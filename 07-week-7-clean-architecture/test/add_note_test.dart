import 'package:flutter_test/flutter_test.dart';
import 'package:week7_clean_architecture/core/failures.dart';
import 'package:week7_clean_architecture/features/notes/domain/entities/note.dart';
import 'package:week7_clean_architecture/features/notes/domain/repositories/note_repository.dart';
import 'package:week7_clean_architecture/features/notes/domain/usecases/add_note.dart';

class FakeNoteRepositoryForAdd implements NoteRepository {
  FakeNoteRepositoryForAdd({this.fail = false});

  final bool fail;
  Note? lastAdded;

  @override
  Future<({List<Note> notes, Failure? failure})> fetchNotes() async {
    return (notes: const <Note>[], failure: null);
  }

  @override
  Future<({Note? note, Failure? failure})> addNote({
    required String title,
    String body = '',
  }) async {
    if (fail) {
      return (
        note: null,
        failure: const LocalFailure('Gagal menulis data ke database.'),
      );
    }
    final note = Note(
      id: 99,
      title: title,
      body: body,
      updatedAt: DateTime(2026, 10, 11, 10, 0),
      dirty: true,
    );
    lastAdded = note;
    return (note: note, failure: null);
  }

  @override
  Future<({int count, Failure? failure})> countDirty() async =>
      (count: 0, failure: null);

  @override
  Future<({int syncedCount, Failure? failure})> syncNotes() async =>
      (syncedCount: 0, failure: null);
}

void main() {
  group('AddNote Use Case Test', () {
    test('AddNote berhasil menyimpan catatan ketika judul valid', () async {
      final repo = FakeNoteRepositoryForAdd();
      final useCase = AddNote(repo);

      final result = await useCase(
        title: 'Belajar SOLID',
        body: 'Single Responsibility Principle',
      );

      expect(result.failure, isNull);
      expect(result.note, isNotNull);
      expect(result.note!.title, 'Belajar SOLID');
      expect(result.note!.body, 'Single Responsibility Principle');
      expect(repo.lastAdded?.title, 'Belajar SOLID');
    });

    test('AddNote mengembalikan ValidationFailure jika judul kosong/spasi', () async {
      final repo = FakeNoteRepositoryForAdd();
      final useCase = AddNote(repo);

      final result = await useCase(title: '   ');

      expect(result.note, isNull);
      expect(result.failure, isA<ValidationFailure>());
      expect(result.failure!.message, contains('tidak boleh kosong'));
      expect(repo.lastAdded, isNull);
    });

    test('AddNote menangani LocalFailure jika database gagal', () async {
      final repo = FakeNoteRepositoryForAdd(fail: true);
      final useCase = AddNote(repo);

      final result = await useCase(title: 'Catatan Baru');

      expect(result.note, isNull);
      expect(result.failure, isA<LocalFailure>());
      expect(result.failure!.message, contains('Gagal menulis data'));
    });
  });
}
