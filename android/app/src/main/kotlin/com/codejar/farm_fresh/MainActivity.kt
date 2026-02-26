package com.codejar.farm_pro

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant
import android.content.Context
import android.content.ContextWrapper
import android.os.Bundle

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Explicitly register all plugins to ensure they're available
        GeneratedPluginRegistrant.registerWith(flutterEngine)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Additional setup for plugin compatibility
        try {
            // This ensures the application context is properly set up for plugins
            Thread.currentThread().contextClassLoader = this.classLoader
        } catch (e: Exception) {
            // Handle any exceptions silently
        }
    }
}
