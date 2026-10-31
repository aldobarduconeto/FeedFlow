import 'package:flutter/material.dart';

import 'colors.dart';
import '../../services/appearance_service.dart';

/// Resolves the cover through Flutter's image cache and keeps the result while
/// playback progress rebuilds the surrounding page.
class CoverBackground extends StatefulWidget {
  CoverBackground({
    required this.imageUrl,
    required this.child,
    this.immersive = false,
    super.key,
  });

  final String? imageUrl;
  final Widget child;
  final bool immersive;

  @override
  State<CoverBackground> createState() => _CoverBackgroundState();
}

class _CoverBackgroundState extends State<CoverBackground> {
  Color _color = FeedFlowColors.background;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(CoverBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) _resolve();
  }

  Future<void> _resolve() async {
    final request = ++_request;
    _color = FeedFlowColors.background;
    final url = widget.imageUrl;
    if (url == null || url.isEmpty) return;
    try {
      final scheme = await ColorScheme.fromImageProvider(
        provider: NetworkImage(url),
        brightness: Brightness.dark,
        dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
      );
      if (!mounted || request != _request) return;
      setState(() {
        _color = HSLColor.fromColor(scheme.primaryContainer)
            .withLightness(0.18)
            .toColor();
      });
    } catch (_) {
      // A missing image or a web CORS restriction uses the default background.
    }
  }

  @override
  Widget build(BuildContext context) {
    final light = AppearanceService.instance.theme == 'light';
    final oled = AppearanceService.instance.theme == 'oled';
    final top = widget.immersive
        ? HSLColor.fromColor(_color).withLightness(0.24).toColor()
        : oled
        ? Colors.black
        : light
        ? HSLColor.fromColor(_color).withLightness(0.93).toColor()
        : _color;
    final bottom = widget.immersive
        ? HSLColor.fromColor(_color).withLightness(0.16).toColor()
        : light
        ? HSLColor.fromColor(_color).withLightness(0.98).toColor()
        : oled
        ? Colors.black
        : HSLColor.fromColor(_color).withLightness(0.07).toColor();
    return AnimatedContainer(
      duration: Duration(milliseconds: 450),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ),
      ),
      child: widget.child,
    );
  }
}
