class HealthStats {
  final int scansThisWeek;
  final int medicationsTaken;
  final int adherenceRate;
  final String? nextReminder;
  final String? nextReminderTime;
  final int pendingReminders;

  HealthStats({
    required this.scansThisWeek,
    required this.medicationsTaken,
    required this.adherenceRate,
    this.nextReminder,
    this.nextReminderTime,
    required this.pendingReminders,
  });

  factory HealthStats.empty() {
    return HealthStats(
      scansThisWeek: 0,
      medicationsTaken: 0,
      adherenceRate: 0,
      nextReminder: null,
      nextReminderTime: null,
      pendingReminders: 0,
    );
  }

  HealthStats copyWith({
    int? scansThisWeek,
    int? medicationsTaken,
    int? adherenceRate,
    String? nextReminder,
    String? nextReminderTime,
    int? pendingReminders,
  }) {
    return HealthStats(
      scansThisWeek: scansThisWeek ?? this.scansThisWeek,
      medicationsTaken: medicationsTaken ?? this.medicationsTaken,
      adherenceRate: adherenceRate ?? this.adherenceRate,
      nextReminder: nextReminder ?? this.nextReminder,
      nextReminderTime: nextReminderTime ?? this.nextReminderTime,
      pendingReminders: pendingReminders ?? this.pendingReminders,
    );
  }
}
