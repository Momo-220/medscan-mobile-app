import 'dart:io';

void main() {
  var content = File('/Users/mohamed02/Documents/medscan-app-1/mobile/lib/main.dart').readAsStringSync();
  content = content.replaceAll(
    "import 'shared/services/widget_service.dart';",
    "import 'shared/services/widget_service.dart';\nimport 'features/reminders/providers/reminders_provider.dart';"
  );
  
  content = content.replaceAll(
'''@pragma('vm:entry-point')
Future<void> interactiveCallback(Uri? uri) async {
  if (uri?.host == 'mark_taken') {
    debugPrint('Widget: interactiveCallback triggered for mark_taken');
    // Here we could directly mark the reminder as taken in Firebase.
    // However, since we don't have the ProviderContainer here easily,
    // we can use WidgetService to log it or update shared preferences,
    // or trigger an API call. For now, let's just log and update the widget's internal state.
    final takenId = await WidgetService.checkMedicationTaken();
    debugPrint('Widget background mark_taken: id=\$takenId');
  }
}''',
'''@pragma('vm:entry-point')
Future<void> interactiveCallback(Uri? uri) async {
  if (uri?.host == 'mark_taken') {
    debugPrint('Widget: interactiveCallback triggered for mark_taken');
    final takenId = await WidgetService.checkMedicationTaken();
    debugPrint('Widget background mark_taken: id=\$takenId');
    
    if (takenId != null && takenId.isNotEmpty) {
      try {
        if (Firebase.apps.isEmpty) {
          if (defaultTargetPlatform == TargetPlatform.android) {
            await Firebase.initializeApp(
              options: const FirebaseOptions(
                apiKey: 'AIzaSyDI1PB5EqYUhQ5xUB2yr2yovKi8sXc6rqY',
                appId: '1:14523087808:android:eb35e6d0783e5232fd6625',
                messagingSenderId: '14523087808',
                projectId: 'medscan-915d3',
                storageBucket: 'medscan-915d3.firebasestorage.app',
              ),
            );
          } else {
            await Firebase.initializeApp(
              options: const FirebaseOptions(
                apiKey: 'AIzaSyBEbHqdkETi-6GbpRpjt0f5QGIC7H_Bf7o',
                appId: '1:14523087808:ios:80c20077ffb81a11fd6625',
                messagingSenderId: '14523087808',
                projectId: 'medscan-915d3',
                storageBucket: 'medscan-915d3.firebasestorage.app',
                iosBundleId: 'com.seinimomo.medscanapp',
              ),
            );
          }
        }
        
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ]
        );
        
        await container.read(remindersProvider.notifier).markTaken(takenId);
        
        // Let's also sync the widget with the updated data
        final updatedReminders = container.read(remindersProvider);
        await WidgetService.syncWidgetData(updatedReminders);
      } catch (e) {
        debugPrint('Error in background widget callback: \$e');
      }
    }
  }
}'''
  );
  
  File('/Users/mohamed02/Documents/medscan-app-1/mobile/lib/main.dart').writeAsStringSync(content);
}
