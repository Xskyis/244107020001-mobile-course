import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/api_client.dart';
import 'route_parser.dart';

class PushService {
  PushService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final ApiClient _apiClient = ApiClient();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'pengumuman',
    'Pengumuman Kampus',
    description: 'Notifications for important campus updates.',
    importance: Importance.high,
  );

  static String? pendingDeepLink;

  static Future<void> initialize(void Function(String route) go) async {
    await _requestPermission();
    await _initializeLocalNotifications(go);

    final token = await _messaging.getToken();
    if (token != null) await _registerDevice(token);
    await subscribeToAnnouncements();

    _messaging.onTokenRefresh.listen((newToken) {
      _registerDevice(newToken);
    });
    listenForeground(go);
    await handleTerminated(go);
  }

  static Future<void> subscribeToAnnouncements() {
    return _messaging.subscribeToTopic('pengumuman-kampus');
  }

  static Future<void> unsubscribeFromAnnouncements() {
    return _messaging.unsubscribeFromTopic('pengumuman-kampus');
  }

  static Future<void> _registerDevice(String token) async {
    try {
      await _apiClient.registerDevice(
        token: token,
        platform: defaultTargetPlatform.name,
      );
      debugPrint('FCM device registered: ${_maskToken(token)}');
    } catch (error) {
      debugPrint('FCM device registration failed: $error');
    }
  }

  static String _maskToken(String token) {
    if (token.length <= 8) return '***';
    return '${token.substring(0, 4)}...${token.substring(token.length - 4)}';
  }

  static Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('Notification permission: ${settings.authorizationStatus}');
  }

  static Future<void> _initializeLocalNotifications(
    void Function(String route) go,
  ) async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const settings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final route = response.payload;
        if (route != null && route.isNotEmpty) go(route);
      },
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(_channel);
    await androidPlugin?.requestNotificationsPermission();
  }

  static void listenForeground(void Function(String route) go) {
    FirebaseMessaging.onMessage.listen((message) async {
      await _showForegroundNotification(message);
    });
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      go(routeFromMessage(message.data));
    });
  }

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;

    await _localNotifications.show(
      id: message.hashCode,
      title: notification?.title ?? 'Pengumuman',
      body: notification?.body ?? '',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'pengumuman',
          'Pengumuman Kampus',
          channelDescription: 'Notifications for important campus updates.',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: routeFromMessage(message.data),
    );
  }

  static Future<void> handleTerminated(void Function(String route) go) async {
    final initial = await _messaging.getInitialMessage();
    if (initial != null) go(routeFromMessage(initial.data));
    if (pendingDeepLink != null) {
      go(pendingDeepLink!);
      pendingDeepLink = null;
    }
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background notification received: ${message.messageId}');
}
