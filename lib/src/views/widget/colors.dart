import 'package:flutter/material.dart';

/// Paleta de cores oficial do FeedFlow.
abstract final class FeedFlowColors {
  // Marca
  static const Color primary = Color(0xFF6366F1);
  static const Color secondary = Color(0xFF60A5FA);
  static const Color accent = Color(0xFF22D3EE);
  // Fundos
  static const Color background = Color(0xFF080B14);
  static const Color surface = Color(0xFF0F172A);
  static const Color surfaceElevated = Color(0xFF182238);
  static const Color surfaceHighlight = Color(0xFF222E47);
  // Textos
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textDisabled = Color(0xFF64748B);
  // Estados
  static const Color success = Color(0xFF34D399);
  static const Color warning = Color(0xFFFBBF24);
  static const Color error = Color(0xFFF87171);
  static const Color info = Color(0xFF60A5FA);
  // Elementos
  static const Color divider = Color(0xFF263247);
  static const Color outline = Color(0xFF334155);
}

/// Tema exclusivamente escuro do FeedFlow.
abstract final class FeedFlowTheme {
  static const ColorScheme _colorScheme = ColorScheme.dark(
    primary: FeedFlowColors.primary,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFF292B68),
    onPrimaryContainer: Color(0xFFE0E1FF),
    secondary: FeedFlowColors.secondary,
    onSecondary: Color(0xFF071426),
    secondaryContainer: Color(0xFF1E3A5F),
    onSecondaryContainer: Color(0xFFDCEBFF),
    tertiary: FeedFlowColors.accent,
    onTertiary: Color(0xFF00363D),
    surface: FeedFlowColors.surface,
    onSurface: FeedFlowColors.textPrimary,
    error: FeedFlowColors.error,
    onError: Color(0xFF450A0A),
    outline: FeedFlowColors.outline,
    outlineVariant: FeedFlowColors.divider,
    surfaceContainerLowest: FeedFlowColors.background,
    surfaceContainerLow: Color(0xFF111827),
    surfaceContainer: FeedFlowColors.surface,
    surfaceContainerHigh: FeedFlowColors.surfaceElevated,
    surfaceContainerHighest: FeedFlowColors.surfaceHighlight,
  );
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: _colorScheme,
      scaffoldBackgroundColor: FeedFlowColors.background,
      canvasColor: FeedFlowColors.background,
      dividerColor: FeedFlowColors.divider,
      // Tipografia
      fontFamily: 'Inter',
      textTheme: const TextTheme(
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
        bodyLarge: TextStyle(
          color: FeedFlowColors.textPrimary,
        ),
        bodyMedium: TextStyle(
          color: FeedFlowColors.textSecondary,
        ),
        bodySmall: TextStyle(
          color: FeedFlowColors.textSecondary,
        ),
        labelLarge: TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
      // AppBar
      appBarTheme: const AppBarTheme(
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
          side: const BorderSide(color: FeedFlowColors.divider, width: 0.5),
        ),
      ),
      // Campos de texto
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: FeedFlowColors.surfaceElevated,
        hintStyle: const TextStyle(color: FeedFlowColors.textDisabled),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: FeedFlowColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: FeedFlowColors.primary,
            width: 1.5,
          ),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      // Botões de texto
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: FeedFlowColors.secondary),
      ),
      // Ícones
      iconTheme: const IconThemeData(color: FeedFlowColors.textSecondary, size: 24),
      // Navegação inferior
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: FeedFlowColors.surface,
        indicatorColor: FeedFlowColors.primary.withValues(alpha: 0.22),
        elevation: 0,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: FeedFlowColors.secondary);
          }
          return const IconThemeData(color: FeedFlowColors.textSecondary);
        }),
      ),
      // Divisores
      dividerTheme: const DividerThemeData(
        color: FeedFlowColors.divider,
        thickness: 0.7,
        space: 1,
      ),
      // SnackBars
      snackBarTheme: SnackBarThemeData(
        backgroundColor: FeedFlowColors.surfaceHighlight,
        contentTextStyle: const TextStyle(color: FeedFlowColors.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      // Seleção de texto
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: FeedFlowColors.secondary,
        selectionColor: Color(0x666366F1),
        selectionHandleColor: FeedFlowColors.secondary,
      ),
      // Progresso
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: FeedFlowColors.secondary,
        linearTrackColor: FeedFlowColors.surfaceHighlight,
      ),
    );
  }
}