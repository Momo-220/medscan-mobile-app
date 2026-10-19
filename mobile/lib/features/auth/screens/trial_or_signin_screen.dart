import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../core/di/providers.dart';
import '../../../shared/utils/localization.dart';
import '../../../shared/widgets/button.dart';
import '../../../shared/widgets/legal_modal.dart';

import '../providers/auth_provider.dart';

class TrialOrSignInPage extends ConsumerStatefulWidget {
  const TrialOrSignInPage({super.key});

  @override
  ConsumerState<TrialOrSignInPage> createState() => _TrialOrSignInPageState();
}

class _TrialOrSignInPageState extends ConsumerState<TrialOrSignInPage> {
  String? _error;
  bool _loading = false;

  Future<void> _handleTryApp() async {
    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      // 0. Crucial: Clean up any previous Firebase or local auth sessions first
      await ref.read(authProvider.notifier).signOut();

      final secureStorage = ref.read(secureStorageServiceProvider);
      final client = ref.read(apiClientProvider);

      // Use the secure device ID (stored in Keychain/EncryptedSharedPrefs)
      // to prevent easy bypass of trial limits on rooted devices
      final deviceId = await secureStorage.getSecureDeviceId();

      // 1. Request a trial token from the backend (checks eligibility + registers device)
      final tokenResponse = await client.post('/trial/token', data: {'device_id': deviceId});
      final String? trialToken = tokenResponse.data['token'];

      if (trialToken == null || trialToken.isEmpty) {
        setState(() {
          _error = ref.t('trialNotAvailable');
          _loading = false;
        });
        return;
      }

      // 2. Save the trial JWT to secure storage (ApiClient will use it for requests)
      await secureStorage.setAuthToken(trialToken);

      // 3. Navigate to AskNamePage
      if (mounted) {
        context.go('/ask-name');
      }
    } catch (e, stack) {
      debugPrint('🚨 ERROR IN TRIAL SIGN-IN: $e\n$stack');
      // Check if it's a "trial already used" error
      final errorMsg = e.toString();
      if (errorMsg.contains('trial_already_used') || errorMsg.contains('403')) {
        setState(() {
          _error = ref.t('trialNotAvailable');
          _loading = false;
        });
      } else {
        setState(() {
          _error = ref.t('trialNotAvailable');
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
            child: ResponsiveContainer(
              maxWidth: 480,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logo inside modern card frame
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.all(16.0),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.check_circle_outline,
                      color: AppColors.primary,
                      size: 64,
                    ),
                  ),
                ),
                const SizedBox(height: 48),

                // Title
                Text(
                  ref.t('trialOrSignInTitle'),
                  style: AppTextStyles.h2(isDark: isDark).copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Tagline
                Text(
                  ref.t('trialOrSignInTagline'),
                  style: AppTextStyles.body(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ).copyWith(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),

                // Error Message Box
                if (_error != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _error!,
                            style: AppTextStyles.small(
                              color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Sign Up Button
                Button(
                  width: double.infinity,
                  onTap: () => context.go('/auth', extra: {'isLogin': false}),
                  child: Text(ref.t('authRegister')),
                ),
                const SizedBox(height: 16),

                // Login Button
                Button(
                  width: double.infinity,
                  variant: ButtonVariant.secondary,
                  onTap: () => context.go('/auth', extra: {'isLogin': true}),
                  child: Text(ref.t('authLogin')),
                ),
                const SizedBox(height: 24),

                // Try App Link Button
                TextButton(
                  onPressed: _loading ? null : _handleTryApp,
                  child: _loading 
                    ? const SizedBox(
                        width: 16, height: 16, 
                        child: CircularProgressIndicator(strokeWidth: 2)
                      )
                    : Text(
                        ref.t('tryApp'),
                        style: AppTextStyles.small(
                          color: isDark ? AppColors.textMutedDark : AppColors.textSecondary,
                        ).copyWith(
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                ),

                const SizedBox(height: 24),

                // Informative Legal Notice
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${ref.t('authTermsNotice')} ',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: isDark ? AppColors.textMutedDark : const Color(0xFF64748B),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => showLegalModal(
                          context,
                          title: ref.t('termsTitle'),
                          content: ref.t('termsContent'),
                          closeLabel: ref.t('close'),
                        ),
                        child: Text(
                          ref.t('terms'),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2563EB),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      Text(
                        ' ${ref.t('andOur')} ',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: isDark ? AppColors.textMutedDark : const Color(0xFF64748B),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => showLegalModal(
                          context,
                          title: ref.t('privacyTitle'),
                          content: ref.t('privacyContent'),
                          closeLabel: ref.t('close'),
                        ),
                        child: Text(
                          ref.t('privacyPolicy'),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2563EB),
                            decoration: TextDecoration.underline,
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
      ),
    ),
  );
  }
}
