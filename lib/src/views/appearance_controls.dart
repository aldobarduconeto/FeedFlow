import 'package:flutter/material.dart';

import '../services/appearance_service.dart';
import 'widget/colors.dart';
import 'widget/tv_focusable.dart';

class AppearanceControls extends StatelessWidget {
  const AppearanceControls({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppearanceService.instance,
      builder: (context, _) {
        final prefs = AppearanceService.instance;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Seletor de Tema Visual em Grid
            Text(
              'TEMA DO APLICATIVO',
              style: TextStyle(
                color: FeedFlowColors.secondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 460;
                return GridView(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isCompact ? 2 : 4,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    mainAxisExtent: isCompact ? 76 : 82,
                  ),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _ThemeOptionCard(
                      id: 'system',
                      label: 'Sistema',
                      description: 'Acompanha o SO',
                      icon: Icons.brightness_auto_rounded,
                      isSelected: prefs.theme == 'system',
                      bgPreview: const Color(0xFF1E293B),
                      accentPreview: const Color(0xFF38BDF8),
                      onSelect: () => prefs.update(theme: 'system'),
                    ),
                    _ThemeOptionCard(
                      id: 'light',
                      label: 'Claro',
                      description: 'Clean & Luminoso',
                      icon: Icons.light_mode_rounded,
                      isSelected: prefs.theme == 'light',
                      bgPreview: const Color(0xFFF8FAFC),
                      accentPreview: const Color(0xFF474AC6),
                      onSelect: () => prefs.update(theme: 'light'),
                    ),
                    _ThemeOptionCard(
                      id: 'dark',
                      label: 'Escuro',
                      description: 'Slate Noturno',
                      icon: Icons.dark_mode_rounded,
                      isSelected: prefs.theme == 'dark',
                      bgPreview: const Color(0xFF0F172A),
                      accentPreview: const Color(0xFF6366F1),
                      onSelect: () => prefs.update(theme: 'dark'),
                    ),
                    _ThemeOptionCard(
                      id: 'oled',
                      label: 'Preto OLED',
                      description: 'AMOLED #000000',
                      icon: Icons.nights_stay_rounded,
                      isSelected: prefs.theme == 'oled',
                      bgPreview: Colors.black,
                      accentPreview: const Color(0xFF22D3EE),
                      onSelect: () => prefs.update(theme: 'oled'),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // Prévia do Leitor em Tempo Real
            Text(
              'PRÉVIA DA LEITURA',
              style: TextStyle(
                color: FeedFlowColors.secondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: prefs.margin.clamp(12, 32),
                vertical: 16,
              ),
              decoration: BoxDecoration(
                color: FeedFlowColors.surfaceElevated.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: FeedFlowColors.divider.withValues(alpha: 0.7),
                  width: 0.8,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Exploração Espacial e Novas Fronteiras',
                    style: TextStyle(
                      fontFamily: prefs.serif ? 'serif' : null,
                      fontSize: (prefs.fontSize * 1.15).clamp(16, 28),
                      fontWeight: FontWeight.bold,
                      color: FeedFlowColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'O telescópio James Webb capturou imagens inéditas de galáxias formadas nos primeiros 400 milhões de anos do universo, revelando detalhes sem precedentes sobre a formação estelar primordial.',
                    textAlign: prefs.alignment,
                    style: TextStyle(
                      fontFamily: prefs.serif ? 'serif' : null,
                      fontSize: prefs.fontSize,
                      color: FeedFlowColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Controles de Tipografia
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tamanho do texto'),
                  Text(
                    '${prefs.fontSize.round()} pt',
                    style: TextStyle(
                      color: FeedFlowColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              subtitle: Slider(
                value: prefs.fontSize,
                min: 14,
                max: 26,
                divisions: 12,
                label: '${prefs.fontSize.round()} pt',
                onChanged: (value) => prefs.update(fontSize: value),
              ),
            ),

            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Margens de leitura'),
                  Text(
                    '${prefs.margin.round()} px',
                    style: TextStyle(
                      color: FeedFlowColors.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              subtitle: Slider(
                value: prefs.margin,
                min: 12,
                max: 48,
                divisions: 9,
                label: '${prefs.margin.round()} px',
                onChanged: (value) => prefs.update(margin: value),
              ),
            ),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.font_download_outlined),
              title: const Text('Tipografia com serifa'),
              subtitle: const Text('Estilo clássico de livro / editorial'),
              value: prefs.serif,
              onChanged: (value) => prefs.update(serif: value),
            ),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.format_align_justify_rounded),
              title: const Text('Texto justificado'),
              subtitle: const Text('Alinhar texto uniformemente nas margens'),
              value: prefs.alignment == TextAlign.justify,
              onChanged: (value) => prefs.update(
                alignment: value ? TextAlign.justify : TextAlign.start,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ThemeOptionCard extends StatelessWidget {
  final String id;
  final String label;
  final String description;
  final IconData icon;
  final bool isSelected;
  final Color bgPreview;
  final Color accentPreview;
  final VoidCallback onSelect;

  const _ThemeOptionCard({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.bgPreview,
    required this.accentPreview,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      onPressed: onSelect,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? FeedFlowColors.primary.withValues(alpha: 0.12)
                : FeedFlowColors.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? FeedFlowColors.primary
                  : FeedFlowColors.divider.withValues(alpha: 0.7),
              width: isSelected ? 1.8 : 0.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Paleta de amostra
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: bgPreview,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: accentPreview,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: FeedFlowColors.primary,
                    )
                  else
                    Icon(
                      icon,
                      size: 16,
                      color: FeedFlowColors.textDisabled,
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? FeedFlowColors.primary
                          : FeedFlowColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 10,
                      color: FeedFlowColors.textDisabled,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
