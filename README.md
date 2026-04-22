# Beacon Simulator

Android SATECH-style BLE beacon simulator built with Flutter.

## Overview

This project simulates SATECH-style Bluetooth Low Energy (BLE) beacons on Android devices. It broadcasts standard Apple iBeacon advertisements along with custom Info packets (0xFFE1) following the SATECHBeacon Development API & Command Guide (V1.1).

## Features

- **iBeacon Broadcasting**: Standard Apple iBeacon format with configurable UUID, Major, Minor, and measured power
- **Custom Info Packets**: Service data advertising with device type, battery level, MAC address, and device name
- **Legacy AD Payload**: Compliant with 31-byte Bluetooth advertisement packet limits
- **Python Simulation Tool**: Includes `beacon_simulation.py` for testing and packet generation on desktop platforms

## Requirements

- Flutter SDK ^3.10.4
- Dart SDK ^3.10.4
- Android device with Bluetooth LE capability
- Python 3.9+ (for simulation tool)

## Dependencies

### Flutter Dependencies
- `flutter_ble_peripheral`: ^2.1.0 - BLE peripheral mode advertising
- `cupertino_icons`: ^1.0.8 - iOS style icons

### Python Dependencies (for simulation tool)
See requirements in `beacon_simulation.py` header comments.

## Project Structure

```
beacon_simulator/
├── lib/
│   ├── main.dart                 # Main application entry point
│   ├── beacon_advertiser.dart    # BLE advertising logic
│   ├── beacon_payloads.dart      # Packet payload builders
│   └── android_advertise_data.dart # Android-specific advertise data
├── android/                      # Android platform configuration
├── test/                         # Unit tests
├── beacon_simulation.py          # Python BLE simulation tool
├── pubspec.yaml                  # Flutter package configuration
└── README.md                     # This file
```

## Usage

### Flutter App (Android)

1. Ensure Bluetooth is enabled on your Android device
2. Run the app: `flutter run`
3. Configure beacon parameters (UUID, Major, Minor, etc.)
4. Start advertising to broadcast beacon signals

### Python Simulation Tool

The `beacon_simulation.py` script can be used for testing packet generation:

```bash
python beacon_simulation.py --help
```

**Note**: On Windows, real BLE transmission requires WinRT. Some Bluetooth stacks may reject oversize or invalid advertisement combinations.

## Advertisement Format

### iBeacon Packet
- Flags (0x01)
- Manufacturer Specific Data (0xFF)
  - Company ID: Apple (0x004C)
  - iBeacon preamble: 0x02 0x15
  - UUID (16 bytes)
  - Major (2 bytes)
  - Minor (2 bytes)
  - Measured Power (1 byte)

### Info Packet (0xFFE1)
- Flags (0x01)
- Complete 16-bit UUID List (0x03)
- Service Data (0x16)
  - UUID (little-endian)
  - Device Type
  - Battery Level
  - MAC Address
  - Device Name

## License

Copyright (c) 2026 Y.Rakmani. All rights reserved.

## Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Bluetooth LE Advertising Guide](https://developer.android.com/guide/topics/connectivity/bluetooth-le-advertising)
- [SATECHBeacon Development API & Command Guide (V1.1)](https://github.com/YuukiRakmani/SATECHBeacon_Documents/blob/main/SATECHBeacon%E9%96%8B%E7%99%BAAPI%E3%83%BB%E5%91%BD%E4%BB%A4%E3%82%AC%E3%82%A4%E3%83%89_V1.1.pdf)
