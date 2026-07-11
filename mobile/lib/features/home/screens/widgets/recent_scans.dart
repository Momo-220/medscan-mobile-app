import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/text_styles.dart';
import '../../../../shared/utils/localization.dart';
import '../../../../shared/widgets/card.dart';
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
          // Header of the section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                ref.t('recentScans'),
                style: AppTextStyles.h3(isDark: isDark),
              ),
              GestureDetector(
                onTap: () => context.go('/pharmacy'),
                child: Text(
                  ref.t('seeAll'),
                  style: AppTextStyles.small(color: AppColors.primary).copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          scansAsync.when(
            loading: () => _buildSkeletonList(),
            error: (err, stack) => _buildSkeletonList(), // Graceful fallback
            data: (scans) {
              if (scans.isEmpty) {
                return SizedBox(
                  width: double.infinity,
                  child: AppCard(
                    padding: const EdgeInsets.all(24),
                    children: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.history_toggle_off_outlined,
                            size: 40,
                            color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            ref.t('noRecentScans'),
                            style: AppTextStyles.small(isDark: isDark),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: scans.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final scan = scans[index];
                  final scannedDate = DateFormat.yMMMd().format(scan.scannedAt);

                  return AppCard(
                    hover: true,
                    padding: const EdgeInsets.all(12),
                    onTap: () {
                      context.push('/scan-result', extra: scan.toJson());
                    },
                    children: Row(
                      children: [
                        // Image Thumbnail with Cache support
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

                        // Scan Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                scan.medicationName,
                                style: AppTextStyles.bodyBold(isDark: isDark).copyWith(fontSize: 15),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (scan.genericName != null && scan.genericName!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  scan.genericName!,
                                  style: AppTextStyles.small(
                                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                                  ).copyWith(fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                '${ref.t('scannedAt')} $scannedDate',
                                style: AppTextStyles.micro(isDark: isDark),
                              ),
                            ],
                          ),
                        ),
                        
                        // Right Chevron action icon
                        Icon(
                          Icons.chevron_right,
                          color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                          size: 20,
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return const AppCard(
          padding: EdgeInsets.all(12),
          children: Row(
            children: [
              Skeleton(width: 60, height: 60, borderRadius: 12),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(width: 120, height: 18),
                    SizedBox(height: 6),
                    Skeleton(width: 80, height: 14),
                    SizedBox(height: 6),
                    Skeleton(width: 100, height: 10),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.black12, size: 20),
            ],
          ),
        );
      },
    );
  }
}
