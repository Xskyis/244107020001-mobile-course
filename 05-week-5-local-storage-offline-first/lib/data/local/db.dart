import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

Future<Database> openLocalDatabase() async {
	final path = join(await getDatabasesPath(), 'week5_offline.db');
	return openDatabase(
		path,
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
	);
}
