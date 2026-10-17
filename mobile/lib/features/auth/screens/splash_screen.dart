import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  final List<_StarData> _stars = [];
  final Random _random = Random();
  


  @override
  void initState() {
    super.initState();

    // Generate 20 star positions (matching React's random client-side stars)
    for (int i = 0; i < 20; i++) {
      _stars.add(
        _StarData(
          left: _random.nextDouble(),
          top: _random.nextDouble(),
          maxOpacity: _random.nextDouble() * 0.4 + 0.1,
          duration: Duration(milliseconds: 1500 + _random.nextInt(1500)),
          delay: Duration(milliseconds: _random.nextInt(1000)),
        ),
      );
    }

    // Animation controller for the logo transition (600ms phases)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const ElasticOutCurve(0.64), // Matches web cubic-bezier(0.34, 1.56, 0.64, 1)
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    _runSplashLifecycle();
  }

  Future<Map<String, dynamic>> _resolveSession() async {
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        user = await FirebaseAuth.instance
            .authStateChanges()
            .first
            .timeout(const Duration(milliseconds: 1500), onTimeout: () => FirebaseAuth.instance.currentUser);
      }
    } catch (e) {
      debugPrint('Firebase Auth check failed: $e');
    }

    bool hasTrialToken = false;
    try {
      final storedToken = await ref.read(secureStorageServiceProvider).getAuthToken();
      if (storedToken != null && storedToken.isNotEmpty) {
        hasTrialToken = true;
      }
    } catch (e) {
      debugPrint('Could not read secure storage: $e');
    }

    return {
      'user': user,
      'hasTrialToken': hasTrialToken,
    };
  }

  Future<void> _runSplashLifecycle() async {
    // 0. Preload session in parallel while animation plays
    final sessionFuture = _resolveSession();

    // 1. Pop-in animation (500ms)
    _controller.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    // 2. Logo visible phase (1400ms)
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;

    // 3. Pop-out animation (400ms)
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeIn,
      ),
    );
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeIn,
      ),
    );
    _controller.reverse(from: 1.0);

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    // 4. Retrieve resolved session (already finished in parallel)
    final session = await sessionFuture;
    final User? user = session['user'] as User?;
    final bool hasTrialToken = session['hasTrialToken'] as bool? ?? false;
    final prefs = ref.read(sharedPrefsServiceProvider);

    final isAuthenticated = user != null || hasTrialToken;

    if (isAuthenticated) {
      // User is already logged in — permanently cement onboarding flag
      await prefs.setOnboardingCompleted(true);

      // Refresh Firebase token silently in background to keep ApiClient primed
      if (user != null) {
        user.getIdToken().then((token) {
          if (token != null && token.isNotEmpty) {
            ref.read(secureStorageServiceProvider).setAuthToken(token);
          }
        }).catchError((err) {
          debugPrint('Silent token refresh in splash error: $err');
        });
      }

      // Si l'utilisateur est connecté avec un compte réel mais n'a pas encore choisi d'avatar,
      // on lui propose l'écran des avatars
      final avatarCompleted = prefs.isAvatarCompleted();
      final localAvatar = prefs.getLocalAvatar();
      final hasAvatar = (localAvatar != null && localAvatar.isNotEmpty) ||
          (user?.photoURL != null && user!.photoURL!.contains('avatar'));

      if (!mounted) return;

      if (user != null && !hasTrialToken && (!avatarCompleted || !hasAvatar)) {
        context.go('/choose-avatar');
      } else if (user != null && !hasTrialToken && !prefs.isDoctorCompleted()) {
        context.go('/choose-doctor');
      } else {
        context.go('/home');
      }
    } else {
      if (!mounted) return;
      // User has no active session: check onboarding
      final onboardingCompleted = prefs.isOnboardingCompleted();
      if (!onboardingCompleted) {
        context.go('/language');
      } else {
        context.go('/auth');
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0A1628), // 0%
              Color(0xFF1A365D), // 50%
              Color(0xFF0D2847), // 100%
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Twinkling stars background
            Positioned.fill(
              child: Stack(
                children: _stars.map((star) {
                  return Positioned(
                    left: star.left * size.width,
                    top: star.top * size.height,
                    child: _TwinklingStar(starData: star),
                  );
                }).toList(),
              ),
            ),

            // Animated Logo + Glow background
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [


                  // Logo Pop scale/fade animation
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Opacity(
                          opacity: _opacityAnimation.value,
                          child: child,
                        ),
                      );
                    },
                    child: Hero(
                      tag: 'app_logo',
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 160,
                        height: 160,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          // Fallback container if logo image fails to load
                          return Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF5B9FED), Color(0xFF06B6D4)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 20,
                                  offset: Offset(0, 10),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.check_circle_outline,
                              color: Colors.white,
                              size: 80,
                            ),
                          );
                        },
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

class _StarData {
  final double left;
  final double top;
  final double maxOpacity;
  final Duration duration;
  final Duration delay;

  _StarData({
    required this.left,
    required this.top,
    required this.maxOpacity,
    required this.duration,
    required this.delay,
  });
}

class _TwinklingStar extends StatefulWidget {
  final _StarData starData;

  const _TwinklingStar({required this.starData});

  @override
  State<_TwinklingStar> createState() => _TwinklingStarState();
}

class _TwinklingStarState extends State<_TwinklingStar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.starData.duration,
    );

    _animation = Tween<double>(begin: 0.1, end: widget.starData.maxOpacity).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Apply start delay
    Future.delayed(widget.starData.delay, () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            width: 3.0,
            height: 3.0,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
