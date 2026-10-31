import '../../services/appearance_service.dart';

import 'package:flutter/material.dart';

/// Paleta de cores oficial do FeedFlow com suporte a Claro, Escuro e Preto Puro OLED.
abstract final class FeedFlowColors {
  // Marca
  static Color get primary => AppearanceService.instance.isLight
      ? const Color(0xFF474AC6)
      : const Color(0xFF6366F1);
  static Color get secondary => AppearanceService.instance.isLight
      ? const Color(0xFF1D5DA8)
      : const Color(0xFF60A5FA);
  static Color get accent => AppearanceService.instance.isLight
      ? const Color(0xFF007587)
      : const Color(0xFF22D3EE);

  // Fundos
  static Color get background => AppearanceService.instance.isLight
      ? const Color(0xFFF8FAFC)
      : AppearanceService.instance.isOled
          ? Colors.black
          : const Color(0xFF080B14);

  static Color get surface => AppearanceService.instance.isLight
      ? const Color(0xFFFFFFFF)
      : AppearanceService.instance.isOled
          ? const Color(0xFF070707)
          : const Color(0xFF0F172A);

  static Color get surfaceElevated => AppearanceService.instance.isLight
      ? const Color(0xFFF1F5F9)
      : AppearanceService.instance.isOled
          ? const Color(0xFF111111)
          : const Color(0xFF182238);

  static Color get surfaceHighlight => AppearanceService.instance.isLight
      ? const Color(0xFFE2E8F0)
      : AppearanceService.instance.isOled
          ? const Color(0xFF1A1A1A)
          : const Color(0xFF222E47);

  // Textos
  static Color get textPrimary => AppearanceService.instance.isLight
      ? const Color(0xFF0F172A)
      : const Color(0xFFF1F5F9);

  static Color get textSecondary => AppearanceService.instance.isLight
      ? const Color(0xFF475569)
      : AppearanceService.instance.isOled
          ? const Color(0xFFA1A1AA)
          : const Color(0xFF94A3B8);

  static Color get textDisabled => AppearanceService.instance.isLight
      ? const Color(0xFF94A3B8)
      : AppearanceService.instance.isOled
          ? const Color(0xFF71717A)
          : const Color(0xFF64748B);

  // Estados
  static Color get success => AppearanceService.instance.isLight
      ? const Color(0xFF16A34A)
      : const Color(0xFF34D399);
  static Color get warning => AppearanceService.instance.isLight
      ? const Color(0xFFD97706)
      : const Color(0xFFFBBF24);
  static Color get error => AppearanceService.instance.isLight
      ? const Color(0xFFDC2626)
      : const Color(0xFFF87171);
  static Color get info => AppearanceService.instance.isLight
      ? const Color(0xFF2563EB)
      : const Color(0xFF60A5FA);

  // Elementos
  static Color get divider => AppearanceService.instance.isLight
      ? const Color(0xFFE2E8F0)
      : AppearanceService.instance.isOled
          ? const Color(0xFF262626)
          : const Color(0xFF263247);

  static Color get outline => AppearanceService.instance.isLight
      ? const Color(0xFFCBD5E1)
      : AppearanceService.instance.isOled
          ? const Color(0xFF333333)
          : const Color(0xFF334155);
}

/// Tema do FeedFlow a partir da preferência de aparência.
abstract final class FeedFlowTheme {
  static ColorScheme get _colorScheme {
    if (AppearanceService.instance.isLight) {
      return ColorScheme.light(
        primary: FeedFlowColors.primary,
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFFE0E1FF),
        onPrimaryContainer: const Color(0xFF191A54),
        secondary: FeedFlowColors.secondary,
        onSecondary: Colors.white,
        secondaryContainer: const Color(0xFFDCEBFF),
        onSecondaryContainer: const Color(0xFF0A2540),
        tertiary: FeedFlowColors.accent,
        onTertiary: Colors.white,
        surface: FeedFlowColors.surface,
        onSurface: FeedFlowColors.textPrimary,
        error: FeedFlowColors.error,
        onError: Colors.white,
        outline: FeedFlowColors.outline,
        outlineVariant: FeedFlowColors.divider,
        surfaceContainerLowest: FeedFlowColors.background,
        surfaceContainerLow: const Color(0xFFF1F5F9),
        surfaceContainer: FeedFlowColors.surface,
        surfaceContainerHigh: FeedFlowColors.surfaceElevated,
        surfaceContainerHighest: FeedFlowColors.surfaceHighlight,
      );
    }

