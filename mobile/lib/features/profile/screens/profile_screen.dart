import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';
import '../../../core/di/providers.dart';
import '../../../shared/utils/localization.dart';
import '../../../shared/widgets/button.dart';
import '../../../shared/widgets/card.dart';
import '../../../shared/widgets/input.dart';
import '../../auth/providers/auth_provider.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final TextEditingController _nameController = TextEditingController();
  bool _saving = false;

  final List<String> _avatarPaths = [
    'assets/images/avatar1.png',
    'assets/images/avatar2.png',
    'assets/images/avatar3.png',
    'EMPTY', // placeholder for avatar4 which is missing
    'assets/images/avatar5.png',
    'assets/images/avatar6.png',
    'assets/images/avatar7.png',
    'assets/images/avatar8.png',
    'assets/images/avatar9.png',
    'assets/images/avatar10.png',
    'assets/images/avatar11.png',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = FirebaseAuth.instance.currentUser;
      final prefs = ref.read(sharedPrefsServiceProvider);
      _nameController.text = user?.displayName ?? prefs.getLocalName() ?? '';
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _showEditNameDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;
    _nameController.text = user?.displayName ?? '';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.cardDark : AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            ref.t('fullName'),
            style: AppTextStyles.h3(isDark: isDark),
          ),
          content: CustomInput(
            controller: _nameController,
            hintText: ref.t('fullName'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(ref.t('close'), style: AppTextStyles.small(color: AppColors.textMuted)),
            ),
            TextButton(
              onPressed: () async {
                final newName = _nameController.text.trim();
                if (newName.isNotEmpty) {
                  Navigator.pop(context);
                  if (mounted) {
                    setState(() {
                      _saving = true;
                    });
                  }
                  try {
                    await ref.read(authProvider.notifier).updateProfile(displayName: newName);
                    final prefs = ref.read(sharedPrefsServiceProvider);
                    await prefs.setLocalName(newName);
                  } catch (_) {}
                  if (mounted) {
                    setState(() {
                      _saving = false;
                    });
                  }
                }
              },
              child: Text(
                ref.t('confirm'),
                style: AppTextStyles.smallBold().copyWith(color: AppColors.primary),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAvatarSelectorDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Les avatars ne sont pas disponibles en mode d'essai. Inscrivez-vous !",
            style: AppTextStyles.smallBold(isDark: false).copyWith(color: Colors.white),
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    String activeAvatar = user.photoURL ?? '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              backgroundColor: isDark ? AppColors.cardDark : AppColors.card,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ref.t('chooseAvatar'),
                      style: AppTextStyles.h3(isDark: isDark).copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    // Grid of 3x4 avatars
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _avatarPaths.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemBuilder: (context, index) {
                        final path = _avatarPaths[index];
                        if (path == 'EMPTY') {
                          return const SizedBox();
                        }

                        final isSelected = activeAvatar == path;

                        return GestureDetector(
                          onTap: () {
                            setModalState(() {
                              activeAvatar = path;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? AppColors.primary : Colors.transparent,
                                width: 3.5,
                              ),
                            ),
                            padding: const EdgeInsets.all(2),
                            child: ClipOval(
                              child: Image.asset(path, fit: BoxFit.cover),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              side: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFE2E8F0)),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              ref.t('back'),
                              style: AppTextStyles.smallBold(isDark: isDark).copyWith(
                                color: isDark ? Colors.white70 : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            onPressed: () async {
                              Navigator.pop(context);
                              if (activeAvatar.isNotEmpty) {
                                if (mounted) {
                                  setState(() {
                                    _saving = true;
                                  });
                                }
                                try {
                                  await ref.read(authProvider.notifier).updateProfile(photoURL: activeAvatar);
                                } catch (_) {}
                                if (mounted) {
                                  setState(() {
                                    _saving = false;
                                  });
                                }
                              }
                            },
                            child: Text(
                              ref.t('confirm'),
                              style: AppTextStyles.smallBold(isDark: false).copyWith(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleSignOut() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.cardDark : AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(ref.t('signOut'), style: AppTextStyles.h3(isDark: isDark)),
          content: Text(
            'Êtes-vous sûr de vouloir vous déconnecter ?',
            style: AppTextStyles.small(isDark: isDark),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(ref.t('close'), style: AppTextStyles.small(color: AppColors.textMuted)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context); // Close dialog
                await ref.read(authProvider.notifier).signOut();
                if (mounted) {
                  context.go('/splash'); // Go back to splash / onboarding
                }
              },
              child: Text(
                ref.t('signOut'),
                style: AppTextStyles.smallBold().copyWith(color: Colors.red[600]),
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
    final user = FirebaseAuth.instance.currentUser;
    final isTrial = user == null;
    final isAnonymous = isTrial || user.isAnonymous;

    final prefs = ref.watch(sharedPrefsServiceProvider);
    final displayName = isTrial 
        ? (prefs.getLocalName() ?? 'Essai') 
        : (user?.displayName ?? 'Utilisateur');
    final userEmail = isTrial 
        ? 'Mode Essai' 
        : (user?.email ?? 'Compte anonyme');

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 80,
        leading: InkWell(
          onTap: () => context.pop(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 8),
              Icon(Icons.arrow_back_ios_new, size: 16, color: isDark ? Colors.white : AppColors.textPrimary),
              const SizedBox(width: 4),
              Text(
                ref.t('back'),
                style: AppTextStyles.body(isDark: isDark).copyWith(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Page Title & Subtitle (Turkish format)
              Text(
                ref.t('myProfile'),
                style: AppTextStyles.h2(isDark: isDark).copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                ref.t('managePersonalInfo'),
                style: AppTextStyles.small(
                  color: isDark ? AppColors.textMutedDark : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // 2. Avatar welcome Card
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                children: Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () => _showAvatarSelectorDialog(context),
                        child: Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE),
                                  width: 3.5,
                                ),
                              ),
                              child: ClipOval(
                                child: user?.photoURL != null && user!.photoURL!.isNotEmpty
                                    ? (user.photoURL!.startsWith('http')
                                        ? Image.network(user.photoURL!, fit: BoxFit.cover)
                                        : Image.asset(user.photoURL!, fit: BoxFit.cover))
                                    : const Icon(Icons.person, color: AppColors.primary, size: 56),
                              ),
                            ),
                            if (!isTrial)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 15,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (!isTrial) ...[
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () => _showAvatarSelectorDialog(context),
                          child: Text(
                            ref.t('changeAvatar'),
                            style: AppTextStyles.smallBold(isDark: isDark).copyWith(
                              color: AppColors.primary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        displayName,
                        style: AppTextStyles.h3(isDark: isDark).copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF3B82F6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 3. Personal Info Box
              Text(
                ref.t('personalInfo'),
                style: AppTextStyles.bodyBold(isDark: isDark).copyWith(fontSize: 16),
              ),
              const SizedBox(height: 8),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                children: Column(
                  children: [
                    // Full name row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E3A8A).withOpacity(0.2) : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.person_outline, color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ref.t('fullName'),
                                style: AppTextStyles.micro(isDark: isDark).copyWith(
                                  color: isDark ? AppColors.textMutedDark : AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                displayName,
                                style: AppTextStyles.smallBold(isDark: isDark),
                              ),
                            ],
                          ),
                        ),
                        if (!isTrial)
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                            onPressed: () => _showEditNameDialog(context),
                          ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Divider(height: 1, color: Colors.white10),
                    ),
                    // Email row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E3A8A).withOpacity(0.2) : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.mail_outline, color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ref.t('email'),
                                style: AppTextStyles.micro(isDark: isDark).copyWith(
                                  color: isDark ? AppColors.textMutedDark : AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                userEmail,
                                style: AppTextStyles.smallBold(isDark: isDark),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 4. Settings Card Shortcut
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                onTap: () => context.push('/settings'),
                hover: true,
                children: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E3A8A).withOpacity(0.2) : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.shield_outlined, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ref.t('settingsTitle'),
                            style: AppTextStyles.smallBold(isDark: isDark),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Notifications, confidentialité, etc.',
                            style: AppTextStyles.micro(isDark: isDark).copyWith(
                              color: isDark ? AppColors.textMutedDark : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: isDark ? AppColors.textMutedDark : AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // 5. Logout Button
              GestureDetector(
                onTap: _handleSignOut,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.redAccent.withOpacity(0.05) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.redAccent.withOpacity(0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.01),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.logout, color: Colors.redAccent, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        ref.t('logout'),
                        style: AppTextStyles.bodyBold(isDark: isDark).copyWith(color: Colors.redAccent),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
