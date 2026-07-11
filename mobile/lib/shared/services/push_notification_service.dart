import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';

class PushNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    try {
      // 1. Request permissions (specifically for iOS)
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('Push Notification Permission Granted!');
        
        try {
          // 2. Fetch FCM Token (highly useful for console/API testing)
          final token = await _messaging.getToken();
          debugPrint('FCM DEVICE TOKEN: $token');
        } catch (tokenError) {
          debugPrint('⚠️ Impossible de générer le token FCM sur iOS : $tokenError');
          debugPrint('👉 C\'est tout à fait normal si vous utilisez un compte développeur Apple gratuit (sans capability Push Notifications ni clé APNs .p8 dans Firebase).');
        }
      } else {
        debugPrint('Push Notification Permission Denied or Not Determined');
      }

      // 3. Handle foreground notifications
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Received foreground push message: ${message.notification?.title}');
        if (message.notification != null) {
          // Show a local alarm notification instantly when push is received in foreground
          NotificationService.showInstantNotification(
            id: message.hashCode,
            title: message.notification!.title ?? '💊 MediScan',
            body: message.notification!.body ?? '',
          );
        }
      });

      // 4. Handle background/terminated message openings
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('App opened from push message: ${message.data}');
      });
      
    } catch (e) {
      debugPrint('Failed to initialize push notifications: $e');
    }
  }
}
