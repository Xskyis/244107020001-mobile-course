import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'data/models/post.dart';
import 'data/providers.dart';
import 'data/sync.dart';
import 'router.dart';
import 'widgets/note_tile.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Batasi ukuran imageCache di memori agar mencegah lonjakan konsumsi RAM.
  PaintingBinding.instance.imageCache.maximumSize = 100;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 << 20;
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Abaikan bila .env tidak ditemukan pada environment test
  }
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Offline First Notes',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() => initializePreferences(ref));
  }

  @override
  Widget build(BuildContext context) {
    const pages = [PostsTab(), NotesTab(), SettingsTab()];
    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.article_outlined),
            label: 'Posts',
          ),
          NavigationDestination(
            icon: Icon(Icons.note_alt_outlined),
            label: 'Catatan',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'Pengaturan',
          ),
        ],
      ),
    );
  }
}

class PostsTab extends ConsumerStatefulWidget {
  const PostsTab({super.key});

  @override
  ConsumerState<PostsTab> createState() => _PostsTabState();
}

class _PostsTabState extends ConsumerState<PostsTab> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(paginatedPostsProvider.notifier).loadMore();
    }
  }

  Future<void> _refresh() =>
      ref.read(paginatedPostsProvider.notifier).refresh();

  @override
  Widget build(BuildContext context) {
    final postsState = ref.watch(paginatedPostsProvider);
    final offline = ref.watch(forceOfflineProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cache-first posts'),
        actions: [
          if (offline)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Icon(Icons.cloud_off),
            ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (postsState.isLoading && postsState.items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (postsState.error != null && postsState.items.isEmpty) {
            return Center(
              child: Text('Gagal membaca cache: ${postsState.error}'),
            );
          }
          if (postsState.items.isEmpty) {
            return const Center(
              child: Text('Belum ada cache. Refresh saat online.'),
            );
          }
          final itemCount =
              postsState.items.length + (postsState.hasMore ? 1 : 0);
          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(12),
            itemCount: itemCount,
            itemBuilder: (context, index) {
              if (index == postsState.items.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final post = postsState.items[index];
              return _PostTile(key: ValueKey(post.id), post: post);
            },
          );
        },
      ),
    );
  }
}

class _PostTile extends StatelessWidget {
  const _PostTile({super.key, required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ListTile(
        title: Text(post.title),
        subtitle: Text(post.body),
        leading: CircleAvatar(child: Text('${post.id}')),
      ),
    );
  }
}

class NotesTab extends ConsumerStatefulWidget {
  const NotesTab({super.key});

  @override
  ConsumerState<NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends ConsumerState<NotesTab> {
  final _controller = TextEditingController();
  final _searchController = TextEditingController();
  bool _syncing = false;

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addNote() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;
    try {
      await ref.read(noteRepositoryProvider).add(content);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Catatan gagal disimpan: $error')));
      return;
    }
    _controller.clear();
    ref.invalidate(notesProvider);
    ref.invalidate(dirtyCountProvider);
  }

  Future<void> _sync() async {
    if (ref.read(forceOfflineProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sync tidak tersedia saat mode offline aktif.'),
        ),
      );
      return;
    }
    setState(() => _syncing = true);
    final count = await syncNotes(
      ref.read(noteRepositoryProvider),
      forceOffline: ref.read(forceOfflineProvider),
    );
    if (!mounted) return;
    setState(() => _syncing = false);
    ref.invalidate(notesProvider);
    ref.invalidate(dirtyCountProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count == 0
              ? 'Tidak ada catatan dirty.'
              : '$count catatan tersinkron.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredNotes = ref.watch(filteredNotesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catatan offline'),
        actions: [
          _SyncBadgeButton(syncing: _syncing, onSync: _sync),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              key: const Key('search_notes_field'),
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _SearchClearButton(
                  controller: _searchController,
                ),
                hintText: 'Cari judul atau isi catatan...',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                ref.read(searchQueryProvider.notifier).setQuery(value);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: 'Catatan baru',
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _addNote,
                  icon: const Icon(Icons.add_circle),
                ),
              ],
            ),
          ),
          Expanded(
            child: filteredNotes.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Gagal membaca catatan: $error')),
              data: (items) {
                if (items.isEmpty) {
                  final currentQuery = ref.read(searchQueryProvider);
                  if (currentQuery.trim().isNotEmpty) {
                    return _SearchEmptyState(query: currentQuery);
                  }
                  return const Center(child: Text('Belum ada catatan.'));
                }
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final note = items[index];
                    return NoteTile(key: ValueKey(note.id), note: note);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('open_ai_chat_fab'),
        onPressed: () => context.push('/ai-chat'),
        icon: const Icon(Icons.auto_awesome),
        label: const Text('AI Chat'),
      ),
    );
  }
}

class _SyncBadgeButton extends ConsumerWidget {
  const _SyncBadgeButton({required this.syncing, required this.onSync});

  final bool syncing;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dirtyCount = ref.watch(dirtyCountProvider).value ?? 0;
    return Badge(
      label: Text('$dirtyCount'),
      isLabelVisible: dirtyCount > 0,
      child: IconButton(
        tooltip: 'Sync catatan',
        onPressed: syncing ? null : onSync,
        icon: syncing
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.sync),
      ),
    );
  }
}

class _SearchClearButton extends ConsumerWidget {
  const _SearchClearButton({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasQuery = ref.watch(
      searchQueryProvider.select((q) => q.isNotEmpty),
    );
    if (!hasQuery) return const SizedBox.shrink();
    return IconButton(
      icon: const Icon(Icons.clear),
      onPressed: () {
        controller.clear();
        ref.read(searchQueryProvider.notifier).clear();
      },
    );
  }
}

class _SearchEmptyState extends StatelessWidget {
  const _SearchEmptyState({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.search_off,
            size: 48,
            color: Colors.grey,
          ),
          const SizedBox(height: 8),
          Text(
            'Tidak ada catatan yang cocok dengan "$query"',
            key: const Key('search_empty_state_text'),
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class SettingsTab extends ConsumerWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(forceOfflineProvider);
    final darkMode = ref.watch(themeModeProvider) == ThemeMode.dark;
    final lastOpened = ref.watch(lastOpenedProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan offline')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Tema gelap'),
            subtitle: const Text('Disimpan sebagai preferensi lokal'),
            value: darkMode,
            onChanged: (value) => setDarkMode(ref, value),
          ),
          SwitchListTile(
            title: const Text('Paksa mode offline'),
            subtitle: const Text('Posts dan catatan tidak memakai jaringan'),
            value: offline,
            onChanged: (value) => setForceOffline(ref, value),
          ),
          if (lastOpened != null)
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Terakhir dibuka'),
              subtitle: Text(lastOpened.toLocal().toString()),
            ),
        ],
      ),
    );
  }
}
