import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Use the normal session store whenever possible. If Android's native
/// shared_preferences channel fails, keep Supabase usable through a private
/// cache file without deleting or modifying the original persisted session.
class ResilientAuthStorage extends LocalStorage {
  ResilientAuthStorage({required String persistSessionKey})
      : _primary = SharedPreferencesLocalStorage(
          persistSessionKey: persistSessionKey,
        );

  final SharedPreferencesLocalStorage _primary;
  bool _nativeAvailable = false;

  File get _backup => File(
        Directory.systemTemp.path +
            Platform.pathSeparator +
            'campingcar_auth_session_fallback.txt',
      );

  Future<String?> _readBackup() async {
    try {
      if (!await _backup.exists()) return null;
      final contents = await _backup.readAsString();
      return contents.isEmpty ? null : contents;
    } catch (error) {
      debugPrint('Private fallback session read failed (' +
          error.runtimeType.toString() + ')');
      return null;
    }
  }

  Future<void> _writeBackup(String value) async {
    try {
      await _backup.writeAsString(value, flush: true);
    } catch (error) {
      debugPrint('Private fallback session write failed (' +
          error.runtimeType.toString() + ')');
      // Network login still works, but might need to repeat after a restart.
    }
  }

  Future<void> _removeBackup() async {
    try {
      if (await _backup.exists()) await _backup.delete();
    } catch (_) {}
  }

  @override
  Future<void> initialize() async {
    try {
      await _primary.initialize();
      _nativeAvailable = true;

      // Migrate our backup only when the native store has no session.
      final hasNative = await _primary.hasAccessToken();
      if (!hasNative) {
        final backup = await _readBackup();
        if (backup != null) {
          await _primary.persistSession(backup);
          await _removeBackup();
        }
      }
    } catch (error) {
      _nativeAvailable = false;
      debugPrint('SharedPreferences channel unavailable; using private session fallback (' +
          error.runtimeType.toString() + ')');
    }
  }

  @override
  Future<bool> hasAccessToken() async =>
      (await accessToken())?.isNotEmpty ?? false;

  @override
  Future<String?> accessToken() async {
    if (_nativeAvailable) {
      try {
        final token = await _primary.accessToken();
        if (token != null && token.isNotEmpty) return token;
      } catch (error) {
        _nativeAvailable = false;
        debugPrint('Native session read unavailable (' +
            error.runtimeType.toString() + ')');
      }
    }
    return _readBackup();
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    if (_nativeAvailable) {
      try {
        await _primary.persistSession(persistSessionString);
        await _removeBackup();
        return;
      } catch (error) {
        _nativeAvailable = false;
        debugPrint('Native session write unavailable (' +
            error.runtimeType.toString() + ')');
      }
    }
    await _writeBackup(persistSessionString);
  }

  @override
  Future<void> removePersistedSession() async {
    if (_nativeAvailable) {
      try {
        await _primary.removePersistedSession();
      } catch (error) {
        _nativeAvailable = false;
        debugPrint('Native session removal unavailable (' +
            error.runtimeType.toString() + ')');
      }
    }
    await _removeBackup();
  }
}
