# Flutter Local Notifications ProGuard / R8 Rules for Release Production
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver { *; }
-keep class com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver { *; }
-keep class com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver { *; }
-keepclassmembers class * extends com.dexterous.flutterlocalnotifications.** { *; }

# Firebase Cloud Messaging Rules
-keep class com.google.firebase.messaging.** { *; }
-keep class com.google.firebase.iid.** { *; }
