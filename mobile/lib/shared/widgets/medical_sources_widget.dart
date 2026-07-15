import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';
import '../utils/localization.dart';

class MedicalSourcesWidget extends ConsumerWidget {
  final String medicationName;
  final List<String>? explicitSources;
  final bool isAiResponse;
  final String? genericName;

  const MedicalSourcesWidget({
    super.key,
    required this.medicationName,
    this.explicitSources,
    this.isAiResponse = false,
    this.genericName,
  });

  // Helper to open a URL in the browser
  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  // Generates direct search link based on medication or generic name
  String _getSearchUrl(String engine, String query) {
    final cleanQuery = Uri.encodeComponent(query.trim());
    switch (engine.toLowerCase()) {
      case 'ansm_notice':
        // Direct search on the official French public drug database (ANSM)
        return 'https://base-donnees-publique.medicaments.gouv.fr/index.php?txtRecherche=$cleanQuery';
      case 'dailymed':
        // Direct search on NIH DailyMed (US)
        return 'https://dailymed.nlm.nih.gov/dailymed/search.cfm?labeltype=all&query=$cleanQuery';
      case 'google_notice':
        // Google search targeted at the official manufacturer leaflet (Notice PDF)
        return 'https://www.google.com/search?q=$cleanQuery+notice+d%27utilisation+pdf+leaflet';
      case 'openfda':
        return 'https://ndclist.com/?s=$cleanQuery';
      case 'ema':
        return 'https://www.ema.europa.eu/en/search/site/$cleanQuery';
      default:
        return 'https://scholar.google.com/scholar?q=$cleanQuery';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appLang = ref.watch(languageProvider);

    // CRITICAL FIX: Prioritize medication name (commercial name like Doliprane) over generic molecule
    // so we search for the actual product, not just its chemical components.
    String cleanName = medicationName.trim();
    if (cleanName.isEmpty || cleanName.toLowerCase() == 'unknown' || cleanName.toLowerCase() == 'médicament') {
      cleanName = (genericName ?? '').trim();
    }
    
    final bool hasValidMedication = cleanName.isNotEmpty && cleanName.toLowerCase() != 'unknown' && cleanName.toLowerCase() != 'médicament';

    // Build the list of sources/citations
    final List<Map<String, String>> sourcesList = [];

    if (hasValidMedication) {
      // 1. Target the Leaflet / Notice directly (highly requested by users & App Store reviewers)
      if (appLang == 'fr') {
        sourcesList.add({
          'name': 'Notice Officielle (ANSM)',
          'url': _getSearchUrl('ansm_notice', cleanName),
        });
        sourcesList.add({
          'name': 'Notice PDF (Google)',
          'url': _getSearchUrl('google_notice', cleanName),
        });
      } else {
        sourcesList.add({
          'name': 'Leaflet Search (NIH)',
          'url': _getSearchUrl('dailymed', cleanName),
        });
        sourcesList.add({
          'name': 'Notice PDF (Google)',
          'url': _getSearchUrl('google_notice', cleanName),
        });
      }

      // 2. Add structural databases
      if (appLang == 'fr') {
        sourcesList.add({
          'name': 'Base Publique du Médicament',
          'url': 'https://base-donnees-publique.medicaments.gouv.fr/',
        });
      } else {
        sourcesList.add({
          'name': 'DailyMed (NIH)',
          'url': 'https://dailymed.nlm.nih.gov/',
        });
        sourcesList.add({
          'name': 'OpenFDA Label',
          'url': _getSearchUrl('openfda', cleanName),
        });
      }
    } else {
      // General fallbacks if medication is not identified
      sourcesList.add({
        'name': 'WHO (World Health Org)',
        'url': 'https://www.who.int/',
      });
      sourcesList.add({
        'name': 'NIH MedlinePlus',
        'url': 'https://medlineplus.gov/',
      });
      if (appLang == 'fr') {
        sourcesList.add({
          'name': 'Base Publique (France)',
          'url': 'https://base-donnees-publique.medicaments.gouv.fr/',
        });
      } else {
        sourcesList.add({
          'name': 'DailyMed NLM',
          'url': 'https://dailymed.nlm.nih.gov/',
        });
      }
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16, bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withOpacity(0.4) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Permanent Warning Banner (Required by Apple Reviewers)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.red[900]!.withOpacity(0.15) : Colors.red[50]!.withOpacity(0.8),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.red[900]!.withOpacity(0.3) : Colors.red[100]!,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded, 
                  color: isDark ? Colors.red[300] : Colors.red[700], 
                  size: 20
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ref.t('permanentMedicalDisclaimer'),
                    style: AppTextStyles.micro(isDark: isDark).copyWith(
                      color: isDark ? Colors.red[200] : Colors.red[800],
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 2. Title Section
                Row(
                  children: [
                    const Icon(
                      Icons.menu_book_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      ref.t('medicalSources'),
                      style: AppTextStyles.smallBold(isDark: isDark).copyWith(
                        color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 3. AI Disclaimer (if generated by Gemini)
                if (isAiResponse) ...[
                  Text(
                    ref.t('aiDisclaimer'),
                    style: AppTextStyles.micro(isDark: isDark).copyWith(
                      fontStyle: FontStyle.italic,
                      color: isDark ? Colors.white60 : Colors.black54,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // 4. Sources badging list (horizontally scrollable chips)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: sourcesList.map((src) {
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _launchUrl(src['url']!),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[900] : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                src['name']!,
                                style: AppTextStyles.micro(isDark: isDark).copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.open_in_new_rounded,
                                size: 12,
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
