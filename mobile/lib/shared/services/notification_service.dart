import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // 1. Initialize Timezones
    tz.initializeTimeZones();
    try {
      final dynamic tzResult = await FlutterTimezone.getLocalTimezone();
      String timeZoneName;
      if (tzResult is String) {
        timeZoneName = tzResult;
      } else {
        try {
          timeZoneName = tzResult.name;
        } catch (_) {
          // If all else fails, try to parse the name out of TimezoneInfo(...)
          final String str = tzResult.toString();
          if (str.contains('(') && str.contains(',')) {
            timeZoneName = str.split('(')[1].split(',')[0].trim();
          } else {
            timeZoneName = str;
          }
        }
      }
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      debugPrint('Local Timezone initialized to: $timeZoneName');
    } catch (e) {
      debugPrint('Could not get local timezone, defaulting to UTC: $e');
    }

    // 2. Setup channel details for Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // 3. Setup Darwin (iOS / macOS) details
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: false,
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
    );

    try {
      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse details) {
          debugPrint('Notification clicked: ${details.payload}');
        },
      );
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  static Future<bool> requestPermissions() async {
    try {
      final androidPlatform = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlatform != null) {
        final bool? granted = await androidPlatform.requestNotificationsPermission();
        return granted ?? false;
      }

      final iosPlatform = _notificationsPlugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (iosPlatform != null) {
        final bool? granted = await iosPlatform.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
          critical: false,
        );
        return granted ?? false;
      }

      final macosPlatform = _notificationsPlugin.resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>();
      if (macosPlatform != null) {
        final bool? granted = await macosPlatform.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
      
      return false;
    } catch (e) {
      debugPrint('Failed to request notification permission: $e');
      return false;
    }
  }

  static Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required String timeStr, // format "HH:MM" e.g., "08:30"
  }) async {
    try {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      // If scheduled date is in the past, move to next day
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'medscan_reminders_channel_v2',
        'Rappels de médicaments',
        channelDescription: 'Notifications pour la prise de médicaments',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('alarme_douce'),
        category: AndroidNotificationCategory.alarm,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        fullScreenIntent: true,
        vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000, 500, 1000]),
      );

      const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'alarme_douce.wav',
        badgeNumber: 1,
        interruptionLevel: InterruptionLevel.active,
      );

      final NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      // Schedule recurring daily notification
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // Daily match at the same time
        payload: id.toString(),
      );
    } catch (e) {
      debugPrint('Error scheduling local notification: $e');
    }
  }

  static Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'medscan_reminders_channel_v2',
        'Rappels de médicaments',
        channelDescription: 'Notifications pour la prise de médicaments',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('alarme_douce'),
        category: AndroidNotificationCategory.alarm,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        fullScreenIntent: true,
        vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000, 500, 1000]),
      );

      const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'alarme_douce.wav',
        badgeNumber: 1,
        interruptionLevel: InterruptionLevel.active,
      );

      final NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      await _notificationsPlugin.show(
        id,
        title,
        body,
        platformDetails,
        payload: id.toString(),
      );
    } catch (e) {
      debugPrint('Error showing instant notification: $e');
    }
  }

  static Future<void> cancelReminder(int id) async {
    try {
      await _notificationsPlugin.cancel(id);
    } catch (e) {
      debugPrint('Error cancelling local notification: $e');
    }
  }

  static Future<void> cancelAll() async {
    try {
      await _notificationsPlugin.cancelAll();
    } catch (e) {
      debugPrint('Error cancelling all notifications: $e');
    }
  }
}
