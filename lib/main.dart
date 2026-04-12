// Copyright (c) 2026 Y.Rakmani. All rights reserved.
//
// Beacon Simulator — Flutter UI and application logic.

import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'android_advertise_data.dart';
import 'beacon_advertiser.dart';
import 'beacon_payloads.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BeaconSimulatorApp());
}

class BeaconSimulatorApp extends StatelessWidget {
  const BeaconSimulatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Beacon Simulator',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const BeaconHomePage(),
    );
  }
}

class BeaconHomePage extends StatefulWidget {
  const BeaconHomePage({super.key});

  @override
  State<BeaconHomePage> createState() => _BeaconHomePageState();
}

class _BeaconHomePageState extends State<BeaconHomePage> {
  final _advertiser = BeaconAdvertiser();

  final _uuid = TextEditingController(
    text: '00112233-4455-6677-8899-AABBCCDDEEFF',
  );
  final _mac = TextEditingController(text: 'CA:80:D8:47:3E:DA');
  final _major = TextEditingController(text: '43690');
  final _minor = TextEditingController(text: '48059');
  final _txPower = TextEditingController(text: '-59');
  final _battery = TextEditingController(text: '100');
  final _name = TextEditingController(text: 'PLUS');
  final _infoType = TextEditingController(text: 'A1,08');
  final _dwellMs = TextEditingController(text: '1000');

  BeaconBroadcastMode _mode = BeaconBroadcastMode.both;

  String _status = 'Idle';
  String? _lastError;

