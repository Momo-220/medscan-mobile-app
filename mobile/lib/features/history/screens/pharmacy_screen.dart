import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../shared/utils/localization.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/button.dart';
import '../../../core/constants/api_constants.dart';
import '../../../data/models/recent_scan.dart';
import '../providers/pharmacy_provider.dart';

class PharmacyPage extends ConsumerStatefulWidget {
  const PharmacyPage({super.key});

  @override
  ConsumerState<PharmacyPage> createState() => _PharmacyPageState();
}

class _PharmacyPageState extends ConsumerState<PharmacyPage> {
  final TextEditingController _searchController = TextEditingController();
  late final ScrollController _scrollController;
  final ValueNotifier<double> _scrollOffset = ValueNotifier<double>(0.0);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      if (_scrollController.positions.isNotEmpty) {
        _scrollOffset.value = _scrollController.positions.first.pixels;
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _scrollOffset.dispose();
    super.dispose();
  }

  Color _getCategoryAccentColor(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('douleur') || lower.contains('analg') || lower.contains('pain')) {
      return const Color(0xFF3B82F6); // Blue
    } else if (lower.contains('infect') || lower.contains('antibiot') || lower.contains('anti-infect')) {
      return const Color(0xFF10B981); // Emerald
    } else if (lower.contains('inflamm') || lower.contains('cortico')) {
      return const Color(0xFFF59E0B); // Amber
    } else if (lower.contains('digest') || lower.contains('gastro') || lower.contains('spasm')) {
      return const Color(0xFF06B6D4); // Cyan
    } else if (lower.contains('cardio') || lower.contains('tens')) {
      return const Color(0xFFEF4444); // Red/Coral
    }
    return const Color(0xFF10B981); // Emerald default
  }

  String _formatScannedDate(DateTime date, String lang) {
    if (lang == 'fr') {
      const months = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
      final m = (date.month >= 1 && date.month <= 12) ? months[date.month - 1] : '';
      return '${date.day} $m';
    }
    try {
      return DateFormat.MMMd().format(date);
    } catch (_) {
      return '${date.day}/${date.month}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pharmacyState = ref.watch(pharmacyProvider);
    final user = FirebaseAuth.instance.currentUser;
    final isAnonymous = user?.isAnonymous ?? true;
    final currentLang = ref.watch(languageProvider);

    final int count = pharmacyState.filteredScans.length;
    final String countText = currentLang == 'fr'
        ? '$count médicament${count > 1 ? 's' : ''}'
        : currentLang == 'tr'
            ? '$count ilaç'
            : currentLang == 'ar'
                ? '$count أدوية'
                : '$count medication${count > 1 ? 's' : ''}';

    final topPadding = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF1F6FB),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header with Dashboard-matching smooth gradient fondu
          RepaintBoundary(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFD6EAFC),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [const Color(0xFF1E293B), AppColors.backgroundDark]
                      : [const Color(0xFFD4E8FC), const Color(0xFFF1F6FB)],
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: topPadding + 8,
                      left: 16.0,
                      right: 16.0,
                      bottom: 14.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Row: Title + Medication Count Pill
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              ref.t('myPharmacy'),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                letterSpacing: -0.5,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.10)
                                    : Colors.white.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : const Color(0xFFCBD5E1).withValues(alpha: 0.6),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                countText,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Search Field
                        Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : const Color(0xFFCBD5E1).withValues(alpha: 0.7),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) {
                              ref.read(pharmacyProvider.notifier).setSearchQuery(val);
                            },
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            decoration: InputDecoration(
                              hintText: ref.t('searchMedications'),
                              hintStyle: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                color: isDark
                                    ? const Color(0xFF64748B)
                                    : const Color(0xFF94A3B8),
                              ),
                              prefixIcon: Icon(
                                CupertinoIcons.search,
                                size: 18,
                                color: isDark
                                    ? const Color(0xFF64748B)
                                    : const Color(0xFF94A3B8),
                              ),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? GestureDetector(
                                      onTap: () {
                                        _searchController.clear();
                                        ref.read(pharmacyProvider.notifier).setSearchQuery('');
                                        setState(() {});
                                      },
                                      child: Icon(
                                        CupertinoIcons.clear_circled_solid,
                                        size: 18,
                                        color: isDark
                                            ? const Color(0xFF64748B)
                                            : const Color(0xFF94A3B8),
                                      ),
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 3 Compact Filters (iOS Sliding & Draggable Control like Reminders)
                        _SlidingPharmacyFilter(
                          selectedValue: pharmacyState.sortFilter,
                          onValueChanged: (val) {
                            ref.read(pharmacyProvider.notifier).setSortFilter(val);
                          },
                          isDark: isDark,
                          lang: currentLang,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 2. Body: Scrollable Grid with Dashboard cinematic dissolve
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                if (user != null) {
                  await ref.read(pharmacyProvider.notifier).fetchPharmacyList(user.uid);
                }
              },
              color: AppColors.primary,
              child: ValueListenableBuilder<double>(
                valueListenable: _scrollOffset,
                builder: (context, offset, child) {
                  final double fadeStop = (offset / 32.0).clamp(0.0, 1.0) * 0.048;
                  return ShaderMask(
                    shaderCallback: (Rect bounds) {
                      if (fadeStop <= 0.001) {
                        return const LinearGradient(
                          colors: [Colors.black, Colors.black],
                        ).createShader(bounds);
                      }
                      return LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: const [
                          Colors.transparent,
                          Colors.black,
                        ],
                        stops: [0.0, fadeStop],
                      ).createShader(bounds);
                    },
                    blendMode: BlendMode.dstIn,
                    child: child!,
                  );
                },
                child: isAnonymous
                    ? _buildTrialState(isDark)
                    : (pharmacyState.loading && pharmacyState.filteredScans.isEmpty)
                        ? _buildSkeletonGrid(context)
                        : pharmacyState.filteredScans.isEmpty
                            ? _buildEmptyState(isDark)
                            : _buildScansGrid(context, pharmacyState.filteredScans, isDark),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScansGrid(BuildContext context, List<RecentScan> scans, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth >= 560;
        final bottomPadding = AppResponsive.bottomBarSpacing(context);
        final int crossAxisCount = isWide ? (constraints.maxWidth / 190).floor().clamp(2, 6) : 2;

        return GridView.builder(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            top: 8.0,
            bottom: bottomPadding,
          ),
          itemCount: scans.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.88,
          ),
          itemBuilder: (context, index) {
            return _buildPharmacyCard(context, scans[index], isDark);
          },
        );
      },
    );
  }

  Widget _buildPharmacyCard(BuildContext context, RecentScan scan, bool isDark) {
    final currentLang = ref.watch(languageProvider);
    final scannedDate = _formatScannedDate(scan.scannedAt, currentLang);
    final accentColor = _getCategoryAccentColor(scan.category);

    final subtitleParts = <String>[];
    if (scan.dosage != null && scan.dosage!.isNotEmpty) {
      subtitleParts.add(scan.dosage!);
    }
    if (scan.form != null && scan.form!.isNotEmpty) {
      subtitleParts.add(scan.form!);
    }
    final subtitleText = subtitleParts.join(' • ');

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push('/scan-result', extra: scan.toJson());
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Left Category Accent Bar
            Positioned(
              left: 0,
              top: 12,
              bottom: 12,
              width: 3.5,
              child: Container(
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(3),
                    bottomRight: Radius.circular(3),
                  ),
                ),
              ),
            ),

            // Card Inner Layout: Top Square Image (~70% space) + Bottom Info (~30%)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Prominent Square Medication Image Container (~70% of card)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 7, 18, 0),
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F172A).withValues(alpha: 0.6)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : const Color(0xFFF1F5F9),
                          width: 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: _buildThumbnail(scan, isDark),
                      ),
                    ),
                  ),
                ),

                // Details Section Below Image (~30% space)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Medication Name (1-2 lines)
                            Text(
                              ref.formatMedicationName(scan.medicationName),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                height: 1.15,
                              ),
                              maxLines: subtitleText.isNotEmpty ? 1 : 2,
                              overflow: TextOverflow.ellipsis,
                            ),

                            // Subtitle (dosage / form)
                            if (subtitleText.isNotEmpty) ...[
                              const SizedBox(height: 1),
                              Text(
                                subtitleText,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),

                        // Bottom Row: Category Pill Badge + Date
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (scan.category.isNotEmpty)
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? accentColor.withValues(alpha: 0.15)
                                        : accentColor.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    scan.category,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w600,
                                      color: accentColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                            else
                              const SizedBox.shrink(),
                            const SizedBox(width: 4),
                            Text(
                              scannedDate,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? const Color(0xFF64748B)
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Top-Right Floating Delete Button
            Positioned(
              top: 11,
              right: 13,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _confirmDeletePharmacyScan(context, scan, isDark);
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(4.5),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B).withValues(alpha: 0.85)
                        : Colors.white.withValues(alpha: 0.90),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : const Color(0xFFE2E8F0),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Icon(
                    CupertinoIcons.trash,
                    size: 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeletePharmacyScan(BuildContext context, RecentScan scan, bool isDark) {
    final isFrench = ref.read(languageProvider) == 'fr';
    final medName = ref.formatMedicationName(scan.medicationName);
    final scanId = scan.scanId.isNotEmpty ? scan.scanId : scan.id;

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
                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(CupertinoIcons.trash, color: Color(0xFFEF4444), size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isFrench ? 'Supprimer ce médicament ?' : 'Delete medication?',
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
              ? 'Voulez-vous retirer "$medName" de votre pharmacie ?'
              : 'Do you want to remove "$medName" from your pharmacy?',
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
              final secondaryId = (scan.id.isNotEmpty && scan.id != scanId) ? scan.id : null;
              await ref.read(pharmacyProvider.notifier).deleteScan(scanId, secondaryId: secondaryId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isFrench ? 'Médicament supprimé' : 'Medication deleted',
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
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth >= 560;
        final bottomPadding = AppResponsive.bottomBarSpacing(context);
        final int crossAxisCount = isWide ? (constraints.maxWidth / 190).floor().clamp(2, 6) : 2;

        return GridView.builder(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            top: 8.0,
            bottom: bottomPadding,
          ),
          itemCount: 6,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.88,
          ),
          itemBuilder: (context, index) => _buildSkeletonSquareCard(context),
        );
      },
    );
  }

  Widget _buildSkeletonSquareCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: const Padding(
        padding: EdgeInsets.fromLTRB(8, 0, 8, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(10, 7, 10, 0),
              child: AspectRatio(
                aspectRatio: 1.0,
                child: Skeleton(width: double.infinity, height: double.infinity, borderRadius: 14),
              ),
            ),
            SizedBox(height: 6),
            Skeleton(width: 95, height: 11, borderRadius: 4),
            SizedBox(height: 4),
            Skeleton(width: 60, height: 9, borderRadius: 4),
            Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Skeleton(width: 42, height: 12, borderRadius: 4),
                Skeleton(width: 28, height: 9, borderRadius: 4),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrialState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.lock,
              size: 56,
              color: isDark ? Colors.white12 : Colors.black12,
            ),
            const SizedBox(height: 16),
            Text(
              ref.t('restrictedHistoryTitle'),
              style: AppTextStyles.bodyBold(isDark: isDark),
            ),
            const SizedBox(height: 8),
            Text(
              ref.t('restrictedHistoryDesc'),
              style: AppTextStyles.small(isDark: isDark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Button(
              onTap: () => context.go('/auth'),
              child: Text(ref.t('signInOrRegister')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CupertinoIcons.square_stack_3d_up_slash,
                  size: 32,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                ref.t('noRecentScans'),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                ref.watch(languageProvider) == 'fr'
                    ? 'Scannez un médicament pour l\'ajouter à votre pharmacie personnelle.'
                    : 'Scan a medication to add it to your personal pharmacy.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(RecentScan scan, bool isDark) {
    final String? localPath = scan.localImagePath ??
        (scan.imageUrl != null && !scan.imageUrl!.startsWith('http') && !scan.imageUrl!.startsWith('/api')
            ? scan.imageUrl
            : null);
    if (localPath != null && File(localPath).existsSync()) {
      return Image.file(
        File(localPath),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildNetworkOrIcon(scan, isDark),
      );
    }
    return _buildNetworkOrIcon(scan, isDark);
  }

  Widget _buildNetworkOrIcon(RecentScan scan, bool isDark) {
    if (scan.imageUrl != null && scan.imageUrl!.isNotEmpty) {
      final String resolved = ApiConstants.resolveImageUrl(scan.imageUrl);
      if (resolved.isNotEmpty) {
        return CachedNetworkImage(
          imageUrl: resolved,
          fit: BoxFit.cover,
          placeholder: (context, url) =>
              const Skeleton(width: double.infinity, height: double.infinity),
          errorWidget: (context, url, error) {
            if (scan.localImagePath != null && File(scan.localImagePath!).existsSync()) {
              return Image.file(
                File(scan.localImagePath!),
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Center(
                  child: Icon(
                    CupertinoIcons.capsule,
                    size: 38,
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  ),
                ),
              );
            }
            return Center(
              child: Icon(
                CupertinoIcons.capsule,
                size: 38,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
            );
          },
        );
      }
    }
    return Center(
      child: Icon(
        CupertinoIcons.capsule,
        size: 38,
        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
      ),
    );
  }
}

class _SlidingPharmacyFilter extends StatefulWidget {
  final String selectedValue;
  final ValueChanged<String> onValueChanged;
  final bool isDark;
  final String lang;

  const _SlidingPharmacyFilter({
    required this.selectedValue,
    required this.onValueChanged,
    required this.isDark,
    required this.lang,
  });

  @override
  State<_SlidingPharmacyFilter> createState() => _SlidingPharmacyFilterState();
}

class _SlidingPharmacyFilterState extends State<_SlidingPharmacyFilter> {
  bool _isDragging = false;
  double? _dragPositionX;
  int _hoveredIndex = 0;

  List<Map<String, String>> _getOptions() {
    String allLabel;
    String dateLabel;
    String nameLabel;
    if (widget.lang == 'fr') {
      allLabel = 'Tous';
      dateLabel = 'Par Date';
      nameLabel = 'Par Nom';
    } else if (widget.lang == 'tr') {
      allLabel = 'Tümü';
      dateLabel = 'Tarihe Göre';
      nameLabel = 'Ada Göre';
    } else if (widget.lang == 'ar') {
      allLabel = 'الكل';
      dateLabel = 'حسب التاريخ';
      nameLabel = 'حسب الاسم';
    } else {
      allLabel = 'All';
      dateLabel = 'By Date';
      nameLabel = 'By Name';
    }
    return [
      {'value': 'all', 'label': allLabel},
      {'value': 'date', 'label': dateLabel},
      {'value': 'name', 'label': nameLabel},
    ];
  }

  int _getIndexForValue(String val) {
    final opts = _getOptions();
    final idx = opts.indexWhere((o) => o['value'] == val);
    return idx < 0 ? 0 : idx;
  }

  @override
  void initState() {
    super.initState();
    _hoveredIndex = _getIndexForValue(widget.selectedValue);
  }

  @override
  void didUpdateWidget(covariant _SlidingPharmacyFilter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging) {
      _hoveredIndex = _getIndexForValue(widget.selectedValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = _getOptions();
    final selectedIndex = _getIndexForValue(widget.selectedValue);

    return Container(
      height: 40,
      padding: const EdgeInsets.all(3.0),
      decoration: BoxDecoration(
        color: widget.isDark
            ? const Color(0xFF0F172A).withValues(alpha: 0.55)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double totalWidth = constraints.maxWidth;
          final double segmentWidth = totalWidth / 3;

          double pillLeft;
          if (_isDragging && _dragPositionX != null) {
            final double rawLeft = _dragPositionX! - (segmentWidth / 2);
            pillLeft = rawLeft.clamp(0.0, totalWidth - segmentWidth);
          } else {
            pillLeft = selectedIndex * segmentWidth;
          }

          final activeIndex = _isDragging ? _hoveredIndex : selectedIndex;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              final idx = (details.localPosition.dx / segmentWidth).floor().clamp(0, 2);
              _hoveredIndex = idx;
            },
            onTapUp: (details) {
              final idx = (details.localPosition.dx / segmentWidth).floor().clamp(0, 2);
              HapticFeedback.lightImpact();
              widget.onValueChanged(options[idx]['value']!);
            },
            onHorizontalDragStart: (details) {
              final idx = (details.localPosition.dx / segmentWidth).floor().clamp(0, 2);
              setState(() {
                _isDragging = true;
                _dragPositionX = details.localPosition.dx;
                _hoveredIndex = idx;
              });
              HapticFeedback.selectionClick();
            },
            onHorizontalDragUpdate: (details) {
              final newHovered = (details.localPosition.dx / segmentWidth).floor().clamp(0, 2);
              if (newHovered != _hoveredIndex) {
                _hoveredIndex = newHovered;
                HapticFeedback.selectionClick();
              }
              setState(() {
                _dragPositionX = details.localPosition.dx;
              });
            },
            onHorizontalDragEnd: (_) {
              final chosen = _hoveredIndex;
              setState(() {
                _isDragging = false;
                _dragPositionX = null;
              });
              HapticFeedback.lightImpact();
              widget.onValueChanged(options[chosen]['value']!);
            },
            onHorizontalDragCancel: () {
              setState(() {
                _isDragging = false;
                _dragPositionX = null;
                _hoveredIndex = selectedIndex;
              });
            },
            child: Stack(
              children: [
                // Fluid Sliding & Dragging Pill
                AnimatedPositioned(
                  duration: _isDragging ? Duration.zero : const Duration(milliseconds: 280),
                  curve: Curves.fastOutSlowIn,
                  left: pillLeft,
                  top: 0,
                  width: segmentWidth,
                  height: 34,
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.isDark ? const Color(0xFF334155) : Colors.white,
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: widget.isDark ? 0.35 : 0.08),
                          blurRadius: _isDragging ? 8 : 6,
                          offset: const Offset(0, 1.5),
                        ),
                      ],
                    ),
                  ),
                ),

                // Interactive Options Row
                Row(
                  children: List.generate(options.length, (index) {
                    final opt = options[index];
                    final isSelected = activeIndex == index;
                    return Expanded(
                      child: SizedBox(
                        height: 34,
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected
                                  ? (widget.isDark ? Colors.white : const Color(0xFF0F172A))
                                  : (widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                            child: Text(
                              opt['label']!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

