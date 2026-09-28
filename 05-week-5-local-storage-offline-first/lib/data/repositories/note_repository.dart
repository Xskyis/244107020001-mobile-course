import 'package:sqflite/sqflite.dart';

import '../local/db.dart';
import '../local/note.dart';

class NoteRepository {
  NoteRepository({Future<Database> Function()? openDb})
      : _openDb = openDb ?? openLocalDatabase;

  final Future<Database> Function() _openDb;

  Future<List<Note>> fetchNotes() async {
    final database = await _openDb();
    final rows = await database.query('notes', orderBy: 'updated_at DESC');
    return rows.map(Note.fromMap).toList();
  }

  Future<Note?> fetchNote(int id) async {
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
    final database = await _openDb();
    return database.insert(
      'notes',
      Note(
        title: title,
        body: body,
        updatedAt: DateTime.now(),
        dirty: true,
      ).toMap(),
    );
  }

  Future<int> countDirty() async {
    final database = await _openDb();
    final result = await database.rawQuery(
      'SELECT COUNT(*) AS count FROM notes WHERE dirty = 1',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> markAllSynced() async {
    final database = await _openDb();
    await database.update('notes', {'dirty': 0}, where: 'dirty = 1');
  }

  Future<void> add(String content) => addNote(title: content);
  Future<List<Note>> getNotes() => fetchNotes();
}