  @override
  void dispose() {
    _advertiser.stop();
    _uuid.dispose();
    _mac.dispose();
    _major.dispose();
    _minor.dispose();
    _txPower.dispose();
    _battery.dispose();
    _name.dispose();
    _infoType.dispose();
    _dwellMs.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _lastError = null;
      _status = 'Checking…';
    });

    int major;
    int minor;
    int tx;
    int battery;
    int dwell;
    try {
      major = int.parse(_major.text.trim());
      minor = int.parse(_minor.text.trim());
      tx = int.parse(_txPower.text.trim());
      battery = int.parse(_battery.text.trim());
      dwell = int.parse(_dwellMs.text.trim());
    } on FormatException {
      setState(() {
        _lastError = 'Major, minor, TX power, battery, and dwell must be integers.';
        _status = 'Idle';
      });
      return;
    }

    final config = BeaconSimConfig(
      broadcastMode: _mode,
      uuid: _uuid.text.trim(),
      major: major,
      minor: minor,
      txPowerDbm: tx,
      battery: battery,
      mac: _mac.text.trim(),
      name: _name.text.trim(),
      infoType: _infoType.text.trim(),
      dwellMs: dwell,
    );

    final prep = await _advertiser.prepare(config);
    if (prep != null) {
      setState(() {
        _lastError = prep;
        _status = 'Idle';
      });
      return;
    }

    await _advertiser.start(
      config,
      onStatus: (s) {
        if (mounted) {
          setState(() => _status = s);
        }
      },
      onError: (m) {
        if (mounted) {
          setState(() {
            _lastError = m;
            _status = 'Idle';
          });
        }
      },
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _stop() async {
    await _advertiser.stop();
    if (mounted) {
      setState(() => _status = 'Idle');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SATECH-style beacon simulator'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Broadcasts the same legacy packets as beacon_simulation.py on Windows. '
            'The MAC field is only bytes inside the Info advertisement, not the phone radio address.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _uuid,
            decoration: const InputDecoration(
              labelText: 'iBeacon proximity UUID',
              border: OutlineInputBorder(),
            ),
            enabled: !_advertiser.isRunning,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _mac,
            decoration: const InputDecoration(
              labelText: 'Info payload MAC (6 octets, e.g. CA:80:D8:47:3E:DA)',
              border: OutlineInputBorder(),
            ),
            enabled: !_advertiser.isRunning,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _battery,
            decoration: const InputDecoration(
              labelText: 'Info battery byte (0–255)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            enabled: !_advertiser.isRunning,
          ),
          const SizedBox(height: 16),
          SegmentedButton<BeaconBroadcastMode>(
            segments: const [
              ButtonSegment(
                value: BeaconBroadcastMode.ibeacon,
                label: Text('iBeacon'),
              ),
              ButtonSegment(
                value: BeaconBroadcastMode.info,
                label: Text('Info'),
              ),
              ButtonSegment(
                value: BeaconBroadcastMode.both,
                label: Text('Both'),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (s) {
              if (_advertiser.isRunning) {
                return;
              }
              setState(() => _mode = s.first);
            },
          ),
          const SizedBox(height: 16),
          ExpansionTile(
            title: const Text('Advanced'),
            children: [
              TextField(
                controller: _major,
                decoration: const InputDecoration(
                  labelText: 'Major (0–65535)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                enabled: !_advertiser.isRunning,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _minor,
                decoration: const InputDecoration(
                  labelText: 'Minor (0–65535)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                enabled: !_advertiser.isRunning,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _txPower,
                decoration: const InputDecoration(
                  labelText: 'iBeacon measured power at 1m (dBm)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                enabled: !_advertiser.isRunning,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Info name (up to 4 ASCII chars)',
                  border: OutlineInputBorder(),
                ),
                enabled: !_advertiser.isRunning,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _infoType,
                decoration: const InputDecoration(
                  labelText: 'Info type (e.g. A1,08)',
                  border: OutlineInputBorder(),
                ),
                enabled: !_advertiser.isRunning,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _dwellMs,
                decoration: const InputDecoration(
                  labelText: 'Dwell per frame (ms)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                enabled: !_advertiser.isRunning,
              ),
              const SizedBox(height: 12),
            ],
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Status'),
            subtitle: Text(_status),
          ),
          if (_lastError != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _lastError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton.icon(
                onPressed: _advertiser.isRunning ? null : _start,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: !_advertiser.isRunning ? null : _stop,
                icon: const Icon(Icons.stop),
                label: const Text('Stop'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: () => _advertiser.openAppSettings(),
                child: const Text('App settings'),
              ),
              TextButton(
                onPressed: () => _advertiser.openBluetoothSettings(),
                child: const Text('Bluetooth settings'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ExpansionTile(
            title: const Text('Debug: wire-level preview'),
            subtitle: const Text('Compare with python beacon_simulation.py --dry-run'),
            children: [
              Builder(
                builder: (context) {
                  try {
                    final uuid16 = uuidBytesFromString(_uuid.text.trim());
                    final major = int.parse(_major.text.trim());
                    final minor = int.parse(_minor.text.trim());
                    final tx = int.parse(_txPower.text.trim());
                    final ib = buildIBeaconLegacyAd(
                      uuid16: uuid16,
                      major: major,
                      minor: minor,
                      measuredPowerDbm: tx,
                    );
                    final mac6 = parseMacString(_mac.text.trim());
                    final (t0, t1) = parseInfoType(_infoType.text.trim());
                    final nameB = Uint8List.fromList(_name.text.trim().codeUnits);
                    final inf = buildSatechInfoLegacyAd(
                      type0: t0,
                      type1: t1,
                      batteryPercent: int.parse(_battery.text.trim()),
                      mac6: mac6,
                      name4: nameB,
                    );
                    return SelectableText(
                      'iBeacon AD (${ib.length} B):\n${formatHex(ib)}\n\n'
                      'Info AD (${inf.length} B):\n${formatHex(inf)}',
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    );
                  } catch (e) {
                    return Text(
                      'Could not build preview: $e',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Native channel: ${BeaconSimConfig.methodChannelName} · '
            'Apple mfg id: 0x${kAppleIBeaconManufacturerId.toRadixString(16)} · '
            'Service: $kSatechInfoServiceUuid',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              '© 2026 Y.Rakmani. All rights reserved.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
