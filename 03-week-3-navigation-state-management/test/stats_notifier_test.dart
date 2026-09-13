import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:week3_app/providers/stats_provider.dart';

/// Implementasi mock [Random] untuk pengujian deterministik tanpa flakiness
class MockRandom implements Random {
  final double value;
  MockRandom(this.value);

  @override
  double nextDouble() => value;

  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => false;
}

class MockDynamicRandom implements Random {
  final double Function() getValue;
  MockDynamicRandom(this.getValue);

  @override
  double nextDouble() => getValue();

  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => false;
}

void main() {
  group('StatsNotifier Unit Tests', () {
    test('State awal adalah AsyncLoading', () {
      final container = ProviderContainer(
        overrides: [
          statsProvider.overrideWith(
            () => StatsNotifier(
              random: MockRandom(0.5),
              delay: const Duration(milliseconds: 200),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(statsProvider);
      expect(state, isA<AsyncLoading>());
    });

    test('Berhasil memuat 3 item statistik ketika random >= 0.3 (Success state)',
        () async {
      final container = ProviderContainer(
        overrides: [
          statsProvider.overrideWith(
            () => StatsNotifier(
              random: MockRandom(0.5),
              delay: Duration.zero,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final completer = Completer<AsyncValue<List<StatItem>>>();
      container.listen<AsyncValue<List<StatItem>>>(
        statsProvider,
        (_, next) {
          if (next.hasValue && !completer.isCompleted) {
            completer.complete(next);
          }
        },
        fireImmediately: true,
      );

      final result = await completer.future;

      expect(result.hasValue, isTrue);
      expect(result.hasError, isFalse);
      expect(result.value!.length, 3);
      expect(result.value![0].label, 'Total ToDo');
      expect(result.value![1].label, 'ToDo Selesai');
      expect(result.value![2].label, 'Harus Diselesaikan');
    });

    test('Menghasilkan AsyncError saat random < 0.3 (Simulasi kegagalan 30%)',
        () async {
      final container = ProviderContainer(
        overrides: [
          statsProvider.overrideWith(
            () => StatsNotifier(
              random: MockRandom(0.1),
              delay: Duration.zero,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final completer = Completer<AsyncValue<List<StatItem>>>();
      container.listen<AsyncValue<List<StatItem>>>(
        statsProvider,
        (_, next) {
          if (next.hasError && !completer.isCompleted) {
            completer.complete(next);
          }
        },
        fireImmediately: true,
      );

      final result = await completer.future;

      expect(result.hasError, isTrue);
      expect(
        result.error.toString(),
        contains('Gagal menyinkronkan statistik tugas'),
      );
    });

    test('Method retry() memicu perubahan state dan mampu memulihkan data',
        () async {
      bool shouldFail = true;
      final dynamicRandom = MockDynamicRandom(() => shouldFail ? 0.1 : 0.8);

      final container = ProviderContainer(
        overrides: [
          statsProvider.overrideWith(
            () => StatsNotifier(
              random: dynamicRandom,
              delay: Duration.zero,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      Completer<AsyncValue<List<StatItem>>> completer = Completer();
      container.listen<AsyncValue<List<StatItem>>>(
        statsProvider,
        (_, next) {
          if ((next.hasError || next.hasValue) && !completer.isCompleted) {
            completer.complete(next);
          }
        },
        fireImmediately: true,
      );

      // 1. Tangkap hasil inisialisasi awal (error)
      final initialErrorState = await completer.future;
      expect(initialErrorState.hasError, isTrue);

      // 2. Siapkan completer untuk aksi retry berikutnya yang sukses
      completer = Completer();
      shouldFail = false;

      // 3. Panggil retry()
      await container.read(statsProvider.notifier).retry();

      // 4. Verifikasi state berhasil pulih membawa 3 item data
      final recoveredState = await completer.future;
      expect(recoveredState.hasValue, isTrue);
      expect(recoveredState.value!.length, 3);
      expect(recoveredState.hasError, isFalse);
    });
  });
}
