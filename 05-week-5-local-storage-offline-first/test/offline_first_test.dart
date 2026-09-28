import 'package:flutter_test/flutter_test.dart';
import 'package:week5_offline_notes/data/repositories/note_repository.dart';
import 'package:week5_offline_notes/data/sync.dart';

class FakeNoteRepository extends NoteRepository {
  int dirty = 2;

  @override
  Future<int> countDirty() async => dirty;

  @override
  Future<void> markAllSynced() async => dirty = 0;
}

void main() {
  test('syncNotes uploads dirty notes and clears the dirty count', () async {
    final repository = FakeNoteRepository();

    expect(await syncNotes(repository), 2);
    expect(repository.dirty, 0);
    expect(await syncNotes(repository), 0);
  });

  test('syncNotes rejects writes while forceOffline is enabled', () async {
    final repository = FakeNoteRepository();

    expect(
      () => syncNotes(repository, forceOffline: true),
      throwsA(isA<StateError>()),
    );
    expect(repository.dirty, 2);
  });
}
