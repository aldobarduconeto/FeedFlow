import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  AuthService({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? _createSecureStorage();

  static const _accountsKey = 'feedflow.auth.accounts.v1';
  static const _activeUserIdKey = 'feedflow.auth.userId.v1';
  static const _passwordKeyPrefix = 'feedflow.auth.password.v1.';
  static const _legacyFeedDataKey = 'feedflow.data.v1';

  final FlutterSecureStorage _secureStorage;

  static FlutterSecureStorage _createSecureStorage() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
      // Use the legacy macOS Keychain to avoid requiring Keychain Sharing
      // provisioning for an app that does not share credentials with other apps.
      return const FlutterSecureStorage(
        mOptions: MacOsOptions(usesDataProtectionKeychain: false),
      );
    }
    return const FlutterSecureStorage();
  }

  Future<String?> restoreSession() async {
    final preferences = await SharedPreferences.getInstance();
    final userId = preferences.getString(_activeUserIdKey);
    if (userId == null) return null;

    final accounts = _readAccounts(preferences);
    if (!accounts.any(
          (account) =>
              account['id'] == userId && account['username']!.isNotEmpty,
        ) ||
        await _secureStorage.read(key: '$_passwordKeyPrefix$userId') == null) {
      final removed = await preferences.remove(_activeUserIdKey);
      if (!removed) {
        throw StateError('Não foi possível limpar a sessão local inválida.');
      }
      return null;
    }
    return userId;
  }

  Future<String> signUp({
    required String username,
    required String password,
  }) async {
    final cleanUsername = username.trim();
    if (!RegExp(r'^[a-zA-Z0-9_.-]{3,24}$').hasMatch(cleanUsername)) {
      throw const FormatException(
        'Use de 3 a 24 letras, números, ponto, hífen ou sublinhado.',
      );
    }
    if (password.length < 8) {
      throw const FormatException('A senha deve ter pelo menos 8 caracteres.');
    }

    final preferences = await SharedPreferences.getInstance();
    final accounts = _readAccounts(preferences);
    if (accounts.any(
      (account) =>
          account['username']!.toLowerCase() == cleanUsername.toLowerCase(),
    )) {
      throw const FormatException('Este nome de usuário já está em uso.');
    }

    final userId = _newUserId(
      accounts.map((account) => account['id']!).toSet(),
    );
    await _secureStorage.write(
      key: '$_passwordKeyPrefix$userId',
      value: password,
    );
    final isFirstAccount = accounts.isEmpty;
    accounts.add({
      'id': userId,
      'name': cleanUsername,
      'username': cleanUsername,
    });
    try {
      await _saveAccounts(preferences, accounts);
      if (isFirstAccount) {
        final previousFeedData = preferences.getString(_legacyFeedDataKey);
        if (previousFeedData != null) {
          final migrated = await preferences.setString(
            'feedflow.data.v1.$userId',
            previousFeedData,
          );
          if (!migrated) {
            throw StateError('Não foi possível migrar os feeds salvos.');
          }
        }
      }
      await _saveSession(preferences, userId);
    } catch (error, stackTrace) {
      accounts.removeWhere((account) => account['id'] == userId);
      Object? rollbackError;
      try {
        await _saveAccounts(preferences, accounts);
      } catch (error) {
        rollbackError = error;
      }
      try {
        await _secureStorage.delete(key: '$_passwordKeyPrefix$userId');
      } catch (error) {
        rollbackError ??= error;
      }
      if (rollbackError != null) {
        Error.throwWithStackTrace(
          StateError(
            'Falha ao criar a conta: $error. Falha ao limpar os dados '
            'incompletos: $rollbackError',
          ),
          stackTrace,
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
    return userId;
  }

  Future<String> signIn({
    required String username,
    required String password,
  }) async {
    final cleanUsername = username.trim().toLowerCase();
    if (cleanUsername.isEmpty || password.isEmpty) {
      throw const FormatException('Usuário ou senha inválidos.');
    }

    final preferences = await SharedPreferences.getInstance();
    final accounts = _readAccounts(preferences);
    for (final account in accounts) {
      final savedUsername = account['username']!.toLowerCase();
      if (savedUsername.isEmpty || savedUsername != cleanUsername) {
        continue;
      }
      final userId = account['id']!;
      final savedPassword = await _secureStorage.read(
        key: '$_passwordKeyPrefix$userId',
      );
      if (savedPassword != password) break;
      await _saveSession(preferences, userId);
      return userId;
    }
    throw const FormatException('Usuário ou senha inválidos.');
  }

  Future<AccountProfile?> getProfile(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    for (final account in _readAccounts(preferences)) {
      if (account['id'] == userId && account['username']!.isNotEmpty) {
        return AccountProfile(
          id: userId,
          username: account['username']!,
          name: account['name']!,
        );
      }
    }
    return null;
  }

  Future<void> signOut() async {
    final preferences = await SharedPreferences.getInstance();
    final removed = await preferences.remove(_activeUserIdKey);
    if (!removed) {
      throw StateError('Não foi possível encerrar a sessão local.');
    }
  }

  List<Map<String, String>> _readAccounts(SharedPreferences preferences) {
    final encodedAccounts = preferences.getString(_accountsKey);
    if (encodedAccounts == null) return [];
    final decoded = jsonDecode(encodedAccounts);
    if (decoded is! List) {
      throw const FormatException('Os dados locais das contas são inválidos.');
    }
    return decoded.map<Map<String, String>>((entry) {
      if (entry is! Map) {
        throw const FormatException(
          'Os dados locais de uma conta são inválidos.',
        );
      }
      final id = entry['id'];
      final name = entry['name'];
      final username = entry['username'] ?? '';
      if (id is! String || name is! String || username is! String) {
        throw const FormatException(
          'Os dados locais de uma conta estão incompletos.',
        );
      }
      return {'id': id, 'name': name, 'username': username};
    }).toList();
  }

  Future<void> _saveAccounts(
    SharedPreferences preferences,
    List<Map<String, String>> accounts,
  ) async {
    final saved = await preferences.setString(
      _accountsKey,
      jsonEncode(accounts),
    );
    if (!saved) throw StateError('Não foi possível salvar a conta local.');
  }

  Future<void> _saveSession(
    SharedPreferences preferences,
    String userId,
  ) async {
    final saved = await preferences.setString(_activeUserIdKey, userId);
    if (!saved) throw StateError('Não foi possível salvar a sessão local.');
  }

  static String _newUserId(Set<String> existingIds) {
    final random = Random.secure();
    while (true) {
      final bytes = List<int>.generate(16, (_) => random.nextInt(256));
      final id = bytes
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join();
      if (!existingIds.contains(id)) return id;
    }
  }
}

class AccountProfile {
  const AccountProfile({
    required this.id,
    required this.username,
    required this.name,
  });

  final String id;
  final String username;
  final String name;
}
