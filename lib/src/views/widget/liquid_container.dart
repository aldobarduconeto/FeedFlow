import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/appearance_service.dart';
import 'colors.dart';

/// Container com efeito de vidro líquido (Liquid Glass / Frosted Glass),
/// contendo desfoque suave, borda com reflexo de luz e sombras orgânicas.
class LiquidContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final double blurSigma;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final VoidCallback? onTap;

  const LiquidContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius,
    this.backgroundColor,
    this.blurSigma = 16.0,
    this.border,
    this.boxShadow,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.circular(22);
    final isOled = AppearanceService.instance.isOled;
    final isLight = AppearanceService.instance.isLight;

    final defaultBg = isOled
        ? Colors.black.withValues(alpha: 0.92)
        : isLight
            ? FeedFlowColors.surface.withValues(alpha: 0.88)
            : FeedFlowColors.surfaceElevated.withValues(alpha: 0.75);

    final defaultBorder = Border.all(
      color: isOled
          ? const Color(0xFF262626)
          : isLight
              ? Colors.black.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.12),
      width: 0.8,
    );

    Widget content = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? defaultBg,
        borderRadius: effectiveRadius,
        border: border ?? defaultBorder,
      ),
      child: child,
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: effectiveRadius,
          child: content,
        ),
      );
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: effectiveRadius,
        boxShadow: boxShadow ??
            [
              BoxShadow(
                color: Colors.black.withValues(alpha: isLight ? 0.06 : 0.12),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
              if (!isOled)
                BoxShadow(
                  color: FeedFlowColors.primary.withValues(alpha: 0.05),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
            ],
      ),
      child: ClipRRect(
        borderRadius: effectiveRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: content,
        ),
      ),
    );
  }
}

/// Orbes de luz líquida difusa para o fundo do aplicativo, criando
/// profundidade orgânica quando os cartões líquidos passam por cima.
/// Em modo OLED, é desativado para garantir 100% de pixels pretos puros (#000000).
class LiquidBackgroundOrbs extends StatelessWidget {
  const LiquidBackgroundOrbs({super.key});

  @override
  Widget build(BuildContext context) {
    if (AppearanceService.instance.isOled) {
      return const SizedBox.shrink();
    }

    final isLight = AppearanceService.instance.isLight;

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Orbe de luz primária (Superior Direito)
          Positioned(
            top: -120,
            right: -100,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    FeedFlowColors.primary.withValues(
                      alpha: isLight ? 0.08 : 0.13,
                    ),
                    FeedFlowColors.primary.withValues(
                      alpha: isLight ? 0.02 : 0.04,
                    ),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
          // Orbe de luz secundária (Inferior Esquerdo)
          Positioned(
            bottom: 40,
            left: -120,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    FeedFlowColors.accent.withValues(
                      alpha: isLight ? 0.06 : 0.1,
                    ),
                    FeedFlowColors.secondary.withValues(
                      alpha: isLight ? 0.02 : 0.03,
                    ),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra de navegação flutuante fluida (Floating Liquid Dock)
class LiquidFloatingDock extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final List<LiquidDockItem> items;

  const LiquidFloatingDock({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final isOled = AppearanceService.instance.isOled;
    final isLight = AppearanceService.instance.isLight;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: LiquidContainer(
        borderRadius: BorderRadius.circular(32),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        backgroundColor: isOled
            ? Colors.black.withValues(alpha: 0.95)
            : isLight
                ? FeedFlowColors.surface.withValues(alpha: 0.92)
                : FeedFlowColors.surface.withValues(alpha: 0.82),
        blurSigma: 20,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isLight ? 0.08 : 0.22),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          if (!isOled)
            BoxShadow(
              color: FeedFlowColors.primary.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
        ],
        border: Border.all(
          color: isOled
              ? const Color(0xFF2E2E2E)
              : isLight
                  ? Colors.black.withValues(alpha: 0.09)
                  : Colors.white.withValues(alpha: 0.14),
          width: 0.8,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (var i = 0; i < items.length; i++)
              _buildItem(context, i, items[i]),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, int index, LiquidDockItem item) {
    final isSelected = selectedIndex == index;
    return InkWell(
      onTap: () => onItemSelected(index),
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 18 : 14,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? FeedFlowColors.primary.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: isSelected
              ? Border.all(
                  color: FeedFlowColors.primary.withValues(alpha: 0.5),
                  width: 0.8,
                )
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? item.selectedIcon : item.icon,
              size: 21,
              color: isSelected
                  ? FeedFlowColors.primary
                  : FeedFlowColors.textSecondary,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: FeedFlowColors.primary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class LiquidDockItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const LiquidDockItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}
