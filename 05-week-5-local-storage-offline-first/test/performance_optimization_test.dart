import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:week5_offline_notes/data/local/note.dart';
import 'package:week5_offline_notes/data/models/post.dart';
import 'package:week5_offline_notes/data/network_cache.dart';
import 'package:week5_offline_notes/data/providers.dart';
import 'package:week5_offline_notes/data/repositories/note_repository.dart';
import 'package:week5_offline_notes/data/repositories/post_repository.dart';
import 'package:week5_offline_notes/main.dart';
import 'package:week5_offline_notes/widgets/note_tile.dart';

class LargeNoteRepository extends NoteRepository {
  LargeNoteRepository(this.notes);

  final List<Note> notes;
  int dirty = 1;

  @override
  Future<List<Note>> fetchNotes() async => notes;

  @override
  Future<int> countDirty() async => dirty;
}

class FakePaginatedPostRepository extends PostRepository {
  FakePaginatedPostRepository() : super(Dio());

  final List<int> requestedPages = [];

  @override
  Future<List<Post>> fetchPostsPage({int page = 1, int limit = 20}) async {
    requestedPages.add(page);
    if (page > 2) return [];
    final start = (page - 1) * limit + 1;
    return List.generate(
      limit,
      (i) => Post(
        id: start + i,
        userId: 1,
        title: 'Post #${start + i}',
        body: 'Body #${start + i}',
      ),
    );
  }
}

class CountingHttpAdapter implements HttpClientAdapter {
  CountingHttpAdapter({this.failFirstAttempt = false});

  final bool failFirstAttempt;
  int callCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    callCount++;
    if (failFirstAttempt && callCount == 1) {
      throw DioException.connectionTimeout(
        timeout: const Duration(milliseconds: 50),
        requestOptions: options,
      );
    }
    return ResponseBody.fromString(
      jsonEncode([
        {'id': 1, 'userId': 1, 'title': 'Cached Post', 'body': 'Body'},
      ]),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('Week 11 Performance Optimization Tests', () {
    testWidgets('NotesTab memakai ListView.builder (lazy loading) untuk 200 catatan', (
      tester,
    ) async {
      final notes = List.generate(
        200,
        (i) => Note(
          id: i + 1,
          title: 'Catatan #$i',
          body: 'Isi catatan ke-$i',
          updatedAt: DateTime(2026, 11, 15),
        ),
      );
      final repo = LargeNoteRepository(notes);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [noteRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(home: NotesTab()),
        ),
      );
      await tester.pumpAndSettle();

      // Hanya item di sekitar viewport yang dibangun (< 30 dari 200 total).
      final builtTiles = tester.widgetList<NoteTile>(find.byType(NoteTile));
      expect(builtTiles.length, lessThan(30));
      expect(find.byType(ListView), findsOneWidget);
    });

    test('TtlCacheInterceptor mengembalikan cache pada request berulang', () async {
      final adapter = CountingHttpAdapter();
      final cacheInterceptor = TtlCacheInterceptor(
        ttl: const Duration(seconds: 60),
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com'))
        ..httpClientAdapter = adapter
        ..interceptors.add(cacheInterceptor);

      final first = await dio.get<List<dynamic>>('/posts');
      final second = await dio.get<List<dynamic>>('/posts');

      expect(first.statusCode, 200);
      expect(second.statusCode, 200);
      expect(adapter.callCount, 1);
      expect(cacheInterceptor.missCount, 1);
      expect(cacheInterceptor.hitCount, 1);
    });

    test('RetryInterceptor melakukan retry otomatis saat timeout sementara', () async {
      final adapter = CountingHttpAdapter(failFirstAttempt: true);
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com'))
        ..httpClientAdapter = adapter;
      dio.interceptors.add(
        RetryInterceptor(
          dio: dio,
          maxRetries: 2,
          baseDelay: const Duration(milliseconds: 10),
        ),
      );

      final response = await dio.get<List<dynamic>>('/posts');
      expect(response.statusCode, 200);
      expect(adapter.callCount, 2);
    });

    test('PaginatedPostsNotifier memuat halaman secara bertahap (pagination)', () async {
      final fakeRepo = FakePaginatedPostRepository();
      final container = ProviderContainer(
        overrides: [postRepositoryProvider.overrideWithValue(fakeRepo)],
      );
      addTearDown(container.dispose);

      // Panggil loadInitial secara eksplisit pada unit test
      await container.read(paginatedPostsProvider.notifier).loadInitial();

      var state = container.read(paginatedPostsProvider);
      expect(state.items.length, 20);
      expect(state.hasMore, isTrue);
      expect(fakeRepo.requestedPages, [1]);

      await container.read(paginatedPostsProvider.notifier).loadMore();
      state = container.read(paginatedPostsProvider);
      expect(state.items.length, 40);
      expect(fakeRepo.requestedPages, [1, 2]);
    });
  });
}
