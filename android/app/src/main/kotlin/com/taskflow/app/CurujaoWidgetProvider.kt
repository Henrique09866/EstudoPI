package com.taskflow.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class CurujaoWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        appWidgetIds.forEach { widgetId -> updateWidget(context, appWidgetManager, widgetId) }
    }

    companion object {
        private const val preferencesName = "curujao_study_widget"
        private const val titleKey = "next_task_title"
        private const val subtitleKey = "next_task_subtitle"

        fun saveNextTask(context: Context, title: String, subtitle: String) {
            context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
                .edit()
                .putString(titleKey, title)
                .putString(subtitleKey, subtitle)
                .apply()
            val manager = AppWidgetManager.getInstance(context)
            val component = android.content.ComponentName(context, CurujaoWidgetProvider::class.java)
            manager.getAppWidgetIds(component).forEach { widgetId ->
                updateWidget(context, manager, widgetId)
            }
        }

        private fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            widgetId: Int,
        ) {
            val preferences = context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
            val views = RemoteViews(context.packageName, R.layout.curujao_study_widget)
            views.setTextViewText(
                R.id.widget_task_title,
                preferences.getString(titleKey, "Abra o Curujão para planejar"),
            )
            views.setTextViewText(
                R.id.widget_task_subtitle,
                preferences.getString(subtitleKey, "Seu próximo foco começa aqui"),
            )
            val pomodoroIntent = Intent(context, MainActivity::class.java).apply {
                action = AppShortcutControllerAction.startPomodoro
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pomodoroPendingIntent = PendingIntent.getActivity(
                context,
                100,
                pomodoroIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_start_pomodoro, pomodoroPendingIntent)
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

object AppShortcutControllerAction {
    const val startPomodoro = "com.taskflow.app.START_POMODORO"
}
