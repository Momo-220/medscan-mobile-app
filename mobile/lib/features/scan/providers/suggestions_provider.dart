import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/providers.dart';
import '../../../data/models/medication_suggestion.dart';

final suggestionsProvider = FutureProvider.family<List<MedicationSuggestion>, String>((ref, category) async {
  if (category.isEmpty) return [];
  
  try {
    final client = ref.read(apiClientProvider);
    final response = await client.get('/suggestions', queryParameters: {
      'category': category,
      'limit': 3,
    });
    
    final List<dynamic> suggestionsJson = response.data['suggestions'] ?? [];
    return suggestionsJson.map((e) => MedicationSuggestion.fromJson(e)).toList();
  } catch (_) {
    return [];
  }
});
