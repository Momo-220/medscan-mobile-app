import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';
import '../../../shared/utils/localization.dart';
import '../../../shared/widgets/button.dart';
import '../../../shared/widgets/card.dart';
import '../../../shared/widgets/google_logo.dart';
import '../../../shared/widgets/input.dart';
import '../providers/auth_provider.dart';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  bool _isLogin = true;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();

  bool _showPassword = false;
  bool _showPasswordConfirm = false;
  bool _loading = false;
  String? _error;

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

  String _getAuthErrorMessage(dynamic err) {
    if (err is FirebaseAuthException) {
      final code = err.code;
      if (code == 'user-not-found' || code == 'wrong-password' || code == 'invalid-credential') {
        return ref.t('authErrorInvalid');
      }
      if (code == 'email-already-in-use') {
        return ref.t('authErrorEmailUsed');
      }
      if (code == 'weak-password') {
        return ref.t('authErrorWeakPassword');
      }
      if (code == 'network-request-failed') {
        return ref.t('authErrorNetwork');
      }
    }
    
    final errStr = err.toString();
    if (errStr.contains('introuvable') || errStr.contains('not found')) {
      return 'Nom d\'utilisateur introuvable. Essayez avec votre email.';
    }
    if (errStr.contains('déjà pris') || errStr.contains('taken')) {
      return 'Ce nom d\'utilisateur est déjà pris.';
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
    final username = _usernameController.text.trim();

    if (emailOrUsername.isEmpty || password.isEmpty) {
      setState(() {
        _error = ref.t('authErrorGeneric');
      });
      return;
    }

    if (!_isLogin && password != confirm) {
      setState(() {
        _error = ref.t('authErrorPasswordMismatch');
      });
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      if (_isLogin) {
        await ref.read(authProvider.notifier).signIn(emailOrUsername, password);
        if (mounted) {
          context.go('/home');
        }
      } else {
        await ref.read(authProvider.notifier).signUp(
          emailOrUsername,
          password,
          name,
          username: username.isEmpty ? null : username,
        );
        if (mounted) {
          context.go('/choose-avatar');
        }
      }
    } catch (err) {
      setState(() {
        _error = _getAuthErrorMessage(err);
        _loading = false;
      });
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
        // If logged in successfully, go home
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          context.go('/home');
        } else {
          setState(() {
            _loading = false;
          });
        }
      }
    } catch (err) {
      setState(() {
        _error = _getAuthErrorMessage(err);
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
          // Si pas de nom ou nom générique → demander le nom
          final name = user.displayName ?? '';
          final needsName = name.isEmpty || name.toLowerCase() == 'user';
          if (needsName) {
            context.go('/ask-name');
          } else {
            context.go('/home');
          }
        } else {
          setState(() { _loading = false; });
        }
      }
    } catch (err) {
      setState(() {
        _error = _getAuthErrorMessage(err);
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
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.cardDark : Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.06),
                                        blurRadius: 10,
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
                            padding: const EdgeInsets.all(6.0),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : AppColors.backgroundSecondary,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() {
                                      _isLogin = true;
                                      _error = null;
                                    }),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: _isLogin
                                            ? (isDark ? const Color(0xFF334155) : Colors.white)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: _isLogin && !isDark
                                            ? [
                                                const BoxShadow(
                                                  color: Colors.black12,
                                                  blurRadius: 4,
                                                  offset: Offset(0, 1),
                                                )
                                              ]
                                            : null,
                                      ),
                                      child: Text(
                                        ref.t('authLogin'),
                                        style: AppTextStyles.small(
                                          color: _isLogin
                                              ? AppColors.primary
                                              : (isDark ? AppColors.textMutedDark : AppColors.textSecondary),
                                          fontWeight: FontWeight.w600,
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
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: !_isLogin
                                            ? (isDark ? const Color(0xFF334155) : Colors.white)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: !_isLogin && !isDark
                                            ? [
                                                const BoxShadow(
                                                  color: Colors.black12,
                                                  blurRadius: 4,
                                                  offset: Offset(0, 1),
                                                )
                                              ]
                                            : null,
                                      ),
                                      child: Text(
                                        ref.t('authRegister'),
                                        style: AppTextStyles.small(
                                          color: !_isLogin
                                              ? AppColors.primary
                                              : (isDark ? AppColors.textMutedDark : AppColors.textSecondary),
                                          fontWeight: FontWeight.w600,
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
                              mainAxisAlignment: MainAxisAlignment.center,
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

                          // ── Social Sign-In Row (Apple & Google Side-by-Side) ──
                          Row(
                            children: [
                              // Apple Button
                              Expanded(
                                child: GestureDetector(
                                  onTap: _loading ? null : _handleAppleSignIn,
                                  child: Container(
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white : Colors.black,
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: isDark
                                          ? null
                                          : [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.08),
                                                blurRadius: 4,
                                                offset: const Offset(0, 1),
                                              ),
                                            ],
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.apple,
                                          color: isDark ? Colors.black : Colors.white,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          ref.t('authApple'),
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.black : Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Google Button
                              Expanded(
                                child: GestureDetector(
                                  onTap: _loading ? null : _handleGoogleSignIn,
                                  child: Container(
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1D1B20) : Colors.white,
                                      border: Border.all(
                                        color: isDark
                                            ? const Color(0xFF49454F)
                                            : const Color(0xFFDADCE0),
                                        width: 1,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: isDark
                                          ? null
                                          : [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.06),
                                                blurRadius: 4,
                                                offset: const Offset(0, 1),
                                              ),
                                            ],
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const GoogleLogo(size: 18),
                                        const SizedBox(width: 8),
                                        Text(
                                          ref.t('authGoogle'),
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white : const Color(0xFF1F1F1F),
                                          ),
                                        ),
                                      ],
                                    ),
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
        ],
      ),
    );
  }
}
