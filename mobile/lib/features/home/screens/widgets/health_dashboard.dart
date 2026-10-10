import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/text_styles.dart';
import '../../../../shared/utils/localization.dart';
import '../../../../shared/widgets/card.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../providers/health_stats_provider.dart';

class HealthDashboardWidget extends ConsumerWidget {
  const HealthDashboardWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(healthStatsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        // Dynamically compute columns and height based on allocated space:
        // >= 640px: 4 columns in one sleek horizontal row
        // 330px - 639px: 2 columns in a modern 2x2 grid
        // < 330px: 1 column with horizontal row layout for ultra-compact devices
        final int crossAxisCount = availableWidth >= 640 ? 4 : (availableWidth >= 330 ? 2 : 1);
        final bool isHorizontal = crossAxisCount == 1;
        final double cardHeight = isHorizontal ? 84.0 : 156.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                ref.t('healthDashboard'),
                style: AppTextStyles.h3(isDark: isDark),
              ),
            ),
            const SizedBox(height: 16),
            statsAsync.when(
              loading: () => _buildSkeletonLoader(crossAxisCount, cardHeight, isHorizontal),
              error: (err, stack) => _buildSkeletonLoader(crossAxisCount, cardHeight, isHorizontal),
              data: (stats) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 4,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent: cardHeight,
                    ),
                    itemBuilder: (context, index) {
                      switch (index) {
                        case 0:
                          return _buildStatCard(
                            context: context,
                            icon: Icons.analytics_outlined,
                            iconBg: AppColors.primary,
                            value: stats.scansThisWeek.toString(),
                            label: ref.t('scansThisWeek'),
                            isHorizontal: isHorizontal,
                            footer: stats.scansThisWeek > 0
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.trending_up, color: Colors.green, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        ref.t('active'),
                                        style: AppTextStyles.micro().copyWith(color: Colors.green, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  )
                                : null,
                          );
                        case 1:
                          return _buildStatCard(
                            context: context,
                            icon: Icons.local_pharmacy_outlined,
                            iconBg: const Color(0xFF3B82F6),
                            value: stats.medicationsTaken.toString(),
                            label: ref.t('medicationsTaken'),
                            isHorizontal: isHorizontal,
                            footer: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle_outline, color: Colors.green, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  ref.t('upToDate'),
                                  style: AppTextStyles.micro().copyWith(color: Colors.green, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          );
                        case 2:
                          return _buildStatCard(
                            context: context,
                            icon: Icons.favorite_border,
                            iconBg: const Color(0xFF10B981),
                            value: '${stats.adherenceRate}%',
                            label: ref.t('adherenceRate'),
                            isHorizontal: isHorizontal,
                            footer: isHorizontal
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.favorite, color: Color(0xFF10B981), size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        ref.t('excellent'),
                                        style: AppTextStyles.micro().copyWith(color: const Color(0xFF10B981), fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  )
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: Container(
                                          height: 6,
                                          width: double.infinity,
                                          color: isDark ? Colors.white12 : Colors.black12,
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: FractionallySizedBox(
                                              widthFactor: (stats.adherenceRate / 100.0).clamp(0.0, 1.0),
                                              child: Container(
                                                color: const Color(0xFF10B981),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          );
                        case 3:
                        default:
                          return _buildStatCard(
                            context: context,
                            icon: Icons.alarm,
                            iconBg: const Color(0xFFF97316),
                            value: stats.nextReminderTime == 'late' || stats.nextReminderTime == 'En retard'
                                ? ref.t('late')
                                : (stats.nextReminderTime ?? '--:--'),
                            label: stats.nextReminder ?? ref.t('nextReminder'),
                            isHorizontal: isHorizontal,
                            footer: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.hourglass_empty, color: Color(0xFFF97316), size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  '${stats.pendingReminders} ${ref.t('pending')}',
                                  style: AppTextStyles.micro().copyWith(color: const Color(0xFFF97316), fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          );
                      }
                    },
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildSkeletonLoader(int count, double cardHeight, bool isHorizontal) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: count,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: cardHeight,
        ),
        itemBuilder: (context, index) {
          if (isHorizontal) {
            return const AppCard(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              children: Row(
                children: [
                  Skeleton(width: 44, height: 44, borderRadius: 14),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Skeleton(width: 60, height: 20),
                        SizedBox(height: 4),
                        Skeleton(width: 110, height: 12),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return const AppCard(
            padding: EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
            children: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Skeleton(width: 36, height: 36, borderRadius: 10),
                SizedBox(height: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(width: 50, height: 20),
                    SizedBox(height: 4),
                    Skeleton(width: 90, height: 12),
                  ],
                ),
                SizedBox(height: 6),
                Skeleton(width: 70, height: 14),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard({
    required BuildContext context,
    required IconData icon,
    required Color iconBg,
    required String value,
    required String label,
    Widget? footer,
    bool isHorizontal = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isHorizontal) {
      return AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        children: Row(
          children: [
            // Icon Box
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconBg, size: 22),
            ),
            const SizedBox(width: 14),

            // Value and Label Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value,
                    style: AppTextStyles.h3(isDark: isDark).copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: AppTextStyles.small(isDark: isDark).copyWith(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Footer Badge / Progress Bar
            ?footer,
          ],
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
      children: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Icon Box
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconBg, size: 18),
          ),
          const SizedBox(height: 6),

          // Value and Label Text
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: AppTextStyles.h3(isDark: isDark).copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTextStyles.micro(isDark: isDark).copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Footer Badge / Progress Bar
          SizedBox(
            height: 20,
            child: Align(
              alignment: Alignment.centerLeft,
              child: footer ?? const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}
