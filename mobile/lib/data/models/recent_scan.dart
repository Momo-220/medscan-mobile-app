class RecentScan {
  final String id;
  final String scanId;
  final String medicationName;
  final String? genericName;
  final String? dosage;
  final String? form;
  final String category;
  final String? manufacturer;
  final String? packagingLanguage;
  final String? imageUrl;
  final String? confidence;
  final DateTime scannedAt;
  final Map<String, dynamic>? analysisData;
  final List<String> warnings;
  final List<String> contraindications;
  final List<String> interactions;
  final List<String> sideEffects;
  final String? disclaimer;

  RecentScan({
    required this.id,
    required this.scanId,
    required this.medicationName,
    this.genericName,
    this.dosage,
    this.form,
    required this.category,
    this.manufacturer,
    this.packagingLanguage,
    this.imageUrl,
    this.confidence,
    required this.scannedAt,
    this.analysisData,
    required this.warnings,
    required this.contraindications,
    required this.interactions,
    required this.sideEffects,
    this.disclaimer,
  });

  static String? _parseStringOrList(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is List) {
      if (value.isEmpty) return null;
      return value.map((e) => '- $e').join('\n');
    }
    return value.toString();
  }

  static List<String> _parseUnionList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.map((e) => e.toString()).toList();
    if (value is String) {
      if (value.trim().isEmpty) return [];
      return [value];
    }
    return [];
  }

  factory RecentScan.fromJson(Map<String, dynamic> json) {
    return RecentScan(
      id: json['id'] as String? ?? json['scan_id'] as String? ?? '',
      scanId: json['scan_id'] as String? ?? json['id'] as String? ?? '',
      medicationName: json['medication_name'] as String? ?? 'Médicament',
      genericName: _parseStringOrList(json['generic_name']),
      dosage: _parseStringOrList(json['dosage']),
      form: _parseStringOrList(json['form']),
      category: json['category'] as String? ?? 'autre',
      manufacturer: _parseStringOrList(json['manufacturer']),
      packagingLanguage: _parseStringOrList(json['packaging_language']),
      imageUrl: json['image_url'] as String?,
      confidence: _parseStringOrList(json['confidence']) ?? 'medium',
      scannedAt: json['scanned_at'] != null 
          ? DateTime.parse(json['scanned_at'] as String) 
          : DateTime.now(),
      analysisData: json['analysis_data'] as Map<String, dynamic>?,
      warnings: _parseUnionList(json['warnings']),
      contraindications: _parseUnionList(json['contraindications']),
      interactions: _parseUnionList(json['interactions']),
      sideEffects: _parseUnionList(json['side_effects']),
      disclaimer: _parseStringOrList(json['disclaimer']) ?? '⚕️ Ceci est uniquement à titre informatif.',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'scan_id': scanId,
      'medication_name': medicationName,
      'generic_name': genericName,
      'dosage': dosage,
      'form': form,
      'category': category,
      'manufacturer': manufacturer,
      'packaging_language': packagingLanguage,
      'image_url': imageUrl,
      'confidence': confidence,
      'scanned_at': scannedAt.toIso8601String(),
      'analysis_data': analysisData,
      'warnings': warnings,
      'contraindications': contraindications,
      'interactions': interactions,
      'side_effects': sideEffects,
      'disclaimer': disclaimer,
    };
  }

  RecentScan copyWith({
    String? id,
    String? scanId,
    String? medicationName,
    String? genericName,
    String? dosage,
    String? form,
    String? category,
    String? manufacturer,
    String? packagingLanguage,
    String? imageUrl,
    String? confidence,
    DateTime? scannedAt,
    Map<String, dynamic>? analysisData,
    List<String>? warnings,
    List<String>? contraindications,
    List<String>? interactions,
    List<String>? sideEffects,
    String? disclaimer,
  }) {
    return RecentScan(
      id: id ?? this.id,
      scanId: scanId ?? this.scanId,
      medicationName: medicationName ?? this.medicationName,
      genericName: genericName ?? this.genericName,
      dosage: dosage ?? this.dosage,
      form: form ?? this.form,
      category: category ?? this.category,
      manufacturer: manufacturer ?? this.manufacturer,
      packagingLanguage: packagingLanguage ?? this.packagingLanguage,
      imageUrl: imageUrl ?? this.imageUrl,
      confidence: confidence ?? this.confidence,
      scannedAt: scannedAt ?? this.scannedAt,
      analysisData: analysisData ?? this.analysisData,
      warnings: warnings ?? this.warnings,
      contraindications: contraindications ?? this.contraindications,
      interactions: interactions ?? this.interactions,
      sideEffects: sideEffects ?? this.sideEffects,
      disclaimer: disclaimer ?? this.disclaimer,
    );
  }
}
