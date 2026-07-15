import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/di/providers.dart';
import 'core/router/router.dart';
import 'core/theme/theme.dart';
import 'shared/services/notification_service.dart';
import 'shared/services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Local Notifications service
  await NotificationService.initialize();

  // Load SharedPreferences instance
  final sharedPreferences = await SharedPreferences.getInstance();

  // Initialize Firebase with explicit options
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyBEbHqdkETi-6GbpRpjt0f5QGIC7H_Bf7o',
        appId: '1:14523087808:ios:80c20077ffb81a11fd6625',
        messagingSenderId: '14523087808',
        projectId: 'medscan-915d3',
        storageBucket: 'medscan-915d3.firebasestorage.app',
        // Fixed: must match PRODUCT_BUNDLE_IDENTIFIER in Runner.xcodeproj
        iosBundleId: 'com.seinimomo.medscanapp',
      ),
    );
    debugPrint('Firebase initialized successfully!');
    // Initialize Remote Push Notifications service
    await PushNotificationService.initialize();
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  // Initialize Google Sign-In (required once in v7.x before any authenticate() call)
  try {
    await GoogleSignIn.instance.initialize();
    debugPrint('GoogleSignIn initialized successfully!');
  } catch (e) {
    debugPrint('GoogleSignIn initialization failed: $e');
  }

  // Lock device orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const MedScanApp(),
    ),
  );
}

class MedScanApp extends ConsumerWidget {
  const MedScanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeModeState = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'MedScan',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeModeState,
      routerConfig: router,
    );
  }
}
