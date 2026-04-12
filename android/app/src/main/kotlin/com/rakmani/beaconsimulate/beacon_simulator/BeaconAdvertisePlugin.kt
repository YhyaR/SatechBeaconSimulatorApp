package com.rakmani.beaconsimulate.beacon_simulator

/*
 * Copyright (c) 2026 Y.Rakmani. All rights reserved.
 *
 * Native BLE legacy advertiser bridge for the Beacon Simulator app.
 */

import android.bluetooth.BluetoothManager
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.content.Context
import android.os.ParcelUuid
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.UUID

/**
 * Legacy BLE advertising for iBeacon + SATECH Info using [ByteArray] payloads from Dart
 * ([Uint8List] over the method channel).
 */
class BeaconAdvertisePlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private var applicationContext: Context? = null
    private var leAdvertiser: BluetoothLeAdvertiser? = null
    private var activeCallback: AdvertiseCallback? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        stopAdvertising(null)
        applicationContext = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "start" -> handleStart(call, result)
            "stop" -> stopAdvertising(result)
            "isAdvertising" -> result.success(activeCallback != null)
            else -> result.notImplemented()
        }
    }

    private fun handleStart(call: MethodCall, result: Result) {
        val ctx = applicationContext
        if (ctx == null) {
            result.error("no_context", "Plugin not attached", null)
            return
        }
        val mode = call.argument<String>("mode")
        val payload = call.argument<ByteArray>("payload")
        if (mode == null || payload == null) {
            result.error("bad_args", "mode and payload are required", null)
            return
        }
        val manager = ctx.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        val adapter = manager?.adapter
        val adv = adapter?.bluetoothLeAdvertiser
        if (adv == null) {
            result.error("no_advertiser", "Bluetooth LE advertiser not available", null)
            return
        }
        stopAdvertising(null)

        val data = AdvertiseData.Builder()
        when (mode) {
            "ibeacon" -> {
                val manufacturerId = call.argument<Int>("manufacturerId") ?: 0x004c
                data.addManufacturerData(manufacturerId, payload)
            }
            "info" -> {
                val uuid = ParcelUuid(UUID.fromString(SATECH_SERVICE_UUID))
                data.addServiceUuid(uuid)
                data.addServiceData(uuid, payload)
            }
            else -> {
                result.error("bad_mode", "mode must be ibeacon or info", null)
                return
            }
        }
        data.setIncludeDeviceName(false)

        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_BALANCED)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
            .setConnectable(false)
            .setTimeout(0)
            .build()

        val callback = object : AdvertiseCallback() {
            override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
                Log.i(TAG, "onStartSuccess mode=$mode")
                result.success(true)
            }

            override fun onStartFailure(errorCode: Int) {
                Log.e(TAG, "onStartFailure code=$errorCode")
                activeCallback = null
                result.error(
                    "ADVERTISE_FAILED",
                    advertiseFailureName(errorCode),
                    errorCode,
                )
            }
        }
        activeCallback = callback
        leAdvertiser = adv
        try {
            adv.startAdvertising(settings, data.build(), callback)
        } catch (e: Exception) {
            activeCallback = null
            result.error("start_exception", e.message, null)
        }
    }

    private fun stopAdvertising(result: Result?) {
        val adv = leAdvertiser
        val cb = activeCallback
        if (adv != null && cb != null) {
            try {
                adv.stopAdvertising(cb)
            } catch (_: Exception) {
            }
        }
        activeCallback = null
        result?.success(true)
    }

    private fun advertiseFailureName(code: Int): String = when (code) {
        AdvertiseCallback.ADVERTISE_FAILED_DATA_TOO_LARGE -> "DATA_TOO_LARGE"
        AdvertiseCallback.ADVERTISE_FAILED_TOO_MANY_ADVERTISERS -> "TOO_MANY_ADVERTISERS"
        AdvertiseCallback.ADVERTISE_FAILED_ALREADY_STARTED -> "ALREADY_STARTED"
        AdvertiseCallback.ADVERTISE_FAILED_INTERNAL_ERROR -> "INTERNAL_ERROR"
        AdvertiseCallback.ADVERTISE_FAILED_FEATURE_UNSUPPORTED -> "FEATURE_UNSUPPORTED"
        else -> "UNKNOWN_$code"
    }

    companion object {
        private const val TAG = "BeaconAdvertise"
        const val CHANNEL_NAME = "com.rakmani.beaconsimulate/beacon_advertise"
        private const val SATECH_SERVICE_UUID = "0000ffe1-0000-1000-8000-00805f9b34fb"
    }
}
