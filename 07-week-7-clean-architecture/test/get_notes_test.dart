import 'package:flutter_test/flutter_test.dart';
import 'package:week7_clean_architecture/core/failures.dart';
import 'package:week7_clean_architecture/features/notes/domain/entities/note.dart';
import 'package:week7_clean_architecture/features/notes/domain/repositories/note_repository.dart';
import 'package:week7_clean_architecture/features/notes/domain/usecases/get_notes.dart';

class FakeNoteRepository implements NoteRepository {
  FakeNoteRepository({this.items = const [], this.fail = false});

  final List<Note> items;
  final bool fail;

  @override
  Future<({List<Note> notes, Failure? failure})> fetchNotes() async {
    if (fail) {
      return (
        notes: const <Note>[],
        failure: const LocalFailure('db locked (simulasi)'),
      );
    }
    return (notes: items, failure: null);
  }

  @override
  Future<({Note? note, Failure? failure})> addNote({
    required String title,
    String body = '',
  }) async {
    if (fail) {
      return (
        note: null,
        failure: const LocalFailure('db locked (simulasi)'),
      );
    }
    final note = Note(
      id: items.length + 1,
      title: title,
      body: body,
      updatedAt: DateTime(2026, 10, 11),
      dirty: true,
    );
    return (note: note, failure: null);
  }

  @override
  Future<({int count, Failure? failure})> countDirty() async {
    return (count: items.where((n) => n.dirty).length, failure: null);
  }

  @override
  Future<({int syncedCount, Failure? failure})> syncNotes() async {
    return (syncedCount: items.where((n) => n.dirty).length, failure: null);
  }
}

void main() {
  group('GetNotes Use Case Test', () {
    test('GetNotes meneruskan daftar data dari repository dengan benar (sukses)',
        () async {
      final sampleNotes = [
        Note(
          id: 1,
          title: 'Catatan Arsitektur',
          body: 'Menerapkan Clean Architecture',
          updatedAt: DateTime(2026, 9, 27),
          dirty: false,
        ),
        Note(
          id: 2,
          title: 'Catatan Riverpod',
          body: 'Dependency Injection via Provider',
          updatedAt: DateTime(2026, 9, 28),
          dirty: true,
        ),
      ];

      final repo = FakeNoteRepository(items: sampleNotes);
      final useCase = GetNotes(repo);

      final result = await useCase();

      expect(result.failure, isNull);
      expect(result.notes.length, 2);
      expect(result.notes.first.title, 'Catatan Arsitektur');
      expect(result.notes.first.dirty, isFalse);
      expect(result.notes.last.title, 'Catatan Riverpod');
      expect(result.notes.last.dirty, isTrue);
    });

    test('GetNotes meneruskan Failure tanpa crash / melempar exception ke UI (gagal)',
        () async {
      final repo = FakeNoteRepository(fail: true);
      final useCase = GetNotes(repo);

      final result = await useCase();

      expect(result.failure, isNotNull);
      expect(result.failure, isA<LocalFailure>());
      expect(result.failure!.message, contains('db locked (simulasi)'));
      expect(result.notes, isEmpty);
    });
  });
}
