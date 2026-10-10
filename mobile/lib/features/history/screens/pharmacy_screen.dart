import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../shared/utils/localization.dart';
import '../../../shared/widgets/card.dart';
import '../../../shared/widgets/input.dart';
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pharmacyState = ref.watch(pharmacyProvider);
    final user = FirebaseAuth.instance.currentUser;
    final isAnonymous = user?.isAnonymous ?? true;

    // Available categories from user's scans
    final categories = ['']; // Empty means "All"
    for (var scan in pharmacyState.allScans) {
      if (scan.category.isNotEmpty && !categories.contains(scan.category)) {
        categories.add(scan.category);
      }
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ref.t('myPharmacy'),
              style: AppTextStyles.h3(isDark: isDark).copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              '${pharmacyState.allScans.length} ${ref.t('medicationsScanned')}',
              style: AppTextStyles.small(
                color: isDark ? AppColors.textMutedDark : AppColors.textSecondary,
              ).copyWith(fontSize: 12),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            if (user != null) {
              await ref.read(pharmacyProvider.notifier).fetchPharmacyList(user.uid);
            }
          },
          color: AppColors.primary,
          child: ResponsiveContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: CustomInput(
                    controller: _searchController,
                    hintText: ref.t('searchMedications'),
                    icon: Icon(
                      Icons.search,
                      color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                    ),
                    onChanged: (value) {
                      ref.read(pharmacyProvider.notifier).setSearchQuery(value);
                    },
                  ),
                ),

                // 1b. Stat Boxes Row
                _buildStatBoxesRow(context, pharmacyState),

                // 2. Categories Horizontal Scroll
                if (categories.length > 1) ...[
                  SizedBox(
                    height: 38,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final cat = categories[index];
                        final isSelected = pharmacyState.selectedCategory == cat;
                        final label = cat.isEmpty ? ref.t('all') : cat;

                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(label),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                ref.read(pharmacyProvider.notifier).setCategory(cat);
                              }
                            },
                            selectedColor: AppColors.primary,
                            backgroundColor: isDark ? AppColors.cardDark : Colors.white,
                            labelStyle: AppTextStyles.small(
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimary),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isSelected 
                                    ? AppColors.primary 
                                    : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                              ),
                            ),
                            showCheckmark: false,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // 3. Main Results Grid/List
                Expanded(
                  child: isAnonymous
                      ? _buildTrialState(isDark)
                      : (pharmacyState.loading && pharmacyState.filteredScans.isEmpty)
                          ? _buildSkeletonList(context)
                          : pharmacyState.filteredScans.isEmpty
                              ? _buildEmptyState(isDark)
                              : _buildScansGrid(context, pharmacyState.filteredScans, isDark),
                ),
              ],
            ),
          ),
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
              Icons.lock_outline,
              size: 64,
              color: isDark ? Colors.white10 : Colors.black12,
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_toggle_off_outlined,
              size: 64,
              color: isDark ? Colors.white24 : Colors.black12,
            ),
            const SizedBox(height: 16),
            Text(
              ref.t('noRecentScans'),
              style: AppTextStyles.body(isDark: isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScansGrid(BuildContext context, List<RecentScan> scans, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth >= 560;
        final bottomPadding = AppResponsive.bottomBarSpacing(context);

        if (isWide) {
          return GridView.builder(
            padding: EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              top: 8.0,
              bottom: bottomPadding,
            ),
            itemCount: scans.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 400,
              mainAxisExtent: 120,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (context, index) {
              return _buildPharmacyCard(context, scans[index], isDark);
            },
          );
        }

        return ListView.builder(
          padding: EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            top: 8.0,
            bottom: bottomPadding,
          ),
          itemCount: scans.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: _buildPharmacyCard(context, scans[index], isDark),
            );
          },
        );
      },
    );
  }

  Widget _buildPharmacyCard(BuildContext context, RecentScan scan, bool isDark) {
    final scannedDate = DateFormat.yMMMd().format(scan.scannedAt);
    
    final subtitleParts = <String>[];
    if (scan.dosage != null && scan.dosage!.isNotEmpty) {
      subtitleParts.add(scan.dosage!);
    }
    if (scan.form != null && scan.form!.isNotEmpty) {
      subtitleParts.add(scan.form!);
    }
    final subtitleText = subtitleParts.join(' • ');

    return AppCard(
      hover: true,
      padding: const EdgeInsets.all(14),
      onTap: () {
        context.push('/scan-result', extra: scan.toJson());
      },
      children: Row(
        children: [
          // Image Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 56,
              height: 56,
              color: isDark ? const Color(0xFF1E293B) : AppColors.backgroundSecondary,
              child: _buildThumbnail(scan, isDark),
            ),
          ),
          const SizedBox(width: 14),

          // Details Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        scan.medicationName,
                        style: AppTextStyles.bodyBold(isDark: isDark).copyWith(fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      scannedDate,
                      style: AppTextStyles.micro(isDark: isDark).copyWith(
                        color: isDark ? AppColors.textMutedDark : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                if (subtitleText.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitleText,
                    style: AppTextStyles.small(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark 
                        ? const Color(0xFF1E3A8A).withOpacity(0.3) 
                        : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark 
                          ? const Color(0xFF1E40AF).withOpacity(0.4) 
                          : const Color(0xFFDBEAFE),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    scan.category,
                    style: AppTextStyles.micro(isDark: isDark).copyWith(
                      color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.chevron_right,
            color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonList(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth >= 560;
        final bottomPadding = AppResponsive.bottomBarSpacing(context);

        if (isWide) {
          return GridView.builder(
            padding: EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              top: 8.0,
              bottom: bottomPadding,
            ),
            itemCount: 4,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 400,
              mainAxisExtent: 120,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (context, index) => _buildSkeletonItem(),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            top: 8.0,
            bottom: bottomPadding,
          ),
          itemCount: 4,
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: _buildSkeletonItem(),
          ),
        );
      },
    );
  }

  Widget _buildSkeletonItem() {
    return const AppCard(
      padding: EdgeInsets.all(14),
      children: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Skeleton(width: 120, height: 18),
              Skeleton(width: 70, height: 12),
            ],
          ),
          SizedBox(height: 6),
          Skeleton(width: 160, height: 12),
          SizedBox(height: 10),
          Skeleton(width: 80, height: 20, borderRadius: 8),
        ],
      ),
    );
  }

  Widget _buildStatBoxesRow(BuildContext context, PharmacyState state) {
    final totalCount = state.allScans.length;
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final thisMonthCount = state.allScans.where((s) => s.scannedAt.isAfter(startOfMonth)).length;
    const toRenewCount = 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 360;
          return Row(
            children: [
              Expanded(
                child: _buildStatBox(
                  context: context,
                  value: totalCount.toString(),
                  label: ref.t('total'),
                  icon: Icons.inventory_2_outlined,
                  iconColor: const Color(0xFF3B82F6),
                  isCompact: isCompact,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatBox(
                  context: context,
                  value: toRenewCount.toString(),
                  label: ref.t('toRenew'),
                  icon: Icons.warning_amber_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  isCompact: isCompact,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatBox(
                  context: context,
                  value: thisMonthCount.toString(),
                  label: ref.t('thisMonth'),
                  icon: Icons.calendar_today_outlined,
                  iconColor: const Color(0xFF10B981),
                  isCompact: isCompact,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatBox({
    required BuildContext context,
    required String value,
    required String label,
    required IconData icon,
    required Color iconColor,
    bool isCompact = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: AppTextStyles.h3(isDark: isDark).copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: isCompact ? 18 : 22,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: isCompact ? 14 : 16),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppTextStyles.micro(isDark: isDark).copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: isCompact ? 10 : 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(RecentScan scan, bool isDark) {
    // 1. Direct local file if available on this device
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
          placeholder: (context, url) => const Skeleton(width: 60, height: 60),
          errorWidget: (context, url, error) {
            if (scan.localImagePath != null && File(scan.localImagePath!).existsSync()) {
              return Image.file(
                File(scan.localImagePath!),
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => const Icon(
                  Icons.medication_outlined,
                  size: 28,
                  color: AppColors.primary,
                ),
              );
            }
            return const Icon(
              Icons.medication_outlined,
              size: 28,
              color: AppColors.primary,
            );
          },
        );
      }
    }
    return const Icon(
      Icons.medication_outlined,
      size: 28,
      color: AppColors.primary,
    );
  }
}
