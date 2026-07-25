import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/services/notification_service.dart';
import '../data/notification_catalog.dart';

/// Engine managing priority rules and scheduling for daily tips vs medication reminders
class SmartNotificationScheduler {
  static const String _prefKeyLastIndex = 'smart_notif_last_catalog_index';
  static const List<int> _tipNotificationIds = [800001, 800002, 800003];

  /// Synchronizes scheduled notifications based on active user reminders and language
  static Future<void> syncSchedule({
    required BuildContext context,
    required List activeReminders,
  }) async {
    try {
      final bool hasActiveReminders = activeReminders.any((r) {
        try {
          return r.active == true;
        } catch (_) {
          return true;
        }
      });

      // RULE 1: If user has active medication reminders, cancel tip notifications
      if (hasActiveReminders) {
        for (final id in _tipNotificationIds) {
          await NotificationService.cancelReminder(id);
        }
        debugPrint('SmartNotificationScheduler: User has active medication reminders. Tips suspended.');
        return;
      }

      // RULE 2: If NO active medication reminders, schedule 2-3 daily tips
      final sp = await SharedPreferences.getInstance();
      int currentIndex = sp.getInt(_prefKeyLastIndex) ?? 0;
      final String langCode = sp.getString('language') ?? 'fr';

      final now = DateTime.now();
      // Slots: 10:00 AM, 3:00 PM (15:00), 7:30 PM (19:30)
      final slots = [
        DateTime(now.year, now.month, now.day, 10, 0),
        DateTime(now.year, now.month, now.day, 15, 0),
        DateTime(now.year, now.month, now.day, 19, 30),
      ];

      for (int i = 0; i < slots.length; i++) {
        var scheduledTime = slots[i];
        if (scheduledTime.isBefore(now)) {
          scheduledTime = scheduledTime.add(const Duration(days: 1));
        }

        final catalogItem = NotificationCatalog.getItem(currentIndex + 1);
        final title = catalogItem.getTitle(langCode);
        final body = catalogItem.getBody(langCode);

        await NotificationService.scheduleTipNotification(
          id: _tipNotificationIds[i],
          title: title,
          body: body,
          scheduledDate: scheduledTime,
        );

        currentIndex = (currentIndex + 1) % NotificationCatalog.items.length;
      }

      await sp.setInt(_prefKeyLastIndex, currentIndex);
      debugPrint('SmartNotificationScheduler: Scheduled 3 daily tips for language "$langCode". Next index: $currentIndex');
    } catch (e) {
      debugPrint('SmartNotificationScheduler sync error: $e');
    }
  }

  /// Triggers an immediate demo of both notification types for testing
  static Future<void> triggerDevDemo({
    required BuildContext context,
    required bool isMedicationReminder,
    String? preferredLanguage,
  }) async {
    final sp = await SharedPreferences.getInstance();
    final String langCode = preferredLanguage ?? sp.getString('language') ?? 'fr';

    if (isMedicationReminder) {
      String title = '💊 Rappel Médicament — Doliprane 1000mg';
      String body = 'C\'est l\'heure de votre prise (1 gélule). N\'oubliez pas de boire un grand verre d\'eau.';

      if (langCode == 'en') {
        title = '💊 Medication Reminder — Doliprane 1000mg';
        body = 'Time for your dose (1 capsule). Don\'t forget a full glass of water.';
      } else if (langCode == 'ar') {
        title = '💊 تذكير بالدواء — دوليبران 1000 ملغ';
        body = 'حان موعد الجرعة (كبسولة واحدة). لا تنس شرب كوب ماء كبير.';
      } else if (langCode == 'tr') {
        title = '💊 İlaç Hatırlatıcı — Doliprane 1000mg';
        body = 'İlaç vaktiniz geldi (1 kapsül). Bir bardak su içmeyi unutmayın.';
      }

      await NotificationService.showInstantNotification(
        id: 999001,
        title: title,
        body: body,
      );
    } else {
      final catalogItem = NotificationCatalog.getItem(1); // Sample item
      final title = catalogItem.getTitle(langCode);
      final body = catalogItem.getBody(langCode);

      await NotificationService.showTipNotification(
        id: 999002,
        title: title,
        body: body,
      );
    }
  }
}
