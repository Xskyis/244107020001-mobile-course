import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/providers.dart';
import 'data/sync.dart';
import 'router.dart';
import 'widgets/note_tile.dart';

void main() {
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
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
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
            child: notes.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Gagal membaca catatan: $error')),
              data: (items) => items.isEmpty
                  ? const Center(child: Text('Belum ada catatan.'))
                  : ListView(
                      children: items
                          .map((note) => NoteTile(note: note))
                          .toList(),
                    ),
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
