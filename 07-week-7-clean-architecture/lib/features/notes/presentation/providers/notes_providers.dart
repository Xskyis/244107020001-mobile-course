import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/note_repository_impl.dart';
import '../../domain/entities/note.dart';
import '../../domain/repositories/note_repository.dart';
import '../../domain/usecases/add_note.dart';
import '../../domain/usecases/get_notes.dart';

// Data layer: penyuntikan repository implementasi
final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  return NoteRepositoryImpl();
});

// Domain layer: use cases bergantung pada abstraksi interface
final getNotesProvider = Provider<GetNotes>((ref) {
  return GetNotes(ref.watch(noteRepositoryProvider));
});

final addNoteProvider = Provider<AddNote>((ref) {
  return AddNote(ref.watch(noteRepositoryProvider));
});

// Presentation layer: state stream untuk daftar catatan
final notesProvider = FutureProvider<List<Note>>((ref) async {
  final result = await ref.watch(getNotesProvider).call();
  if (result.failure != null) {
    throw Exception(result.failure!.message);
  }
  return result.notes;
});

// Presentation layer: state stream untuk jumlah catatan dirty (belum sinkron)
final dirtyCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(noteRepositoryProvider);
  final result = await repository.countDirty();
  if (result.failure != null) return 0;
  return result.count;
});

// Controller / Notifier untuk action add dan sync
class NotesActionNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> add({required String title, String body = ''}) async {
    state = const AsyncLoading();
    final addUseCase = ref.read(addNoteProvider);
    final result = await addUseCase(title: title, body: body);
    if (result.failure != null) {
      state = AsyncError(result.failure!.message, StackTrace.current);
      return false;
    }
    state = const AsyncData(null);
    ref.invalidate(notesProvider);
    ref.invalidate(dirtyCountProvider);
    return true;
  }

  Future<int?> sync() async {
    state = const AsyncLoading();
    final repository = ref.read(noteRepositoryProvider);
    final result = await repository.syncNotes();
    if (result.failure != null) {
      state = AsyncError(result.failure!.message, StackTrace.current);
      return null;
    }
    state = const AsyncData(null);
    ref.invalidate(notesProvider);
    ref.invalidate(dirtyCountProvider);
    return result.syncedCount;
  }
}

final notesActionProvider =
    NotifierProvider<NotesActionNotifier, AsyncValue<void>>(
  NotesActionNotifier.new,
);
