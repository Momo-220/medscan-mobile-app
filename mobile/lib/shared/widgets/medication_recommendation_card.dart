import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/api_constants.dart';
import '../../data/models/recent_scan.dart';
import '../../features/history/providers/pharmacy_provider.dart';
import '../utils/localization.dart';

/// Helper to parse and extract medication recommendations from AI assistant responses.
class MedicationRecommendationParser {
  static Map<String, dynamic>? parse(String content) {
    if (content.isEmpty) return null;
    final jsonMatch = RegExp(r'\[\[MEDICATION_RECOMMENDED:(\{.*?\})\]\]').firstMatch(content);
    if (jsonMatch != null) {
      try {
        final decoded = json.decode(jsonMatch.group(1)!);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      } catch (_) {}
    }
    final idMatch = RegExp(r'\[\[MEDICATION_RECOMMENDED:([a-zA-Z0-9_-]+)\]\]').firstMatch(content);
    if (idMatch != null) {
      return {'id': idMatch.group(1)!};
    }
    return null;
  }

  static String cleanText(String content) {
    return content.replaceAll(RegExp(r'\[\[MEDICATION_RECOMMENDED.*'), '').trim();
  }
}

/// Interactive medication recommendation card displayed when the AI assistant
/// recommends a medication from the user's scanned medicine cabinet.
class MedicationRecommendationCard extends ConsumerWidget {
  final Map<String, dynamic> medicationData;
  final VoidCallback? onCustomTap;

  const MedicationRecommendationCard({
    super.key,
    required this.medicationData,
    this.onCustomTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = ref.watch(languageProvider);
    final pharmacyState = ref.watch(pharmacyProvider);

    final String scanId = (medicationData['id'] ?? medicationData['scan_id'] ?? '').toString();
    final String medName = (medicationData['name'] ?? medicationData['medication_name'] ?? 'Médicament').toString();
    final String? dosage = medicationData['dosage'] as String?;
    final String? form = medicationData['form'] as String?;
    final String? category = medicationData['category'] as String?;
    String? imageUrl = medicationData['image_url'] as String? ?? medicationData['imageUrl'] as String?;

    // Find the full RecentScan in pharmacy if available
    RecentScan? matchedScan;
    if (scanId.isNotEmpty) {
      try {
        matchedScan = pharmacyState.allScans.firstWhere(
          (s) => s.scanId == scanId || s.id == scanId,
        );
      } catch (_) {
        matchedScan = null;
      }
    }

    if (imageUrl == null || imageUrl.isEmpty) {
      imageUrl = matchedScan?.imageUrl ?? matchedScan?.localImagePath;
    }

    // Localized texts
    final isFrench = lang == 'fr';
    final isTurkish = lang == 'tr';
    final isArabic = lang == 'ar';

    final badgeLabel = isFrench
        ? 'DANS VOTRE PHARMACIE'
        : (isTurkish ? 'ECZA DOLABINIZDA' : (isArabic ? 'في صيدليتك' : 'IN YOUR CABINET'));

    final actionLabel = isFrench
        ? 'Voir la notice'
        : (isTurkish ? 'İlacı incele' : (isArabic ? 'عرض النشرة' : 'View details'));

    final dosageSubtitle = [
      if (dosage != null && dosage.isNotEmpty) dosage,
      if (form != null && form.isNotEmpty) form,
    ].join(' • ');

    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.45 : 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.12 : 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.lightImpact();
            if (onCustomTap != null) {
              onCustomTap!();
              return;
            }
            if (matchedScan != null) {
              context.push('/scan-result', extra: matchedScan.toJson());
            } else {
              context.push('/scan-result', extra: {
                'scan_id': scanId,
                'id': scanId,
                'medication_name': medName,
                'dosage': dosage,
                'form': form,
                'category': category ?? 'autre',
                'image_url': imageUrl,
                'analysis_data': {
                  'medication_name': medName,
                  'dosage': dosage,
                  'form': form,
                  'category': category,
                },
              });
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Pill Badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.25),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            CupertinoIcons.checkmark_shield_fill,
                            size: 11,
                            color: Color(0xFF10B981),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            badgeLabel,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (category != null && category.isNotEmpty && category.toLowerCase() != 'autre') ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          category,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),

                // Main Content: Thumbnail Photo + Medication Info
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Medication Photo Thumbnail
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: _buildThumbnailImage(imageUrl, isDark),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Medication Titles
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            medName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          if (dosageSubtitle.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              dosageSubtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Action Button / Arrow
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            actionLabel,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            CupertinoIcons.arrow_right,
                            size: 11,
                            color: Color(0xFF10B981),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailImage(String? url, bool isDark) {
    if (url == null || url.isEmpty) {
      return Center(
        child: Icon(
          CupertinoIcons.capsule_fill,
          color: const Color(0xFF10B981).withValues(alpha: 0.7),
          size: 26,
        ),
      );
    }

    if (!url.startsWith('http') && File(url).existsSync()) {
      return Image.file(
        File(url),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Center(
          child: Icon(
            CupertinoIcons.capsule_fill,
            color: const Color(0xFF10B981).withValues(alpha: 0.7),
            size: 26,
          ),
        ),
      );
    }

    final resolved = ApiConstants.resolveImageUrl(url);
    return CachedNetworkImage(
      imageUrl: resolved,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF10B981),
            ),
          ),
        ),
      ),
      errorWidget: (context, url, error) => Center(
        child: Icon(
          CupertinoIcons.capsule_fill,
          color: const Color(0xFF10B981).withValues(alpha: 0.7),
          size: 26,
        ),
      ),
    );
  }
}
