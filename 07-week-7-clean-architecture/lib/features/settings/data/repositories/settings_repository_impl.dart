import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  static const _darkModeKey = 'dark_mode';
  static const _forceOfflineKey = 'force_offline';
  static const _lastOpenedKey = 'last_opened_at';

  @override
  Future<bool> getDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_darkModeKey) ?? false;
  }

  @override
  Future<void> setDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, value);
  }

  @override
  Future<bool> getForceOffline() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_forceOfflineKey) ?? false;
  }

  @override
  Future<void> setForceOffline(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_forceOfflineKey, value);
  }

  @override
  Future<DateTime?> getLastOpened() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_lastOpenedKey);
    return value == null ? null : DateTime.tryParse(value);
  }

  @override
  Future<void> setLastOpened(DateTime value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastOpenedKey, value.toIso8601String());
  }
}
