# Spec: YOURVPN — Original Flutter+Go VPN (All Protocols, WG+AmneziaWG Priority First, 1 TUN Fork, Max Firewall) — v2.0 EXTREME DETAIL

> Generated from `goal.md` FROZEN FINAL (2026-08-30 07:30) — Reverted to **All protocols, WG+AmneziaWG priority first** — `Apply all 3 and freeze` + 4 extra deeps + Hallmark blended prototype. This spec is the gated source of truth. Do not code beyond this spec without updating it.
> Stack: Flutter 3.47.2 + Dart + `material_3_expressive` 45 M3E + `cue`/`motion_kit`/`transit_kit` + Go 1.25 (`hoaxisr/amnezia-box` fork `with_awg` + `XTLS/Xray-core`) via gomobile + original MethodChannel. Platforms: Android + Windows first (MVP). License: AGPL-3.0 self-contained (no external mentions in README/docs, LICENSE contains third-party notices). Source-driven from official docs.

---

## Objective

**What we're building and why:** A polished original public VPN client (AGPL) that **wins or ties** vs all 13 researched VPNs (`01-Karing … 13-Matsuri-SagerNet`) on every capability row, with **WG + AmneziaWG (all values Jc/Jmin/Jmax/S1-S4/H1-H4/I1-I5/Id/Ip/Ib + ChaCha) as the star** for highly censored networks, plus full multi-protocol coverage (VLESS+Reality/Vision/XHTTP, VMess, Trojan, SS/SS2022, Hysteria2, TUIC, SSH, Tor chaining, WG/AWG). It uses **one TUN unified via `amnezia-box` fork** (`with_awg` tag, FakeIP fix), **sing-box advanced routing** (30 `route.rules` fields + 3-tier groups + `rule_set` SRS binary + FakeIP 198.18/15 + uTLS + max WFP firewall), **Material 3 Expressive UI** (Slipnet-like Jetpack Compose M3 in Flutter), **guided 3-step wizard**, **daily platform-aware GitHub updates** with 6h stale-while-revalidate cache, **EN + FA RTL** + a11y, **full diagnostics** (DNS scanner 0-6 + Prism HMAC + Simple Ping + PingRoute + network_reachability Rust), **original branding** (no external thanks in docs).

**Who is the user?**

- **Primary:** Users in Iran, Russia, China on DPI (TSPU, GFW) who need WG fingerprinted traffic to look like QUIC/DNS/STUN via AmneziaWG junk, plus fallback to VLESS Reality when WG blocked. They know `amnezia` values and want sliders for H1-H4, not just presets.
- **Secondary:** Power users who manage 7 subs (Clash YAML, sing-box JSON, vmess/vless/ss/trojan/hysteria2/tuic/WG INI, SIP008) and fine-tune 30-field rules (`process_name` on Windows, `package_name` on Android, `wifi_ssid`, `rule_set` SRS) and 3-tier groups (`HKG-AUTO urltest 300s` → `MANUAL selector` → `PROXY` + `TOR-CHAIN relay`).

**What does success look like?** Eight testable conditions in Success Criteria below — capability win via script, leak-free via 7 tests, AmneziaWG handshake via fork sanity, Tor isolated, wizard polished, updates platform-aware, build reproducible, compliance ready.

**Out of scope (v1):** iOS/macOS/Linux full, browser extension, server-side panel/management (SlipGate-like), paid/monetized infra, pure-Rust core rewrite, mentions of other VPN projects in README/docs (internal fork usage is not mentioned externally).

**User stories (must pass, with acceptance):**

