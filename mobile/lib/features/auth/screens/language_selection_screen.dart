import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../shared/utils/localization.dart';
import '../../../shared/widgets/language_dialog.dart';

class LanguageSelectionPage extends ConsumerStatefulWidget {
  const LanguageSelectionPage({super.key});

  @override
  ConsumerState<LanguageSelectionPage> createState() => _LanguageSelectionPageState();
}

class _LanguageSelectionPageState extends ConsumerState<LanguageSelectionPage> {
  String? _selectedCode;

  @override
  void initState() {
    super.initState();
    _selectedCode = ref.read(languageProvider);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentLang = _selectedCode ?? ref.watch(languageProvider);

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
                color: AppColors.primary.withValues(alpha: isDark ? 0.05 : 0.1),
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
                color: AppColors.primary.withValues(alpha: isDark ? 0.05 : 0.05),
              ),
            ),
          ),

          // Main Screen Content
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isTablet = constraints.maxWidth >= 600;
                final double maxWidth = isTablet ? 680 : 440;

                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                    child: ResponsiveContainer(
                      maxWidth: maxWidth,
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
                                  color: Colors.black.withValues(alpha: 0.06),
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
                          const SizedBox(height: 36),

                          // Prompt Title
                          Text(
                            ref.t('onboardingChooseLanguage'),
                            style: GoogleFonts.plusJakartaSans(
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontWeight: FontWeight.w700,
                              fontSize: 19,
                              letterSpacing: -0.3,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Select your preferred language / Choisissez votre langue',
                            style: GoogleFonts.plusJakartaSans(
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 28),

                          // Adaptive Grid of Language Cards
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 220,
                              mainAxisExtent: 142,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                            itemCount: kSupportedLanguages.length,
                            itemBuilder: (context, index) {
                              final lang = kSupportedLanguages[index];
                              final isSelected = currentLang == lang['code'];

                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () async {
                                    HapticFeedback.lightImpact();
                                    setState(() {
                                      _selectedCode = lang['code'];
                                    });
                                    await ref.read(languageProvider.notifier).setLanguage(lang['code']!);
                                    await Future.delayed(const Duration(milliseconds: 220));
                                    if (context.mounted) {
                                      context.go('/onboarding');
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(22),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? (isDark
                                              ? const Color(0xFF00ACC1).withValues(alpha: 0.16)
                                              : const Color(0xFFE0F7FA))
                                          : (isDark
                                              ? AppColors.cardDark
                                              : Colors.white),
                                      borderRadius: BorderRadius.circular(22),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFF26C6DA)
                                            : (isDark
                                                ? Colors.white.withValues(alpha: 0.08)
                                                : const Color(0xFFE2E8F0)),
                                        width: isSelected ? 2.0 : 1.0,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Stack(
                                      children: [
                                        Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              CircularFlagBadge(code: lang['code']!, size: 44.0),
                                              const SizedBox(height: 10),
                                              Text(
                                                lang['label']!,
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                lang['sub']!,
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isSelected)
                                          Positioned(
                                            top: 0,
                                            right: 0,
                                            child: Container(
                                              width: 20,
                                              height: 20,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF26C6DA),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Center(
                                                child: Icon(
                                                  Icons.check_rounded,
                                                  size: 13,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
