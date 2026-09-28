import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/providers.dart';
import 'data/sync.dart';
import 'router.dart';
import 'widgets/note_tile.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Offline First Notes',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal)),
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
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.article_outlined), label: 'Posts'),
          NavigationDestination(icon: Icon(Icons.note_alt_outlined), label: 'Catatan'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Pengaturan'),
        ],
      ),
    );
  }
}

class PostsTab extends ConsumerWidget {
  const PostsTab({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    await refreshPostsInBackground(ref.read(postRepositoryProvider));
    ref.invalidate(postsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(postsProvider);
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
            onPressed: () => _refresh(ref),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: posts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Gagal membaca cache: $error')),
        data: (items) => items.isEmpty
            ? const Center(child: Text('Belum ada cache. Refresh saat online.'))
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final post = items[index];
                  return ListTile(
                    title: Text(post.title),
                    subtitle: Text(post.body),
                    leading: CircleAvatar(child: Text('${post.id}')),
                  );
                },
              ),
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
  bool _syncing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _addNote() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;
    await ref.read(noteRepositoryProvider).add(content);
    _controller.clear();
    ref.invalidate(notesProvider);
    ref.invalidate(dirtyCountProvider);
  }

  Future<void> _sync() async {
    setState(() => _syncing = true);
    final count = await syncNotes(ref.read(noteRepositoryProvider));
    if (!mounted) return;
    setState(() => _syncing = false);
    ref.invalidate(notesProvider);
    ref.invalidate(dirtyCountProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(count == 0 ? 'Tidak ada catatan dirty.' : '$count catatan tersinkron.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(notesProvider);
    final dirtyCount = ref.watch(dirtyCountProvider).value ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catatan offline'),
        actions: [
          Badge(
            label: Text('$dirtyCount'),
            isLabelVisible: dirtyCount > 0,
            child: IconButton(
              tooltip: 'Sync catatan',
              onPressed: _syncing ? null : _sync,
              icon: _syncing
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.sync),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: TextField(controller: _controller, decoration: const InputDecoration(labelText: 'Catatan baru'))),
                IconButton(onPressed: _addNote, icon: const Icon(Icons.add_circle)),
              ],
            ),
          ),
          Expanded(
            child: notes.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Gagal membaca catatan: $error')),
              data: (items) => items.isEmpty
                  ? const Center(child: Text('Belum ada catatan.'))
                  : ListView(children: items.map((note) => NoteTile(note: note)).toList()),
            ),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan offline')),
      body: SwitchListTile(
        title: const Text('Paksa mode offline'),
        subtitle: const Text('Posts hanya membaca cached_posts'),
        value: offline,
        onChanged: (value) => setForceOffline(ref, value),
      ),
    );
  }
}
