class ScanResponse {
  final String scanId;
  final String medicationName;
  final String? genericName;
  final String? brandName;
  final String? dosage;
  final String? form;
  final String category;
  final String? activeIngredient;
  final String? excipients;
  final String? indications;
  final String? contraindications;
  final String? sideEffects;
  final String? dosageInstructions;
  final String? posology;
  final String? precautions;
  final String? interactions;
  final String? overdose;
  final String? storage;
  final String? additionalInfo;
  final String? manufacturer;
  final String? lotNumber;
  final String? expiryDate;
  final String packagingLanguage;
  final String? imageUrl;
  final String confidence;
  final String? disclaimer;
  final List<String> warnings;
  final List<String> sources;
  final Map<String, dynamic>? analysisData;
  final DateTime scannedAt;
  final String? analyzedAt;

  ScanResponse({
    required this.scanId,
    required this.medicationName,
    this.genericName,
    this.brandName,
    this.dosage,
    this.form,
    required this.category,
    this.activeIngredient,
    this.excipients,
    this.indications,
    this.contraindications,
    this.sideEffects,
    this.dosageInstructions,
    this.posology,
    this.precautions,
    this.interactions,
    this.overdose,
    this.storage,
    this.additionalInfo,
    this.manufacturer,
    this.lotNumber,
    this.expiryDate,
    required this.packagingLanguage,
    this.imageUrl,
    required this.confidence,
    this.disclaimer,
    required this.warnings,
    required this.sources,
    this.analysisData,
    required this.scannedAt,
    this.analyzedAt,
  });

  static List<String> _parseList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.map((e) => e.toString()).toList();
    if (value is String) return [value];
    return [];
  }

  static String? _parseStringOrList(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is List) {
      if (value.isEmpty) return null;
      return value.map((e) => '- $e').join('\n');
    }
    return value.toString();
  }

  factory ScanResponse.fromJson(Map<String, dynamic> json) {
    return ScanResponse(
      scanId: json['scan_id'] as String? ?? '',
      medicationName: json['medication_name'] as String? ?? 'Médicament',
      genericName: _parseStringOrList(json['generic_name']),
      brandName: _parseStringOrList(json['brand_name']),
      dosage: _parseStringOrList(json['dosage']),
      form: _parseStringOrList(json['form']),
      category: json['category'] as String? ?? 'autre',
      activeIngredient: _parseStringOrList(json['active_ingredient']),
      excipients: _parseStringOrList(json['excipients']),
      indications: _parseStringOrList(json['indications']),
      contraindications: _parseStringOrList(json['contraindications']),
      sideEffects: _parseStringOrList(json['side_effects']),
      dosageInstructions: _parseStringOrList(json['dosage_instructions']),
      posology: _parseStringOrList(json['posology']),
      precautions: _parseStringOrList(json['precautions']),
      interactions: _parseStringOrList(json['interactions']),
      overdose: _parseStringOrList(json['overdose']),
      storage: _parseStringOrList(json['storage']),
      additionalInfo: _parseStringOrList(json['additional_info']),
      manufacturer: _parseStringOrList(json['manufacturer']),
      lotNumber: _parseStringOrList(json['lot_number']),
      expiryDate: _parseStringOrList(json['expiry_date']),
      packagingLanguage: json['packaging_language'] as String? ?? 'fr',
      imageUrl: json['image_url'] as String?,
      confidence: json['confidence'] as String? ?? 'high',
      disclaimer: json['disclaimer'] as String? ?? '⚕️ Ceci est uniquement à titre informatif.',
      warnings: _parseList(json['warnings']),
      sources: _parseList(json['sources']),
      analysisData: json['analysis_data'] as Map<String, dynamic>?,
      scannedAt: json['scanned_at'] != null 
          ? DateTime.parse(json['scanned_at'] as String) 
          : DateTime.now(),
      analyzedAt: json['analyzed_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'scan_id': scanId,
      'medication_name': medicationName,
      'generic_name': genericName,
      'brand_name': brandName,
      'dosage': dosage,
      'form': form,
      'category': category,
      'active_ingredient': activeIngredient,
      'excipients': excipients,
      'indications': indications,
      'contraindications': contraindications,
      'side_effects': sideEffects,
      'dosage_instructions': dosageInstructions,
      'posology': posology,
      'precautions': precautions,
      'interactions': interactions,
      'overdose': overdose,
      'storage': storage,
      'additional_info': additionalInfo,
      'manufacturer': manufacturer,
      'lot_number': lotNumber,
      'expiry_date': expiryDate,
      'packaging_language': packagingLanguage,
      'image_url': imageUrl,
      'confidence': confidence,
      'disclaimer': disclaimer,
      'warnings': warnings,
      'sources': sources,
      'analysis_data': analysisData,
      'scanned_at': scannedAt.toIso8601String(),
      'analyzed_at': analyzedAt,
    };
  }
}
