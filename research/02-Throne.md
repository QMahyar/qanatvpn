# 02 — Throne (throneproj/Throne) — Extreme-Detail Research

> **Qt + sing-box Desktop GUI proxy utility — successor to Nekoray. Formerly `Matsuri`/`Nekoray`. Licensed GPL-3.0. Cross-platform (Windows / macOS / Linux).**

* **Repo:** `https://github.com/throneproj/Throne` — org `throneproj`, created `2024-02-07T20:43:12Z`
* **Homepage / Docs:** `https://throneproj.github.io` (EN/FA/RU/ZH) — sitemap: `/get_started/installation`, `/get_started/configuration`, `/advanced/windows_tun_mode`, `/advanced/deeplinks`, `/downloads`
* **Default branch:** `dev` (production releases cut from `dev` via `github-actions[bot]`)
* **License:** `GPL-3.0` (`LICENSE` at repo root, SPDX `GPL-3.0`, `gpl-3.0-or-later` in AUR)
* **Stars / Forks / Watchers:** `6933` / `394` / `51` (as of `2026-08-29`, GitHub API)
* **Commits:** `2055` on `dev` — **Releases:** `75` — **Open issues:** `~28-37` — **Open PRs:** `9`
* **Languages:** `C++ 75.9%`, `Go 18.2%`, `CSS 3.2%`, `CMake 1.6%`, `NSIS 0.6%`, `Shell 0.5%`, `C`, `HTML`
* **Latest stable:** `1.2.4` (`2026-08-08T23:08:42Z`) — prior `1.2.3` (`2026-08-07`), `1.2.0` (`2026-07-22`), `1.1.5` (`2026-06-06`), `1.1.0` (`2026-03-07`, SQLite migration)
* **Tagline:** *Desktop GUI proxy utility. Powerful, Open-Source, Cross-Platform.*

---

## 1. Overview

- **What Throne is**
  - Qt-based desktop GUI that **generates, manages, and runs `sing-box` configs** — not a VPN provider, a **bring-your-own-server** proxy manager (like Clash Verge / NekoBox / Hiddify).
  - HOW: User imports subscriptions / manual profiles → GUI stores in SQLite (`~/.config/Throne` or `%APPDATA%\Throne` + `config/cache.db`) → on Start, `src/configs/generate.h/.cpp` builds a full `sing-box` JSON (inbounds/outbounds/route/dns/experimental) → IPC to `ThroneCore` (Go) which runs `sing-box` + optional `Xray-core`.
  - Empowered by `sing-box` — Throne is the **GUI + lifecycle + routing + subscription engine**; `sing-box` is the **data plane** (inbounds, outbounds, TUN, DNS, router).
  - Successor narrative: Nekoray (by `MatsuriDayo`) archived after Dec 2023 partial abandonment → Throne forked with "lots of improvements, tons of new features, removal of obsolete features and simplifications" (README FAQ).

- **License & Governance**
  - `GPL-3.0` (`LICENSE` file, `GPL-3.0-or-later` on AUR `throne`/`throne-git`).
  - HOW docs replicate license: AUR `Conflicts: nekoray-git, throne` / `Provides: throne` — drop-in replacement.
  - Org `throneproj` (220557208) — maintainers `Mahdi-zarei`, `parhelia512`, `arm64v8a`, `0-Kutya-0`, `CodeFreer`, etc. Sponsor via `github.com/sponsors/Mahdi-zarei` (1.2.0 release notes).

- **Cross-platform Qt6**
  - **CMake** root `CMakeLists.txt:3` — `cmake_minimum_required(VERSION 3.20)`, `project(Throne VERSION 0.1)`, `CMAKE_CXX_STANDARD 20`, `MSVC` `/OPT:REF /OPT:ICF` dead-code stripping, non-MSVC `-ffunction-sections -fdata-sections` + `-Wl,--gc-sections` (Linux) / `-Wl,-dead_strip` (macOS).
  - **Qt6** `find_package(Qt6 REQUIRED COMPONENTS Widgets Network LinguistTools DBus)` (`CMakeLists.txt:30-35`) — Widgets (main window), Network (subscriptions, speedtest), LinguistTools (i18n: EN/FA/RU/ZH), DBus (Linux).
  - **Sources enumeration** `CMakeLists.txt:48+` — `src/main.cpp`, `src/global/Configs.cpp`, `src/global/Utils.cpp`, `src/global/Logger.cpp`, `src/global/PeriodicRunner.cpp`, `src/global/HTTPRequestHelper.cpp`, `src/global/DeviceDetailsHelper.cpp`, `3rdparty/qrcodegen.cpp`, `3rdparty/quirc/*`, `3rdparty/SQLiteCpp/src/*`, `src/api/RPC.cpp`, `src/stats/traffic/*`, `src/configs/sub/*`, `src/sys/Process.cpp`, `src/ui/mainWindow/mainwindow_*.cpp`, `src/ui/widget/*`.
  - **Platform shims:** `cmake/macos/macos.cmake`, `cmake/windows/windows.cmake`, `cmake/linux/linux.cmake` — plus `cmake/nkr.cmake`, `cmake/QHotkey.cmake`, `cmake/print.cmake`, `cmake/myproto.cmake`.
  - **Entry:** `src/main.cpp` → `MainWindow` (`include/ui/mainwindow.h` + `include/ui/mainWindow/MainWindowInternal.h`) with setup split: `mainwindow_setup.cpp`, `mainwindow_events.cpp`, `mainwindow_groups.cpp`, `mainwindow_view.cpp`, `mainwindow_connections.cpp`, `mainwindow_profiles.cpp`, `mainwindow_deeplink.cpp`, `mainwindow_system.cpp`, `mainwindow_log.cpp`, `mainwindow_hotkeys.cpp`, `mainwindow_profile_lifecycle.cpp`, `mainwindow_autoselector.cpp`.

- **Sing-box empowered — architecture at a glance**
  - **GUI (C++/Qt)** owns: profile DB, subscriptions, routing editor, TUN/system-proxy toggles, hotkeys, tray, updater, IPC client.
  - **Core (Go)** owns: actual `sing-box` + `Xray-core` runtime, TUN device, DNS, connections.
  - **IPC boundary:** GUI spawns `ThroneCore` (same dir, enforced — Security enhancement 1.1.3: *core strictly required to be in same directory as GUI, core may only be started by GUI, communicates via unix socket / named pipes*), env `THRONE_CORE_SOCKET`, `THRONE_CORE_DEBUG`, parent PID check.
    - HOW: `core/server/main.go:RunCore()` reads `THRONE_CORE_SOCKET` → `parentcheck.CheckParentProcess()` + `parentcheck.ParentPID` → loop 10× `ipc.ConnectIPC(socketName, parentPID)` 500ms → `runDispatch(conn)` → gRPC-style dispatch over net.Conn.
    - Parent liveness: Windows `parent.Wait()` → fatal; Unix `parent.Signal(0)` poll every 10s → fatal.
    - Memory watchdog: `liveHeap()` via `runtime/metrics "/gc/heap/live:bytes"` → `memoryPanicThreshold=1536 MiB` under `memoryLimit=2 GiB` → `runtimeDebug.FreeOSMemory()` + 30s backoff → heap pprof to temp file → `panic()` with exit code 2 (GUI distinguishes panic vs clean stop).
    - Version banner on start: `sing-box: <C.Version>` + `Xray-core: <core.Version()>`.

---

## 2. Supported Protocols (24 listed in README)

> Implementation: Each protocol maps to a `sing-box` outbound `type` (or Xray outbound when using Extra Core). GUI editor (`src/ui/profile/*`, `src/ui/mainWindow/mainwindow_profiles.cpp`) collects per-protocol fields → `src/configs/generate.cpp` emits JSON → `core/server/*` starts it. Empty `|` = Xray/Reality variants handled via `security` field.

