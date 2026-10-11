import '../../../../core/failures.dart';
import '../entities/note.dart';

abstract class NoteRepository {
  Future<({List<Note> notes, Failure? failure})> fetchNotes();

  Future<({Note? note, Failure? failure})> addNote({
    required String title,
    String body = '',
  });

  Future<({int count, Failure? failure})> countDirty() async =>
      (count: 0, failure: null);

  Future<({int syncedCount, Failure? failure})> syncNotes() async =>
      (syncedCount: 0, failure: null);
}
