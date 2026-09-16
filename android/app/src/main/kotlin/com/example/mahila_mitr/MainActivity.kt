package com.example.mahila_mitr

import android.Manifest
import android.bluetooth.BluetoothManager
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.pm.PackageManager
import android.os.Build
import android.os.ParcelUuid
import android.util.Log
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

class MainActivity : FlutterActivity() {
    private val service = ParcelUuid(UUID.fromString("7b5dc1a5-0e68-442d-888d-8ef7a7506de2"))
    private var channel: MethodChannel? = null
    private var advertiser: BluetoothLeAdvertiser? = null
    private var scanner: BluetoothLeScanner? = null
    private var advertising = false
    private var scanning = false
    private var pending: Pair<MethodCall, MethodChannel.Result>? = null
    private var advertiseStartResult: MethodChannel.Result? = null
    private var advertiseCallback: AdvertiseCallback? = null
    private var advertisedCode: String? = null
    private var scanResultsSeen = 0
    private var lastFoundCode: String? = null
    private var lastFoundAt = 0L
    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            scanResultsSeen++
            if (scanResultsSeen == 1 || scanResultsSeen % 10 == 0) {
                channel?.invokeMethod("scanProgress", scanResultsSeen)
            }
            val bytes = result.scanRecord?.getServiceData(service) ?: return
            if (bytes.size != 6) return
            val code = bytes.joinToString("") { "%02X".format(it.toInt() and 0xff) }
            val now = System.currentTimeMillis()
            if (code == lastFoundCode && now - lastFoundAt < 3000) return
            lastFoundCode = code
            lastFoundAt = now
            Log.d("MahilaNearby", "Mahila invitation advertisement found")
            channel?.invokeMethod("found", code)
        }
        override fun onScanFailed(errorCode: Int) {
            scanning = false
            channel?.invokeMethod("error", "Bluetooth scan failed ($errorCode)")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mahila_mitr/nearby")
        channel?.setMethodCallHandler { call, result ->
            if (call.method == "stopAdvertising") { stopAdvertising(); result.success(null); return@setMethodCallHandler }
            if (call.method == "stopScan") { stopScan(); result.success(null); return@setMethodCallHandler }
            val permissions = if (Build.VERSION.SDK_INT >= 31) {
                if (call.method == "startAdvertising") arrayOf(Manifest.permission.BLUETOOTH_ADVERTISE, Manifest.permission.BLUETOOTH_CONNECT)
                else arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
            } else arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
            val missing = permissions.filter { ActivityCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED }
            if (missing.isNotEmpty()) {
                pending = Pair(call, result)
                ActivityCompat.requestPermissions(this, missing.toTypedArray(), 71)
            } else execute(call, result)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != 71) return
        val request = pending ?: return
        pending = null
        if (grantResults.isEmpty() || grantResults.any { it != PackageManager.PERMISSION_GRANTED }) {
            request.second.error("permission_denied", "Nearby devices permission is required", null)
        } else execute(request.first, request.second)
    }

    private fun execute(call: MethodCall, result: MethodChannel.Result) {
        val adapter = (getSystemService(BLUETOOTH_SERVICE) as BluetoothManager).adapter
        if (adapter == null || !adapter.isEnabled) { result.error("bluetooth_off", "Turn on Bluetooth first", null); return }
        try {
            when (call.method) {
                "startAdvertising" -> {
                    val code = call.argument<String>("code") ?: ""
                    if (!Regex("[0-9A-F]{12}").matches(code)) { result.error("invalid_code", "Create a new invite first", null); return }
                    if (advertising && advertisedCode == code) {
                        result.success(mapOf("status" to "already_advertising"))
                        return
                    }
                    val bytes = ByteArray(6) { i -> code.substring(i * 2, i * 2 + 2).toInt(16).toByte() }
                    stopAdvertising()
                    advertiser = adapter.bluetoothLeAdvertiser
                    if (advertiser == null) { result.error("unsupported", "This phone cannot advertise over BLE", null); return }
                    val settings = AdvertiseSettings.Builder().setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
                        .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM).setConnectable(false).build()
                    val data = AdvertiseData.Builder().setIncludeDeviceName(false).addServiceData(service, bytes).build()
                    val callback = object : AdvertiseCallback() {
                        override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
                            if (advertiseCallback !== this) return
                            advertising = true
                            advertisedCode = code
                            Log.d("MahilaNearby", "BLE advertising started")
                            advertiseStartResult?.success(mapOf("status" to "started"))
                            advertiseStartResult = null
                        }

                        override fun onStartFailure(errorCode: Int) {
                            if (advertiseCallback !== this) return
                            advertising = false
                            advertisedCode = null
                            val reason = when (errorCode) {
                                ADVERTISE_FAILED_DATA_TOO_LARGE -> "Bluetooth advertisement is too large"
                                ADVERTISE_FAILED_TOO_MANY_ADVERTISERS -> "Bluetooth is busy advertising for other apps"
                                ADVERTISE_FAILED_FEATURE_UNSUPPORTED -> "This phone cannot advertise over BLE"
                                ADVERTISE_FAILED_ALREADY_STARTED -> "Bluetooth sharing is already active"
                                else -> "Bluetooth advertising failed ($errorCode)"
                            }
                            Log.e("MahilaNearby", reason)
                            advertiseStartResult?.error("advertise_failed", reason, null)
                            advertiseStartResult = null
                            advertiseCallback = null
                        }
                    }
                    advertiseCallback = callback
                    advertiseStartResult = result
                    advertiser!!.startAdvertising(settings, data, callback)
                }
                "startScan" -> {
                    stopScan()
                    scanResultsSeen = 0
                    lastFoundCode = null
                    lastFoundAt = 0L
                    scanner = adapter.bluetoothLeScanner
                    if (scanner == null) { result.error("unsupported", "This phone cannot scan BLE", null); return }
                    val filters = listOf(ScanFilter.Builder().setServiceData(service, byteArrayOf()).build())
                    scanner!!.startScan(filters, ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).build(), scanCallback)
                    scanning = true
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: SecurityException) {
            advertiseStartResult = null
            result.error("permission_denied", "Nearby devices permission is required", null)
        }
        catch (e: Exception) {
            advertiseStartResult = null
            result.error("bluetooth_error", e.message ?: "Bluetooth failed", null)
        }
    }

    private fun stopAdvertising() {
        val callback = advertiseCallback
        if (callback != null) {
            try { advertiser?.stopAdvertising(callback) } catch (_: Exception) {}
        }
        advertiseCallback = null
        advertiseStartResult = null
        advertisedCode = null
        advertiser = null
        advertising = false
    }
    private fun stopScan() {
        try { scanner?.stopScan(scanCallback) } catch (_: Exception) {}
        scanning = false
    }
    override fun onDestroy() { stopAdvertising(); stopScan(); super.onDestroy() }
}
