package com.dukanest.dukanest_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val cp35BeaconPlugin = Cp35BeaconPlugin()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        cp35BeaconPlugin.attach(this)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            Cp35BeaconPlugin.CHANNEL,
        ).setMethodCallHandler(cp35BeaconPlugin)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == Cp35BeaconPlugin.PERMISSION_REQUEST) {
            cp35BeaconPlugin.onPermissionResult(grantResults)
        }
    }
}
