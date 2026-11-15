import 'package:dio/dio.dart';

class _CacheEntry {
  _CacheEntry({required this.response, required this.cachedAt});

  final Response<dynamic> response;
  final DateTime cachedAt;
}

/// Interceptor Dio untuk caching respons GET di memori dengan batas TTL.
class TtlCacheInterceptor extends Interceptor {
  TtlCacheInterceptor({this.ttl = const Duration(seconds: 60)});

  final Duration ttl;
  final Map<String, _CacheEntry> _cache = {};

  int hitCount = 0;
  int missCount = 0;

  void clear() => _cache.clear();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.method.toUpperCase() != 'GET' ||
        options.extra['skipCache'] == true) {
      handler.next(options);
      return;
    }

    final key = options.uri.toString();
    final entry = _cache[key];
    if (entry != null && DateTime.now().difference(entry.cachedAt) < ttl) {
      hitCount++;
      handler.resolve(
        Response<dynamic>(
          requestOptions: options,
          data: entry.response.data,
          statusCode: entry.response.statusCode ?? 200,
          headers: entry.response.headers,
        ),
      );
      return;
    }

    missCount++;
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (response.requestOptions.method.toUpperCase() == 'GET' &&
        response.statusCode == 200) {
      _cache[response.requestOptions.uri.toString()] = _CacheEntry(
        response: response,
        cachedAt: DateTime.now(),
      );
    }
    handler.next(response);
  }
}

/// Interceptor Dio untuk retry otomatis pada error koneksi sementara.
class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    required this.dio,
    this.maxRetries = 2,
    this.baseDelay = const Duration(milliseconds: 300),
  });

  final Dio dio;
  final int maxRetries;
  final Duration baseDelay;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final attempt = (err.requestOptions.extra['retry_attempt'] as int?) ?? 0;
    final isTransient =
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError;

    if (!isTransient || attempt >= maxRetries) {
      handler.next(err);
      return;
    }

    await Future<void>.delayed(baseDelay * (attempt + 1));
    final options = err.requestOptions;
    options.extra['retry_attempt'] = attempt + 1;

    try {
      final response = await dio.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }
}
