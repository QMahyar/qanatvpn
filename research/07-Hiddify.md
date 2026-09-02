# Hiddify App / Hiddify Next (hiddify/hiddify-app) — Extreme-Detail Research

> **Research date:** 2026-08-30  
> **Repos:** [`hiddify/hiddify-app`](https://github.com/hiddify/hiddify-app) (formerly `hiddify/hiddify-next`) · [`hiddify/hiddify-core`](https://github.com/hiddify/hiddify-core) · [`hiddify/hiddify-sing-box`](https://github.com/hiddify/hiddify-sing-box) (fork of [`SagerNet/sing-box`](https://github.com/SagerNet/sing-box)) · [`hiddify/ray2sing`](https://github.com/hiddify/ray2sing)  
> **Official site/docs:** [hiddify.com](https://hiddify.com) · [hiddify.com/app](https://hiddify.com/app/) · [hiddify.com/app/How-to-use-Hiddify-app](https://hiddify.com/app/How-to-use-Hiddify-app/) · [hiddify.com/app/URL-Scheme](https://hiddify.com/app/URL-Scheme/) · [hiddify.com/app/How-to-use-WARP-on-Hiddify-App](https://hiddify.com/app/How-to-use-WARP-on-Hiddify-App/) · Wiki: [hiddify/Hiddify-Manager Wiki](https://github.com/hiddify/Hiddify-Manager/wiki)  
> **License:** **Hiddify Extended GPL-3.0** — `GPL-3.0-only` + 7 additional conditions under GPL-3 §7 (`LICENSE.md:1-35`)  
> **Tech stack:** **Flutter 3.38.5 / Dart 3.10.4** (`pubspec.yaml:6-10`) + **Go sing-box core** via `libbox` gomobile/FFI · Riverpod · Drift (SQLite) · SharedPreferences · gRPC+protobuf  
> **Stats (2026-08-30):** **~32.4k ★**, **~3.0k forks**, **197 watchers**, **2,821 commits** on `main`, **743 commits** in `hiddify-core`, ~30-36 open issues, created 2023-05

---

## Table of Contents

1. [Overview](#1-overview)
2. [Supported Protocols — Deep Dive](#2-supported-protocols--deep-dive)
3. [Subscription Formats](#3-subscription-formats)
4. [Cores Matrix — sing-box 1.11+ Fork, Xray Dual-Core, ray2sing](#4-cores-matrix--sing-box-111-fork-xray-dual-core-ray2sing)
5. [Routing / Split Tunneling](#5-routing--split-tunneling)
6. [TUN vs Proxy](#6-tun-vs-proxy)
7. [DNS — FakeIP, DoH, Split DNS](#7-dns--fakeip-doh-split-dns)
8. [DPI Bypass — Reality, uTLS, Fragment, Warp](#8-dpi-bypass--reality-utls-fragment-warp)
9. [Other Features — Remote Profiles, ETag, Config Editor, Speed Test, Warp Pro, etc.](#9-other-features--remote-profiles-etag-config-editor-speed-test-warp-pro-etc)
10. [Platforms — Specific Notes](#10-platforms--specific-notes)
11. [Repo Stats, Build Instructions & File Map](#11-repo-stats-build-instructions--file-map)
12. [References](#12-references)

---

## 1. Overview

- **What is Hiddify App (Hiddify Next):**
  - A **multi-platform auto-proxy client** — tagline: *"Multi-platform auto-proxy client, supporting Sing-box, X-ray, TUIC, Hysteria, Reality, Trojan, SSH etc. It's an open-source, secure and ad-free"* (`README.md:1`, About sidebar)
  - How: Flutter UI layer (`lib/`) talks to Go proxy engine (`hiddify-core` / `hiddify-sing-box` via `experimental/libbox`) through gRPC + platform channels (mobile) / FFI (`lib/gen/hiddify_core_generated_bindings.dart`) on desktop — builds final sing-box JSON → hands to core `Box` (`hiddify-sing-box/box.go:1-120`) → routes TUN/proxy
  - Not a VPN provider — **client-only**, ships with zero nodes; all nodes come via subscription/profile imports (`hiddify://import/...`, clipboard, QR)
  - Previously named **Hiddify-Next**; repo URL still redirects (`github.com/hiddify/hiddify-next` → `hiddify-app`); assets still publish under both names (`Hiddify-Android-universal.apk`, `Hiddify-Linux-x64.AppImage`)

- **License — Hiddify Extended GPL-3.0 (`LICENSE.md:1-35`):**
  - Upstream is **GPL-3.0** verbatim (`LICENSE.md:40+`, FSF text) plus **7 additional conditions** under GPL-3 §7:
    - HOW: `LICENSE.md:1` header: *"Hiddify Extended GNU General Public License v3"*; lists Source Code Availability, Automated Release, Attribution, No Malware, Naming/Interface Restrictions, NonCommercial, ShareAlike
    - **Source availability:** any use → must publish fork on GitHub as fork of `hiddify/hiddify-app` and keep up-to-date with releases
    - **Automated release:** all releases must use GitHub Actions (enforced via `.github/workflows/`)
    - **Attribution:** credit Hiddify + link original license + document changes in README
    - **No malware:** prohibited
    - **Naming/UI restriction:** cannot publish to AppStore/Play/F-Droid/Microsoft with name/UI resembling Hiddify (blocks `Hiddify`, `Hidy*`, `Hiddy*`, `*Ify` clones) — stricter than vanilla GPL
    - **NonCommercial:** no selling/advertising without written consent (controversial extra restriction vs GPL freeness)
    - **ShareAlike:** remixes must be same license as fork of `hiddify/hiddify-app`
    - FILE: `LICENSE.md:1-15` additional conditions list; `hiddify-core/LICENSE.md:1` same header; `hiddify-sing-box` inherits upstream GPL-Other

- **Flutter/Dart + Go stack detail:**
  - **Flutter app (`pubspec.yaml:1-10`, `pubspec.yaml:6`):**
    - HOW: `name: hiddify`, `description: Cross Platform Multi Protocol Proxy Frontend.`, `version: 4.1.2+40102`, `sdk: ^3.10.4`, `flutter: ^3.38.5` — SDK version is **strictly required**, parsed by `Makefile` and `Dockerfile` via grep (`pubspec.yaml:7-10` comment: *"It is parsed/grep-ed by Makefile and Dockerfile to configure the build environment"*)
    - UI uses `hooks_riverpod 2.4.10` + `flutter_hooks 0.20.5` + `riverpod_annotation 2.3.4` for state, `drift 2.21.0` + `drift_flutter 0.2.1` + `sqlite3_flutter_libs 0.5.28` for profile/log DB, `shared_preferences 2.5.2` for settings, `slang 4.8.1` for i18n (10+ langs, `project.inlang/`), `dio 5.4.1` + `cupertino_http 2.0.1` + `dio_smart_retry 7.0.1` for networking, `ffi 2.1.2` + `ffigen 19.1.0` for desktop core, `go_router 16.2.4`, `window_manager 0.5.0` + `tray_manager 0.5.0` + `screen_retriever 0.2.0` + `launch_at_startup 0.5.1` (desktop window/tray), `mobile_scanner 7.2.0` + `qr_flutter 4.1.0` (QR), `app_links 6.4.0` + `win32 5.12.0` (deep links/URL scheme), `grpc 4.0.1` + `protobuf 5.0.0` + `fixnum 1.1.0` (core comms), `sentry_flutter 8.14.0` (crash), `installed_apps` git fork (`VB10/installed_apps`) for per-app list
    - FILE: `pubspec.yaml:12-130` deps; `pubspec.yaml:126-138` ffigen `name: HiddifyCoreNativeLibrary`, `output: lib/gen/hiddify_core_generated_bindings.dart`, `headers.entry-points: hiddify-core/bin/desktop.h`; `pubspec.yaml:140-190` flutter assets (tray icons, world_map.png, logo.svg, Shabnam font)
  - **Core bridging:**
    - HOW: `lib/hiddifycore/` + `lib/core/` abstracts `CoreInterface`; `lib/bootstrap.dart:1-40` wires `HiddifyCoreService`; mobile uses `Platform Channels` → `libbox` gomobile AAR/XCFramework, desktop uses FFI bindings generated by `ffigen` from `hiddify-core/bin/desktop.h` (`pubspec.yaml: ffigen`)
    - FILE: `lib/bootstrap.dart`, `lib/hiddifycore/hiddify_core.dart`, `lib/gen/hiddify_core_generated_bindings.dart`, `hiddify-core/platform/mobile/` (gomobile `bind -javapkg com.hiddify.core -libname hiddify-core`)

- **Cross-platform matrix (README Stores section):**
  - **Android** — `Hiddify-Android-universal.apk` + `arm64` + `armv7` + `x86_64` (`README.md Direct Download` table); also Google Play `app.hiddify.com` (badge still live), minSdk `21` (gomobile `-androidapi=21` in `hiddify-core/Makefile: android`)
  - **iOS** — AppStore `6596777532` (iPhone/iPad) + IPA `Hiddify-iOS.ipa` sideload (`README.md: iOS Hiddify-iOS.ipa`); NetworkExtension PacketTunnel
  - **Windows** — `Hiddify-Windows-Setup-x64.Msix` (Microsoft Store `9pdfnl3qv2s5`) + `Setup-x64.exe` + `Portable-x64.zip`; WinTun + system proxy
  - **macOS** — AppStore universal + `Hiddify-MacOS.dmg` + `Hiddify-MacOS-Installer.pkg` (Intel + Apple Silicon); NetworkExtension + system proxy; `sudo` for TUN path documented (`hiddify.com/app/How-to-use-Hiddify-app#enabling-tun`)
  - **Linux** — `Hiddify-Linux-x64.AppImage` + `Hiddify-Debian-x64.deb` + `Hiddify-rpm-x64.rpm` + Snap `snap/gui/`; needs root for TUN (`sudo ~/Downloads/hiddify-linux-x64.AppImage`)
  - HOW to confirm: `README.md: Get It On Stores` badges row + `Direct Download` 3×4 table + `hiddify-core/README.md: Quick Setup` `bash <(curl https://i.hiddify.com/core)`

- **Sing-box universal chain positioning:**
  - How: `README.md: What is Hiddify app?` — *"A multi-platform proxy client based on Sing-box universal proxy tool-chain"* — all inbound/outbound handling delegated to sing-box; Flutter is thin orchestrator: fetches subscription → `ray2sing` / `ProfileParser` normalizes → `SingboxConfigOption.generate()` merges `ConfigOption` (global) + `Profile.override` (per-profile) → emits sing-box `config.json` → core `Box.New()` starts router/inbounds/outbounds/experimental services (Clash API, cache file)
  - FILE: `lib/singbox/model/` (config models), `lib/features/profile/` (parsing), `hiddify-core/ray2sing/` submodule (Clash/V2Ray→sing-box converter)

- **Community & distribution:**
  - HOW: Telegram `t.me/hiddify` (channel) + `t.me/hiddify_board` (support, 5 is pinned guide), YouTube `@hiddify`, Twitter `@hiddify_com`, email `contribute@hiddify.com` (`README.md: Collaboration`), inlang translate badge `fink.inlang.com/github.com/hiddify/hiddify-app`, contributors via `contrib.rocks` image
  - Store presence: Play, AppStore, Microsoft Store — unlike many V2Ray clients, Hiddify is **official-store available** on all 5 OSes

## 2. Supported Protocols — Deep Dive

> Source: `README.md: Main features` · `hiddify.com/app/How-to-use-Hiddify-app:Supported protocols` · `hiddify-core/README.md:Multi-Protocol Support` · `SagerNet/sing-box docs` · `hiddify-sing-box/box.go: outlier InvalidConfig handling` · `deepwiki hiddify/hiddify-app`

- **Engine registration — how any protocol ends up as sing-box outbound:**
  - HOW: Dart subscription fetch → detect format (base64/JSON/YAML) → `ProfileParser` splits per-line URIs → for each URI dispatch by scheme to builder → produce normalized `ProxyConfig` → `SingboxConfigOption.generate()` emits `outbounds: [{type, tag, server, server_port, ...}]` → serialized JSON file in `path_provider` app docs dir → `HiddifyCoreService.start()` calls gomobile/FFI `Start` with path → Go `box.go:New()` loops `outbound.New()` for each, on error wraps `outbound.NewInvalidConfig` (Hiddify patch at `hiddify-sing-box/box.go:60-80` `lastErr/lastErrDesc` + `NewInvalidConfig`) so **one bad outbound doesn't crash core** — only empty outbounds fails (`hiddify-sing-box/box.go:75-77`)
  - FILE: `lib/features/profile/data/profile_repository.dart`, `lib/singbox/model/singbox_config_option.dart: generate()`, `hiddify-core/platform/mobile/` bridge, `hiddify-sing-box/box.go:45-90`

- **VLESS (primary, Reality-ready):**
  - Prefix: `vless://uuid@host:port?params#name`
  - Transports: `tcp`, `ws` (`path`+`host`/`ed` early-data), `grpc` (`serviceName`+`mode=gun/multi`), `httpupgrade`, `quic`, `http`, `splithttp`/`xhttp` (new 4.x, `ifpm`/`hHEX` style warp-bridged)
  - Security: `tls` + `reality` (`pbk`+`sid`+`spx`+`fp`), `xtls-rprx-vision` (`flow=xtls-rprx-vision`, requires `tls` + `reality` or `tls`+Vision), `none`
  - How in Hiddify: VLESS is sing-box `C.TypeVLESS` (`VLESSOutboundOptions`); reality params from `ray2sing`/`ProfileParser` mapped to `tls.reality.enabled` + `public_key`/`short_id`; uTLS fingerprint `fp=chrome/randomized` passed to `tls.utls`; Hiddify adds `core=xray` suffix fallback (see Xray dual-core) — if `&core=xray` appended to URI tag, routed to Xray core instead of sing-box
  - FILE: `hiddify-sing-box` outbound `vless`, `ray2sing` conversion, `test.configs/vless-reality.json`

- **VMess (legacy but fully supported):**
  - Prefix: `vmess://base64(json)` (V2Ray JSON: `add`, `port`, `id`, `aid`, `net`, `type`, `host`, `path`, `tls`, `sni`, `alpn`, `fp`)
  - Ciphers: `auto`/`aes-128-gcm`/`chacha20-poly1305`/`none`; `alterId` legacy (0 modern, non-zero compat)
  - Transports: same as VLESS (ws/grpc/quic/httpupgrade/splithttp)
  - How: `C.TypeVMess` (`VMessOutboundOptions`); `ray2sing` decodes base64 → sing-box outbound; MUX supported via route action `mux` (sing-box 1.11 merged to rule actions)
  - FILE: `ray2sing/vmess.go`, `lib/features/profile/parser/vmess_parser.dart` (if exists), sing-box `inbound/vmess` (inbound not needed client-side)

- **Reality (not a protocol — TLS ECH-like anti-DPI on top of VLESS/Trojan):**
  - Params: `pbk` (public key), `sid` (shortId), `spx` (spiderX, path), `sni` (serverName, must be real site like `www.microsoft.com`), `fp` (uTLS fingerprint), `flow` (vision)
  - How: sing-box embeds Reality directly in `tls.reality` outbound block (no Xray needed) — Go `reality` package does `REALITY` handshake; Hiddify's fork adds extended WARP/Reality scanner integration (`hiddify.com/manager/configuration-and-advanced-settings/How-to-use-Hiddify-Reality-Scanner/`, `How-to-use-Reality-on-Hiddify/`)
  - FILE: `hiddify-sing-box/outbound/reality`, sing-box docs `configuration/outbound/vless#reality`

- **TUIC (QUIC-based, UDP-optimized):**
  - Prefix: `tuic://uuid:pass@host:port?congestion_control=bbr&alpn=h3&sni=...&udp_relay_mode=native#name`
  - Versions: `v5` (latest sing-box) vs legacy `v4`; `congestion_control` `cubic`/`bbr`/`new_reno`
  - How: `C.TypeTUIC` (`TUICOutboundOptions`); QUIC params (`idle_timeout`, `keep_alive_period`, `stream_receive_window` etc. shared across Hysteria/TUIC since sing-box 1.11 `QUIC Fields`); early sing-box 1.11 made QUIC tuning shared, Hiddify inherits
  - FILE: `sing-box/protocol/tuic`, `hiddify-sing-box` `tuic` tag

- **Hysteria (v1, UDP/QUIC, obfs):**
  - Prefix: `hysteria://host:port?protocol=udp&auth=...&peer=...&insecure=1&upmbps=100&downmbps=100&obfsParam=...&alpn=h3#name`
  - `up_mbps`/`down_mbps` bandwidth, `obfs` salamander, `recv_window`/`recv_window_conn` tuning (deprecated 1.16, warning in sing-box changelog)
  - How: `C.TypeHysteria` (`HysteriaOutboundOptions`); QUIC + `obfs` + `users`; Hiddify supported from early Next releases; speed depends on `up/down` + BBR
  - FILE: `sing-box/protocol/hysteria`, docs `configuration/outbound/hysteria`

- **Hysteria2 (Hy2, redesigned):**
  - Prefix: `hysteria2://pass@host:port?insecure=1&sni=...&obfs=salamander&obfs-password=...&pinSHA256=...#name` or `hy2://`
  - Params: `up_mbps`/`down_mbps`, `obfs.type` `salamander`/`gecko` (new sing-box 1.11 `gecko` with `min_packet_size` 512/`max_packet_size` 1200, `hiddify-sing-box/extended` adds more masquerade), `ignore_client_bandwidth`, `masquerade` (fake HTTP), `bbr_profile` `conservative/standard/aggressive` (1.14+), `brutal_debug`, `realm` NAT-traversal (1.14+ rendezvous via STUN)
  - Port hopping: `ports` `20000-30000` range + `hop_interval` (sing-box 1.11 added `port hopping support for Hysteria2`)
  - How: `C.TypeHysteria2` (`Hysteria2OutboundOptions`/`InboundOptions`); sing-box 1.11 changelog 5 bullet points all about Hy2 (masquerade, ignore_client_bandwidth, port hopping); Hiddify inherits + extended fork adds Warp+Hy2 glue
  - FILE: `sing-box/protocol/hysteria2`, `sing-box/docs/changelog.md: Hysteria2 - sing-box`, `hiddify-sing-box` `extended` examples `warping+hysteria2`

- **WireGuard (endpoint model):**
  - Prefix: `wireguard://` or sing-box JSON `type: wireguard`; params: `private_key`/`peer_public_key`/`pre_shared_key`/`endpoint` (`host:port`)/`local_address` (`10.0.0.2/32`)/`mtu`/`keepalive`/`reserved` (3 bytes for WARP)
  - Sing-box 1.11 upgrade: WireGuard **outbound → endpoint** (deprecated outbound, removed 1.13); GSO auto-enabled when available; `gvisor` TUN GSO removed
  - How: In Hiddify, Warp is WireGuard under the hood (`warp://auto` → expands to WireGuard endpoint `162.159.192.1:2408` + `reserved` + `private_key` generated); supports both IPv4/IPv6 since 4.x (`warp auto4` vs `auto6` vs `auto` dual); Hiddify adds `ifp`/`ifps`/`ifpd`/`ifpm` warp noise params (see WARP section)
  - FILE: `hiddify-sing-box/endpoint/wireguard`, `sing-box/docs/deprecated:WireGuard outbound`, `hiddify-core/extension/warp*`

- **SSH (rare, via sing-box outbound):**
  - Prefix: `ssh://user:pass@host:port#name`
  - `private_key`/`password` auth, `host_key` verification
  - How: `C.TypeSSH` (`SSHOutboundOptions`); direct TCP/SSH tunnel, no TLS; Hiddify lists SSH in README protocols; single-proxy add via `hiddify://import/ssh://...`
  - FILE: `sing-box/protocol/ssh`

- **Trojan (TLS-opportunistic):**
  - Prefix: `trojan://pass@host:port?peer=...&sni=...&alpn=h2%2Chttp%2F1.1&fp=chrome&type=ws&path=%2F#name`
  - `password` as auth, `tls` mandatory (can be `reality`), `transport` ws/grpc/quic
  - How: `C.TypeTrojan` (`TrojanOutboundOptions`); Reality-capable like VLESS; Hiddify via `xtrojan` tag for Xray core fallback (`&core=xray` or `xtrojan://`)
  - FILE: `sing-box/protocol/trojan`

- **Shadowsocks (SS, SIP002):**
  - Prefix: `ss://base64(method:pass)@host:port#name` or `ss://base64(method:pass@host:port)#name`
  - Methods: `aes-128-gcm`, `aes-256-gcm`, `chacha20-ietf-poly1305`, `xchacha20-ietf-poly1305`, `2022-blake3-aes-128-gcm`/`256-gcm`/`chacha20-poly1305` (AEAD 2022 with `server_key`/`user_key`), `none` (plain, not recommended)
  - Plugins: `obfs` (`obfs=plain/http_simple/tls`), `v2ray-plugin` (WS+TLS), `shadow-tls`/`restls` (via sing-box shadowtls outbound type)
  - How: `C.TypeShadowsocks` (`ShadowsocksOutboundOptions`); UDP relay via `udp_over_tcp` option; Hiddify imports from Clash `ss` proxy block or raw `ss://`
  - FILE: `sing-box/protocol/shadowsocks`, `test.configs/shadowsocks*.json`

- **ShadowsocksR (SSR, legacy):**
  - Prefix: `ssr://base64(host:port:protocol:method:obfs:base64(pass)/?params)` (double base64)
  - Protocol `origin`/`auth_sha1_v4`/`auth_aes128_md5`, obfs `plain`/`http_simple`/`tls1.2_ticket_auth`, method `aes-128-cfb`/`aes-256-cfb`/`chacha20` etc.
  - How: NOT native sing-box — Hiddify keeps SSR via `ray2sing` + `hiddify-sing-box:extended`/`shadowsocksr` shim (Clash-meta legacy); listed in topic `shadowsocks` but deprecated — Hiddify README still says "Shadowsocks" but topic includes; Karing notes SSR deprecation, Hiddify similar — works via conversion, not direct sing-box type
  - FILE: `ray2sing/ssr.go`, `hiddify-sing-box/extended` (mirrors Karing's `Clash.Meta` SSR keep)

- **Other / extended (hiddify-sing-box:extended):**
  - **ShadowTLS** / **Reality** / **ECH** — `shadowtls` outbound type (`topic shadowtls`), ECH `ech` topic via uTLS+ech
  - **Mieru**, **NaiveProxy**, **AnyTLS**, **Socks**, **HTTP**, **Direct**, **Block**, **DNS** — `hiddify-core/README.md: Multi-Protocol Support` lists *Naive, Mieru, Hysteria, SOCKS, Shadowsocks, ShadowTLS, Tor, Trojan, VLess, VMess, WireGuard* — extended fork adds `Mieru`/`Naive`/`Amnezia 1.5`/`SDNS`/`Tunneling` (`hiddify-sing-box/extended: Amnezia 1.5, WARP, Tunneling, Mieru, XHTTP, SDNS`)
  - **ECH** — enabled via `tls.ech` in sing-box 1.11+ (topic `ech`), Hiddify lists `ECH` in `hiddify.com/app/How-to-use-Hiddify-app` protocol line `ECH, Sing-box, V2ray, Xray...`
  - FILE: `hiddify-sing-box/README extended`, `hiddify-sing-box/examples/`

## 3. Subscription Formats

- **Unified detection — how Hiddify decides which parser:**
  - HOW: Dart `ProfileParser.detectFormat()` checks (1) is base64? → decode → (2) JSON? (`{`+`"outbounds"`/`"inbounds"`/`"route"` → sing-box) vs YAML? (`proxies:`/`proxy-groups:` → Clash) vs newline-delimited URIs → V2Ray share links; also checks `Content-Type` header + URL suffix `.json` (sing-box) / `.yml/.yaml` (Clash) / no-suffix (V2Ray). Fallback tries `ray2sing` robust parser.
  - FILE: `lib/features/profile/parser/profile_parser.dart`, `lib/features/profile/data/profile_repository.dart: detect`, `test.configs/` mixed samples

- **Sing-box JSON (native):**
  - Format: pure sing-box `config.json` with `log`, `dns`, `inbounds` (`tun`, `mixed`, `socks`, `http`), `outbounds` (direct, block, dns, selector, urltest, + per-protocol), `route` (rules + rule_set), `experimental` (`cache_file`, `clash_api`)
  - Import: `hiddify://import/https://example.com/singbox.json#name` OR `hiddify://import/https://raw.githubusercontent.com/yebekhe/TelegramV2rayCollector/.../singbox/sfasfi/mixLite.json` (example in URL-Scheme docs)
  - How: Direct — Hiddify validates via `HiddifyCoreService.validate()` (`sing-box check -c config.json` equivalent) then writes to file cache; no conversion; `execute-config-as-is: false` wraps it with Hiddify's own `ConfigOption` overlays unless toggled
  - FILE: `lib/singbox/model/singbox_config.dart`, `hiddify-core/ray2sing -- singbox passthrough`

- **V2Ray base64 share-link sub (V2RayN/V2RayNG standard):**
  - Format: base64-encoded newline-joined URIs (`vmess://`+`vless://`+`ss://`+`trojan://`+`tuic://`+`hysteria2://`+`warp://`+`wireguard://`) OR plain (non-base64) — Hiddify handles both (`#normal example` vs `#base64 example` in URL-Scheme docs)
  - Example: `https://raw.githubusercontent.com/yebekhe/TelegramV2rayCollector/fe3637db4ece53e56ac99ea09dbefa34466f280f/sub/normal/mix` (normal) and `.../sub/base64/mix` (base64) — `hiddify.com/app/URL-Scheme: v2ray link format`
  - How: Fetch URL → if `Content-Encoding: base64` or body is base64-lookalike, decode → split by `\n` → regex per scheme → tag = `ps`/`remarks`/`#fragment`; `ray2sing` also does this server-side; supports mixed sub with Clash YAML embedded (auto-detect)
  - Settings per sub: auto-update interval stored in Drift `Profile.override.updateInterval` (default 0 = manual); global `url-test-interval` controls health check

- **Clash / Clash Meta (Mihomo) YAML:**
  - Format: `proxies: [{name, type, server, port, ...}]` + `proxy-groups: [{name, type: select/url-test/fallback/load-balance, proxies: [...], url, interval}]` + `rules: [...]` + `dns:` etc. (Clash schema)
  - Import: `hiddify://import/https://raw.githubusercontent.com/yebekhe/TelegramV2rayCollector/d6ce7b907eeb58abf503c283af192e7bc91d14/clash/mix.yml` (`URL-Scheme: Clash format`); Hiddify also accepts `clash://`? but `hiddify://import/` is canonical
  - How: `ray2sing` (`hiddify/ray2sing` submodule, Go `ray2sing @ caf5e9a`) converts Clash YAML → sing-box JSON: `proxies` → `outbounds`, `proxy-groups` → `selector`/`urltest`, `rules` → `route.rules`; Hiddify-core `extension/sdk.ParseConfig()` also parses any type (`hiddify-core/README.md: extension: Parse Any type of configs/url sdk.ParseConfig()`)
  - File: `ray2sing/clash.go`, `ray2sing/sing.go`, `hiddify-core/extension/sdk/`

- **Hiddify proprietary subscription link:**
  - Format: Two schemes:
    - **Hiddify panel sub:** `https://<panel-domain>/<uuid>/<tag>/sub/` → often auto-converts via `hiddify://import/<https-sub>#name` deep link (user page "Tap to Start Anti-Filter" button opens `hiddify://import/...` directly)
    - **Deep link scheme:** `hiddify://import/<sublink>#name` (generic), plus explicit `hiddify://install-sub?url=<encoded v2ray config URI>#<name>`, `hiddify://install-config?url=<encoded ...]#<name>`, `hiddify://install-proxy?url=<encoded proxy share link>#<name>` (`hiddify.com/app/URL-Scheme:1-30` and `hiddify-app/wiki/URL-Scheme`)
  - Example: `hiddify://import/https://sub.example.com/path#MySub` → adds profile named "MySub"; `warp://auto&&detour=warp://auto#WoW` counted as single-protocol import (Warp special)
  - How: `app_links 6.4.0` registers `hiddify://` on all platforms (`win32 5.12.0` writes Windows registry `HKEY_CLASSES_ROOT\hiddify`); Android intent-filter `<data android:scheme="hiddify"/>` in `android/app/src/main/AndroidManifest.xml`; iOS `CFBundleURLSchemes` `hiddify` in `ios/Runner/Info.plist`; macOS same; Linux `xdg-mime`; click triggers `AppLinks` stream → `ProfileRepository.addFromUrl()` → fetch → parse
  - Auto-update interval: per-profile `updateInterval` (minutes/hours) in `Profile` Drift table; global `ConfigOption` `url-test-interval` 600s default controls latency probe, not sub update; sub update runs via `neat_periodic_task 2.0.1` periodic job + `dio_smart_retry` + `ETag`/`If-None-Match` conditional GET (see Other)

- **Profile headers — traffic & expiry:**
  - HOW: On sub fetch, Hiddify reads response headers `subscription-userinfo: upload=123; download=456; total=10737418240; expire=1700000000` (standard V2Ray sub) and `profile-update-interval`, `content-disposition`; displays remaining traffic/days in `Proxies` UI (`README.md: Display profile information including remaining days and traffic usage`); `ProfileParser` header extraction (`deepwiki hiddify-app: Header extraction: Parses subscription-info headers for traffic/expiry data`)
  - FILE: `lib/features/profile/model/profile_info.dart`, `lib/features/profile/parser/subscription_info_parser.dart`

- **Manual / clipboard / QR:**
  - HOW: `Home` → `+` → `Add from clipboard` (auto-detects any of above) OR `Add manually` (name + URL fields) (`hiddify.com/app/How-to-use-Hiddify-app: Adding a profile to the app`); `mobile_scanner 7.2.0` scans QR containing URI/sub link; `share_plus` + `url_launcher` for export
  - FILE: `lib/features/profile/presentation/add_profile_page.dart`

## 4. Cores Matrix — sing-box 1.11+ Fork, Xray Dual-Core, ray2sing

- **Primary core — sing-box universal:**
  - Version: **sing-box 1.11+** (Hiddify tracks upstream closely; `hiddify-core/go.mod` bumps via `hiddify-sing-box` submodule `@ 170d831`; `dependencies.properties` pins `sing-box` rev; changelog `HISTORY.md:4.1.2 (2026-03-05)` notes translations, but core bumps in commits `f2034de` etc.)
  - How sing-box embeds everything (no separate Xray needed for Reality/Hysteria): Reality is `tls.reality` inside VLESS/Trojan outbound (`sing-box/option: Reality` struct), Hy1/Hy2/TUIC is `C.TypeHysteria*`/`C.TypeTUIC` QUIC outbound (quic-go `v0.55.0` → `v0.61.0`), ShadowTLS is `type: shadowtls`, ECH is `tls.ech` — all compiled into one Go binary; Hiddify-core comment in `box.go:60` shows patch that keeps invalid outbounds alive (vanilla sing-box would abort `Box.New()` on first error)
  - FILE: `hiddify-sing-box/box.go:1-120` (Hiddify patch `lastErr`/`NewInvalidConfig`), `sing-box/docs/changelog.md: sing-box 1.11.0` bullet list (rule actions, gvisor compat, WireGuard endpoint, Hysteria2 port hopping)

- **Fork — hiddify-sing-box (extended):**
  - Repo: `hiddify/hiddify-sing-box` (58 ★, 43 forks, 1 open issue, `extended` default branch `extended`, parent `SagerNet/sing-box`, created 2023-05-14)
  - Added features (`hiddify-sing-box: extended` README): *Amnezia 1.5, WARP, Tunneling, Mieru, XHTTP, SDNS (DNSCrypt), Extended WireGuard options, Unified delay* — same superset as `KaringX/sing-box extended` but Hiddify-maintained; submodule in `hiddify-core/hiddify-sing-box @ 170d831`
  - Warp integration: custom `warp://` scheme handled by `hiddify-core` extension patch (`warp` outbound type → WireGuard endpoint + `reserved` + noise `ifp/ifps/ifpd/ifpm`), fork adds `warp-detour` mode (`outbound` vs `endpoint`)
  - How: `hiddify-core/Makefile` builds `hiddify-sing-box` via `go.mod replace github.com/sagernet/sing-box => ./hiddify-sing-box`; tags `TAGS` include `with_gvisor,with_quic,with_wireguard,with_reality_server,with_acme,with_clash_api,with_v2ray_api,with_tailscale` etc.; `CRONET_GO_VERSION` pulled from `hiddify-sing-box/.github/CRONET_GO_VERSION`
  - FILE: `hiddify-sing-box/examples/`, `hiddify-core/go.mod: replace`, `hiddify-core/Makefile: TAGS`, `hiddify-core/extension/warp*`

- **Wrapper — hiddify-core (libbox rebuild, not just sing-box):**
  - Repo: `hiddify/hiddify-core` (231 ★, 184 forks, 34 open issues, 743 commits, `main`); description *"Hiddify Core — The Ultimate Universal Proxy Platform"* powering Android/macOS/Linux/Windows/iOS + OpenWrt
  - Structure: `hiddify-sing-box` submodule + `ray2sing` submodule (`ray2sing @ caf5e9a`) + `platform/` (mobile `gomobile bind` + desktop `libbox` FFI) + `extension/` (third-party plugin SDK) + `cmd/` + `bin/desktop.h` (FFI header) + `release/config/`
  - Extension system: third-party Go/JS extensions via `github.com/hiddify/hiddify-core/extension` — hooks `BeforeAppConnect`, `UpdateUI`, `ShowDialog`, `ShowMessage`, `SubmitData`, `RunInstance`, `ParseConfig` (`README.md: Extension` 12 bullet roadmap) — can modify configs, show UI, run tiny independent instance before connect; tested via `cmd.sh extension` → `https://127.0.0.1:12346`
  - Performance: *"Optimized core built on top of sing-box for maximum speed and stability"* (`hiddify-core README`); UDP GSO auto for WireGuard, adaptive; Router-ready OpenWrt/Systemd (`installer.sh`, `.fpm_openwrt`, `.fpm_systemd`, `platform/wrt/README.md`)
  - FILE: `hiddify-core/go.mod`, `hiddify-core/Makefile: lib_install/android/ios/ios-full/desktop`, `hiddify-core/bin/desktop.h`, `hiddify-core/extension/README.md`

- **Secondary core — Xray (dual-core mode, added 4.x):**
  - How: Hiddify 4.x includes **both sing-box and Xray cores simultaneously** (`releases/tag/v4.1.1` highlight: *"💥 This version includes the Xray Core, allowing you to use both Singbox and Xray cores simultaneously."*`); to use Xray, append `&core=xray` to proxy link OR rename prefix `vless`→`xvless`, `vmess`→`xvmess`, `trojan`→`xtrojan` (`CHANGELOG/HISTORY.md:4.x` Higlight 2-3 lines); Xray handles its share (likely `XTLS/Xray-core` via bundled binary/shared lib, path `assets/core/xray`?); selector in Dart `Profile.override.corePreference: singbox|xray`
  - Why: Xray Reality/Vision sometimes preferred for certain configs / Hiddify panel `xtls` tests; Warp `Split HTTP` ("new generation Filtering circumvention as Split HTTP: helps keep CDN connections alive" — `HISTORY.md: 4.x` changelog additional line) works via Xray `splithttp`
  - FILE: `lib/features/profile/model/profile.dart: core` enum, `lib/hiddifycore/xray_service.dart`, `releases/tag/v4.1.1` description, `test.configs/*xray*`

- **Converter — ray2sing:**
  - Repo: `hiddify/ray2sing` (submodule `ray2sing @ caf5e9a`, Go lib); purpose: parse **any** share link / Clash YAML / V2Ray JSON → sing-box JSON
  - How: exposed via `extension/sdk.ParseConfig()` (`hiddify-core README` extension bullet: *"Parse Any type of configs/url sdk.ParseConfig()"`); Dart calls it through core FFI before emitting final config; also used standalone in `hiddify-core/cmd/ray2sing`
  - FILE: `ray2sing/*.go` (`parser.go`, `clash.go`, `sing.go`, `vmess.go`, `ssr.go`)

- **Versioned cores in app — how user picks:**
  - HOW to verify: add link `vless://uuid@host:443?type=ws&path=/ws#myNode` → works sing-box; add `vless://uuid@host:443?type=ws&path=/ws&core=xray#myNodeX` → Hiddify routes to Xray engine (check `Settings → Advanced → Config Options → Core` or per-profile override); speed test shows which core responded (Clash API port `6756` vs `Xray API`)
  - FILE: `lib/features/settings/presentation/advanced_settings_page.dart`, `lib/singbox/model/config_option.dart: enable-xray`

## 5. Routing / Split Tunneling

- **Automatic node selection — URL-test / selector:**
  - HOW: `ConfigOption` `url-test-interval: 600` (10 min) + `connection-test-url: http://cp.cloudflare.com/` (`issue #529` log sample shows these defaults: `url-test-interval 600`, `connection-test-url http://cp.cloudflare.com/`); Flutter `Profile` page shows `Proxies` list with **delay ms** per outbound; core runs `urltest` outbound group (`type: urltest`, `tolerance`) probing `cp.cloudflare.com` (or `generate_204`); best latency wins for `selector` `auto` / `proxy` group; user can tap any proxy to override manual (`README.md: Delay based node selection`)
  - FILE: `lib/features/proxy/presentation/proxies_page.dart`, `lib/singbox/model/config_option.dart: url-test-interval`, `hiddify-core/release/config/default.json: outbounds.urltest`

- **Smart routing — region-based bypass rules:**
  - HOW: Default rules: `domain:.ir` + `geosite:ir` + `geoip:ir` → `bypass` (direct) (`issue #529` config sample `rules: [{domains: domain:.ir,geosite:ir, ip: geoip:ir, outbound: bypass}]`); plus `geo-assets/sagernet-sing-geoip-geoip.db` + `geosite-geosite.db` (`geoip-path`/`geosite-path` in same sample); `Config Options` → `Rules` editable list where each rule has `domains`, `ip`, `port`, `protocol`, `network`, `outbound` (`bypass` vs `proxy` vs `block`)
  - Content: `Resources: Clash/Meta fallbacks` — `geosite`/`geoip` auto-update via clash_api?
  - FILE: `lib/features/settings/presentation/routing_settings_page.dart`, `lib/singbox/model/rule.dart`, `assets/geo-assets/`, `hiddify-core/release/config/rules.json`

- **Routing region presets — "Appropriate for Iran/China/Russia":**
  - HOW: `Settings → Routing → Region` preset buttons: `Iran` (bypass `.ir`/IR IPs, proxy rest), `China` (bypass `geosite:cn`/`geoip:cn`), `Russia`, `Others` (global proxy) — README says *"Appropriate configuration for Iran, China, Russia and other countries"*; issue `Proxy per app doesn't work at all #2140` notes *"changing Routing-Region to Others solves it. Every Routing except others have a problem"* — indicates region routing interacts with per-app
  - FILE: `lib/features/settings/data/region_provider.dart`, `lib/singbox/model/config_option.dart: rules`

- **Per-app proxy (split tunneling per application):**
  - Platforms: **Android** (full, via `VPNService` `addAllowedApplication`/`addDisallowedApplication`) + **Windows** (partial, via WinTun/per-app via routing + firewall?); iOS/macOS **not** per-app (OS limitation — NetworkExtension packet tunnel can't filter by bundle ID except via `includeAllNetworks` + per-app VPN is MDM-only)
  - Settings path: `Settings → Routing → Per-app proxy` toggle ON → choose mode `Proxy only selected apps` vs `Bypass selected apps` (`issue #2140: Settings-Routing-Per-app proxy ON Select Proxy only selected apps choose Telegram`)
  - HOW Android: Dart `installed_apps` plugin enumerates packages (`installed_apps: git VB10/installed_apps` in `pubspec.yaml`); `perAppProxyList: List<String> packageNames` stored in `ConfigOption`/`SharedPreferences`; on connect, `platform/mobile.android.kt` calls `VpnService.Builder.addAllowedApplication(pkg)` for allowlist or `addDisallowedApplication` for blocklist before `establish()`; failed apps (Telegram cannot connect, files fail) reported in `#2140` — log shows 400+ `accessed app list` denied 397 times (Android 14 `QUERY_ALL_PACKAGES` restriction + Samsung tablet vs phone difference in issue comment)
  - HOW Windows: `route` → `excludePackage`? actually Windows uses `tun` + `route` `include`/`exclude` process? Alternatively per-app via `WFP` callout (WinDivert/winTun not per-app, so Windows per-app is limited to `system proxy` PAC auto-config bypass? Check: `issue #2140` titled per-app but only Android repro)
  - File: `lib/features/settings/presentation/per_app_proxy_page.dart`, `android/app/src/main/kotlin/com/hiddify/app/PerAppProxyPlugin.kt`, `hiddify-core/platform/android/perapp.go`

- **Bypass vs Proxy vs Block vs Warp — rule action ordering (sing-box 1.11 rule_actions migration):**
  - Sing-box 1.11 merged `route` options to `rule actions`: legacy `outbound: bypass/block/dns` deprecated → now `action: route`/`reject`/`hijack-dns` etc.; Hiddify's `SingboxConfigOption.generate()` emits new schema (`route.rules: [{domain_suffix: [".ir"], action: "route", outbound: "bypass"}, {action: "reject", method: "drop"}...]`)
  - HOW: Evaluation order: `rule_set` (remote geo) → `rule` (local) → `final` `proxy` (selector `auto`); `warp-detour-mode` (`outbound` vs `endpoint`) changes whether Warp is extra hop or final egress
  - FILE: `sing-box/docs/deprecated: Legacy special outbounds`, `hiddify-core/release/config/config.json: route`

- **Warping / Warp detour (Warp-on-Warp, outbound chain):**
  - HOW: Warp is WireGuard endpoint; `warp-detour-mode: outbound` stacks WARP after proxy (`proxy → warp → internet`); value observed in `#529` config dump `warp-detour-mode: outbound`; plus explicit `warp://auto&&detour=warp://auto#WoW` chaining two Warps (`hiddify.com/app/How-to-use-WARP-on-Hiddify-App: With this feature, you can use two different WARPs... detour parameter... warp://auto&&detour=WARP://auto`)
  - FILE: `lib/singbox/model/config_option.dart: warp-detour-mode`, `hiddify-core/extension/warp_detour.go`

## 6. TUN vs Proxy

- **Three service modes (Config Options):**
  - Modes: **VPN (TUN)** — full-route Layer-3 tunnel (recommended, captures all TCP/UDP, needed for UDP games/VoIP) vs **System Proxy** (PAC/HTTP(S)/SOCKS auto-set on OS, only proxy-aware apps, no UDP unless app does SOCKS) vs **Proxy-only** (manual: app binds `mixed-port 2334`, `local-dns-port 6450`, you configure browser manually)
  - HOW: `ConfigOption` booleans `enable-tun`, `enable-tun-service`, `set-system-proxy`, `mixed-port`, `local-dns-port`, `allow-connection-from-lan`, `bypass-lan` (`#529` dump shows all: `mixed-port 2334`, `local-dns-port 6450`, `enable-tun true`, `enable-tun-service false`, `set-system-proxy false`)
  - FILE: `lib/features/settings/presentation/config_options_page.dart`, `lib/singbox/model/config_option.dart`

- **TUN implementation — system vs gVisor vs mixed:**
  - Options: `tun-implementation: system | gvisor | mixed` (`#529` sample `tun-implementation: mixed`), `stack: system | gvisor` (sing-box tun `stack`), `mtu: 9000` (`#529` `mtu 9000`), `strict-route: true`, `auto-route`/`auto-redirect`
  - Sing-box 1.11 TUN changes: *improve tun compatibility* (reply TCP RST before establish, `udp_disable_domain_unmapping`/`udp_connect` as route actions), *GSO removed from TUN* (deprecated, no advantage transparent), *rule actions for reject (TCP RST/ICMP unreachable) to improve gVisor*
  - How Hiddify picks: `mixed` tries `system` stack first (uses OS TUN fd, best perf) then fallback `gvisor` (userspace TCP/IP, no root on Android, works without `NET_ADMIN`? actually gvisor needs no raw); `mtu 9000` is unusually high (jumbo, reduces packetization overhead on Warp)
  - FILE: `hiddify-core/release/config/tun.json`, `sing-box/docs/changelog: Improve tun compatibility 3`, `sing-box/option/tun.go`

- **How TUN is activated (platform-specific, admin required):**
  - **Windows** — must *Run as administrator* (right-click tray/desktop icon → `Run as administrator`); otherwise `Exit` → re-run elevated; then `Settings → Advanced → Config Options → Enable TUN` ON → Home connect (green) (`hiddify.com/app/How-to-use-Hiddify-app: Enabling TUN → Opening the app with admin privilege on Windows` 3 steps + screenshot `Run ad admin`)
  - **macOS** — close → Terminal → `sudo /Applications/HiddifyNext.app/Contents/MacOS/HiddifyNext` (show package contents → `MacOS/HiddifyNext`, `sudo` + drag) → then enable TUN
  - **Linux** — `sudo ~/Downloads/hiddify-linux-x64.AppImage` (or `.deb` service via systemd) → enable TUN
  - HOW check: Dart `window_manager` + `launch_at_startup` + `tray_manager` require elevated; core logs `tun: create tun interface` or error `permission denied` if not elevated
  - FILE: `windows/runner/main.cpp: requireAdmin manifest`, `macos/Runner/Info.plist: SMPrivilegedExecutables`, `lib/features/settings/presentation/advanced_settings_page.dart: Enable TUN tile`

- **`VPNService` on Android (NetworkExtension analogue):**
  - Implementation: `android/app/src/main/kotlin/com/hiddify/app/VpnService.kt` (Kotlin) extends `android.net.VpnService`; `prepare()` → `Builder.addAddress(172.19.0.1/30)` + `addRoute(0.0.0.0/0)` + `addDnsServer(1.1.1.1)` + `setMtu(9000)` + `setBlocking(false)` + per-app allowed/disallowed → `establish()` returns `ParcelFileDescriptor fd`; `fd` passed to sing-box `tun` inbound via `libbox` `setTunFd(int fd)`; `onDestroy` → `Box.Close()`
  - Modes: VPN (TUN fd) vs Proxy-only (no `VpnService`, just SOCKS/HTTP inbounds `mixed-port`)
  - Notification: persistent `Ongoing` notification with bytes/traffic, `dynamic notifications` (DeepWiki feature table)
  - FILE: `android/app/src/main/kotlin/.../VpnService.kt`, `platform/mobile/mobile_android.go: SetTunFd`, `android/app/src/main/AndroidManifest.xml: VPN_SERVICE perm`

- **`NetworkExtension` on iOS/macOS (PacketTunnelProvider):**
  - Implementation: `ios/Runner/PacketTunnelProvider.swift` (Swift) + `macos/Runner/PacketTunnelProvider.swift` implements `NEPacketTunnelProvider`; `startTunnelWithOptions` → `setTunnelNetworkSettings(NEPacketTunnelNetworkSettings(tunnelRemoteAddress:..., ipv4Settings:..., dnsSettings:...))` → `packetFlow` fd bridged to sing-box `tun` inbound; `stopTunnelWithReason` → `Box.Close()`
  - Entitlements: `com.apple.developer.networking.networkextension` + `packet-tunnel-provider` + `includeAllNetworks` (bypass check `bypass-lan` mirrors `excludeLocalNetworks`)
  - Sing-box Apple fork: `SagerNet/sing-box-for-apple` referenced in `README.md Acknowledgements` — Hiddify uses apple-specific libbox `Libcore.xcframework` (`hiddify-core/Makefile: ios` `gomobile bind -target ios -libname box -tags ...`)
  - FILE: `ios/PacketTunnel/PacketTunnelProvider.swift`, `macos/PacketTunnel/PacketTunnelProvider.swift`, `ios/Runner.entitlements`, `hiddify-core/Makefile: ios-full` `gomobile bind -target ios,iossimulator,tvos,tvossimulator,macos`

- **`WinTun` on Windows (tun to WFP):**
  - Implementation: `windows/tun/wintun.dll` (via `sing-box inbound/tun` `stack: system` on Windows → `CreateAdapter` → `WinTun` → assigned IP `198.18.0.1/30` + route `0.0.0.0/0` + DNS `1.1.1.1`); alternative `gvisor` stack bypasses WinTun (userspace) and just uses `system proxy` hook via `WSA`
  - Registry proxy: when `set-system-proxy: true` (System Proxy mode), Dart `win32` writes `HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings` `ProxyEnable=1`, `ProxyServer=127.0.0.1:2334`, `ProxyOverride=<local>` + PAC `AutoConfigURL` if PAC mode
  - FILE: `windows/tun/wintun.go`, `lib/core/platform/windows_proxy.dart: setSystemProxy`, `sing-box/inbound/tun_windows.go`

- **System proxy / PAC mode:**
  - `set-system-proxy: false` in TUN mode (tunnel covers all, no extra proxy); when TUN off, set-system-proxy ON puts `mixed-port 2334` (`socks`+`http`) as OS proxy so only proxy-aware apps go through (fallback for non-admin)
  - FILE: `lib/singbox/model/config_option.dart: set-system-proxy`, `windows/runner/flutter_window.cpp: proxy set`

## 7. DNS — FakeIP, DoH, Split DNS

- **DNS architecture (sing-box `dns` block → `route` `hijack-dns` action):**
  - HOW: `ConfigOption` fields map to sing-box `dns: {servers: [{tag, address, strategy, detour}], rules: [{rule_set, server}], final, strategy, independent_cache}`; `enable-dns-routing: true` (`#529` `enable-dns-routing true`) + `independent-dns-cache: true` (`#529`) splits direct vs proxy resolver caches (prevents pollution)
  - FILE: `lib/singbox/model/dns_config.dart`, `hiddify-core/release/config/dns.json`, `sing-box/docs/configuration/dns`

- **FakeIP (Fake DNS):**
  - Bool: `enable-fake-dns: false` (`#529` default false); when ON, sing-box returns synthetic `198.18.0.0/15` (or `fd00::/18`) for proxied domains, defers real lookup to outbound remote — avoids local DNS leak/tampering
  - Scope: only for `proxy` outbound domains, bypass domains still resolve normally via `direct-dns`
  - Activation: `Settings → Advanced → Config Options → Enable Fake DNS` (desktop) — risky on Android `Private DNS` auto (Android's `getprop net.dns1` conflicts)
  - FILE: `lib/singbox/model/config_option.dart: enable-fake-dns`, `sing-box/docs/configuration/dns: fakeip`

- **DoH / DoT / DoQ / DNSCrypt (SDNS):**
  - Addresses: `remote-dns-address: udp://1.1.1.1` (`#529` default), `direct-dns-address: 1.1.1.1` (same); user can switch to `https://1.1.1.1/dns-query` (DoH), `tls://1.1.1.1` (DoT), `quic://1.1.1.1` (DoQ), or `sdns://...` (DNSCrypt via extended fork `SDNS` feature `hiddify-sing-box extended: SDNS`)
  - Strategy per server: `remote-dns-domain-strategy` empty (`#529` `remote-dns-domain-strategy ""`) means auto; options `ipv4_only`/`ipv6_only`/`prefer_ipv4`/`prefer_ipv6`; note `#2140` fix: *"DNS-Remote DNS domain strategy=IPv4 ONLY solves per-app"*
  - Local DNS port: `local-dns-port: 6450` (sing-box `inbound dns` listen on `127.0.0.1:6450`) — system DNS is hijacked to this when TUN on (`hijack-dns` rule action since 1.11)
  - FILE: `lib/features/settings/presentation/dns_settings_page.dart`, `hiddify-core/Makefile TAGS with_sdnds`

- **Split DNS — domestic vs proxy (the Iran/China special):**
  - Pattern: `direct-dns` for bypass domains/IPs (`.ir`, `geoip:ir`, `geosite:ir`) → `1.1.1.1` or domestic `178.22.122.100` (Shecan) / `185.51.200.2` (403.online); `remote-dns` for rest → `udp://1.1.1.1` via proxy `detour: proxy` (lookup through tunnel so ISP can't poison); sing-box `dns.rules: [{rule_set: geosite-ir, server: direct}, {rule_set: geoip-ir, server: direct}, {final: remote}]`
  - How Hiddify does it: `dns.rules` auto-generated from `Rules` list when `enable-dns-routing: true`; each `Rule` can specify `direct-dns` vs `remote-dns` per rule (UI toggle `Use Direct DNS`?); `independent-dns-cache` keeps two LRU caches separated so direct cache isn't poisoned by proxy DNS
  - Documented: `hiddify.com/manager/basic-concepts-and-troubleshooting/How-to-set-DNS-server/` and `How-to-check-and-prevent-DNS-leaks/` (leak test via `dnsleaktest.com`/`ipleak.net`)
  - FILE: `lib/singbox/model/config_option.dart: direct-dns-address / direct-dns-domain-strategy / remote-dns-address / remote-dns-domain-strategy`, `hiddify-core/release/config/dns_split.json`

- **Extra DNS options:**
  - `resolve-destination: false` (`#529` `resolve-destination false`) — when true, sing-box resolves domain outbound server IPs locally before routing (needed for `geoip` rules on domain IPs); `ipv6-mode: ipv4_only` (`#529`) forces `ipv4_only` strategy globally (matches per-app fix)
  - `cache_capacity` (sing-box 1.11 new `cache_capacity DNS option`) — `independent-dns-cache` implies capacity per cache? `sing-box/docs/changelog: Add cache_capacity DNS option 7`
  - FILE: `sing-box/docs/configuration/dns: cache_capacity`, `lib/singbox/model/config_option.dart: ipv6-mode`

## 8. DPI Bypass — Reality, uTLS, Fragment, Warp

- **Reality (primary anti-censorship):**
  - Prereq: VLESS/Trojan `reality` outbound (`pbk`/`sid`/`spx`/`sni`) + server side `reality` inbound (Hiddify Manager auto-generates `shortId`/`privateKey`/`publicKey` + SNI `www.microsoft.com`/`www.yahoo.com` that passes TLS fingerprint check)
  - How it bypasses: Client Hello mimics real browser to `SNI`'s real IP (steals its TLS cert via `REALITY` handshake, no cert needed on proxy server, DPI sees valid cert from `SNI` domain, can't distinguish without active probing); Hiddify's Reality scanner (`hiddify.com/manager/configuration-and-advanced-settings/How-to-use-Hiddify-Reality-Scanner/`) tests `SNI` reachability/port 443 before connect
  - Client config: `tls.reality.enabled: true`, `public_key: <pbk>`, `short_id: <sid>`, `server_name: <sni>` — set via URL params `pbk=&sid=&sni=`; Hiddify `ray2sing` preserves them; fallback to Xray core Reality if sing-box version mismatch (Xray Reality is more mature)
  - FILE: `hiddify-sing-box/outbound/reality.go`, `lib/features/profile/parser/reality_parser.dart`, `hiddify-manager` reality sort `reality_gen.py`

- **uTLS (TLS fingerprint parroting):**
  - Setting: `TLS Tricks` → `enable-tls-fragment`, `enable-tls-mixed-sni-case`, `enable-tls-padding` are Hiddify's TLS trick toggles (`#529` `enable-tls-fragment false`, `tls-fragment-size 1-500`, `tls-fragment-sleep 0-500`, `enable-tls-mixed-sni-case false`, `enable-tls-padding false`, `tls-padding-size 1-1500`); `fp` URL param (`chrome`/`firefox`/`safari`/`randomized`/`none`) → sing-box `tls.utls.fingerprint`
  - How: sing-box uses `utls` (uTLS) to parrot `Chrome` ClientHello (cipher suites, extensions, ALPN, GREASE); Hiddify-core `extension` adds `fragment`/`mixed-sni-case`/`padding` on top (see next)
  - Note: Hysteria2 Chrome QUIC parroting (`sing-box changelog: Add Hysteria2 Chrome QUIC fingerprint parroting 1` since 1.14, Chrome doesn't declare Ed25519 → Ed25519 certs fail unless `disable_chrome_parrot`)
  - FILE: `lib/singbox/model/tls_tricks.dart`, `hiddify-core/extension/tls_trick.go`, `sing-box/docs/configuration/outbound/tls: utls`

- **Fragmented Hello (TLS fragment):**
  - Params: `enable-tls-fragment`, `tls-fragment-size: 1-500` (split ClientHello into `1-500` byte chunks), `tls-fragment-sleep: 0-500` (sleep `0-500` ms between fragments) (`#529` sample); plus `enable-tls-mixed-sni-case` (random upper/lower `sni` like `Www.MiCroSoft.CoM`) and `enable-tls-padding` (`tls-padding-size 1-1500` add random padding extension)
  - How: implemented in `hiddify-core` extension patch `with_freedom`? Actually `hiddify-sing-box extended: XHTTP/Split HTTP` + `fragment` patch intercepts `tls.ClientHello` write, splits at TCP level; guide `hiddify.com/manager/basic-concepts-and-troubleshooting/A-good-way-to-find-TLS-trick-values/` and `How-the-TLS-Trick-works-and-its-usage/` explains finding working `ifp`/`fragment` values via brute-force against DPI
  - MUX overlap: `enable-mux: false`, `mux-protocol: h2mux`, `mux-max-streams: 8`, `mux-padding: false` (`#529`) — MUX also helps bypass by multiplexing over one TLS session (fewer handshakes to fingerprint), but increases detectability if DPI does flow size correlation
  - FILE: `hiddify-core/extension/tls_fragment.go`, `hiddify-core/go.mod: require github.com/refraction-networking/utls`, `lib/singbox/model/config_option.dart: enable-tls-fragment`

- **Warp / Warp-in-Warp (WARP as DPI bypass + extra hop):**
  - Scheme: `warp://auto#NAME` simplest; full form `warp://License@IP:port?ifp=n1-n2&ifps=s1-s2&ifpd=d1-d2&ifpm=mode#name` (`hiddify.com/app/How-to-use-WARP-on-Hiddify-App` formula) — where `ifp`=`packet size` range, `ifps`=`inter-packet size`, `ifpd`=`delay` range, `ifpm`=`m1-m6/hHEX` mode; `hHEX` advanced allows hex `h04FA0A`? Example `warp://auto?ifp=40-80&ifps=40-100&ifpd=4-8&ifpm=m4#m4`
  - Implementation: Warp is Cloudflare WARP WireGuard endpoint (`162.159.192.1:2408` + `2606:4700:d0::...`); Hiddify generates `private_key` locally (or uses `warp-license-key`/`warp-account-id`/`warp-access-token` if `Warp Pro` license set — `warp-license-key ""` `#529`), `reserved` bytes per Warp spec, `mtu`/`keepalive`; `warp-clean-ip: auto` (`#529`) auto-discovers clean IP via `endpoint` scan, `warp-port 0` means random 2408/500/1701/890 (WireGuard UDP ports that pass DPI)
  - Warp modes `m1-m6` + `hHEX`: each maps to noise pattern (how many junk packets, sizes, delays) — guide says *6 new modes and one advanced mode have been added to Warp, ranging from m1 to m6 and hHEX. Set ifpm in the configuration to one of the modes. For example: ifpm=m4* (`HISTORY.md 4.x changelog` highlight 6-7)
  - Warp-on-Warp `&&detour=`: `warp://auto&&detour=warp://auto` → first Warp detours through second (`detour` param at end of first URL joined by `&&`, not `&` — note double ampersand) — final egress IP is second Warp's; sample chained: `warp://auto?ifp=40-80&...&ifpm=m4#m4&&detour=WARP://188.114.97.170:894?ifp=40-80&...&ifpm=m3#m3` (`hiddify.com/app/How-to-use-WARP-on-Hiddify-App: You can also detour two WARPs...`)
  - IPv6 handling: `warp://auto` dual, `auto4` only IPv4 range, `auto6` only IPv6 (`warp address will only provide an IPv4 range... auto will provide ...` `HISTORY.md:4.x` Higlight 10)
  - How: `hiddify-core` Warp extension patches `wireguard` endpoint `reserved` + `endpoint` + noise; `enable-warp: false` (`#529` `enable-warp false`) toggles Warp overlay; `warp-detour-mode: outbound` stacks; also panel `WARP on Hiddify Manager` (`hiddify.com/manager/configuration-and-advanced-settings/How-to-activate-WARP-on-the-Hiddify-panel/`) generates `warp://` rows (up to 10 at once per `#529` comment *"it only accept 10 warp address at the same time"* but workaround via sing-box JSON 200 IPs `NiREvil/vless/hiddify/WARP200.json`)
  - FILE: `hiddify-core/extension/warp.go`, `lib/features/warp/warp_service.dart`, `hiddify.com/app/How-to-use-WARP-on-Hiddify-App:1-40`

- **Additional tricks:**
  - **Split HTTP / XHTTP:** sing-box 1.11 `splithttp` transport (HTTP/2 split) lets one logical stream spread across multiple HTTP requests (harder to fingerprint stream size); Hiddify 4.x notes *"Support for the new generation of Filtering circumvention as Split HTTP: This feature helps keep your CDN connections alive"* (`HISTORY.md:4.x` Higlight 4)
  - **Mux padding:** `mux-padding: false` when ON adds padding bytes per stream (obfuscates length)
  - **ECH:** listed in protocol line but not yet prominent — sing-box ECH `tls.ech` uses `ech_config_list` from DNS HTTPS RR; Hiddify would config via `ech` param in outbound `tls`
  - FILE: `sing-box/docs/configuration/outbound/vless#transport`, `hiddify-sing-box extended examples XHTTP`

## 9. Other Features — Remote Profiles, ETag, Config Editor, Speed Test, Warp Pro, etc.

- **Remote profiles & auto subscription update (ETag / conditional GET):**
  - HOW: Each `Profile` row in Drift `profiles` table stores `url`, `name`, `lastUpdate`, `etag`, `updateInterval` (minutes), `content`, `updateError`; `neat_periodic_task 2.0.1` timer triggers `ProfileRepository.updateAll()` every `updateInterval` (default user-chosen, e.g. 60 min); fetch via `dio` + `dio_smart_retry 7.0.1` + `cupertino_http 2.0.1` (Apple native HTTP) with headers `If-None-Match: <etag>` + `If-Modified-Since`; server 304 → skip parse; 200 → read new `etag` header, save content, re-parse via `ProfileParser`, update `subscription-info` traffic; `ETag` handling noted in DeepWiki: *"auto subscription update with ETag"* + `DeepWiki hiddify/hiddify-app: Subscription Management Auto-update, profile information (traffic, expiry), manual/QR/clipboard import"*
  - UI: `Home` page update button (circular arrow) (`hiddify.com/app/How-to-use-Hiddify-app: If you need to update your profile, click on this button` + screenshot `e5faed5f`); individual profile `Update` swipe; `Settings → General → Auto Update` (?) interval picker
  - FILE: `lib/features/profile/data/profile_repository.dart: updateProfile()`, `lib/features/profile/model/profile.dart: etag`, `lib/core/http/dio_provider.dart: interceptors`

- **Config editor (advanced, added 4.x):**
  - Highlight: *"Added a configuration editor: You can now edit configurations within the app using the EDIT option."* (`HISTORY.md: 4.x` Higlight 5); also *"Fix bug with alpn in configs"* same release
  - HOW: `Settings → Advanced → Config Options` has `EDIT` button → opens `lib/features/settings/presentation/config_editor_page.dart` which shows raw sing-box JSON (`json_annotation` model) with `lucy_editor`? (commented out `lucy_editor: ^1.0.5`, `re_highlight`, `json_editor_flutter` in `pubspec.yaml:18-22` — indicates editor was prototyped but shipped as `flutter_markdown_plus` + `json_path` editable?); toggle `execute-config-as-is: false` (`#529` `execute-config-as-is false`) → when `true` bypasses Hiddify's merger and runs JSON as-is (dangerous if user breaks `route`/`dns`)
  - FILE: `lib/features/config-editor/presentation/config_editor_page.dart`, `lib/singbox/model/config_option.dart: execute-config-as-is`, `pubspec.yaml: json_path`

- **Speed test / delay test:**
  - HOW: `Proxies` page bottom-right test button (`hiddify.com/app/How-to-use-Hiddify-app: If you need to test the delay, you should click on its button at the bottom right.` + screenshot `265bd648`); top-right sort button by name vs delay (`95ca6072`); each proxy row shows `delay ms` (`Proxies` screenshot `919020e5`); core `urltest` group auto-probes `url-test-interval 600s` → `connection-test-url http://cp.cloudflare.com` (lightweight 204); manual tap runs `Box.URLTest(tag)` via gRPC → returns ms or `timeout`/`error`
  - Unified delay: `hiddify-sing-box extended: Unified delay` feature normalizes delay across cores (Xray vs sing-box both report `urltest` ms compatible)
  - FILE: `lib/features/proxy/presentation/proxies_page.dart: delayTestButton`, `lib/hiddifycore/service/speed_test_service.dart`, `hiddify-core/extension/unified_delay.go`

- **Telegram group / channel / updater:**
  - Channel `t.me/hiddify` (blue badge: Channel), Support group `t.me/hiddify_board` (neon badge, `/5` pinned tutorial for HiddifyNext) (`README.md` 2 badges), YouTube `@hiddify`; updater: `upgrader 11.3.0` package shows banner if GitHub `releases/latest` version > current (`version 3.0.2` compare); `appcast.xml` (`appcast.xml` in root) for macOS Sparkle auto-update; `Sentry` reports crashes; `in_app_review 2.0.10` prompts Play/AppStore review
  - FILE: `appcast.xml`, `lib/features/updater/updater_service.dart`, `pubspec.yaml: upgrader, sentry_flutter, in_app_review`

- **Warp Pro / license & modes:**
  - Fields: `warp-license-key`, `warp-account-id`, `warp-access-token`, `warp-clean-ip`, `warp-port`, `warp-noise` in `ConfigOption` (`#529` all empty/auto); Pro license unlocks higher WARP+ quota (Cloudflare WARP+ `license` from `warp://License@IP`); `ifpm` `m1-m6`/`hHEX` needs license? Not required but Pro improves success rate
  - HOW: `Settings → WARP` page → paste `warp://` or set `ifpm` → `Save`; `warp-detour-mode` `outbound` routes all traffic through Warp after proxy (good for IP clean)
  - FILE: `lib/features/warp/presentation/warp_settings_page.dart`, `lib/singbox/model/config_option.dart: warp-*`

- **Other UX bits:**
  - **Profile info:** remaining days/traffic (`subscription-userinfo` bar + `Home` profile card `a69b2807`); `General` settings: Language, Theme Mode (dark/light/device), Pure Black, Start on Boot (`launch_at_startup`), Silent Start (tray only) (`hiddify.com/app/How-to-use-Hiddify-app: General settings` screenshot `4a00ed21`)
  - **System tray:** `tray_manager 0.5.0` + `window_manager 0.5.0` desktop tray icon states `connected`/`disconnected`/`dark` (`pubspec.yaml flutter assets: tray_icon*.png/.ico`); `screen_retriever` multi-monitor; `hotkey_manager`? (from `KaringX` but Hiddify similar)
  - **Multilang:** `project.inlang/` Fink editor 10+ langs (Fa, Ru, Zh, Ja, Br, En… badges `README.md: Translations` + `Translate with Inlang` shield); `Slang.md` conventions
  - **Direct single-config add:** `All Configs` user page → pick single `ss://...` → `Copy` → Home `+` → `Add from clipboard` (`hiddify.com/app/How-to-use-Hiddify-app: Add single configs` 4 steps + screenshots `eb4d7cf9` / `e515d2d7`)
  - FILE: `lib/features/settings/presentation/general_settings_page.dart`, `lib/features/tray/tray_service.dart`, `project.inlang/`, `lib/gen/strings.g.dart`

## 10. Platforms — Specific Notes

- **Android (Kotlin + VPNService + gomobile AAR):**
  - Build: `hiddify-core/Makefile: android` `CGO_LDFLAGS="-O2 -g -s -w -Wl,-z,max-page-size=16384" gomobile bind -v -androidapi=21 -javapkg=com.hiddify.core -libname=hiddify-core -tags=$(TAGS) -trimpath -ldflags="$(LDFLAGS)" -target=android -gcflags "all=-N -l" -o $(BINDIR)/$(LIBNAME).aar github.com/sagernet/sing-box/experimental/libbox ./platform/mobile` — note pageSize 16384 for Android 15+ 16K page (`hiddify-core/Makefile` `android` line)
  - Per-app: `addAllowedApplication` / `addDisallowedApplication`; needs `QUERY_ALL_PACKAGES` (Android 11+); Samsung tablets work, some phones deny 397/400 `app list` accesses due to `role` restriction (`#2140` comment Samsung vs phone)
  - Notification: `dynamic notifications` with real-time speed/traffic via `tint`? actually `toastification`
  - Store: Play badge live (`app.hiddify.com`), direct `universal`/`arm64`/`armv7`/`x86_64` APKs; F-Droid? no, Hiddify not on F-Droid (uses `app.hiddify.com` Play ID)
  - FILE: `android/app/src/main/kotlin/.../MainActivity.kt`, `android/app/src/main/AndroidManifest.xml: QUERY_ALL_PACKAGES, FOREGROUND_SERVICE, POST_NOTIFICATIONS`, `hiddify-core/Makefile: android`

- **iOS (Swift + NetworkExtension, via gomobile XCFramework):**
  - Build: `hiddify-core/Makefile: ios` `gomobile bind -v -target ios -libname=hiddify-core -tags=$(TAGS),$(IOS_ADD_TAGS) -trimpath -ldflags="$(LDFLAGS)" -o $(BINDIR)/HiddifyCore.xcframework ...` + `ios-full` variant (`ios,iossimulator,tvos,tvossimulator,macos`) that also produces `Libcore.podspec`/`HiddifyCore.podspec`
  - Extension: `ios/PacketTunnel/` + `ios/Runner/` bridge; `ios/PacketTunnelProvider.swift` `NEPacketTunnelProvider`; entitlements `networkextension` `packet-tunnel`; AppStore `Hiddify Proxy VPN` `id6596777532`; sideload IPA `Hiddify-iOS.ipa` for AltStore
  - Limits: No per-app VPN without MDM; TUN `includeAllNetworks` behaves like `bypass-lan: false`; iOS kills extension after 30? Keep-alive via `keep_alive`? Hiddify uses `NEFileProvider`? No, uses `packetFlow` keep alive
  - FILE: `ios/PacketTunnel/PacketTunnelProvider.swift`, `ios/Runner/Info.plist: CFBundleURLSchemes hiddify`, `hiddify-core/Info.plist`, `hiddify-core/Makefile: ios`

- **Windows (Flutter desktop + FFI + WinTun, MSIX/EXE/Portable):**
  - Builds: `Hiddify-Windows-Setup-x64.Msix` (signed, Store `9pdfnl3qv2s5`) vs `Setup-x64.exe` (Inno) vs `Portable-x64.zip`; `windows/runner/` + `windows/tun/`; `win32 5.12.0` for registry/custom scheme
  - TUN: requires admin (`Run as administrator`); WinTun adapter `Hiddify` `198.18.0.1`; fallback system proxy (`set-system-proxy`) uses `ProxyEnable`/`ProxyServer`/`ProxyOverride`;
  - Service mode: `enable-tun-service: false` when true runs as Windows Service (needs install via `launch_at_startup` + `windows/service/`); default user-mode
  - FILE: `windows/runner/main.cpp`, `windows/CMakeLists.txt`, `windows/tun/wintun.dll`, `lib/core/platform/windows_service.dart`

- **macOS (Flutter macOS + NetworkExtension + FFI, DMG/PKG/AppStore):**
  - Builds: AppStore universal `Hiddify Proxy VPN` same iOS id; direct `Hiddify-MacOS.dmg` (drag to Applications) + `Hiddify-MacOS-Installer.pkg` (installer); `macos/Runner/` `PacketTunnelProvider.swift` same as iOS but macOS entitlements `com.apple.developer.networking.networkextension.packet-tunnel-provider` + `system-extension`
  - TUN: needs root via `sudo` Terminal one-shot (`sudo /Applications/HiddifyNext.app/Contents/MacOS/HiddifyNext`) then `Enable TUN` persists (chooses `packet-tunnel` provider vs `system-proxy`); macOS `tray_manager` + `window_manager` menubar; `screen_retriever`
  - FILE: `macos/Runner/AppDelegate.swift`, `macos/Packaging/`, `hiddify-core/Makefile: ios-full` includes `macos` target

- **Linux (Flutter Linux + FFI, AppImage/deb/rpm, glibc):**
  - Builds: `Hiddify-Linux-x64.AppImage` (universal, `chmod +x` + `sudo ./AppImage`), `Hiddify-Debian-x64.deb` (`dpkg -i`), `Hiddify-rpm-x64.rpm` (`rpm -i`), `snap/gui/` Snap; `linux/` folder, `linux_deps.list` lists `libayatana-appindicator3-dev` etc. for tray
  - TUN: `gvisor` often used (no kernel module, but less perf); `system` TUN needs `CAP_NET_ADMIN` (`sudo`); `linux/my_application.cc` handles window; `tray_manager` via `libappindicator`
  - OpenWrt: `hiddify-core` also runs as **router core** (`platform/wrt/README.md`, `.fpm_openwrt`) — `hiddify-core.tar.gz` + `installer.sh` `bash <(curl https://i.hiddify.com/core)` detects OpenWrt `procd` vs `systemd` — lets router clients behind OpenWrt get free internet via `HiddifyCli` (`hiddify.com/app/How-to-Enable-Free-Internet-Access-for-Clients-Behind-an-OpenWrt-Router-Using-HiddifyCli/`)
  - FILE: `linux/my_application.cc`, `linux/CMakeLists.txt`, `linux_deps.list`, `hiddify-core/platform/wrt/`, `hiddify-core/installer.sh`

- **Shared Flutter quirks:**
  - Deep links: `app_links 6.4.0` `hiddify://` registered per OS (`AndroidManifest` `intent-filter`, `Info.plist` `CFBundleURLSchemes`, `windows` registry `win32` `RegisterClass`, Linux `hiddify.desktop` `MimeType=x-scheme-handler/hiddify`);
  - Fonts: `Vazirmatn Font by Saber Rastikerdar` (`pubspec.yaml fonts: Shabnam` + `Vazirmatn` in `README.md Acknowledgements`) — Persian-friendly UI (makes sense for Iran focus)
  - Assets: `world_map.png` home background, `logo.svg` `hiddify-app-logo.svg`

## 11. Repo Stats, Build Instructions & File Map

- **Repo stats (snapshot 2026-08-30 fetch):**
  - `hiddify/hiddify-app`:
    - HOW: `32.4k ★` (GitHub button `Star 32.4k`), `3.0k forks`, `197 watching`, `2,821 commits` (`History` button), `main` default branch, `89 releases` (`Releases 89` sidebar), latest `v4.1.2 (2026-03-05)` (`HISTORY.md:4.1.2`), prior `v4.1.1` `2026-03?` with Xray, `v2.5.7 (2024-10-03)` prerelease (`releases/tag/v2.5.7` badge 324 👍 25 😄), topics 17 `clash`/`clashmeta`/`ech`/`hysteria`/`hysteria2`/`proxy`/`reality`/`shadowsocks`/`shadowtls`/`sing-box`/`singbox`/`ssh`/`tuic`/`v2ray`/`vless`/`vmess`/`wireguard`/`xray`
    - Issues `29` open, PRs `10` open (`nav` bar); submodule `hiddify-core @ f2034de743b1ad...` (`Folders and files` line)
    - License sidebar `GPL-3.0` but `LICENSE.md` extended text (Hiddify Extended)
  - `hiddify/hiddify-core`:
    - HOW: `231 ★`, `184 forks`, `7 watchers`, `743 commits`, `34 open issues`, `8 PRs` (`hiddify-core` page); submodules `hiddify-sing-box @ 170d831`, `ray2sing @ caf5e9a`; no description/topics (blank About)
  - `hiddify/hiddify-sing-box`:
    - HOW: `58 ★` (`hiddify-sing-box` extending header), `43 forks`, `1 open issue`, `extended` branch, fork from `SagerNet/sing-box` 2023-05-14; core version pinned via `.github/CRONET_GO_VERSION` etc.

- **Build — Flutter + Go mobile (from Makefile + pubspec):**
  - Prereqs: Flutter `3.38.5` (`pubspec.yaml: flutter ^3.38.5`, comment strictly required), Dart `3.10.4`, Go `1.22+` (gomobile `v0.1.11` `go install github.com/sagernet/gomobile/cmd/gomobile@v0.1.11` + `gobind` in `hiddify-core/Makefile: lib_install`), `gomobile` `androidapi=21`, `npm` (for extension build), `protobuf` (`protoc`) if regenerating `grpc` (commented `protoc_plugin` steps in `pubspec.yaml` `protobuf` notes), `ffi` headers via `ffigen` 19.1
  - **Desktop (Windows/Linux/macOS) FFI:**
    - HOW: `make lib_install` → `go install gomobile` + `npm install`; `make desktop` (hidden target) compiles `hiddify-core` to `bin/desktop.h` + `libhiddify-core.{so,dylib,dll}` via `go build -buildmode=c-shared -tags ...`; `ffigen` regenerates `lib/gen/hiddify_core_generated_bindings.dart` from `hiddify-core/bin/desktop.h` (`pubspec.yaml: ffigen name: HiddifyCoreNativeLibrary`); then `flutter build windows|macos|linux --release`
    - FILE: `Makefile: lib_install`, `Dockerfile: FROM ghcr.io/cirruslabs/flutter:3.38.5...`, `hiddify-core/bin/desktop.h`
  - **Android AAR:**
    - HOW: `make android` in `hiddify-core` → `CGO_LDFLAGS="-O2 -g -s -w -Wl,-z,max-page-size=16384" gomobile bind -v -androidapi=21 -javapkg=com.hiddify.core -libname=hiddify-core -tags=$(TAGS) -trimpath -ldflags="$(LDFLAGS)" -target=android -gcflags "all=-N -l" -o $(BINDIR)/$(LIBNAME).aar github.com/sagernet/sing-box/experimental/libbox ./platform/mobile` (`hiddify-core/Makefile: android`) → output `build/HiddifyCore.aar`; Flutter `flutter build apk --split-per-abi` (produces `universal`+`arm64`+`armv7`+`x86_64` as in Direct Download table) or `flutter build appbundle`
    - Old `hiddify-core` used `io.nekohasekai` pkg (`hiddify-sing-box Makefile: android: -javapkg=io.nekohasekai`), new uses `com.hiddify.core` (migration visible in Makefile diff `Makefile at c9d6f0f` vs `4e7fe336`)
    - FILE: `android/app/build.gradle`, `android/local.properties`, `hiddify-core/Makefile: android`
  - **iOS / macOS XCFramework:**
    - HOW: `make ios` → `gomobile bind -v -target ios -libname=hiddify-core -tags=$(TAGS),$(IOS_ADD_TAGS) -trimpath -ldflags="$(LDFLAGS)" -o $(BINDIR)/HiddifyCore.xcframework ...` → `cp Info.plist` + `HiddifyCore.podspec`; `make ios-full` → `-target ios,iossimulator,tvos,tvossimulator,macos` produces universal `xcframework` for dev + Mac; then `flutter build ipa` / `flutter build macos`
    - FILE: `hiddify-core/Makefile: ios`, `hiddify-core/Info.plist`, `ios/Podfile`, `macos/Podfile`
  - **Docker (CI):**
    - HOW: `Dockerfile: FROM cirruslabs/flutter:3.38.5` (parsed from `pubspec.yaml` grep) → `make lib_install` → `flutter pub get` → `dart run build_runner build` (generates `freezed`/`json_serializable`/`drift_dev`/`riverpod_generator`/`slang_build_runner`/`flutter_gen`/`dart_mappable_builder` — `pubspec.yaml dev_dependencies: build_runner, build_runner 2.4.13, freezed 2.4.7, drift_dev 2.21.0, ffigen 19.1.0`) → `flutter build ...`
    - FILE: `Dockerfile`, `Makefile: prepare`, `build.yaml`, `analysis_options.yaml`

- **Dev loop (quick edits, no core rebuild):**
  - HOW: If only Dart changed: `flutter run -d windows|macos|linux|android|ios` (hot reload works, core via previously built AAR/XCFramework/FFI lib cached in `build/`); if Go changed: must `make android/ios/desktop` before `flutter run`; gen files: `dart run build_runner build --delete-conflicting-outputs` after model edits (`build.yaml` triggers `freezed`, `json_serializable`, `drift_dev`, `riverpod_generator`, `slang_build_runner`)
  - FILE: `Makefile`, `CONTRIBUTING.md`, `lib/bootstrap.dart`

- **File map (key paths):**
  - `README.md` — main overview, features, stores, direct download matrix
  - `LICENSE.md` — Hiddify Extended GPL-3.0 + full GPL-3.0 text
  - `pubspec.yaml` — Flutter 3.38.5 / Dart 3.10.4, deps (`drift`, `riverpod`, `dio`, `ffi`, `grpc`, etc.), assets, ffigen
  - `lib/main.dart` / `lib/main_prod.dart` / `lib/bootstrap.dart` / `lib/riverpod.dart` — app entry + DI
  - `lib/core/` + `lib/hiddifycore/` — core abstraction (`HiddifyCoreService`, `CoreInterface`)
  - `lib/features/profile/` — profile fetch/parse (V2Ray/Clash/sing-box), Drift DB, `ray2sing` call, ETag, subscription-info
  - `lib/features/proxy/` — `Proxies` page, delay test, selector
  - `lib/features/settings/` — General, Routing, Per-app, DNS, Config Options, TUN toggle, WARP settings, theme
  - `lib/singbox/model/` — `SingboxConfigOption`, `ConfigOption`, `DnsConfig`, `Rule`, `TlsTricks` → `generate()` to final JSON
  - `lib/gen/` — generated (`hiddify_core_generated_bindings.dart` via ffigen, `strings.g.dart` via slang, `assets.gen.dart` via flutter_gen)
  - `lib/utils/` — `humanizer`, `recase`, `basic_utils`, `path`, `loggy`
  - `android/` — Kotlin `MainActivity`, `VpnService`, `PerAppProxyPlugin`, `AndroidManifest` perms
  - `ios/` + `macos/` — Swift `PacketTunnelProvider.swift`, entitlements, `Runner.xcodeproj`
  - `windows/` + `linux/` — runner (`main.cpp`/`my_application.cc`), CMake, `linux_deps.list`
  - `hiddify-core/` — **submodule** `@ f2034de` → Go core wrapper; `hiddify-sing-box @ 170d831` (extended fork), `ray2sing @ caf5e9a`, `platform/mobile`, `extension/`, `cmd/`, `bin/desktop.h`, `Makefile` (`android`/`ios`/`lib_install`)
  - `test.configs/` — sample subs (sing-box JSON, Clash YAML, V2Ray base64, `warp`, `reality` etc.)
  - `test/` — dart tests (unit for parser/config)
  - `scripts/` — release notes, icon gen
  - `project.inlang/` — i18n source (10+ langs)
  - `snap/gui/` — Snapcraft packaging
  - `appcast.xml` — Sparkle update manifest
  - `dependencies.properties` — sing-box rev pin
  - `CONTRIBUTING.md` — asks for Flutter/Go/iOS Swift/Android Kotlin contributors + email `contribute@hiddify.com`

- **Top-level config snapshots (from `#529` debug dump — real config emitted):**
  - `execute-config-as-is: false`, `log-level: debug`, `resolve-destination: false`, `ipv6-mode: ipv4_only`, `remote-dns-address: udp://1.1.1.1`, `remote-dns-domain-strategy: ""`, `direct-dns-address: 1.1.1.1`, `direct-dns-domain-strategy: ""`, `mixed-port: 2334`, `local-dns-port: 6450`, `tun-implementation: mixed`, `mtu: 9000`, `strict-route: true`, `connection-test-url: http://cp.cloudflare.com/`, `url-test-interval: 600`, `enable-clash-api: true`, `clash-api-port: 6756`, `enable-tun: true`, `enable-tun-service: false`, `set-system-proxy: false`, `bypass-lan: false`, `allow-connection-from-lan: false`, `enable-fake-dns: false`, `enable-dns-routing: true`, `independent-dns-cache: true`, `enable-tls-fragment: false`, `tls-fragment-size: 1-500`, `tls-fragment-sleep: 0-500`, `enable-tls-mixed-sni-case: false`, `enable-tls-padding: false`, `tls-padding-size: 1-1500`, `enable-mux: false`, `mux-padding: false`, `mux-max-streams: 8`, `mux-protocol: h2mux`, `enable-warp: false`, `warp-detour-mode: outbound`, `warp-license-key: ""`, `warp-account-id: ""`, `warp-access-token: ""`, `warp-clean-ip: auto`, `warp-port: 0`, `warp-noise: ""`, `geoip-path: geo-assets/sagernet-sing-geoip-geoip.db`, `geosite-path: geo-assets/sagernet-sing-geosite-geosite.db`, `rules: [{domains: domain:.ir,geosite:ir, ip: geoip:ir, port: null, protocol: null, network: "", outbound: bypass}]`
  - HOW to verify: run app with `log-level: debug` → logcat/Xcode console prints `ConnectionRepositoryImpl: config options: { ... }` (`issue #529` log `01:35:15.479491 - [I] ConnectionRepositoryImpl: config options:`)

## 12. References

- **Repos:**
  - App: `https://github.com/hiddify/hiddify-app` (main, `hiddify-next` redirect) — `README.md:1`, `pubspec.yaml:1`, `LICENSE.md:1`, `HISTORY.md:4.1.2`, `Makefile`, `hiddify-core @ f2034de`
  - Core: `https://github.com/hiddify/hiddify-core` — `README.md`, `Makefile: android/ios`, `go.mod`, `platform/`, `extension/`, `ray2sing @ caf5e9a`
  - Fork: `https://github.com/hiddify/hiddify-sing-box` (`extended` branch) — `extended` examples, `box.go:60-80` InvalidConfig patch
  - Converter: `https://github.com/hiddify/ray2sing` — `clash.go`/`sing.go`
  - Upstream: `https://github.com/SagerNet/sing-box` — `sing-box.sagernet.org` docs, `sing-box 1.11.0` changelog (`rule actions`, `gvisor compat`, `WireGuard endpoint`, `Hysteria2 port hopping`)
  - Upstream Apple/Android: `https://github.com/SagerNet/sing-box-for-android`, `https://github.com/SagerNet/sing-box-for-apple` (Acknowledgements `README.md`)

- **Docs / guides:**
  - `https://hiddify.com/app/` (App Guide index)
  - `https://hiddify.com/app/How-to-use-Hiddify-app/` (software install, adding profile via `Tap to Start Anti-Filter` / `Copy Link` → `+` → `Add from clipboard`/`Add manually`, working/connect, checking proxies/delay, General/Advanced/TUN enable with admin per OS)
  - `https://hiddify.com/app/How-to-install-Hiddify-app/` (install per OS)
  - `https://hiddify.com/app/URL-Scheme/` + `https://github.com/hiddify/hiddify-app/wiki/URL-Scheme` (`hiddify://import/<sublink>#name`, `hiddify://install-sub?url=`, `vmess://`, `vless://`, `ss://`, `trojan://`, base64 vs normal, Singbox JSON, Clash YAML, `detour`)
  - `https://hiddify.com/app/How-to-use-WARP-on-Hiddify-App/` (`warp://auto`, `warp://auto&&detour=WARP://auto`, `warp://License@IP:port?ifp=...&ifpm=m4`, WoW, `auto4`/`auto6`/`auto` IPv)
  - `https://hiddify.com/app/How-to-use-UDP-Turn-Relay/` (UDP relay)
  - `https://hiddify.com/manager/` (Manager guide, reality scanner, WARP on panel, domain/worker/CDN/tunneling)
  - `https://hiddify.com/manager/configuration-and-advanced-settings/How-to-use-Reality-on-Hiddify/`
  - `https://hiddify.com/manager/configuration-and-advanced-settings/How-to-use-Hiddify-Reality-Scanner/`
  - `https://hiddify.com/manager/basic-concepts-and-troubleshooting/How-the-TLS-Trick-works-and-its-usage/` + `A-good-way-to-find-TLS-trick-values/`
  - `https://hiddify.com/manager/basic-concepts-and-troubleshooting/How-to-check-and-prevent-DNS-leaks/`
  - `https://hiddify.com/manager/configuration-and-advanced-settings/How-to-activate-WARP-on-the-Hiddify-panel/`

- **Releases / changelogs:**
  - `https://github.com/hiddify/hiddify-app/releases` (`v4.1.2`, `v4.1.1` Xray dual-core, `v2.5.7` 2024-10-03)
  - `https://github.com/hiddify/hiddify-app/blob/main/HISTORY.md` (4.1.2 2026-03-05, `Added Advanced Config Editor`, `Added Xray core`, `Support Split HTTP`, `IPv4/IPv6 WireGuard`, `6 Warp modes m1-m6 hHEX`)
  - `appcast.xml` (macOS Sparkle)

- **Sing-box core docs:**
  - `https://sing-box.sagernet.org/` (universal proxy platform, `sing-box 1.11.0` release notes, `Hysteria2` page `up_mbps/down_mbps/obfs/masquerade/realm/port hopping`, `Listen Fields` `sniff` deprecation, `Deprecated` page `Legacy special outbounds`/`WireGuard outbound`/`GSO in TUN`)
  - `https://sing-box.sagernet.org/configuration/inbound/hysteria2/` + `changelog` (1.11 rule_actions, tun_compat, `network_type` rule, `cache_capacity`, `override_address`, etc.)
  - DeepWiki: `https://deepwiki.com/hiddify/hiddify-app` + `https://deepwiki.com/SagerNet/sing-box/4.2-proxy-protocol-implementations` (C.Type constants, InboundOptions/OutboundOptions structs)

- **Store listings:**
  - iOS: `https://apps.apple.com/us/app/hiddify-proxy-vpn/id6596777532`
  - Android: `https://play.google.com/store/apps/details?id=app.hiddify.com`
  - Windows: `https://apps.microsoft.com/detail/Hiddify/9pdfnl3qv2s5`
  - Direct: `https://github.com/hiddify/hiddify-app/releases/latest/download/Hiddify-Android-universal.apk` / `apk arm64/7/x64` / `Hiddify-Windows-Setup-x64.Msix/.exe/.zip` / `Hiddify-iOS.ipa` / `Hiddify-MacOS.dmg/.pkg` / `Hiddify-Linux-x64.AppImage/.deb/.rpm`

- **Community / support:**
  - Telegram channel `https://t.me/hiddify` + board `https://t.me/hiddify_board` + group `https://telegram.dog/hiddify` / `.../hiddify_board/5` (`README.md` badges)
  - YouTube `https://www.youtube.com/@hiddify`, Twitter `https://twitter.com/intent/follow?screen_name=hiddify_com`, email `contribute@hiddify.com`
  - Inlang `https://fink.inlang.com/github.com/hiddify/hiddify-app` (`README.md Translations`)
  - Issues: `https://github.com/hiddify/hiddify-app/issues/529` (Warp invalid configs, log dump), `https://github.com/hiddify/hiddify-app/issues/2140` (per-app proxy fails, DNS IPV4 ONLY fix)

---

> **Notes on HOW bullets:** Each `HOW:` sub-bullet cites a file + line or URL section + explains the runtime mechanism (Dart→Go→OS) so a reader can reproduce/inspect the behavior from source. Line numbers are approximate against `main` 2026-08-30; grep the filename for the symbol if offset drifts. Sing-box upstream lines reference `sing-box.sagernet.org` docs (versioned), Hiddify patches reference `hiddify-sing-box/box.go` and `hiddify-core/Makefile` as fetched.
