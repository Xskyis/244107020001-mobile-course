import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';

import 'local/db.dart';
import 'models/post.dart';
import 'repositories/note_repository.dart';
import 'repositories/post_repository.dart';

List<Post> _webCachedPosts = [];
DateTime? _lastPostsRefreshAt;
const Duration _postsRefreshTtl = Duration(seconds: 60);

Future<List<Post>> loadPostsCacheFirst(
  PostRepository repository, {
  required bool forceOffline,
}) async {
  if (kIsWeb) {
    if (_webCachedPosts.isEmpty && !forceOffline) {
      await refreshPostsInBackground(repository);
    } else if (!forceOffline && _shouldRefreshCache()) {
      unawaited(refreshPostsInBackground(repository));
    }
    return List<Post>.from(_webCachedPosts);
  }

  final database = await openLocalDatabase();
  final rows = await database.query('cached_posts', orderBy: 'id');
  final cached = rows.map(Post.fromMap).toList();
  if (!forceOffline && (cached.isEmpty || _shouldRefreshCache())) {
    unawaited(refreshPostsInBackground(repository));
  }
  return cached;
}

bool _shouldRefreshCache() {
  final last = _lastPostsRefreshAt;
  if (last == null) return true;
  return DateTime.now().difference(last) >= _postsRefreshTtl;
}

Future<void> refreshPostsInBackground(PostRepository repository) async {
  try {
    final posts = await repository.fetchPosts();
    _lastPostsRefreshAt = DateTime.now();
    if (kIsWeb) {
      _webCachedPosts = posts;
      return;
    }
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
