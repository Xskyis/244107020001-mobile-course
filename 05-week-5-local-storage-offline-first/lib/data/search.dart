import 'local/note.dart';

/// Memfilter daftar catatan berdasarkan query pencarian secara case-insensitive.
///
/// Memeriksa kecocokan pada field [Note.title] maupun [Note.body].
/// Jika [query] kosong atau hanya spasi, seluruh [notes] dikembalikan apa adanya.
List<Note> filterNotesByQuery(List<Note> notes, String query) {
  final cleanQuery = query.trim().toLowerCase();
  if (cleanQuery.isEmpty) return notes;
  return notes.where((note) {
    final titleMatch = note.title.toLowerCase().contains(cleanQuery);
    final bodyMatch = note.body.toLowerCase().contains(cleanQuery);
    return titleMatch || bodyMatch;
  }).toList();
}

