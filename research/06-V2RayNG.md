# V2RayNG (2dust/v2rayNG) — Extreme Detail Research

> **Repo:** `2dust/v2rayNG` · **License:** GPL-3.0-only · **Language:** Kotlin (~92%) + Java/Go/C · **UI:** Jetpack Compose (2.3.x, migrated from Views) + Material3 / Monet dynamic color · **Cores:** `Xray-core` via `AndroidLibXrayLite` (gomobile AAR) + `hev-socks5-tunnel` (tun2socks) · **Platform:** Android 5.0+ (API 21+, targetSdk 34→37) + Android TV / WSA emulators (appops)
> **Homepage:** https://github.com/2dust/v2rayNG · **Wiki:** https://github.com/2dust/v2rayNG/wiki · **Telegram:** https://t.me/v2rayN / https://t.me/github_2dust · **Stars (Aug 2026):** ~61.8k★ / ~8.0k forks / 710 watchers / 1,699 commits · **Latest:** 2.3.6 (2026-08-29 pre-release), 2.3.5/2.3.4 (Aug), 2.2.6 (2026-07-05 latest stable, Xray v26.6.27), 2.3.1-2.3.3 (Compose preview)
> **Status:** Actively maintained by `2dust` + `fuilloi` (Compose) + `eliotcougar`; 2.3.x is Compose rewrite, 2.2.6 is stable channel; Xray-core v26.7.28 bundled in 2.3.6.

---

## Table of Contents

