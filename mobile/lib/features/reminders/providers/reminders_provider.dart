import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart'; // StateNotifier, StateNotifierProvider (Riverpod 3.x legacy)
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/di/providers.dart';
import '../../../data/models/reminder.dart';
import '../../auth/providers/auth_provider.dart';
import '../../home/providers/health_stats_provider.dart';
import '../../../shared/services/notification_service.dart';
import '../../../shared/utils/localization.dart';
import '../services/smart_notification_scheduler.dart';
import '../../../shared/services/widget_service.dart';

class RemindersNotifier extends StateNotifier<AsyncValue<List<Reminder>>> {
  final Ref _ref;

  RemindersNotifier(this._ref) : super(const AsyncValue.loading()) {
    _ref.listen(firebaseAuthStateProvider, (previous, next) {
      final user = next.value;
      if (user != null) {
        final userId = user.uid;
        // Load cached reminders so we sync name + reminders together
        List<Reminder>? cachedList;
        try {
          final prefs = _ref.read(sharedPrefsServiceProvider);
          final cacheJson = prefs.getRemindersCache(userId);
          if (cacheJson != null) {
            final List<dynamic> decoded = json.decode(cacheJson);
            cachedList = decoded.map((e) => Reminder.fromJson(e)).toList();
          }
        } catch (_) {}
        // Sync widget with BOTH user name and reminders in one atomic call
        WidgetService.syncWidget(reminders: cachedList, langCode: _ref.read(languageProvider));
        _loadCacheAndFetch(userId);
      } else {
        NotificationService.cancelAll();
        WidgetService.clearWidget();
        state = const AsyncValue.data([]);
      }
    }, fireImmediately: true);
  }

  void _loadCacheAndFetch(String userId) {
    // 1. Load cache from SharedPreferences (offline support)
    final prefs = _ref.read(sharedPrefsServiceProvider);
    final cacheJson = prefs.getRemindersCache(userId);
    if (cacheJson != null) {
      try {
        final List<dynamic> list = json.decode(cacheJson);
        final cachedReminders = list.map((e) => Reminder.fromJson(e)).toList();
        state = AsyncValue.data(cachedReminders);

        // Synchronize local notifications scheduled with cached active reminders
        for (var r in cachedReminders) {
          final int notificationId = _getStableNotificationId(r.id);
          if (r.active) {
            final details = _getNotificationDetails(r.medicationName, r.dosage, _ref.read(languageProvider));
            NotificationService.scheduleReminder(
              id: notificationId,
              title: details['title']!,
              body: details['body']!,
              timeStr: r.time,
              frequency: r.frequency,
              days: r.days,
            );
          }
        }
        SmartNotificationScheduler.syncSchedule(activeReminders: cachedReminders);
        WidgetService.syncWidget(reminders: cachedReminders, langCode: _ref.read(languageProvider));
      } catch (_) {}
    }

    // 2. Fetch fresh reminders from API
    fetchReminders(userId);
  }

  Future<void> fetchReminders(String userId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      if (state.value == null) {
        state = const AsyncValue.data([]);
      }
      return;
    }

