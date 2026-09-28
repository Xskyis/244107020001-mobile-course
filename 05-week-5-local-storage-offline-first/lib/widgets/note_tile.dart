import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/local/note.dart';

class NoteTile extends StatelessWidget {
  const NoteTile({super.key, required this.note});

  final Note note;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: note.id == null ? null : () => context.push('/note/${note.id}'),
      leading: Icon(
        note.dirty ? Icons.cloud_upload_outlined : Icons.cloud_done_outlined,
      ),
      title: Text(note.title),
      subtitle: note.body.isEmpty ? null : Text(note.body),
      trailing: note.dirty
          ? const Chip(label: Text('belum tersinkron'))
          : const Icon(Icons.chevron_right),
    );
  }
}