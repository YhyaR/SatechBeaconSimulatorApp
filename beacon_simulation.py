"""
Simulate SATECHBeacon legacy BLE advertising: standard Apple iBeacon + Info (0xFFE1).

Layout matches *SATECHBeacon Development API & Command Guide* (V1.1):
- iBeacon: Flags + Manufacturer Data (Apple 0x004C, inner 0x02 0x15 + UUID + Major + Minor + Measured Power).
- Info: Flags + Complete 16-bit UUID list (0xFFE1) + Service Data 0x16 (UUID LE + Type + Battery + MAC + Name).

On Windows, real transmission uses WinRT (BluetoothLEAdvertisementPublisher).
Requires:
- Python 3.9+ (including 3.13)
- `pip install -r requirements.txt`
- Bluetooth LE capable adapter; some stacks reject oversize or invalid combos.
"""

from __future__ import annotations

import argparse
import sys
import time
import uuid as uuid_lib
from typing import Iterable, Sequence


# --- Packet builders (legacy AD payload, 31-byte limit per packet) ---


def build_ibeacon_legacy_ad(
    uuid: uuid_lib.UUID,
    major: int,
    minor: int,
    measured_power_dbm: int = -59,
) -> bytes:
    """
    Apple iBeacon in a single legacy advertisement (flags + manufacturer data only).
    """
    if not (0 <= major <= 0xFFFF and 0 <= minor <= 0xFFFF):
        raise ValueError("major and minor must be 0..65535")
    u = uuid.bytes
    flags = bytes([0x02, 0x01, 0x06])
    # Manufacturer: Company ID Apple 0x004C LE + iBeacon preamble + payload
    inner = bytes([0x02, 0x15]) + u + major.to_bytes(2, "big") + minor.to_bytes(2, "big")
    inner += _i8_as_u8(measured_power_dbm)
    mfg_body = b"\x4C\x00" + inner
    mfg_ad = bytes([len(mfg_body) + 1, 0xFF]) + mfg_body
    ad = flags + mfg_ad
    if len(ad) > 31:
        raise ValueError("iBeacon AD exceeds 31 bytes")
    return ad


def build_satech_info_legacy_ad(
    info_type: tuple[int, int] = (0xA1, 0x08),
    battery_percent: int = 100,
    mac: bytes | None = None,
    name: bytes | None = None,
) -> bytes:
    """
    SATECH "Info" channel: 0xFFE1 service + 13-byte service payload.

    Doc example decodes as: Type (2 B) A1 08, Battery (1) 0x64, MAC (6), Name (4) ASCII.
    Example name bytes 50 4C 55 53 = \"PLUS\".
    """
    if not (0 <= battery_percent <= 255):
        raise ValueError("battery_percent must be 0..255")
    t0, t1 = info_type
    if mac is None:
        mac = bytes([0xC0, 0xAC, 0xF5, 0x24, 0x3F, 0x23])
    elif len(mac) != 6:
        raise ValueError("mac must be 6 bytes")
    if name is None:
        name = b"PLUS"
    name = name[:4].ljust(4, b"\x00")

    service_payload = bytes([t0, t1, battery_percent]) + mac + name
    if len(service_payload) != 13:
        raise ValueError("internal: Info service payload must be 13 bytes")

    flags = bytes([0x02, 0x01, 0x06])
    uuid_list = bytes([0x03, 0x03, 0xE1, 0xFF])
    # Service Data: type 0x16, 16-bit UUID LE E1 FF + 13 bytes
    sd_body = b"\xE1\xFF" + service_payload
    sd_ad = bytes([1 + len(sd_body), 0x16]) + sd_body
    ad = flags + uuid_list + sd_ad
    if len(ad) > 31:
        raise ValueError("Info AD exceeds 31 bytes")
    return ad


def _i8_as_u8(v: int) -> bytes:
    """iBeacon measured power is a signed int8 on the wire as one byte."""
    x = max(-128, min(127, int(v)))
    return bytes([x & 0xFF])


def format_ad_hex(ad: bytes) -> str:
    return ad.hex(" ", 1).upper()


def iter_ad_sections(ad: bytes) -> Iterable[tuple[int, bytes]]:
    """Parse legacy AD into (ad_type, data) tuples (data excludes type)."""
    i = 0
    while i < len(ad):
        length = ad[i]
        if length == 0:
            break
        i += 1
        if i + length > len(ad):
            break
        ad_type = ad[i]
        data = ad[i + 1 : i + length]
        i += length
        yield ad_type, data


# --- Windows WinRT publisher (optional) ---


def _buffer_from_bytes(data: bytes):
    from winrt.windows.storage.streams import DataWriter

    w = DataWriter()
    w.write_bytes(data)
    return w.detach_buffer()


def _apply_winrt_ad(publisher, ad: bytes) -> None:
    """
    Apply a legacy AD packet to a WinRT publisher.
    Windows blocks manual 'Flags' (0x01) and 'UUID List' (0x03) as raw sections.
    We must use specialized properties or omit them.
    """
    from winrt.windows.devices.bluetooth.advertisement import (
        BluetoothLEAdvertisementDataSection,
        BluetoothLEManufacturerData,
    )

    adv = publisher.advertisement
    adv.data_sections.clear()
    adv.manufacturer_data.clear()
    # We omit service_uuids because it often fails with 'The parameter is incorrect'
    # and Windows adds its own Flags automatically.

    for ad_type, data in iter_ad_sections(ad):
        if ad_type == 0x01:  # Flags (Windows manages this)
            continue
        if ad_type == 0x03:  # 16-bit UUID List (Windows managed, or omit)
            continue
        if ad_type == 0xFF:  # Manufacturer Data (iBeacon)
            if len(data) >= 2:
                company_id = int.from_bytes(data[:2], "little")
                mfg_payload = data[2:]
                mfg_data = BluetoothLEManufacturerData(company_id, _buffer_from_bytes(mfg_payload))
                adv.manufacturer_data.append(mfg_data)
            continue

        # Everything else (like 0x16 Service Data) as raw section
        section = BluetoothLEAdvertisementDataSection(ad_type, _buffer_from_bytes(data))
        adv.data_sections.append(section)


