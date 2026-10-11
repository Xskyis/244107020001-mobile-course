import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/settings_repository_impl.dart';
import '../../domain/repositories/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepositoryImpl();
});

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.light;

  Future<void> loadTheme() async {
    final repo = ref.read(settingsRepositoryProvider);
    final isDark = await repo.getDarkMode();
    state = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> setDarkMode(bool isDark) async {
    state = isDark ? ThemeMode.dark : ThemeMode.light;
    await ref.read(settingsRepositoryProvider).setDarkMode(isDark);
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ForceOfflineNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  Future<void> loadSetting() async {
    final repo = ref.read(settingsRepositoryProvider);
    state = await repo.getForceOffline();
  }

  Future<void> setForceOffline(bool value) async {
    state = value;
    await ref.read(settingsRepositoryProvider).setForceOffline(value);
  }
}

final forceOfflineProvider =
    NotifierProvider<ForceOfflineNotifier, bool>(ForceOfflineNotifier.new);

final lastOpenedProvider = FutureProvider<DateTime?>((ref) async {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.getLastOpened();
});
