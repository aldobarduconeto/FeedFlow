import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Utilitários para detecção e suporte a Android TV, Smart TVs e Controles Remotos/Gamepads.
class TvModeService {
  TvModeService._();
  static final TvModeService instance = TvModeService._();

  bool _isTvMode = false;
  bool get isTvMode => _isTvMode;

  /// Ativa/desativa modo TV manualmente ou por detecção
  void setTvMode(bool enabled) {
    _isTvMode = enabled;
  }

  /// Verifica se uma tecla pressionada pertence a um controle de TV ou gamepad
  static bool isTvRemoteKey(LogicalKeyboardKey key) {
    return isDpadKey(key) ||
        isActionKey(key) ||
        isBackKey(key) ||
        isMediaKey(key) ||
        isPagingKey(key);
  }

  /// Teclas direcionais (D-Pad e setas direcionais)
  static bool isDpadKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight;
  }

  /// Teclas de seleção / confirmação (OK / Enter / Gamepad A)
  static bool isActionKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.gameButtonA;
  }

  /// Tecla voltar (Esc / Gamepad B / Android Back)
  static bool isBackKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.gameButtonB ||
        key == LogicalKeyboardKey.goBack;
  }

  /// Teclas dedicadas de mídia (Play/Pause, Seek, etc.) presentes em controles de TV
  static bool isMediaKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.mediaPlayPause ||
        key == LogicalKeyboardKey.mediaPlay ||
        key == LogicalKeyboardKey.mediaPause ||
        key == LogicalKeyboardKey.mediaStop ||
        key == LogicalKeyboardKey.mediaFastForward ||
        key == LogicalKeyboardKey.mediaRewind ||
        key == LogicalKeyboardKey.mediaTrackNext ||
        key == LogicalKeyboardKey.mediaTrackPrevious;
  }

  /// Teclas de paginação / troca rápida de abas (Channel +/-, Page Up/Down, L1/R1)
  static bool isPagingKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.channelUp ||
        key == LogicalKeyboardKey.channelDown ||
        key == LogicalKeyboardKey.pageUp ||
        key == LogicalKeyboardKey.pageDown ||
        key == LogicalKeyboardKey.gameButtonLeft1 ||
        key == LogicalKeyboardKey.gameButtonRight1;
  }

  /// Realiza scroll suave para uso com D-Pad de controle remoto
  static void smoothScroll(ScrollController controller, {required double offsetDelta}) {
    if (!controller.hasClients) return;
    final current = controller.offset;
    final max = controller.position.maxScrollExtent;
    final min = controller.position.minScrollExtent;
    final target = (current + offsetDelta).clamp(min, max);

    controller.animateTo(
      target,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }
}
