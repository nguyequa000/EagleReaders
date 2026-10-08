package com.UNT.storysprout

import android.app.ActivityManager
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // How much memory this app and this phone have, so the reader can size
        // its biggest page-by-page book to the phone (see device_memory.dart).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "storysprout/memory")
            .setMethodCallHandler { call, result ->
                if (call.method == "memory") {
                    val info = ActivityManager.MemoryInfo()
                    (getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager)
                        .getMemoryInfo(info)
                    result.success(
                        mapOf(
                            // Raised by android:largeHeap.
                            "maxHeap" to Runtime.getRuntime().maxMemory(),
                            "totalRam" to info.totalMem,
                        )
                    )
                } else {
                    result.notImplemented()
                }
            }
    }
}
