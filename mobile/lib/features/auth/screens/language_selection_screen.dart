import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';
import '../../../shared/utils/localization.dart';
import '../../../shared/widgets/card.dart';

class LanguageSelectionPage extends ConsumerWidget {
  const LanguageSelectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final languages = [
      {'code': 'fr', 'label': 'Français', 'flag': '🇫🇷'},
      {'code': 'en', 'label': 'English', 'flag': '🇬🇧'},
      {'code': 'ar', 'label': 'العربية', 'flag': '🇸🇦'},
      {'code': 'tr', 'label': 'Türkçe', 'flag': '🇹🇷'},
    ];

    return Scaffold(
      body: Stack(
        children: [
          // Background soft gradient orbs (matches React CSS orbs)
          Positioned.fill(
            child: Container(
              color: isDark ? AppColors.backgroundDark : AppColors.background,
            ),
          ),
          Positioned(
            top: -128,
            right: -128,
            child: Container(
              width: 288,
              height: 288,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(isDark ? 0.05 : 0.1),
              ),
            ),
          ),
          Positioned(
            bottom: -128,
            left: -128,
            child: Container(
              width: 288,
              height: 288,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(isDark ? 0.05 : 0.05),
              ),
            ),
          ),

          // Main Screen Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Elevated Logo Container
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.cardDark : AppColors.card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? const Color(0x1AFFFFFF) : const Color(0xCCFFFFFF),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(12.0),
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.check_circle_outline,
                          color: AppColors.primary,
                          size: 48,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'MedScan',
                      style: AppTextStyles.h2(isDark: isDark),
                    ),
                    const SizedBox(height: 48),

                    // Prompt Title
                    Text(
                      ref.t('onboardingChooseLanguage'),
                      style: AppTextStyles.body(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ).copyWith(fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // 2x2 Grid of Language Cards
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.1,
                      ),
                      itemCount: languages.length,
                      itemBuilder: (context, index) {
                        final lang = languages[index];
                        return AppCard(
                          hover: true,
                          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                          onTap: () async {
                            await ref.read(languageProvider.notifier).setLanguage(lang['code']!);
                            if (context.mounted) {
                              context.go('/onboarding');
                            }
                          },
                          children: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  lang['flag']!,
                                  style: const TextStyle(fontSize: 40),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  lang['label']!,
                                  style: AppTextStyles.bodySemiBold(isDark: isDark).copyWith(fontSize: 14),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
