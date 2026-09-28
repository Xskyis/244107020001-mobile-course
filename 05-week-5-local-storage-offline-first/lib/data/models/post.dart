class Post {
  const Post({
    required this.userId,
    required this.id,
    required this.title,
    required this.body,
  });

  final int userId;
  final int id;
  final String title;
  final String body;

  factory Post.fromMap(Map<String, Object?> map) => Post(
    userId: map['user_id'] as int,
    id: map['id'] as int,
    title: map['title'] as String,
    body: map['body'] as String,
  );

  factory Post.fromJson(Map<String, dynamic> json) => Post(
    userId: (json['userId'] as num?)?.toInt() ?? 0,
    id: (json['id'] as num?)?.toInt() ?? 0,
    title: json['title'] as String? ?? '',
    body: json['body'] as String? ?? '',
  );

  Map<String, Object?> toCacheMap() => {
    'id': id,
    'user_id': userId,
    'title': title,
    'body': body,
    'cached_at': DateTime.now().millisecondsSinceEpoch,
  };
}
