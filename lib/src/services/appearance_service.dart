import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppearanceService extends ChangeNotifier with WidgetsBindingObserver {
  AppearanceService._();
  static final instance = AppearanceService._();
  SharedPreferences? _prefs;

  /// Temas disponíveis:
  /// - 'system': segue o tema do sistema operacional
  /// - 'light': tema claro limpo
  /// - 'dark': tema escuro suave (ardósia/azul escuro)
  /// - 'oled': tema preto absoluto (#000000) para telas OLED/AMOLED
  String theme = 'system';
  double fontSize = 17;
  double margin = 20;
  bool serif = false;
  TextAlign alignment = TextAlign.start;

  /// Retorna o tema ativo resolvido ('light', 'dark' ou 'oled')
  String get effectiveTheme {
    if (theme == 'system') {
      final brightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      return brightness == Brightness.dark ? 'dark' : 'light';
    }
    return theme;
  }

  bool get isLight => effectiveTheme == 'light';
  bool get isDark => effectiveTheme == 'dark';
  bool get isOled => effectiveTheme == 'oled';
  bool get isAnyDark => isDark || isOled;

  ThemeMode get themeMode {
    switch (theme) {
      case 'system':
        return ThemeMode.system;
      case 'light':
        return ThemeMode.light;
      case 'dark':
      case 'oled':
      default:
        return ThemeMode.dark;
    }
  }

  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);
    _prefs = await SharedPreferences.getInstance();
    final savedTheme = _prefs!.getString('appearance.theme');
    theme = ['system', 'light', 'dark', 'oled'].contains(savedTheme)
        ? savedTheme!
        : 'system';
    fontSize = (_prefs!.getDouble('appearance.font') ?? 17).clamp(14, 26);
    margin = (_prefs!.getDouble('appearance.margin') ?? 20).clamp(12, 48);
    serif = _prefs!.getBool('appearance.serif') ?? false;
    final align = _prefs!.getString('appearance.align');
    alignment = align == 'justify' ? TextAlign.justify : TextAlign.start;
    notifyListeners();
  }

  @override
  void didChangePlatformBrightness() {
    if (theme == 'system') {
      notifyListeners();
    }
  }

  Future<void> update({
    String? theme,
    double? fontSize,
    double? margin,
    bool? serif,
    TextAlign? alignment,
  }) async {
    this.theme = theme ?? this.theme;
    this.fontSize = fontSize ?? this.fontSize;
    this.margin = margin ?? this.margin;
    this.serif = serif ?? this.serif;
    this.alignment = alignment ?? this.alignment;
    notifyListeners();
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    await prefs.setString('appearance.theme', this.theme);
    await prefs.setDouble('appearance.font', this.fontSize);
    await prefs.setDouble('appearance.margin', this.margin);
    await prefs.setBool('appearance.serif', this.serif);
    await prefs.setString(
      'appearance.align',
      this.alignment == TextAlign.justify ? 'justify' : 'start',
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
