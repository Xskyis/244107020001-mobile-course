/// Model representasi catatan untuk pencarian
class NoteItem {
  const NoteItem({
    this.id,
    required this.title,
    this.body = '',
    required this.updatedAt,
    this.dirty = false,
  });

  final int? id;
  final String title;
  final String body;
  final DateTime updatedAt;
  final bool dirty;
}

/// Fungsi murni (pure logic) untuk memfilter catatan berdasarkan query pencarian.
///
/// Logika pencarian bersifat case-insensitive, mengabaikan leading/trailing whitespace,
/// dan mencari kecocokan pada field [NoteItem.title] maupun [NoteItem.body].
List<T> filterNotesGeneric<T>({
  required List<T> notes,
  required String query,
  required String Function(T) getTitle,
  required String Function(T) getBody,
}) {
  final cleanQuery = query.trim().toLowerCase();
  if (cleanQuery.isEmpty) return notes;

  return notes.where((note) {
    final titleMatch = getTitle(note).toLowerCase().contains(cleanQuery);
    final bodyMatch = getBody(note).toLowerCase().contains(cleanQuery);
    return titleMatch || bodyMatch;
  }).toList();
}

