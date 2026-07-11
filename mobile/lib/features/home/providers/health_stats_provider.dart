import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/health_stats.dart';
import '../../../data/models/reminder.dart';
import '../../../data/remote/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/di/providers.dart';

class HealthStatsNotifier extends StateNotifier<AsyncValue<HealthStats>> {
  final Ref _ref;
  Timer? _timer;

  HealthStatsNotifier(this._ref) : super(const AsyncValue.loading()) {
    // Listen to authentication to start or stop polling
    _ref.listen(firebaseAuthStateProvider, (previous, next) {
      final user = next.value;
      if (user != null) {
        fetchStats();
        _startTimer();
      } else {
        _stopTimer();
        state = AsyncValue.data(HealthStats.empty());
      }
    }, fireImmediately: true);
  }

  void _startTimer() {
    _stopTimer();
    // Poll every 5 minutes (matching React context interval)
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => fetchStats(quietly: true));
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> fetchStats({bool quietly = false}) async {
    final user = _ref.read(firebaseAuthStateProvider).value;
    if (user == null) return;

    if (user.isAnonymous) {
      // Trial user: Health metrics remain empty (matches React emptyStats rule)
      state = AsyncValue.data(HealthStats.empty());
      return;
    }

    if (!quietly) {
      state = const AsyncValue.loading();
    }

    try {
      final client = _ref.read(apiClientProvider);

      // Perform parallel fetches for reminders and scan history
      final results = await Future.wait([
        client.get('/reminders', queryParameters: {'active_only': true, 'limit': 50}),
        client.get('/history', queryParameters: {'limit': 100, 'page': 1}),
      ]);

      final remindersData = results[0].data;
      final historyData = results[1].data;

      // === Process Reminders ===
      final List<dynamic> remindersJson = remindersData['reminders'] ?? [];
      final List<Reminder> reminders = remindersJson.map((e) => Reminder.fromJson(e)).toList();
      final int medicationsTakenToday = remindersData['medications_taken_today'] ?? 0;
      
      final activeReminders = reminders.where((r) => r.active).toList();
      
      // Calculate Adherence Rate: (Medications taken / total active reminders) capped at 100%
      final int totalReminders = reminders.length;
      final int adherenceRate = totalReminders > 0 
          ? ((medicationsTakenToday / totalReminders) * 100).round().clamp(0, 100) 
          : 0;

      // Find Next Active Reminder
      Reminder? nextReminderObj;
      if (activeReminders.isNotEmpty) {
        activeReminders.sort((a, b) => a.nextDose.compareTo(b.nextDose));
        nextReminderObj = activeReminders.first;
      }

      // Calculate Time Remaining for Next Dose
      String? nextReminderTime;
      if (nextReminderObj != null) {
        final now = DateTime.now().toUtc();
        final difference = nextReminderObj.nextDose.difference(now);

        if (difference.isNegative) {
          nextReminderTime = 'late';
        } else {
          final hours = difference.inHours;
          final minutes = difference.inMinutes % 60;
          if (hours > 0) {
            nextReminderTime = '${hours}h${minutes > 0 ? ' ${minutes}min' : ''}';
          } else {
            nextReminderTime = '${minutes}min';
          }
        }
      }

      // === Process Scans ===
      final List<dynamic> scansJson = historyData['scans'] ?? [];
      final int scansCount = historyData['count'] ?? 0;
      
      // Filter scans in the last 7 days
      final now = DateTime.now().toUtc();
      final oneWeekAgo = now.subtract(const Duration(days: 7));
      
      int scansThisWeek = 0;
      for (var s in scansJson) {
        final scannedAtStr = s['scanned_at'];
        if (scannedAtStr != null) {
          final scannedAt = DateTime.parse(scannedAtStr);
          if (scannedAt.isAfter(oneWeekAgo)) {
            scansThisWeek++;
          }
        }
      }

      final stats = HealthStats(
        scansThisWeek: scansThisWeek,
        medicationsTaken: medicationsTakenToday,
        adherenceRate: adherenceRate,
        nextReminder: nextReminderObj?.medicationName,
        nextReminderTime: nextReminderTime ?? nextReminderObj?.time,
        pendingReminders: activeReminders.length,
      );

      if (mounted) {
        state = AsyncValue.data(stats);
      }
    } catch (e, stack) {
      if (mounted && !quietly) {
        state = AsyncValue.error(e, stack);
      }
    }
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }
}

// Health Stats Provider
final healthStatsProvider = StateNotifierProvider<HealthStatsNotifier, AsyncValue<HealthStats>>((ref) {
  return HealthStatsNotifier(ref);
});
