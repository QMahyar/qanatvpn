# VPN Goal — Endgame Definition (FROZEN FINAL — ORIGINAL SELF-CONTAINED — READY FOR SPEC)

> FROZEN 2026-08-30 07:00 UTC. All 21 locks + 3 refines + 4 extra deeps + UI M3E + i18n/RTL + diagnostics + original self-contained. Source-driven best practices apply.
> Folder: `C:\Users\qmahyar\Desktop\VPN Research`

**Status:** 🔒 FROZEN FINAL — explicit `now. my previus choices stand but i want no mention of other prjects in readme and docs etc.` — self-contained original
**Confidence:** 98%
**Next:** SPEC.md already generated — update SPEC to reflect original self-contained + source-driven, then `tasks/plan.md`

---

## 1. Intent — FROZEN FINAL

- **Outcome:** Original public AGPL Flutter+Go VPN (Android+Win first) that wins vs 13 researched VPNs on capability matrix, polished M3 Expressive UI, guided wizard, max firewall, daily platform-aware updates, original branding, no external mentions in README/docs.
- **User:** Public in censored regions + power users.
- **Why now:** Unify all tricks in one original, auditable, ad-free client.
- **Success:** Objective agent `you >=` all 13 + ipleak/dnsleak clean + 7 leak tests + GitHub daily checks + README/docs self-contained original.
- **Constraint:** 9-10w, Flutter+Go 2-lang, 1 TUN fork (internal, not mentioned externally), Tor sidecar, All+ ECH, GitHub Releases only, AGPL, zero telemetry, source-driven from official docs.
- **Out of scope:** iOS v1, browser extension, server panel, pure-Rust core, mentions of other projects in README/docs.

---

## 2. Platforms

Android + Windows first — Flutter single Dart codebase + Go libbox via gomobile (`libbox.aar` API 24 + `libbox.dll`). Kotlin hidden in plugin, not mentioned in docs.

---

## 3. Core — FROZEN ORIGINAL SELF-CONTAINED

**Pure Flutter+Go via gomobile (original, no external engine mentions in docs):**

- **UI:** Flutter 3.47.2, Dart, **material_3_expressive** (45 M3E, `motor` spring, like Slipnet Compose M3 in Flutter).
- **Core (internal, not in README):** Go `amnezia-box` fork (`hoaxisr/amnezia-box` 82★, `with_awg` tag, `type: awg`, FakeIP fix) + `XTLS/Xray-core` 26.x, built `go build -tags "with_gvisor,with_quic,with_dhcp,with_wireguard,with_utls,with_acme,with_clash_api,with_awg"` → `gomobile bind -tags with_awg -androidapi 24 -javapkg com.qanatvpn.libbox` → `android/app/libs/libbox.aar`. This is **internal implementation**, README/docs describe as "original core" without naming forks.
- **VPN abstraction (original):** Your own Flutter `MethodChannel` `vpn_service` (not `vpnclient_engine_flutter` to avoid Extended GPL attribution) — Dart `VpnService` wrapper directly calling Go libbox `Libbox.setup()` → TUN fd via `VpnService.Builder` + `protect(fd)` + `Service.startForeground()` + `isIgnoringBatteryOptimizations`. Source-driven from `developer.android.com` VpnService docs, not from other VPN projects.
- **Source-driven best practices:** Build from official docs only — `docs.flutter.dev` (i18n/RTL), `sing-box.sagernet.org` (route.rules/rule_set), `developer.android.com` (VpnService/Doze), `pub.dev` (material_3_expressive, cue, drift), `go.dev` (gomobile). No copy-paste from other VPNs.

---

## 4. Protocols — REVERTED FINAL: ALL PROTOCOLS, WG+AWG PRIORITY FIRST

**All protocols, but WG + AmneziaWG (all values: Jc/Jmin/Jmax/S1-S4/H1-H4/I1-I5 + masquerade Id/Ip/Ib + ChaCha header protection) via internal `awg` endpoint implemented first.** Full set: VLESS+Reality/Vision/XHTTP, VMess, Trojan, Shadowsocks/SS2022, Hysteria2, TUIC v5, WireGuard + AmneziaWG (all values), SSH, Tor (SOCKS sidecar), chaining (WG→WG, WG→VLESS etc.). Build order: WG/AWG + core routing first (week 1-2), then VLESS/VMess/Trojan/SS (week 3), then Hysteria2/TUIC/SSH/Tor (week 4). Docs call AWG "obfuscated WireGuard" but present as original. This restores the publish "win vs 13" capability matrix with WG/AWG as the star for highly censored networks.

---

## 5. DPI

All ON + ECH v1: Reality, Vision, XHTTP, uTLS, Fragment, ECH, AnyTLS/ShadowTLS/Salamander, obfuscated WG junk H1-H4/S1-S4/I1-I5.

---

## 6. Split Tunneling & Routing

**Groups:** sing-box 3-tier (auto urltest → selector → proxy) with `filter`. **Fields:** Full UI for all 30 `route.rules` fields + logical and/or, `find_process`, `package_name`, `wifi_ssid`.

---

## 7. Traffic Capture

Both TUN `mixed` + Proxy PAC + max firewall (WFP/iptables/pf) + Local SOCKS5 10808/HTTP 10809.

---

## 8. DNS

FakeIP 198.18.0.0/15 + DoH split + bootstrap + hijack.

