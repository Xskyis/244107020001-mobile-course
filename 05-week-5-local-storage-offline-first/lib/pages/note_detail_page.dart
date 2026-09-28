import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';

class NoteDetailPage extends ConsumerWidget {
  const NoteDetailPage({super.key, required this.noteId});

  final int noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final note = ref.watch(noteDetailProvider(noteId));
    return Scaffold(
      appBar: AppBar(title: Text('Detail catatan #$noteId')),
      body: note.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Gagal membaca catatan: $error')),
        data: (item) => item == null
            ? const Center(child: Text('Catatan tidak ditemukan.'))
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(item.title, style: Theme.of(context).textTheme.headlineSmall),
                  if (item.body.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(item.body),
                  ],
                  const SizedBox(height: 24),
                  Text(item.dirty ? 'belum tersinkron' : 'tersinkron'),
                ],
              ),
      ),
    );
  }
}