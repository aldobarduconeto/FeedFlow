import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PermissionService {
  static const _firstLaunchKey = 'feedflow.permissions_requested.v1';

  /// Verifica se é a primeira vez que o aplicativo é aberto.
  Future<bool> isFirstLaunch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return !(prefs.getBool(_firstLaunchKey) ?? false);
    } catch (_) {
      return false;
    }
  }

  /// Registra que a solicitação inicial de permissões foi realizada.
  Future<void> markPermissionsRequested() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_firstLaunchKey, true);
    } catch (e) {
      debugPrint('Erro ao salvar flag de permissões: $e');
    }
  }

  /// Solicita todas as permissões essenciais que o FeedFlow precisa.
  Future<Map<String, bool>> requestAllPermissions() async {
    final results = <String, bool>{};

    try {
      // 1. Notificações (para avisar quando novas notícias/podcasts forem publicados)
      final notifStatus = await Permission.notification.request();
      results['notification'] = notifStatus.isGranted;
    } catch (e) {
      debugPrint('Permissão de notificação não suportada nesta plataforma: $e');
      results['notification'] = true;
    }

    // Marca como solicitado após o fluxo
    await markPermissionsRequested();
    return results;
  }

  /// Verifica o status atual da permissão de notificação
  Future<bool> isNotificationGranted() async {
    try {
      return await Permission.notification.isGranted;
    } catch (_) {
      return true;
    }
  }

  /// Abre as configurações do sistema para o usuário ajustar permissões manualmente se necessário
  Future<bool> openSettings() async {
    try {
      return await openAppSettings();
    } catch (_) {
      return false;
    }
  }
}
