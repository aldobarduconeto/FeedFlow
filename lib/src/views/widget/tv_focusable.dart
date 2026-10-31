import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/tv_mode_service.dart';
import 'colors.dart';

/// Widget que fornece realce visual e suporte completo a controle remoto de TV / Gamepad.
class TvFocusable extends StatefulWidget {
  const TvFocusable({
    required this.child,
    this.onPressed,
    this.focusNode,
    this.autofocus = false,
    this.borderRadius,
    this.focusBorderColor,
    this.scaleFactor = 1.02,
    this.showGlow = true,
    this.padding,
    super.key,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final FocusNode? focusNode;
  final bool autofocus;
  final BorderRadius? borderRadius;
  final Color? focusBorderColor;
  final double scaleFactor;
  final bool showGlow;
  final EdgeInsetsGeometry? padding;

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(TvFocusable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != null && widget.focusNode != _focusNode) {
      _focusNode.removeListener(_onFocusChange);
      _focusNode = widget.focusNode!;
      _focusNode.addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    } else {
      _focusNode.removeListener(_onFocusChange);
    }
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus != _isFocused) {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
      if (_isFocused && mounted) {
        Scrollable.ensureVisible(
          context,
          alignment: 0.5,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutQuad,
        );
      }
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (TvModeService.isActionKey(event.logicalKey)) {
        if (widget.onPressed != null) {
          widget.onPressed!();
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(16);
    final borderColor = widget.focusBorderColor ?? FeedFlowColors.primary;

    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: _handleKeyEvent,
      child: AnimatedScale(
        scale: _isFocused ? widget.scaleFactor : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutQuad,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: widget.padding,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: _isFocused
                ? Border.all(color: borderColor, width: 2.2)
                : Border.all(color: Colors.transparent, width: 2.2),
            boxShadow: _isFocused && widget.showGlow
                ? [
                    BoxShadow(
                      color: borderColor.withValues(alpha: 0.45),
                      blurRadius: 14,
                      spreadRadius: 1.5,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
