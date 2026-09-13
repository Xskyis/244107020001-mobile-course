import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/stats_provider.dart';

/// Halaman StatsPage menggunakan [ConsumerWidget] untuk memantau state statistik ToDo.
/// Menerapkan desain minimalis modern dengan penanganan 3 state AsyncValue.
class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. ref.watch HANYA digunakan di dalam method build() untuk reactive update UI
    final statsAsync = ref.watch(statsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Statistik ToDo',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          // Tombol refresh manual di AppBar
          IconButton(
            tooltip: 'Sinkronkan ulang statistik',
            icon: const Icon(Icons.refresh_rounded),
            // ref.read digunakan di dalam event callback
            onPressed: () => ref.read(statsProvider.notifier).retry(),
          ),
        ],
      ),
      // 2. Menangani 3 state asinkron menggunakan .when()
      body: statsAsync.when(
        // === STATE 1: LOADING (Spinner) ===
        // Ditampilkan selama simulasi delay 2 detik
        loading: () => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF0F172A),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Menghitung statistik ToDo...',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        // === STATE 2: ERROR (Pesan + Tombol Retry) ===
        // Ditampilkan jika simulasi kegagalan 30% terjadi
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFEE2E2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEE2E2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.cloud_off_rounded,
                      color: Color(0xFFDC2626),
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Gagal Menyinkronkan Statistik',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString().replaceAll('Exception: ', ''),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Tombol Coba Lagi
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => ref.read(statsProvider.notifier).retry(),
                    icon: const Icon(Icons.replay_rounded, size: 16),
                    label: const Text(
                      'Coba Lagi',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // === STATE 3: SUCCESS (ListView 3 Item) ===
        // Menampilkan 3 kartu metrik: Total, Selesai, dan Harus Diselesaikan
        data: (stats) => ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: stats.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = stats[index];

            return Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.015),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: item.accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      item.icon,
                      color: item.accentColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.description,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    item.value,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: item.accentColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
