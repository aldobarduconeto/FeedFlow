import 'package:flutter/material.dart';

import '../services/permission_service.dart';
import 'widget/colors.dart';

class PermissionsOnboardingDialog extends StatefulWidget {
  final PermissionService permissionService;
  final VoidCallback onCompleted;

  const PermissionsOnboardingDialog({
    super.key,
    required this.permissionService,
    required this.onCompleted,
  });

  @override
  State<PermissionsOnboardingDialog> createState() =>
      _PermissionsOnboardingDialogState();
}

class _PermissionsOnboardingDialogState
    extends State<PermissionsOnboardingDialog> {
  bool _isRequesting = false;
  Map<String, bool> _statuses = {
    'notification': false,
    'storage': false,
    'audio': false,
    'batteryOptimization': false,
  };

  @override
  void initState() {
    super.initState();
    _checkInitialStatuses();
  }

  Future<void> _checkInitialStatuses() async {
    final res = await widget.permissionService.checkAllPermissions();
    if (mounted) {
      setState(() => _statuses = res);
    }
  }

  Future<void> _grantPermissions() async {
    setState(() => _isRequesting = true);
    try {
      final results = await widget.permissionService.requestAllPermissions();
      if (mounted) {
        setState(() => _statuses = results);
      }
    } finally {
      if (mounted) {
        widget.onCompleted();
      }
    }
  }

  Future<void> _openAppSettings() async {
    await widget.permissionService.openSettings();
  }

  Future<void> _skip() async {
    await widget.permissionService.markPermissionsRequested();
    if (mounted) {
      widget.onCompleted();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool notifGranted = _statuses['notification'] ?? false;
    final bool storageGranted =
        (_statuses['storage'] ?? false) || (_statuses['audio'] ?? false);
    final bool batteryGranted = _statuses['batteryOptimization'] ?? false;

    return Dialog(
      backgroundColor: FeedFlowColors.surfaceElevated,
      elevation: 16,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(
          color: FeedFlowColors.divider.withValues(alpha: 0.7),
          width: 0.8,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Ícone e Apresentação do App
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: FeedFlowColors.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: FeedFlowColors.primary.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(
                        'assets/icon.png',
                        width: 44,
                        height: 44,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.rss_feed_rounded,
                          size: 32,
                          color: FeedFlowColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Permissões do FeedFlow',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: FeedFlowColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Para sincronizar conteúdos, alertar novas publicações e reproduzir áudio em segundo plano com excelência, solicitamos autorização aos seguintes recursos do sistema:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: FeedFlowColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),

              // Card 1: Notificações
              _permissionCard(
                icon: Icons.notifications_active_rounded,
                iconColor: FeedFlowColors.primary,
                title: 'Notificações do Sistema',
                description:
                    'Receba alertas em tempo real quando suas fontes publicarem novas notícias ou podcasts com título e publisher.',
                isGranted: notifGranted,
              ),
              const SizedBox(height: 10),

              // Card 2: Áudio e Armazenamento
              _permissionCard(
                icon: Icons.headphones_rounded,
                iconColor: FeedFlowColors.secondary,
                title: 'Mídia e Armazenamento Offline',
                description:
                    'Permite baixar e armazenar episódios de podcasts e capas de artigos para consumo rápido sem internet.',
                isGranted: storageGranted,
              ),
              const SizedBox(height: 10),

              // Card 3: Execução em Segundo Plano
              _permissionCard(
                icon: Icons.battery_charging_full_rounded,
                iconColor: FeedFlowColors.accent,
                title: 'Áudio Contínuo em Segundo Plano',
                description:
                    'Evita que o sistema encerre o podcast quando a tela estiver bloqueada ou em economia de bateria.',
                isGranted: batteryGranted,
              ),
              const SizedBox(height: 26),

              // Botões de Ação
              FilledButton(
                onPressed: _isRequesting ? null : _grantPermissions,
                style: FilledButton.styleFrom(
                  backgroundColor: FeedFlowColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isRequesting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Conceder todas as permissões',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: _isRequesting ? null : _openAppSettings,
                    icon: const Icon(Icons.settings_outlined, size: 16),
                    label: const Text(
                      'Configurações do sistema',
                      style: TextStyle(fontSize: 12.5),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: FeedFlowColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _isRequesting ? null : _skip,
                    style: TextButton.styleFrom(
                      foregroundColor: FeedFlowColors.textSecondary,
                    ),
                    child: const Text(
                      'Pular / Mais tarde',
                      style: TextStyle(fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _permissionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required bool isGranted,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FeedFlowColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGranted
              ? Colors.green.withValues(alpha: 0.4)
              : FeedFlowColors.divider.withValues(alpha: 0.6),
          width: 0.8,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: (isGranted ? Colors.green : iconColor)
                  .withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isGranted ? Icons.check_circle_rounded : icon,
              color: isGranted ? Colors.green : iconColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: FeedFlowColors.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: isGranted
                            ? Colors.green.withValues(alpha: 0.15)
                            : iconColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isGranted ? 'Concedido' : 'Solicitar',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: isGranted ? Colors.green : iconColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: FeedFlowColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
