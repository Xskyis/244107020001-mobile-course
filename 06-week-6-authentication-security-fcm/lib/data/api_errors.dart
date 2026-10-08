import 'package:dio/dio.dart';

String friendlyMessageFromDio(DioException error) {
  if (error.response?.statusCode == 401) {
    return 'Sesi Anda telah berakhir. Silakan login kembali.';
  }

  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return 'Koneksi terlalu lama. Periksa jaringan dan coba lagi.';
    case DioExceptionType.connectionError:
      return 'Tidak dapat terhubung ke server. Periksa koneksi internet.';
    default:
      return 'Terjadi kesalahan jaringan. Silakan coba lagi.';
  }
}
