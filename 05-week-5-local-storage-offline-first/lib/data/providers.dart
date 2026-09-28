import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local/note.dart';
import 'models/post.dart';
import 'prefs.dart';
import 'repositories/note_repository.dart';
import 'repositories/post_repository.dart';
import 'sync.dart';

final dioProvider = Provider<Dio>((ref) => Dio(BaseOptions(
      baseUrl: 'https://jsonplaceholder.typicode.com',
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    )));

class ForceOfflineNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setValue(bool value) => state = value;
}

final forceOfflineProvider =
    NotifierProvider<ForceOfflineNotifier, bool>(ForceOfflineNotifier.new);

final noteRepositoryProvider = Provider<NoteRepository>((ref) => NoteRepository());
final postRepositoryProvider = Provider<PostRepository>(
  (ref) => PostRepository(ref.watch(dioProvider)),
);

final notesProvider = FutureProvider<List<Note>>(
  (ref) => ref.watch(noteRepositoryProvider).fetchNotes(),
  retry: (retryCount, error) => null,
);
final noteDetailProvider = FutureProvider.family<Note?, int>(
  (ref, id) => ref.watch(noteRepositoryProvider).fetchNote(id),
);
final dirtyCountProvider = FutureProvider<int>(
  (ref) => ref.watch(noteRepositoryProvider).countDirty(),
);

final postsProvider = FutureProvider<List<Post>>((ref) async {
  final repository = ref.watch(postRepositoryProvider);
  final offline = ref.watch(forceOfflineProvider);
  return loadPostsCacheFirst(repository, forceOffline: offline);
});

Future<void> initializePreferences(WidgetRef ref) async {
  ref.read(forceOfflineProvider.notifier).setValue(await readForceOffline());
}

Future<void> setForceOffline(WidgetRef ref, bool value) async {
  ref.read(forceOfflineProvider.notifier).setValue(value);
  await writeForceOffline(value);
  ref.invalidate(postsProvider);
}