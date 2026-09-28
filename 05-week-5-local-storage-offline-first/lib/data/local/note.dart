class Note {
	const Note({
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

	String get content => body.isEmpty ? title : '$title\n$body';
	bool get isDirty => dirty;

	factory Note.fromMap(Map<String, Object?> map) => Note(
				id: map['id'] as int?,
				title: map['title'] as String? ?? map['content'] as String? ?? '',
				body: map['body'] as String? ?? '',
				updatedAt: DateTime.fromMillisecondsSinceEpoch(
					(map['updated_at'] as int?) ?? 0,
				),
				dirty: ((map['dirty'] ?? map['is_dirty']) as int? ?? 0) == 1,
			);

	Map<String, Object?> toMap() => {
				if (id != null) 'id': id,
				'title': title,
				'body': body,
				'updated_at': updatedAt.millisecondsSinceEpoch,
				'dirty': dirty ? 1 : 0,
			};
}
