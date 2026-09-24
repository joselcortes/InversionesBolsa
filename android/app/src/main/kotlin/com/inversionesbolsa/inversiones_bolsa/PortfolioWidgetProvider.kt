package com.inversionesbolsa.inversiones_bolsa

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

// Widget de pantalla de inicio: valor del portafolio y variación del día.
// Los datos los escribe la app (o la tarea en segundo plano) con home_widget.
class PortfolioWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.portfolio_widget).apply {
                setTextViewText(R.id.widget_value, widgetData.getString("value", "—"))
                setTextViewText(
                    R.id.widget_change,
                    widgetData.getString("change", "Abre la app para cargar"),
                )
                setTextColor(
                    R.id.widget_change,
                    if (widgetData.getBoolean("up", true)) Color.parseColor("#22C55E")
                    else Color.parseColor("#EF4444"),
                )
                setTextViewText(R.id.widget_mode, widgetData.getString("mode", ""))
                setTextViewText(R.id.widget_updated, widgetData.getString("updated", ""))
                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
