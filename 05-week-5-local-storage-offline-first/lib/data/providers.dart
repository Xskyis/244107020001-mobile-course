import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai/ai_service.dart';
import 'local/note.dart';
import 'models/post.dart';
import 'prefs.dart';
import 'repositories/note_repository.dart';
import 'repositories/post_repository.dart';
import 'search.dart';
import 'sync.dart';

final dioProvider = Provider<Dio>(
  (ref) => Dio(
    BaseOptions(
      baseUrl: 'https://jsonplaceholder.typicode.com',
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ),
  ),
);

class ForceOfflineNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setValue(bool value) => state = value;
}

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.light;

  void setValue(ThemeMode value) => state = value;
}

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
  void clear() => state = '';
}

final forceOfflineProvider = NotifierProvider<ForceOfflineNotifier, bool>(
  ForceOfflineNotifier.new,
);
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(
  SearchQueryNotifier.new,
);

final lastOpenedProvider = FutureProvider<DateTime?>((ref) => readLastOpened());

final noteRepositoryProvider = Provider<NoteRepository>(
  (ref) => NoteRepository(),
);
final postRepositoryProvider = Provider<PostRepository>(
  (ref) => PostRepository(ref.watch(dioProvider)),
);

final notesProvider = FutureProvider<List<Note>>(
  (ref) => ref.watch(noteRepositoryProvider).fetchNotes(),
  retry: (retryCount, error) => null,
);

final filteredNotesProvider = Provider<AsyncValue<List<Note>>>((ref) {
  final notesAsync = ref.watch(notesProvider);
  final query = ref.watch(searchQueryProvider);
  return notesAsync.whenData((notes) => filterNotesByQuery(notes, query));
});

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
  final darkMode = await readDarkMode();
  ref
      .read(themeModeProvider.notifier)
      .setValue(darkMode ? ThemeMode.dark : ThemeMode.light);
  await writeLastOpened(DateTime.now());
  ref.invalidate(lastOpenedProvider);
}

Future<void> setForceOffline(WidgetRef ref, bool value) async {
  ref.read(forceOfflineProvider.notifier).setValue(value);
  await writeForceOffline(value);
  ref.invalidate(postsProvider);
}

Future<void> setDarkMode(WidgetRef ref, bool value) async {
  ref
      .read(themeModeProvider.notifier)
      .setValue(value ? ThemeMode.dark : ThemeMode.light);
  await writeDarkMode(value);
}

final aiServiceProvider = Provider<AiService>((ref) => AiService());

final hasApiKeyProvider = FutureProvider<bool>(
  (ref) => ref.watch(aiServiceProvider).hasApiKey(),
);

final aiDailyUsageProvider = FutureProvider<int>(
  (ref) => ref.watch(aiServiceProvider).getDailyUsageCount(),
);

class ChatMessage {
  const ChatMessage({
    required this.isUser,
    required this.text,
    this.generatedNote,
    this.isSaved = false,
    this.isError = false,
    this.failedPrompt,
  });

  final bool isUser;
  final String text;
  final GeneratedNoteResult? generatedNote;
  final bool isSaved;
  final bool isError;
  final String? failedPrompt;

  ChatMessage copyWith({
    String? text,
    GeneratedNoteResult? generatedNote,
    bool? isSaved,
    bool? isError,
    String? failedPrompt,
  }) {
    return ChatMessage(
      isUser: isUser,
      text: text ?? this.text,
      generatedNote: generatedNote ?? this.generatedNote,
      isSaved: isSaved ?? this.isSaved,
      isError: isError ?? this.isError,
      failedPrompt: failedPrompt ?? this.failedPrompt,
    );
  }
}

class AiChatState {
  const AiChatState({
    this.messages = const [],
    this.isGenerating = false,
    this.streamingPreview = '',
  });

  final List<ChatMessage> messages;
  final bool isGenerating;
  final String streamingPreview;

  AiChatState copyWith({
    List<ChatMessage>? messages,
    bool? isGenerating,
    String? streamingPreview,
  }) {
    return AiChatState(
      messages: messages ?? this.messages,
      isGenerating: isGenerating ?? this.isGenerating,
      streamingPreview: streamingPreview ?? this.streamingPreview,
    );
  }
}

class AiChatNotifier extends Notifier<AiChatState> {
  @override
  AiChatState build() => const AiChatState();

  Future<void> sendPrompt(String prompt) async {
    final clean = prompt.trim();
    if (clean.isEmpty || state.isGenerating) return;

    final aiService = ref.read(aiServiceProvider);
    final forceOffline = ref.read(forceOfflineProvider);

    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(isUser: true, text: clean),
      ],
      isGenerating: true,
      streamingPreview: '',
    );

    try {
      final result = await aiService.generateNote(
        clean,
        forceOffline: forceOffline,
      );
      await _streamAndAppend(result);
      ref.invalidate(aiDailyUsageProvider);
    } catch (error) {
      state = state.copyWith(
        messages: [
          ...state.messages,
          ChatMessage(
            isUser: false,
            text: error.toString(),
            isError: true,
            failedPrompt: clean,
          ),
        ],
        isGenerating: false,
        streamingPreview: '',
      );
    }
  }

  Future<void> generateWithFallback(String prompt) async {
    final clean = prompt.trim();
    if (clean.isEmpty || state.isGenerating) return;

    state = state.copyWith(isGenerating: true, streamingPreview: '');
    final fallback = AiService.generateFallbackNote(clean);
    await _streamAndAppend(fallback);
  }

  Future<void> _streamAndAppend(GeneratedNoteResult result) async {
    final aiService = ref.read(aiServiceProvider);
    await for (final chunk in aiService.streamTextChunks(result.rawResponse)) {
      if (!ref.mounted) return;
      state = state.copyWith(streamingPreview: chunk);
    }
    if (!ref.mounted) return;
    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(
          isUser: false,
          text: result.body,
          generatedNote: result,
        ),
      ],
      isGenerating: false,
      streamingPreview: '',
    );
  }

  Future<void> saveNoteFromMessage(int index) async {
    if (index < 0 || index >= state.messages.length) return;
    final msg = state.messages[index];
    final generated = msg.generatedNote;
    if (generated == null || msg.isSaved) return;

    await ref
        .read(noteRepositoryProvider)
        .addNote(title: generated.title, body: generated.body);
    ref.invalidate(notesProvider);
    ref.invalidate(dirtyCountProvider);

    final updated = List<ChatMessage>.from(state.messages);
    updated[index] = msg.copyWith(isSaved: true);
    state = state.copyWith(messages: updated);
  }

  void clearChat() {
    state = const AiChatState();
  }
}

final aiChatProvider = NotifierProvider<AiChatNotifier, AiChatState>(
  AiChatNotifier.new,
);
