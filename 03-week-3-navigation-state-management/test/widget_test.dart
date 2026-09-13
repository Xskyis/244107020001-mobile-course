import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:week3_app/main.dart';

void main() {
  testWidgets('menambah tugas baru', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    expect(find.text('Belum ada tugas'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Kerjakan PR minggu 3');
    await tester.tap(find.text('Tambah'));
    await tester.pump();

    expect(find.text('Kerjakan PR minggu 3'), findsOneWidget);
  });

  testWidgets('filter membedakan tugas aktif dan tugas selesai', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));

    // Tambah 2 tugas
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Tugas 1');
    await tester.tap(find.text('Tambah'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Tugas 2');
    await tester.tap(find.text('Tambah'));
    await tester.pumpAndSettle();

    // Centang Tugas 1 menjadi selesai
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    // Pilih filter "Belum Selesai"
    await tester.tap(find.text('Belum Selesai'));
    await tester.pumpAndSettle();
    expect(find.text('Tugas 2'), findsOneWidget);
    expect(find.text('Tugas 1'), findsNothing);

    // Pilih filter "Selesai"
    await tester.tap(find.text('Selesai'));
    await tester.pumpAndSettle();
    expect(find.text('Tugas 1'), findsOneWidget);
    expect(find.text('Tugas 2'), findsNothing);
  });

  testWidgets('navigasi ke halaman statistik lewat NavigationBar', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));

    // Ketuk item kedua di NavigationBar (Statistik)
    await tester.tap(find.text('Statistik'));
    await tester.pumpAndSettle();

    // Verifikasi berada di halaman statistik
    expect(find.text('Statistik ToDo'), findsOneWidget);
  });
}
