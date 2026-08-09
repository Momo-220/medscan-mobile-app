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
          final String str = tzResult.toString();
          if (str.contains('(') && str.contains(',')) {
            timeZoneName = str.split('(')[1].split(',')[0].trim();
          } else {
            timeZoneName = str;
          }
        }
      }
      _setLocalTimezoneSafely(timeZoneName);
    } catch (e) {
      debugPrint('Could not get local timezone, attempting offset fallback: $e');
      _setLocalTimezoneSafely('UTC');
    }

    // 2. Setup channel details for Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('launcher_icon');

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
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse details) {
          debugPrint('Notification clicked: ${details.payload}');
        },
      );

      // Create high-importance Android Notification Channels with custom sounds
      final androidPlatform = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlatform != null) {
        await androidPlatform.createNotificationChannel(
          const AndroidNotificationChannel(
            'medscan_reminders_channel_v3',
            'Rappels de médicaments',
            description: 'Notifications pour la prise de médicaments',
            importance: Importance.max,
            playSound: true,
            sound: RawResourceAndroidNotificationSound('alarme_douce'),
          ),
        );
        await androidPlatform.createNotificationChannel(
          const AndroidNotificationChannel(
            'medscan_general_tips_channel_v3',
            'Conseils & Astuces Santé',
            description: 'Notifications d\'astuces santé et conseils quotidiens',
            importance: Importance.high,
            playSound: true,
            sound: RawResourceAndroidNotificationSound('notif_douce'),
          ),
        );

        // Auto-request notifications and exact alarm permissions on Android launch
        await androidPlatform.requestNotificationsPermission();
        try {
          await androidPlatform.requestExactAlarmsPermission();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  static Future<bool> requestPermissions() async {
    try {
      final androidPlatform = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlatform != null) {
        final bool? notificationsGranted = await androidPlatform.requestNotificationsPermission();
        try {
          await androidPlatform.requestExactAlarmsPermission();
        } catch (_) {}
        return notificationsGranted ?? false;
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
    required String frequency,
    List<int>? days,
  }) async {
    try {
      // 1. Cancel any existing scheduled alarms for this reminder
      await cancelReminder(id);

      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      // 2. Safe location mapping
      tz.Location location;
      try {
        location = tz.local;
      } catch (_) {
        try {
          location = tz.getLocation('UTC');
        } catch (_) {
          location = tz.timeZoneDatabase.locations.values.first;
        }
      }

      // 3. Define hour offsets according to daily frequency
      final List<int> hourOffsets = [0];
      if (frequency == 'twice') {
        hourOffsets.add(12);
      } else if (frequency == 'three-times') {
        hourOffsets.addAll([8, 16]);
      }

      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'medscan_reminders_channel_v3',
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

      final AndroidNotificationDetails androidDetailsDefaultSound = AndroidNotificationDetails(
        'medscan_reminders_channel_v3',
        'Rappels de médicaments',
        channelDescription: 'Notifications pour la prise de médicaments',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
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

      final NotificationDetails platformDetailsDefaultSound = NotificationDetails(
        android: androidDetailsDefaultSound,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      final nowLocal = DateTime.now();

      // 4. Schedule multiple alarms dynamically
      if (days == null || days.isEmpty) {
        // Daily matching configuration
        for (int i = 0; i < hourOffsets.length; i++) {
          final offset = hourOffsets[i];
          final targetHour = (hour + offset) % 24;
          final daysToAdd = (hour + offset) ~/ 24;

          var scheduledLocal = DateTime(
            nowLocal.year,
            nowLocal.month,
            nowLocal.day,
            targetHour,
            minute,
          );

          if (daysToAdd > 0) {
            scheduledLocal = scheduledLocal.add(Duration(days: daysToAdd));
          }

          if (scheduledLocal.isBefore(nowLocal)) {
            scheduledLocal = scheduledLocal.add(const Duration(days: 1));
          }

          final scheduledDate = tz.TZDateTime.from(scheduledLocal, location);
          final int alarmId = id + (i * 100000);
          try {
            await _notificationsPlugin.zonedSchedule(
              id: alarmId,
              title: title,
              body: body,
              scheduledDate: scheduledDate,
              notificationDetails: platformDetails,
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
              matchDateTimeComponents: DateTimeComponents.time,
              payload: id.toString(),
            );
          } catch (e) {
            debugPrint('exactAllowWhileIdle failed, falling back: $e');
            final useDefaultSound = e.toString().contains('invalid_sound');
            final detailsToUse = useDefaultSound ? platformDetailsDefaultSound : platformDetails;
            try {
              await _notificationsPlugin.zonedSchedule(
                id: alarmId,
                title: title,
                body: body,
                scheduledDate: scheduledDate,
                notificationDetails: detailsToUse,
                androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
                matchDateTimeComponents: DateTimeComponents.time,
                payload: id.toString(),
              );
            } catch (_) {
              await _notificationsPlugin.zonedSchedule(
                id: alarmId,
                title: title,
                body: body,
                scheduledDate: scheduledDate,
                notificationDetails: detailsToUse,
                androidScheduleMode: AndroidScheduleMode.inexact,
                matchDateTimeComponents: DateTimeComponents.time,
                payload: id.toString(),
              );
            }
          }
        }
      } else {
        // Weekdays matching configuration (e.g. Mon, Thu)
        // ISO weekdays: 1 (Mon) - 7 (Sun)
        // Our indices: 0 (Mon) - 6 (Sun)
        for (final weekdayIndex in days) {
          final targetIsoWeekday = weekdayIndex + 1;

          for (int i = 0; i < hourOffsets.length; i++) {
            final offset = hourOffsets[i];
            final targetHour = (hour + offset) % 24;
            final daysToAddOffset = (hour + offset) ~/ 24;

            var scheduledLocal = DateTime(
              nowLocal.year,
              nowLocal.month,
              nowLocal.day,
              targetHour,
              minute,
            );

            if (daysToAddOffset > 0) {
              scheduledLocal = scheduledLocal.add(Duration(days: daysToAddOffset));
            }

            while (scheduledLocal.weekday != targetIsoWeekday || scheduledLocal.isBefore(nowLocal)) {
              scheduledLocal = scheduledLocal.add(const Duration(days: 1));
            }

            final scheduledDate = tz.TZDateTime.from(scheduledLocal, location);
            final int alarmId = id + ((weekdayIndex + 1) * 10000) + (i * 100000);
            try {
              await _notificationsPlugin.zonedSchedule(
                id: alarmId,
                title: title,
                body: body,
                scheduledDate: scheduledDate,
                notificationDetails: platformDetails,
                androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
                matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
                payload: id.toString(),
              );
            } catch (e) {
              debugPrint('exactAllowWhileIdle failed, falling back: $e');
              final useDefaultSound = e.toString().contains('invalid_sound');
              final detailsToUse = useDefaultSound ? platformDetailsDefaultSound : platformDetails;
              try {
                await _notificationsPlugin.zonedSchedule(
                  id: alarmId,
                  title: title,
                  body: body,
                  scheduledDate: scheduledDate,
                  notificationDetails: detailsToUse,
                  androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
                  matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
                  payload: id.toString(),
                );
              } catch (_) {
                await _notificationsPlugin.zonedSchedule(
                  id: alarmId,
                  title: title,
                  body: body,
                  scheduledDate: scheduledDate,
                  notificationDetails: detailsToUse,
                  androidScheduleMode: AndroidScheduleMode.inexact,
                  matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
                  payload: id.toString(),
                );
              }
            }
          }
        }
      }
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
        'medscan_reminders_channel_v3',
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

      final AndroidNotificationDetails androidDetailsDefaultSound = AndroidNotificationDetails(
        'medscan_reminders_channel_v3',
        'Rappels de médicaments',
        channelDescription: 'Notifications pour la prise de médicaments',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
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

      final NotificationDetails platformDetailsDefaultSound = NotificationDetails(
        android: androidDetailsDefaultSound,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      try {
        await _notificationsPlugin.show(
          id: id,
          title: title,
          body: body,
          notificationDetails: platformDetails,
          payload: id.toString(),
        );
      } catch (e) {
        if (e.toString().contains('invalid_sound')) {
          await _notificationsPlugin.show(
            id: id,
            title: title,
            body: body,
            notificationDetails: platformDetailsDefaultSound,
            payload: id.toString(),
          );
        } else {
          rethrow;
        }
      }
    } catch (e) {
      debugPrint('Error showing instant notification: $e');
    }
  }

  /// Displays an instant tip notification using the general_tips channel and notif_douce sound
  static Future<void> showTipNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'medscan_general_tips_channel_v3',
        'Conseils & Astuces Santé',
        channelDescription: 'Notifications d\'astuces santé et conseils quotidiens',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('notif_douce'),
        category: AndroidNotificationCategory.recommendation,
      );

      final AndroidNotificationDetails androidDetailsDefaultSound = AndroidNotificationDetails(
        'medscan_general_tips_channel_v3',
        'Conseils & Astuces Santé',
        channelDescription: 'Notifications d\'astuces santé et conseils quotidiens',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        playSound: true,
        category: AndroidNotificationCategory.recommendation,
      );

      const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'notif_douce.wav',
        badgeNumber: 1,
        interruptionLevel: InterruptionLevel.active,
      );

      final NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      final NotificationDetails platformDetailsDefaultSound = NotificationDetails(
        android: androidDetailsDefaultSound,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      try {
        await _notificationsPlugin.show(
          id: id,
          title: title,
          body: body,
          notificationDetails: platformDetails,
          payload: 'tip_$id',
        );
      } catch (e) {
        if (e.toString().contains('invalid_sound')) {
          await _notificationsPlugin.show(
            id: id,
            title: title,
            body: body,
            notificationDetails: platformDetailsDefaultSound,
            payload: 'tip_$id',
          );
        } else {
          rethrow;
        }
      }
    } catch (e) {
      debugPrint('Error showing tip notification: $e');
    }
  }

  /// Schedules a recurring tip notification on the general_tips channel
  static Future<void> scheduleTipNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    try {
      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'medscan_general_tips_channel_v3',
        'Conseils & Astuces Santé',
        channelDescription: 'Notifications d\'astuces santé et conseils quotidiens',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('notif_douce'),
      );

      final AndroidNotificationDetails androidDetailsDefaultSound = AndroidNotificationDetails(
        'medscan_general_tips_channel_v3',
        'Conseils & Astuces Santé',
        channelDescription: 'Notifications d\'astuces santé et conseils quotidiens',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        playSound: true,
      );

      const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'notif_douce.wav',
        badgeNumber: 1,
        interruptionLevel: InterruptionLevel.active,
      );

      final NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      final NotificationDetails platformDetailsDefaultSound = NotificationDetails(
        android: androidDetailsDefaultSound,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      tz.Location location;
      try {
        location = tz.local;
      } catch (_) {
        location = tz.getLocation('UTC');
      }

      final tzScheduled = tz.TZDateTime.from(scheduledDate, location);

      try {
        await _notificationsPlugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: tzScheduled,
          notificationDetails: platformDetails,
          androidScheduleMode: AndroidScheduleMode.inexact,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: 'tip_$id',
        );
      } catch (e) {
        if (e.toString().contains('invalid_sound')) {
          await _notificationsPlugin.zonedSchedule(
            id: id,
            title: title,
            body: body,
            scheduledDate: tzScheduled,
            notificationDetails: platformDetailsDefaultSound,
            androidScheduleMode: AndroidScheduleMode.inexact,
            matchDateTimeComponents: DateTimeComponents.time,
            payload: 'tip_$id',
          );
        } else {
          rethrow;
        }
      }
    } catch (e) {
      debugPrint('Error scheduling tip notification: $e');
    }
  }

  static Future<void> cancelReminder(int id) async {
    try {
      await _notificationsPlugin.cancel(id: id);
      await _notificationsPlugin.cancel(id: id + 100000);
      await _notificationsPlugin.cancel(id: id + 200000);
      for (int i = 0; i < 7; i++) {
        final int baseDayOffset = id + ((i + 1) * 10000);
        await _notificationsPlugin.cancel(id: baseDayOffset);
        await _notificationsPlugin.cancel(id: baseDayOffset + 100000);
        await _notificationsPlugin.cancel(id: baseDayOffset + 200000);
      }
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

  static void _setLocalTimezoneSafely(String name) {
    try {
      tz.setLocalLocation(tz.getLocation(name));
      debugPrint('Local Timezone initialized directly to: $name');
    } catch (_) {
      final localOffsetSeconds = DateTime.now().timeZoneOffset.inSeconds;
      for (final loc in tz.timeZoneDatabase.locations.values) {
        if (loc.currentTimeZone.offset == localOffsetSeconds || loc.currentTimeZone.offset == localOffsetSeconds * 1000) {
          tz.setLocalLocation(loc);
          debugPrint('Local Timezone initialized by offset match to: ${loc.name}');
          return;
        }
      }
      // Ultimate fallback: UTC or first database location
      try {
        tz.setLocalLocation(tz.getLocation('UTC'));
      } catch (_) {
        if (tz.timeZoneDatabase.locations.isNotEmpty) {
          tz.setLocalLocation(tz.timeZoneDatabase.locations.values.first);
        }
      }
    }
  }
}
