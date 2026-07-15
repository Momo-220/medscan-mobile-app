import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart'; // StateNotifier, StateNotifierProvider (Riverpod 3.x legacy)
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/di/providers.dart';
import '../../../data/models/reminder.dart';
import '../../auth/providers/auth_provider.dart';
import '../../home/providers/health_stats_provider.dart';
import '../../../shared/services/notification_service.dart';
import '../../../shared/utils/localization.dart';

class RemindersNotifier extends StateNotifier<AsyncValue<List<Reminder>>> {
  final Ref _ref;

  RemindersNotifier(this._ref) : super(const AsyncValue.loading()) {
    _ref.listen(firebaseAuthStateProvider, (previous, next) {
      final user = next.value;
      if (user != null) {
        _loadCacheAndFetch(user.uid);
      } else {
        state = const AsyncValue.data([]);
        NotificationService.cancelAll();
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
      } catch (_) {}
    }

    // 2. Fetch fresh reminders from API
    fetchReminders(userId);
  }

  Future<void> fetchReminders(String userId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      state = const AsyncValue.data([]);
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
          final int notificationId = r.id.hashCode;
          if (r.active) {
            final details = _getNotificationDetails(r.medicationName, r.dosage, _ref.read(languageProvider));
            NotificationService.scheduleReminder(
              id: notificationId,
              title: details['title']!,
              body: details['body']!,
              timeStr: r.time,
            );
          } else {
            NotificationService.cancelReminder(notificationId);
          }
        }
      }
    } catch (e, stack) {
      if (state.value == null || state.value!.isEmpty) {
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
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Proactively request notification permissions when adding a reminder
      await NotificationService.requestPermissions();

      final client = _ref.read(apiClientProvider);
      final response = await client.post('/reminders', data: {
        'medication_name': medicationName,
        'dosage': dosage,
        'time': time,
        'frequency': frequency,
        'active': true,
      });

      final newReminder = Reminder.fromJson(response.data);
      
      if (mounted) {
        final current = state.value ?? [];
        final updatedList = [...current, newReminder];
        state = AsyncValue.data(updatedList);
        _saveCache(user.uid, updatedList);

        // Schedule local notification alarm with caring message
        final details = _getNotificationDetails(newReminder.medicationName, newReminder.dosage, _ref.read(languageProvider));
        NotificationService.scheduleReminder(
          id: newReminder.id.hashCode,
          title: details['title']!,
          body: details['body']!,
          timeStr: newReminder.time,
        );

        // Refresh dashboard metrics
        _ref.read(healthStatsProvider.notifier).fetchStats(quietly: true);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateReminder({
    required String id,
    required String medicationName,
    required String dosage,
    required String time,
    required String frequency,
    required bool active,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      if (active) {
        // Proactively request notification permissions when activating a reminder
        await NotificationService.requestPermissions();
      }

      final client = _ref.read(apiClientProvider);
      final response = await client.put('/reminders/$id', data: {
        'medication_name': medicationName,
        'dosage': dosage,
        'time': time,
        'frequency': frequency,
        'active': active,
      });

      final updatedReminder = Reminder.fromJson(response.data);

      if (mounted) {
        final current = state.value ?? [];
        final updatedList = current.map((r) => r.id == id ? updatedReminder : r).toList();
        state = AsyncValue.data(updatedList);
        _saveCache(user.uid, updatedList);

        // Update local notification alarm
        final int notificationId = id.hashCode;
        if (active) {
          final details = _getNotificationDetails(updatedReminder.medicationName, updatedReminder.dosage, _ref.read(languageProvider));
          NotificationService.scheduleReminder(
            id: notificationId,
            title: details['title']!,
            body: details['body']!,
            timeStr: updatedReminder.time,
          );
        } else {
          NotificationService.cancelReminder(notificationId);
        }

        // Refresh dashboard metrics
        _ref.read(healthStatsProvider.notifier).fetchStats(quietly: true);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> toggleReminderActive(String id, bool active) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final current = state.value ?? [];
    final reminder = current.firstWhere((r) => r.id == id);

    await updateReminder(
      id: id,
      medicationName: reminder.medicationName,
      dosage: reminder.dosage,
      time: reminder.time,
      frequency: reminder.frequency,
      active: active,
    );
  }

  Future<void> deleteReminder(String id) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final client = _ref.read(apiClientProvider);
      await client.delete('/reminders/$id');

      if (mounted) {
        final current = state.value ?? [];
        final updatedList = current.where((r) => r.id != id).toList();
        state = AsyncValue.data(updatedList);
        _saveCache(user.uid, updatedList);

        // Cancel local notification alarm
        NotificationService.cancelReminder(id.hashCode);

        // Refresh dashboard metrics
        _ref.read(healthStatsProvider.notifier).fetchStats(quietly: true);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> markTaken(String id) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final client = _ref.read(apiClientProvider);
      await client.post('/reminders/$id/take', data: {'taken_at': DateTime.now().toUtc().toIso8601String()});

      // Refresh list to pull updated taken states and next dose calculations
      await fetchReminders(user.uid);
      
      // Refresh dashboard metrics
      _ref.read(healthStatsProvider.notifier).fetchStats(quietly: true);
    } catch (e) {
      rethrow;
    }
  }

  Map<String, String> _getNotificationDetails(String medicationName, String dosage, String lang) {
    final list = _caringMessages[lang] ?? _caringMessages['fr']!;
    final index = (medicationName.hashCode + dosage.hashCode) % list.length;
    final messageTemplate = list[index];
    
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
      "Kendinize özen gösterme vakti geldi. Küçük hatırlatmanız: {medication} ({dosage}) ❤️",
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

final remindersProvider = StateNotifierProvider<RemindersNotifier, AsyncValue<List<Reminder>>>((ref) {
  return RemindersNotifier(ref);
});
