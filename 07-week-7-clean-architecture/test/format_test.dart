import 'package:flutter_test/flutter_test.dart';
import 'package:week7_clean_architecture/core/format.dart';

void main() {
  group('Core Format Helper Tests', () {
    test('formatDate mengembalikan string terformat YYYY-MM-DD HH:mm', () {
      final dt = DateTime(2026, 10, 11, 8, 30);
      expect(formatDate(dt), '2026-10-11 08:30');
    });

    test(
      'formatRelativeDate mengembalikan "Baru saja" untuk selisih < 1 menit',
      () {
        final now = DateTime(2026, 10, 11, 10, 0, 30);
        final dt = DateTime(2026, 10, 11, 10, 0, 0);
        expect(formatRelativeDate(dt, now: now), 'Baru saja');
      },
    );

    test('formatRelativeDate mengembalikan menit lalu untuk selisih menit', () {
      final now = DateTime(2026, 10, 11, 10, 15);
      final dt = DateTime(2026, 10, 11, 10, 0);
      expect(formatRelativeDate(dt, now: now), '15 menit lalu');
    });

    test('formatSyncStatus mengembalikan status ramah pengguna', () {
      expect(formatSyncStatus(true), 'Belum tersinkron');
      expect(formatSyncStatus(false), 'Tersinkron');
    });
  });
}
