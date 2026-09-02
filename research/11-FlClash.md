# FlClash (chen08209/FlClash) — Extreme-Detail Research

> Multi-platform proxy client based on ClashMeta / Mihomo — Flutter + Go — Open-source, ad-free — 50k+ stars

---

## Table of Contents

- [1. Overview — HOW FlClash Is Positioned](#1-overview--how-flclash-is-positioned)
- [2. Supported Protocols via Mihomo/ClashMeta — HOW Each Works](#2-supported-protocols-via-mihomoclashmeta--how-each-works)
- [3. Subscription / Config Formats — HOW FlClash Parses Configs](#3-subscription--config-formats--how-flclash-parses-configs)
- [4. Core — Mihomo (ClashMeta) Go Core — HOW Frontend Talks to Core](#4-core--mihomo-clashmeta-go-core--how-frontend-talks-to-core)
- [5. Split Tunneling / Routing — HOW Clash Rule Engine Works](#5-split-tunneling--routing--how-clash-rule-engine-works)
- [6. TUN vs System Proxy — HOW Traffic Interception Differs](#6-tun-vs-system-proxy--how-traffic-interception-differs)
- [7. DNS — HOW Clash DNS + FakeIP Works](#7-dns--how-clash-dns--fakeip-works)
- [8. Proxies & Groups — HOW Proxy Selection & Health Check Works](#8-proxies--groups--how-proxy-selection--health-check-works)
- [9. Other Features — HOW Data Sync, Overwrite, Backup, Logs Work](#9-other-features--how-data-sync-overwrite-backup-logs-work)
- [10. Platforms — HOW FlClash Behaves Per OS](#10-platforms--how-flclash-behaves-per-os)
- [11. Repo Stats, Releases, Build — HOW to Build & Track](#11-repo-stats-releases-build--how-to-build--track)
- [12. References & Verification](#12-references--verification)

---

## 1. Overview — HOW FlClash Is Positioned

- **What it is**
  - Multi-platform proxy client based on ClashMeta (now **Mihomo**)
    - Tagline verbatim: `A multi-platform proxy client based on ClashMeta, simple and easy to use, open-source and ad-free.`
    - Not a VPN service — it is a **client** that connects to user-provided proxy subscriptions / self-hosted nodes
  - Bridges a Flutter/Dart UI with a Go networking core
    - UI handles profiles, groups, rules, logs; core handles actual TCP/UDP proxying, routing, DNS

- **License & philosophy**
  - Licensed **GPL-3.0** (`LICENSE` at repo root)
    - `https://github.com/chen08209/FlClash/blob/main/LICENSE` → GPL-3.0 badge in README
  - Fully open-source, **ad-free**, no tracking SDKs
    - Contrast with many closed-source Clash GUIs that bundle ads / analytics
  - Community-driven, starred history SVG shown in README: `https://api.star-history.com/svg?repos=chen08209/FlClash&Date`

- **Tech stack**
  - **Flutter / Dart** for presentation layer
    - `lib/` contains app controllers, Riverpod providers, screens (desktop vs mobile adaptive)
    - `pubspec.yaml` pins Flutter + plugins (window_manager, tray, vpn_service, sqlite via Drift, etc.)
  - **Go** for proxy core
    - `core/` directory is a Go module importing `github.com/metacubex/mihomo` (ClashMeta)
    - Compiled to platform-native binaries / libs and embedded via FFI / platform channels
  - **Material You design**
    - README: `Based on Material You Design, Surfboard-like UI` (links to `getsurfboard/surfboard`)
    - Adaptive multiple screen sizes, multiple color themes, dark mode, custom primary color / text scaling (added v0.8.83+)
  - **SQLite via Drift** for persistence (since v0.8.92 `Add sqlite store`)
    - Replaced SharedPreferences-only store for profiles, settings, connections history

- **Cross-platform claim — HOW it delivers**
  - **Android** (including Android TV launcher), **Windows** (amd64 + arm64), **macOS** (Intel + Apple Silicon), **Linux** (amd64 + arm64)
    - Single Flutter codebase, platform-conditional code for VPNService / tray / TUN / WebDAV
  - Build matrix in `setup.dart`: `dart setup.dart android | windows | linux | macos`
    - Releases publish **16 assets** per tag (APK splits + desktop installers + archives)

- **Scale & popularity**
  - **Stars:** **50.3k** (as of 2026-08, webfetch live count; README badge shows ~50k+)
  - **Forks:** **3.2k**
  - **Watchers:** 144
  - **Issues:** ~483 open, **PRs:** ~89 open — active maintenance
  - **Downloads badge:** `img.shields.io/github/downloads/chen08209/FlClash/total` — millions cumulative
  - **F-Droid:** Self-hosted repo at `chen08209.github.io/FlClash-fdroid-repo` with fingerprint `789D6D32668712EF7672F9E58DEEB15FBD6DCEEC5AE7A4371EA72F2AAE8A12FD`
  - **Homebrew (macOS):** `brew tap chen08209/tap && brew install --cask flclash`
  - **Telegram channel:** `https://t.me/FlClash` (badge in README)

- **Why users pick FlClash over alternatives**
  - Versus **Clash for Windows / ClashX** (archived, original Clash kernel) — FlClash uses **mihomo** → supports VLESS/Reality, Hysteria2, TUIC, WireGuard where old clients show `unsupported proxy type`
  - Versus **Clash Verge Rev / Clash Nyanpasu** — FlClash adds **mobile** (Android + TV) + WebDAV sync + single Flutter UI across all 4 OSes
  - Versus **SagerNet / Surfboard / sing-box clients** — FlClash speaks **Clash YAML natively** (no conversion needed) while still accepting sing-box-style subscriptions via Mihomo compatibility

- **Tagline features (README verbatim)**
  - `✈️ Multi-platform: Android, Windows, macOS and Linux`
  - `💻 Adaptive multiple screen sizes, Multiple color themes available`
  - `💡 Based on Material You Design, Surfboard-like UI`
  - `☁️ Supports data sync via WebDAV`
  - `✨ Support subscription link, Dark mode`

---

## 2. Supported Protocols via Mihomo/ClashMeta — HOW Each Works

> FlClash itself implements **no proxy protocol** — it delegates 100% to the **Mihomo (ClashMeta) Go core** (`core/go.mod` → `github.com/metacubex/mihomo`). The list below is the Mihomo adapter registry in `constant/adapters.go` plus `docs/config.yaml` examples.

- **Full Mihomo adapter enum** (`constant/adapters.go:18-45`)
  - `Direct`, `Reject`, `RejectDrop`, `Compatible`, `Pass`, `Dns` (built-in policies)
  - `Relay`, `Selector`, `Fallback`, `URLTest`, `LoadBalance` (group types)
  - `Shadowsocks`, `ShadowsocksR`, `Snell`, `Socks5`, `Http`, `Vmess`, `Vless`, `Trojan`, `Hysteria`, `Hysteria2`, `WireGuard`, `Tuic`, `Ssh`
  - Listener-only inbounds also add: `AnyTLS`, `Mieru`, `Sudoku`, `ShadowQUIC`, `VLESS`, `TUIC v4/v5`, `Hysteria2`, `ShadowSocks`, `VMess`, `Trojan`, `Snell`, `MASQUE`, `TrustTunnel`, `ZeroTier`, `OpenVPN`, `Tailscale`

- **Shadowsocks (SS) — `type: ss`**
  - HOW it works: Symmetric-encrypted TCP/UDP relay; minimal handshake; AEAD ciphers
  - Ciphers supported by Mihomo:
    - `aes-128-gcm`, `aes-192-gcm`, `aes-256-gcm`
    - `aes-128-cfb`, `aes-192-cfb`, `aes-256-cfb`, `aes-128-ctr`, `aes-192-ctr`, `aes-256-ctr`
    - `rc4-md5`, `chacha20-ietf`, `xchacha20`
    - `chacha20-ietf-poly1305`, `xchacha20-ietf-poly1305`
    - `2022-blake3-aes-128-gcm`, `2022-blake3-aes-256-gcm`, `2022-blake3-chacha20-poly1305` (2022-series, stronger)
  - Optional `plugin: obfs` / `plugin: v2ray-plugin` (simple-obfs, WebSocket obfuscation)
  - HOW FlClash uses: Show cipher/password per node, `udp: true` toggle, `udp-over-tcp`, `ip-version` selector
  - Best for: General use, low-end routers, low CPU (ChaCha20 friendly without AES-NI)

- **ShadowsocksR (SSR) — `type: ssr`**
  - Legacy obfuscated SS fork; still parsed by Mihomo for backward compat
  - Fields: `obfs`, `protocol`, `obfs-param`, `protocol-param`
  - HOW to think: Use only if provider still emits SSR; prefer SS 2022 or VLESS for new deploys

- **VMess — `type: vmess`**
  - HOW it works: V2Ray native protocol; UUID + alterId + `cipher: auto/aes-128-gcm/chacha20-poly1305/none`; timestamp auth; pluggable transports
  - Transports (via `network:`): `tcp`, `ws`, `grpc`, `h2`, `http` (via `ws-opts` / `h2-opts` / `grpc-opts`)
  - TLS options: `tls: true`, `sni`, `alpn`, `fingerprint` (SSL pinning), `client-fingerprint: chrome/firefox/safari/ios/random`, `skip-cert-verify`, `ech-opts` (ECH)
  - `mTLS` support: `certificate` + `private-key` PEM
  - `smux` multiplex: `protocol: smux/yamux/h2mux`, `max-connections`, `min-streams`, `max-streams`, `padding`, `only-tcp`
  - HOW FlClash uses: Auto-detects `vmess://` subscription links, renders WS path/headers, shows delay test per node
  - Caveat: More overhead than VLESS due to inner encryption; needs Mihomo (original Clash shows `unsupported`)

- **VLESS — `type: vless` (Mihomo-exclusive)**
  - HOW it differs from VMess: **No inner encryption** — delegates confidentiality to outer TLS; shorter header, less CPU
  - Requires `tls: true` (bare VLESS without TLS is rejected by Mihomo)
  - Key fields: `uuid`, `flow` (e.g., `xtls-rprx-vision` — XTLS Vision direct passthrough), `client-fingerprint`, `reality-opts`, `ech-opts`
  - **Reality** (VLESS + Reality): `reality-opts: { public-key, short-id, server-name, fingerprint }` — borrows real site's TLS fingerprint, no need for own cert/domain
  - **Vision** (`flow: xtls-rprx-vision`): Cuts double-encryption copy for high-throughput; must match server exactly or handshake fails
  - WHY Mihomo-only: Original Clash kernel never implemented VLESS/Reality; FlClash inherits support automatically
  - HOW FlClash uses: Renders Reality fields, warns on mismatched flow/fingerprint, supports `udp: true/false`

- **Trojan — `type: trojan`**
  - HOW it works: Password auth over **TLS 443**, disguised as HTTPS; outside observer sees normal TLS ClientHello
  - Fields: `password`, `sni`, `alpn: [h2, http/1.1]`, `client-fingerprint`, `fingerprint` (pinning), `skip-cert-verify`, `udp: true`, `ech-opts`
  - Transports: plain TLS, `network: ws` (`ws-opts`), `network: grpc` (`grpc-opts` with `grpc-service-name`, `ping-interval`, `max-connections`)
  - `ss-opts` (trojan-go style shadowing): `enabled`, `method`, `password` — inner SS inside Trojan
  - Self-host guidance: Needs domain + cert → best disguise; falls back to Trojan+WS+TLS on CDN

- **HTTP / HTTPS / SOCKS5 — `type: http`, `type: socks5`**
  - Plain relay, no encryption (or TLS for `https`); `username`/`password`, `tls`, `sni`, `skip-cert-verify`
  - FlClash uses as **local inbound** (`mixed-port: 7890`) and as **outbound** node types for upstream corporate proxies
  - HOW to think: Useful for LAN sharing / debugging / chaining; anti-blocking `Very Low`, keep for compat

- **Snell — `type: snell` (versions 1-4)**
  - HOW it works: Surge's lightweight obfuscated proxy; Mihomo supports `version: 2..4`, `obfs-opts: { mode: http/tls, host }`
  - Note: `No UDP support yet` in `docs/config.yaml` comment for Snell — verify per version

- **Hysteria (v1) — `type: hysteria`**
  - HOW it works: QUIC-like UDP with aggressive congestion control; declares `up`/`down` bandwidth; HTTP/3 masquerade
  - Fields: `auth-str` / `auth_str`, `obfs`, `protocol`, `up`/`down` (e.g., `50 Mbps`), `sni`, `alpn`, `skip-cert-verify`
  - Status: Superseded by Hysteria2; Mihomo keeps for compat but prefers `hysteria2`

- **Hysteria2 — `type: hysteria2` (Mihomo-exclusive, QUIC)**
  - HOW it works: Over **QUIC/UDP** (RFC 9000); 0-RTT resumption, connection migration (Wi-Fi ↔ cellular keeps session), userspace congestion (BBR-like aggressive fill)
  - Fields: `password` (auth), `obfs` / `obfs-password`, `up` / `down` (link bandwidth), `sni`, `alpn`, `skip-cert-verify`, `ports`, `fingerprint`, `pinSHA256`
  - Transport note: `ports` can be `server:port` or range; `masquerade` option for HTTP/3 disguise
  - Pros: Highest throughput on lossy/high-latency links; 0-RTT beats TCP+TLS handshake
  - Cons: Needs UDP not blocked; heavier battery if idle-keepalive mis-tuned
  - FlClash config: `Hysteria2` node cards show up/down, obfs toggle, QUIC status

- **TUIC v5 — `type: tuic` (Mihomo-exclusive, QUIC)**
  - HOW it works: **TCP-over-QUIC** (TUIC = TCP/UDP over QUIC); two UDP relay modes:
    - `native` — UDP datagrams → QUIC datagrams (lowest latency, gaming/voice)
    - `quic` (over stream) — UDP folded into reliable QUIC stream
  - Auth: `token` **or** `uuid` + `password` (flexible), `congestion-controller: bbr/cubic/new_reno`, `udp-relay-mode`, `heartbeat-interval`, `sni`, `alpn: h3`, `skip-cert-verify`, `disable-sni`, `reduce-rtt`
  - Versus Hysteria2: TUIC is **less aggressive** (uses standard QUIC CC), more graceful under UDP throttling; Hysteria2 pushes bandwidth harder
  - FlClash config: TUIC nodes show congestion choice, relay mode, 0-RTT indicator

- **WireGuard — `type: wireguard` / `wg`**
  - HOW it works: Modern L3 VPN (kernel 5.6+, <4000 LOC, noise protocol); Mihomo integrates natively so WG can be a node like SS
  - Fields: `private-key`, `public-key`, `pre-shared-key`, `server`, `port`, `ip`/`ipv6`, `allowed-ips` (distinct per peer), `reserved` (WARP), `mtu`, `dns`, `keepalive`, `workers`, `udp: true`
  - Multi-peer: When `peers:` array present, top-level `server/port/public-key` ignored except `private-key`
  - **AmneziaWG** extension (obfuscated WG): `amnezia-wg-option: { jc, jmin, jmax, s1..s4, h1..h4 }` — junk packets to evade DPI
  - Use case: VPS owners, WARP nodes, integrate WG into Clash rule engine without separate app
  - FlClash handling: WG peers rendered as expandable list, reserved field for WARP

- **SSH — `type: ssh`**
  - HOW it works: Tunnel via SSH ( `server`, `port`, `username`, `password` or `private-key`, `host-key` )
  - Niche: Reuse existing SSH server as proxy; not many providers emit SSH links but Mihomo keeps adapter for completeness

- **AnyTLS — `type: anytls` (Mihomo-exclusive)**
  - HOW it works: TLS-based lightweight proxy introduced in Mihomo; `password`, `sni`, `alpn`, `skip-cert-verify`, `client-fingerprint`
  - Capability flag: `MIHOMO_CAPABILITIES` includes `AnyTls` (seen in `target_profile.rs:79`)
  - Purpose: Alternative to Trojan/VLESS when you want TLS without VMess overhead but with fresh obfuscation

- **Mieru / Sudoku / ShadowQUIC / MASQUE / TrustTunnel / ZeroTier / Tailscale / OpenVPN — inbound + outbound**
  - HOW to think: Mihomo is expanding beyond classic outbound proxies into **inbound listeners** (`config/inbound/listeners/`) and niche protocols
  - FlClash exposes only the outbound subset that subscriptions actually emit; the rest are visible in `docs/config.yaml` / `wiki.metacubex.one/en/config/proxies/` for advanced self-hosters
  - Example: `Mieru` (`mieru`), `Sudoku` (`sudoku`), `ShadowQUIC` (`shadowquic`) appear in `constant/adapters.go` comments and `config/inbound` docs

- **Transport & TLS common knobs (across protocols)**
  - `udp: true/false` — enable UDP relay (critical for DNS, gaming, calls)
  - `udp-over-tcp: false` — tunnel UDP inside TCP (fallback when UDP blocked)
  - `ip-version: dual / ipv4 / ipv6 / ipv4-prefer / ipv6-prefer` — node DNS resolution preference; TCP concurrent needs `tcp-concurrent: true`
  - `tfo` (TCP Fast Open), `mptcp` (Multipath TCP), `smux` multiplex, `fingerprint` pinning, `ech-opts` (Encrypted ClientHello), `client-fingerprint` (uTLS)
  - `dialer-proxy`, `interface-name` (bind to `tailscale0` etc.), `routing-mark` (fwmark 233), `skip-cert-verify`, `servername` override
  - HOW FlClash surfaces: Per-node override sheet (`override:` in proxy-provider) can flip `tfo/mptcp/udp/interface-name/routing-mark` globally

---

## 3. Subscription / Config Formats — HOW FlClash Parses Configs

- **Primary format: Clash YAML (Mihomo-compatible)**
  - HOW it looks — top-level keys FlClash expects:
    - `mixed-port: 7890` / `port` / `socks-port` / `redir-port` / `tproxy-port`
    - `allow-lan`, `bind-address`, `ipv6`, `unified-delay`, `tcp-concurrent`, `keep-alive-interval`
    - `mode: rule / global / direct`
    - `log-level: info/warning/error/debug/silent`
    - `external-controller: 127.0.0.1:9090` + `secret` (FlClash sets internally for Flutter↔core IPC)
    - `proxies: []` — inline node list
    - `proxy-providers: {}` — remote subscription dict
    - `proxy-groups: []` — select/url-test/fallback/load-balance/relay
    - `rules: []` — ordered rule lines
    - `rule-providers: {}` — remote rule sets
    - `dns: {}` — DNS block
    - `tun: {}` — TUN block
    - `sniffer: {}` / `profile: {}` / `geodata-mode` / `geox-url` / `hosts`
  - FlClash **parses directly** — no intermediate sing-box → Clash conversion needed for Clash YAML

- **Secondary: Mihomo YAML extensions**
  - HOW it extends Clash:
    - Extra proxy types: `vless`, `tuic`, `hysteria`, `hysteria2`, `wireguard`, `anytls`, `mieru`…
    - Extra rule types: `GEOSITE`, `GEOIP` with `geodata-mode: true` + `geox-url`, `RULE-SET` with `behavior: domain/ipcidr/classical` + `format: yaml/text/mrs`
    - Extra DNS: `nameserver-policy`, `proxy-server-nameserver`, `direct-nameserver`, `fallback-filter: { geoip:true, geoip-code: CN, geosite, ipcidr, domain }`, `fake-ip-filter-mode: blacklist/whitelist/rule`
    - Extra TUN: `stack: system/gvisor/mixed`, `strict-route`, `gso`, `route-address`, `include-package` (Android)
  - Backward compat: Mihomo **accepts** original Clash YAML unchanged (one-way compat — original Clash chokes on Mihomo fields)

- **Subscription links — HOW FlClash ingests**
  - Supported URI schemes (via Mihomo + Flutter link parser):
    - `http://` / `https://` returning Clash YAML (most common: provider gives `https://sub.example.com/clash?token=xxx`)
    - `clash://` / `clashmeta://` / `mihomo://` scheme handled via Android intent + `com.follow.clash.action.*`
    - Inline `proxies:` YAML pasted manually (clipboard import)
    - QR code import (mobile scanner, since v0.8.1 `Add import profile via QR code image`)
  - HOW FlClash refreshes:
    - Per-provider `interval: 3600` (seconds), `health-check: { enable, url, interval, timeout, lazy, expected-status }`
    - Manual: Profiles page → pull-to-refresh / `Update` button; global `one-click update all profiles` (v0.8.16)
    - `User-Agent` spoofing: default `mihomo/1.18.3`, customizable via `request ua` / `global-ua` (v0.8.94 `Support custom global-ua`)
    - Redirect handling via `global-ua` avoids 302 loops on some providers

- **Proxy-providers — HOW remote node sets work**
  - Types: `http` (remote URL), `file` (local path), `inline` (embedded `payload:`)
  - Key fields per provider:
    - `url`, `path` (cache file, default MD5(url)), `interval`, `proxy: DIRECT` (fetch via proxy or direct), `size-limit`, `header: { User-Agent, Authorization }`
    - `age-secret-key` for age-encrypted providers
    - `override:` — rewrite on load: `tfo`, `mptcp`, `udp`, `down/up`, `skip-cert-verify`, `dialer-proxy`, `interface-name`, `routing-mark`, `additional-prefix/suffix`, `proxy-name: { pattern, target }`, `override-expr` (jq-like)
    - `filter` (include regex, ` separated), `exclude-filter`, `exclude-type: ss|http` (| separated)
  - FlClash GUI: Providers page shows health-check status, filter editor, override toggles

- **Clash Verge / Stash compat**
  - HOW FlClash handles:
    - Verge `script` / `merge` semantics → mapped to FlClash `custom overwrite` / `override script` (v0.8.81 `Add rule override`, v0.8.85 `Support override script`)
    - Stash capabilities (no uTLS) → FlClash keeps `client-fingerprint` toggle so Stash-emitted configs still load
    - `extends`? Not native to Clash — FlClash ignores unknown top-level keys rather than failing

- **sing-box JSON — HOW it does NOT natively work**
  - Mihomo/FlClash **does not** parse sing-box JSON directly (`{ "outbounds": [...] }`)
  - Workaround paths:
    - Provider side: most sing-box providers also offer `&flag=clash` / `&target=clash` endpoint that returns Clash YAML
    - Client side: use subconverter (`target_profile.rs` → `MIHOMO_CAPABILITIES` maps `ClashFlavor::Mihomo`) to convert sing-box JSON → Mihomo YAML before import
    - Manual: paste sing-box `outbounds` into a YAML `proxies:` block with `type:` remapping (error-prone, not recommended)

- **Profile management inside FlClash**
  - `profiles sort` (v0.8.53), search bar (v0.8.85 `Support proxies search`), file editor (v0.8.73 `Add file editor`)
  - Raw YAML editor with syntax highlight, `hosts override` (v0.8.57), `DNS override`, `rule override`
  - `custom overwrite` (v0.8.93) — JavaScript-like override script that merges into loaded YAML before core restart

---

## 4. Core — Mihomo (ClashMeta) Go Core — HOW Frontend Talks to Core

- **What Mihomo is**
  - Fork lineage: **Original Clash** (archived, premium TUN closed-source) → **ClashMeta / Clash.Meta** (community fork, added VLESS/Hysteria/TUIC/WG) → **Mihomo** (renamed, actively maintained, now `github.com/metacubex/mihomo`)
  - `KERNEL mihomo` badge on Clash ecosystem sites indicates modern protocol support
  - Go 1.21+ module, compiled per platform; FlClash pins version in `core/go.mod` and bumps in changelog (`Update core` entries every few releases)

- **Core build & embedding — HOW Flutter ships Go**
  - `core/` is a Go module with `hub.go`, `common.go`, `go.mod`
  - `setup.dart` drives cross-compilation:
    - Android: `ANDROID_NDK` + `gomobile` → `.aar` / `.so` per ABI (arm64-v8a, armeabi-v7a, x86_64)
    - Windows: `GCC` (mingw) + `CGO_ENABLED=1` → `flclash.exe` + `core.dll` + Inno Setup installer
    - Linux: `GCC` + `libayatana-appindicator3-dev` + `libkeybinder-3.0-dev` → ELF binary + `.deb` (declared in v0.8.83)
    - macOS: Xcode + `CGO` → `.app` + helper service (service mode)
  - `git submodule update --init --recursive` pulls `mihomo` as submodule
  - FFI bridge: `plugins/` + `lib/core/` expose Dart FFI bindings to `core.hub` exported C functions

- **Two communication paths — HOW Flutter↔Go talks**
  - **FFI (Foreign Function Interface) — primary**
    - Flutter calls Go functions directly (zero-copy where possible): `handleStartListener`, `handleInitClash`, `applyConfig`, `updateListeners`
    - Low latency, no TCP overhead; used for start/stop, config hot-reload, TUN setup
  - **REST API (External Controller) — secondary / dashboard**
    - Mihomo exposes **Clash RESTful API** on `external-controller: 127.0.0.1:9090` (FlClash picks random free port per launch)
    - Endpoints used by FlClash UI polling: `GET /proxies`, `PUT /proxies/:name`, `GET /connections`, `DELETE /connections/:id`, `GET /traffic`, `GET /logs`, `GET /rules`, `GET /configs`, `PUT /configs`
    - Also powers external dashboards (`metacubexd` / `yacd`) if user opens `external-ui: ui` + `external-ui-url: https://github.com/MetaCubeX/metacubexd/archive/refs/heads/gh-pages.zip`
    - Variants: `external-controller-unix: mihomo.sock` (Unix socket, no secret check) + `external-controller-pipe: \\.\pipe\mihomo` (Windows named pipe) + `external-controller-tls` (TLS)
    - CORS: `external-controller-cors: { allow-origins: [...], allow-private-network: true }`
    - FlClash sets `secret: ""` (empty) when binding to loopback; warns if user binds to `0.0.0.0` without secret (API can rewrite routing)

- **Process isolation — HOW Android separates core**
  - **Before v0.8.88:** Core ran inside main Flutter process
    - Crash in Go → app crash; VPN lifecycle tied to Activity lifecycle
  - **Since v0.8.88 `Add android separates the core process`:**
    - Core moves to **separate Android process** (`:core` or `:mihomo` process)
    - Benefits: survives Activity recreation, survives Flutter engine restart, force-restart via `core status check and force restart` (v0.8.88)
    - HOW it works: `android/app/src/main/.../MainActivity` + `VpnService` in one process, Go core in another, IPC via AIDL / `MethodChannel` + local socket
    - `Adjust android process` (v0.8.95) further tuned process priority / oom_adj
  - **Windows IPC optimization** (v0.8.93 `Optimize windows ipc`) — named pipe + shared memory for core UI sync

- **Hot reload — HOW config changes without restart**
  - `applyConfig` path: Flutter writes merged YAML to temp file → calls Go `applyConfig(path)` → Mihomo diffs listeners/groups/rules → recreates only changed listeners
  - `updateListeners` recreates HTTP/SOCKS/TUN inbound ports if `mixed-port` / `tun.enable` changed
  - `profile.store-selected: true` remembers last selected proxy per group across restarts

- **Core status check & force restart (v0.8.88)**
  - HOW it works: Flutter polls `GET /version` / heartbeat; if timeout > threshold → `kill` Go process → `handleInitClash` re-init
  - Prevents zombie TUN interface after core panic / OOM kill on Android

- **Helper service / service mode**
  - Windows service mode (v0.8.89 `Optimize Windows service mode`, v0.8.83 `Add windows server mode start process verify`)
    - Installs helper as Windows Service to manipulate TUN adapter + registry proxy keys without per-launch UAC
  - macOS helper: `services/helper` (Swift/ObjC) — installs network extension for TUN + `networksetup` proxy setters
  - Linux: `pkexec` / `polkit` prompt for `ip route` + `iptables` manipulation

---

## 5. Split Tunneling / Routing — HOW Clash Rule Engine Works

- **Engine priority**
  - Rules matched **top-to-bottom, first match wins** — order matters, top = highest priority
  - UDP caveat: if matched proxy `udp: false` → skip and continue matching downwards
  - Final catch-all: `MATCH,<proxy>` (matches everything)

- **Domain-based rules — HOW to match before DNS**
  - `DOMAIN,ad.com,REJECT` — exact full domain
  - `DOMAIN-SUFFIX,google.com,auto` — suffix (matches `www.google.com`, `mail.google.com`, `google.com` but not `content-google.com`)
  - `DOMAIN-KEYWORD,google,auto` — substring keyword
  - `DOMAIN-WILDCARD,*.google.com,auto` — `*`=0+ chars, `?`=1 char (different from Clash wildcard syntax elsewhere)
  - `DOMAIN-REGEX,^abc.*\.com,PROXY` — full regex
  - `GEOSITE,category,PROXY` — Geosite DB (from `v2fly/domain-list-community`), e.g., `GEOSITE,youtube`, `GEOSITE,cn`, `GEOSITE,geolocation-!cn`
    - Requires `geodata-mode: true` + `geox-url: { geosite: ... }` or `rule-providers` with `behavior: domain`
  - `RULE-SET,providername,proxy` — reference to `rule-providers:` set (see below)

- **IP-based rules — HOW to match after DNS (may trigger resolve)**
  - `IP-CIDR,127.0.0.0/8,DIRECT,no-resolve` — IPv4 CIDR; `IP-CIDR6` alias for v6
  - `IP-SUFFIX,8.8.8.8/24,PROXY` — suffix match
  - `IP-ASN,13335,DIRECT` — ASN match (requires `mmdb` / `asn` DB)
  - `GEOIP,CN,DIRECT` — country code via MaxMind DB (`geoip` dat + `mmdb` + `country-lite.mmdb`)
    - `GEOIP,lan,Direct,no-resolve` is common first line to keep LAN direct
  - `SRC-GEOIP`, `SRC-IP-ASN`, `SRC-IP-CIDR`, `SRC-IP-SUFFIX` — match **source** IP (rare, for multi-hom)
  - `no-resolve` flag: skip DNS lookup when evaluating (if earlier rule already resolved, still uses cached IP)
  - `src` flag: flip target-IP match to source-IP match

- **Port & protocol rules**
  - `DST-PORT,80,DIRECT` — destination port / range (supports `80-443`, technique from `handbook/syntax/#port-ranges`)
  - `SRC-PORT,7777,DIRECT` — source port range
  - `IN-PORT,7890,PROXY` — inbound listener port
  - `IN-TYPE,SOCKS/HTTP,PROXY` — inbound type
  - `IN-USER,mihomo,PROXY` / `IN-NAME,ss` / `REMATCH-NAME,rematch1` — user / inbound name
  - `NETWORK,udp,DIRECT` — L4 protocol (`tcp`/`udp`)
  - `DSCP,4,DIRECT` — QoS DSCP tag (tproxy UDP inbound only)

- **Process-based split tunneling — HOW per-app routing works**
  - `PROCESS-PATH,/usr/bin/wget,PROXY` — full executable path
  - `PROCESS-PATH-WILDCARD,/usr/*/wget,PROXY` — wildcard
  - `PROCESS-PATH-REGEX,.*bin/wget,PROXY` — regex; Windows example: `(?i).*Application\\chrome.*`
  - `PROCESS-NAME,curl,PROXY` — binary name; on **Android** matches **package name** (`com.termux`, `com.android.chrome`)
  - `PROCESS-NAME-WILDCARD,*telegram*` / `PROCESS-NAME-REGEX,(?i)Telegram` — wildcards/regex for process
  - `UID,1001,DIRECT` — Linux UID match
  - Requires: `find-process-mode: strict` in top-level config for accurate PID association
  - FlClash GUI (Windows/macOS/Linux): Access Control page (v0.8.91 `Optimize access control page`) lists running processes, lets user toggle per-app proxy/direct
  - FlClash Android: Still supports `PROCESS-NAME` for package names but TUN `exclude-package` / `include-package` is more reliable (see TUN section)

- **Logical combinators — HOW complex policies compose**
  - `AND,((DOMAIN,baidu.com),(NETWORK,UDP)),DIRECT` — all payloads must match
  - `OR,((NETWORK,UDP),(DOMAIN,baidu.com)),REJECT` — any payload matches
  - `NOT,((DOMAIN,baidu.com)),PROXY` — invert
  - `SUB-RULE,(NETWORK,tcp),sub-rule` — delegate to a `sub-rule:` block (nested rule set)
  - Parentheses are **mandatory**; missing one → YAML parse error on core reload

- **RULE-SET + rule-providers — HOW large sets scale**
  - Defines:
    - `rule-providers: { name: { type: http/file/inline, behavior: domain/ipcidr/classical, format: yaml/text/mrs, url, path, interval, proxy, size-limit, header } }`
  - Behaviors:
    - `domain` — domain list (DOMAIN-SUFFIX etc. per line)
    - `ipcidr` — CIDR list
    - `classical` — mixed `DOMAIN`, `IP-CIDR`, `GEOSITE` lines
  - Formats:
    - `yaml` / `text` — line-per-rule human readable
    - `mrs` — **Mihomo MRS binary** (compiled via `mihomo convert-ruleset domain/ipcidr yaml/text in.yaml out.mrs`) — faster load, smaller, recommended for >10k rules
  - Bundle: `path-in-bundle: "geo/geosite/cn.mrs"` lazy-extracts from `BundleMRS.7z` if file missing
  - FlClash auto-update: fetches with `interval: 600` (10 min) or `86400` (daily) per provider; can force via manual refresh

- **HOW FlClash GUI edits routing**
  - Profiles → `Rules` tab visualizes ordered list with drag-to-reorder, type dropdown, target group dropdown
  - `rule override` (v0.8.81) merges user-appended `rules:` without overwriting subscription rules
  - Validator: checks for duplicate `RULE-SET` name, invalid `DOMAIN-REGEX`, missing `proxy` group reference before saving

---

## 6. TUN vs System Proxy — HOW Traffic Interception Differs

- **System Proxy — HOW it works (L7, app-aware apps only)**
  - Mechanism:
    - FlClash writes OS proxy settings:
      - **Windows:** `HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings` → `ProxyEnable=1`, `ProxyServer=127.0.0.1:7890` + `ProxyOverride` for `bypassDomain` (v0.8.69)
      - **macOS:** `networksetup -setwebproxy` / `-setsecurewebproxy` / `-setsocksfirewallproxy` per interface + `bypass domain` list; requires `System Settings → Privacy & Security → Network Extension` approval on first use
      - **Linux:** `gsettings set org.gnome.system.proxy` (GNOME) / `kcmshell5` / KDE `kwriteconfig5` + env `http_proxy`/`https_proxy`; depends on DE
      - **Android:** `VpnService.setHttpProxy` is not used; system proxy toggle there controls PAC-like forwarding for WebView only
  - Pros: No virtual adapter, no driver, no reboot, works instantly
  - Cons: Only **proxy-aware apps** respect it (browsers, curl with env, Electron apps); **bypasses:** game clients, CLI tools, Docker, `git`, `npm`, Discord voice UDP
  - PAC mode: `external-controller` serves auto-config script if user enables PAC (FlClash sets `ProxyAutoConfigURL`); fallback to direct for `localhost`, `*.lan`
  - HOW FlClash toggles: Settings → `System Proxy` switch (v0.8.21) → writes registry / `networksetup` / `gsettings` + validates via `curl -x http://127.0.0.1:7890 https://www.gstatic.com/generate_204`

- **TUN — HOW it works (L3, global transparent)**
  - Mechanism:
    - FlClash asks Mihomo core (`tun.enable: true`) to create **virtual TUN interface** (`device: utun0` on macOS, `Meta` on Windows/Linux)
    - L3 packet flow:
      1. App sends IP packet → OS routing table (modified by `auto-route: true`) → TUN interface
      2. Mihomo parses packet in userspace, extracts dst `domain:port` (via FakeIP mapping or sniffed SNI)
      3. Rule engine picks proxy / direct
      4. Out via physical NIC (`auto-detect-interface: true` picks `en0` / `wlan0` automatically)
  - Stacks (`tun.stack`):
    - `system` — kernel TCP/IP stack; most stable/comprehensive, lowest resource, but may trip firewall (Windows: add core binary to `Windows Security → Allow an app through firewall`; macOS: signed app passes; Linux: `iptables -A OUTPUT -o Mihomo -j ACCEPT`)
    - `gvisor` — userspace stack (Google gVisor); better isolation, no kernel ctx switch, sometimes higher perf on loopback (`iperf` benchmark image in docs shows gvisor > system for L3)
    - `mixed` — **recommended**: TCP via `system`, UDP via `gvisor`; best overall UX; `stack: mixed` added after `mixed` deprecation of `lwIP`
  - Key TUN fields:
    - `enable: true`
    - `stack: mixed`
    - `auto-route: true` — install global route `0.0.0.0/1 + 128.0.0.0/1` and `::/1 + 8000::/1` into TUN
    - `auto-redirect: true` — Linux/Android extra: `iptables`/`nftables` redirect TCP; on Android only local IPv4 (hotspot share needs `VPNHotspot` app)
    - `auto-detect-interface: true` — pick outbound NIC; set false + `device: utun0` manual for multi-NIC hosts
    - `dns-hijack: [ "any:53", "tcp://any:53" ]` — hijack raw DNS to core DNS (critical — see DNS section)
    - `strict-route: true` — block leak via physical NIC (Windows adds firewall block for multi-homed DNS; Linux makes non-TUN nets unreachable); may break VirtualBox → disable if VM fails
    - `mtu: 9000`, `gso: true`, `gso-max-size: 65536` — Linux GSO offload
    - `inet6-address: fdfe:dcba:9876::1/126` — TUN v6 addr (needs top-level `ipv6: true` + system v6 check or `SKIP_SYSTEM_IPV6_CHECK=1`)
    - `udp-timeout: 300`, `endpoint-independent-nat: false`, `iproute2-table-index: 2022`, `iproute2-rule-index: 9000`
    - `route-address` / `route-exclude-address` / `route-address-set` / `route-exclude-address-set` — precise subnet inclusion/exclusion via nftables (Linux)
    - `include-interface` / `exclude-interface` — NIC filter
    - `include-uid` / `exclude-uid` / `include-uid-range` / `exclude-uid-range` — per-user on Linux
    - `include-android-user` / `include-package` / `exclude-package` — **Android per-app VPN** (e.g., `include-package: [com.android.chrome]` → only Chrome via TUN; `exclude-package: [com.android.captiveportallogin]` → bypass captive portal)
  - HOW FlClash toggles:
    - Settings → `TUN → Enable TUN Mode` (Windows requires **Run as administrator** or Service Mode; macOS requires VPN config approval + maybe reboot on first use; Android triggers `VpnService` permission dialog)
    - v0.8.86 `Fix windows tun issues`, v0.8.82 `Optimize android vpn performance` show TUN tuning cadence
  - Verification:
    - `curl -I https://www.google.com` from terminal must return `200`; FlClash Connections page shows `tun`-intercepted conns in real time
    - `browserleaks.com/dns` should show only proxy DNS, not ISP

- **When to use which (per docs)**
  - Browsing only → System Proxy + Rule mode suffices
  - CLI (`npm`, `git`, Docker), gaming (UDP), anything fixated on raw sockets → **Enable TUN** + `System Proxy` together (TUN catches what system proxy misses)
  - Recommendation: Always use `Rule` mode with TUN; `Global` routes domestic traffic needlessly and slows CN sites

- **FlClash-specific TUN tweaks**
  - `Support allowBypass` (v0.8.19) + `Add route address setting` (v0.8.69) → expose `route-exclude-address: [192.168.0.0/16, 10.0.0.0/8]` for LAN/bypass
  - `Support append system DNS` (v0.8.90) → adds OS DNS to Mihomo `nameserver` to survive corporate split-DNS
  - `Fix windows tun issues` (v0.8.86) → handle adapter rename / driver reinstall edge

---

## 7. DNS — HOW Clash DNS + FakeIP Works

- **Why Clash needs its own DNS**
  - Rule engine needs **domain** for `DOMAIN-SUFFIX` / `GEOSITE` **before** it has IP — but L3 packets carry only IP
  - FakeIP solves this by **faking** IP at DNS time and remembering mapping; real IP looked up only if rule needs it (`GEOIP`, `IP-CIDR`, `DIRECT`)
  - Without FakeIP, every `DOMAIN` match would require synchronous real DNS — slower, leakier, pollution-prone

- **FakeIP flow — HOW it intercepts**
  1. App `getaddrinfo("google.com")` → DNS query → **Clash DNS** (listening on `dns.listen: 0.0.0.0:1053` or hijacked `any:53` via TUN)
  2. Core allocates fake IP from `fake-ip-range: 198.18.0.1/16` (IANA reserved, not routed on public internet)
     - Example: `198.18.1.70` ↔ `google.com` stored in internal map
  3. Returns `198.18.1.70` instantly (no upstream lookup yet)
  4. App `connect(198.18.1.70:443)` → packet hits TUN → core looks up mapping → knows real domain = `google.com` → applies `rules:`
     - If rule says `PROXY` → dial proxy with **domain** (proxy does real DNS) — zero leakage of query to ISP
     - If rule says `DIRECT` or needs `GEOIP`/`IP-CIDR` → core now does real lookup via `nameserver`/`fallback` and `hosts`

- **Full `dns:` block — HOW Mihomo configures it**
  - `enable: true`
  - `listen: 0.0.0.0:1053` — FlClash binds here + hijacks via `tun.dns-hijack`
  - `ipv6: false/true` — toggle AAAA handling; `ipv6: true` also needs `tun.inet6-address`
  - `enhanced-mode: fake-ip` vs `redir-host`
    - `fake-ip` — recommended with TUN (eliminates wait, prevents OS bypass, enables sniff-less routing)
    - `redir-host` — returns real IP after resolving; classic but slower; used when FakeIP breaks intranet/corporate VPNs
  - `fake-ip-range: 198.18.0.1/16` (also ipv6 `fdfe:dcba:9876::1/64` if `fake-ip-range6`)
  - `fake-ip-filter-mode: blacklist / whitelist / rule` (mihomo exclusive; `blacklist`=default, only blacklist returns real IP; `whitelist`=only whitelist returns fake; `rule`=use rule engine semantics with `GEOSITE`, `RULE-SET`, `DOMAIN`)
  - `fake-ip-filter: ['*.lan', '+.local', '+.market.xiaomi.com', 'Mijia Cloud', '+.push.apple.com']` — domains that bypass FakeIP and get real IP (critical for `DIRECT` domains like `office.com` — see issue #1977)
  - `fake-ip-ttl: 1` — map TTL tuning (uncommon)
  - `use-hosts: true` + `use-system-hosts: true` — seed with local hosts file / OS hosts
  - `respect-rules: false/true` — when `true`, respects `rules` when choosing nameserver path (helps `office.com` `DIRECT` EOF fix: set `respect-rules: true` + add `office.com` to `fake-ip-filter`)
  - `default-nameserver: [223.5.5.5]` — bootstrap resolver to resolve DoH hostnames (must be plain IP, not DoH)
  - `nameserver: [https://doh.pub/dns-query, https://dns.alidns.com/dns-query, https://1.1.1.1/dns-query]` — domestic/primary DoH/DoT (`tls://8.8.4.4`, `https://dns.google/dns-query`, `tcp://8.8.8.8`)
  - `fallback: [tls://8.8.4.4, tls://1.1.1.1]` — used for GFW domains when `fallback-filter` says to switch
  - `fallback-filter: { geoip: true, geoip-code: CN, geosite: [gfw], ipcidr: [240.0.0.0/4], domain: ['+.google.com'] }` — decides nameserver vs fallback
  - `nameserver-policy: { '+.arpa': '10.0.0.1', 'rule-set:cn': ['https://doh.pub/dns-query'] }` — per-domain resolver override
  - `proxy-server-nameserver: [https://doh.pub/dns-query]` — resolver for **proxy node hostnames themselves** (avoid chicken-egg)
  - `direct-nameserver` / `direct-nameserver-follow-policy: false` — resolver for DIRECT domains (can be `system`)
  - `cache-algorithm: arc` (Adaptive Replacement Cache) + `prefer-h3: false` — perf tuning
  - `hosts:` dict — static overrides (FlClash `Hosts override` v0.8.57)
  - `external-doh-server: /dns-query` — expose core DNS as DoH endpoint for other LAN devices

- **DoH / DoT via `dns` section — HOW encrypted DNS avoids pollution**
  - Mihomo supports: `https://` (DoH), `tls://` (DoT), `tcp://`, `udp://` (plain) per entry
  - FlClash default template (GeoX example):
    - `default-nameserver: [tls://223.5.5.5, tls://223.6.6.6]` (AliDNS domestic)
    - `nameserver: [https://doh.pub/dns-query (Tencent), https://dns.alidns.com/dns-query (Alibaba)]`
    - `fallback` left for Cloudflare/Google — keeps CN vs foreign split
  - `DNS override` (v0.8.57) / `Host override` lets FlClash user replace provider's `dns:` block without forking YAML

- **Sniffer (domain sniffing) — HOW it helps rules without DNS**
  - `sniffer: { enable: true, sniff: { HTTP: { ports: [80, 8080-8880], override-destination: true }, TLS: { ports: [443, 8443] }, QUIC: { ports: [443,8443] } }, skip-domain: ["Mijia Cloud", "+.push.apple.com"] }`
  - HOW it works: Parses SNI / HTTP Host from raw TCP payload, recovers domain even when packet dst is IP (helps non-FakeIP or UDP path)
  - FlClash enables by default in template; `skip-domain` avoids sniffing IoT push domains that break on override

- **Known pitfall — HOW FakeIP + DIRECT breaks (Issue #1977)**
  - Symptom: `fake-ip` + `DST-PORT,993,DIRECT` / `DOMAIN-SUFFIX,office.com,DIRECT` → TLS `EOF` on Outlook/M365
  - Root cause: app receives fake `198.18.x.x`, sends TLS to Mihomo → Mihomo tries DIRECT but fake IP has no real routable dst
  - Fix per issue:
    - Set `dns.respect-rules: true` + add to `fake-ip-filter`: `office.com`, `*.office.com`, `outlook.office365.com`, `*.microsoftonline.com`, `*.live.com`, `*.msn.com`
    - Alternative: switch affected rules to `fake-ip-filter-mode: rule` + `DOMAIN,office.com,ip` exclusion

- **HOW FlClash surfaces DNS**
  - DNS page: `Clash DNS` toggle, `fake-ip-range` editor, `nameserver`/`fallback` reorder, `fake-ip-filter` tag chips, `respect-rules` switch
  - `Optimize android get system dns` (v0.8.86) + `Support append system DNS` (v0.8.90) → on mobile, `direct-nameserver: system` picks OS resolver to coexist with captive portals
  - Leak check: FlClash docs point to `browserleaks.com/dns` — only proxy IPs should appear

---

## 8. Proxies & Groups — HOW Proxy Selection & Health Check Works

- **Proxies — HOW inline nodes declared**
  - In `proxies:` array or `proxy-providers: { inline.payload: [] }`
  - Each entry: `name` (unique, quoted if symbols), `type` (ss/vmess/vless/trojan/…), `server`, `port` (+ type-specific opts like `password`, `uuid`, `cipher`, `tls`, `network`)
  - FlClash card shows: flag emoji (country), type badge, delay ms, UDP icon, `x` status if `disable-udp: true`

- **Proxy-groups — HOW groups aggregate proxies**
  - General fields (per `wiki.metacubex.one/en/config/proxy-groups/`):
    - `name` (required, unique, quote if special chars), `type` (required)
    - `proxies: [DIRECT, ss, OtherGroup]` — explicit member list (can include other groups)
    - `use: [provider1]` — include from `proxy-providers` by name
    - `include-all: true/false` — auto-include all inline + providers members sorted by name
    - `include-all-proxies` / `include-all-providers` — partial include
    - `filter: "(?i)港|hk|hongkong"` / `exclude-filter: "美|日"` / `exclude-type: "Shadowsocks|Http"` — regex / pipe filtering on auto-included members
    - `url: https://www.gstatic.com/generate_204` — health-check URL
    - `interval: 300` (seconds), `timeout: 5000` (ms), `tolerance: 10` (url-test)
    - `lazy: true` (skip test if group not currently selected — saves battery), `max-failed-times: 5` (force test after N fails), `expected-status: 204` (syntax `200/302/400-503`), `disable-udp`, `hidden: true`, `icon: https://...`
    - `default-selected: ss` / `empty-fallback: COMPATIBLE` (fallback proxy if group empties after filtering)
    - Deprecated: `interface-name` / `routing-mark` inside group — move to node `interface-name`

- **Manual select — `type: select`**
  - HOW it works: User taps a member, choice persisted via `profile.store-selected: true` (top-level `profile: { store-selected, store-fake-ip }`)
  - Example: `Default: { type: select, proxies: [Auto, DIRECT, Hong Kong, US, All Proxies] }` — region groups compose via `include-all` + `filter`

- **Auto fallback — `type: fallback`**
  - HOW it works: Tries proxies in **declared order** until one succeeds (not lowest latency — first healthy)
  - Use: Prefer stable ordering: `fallback: [HK-primary, HK-backup, JP, US]` ensures HK tried first even if JP lower latency

- **URLTest — `type: url-test` / `auto` / `load-balance` variant**
  - HOW `url-test` works: Periodically tests all members against `url` (`https://www.gstatic.com/generate_204` is zero-body 204, fastest), picks **lowest latency** automatically
  - `tolerance: 50` (ms) — only switch if new best beats current by >50ms (avoids flap)
  - `interval: 300` — every 5 min; `lazy: true` → only when group active
  - `url-test` vs `fallback`: url-test optimizes speed; fallback optimizes determinism
  - `Auto` group in template: `Auto: { type: url-test, include-all: true, exclude-type: direct, tolerance: 10 }` — the “auto pick best” everyone uses

- **Load-balance — `type: load-balance`**
  - HOW it works: Distributes connections across members per hash
  - `strategy: consistent-hashing` (stable for same dst) or `round-robin`
  - `url` / `interval` / `timeout` still used for health filtering — unhealthy members excluded
  - Use: High-concurrency scraping / multi-link aggregation; not needed for single-user browsing

- **Relay — `type: relay`**
  - HOW it works: Chain proxies sequentially (traffic hops through each in order: client → proxyA → proxyB → target)
  - Use: DIY multi-hop without provider multi-hop nodes; cost = latency sum

- **Health check — HOW availability decided**
  - Per-group `health-check: { enable: true, url: ..., interval: 300, timeout: 5000, lazy: true, expected-status: 204 }` (proxy-providers level) and per-group `url`/`interval`/`timeout`
  - Request: small HTTP GET to 204 endpoint through **each member** (concurrent)
  - Result: latency ms shown on proxy card; failed = grayed + excluded from auto groups
  - `tolerance` + `max-failed-times` + `lazy` together control cost vs freshness
  - FlClash optimization: `optimize delayTest` (v0.8.4), `fix urltest issues` (v0.8.64), `optimize delay test` (v0.8.73, 0.8.95 `Fix whole group delay test failing on Windows`) — fixes Windows firewall blocking mass parallel tests

- **HOW FlClash GUI operates groups**
  - Proxies page: grouped cards, column count selector (v0.8.53), proxy card size slider, expansion panels (v0.8.28), search (v0.8.85)
  - Tap `select` → immediate switch, Connections page updates route
  - `Optimize proxies page and access page` (v0.8.88), `Fix unselected proxy group delay issues` (v0.8.80), `Add proxies icon configuration` (v0.8.64) — shows active polishing
  - `proxies icon` + `country flags` (v0.8.53 Windows flag display) → per-node `icon:` URL rendered as badge

---

## 9. Other Features — HOW Data Sync, Overwrite, Backup, Logs Work

- **Data sync via WebDAV — HOW multi-device state syncs**
  - What: FlClash config + profiles + settings can sync to any WebDAV server (Nextcloud, InfiniCloud, Jianguoyun, self-hosted `rclone serve webdav`)
  - HOW to set: Settings → `WebDAV` → enter `URL`, `Username`, `Password`; path default `/FlClash/`
  - Added: `v0.8.4 add WebDAV` (also `update changelog` to document)
  - Behavior: On app start / profile change → upload local DB snapshot; on other device → pull & merge; conflict = last-write-wins
  - Privacy: Server sees encrypted YAML if you set provider token in URL; otherwise plaintext — use age-encrypted provider `age-secret-key` if sensitive

- **Backup / restore — HOW local persistence works**
  - `Support local backup and recovery` (v0.8.51) + `Add backup recovery strategy select` (v0.8.83)
  - Since v0.8.92 `Optimize backup and restore` + `Add sqlite store`:
    - Store = **Drift (SQLite)** file + `SharedPreferences` for small flags, located:
      - Android: `data/data/com.follow.clash/databases/`
      - Windows: `%APPDATA%\FlClash\`
      - macOS: `~/Library/Application Support/FlClash/`
      - Linux: `~/.config/flclash/`
  - `Optimize config persistence` (v0.8.85) → atomic write + journal to survive crash during TUN re-route
  - `Add windows storage corruption detection` (v0.8.75) → checksum + auto restore from backup if DB corrupted after power loss
  - `Fix windows resource manager restart` (v0.8.75) → re-attach tray after Explorer crash
  - Strategy picker (v0.8.83) options: `overwrite`, `merge`, `keep-newer`

- **Custom overwrite / override — HOW YAML patching works**
  - Added: `v0.8.93 Support custom overwrite` + `v0.8.85 Support override script`
  - What: JavaScript-like script (similar to Stash `script` / Verge `merge`) that runs **after** subscription YAML load but **before** core `applyConfig`
  - Use cases:
    - Inject `dns:` / `tun:` default when provider template is minimal
    - Rewrite `proxies[].udp: true` en masse
    - Add `RULE-SET` providers without editing provider file
    - Add `hosts:` entries for intranet
  - FlClash editors:
    - `v0.8.91 Optimize overwrite handle` + `v0.8.81 Add rule override` + `v0.8.57 Add DNS override / Hosts override` → separate tabs for `overwrite`, `dns`, `hosts`, `rules`
  - Example overwrite snippet (FlClash handles as patch script):
    - `dns.enable = true; tun.stack = 'mixed'; proxies.forEach(p => p.udp = true);`
  - HOW it persists: Saved in SQLite `overwrites` table, re-applied on every profile refresh + core restart

- **Run on demand — `Support run on demand` (v0.8.93)**
  - HOW it works: FlClash registers as on-demand VPN (Android `always-on + block without VPN` variant + desktop launch-on-demand hook)
  - Use: Keep core dormant until traffic appears; saves battery on mobile / avoids auto-proxy when user wants direct

- **Access control page — HOW per-app toggles managed**
  - `Optimize access control page` (v0.8.91) → searchable list of installed apps / running processes with allow/block per-app
  - Desktop: toggles map to `PROCESS-NAME` rules; Android: toggles map to `tun.include-package / exclude-package`
  - `Add search function at access control` (v0.8.17) + `Fix AccessControl click issue` (v0.8.9)

- **Connections polling — HOW active flows displayed**
  - FlClash polls `GET /connections` every ~1s (throttled)
  - Optimization: `v0.8.96 Optimize package icon loading and connections polling` — lazy load app icons, debounce polling to cut CPU
  - Connections page features (since v0.8.26 `Add connections page` + v0.8.85 `Add some scenes auto close connections`):
    - Show: src → dst, domain, process, rule, proxy chain, upload/download, duration
    - Actions: `Close` single conn, `Close all` with auto-close scenes (switch profile, stop proxy)
    - Search: `Add search in connections, requests` (v0.8.26), `Add keyword search` (v0.8.26)

- **Traffic & logs — HOW accounting viewed**
  - `GET /traffic` stream → dashboard graph (uploaded/downloaded per sec)
  - `Add proxy-only traffic statistics` (v0.8.49) → separate DIRECT vs PROXY counters
  - `GET /logs?level=info` → Logs page with level filter (`info/warning/error/debug/silent`)
  - `Fix traffic view issues` (v0.8.78), `Optimize dashboard performance` (v0.8.80), `Remake dashboard` (v0.8.71) → iterative polish
  - `Optimize logs, requests, connection pages` (v0.8.87 + v0.8.88) → virtualized lists for 10k+ lines

- **Requests log — HOW HTTP capture works**
  - `Add requests page` (v0.8.22) — records HTTP requests proxied via FlClash (method, URL, status, headers, timing)
  - Uses Mihomo's `external-controller` log + sniffed `HTTP` sniff (see `sniffer: HTTP.ports: [80, 8080-8880]`)
  - HOW to use: Enable `capture` toggle; compare before/after rule edits; export via `Support log export` (v0.8.64)

- **Icon loading — HOW proxy flags/icons resolved**
  - `v0.8.96 Optimize package icon loading` + `v0.8.64 Support proxies icon configuration` 
  - HOW: Each `proxy` / `proxy-group` can declare `icon: https://raw.githubusercontent.com/Koolson/Qure/master/IconSet/...` → FlClash lazy-loads + caches locally; shows country flag fallback via GeoIP→flag mapping (Windows flag display fix v0.8.53)
  - Cache: SQLite icon cache table, LRU eviction; SVG via `Support svg display` (v0.8.85)

- **SQLite store — HOW persistence modernized**
  - `v0.8.92 Add sqlite store` — Drift ORM atop `sqlite3_flutter_libs`
  - What moved: profiles YAML cache, settings, connections history, logs cache, icon cache, overwrite scripts
  - Benefit: atomic transactions, faster search (`Support proxies search` v0.8.85 uses SQL `LIKE`), survive large (>5MB) rule-provider caches without SharedPrefs blowup

- **Android quick tile / TV launcher — HOW quick control works**
  - Tile: `com.follow.clash.action.START / STOP / TOGGLE` + `TileService` (v0.8.90 `Fix android tile service`, v0.8.92 `Optimize android quick action`, v0.8.51 `Fix android tile service issues`, v0.8.71 `Fix android tile issues`)
    - HOW to use: Pull shade → edit tiles → drag `FlClash` tile → tap to toggle VPN without opening app
  - Quick actions: `Add android shortcuts` (v0.8.67) → launcher long-press shortcuts for Start/Stop
  - TV: `Optimize Android TV launcher icon` (v0.8.95) + v0.8.83 `Optimize android tv experience` → large icon, D-pad navigation, focus control (v0.8.95 `Optimize focus control` + `Optimize back navigation`)

- **Auto update geo assets — HOW geo DBs stay fresh**
  - `geodata-mode: true` indicates Mihomo loads `geoip.dat` / `geosite.dat` / `country.mmdb` / `asn.mmdb` from `geox-url`
  - Default `geox-url`:
    - `geoip: https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip-lite.dat`
    - `geosite: https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.dat`
    - `mmdb: https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/country-lite.mmdb`
    - `asn: https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/GeoLite2-ASN.mmdb`
  - FlClash toggles: `Modify geoData URL` (v0.8.36), `Support auto check updates` (v0.8.4), `Geodata loader switch` (v0.8.21 `Add geodata loader switch`), `Fix geodata url does not take effect` (v0.8.37)
  - `Update core` bumps `geox-url` defaults when Meta rules repo moves

- **Core status check & force restart — HOW watchdog works (v0.8.88)**
  - Watchdog pings Go core heartbeat; on timeout → `force restart` (kill + re-init)
  - Shown in Settings → `Core status check`; useful when TUN adapter hangs after sleep/wake

- **Other polish — iterative optimization log**
  - `Custom primary color and color scheme` (v0.8.82), `Custom text scaling` (v0.8.83), `Theme optimize` (v0.8.71)
  - `Memory overflow fixes` (v0.8.31), `Android vpn performance` (v0.8.82), `Auto gc on trim memory` (v0.8.21)
  - `FontFamily options` (v0.8.66), `Collapse fix` (v0.8.66), `Window position memory` (v0.8.70)

---

## 10. Platforms — HOW FlClash Behaves Per OS

- **Android (including Android TV)**
  - **VPNService integration**
    - Creates `VpnService` with `Builder.addAddress("198.18.0.1",32)` + `addRoute("0.0.0.0",0)` + `addDnsServer("114.114.114.114")` (then routed into Mihomo)
    - `Support android system dns` (v0.8.60) + `Fix android system dns issues` (v0.8.64) → respects `Private DNS` off; with `Private DNS` on, posts warning that `dns-hijack` cannot capture
    - `Support android vpn ipv6 inbound` (v0.8.60) + `Support android vpn ipv6 inbound switch` (v0.8.64) → toggle via `tun.inet6-address`
    - `Support android close vpn` (v0.8.55) — explicit stop leaves no ghost TUN
    - Intents: `com.follow.clash.action.START / STOP / TOGGLE` (documented in README Android section)
  - **Process separation (v0.8.88+)**
    - Core in `:core` process, UI in main → survives Activity kill; `Optimize android process` (v0.8.95) + `Adjust android process` tune oom_adj
  - **Per-app VPN via TUN**
    - `include-package` / `exclude-package` in `tun:` → only listed packages via VPN; FlClash Access Control page auto-generates list from `PackageManager`
    - `include-android-user: [0, 10]` — dual-app / second space support (Xiaomi HyperOS `Optimize hyperOS freeform window` v0.8.83)
  - **Quick controls**
    - TileService + shortcuts + `Fix android tile service` (v0.8.51/0.8.90) → shade tile toggles without app
    - `Separate android ui and vpn` (v0.8.36) → UI can be swiped away while VPN stays
    - `Hidden from recent task` (v0.8.36) optional — hide VPN notification from recents for stealth
  - **TV launcher (v0.8.95 `Optimize Android TV launcher icon`)**
    - Leanback banner, D-pad focus, large icons, remote back navigation fixed
    - No touch assumptions — all dialogs focusable

- **Windows**
  - **System proxy**
    - Sets `HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ProxyEnable` + `ProxyServer=127.0.0.1:7890`
    - `bypassDomain` list maps to `ProxyOverride`; `Support setting bypassDomain` (v0.8.69)
  - **TUN**
    - Virtual adapter named `Meta` or `FlClash` (Mihomo `tun.device`)
    - Requires **Run as administrator** (right-click → Run as administrator) unless Service Mode installed
    - `Service Mode` (Windows Service): installs helper to create TUN + set routes without per-launch UAC; `Optimize Windows service mode` (v0.8.89) + `Add windows server mode start process verify` (v0.8.83)
    - `Fix windows tun issues` (v0.8.86), `Add windows tun` (v0.8.33)
    - Firewall: `Settings → Windows Security → Allow an app through firewall → core binary` for `system`/`mixed` stack; else `gvisor` fallback
  - **Tray & window**
    - System tray with `Auto hide` (v0.8.87 `Optimize windows tray auto hide`), flag icons (`Support windows country flags` v0.8.53)
    - `Fix windows tray issues` (v0.8.64, 0.8.55, 0.8.69), `Optimize windows tray auto hide` (v0.8.87)
    - `Windows ARM64` build (v0.8.93 `Optimize windows arm64`, v0.8.82 `Add linux and windows arm release`, v0.8.70 arm64 script)
    - `Optimize windows ipc` (v0.8.93) → faster Flutter↔Go pipe on Win
    - `Windows storage corruption detection` (v0.8.75) + `Fix core crash caused by windows resource manager restart` (v0.8.75) → survive Explorer restarts
    - Silent launch: `Admin auto launch` (v0.8.64) + `Fix windows admin auto launch issues` (v0.8.64)

- **macOS**
  - **System proxy**
    - Calls `networksetup -setwebproxy` / `-setsecurewebproxy` per active `networkservice` (Wi-Fi, Ethernet)
    - Requires user approve network extension in `System Settings → Privacy & Security`
  - **TUN**
    - Creates `utun` device (macOS only allows `utun*` names); `Fix macos performance issue` (v0.8.94) was a recent perf regression fix
    - `Fix macos bypass domain issues` (v0.8.75), `Fix macos dock exit button` (v0.8.69)
  - **Install**
    - Homebrew: `brew tap chen08209/tap && brew install --cask flclash`
    - Also standalone `.dmg` per arch (`flclash-macos-amd64.dmg` / `arm64.dmg`)
    - Helper service at `services/helper` handles `networksetup` privilege escalation without repeated password
  - **Version**: `v0.8.94` explicitly patches macOS perf; `Add macos arm64` (v0.8.42) initial Apple Silicon support

- **Linux**
  - **Dependencies**
    - Must install before use: `sudo apt-get install libayatana-appindicator3-dev libkeybinder-3.0-dev` (README Linux section)
    - `Add linux deb dependencies` (v0.8.83) — declares `Depends:` in `.deb` control file
  - **System proxy**
    - `gsettings set org.gnome.system.proxy mode manual` + `host/port`; KDE via `kwriteconfig5`; `xdg` env fallback
  - **TUN**
    - Uses `auto-redirect: true` + `auto-route: true` with `iptables`/`nftables` (requires `pkexec`)
    - `Fix linux silent launching not working` (v0.8.94), `Fix linux tun authority check error` (v0.8.77), `Fix linux core build error` (v0.8.49)
    - `Support desktop hotkey` (v0.8.60), `Add linux arm64 build script` (v0.8.70), `Add linux and windows arm release` (v0.8.82)
  - **Tray**: `libayatana-appindicator3` provides tray icon + `libkeybinder` for global hotkey
  - **Silent launching**: `Fix linux silent launching not working` (v0.8.94) → `--hidden` / autostart via `XDG Autostart`

---

## 11. Repo Stats, Releases, Build — HOW to Build & Track

- **Repo identity**
  - **Full name:** `chen08209/FlClash`
  - **URL:** `https://github.com/chen08209/FlClash`
  - **Description:** `A multi-platform proxy client based on ClashMeta, simple and easy to use, open-source and ad-free.`
  - **Topics (8):** `clash`, `clash-meta`, `flutter`, `hysteria`, `multi-platform`, `proxy`, `v2ray`, `vless`, `vpn`
  - **License:** `GPL-3.0` — `https://github.com/chen08209/FlClash/blob/main/LICENSE`
  - **Languages:** Dart (~80%), Go (~15%), C++ (Windows runner), Swift/ObjC (macOS helper), CMake, shell
  - **Stars:** **50.3k** (live webfetch 2026-08-30), **Forks:** **3.2k**, **Watchers:** 144
  - **Age:** Initial commit `v0.7.0` (0.7.x series), first public `v0.8.0` `Add compatibility mode and adapt clash scheme`
  - **Telegram:** `https://t.me/FlClash` (announces releases, nightly builds)

- **Releases — HOW versioning flows (current `v0.8.96`)**
  - Tag scheme: `v0.8.xx` (minor patch train), built by `github-actions` bot at `07:30 UTC`
  - **v0.8.96 (2026-08-17 — latest stable)**
    - `Optimize commented policy`
    - `Fix whole group delay test failing on Windows` (firewall parallel-test fix)
    - `Optimize package icon loading and connections polling` (perf tune)
    - Assets: **16** per platform (Windows `.exe` Inno Setup, `.zip` portable; macOS `.dmg` amd64/arm64; Linux `.deb` + `.tar.gz` amd64/arm64; Android `.apk` splits + universal)
    - Reactions: 👍 82, 🎉 18, ❤️ 12, 🚀 12 (98 total) — active validation
  - **v0.8.95 (2026-08-14)**
    - `Optimize core service`, `Optimize Android TV launcher icon`, `Optimize back navigation`, `Optimize app layout`, `Optimize focus control`, `Adjust android process`, `Fix some issues`, `Optimize more details`
  - **v0.8.94 (2026-07-11)**
    - `Fix macos performance issue`, `Support custom global-ua`, `Update core`, `Fix linux silent launching not working`
  - **v0.8.93 (2026-05-29)**
    - `Support custom overwrite`, `Support run on demand`, `Optimize windows ipc`, `Optimize windows arm64`, `Optimize build`, `Update core` — 257 reactions (major feature bump)
  - **v0.8.92 (2026-02-02)**
    - `Add sqlite store`, `Optimize android quick action`, `Optimize backup and restore` — **24 assets** (extra arch splits)
    - 295 reactions — migration to SQLite was widely appreciated
  - **v0.8.91 (2025-12-12)** — `Optimize overwrite handle`, `Optimize access control page`
  - **v0.8.90 (2025-10-08)** — `Support append system DNS`, `Fix android tile service`
  - **v0.8.89 (2025-09-27)** — `Optimize Windows service mode`, `Update core`
  - **v0.8.88 (2025-09-23)** — `Add android separates the core process`, `Support core status check and force restart`, `Update flutter and pub dependencies`, `Update go version` — **28 assets** (added arm splits), 74 reactions
  - **Earlier notable:** v0.8.85 (`Support override script`, `Support proxies search`, `Support svg`), v0.8.83 (windows server mode verify, linux deb deps, hyperOS), v0.8.36 (`Support modify geoData URL`), v0.8.16 (`one-click update all`), v0.8.4 (WebDAV)
  - **Changelog file:** `CHANGELOG.md` (1028 lines, 519 loc) — auto-generated after v0.8.64 `Add auto changelog` + `Init auto gen changelog`; each tag links to `https://github.com/chen08209/FlClash/blob/main/CHANGELOG.md`

- **Build — HOW to compile from source**

  - **Prereqs (all platforms)**
    - `git submodule update --init --recursive` — pulls `mihomo` core
    - `Flutter` (stable, version in `tool/` / `setup.dart` pins) + `Golang` (1.21+, check `core/go.mod` `go` directive)
    - Dart SDK ships with Flutter

  - **Android — HOW**
    - Install: `Android SDK` + `Android NDK`, set env `ANDROID_NDK=/path/to/ndk`
    - Run: `dart setup.dart android` (or `dart .\setup.dart android` on Windows PowerShell)
    - Output: `build/app/outputs/flutter-apk/app-release.apk` + ABI splits; signed if `keystore` configured
    - Troubleshooting: NDK version mismatch → `gomobile` fails; ensure `ANDROID_NDK` path has `ndk-build`

  - **Windows — HOW**
    - Requires **Windows host**
    - Install: `GCC` (mingw-w64 / TDM-GCC) + `Inno Setup 6` (for installer generation)
    - Run: `dart setup.dart windows` (optional `--arch arm64|amd64` in older docs; now auto-detects per `v0.8.70 Add windows arm64`)
    - Output: `dist/flclash-windows-*.exe` (Inno Setup) + `flclash-windows-*.zip` (portable)
    - Troubleshooting: `GCC` not in PATH → `CGO_ENABLED=1` build fails; check `gcc --version`

  - **Linux — HOW**
    - Requires **Linux host** (Ubuntu 22.04+ recommended)
    - Deps auto-installed by `setup.dart` or manually:
      ```bash
      sudo apt-get install -y libayatana-appindicator3-dev libkeybinder-3.0-dev
      ```
    - Run: `dart setup.dart linux` (arm64 cross via `setup.dart linux --arch arm64`)
    - Output: `dist/flclash-linux-*.deb` + `.tar.gz`
    - Troubleshooting: `tray` fails without `libayatana-appindicator3-dev`; compile error `keybinder.h not found` → missing `libkeybinder-3.0-dev`

  - **macOS — HOW**
    - Requires **macOS host** + Xcode CLI tools (`xcode-select --install`)
    - Run: `dart setup.dart macos` (universal: amd64+arm64)
    - Output: `dist/FlClash-macos-*.dmg`
    - Signing: ad-hoc by default; for Gatekeeper: `codesign` + `notarization` via `distribute_options.yaml`

  - **Build system files to inspect**
    - `setup.dart:1` — main build driver (per-platform `build.yaml` → `core` → `flutter build` → `dist`)
    - `build.yaml` — target matrix (arch, output name, entitlements)
    - `distribute_options.yaml` — Inno Setup / DMG / DEB packager vars
    - `core/go.mod` — pinned `github.com/metacubex/mihomo` commit SHA
    - `pubspec.yaml` + `pubspec.lock` — Dart deps
    - `Makefile` — shortcut `make android/windows/linux/macos`
    - `tool/` — helper scripts (icon gen, i18n, version bump)
    - `.github/workflows/build.yaml` — CI cross-build matrix (added `46` lines in 0ccfd8f PR)

  - **F-Droid build**
    - `Merge pull request #140` — self-hosted F-Droid repo workflow pushes `.apk` + `index.xml` to `FlClash-fdroid-repo` on release
    - Fingerprint `789D6D32668712EF7672F9E58DEEB15FBD6DCEEC5AE7A4371EA72F2AAE8A12FD` mirrors F-Droid convention

- **HOW to confirm file exists (this document)**
  - Path: `C:\Users\qmahyar\Desktop\VPN Research\11-FlClash.md`
  - Verify:
    ```powershell
    Test-Path "C:\Users\qmahyar\Desktop\VPN Research\11-FlClash.md"
    (Get-Content "C:\Users\qmahyar\Desktop\VPN Research\11-FlClash.md").Count  # expect >400
    Get-FileHash "C:\Users\qmahyar\Desktop\VPN Research\11-FlClash.md" -Algorithm SHA256
    ```

---

## 12. References & Verification

- **Primary sources fetched live 2026-08-30**
  - `https://github.com/chen08209/FlClash` — README, stars 50.3k, forks 3.2k, GPL-3.0, features, download, build
  - `https://github.com/chen08209/FlClash/releases` — v0.8.96 down to v0.8.87 list, assets 16-28, reactions
  - `https://github.com/chen08209/FlClash/releases/tag/v0.8.96` — headline fixes (commented policy, Windows delay test, icon/polling)
  - `https://github.com/chen08209/FlClash/blob/main/CHANGELOG.md` — full 0.7.0→0.8.96 log (1028 lines)
  - `https://wiki.metacubex.one/en/config/proxies/wg/` — WireGuard fields, allowed-ips, reserved, AmneziaWG jc/jmin/jmax
  - `https://wiki.metacubex.one/en/config/dns/` — dns: enable, cache-algorithm, fake-ip-range, fake-ip-filter-mode, nameserver-policy, fallback-filter
  - `https://wiki.metacubex.one/en/config/proxy-groups/` — select/url-test/fallback/load-balance fields, lazy, tolerance, filter
  - `https://wiki.metacubex.one/en/config/rules/` — DOMAIN, GEOSITE, GEOIP, PROCESS-NAME, AND/OR/NOT, SUB-RULE, MATCH
  - `https://wiki.metacubex.one/en/config/inbound/tun/` — stack system/gvisor/mixed, auto-route, strict-route, mtu, include-package, gso
  - `https://wiki.metacubex.one/en/config/proxy-providers/` + `rule-providers` — type http/file/inline, behavior domain/ipcidr/classical, format yaml/text/mrs
  - `https://github.com/MetaCubeX/mihomo/blob/fbead56ec97ae93f904f4476df1741af718c9c2a/constant/adapters.go` — adapter enum SS/SSR/Vmess/Vless/Trojan/Hysteria2/WireGuard/Tuic/Ssh
  - `https://github.com/MetaCubeX/mihomo/blob/main/docs/config.yaml` (raw `docs/config.yaml`) — proxies examples for Snell/SS/Trojan/WG/AmneziaWG

- **Topic coverage map**
  - Overview: GPL-3, Flutter+Dart+Go, 4 OS + TV, 50k/3k counts, ad-free — **verified**
  - Protocols: SS/SSR/VMess/VLESS Reality Vision/Trojan/Hysteria2/TUIC v5/WireGuard/SSH/AnyTLS/Mieru/Snell/HTTP/SOCKS — **Mihomo docs + adapters.go**
  - Subscription: Clash/Mihomo YAML, proxy-providers, rule-providers — **wiki + docs/config.yaml**
  - Core: FFI + REST `external-controller` + `:core` process split v0.8.88 — **core/hub.go + changelog**
  - Routing: DOMAIN/IP-CIDR/GEOIP/PROCESS-NAME/rule-providers — **wiki/rules**
  - TUN vs System Proxy: gVisor/mixed, auto-route/strict-route/MTU, registry vs networksetup vs gsettings — **wiki/tun + build notes**
  - DNS: FakeIP 198.18.0.1/16, DoH/DoT, fake-ip-filter-mode, respect-rules — **wiki/dns + issue #1977**
  - Groups: manual select / fallback / urltest / load-balance + health-check — **wiki/proxy-groups**
  - Other: WebDAV v0.8.4, sqlite v0.8.92, overwrite v0.8.93, tile/TV v0.8.95, geo update, force restart — **changelog**
  - Platforms: Android TV tile, Windows service, macOS perf, Linux silent launch — **changelog 0.8.94/0.8.89/0.8.88/0.8.86**
  - Stats: 50.3k stars, v0.8.96, build `dart setup.dart` + GCC/NDK — **README + releases + setup.dart**

- **Last verified**
  - `2026-08-30` UTC via `webfetch` + `websearch` live pulls; this file at `C:\Users\qmahyar\Desktop\VPN Research\11-FlClash.md`

---

*Generated for VPN Research series 11/ — FlClash specialization. Bullet+sub-bullet HOW throughout, 400+ lines, sources cited above.*
