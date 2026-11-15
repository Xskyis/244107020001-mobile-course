import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';

import '../local/db.dart';
import '../local/note.dart';

class NoteRepository {
  NoteRepository({Future<Database> Function()? openDb})
    : _openDb = openDb ?? openLocalDatabase;

  final Future<Database> Function() _openDb;

  static final List<Note> _webNotes = [
    Note(
      id: 1,
      title: 'Catatan Kuliah Mobile',
      body: 'Mempelajari Offline-First SQLite dan integrasi fitur AI.',
      updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
      dirty: false,
    ),
  ];
  static int _webNextId = 2;

  Future<List<Note>> fetchNotes() async {
    if (kIsWeb) {
      return List<Note>.from(_webNotes)
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
    final database = await _openDb();
    final rows = await database.query('notes', orderBy: 'updated_at DESC');
    return rows.map(Note.fromMap).toList();
  }

  Future<Note?> fetchNote(int id) async {
    if (kIsWeb) {
      for (final note in _webNotes) {
        if (note.id == id) return note;
      }
      return null;
    }
    final database = await _openDb();
    final rows = await database.query(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Note.fromMap(rows.first);
  }

  Future<int> addNote({required String title, String body = ''}) async {
    if (kIsWeb) {
      final id = _webNextId++;
      _webNotes.insert(
        0,
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
    final database = await _openDb();
    final columns = await database.rawQuery('PRAGMA table_info(notes)');
    final existingColumns = columns.map((column) => column['name']).toSet();
    final note = Note(
      title: title,
      body: body,
      updatedAt: DateTime.now(),
      dirty: true,
    );
    final values = note.toMap();
    if (existingColumns.contains('content')) values['content'] = title;
    if (existingColumns.contains('is_dirty')) values['is_dirty'] = 1;
    return database.insert('notes', values);
  }

  Future<int> countDirty() async {
    if (kIsWeb) {
      return _webNotes.where((note) => note.dirty).length;
    }
    final database = await _openDb();
    final result = await database.rawQuery(
      'SELECT COUNT(*) AS count FROM notes WHERE dirty = 1',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> markAllSynced() async {
    if (kIsWeb) {
      for (var i = 0; i < _webNotes.length; i++) {
        final note = _webNotes[i];
        if (note.dirty) {
          _webNotes[i] = Note(
            id: note.id,
            title: note.title,
            body: note.body,
            updatedAt: note.updatedAt,
            dirty: false,
          );
        }
      }
      return;
    }
    final database = await _openDb();
    await database.update('notes', {'dirty': 0}, where: 'dirty = 1');
  }

  Future<void> add(String content) => addNote(title: content);
  Future<List<Note>> getNotes() => fetchNotes();
}
