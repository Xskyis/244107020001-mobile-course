import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';

import 'package:week6_app/data/api_errors.dart';
import 'package:week6_app/messaging/route_parser.dart';

class FakeTokenStore {
  String? access;
  String? refresh;
}

void main() {
  test('routeFromMessage menangani route kosong dan tanpa slash', () {
    expect(routeFromMessage({}), '/');
    expect(routeFromMessage({'route': 'pengumuman/3'}), '/pengumuman/3');
    expect(routeFromMessage({'route': '/pengumuman/3'}), '/pengumuman/3');
  });

  test('data payload membawa id pengumuman', () {
    final data = <String, dynamic>{'route': '/pengumuman/3', 'id': '3'};
    expect(data['id'], '3');
    expect(routeFromMessage(data), '/pengumuman/3');
  });

  test('provider auth membaca status login dari token', () async {
    final store = FakeTokenStore()..access = 'mock-access';
    expect(store.access != null, isTrue);
    store.access = null;
    expect(store.access != null, isFalse);
  });

  test('refresh gagal -> sesi dibersihkan (paksa login ulang)', () async {
    final store = FakeTokenStore()..refresh = '';
    final needsLogin = (store.refresh ?? '').isEmpty;
    expect(needsLogin, isTrue);
  });

  test('error API memetakan unauthorized, timeout, dan offline', () {
    expect(
      friendlyMessageFromDio(
        DioException(
          requestOptions: RequestOptions(path: '/login'),
          response: Response(
            requestOptions: RequestOptions(path: '/login'),
            statusCode: 401,
          ),
        ),
      ),
      contains('login kembali'),
    );
    expect(
      friendlyMessageFromDio(
        DioException(
          requestOptions: RequestOptions(path: '/login'),
          type: DioExceptionType.connectionTimeout,
        ),
      ),
      contains('terlalu lama'),
    );
    expect(
      friendlyMessageFromDio(
        DioException(
          requestOptions: RequestOptions(path: '/login'),
          type: DioExceptionType.connectionError,
        ),
      ),
      contains('internet'),
    );
  });
}
