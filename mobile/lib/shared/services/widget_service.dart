import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart';
import '../../data/models/reminder.dart';
import '../../features/reminders/data/notification_catalog.dart';

class WidgetService {
  static const String appGroupId = 'group.com.seinimomo.medscanapp';
  static const String iOSWidgetName = 'MedScanWidget';
  static const String androidWidgetName = 'MedScanWidgetProvider';
  static final Lock _lock = Lock();

  /// Initialize HomeWidget AppGroup for iOS
  static Future<void> init() async {
    try {
      await HomeWidget.setAppGroupId(appGroupId);
    } catch (e) {
      debugPrint('WidgetService init error: $e');
    }
  }

  static String extractAvatarId(String? photoURL) {
    if (photoURL == null || photoURL.isEmpty) return 'Avatar1';
    final match = RegExp(r'avatar(\d+)').firstMatch(photoURL.toLowerCase());
    if (match != null) {
      return 'Avatar${match.group(1)}';
    }
    return 'Avatar1';
  }

  /// Syncs current data to Home Widget (both iOS & Android)
  static Future<void> syncWidget({
    List<Reminder>? reminders,
    String? userName,
    String? avatarId,
    String? tipTitle,
    String? tipBody,
    String langCode = 'fr',
  }) async {
    await _lock.synchronized(() async {
      try {
        await init();

        // 1. Find next upcoming active reminder (if reminders list is provided)
        String? reminderName;
        String? reminderTime;
        String? reminderDosage;
        String? reminderId;

        if (reminders != null) {
          reminderName = 'Aucun rappel';
          reminderTime = '--:--';
          reminderDosage = '';
          reminderId = '';

          int totalDoses = 1;
          int takenDoses = 0;
          double progress = 0.0;
          bool allDone = false;

          if (reminders.isNotEmpty) {
            final now = DateTime.now();
            
            // Calculate progress for today
            final todayReminders = reminders.where((r) => 
                r.active && (r.days == null || r.days!.contains(now.weekday))
            ).toList();
            
            if (todayReminders.isNotEmpty) {
              totalDoses = todayReminders.map((r) => r.totalDosesToday).fold(0, (a, b) => a + b);
              takenDoses = todayReminders.map((r) => r.dosesTakenToday).fold(0, (a, b) => a + b);
              progress = totalDoses > 0 ? takenDoses / totalDoses : 0.0;
              allDone = progress >= 1.0;
            } else {
              totalDoses = 1;
              takenDoses = 1;
              allDone = true;
              progress = 1.0;
            }

            final active = todayReminders.where((r) => r.dosesTakenToday < r.totalDosesToday).toList();
            
            if (active.isNotEmpty) {
              // Sort to find the CLOSEST upcoming reminder based on nextDose DateTime
              active.sort((a, b) => a.nextDose.compareTo(b.nextDose));
              
              final next = active.first;
              reminderName = next.medicationName;
              
              // Format next dose time dynamically
              final hour = next.nextDose.hour.toString().padLeft(2, '0');
              final minute = next.nextDose.minute.toString().padLeft(2, '0');
              reminderTime = '$hour:$minute';
              
              reminderDosage = next.dosage.isNotEmpty ? next.dosage : '1 dose';
              reminderId = next.id;
              
              await HomeWidget.saveWidgetData<int>('next_dose_timestamp', next.nextDose.millisecondsSinceEpoch);
              await HomeWidget.saveWidgetData<bool>('is_pending', next.status == ReminderStatus.pending);
            } else if (allDone) {
              reminderName = 'Tout est pris ! 🎉';
              reminderTime = '';
              reminderDosage = 'Excellente journée';
            }
            
            final newHistory = await _updateWeeklyHistory(allDone, reminders);
            await HomeWidget.saveWidgetData<String>('week_history', newHistory);
            
            final streak = _calculateStreak(newHistory, now.weekday, reminders);
            await HomeWidget.saveWidgetData<int>('streak', streak);
          } else {
            totalDoses = 1;
            takenDoses = 1;
            allDone = true;
            progress = 1.0;
            final newHistory = await _updateWeeklyHistory(true, reminders);
            await HomeWidget.saveWidgetData<String>('week_history', newHistory);
            await HomeWidget.saveWidgetData<int>('streak', 0);
          }

          // Save progress data to HomeWidget
          await HomeWidget.saveWidgetData<double>('progress', progress);
          await HomeWidget.saveWidgetData<bool>('all_done', allDone);
          await HomeWidget.saveWidgetData<int>('total_doses', totalDoses);
          await HomeWidget.saveWidgetData<int>('taken_doses', takenDoses);
          await HomeWidget.saveWidgetData<bool>('has_reminders', reminders.isNotEmpty);
        }
        if (tipTitle == null || tipBody == null) {
          final catalogItem = NotificationCatalog.getItem(1);
          tipTitle = catalogItem.getTitle(langCode);
          tipBody = catalogItem.getBody(langCode);
        }

        // 3. Resolve user name + avatar
        String resolvedName = userName?.trim() ?? '';
        String resolvedAvatar = avatarId?.trim() ?? '';

        if (resolvedName.isEmpty || resolvedAvatar.isEmpty) {
          try {
            final user = FirebaseAuth.instance.currentUser;
            if (resolvedName.isEmpty) {
              resolvedName = user?.displayName?.trim() ?? '';
            }
            if (resolvedAvatar.isEmpty && user?.photoURL != null) {
              resolvedAvatar = extractAvatarId(user!.photoURL);
            }
          } catch (_) {}
        }

        if (resolvedName.isEmpty) {
          try {
            final prefs = await SharedPreferences.getInstance();
            resolvedName = prefs.getString('mediscan_user_name')?.trim() ??
                prefs.getString('user_name')?.trim() ??
                '';
          } catch (_) {}
        }

        if (resolvedAvatar.isEmpty) {
          resolvedAvatar = 'Avatar1';
        }

        debugPrint(
            'WidgetService: Syncing widget data: user_name="$resolvedName", avatar_id="$resolvedAvatar", reminder_name="$reminderName", reminder_time="$reminderTime", reminder_dosage="$reminderDosage", lang_code="$langCode"');

        // 4. Save all data to shared storage for native widgets
        if (reminders != null) {
          await HomeWidget.saveWidgetData<String>('reminder_name', reminderName);
          await HomeWidget.saveWidgetData<String>('reminder_time', reminderTime);
          await HomeWidget.saveWidgetData<String>('reminder_dosage', reminderDosage);
          await HomeWidget.saveWidgetData<String>('reminder_id', reminderId);
        } else {
          // If reminders list is null, provide default values so the widget doesn't crash
          await HomeWidget.saveWidgetData<double>('progress', 0.0);
          await HomeWidget.saveWidgetData<bool>('all_done', false);
          await HomeWidget.saveWidgetData<int>('streak', 0);
          await HomeWidget.saveWidgetData<String>('week_history', '0000000');
          await HomeWidget.saveWidgetData<bool>('has_reminders', false);
        }
        await HomeWidget.saveWidgetData<String>('tip_title', tipTitle);
        await HomeWidget.saveWidgetData<String>('tip_body', tipBody);
        await HomeWidget.saveWidgetData<String>('user_name', resolvedName);
        await HomeWidget.saveWidgetData<String>('avatar_id', resolvedAvatar);
        await HomeWidget.saveWidgetData<String>('lang_code', langCode);

        // 5. Request widget refresh
        await HomeWidget.updateWidget(
          name: iOSWidgetName,
          iOSName: iOSWidgetName,
          androidName: androidWidgetName,
        );

        debugPrint('WidgetService: Home Widget updated successfully.');
      } catch (e) {
        debugPrint('WidgetService error updating widget: $e');
      }
    });
  }

