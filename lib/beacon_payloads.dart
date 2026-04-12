// Copyright (c) 2026 Y.Rakmani. All rights reserved.
//
// Legacy BLE payload builders (Dart port of beacon_simulation.py semantics).

import 'dart:typed_data';

/// SATECH-style legacy BLE payloads matching [beacon_simulation.py].

/// Parses a UUID string into 16 bytes (RFC order, same as Python `UUID.bytes`).
Uint8List uuidBytesFromString(String input) {
  final hex = input.replaceAll('-', '').toLowerCase();
  if (hex.length != 32) {
    throw FormatException('UUID must be 32 hex digits', input);
  }
  final out = Uint8List(16);
  for (var i = 0; i < 16; i++) {
    out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

/// iBeacon manufacturer-specific data **after** company ID 0x004C (Android adds the ID).
Uint8List buildIBeaconInner({
  required Uint8List uuid16,
  required int major,
  required int minor,
  required int measuredPowerDbm,
}) {
  if (uuid16.length != 16) {
    throw ArgumentError.value(uuid16, 'uuid16', 'must be 16 bytes');
  }
  if (major < 0 || major > 0xffff || minor < 0 || minor > 0xffff) {
    throw ArgumentError('major and minor must be 0..65535');
  }
  final inner = BytesBuilder(copy: false);
  inner.addByte(0x02);
  inner.addByte(0x15);
  inner.add(uuid16);
  inner.add(_uint16BigEndian(major));
  inner.add(_uint16BigEndian(minor));
  inner.addByte(_i8AsU8(measuredPowerDbm));
  final ad = inner.toBytes();
  if (ad.length > 24) {
    throw StateError('iBeacon inner exceeds expected size');
  }
  return ad;
}

/// Full legacy AD (flags + manufacturer) for dry-run / debugging — same layout as Python.
Uint8List buildIBeaconLegacyAd({
  required Uint8List uuid16,
  required int major,
  required int minor,
  required int measuredPowerDbm,
}) {
  final inner = buildIBeaconInner(
    uuid16: uuid16,
    major: major,
    minor: minor,
    measuredPowerDbm: measuredPowerDbm,
  );
  final mfgBody = BytesBuilder(copy: false);
  mfgBody.addByte(0x4c);
  mfgBody.addByte(0x00);
  mfgBody.add(inner);
  final mfgAd = BytesBuilder(copy: false);
  mfgAd.addByte(mfgBody.length + 1);
  mfgAd.addByte(0xff);
  mfgAd.add(mfgBody.toBytes());
  final flags = Uint8List.fromList([0x02, 0x01, 0x06]);
  final ad = Uint8List.fromList([...flags, ...mfgAd.toBytes()]);
  if (ad.length > 31) {
    throw StateError('iBeacon AD exceeds 31 bytes');
  }
  return ad;
}

/// 13-byte service data body for SATECH Info (UUID 0xFFE1 on wire).
Uint8List buildSatechInfoServicePayload({
  required int type0,
  required int type1,
  required int batteryPercent,
  required Uint8List mac6,
  required Uint8List name4,
}) {
  if (batteryPercent < 0 || batteryPercent > 255) {
    throw ArgumentError('battery must be 0..255');
  }
  if (mac6.length != 6) {
    throw ArgumentError.value(mac6, 'mac6', 'must be 6 bytes');
  }
  final name = Uint8List(4);
  final src = name4.length > 4 ? name4.sublist(0, 4) : name4;
  name.setAll(0, src);
  final payload = Uint8List(13);
  payload[0] = type0 & 0xff;
  payload[1] = type1 & 0xff;
  payload[2] = batteryPercent & 0xff;
  payload.setRange(3, 9, mac6);
  payload.setRange(9, 13, name);
  return payload;
}

/// Full legacy AD for dry-run (flags + uuid list + service data).
Uint8List buildSatechInfoLegacyAd({
  required int type0,
  required int type1,
  required int batteryPercent,
  required Uint8List mac6,
  required Uint8List name4,
}) {
  final servicePayload = buildSatechInfoServicePayload(
    type0: type0,
    type1: type1,
    batteryPercent: batteryPercent,
    mac6: mac6,
    name4: name4,
  );
  final flags = Uint8List.fromList([0x02, 0x01, 0x06]);
  final uuidList = Uint8List.fromList([0x03, 0x03, 0xe1, 0xff]);
  final sdBody = BytesBuilder(copy: false);
  sdBody.addByte(0xe1);
  sdBody.addByte(0xff);
  sdBody.add(servicePayload);
  final sdAd = BytesBuilder(copy: false);
  sdAd.addByte(1 + sdBody.length);
  sdAd.addByte(0x16);
  sdAd.add(sdBody.toBytes());
  final ad = Uint8List.fromList([
    ...flags,
    ...uuidList,
    ...sdAd.toBytes(),
  ]);
  if (ad.length > 31) {
    throw StateError('Info AD exceeds 31 bytes');
  }
  return ad;
}

Uint8List parseMacString(String mac) {
  final parts = mac.replaceAll('-', ':').split(':');
  if (parts.length != 6) {
    throw FormatException('MAC must have 6 octets', mac);
  }
  final out = Uint8List(6);
  for (var i = 0; i < 6; i++) {
    out[i] = int.parse(parts[i].trim(), radix: 16);
  }
  return out;
}

(int, int) parseInfoType(String s) {
  final parts = s.replaceAll(' ', '').split(',');
  if (parts.length != 2) {
    throw FormatException('info-type must look like A1,08', s);
  }
  return (int.parse(parts[0], radix: 16), int.parse(parts[1], radix: 16));
}

String formatHex(Uint8List bytes, {String sep = ' '}) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(sep);
}

int _i8AsU8(int v) {
  final x = v.clamp(-128, 127).toInt();
  return x & 0xff;
}

Uint8List _uint16BigEndian(int v) {
  final u = Uint8List(2);
  u[0] = (v >> 8) & 0xff;
  u[1] = v & 0xff;
  return u;
}
