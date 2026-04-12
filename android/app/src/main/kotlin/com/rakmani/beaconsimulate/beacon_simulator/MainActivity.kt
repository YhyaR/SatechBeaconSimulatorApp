package com.rakmani.beaconsimulate.beacon_simulator

// Copyright (c) 2026 Y.Rakmani. All rights reserved.

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(BeaconAdvertisePlugin())
    }
}