  /// Check if user marked medication as taken from the widget
  /// Returns the reminder_id that was marked, or null
  static Future<String?> checkMedicationTaken() async {
    try {
      await init();
      final taken = await HomeWidget.getWidgetData<bool>('medication_taken');
      if (taken == true) {
        final takenId = await HomeWidget.getWidgetData<String>('medication_taken_id');
        // Clear the flag so we don't process it again
        await HomeWidget.saveWidgetData<bool>('medication_taken', false);
        await HomeWidget.saveWidgetData<String>('medication_taken_id', '');
        await HomeWidget.updateWidget(
          name: iOSWidgetName,
          iOSName: iOSWidgetName,
          androidName: androidWidgetName,
        );
        debugPrint('WidgetService: Medication taken from widget: id=$takenId');
        return takenId;
      }
    } catch (e) {
      debugPrint('WidgetService: Error checking medication taken: $e');
    }
    return null;
  }

  /// Clears user-specific data from the widget (used on logout)
  static Future<void> clearWidget() async {
    try {
      await init();
      await HomeWidget.saveWidgetData<String>('user_name', '');
      await HomeWidget.saveWidgetData<String>('avatar_id', 'Avatar1');
      await HomeWidget.saveWidgetData<String>('reminder_name', 'Aucun rappel');
      await HomeWidget.saveWidgetData<String>('reminder_time', '--:--');
      await HomeWidget.saveWidgetData<String>('reminder_dosage', '');
      await HomeWidget.saveWidgetData<String>('reminder_id', '');
      
      await HomeWidget.updateWidget(
        name: iOSWidgetName,
        iOSName: iOSWidgetName,
        androidName: androidWidgetName,
      );
      debugPrint('WidgetService: Widget data cleared successfully on logout.');
    } catch (e) {
      debugPrint('WidgetService error clearing widget: $e');
    }
  }

