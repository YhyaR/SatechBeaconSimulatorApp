// Copyright (c) 2026 Y.Rakmani. All rights reserved.

import 'dart:typed_data';

import 'package:beacon_simulator/beacon_payloads.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iBeacon legacy AD matches beacon_simulation.py --dry-run defaults', () {
    final uuid16 = uuidBytesFromString('00112233-4455-6677-8899-AABBCCDDEEFF');
    final ad = buildIBeaconLegacyAd(
      uuid16: uuid16,
      major: 43690,
      minor: 48059,
      measuredPowerDbm: -59,
    );
    expect(
      formatHex(ad),
      '02 01 06 1A FF 4C 00 02 15 00 11 22 33 44 55 66 77 88 99 AA BB CC DD EE FF AA AA BB BB C5',
    );
  });

  test('SATECH Info legacy AD matches beacon_simulation.py --dry-run defaults', () {
    final mac = parseMacString('CA:80:D8:47:3E:DA');
    final ad = buildSatechInfoLegacyAd(
      type0: 0xa1,
      type1: 0x08,
      batteryPercent: 100,
      mac6: mac,
      name4: Uint8List.fromList('PLUS'.codeUnits),
    );
    expect(
      formatHex(ad),
      '02 01 06 03 03 E1 FF 10 16 E1 FF A1 08 64 CA 80 D8 47 3E DA 50 4C 55 53',
    );
  });
}
