import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../core/di/providers.dart';
import '../../../shared/services/version_service.dart';
import '../../../shared/services/widget_service.dart';
import '../../../shared/services/username_service.dart';
import '../../../shared/widgets/version_update_dialog.dart';
import '../../../shared/utils/localization.dart';
import '../../../shared/widgets/button.dart';
import '../../../data/models/credits.dart';
import '../providers/credits_provider.dart';
import '../providers/health_stats_provider.dart';
import '../providers/recent_scans_provider.dart';
import '../../reminders/providers/reminders_provider.dart';
import '../../chat/providers/doctor_provider.dart';
import 'widgets/animated_gem_badge.dart';
import 'widgets/health_dashboard.dart';
import 'widgets/new_medication_scan_card.dart';
import 'widgets/next_reminder_section.dart';
import 'widgets/recent_scans.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  static bool _hasShownVersionDialog = false;
  static String? _lastSyncedKey;

  late final ScrollController _scrollController;
  final ValueNotifier<double> _scrollOffset = ValueNotifier<double>(0.0);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      _scrollOffset.value = _scrollController.hasClients ? _scrollController.offset : 0.0;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _scrollOffset.dispose();
    super.dispose();
  }

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
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
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
                          '${data.credits} ${ref.t('gems')}',
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

                  // Sign-up / Upgrade prompt if anonymous
                  if (isAnonymous) ...[
                    Button(
                      width: double.infinity,
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/auth');
                      },
                      child: Text(ref.t('signUpToKeepGems')),
                    ),
                    const SizedBox(height: 12),
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
          ),
        );
      },
    );
  }

  void _handleVersionStatus(BuildContext context, AppVersionStatus status) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      if (status is MaintenanceStatus) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => MaintenanceDialog(message: status.message),
        );
      } else if (status is UpdateRequiredStatus) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => VersionUpdateDialog(
            config: status.config,
            isForceUpdate: true,
          ),
        );
      } else if (status is UpdateAvailableStatus) {
        if (_hasShownVersionDialog) return;
        _hasShownVersionDialog = true;
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (context) => VersionUpdateDialog(
            config: status.config,
            isForceUpdate: false,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Listen to remote version checking status
    ref.listen<AsyncValue<AppVersionStatus>>(versionCheckProvider, (previous, next) {
      next.whenOrNull(
        data: (status) => _handleVersionStatus(context, status),
      );
    });

    final versionAsync = ref.watch(versionCheckProvider);
    versionAsync.whenOrNull(
      data: (status) => _handleVersionStatus(context, status),
    );

    // Auth & local name / username extraction
    final user = FirebaseAuth.instance.currentUser;
    final prefs = ref.watch(sharedPrefsServiceProvider);
    final localAvatar = prefs.getLocalAvatar();
    final String activeAvatar = (user?.photoURL != null && user!.photoURL!.isNotEmpty)
        ? user.photoURL!
        : (localAvatar ?? '');
    final localUsername = prefs.getLocalUsername();
    final String greetingName = (localUsername != null && localUsername.isNotEmpty)
        ? (localUsername.startsWith('@') ? localUsername : '@$localUsername')
        : (user?.displayName ?? prefs.getLocalName() ?? ref.t('user'));

    final syncKey = '$greetingName-$activeAvatar-${user?.uid}';
    if (_lastSyncedKey != syncKey) {
      _lastSyncedKey = syncKey;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final remindersList = ref.read(remindersProvider).value;
        WidgetService.syncWidget(
          reminders: remindersList,
          userName: greetingName,
          avatarId: WidgetService.extractAvatarId(activeAvatar),
          langCode: ref.read(languageProvider),
        );

        if ((prefs.getLocalUsername() == null || prefs.getLocalUsername()!.isEmpty) &&
            user != null &&
            !user.isAnonymous) {
          final fetched = await UsernameService().lookupUsernameByUid(user.uid);
          if (fetched != null && fetched.isNotEmpty) {
            await prefs.setLocalUsername(fetched);
          }
        }
      });
    }

    final String greeting = _getGreeting(ref.t('goodMorning'), ref.t('goodEvening'));
    final creditsAsync = ref.watch(creditsProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF1F6FB),
      body: Column(
        children: [
          // 1. FIXED HEADER (Always pinned at top on all devices, GPU layer isolated)
          RepaintBoundary(
            child: _buildHeader(
              context: context,
              ref: ref,
              isDark: isDark,
              greeting: greeting,
              greetingName: greetingName,
              activeAvatar: activeAvatar,
              creditsAsync: creditsAsync,
            ),
          ),

          // 2. SCROLLABLE BODY (Cinematic smooth gradient fade out on scroll)
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await Future.wait([
                  ref.read(creditsProvider.notifier).fetchCredits(quietly: true),
                  ref.read(healthStatsProvider.notifier).fetchStats(quietly: true),
                  ref.read(recentScansProvider.notifier).fetchRecentScans(),
                ]);
              },
              color: const Color(0xFF2563EB),
              child: ValueListenableBuilder<double>(
                valueListenable: _scrollOffset,
                builder: (context, offset, child) {
                  // Cinematic film dissolve: smooth gradient fade at top of scrolling body
                  final double fadeStop = (offset / 32.0).clamp(0.0, 1.0) * 0.048;
                  if (fadeStop <= 0.001) {
                    return child!;
                  }
                  return ShaderMask(
                    shaderCallback: (Rect bounds) {
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
                    child: child,
                  );
                },
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  child: ResponsiveContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 14),

                        // 2b. QUICK SCAN PROMPT ("Un nouveau médicament ?")
                        const NewMedicationScanCard(),

                        const SizedBox(height: 14),

                        // 3. HEALTH DASHBOARD (1 Tall card left + 2 stacked cards right)
                        const HealthDashboardWidget(),

                        const SizedBox(height: 14),

                        // 4. NEXT REMINDER (Dedicated Section below dashboard)
                        const NextReminderSectionWidget(),

                        const SizedBox(height: 4), // Tight spacing above Recent Scans!

                        // 5. RECENT SCANS (2-Column Grid)
                        const RecentScansWidget(),

                        // Bottom spacing margin for floating navigation bar
                        SizedBox(height: AppResponsive.bottomBarSpacing(context) + 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader({
    required BuildContext context,
    required WidgetRef ref,
    required bool isDark,
    required String greeting,
    required String greetingName,
    required String activeAvatar,
    required AsyncValue<Credits> creditsAsync,
  }) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final double doctorWidth = (screenWidth * 0.42).clamp(130.0, 195.0);
    final double doctorHeight = doctorWidth * 1.11;

    return Container(
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
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 1. Doctor Portrait (Dynamic AI Doctor) - Adaptive responsive size
              Positioned(
                top: topPadding + 4,
                right: 0,
                width: doctorWidth,
                height: doctorHeight,
                child: GestureDetector(
                  onTap: () => context.go('/chat'),
                  behavior: HitTestBehavior.opaque,
                  child: ShaderMask(
                    shaderCallback: (rect) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black, Colors.black, Colors.transparent],
                        stops: [0.0, 0.88, 1.0],
                      ).createShader(rect);
                    },
                    blendMode: BlendMode.dstIn,
                    child: Image.asset(
                      ref.watch(doctorProvider).imagePath,
                      fit: BoxFit.contain,
                      alignment: Alignment.topRight,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),

          // 2. Foreground Elements
          Padding(
            padding: EdgeInsets.only(
              top: topPadding + (screenHeight < 700 ? 6 : 8),
              left: 20,
              right: 20,
              bottom: screenHeight < 700 ? 12 : 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Avatar & Greeting (Left) + Compact Gem Badge (Right)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar & Greeting
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.push('/profile'),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? Colors.white.withOpacity(0.2) : Colors.white,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF1A3B5D).withOpacity(0.08),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: activeAvatar.isNotEmpty
                                  ? (activeAvatar.startsWith('http')
                                      ? Image.network(
                                          activeAvatar,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white),
                                        )
                                      : Image.asset(
                                          activeAvatar,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white),
                                        ))
                                  : const Icon(Icons.person, color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              greeting,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isDark ? AppColors.textMutedDark : const Color(0xFF64748B),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => context.push('/profile'),
                              child: Text(
                                greetingName,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF8B5CF6), // Iconic Purple!
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Top-Right: Animated Gem Badge (shows count, then smoothly folds to circle with blue ring)
                    AnimatedGemBadge(
                      key: const ValueKey('home_gem_badge'),
                      credits: creditsAsync.asData?.value.credits ?? 0,
                      onTap: () => _showCreditsDialog(context, ref),
                    ),
                  ],
                ),

                SizedBox(height: screenHeight < 700 ? 10 : 14),

                // Display Title "How do you feel?" - Adaptive width & responsive font
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: (screenWidth - doctorWidth - 36).clamp(135.0, 240.0)),
                  child: Text(
                    ref.t('howDoYouFeel'),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: screenWidth < 360 ? 21 : 24,
                      fontWeight: FontWeight.w800,
                      height: 1.22,
                      letterSpacing: -0.5,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),

                SizedBox(height: screenHeight < 700 ? 12 : 16),

                // Sleek Frosted Glass AI Pill Bar with blur
                GestureDetector(
                  onTap: () => context.go('/chat'),
                  behavior: HitTestBehavior.opaque,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        width: double.infinity,
                        height: 48,
                        padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
                        decoration: BoxDecoration(
                          color: (isDark ? const Color(0xFF1E293B) : Colors.white).withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.15)
                                : Colors.white.withValues(alpha: 0.8),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.auto_awesome,
                              color: Color(0xFFF59E0B),
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                ref.watch(doctorProvider).id == 'dr_sarah'
                                    ? '${ref.t('askDrSarah')}...'
                                    : 'Poser une question à ${ref.watch(doctorProvider).shortName}...',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -0.2,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Small circular action button beside it
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF334155) : Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.12)
                                      : const Color(0xFFE2E8F0),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 18,
                                  color: isDark ? Colors.white : const Color(0xFF2563EB),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
);
  }
}

