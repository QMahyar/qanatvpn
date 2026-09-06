# YOURVPN

A censorship-resistant VPN client for Android and Windows, built for highly
censored networks. WireGuard and AmneziaWG are first-class citizens — every
obfuscation parameter (Jc, Jmin/Jmax, H1–H4, S1/S2, I1–I5, Id) is fully
editable — combined with sing-box's advanced routing engine (30-field rules,
logical AND/OR groups, urltest auto-selection) behind an original
Material 3 Expressive interface in English and Persian (RTL).

Original, self-contained code. No copied strings, configs, or branding from
other VPN clients. Licensed AGPL-3.0.

## Features

- **WireGuard + AmneziaWG (AWG)** — full parameter surface with presets
  (quic-mimic / balanced / stealth) plus per-field control, random profile
  generation, and validation against the AWG spec (H1∩H2=∅, S1+56≠S2,
  Jmax<MTU, …).
- **All common protocols** — VLESS (Reality/Vision), VMess, Trojan,
  Shadowsocks (incl. 2022), Hysteria2, TUIC, SSH; transports ws / gRPC /
  http / httpupgrade / xhttp with ECH where the engine supports it.
- **Import anything** — share links (`vless://`, `vmess://`, `ss://`,
  `hysteria2://`, `tuic://`, `trojan://`, WireGuard INI), sing-box JSON, and
  Clash/mihomo YAML subscriptions or pasted blobs, with per-line error
  reporting.
- **Advanced routing** — typed 30-field rule editor, AND/OR rule groups,
  selector/urltest groups with latency testing, per-app split tunneling
  (Android), rule sets with bundled CN geoip/geosite fallbacks.
- **Fail-closed security posture** — engine crashes block rather than leak;
  connect-order enforcement is tested; DNS and route rules are compiled and
  validated with the real engine before connect.
- **Daily-driver details** — encrypted export/import of all settings
  (Argon2id + AES-256-GCM), in-app updates with sha256 verification, live
  logs, diagnostics, and a 3-step onboarding wizard.

## Platforms

| Platform | Status | Engine |
|----------|--------|--------|
| Android 8+ | MVP | `libbox` (gomobile aar built from the pinned `amnezia-box` fork, `with_awg`) |
| Windows 10+ | MVP | bundled `sing-box.exe` (same fork, `with_awg,with_purego`) subprocess |

## Download

Grab the latest APK (`arm64-v8a` for most phones) or the Windows zip from
[Releases](https://github.com/QMahyar/yourvpn/releases). Every artifact has a
sibling `.sha256`; the in-app updater verifies downloads automatically.

## Build from source

Requirements: Flutter 3.47.2, Go 1.25, JDK 17, Android NDK r28, and git
submodules.

```bash
git clone --recurse-submodules https://github.com/QMahyar/yourvpn.git
cd yourvpn

flutter pub get && flutter gen-l10n

# Android: build the engine aar from the pinned fork, then the app
make -C go/amnezia-box lib_android
cp go/amnezia-box/libbox.aar android/app/libs/
flutter build apk --release --split-per-abi

# Windows: use the prebuilt pinned sing-box.exe (scripts/libbox.ps1 builds it)
flutter build windows
```

## Testing

```bash
flutter test --coverage          # unit + widget + golden tests
flutter analyze                  # lints (RTL-safe EdgeInsets enforced)
sing-box check -c profiles/config.wg-awg.json   # shipped profile validity
scripts/leak_test.sh             # on-device leak scenarios (requires device)
```

## Privacy

The app contacts GitHub (release checks + geo/rule-set updates) and your
subscription endpoints — nothing else. No analytics, no crash reporting, no
telemetry. Engine logs stay on-device. Secrets are stored app-locally.

## License

AGPL-3.0 — see [LICENSE](LICENSE). Third-party components and their licenses
are listed in [THIRD_PARTY.md](THIRD_PARTY.md). If you distribute modified
binaries, AGPL §13 requires you to offer your corresponding source.

This project is provided as-is, without warranty. Using a VPN may violate
local laws or terms of service in your jurisdiction; you are responsible for
compliance.
