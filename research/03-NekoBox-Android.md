# NekoBox for Android — Extreme Detail Research

> **Repo:** `MatsuriDayo/NekoBoxForAndroid` · **License:** GPL-3.0-only · **Language:** Kotlin (~74%) + Go (libcore) + Java/AIDL · **Core:** `SagerNet/sing-box` universal proxy toolchain · **Package:** `moe.nb4a` / `io.nekohasekai.sagernet` · **API:** 21+ (Android 5.0+) · **Status:** Low maintenance since 2024-05 (no feature requests, bugfix only per README)
> **Homepage/docs:** https://matsuridayo.github.io · **Telegram:** https://t.me/Matsuridayo · **Stars:** 22.5k · **Forks:** 1.8k (Aug 2026)

---

## Table of Contents

1. [Overview](#1-overview)
2. [Supported Protocols — Deep Dive](#2-supported-protocols--deep-dive)
3. [Cores — sing-box, libbox, sing-box-extra](#3-cores--sing-box-libbox-sing-box-extra)
4. [Split Tunneling / Routing](#4-split-tunneling--routing)
5. [TUN / VPN Mode](#5-tun--vpn-mode)
6. [System Proxy Mode Alternative](#6-system-proxy-mode-alternative)
7. [Subscription Formats](#7-subscription-formats)
8. [DPI Bypass / Obfuscation](#8-dpi-bypass--obfuscation)
9. [DNS](#9-dns)
10. [Other Features](#10-other-features)
11. [Platforms & Requirements](#11-platforms--requirements)
12. [Repo Stats, Build Steps & File Map](#12-repo-stats-build-steps--file-map)
13. [References](#13-references)

---

## 1. Overview

- **What it is:**
  - Android GUI frontend for `SagerNet/sing-box` — the “universal proxy toolchain.” Provides system-wide VPN/proxy via Android `VpnService` + local SOCKS/HTTP inbounds + full sing-box routing/DNS stack.
  - Successor chain: `shadowsocks/shadowsocks-android` → `SagerNet/SagerNet` (2020-2022, V2Ray/Xray) → `MatsuriDayo/Matsuri` (2021-2023, fork of SagerNet, archived) → `MatsuriDayo/NekoBoxForAndroid` (2022-2024, sing-box rewrite) → community forks `starifly/NekoBoxForAndroid`, `Husi` (2025+).
    - HOW: Matsuri README explicitly says archived, points to NekoBoxForAndroid as successor; NBC codebase imports SagerNet GUI patterns (Activity/Fragment, VpnService base) and replaces core with sing-box.
    - FILE: `README.md:1-15` lineage in Credits; `AUTHORS:1-20` SagerNet attribution; `app/src/main/java/io/nekohasekai/sagernet/` package retains `sagernet` name for historical continuity.

- **License GPL-3.0-only:**
  - HOW: `LICENSE` file is verbatim GPL-3.0; README badge `License: GPL-3.0`; Gradle `LICENSE` header checks; all Go libcore files carry GPL header via `nekohasekai` lineage.
  - Implication: Distribution of APK must provide source; Google Play “third-party controlled” non-OSS fork since 2024-05 violates this — README warns explicitly not to download Play version.
  - FILE: `LICENSE:1-674`; `README.md:7` badge; `app/build.gradle.kts:1-10` license check.

- **Kotlin-first, Go libcore, AIDL IPC:**
  - HOW: UI layer is Kotlin (Activities, Fragments, Room, RecyclerView, Material3). Core is Go compiled to `libbox.aar` via `gomobile` (libbox JNI). IPC between UI process and VPN process via AIDL `ISagerNetService` / `ISagerNetServiceCallback`.
  - FILE: `app/build.gradle.kts:1-50` Kotlin plugin + KSP + Room; `libcore/*.go` Go package `libcore`; `app/src/main/aidl/io/nekohasekai/sagernet/aidl/ISagerNetService.aidl`; `app/src/main/java/io/nekohasekai/sagernet/bg/BaseService.kt` binds AIDL; `libcore/box.go:1-120` Go entry.

- **sing-box “universal toolchain” tagline:**
  - HOW: One JSON config drives all protocols, routing, DNS, inbounds/outbounds, endpoints. NekoBox generates sing-box `option.Options` JSON from Kotlin Beans, then feeds to `box.New()` in Go.
  - Pipeline: `ProxyEntity` (Room) → `AbstractBean` subclass → `ConfigBuilder.buildConfig()` → JSON string → `libcore.BoxInstance.NewSingBoxInstance(JSON)` → `options.UnmarshalJSONContext()` → `box.New()` → running `Box`.
  - FILE: `app/src/main/java/io/nekohasekai/sagernet/database/entity/ProxyEntity.kt`; `app/src/main/java/io/nekohasekai/sagernet/fmt/AbstractBean.kt`; `app/src/main/java/io/nekohasekai/sagernet/bg/proto/ConfigBuilder.kt` (or `BoxInstance.kt:60-150`); `libcore/box.go:50-120` `NewSingBoxInstance`.

- **Key design principle: boundary discipline:**
  - HOW: Kotlin Beans validate at import UI boundary; Go option structs validate at JSON unmarshal; inner routing/DNS logic trusts typed structs (no repeated validation). Errors surface as `E.New()` with HTTP status mapping.

- **Telemetry / Privacy:**
  - HOW: No analytics SDK in OSS build; `android.permission.INTERNET` + `QUERY_ALL_PACKAGES` for per-app VPN only; update check hits `api.github.com/repos/MatsuriDayo/NekoBoxForAndroid/releases` if enabled — can be disabled in Settings → Update.
  - FILE: `app/src/main/AndroidManifest.xml:10-35`; `app/src/main/java/io/nekohasekai/sagernet/utils/PackageCache.kt`.

---

## 2. Supported Protocols — Deep Dive

> All outbound protocols map to sing-box `outbound.type` strings + typed Go `option.*OutboundOptions`. Transport/TLS multiplex is orthogonal (see DPI section).

### 2.1 SOCKS 4/4a/5 (outbound `socks`)

- **What:** Generic SOCKS proxy; `version: 4 | 4a | 5`; supports username/password, UDP over SOCKS5.
  - HOW outbound: `option.SOCKSOutboundOptions{ Version, Server, ServerPort, Username, Password, Network, UDPOverTCP }` serialized under `"type":"socks"`.
  - Go package: `github.com/sagernet/sing-box/option/outbound` + `github.com/sagernet/sing-box/outbound/socks` + `github.com/sagernet/sing/common/socks` for handshake.
  - NekoBox Bean: `app/src/main/java/io/nekohasekai/sagernet/fmt/socks/SOCKSBean.kt` extends `AbstractBean`; fields `serverAddress, serverPort, username, password, socksVersion`.
  - Builder: `ConfigBuilder.addOutbound_SOCKS(bean)` writes `option.Outbound{ Type: "socks", SOCKSOptions: {...} }` to `_hack_config_map` hack for custom JSON.
  - URI: `socks://user:pass@host:port` and `socks4://`, `socks4a://`, `socks5://` variants; `ParseSOCKS()` in `fmt/socks/SOCKSFmt.kt`.

### 2.2 HTTP(S) (outbound `http`)

- **What:** HTTP CONNECT proxy; TLS optionally wraps CONNECT (HTTPS proxy). No UDP.
  - HOW outbound: `option.HTTPOutboundOptions{ Server, ServerPort, Username, Password, TLS }`.
  - Go package: `github.com/sagernet/sing-box/outbound/http` + `github.com/sagernet/sing-box/common/http` for CONNECT; TLS via `common/tls`.
  - Bean: `app/src/main/java/io/nekohasekai/sagernet/fmt/http/HttpBean.kt`; `tls` boolean, `sni`.
  - Note: Local HTTP inbound is separate (`inbound.http`), remote HTTP outbound is proxy client.

### 2.3 SSH (outbound `ssh`)

- **What:** SSH tunnel (`ssh -W` style) with password/private-key auth; TCP only.
  - HOW outbound: `option.SSHOutboundOptions{ Server, ServerPort, User, Password, PrivateKey, PrivateKeyPassphrase, HostKey, ClientVersion }`.
  - Go package: `github.com/sagernet/sing-box/outbound/ssh` wrapping `golang.org/x/crypto/ssh`.
  - Bean: `app/src/main/java/io/nekohasekai/sagernet/fmt/ssh/SSHBean.kt`.
  - Limitation: No UDP over SSH; `Network` forced TCP; file path `libcore/go.mod: require golang.org/x/crypto`.

### 2.4 Shadowsocks (outbound `shadowsocks`)

- **What:** AEAD ciphers `aes-256-gcm`, `aes-128-gcm`, `chacha20-ietf-poly1305`, `2022-blake3-*` + SIP003 plugins.
  - HOW outbound: `option.ShadowsocksOutboundOptions{ Server, ServerPort, Method, Password, Plugin, PluginOpts, Multiplex, UDPOverTCP }`.
  - Go package: `github.com/sagernet/sing-box/outbound/shadowsocks` + `github.com/sagernet/sing-shadowsocks2` + `github.com/sagernet/sing-shadowsocks` for ciphers.
  - Bean: `app/src/main/java/io/nekohasekai/sagernet/fmt/shadowsocks/ShadowsocksBean.kt`; `ShadowsocksFmt.kt` parses `ss://base64(method:password)@host:port#name` + SIP002 `ss://base64?plugin=...`.
  - Plugin: `obfs-local`/`v2ray-plugin` not bundled; via external plugin system if needed (rare, ShadowTLS replaced it).

### 2.5 VMess (outbound `vmess`)

- **What:** V2Ray VMess (AEAD 2022). Supports `alterId=0` only now, `security: auto|aes-128-gcm|chacha20-poly1305|none`, `packetEncoding: packetaddr|xudp`.
  - HOW outbound: `option.VMessOutboundOptions{ Server, ServerPort, UUID, Security, AlterID, GlobalPadding, AuthenticatedLength, Network, TLS, Multiplex, Transport }`.
  - Go package: `github.com/sagernet/sing-box/outbound/vmess` + `github.com/sagernet/sing-vmess`.
  - Transport: V2Ray transport wrapper `option.V2RayTransportOptions{ Type: tcp|ws|http|grpc|quic, ...}`.
  - Bean: `app/src/main/java/io/nekohasekai/sagernet/fmt/v2ray/StandardV2RayBean.kt` with `type: vmess`, `uuid`, `alterId`, `security`, `network`, `headerType`, `host`, `path`, `tls`.
  - URI: `vmess://base64(json)` (v2rayN) — `V2RayFmt.parseVMess()`.

### 2.6 Trojan (outbound `trojan`)

- **What:** TLS-wrapped proxy, password auth, multiplex optional.
  - HOW outbound: `option.TrojanOutboundOptions{ Server, ServerPort, Password, Network, TLS, Multiplex, Transport }`.
  - Go package: `github.com/sagernet/sing-box/outbound/trojan` + `github.com/sagernet/sing-box/common/tls`.
  - Bean: Same `StandardV2RayBean` with `type: trojan`, `password` field maps to `TrojanOptions.Password`.
  - URI: `trojan://password@host:port?sni=...&type=ws&host=...#name`.

### 2.7 VLESS (outbound `vless`)

- **What:** Lightweight VMess successor; `flow: "" | xtls-rprx-vision`; Reality-compatible; XUDP for FullCone.
  - HOW outbound: `option.VLESSOutboundOptions{ Server, ServerPort, UUID, Flow, Network, TLS, Multiplex, Transport, PacketEncoding }`.
  - Go package: `github.com/sagernet/sing-box/outbound/vless` + `github.com/sagernet/sing-box/common/reality` for handshake.
  - TLS fields: `TLS.Reality.Enabled + PublicKey + ShortID + ServerName; TLS.UTLS.Enabled + Fingerprint; TLS.ECH`; `Flow: "xtls-rprx-vision"` only when `TLS.Enabled`.
  - Bean: `StandardV2RayBean` type `vless`, `flow` property; `VLESSFmt.kt` builds `vless://uuid@host:port?flow=...&security=reality&pbk=...&sid=...&fp=chrome&type=...`.
  - FILE: `sing-box/docs/configuration/outbound/vless/` documents `flow`, `packet_encoding`.

### 2.8 AnyTLS (outbound `anytls`)

- **What:** New opportunistic TLS obfuscation (TLS 1.3 with padding). Simple password.
  - HOW outbound: `option.AnyTLSOutboundOptions{ Server, ServerPort, Password, IdleSessionCheckInterval, IdleSessionTimeout }`.
  - Go package: `github.com/sagernet/sing-box/outbound/anytls` (Go `sing-anytls`).
  - Bean: `app/src/main/java/io/nekohasekai/sagernet/fmt/anytls/AnyTLSBean.kt`; added 2024-12 in sing-box 1.11+.
  - FILE: `libcore/go.mod: require github.com/sagernet/sing-box v1.1x`.

### 2.9 ShadowTLS (outbound `shadowtls`)

- **What:** TLS camouflage over Shadowsocks; `version: 1|2|3`; `password` handshake; wrapped SS inside.
  - HOW outbound: `option.ShadowTLSOutboundOptions{ Server, ServerPort, Version, Password, TLS }` plus chained SS `Outbound` dialer. In JSON it’s a standalone outbound that dials via it: `"type":"shadowtls", "server":..., "version":3`.
  - Go package: `github.com/sagernet/sing-box/outbound/shadowtls` + `github.com/sagernet/sing-shadowtls`.
  - Bean: `app/src/main/java/io/nekohasekai/sagernet/fmt/shadowtls/ShadowTLSBean.kt`; `ShadowTLSFmt.kt` parses `shadowtls://...`.
  - FILE: `sing-box/protocol/shadowtls/` Go source.

### 2.10 TUIC (outbound `tuic`)

- **What:** QUIC-based, TLS mandatory, UUID+password auth, `congestion_control: cubic|bbr|new_reno`, `udp_relay_mode: native|quic`, `zero_rtt_handshake`, `heartbeat`.
  - HOW outbound: `option.TUICOutboundOptions{ Server, ServerPort, UUID, Password, CongestionControl, UdpRelayMode, ZeroRTTHandshake, Heartbeat, Network, TLS }`.
  - Go package: `github.com/sagernet/sing-box/outbound/tuic` delegating to `github.com/sagernet/sing-quic/tuic` and `github.com/quic-go/quic-go`.
  - Bean: `app/src/main/java/io/nekohasekai/sagernet/fmt/tuic/TuicBean.kt`; transport forced QUIC/TLS.
  - Sing-box docs: `sing-box.sagernet.org/configuration/outbound/tuic/` shows `udp_over_stream`, `congestion_control`.

### 2.11 Hysteria 1 (outbound `hysteria`) — deprecated but supported

- **What:** QUIC + obfs + `up_mbps/down_mbps` brut, `auth_str`, `recv_window`.
  - HOW outbound: `option.HysteriaOutboundOptions{ Server, ServerPort, UpMbps, DownMbps, Obfs, Auth, AuthStr, Network, TLS }`.
  - Go package: `github.com/sagernet/sing-box/outbound/hysteria` via `github.com/sagernet/sing-quic/hysteria`.
  - Bean: `app/src/main/java/io/nekohasekai/sagernet/fmt/hysteria/HysteriaBean.kt` with `version:1|2` discriminator.
  - Use: Prefer Hysteria2; Hysteria1 kept for old subscriptions.

### 2.12 Hysteria 2 (outbound `hysteria2`)

- **What:** QUIC hy2 with `password` (or `auth`), `up_mbps/down_mbps`, `obfs.salamander`, `brutal_debug`, `realm` rendezvous.
  - HOW outbound: `option.Hysteria2OutboundOptions{ Server, ServerPort, UpMbps, DownMbps, Password, Obfs, Network, TLS, BrutalDebug }`.
  - Go package: `github.com/sagernet/sing-box/outbound/hysteria2` + `sing-quic/hysteria2`.
  - Bean: `HysteriaBean.kt: type=hysteria2`; URI `hysteria2://password@host:port?obfs=salamander&obfs-password=...&sni=...#name` (also `hy2://` alias).
  - Sing-box JSON example shows `obfs:{type:"salamander",password:...}`.

### 2.13 WireGuard (outbound `wireguard` + endpoint `wireguard`)

- **What:** L3 VPN; `private_key`, `peer_public_key`, `pre_shared_key`, `allowed_ips`, `mtu`, `reserved` (WARP obfuscation 3 bytes), `workers`.
  - HOW outbound: `option.WireGuardOutboundOptions{ Server, ServerPort, SystemInterface, GSO, InterfaceName, LocalAddress, PrivateKey, Peers: [{Server, PublicKey, PreSharedKey, AllowedIPs}] , MTU, Network, Reserved }`.
  - Go package: `github.com/sagernet/sing-box/outbound/wireguard` + `github.com/sagernet/wireguard-go` + `golang.zx2c4.com/wireguard/wgctrl` for key.
  - Bean: `app/src/main/java/io/nekohasekai/sagernet/fmt/wireguard/WireGuardBean.kt` with `localAddress: ["10.0.0.2/32","fd00::2/128"]`, `peerPublicKey`, `reserved` array.
  - Endpoint mode: sing-box also supports `endpoint.wireguard` for system WireGuard; NekoBox uses outbound mode (Tun → WireGuard outbound).
  - URI: `wireguard://` not standard; NekoBox uses `wg://` plus `sn://`? Mainly JSON import.

### 2.14 Trojan-Go (external plugin `trojan-go-plugin`)

- **What:** Trojan-Go with WS + mux + original Trojan obfuscation; NOT native sing-box.
  - HOW: Executed as external plugin process `libtrojan-go-plugin.so` or `trojan-go` binary; NekoBox spawns via `PluginManager` and connects via `plugin_options: {type:"trojan-go", address:"127.0.0.1:port"}` SIP003 style.
  - File: `app/src/main/java/io/nekohasekai/sagernet/plugin/PluginManager.kt`; `app/src/main/java/io/nekohasekai/sagernet/plugin/TrojanGoPlugin.kt`; plugin APK `moe.matsuri.exe.trojan_go`.
  - Required: Install plugin from https://matsuridayo.github.io/nb4a-plugin/ (`moe.matsuri.exe.trojan_go.apk`).
  - Limitation: Extra hop adds latency; not recommended over native Trojan/VLESS.

### 2.15 NaïveProxy (external plugin `naive-plugin`)

- **What:** Chrome net stack proxy (`naive`) with `host_resolver_rules`, padding, `insecure_concurrency`.
  - HOW: Plugin binary `naive` spawned similarly; `option.NaiveOutboundOptions` exists natively in sing-box (`type: naive`) but Android build may route via plugin for binary size.
  - FILE: `sing-box/outbound/naive/` Go pkg; `app/src/main/java/io/nekohasekai/sagernet/fmt/naive/NaiveBean.kt` if present else `plugin/NaivePlugin.kt`.
  - Plugin APK: `moe.matsuri.exe.naive`.

### 2.16 Mieru (external plugin `mieru-plugin`)

- **What:** Mieru `mieru://` with `portMap`, `multiplexing: multiplex|none`.
  - HOW: External Go binary `mieru` plugin, SIP003 exec.
  - FILE: `app/src/main/java/io/nekohasekai/sagernet/plugin/MieruPlugin.kt`; APK `moe.matsuri.exe.mieru`.
  - Go pkg (native preview): `github.com/enfein/mieru` not yet merged to sing-box main.

### 2.17 Other via plugins

- **ShadowsocksR, Snell, Juicity** — historically via `sing-box-extra` fork; now minimal.
  - HOW: `matsuridayo/sing-box-extra` provided `shadowsocksr`, `juicity` outbound types; libcore `go.mod` replaced `github.com/sagernet/sing-box` with `../sing-box` or `../sing-box-extra` during build in older tags (see issue #763). Modern master uses upstream `sagernet/sing-box` directly; extra plugins as separate plugin APKs.
  - FILE: `libcore/go.mod: replace github.com/sagernet/sing-box => ../sing-box` and `replace github.com/matsuridayo/sing-box-extra => ../sing-box-extra` (older); current `libcore/box.go:imports github.com/sagernet/sing-box/...` shows upstream.

---

## 3. Cores — sing-box, libbox, sing-box-extra

- **Primary core: sing-box (Go):**
  - Version pin: `libcore/go.mod` `require github.com/sagernet/sing-box v1.11.x` (varies by tag; 1.3.9 shipped sing-box 1.11.13 per issue #973 log). Check `libcore/go.mod` and `nb4a.properties: versionName=1.3.9` for exact.
  - HOW to see: `cat libcore/go.mod | grep sing-box`; `grep -r "sing-box" libcore/*.go` shows imports.
  - FILE: `libcore/go.mod:5`, `libcore/box.go:15-25`, `nb4a.properties:1-10`.

- **libbox JNI bridge:**
  - What: sing-box’s `experimental/libbox` wraps `box.Box` for mobile: `libbox.NewService(config, platformInterface)` + `box.Start()`/`Close()`.
  - HOW: NekoBox’s `libcore/box.go` defines `BoxInstance struct { Box *box.Box; cancel context.CancelFunc; selector *group.Selector; pauseManager }` and exports via `gomobile` as `libbox.aar` (Java `io.nekohasekai.sagernet.bg.proto.BoxInstance`).
  - Platform interface: `libcore/platform_box.go` implements `platform.Interface` — `OpenTun()`, `AutoDetectInterfaceControl(fd)`, `FindConnectionOwner()`, `PackageNameByUid()`, `UsePlatformDefaultInterfaceMonitor()` etc. Bridges Android `VpnService.protect(fd)` via `protect_server` socket.
  - FILE: `libcore/box.go:40-110` `NewSingBoxInstance`, `libcore/platform_box.go:1-80` `boxPlatformInterfaceWrapper`, `libcore/device/device.go` panic handler, `libcore/libbox.go` gomobile export.

- **matsuri/sing-box-extra fork:**
  - What: Matsuri’s patched sing-box adding `mieru`, `naive` quirks, `v2ray` extra transports, `boxapi` helpers.
  - Status: Not used as primary in latest master — replaced by upstream sing-box + separate plugin binaries. Old builds required cloning sibling directory `../sing-box-extra` due to `replace` directive (see issue #763 error `replacement directory ../../sing-box-extra does not exist`).
  - HOW to check: `grep -r "sing-box-extra" libcore/go.mod` — if present, need extra clone; if absent, uses upstream.
  - FILE: `libcore/go.mod: replace github.com/matsuridayo/sing-box-extra => ...` (historical); `libcore/box.go: imports github.com/matsuridayo/libneko/...` still uses libneko helpers.

- **Xray-core not used:**
  - HOW: No `github.com/xtls/xray-core` imports; all outbounds are sing-box native; VLESS Reality is sing-box’s Go implementation (not Xray’s). Migration from SagerNet/Matsuri (which used `v2ray-core`/`xray-core`) is the main breaking change.
  - FILE: `libcore/go.mod` has zero `xray-core`; `app/src/main/java/io/nekohasekai/sagernet/fmt/v2ray/` now outputs sing-box JSON, not `config.json` for Xray.

- **Included registries:**
  - HOW: `nekoboxAndroidInboundRegistry()`, `nekoboxAndroidOutboundRegistry()`, `nekoboxAndroidEndpointRegistry()` register only needed protocols to shrink binary (not full `distro/all`).
  - FILE: `libcore/box.go:60-70` `box.Context(ctx, nekoboxAndroidInboundRegistry(), ...)`.

---

## 4. Split Tunneling / Routing

- **Route object generation:**
  - HOW: Kotlin `ConfigBuilder.buildConfig(proxyEntity, profile)` constructs `option.RouteOptions{ Rules:[], RuleSet:[], Final:"proxy", AutoDetectInterface:true, OverrideAndroidVPN:false, DefaultDomainResolver:"local" }` then JSON-marshals. Every UI rule row → one `option.Rule{ Domain, DomainSuffix, DomainKeyword, DomainRegex, Geosite, GeoIP, IPCidr, Port, PackageName, Inbound, ClashMode }`.
  - FILE: `app/src/main/java/io/nekohasekai/sagernet/bg/proto/ConfigBuilder.kt:80-250` `buildRoute()`.

- **GeoIP / Geosite → RuleSet migration:**
  - Legacy: `route.geoip` / `route.geosite` with `geoip:cn` / `geosite:cn`. Deprecated since sing-box 1.8, removed 1.12.
  - Modern: `route.rule_set: [{type:"remote", tag:"geoip-cn", format:"binary", url:"https://.../geoip-cn.srs", update_interval:"1d"}]` + `route.rules: [{rule_set:["geoip-cn"], outbound:"direct"}]`. Binary SRS uses `sing-box rule-set compile`.
  - NekoBox UI: Settings → Route → Geo Assets downloads `geoip.db`/`geosite.db` for older tags; newer uses `geoip-cn.srs`, `geosite-category-ads.srs`.
  - FILE: `app/src/main/java/io/nekohasekai/sagernet/database/preference/RoutePreference.kt`; `app/src/main/java/io/nekohasekai/sagernet/bg/RouteConfigHelper.kt`.

- **Per-app proxy / bypass (Android):**
  - Two layers:
    1. **VpnService layer:** `VpnService.Builder.addAllowedApplication(pkg)` (proxy only these) or `addDisallowedApplication(pkg)` (bypass). Mutually exclusive; empty = global VPN. Set before `Builder.establish()`.
    2. **Route rule layer:** `route.rules: [{package_name:["com.example"], outbound:"proxy"}]` or `block`. More flexible (doesn’t require re-establish tunnel).
  - NekoBox exposes both: Settings → Per-App Proxy (VPN layer) + Route → Rules → Applications field.
  - Leak nuance: VpnService per-app is at TUN file-descriptor level; sing-box `route` sees `package_name` via `FindConnectionOwner()` (procfs or `intfBox.FindConnectionOwner()`). If app connects to local `mixed-in` (127.0.0.1:2080) directly, it bypasses TUN — fixed by rule `{"inbound":["mixed-in","socks-in"],"outbound":"block"}` discussed in issue #1153.
  - FILE: `app/src/main/java/io/nekohasekai/sagernet/bg/VpnService.kt:120-200` `createBuilder()`; `libcore/platform_box.go:80-150` `FindConnectionOwner`; `app/src/main/java/io/nekohasekai/sagernet/ui/PerAppProxyActivity.kt`.

- **ACL (Access Control List):**
  - HOW: Route → Custom Rules supports `ip_cidr`, `domain`, `geosite`, `port`, `package_name`, `inbound`, `clash_mode`, `invert`. Logical rules: `type:"logical", mode:"and|or", rules:[...]`.
  - FILE: `app/src/main/java/io/nekohasekai/sagernet/database/entity/RouteEntity.kt`; `sing-box/docs/configuration/route/rule.md`.

- **Clash Mode switch (Global / Rule / Direct):**
  - HOW: `route.clash_mode` via UI toggle; rule action `clash_mode:"direct"` selects rule set.
  - FILE: `app/src/main/java/io/nekohasekai/sagernet/ui/RouteSettingsActivity.kt`.

- **Implementation file map for routing:**
  - `app/src/main/java/io/nekohasekai/sagernet/bg/proto/ConfigBuilder.kt: buildRoute()`
  - `app/src/main/java/io/nekohasekai/sagernet/database/entity/RouteEntity.kt`
  - `app/src/main/java/io/nekohasekai/sagernet/ui/RouteActivity.kt`
  - `libcore/platform_box.go: FindConnectionOwner, PackageNameByUid`
  - `sing-box/route/router.go` (core eval loop)

---

## 5. TUN / VPN Mode

- **Android VpnService foundation:**
  - HOW: `app/src/main/java/io/nekohasekai/sagernet/bg/VpnService.kt` extends `android.net.VpnService`. Flow:
    1. `VpnService.prepare(context)` → user consent dialog if not approved.
    2. `Builder().addAddress("172.19.0.1/30").addRoute("0.0.0.0/0").addRoute("::/0").addDnsServer(...).setMtu(9000).setBlocking(true).addDisallowedApplication`... → `establish()` returns `ParcelFileDescriptor` (tun fd).
    3. fd passed to Go via `intfBox.OpenTun(jsonTunOptions, platformOptions)` → `tun.New(*options)` → `tun2socks` packet pump starts.
    4. All IP packets read from fd, parsed, injected into sing-box `tun` inbound; sing-box routes and dials outbounds; protects outbound sockets via `protect(fd)` to avoid loop.
  - FILE: `app/src/main/java/io/nekohasekai/sagernet/bg/VpnService.kt:40-220`; `app/src/main/java/io/nekohasekai/sagernet/bg/BaseService.kt`; `libcore/platform_box.go:20-60` `OpenTun`, `AutoDetectInterfaceControl`.

- **sing-box `tun` inbound:**
  - JSON generated: `{"type":"tun","tag":"tun-in","inet4_address":["172.19.0.1/30"],"mtu":9000,"stack":"mixed","sniff":true,"sniff_override_destination":true,"endpoint_independent_nat":true}`.
  - Stack options: `mixed` (auto), `gvisor` (userspace TCP/IP), `system` (Linux-like via double-NAT), `lwIP` removed. Setting Tun Implementation → `System` uses `tun2socket` trick for 1 Gbps on mid devices but needs firewall allowance; `gVisor` slower but compatible.
  - FILE: `app/src/main/java/io/nekohasekai/sagernet/bg/proto/TunConfig.kt`; `sing-box/docs/configuration/inbound/tun.md`; comment in issue #122 explains System vs gVisor history.

- **MTU:**
  - Default `9000` (high to reduce segmentation) or `1500` fallback. User editable Settings → Tun → MTU. Affects `Builder.setMtu()`.
  - FILE: `app/src/main/java/io/nekohasekai/sagernet/database/preference/TunPreference.kt: mtu = 9000`.

- **IPv4 / IPv6:**
  - HOW: `inet4_address: 172.19.0.1/30` always; `inet6_address: fdfe:dcba:9876::1/126` if IPv6 enabled (Settings → Tun → Enable IPv6). `addRoute("::/0")` only if IPv6 on. DNS `strategy: ipv4_only|prefer_ipv6` controls resolution.
  - FILE: `app/src/main/java/io/nekohasekai/sagernet/bg/proto/ConfigBuilder.kt: buildTunInbound()`.

- **Per-App VPN (VPN layer):**
  - HOW: As above, `Builder.addAllowedApplication` / `addDisallowedApplication` + optional `allowBypass=true` (apps may call `bindProcessToNetwork` to evade VPN). NekoBox sets `allowBypass=false` by default for leak prevention.
  - FILE: `VpnService.kt: addAllowedApplication loop`; `AndroidManifest.xml: BIND_VPN_SERVICE`.

- **Always-On VPN & Block connections without VPN:**
  - HOW: System Settings → VPN → NekoBox gear → Always-on VPN (OS feature, not app). When enabled, OS restarts VpnService on boot and kills non-VPN traffic if “Block connections without VPN” toggled. App supports `onRevoke()` callback.
  - NekoBox setting: Preferences → Service Mode → VPN (required for Always-On to work).

- **Leak prevention & loop protection:**
  - HOW:
    - `VpnService.protect(socketFd)` called for every outbound TCP/UDP socket before `connect()` → packet not re-enter TUN. Implemented via `protect_server` UNIX socket (`libcore/protect_server/`) + `AutoDetectInterfaceControl(fd)` in `platform_box.go:10-30`.
    - If per-app bypass incorrectly allows browsing to `127.0.0.1:2080` mixed port, rule block above prevents IP leak via local proxy.
    - `strict_route:true` in tun inbound prevents routing-loop on misconfig.
  - FILE: `libcore/platform_box.go:15` `sendFdToProtect`; `app/src/main/java/io/nekohasekai/sagernet/bg/ProtectServer.kt`; `sing-box/docs/configuration/inbound/tun/#strict_route`.

- **Battery / performance notes:**
  - System stack fastest (uses kernel TCP), ~1 Gbps single thread vs gVisor ~400 Mbps on low-end per issue #122; gVisor more stable behind firewall.
  - FILE: Comment thread #122 `Tun 实现` discussion.

---

## 6. System Proxy Mode Alternative

- **What it does:**
  - Instead of VPN TUN, creates only local proxy listeners (`mixed`, `socks`, `http` inbounds on 127.0.0.1:2080/2081). Apps must manually set proxy or Chrome reads system proxy via `VpnService.Builder.setHttpProxy()` even without TUN intercept.
  - Use case: Root not needed but only proxied apps configured manually; saves battery vs TUN.

- **Inbound ports:**
  - `mixed-in` (SOCKS5 + HTTP) default `127.0.0.1:2080` (TCP, `sniff:true`), `socks-in` optional, `http-in` optional.
  - JSON: `{"type":"mixed","tag":"mixed-in","listen":"127.0.0.1","listen_port":2080,"sniff":true}` + `{"type":"http","tag":"http-in","listen":"127.0.0.1","listen_port":2081}`.
  - FILE: `app/src/main/java/io/nekohasekai/sagernet/bg/proto/ConfigBuilder.kt: buildInbounds()`; `libcore/box.go: InboundRegistry`.

- **Toggle:**
  - Settings → Service Mode → “Proxy Only” vs “VPN”. Proxy Only never calls `Builder.establish()`, only starts `Box`.
  - FILE: `app/src/main/java/io/nekohasekai/sagernet/ui/SettingsActivity.kt: serviceMode`.

- **Append HTTP Proxy to VPN:**
  - Option `appendHttpProxy` sets `Builder.setHttpProxy(ProxyInfo.buildDirectProxy("127.0.0.1", 2080))` so WebView/Chrome auto-use proxy even in VPN mode without per-app config.
  - FILE: `app/src/main/java/io/nekohasekai/sagernet/bg/VpnService.kt: setHttpProxy`; issue #122 comment clarifies.

- **When to use which:**
  - VPN/TUN: global, zero app config, captures UDP & ICMP, supports per-app rules.
  - System Proxy: lighter, but UDP not proxied, apps that ignore system proxy bypass.

---

## 7. Subscription Formats

- **All subscriptions → outbounds only (routing ignored):**
  - HOW: `RawUpdater.doUpdate()` downloads URL, detects format, calls `parseRaw()` parsers, generates list `ProxyEntity`, saves to Room `proxy` table, ignores any `route`/`dns` JSON that may be bundled in Clash yaml.
  - FILE: `app/src/main/java/io/nekohasekai/sagernet/fmt/SubscriptionUpdater.kt`; `app/src/main/java/io/nekohasekai/sagernet/fmt/ProxyEntity.kt`.

- **ClashMeta / Clash YAML:**
  - HOW: `com.github.esotericsoftware.yaml` (SnakeYAML) parses `proxies: [{name,type,server,port,cipher,sni,...}]` + `proxy-groups` ignored. Supports `ss`, `ssr`, `vmess`, `vless`, `trojan`, `hysteria2`, `tuic`, `wireguard` ClashMeta extensions. Single proxy yaml → `ClashFmt.parseClash()`.
  - FILE: `app/src/main/java/io/nekohasekai/sagernet/fmt/clash/ClashFmt.kt: parseClashMeta`.

- **sing-box outbound JSON:**
  - HOW: Direct `{"outbounds":[{"type":"vless","tag":"...","server":...}]}` pasted or via subscription URL returning JSON. Parser tries `option.Outbound.UnmarshalJSON`; if success, creates `SingBoxBean` holding raw JSON and validates with sing-box.
  - FILE: `app/src/main/java/io/nekohasekai/sagernet/fmt/singbox/SingBoxFmt.kt`.

- **Shadowrocket / v2rayN style:**
  - HOW: Newline-separated URIs: `ss://`, `ssr://`, `vmess://`, `vless://`, `trojan://`, `hysteria2://`/`hy2://`, `tuic://`, `socks://`, `wireguard://`. Base64 outer list is v2rayN SSD format: `base64(url1\nurl2)`.
  - Parsers: `SSFmt`, `VMessFmt`, `VLESSFmt`, `TrojanFmt`, `TuicFmt`, `HysteriaFmt`, `WireGuardFmt` each implement `parseX(link)`.
  - FILE: `app/src/main/java/io/nekohasekai/sagernet/fmt/v2ray/V2RayFmt.kt`; `app/src/main/java/io/nekohasekai/sagernet/fmt/shadowsocks/`.

- **SIP008 (Shadowsocks JSON Online Config):**
  - HOW: JSON array `[{"server":"host","server_port":8388,"password":"...","method":"aes-256-gcm","remarks":"name"}]` hosted at URL. Standard for SS online subscription.
  - Parser: `SIP008Fmt.parseSIP008(jsonStr)` → `ShadowsocksBean` per entry.
  - FILE: `app/src/main/java/io/nekohasekai/sagernet/fmt/shadowsocks/SIP008Fmt.kt`.

- **Additional:**
  - **Base64 single file:** v2rayN’s `base64(links\n)` auto-detected via `tryBase64Decode()`.
  - **YAML base64:** some providers base64-encode entire Clash YAML — NekoBox tries UTF-8 then base64 fallback.
  - **Custom dial / ShadowTLS / AnyTLS links:** `shadowtls://`, `anytls://`, `mieru://`, `naive+https://` via respective fmt.
  - FILE: `app/src/main/java/io/nekohasekai/sagernet/fmt/FmtRegistry.kt` dispatch map.

---

## 8. DPI Bypass / Obfuscation

- **Reality (TLS camouflage, no cert needed):**
  - HOW: Outbound `tls.reality.enabled:true, public_key, short_id, server_name, handshake.server+port` + inbound equivalent on server with `private_key`. NekoBox exposes Reality fields under each TLS-enabled protocol (VLESS/Trojan/VMess). Keys generated outside: `sing-box generate reality-keypair` → private stays on server, public in client JSON.
  - Go pkg: `github.com/sagernet/sing-box/common/reality` + `option.OutboundRealityOptions`.
  - Bean fields: `realityPubKey, realityShortId, realityServerName`.
  - FILE: `app/src/main/java/io/nekohasekai/sagernet/fmt/v2ray/StandardV2RayBean.kt: reality fields`; `sing-box/docs/configuration/shared/tls/#reality`.

- **Vision (`flow: xtls-rprx-vision`):**
  - HOW: `VLESS outbound flow="xtls-rprx-vision"` + TLS enabled; provides TLS-in-TLS hardening. Radio button in VLESS edit screen.
  - FILE: `StandardV2RayBean.kt: flow`; `sing-box/docs/configuration/outbound/vless/#flow`.

- **uTLS (ClientHello fingerprint spoofing):**
  - HOW: `tls.utls.enabled:true, fingerprint:"chrome|firefox|edge|safari|ios|android|random|randomized|qq|360"` (chrome default). Mimics browser TLS fingerprint to evade JA3 detection. Implemented via `github.com/refraction-networking/utls` wrapped by sing-box.
  - FILE: `app/src/main/java/io/nekohasekai/sagernet/fmt/tls/TLSSettings.kt`; `sing-box/docs/configuration/shared/tls/#utls`.

- **Fragmented TLS / record_fragment:**
  - HOW: `tls.fragment:true` + `fragment_fallback_delay: 10ms` splits ClientHello; `record_fragment:true` fragments TLS records. Helps against SNI blocking. Toyed as `tls.fragment` boolean.
  - Go pkg: `github.com/sagernet/sing-box/common/tls` with `fragment` dialer.
  - FILE: `sing-box/docs/configuration/shared/tls/#fragment`.

- **ECH (Encrypted Client Hello):**
  - HOW: `tls.ech.enabled:true, config|config_path, pq_signature_schemes_enabled`. Encrypts SNI. NekoBox UI optional under TLS → ECH.
  - FILE: `sing-box/docs/configuration/shared/tls/#ech`.

- **ShadowTLS (TLS masquerade):**
  - HOW: As above outbound `shadowtls` wraps Shadowsocks inside fake TLS to whitelisted domain (e.g., `gateway.icloud.com`). `version:3`, `password`, `tls.server_name`.
  - FILE: `sing-box/protocol/shadowtls/` plus `fmt/shadowtls/`.

- **WireGuard obfuscation (reserved bytes / WARP):**
  - HOW: `WireGuardBean.reserved: [3 bytes]` randomizes handshake to look like WARP; plus `private_key` generated per device; optional `obfs` via `sing-box` `wireguard` `reserved` + `workers`.
  - FILE: `fmt/wireguard/WireGuardBean.kt: reserved`.

- **Hysteria obfs / Salamander:**
  - HOW: `hysteria2.obfs:{type:"salamander", password:"..."}` XORs QUIC packet to hide fingerprint.
  - FILE: `HysteriaBean.kt`; `sing-box/docs/configuration/outbound/hysteria2/#obfs`.

- **What’s NOT in NekoBox:**
  - No built-in generic packet fragmenter for arbitrary TCP (only TLS fragment); no `ws` early-data obfuscation toggle separate from transport; no `Reality` without TLS (hard requirement).

---

## 9. DNS

> NekoBox generates `dns` block for sing-box; sing-box handles resolution before routing (`route` may sniff → `action:hijack-dns`).

- **DNS block structure:**
  - JSON: `{"dns":{"servers":[{"tag":"remote","address":"https://8.8.8.8/dns-query","detour":"proxy","strategy":"ipv4_only"}, {"tag":"direct","address":"local","detour":"direct"}, {"tag":"fakeip","type":"fakeip","inet4_range":"198.18.0.0/15"}], "rules":[{"geosite":["cn"],"server":"direct"}, {"query_type":["A","AAAA"],"server":"remote"}], "final":"remote", "strategy":"ipv4_only", "independent_cache":true, "reverse_mapping":false}}`.
  - FILE: `app/src/main/java/io/nekohasekai/sagernet/bg/proto/ConfigBuilder.kt: buildDNS()`; `sing-box/docs/configuration/dns/`.

- **FakeIP:**
  - HOW: `dns.servers[]: {type:"fakeip", tag:"fakeip", inet4_range:"198.18.0.0/15", inet6_range:"fc00::/18"}` + rule `{"query_type":["A","AAAA"], "server":"fakeip"}` + `dns.fakeip.enabled:true` legacy (removed 1.14). Tun inbound `sniff` + `route.rules: {action:"hijack-dns"}` intercepts DNS port 53 and returns FakeIP; outbound connects with original domain (not IP) for proper routing (geosite matches).
  - Settings: DNS → Enable FakeIP (toggle). Range editable.
  - FILE: `app/src/main/java/io/nekohasekai/sagernet/database/preference/DNSPreference.kt: fakeIp`; `sing-box/docs/configuration/dns/fakeip.md`; `sing-box/docs/configuration/dns/server/fakeip`.

- **Remote DNS (proxied):**
  - Providers: `https://8.8.8.8/dns-query`, `tls://8.8.8.8`, `quic://dns.adguard.com`, `https://1.1.1.1/dns-query`, custom DoH/DoT/DoQ. `detour:"proxy"` forces query via proxy outbound (avoid poisoning). Configurable address + resolver.
  - FILE: `app/src/main/java/io/nekohasekai/sagernet/ui/DNSSettingsActivity.kt`.

- **Domestic / Direct DNS:**
  - Providers: `local` (system resolver), `223.5.5.5`, `114.114.114.114`, `tls://dot.pub` etc. `detour:"direct"` so answer is real local IP for `direct` routed domains.
  - Strategy: `direct` DNS used for `geosite:cn` / `geoip:cn` routed rules; `remote` DNS for proxied.

- **DNS routing rules:**
  - HOW: Same matcher as route rules but under `dns.rules`: fields `domain`, `domain_suffix`, `geosite`, `query_type`, `outbound` (not server). Example: `{"geosite":["cn"],"server":"direct"}` and `{"geosite":["geolocation-!cn"],"server":"remote"}`.
  - FILE: `sing-box/docs/configuration/dns/rule/`; `ConfigBuilder.kt: buildDNSRules()`.

- **Other DNS options:**
  - `strategy` override (`ipv4_only`, `prefer_ipv4`, `prefer_ipv6`, `ipv6_only`), `independent_cache:true` (per-server cache), `reverse_mapping:true` (IP → domain for sniff), `client_subnet`, `disable_cache`, `optimistic`.
  - FILE: `sing-box/docs/configuration/dns/index.md`.

- **hijack-dns rule:**
  - HOW: `route.rules: [{"protocol":["dns"],"action":"hijack-dns"}]` intercepts port-53 packets from TUN and redirects to sing-box DNS server instead of network DNS (leak prevention).
  - FILE: `ConfigBuilder.kt: buildRouteRules() hijackDns`.

---

## 10. Other Features

- **Groups (proxy groups):**
  - Types: Manual selector (`selector`), Auto URLTest (`urltest`), LoadBalance not exposed. `Selector` outbound: `{"type":"selector","tag":"proxy","outbounds":["node1","node2"], "default":"node1", "interrupt_exist_connections":false}`; URLTest: `{"type":"urltest","tag":"auto","outbounds":["a","b"],"url":"https://www.gstatic.com/generate_204","interval":"10m","tolerance":50}`.
  - HOW: UI Groups → Create Group → type select URLTest interval; `ConfigBuilder.buildGroups()` writes selector/urltest outbounds and wires `route.final = groupTag`.
  - FILE: `app/src/main/java/io/nekohasekai/sagernet/group/GroupManager.kt`; `app/src/main/java/io/nekohasekai/sagernet/database/entity/GroupEntity.kt`; `sing-box/protocol/group/selector.go`, `urltest.go`; `libcore/box.go:54` `b.selector = proxy.(*group.Selector)`.
  - Switch node: Notification tile + in-app spinner calls `BoxInstance.Selector.Select(outboundTag)`.

- **Speed test (latency):**
  - HOW: `github.com/matsuridayo/libneko/speedtest` Go package opens `http://www.gstatic.com/generate_204` or `https://www.google.com/generate_204` via each outbound’s `Dialer` (or `Group.Selector` urltest). Measures RTT ms. Results cached per entity. Bulk test via `WorkManager` coroutine.
  - FILE: `libcore/box.go: imports matsuridayo/libneko/speedtest`; `app/src/main/java/io/nekohasekai/sagernet/bg/SpeedTestService.kt`; `app/src/main/java/io/nekohasekai/sagernet/utils/SpeedtestUtil.kt`.

- **Traffic stats:**
  - HOW: sing-box `experimental.clash_api` + `experimental.v2ray_api` stats: per-outbound `uplink`/`downlink` bytes via `box.Router().Connections()` or `adapter.Outbound.Interface` `CounterConn`. UI polls every 1s via AIDL `getStats()`. Notification shows `▲ 1.2 MB/s ▼ 4.5 MB/s`.
  - Bypass: `V2Ray API` enabled only if `Settings → Enable statistics`.
  - FILE: `libcore/box.go: adapter.Outbound`; `app/src/main/java/io/nekohasekai/sagernet/bg/BaseService.kt: statsPoller`; `app/src/main/res/layout/notification_service.xml`.

- **Backup / import:**
  - HOW: `app/src/main/java/io/nekohasekai/sagernet/database/DataStore.kt` Room DB export to `matbackup` (zip of `sagernet.db` + `preferences.json`) or `json` (plain). Restore via SAF picker. Includes profiles, groups, route entities, preferences.
  - FILE: `app/src/main/java/io/nekohasekai/sagernet/ui/BackupActivity.kt`; `app/src/main/java/io/nekohasekai/sagernet/database/BackupHelper.kt`.

- **Plugin system:**
  - HOW: External plugin APK registers `Service` with intent `io.nekohasekai.sagernet.plugin.ACTION` and metadata `io.nekohasekai.sagernet.plugin.NAME`. Main app discovers via `PackageManager.queryIntentServices`, shows in About → Plugins. Executes binary via `PluginManager.startPlugin(pluginId, port)` and connects via local SOCKS `127.0.0.1:<port>`.
  - Compatible prefix: `moe.matsuri.exe.*` or historical `io.nekohasekai.sagernet.plugin.*` (both scanned).
  - Download: https://matsuridayo.github.io/nb4a-plugin/ lists `trojan-go-plugin`, `naive-plugin`, `mieru-plugin`.
  - FILE: `app/src/main/java/io/nekohasekai/sagernet/plugin/PluginManager.kt`; `app/src/main/java/io/nekohasekai/sagernet/plugin/PluginContract.kt`; docs `matsuridayo.github.io/nb4a-plugin/`.

- **Notification:**
  - HOW: Foreground service notification with `NotificationCompat.Builder` (channel `bg_service`). Shows connected profile, traffic speed, uptime, buttons Disconnect / Toggle Group. `NotificationManagerCompat.notify(SERVICE_NOTIFICATION_ID)`.
  - FILE: `app/src/main/java/io/nekohasekai/sagernet/bg/BaseService.kt: showNotification()`; `app/src/main/java/io/nekohasekai/sagernet/utils/NotificationUtil.kt`.

- **Quick Tile (QS TileService):**
  - HOW: `android.service.quicksettings.TileService` subclass `QuickToggleTileService.kt`. Tap toggles VPN on/off via `SagerNet.startService()` / `stopService()`. Long-press opens app. Requires `BIND_QUICK_SETTINGS_TILE`.
  - FILE: `app/src/main/java/io/nekohasekai/sagernet/widget/QuickToggleTileService.kt`; `app/src/main/AndroidManifest.xml: TileService declaration`.

- **Other UX:**
  - QR scan share: `ZXing-lite` `com.github.jenly1314:zxing-lite:2.1.1` — Camera → parse link → add entity.
  - Web dashboard: `Yacd-meta` built-in Clash API web UI at `http://127.0.0.1:9090/ui` (username `yacd-meta`).
  - Widget, per-profile TLS allowInsecure per-bean, multiplex toggle, UDP over TCP, domain strategy.
  - FILE: `app/src/main/java/io/nekohasekai/sagernet/ui/ProfileActivity.kt`; `buildScript/yacd.gradle.kts`.

---

## 11. Platforms & Requirements

- **Minimum: Android 5.0 API 21+**
  - HOW: `android.minSdk = 21` in `app/build.gradle.kts: android { defaultConfig { minSdk = 21 } }`. Targets ~Android 13+ compile SDK.
  - FILE: `app/build.gradle.kts: android.defaultConfig.minSdk = 21`; `README.md:7` badge `API-21+`; `buildSrc/src/main/kotlin/Config.kt: minSdk`.

- **Architectures:**
  - Supported ABIs: `arm64-v8a`, `armeabi-v7a`, `x86_64` (and `x86` via `arm` fallback in some tags). `libbox.aar` contains `jni/arm64-v8a/libbox.so`, `jni/armeabi-v7a/libbox.so`, etc. `x86_64` needed for emulator.
  - HOW: `gomobile bind -target android/arm,android/arm64,android/amd64` (or `android/amd64` for x86_64). NDK 25.1.x.
  - FILE: `libcore/build.sh: gomobile bind -target android`; `libcore/Makefile: GOOS=android`; `buildScript/gomobile.gradle.kts`.
  - APK split: `app-arm64-v8a-release.apk`, `app-universal-release.apk`.

- **Android TV support:**
  - HOW: No Leanback launcher restriction; `VpnService` works on TV; dpad-navigable UI (RecyclerView focus). Tested on `shield` style devices; `uses-feature: android.software.leanback` not required but TV banner present.
  - FILE: `app/src/main/AndroidManifest.xml: <intent-filter android:leanback ...>` if present; community confirms TV works in Issues.

- **Permissions:**
  - Required: `INTERNET`, `ACCESS_NETWORK_STATE`, `QUERY_ALL_PACKAGES` (per-app), `FOREGROUND_SERVICE`, `POST_NOTIFICATIONS` (Android 13+), `RECEIVE_BOOT_COMPLETED` (auto-start).
  - FILE: `app/src/main/AndroidManifest.xml:1-40`.

- **Not supported:**
  - iOS, Windows, macOS — use `NekoRay` / `NekoBox for PC` or `sing-box` CLI directly. ChromeOS via Android container works but VpnService nested may fail.

---

## 12. Repo Stats, Build Steps & File Map

### 12.1 Repo stats (Aug 2026)

- **Stars:** 22.5k · **Watchers:** 135 · **Forks:** 1.8k · **Issues:** 163 open · **PRs:** 11 · **Commits:** 392 on `main` · **Releases:** ~15 (latest 1.3.9 / 1.4.1 beta tag) · **License:** GPL-3.0 · **Languages:** Kotlin, Go, Java, Shell, AIDL.
- **Latest release assets:** `NekoBoxForAndroid-1.3.9-arm64-v8a.apk`, `-armeabi-v7a.apk`, `-x86_64.apk`, `-universal.apk` (+ `*.apk.sig`).
- FILE: GitHub API `https://api.github.com/repos/MatsuriDayo/NekoBoxForAndroid`.

### 12.2 File map (absolute paths inside repo)

```
NekoBoxForAndroid/
├── README.md                          # protocol list + download warning
├── LICENSE                            # GPL-3.0
├── AUTHORS                            # SagerNet attribution
├── nb4a.properties                    # versionName/versionCode (1.3.9)
├── build.gradle.kts                   # root gradle
├── settings.gradle.kts
├── repositories.gradle.kts
├── gradle.properties                  # org.gradle.jvmargs
├── app/
│   ├── build.gradle.kts               # minSdk 21, Room, OkHttp, SnakeYAML
│   ├── src/main/
│   │   ├── AndroidManifest.xml        # VpnService, TileService, permissions
│   │   ├── java/io/nekohasekai/sagernet/
│   │   │   ├── bg/
│   │   │   │   ├── BaseService.kt     # foreground service, stats poll
│   │   │   │   ├── VpnService.kt     # Builder.establish, allowBypass, httpProxy
│   │   │   │   ├── ProtectServer.kt  # UNIX socket protect_server bridge
│   │   │   │   └── proto/
│   │   │   │       ├── BoxInstance.kt # proxy to libcore.BoxInstance
│   │   │   │       └── ConfigBuilder.kt # Beans → sing-box JSON (route/dns/inbound/outbound)
│   │   │   ├── database/
│   │   │   │   ├── entity/ProxyEntity.kt # Room entity, Kryo bean blob
│   │   │   │   └── DataStore.kt       # Room db, backup/restore
│   │   │   ├── fmt/
│   │   │   │   ├── AbstractBean.kt    # base: serverAddr, port, name
│   │   │   │   ├── socks/             # SOCKS 4/4a/5
│   │   │   │   ├── http/              # HTTP(S)
│   │   │   │   ├── ssh/               # SSH
│   │   │   │   ├── shadowsocks/       # SS + SIP008 + Clash
│   │   │   │   ├── v2ray/             # StandardV2RayBean (vmess/trojan/vless)
│   │   │   │   ├── wireguard/         # WireGuard
│   │   │   │   ├── tuic/              # TUIC
│   │   │   │   ├── hysteria/          # Hysteria1/2
│   │   │   │   ├── shadowtls/         # ShadowTLS
│   │   │   │   ├── anytls/            # AnyTLS
│   │   │   │   └── singbox/           # raw sing-box outbound
│   │   │   ├── plugin/
│   │   │   │   └── PluginManager.kt   # external plugin exec (moe.matsuri.exe.*)
│   │   │   ├── group/GroupManager.kt  # selector/urltest
│   │   │   └── ui/                   # Activities/Fragments (Route, DNS, Profile)
│   │   └── aidl/.../ISagerNetService.aidl
├── libcore/
│   ├── go.mod                         # require sagernet/sing-box v1.11.x
│   ├── go.sum
│   ├── box.go                         # NewSingBoxInstance, Box selector
│   ├── platform_box.go                # OpenTun, FindConnectionOwner, protect fd
│   ├── libbox.go                      # gomobile export
│   ├── device/device.go
│   └── build.sh / Makefile            # gomobile bind
├── buildScript/
│   ├── gomobile.gradle.kts
│   └── yacd.gradle.kts                # Yacd-meta dashboard copy
├── buildSrc/src/main/kotlin/Config.kt # SDK versions
└── .github/workflows/build.yml        # CI builds aar then apk
```

### 12.3 Build steps (verified from `README` + `build.yml` + issues #162, #763, #973)

1. **Prereqs:**
   - `JDK 17` for Gradle (`app`), `JDK 8` historically for `libcore` via `gomobile` (now JDK 17 both — see issue #973 note `jdk8 required to build libcore, jdk17 for gradlew`).
   - `Android SDK` `compileSdk 34`, `NDK 25.1.x`, `Go 1.21+`, `gomobile` (`go install golang.org/x/mobile/cmd/gomobile@latest && gomobile init`).
   - `git`, `bash` (WSL on Windows).

2. **Clone + sibling sing-box (if needed by go.mod replace):**
   ```bash
   git clone https://github.com/MatsuriDayo/NekoBoxForAndroid
   cd NekoBoxForAndroid
   # only if libcore/go.mod has replace => ../sing-box or ../sing-box-extra
   git clone https://github.com/SagerNet/sing-box ../sing-box
   # git clone https://github.com/MatsuriDayo/sing-box-extra ../sing-box-extra
   git clone https://github.com/MatsuriDayo/libneko ../libneko  # if replace points there
   ```

3. **Build libcore AAR:**
   ```bash
   cd libcore
   go mod tidy
   # either gomobile bind or via Gradle task:
   ./build.sh
   # or: gomobile bind -v -target android/arm,android/arm64,android/amd64 -javapkg io.nekohasekai.libcore -o libbox.aar -trimpath -ldflags "-s -w"
   # Result: libcore/libbox.aar with jni/{arm64-v8a,armeabi-v7a,x86_64}/libgojni.so + libbox.aar
   ```

4. **Build APK (without rebuilding libcore if aar cached):**
   ```bash
   cd ..
   ./gradlew :app:assembleOssRelease
   # flavors: ossRelease, playRelease (not OSS), fdroid
   # ABIs: assembleOssRelease generates universal; use app:assembleOssRelease -Pabi=arm64-v8a for split (see build.gradle split.abi)
   ls app/build/outputs/apk/oss/release/*.apk
   ```

5. **CI (GitHub Actions):**
   - `.github/workflows/build.yml` does `actions/setup-go@v4`, `actions/setup-java@v3 (17)`, `android-actions/setup-android`, `gomobile init`, then `gradle assemble`. Artifacts uploaded as `app-*.apk`.

6. **Common pitfalls (from issues):**
   - `module sagernet/sing-box@latest found but does not contain package sing-box/nekoutils` → need sibling `../sing-box` clone matching `replace` version.
   - `go.mod: replacement directory ../../sing-box-extra does not exist` → clone `sing-box-extra` sibling.
   - `JDK mismatch` → use JDK 8 for `gomobile bind`, JDK 17 for `./gradlew` on older tags.
   - `NDK not found` → set `ANDROID_NDK` env or install via `sdkmanager --install "ndk;25.1.8937393"`.

7. **Verify build:**
   ```bash
   ./gradlew :app:lint
   ./gradlew :app:connectedAndroidTest  # needs emulator
   ```

### 12.4 Key implementation cross-reference (protocol → Go pkg → Kotlin bean → builder line)

| Protocol | sing-box `outbound.type` | Go pkg | Kotlin Bean | Builder method | Plugin needed |
|---|---|---|---|---|---|
| SOCKS 4/4a/5 | `socks` | `outbound/socks` | `fmt/socks/SOCKSBean.kt` | `addOutbound_SOCKS` | no |
| HTTP | `http` | `outbound/http` | `fmt/http/HttpBean.kt` | `addOutbound_HTTP` | no |
| SSH | `ssh` | `outbound/ssh` | `fmt/ssh/SSHBean.kt` | `addOutbound_SSH` | no |
| Shadowsocks | `shadowsocks` | `outbound/shadowsocks` | `fmt/shadowsocks/ShadowsocksBean.kt` | `addOutbound_SS` | no |
| VMess | `vmess` | `outbound/vmess` | `fmt/v2ray/StandardV2RayBean.kt:type=vmess` | `addOutbound_VMess` | no |
| Trojan | `trojan` | `outbound/trojan` | `StandardV2RayBean:type=trojan` | `addOutbound_Trojan` | no |
| VLESS | `vless` | `outbound/vless` | `StandardV2RayBean:type=vless` | `addOutbound_VLESS` | no |
| AnyTLS | `anytls` | `outbound/anytls` | `fmt/anytls/AnyTLSBean.kt` | `addOutbound_AnyTLS` | no |
| ShadowTLS | `shadowtls` | `outbound/shadowtls` | `fmt/shadowtls/ShadowTLSBean.kt` | `addOutbound_ShadowTLS` | no |
| TUIC | `tuic` | `outbound/tuic` (`sing-quic/tuic`) | `fmt/tuic/TuicBean.kt` | `addOutbound_TUIC` | no |
| Hysteria1 | `hysteria` | `outbound/hysteria` | `fmt/hysteria/HysteriaBean.kt:v1` | `addOutbound_Hysteria` | no |
| Hysteria2 | `hysteria2` | `outbound/hysteria2` | `HysteriaBean:v2` | `addOutbound_Hysteria2` | no |
| WireGuard | `wireguard` | `outbound/wireguard` | `fmt/wireguard/WireGuardBean.kt` | `addOutbound_WireGuard` | no |
| Trojan-Go | exec plugin | `N/A` (ext) | `plugin/TrojanGoPlugin.kt` | `addOutbound_Plugin` | `trojan-go-plugin` |
| Naïve | `naive` | `outbound/naive` | `fmt/naive/NaiveBean.kt` | `addOutbound_Naive` | `naive-plugin` or builtin |
| Mieru | exec plugin | `N/A` (ext) | `plugin/MieruPlugin.kt` | `addOutbound_Plugin` | `mieru-plugin` |

---

## 13. References

- **GitHub README:** https://github.com/MatsuriDayo/NekoBoxForAndroid — protocol list, warning about Play store fork, credits.
- **Docs site:** https://matsuridayo.github.io — NekoBoxForAndroid plugin page https://matsuridayo.github.io/nb4a-plugin/.
- **Core:** https://github.com/SagerNet/sing-box — `docs/configuration/outbound/`, `docs/configuration/dns/`, `docs/configuration/route/`, `docs/configuration/inbound/tun/`, `docs/configuration/shared/tls/`.
- **sing-box docs (outbound):** https://sing-box.sagernet.org/configuration/outbound/ — full type table (direct, socks, http, shadowsocks, vmess, trojan, wireguard, hysteria, vless, shadowtls, tuic, hysteria2, anytls, tor, ssh, dns, selector, urltest).
- **sing-box docs (DNS/TUN/Route):** https://sing-box.sagernet.org/configuration/dns/ , `/dns/server/fakeip`, `/route/`, `/route/rule/`, `/inbound/tun/`.
- **libcore bridging:** `libcore/box.go` (NewSingBoxInstance), `libcore/platform_box.go` (OpenTun, AutoDetectInterfaceControl, FindConnectionOwner) — viewed via GitHub web at `main` branch.
- **Issues cited:** #122 Tun implementation System vs gVisor, #162 build guide, #763 libcore aar replacement directory, #973 sing-box 1.11.13 build failure, #1153 per-app split tunneling leak and `inbound:["mixed-in","socks-in"]` block fix.
- **Wiki / DeepWiki:** `starifly/NekoBoxForAndroid` DeepWiki 5-layer arch (VpnService → TUN → ConfigBuilder → libbox → sing-box).
- **History:** `MatsuriDayo/Matsuri` (archived, NOASSERTION, SagerNet successor), `SagerNet/SagerNet` lineage, `AUTHORS` file attribution to `nekohasekai <contact-sagernet@sekai.icu>`.
- **Comparison:** `chonglangbiji.com` 2026 Matsuri/SagerNet history timeline (SagerNet → Matsuri → NekoBox → Husi).
- **Plugins:** https://matsuridayo.github.io/nb4a-plugin/ — `moe.matsuri.exe.*` naming, `io.nekohasekai.sagernet.plugin.*` historical.

---

*Generated 2026-08-30 for VPN Research 03 — NekoBox for Android. All file paths are as seen on GitHub `main` at 5768494d tag-equivalent Aug 2026; Go package paths as per `sing-box@1.11.x` option structs. Verify with `cat libcore/go.mod` + `ls app/src/main/java/io/nekohasekai/sagernet/fmt/`.*
