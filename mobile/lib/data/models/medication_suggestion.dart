class MedicationSuggestion {
  final String id;
  final String name;
  final String? genericName;
  final String? brandName;
  final String category;
  final String? dosage;
  final String? form;
  final String? imageUrl;
  final String? manufacturer;
  final String? indications;

  MedicationSuggestion({
    required this.id,
    required this.name,
    this.genericName,
    this.brandName,
    required this.category,
    this.dosage,
    this.form,
    this.imageUrl,
    this.manufacturer,
    this.indications,
  });

  factory MedicationSuggestion.fromJson(Map<String, dynamic> json) {
    return MedicationSuggestion(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      genericName: json['generic_name'] as String?,
      brandName: json['brand_name'] as String?,
      category: json['category'] as String? ?? '',
      dosage: json['dosage'] as String?,
      form: json['form'] as String?,
      imageUrl: json['image_url'] as String?,
      manufacturer: json['manufacturer'] as String?,
      indications: json['indications'] as String?,
    );
  }
}
