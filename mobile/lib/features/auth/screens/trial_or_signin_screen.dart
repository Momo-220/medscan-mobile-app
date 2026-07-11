import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';
import '../../../core/di/providers.dart';
import '../../../shared/utils/localization.dart';
import '../../../shared/widgets/button.dart';

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

      final prefs = ref.read(sharedPrefsServiceProvider);
      final secureStorage = ref.read(secureStorageServiceProvider);
      final client = ref.read(apiClientProvider);
      final deviceId = prefs.getDeviceId();

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
                const SizedBox(height: 32),

                // Error Message Box
                if (_error != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _error!,
                      style: AppTextStyles.small(
                        color: isDark ? Colors.amber[200] : Colors.amber[900],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Try App CTA Button
                Button(
                  loading: _loading,
                  width: double.infinity,
                  onTap: _handleTryApp,
                  child: Text(ref.t('tryApp')),
                ),
                const SizedBox(height: 24),

                // Sign In / Register Link Button
                TextButton(
                  onPressed: () => context.go('/auth'),
                  child: Text(
                    ref.t('signInOrRegister'),
                    style: AppTextStyles.small(
                      color: isDark ? AppColors.textMutedDark : AppColors.textSecondary,
                    ).copyWith(
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
