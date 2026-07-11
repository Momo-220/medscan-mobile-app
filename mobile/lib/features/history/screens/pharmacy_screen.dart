import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';
import '../../../shared/utils/localization.dart';
import '../../../shared/widgets/card.dart';
import '../../../shared/widgets/input.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/button.dart';
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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: CustomInput(
                  controller: _searchController,
                  hintText: ref.t('searchMedications'),
                  icon: Icon(
                    Icons.search,
                    color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                  ),
                  onChanged: (val) {
                    ref.read(pharmacyProvider.notifier).setSearchQuery(val);
                  },
                ),
              ),

              // 1b. Stat Boxes Row
              _buildStatBoxesRow(context, pharmacyState),

              // 2. Horizontal Categories list
              if (categories.length > 1) ...[
                SizedBox(
                  height: 48,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final cat = categories[index];
                      final isSelected = pharmacyState.selectedCategory == cat;
                      final label = cat.isEmpty ? ref.t('allCategories') : cat;

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
                        ? _buildSkeletonList()
                        : pharmacyState.filteredScans.isEmpty
                            ? _buildEmptyState(isDark)
                            : _buildScansGrid(pharmacyState.filteredScans, isDark),
              ),
            ],
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
              'Historique restreint',
              style: AppTextStyles.bodyBold(isDark: isDark),
            ),
            const SizedBox(height: 8),
            Text(
              'Créez un compte pour archiver vos scans, accéder à votre pharmacie et suivre vos prises.',
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

  Widget _buildScansGrid(List<RecentScan> scans, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      itemCount: scans.length,
      itemBuilder: (context, index) {
        final scan = scans[index];
        final scannedDate = DateFormat.yMMMd().format(scan.scannedAt);
        
        final subtitleParts = <String>[];
        if (scan.dosage != null && scan.dosage!.isNotEmpty) {
          subtitleParts.add(scan.dosage!);
        }
        if (scan.form != null && scan.form!.isNotEmpty) {
          subtitleParts.add(scan.form!);
        }
        final subtitleText = subtitleParts.join(' • ');

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: AppCard(
            hover: true,
            padding: const EdgeInsets.all(16),
            onTap: () {
              context.push('/scan-result', extra: scan.toJson());
            },
            children: Row(
              children: [
                // Image Thumbnail (matching RecentScansWidget)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 60,
                    height: 60,
                    color: isDark ? const Color(0xFF1E293B) : AppColors.backgroundSecondary,
                    child: scan.imageUrl != null && scan.imageUrl!.isNotEmpty
                        ? (scan.imageUrl!.startsWith('http')
                            ? CachedNetworkImage(
                                imageUrl: scan.imageUrl!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const Skeleton(width: 60, height: 60),
                                errorWidget: (context, url, error) => const Icon(
                                  Icons.image_not_supported_outlined,
                                  size: 24,
                                  color: AppColors.primary,
                                ),
                              )
                            : Image.file(
                                File(scan.imageUrl!),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const Icon(
                                  Icons.image_not_supported_outlined,
                                  size: 24,
                                  color: AppColors.primary,
                                ),
                              ))
                        : const Icon(
                            Icons.medication_outlined,
                            size: 28,
                            color: AppColors.primary,
                          ),
                  ),
                ),
                const SizedBox(width: 16),

                // Details Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              scan.medicationName,
                              style: AppTextStyles.bodyBold(isDark: isDark).copyWith(fontSize: 16),
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
                        const SizedBox(height: 4),
                        Text(
                          subtitleText,
                          style: AppTextStyles.small(
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark 
                              ? const Color(0xFF1E3A8A).withOpacity(0.3) 
                              : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
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
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                  size: 20,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      itemCount: 4,
      itemBuilder: (context, index) {
        return const Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: AppCard(
            padding: EdgeInsets.all(16),
            children: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Skeleton(width: 120, height: 18),
                    Skeleton(width: 80, height: 14),
                  ],
                ),
                SizedBox(height: 8),
                Skeleton(width: 180, height: 14),
                SizedBox(height: 16),
                Skeleton(width: 90, height: 22, borderRadius: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatBoxesRow(BuildContext context, PharmacyState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final totalCount = state.allScans.length;
    
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final thisMonthCount = state.allScans.where((s) => s.scannedAt.isAfter(startOfMonth)).length;
    
    // Fallback: 0 to renew as shown in reference screenshots
    const toRenewCount = 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          Expanded(
            child: _buildStatBox(
              context: context,
              value: totalCount.toString(),
              label: ref.t('total'),
              icon: Icons.inventory_2_outlined,
              iconColor: const Color(0xFF3B82F6),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatBox(
              context: context,
              value: toRenewCount.toString(),
              label: ref.t('toRenew'),
              icon: Icons.warning_amber_rounded,
              iconColor: const Color(0xFFF59E0B),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatBox(
              context: context,
              value: thisMonthCount.toString(),
              label: ref.t('thisMonth'),
              icon: Icons.calendar_today_outlined,
              iconColor: const Color(0xFF10B981),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox({
    required BuildContext context,
    required String value,
    required String label,
    required IconData icon,
    required Color iconColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
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
              Text(
                value,
                style: AppTextStyles.h3(isDark: isDark).copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTextStyles.micro(isDark: isDark).copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
