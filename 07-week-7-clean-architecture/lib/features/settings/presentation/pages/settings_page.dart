import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format.dart';
import '../providers/settings_providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(forceOfflineProvider);
    final darkMode = ref.watch(themeModeProvider) == ThemeMode.dark;
    final lastOpenedAsync = ref.watch(lastOpenedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
        elevation: 1,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          SwitchListTile(
            title: const Text('Tema Gelap'),
            subtitle: const Text('Disimpan sebagai preferensi lokal'),
            secondary: Icon(
              darkMode ? Icons.dark_mode : Icons.light_mode,
            ),
            value: darkMode,
            onChanged: (value) =>
                ref.read(themeModeProvider.notifier).setDarkMode(value),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Paksa Mode Offline'),
            subtitle: const Text('Catatan tidak menggunakan sinkronisasi server'),
            secondary: Icon(
              offline ? Icons.cloud_off : Icons.cloud_queue,
            ),
            value: offline,
            onChanged: (value) =>
                ref.read(forceOfflineProvider.notifier).setForceOffline(value),
          ),
          const Divider(),
          lastOpenedAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (error, stack) => const SizedBox.shrink(),
            data: (lastOpened) => lastOpened == null
                ? const SizedBox.shrink()
                : ListTile(
                    leading: const Icon(Icons.schedule),
                    title: const Text('Terakhir Dibuka'),
                    subtitle: Text(formatDate(lastOpened)),
                  ),
          ),
        ],
      ),
    );
  }
}
