import 'dart:async';

import 'package:sqflite/sqflite.dart';

import 'local/db.dart';
import 'repositories/note_repository.dart';
import 'repositories/post_repository.dart';
import 'models/post.dart';

Future<List<Post>> loadPostsCacheFirst(
  PostRepository repository, {
  required bool forceOffline,
}) async {
  final database = await openLocalDatabase();
  final rows = await database.query('cached_posts', orderBy: 'id');
  final cached = rows.map(Post.fromMap).toList();
  if (!forceOffline) {
    unawaited(refreshPostsInBackground(repository));
  }
  return cached;
}

Future<void> refreshPostsInBackground(PostRepository repository) async {
  try {
    final posts = await repository.fetchPosts();
    final database = await openLocalDatabase();
    await database.transaction((transaction) async {
      for (final post in posts) {
        await transaction.insert(
          'cached_posts',
          post.toCacheMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  } catch (_) {
    // Cache-first keeps the last known data when refresh cannot connect.
  }
}

Future<int> syncNotes(
  NoteRepository repository, {
  bool forceOffline = false,
}) async {
  if (forceOffline) {
    throw StateError('Sync tidak tersedia saat mode offline aktif.');
  }
  final dirtyCount = await repository.countDirty();
  if (dirtyCount == 0) return 0;
  await Future<void>.delayed(const Duration(seconds: 1));
  await repository.markAllSynced();
  return dirtyCount;
}
