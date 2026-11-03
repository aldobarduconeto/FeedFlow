import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Serviço responsável por gerenciar e solicitar todas as permissões necessárias
/// para o funcionamento pleno do FeedFlow nas diferentes plataformas.
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

  /// Solicita todas as permissões essenciais que o FeedFlow precisa em todos os sistemas:
  /// 1. Notificações (avisar quando notícias e novos podcasts forem publicados)
  /// 2. Armazenamento e Mídia/Áudio (armazenamento e download de episódios offline)
  /// 3. Otimização de bateria (para manter podcasts tocando em segundo plano sem corte)
  Future<Map<String, bool>> requestAllPermissions() async {
    final results = <String, bool>{};

    if (kIsWeb) {
      // Plataforma web possui modelo de permissões diferente do nativo
      results['notification'] = true;
      results['storage'] = true;
      results['audio'] = true;
      results['batteryOptimization'] = true;
      await markPermissionsRequested();
      return results;
    }

    // 1. Notificações do Sistema
    try {
      final notifStatus = await Permission.notification.request();
      results['notification'] = notifStatus.isGranted;
    } catch (e) {
      debugPrint('Permissão de notificação não suportada nesta plataforma: $e');
      results['notification'] = true;
    }

    // 2. Mídia de Áudio (Android 13+ / API 33+)
    try {
      final audioStatus = await Permission.audio.request();
      results['audio'] = audioStatus.isGranted;
    } catch (e) {
      debugPrint('Permissão de áudio não aplicável: $e');
      results['audio'] = true;
    }

    // 3. Armazenamento tradicional (Android <= 12 e outros sistemas)
    try {
      final storageStatus = await Permission.storage.request();
      results['storage'] = storageStatus.isGranted;
    } catch (e) {
      debugPrint('Permissão de armazenamento não aplicável: $e');
      results['storage'] = true;
    }

    // 4. Isenção de Otimização de Bateria (Android para áudio contínuo em segundo plano)
    try {
      final batteryStatus =
          await Permission.ignoreBatteryOptimizations.request();
      results['batteryOptimization'] = batteryStatus.isGranted;
    } catch (e) {
      debugPrint('Permissão de otimização de bateria não aplicável: $e');
      results['batteryOptimization'] = true;
    }

    // Marca como solicitado após o fluxo
    await markPermissionsRequested();
    return results;
  }

  /// Verifica o status atual de cada permissão no sistema sem exibir diálogo de solicitação.
  Future<Map<String, bool>> checkAllPermissions() async {
    if (kIsWeb) {
      return {
        'notification': true,
        'storage': true,
        'audio': true,
        'batteryOptimization': true,
      };
    }

    bool notifGranted = false;
    bool storageGranted = false;
    bool audioGranted = false;
    bool batteryGranted = false;

    try {
      notifGranted = await Permission.notification.isGranted;
    } catch (_) {
      notifGranted = true;
    }

    try {
      audioGranted = await Permission.audio.isGranted;
    } catch (_) {
      audioGranted = true;
    }

    try {
      storageGranted = await Permission.storage.isGranted;
    } catch (_) {
      storageGranted = true;
    }

    try {
      batteryGranted = await Permission.ignoreBatteryOptimizations.isGranted;
    } catch (_) {
      batteryGranted = true;
    }

    return {
      'notification': notifGranted,
      'storage': storageGranted,
      'audio': audioGranted,
      'batteryOptimization': batteryGranted,
    };
  }

  /// Verifica o status atual da permissão de notificação.
  Future<bool> isNotificationGranted() async {
    if (kIsWeb) return true;
    try {
      return await Permission.notification.isGranted;
    } catch (_) {
      return true;
    }
  }

  /// Solicita especificamente a permissão de notificações.
  Future<bool> requestNotificationPermission() async {
    if (kIsWeb) return true;
    try {
      final status = await Permission.notification.request();
      return status.isGranted;
    } catch (_) {
      return true;
    }
  }

  /// Solicita especificamente as permissões de armazenamento e mídia.
  Future<bool> requestStorageAndMediaPermissions() async {
    if (kIsWeb) return true;
    try {
      final audioStatus = await Permission.audio.request();
      final storageStatus = await Permission.storage.request();
      return audioStatus.isGranted || storageStatus.isGranted;
    } catch (_) {
      return true;
    }
  }

  /// Solicita isenção de otimização de bateria para podcast em segundo plano.
  Future<bool> requestBatteryOptimizationExemption() async {
    if (kIsWeb) return true;
    try {
      final status = await Permission.ignoreBatteryOptimizations.request();
      return status.isGranted;
    } catch (_) {
      return true;
    }
  }

  /// Abre a tela de configurações do sistema para que o usuário ajuste permissões manualmente.
  Future<bool> openSettings() async {
    try {
      return await openAppSettings();
    } catch (_) {
      return false;
    }
  }
}
