import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:week5_offline_notes/data/local/note.dart';
import 'package:week5_offline_notes/data/providers.dart';
import 'package:week5_offline_notes/data/repositories/note_repository.dart';
import 'package:week5_offline_notes/data/search.dart';
import 'package:week5_offline_notes/main.dart';

class FakeNoteRepositoryForSearch extends NoteRepository {
  FakeNoteRepositoryForSearch(this.sampleNotes);

  final List<Note> sampleNotes;

  @override
  Future<List<Note>> fetchNotes() async => sampleNotes;

  @override
  Future<int> countDirty() async => 0;
}

void main() {
  group('Search & Filter Pure Logic Tests', () {
    final sampleNotes = [
      Note(
        id: 1,
        title: 'Belanja Mingguan',
        body: 'Beli susu, telur, dan roti gandum',
        updatedAt: DateTime(2026, 10, 30, 10, 0),
      ),
      Note(
        id: 2,
        title: 'Rencana Belanja Buku',
        body: 'Praktikum Riverpod dan Clean Architecture',
        updatedAt: DateTime(2026, 10, 30, 11, 0),
      ),
      Note(
        id: 3,
        title: 'Daftar Kuliah',
        body: 'Pemrograman Mobile dan Sistem Operasi',
        updatedAt: DateTime(2026, 10, 30, 12, 0),
      ),
    ];

    test('Filter abaikan huruf besar/kecil (case-insensitive)', () {
      final results = filterNotesByQuery(sampleNotes, 'bElAnJa');
      expect(results.length, 2);
      expect(results.map((n) => n.id), containsAll([1, 2]));
    });

    test(
      'Query tidak cocok mengembalikan list kosong (empty state trigger)',
      () {
        final results = filterNotesByQuery(
          sampleNotes,
          'zzz-tak-ada-di-catatan',
        );
        expect(results, isEmpty);
      },
    );

    test('Query kosong atau hanya spasi mengembalikan seluruh catatan', () {
      final emptyResult = filterNotesByQuery(sampleNotes, '');
      expect(emptyResult.length, 3);

      final spaceResult = filterNotesByQuery(sampleNotes, '    ');
      expect(spaceResult.length, 3);
    });

    test('Pencarian mencocokkan kata pada field body', () {
      final results = filterNotesByQuery(sampleNotes, 'roti');
      expect(results.length, 1);
      expect(results.first.title, 'Belanja Mingguan');
    });
  });

  group('Search Widget & Empty State Tests', () {
    testWidgets('Menampilkan search empty state ketika query tidak cocok', (
      tester,
    ) async {
      final sampleNotes = [
        Note(
          id: 1,
          title: 'Catatan Kuliah Mobile',
          body: 'Mempelajari State Management',
          updatedAt: DateTime(2026, 10, 30, 9, 0),
        ),
      ];

      final fakeRepo = FakeNoteRepositoryForSearch(sampleNotes);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [noteRepositoryProvider.overrideWithValue(fakeRepo)],
          child: const MaterialApp(home: NotesTab()),
        ),
      );

      // Selesaikan future notesProvider
      await tester.pumpAndSettle();

      // Pastikan catatan awal muncul
      expect(find.text('Catatan Kuliah Mobile'), findsOneWidget);

      // Masukkan query pencarian yang tidak ada di catatan
      final searchField = find.byKey(const Key('search_notes_field'));
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'KataKunciYangTakPernahAda');
      await tester.pumpAndSettle();

      // Catatan lama tersembunyi
      expect(find.text('Catatan Kuliah Mobile'), findsNothing);

      // Empty state pencarian muncul
      expect(
        find.text(
          'Tidak ada catatan yang cocok dengan "KataKunciYangTakPernahAda"',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.search_off), findsOneWidget);

      // Bersihkan pencarian lewat tombol clear
      final clearButton = find.byIcon(Icons.clear);
      expect(clearButton, findsOneWidget);
      await tester.tap(clearButton);
      await tester.pumpAndSettle();

      // Catatan awal kembali terlihat
      expect(find.text('Catatan Kuliah Mobile'), findsOneWidget);
    });
  });
}
