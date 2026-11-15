import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:week5_offline_notes/ai/ai_service.dart';
import 'package:week5_offline_notes/data/local/note.dart';
import 'package:week5_offline_notes/data/providers.dart';
import 'package:week5_offline_notes/data/repositories/note_repository.dart';
import 'package:week5_offline_notes/features/chat_screen.dart';

class InMemorySecureStorage extends FlutterSecureStorage {
  InMemorySecureStorage([Map<String, String>? initial])
    : _store = Map<String, String>.from(initial ?? {});

  final Map<String, String> _store;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _store[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _store.remove(key);
    } else {
      _store[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _store.remove(key);
  }
}

class FakeAiNoteRepository extends NoteRepository {
  final List<Note> savedNotes = [];

  @override
  Future<int> addNote({required String title, String body = ''}) async {
    final id = savedNotes.length + 1;
    savedNotes.add(
      Note(
        id: id,
        title: title,
        body: body,
        updatedAt: DateTime.now(),
        dirty: true,
      ),
    );
    return id;
  }

  @override
  Future<List<Note>> fetchNotes() async => savedNotes;

  @override
  Future<int> countDirty() async => savedNotes.where((n) => n.dirty).length;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AiService Unit Tests', () {
    test('parseGeneratedNote mem-parsing format JUDUL dan ISI dengan benar', () {
      const raw = '''
JUDUL: Ringkasan Riverpod
ISI:
- Provider: menyimpan state immutable
- Notifier: mengelola state reaktif
''';
      final result = AiService.parseGeneratedNote(raw);
      expect(result.title, 'Ringkasan Riverpod');
      expect(result.body, contains('Provider: menyimpan state immutable'));
      expect(result.body, contains('Notifier: mengelola state reaktif'));
    });

    test('containsSensitiveData mendeteksi API key dan 16 digit NIK', () {
      expect(
        AiService.containsSensitiveData('Kunci saya AIzaSyDummyKey123456789012345'),
        isTrue,
      );
      expect(
        AiService.containsSensitiveData('NIK saya 3507123456789012'),
        isTrue,
      );
      expect(
        AiService.containsSensitiveData('Buatkan catatan kuliah Pemrograman Mobile'),
        isFalse,
      );
    });

    test('generateNote memanggil API, menyimpan cache, dan menghitung kuota', () async {
      var callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'text':
                          'JUDUL: Catatan Flutter AI\nISI:\n- Gunakan flutter_secure_storage\n- Terapkan fallback offline',
                    },
                  ],
                },
              },
            ],
          }),
          200,
        );
      });

      final service = AiService(
        storage: InMemorySecureStorage({AiService.apiKeyStorageKey: 'test-key'}),
        client: mockClient,
      );

      final first = await service.generateNote('Buat catatan Flutter AI');
      expect(first.title, 'Catatan Flutter AI');
      expect(first.fromCache, isFalse);
      expect(callCount, 1);
      expect(await service.getDailyUsageCount(), 1);

      final second = await service.generateNote('buat catatan flutter ai');
      expect(second.fromCache, isTrue);
      expect(callCount, 1);
    });

    test('generateNote melempar AiOfflineException saat forceOffline aktif', () async {
      final service = AiService(
        storage: InMemorySecureStorage({AiService.apiKeyStorageKey: 'test-key'}),
      );

      expect(
        () => service.generateNote('Topik belajar', forceOffline: true),
        throwsA(isA<AiOfflineException>()),
      );
    });

    test('generateNote melempar AiMissingKeyException jika API key kosong', () async {
      final service = AiService(
        storage: InMemorySecureStorage(),
        envKeyProvider: () => '',
      );

      expect(
        () => service.generateNote('Topik belajar'),
        throwsA(isA<AiMissingKeyException>()),
      );
    });

    test('generateNote memakai model gemini-flash-lite-latest dan fallback .env', () async {
      Uri? calledUri;
      final mockClient = MockClient((request) async {
        calledUri = request.url;
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'JUDUL: Tes Env\nISI:\n- Berhasil'},
                  ],
                },
              },
            ],
          }),
          200,
        );
      });

      final service = AiService(
        storage: InMemorySecureStorage(),
        client: mockClient,
        envKeyProvider: () => 'env-secret-key',
      );

      final result = await service.generateNote('Tes Env');
      expect(result.title, 'Tes Env');
      expect(calledUri.toString(), contains('gemini-flash-lite-latest:generateContent'));
      expect(calledUri?.queryParameters['key'], 'env-secret-key');
    });
  });

  group('AiChatScreen Widget Tests', () {
    testWidgets(
      'Menampilkan fallback lokal saat API key kosong dan menyimpan catatan',
      (tester) async {
        final fakeRepo = FakeAiNoteRepository();
        final fakeAiService = AiService(storage: InMemorySecureStorage());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              noteRepositoryProvider.overrideWithValue(fakeRepo),
              aiServiceProvider.overrideWithValue(fakeAiService),
            ],
            child: const MaterialApp(home: AiChatScreen()),
          ),
        );

        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('ai_chat_input')),
          'Checklist UAS Mobile',
        );
        await tester.tap(find.byKey(const Key('ai_chat_send_btn')));
        await tester.pumpAndSettle();

        expect(find.text('Layanan AI Tidak Tersedia'), findsOneWidget);
        expect(find.byKey(const Key('use_fallback_btn')), findsOneWidget);

        await tester.tap(find.byKey(const Key('use_fallback_btn')));
        await tester.pumpAndSettle();

        expect(find.text('Offline Fallback'), findsOneWidget);
        expect(find.byKey(const Key('save_ai_note_btn')), findsOneWidget);

        await tester.tap(find.byKey(const Key('save_ai_note_btn')));
        await tester.pumpAndSettle();

        expect(fakeRepo.savedNotes.length, 1);
        expect(fakeRepo.savedNotes.first.title, contains('Checklist UAS Mobile'));
        expect(find.text('Tersimpan'), findsOneWidget);
      },
    );
  });
}
