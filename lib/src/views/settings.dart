import 'dart:async';
import 'dart:convert';

import 'appearance_controls.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/appearance_service.dart';
import '../services/online_catalog_service.dart';
import 'widget/catalog_locale_dialogs.dart';
import '../services/feed_service.dart';
import '../services/suggestion_service.dart';
import '../services/notification_service.dart';
import '../services/permission_service.dart';
import 'permissions_onboarding_dialog.dart';
import 'widget/liquid_container.dart';

import 'package:feedflow/src/models/setting.dart';
import 'package:feedflow/src/views/widget/colors.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    required this.feedService,
    required this.suggestionService,
    required this.onReloadData,
    this.notificationService,
    super.key,
  });

  final FeedService feedService;
  final SuggestionService suggestionService;
  final NotificationService? notificationService;
  final Future<void> Function() onReloadData;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Setting settings = Setting.defaults;
  bool _isLoading = true;
  String? _storageError;
  bool _isReloadingData = false;

  static const String _settingsKey = 'feedflow.settings.v1.local';

  @override
  void initState() {
    super.initState();
    unawaited(_loadSettings());
  }

  Future<void> _reloadData() async {
    if (_isReloadingData) return;
    setState(() => _isReloadingData = true);
    try {
      await widget.onReloadData();
      if (mounted) {
        final failedFeeds =
            widget.feedService.refreshErrors.length +
            widget.suggestionService.previews.values
                .where((preview) => preview.hasError)
                .length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              failedFeeds == 0
                  ? 'Todas as fontes foram atualizadas com sucesso.'
                  : 'Atualização concluída: $failedFeeds fonte(s) falharam.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível recarregar os dados: $error'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isReloadingData = false);
    }
  }

  Future<void> _loadSettings() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = preferences.getString(_settingsKey);
      final loadedSettings = saved == null
          ? Setting.defaults
          : Setting.fromMap(jsonDecode(saved) as Map<String, dynamic>);
      if (mounted) {
        setState(() {
          settings = loadedSettings;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _storageError = 'Não foi possível carregar as configurações: $error';
          _isLoading = false;
        });
      }
    }
  }

  void _updateSettings(Setting updatedSettings) {
    setState(() => settings = updatedSettings);
    unawaited(_persistSettings(updatedSettings));
  }

  Future<void> _persistSettings(Setting updatedSettings) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setString(
        _settingsKey,
        jsonEncode(updatedSettings.toMap()),
      );
      if (!saved) {
        throw StateError('O SharedPreferences não confirmou a gravação.');
      }
      if (mounted && _storageError != null) {
        setState(() => _storageError = null);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _storageError = 'Não foi possível salvar as configurações: $error';
        });
      }
    }
  }

  Future<void> _exportOpml() async {
    final opml = widget.feedService.exportOpml();
    await Clipboard.setData(ClipboardData(text: opml));
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FeedFlowColors.surfaceElevated,
        title: Row(
          children: [
            Icon(Icons.output_rounded, color: FeedFlowColors.primary),
            const SizedBox(width: 10),
            const Text(
              'Exportação OPML',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.feedService.sources.length} fontes foram formatadas no padrão universal OPML 2.0 e copiadas para a sua área de transferência!',
              style: TextStyle(color: FeedFlowColors.textPrimary, fontSize: 13.5),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: FeedFlowColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: FeedFlowColors.divider),
              ),
              constraints: const BoxConstraints(maxHeight: 140),
              child: SingleChildScrollView(
                child: Text(
                  opml,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showImportOpmlDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FeedFlowColors.surfaceElevated,
        title: Row(
          children: [
            Icon(Icons.input_rounded, color: FeedFlowColors.primary),
            const SizedBox(width: 10),
            const Text(
              'Importar OPML',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cole o XML do arquivo OPML ou clique no ícone para colar da área de transferência:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: '<opml version="2.0">...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                suffixIcon: IconButton(
                  tooltip: 'Colar da área de transferência',
                  icon: const Icon(Icons.paste_rounded),
                  onPressed: () async {
                    final data = await Clipboard.getData('text/plain');
                    if (data?.text != null) {
                      controller.text = data!.text!;
                    }
                  },
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Importar'),
          ),
        ],
      ),
    );

    if (result == true && controller.text.trim().isNotEmpty) {
      try {
        final count = await widget.feedService.importOpml(controller.text);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                count > 0
                    ? '$count nova(s) fonte(s) importada(s) com sucesso!'
                    : 'Nenhuma nova fonte identificada no arquivo fornecido.',
              ),
            ),
          );
          if (count > 0) {
            unawaited(widget.onReloadData());
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Falha ao importar OPML: $e')),
          );
        }
      }
    }
    controller.dispose();
  }

  Future<void> _confirmClearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FeedFlowColors.surfaceElevated,
        title: const Text('Limpar cache e artigos antigos?'),
        content: const Text(
          'Esta operação removerá os artigos já lidos e arquivos temporários da memória do aparelho para liberar espaço. Suas fontes cadastradas e favoritos permanecerão intactos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Limpar agora'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cache local e artigos lidos foram limpos com sucesso.'),
        ),
      );
      unawaited(widget.onReloadData());
    }
  }

  Future<void> _confirmResetSettings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FeedFlowColors.surfaceElevated,
        title: const Text('Restaurar padrões?'),
        content: const Text(
          'Deseja restaurar todas as configurações e aparência do FeedFlow para os valores padrão de fábrica? As suas assinaturas de feeds continuarão salvas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _updateSettings(Setting.defaults);
      await AppearanceService.instance.update(
        theme: 'system',
        fontSize: 17,
        margin: 20,
        serif: false,
        alignment: TextAlign.start,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configurações redefinidas para os padrões.'),
          ),
        );
      }
    }
  }

  Future<void> _selectPlaybackSpeed() async {
    final selected = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: FeedFlowColors.surfaceElevated,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Velocidade padrão de reprodução',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            for (final speed in [0.8, 1.0, 1.2, 1.5, 1.75, 2.0])
              ListTile(
                title: Text('${speed}x'),
                trailing: settings.playbackSpeed == speed
                    ? Icon(Icons.check_rounded, color: FeedFlowColors.primary)
                    : null,
                onTap: () => Navigator.pop(context, speed),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (selected != null && mounted) {
      _updateSettings(settings.copyWith(playbackSpeed: selected));
    }
  }

  Future<void> _selectSeekSeconds({required bool isForward}) async {
    final current =
        isForward ? settings.seekForwardSeconds : settings.seekBackwardSeconds;
    final options = isForward ? [10, 15, 30, 45, 60] : [5, 10, 15, 30];

    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: FeedFlowColors.surfaceElevated,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                isForward ? 'Avanço rápido' : 'Retrocesso rápido',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            for (final sec in options)
              ListTile(
                title: Text('$sec segundos'),
                trailing: current == sec
                    ? Icon(Icons.check_rounded, color: FeedFlowColors.primary)
                    : null,
                onTap: () => Navigator.pop(context, sec),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    if (selected != null && mounted) {
      _updateSettings(
        isForward
            ? settings.copyWith(seekForwardSeconds: selected)
            : settings.copyWith(seekBackwardSeconds: selected),
      );
    }
  }

  Future<void> _selectDefaultSleepTimer() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: FeedFlowColors.surfaceElevated,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Timer de sono padrão',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            for (final min in [15, 30, 45, 60])
              ListTile(
                title: Text('$min minutos'),
                trailing: settings.defaultSleepTimerMinutes == min
                    ? Icon(Icons.check_rounded, color: FeedFlowColors.primary)
                    : null,
                onTap: () => Navigator.pop(context, min),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (selected != null && mounted) {
      _updateSettings(settings.copyWith(defaultSleepTimerMinutes: selected));
    }
  }

  Future<void> _selectRefreshInterval() async {
    final interval = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: FeedFlowColors.surfaceElevated,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Intervalo de atualização em 2º plano',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            for (final minutes in [15, 30, 60, 180])
              ListTile(
                title: Text('$minutes minutos'),
                trailing: settings.refreshIntervalMinutes == minutes
                    ? Icon(Icons.check_rounded, color: FeedFlowColors.secondary)
                    : null,
                onTap: () => Navigator.pop(context, minutes),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (interval != null && mounted) {
      _updateSettings(settings.copyWith(refreshIntervalMinutes: interval));
    }
  }

  Future<void> _selectRetentionDays() async {
    final days = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: FeedFlowColors.surfaceElevated,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Retenção de conteúdo antigo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            for (final option in <int>[7, 30, 90, 0])
              ListTile(
                title: Text(
                  option == 0 ? 'Indefinidamente' : '$option dias',
                ),
                trailing: settings.retentionDays == option
                    ? Icon(Icons.check_rounded, color: FeedFlowColors.secondary)
                    : null,
                onTap: () => Navigator.pop(context, option),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (days != null && mounted) {
      _updateSettings(settings.copyWith(retentionDays: days));
    }
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 26, bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: FeedFlowColors.secondary),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: FeedFlowColors.secondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalArticles =
        widget.feedService.items.where((i) => !i.isPodcast).length;
    final totalPodcasts =
        widget.feedService.items.where((i) => i.isPodcast).length;
    final totalSources = widget.feedService.sources.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Configurações',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Restaurar padrões',
            onPressed: _confirmResetSettings,
            icon: const Icon(Icons.restart_alt_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
              children: [
                if (_storageError != null) ...[
                  Card(
                    color: FeedFlowColors.error.withValues(alpha: 0.12),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        _storageError!,
                        style: TextStyle(color: FeedFlowColors.error),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 1. APARÊNCIA & TEMAS
                _buildSectionHeader(
                  'APARÊNCIA & TEMAS',
                  Icons.palette_outlined,
                ),
                Card(
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: AppearanceControls(),
                  ),
                ),
                const SizedBox(height: 10),
                Card(
                  child: SwitchListTile(
                    value: settings.compactFeedView,
                    onChanged: (val) => _updateSettings(
                      settings.copyWith(compactFeedView: val),
                    ),
                    secondary: const Icon(Icons.view_agenda_outlined),
                    title: const Text('Modo de exibição compacto'),
                    subtitle: const Text(
                      'Reduz o espaçamento entre itens para visualizar mais títulos na tela',
                    ),
                  ),
                ),

                // PAÍS & IDIOMA DO CATÁLOGO (InfoBubble)
                _buildSectionHeader(
                  'PAÍS & IDIOMA DO CATÁLOGO',
                  Icons.public_rounded,
                ),
                LiquidContainer(
                  padding: const EdgeInsets.all(14),
                  backgroundColor:
                      FeedFlowColors.surfaceElevated.withValues(alpha: 0.7),
                  child: Row(
                    children: [
                      Icon(
                        Icons.travel_explore_rounded,
                        color: FeedFlowColors.primary,
                        size: 26,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Indica o país e idioma para filtrar as fontes do catálogo InfoBubble (catalog.html) na aba Explorar. Os dados são consultados estritamente sob demanda e mantidos apenas na memória volátil, sem armazenamento persistente.',
                          style: TextStyle(
                            fontSize: 12,
                            color: FeedFlowColors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                AnimatedBuilder(
                  animation: OnlineCatalogService.instance,
                  builder: (context, _) {
                    final catalogService = OnlineCatalogService.instance;
                    return Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: Text(
                              OnlineCatalogService.countryFlag(
                                catalogService.selectedCountry,
                              ),
                              style: const TextStyle(fontSize: 22),
                            ),
                            title: const Text('País do catálogo'),
                            subtitle: Text(
                              '${catalogService.selectedCountryDisplay} (${catalogService.selectedCountry})',
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () async {
                              final res =
                                  await showCountryPickerDialog(context);
                              if (res != null && mounted) setState(() {});
                            },
                          ),
                          const Divider(height: 1, indent: 16, endIndent: 16),
                          ListTile(
                            leading: const Icon(Icons.translate_rounded),
                            title: const Text('Idioma preferencial'),
                            subtitle: Text(
                              '${catalogService.selectedLanguageDisplay} (${catalogService.selectedLanguage})',
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () async {
                              final res =
                                  await showLanguagePickerDialog(context);
                              if (res != null && mounted) setState(() {});
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // 2. LEITOR & CONTEÚDO
                _buildSectionHeader(
                  'LEITOR & ARTIGOS',
                  Icons.article_outlined,
                ),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: settings.markAsReadOnOpen,
                        onChanged: (value) => _updateSettings(
                          settings.copyWith(markAsReadOnOpen: value),
                        ),
                        secondary: const Icon(Icons.mark_email_read_outlined),
                        title: const Text('Marcar como lido ao abrir'),
                        subtitle: const Text(
                          'Muda o status do artigo para lido assim que for aberto',
                        ),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      SwitchListTile(
                        value: settings.markAsReadOnScroll,
                        onChanged: (value) => _updateSettings(
                          settings.copyWith(markAsReadOnScroll: value),
                        ),
                        secondary: const Icon(Icons.swipe_vertical_rounded),
                        title: const Text('Marcar ao rolar até o final'),
                        subtitle: const Text(
                          'Marca como lido automaticamente após ler todo o texto',
                        ),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      SwitchListTile(
                        value: settings.downloadImages,
                        onChanged: (value) => _updateSettings(
                          settings.copyWith(downloadImages: value),
                        ),
                        secondary: const Icon(Icons.image_outlined),
                        title: const Text('Carregar imagens nos artigos'),
                        subtitle: const Text(
                          'Exibe fotos e mídias das publicações (desative para economizar dados)',
                        ),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      SwitchListTile(
                        value: settings.openInExternalBrowser,
                        onChanged: (value) => _updateSettings(
                          settings.copyWith(openInExternalBrowser: value),
                        ),
                        secondary: const Icon(Icons.open_in_browser_rounded),
                        title: const Text('Abrir links no navegador externo'),
                        subtitle: const Text(
                          'Usa o navegador padrão do sistema em vez do visualizador interno',
                        ),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      SwitchListTile(
                        value: settings.confirmMarkAllRead,
                        onChanged: (value) => _updateSettings(
                          settings.copyWith(confirmMarkAllRead: value),
                        ),
                        secondary:
                            const Icon(Icons.check_circle_outline_rounded),
                        title: const Text('Confirmar antes de marcar todos'),
                        subtitle: const Text(
                          'Exibe confirmação para prevenir toques acidentais',
                        ),
                      ),
                    ],
                  ),
                ),

                // 3. PODCASTS & REPRODUÇÃO
                _buildSectionHeader(
                  'PODCASTS & REPRODUÇÃO',
                  Icons.podcasts_rounded,
                ),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.speed_rounded),
                        title: const Text('Velocidade padrão de reprodução'),
                        subtitle: Text(
                          '${settings.playbackSpeed}x (ajustável no player individual)',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: _selectPlaybackSpeed,
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        leading: const Icon(Icons.fast_forward_rounded),
                        title: const Text('Avanço rápido'),
                        subtitle: Text('${settings.seekForwardSeconds} segundos'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _selectSeekSeconds(isForward: true),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        leading: const Icon(Icons.fast_rewind_rounded),
                        title: const Text('Retrocesso rápido'),
                        subtitle:
                            Text('${settings.seekBackwardSeconds} segundos'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _selectSeekSeconds(isForward: false),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      SwitchListTile(
                        value: settings.skipSilence,
                        onChanged: (value) => _updateSettings(
                          settings.copyWith(skipSilence: value),
                        ),
                        secondary: const Icon(Icons.graphic_eq_rounded),
                        title: const Text('Pular silêncios'),
                        subtitle: const Text(
                          'Reduz pausas silenciosas durante o episódio',
                        ),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      SwitchListTile(
                        value: settings.autoplayPodcasts,
                        onChanged: (value) => _updateSettings(
                          settings.copyWith(autoplayPodcasts: value),
                        ),
                        secondary: const Icon(Icons.playlist_play_rounded),
                        title: const Text('Reprodução contínua'),
                        subtitle: const Text(
                          'Toca o próximo episódio da lista automaticamente',
                        ),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      SwitchListTile(
                        value: settings.savePlaybackPosition,
                        onChanged: (value) => _updateSettings(
                          settings.copyWith(savePlaybackPosition: value),
                        ),
                        secondary: const Icon(Icons.bookmark_outline_rounded),
                        title: const Text('Lembrar posição de reprodução'),
                        subtitle: const Text(
                          'Retoma os episódios exatamente de onde parou',
                        ),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      SwitchListTile(
                        value: settings.pauseOnHeadphonesDisconnect,
                        onChanged: (value) => _updateSettings(
                          settings.copyWith(
                            pauseOnHeadphonesDisconnect: value,
                          ),
                        ),
                        secondary: const Icon(Icons.headset_off_outlined),
                        title: const Text('Pausar ao desconectar fones'),
                        subtitle: const Text(
                          'Pausa imediata se fones ou bluetooth forem desconectados',
                        ),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        leading: const Icon(Icons.bedtime_outlined),
                        title: const Text('Timer de sono padrão'),
                        subtitle: Text(
                          '${settings.defaultSleepTimerMinutes} minutos',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: _selectDefaultSleepTimer,
                      ),
                    ],
                  ),
                ),

                // 4. SINCRONIZAÇÃO & DADOS
                _buildSectionHeader(
                  'SINCRONIZAÇÃO & DADOS',
                  Icons.sync_rounded,
                ),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: _isReloadingData
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.sync_rounded),
                        title: const Text('Recarregar todos os dados agora'),
                        subtitle: const Text(
                          'Atualiza matérias recentes e catálogo de sugestões',
                        ),
                        trailing: _isReloadingData
                            ? null
                            : const Icon(Icons.play_arrow_rounded),
                        onTap: _isReloadingData ? null : _reloadData,
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      SwitchListTile(
                        value: settings.autoRefresh,
                        onChanged: (value) => _updateSettings(
                          settings.copyWith(autoRefresh: value),
                        ),
                        secondary: const Icon(Icons.autorenew_rounded),
                        title: const Text('Atualização automática'),
                        subtitle: const Text(
                          'Busca novidades em segundo plano periodicamente',
                        ),
                      ),
                      if (settings.autoRefresh) ...[
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        ListTile(
                          leading: const Icon(Icons.schedule_rounded),
                          title: const Text('Intervalo de atualização'),
                          subtitle: Text(
                            '${settings.refreshIntervalMinutes} minutos',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: _selectRefreshInterval,
                        ),
                      ],
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      SwitchListTile(
                        value: settings.refreshOnStartup,
                        onChanged: (value) => _updateSettings(
                          settings.copyWith(refreshOnStartup: value),
                        ),
                        secondary: const Icon(Icons.launch_rounded),
                        title: const Text('Atualizar ao abrir o aplicativo'),
                        subtitle: const Text(
                          'Verifica novas publicações assim que o app é iniciado',
                        ),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      SwitchListTile(
                        value: settings.wifiOnly,
                        onChanged: (value) => _updateSettings(
                          settings.copyWith(wifiOnly: value),
                        ),
                        secondary: const Icon(Icons.wifi_rounded),
                        title: const Text('Atualizar somente no Wi-Fi'),
                        subtitle: const Text(
                          'Economiza a sua franquia de dados móveis 3G/4G/5G',
                        ),
                      ),
                    ],
                  ),
                ),

                // 5. NOTIFICAÇÕES & ALERTAS
                _buildSectionHeader(
                  'NOTIFICAÇÕES & ALERTAS',
                  Icons.notifications_active_outlined,
                ),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: widget.notificationService?.notificationsEnabled ??
                            true,
                        onChanged: (val) {
                          widget.notificationService?.setNotificationsEnabled(val);
                          setState(() {});
                        },
                        secondary:
                            const Icon(Icons.notifications_active_outlined),
                        title: const Text('Notificações de novas publicações'),
                        subtitle: const Text(
                          'Avisa quando um artigo ou podcast é lançado com título e publisher',
                        ),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      SwitchListTile(
                        value: settings.notifyNews,
                        onChanged: (val) => _updateSettings(
                          settings.copyWith(notifyNews: val),
                        ),
                        secondary: const Icon(Icons.article_outlined),
                        title: const Text('Notificar notícias'),
                        subtitle: const Text(
                          'Alertas para artigos de texto das suas fontes',
                        ),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      SwitchListTile(
                        value: settings.notifyPodcasts,
                        onChanged: (val) => _updateSettings(
                          settings.copyWith(notifyPodcasts: val),
                        ),
                        secondary: const Icon(Icons.podcasts_rounded),
                        title: const Text('Notificar podcasts'),
                        subtitle: const Text(
                          'Alertas para novos episódios de podcasts inscritos',
                        ),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        leading: const Icon(Icons.send_rounded),
                        title: const Text('Testar notificação de notícia'),
                        subtitle: const Text('Dispara notificação nativa no sistema e in-app'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () async {
                          await widget.notificationService
                              ?.sendTestNotification(isPodcast: false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Notificação de notícia enviada para o sistema!',
                                ),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        leading: const Icon(Icons.send_rounded),
                        title: const Text('Testar notificação de podcast'),
                        subtitle: const Text('Dispara notificação nativa de novo episódio'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () async {
                          await widget.notificationService
                              ?.sendTestNotification(isPodcast: true);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Notificação de podcast enviada para o sistema!',
                                ),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        leading: const Icon(Icons.security_rounded),
                        title: const Text('Permissões do aplicativo'),
                        subtitle: const Text(
                          'Rever permissões do sistema (notificações, mídia e segundo plano)',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => PermissionsOnboardingDialog(
                              permissionService: PermissionService(),
                              onCompleted: () => Navigator.pop(context),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        leading: const Icon(Icons.settings_applications_rounded),
                        title: const Text('Configurações do sistema operacional'),
                        subtitle: const Text(
                          'Acessar detalhes e gerenciar permissões no Android/iOS',
                        ),
                        trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                        onTap: () async {
                          await PermissionService().openSettings();
                        },
                      ),
                    ],
                  ),
                ),

                // 6. BACKUP & PRIVACIDADE (100% LOCAL / SEM CONTAS)
                _buildSectionHeader(
                  'BACKUP & PRIVACIDADE (100% LOCAL / SEM CONTAS)',
                  Icons.shield_outlined,
                ),
                LiquidContainer(
                  padding: const EdgeInsets.all(14),
                  backgroundColor:
                      FeedFlowColors.surfaceElevated.withValues(alpha: 0.7),
                  child: Row(
                    children: [
                      Icon(
                        Icons.verified_user_rounded,
                        color: FeedFlowColors.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Zero Contas, 100% Privado. O FeedFlow armazena todas as suas assinaturas, progresso e histórico exclusivamente no seu dispositivo, sem envio para nuvem e sem telemetria.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: FeedFlowColors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.file_upload_outlined),
                        title: const Text('Exportar fontes (OPML 2.0)'),
                        subtitle: const Text(
                          'Copia todas as suas fontes em formato universal para backup ou outros apps',
                        ),
                        trailing: const Icon(Icons.copy_rounded, size: 18),
                        onTap: _exportOpml,
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        leading: const Icon(Icons.file_download_outlined),
                        title: const Text('Importar fontes (OPML 2.0)'),
                        subtitle: const Text(
                          'Adicione múltiplos feeds instantaneamente colando o XML do OPML',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: _showImportOpmlDialog,
                      ),
                    ],
                  ),
                ),

                // 7. ARMAZENAMENTO & CACHE
                _buildSectionHeader(
                  'ARMAZENAMENTO & CACHE',
                  Icons.storage_rounded,
                ),
                // Estatísticas rápidas
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DADOS EM MEMÓRIA LOCAL',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: FeedFlowColors.textDisabled,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildDataStat(
                              label: 'Fontes',
                              count: totalSources.toString(),
                              icon: Icons.rss_feed_rounded,
                            ),
                            _buildDataStat(
                              label: 'Artigos',
                              count: totalArticles.toString(),
                              icon: Icons.article_rounded,
                            ),
                            _buildDataStat(
                              label: 'Podcasts',
                              count: totalPodcasts.toString(),
                              icon: Icons.podcasts_rounded,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.cleaning_services_outlined),
                        title: const Text('Retenção de conteúdo antigo'),
                        subtitle: Text(
                          settings.retentionDays == 0
                              ? 'Manter indefinidamente'
                              : '${settings.retentionDays} dias',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: _selectRetentionDays,
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        leading: Icon(
                          Icons.delete_sweep_outlined,
                          color: FeedFlowColors.warning,
                        ),
                        title: const Text('Limpar cache e itens lidos antigos'),
                        subtitle: const Text(
                          'Libera espaço em disco sem afetar suas fontes inscritas',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: _confirmClearCache,
                      ),
                    ],
                  ),
                ),

                // 8. SOBRE & AÇÕES DO SISTEMA
                _buildSectionHeader('SOBRE O FEEDFLOW', Icons.info_outline_rounded),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset('assets/icon.png', width: 32, height: 32),
                        ),
                        title: const Text('FeedFlow'),
                        subtitle: const Text('Versão 1.0.0 • 100% Offline-First'),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        leading: Icon(Icons.restart_alt_rounded, color: FeedFlowColors.error),
                        title: Text('Restaurar configurações padrão', style: TextStyle(color: FeedFlowColors.error)),
                        subtitle: const Text('Redefine aparência, leitor e reprodução para os valores de fábrica'),
                        onTap: _confirmResetSettings,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),
                Center(
                  child: Text(
                    'FeedFlow • Agregador de Feeds & Podcasts Sem Contas',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: FeedFlowColors.textDisabled),
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }

  Widget _buildDataStat({
    required String label,
    required String count,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(icon, size: 22, color: FeedFlowColors.primary),
        const SizedBox(height: 6),
        Text(
          count,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: FeedFlowColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: FeedFlowColors.textDisabled),
        ),
      ],
    );
  }
}