  static Future<String> _updateWeeklyHistory(bool todayCompleted, List<Reminder> reminders) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    
    // Find Monday of this week (weekday is 1 for Mon, 7 for Sun)
    final monday = todayDate.subtract(Duration(days: now.weekday - 1));
    final weekKey = "${monday.year}-${monday.month}-${monday.day}";
    
    final savedWeekKey = prefs.getString('week_history_key');
    List<String> takenDays = List.generate(7, (i) => "0");
    
    if (savedWeekKey == weekKey) {
      final savedHistory = prefs.getString('week_history_data');
      if (savedHistory != null && savedHistory.length == 7) {
        takenDays = savedHistory.split('');
      }
    } else {
      // New week: start fresh, save new week key
      await prefs.setString('week_history_key', weekKey);
      await prefs.setString('week_history_data', '0000000');
    }
    
    // Find earliest creation date of active reminders
    DateTime? earliestCreated;
    if (reminders.isNotEmpty) {
      for (var r in reminders) {
        if (earliestCreated == null || r.createdAt.isBefore(earliestCreated)) {
          earliestCreated = r.createdAt;
        }
      }
    }
    
    // Process each day of the current week
    for (int i = 0; i < 7; i++) {
      final dayDate = monday.add(Duration(days: i));
      
      if (earliestCreated != null) {
        final earliestDateOnly = DateTime(earliestCreated.year, earliestCreated.month, earliestCreated.day);
        if (dayDate.isBefore(earliestDateOnly)) {
          takenDays[i] = "0"; // Day is before medication was created -> not green / inactive
          continue;
        }
      }
      
      if (dayDate.isAtSameMomentAs(todayDate)) {
        takenDays[i] = todayCompleted ? "1" : "0";
      } else if (dayDate.isAfter(todayDate)) {
        takenDays[i] = "0"; // Future days are not completed yet
      }
      // For past days since earliestCreated, we keep the previously saved takenDays[i] value
    }
    
    final newHistory = takenDays.join('');
    await prefs.setString('week_history_data', newHistory);
    return newHistory;
  }

  static int _calculateStreak(String history, int todayWeekday, List<Reminder> reminders) {
    DateTime? earliestCreated;
    if (reminders.isNotEmpty) {
      for (var r in reminders) {
        if (earliestCreated == null || r.createdAt.isBefore(earliestCreated)) {
          earliestCreated = r.createdAt;
        }
      }
    }
    if (earliestCreated == null) return 0;
    
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final monday = todayDate.subtract(Duration(days: now.weekday - 1));
    final earliestDateOnly = DateTime(earliestCreated.year, earliestCreated.month, earliestCreated.day);

    int streak = 0;
    final takenDays = history.split('');
    
    // Start scanning backwards from today (todayWeekday - 1)
    for (int i = todayWeekday - 1; i >= 0; i--) {
      final dayDate = monday.add(Duration(days: i));
      if (dayDate.isBefore(earliestDateOnly)) {
        break; // Stop counting streak before the medication was created
      }
      
      if (takenDays[i] == "1") {
        streak++;
      } else {
        // If today is not completed yet, we check if yesterday was completed
        // to maintain the streak. But if we hit a '0' before today, the streak is broken.
        if (i < todayWeekday - 1) {
          break;
        }
      }
    }
    return streak;
  }
}
