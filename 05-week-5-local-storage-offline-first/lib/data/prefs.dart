import 'package:shared_preferences/shared_preferences.dart';

const _forceOfflineKey = 'force_offline';
const _darkModeKey = 'dark_mode';
const _lastOpenedKey = 'last_opened_at';

Future<bool> readForceOffline() async {
  final preferences = await SharedPreferences.getInstance();
  return preferences.getBool(_forceOfflineKey) ?? false;
}

Future<void> writeForceOffline(bool value) async {
  final preferences = await SharedPreferences.getInstance();
  await preferences.setBool(_forceOfflineKey, value);
}

Future<bool> readDarkMode() async {
  final preferences = await SharedPreferences.getInstance();
  return preferences.getBool(_darkModeKey) ?? false;
}

Future<void> writeDarkMode(bool value) async {
  final preferences = await SharedPreferences.getInstance();
  await preferences.setBool(_darkModeKey, value);
}

Future<DateTime?> readLastOpened() async {
  final preferences = await SharedPreferences.getInstance();
  final value = preferences.getString(_lastOpenedKey);
  return value == null ? null : DateTime.tryParse(value);
}

Future<void> writeLastOpened(DateTime value) async {
  final preferences = await SharedPreferences.getInstance();
  await preferences.setString(_lastOpenedKey, value.toIso8601String());
}
