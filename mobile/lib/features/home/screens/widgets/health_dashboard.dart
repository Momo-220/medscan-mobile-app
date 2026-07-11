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
    final width = MediaQuery.of(context).size.width;

    // Calculate cross axis count based on screen width
    final int crossAxisCount = width > 900 ? 4 : (width > 600 ? 2 : 1);
    final double childAspectRatio = width > 900 ? 1.3 : (width > 600 ? 1.3 : 3.8);

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
          loading: () => _buildSkeletonLoader(crossAxisCount, childAspectRatio),
          error: (err, stack) => _buildSkeletonLoader(crossAxisCount, childAspectRatio), // Graceful fallback
          data: (stats) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: childAspectRatio,
                children: [
                  // Card 1: Scans
                  _buildStatCard(
                    context: context,
                    icon: Icons.analytics_outlined,
                    iconBg: AppColors.primary,
                    value: stats.scansThisWeek.toString(),
                    label: ref.t('scansThisWeek'),
                    isHorizontal: crossAxisCount == 1,
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
                  ),

                  // Card 2: Medications Taken
                  _buildStatCard(
                    context: context,
                    icon: Icons.local_pharmacy_outlined,
                    iconBg: const Color(0xFF3B82F6),
                    value: stats.medicationsTaken.toString(),
                    label: ref.t('medicationsTaken'),
                    isHorizontal: crossAxisCount == 1,
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
                  ),

                  // Card 3: Adherence Rate
                  _buildStatCard(
                    context: context,
                    icon: Icons.favorite_border,
                    iconBg: const Color(0xFF10B981),
                    value: '${stats.adherenceRate}%',
                    label: ref.t('adherenceRate'),
                    isHorizontal: crossAxisCount == 1,
                    footer: crossAxisCount == 1
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
                                      widthFactor: stats.adherenceRate / 100.0,
                                      child: Container(
                                        color: const Color(0xFF10B981),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),

                  // Card 4: Next Reminder
                  _buildStatCard(
                    context: context,
                    icon: Icons.alarm,
                    iconBg: const Color(0xFFF97316),
                    value: stats.nextReminderTime == 'late' || stats.nextReminderTime == 'En retard'
                        ? ref.t('late')
                        : (stats.nextReminderTime ?? '--:--'),
                    label: stats.nextReminder ?? ref.t('nextReminder'),
                    isHorizontal: crossAxisCount == 1,
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
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }


  Widget _buildSkeletonLoader(int count, double ratio) {
    final isHorizontal = count == 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: count,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: ratio,
        children: List.generate(4, (index) {
          if (isHorizontal) {
            return const AppCard(
              padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              children: Row(
                children: [
                  Skeleton(width: 48, height: 48, borderRadius: 16),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Skeleton(width: 60, height: 24),
                        SizedBox(height: 4),
                        Skeleton(width: 120, height: 14),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return const AppCard(
            padding: EdgeInsets.all(16.0),
            children: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Skeleton(width: 40, height: 40, borderRadius: 12),
                SizedBox(height: 8),
                Skeleton(width: 60, height: 24),
                SizedBox(height: 4),
                Skeleton(width: 100, height: 14),
              ],
            ),
          );
        }),
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
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        children: Row(
          children: [
            // Icon Box
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBg.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconBg, size: 24),
            ),
            const SizedBox(width: 16),

            // Value and Label Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value,
                    style: AppTextStyles.h3(isDark: isDark).copyWith(
                      fontSize: 24,
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
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Footer Badge / Progress Bar
            if (footer != null) footer,
          ],
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(16.0),
      children: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Icon Box
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconBg, size: 20),
          ),
          const SizedBox(height: 8),

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
                  style: AppTextStyles.micro(isDark: isDark).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Footer Badge / Progress Bar
          if (footer != null) footer,
        ],
      ),
    );
  }
}
