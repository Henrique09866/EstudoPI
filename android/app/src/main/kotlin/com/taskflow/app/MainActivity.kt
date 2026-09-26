package com.taskflow.app

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var shortcutChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "curujao/widgets")
            .setMethodCallHandler { call, result ->
                if (call.method != "update") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val title = call.argument<String>("title") ?: "Nenhuma tarefa pendente"
                val subtitle = call.argument<String>("subtitle") ?: "Toque para abrir seus estudos"
                CurujaoWidgetProvider.saveNextTask(this, title, subtitle)
                result.success(null)
            }
        shortcutChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "curujao/shortcuts",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method == "getLaunchAction") {
                    result.success(intent?.action)
                } else {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.action == AppShortcutControllerAction.startPomodoro) {
            shortcutChannel?.invokeMethod("startPomodoro", intent.action)
        }
    }
}
