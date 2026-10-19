import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../shared/utils/localization.dart';
import '../../../shared/widgets/card.dart';
import '../../../shared/services/notification_service.dart';
import '../../../shared/utils/pill_notification.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/di/providers.dart';
import '../../../shared/widgets/language_dialog.dart';
import '../../../shared/widgets/legal_modal.dart';
import '../../chat/providers/doctor_provider.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _notificationsEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkNotificationStatus();
  }

  Future<void> _checkNotificationStatus() async {
    // Simple state detection, default true on mobile if authorized
    setState(() {
      _notificationsEnabled = true;
    });
  }

  Future<void> _handleNotificationToggle(bool value) async {
    if (value) {
      final granted = await NotificationService.requestPermissions();
      setState(() {
        _notificationsEnabled = granted;
      });
      if (!granted && mounted) {
        showPillError(context, ref.t('settingsNotificationPermissionError'));
      }
    } else {
      await NotificationService.cancelAll();
      setState(() {
        _notificationsEnabled = false;
      });
    }
  }

  void _showLanguageSelector(BuildContext context) {
    showLanguageSelectionDialog(context);
  }

  void _showHelpModal(BuildContext context, String title, String content) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: isDark ? AppColors.cardDark : AppColors.card,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.h3(isDark: isDark)),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: SingleChildScrollView(
                    child: Text(
                      content,
                      style: AppTextStyles.small(isDark: isDark).copyWith(height: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(ref.t('close')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardIcon(IconData icon) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFE0EDFF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: const Color(0xFF3B82F6), size: 22),
    );
  }

  Future<void> _handleSignOut() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.cardDark : AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(ref.t('signOut'), style: AppTextStyles.h3(isDark: isDark)),
          content: Text(
            ref.t('confirmLogout'),
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(ref.t('close'), style: const TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext); // Close dialog
                await ref.read(authProvider.notifier).signOut();
                if (!mounted) return;
                context.go('/splash'); // Redirect to splash/onboarding
              },
              child: Text(
                ref.t('logout'),
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleDeleteAccount() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.cardDark : AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(ref.t('confirmDeleteAccount'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          content: Text(
            ref.t('confirmDeleteAccountDesc'),
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(ref.t('close'), style: const TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext); // Close dialog
                try {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    final uid = user.uid;
                    try {
                      await FirebaseFirestore.instance.collection('users').doc(uid).delete();
                    } catch (fsErr) {
                      debugPrint('Error deleting user doc: $fsErr');
                    }
                    await user.delete();
                    await ref.read(authProvider.notifier).signOut();
                  }
                  if (!mounted) return;
                  showPillSuccess(context, ref.t('accountDeletedSuccess'));
                  context.go('/splash');
                } catch (e) {
                  if (!mounted) return;
                  showPillError(context, ref.t('reauthRequiredForDelete'));
                }
              },
              child: Text(
                ref.t('delete'),
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }



  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final currentLang = ref.watch(languageProvider);
    final String activeLanguageFlag = currentLang == 'fr'
        ? '🇫🇷'
        : currentLang == 'en'
            ? '🇺🇸'
            : currentLang == 'ar'
                ? '🇦🇪'
                : '🇹🇷';

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF3F8FF),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: ResponsiveContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Settings Header Title & Subtitle
              Text(
                ref.t('settingsTitle'),
                style: AppTextStyles.h1(isDark: isDark).copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 32,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                ref.t('settingsDescription'),
                style: AppTextStyles.body(isDark: isDark).copyWith(
                  fontSize: 15,
                  color: isDark ? AppColors.textMutedDark : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 28),

              // SECTION 0: Votre Médecin Référent
              _buildSectionHeader(ref.t('myDoctorAI'), isDark),
              const SizedBox(height: 10),
              AppCard(
                onTap: () => context.push('/choose-doctor'),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                children: Row(
                  children: [
                    // Doctor Avatar with prominent ring, status badge and glow
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                            border: Border.all(
                              color: Color(ref.watch(doctorProvider).accentColorValue).withValues(alpha: 0.55),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Color(ref.watch(doctorProvider).accentColorValue).withValues(alpha: isDark ? 0.35 : 0.20),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              ref.watch(doctorProvider).imagePath,
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, size: 24),
                            ),
                          ),
                        ),
                        Container(
                          width: 13,
                          height: 13,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              width: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  ref.watch(doctorProvider).name,
                                  style: AppTextStyles.bodyBold(isDark: isDark).copyWith(
                                    fontSize: 16.5,
                                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Icon(Icons.verified, color: Color(0xFF2563EB), size: 16),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            ref.t(ref.watch(doctorProvider).specialtyKey),
                            style: AppTextStyles.small(isDark: isDark).copyWith(
                              fontSize: 12.5,
                              color: isDark ? AppColors.textMutedDark : const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155).withValues(alpha: 0.6) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            ref.t('changeDoctor'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 11,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // SECTION 1: Notifications
              _buildSectionHeader(ref.t('notifications'), isDark),
              const SizedBox(height: 10),
              AppCard(
                padding: const EdgeInsets.all(20),
                children: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ref.t('medicationReminders'),
                                style: AppTextStyles.bodyBold(isDark: isDark).copyWith(
                                  fontSize: 17,
                                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                ref.t('medicationRemindersDesc'),
                                style: AppTextStyles.small(isDark: isDark).copyWith(
                                  fontSize: 13,
                                  color: isDark ? AppColors.textMutedDark : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _notificationsEnabled,
                          activeColor: Colors.white,
                          activeTrackColor: const Color(0xFF3B82F6),
                          inactiveTrackColor: const Color(0xFFE2E8F0),
                          onChanged: _handleNotificationToggle,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),



              // SECTION 3: Privacy & Security
              _buildSectionHeader(ref.t('privacy'), isDark),
              const SizedBox(height: 10),
              AppCard(
                padding: const EdgeInsets.all(20),
                children: InkWell(
                  onTap: () => context.push('/profile'),
                  borderRadius: BorderRadius.circular(20),
                  child: Row(
                    children: [
                      _buildCardIcon(Icons.shield_outlined),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ref.t('authentication'),
                              style: AppTextStyles.bodyBold(isDark: isDark).copyWith(
                                fontSize: 17,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              ref.t('secureYourAccount'),
                              style: AppTextStyles.small(isDark: isDark).copyWith(
                                fontSize: 13,
                                color: isDark ? AppColors.textMutedDark : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // SECTION 4: Appearance
              _buildSectionHeader(ref.t('appearance'), isDark),
              const SizedBox(height: 10),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                children: Column(
                  children: [
                    // Row 1: Theme choice
                    InkWell(
                      onTap: () => _showThemeSelector(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Row(
                          children: [
                            _buildCardIcon(Icons.dark_mode_outlined),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ref.t('theme'),
                                    style: AppTextStyles.bodyBold(isDark: isDark).copyWith(
                                      fontSize: 17,
                                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    ref.t('themeDesc'),
                                    style: AppTextStyles.small(isDark: isDark).copyWith(
                                      fontSize: 13,
                                      color: isDark ? AppColors.textMutedDark : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              ref.watch(themeProvider) == ThemeMode.dark
                                  ? ref.t('dark')
                                  : ref.watch(themeProvider) == ThemeMode.light
                                      ? ref.t('light')
                                      : "Système",
                              style: AppTextStyles.bodyBold(isDark: isDark).copyWith(
                                  fontSize: 16,
                                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    // Row 2: Language choice
                    InkWell(
                      onTap: () => _showLanguageSelector(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Row(
                          children: [
                            _buildCardIcon(Icons.language_outlined),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ref.t('language'),
                                    style: AppTextStyles.bodyBold(isDark: isDark).copyWith(
                                      fontSize: 17,
                                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    ref.t('languageDesc'),
                                    style: AppTextStyles.small(isDark: isDark).copyWith(
                                      fontSize: 13,
                                      color: isDark ? AppColors.textMutedDark : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              activeLanguageFlag,
                              style: const TextStyle(
                                fontSize: 22,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // SECTION 6: À propos
              _buildSectionHeader(ref.t('about'), isDark),
              const SizedBox(height: 10),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                children: Column(
                  children: [
                    // Row 1: Aide & Support
                    InkWell(
                      onTap: () => _showHelpModal(
                        context,
                        ref.t('helpSupportTitle'),
                        ref.t('helpSupportContent'),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Row(
                          children: [
                            _buildCardIcon(Icons.help_outline_rounded),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ref.t('helpSupportTitle'),
                                    style: AppTextStyles.bodyBold(isDark: isDark).copyWith(
                                      fontSize: 17,
                                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    ref.t('helpSupportDesc'),
                                    style: AppTextStyles.small(isDark: isDark).copyWith(
                                      fontSize: 13,
                                      color: isDark ? AppColors.textMutedDark : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),

                    // Row 2: À propos de l'application
                    InkWell(
                      onTap: () => _showHelpModal(
                        context,
                        ref.t('aboutTitle'),
                        ref.t('aboutContent'),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Row(
                          children: [
                            _buildCardIcon(Icons.info_outline_rounded),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ref.t('aboutTitle'),
                                    style: AppTextStyles.bodyBold(isDark: isDark).copyWith(
                                      fontSize: 17,
                                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    ref.t('about'),
                                    style: AppTextStyles.small(isDark: isDark).copyWith(
                                      fontSize: 13,
                                      color: isDark ? AppColors.textMutedDark : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),

                    // Row 3: Conditions d'utilisation
                    InkWell(
                      onTap: () => showLegalModal(
                        context,
                        title: ref.t('termsTitle'),
                        content: ref.t('termsContent'),
                        closeLabel: ref.t('close'),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Row(
                          children: [
                            _buildCardIcon(Icons.gavel_rounded),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ref.t('termsTitle'),
                                    style: AppTextStyles.bodyBold(isDark: isDark).copyWith(
                                      fontSize: 17,
                                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    ref.t('terms'),
                                    style: AppTextStyles.small(isDark: isDark).copyWith(
                                      fontSize: 13,
                                      color: isDark ? AppColors.textMutedDark : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),

                    // Row 4: Politique de confidentialité
                    InkWell(
                      onTap: () => showLegalModal(
                        context,
                        title: ref.t('privacyTitle'),
                        content: ref.t('privacyContent'),
                        closeLabel: ref.t('close'),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Row(
                          children: [
                            _buildCardIcon(Icons.privacy_tip_outlined),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ref.t('privacyTitle'),
                                    style: AppTextStyles.bodyBold(isDark: isDark).copyWith(
                                      fontSize: 17,
                                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    ref.t('privacyPolicy'),
                                    style: AppTextStyles.small(isDark: isDark).copyWith(
                                      fontSize: 13,
                                      color: isDark ? AppColors.textMutedDark : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),

                    // Row 5: Version
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Row(
                        children: [
                          _buildCardIcon(Icons.info_outline),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ref.t('version'),
                                  style: AppTextStyles.bodyBold(isDark: isDark).copyWith(
                                    fontSize: 17,
                                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  ref.t('appSubName'),
                                  style: AppTextStyles.small(isDark: isDark).copyWith(
                                    fontSize: 13,
                                    color: isDark ? AppColors.textMutedDark : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'v1.0.0',
                            style: AppTextStyles.bodyBold(isDark: isDark).copyWith(
                              fontSize: 16,
                              color: isDark ? Colors.white70 : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // SECTION 5: Account (Placé en dernier)
              _buildSectionHeader(ref.t('account'), isDark),
              const SizedBox(height: 10),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                children: Column(
                  children: [
                    // Row 2: Logout
                    InkWell(
                      onTap: _handleSignOut,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.logout_rounded, color: Color(0xFFF97316), size: 22),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ref.t('logout'),
                                    style: AppTextStyles.bodyBold(isDark: isDark).copyWith(
                                      fontSize: 17,
                                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    ref.t('logoutDesc'),
                                    style: AppTextStyles.small(isDark: isDark).copyWith(
                                      fontSize: 13,
                                      color: isDark ? AppColors.textMutedDark : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),

                    // Row 3: Delete Account
                    InkWell(
                      onTap: _handleDeleteAccount,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444), size: 22),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ref.t('deleteAccount'),
                                    style: AppTextStyles.bodyBold(isDark: isDark).copyWith(
                                      fontSize: 17,
                                      color: const Color(0xFFEF4444),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    ref.t('deleteAccountDesc'),
                                    style: AppTextStyles.small(isDark: isDark).copyWith(
                                      fontSize: 13,
                                      color: isDark ? AppColors.textMutedDark : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: AppResponsive.bottomBarSpacing(context)),
            ],
          ),
        ),
      ),
    ),
  );
  }

  void _showThemeSelector(BuildContext context) {
    final isDark = ref.read(themeProvider) == ThemeMode.dark;
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final currentMode = ref.read(themeProvider);
            return AlertDialog(
              backgroundColor: isDark ? AppColors.cardDark : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text(
                ref.t('theme'),
                style: AppTextStyles.h3(isDark: isDark).copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildThemeOption(
                    ctx,
                    setModalState,
                    icon: Icons.light_mode_outlined,
                    label: ref.t('light'),
                    mode: ThemeMode.light,
                    currentMode: currentMode,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildThemeOption(
                    ctx,
                    setModalState,
                    icon: Icons.dark_mode_outlined,
                    label: ref.t('dark'),
                    mode: ThemeMode.dark,
                    currentMode: currentMode,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildThemeOption(
                    ctx,
                    setModalState,
                    icon: Icons.brightness_auto_outlined,
                    label: 'Automatique (Système)',
                    mode: ThemeMode.system,
                    currentMode: currentMode,
                    isDark: isDark,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    ref.t('close'),
                    style: TextStyle(
                      color: isDark ? AppColors.textMutedDark : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildThemeOption(
    BuildContext ctx,
    StateSetter setModalState, {
    required IconData icon,
    required String label,
    required ThemeMode mode,
    required ThemeMode currentMode,
    required bool isDark,
  }) {
    final isSelected = currentMode == mode;
    return GestureDetector(
      onTap: () async {
        await ref.read(themeProvider.notifier).setThemeMode(mode);
        setModalState(() {});
        if (ctx.mounted) Navigator.of(ctx).pop();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF3D6B9E).withOpacity(0.3) : const Color(0xFFE0EDFF))
              : (isDark ? const Color(0xFF2A3A4D) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF3D6B9E)
                : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
            width: isSelected ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? const Color(0xFF3D6B9E)
                  : (isDark ? Colors.white54 : const Color(0xFF64748B)),
              size: 22,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyBold(isDark: isDark).copyWith(
                  fontSize: 16,
                  color: isSelected
                      ? (isDark ? Colors.white : const Color(0xFF1E293B))
                      : (isDark ? Colors.white70 : const Color(0xFF475569)),
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: Color(0xFF3D6B9E), size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String label, bool isDark) {
    return Text(
      label,
      style: AppTextStyles.bodyBold(isDark: isDark).copyWith(
        fontSize: 16,
        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
      ),
    );
  }
}


