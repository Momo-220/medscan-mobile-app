import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';
import '../../../core/di/providers.dart';
import '../../../shared/utils/localization.dart';
import '../../../shared/widgets/button.dart';
import '../../../shared/widgets/card.dart';
import '../providers/credits_provider.dart';
import '../providers/health_stats_provider.dart';
import '../providers/recent_scans_provider.dart';
import 'widgets/health_dashboard.dart';
import 'widgets/recent_scans.dart';
import 'widgets/medication_reminders.dart';
import 'widgets/health_tips_card.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  String _getGreeting(String tMorning, String tEvening) {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 18) {
      return tMorning;
    }
    return tEvening;
  }

  void _showCreditsDialog(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final creditsAsync = ref.watch(creditsProvider);
    final user = FirebaseAuth.instance.currentUser;
    final isAnonymous = user?.isAnonymous ?? true;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: isDark ? AppColors.cardDark : AppColors.card,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Diamond Icon
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.yellow[600]!.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(child: Text('💎', style: TextStyle(fontSize: 32))),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  ref.t('credits'),
                  style: AppTextStyles.h3(isDark: isDark),
                ),
                const SizedBox(height: 12),

                // Balance
                creditsAsync.when(
                  loading: () => const CircularProgressIndicator(),
                  error: (err, stack) => const Text('0'),
                  data: (data) => Column(
                    children: [
                      Text(
                        '${data.credits} ${ref.read(languageProvider) == 'fr' ? 'Gemmes' : (ref.read(languageProvider) == 'en' ? 'Gems' : (ref.read(languageProvider) == 'tr' ? 'Mücevher' : 'جواهر'))}',
                        style: AppTextStyles.displayHero(color: AppColors.primary),
                      ),
                      if (data.nextResetAt != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          ref.t('autoRenewMidnight'),
                          style: AppTextStyles.micro(isDark: isDark),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Action content based on Anonymous or Registered
                if (isAnonymous) ...[
                  Text(
                    ref.t('trialOrSignInTagline'),
                    style: AppTextStyles.small(isDark: isDark),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Button(
                    width: double.infinity,
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/auth');
                    },
                    child: Text(ref.t('signInOrRegister')),
                  ),
                ] else ...[
                  Text(
                    ref.t('trialGemsBenefit'),
                    style: AppTextStyles.small(isDark: isDark),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 16),

                // Close Button
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    ref.t('close'),
                    style: AppTextStyles.small(color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Auth & local name extraction
    final user = FirebaseAuth.instance.currentUser;
    final prefs = ref.watch(sharedPrefsServiceProvider);
    final String displayName = user?.displayName ?? prefs.getLocalName() ?? ref.t('user');

    final String greeting = _getGreeting(ref.t('goodMorning'), ref.t('goodEvening'));
    final creditsAsync = ref.watch(creditsProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          // Parallel pull refresh
          await Future.wait([
            ref.read(creditsProvider.notifier).fetchCredits(quietly: true),
            ref.read(healthStatsProvider.notifier).fetchStats(quietly: true),
            ref.read(recentScansProvider.notifier).fetchRecentScans(),
          ]);
        },
        color: AppColors.primary,
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Premium Header Section (User info + Gem badge)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User Info details (Left Side)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              greeting,
                              style: AppTextStyles.h1(isDark: isDark).copyWith(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () => context.push('/profile'),
                              child: Text(
                                displayName,
                                style: AppTextStyles.h2(isDark: isDark).copyWith(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF9333EA), // Purple color!
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              ref.t('howDoYouFeel'),
                              style: AppTextStyles.small(isDark: isDark).copyWith(
                                fontSize: 14,
                                color: isDark ? AppColors.textMutedDark : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Gem badge + Avatar (Right Side)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Credits Gemme Badge
                          GestureDetector(
                            onTap: () => _showCreditsDialog(context, ref),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: AppColors.gemsBadgeGradient,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.yellow[600]!.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Text('💎', style: TextStyle(fontSize: 16)),
                                  const SizedBox(width: 6),
                                  creditsAsync.when(
                                    loading: () => const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                    error: (_, __) => const Text('0'),
                                    data: (data) => Text(
                                      data.credits.toString(),
                                      style: AppTextStyles.smallBold(
                                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          
                          // Circular Avatar Frame
                          GestureDetector(
                            onTap: () => context.push('/profile'),
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: AppColors.scanButtonGradient,
                                border: Border.all(
                                  color: AppColors.primaryLight.withOpacity(0.5),
                                  width: 2,
                                ),
                              ),
                              child: ClipOval(
                                child: user?.photoURL != null && user!.photoURL!.isNotEmpty
                                    ? (user.photoURL!.startsWith('http')
                                        ? Image.network(
                                            user.photoURL!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => const Icon(
                                              Icons.person,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Image.asset(
                                            user.photoURL!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => const Icon(
                                              Icons.person,
                                              color: Colors.white,
                                            ),
                                          ))
                                    : const Icon(
                                        Icons.person,
                                        color: Colors.white,
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Next Reminder & Health Tip Cards
                const HealthTipsCardWidget(),
                const SizedBox(height: 24),

                // Health Stats Dashboard
                const HealthDashboardWidget(),
                const SizedBox(height: 32),

                // Medication Reminders List
                const MedicationRemindersWidget(),
                const SizedBox(height: 32),

                // Recent Scans List
                const RecentScansWidget(),
                
                // Bottom spacing margin for floating navigation bar
                const SizedBox(height: 120),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
