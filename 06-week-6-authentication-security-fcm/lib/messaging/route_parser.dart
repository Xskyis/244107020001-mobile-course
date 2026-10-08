import '../routes.dart';

String routeFromMessage(Map<String, dynamic> data) {
  final value = data['route'];
  if (value is! String || value.isEmpty) return AppRoutes.home;
  return value.startsWith('/') ? value : '/$value';
}