- **SOCKS (4/5)**
  - HOW: sing-box `type: socks` — `server`, `server_port`, `username`, `password`, `version`. Used both as **outbound** and as **bridge for Xray core** (`127.0.0.1:55713` SOCKS inbound stitched in issue #1477 log).
  - Implementation: `core/server/dispatch.go` + `core/server/egress.go` — creates sing-box outbound; if Xray mode, adds `socks` bridge outbound tagged `config-1`.

- **HTTP(S)**
  - HOW: `type: http` — `server`, `server_port`, `username`, `password`, `tls` optional, `path` for CONNECT. Also used for **System Proxy mode** upstream.

- **Shadowsocks (SS / SS-2022)**
  - HOW: `type: shadowsocks` — `method` (`aes-128-gcm`, `aes-256-gcm`, `chacha20-ietf-poly1305`, `2022-blake3-*`), `password`, `plugin` / `plugin_opts` (v2ray-plugin / obfs). SS-2022 adds `server_key`.
  - Group updater: `src/configs/sub/clash.cpp` parses `ss://` (v2rayN + SIP002).

- **Trojan**
  - HOW: `type: trojan` — `password`, `tls` (SNI, ALPN, utls fingerprint, reality/e​ch), `multiplex`, `transport` (ws/grpc/h2).

- **VMess**
  - HOW: `type: vmess` — `uuid`, `alterId` (legacy), `security` (`aes-128-gcm`/`chacha20-poly1305`/`auto`), `global_padding` / XHTTP options (thanks `Yulinanami` 1.1.3 `XHTTP Xpadding options`).

- **VLESS (sing-box)**
  - HOW: `type: vless` — `uuid`, `flow` (`xtls-rprx-vision` / `""`), `tls` + `reality`, `packet_encoding` (xudp), `transport` (tcp/ws/grpc/quic/httpupgrade).
  - Reality: `tls.reality.enabled`, `public_key`, `short_id`, `server_name`, `handshake.server`/`server_port`. Throne uses **Xray for reality by default** since ~1.2.0 (release note: *Use Xray for reality by default*).

- **TUIC (v5)**
  - HOW: `type: tuic` — `uuid`, `password`, `congestion_control` (`cubic`/`bbr`), `udp_relay_mode` (`native`/`quic`), `zero_rtt_handshake`, `heartbeat`.

- **Hysteria (1)**
  - HOW: `type: hysteria` — UDP, `up_mbps`/`down_mbps`, `obfs`, `auth`, `recv_window_conn`/`recv_window`, `disable_mtu_discovery`.

- **Hysteria2 (hy2)**
  - HOW: `type: hysteria2` — `password` (or `obfs` + `obfs.password`), `tls` (SNI, insecure, ech), `brutal_debug`, `up_mbps`/`down_mbps`. Release note #1353 discussion: hy2 replaces hysteria for high-throughput QUIC; Hiddify docs list `hy2 @ 443/udp`.

- **AnyTLS**
  - HOW: `type: anytls` — sing-anytls `v0.0.11` (go.mod `github.com/anytls/sing-anytls`). Password-auth TLS proxy that pads record sizes to defeat TLS-in-TLS detection. Needs TLS cert + SNI (`server_name`). Issue #1462 confirms `AnyTLS-Reality` combo now supported (`anytls` inbound with `tls.reality.enabled` + `private_key`/`short_id`).
  - UI: `src/ui/profile/*` AnyTLS dialog — fields `password`, `idle_session_check_interval`, `min_idle_session`. Added in CA `2025-2026` wave.

- **Mieru**
  - HOW: `type: mieru` — `github.com/enfein/mieru/v3 v3.33.0` (go.mod). Multiplexed proxy — added `Mieru protocol support` in 1.2.x dev (release note: *Add Mieru protocol support*). Niche obfuscation, TCP.

- **Snell**
  - HOW: `type: snell` — proprietary Surge outbound — `psk`, `version` (1-4), `obfs` (`http`/`tls`).

- **NaïveProxy**
  - HOW: `type: naive` — Chromium-network-based `naiveproxy` (`method` via `Chrome` network stack / `quic`). Resists censor by looking like real Chrome traffic.

- **Juicity**
  - HOW: `type: juicity` — via `github.com/exclavenetwork/sing-juicity v0.3.0-beta.1` (go.mod). QUIC-based, `uuid`, `password`, `congestion_control`, `sni`.

- **TrustTunnel**
  - HOW: `type: ???` — sing-box `trusttunnel` (experimental). Listed in README but still niche; Forum `MoaV Docs` lists `4443/tcp+udp` `Very High` stealth.

- **ShadowTLS (v3)**
  - HOW: `type: shadowtls` — TLS handshake forwarding + inner `shadowsocks`; version 3 (`shadowtls` version 3). Concept sibling to Reality — forwards ClientHello to real dest, steganographic inner.

- **WireGuard (vanilla)**
  - HOW: `type: wireguard` — `private_key`, `peers { public_key, allowed_ips, endpoint, preshared_key }`, `local_address` (`172.16.0.2/32`, `fd...::/128`), `mtu 1280`, `persistent_keepalive`. Underlying `github.com/throneproj/wireguard-go v0.0.0-20260826184406-6afb6c3abbbf` (fork replace in go.mod).
  - WARP-specific: `engage.cloudflareclient.com:2408` peer, `0.0.0.0/0`, `::/0` allowed_ips, Warp gen/chain support added 1.1.0 (*Add warp gen/chain support*).

- **AmneziaWG (AWG)**
  - HOW: `type: amneziawg` (custom sing-box fork — not upstream sing-box). Fork `github.com/throneproj/sing-box v1.11.16-0.20260826185710-...` + `wireguard-go` fork. Parameters: `Jc`, `Jmin`, `Jmax` (junk packets), `S1`, `S2`, `H1`-`H4` (magic header randomization), `Junk` padding — matches amneziawg-go `H1-H5` ranges.
  - History: **Removed** in 1.1.0 (*Removed Amenzia wireguard support due to poor docs*), **re-added 1.1.5** (*Added Amenzia Wireguard support again — v2 schematics*), **Amnezia v3** in 1.2.x latest (`Update sing-box 1`, `Add Amnezia v3 support`). Issue #1353 tracks AWG 2.0 (`Jc/Jmin/Jmax` ranges, `S1/S2/H1-H4`) + PR `v14d4n/throne-sing-box-awg` leveraging `hoaxisr/amnezia-box`.
  - Config file: same as WG but GUI adds AWG panel with `Jc/Jmin/Jmax`, `S1/S2`, `H1-H4` + junk params. Routeprofile issue: *routing rules aren't loading when using only awg profiles* → `cache.db` too small unless at least one non-AWG profile updates rulesets first.

- **SSH**
  - HOW: `type: ssh` — `user`, `password` / `private_key` / `private_key_path`, `host_key`, `client_version`. Tunnel via SSH.

- **Xray VLESS (Extra Core path)**
  - HOW: Not sing-box `vless` but **Xray outbound** `protocol: vless` (`core/server/gen` + `server_interface.go`). Used when `Settings → Import → Use Xray for VLESS` or `VLESS (Xray)` profile type or Reality+Vision/XHTTP that sing-box path handles via Xray branch. Transport mapping: `tcp/http upgrade` → `XHTTP`, `xtls-rprx-vision` flow, `reality`.
  - Note `1.1.0` README: *Xray core is now supported for VLESS configs. Note that not all Transports are supported and that you cannot switch between the Cores. You can however, customize when Xray core is used*.

- **Custom Outbound (Both sing-box and Xray)**
  - HOW: GUI `Add Custom Outbound` → raw JSON editor (`src/ui/widget/json/JsonTree.h`, `JsonCodeEdit.h`, `JsonValidator.h`, `JsonSchemaValidator.cpp`, `SchemaStore.cpp/.h`) with schema validation. Stored as `custom-outbound` profile `type` with `outbound_json`. On generate, injected verbatim as sing-box outbound or Xray outbound depending on selector.
  - Chaining: `Custom Outbound` can be chained (see Chaining).

- **Custom Config (Both sing-box and Xray)**
  - HOW: Full config JSON/YAML override (`custom-config`) — bypasses generator. Used for advanced users; file path via `vpnFileImport.hpp/.cpp` (`src/configs/sub/vpnFileImport.cpp`).

- **Chaining outbounds (Hop chain)**
  - HOW: `Dialer` chain — `outbound.detour` / `dialer_proxy` in sing-box. GUI `Profile → Chain` → pick next hop profile as detour. Added `1.1.3`: *Add chain support for Xray*, *Allow chaining Extra core profiles (only as last hop)*, *Allow chaining custom outbound/custom Xray outbound/custom Xray configs*. `core/server/egress.go` builds outbound selectors with `detour` field.
  - Use: fronting (e.g., `Shadowsocks → VLESS-Reality`, `Warp chain` as egress), provider warp-bypass trick: `warp-bypass` default route (1.2.0).

- **Extra Core (Generic)**
  - HOW: Run arbitrary extra executable as outbound (Xray or other). `src/configs/sub/vpnFileImport.*` + `core/server/server_autoselector.go`. `Extra Core` appears as profile type — started as unprivileged child of ThroneCore (security 1.1.3: *Extra cores as unprivileged processes*). Routing: *Route extra/xray core dns to direct* to avoid loopback.

---

## 3. Cores

- **Primary: SagerNet sing-box (throneproj fork)**
  - **What:** `github.com/sagernet/sing-box` — universal proxy platform (inbounds: tun/mixed/socks/http/direct; outbounds: all protocols; route/dns/experimental).
  - **Throne fork:** `github.com/throneproj/sing-box v1.11.16-0.20260826185710-447f3527e6c6` (go.mod replace line) + `go 1.26`, but binary reports `sing-box: v1.13.20-0.20260823144715-a1619d0e396e` (see `core/server/main.go: fmt.Println("sing-box:", C.Version)`). Upstream progression in releases: `1.13.2` (1.1.0), `1.13.12` (1.1.3), `1.13.13` (1.1.5), `1.13.14` (1.2.0-beta.3), `1.13.20` (1.2.4 dev).
  - **Deps in go.mod:** `sing v0.9.0-beta.4`, `sing-tun v0.9.0-beta.2`, `sing-anytls v0.0.11`, `mieru/v3 v3.33.0`, `sing-juicity`, `utls`, `quic-go`, `wireguard-go` fork, etc. Full list 80+ indirect deps visible above.
  - **Build tag:** gVisor enabled by default — `mixed` default stack when gVisor tag present else `system` (sing-box inbound docs: *Defaults to the `mixed` stack if the gVisor build tag is enabled*).

- **Optional: Xray-core (XTLS)**
  - **What:** `github.com/xtls/xray-core` — VLESS/VMess/Trojan/Shadowsocks with Reality/Vision/XHTTP/FinalMask.
  - **Throne fork/pin:** `github.com/throneproj/xray-core v1.251015.1-0.20260808214837-735fffaa66af` replace for `github.com/xtls/xray-core v1.260327.1` (go.mod). Binary prints `Xray-core: <core.Version()>` on start.
  - **When used:**
    - Explicit `VLESS (Xray)` profile type,
    - `Settings → Use Xray for Reality by default` (1.2.0-beta note: *Use Xray for reality by default and allow importing all VLESS in Xray*),
    - `XHTTP`, `Vision`, `FinalMask`, `reverse-reality` that Throne delegates to Xray,
    - `Custom Xray Outbound / Custom Xray Config`.
  - **How bridged:** Xray runs as **separate process** `ThroneCore` child (`core/server/dispatch.go`, `server_interface.go` + `internal/boxmain`). Sing-box creates a `socks` outbound bridging to Xray's SOCKS inbound (`127.0.0.1:55713` in #1477 log). Sing-box TUN `find_process` rule routes `ThroneCore.exe` → `direct` to break loop; fallback deterministic `ip_cidr → direct` for server destination recommended (see #1477 fix suggestion).
  - **Security pinning:** 1.1.3 *Route extra/xray core dns to direct dns to avoid loopback* — DNS rule `process_path: ThroneCore.exe → dns-direct` + `domain: pl-mirror... → dns-direct` (log snippet).

- **Matsuri / sing-box-extra lineage**
  - Historical `Matsuri`/`NekoBox`/`nekoray` extra binaries bundled `sing-box-extra` (SagerNet forks with extra protocols). Throne inherits this pattern: **built-in sing-box fork already includes AnyTLS/Mieru/Juicity/Hysteria/TUIC etc.** — no separate `sing-box-extra` binary needed since 1.1.x. The `Extra Core` slot is for Xray (and user-provided cores) rather than a second sing-box.
  - **File layout (release zip):**
    - `Throne.exe` (GUI, Qt) + `ThroneCore.exe` (Go, must be same dir — security check)
    - `updater.exe` / `updater` (privileged updater, copied to `updater.old` on Windows),
    - `res/` (icons, themes, geo assets placeholder),
    - `config/` (SQLite `cache.db`, `profiles`, routeprofiles cache),
    - Optional `ThroneCore` setuid-root on Linux/macOS via privilege escalation (Terminal prompt on macOS, `SUID` / `cap_*` on Linux).

- **Version matrix (release notes):**
  - `1.1.0`: `Qt 6.11.1`, `Go 1.25.9`, `sing-box 1.13.12`, `Xray 26.3.27` → `1.1.5`: `sing-box 1.13.13`, `1.2.0-beta.3`: `sing-box 1.13.14`, `1.2.4 dev`: `sing-box 1.13.20`, `Xray 1.260327.x`. Language `C++20`.

---

## 4. Split Tunneling / Routing

- **Routing profiles (concepts)**
  - HOW: GUI `Routes → Routing Settings → Routes` — list of named profiles (radio). `Routes → Download Config Profile` fetches remote **routeprofiles** from `github.com/throneproj/routeprofiles` (repo of `rule-set/srslist.h` curated via `curl -fLso srslist.h https://raw.githubusercontent.com/throneproj/routeprofiles/rule-set/srslist.h` during build). Profiles are sing-box `route.rules[]` + `rule_set[]` + `dns.rules[]`.
  - Storage: SQLite `route_profiles` table (`src/database`, `include/database`, `3rdparty/SQLiteCpp`), auto-update interval `12h0m0s` (PeriodicRunner `src/global/PeriodicRunner.cpp`, `RouteUpdater` `include/configs/sub/RouteUpdater.hpp` + `src/configs/sub/RouteUpdater.cpp`).
  - Local vs remote vs raw: since 1.2.0 supports *remote, block, warp-bypass, Raw routing profile* — raw = user-pasted `route` section with `raw: true` envelope.

- **Rule primitives (sing-box route)**
  - Downloadables include: `Bypass China` + `Bypass China Blocked`, `Bypass LAN`, `Bypass Private`, `Block Ads` (via `route_exclude_address_set`/`rule_set`). Example log route: `final: proxy`, `auto_detect_interface: true`, `default_domain_resolver: dns-direct`, `rules: sniff, hijack-dns, reject dns-in, process_path→direct, sniff mixed-in/tun-in, resolve ipv4_only, hijack-dns, domain_suffix→direct (twitch.tv, ya.ru, ozon.ru, yandex.*, etc)`.
  - Fields per rule: `domain`, `domain_suffix`, `domain_keyword`, `domain_regex`, `rule_set`, `ip_cidr`, `ip_is_private`, `port`, `protocol`, `process_path`, `process_name`, `package_name` (Android), inbound tag, outbound tag. Action `route` / `sniff` / `resolve` / `hijack-dns` / `reject`.
  - Config doc recommended steps: *Routes → Download Config Profile → Select `Bypass China` + `Bypass China Blocked` → Delete default rules, keep only downloaded two* (get_started/configuration).

- **Bypass / per-app (Windows / Linux)**
  - **Windows per-app:** `include_interface`/`exclude_interface`, `process_path`/`process_name` rules via `route.find_process: true` (see #1477 JSON `"find_process":true`). GUI exposes `Per-App` toggle in VPN settings? Implementation: `src/ui/setting/dialog_vpn_settings.*` + `src/sys/ProcessMetrics.cpp`.
  - **Linux per-app:** `include_uid`/`exclude_uid`/`include_uid_range`/`exclude_uid_range`, `include_package`/`exclude_package` (Android). On Linux `auto_redirect` (nftables) vs `tun` path.
  - **ICMP Network:** 1.1.3 *Add ICMP network to routing profile* — allow `network: icmp` in rules (ping through TUN).
  - **Simple Rules:** GUI *Make simple rules index adjustable* (1.1.0) — reorders `route.rules[]`.

- **TUN stack options (sing-box `tun.stack`) — see §5 for deep dive but routing-relevant:**
  - `route_address` (`0.0.0.0/1`, `128.0.0.0/1`, `::/1`, `8000::/1`), `route_exclude_address` (`192.168.0.0/16`, `fc00::/7`, `127.0.0.0/8`), `route_address_set` (`geoip-cloudflare`), `route_exclude_address_set` (`geoip-cn`, `ff00::/8`). Tun `Docs` fields: `auto_route`, `strict_route`, `endpoint_independent_nat`, `include_interface`, `exclude_uid`, etc. (sing-box tun docs list 30+ knobs).
  - `strict_route` **disabled by default since 1.2.0** (release note *Disable strict route by default — strict route causes issues on certain windows environments*), re-enabled on Windows in 1.2.1 with warning (*Re-Enable strict route on windows again, with warnings on faulty systems*).

- **Auto-selector / Load-balance**
  - **1.2.3** *Add Auto-selector*: GUI create profile group of type `Auto Selector` that probes a selector list and picks best via `urltest` — essentially sing-box `selector`/`urltest` outbound. Manifests as `server_autoselector.go` (`core/server/server_autoselector.go`) generating `selector` outbound + `urltest` interval.

- **Deeplink routing (§8 deep links correlate):**
  - `throne://route/<base64>` carries `{"kind":"throne-route-profile","v":1,"name":"...","default_outbound":"proxy","rules":[]}` or `{"raw":true,"route":{...}}` — imported via `Routes → Routing Settings → Ctrl+V` or `throne://` scheme handler (`src/sys/UrlScheme.cpp/.hpp`, `src/ui/mainWindow/mainwindow_deeplink.cpp`).
  - `throne://remoteroute/<base64>` carries newline `https://...#Name` list — *remote* profiles auto-updated every `Routing profiles auto update` interval (≥30 min else off). Bulk import via browser click / drag-drop / CLI arg.

---

## 5. TUN vs System Proxy

| Mode | How it works | Stack | When to use | Caveats |
|------|--------------|-------|-------------|---------|
| **System Proxy** | Sets OS proxy settings (Windows `WinCommander.cpp` + `QvProxyConfigurator`, macOS `sys/macos/MacOS.*`, Linux `QvProxyConfigurator`). Browsers/apps that respect system proxy go through `mixed-in` (127.0.0.1:2080). Other apps bypass. | N/A (mixed inbound) | Light browsing, needs no admin | Must **Exit cleanly** — force quit leaves proxy set (FAQ: *re-open Throne → enable System proxy → disable to reset*). Cannot coexist with TUN. |
| **TUN Mode** | Creates virtual NIC `throne-tun` (`172.19.0.1/24` or `172.19.0.1/30` + IPv6 ULA) at L3 — all sockets captured. Implements via sing-box `tun` inbound with `auto_route: true`. | `gvisor` / `system` / `mixed` (user-select in `Settings → TUN Settings → Stack`) | Global proxy — games, non-proxy-aware apps | Needs **root/admin** — SUID or `cap_net_admin` (Linux) / elevated Terminal `chown root` (macOS) / `Run as administrator` (Windows). Exclusive with System Proxy. |

- **TUN implementation — sing-box `tun` inbound JSON (example from #1477 & sing-box docs):**
  - ```json
    {
      "type": "tun",
      "tag": "tun-in",
      "interface_name": "throne-tun",
      "address": ["172.19.0.1/24"],
      "mtu": 1500,
      "auto_route": true,
      "strict_route": true,
      "stack": "system",
      "route_exclude_address": ["127.0.0.0/8"],
      "auto_redirect": true,
      "endpoint_independent_nat": false
    }
    ```
  - PLUS `inbounds`: `mixed-in` (`127.0.0.1:2080` `type: mixed`) + `dns-in` (`127.0.0.1:5533` `type: direct`) — TUN hijacks DNS to `dns-in`.

- **Stack taxonomy (sing-box docs `configuration/inbound/tun`):**
  - `system` — **L3→L4 via OS network stack** — uses OS IP stack to translate TUN IP packets to TCP/UDP sockets (Windows `Wintun`/`WinTun` driver, Linux `tun` device + `netlink`/`nftables`).
    - PRO: native performance, low overhead, leverages OS TCP.
    - CON: on Windows 25H2 + Avast/AV, silently fails (*no traffic forwarded, no error* — issue #1687 root cause was Avast network shield). On Linux with `route_exclude_address` + `auto_redirect`, `nftables: create address sets: file exists` (`sing-box #4316`).
  - `gvisor` — **userspace TCP/IP via `gvisor.dev/gvisor`** — `stack.LinkEndpoint` ↔ `gvisor` `stack.Stack` with `ipv4.NewProtocol`, `ipv6.NewProtocol`, `tcp.NewProtocol`, `udp.NewProtocol`, `SetSpoofing(true)`, `SetPromiscuousMode(true)`, `SetRouteTable(0.0.0.0/0, ::/0)`.
    - PRO: most reliable cross-platform, works when AV blocks `system` (issue #1687: *only gvisor works* on Ubuntu 26.04/Arch/cachyOS + Windows 11 Pro gvisor→works, system/mixed→silent fail). Avoids OS quirks.
    - CON: higher CPU, slightly higher latency, longer `Stop` teardown (`interface to go down when gvisor set` — report 1.2.0).
  - `mixed` — **TCP via `system`, UDP via `gvisor`** — default when gVisor build tag enabled. Hybrid: TCP performance of system + UDP Full-Cone NAT correctness of gVisor's custom `UDPHandler` (gVisor UDP forwarder bypassed for raw `IP+UDP` packets with checksums — needed for Full-Cone NAT per Xray internals doc).
    - Fallback: If `system` broken, `mixed` inherits same failure (issue #1687: *system and mixed modes don't work, only gVisor works*).

- **Advanced Windows TUN — DNS leak mitigation (`/advanced/windows_tun_mode`):**
  - **1. Disable Smart Multi-Homed Name Resolution** — `reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" /v DisableSmartNameResolution /t REG_DWORD /d 1 /f` via elevated CMD + reboot (Group Policy `Computer Configuration → Administrative Templates → Network → DNS Client`). Prevents Windows racing DNS across all NICs bypassing `throne-tun`.
  - **2. Disable QUIC in browser** — `chrome://flags` → `QUIC` → `Disabled` — stops browser DoQ/QUIC bypassing TUN DNS.

- **Auto-route / Strict / Redirect / Exclude knobs:**
  - `auto_route: true` — sing-box installs routes (`0.0.0.0/1` + `128.0.0.0/1` split default) pointing to `throne-tun`.
  - `strict_route: true` — forces even `route_exclude_address` via TUN then policy-routes back; disabled by default (1.2.0) due to Windows faults, re-enabled 1.2.1 with warning. Test matrix: #1687 — `Disable Private Range Bypass` + `auto_redirect` combos vary per distro.
  - `auto_redirect: true` — Linux `nftables`/`iptables` `NFQUEUE` path (`auto_redirect_input_mark 0x2023` etc.) — regression in sing-box 1.13.14 (#4316) → need sing-box 1.14 + Throne `Disable private range Bypass` toggle.
  - `route_exclude_address`: GUI exposes *Disable Private Range bypass* in TUN settings — toggles `192.168.0.0/16`, `10.0.0.0/8`, `172.16.0.0/12`, `fc00::/7`, `ff00::/8`. When excluded + `auto_redirect` ON → `netlink receive: file exists` (“create ipv6 route exclude address set: conn.Receive: netlink receive: file exists”) — workaround is ticking *Disable Private Range bypass* or disabling `auto_redirect`.

- **Mode exclusivity & lifecycle:**
  - `Settings → Basic Settings → Security` may disable privilege escalation → TUN disabled unless manual `cap_net_admin`. GUI warns if switching TUN while System Proxy active (get_started/configuration: *Please disable System Proxy when enabling TUN mode; both cannot be enabled simultaneously*). On profile stop, `System proxy` auto-disabled (1.1.3).

- **File paths for TUN/system-proxy logic:**
  - GUI: `src/ui/mainWindow/mainwindow_system.cpp`, `src/ui/mainWindow/mainwindow_profile_lifecycle.cpp`, `src/ui/setting/dialog_vpn_settings.*` (TUN dialog: stack dropdown, MTU, DNS hijack toggle, `auto_route`/`strict_route`/`Disable Private Range Bypass`).
  - Core: `core/server/server_vpnstatus.go` (TUN status), `core/server/internal/boxmain` (sing-box box lifecycle, `post-start inbound/tun[tun-in]` hook).
  - Windows priv: `3rdparty/WinCommander.cpp/.hpp`, `include/sys/windows/WinVersion.h`, `src/sys/ProcessMetrics.cpp`.
  - Linux priv: `include/sys/linux/LinuxCap.h`, `core/server/dashboard_unix.go` vs `dashboard_windows.go`.

---

## 6. Subscription Formats

- **Share links (URI) — paste via `Ctrl+V` on main window**
  - `ss://` (Shadowsocks SIP002 + `2022-blake3` + plain), `ssr://` (legacy, limited), `vmess://` (base64 JSON `v2rayN`), `vless://` (Xray/sing-box `uuid@host:port?security=reality&flow=...&type=ws&path=...#name`), `trojan://`, `trojan-go://`, `tuic://`, `hysteria://` / `hy2://` / `hysteria2://`, `anytls://`, `mieru://`, `wireguard://` / `wg://`, `snell://`, `socks://` / `socks5://`, `http://`/`https://` (http proxy), `ssh://` (rare).
  - HOW: `src/configs/sub/GroupUpdater.cpp` → detect scheme → decode base64 → JSON/url query → emit `Profile` entity → `src/configs/sub/clash.cpp` share-link parser. `deeplink` `throne://add/<base64>` also maps to single profile JSON (no confirmation, added to current group).

- **Raw Clash (YAML)**
  - HOW: Limited Clash YAML (`proxies:`, `proxy-groups:` subset) → `src/configs/sub/clash.cpp` via `fkYAML` (`3rdparty/fkYAML`) — parses `proxies:` array (ss/ssr/vmess/vless/trojan/snall/hysteria/wg) → maps Clash fields → Throne profile structs. Release notes: *limited support for Shadowsocks and Clash formats* (README). Not full Clash rule conversion; inbound names preserved where possible.
  - File: `include/configs/sub/clash.hpp` (if present), `src/configs/sub/clash.cpp` uses `fkYAML` DOM.

- **sing-box outbound JSON (raw JSON representation)**
  - ```json
    {"tag":"my-node","type":"vless","server":"1.2.3.4","server_port":443,"uuid":"...","tls":{"enabled":true,"server_name":"example.com","reality":{...}},"transport":{"type":"ws","path":"/"}}
    ```
  - HOW: `Ctrl+V` raw JSON or `Subscribe URL` returning JSON array / sing-box config `outbounds[]`. GUI `Custom Outbound` uses same JSON. Importer `src/configs/sub/vpnFileImport.cpp` detects `{"outbounds":` vs single outbound vs full sing-box config (`{"inbounds":...,"outbounds":...}`) → if full config → import as `Custom Config`.
  - `deepLink` `throne://add/<base64>` payload is exactly this JSON outbound.

- **v2rayN format (VMess/VLESS share links + subscription)**
  - Subscription URL returns base64-lines TXT (classic `vmess://` + `ss://` list) OR JSON `{"outbounds":[...]}` OR Clash YAML. Headers handled with `X-Subscription-Userinfo` for traffic.
  - HOW update: `GroupUpdater` (`include/configs/sub/GroupUpdater.hpp` — `src/configs/sub/GroupUpdater.cpp`) fetches URL via `HTTPRequestHelper.cpp` (`libcurl`/`QNetworkAccessManager` fallback), respects `Auto update` interval (PeriodicRunner cron), `Update Subscription` `Ctrl+U`, `Refresh List` (right-click group). Cache: SQLite `groups` + `profiles` with `group_id`, `subscription_url`.

- **Subscription management:**
  - `Groups` dialog (`src/ui/group/dialog_manage_groups.*`) → Type `Subscription` → `URL` field (+ `User-Agent` spoof, `auto_update` bool). Right-click group → `Update Subscription` / `Refresh List` / `Clear Profiles`. Deeplink `throne://addsub/<base64>` adds `url#name` group and fetches immediately (confirmation dialog with `Auto update` checkbox default ticked). Standard Base64 with `=` padding required for `addsub`.
  - File import: `throne://remoteroute` never decodes as subscription; subscription decoder is separate.

---

## 7. DPI Bypass

> Throne itself is not the DPI engine — it delegates to `sing-box`/`Xray` protocol obfuscation. Throne exposes the knobs + builds correct transport/TLS JSON. Real obfuscation lives in outbound `tls` + `transport` + `multiplex` + `packet_encoding`.

- **Reality (VLESS + Reality — strongest 2026)**
  - HOW: Borrow real site cert (`dest: www.microsoft.com:443`, `dl.google.com`, `yahoo.com` in #1462 example). Client `reality: { enabled: true, public_key: u4v3..., short_id: ... }`, server `private_key`, `short_id`, `handshake.server`. Throne delegates Reality to **Xray** by default (release note 1.2.0 *Use Xray for reality by default*) because sing-box Reality + Xray Reality parity gaps; fallback is sing-box `tls.reality`.
  - Stealth model (VPNSmith 2026): `SNI inspection` + `JA3/JA4 fingerprint` + `ML packet timing/entropy` + `active probing` — Reality resists all four: presents **real Microsoft/Cloudflare cert**, **real JA3**, inner tunnel padded/fragment per `xtls-rprx-vision` flow. GFW Report field: Reality best survives GFW 4.0 active probing.
  - GUI: profile `Security → Reality` panel — `Public Key`, `Short ID`, `Server Name`, `Fingerprint` (`chrome`/`firefox` via `utls` `github.com/metacubex/utls` / `refraction-networking/utls`), `Spider X` / `ECH`. Added `Add XHTTP Xpadding options` (1.1.3 thanks Yulinanami) + `Add ECH server name` (1.1.3).

- **Custom Fragmentation — Hiddify TLS fragment / TLS Mixed-case (1.2.0)**
  - HOW: `Settings → TLS Fragment` / `TLS Tricks` → sing-box `tls_fragment` + `tls_mixed_case` (Hiddify extensions merged into throneproj/sing-box fork). Splits ClientHello into fragments (`tls_fragment: { enabled: true, size: "10-200", sleep: "2-8" }`) and randomizes SNI case (`tls_mixed_case: true`) to defeat SNI-based DPI. Issue #1477 observed `tls_tricks` stripped for minimal sing-box repro.
  - Transport: `utls` fingerprint `chrome` in example AnyTLS+Reality config (CH fingerprint spoof) + `ech` ECH extension (encrypted ClientHello) — fields `tls.utls.enabled`, `tls.ech`.

- **XHTTP / Vision flow — anti TLS-in-TLS detection**
  - `flow: xtls-rprx-vision` (Xray) splices inner TLS into outer to defeat `TLS-in-TLS` size pattern detection (ML per-flow 40+ features). `XHTTP` (VLESS+XHTTP+Reality port 2096/tcp MoaV Docs `Very High` stealth) is next-gen HTTP upgrade transport — *Extend XHTTP settings support* (1.1.5 thanks Katze-942). Config key `transport.type: xhttp` + `xhttp` options + `padding`.
  - Throne: profile transport dropdown now includes `XHTTP`, `HTTPUpgrade`, `gRPC`, `WS`, `QUIC` (`Annex A` in profile editor). Vision flag in VLESS editor.

- **AnyTLS obfuscation**
  - Record-size varying + padding (`padding_scheme: ["stop=8","0=30-30","1=100-400", ...]` in AnyTLS inbound example) — defeats `TLS-in-TLS` fingerprint distinct from Reality's approach. Client fields `idle_session_check_interval 30s`, `min_idle_session 5`.

- **ShadowTLS / ShadowTLS v3**
  - TLS handshake forwarding (`shadowtls` version 3, `password`, `version: 3`) wraps inner `shadowsocks-2022`. Looks like legitimate TLS to middleboxes — smaller ecosystem, MoaVDocs recommends `Very High` stealth, often paired sing-box+SS inner.

- **AmneziaWG DPI layer (UDP)**
  - `Jc`/`Jmin`/`Jmax` junk packets + `S1`/`S2`/`H1-H4` magic header randomization break WireGuard signature within ~100 packets (GFW Report). MoaV: AWG works Russia/Belarus/soft Iran, not reliably GFW 4.0 China (needs Reality). Throne exposes junk sliders in AWG profile editor; amneziawg-go warns `Jmax >= system MTU → fragmentation` suspicious.

- **NaïveProxy / Mieru / Juicity / Hysteria2 obfuscation**
  - NaïveProxy: real Chrome traffic → most stealth for TSPU (Iran) as primary (MoaV). Mieru: multiplexed TCP niche. Hysteria2: QUIC + `up_mbps` brutal congestion, `obfs` password.

- **SSH tunneling fallback**
  - `type: ssh` as inner-obfuscation (TCP over SSH) — last resort `53/udp` `dnstt/slipstream` not directly in Throne but SSH over 443 can chain.

- **QUIC disable note**
  - For censor TUN, `chrome://flags → QUIC → Disabled` is part of Throne Windows TUN hardening (see §5) — QUIC leaks bypass TUN DNS.

---

## 8. DNS

- **Tun DNS hijack (always-on since 1.2.0-beta.3)**
  - Release note *Make sniff and hijack-dns always on* — sing-box `route.rules: { action: sniff, inbound: dns-in }`, `{ action: hijack-dns, inbound: dns-in, protocol: dns }`, `{ action: reject, inbound: dns-in }` + later `{ action: sniff, inbound: [mixed-in, tun-in] }`, `{ action: resolve, strategy: ipv4_only }`, `{ action: hijack-dns, protocol: dns }`. Hijack intercepts port 53 UDP/TCP and redirects to sing-box DNS subsystem rather than letting OS resolver forward.
  - Inbounds `dns-in` (`127.0.0.1:5533 type: direct`) is dummy sink — hijack rule captures before it reaches `reject`.
  - DNS config (from #1477 dump):
    ```json
    {
      "dns": {
        "servers": [
          { "tag": "dns-remote", "type": "udp", "server": "1.1.1.1", "detour": "proxy", "domain_resolver": "dns-local" },
          { "tag": "dns-direct", "type": "local" },
          { "tag": "dns-local", "type": "local" }
        ],
        "rules": [
          { "action": "predefined", "rcode": "NOERROR", "query_type": "A", "domain": "localhost", "answer": "localhost. IN A 127.0.0.1" },
          { "action": "predefined", "rcode": "NOERROR", "query_type": "AAAA", "domain": "localhost", "answer": "localhost. IN AAAA ::1" },
          { "action": "route", "process_path": ["C:\\...\\ThroneCore.exe"], "server": "dns-direct", "strategy": "ipv4_only" },
          { "action": "route", "domain": ["pl-mirror.api.akenai.click"], "server": "dns-direct", "strategy": "ipv4_only" },
          { "action": "route", "server": "dns-remote", "strategy": "ipv4_only" }
        ]
      },
      "route": { "default_domain_resolver": { "server": "dns-direct", "strategy": "ipv4_only" } }
    }
    ```
  - Logic: Xray/extra-core DNS (`ThroneCore.exe`) forced `dns-direct` (local resolver) to avoid loop — else `dns-remote via proxy → TUN → loop`.

- **DoH / DoT / Default**
  - 1.2.0 *Use Google DoH as default remote DNS* — `dns-remote` default now `https://8.8.8.8/dns-query` or `tls://8.8.8.8` when DoH enabled (profile `DNS → Remote DNS`). User can set `Use Google DoH` toggle; alternative local `223.5.5.5` (AliDNS) example in #1462 config `dns: { servers: [{tag:google,type:tls,server:8.8.8.8},{tag:local,type:udp,server:223.5.5.5}]}`.
  - Strategy options: `ipv4_only` (default), `ipv6_only`, `prefer_ipv4`, `prefer_ipv6`, `ipv4_only` fixes Warp IPv6 complaints (AWG thread: *I enabled IPv6 in Tun mode and set prefer_ipv4 instead of ipv4_only*).
  - ThroneCore experimental: `cache_file { enabled: true, store_fakeip: true, store_rdrc: true }`, `clash_api { default_mode: "" }` (log snippet).

- **System DNS mode**
  - Settings `→ Basic Settings → System DNS` — actually changes OS DNS (Windows `SetDNS via netsh/WinCommander`, Linux `systemd-resolved`/`resolv.conf`, macOS `scutil`). Antivirus false-positive vector (FAQ: *System DNS feature will change your system's DNS settings, dangerous*). `prepare_exit()` in `mainwindow_system.cpp` ensures `set_system_dns(false, false)` on exit; `Remember System DNS` setting persists across restart.

- **TUN DNS address mapping**
  - sing-box `tun` `dns_mode: hijack` + `dns_address: ["172.18.0.2","fdfe:dcba:9876::2"]` (sing-box tun docs) — not exposed directly but baked into generate.

---

## 9. Other Features

- **Group management (Subscriptions + Manual groups)**
  - GUI `Settings → Groups` (`src/ui/group/dialog_manage_groups.*`, `mainwindow_groups.cpp`). Types: `Subscription` (URL fetched) vs `Manual` (hand-added). Fields `name`, `url`, `auto_update`, `user-agent`, `proxy` for group fetch.
  - Paste-to-add: `Ctrl+V` on main window reads clipboard (share link / JSON / Clash / `throne://`) → `GroupUpdater` imports to `Default` group if none selected, else current.
  - Ops: `Update Subscription (Ctrl+U)`, `Refresh List`, `Copy Link`, `Share → Copy links of selected (Deep Links) (Ctrl+Alt+C)`, `Import from file` (multiple file selection since 1.2.3), `Auto clear unavailable profiles` (1.1.0 toggle).
  - Deep links `throne://addsub` / `add` / `route` / `remoteroute` all create groups (`throne://addsub` does; `remoteroute` creates remote route groups, not proxy groups).
  - Storage: SQLite `groups` table, relations `profiles.group_id`. Migrations in `src/database`.

- **Speed test / Latency / Outgoing IP test**
  - `URL Test Selected Items (Ctrl+Shift+S)` (`src/ui/mainWindow/TestRunner.*`, `include/ui/mainWindow/TestRunner.h`) — `urltest` style RTT probe (HTTP GET to `http://www.gstatic.com/generate_204` or `https://cp.cloudflare.com`), parallel goroutines via `core/server` speedtest. Fork `github.com/Mahdi-zarei/speedtest-go v1.7.13-...` (go.mod) for throughput test variant.
  - `Outgoing IP Test` (1.1.0) — shows `profile's outbound IP, country and availability` via `HTTPRequestHelper.cpp` + `CountryHelper.cpp` (`GeoIP lookup` after probe).
  - `Show current speed in connections Tab` (1.2.0-beta.3) + `Show connection speed in connections Tab and allow sorting by it` (1.2.0) — per-connection `rx/tx` bps (`src/stats/traffic/TrafficLooper.cpp`, `TrafficStatsManager.cpp/.hpp`).
  - Connections tab: live TCP/UDP conns with `inbound/outbound`, `process`, `domain`, `speed`, `duration` — sortable.

- **Traffic statistics module (1.2.0)**
  - Aggregated `traffic grouped by config/application, can be disabled in settings` — `src/stats/traffic/*`, `include/stats/traffic/TrafficStatsManager.hpp`. Persists to SQLite, chart widget `3rdparty/qv2ray/.../SpeedWidget.cpp/.hpp` (QChart replacement). Runtime stats widget (1.2.0) shows `memory watchdog` + `goroutines`.

- **Hotkeys (global)**
  - `QHotkey` (`3rdparty/QHotkey`, `cmake/QHotkey.cmake`, `src/ui/mainWindow/mainwindow_hotkeys.cpp`, `src/ui/setting/dialog_hotkey.*`, `3rdparty/QtExtKeySequenceEdit.*`) — global accel for `Start/Stop`, `System Proxy Toggle`, `TUN Toggle`, `Select profile Up/Down`, `URL Test`. Registered via OS `RegisterHotKey` (Win), `CGEventTap` (macOS), `X11` (`QX11Info`) bypass. Hidden menu shortcuts `RegisterHiddenMenuShortcuts()`.

- **QoS / mux / transport tweaks**
  - Profile advanced: `bind_interface`, `inet4_bind_address` / `inet6_bind_address` (`inet_bind_ipv4/6` 1.1.3) to bind to non-default interface (Corporate OpenVPN). `outbound.direct` with `bind_interface` (`1.1.3 Add direct outbound`).
  - `Multiplex (SMUX/YAMUX/H2Mux)` toggles per outbound, `packet_encoding: xudp`, `udp_over_tcp`.

- **Custom assets & Theming**
  - `src/ui/setting/ThemeManager.*` + `Icon.cpp` — themes: default + `Old Nekoray Themes FlatGray, LightBlue, BlackSoft readded` (1.1.5). Handles `mw_size`, `mainWindowGeometry`, `splitter_state` (commit on `on_commitDataRequest()`).
  - App icon in taskbar changed 1.1.0 (`Change app icon in taskbar`).
  - `Custom assets` via `Settings → Assets`? Actually `Preset Settings` (`DialogPresetSettings`) allows overriding `geoip.dat`/`geosite.dat`/`srs` — Throne downloads `routeprofiles` not sing-box official `geo`. Paths user-configurable in settings repo (`Configs::dataManager->settingsRepo`).

- **Deeplinks (throne://) — OS scheme handler**
  - Handler: `src/sys/UrlScheme.cpp/.hpp` + `mainwindow_deeplink.cpp` — registered at startup portable (no admin) for Windows/Linux/macOS, self-heals if moved.
  - Commands (case-insensitive, all `throne://<cmd>/<base64_payload>` with slash+payload required, no query params):
    - `addsub` — Standard Base64 `url#name` → confirm dialog listed + fetched immediate.
    - `route` — URL-safe or Standard Base64 or plain JSON `{"kind":"throne-route-profile","v":1,"name":...}` → `Ctrl+C` in Routing Settings exports this.
    - `remoteroute` — Standard Base64 newline `https://...#Name` list → confirmation + `Auto update` global.
    - `add` — Base64 outbound JSON → added to current group no confirm (deep link share `Ctrl+Alt+C`).
  - Error logs: `Ignored deeplink with unknown command`, `Base64 is invalid.`, `The link did not contain a subscription URL`.

- **Warp gen / chain (1.1.0)**
  - `src/global/OtpPlaceholder.cpp`, `VpnCredentialOverride.cpp`, `DeviceDetailsHelper.cpp` + core `egress.go` — generate Cloudflare WARP `wireguard` config (`engage.cloudflareclient.com:2408`), allow chaining as egress detour.

- **Backup & Restore (1.1.3)**
  - `Settings → Backup/Restore` — exports SQLite + `config/srslist.h` snapshot. Import handles legacy DB incompat (1.1.0 *Migrate to SQLite — incompatible, must migrate by hand*).

- **Safety & updater**
  - `prepare_exit()` (`mainwindow_system.cpp:66-102`) → `set_system_proxy(false)` + `set_system_dns(false)` + `profile_stop()` + `core_process->Kill()` + `tray->hide()`. Exit reasons `RunUpdater` → `updater.exe`/`updater` via `QProcess::startDetached`, `Restart`/`RestartWithTun`/`RestartWithDns` via elevation on Windows.
  - Updater copies to `updater.old` on Windows before exec — explains AV heuristic false positive (FAQ).

- **Logs & Filtering (1.1.0 Add log filtering)**
  - `mainwindow_log.cpp` + `global/Logger.cpp/.hpp` + `include/global/Logger.hpp` — auto-scroll toggle (contrib `alpatovdanila` 1.1.3), filter by level/tag. Core emits `warn` default (`log: { level: warn }` log snippet).

- **Other UX polish**
  - `Make simple rules index adjustable`, `Improve Profile Table Columns customization`, `Show connection speed in connections Tab and allow sorting`, `Improve menus and Tool Buttons`, `Improve certain UI sections`, `Multiple file selection for importing from file`, `Backup and restore capability`, `Security enhancements`.

---

## 10. Platforms — Build & Install Matrix

### Microsoft Windows

- **Minimum:** `Windows 7 SP1` (legacy zip `windowslegacy64.zip`) → `Windows 10` (`windows64.zip`) → `Windows 11` OK.
- **Artifacts per 1.2.4 (14 total):** `Throne-1.2.4-windows-universal-installer.exe` (~107 MB), `windows64.zip` (~44 MB), `windows32.zip` (~33 MB), `windows-arm64.zip` (~40 MB), `windowslegacy64.zip` (~35 MB) — sizes from API `size` field.
- **Install methods:**
  - Portable: extract `windows*.zip` → `Throne.exe` (no admin until TUN mode)
  - Installer: `Throne-x.x.x-universal-installer.exe` → `Fix windows installer permission handling` (1.1.3), `Make windows installer universal` (1.1.3), `Fix windows installer behavior` (1.2.3)
  - **WinGet:** `winget install -e --id Throneproj.Throne`
  - **Scoop:** `scoop bucket add extras && scoop install extras/throne`
  - **Symlink fix:** 1.1.5 *Fix symlink issues on windows*
- **macOS-style quarantine not needed.**
- **Bits:** `x64`, `x86` (32-bit), `ARM64` (native). `universal-installer.exe` bundles all.

### Linux

- **Minimum:** `GLIBC 2.34` (amd64) / `2.38` (arm64) per Downloads table. Debian/Ubuntu `.deb` — two flavors (`-system-qt` ~25 MB vs full ~49 MB) — difference is bundled Qt libs (FAQ 3× heavier with bundled).
- **Artifacts per 1.2.4:** `linux-amd64.zip` (~63 MB), `linux-arm64.zip` (~60 MB), `debian-amd64.deb` (~49 MB), `debian-amd64-system-qt.deb` (~25 MB), `debian-arm64.deb` (~46 MB), `debian-arm64-system-qt.deb` (~23 MB).
- **Install methods:**
  - **CLI installer (recommended):** `curl -fsSL https://raw.githubusercontent.com/throneproj/Throne/dev/script/install_linux.py | sudo python3` (`script/install_linux.py` interactive menu: Install/Uninstall, stable/unstable, shows installed version). Installs to `/opt/Throne` + `.desktop` entry. Update = re-run. Uninstall leaves `~/.config/Throne` untouched. Needs Python3 + root.
  - Portable: `unzip linux-*.zip && ./Throne`
  - Debian/Ubuntu: `sudo apt install ./debian-*.deb`
  - **Fedora/RHEL9+:** `sudo curl -o /etc/yum.repos.d/throne.repo https://parhelia512.github.io/throne.repo && sudo dnf install -y throne --refresh`; older RHEL via `parhelia512.github.io` RPM repo
  - **openSUSE/SLES:** `sudo zypper addrepo -fc https://parhelia512.github.io/throne-sle.repo && sudo zypper install -y throne`
  - **Arch AUR:** `yay -S throne` / `paru -S throne` (packages `throne` stable + `throne-git` dev — `aur.archlinux.org/packages/throne-git` `1.1.1.r71.g5bd6cb2-1`, AUR keywords `nekoray proxy sing-box throne vpn`, license `GPL-3.0-or-later`, provides `throne` conflicts `nekoray-git`)
  - **NixOS:** `programs.throne = { enable = true; # tunMode.enable = true; }` in `configuration.nix`
  - **Nix:** `nix-env -iA nixos.throne` or `nix-shell -p throne`
- **Privilege for TUN:** `SUID` (`chmod +s ThroneCore`) or `cap_net_admin` (`setcap cap_net_admin+ep ThroneCore`) or disable auto escalation in `Basic Settings → Security` → manual caps + 3-4 password prompts per TUN toggle. FAQ: *To create and manage system TUN interface, root access required*.
- **Auto-redirect Linux quirk:** `auto_redirect` enabled remaps via `nftables` (`florianl/go-nfqueue/v2`, `google/nftables`, `coreos/go-iptables`) — regression requires Throne *Disable private range Bypass* + sing-box 1.14.

### macOS

- **Minimum:** `macOS 13` (arm64 Apple Silicon) / `macOS 10.15` (legacy Intel) per Downloads table.
- **Artifacts per 1.2.4:** `macos-arm64.zip` (~50 MB), `macos-amd64.zip` (~54 MB), `macoslegacy-amd64.zip` (~52 MB).
- **Install:** Extract ZIP → `xattr -d com.apple.quarantine /path/to/Throne.app` then `mv Throne.app /Applications` **before first launch** (built-in privilege escalation spawns `Terminal` to `chown root`/`chmod +s` core — fails if still in `~/Downloads`). Unsigned → Gatekeeper quarantine removal required.
- **Fixes:** 1.2.4 *Fix MacOS DNS issues in Tun mode* + *Fix Xray config issues on Linux in Tun mode*; 1.1.5 *Fix MacOS database storage location*; Nix/Linux not affected.

### Cross-cutting download stats

- Badge `img.shields.io/github/downloads/throneproj/Throne/total` → total downloads (not per-release). Per-version 14 assets × ~23-107 MB. Release cadence: `75 releases` since Feb 2024, ~biweekly. Latest dev build via `Actions` `runs/30078801884` referenced in #1687.

---

## 11. Build — From Source & Toolchain

- **Quick build (docs `get_started/installation#build-from-source`):**
  ```bash
  git clone --recursive https://github.com/throneproj/Throne.git
  cd Throne && mkdir build && cd build
  curl -fLso srslist.h "https://raw.githubusercontent.com/throneproj/routeprofiles/rule-set/srslist.h"
  cmake .. && make -j$(nproc)
  ```
  - `--recursive` pulls subm `3rdparty/QHotkey`, `SQLiteCpp`, `fkYAML`, `quirc`, `simple-protobuf`, `qv2ray`.
  - `srslist.h` generation: route profiles compiled header included in build tree (`cmake/nkr.cmake` includes `srslist.h`).

- **Toolchain pins (from go.mod + CMakeLists.txt + 1.1.3 notes):**
  - C++20, Qt 6.11.1, Go 1.26 (1.25.9 in 1.1.3 notes, Go 1.22+ needed for `replace` wireguard-go fork), CMake 3.20+, protobuf (`myproto` via `simple-protobuf` + `google.golang.org/protobuf v1.36.11`, `grpc v1.82.1`), Python3 for `install_linux.py`.
  - Go deps: `sing-box 1.13.20`, `sing v0.9.0-beta.4`, `sing-tun v0.9.0-beta.2`, `xray-core 1.260327.x` fork, `mieru v3.33.0`, `sing-anytls v0.0.11`, `sing-juicity v0.3.0-beta.1`, `quic-go 0.59`, `utls/metacubex`, `wireguard-go fork`, `speedtest-go 1.7.13`, `cobra 1.10.2`, `crypto 0.54.0`, `sys 0.47.0`.

- **Directory map (authoritative paths):**
  - `CMakeLists.txt` → root build definition
  - `cmake/{nkr.cmake, QHotkey.cmake, print.cmake, myproto.cmake, macos/*.cmake, windows/*.cmake, linux/*.cmake}`
  - `3rdparty/{QHotkey, QrDecoder.{cpp,h}, QtExtKeySequence*, qrcodegen.*, quirc/, SQLiteCpp/, fkYAML/, simple-protobuf/, qv2ray/}`
  - `core/server/{main.go, server.go, dispatch.go, egress.go, server_autoselector.go, server_interface.go, server_vpnstatus.go, dashboard_{unix,windows}.go, go.mod, go.sum, gen/, internal/, ipc/, parentcheck/}`
  - `core/.gitignore` (ignore Go bin)
  - `include/{api, configs, database, global, stats, sys, ui}` + matching `src/{api, configs, database, global, main.cpp, stats, sys, ui}`
  - `src/global/{Configs, Utils, Logger, PeriodicRunner, HTTPRequestHelper, DeviceDetailsHelper, CountryHelper, OTP, OtpPlaceholder, VpnCredentialOverride}.cpp`
  - `src/configs/sub/{GroupUpdater, RouteUpdater, clash.vpnFileImport}.cpp/.hpp`
  - `src/sys/{Process, ProcessMetrics, UrlScheme}.cpp` + `include/sys/{windows, linux, macos}/`
  - `src/ui/mainWindow/{mainwindow_{setup,events,groups,view,connections,profiles,deeplink,system,log,hotkeys,profile_lifecycle,autoselector}.cpp, TestRunner.cpp}`
  - `src/ui/setting/{ThemeManager, Icon, dialog_{basic_settings, hotkey, manage_routes, manage_groups, otp_manager, preset_settings, vpn_settings}.cpp}`
  - `src/ui/widget/{StartStopButton, TrayProfileSelector, TrayOtpCodes, json/{JsonTree, JsonValidator, SchemaStore, JsonCodeEdit}.cpp}`
  - `src/ui/group/dialog_manage_groups.*`
  - `src/api/RPC.cpp`
  - `src/stats/traffic/{TrafficLooper, TrafficStatsManager}.cpp`
  - `res/{...}` (`res.qrc` bundled)
  - `script/install_linux.py`
  - `include/ui/mainwindow.ui` (Qt Designer)
  - `.github/` (CI — Actions `runs/*`)

---

## 12. Build Stats & Release Changelog Highlights

- **GitHub API snapshot (2026-08-29):** `stars 6933` · `forks 394` · `watchers 51` · `open_issues 37` · `created 2024-02-07` · `updated 2026-08-29` · `pushed 2026-08-28` · `size 30263` (KB).
- **Recent releases (per_page 15):**
  - `1.2.4 @ 2026-08-08`: Fix Xray profile DNS issues, Fix auto selector bugs, Fix MacOS DNS in TUN, Fix Xray config on Linux in TUN.
  - `1.2.3 @ 2026-08-07`: Add Auto-selector (selector+urltest load-balance), Fix windows installer, Fix Xray profiles on certain windows systems, Fix Exclude private range in TUN.
  - `1.2.2 @ 2026-07-29`: (small fix)
  - `1.2.1 @ 2026-07-26`: Re-Enable strict route on windows with warnings, Fix Xray downloadSetting interface binding, Re-add `auto_redirect` on Linux, Fix Xray core DNS issues.
  - `1.2.0 @ 2026-07-22`: Add remote route profiles, `block`+`warp-bypass` defaults, Raw routing profile, Improve Xray, Hiddify TLS fragment/Mixed-case, traffic statistics module, Mieru protocol, runtime stats widget, Disable strict route by default, Google DoH default, Security view column, Remove insecure configs action, Linux universal installer.
  - `1.2.0-beta.3 @ 2026-06-26`: Fix testing current with wrong outbound, Make sniff/hijack-dns always on, Show speed in connections, Use Xray for reality default, sing-box 1.13.14, Tray menu improvements, Mieru.
  - `1.1.6 @ 2026-06-08` … `1.1.5 @ 2026-06-06`: Deeplink support, AmneziaWG v2 re-added, Old Nekoray Themes, sing-box 1.13.13, Xray fix.
  - `1.1.3 @ ~2026-05`: ICMP network, Disable Mixed inbound, Chain support Xray/Extra core, Hwid params, Themes, etc.
  - `1.1.0 @ 2026-03-07`: Xray VLESS, SQLite migration (incompatible), hwid, Warp gen/chain, sing-box 1.13.2 — **requires clean install**.

- **Download matrix per latest (1.2.4 14 assets):** Debian `.deb`/`-system-qt` ×2 arch (25-49 MB), Linux ZIP ×2 (60-63 MB), macOS ZIP ×3 (50-54 MB), Windows ZIP ×4 (33-44 MB) + universal installer (107 MB).

- **Credits (README):** SagerNet/sing-box, XTLS/Xray-core, Qv2ray, Qt, simple-protobuf, fkYAML, quirc, QHotkey, srombauts/sqlitecpp.

---

## 13. Issues & Known Quirks (from fetch)

- **#1477 — Xray VLESS 60s loop via TUN `ThroneCore.exe` process rule** — `find_process` unreliable → add `ip_cidr → direct` for proxy server IP fix suggestion.
- **#1687 — TUN stacks `system`/`mixed` silent fail → only `gvisor` works** — root causes mixed: sing-box 1.13.14 `auto_redirect` + `route_exclude_address` `nftables: file exists` (needs 1.14), Avast AV network shield (disabling Avast fixes), Ubuntu 26.04 / Arch / cachyOS 7.1.4 / Windows 11 25H2 all reproduced. Workaround: `Stack: gvisor` + `Disable Private Range Bypass` + `auto_redirect`.
- **#1353 / #1274 — AmneziaWG 2.0 vs FinalMask debate** — maintainer: *AWG will never be in upstream sing-box* (noise layer), wait for sing-box or third-party fork `throne-sing-box-awg` (`hoaxisr/amnezia-box` impl) vs Xray `FinalMask` Swiss-army. `cache.db` small bug when only AWG profiles loaded.
- **#1462 — AnyTLS-Reality greyed** — character encoding Linux vs Windows root cause, now supports.

---

## 14. Quick Reference — Key File Paths

| Area | Path |
|------|------|
| Go core entry | `core/server/main.go` (watchMemory, IPC, parentcheck) |
| Core config dispatch | `core/server/dispatch.go`, `egress.go`, `server*.go`, `internal/boxmain` |
| IPC | `core/server/ipc/**`, `src/api/RPC.cpp`, `include/api/RPC.h` |
| Subscription + Clash | `src/configs/sub/GroupUpdater.*`, `RouteUpdater.*`, `clash.cpp`, `vpnFileImport.*`, `include/configs/generate.h` |
| DB | `src/database/**`, `include/database/**`, `3rdparty/SQLiteCpp` |
| TUN/System proxy | `src/ui/mainWindow/mainwindow_system.cpp`, `mainwindow_profile_lifecycle.cpp`, `src/ui/setting/dialog_vpn_settings.*`, `core/server/server_vpnstatus.go` |
| Deeplinks / URL scheme | `src/sys/UrlScheme.*`, `src/ui/mainWindow/mainwindow_deeplink.cpp` |
| Hotkeys | `src/ui/mainWindow/mainwindow_hotkeys.cpp`, `3rdparty/QHotkey` |
| Stats | `src/stats/traffic/*`, `include/stats/traffic/*` |
| Global singletons | `src/global/Configs.*`, `Logger.*`, `PeriodicRunner.*`, `HTTPRequestHelper.*` |
| Theming | `src/ui/setting/ThemeManager.*` |
| Widgets | `src/ui/widget/**`, `include/ui/widget/**` |
| Generate | `src/configs/generate.*` (sing-box JSON builder) |
| Build | `CMakeLists.txt`, `cmake/**/*.cmake`, `core/server/go.mod` |

---

## 15. Verdict Notes (for VPN Research)

- **Throne = GUI + sing-box orchestrator**, not a protocol inventor — its value is **subscription/route/chain/TUN/DNS UX** atop battle-tested sing-box/Xray data planes. Direct comparison basis vs `Karing`, `Matsuri`, `NekoBox`, `Hiddify`, `Clash Meta`.
- **Protocol breadth best-in-class for Qt desktop**: AnyTLS + Mieru + Juicity + TrustTunnel + AWG v2/v3 + Xray Reality + XHTTP distinguishes from pure sing-box GUIs that lack AWG/Mieru or delegate Reality to Xray only.
- **2026 DPI-relevant defaults**: Reality via Xray + Vision/XHTTP, Hiddify fragment/mixed-case, Google DoH, sniff/hijack always on — correct for GFW/TSPU/Roskomnadzor threat model (VPNSmith/MoaV field reports).
- **TUN reliability caveat**: `system`/`mixed` fragile across AV + `nftables` exclude sets → docs should recommend `gvisor` fallback and *Disable Multi-Homed DNS + QUIC* hardening for Windows TUN.
- **Subscription interop strong**: Clash partial + sing-box JSON + v2rayN URI + deeplink `throne://` — outperforms single-format managers; Clash rule import still limited.

---

*Generated 2026-08-29 — sources: `throneproj/Throne` README+API, `throneproj.github.io` (installation/configuration/advanced/windows_tun_mode/deeplinks/downloads), `core/server/go.mod`, `CMakeLists.txt`, issues #1477/#1687/#1353/#1462, `throneproj/routeprofiles`, `sing-box` inbound/tun docs, releases 1.1.0→1.2.4. Verify `TUN stack = gvisor` if `system` silent-fails; verify `AWG Jc/Jmin/Jmax` ranges match `amneziawg-go` warning about `Jmax < MTU`.*
