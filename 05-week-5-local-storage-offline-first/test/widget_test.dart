import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:week5_offline_notes/data/models/post.dart';
import 'package:week5_offline_notes/data/providers.dart';
import 'package:week5_offline_notes/data/repositories/post_repository.dart';
import 'package:week5_offline_notes/main.dart';

class _FakePostRepository extends PostRepository {
  _FakePostRepository() : super(Dio());

  @override
  Future<List<Post>> fetchPosts() async => const [];

  @override
  Future<List<Post>> fetchPostsPage({int page = 1, int limit = 20}) async =>
      const [];
}

void main() {
  testWidgets('offline-first app renders navigation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          postRepositoryProvider.overrideWithValue(_FakePostRepository()),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cache-first posts'), findsOneWidget);
    expect(find.text('Catatan'), findsOneWidget);
  });
}
