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
}