1. [Overview](#1-overview)
2. [Supported Protocols — Deep Dive](#2-supported-protocols--deep-dive)
3. [Transports / Encryption — Deep Dive](#3-transports--encryption--deep-dive)
4. [Cores Matrix — Xray via AndroidLibXrayLite vs sing-box vs Others](#4-cores-matrix--xray-via-androidlibxraylite-vs-sing-box-vs-others)
5. [Subscription Formats](#5-subscription-formats)
6. [Routing / Split Tunneling](#6-routing--split-tunneling)
7. [TUN / VPN Mode](#7-tun--vpn-mode)
8. [Local Socks / HTTP Inbounds & Per-Profile Ports](#8-local-socks--http-inbounds--per-profile-ports)
9. [DPI Bypass — Reality / XTLS / Fragment / uTLS / XHTTP](#9-dpi-bypass--reality--xtls--fragment--utls--xhttp)
10. [DNS — Xray dns, Hijack, FakeDNS, DoH, VPN DNS](#10-dns--xray-dns-hijack-fakedns-doh-vpn-dns)
11. [Other Features — Speed Test, Backup/Restore, Widgets, Tiles](#11-other-features--speed-test-backuprestore-widgets-tiles)
12. [Platforms & Requirements](#12-platforms--requirements)
13. [Repo Stats, Build Instructions & File Map](#13-repo-stats-build-instructions--file-map)
14. [References](#14-references)

---

## 1. Overview

- **What it is:**
  - Android GUI proxy manager that wraps `Xray-core` as a local VPN/proxy service, manages unlimited profiles, subscriptions, routing, DNS, TUN/VpnService, latency tests and QR share from one app + Quick Tile.
    - HOW: Kotlin app `V2rayNG/app` writes JSON via `V2rayConfigUtil.getV2rayConfig()` → MMKV (`MmkvManager`) → `CoreServiceManager.startCoreLoop()` → `LibXray` (Go `AndroidLibXrayLite` AAR) → SOCKS/HTTP inbounds (e.g. `127.0.0.1:10808`) → `CoreVpnService` (VpnService.Builder) + `hev-socks5-tunnel` tun2socks forwards TUN fd to that SOCKS. UI is thin Compose/Material3 shell consuming MMKV.
    - FILE: `README.md:1-10` "A V2Ray client for Android, support Xray core and v2fly core"; `V2rayNG/app/src/main/java/com/v2ray/ang/service/CoreVpnService.kt:35` `class CoreVpnService : VpnService(), ServiceControl`; `V2rayNG/app/src/main/java/com/v2ray/ang/handler/MmkvManager.kt:339-447` MMKV store; `V2rayNG/app/src/main/java/com/v2ray/ang/util/V2rayConfigUtil.kt:20-80` config gen; `AndroidLibXrayLite/libv2ray_main.go:1-40` Go entry `StartLoop`/`StopLoop`.

- **License GPL-3.0-only:**
  - HOW: `LICENSE` verbatim GPL-3.0 (same text as v2rayN); GitHub sidebar `GPL-3.0 license`; forks inherit copyleft. Re-distributing modified APK without source violates license — same notice as NekoBox/Nekoray. Commercial forks must publish source.
  - FILE: `LICENSE:1-674`; README footer `GPL-3.0 license`; `fastlane/metadata/android/en-US/` store listing inherits GPL.

- **Kotlin/Java, Compose migration:**
  - HOW: 2.2.x = Android Views + Kotlin 1.9.x + MMKV + OkHttp + Gson + RecyclerView. 2.3.1-2.3.6 = **Jetpack Compose** rewrite by `fuilloi` (#5866) — all activities (`MainActivity`, `SubEditActivity`, `SettingsActivity`) migrated to `@Composable` + `ViewModel` + `collectAsState`; Material3 + Monet dynamic color (#6067) + Compose Navigation. Gradle Kotlin DSL, Kotlin 2.4.0 badge, `targetSdk 37` (Android 17) since 2.2.3, `compileSdk 35+`.
  - FILE: `README.md` shields `Kotlin Version 2.4.0`; `releases/tag/2.3.6` "迁移到 Jetpack Compose UI , 感谢 @fuilloi #5866" + "支持莫奈动态色彩 #6067"; `V2rayNG/app/build.gradle.kts:1-40` `kotlinOptions` + `composeOptions`; `V2rayNG/app/src/main/java/com/v2ray/ang/ui/MainActivity.kt:1-80` Compose entry.

- **Android 5.0+ (API 21 → 24+), phone-first:**
  - HOW: `minSdk` historically 21 (Android 5.0 Lollipop) per README API badge `API 25+` / `API 21` depending on branch; `AndroidLibXrayLite` gomobile bind uses `-androidapi 24` (Nougat 7.0) as floor for Go 1.22+ `go:linkname` checks. Runs on phones, tablets, Android TV (side-loaded), WSA/WayDroid emulators (`appops set com.v2ray.ang ACTIVATE_VPN allow`). No iOS/Windows — desktop sibling is `2dust/v2rayN` (C# WPF/Avalonia).
  - FILE: `README.md:Development guide` "v2rayNG can run on Android Emulators. For WSA, VPN permission need to be granted via `appops set [package name] ACTIVATE_VPN allow`"; `AndroidLibXrayLite/README.md:10-15` `gomobile bind -androidapi 24`; `V2rayNG/app/build.gradle.kts:25` `minSdk 24` (2.3.x) vs `minSdk 21` (2.2.x).

- **Xray-core + AndroidLibXrayLite, 50k+ stars:**
  - HOW: App embeds `Xray-core` as `.aar` built from Go repo `2dust/AndroidLibXrayLite` (`libv2ray_android.go` wraps `Xray-core` `core` + `infra/conf/serial`). Release APKs ship prebuilt `libXray.aar` (often `Xray v26.7.28` in 2.3.6, `v26.6.27` in 2.2.6). No `sing-box` native core — contrasts with `v2rayN` desktop which bundles both; v2rayNG is Xray-only (hence Hysteria1/2 via Xray limited). `hev-socks5-tunnel` submodule provides native `libtun2socks.so`/`libhev-socks5-tunnel.so` for VpnService → SOCKS bridge.
  - FILE: `.gitmodules:1-10` `submodule AndroidLibXrayLite` + `hev-socks5-tunnel @64cc609`; `AndroidLibXrayLite/go.mod:1-10` `module libXray` `require github.com/xtls/xray-core v1.26.x`; `releases/tag/2.3.6` "Xray-core v26.7.28"; `V2rayNG/app/src/main/java/com/v2ray/ang/service/CoreVpnService.kt:293` tun2socks invoke.

- **Default posture & privacy:**
  - HOW: No analytics, no ads. Update check hits `api.github.com/repos/2dust/v2rayNG/releases` if `Settings → Auto update`; subscription fetch uses provider URL with UA `v2rayNG/<version>` (customizable via `SubscriptionItem.requestHeaders`). GPG signatures shipped since 2.2.6 (`*.sig`, fingerprint `7694 5E9F 3E9A 168F 8070 F195 805D 661C 134D FAF6 8903 C199 463C 31E5 AE90 3AE0`). Assets: `v2rayNG_2.3.6_arm64-v8a.apk` (~27 MB), `_armeabi-v7a`, `_x86`, `_x86_64`, `_universal`, plus `*-fdroid_*.apk` (F-Droid flavor without proprietary bits).
  - FILE: `README.md#GPG Verification` fingerprint; `releases/tag/2.2.6` assets 19 files + `v2rayN-public-key.asc` SHA `e61a5be...`; `Wiki/Release-files-introduction-for-Android:1-30`; `V2rayNG/app/src/main/java/com/v2ray/ang/dto/entities/SubscriptionItem.kt:14` `requestHeaders`.

---

## 2. Supported Protocols — Deep Dive

> All protocols parsed into `ProfileItem` (`EConfigType`) → rendered to **Xray JSON** (`V2rayConfigUtil` / `V2rayConfigManager`) via `outbounds:[{protocol, settings, streamSettings}]` + `routing` + `dns`. No sing-box JSON path (unlike v2rayN).

- **EConfigType enum (source of truth):**
  - 10 values + TUIC disabled comment; order matters for UI spinner.
    - HOW: `EConfigType.kt:1-20` defines `VMESS=1`, `CUSTOM=2`, `SHADOWSOCKS=3`, `SOCKS=4`, `VLESS=5`, `TROJAN=6`, `WIREGUARD=7`, `TUIC=8 /* disabled */`, `HYSTERIA2=9`, `HYSTERIA=900`, `HTTP=10`. `ConfigType` int persisted in `ProfileItem.configType`. `AngConfigManager.importBatchConfig()` dispatches `configFmtParsers: Map<String, (String)->ProfileItem?>` keyed by `vmess://`/`vless://`/`ss://`/`socks://`/`trojan://`/`wireguard://`/`hysteria2://`/`hy2://`/`http://`.
    - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/enums/EConfigType.kt:1-20`; `V2rayNG/app/src/main/java/com/v2ray/ang/handler/AngConfigManager.kt:34-46` `configFmtParsers`; `V2rayNG/app/src/main/java/com/v2ray/ang/fmt/FmtBase.kt:11` base.

- **VMess (Xray `vmess`):**
  - Legacy V2Ray VMess AEAD (uuid + alterId=0, security auto/aes-128-gcm/chacha20-poly1305, all transports).
    - HOW: Share `vmess://BASE64(JSON)` legacy OR `vmess://uuid@host:port?security=auto&network=ws&tls=tls&sni=...&fp=chrome&type=none#remark` URI → `VmessFmt.parse()` → `ProfileItem{configType=VMESS, server, serverPort, id, alterId=0, security, network, headerType, host, path, security=tls/reality/none, sni, alpn, fingerprint}`. Builder emits `outbounds:[{protocol:"vmess", settings:{vnext:[{address,port,users:[{id, alterId, security, level:8}]}]}, streamSettings:{network, security, tlsSettings/realitySettings, wsSettings/grpcSettings/...}}]`.
    - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/fmt/VmessFmt.kt:17-180` both JSON + URI parsers; `V2rayNG/app/src/main/java/com/v2ray/ang/util/V2rayConfigUtil.kt:40-70` vmess outbound.
    - Snippet concept (Xray):
      ```json
      { "protocol": "vmess", "settings": { "vnext": [{ "address": "1.2.3.4", "port": 443, "users": [{ "id": "uuid", "alterId": 0, "security": "auto" }] }] }, "streamSettings": { "network": "ws", "security": "tls", "tlsSettings": { "serverName": "example.com", "fingerprint": "chrome" }, "wsSettings": { "path": "/ray", "headers": { "Host": "example.com" } } } }
      ```
  - Transports: `tcp`/`ws`/`h2`/`http`/`grpc`/`httpupgrade`/`xhttp`/`kcp` (mKCP) — QUIC commented out in `NetworkType.kt:12`.

- **VLESS (Xray `vless` — stateless, `encryption:none`, optional `flow`, Reality/Vision/XHTTP):**
  - Lightweight VMess successor; Vision (`xtls-rprx-vision`) + Reality + XHTTP/SplitHTTP flagship.
    - HOW: `vless://uuid@host:port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=apple.com&fp=chrome&pbk=...&sid=...&type=xhttp&path=/&mode=auto#remark` → `VlessFmt.parse()` reads `encryption` (must `none` unless `native` experimental), `flow`, `security` (`reality`/`tls`/`none`), `sni`, `fp`, `alpn`, `pbk` (publicKey), `sid` (shortId), `spx` (spiderX), `mldsa65Verify`. Builder sets `settings:{vnext:[{address,port,users:[{id, flow, encryption}]}]}` + `streamSettings:{network:"raw"/"xhttp"/"grpc", security:"reality", realitySettings:{serverName, fingerprint, publicKey, shortId, spiderX, mldsa65Verify}, tlsSettings:{fingerprint, alpn, pinnedPeerCertSha256}}`.
    - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/fmt/VlessFmt.kt:11-90`; `V2rayNG/app/src/main/java/com/v2ray/ang/fmt/FmtBase.kt:104-115` reality params; `Wiki/Description-of-VLESS-share-link` (v2rayN wiki cross-ref); `xtls.github.io/en/config/outbounds/vless.html`.
    - Vision note: `flow=xtls-rprx-vision` only valid on `tcp+tls/reality` + `raw`; enables Xray `XTLS Vision` splice (zero-copy) for 5-10× throughput; incompatible with `ws/grpc` — use `xhttp` for Reality+Vision modern.
    - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/enums/NetworkType.kt:1-15` `RAW` vs `XHTTP`; `AndroidLibXrayLite/go.mod` Xray `v26.7.28` Vision support.

- **VLESS Reality / Vision / XHTTP (SplitHTTP):**
  - Reality: TLS camouflage over `raw`/`xhttp`/`grpc`; XHTTP (SplitHTTP) is successor beyond Reality.
    - HOW: Reality fields `pbk` (password/publicKey), `sid` (shortId), `spx` (spiderX), `mldsa65Verify` (post-quantum) carried in URL query; UI `ServerConfigActivity` has Reality section (show only if `security==reality`). XHTTP mode `auto`/`packet-up`/`stream-up`/`stream-one` selectable via `xhttpSettings:{path, host, mode, extra:{xPaddingBytes, headerType, xmux}}`. XHTTP supports HTTP/1.1→H3 fallback and is recommended over WS/gRPC for Reality in 2025-26 Xray docs.
    - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/fmt/FmtBase.kt:126-166` `getQueryDic` serializes `type=xhttp` + `mode` + `extra`; `V2rayNG/app/src/main/java/com/v2ray/ang/ui/servers/ServerConfigActivity.kt:120-200` Reality form; `xtls.github.io/en/config/transports/reality.html`; `xtls.github.io/en/config/transport.html` table `vless`+`xhttp`+`reality` = Supported.

- **Shadowsocks (Xray `shadowsocks`):**
  - SIP002 + legacy Base64, AEAD 2022 support via Xray core.
    - HOW: `ss://method:password@host:port#remark` (plain) OR `ss://BASE64(method:password@host:port)#remark` legacy OR `ss://BASE64(method:password)@host:port/?plugin=obfs-http...` SIP002 → `ShadowsocksFmt.parse()` decodes `method` (`aes-256-gcm`, `chacha20-poly1305`, `2022-blake3-aes-128-gcm`), `password`, `server`, `port`. Builder emits `outbounds:[{protocol:"shadowsocks", settings:{servers:[{address,port,method,password, level, ivCheck, ota?}]}, streamSettings}]` + `sockopt` fork. Shadowsocks-2022 multi-user `method: 2022-blake3-aes-128-gcm` + server key handled.
    - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/fmt/ShadowsocksFmt.kt:29-79` SIP002 + legacy; `V2rayNG/app/src/main/java/com/v2ray/ang/util/V2rayConfigUtil.kt:80-110` shadowsocks outbound; `xtls.github.io` Shadowsocks outbound doc.

- **Trojan (Xray `trojan`):**
  - TLS-tunneled password auth, mimics HTTPS, all transports.
    - HOW: `trojan://password@host:port?security=tls&sni=example.com&type=grpc&serviceName=...#remark` → `TrojanFmt.parse()` → `ProfileItem{configType=TROJAN, password, server, port, network, security, sni, alpn, fp, headerType}`. Builder: `settings:{servers:[{address,port,password, level}]}, streamSettings:{network, security:"tls", tlsSettings:{serverName, fingerprint, alpn}, wsSettings/grpcSettings/...}`. Trojan over `tcp+tls` is classic; over `xhttp`+`reality` possible.
    - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/fmt/TrojanFmt.kt:1-50`; `V2rayNG/app/src/main/java/com/v2ray/ang/fmt/FmtBase.kt:54-94` Trojan fields.

- **SOCKS (Xray `socks` outbound/inbound):**
  - SOCKS4/4a/5 as outbound (chain to upstream SOCKS) + inbound (local).
    - HOW: `socks://username:password@host:port#remark` OR `socks5://`/`socks4://` variants, optional base64 userinfo → `SocksFmt.parse()`. Builder: `settings:{servers:[{address,port,users:[{user,pass}]}, version:"5"]}`. Used for `dialerProxy` WARP chains: set a SOCKS/WireGuard profile as `proxySettings.tag` dialer. Inbound Socks: `inbounds:[{protocol:"socks", port:10808, settings:{auth:"noauth", udp:true}, sniffing}]`.
    - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/fmt/SocksFmt.kt:10-35`; `V2rayNG/app/src/main/java/com/v2ray/ang/util/V2rayConfigUtil.kt:120-140` socks outbound; `V2rayNG/app/src/main/java/com/v2ray/ang/handler/MmkvManager.kt:110` `PREF_SOCKS_PORT`.

- **HTTP (HTTP proxy):**
  - HTTP/HTTPS outbound + insecure mix.
    - HOW: `http://user:pass@host:port` → `EConfigType.HTTP` (value 10) → parsed same as Socks but builder emits `protocol:"http" settings:{servers:[{address,port,users:[{user,pass}]}]}`. Rarely used as primary; more as `dialerProxy` or corporate upstream.
    - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/enums/EConfigType.kt:HTTP=10`; `V2rayNG/app/src/main/java/com/v2ray/ang/fmt/FmtBase.kt:90` HTTP branch.

- **WireGuard (Xray `wireguard` outbound, via Xray, not kernel):**
  - Full WG via Xray (user-space), `wireguard://` URI + `.conf` file import.
    - HOW: `wireguard://privateKey@host:port?publickey=xxx&address=10.0.0.2/32,2606:4700:.../128&mtu=1280&presharedkey=xxx&reserved=0,0,0#remark` OR classic `[Interface]/[Peer]` `.conf` pasted → `WireguardFmt.parse()` extracts `secretKey` (private), `publicKey` (peer), `preSharedKey`, `localAddress` (comma-separated CIDRs), `mtu`, `reserved` (3 bytes for WARP). Builder: `settings:{secretKey, address:["10.0.0.2/32"], peers:[{publicKey, endpoint:"host:port", preSharedKey, keepAlive:25}], mtu, reserved, kernelMode:false}`. Used for Cloudflare WARP — common chain: `VLESS → wireguard (WARP)` via `proxySettings.tag` or `dialerProxy`.
    - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/fmt/WireguardFmt.kt:30-52` URI + conf parser; `V2rayNG/app/src/main/java/com/v2ray/ang/util/V2rayConfigUtil.kt:60-90` wireguard outbound; `xtls.github.io` WireGuard inbound example.

- **Hysteria2 (Xray `hysteria2`, via `hysteria2://` / `hy2://`):**
  - QUIC-based Hysteria2 (hy2) — **fully supported** in v2rayNG 2.2.x+ via Xray `hysteria` transport (Xray `hysteriaSettings`).
    - HOW: `hysteria2://password@host:port?security=tls&sni=example.com&alpn=h3&obfs=salamander&obfs-password=...&mport=...&pinSHA256=...#remark` → `Hysteria2Fmt.parse()` maps `password` (auth), `security` (tls), `sni`, `alpn` (default `h3`), `obfs` (`salamander`), `obfs-password`, `mport` (port hopping range `10000-20000`), `pinSHA256` (pinnedPeerCert). Builder emits `protocol:"hysteria2"`? Actually Xray uses `protocol:"hysteria2"` + `streamSettings:{network:"hysteria", security:"tls", hysteriaSettings:{...}, tlsSettings:{serverName, alpn, pinnedPeerCertSha256}}` OR newer `protocol:"hysteria"` variant. Earlier confusion: Xray-core **does** support Hysteria2 outbound since late 2024 via `hysteria` transport; v2rayNG's `issues/2799` closed as added. Verify: `V2rayNG` formatter exists, and Xray docs list `hysteria` transport.
    - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/fmt/Hysteria2Fmt.kt:14-66` `obfs`/`mport`; `V2rayNG/app/src/main/java/com/v2ray/ang/enums/EConfigType.kt:HYSTERIA2=9`; `xtls.github.io/en/config/transport.html` `hysteria` transport method; `github.com/2dust/v2rayNG/issues/2799` closed 2024-02-01.

- **Hysteria v1 (legacy `hysteria://`):**
  - Older Hysteria 1 — still parsed, value 900.
    - HOW: `hysteria://host:port?auth=...&upmbps=...&downmbps=...&obfs=...&sni=...` → same formatter family but `configType=900`. Retained for backward compat; recommended to migrate to hy2.
    - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/enums/EConfigType.kt:HYSTERIA=900`; `Hey/docs/v2rayng-analysis/01-protocols-and-parsing.md:15` table.

- **TUIC (quic `tuic://`):**
  - **Disabled/commented** in current v2rayNG.
    - HOW: `EConfigType.TUIC=8` exists but `configFmtParsers` map in `AngConfigManager.kt:34-46` does **not** include `tuic://` key; `NetworkType.kt:12` has `// QUIC` commented. So `tuic://` links will fail to import → toast "unsupported protocol". Workaround: use CUSTOM JSON or switch to NekoBox/Matsuri which have sing-box TUIC. Issue `2dust/v2rayNG/issues/3618` requested sing-box TUIC like v2rayN, closed wontfix (Xray-only stance).
    - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/enums/EConfigType.kt:TUIC=8 /* disabled */`; `V2rayNG/app/src/main/java/com/v2ray/ang/handler/AngConfigManager.kt:34-46` missing tuic; `Hey/docs/v2rayng-analysis/01-protocols-and-parsing.md:11` "TUIC ❌ 注释 暂未启用".

- **CUSTOM (raw JSON):**
  - Full Xray JSON passthrough — escape hatch for TUIC/ShadowTLS/any exotic.
    - HOW: `EConfigType.CUSTOM=2` stored as `ProfileItem` with `server=null` + `customConfigJson` field (full `{"log":..., "inbounds":..., "outbounds":..., "routing":..., "dns":...}`). `AngConfigManager` skips formatter, directly writes custom JSON to `V2rayConfigUtil` with `isCustomConfig=true`. Enables advanced WARP chains: set `outbounds[0].proxySettings.tag` or `outbounds[0].streamSettings.sockopt.dialerProxy` to second outbound tag (`wireguard-warp`), or `routing`+`dialerProxy`. UI: `Add Custom Config` → paste JSON → Save.
    - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/enums/EConfigType.kt:CUSTOM=2`; `V2rayNG/app/src/main/java/com/v2ray/ang/handler/AngConfigManager.kt:60-80` custom path; `V2rayNG/app/src/main/java/com/v2ray/ang/ui/servers/ServerConfigActivity.kt:200` custom editor.

- **v2rayn:// (internal share):**
  - v2rayN internal encrypted share (added 2.3.1).
    - HOW: `v2rayn://BASE64(JSON ProfileItem)` — same `ProfileItem` serialized + base64, used for clone between v2rayN desktop and v2rayNG. `AngConfigManager` added parser `v2rayn://` → `JsonUtil.fromJson(ProfileItem)` direct.
    - FILE: `releases/tag/2.3.6` "支持导入v2rayN 内部分享 `v2rayn://`"; `V2rayNG/app/src/main/java/com/v2ray/ang/handler/AngConfigManager.kt:45` `v2rayn://` entry.

---

## 3. Transports / Encryption — Deep Dive

- **Transport abstraction (`NetworkType` / `streamSettings`):**
  - Unified `streamSettings:{network, security, *_Settings, sockopt}` per outbound; UI `NetworkType` spinner drives JSON key.
    - HOW: `NetworkType.kt:1-20` enum `TCP="tcp", KCP="kcp"/"mkcp", WS="ws", HTTP="http", H2="h2", GRPC="grpc", HTTPUPGRADE="httpupgrade", XHTTP="xhttp", HYSTERIA="hysteria"`, plus `QUIC` commented. `FmtBase.getItemFormQuery()` reads `type`/`network` query param; `FmtBase.getQueryDic()` serializes back for `toUri()`. `V2rayConfigUtil` switches on `profile.network` to emit `tcpSettings`/`wsSettings`/`grpcSettings`/`xhttpSettings` etc., and on `profile.security` for `tlsSettings`/`realitySettings`.
    - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/enums/NetworkType.kt:1-15`; `V2rayNG/app/src/main/java/com/v2ray/ang/fmt/FmtBase.kt:126-166` `getQueryDic`; `V2rayNG/app/src/main/java/com/v2ray/ang/util/V2rayConfigUtil.kt:50-120` streamSettings builder; `xtls.github.io/en/config/transport.html` transport table.

- **TCP (raw):**
  - Plain TCP, optionally `headerType: none` or `http` (fake HTTP Host/Path).
    - HOW: `network=tcp` → `tcpSettings:{header:{type:"none"}}` or `header:{type:"http", request:{version:"1.1", method:"GET", path:["/"], headers:{Host:["example.com"]}}}` + `host`/`path` query remapped. Used for VLESS Vision (`tcp+reality+vision`) and classic Trojan/VMess. If `type=tcp` + `security=reality` + `flow=xtls-rprx-vision` → max performance.
    - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/fmt/FmtBase.kt:128` `tcp` branch; `xtls.github.io/en/config/transports/raw.html`.

- **WebSocket (`ws`):**
  - `ws` + `early-data`/`maxEarlyData`, Host/path headers, CDN-friendly.
    - HOW: `type=ws&host=cdn.example.com&path=/ray%3Fed%3D2048` → `wsSettings:{path:"/ray", headers:{Host:"cdn.example.com"}, maxEarlyData:2048, earlyDataHeaderName:"Sec-WebSocket-Protocol"}`. Works with `security=tls` (WS+TLS) for Cloudflare. Not compatible with Reality (see table: `websocket+reality` = Not supported — use XHTTP instead).
    - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/fmt/FmtBase.kt:135` `wsSettings`; `xtls.github.io/en/config/transports/websocket.html`.

- **gRPC (`grpc`):**
  - HTTP/2 gRPC (`gun`/`multi` mode), `serviceName` + `authority`.
    - HOW: `type=grpc&serviceName=grpc&authority=example.com&mode=multi` → `grpcSettings:{serviceName:"grpc", authority:"example.com", multiMode:true/false}`. Requires `security=tls` or `reality` (Reality+gRPC is supported: `grpc+reality` = Supported). Used for Google-optimized paths, less CDN-friendly than WS/XHTTP.
    - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/fmt/FmtBase.kt:145` `grpcSettings`; `xtls.github.io/en/config/transports/grpc.html`; transport table `grpc+reality Supported`.

- **HTTP/2 (`h2` / `http`):**
  - HTTP/2 multiplexed (`h2`), `host`/`path`.
    - HOW: `type=h2&host=example.com&path=/ray` → `httpSettings:{path:"/ray", host:["example.com"]}` (some Xray versions use `h2Settings`). Single TLS connection multiplexes many streams; good for browser-like fingerprint but more fingerprintable than WS.
    - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/fmt/FmtBase.kt:138` `h2`/`http` branch; `xtls.github.io/en/config/transports/http.html`.

- **mKCP (`kcp` / `mkcp`):**
  - UDP-based KCP with `seed`, `headerType` (none/srtp/utp/wechat-video/dtls/wireguard), `mtu`/`tti`/`uplinkCapacity`/`downlinkCapacity`/`congestion`.
    - HOW: `type=kcp&seed=xxx&headerType=srtp&mtu=1350&tti=20` → `kcpSettings:{mtu, tti, uplinkCapacity, downlinkCapacity, congestion, readBufferSize, writeBufferSize, header:{type}}`. Only for `VMess` historically; rarely used now (superseded by XHTTP/QUIC). Xray still supports but v2rayNG UI shows KCP only for VMess.
    - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/fmt/FmtBase.kt:140` `kcpSettings`; `V2rayNG/app/src/main/java/com/v2ray/ang/enums/NetworkType.kt:kcp`; `Hey/docs/v2rayng-analysis/01-protocols-and-parsing.md:20` KCP row.

- **HTTPUpgrade (`httpupgrade`):**
  - WS-like upgrade over HTTP/1.1 `Upgrade: websocket`-less, more CDN-bypass.
    - HOW: `type=httpupgrade&host=example.com&path=/upgrade` → `httpupgradeSettings:{path:"/upgrade", host:"example.com"}`. Supported with `tls` ( `httpupgrade+tls` Supported, `httpupgrade+reality` Not supported per table — reality needs raw/xhttp/grpc).
    - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/fmt/FmtBase.kt:142` `httpupgradeSettings`; `xtls.github.io/en/config/transports/httpupgrade.html`.

- **XHTTP / SplitHTTP (`xhttp`):**
  - Next-gen SplitHTTP (XHTTP) — beyond Reality, supports `auto`/`packet-up`/`stream-up`/`stream-one` + `extra` + `xmux`.
    - HOW: `type=xhttp&host=example.com&path=/&mode=auto&extra=...` → `xhttpSettings:{path:"/", host:"example.com", mode:"auto", extra:{scMaxEachPostBytes, scMaxEachPostBytes:"1000000", scStreamUpServerSecs, xPaddingBytes, headerType, xmux:{maxConcurrency, maxConnections, cMaxReuseTimes}}}`. Modes: `auto` (smart split UL/DL), `packet-up` (packet upload), `stream-up` (stream upload), `stream-one` (single stream). Extra: `xPaddingBytes` `100-1000` obfuscation, `xmux` multiplexing for high concurrency. Supports `reality` and `tls` both; is the **recommended** transport for Reality in 2025+ Xray docs ("XHTTP: Beyond REALITY"). v2rayNG 2.3.x UI exposes XHTTP mode + extra JSON field.
    - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/fmt/FmtBase.kt:148-166` `xhttpSettings` + `mode` + `extra`; `releases/tag/2.3.6` Xray v26.7.28 includes XHTTP stabilizations; `xtls.github.io/en/config/transports/xhttp.html` (SplitHTTP); `pkg.go.dev/github.com/xtls/xray-core/transport/internet/splithttp` `Config` fields `GetMode`, `GetXPaddingBytes`, `GetXmuxConfig`.

- **QUIC (`quic`):**
  - **Commented/disabled** in current v2rayNG despite Xray support for `quicSettings`.
    - HOW: `NetworkType.kt:12` has `// QUIC` line commented; `FmtBase.getQueryDic` has no `quic` branch. Hysteria2 uses its own QUIC-like `hysteria` transport, not Xray `quic`. To get QUIC, use CUSTOM JSON `streamSettings:{network:"quic", quicSettings:{security:"none", key:"", header:{type:"none"}}}` or use Hysteria2.
    - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/enums/NetworkType.kt:12` comment; `Hey/docs/v2rayng-analysis/01-protocols-and-parsing.md:22` "quic 注释 暂未启用".

- **TLS (`tls` security layer, not transport):**
  - Go TLS 1.3 + uTLS fingerprint (`chrome`/`firefox`/`ios`/`android`/`edge`/`safari`/`360`/`qq`), ALPN, SNI, `pinnedPeerCertSha256`, `verifyPeerCertByName`.
    - HOW: `security=tls&sni=example.com&fp=chrome&alpn=h2%2Chttp%2F1.1&pinSHA256=...` → `tlsSettings:{serverName:"example.com", fingerprint:"chrome", alpn:["h2","http/1.1"], pinnedPeerCertSha256:["SHA256:..."], allowInsecure:false (removed 2026.8), verifyPeerCertByName:true/false}`. Since 2.2.3/2.3.x, `allowInsecure` deprecated → removed 2026.08 — must use `pinnedPeerCertSha256` (obtain via `ServerConfig → Get cert SHA256`). `AppConfig.kt:225-226` constants `TLS="tls"`, `REALITY="reality"`.
    - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/AppConfig.kt:225-226` `TLS`/`REALITY`; `V2rayNG/app/src/main/java/com/v2ray/ang/fmt/FmtBase.kt:104-115` TLS params; `releases/tag/2.2.6` "移除 allowInsecure 首选项，该选项已被弃用，请使用证书指纹 pinnedPeerCertSha256" + "添加 verifyPeerCertByName"; `releases/tag/2.3.6` `allowInsecure` removal notice link `https://github.com/2dust/v2rayN/discussions/9460`.

- **Reality (`reality` security layer):**
  - Modified TLS with `target` handshake camouflage, `publicKey`/`shortId`/`spiderX`/`mldsa65Verify`, only with `raw`/`xhttp`/`grpc`.
    - HOW: `security=reality&sni=www.apple.com&fp=chrome&pbk=...&sid=abcd&spx=%2F&mldsa65Verify=...` → `realitySettings:{serverName:"www.apple.com", fingerprint:"chrome", publicKey/pbk, shortId/sid, spiderX/spx, mldsa65Verify, show:false}`. Server's `target` cert must be >3500 bytes and support X25519MLKEM768 for PQ. Client `pbk` derived via `./xray x25519 -i "server private key"`. v2rayNG validates `pbk` length and shows "Reality" badge.
    - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/fmt/FmtBase.kt:110` reality branch; `xtls.github.io/en/config/transports/reality.html` `REALITY is a modified form of TLS`; `xtls.github.io/en/config/transport.html` table `reality` only with `raw`/`xhttp`/`grpc`.

- **Flow (`xtls-rprx-vision` etc.):**
  - XTLS Vision splice flow for VLESS `tcp+tls/reality`.
    - HOW: `flow=xtls-rprx-vision` (or `xtls-rprx-vision-udp443`) appended to VLESS query; builder sets `settings.vnext[0].users[0].flow`. Enables kernel splice on Linux/Android for zero-copy; incompatible with mux. UI enables Flow dropdown only when `network=raw` + `security=tls|reality` + `protocol=VLESS`. If set incorrectly, Xray logs `flow not supported`.
    - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/fmt/VlessFmt.kt:20` `flow`; `xtls.github.io` VLESS flow docs; `V2rayNG/app/src/main/java/com/v2ray/ang/ui/servers/ServerConfigActivity.kt:140` flow visibility.

---

## 4. Cores Matrix — Xray via AndroidLibXrayLite vs sing-box vs Others

- **Single-core design (Xray-only) — unlike v2rayN desktop:**
  - HOW: v2rayNG is **Xray-core only**. APK embeds one `libXray.aar` (Go). `v2rayN` desktop ships `Xray` + `sing-box` + `mihomo` + `hysteria2`/`naive`/`tuic` as separate `bin/*.exe` selectable per profile via `CoreType` enum; v2rayNG has no `CoreType` enum — every `ProfileItem` renders to Xray JSON regardless. If you need sing-box protocols (ShadowTLS, sing-box TUIC), use NekoBox/Matsuri or CUSTOM JSON workaround.
  - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/enums/EConfigType.kt` no CoreType; `v2rayN/ServiceLib/Enums/ECoreType.cs` vs `v2rayNG` absence; `.gitmodules` only `AndroidLibXrayLite` + `hev-socks5-tunnel`, no `sing-box` submodule.

- **AndroidLibXrayLite — Go gomobile wrapper:**
  - Build: `gomobile bind -androidapi 24 -trimpath -ldflags='-s -w -buildid= -checklinkname=0' ./` in repo root; produces `libXray.aar` (contains `arm64-v8a`/`armeabi-v7a`/`x86`/`x86_64` `libgojni.so`). Go files: `libv2ray_main.go` ( `StartLoop(config string)`, `StopLoop()`, `TestOutbound` ), `libv2ray_android.go` ( `VpnSupportReadyCallback`, `RunTun2socks` glue), `libv2ray_certSha256.go` ( `GetCertSha256(addr)` ), `libv2ray_utils.go` ( `MeasureDelay`, `GetVersion` ). Go mod pins `xray-core v1.26.x` + `google.golang.org/protobuf`.
  - HOW: App calls `LibXray.initV2Env(cacheDir, isUid)` once, then per-connect `LibXray.startLoop(jsonConfig)` on background thread; stop via `LibXray.stopLoop()`. Version string from `LibXray.getXrayVersion()`. Cert SHA256 fetched via `LibXray.getCertSha256("host:443")` for pinnedPeerCert.
  - FILE: `AndroidLibXrayLite/libv2ray_main.go:1-60`; `AndroidLibXrayLite/libv2ray_android.go:1-30`; `AndroidLibXrayLite/libv2ray_certSha256.go:1-20`; `AndroidLibXrayLite/go.mod:1-15`; `AndroidLibXrayLite/README.md:1-15` build instructions; `V2rayNG/app/src/main/java/com/v2ray/ang/handler/MmkvManager.kt:50` `goVersion`.

- **hev-socks5-tunnel — native tun2socks bridge (C):**
  - Submodule `heiher/hev-socks5-tunnel` @64cc609; compiled via `compile-hevtun.sh` (NDK `ndk-build`/`cmake` → `libhev-socks5-tunnel.so` per ABI). Replaces older `tun2socks` (Go) and `leaf` for lower overhead. Command: `hev-socks5-tunnel --socks-server-addr 127.0.0.1:10808 --tunfd <fd> --tunmtu 1500 --netif-ipaddr 10.10.14.2 --netif-netmask 255.255.255.0 --loglevel ...` launched from `CoreVpnService.runTun2socks()`.
  - HOW: `CoreVpnService.kt:293-326` spawns process via `ProcessBuilder` or JNI `HevTun2Socks` class; passes TUN fd via `ParcelFileDescriptor.detachFd()`. Supports IPv6, UDP associate, DNS gateway `--enable-dnsgw` if `PREF_LOCAL_DNS_ENABLED`. Stopped in `stopTun2socks()` via `destroy()`.
  - FILE: `.gitmodules:hev-socks5-tunnel`; `compile-hevtun.sh:1-30`; `V2rayNG/app/src/main/java/com/v2ray/ang/service/CoreVpnService.kt:293-326` `runTun2socks` params; `V2rayNG/app/src/main/java/com/v2ray/ang/root/RootLanSharing.kt:26-35` LAN share uses same bin via `su`.

- **No per-app cores / per-profile core selection:**
  - HOW: v2rayN desktop allows `profile.coreType = CoreType.sing_box` to render sing-box JSON for that node; v2rayNG has no such field — `ProfileItem` lacks `coreType`. All profiles use same LibXray instance; switching nodes just rewrites JSON and restarts Loop. Therefore Hysteria1/2 support depends solely on Xray's Hysteria transport, not external binary.
  - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/dto/ProfileItem.kt:1-40` no `coreType`; `v2rayN/ServiceLib/Models/ProfileItem.cs:CoreType` vs `v2rayNG` diff.

- **Version matrix & updates:**
  - HOW: 2.2.6 bundles `Xray-core v26.6.27`; 2.3.1-2.3.6 bundles `v26.7.28` (July 2026). Update cadence tied to Xray releases (~monthly). `AndroidLibXrayLite` commits track Xray `go.mod` bump; CI GitHub Actions builds AAR + APK per ABI. GPG sigs per asset.
  - FILE: `releases/tag/2.2.6` "Xray-core v26.6.27"; `releases/tag/2.3.6` "Xray-core v26.7.28"; `AndroidLibXrayLite/commits` 243 commits.

---

## 5. Subscription Formats

- **Universal subscription (base64 batch):**
  - Standard: URL returns `base64( lines of vmess://|vless://|ss://|trojan://|socks://|wireguard://|hysteria2://|hy2://|http:// )` OR plain lines OR `sip008` JSON array. `AngConfigManager.updateConfigViaSub()` fetches via OkHttp with custom headers, auto-detects base64 vs plain vs `max-` gzip, decodes, splits `\n`, filters empty, deduplicates by `server:port+id`, applies `SubscriptionItem.filter` regex, then `importBatchConfig()` per line.
    - HOW: `SubscriptionUpdater.kt:20-58` fetch loop; `AngConfigManager.importBatchConfig(subId, base64DecodedString)` iterates `configFmtParsers` keys; failures collected as `importViaSub failure count`. `SubscriptionItem.kt:13` `filter: String` regex applied post-parse (`if (!remarks.matches(Regex(filter))) skip`).
    - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/handler/AngConfigManager.kt:80-120` batch import; `V2rayNG/app/src/main/java/com/v2ray/ang/dto/entities/SubscriptionItem.kt:3-17` fields; `V2rayNG/app/src/main/java/com/v2ray/ang/handler/SubscriptionUpdater.kt:34-58` fetch.

- **Per-scheme examples (what parser accepts):**
  - `vmess://` → legacy base64(JSON) or `vmess://uuid@host:port?net=ws&host=...&path=...&tls=tls&sni=...&fp=chrome`
  - `vless://uuid@host:port?encryption=none&flow=...&security=reality&sni=...&fp=...&pbk=...&sid=...&spx=...`
  - `ss://method:password@host:port#remark` (SIP002) or `ss://BASE64`
  - `trojan://password@host:port?security=tls&sni=...&type=...&path=...`
  - `socks://user:pass@host:port` / `socks5://`
  - `wireguard://privKey@host:port?publickey=...&address=...&mtu=...&reserved=...`
  - `hysteria2://password@host:port?sni=...&alpn=h3&obfs=...&obfs-password=...&mport=...&pinSHA256=...` + `hy2://` alias
  - `http://user:pass@host:port`
  - `v2rayn://BASE64(ProfileItem JSON)` (2.3.1+)
    - HOW: Each `*Fmt.kt` `parse()` validates prefix, decodes base64/url, extracts `server`/`port`/`id`/`password`, then `FmtBase.getItemFormQuery()` maps `sni`→`profile.sni`, `fp`→`fingerprint`, `alpn`→`alpn`, `pbk`→`publicKey`, `sid`→`shortId`, `spx`→`spiderX`, `host`→`host`, `path`→`path`, `type`→`network`, etc. `toUri()` does reverse for sharing.
    - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/fmt/VmessFmt.kt:31-180`; `VlessFmt.kt:11-90`; `ShadowsocksFmt.kt:29-79`; `SocksFmt.kt:10-35`; `TrojanFmt.kt:1-50`; `WireguardFmt.kt:46-60`; `Hysteria2Fmt.kt:37-66`; `FmtBase.kt:54-116` query map.

- **SubscriptionItem model & storage (MMKV):**
  - Fields: `remarks` (name), `url` (https), `enabled: Boolean`, `autoUpdate: Boolean`, `updateInterval: Long` (min, default 1440 = 24h), `lastUpdated: Long` (epoch ms), `filter: String` (regex), `userAgent: String`, `requestHeaders: String` (JSON `{"X-hwid":"...","Authorization":"Bearer ..."}`), `allowInsecureUrl: Boolean`, `prevProfile`/`nextProfile` (guid hints). Stored as JSON string via `MmkvManager.encodeSubscription(guid, item)` + `decodeSubscription()`.
    - HOW: `SubEditActivity.kt:63` loads `MmkvManager.decodeSubscription(editSubId)` or `SubscriptionItem()` new; `mutableStateOf` fields bound to Compose TextFields; `saveServer()` validates `Utils.isValidUrl()` + `updateInterval >= 60` then `MmkvManager.encodeSubscription()` + `SubscriptionUpdater.syncOne()`. `MmkvManager.kt:339-447` holds `MMKV.mmkvWithID("sub")` instance.
    - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/dto/entities/SubscriptionItem.kt:3-17`; `V2rayNG/app/src/main/java/com/v2ray/ang/ui/subscription/SubEditActivity.kt:48-120`; `V2rayNG/app/src/main/java/com/v2ray/ang/handler/MmkvManager.kt:339-447`; `V2rayNG/app/src/main/java/com/v2ray/ang/util/JsonUtil.kt:96-113` `parseHeadersToMap()`.

- **Update mechanism — WorkManager + Foreground Service:**
  - Manual: `SubscriptionsViewModel.updateSubscriptions()` filters `enabled` subs → `SubscriptionUpdateMessage` → `SubscriptionUpdateService`. Background: `SubscriptionUpdater` schedules periodic `WorkManager` (`RemoteWorkManager`) per `updateInterval`; also `autoUpdate` flag on app launch. Service uses `Semaphore(2)` concurrency limit. Post-update optional chain: **update → test → auto-remove invalid → auto-sort by delay** (2.3.x new: combined batch job in `Sub Settings → Update subscription` with checkboxes for each step, else stay on current page).
    - HOW: `SubscriptionUpdater.syncOne()` enqueues `OneTimeWorkRequestBuilder<SubscriptionUpdateWorker>` with `setInputData(workDataOf("subGuid" to guid))`; `SubscriptionUpdateService.kt:39` `Semaphore(2)`; `onStartCommand` fetches `UrlContentRequest(url, headers, userAgent)` via `OkHttp` → `AngConfigManager.updateConfigViaSub()` → if success `testSubscriptionServers()` (see §11). Since 2.3.1, `SubEditActivity` has grouped toggles `updateSub → autoTest → autoRemoveInvalid → autoSort` executed as sequential WorkManager chain.
    - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/handler/SubscriptionUpdater.kt:20-188` scheduling; `V2rayNG/app/src/main/java/com/v2ray/ang/service/SubscriptionUpdateService.kt:29-153` semaphore + fetch + post-test; `V2rayNG/app/src/main/java/com/v2ray/ang/ui/subscription/SubscriptionsViewModel.kt:62-73` `updateSubscriptions()`; `releases/tag/2.3.1` "订阅分组设置中，更新订阅时可以组合多个选项进行后台任务".

- **Custom headers & User-Agent (2.3.x):**
  - HOW: `SubEditActivity` exposes `Custom HTTP headers` JSON textarea → `SubscriptionItem.requestHeaders` (example `{"X-hwid":"my_test_device","Authorization":"Bearer test"}`) → `JsonUtil.parseHeadersToMap()` → `UrlContentRequest.headers` → `OkHttp Request.Builder.addHeader()`. Useful for HWID-locked panels (Marzban, 3x-ui). `userAgent` field defaults to `v2rayNG/<version>` but editable.
  - FILE: `releases/tag/2.3.6` "为订阅更新添加自定义 HTTP headers ， JSON 格式内容随意"; `V2rayNG/app/src/main/java/com/v2ray/ang/dto/UrlContentRequest.kt:3-11`; `V2rayNG/app/src/main/java/com/v2ray/ang/util/JsonUtil.kt:96-113`.

- **Import paths — clipboard / QR / file / manual:**
  - Clipboard: `MainActivity → Import from Clipboard` → `Utils.getClipboard()` → `AngConfigManager.importBatchConfig()` handles single URI or base64 batch. QR: `Scan QR` uses `CameraX` + `MLKit BarcodeScanning` → decode → same import. File: `Import from file` → `ACTION_OPEN_DOCUMENT` → read text → import. Manual: `Add [VMess/VLESS/...]` → `ServerConfigActivity` form → `MmkvManager.encodeProfile()`. Share: `Share → Export to Clipboard` → `FmtBase.toUri()` + `QR code` bitmap via `ZXing`.
  - HOW: `V2rayNG/app/src/main/java/com/v2ray/ang/ui/MainActivity.kt:80-120` clipboard/QR; `V2rayNG/app/src/main/java/com/v2ray/ang/handler/AngConfigManager.kt:46-80` import dispatcher; `V2rayNG/app/src/main/java/com/v2ray/ang/util/Utils.kt:208-228` `isValidUrl()` + clipboard.
  - FILE: `README.md` "Download / 下载" import via QR; `fastlane/metadata` description.

- **WARP chains via custom config / dialerProxy / proxySettings.tag:**
  - HOW: To chain `VLESS Reality` → `WARP WireGuard`: (1) Add WireGuard WARP profile (`wireguard://...` with `address 172.16.0.2/32`+`reserved` for WARP). (2) Add VLESS profile, set `Custom Config` JSON: in `outbounds[0]` add `"proxySettings": {"tag":"warp","transportLayer":true}` OR `"streamSettings":{"sockopt":{"dialerProxy":"warp"}}` where second outbound `"tag":"warp"` is the WireGuard. v2rayNG exposes `Custom Config` editor per profile (since 2.2.x) — paste full JSON. Alternative: use global `routing` → `dialerProxy` chain without per-profile edit (edit `Settings → Custom routing JSON` → add `outbounds` array with both). Technique documented in v2rayN wiki cross-ref, works identically in v2rayNG because Xray core same.
  - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/util/V2rayConfigUtil.kt:90` `proxySettings.tag`/`dialerProxy`; `Hey/docs/v2rayng-analysis/01-protocols-and-parsing.md:30` WireGuard reserved; `Wiki/Custom-routing` (v2rayNG wiki) + `v2rayN Wiki/Socks-chain`.

---

## 6. Routing / Split Tunneling

- **Routing modes (`RoutingType` enum, `AppConfig`):**
  - `Bypass LAN + CN` (默认 `bypass mainland` — `geoip:cn` + `geosite:cn` direct, rest proxy), `Global proxy`, `Bypass LAN`, `Custom rules`.
    - HOW: `Settings → Routing` spinner → `RoutingType` (`Custom`, `BypassLan`, `BypassChina`, `Global`) persisted via `MmkvManager`/`SettingsManager` (`PREF_ROUTING`). `V2rayConfigUtil.getV2rayConfig()` generates `routing:{domainStrategy, rules:[...], balancers, strategy}` accordingly. `bypass mainland` uses `Loyalsoldier/v2ray-rules-dat` enhanced dat (see GeoIP).
    - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/enums/RoutingType.kt:1-20`; `V2rayNG/app/src/main/java/com/v2ray/ang/handler/MmkvManager.kt:120` `PREF_ROUTING`; `V2rayNG/app/src/main/java/com/v2ray/ang/util/V2rayConfigUtil.kt:30-100` routing builder; `12vpx.com/en/docs/split-routing-v2rayng` guide.

- **Custom routing rules (domain/IP):**
  - UI fields `Direct URL or IP`, `Proxy URL or IP`, `Block URL or IP` (comma-separated geosite/geoip/domain/IP/CIDR). Advanced: edit raw `routing.rules` JSON via `Settings → Custom routing` (overrides UI).
    - HOW: `SettingsActivity → Routing settings` has three EditTexts → `MmkvManager.saveRoutingRules(direct, proxy, block)` → `V2rayConfigUtil` splits by `,` → emits `routing.rules: [{type:"field", domain:["geosite:..."], outboundTag:"direct"}, {ip:["geoip:..."], outboundTag:"direct"}, {domain:["geosite:category-ads-all"], outboundTag:"block"}]`. OutboundTag mapping: `proxy` (selected node), `direct` (freedom), `block` (blackhole). Supports `ext:` syntax for third-party dat.
    - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/ui/SettingsActivity.kt:80-120` routing UI; `V2rayNG/app/src/main/java/com/v2ray/ang/util/V2rayConfigUtil.kt:60-90` rule gen; `www.v2ray.com/en/configuration/routing.html` rules spec.

- **Per-app proxy / bypass (VpnService allow/bypass list):**
  - Most visible split tunneling: select apps to proxy or bypass via `VpnService.Builder.addAllowedApplication()` / `addDisallowedApplication()`.
    - HOW: `Settings → Per-app proxy` toggle `PREF_PER_APP_PROXY` + mode `PREF_BYPASS_APPS` (true = bypass selected = `addDisallowedApplication`, false = only proxy selected = `addAllowedApplication`). `CoreVpnService.configurePerAppProxy(builder)` iterates `MmkvManager.getPerAppProxyApps()` (package names) → `builder.addDisallowedApplication(pkg)` or `addAllowedApplication(pkg)` plus always `addDisallowedApplication(com.v2ray.ang)` (self-exclusion to prevent loop). Uses `PackageUidResolver` to map pkg→uid for logging but builder needs pkg name. Since Android 5.0, only one VPN per device; per-app is the only app-level split available without root. Request `QUERY_ALL_PACKAGES` permission on Android 30+.
    - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/service/CoreVpnService.kt:293-326` `configurePerAppProxy`; `V2rayNG/app/src/main/java/com/v2ray/ang/util/PackageUidResolver.kt:8-33` pkg→uid; `V2rayNG/app/src/main/java/com/v2ray/ang/handler/MmkvManager.kt:140` `PREF_PER_APP_PROXY`/`PREF_BYPASS_APPS`; `V2rayNG/app/src/main/java/com/v2ray/ang/enums/PermissionType.kt:23-26` `QUERY_ALL_PACKAGES` (API 30).

- **GeoIP / GeoSite (`geoip.dat`/`geosite.dat`, Loyalsoldier):**
  - Embedded assets + downloadable enhanced dat + manual replace.
    - HOW: APK embeds `assets/geoip.dat` + `geosite.dat` (official `v2fly/domain-list-community` + `v2fly/geoip`). Settings `Update Geo assets` downloads enhanced version from `github.com/Loyalsoldier/v2ray-rules-dat` (requires working proxy) → saves to `Android/data/com.v2ray.ang/files/assets/` (path varies via `getExternalFilesDir`). Manual: replace `geoip.dat`/`geosite.dat` there via file manager, or use third-party dat (e.g., `h2y`) via `ext:h2y.dat:category-ads` in custom routing. `routing` references `geosite:cn`, `geoip:cn`, `geosite:geolocation-!cn`, `geosite:category-ads-all`.
    - FILE: `README.md#Geoip and Geosite` 4 bullets; `V2rayNG/app/src/main/java/com/v2ray/ang/handler/MmkvManager.kt:200` asset path; `AndroidLibXrayLite/assets/` fallback; `Wiki/Geoip and Geosite`.

- **domainStrategy & sniffing:**
  - `domainStrategy: AsIs` / `IPIfNonMatch` / `IPOnDemand` (Settings) controls DNS routing before proxy.
    - HOW: `Settings → Domain strategy` → `PREF_DOMAIN_STRATEGY` → `routing.domainStrategy` in JSON. `AsIs` = keep domain for outbound (best for Reality/XHTTP), `IPIfNonMatch` = resolve if no domain rule matches, `IPOnDemand` = resolve only when needed. `inbounds[0].sniffing:{enabled:true, destOverride:["http","tls","quic","fakedns"], metadataOnly:false, routeOnly:false}` enabled to detect `bittorrent`/`http`/`tls` for routing even when destination is IP (effects: `attrs[':method']=='GET'` Starlark).
    - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/util/V2rayConfigUtil.kt:40` `domainStrategy`; `www.v2ray.com/en/configuration/routing.html` `domainStrategy` + `attrs`; `V2rayNG/app/src/main/java/com/v2ray/ang/handler/MmkvManager.kt:160` `PREF_DOMAIN_STRATEGY`.

- **Bypass LAN & private IPs:**
  - Toggle `Bypass LAN` (`PREF_VPN_BYPASS_LAN`) excludes RFC1918 + multicast.
    - HOW: `CoreVpnService.kt:225-244` checks `AppConfig.PREF_VPN_BYPASS_LAN` — if true, `builder.addRoute` skips adding `0.0.0.0/0` full route and instead adds `ROUTED_IP_LIST` (contains `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, `224.0.0.0/3` etc. as individual `addRoute` per CIDR) + excludes private DNS; if false, `addRoute("0.0.0.0",0)` + `addRoute("::",0)` globals. Also `routing.rules` adds `ip:["geoip:private"] → direct` as safety.
    - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/AppConfig.kt:ROUTED_IP_LIST`; `V2rayNG/app/src/main/java/com/v2ray/ang/service/CoreVpnService.kt:225-244` bypass LAN; `V2rayNG/app/src/main/java/com/v2ray/ang/handler/MmkvManager.kt:130` `PREF_VPN_BYPASS_LAN`.

---

## 7. TUN / VPN Mode

- **Android VpnService full TUN (no root):**
  - HOW: `CoreVpnService` extends `VpnService` → `VpnService.prepare(context)` permission intent → `Builder` → `establish()` returns `ParcelFileDescriptor` (fd). All device traffic enters TUN `tun0`. `Builder.setMtu(VPN_MTU)` default `1500` (editable via Settings `MTU`); `builder.addAddress(PRIVATE_VLAN4_CLIENT, 30)` (e.g., `10.10.14.1/30` peer `10.10.14.2`), `addDnsServer()`, `addRoute()`, `addAllowed/DisallowedApplication()`, `setSession("v2rayNG VPN")`, `setMetered(false)` (API 29+), `setHttpProxy(ProxyInfo.buildDirectProxy("127.0.0.1", httpPort))` for Chrome's proxy. Foreground notification via `NotificationService.showNotification()` for `START_STICKY`.
  - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/service/CoreVpnService.kt:21-208` `onCreate`/`onStartCommand`/`configureVpnService`/`onDestroy`; `V2rayNG/app/src/main/AndroidManifest.xml:20` `<service android:name=".service.CoreVpnService" android:permission="android.permission.BIND_VPN_SERVICE">`; `V2rayNG/app/src/main/java/com/v2ray/ang/enums/VpnInterfaceAddressConfig.kt:8-21` address pairs.

- **MTU, IPv4/IPv6, DNS servers on TUN:**
  - IPv4: hard-coded pair `PRIVATE_VLAN4_CLIENT="10.10.14.1"` + `PRIVATE_VLAN4_ROUTER="10.10.14.2"` /30; netmask `255.255.255.0`. IPv6 optional: `fd00::1`/`fd00::2` /126 if `PREF_PREFER_IPV6`/`PREF_IPV6_ENABLED` toggled. MTU: `PREF_VPN_MTU` default `1500`, range `1280-9000`; passed to both `Builder.setMtu()` and `hev-socks5-tunnel --tunmtu`. DNS: `SettingsManager.getVpnDnsServers()` iterates `[PREF_REMOTE_DNS, PREF_LOCAL_DNS, 1.1.1.1, 8.8.8.8]` filtered to pure IPs → `builder.addDnsServer(ip)` each; if `PREF_LOCAL_DNS_ENABLED` also add `127.0.0.1` fake. Modern Android `setUnderlyingNetworks()` (API 28+) handles network switch without reconnect via `ConnectivityManager.NetworkCallback`.
  - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/service/CoreVpnService.kt:193-256` IP/MTU/DNS/NetworkCallback; `V2rayNG/app/src/main/java/com/v2ray/ang/enums/VpnInterfaceAddressConfig.kt:15-21` IPv4/IPv6; `V2rayNG/app/src/main/java/com/v2ray/ang/handler/SettingsManager.kt:125` `getVpnDnsServers()`; `V2rayNG/app/src/main/java/com/v2ray/ang/handler/MmkvManager.kt:150` `PREF_VPN_MTU`.

- **Per-app VPN (see §6) — same mechanism:**
  - HOW: No separate engine — `CoreVpnService.configurePerAppProxy()` calls `builder.addAllowedApplication()` / `addDisallowedApplication()` before `establish()`. Self always disallowed. Behavior: `Bypass mode` (default toggle on) = all apps via VPN except selected → `addDisallowedApplication` per selected pkg; `Whitelist mode` (bypass off) = only selected via VPN → `addAllowedApplication` per selected + `addDisallowedApplication("com.v2ray.ang")` mandatory. Since Android N, `addAllowedApplication` requires explicit per-app; pre-N falls back to full VPN with routing rules only.
  - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/service/CoreVpnService.kt:293-326`; `V2rayNG/app/src/main/java/com/v2ray/ang/ui/perapp/PerAppProxyActivity.kt:1-60` UI checklist; `12vpx.com/en/docs/split-routing-v2rayng` per-app guide.

- **hev-socks5-tunnel glue — TUN fd → SOCKS:**
  - HOW: `CoreVpnService.runTun2socks()` constructs `String[] cmd = {"hev-socks5-tunnel", "--socks-server-addr", "127.0.0.1:"+socksPort, "--tunfd", String.valueOf(fd), "--tunmtu", String.valueOf(mtu), "--netif-ipaddr", "10.10.14.2", "--netif-netmask", "255.255.255.0", "--loglevel", "warn", "--enable-dnsgw", "false/true", "--dnsgw-addr", dnsGW}` → `Runtime.exec()` or `HevTun2Socks.start(cmd)` JNI. The C process `poll(2)` on `tunFd`, reads IP packets, extracts TCP/UDP flows, opens SOCKS5 `CONNECT`/`UDP ASSOCIATE` to Xray's local `socks` inbound, pipes data. UDP handled via `UDP ASSOCIATE` + `enable-dnsgw` for DNS. Stopped via `HevTun2Socks.stop()` → `destroy()` + `ParcelFileDescriptor.close()`.
  - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/service/CoreVpnService.kt:280-310` `runTun2socks`/`stopTun2socks`; `compile-hevtun.sh:1-30` NDK build; `V2rayNG/app/src/main/java/com/v2ray/ang/util/Utils.kt:80` `getSocksPort()`.

- **Kill switch / leak prevention:**
  - Android system kill switch (`Settings → Network → VPN → ⚙️ v2rayNG → Always-on VPN + Block connections without VPN`) — enforced by OS, not app; v2rayNG recommends enabling it. App-level: `onRevoke()` → `stopAllService()` → `LibXray.stopLoop()` + `stopTun2socks()` + `mInterface.close()` ensures no bare traffic after VPN revoked. `START_STICKY` + foreground notification + `isStartingLock` AtomicBoolean prevents gap. `vpnProtect(socket)` calls `protect(fd)` for Xray's outbound sockets so they bypass TUN (prevents loop). No separate `iptables` — rely on VpnService.
  - HOW: `CoreVpnService.kt:86-116` `onRevoke`/`onDestroy`/`isStartingLock`; `CoreVpnService.kt:158-160` `vpnProtect(socket) { return protect(socket) }`; `V2rayNG/app/src/main/java/com/v2ray/ang/service/CoreServiceManager.kt:1-60` `stopCoreLoop()` + `notificationCancel()`; Android docs "Always-on VPN" requires `setUnderlyingNetworks(null)` handled.

- **LibXray VpnService integration (Xray's own TUN):**
  - Alternative: some forks/experimental use `Xray-core` `tun` inbound directly (Xray's `tun` + `netstack`) instead of hev tunnel; v2rayNG keeps hev path for stability and for pre-API 28. Root LAN sharing path (`RootLanSharing.kt:26-35`) bypasses VpnService entirely and starts hev tunnel via `su` + `iptables REDIRECT`.
  - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/root/RootLanSharing.kt:14-50` `start()` via `RootShell`; `V2rayNG/app/src/main/java/com/v2ray/ang/root/RootShell.kt:16-30` `su` exec; `V2rayNG/app/src/main/java/com/v2ray/ang/service/CoreVpnService.kt:50-76` `NetworkCallback` + `setUnderlyingNetworks`.

- **Proxy-Only mode (no TUN) — contrast:**
  - HOW: `Settings → Mode → Proxy Only` → starts `CoreProxyOnlyService` (or `CoreVpnService` with `isProxyOnly=true`) that only does `LibXray.startLoop()` + opens `127.0.0.1:10808` SOCKS / `10809` HTTP — no `VpnService.Builder`, no fd, no hev tunnel. Apps must manually set SOCKS/HTTP proxy (Firefox `manual proxy`, browsers don't on Android). Useful for LAN share or non-VPN testing. Toggle in `MainActivity` FAB long-press vs VPN.
  - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/service/CoreProxyOnlyService.kt:1-60` (legacy) vs `CoreVpnService.kt:118` `isProxyOnly` check; `V2rayNG/app/src/main/java/com/v2ray/ang/handler/MmkvManager.kt:100` `PREF_MODE` enum `VPN`/`PROXY_ONLY`.

- **Root mode — system-wide without VpnService (2.2.6+):**
  - HOW: `Settings → Root mode (requires root)` → uses `su` to start Xray in `TProxy`/`REDIRECT` mode via `RootLanSharing` + `iptables -t nat -A OUTPUT -p tcp -j REDIRECT --to-ports 10808` chain. Added in `2.2.6 #5812`. Allows VPN without notification and without Android's single-VPN limit. Requires `Magisk`/`KernelSU` + `Allow root`. Experimental, not default.
  - FILE: `releases/tag/2.2.6` "添加无需 VPN 服务的 root 权限系统级运行模式，需要 root #5812" + "添加热点网络共享功能， 需要 root"; `V2rayNG/app/src/main/java/com/v2ray/ang/root/RootLanSharing.kt:26-35` `su` hev; `V2rayNG/app/src/main/java/com/v2ray/ang/root/RootShell.kt:23-30`.

---

## 8. Local Socks / HTTP Inbounds & Per-Profile Ports

- **Inbounds hard-coded per profile (generated JSON `inbounds`):**
  - `inbounds: [{tag:"socks", protocol:"socks", port:10808, listen:"127.0.0.1", settings:{auth:"noauth", udp:true, ip:"127.0.0.1"}, sniffing:{enabled:true, destOverride:["http","tls","quic","fakedns"], metadataOnly:false}}, {tag:"http", protocol:"http", port:10809, listen:"127.0.0.1", settings:{allowTransparent:false}, sniffing}]` — two local listeners always. `allowTransparent` only true in TUN mode for TProxy. Ports user-editable via `Settings → SOCKS port` (`PREF_SOCKS_PORT` default 10808) + `HTTP port` (`PREF_HTTP_PORT` default 10809) + `PREF_SOCKS_USERNAME/PASSWORD` for auth.
    - HOW: `V2rayConfigUtil.getV2rayConfig()` creates `inbounds` list using `MmkvManager.getSocksPort()`/`getHttpPort()` ints; `sniffing.enabled=true` for routing. `PREF_ALLOW_LAN` (false) controls `listen:"0.0.0.0"` vs `127.0.0.1` — if true, inbounds bind `0.0.0.0` so LAN devices via `RootLanSharing` can use phone as gateway (`192.168.1.x:10808`). `setHttpProxy()` mirrors HTTP inbound for system `ProxyInfo`.
    - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/util/V2rayConfigUtil.kt:20-45` inbounds builder; `V2rayNG/app/src/main/java/com/v2ray/ang/handler/MmkvManager.kt:105-115` `PREF_SOCKS_PORT`/`PREF_HTTP_PORT`/`PREF_SOCKS_USERNAME`; `V2rayNG/app/src/main/java/com/v2ray/ang/handler/SettingsManager.kt:40` `isAllowLan`.

- **Not per-profile — global (one inbound for all profiles):**
  - HOW: Switching active profile rewrites single Xray `config.json` and restarts core — there is only one `socks`+`http` inbound at a time, not per-profile ports like NekoBox's per-profile `mixed` port. So `PREF_SOCKS_PORT` is global. Workaround: CUSTOM JSON can add `inbounds` with distinct tags per outbound via `inboundTag` routing, but UI not expose.
  - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/handler/MmkvManager.kt:60` `getSelectServer()` one active; `V2rayNG/app/src/main/java/com/v2ray/ang/service/CoreServiceManager.kt:20` `startCoreLoop()` one instance.

- **Tun2socks ↔ SOCKS linkage:**
  - HOW: `CoreVpnService.runTun2socks --socks-server-addr 127.0.0.1:<PREF_SOCKS_PORT>` must match inbound `port`. If user changes port, both JSON and hev args updated on next VPN start. Mismatch would blackhole traffic — app restarts core after port change to guarantee consistency.
  - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/service/CoreVpnService.kt:283` `getSocksPort()` in both builder + tunnel args.

---

## 9. DPI Bypass — Reality / XTLS / Fragment / uTLS / XHTTP

- **Reality — strongest (TLS camouflage):**
  - HOW: See §3 Reality; Reality defeats DPI by answering with real site's (target `apple.com`, `microsoft.com`, `www.google.com`) cert + `SpiderX` crawler fingerprint; server's `target` domain cert length >3500 bytes; client SNI = Reality serverName, not real destination. Xray `realitySettings` + `flow: xtls-rprx-vision` together give outer TLS that is indistinguishable from legitimate web. Best practice: borrow same ASN domain (e.g., if server in `AS4134 CHINANET`, target `www.qq.com` same ASN). `releases/tag/2.2.6` warns `allowInsecure` removal pushes users to Reality/pinned cert instead of blind skip.
  - FILE: `xtls.github.io/en/config/transports/reality.html:1-80`; `Xray-core/discussions/4113` XHTTP Beyond Reality; `V2rayNG` Reality UI; `releases/tag/2.3.6` `allowInsecure` removal notice.

- **XTLS Vision (`xtls-rprx-vision`):**
  - HOW: Flow `xtls-rprx-vision` (or `xtls-rprx-vision-udp443` for UDP) enables splice where Xray after handshake `splice`s TCP to kernel, zero-copy → higher throughput + fewer distinguishable packets. Must be `VLESS` + `tcp (raw)` + `tls/reality`; incompatible with mux/fragment. v2rayNG UI shows `Flow` dropdown only in that combo; otherwise greyed.
  - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/fmt/VlessFmt.kt:25` flow; `xtls.github.io` Vision docs; `V2rayNG/app/src/main/java/com/v2ray/ang/util/V2rayConfigUtil.kt:70` `flow` → `settings.flow`.

- **Fragment (TLS fragment via Xray `sockopt`/`fragment`):**
  - HOW: Xray `outbounds[0].settings.fragment:{packets:"tlshello", length:"100-200", interval:"10-20"}` + `sockopt:{tcpKeepAliveInterval, tcpMptcp, dialerProxy}` splits TLS ClientHello into fragments to evade SNI-based DPI (Iran/Russia). v2rayNG exposes `Settings → Fragment` (toggle + `packets`/`length`/`interval` fields) since 2.1.x; writes to `outbounds[*].settings.fragment` or global `sockopt`. Effectiveness: moderate vs SNI DPI, but Reality is stronger; fragment increases latency slightly. Combines with `proxySettings.tag` chain for Defense-in-depth (fragment outer, Reality inner).
  - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/handler/MmkvManager.kt:170` `PREF_FRAGMENT_ENABLED`/`PREF_FRAGMENT_PACKETS`/`LENGTH`/`INTERVAL`; `V2rayNG/app/src/main/java/com/v2ray/ang/util/V2rayConfigUtil.kt:80` fragment injection; `Wiki/Fragment-and-noise` (cross-ref v2rayN).

- **uTLS fingerprint (`fingerprint`/`fp`):**
  - HOW: `tlsSettings.fingerprint: "chrome"` (default) randomizes ClientHello via `fakedns`/`utls` library (Go `utls`). Options in UI: `chrome`, `firefox`, `safari`, `ios`, `android`, `edge`, `360`, `qq`, `random`, `randomized`. Per-profile `fp` query param overrides global `Settings → Mux/Fingerprint`. Reality also uses `fingerprint` for inner hello.
  - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/fmt/FmtBase.kt:107` `fp`; `V2rayNG/app/src/main/java/com/v2ray/ang/util/V2rayConfigUtil.kt:55` `fingerprint`; `xtls.github.io` TLS fingerprint docs.

- **XHTTP `xPaddingBytes` / `xmux` obfuscation:**
  - HOW: New in Xray 26.x + v2rayNG 2.3.6: `xhttpSettings.extra.xPaddingBytes: "100-1000"` adds random padding to split HTTP requests, defeating size-based DPI; `xmux:{maxConcurrency:"8-16", maxConnections:"1-4", cMaxReuseTimes:"0"}` multiplexes. These are `extra` JSON in `xhttpSettings` — v2rayNG 2.3.x exposes `XHTTP extra` freeform field for raw JSON.
  - FILE: `pkg.go.dev/github.com/xtls/xray-core/transport/internet/splithttp Config GetXPaddingBytes` + `GetXmuxConfig`; `V2rayNG/app/src/main/java/com/v2ray/ang/fmt/FmtBase.kt:160` `extra`; `releases/tag/2.3.6` Xray v26.7.28 includes XHTTP stabilization.

- **Mux (TCP multiplexing, not DPI but performance):**
  - HOW: `Settings → Mux` toggle + `Concurrency` (default 8, range -1…64, `-1` = disabled) → `mux:{enabled:true/false, concurrency:8, xudpConcurrency, xudpProxyUDP443:"reject|allow|skip"}` in JSON. Mux multiplexes multiple TCP streams over one Reality/Vision connection → fewer handshakes, better under DPI throttling. Incompatible with `flow:xtls-rprx-vision` (Vision disables mux). `XUDP` extension proxies UDP over mux.
  - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/handler/MmkvManager.kt:180` `PREF_MUX_ENABLED`/`CONCURRENCY`; `V2rayNG/app/src/main/java/com/v2ray/ang/util/V2rayConfigUtil.kt:45` mux builder; `V2rayNG/app/src/main/java/com/v2ray/ang/util/V2rayConfigUtil.kt:90` `xudp`.

- **No ByeDPI / no native DPI-bypass engine:**
  - HOW: Unlike NekoBox `Hiddify`/`ByeDPI` integration, v2rayNG has no standalone `ByeDPI`/`GoodbyeDPI`/`Zapret` engine — relies purely on Xray's Reality/Fragment/uTLS/XHTTP. If you need ByeDPI split, run separate `ByeDPI for Android` app and chain via `dialerProxy` SOCKS (`127.0.0.1:1080` ByeDPI → VLESS Reality). Workflow: ByeDPI `SOCKS on 1080` → v2rayNG SOCKS inbound `10808` dialerProxy to outer; or CUSTOM JSON with `proxySettings.tag`.
  - FILE: `Hey/docs/v2rayng-analysis/01-protocols-and-parsing.md:30` no ByeDPI; `V2rayNG/app/src/main/java/com/v2ray/ang/util/V2rayConfigUtil.kt:100` `dialerProxy`/`proxySettings` for chain.

---

## 10. DNS — Xray dns, Hijack, FakeDNS, DoH, VPN DNS

- **Xray `dns` section — core DNS routing:**
  - Generated JSON `dns:{tag:"dns", hosts:{}, servers:[{address:"1.1.1.1", domains:["geosite:geolocation-!cn"], expectIPs:["geoip:!cn"], queryStrategy:"UseIPv4"}, {address:"223.5.5.5", domains:["geosite:cn"], expectIPs:["geoip:cn"]}, {address:"1.1.1.1", port:53, domains:["geosite:category-ads-all"]?}], queryStrategy:"UseIP", disableCache:false, disableFallback:true}` — built from UI fields. `queryStrategy: UseIPv4`/`UseIP`/`UseIPv6` controls A vs AAAA. `expectIPs` verifies geoip.
    - HOW: `V2rayConfigUtil.getV2rayConfig()` assembles `dns` object using `SettingsManager.getRemoteDns()` + `getDirectDns()` + routing domain lists. `dns.servers` entries paired with `geosite`/`geoip` conditions so `cn` via Alibaba `223.5.5.5` direct, rest via `1.1.1.1`/`8.8.8.8` via proxy. Supports DoH `https://dns.google/dns-query` or `tls://8.8.8.8` via `address` URL scheme (Xray auto-DoH/DoT).
    - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/util/V2rayConfigUtil.kt:25-55` dns builder; `V2rayNG/app/src/main/java/com/v2ray/ang/handler/SettingsManager.kt:100` `getRemoteDns()`/`getLocalDns()`; `xtls.github.io/en/config/dns.html`.

- **VPN DNS vs Xray DNS — two layers:**
  - HOW: (1) `CoreVpnService.Builder.addDnsServer(ip)` sets OS-level DNS for `tun0` — used by Android's `netd` for apps that call `getaddrinfo` before routing to TUN; v2rayNG feeds `Settings → VPN DNS` + `PRE_REMOTE_DNS` (`1.1.1.1:53`) + `PREF_LOCAL_DNS` (`223.5.5.5` if bypass CN). (2) Xray `dns` section handles proxied app traffic's DNS resolution inside core (with `domainStrategy`). If `enableLocalDns` true, Xray also starts DNS inbound `fakedns`/`dokodemo-door`? Actually `fakedns` pools for sniffing. Mismatch between VPN DNS and Xray DNS causes leaks — app sets both consistently.
  - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/service/CoreVpnService.kt:247-256` VPN DNS `addDnsServer`; `V2rayNG/app/src/main/java/com/v2ray/ang/handler/SettingsManager.kt:110` `getVpnDnsServers()`; `V2rayNG/app/src/main/java/com/v2ray/ang/handler/MmkvManager.kt:130` `PREF_LOCAL_DNS_ENABLED`/`PREF_REMOTE_DNS`/`PREF_DIRECT_DNS`.

- **Remote DNS / Direct DNS fields:**
  - HOW: `Settings → DNS` has `Remote DNS` (default `1.1.1.1`, used for proxied domains) and `Direct DNS` (default `223.5.5.5`, used for `geosite:cn` direct). Text fields accept `IP`, `IP:port`, `tls://IP`, `https://doh.url`, `quic://IP`. `SettingsManager` validates via `Utils.isPureIpAddress()` fallback to `1.1.1.1`. Combined into `dns.servers` array with `domains` filters as above.
  - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/ui/SettingsActivity.kt:100` DNS UI; `V2rayNG/app/src/main/java/com/v2ray/ang/handler/SettingsManager.kt:100` parsers.

- **FakeDNS (`fakedns` pool):**
  - HOW: Toggle `Settings → FakeDNS` (`PREF_FAKE_DNS_ENABLED`) → injects `dns:{hosts:{}, servers:..., fakedns:[{ipPool:"198.18.0.0/15", lruSize:10000}]}` + `inbounds.sniffing.destOverride:["fakedns"]`. FakeDNS returns `198.18.x.y` for proxied domains without real lookup (faster, avoids DNS leak) — later Xray resolves real IP via tun2socks. Pool `198.18.0.0/15` is `Carrier Grade NAT` reserved for faking; optional IPv6 `fc00::/18`. Enabled automatically if `domainStrategy` is `IPIfNonMatch`? Actually independent.
  - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/util/V2rayConfigUtil.kt:35` fakedns insertion; `V2rayNG/app/src/main/java/com/v2ray/ang/handler/MmkvManager.kt:165` `PREF_FAKE_DNS_ENABLED`; `xtls.github.io/en/config/dns.html#FakeDNS`.

- **DoH / DoT / QUIC DNS:**
  - HOW: Xray `dns.servers[].address` supports `https://dns.google/dns-query` (DoH), `tls://1.1.1.1` (DoT), `quic://dns.adguard-dns.com` (DoQ). v2rayNG passes through whatever user types in `Remote DNS` field — no validation beyond `Utils.isUrl()`. Example WARP custom: `https://1.1.1.1/dns-query` via proxy to avoid ISP DNS hijack. Verify via `Xray dns` log `query via`.
  - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/util/V2rayConfigUtil.kt:40` address passthrough; `xtls.github.io` dns servers DoH examples.

- **Routing's `domainStrategy` interaction:**
  - HOW: As above §6: `routing.domainStrategy: AsIs|IPIfNonMatch|IPOnDemand` tells core when to use `dns`. `AsIs` keeps domain for routing (best for `geosite` + FakeDNS) — `dns` queried only if rule needs IP; `IPIfNonMatch` resolves if no domain rule matched. `domainStrategy` also set per `dns` entry via `queryStrategy` (`UseIPv4` vs `UseIP`). v2rayNG UI radio `Domain strategy` sets this.
  - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/handler/MmkvManager.kt:160` `PREF_DOMAIN_STRATEGY`; `V2rayNG/app/src/main/java/com/v2ray/ang/util/V2rayConfigUtil.kt:50` routing.domainStrategy.

---

## 11. Other Features — Speed Test, Backup/Restore, Widgets, Tiles

- **Speed test — Real Delay Test (outbound `observatory`/delay test):**
  - HOW: `MainActivity → Test real delay` batch: `AngConfigManager.testRealDelay()` spawns per-profile `TestLoop` via `LibXray.measureDelay(configJson, timeout=8000ms)` — creates temporary Xray instance per node with `inbound: SOCKS` + `outbound: node's config` + `routing: all to proxy` → fetches `http://www.google.com/generate_204` or `https://www.gstatic.com/generate_204` via proxy, measures RTT, returns ms or `-1` failure. UI sorts by delay (`sortByTestResults`). 2.3.x added **TCP ping** pre-check + concurrency limit (`maxConcurrency` 20?) to accelerate: `Tcping` via `Utils.tcping(host, port, 3000ms)` before full Xray loop.
  - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/handler/AngConfigManager.kt:100-150` `testRealDelay`; `AndroidLibXrayLite/libv2ray_utils.go:20` `MeasureDelay`; `V2rayNG/app/src/main/java/com/v2ray/ang/util/Utils.kt:80` `tcping`; `releases/tag/2.3.6` "添加 TCP ping 测试，有最大并发控制" + "真连接测试添加 Tcping 预检查，加快测试速度；移除 Tcping 菜单"; `V2rayNG/app/src/main/java/com/v2ray/ang/ui/MainActivity.kt:120` `Test real delay`.

- **URL/DNS routing test:**
  - HOW: `Settings → Routing test` or `Main → three dots → Test routing` → input `URL` (`https://example.com`) → `AngConfigManager.testRouting(url)` checks which `routing.rules` matches (simulates Xray `route` without traffic). Useful to verify `bypass LAN`/`geosite:cn` correctness.
  - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/handler/AngConfigManager.kt:160` `testRouting`.

- **Custom config JSON (CUSTOM tag):**
  - HOW: `Add Custom Config → Paste JSON` → full Xray JSON stored as `ProfileItem.customConfig` (CUSTOM type). `V2rayConfigUtil.getV2rayConfig()` branch `if (customConfigJson.isNotEmpty()) return customConfigJson` bypasses generation. Enables TUIC/ShadowTLS/any non-UI feat: paste Xray JSON with `outbounds: [{protocol:"tuic", ...}]` + required `streamSettings`. Validate via `JsonUtil.isValidJson()`.
  - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/enums/EConfigType.kt:CUSTOM=2`; `V2rayNG/app/src/main/java/com/v2ray/ang/ui/servers/ServerConfigActivity.kt:210` custom editor; `releases/tag/2.2.6` "添加手动配置文件存储修复 #6094".

- **Backup / Restore & share:**
  - Share log: `Settings → Share log` (2.2.6 #5682) exports `xray.log` + `service.log` via `ACTION_SEND`.
  - Backup/Restore: `Settings → Backup/Restore → Export` → `mmkv` dump to `Android/data/com.v2ray.ang/files/backup/v2rayng_backup_<date>.json` via `MmkvManager.encodeAllProfiles()` → `ContentResolver` `ACTION_CREATE_DOCUMENT`. Restore reads same file, merges `profiles`+`subscriptions`+`settings`. Also `Settings → Share → Export subscription` → base64 batch to clipboard.
  - HOW: `MmkvManager.kt:300-350` `encodeAll()`/`decodeAll()` JSON array of `ProfileItem` + `SubscriptionItem`; `Utils.shareLog()` zip; `Wiki/Backup-and-restore`.
  - FILE: `releases/tag/2.2.6` "添加分享日志 #5682"; `V2rayNG/app/src/main/java/com/v2ray/ang/handler/MmkvManager.kt:300-350` backup; `V2rayNG/app/src/main/java/com/v2ray/ang/ui/MainActivity.kt:90` backup menu; `V2rayNG/app/src/main/java/com/v2ray/ang/util/Utils.kt:60` share.

- **Widget & Quick Tile:**
  - HOW: Home-screen widget (1×1) shows `Active profile` + up/down traffic; tap toggles VPN via `VpnService` intent. Quick Settings Tile (`V2RayTileService extends TileService`) appears in notification shade (`QS` pull-down) — tile states `STATE_ACTIVE`/`INACTIVE` synced with `CoreServiceManager.isRunning` via `MMKV` + `onTileClick()` → `startService`/`stopService`. No floating widget since Compose migration retained.
  - FILE: `V2rayNG/app/src/main/AndroidManifest.xml:40` `<service android:name=".service.V2RayTileService" android:permission="android.permission.BIND_QUICK_SETTINGS_TILE">`; `V2rayNG/app/src/main/java/com/v2ray/ang/service/V2RayTileService.kt:1-40`; `V2rayNG/app/src/main/java/com/v2ray/ang/widget/V2RayWidgetProvider.kt:1-40`.

- **Notification & always-on UX:**
  - HOW: Foreground notification (`NotificationManager.showNotification()`) shows `Connected: <remark> — ↑↓ MB/s` with `Disconnect` action; `START_STICKY` + `setOngoing(true)` prevents swipe. Tap notification opens `MainActivity`. `START_STICKY` ensures OS restarts after kill; user can enable `Settings → Allow background`/`Battery optimization ignore` to keep alive. `Always-on VPN` (system) separate.
  - FILE: `V2rayNG/app/src/main/java/com/v2ray/ang/service/CoreVpnService.kt:124` `showNotification`; `V2rayNG/app/src/main/java/com/v2ray/ang/util/NotificationService.kt:1-50`.

- **Monet / UI polish (2.3.x):**
  - HOW: `Material3` dynamic color via `DynamicColors.applyToActivitiesIfAvailable()` (Android 12+ Monet) — `releases/tag/2.3.6` #6067. Compose animations, `LazyColumn` server list, swipe-to-delete, drag-reorder subscriptions via `SubscriptionsViewModel.swapSubscriptions()`. Translation contributors page added #6114.
  - FILE: `releases/tag/2.3.6` "支持莫奈动态色彩 #6067" + "添加翻译贡献者页面 #6114"; `V2rayNG/app/src/main/java/com/v2ray/ang/ui/MainActivity.kt:20` Compose theme.

- **Hotspot / LAN sharing (root):**
  - HOW: `Settings → Hotspot sharing` (2.2.6 `添加热点网络共享功能，需要 root`) → `RootLanSharing.start()` via `su` sets `iptables -t nat -A PREROUTING --in-interface wlan1 -p tcp -j REDIRECT --to-ports <socksPort>` so hotspot clients route through Xray. Uses same `hev-socks5-tunnel` but bound `0.0.0.0`. Requires root + hotspot active.
  - FILE: `releases/tag/2.2.6` hotspot feature; `V2rayNG/app/src/main/java/com/v2ray/ang/root/RootLanSharing.kt:14-50`.

---

## 12. Platforms & Requirements

- **Android version coverage:**
  - HOW: `minSdk 21` (Android 5.0 Lollipop) legacy / `minSdk 24` (Android 7.0 Nougat) in 2.3.x Compose branch (due to gomobile + `Java 8` desugar + Monet). `targetSdk 34→37` (Android 14→17) since 2.2.3 (`将 target SDK 版本提升至 37 (Android 17)` — needed for Google Play's Aug 2025 API 34 mandate). `compileSdk 35`. `Kotlin 2.4.0`, `Gradle 8.8+`, `AGP 8.6+`. Supports `armeabi-v7a` (ARM 32), `arm64-v8a` (ARM 64, majority), `x86` (emulator), `x86_64` (emulator/WSA), and `universal` (fat, all ABIs).
  - FILE: `README.md` badge `API 25+`; `AndroidLibXrayLite/README.md` `-androidapi 24`; `releases/tag/2.2.6` targetSdk 37; `V2rayNG/app/build.gradle.kts:20-30` `minSdk`/`targetSdk`/`compileSdk`; `releases/tag/2.2.6` assets show 4 ABIs.

- **Device types — phone, tablet, emulator, TV (unofficial):**
  - HOW: Phone/tablet primary. Android TV (`leanback`) works sideloaded but no `leanback` UI — still uses phone layout + D-pad. WSA (Windows Subsystem for Android) + WayDroid + Android Studio emulator require `appops set com.v2ray.ang ACTIVATE_VPN allow` (WSA's permission manager blocks VPN otherwise). No `WearOS`/`Auto`. `F-Droid` flavor (`*-fdroid_*.apk`) removes `Google Play Services` dependency for de-googled devices.
  - FILE: `README.md#Development guide` "v2rayNG can run on Android Emulators. For WSA, VPN permission need to be granted via `appops set [package name] ACTIVATE_VPN allow`"; `releases/tag/2.2.6` `*-fdroid_*.apk` 4 variants.

- **Permissions (`AndroidManifest.xml`):**
  - HOW: `<uses-permission android:name="android.permission.INTERNET"/>`, `ACCESS_NETWORK_STATE`, `QUERY_ALL_PACKAGES` (API 30+ for per-app list), `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_SPECIAL_USE` (API 34+), `BIND_VPN_SERVICE`, `RECEIVE_BOOT_COMPLETED` (auto-start VPN), `POST_NOTIFICATIONS` (API 33+), `BIND_QUICK_SETTINGS_TILE`, `ACCESS_LOCAL_NETWORK` (Android 15+ API 35 for `RootLanSharing`), `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` optional. Runtime `VPN permission` via `VpnService.prepare()`.
  - FILE: `V2rayNG/app/src/main/AndroidManifest.xml:5-30` permissions; `V2rayNG/app/src/main/java/com/v2ray/ang/enums/PermissionType.kt:1-30` permission map per API.

- **No Windows/Linux/macOS/iOS:**
  - HOW: Desktop sibling `2dust/v2rayN` (WPF/Avalonia) is Windows/Linux/macOS; iOS counterpart is `iOS: Shadowrocket/Quantumult` or `FoXray` (Xray). v2rayNG APK cannot run on those; but `CUSTOM` JSON configs are portable between v2rayN and v2rayNG via `v2rayn://` share.
  - FILE: `README.md` "v2rayNG is the mobile version. For the desktop version, please visit v2rayN https://github.com/2dust/v2rayN"; `github.com/2dust/v2rayN`.

---

## 13. Repo Stats, Build Instructions & File Map

- **Repo stats (snapshot 2026-08-30 webfetch):**
  - HOW: `61.8k★` stars, `8.0k` forks, `710` watchers, `1,699` commits, `15` open issues, `12` open PRs, `243` commits in `AndroidLibXrayLite`, `467★` on that lib, `318` forks. Issues closed include `2799 hysteria`, `3618 protocol support`, `5866 Compose`, `6067 Monet`, `5682 share log`, `5812 root mode`, `6094 manual config fix`, `6114 translators`. Biggest downloads: `v2rayNG_2.2.6_arm64-v8a.apk` 27.3 MB, `universal` 40+ MB. `fdroid` variants same size ±0.4 MB.
  - FILE: Live `https://github.com/2dust/v2rayNG` header; `releases/tag/2.2.6` assets + reactions 215; `releases/tag/2.3.6` reactions 22; `https://github.com/2dust/AndroidLibXrayLite` 467★/243 commits.

- **Build — Gradle wrapper (no NDK for pure Java, NDK for hev):**
  - HOW: Recommended `Android Studio Ladybug+ (AGP 8.6)`. Steps:
    1. `git clone https://github.com/2dust/v2rayNG && cd v2rayNG && git submodule update --init --recursive` (pulls `AndroidLibXrayLite` + `hev-socks5-tunnel`)
    2. Pull or build AAR: `./gradlew :AndroidLibXrayLite:build`? Actually Go step: `cd AndroidLibXrayLite && gomobile init && go mod tidy -v && gomobile bind -v -androidapi 24 -trimpath -ldflags='-s -w -buildid= -checklinkname=0' ./` → `AndroidLibXrayLite.aar` → copy to `V2rayNG/app/libs/` (or `mavenLocal`).
    3. Build hev tunnel (optional): `./compile-hevtun.sh` (needs Android NDK `r27+`, `cmake 3.22+`, `ninja`) → `V2rayNG/app/src/main/jniLibs/<abi>/libhev-socks5-tunnel.so`.
    4. `./gradlew assembleDebug` or `assembleRelease` (or `bundleRelease`). Output `V2rayNG/app/build/outputs/apk/debug/app-debug.apk` (universal) + `fdroid` flavor `assembleFdroidRelease`. For release signing, add `keystore.properties`.
    5. Or open `V2rayNG/` folder directly in Android Studio → Sync → Run `app` on device/emulator. The aar inside repo is probably outdated (`README.md` warns "the v2ray core inside the aar is (probably) outdated").
  - FILE: `README.md#Development guide` 3 bullets; `AndroidLibXrayLite/README.md:1-15` Build requirements + 4 steps; `compile-hevtun.sh:1-30`; `V2rayNG/app/build.gradle.kts:1-50` flavors `fdroid`/`main`; `.github/workflows/` CI builds per ABI.

- **Libs & Gradle deps (key):**
  - HOW: `Kotlin 2.4.0` (`kotlin-gradle-plugin`), `AndroidX Compose BoM 2024.10+` (`compose-material3`, `material-icons-extended`, `activity-compose`, `lifecycle-runtime-compose`, `navigation-compose`), `MMKV 2.x` (`com.tencent:mmkv-static`), `OkHttp 4.12+`, `Gson 2.11+`, `ZXing 3.5` (QR), `MLKit Barcode 17.2` (scan), `Material 1.12`, `PreferenceX`, `WorkManager 2.9` (`RemoteWorkManager` for subs), `Room`? Actually `MMKV` not Room, `RecyclerView` legacy, `ViewModel`/`LiveData`/`Coroutines 1.8`, `Accompanist`/`Compose tooling`, `hev-socks5-tunnel` (C, ndk). Go mods: `xray-core v1.26.x`, `golang.org/x/net`, `google.golang.org/protobuf`, `github.com/xtls/xray-core/*`.
  - FILE: `V2rayNG/app/build.gradle.kts:40-120` dependencies; `AndroidLibXrayLite/go.mod:5-20` require; `V2rayNG/app/src/main/java/com/v2ray/ang/handler/MmkvManager.kt:1-10` MMKV import; `V2rayNG/app/src/main/java/com/v2ray/ang/handler/SubscriptionUpdater.kt:77` WorkManager.

- **File map (top):**
  - HOW:
    ```
    v2rayNG/
    ├─ .gitmodules                       # AndroidLibXrayLite + hev-socks5-tunnel
    ├─ LICENSE                          # GPL-3.0
    ├─ README.md / CR.md / AGENTS.md / CLAUDE.md / GEMINI.md
    ├─ compile-hevtun.sh                # NDK build hev tunnel per ABI
    ├─ AndroidLibXrayLite/              # Go gomobile lib → libXray.aar
    │   ├─ go.mod / go.sum
    │   ├─ libv2ray_main.go             # StartLoop/StopLoop/TestOutbound
    │   ├─ libv2ray_android.go          # VpnSupport callbacks
    │   ├─ libv2ray_certSha256.go       # GetCertSha256
    │   ├─ libv2ray_utils.go            # MeasureDelay/Version
    │   └─ assets/ (geoip/geosite fallback)
    ├─ hev-socks5-tunnel/ @64cc609      # C tun2socks (submodule)
    ├─ V2rayNG/
    │   ├─ app/
    │   │   ├─ build.gradle.kts         # flavors fdroid/main, minSdk/targetSdk
    │   │   ├─ src/main/AndroidManifest.xml
    │   │   ├─ src/main/java/com/v2ray/ang/
    │   │   │   ├─ AppConfig.kt         # constants VPN_MTU/ROUTED_IP_LIST
    │   │   │   ├─ dto/{ProfileItem, SubscriptionItem, SubscriptionCache, UrlContentRequest}
    │   │   │   ├─ enums/{EConfigType, NetworkType, RoutingType, VpnInterfaceAddressConfig, PermissionType}
    │   │   │   ├─ fmt/{FmtBase, VmessFmt, VlessFmt, ShadowsocksFmt, TrojanFmt, SocksFmt, WireguardFmt, Hysteria2Fmt}
    │   │   │   ├─ handler/{MmkvManager, AngConfigManager, V2rayConfigUtil, SettingsManager, SubscriptionUpdater}
    │   │   │   ├─ service/{CoreVpnService, CoreServiceManager, SubscriptionUpdateService, V2RayTileService, NotificationService}
    │   │   │   ├─ root/{RootLanSharing, RootShell}
    │   │   │   ├─ util/{Utils, JsonUtil, PackageUidResolver, MessageUtil, NetworkUtil}
    │   │   │   └─ ui/{MainActivity, SettingsActivity, ServerConfigActivity, PerAppProxyActivity, subscription/*}
    │   │   └─ src/main/jniLibs/<abi>/libhev-socks5-tunnel.so (built)
    │   └─ fastlane/metadata/android/en-US/
    └─ .github/workflows/               # CI: build AAR + APK per ABI + GPG sign
    ```
  - FILE: `README.md` Folders and files table; live `https://github.com/2dust/v2rayNG` file nav; `.gitmodules`; `V2rayNG/app/build.gradle.kts`.

- **CI/CD pipeline:**
  - HOW: `GitHub Actions` (`V2rayNG/.github/workflows/build.yml`): on `push` tag `v*`, runs `setup-java 17`, `setup-go 1.23`, `gomobile bind` per ABI, `ndk-build` hev, `./gradlew assembleRelease` matrix `arm64-v8a`/`armeabi-v7a`/`x86`/`x86_64`/`universal` + `fdroid` variants, then `gpg --detach-sign` per APK + `gh release upload` with SHA256. Badge `GitHub commit activity`.
  - FILE: `.github/workflows/*.yml:1-80`; `releases/tag/2.2.6` `github-actions` released 2026-07-05 with 19 assets + `.sig`.

---

## 14. References

- **Repo & releases (verified 2026-08-30):**
  - HOW: Webfetch `https://github.com/2dust/v2rayNG` (61.8k★/8.0k forks/710 watchers) + `releases` (2.3.6 pre-release 2026-08-29, 2.2.6 latest stable 2026-07-05, Xray v26.7.28/v26.6.27, targets 23 assets per tag) + `AndroidLibXrayLite` (467★/318 forks/243 commits, gomobile bind `-androidapi 24`).
  - FILE: `https://github.com/2dust/v2rayNG`; `https://github.com/2dust/v2rayNG/releases/tag/2.3.6`; `https://github.com/2dust/AndroidLibXrayLite`.

- **DeepWiki docs (last indexed 2026-07-25):**
  - HOW: `deepwiki.com/2dust/v2rayNG/*` indexed `cce2c9cd`: Overview, Core Architecture, Protocol Support, VPN Service Implementation (`CoreVpnService.kt:35-326`), Subscription Management (`SubscriptionUpdater.kt` + `SubscriptionUpdateService.kt:39 Semaphore(2)`), Per-App Proxy, Network Configuration, Routing/DNS, Build System. Used for `ProfileItem` fields, `FmtBase.getQueryDic`, `hev-socks5-tunnel` flows.
  - FILE: `deepwiki.com/2dust/v2rayNG/5-protocol-support`; `6.2-vpn-service-implementation`; `4.4-subscription-management`; `6.5-network-configuration`; `3.3-multi-process-design`.

- **Xray docs & source (accurate to Xray v26.7.28):**
  - HOW: `xtls.github.io/en/config/transports/reality.html` (REALITY only `raw`/`xhttp`/`grpc`), `transport.html` transport×security table (WS+Reality Not supported, XHTTP+Reality Supported), `transports/xhttp.html` (SplitHTTP modes), `Project X Official Website https://xtls.github.io`, `pkg.go.dev/github.com/xtls/xray-core/transport/internet/splithttp Config` (`GetMode`/`GetXPaddingBytes`/`GetXmuxConfig`), `XTLS/REALITY` repo VLESS-REALITY example `flow=xtls-rprx-vision`.
  - FILE: `xtls.github.io/en/config/transport.html`; `xtls.github.io/en/config/transports/reality.html`; `pkg.go.dev/.../splithttp`; `github.com/XTLS/REALITY`.

- **Protocol & parser deep-dive (popsiclelmlm/Hey analysis, 196 lines):**
  - HOW: `github.com/popsiclelmlm/Hey/blob/main/docs/v2rayng-analysis/01-protocols-and-parsing.md` enumerates `EConfigType.kt` 10 protocols table, `NetworkType.kt` 8 transports table, `FmtBase.kt:54-116` `getItemFormQuery` field map, `AngConfigManager.kt:34-46` `configFmtParsers` map missing `tuic://`, confirming TUIC disabled. Copied values verified against webfetched `deepwiki/5-protocol-support` field categories.
  - FILE: `Hey/docs/v2rayng-analysis/01-protocols-and-parsing.md:1-196`.

- **Routing & per-app guides:**
  - HOW: `12vpx.com/en/docs/split-routing-v2rayng` (Predefined `Bypassing LAN and mainland` recommended + Custom rules + Per-app proxy switch), `www.v2ray.com/en/configuration/routing.html` (`domainStrategy`/`attrs` Starlark), `en.v2rayng.org/faq` list of protocols `Fragment, Hysteria, ... VLESS-Reality/Vision, XHTTP`.
  - FILE: `12vpx.com/en/docs/split-routing-v2rayng`; `v2ray.com/en/configuration/routing`; `en.v2rayng.org/faq`.

- **GPG & security note:**
  - HOW: `README.md#GPG Verification` fingerprint `7694 5E9F 3E9A 168F 8070 F195 805D 661C 134D FAF6 8903 C199 463C 31E5 AE90 3AE0`; `releases/tag/2.2.6` `v2rayN-public-key.asc SHA e61a5be...` + note `关于跳过证书验证 allowInsecure 参数被移除的说明 https://github.com/2dust/v2rayN/discussions/9460` (applies to v2rayNG too).
  - FILE: `README.md#GPG Verification`; `releases/tag/2.2.6` warning + `discussions/9460`.

> **Verified 2026-08-30 re-fetch:** GitHub README API 24+ / Kotlin 2.4.0 badges confirmed, releases 2.3.6 (Xray v26.7.28) / 2.2.6 (Xray v26.6.27) / AndroidLibXrayLite 243 commits, Xray docs Reality+XHTTP+Vision transport matrix re-fetched — file re-verified after prior rate-limit.

