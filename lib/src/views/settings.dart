import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../services/feed_service.dart';
import '../services/suggestion_service.dart';

import 'package:feedflow/src/models/setting.dart';
import 'package:feedflow/src/views/widget/colors.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    required this.userId,
    required this.authService,
    required this.feedService,
    required this.suggestionService,
    required this.onReloadData,
    required this.onSignOut,
    super.key,
  });

  final String userId;
  final AuthService authService;
  final FeedService feedService;
  final SuggestionService suggestionService;
  final Future<void> Function() onReloadData;
  final Future<void> Function() onSignOut;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Setting settings = Setting.defaults;
  bool _isLoading = true;
  String? _storageError;
  AccountProfile? _profile;
  bool _profileLoading = true;
  bool _isReloadingData = false;

  String get _settingsKey => 'feedflow.settings.v1.${widget.userId}';

  @override
  void initState() {
    super.initState();
    unawaited(_loadSettings());
    unawaited(_loadProfile());
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await widget.authService.getProfile(widget.userId);
      if (mounted) setState(() => _profile = profile);
    } catch (error) {
      if (mounted) {
        setState(
          () => _storageError = 'Não foi possível carregar o perfil: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _profileLoading = false);
    }
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
                  ? 'Dados recarregados com sucesso.'
                  : 'Dados recarregados. $failedFeeds fonte(s) falharam.',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Configurações',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Restaurar padrões',
            onPressed: () => _updateSettings(Setting.defaults),
            icon: const Icon(Icons.restart_alt_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                if (_storageError != null) ...[
                  Card(
                    color: FeedFlowColors.error.withValues(alpha: 0.12),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        _storageError!,
                        style: const TextStyle(color: FeedFlowColors.error),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const Text(
                  'PERFIL',
                  style: TextStyle(
                    color: FeedFlowColors.secondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.person_outline_rounded),
                        title: Text(
                          _profileLoading
                              ? 'Carregando perfil…'
                              : _profile?.username ?? 'Perfil indisponível',
                        ),
                        subtitle: const Text('Nome de usuário'),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        leading: const Icon(Icons.fingerprint_rounded),
                        title: const Text('ID da conta'),
                        subtitle: SelectableText(_profile?.id ?? widget.userId),
                        trailing: IconButton(
                          tooltip: 'Copiar ID',
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            await Clipboard.setData(
                              ClipboardData(
                                text: _profile?.id ?? widget.userId,
                              ),
                            );
                            if (mounted) {
                              messenger.showSnackBar(
                                const SnackBar(content: Text('ID copiado.')),
                              );
                            }
                          },
                          icon: const Icon(Icons.copy_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'DADOS',
                  style: TextStyle(
                    color: FeedFlowColors.secondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: _isReloadingData
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync_rounded),
                    title: const Text('Recarregar dados'),
                    subtitle: const Text(
                      'Atualiza suas fontes e as sugestões do catálogo',
                    ),
                    onTap: _isReloadingData ? null : _reloadData,
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'CONTA',
                  style: TextStyle(
                    color: FeedFlowColors.secondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.logout_rounded,
                      color: FeedFlowColors.error,
                    ),
                    title: const Text('Sair da conta'),
                    onTap: () async => widget.onSignOut(),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'PERSONALIZAÇÃO',
                  style: TextStyle(
                    color: FeedFlowColors.secondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 12),

                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: settings.markAsReadOnOpen,
                        onChanged: (value) => _updateSettings(
                          settings.copyWith(markAsReadOnOpen: value),
                        ),
                        secondary: const Icon(Icons.mark_email_read_outlined),
                        title: const Text('Marcar como lido'),
                        subtitle: const Text('Marcar artigos ao abri-los'),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      SwitchListTile(
                        value: settings.downloadImages,
                        onChanged: (value) => _updateSettings(
                          settings.copyWith(downloadImages: value),
                        ),
                        secondary: const Icon(Icons.image_outlined),
                        title: const Text('Carregar imagens'),
                        subtitle: const Text('Exibir imagens nos artigos'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),
                const Text(
                  'ATUALIZAÇÃO DE FEEDS',
                  style: TextStyle(
                    color: FeedFlowColors.secondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 12),

                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: settings.autoRefresh,
                        onChanged: (value) => _updateSettings(
                          settings.copyWith(autoRefresh: value),
                        ),
                        secondary: const Icon(Icons.sync_rounded),
                        title: const Text('Atualização automática'),
                        subtitle: const Text(
                          'Buscar novos conteúdos automaticamente',
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
                          onTap: () async {
                            final interval = await showModalBottomSheet<int>(
                              context: context,
                              backgroundColor: FeedFlowColors.surface,
                              builder: (context) => SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.all(20),
                                      child: Text(
                                        'Intervalo de atualização',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    for (final minutes in [15, 30, 60, 180])
                                      ListTile(
                                        title: Text('$minutes minutos'),
                                        trailing:
                                            settings.refreshIntervalMinutes ==
                                                minutes
                                            ? const Icon(
                                                Icons.check_rounded,
                                                color: FeedFlowColors.secondary,
                                              )
                                            : null,
                                        onTap: () {
                                          Navigator.pop(context, minutes);
                                        },
                                      ),
                                    const SizedBox(height: 12),
                                  ],
                                ),
                              ),
                            );

                            if (interval != null && mounted) {
                              _updateSettings(
                                settings.copyWith(
                                  refreshIntervalMinutes: interval,
                                ),
                              );
                            }
                          },
                        ),
                      ],
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      SwitchListTile(
                        value: settings.wifiOnly,
                        onChanged: (value) =>
                            _updateSettings(settings.copyWith(wifiOnly: value)),
                        secondary: const Icon(Icons.wifi_rounded),
                        title: const Text('Somente Wi-Fi'),
                        subtitle: const Text('Limitar atualizações ao Wi-Fi'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),
                const Text(
                  'PODCASTS',
                  style: TextStyle(
                    color: FeedFlowColors.secondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 12),

                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: settings.autoplayPodcasts,
                        onChanged: (value) => _updateSettings(
                          settings.copyWith(autoplayPodcasts: value),
                        ),
                        secondary: const Icon(
                          Icons.play_circle_outline_rounded,
                        ),
                        title: const Text('Reprodução automática'),
                        subtitle: const Text(
                          'Iniciar a reprodução automaticamente',
                        ),
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
                          'Reduzir pausas silenciosas no áudio',
                        ),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        leading: const Icon(Icons.speed_rounded),
                        title: const Text('Velocidade de reprodução'),
                        subtitle: Text(
                          '${settings.playbackSpeed.toStringAsFixed(2)}x',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () async {
                          double speed = settings.playbackSpeed;

                          final result = await showDialog<double>(
                            context: context,
                            builder: (dialogContext) => StatefulBuilder(
                              builder: (context, setDialogState) => AlertDialog(
                                title: const Text('Velocidade de reprodução'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${speed.toStringAsFixed(2)}x',
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w700,
                                        color: FeedFlowColors.secondary,
                                      ),
                                    ),
                                    Slider(
                                      value: speed,
                                      min: 0.5,
                                      max: 2.0,
                                      divisions: 15,
                                      label: '${speed.toStringAsFixed(2)}x',
                                      onChanged: (value) {
                                        setDialogState(() {
                                          speed = value;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext),
                                    child: const Text('Cancelar'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, speed),
                                    child: const Text('Aplicar'),
                                  ),
                                ],
                              ),
                            ),
                          );

                          if (result != null && mounted) {
                            _updateSettings(
                              settings.copyWith(playbackSpeed: result),
                            );
                          }
                        },
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      SwitchListTile(
                        value: settings.savePlaybackPosition,
                        onChanged: (value) => _updateSettings(
                          settings.copyWith(savePlaybackPosition: value),
                        ),
                        secondary: const Icon(Icons.bookmark_outline_rounded),
                        title: const Text('Salvar posição'),
                        subtitle: const Text('Continuar de onde parou'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),
                const Text(
                  'ARMAZENAMENTO',
                  style: TextStyle(
                    color: FeedFlowColors.secondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 12),

                Card(
                  child: ListTile(
                    leading: const Icon(Icons.cleaning_services_outlined),
                    title: const Text('Retenção de conteúdo'),
                    subtitle: Text(
                      settings.retentionDays == 0
                          ? 'Manter indefinidamente'
                          : '${settings.retentionDays} dias',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () async {
                      final days = await showModalBottomSheet<int>(
                        context: context,
                        backgroundColor: FeedFlowColors.surface,
                        builder: (context) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Padding(
                                padding: EdgeInsets.all(20),
                                child: Text(
                                  'Retenção de conteúdo',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              for (final option in <int>[7, 30, 90, 0])
                                ListTile(
                                  title: Text(
                                    option == 0
                                        ? 'Indefinidamente'
                                        : '$option dias',
                                  ),
                                  trailing: settings.retentionDays == option
                                      ? const Icon(
                                          Icons.check_rounded,
                                          color: FeedFlowColors.secondary,
                                        )
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
                    },
                  ),
                ),

                const SizedBox(height: 24),
                Center(
                  child: Text(
                    'FeedFlow • Configurações',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: FeedFlowColors.textDisabled),
                  ),
                ),
              ],
            ),
    );
  }
}
