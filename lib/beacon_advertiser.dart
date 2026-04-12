// Copyright (c) 2026 Y.Rakmani. All rights reserved.
//
// BLE advertising session: permissions (via flutter_ble_peripheral) and
// Android native advertise rotation.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';

import 'android_advertise_data.dart';
import 'beacon_payloads.dart';

/// Which logical frames to broadcast (matches Python `--mode`).
enum BeaconBroadcastMode { ibeacon, info, both }

/// Configuration for one simulator session (CLI-aligned defaults in UI).
class BeaconSimConfig {
  BeaconSimConfig({
    required this.broadcastMode,
    required this.uuid,
    required this.major,
    required this.minor,
    required this.txPowerDbm,
    required this.battery,
    required this.mac,
    required this.name,
    required this.infoType,
    required this.dwellMs,
  });

  final BeaconBroadcastMode broadcastMode;
  final String uuid;
  final int major;
  final int minor;
  final int txPowerDbm;
  final int battery;
  final String mac;
  final String name;
  final String infoType;
  final int dwellMs;

  static const methodChannelName = 'com.rakmani.beaconsimulate/beacon_advertise';
}

/// Starts/stops legacy BLE advertising via app-embedded [MethodChannel] on Android,
/// and uses [FlutterBlePeripheral] for permission / Bluetooth state only.
class BeaconAdvertiser {
  BeaconAdvertiser()
      : _channel = const MethodChannel(BeaconSimConfig.methodChannelName),
        _ble = FlutterBlePeripheral();

  final MethodChannel _channel;
  final FlutterBlePeripheral _ble;

  bool _running = false;
  int _frameIndex = 0;
  Completer<void>? _stopped;

  bool get isRunning => _running;

  /// Human-readable status for UI.
  Future<String?> prepare(BeaconSimConfig config) async {
    if (!await _ble.isSupported) {
      return 'This device does not support Bluetooth LE.';
    }
    if (!await _ble.isBluetoothOn) {
      return 'Turn Bluetooth on to advertise.';
    }
    var perm = await _ble.hasPermission();
    if (perm != BluetoothPeripheralState.granted) {
      perm = await _ble.requestPermission();
    }
    if (perm == BluetoothPeripheralState.permanentlyDenied) {
      return 'Bluetooth permission is blocked. Open app settings to allow it.';
    }
    if (perm == BluetoothPeripheralState.denied) {
      return 'Bluetooth permission was denied.';
    }
    if (perm != BluetoothPeripheralState.granted) {
      return 'Bluetooth permission is not granted ($perm).';
    }
    try {
      _validate(config);
    } on FormatException catch (e) {
      return e.message;
    } on ArgumentError catch (e) {
      return e.message;
    }
    return null;
  }

  void _validate(BeaconSimConfig c) {
    uuidBytesFromString(c.uuid);
    parseMacString(c.mac);
    parseInfoType(c.infoType);
    final nameBytes = Uint8List.fromList(c.name.codeUnits);
    if (nameBytes.isEmpty) {
      throw ArgumentError('Name must be at least one ASCII character');
    }
    if (c.dwellMs < 1) {
      throw ArgumentError('Dwell must be at least 1 ms');
    }
  }

  /// Opens system app details (e.g. after permanentlyDenied).
  Future<void> openAppSettings() => _ble.openAppSettings();

  Future<void> openBluetoothSettings() => _ble.openBluetoothSettings();

  Future<void> enableBluetooth({bool askUser = true}) =>
      _ble.enableBluetooth(askUser: askUser);

  /// Starts the advertising loop. Call [stop] to end.
  Future<void> start(
    BeaconSimConfig config, {
    required void Function(String status) onStatus,
    required void Function(String message) onError,
  }) async {
    if (_running) {
      await stop();
    }
    _validate(config);
    _running = true;
    _stopped = Completer<void>();
    _frameIndex = 0;

    final uuid16 = uuidBytesFromString(config.uuid);
    final mac6 = parseMacString(config.mac);
    final (t0, t1) = parseInfoType(config.infoType);
    final nameBytes = Uint8List.fromList(config.name.codeUnits);
    final ibeaconInner = buildIBeaconInner(
      uuid16: uuid16,
      major: config.major,
      minor: config.minor,
      measuredPowerDbm: config.txPowerDbm,
    );
    final infoPayload = buildSatechInfoServicePayload(
      type0: t0,
      type1: t1,
      batteryPercent: config.battery,
      mac6: mac6,
      name4: nameBytes,
    );

    final frames = <_Frame>[];
    switch (config.broadcastMode) {
      case BeaconBroadcastMode.ibeacon:
        frames.add(_Frame.iBeacon(ibeaconInner));
      case BeaconBroadcastMode.info:
        frames.add(_Frame.info(infoPayload));
      case BeaconBroadcastMode.both:
        frames.add(_Frame.iBeacon(ibeaconInner));
        frames.add(_Frame.info(infoPayload));
    }

    unawaited(_runLoop(config, frames, onStatus, onError));
  }

  Future<void> _runLoop(
    BeaconSimConfig config,
    List<_Frame> frames,
    void Function(String status) onStatus,
    void Function(String message) onError,
  ) async {
    try {
      while (_running) {
        final frame = frames[_frameIndex];
        onStatus(frame.label);
        try {
          await _channel.invokeMethod<void>('start', frame.args);
        } on PlatformException catch (e) {
          onError('Advertise failed: ${e.message ?? e.code}');
          break;
        }
        await Future<void>.delayed(Duration(milliseconds: config.dwellMs));
        if (!_running) {
          break;
        }
        try {
          await _channel.invokeMethod<void>('stop');
        } on PlatformException catch (_) {}
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (frames.length > 1) {
          _frameIndex = (_frameIndex + 1) % frames.length;
        }
      }
    } finally {
      try {
        await _channel.invokeMethod<void>('stop');
      } on PlatformException catch (_) {}
      _running = false;
      _stopped?.complete();
    }
  }

  Future<void> stop() async {
    _running = false;
    final c = _stopped;
    if (c != null) {
      await c.future;
    }
  }
}

class _Frame {
  _Frame._(this.label, this.args);

  factory _Frame.iBeacon(Uint8List inner) => _Frame._(
        'Advertising iBeacon',
        <String, Object?>{
          'mode': 'ibeacon',
          'manufacturerId': kAppleIBeaconManufacturerId,
          'payload': inner,
        },
      );

  factory _Frame.info(Uint8List service13) => _Frame._(
        'Advertising Info (0xFFE1)',
        <String, Object?>{
          'mode': 'info',
          'payload': service13,
        },
      );

  final String label;
  final Map<String, Object?> args;
}
