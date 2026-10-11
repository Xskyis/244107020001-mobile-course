abstract class SettingsRepository {
  Future<bool> getDarkMode();
  Future<void> setDarkMode(bool value);

  Future<bool> getForceOffline();
  Future<void> setForceOffline(bool value);

  Future<DateTime?> getLastOpened();
  Future<void> setLastOpened(DateTime value);
}
