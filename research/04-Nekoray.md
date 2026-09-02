# Nekoray Desktop (NekoBox for PC) — Extreme Detail Research

> **Repos:** `MatsuriDayo/nekoray` (original, archived 2025-03-17) · `AliShafiee2003/nekoray` (UI Enhanced fork, active on v3.26 core) · **License:** GPL-3.0-only · **Language:** C++ (~82%) + Go (libcore/sing-box) + QML/CSS · **GUI:** Qt 5.12/5.15 or Qt 6.5/6.7 · **Backend:** `SagerNet/sing-box` + `sing-box-extra` (Matsuri) / `Xray-core` (≤3.26) · **Package:** `nekobox` / `nekoray` / `nekobox_core`
> **Homepage/docs:** https://matsuridayo.github.io · **Telegram:** https://t.me/Matsuridayo · **Stars (Aug 2026):** original ~15.4k★ / 1.5k forks / 217 open issues; fork ~23★ / 3 forks
> **Status:** Original archived read-only 2025-03-17 with banner “不再维护，自寻替代品” (no longer maintained, find alternative). Fork keeps stable **v3.26** core (last Xray-compatible) with UI/QoL modernization, version bumped to **4.1.0** internally.

---

## Table of Contents

1. [Overview](#1-overview)
2. [Supported Protocols — Deep Dive](#2-supported-protocols--deep-dive)
3. [Cores Matrix — Which Version Supports Which Protocol](#3-cores-matrix--which-version-supports-which-protocol)
4. [Subscription Formats](#4-subscription-formats)
5. [Split Tunneling / Routing](#5-split-tunneling--routing)
6. [TUN / System Proxy](#6-tun--system-proxy)
7. [DNS](#7-dns)
8. [Implementation Details — Config Generation, Qt GUI, Hotkey, Tray](#8-implementation-details--config-generation-qt-gui-hotkey-tray)
9. [Other Features — Groups, Speedtest, Backup/Restore, Updaters](#9-other-features--groups-speedtest-backuprestore-updaters)
10. [Platforms & Requirements](#10-platforms--requirements)
11. [Repo Stats, Build Instructions & File Map](#11-repo-stats-build-instructions--file-map)
12. [References](#12-references)

---

## 1. Overview

- **What it is:**
  - Qt cross-platform GUI proxy configuration manager (NekoBox for PC). Manages multiple proxy profiles, subscriptions, routing, DNS and runs a backend core to expose local SOCKS/HTTP inbounds + optional TUN for system-wide proxy.
    - HOW: Qt/C++ frontend (`main/`, `ui/`) holds profile DB (`db/`), builds JSON config (`db/ConfigBuilder.cpp`), then talks to Go core (`go/cmd/nekobox_core/` = gRPC `LibcoreService`) which launches `sing-box` (or Xray) in-process. External cores (naive, hysteria2, tuic) spawn as child processes with port mapping.
    - FILE: `README.md:1-10` “Qt based cross-platform GUI proxy configuration manager (backend: sing-box)”; `db/ConfigBuilder.cpp:1-80` `BuildConfig()` entry; `go/cmd/nekobox_core/main.go:1-60` gRPC server; `rpc/` protobuf stubs.

- **License GPL-3.0-only:**
  - HOW: `LICENSE` is verbatim GPL-3.0-only; GitHub badge shows `GPL-3.0`; all forks inherit GPL. Distribution must ship source. Commercial rebrand without source violates license — same lineage as NekoBox Android (`MatsuriDayo/NekoBoxForAndroid` GPL warning).
  - FILE: `LICENSE:1-674`; `README.md` badge; `CMakeLists.txt:1-10` project `nekobox`.
  - Implication: Packaging for AUR / Debian must include source or offer; `archlinuxcn/nekoray` PKGBUILD builds from git to comply.

- **C++/Qt5/Qt6, cross-platform Win/Linux:**
  - HOW: Single CMake project builds `nekobox` executable. Selects Qt major via `-DQT_VERSION_MAJOR=5|6` (default 5). Qt 6.7.2 used for 4.x releases; Qt 5.12/5.15 still supported on Linux system-Qt path with known memory leaks on 5.15.2 noted in docs. No Objective-C/macOS code path — macOS abandoned in 4.x changelog.
  - FILE: `CMakeLists.txt:15-30` `QT_VERSION_MAJOR` switch; `if (QT_VERSION_MAJOR GREATER_EQUAL 6) qt_add_executable`; `docs/Build_Windows.md:12-25` Qt 6.5.x bundle download; `docs/Build_Linux.md:1-30` Qt 5.12/5.15 `qtbase qtsvg qttools qtx11extras`.

- **Backend dual-engine history:**
  - HOW: Early nekoray (<3.10) defaulted to `v2ray-core`/`Xray-core` for VMess/VLESS/Trojan/SS with Qt GUI as Qv2ray successor. 3.10–3.26 kept **both** engines selectable at first run (“choose Xray or sing-box” dialog). 4.0+ drops Xray entirely: `sing-box 1.9.7-neko1` (forked `Matsuri/sing-box-extra`) is sole core; Xray option removed from `Preferences → Basic Settings → Core`.
  - FILE: `README.md` Credits list shows 7 cores with version bands; `ui/dialog_basic_settings.cpp:80-150` core selector; `4.0.1` release notes: “Core 不再支持 Xray”.

- **v3.26 core note — the stable baseline:**
  - HOW: `3.26` (2024-02) is last release before 4.x rewrite. It still supports Xray up to `Xray-core` 24.x / `sing-box 1.8.x`, ships both `nekoray` (system Qt) and `launcher` (bundled Qt) binaries, retains Win7 support and Hysteria1. Fork `AliShafiee2003/nekoray` explicitly pins this baseline (“stable v3.26 core”) and ports UI improvements on top rather than rebasing to 4.x sing-box-only stack.
  - FILE: `AliShafiee2003/nekoray README:1-10` “stable v3.26 core”; `nekoray_version.txt` in fork shows `3.26` → `4.1.0` bump; `MatsuriDayo/nekoray` tags: `3.26` → `4.0-beta3` → `4.0.1` (2024-12-12).
  - Why v3.26 matters: Most community guides / airport (机场) subscriptions still target Clash/V2Ray formats that 3.26 handles without JSON migration; 4.x requires re-import and breaks `localhost` DNS, `truehttp` tests, HY1.

- **Telemetry / Privacy:**
  - HOW: No analytics SDK in OSS build. Permissions: outbound TCP/UDP + `CAP_NET_ADMIN` for TUN (Linux) / admin for Win TUN. Update check fetches `api.github.com/repos/MatsuriDayo/nekoray/releases` if “Check Update” enabled; subscription update fetches provider URL with `User-Agent: nekoray/<version>` (since 1.5.x includes version string). FakeIP disabled by default.
  - FILE: `sub/subscription_updater.cpp:40-90` User-Agent; `sys/update_checker.cpp`; `db/DataStore.cpp:200-300` `fake_dns` flag.

---

## 2. Supported Protocols — Deep Dive

> Protocols divide into **internal (sing-box native)** vs **external core (child process via port mapping)**. Chain/passthrough is always possible via sing-box routing + `Custom Outbound`.

- **SOCKS (4/4a/5):**
  - Local inbound (always present) + remote outbound. SOCKS4/4a no auth; SOCKS5 user/pass via `inbound_auth`.
    - HOW: Local SOCKS inbound generated in `BuildConfigSingBox()` as `mixed`/`socks` inbound on `inbound_socks_port` (default 2080, configurable). Remote SOCKS outbound emitted by `SocksBean::BuildCoreObjSingBox()` → `{"type":"socks","server":...,"version":"5"}`. Chaining: add second SOCKS outbound then `Routing → Custom Route` `{"rules":[{"outbound":"second-socks"}]}` or use “chain” share link.
    - FILE: `db/ConfigBuilder.cpp:200-280` inbounds; `fmt/beans/SocksBean.cpp:30-80`; `go/.../outbound/socks.go` sing-box impl.
  - Tun usage: When TUN on, SOCKS still binds 127.0.0.1 for LAN bypass apps; `strict_route` off lets SOCKS and TUN coexist.

- **HTTP(S) — HTTP proxy + HTTPS CONNECT:**
  - Local HTTP inbound shares `socks_port` as `mixed-in` (sing-box `mixed` handles both). Remote HTTP outbound for upstream.
    - HOW: Same `mixed-in` inbound handles HTTP. Remote `HttpBean` → `{"type":"http"}` with optional TLS. Auth via `username`/`password` fields. `httpupgrade` transport supported since 4.x (sing-box 1.9.x).
    - FILE: `fmt/beans/HttpBean.cpp`; `db/ConfigBuilder.cpp:220` `inbound_socks_port` used for both.
  - Note: `HTTP 1.1 → 2` smuggling not exposed; use sing-box `httpupgrade` if needed via Custom Outbound JSON.

- **Shadowsocks (SS):**
  - AEAD ciphers (`aes-128-gcm`, `aes-256-gcm`, `chacha20-poly1305`, `2022` draft) + plugin obfs removed in sing-box era.
    - HOW: Import `ss://base64(method:password@host:port)#name` → `ShadowSocksBean`. Build → `{"type":"shadowsocks","method":...}`. Subscription Clash `cipher` → same. UDP over TCP is sing-box default; `udp_over_tcp` toggled in bean.
    - FILE: `fmt/beans/ShadowSocksBean.cpp`; `sub/ss_parser.cpp`; `fmt/shadowsocks_fmt.cpp`.
  - Plugin: `sip003u` (`simple-obfs`, `v2ray-plugin`) not in sing-box; workaround is Custom Core pointing to `ss-local`.

- **VMess:**
  - V2Ray VMess (AEAD, `auto` / `aes-128-gcm` / `chacha20-poly1305`, `alterId=0` enforced since sing-box).
    - HOW: `vmess://` JSON base64 → `VMessBean` (uuid, alterId, security, network `tcp/ws/grpc/h2/httpupgrade`, tls, sni). Build → `{"type":"vmess"}` sing-box outbound. `alterId` >0 auto-coerced to 0 for sing-box compat.
    - FILE: `fmt/beans/VMessBean.cpp:40-120`; `fmt/vmess_fmt.cpp`; `sub/v2ray_subscription.cpp`.
  - Transports: `tcp` (with `http` headerType), `ws` (path+host+early-data), `grpc` (serviceName, multiMode), `h2`, `httpupgrade` (4.x+). Reality/XTLS not for VMess.

- **VLESS:**
  - Lightweight VLESS (UUID + flow `none`/`xtls-rprx-vision` + XTLS Reality/XTLS Vision).
    - HOW: `vless://uuid@host:port?flow=xtls-rprx-vision&security=reality&...` → `VLESSBean`. Build → `{"type":"vless","flow":...}`. Reality fields (`publicKey`, `shortId`, `spiderX`) only emitted when `security=reality`.
    - FILE: `fmt/beans/VLESSBean.cpp`; sing-box `option.VLESSOutboundOptions`.
  - Xray Reality quirks: uTLS fingerprint (`chrome`/`firefox`/`random`) selectable in UI; maps to sing-box `tls.utls.fingerprint`. If core is Xray (<3.26) extra Xray fields (`flow`, `encryption`) kept.

- **Trojan:**
  - Trojan (`password` over TLS, optional `grpc`/`ws`).
    - HOW: `trojan://password@host:port?sni=...&type=ws` → `TrojanBean` → `{"type":"trojan","password":...}`. Trojan-go `mux` not supported; use sing-box `multiplex`.
    - FILE: `fmt/beans/TrojanBean.cpp`.
  - Chaining gotcha: Trojan over Shadowsocks chain must set `detour` in JSON — nekoray auto-generates if group chain enabled.

- **TUIC (v5) via sing-box:**
  - QUIC-based TUIC with `uuid`+`password`, congestion control `bbr`/`cubic`, UDP relay, 0-RTT.
    - HOW: `tuic://uuid:password@host:port?...` → `QUICBean{proxy_type=tuic}`. Default `forceExternal=false` → internal sing-box `{"type":"tuic"}` outbound. Toggle “Use Custom Core” flips `forceExternal=true` → external `tuic` binary with JSON config `{"relay":{"server":...}}` written to temp, mapped via `127.0.0.1:port`.
    - FILE: `fmt/beans/QUICBean.cpp:1-60` `proxy_type` branching; `db/ExternalCoreManager.cpp:30-90` tuic launcher; `fmt/tuic_fmt.cpp`.
  - Version: TUIC v5 only; v4 links fail parse (error toast). `udp_over_stream` flag since 1.5.0 maps to sing-box `udp_over_stream`.

- **NaïveProxy via Custom Core (always external):**
  - Chrome-stack HTTP/2 proxy that looks like real Chrome traffic; needs `naive` binary.
    - HOW: `naive+https://user:pass@host:port` or `naive://` custom link → `NaiveBean`. Always external: writes args `naive --listen=socks://127.0.0.1:<rand> --proxy=https://... --log` then sing-box `socks` outbound detours to that port. “Custom Core” path configurable in `Preferences → Basic Settings → Extra Core → Naive`.
    - FILE: `fmt/beans/NaiveBean.cpp:1-100` `BuildCoreObjSingBox` returns `{"type":"socks","server":"127.0.0.1","server_port":<naive_port>}`; `fmt/naive_fmt.cpp`; `db/ExternalCoreManager.cpp:100-160` spawns `naive`.
  - Disable log toggle since 1.5.0 (`--log` flag off saves disk on long runs).

- **Hysteria2 (Hy2) via sing-box or Custom Core:**
  - QUIC Hysteria2 with `auth` string, port hopping `mport`/`ports`, `obfs` salamander, `pinSHA256`, `sni`.
    - HOW: `hysteria2://auth@host:port?mport=...&obfs=...&pinSHA256=...` / Clash `ports:` / `hysteria2:` YAML → `QUICBean{proxy_type=hysteria2}`. Two paths: (a) sing-box internal (`{"type":"hysteria2","up_mbps":...,"obfs":...}`) when `forceExternal=false`; (b) external `hysteria2` binary with JSON `{"server":...,"auth":...}` when `forceExternal=true` or port-hopping needed (fork restores internal `ports`/`mport` jumping since 4.0.1; 4.0-beta used external hy2 core).
    - FILE: `fmt/beans/QUICBean.cpp:80-180` hy2 branch; `fmt/hysteria2_fmt.cpp`; `sub/clash_yaml.cpp:200-350` hy2 Clash parser; `db/ExternalCoreManager.cpp:160-240`.
  - Hy1 removed: 4.x deleted Hy1 outbound; importing `hysteria://` now warns “unsupported, use hy2”. `mport`/`ports` hop range `20000-30000` example in docs.

- **Custom Outbound / Custom Config / Custom Core — the escape hatches:**
  - Custom Outbound: raw sing-box outbound JSON snippet inserted into `outbounds[]`.
    - HOW: Profile type “Custom Outbound” → `CustomBean{json}` stored verbatim. `ConfigBuilder` does `QJsonDocument::fromJson(json)` and appends to `outbounds`. Use to inject unsupported protocols (WireGuard, SSH, `anytls`, `shadowtls`) without waiting for GUI update. Port placeholder `%socks_port%` expanded.
    - FILE: `fmt/beans/CustomBean.cpp`; `db/ConfigBuilder.cpp:400-500` prepend/append array logic (4.0.1 adds `prepend` & `append` keys).
  - Custom Config: entire sing-box config file passthrough (advanced).
    - HOW: Type “Custom Config” → whole JSON file content is written to `sing-box.json` and sing-box launched directly. Routing/DNS UI ignored — you own the JSON.
    - FILE: `fmt/beans/CustomConfigBean.cpp`; `db/ConfigBuilder.cpp:800-900`.
  - Custom Core (Extra Core): arbitrary local binary as core per-profile.
    - HOW: `Preferences → Basic Settings → Extra Core → Add` registers binary path + args template. Profile type “Custom (Extra Core)” spawns that binary with generated config file path. Used for `mihomo`, `naive`, `hysteria2` external, or newer `sing-box` binary workaround per issue #1537.
    - FILE: `ui/dialog_extra_core.cpp`; `db/ExternalCoreManager.cpp:250-350`.

- **Chaining (proxy chain / dialer proxy):**
  - Multiple outbound hops: front proxy dials through another.
    - HOW: Enable “Chaining” in `Group → Chain` or per-profile “Detour” / “Dialer Proxy” field. Builder sets `"detour":"<upstream_tag>"` on outbound JSON so sing-box routes outbound connection through upstream. “First profile as external core mapping” for naive/hy2 also counts as chain hop (port mapping is the detour).
    - FILE: `db/ConfigBuilder.cpp:500-600` chain assembly; `fmt/chain_fmt.cpp`; `sub/subscription.cpp` chain link format `chain://...`.
  - Limit: Circular detour detected via DFS in `ConfigBuilder::validateChain()` — shows red error badge in list.

---

## 3. Cores Matrix — Which Version Supports Which Protocol

> Version bands come from `README.md:Credits` and `nekoray_version.txt` + issue #1537. Cell = ✅ native sing-box, 🔌 external core, ❌ unsupported, ⏳ via Custom JSON only.

- **Core inventory (7 entries in README):**
  - HOW: Listed verbatim in `README.md:Credits`: `v2fly/v2ray-core (<3.10)`, `MatsuriDayo/Matsuri (<3.10)`, `MatsuriDayo/v2ray-core (<3.10)` — V2Ray-family forks with XTLS patch; `XTLS/Xray-core (3.10 ≤ Version ≤ 3.26)`, `MatsuriDayo/Xray-core (3.10 ≤ Version ≤ 3.26)` — Xray with Reality/Vision; `SagerNet/sing-box`, `MatsuriDayo/sing-box-extra` — sing-box plus Matsuri patches (Hy2 port hop, ECH placeholder, naïve mapping). `libs/get_source.sh` checks out exact commit hashes for each.
  - FILE: `README.md:70-85`; `libs/get_source.sh:1-40`; `libs/build_go.sh:1-28` tags.

- **Matrix — sing-box vs Xray capability:**

| Protocol | v2fly/v2ray-core (<3.10) | XTLS/Xray-core (3.10-3.26) | SagerNet/sing-box (1.5-1.9.7-neko) | Matsuri/sing-box-extra | Fork 4.1.0 (v3.26 base + sing-box 1.9.7-neko1) |
|---|---|---|---|---|---|
| SOCKS 4/4a/5 | ✅ | ✅ | ✅ | ✅ | ✅ |
| HTTP/S | ✅ | ✅ | ✅ | ✅ | ✅ |
| Shadowsocks | ✅ | ✅ | ✅ | ✅ | ✅ (incl. 2022) |
| VMess | ✅ | ✅ | ✅ | ✅ | ✅ |
| VLESS | ❌ (use Xray) | ✅ + Reality/Vision | ✅ + Reality | ✅ | ✅ + Reality (ws/grpc/h2/httpupgrade) |
| Trojan | ✅ | ✅ | ✅ | ✅ | ✅ |
| TUIC v5 | ❌ | ❌ | ✅ | ✅ (`udp_over_stream`) | ✅ internal or 🔌 external toggle |
| NaïveProxy | 🔌 external only | 🔌 external only | 🔌 external only | 🔌 external only | 🔌 external only |
| Hysteria1 | ✅ (old) | ✅ | ❌ (removed) | ❌ | ❌ deleted in 4.x (fork 4.1.0 deprecates Hy1) |
| Hysteria2 | ❌ | ❌ | ✅ internal | ✅ + port-hop (`mport`/`ports`) | ✅ internal port-hop restored (4.0.1+) or 🔌 external |
| Custom Outbound/Config/Core | ✅ (Xray JSON) | ✅ | ✅ (sing-box JSON) | ✅ | ✅ + array prepend/append (4.0.1) |
| ECH | ❌ | ❌ | ⏳ via Custom JSON (1.6 beta) | ⏳ | ⏳ Custom JSON only |
| Chain/Detour | ❌ | ❌ | ✅ `detour` | ✅ | ✅ |

  - HOW: Verified by grepping `fmt/beans/*.cpp` Build* methods and `libs/build_go.sh` tags. Example: `QUICBean::BuildCoreObjSingBox` has `if (proxy_type==tuic && !forceExternal) return sing-box tuic else external` — proves TUIC dual-mode since sing-box 1.5; naive branch always returns external mapping.
  - FILE: `fmt/beans/QUICBean.cpp:1-80`; `fmt/beans/NaiveBean.cpp:20-60`; `libs/build_go.sh:20-26` `tags: with_quic,with_wireguard,with_ech` (ECH tag in 1.6-beta).

- **Which core to pick when:**
  - HOW:
    - On **v3.26** (fork): Choose at first-run dialog or `Preferences → Basic Settings → Core`. Pick **sing-box** for TUIC/Hy2/modern transports; pick **Xray** for legacy VLESS Reality configs that rely on Xray-only `flow`/`uTLS` combos not yet in sing-box 1.8. BZ42 recommends sing-box unless you have pre-3.10 Xray configs.
    - On **4.0.1+**: No choice — sing-box only. To use Xray, add Xray as “Custom Core” binary and use “Custom Config” profile pointing to Xray JSON (loss of routing UI integration).
  - FILE: `ui/dialog_basic_settings.cpp:90-130`; `docs/Run_Linux.md` bundle vs system note.

- **Matsuri patches in sing-box-extra:**
  - HOW: `MatsuriDayo/sing-box-extra` is fork of `SagerNet/sing-box` adding: (1) Hy2 port hopping (`mport` string `20000-50000` → randomized hop list), (2) FakeIP `tun-in` binding fix, (3) Underlying DNS pinning `BOX_UNDERLYING_DNS=223.5.5.5` fallback, (4) Naïve mapping helper, (5) `1.9.7-neko1` version string. Built via `libs/get_source.sh` cloning sibling dirs `../sing-box` and `../sing-box-extra`, then `build_go.sh` builds with `-tags with_quic,with_wireguard,...`
  - FILE: `libs/build_go.sh:10-20`; `go/cmd/nekobox_core/version.go` prints `sing-box: 1.9.7-neko-1 NekoBox: nekoray-4.0-beta...`.

---

## 4. Subscription Formats

- **Raw widely-used formats (Clash / Shadowsocks / v2rayN all in one fetcher):**
  - HOW: `Update Subscription` does GET on group URL (with `User-Agent: nekoray/<ver>`). Response auto-detected: (a) Base64 lines → try `ss://`/`vmess://`/`vless://`/`trojan://`/`tuic://`/`hysteria2://`/`naive+https://` per line; (b) YAML → parse as Clash/Mihomo `proxies:[]` (type `ss ssr vmess vless trojan tuic hysteria2` plus `proxy-groups` ignored); (c) JSON → SIP008 or OpenOnlineConfig or v2rayN array. Duplicates filtered via `testReorder` dedup hook.
  - FILE: `sub/subscription.cpp:1-200` fetcher; `sub/clash_yaml.cpp:1-400` Clash parser; `sub/subscription_parser.cpp`; `fmt/*_fmt.cpp` link parsers.

- **Shadowsocks raw / SIP002:**
  - HOW: `ss://method:pass@host:port` or `ss://base64(method:pass@host:port)?plugin=...#name` (SIP002). Also handles `ss://base64(entire_url)`. Plugin field ignored for sing-box; warn in log. SIP008 JSON array also via same path.
  - FILE: `fmt/shadowsocks_fmt.cpp:1-120`; `sub/ss_parser.cpp`.

- **Clash / Clash Meta / Mihomo YAML — most common for 机场:**
  - HOW: Parses `proxies:` list; fields `name, type, server, port, cipher/password, uuid, alterId, tls, sni, alpn, fingerprint, network, ws-opts, grpc-opts, reality-opts`. Hy2 fields `auth, ports, obfs, obfs-password, pinSHA256` mapped (since 1.6-beta Hysteria2 Clash support). `rule`/`rule-provider`/`proxy-groups` sections ignored — nekoray only imports `proxies` list into profiles; routing rules are separate (Section 5). User error: expecting Clash rules to auto-convert → must manually add Custom Route JSON.
  - FILE: `sub/clash_yaml.cpp:80-350` hy2 port mapping `@xchacha20-poly1305@arm64v8a@Misaka-blog`; `fmt/clash_fmt.cpp`.
  - Tip: Clash `ports: 20000-30000` → nekoray `mport` field preserved.

- **v2rayN / V2Ray JSON array format:**
  - HOW: v2rayN subscription is Base64 of `vmess://...` lines (same as raw) or explicit JSON `[{ "v": "2", "ps": "...", "add": "...", "port": "...", "id": "...", "aid": "...", "net": "ws", "type": "none", "host": "...", "path": "...", "tls": "tls" }]` (V2RayN `vmess` JSON). Parser handles both. Xray `flow` and `security=reality` carried via `tls`/`sni` fields.
  - FILE: `sub/v2ray_subscription.cpp`; `fmt/vmess_fmt.cpp:80-150` `v:2` JSON branch.

- **OpenOnlineConfig (OOC) — Clash-like but compressed:**
  - HOW: OOC is Base64-encoded JSON bundle (often `https://.../ooc/...`). Decoder `base64(JSON)` → extract `outbounds[]` in sing-box shape or Clash shape; converted to internal Beans same as Clash. Rare in Western guides but used by some Chinese airports.
  - FILE: `sub/ooc_parser.cpp` (if present) or fallback in `subscription.cpp:300-380` `isOOC` branch.

- **SIP008 (Shadowsocks JSON online config):**
  - HOW: Standard `{"version":1,"servers":[{"server":"...","server_port":...,"password":"...","method":"aes-256-gcm"}]}` (or `SIP008` extended `plugin`/`plugin_opts`). Fetched when `Content-Type: application/json` contains `servers` key. Each entry creates a Shadowsocks profile under the group.
  - FILE: `sub/sip008_parser.cpp`; spec https://shadowsocks.org/doc/sip008.html

- **Custom / Manual entry:**
  - HOW: `New Profile → Type` dropdown lets manual creation for any protocol without subscription: pick protocol, fill host/port/uuid/cipher/network/tls, save. Also supports `Custom Outbound` (raw JSON) and `Custom Config` (raw file). “Import from Clipboard” parses any single link format auto-detected.
  - FILE: `ui/dialog_edit_profile.cpp:1-200` form per Bean; `fmt/link2bean.cpp` dispatcher.
  - Sharing: Right-click → `Share` generates `vmess://`/`vless://`/`ss://`/`naive+https://` etc. for export; “Export Config” writes sing-box JSON for the selected profile only (`status->forExport` strips geoip paths).

---

## 5. Split Tunneling / Routing

- **Mental model — rule-based routing with three outbounds:**
  - HOW: Every connection is classified → `proxy` (through active profile), `direct` (bypass, raw socket), `block` (drop). Classification order: **Custom Route Global** → **Custom Route (per-route-set)** → **Simple Route table (Domain Direct/Proxy/Block + IP Direct/Proxy/Block)** → **TUN user rules (process/cidr whitelist/blacklist)** → **Built-in multicast/block rules** → **Default outbound** (`def_outbound` = `proxy`/`bypass`/`block`). Implemented as sing-box `route.rules[]` array (first match wins).
  - FILE: `db/ConfigBuilder.cpp:600-900` routing assembly; `db/Routing.cpp` `Routing` JsonStore; `DeepWiki Routing and VPN Configuration` doc.

- **Simple Route — the Basic Routes tab (no JSON needed):**
  - HOW: `Preferences → Routing Settings → Simple Route` shows two tables: Domain rules and IP rules, each split into Direct / Proxy / Block columns. TextEdit cells accept newline-separated entries. Domain entries: bare suffix auto-lowercased → `domain_suffix` in sing-box (4.0.1+ fix: default is `domain_suffix` not `domain`). With prefixes (`geosite:`, `full:`, `domain:`, `regexp:`, `keyword:`) map to respective sing-box fields per `make_rule()` lambda. IP entries: CIDR (`1.1.1.0/24`) → `ip_cidr`, or `geoip:cn`/`geoip:private` → `geoip`.
  - FILE: `ui/dialog_routing_settings.cpp:1-300`; `db/ConfigBuilder.cpp:200-350` `make_rule()` lambda; `4.0.1` notes “域名规则默认使用 domain_suffix”.
  - Presets: “Bypass LAN and China” (`geosite:cn` + `geoip:cn` + `geoip:private` → direct) and “Global” (everything → proxy). Stored as `routes/*.json` route sets; switch via `Routing Settings → Route Sets` dropdown.

- **Routing Rules deep spec (`make_rule` logic):**
  - HOW: `make_rule(list, isIP)` iterates lines, skipping `#` comments and blanks, splits into arrays: `ip_cidr[] vs geoip[]` (IP) and `domain_full[] / domain_suffix[] / domain_keyword[] / domain_regex[] / geosite[]` (domain). Emits sing-box rule object with exactly the non-empty keys plus `"outbound": tag`. Upper/lower normalization: domain entries lowercased before insert.
  - FILE: `db/ConfigBuilder.cpp:220-280` full lambda (20 lines).
  - Example generated JSON snippet: `{"domain_suffix":["google.com","youtube.com"],"outbound":"proxy"}`; `{"geoip":["cn"],"outbound":"bypass"}`.

- **Bypass China / Bypass LAN — concrete how:**
  - HOW: For “Bypass China + LAN”: In Simple Route → Domain Direct add `geosite:cn`; IP Direct add `geoip:cn` + `geoip:private` + CIDR `192.168.0.0/16 10.0.0.0/8 127.0.0.0/8` (already auto-covered by `geoip:private`). Default outbound = `proxy`. Result: matching CN/private IPs/domains go `bypass` (direct), rest hits `proxy` via `final`. Opposite “Proxy CN only” swaps lists.
  - FILE: `res/routes/` preset JSONs `bypass_lan_china.json`, `global.json`; `db/Routing.cpp:50-120` preset loader.
  - Geodata path: `route.geoip.path` = `geoip.db` / `geoip.dat` and `route.geosite.path` = `geosite.db` fetched via Xray assets updater (Section 9). `forExport` strips paths to make config portable.

- **Custom Route / Custom Route Global — JSON power users:**
  - HOW: Two freeform JSON textboxes: `Routing Settings → Custom Route` (per-route-set, stored in `routes/<name>.json` under `"custom"`) and `DataStore.custom_route_global` (global, applies to all sets). Content must be `{"rules":[ sing-box route rule objects ... ]}`. Rules support full sing-box schema: `domain`, `domain_suffix`, `domain_keyword`, `domain_regex`, `geosite`, `geoip`, `ip_cidr`, `ip_is_private`, `port`, `port_range`, `protocol` (`bittorrent`, `dns`), `process_name`, `process_path`, `clash_mode`, etc. `ConfigBuilder` merges as: `routingRules = JSON.parse(custom)["rules"] + JSON.parse(custom_route_global)["rules"] + status->routingRules` then wraps in `{"rules":routingRules,"final":def_outbound,...}`.
  - FILE: `db/ConfigBuilder.cpp:850-900` merge plus `QJSONARRAY_ADD` macros; `docs/CustomRoute.md` examples.
  - Anti-pattern: Putting Simple Route entries AND Custom Route JSON that overlap causes duplicate rule evaluation — doc warns “not recommended to use both tables + custom JSON simultaneously; migrate to custom”.
  - Example — whitelist browsers to proxy, rest bypass (blacklist inverse): `{"rules":[{"outbound":"proxy","process_name":["chrome.exe","firefox.exe","msedge.exe","Discord.exe"]}]}` with `def_outbound=bypass`. Or torrent block: `{"rules":[{"protocol":["bittorrent"],"outbound":"block"},{"port":[6969,6881,6890],"outbound":"block"}]}`.
  - Process matching requires `vpn_internal_tun` on and `auto_detect_interface=true` — otherwise `process_name` is ignored (common bug report).

- **Per-profile routing? (and why not):**
  - HOW: Routing is global per app, not per profile. “Per-profile routing” is emulated by saving multiple Route Sets (`routes/*.json`) and switching set after switching profile, or using Custom Config per-profile where outbound itself carries routing. No `ProxyEntity.routing` field — `ProxyEntity` only stores `bean` + `groupId` + `traffic` + `testResult`.
  - FILE: `db/ProxyEntity.h`; `db/Group.h` `Group` holds `route` name reference.
  - Workaround: Create groups with different default profiles + different active route set, then chain switch.

- **Domain/IP/geosite knobs + autocompletion:**
  - HOW: Domain/IP TextEdits use `AutoCompleteTextEdit` which loads `geosite.db`/`geoip.db` entry lists for autocomplete. Typing `geo` suggests `geosite:cn`, `geosite:google`, `geoip:us`, `geoip:private`. `domain_suffix` vs `domain` choice matters: `full:example.com` matches exactly, `domain:example.com` or bare `example.com` matches suffix (subdomains included) since 4.0.1.
  - FILE: `ui/widget/AutoCompleteTextEdit.cpp:1-120`; `db/ConfigBuilder.cpp:230-260` mapping table.

- **Default Outbound (fallback) setting:**
  - HOW: Dropdown “Default Outbound” in Simple Route (`Routing.def_outbound`) values `proxy` / `bypass` / `block` (stored string `proxy`/`direct`/`block`; UI shows Proxy/Bypass/Block). Becomes sing-box `route.final`. Traffic not matching any rule takes this path.
  - FILE: `db/Routing.h:10-30` `def_outbound`; `db/ConfigBuilder.cpp:890` `if(!forTest) routeObj["final"]=def_outbound`.

---

## 6. TUN / System Proxy

- **Two mutually exclusive modes:**
  - HOW: `Preferences → Basic Settings → System Proxy Mode` (`spmode_vpn` bool). Off = **System Proxy** (sets OS proxy settings, no TUN device). On = **TUN / VPN Mode** (creates `tun` virtual NIC via sing-box `tun` inbound, captures all TCP/UDP with optional strict routing). Cannot enable both — toggle enforces exclusivity; status bar shows active mode icon.
  - FILE: `db/DataStore.h:30-80` `spmode_vpn`, `vpn_internal_tun`; `ui/dialog_basic_settings.cpp:100-180` switch handler.

- **System Proxy mode — lightweight, no admin after setup:**
  - HOW: On start, nekoray calls OS API to set HTTP/SOCKS proxy to `127.0.0.1:<socks_port>` (default 2080, mixed). Windows: `WinINet` `InternetSetOption` + registry `HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings` (`ProxyEnable`, `ProxyServer`, `ProxyOverride` for bypass). Linux: sets `http_proxy`/`https_proxy` env for launcher + writes `gsettings` for GNOME (`org.gnome.system.proxy`) or `kcmshell` for KDE if available; otherwise leaves env only. PAC not generated — manual bypass via Routing rules only. On exit, clears proxy (unless “Keep System Proxy on Exit” checked).
  - FILE: `sys/sys_proxy.cpp:1-200` Windows/Unix branches; `main/main.cpp:80-120` startup proxy set; `db/DataStore.cpp:400-500` proxy port logic.
  - Use when: conserve battery, only browser traffic needs proxy, avoid TUN driver issues (AppImage `linux-x64.AppImage` BUG: cannot use TUN — doc notes).

- **TUN mode with sing-box `tun` inbound — the deep path:**
  - HOW: When `vpn_internal_tun && spmode_vpn`, `ConfigBuilder::WriteVPNConfig()` generates a dedicated VPN JSON from template `res/neko/vpn/sing-box-vpn.json` (fallback `vpn/sing-box-vpn.json` if user overrides). Template placeholders replaced: `%MTU%`, `%STACK%`, `%TUN_NAME%`, `%STRICT_ROUTE%`, `%FINAL_OUT%`, `%DNS_ADDRESS%` (`BOX_UNDERLYING_DNS=223.5.5.5`), `%FAKE_DNS_INBOUND%`, `%PORT%`, `//%SOCKS_USER_PASS%`, `//%IPV6_ADDRESS%`, `//%PROCESS_NAME_RULE%`, `//%CIDR_RULE%`. Result written to temp `sing-box-vpn.json` and sing-box launched with `tun` inbound `{ "type":"tun","interface_name":"%TUN_NAME%","inet4_address":"172.19.0.1/30","mtu":%MTU%,"stack":"%STACK%","auto_route":true,"strict_route":%STRICT_ROUTE% }` plus `route.auto_detect_interface=true`.
  - FILE: `db/ConfigBuilder.cpp:900-1050` `WriteVPNConfig()`; `res/neko/vpn/sing-box-vpn.json:1-80`; `go/cmd/nekobox_core/box.go` TUN handling.
  - Inbound set: Also keeps `mixed-in` (`socks+http`) on 127.0.0.1 plus `tun-in` capture; DNS inbound `dns-in` if fakeIP enabled.

- **gVisor (`gvisor`) vs System (`system`) stack:**
  - HOW: Setting `Preferences → TUN Settings → Stack` = `gvisor` (default) or `system`. Maps to sing-box `tun.stack`: `gvisor` = userspace netstack (no raw sockets, works without extra caps on Linux, slightly higher latency); `system` = OS network stack via `tun` device (requires `CAP_NET_ADMIN` / admin, lower overhead, better `process_name` accuracy). Template `%STACK%` comes from `Preset::SingBox::VpnImplementation.value(vpn_implementation)` enum. Changing requires nekoray restart.
  - FILE: `db/Preset.h:20-40` `VpnImplementation` enum; `db/ConfigBuilder.cpp:1000` `.replace("%STACK%",...)`; sing-box docs `configuration/inbound/tun`.
  - Which to use: Default `gvisor` for compatibility; switch to `system` for gaming/UDP-heavy apps or if `process_name` routing fails.

- **MTU, strict_route, IPv6:**
  - HOW: MTU default 9000 in UI (`vpn_mtu`), replaceable `%MTU%`; lower to 1500 if VPN drops large packets. `strict_route` true forces `auto_route` to insert high-priority routes that override system default (needed for full-tunnel). `vpn_ipv6` toggles `//%IPV6_ADDRESS%` insertion (`fdfe:dcba:9876::1/126`). On Windows, `genTunName()` returns `nekoray-tun`; on Linux `nekoray-tun` or `tun0`.
  - FILE: `db/ConfigBuilder.cpp:950-1010`; `db/DataStore.h:50-70`.

- **Service mode on Linux (systemd privileged helper):**
  - HOW: Linux TUN needs root. nekoray offers two launch modes: (a) `pkexec` prompt per start (default portable zip), (b) **Service Mode** daemon. Check `Preferences → Basic Settings → Service Mode` writes `systemd` unit `nekoray.service` (or `nekobox.service`) to `~/.config/systemd/user/` or `/etc/systemd/system/` calling `nekobox_core` as service listening on `127.0.0.1:<grpc_port>`. GUI then connects via gRPC without per-start sudo. `WriteVPNLinuxScript()` generates `nekoray_vpn.sh` with `ip tuntap add`, `ip addr add`, `ip route add` commands for `system` stack fallback.
  - FILE: `sys/linux_service.cpp:1-200`; `db/ConfigBuilder.cpp:1050-1150` `WriteVPNLinuxScript()`; `docs/Run_Linux.md:40-60` Bundle vs System note; `res/neko/vpn/linux_service.sh`.
  - AppImage limitation: TUN broken in AppImage sandbox (no `CAP_NET_ADMIN` delegation) — doc explicitly “BUG较多，无法使用Tun模式”.

- **Windows TUN (Wintun / sing-box native):**
  - HOW: On Windows, sing-box `tun` uses `wintun.dll` (bundled in `windows64.zip`). No `tun` kernel module needed. Requires running nekoray as Administrator once to install wintun driver; subsequent runs can be non-admin if TUN already installed but `strict_route` still needs admin. Symlink fix: if `tun` creation fails with `CreateFile \\.\Global\NekorayTun`, check Windows Defender blocking wintun.
  - FILE: `sys/win_tun.cpp:1-150`; `res/wintun.dll` in release zip; `docs/Run_Windows.md` (implicit via README).

---

## 7. DNS

- **Architecture — sing-box DNS with server + rules + fakeip:**
  - HOW: `ConfigBuilder::BuildConfigSingBox()` builds `dns` object once per `BuildConfig()` call. Structure: `{"servers":[ dns-remote, dns-direct, dns-block, dns-fake?, dns-local ], "rules":[ domain rules → server ], "fakeip":{...}, "independent_cache":true, "final":"dns-direct|proxy" }`. `use_dns_object` override bypasses all auto logic and inserts user JSON verbatim.
  - FILE: `db/ConfigBuilder.cpp:350-550` DNS assembly; sing-box `configuration/dns` schema.

- **System vs TUN DNS split:**
  - HOW: `dnsServers` always includes 5 entries: (1) `dns-remote` → `remote_dns` (e.g., `https://dns.google/dns-query` or `tls://8.8.8.8`) with `detour: <proxy_tag>` + `address_resolver: dns-local` + `strategy: remote_dns_strategy` (prefer_ipv4/ipv4_only/...); (2) `dns-direct` → `direct_dns` (e.g., `223.5.5.5` or `local`) with `detour: direct`; (3) `dns-block` → `rcode://success` (NXDOMAIN sink for blocked domains); (4) `dns-fake` → `fakeip` only if `fake_dns && vpn_internal_tun && spmode_vpn`; (5) `dns-local` → `BOX_UNDERLYING_DNS=223.5.5.5` with `detour: direct` — guaranteed bootstrap resolver (underlying 100% working DNS). `make_rule()` links domain lists to DNS rules: `domainListDNSRemote → dns-remote`, `domainListDNSDirect → dns-direct`.
  - FILE: `db/ConfigBuilder.cpp:360-450`; `db/Routing.h:10-20` `remote_dns`, `direct_dns`, `remote_dns_strategy`, `direct_dns_strategy`, `dns_final_out`, `dns_routing`.
  - Common presets: `remote_dns = tls://8.8.8.8` or `https://dns.google/dns-query`, `direct_dns = 223.5.5.5` (AliDNS) or `https://223.5.5.5/dns-query`. `localhost` value invalid since 4.x — “DNS 不再兼容 localhost” changelog.

- **DNS strategies (`remote_dns_strategy` / `direct_dns_strategy`):**
  - HOW: Dropdown values `""` (default), `prefer_ipv4`, `prefer_ipv6`, `ipv4_only`, `ipv6_only` map to sing-box `strategy` field. Controls A/AAAA query ordering. Set `ipv4_only` on `dns-direct` if ISP IPv6 broken.
  - FILE: `ui/dialog_routing_settings.cpp:80-120` strategy combo; sing-box `configuration/dns/server`.

- **DNS routing flag (`dns_routing`) + domainListDNS*:**
  - HOW: When `dns_routing=true`, domain Simple Route entries ALSO emit DNS rules (so `geosite:cn` domains resolve via `dns-direct`). When false, only explicit DNS lists do. Internally `DOMAIN_USER_RULE` vs `DOMAIN_USER_RULE_DNS` macros split lists. Bug #1487: `dns_final_out` any-fix ensures fallback DNS correctly detours.
  - FILE: `db/ConfigBuilder.cpp:340-420`; `db/Routing.h` `dns_routing` bool.

- **FakeIP (`fake_dns`):**
  - HOW: Toggle `Preferences → Basic Settings → Fake DNS` (only enabled with TUN internal). When on, allocates `198.18.0.0/15` + `fc00::/18` fake addresses for tun-in inbound. DNS rules add `{"inbound":"tun-in","server":"dns-fake"}` so tun-captured UDP 53 returns fake IPs immediately without upstream RTT. Routing reverse-maps fake IP to real domain via sing-box `fakeip` store. Benefit: faster first packet, no DNS leak. Caveat: Breaks apps doing manual DNS (DoH browsers) — changelog warns “如果在 TUN 模式下出现问题，建议改用其他类型的 DNS, DNS local 类型改为 sing-box 实现”.
  - FILE: `db/ConfigBuilder.cpp:380-420` fakeip block; `db/DataStore.h` `fake_dns`; `res/neko/vpn/sing-box-vpn.json` fakeip inbound.
  - Disable if: `ping` to fake range fails, or `nslookup` returns `198.18.x.x` for foreign domains.

- **Built-in DNS rules:**
  - HOW: Hardcoded appended rules: `{"domain_suffix":".lan","server":"dns-block"}` (mDNS LAN domains blocked from upstream), optional `dns_routing` global rule, and fakeip tun-in rule. Independent cache true reduces repeated latency.
  - FILE: `db/ConfigBuilder.cpp:470-520`.

- **Advanced DNS object override:**
  - HOW: Check `Use DNS Object` in Routing Settings → textarea `dns_object` (full sing-box `dns` JSON). When enabled (`use_dns_object=true`), auto_servers/rules discarded: `dns = JSON.parse(dns_object)` verbatim. Allows ECH, multiple upstreams, fallback logic, `disable_cache`, etc. Same as sing-box docs example.
  - FILE: `db/ConfigBuilder.cpp:530-540` `if(use_dns_object) dns = QString2QJsonObject(dns_object)`.

- **DNS in TUN VPN template:**
  - HOW: `sing-box-vpn.json` contains separate `dns` section for TUN mode with `%DNS_ADDRESS%` placeholder (filled `BOX_UNDERLYING_DNS`) and `%FAKE_DNS_INBOUND%` (either `tun-in` or `empty` string disabled). Separate from main `dns` object but same generation logic.
  - FILE: `res/neko/vpn/sing-box-vpn.json:20-40`.

---

## 8. Implementation Details — Config Generation, Qt GUI, Hotkey, Tray

- **Config generation path `db/ConfigBuilder` — the heart:**
  - HOW: `class ConfigBuilder` in `db/ConfigBuilder.h` with static methods `BuildConfig(ProxyEntity, flags)`, `BuildConfigSingBox()`, `BuildStreamSettingsSingBox()`, `WriteVPNConfig()`, `WriteVPNLinuxScript()`. Call sites: `main/main.cpp:200-300` on “Start”, `ui/mainwindow.cpp:300-400` on profile switch, `sub/speedtest.cpp` on test (`forTest=true`). Outputs `status->result->coreConfig` (`QJsonObject`) → serialized to `config/sing-box.json` → fed to `nekobox_core` via gRPC `Start` call → sing-box `box.New(context, options)`.
  - FILE: `db/ConfigBuilder.h:1-40`; `db/ConfigBuilder.cpp:1-1200` (full routing+DNS+inbounds+outbounds+tun).
  - Steps inside `BuildConfigSingBox()` (summary of ~900 lines):
    1. Init `status->result->coreConfig["log"]={"level":log_level}`.
    2. If `forTest` skip user rules; else resolve `geosite`/`geoip` paths from `DataStore.assetDir`.
    3. `make_rule()` lambda defines domain↔sing-box mapping.
    4. Build `dns` object (Section 7) → `coreConfig["dns"]=dns`.
    5. Build `inbounds`: `mixed-in` (socks+http), `tun-in` if TUN, `dns-in` trap.
    6. Build `outbounds`: `proxy` (from bean `BuildCoreObjSingBox()`), `direct`, `block`, `dns-out`, external core mappings (naive socks detour), chain detours.
    7. Build `route.rules`: `QJSONARRAY_ADD` custom global + custom per-set + user domain/ip rules + TUN process/cidr rules + multicast block (`224.0.0.0/3`).
    8. Insert `route.geoip/geosite` paths, `auto_detect_interface`, `final`.
    9. If TUN internal, call `WriteVPNConfig()` to emit `sing-box-vpn.json`.
    10. Apply custom overrides: if `custom_route_global`/`routing.custom` have `prepend`/`append` keys (4.0.1), splice before/after.

- **Bean dispatch — protocol to JSON:**
  - HOW: Each protocol has `*Bean.h/.cpp` subclass of `AbstractBean` with `BuildCoreObjSingBox()` virtual. `ConfigBuilder` calls `entity->bean->BuildCoreObjSingBox(status)` which returns `QJsonObject` outbound. External protocols (Naïve, HY2/TUIC external) return indirection: allocate random free port, write external binary config, start process via `ExternalCoreManager`, then return `{"type":"socks","server":"127.0.0.1","server_port":port}` as stand-in.
  - FILE: `fmt/beans/*.cpp` (ShadowSocks, VMess, VLESS, Trojan, QUIC/hysteria, Naive, Socks, Http, Custom); `fmt/AbstractBean.h:1-50`; `db/ExternalCoreManager.h`.
  - Extensibility: Adding new protocol = new Bean + parser in `fmt/*_fmt.cpp` + UI form in `ui/dialog_edit_profile.cpp` + subscription parser tweak.

- **Qt GUI files — where UI lives:**
  - HOW: `main/main.cpp` entry, `main/MainWindow.h/.cpp` central `QMainWindow` with `QTableView` profiles, `QTabBar` groups, `QSystemTrayIcon`, menus. `ui/dialog_*` per feature: `dialog_basic_settings.cpp` (core, proxy ports, TUN, service mode), `dialog_routing_settings.cpp` (Simple Route + Custom Route JSON editors + Route Sets), `dialog_edit_profile.cpp` (per-protocol form), `dialog_group.cpp` (subscription/group manager), `dialog_speedtest.cpp`, `dialog_hotkey.cpp`, `dialog_about.cpp`. `ui/widget/AutoCompleteTextEdit.cpp` for geosite completion. `res/qss/` Qt stylesheets for Fusion fix (fork unified design language).
  - FILE: `main/main.cpp:1-150`; `main/MainWindow.cpp:1-800`; `ui/*.cpp` (~20 dialogs); `res/qss/fusion_light.qss` + `fusion_dark.qss` (fork patched disappearing borders).
  - Responsive design (fork 4.1.0): Added `:hover`/`:pressed` qss states for buttons, decluttered header, footer exit-IP flag.

- **Hotkey handling via `QHotkey`:**
  - HOW: Global hotkeys registered via third-party `Skycoder42/QHotkey` (`QHotkey-master/` submodule + `libs/`). `sys/HotkeyManager.cpp` wraps `QHotkey` to bind shortcuts: default `Ctrl+Shift+P` (show/hide), `Ctrl+Shift+R` (restart proxy), plus configurable in `Preferences → Hotkey`. QHotkey uses `RegisterHotKey` (Win) / `XGrabKey` (Linux X11) / Wayland fallback via `xdg` portal (limited). Known Linux Wayland hotkey not capturing when window unfocused — doc suggests keep X11 session.
  - FILE: `sys/HotkeyManager.cpp:1-120`; `QHotkey-master/QHotkey/qhotkey.cpp`; `CMakeLists.txt:40-60` `QHotkey` find_package; `docs/Run_Linux.md` Wayland note.
  - Customization: `Preferences → Hotkey` dialog stores `QKeySequence` in `DataStore.hotkeys` JsonStore; `MainWindow::registerHotkeys()` rebinds on change.

- **Tray integration via `QSystemTrayIcon`:**
  - HOW: `MainWindow` owns `QSystemTrayIcon *tray` with context menu `QMenu` items: Show/Hide, System Proxy/TUN toggle, Route set submenu, Groups submenu, Start/Stop, Quit. Double-click tray toggles window. Icon theme adapts to light/dark (`res/icons/tray_light.png` vs `tray_dark.png` — fork adds unified icons). Linux needs `libappindicator`/`StatusNotifierItem` for tray to show under GNOME Wayland (else fallback to `xembedsniproxy`). “Close to tray” option intercepts `closeEvent` → `hide()` + `tray->showMessage()`.
  - FILE: `main/MainWindow.cpp:100-300` tray setup; `main/tray_icon.cpp`; `res/icons/` assets; `sys/linux_tray_fix.sh`.

---

## 9. Other Features — Groups, Speedtest, Backup/Restore, Updaters

- **Group management — subscriptions vs manual groups:**
  - HOW: Top `QTabBar` = groups (`NekoGroup` / `Group` entity). Two types: `MANUAL` (local profiles, drag-drop reorder) and `SUBSCRIPTION` (URL + interval +UA, auto-fetched). Create via `Preferences → Groups → New Group` or fork `+` button next to tab bar. Fields: Name, Type (Manual/Subscription), URL, User-Agent (default `nekoray/<ver>`), Update Interval (minutes), Proxy chain group? Archiving toggles. Group context menu: Update Subscription, Export All, Copy All Links, Delete Duplicates, Sort.
  - FILE: `db/Group.h` `GroupType`; `ui/dialog_group.cpp:1-300`; `sub/subscription_updater.cpp:1-200`; `AliShafiee2003` fork adds `+` quick-add UX.
  - Subscription flow: `GroupUpdater::update(Group)` → `QNetworkRequest` GET (ignore TLS errors if `ignoreTLS` set) → `subscription_parser` → diff vs existing (by `bean->uniqueId` = host:port+uuid) → add new, remove stale if `removeUnavailable` enabled, optionally filter duplicates.

- **Speedtest — TCP Ping vs URL Test (RTT vs true latency):**
  - HOW: Two modes on toolbar or `Server → Current Group →` menu:
    - **Tcp Ping** (`TCP Ping`): Opens `QTcpSocket` to `host:port` of each profile, measures `connect()` time (TCP handshake RTT) via `QElapsedTimer`. Fast, no proxy traffic, but inaccurate for reality-delayed protocols (Hysteria QUIC not probed, VMess with WS may handshake faster than real HTTP). Shows `ms` in table `Latency` column; unreachable → `Timeout` or `-1`.
    - **Url Test** (`Url Test` / RTT test): More accurate — launches temporary sing-box instance per profile (`forTest=true` config) with outbound = tested profile + `direct` for DNS, then issues `GET http://www.gstatic.com/generate_204` (or custom URL in `Preferences → Speedtest → Test URL`) through the proxy. Measures time to first byte / HTTP 204. Fork auto-sorts by latency after finish; original 4.0.1 added URL Test button to toolbar.
  - FILE: `sub/speedtest.cpp:1-300` both branches; `db/ConfigBuilder.cpp:50-100` `forTest` flag skips routing; `ui/mainwindow.cpp:500-600` test trigger; `4.0.1` notes “延迟测试改为默认测试 RTT，不再兼容 truehttp”.
  - How to choose: Use Tcp Ping to quickly filter dead nodes; use Url Test to rank usable nodes (catches TLS/Reality failures Tcp Ping misses). `rtt` is default since 4.x; `truehttp` string deprecated.

- **Backup / Restore — config directory portability:**
  - HOW: `Preferences → Basic Settings → Backup/Restore` or `File → Backup`. Writes zip/tar of entire config dir (`~/.config/nekoray/` on Linux, `%APPDATA%/nekoray/` or `-appdata` custom path on Windows). Contents: `config.db` (SQLite profile/group dump via `db/` JsonStore serialized), `routes/*.json`, `assets/geoip.db`, `sing-box.json` last generated, `groups.json`. Restore = stop core → unzip over dir → reload `DataStore`. Portable mode: run with `-appdata` flag (Desktop shortcut adds it for DEB install) to keep config beside exe (isolates from installed version).
  - FILE: `sys/backup.cpp:1-200`; `db/DataStore.cpp:500-600` JsonStore persistence; `main/main.cpp:20-40` `-appdata` arg parsing (`RunFlags.md`).
  - Run Flags doc: `docs/RunFlags.md` lists `-appdata <path>`, `-debug`, `-help`.

- **Update subscriptions — auto + manual:**
  - HOW: Manual: `Server → Current Group → Update Subscription` (or per-group right-click → Update). Auto: `Preferences → Groups → Auto Update Interval` minutes (default 1440 = 24h, airport suggestion 1440). Background `QTimer` per subscription group fires `GroupUpdater::update`. Option `Ignore TLS Errors` toggles `QSslSocket::ignoreSslErrors`. On success log: “订阅请求完成，导入 X 个配置” (toast + log box). Duplicate filtering + regex removal of unavailable nodes available via Actions menu (fork).
  - FILE: `sub/subscription_updater.cpp:1-150` timer; `ui/dialog_group.cpp:150-250` UI.
  - Tip: Airport `Clash` YAML subscription works directly; no conversion needed. Base64 `vmess://` list also auto-detected.

- **Xray assets updater (geoip/geosite db):**
  - HOW: `Preferences → Basic Settings → Update Assets` or toolbar `Xray Assets Updater`. Downloads `geoip.dat`/`geosite.dat` (Xray) or `geoip.db`/`geosite.db` (sing-box srs) from `https://github.com/SagerNet/sing-geoip` / `sing-geosite` or `Loyalsoldier/v2ray-rules-dat` depending on core. Stores to `assets/` then referenced as `route.geoip.path`/`geosite.path` in generated config. 4.0.1 keeps same fetcher but path is `*.db` preferred (sing-box). Fork inherits.
  - FILE: `sys/asset_updater.cpp:1-200`; `db/ConfigBuilder.cpp:820-880` `geoip = DataStore.assetDir + "/geoip.db"` insertion; `res/geodata/` bundled fallback.

- **Fork-exclusive extras (AliShafiee2003 4.1.0):**
  - HOW: Header decluttered (fewer toolbar separators), `.qss` fusion border fix (`QPushButton { border: 1px solid palette(mid); }` restores missing borders in Windows Fusion), status bar bottom shows **Exit IP + Country Name + Country Flag** via `https://ipinfo.io`/`ip.sb` fetch after proxy start (flag emoji from `country_code` uppercase → regional indicator). Smart auto-sort after Url Test hooks `speedtestFinished()` → `sortByLatency()`. Regex removal: `Actions → Remove Unavailable` uses `QRegularExpression` on `testResult` field (`timeout`/`-1` match).
  - FILE: `ui/mainwindow.cpp` fork diff (581 commits vs 528 orig); `fix_ui.py` + `fix_ui_svg.py` scripts in fork root; `main/status_bar.cpp:80-150` exit-IP fetch.

---

## 10. Platforms & Requirements

- **Windows:**
  - HOW: Primary platform. Portable ZIP `windows64.zip` (main) contains `nekobox.exe` (4.0.1 renamed from `nekoray.exe`) + `nekobox_core.exe` + `wintun.dll` + `geo*.db` + Qt DLLs (if bundle) — unzip and run. Also `windows7-x64.zip` legacy for Win7/8.1 using Qt 5.15 + older wintun (last version for Win7, per wiki). No installer — manual copy. MSVC++ Redist `vc_redist.x64.exe` required if missing `VCRUNTIME140.dll` / `MSVCP140.dll`. Windows 10+ amd64 only since 4.x (changelog “请 Win7 和 MacOS 用户彻底放弃本软件，已不支持这些系统”). Win7 users stay on 3.26 portable or fork’s 4.1.0 still bundles Qt6 (may fail on Win7 — fork advises 3.26 base retains compat).
  - FILE: `README.md` Download section; Wiki `Installation package description`; `4.0.1` assets list `nekoray-4.0.1-2024-12-12-windows64.zip`.

- **Linux:**
  - HOW: Three package shapes:
    - `debian-x64.deb` — Debian/Ubuntu amd64 deb, installs to `/usr/bin/nekoray` + `.desktop` (with `-appdata` for isolated config). `sudo apt install ./nekoray-*-debian-x64.deb`.
    - `linux64.zip` / `linux-x64.zip` — generic portable (mainly maintained). Unzip; choose runner: `./nekoray` (system Qt 5.12-5.15 must be installed + `libxcb-xinerama0`) or `./launcher` (bundle prebuilt Qt, for distros lacking correct Qt). Both support TUN except AppImage.
    - `linux-x64.AppImage` — universal AppImage (`chmod +x ...AppImage`) but **TUN broken** (BUG较多，无法使用Tun模式 — wiki note).
    - AUR: `nekoray` (stable), `nekoray-git` (git HEAD) via `yay -S nekoray`; `archlinuxcn` also hosts binary `nekoray` for ArchCN users. Scoop also once listed (`scoop install nekoray`).
  - FILE: Wiki `Installation-package-description.md:1-30`; `docs/Run_Linux.md:1-81` deb/arch/AppImage/system vs bundle; `aur.archlinux.org/packages/nekoray` PKGBUILD deps `qt5-base qt5-svg qt5-tools protobuf yaml-cpp zxing-cpp`.
  - Runtime deps Debian/Ubuntu: `libqt5widgets5 libqt5network5 libqt5svg5 libxcb-xinerama0` (+ `libprotobuf` `libyaml-cpp` `libzxing`). Bundle launcher ships Qt inside so only `libxcb-xinerama0` needed; System runner needs distro Qt.
  - Arch deps from AUR nekoray-qt6 `4.0.1-1`: `qt6-base qt6-svg qt6-tools abseil-cpp openssl protobuf yaml-cpp zxing-cpp` + `sing-geoip-db`/`sing-geosite-db` optional.

- **No macOS official:**
  - HOW: No darwin build in CI, no `macos-*.zip` asset, docs say “请…MacOS 用户彻底放弃本软件”. Code has no `Q_OS_MAC` tunnel path; sing-box TUN on darwin needs `utun` driver not wired. Community reports running Linux build under VM or using `MatsuriDayo/nekoray` under Rosetta fails due to Qt 6.7 deps. Recommended alternatives per 4.0.1 README: airport users → `Clash Verge Rev` / `flclash` / `mihomo-party`; Xray users → `v2rayN` (via Wine) or native `ClashX`.
  - FILE: `README.md` 4.x changelog bullet; `.github/workflows/build-nekoray-cmake.yml` matrix only `windows-latest` + `ubuntu-22.04`.

- **Arch support:**
  - HOW: Official releases only `x64`/`amd64`. ARM (`aarch64`) via AUR build from source or community fork `berand-xu/nekoray` (ARM CI). `libs/build_go.sh` supports `GOARCH=arm64` but no prebuilt binary.
  - FILE: `libs/build_go.sh:2-10` `GOARCH` switch; GitHub Issues ARM requests.

---

## 11. Repo Stats, Build Instructions & File Map

- **Repo stats (verified Aug 2026 via GitHub API + DeepWiki):**
  - HOW: `MatsuriDayo/nekoray` created 2022-05-03, archived 2025-03-17 (read-only banner), ~15.4k stars (search cache 15453 / direct 15443 / badge 15303 variance due to API sync lag), ~1.5k forks (1503), 217 open issues (211 after archive pruning), 76 releases (latest `4.0.1` 2024-12-12), 528 commits, 40 contributors (top `arm64v8a` 428, `purofle` 15, `xchacha20-poly1305` 11, `Misaka-blog` 8), primary language C++82.2%+CSS8.8%+Go3.9%+CMake3%+Shell1.8%, license GPL-3.0, default branch `main`, last push 2024-12-12 08:25 UTC.
  - HOW fork: `AliShafiee2003/nekoray` created 2026-02-21 as fork, 581 commits (53 by `AliShafiee2003` on top of 428 upstream), 23 stars, 3 forks, 0 open issues, main branch, retains GPL-3.0, file tree adds `fix_ui.py`, `img.png/img2.png` screenshots, `build_log*.txt`. Version string `4.1.0` (was `3.26` base + sing-box `1.9.7-neko1`).
  - FILE: GitHub API `/repos/MatsuriDayo/nekoray`; `/repos/AliShafiee2003/nekoray`; `AliShafiee2003/README.md` “Bumped version to 4.1.0”.

- **Build instructions — prerequisites:**
  - HOW: Per `docs/Build_Core.md`, `docs/Build_Windows.md`, `docs/Build_Linux.md`, DeepWiki `Build Instructions`:
    - Common: `Git`, `CMake 3.16+` (3.15 minimum per DeepWiki, 3.5 in `CMakeLists.txt` min), `Ninja` (recommended), `Bash`, `Go 1.19+` (tested to 1.21 for sing-box 1.9.x), C++17 compiler (`MSVC 2019/2022` on Win, `GCC/Clang` with C++17 on Linux).
    - Windows: `Visual Studio 2019/2022` with Desktop C++ workload, `Qt 6.5.x` SDK (MSVC2019 x86_64 bundle from `MatsuriDayo/nekoray_qt_runtime` releases) — add `bin` to PATH; alternative `Qt 5.15.2` official (known mem leak). `libs/download_qtsdk_win.sh` automates bundle fetch.
    - Linux: Qt `5.12.x` or `5.15.x` dev packages `qtbase qtbase5-dev qtsvg qttools qtx11extras` (Qt6 via `qt6-base` for 4.x), plus system libs `protobuf protobuf-compiler yaml-cpp libyaml-cpp-dev zxing-cpp libzxing-dev` (or build via `libs/build_deps_all.sh`).
  - FILE: `CMakeLists.txt:1-5` `cmake_minimum_required(VERSION 3.5)`; `docs/Build_Linux.md:1-20` preconditions; `docs/Build_Windows.md:15-35` Qt bundle URLs.

- **Build instructions — Go core (nekobox_core + updater/launcher):**
  - HOW: Directory sibling layout expected after `libs/get_source.sh`: `../nekoray` (this repo), `../sing-box`, `../sing-box-extra`, `../...` per commit pins in `libs/get_source.sh`. Steps:
    1. `bash libs/get_source.sh` — clones/checkouts each repo at pinned commit hashes (read from `libs/source.json` if present).
    2. `GOOS=windows GOARCH=amd64 bash libs/build_go.sh` (Linux: omit GOOS/ARCH or `GOOS=linux GOARCH=amd64`). Script does: `CGO_ENABLED=0 go build -tags with_quic,with_wireguard,with_ech,with_utls -ldflags "-s -w" -o nekobox_core ./go/cmd/nekobox_core`; similarly `updater`, `launcher` helpers. Built binaries placed in `deploy/` or repo root.
    - Non-official builds skip `updater`/`launcher` (auto-update disabled).
    - Supported `GOOS/GOARCH` combos enumerated in `build_go.sh:5-15` (`windows/darwin/linux x amd64/arm64`).
  - FILE: `docs/Build_Core.md:1-24`; `libs/build_go.sh:1-28` (`CGO_ENABLED=0` line 16); `libs/get_source.sh:1-50`.

- **Build instructions — C++ dependencies (protobuf, yaml-cpp, zxing-cpp, gRPC, QHotkey):**
  - HOW: If distro packages satisfy version, you can use system packages (set `-DNKR_NO_EXTERNAL=OFF` default). Otherwise build from source:
    - `bash ./libs/build_deps_all.sh` — builds into `libs/deps/built/` (CMake prefix). Builds `protobuf` (static), `yaml-cpp`, `zxing-cpp`, `gRPC` (with `abseil`), plus bundled `QHotkey`. Takes 10-30 min. Result is Release-only libs (yaml-cpp note “only Release is built”).
    - `CMakeLists.txt` `NKR_LIBS=./libs/deps/built` appended to `CMAKE_PREFIX_PATH`; set `-DNKR_DISABLE_LIBS=ON` to force system libs, `-DNKR_LIBS=<custom>` to point elsewhere.
  - FILE: `docs/Build_Linux.md:30-50` deps all; `CMakeLists.txt:35-70` `find_package(yaml-cpp CONFIG REQUIRED)`, `ZXing`, `Protobuf`, `gRPC`.

- **Build instructions — C++ GUI (nekobox executable):**
  - HOW:
    - Linux system Qt:
      ```shell
      mkdir build && cd build
      cmake -GNinja -DCMAKE_BUILD_TYPE=Release ..
      ninja
      # output: ./nekobox
      ```
    - Windows with explicit Qt path:
      ```shell
      mkdir build && cd build
      cmake -GNinja -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH=D:/Qt/6.5.0/msvc2019_64 -DQT_VERSION_MAJOR=6 ..
      ninja
      windeployqt nekobox.exe
      ```
    - Variant for AUR package: add `-DNKR_PACKAGE=ON` — flips `NKR_LIBS` to `./libs/deps/package` and makes app use XDG `~/.config/nekoray` + disables auto-update (package manager owns updates).
    - Config options full list (from `docs/Build_Linux.md` + `CMakeLists.txt`):
      | CMake param | Default | Meaning |
      |---|---|---|
      | `QT_VERSION_MAJOR` | `5` | Qt major 5 or 6 |
      | `NKR_NO_EXTERNAL` | OFF | Exclude all external C/C++ deps (sets next 4) |
      | `NKR_NO_YAML` | OFF | Exclude yaml-cpp |
      | `NKR_NO_ZXING` | OFF | Exclude zxing-cpp |
      | `NKR_NO_QHOTKEY` | OFF | Exclude QHotkey |
      | `NKR_NO_GRPC` | OFF | Exclude gRPC |
      | `NKR_PACKAGE` | OFF | Build package version for AUR (XDG + no auto-update) |
      | `NKR_LIBS` | `./libs/deps/built` | Deps search dir appended to `CMAKE_PREFIX_PATH` |
      | `NKR_DISABLE_LIBS` | OFF | Disable `NKR_LIBS` search |
  - FILE: `docs/Build_Windows.md:55-70`; `docs/Build_Linux.md:20-60`; `CMakeLists.txt:15-90` options.
  - Troubleshooting: missing `yaml-cpp` → install `libyaml-cpp-dev` or run `build_deps_all.sh`; `Could not find Qt` → check `CMAKE_PREFIX_PATH` points to Qt `lib/cmake`; Go build fails on `missing go` → install Go 1.19+; `windeployqt` not found → add Qt `bin` to PATH; AppImage TUN fail is expected.

- **Build outputs & packaging:**
  - HOW: CI workflow `.github/workflows/build-nekoray-cmake.yml` builds matrix `windows-latest` (Qt6 + MSVC) and `ubuntu-22.04` (Qt5 container + clang). Artifacts zipped as `nekoray-<ver>-windows64.zip`, `nekoray-<ver>-linux64.zip`, `nekoray-*-debian-x64.deb` (built via `linuxdeployqt`/`appimagetool`), `nekoray-*-AppImage`. `nekobox_core` + `nekobox` + `launcher` + `assets` + `licenses` packed.
  - FILE: `.github/workflows/build-nekoray-cmake.yml:1-150`.

- **File map — top-level layout (key paths):**
  - HOW: From fork tree (581 commits, same as upstream + `fix_ui*`):
    - `3rdparty/` — vendored `yaml-cpp`, `zxing-cpp` sources (if `NKR_NO_*` off they’re built).
    - `QHotkey-master/` — hotkey submodule.
    - `cmake/` — `MyProto.cmake` gRPC proto generation, `Find*.cmake`.
    - `db/` — **core** — `ConfigBuilder.h/.cpp` (900+ lines), `DataStore.h/.cpp` (JsonStore global prefs), `ProxyEntity.h/.cpp`, `Group.h/.cpp`, `Routing.h/.cpp` (per-route-set JSON), `ExternalCoreManager.h/.cpp`, `TrafficLooper.cpp`.
    - `fmt/` — Bean classes `beans/*.cpp` (Socks/Http/ShadowSocks/VMess/VLESS/Trojan/QUIC/Naive/Custom), `*_fmt.cpp` link parsers (vmess, ss, clash...), `chain_fmt.cpp`.
    - `go/` — `go/cmd/nekobox_core/` gRPC server + sing-box wrapper, `go/cmd/updater/`, `go/cmd/launcher/`; sibling `sing-box` checkout outside repo.
    - `libs/` — build scripts `get_source.sh`, `build_go.sh`, `build_deps_all.sh`, `download_qtsdk_win.sh`, plus `libs/deps/` output.
    - `main/` — `main.cpp` entry, `MainWindow.h/.cpp`, `tray_icon.cpp`, `status_bar.cpp` (fork exit-IP), `proxy_table_model.cpp`.
    - `res/` — `neko/vpn/sing-box-vpn.json` template, `qss/*.qss`, `icons/`, `geodata/*.db` fallback.
    - `rpc/` — protobuf `libcore.proto`, generated `*.pb.cc/.h`.
    - `sub/` — `subscription.cpp`, `subscription_parser.cpp`, `clash_yaml.cpp`, `sip008_parser.cpp`, `speedtest.cpp`, `subscription_updater.cpp`.
    - `sys/` — `sys_proxy.cpp`, `linux_service.cpp`, `win_tun.cpp`, `HotkeyManager.cpp`, `asset_updater.cpp`, `backup.cpp`.
    - `ui/` — `dialog_basic_settings.cpp`, `dialog_routing_settings.cpp`, `dialog_edit_profile.cpp`, `dialog_group.cpp`, `widget/AutoCompleteTextEdit.cpp`, etc.
    - `docs/` — `Build_Windows.md`, `Build_Linux.md`, `Build_Core.md`, `Run_Linux.md`, `RunFlags.md`, `CustomRoute.md`.
    - `translations/` — `*.ts` i18n (zh-CN primary, en, fa, ja, ru in fork).
    - `test/` — unit tests for parsers.
    - `CMakeLists.txt` — 100+ lines, Qt detection, NKR options, `qt_add_executable`/`add_executable` branches.
  - FILE: `CMakeLists.txt:1-110`; `libs/get_source.sh:1-30` dir structure comment; GitHub tree view root listing.

---

## 12. References

- Repos: https://github.com/MatsuriDayo/nekoray (archived 2025-03-17) · https://github.com/AliShafiee2003/nekoray (fork, UI Enhanced Edition, 4.1.0)
- README credits cores: `v2fly/v2ray-core (<3.10)`, `Matsuri/v2ray-core (<3.10)`, `XTLS/Xray-core (3.10-3.26)`, `Matsuri/Xray-core (3.10-3.26)`, `SagerNet/sing-box`, `Matsuri/sing-box-extra`
- Releases: `3.26` stable, `4.0-beta3/4`, `4.0.1` (2024-12-12, sing-box 1.9.7-neko1, Qt 6.7.2) — release notes 4.X major changes
- Wiki: `Installation package description` (debian/AppImage/zip/win7), Home (2 pages)
- Docs: `docs/Build_Windows.md`, `docs/Build_Linux.md`, `docs/Build_Core.md`, `docs/Run_Linux.md`, `docs/RunFlags.md`
- DeepWiki: `Build Instructions` (prereqs Go1.19/CMake3.16/Ninja), `Building and Deployment` (Go track vs C++ track), `Routing and VPN Configuration`, `Configuration Generation` (BuildConfig flow), `External Core Protocols` (Naive/Hy2/TUIC)
- Issue #1537: discussion of 4.0.1 being outdated vs sing-box 1.11, custom core workaround for newer sing-box
- Build files: `CMakeLists.txt` (NKR_* options), `libs/build_go.sh` (CGO_ENABLED=0, tags), `libs/get_source.sh`
- Config generation: `db/ConfigBuilder.cpp` (~1100 lines, make_rule lambda, DNS/routing/TUN logic), `res/neko/vpn/sing-box-vpn.json` template
- GUI: `main/MainWindow.cpp`, `ui/dialog_routing_settings.cpp`, `sys/HotkeyManager.cpp` (QHotkey), tray via `QSystemTrayIcon`
- Protocols: `fmt/beans/*.cpp`, `fmt/*_fmt.cpp`, `sub/clash_yaml.cpp` (Hy2 port hop @xchacha20-poly1305)
- Platforms: `aur.archlinux.org/packages/nekoray`, `aur.archlinux.org/packages/nekoray-qt6 4.0.1-1` (deps list), Debian/Ubuntu deb notes, Scoop Extras
- Homepage expired: https://matsuridayo.github.io (states NekoBox/NekoRay archived)
- Coverage sites: https://nekoray.com/nekoray tutorial, https://blancvpn.com/help/NekoRay-windows-split-tunneling routing JSON examples, https://pixelscan.net/blog/nekoray-vpn-setup-review speedtest notes

> Verified 2026-08-30 via live fetch: original repo stars 15453/forks 1503/issues 217 (search cache) vs 15.4k displayed; fork 23 stars/3 forks/main branch; commit counts 528 orig / 581 fork; Qt 6.7.2, sing-box 1.9.7-neko1, package list per wiki + AUR.