1. **WG+AWG star on DPI:** As a user on LTE with TSPU DPI that blocks vanilla WireGuard, I open wizard → grant VpnService → allow battery exemption (`isIgnoringBatteryOptimizations` → `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, VPN acceptable use) → pick allowlist `Telegram+Chrome` → connect to HKG-02 WG+AWG endpoint (`jc 6, jmin 8, jmax 48, s1 123, h1 … , i1 …`, `awg` type via `hoaxisr/amnezia-box` libbox.aar sanity `strings libbox.so | grep -c amneziawg >0`) → `ipleak.net` shows VPN IP, `dnsleaktest.com` Extended shows VPN DNS, YouTube loads, Telegram calls work, and Airplane toggle triggers max firewall block (no leak per 7 tests).
2. **All-protocols fallback:** As a power user on Windows 11, I import Clash YAML + `vless://` (Reality+Vision+XHTTP) + `ss://` + `[Interface]` WG INI (preshared_key) + `hysteria2://` (mport, hopInterval) in one sub update (ETag 24h, 6h cache) → group auto-sorts via 3-tier (`HKG-AUTO` filter `香港|HK` → `MANUAL` `.*` → `PROXY` + `TOR-CHAIN` relay `tor-socks 127.0.0.1:9050`) → I set `PROCESS-NAME,steam.exe,DIRECT` + `wifi_ssid,My WIFI,DIRECT` + `rule_set,geosite-cn,DIRECT` via full 30-field editor + logical `and` → `steam.exe` bypasses, `chrome.exe` via PROXY, `geosite-cn` direct, and `MethodChannel` `setRoutingRules()` enforces via `route.rules` + `rule_set` SRS binary.
3. **Priority build order:** As a maintainer, I see WG/AWG + core routing land week 1-2, VLESS/VMess/Trojan/SS week 3, Hysteria2/TUIC/SSH/Tor week 4 — so the star (WG+AWG) is testable earliest, and full win vs 13 lands by week 4, not after 9 weeks.
4. **Updates platform-aware:** As a maintainer, I push `geosite-cn.srs` + app `v1.2.3` to GitHub Releases → user's daily 24h ETag check fetches `.srs` via `download_detour: proxy` with `If-None-Match`, and platform-aware updater shows `Update v1.2.3 for windows-x64` (asset `yourvpn_v1.2.3_windows-x64.zip`) vs `android-arm64-v8a.apk`, with changelog + `latest.json` platform map, without hitting 60/hr unauth limit thanks to 6h `stale-while-revalidate` + `x-ratelimit-reset`/`retry-after` handling (sesori pattern).
5. **Tor chaining with WG:** As a user needing WG→WG chain, I set `chain` outbound `tor → wg` via Tor sidecar on `127.0.0.1:9050` → sing-box `socks` detour `tor-socks`, and if Tor entry blocked, sing-box stays up (no `FATAL start outbound/tor` per #4200), falling back to `block`.

---

## Tech Stack

| Layer | Choice | Version / Pin | Why + source-driven reference |
|---|---|---|---|
| UI | Flutter + Dart, **material_3_expressive** (Slipnet-like) | Flutter 3.47.2, Dart 3.13, `material_3_expressive` 1.1.1 (45 M3E, needs `material_ui` 1.1.0) + `motor` `material_new_shapes` `dynamic_color` via `subosito/flutter-action@v2`, `cue` 0.3.1 physics-first, `flutter_motion_kit` 60fps, `transit_kit` 384 transitions | Slipnet uses Jetpack Compose M3; this is its Flutter faithful: 45 M3E widgets, spring physics, shape morph, liquid indicators, `M3EMaterialApp`/`M3ETheme` — polished, editorial trust, plus Hum push shift. Blend validated in `prototype-final.html` Bento×Hum. |
| i18n/RTL/a11y | `flutter_localizations` + `intl` + ARB | `EdgeInsetsDirectional`, `Semantics`, `MediaQuery.textScaleFactor` clamped 0.9-1.35, `ReduceMotion` | EN + FA RTL (like GRoute), ICU plural, 200% scale, WCAG AA, `flutterspecialists.eu` |
| State | `flutter_riverpod` 2.0 + `go_router` + `drift` + `flutter_secure_storage` + `flutter_cache_manager` | Gate VPN Feature-Based MVVM | Riverpod, `compute()` isolates for CSV/rule parsing, 6h stale-while-revalidate |
| Diagnostics | `drift` sqlite + `flutter_secure_storage` + `network_reachability` Rust + `fl_chart` | Drift, Rust stability 0-100 + DNS hijack, Slipnet scanner 0-6 + Prism HMAC, PingRoute per-hop | DNS scanner Simple/Advanced/E2E/Prism, Simple Ping TCP 5000ms, sort by ping, traceroute |
| Core routing | Go `amnezia-box` fork (internal) | `hoaxisr/amnezia-box` `awg-1.14-rc1` (fork of `amnezia-vpn/sing-box`), Go 1.25.x, NDK 28, JDK 17, `gomobile bind -androidapi 24 -tags with_gvisor,with_quic,with_dhcp,with_wireguard,with_utls,with_acme,with_clash_api,with_awg` | Adds `awg` endpoint (Jc/S1/H1/I1 + FakeIP DNS fix via `dnsRouter.Lookup`) to vanilla sing-box (which rejects AmneziaWG per #2557 wontfix). 1 TUN unified, tracks `dev-next`. Internal, not in README. Alternative `sing-box-lx` (thin, XHTTP/MASQUE) equivalent. |
| Secondary core | XTLS/Xray-core | 26.x, Go 1.25 | Reality/Vision edge where Xray leads, side lib for VLESS edge cases |
| VPN abstraction | **Original Flutter MethodChannel + Go libbox** (self-contained) | `MethodChannel` `vpn_service` Dart ↔ Go `Libbox.setup()` + `VpnService.Builder` + `protect(fd)` + `Service.startForeground()` | No `vpnclient_engine_flutter` (avoids Extended GPL attribution per `VPNclient/VPNclient-engine-flutter` LICENSE extended GPL v3 clause 5). Source-driven from `developer.android.com` VpnService/Doze, not copy. |
| Foreground | `flutter_foreground_task` | `foregroundServiceType: dataSync|remoteMessaging`, `FOREGROUND_SERVICE_DATA_SYNC` | `Service.startForeground()` + `isIgnoringBatteryOptimizations()` → `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` (acceptable for VPN per `developer.android.com/training/monitoring-device-state/doze-standby` + `support.google.com/googleplay/answer/12564964` declaration) |
| Updates | `workmanager` + `package_info_plus` + `http` | `flutter_github_releases_service` pattern, `http/testing` for `GitHubRateLimitException` (sesori) | Daily 24h, ETag, `latest.json` per-platform, retry-after, 6h cache |
| Build | Flutter + Go + Gomobile | `gomobile` (SagerNet fork), `geodat2srs` | `make lib_android` → `libbox.aar` + `libbox-legacy.aar` → `android/app/libs/` → `flutter build apk --split-per-abi` |
| Protocols | All, WG/AWG priority first | VLESS+Reality/Vision/XHTTP, VMess, Trojan, SS/SS2022, Hysteria2 (Brutal/BBR, salamander, mport), TUIC v5, WG+AWG (all values), SSH (mwiede JSch), Tor (SOCKS sidecar), chain (relay/detour) | Build order: WG/AWG week1-2 → VLESS/VMess/Trojan/SS week3 → Hysteria2/TUIC/SSH/Tor week4 |

---

## Commands

Full executable commands with flags — run from repo root (`yourvpn/`). CI uses same.

```bash
# ── Dev ──
flutter pub get
flutter gen-l10n  # from ARB app_en.arb / app_fa.arb → l10n
flutter run -d android  # Android SDK 36, NDK 28, JDK 17, libbox.aar present
flutter run -d windows

# ── Go libbox.aar (with AmneziaWG, all values) — mirrors amnezia-box-for-android
cd go/amnezia-box
git submodule update --init --recursive  # submodules/wireguard-go → Leadaxe/wireguard-go-awg2-lx
make lib_install && make lib_android  # gomobile bind -tags with_gvisor,with_quic,with_dhcp,with_wireguard,with_utls,with_acme,with_clash_api,with_awg -androidapi 24
cp libbox.aar ../../android/app/libs/ && cp libbox-legacy.aar ../../android/app/libs/
ls -lh ../../android/app/libs/
# sanity: must pass
strings android/app/libs/libbox.aar | strings | grep -q "amneziawg" || (echo "AWG missing — with_awg tag?" && exit 1)
strings android/app/libs/libbox.aar | strings | grep -q "Awg is not included" && (echo "AWG stub — tag missing" && exit 1)

# ── Xray side lib (optional)
cd go/xray-core && go build -o ../../windows/xray.exe ./main

# ── Tor sidecar (detached, for chaining)
tor --version  # must exist
# sing-box will dial via socks detour 127.0.0.1:9050, not via type: tor

# ── Build APKs (split per ABI, platform-aware)
flutter build apk --release --split-per-abi --no-tree-shake-icons --dart-define=UPDATE_CHANNEL=androidApk
# outputs: build/app/outputs/flutter-apk/app-arm64-v8a-release.apk (arm64-v8a), app-armeabi-v7a-release.apk, app-x86_64-release.apk
# + universal: flutter build apk --release

# ── Build Windows (with Go DLL)
go build -tags nosqlite -buildmode=c-shared -o windows/libbox.dll ./go/libbox
# copy mingw runtime (gopeed pattern)
cp "C:/Program Files/Git/mingw64/bin/libstdc++-6.dll" build/windows/x64/runner/Release/
cp "C:/Program Files/Git/mingw64/bin/libgcc_s_seh-1.dll" build/windows/x64/runner/Release/
cp "C:/Program Files/Git/mingw64/bin/libwinpthread-1.dll" build/windows/x64/runner/Release/
cp "C:/Windows/System32/msvcp140.dll" build/windows/x64/runner/Release/ 2>/dev/null || true
flutter build windows --release --dart-define=UPDATE_CHANNEL=windowsPortable
Compress-Archive -Path "build/windows/x64/runner/Release/*" -DestinationPath "build/windows/Output/YourVPN_v1.2.3_windows-x64.zip" -Force

# ── Test (all must pass before push)
flutter test --coverage  # ≥70% for lib/modules/routing_editor + lib/services
flutter test test/updater/github_releases_api_test.dart  # 403/429/401 rate-limit (sesori)
go test ./...  # libbox
dart format --set-exit-if-changed . && flutter analyze && golangci-lint run ./...

# ── Sing-box checks (source-driven)
sing-box check -c profiles/config.json
sing-box check -c profiles/config.wg-awg.json  # WG/AWG priority config first
sing-box rule-set compile schemas/geosite-cn.json -o rule_sets/geosite-cn.srs
sing-box rule-set compile schemas/geoip-cn.json -o rule_sets/geoip-cn.srs
sing-box rule-set decompile -o /tmp/out.json rule_sets/geosite-cn.srs && jq empty /tmp/out.json

# ── Geodata update (dev)
curl -fsSL -o /tmp/geoip.dat https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat
curl -fsSL -o /tmp/geosite.dat https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat
geodat2srs geoip -i /tmp/geoip.dat -o rule_sets/ --prefix geoip-
geodat2srs geosite -i /tmp/geosite.dat -o rule_sets/ --prefix geosite-

# ── L10n
flutter gen-l10n && flutter test test/l10n/

# ── Release dry-run
dart run fl_build -p android && dart run fl_build -p windows  # like flutter_server_box
```

**CI equivalents (GitHub Actions 3 jobs parallel, per `nick4man/amnezia-box-for-android` + `lollipopkit/flutter_server_box` + `GopeedLab/gopeed`):**

- `build-android` (`ubuntu-latest`): `subosito/flutter-action@v2` flutter 3.47.2 + `actions/setup-go@v5` 1.25 + `android-actions/setup-android@v3` + `sdkmanager --install "ndk;28.0.13004108" "platforms;android-36" "build-tools;36.0.0"` → `make lib_android` → sanity `strings libbox.so | grep amneziawg` → `flutter build apk --split-per-abi` → `softprops/action-gh-release@v2` (arm64/arm/amd64) + `latest.json`
- `build-windows` (`windows-latest`): `flutter build windows` + `go build -buildmode=c-shared` + mingw dlls + `Compress-Archive` → zip + `svenstaro/upload-release-action@v2`
- `build-linux` (`ubuntu-latest`): `apt-get install clang cmake ninja-build pkg-config libgtk-3-dev` → `flutter build linux` → tar.gz

---

## Project Structure

```
yourvpn/  # ORIGINAL SELF-CONTAINED — README/docs contain no external project names; LICENSE contains AGPL + third-party notices as required by law
├── lib/                          # Flutter Dart — Feature-Based MVVM + source-driven (docs.flutter.dev)
│   ├── main.dart                 # M3EMaterialApp + dynamic_color + M3ETheme (material_3_expressive 45 M3E) + cue
│   ├── app/                      # M3EMaterialApp + go_router (ShellRoute bottom nav, sharedAxisX via transit_kit, cue spring)
│   ├── core/
│   │   ├── network/              # http + flutter_cache_manager 6h stale-while-revalidate + ETag + retry-after
│   │   ├── routing/              # go_router + deep link yourvpn://
│   │   └── services/             # ORIGINAL MethodChannel vpn_service → Go libbox (not vpnclient_engine) + singbox_config_builder
│   ├── modules/
│   │   ├── vpn/                  # WG/AWG priority first — HKG-02 WG+AWG example in mock
│   │   │   ├── logic/            # VpnNotifier (Riverpod) + VpnState (cue spring, eye blink)
│   │   │   ├── models/           # VpnServer (WG/AWG Jc/H1/I1 + VLESS etc. deferred), RoutingRule (30 fields), ProxyGroup (3-tier), DiagnosticsResult
│   │   │   ├── repositories/     # SubscriptionRepository (Clash YAML/sing-box JSON/vmess/vless/ss/trojan/hysteria2/tuic/WG INI/SIP008), GeoRepository, ConfigRepository (drift)
│   │   │   └── screens/          # home (bento 10 tiles, pulse + Hum push shift), subscriptions, traffic, settings, onboarding_wizard (3-step)
│   │   ├── groups/               # 3-tier: auto urltest (filter regex HongKong|HK) → selector MANUAL → proxy PROXY + TOR-CHAIN relay (filter/exclude-filter)
│   │   ├── routing_editor/       # Full 30-field M3E UI: domain/suffix/keyword/regex, geosite/geoip, ip_cidr, port/range, process_name/path_regex, package_name/regex, wifi_ssid/bssid, rule_set, invert, action, outbound, logical and/or + Monaco fallback + sing-box check
│   │   ├── logs/                 # connections + requests + DNS SubscribeDNSQueries via CommandClient (with_lx_command) + pcap toggle + fl_chart
│   │   ├── diagnostics/          # DNS scanner 0-6 + Prism HMAC (Slipnet-like), Simple Ping TCP 5000ms, sort by ping, PingRoute per-hop (fl_chart), network_reachability Rust stability 0-100
│   │   ├── updates/              # daily workmanager + GitHub platform-aware updater (6h cache, x-ratelimit-reset)
│   │   ├── profiles/             # 7 subs preview: Clash YAML, VLESS Reality, WG INIs, Tor sidecar
│   │   └── i18n/                 # l10n ARB en/fa RTL — EdgeInsetsDirectional, Semantics, ReduceMotion
│   ├── l10n/                     # app_en.arb, app_fa.arb (ICU plural, @description), generated app_localizations.dart
│   └── utils/                    # singbox_config_builder.dart (→ original libbox bridge, source-driven from sing-box.sagernet.org) + amnezia_values.dart (Jc/H1/I1 presets)
├── android/                      # Flutter Android shell
│   ├── app/
│   │   ├── libs/
│   │   │   ├── libbox.aar        # from amnezia-box gomobile bind -with_awg (all Amnezia values)
│   │   │   └── libbox-legacy.aar # API 21
│   │   └── src/main/
│   │       ├── AndroidManifest.xml  # FOREGROUND_SERVICE, FOREGROUND_SERVICE_DATA_SYNC|REMOTE_MESSAGING, VpnService, REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
│   │       └── kotlin/com/yourvpn/ # minimal: ForegroundService (dataSync), BatteryOptHelper, no VPN logic (in Go)
│   └── key.properties            # storeFile upload-keystore.jks (F-Droid pin e9fe39...), not committed
├── windows/
│   ├── runner/                   # Flutter Windows runner + libbox.dll + msvcp140.dll etc.
│   └── libbox.dll                # from go build -buildmode=c-shared
├── (no ios/macos/linux stubs — YAGNI, defer to v1.1, Flutter supports but not created)
├── go/
│   ├── amnezia-box/              # submodule hoaxisr/amnezia-box pin awg-1.14-rc1 @ SHA <?> (replace <?> at todo:2 with git rev-parse, e.g., abc123), with_awg, submodules/wireguard-go → Leadaxe/wireguard-go-awg2-lx@SHA<?> (sagernet + Amnezia 3-way merge) — pinned, not floating dev-next
│   ├── xray-core/                # submodule XTLS/Xray-core 26.x@SHA<?> (for VLESS edge, deferred to week 3)
│   └── tor/                      # tor binary sidecar (detached, socks 127.0.0.1:9050, not type: tor)
├── rule_sets/                    # *.srs binary + *.json source + cache (SagerNet/sing-geosite)
│   ├── geosite-cn.srs            # remote binary, url https://.../geosite-cn.srs, update_interval 24h, download_detour proxy, initial_path assets/...
│   ├── geoip-cn.srs
│   └── initial_assets/           # initial_path fallback for offline first run
├── assets/
│   ├── geoip/ & geosite/         # initial_path
│   └── l10n/                     # flags, etc.
├── profiles/                     # user configs: config.json (WG/AWG priority first), config.full.json, subscriptions/*.json, cache/
├── test/
│   ├── updater/github_releases_api_test.dart  # 403 x-ratelimit-remaining:0 → GitHubRateLimitException, 429, 401 retry unauth (sesori)
│   ├── routing/rule_test.dart    # 30 fields → sing-box check + rule-set compile round-trip, OR groups AND logic
│   ├── groups/groups_test.dart   # 3-tier filter/exclude-filter
│   ├── vpn/kill_switch_test.dart # max firewall via tcpdump
│   └── l10n/arb_test.dart        # EN/FA RTL, EdgeInsetsDirectional
├── go.mod / pubspec.yaml         # flutter 3.47.2, material_3_expressive, cue, drift, go 1.25
├── analysis_options.yaml         # flutter_lints + custom: require EdgeInsetsDirectional, require Semantics
├── Makefile.lx / Makefile        # lx-print-tags, lib_android
├── .hallmark/                    # Hallmark log.json (Bento Specimen, Grid Hum etc.) — not in v1 (throwaway prototype branch)
├── .github/workflows/
│   ├── build-android.yml         # libbox.aar + APK split (amnezia-box-for-android pattern) + sanity strings
│   ├── build-windows.yml         # lib dll + zip
│   └── build-linux.yml           # stub
└── docs/ + research/ + tasks/ (at VPN Research/ root)
     ├── docs/archify.html + docs/archify-candidate.json (showcase 950×560 9/9)
     ├── docs/prototype-final.html (blended Bento×Hum)
     ├── research/01-Karing.md … 13-Matsuri-SagerNet.md + research/audit.md (13 + must-changes)
     ├── tasks/plan.md + tasks/todo.md + tasks/progress-*.md + docs/decisions.tsv
     └── SPEC.md, goal.md, CONTEXT.md, intent.md, scaffold.md, AGENTS.md (specs at root)
```

**Key paths (source-driven):**

- `lib/utils/singbox_config_builder.dart:18` style: builds `route.rules` JSON from Flutter state → `Libbox.setServer` → Go `Libbox.setup()` (single TUN).
- `go/amnezia-box/.github/workflows/build.yaml` pattern: `strings libbox.so | grep -q amneziawg` sanity.
- `android/app/libs/libbox.aar` via `gomobile bind -androidapi 24` (API 21 legacy).
- `lib/l10n/app_en.arb` + `app_fa.arb` → `flutter gen-l10n`.

---

## Architecture — Deep Modules (from improve-codebase-architecture, 6 deepening opportunities, build order 03→01+02→04→05→06)

> Deep module = small interface + lots of hidden implementation. Shallow = interface nearly as complex as impl. Seam = where interface lives. Adapter = translation at seam. Leverage = capability per interface unit. Locality = fix once, fixed everywhere. Deletion test = would deleting module force callers to re-implement it? Interface is test surface.

**Build order (grilling Q1):** `03 Tunnel Lifecycle` → `01 RoutingCompiler` + `02 IngestionAdapter` parallel → `04 AmneziaWG Domain` → `05 GeoAsset` → `06 Health` (sequential 05→06 per Q9). Migration: delete shallow modules immediately (Q10, warrants ADR).

### 03 Tunnel Lifecycle — Deep, owns Dart↔Kotlin↔Go seam (Strong, top pick)

- **Files:** `lib/core/services/tunnel.dart` (new deep module) • `lib/modules/vpn/logic/vpn_notifier.dart` • `android/.../ForegroundService.kt` • `go/libbox/bridge.go` (typed, not `Setup(string)`)
- **Interface (deep, small):** `Tunnel.connect(tag: string) -> TunnelState`, `disconnect()`, `status Stream<TunnelState>` — hides 12-step sequence + Tor SOCKS detour. Tag seam chosen per Q3 for leverage (caller knows `HKG-02`, not Go structs).
- **Adapters private:** `PlatformAdapter.establish() -> fd`, `BoxAdapter.start(TypedConfig)`, `FirewallAdapter.enforce()`, `TorAdapter` (SOCKS `127.0.0.1:9050` not `type:tor` FATAL #4200).
- **Benefits:** Locality — lifecycle co-located. Leverage — one `connect(tag)` does 12 steps. Tests — `FakePlatformAdapter` (fake fd) + `FakeBoxAdapter` → unit-test ordering/airplane/block without device.

### 01 RoutingCompiler — Deep, hides 30 fields + 3-tier + SRS (Strong)

- **Files:** `lib/modules/routing/routing_compiler.dart` • `lib/modules/routing_editor/models/route_rule.dart` (remove) • `lib/modules/groups/` (absorb) • `lib/utils/singbox_config_builder.dart:18` (thin ConfigAssembler)
- **Interface:** `RoutingPolicy {rules, groups}` → `RoutingCompiler.compile(policy) -> CompiledRoute {rulesJson, ruleSets, validationErrors, isValid}` (field not throw per Q4). Hides OR-group AND-logic (`route/rule/rule_default.go:17`), `invert`, `SRS tag` generation.
- **Benefits:** Locality — one place for `geosite-cn` vs proxy. Leverage — one compile gives validated JSON. Tests — through `compile()` without `sing-box check`.

### 02 IngestionAdapter — Deep, unified 7 parsers (Strong)

- **Files:** `lib/modules/vpn/repositories/ingestion/` • parsers (clash_yaml, singbox_json, vmess, vless, ss/sip008, trojan, hysteria2, tuic, wg_ini) • `lib/utils/amnezia_values.dart`
- **Interface:** `parseAndNormalize(RawSubscription {bytes, url, contentType}) -> List<NormalizedEndpoint>` sealed union `VlessEndpoint | WireGuardEndpoint(AwgProfile) | Hysteria2Endpoint` (Q5) — not flat struct. Hides per-format quirks.
- **Benefits:** Locality — one adapter case per new format. Tests — raw `clash YAML / vless:// / wg_ini` → union without file IO.

### 04 AmneziaWG Domain — Deep, hides 30+ params (Strong)

- **Files:** `lib/modules/vpn/amnezia/awg_profile.dart` • `awg_config.dart` • `go/amnezia-box/option/wireguard_awg.go`
- **Interface:** `AwgProfile` preset + Custom advanced (Q6) → `AwgConfig.fromPreset('quic-mimic')` / `generateRandom()` → `AwgConfig {strength, overhead, toEndpointJson()}` — hides `H1∩H2=∅`, `S1+56≠S2`, `Jmax<MTU`, `Id/Ip/Ib` masquerade, must-match vs may-differ. UI: 2-3 presets default, 30 sliders behind Advanced.

### 05 GeoAsset — Deep, owns SRS pipeline (Worth)

- **Files:** `lib/modules/geo/geo_asset.dart` • `lib/modules/updates/` • `lib/core/network/` (6h cache) • `rule_sets/*.srs` • `lib/modules/dns/`
- **Interface:** `ensure(tag) -> Path` always via `initial_path` (Q7) + `refreshAll()` ETag-aware — hides 6h stale-while-revalidate, `x-ratelimit-reset`, `CacheFile`, compile.

### 06 Health — Deep, owns diagnostics hierarchy (Worth)

- **Files:** `lib/modules/health/health.dart` • `lib/modules/diagnostics/` • `lib/modules/logs/` • `network_reachability` Rust • `drift`
- **Interface:** `snapshot() -> HealthReport {score 0-6, hijacked, pingMs, stability, hops}` + `stream` auto-refresh (Q8) — hides scanner 0-6, Prism HMAC, ping TCP 5000ms, traceroute, Rust `guard()`. Sequential 05→06 per Q9.

---

## Code Style

One real snippet beats three paragraphs. Follow `analysis_options.yaml` + `dart format` + `golangci-lint` + Hallmark token discipline + unslop plain speech.

**Naming:** `lowerCamelCase` Dart, `PascalCase` widgets (`VpnNotifier`, `RouteRule`, `M3ECard`), `snake_case` Go files (`wireguard_go_awg2.go`), `SCREAMING_SNAKE` for `update_interval` constants. Files: `vpn_notifier.dart`, `route_rule.dart`, `singbox_config_builder.dart:18`, `amnezia_values.dart`.

**Tokens locked (Hallmark discipline):** Once `material_3_expressive` theme picked, every color `var(--color-*)` and `font-family: var(--font-*)` — no inline `oklch()`/`hex`/`rgb()` in body, no `font-family: "Fraunces"` bypass. If needed, lift into `:root` as new `var(--color-*)`.

**Flutter (Riverpod + M3E + cue, unslop: active voice, sentence case, no em dashes):**

```dart
// lib/modules/vpn/logic/vpn_notifier.dart — active voice, plain words
@riverpod
class VpnNotifier extends _$VpnNotifier {
  @override
  VpnState build() => const VpnState.disconnected();

  Future<void> connect({required String tag}) async {
    state = const VpnState.connecting();
    final config = ref.read(singBoxConfigBuilderProvider).build(tag); // WG/AWG priority first
    await SingBox.check(config); // sing-box check -c — fails build, not at runtime
    await VpnService.connect(tag); // original MethodChannel → Go Libbox.setup() → TUN
    state = VpnState.connected(tag: tag, stats: await _pollStats());
  }

  Future<void> setRoutingRules(List<RouteRule> rules) async {
    await VpnService.setRoutingRules(rules.map((r) => r.toJson()).toList());
  }
}

// lib/modules/routing_editor/models/route_rule.dart — 30 fields, sentence case, no bold labels
class RouteRule {
  const RouteRule({
    this.domain, this.domainSuffix, this.geosite, this.geoip,
    this.ipCidr, this.port, this.processName, this.processPathRegex,
    this.packageName, this.wifiSsid, this.ruleSet, this.invert = false,
    required this.action, // route, block, direct
    this.outbound, // direct, PROXY, REJECT, tor-socks
    this.type, // null = default, logical + mode and/or
  });
  Map<String, dynamic> toJson() => {
    if (domain != null) 'domain': [domain],
    if (processName != null) 'process_name': [processName],
    if (packageName != null) 'package_name': [packageName],
    if (wifiSsid != null) 'wifi_ssid': [wifiSsid],
    if (ruleSet != null) 'rule_set': ruleSet,
  };
}
```

**Go (libbox, with_awg, all Amnezia values):**

```go
// go/libbox/bridge.go — plain word, not "harness"
//go:build with_awg
package libbox

import "github.com/sagernet/sing-box/option"

func Setup(boxConfig string) error {
    // wires amnezia-box with_awg (all values: Jc/Jmin/Hmax/H1-H4/I1-I5/Id/Ip/Ib) + Xray, single TUN
    // source-driven from sing-box.sagernet.org/configuration/route/rule/
    return runBox(boxConfig, withDNSHijack, withFakeIP("198.18.0.0/15"))
}

// option/wireguard_awg.go — typed, no "intricate"
type WireGuardAWGOptions struct {
    Jc int `json:"jc"`; Jmin int `json:"jmin"`; Jmax int `json:"jmax"`
    S1 int `json:"s1"`; S2 int `json:"s2"`; H1 string `json:"h1"`; H4 string `json:"h4"`
    I1 string `json:"i1"`; I5 string `json:"i5"` // I1-I5 obfuscation chains
    Id string `json:"id"`; Ip string `json:"ip"`; Ib string `json:"ib"` // masquerade
}
```

**Formatting:** `dart format --set-exit-if-changed .` in CI before `flutter analyze`. `golangci-lint run ./...` must pass. Hallmark: `html,body {overflow-x:clip}` + `minmax(0,1fr)` + `overflow-wrap:anywhere` + `white-space:nowrap` on chips.

**Unslop (plain speech):** Use `use` not `utilize`, `help` not `facilitate`, `many` not `numerous`, `if` not `in the event that`, no em dashes, no `**Performance:**` inline-header lists (use prose), sentence case headings, no puffery (`testament`, `tapestry`, `pivotal`), no `not just X, but Y`.

---

## Testing Strategy

**Framework:** `flutter test` + `go test` + `sing-box check` + `sing-box rule-set compile` + leak tests via `tcpdump`/`dnsleaktest.com`/`ipleak.net`/`browserleaks.com`/`network_reachability` + `flutter_localizations` golden.

**Where tests live:** `test/` (unit), `test/integration/` (engine), `androidTest/` (VpnService), `go/...` (libbox), `test/l10n/` (ARB). Coverage: `flutter test --coverage` ≥70% for `lib/modules/routing_editor`, `lib/services`, `lib/modules/diagnostics`.

**Test levels (extreme detail):**

| Concern | Level | How | When | Why this level |
|---|---|---|---|---|
| `route.rules` 30 fields, 3-tier groups, `logical` and/or, `rule_set` SRS binary | Unit | `test/routing/rule_test.dart`: builds JSON with `domain`/`geosite`/`geoip`/`ip_cidr`/`process_name`/`package_name`/`wifi_ssid`/`rule_set` → `sing-box check -c` + `sing-box rule-set compile` round-trip + `decompile` → `jq empty` + asserts OR groups AND logic per `route/rule/rule_default.go:17` (`domain\|\|geosite\|\|geoip\|\|ip_cidr` && `port` && `source_ip` && `other`) | On every `lib/modules/routing_editor` change | Catches malformed rule_set merge before runtime |
| SRS `binary` + ETag + `update_interval` 24h + `initial_path` + `CacheFile` | Integration | `test/updater/github_releases_api_test.dart` (sesori_bridge pattern): mock `MockClient` 403 `x-ratelimit-remaining:0` + `x-ratelimit-reset` → `GitHubRateLimitException`, 429 → rateLimit, 401 → retry unauth, 403 no budget → `StateError`, 500 → `HttpException`, `initial_path` fallback | On `lib/modules/updates/` change | GitHub 60/hr limit handling |
| VPN connect (WG/AWG priority) + kill switch max firewall | Integration | `flutter test` with `MethodChannel` mock + Go `libbox` mock + `tcpdump` capture on CI runner (like VPN Security Review July 2026 16 VPNs): `strings libbox.so | grep amneziawg` must pass, then `VpnService.connect("HKG-02")` → `protect(fd)` called | On `lib/modules/vpn/` + `go/` change | Catches AWG stub (`Awg is not included`) before APK |
| Leak tests (7) | E2E manual on device (Android 13+, Win 11) | `ipleak.net` + `dnsleaktest.com` Extended + `browserleaks.com` WebRTC + `dnsleaktest.com` after `flutter_foreground_task` + `isIgnoringBatteryOptimizations`: must show VPN IP/DNS only, no ISP; 7 scenarios: reboot+startup (no packets before VPN), sleep/wake 60s, Wi-Fi↔hotspot handoff (continuous ping, no reply when `reconnecting`), DoH/QUIC (Chromium DoH bound to tunnel), IPv6 (no public v6 unless tunneled, else block), split audit (per-app bypass shows no rows for excluded UIDs), captive portal | Before every GitHub Release tag | 6/16 VPNs leaked July 2026 via DNS fails-open, IPv6, QUIC |
| Build 3 jobs parallel | CI | GitHub Actions: `strings libbox.so | grep -q amneziawg`, `flutter analyze`, `dart format`, `golangci-lint`, `sing-box check`, `flutter test --coverage` | On every push to `main` | Rebase safety |
| L10n/RTL/a11y | Widget + golden | `test/l10n/arb_test.dart`: `EdgeInsetsDirectional` not `EdgeInsets.only`, `Semantics` on icon-only controls, `TextScaler.clamp 0.9-1.35`, `ReduceMotion` fallback (glow/bounce skipped), golden localization for EN/FA, 200% text scale overflow check | On `lib/l10n/` + `lib/ui/` change | GRoute EN/FA RTL, WCAG AA |
| Diagnostics | Integration | `test/diagnostics/scanner_test.dart`: Simple ping TCP 5000ms `Socket.connect`, `network_reachability` `guard()` + `StabilityScore` + `detectDnsHijack`, `geodat2srs` compile | On `lib/modules/diagnostics/` change | Slipnet 0-6 score |
| Play policy | Manual | Verify prominent disclosure dialog + 90s video + declaration form (`Device security` / `Network-related tools`) + encryption `device→tunnel` doc | Before Play submission v1.1 | `support.google.com/googleplay/answer/12564964` |

**Verification checkpoints (must pass before merge):**

1. `flutter analyze && dart format --set-exit-if-changed . && golangci-lint run ./... && flutter test --coverage ≥70%` passes.
2. `sing-box check -c profiles/config.json && sing-box check -c profiles/config.wg-awg.json` passes + `sing-box rule-set compile` round-trip passes.
3. On-device: `ipleak.net` VPN only, `dnsleaktest.com` Extended VPN DNS only, `browserleaks.com` WebRTC no local IP, 7 leak tests pass.
4. `GitHubReleasesApi` handles 403/429/401 as sesori, 6h cache works, `initial_path` offline.
5. Wizard: `isIgnoringBatteryOptimizations` → `requestIgnoreBatteryOptimization()` succeeds, foreground `foreground_service` non-dismissible, tap brings foreground, `autoRunOnBoot` true.

---

## Boundaries

**Always do:**

- Run `flutter test --coverage` + `sing-box check` + `dart format` before commits.
- Validate `route.rules` + `rule_set` via `sing-box rule-set compile` before writing `profiles/config.json` (WG/AWG priority config first).
- Use original MethodChannel for `VpnService` (not `vpnclient_engine_flutter`) with `with_awg` tag for libbox.
- Cache GitHub API 6h stale-while-revalidate + respect `x-ratelimit-reset`/`retry-after` + `If-None-Match` ETag.
- Pin `flutter 3.47.2`, `Go 1.25.x`, `NDK 28`, `JDK 17`, `material_3_expressive` 45 M3E.
- Write `EdgeInsetsDirectional` not `EdgeInsets.only`, require `Semantics` on tappables, test 200% scale.
- Encrypt `device→tunnel` and document in Play listing + prominent disclosure + 90s video.
- Keep README/docs self-contained original (no external VPN names) — LICENSE contains AGPL + third-party SHAs, not README.

**Ask first:**

- Database schema changes (`drift` for profiles — `fl_build` handles, but ask before new table).
- Adding dependencies (`pubspec.yaml` + `go.mod` replace directives).
- Changing CI (`.github/workflows/*`), signing (`key.properties`, `upload-keystore.jks`).
- Adding new protocol (new `sing-box` `outbound.type` + M3E UI field) — even though WG/AWG priority first, other protocols deferred to week 3-4, still ask.
- Changing `route.rules` top-level `final` or `auto_detect_interface` or `find_process`.
- Adding new locale beyond EN/FA.

**Never do:**

- Commit secrets (`key.properties` password, `upload-keystore.jks`, GitHub tokens) — use `secrets.*`.
- Edit `go/amnezia-box` fork directly — rebase via `git fetch amnezia/master && git merge` + `replace` directive.
- Remove failing `test/updater/github_releases_api_test.dart` 403/429 tests without approval.
- Skip `isIgnoringBatteryOptimizations` check — Doze will kill service on API 23+ (per `developer.android.com/training/monitoring-device-state/doze-standby`).
- Use `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` for non-VPN core function (Play will reject per `support.google.com/googleplay/answer/12564964`).
- Ship without `sing-box check` + 7 leak tests.
- Use `EdgeInsets.only(left:)` in RTL — breaks FA.
- Use `vpnclient_engine_flutter` without publishing fork+attribution — violates Extended GPL v3 clause 5.
- Copy other VPN project text verbatim into README/docs — original self-contained only.

---

## Success Criteria

All must be true to ship `v1.0` (WG/AWG priority first, full win by week 4):

1. **Capability win (WG/AWG priority):** Script `scripts/compare_capabilities.py` vs `research/*.md` shows `yourvpn >=` every researched VPN on every row **for WG/AWG star first** (Jc/Jmin/Jmax/S1-S4/H1-H4/I1-I5/Id/Ip/Ib + FakeIP DNS fix + 30 fields + 3-tier groups + relay + WFP max + uTLS). ECH moved to v1.1 (see audit). Full win (VLESS etc.) by week 4, but WG/AWG + routing win by week 2.
2. **Leak-free (7 tests):** On Android 13+ and Win 11, after guided 3-step wizard + battery exemption, `ipleak.net` + `dnsleaktest.com` Extended + `browserleaks.com` WebRTC all show VPN IP/DNS only; 7 tests pass: reboot+startup (no packets before VPN), sleep/wake 60s, Wi-Fi↔hotspot handoff (no reply when `reconnecting`), DoH/QUIC bound, IPv6 no public v6, split audit (per-app bypass no rows), captive portal. Per RTINGS July 2026 (6/16 leaked).
3. **AmneziaWG all values:** `awg` endpoint JSON (`jc 6, jmin 8, jmax 48, s1 123, h1 … , i1 …`, `id/ip/ib` masquerade) via `hoaxisr/amnezia-box` libbox.aar (sanity `strings libbox.so | grep -c amneziawg >0` + not `Awg is not included`) connects to real AWG 2.0 server handshake+keepalive+traffic, validated on LTE with TSPU-like DPI (like `Leadaxe/wireguard-go-awg2-lx`).
4. **Tor isolated (if kept for chain):** Tor sidecar on `127.0.0.1:9050` via `socks` detour `tor-socks`; killing Tor does not crash sing-box (no `FATAL start outbound/tor` per #4200), sing-box stays up via `block` fallback — or Tor deferred to v1.1 if pure WG/AWG scope chosen.
5. **UX polished (blended Bento×Hum):** Guided 3-step wizard (VPN permission → battery exemption → per-app allowlist/bypass) + Flutter M3E dark/light/AMOLED + adaptive bento home (power pulse + Hum push shift + color-shift cards + eye blink) + live connections/requests/DNS via `SubscribeDNSQueries` + traffic chart `fl_chart` + `showNotification: true` foreground `foreground_service` + `autoRunOnBoot: true` + EN/FA RTL `EdgeInsetsDirectional` + a11y `Semantics` + `ReduceMotion`.
6. **Updates platform-aware:** Daily 24h ETag checks for SRS + subs + app via `api.github.com/repos/<you>/yourvpn/releases/latest`, semver compare, filter asset by `platform` (`-arm64-v8a.apk`, `-windows-x64.zip`), 6h cache avoids 403 `x-ratelimit-remaining:0`, `initial_path` offline, `latest.json` platform map.
7. **Build reproducible:** GitHub Actions 3 jobs parallel produce `yourvpn_v1.2.3_arm64.apk`, `_arm.apk`, `_amd64.apk`, `_windows_amd64.zip` with `sha256` + `latest.json` (like `lollipopkit/flutter_server_box` + `RecomBox`), uploaded via `softprops/action-gh-release@v2` without manual steps, `flutter analyze` + `golangci-lint` green, `strings libbox.so | grep amneziawg` green.
8. **Compliance self-contained:** AGPL-3.0 `LICENSE` + `THIRD_PARTY.md` (fork SHAs: `hoaxisr/amnezia-box@awg-1.14-rc1`, `XTLS/Xray-core@26.x`, `Leadaxe/wireguard-go-awg2-lx`) + `src` tarball per release + Play `VpnService` declaration (`Network-related tools`, encryption doc, 90s disclosure video) ready, but README/docs contain **no external project names** (original).

---

## Open Questions

- None — all 22 locks resolved (21 + WG/AWG priority revert). One watch: if pure WG/AWG scope chosen, VLESS etc. deferred to v1.1, but SPEC keeps them as week 3-4 to preserve win. Decide during `core` module implement whether to keep `xray-core` submodule for VLESS edge (week 3) or defer to v1.1.

---

## References

- Research: `research/01-Karing.md … 13-Matsuri-SagerNet.md`, `research/audit.md` (6 must-changes + 3 refines), `goal.md FROZEN FINAL`, `docs/prototype-final.html` (blended Bento×Hum), `docs/archify.html` showcase, `hallmark-variants/01 + 10` kept.
- Upstream issues: SagerNet/sing-box #4045/#2557 (AmneziaWG wontfix), throneproj/Throne #1353/#1117 (AWG via fork `v14d4n/throne-sing-box-awg`), SagerNet/sing-box #4200 (Tor FATAL), GFW-knocker/MahsaNG (fragmentor), anonvector/SlipNet (Jetpack Compose M3 + Rust QUIC).
- Docs (source-driven): `sing-box.sagernet.org/configuration/route/rule/` (30 fields), `deepwiki.com/SagerNet/sing-box/3.1-routing-rules-and-rule-sets` (OR groups AND logic, SRS binary, ETag), `docs.flutter.dev/ui/internationalization` (ARB, EdgeInsetsDirectional), `developer.android.com` VpnService/Doze, `support.google.com/googleplay/answer/12564964` VpnService declaration, `pub.dev` `material_3_expressive`/`cue`/`drift`/`network_reachability`, `fzyzcjy/flutter_rust_bridge` (not needed, pure Go).
- Prototypes: `hallmark-variants/01-bento-specimen.html` (P5 H4 E5 S4 R5 V5) + `10-grid-hum.html` (P5 H5 E5 S5 R5 V5) — blended into `prototype-final.html`.

---

**Approved:** FROZEN FINAL goal.md (All protocols WG/AWG priority first, original self-contained, M3E, i18n, diagnostics) → this SPEC v2.0 is the next gate. Human reviews Tech Stack + Commands + Project Structure + Success Criteria before `tasks/plan.md` via `planning-and-task-breakdown`.
