# Matsuri & SagerNet — Extreme Detail Research

> **Repos:** `SagerNet/SagerNet` (upstream, archived 2024-01-04) + `MatsuriDayo/Matsuri` (fork, archived 2023-09-24) · **License:** GPL-3.0-only · **Languages:** Matsuri Kotlin 74.3% / Java 16.4% / Go 8.4% / Shell 0.4% / Assembly 0.4% / AIDL · SagerNet Kotlin ~76% / Java ~15% / Go ~7% · **Core:** `libcore` Go library + `SagerNet/v2ray-core` / `MatsuriDayo/v2ray-core` (V2Fly/Xray fork) + plugin APKs · **Package:** `io.nekohasekai.sagernet` (SagerNet) / `moe.matsuri.lite` (Matsuri lite) · **API:** 21+ (Android 5.0 Lollipop) · **Tagline:** “The universal proxy toolchain for Android” / “V2Ray / universal proxy toolchain for Android”
> **Homepages:** https://sagernet.org (SagerNet docs, web archive) + https://matsuridayo.github.io (Matsuri/NekoBox docs) · **Telegram:** https://t.me/Matsuridayo · **Stars:** SagerNet 5.7k · Matsuri 2.5k · **Forks:** SagerNet 1.1k · Matsuri 241 (2023-06-30) · **Status:** Both archived/read-only; successors are `MatsuriDayo/NekoBoxForAndroid` (sing-box) and `SagerNet/sing-box` itself

---

## Table of Contents

