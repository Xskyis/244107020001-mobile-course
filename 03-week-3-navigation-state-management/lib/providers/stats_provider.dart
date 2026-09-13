import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'todo_provider.dart';

/// Model data statistik penyelesaian ToDo bersifat immutable
class StatItem {
  final String label;
  final String value;
  final String description;
  final IconData icon;
  final Color accentColor;

  const StatItem({
    required this.label,
    required this.value,
    required this.description,
    required this.icon,
    required this.accentColor,
  });
}

/// AsyncNotifier modern (Riverpod 2.x/3.x) untuk mengelola state statistik ToDo asinkron.
/// Mensimulasikan sinkronisasi analitik tugas ke server dengan delay 2 detik dan kegagalan 30%.
class StatsNotifier extends AsyncNotifier<List<StatItem>> {
  final Random _random;
  final Duration _delay;

  /// Dependency injection opsional untuk Random dan Delay agar pengujian unit test cepat & deterministik
  StatsNotifier({
    Random? random,
    Duration? delay,
  })  : _random = random ?? Random(),
        _delay = delay ?? const Duration(seconds: 2);

  /// Method build() otomatis dipanggil saat provider pertama kali diinisialisasi
  @override
  Future<List<StatItem>> build() async {
    return _fetchStats();
  }

  /// Simulasi pengambilan data metrik penyelesaian ToDo
  Future<List<StatItem>> _fetchStats() async {
    // 1. Simulasi network latency (default 2 detik)
    await Future.delayed(_delay);

    // 2. Simulasi probabilitas kegagalan sebesar 30%
    if (_random.nextDouble() < 0.3) {
      throw Exception('Gagal menyinkronkan statistik tugas (Simulasi Error 30%)');
    }

    // 3. Membaca state real-time dari todoListProvider
    final todos = ref.read(todoListProvider);
    final total = todos.length;
    final completed = todos.where((t) => t.done).length;
    final pending = total - completed;

    // 4. Mengembalikan tepat 3 item statistik penyelesaian ToDo
    return [
      StatItem(
        label: 'Total ToDo',
        value: '$total',
        description: 'Semua tugas yang tercatat',
        icon: Icons.checklist_rounded,
        accentColor: const Color(0xFF0F172A),
      ),
      StatItem(
        label: 'ToDo Selesai',
        value: '$completed',
        description: total == 0
            ? 'Belum ada tugas selesai'
            : '${((completed / total) * 100).toStringAsFixed(0)}% telah tuntas',
        icon: Icons.task_alt_rounded,
        accentColor: const Color(0xFF16A34A),
      ),
      StatItem(
        label: 'Harus Diselesaikan',
        value: '$pending',
        description: pending == 0
            ? 'Semua tugas telah beres!'
            : '$pending tugas masih menunggu',
        icon: Icons.pending_actions_rounded,
        accentColor: const Color(0xFFEA580C),
      ),
    ];
  }

  /// Method retry untuk memicu pengambilan ulang data saat terjadi error
  Future<void> retry() async {
    // Set state ke loading terlebih dahulu
    state = const AsyncLoading();
    // AsyncValue.guard otomatis menangkap exception dan mengonversinya menjadi AsyncError
    state = await AsyncValue.guard(() => _fetchStats());
  }
}

/// Provider dideklarasikan dengan tipe eksplisit tanpa duplikasi
final statsProvider =
    AsyncNotifierProvider<StatsNotifier, List<StatItem>>(StatsNotifier.new);
