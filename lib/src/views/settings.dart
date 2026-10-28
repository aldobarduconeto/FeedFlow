import 'dart:async';
import 'dart:convert';

import 'appearance_controls.dart';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/feed_service.dart';
import '../services/suggestion_service.dart';

import 'package:feedflow/src/models/setting.dart';
import 'package:feedflow/src/views/widget/colors.dart';

class SettingsPage extends StatefulWidget {
  SettingsPage({
    required this.feedService,
    required this.suggestionService,
    required this.onReloadData,
    super.key,
  });

  final FeedService feedService;
  final SuggestionService suggestionService;
  final Future<void> Function() onReloadData;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Setting settings = Setting.defaults;
  bool _isLoading = true;
  String? _storageError;
  bool _isReloadingData = false;

  static String _settingsKey = 'feedflow.settings.v1.local';

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
        title: Text(
          'Configurações',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Restaurar padrões',
            onPressed: () => _updateSettings(Setting.defaults),
            icon: Icon(Icons.restart_alt_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                if (_storageError != null) ...[
                  Card(
                    color: FeedFlowColors.error.withValues(alpha: 0.12),
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Text(
                        _storageError!,
                        style: TextStyle(color: FeedFlowColors.error),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                ],
                Text(
                  'DADOS',
                  style: TextStyle(
                    color: FeedFlowColors.secondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: _isReloadingData
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.sync_rounded),
                    title: Text('Recarregar dados'),
                    subtitle: Text(
                      'Atualiza suas fontes e as sugestões do catálogo',
                    ),
                    onTap: _isReloadingData ? null : _reloadData,
                  ),
                ),
                SizedBox(height: 28),
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: AppearanceControls(),
                  ),
                ),
                SizedBox(height: 28),
                Text(
                  'PERSONALIZAÇÃO',
                  style: TextStyle(
                    color: FeedFlowColors.secondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                SizedBox(height: 12),

                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: settings.markAsReadOnOpen,
                        onChanged: (value) => _updateSettings(
                          settings.copyWith(markAsReadOnOpen: value),
                        ),
                        secondary: Icon(Icons.mark_email_read_outlined),
                        title: Text('Marcar como lido'),
                        subtitle: Text('Marcar artigos ao abri-los'),
                      ),
                      Divider(height: 1, indent: 16, endIndent: 16),
                      SwitchListTile(
                        value: settings.downloadImages,
                        onChanged: (value) => _updateSettings(
                          settings.copyWith(downloadImages: value),
                        ),
                        secondary: Icon(Icons.image_outlined),
                        title: Text('Carregar imagens'),
                        subtitle: Text('Exibir imagens nos artigos'),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 28),
                Text(
                  'ATUALIZAÇÃO DE FEEDS',
                  style: TextStyle(
                    color: FeedFlowColors.secondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                SizedBox(height: 12),

                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: settings.autoRefresh,
                        onChanged: (value) => _updateSettings(
                          settings.copyWith(autoRefresh: value),
                        ),
                        secondary: Icon(Icons.sync_rounded),
                        title: Text('Atualização automática'),
                        subtitle: Text(
                          'Buscar novos conteúdos automaticamente',
                        ),
                      ),
                      if (settings.autoRefresh) ...[
                        Divider(height: 1, indent: 16, endIndent: 16),
                        ListTile(
                          leading: Icon(Icons.schedule_rounded),
                          title: Text('Intervalo de atualização'),
                          subtitle: Text(
                            '${settings.refreshIntervalMinutes} minutos',
                          ),
                          trailing: Icon(Icons.chevron_right_rounded),
                          onTap: () async {
                            final interval = await showModalBottomSheet<int>(
                              context: context,
                              backgroundColor: FeedFlowColors.surface,
                              builder: (context) => SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Padding(
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
                                            ? Icon(
                                                Icons.check_rounded,
                                                color: FeedFlowColors.secondary,
                                              )
                                            : null,
                                        onTap: () {
                                          Navigator.pop(context, minutes);
                                        },
                                      ),
                                    SizedBox(height: 12),
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
                      Divider(height: 1, indent: 16, endIndent: 16),
                      SwitchListTile(
                        value: settings.wifiOnly,
                        onChanged: (value) =>
                            _updateSettings(settings.copyWith(wifiOnly: value)),
                        secondary: Icon(Icons.wifi_rounded),
                        title: Text('Somente Wi-Fi'),
                        subtitle: Text('Limitar atualizações ao Wi-Fi'),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 28),
                Text(
                  'PODCASTS',
                  style: TextStyle(
                    color: FeedFlowColors.secondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                SizedBox(height: 12),

                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: settings.autoplayPodcasts,
                        onChanged: (value) => _updateSettings(
                          settings.copyWith(autoplayPodcasts: value),
                        ),
                        secondary: Icon(Icons.play_circle_outline_rounded),
                        title: Text('Reprodução automática'),
                        subtitle: Text('Iniciar a reprodução automaticamente'),
                      ),
                      Divider(height: 1, indent: 16, endIndent: 16),
                      SwitchListTile(
                        value: settings.skipSilence,
                        onChanged: (value) => _updateSettings(
                          settings.copyWith(skipSilence: value),
                        ),
                        secondary: Icon(Icons.graphic_eq_rounded),
                        title: Text('Pular silêncios'),
                        subtitle: Text('Reduzir pausas silenciosas no áudio'),
                      ),
                      Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        leading: Icon(Icons.speed_rounded),
                        title: Text('Velocidade por podcast'),
                        subtitle: Text(
                          'Ajuste de 0,8x a 2x no player. Cada programa lembra sua velocidade.',
                        ),
                      ),
                      Divider(height: 1, indent: 16, endIndent: 16),
                      SwitchListTile(
                        value: settings.savePlaybackPosition,
                        onChanged: (value) => _updateSettings(
                          settings.copyWith(savePlaybackPosition: value),
                        ),
                        secondary: Icon(Icons.bookmark_outline_rounded),
                        title: Text('Salvar posição'),
                        subtitle: Text('Continuar de onde parou'),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 28),
                Text(
                  'ARMAZENAMENTO',
                  style: TextStyle(
                    color: FeedFlowColors.secondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                SizedBox(height: 12),

                Card(
                  child: ListTile(
                    leading: Icon(Icons.cleaning_services_outlined),
                    title: Text('Retenção de conteúdo'),
                    subtitle: Text(
                      settings.retentionDays == 0
                          ? 'Manter indefinidamente'
                          : '${settings.retentionDays} dias',
                    ),
                    trailing: Icon(Icons.chevron_right_rounded),
                    onTap: () async {
                      final days = await showModalBottomSheet<int>(
                        context: context,
                        backgroundColor: FeedFlowColors.surface,
                        builder: (context) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
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
                                      ? Icon(
                                          Icons.check_rounded,
                                          color: FeedFlowColors.secondary,
                                        )
                                      : null,
                                  onTap: () => Navigator.pop(context, option),
                                ),
                              SizedBox(height: 12),
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

                SizedBox(height: 24),
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