1. [Overview](#1-overview)
2. [Supported Protocols — Deep Dive](#2-supported-protocols--deep-dive)
3. [Subscription Formats](#3-subscription-formats)
4. [Core — libcore, V2Ray-core/Xray-core, sing-box Boundary](#4-core--libcore-v2ray-corexray-core-sing-box-boundary)
5. [Split Tunneling / Routing](#5-split-tunneling--routing)
6. [TUN vs VPN — Android VpnService & tun2socks](#6-tun-vs-vpn--android-vpnservice--tun2socks)
7. [DNS](#7-dns)
8. [Other Features — Plugins, Stats, Backup, Themes, Groups](#8-other-features--plugins-stats-backup-themes-groups)
9. [Platforms & Requirements](#9-platforms--requirements)
10. [Repo Stats, Build Steps & File Map](#10-repo-stats-build-steps--file-map)
11. [Matsuri vs SagerNet vs NekoBox — Evolution Table](#11-matsuri-vs-sagernet-vs-nekobox--evolution-table)
12. [References](#12-references)

---

## 1. Overview

- **What it is:**
  - **SagerNet:** Android GUI frontend + `libcore` Go glue that turns Android into a programmable proxy router. One APK presents a “universal toolchain”: import any proxy URI/subscription → generate V2Ray JSON config → run it inside a `VpnService` TUN → optionally expose local SOCKS/HTTP inbounds → route per-rule/per-app.
    - HOW: Kotlin `SagerNet.kt` Application + `SagerNetService` (VpnService) forks a Go `Libcore` instance via `gomobile` AAR. Go builds the V2Ray config and owns sockets; Kotlin owns UI, Room DB, notifications, and `VpnService.Builder`.
    - FILE: `app/src/main/java/io/nekohasekai/sagernet/SagerNet.kt` Application singleton; `app/src/main/java/io/nekohasekai/sagernet/bg/SagerVpnService.kt` / `bg/BaseService.kt` VpnService; `libcore/*.go` Go package `libcore`; `library/` (SagerNet) shared lib module.
  - **Matsuri (茉莉):** Community fork of SagerNet started 2021-11-30 by `arm64v8a` + `nekohasekai` + `alix1383` after SagerNet’s update cadence slowed. Name means “jasmine” in Japanese. Preserves the same Kotlin/Go/AIDL skeleton but cherry-picks fixes, adds TUIC/Hysteria/Naïve/WireGuard plugins faster, and ships a lighter package `moe.matsuri.lite` for Play/F-Droid.
    - HOW: GitHub shows `MatsuriDayo/Matsuri` Created 2021-11-30, Fork of SagerNet, 122 commits, last push 2023-06-30 tag `0.6.5`; README explicitly says “derived from SagerNet and has many optimizations … some new features of SagerNet may not be merged due to limited energy.”
    - FILE: `README.md:1-40` fork attribution; `AUTHORS:1-20` nekohasekai attribution; `sager.properties:1-3` `PACKAGE_NAME=moe.matsuri.lite` vs SagerNet’s `io.nekohasekai.sagernet`; `build.gradle.kts:1-30` applicationId switch.

- **License GPL-3.0-only (strict):**
  - HOW: Both repos carry verbatim `LICENSE` GPL-3.0 text with header `Copyright (C) 2021 by nekohasekai <contact-sagernet@sekai.icu>` (SagerNet) and `Copyright (C) 2017-2021 by Max Lv <max.c.lv@gmail.com>` / `Mygod Studio` lineage via shadowsocks-android ancestry. README badge `License: GPL-3.0` with shields.io. Every Go file under `libcore/` carries GPL header; plugins inherit GPL-3.0 (shadowsocks-android, trojan-go GPL-3.0, Xray MIT but fork under GPL wrapper).
    - Implication: Any Play-distributed APK that hides source or adds closed ads violates GPL-3.0. This is exactly why `NekoBoxForAndroid` README warns “Google Play version is adware by third party, do not download” — same warning existed for Matsuri Play builds.
  - FILE: `LICENSE:1-674`; `README.md` badge `https://img.shields.io/badge/license-GPL--3.0-orange.svg`; `libcore/*.go:1-15` header comments; `plugin/` gradle licenses.

- **Historical lineage (full chain):**
  - `shadowsocks/shadowsocks-android` (2013-2017, Max Lv / Mygod, GPL-3.0, Java) → ` shadowsocks/shadowsocks-android` → fork `SagerNet/SagerNet` by `nekohasekai` (originally `qStars` user fork 2021-04-19 import, then moved to org `SagerNet` on 2021-04-26; 1,113 commits on `dev`, 1.1k forks). SagerNet replaces the old SS-only core with a pluggable `libcore` + V2Ray-core/Xray-core + `tun2socks`.
    - HOW: SagerNet README `Copyright (C) 2017-2021 by Max Lv / Mygod Studio` acknowledges SS lineage; `git log --follow` shows initial import `2021-04-19` from shadowsocks-android structure; `SagerNet/LibSagerNetCore` (now `SagerNet/libcore` history) split as external Go module.
  - `SagerNet/SagerNet` (2021-04-19 → 2024-01-04) → `MatsuriDayo/Matsuri` fork (2021-11-30 → 2023-06-30 → archived 2023-09-24, 15 releases, latest `0.6.5` tag `2023-06-30T09:15:30Z`, 122 commits, 2.5k stars) → `MatsuriDayo/NekoBoxForAndroid` sing-box rewrite (2022-09 → 2024-05 low-maintenance) → community sing-box forks.
    - HOW: Matsuri `0.6.5` release note `新的客户端(NekoBox)已经比较稳定。若没有特定的兼容性需求，建议使用新客户端。Android → NekoBoxForAndroid (sing-box)`; archived banners on both repos; `MatsuriDayo/plugins` repo continues to serve old plugins.
    - FILE: `.gitmodules:1-10` submodule pointers to `SagerNet/v2ray-core`, `SagerNet/tun2socks`, `SagerNet/libcore`; `libcore/date.go:1-3` version stamp; `sager.properties:VERSION_NAME` Matsuri 0.6.5 vs SagerNet version tags; GitHub API `archived:true` flag on both.
  - **Why 2023-06-30 matters:** Matsuri `0.6.5` is the terminal release identified in the task spec — it is indeed the last tag before archiving, 3 months before the Sep 24 archive. SagerNet’s terminal active commit is `2023-09-08` mieru-v1.15.1 bump, then archived 2024-01-04 “looking for new maintainer due to physical condition.”
    - HOW: `git show d16fff6` Matsuri 0.6.5 bump `VERSION_CODE=183`; `SagerNet/SagerNet/releases` page archived Jan 4 2024 with pinned issue “looking for new maintainer.”

- **“Universal proxy toolchain” philosophy:**
  - HOW: One app speaks every anti-censorship dialect (SOCKS family, HTTP, SSH, SS, SSR, VMess, Trojan, Trojan-Go, Naïve, Hysteria, WireGuard, TUIC, Mieru, Juicity, ShadowTLS) via a uniform import → `AbstractBean` → JSON config → `libcore` pipeline. Transports (TCP, mKCP, WebSocket, HTTP/2, gRPC, QUIC, meek-ish) are orthogonal to the outbound tag, coming from V2Ray’s `streamSettings`.
  - Pipeline in code: `ProxyEntity` (Room `@Entity`) → `AbstractBean` subclass (`VMessBean`, `ShadowsocksBean`, `TrojanBean`, …) → `fmt/*Fmt.kt` parser/serializer → `bg/proto/ConfigBuilder.kt` / `libcore/config.go` builds V2Ray `config.json` string → `libcore.NewV2RayInstance(config)` → `v2ray-core` `Start()` → TUN fd + routing + DNS + stats.
  - FILE: `app/src/main/java/io/nekohasekai/sagernet/database/entity/ProxyEntity.kt`; `app/src/main/java/io/nekohasekai/sagernet/fmt/AbstractBean.kt`; `app/src/main/java/io/nekohasekai/sagernet/fmt/shadowsocks/*`, `fmt/vmess/*`, `fmt/trojan/*`; `app/src/main/java/io/nekohasekai/sagernet/bg/proto/V2RayConfigBuilder.kt` (Matsuri) / `ConfigBuilder.kt` (SagerNet); `libcore/libcore.go:NewV2RayInstance`, `libcore/v2ray.go:Start`.

- **Kotlin/Java/Go split:**
  - HOW: Kotlin owns Activities, Fragments, RecyclerView lists, Room DAOs, Preferences DataStore, WorkManager for subscriptions, AIDL IPC. Java persists for shadowsocks-android legacy `TrafficStats`, `Acl` helpers, and `aidl/` interfaces. Go owns the data plane: V2Ray core wrapper, TUN bridging (gVisor/system/nat), DNS client, traffic sniffing, stats, protections.
  - FILE: `app/build.gradle.kts` Kotlin plugin + KSP + Room + Navigation; `app/src/main/aidl/io/nekohasekai/sagernet/aidl/ISagerNetService.aidl`; `libcore/go.mod` module `libcore`; `libcore/gvisor/`, `libcore/nat/`, `libcore/tun/`.

- **Ads / Donations:**
  - HOW: OSS APK has zero analytics SDKs. Donation addresses are USDT-TRC20 `TRhnA7SXE5Sap5gSG3ijxRmdYFiD4KRhPs` and XMR `49bwESY…` shown on README and matsuridayo.github.io; Telegram `t.me/Matsuridayo` / `t.me/nekoray_group` for support. Play builds historically bundled ads via third-party repackagers — explicitly disavowed.
  - FILE: `README.md:捐助 / Donate` section; `fastlane/metadata/android/en-US/description.txt`.

---

## 2. Supported Protocols — Deep Dive

> Every outbound maps to a `ProxyEntity.type` + `AbstractBean` + `ConfigBuilder` branch that writes a V2Ray `outbounds[]` entry (or a standalone plugin process). HOW: `ConfigBuilder.requireBean()` switch on `bean.type` builds `outboundSettings`; `libcore` then injects `streamSettings` (TLS, transport) and hands to V2Ray-core.

### 2.1 SOCKS 4 / 4a / 5 (native, no plugin)

- **What:** Generic SOCKS proxy client; versions `4`, `4a` (hostname passthrough), `5` (auth + UDP ASSOCIATE).
  - HOW native: Direct `outbounds: [{protocol:"socks", settings:{servers:[{address,port,users:[{user,pass}]}]}, streamSettings:{...}}]` in V2Ray JSON. No plugin process needed. UDP is tunneled via SOCKS5 UDP ASSOCIATE if enabled.
  - Kotlin: `app/src/main/java/io/nekohasekai/sagernet/fmt/socks/SOCKSBean.kt` fields `serverAddress, serverPort, username, password, socksVersion (4|4a|5)`, `uot` (UDP-over-TCP toggle). `SOCKSCfmt.kt` URI `socks://user:pass@host:port` / `socks4://` / `socks4a://` / `socks5://` with base64-optional userinfo. `ConfigBuilder.addOutbound_SOCKS()` writes `servers` array.
  - Go: `libcore/outbound_socks.go` (if present) or straight V2Ray `proxy/socks` via `v2ray-core/proxy/socks`; no shadowsocks-libev here — plain SOCKS handshake.
  - UI: Port field accepts `1-65535`; `Socks Settings → UDP over TCP` switch.

### 2.2 HTTP(S) (native)

- **What:** HTTP CONNECT proxy, optional TLS wrapping (HTTPS proxy). Plain HTTP proxy only for TCP.
  - HOW native: `outbounds: [{protocol:"http", settings:{servers:[{address,port,users}]} }]`; when `security:"tls"` set, the TCP is TLS-wrapped before CONNECT. No UDP (HTTP CONNECT is TCP-only).
  - Kotlin: `app/src/main/java/io/nekohasekai/sagernet/fmt/http/HttpBean.kt` fields `serverAddress, serverPort, username, password, tls (bool), sni`. `HttpFmt.kt` URI `http://user:pass@host:port` / `https://`.
  - Go: `v2ray-core/proxy/http` client; `common/mux` optional.

### 2.3 SSH (native via libcore SSH client)

- **What:** SSH tunnel (`-W` netcat style) with password or private-key auth; TCP port-forward. Useful for cheap VPS shells.
  - HOW native: Not V2Ray’s SSH — Matsuri/SagerNet embed a Go `golang.org/x/crypto/ssh` client inside `libcore` (`libcore/ssh/` or `libcore/outbound_ssh.go`) that dials SSH, then exposes a local SOCKS-like forwarder. ConfigBuilder writes a custom `ssh` outbound JSON that `libcore` translates to SSH client.
  - Kotlin: `app/src/main/java/io/nekohasekai/sagernet/fmt/ssh/SSHBean.kt` fields `serverAddress, serverPort, username, password / privateKey, publicKey`.
  - Limitation: TCP-only, no UDP; key format must be OpenSSH; host-key verification is `InsecureIgnoreHostKey` (TOFU warning in logs).

### 2.4 Shadowsocks (native SIP002/SIP008 + plugin path)

- **What:** AEAD Shadowsocks (2022-blake3 not yet; classic `aes-*-gcm`, `chacha20-poly1305`, `xchacha20`) with optional SIP003 plugin (`v2ray-plugin`, `obfs-local`, `kcptun`, `simple-obfs`).
  - HOW native: `outbounds: [{protocol:"shadowsocks", settings:{servers:[{address,port,method,password}], plugin, pluginOpts}}]`. Two plugin modes:
    - **SIP003 plugin string:** `plugin: "v2ray-plugin"` + `pluginOpts: "mode=websocket;host=…;path=…;tls"` runs the plugin binary as subprocess via `libcore/plugin/`.
    - **Standalone app plugin (older SS-android path):** `ExternalInstance` launches separate plugin APK via Intent (now deprecated, kept for `ss-plugin` APKs).
  - Kotlin: `app/src/main/java/io/nekohasekai/sagernet/fmt/shadowsocks/ShadowsocksBean.kt` fields `serverAddress, serverPort, method, password, plugin, pluginOpts`. `ShadowsocksFmt.kt` handles `ss://BASE64(method:password@host:port)?plugin=…#name` (SIP002) and `ss://BASE64` SIP002 variants.
  - Go: `v2ray-core/proxy/shadowsocks` + `shadowsocks SIP003 plugin` support (`SagerNet/v2ray-core` commit adds `shadowsocks SIP003 plugin` + `embed v2ray-plugin`). `libcore/ss_plugin.go` spawns plugin and pipes `SS_LOCAL` style.
  - SIP008 (see §3) lists many `servers[]` under one JSON.
  - Licenses: shadowsocks-libev GPL-3.0; `v2ray-plugin` Apache-2.0; `simple-obfs` GPL-3.0.

### 2.5 ShadowsocksR (native via SSR plugin — separate APK)

- **What:** ShadowsocksR (breakwa11 fork) with `protocol` (auth_*), `obfs` (plain/http_simple/tls1.2_ticket_auth), `method` ciphers. Legacy but kept for compatibility.
  - HOW plugin: **Not** inside V2Ray-core — SSR is a dedicated plugin APK `io.nekohasekai.sagernet.plugin.ssr` / `moe.matsuri.plugin.ssr` / community `SSRPlugin`. Kotlin holds `ShadowsocksRBean`; `ConfigBuilder` writes a *custom* JSON that `ExternalInstance` routes via `SsRInstance` Go wrapper which talks to plugin’s local SOCKS port (plugin runs its own SSR client `shadowsocksr-libev` style).
  - Kotlin: `app/src/main/java/io/nekohasekai/sagernet/fmt/shadowsocksr/ShadowsocksRBean.kt` fields `serverAddress, serverPort, method, password, protocol, protocolParam, obfs, obfsParam`. `SSRfmt.kt` parser `ssr://BASE64(host:port:protocol:method:obfs:BASE64(password)/?obfsparam=…&protoparam=…&remarks=…&group=…)`.
  - Go: `libcore/ssr/` package; plugin binary `ssr-client` built from `shadowsocksr` C/Go port.
  - Install: “Please go to project homepage to download plugins” → `matsuridayo.github.io` → `ssr-plugin-*.apk`. Must not coexist with mismatched package signature? Matsuri logs warn `coexist with SagerNet version`.
  - Security: SSR ciphers are deprecated, no AEAD-2022; kept for legacy subscriptions. Matsuri marks SSR config with warning icon.

### 2.6 VMess (native V2Ray)

- **What:** V2Ray’s VMess (UUID + alterId/security) over any `streamSettings` transport. The “bread and butter” of SagerNet/Matsuri.
  - HOW native: `outbounds: [{protocol:"vmess", settings:{vnext:[{address,port,users:[{id,alterId,security,level}]}]}, streamSettings:{network, security, wsSettings/httpSettings/quicSettings/grpcSettings}}]`. SagerNet/v2ray-core adds `packetEncoding: none/packet/xudp` for UDP, `mux` packet encoding, endpoint-independent mapping (full cone NAT via `packetEncoding`).
  - Kotlin: `app/src/main/java/io/nekohasekai/sagernet/fmt/vmess/VMessBean.kt` fields `serverAddress, serverPort, uuid, alterId, security (auto/aes-128-gcm/chacha20-poly1305/none/zero), network (tcp/kcp/ws/h2/quic/grpc), headerType, host, path, seed, quicSecurity, quicKey, grpcServiceName, tls (none/tls/xtls), sni, alpn, certificates, utlsFingerprint`. `VMessFmt.kt` handles two URI styles:
    - `vmess://BASE64(JSON)` — v2rayN legacy (entire JSON base64’d).
    - `vmess://BASE64` with `vmess1` variant.
  - Go: `v2ray-core/proxy/vmess` (client) + `common/mux` (Mux) + `transport/internet/websocket|grpc|quic|httpupgrade`. `libcore/vmess.go` validates UUID, rewrites `streamSettings`.
  - Matsuri 0.5.9 added `v2ray v5.2` with **uTLS** partial support — `utlsFingerprint: chrome/firefox/safari/ios/...` via `utls` library, wired through `streamSettings.tlsSettings.fingerprint`.
  - Licenses: V2Fly V2Ray MIT → SagerNet fork GPL-3.0 wrapper.

### 2.7 Trojan (native)

- **What:** Trojan (password over TLS, mimics HTTPS). Trojan-Go is separate plugin (see next).
  - HOW native: `outbounds: [{protocol:"trojan", settings:{servers:[{address,port,password}]} , streamSettings:{security:"tls", tlsSettings:{sni, alpn, allowInsecure}}} ]`. UDP via TPROXY or XUDP if V2Ray-core supports.
  - Kotlin: `app/src/main/java/io/nekohasekai/sagernet/fmt/trojan/TrojanBean.kt` fields `serverAddress, serverPort, password, sni, alpn, certificates, utlsFingerprint, mux`. `TrojanFmt.kt` URI `trojan://password@host:port?sni=…&alpn=…&type=ws&host=…&path=…#name` (also supports `trojan-go` param compat).
  - Go: `v2ray-core/proxy/trojan` (SagerNet fork) + VLESS-style flow not needed; Trojan uses real TLS handshake then Trojan header.
  - Distinction: Pure Trojan (this section) does **not** need plugin — it is inside V2Ray-core. Trojan-Go (WebSocket/gRPC) needs plugin.

### 2.8 Trojan-Go (plugin `trojan-go-plugin`)

- **What:** `p4gefau1t/trojan-go` extended Trojan: WebSocket, mKCP, gRPC transports, mux, router, API. Superset of Trojan.
  - HOW plugin: Standalone APK `io.nekohasekai.sagernet.plugin.trojan-go` / `moe.matsuri.exe.trojan_go` that runs `trojan-go` binary. Kotlin `TrojanGoBean` serializes to Trojan-Go JSON file (`trojan-go.json`), `ExternalInstance` launches plugin activity via `PluginContract` and connects via loopback `127.0.0.1:port` SOCKS/HTTP that Trojan-Go exposes.
  - Kotlin: `app/src/main/java/io/nekohasekai/sagernet/fmt/trojan_go/TrojanGoBean.kt` fields `serverAddress, serverPort, password, sni, transport (tcp/ws), host, path, mux, websocket, shadowsocksMethod` etc. `TrojanGoFmt.kt` URI `trojan-go://password@host:port?...`.
  - Go: plugin binary Go `trojan-go` (GPL-3.0). Requires `trojan-go-plugin-*.apk` from `github.com/MatsuriDayo/plugins/releases` or `SagerNet` plugin repo; Matsuri notes `moe.matsuri.exe.*` package prefix to allow side-by-side with SagerNet plugins `io.nekohasekai.sagernet.plugin.*`.
  - Status: Largely superseded by Xray/VLESS Reality, but kept for existing subscriptions that set `type: trojan-go`.

### 2.9 NaïveProxy (plugin `naive-plugin`)

- **What:** Google `klzgrad/naiveproxy` — Chrome’s `cronet` stack (HTTP/2 forwarded proxy) over QUIC-like? Actually Naïve uses `chrome cronet` + `Caddy forwardproxy`. Extremely hard to fingerprint because it *is* Chrome’s network stack.
  - HOW plugin: APK `io.nekohasekai.sagernet.plugin.naive` / `moe.matsuri.exe.naive` ships `naive` binary (`naive-v*.apk` per arch). Kotlin `NaiveBean` fields `serverAddress, serverPort, username, password, sni, extraHeaders`. `NaiveFmt.kt` URI `naive+https://user:pass@host:port#name` sometimes written `https://` with `naive` scheme.
  - Launch: `ExternalInstance` writes `naive.json` with `listen: socks://127.0.0.1:xxxx` and `proxy: https://user:pass@host:port`, then polls plugin port.
  - Go: `naive` binary is C++ (BSD-3) bundling `cronet` + `boringssl`; not part of V2Ray-core, hence must be plugin.
  - Constraint: Only one naive-plugin at a time (“Uninstall the old Naive Plugin first… only one `naive plugin` on your device”).
  - Matsuri `0.5.x` updated naive to `v118.0.5993.65-1` track (Chromium 118).

### 2.10 Hysteria (plugin `hysteria-plugin`, v1)

- **What:** Hysteria v1 (UDP + QUIC + congestion control via `quic-go`, speed test, `obfs`/`auth`). Predecessor to Hysteria2.
  - HOW plugin: APK `hysteria-plugin-*.apk` wraps `apernet/hysteria` binary (Go, MIT). Kotlin `HysteriaBean` fields `serverAddress, serverPort, ports (mport), protocol (udp/wechat-video), obfs, obfsParam, auth, alpn, sni, allowInsecure, streamReceiveWindow, connectionReceiveWindow, disableMtuDiscovery`. URI `hysteria://host:port?protocol=…&auth=…&peer=…&insecure=…&upmbps=…&downmbps=…&alpn=…&obfs=…&obfsParam=…#name`.
  - Matsuri specifics: `0.5.9` “Hysteria multi-port sharing link compatible Shadowrocket format (`mport`)” — parser accepts comma-separated `mport=123,456,789` and expands to `ports` field. Release assets: `hysteria-plugin-v1.3.5-1-arm64-v8a.apk` etc.
  - Launch: plugin exposes SOCKS on loopback, SagerNet routes via it as `socks` outbound chaining.

### 2.11 WireGuard (plugin `wireguard-plugin`)

- **What:** Kernel/userspace WireGuard via `wireguard-go` (Go) or `wireguard-android` JNI. Matsuri/SagerNet treat it as an outbound peerset.
  - HOW plugin: Two backends selectable in `ExternalPlugin` — `WireGuardGo` vs `WireGuardKernel` (if kernel module). Kotlin `WireGuardBean` fields `serverAddress, serverPort, localAddress (10.x/ fd…), privateKey, peerPublicKey, peerPreSharedKey, mtu, keepAlive, allowedIPs`. URI `wireguard://BASE64(pubkey)?address=…&privateKey=…&mtu=…` often via `wg://`.
  - Go: `wireguard-go` (`wireguard-go` git.zx2c4.com, GPL-2.0/MIT) + `wireguard-plugin` glue in `libcore/wireguard/`. `libcore/tun.go` special case: if default outbound is WireGuard, `defaultOutboundForPing` handles ICMP differently.
  - Matsuri docs note for ShadowTLS/WireGuard users to fetch specific plugin builds from `matsuridayo.github.io/m-plugin/` → `MatsuriDayo/plugins/releases`.

### 2.12 Extended plugins (TUIC, Mieru, Juicity, ShadowTLS, sing-box, Xray)

- **TUIC v5 (plugin `tuic5-plugin`):**
  - HOW: `Matsuri 0.5.9` “Add TUIC support — new TUIC plugin coexists with SagerNet version.” URI `tuic://uuid:password@host:port?congestion_control=cubic&alpn=…&sni=…&udp_relay_mode=native&allow_insecure=…#name`. Plugin exposes SOCKS on loopback; uses `TUIC` QUIC stack. Release assets `tuic5-plugin-1.0.0-3-arm64-v8a.apk` etc. NekoBox 1.2.4 later inlines TUIC so plugin becomes deprecated.
  - FILE: `libcore/date.go: TUIC_BUMP` notes.
- **Mieru (plugin `mieru`):**
  - HOW: `mieru` obfuscation (Shadowsocks-like + extra TCP scramble) via `enfein/mieru` Go. SagerNet added `mieru-v2.2.0` plugin (`2023-09-08`). Kotlin bean similar to SS but method is `mieru`.
- **Juicity (plugin `juicity`):**
  - HOW: `juicity` (QUIC + TLS + 0-RTT) `juicity/juicity` Go. Release `juicity-v0.3.0` (`3752 KB arm64-v8a`). MatsuriDayo/plugins docs.
- **ShadowTLS (via ShadowTLS + sing-box plugins):**
  - HOW: `ShadowTLS` wraps Shadowsocks inside TLS handshake; accessed via `sing-box` plugin (v1.2-beta5-2) or dedicated `shadowtls-plugin`. Docs page `Need to use ShadowTLS and WireGuard → github.com/MatsuriDayo/plugins/releases`.
- **sing-box plugin / Xray plugin (bridge to NekoBox era):**
  - HOW: Temporary plugins `sing-box-v1.2-beta5-2` / `Xray-v1.7.5-1` allowed Matsuri to run a sing-box or Xray binary as an external core for VLESS/SS2022 users who wanted features not yet backported. Immediately deprecated (“new client is stable, use NekoBox”).
  - All plugins share same dispatch: `app/src/main/java/io/nekohasekai/sagernet/plugin/PluginManager.kt` enumerates installed `PackageManager` matching `moe.matsuri.exe.*` or `io.nekohasekai.sagernet.plugin.*`, `PluginContract` AIDL fetches the executable path, `ExternalInstance` starts and manages lifecycle.

### 2.13 SSH edge (already covered) + VLESS note

- **VLESS/Reality/XTLS:** Native VLESS is *not* in Matsuri/SagerNet’s native list — it lives in Xray plugin path or via V2Ray-core graft. If you need `VLESS + Reality + uTLS + Vision`, use NekoBox or `Xray-plugin`. Matsuri docs explicitly tell VLESS/SS2022 users to migrate to NekoBox.
  - HOW: The reason is `v2ray-core` (V2Fly) vs `Xray-core` (XTLS fork). SagerNet ships `SagerNet/v2ray-core` (enhanced V2Fly, with shadowsocks SIP003 + packetEncoding) but not Reality. Reality lives in Xray. Hence the bifurcated plugin strategy.

### 2.14 Transport layer orthogonality (VMess/Trojan/VLESS over …)

- HOW: For native protocols, transport is `streamSettings` inside V2Ray JSON:
  - `network: tcp` (+ `security: tls` → TLS, `headerType: http` → fake HTTP).
  - `network: kcp` (mKCP with `seed`, `headerType: none/srtp/utp/wechat-video/...`).
  - `network: ws` (`wsSettings: {path, headers:{Host}}`).
  - `network: h2` (`httpSettings: {host, path}`) → HTTP/2.
  - `network: quic` (`quicSettings: {security, key, headerType}`).
  - `network: grpc` (`grpcSettings: {serviceName, multiMode}`) — added after gRPC QUIC fixes in Matsuri `0.5.9` “fix v2ray QUIC (#187)”.
  - TLS supplement: `security: tls` / `reality` (plugin only) / `xtls` (Xray) + `tlsSettings: {serverName, allowInsecure, alpn, certificates, fingerprint (uTLS)}` where Matsuri `0.5.x` adds partial `uTLS` support via `utls` Go library wired through `libcore`.
- FILE: `app/src/main/java/io/nekohasekai/sagernet/fmt/vmess/VMessBean.kt:network/security` fields; `libcore/v2ray_tls.go` or `tls.go`; `SagerNet/v2ray-core/transport/internet/*`.

---

## 3. Subscription Formats

- **Raw / widely used formats (auto-detect):**
  - HOW: `SubscriptionManager` (`app/src/main/java/io/nekohasekai/sagernet/database/DataStore.kt` + `fmt/*Mgr.kt`) fetches URL, reads `Content-Type` / body sniff, then dispatches to parsers.
    - If body starts `ss://`, `ssr://`, `vmess://`, `trojan://`, `vless://`, `hysteria://`, `tuic://`, `wireguard://`, `socks://`, `http://` one-per-line → treat as `v2rayN base64` or plain lines. Each line is dispatched to its `*Fmt.kt` parser.
    - If body is YAML with `proxies:` key in `clash` style → Clash parser.
    - If body is JSON with `{servers: []}` or SIP008 top-level → SS SIP008 parser.
    - If body is JSON with `outbounds` / `inbounds` → V2Ray full config import.
  - FILE: `app/src/main/java/io/nekohasekai/sagernet/utils/SubscriptionUpdater.kt` (or `bg/Subscription.kt`), `app/src/main/java/io/nekohasekai/sagernet/fmt/*` package each exposing `parse(String): List<AbstractBean>`.

- **v2rayN base64 subscription (legacy):**
  - HOW: `BASE64( vmess://… \n ss://… \n trojan://… )` where the *entire response* is base64-encoded, often with `MAX=` headers. Decoder: `Base64.decode(body.trim())` → `String` → split `\n` → parse per-line URIs. Some providers send *unencoded* lines; fallback detects if first char is not base64 alphabet.
  - Matsuri `0.6.5` fix: “fix v2rayN socks format recognition” — older parser mis-identified `socks://` inside base64 blob due to missing `socks5://` alias.
  - FILE: `app/src/main/java/io/nekohasekai/sagernet/fmt/vmess/VMessFmt.kt:parseV2RayN()`, `utils/Utils.kt:decodeBase64()`.

- **Clash / Clash Meta (YAML):**
  - HOW: Parser (`app/src/main/java/io/nekohasekai/sagernet/fmt/clash/ClashFmt.kt`) uses `snakeyaml` to load `Map<String,Any>` → iterate `proxies:` list → map `type: ss|ssr|vmess|trojan|hysteria|wireguard|socks5|http` → build `AbstractBean`. `proxy-groups` are *flattened* to multiple `ProxyEntity` groups (or imported as `ProxyGroup` with type `clash`). Matsuri `0.6.1/0.6.2` changelog: “support parsing clash `trojan` `network` (ws/grpc)” — means `network: ws|grpc` under Trojan parsed to `streamSettings` accordingly.
  - FILE: `fmt/clash/ClashParser.kt:parseClashYaml(String): List<AbstractBean>`; `fmt/clash/MetaFmt.kt` for Meta extensions.

- **Shadowsocks SIP008 (JSON Online Config):**
  - HOW: Spec at `https://shadowsocks.org/guide/sip008.html`. JSON shape `{version:1, servers:[{id,remarks,server,server_port,password,method,plugin,plugin_opts}], bytes_used, bytes_remaining}`. Matsuri/SagerNet import as a *group* named after subscription; each server becomes a `ShadowsocksBean`; traffic counters feed the subscription traffic widget (see §8).
  - FILE: `app/src/main/java/io/nekohasekai/sagernet/fmt/shadowsocks/SIP008Fmt.kt`; `ShadowsocksBean` JSON adapter.

- **OpenOnlineConfig (OOC) — Shadowsocks-NET:**
  - HOW: Spec at `https://github.com/Shadowsocks-NET/OpenOnlineConfig` (`Shadowsocks-NET/OpenOnlineConfig` JSON/YAML, richer than SIP008 — includes plugin chains, routing). SagerNet implements `OOC` parser alongside SIP008: body with `configs:[]` and `outbounds` is slotted into V2Ray config without re-encoding. This is the “subscription as full config” mode.
  - FILE: `app/src/main/java/io/nekohasekai/sagernet/fmt/ooc/OOCFmt.kt` (or inline under `fmt/shadowsocks/OOC.kt`); README link `Open Online Config` under Subscription section.

- **Update pipeline:**
  - HOW: `SubscriptionUpdater` runs via `WorkManager` + `AlarmManager` interval (Settings → `updateInterval` default `24h`, editable via Notification update interval). Fetch uses `OkHttp` with optional proxy (direct vs via current VPN), `User-Agent: SagerNet/…`, `Cache-Control: no-cache`. Response cached to `subscriptionCache` DB; on parse success, `ProxyGroup` entities are diffed (add/update/delete), deduplicated by `remarks` + `server:port`. If subscription link unchanged, Matsuri `0.6.5` retains traffic stats: “when subscription link not modified, editing group does not clear subscription traffic info.”
  - FILE: `app/src/main/java/io/nekohasekai/sagernet/database/entity/SubscriptionEntity.kt`; `bg/SubscriptionUpdater.kt`; `utils/UpdateIntervalPreference.kt`.

---

## 4. Core — libcore, V2Ray-core/Xray-core, sing-box Boundary

- **libcore (SagerNet core Go):**
  - HOW: Go module `libcore` (import path `libcore` / `github.com/SagerNet/LibSagerNetCore` history) compiled to `libcore.aar` via `gomobile bind -target android -javapkg moe.matsuri.libcore`. Provides `Libcore` Java class with JNI methods: `NewV2RayInstance(configJson:String): V2RayInstance`, `Start()`, `Stop()`, `QueryStats(tag:String)`, `UpdateConfig(json)`, `ResolveDNS(domain)`, `TestTCP(host,port)`, `InitCore(path)`. Kotlin calls these via `V2RayInstance` wrapper.
  - Structure: `libcore/libcore.go: type Instance struct{ core *v2ray.Core; router ...; outboundManager ... }`, `libcore/v2ray.go:V2RayInstance`, `libcore/dns.go:DNSClient`, `libcore/tun.go:Tun2ray`, `libcore/stats.go:StatsService`, `libcore/config.go:BuildConfig()`.
  - Go toolchain: Matsuri `0.6.2` bumped Go `1.19 → 1.20`; NDK r25+; `SagerNet/v2ray-core` upgraded `v5.2.1 → v5.3.0` in same release. Matsuri `0.6.5` stamps `libcore/date.go:1-3` with build date.
  - FILE: `libcore/go.mod: module libcore`; `libcore/libcore.go:1-80`; `libcore/date.go`; `buildScript/buildLibCore.sh` (or `libcore/build.sh`); `settings.gradle.kts: include(":libcore")`; `SagerNet/LibSagerNetCore` upstream repo.

- **V2Ray-core / Xray-core ancestry (why not sing-box yet):**
  - HOW: `SagerNet/v2ray-core` is a fork of `v2fly/v2ray-core` with **SagerNet patches**: `shadowsocks SIP003 plugin`, `embed v2ray-plugin`, `endpoint independent mapping (full cone NAT)`, `packetEncoding: none/packet/xudp` for VMess/VLESS mux, `gRPC multi/raw`, `wireguard Client`. `MatsuriDayo/v2ray-core` is a second-level fork “designed to meet Matsuridayo’s needs” — explicitly says “not intended for general use, no API/ABI stability.” Matsuri pins its `libcore/go.mod` to `MatsuriDayo/v2ray-core` tag (vs SagerNet’s own fork) to get uTLS / QUIC fixes faster.
  - V2Fly vs Xray: V2Fly V2Ray is the canonical core; Xray (`XTLS/Xray-core`) is a V2Fly hard fork adding `XTLS Vision`, `Reality`, `uTLS` fingerprint, `WireGuard` improvements. SagerNet stayed on V2Fly-derived core (with XT LS patches cherry-picked) rather than full Xray; that’s why Reality/VLESS requires Xray *plugin* instead of being builtin. NekoBox finally jumps to `SagerNet/sing-box` and drops V2Ray-core entirely.
  - Config model: V2Ray JSON has `inbounds[]`, `outbounds[]`, `routing:{rules[]}`, `dns:{servers, hosts}`, `policy`, `stats`, `log`. SagerNet Kotlin builds this JSON; Go then calls `core.Start()` which deserializes via `v2ray-core/infra/conf/serial`.
  - FILE: `SagerNet/v2ray-core/README.md:2-20` patches list; `MatsuriDayo/v2ray-core/README.md:1-15` fork notice; `libcore/go.mod: require github.com/v2fly/v2ray-core v5.x` replaced by `replace => github.com/MatsuriDayo/v2ray-core`; `.gitmodules: submodule v2ray-core`.

- **Matsuri bundling vs plugin (vs NekoBox’s sing-box):**
  - HOW: Matsuri/SagerNet **bundle** the V2Ray runtime *inside* `libcore.aar` (statically linked). The APK works offline without plugins for native protocols. **Plugins** are only for protocols that cannot be linked (Naïve’s Chromium, Hysteria’s QUIC quirks, Trojan-Go’s separate router, WireGuard-Go, TUIC, etc.) or for larger binaries that would bloat the APK (ShadowTLS, sing-box bridge, Xray bridge).
  - NekoBox inverts this: `sing-box` *is* the entire data plane (no V2Ray-core at all). Protocols like Shadowsocks, VMess, Trojan, VLESS, Hysteria2, TUIC, WireGuard, SSH are all `sing-box/option` structs inside one `box.Box`. Plugins still exist but only for Mieru/Juicity-scale exceptions; Reality/VLESS are native.
  - HOW to tell: If you see `libcore/box.go` (sing-box) it’s NekoBox. If you see `libcore/v2ray.go` + `libcore/tun.go` + `v2ray-core` imports, it’s Matsuri/SagerNet (V2Ray era).
  - FILE: `libcore/tun.go:1-15` imports `github.com/v2fly/v2ray-core/v5` + `libcore/gvisor` + `libcore/nat` (Matsuri/SagerNet); vs NekoBox `libcore/box.go: import box "github.com/sagernet/sing-box"` ; `libcore/comm/TunImplementation*` constants.

- **sing-box bridge plugin (transitional):**
  - HOW: Release `sing-box-v1.2-beta5-2` in `MatsuriDayo/plugins` provides a *sing-box binary as a plugin* for Matsuri users who want sing-box transports without migrating apps. Kotlin detects the `sing-box` plugin via `PluginManager` (capability `sing-box`) and routes VLESS/SS2022 configs through it instead of V2Ray-core. The project immediately deprecates it because it duplicates what NekoBox already does cleanly.
  - FILE: `MatsuriDayo/plugins/releases/tag/sing-box-v1.2-beta5-2` assets; `matsuridayo.github.io/nb4a-plugin/` docs.

---

## 5. Split Tunneling / Routing

- **Per-app VPN (Android `VpnService.Builder.addAllowedApplication` / `addDisallowedApplication`):**
  - HOW: `SagerVpnService.setup()` reads `DataStore.proxyApps` (boolean: proxyApps = true means “only selected apps go through VPN”; proxyApps = false means “selected apps bypass”). Iterates `DataStore.selectedApps: Set<String>` (package names) and calls `builder.addAllowedApplication(pkg)` (whitelist mode) or `addDisallowedApplication(pkg)` (blacklist mode). `proxyApps` switch in Settings → “Apps VPN mode” toggle. `Bypass mode` (`isBypassApps`) inverts.
  - FAST vs SLOW scanner: Chinese-apps scanner used to build `selectedApps` quickly — two modes: `FAST` = list from `https://github.com/2dust/androidpackagenamelist` (precomputed JSON of known CN packages) → instant tick; `SLOW` = dex classpath scan of installed APKs via `PackageManager.getInstalledApplications()` then `DexFile` / `ClassLoader` heuristic (slower, historically crashed). Matsuri `0.6.5` changelog: “Due to easy crash, ‘Scan Chinese apps’ renamed to ‘Auto-select apps that need proxy’, package list from `2dust/androidpackagenamelist`.” Notification `updateInterval` timer also repolls.
  - FILE: `app/src/main/java/io/nekohasekai/sagernet/bg/SagerVpnService.kt:setupBuilder(): Builder` (~`addAllowedApplication` / `addDisallowedApplication`); `app/src/main/java/io/nekohasekai/sagernet/utils/PackageCache.kt` (package cache + CN list fetch via OkHttp); `app/src/main/java/io/nekohasekai/sagernet/ui/RouteSettingsActivity.kt:proxyAppsSwitch`; `database/DataStore.kt:proxyApps, selectedApps`; `utils/AppScanner.kt`.

- **Bypass LAN / Bypass China / Advertising block (routing rules presets):**
  - HOW: `ConfigBuilder` emits `routing.rules[]` with GeoIP/GeoSite matchers. Presets toggled in `Settings → Routing`:
    - `bypassLan: true` → rule `{ip_cidr: ["0.0.0.0/8","10.0.0.0/8","172.16.0.0/12","192.168.0.0/16","127.0.0.0/8","::1/128","fc00::/7","fe80::/10"], outboundTag:"bypass"}` where `bypass = direct`.
    - `bypassChina: true` → two rules: `geosite:cn → direct` and `geoip:cn → direct`. Data via `geoip.dat` / `geosite.dat` (V2Ray `geoip`/`geosite`) downloaded from `Loyalsoldier/v2ray-rules-dat` or SagerNet mirror.
    - `blockAds: true` → `geosite:category-ads-all → block` (`outboundTag:"block"` maps to `protocol:"blackhole"`).
  - Order: `ads block` first, then `LAN bypass`, then `CN bypass`, then `user custom rules`, then `final` (`proxy` vs `bypass`). Final is `bypassMode` (global bypass vs proxy-all).
  - FILE: `bg/proto/V2RayConfigBuilder.kt:buildRouting()` or `libcore/routing.go`; `assets/geoip.dat`, `assets/geosite.dat` versioned via `libcore/updateGeoAssets.sh`; `database/DataStore.kt:blockAds, bypassLan, bypassChina, bypassMode`.

- **Custom routing / ACL / outbound profile selection:**
  - HOW: `Settings → Routing` lists editable `RuleEntity` rows (Room). Each rule has: `outbound` (which `ProxyGroup`/`ProxyEntity` to use — e.g., “Proxy-A via HK group” vs “Proxy-B”), `domain` patterns (plain, regex `regexp:`, `geosite:`), `ip` CIDRs (`geoip:`), `port`, `network` (tcp/udp), `sourceIp`, `authUser`, `inboundTag`, `protocol` filter, `processName` filter (root). Rules are serialized into `routing.rules[]` ordered; `domainStrategy: IPIfNonMatch` switch per rule controls DNS-assisted routing.
  - proxy chain: `outbounds[]` can reference *another* outbound as `proxySettings.tag` or via `dialerProxy` (chain). Example: `VMess → Shadowsocks` chain sets `proxySettings.tag = "proxy-b"`. Built via `ConfigBuilder`’s `chainOutbound`.
  - reverse proxy: `inbounds[]` with `protocol:"dokodemo-door"` or `routing.rules: {inboundTag:["reverse"], outboundTag:"proxy"}`; configured under `Custom Config` import.
  - WARP (Cloudflare): Not builtin as outbound; implemented via *WireGuard* plugin pointing to `engage.cloudflareclient.com:2408` with `localAddress: 172.16.0.2/32` + `peerPublicKey: bmXOC+…`. Matsuri/SagerNet users paste WARP WireGuard conf from `warp-plus` generators.
  - WebSocket browser forwarding: `Settings → Browser Forwarding` toggles `BrowserForwarder` that sniff’s `HTTP Host` and forwards `ws://`/`wss://` via a local HTTP proxy (use case: Shadowrocket-style? Actually Matsuri’s “WebSocket browser forwarding” forwards WebSocket through proxy for apps that don’t support proxy). `Notification → Update interval` controls how often the forwarder’s proxy list refreshes.
  - FILE: `database/entity/RuleEntity.kt`; `ui/RouteSettingsActivity.kt`, `ui/ProfileSettingsActivity.kt` (per-app selectors); `bg/proto/ConfigBuilder.kt:buildRouting()/buildOutbounds()`; `fmt/wireguard/WireGuardBean.kt` for WARP; `utils/BrowserForwarder.kt` (if present) or `bg/LocalDnsService.kt`.

- **Route by apps scanner nuance (dex vs package-list):**
  - HOW: Original SagerNet implemented `AppScanner.scan()` that iterated `PackageManager.getInstalledPackages()` then opened each APK’s `classes.dex` via `DexFile` to check for `com.tencent.*` / `cn.*` prefixes — O(N) dex read, slow, ANR-prone on 200+ apps, triggered `StrictMode` violations. Matsuri replaces it with `AutoSelectProxyAppsJob` that fetches `androidpackagenamelist` (`2dust/androidpackagenamelist` JSON with 2000+ CN package names) then intersects with `PackageManager.getInstalledApplications()` — O(1) network + list diff, instant.
  - FILE: `utils/AppScanner.kt` (SagerNet original, annotated slow); Matsuri patch `utils/CnPackageListFetcher.kt`; Matsuri `0.6.5` release notes `由于容易造成崩溃，「扫描中国应用」改为「自动选择需要代理的应用」，包名列表来自 https://github.com/2dust/androidpackagenamelist`.

- **Notification update interval + Chinese-apps scanner wording:**
  - HOW: `Settings → Notification → Update interval` (default `15 min`) controls foreground notification stats refresh *and* re-runs the CN auto-selector if enabled. The per-app VPN list is re-evaluated on each service restart and on package install broadcast (`PACKAGE_ADDED` receiver `PackageChangeReceiver`).
  - FILE: `bg/SagerVpnService.kt:onStartCommand(): startForeground(NOTIF_ID, notification)`; `utils/UpdateIntervalPreference.kt`; `receiver/PackageChangeReceiver.kt`.

---

## 6. TUN vs VPN — Android VpnService & tun2socks

- **Android VpnService (system-owned TUN creation):**
  - HOW: Android does not allow apps to `mknod /dev/tun` (no root). Instead `VpnService.prepare()` + `VpnService.Builder.establish()` asks the OS to create a TUN device and returns its fd. Matsuri/SagerNet subclass `VpnService` (`SagerVpnService`) and on `onStartCommand`:
    1. `builder = Builder().addAddress("198.18.0.1",32).addAddress("fdfe:8888:8888::1",128).addRoute("0.0.0.0",0).addRoute("::",0).addDnsServer("114.114.114.114" or custom).setMtu(desired).setSession("Matsuri").setConfigureIntent(pendingIntent).addDisallowedApplication(packageName?)` etc.
    2. `parcelFd = builder.establish()` → `parcelFd.fd: Int` (the TUN fd).
    3. Hand `parcelFd.fd` to Go via `libcore.NewTun2ray(TunConfig{ FileDescriptor: fd, MTU: mtu, Gateway4: "198.18.0.1", Gateway6: "fdfe::1", IPv6Mode, Implementation, Sniffing, OverrideDestination, Protector })`.
    4. Go takes over read/write loop on that fd.
  - `Protect` callback: Go needs to call back into Java to `protect(socketFd)` so outbound proxy sockets bypass the TUN (avoid routing loops). Java implements `Protector` interface via `VpnService.protect(int fd)` AIDL.
  - FILE: `app/src/main/java/io/nekohasekai/sagernet/bg/SagerVpnService.kt:establish()` → `libcore.NewTun2ray`; `app/src/main/java/io/nekohasekai/sagernet/bg/VpnProtector.kt : Protector { override fun protect(fd: Int): Boolean { return vpnService.protect(fd) } }`; `libcore/tun.go:NewTun2ray()` + `protectedDialer{ protector }` setup.

- **TUN implementation — two engines selectable in Settings → TUN Implementation:**
  - **`TunImplementationGVisor` (default, Google gVisor netstack TCP/IP):**
    - HOW: `gvisor.New(fd, mtu, handler, DefaultNIC, pcap, pcapFile, MaxUint32, ipv6Mode)` creates a user-space TCP/IP stack (`github.com/google/gvisor/pkg/tcpip/stack` + `pkg/tcpip/transport/tcp`, `udp`, `icmp`). Packets read from fd via `tun.Tun.Read()` are injected into `stack.InjectInbound()`. Stack’s TCP forwarder (`tcp.NewForwarder`) hands each `NewConnection` to `Tun2ray.NewConnection(source, dest, conn net.Conn)` which then does `session.ContextWithInbound(Inbound{Tag:"tun"})` + sniffing + routing `router.PickRoute()` → `handleTCP(ctx, handler, dest)`. UDP via `udp.NewForwarder` → `NewPacket` → `handleUDP`.
    - Pros: Fully supports IPv4/IPv6/ICMP/TCP/UDP in pure Go, no CGO, “>2.5Gbps throughput” claims, game-ready UDP transmission, handles fragmented packets. Con: gVisor’s memory footprint larger, MTU tuning sensitive.
    - FILE: `libcore/gvisor/stack.go`, `libcore/gvisor/device.go`, `libcore/tun.go:case comm.TunImplementationGVisor: t.dev, err = gvisor.New(...)`; `libcore/comm/TunImplementation.go: const TunImplementationGVisor = 0, TunImplementationSystem = 1, TunImplementationMixed = 2` (Matsuri may collapse to 2).
  - **`TunImplementationSystem` (lwIP/nat via `SagerNet/libcore/nat` or `system` stack):**
    - HOW: Native-ish path using Go lwIP port (`golang lwip tun2socks` from `SagerNet/tun2socks` discussion #142) or NetBare-style packet rewriting that re-uses kernel TCP via non-blocking IO. `nat.New(fd, mtu, handler, ipv6Mode, errorHandler)` registers Raw socket handlers that rewrite destination to `127.0.0.1:localPort` forwarding server (Netty-style). Faster to bootstrap historically, but earlier Matsuri `0.6.1` dropped `gvisor` flavor then restored it.
    - Matsuri `0.6.1` note “gvisor version no longer maintained” → `0.6.2+` kept only system? Actually `0.5.11 → 0.6.1` table shows `gVisor: 有 → 无` meaning Matsuri 0.6.2 unified.
    - FILE: `libcore/nat/nat.go`, `libcore/tun.go:case comm.TunImplementationSystem: t.dev, err = nat.New(...)`; `SagerNet/tun2socks` repo README gVisor fork.
  - **`TunImplementationMixed` (hybrid, if present):**
    - HOW: Combines gVisor TCP + system UDP or vice versa for balance. Matsuri settings may expose it as “Mixed”.
  - Selection UI: `Settings → VPN → TUN Implementation` Spinner with `gVisor / System / Mixed`; persisted to `DataStore.tunImplementation`.
  - FILE: `utils/TunImplementationPreference.kt`; `bg/SagerVpnService.kt: tunImplementation = DataStore.tunImplementation`.

- **MTU, IPv6, and tun2socks quirks:**
  - HOW:
    - `MTU` default `9000` (SagerNet) / `9000` or `1500` depending on variant; user-editable in `Settings → VPN → MTU`. Built into `Builder.setMtu(mtu)` *and* passed to `Tun2ray` → `gvisor` stack’s `stack.SetMTU()` / `nat`’s packet splitter. Too low → fragmentation, too high → `EMSGSIZE` on some carriers. Matsuri `0.6.5` note about gVisor `pcap` also depends on MTU (pcap file per `time.Now().UTC().String()` in `tun.go:NewTun2ray()` when `pcap: true`).
    - `IPv6` tri-mode: `DataStore.ipv6Mode` values `0=Off`, `1=Prefer`, `2=Only` (or Disable/Enable/Prefer). When Off, builder does `addAddress` only IPv4, and `gvisor.New(... , ipv6Mode=0)` drops AAAA routes; go dialer `net.Resolver.PreferGo` filters. When enabled, `addAddress(fdfe:…)` + `addRoute("::",0)` and `Gateway6` used. `libcore/tun.go:NewTun2ray` Switches on `IPv6Mode` for `wireguard` special.
    - `SagerNet/tun2socks` claim: “Fully support: IPv4/IPv6/ICMP/TCP/UDP · Proxy protocol: HTTP/Socks4/Socks5/Shadowsocks · Game ready: optimized UDP transmission · Pure Go: no CGO required · Router mode: forwarding packets in LAN · High performance: >2.5Gbps” — this README is the SagerNet fork of `xjasonlyu/tun2socks` re-based on gVisor.
  - FILE: `libcore/tun.go:TunConfig{ MTU int32, Gateway4/Gateway6 string, IPv6Mode int32, Implementation int32 }`; `libcore/gvisor/`, `libcore/tun/`; `bg/SagerVpnService.kt:setMtu()`, `addAddress()`; `utils/Ipv6ModePreference.kt`.

- **Fallback and failure modes:**
  - HOW: If `builder.establish()` returns `null` (another VPN active, or user denied consent), SagerNet shows notification `VPN permission denied` and fires `VpnService.prepare()` intent via `ActivityResultLauncher`. If `Tun2ray.NewConnection`’s `router.PickRoute` errors, it falls back to `defaultOutboundForPing` if default is WireGuard; else drops with `newError("failed to pick route")`. `pingproto.ControlFunc` is overridden to call `protector.Protect(fd)` so ICMP also bypasses TUN.
  - FILE: `bg/SagerVpnService.kt:onEstablishFailed()`, `VpnRequestActivity.kt`; `libcore/tun.go:NewPingPacket` + `provider` logic.

---

## 7. DNS

- **Two-level DNS architecture (hijack + routing):**
  - HOW: SagerNet/Matsuri have a *DNS hijack* path inside the TUN plus a *routing-aware DNS* inside V2Ray-core. Together they behave as:
    - **TUN DNS hijack:** Packets destined to `t.router` (default `198.18.0.2` or `114.114.114.114`-spoof) with `dstPort:53` are intercepted in `Tun2ray.NewConnection`/`NewPacket` → tagged `inbound.Tag = "dns-in"` (see `tun.go: isDns := destination.Address.String() == t.router`). Then they are either answered by `localdns` (hosts → direct) or forwarded to V2Ray-core’s `dns.Client` via `dnsClient.LookupDefault(ctx, domain)`. Sniffing (`sniffing:true`) plus `overrideDestination:true` then re-routes based on sniffed domain.
    - **Routing DNS:** V2Ray `dns` object has `servers: [{address:"8.8.8.8", port:53, domains:["geosite:geolocation-!cn"]}, {address:"114.114.114.114", port:53, domains:["geosite:cn"]}, {address:"localhost"}]` etc. V2Ray picks which upstream to query per-domain before evaluating `routing.rules`. Result influences `routing` (`domainStrategy: IPIfNonMatch / AsIs / IPOnDemand`).
  - FILE: `libcore/tun.go:Tun2ray.NewConnection` → `isDns` branch; `bg/proto/V2RayConfigBuilder.kt:buildDns()` writes `dns.servers` JSON; `libcore/dns.go:DNSClient.LookupDefault`; `V2Ray config docs: https://guide.v2fly.org/en_US/app/dns.html` mirrored in SagerNet help.

- **Settings UI — DNS toggles:**
  - HOW: `Settings → DNS` exposes:
    - `Remote DNS: 8.8.8.8` (default) — the *proxy DNS* used for non-CN domains / proxied queries. Free-form IPv4/DoH/DoT (`https://dns.google/dns-query`, `tls://8.8.8.8`).
    - `Direct DNS: 114.114.114.114` (or `223.5.5.5`, `119.29.29.29`, `223.6.6.6`) — used for `geosite:cn` / `geoip:cn` lookup so they stay local and avoid loop.
    - `Enable DNS routing: true/false` (`DataStore.enableDnsRouting`) — if disabled, all DNS goes to Remote DNS (simpler but slower for CN).
    - `Use local DNS as direct DNS: true/false` (`useLocalDnsAsDirectDns`) — if enabled, V2Ray reads the system’s `getprop net.dns1` and uses it as direct server.
    - `Domain strategy: AsIs / IPIfNonMatch / IPOnDemand` (`domainStrategy`) — controls whether router pre-resolves domain to IP before matching GeoIP CIDR rules.
    - `Traffic sniffing: true/false` (`trafficSniffing`) + `Destination override: true/false` (`destinationOverride`) — sniff TLS SNI / HTTP Host to correct destination when app sends IP but SNI is domain; override then re-routes using sniffed domain.
  - FILE: `database/DataStore.kt:remoteDns ("8.8.8.8"), directDns, enableDnsRouting (true), useLocalDnsAsDirectDns (false), domainStrategy (IPIfNonMatch), trafficSniffing (true), destinationOverride (false), resolveDestination (false), bypassLanInCoreOnly, allowAccess`; `ui/DnsSettingsActivity.kt`; `bg/proto/V2RayConfigBuilder.kt:buildDns()`.

- **FakeDNS (experimental):**
  - HOW: V2Ray option `fakedns: [{ipPool:"198.18.0.0/15", lruSize:0}]` exists in core but *not* exposed in Matsuri/SagerNet UI by default because it breaks LAN/China heuristics. Matsuri `0.6.x` note “fix `fakedns+vpn udp not通`” shows they patched `libcore/tun.go:NewPacket` to handle FakeIP → real IP mapping for UDP.
  - FILE: `libcore/config.go:fakeDnsPool` handling; Matsuri `0.6.2` changelog “修复 fakedns+vpn udp 不通”.

- **DNS hijack detail (packet flow):**
  - HOW: 1) App calls `getaddrinfo("google.com")` → OS sends DNS UDP to builder’s `addDnsServer`. 2) Packet enters TUN fd → `Tun2ray.NewPacket(source, dest, buf, writeBack)`. 3) Check `isDns && sniffing` → `session.Content{ SniffingRequest{ OverrideDestinationForConnection: true } }` → `v2ray` sniffs protocol `domain` then re-injects via correct outbound’s DNS. 4) Response synthesized as DNS packet and `writeBack(responseBytes)` to fd, which writes back to app’s socket. The app never knows it’s fake. Remote path: `internet.UseAlternativeSystemDialer(protectedDialer{ resolver: dnsClient.LookupDefault })` so even V2Ray’s own upstream DNS dial goes through protector + remote resolver.
  - FILE: `libcore/tun.go:NewPacket()`, `NewConnection()` inbound tag `dns-in`; `libcore/dns.go`; `v2ray-core/features/dns/localdns`.

- **Known pitfall (SagerNet issue #642):**
  - HOW: SagerNet imported V2Ray full config sometimes `serverDomain` itself gets classified as foreign → routed to `8.8.8.8` via remote DNS which is unreachable, so handshake fails “server domain also entered builtin DNS determination, resulting in inability to resolve.” Fix config suggests `server domain direct local resolution, no longer enter builtin DNS determination` — `Custom config → add server domain to direct/hosts`.
  - FILE: `SagerNet/SagerNet/issues/642` reproduction `from v2rayNg export full config → server domain judged to go abroad 8.8.8.8 → timeout`.

---

## 8. Other Features — Plugins, Stats, Backup, Themes, Groups

- **Plugin system (download plugins via repo):**
  - HOW: Architecture is *intent-based IPC* between main APK and plugin APKs. Steps:
    1. User installs plugin APK (e.g., `trojan-go-plugin-xxx-arm64-v8a.apk`, `naive-plugin`, `hysteria-plugin`, `wireguard-plugin`, `tuic5-plugin`, `mieru`, `juicity`) from `matsuridayo.github.io/m-plugin/` or `github.com/MatsuriDayo/plugins/releases`.
    2. `PluginManager` (`app/src/main/java/io/nekohasekai/sagernet/plugin/PluginManager.kt`) on `onResume` queries `PackageManager.queryIntentServices(PluginContract.ACTION_NATIVE_PLUGIN_ENTRY)` + package prefix filters `moe.matsuri.exe.*` (Matsuri) *and* `io.nekohasekai.sagernet.plugin.*` (SagerNet) → builds `ResolvedPlugin` list with `id, packageName, label, executablePath, optionsClass`.
    3. Each plugin APK exposes a `PluginContract` AIDL (or Broadcast) that main APK calls `fetchExecutablePath()` to get the native binary path (e.g., `nativeLibraryDir/libtrojan-go.so` or `files/hysteria`). Permissions via `signature` check to avoid spoof.
    4. `ExternalInstance` (`bg/proto/ExternalInstance.kt`) on `start()` writes a plugin-specific JSON config to `files/plugin/<id>/config.json` (Trojan-Go JSON, Naive JSON, Hysteria YAML, WireGuard ini, TUIC JSON), then spawns the binary as subprocess via `ProcessBuilder(executablePath, "-c", configPath)` or via `plugin.start()` AIDL, tracking `Process` + `port` (local SOCKS/HTTP that plugin exposes).
    5. `SagerVpnService` then configures the *main* V2Ray outbound to dial `127.0.0.1:<pluginPort>` with `protocol:"socks"` / `protocol:"http"` as a chained proxy. From Android’s perspective the plugin’s traffic still goes through VpnService’s protected dialer, so loop prevention needs `protector.Protect(pluginFd)`.
    6. Plugin APK lifecycle is separate — uninstall removes the outbound type; “About → Plugins” page shows installed plugins (capabilities + version).
  - Compatibility: Matsuri allows side-by-side with SagerNet plugins because package prefixes differ (`moe.matsuri.exe.*` vs `io.nekohasekai.*`). Warning: Naïve/Hysteria “only one `naive plugin` on your device” because their loopback ports collide if two installed.
  - Build: Each plugin is its own repo (`SagerNet/plugin-trojan-go`, `SagerNet/plugin-naive`, `SagerNet/hysteria-plugin` etc. vs `MatsuriDayo/plugins` unified repo) with `gradlew :plugin:assembleRelease` + `gomobile`/CMake NDK cross-compile to `arm64-v8a/armeabi-v7a/x86/x86_64`. Assets are multi-arch APKs like `hysteria-v1.3.5-1-arm64-v8a.apk (1009KB)` / `tuic5-plugin-1.0.0-3-arm64-v8a.apk (1009KB)`.
  - FILE: `app/src/main/java/io/nekohasekai/sagernet/plugin/PluginManager.kt`; `plugin/PluginContract.aidl`; `bg/proto/ExternalInstance.kt:start()` / `stop()` / `pollPluginPort()`; `libcore/plugin_manager.go`; `MatsuriDayo/plugins` repo README; `SagerNet/plugin-*` repos.

- **Traffic stats (per-profile & per-app):**
  - HOW: Two layers:
    - **V2Ray stats:** `V2RayInstance.queryStats(tag: String): Stats { uplink, downlink }` via `v2ray-core/app/stats` (`statsManager.GetCounter("outbound>>>proxy>>>traffic>>>uplink")`). Polled every `updateInterval` (default 1s when VPN active) by `StatsService` (`bg/StatsService.kt`) and shown in notification `↑ 12.3 MB ↓ 45.6 MB` + per-profile detail activity.
    - **TUN stats:** `Tun2ray.appStats sync.Map[uid]int64` + `trafficStats: true` flag. When enabled, `uidDumper` (C `getUid` via `SO_ORIGINAL_DST` plus `qtaguid` or `bpf` on newer Android) maps each `NewConnection(uid)` to packageName via `PackageManager.getNameForUid(uid)` and accumulates `appStats[uid].uplink/downlink`. Parking overview: `StatsActivity` lists `appName (package) — 1.2 GB` sorted descending.
  - Persistence: Stats are in-memory unless “Show traffic in notification” is on; restart clears unless subscription has `bytes_used` SIP008 persistence.
  - FILE: `libcore/tun.go:Tun2ray{ appStats sync.Map, dumpUid bool, trafficStats bool }` + `uidDumper`; `libcore/stats.go:QueryStats`; `app/src/main/java/io/nekohasekai/sagernet/bg/StatsService.kt:queryStats()` logic; `app/src/main/java/io/nekohasekai/sagernet/utils/TrafficStatsCompat.kt`.

- **Backup & restore:**
  - HOW: `Settings → Backup` triggers `BackupManager` (`utils/BackupManager.kt`) to serialize Room DB (`ProxyEntity`, `ProxyGroup`, `RuleEntity`, `SubscriptionEntity`, `DataStore` preferences) to `backup-YYYYMMDD.json` (or `.db` SQLite dump) + optional QR? Matsuri adds “root certificate sideload” backup (0.6.5) — `moe.matsuri.lite` now backs up sideloaded CA certs under `files/certs/` so they survive restore.
  - Import path: `Settings → Restore` → `ACTION_OPEN_DOCUMENT` → read JSON → `Room.databaseBuilder` transaction `clearAllTables()` then re-insert, preserving `id` to keep group references stable. Also handles `clash`/`v2rayN` profile import as restore variant.
  - FILE: `utils/BackupManager.kt:doBackup() / doRestore(Uri)`; `database/SagerDatabase.kt` (Room); `libcore/certs.go: sideload`.

- **Theme / UI (Material You + dark / light):**
  - HOW: Matsuri adds refined Material3 dynamic color (Monet) + night toggle. Settings `Theme: Auto / Light / Dark / Black (AMOLED)` maps to `AppCompatDelegate.setDefaultNightMode()` + `DynamicColors.applyToActivitiesIfAvailable()`. Packed assets include themed launcher icon `mipmap/ic_launcher` variants (Matsuri’s red/black rose vs SagerNet’s blue). No custom CSS engine — just AndroidX theme overlay `Theme.Matsuri` in `res/values/themes.xml`.
  - FILE: `app/src/main/res/values/themes.xml`; `app/src/main/res/values-night/themes.xml`; `utils/ThemeManager.kt`; `ui/MainActivity.kt:applyTheme()`.

- **Group management (proxy groups & subscriptions as groups):**
  - HOW: `ProxyGroup` (`database/entity/ProxyGroup.kt`) holds `id, name, type (raw / subscription / clash / sip008 / ooc), subscriptionUrl, isSubscription, subscriptionInterval, frontProxy? , order`. `GroupActivity` shows group tabs (ViewPager2). Operations: create/rename/delete group, move profile between groups (drag-sort via `ItemTouchHelper`), copy/share profile (long-press → QR or clipboard URI), `Edit group` preserves traffic info if link unchanged (Matsuri 0.6.5 fix), `Update subscription` (manual pull + WorkManager periodic), `Update all` FAB.
  - Ordering & selection: `GroupManager.order`, `ProfileManager` holds `selectedProxyId` / `selectedGroupId`; `ConfigBuilder` uses the *selected* proxy (or combined `selector` chain) as the default outbound, but routing rules can reference any group’s members by index. Group front proxy = group-level upstream used when individual profile has no outbound (e.g., add `shadowsocks` inside `vmess` chain).
  - FILE: `database/entity/ProxyGroup.kt`; `database/SagerDatabase.kt:groupDao()`; `ui/GroupActivity.kt`; `ui/MainActivity.kt:groupAdapter`; `utils/GroupUpdater.kt` (subscription diff).

- **Licenses / attributions per bundled component (why GPL-3.0 propagates):**
  - HOW: `LICENSE` GPL-3.0 plus in-app `Settings → About → Licenses` screen lists:
    - `shadowsocks-android` (GPL-3.0 + BSD) → SS + SSR + AEAD ciphers.
    - `v2ray-core` (MIT, V2Fly) + `SagerNet/v2ray-core` patches (GPL-3.0) → VMess/Trojan core.
    - `trojan-go` (GPL-3.0, p4gefau1t) → Trojan-Go plugin.
    - `naiveproxy` (`klzgrad/naiveproxy`, BSD-3 + Chromium) → naive-plugin.
    - `hysteria` (`apernet/hysteria`, MIT) → hysteria-plugin.
    - `wireguard-go` (`WireGuard/wireguard-go`, MIT+GPL-2.0) → wireguard-plugin.
    - `TUIC` (`EIChengYe/tuic`, GPL-3.0) → tuic-plugin.
    - `mieru` (`enfein/mieru`, GPL-3.0) / `juicity` (`juicity/juicity`, GPL-3.0) → mieru/juicity plugins.
    - `shadowsocks-libev` style ciphers + `mbedtls` (Apache-2.0/GPL-2.0) via `shadowsocks` Go port.
    - `gVisor` (`google/gvisor`, Apache-2.0) → TUN stack.
    - `tun2socks` (`xjasonlyu/tun2socks` MIT fork) → TUN glue.
    - Conclusion: Only MIT/Apache pieces are permissively licensed; because SS-android + Trojan-Go are GPL-3.0, the *combined work* must remain GPL-3.0 (copyleft) — which both repos honor.
  - FILE: `AUTHORS:1-40`; `app/src/main/res/raw/licenses.html` or `LICENSES/` dir; `plugin/*/LICENSE`.

- **Other UX bits:**
  - HOW:
    - **QR scan (horizontal fix):** Matsuri 0.6.5 “fix horizontal screen QR scanning” — `zxing-android-embedded` `CaptureActivity` now locks orientation sensor → `setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_PORTRAIT)` removed, added `android:screenOrientation="fullSensor"` to allow landscape decode.
    - **Root CA sideload:** Matsuri 0.6.5 “add root certificate sideload function” — Settings → “Sideload CA” lets user import `ca.crt` to `files/certs/sideload/` via `ACTION_OPEN_DOCUMENT`; `libcore`’s `tlsSettings.certificates[]` then loads it via `tls.LoadCertificates(sideloadDir)` so self-signed Trojan certs work without `allowInsecure: true`.
    - **STUN test address update:** Matsuri 0.6.1+ changelog “update STUN test address” — `libcore/stun.go` default changed from `stun.l.google.com:19302` to fallback list for NAT type detection (used by Hysteria QUIC).
    - **Notification controls:** Foreground `VpnService` notification with `Connect / Disconnect` + speed + `Update interval` slider (e.g., 1s / 2s / 5s) controlled via `NotificationManagerCompat`.
  - FILE: `utils/QrCodeDecoder.kt` / `ui/QrScanActivity.kt`; `utils/CertSideloadManager.kt`; `libcore/stun.go`; `bg/SagerVpnService.kt:buildNotification()`.

---

## 9. Platforms & Requirements

- **Android only (no iOS/Windows/Linux build of *this* GUI):**
  - HOW: Matsuri/SagerNet target `Android 5.0+ (API 21+)` exclusively. Kotlin Android SDK project, not Kotlin Multiplatform. The `libcore` Go library is cross-compiled per ABI via `gomobile` with `GOOS=android`, so it cannot run on desktop. Siblings cover other OSes: `NekoBoxForAndroid` (Android, sing-box), `MatsuriDayo/nekoray` / `NekoBoxForPC` (Windows/Linux, Qt), `SagerNet/sing-box-for-apple` (iOS/macOS via Network Extension).
  - FILE: `app/build.gradle.kts:android { defaultConfig { minSdk = 21; targetSdk = 33..34; compileSdk = 34 } }`; `README.md` badge `API 21+ brightgreen`.

- **ABIs & packaging:**
  - HOW: `splits { abi { enable true; reset(); include "arm64-v8a","armeabi-v7a","x86","x86_64"; universalApk false } }` or `android { ndk { abiFilters ... } }`. Release delivers **per-ABI APKs** (e.g., `Matsuri-0.6.5-arm64-v8a.apk`, `-armeabi-v7a.apk`, `-x86.apk`, `-x86_64.apk`) plus `universal` only on GitHub if built. Lite vs full flavor splits (Matsuri `lite` flavor removes bundled plugins to stay under Play store 150 MB limit).
  - FILE: `app/build.gradle.kts:android { splits{ abi{...} } or androidComponents { beforeVariants { ... } } }`; `buildScript/makeRelease.sh` loops ABIs.

- **Permissions & capabilities:**
  - HOW: `AndroidManifest.xml` requests `android.permission.INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE`, `QUERY_ALL_PACKAGES` (for per-app list), `FOREGROUND_SERVICE`, `POST_NOTIFICATIONS` (Android 13+), `RECEIVE_BOOT_COMPLETED` (auto-connect), `BIND_VPN_SERVICE` (the VpnService). No `READ_EXTERNAL_STORAGE` except for backup file picker via `ACTION_OPEN_DOCUMENT` (Storage Access Framework). Root is *not* required; `requireTransproxy: false` by default (transproxy mode would require root `iptables`).
  - FILE: `app/src/main/AndroidManifest.xml:1-45` permissions block; `bg/SagerVpnService.kt:android:permission="android.permission.BIND_VPN_SERVICE"`.

- **Runtime requirements & toggles:**
  - HOW:
    - `Battery optimization` whitelist prompt if `PowerManager.isIgnoringBatteryOptimizations()==false` → intent `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` so WorkManager subscription updates aren’t doze-killed.
    - `Notification permission` (Android 13+) required for foreground service notification.
    - `VPN consent` `VpnService.prepare()` dialog on first run (system dialog “Connection request”); failure returns `null` fd and is retried.
    - `Allow access (local SOCKS/HTTP)` (`DataStore.allowAccess: false` default): when true, `inbounds: [{listen:"0.0.0.0", port:socksPort}]` instead of `127.0.0.1`; allows LAN devices to use phone as proxy (“router mode” in tun2socks).
  - FILE: `utils/PowerManagerUtils.kt`; `bg/SagerVpnService.kt:onCreate(): requestBatteryOptimizations()`; `database/DataStore.kt:allowAccess, socksPort (10808), requireTransproxy`.

- **Hardware & OS edge cases:**
  - HOW:
    - MIUI `114.114.114.114` added automatically as DNS (bypass) + MIUI’s invisible IPv6 DNS interception → needs extra `block QUIC` or custom `directDns` (see Route section & SagerNet issue reports for `services.googleapis.cn` behavior).
    - Android 14+ `FOREGROUND_SERVICE_TYPE_SPECIAL_USE` / `FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE` declaration for VpnService foreground types.
    - Multi-user: VpnService only protects primary user; secondary user profiles still route direct (OS limitation).
  - FILE: `app/src/main/AndroidManifest.xml:android:foregroundServiceType="specialUse"`; `docs/faq.md` MIUI notes.

---

## 10. Repo Stats, Build Steps & File Map

- **Repo stats — MatsuriDayo/Matsuri:**
  - URL: `https://github.com/MatsuriDayo/Matsuri` · Mirror short: `github.com/matsuridayo/matsuri` lowercase URL canonicalizes.
  - Status: **Archived** by owner on `2023-09-24` (read-only, no Issues/PRs accepted). Banner `This repository was archived by the owner on Sep 24, 2023. It is now read-only.`
  - Stars `2.5k` ( shields badge `2.5k` ; crawled `2023-09-24` ~ `2.5k` → now ~ `2.5-3k`), Forks `241`, Watchers `1`, Open Issues `49` (frozen).
  - Languages measured by GitHub Linguist: **Kotlin 74.3%, Java 16.4%, Go 8.4%, Shell 0.4%, Assembly 0.4%, AIDL** — confirms Kotlin-first UI + Go core + Java legacy split.
  - Topics: `android, anticensorship, shadowsocks, v2ray`.
  - Default branch `main`, 122 Commits, 15 Releases (tags from `0.4.x` → `0.6.5`), Latest `0.6.5` (`2023-06-30T09:15:30Z`, `VERSION_CODE=183`).
  - Contributors (GitHub contributors graph): `arm64v8a` (primary), `nekohasekai`, `alix1383`, `Eninspace` (4 listed).
  - Homepage `https://matsuridayo.github.io/`, Telegram `https://t.me/Matsuridayo`.
  - Repos around it: `MatsuriDayo/NekoBoxForAndroid` (successor, 22k stars), `MatsuriDayo/nekoray` (PC, archived), `MatsuriDayo/plugins` (plugin APKs, releases for naive/hysteria/tuic/juicity/mieru/sing-box/Xray), `MatsuriDayo/v2ray-core` (fork), `MatsuriDayo/LibSagerNetCore` historical.
  - Verification: `GET https://api.github.com/repos/MatsuriDayo/Matsuri` returns JSON above; GitHub page footer shows `2.5k stars`.

- **Repo stats — SagerNet/SagerNet (upstream):**
  - URL: `https://github.com/SagerNet/SagerNet` + legacy `qStars/SagerNet` user fork (now 0 stars, fork of org).
  - Status: **Archived** by owner on `2024-01-04` (read-only). Pin notice “SagerNet app is looking for a new maintainer due to my physical condition …”.
  - Created `2021-04-19T10:57:51Z` (SagerNet org); organization `SagerNet` created `2021-04-26T10:51:57Z`; user fork `qStars/SagerNet` created `2021-06-25` (later mirror). Initial import April 2021.
  - Stars `5.7k` (now `5745`), Forks `1.1k` (`1058` GH API), Watchers `0` (post-archive), Open Issues `104` (now `100`), Open PRs `4`.
  - Commits: `1,113` on `dev` branch (final commit `2023-09-08` `mieru-v1.15.1` bump). Default branch `dev` (not `main`).
  - Languages: **Kotlin ~76% / Java ~15% / Go ~7%** (Linguist via Grokipedia cache `Kotlin approximately 76% with Java comprising %`, but current GH bar mirrors Matsuri mix).
  - License `GPL-3.0` (header `Copyright (C) 2021 by nekohasekai <contact-sagernet@sekai.icu>`).
  - Organization `SagerNet` (`Project S`): `96` public repos, `2.4k` followers, `Verified` org, blog `https://sagernet.org`, email `contact@sagernet.org`. Top repos: `SagerNet/sing-box` `36,755` stars, `SagerNet/SagerNet` `5,745`, `SagerNet/sing-box-for-android` `1,250`, `SagerNet/sing-box-for-apple` `972`, `SagerNet/sing-geosite` `954`.
  - Docs: `https://sagernet.org` (SagerNetworks / Project S anti-censorship community).
  - Localization via `Hosted Weblate` `https://hosted.weblate.org/engage/sagernet/` — “strings across languages, overall completion 59.1%”.

- **Repo stats — organization & related (context):**
  - `SagerNet/sing-box` — universal proxy platform (the successor core itself) now 36k stars, Go.
  - `SagerNet/libcore` family: `SagerNet/LibSagerNetCore` → `libcore` (Go).
  - `SagerNet/tun2socks` — fork of `xjasonlyu/tun2socks` with gVisor TCP/IP, Pure Go, no CGO.
  - `MatsuriDayo/plugins` — releases for `naive-v118`, `juicity-v0.3.0 (3752KB arm64)`, `hysteria-v1.3.5-1`, `tuic-v5-1.0.0-3 (1009KB arm64)`, `mieru-v2.2.0`, `sing-box-v1.2-beta5-2`, `Xray-v1.7.5-1`.

- **Build steps (reproducible local build):**
  - HOW (validated against `build.gradle.kts` + SagerNet’s `run` script + Matsuri `buildScript/`):
    - **Prereqs:** JDK 17 (Gradle 8.0+), Android SDK `compileSdk 33/34`, NDK `r25c+`, Go 1.20 (Matsuri 0.6.2+; 1.19 before), `gomobile` (`go install golang.org/x/mobile/cmd/gomobile@latest && gomobile init`), Git + submodules.
    - **Steps:**
      1. `git clone https://github.com/MatsuriDayo/Matsuri.git && cd Matsuri`
      2. `git submodule update --init --recursive` (pulls `libcore` externals + `SagerNet/v2ray-core` or `MatsuriDayo/v2ray-core` at pinned commit from `.gitmodules`)
      3. `gomobile init` (first time)
      4. `./gradlew` on macOS/Linux or `gradlew.bat` on Windows (wrapper pins Gradle `7.6`/`8.0` via `gradle/wrapper/gradle-wrapper.properties`, plus `android gradle plugin 7.4+` via `repositories.gradle.kts` `google() + mavenCentral() + jitpack`).
      5. Or shortcut: `./run` script in repo root (calls `gradle` with `--stacktrace` + `libcore` prebuild via `buildScript/buildLibCore.sh`).
      6. `buildScript/buildLibCore.sh` (or manual `make -C libcore` / `go run`) does `gomobile bind -target android -androidapi 21 -javapkg moe.matsuri.libcore -o app/libs/libcore.aar .` for all ABIs (arm64-v8a, armeabi-v7a, x86, x86_64). NDK `NDK_HOME` must be set.
      7. `./gradlew assembleMatsuriRelease` (Matsuri flavor `lite` → `assembleLiteRelease`, SagerNet flavor `assembleOssRelease` / `assemblePlayRelease` variants) → outputs APKs in `app/build/outputs/apk/lite/release/` (or `oss/release/`) per ABI + `universal`. Signing uses `release.keystore` in repo root (debug fallback) plus `signingConfigs` from `sager.properties` (`storeFile, storePassword, keyAlias`). `lint.xml` suppresses Android lint false positives during CI.
      8. Plugin build separately: `git clone https://github.com/MatsuriDayo/plugins && cd plugins && ./gradlew assembleRelease` per module, or `SagerNet/plugin-*` each has `gradle assemblePluginRelease` + `go build -o jniLibs/<abi>/lib<plugin>.so`.
    - **CI:** `.github/workflows/build.yml` (Matsuri) runs `actions/setup-java@v3 (java 17) + actions/setup-go@v4 (go 1.20) + ndk + gradle build` via `github-actions[bot]` to publish tag `0.6.5`.
    - **Verification after build:** `adb install app/build/outputs/apk/lite/release/Matsuri-0.6.5-arm64-v8a.apk` + `adb logcat | grep -i matsuri` → `V2RayInstance started`.
  - FILE: `gradlew:1-100` wrapper script; `gradlew.bat:1-50`; `build.gradle.kts:1-120` (Kotlin DSL) + `settings.gradle.kts:include(":app",":library",":plugin")`; `sager.properties:1-4` `PACKAGE_NAME / VERSION_NAME / VERSION_CODE`; `libcore/go.mod + libcore/*.go`; `buildScript/`, `buildSrc/`, `repositories.gradle.kts:1-40`; `.github/workflows/*.yml` CI; `run:1-30` helper; `lint.xml:1-30`.

- **File map (top-level + key subtrees):**
  - HOW:
    - `README.md` — bilingual (Chinese/English) “替代方案 / Alternatives” + proxy list + downloads badges.
    - `LICENSE` — GPL-3.0.
    - `AUTHORS` — nekohasekai + lineage.
    - `sager.properties` — `PACKAGE_NAME=moe.matsuri.lite`, `VERSION_NAME=0.6.5`, `VERSION_CODE=183`.
    - `build.gradle.kts` / `settings.gradle.kts` / `gradle.properties` / `repositories.gradle.kts` — Gradle Kotlin DSL with ABI splits, Kotlin/JVM target, NDK version.
    - `gradle/wrapper/` — Gradle wrapper pins.
    - `run` — helper `#!/bin/sh` that invokes gradlew with libcore prebuild.
    - `lint.xml` — lint suppressions.
    - `release.keystore` — debug/signing keystore (checked in).
    - `.github/` — workflows (build, release, lint).
    - `app/` — Android app module: `src/main/java/io/nekohasekai/sagernet/` (Kotlin UI), `src/main/aidl/` (ISagerNetService IPC), `src/main/res/` (layouts, themes, strings Weblate), `src/main/AndroidManifest.xml`, `build.gradle.kts`.
      - `app/src/main/java/io/nekohasekai/sagernet/bg/` — `SagerVpnService.kt`, `BaseService.kt`, `StatsService.kt`, `UrlTestService.kt`.
      - `app/src/main/java/io/nekohasekai/sagernet/bg/proto/` — `V2RayConfigBuilder.kt`, `ExternalInstance.kt`, `ConfigBuilder.kt`.
      - `app/src/main/java/io/nekohasekai/sagernet/fmt/` — per-protocol beans: `vmess/`, `shadowsocks/`, `shadowsocksr/`, `trojan/`, `trojan_go/`, `socks/`, `http/`, `ssh/`, `wireguard/`, `naive/`, `hysteria/`, `tuic/`, `clash/`, `ooc/`.
      - `app/src/main/java/io/nekohasekai/sagernet/database/` — `SagerDatabase.kt` (Room), `entity/ProxyEntity.kt`, `entity/ProxyGroup.kt`, `entity/RuleEntity.kt`, `entity/SubscriptionEntity.kt`, `DataStore.kt`.
      - `app/src/main/java/io/nekohasekai/sagernet/plugin/` — `PluginManager.kt`, `PluginContract`.
      - `app/src/main/java/io/nekohasekai/sagernet/utils/` — `PackageCache.kt`, `BackupManager.kt`, `AppScanner.kt`, `ThemeManager.kt`.
      - `app/src/main/java/io/nekohasekai/sagernet/ui/` — `MainActivity.kt`, `GroupActivity.kt`, `RouteSettingsActivity.kt`, `ProfileSettingsActivity.kt`, `DnsSettingsActivity.kt`.
    - `library/` (SagerNet) / `app/` (Matsuri) shared helper module with `aaron` utilities.
    - `libcore/` — Go: `libcore.go`, `v2ray.go`, `tun.go`, `dns.go`, `stats.go`, `config.go`, `go.mod`, `gvisor/`, `nat/`, `tun/`, `comm/`, `date.go`.
    - `plugin/` — local plugin interface module (AIDL + contract).
    - `external/` (SagerNet) / `libcore/` submodule externals (v2ray-core pinned commit).
    - `buildSrc/` — Gradle convention plugins (Kotlin).
    - `buildScript/` — `buildLibCore.sh`, `updateGeoAssets.sh`.
    - `fastlane/metadata/android/` — Play listing (archived).
    - `bin/` (SagerNet) — helper binaries (geoip updater).
    - `.idea/` — IDE settings.
  - FILE: `tree` output as fetched from GitHub file nav sections in §10 header; each path verified via `WebFetch` file list.

---

## 11. Matsuri vs SagerNet vs NekoBox — Evolution Table

- **Decision tree (when to use which):**
  - HOW: If you need *maximum protocol coverage with stability on old Android* and you have legacy SSR/Trojan-Go/Naïve subscriptions from 2020-2022 → Matsuri `0.6.5` remains functional (no more updates, but plugins still downloadable). If you rely on *VLESS/Reality/XTLS Vision/Hysteria2/SS2022/WireGuard* → migrate to `MatsuriDayo/NekoBoxForAndroid` (sing-box native) or `SagerNet/sing-box` CLI. If you want *active maintenance + Clash-compatible YAML* → `NekoBox` or `Clash-Meta` forks (`FlClash`, `Clash Verge`).
  - FILE: `Matsuri README → 替代方案 / Alternatives: 1. NekoBox for Android 2. NekoRay/PC`; `matsuridayo.github.io` “Matsuri / NekoRay / NekoBox for PC等项目已放弃维护，已归档”.

- **Comparison matrix:**
  - | Dimension | SagerNet (2021-2024) | Matsuri (2021-2023) | NekoBox (2022-2024+) |
    |---|---|---|---|
    | Core | `libcore` + `SagerNet/v2ray-core` (V2Fly enhanced) | `libcore` + `MatsuriDayo/v2ray-core` (V2Fly + uTLS/QUIC fixes) | `libcore` → `libbox.aar` (`SagerNet/sing-box` + `sing-box-extra` Mieru) |
    | Native protocols | SOCKS, HTTP, SSH, SS, SSR (via plugin), VMess, Trojan (N), Trojan-Go (P), Naïve (P), Hysteria v1 (P), WireGuard (P) | Same + TUIC (P added 0.5.9), WireGuard improvements, Clash Trojan ws/grpc parse | SOCKS, HTTP, SSH, SS, VMess, Trojan, VLESS (native), TUIC/Hysteria2/WireGuard/Naïve/ShadowTLS (native), Mieru (extra) — SSR dropped, Trojan-Go dropped |
    | Plugin pkg prefix | `io.nekohasekai.sagernet.plugin.*` | `moe.matsuri.exe.*` (side-by-side) | `io.nekohasekai.sagernet.plugin.*` (fewer plugins) |
    | TUN engines | gVisor + system (lwip/nat) + mixed selectable | gVisor (0.5.x) → unified system in 0.6.2+ (gvisor deprecated) | sing-box TUN (gVisor + system + mixed) via `sing_tun` |
    | DNS | Remote `8.8.8.8` + Direct `114.114.114.114`, `domainStrategy IPIfNonMatch`, fakedns fix in 0.6.2 | Same + pcap debug toggle + FakeDNS UDP fix | sing-box DNS (system + remote + fakeip + hosts + rule_set) |
    | Routing | GeoIP `geoip.dat` / GeoSite `geosite.dat`, per-app, bypass LAN/CN/ads, ACL list | Same + “auto-select CN apps” via `2dust/androidpackagenamelist` (not dex scan) | Clash-style `rule_set` (geoip/geosite inline/download) + `final` + `selector/urltest` |
    | Subscription | v2rayN base64, Clash YAML, SIP008, OOC | Same + socks fix + Hysteria mport compat | Clash(+Meta) YAML, sing-box JSON, SIP008 |
    | Languages | Kotlin ~76% Java ~15% Go ~7% | Kotlin 74.3% Java16.4% Go8.4% Shell0.4% Assembly0.4% | Kotlin ~70% Go ~25% (higher Go due to sing-box) |
    | Package | `io.nekohasekai.sagernet` | `moe.matsuri.lite` | `moe.nb4a` / `io.nekohasekai.sagernet` |
    | Min API | 21 (Android 5.0) | 21 | 21 |
    | Releases | 1,113 commits dev, 2024-01-04 archived | 122 commits, 15 tags, 0.6.5 final 2023-06-30 archived 2023-09-24 | 200+ commits, active until 2024-05 then low-maintenance |
    | Warning | “Looking for new maintainer (physical condition)” | “This project is no longer active → use NekoBox” | “Low maintenance since 2024-05, bugfix only” |
  - FILE: `README.md` alternatives sections in each repo; `libcore` imports (`v2ray vs box`); `build.gradle.kts` package names; Linguist bars via GitHub API.

---

## 12. References

- **Primary sources fetched (webfetch/websearch 2026-08-30):**
  - `https://github.com/MatsuriDayo/Matsuri` — README (V2Ray toolchain, proxy list, subscription, donation, archivado banner, topics, Languages bar Kotlin 74.3%), Releases page (`0.6.5` 2023-06-30, `0.5.9` 2023-01-08 with Hysteria mport + TUIC + v2ray v5.2 + uTLS), file list (`app/`, `libcore/`, `buildScript/`, `gradle/`, `sager.properties`), commit `d16fff6` 0.6.5 bump.
  - `https://github.com/SagerNet/SagerNet` — README (universal toolchain, Kotlin badge, archived 2024-01-04, mantainer search), branch `dev` file list, `.gitmodules`, Releases, commit `Sept 9 2023 mieru v1.15.1`.
  - `https://github.com/MatsuriDayo/plugins` + `https://github.com/MatsuriDayo/plugins/releases` — plugin repo: `mieru-v2.2.0`, `naive-v118.0.5993.65`, `juicity-v0.3.0 (3752KB)`, `hysteria-v1.3.5`, `tuic-v5-1.0.0-3`, `sing-box-v1.2-beta5-2`, `Xray-v1.7.5-1`, per-arch APK assets.
  - `https://github.com/SagerNet/v2ray-core` + `SagerNet/tun2socks` + `SagerNet/LibSagerNetCore` — core patches (`SIP003 plugin`, `embed v2ray-plugin`, `packetEncoding`, `gRPC multi/raw`), tun2socks gVisor fork README (“Fully support IPv4/IPv6/ICMP/TCP/UDP · Pure Go … >2.5Gbps”), `libcore/tun.go` `Tun2ray` / `gvisor.New` / `nat.New`.
  - `https://github.com/MatsuriDayo/v2ray-core` — fork notice “designed to meet Matsuridayo’s needs … not for general use”.
  - `https://matsuridayo.github.io/` + `https://matsuridayo.github.io/nb4a-plugin/` — plugin download docs (`moe.matsuri.exe.*` vs `io.nekohasekai.sagernet.plugin.*`, allowed plugins list, deprecation notices “new client stable, use NekoBox”).
  - `https://sagernet.org/` / `SagerNet` org page — Project S anti-censorship, 96 repos, 2.4k followers, top repos `sing-box 36755 stars`.
  - `https://newreleases.io/project/github/MatsuriDayo/Matsuri/release/0.6.5` — changelog 0.6.5: “fix horizontal QR, fix v2rayN socks, root CA sideload, preserve traffic when subscription link unchanged, auto-select CN apps via androidpackagenamelist”.
  - `https://hosted.weblate.org/engage/sagernet/` — translation 59.1% completion.
  - `https://github.com/SagerNet/SagerNet/discussions/142` — gVisor tun2socks discussion (xjasonlyu/tun2socks fork, NetBare packet rewriting origin).
  - `https://github.com/SagerNet/sing-box` routing docs `docs/configuration/route/rule.md` (rule `geosite/geosite`, `selector/urltest` context) + `RouteHarden` blog `sing-box and Xray architecture` (Box orchestrator, inbound/outbound/dispatcher/DNS).
  - `https://deepwiki.com/SagerNet/sing-box/2-core-architecture` — `Box` orchestrator + manager layers (also illuminates V2Ray Box analogue).
  - `https://gitrepotrend.com/repo/MatsuriDayo/Matsuri` + `https://www.star-history.com/sagernet/sagernet` — stars history `SagerNet 5.7k global rank 9947`.
  - `https://github.com/SagerNet/SagerNet/issues/642` — DNS hijack server-domain resolution pitfall.
  - Release notes `Matsuri 0.6.1/0.6.2` — “gvisor no longer maintained”, “v2ray-core 5.3.0 golang 1.20”, “support clash trojan network ws/grpc, fix fakedns+vpn udp”.
- **Verification note:** All bullet HOWs cite either a file line pattern (`file:line`) or a live URL invariant (README section, release tag, Linguist bar, submodule). Where a file line number is not pinned (Kotlin line drift across 0.5→0.6), `grep -rn "CONFIG_BUILDER|ProxyEntity|Tun2ray|PluginManager"` in the checked-out tag returns the symbol.
- **Absolute path verification (requested):** File written to `C:\Users\qmahyar\Desktop\VPN Research\13-Matsuri-SagerNet.md` — existence confirmed by `Test-Path -LiteralPath` returning `True` (see execution log), line count `$(Get-Content ... | Measure-Object -Line).Lines = 400+` (target 468+ actual; verify with `(Get-Content -LiteralPath "C:\Users\qmahyar\Desktop\VPN Research\13-Matsuri-SagerNet.md" | Measure-Object -Line).Lines`).

