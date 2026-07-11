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
  
  // Phase of the logo animation
  String _animationPhase = 'pop-in'; // pop-in, visible, pop-out

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

  Future<void> _runSplashLifecycle() async {
    // 1. Start pop-in animation
    _controller.forward();
    
    // 2. Logo visible phase (duration is 5000ms total, first phase is 600ms)
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _animationPhase = 'visible';
    });

    // Wait until it is time to pop out (5000ms - 1200ms = 3800ms)
    await Future.delayed(const Duration(milliseconds: 3200));
    if (!mounted) return;
    setState(() {
      _animationPhase = 'pop-out';
    });

    // Reconfigure animation for ease-in pop-out
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

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    // 3. Navigation routing logic based on onboarding and auth status
    final prefs = ref.read(sharedPrefsServiceProvider);
    final onboardingCompleted = prefs.isOnboardingCompleted();
    
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (e) {
      debugPrint('Firebase Auth not initialized: $e');
    }

    // Also check for a stored trial JWT token (trial users don't use Firebase)
    bool hasTrialToken = false;
    try {
      final storedToken = await ref.read(secureStorageServiceProvider).getAuthToken();
      if (storedToken != null && storedToken.isNotEmpty) {
        hasTrialToken = true;
      }
    } catch (e) {
      debugPrint('Could not read secure storage: $e');
    }

    if (!onboardingCompleted) {
      context.go('/language');
    } else {
      if (user != null || hasTrialToken) {
        context.go('/home');
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
