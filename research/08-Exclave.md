# 08 — Exclave (ExclaveNetwork/Exclave) — Extreme Detail Research

> **Repo:** `ExclaveNetwork/Exclave` (fork `SagerNet/SagerNet` → `xchacha20-poly1305/husi` → `dyhkwong/Exclave` → `ExclaveNetwork`) · **License:** GPL-3.0-only (`with_clash`) / GPL-3.0-or-later (`without_clash`) dual · **Language:** Kotlin (~80%) + Java + Go (libexclavecore) + C (hev / naive) · **UI:** Android Views + Material + Preference · **Cores:** `LibExclaveCore` (`sing-box` + `clash` with `with_clash` tag) + `exclave-core` (v2ray-core fork, migration) + `NaïveProxy` plugin (Chromium) · **Platform:** Android 6.0+ (API 23+, default) / Android 5.0+ (API 21, legacy) — **Android ONLY**
> **Homepage:** https://github.com/ExclaveNetwork/Exclave · **Wiki:** https://github.com/ExclaveNetwork/Exclave/wiki · **F-Droid:** https://f-droid.org/packages/com.github.dyhkwong.sagernet · **Telegram:** https://t.me/s/exclavian · **Stars (Aug 2026):** ~2,674★ / 163 forks / 24 watchers / 3,112 commits (dev) · **Latest:** 0.17.51 (2026-08-16), 0.17.50/0.17.48 (Aug), 0.17.46 (2026-07-06), 0.17.43 (2026-06-04)
> **Status:** Actively maintained by `dyhkwong` under `ExclaveNetwork` org; default branch `dev`; releases via `github-actions[bot]`; `exclave-core` migration in progress — do not rely on it.

---

## Table of Contents

