import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:week5_offline_notes/data/local/note.dart';
import 'package:week5_offline_notes/data/models/post.dart';
import 'package:week5_offline_notes/data/providers.dart';
import 'package:week5_offline_notes/data/repositories/note_repository.dart';
import 'package:week5_offline_notes/data/repositories/post_repository.dart';
import 'package:week5_offline_notes/main.dart';

class _InMemoryNoteRepo extends NoteRepository {
  final List<Note> _notes = [];

  @override
  Future<List<Note>> fetchNotes() async => List<Note>.from(_notes);

  @override
  Future<int> addNote({required String title, String body = ''}) async {
    final id = _notes.length + 1;
    _notes.insert(
      0,
      Note(
        id: id,
        title: title,
        body: body,
        updatedAt: DateTime(2026, 11, 15),
        dirty: true,
      ),
    );
    return id;
  }

  @override
  Future<int> countDirty() async => _notes.where((n) => n.dirty).length;
}

class _InMemoryPostRepo extends PostRepository {
  _InMemoryPostRepo() : super(Dio());

  @override
  Future<List<Post>> fetchPostsPage({int page = 1, int limit = 20}) async =>
      const [];
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('alur utama: buka tab Catatan, tambah catatan, buka AI Chat', (
    tester,
  ) async {
    final noteRepo = _InMemoryNoteRepo();
    final postRepo = _InMemoryPostRepo();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noteRepositoryProvider.overrideWithValue(noteRepo),
          postRepositoryProvider.overrideWithValue(postRepo),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Pindah ke tab Catatan
    await tester.tap(find.text('Catatan'));
    await tester.pumpAndSettle();

    // Tambah catatan baru melalui form
    await tester.enterText(
      find.byKey(const Key('add_note_field')),
      'Tugas QA Minggu 12',
    );
    await tester.tap(find.byKey(const Key('add_note_button')));
    await tester.pumpAndSettle();

    expect(find.text('Tugas QA Minggu 12'), findsOneWidget);

    // Buka halaman AI Chat melalui FAB
    await tester.tap(find.byKey(const Key('open_ai_chat_fab')));
    await tester.pumpAndSettle();

    expect(find.text('AI Note Assistant'), findsOneWidget);
  });
}
