import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppearanceService extends ChangeNotifier {
  AppearanceService._();
  static final instance = AppearanceService._();
  SharedPreferences? _prefs;
  String theme = 'dark';
  double fontSize = 17;
  double margin = 20;
  bool serif = false;
  TextAlign alignment = TextAlign.start;
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    final savedTheme = _prefs!.getString('appearance.theme');
    theme = ['light', 'dark', 'oled'].contains(savedTheme)
        ? savedTheme!
        : 'dark';
    fontSize = (_prefs!.getDouble('appearance.font') ?? 17).clamp(14, 26);
    margin = (_prefs!.getDouble('appearance.margin') ?? 20).clamp(12, 48);
    serif = _prefs!.getBool('appearance.serif') ?? false;
    final align = _prefs!.getString('appearance.align');
    alignment = align == 'justify' ? TextAlign.justify : TextAlign.start;
    notifyListeners();
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
}
