import 'package:flutter/material.dart';

import '../services/appearance_service.dart';

class AppearanceControls extends StatelessWidget {
  AppearanceControls({super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: AppearanceService.instance,
    builder: (context, _) {
      final prefs = AppearanceService.instance;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            key: ValueKey(prefs.theme),
            initialValue: prefs.theme,
            decoration: InputDecoration(labelText: 'Tema'),
            items: [
              DropdownMenuItem(value: 'light', child: Text('Claro')),
              DropdownMenuItem(value: 'dark', child: Text('Escuro')),
              DropdownMenuItem(value: 'oled', child: Text('Preto OLED')),
            ],
            onChanged: (value) => prefs.update(theme: value),
          ),
          SizedBox(height: 12),
          ListTile(
            title: Text('Tamanho do texto'),
            subtitle: Slider(
              value: prefs.fontSize,
              min: 14,
              max: 26,
              divisions: 12,
              label: prefs.fontSize.round().toString(),
              onChanged: (value) => prefs.update(fontSize: value),
            ),
          ),
          SwitchListTile(
            title: Text('Fonte com serifa'),
            value: prefs.serif,
            onChanged: (value) => prefs.update(serif: value),
          ),
          ListTile(
            title: Text('Margens da leitura'),
            subtitle: Slider(
              value: prefs.margin,
              min: 12,
              max: 48,
              divisions: 9,
              label: prefs.margin.round().toString(),
              onChanged: (value) => prefs.update(margin: value),
            ),
          ),
          SwitchListTile(
            title: Text('Texto justificado'),
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
