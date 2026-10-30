import '../../domain/entities/note.dart';

class NoteModel extends Note {
  const NoteModel({
    super.id,
    required super.title,
    super.body = '',
    required super.updatedAt,
    super.dirty = false,
  });

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'title': title,
    'body': body,
    'updated_at': updatedAt.millisecondsSinceEpoch,
    'dirty': dirty ? 1 : 0,
  };

  factory NoteModel.fromMap(Map<String, Object?> map) {
    DateTime parsedDate;
    final rawDate = map['updated_at'];
    if (rawDate is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(rawDate);
    } else if (rawDate is String) {
      parsedDate =
          DateTime.tryParse(rawDate) ?? DateTime.fromMillisecondsSinceEpoch(0);
    } else {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(0);
    }

    return NoteModel(
      id: (map['id'] as num?)?.toInt(),
      title: map['title'] as String? ?? map['content'] as String? ?? '',
      body: map['body'] as String? ?? '',
      updatedAt: parsedDate,
      dirty: ((map['dirty'] ?? map['is_dirty']) as num? ?? 0) == 1,
    );
  }

  factory NoteModel.fromEntity(Note note) {
    return NoteModel(
      id: note.id,
      title: note.title,
      body: note.body,
      updatedAt: note.updatedAt,
      dirty: note.dirty,
    );
  }

  Note toEntity() => Note(
    id: id,
    title: title,
    body: body,
    updatedAt: updatedAt,
    dirty: dirty,
  );
}
