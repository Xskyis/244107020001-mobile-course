import 'package:dio/dio.dart';

import '../models/post.dart';

class PostRepository {
  PostRepository(this._dio);

  final Dio _dio;

  Future<List<Post>> fetchPosts() async {
    final response = await _dio.get<List<dynamic>>('/posts');
    final data = response.data ?? [];
    return data.whereType<Map<String, dynamic>>().map(Post.fromJson).toList();
  }

  /// Fetch post per halaman untuk pagination & payload yang lebih ringan.
  Future<List<Post>> fetchPostsPage({int page = 1, int limit = 20}) async {
    final response = await _dio.get<List<dynamic>>(
      '/posts',
      queryParameters: {'_page': page, '_limit': limit},
    );
    final data = response.data ?? [];
    return data.whereType<Map<String, dynamic>>().map(Post.fromJson).toList();
  }
}
