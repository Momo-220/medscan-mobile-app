package com.seinimomo.medscanapp

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import android.view.View
import es.antonborri.home_widget.HomeWidgetProvider
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import java.util.Calendar

class MedScanWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.medscan_widget_layout).apply {

                val reminderName   = widgetData.getString("reminder_name", "") ?: ""
                val reminderTime   = widgetData.getString("reminder_time", "--:--") ?: "--:--"
                val reminderDosage = widgetData.getString("reminder_dosage", "") ?: ""
                val reminderId     = widgetData.getString("reminder_id", "") ?: ""
                val userName       = widgetData.getString("user_name", "") ?: ""
                val avatarId       = widgetData.getString("avatar_id", "Avatar1") ?: "Avatar1"

                val hasReminder = reminderName.isNotEmpty() && reminderName != "Aucun rappel"
                val allDone = getSafeBoolean(widgetData, "all_done", false)
                val progressFromFlutter = getSafeDouble(widgetData, "progress", 0.0)
                val totalDoses = getSafeInt(widgetData, "total_doses", 1)
                val takenDoses = getSafeInt(widgetData, "taken_doses", 0)

                val isPending = getSafeBoolean(widgetData, "is_pending", false)
                val nextDoseTimestamp = getSafeLong(widgetData, "next_dose_timestamp", 0L)
                val weekHistory = widgetData.getString("week_history", "0000000") ?: "0000000"
                val hasReminders = getSafeBoolean(widgetData, "has_reminders", true)

                // ── Greeting based on hour ──
                val greeting = getGreeting()

                // ── Progress toward next dose ──
                val progress = if (progressFromFlutter > 0) progressFromFlutter else computeProgress(reminderTime)

                // ── Header ──
                setTextViewText(R.id.widget_greeting, greeting)
                val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
                val greetingIconRes = if (hour in 5..17) R.drawable.ic_sun else R.drawable.ic_moon
                setImageViewResource(R.id.widget_greeting_icon, greetingIconRes)
                
                setTextViewText(R.id.widget_username, if (userName.isEmpty()) "Utilisateur" else userName)

                // ── Avatar ──
                val resId = context.resources.getIdentifier(avatarId.lowercase(), "drawable", context.packageName)
                if (resId != 0) setImageViewResource(R.id.widget_avatar, resId)

                // ── Body ──
                setTextViewText(
                    R.id.widget_reminder_name,
                    if (allDone) "Tout est pris ! 🎉" else if (hasReminder) reminderName else "Aucun rappel actif"
                )
                setTextViewText(
                    R.id.widget_reminder_dosage,
                    if (allDone) "Excellente journée" else if (hasReminder) reminderDosage else ""
                )
                
                if (allDone || !hasReminder) {
                    setTextViewText(R.id.widget_reminder_time, if (allDone) "" else "--:--")
                    setViewVisibility(R.id.widget_countdown, View.GONE)
                    setViewVisibility(R.id.widget_reminder_time, View.VISIBLE)
                } else if (isPending && nextDoseTimestamp > 0L) {
                    // Show live countdown
                    val elapsedRealtimeOffset = android.os.SystemClock.elapsedRealtime() - System.currentTimeMillis()
                    val targetTimeInRealtime = nextDoseTimestamp + elapsedRealtimeOffset
                    
                    setChronometer(R.id.widget_countdown, targetTimeInRealtime, "Dans %s", true)
                    setChronometerCountDown(R.id.widget_countdown, true)
                    setViewVisibility(R.id.widget_countdown, View.VISIBLE)
                    setViewVisibility(R.id.widget_reminder_time, View.GONE)
                } else {
                    // Due now
                    setTextViewText(R.id.widget_reminder_time, "À prendre")
                    setViewVisibility(R.id.widget_countdown, View.GONE)
                    setViewVisibility(R.id.widget_reminder_time, View.VISIBLE)
                }

                // ── Pris Button ──
                if (hasReminder && !allDone) {
                    if (isPending) {
                        setViewVisibility(R.id.widget_pending_button, View.VISIBLE)
                        setViewVisibility(R.id.widget_pris_button, View.GONE)
                        
                        val pendingIntentNone = android.app.PendingIntent.getActivity(context, 0, android.content.Intent(), android.app.PendingIntent.FLAG_IMMUTABLE)
                        setOnClickPendingIntent(R.id.widget_pending_button, pendingIntentNone)
                    } else {
                        setViewVisibility(R.id.widget_pending_button, View.GONE)
                        setViewVisibility(R.id.widget_pris_button, View.VISIBLE)
                        
                        val uri = android.net.Uri.parse("medscan://mark_taken?id=$reminderId")
                        val actionIntent = android.content.Intent(context, MedScanWidgetActionReceiver::class.java)
                        actionIntent.action = "com.seinimomo.medscanapp.MARK_TAKEN"
                        actionIntent.data = uri
                        
                        val pendingIntentPris = android.app.PendingIntent.getBroadcast(
                            context,
                            0,
                            actionIntent,
                            android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_MUTABLE
                        )
                        setOnClickPendingIntent(R.id.widget_pris_button, pendingIntentPris)
                    }
                } else {
                    setViewVisibility(R.id.widget_pris_button, View.GONE)
                    setViewVisibility(R.id.widget_pending_button, View.GONE)
                }