    if (AppearanceService.instance.isOled) {
      return ColorScheme.dark(
        primary: FeedFlowColors.primary,
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFF24265A),
        onPrimaryContainer: const Color(0xFFE0E1FF),
        secondary: FeedFlowColors.secondary,
        onSecondary: Colors.black,
        secondaryContainer: const Color(0xFF152A45),
        onSecondaryContainer: const Color(0xFFDCEBFF),
        tertiary: FeedFlowColors.accent,
        onTertiary: Colors.black,
        surface: Colors.black,
        onSurface: Colors.white,
        error: FeedFlowColors.error,
        onError: Colors.black,
        outline: FeedFlowColors.outline,
        outlineVariant: FeedFlowColors.divider,
        surfaceContainerLowest: Colors.black,
        surfaceContainerLow: Colors.black,
        surfaceContainer: const Color(0xFF080808),
        surfaceContainerHigh: const Color(0xFF121212),
        surfaceContainerHighest: const Color(0xFF1C1C1C),
      );
    }

    return ColorScheme.dark(
      primary: FeedFlowColors.primary,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFF292B68),
      onPrimaryContainer: const Color(0xFFE0E1FF),
      secondary: FeedFlowColors.secondary,
      onSecondary: const Color(0xFF071426),
      secondaryContainer: const Color(0xFF1E3A5F),
      onSecondaryContainer: const Color(0xFFDCEBFF),
      tertiary: FeedFlowColors.accent,
      onTertiary: const Color(0xFF00363D),
      surface: FeedFlowColors.surface,
      onSurface: FeedFlowColors.textPrimary,
      error: FeedFlowColors.error,
      onError: const Color(0xFF450A0A),
      outline: FeedFlowColors.outline,
      outlineVariant: FeedFlowColors.divider,
      surfaceContainerLowest: FeedFlowColors.background,
      surfaceContainerLow: const Color(0xFF111827),
      surfaceContainer: FeedFlowColors.surface,
      surfaceContainerHigh: FeedFlowColors.surfaceElevated,
      surfaceContainerHighest: FeedFlowColors.surfaceHighlight,
    );
  }

  static ThemeData get current => dark;

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: AppearanceService.instance.isLight
          ? Brightness.light
          : Brightness.dark,
      colorScheme: _colorScheme,
      scaffoldBackgroundColor: FeedFlowColors.background,
      canvasColor: FeedFlowColors.background,
      dividerColor: FeedFlowColors.divider,
      // Tipografia
      fontFamily: 'Inter',
      textTheme: TextTheme(
        displayLarge: TextStyle(
          color: FeedFlowColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        headlineLarge: TextStyle(
          color: FeedFlowColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: TextStyle(
          color: FeedFlowColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          color: FeedFlowColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: FeedFlowColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(color: FeedFlowColors.textPrimary),
        bodyMedium: TextStyle(color: FeedFlowColors.textSecondary),
        bodySmall: TextStyle(color: FeedFlowColors.textSecondary),
        labelLarge: const TextStyle(fontWeight: FontWeight.w600),
      ),
      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: FeedFlowColors.background,
        foregroundColor: FeedFlowColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      // Cards
      cardTheme: CardThemeData(
        color: FeedFlowColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: FeedFlowColors.divider, width: 0.5),
        ),
      ),
      // Campos de texto
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: FeedFlowColors.surfaceElevated,
        hintStyle: TextStyle(color: FeedFlowColors.textDisabled),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: FeedFlowColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: FeedFlowColors.primary, width: 1.5),
        ),
      ),
      // Botões principais
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: FeedFlowColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: FeedFlowColors.surfaceHighlight,
          disabledForegroundColor: FeedFlowColors.textDisabled,
          elevation: 0,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      // Botões de texto
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: FeedFlowColors.secondary),
      ),
      // Ícones
      iconTheme: IconThemeData(color: FeedFlowColors.textSecondary, size: 24),
      // Navegação inferior
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: FeedFlowColors.surface,
        indicatorColor: FeedFlowColors.primary.withValues(alpha: 0.22),
        elevation: 0,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: FeedFlowColors.secondary);
          }
          return IconThemeData(color: FeedFlowColors.textSecondary);
        }),
      ),
      // Divisores
      dividerTheme: DividerThemeData(
        color: FeedFlowColors.divider,
        thickness: 0.7,
        space: 1,
      ),
      // SnackBars
      snackBarTheme: SnackBarThemeData(
        backgroundColor: FeedFlowColors.surfaceHighlight,
        contentTextStyle: TextStyle(color: FeedFlowColors.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      // Seleção de texto
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: Color(0xFF60A5FA),
        selectionColor: Color(0x666366F1),
        selectionHandleColor: Color(0xFF60A5FA),
      ),
      // Progresso
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: FeedFlowColors.secondary,
        linearTrackColor: FeedFlowColors.surfaceHighlight,
      ),
      // Chips Modernos
      chipTheme: ChipThemeData(
        backgroundColor: FeedFlowColors.surfaceElevated,
        selectedColor: FeedFlowColors.primary.withValues(alpha: 0.16),
        disabledColor: FeedFlowColors.surfaceHighlight.withValues(alpha: 0.4),
        labelStyle: TextStyle(
          color: FeedFlowColors.textPrimary,
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: TextStyle(
          color: FeedFlowColors.primary,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: FeedFlowColors.divider.withValues(alpha: 0.7),
            width: 0.8,
          ),
        ),
        showCheckmark: false,
        elevation: 0,
        pressElevation: 0,
      ),
      // Popups / Menus Modernos
      popupMenuTheme: PopupMenuThemeData(
        color: FeedFlowColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 10,
        shadowColor: Colors.black.withValues(alpha: 0.35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: FeedFlowColors.divider.withValues(alpha: 0.75),
            width: 0.8,
          ),
        ),
        textStyle: TextStyle(
          color: FeedFlowColors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      // Diálogos Modernos
      dialogTheme: DialogThemeData(
        backgroundColor: FeedFlowColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 14,
        shadowColor: Colors.black.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: FeedFlowColors.divider.withValues(alpha: 0.7),
            width: 0.8,
          ),
        ),
        titleTextStyle: TextStyle(
          color: FeedFlowColors.textPrimary,
          fontSize: 18.5,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      // BottomSheet Moderno
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: FeedFlowColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 16,
        modalBackgroundColor: FeedFlowColors.surfaceElevated,
        modalElevation: 16,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        dragHandleColor: FeedFlowColors.outline.withValues(alpha: 0.4),
        dragHandleSize: const Size(38, 4.5),
      ),
      // Sliders
      sliderTheme: SliderThemeData(
        activeTrackColor: FeedFlowColors.secondary,
        inactiveTrackColor: FeedFlowColors.surfaceHighlight,
        thumbColor: Colors.white,
        trackHeight: 4,
      ),
    );
  }
}
