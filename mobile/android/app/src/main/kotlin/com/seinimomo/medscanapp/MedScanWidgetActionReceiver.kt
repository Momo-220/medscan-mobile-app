package com.seinimomo.medscanapp

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import es.antonborri.home_widget.HomeWidgetBackgroundReceiver

class MedScanWidgetActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == "com.seinimomo.medscanapp.MARK_TAKEN") {
            // 1. Optimistic update
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val total = prefs.getInt("total_doses", 1)
            val taken = prefs.getInt("taken_doses", 0)
            
            val newTaken = if (taken + 1 > total) total else taken + 1
            val allDone = newTaken >= total
            val progress = newTaken.toFloat() / total.toFloat()
            
            prefs.edit()
                .putInt("taken_doses", newTaken)
                .putFloat("progress", progress)
                .putBoolean("all_done", allDone)
                .putBoolean("medication_taken", true)
                .putString("medication_taken_id", intent.data?.getQueryParameter("id") ?: "")
                .apply()
                
            // 2. Refresh Widget UI instantly
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, MedScanWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
            
            val updateIntent = Intent(context, MedScanWidgetProvider::class.java)
            updateIntent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            updateIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, appWidgetIds)
            context.sendBroadcast(updateIntent)
            
            // 3. Delegate to Flutter background worker
            val flutterIntent = Intent(context, HomeWidgetBackgroundReceiver::class.java)
            flutterIntent.data = intent.data // Forward the URI
            context.sendBroadcast(flutterIntent)
        }
    }
}
