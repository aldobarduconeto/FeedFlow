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

  Future<void> _grantPermissions() async {
    setState(() => _isRequesting = true);
    try {
      await widget.permissionService.requestAllPermissions();
    } finally {
      if (mounted) {
        widget.onCompleted();
      }
    }
  }

  Future<void> _skip() async {
    await widget.permissionService.markPermissionsRequested();
    if (mounted) {
      widget.onCompleted();
    }
  }

  @override
  Widget build(BuildContext context) {
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
                'Bem-vindo ao FeedFlow',
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
                'Para oferecer a melhor experiência com notícias e podcasts, precisamos de algumas permissões do seu dispositivo:',
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
                title: 'Notificações de Publicações',
                description:
                    'Avisa imediatamente quando uma notícia ou episódio for publicado, com o título e publisher.',
                badge: 'Importante',
              ),
              const SizedBox(height: 10),

              // Card 2: Áudio e Mídia
              _permissionCard(
                icon: Icons.headphones_rounded,
                iconColor: FeedFlowColors.secondary,
                title: 'Áudio em Segundo Plano',
                description:
                    'Reproduz podcasts com a tela desligada ou enquanto você utiliza outros aplicativos.',
              ),
              const SizedBox(height: 10),

              // Card 3: Armazenamento e Offline
              _permissionCard(
                icon: Icons.download_for_offline_rounded,
                iconColor: FeedFlowColors.accent,
                title: 'Downloads e Armazenamento',
                description:
                    'Permite baixar episódios completos de podcasts para ouvir quando estiver offline.',
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
                        'Conceder permissões e continuar',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _isRequesting ? null : _skip,
                style: TextButton.styleFrom(
                  foregroundColor: FeedFlowColors.textSecondary,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Agora não / Continuar depois',
                  style: TextStyle(fontSize: 13),
                ),
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
    String? badge,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FeedFlowColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: FeedFlowColors.divider.withValues(alpha: 0.6),
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
              color: iconColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
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
                    if (badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: iconColor,
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
