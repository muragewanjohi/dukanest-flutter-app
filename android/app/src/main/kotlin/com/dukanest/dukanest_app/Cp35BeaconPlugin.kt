package com.dukanest.dukanest_app

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.bluetooth.BluetoothManager
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.dukanest.dukanest_app.ble.AndroidCp35Transport
import com.dukanest.dukanest_app.ble.Cp35GattClient
import com.dukanest.dukanest_app.ble.Cp35ProvisionError
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * MethodChannel bridge for CP35 provisioning. Never logs beacon passwords.
 *
 * Channel: [CHANNEL].
 */
class Cp35BeaconPlugin : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "com.dukanest.dukanest_app/cp35"
        const val PERMISSION_REQUEST = 41035
    }

    private var activity: Activity? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()
    private var client: Cp35GattClient? = null
    private var pendingResult: MethodChannel.Result? = null
    private var pendingAfterPermission: (() -> Unit)? = null

    fun attach(activity: Activity) {
        this.activity = activity
    }

    fun onPermissionResult(grantResults: IntArray) {
        val result = pendingResult
        val next = pendingAfterPermission
        pendingResult = null
        pendingAfterPermission = null
        if (result == null || next == null) return
        if (grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
            next()
        } else {
            result.error("permission_required", "Allow Bluetooth to configure the beacon.", null)
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isSdkAvailable" -> result.success(isRadioAvailable())
            "scanNearbyBeacons" -> withPermissions(result) {
                executor.execute {
                    val devices = try {
                        scanNearby()
                    } catch (_: Exception) {
                        null
                    }
                    mainHandler.post {
                        if (devices == null) {
                            result.error("scan_failed", "Could not scan for beacons.", null)
                        } else {
                            result.success(devices)
                        }
                    }
                }
            }
            "connect" -> withPermissions(result) {
                runAsync(result) {
                    ensureClient().connect(call.argument<String>("mac") ?: "")
                }
            }
            "unlock" -> runAsync(result) {
                ensureClient().unlock(call.argument<String>("password") ?: "")
            }
            "writeIBeacon" -> runAsync(result) {
                val uuid = call.argument<String>("uuid")
                val major = call.argument<Number>("major")?.toInt()
                val minor = call.argument<Number>("minor")?.toInt()
                if (uuid.isNullOrBlank() || major == null || minor == null) {
                    Result.failure(Cp35ProvisionError.BadArgs("uuid, major, minor required"))
                } else {
                    ensureClient().writeIBeacon(
                        uuid = uuid,
                        major = major,
                        minor = minor,
                        txDbm = call.argument<Number>("txDbm")?.toDouble() ?: -13.5,
                        intervalMs = call.argument<Number>("intervalMs")?.toInt() ?: 500,
                    )
                }
            }
            "restart" -> runAsync(result) {
                ensureClient().restart(call.argument<String>("password") ?: "")
            }
            "disconnect" -> runAsync(result) {
                client?.disconnect()
                Result.success(Unit)
            }
            else -> result.notImplemented()
        }
    }

    private fun isRadioAvailable(): Boolean {
        val ctx = activity ?: return false
        val adapter = (ctx.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter
        return adapter != null
    }

    private fun requiredPermissions(): Array<String> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }
    }

    private fun withPermissions(result: MethodChannel.Result, block: () -> Unit) {
        val act = activity
        if (act == null) {
            result.error("permission_required", "Allow Bluetooth to configure the beacon.", null)
            return
        }
        val missing = requiredPermissions().filter {
            ContextCompat.checkSelfPermission(act, it) != PackageManager.PERMISSION_GRANTED
        }
        if (missing.isEmpty()) {
            block()
            return
        }
        pendingResult = result
        pendingAfterPermission = block
        ActivityCompat.requestPermissions(act, missing.toTypedArray(), PERMISSION_REQUEST)
    }

    private fun ensureClient(): Cp35GattClient {
        val existing = client
        if (existing != null) return existing
        val ctx = activity ?: throw Cp35ProvisionError.GattError("no_context")
        val created = Cp35GattClient(AndroidCp35Transport(ctx.applicationContext), commandPauseMs = 80L)
        client = created
        return created
    }

    @SuppressLint("MissingPermission")
    private fun scanNearby(timeoutMs: Long = 6_000L): List<Map<String, Any>> {
        val ctx = activity ?: return emptyList()
        val adapter = (ctx.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter
            ?: return emptyList()
        if (!adapter.isEnabled) return emptyList()
        val scanner = adapter.bluetoothLeScanner ?: return emptyList()
        val found = linkedMapOf<String, MutableMap<String, Any>>()
        val callback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                val device = result.device ?: return
                val mac = device.address ?: return
                val name = result.scanRecord?.deviceName?.takeIf { it.isNotBlank() }
                    ?: device.name?.takeIf { it.isNotBlank() }
                    ?: "Unknown"
                val previous = found[mac]
                val previousRssi = previous?.get("rssi") as? Int
                if (previousRssi == null || result.rssi > previousRssi) {
                    found[mac] = mutableMapOf("name" to name, "mac" to mac, "rssi" to result.rssi)
                }
            }
        }
        scanner.startScan(callback)
        try {
            Thread.sleep(timeoutMs)
        } finally {
            try {
                scanner.stopScan(callback)
            } catch (_: Exception) {
                // Scan may already have stopped.
            }
        }
        return found.values.sortedByDescending { it["rssi"] as Int }
    }

    private fun runAsync(result: MethodChannel.Result, block: () -> Result<Unit>) {
        executor.execute {
            val outcome = try {
                block()
            } catch (e: Cp35ProvisionError) {
                Result.failure(e)
            } catch (e: Exception) {
                Result.failure(Cp35ProvisionError.GattError(e.javaClass.simpleName))
            }
            mainHandler.post {
                outcome.fold(
                    onSuccess = { result.success(true) },
                    onFailure = { err ->
                        when (err) {
                            is Cp35ProvisionError.AuthFailed -> result.success(false)
                            is Cp35ProvisionError.NotConnected ->
                                result.error("not_connected", err.message, null)
                            is Cp35ProvisionError.BadArgs ->
                                result.error("bad_args", err.message, null)
                            is Cp35ProvisionError.Timeout ->
                                result.error("timeout", err.message, null)
                            is Cp35ProvisionError.GattError ->
                                result.error("gatt_error", err.message, null)
                            else -> result.error("gatt_error", err.message, null)
                        }
                    },
                )
            }
        }
    }
}
