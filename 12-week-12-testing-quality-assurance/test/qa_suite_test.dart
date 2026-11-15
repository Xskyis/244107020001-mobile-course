import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:week5_offline_notes/data/local/note.dart';
import 'package:week5_offline_notes/data/note_validation.dart';
import 'package:week5_offline_notes/data/providers.dart';
import 'package:week5_offline_notes/data/repositories/note_repository.dart';
import 'package:week5_offline_notes/main.dart';

class FakeQaNoteRepository extends NoteRepository {
  FakeQaNoteRepository({
    List<Note>? initialNotes,
    this.fetchError,
    this.addError,
  }) : _notes = List<Note>.from(initialNotes ?? []);

  final List<Note> _notes;
  final Exception? fetchError;
  final Exception? addError;
  int addCalls = 0;

  @override
  Future<List<Note>> fetchNotes() async {
    if (fetchError != null) throw fetchError!;
    return List<Note>.from(_notes);
  }

  @override
  Future<int> addNote({required String title, String body = ''}) async {
    addCalls++;
    if (addError != null) throw addError!;
    final id = _notes.length + 1;
    _notes.insert(
      0,
      Note(
        id: id,
        title: title,
        body: body,
        updatedAt: DateTime(2026, 11, 15),
        dirty: true,
      ),
    );
    return id;
  }

  @override
  Future<int> countDirty() async => _notes.where((n) => n.dirty).length;
}

void main() {
  group('Unit Test - Validasi Judul Catatan & Kasus Tepi', () {
    test('menerima judul catatan yang valid dan menormalisasi spasi', () {
      // Arrange
      const rawTitle = '  Materi Testing Flutter  ';
      // Act
      final valid = isValidNoteTitle(rawTitle);
      final normalized = normalizeNoteTitle(rawTitle);
      // Assert
      expect(valid, isTrue);
      expect(normalized, 'Materi Testing Flutter');
    });

    test('menolak input kosong atau hanya spasi', () {
      expect(isValidNoteTitle(''), isFalse);
      expect(isValidNoteTitle('     '), isFalse);
      expect(isValidNoteTitle('\n\t '), isFalse);
    });

    test('menolak judul melebihi batas 120 karakter (kasus tepi)', () {
      final exact120 = 'a' * 120;
      final over120 = 'a' * 121;
      expect(isValidNoteTitle(exact120), isTrue);
      expect(isValidNoteTitle(over120), isFalse);
    });
  });

  group('Fake Repository - Skenario Sukses & Kegagalan', () {
    test('mengembalikan daftar catatan saat repository sukses', () async {
      final repo = FakeQaNoteRepository(
        initialNotes: [
          Note(
            id: 1,
            title: 'Baca Dokumentasi QA',
            updatedAt: DateTime(2026, 11, 15),
          ),
        ],
      );

      final notes = await repo.fetchNotes();
      expect(notes.length, 1);
      expect(notes.first.title, 'Baca Dokumentasi QA');
    });

    test('melempar exception saat repository gagal (tidak berubah jadi list kosong)', () async {
      final repo = FakeQaNoteRepository(
        fetchError: Exception('Koneksi SQLite gagal'),
      );

      expect(() => repo.fetchNotes(), throwsA(isA<Exception>()));
    });
  });

  group('Widget Test - NotesTab Interaksi, Validasi, & Error State', () {
    testWidgets('menolak input kosong/spasi dan menampilkan SnackBar validasi', (
      tester,
    ) async {
      final repo = FakeQaNoteRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [noteRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(home: NotesTab()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Belum ada catatan.'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('add_note_field')), '   ');
      await tester.tap(find.byKey(const Key('add_note_button')));
      await tester.pumpAndSettle();

      expect(repo.addCalls, 0);
      expect(
        find.text('Judul catatan tidak boleh kosong atau > 120 karakter.'),
        findsOneWidget,
      );
    });

    testWidgets('menambahkan catatan valid dan menampilkannya di daftar', (
      tester,
    ) async {
      final repo = FakeQaNoteRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [noteRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(home: NotesTab()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('add_note_field')),
        'Belajar Integration Test',
      );
      await tester.tap(find.byKey(const Key('add_note_button')));
      await tester.pumpAndSettle();

      expect(repo.addCalls, 1);
      expect(find.text('Belajar Integration Test'), findsOneWidget);
      expect(find.text('belum tersinkron'), findsOneWidget);
    });

    testWidgets('menampilkan pesan error saat fetchNotes gagal', (tester) async {
      final repo = FakeQaNoteRepository(
        fetchError: Exception('Database corrupt'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [noteRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(home: NotesTab()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Gagal membaca catatan:'),
        findsOneWidget,
      );
    });
  });
}