                // ── Progress bar ──
                val progressInt = (progress * 100).toInt().coerceIn(0, 100)
                setProgressBar(R.id.widget_progress_bar, 100, progressInt, false)
                val label = if (allDone) {
                    "Journée terminée"
                } else if (totalDoses > 1) {
                    "$takenDoses/$totalDoses doses"
                } else {
                    "$progressInt%"
                }
                setTextViewText(R.id.widget_progress_label, label)
                
                // ── Weekly history dots ──
                val daysResIds = intArrayOf(
                    R.id.widget_day_0,
                    R.id.widget_day_1,
                    R.id.widget_day_2,
                    R.id.widget_day_3,
                    R.id.widget_day_4,
                    R.id.widget_day_5,
                    R.id.widget_day_6
                )
                for (i in 0..6) {
                    val isTaken = if (i < weekHistory.length) weekHistory[i] == '1' else false
                    val dotRes = if (isTaken) R.drawable.widget_dot_active else R.drawable.widget_dot_inactive
                    setImageViewResource(daysResIds[i], dotRes)
                }

                // ── Toggle Visibility between Active Content and Empty State Action Dock ──
                if (hasReminders) {
                    setViewVisibility(R.id.widget_main_content, View.VISIBLE)
                    setViewVisibility(R.id.widget_empty_state, View.GONE)
                } else {
                    setViewVisibility(R.id.widget_main_content, View.GONE)
                    setViewVisibility(R.id.widget_empty_state, View.VISIBLE)

                    // ── Empty State Action Buttons ──
                    val pendingIntentScanEmpty = HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        android.net.Uri.parse("medscan://scan")
                    )
                    setOnClickPendingIntent(R.id.widget_empty_scan_button, pendingIntentScanEmpty)

                    val pendingIntentAddEmpty = HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        android.net.Uri.parse("medscan://home")
                    )
                    setOnClickPendingIntent(R.id.widget_empty_add_button, pendingIntentAddEmpty)

                    val pendingIntentPharmacyEmpty = HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        android.net.Uri.parse("medscan://pharmacy")
                    )
                    setOnClickPendingIntent(R.id.widget_empty_pharmacy_button, pendingIntentPharmacyEmpty)
                }

                // ── Click to open app ──
                val pendingIntentHome = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    android.net.Uri.parse("medscan://home")
                )
                setOnClickPendingIntent(R.id.widget_root, pendingIntentHome)
                
                val pendingIntentScan = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    android.net.Uri.parse("medscan://scan")
                )
                setOnClickPendingIntent(R.id.widget_scan_button, pendingIntentScan)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    /** Returns a contextual greeting based on the current hour. */
    private fun getGreeting(): String {
        val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        return when {
            hour in 5..11  -> "Bonjour"
            hour in 12..17 -> "Bon après-midi"
            else           -> "Bonsoir"
        }
    }

    /**
     * Computes a 0.0–1.0 progress value toward the next dose.
     * Parses "HH:mm" and measures how close we are to that time today.
     */
    private fun computeProgress(timeStr: String): Double {
        val parts = timeStr.split(":").mapNotNull { it.toIntOrNull() }
        if (parts.size < 2) return 0.5

        val targetHour   = parts[0]
        val targetMinute = parts[1]
        val now = Calendar.getInstance()
        val nowMinutes    = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        val targetMinutes = targetHour * 60 + targetMinute

        var diff = targetMinutes - nowMinutes
        if (diff < 0) diff += 24 * 60

        // Progress = 1 - (remaining fraction over a 12h window)
        val progress = 1.0 - (diff.toDouble() / (12 * 60)).coerceIn(0.0, 1.0)
        return progress.coerceAtLeast(0.05)
    }

    private fun getSafeDouble(prefs: SharedPreferences, key: String, defaultVal: Double): Double {
        val value = prefs.all[key] ?: return defaultVal
        return when (value) {
            is Number -> value.toDouble()
            is String -> value.toDoubleOrNull() ?: defaultVal
            else -> defaultVal
        }
    }

    private fun getSafeInt(prefs: SharedPreferences, key: String, defaultVal: Int): Int {
        val value = prefs.all[key] ?: return defaultVal
        return when (value) {
            is Number -> value.toInt()
            is String -> value.toIntOrNull() ?: defaultVal
            else -> defaultVal
        }
    }

    private fun getSafeLong(prefs: SharedPreferences, key: String, defaultVal: Long): Long {
        val value = prefs.all[key] ?: return defaultVal
        return when (value) {
            is Number -> value.toLong()
            is String -> value.toLongOrNull() ?: defaultVal
            else -> defaultVal
        }
    }

    private fun getSafeBoolean(prefs: SharedPreferences, key: String, defaultVal: Boolean): Boolean {
        val value = prefs.all[key] ?: return defaultVal
        return when (value) {
            is Boolean -> value
            is Number -> value.toInt() != 0
            is String -> value.lowercase() == "true" || value == "1"
            else -> defaultVal
        }
    }
}
