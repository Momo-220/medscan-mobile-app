import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';
import '../../../shared/utils/localization.dart';
import '../../../shared/utils/pill_notification.dart';
import '../../../shared/widgets/button.dart';
import '../../../shared/widgets/card.dart';
import '../providers/auth_provider.dart';

class ChooseAvatarPage extends ConsumerStatefulWidget {
  const ChooseAvatarPage({super.key});

  @override
  ConsumerState<ChooseAvatarPage> createState() => _ChooseAvatarPageState();
}

class _ChooseAvatarPageState extends ConsumerState<ChooseAvatarPage> {
  String? _selectedAvatar;

  final List<String> _avatarPaths = [
    'assets/images/avatar1.png',
    'assets/images/avatar2.png',
    'assets/images/avatar3.png',
    'assets/images/avatar5.png',
    'assets/images/avatar6.png',
    'assets/images/avatar7.png',
    'assets/images/avatar8.png',
    'assets/images/avatar9.png',
    'assets/images/avatar10.png',
    'assets/images/avatar11.png',
  ];

  bool _loading = false;

  Future<void> _handleConfirm() async {
    if (_selectedAvatar == null) return;

    setState(() {
      _loading = true;
    });

    try {
      await ref.read(authProvider.notifier).updateProfile(photoURL: _selectedAvatar);
      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      setState(() {
        _loading = false;
      });
      showPillError(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      body: Stack(
        children: [
          // Background soft gradient orbs
          Positioned(
            top: -120,
            right: -120,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(isDark ? 0.03 : 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -120,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(isDark ? 0.03 : 0.05),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    AppCard(
                      padding: const EdgeInsets.all(28.0),
                      children: Column(
                        children: [
                          // Header
                          Text(
                            ref.t('chooseAvatar'),
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Personnalise ton profil pour commencer l'aventure",
                            style: AppTextStyles.small(
                              color: isDark ? AppColors.textMutedDark : AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),

                          // Grid
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 1.0,
                            ),
                            itemCount: _avatarPaths.length,
                            itemBuilder: (context, index) {
                              final path = _avatarPaths[index];
                              final isSelected = _selectedAvatar == path;

                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedAvatar = path;
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeInOut,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primary
                                          : (isDark ? Colors.white10 : Colors.black12),
                                      width: isSelected ? 4 : 2,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: AppColors.primary.withOpacity(0.3),
                                              blurRadius: 12,
                                              spreadRadius: 2,
                                            )
                                          ]
                                        : [],
                                  ),
                                  child: ClipOval(
                                    child: Image.asset(
                                      path,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          color: isDark ? Colors.white10 : Colors.black12,
                                          child: const Icon(
                                            Icons.person,
                                            color: AppColors.primary,
                                            size: 28,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 36),

                          // Validate Button
                          Button(
                            loading: _loading,
                            disabled: _selectedAvatar == null,
                            width: double.infinity,
                            onTap: _handleConfirm,
                            child: const Text('Continuer'),
                          ),
                        ],
                      ),
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