def _start_winrt_rotation(
    frames: Sequence[bytes],
    dwell_ms: int,
    stop_after_s: float | None,
) -> None:
    from winrt.windows.devices.bluetooth.advertisement import BluetoothLEAdvertisementPublisher

    publisher = BluetoothLEAdvertisementPublisher()
    t0 = time.monotonic()
    try:
        while True:
            for ad in frames:
                _apply_winrt_ad(publisher, ad)
                publisher.start()
                time.sleep(max(0.001, dwell_ms / 1000.0))
                publisher.stop()
                # Windows radio stack needs a small gap to settle between identity flips
                time.sleep(0.1)
            if stop_after_s is not None and (time.monotonic() - t0) >= stop_after_s:
                break
    finally:
        try:
            publisher.stop()
        except Exception:
            pass


def run_dry_run(frames: Sequence[tuple[str, bytes]]) -> None:
    for label, ad in frames:
        print(f"--- {label} ({len(ad)} B) ---")
        print(format_ad_hex(ad))
        for ad_type, data in iter_ad_sections(ad):
            print(f"  type 0x{ad_type:02X}: {data.hex(' ', 1).upper()}")
        print()


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="SATECH-style iBeacon + Info BLE simulation (Windows)")
    p.add_argument(
        "--mode",
        choices=("ibeacon", "info", "both"),
        default="both",
        help="Which advertisement to send or print",
    )
    p.add_argument("--uuid", default="00112233-4455-6677-8899-AABBCCDDEEFF", help="iBeacon UUID")
    p.add_argument("--major", type=int, default=43690, help="iBeacon major (0-65535)")
    p.add_argument("--minor", type=int, default=48059, help="iBeacon minor (0-65535)")
    p.add_argument("--tx-power", type=int, default=-59, help="iBeacon measured power at 1m (dBm)")
    p.add_argument("--battery", type=int, default=100, help="Info channel battery byte 0-255")
    p.add_argument(
        "--info-type",
        default="A1,08",
        help='Info type two bytes hex, e.g. "A1,08"',
    )
    p.add_argument(
        "--mac",
        default="CA:80:D8:47:3E:DA",
        help="Info MAC as CA:80:D8:47:3E:DA",
    )
    p.add_argument("--name", default="PLUS", help="Info name, up to 4 ASCII chars")
    p.add_argument("--dwell-ms", type=int, default=1000, help="Time each frame stays on air (both mode)")
    p.add_argument("--duration", type=float, default=0.0, help="Stop after N seconds (0 = run until Ctrl+C)")
    p.add_argument(
        "--dry-run",
        action="store_true",
        help="Only print AD bytes; do not use the radio",
    )
    args = p.parse_args(argv)

    uid = uuid_lib.UUID(args.uuid)
    mac_parts = [int(x, 16) for x in args.mac.replace("-", ":").split(":")]
    if len(mac_parts) != 6:
        print("--mac must have 6 octets", file=sys.stderr)
        return 2
    mac = bytes(mac_parts)
    try:
        t0_s, t1_s = args.info_type.replace(" ", "").split(",")
        info_type = (int(t0_s, 16), int(t1_s, 16))
    except ValueError:
        print('--info-type must look like "A1,08"', file=sys.stderr)
        return 2

    name_b = args.name.encode("ascii", errors="replace")[:4]

    frames: list[tuple[str, bytes]] = []
    if args.mode in ("ibeacon", "both"):
        frames.append(("iBeacon", build_ibeacon_legacy_ad(uid, args.major, args.minor, args.tx_power)))
    if args.mode in ("info", "both"):
        frames.append(
            (
                "Info (0xFFE1)",
                build_satech_info_legacy_ad(
                    info_type=info_type,
                    battery_percent=args.battery,
                    mac=mac,
                    name=name_b,
                ),
            )
        )

    if args.dry_run:
        run_dry_run(frames)
        return 0

    try:
        # Check for core WinRT advertisement support
        import winrt.windows.devices.bluetooth.advertisement
        # These are common dependencies that might be missing in partial installs
        import winrt.windows.foundation
        import winrt.windows.foundation.collections
        import winrt.windows.storage.streams
    except ImportError as e:
        print(
            f"Live advertising needs WinRT packages. (Missing: {e.name if hasattr(e, 'name') else e})\n"
            "Try: pip install -r requirements.txt\n",
            file=sys.stderr,
        )
        run_dry_run(frames)
        return 1

    ad_only = [b for _, b in frames]
    stop_after = args.duration if args.duration > 0 else None
    print("Advertising; Ctrl+C to stop.")
    try:
        _start_winrt_rotation(ad_only, args.dwell_ms, stop_after)
    except KeyboardInterrupt:
        print("\nStopped.")
    except OSError as e:
        print(f"Bluetooth publisher error: {e}", file=sys.stderr)
        run_dry_run(frames)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
