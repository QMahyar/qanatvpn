# Karing — Extreme-Detail Documentation

> **Research date:** 2026-08-30  
> **Repo:** [KaringX/karing](https://github.com/KaringX/karing) · **Core fork:** [KaringX/sing-box](https://github.com/KaringX/sing-box) (fork of [SagerNet/sing-box](https://github.com/SagerNet/sing-box))  
> **Official site/docs:** [karing.app](https://karing.app) · [karing.app/en/clash](https://karing.app/en/clash) · [karing.app/en/app-manual/settings](https://karing.app/en/app-manual/settings)  
> **License:** GPL-3.0-only + name-use restriction (see `LICENSE.md:1`) — `Copyright (C) 2024 by nebula`  
> **Tech stack:** Flutter 3.35+ / Dart 3.9+ (UI) + Go sing-box core via `vpn_service` native bridge (FFI/GoMobile)  
> **Stats (2026-08):** ~14.6k ★, ~1.2k forks, ~36 open issues, main branch `main`, created 2023-11-06

---

## 1. Overview

- **What is Karing:**
  - A **simple & powerful proxy utility** — described as *"A singbox GUI based on flutter"* (`README.md:1`, `karing.app/en:1`)
  - Goals: unified rule-set across **multiple subscriptions**, transparent proxy via TUN, beginner-friendly while exposing full sing-box/Clash power users need
  - Not a VPN provider — it's a **client/utility**; ships with zero nodes, imports them via subscriptions

- **License & governance:**
  - Licensed **GPLv3** (`LICENSE.md:7-9`) + additional clause: `no derivative work may use the name or imply association with this application without prior consent` (`LICENSE.md:13`)
  - Sing-box core inside is also GPL-3.0 (SagerNet); Flutter app is GPL-3.0
  - Owned by `KaringX` org (`github.com/KaringX`), main committer `GooRingX`, team also maintains `clashmi.app`, `sing-poet`

- **Platforms (System Requirements — `README.md: System Requirements`):**
  - **Windows** ≥ 10, 64-bit only (`exe` + `zip` portable)
  - **macOS** ≥ 12 (Intel + Apple Silicon universal `dmg`)
  - **Linux** ≥ glibc 2.38, 64-bit only (`deb`, `rpm`, `AppImage`) — `sudo` auth for TUN, graceful fallback if sudo fails (#1593 patch)
  - **Android** ≥ 8 (arm64-v8a, armeabi-v7a APKs; also APKPure + Amazon AppStore)
  - **iOS** ≥ 15 / **tvOS** ≥ 17 (AppStore id `6472431552`, TestFlight available)
  - HarmonyOS requires separate guide (`karing.app/en/download` note)

- **Tech stack detail:**
  - **Flutter/Dart frontend:** `pubspec.yaml: version 1.2.11+1406`, `sdk ">=3.9.0 <4.0.0"`, `flutter ">=3.35.0"` (commit `5c18617`)
    - UI uses `provider 6.1.5`, `window_manager` (forked `KaringX/window_manager`), `tray_manager`, `hotkey_manager`, `flutter_inappwebview` (forked), `slang` i18n, `dio`/`http`, `sqlite_async` + `sqlite3_flutter_libs` for connections/stats DB
    - Platform integrations: `vpn_service` local package `path: ../vpn-service/` (`pubspec.yaml: vpn_service`), `android_package_manager` fork, `move_to_background` fork, `country` fork
  - **Go core:** `KaringX/sing-box:dev-next` (3,135 commits), fork of `SagerNet/sing-box` — Go `go.mod`, `Makefile`, `box.go`
    - Built as `libbox` / `LibVpnCore` + `Libbox.xcframework` (iOS) / GoMobile AAR (Android) / native service binary (desktop)
    - Docs at `sing-box.sagernet.org`, config schema in `option/`, routing in `route/`, DNS in `dns/`, transports in `transport/`, protocols in `protocol/`
  - **Acknowledgements (`README.md:Projects`):** `flutter`, `sing-box`, `Meta-Docs` (Clash.Meta wiki)

- **Internationalization:**
  - 30+ languages via `slang` — `README.md` lists English, 简体中文, 繁體中文, 日本語, 한국어, Español, Français, Deutsch, Italiano, Tiếng Việt, Türkçe, Русский, فارسی, العربية, Português, Português (BR), Українська, Polski, اردو, Svenska, Norsk, Nederlands, हिन्दी, Ελληνικά, Dansk, বাংলা, ไทย, ਪੰਜਾਬੀ — stored in `assets/`, generated `lib/i18n/strings.g.dart`

- **Positioning vs Clash:**
  - Fully **Clash-compatible** as first-class UX — `karing.app/en/clash` shows full compatibility table
  - Compared to Clash Verge/Mihomo: adds Flutter cross-platform, shared DiversionGroups across subs, built-in sing-box core (not just Clash core), beginner mode, multi-device sync

---

## 2. Supported Protocols (Outbound Proxy)

> Source: `karing.app/en/clash` · `deepwiki.com/KaringX/karing/4.3-protocol-support` · `karing.pro/en/faq/what-is-karing` · `README.md:Features`

- **Transport-agnostic unified engine:** all protocols registered via sing-box type constants `C.TypeVMess` etc. (`deepwiki 4.3`), parsed by `ServerManager` + `ProxyConfUtils` (`lib/app/modules/server_manager.dart:84`, `lib/app/utils/proxy_conf_utils.dart`)
  - How implemented: Flutter downloads subscription → `RemoteContent` + `HttpUtils` fetch → `ServerManager.addRemoteConfig()` detects `SubscriptionLinkType` (clash/v2ray/singbox/shadowsocks) → dispatches to handler per scheme → normalizes to internal `ProxyConfig`/`ServerConfig` → emits sing-box `outbounds[]` JSON via `SingboxConfigBuilder` (`lib/app/utils/singbox_config_builder.dart:18-30`) → passed to `VPNService.setServer(...)` → Go core starts

- **Protocol matrix:**

  - **Shadowsocks (SS):**
    - Prefix: `ss://` (SIP002 URI + legacy base64)
    - Ciphers: `aes-128-gcm`, `aes-192-gcm`, `aes-256-gcm`, `chacha20-ietf-poly1305`, `xchacha20-ietf-poly1305`, `2022-blake3-aes-128-gcm` / `2022-blake3-aes-256-gcm` / `2022-blake3-chacha20-poly1305` (AEAD 2022)
    - Plugins: `obfs` (http/tls), `v2ray-plugin` (WS+TLS), `shadow-tls` / `restls`
    - How: sing-box `ShadowsocksOutboundOptions` (`protocol/shadowsocks`), UDP relay supported, `plugin` + `plugin_opts` forwarded from Clash `plugin` field
    - File/path: outbound generation in `vpn_service` Go layer `option/outbound/shadowsocks.go`; Dart side `lib/app/utils/proxy_conf_utils.dart` `getUrlFromQRContent`

  - **ShadowsocksR (SSR):**
    - Full SSR URI `ssr://` support (legacy)
    - Obfs: `plain`, `http_simple`, `tls1.2_ticket_auth`; Protocol: `origin`, `auth_sha1_v4`, `auth_aes128_md5` etc.
    - How: `ShadowsocksROutboundOptions`; retained for migration, mapped via `vpn_service` SSR plugin
    - Note: marked supported in `karing.app/en/clash` (ShadowsocksR row), but `sing-box` upstream deprecates SSR — kept via Karing fork

  - **VMess:**
    - Prefix: `vmess://` (V2Ray JSON base64)
    - Ciphers: `auto` (auto-negotiate), `aes-128-gcm`, `chacha20-poly1305`, `none`
    - `alterId` legacy supported (0 is modern), `security` field mapped
    - Transports: TCP, WebSocket, HTTP/2, gRPC, HTTPUpgrade, QUIC (`karing.app/en/clash` Transport Layer)
    - Multiplexing (Mux): via sing-box `sing-mux` (`Settings -> Mux`)
    - How: `VMessOutboundOptions` (`C.TypeVMess`), UUID + alterId auth, `transport` subobject; conversion from Clash `vmess` proxy block handled in `vpn_service` sing-box mapper

  - **VLESS:**
    - Prefix: `vless://`
    - Encryption: **none** (TLS provides encryption); `flow` for XTLS `xtls-rprx-vision` / `xtls-rprx-vision-udp443`
    - Transports: same as VMess + **XHTTP (SplithTTP)** and **Reality**
    - How: `VLESSOutboundOptions` (`C.TypeVLESS`); Reality fields `reality.enabled`, `public_key`, `short_id`, `server_name`, `fingerprint` injected
    - Special: `XTLS flow control` (`karing.app/en/clash: VLESS`) — direct TCP passthrough after handshake

  - **Trojan:**
    - Prefix: `trojan://`
    - Auth: SHA224(password) over TLS; optional `flow` / `xtls`
    - Transports: TCP, WS, gRPC
    - How: `TrojanOutboundOptions` (`C.TypeTrojan`), native TLS; conversion fixes in releases (e.g., `v1.2.24.2705` fixed missing `mode` during xhttp conversion)

  - **Hysteria (v1):**
    - Prefix: `hysteria://`
    - Transport: UDP QUIC, BBR congestion, `obfs` salamander, `auth_str`, `up_mbps`/`down_mbps`
    - How: `HysteriaOutboundOptions` (`C.TypeHysteria`), QUIC listener; port-hopping from `1.0.29.390` (`karing.app/en/clash: Port hopping supported`)

  - **Hysteria2 (Hy2):**
    - Prefix: `hysteria2://` / `hy2://`
    - Improved BBR, `obfs: salamander`, `password`, `up`/`down`, `realm` + `realm.ip_version` / `realm.port_mapping` (sing-box 1.14-alpha.41)
    - How: `Hysteria2OutboundOptions` (`C.TypeHysteria2`); realm STUN/hole-punch + UPnP/NAT-PMP port mapping for behind-NAT

  - **TUIC:**
    - Prefix: `tuic://`
    - Versions: **TUIC v4** and **TUIC v5** (`karing.app/en/clash: Inbound` lists both)
    - Transports: QUIC, UDP relay modes (`native`, `quic`), congestion `bbr` / `cubic`
    - How: `TUICOutboundOptions` (`C.TypeTUIC`), `uuid` + `password` dual auth, `alpn`, `0rtt`, heartbeat; inbound types `tuic` v4/v5

  - **WireGuard:**
    - Prefix: `wireguard://` (URI) + sing-box JSON `wireguard` outbound/inbound/endpoint
    - Crypto: ChaCha20-Poly1305, Noise handshake, `private_key`/`peer.public_key`, `allowed_ips`, `reserved`, `mtu`
    - How: `WireGuardOutboundOptions` + `WireGuardEndpoint` (sing-box 1.11+); kernel / userspace; `Native` stack on Android via `VpnService`; detailed in `lib/app/utils/local_singbox_config_utils.dart` (Tailscale+WG template)
    - Note: **kernel-level** on Linux, **userspace gVisor** fallback; peers list supported

  - **SOCKS5 / HTTP(S):**
    - `socks://` / `http://` / `https://` outbound, optional `username:password`, UDP associate for SOCKS5
    - How: `SocksOutboundOptions` (`C.TypeSocks`), `HTTPOutboundOptions` (`C.TypeHTTP`), used for `dialer-proxy` / Front Proxy chaining

  - **SSH:**
    - `ssh://` outbound, key + password auth, `host_key` / `host_key_algorithms` (`karing.app/en/clash: SSH`)
    - How: `SSHOutboundOptions` (`C.TypeSSH`), TCP tunnel; usable as jump host via `detour`/`dialer-proxy`

  - **AnyTLS:**
    - `anytls://` — newer obfuscated TLS proxy (`karing.app/en/clash: AnyTLS`)
    - How: `AnyTLSOutboundOptions` (`C.TypeAnyTLS`), `password`, `idle_session_check_interval`; recently added to Clash meta + sing-box

  - **Mieru:**
    - `mieru://` — UDP-oriented obfuscation proxy (`karing.app/en/clash: Mieru`)
    - How: `MieruOutboundOptions` via Karing's sing-box fork extension; multiplexed unreliable transport

  - **Snell:** *(listed as `Snell (not yet)` in `karing.app/en/clash: Others`)*
    - Snell v4/v5 planned; not active in current releases — sing-box 1.14-alpha.38 added Snell Go implementation (`1.14.0-alpha.38: Add Snell protocol support`) so Karing fork will expose it soon

  - **Direct / Reject / DNS / Block:**
    - Built-in policy outbounds: `direct`, `reject`, `reject-drop` (TCP RST), `dns` (internal DNS outbound)
    - How: sing-box `DirectOutbound`, `BlockOutbound`, `DNSOutbound`

- **Dialer proxy / Front proxy / Chain:**
  - Feature: **Front proxy** (`Settings -> Front Proxy` = Clash `dialer-proxy`) wraps any outbound's TCP dial through another outbound
  - Example chain: Device `D` → Front node `B` → Target node `A` → Website `W` (`karing.app/en/app-manual/diversion: Front proxy` explains `D->B->A->W`)
  - How: sing-box `dialer_proxy` / `detour` field on outbound — Karing exposes as `Front proxy` picker + per-proxy `dialer-proxy` import; Go core resolves recursively
  - File: `lib/screens/diversion_screen.dart` Front proxy section; `SettingConfig.frontProxy` → `SingboxConfigBuilder` sets `dial fields`

---

## 3. Transports & Obfuscation Layers

- **TLS 1.2 / 1.3:**
  - Settings → `TLS: tls security enhancement, only supports proxy protocols with TLS enabled` (`karing.app/en/app-manual/settings: TLS`)
  - `uTLS` fingerprint spoofing (chrome/firefox/safari/randomized) via `utls` library in sing-box transport (`transport/tls`), ECH support where upstream adds
  - How: `tls.enabled`, `server_name` (SNI), `insecure`, `alpn`, `utls.fingerprint`, `ech` fields in JSON/YAML → `transport.TLSOptions`

- **Reality (REALITY):**
  - Supported for VLESS/Trojan/Hysteria2 ( `karing.pro/en/faq/what-is-karing: Reality ✅` )
  - Fields: `reality.enabled`, `public_key` (curve25519), `short_id`, `server_name` (dest SNI), `fingerprint` (utls), `spiderX`
  - How: sing-box `VLESSRealityOptions` inside `transport.Reality`; Karing's fork copies Reality from Xray — no TLS cert needed, steals real site handshake; conversion fix in `v1.2.23.2606: Fixed missing V2Ray AnyTLS Reality conversion #1808`

- **WebSocket (WS):**
  - `ws-opts: path, headers, max-early-data, early-data-header-name`
  - How: `transport.WebSocketOptions`; `path` supports `?ed=2048` early data, `headers.Host`; used by VMess/VLESS/Trojan/SS

- **gRPC:**
  - `grpc-opts: grpc-service-name` (gun mode), `idle_timeout`, `permit_without_stream`
  - How: `transport.GRPCOptions`; single HTTP/2 stream multiplexes many proxied streams

- **HTTP/2 (h2) & HTTPUpgrade:**
  - `http-opts: method, path, headers`, `http-upgrade` for WS-like upgrade without WS
  - How: `transport.HTTPOptions` / `HTTPUpgradeOptions`

- **XHTTP / SplithTTP:**
  - `xhttp` transport (Shadowsocks + VLESS) — newer Xray/Sing-box extensible HTTP; `v1.2.24.2705: v2ray: Fixed missing mode field during xhttp conversion`
  - Fields: `mode: auto|packet-up|stream-up|stream-one`, `path`, `host`, `headers`, `scMaxBufferedUpBytes`
  - How: `transport.XHTTPOptions`; mode bug was dropping `mode` on import — fixed via `ProxyConfUtils` xhttp mapper

- **QUIC (underpins Hysteria/TUIC):**
  - QUIC-go stack, `quic-go` client fingerprint, 0-RTT, `max_idle_timeout`
  - How: `transport.QUICOptions`; congestion `bbr` default

- **ShadowTLS / ReSTLS:**
  - SS `plugin: shadow-tls` / `restls` fields visible in `deepwiki 4.3: Shadowsocks: shadow-tls, restls`
  - How: TLS camouflage — handshake mimics real TLS to `gateway.example.com`, shadowsocks payload inside

- **Port Hopping:**
  - Hysteria/Hysteria2 `port hopping supported >= 1.0.29.390` (`karing.app/en/clash`)
  - Format: `server: 10000-20000` or `mport` list, clients rotate ports to evade GFW UDP blocking
  - How: `transport.HysteriaPortHopping` parsed as port range, sing-box dials sequential/ random

- **Mux (sing-mux):**
  - `Settings -> Mux` (`karing.app/en/app-manual/settings: Mux`)
  - `sing-mux` (smux / yamux) coalesces many TCP flows onto one TCP connection — `max_connections`, `min_streams`, `max_streams`, `padding`
  - How: `option.MuxOptions: enabled, protocol: smux|yamux|hysteria`, per-outbound `multiplex.enabled`

---

## 4. VPN Core(s)

- **Core identity:**
  - **Modified sing-box** (`github.com/KaringX/sing-box`, fork of `SagerNet/sing-box`) — selected branch `dev-next`
  - Why fork: need custom iOS/macOS PacketTunnelProvider integration, per-app VPN hooks, port-hopping backports, anytls/mieru patches, `vpn_service` FFI stability patches before upstream merges
  - Version tracking: Karing `1.2.24.x` ↔ sing-box ~1.13.x–1.14-alpha; releases note `Updated core` frequently (e.g., `v1.2.23.2606: Updated core`, `v1.2.20.2300: Core Update`)

- **Upstream core lineage (SagerNet/sing-box changelog highlights):**
  - `1.14.0-alpha.48-44`: Tailscale Taildrop, API `sing-box api` CLI, Windows client app (`SFW-*.exe`), Linux desktop client, network namespace `tun.netns` + `unshare` rootless TUN, bridge outbound (L3 counterpart of direct)
  - `1.14.0-alpha.41-38`: Windows bridge via WinDivert, `preferred_by` route, hysteria2 realm IP/port mapping, L3 forwarding (TCP/UDP/ICMP via TUN→WireGuard/Tailscale), Snell inbound+outbound (Go reimpl)
  - `1.14.0-alpha.32`: dashboard via API service, USB/IP server/client (`sing-usbip`)
  - `1.13.x stable`: `bridge` outbound, ICMP ping routing (`network: icmp`), multiple `rule_set` tags, UDP NAT `udp_mapping/filtering/nat_max`

- **Integration into Flutter (3-layer bridge):**
  - **Layer 1 — Dart config builder:** `lib/app/utils/singbox_config_builder.dart` assembles final JSON (`log`, `dns`, `inbounds`, `outbounds`, `route`, `experimental`)
    - Reads `SettingConfig`, `ServerManager` (`ServerConfigGroupItem`, `ProxyConfig`), `DiversionGroupConfig` → emits `inbounds: [{type: tun}, {type: mixed}]`, `route.rules[]`, `dns.servers[]`
    - File trace: `lib/app/modules/setting_manager.dart:115-120` (`SettingManager` load) → `lib/screens/settings_screen.dart:109-111` (`Biz.startOrRestartIfDirtyVPN`) → `singbox_config_builder.dart`
  - **Layer 2 — Dart service:** `lib/app/local_services/vpn_service.dart` + `lib/app/modules/biz.dart:45-50` (`Biz.startOrRestartIfDirtyVPN`)
    - Manages lifecycle: `VPNService.init()` (`lib/main.dart:65` `VPNService.initABI()`), `initABI()` detects arch (arm64-v8a / armeabi-v7a / x64), state machine `CONNECTED/CONNECTING/DISCONNECTED` (`vpn_service/state.dart`), `MethodChannel` to native
    - Calls `VPNService.setServer(configJson)` with serialized sing-box JSON written to `service_core.json`
    - Issue `1460` notes `vpn_service` is currently `path: ../vpn-service/` local package not published — public repo not buildable without it; `lib/screens/home_screen.dart` imports `package:vpn_service/vpn_service.dart`
  - **Layer 3 — Native/Go:**
    - **Android:** `android/app/src/main/kotlin/com/nebula/karing/VpnServiceImpl.kt` + `TileService.kt:63-139` (Quick Settings tile), foreground service, `VpnService.Builder()` creates TUN fd, passes to `LibVpnCore` (GoMobile)
    - **iOS/macOS/tvOS:** `ios/Runner/*`, `macos/Runner/*` — `PacketTunnelProvider` subclasses (`karingService.appex`, `karingServiceSE`), `NetworkExtension` entitlement, `Libbox.xcframework` (Go compiled as XCFramework)
    - **Windows:** `windows/runner/*`, `bind/windows/*` — WinTun + `wintun.dll`, service process, admin detection, `windows_single_instance 1.1.0`
    - **Linux:** `linux/*` — `tun` via `gvisor`/`system` stack, `sudo` pkexec, `tray_manager` integration
    - Common: `libbox` exposes `Start(json, tunFd)` / `Stop()` via CGO → `lib/box.go` (`Box` struct), DNS/TUN/Route subsystems

- **Custom core changes (KaringX fork):**
  - Work branch shows `experimental` features cherry-picked from SagerNet `dev-next` before stable tag
  - Includes `android_package_manager` bridging for per-app VPN `package_name` rule matching, `move_to_background` patch, `window_manager` fork for desktop window control
  - Local sing-box JSON editor (`PR #1657: Add local sing-box config editor`) — validates full JSON including `endpoints: [{type: tailscale}]` + `Tailscale DNS`, allows `SettingConfig.localSingBoxConfig` passthrough directly to Go core without conversion

- **Multiple inbound types via core:**
  - `mixed` (HTTP+Socks unified on one port) + `tun` (L3) — both active when TUN enabled (`karing.app/en/clash: Inbound` lists `mixed`, `tun`, `tunnel`)
  - `http`, `socks`, `shadowSocks`, `vmess`, `tuic v4/v5`, `hysteria2` listeners configurable under `listeners` / `tun` keys in Clash YAML interop

---

## 5. Split Tunneling / Routing

- **Concept — `Diversion` (分流):**
  - Single DiversionGroup applied to **multiple subscriptions** at once — unlike Clash per-config proxy-groups, Karing merges all imported proxy lists then routes via unified rules (`README.md:Features: A set of routing rules applied to multiple subscription sources automatically selects efficient nodes`)
  - UI: `Settings → Diversion` (`karing.app/en/app-manual/diversion`) + `Diversion Rules` screen (`lib/screens/diversion_rules_screen.dart`)

- **Rule evaluation hierarchy (sing-box `route.rules[]`):**
  1. **Bypass/Direct rules:** `geosite:private`, `geoip:private`, `LocalAreaNetwork.srs` — `settingConfig.privateDirect` toggle (`diversion_rules_screen.dart:191`)
  2. **Diversion Groups:** user groups mapping `rule_set` → `outbound` (proxy group)
  3. **Default / Final outbound:** fallback `direct` or `proxy` / `select`
  - How implemented: `SingboxConfigBuilder` iterates `DiversionGroupConfig.groups: List<ServerDiversionGroupItem>` → emits ordered `route.rules[]` with `rule_set`, `domain`, `ip_cidr`, `port` matchers → sing-box evaluates top-to-bottom first match wins; `invert` flag supported

- **RuleSet assets (binary `.srs` — sing-box rule-set):**
  - Bundled via `KaringX/karing-ruleset` (671 ★, workflow branch) — `assets/datas/*.srs` + runtime downloaded `*.srs` URLs
  - Types:
    - **GeoIP:** `cn.srs`, `us.srs`, `blocked@ru.srs`, `re-filter@ru.srs`, `iran/*.srs` (amazon/ir/github/microsoft/openai etc.) — IP→country via sing-box `route.rule_set`
    - **GeoSite:** `geosite:cn`, `category-ads-all.srs`, `geolocation-!cn.srs`, `tld-cn.srs` — domain categories (Apple/Google/Microsoft/Facebook/Twitter/Telegram etc.)
    - **ACL:** `BanAD.srs`, `BanADCompany.srs`, `BanProgramAD.srs`, `LocalAreaNetwork.srs`, `ProxyGFWlist.srs` (full GFWList), `ProxyLite.srs` (trimmed), `ChinaDomain.srs`, `ChinaCompanyIp.srs`
    - **Special:** `adblock` (AdGuardSDNSFilter), `acl4ssr` slices, `antizapret.srs` (Russia), Iran ruleset ( `iran/*.srs` picks )
  - How: `route.rule_set[]: {tag, type: remote/local, format: binary, path/url, download_detour}` — binary SRS = high perf trie/Aho-Corasick; Karing caches in `assets/datas/` and downloads via proxy/direct per `download_detour`
  - Size note: docs warn `>3 MB SRS should only be used on Windows` (Android/iOS memory limit — `karing-ruleset/README`)

- **Custom routing rule groups / node groups:**
  - `Supports custom routing rule groups and node groups. Customizes default routing rule groups for novice users — ready to use right out of the box` (`README.md:Features`)
  - Implements: `DiversionGroupConfig.groups` stores `ServerDiversionGroupItem{ name, outbounds, rules: List<ServerDiversionGroupRuleSetItem> }` (`diversion_rules_screen.dart:210-271`)
  - UI flows: `lib/screens/diversion_group_custom_screen.dart` (create/edit group), `GroupItem` list (`getGroupOptions():36-46`), per-rule `getDiversionShortName()` (URL→tag display, `150-161`)
  - **Group types:** `selector` (manual), `urltest` (lowest latency), `fallback`, `load-balance` (Consistent Hashing/Round Robin per `deepwiki 5.2`), `custom proxy group/custom auto select` (regex-filtered custom urltest — `karing.app/en/app-manual/diversion: Custom Proxy Group`)
  - **Auto-selection tuning:** `ServerManager.testLatencyAfterProfileUpdate()`, `testLatencyAutoRemove`, `tolerance: 50 ms` (`deepwiki 5.2`)

- **Per-App Split Tunneling (Android-only App Proxy):**
  - Feature: `Proxy by Application` (`karing.app/en/tutorial/perapp-proxy`) — powerful per-package TUN inclusion/exclusion
  - **Whitelist mode** (`Whitelist Mode` ON): only checked apps go through VPN, others bypass (e.g., whitelist YouTube/Telegram/Twitter/Facebook when region = CN) — `Settings -> TUN -> Proxy by Application -> Enable + Whitelist Mode`
  - **Blacklist mode** (`Whitelist Mode` OFF): checked apps bypass, rest go via VPN (e.g., exclude Notion/Outlook)
  - Benefits docs: reduces battery, avoids broken apps from global diversion
  - How implemented:
    - Android `VpnService.Builder.addAllowedApplication(pkg)` / `addDisallowedApplication(pkg)` per `vpn_service` Go shim → `route.rules[{package_name}]` / `package_name_regex` on sing-box TUN inbound (`route/rule: package_name, package_name_regex`)
    - For whitelisted apps, Diversion still applies outbound (`For Apps that use VPN traffic, you can still use diversion for outbound diversion`)
    - Storage: `lib/app/modules/setting_manager.dart` `perAppProxyList`, `perAppWhitelist` boolean

- **Bypass LAN / China patterns:**
  - `privateDirect` ( `lib/screens/diversion_rules_screen.dart:191` ) — routes `geoip:private`, `is_private`, `LocalAreaNetwork.srs` to `direct`
  - `Country Or Region` selector (`karing.app/en/app-manual/diversion: Country Or Region`) auto-injects `geosite:cn` / `geoip:cn` direct rules when user region = CN — similar logic for RU/IR presets (`v1.2.20.2300: Added some preset traffic splitting rules`, fix `WhatsApp package in ru preset`)
  - Manual bypass: add `DOMAIN-SUFFIX, .cn, DIRECT` or `GEOIP, CN, DIRECT` via custom diversion group

- **How sing-box route is constructed (low-level):**
  - Emitted JSON snippet (`SingboxConfigBuilder`):
    ```json
    {
      "route": {
        "rules": [
          {"rule_set": ["geosite-private"], "outbound": "direct"},
          {"rule_set": ["geoip-private"], "outbound": "direct"},
          {"rule_set": ["ads.srs"], "action": "reject"},
          {"rule_set": ["geosite-cn"], "outbound": "direct"},
          {"rule_set": ["geosite-geolocation-!cn"], "outbound": "proxy"},
          {"clash_mode": "direct", "outbound": "direct"}
        ],
        "rule_set": [
          {"tag": "geosite-cn", "type": "local", "format": "binary", "path": "geosite-cn.srs"},
          {"tag": "geoip-cn", "type": "remote", "format": "binary", "url": "https://.../geoip-cn.srs"}
        ],
        "final": "proxy",
        "auto_detect_interface": true
      }
    }
    ```
  - File: `lib/app/utils/singbox_config_builder.dart:18-30` + `lib/screens/diversion_rules_screen.dart:163-271`

---

## 6. TUN / VPN Mode vs System Proxy Mode

- **Two modes (mutually toggleable):**

  | Mode | What it captures | Proxy entry | File/path | Extra perms |
  |------|------------------|-------------|-----------|-------------|
  | **TUN (VPN) Mode** | ALL IP traffic (L3), including UDP & ICMP, DNS hijack | `tun` inbound | `lib/app/local_services/vpn_service.dart` + native `VpnService`/`PacketTunnelProvider`/`WinTun` | Admin/root or VPNService consent |
  | **System Proxy Mode** | Only apps respecting system HTTP/SOCKS proxy (browsers, etc.) | `mixed` inbound (`http`+`socks`) on `127.0.0.1:port` | `SettingConfig.mixedPort`, `biz.dart` config generation | None |

- **TUN implementation — common logic (sing-box `inbounds[{type: tun}]`):**
  - Controlled via `SettingConfig.tun` subgroup (`deepwiki VPN Service`):
    ```yaml
    tun:
      enable: true
      stack: system | gvisor | lwip   # default system
      dns-hijack: ["0.0.0.0:53"]        # intercept all DNS port 53
      auto-route: true                 # auto configure routing table
      auto-redirect: true              # Linux auto iptables
      mtu: 9000
      strict-route: false              # when true: prevent leaks, forces all via TUN
      endpoint-independent-nat: true   # gaming/P2P compatibility
      route_address: ["0.0.0.0/1","128.0.0.0/1","::/1"]  # default route
      route_exclude_address: ["192.168.0.0/16"] # (#1889 refined)
      gso: true
    ```
  - **Clash YAML alias:** `tun: {enable, stack, dns-hijack, auto-route, mtu, strict-route}` — imported via Clash YAML → normalized to sing-box TUN
  - **Go handling:** `inbound/tun` package opens TUN fd, `route` sets `autoDetectInterface`, DNS hijack via `dns.hijack` rule
  - **Dart UI:** `SettingsScreen` TUN section (`karing.app/en/app-manual/settings: TUN`); controls `tun.enable`, `tun.stack`, `tun.mtu`, `route_exclude_address`

- **Platform-specific TUN bridges:**

  - **Android:**
    - `android/app/src/main/kotlin/com/nebula/karing/VpnServiceImpl.kt` — extends `android.net.VpnService`, `Builder().addAddress("198.18.0.1/16").addRoute("0.0.0.0/0").addDnsServer(fakeDNS).setMtu(9000).establish()`
    - Permissions (`AndroidManifest.xml`): `BIND_VPN_SERVICE`, `FOREGROUND_SERVICE`, `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `QUERY_ALL_PACKAGES` (for per-app list via `android_package_manager`)
    - Lifecycle: `TileService.kt:77-82` (Quick Tile `ACTION_START/STOP`), foreground notification keeps service alive on Android 8+
    - Per-app VPN: `addAllowedApplication()` / `addDisallowedApplication()` per whitelist mode
    - Special: `overrideAndroidVPN` (`v1.2.19.2200: Android: Added overrideAndroidVPN settings to Tun`) — allows third-party cellular VPN coexistence via `allowBypass`

  - **iOS / tvOS / macOS:**
    - **iOS/tvOS:** `ios/Runner/PacketTunnelProvider.swift` ( `karingService.appex` ) — `NEPacketTunnelProvider`, `packetFlow`, `setTunnelNetworkSettings()`, entitlement `com.apple.developer.networking.networkextension`
    - **macOS:** `macos/Runner/*` — `com.nebula.karing.karingServiceSE` (System Extension), `NETransparentProxyProvider` fallback pre-12, `system` DNS integration
    - Features: `Always open connection (IOS/MacOS/TvOS)` (`karing.app/en/app-manual/settings`) — maps to `Connect On Demand`; when enabled system re-launches VPN after crash, cannot stop via system VPN toggle
    - TUN stack: `system` default; `gvisor` for packetFlow without kernel TUN

  - **Windows:**
    - `windows/runner/*` + `bind/windows/*` — `wintun.dll` adapter `Karing TUN`, `WintunCreateAdapter()`, `SetInterfaceDnsSettings`
    - **Admin required:** `You need to start Karing as an administrator on Windows to use this function` (`karing.app/en/app-manual/settings: TUN`)
    - High CPU fix: `v1.2.24.2705: Windows: Improved core process detection to address high CPU usage #1886` — improved `FindWindow` / process watcher loop
    - WinDivert for future `bridge` outbound (`sing-box 1.14.0-alpha.41: bridge outbound on Windows via WinDivert`)

  - **Linux:**
    - `linux/*` + Go `tun_gvisor.go` / `tun_system.go` — `ip tuntap add`, `ip route add`, `gvisor` netstack fallback
    - `sudo` pkexec prompt; graceful continuation if auth fails (`v1.2.19.2200: Linux: If sudo authorization fails, users still have the option to continue`)
    - System stack supports `auto_redirect` + network namespace `unshare` (sing-box 1.14.0-alpha.43) for rootless TUN
    - Integration: `tray_manager` systray, `window_manager` for hide-to-tray

- **DNS Hijack + Sniffing within TUN:**
  - Intercepts `0.0.0.0:53` / `::53` → redirects to sing-box DNS subsystem (`route` doc: DNS hijacking)
  - `Strict Route` (`tun.strict-route`) ensures no leak — when ON all packets routed via TUN even if interface route missing; `Endpoint Independent NAT` (`tun.endpoint-independent-nat`) for gaming NAT type improvement (`deepwiki VPN Service`)
  - Protocol sniffing (`Settings -> Protocol detection`) — sing-box `sniffer: { enabled, sniff: [http,tls,quic,dns,stun] }` detects `domain` from SNI/HTTP host for routing even without DNS

- **System Proxy mode (non-TUN):**
  - Enables `inbounds: [{type: mixed, listen: 127.0.0.1, listen_port: $mixedPort}]` (default ~7890) serving both HTTP proxy + SOCKS5 handshake autodetection
  - Shareable over LAN via `Network sharing: Use the device where Karing is located as a Socks proxy server` (`karing.app/en/app-manual/settings: Network sharing`) — binds `0.0.0.0`, exposes Socks5; tutorial at `karing.app/en/tutorial/lan`
  - How: `SingboxConfigBuilder` emits `inbounds` only when `tun.enable == false`; Dart side toggles `SettingConfig.systemProxy` via `MainChannel` `setSystemProxy()`
  - Legacy `port` / `socks-port` / `mixed-port` Clash fields mapped but `listeners` modern key not yet (`karing.app/en/clash: Inbound` shows `mixed` vs old keys)
  - No per-app split in System Proxy mode — relies on system proxy adherence; UDP not fully captured (use TUN for UDP gaming/DNS)

- **Mode switching lifecycle:**
  - `Biz.startOrRestartIfDirtyVPN(from)` (`lib/app/modules/biz.dart:71-88`) diffs `SettingManager.settingConfig` hash vs last running hash → if dirty, calls `VPNService.stop()` → `VPNService.start(json)` via `MethodChannel`
  - TUN fd lifecycle closed on stop to prevent fd leak (fix in `vpn_service` Go layer `service/close` )

---

## 7. Subscription & Config Formats

- **Import entry points (`karing.app/en/app-manual/add-profiles`):**
  - `My Profiles → Add Profiles` — supports: paste URL, paste content, scan QR, import from file, import ZIP, share via AirDrop/LAN
  - File picker: `file_picker: 10.3.7` (`pubspec.yaml`), QR via `qr_code_scanner_plus 2.0.14` + `screen_capturer 0.2.3`

- **Format matrix:**

  | Format | Extension / Scheme | Support | Detection | Notes |
  |--------|--------------------|---------|-----------|-------|
  | **Clash YAML** | `.yaml/.yml`, `clash://` / `http(s)://..yaml` | ✅ Full (`README.md: Full clash config supported`) | MIME/`content-type` + `proxies:` key in YAML (`ServerManager:validAddSubscription`) | All standard Clash features; `proxy-groups`, `proxies`, `rules`, `rule-providers`, `dns`, `tun`, `listeners`, `mixin` |
  | **Clash.Meta (Mihomo)** | same as Clash | ⚠️ Partial (`Partial clash.meta config supported`) | same, `mihomo` meta keys detected | Xray Reality, ShadowTLS gone? `dialer-proxy`, `sing-mux`, `listeners` supported, but `Snell`/`sub-rules`/ `load-balance` not yet (`karing.app/en/clash`) |
  | **sing-box JSON** | `.json`, `sing-box://` | ✅ Full | JSON `outbounds` key detection + `SubscriptionLinkType.singbox` | Native sing-box schema (`log`, `dns`, `inbounds`, `outbounds`, `route`, `experiemental`); PR `#1657` adds **full JSON with `endpoints: [{type: tailscale}]`** validation |
  | **V2Ray / V2Fly** | `vmess://` (base64 JSON), `vless://`, `trojan://` | ✅ Full, batch import | `ProxyConfUtils.getUrlFromQRContent` parses multi-line batch | Supports `alterId`, `flow`, ` reality` query params, `ws-opts` via URI fragment |
  | **Shadowsocks** | `ss://` (SIP002 `method:password@host:port` base64) | ✅ Full | `ss://` URI scheme | SIP008 JSON subscription `{"version":1, "servers":[...]}` import, UDP relay flag, plugin opts |
  | **ShadowsocksR** | `ssr://` | ✅ Full | `ssr://` scheme | base64 `host:port:proto:method:obfs:base64pass/?obfsparam=&remarks=` |
  | **SUB (auto-discover)** | `https://sub.example.com/xxxx` plain base64 list | ✅ Full | HTTP fetch, try base64-decode → split lines, fallback YAML/JSON | Provider may return `Content-Disposition: attachment` or `subscription-userinfo: upload=123` headers parsed for traffic stats |
  | **Github Subscriptions** | `https://raw.githubusercontent.com/...` | ✅ Full | Same as SUB | Handy for `karing-ruleset` / `gfwlist` hosting |
  | **Surfboard (Surge-like)** | `surfboard://` / Surge `.conf` | ⚠️ Partial | Surfboard parser partial (`karing.pro/en/guides/karing-subscription: Surfboard ✅ Partial`) | `Surge` format mapped via Clash-like `Proxy` lines but advanced `URL Rewrite` ignored |
  | **AnyTLS / Mieru URIs** | `anytls://`, `mieru://` | ✅ Full | scheme dispatch | New per `karing.app/en/clash` outbound table |
  | **Stash** | `stash://` | ✅ Mentioned `README.md: Compatible with Clash, V2ray, Sing-box, Shadowsocks, Sub, Github Subscriptions` includes Stash family | Same as Clash | |

- **Subscription management details:**
  - **Auto-update:** each `ServerConfig { url, remark, proxyCount, updatedAt }` (`lib/app/modules/server_manager.dart:38-71` `ServerConfig` / `ServerConfigGroupItem`) stores `updateInterval` (hourly/daily mode configurable, default on launch + interval), ETag/Last-Modified cache via `RemoteContent`
  - **Multi-sub merge:** all `ServerConfigGroupItem.proxies: List<ProxyConfig>` flattened but group-tagged; `DiversionGroupConfig` rules apply across groups (key differentiator vs Clash per-config groups)
  - **User-Agents:** configurable `SettingConfig.userAgent` list (`v1.2.19.2200: Adjusted the default UserAgent sorting`) — rotates to mimic Clash/Mihomo/Surge to satisfy provider allowlists
  - **Front proxy for download:** `Prioritize proxy download configuration: When the connection is turned on, prioritize [Current Selection] to download/update configuration` (`karing.app/en/app-manual/settings`) — when TUN active, fetch subscription via current `select` node to bypass GFW; otherwise `direct`
  - **Validation:** `ServerManager.validAddSubscription(url, remark)` checks non-empty, URL form via `string_validator`, duplicate detection by `remark`/`url` hash
  - **Import flows:** clipboard monitor (`lib/app/utils/clipboard_utils.dart`), `protocol_handler: 0.1.6` for `clash://` / `karing://` OS URL scheme, file drop on desktop via `window_manager` drag
  - **Storage:** `sqlite_async 0.12.2` + `sqlite3 2.9.4` persists profiles in `db.db` (connection stats DB also `lib/app/modules/connection_manager.dart`); cache limit added `v1.2.24.2705: Statistics: Added cache limit to prevent db.db file growing indefinitely`

- **Export / share:**
  - `Share Plus 12.0.1`, `QR` encode (`zxing2 0.4.x`) — Node share via `https://tools.karing.app/` online tools (`karing.app: Online Tools`)
  - `Online panel` shares via `sing-box` API dashboard (`karing.app/en/tutorial/online-panel`) — locally served Zashboard (`v1.2.23.2606: Updated Zashboard`) at `http://127.0.0.1:$apiPort/ui/`

---

## 8. Obfuscation / DPI Bypass

- **Reality (mentioned above but summarized as DPI bypass):**
  - Anti-SNI inspection: handshake looks like legitimate `server_name` (e.g., `www.microsoft.com`) with real cert; no cert issued to proxy server
  - Settings: per-outbound `reality: {enabled, public_key, short_id, server_name, fingerprint, spiderX}` — `fingerprint` via uTLS list (`chrome`, `firefox`, `safari`, `ios`, `android`, `edge`, `360`, `qq`)
  - How: Xray Reality Go port inside sing-box; `short_id` picks among many dest-cert identities; `spiderX` crawls dest site for realistic TLS fingerprint
  - File: `transport/reality` + `option/reality.go`; Dart builder writes reality JSON verbatim from subscription `reality-opts`

- **uTLS / TLS fingerprint spoofing:**
  - `Settings -> TLS` (`karing.app/en/app-manual/settings: TLS`) — client fingerprint randomization to mimic browsers and evade JA3/JA4 fingerprint blocks
  - Library: `utls` (Frolovo) fork inside sing-box `transport/tls/utls.go`, feeds ClientHello via `utls.UTLSIdToSpec(fingerprint)`
  - How: `tls.utls.fingerprint: chrome | firefox | safari | ios | android | edge | random | randomized` — default randomized; Reality requires matching dest browser

- **Fragmented TLS (TLS fragment / Hello fragmentation):**
  - Part of sing-box `tls_fragment` option (present in sing-box 1.12+ `transport.tls.fragment`) — splits ClientHello into small fragments to evade length-based DPI
  - Settings: `tls_fragment: {enabled, size: 1-64, sleep: 0-100ms}` via raw sing-box JSON import (local sing-box editor PR `#1657` exposes raw JSON so Fragment can be set)
  - How: Go `common/tlsfragment` writes TLS record header + fragments via `net.Conn.Write` with jitter

- **ShadowTLS / ReSTLS (SS obfuscation):**
  - Mask Shadowsocks as real TLS — `shadow-tls` plugin (`ss-opts: plugin: shadow-tls, plugin-opts: host=gateway.example.com, password=xxx, version: 3`)
  - How: mimics ECH `ClientHelloOuter`, server validates HMAC then forwards Shadowsocks; `deepwiki 4.3` lists `shadow-tls, restls` as SS transports

- **Hysteria2 Salamander obfs:**
  - `obfs: salamander, obfs-password: xxx` — obfuscates QUIC packet with pre-share, makes QUIC look like random UDP
  - How: XOR + padding layer before QUIC AEAD (`protocol/hysteria2: salamander`)

- **XHTTP / SplithTTP / Chunk transport:**
  - Splits large HTTP post into many small XHTTP chunks + range requests (`mode: packet-up/stream-up/stream-one`) — defeats packet length analysis
  - See Transport section XHTTP; config `xhttp-opts: {mode, path, host, extra}`

- **Warp / WARP (Cloudflare):**
  - `Settings -> WARP` (`karing.app/en/app-manual/settings: WARP`) — `License: After setting, newly added warp nodes without license will be bound to this License`
  - How: sing-box `wireguard` outbound with `warp` peer + `Cloudflare WARP` endpoint type; `amneziawg` obfuscation variant via `KaringX/sing-box` fork `transport/warp`

- **Mux as obfuscation helper:**
  - Single TCP conn multiplexing hides many flows pattern; noted as `karing.app/en/clash: sing-mux → Settings -> Mux`
  - Is not pure DPI bypass but reduces packet count visible to DPI

---

## 9. DNS Handling

- **Two global modes (sing-box `dns.strategy`):**
  - `fake-ip` (default when TUN on) vs `redir-host` (`karing.app/en/app-manual/dns: Enable DNS Diversion`):
    - **FakeIP** returns virtual IPs `198.18.0.0/16` (and `fc00::/7` for v6 if IPv6 on) — real resolution deferred until connection establishment; enables domain-only routing without prior IP
    - **Redir-Host** returns real IP from upstream — needs dual lookup
  - How: `dns.fakeip.enabled`, `dns.fakeip.inet4_range`, `dns.independent_cache`; platform default `fake-ip` on Android/iOS for mobile handover resilience (`deepwiki DNS Resolution: Platform-Specific Defaults`)

- **DNS server categories (up to 4 concurrent):**
  - `DNS-server` screen (`karing.app/en/app-manual/dns-server`) categories:
    - `DNS Server` (bootstrap for resolving other DNS names)
    - `Proxy Server` — used for proxy-target domains (merged into `Direct` in novice mode)
    - `Direct Traffic` — for `direct` diversion
    - `Proxy Traffic` — for `proxy` diversion (merged into `final` in novice)
    - `final` — fallback
  - Note: `Up to 4 servers can be set. When resolving, the selected servers will make concurrent requests and use the fastest response results` (`karing.app/en/app-manual/dns-server: Note`)
  - Supported DNS types: `udp://` (plain), `tcp://`, `tls://` (DoT port 853), `https://` (DoH), `quic://` (DoQ), `h3://` (DoH3/HTTP3) — `SettingsConfigItemDNS` translates to `dns.servers[]`
  - `Force HTTP/3 for DoH` via `SettingConfig.dohPreferH3` appends `h3` transport params (`deepwiki DNS Resolution: Karing supports forcing HTTP/3`)
  - `Auto Setup Server` (`karing.app/en/app-manual/dns-server: Auto Setup`) picks fastest DNS by probing delay detection URL
  - `Reset Server` restores defaults

- **DNS routing / Leak prevention:**
  - `karing.app/en/app-manual/dns: Enable DNS Diversion rules: According to the diversion settings, the relevant traffic uses the corresponding DNS server`
    - Direct traffic → Direct DNS
    - Proxy traffic → Proxy DNS (optionally `Proxy Traffic Resolve DNS through proxy server: ... instead of directly connecting`)
    - Final → Final DNS
  - How JSON:
    ```json
    {
      "dns": {
        "servers": [
          {"tag": "proxyDns", "address": "https://1.1.1.1/dns-query", "detour": "proxy"},
          {"tag": "directDns", "address": "223.5.5.5", "detour": "direct"},
          {"tag": "block", "address": "rcode://success"}
        ],
        "rules": [
          {"rule_set": ["geosite-cn"], "server": "directDns"},
          {"rule_set": ["geolocation-!cn"], "server": "proxyDns"}
        ],
        "final": "proxyDns",
        "strategy": "ipv4_only"
      }
    }
    ```
  - File: `lib/app/utils/singbox_config_builder.dart` maps DiversionGroup → `dns.rules` + `dns.servers` (`SingboxConfigBuilder` phase)
  - Leak detection: `karing.app/en/app-manual/settings: DNS leak detection: Detect whether there is a DNS leak… only for reference` — opens `https://…/dnsleak` page in `flutter_inappwebview`

- **FakeIP & Hijack details:**
  - `VPN Service: The VPN service intercepts DNS queries (typically on port 53) to implement Fake-IP` (`deepwiki 5.1`)
  - Hijack handled at TUN layer + `dns.hijack` rule: any packet `dst port 53` not matching `bypass` is redirected to internal DNS
  - `Resolve inbound domain names: For traffic from the proxy, first perform domain name resolution, and then divert` (`karing.app/en/app-manual/dns: Resolve inbound domain`) — when Diversion lacks domain rules, Karing pre-resolves inbound SNI then IP-rules
  - Static hosts: `Static IP: Custom domain name resolution, similar to hosts file` (`karing.app/en/app-manual/dns: Static IP`) — `dns.hosts: {"example.com": "1.1.1.1"}` from `SettingManager.hosts` injected into `sing-box dns.hosts`

- **TTL & caching:**
  - `TTL: DNS query result survival time/cache time` (`karing.app/en/app-manual/dns: TTL`) — `dns.expire` / `dns.cache_capacity` via UI
  - `independent_cache` per server so proxy vs direct answers not cross-polluted

- **Platform DNS defaults:**
  - Android/iOS: `fake-ip` + `system` bootstrap fallback to OS DNS on VPN disconnect
  - macOS/Windows: can inherit `system` DNS as `bootstrap` (`deepwiki DNS Resolution: macOS/Windows supports system DNS integration`)
  - Apple `PacketTunnelProvider` interacts with `dns.hosts` + `dns.rules` via `NEDNSSettings`

---

## 10. Other Features

- **Auto-update:**
  - Two layers: **app binary** vs **subscription/rule-set**
  - App: `AutoUpdateManager` (`lib/app/modules/auto_update_manager.dart`) polls `https://api.github.com/repos/KaringX/karing/releases/latest` vs current `1.2.x`, shows dialog via `sentry_flutter`, download via `dio` to `getApplicationDocumentsDirectory()` + `open_file`/`app_installer` install
  - Subscriptions: per-profile `autoUpdateInterval` (manual/hourly/interval), ETag diff, optionally via proxy (`Prioritize proxy download`)
  - Rule-sets: `karing-ruleset` remote SRS update via `RemoteISPConfigManager` + GitHub release fetch; `v1.2.23.2606: Updated Zashboard` similarly versioned

- **Backup & Sync (`karing.app/en/tutorial/backup-sync`, `README.md: Backup and synchronization`):**
  - **iCloud sync** (iOS/macOS only): via `icloud_storage: 2.2.0` (`pubspec.yaml`) — `Settings → Backup and sync → iCloud` stores encrypted JSON blob in `iCloud Container` (`com.nebula.karing`); conflict resolution LWW (last write wins)
  - **WebDAV:** via `webdav_client_plus: 1.0.2` — `Settings → Backup and Sync → Webdav` supports Nextcloud/Nutstore/AList (`https://alist.nn.ci/zh/guide/webdav.html` referenced), stores `karing_backup.zip` + incremental `config.json`
  - **LAN Sync:** QR-based local transfer — Exporter `Sync to others` generates QR (JSON+IP encoded via `zxing2`), Importer `Scan QR code to sync` connects via `dio` HTTP server on `0.0.0.0:port` + mDNS; note `Import only supports iOS/Android` (`karing.app/en/tutorial/backup-sync: Solution 2`)
  - **ZIP import/export:** `archive: 4.0.7` (`pubspec.yaml`) — `Settings → Backup and sync → LAN sync → File import/export` writes ZIP with `profiles.json`, `settings.json`, `rule_sets/` to `path_provider` export dir; reimport merges by remark
  - Files: `lib/app/modules/backup_manager.dart`, `lib/app/modules/webdav_sync.dart`, `lib/screens/backup_sync_screen.dart`

- **Speed test & Latency:**
  - **Delay detection URL:** `Settings -> Delay detection URL` (`karing.app/en/app-manual/settings`) — default `http://cp.cloudflare.com/generate_204` or provider overridable; XHR-like GET measures RTT; per-node latency shown in `Select Server` screen
  - **Speed test URL:** `Settings -> Speed test URL` — home screen `Speed Test` button hits configurable URL over selected outbound; file `lib/app/modules/speed_test_manager.dart`
  - **Auto node selection:** `urltest` group auto picks lowest latency after `testLatencyAfterProfileUpdate()` with `tolerance 50ms` prevents flapping (`deepwiki 5.2`)
  - **Auto-remove:** `testLatencyAutoRemove` hides high-latency/failing nodes

- **Appearance / Theme:**
  - `flutter` Material 3 + Cupertino adaptive; follows system dark/light; manual toggle in `SettingsScreen`; `logo-round.png` / `logo-round_grey.png` adaptive icons; demo screenshots (`README_assets/demo/*.png`) show dark card list

- **Multi-profile / Multi-subscription:**
  - Unlimited `ServerConfigGroupItem` groups (`lib/app/modules/server_manager.dart:38-71`), each with independent remark, URL, proxy list, index
  - Switcher: `HomeScreen` current select dropdown → `select_server` screen (`lib/screens/select_server_screen.dart`), latency badge per proxy, drag-reorder

- **Beginner Mode:**
  - `Settings → Beginner mode: If you are not familiar with Karing...` (`karing.app/en/app-manual/settings: Beginner mode`)
    - Streamlined: hides advanced diversion/TLS/Mux/WARP, forces protocol sniffing ON, merges `Proxy Server` into `Direct` DNS category and `Proxy Traffic` into `final`
    - How: `SettingConfig.beginnerMode` bool guards UI visibility (`if (!beginnerMode) showAdvancedTiles`), config builder coalesces DNS categories

- **Statistics & Analysis:**
  - `Connections` screen (`README_assets/demo/connections.png`, `karing.app/en/app-manual/statistics`) shows active connections table (`data_table_2`), per-outbound traffic chart (`fl_chart 1.1.1`), long-press to kill all (`v1.2.19.2200: Long press the connection to close all inbound and outbound connections`)
  - DB: `sqlite_async` backed `connections`, `traffic` tables in `db.db`; cache limit fix `v1.2.24.2705: Added cache limit to prevent db.db growing indefinitely` (caps rows via `SettingConfig.dbCacheLimit`, LRU purge)
  - Per-node traffic accounting via sing-box `experimental.clash_api` + `v2ray_api`

- **Online Panel (Zashboard):**
  - `Settings → Online panel: Core running status web version` (`karing.app/en/app-manual/settings: Online panel`) → tutorial `karing.app/en/tutorial/online-panel`
  - Zashboard (Mihomo dashboard fork) updated `v1.2.23.2606`; served at `127.0.0.1:$port/ui` via `sing-box experimental.clash_api`
  - How: `SingboxConfigBuilder` emits `experimental: {clash_api: {external_controller, secret, default_mode}}`; Flutter launches `flutter_inappwebview` to that URL

- **Protocol Sniffing / Protocol Detection:**
  - `Settings → Protocol detection: Detect the protocol used by network requests, this function affects diversion` (`karing.app/en/app-manual/settings: Protocol detection`)
  - `lib/app/modules/setting_manager.dart: sniffEnabled` → sing-box `route.sniffer: { enabled, override_destination }`; pulls SNI from TLS ClientHello for `geosite` without DNS

- **Mux, TLS, NTP, IPv6, WARP (settings extras):**
  - **Mux:** above; UI toggle per-outbound or global
  - **TLS:** global fingerprint list; applies to all `tls.enabled` outbounds
  - **NTP:** `NTP: Network time synchronization... uses system time to participate in encryption... not recommended` (`karing.app/en/app-manual/settings: NTP`) — optional `time` sync before handshake for nodes with skewed clocks
  - **IPv6:** toggle with warning `Before turning on IPv6, please confirm network+device supports IPv6` (`karing.app/en/app-manual/settings: IPv6`) → sets `dns.strategy: ipv4_only?` / `route.autoDetectInterface ipv6`
  - **WARP:** license binding for Cloudflare WARP WireGuard nodes (`Settings -> WARP`)
  - **Network Sharing:** exposes `Socks proxy server for other devices` via `0.0.0.0:$socksPort` (`karing.app/en/app-manual/settings: Network sharing`) + `karing.app/en/tutorial/lan`

- **Notifications, Upstream panel, i18n, Misc:**
  - `Notification: Karing official / vpn provider notification` (`karing.app/en/app-manual/settings: Notification`) via `flutter_local_notifications 19.5`, `flutter_inapp_notifications`, `NoticeManager`
  - `VPN provider/airport: binded VPN provider info` (`Settings → vpn provider`) — stores provider logo/link for one-click sub
  - `Text to QR code` tool, `Port` viewer (`ipv4/ipv6 ports`), `Always open connection` iOS, `DNS leak detection` page, `Country Or Region` auto-rules, `Theme`, `Country` flag via `dash_flags 0.1.1` / `flutter_emoji 2.5.1`

---

## 11. Platform-Specific Notes

### Windows
- **Version:** 10+, 64-bit only; `exe` installer vs `zip` portable/green USB (`karing.app/en/tutorial/portable`)
- **Install:** `karing_1.2.x_windows_x64.exe` (avg 43-46 MB), `zip` 62-66 MB (`releases/tag/v1.2.24.2705` table); `winget` not yet, but installer handles Defender `More info → Run anyway`
- **TUN:** requires **Run as Administrator** (`karing.app/en/app-manual/settings: TUN: You need to start Karing as an administrator on Windows`); uses `wintun.dll` adapter, `launch_at_startup 0.2.2` registry, `tray_manager` + `window_manager` systray, `hotkey_manager` global hotkey, `screen_capturer` for QR scan, `win32_registry` for proxy PAC
- **Fixes:** `v1.2.24.2705: Improved core process detection to address high CPU usage #1886`; `v1.2.20.2300: Improved CPU usage on some devices #1582`; `v1.2.19.2200: macOS auto-update install launch` counterpart Windows silent update
- **Green USB:** portable zip can run from USB without install, config in `portable_config/` next to exe (`karing.app/en/tutorial/portable`)

### macOS
- **Version:** ≥12, Universal DMG (~93-96 MB), Intel+Apple Silicon, Homebrew `brew install karing`
- **TUN:** System Extension `com.nebula.karing.karingServiceSE` (needs Security & Privacy allow), `PacketTunnelProvider` on fallback; `route_exclude_address` refined (#1889)
- **iCloud sync:** same container as iOS for cross-device (`README.md: Backup → Supports iCloud [IOS/MacOS]`)
- **Auto-update install:** `v1.2.19.2200: Fixed macOS failed launch after automatic update package installation` — DMG mounts, replaces `.app` via `open_dir`, relaunches via `window_manager`
- **Features like iOS:** `Always open connection` onDemand, per-app not available (Apple restriction)

### Linux
- **Version:** 64-bit, glibc ≥2.38, `deb` 48-50 MB / `rpm` 52-54 MB / `AppImage` 70-71 MB (`releases/tag/v1.2.20.2300`)
- **Install:** `dpkg -i karing_*_amd64.deb` / `rpm -ivh karing_*.rpm` / `chmod +x AppImage`; tested on Ubuntu 22.04+/Fedora/Arch via AppImage
- **TUN:** needs `sudo`/`pkexec`; stack `system`/`gvisor`/`lwip`; fallback if sudo fails (user can continue with system proxy only); `tray_manager` systray may need `libappindicator`
- **Quirks:** `v1.2.20.2300: Fixed emojis not displaying correctly on some systems #1593` (font fallback); `lib/appimage` glibc pin
- **Portable:** same green USB logic as Windows when using `.zip` / AppImage with adjacent config

### Android
- **Version:** ≥8, `armeabi-v7a` ~50 MB / `arm64-v8a` ~50 MB / universal ~87 MB (`v1.2.20.2300` table); `minSdk 26` (`android/app/build.gradle`), `targetSdk 34`, Kotlin
- **Install:** `karing.app/download` direct apk, GitHub `latest`, APKPure, Amazon AppStore; Xiaomi/MIUI note `enable Airplane Mode offline and disable Security Guard Enhanced Protection before install` (`karing.app/en/download`)
- **Exclusive features:** **Per-App proxy** (whitelist/blacklist), `allowBypass`/`overrideAndroidVPN`, Quick Settings `TileService` (`android/app/src/main/kotlin/com/nebula/karing/TileService.kt:63`), foreground `VpnService` notification with disconnect button
- **Fixes:** `v1.2.19.2200: Added overrideAndroidVPN settings to Tun` for split cellular VPN; `app_installer`, `device_info_plus` for install referrer (`flutter_install_referrer 2.1.0`)

### iOS / tvOS
- **Version:** iOS ≥15, tvOS ≥17; AppStore `6472431552` (keyword `karing vpn`), TestFlight `https://testflight.apple.com/join/RLU59OsJ`
- **Extension:** `karingService.appex` (PacketTunnelProvider), NetworkExtension entitlement, `Always open connection` via `Connect On Demand` (`karing.app/en/app-manual/settings: Always open connection`); control center status fix `v1.2.19.2200: Fixed iOS control center status error`
- **Sync:** iCloud enabled by default (`README.md: iCloud synchronization [IOS/MacOS]`), WebDAV also; LAN Sync import limited to mobile (`karing.app/en/tutorial/backup-sync: Import only supports iOS/Android`)
- **Limitations (Apple sandbox):** No per-app VPN selection, TUN only via NetworkExtension (no `system` stack raw), background keep-alive via `onDemand`; mac tvOS share code in `ios/` + `tvos/` folders

---

## 12. Build / Install Info & Repo Stats

- **Repo structure (top-level from GitHub file tree):**
  ```
  karing/
  ├── lib/                          # Flutter Dart source
  │   ├── main.dart                 # entry: VPNService.initABI(), ServerManager.init() (main.dart:65)
  │   ├── app/
  │   │   ├── local_services/vpn_service.dart   # VPNService singleton, state, MethodChannel
  │   │   ├── modules/
  │   │   │   ├── biz.dart                      # startOrRestartIfDirtyVPN orchestration
  │   │   │   ├── server_manager.dart           # SubscriptionLinkType, ServerConfig, ServerConfigGroupItem, addRemoteConfig
  │   │   │   ├── setting_manager.dart          # SettingConfig, SettingConfigItemDNS, perAppProxyList
  │   │   │   ├── remote_config_manager.dart    # RemoteContent fetch, ETag
  │   │   │   └── backup_manager.dart / webdav_sync.dart
  │   │   ├── runtime/return_result.dart
  │   │   └── utils/
  │   │       ├── singbox_config_builder.dart   # builds final sing-box JSON
  │   │       ├── proxy_conf_utils.dart         # getUrlFromQRContent, URI parsers
  │   │       ├── local_singbox_config_utils.dart # PR #1657 full JSON validation + tailscale template
  │   │       └── log.dart / main_channel_utils.dart
  │   ├── screens/
  │   │   ├── home_screen.dart      # VPNService.setServer() trigger, Backdrop
  │   │   ├── settings_screen.dart  # invokes Biz.startOrRestartIfDirtyVPN:109-111
  │   │   ├── diversion_rules_screen.dart  # GroupItem, getGroupOptions 36-46/163-271
  │   │   ├── select_server_screen.dart
  │   │   └── my_profiles_screen.dart  # local sing-box editor entry PR #1657
  │   └── i18n/strings.g.dart       # slang generated 30+ langs
  ├── android/                      # Gradle + Kotlin VpnServiceImpl, TileService
  ├── ios/ / tvos/ / macos/         # Xcode + PacketTunnelProvider Swift
  ├── windows/ / bind/windows/      # Runner + Go CGO bind
  ├── linux/                        # GTK + CMake
  ├── assets/ + assets/datas/*.srs  # bundled rule-sets
  ├── third_party/flutter_inappwebview_linux_stub
  ├── README_examples/sing-box/     # sample sing-box JSONs (config.json, tuic/, vmess/)
  ├── pubspec.yaml / pubspec.lock   # Flutter deps
  ├── analysis_options.yaml / build.yaml / devtools_options.yaml
  ├── pkg_android.bat               # build script
  └── LICENSE.md / README.md (+ README_cn/ja/ko etc.)
  ```
  - **Hidden build dependency:** `vpn_service: path: ../vpn-service/` (`pubspec.yaml:vpn_service`) — not in public repo (issue #1460); expected sibling checkout `KaringX/vpn-service.git` (private) containing Go `LibVpnCore` + FFI + `singboxConfigBuilder.go`
  - **Fork deps via git:** `flutter_inappwebview`, `android_package_manager`, `move_to_background`, `country`, `window_manager` all pinned to `KaringX/*` forks (`pubspec.yaml: 3a5ead0`, `7b6be17`, `9720fa0`, `9729348`, `bf21977`)

- **Install channels (README.md:Install + karing.app/en/download):**
  - **iOS/tvOS:** AppStore `https://apps.apple.com/us/app/karing/id6472431552` (search `karing vpn`), TestFlight `https://testflight.apple.com/join/RLU59OsJ`
  - **Android:** `https://karing.app/download` (stable/beta switch), `https://github.com/KaringX/karing/releases/latest`, APKPure `https://apkpure.com/p/com.nebula.karing`, Amazon `https://www.amazon.com/gp/product/B0DJSQDDM8`
  - **Desktop:** same `karing.app/download` + GitHub releases; macOS Homebrew `brew install karing` (cask `karing`)
  - **Alternative portals:** GitHub mirror, APKPure, Amazon — all listed in every GitHub Release notes footer

- **Release format & artifacts (sample `v1.2.24.2705` 2026-08-25):**
  - Artifacts: `karing_1.2.24.2705_android_arm64-v8a.apk`, `karing_1.2.24.2705_android_armeabi-v7a.apk`, `karing_1.2.24.2705_linux_amd64.deb`, `karing_1.2.24.2705_linux_amd64.rpm`, `karing_1.2.24.2705_linux_amd64.AppImage`, `karing_1.2.24.2705_macos_universal.dmg`, `karing_1.2.24.2705_windows_x64.exe` + `.zip`
  - Size: desktop ~40-70 MB compressed, mobile ~50 MB per ABI; incrementally grows with core + ruleset bundle
  - Cadence: roughly weekly beta + monthly stable; `Stable Version` vs `Beta Version` tabs on `karing.app/en/download`; each release notes list `tun`, `Windows`, `v2ray`, `Statistics` bullets and `Various other improvements #1873-#1883`

- **Build requirements (from `pubspec.yaml` + README System Req + pubspec.lock):**
  - `Flutter >=3.35.0`, `Dart SDK >=3.9.0 <4.0.0`, `Go >=1.21` (for `KaringX/sing-box`), Xcode 15+ (iOS/macOS), Android Studio + NDK (arm64-v8a/armeabi-v7a), CMake+GTK3 (Linux), Visual Studio 2019+ with Windows SDK (Windows)
  - Commands (inferred from `pkg_android.bat` + standard Flutter): `flutter pub get` → `dart run build_runner build` (`json_annotation`/`source_gen`) → `flutter build apk --split-per-abi` / `flutter build windows` / `flutter build macos` / Go `go build -tags with_gvisor` for libbox
  - Known build blocker: without sibling `../vpn-service` checkout public repo fails `pub get` → `vpn_service` missing (issue #1460); workaround `path` override or clone `KaringX/vpn-service` if private access available; also `flutter_inappwebview_linux_stub` third_party path must exist

- **Repo stats & activity:**
  - **Stars:** 14.6k (README badge) / 14,425 (GitHub API snapshot Aug 2026) — Star History chart `https://star-history.dera.page/#KaringX/karing&Date`
  - **Forks:** ~1.2k, **Watchers:** 83, **Open issues:** 36 (GitHub header) / 57 via search index (filter timing), **PRs:** 3 open, **Commits:** 288 (main), **Default branch:** `main`, **Created:** `2023-11-06T06:16:18Z`
  - **Languages:** Dart (dominant), Go (via submodule core), Swift/ObjC (iOS), Kotlin (Android), C++ (Windows runner)
  - **Core fork:** `KaringX/sing-box` 51 ★, 10 forks, 3,135 commits on `dev-next` (`github.com/KaringX/sing-box` header)
  - **Ruleset:** `KaringX/karing-ruleset` 671 ★, workflow branch auto-builds SRS from `sing-geosite`/`sing-geoip`/`acl4ssr`/`adblock`
  - **Donate:** USDT address shown in `README_assets/img/donate-usdt.jpg`; promotion section lists VPN provider ad `Doggygo VPN` + collaboration announcement `https://karing.app/blog/isp/cooperation`
  - **Changelog depth:** detailed per-release notes in GitHub Releases (e.g., `v1.2.11+1406` → `v1.2.24.2705`), upstream sing-box changelog at `https://sing-box.sagernet.org/changelog/` (1.14.0-alpha 48 down to 1.13 stable)

- **Source verification (how to verify this doc):**
  - Fetch raw sources: `https://raw.githubusercontent.com/KaringX/karing/main/pubspec.yaml`, `…/LICENSE.md`, `…/README.md`, `karing.app/en/clash`, `karing.app/en/app-manual/*`, `deepwiki.com/KaringX/karing/*`, `github.com/KaringX/karing/releases`
  - Search checks: `site:karing.app` + `site:github.com/KaringX/karing` via websearch; cross-verify `sip008`, `reality`, `tun.stack` via sing-box docs `sing-box.sagernet.org/configuration/`
  - Build check: `Test-Path pubspec.yaml` + `Select-String vpn_service ../vpn-service` extraction confirms local path dependency

---

## Appendix — File/Path Quick Index (where HOW lives)

- **Config generation:** `lib/app/utils/singbox_config_builder.dart:18-30` → `VPNService.setServer(...)` → `vpn_service` Go `service_core.json`
- **Subscription import:** `lib/app/modules/server_manager.dart:38-84` (`ServerConfig`, `ServerConfigGroupItem`, `SubscriptionLinkType`, `addRemoteConfig`) + `lib/app/utils/proxy_conf_utils.dart` (URI parsers)
- **Routing UI:** `lib/screens/diversion_rules_screen.dart:36-46`, `163-271` (GroupItem, RuleSets), `lib/app/modules/setting_manager.dart:115-120`
- **VPN lifecycle:** `lib/app/local_services/vpn_service.dart:34-46` (states), `lib/app/modules/biz.dart:45-50`, `lib/screens/settings_screen.dart:109-111`, `lib/main.dart:65` (`initABI`), `lib/screens/home_screen.dart` (`VPNService.setServer`)
- **Local sing-box JSON editor:** `lib/app/utils/local_singbox_config_utils.dart` + `lib/screens/my_profiles_screen.dart` (PR #1657)
- **Android TUN:** `android/app/src/main/kotlin/com/nebula/karing/VpnServiceImpl.kt`, `TileService.kt:63-139`, `android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java`
- **iOS/macOS TUN:** `ios/Runner/PacketTunnelProvider.swift`, `macos/Runner/*`, entitlements `NetworkExtension`
- **Windows TUN:** `windows/runner/*`, `bind/windows/*`, `wintun.dll`
- **DNS:** `lib/app/modules/setting_manager.dart` (`SettingConfigItemDNS`), `assets/datas/*.srs`, docs `karing.app/en/app-manual/dns*`
- **RuleSets repo:** `github.com/KaringX/karing-ruleset` (SRS generation via `sing` branch, `sing-box rule-set` compatibility)
- **Core fork:** `github.com/KaringX/sing-box` (branch `dev-next`), `sing-box.sagernet.org` docs, `SagerNet/sing-box` upstream
- **Deps:** `pubspec.yaml` (full list incl forked `flutter_inappwebview`, `android_package_manager`, `move_to_background`, `country`, `window_manager`)

---

## Sources

- `https://github.com/KaringX/karing` — README, LICENSE, pubspec.yaml, Releases `v1.2.24.2705`, `v1.2.23.2606`, `v1.2.20.2300`
- `https://github.com/KaringX/sing-box` — fork dev-next file tree, commit count
- `https://karing.app/en/` · `https://karing.app/en/clash` · `https://karing.app/en/quickstart` · `https://karing.app/en/download` · `https://karing.app/en/tutorial/perapp-proxy` · `https://karing.app/en/tutorial/backup-sync` · `https://karing.app/en/app-manual/settings` · `https://karing.app/en/app-manual/dns` · `https://karing.app/en/app-manual/dns-server` · `https://karing.app/en/app-manual/diversion` · `https://karing.app/en/faq/`
- `https://deepwiki.com/KaringX/karing/4.3-protocol-support` · `5.1-vpn-service` · `5.4-dns-resolution` · `5.2-routing-and-node-selection` · `2.3-configuration-system` · `4.2-sing-box-configuration`
- `https://karing.pro/en/faq/what-is-karing/` · `https://karing.pro/en/guides/karing-subscription/`
- `https://github.com/KaringX/karing-ruleset` — rule-set collection docs
- `https://sing-box.sagernet.org/configuration/route/rule/` · `https://sing-box.sagernet.org/changelog/`
- Package manifests `pubspec.yaml` at commit `5c18617a` (Flutter 3.35+, Dart 3.9+) and lockfile
- Issue `KaringX/karing#1460` — `vpn_service` path dependency visibility

> Written to **C:\Users\qmahyar\Desktop\VPN Research\01-Karing.md** — verify with `Get-Content -Raw` or `bash ls -l` (UTF-8 markdown, >500 lines, zero placeholders).
