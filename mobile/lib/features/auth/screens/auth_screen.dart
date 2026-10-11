import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../core/di/providers.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../shared/utils/localization.dart';
import '../../../shared/widgets/button.dart';
import '../../../shared/widgets/card.dart';
import '../../../shared/widgets/google_logo.dart';
import '../../../shared/widgets/input.dart';
import '../../../shared/services/username_service.dart';
import '../../../shared/utils/email_validator.dart';
import '../providers/auth_provider.dart';

class AuthPage extends ConsumerStatefulWidget {
  final bool isLoginDefault;
  
  const AuthPage({
    super.key,
    this.isLoginDefault = true,
  });

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  late bool _isLogin;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();

  bool _showPassword = false;
  bool _showPasswordConfirm = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _isLogin = widget.isLoginDefault;
  }

  int _getPasswordStrength(String pwd) {
    if (pwd.isEmpty) return 0;
    if (pwd.length < 6) return 1;

    final hasLetter = RegExp(r'[a-zA-Z]').hasMatch(pwd);
    final hasNumber = RegExp(r'[0-9]').hasMatch(pwd);
    final hasSpecial = RegExp(r'[^a-zA-Z0-9]').hasMatch(pwd);

    int types = 0;
    if (hasLetter) types++;
    if (hasNumber) types++;
    if (hasSpecial) types++;

    if (pwd.length >= 8 && types >= 3) return 3;
    if (pwd.length >= 6 && types >= 2) return 2;
    return 1;
  }

  String _getAuthErrorMessage(dynamic err, {bool isApple = false, bool isGoogle = false}) {
    if (err is FirebaseAuthException) {
      final code = err.code;
      if (isApple && (code == 'invalid-credential' || code == 'invalid-user-token' || code == 'operation-not-allowed')) {
        return ref.t('authErrorAppleFailed');
      }
      if (isGoogle && (code == 'invalid-credential' || code == 'operation-not-allowed')) {
        return ref.t('authErrorGeneric');
      }
      if (code == 'user-not-found' || code == 'wrong-password' || code == 'invalid-credential') {
        return ref.t('authErrorInvalid');
      }
      if (code == 'invalid-user-token' || code == 'operation-not-allowed') {
        return ref.t('authErrorAppleFailed');
      }
      if (code == 'email-already-in-use') {
        return ref.t('authErrorEmailUsed');
      }
      if (code == 'weak-password') {
        return ref.t('authErrorWeakPassword');
      }
      if (code == 'invalid-email') {
        return ref.t('authErrorInvalidEmail');
      }
      if (code == 'user-disabled') {
        return ref.t('authErrorUserDisabled');
      }
      if (code == 'too-many-requests') {
        return ref.t('authErrorTooManyRequests');
      }
      if (code == 'network-request-failed') {
        return ref.t('authErrorNetwork');
      }
      if (code == 'account-exists-with-different-credential') {
        return ref.t('authErrorEmailExistsSignIn');
      }
    }
    
    final rawErrStr = err.toString();
    final errStr = rawErrStr.replaceAll('Exception: ', '').trim();

    if (errStr.contains('introuvable') || errStr.contains('not found')) {
      return ref.t('authErrorUsernameNotFound');
    }
    if (errStr.contains('déjà pris') || errStr.contains('taken') || errStr.contains('username_taken')) {
      return ref.t('authErrorUsernameTaken');
    }
    if (errStr.contains('jetables') || errStr.contains('disposable')) {
      return ref.t('authErrorDisposableEmail');
    }
    if (errStr.contains('mediscan-email-exists-signin')) {
      return ref.t('authErrorEmailExistsSignIn');
    }
    if (errStr.contains('popup-closed-by-user') || errStr.contains('cancelled-popup-request')) {
      return ref.t('authErrorPopupClosed');
    }
    if (errStr.contains('popup-blocked')) {
      return ref.t('authErrorPopupBlocked');
    }
    if (errStr.contains('SignInWithApple') ||
        errStr.contains('apple') ||
        errStr.contains('invalid-user-token') ||
        errStr.contains('accessToken')) {
      return ref.t('authErrorAppleFailed');
    }

    // Never display raw technical error strings (brackets, platform exceptions, tokens, etc.)
    if (errStr.isNotEmpty &&
        !errStr.startsWith('[') &&
        !errStr.contains('PlatformException') &&
        !errStr.contains('FirebaseException') &&
        !errStr.contains('firebase_auth') &&
        !errStr.contains('Instance of') &&
        !errStr.contains('nil') &&
        !errStr.contains('token') &&
        errStr.length < 120) {
      return errStr;
    }
    
    return ref.t('authErrorGeneric');
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _error = null;
    });

    final emailOrUsername = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _passwordConfirmController.text;
    final name = _nameController.text.trim();
    final rawUsername = _usernameController.text.trim();
    final cleanUsername = rawUsername.startsWith('@') ? rawUsername.substring(1).trim() : rawUsername;

    // Login validation
    if (_isLogin) {
      if (emailOrUsername.isEmpty) {
        setState(() {
          _error = ref.t('authErrorEmailLoginRequired');
        });
        return;
      }
      if (password.isEmpty) {
        setState(() {
          _error = ref.t('authErrorPasswordLoginRequired');
        });
        return;
      }
    } else {
      // Register validation
      if (name.isEmpty) {
        setState(() {
          _error = ref.t('authErrorNameRequired');
        });
        return;
      }
      if (name.length < 2) {
        setState(() {
          _error = ref.t('authErrorNameTooShort');
        });
        return;
      }
      if (cleanUsername.isNotEmpty) {
        final usernameValidation = UsernameService.validate(cleanUsername);
        if (usernameValidation != null) {
          setState(() {
            _error = usernameValidation;
          });
          return;
        }
      }
      final emailValidation = EmailValidator.validate(emailOrUsername);
      if (emailValidation != null) {
        setState(() {
          _error = emailValidation;
        });
        return;
      }
      if (password.isEmpty) {
        setState(() {
          _error = ref.t('authErrorPasswordRequired');
        });
        return;
      }
      if (password.length < 6) {
        setState(() {
          _error = ref.t('authErrorWeakPassword');
        });
        return;
      }
      if (password != confirm) {
        setState(() {
          _error = ref.t('authErrorPasswordMismatch');
        });
        return;
      }
    }

    setState(() {
      _loading = true;
    });

    try {
      if (_isLogin) {
        await ref.read(authProvider.notifier).signIn(emailOrUsername, password);
        if (mounted) {
          await _navigateAfterAuth(isNewRegistration: false);
        }
      } else {
        await ref.read(authProvider.notifier).signUp(
          emailOrUsername,
          password,
          name,
          username: cleanUsername.isEmpty ? null : cleanUsername,
        );
        if (mounted) {
          await _navigateAfterAuth(isNewRegistration: true);
        }
      }
    } catch (err) {
      setState(() {
        _error = _getAuthErrorMessage(err);
        _loading = false;
      });
    }
  }

  Future<void> _navigateAfterAuth({required bool isNewRegistration}) async {
    final user = FirebaseAuth.instance.currentUser;
    final prefs = ref.read(sharedPrefsServiceProvider);

    // 1. Check if user already has an avatar (locally or in Firebase Auth)
    final localAvatar = prefs.getLocalAvatar();
    final firebaseAvatar = user?.photoURL;
    String? existingAvatar = (localAvatar != null && localAvatar.isNotEmpty)
        ? localAvatar
        : (firebaseAvatar != null && firebaseAvatar.isNotEmpty ? firebaseAvatar : null);

    // 2. If missing, look up from Firestore user document
    if ((existingAvatar == null || existingAvatar.isEmpty) && user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final firestoreAvatar = doc.data()?['photo_url'] as String?;
        if (firestoreAvatar != null && firestoreAvatar.isNotEmpty) {
          existingAvatar = firestoreAvatar;
        }
      } catch (_) {}
    }

    if (existingAvatar != null && existingAvatar.isNotEmpty) {
      await prefs.setLocalAvatar(existingAvatar);
      await prefs.setAvatarCompleted(true);
      if (mounted) {
        context.go('/home');
      }
    } else if (isNewRegistration) {
      if (mounted) {
        context.go('/choose-avatar');
      }
    } else {
      // User logged in but has no avatar chosen yet
      if (mounted) {
        context.go('/choose-avatar');
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      await ref.read(authProvider.notifier).signInWithGoogle();
      if (mounted) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await _navigateAfterAuth(isNewRegistration: false);
        } else {
          setState(() {
            _loading = false;
          });
        }
      }
    } catch (err) {
      setState(() {
        _error = _getAuthErrorMessage(err, isGoogle: true);
        _loading = false;
      });
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      await ref.read(authProvider.notifier).signInWithApple();
      if (mounted) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await _navigateAfterAuth(isNewRegistration: false);
        } else {
          setState(() { _loading = false; });
        }
      }
    } catch (err) {
      final errStr = err.toString().toLowerCase();
      if (errStr.contains('canceled') || errStr.contains('cancelled') || errStr.contains('1001') || errStr.contains('user-cancelled') || errStr.contains('authorization_error_code_canceled')) {
        setState(() {
          _loading = false;
        });
        return;
      }
      debugPrint('Apple Sign-In error details: $err');
      setState(() {
        _error = _getAuthErrorMessage(err, isApple: true);
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strength = _getPasswordStrength(_passwordController.text);

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

          // Content Wrapper
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: ResponsiveContainer(
                  maxWidth: 480,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Main Form Card
                    AppCard(
                      padding: const EdgeInsets.all(28.0),
                      children: Column(
                        children: [
                          // App Branding Header
                          Center(
                            child: Column(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white : Colors.black,
                                    borderRadius: BorderRadius.circular(50),
                                    boxShadow: isDark
                                        ? null
                                        : [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.08),
                                              blurRadius: 6,
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
                                const SizedBox(height: 12),
                                Text(
                                  'MedScan',
                                  style: AppTextStyles.h3(isDark: isDark),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  ref.t('authSubtitle'),
                                  style: AppTextStyles.small(
                                    color: isDark ? AppColors.textMutedDark : AppColors.textSecondary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Toggle Selector: Login / Register
                          Container(
                            padding: const EdgeInsets.all(5.0),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() {
                                      _isLogin = true;
                                      _error = null;
                                    }),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: _isLogin
                                            ? (isDark ? const Color(0xFF334155) : Colors.white)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(15),
                                        boxShadow: _isLogin && !isDark
                                            ? [
                                                BoxShadow(
                                                  color: const Color(0xFF3B82F6).withOpacity(0.10),
                                                  blurRadius: 8,
                                                  spreadRadius: 0,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Text(
                                        ref.t('authLogin'),
                                        style: AppTextStyles.bodyBold(isDark: isDark).copyWith(
                                          color: _isLogin
                                              ? const Color(0xFF3B82F6)
                                              : (isDark ? AppColors.textMutedDark : const Color(0xFF64748B)),
                                          fontSize: 14.5,
                                          fontWeight: _isLogin ? FontWeight.w700 : FontWeight.w500,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() {
                                      _isLogin = false;
                                      _error = null;
                                    }),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: !_isLogin
                                            ? (isDark ? const Color(0xFF334155) : Colors.white)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(15),
                                        boxShadow: !_isLogin && !isDark
                                            ? [
                                                BoxShadow(
                                                  color: const Color(0xFF3B82F6).withOpacity(0.10),
                                                  blurRadius: 8,
                                                  spreadRadius: 0,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Text(
                                        ref.t('authRegister'),
                                        style: AppTextStyles.bodyBold(isDark: isDark).copyWith(
                                          color: !_isLogin
                                              ? const Color(0xFF3B82F6)
                                              : (isDark ? AppColors.textMutedDark : const Color(0xFF64748B)),
                                          fontSize: 14.5,
                                          fontWeight: !_isLogin ? FontWeight.w700 : FontWeight.w500,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Form Inputs
                          if (_error != null) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red[50]!.withOpacity(isDark ? 0.15 : 0.9),
                                border: Border.all(
                                  color: Colors.red[200]!.withOpacity(isDark ? 0.3 : 0.9),
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _error!,
                                style: AppTextStyles.small(
                                  color: isDark ? Colors.red[300] : Colors.red[700],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          if (!_isLogin) ...[
                            CustomInput(
                              controller: _nameController,
                              hintText: ref.t('fullName'),
                              icon: const Icon(Icons.person_outline, size: 20),
                            ),
                            const SizedBox(height: 16),
                            CustomInput(
                              controller: _usernameController,
                              hintText: '@nom_utilisateur',
                              icon: const Icon(Icons.alternate_email, size: 20),
                              keyboardType: TextInputType.text,
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 16),
                          ],

                          CustomInput(
                            controller: _emailController,
                            hintText: _isLogin
                                ? 'Email ou @nom_utilisateur'
                                : ref.t('email'),
                            keyboardType: _isLogin
                                ? TextInputType.text
                                : TextInputType.emailAddress,
                            icon: Icon(
                              _isLogin
                                  ? Icons.person_outline
                                  : Icons.mail_outline,
                              size: 20,
                            ),
                          ),
                          const SizedBox(height: 16),

                          CustomInput(
                            controller: _passwordController,
                            hintText: ref.t('authPassword'),
                            obscureText: !_showPassword,
                            textInputAction: _isLogin ? TextInputAction.done : TextInputAction.next,
                            onSubmitted: _isLogin ? (_) => _handleSubmit() : null,
                            icon: const Icon(Icons.lock_outline, size: 20),
                            onChanged: (_) {
                              // Force redraw for password strength
                              if (!_isLogin) setState(() {});
                            },
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _showPassword = !_showPassword),
                              icon: Icon(
                                _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                size: 20,
                                color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                              ),
                            ),
                          ),

                          // Password Strength Indicator (Register only)
                          if (!_isLogin) ...[
                            const SizedBox(height: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: Container(
                                    height: 4,
                                    width: double.infinity,
                                    color: isDark ? Colors.white12 : Colors.black12,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: FractionallySizedBox(
                                        widthFactor: strength == 0 ? 0.0 : strength == 1 ? 0.33 : strength == 2 ? 0.66 : 1.0,
                                        child: Container(
                                          color: strength == 1
                                              ? Colors.red
                                              : strength == 2
                                                  ? Colors.amber
                                                  : strength == 3
                                                      ? Colors.green
                                                      : Colors.transparent,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (_passwordController.text.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    strength == 1
                                        ? ref.t('authPasswordWeak')
                                        : strength == 2
                                            ? ref.t('authPasswordMedium')
                                            : ref.t('authPasswordStrong'),
                                    style: AppTextStyles.micro(isDark: isDark).copyWith(
                                      color: strength == 1
                                          ? Colors.red
                                          : strength == 2
                                              ? Colors.amber
                                              : Colors.green,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 16),
                            CustomInput(
                              controller: _passwordConfirmController,
                              hintText: ref.t('authConfirmPassword'),
                              obscureText: !_showPasswordConfirm,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _handleSubmit(),
                              icon: const Icon(Icons.lock_outline, size: 20),
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => _showPasswordConfirm = !_showPasswordConfirm),
                                icon: Icon(
                                  _showPasswordConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  size: 20,
                                  color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 28),

                          // Submit Action CTA Button
                          Button(
                            loading: _loading,
                            width: double.infinity,
                            onTap: _handleSubmit,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(_isLogin ? ref.t('authLogin') : ref.t('authRegister')),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward, size: 18, color: Colors.white),
                              ],
                            ),
                          ),

                          // Or Divider
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24.0),
                            child: Row(
                              children: [
                                Expanded(child: Divider(color: isDark ? Colors.white12 : Colors.black12)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                  child: Text(
                                    ref.t('authOr'),
                                    style: AppTextStyles.micro(isDark: isDark),
                                  ),
                                ),
                                Expanded(child: Divider(color: isDark ? Colors.white12 : Colors.black12)),
                              ],
                            ),
                          ),

                          // ── Social Sign-In Row (Apple iOS-only + Google) ──
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Apple Button — iOS only (Apple guideline 4.8)
                              if (Platform.isIOS) ...[
                                FutureBuilder<bool>(
                                  future: SignInWithApple.isAvailable(),
                                  builder: (context, snapshot) {
                                    final available = snapshot.data == true;
                                    if (!available) return const SizedBox.shrink();
                                    return Row(
                                      children: [
                                        GestureDetector(
                                          onTap: _loading ? null : _handleAppleSignIn,
                                          child: Container(
                                            width: 56,
                                            height: 56,
                                            decoration: BoxDecoration(
                                              color: isDark ? Colors.white : Colors.black,
                                              borderRadius: BorderRadius.circular(50),
                                              boxShadow: isDark
                                                  ? null
                                                  : [
                                                      BoxShadow(
                                                        color: Colors.black.withOpacity(0.08),
                                                        blurRadius: 6,
                                                        offset: const Offset(0, 2),
                                                      ),
                                                    ],
                                            ),
                                            child: Center(
                                              child: Icon(
                                                Icons.apple,
                                                color: isDark ? Colors.black : Colors.white,
                                                size: 26,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 20),
                                      ],
                                    );
                                  },
                                ),
                              ],
                              // Google Button — all platforms
                              GestureDetector(
                                onTap: _loading ? null : _handleGoogleSignIn,
                                child: Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1D1B20) : Colors.white,
                                    border: Border.all(
                                      color: isDark
                                          ? const Color(0xFF49454F)
                                          : const Color(0xFFDADCE0),
                                      width: 1,
                                    ),
                                    borderRadius: BorderRadius.circular(50),
                                    boxShadow: isDark
                                        ? null
                                        : [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.06),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                  ),
                                  child: const Center(
                                    child: GoogleLogo(size: 24),
                                  ),
                                ),
                              ),
                            ],
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
        ],
      ),
    );
  }
}
