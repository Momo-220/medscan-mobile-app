import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';
import '../../../core/di/providers.dart';
import '../../../shared/utils/localization.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  int _currentIndex = 0;

  final List<IconData> _icons = [
    Icons.qr_code_scanner_outlined,
    Icons.chat_bubble_outline,
    Icons.notifications_active_outlined,
    Icons.auto_stories_outlined,
    Icons.verified_user_outlined,
  ];

  final List<List<Color>> _slideGradients = [
    [const Color(0x223B82F6), const Color(0x2206B6D4)], // blue/cyan
    [const Color(0x228B5CF6), const Color(0x22D946EF)], // violet/fuchsia
    [const Color(0x22F97316), const Color(0x22F59E0B)], // orange/amber
    [const Color(0x2210B981), const Color(0x2214B8A6)], // emerald/teal
    [const Color(0x22F43F5E), const Color(0x22EC4899)], // rose/pink
  ];

  void _onComplete() async {
    final prefs = ref.read(sharedPrefsServiceProvider);
    await prefs.setOnboardingCompleted(true);
    if (mounted) {
      context.go('/trial-or-signin');
    }
  }

  void _nextPage() {
    if (_currentIndex == 4) {
      _onComplete();
    } else {
      setState(() {
        _currentIndex++;
      });
    }
  }

  Widget _buildRichTitle(String raw, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final parts = raw.split('|');
    
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        children: List.generate(parts.length, (index) {
          final isImpact = index % 2 == 1;
          return TextSpan(
            text: parts[index],
            style: isImpact 
                ? AppTextStyles.h2(color: AppColors.primary).copyWith(fontWeight: FontWeight.bold)
                : AppTextStyles.h2(isDark: isDark),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final screenH = MediaQuery.of(context).size.height;

    final String titleKey = 'onboardingTitle${_currentIndex + 1}';
    final String descKey = 'onboardingDesc${_currentIndex + 1}';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8F0FF),
        child: Stack(
          children: [
            // ── Background Gradient (Transitions smoothly) ────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _slideGradients[_currentIndex],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),

            // ── Skip Button (Only visible before the last slide) ──────────
            if (_currentIndex < 4)
              Positioned(
                top: topPadding + 16,
                right: 16,
                child: TextButton(
                  onPressed: _onComplete,
                  child: Text(
                    ref.t('onboardingSkip'),
                    style: AppTextStyles.body(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ).copyWith(fontSize: 14),
                  ),
                ),
              ),

            // ── Main Slide Content ────────────────────────────────────────
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.96, end: 1.0).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Stack(
                  key: ValueKey<int>(_currentIndex),
                  children: [
                    // Centered Icon Card
                    Positioned(
                      top: topPadding + screenH * 0.20,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Glow background blur
                            Container(
                              width: 170,
                              height: 170,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    _slideGradients[_currentIndex][0].withOpacity(0.8),
                                    _slideGradients[_currentIndex][1].withOpacity(0.5),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                            // White icon box
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E293B).withOpacity(0.9)
                                    : Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Icon(
                                _icons[_currentIndex],
                                color: AppColors.primary,
                                size: 56,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Text Details
                    Positioned(
                      top: topPadding + screenH * 0.20 + 155,
                      left: 32,
                      right: 32,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _buildRichTitle(ref.t(titleKey), context),
                          const SizedBox(height: 16),
                          Text(
                            ref.t(descKey),
                            style: AppTextStyles.body(
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                            ).copyWith(fontSize: 15, height: 1.5),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Bottom Section: Dots and Action CTA ───────────────────────
            Positioned(
              left: 24,
              right: 24,
              bottom: bottomPadding + 32,
              child: Column(
                children: [
                  // Pagination Indicator Dots (5 total)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final isSelected = index == _currentIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4.0),
                        height: 10,
                        width: isSelected ? 32 : 10,
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? AppColors.primary 
                              : (isDark ? Colors.white24 : Colors.black12),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 32),

                  // Action Button
                  GestureDetector(
                    onTap: _nextPage,
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: AppColors.scanButtonGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentIndex == 4
                                ? ref.t('onboardingGetStarted')
                                : ref.t('onboardingNext'),
                            style: AppTextStyles.bodyBold(isDark: false).copyWith(color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _currentIndex == 4 
                                ? Icons.arrow_forward 
                                : Icons.chevron_right,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
