import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

Future<Database> openLocalDatabase() async {
  final path = join(await getDatabasesPath(), 'week5_offline.db');
  return openDatabase(
    path,
    version: 2,
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
      await database.execute('''
				CREATE TABLE cached_posts (
					id INTEGER PRIMARY KEY,
					user_id INTEGER NOT NULL,
					title TEXT NOT NULL,
					body TEXT NOT NULL,
					cached_at INTEGER NOT NULL
				)
			''');
    },
    onUpgrade: (database, oldVersion, newVersion) async {
      if (oldVersion < 2) {
        final columns = await database.rawQuery('PRAGMA table_info(notes)');
        final existingColumns = columns.map((column) => column['name']).toSet();
        if (!existingColumns.contains('title')) {
          await database.execute(
            'ALTER TABLE notes ADD COLUMN title TEXT NOT NULL DEFAULT \'\'',
          );
        }
        if (!existingColumns.contains('body')) {
          await database.execute(
            'ALTER TABLE notes ADD COLUMN body TEXT NOT NULL DEFAULT \'\'',
          );
        }
        if (!existingColumns.contains('updated_at')) {
          await database.execute(
            'ALTER TABLE notes ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (!existingColumns.contains('dirty')) {
          await database.execute(
            'ALTER TABLE notes ADD COLUMN dirty INTEGER NOT NULL DEFAULT 1',
          );
        }
        if (existingColumns.contains('content')) {
          await database.execute(
            'UPDATE notes SET title = content WHERE title = \'\'',
          );
        }
        if (existingColumns.contains('is_dirty')) {
          await database.execute('UPDATE notes SET dirty = is_dirty');
        }
        await database.execute(
          'UPDATE notes SET updated_at = ? WHERE updated_at = 0',
          [DateTime.now().millisecondsSinceEpoch],
        );
      }
    },
  );
}
