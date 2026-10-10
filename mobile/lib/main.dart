import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'core/di/providers.dart';
import 'core/router/router.dart';
import 'core/theme/theme.dart';
import 'core/constants/api_constants.dart';
import 'data/models/reminder.dart';
import 'shared/services/notification_service.dart';
import 'shared/services/push_notification_service.dart';
import 'shared/services/widget_service.dart';

/// Background callback triggered by the iOS widget's "Pris" button.
/// This runs in a background isolate — NO Flutter UI, NO Riverpod state.
/// We manually load the cache, update it, and push it back to the widget.
@pragma('vm:entry-point')
Future<void> interactiveCallback(Uri? uri) async {
  if (uri?.host != 'mark_taken') return;

  debugPrint('Widget: interactiveCallback triggered for mark_taken');

  try {
    // 1. Initialize Firebase in this background isolate
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: defaultTargetPlatform == TargetPlatform.android
            ? const FirebaseOptions(
                apiKey: 'AIza' 'SyDI1PB5EqYUhQ5xUB2yr2yovKi8sXc6rqY',
                appId: '1:14523087808:android:eb35e6d0783e5232fd6625',
                messagingSenderId: '14523087808',
                projectId: 'medscan-915d3',
                storageBucket: 'medscan-915d3.firebasestorage.app',
              )
            : const FirebaseOptions(
                apiKey: 'AIza' 'SyBEbHqdkETi-6GbpRpjt0f5QGIC7H_Bf7o',
                appId: '1:14523087808:ios:b056fb85e473843cfd6625',
                messagingSenderId: '14523087808',
                projectId: 'medscan-915d3',
                storageBucket: 'medscan-915d3.firebasestorage.app',
                iosBundleId: 'com.seinimomo.medscanapp',
              ),
      );
    }

    await WidgetService.init();

    // 2. Read the reminder ID that was marked as taken by the widget
    String? takenId = uri?.queryParameters['id'];
    if (takenId == null || takenId.isEmpty) {
      takenId = await WidgetService.checkMedicationTaken();
    }
    debugPrint('Widget background mark_taken: id=$takenId');
    if (takenId == null || takenId.isEmpty) return;

    // 3. Load the reminders cache from SharedPreferences directly
    //    (Riverpod providers do not exist in a background isolate)
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final userId = firebaseUser?.uid ?? 'local_user';
    final cacheKey = 'reminders_cache_$userId';

    final prefs = await SharedPreferences.getInstance();
    final cacheJson = prefs.getString(cacheKey);

    List<Reminder> reminders = [];
    if (cacheJson != null && cacheJson.isNotEmpty) {
      try {
        final List<dynamic> decoded = json.decode(cacheJson);
        reminders = decoded.map((e) => Reminder.fromJson(e as Map<String, dynamic>)).toList();
      } catch (e) {
        debugPrint('Widget: Failed to decode reminders cache: $e');
      }
    }

    // 4. Mark the reminder as taken in the local list
    bool found = false;
    final updatedReminders = reminders.map((r) {
      if (r.id == takenId) {
        found = true;
        final newNextDose = r.calculateNextDoseTime(r.nextDose);
        final isAllDone = newNextDose.day != r.nextDose.day;
        return r.copyWith(
          nextDose: newNextDose,
          taken: isAllDone ? true : false,
        );
      }
      return r;
    }).toList();

    if (!found) {
      debugPrint('Widget: Reminder id=$takenId not found in cache, syncing anyway.');
    }

    // 5. Save updated cache back to SharedPreferences
    try {
      final updatedJson = json.encode(updatedReminders.map((r) => r.toJson()).toList());
      await prefs.setString(cacheKey, updatedJson);
    } catch (e) {
      debugPrint('Widget: Failed to save updated reminders cache: $e');
    }

    // 6. Sync widget with the updated list (this also calls WidgetCenter.reloadAllTimelines)
    await WidgetService.syncWidget(reminders: updatedReminders);

    // 7. Also call the backend API to mark as taken if user is authenticated
    try {
      if (firebaseUser != null && !firebaseUser.isAnonymous && !takenId.startsWith('reminder_')) {
        final token = await firebaseUser.getIdToken();
        if (token != null && token.isNotEmpty) {
          final uri = Uri.parse('${ApiConstants.baseUrl}/reminders/$takenId/take');
          final response = await http.post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'taken_at': DateTime.now().toUtc().toIso8601String(),
            }),
          );
          debugPrint('Widget: Backend sync for markTaken status: ${response.statusCode}');
        }
      }
    } catch (e) {
      debugPrint('Widget: Failed to sync markTaken with backend: $e');
    }

    debugPrint('Widget: Successfully processed mark_taken for id=$takenId');
  } catch (e) {
    debugPrint('Widget: Error in background interactiveCallback: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Firebase first with explicit options per platform
  try {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'AIza' 'SyDI1PB5EqYUhQ5xUB2yr2yovKi8sXc6rqY',
          appId: '1:14523087808:android:eb35e6d0783e5232fd6625',
          messagingSenderId: '14523087808',
          projectId: 'medscan-915d3',
          storageBucket: 'medscan-915d3.firebasestorage.app',
        ),
      );
    } else {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'AIza' 'SyBEbHqdkETi-6GbpRpjt0f5QGIC7H_Bf7o',
          appId: '1:14523087808:ios:b056fb85e473843cfd6625',
          messagingSenderId: '14523087808',
          projectId: 'medscan-915d3',
          storageBucket: 'medscan-915d3.firebasestorage.app',
          iosBundleId: 'com.seinimomo.medscanapp',
        ),
      );
    }
    debugPrint('Firebase initialized successfully!');
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  // 2. Initialize Local Notifications & Home Widget service
  await NotificationService.initialize();
  await PushNotificationService.initialize();
  await WidgetService.init();

  // NOTE: We do NOT call checkMedicationTaken() here.
  // The background callback (interactiveCallback) handles it directly
  // when the widget button is pressed. Calling it here would consume
  // (and discard) the flag before the callback processes it.

  // Register background interactivity callback
  await HomeWidget.registerInteractivityCallback(interactiveCallback);

  // Load SharedPreferences instance
  final sharedPreferences = await SharedPreferences.getInstance();

  // Initialize Google Sign-In (required once in v7.x before any authenticate() call)
  try {
    await GoogleSignIn.instance.initialize(
      serverClientId:
          '14523087808-77j9h0j47fm7ks4t6scu6nflfd43fhtt.apps.googleusercontent.com',
    );
    debugPrint('GoogleSignIn initialized successfully!');
  } catch (e) {
    debugPrint('GoogleSignIn initialization failed: $e');
  }

  // Lock device orientation to portrait on phones, allow all orientations on tablets (iPad)
  final view = WidgetsBinding.instance.platformDispatcher.views.firstOrNull;
  final isTablet = view != null &&
      (MediaQueryData.fromView(view).size.shortestSide >= 600);
  if (!isTablet) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  } else {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const MedScanApp(),
    ),
  );
}

class MedScanApp extends ConsumerStatefulWidget {
  const MedScanApp({super.key});

  @override
  ConsumerState<MedScanApp> createState() => _MedScanAppState();
}

class _MedScanAppState extends ConsumerState<MedScanApp> {
  @override
  void initState() {
    super.initState();
    // Listen for widget taps — navigate to /home when the widget is pressed
    HomeWidget.widgetClicked.listen((uri) {
      if (uri != null) {
        final router = ref.read(routerProvider);
        // medscan://home → /home, medscan://chat → /chat, etc.
        final path = uri.host.isNotEmpty ? '/${uri.host}' : '/home';
        router.go(path);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
