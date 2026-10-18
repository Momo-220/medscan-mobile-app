import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../di/providers.dart';

import '../../features/auth/screens/ask_name_screen.dart';
import '../../features/auth/screens/auth_screen.dart';
import '../../features/auth/screens/choose_avatar_screen.dart';
import '../../features/auth/screens/choose_doctor_screen.dart';
import '../../features/auth/screens/language_selection_screen.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/trial_or_signin_screen.dart';
import '../../features/chat/screens/chat_screen.dart';
import '../../features/chat/screens/voice_consultation_screen.dart';
import '../../features/history/screens/pharmacy_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/scan/screens/scan_result_screen.dart';
import '../../features/scan/screens/scan_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../shared/widgets/floating_scan_button.dart';
import '../../shared/widgets/navigation_bar.dart';

// Keys created once at module level — never reassigned, never recreated
final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

/// Route observer for listening to navigation events (e.g. for replaying gem animation on return)
final RouteObserver<ModalRoute<void>> homeRouteObserver = RouteObserver<ModalRoute<void>>();

/// Smooth fade transition builder (duration 220ms with easeInOutCubic curve)
CustomTransitionPage<void> _buildSmoothPage({
  required Widget child,
  required GoRouterState state,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOutCubic,
        reverseCurve: Curves.easeInOutCubic,
      );
      return FadeTransition(
        opacity: curvedAnimation,
        child: child,
      );
    },
  );
}

final GoRouter _router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  observers: [homeRouteObserver],
  initialLocation: '/splash',
  // Handle deep links from the home screen widget (medscan://home → /home)
  redirect: (context, state) {
    final uri = state.uri;
    // When opened via medscan:// scheme from the widget, redirect to target path
    if (uri.scheme == 'medscan') {
      final path = uri.host; // e.g. 'home' from medscan://home
      return path.isNotEmpty ? '/$path' : '/home';
    }
    return null; // no redirect otherwise
  },
  routes: [
    GoRoute(
      path: '/splash',
      pageBuilder: (context, state) => _buildSmoothPage(child: const SplashPage(), state: state),
    ),
    GoRoute(
      path: '/language',
      pageBuilder: (context, state) => _buildSmoothPage(child: const LanguageSelectionPage(), state: state),
    ),
    GoRoute(
      path: '/onboarding',
      pageBuilder: (context, state) => _buildSmoothPage(child: const OnboardingPage(), state: state),
    ),
    GoRoute(
      path: '/trial-or-signin',
      pageBuilder: (context, state) => _buildSmoothPage(child: const TrialOrSignInPage(), state: state),
    ),
    GoRoute(
      path: '/ask-name',
      pageBuilder: (context, state) => _buildSmoothPage(child: const AskNamePage(), state: state),
    ),
    GoRoute(
      path: '/auth',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return _buildSmoothPage(
          child: AuthPage(isLoginDefault: extra['isLogin'] ?? true),
          state: state,
        );
      },
    ),
    GoRoute(
      path: '/choose-avatar',
      pageBuilder: (context, state) => _buildSmoothPage(child: const ChooseAvatarPage(), state: state),
    ),
    GoRoute(
      path: '/choose-doctor',
      pageBuilder: (context, state) => _buildSmoothPage(child: const ChooseDoctorPage(), state: state),
    ),
    GoRoute(
      path: '/profile',
      pageBuilder: (context, state) => _buildSmoothPage(child: const ProfilePage(), state: state),
    ),
    GoRoute(
      path: '/scan',
      pageBuilder: (context, state) => _buildSmoothPage(child: const ScanPage(), state: state),
    ),
    GoRoute(
      path: '/scan-result',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return _buildSmoothPage(
          child: ScanResultPage(scanData: extra),
          state: state,
        );
      },
    ),
    GoRoute(
      path: '/voice-consultation',
      pageBuilder: (context, state) => _buildSmoothPage(
        child: const VoiceConsultationScreen(),
        state: state,
      ),
    ),

    // ShellRoute for Bottom Nav Tabs (Fluid, smooth transitions without sliding)
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => AppShell(
        currentPath: state.matchedLocation,
        child: child,
      ),
      routes: [
        GoRoute(
          path: '/home',
          pageBuilder: (context, state) => _buildSmoothPage(child: const HomePage(), state: state),
        ),
        GoRoute(
          path: '/chat',
          pageBuilder: (context, state) {
            String? medicationContext;
            String? medicationImageUrl;
            if (state.extra is String) {
              medicationContext = state.extra as String;
            } else if (state.extra is Map<String, dynamic>) {
              final map = state.extra as Map<String, dynamic>;
              medicationContext = map['name'] as String?;
              medicationImageUrl = map['imageUrl'] as String?;
            }
            return _buildSmoothPage(
              child: ChatPage(
                key: ValueKey('chat_${medicationContext ?? "default"}_${state.pageKey.value}'),
                medicationContext: medicationContext,
                medicationImageUrl: medicationImageUrl,
              ),
              state: state,
            );
          },
        ),
        GoRoute(
          path: '/pharmacy',
          pageBuilder: (context, state) => _buildSmoothPage(child: const PharmacyPage(), state: state),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) => _buildSmoothPage(child: const SettingsPage(), state: state),
        ),
      ],
    ),
  ],
);


// Single instance — Riverpod guarantees it's created only once
final routerProvider = Provider<GoRouter>((ref) {
  ref.keepAlive();
  return _router;
});

class AppShell extends ConsumerWidget {
  final Widget child;
  final String currentPath;

  const AppShell({
    super.key,
    required this.child,
    required this.currentPath,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final isChatInputActive = currentPath == '/chat' && ref.watch(chatInputActiveProvider);
    final hideNavBar = isKeyboardOpen || isChatInputActive;

    // Show floating scan (+) action button on Home and Pharmacy tabs
    final showFab = !hideNavBar && (currentPath == '/home' || currentPath == '/pharmacy');

    final safeAreaBottom = MediaQuery.paddingOf(context).bottom;
    final double bottomMargin = safeAreaBottom > 0 ? safeAreaBottom + 8.0 : 20.0;
    final double fabBottom = bottomMargin + 68.0 + 80.0;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final double horizontalMargin = screenWidth < 360 ? 12.0 : (screenWidth < 400 ? 16.0 : 20.0);
    final double clampedWidth = screenWidth.clamp(0.0, 500.0);
    final double fabRight = ((screenWidth - clampedWidth) / 2) + horizontalMargin + 4.0;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(child: child),

          // Floating Scan (+) Action Button (Positioned at bottom right)
          Positioned(
            right: fabRight,
            bottom: fabBottom,
            child: AnimatedSlide(
              offset: showFab ? Offset.zero : const Offset(0, 1.6),
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOutCubic,
              child: AnimatedOpacity(
                opacity: showFab ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                child: IgnorePointer(
                  ignoring: !showFab,
                  child: const FloatingScanButton(),
                ),
              ),
            ),
          ),

          // Docked Bottom Navigation Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedSlide(
              offset: hideNavBar ? const Offset(0, 1.8) : Offset.zero,
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeInOutCubic,
              child: AnimatedOpacity(
                opacity: hideNavBar ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeInOut,
                child: CustomNavigationBar(currentPath: currentPath),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