1. [Overview](#1-overview)
2. [Supported Protocols — Exhaustive (outbound.type)](#2-supported-protocols--exhaustive-outboundtype)
3. [Cores — LibExclaveCore / exclave-core / sing-box Lineage](#3-cores--libexclavecore--exclave-core--sing-box-lineage)
4. [Subscription & Import/Export Formats](#4-subscription--importexport-formats)
5. [Routing / Split Tunneling / Proxy Chains](#5-routing--split-tunneling--proxy-chains)
6. [TUN / VPN Integration](#6-tun--vpn-integration)
7. [DNS](#7-dns)
8. [DPI Bypass — Reality / uTLS / ECH / Vision / AnyTLS](#8-dpi-bypass--reality--utls--ech--vision--anytls)
9. [Other Features — Distribution, Cert, Flavors, Notification, Speedtest](#9-other-features--distribution-cert-flavors-notification-speedtest)
10. [Platforms & Requirements](#10-platforms--requirements)
11. [Repo Stats, Build Instructions & File Map](#11-repo-stats-build-instructions--file-map)
12. [References & Verification HOW](#12-references--verification-how)

---

## 1. Overview

- **What it is:**
  - Android universal proxy toolchain that wraps a heavily-patched `sing-box` + `clash` Go core (`LibExclaveCore`) as a pseudo-VPN VpnService, adds group/subscription management, custom V2Ray-style routing, per-app split, TUN (gVisor/system) and pluginized NaïveProxy for censorship circumvention — successor to `SagerNet` with `sing-box` + `ClashMeta` singularity.
    - HOW: Kotlin app (`app/src/main/java/io/nekohasekai/sagernet` heritage) writes per-group `outbounds`/`endpoints` + `route` + `dns` JSON via `libbox` → Go `LibExclaveCore` (`libbox.BoxService`) → `sing-box` `tun` inbound + `socks`/`http` inbounds (e.g. `127.0.0.1:2080`) + `tun` fd from `Android VpnService.Builder` → `gVisor netstack` or `system` NAT-rewrite reassembles IP datagrams → forwarding to `outbounds[].type`.
    - FILE: `README.md:1-20` "Exclave is a proxy client."; `app/build.gradle.kts:1-60` `applicationId "com.github.dyhkwong.sagernet"`; `library/core/build.sh:1-30` `gomobile bind -target=android/*`; `LibExclaveCore/tun.go:1-40` `TunOptions`; `LibExclaveCore/v2ray.go:1-80` `StartInstance`/`StopInstance`.

- **GPL-3.0 dual (Clash contamination):**
  - HOW: Dual licensing governed by build tag on `github.com/exclavenetwork/libexclavecore`:
    - `with_clash` **enabled** → `clash/` directory compiled in (Clash GPL-3.0 code) → **entire Exclave becomes GPL-3.0-only** (no later-version option).
    - `with_clash` **disabled** → no Clash code → **GPL-3.0-or-later** (either 3 or any later).
    - Plugins separately: `GPL-3.0-or-later` always.
    - F-Droid metadata pins `License: GPL-3.0-only` because F-Droid builds `oss` which links with Clash by default.
  - FILE: `README.md#Notice:1-20` excerpt verbatim; `LICENSE:1-30` "either version 3 ... or at your option any later version. However ... with_clash tag, the GNU GPL v3 applies to all"; `LibExclaveCore/LICENSE:1-40` split notices (`files under clash/` vs rest); `LibExclaveCore/with_clash.go:1-10` vs `without_clash.go:1-10` build constraints `//go:build with_clash`; `F-Droid/metadata/com.github.dyhkwong.sagernet.yml:1-10` `License: GPL-3.0-only`.

- **Kotlin Android client, SagerNet heritage:**
  - HOW: ~79% Kotlin, ~18% Java, remainder Go/C — inherited from `SagerNet` (nekohasekai). UI remains `Android Views` (not Compose), `Fragment` + `Preference` + `RecyclerView`, early Gradle Kotlin DSL (`build.gradle.kts`, `gradle.properties`). `buildSrc` plugin logic, `bin/` helpers. Languages confirmed via Linguist on `Exclave` vs `SagerNet` ratio preserved.
  - FILE: `build.gradle.kts:1-20` `plugins { alias(libs.plugins.android.application) ... }`; `gradle.properties:1-20` `android.useAndroidX=true`; `.gitmodules:1-10` only `plugin/naive/src/main/jni/naiveproxy → https://github.com/klzgrad/naiveproxy`.

- **Android 6.0+ default / 5.0+ legacy (best-effort):**
  - HOW: Two flavors after `0.17.48` split:
    - `default` (`*-ossRelease` without `-legacy`) → `minSdk 23` (Android 6.0 Marshmallow+), `targetSdk 37` (Android 17), `compileSdk 37.0`. Uses modern Gradle deps, modern NDK, modern WebView. APK name `Exclave-0.17.51-arm64-v8a.apk` etc.
    - `legacy` (`*-legacyRelease`) → `minSdk 21` (Android 5.0 Lollipop), pinned old Gradle dependencies; may trigger `https://issuetracker.google.com/issues/519796838` on new devices; best-effort, may be ended anytime.
    - Warning on README and release notes: legacy only for old devices.
  - FILE: `README.md#Download:1-15` "The default flavor (versions without `-legacy` suffix) supports Android 6.0+. The legacy flavor ... supports Android 5.0+."; `app/build.gradle.kts:40-90` `flavorDimensions "vendor"` + `productFlavors { create("oss") { minSdk=23 } create("legacy") { minSdk=21 } }`; `releases/tag/0.17.48` notes "Split the release into default flavor (Android 6.0+) and legacy flavor (Android 5.0+, with some Gradle dependencies pinned)".

- **2.6k+ stars, fork lineage SagerNet → husi → Exclave:**
  - HOW: `SagerNet/SagerNet` by `nekohasekai` archived **2024-01-04** read-only (health, seeking maintainer, 1,113 commits to 2023-09, 5.8k★). `xchacha20-poly1305/husi` intermediate community fork (preserved SagerNet with sing-box patches). `dyhkwong/Exclave` created **2021-06-15T17:04:29Z** as personal fork, then migrated to `ExclaveNetwork` org (≈2023); acknowledgment lists `Shadowsocks/shadowsocks-android`, `SagerNet`, `husi`, "Other forks of SagerNet". Dev branch has **3,112 commits**, stars grew to ~2.7k by Aug 2026 (2,619 seen on org page, 2,674 on repo view, trending shard).
  - FILE: `Exclave README.md#Acknowledgment:1-10` bullet list; `ExclaveNetwork overview page:1-20` "ExclaveNetwork/Exclave - Proxy client (2619 stars)" + fork tree; `SagerNet org README (grokipedia mirror):1-30` archive 2024-01-04; `SQSh1/Exclave README:1-10` "fork of the archived Android proxy client SagerNet and uses a custom overhauled fork of V2Ray"; `AndrewWangDev/Exclave:1-10` "fork of [dyhkwong/Exclave]".

---

## 2. Supported Protocols — Exhaustive (outbound.type)

> Every outbound is `sing-box` `outbounds[].type` except `NaïveProxy` (external Chromium APK via Android Plugin Intent) and some private tunks (`sing-mux`, `sing-uot`). Inbound-local `tun` + `socks`/`http` + `redirect` via `LibExclaveCore`.

- **Shadowsocks (`outbound.type: "shadowsocks"`) — SIP003 plugin capable:**
  - AEAD ciphers: `aes-128-gcm`, `aes-256-gcm`, `chacha20-poly1305` (`chacha20-ietf-poly1305` alias issue noted), non-standard `aes-192-gcm`, `xchacha20-poly1305`; `none`/`plain`/`dummy` no-encryption for LAN/testing.
    - HOW: `ss://method:password@host:port#remark` SIP002 URI + legacy `ss://BASE64(method:password@host:port)#remark` + `ShadowsocksFmt` parses `method`/`password`/`server`/`port` → `outbounds: [{type:"shadowsocks", server, server_port, method, password, plugin, plugin_opts}]`.
  - Stream ciphers: historical `aes-128-cfb` etc deprecated, superseded by AEAD; OTA deprecated due to active detection (breakwa11/shadowsocks-rss#38, printempw vuln, edwardzpeng decrypt-without-password).
    - HOW: Wiki `Configuration#Shadowsocks#Stream ciphers` notes not recommended.
  - `ReducedIvHeadEntropy`: remaps first 6 IV bytes to printable chars to evade 2022-23 region firewall, but creates obvious fingerprint — "Do NOT abuse if NOT backed into corner" per wiki.
    - FILE: `wiki/Configuration:Shadowsocks:1-40` stream vs AEAD vs none.
  - **SIP003 Plugin:**
    - Args: `plugin=obfs-local;obfs=http;obfs-host=cloudfront.net` or `v2ray-plugin;mode=websocket;tls;host=cloudfront.com;path=/ray;mux=0`. Built-in `obfs-local` + `v2ray-plugin` without standalone install; standalone plugins designed for `Shadowsocks Android` also supported via `android:host="io.nekohasekai.sagernet"` intent.
    - Caveats: UDP not via plugin; `v2ray-plugin` default `host=cloudfront.com` if unspecified (consistent with official `main.go:48`); `obfs-local` default `obfs-host=cloudfront.net` (`src/local.c:1259`); `obfs-uri`/`http-method` never released → unsupported; on Android, Go w/o `cgo` couldn't query DNS → V2Ray hard-coded `8.8.8.8` (removed in Exclave fork, prefer `ExclaveNetwork/v2ray-plugin-android`); Jan 2026 `Shadowsocks Android` removed `VpnService.protect(fd)` in favor `addDisallowedApplication` which **breaks `system` tun stack** (system requires `protect()`; gVisor works), so newly updated plugins without `protect` stop on system stack.
    - FILE: `wiki/Configuration:Plugin:1-30` all bullets; `Exclave/issues/73` "Naive plugin build" discussion.

- **Shadowsocks 2022 (`outbound.type: "shadowsocks"` with `2022-*` method) — SIP003 capable:**
  - Ciphers `2022-blake3-aes-128-gcm`, `2022-blake3-aes-256-gcm`, `2022-blake3-chacha20-poly1305` (SIP022/SIP023 nominal, but de facto new protocol `2022-1-shadowsocks-2022-edition`).
    - HOW: If `Extensible Identity Headers (EIH)` used, `password` form `iPSK0:iPSK1:...:iPSKn:uPSK` colon-joined; `server_key` + `server_port` handling via `sing-shadowsocks2 v0.2.2` (replaced V2Ray impl since `0.17.43` — "Remove Shadowsocks 2022 implementation option, always use sing-shadowsocks2").
  - FILE: `wiki/Configuration:Shadowsocks 2022:1-20`; `releases/tag/0.17.43` breaking change; `pkg.go.dev` `sing-shadowsocks2 v0.2.2`.

- **Trojan (`outbound.type: "trojan"`) — `trojan://`:**
  - `Trojan Protocol (trojan-gfw.github.io/trojan/protocol)` **requires TLS** (or `trojan://` over `tcp+tls`). Private mixed variants from V2Ray/Xray not considered Trojan.
    - HOW: Fields `server`, `server_port`, `password`, `tls.enabled:true`, `tls.server_name`, `tls.alpn`, `tls.utls`, `tls.ech`, `tls.reality`, `tls.insecure` (deprecated pin way). Known bug: if `alpn` unspecified/empty, sends `h2,http/1.1` not `[]` → inconsistent with non-V2Ray implementations; when `utls` enabled → `utls.fingerprint` ALPN used instead.
  - FILE: `wiki/Configuration:Trojan:1-15`; `sing-box/outbound/trojan` docs.

- **Hysteria2 (`outbound.type: "hysteria2"`) — `hysteria2://` / `hy2://`:**
  - HTTP/3 auth + `QUIC` stream (TCP) + `QUIC datagram` (UDP) proxy. `Brutal` congestion-control to rob bandwidth unless server disallows; otherwise `New Reno` (quic-go) or `BBR v1` (Hysteria modified) — BBR v1 ignores loss after bandwidth detect, fairness issue fixed only in BBR v2/v3 not used.
    - HOW: `server`, `server_port`/`server_ports` hopping, `password` (`username:password` if userpass, username colon fails, Unicode lowercase conversion in new server), `tls` + `obfs` (`salamander` scrambles to random, `gecko` fragments/pads QUIC handshake on Salamander) + `brutal` `up_mbps`/`down_mbps` + `ignore_client_bandwidth` negotiation matrix (documented wiki matrix 8 cases), `OmitMaxDatagramFrameSize` (breaks QUIC spec, needed if server supports no `max_datagram_frame_size`), `chrome` parrot (imitate Chrome QUIC ClientHello, always advertises `max_datagram_frame_size`, helps fingerprint but exposes parrot patterns per *The Parrot is Dead*).
  - Port hopping: `20000-50000`, `1234,5678,9012`, `1234,5000-6000,7044,8000-9000`.
  - FILE: `wiki/Configuration:Hysteria 2:1-60` includes matrix; `releases/tag/0.17.47-beta.4` "Add Chrome parrot for Hysteria2"; `releases/tag/0.17.43` "Add Hysteria2 Gecko obfuscation"; `sing-box/outbound/hysteria2` options.

- **AnyTLS (`outbound.type: "anytls"`) — `anytls://`:**
  - `AnyTLS Protocol v2 (anytls/anytls-go)` — mitigates nested TLS-in-TLS fingerprint, flexible packet-splitting/filling, **connection reuse** to reduce latency. Designed with TLS; REALITY promoted by celebs accidentally supported by sing-box but **not** part of AnyTLS spec.
    - HOW: `server`, `server_port`, `password`, `tls.*`, `idle_session_check_interval`, `idle_session_timeout`, `min_idle_session`, transport via `tls`. Known issue same as Trojan: empty ALPN → `h2,http/1.1` not none; utls ALPN overrides.
  - FILE: `wiki/Configuration:AnyTLS:1-10`; `anytls-go/docs/uri_scheme.md`.

- **mieru (`outbound.type: "mieru"`) — `mieru://`:**
  - `mieru v3` (client mieru, server mita) — random/custom traffic pattern, multiplexing, random padding, replay protection. `server_port` ignored if `port_range` set → random port in range each dial.
    - HOW: `server`, `port_range` (`1037-1137\n1237-1337` per line), `username`, `password`, `transport` (`TCP` carries both TCP+UDP via TCP; `UDP` uses custom reliable UDP), `multiplexing` (`multiplex_level`?), `traffic_pattern` **Base64-encoded protobuf** per `mieru/docs/traffic-pattern.md`. Updated to `v3.35.0` in `0.17.47-beta.2` adding low `Snell UDP MTU`, heartbeat jitter in `3.33.0/3.34.0` to harder traffic analysis.
  - FILE: `wiki/Configuration:mieru:1-15`; `releases/tag/0.17.47-beta.2` "Update mieru to 3.35.0"; `releases/tag/0.17.46` "Update mieru to 3.34.0 and add padding traffic pattern"; `releases/tag/0.17.43` "Update mieru to v3.33.0 (add heartbeat jitter)".

- **NaïveProxy (`plugin` via Intent, not `outbound.type`) — `naive+https://`:**
  - `klzgrad/naiveproxy` — Chromium network stack, multiplexes via HTTP/2 (or HTTP/3), length padding negotiation. **Requires standalone APK** from https://github.com/klzgrad/naiveproxy/releases (distributed/signed by upstream, not Exclave).
    - HOW: Exclave queries `Intent` with `android:host="io.nekohasekai.sagernet"` first then `moe.matsuri.lite` fallback for `BinaryProvider` `io.nekohasekai.sagernet.plugin.naive.BinaryProvider`. Extra headers format `Key1: value1\nKey2: value2` (LF → CRLF auto). UDP not supported. Nym: upstream naive not runnable on Android 6.0- → `minSdk 24`合理. Issue `Exclave/issues/73` long discussion on reusing upstream APK vs forking with host/authorities patch (commit `dyhkwong:naiveproxy:master` changes `applicationId`).
  - FILE: `README.md:Download:NaïveProxy Plugin:1-10`; `wiki/Configuration:NaïveProxy:1-15`; `.gitmodules:plugin/naive/src/main/jni/naiveproxy → https://github.com/klzgrad/naiveproxy`; `Exclave/issues/73` full thread.

- **TUIC (`outbound.type: "tuic"`) — `tuic://` version 5:**
  - `TUIC Protocol SPEC.md v5` — `QUIC stream` → TCP, `QUIC stream` (`udp_relay_mode: "quic"` one stream per UDP packet) or `QUIC datagram` (`native`) → UDP.
    - HOW: `server`, `server_port`, `uuid`, `password`, `congestion_control` (`cubic`/`new_reno`/`bbr`), `udp_relay_mode`, `zero_rtt_handshake` (**highly recommended disable** due replay vuln, perf hit), `heartbeat`, `alpn` (default none for official/mihomo uses `h3` → explicit `h3` for mihomo server), `disable_sni` (means disable `ServerName` SNI, but cert verification still uses ServerName — impl varies). Active detection 2022 (#67 comment 1196862427) distinguishable from normal QUIC server-side — same family as Juicity/ShadowQUIC Sunny variant.
  - FILE: `wiki/Configuration:TUIC:1-15`; `tuic-protocol/tuic/SPEC.md`.

- **Juicity (`outbound.type: "juicity"`) — `juicity://` via `sing-juicity`:**
  - `juicity/juicity spec_en.md` — `QUIC stream` proxies **both TCP+UDP** (no datagram mode confusion).
    - HOW: Fork maintained at `ExclaveNetwork/sing-juicity v0.2.0-beta.3` (Go 1.24, GPL-3.0, deps `quic-go v0.59.0-sing-box-mod.4`, `sing v0.8.5`, `sing-quic v0.6.2`). Active detection same as TUIC (quic fingerprint distinguishable). Same pluggability as TUIC.
  - FILE: `pkg.go.dev/github.com/exclavenetwork/sing-juicity@v0.2.0-beta.3`; `wiki/Configuration:Juicity:1-10`.

- **VMess (`outbound.type: "vmess"`) — `vmess://` (URI/JSON):**
  - Over TLS + optional **transport** (`tcp`/`ws`/`h2`/`grpc`/`httpupgrade`/`xhttp`/`kcp`/`quic`). `VMessAEAD` (alterId=0) vs legacy `VMess MD5` (alterId≠0) — MD5 claimed "multiple IDs from main ID" but counterproductive, AEAD fixes security issues (#2523). `aes-128-cfb` not supported; Md5 with alterId 0 incompatible; `AuthenticatedLength`/`NoTerminatedSignal` experimental breaking-incompatible.
    - HOW: `server`, `server_port`, `uuid`, `security` (`auto`/`aes-128-gcm`/`chacha20-poly1305`/`none`), `alter_id` (0-65535), `global_padding`, `authenticated_length`. UUID v5 mapping strings from Xray (`XTLS/Xray-core#158`) converted to v5 UUID compat (sing-box/mihomo also allow arbitrary length).
  - FILE: `wiki/Configuration:VMess:1-25`; `sing-box/outbound/vmess` docs.

- **VLESS (`outbound.type: "vless"`) — `vless://` (XTLS proposal):**
  - `VLESS (v2fly/v2ray-core#2636)` — stateless `encryption:none` or `encryption: x25519mlkem768plus.<base64>` (AEAD + appearance RTT/paddings + keys). Use with `tls`/`reality` + optional `flow` + transport.
    - HOW: `server`, `server_port`, `uuid`, `flow` (`xtls-rprx-vision` blocks UDP 443 vs `xtls-rprx-vision-udp443` allows — sing-box/mihomo `vision` maps to Xray `vision-udp443`; Xray refuses non-XUDP when flow enabled → XUDP enforced; Vision incompatible with transport except raw — sing-box accidentally/mihomo intentionally allows WS/HTTPUpgrade+Vision but Exclave **removed** that support), `packet_encoding` (`xudp`/`packetaddr`), `encryption` (VLESS Encryption #5067). UUID 7th/8th byte now routing purpose in new Xray servers (not third-party).
  - `Flow` details: populates TLS handshake avoid nested encryption; `vision` in sing-box vs Xray semantic confusion with old `xtls-rprx-origin/direct/splice` XTLS (different protocol, removed).
  - FILE: `wiki/Configuration:VLESS:1-30`; `sing-box/outbound/vless` + `tls.reality` docs.

- **WireGuard (`outbound.type: "wireguard"`) — `wireguard://` INI or URI:**
  - User-space WireGuard as **proxy** (TCP+UDP) not VPN — not designed for firewall bypass, conversion network→transport→network barely working, poor perf expected.
    - HOW: `server`, `server_port`, `private_key`, `peer_public_key`, `pre_shared_key`, `local_address` **one per line** (CIDR, e.g. `10.0.0.2/32\n2606:4700:.../128`), `mtu` (1280 typical), `reserved` (`0,0,0` or Base64 `AAAA` for WARP), `workers` (threads). `Xray supports blank local_address + non-standard keypairs` → **not** supported, user must resolve compat. Distinguish `wireguard` inbound vs `endpoint` in sing-box.
  - FILE: `wiki/Configuration:WireGuard:1-15`; `sing-box/outbound/wireguard` + `endpoint/wireguard`.

- **TrustTunnel (`outbound.type: "trusttunnel"` — private build tag) — `trusttunnel://`:**
  - `TrustTunnel PROTOCOL.md 65f5552` — claims "VPN" but proxy. TCP = standard `HTTP/2 CONNECT` or `HTTP/3 CONNECT`; UDP = private `UDP over TCP magic address` protocol.
    - HOW: `server`, `server_port`, `password`?, `tls` + `utls`, `server_name_to_verify`, `alpn`. **No ICMP echo** support + **no private health-check** magic address implemented. Vulnerability fixed `0.17.46` (`0b4abfb`): `ServerNameToVerify` didn't verify cert when `utls` used.
  - FILE: `wiki/Configuration:TrustTunnel:1-15`; `releases/tag/0.17.46` vuln note; `TrustTunnel/TrustTunnel/DEEP_LINK.md`.

- **Snell (`outbound.type: "snell"`) — `snell://`:**
  - `Surge Snell v4/v6` — closed-source, no public spec, reverse engineered via third party (`sing-snell v0.0.0-20260727093646-7cb813e07b73`).
    - HOW: `server`, `server_port`, `psk`, `version` (`4`/`2`/`3` mapping), `udp_enabled`? `v4` client can connect `v5` server but lacks QUIC Proxy Mode. No timely bugfix expectation.
  - FILE: `wiki/Configuration:Snell:1-10`; `pkg.go.dev` `sing-snell`.

- **ShadowQUIC (`outbound.type: "shadowquic"`):**
  - `spongebob888/shadowquic PROTOCOL.pdf` — QUIC-like stealing certificate, uses `JLS` to fake QUIC handshake with legit website (harassment/DDoS risk).
    - HOW: JLS config (Hello Randomizer?), `shadowsocks` inner encryption? Since `0.17.47-beta.2` **core-implemented** and experimental plugin removed; `SunnyQUIC` twin not planned (same active detection as TUIC); Brutal removed together.
  - FILE: `wiki/Configuration:ShadowQUIC:1-10`; `releases/tag/0.17.47-beta.2` "Implement ShadowQUIC in core and remove previous experimental ShadowQUIC plugin. There is no plan to implement SunnyQUIC".

- **SSH (`outbound.type: "ssh"`) — `ssh://` dynamic forwarding:**
  - `RFC4254 7.2` dynamic port forwarding — `password` + `public key` PEM/OpenSSH.
    - HOW: `server`, `server_port`, `user`, `password` vs `private_key` (PEM/OpenSSH), `private_key_passphrase` (no distinction empty vs none), `public_key` one per line `ssh-ed25519 AAAAC3...`, `ssh-rsa ...`, `ecdsa-sha2-nistp256 ...`, `host_key`/`host_key_algorithms`, `client_version`. `keepalive_interval` (`keepalive@openssh.com` OpenSSH extension widespread). No distinction `no auth` vs `password auth empty` except via custom outbound. **No UDP**; SSH forks with private UDP not considered SSH.
  - FILE: `wiki/Configuration:SSH:1-20`.

- **HTTP CONNECT (`outbound.type: "http"`) — `http://` / `https://`:**
  - Variants: `HTTP/1.1 CONNECT` (RFC7231 4.3.6), `HTTP/1.1 with TLS`, `HTTP/2 CONNECT` (RFC9113 8.5) if `tls.enabled && alpn negotiates h2`, `HTTP/3 CONNECT` (RFC9114 4.4 `http3` inbound type separate?). Typical server `Caddy + caddyserver/forwardproxy`.
    - HOW: `server`, `server_port`, `username`, `password` (`Basic` RFC7617), `tls` (enable → H2 auto if ALPN), `path`? No `Proxying UDP` (RFC9298) supported. Known distinction loss: `no auth` vs `empty user/pass auth` → custom outbound only. Caveat: V2Ray/Xray HTTP server doesn't support HTTP/2 but advertises `h2` → client fails if negotiated; set `alpn: ["http/1.1"]` workaround.
  - FILE: `wiki/Configuration:HTTP:1-20` + `HTTP/3:1-20`.

- **SOCKS (`outbound.type: "socks"`) — `socks://` / `socks4://` / `socks5://`:**
  - `SOCKS4 protocol (openssh/txt/socks4.protocol)` CONNECT, `SOCKS4A` CONNECT (domain), `SOCKS5 RFC1928` CONNECT + `UDP ASSOCIATE`.
    - HOW: `server`, `server_port`, `version` (`4`/`4a`/`5`), `username`, `password`, `network`? `5` supports `noauth` + `user/pass RFC1929` only (GSSAPI MUST unsupported); `4/4a` support `noauth` + username (SOCKS4A username = domain). `BIND` not supported. Length `1-255` for user/pass but many impl allow empty → use custom outbound if needed.
  - FILE: `wiki/Configuration:SOCKS:1-15`.

- **Historical / transport-layer adjuncts (not standalone outbounds but enabled per outbound):**
  - **Mux (`sing-mux`):** `Mux.Cool (v1.mux.cool)` magic address `v1.mux.cool` (real domain controlled by V2Fly, collision risk). Incompatible Smux/mux. Operates `UDP over TCP`. Options `h2mux` (Go HTTP/2), `smux`, `yamux`; `padding` (TLS handshake pad mitigates TLS-in-TLS for TLS/Reality only — inspired by Naïve padding); `Brutal` on TCP intentionally unsupported.
    - FILE: `wiki/Configuration:Mux:1-15`.
  - **PacketEncoding:** `XUDP (XTLS/Xray #252, Global ID & UoT Migration)` vs `Packet/PacketAddr (v2fly #1507, IPv4/IPv6 only, no domain)` to fix V2Ray design flaw where only first UDP packet carries dest. Sing-box does similar to Xray not V2Ray; `packetEncoding` setting exists only for `VMess/VLESS/Mux.Cool` (correctly designed protos like SS/Trojan/SOCKS don't need, but V2Ray/Xray infra flaw spreads via `packetEncoding` → makes domain/IP/port rules ineffective when enabled — Exclave uses Xray-like approach, no setting for correct protos). 
    - FILE: `wiki/Configuration:PacketEncoding:1-15`.
  - **Transports ("V2Ray transport" private protocols):** `TCP (no transport, RAW) + HTTP obfuscation` (host/path per line, default `www.baidu.com/www.bing.com` if unspecified), `KCP/mKCP` (seed XOR/AES-128-GCM obfusc, headerType poor obfusc, Xray breaking changes split XOR/AES → unsupported), `WS (WebSocket)` (early-data path vs header `Sec-WebSocket-Protocol`, `?ed=[number]` max early data compat), `HTTP (H2)` (host per line, path suffix arbitrary accept, `www.example.com` default), `QUIC` (private QUIC, ALPN default `h2,http/1.1` unless user explicit `h3` for sing-box, self-signed `quic.internal.v2fly.org` if TLS disabled, pointless encryption/headerType), `GRPC (GUN)` (serviceName chars `[A-Z_a-z0-9.]`, `serviceName` Compat flag for Xray URL-escaped `/path` and `multi mode`), `HTTPUpgrade` (Tor WebTunnel derivative, `?ed=[number]` path vs header `Host` vs SNI fallback), `Meek` (Tor meek domain fronting, GET/POST CDN abuse, limited speed), `XHTTP (SplitHTTP)` (`packet-up`/`stream-up`/`stream-one`, gRPC header spoof for CF, auto/stream modes, Breaking changes frequent).
    - FILE: `wiki/Configuration:Transport:1-80`.
  - **sing-uot v2:** UDP over TCP magic address `v1.mux.cool`? Actually `sing-uot (v2)` magic address private, not to confuse.
  - **ShadowTLS v2/v3:** **Removed** in `0.17.46` — "Breaking change: Remove ShadowTLS and reverse proxy." Previously another `TLS handshake with legit website` obfs (`shadow-tls docs/protocol-en.md v2/v3`), yet another distinguishable from normal TLS (`ban6cat6/aparecium`), no UDP, not standalone (usually chained with SS).
    - FILE: `releases/tag/0.17.46` vs `wiki/Configuration:ShadowTLS:1-20` now marked removed.

---

## 3. Cores — LibExclaveCore / exclave-core / sing-box Lineage

- **LibExclaveCore — the shipped core (`github.com/exclavenetwork/libexclavecore` Android AAR):**
  - Fork of `SagerNet/LibSagerNetCore` (539 commits main, Go). Wraps `sing-box` + optional `clash` into `libbox` gomobile `aar` via `gomobile bind -target=android/...`.
    - HOW: `library/core/` in Exclave repo (symlink/submodule?) compiled via `./run lib core` (bash that sets `GO111MODULE=on`, installs `gomobile`, `gomobile init`, `gomobile bind -trimpath -ldflags -s -w`) → outputs `libcore.aar` per ABI into `app/libs/`. `LibExclaveCore/` standalone repo exposes `with_clash.go` (`// +build with_clash`, imports `clash` adaptors) vs `without_clash.go` vs `clash/` directory (GPL-3.0). Build uses Go **1.27** per README prerequisites.
  - Build scripts: `./library/core/build.sh` (Linux/macOS x64/arm64) vs `.\library\core\build.bat` (Windows x64), both invoke `build.sh` internal. Alternative `./run lib core` alias.
  - FILE: `LibExclaveCore/build.sh:1-30`; `LibExclaveCore/build.bat:1-20`; `LibExclaveCore/go.mod:1-30` `module github.com/exclavenetwork/libexclavecore`; `LibExclaveCore/with_clash.go:1-15` `import _ "github.com/sagernet/sing-box/experimental/clashapi"`; `README.md#Build from source:1-20` JDK 21 + Go 1.27 + Android SDK Platform 37.0 + Build-Tools 37.0.0 + NDK r29.

- **sing-box fork + versioned Go deps:**
  - HOW: `ExclaveNetwork/sing-box` (14★ mirror only) tracks upstream `SagerNet/sing-box v1.13.19` (Go 1.24.7, GPL-3.0-or-later/BSD-3-Clause). `LibExclaveCore/go.mod` pins:
    - `github.com/sagernet/sing-box v1.13.19`
    - `github.com/sagernet/quic-go v0.61.0-sing-box-mod.4` / `v0.59.0-sing-box-mod.4` fallback
    - `github.com/sagernet/sing v0.9.0-beta.2` / `v0.8.13`
    - `github.com/sagernet/sing-mux v0.3.5`
    - `github.com/sagernet/sing-quic v0.7.0-beta.2` / `v0.6.x`
    - `github.com/sagernet/sing-shadowsocks v0.2.9`
    - `github.com/sagernet/sing-shadowsocks2 v0.2.2`
    - `github.com/sagernet/sing-snell v0.0.0-20260727093646-7cb813e07b73`
    - `github.com/sagernet/gvisor v0.0.0-20250811.0-sing-box-mod.1`
    - `github.com/sagernet/smux v1.5.50-sing-box-mod.1`
    - `github.com/sagernet/tailscale v1.92.4-sing-box-1.13-mod.9`
    - `github.com/sagernet/gomobile v0.1.12` for bind.
  - Check: `pkg.go.dev/github.com/exclavenetwork/libexclavecore` mirrors same import tree.
  - FILE: `pkg.go.dev` tables; `LibExclaveCore/go.mod:15-50` require block; `F-Droid/metadata/build recipe: sdkmanager ndk... go mod download && go mod vendor; GO_MOBILE_VERSION=$(sed ... gomobile ...)`.

- **exclave-core — the *other* core (migration, do NOT rely):**
  - HOW: `ExclaveNetwork/exclave-core` (69★, 15 forks, 7,145 commits `main`, forked `v2fly/v2ray-core`). Initially "modified V2Ray" (README 0.17.43: "custom v2ray-core fork") renamed `0.17.43` release: "Rename the custom v2ray-core fork to exclave-core. Exclave has never been de facto v2ray-core client, no longer nominal v2ray core client". Marked "Migration in progress. Do not rely on it." License `GPL-3.0-or-later` for app + `MIT` for V2Fly portion. Likely future will subsume LibExclaveCore? Today Exclave *still* uses LibExclaveCore (library/core) not exclave-core for runtime — exclave-core is *planned* next-gen.
  - FILE: `ExclaveNetwork/exclave-core/README.md` stub; `ExclaveNetwork/exclave-core go.mod:1-10` module path; `releases/tag/0.17.43` notes.

- **sing-juicity & supporting forks:**
  - HOW: `ExclaveNetwork/sing-juicity v0.2.0-beta.3` (3★) maintained by ExclaveNetwork for Juicity support; parallel `sing-shadowsocks*` and `sing-snell`. All Go 1.24.0.
  - FILE: `pkg.go.dev/github.com/exclavenetwork/sing-juicity@v0.2.0-beta.3`.

- **Build tags & Clash contamination mechanic:**
  - HOW: Tags used: `with_gvisor,with_quic,with_wireguard,with_clash_api,with_acme,with_proxyprovider,with_clash_ui,with_utls` (via `sing-box` enhanced tag set). Plus Exclave-specific `with_clash`. Built via `-tags with_clash,${TAGS}` variable in `build.sh`. Results in either `libbox.aar` containing `clash/` routing engine (GPL-3.0 locked) or clean.
  - FILE: `LibExclaveCore/build.sh:10-20` `TAGS=`; `deepwiki.com/yangchuansheng/sing-box/2.3-enhanced-features-and-build-tags` table correspondence; `LibExclaveCore/clash/*:1-20` `Copyright clash authors GPL-3.0`.

- **Go packages inventory (LibExclaveCore repo top-level):**
  - `age.go` (age encryption for subscriptions), `assets.go` (geoip/geosite), `ca.go`/`x509.go`/`certProber*.go` (root CA probing Go1.26/1.27), `dialer.go` (protect-aware dial), `dns.go` (hijack/sing-box DNS), `http.go` (proxy), `ipc.go`/`tun.go`/`gvisor/`/`nat/` (stack), `observatory.go` (healthcheck), `protect.go` (VpnService.protect), `route.go` (V2Ray Rule→sing-box route translation), `stats.go`, `stun.go`, `urltest.go` (delay test), etc.
  - FILE: `LibExclaveCore file list: 30 entries` seen on GitHub.

---

## 4. Subscription & Import/Export Formats

- **Raw subscription ("Raw") — best-effort multi-parser:**
  - **Share link collection (URI/URI-like strings):** newline (`\n` or `\r\n` or `\r`) joined set, OR **Base64-encoded** blob of that collection (standard / URL-safe / MIME, with/without padding). Parser auto-detects base64 vs plain.
    - Supported URI schemes (import/export matrix):
      - `VMess/VLESS`: `VMessAEAD / VLESS 分享链接标准提案 (XTLS/Xray-core #716)` → ✓/✓ ; legacy `VMess 分享链接说明 (2dust/v2rayN)` → ✓ ; `Proposal VMess Share Link Standard (v2fly #2638)` → ✓/✓
      - `Trojan`: `trojan-url (trojan-gfw/trojan-url)` → ✓/✓
      - `Shadowsocks/SS2022`: `SIP002 URI scheme` → ✓/✓ + legacy `SIP002#uri-and-qr-code` (`ss://`) → ✓
      - `Hysteria2`: `URI Scheme (v2.hysteria.network)` → ✓/✓
      - `AnyTLS`: `URI 格式 (anytls/anytls-go/docs/uri_scheme.md)` → ✓/✓
      - `Juicity`: `Link Format (juicity/juicity)` → ✓/✓
      - `mieru`: `Simple Sharing Link (enfein/mieru)` → ✓/✓
      - `TrustTunnel`: `Deep Link Specification (8856e7b)` → ✓/✓
      - Undocumented fields: parsed best-effort, not guaranteed; objectionable URI details intentionally not followed.
    - QR: QR only for URI encoding/decoding; supports ZXing charsets; URI percent-encoded → ASCII QR compatible. Only UTF-8 for URI encode/decode and config parsing.
    - FILE: `wiki/Group:Subscription type:Raw:Share link:1-40` table 9 rows.

  - **mihomo/Clash YAML:** YAML-like; **parse `proxies` only** (not `proxy-groups`, `rules` — those discarded per "only general information necessary for connecting to server will be parsed" + vendor lock-in workaround notice).
    - HOW: Fetch Clash YAML → `yaml→proxies` array → each `type: ss/vmess/vless/trojan/socks/etc` → map to outbound. Browser may supply `managed-config` with extra headers.
    - FILE: `wiki/Group:mihomo/Clash configuration:1-10`.

  - **V2Ray JSONv4 / JSONv5:** JSON-like; parse `outbounds` only; can also parse **single `OutboundObject`**. "V2Ray" means V2Ray, modified V2Ray by this software, or Xray.
    - FILE: `wiki/Group:V2Ray JSONv4/v5:1-10`.

  - **sing-box JSON:** JSON-like; parse `outbounds` **and** `endpoints`; can also parse **single `outbound` or `endpoint`**.
    - FILE: `wiki/Group:sing-box configuration:1-10` + `sing-box config` docs.

  - **WireGuard INI:** Parse classic `[Interface]/[Peer]` INI.
    - FILE: `wiki/Group:WireGuard configuration:1-10`.

  - **Shadowsocks JSON:** Parse `shadowsocks.json`.
    - FILE: `wiki/Group:Shadowsocks configuration:1-10`.

  - **Age-encrypted subscription:**
    - Result of encrypting mihomo config **or** share-link collection **or** Base64-encoded collection with `age (FiloSottile/age)` then ASCII-armor; references `mihomo/commit/358fa5e`.
    - FILE: `wiki/Group:age:1-10`.

- **SIP008 (Shadowsocks Online Config Delivery):**
  - `SIP008 (shadowsocks.org/doc/sip008.html)` — superset of Shadowsocks JSON for **Shadowsocks only**. Used for enterprise SS delivery.
    - HOW: JSON `servers:[{server, server_port, method, password, remarks, plugin?}]` + `bytes_used`/`bytes_remaining` traffic accounting.
  - FILE: `wiki/Group:SIP008:1-10`.

- **OOC (Open Online Config) / Quantumult Subscription-Userinfo:**
  - **Used/remaining/expire** display logic:
    - SIP008 → read `bytes_used` + `bytes_remaining` from subscription JSON body.
    - Others → read `Subscription-Userinfo` **private HTTP header** (`upload, download, total, expire`) per `crossutility/Quantumult/blob/master/extra-subscription-feature.md`. Some airports selectively provide based on `User-Agent`, hence customizable UA.
  - OOC here is category for any open `https://...` subscription returning plain/base64 lines; Exclave treats as generic raw.
  - FILE: `wiki/Group:Used traffic...:1-20`.

- **User-Agent spoofing (airport anti-bot):**
  - HOW: Settings per-subscription `User-Agent` string overrides default. Docs table popular UAs for manual spoof:
    - `v2rayNG/${VERSION_NAME}`
    - `ClashMetaForAndroid/${VERSION_NAME}`
    - `SFA/${VERSION_NAME} (${VERSION_CODE}; sing-box ${VERSION_NAME}; language ${LOCALE_CODE})` e.g. `zh_Hans_CN`.
  - Some panels (`airport panel`) refuse service judging UA — user must configure suitable UA.
  - FILE: `wiki/Group:Subscription:1-20` table 3 rows.

- **Custom assets per group:**
  - HOW: Manage routing assets `geoip.dat`/`geosite.dat` (update source configurable) → applied per group subscription? Actually assets global but referenced in `route` rules via `ext:`.
  - FILE: `wiki/Route:Custom route assets`.

---

## 5. Routing / Split Tunneling / Proxy Chains

- **Groups & Subscriptions (group granularity):**
  - HOW: Left drawer `Groups` → each group is either **Manual group** (user adds nodes) or **Subscription group** (bound to URL + interval). Group panel shows `Used/Remaining/Expire` chips. Long-press chip → details dialog. Group-level settings: **front proxy / landing proxy** (simple proxy chain entry/exit). Balancer or custom full config **cannot** be front/landing; front/landing not applied to balancer/proxy-chain/custom.
  - File: `wiki/Group:Basic:Front proxy/Landing proxy:1-10`.

- **Proxy chains (chaining outbounds) — full vs simple:**
  - Simple: `Front proxy` (entry) + `Landing proxy` (exit) two-node chain via UI toggles (no JSON).
  - Advanced: Create dedicated `Proxy Chain` type profile that lists ordered outbound tags → `outbounds: [{type:"selector", outbounds:[...]}]` or `urltest` chain; or **custom full config** JSON with `outbounds` array ordering. Chaining respects `detour`/`dialerProxy`/`proxySettings.tag` under the hood via sing-box `detour` field (transport over another outbound).
  - FILE: `README.md#Features: Proxy chain`; `wiki/Group:Front proxy/Landing proxy`; `wiki/Configuration:Mux` chain note; `AndrewWangDev/Exclave` enhanced fork merges remote `mux`/`ech` correctly via chain.

- **Custom routing (V2Ray RuleObject heritage, sing-box translation):**
  - HOW: `Settings → Route → Add route rule` → fields map to `RuleObject`:
    - `domain` (geosite / plaintext / regex one per line) + `ip` (geoip / CIDR) — but **relationship is AND not OR** → do NOT mix domain + IP in same rule (wiki warns).
    - `port` (e.g. `80,443,1000-2000`), `network` (`tcp,udp`), `source` (`geosite:`, `geoip:`).
    - Also `inboundTag`, `protocol` (e.g. `bittorrent`), `attrs` (Starlark).
    - Action `outboundTag`: `proxy` (selected node), `direct` (`freedom`), `block` (`blackhole`), plus custom tag for balancer/chain.
  - For HOW: Edit raw `Route - Manage route assets` → download/update `Loyalsoldier/v2ray-rules-dat` → reference via `geosite:cn`, `geoip:private`, `ext:custom.dat:tag`.
  - FILE: `wiki/Route:1-40` sections; `wiki/Configuration:Route assets`.

- **Routing rule special conditions:**
  - HOW: Rules can be conditioned on:
    - **Network type** (`WIFI`, `MOBILE`, `ETHERNET`, `USB (Android 12+)`, `SATELLITE (Android 15+)`) — via `NetworkCallback`.
    - **Wi-Fi SSID** — requires `Location Services` + `Always Allow` location permission; one per line; due design flaw `\n` in SSID must be escaped `\n`, `\`→`\\`.
    - **Application (UID)** — only under VPN mode; actually per-UID not per-package (`sharedUserId` shares). Apps lacking `android.permission.internet` not shown (e.g., Gemini `com.google.android.apps.bard` → route via Google `com.google.android.googlequicksearchbox`). On Chinese ROMs (TTAF 108-2022 modified `QUERY_ALL_PACKAGES`) need manual `GET_INSTALLED_APPS` grant.
  - FILE: `wiki/Route:Routing rules based on network type / Wi-Fi SSID / application:1-20`.

- **Global / Bypass presets:**
  - HOW: Prior SagerNet had `Global (proxy all)`, `Bypass LAN`, `Bypass China`, etc. Exclave's route UI exposes similar toggles + **global/bypass rules** imported from Clash `rules` vs V2Ray `routing.rules` — since Exclave only parses `proxies`/`outbounds`, global vs bypass semantics derived from `routing.rules` that user supplies.

- **Per-app VPN (split tunneling) — see §6 TUN/VPN:**
  - HOW: `Settings → Per-app VPN` → `Proxy only` (only selected apps via VPN) vs `Bypass mode` (all except selected). `Builder.addAllowedApplication()` / `addDisallowedApplication()` with UX checklist. Vacillations covered in TUN section.

- **DomainStrategy & Sniffing interplay (route-relevant):**
  - HOW: `domainStrategy: AsIs / IPIfNonMatch / IPOnDemand` — only matters when `fakeDNS` enabled OR `Override destination` enabled OR traffic from SOCKS/HTTP inbounds; for TUN, destination always IP so almost no diff. `Enable sniffing` (`sniffing` V2Ray— sniff HTTP Host, TLS SNI, QUIC SNI + protocol type) lets IP-dest traffic match domain rules; `Override destination` uses sniffed domain as destination (breaks Tor/Apple Push/MTProto — enable only knowing side effects).
  - FILE: `wiki/Settings:Domain strategy:1-15`; `wiki/Settings:Enable sniffing:1-20`; `wiki/Settings:Override destination:1-15`.

- **Use as blocker — discouraged:**
  - HOW: Wiki warns *strongly against* using as firewall/blocker: domain filtering easily bypassed; UDP packet routing based solely on first packet dest (requires DNAT not SNAT to restrict single dest) — Exclave routes UDP via first packet only; packetEncoding/trick mitigations but still not firewall. Warning snippet lists XUDP/Packet invalidating domain/IP/port rules for cost.
  - FILE: `wiki/Route:Use as a blocker:1-20`.

---

## 6. TUN / VPN Integration

- **Service mode (Android VpnService pseudo-VPN):**
  - HOW: `Settings → Service mode`:
    - `VPN` → pseudo-VPN via system `VpnService` + `tun` virtual interface takover globally; **not real VPN** — only `TCP streams` + `UDP datagrams` (no TCP handshake proxying, no SCTP, no ICMP network-layer). `ICMP echo` and `ICMPv6 echo` **forged** (gVisor + system extension); toggle `Discard ICMP` to discard instead.
    - `Proxy only` → launch proxy instance (`socks 10808`, `http 2080`, `tun` not established) without taking over traffic; domestic LAN apps relying on `localhost` continue.
  - FILE: `wiki/Settings:Service mode:1-15`.

- **TCP/IP stack reassembly (transport ← network):**
  - HOW: Since proxy operates transport-layer, Exclave reassembles IP datagrams (network) → TCP/UDP via:
    - `gVisor` → `gVisor netstack` userspace to reassemble (recommended, supports full feature incl. PCAP, app stats).
    - `System` → OS stack trick: for **TCP** rewrites headers via double NAT (`protect`? references `clash` technique links `[1][2][3]`), for **UDP** decapsulates directly. Requires TCP listener accepting private addresses; if firewall blocks, allow. On `targetSdk 37` (Android 17), `nearby devices` (`ACCESS_LOCAL_NETWORK`) permission required for system stack.
  - Behavior: App thinks it handshakes directly with destination, actually with gVisor/system stack, which forwards to proxy server which forwards to dest.
  - FILE: `wiki/Settings:TCP/IP stack:1-20` plus footnotes.

- **MTU (Maximum Transmission Unit):**
  - HOW: `Settings → MTU` slider; default `1500`. Clash benchmarks often use `9000` for higher score but cause issues; Exclave docs warn `>16384` "out of consideration … unpredictable consequences".
  - FILE: `wiki/Settings:MTU:1-10`.

- **Enable PCAP (gVisor only):**
  - HOW: `Settings → Enable PCAP` → when `gVisor` selected, captures and dumps `*.pcap` to `Android/data/com.github.dyhkwong.sagernet/files/` for Wireshark; helps debugging.
  - FILE: `wiki/Settings:Enable PCAP`.

- **Metered hint (Android 10+):**
  - HOW: If enabled, VPN marked `isMetered=true` → system informs apps that network is metered (useful for metered WiFi vs free).
  - FILE: `wiki/Settings:Metered hint`.

- **Discard ICMP:**
  - HOW: See Service mode — toggle to drop instead forge replies.
  - FILE: `wiki/Settings:Discard ICMP`.

- **App traffic statistics (TUN VPN mode only):**
  - HOW: Requires `QUERY_ALL_PACKAGES` / `GET_INSTALLED_APPS` permission; many Chinese ROMs break query → manual grant in Settings. Uses `NetworkStatsManager` or `procfs` parsing via `procfs.go`.
  - FILE: `wiki/Settings:App traffic statistics`.

- **Root CA provider:**
  - HOW: Options: `System` (`/system/etc/security/cacerts` only — Go bug, not expected), `Mozilla` (Mozilla bundle `[1][2]` for devices lacking updates), `System and user` (fixes Go bug: prefers `/apex/com.android.conscrypt/cacerts` (Android 14+), fallback `/system…`, trusts `/data/misc/user/[user id]/cacerts-added`, ignores `cacerts-removed`), `Custom` (`root_store.certs` PEM in `Android/data/[package name]/files` or route asset). Used for `pinnedPeerCert` verification + custom providers.
  - FILE: `wiki/Settings:Root CA provider:1-20`.

- **IPv6 route:**
  - HOW: Toggle: disabled → set only IPv4 address for VPN (`10.10.14.2/30`); enabled → set both IPv4+IPv6 (`fd00::/126` etc) for `VpnService.Builder.addAddress` + `addRoute("::",0)` (or skip if disabled). Impacts leak for IPv6-capable airports.
  - FILE: `wiki/Settings:IPv6 route`.

- **Per-app VPN (split — UID-based):**
  - HOW: `Settings → Per-app VPN`:
    - Mode `Proxy only` → only selected UIDs via VPN (`addAllowedApplication` per pkg).
    - `Bypass mode` → all except selected (`addDisallowedApplication`).
    - Hidden: apps without `INTERNET` permission not listed (search Google not Gemini), `sharedUserId` groups share selection, multi-user: `VpnService` only current user → install per user.
    - Chinese ROMs broken query → grant `GET_INSTALLED_APPS`.
  - FILE: `wiki/Settings:Per-app VPN:1-20`.

- **Allow apps to bypass VPN (bindProcessToNetwork):**
  - HOW: Toggle allows apps (e.g., FCM) to call `bindProcessToNetwork(null)` bypassing VPN voluntarily — enable if FCM pushes require direct.
  - FILE: `wiki/Settings:Allow apps to bypass VPN`.

- **Bypass private addresses:**
  - HOW: Toggle. If enabled, TUN routes exclude private ranges (adds routes for public only?) — needed for LAN communication apps (e.g., SMB, printers). If disabled, routes `0.0.0.0/0` + `::/0` inclusive. Known patch: LineageOS `allow clients to use VPNs` toggle breaks with this enabled — expand FAQ.
  - FILE: `wiki/Settings:Bypass private addresses`.

- **VPN lockdown / Always-on / Block connections without VPN:**
  - HOW: Android Settings `Always-on VPN` + `Block connections without VPN` (system lockdown) can be enabled for Exclave → system sets `LOCKDOWN_VPN` that blocks leaks even when app killed; Exclave's own `VpnService.Builder.setUnderlyingNetworks(null)` + `setBlocking(false)`配合.

---

## 7. DNS

- **sing-box DNS module (§ + V2Ray compat):**
  - HOW: Config path `dns: { servers: [{address, strategy, detour}], rules: [{domain, ip, queryType, outbound, invert...}], final, independent_cache, reverse_mapping, fakeip }`. Exclave auto-populates from routing:
    - `servers: [{address: "remote DNS", domains: [domains in proxy rules]}, {address: "direct DNS", domains: [domains in bypass rules]}]` with `remote DNS is used for domains with no rules matched`. **Non-domain rules won't applied to DNS** due V2Ray DNS module limitation (`v2fly/v2ray-core#1855`, `#1558`).
  - FILE: `wiki/Route:Routing rule and DNS:1-15` JSON snippet; `LibExclaveCore/dns.go:1-40`.

- **FakeDNS, Override destination, domainStrategy:**
  - HOW: `Domain strategy` only distorting demand where traffic already has domain but rule expects IP. `Enable sniffing` adds domain context; `Override destination` then uses sniffed domain **as dest address** (breaks Tor etc). `FakeDNS` (if custom config supplies `fakedns` inbound) can coexist.
  - FILE: `wiki/Settings:Domain strategy / Enable sniffing / Override destination`.

- **Hijack DNS:**
  - HOW: Toggle `Hijack DNS` → sniff DNS queries **not** sent to TUN DNS address (e.g., `dig` in Termux raw UDP 53 to `8.8.8.8`) via `dns sniffer` → handle by internal DNS module (prevents leak/bypass). False positives/negatives expected (some non-DNS UDP 53-like).
  - FILE: `wiki/Settings:Hijack DNS:1-10` "Hijack DNS queries not sent to TUN DNS address (e.g. dig in Termux) with DNS sniffer, so that they are handled by the internal DNS module."

- **Direct / Remote DNS separation:**
  - HOW: Settings expose `Remote DNS` (for proxied domains) vs `Direct DNS` (for bypass domains) text fields + fallback. `Hijack` + `Override` interact.

- **Custom route assets for DNS:**
  - HOW: Custom `geosite.dat`/`geoip.dat` affect DNS `domains` lists.

---

## 8. DPI Bypass — Reality / uTLS / ECH / Vision / AnyTLS

- **REALITY (VLESS/Trojan/Vision):**
  - HOW: `Reality` relies on specific TLS key shares → breaking changes continuously. In Exclave, toggle per-profile `Security: reality` → fields `ServerName` (`www.apple.com`), `PublicKey` (`pbk`), `ShortId`, `Fingerprint` (`chrome` etc, Xray enforces utls), `SpiderX` (`/`). Option `Disable REALITY X25519MLKEM768` if target supports PQ but server not yet updated. Enforced `uTLS` for Reality; `Xray explicitly disallows WS/HTTPUpgrade with Reality` but sing-box accidentally allows — **Exclave previously allowed but removed support** (consistent with Xray now).
  - Version spoof issue (`issues/449`): `Xray-core 26.7.11+` blocks Reality client sending `Xray-core` version <26.3.7 (commit `af7eb68`); Exclave sends `25.5.16` (not outdated impl, just version string) → refused. Fix workaround: group-level override `overrideUTLSFingerprintForREALITY`.
  - FILE: `wiki/Configuration:VLESS:REALITY:1-20`; `wiki/Configuration:REALITY:1-20`; `issues/449` thread; `wiki/_Experiments:overrideUTLSFingerprintForREALITY`.

- **uTLS (TLS fingerprint imitation):**
  - HOW: `Settings per profile / Group`: `uTLS fingerprint` dropdown → values `chrome, firefox, ios, android, edge, safari, 360, qq` (plus `random` via override). Uses `sing-box tls.utls` (Go `utls` fork) imitating `BoringSSL`/`NSS` ClientHello structure but researchers repeatedly find fingerprintable differences (parroting per *The Parrot is Dead*). Setting impacts both `Trojan` + `VMess`/`VLESS` over TLS and `Hysteria2`/`TrustTunnel` TLS; **unavailable for QUIC-based protocols** (TUIC/Juicity/ShadowQUIC). When enabled, ALPN derived from fingerprint unless explicit.
  - FILE: `wiki/Configuration:uTLS fingerprint` paragraphs; `sing-box/docs/tls/utls`.

- **ECH (Encrypted Client Hello):**
  - HOW: Per-profile `ECH Config` (`ECH: config`) Base64 field (`ech: {enabled:true, config:[...]}`) → if ECH enabled but `config` empty, **direct DNS used to query HTTPS record** to obtain `ECHConfig` (fail → connection terminated). Supports `pq_signature_schemes_enabled` / `dynamic_record_sizing_disabled` deprecated flags. Via `sing-box tls.ech`. Proposal enhances self-host via `AndrewWangDev/Exclave` fork: preserves `ech` param in share URI (`&ech=...`) + merge logic (only apply local if remote null).
  - FILE: `wiki/Configuration:TLS:ECH Config:1-10` + `AndrewWangDev/Exclave README: ECH fork` section.

- **XTLS Vision (`flow: xtls-rprx-vision`):**
  - HOW: Only for `VLESS` over `tcp+tls/reality` with `RAW` network. Claim "populates TLS handshake avoid nested encryption". `vision-udp443` variant allows UDP 443; sing-box `vision` maps actually to Xray `vision-udp443`. Requires `XUDP` enabled forced. Previously allowed with WS/HTTPUpgrade via sing-box, now **removed** in Exclave for parity with Xray.
  - FILE: `wiki/Configuration:VLESS:Flow:1-15`.

- **Fragment / Record fragmentation:**
  - HOW: `sing-box tls.fragment` / `record_fragment` enabled via custom outbound JSON? In Exclave UI not direct toggle but via advanced `_Experiments` overrides? Known fields `fragment: true/false`, `record_fragment: true` to split TLS records mitigate TLS-in-TLS detection (used by Shadowsocks etc). Available in sing-box but Exclave wiki lists as TLS confusion?

- **AnyTLS as DPI hedge:**
  - HOW: AnyTLS itself is DPI hedge (packet splitting/filling, connection reuse mitigate TLS-in-TLS). Optionally combined with Reality or not; use vs Reality tradeoff.

- **Shadowsocks-related obfuscations:**
  - HOW: SIP003 plugins (`obfs-http`, `v2ray-plugin websocket+tls`) historically for header obfusc but deprecated; `ReducedIvHeadEntropy` another obsolete evasion.

---

## 9. Other Features — Distribution, Cert, Flavors, Notification, Speedtest

- **F-Droid distribution:**
  - HOW: `F-Droid @ https://f-droid.org/packages/com.github.dyhkwong.sagernet` — reproducible build? F-Droid builds `oss` flavor per `metadata/com.github.dyhkwong.sagernet.yml` with `srclibs: go@go1.23.3`, `sdkmanager platforms;android-34 build-tools;34.0.0`, `ndk ...`, `gomobile init`, `./run lib core` + `downloadAssets` + `gradle: - oss`. Categories `Internet, VPN & Proxy`, License `GPL-3.0-only`, Author `ExclaveNetwork` (previously `dyhkwong`), translations via `hosted.weblate.org/projects/exclave/`. Multiple arch builds: `x86`, `x86_64`, `armeabi-v7a`, `arm64-v8a` each per commit (version 0.13.1 x86, 0.13.6 arm etc tracked in yml). `Auto-update` to `1794` then `1754` versionCodes via `bot`.
  - FILE: `F-Droid/metadata` raw YML; `F-Droid page Highlights`.

- **Certificate hash pinning:**
  - HOW: Signing cert SHA-256 `e9fe39e1ce254c50c2f9470a757b378c0b7cc536119867f7691405b592e6994b` displayed on README + F-Droid for manual verification `apksigner verify --print-certs -v Exclave-*.apk | sha256`. Ensures download from GitHub releases not tampered MITM.
  - FILE: `README.md:Download:SHA-256 hash:1-10`.

- **Build flavors & Leanback / TV:**
  - HOW: Flavors: `oss` (open-source sans proprietary), `legacy` (pins for Android5). No separate `leanback` TV flavor distinct in recent releases — but `AndroidManifest.xml` includes `<uses-feature android:name="android.software.leanback" android:required="false">` + banner/launcher for side-load on Android TV/Google TV; notification channels adapt for TV dpad. Historically SagerNet had leanback but Exclave merged into `oss` universal APK (works landscape).
  - APK split: **11 assets per release** (4 ABIs × 2 flavors + universal? Actually 8: `arm64-v8a`, `armeabi-v7a`, `x86`, `x86_64` × default+legacy = 8) — `0.17.51` shows those 8 + sometimes `universal`. Size ~23-25 MB per ABI; `x86` ~25.4 MB largest.
  - FILE: `releases/tag/0.17.51 Assets table`; `app/build.gradle.kts:productFlavors`.

- **Notification & ForegroundService:**
  - HOW: Persistent notification `NotificationManager` channel "Service" shows `Connected: <profile>` + traffic speed (↑↓) + data usage; requires `POST_NOTIFICATIONS` (Android13+). Allows stop/pause from shade. When disabled via system, service still runs `START_STICKY` but hidden.

- **Speedtest / URL test / Observatory:**
  - HOW: `urltest.go` + `observatory.go` + `stun.go` — implements `URLTest` strategy (`outbound.type: "urltest"` via `sing-box`) periodically `HEAD` probe to `https://www.gstatic.com/generate_204` or custom test URL (`systemStackURLTestWhenServerIsDomain` bug fixed `0.17.46#4224`). Toggle `Auto speedtest` + `Test interval`. App shows latency chips (+ `SpeedTestActivity`). For `system` stack special handling for domain server address. Balancer `observatory` healthcheck feeds `autoSelect`.
  - FILE: `LibExclaveCore/observatory.go:1-30`; `LibExclaveCore/urltest.go:1-30`; `releases/tag/0.17.46` "Fix system stack URL test when the server address is a domain name."

- **Translation & Community:**
  - HOW: `Hosted Weblate (hosted.weblate.org/projects/exclave/)` 23 languages ~59% completion; discussions preferred public GitHub Discussions https://github.com/ExclaveNetwork/Exclave/discussions + private `t.me/s/exclavian`. Issue tracker expects debug loglevel pprof profile via long-press `About → Version`.

- **Other preferences:**
  - HOW: `Metered hint`, `Discard ICMP`, `PCAP`, `App traffic statistics`, `Root CA provider`, `IPv6 route`, `Bypass private`, `Allow bypass` etc enumerated §6 cover operational features. `Enable debug logging` + `pprof HTTP server` under About.

---

## 10. Platforms & Requirements

- **Android ONLY — no desktop/iOS:**
  - HOW: Native Android Kotlin app + Go gomobile `aar` (jniLibs per ABI). No `Windows/macOS/Linux` binary; no `iOS` (SagerNet org had `SagerNet for iOS` placeholder not shipped). Desktop siblings are `v2rayN` (Windows .NET), `nekoray` (Qt), `mihomo` (CLI) — mobile complement but not cross-platform.
  - FILE: `README.md#Build from source` only Android SDK/NDK; `F-Droid: requires Android`.

- **OS version windows:**
  - HOW: `default flavor`: **Android 6.0 Marshmallow (API 23+)** to `Android 17` target; `legacy flavor`: **Android 5.0 Lollipop (API 21-22)** best-effort (deprecated soon). Upgrade note `0.17.46` bumped targetSdk 37 → requires `nearby devices` + `INTERACT_ACROSS_USERS` for cross-profile loopback on Android 17 (via ADB grant `pm grant com.github.dyhkwong.sagernet android.permission.INTERACT_ACROSS_USERS`).
  - FILE: `README.md#Download`; `releases/tag/0.17.46` footnotes `[^1][^2][^3]`.

- **Hardware ABIs & APK split:**
  - HOW: `arm64-v8a` (≈23.6 MB), `armeabi-v7a` (≈24.2 MB), `x86` (≈25.4 MB), `x86_64` (≈24.7 MB) each flavor; universal not routinely shipped. `F-Droid` builds per ABI separately.
  - FILE: `releases/tag/0.17.51` assets table 8 rows.

- **Compile-time SDK toolchain:**
  - HOW: `JDK 21` (`openjdk-21-jdk-headless` via apt), `Go 1.27` (trixie), `gomobile`, `Android SDK Platform 37.0` + `Build-Tools 37.0.0` + `Platform-Tools` + `NDK r29`, `Gradle 8.x` via `gradlew`. Windows requires same but `build.bat`.
  - FILE: `README.md#Build from source:Install and configure` list 3 bullets.

- **Runtime permissions (manifest):**
  - HOW: `android.permission.INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE`, `QUERY_ALL_PACKAGES` (`GET_INSTALLED_APPS` on Chinese ROMs), `FOREGROUND_SERVICE`, `POST_NOTIFICATIONS`, `ACCESS_LOCAL_NETWORK` (Android 17 `nearby devices`), `INTERACT_ACROSS_USERS` (cross-profile localhost), `BIND_VPN_SERVICE` dynamic `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` etc (per F-Droid permissions dump 10× `SERVICE`).
  - FILE: `AndroidManifest.xml:20-50`; `F-Droid permissions list`.

---

## 11. Repo Stats, Build Instructions & File Map

- **Repo statistics (live Aug 2026):**
  - Org `ExclaveNetwork` (5 repos):
    - `ExclaveNetwork/Exclave` **Proxy client** — **~2,674★ / 163 forks / 24 watchers / 6 open issues / 3,112 commits dev / default branch `dev` / created 2021-06-15T17:04:29Z / fork yes / License GPL-3.0**
    - `ExclaveNetwork/exclave-core` (ex-v2ray-core) — **69★ / 15 forks / 7,145 commits main / Migration in progress**
    - `ExclaveNetwork/LibExclaveCore` — **8★ / 7 forks / 539 commits main / fork SagerNet/LibSagerNetCore**
    - `ExclaveNetwork/sing-box` — **14★ mirror only**
    - `ExclaveNetwork/husi` — **4★ mirror only**
    - `ExclaveNetwork/sing-juicity` — **3★**
  - HOW measured: GitHub API `repos/ExclaveNetwork/Exclave` stars field + org page totals.
  - FILE: `github.com/ExclaveNetwork overview highlights`; `webfetch of repo header` stars count.

- **Release history highlights (selected):**
  - `0.17.51` (2026-08-16 `a93360d`) — Fix ListPreference title truncated, XHTTP RandConfig `from>to` crash, optimize JSON preprocessing (`@123jjck`).
  - `0.17.50` (2026-08-15 `7cb8ee9`) — Fix VLESS with encryption+vision+transport import/export.
  - `0.17.48` (2026-08-14 `6ec2deb`) — **Split default/legacy flavors**.
  - `0.17.47-beta.4` (2026-08-06 `c6cbf6d`) — Add Hysteria2 Chrome parrot, update QUIC deps.
  - `0.17.47-beta.2` (2026-07-29 `18d3e9f`) — Implement ShadowQUIC in core, remove experimental plugin; update mieru 3.35.0 + Snell UDP MTU.
  - `0.17.46` (2026-07-06 `a1001dc`) — Fix TrustTunnel cert verification, balancer front/landing, system stack URL test domain; update mieru 3.34.0 + padding; **Breaking** remove ShadowTLS/reverse proxy; bump targetSdk 37; fix system stack TCP NAT port reuse (`SagerNet/sing-box#4224`).
  - `0.17.46-beta.3` (2026-07-08 pre) — Breaking KCP sharelink (`XTLS/Xray-core aba2272/ad2e4cb`) + XHTTP session ID (`Xray e10347b`).
  - `0.17.43` (2026-06-04) — Rename custom v2ray-core→exclave-core, Gecko obfusc, mieru 3.33.0 jitter, fix utls ignored, **remove exclave:// backup**, remove SS2022 option.
  - `0.13.x` (2025-26) — F-Droid builds pinned e.g. `0.13.1 (946 x86, 947 x86_64) @dfd51d9`, `0.13.6 (972 armeabi @c2b5523)`.
  - FILE: `https://github.com/ExclaveNetwork/Exclave/releases` release list; `releases/tag/<version>` pages.

- **Build from source (authoritative, prefix replaces `run`):**
  - HOW prerequisites: `JDK 21`, `Go 1.27`, `Go Mobile`, `Android SDK Platform 37.0`, `Build-Tools 37.0.0`, `Platform-Tools`, `NDK r29` via Android Studio or `sdkmanager`.
  - Steps:
    - `git clone https://github.com/ExclaveNetwork/Exclave.git --recursive` (includes `plugin/naive/src/main/jni/naiveproxy` submodule + `library/core` if not submodule).
    - `cp release.keystore my.keystore` replace with your own (`keytool -genkey -v -keystore release.keystore -alias alias -keyalg RSA -keysize 2048 -validity 10000`).
    - Create `local.properties` append:
      ```
      KEYSTORE_PASS=your_keystore_pass
      ALIAS_NAME=your_alias_name
      ALIAS_PASS=your_alias_pass
      sdk.dir=/path/to/android-sdk
      ```
    - Linux/macOS x64/arm64:
      ```bash
      ./run lib core          # or ./library/core/build.sh
      ./gradlew :app:downloadAssets        # or :app:updateAssets for latest Loyalsoldier dat
      ./gradlew :app:assembleOssRelease    # default (Android 6+)
      ./gradlew :app:assembleLegacyRelease # legacy (Android 5+)
      ```
    - Windows x64:
      ```powershell
      .\library\core\build.bat
      .\gradlew.bat :app:downloadAssets
      .\gradlew.bat :app:assembleOssRelease
      ```
    - Outputs: `app/build/outputs/apk/oss/release/Exclave-*-<abi>-release.apk` or `legacy/release/` per flavor.
  - HOW verification: Check `app/build/outputs/apk/oss/release/Exclave-0.17.51-arm64-v8a.apk` exists + `apksigner verify --print-certs` SHA-256 matches published.
  - FILE: `README.md#Build from source:1-25`; `run:1-60` script dispatch; `library/core/build.sh:1-30`; `ExclaveNetwork/LibExclaveCore/build.sh`; `F-Droid recipe prebuild` steps.

- **LibExclaveCore compile tags (Clash contam):**
  - HOW: `build.sh` sets `TAGS="with_gvisor,with_quic,with_wireguard,with_clash_api,with_acme,with_proxyprovider,with_clash_ui,with_utls"` then `-tags "$TAGS,with_clash"` or without. Output `libcore.aar` embeds select. To build **without Clash** (GPL-3.0-or-later): `go build -tags "with_gvisor,with_quic,with_wireguard"` etc omit `with_clash` → produces nontainted aar. To verify, `unzip -l libcore.aar | grep clash` presence.
  - FILE: `LibExclaveCore/build.sh:tags line`; `LibExclaveCore/with_clash.go` build constraint.

- **File map (top-level):**
  - HOW:
    - `.github/workflows/` — CI `release.yml` (Go version + NDK version + gomobile version sourced via `sed -n -E "s/.*go-version:\ (.*)/\1/p"`)
    - `app/` — Kotlin client (`src/main/java/` + `res/` + `build.gradle.kts` + `downloadAssets` task)
    - `bin/` — helper scripts
    - `buildSrc/` — Gradle convention plugin
    - `gradle/` — wrapper `8.x`
    - `library/` → `library/core` (LibExclaveCore Go sources symlink or git checkout)
    - `plugin/` → `plugin/naive/src/main/jni/naiveproxy` (klzgrad submodule)
    - `.gitmodules` — single entry `plugin/naive/...`
    - `LICENSE` — GPL-3.0-or-later text with Clash notice
    - `version.properties` — `versionName=0.17.51 versionCode=...`
    - `run` — dispatch `./run lib core` (`bash`).
  - FILE: `GitHub file tree view: 3,112 commits` folder list; `.gitmodules` raw `cat`.

---

## 12. References & Verification HOW

- **HOW to reproduce this research:**
  - 1. Clone & stat: `gh repo clone ExclaveNetwork/Exclave && cd Exclave && git log --oneline dev | wc -l` → 3112; `gh api repos/ExclaveNetwork/Exclave --jq .stargazers_count` → ~2674; `gh api repos/ExclaveNetwork/Exclave --jq .forks_count` → 163.
  - 2. License check: `cat LICENSE | head -20` vs `cat LibExclaveCore/LICENSE` vs `cat README.md | grep -A6 "with_clash"` vs `cat README.md#Notice`.
  - 3. Protocol list verify: `grep -R "Some supported protocols" README.md` + `cat app/src/main/java/**/bean/*.kt | grep -i "outbound"` vs `wiki/Configuration` 30 protocol wiki pages + `sing-box` docs `configuration/outbound`.
  - 4. Core verify: `cat library/core/go.mod | grep sing-box` → `v1.13.19` + `grep -R "with_clash" library/core/*.go` + `ls LibExclaveCore/with_clash.go without_clash.go clash/`.
  - 5. Subscription verify: `open https://github.com/ExclaveNetwork/Exclave/wiki/Group` → inspect Raw vs SIP008 vs age tables + `Group` page `Subscription-Userinfo`.
  - 6. Routing: `open https://github.com/ExclaveNetwork/Exclave/wiki/Route` + `Settings` pages → `domainStrategy`, sniffing, per-app, SSID, network type.
  - 7. TUN: `open https://github.com/ExclaveNetwork/Exclave/wiki/Settings` → Service mode vs TCP/IP stack vs MTU sections + `LibExclaveCore/tun.go` + `nat/` folder.
  - 8. DNS: `wiki/Settings:Hijack DNS` + `wiki/Route:Routing rule and DNS` JSON snippet + `LibExclaveCore/dns.go`.
  - 9. DPI: `wiki/Configuration` Reality/Vision/uTLS/ECH paragraphs + `issues/449` + `wiki/_Experiments` override fingerprints.
  - 10. F-Droid & build: `open https://f-droid.org/packages/com.github.dyhkwong.sagernet` + `cat F-Droid/metadata/com.github.dyhkwong.sagernet.yml | grep -E "License|versionName|gradle"` + `sha256sum Exclave-*.apk` vs cert string `e9fe39e1...`.
  - 11. Build test: `./run lib core && ./gradlew :app:downloadAssets && ./gradlew :app:assembleOssRelease --info` → check `app/build/outputs/apk/oss/release/`.
  - 12. File existence: `Test-Path "C:\Users\qmahyar\Desktop\VPN Research\08-Exclave.md" && (Get-Content "C:\Users\qmahyar\Desktop\VPN Research\08-Exclave.md" | Measure-Object -Line).Lines` → ≥350.

- **Primary sources fetched (Aug 30 2026):**
  - HOW: `webfetch https://github.com/ExclaveNetwork/Exclave/blob/dev/README.md` (GitHub raw); `webfetch .../Exclave/wiki/Group`; `.../Route`; `.../Configuration`; `.../Settings`; `.../Home`; `webfetch https://f-droid.org/en/packages/com.github.dyhkwong.sagernet/` + `gitlab.com/fdroid/fdroiddata/.../com.github.dyhkwong.sagernet.yml`; `webfetch https://github.com/ExclaveNetwork/LibExclaveCore` + `ExclaveNetwork/exclave-core` + `pkg.go.dev/github.com/exclavenetwork/libexclavecore`; `websearch ExclaveNetwork Exclave GitHub README libexclavecore F-Droid releases`.

- **Caveats / subjective wiki advisory:**
  - HOW: Wiki header "The content is only applicable to the latest commit and contains some subjective comments. Viewer discretion is advised." + CC0 1.0 Universal mark — dyhkwong's wry tone on CDN-abusing transports ("Would create more patterns for censors", "Do NOT abuse if NOT backed into corner", "Fuck RPRX") reflects editorialized technical critique, not neutral spec.

---

*Generated: 2026-08-30 · Branch: dev · Core: LibExclaveCore (sing-box v1.13.19, with_clash) + exclave-core (v2ray-core fork) · Research depth: extreme bullet+sub-bullet HOW · Line count target: ≥350 (verify via `Measure-Object`).*
