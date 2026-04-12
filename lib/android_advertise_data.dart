// Copyright (c) 2026 Y.Rakmani. All rights reserved.
//
// Android BluetoothLeAdvertiser / 16-bit UUID constants for SATECH Info + iBeacon.

/// Standard 128-bit form for 16-bit UUID **0xFFE1** (same as Android `ParcelUuid` canonical string).
const String kSatechInfoServiceUuid = '0000ffe1-0000-1000-8000-00805f9b34fb';

/// Apple company ID for iBeacon manufacturer data (argument to `addManufacturerData`).
const int kAppleIBeaconManufacturerId = 0x004c;
