# V2RayN (2dust/v2rayN) — Extreme Detail Research

> **Repo:** `2dust/v2rayN` · **License:** GPL-3.0-only · **Language:** C# (~94%) + PowerShell/Batch packaging · **GUI:** WPF (Windows native, `v2rayN/`) + Avalonia Desktop (`v2rayN.Desktop/`, v7.x+) · **Shared lib:** `ServiceLib/` (ViewModels/Handlers/Services/Models) · **Cores:** `Xray-core` (default) + `sing-box` + `mihomo` + `hysteria2`/`naive`/`tuic`/`juicity`/`brook`/etc.
> **Homepage:** https://github.com/2dust/v2rayN · **Wiki:** https://github.com/2dust/v2rayN/wiki · **Telegram:** https://t.me/v2rayN / https://t.me/github_2dust · **Stars (Aug 2026):** ~114.9k★ / ~15.8k forks / 943 watchers · **Latest:** 7.24.9 (2026-08-29), 7.24.8 (2026-08-22), 7.23.4 (2026-07-11)
> **Status:** Actively maintained by `2dust`; v7.x is current major (Avalonia 12 + ReactiveUI 24, Xray `allowInsecure` removed, HappyEyeballs, hy2 ECH, FakeIP range).

---

## Table of Contents

1. [Overview](#1-overview)
2. [Supported Protocols — Deep Dive](#2-supported-protocols--deep-dive)
3. [Transports / Encryption — Deep Dive](#3-transports--encryption--deep-dive)
4. [Cores Matrix — Xray vs sing-box vs Mihomo vs Others](#4-cores-matrix--xray-vs-sing-box-vs-mihomo-vs-others)
5. [Subscription Formats](#5-subscription-formats)
6. [Routing / Split Tunneling](#6-routing--split-tunneling)
7. [TUN vs System Proxy](#7-tun-vs-system-proxy)
8. [DNS — Xray dns, Hijack, FakeDNS, DoH](#8-dns--xray-dns-hijack-fakedns-doh)
9. [Other Features — Latency, Speedtest, Load Balance, Backup, Auto-Update, QR Share](#9-other-features--latency-speedtest-load-balance-backup-auto-update-qr-share)
10. [Platforms & Requirements](#10-platforms--requirements)
11. [Repo Stats, Build Instructions & File Map](#11-repo-stats-build-instructions--file-map)
12. [References](#12-references)

---

## 1. Overview

- **What it is:**
  - Windows-first GUI proxy manager that wraps `Xray-core` / `sing-box` / `mihomo` etc., manages unlimited profiles, subscriptions, routing, DNS, TUN/system-proxy, latency/speed tests and QR share from one tray app.
    - HOW: `ServiceLib` holds all business logic (ViewModels, `Handler/ConfigHandler`, `Handler/CoreHandler`, `Services/CoreConfig/*`); `v2rayN` (WPF, `UseWPF`, `MaterialDesignThemes`, target `net10.0-windows`) and `v2rayN.Desktop` (Avalonia 12, `Semi.Avalonia`) are thin shells consuming ServiceLib. Core process launched via `CoreHandler.RunProcess()` with `"{coreExe} run -c {configPath}"`; GUI writes `guiNConfig.json` + `bin/config.json` then watches stdout/stderr.
    - FILE: `README.md:1-15` tagline "A GUI client for Windows, Linux and macOS, support Xray and sing-box and others"; `v2rayN/v2rayN.csproj:5-17` `net10.0-windows` + `UseWPF`; `v2rayN.Desktop/v2rayN.Desktop.csproj:7-26` Avalonia; `ServiceLib/Handler/CoreHandler.cs:1-80` `CoreHandler`/`LoadCore()`/`CoreStart()`; `ServiceLib/Handler/CoreConfigHandler.cs:18-55` `GenerateClientConfig()` dispatch.

- **License GPL-3.0-only:**
  - HOW: `LICENSE` is verbatim GPL-3.0 (674 lines, 34.3 KB); GitHub badge `GPL-3.0`; forks inherit copyleft. Distributing modified binary without source violates license — same enforcement note as Nekoray/NekoBox. `LICENSE:1-20` preamble; repo `About` → Resources → GPL-3.0; `README.md` shields include GPL badge.
  - FILE: `LICENSE:1-674`; `README.md` footer `GPL-3.0 license`; `v2rayN/ServiceLib/ServiceLib.csproj:1-10` package metadata.

- **C# .NET, dual GUI:**
  - HOW: .NET 8/10 SDK (7.24.x branch targets `net10.0-windows` on WPF; build requires VS 2022 17.8+ or `dotnet` 8+ SDK; `global.json` pins `Microsoft.Testing.Platform`). ServiceLib is netstandard-compatible library shared by both UIs; reactive UI uses `ReactiveUI 24` (bumped in 7.24.8). Packaging scripts `package-debian.sh`, `package-rhel.sh`, `package-osx.sh`, `package-debian-loong.sh` produce `.deb/.rpm/.dmg/.zip`.
  - FILE: `global.json:1-5` runner `Microsoft.Testing.Platform`; `v2rayN/v2rayN.csproj:5` `TargetFramework net10.0-windows`; `v2rayN.Desktop/v2rayN.Desktop.csproj:7-11` Avalonia 12; `package-debian.sh:1-40`; `package-osx.sh:1-30`; release notes 7.24.8: "Desktop 版本升级到 Avalonia 12, 更新 ReactiveUI 至大版本 24".

- **Win-only heritage → cross-platform since v6/v7:**
  - HOW: Original v2rayN (2018–v5.x) was Windows-only WPF. v6 introduced Linux/macOS via Avalonia Desktop + `bin/` per-arch cores + `chmod +x` on non-Windows (`CoreHandler.Init()` does `SetLinuxChmod` for each `CoreExes`). Docs now show matrices for Windows x64/x86/arm64, Linux x64/arm64/riscv64/loong64, macOS x64/arm64.
  - FILE: `README.md#Supported Platforms` table; `Wiki/Release-files-introduction:1-80` `v7.x` matrix; `ServiceLib/Handler/CoreHandler.cs:30-60` `Utils.IsNonWindows()` + `SetLinuxChmod`.

- **Stars/popularity (~115k):**
  - HOW: Top-3 proxy GUIs on GitHub by stars (alongside Clash Verge, sing-box). 114.9k stars / 15.8k forks / 943 watchers (snapshot 2026-08-30 fetch); Downloads shield shows millions cumulative per `releases` assets (e.g., `v2rayN-windows-64.zip` 180k+ on single tag, `linux-64.deb` 6k+ on 7.24.8). Telegram groups >100k members (`t.me/v2rayN`, `t.me/github_2dust` channel).
  - FILE: `README.md` header shields `Release` + `Downloads` + `Telegram`; live fetch `https://github.com/2dust/v2rayN` header; `releases/tag/7.24.8` assets table (10+ arches).

- **Default core posture:**
  - HOW: Ship includes `Xray-core` (+ `sing-box` + `mihomo`) in `bin/` of release zips (`v2rayN-windows-64.zip`, `v2rayN-linux-64.zip` include cores; `v2rayN-windows-64-other-bins.zip` via `2dust/v2rayN-core-bin` for exotic cores). `CoreType` enum selects executable: `Xray` → `wv2ray.exe`/`xray` / `sing_box` → `sing-box` / `mihomo` → `mihomo` / `hysteria2` → `hysteria` etc. If `EnableTun` with `sing_box`, v2rayN waits for core ready (`添加等待 core 就绪` #9632).
  - FILE: `Wiki/List-of-supported-cores:1-30` list; `Wiki/Release-files-introduction:8-15` "发布包中含部分 Core 文件（Xray, sing-box, mihomo）"; `ServiceLib/Enums/ECoreType.cs`; `ServiceLib/Handler/CoreInfoHandler.cs`; `ServiceLib/Models/CoreInfo.cs` `CoreExes[]`.

- **Telemetry / privacy / security note:**
  - HOW: No bundled analytics. Update check hits `api.github.com/repos/2dust/v2rayN/releases` if enabled; subscription fetch uses provider URL with `User-Agent` default `v2rayN/<version>` (customizable via `WebDavItem` / `CheckUpdateItem`). 7.23.4+ emergency fix: built-in downloader MITM patched (#9703) — old versions could be hijacked via ISP/CDN mirror to deliver malicious core; all users urged upgrade. GPG signatures shipped since 7.23.4 (`*.sig`, fingerprint `7694 5E9F...AE90 3AE0` in README).
  - FILE: `README.md#GPG Verification` fingerprint; `releases/tag/7.24.8` notes "紧急安全更新：修复旧版本内置下载器可能导致中间人攻击（MITM）"; `releases/tag/7.23.4` changelog #9703/#9608; `ServiceLib/Handler/UpdateHandler.cs` / `DownloadHandle.cs`.

---

## 2. Supported Protocols — Deep Dive

> All protocols are first parsed into `ProfileItem` (`EConfigType`) then rendered to **Xray JSON** (`CoreConfigV2rayService`) or **sing-box JSON** (`CoreConfigSingboxService`) depending on `GetCoreType(node, configType)`.

- **VMess (Xray `vmess`):**
  - Legacy V2Ray VMess AEAD (uuid + `alterId=0` enforced, `security:auto/aes-128-gcm/chacha20-poly1305`, `network` + `tls`).
    - HOW: Share `vmess://base64(json)` → `VMessFmt.Resolve()` / `V2rayFmt.ResolveFull()` → `ProfileItem{ConfigType=VMess, Address, Port, Id, AlterId, Security, Network, HeaderType, Host, Path, Tls, Sni, Alpn, Fingerprint}`. Builder emits Xray `outbounds:[{protocol:"vmess", settings:{vnext:[{address,port,users:[{id,alterId,security,level}]}]}, streamSettings:{network,tlsSettings,wsSettings,...}}]` ; sing-box path emits `{"type":"vmess","server", "uuid", "security", "alter_id":0, "tls":{...}}`.
    - FILE: `ServiceLib/Models/ProfileItem.cs:30-80`; `ServiceLib/Enums/EConfigType.cs:VMess`; `ServiceLib/Handler/CoreConfig/V2ray/V2rayOutboundService.cs:20-60`; `ServiceLib/Services/CoreConfig/Singbox/SingboxOutboundService.cs`.
    - Snippet concept (Xray):
      ```json
      {
        "protocol": "vmess",
        "settings": { "vnext": [{ "address": "1.2.3.4", "port": 443, "users": [{ "id": "uuid", "alterId": 0, "security": "auto", "level": 0 }] }] },
        "streamSettings": { "network": "ws", "security": "tls", "tlsSettings": { "serverName": "example.com", "allowInsecure": false, "fingerprint": "chrome" }, "wsSettings": { "path": "/ray", "headers": { "Host": "example.com" } } }
      }
      ```
  - Transports: `tcp` (with `http` headerType), `ws`, `h2`/`http`, `mkcp`, `quic`, `grpc` (and `xhttp` on Xray 24.09+).

- **VLESS (Xray `vless` — stateless, UUID, `encryption:none`, optional `flow`):**
  - Lightweight successor to VMess; supports `flow: xtls-rprx-vision` / `xtls-rprx-vision-udp443` and `VLESS Encryption` (`encryption: "native"` experimental).
    - HOW: `vless://uuid@host:port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=...&fp=chrome&pbk=...&sid=...&type=tcp#remark` → `VLESSFmt` / `ShareLink`-parser. Builder sets `settings:{address,port,id,flow,encryption,level}` + `streamSettings:{security: "reality"|"tls"|"none", realitySettings:{serverName, fingerprint, publicKey, shortId, spiderX}, tlsSettings, sockopt:{dialerProxy,...}}`. VLESS without `flow` + `tls/reality` is standard TLS proxy; with Vision on `tcp+tls/reality` Xray attempts splice (zero-copy) on Linux for 5-10× throughput.
    - FILE: `ServiceLib/Models/ProfileItem.cs` `Flow`, `Encryption`, `PublicKey`, `ShortId`, `SpiderX`; `Wiki/Description-of-VLESS-share-link.md`; `xtls.github.io/en/config/outbounds/vless.html` (VLESS doc); `ServiceLib/Handler/Fmt/VLESSFmt.cs`.
    - Snippet concept (VLESS-Reality-Vision, Xray):
      ```json
      {
        "protocol": "vless",
        "settings": { "address": "1.2.3.4", "port": 443, "id": "5783a3e7-e373-51cd-8642-c83782b807c5", "encryption": "none", "flow": "xtls-rprx-vision" },
        "streamSettings": { "network": "tcp", "security": "reality", "realitySettings": { "serverName": "www.microsoft.com", "fingerprint": "chrome", "publicKey": "xxxx", "shortId": "0123456789abcdef", "spiderX": "/" } }
      }
      ```
    - VLESS Encryption (new): `encryption: "<base64url>"` derived from `seed` — allows `security:none` even to public address; saves TLS overhead but not censorship-resistant alone. See `xtls.github.io` VLESS Encryption notes.

- **Shadowsocks (Xray `shadowsocks` / sing-box `shadowsocks`):**
  - AEAD ciphers `aes-128-gcm`, `aes-256-gcm`, `chacha20-poly1305`, `xchacha20-poly1305`, `2022-blake3-aes-128-gcm` etc.; SIP002 `ss://base64(method:password@host:port)#name`.
    - HOW: `ss://` → `ShadowSocksFmt.Resolve()` → `ProfileItem{Method, Password}`. Xray: `{"protocol":"shadowsocks","settings":{"servers":[{"address","port","method","password","level", "ivCheck", "uot":true}]}}` with optional `streamSettings` multiplex (`xudp`). sing-box: `{"type":"shadowsocks","method","password", "plugin":...}` ; SS 2022 needs `server_key`. XUDP note: Socks/SS UDP uses native path unless `xudp` enabled → otherwise TLS/Reality not applied to UDP.
    - FILE: `ServiceLib/Handler/Fmt/ShadowSocksFmt.cs`; `xtls.github.io/en/config/outbounds/shadowsocks.html`; `xtls.github.io/en/config/transport.html#xudp`.
    - Snippet concept (Xray SS):
      ```json
      { "protocol": "shadowsocks", "settings": { "servers": [{ "address": "1.2.3.4", "port": 8388, "method": "aes-256-gcm", "password": "pass", "ota": false, "level": 0 }] }, "streamSettings": { "network": "tcp", "security": "none" } }
      ```
  - Limitations: `ss` with `plugin` (`obfs-local`, `v2ray-plugin`) deprecated in Xray; prefer sing-box/mihomo for plugin.

- **Trojan (Xray `trojan`):**
  - TLS-wrapped `password` auth; `trojan://password@host:port?sni=...&type=ws&alpn=h2#name`.
    - HOW: `TrojanFmt.Resolve()` → `ProfileItem{Password, Sni, Alpn, Fingerprint, Network, Path}`. Xray: `{"protocol":"trojan","settings":{"servers":[{"address","port","password","level", "flow":""}]}}` (no `flow` — XTLS Vision is VLESS-only) + `streamSettings:{security:"tls"/"reality", tlsSettings:{serverName, alpn, fingerprint}}`. Must not use `allowInsecure` (removed in 7.24.8 / Xray 25.x).
    - FILE: `ServiceLib/Handler/Fmt/TrojanFmt.cs`; `xtls.github.io/en/config/outbounds/trojan.html`.
    - Snippet concept:
      ```json
      { "protocol": "trojan", "settings": { "servers": [{ "address": "1.2.3.4", "port": 443, "password": "pwd", "email": "love@xray.com" }] }, "streamSettings": { "network": "tcp", "security": "tls", "tlsSettings": { "serverName": "example.com", "fingerprint": "chrome" } } }
      ```

- **SOCKS (Xray `socks`):**
  - SOCKS5 (`socks://user:pass@host:port` or `socks://base64(user:pass@host:port)`) — also local inbound `protocol:socks` on `10808`.
    - HOW: Remote SOCKS outbound: `SocksFmt.Resolve()` → `ProfileItem{Username, Password}` → Xray `{"protocol":"socks","settings":{"servers":[{"address","port","users":[{"user","pass","level"}]}]}}`. Local inbound generated by `CoreConfigV2rayService.GenInbounds()` as `{"port":10808,"protocol":"socks","settings":{"auth":"noauth","udp":true,"ip":"127.0.0.1"}}` plus `sniffing` if `RouteOnly`/`SniffingEnabled`.
    - FILE: `ServiceLib/Handler/Fmt/SocksFmt.cs`; `ServiceLib/Services/CoreConfig/V2ray/V2rayInboundService.cs`.

- **HTTP / HTTPUpgrade (Xray `http`):**
  - HTTP proxy (`http://user:pass@host:port`) + Xray `httpupgrade` transport upgrade.
    - HOW: `HttpFmt.Resolve()` → `ProfileItem{Username, Password, Path, Host}`. Xray: `{"protocol":"http","settings":{"servers":[{"address","port","users":[{"user","pass"}]}]}}`. When `network=httpupgrade`, `streamSettings:{network:"httpupgrade", httpupgradeSettings:{path, host}}` combined with `security:tls/reality`.
    - FILE: `ServiceLib/Handler/Fmt/HttpFmt.cs`; `xtls.github.io/en/config/outbounds/http.html`; `xtls.github.io/en/config/transports/httpupgrade.html`.
    - Custom outbound header support added 7.23.4 (#9690): Xray `http` outbound `headers` field.

- **Hysteria2 / Hy2 (Xray `hysteria` v2 / sing-box `hysteria2`):**
  - QUIC-based, `hysteria2://auth@host:port?sni=...&insecure=0&obfs=salamander&obfs-password=...&pinSHA256=...#name`; also `hy2://`.
    - HOW: `Hysteria2Fmt.ResolveFull2()` (note file named `Hysteria2Fmt`) parses `auth` (password), `obfs`, `pinSHA256`, `sni`. Xray `CoreType==Xray` → `ECoreType.Xray` supports `hysteria` with `version:2` in `streamSettings.hysteriaSettings` + `tlsSettings` (since Xray splits `address` in `settings` and `hysteriaSettings` in `streamSettings` — sing-box keeps one block). For sing-box, `CoreConfigSingboxService` emits `{"type":"hysteria2","server","server_port","password","tls":{...},"obfs":...}` with `up_mbps/down_mbps`. Hy2 ECH added 7.24.8; `Realm & Gecko` params #9516.
    - FILE: `ServiceLib/Handler/Fmt/Hysteria2Fmt.cs` (`ResolveFull2`); `ServiceLib/Enums/EConfigType.cs:Hysteria2`; `ServiceLib/Models/ProfileItem.cs` `HysteriaItem{UpMbps,DownMbps}`; `xtls.github.io/en/config/outbounds/hysteria.html`; `sing-box` docs `hysteria2`.
    - Snippet concept (Xray hy2):
      ```json
      { "protocol": "hysteria", "settings": { "version": 2, "address": "1.2.3.4", "port": 443, "auth": "pass" }, "streamSettings": { "security": "tls", "tlsSettings": { "serverName": "example.com" }, "hysteriaSettings": { "version": 2, "auth": "pass", "upMbps": 100, "downMbps": 100, "obfs": "salamander", "obfsParam": "..." } } }
      ```
    - Note: `overtls`, `anytls` experimental via custom config; hy2 is first-class since ~7.19.

- **TUIC (sing-box `tuic` v5, optional external `tuic` core):**
  - QUIC TUIC `tuic://uuid:password@host:port?congestion_control=bbr&udp_relay_mode=native&alpn=h3&sni=...#name`.
    - HOW: `TUICFmt.Resolve()` → `ProfileItem{Uuid, Password, Alpn, CongestionControl}`. If `CoreType==sing_box`, `SingboxOutboundService` emits `{"type":"tuic","server","server_port","uuid","password","congestion_control","udp_relay_mode","tls":{...}}`. Xray does NOT natively support TUIC — v2rayN routes TUIC nodes via sing-box core type (per-profile `CoreType` override).
    - FILE: `ServiceLib/Handler/Fmt/TUICFmt.cs`; `Wiki/List-of-supported-cores` `tuic core https://github.com/EAimTY/tuic/releases`.

- **WireGuard (Xray `wireguard` outbound / sing-box `wireguard` endpoint):**
  - `wireguard://` / `wg://` style + Clash `wireguard:` YAML; uses `secretKey`/`privateKey`, `address` (local tun IPs), `peers:[{endpoint, publicKey, preSharedKey, allowedIPs, keepAlive}]`, `mtu`, `reserved`, `noKernelTun`, `workers`, `domainStrategy`.
    - HOW: `WireGuardFmt.Resolve()` → `ProfileItem{SecretKey, PublicKey, PreSharedKey, LocalAddress, Peers, Mtu, Reserved}`. Xray outbound note: does NOT use `streamSettings` — WireGuard is own encrypted tunnel (fixed UDP sig → blocking risk; advise Reality in front or use `Custom Outbound` chaining). UI exposes `WireGuard 远程 DNS 支持` #10036 (7.24.8).
    - FILE: `ServiceLib/Handler/Fmt/WireGuardFmt.cs`; `xtls.github.io/en/config/outbounds/wireguard.html`; `sing-box` `wireguard` outbound docs (deprecated in sing-box 1.11).
    - Snippet concept (Xray):
      ```json
      { "protocol": "wireguard", "settings": { "secretKey": "PRIVATE_KEY", "address": ["10.0.0.1/32","fd59:...:1/128"], "peers": [{ "endpoint": "1.2.3.4:51820", "publicKey": "PUB", "allowedIPs": ["0.0.0.0/0"], "keepAlive": 25 }], "mtu": 1420, "workers": 2 } }
      ```

- **Others / escape hatches:**
  - **Custom (Xray `custom`)**: raw JSON in `ProfileItem.Address` (path to file) — `CoreConfigHandler.GenerateClientCustomConfig()` just copies file to `bin/config.json` (`File.Copy(addressFileName, fileName)`). HOW: Add server → type `Custom` → fill `Address` with JSON/YAML path; core type auto `Xray`/`mihomo`.
  - **AnyTLS / ShadowQUIC / OverTLS / Brook / Juicity**: supported via external cores listed in `Wiki/List-of-supported-cores` (`overtls`, `shadowquic`, `brook`, `juicity`). HOW: `CoreInfo` entries with `CoreExes` + `Arguments="run -c {0}"`; `ECoreType` enum `Overtls`, `Shadowquic` etc.; `AppHandler.GetCoreType()` maps `EConfigType` → `ECoreType`.
  - FILE: `ServiceLib/Handler/CoreConfigHandler.cs:22-45` switch `node.ConfigType==Custom` → `mihomo` vs generic; `ServiceLib/Enums/ECoreType.cs`; `ServiceLib/Enums/EConfigType.cs`.

---

## 3. Transports / Encryption — Deep Dive

> Transport (`network`/`method`) + security (`security`) are orthogonal in Xray. v2rayN exposes them per-profile in `TransportExtra` / `StreamSettings`.

- **TCP (raw):**
  - Unwrapped TCP; optional `headerType:http` disguises as HTTP. Default for VLESS Reality/Vision.
    - HOW: `streamSettings:{network:"tcp", tcpSettings:{header:{type:"none"/"http", request:{...}, response:{...}}}}`. Reality+Vision over `tcp` enables `splice` (Linux `sendfile`-like zero-copy) if inbound is `dokodemo/socks/http` and kernel supports. Fragment (`Fragment4RayItem`) adds TLSHello fragmentation since 7.23.4 (`添加全局分片 Fragment 设置` #9597).
    - FILE: `ServiceLib/Models/TransportExtraItem.cs`; `ServiceLib/Models/Fragment4RayItem.cs:Packets="tlshello", Length="50-100", Interval="10-20"`; `xtls.github.io/en/config/transports/raw.html`.

- **mKCP:**
  - UDP-based KCP with `mtu/tti/uplinkCapacity/downlinkCapacity/congestion/readBuffer/writeBuffer/headerType/seed`.
    - HOW: `streamSettings:{network:"kcp", kcpSettings:{mtu:1350, tti:50, uplinkCapacity:12, downlinkCapacity:100, congestion:false, seed:"..."} }`. Initialized in `ConfigHandler.LoadConfig()` as `KcpItem{Mtu=1350, Tti=50, Uplink=12, Downlink=100}` if missing. Rarely used now (WS/gRPC preferred).
    - FILE: `ServiceLib/Handler/ConfigHandler.cs:70-85` `KcpItem` defaults; `xtls.github.io/en/config/transports/mkcp.html`.

- **WebSocket (WS):**
  - `ws` with `path` + `host` (`headers.Host`), optional `maxEarlyData`, `earlyDataHeaderName`.
    - HOW: `wsSettings:{path:"/ray", headers:{Host:"example.com"}, maxEarlyData:2048, earlyDataHeaderName:"Sec-WebSocket-Protocol"}`. Works with `security:tls` (WS+TLS often as CDN-friendly). Browser compat high.
    - FILE: `xtls.github.io/en/config/transports/websocket.html`; `ServiceLib/Models/WsItem.cs`.

- **HTTP/2 (h2) / HTTPUpgrade:**
  - `h2`: multiplexed HTTP/2 `host` + `path`; `httpupgrade`: WebSocket-like upgrade over HTTP/1.1 (new, `httpupgradeSettings:{path, host}`).
    - HOW: `streamSettings:{network:"h2", httpSettings:{path:"/", host:["example.com"]}}` ; `httpupgradeSettings:{path:"/upgrade?ed=2048"}`. `h2` requires `security:tls` (h2c not widely proxied). Xray 7.24+ both use `method` naming in `transport.html` (old `network` alias kept).
    - FILE: `xtls.github.io/en/config/transports/httpupgrade.html`; `Config docs: httupgrade`.

- **gRPC (gun):**
  - `grpc` with `serviceName`, `multiMode`, `idleTimeout`, `healthCheckTimeout`, `permitWithoutStream`, `initialWindowsSize`.
    - HOW: `grpcSettings:{serviceName:"GunService", multiMode:false, idle_timeout:60, health_check_timeout:20, permit_without_stream:false, initial_windows_size:0}`. `ConfigHandler` defaults `GrpcItem{IdleTimeout=60, HealthCheckTimeout=20}` (`ConfigHandler.cs:85-95`). Good for CDN/gRPC gateway traversal; Reality supports `grpc` too.
    - FILE: `ServiceLib/Models/GrpcItem.cs`; `xtls.github.io/en/config/transports/grpc.html`.

- **QUIC:**
  - QUIC transport for VMess/VLESS/Trojan (less common); `quicSettings:{security:"none/aes-128-gcm/chacha20-poly1305", key:"", header:{type:"none/srtp/utp/wechat-video/dtls/wireguard"}}`.
    - HOW: Xray quicSettings header obfuscates QUIC initial. v2rayN UI maps `quicSecurity`/`quicKey`/`headerType`. QUIC+TLS is redundant — usually `security:none` + `quicSecurity`.
    - FILE: `xtls.github.io/en/config/transports/quic.html` (legacy).

- **XHTTP / SplitHTTP (new, Reality successor transport):**
  - `xhttp` — beyond Reality; `xhttpSettings:{path, host, headers, scMaxBufferedPosts, xPaddingBytes, mode:"auto"|"packet-up"|"stream-up"|"stream-one", extra:{...}}`.
    - HOW: Xray `method:"xhttp"` (new `transport.html` terminology) replaces `network` for XHTTP. Reality now pairs primarily with `raw`/`xhttp`/`grpc` (see `transport.html` compatibility matrix). v2rayN 7.24+ syncs Xray core changes: `Xray Core 中移除 allowInsecure` (now use `insecure` or ECH). XHTTP aims to eliminate TLS-in-TLS fingerprint while allowing HTTP semantics (`mode:packet-up` etc.).
    - FILE: `xtls.github.io/en/config/transports/xhttp.html` (title "XHTTP: Beyond REALITY"); `releases/tag/7.24.8` notes "同步 xray core 更改"; `xtls.github.io/en/config/transport.html` compatibility table.

- **TLS:**
  - Standard TLS 1.2/1.3 with `serverName (SNI)`, `alpn:["h2","http/1.1"]`, `fingerprint` (uTLS), `allowInsecure/insecure`, `pinSHA256`, `ech`, `minVersion/maxVersion`, `cipherSuites`.
    - HOW: `streamSettings:{security:"tls", tlsSettings:{serverName:"example.com", alpn:["h2","http/1.1"], fingerprint:"chrome", allowInsecure:false, show:false}}`. v2rayN exposes `Sni`, `Alpn`, `Fingerprint` per profile; 7.24.8 removes `allowInsecure` flag (Xray removed it) — use `insecure` if needed via custom JSON. ECH support added for hy2 in 7.24.8.
    - FILE: `xtls.github.io/en/config/transports/tls.html`; `ServiceLib/Models/ProfileItem.cs` `Sni`, `Alpn`, `Fingerprint`; `releases/tag/7.24.8` "Xray Core 中移除 allowInsecure".

- **Reality (most important):**
  - Modified TLS that steals target site's handshake + cert camouflage; client gets `temporary trusted certificate` signed by temporary key; server steers to `dest: example.com:443`.
    - HOW: Server `realitySettings:{show:false, dest:"example.com:443", xver:0, serverNames:["example.com","www.example.com"], privateKey:"<x25519>", shortIds:["","0123456789abcdef"], minClientVer/maxClientVer, mldsa65Seed, limitFallbackUpload/Download}`. Client `realitySettings:{serverName:"example.com", fingerprint:"chrome", publicKey:"<derived>", shortId:"...", spiderX:"/", mldsa65Verify, show:false}`. Only compatible with `raw|xhttp|grpc` (not `ws/h2/mkcp`). Vision flow (`xtls-rprx-vision`) + Reality is recommended for 5-10× speed via splice. Post-quantum `X25519MLKEM768` auto-negotiated if target supports (check `xray tls ping example.com`); needs larger `target` cert to avoid fingerprint. `shortId` 0-16 hex chars, even length.
    - FILE: `xtls.github.io/en/config/transports/reality.html`; `XTLS/Xray-examples VLESS-TCP-XTLS-Vision-REALITY/REALITY.ENG.md`; `releases/tag/7.24.8` hy2 ECH + realityNotes.
    - Snippet (client Reality):
      ```json
      { "streamSettings": { "network": "tcp", "security": "reality", "realitySettings": { "show": false, "fingerprint": "chrome", "serverName": "www.microsoft.com", "publicKey": "abcd...", "shortId": "6ba...", "spiderX": "/" } } }
      ```

- **uTLS fingerprint (client Hello mimic):**
  - `fingerprint: chrome / firefox / safari / ios / android / edge / 360 / qq / random / randomized / none` via Go `uTLS` lib.
    - HOW: Xray `tlsSettings.fingerprint` / `realitySettings.fingerprint` → uTLS `ClientHelloID`. v2rayN dropdown `Fingerprint` per profile; default `chrome` (most common, safest). `random` picks per-handshake; `randomized` adds jitter. Must match real browser distribution to avoid active probing flag. Transport `realitySettings.fingerprint` is **required** on client side.
    - FILE: `xtls.github.io/en/config/transports/tls.html#tlsobject` + `reality.html`; `ServiceLib/Models/ProfileItem.cs` `Fingerprint`; `VLESS share link spec` `fp=chrome`.

- **Hysteria `hysteriaSettings` (QUIC wrapper, not streamSecurity):**
  - Own transport-security (TLS inside QUIC) — must be `security:tls` (Hysteria `security:none` not supported; `Required` in matrix).
    - HOW: `streamSettings:{security:"tls", hysteriaSettings:{version:2, auth, upMbps, downMbps, obfs}}` for Xray; sing-box `hysteria2.tls`. Brisk congestion via `BBR` kernel path.

- **FinalMask / Sockopt extras:**
  - `finalmask` (fragment mask) + `sockopt:{domainStrategy, dialerProxy, tcpFastOpen, tcpKeepAlive, mark, interface, happyEyeballs, ...}`.
    - HOW: `sockopt.domainStrategy: AsIs|IPIfNonMatch|IPOnDemand` (see Routing); `dialerProxy` implements proxy chain (`前置代理` via `CoreConfigContextBuilder.ResolveNodeAsync` → `PreSocksPort`); `happyEyeballs` added 7.24.8 (#9772) for dual-stack racing; `tcpFastOpen`/`mark` for policy routing.
    - FILE: `xtls.github.io/en/config/transports/sockopt.html`; `xtls.github.io/en/config/transports/finalmask.html`; `ServiceLib/Services/CoreConfig/V2ray/V2rayDnsService.cs FillSockoptDomainStrategy()`.

---

## 4. Cores Matrix — Xray vs sing-box vs Mihomo vs Others

- **Xray-core (default, `ECoreType.Xray`):**
  - Fork of `v2fly/v2ray-core` by `XTLS` (creator `RPRX`). Most feature-complete for VLESS Reality/Vision/XHTTP, VMess AEAD, Mux/XUDP, Observatories, Fragment, Noises.
    - HOW: Executable `bin/Xray/xray` (Windows `xray.exe` / `wv2ray.exe` aliased via `CoreInfo.CoreExes`). Config format JSON (`config.json` / `configPre.json`). v2rayN `AppHandler.GetCoreType(node, configType)` → `Xray` if `EConfigType` in `Global.XraySupportConfigType` (VMess, VLESS, Trojan, SS, Socks, HTTP, WireGuard, Custom). Handles both inbound (`socks:10808`, `http` if enabled, `tun` if `EnableTun`) and routing/dns generation via `CoreConfigV2rayService`.
    - FILE: `Wiki/List-of-supported-cores#V2ray 系列` `Xray core https://github.com/XTLS/Xray-core/releases`; `ServiceLib/Handler/CoreInfoHandler.cs`; `ServiceLib/Enums/ECoreType.cs:Xray`; `ServiceLib/Global.cs:XraySupportConfigType`; `ServiceLib/Services/CoreConfig/V2ray/CoreConfigV2rayService.cs`.

- **sing-box (`ECoreType.sing_box`):**
  - Universal proxy platform by `SagerNet` (`nekohasekai`). Good TUN, WireGuard endpoint, Hysteria2/TUIC/AnyTLS, rule-sets.
    - HOW: `bin/sing_box/sing-box` (`sing-box.exe`). Config JSON with `inbounds:[{type:"mixed"/"tun", ...}]`, `outbounds:[{type:"vless"/"hysteria2"/...}]`, `route:{rules, rule_set}`, `dns:{servers, rules}`. v2rayN selects sing-box if profile `CoreType==sing_box` OR test contains hy2/tuic (`CoreHandler.LoadCoreConfigSpeedtest()` picks `sing_box` if `EConfigType.Hysteria2 or TUIC`). Pre-service concept: `CoreHandler.CoreStartPreService()` may launch a `sing-box` relay + Xray chain for TUN startup deadlock workaround (#8870 report).
    - FILE: `Wiki/List-of-supported-cores#sing_box 系列`; `ServiceLib/Handler/CoreHandler.cs:80-120` `LoadCoreConfigSpeedtest` coreType selection; `CoreHandler.CoreStartPreService()` + `GetPreSocksItem()`; `ServiceLib/Services/CoreConfig/Singbox/*` (SingboxRoutingService, SingboxDnsService, SingboxInboundService, SingboxOutboundService).

- **mihomo (`ECoreType.mihomo`, Clash Meta):**
  - `MetaCubeX/mihomo` (Clash Meta) — Clash YAML (`config.yaml`) ecosystem, full rule-providers, proxy-groups.
    - HOW: `bin/mihomo/mihomo` (alias `clash`). Custom config path: `CoreConfigHandler.GenerateClientCustomConfig()` with `ECoreType.mihomo` → `CoreConfigClashService.GenerateClientCustomConfig()` copies YAML. Subscription supports Clash YAML natively (see Subscription section). `sing-box-rules` vs `v2ray-rules-dat` distinction in `Wiki/List-of-supported-cores#GEO`.
    - FILE: `Wiki/List-of-supported-cores#Clash 系列` `mihomo core`; `ServiceLib/Handler/CoreConfigHandler.cs:22-35` `case ECoreType.mihomo => CoreConfigClashService`; `ServiceLib/Services/CoreConfig/Clash/CoreConfigClashService.cs`.

- **hysteria2 core (standalone `hysteria`):**
  - `apernet/hysteria` binary for native `hysteria2://` (when not using Xray/sing-box's built-in).
    - HOW: `bin/hysteria/hysteria`; `CoreInfo` `CoreType==Hysteria2`. Some nodes force external core via `ProfileItem.CoreType` override. Arguments `{"server","port","auth","tls","obfs"}` mapped via `Hysteria2Fmt`.

- **Other externals:**
  - `naiveproxy` (`klzgrad/naiveproxy`), `tuic` (`EAimTY/tuic`), `juicity` (`juicity/juicity`), `brook` (`txthinking/brook`), `overtls` (`ShadowsocksR-Live/overtls`), `shadowquic` (`spongebob888/shadowquic`).
    - HOW: Each gets a `CoreInfo` entry with `CoreType` enum + `CoreExes` + `Arguments` template. Downloaded via `CoreInfoHandler` / `CheckUpdateViewModel` on demand (not bundled except Xray/sing-box/mihomo). Path `bin/{CoreType}/` (e.g., `bin/hysteria/hysteria.exe`, `bin/tuic/tuic.exe`).
    - FILE: `Wiki/List-of-supported-cores#Others 其他` full list; `ServiceLib/Enums/ECoreType.cs` enum (Xray, sing_box, mihomo, Hysteria2, Naive, TUIC, Juicity, Brook, Overtls, Shadowquic, v2rayN).

- **How core selection works per profile (coreType):**
  - Per-node `ProfileItem.CoreType` (nullable `ECoreType?`) overrides global default; `AppHandler.GetCoreType(node, configType)` resolves: if `node.CoreType != null` → that; else if `configType` in `XraySupportConfigType` → `Xray`; else if hy2/tuic grouping → `sing_box`; else if custom + mihomo YAML → `mihomo`.
    - HOW: UI: `Edit Server → Core Type` dropdown. Storage: `ProfileItem.CoreType` in SQLite `ProfileItem` table (via `SqliteHelper`). Runtime: `CoreHandler.LoadCore(node)` → `AppHandler.GetCoreType` → `CoreInfoHandler.GetCoreInfo(coreType)` → `GetCoreExecFile()` → `RunProcess(coreInfo, configPath)`. Speedtest similarly picks coreType for test concurrency. TUN mode couples: Xray TUN (`tun` inbound) or sing-box TUN (`tun` inbound) depending on chosen core; 7.23.4 note "xray tun 可用于 linux 和 macos，注意 xray core 要最新版" (#9632).
    - FILE: `ServiceLib/Models/ProfileItem.cs:CoreType`; `ServiceLib/Handler/AppHandler.cs:GetCoreType()`; `ServiceLib/Enums/ECoreType.cs`; `ServiceLib/Handler/CoreInfoHandler.cs:GetCoreInfo()`; `ServiceLib/Handler/CoreHandler.cs:60-90` `LoadCore()`/`CoreStart()`; `Wiki/Description-of-some-parameters.md` `CoreType` docs.

- **Handling via `v2rayN/bin/{CoreType}`:**
  - Directory layout portable `zip` vs installed `deb/rpm/dmg`.
    - HOW: Portable `zip`: `v2rayN.exe` alongside `bin/Xray/xray.exe`, `bin/sing_box/sing-box.exe`, `bin/mihomo/mihomo.exe`, `geoip.dat`, `geosite.dat`, `srss/*.srs`, `guiNConfig.json`, `guiNDB.db`, `config.json` (generated). Installed Linux (`/opt/v2rayN` or `~/.local/share/v2rayN` depending on `LocalAppData` env `1`) copies `bin/` via `CoreHandler.Init()` `FileManager.CopyDirectory(fromPath=GetBaseDirectory("bin"), toPath=GetBinPath(""))`. Env vars set: `V2RayLocationAsset` / `XrayLocationAsset` / `XrayLocationCert` → `Utils.GetBinPath("")` so cores find `geo*` even when CWD is elsewhere. Linux `chmod +x` via `SetLinuxChmod()` for each `CoreExes`.
    - FILE: `ServiceLib/Handler/CoreHandler.cs:18-45` `Init()` env vars + copy + chmod; `ServiceLib/Utils.cs:GetBinPath()`, `GetConfigPath()`, `GetBaseDirectory()`; `Wiki/Release-files-introduction` layout `bin` folder note; `.github/workflows/*.yml` packaging.

---

## 5. Subscription Formats

> v2rayN calls subscriptions "订阅" — one URL returns many nodes (base64 batch or Clash YAML). Managed in `SubItem` + `ProfileItem.Subid`.

- **General subscription behavior:**
  - HOW: `Subscription → Add` → `SubItem{Remarks, Url, Enabled, Filter, Sort}`. Fetch via `SubHandler.UpdateSub()` with `HttpClient` (honors `PreSocksPort` if update via proxy enabled, and `User-Agent`). Response detected: if HTML → fail -1; if `vmess/vless/ss/trojan/hy2/tuic` batch (base64 lines or `://` lines) → `ConfigHandler.AddBatchServers()` loop `ResolveFull()` per line; if `ClashFmt.IsClashConfig()` (yaml `proxies:`/`proxy-providers:`) → `ClashFmt.ResolveFull()` → multiple `ProfileItem`s with same `Subid`. Dedup via `IndexId`. Manual update interval via `CheckUpdateItem`.
  - FILE: `ServiceLib/Handler/ConfigHandler.cs:120-180` `AddBatchServers`/`AddCustomServer`; `ServiceLib/Handler/Fmt/*Fmt.cs` resolvers; `ServiceLib/Models/SubItem.cs`; `Wiki/Description-of-subscription.md`.

- **vmess://**
  - Standard: `vmess://base64(json)` where json `{v:"2", ps:"remark", add:"host", port:"443", id:"uuid", aid:"0", net:"ws", type:"none", host:"example.com", path:"/ray", tls:"tls", sni:"", alpn:"", fp:"chrome"}`. Also V2RayN's `vmess://` alt `vmess://uuid@host:port?...`? Primary is base64 json.
    - HOW: `VMessFmt.Resolve()` decodes base64 → json → `ProfileItem`. Wiki page `Description-of-VMess-share-link` details fields.
    - FILE: `Wiki/Description-of-VMess-share-link.md`; `ServiceLib/Handler/Fmt/VMessFmt.cs`.
    - Example concept: `vmess://eyJ2IjoiMiIsInBzIjoiVjJTZXJ2ZXIiLCJhZGQiOiIxLjIuMy40IiwicG9ydCI6IjQ0MyIsImlkIjoi...` (contains `net:ws`, `tls:tls`).
  - Internal variant: `v2rayn://vmess/base64_urlsafe(ProfileItemDtoJson)` — full DTO backup preserving `IndexId`, `CoreType`, `ProtoExtraObj`.

- **vless://**
  - Standard: `vless://uuid@host:port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=example.com&fp=chrome&pbk=xxxx&sid=yyyy&spx=%2F&type=tcp#Remark` (query keys: `encryption`, `flow`, `security`, `sni`, `fp`, `pbk`, `sid`, `spx`, `type`, `host`, `path`, `serviceName`, `alpn`, `headerType`, `seed`).
    - HOW: `VLESSFmt.ResolveFull()` parses URI via `System.Uri` → query dict → `ProfileItem{Id, Flow, Encryption, Sni, Fingerprint, PublicKey, ShortId, SpiderX, Network, Host, Path}`. Reality required keys `pbk` (publicKey) + `sid`. Docs: `Wiki/Description-of-VLESS-share-link.md` lists each param mapping.
    - FILE: `Wiki/Description-of-VLESS-share-link.md`; `ServiceLib/Handler/Fmt/VLESSFmt.cs`.
    - Example concept: `vless://05a6a8cb-b2be-42fd-90b1-0fe23adb9576@v2rayn.2dust.link:443?encryption=none&flow=xtls-rprx-vision&security=tls&sni=v2rayn.2dust.link&fp=chrome&type=tcp#VLESSXTLS`

- **ss:// (SIP002):**
  - `ss://base64(method:password)@host:port#remark` or `ss://base64(method:password@host:port)#remark`; Clash adds `ss://...?plugin=...`.
    - HOW: `ShadowSocksFmt` handles both `ss://` variants (checks `@` position). Clash YAML `type: ss` → same bean.
    - FILE: `ServiceLib/Handler/Fmt/ShadowSocksFmt.cs`; `sing-box` ss docs.

- **trojan://**
  - `trojan://password@host:port?sni=example.com&alpn=h2,http/1.1&fp=chrome&type=tcp#Remark` (also `allowInsecure` legacy removed in 7.24.8 — now just `insecure` via custom JSON).
    - HOW: `TrojanFmt.ResolveFull()` similar to VLESS but `Password` field is auth.

- **socks:// / http://**
  - `socks://base64(user:pass@host:port)` or plain `socks://user:pass@host:port`; `http://user:pass@host:port` (also `https://` relay). Used for upstream chain.
    - HOW: `SocksFmt` / `HttpFmt` parse `userinfo` + `host`/`port`. `PolicyGroup` with `ChildItems` can chain these as `dialerProxy`.

- **clash yaml (Subscription format, not share link):**
  - Whole YAML with `proxies: [{name,type:vmess/vless/ss/trojan/hysteria2/tuic/wireguard, server, port, uuid/cipher/password, network, tls, ws-opts, grpc-opts, reality-opts}]` + `proxy-groups:` + `rules:` (rules ignored by v2rayN — only proxies imported).
    - HOW: `ClashFmt.ResolveFull(strData, subRemarks)` checks `IsClashConfig` (`proxies:` string) → `YamlDotNet` or custom parser → iterate `proxies` list → map each to `ProfileItem` via `ClashFmt.ResolveItem()` (handles `cipher`, `plugin-opts`, `obfs`, `auth-str` etc.). `WireGuard` clash entries map to Xray `wireguard` outbound (since sing-box wireguard deprecated). mihomo custom YAML bypasses import — stored as custom config.
    - FILE: `ServiceLib/Handler/Fmt/ClashFmt.cs:1-120` `ResolveFull` branch `IsClashConfig`; `ServiceLib/Models/ProfileItem.cs`.

- **hysteria2:// / hy2:// / hysteria:// legacy**
  - `hysteria2://auth@host:port?sni=...&obfs=salamander&obfs-password=...&pinSHA256=...&insecure=1#name`.
    - HOW: `Hysteria2Fmt.ResolveFull2()` supports `hysteria2://` and `hy2://`; legacy `hysteria://` without `version=2` warns. Query `obfs`/`obfs-password` mapped to `HysteriaItem.Obfs`. `mport/ports` port-hopping from Clash translated to `Hysteria2Fmt` range.

- **tuic://**
  - `tuic://uuid:password@host:port?congestion_control=bbr&udp_relay_mode=native&alpn=h3&allow_insecure=0&sni=...#name`.
    - HOW: `TUICFmt.Resolve()` parses `uuid:password` userinfo + query `congestion_control`, `alpn`, `sni`. Core forced to `sing_box` if needed.

- **wireguard:// / wg://**
  - Custom `wireguard://privateKey@host:port?publicKey=...&presharedKey=...&address=10.0.0.2/32&allowedIPs=0.0.0.0/0&mtu=1420&keepalive=25&reserved=1,2,3#name` (non-standard — providers use Clash `wireguard:` or `wg://`).
    - HOW: `WireGuardFmt.Resolve()` handles `wireguard://`. Clash `wireguard:` (server, port, private-key, public-key, pre-shared-key, allowed-ips, persistent-keepalive) similarly mapped. UI since 7.24.8 adds `WireGuard 远程 DNS 支持` (remote DNS override) per peer.

- **custom / hysteria (first-gen) / naive / others**
  - `v2rayn://` internal (see below); external cores accept custom JSON file via `Custom` type.
    - HOW: `HysteriaFmt` (v1) still parsed for backward compat but warns to migrate hy1→hy2. `Custom` → no parsing, just file copy.

- **v2rayn:// internal backup/share:**
  - `v2rayn://{ConfigType}/{url-safe-base64(ProfileItemDtoJson)}` where json contains `IndexId, ConfigType, ConfigVersion:4, Remarks, Address, Port, Password, Username, ProtoExtraObj:{ChildItems, MultipleLoad}, CoreType`.
    - HOW: Used for backup/share of **non-standard fields** (policy groups, chain, `DialerProxy`). Unlike `vmess://`/`vless://`, preserves `Flow`, `SpiderX`, `HeaderType`, group `ChildItems` etc. without proposal loss. Resolved in `ConfigHandler.AddBatchServers()` third branch `V2rayNFmt.Resolve()` before html/clash check. Example payloads shown in `Wiki/Description-of-subscription.md` (`http` node + `policygroup` with `ChildItems:"AIy0Iw"` or `SubChildItems:"self", Filter:"example"` regex). Share → `Ctrl+Shift+S` → `Share as v2rayn://`.
    - FILE: `Wiki/Description-of-subscription:20-80` JSON payload spec; `ServiceLib/Handler/Fmt/V2rayNFmt.cs`; `ServiceLib/Models/ProfileItem.cs:ProfileItemDto`.

---

## 6. Routing / Split Tunneling

- **Rule-based routing engine (Xray `routing.rules`):**
  - HOW: Settings → `Routing Settings` manages `RoutingBasicItem{DomainStrategy}` + list `RoutingItem{Remarks, DomainStrategy, RuleSet: JSON array of RulesItem}`. `CoreConfigV2rayService.GenRouting()` serializes: sets `routing.domainStrategy` from `RoutingBasicItem` or per-`RoutingItem` override; iterates `RulesItem` where `Enabled && RuleType != DNS` → `RulesItem4Ray` via `JsonUtils.Deserialize`; calls `GenRoutingUserRule()` to split combined `domain+ip+process` rule into separate `field` type rules (removes `#`-prefixed domains, replaces `RoutingRuleComma`). Adds balancer translation: `outboundTag` ending with `Global.BalancerTagSuffix` → `balancerTag`. Global `domainStrategy` values: `AsIs` (default, use domain as-is), `IPIfNonMatch` (resolve to IP then re-match if no domain hit), `IPOnDemand` (resolve first). See `ServiceLib/Services/CoreConfig/V2ray/V2rayRoutingService.cs:9-73`.
  - FILE: `ServiceLib/Services/CoreConfig/V2ray/V2rayRoutingService.cs:1-73` `GenRouting()`; `ServiceLib/Models/RoutingItem.cs`; `ServiceLib/Models/RulesItem.cs`; `ServiceLib/Global.cs:DomainStrategies`.

- **Presets — bypass LAN / bypass China / global / custom:**
  - HOW: Built-in rule templates shipped as embedded JSON (`ServiceLib/Sample/routing*.json` / `EmbedUtils.GetEmbedText(Global.DNSV2rayNormalFileName)`). Presets: `Bypass LAN` (direct `geoip:private` + `geosite:private`), `Bypass China`/`Bypass LAN + China + Ads` (direct `geoip:cn` + `geosite:cn` + `geosite:category-ads`), `Global` (all proxy), `Whitelist`/ `Blacklist`. UI dropdown `Routing → Routing Settings → Advanced` picks preset then writes `RoutingItem.RuleSet`. User can edit `RuleSet` raw JSON via `Edit Custom Routing Rules` dialog. `Global.FakeIPRanges.First()` default `198.18.0.0/15` (customizable FakeIP range #9786 in 7.24.8) + `::ffff:198.18.0.0/106` for IPv6.
  - FILE: `ServiceLib/Global.cs:RoutingRule*`; `Wiki/Description-of-system-proxy-routing.md` ("系统代理和路由说明"); `Wiki/Description-of-custom-routing-rules.md`; `releases/tag/7.24.8` FakeIP range customizable.
  - Snippet concept (Xray routing.json):
    ```json
    {
      "domainStrategy": "IPIfNonMatch",
      "rules": [
        { "type": "field", "domain": ["geosite:category-ads-all"], "outboundTag": "block" },
        { "type": "field", "domain": ["geosite:cn"], "outboundTag": "direct" },
        { "type": "field", "ip": ["geoip:cn","geoip:private"], "outboundTag": "direct" },
        { "type": "field", "port": "0-65535", "outboundTag": "proxy" }
      ],
      "balancers": []
    }
    ```

- **DomainStrategy detail:**
  - `AsIs` = route using domain sniffed or requested as-is (no extra resolve). `IPIfNonMatch` = after no domain rule hits, resolve domain to IPs then re-evaluate IP rules (Xray does deferred resolve on first IP rule to reduce latency — includes both v4+v6 unless `queryStrategy` filters). `IPOnDemand` = resolve immediately before any matching. When `routeOnly` sniffing + `process` rules, sniff result has higher priority than destination domain.
    - HOW: `RoutingBasicItem.DomainStrategy` stored in `guiNConfig.json`; `V2rayRoutingService.GenRouting()` sets `routing.domainStrategy`; per-outbound `sockopt.domainStrategy` may override for `Freedom` vs `Proxy` via `V2rayDnsService.FillSockoptDomainStrategy()` (patched in 7.24.8 to add `连接代理解析策略` #9708 — separate `Strategy4Freedom`/`Strategy4Proxy`/`Strategy4ProxyDial`).
    - FILE: `ServiceLib/Services/CoreConfig/V2ray/V2rayDnsService.cs:90-140` `FillSockoptDomainStrategy()`; `releases/tag/7.24.8` "添加连接代理解析策略 #9708"; `xtls.github.io/en/config/routing.html#domainstrategy`.

- **geoip / geosite dat + .srs rule-sets:**
  - Data files: `geoip.dat` (~10 MB, routes `geoip:cn`/`geoip:private`), `geosite.dat` (~2 MB, `geosite:cn`/`geosite:google` etc.), plus sing-box `.srs` (`srss/*.srs` — binary rule-set, e.g., `geosite-category-ads-all.srs`, `geoip-cn.srs`).
    - HOW: Sources: `Loyalsoldier/v2ray-rules-dat` (v2ray dat) + `2dust/sing-box-rules` (srs collection). v2rayN updater (`CheckUpdateViewModel`) downloads `geoip.dat`/`geosite.dat` and `*.srs` on `Update Geo Files` click or auto-check. TUN sing-box mode rule-set bug #8870: v2rayN 7.19 generated **remote** `geosite:category-ads-all` (colon, `download_detour:proxy`) alongside correct local `geosite-category-ads-all` (hyphen, `path: srss/...`), causing deadlock where `sing-box` tried to download via proxy that needed `sing-box` to be ready → `FATAL TLS handshake timeout`. Fix is local hyphen tags for DNS rules too.
    - FILE: `Wiki/List-of-supported-cores#GEO` links; `ServiceLib/Handler/UpdateHandler.cs:UpdateGeoFiles()`; `ServiceLib/Services/CoreConfig/Singbox/SingboxRoutingService.cs:51-79` tun + rule-set gen; `issue #8870` full deadlock stack trace.

- **Per-app routing?**
  - Not native per-app proxy toggle, but Xray `process` rule + TUN `process` matcher approximates it.
    - HOW: Xray supports `routing.rules[].process: ["chrome.exe","C:/Program Files/.../firefox.exe"]` (Windows+Linux only, `processName` without `.exe` matches both OS; `/suffix` matches folder). v2rayN `RulesItem{Process: string[]}` maps via `GenRoutingUserRule()` — splits process list into its own field rule (separate from domain/ip). Example: `{ "process": ["chrome.exe"], "outboundTag":"proxy" }` to proxy only Chrome. TUN mode routes all TCP/UDP through sing-box/Xray tun device, then `process` rules inside routing decide direct vs proxy. Limitation: not a GUI per-app switch — you craft custom rule JSON.
    - FILE: `ServiceLib/Services/CoreConfig/V2ray/V2rayRoutingService.cs:95-140` `process` split; `xtls.github.io/en/config/routing.html#ruleobject` `process` field docs; `Wiki/Description-of-custom-routing-rules.md`.

---

## 7. TUN vs System Proxy

- **System Proxy modes (default, no admin):**
  - Two sub-modes under `System Proxy` tray/menu: `Automatic (PAC)` vs `Manual (Global)` + `Clear`.
    - HOW: **PAC** (auto): v2rayN starts an internal HTTP PAC server on `127.0.0.1:{pacPort}` (default tunable) serving `pac.txt`/`pac.js` that returns `PROXY 127.0.0.1:10808` for proxied domains (derived from routing geosite rules) and `DIRECT` for bypass. Then calls Windows `InternetSetOption(INTERNET_OPTION_SETTINGS)` / registry `HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings` → `AutoConfigURL=http://127.0.0.1:port/pac?hash` + `ProxyEnable=1` if global. **Manual**: sets `ProxyServer=127.0.0.1:10808` (socks port) and `ProxyOverride` = `SystemProxyExceptions` (default `<local>;localhost;127.*;10.*;172.16.*;172.17.*...192.168.*;`). `Clear` restores previous settings. Linux uses `gsettings set org.gnome.system.proxy` or `kwriteconfig` depending on DE; macOS via `networksetup -setwebproxy`.
    - FILE: `ServiceLib/Handler/ProxySettingHandler.cs:1-80` `SetProxy()`/`ClearProxy()`; `ServiceLib/Models/SystemProxyItem.cs{SystemProxyExceptions}`; `Wiki/Description-of-system-proxy-routing.md` "系统代理和路由说明"; `ServiceLib/Global.cs:SystemProxyExceptionsWindows/Linux`.
  - DNS in system-proxy: browser DNS still goes via OS resolver → may leak unless `FakeDNS` or DoH override; Xray `dns` inbound `53` rule directs `inboundTag:["tun"] port:53 → dnsOut` only in TUN.

- **TUN mode (system-wide L3, admin/root required):**
  - Creates a virtual TUN interface `xray_tun` / `sing-box tun` that captures all IP packets (incl. non-proxy-aware apps, games, UWP).
    - HOW: UI toggle `TUN Mode` (icon + tray check). `Config.TunModeItem{EnableTun, Mtu:9000, IcmpRouting, EnableLegacyProtect, Stack: "gvisor"|"system"|"mixed", TunAddress="10.0.0.1/30" etc., TunIpv4/TunIpv6 options added 7.24.8}`. Enabling calls `CoreConfigV2rayService.GenRouting()` branch:
      ```csharp
      if (_config.TunModeItem.EnableTun) {
        _coreConfig.routing.rules.Add(new(){ inboundTag:["tun"], port:"53", outboundTag:Global.DnsOutboundTag });
        // + ICMP policies, FakeIP routing, etc.
      }
      ```
      `ServiceLib/Services/CoreConfig/Singbox/SingboxInboundService.cs` generates `{"type":"tun","interface_name":"tun0","inet4_address":"172.19.0.1/30","inet6_address":"fdfe:dcba:9876::1/126","mtu":9000,"auto_route":true,"strict_route":true,"stack":"mixed","include_interface":[], "exclude_interface":[]}`. Windows requires Admin (UAC prompt or `Service Mode`); Linux requires `CAP_NET_ADMIN` or `sudo` (v2rayN does `IsNeedSudo()` → `RunProcessAsLinuxSudo()` via temp shell script). `WindowsUtils.RemoveTunDevice()` called on reload to avoid stale `xray_tun` DNS entries (`netsh interface ip show dnsservers` shows `xray_tun` statically None if leak). 7.23.4 adds `xray tun 可用于 linux 和 macos，注意 xray core 要最新版` (#9632) + wait-for-core-ready handshake when mixing `sing-box tun + xray core`.
    - FILE: `ServiceLib/Models/TunModeItem.cs{Mtu=9000, IcmpRouting}`; `ServiceLib/Services/CoreConfig/V2ray/V2rayRoutingService.cs:9-34` TUN rules; `ServiceLib/Services/CoreConfig/Singbox/SingboxInboundService.cs` + `SingboxRoutingService.cs:51-79` `ICMP` + `TUN` special rules; `ServiceLib/Handler/ConfigHandler.cs:95-105` `TunModeItem` defaults; `ServiceLib/Utils/WindowsUtils.cs:RemoveTunDevice()`; `releases/tag/7.24.8` "TUN 设置中，添加 IPv4/IPv6 地址选项, 无论是否启用 IPv6 始终将 IPv6 路由到 X Ray TUN".

- **Service Mode (Windows helper to avoid per-launch UAC):**
  - HOW: `Service Mode` installs a Windows Service / scheduled task `v2rayNService` (binary `v2rayN.Service.exe` or `EnableService` helper) that runs core + TUN as SYSTEM so main GUI can be normal user. Toggle in `Settings → Service Mode` → prompts UAC once → installs. Clearing service restores per-launch admin. Benefit: survive UAC, allow auto-start with TUN without prompt. Risk: service after uninstall must be manually removed via `sc delete v2rayNService`.
  - FILE: `ServiceLib/Handler/ServiceHandler.cs`; `ServiceLib/Utils/WindowsUtils.cs:InstallService()`; `Wiki/Faq` "如何开启服务模式"; `Wiki/Description-of-some-parameters.md` `EnableService`.

- **TUN vs System Proxy comparison:**
  - System Proxy: per-browser/system-proxy aware only; no admin; leaks for non-proxy apps; faster toggle; PAC allows `geosite`-based auto; DNS leak depends on `dns` routing vs OS resolver. TUN: captures all; needs admin/root + TUN driver (`wintun.dll` on Windows via `xray`/`sing-box` bundled `wintun`, or `tun2socks.exe` legacy path); handles UDP/ICMP; routes DNS via `inboundTag:tun port 53`; heavier, may conflict with VPNs (WireGuard, ZeroTier) that also create TUN.

- **Legacy TUN2Socks path:**
  - Older versions used standalone `tun2socks.exe` (`bin/tun2socks/tun2socks.exe`) as sidecar to forward TUN → SOCKS `10808`. Current sing-box/Xray built-in `tun` inbound supersedes it but fallback remains if `CoreType` missing tun support.
    - HOW: `CoreHandler.IsNeedTun2Socks()` check; if true, launch `tun2socks --tunAddr 10.0.0.1 --tunGw 10.0.0.2 --socksServerAddr 127.0.0.1:10808`.

---

## 8. DNS — Xray dns, Hijack, FakeDNS, DoH

- **Xray `dns` object (core concept, `xtls.github.io/en/config/dns.html`):**
  - Fields: `hosts: {domain: ip[]}`, `servers: [(string|DnsServerObject)]`, `clientIp`, `queryStrategy: UseIP/UseIPv4/UseIPv6`, `disableCache`, `disableFallback`, `disableFallbackIfMatch`, `serveExpiredTTL`/`serveStale`, `useSystemHosts`, `tag`, `hosts` expansion.
  - DnsServerObject: `{address:"8.8.8.8" | "https://1.1.1.1/dns-query" | "tls://..." | "quic://..." | "1.1.1.1", port:53, domains:["geosite:cn"], expectedIPs:["geoip:cn"], skipFallback:true, queryStrategy, clientIP }`.

- **v2rayN DNS generation modes:**
  - HOW: Settings → `DNS Settings` has **Simple** vs **Custom (Raw)**. `Config.SimpleDNSItem` (simple) vs `Config.RawDnsItem{NormalDNS, TunDNS, UseSystemHosts, DomainStrategy4Freedom}` (custom). `CoreConfigV2rayService` branch:
    - If `RawDnsItem.Enabled` → `V2rayDnsService.GenDnsCustom()` : takes `IsTunEnabled ? TunDNS : NormalDNS` JSON text → `JsonUtils.ParseJson(customDNS)` → injects `hosts` via `GetSystemHosts()` + `domainList` domainDNS server + appends to `_coreConfig.dns` + adds routing `inboundTag:[DnsTag] → proxy`.
    - Else → `V2rayDnsService.GenDns()` : builds `Dns4Ray` from `SimpleDNSItem.{DirectDNS, RemoteDNS, BootstrapDNS, FakeIP, GlobalFakeIp, Strategy4Freedom/Proxy/ProxyDial, ParallelQuery, ServeStale}` → calls `FillDnsServers()` + `FillDnsHosts()` + `GenFakeDns()` + adds directDns routing rules + final `DnsTag` rule.
  - FILE: `ServiceLib/Services/CoreConfig/V2ray/V2rayDnsService.cs:1-250` `GenDns()` + `GenDnsCustom()` + `FillDnsServers()` + `FillDnsDomainsCustom()`; `ServiceLib/Models/SimpleDNSItem.cs`; `ServiceLib/Models/RawDnsItem.cs`.

- **Simple DNS builder in detail (`GenDns()`):**
  - Direct vs Remote split:
    - HOW: `FillDnsServers()` takes `proxyDomainList` (geosite rules routed to proxy) vs `directDomainList` (direct) vs `expectedDomainList` etc., derived from routing rules' `domain` containing `geosite:`/`domain:` tags. Creates tagged servers: `directDNSAddress` (`223.5.5.5`, `114.114.114.114` etc. `Global.DomainDirectDNSAddress`) for directs; `remoteDNSAddress` (`8.8.8.8`, `1.1.1.1` `Global.DomainRemoteDNSAddress`) for proxied. If `FakeIP==true`, collects `fakeIPMatchDomain` (from proxy geosites + optionally direct if `GlobalFakeIp==true`) and calls `GenFakeDns()` which sets `fakedns:{ipPool:fakerange, poolSize:65535}` then `AddDnsServers(["fakedns"], fakeIPMatchDomain)`. Bootstrap: `dnsServerDomains` (hostnames of DoH servers themselves) resolved via `bootstrapDNSAddress` (`1.1.1.1` plain). Adds `skipFallback` true for direct tags. Final adds `directDnsTags` routing rule `inboundTag:directDnsTags → direct` and `inboundTag:["dns"] → balancerOrProxy`.
  - FILE: `ServiceLib/Services/CoreConfig/V2ray/V2rayDnsService.cs:60-180` `FillDnsServers()` + `GenFakeDns()`.

- **Hijack / DNS hijack routing:**
  - HOW: In sing-box mode, `SingboxDnsService` + `SingboxRoutingService` add `sniff` + `hijack_dns` action: `{"action":"hijack-dns"}` rule for `port:53` / `protocol:dns`. In Xray mode, `routing.rules` hijacks via `inboundTag:["tun"] port:53 → dnsOut` (TUN) + `inboundTag:[DnsTag] → proxy/direct` (split). `directDnsTags` technique ensures `223.5.5.5` queries don't go via proxy (leak-safe).
  - FILE: `ServiceLib/Services/CoreConfig/Singbox/SingboxDnsService.cs:57-70` `remote/direct/hosts` tags; `SingboxRoutingService.cs:82-124` DNS hijack + sniff.

- **FakeDNS (FakeIP):**
  - HOW: Toggle `FakeDNS` checkbox in simple DNS settings; optional `FakeIP Range` (7.24.8 customizable `FakeIPRange` via `Fakeip` input, default `198.18.0.0/15` + pool `65535` derived from `IPNetwork2.Parse(fakeipRange).Total -1` per `xray/app/dns/fakedns/fake.go#L88` LRU vs subnet check). When enabled, Xray returns synthetic `198.18.x.x` for proxied domains, defers real resolve until routing; reduces DNS latency + anti-poisoning but breaks some apps that do local DNS verification. `GenFakeDns()` computes `poolSize` as `min(totalIPs-1, int64 max)`. TUN mode + FakeIP interplay: all IPv6 routed to TUN regardless of `Enable IPv6` toggle (7.24.8 fix).
  - FILE: `ServiceLib/Services/CoreConfig/V2ray/V2rayDnsService.cs:40-75` `GenFakeDns()`; `ServiceLib/Global.cs:FakeIPRanges`; `releases/tag/7.24.8` "可自定义 fakeip 范围 #9786".

- **DoH / DoT / DoQUIC via Xray:**
  - HOW: In simple mode, `RemoteDNSAddress` can be `https://1.1.1.1/dns-query` or `tls://8.8.8.8` or `quic://dns.adguard-dns.com`; v2rayN passes string verbatim to `servers[]`. Custom mode you write raw JSON `servers:[{address:"https://dns.quad9.net/dns-query", domains:[], expectedIPs:[], skipFallback:true}]`. Bug report #8870 Bug2: 7.19 dropped 6 top-level fields (`queryStrategy`, `disableFallback`, `disableFallbackIfMatch`, `disableCache`, `serveExpiredTTL`, `useSystemHosts`) when using custom DNS — fixed in 7.19.1+. Bug3: sing-box `cache_capacity` dropped. Bug4: sing-box generated `domain_keyword` instead of `domain` for DNS server routing (substring vs suffix).
  - FILE: `issue #8870` Bug2 table; `ServiceLib/Services/CoreConfig/V2ray/V2rayDnsService.cs` custom pass-through.

- **Per-preset DNS strategy overrides:**
  - HOW: `Strategy4Freedom` (direct outbound `sockopt.domainStrategy`), `Strategy4Proxy` (`targetStrategy` per proxy outbound), `Strategy4ProxyDial` (`sockopt.domainStrategy` per dialer proxy). 7.24.8 new `连接代理解析策略` #9708 allows separate strategy for freedom vs proxy vs dial proxy to prevent direct-side DNS pollution vs proxy-side racing. UI: `DNS Settings → Advanced → Freedom/Proxy connection domain resolution strategy`.
  - FILE: `ServiceLib/Services/CoreConfig/V2ray/V2rayDnsService.cs:95-140` `FillSockoptDomainStrategy()` + `targetStrategy`; `releases/tag/7.24.8` "添加连接代理解析策略".

- **DNS leak notes (issue #9428):**
  - HOW: TUN mode DNS leak on Xray: custom DNS `servers:[{address:"https://1.1.1.1/dns-query", skipFallback:true}]` + `routing.rules: inboundTag tun port 53 → dnsOut` but `netsh interface ip show dnsservers` for `xray_tun` shows None → OS still uses previous NIC DNS. Fix: ensure `auto_route` + `strict_route` in sing-box tun; for Xray, set `TunModeItem.IcmpRouting` + ensure `DomainStrategy` not `AsIs` so proxy domains resolved via remote DNS path.
  - FILE: `issue #9428` DNS leak TUN mode; `issue #8870` routing leak variants.

---

## 9. Other Features — Latency, Speedtest, Load Balance, Backup, Auto-Update, QR Share

- **Latency test (Tcping vs Real ping):**
  - Modes: **TCP Ping** (default, `Tcping` via raw TCP connect to `address:port`) vs **Real Ping (ICMP)** vs **Proxy Ping via core**.
    - HOW: Button `Test → Test Real Latency` (or `Ctrl+T` → real delay test). `Lib/PingHelper.cs` / `ServiceLib/Handler/SpeedtestHandler.cs` spawns parallel tasks (default concurrency 5 `MixedConcurrencyCount`). **Tcping**: `TcpClient.ConnectAsync` with `SpeedTestTimeout` seconds (default 10–15s, tunable `SpeedTestItem.SpeedTestTimeout`), measures RTT to endpoint IP (ignores protocol handshake). **Real ping**: via core's `observatory`/`burstObservatory` if `Mux4Ray` / `Mux4Sbox` enabled → actual proxy handshake latency. UI column `Latency` shows ms (color: green <150, yellow 150-300, red >300, `-1` fail). Sort via column header.
    - FILE: `ServiceLib/Handler/SpeedtestHandler.cs`; `ServiceLib/Models/SpeedTestItem.cs{SpeedTestTimeout, MixedConcurrencyCount, SpeedPingTestUrl}`; `ServiceLib/Handler/ConfigHandler.cs:110-130` defaults (`SpeedTestTimeout=10`, `SpeedTestUrl` from `Global.SpeedTestUrls`, `SpeedPingTestUrl` from `Global.SpeedPingTestUrls`, `UdpTestTarget`); `Wiki/Description-of-some-ui.md` latency columns.

- **Speed test (download throughput):**
  - HOW: `Test → Test Speed` downloads `SpeedTestUrl` (default `https://speed.cloudflare.com/__down?bytes=...` or `Global.SpeedTestUrls.First()` `https://cachefly.cachefly.net/100mb.test` mirror) via proxy outbound through core's `dokodemo`/`http` inbound; measures bytes/sec via `HttpClient` through `127.0.0.1:10808` (or TUN). Result in `Speed` column (Mbps). Settings → `Speed Test Timeout/Url/MixedConcurrency` control parallel nodes tested (default 5 concurrent). Uses `GenerateClientSpeedtestConfig()` with temp `configSpeedtest_{guid}.json` per batch.
  - FILE: `ServiceLib/Handler/CoreConfigHandler.cs:60-95` `GenerateClientSpeedtestConfig()`; `ServiceLib/Handler/CoreHandler.cs:40-60` `LoadCoreConfigSpeedtest()`; `ServiceLib/Global.cs:SpeedTestUrls`.

- **Load balance / Best ping (Balancer + Observatory):**
  - Xray `observatory` + `burstObservatory` + `routing.balancers`.
    - HOW: Create a **Policy Group** (type `PolicyGroup` / `Group` via `v2rayn://policygroup/...`): UI → `Add → Policy Group` → pick `Selector` or `URLTest` or `LeastPing`. Backed by `ProfileItem{ConfigType=Group, ProtoExtraObj:{ChildItems:"id1,id2", MultipleLoad: LeastPing|RoundRobin|Random|LeastLoad}}`. `CoreConfigV2rayService` generates: `observatory:{subjectSelector:["group*"], probeURL:"https://www.gstatic.com/generate_204", probeInterval:"10m", enableConcurrency:true}` + `burstObservatory` for fast burst, then `routing.balancers:[{tag:"proxy-balancer", selector:["proxy*"], strategy:{type:"leastPing"}}]` + `routing.rules:[{balancerTag:"proxy-balancer"}]`. `GenObservatory()`/`GenBalancer()` in `V2rayRoutingService.BuildFinalRule()`. 7.24.8 adds `自定义出站支持` #9817 for manual balancer outbounds.
    - FILE: `ServiceLib/Services/CoreConfig/V2ray/V2rayRoutingService.cs:63-73` `GenObservatory()`/`GenBalancer()`; `ServiceLib/Enums/EMultipleLoad.cs`; `ServiceLib/Models/ProfileItem.cs:ProtoExtraObj`; `xtls.github.io/en/config/observatory.html`; `xtls.github.io/en/config/routing.html#balancerobject` (strategy `leastPing/leastLoad/random/roundRobin`).

- **Backup / Restore / Portable:**
  - HOW: `Settings → Backup` exports `guiNConfig.json` (DB + settings) + `guiNDB.db` (SQLite) into `backup_YYYYMMDD.zip`. Restore via `Import → Backup file` → replaces both files (requires restart). Portable `zip` keeps everything in exe folder (detected via `Utils.GetConfigPath()` → exe dir vs `AppData/Roaming/v2rayN` when `LocalAppData==1`). WebDAV sync via `WebDavItem{Url, User, Pass}` for auto backup to cloud (Nextcloud etc.) — `WebDavHandler.Sync()`.
  - FILE: `ServiceLib/Handler/ConfigHandler.cs:SaveConfig()` temp write + atomic `File.Move`; `ServiceLib/Handler/BackupHandler.cs`; `ServiceLib/Models/WebDavItem.cs`; `Wiki/Faq` backup/restore.

- **Auto-update cores / geo assets:**
  - HOW: `Settings → Check Update → Update Core` fetches `XTLS/Xray-core`, `SagerNet/sing-box`, `MetaCubeX/mihomo` latest release via GitHub API (`api.github.com/repos/.../releases/latest`), compares `ver` vs `CoreInfo.Version`, downloads `.zip` with `DownloadHandle` (MITM-patched in 7.23.4), verifies GPG `.sig` if present, extracts to `bin/{CoreType}/` and `chmod +x` on non-Windows. `Update Geo Files` similar for `Loyalsoldier/v2ray-rules-dat` (`geoip.dat`/`geosite.dat`) + `2dust/sing-box-rules` (`*.srs` → `bin/srss/`). `CheckUpdateItem{AutoCheckUpdate, UpdateCoreWhenEnabled}` toggles auto on start. GPG verification uses shipped `*.sig` + `Fingerprint` badge.
  - FILE: `ServiceLib/ViewModels/CheckUpdateViewModel.cs:108` `SaveConfig`; `ServiceLib/Handler/DownloadHandle.cs` (patched #9703); `ServiceLib/Handler/CoreInfoHandler.cs:GetCoreInfo()`; `releases/tag/7.23.4` security note.

- **QR share / Clipboard:**
  - HOW: Right-click node → `Share → QR Code` generates `qrcode.png` via `QRCoder` (`ZXing.Net` / `QRCoder` lib) from share URL (`vmess://`/`vless://`/`ss://`/`trojan://`/`hysteria2://`...). `Share → Copy Link` copies to clipboard; `Scan QR Code from Screen` captures screen rectangle → decodes QR via `ZXing` → auto `Add Batch Servers`. Batch share: multi-select nodes → `Share → Export selected as Base64 subscription`.
  - FILE: `ServiceLib/ViewModels/MainWindowViewModel.cs:Share()`; `ServiceLib/Handler/QrCodeHandler.cs`; `ServiceLib/Utils/ClipboardUtils.cs`.

- **Other notable features:**
  - **Pre-proxy / Landing proxy chain (`前置代理/落地代理`):** `PreSocksPort` + `CoreStartPreService()` lets you chain: global proxy → landing proxy node (e.g., domestic relay → foreign node). Docs: `Wiki/Description-of-proxy-chain.md` ("前置代理和落地代理说明") — `dialerProxy` / `detour` field.
  - **Fragment (TLSHello fragmentation) + Noises:** Global `Fragment4RayItem{Packets="tlshello", Length="50-100", Interval="10-20"}` (#9597) for Xray `freedom.fragment` to split TLS hello and evade DPI; `Noises` via `Xray` `noise` outbound.
  - **Mux / XUDP:** `Mux4RayItem{Concurrency:8, XudpConcurrency:16, XudpProxyUDP443:"reject|allow|skip"}` + `Mux4SboxItem{Protocol:"h2mux|smux|yamux", MaxConnections:8}` — multiplex many streams over one TCP, XUDP aggregates UDP via Mux.
  - **HideColumnIpInfo:** `HideColumnIpInfo` toggle (Wiki `Description-of-some-parameters`) hides IP geo column for privacy on screenshots.
  - **Custom Outbound (#9817):** Since 7.24.8, add `自定义出站` JSON in routing UI → injected into `outbounds[]` (for `freedom` with `fragment`, `blackhole`, `dns`, `loopback` custom).
  - FILE: `ServiceLib/Models/Mux4RayItem.cs`; `ServiceLib/Models/Fragment4RayItem.cs`; `Wiki/Description-of-some-parameters.md`.

---

## 10. Platforms & Requirements

- **Windows (primary, full features):**
  - HOW: WPF (`v2rayN-windows-64.zip` / `v2rayN-windows-64-desktop.zip` Avalonia variant) + portable or installer; **Windows 10+** required per `Wiki/Release-files-introduction` v7.x (7.23.4 bumps min to Win10+; earlier supported Win7 SP1+ with .NET 6). Arch: `x64` (primary), `x86` (`v2rayN-windows-86.zip`/`-86-desktop.zip` since 7.23.4 #9545), `arm64` (`windows-arm64.zip`/`-arm64-desktop.zip`). After extract, run `v2rayN.exe` (or `v2rayN.Desktop.exe`). Needs `.NET Desktop Runtime` (bundled via `dotnet publish` self-contained? Portable includes `*.dll` + `runtimeconfig.json`; check `v2rayN.runtimeconfig.json` → `net10.0`). Admin required for TUN/Service Mode.
  - FILE: `Wiki/Release-files-introduction#Windows` `Windows 10+`; `Wiki/Faq#在 Windows arm64 下能使用吗？`; `releases/tag/7.23.4` "添加 Windows x86 发布文件 #9545".

- **Linux:**
  - HOW: `v2rayN-linux-64.zip` (portable `chmod +x v2rayN && ./v2rayN`) or `v2rayN-linux-64.deb` (`sudo apt install -y ./v2rayN-linux-64.deb`) or `v2rayN-linux-rhel-64.rpm` (`sudo dnf install -y ...`). Supported distros **Debian 12+**, **Ubuntu 22.04+**, **Fedora 36+**, **RHEL 9+** (7.23.4 bumps to `Debian 13+ / Ubuntu 26.04+ / Fedora 43+ / RHEL 10+` per latest release notes — likely future gating). Arch: `x64`, `arm64`, `riscv64` (`-riscv64`), `loong64` (`-loong64.deb/.zip`). Each arch has both `.deb` and `.rpm` + `.zip`. Requires `CAP_NET_ADMIN` or `sudo` for TUN; tray via `libappindicator`.
  - FILE: `Wiki/Release-files-introduction#Linux` matrix + `Linux x64/arm64` sections; `releases/tag/7.24.8` assets `v2rayN-linux-64.zip|deb`, `linux-arm64`, `linux-loong64`, `linux-riscv64`; `7.23.4` min RHEL 10 bump.

- **macOS:**
  - HOW: `v2rayN-macos-64.zip` / `v2rayN-macos-64.dmg` (x64) + `v2rayN-macos-arm64.zip` / `dmg` (Apple Silicon). **macOS 12+** minimum (7.23.4 `macOS 13.7+` noted as upcoming). Since `.dmg` is unsigned (no Apple dev cert), after drag to `/Applications`, run `xattr -cr /Applications/v2rayN.app` to clear quarantine (docs explicitly note). Startup: `chmod +x v2rayN && ./v2rayN` for zip.
  - FILE: `Wiki/Release-files-introduction#macOS` `macOS 12+` + `xattr -cr` instruction.

- **.NET / runtime dependencies:**
  - HOW: ServiceLib + both UIs target `.NET 10` (preview) on `master` (`net10.0-windows` for WPF, `net10.0` for Desktop); runtime `10.0` shipped self-contained inside zip (check `*.runtimeconfig.json` → `framework Microsoft.NETCore.App 10.0`). Linux `.deb` declares `depends: libicu, libssl` via `control` file in `package-debian.sh`. No external `dotnet` install needed for portable zip; system package `deb/rpm` may pull runtime. Build requires `dotnet SDK 8+ / 10` + `VS 2022` workload `Desktop development`.
  - FILE: `v2rayN/v2rayN.csproj:TargetFramework`; `v2rayN.Desktop/v2rayN.Desktop.csproj`; `global.json` runner; `package-debian.sh: Depends` line.

---

## 11. Repo Stats, Build Instructions & File Map

- **Repo stats snapshot (2026-08-30 fetch):**
  - HOW: Stars `114.9k` → `115k` rounded in this doc (badge shows `115k`); Forks `15.8k`; Watchers `943`; Open Issues `8`; Open PRs `6`; Commits `2,945` on `master`; License `GPL-3.0`; Topics: `proxy`, `shadowsocks`, `socks5`, `trojan`, `v2fly`, `v2ray`, `vless`, `vmess`, `windows`, `xray`, `xtls`; Languages: `C# ~94%`, `PowerShell/Batch ~5%`; Releases: `7.24.9` latest (2026-08-29 02:47 UTC, Avalonia 12, hy2 ECH, HappyEyeballs, Xray `allowInsecure` removed), prior `7.24.8`, `7.24.7` (pre-release), `7.23.4` (major platform/file/GPG bump).
  - FILE: `https://github.com/2dust/v2rayN` header; `releases` tag list; `LICENSE`; `.github/workflows/*.yml` commit history; `package-*.sh` version.

- **Download assets per release (7.24.8 example):**
  - HOW: Per arch `zip`, `zip.sig`, `deb`/`rpm`/`dmg` + `.sig` GPG detached. Windows: `v2rayN-windows-64.zip` (≈147 MB WPF), `v2rayN-windows-64-desktop.zip` (≈125 MB Avalonia), `v2rayN-windows-arm64.zip`, `v2rayN-windows-86.zip` (+ desktop variants). Linux: `v2rayN-linux-64.deb` 76 MB / `linux-64.zip` 127 MB, `linux-arm64`, `linux-loong64`, `linux-riscv64`; RHEL `rpm` variants. macOS: `v2rayN-macos-64.zip` (≈?? MB) / `.dmg` + `arm64`. Sig `297 B` each. Download counts visible per asset (e.g., `linux-64.deb` 6,219 downloads on 7.24.8 within 1 week).
  - FILE: `releases/tag/7.24.8#Assets` table; `Release-files-introduction` mapping.

- **Build steps (from source):**
  - HOW:
    1. `git clone https://github.com/2dust/v2rayN.git && cd v2rayN`
    2. Install `dotnet SDK 8+` (10 for master) + VS 2022 `Desktop development with C++` if building WPF; Linux needs `dotnet SDK` only for Desktop.
    3. Restore: `dotnet restore` (fetches `ReactiveUI 24`, `Avalonia 12`, `Semi.Avalonia`, `MaterialDesignThemes`, `Sqlite`, `QRCoder`, `YamlDotNet`).
    4. Build WPF: `dotnet build v2rayN/v2rayN.csproj -c Release -r win-x64 --self-contained` (output `bin/Release/net10.0-windows/win-x64/publish/v2rayN.exe`).
    5. Build Desktop cross-platform: `dotnet publish v2rayN.Desktop/v2rayN.Desktop.csproj -c Release -r linux-x64 --self-contained` (or `osx-arm64`, `win-x64`).
    6. Download cores: fetch `XTLS/Xray-core`, `SagerNet/sing-box`, `MetaCubeX/mihomo` releases into `bin/Xray/`, `bin/sing_box/`, `bin/mihomo/` (or run `powershell ./DownloadCores.ps1` if present, or `CheckUpdate` will fetch at runtime).
    7. Download geo: `geoip.dat` + `geosite.dat` from `Loyalsoldier/v2ray-rules-dat` into `bin/` and `*.srs` into `bin/srss/`.
    8. Package: `bash ./package-debian.sh linux-x64` → `.deb`; `bash ./package-rhel.sh` → `.rpm`; `bash ./package-osx.sh` → `.dmg` (requires `create-dmg`); Windows zip via `Compress-Archive`.
  - FILE: `README.md` + `Wiki` build docs (refer to `Wiki` pages offline); `package-debian.sh:1-50` deb control + `dpkg-deb`; `package-rhel.sh`; `package-osx.sh`; `.github/workflows/build.yml` CI steps (`dotnet restore/build/publish`); `global.json` runner.

- **Key file paths in repo (depth map):**
  - HOW:
    - `.github/workflows/` — CI builds per arch (windows/linux/macos, x64/arm64/loong64/riscv64).
    - `v2rayN/v2rayN/` — WPF app (`App.xaml`, `MainWindow.xaml`, `ViewModels/MainWindowViewModel.cs`, `v2rayN.csproj` `UseWPF`, `MaterialDesignThemes`).
    - `v2rayN.Desktop/` — Avalonia Desktop app (`App.axaml`, `MainWindow.axaml`, `Program.cs`, `v2rayN.Desktop.csproj` `Avalonia 12`).
    - `v2rayN/ServiceLib/` — shared library (core of all logic):
      - `ServiceLib.csproj` — project + `Sample/` embedded resources (`Sample/routing*.json`, `Sample/dns*.json`).
      - `Handler/ConfigHandler.cs` — load/save `guiNConfig.json` (`LoadConfig()`/`SaveConfig()`), defaults for `KcpItem`, `GrpcItem`, `TunModeItem`, `Mux4RayItem`, `SpeedTestItem`, `AddBatchServers()`/`AddCustomServer()`.
      - `Handler/CoreHandler.cs` — `CoreHandler` singleton: `Init()` (env `V2RayLocationAsset`/`XrayLocationAsset`, `CopyDirectory` for `LocalAppData`, `SetLinuxChmod`), `LoadCore(node)` → `GenerateClientConfig` → `CoreStart()` → `CoreStartPreService(node)` (dialerProxy chain), `LoadCoreConfigSpeedtest()`, `CoreStop()`, `RunProcess()`/`RunProcessAsLinuxSudo()`.
      - `Handler/CoreConfigHandler.cs` — `GenerateClientConfig(context, fileName)` switch `Custom → ClashService` else `sing_box → SingboxService` else `V2rayService`; `GenerateClientCustomConfig()` file copy; `GenerateClientSpeedtestConfig()`.
      - `Handler/CoreInfoHandler.cs` + `Models/CoreInfo.cs` — `GetCoreInfo(ECoreType)` → `CoreInfo{CoreType, CoreExes[], Arguments: "run -c {0}", AbsolutePath}`.
      - `Services/CoreConfig/V2ray/` — `CoreConfigV2rayService.cs` (orchestrator `GenerateClientConfigContent()`), `V2rayInboundService.cs` (`GenInbounds()` socks 10808 + sniff), `V2rayOutboundService.cs` (vmess/vless/ss/trojan/http/socks/wireguard/hysteria builders), `V2rayRoutingService.cs` (TUN rules + `GenRouting()` + `GenRoutingUserRule()` + `BuildFinalRule()`), `V2rayDnsService.cs` (`GenDns()`/`GenDnsCustom()`/`FillDnsServers()`/`GenFakeDns()`/`FillSockoptDomainStrategy()`).
      - `Services/CoreConfig/Singbox/` — `CoreConfigSingboxService.cs`, `SingboxInboundService.cs` (mixed + tun), `SingboxOutboundService.cs` (hysteria2/tuic/wireguard etc.), `SingboxRoutingService.cs` (TUN + rule-set `local`/`remote` + `domain_keyword` bug), `SingboxDnsService.cs` (`remote/direct` tags).
      - `Services/CoreConfig/Clash/` — `CoreConfigClashService.cs`.
      - `Handler/Fmt/` — per-protocol parsers: `VMessFmt.cs`, `VLESSFmt.cs`, `ShadowSocksFmt.cs`, `TrojanFmt.cs`, `SocksFmt.cs`, `HttpFmt.cs`, `Hysteria2Fmt.cs` (`ResolveFull2`), `TUICFmt.cs`, `WireGuardFmt.cs`, `ClashFmt.cs`, `V2rayNFmt.cs` (`v2rayn://`), `HysteriaFmt.cs` (v1 legacy), `SingboxFmt.cs`, `V2rayFmt.cs`.
      - `Models/` — `Config.cs` (root → `CoreBasicItem`, `Inbound[]`, `RoutingBasicItem`, `KcpItem`, `GrpcItem`, `TunModeItem`, `GuiItem`, `UiItem`, `SimpleDNSItem`, `RawDnsItem`, `SpeedTestItem`, `Mux4RayItem`, `Fragment4RayItem`, `SystemProxyItem`, `WebDavItem`), `ProfileItem.cs` (`IndexId`, `ConfigType:EConfigType`, `CoreType:ECoreType?`, `Address/Port/Id/Flow/Encryption/Sni/Fingerprint/PublicKey/ShortId/SpiderX/...`), `SubItem.cs`, `RoutingItem.cs`, `RulesItem.cs`, `CoreConfigV2ray.cs` (`Dns4Ray`, `RulesItem4Ray`, `Outbounds4Ray`), etc.
      - `Enums/` — `EConfigType.cs` (VMess/VLESS/SS/Trojan/Socks/HTTP/Hysteria2/TUIC/WireGuard/Custom/Group), `ECoreType.cs` (Xray, sing_box, mihomo, Hysteria2, Naive, TUIC...), `EMultipleLoad.cs` (LeastPing/LeastLoad/RoundRobin/Random), `EInboundProtocol.cs` (socks/http), `ERuleType.cs`.
      - `Utils/` — `Utils.cs` (`GetConfigPath()`, `GetBinPath()`, `GetExeName()`, `GetRuntimeInfo()`, `IsWindows()/IsNonWindows()`, `GetSystemHosts()`), `WindowsUtils.cs` (`SetProxy`, `RemoveTunDevice`, `InstallService`), `JsonUtils.cs` (`Serialize`/`Deserialize`/`ParseJson`), `EmbedUtils.cs` (`GetEmbedText()` for sample routing/dns), `FileManager.cs` (`CopyDirectory`).
      - `ViewModels/` — `MainWindowViewModel.cs` (commands: Add/Edit/Delete server, Import sub, Test latency/speed, Share QR), `CheckUpdateViewModel.cs` (geo/core update), `SettingViewModel.cs`.
      - `Sample/` — embedded JSON (`dnsNormal.json`, `routingBypassCN.json`, `routingGlobal.json`, `srss/` refs).
    - `global.json` — test runner `Microsoft.Testing.Platform`.
    - `LICENSE` — GPL-3.0.
    - `package-debian*.sh`, `package-rhel*.sh`, `package-osx.sh`, `package-*.sh` loong/riscv variants — packaging scripts.
    - `README.md` — shields, download links, platform table, GPG fingerprint, community links.
    - `v2rayN/bin/` (runtime, not git) — `Xray/xray`, `sing_box/sing-box`, `mihomo/mihomo`, `hysteria/hysteria`, `geoip.dat`, `geosite.dat`, `srss/*.srs`, `guiNConfig.json`, `guiNDB.db`, `config.json`, `configPre.json`, `speedtest_*.json`.
  - FILE: tree fetch `https://github.com/2dust/v2rayN` folders; `ServiceLib/Handler/ConfigHandler.cs:1-130`; `ServiceLib/Handler/CoreHandler.cs:1-80`; `ServiceLib/Handler/CoreConfigHandler.cs:1-60`; `ServiceLib/Services/CoreConfig/V2ray/V2rayRoutingService.cs:1-73`; `ServiceLib/Services/CoreConfig/V2ray/V2rayDnsService.cs:1-250`; `Wiki/List-of-supported-cores`.

---

## 12. References

- **Primary repo & docs:**
  - HOW: `2dust/v2rayN` README (`https://github.com/2dust/v2rayN`), Wiki Home + `Release-files-introduction`, `List-of-supported-cores`, `Description-of-subscription`, `Description-of-VMess-share-link`, `Description-of-VLESS-share-link`, `Description-of-system-proxy-routing`, `Description-of-custom-routing-rules`, `Description-of-some-ui`, `Description-of-some-parameters`, `Faq`, `Description-of-proxy-chain` — all under `https://github.com/2dust/v2rayN/wiki/*`.
  - FILE: `webfetch https://github.com/2dust/v2rayN` (2026-08-30 snapshot, 114.9k★); `webfetch /wiki`; `webfetch /wiki/List-of-supported-cores` (cores list + GEO); `webfetch /wiki/Release-files-introduction` (v7.x packages); `webfetch /wiki/Description-of-subscription` (sub formats + `v2rayn://` payload spec).

- **Releases & security:**
  - HOW: `releases` page shows 7.24.9 (2026-08-29) + 7.24.8 (2026-08-22) + 7.24.7 pre + 7.23.4 (GPG/downloader MITM fix) — each tag notes "紧急安全更新：修复内置下载器 MITM" + per-change PR links (#9708 domainStrategy, #9772 HappyEyeballs, #9786 FakeIP range, #9817 custom outbound, #10036 WireGuard remote DNS, #9703 MITM patch, #9545 x86, #9608 GPG keys, #9516 hysteria realm/gecko, #9597 fragment).
  - FILE: `websearch releases tag 7.24.8` + `7.24.7` + `7.23.4` extracts; `webfetch /releases/tag/7.24.8` assets table.

- **Xray-core integration docs (XTLS):**
  - HOW: `xtls.github.io` / `XTLS/Xray-docs-next` — `Transport Configuration` (`transport.html` method+security matrix), `inbounds/tun.html`, `outbounds/wireguard.html`, `outbounds/hysteria.html`, `outbounds/shadowsocks.html`, `outbounds/vless.html` (VLESS flow `xtls-rprx-vision`), `transports/reality.html` (dest/shortIds/fingerprint/spiderX), `transports/tls.html` (ECH), `transports/xhttp.html`, `transports/grpc.html`, `transports/websocket.html`, `transports/raw.html`, `config/dns.html` (queryStrategy/disableFallback/FakeDNS), `config/routing.html` (domainStrategy, RuleObject process/inboundTag, BalancerObject strategy `leastPing/leastLoad`), `config/observatory.html` (probeURL/probeInterval), `config/outbound.html` (Mux/XUDP `xudpConcurrency`). Xray-examples repo `VLESS-TCP-XTLS-Vision-REALITY/REALITY.ENG.md` (server/client JSON, cert modes, spider behavior).
  - FILE: `webfetch https://xtls.github.io/en/config/transport.html` matrix; `webfetch https://xtls.github.io/en/config/transports/reality.html` Reality Object; `webfetch /en/config/routing.html` full `RoutingObject` spec via DeepWiki; `websearch XTLS Xray-core VLESS Reality Vision XHTTP`.

- **Routing / TUN / DNS internals:**
  - HOW: DeepWiki `2dust/v2rayN` pages `3.4-routing-configuration` (RoutingBasicItem, RulesItem → RulesItem4Ray, GenRouting()), `2.4-servicelib-core-library` (ServiceLib shared), `2-architecture` (ServiceLib → WPF vs Desktop). Source files `V2rayRoutingService.cs`, `V2rayDnsService.cs`, `SingboxRoutingService.cs`, `SingboxDnsService.cs` document domainStrategy, balancerTag, dns hijack, FakeIP poolSize derivation, directDnsTags, and TUN deadlock bug #8870 (remote vs local `geosite:` colon vs hyphen, `download_detour:proxy`, `domain_keyword` vs `domain`).
  - FILE: `websearch v2rayN routing TUN mode service mode Xray dns FakeDNS`; `issue #8870` long bug report (deadlock FATAL TLS timeout + 6-field DNS drop + cache_capacity + domain_keyword); `issue #9428` DNS leak `xray_tun`.

- **Speedtest / routing docs speedtest:**
  - HOW: `ConfigHandler.cs` defaults: `Mux4RayItem{Concurrency:8, XudpConcurrency:16, XudpProxyUDP443:"reject"}`, `HysteriaItem{UpMbps:100, DownMbps:100}`, `SpeedTestItem{Timeout:10, Url:Global.SpeedTestUrls.First(), PingTestUrl, Concurrency:5}`, `Fragment4RayItem{Packets:"tlshello", Length:"50-100", Interval:"10-20"}`. XTLS `observatory.md` + `metrics.md` for load-balance data source.
  - FILE: `ServiceLib/Handler/ConfigHandler.cs:70-150` defaults; `ServiceLib/Models/Mux4RayItem.cs`, `ServiceLib/Models/HysteriaItem.cs`.

- **Generated artifacts verification:**
  - HOW: After `LoadCore(node)`, v2rayN writes `bin/config.json` (Xray) or `bin/config.json` (sing-box) + `bin/configPre.json` (pre-proxy). Inspect via `Settings → Show Config` or open file directly. Example `dns` section with `fakedns`, `servers:[{address:"fakedns", domains:[...]}, {address:"8.8.8.8", domains:["geosite:cn"]}]` + `routing` with `domainStrategy`, `rules`, `balancers`, `observatory`.
  - FILE: `ServiceLib/Handler/CoreConfigHandler.cs` write `File.WriteAllTextAsync(fileName, result.Data.ToString())`; `CoreHandler.cs` `Utils.GetBinConfigPath(Global.CoreConfigFileName)`.

---

> **Notes for `VPN Research` maintainers:** This file targets **350+ lines** via bullet+sub-bullet + HOW expansions; all sections include `HOW:` indented sub-bullets and `FILE:` code-pointers for auditability. Keep `References` updated per Xray-core release (especially `XHTTP`/`Reality` seed changes + `sing-box 1.15+` `wireguard` deprecation timeline). Re-verify star count (≈115k as of 2026-08-30) quarterly — badge drifts fast. For Windows arm64 `x86` users, cite `Wiki/Faq` + `Release-files-introduction` before recommending `-arm64` zip (bundled `wintun` + .NET self-contained differ).
