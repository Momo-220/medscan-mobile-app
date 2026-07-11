class Credits {
  final int credits;
  final String? nextResetAt;

  Credits({
    required this.credits,
    this.nextResetAt,
  });

  factory Credits.fromJson(Map<String, dynamic> json) {
    return Credits(
      credits: json['credits'] as int? ?? 0,
      nextResetAt: json['next_reset_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'credits': credits,
      'next_reset_at': nextResetAt,
    };
  }

  Credits copyWith({
    int? credits,
    String? nextResetAt,
  }) {
    return Credits(
      credits: credits ?? this.credits,
      nextResetAt: nextResetAt ?? this.nextResetAt,
    );
  }
}
