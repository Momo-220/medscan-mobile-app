enum ReminderStatus {
  due,
  completed,
  pending
}

class Reminder {
  final String id;
  final String medicationName;
  final String dosage;
  final String time;
  final String frequency;
  final List<int>? days;
  final String? notes;
  final bool active;
  final DateTime nextDose;
  final bool? taken;
  final DateTime createdAt;
  final DateTime updatedAt;

  Reminder({
    required this.id,
    required this.medicationName,
    required this.dosage,
    required this.time,
    required this.frequency,
    this.days,
    this.notes,
    required this.active,
    required this.nextDose,
    this.taken,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: json['id'] as String? ?? '',
      medicationName: json['medication_name'] as String? ?? '',
      dosage: json['dosage'] as String? ?? '',
      time: json['time'] as String? ?? '',
      frequency: json['frequency'] as String? ?? '',
      days: (json['days'] as List<dynamic>?)?.map((e) => e as int).toList(),
      notes: json['notes'] as String?,
      active: json['active'] as bool? ?? false,
      nextDose: json['next_dose'] != null 
          ? DateTime.parse(json['next_dose'] as String) 
          : DateTime.now(),
      taken: json['taken'] as bool?,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : DateTime.now(),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'medication_name': medicationName,
      'dosage': dosage,
      'time': time,
      'frequency': frequency,
      'days': days,
      'notes': notes,
      'active': active,
      'next_dose': nextDose.toIso8601String(),
      'taken': taken,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Reminder copyWith({
    String? id,
    String? medicationName,
    String? dosage,
    String? time,
    String? frequency,
    List<int>? days,
    String? notes,
    bool? active,
    DateTime? nextDose,
    bool? taken,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Reminder(
      id: id ?? this.id,
      medicationName: medicationName ?? this.medicationName,
      dosage: dosage ?? this.dosage,
      time: time ?? this.time,
      frequency: frequency ?? this.frequency,
      days: days ?? this.days,
      notes: notes ?? this.notes,
      active: active ?? this.active,
      nextDose: nextDose ?? this.nextDose,
      taken: taken ?? this.taken,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isUpToDate {
    return nextDose.isAfter(DateTime.now());
  }

  int get dosesTakenToday {
    final parts = time.split(':');
    if (parts.length != 2) return 0;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    
    final now = DateTime.now();
    final baseToday = DateTime(now.year, now.month, now.day, hour, minute);
    
    final List<DateTime> slots = [];
    if (frequency == 'twice') {
      slots.add(baseToday);
      slots.add(baseToday.add(const Duration(hours: 12)));
    } else if (frequency == 'three-times') {
      slots.add(baseToday);
      slots.add(baseToday.add(const Duration(hours: 8)));
      slots.add(baseToday.add(const Duration(hours: 16)));
    } else {
      slots.add(baseToday);
    }
    
    int count = 0;
    for (var slot in slots) {
      if (nextDose.isAfter(slot)) {
        count++;
      }
    }
    return count;
  }
  
  int get totalDosesToday {
    if (frequency == 'twice') return 2;
    if (frequency == 'three-times') return 3;
    return 1;
  }

  ReminderStatus get status {
    if (!isUpToDate) return ReminderStatus.due;
    if (dosesTakenToday >= totalDosesToday) return ReminderStatus.completed;
    return ReminderStatus.pending;
  }

  DateTime calculateNextDoseTime(DateTime baseTime) {
    final parts = time.split(':');
    if (parts.length != 2) return baseTime.add(const Duration(days: 1));
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    
    var baseDate = DateTime(baseTime.year, baseTime.month, baseTime.day, hour, minute);
    
    List<DateTime> getSlots(DateTime date) {
      if (frequency == 'twice') {
        return [date, date.add(const Duration(hours: 12))];
      } else if (frequency == 'three-times') {
        return [date, date.add(const Duration(hours: 8)), date.add(const Duration(hours: 16))];
      }
      return [date];
    }
    
    var slots = getSlots(baseDate);
    var candidates = slots.where((d) => d.isAfter(baseTime)).toList();
    
    DateTime next;
    if (candidates.isNotEmpty) {
      next = candidates.first;
    } else {
      next = getSlots(baseDate.add(const Duration(days: 1))).first;
    }
    
    if (days != null && days!.isNotEmpty) {
      int loops = 0;
      while (!days!.contains(next.weekday) && loops < 365) {
        next = next.add(const Duration(days: 1));
        loops++;
      }
    }
    return next;
  }
}