    try {
      final client = _ref.read(apiClientProvider);
      final response = await client.get('/reminders', queryParameters: {'active_only': false});
      
      final List<dynamic> listJson = response.data['reminders'] ?? [];
      final list = listJson.map((e) => Reminder.fromJson(e)).toList();

      if (mounted) {
        state = AsyncValue.data(list);
        _saveCache(userId, list);

        // Synchronize local notifications scheduled with backend active reminders
        for (var r in list) {
          final int notificationId = _getStableNotificationId(r.id);
          if (r.active) {
            final details = _getNotificationDetails(r.medicationName, r.dosage, _ref.read(languageProvider));
            NotificationService.scheduleReminder(
              id: notificationId,
              title: details['title']!,
              body: details['body']!,
              timeStr: r.time,
              frequency: r.frequency,
              days: r.days,
            );
          } else {
            NotificationService.cancelReminder(notificationId);
          }
        }

        // Sync health tips when no active medication reminders
        SmartNotificationScheduler.syncSchedule(activeReminders: list);
        WidgetService.syncWidget(reminders: list, langCode: _ref.read(languageProvider));
      }
    } catch (e, stack) {
      debugPrint('Error fetching reminders: $e');
      if (state.value == null) {
        state = AsyncValue.error(e, stack);
      }
    }
  }

  void _saveCache(String userId, List<Reminder> reminders) {
    try {
      final prefs = _ref.read(sharedPrefsServiceProvider);
      final listJson = reminders.map((e) => e.toJson()).toList();
      prefs.setRemindersCache(userId, json.encode(listJson));
    } catch (_) {}
  }

  Future<void> addReminder({
    required String medicationName,
    required String dosage,
    required String time,
    required String frequency,
    List<int>? days,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? 'local_user';

    // Proactively request notification permissions when adding a reminder
    await NotificationService.requestPermissions();

    final String localId = 'reminder_${DateTime.now().millisecondsSinceEpoch}';
    final parts = time.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final now = DateTime.now();
    var initialNextDose = DateTime(now.year, now.month, now.day, hour, minute);
    if (days != null && days.isNotEmpty) {
      int loops = 0;
      while (!days.contains(initialNextDose.weekday) && loops < 7) {
        initialNextDose = initialNextDose.add(const Duration(days: 1));
        loops++;
      }
    }

    final localReminder = Reminder(
      id: localId,
      medicationName: medicationName,
      dosage: dosage,
      time: time,
      frequency: frequency,
      days: days,
      active: true,
      nextDose: initialNextDose,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // 1. Instantly update local state, save cache, & schedule local notification alarm!
    final current = state.value ?? [];
    final updatedList = [...current, localReminder];
    state = AsyncValue.data(updatedList);
    _saveCache(userId, updatedList);

    final details = _getNotificationDetails(medicationName, dosage, _ref.read(languageProvider));
    await NotificationService.scheduleReminder(
      id: _getStableNotificationId(localReminder.id),
      title: details['title']!,
      body: details['body']!,
      timeStr: localReminder.time,
      frequency: localReminder.frequency,
      days: localReminder.days,
    );

    _ref.read(healthStatsProvider.notifier).fetchStats(quietly: true);
    SmartNotificationScheduler.syncSchedule(activeReminders: updatedList);
    WidgetService.syncWidget(reminders: updatedList, langCode: _ref.read(languageProvider));

    // 2. Try syncing with backend API in background if authenticated
    if (user != null && !user.isAnonymous) {
      try {
        final client = _ref.read(apiClientProvider);
        final response = await client.post('/reminders', data: {
          'medication_name': medicationName,
          'dosage': dosage,
          'time': time,
          'frequency': frequency,
          'days': days,
          'active': true,
        });

        final serverReminder = Reminder.fromJson(response.data);
        if (mounted) {
          final listWithoutTemp = (state.value ?? []).where((r) => r.id != localId).toList();
          final finalList = [...listWithoutTemp, serverReminder];
          state = AsyncValue.data(finalList);
          _saveCache(userId, finalList);
          WidgetService.syncWidget(reminders: finalList, langCode: _ref.read(languageProvider));

          NotificationService.cancelReminder(_getStableNotificationId(localId));
          NotificationService.scheduleReminder(
            id: _getStableNotificationId(serverReminder.id),
            title: details['title']!,
            body: details['body']!,
            timeStr: serverReminder.time,
            frequency: serverReminder.frequency,
            days: serverReminder.days,
          );
        }
      } catch (e) {
        debugPrint('Backend sync for reminder failed, retained local offline reminder: $e');
      }
    }
  }

  Future<void> updateReminder({
    required String id,
    required String medicationName,
    required String dosage,
    required String time,
    required String frequency,
    required bool active,
    List<int>? days,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? 'local_user';

    if (active) {
      await NotificationService.requestPermissions();
    }

    final current = state.value ?? [];
    final existingReminder = current.firstWhere(
      (r) => r.id == id,
      orElse: () {
        final parts = time.split(':');
        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts[1]) ?? 0;
        final now = DateTime.now();
        var initialNextDose = DateTime(now.year, now.month, now.day, hour, minute);
        if (days != null && days.isNotEmpty) {
          int loops = 0;
          while (!days.contains(initialNextDose.weekday) && loops < 7) {
            initialNextDose = initialNextDose.add(const Duration(days: 1));
            loops++;
          }
        }
        return Reminder(
          id: id,
          medicationName: medicationName,
          dosage: dosage,
          time: time,
          frequency: frequency,
          days: days,
          active: active,
          nextDose: initialNextDose,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      },
    );

    final updatedLocalReminder = existingReminder.copyWith(
      medicationName: medicationName,
      dosage: dosage,
      time: time,
      frequency: frequency,
      active: active,
      days: days,
      updatedAt: DateTime.now(),
    );

    final updatedList = current.map((r) => r.id == id ? updatedLocalReminder : r).toList();
    if (!current.any((r) => r.id == id)) {
      updatedList.add(updatedLocalReminder);
    }
    state = AsyncValue.data(updatedList);
    _saveCache(userId, updatedList);

    final int notificationId = _getStableNotificationId(id);
    if (active) {
      final details = _getNotificationDetails(medicationName, dosage, _ref.read(languageProvider));
      NotificationService.scheduleReminder(
        id: notificationId,
        title: details['title']!,
        body: details['body']!,
        timeStr: time,
        frequency: frequency,
        days: days,
      );
    } else {
      NotificationService.cancelReminder(notificationId);
    }

    _ref.read(healthStatsProvider.notifier).fetchStats(quietly: true);
    SmartNotificationScheduler.syncSchedule(activeReminders: updatedList);
    WidgetService.syncWidget(reminders: updatedList, langCode: _ref.read(languageProvider));

    if (user != null && !user.isAnonymous && !id.startsWith('reminder_')) {
      try {
        final client = _ref.read(apiClientProvider);
        final response = await client.put('/reminders/$id', data: {
          'medication_name': medicationName,
          'dosage': dosage,
          'time': time,
          'frequency': frequency,
          'days': days,
          'active': active,
        });

        final serverReminder = Reminder.fromJson(response.data);
        if (mounted) {
          final finalList = (state.value ?? []).map((r) => r.id == id ? serverReminder : r).toList();
          state = AsyncValue.data(finalList);
          _saveCache(userId, finalList);
          WidgetService.syncWidget(reminders: finalList, langCode: _ref.read(languageProvider));
        }
      } catch (e) {
        debugPrint('Backend sync for update reminder failed: $e');
      }
    }
  }

  Future<void> toggleReminderActive(String id, bool active) async {
    final current = state.value ?? [];
    final reminder = current.firstWhere((r) => r.id == id, orElse: () => current.first);

    await updateReminder(
      id: id,
      medicationName: reminder.medicationName,
      dosage: reminder.dosage,
      time: reminder.time,
      frequency: reminder.frequency,
      active: active,
      days: reminder.days,
    );
  }

  Future<void> deleteReminder(String id) async {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? 'local_user';

    final current = state.value ?? [];
    final updatedList = current.where((r) => r.id != id).toList();
    state = AsyncValue.data(updatedList);
    _saveCache(userId, updatedList);

    NotificationService.cancelReminder(_getStableNotificationId(id));

    _ref.read(healthStatsProvider.notifier).fetchStats(quietly: true);
    SmartNotificationScheduler.syncSchedule(activeReminders: updatedList);
    WidgetService.syncWidget(reminders: updatedList, langCode: _ref.read(languageProvider));

    if (user != null && !user.isAnonymous && !id.startsWith('reminder_')) {
      try {
        final client = _ref.read(apiClientProvider);
        await client.delete('/reminders/$id');
      } catch (e) {
        debugPrint('Backend sync for delete reminder failed: $e');
      }
    }
  }

  Future<void> markTaken(String id) async {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? 'local_user';

    final current = state.value ?? [];
    final updatedList = current.map((r) {
      if (r.id == id) {
        final newNextDose = r.calculateNextDoseTime(r.nextDose);
        final isAllDone = newNextDose.day != r.nextDose.day;
        return r.copyWith(
          nextDose: newNextDose,
          taken: isAllDone ? true : false,
        );
      }
      return r;
    }).toList();
    state = AsyncValue.data(updatedList);
    _saveCache(userId, updatedList);

    _ref.read(healthStatsProvider.notifier).fetchStats(quietly: true);
    WidgetService.syncWidget(reminders: updatedList, langCode: _ref.read(languageProvider));

    if (user != null && !user.isAnonymous && !id.startsWith('reminder_')) {
      try {
        final client = _ref.read(apiClientProvider);
        await client.post('/reminders/$id/take', data: {'taken_at': DateTime.now().toUtc().toIso8601String()});
      } catch (e) {
        debugPrint('Backend sync for markTaken failed: $e');
      }
    }
  }

  Map<String, String> _getNotificationDetails(String medicationName, String dosage, String lang) {
    final user = FirebaseAuth.instance.currentUser;
    final prefs = _ref.read(sharedPrefsServiceProvider);
    final rawName = user?.displayName ?? prefs.getLocalName();
    final name = (rawName != null && rawName.trim().isNotEmpty) ? rawName.trim() : null;

    final list = _caringMessages[lang] ?? _caringMessages['fr']!;
    final index = (medicationName.hashCode + dosage.hashCode) % list.length;
    var messageTemplate = list[index];

    // Personalize with name if available
    if (name != null) {
      if (lang == 'fr') {
        messageTemplate = messageTemplate.replaceAll("Coucou !", "Coucou $name !");
      } else if (lang == 'en') {
        messageTemplate = messageTemplate.replaceAll("Hello!", "Hello $name!");
      } else if (lang == 'ar') {
        messageTemplate = messageTemplate.replaceAll("مرحباً!", "مرحباً $name!");
      } else if (lang == 'tr') {
        messageTemplate = messageTemplate.replaceAll("Merhaba!", "Merhaba $name!");
      }
    }
    
    String title;
    if (lang == 'fr') {
      title = '💊 Rappel Doux : $medicationName';
    } else if (lang == 'tr') {
      title = '💊 Tatlı Hatırlatma: $medicationName';
    } else if (lang == 'ar') {
      title = '💊 تذكير لطيف: $medicationName';
    } else {
      title = '💊 Gentle Reminder: $medicationName';
    }
    
    final body = messageTemplate
        .replaceAll('{medication}', medicationName)
        .replaceAll('{dosage}', dosage);
        
    return {'title': title, 'body': body};
  }

  static const Map<String, List<String>> _caringMessages = {
    'fr': [
      "Coucou ! C'est l'heure de prendre soin de vous. Votre petit rappel pour : {medication} ({dosage}) ❤️",
      "Prenez un petit instant pour vous. C'est le moment de prendre votre {medication} ({dosage}). Prenez bien soin de vous ! ✨",
      "Une petite dose de bienveillance : n'oubliez pas votre {medication} ({dosage}) pour rester en pleine forme ! 🌟",
      "Votre santé est précieuse. C'est l'heure de votre {medication} ({dosage}). Passez une excellente journée ! 🌸",
      "Petit rappel doux pour votre santé : c'est le moment de prendre {medication} ({dosage}). Courage ! 💪",
    ],
    'en': [
      "Hello! It's time to take care of yourself. Your gentle reminder for: {medication} ({dosage}) ❤️",
      "Take a quick moment for yourself. It is time for your {medication} ({dosage}). Take good care! ✨",
      "A little dose of kindness: don't forget your {medication} ({dosage}) to keep feeling your best! 🌟",
      "Your health is precious. It's time for your {medication} ({dosage}). Have a beautiful day! 🌸",
      "A sweet reminder for your well-being: it's time to take {medication} ({dosage}). Stay strong! 💪",
    ],
    'tr': [
      "Merhaba! Kendinize özen gösterme vakti geldi. Küçük hatırlatmanız: {medication} ({dosage}) ❤️",
      "Kendiniz için kısa bir ara verin. Şimdi {medication} ({dosage}) zamanı. Sağlığınıza dikkat edin! ✨",
      "Küçük bir sevgi dozu: En iyi halinizde kalmak için {medication} ({dosage}) almayı unutmayın! 🌟",
      "Sağlığınız çok değerli. {medication} ({dosage}) saati geldi. Harika bir gün dileriz! 🌸",
      "İyi hissetmeniz için tatlı bir hatırlatma: {medication} ({dosage}) zamanı. Sağlıkla kalın! 💪",
    ],
    'ar': [
      "مرحباً! حان الوقت للاعتناء بنفسك. تذكير لطيف لـ: {medication} ({dosage}) ❤️",
      "خذ لحظة صغيرة لنفسك. حان وقت تناول {medication} ({dosage}). اعتنِ بصحتك جيداً! ✨",
      "جرعة صغيرة من اللطف: لا تنسَ تناول {medication} ({dosage}) لتبقى في أفضل حال! 🌟",
      "صحتك ثمينة جداً. حان وقت {medication} ({dosage}). نتمنى لك يوماً جميلاً! 🌸",
      "تذكير دافئ لسلامتك: حان وقت تناول {medication} ({dosage}). دمتم بصحة وعافية! 💪",
    ],
  };
}

int _getStableNotificationId(String reminderId) {
  int hash = 0x811c9dc5;
  for (int i = 0; i < reminderId.length; i++) {
    hash ^= reminderId.codeUnitAt(i);
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return (hash & 0x7FFFFFFF) % 500000;
}

final remindersProvider = StateNotifierProvider<RemindersNotifier, AsyncValue<List<Reminder>>>((ref) {
  return RemindersNotifier(ref);
});