---

## 9. Subscriptions

All formats + ETag 24h + QR/ZIP deeplink.

---

## 10. UI / Stack — FROZEN M3 EXPRESSIVE ORIGINAL

Flutter 3.47.2, Dart, **material_3_expressive** (45 M3E, motor, material_new_shapes, dynamic_color) + `cue` physics + `flutter_motion_kit` + `transit_kit` for smooth VPN pulse/draggable sheets/glass, `lib/` MVVM, `android/` hidden, `windows/` runner, `rule_sets/*.srs`. `go_router`, `flutter_secure_storage`, `flutter_foreground_task` (dataSync|remoteMessaging), **original** `vpn_service` MethodChannel + internal `amnezia_box` lib. Docs: self-contained original, no external project mentions, but LICENSE contains AGPL + third-party notices as required by law (not in README).

---

## 11. Extra Features — ALL DAY 1

Groups, stats, backup/WebDAV+LAN ZIP, observatory leastPing, main(config), hotkeys/tray/deeplink, logs/requests/connections, geo updater.

---

## 12. Security & Privacy — MAX FIREWALL

AGPL, zero telemetry, encrypted secrets, max firewall WFP/iptables/pf + in-tunnel DNS + IPv6 block + 7 tests per RTINGS July 2026. Self-contained threat model, no external thanks.

---

## 13. Distribution & Updates — FROZEN DAILY PLATFORM-AWARE

**Daily 24h + ETag + initial_path + CacheFile + 6h stale-while-revalidate + platform/version aware** via `api.github.com/repos/<you>/qanatvpn/releases/latest`, semver, asset filter `android-arm64`/`windows-x64`, `FileProvider`, `workmanager`. **Play policy:** VpnService declaration `Device security`/`Network-related tools`, encryption doc, 90s disclosure video (internal, self-contained). **CI:** 3 jobs parallel (Android libbox+APK split, Win zip, Linux), `subosito/flutter-action@v2` 3.47.2 + Go 1.25 + NDK 28 + JDK 17 + gomobile.

---

## 14. Non-Goals

No iOS v1, no browser extension, no server panel, no paid infra, no pure-Rust core, no external mentions in README/docs.

---

## 15. Extra Deeps — FINAL

| Deep | Lock |
|---|---|
| i18n/RTL/a11y | EN + FA RTL + ARB + `flutter_localizations` + `EdgeInsetsDirectional` + Semantics + Dynamic Type clamped 0.9-1.35 + ReduceMotion (like GRoute EN/FA) |
| Diagnostics+Data | Full: Slipnet-like DNS scanner 0-6 + Prism HMAC + Simple Ping TCP 5000ms + sort by ping + network_reachability Rust stability + PingRoute per-hop + Drift sqlite + secure storage |
| Branding/Legal | Original self-contained, AGPL + 90s video + Telegram (no external thanks in README, LICENSE self-contained) |
| UI Library | material_3_expressive (Slipnet-like) + cue/motion_kit/transit_kit for smooth |
| Stack Simplify | Flutter+Go 2-lang (you chose), original MethodChannel (not vpnclient_engine) |

---

## 16. Capability Map — FROZEN ORIGINAL

| Module | Responsibility | Depends |
|---|---|---|
| `core` | Go internal libbox (amnezia-box + Xray) via gomobile | — |
| `tunnel` | TUN mixed + Proxy + max firewall + foreground | `core` |
| `routing` | 30 fields + 3-tier groups + chains | `core`,`tunnel` |
| `dns` | FakeIP+DoH + hijack | `tunnel`,`routing` |
| `sub` | Parsers + daily ETag (6h cache) | `core` |
| `ui` | Flutter M3E + 30-field editor + groups + logs + wizard (EN/FA RTL) | all |
| `platform` | MethodChannel → VpnService/WinTun + foreground + battery | `tunnel`,`ui` |
| `updates` | Daily SRS/sub + GitHub platform-aware + rate-limit | `sub`,`ui` |
| `sec` | AGPL + secrets + max firewall + 7 tests + Play disclosure | all |
| `diag` | DNS scanner + ping + traceroute + Drift | `platform`,`ui` |

Build order: `core` → `tunnel`,`dns`,`sub` → `routing` → `platform` → `ui`,`updates`,`diag` → `sec`

---

## 17. What Must Change — APPLIED + ORIGINAL

1. Vendor amnezia-box `with_awg` → libbox.aar (internal, not in README)
2. Tor sidecar + SOCKS chain
3. Flutter foreground + MethodChannel (original)
4. Keep All + ECH = 9-10w risk
5. AGPL + src tarball + 90s video (self-contained LICENSE, README no mentions)
6. vpnclient_engine replaced by original MethodChannel for self-contained
7. 6h cache for GitHub API
8. Play disclosure + battery VPN acceptable use
9. NEW: material_3_expressive + cue/motion_kit for smooth
10. NEW: EN+FA RTL ARB + Semantics + ReduceMotion
11. NEW: Full diagnostics Drift + DNS scanner + ping
12. Source-driven: build from official docs, no copy from other VPNs

---

## 18. Next — SPEC update + Plan

Update SPEC.md to reflect original self-contained + M3E + i18n + diagnostics, then `tasks/plan.md` via spec-driven-development + source-driven + test-driven + incremental skills.

**FROZEN FINAL — ready to update SPEC and generate plan**
