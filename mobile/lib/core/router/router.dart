import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/screens/ask_name_screen.dart';
import '../../features/auth/screens/auth_screen.dart';
import '../../features/auth/screens/choose_avatar_screen.dart';
import '../../features/auth/screens/language_selection_screen.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/trial_or_signin_screen.dart';
import '../../features/chat/screens/chat_screen.dart';
import '../../features/history/screens/pharmacy_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/scan/screens/scan_result_screen.dart';
import '../../features/scan/screens/scan_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../shared/widgets/navigation_bar.dart';

// Keys created once at module level — never reassigned, never recreated
final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

final GoRouter _router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (_, __) => const SplashPage()),
    GoRoute(path: '/language', builder: (_, __) => const LanguageSelectionPage()),
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingPage()),
    GoRoute(path: '/trial-or-signin', builder: (_, __) => const TrialOrSignInPage()),
    GoRoute(path: '/ask-name', builder: (_, __) => const AskNamePage()),
    GoRoute(path: '/auth', builder: (_, __) => const AuthPage()),
    GoRoute(path: '/choose-avatar', builder: (_, __) => const ChooseAvatarPage()),
    GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
    GoRoute(path: '/scan', builder: (_, __) => const ScanPage()),
    GoRoute(
      path: '/scan-result',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return ScanResultPage(scanData: extra);
      },
    ),

    // ShellRoute for Bottom Nav Tabs
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => AppShell(
        currentPath: state.matchedLocation,
        child: child,
      ),
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomePage()),
        GoRoute(path: '/chat', builder: (_, __) => const ChatPage()),
        GoRoute(path: '/pharmacy', builder: (_, __) => const PharmacyPage()),
        GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
      ],
    ),
  ],
);

// Single instance — Riverpod guarantees it's created only once
final routerProvider = Provider<GoRouter>((ref) {
  ref.keepAlive();
  return _router;
});

class AppShell extends StatelessWidget {
  final Widget child;
  final String currentPath;

  const AppShell({
    super.key,
    required this.child,
    required this.currentPath,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: child),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: CustomNavigationBar(currentPath: currentPath),
          ),
        ],
      ),
    );
  }
}
