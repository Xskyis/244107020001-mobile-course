import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/failures.dart';
import '../../domain/entities/note.dart';
import '../../domain/repositories/note_repository.dart';
import '../models/note_model.dart';

Future<Database> openDefaultNotesDb() async {
  final dbPath = join(await getDatabasesPath(), 'week7_notes.db');
  return openDatabase(
    dbPath,
    version: 1,
    onCreate: (database, version) async {
      await database.execute('''
        CREATE TABLE notes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          body TEXT NOT NULL DEFAULT '',
          updated_at INTEGER NOT NULL,
          dirty INTEGER NOT NULL DEFAULT 1
        )
      ''');
    },
  );
}

class NoteRepositoryImpl implements NoteRepository {
  NoteRepositoryImpl({Future<Database> Function()? openDb})
      : _openDb = openDb ?? openDefaultNotesDb;

  final Future<Database> Function() _openDb;

  @override
  Future<({List<Note> notes, Failure? failure})> fetchNotes() async {
    try {
      final db = await _openDb();
      final rows = await db.query('notes', orderBy: 'updated_at DESC');
      final notes =
          rows.map((r) => NoteModel.fromMap(r).toEntity()).toList();
      return (notes: notes, failure: null);
    } catch (e) {
      return (
        notes: const <Note>[],
        failure: LocalFailure('Gagal membaca catatan dari database lokal: $e'),
      );
    }
  }

  @override
  Future<({Note? note, Failure? failure})> addNote({
    required String title,
    String body = '',
  }) async {
    try {
      final db = await _openDb();
      final now = DateTime.now();
      final model = NoteModel(
        title: title,
        body: body,
        updatedAt: now,
        dirty: true,
      );
      final id = await db.insert('notes', model.toMap());
      return (
        note: Note(
          id: id,
          title: title,
          body: body,
          updatedAt: now,
          dirty: true,
        ),
        failure: null,
      );
    } catch (e) {
      return (
        note: null,
        failure: LocalFailure('Gagal menyimpan catatan ke database lokal: $e'),
      );
    }
  }

  @override
  Future<({int count, Failure? failure})> countDirty() async {
    try {
      final db = await _openDb();
      final result = await db.rawQuery(
        'SELECT COUNT(*) AS count FROM notes WHERE dirty = 1',
      );
      final count = Sqflite.firstIntValue(result) ?? 0;
      return (count: count, failure: null);
    } catch (e) {
      return (
        count: 0,
        failure: LocalFailure('Gagal menghitung catatan dirty: $e'),
      );
    }
  }

  @override
  Future<({int syncedCount, Failure? failure})> syncNotes() async {
    try {
      final db = await _openDb();
      final dirtyRes = await db.rawQuery(
        'SELECT COUNT(*) AS count FROM notes WHERE dirty = 1',
      );
      final count = Sqflite.firstIntValue(dirtyRes) ?? 0;
      if (count == 0) {
        return (syncedCount: 0, failure: null);
      }
      // Simulasi upload latency 1 detik (sesuai baseline Week 5)
      await Future<void>.delayed(const Duration(seconds: 1));
      await db.update('notes', {'dirty': 0}, where: 'dirty = 1');
      return (syncedCount: count, failure: null);
    } catch (e) {
      return (
        syncedCount: 0,
        failure: LocalFailure('Gagal sinkronisasi catatan: $e'),
      );
    }
  }
}
