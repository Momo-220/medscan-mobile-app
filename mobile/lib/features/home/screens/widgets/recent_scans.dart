import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../shared/utils/localization.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../providers/recent_scans_provider.dart';

class RecentScansWidget extends ConsumerWidget {
  const RecentScansWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scansAsync = ref.watch(recentScansProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title + Voir tout
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                ref.t('recentScans'),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              GestureDetector(
                onTap: () => context.go('/pharmacy'),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.20 : 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          scansAsync.when(
            loading: () => _buildSkeleton(isDark),
            error: (err, stack) => _buildEmptyState(context, ref, isDark),
            data: (scans) {
              if (scans.isEmpty) {
                return _buildEmptyState(context, ref, isDark);
              }

              // Display 2-column grid (up to 4 items)
              final displayScans = scans.take(4).toList();

              return LayoutBuilder(
                builder: (context, constraints) {
                  final bool isWide = constraints.maxWidth >= 520;
                  return GridView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: displayScans.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isWide ? 4 : 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: isWide ? 1.25 : 1.15,
                    ),
                    itemBuilder: (context, index) {
                      final scan = displayScans[index];
                      return _buildMedicineCard(context, ref, scan, isDark);
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMedicineCard(BuildContext context, WidgetRef ref, dynamic scan, bool isDark) {
    return GestureDetector(
      onTap: () {
        context.push('/scan-result', extra: scan.toJson());
      },
      onLongPress: () {
        _confirmDeleteScan(context, ref, scan, isDark);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark.withOpacity(0.85) : Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFF1F5F9),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1A3B5D).withOpacity(0.035),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Medicine Box / Scan Image with Delete Overlay Button
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _buildThumbnail(scan, isDark),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () {
                        _confirmDeleteScan(context, ref, scan, isDark);
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B).withValues(alpha: 0.85)
                              : Colors.white.withValues(alpha: 0.90),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                            width: 0.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          size: 15,
                          color: const Color(0xFFEF4444).withOpacity(0.9),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Bottom Name + Chevron Row
            Row(
              children: [
                Expanded(
                  child: Text(
                    ref.formatMedicationName(scan.medicationName),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: isDark ? AppColors.textMutedDark : const Color(0xFF94A3B8),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteScan(BuildContext context, WidgetRef ref, dynamic scan, bool isDark) {
    final isFrench = ref.read(languageProvider) == 'fr';
    final medName = ref.formatMedicationName(scan.medicationName);
    final scanId = (scan.scanId != null && scan.scanId.toString().isNotEmpty)
        ? scan.scanId.toString()
        : scan.id.toString();
    final rawId = scan.id?.toString() ?? '';
    final secondaryId = (rawId.isNotEmpty && rawId != scanId) ? rawId : null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isFrench ? 'Supprimer ce scan ?' : 'Delete this scan?',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          isFrench
              ? 'Voulez-vous supprimer "$medName" de vos scans récents ?'
              : 'Do you want to delete "$medName" from your recent scans?',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              isFrench ? 'Annuler' : 'Cancel',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : const Color(0xFF64748B),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(recentScansProvider.notifier).deleteScan(scanId, secondaryId: secondaryId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isFrench ? 'Scan supprimé' : 'Scan deleted',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                    ),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }
            },
            child: Text(
              isFrench ? 'Supprimer' : 'Delete',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(dynamic scan, bool isDark) {
    final String? localPath = scan.localImagePath ??
        (scan.imageUrl != null && !scan.imageUrl!.startsWith('http') && !scan.imageUrl!.startsWith('/api')
            ? scan.imageUrl
            : null);
    if (localPath != null && File(localPath).existsSync()) {
      return Image.file(
        File(localPath),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholderIcon(isDark),
      );
    }
    return _buildNetworkOrIcon(scan, isDark);
  }

  Widget _buildNetworkOrIcon(dynamic scan, bool isDark) {
    if (scan.imageUrl != null && scan.imageUrl!.isNotEmpty) {
      final String resolved = ApiConstants.resolveImageUrl(scan.imageUrl);
      if (resolved.isNotEmpty) {
        return CachedNetworkImage(
          imageUrl: resolved,
          fit: BoxFit.contain,
          placeholder: (context, url) => const SizedBox(
            width: 28,
            height: 28,
            child: Center(child: CircularProgressIndicator(strokeWidth: 1.5)),
          ),
          errorWidget: (context, url, error) {
            if (scan.localImagePath != null && File(scan.localImagePath!).existsSync()) {
              return Image.file(
                File(scan.localImagePath!),
                fit: BoxFit.contain,
                errorBuilder: (c, e, s) => _buildPlaceholderIcon(isDark),
              );
            }
            return _buildPlaceholderIcon(isDark);
          },
        );
      }
    }
    return _buildPlaceholderIcon(isDark);
  }

  Widget _buildPlaceholderIcon(bool isDark) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Center(
        child: Icon(
          Icons.medication_rounded,
          size: 26,
          color: Color(0xFF2563EB),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark.withOpacity(0.85) : Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFF1F5F9),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A3B5D).withOpacity(0.035),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    Icons.history_toggle_off_rounded,
                    color: isDark ? AppColors.textMutedDark : const Color(0xFF64748B),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                ref.t('noRecentScans'),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.textMutedDark : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () => context.push('/scan'),
            child: Text(
              '+ ${ref.t('scan')}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF2563EB),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth >= 520;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isWide ? 4 : 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: isWide ? 1.25 : 1.15,
          children: List.generate(
            4,
            (i) => const Skeleton(width: double.infinity, height: double.infinity, borderRadius: 20),
          ),
        );
      },
    );
  }
}
