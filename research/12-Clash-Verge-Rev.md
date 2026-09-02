# Clash Verge Rev (clash-verge-rev/clash-verge-rev) — Extreme-Detail Research

> Tauri 2 + Rust + React 19 successor to zzzgydi/clash-verge — Mihomo (ClashMeta) GUI for Windows / macOS / Linux — GPL-3.0 — 141k+ stars

---

## Table of Contents

- [1. Overview — HOW Clash Verge Rev Is Positioned](#1-overview--how-clash-verge-rev-is-positioned)
- [2. Supported Protocols via Mihomo — HOW Each Proxy Type Works](#2-supported-protocols-via-mihomo--how-each-proxy-type-works)
- [3. Config Formats & Subscription Handling — HOW Verge Handles Profiles](#3-config-formats--subscription-handling--how-verge-handles-profiles)
- [4. Core — Mihomo (ClashMeta) Sidecar — HOW Tauri Spawns & Controls Core](#4-core--mihomo-clashmeta-sidecar--how-tauri-spawns--controls-core)
- [5. Routing / Split Tunneling — HOW Clash Rule Engine & Providers Work](#5-routing--split-tunneling--how-clash-rule-engine--providers-work)
- [6. TUN vs System Proxy — HOW Traffic Capture Differs](#6-tun-vs-system-proxy--how-traffic-capture-differs)
- [7. DNS — HOW Clash DNS Fake-IP / Redir-Host Works](#7-dns--how-clash-dns-fake-ip--redir-host-works)
- [8. Other Features — HOW Web UI, Logs, Theme, Shortcuts, Backup Work](#8-other-features--how-web-ui-logs-theme-shortcuts-backup-work)
- [9. Platforms — HOW Verge Behaves Per OS](#9-platforms--how-verge-behaves-per-os)
- [10. Repo Stats, Releases, Build — HOW to Build & Track](#10-repo-stats-releases-build--how-to-build--track)
- [11. References & Verification](#11-references--verification)

---

## 1. Overview — HOW Clash Verge Rev Is Positioned

- **What it is**
  - Continuation of [zzzgydi/clash-verge](https://github.com/zzzgydi/clash-verge) — verbatim tagline: `Continuation of Clash Verge — A Clash Meta GUI based on Tauri`
    - Original Clash Verge archived / unmaintained → community fork `clash-verge-rev` took over under org `clash-verge-rev`
    - Not a VPN provider — **GUI client** that consumes user-supplied Clash/Mihomo YAML subscriptions or local files and drives the Mihomo kernel
  - Electron successor lineage:
    - `Fndroid/clash_for_windows_pkg` (Electron, original Clash) → `Dreamacro/clash` (Go, archived) → `zzzgydi/clash-verge` (Tauri 1, Vue) → `clash-verge-rev` (Tauri 2, React 19, Rust 2024 edition)
    - Motivation: replace Electron's ~150 MB + high RAM with Tauri's WebView + Rust backend → ~30 MB installer, native performance

- **License**
  - **GPL-3.0** — `LICENSE` at repo root, `GPL-3.0 License. See License here` in README + GitHub sidebar `GPL-3.0 license` badge
    - Verified via webfetch 2026-08-30: `https://github.com/clash-verge-rev/clash-verge-rev` → License field `GNU General Public License v3.0`
    - All forks / redistributions must preserve GPL-3.0

- **Tech stack — HOW it is built**
  - **Tauri 2.x** as desktop shell (replaced Tauri 1 in v2.0.0 — Breaking change notes in `v2.0.2` changelog)
    - Rust backend (`src-tauri/`) with 2024 edition, `tauri::generate_handler!` IPC, plugin system, multi-window
    - Frontend host is OS native WebView (Windows WebView2, macOS WKWebView, Linux WebKitGTK) — no bundled Chromium
  - **Rust (backend)**
    - Tokio async runtime + `tauri-plugin-mihomo` + `tauri-plugin-clash-verge-sysinfo` + `tauri-plugin-deep-link`
    - Handles: core lifecycle, config drafting, system proxy registry, service IPC, WebDAV sync, auto-launch, shortcuts
    - `Cargo.toml` workspace: `src-tauri/Cargo.toml`, `crates/` sub-crates for plugins
  - **React 19 + TypeScript + MUI 7.x** (frontend)
    - Single-page app: `src/pages/_layout.tsx` shell, `src/pages/*.tsx` views (Proxies, Profiles, Rules, Connections, Settings)
    - `src/services/cmds.ts` — typed wrapper over `invoke()` IPC; `tauri-plugin-mihomo-api` for direct core polling
    - State: SWR / TanStack React Query (`useVerge`, `useClash`, `staleTime: 5000ms`)
    - Styling: SCSS + MUI + CSS Injection for user theme overrides
  - **Build tooling**
    - `pnpm` (v10+), `Vite`, `Biome` lint/format, `eslint.config.ts`, `vitest.config.mts`, `Makefile.toml` (cargo-make), `deny.toml` (cargo-deny)
    - `.tool-versions` pins Rust 1.91+, Node 18+, pnpm 10+ (see CONTRIBUTING.md)

- **Cross-platform claim — HOW it delivers**
  - **Windows** x64 + x86 + arm64 (NSIS installer + portable zip, `fixed_webview2` variant bundles WebView2 runtime)
  - **Linux** x64 + arm64 + armhf (`.deb` for Debian/Ubuntu via `apt ./path`, `.rpm` for Fedora/RH via `dnf ./path`, `AppImage` in older tags)
  - **macOS** 11+ Intel (`x64.dmg`) + Apple Silicon (`aarch64.dmg` + `app.tar.gz`)
    - Every release publishes ~28 assets (example `v2.0.2`: `x64-setup.exe` 30.6 MB 461k downloads, `x64.dmg` 40.8 MB, `amd64.deb` 42.5 MB, etc.)
  - HOW to pick installer:
    - Daily use → `Stable` channel via `https://github.com/clash-verge-rev/clash-verge-rev/releases`
    - Rolls / canary → `AutoBuild` tag `autobuild` (rolling, may have defects)
    - Legacy pipeline validation → `Alpha (EOL)` tag `alpha` (deprecated)

- **Scale & popularity — live GitHub metrics (fetched 2026-08-30)**
  - **Stars:** **141.0k** (webfetch GitHub sidebar `141.0k stars`; Oct 2024 `135k`; v2.4.4-rc.1 page `123K` → growth continues)
  - **Forks:** **10.1k**
  - **Watchers:** **379**
  - **Open Issues:** **392** (+ 26 open PRs) — very active
  - **Commits:** **4,692** on `dev` branch (default branch = `dev`)
  - **Commits history graph:** `4,692 Commits` link on GitHub file browser
  - **Homepage:** `https://www.clashverge.dev` / docs at `https://clash-verge-rev.github.io` / `https://clash-verge-rev.github.io/docs`
  - **Telegram:** `@clash_verge_rev` (docs + README badge)
  - **Topics:** `clash`, `clash-meta`, `clash-verge`, `linux`, `mac`, `mihomo`, `tauri-app`, `windows`

- **Features tagline (README verbatim, Chinese + English)**
  - `基于性能强劲的 Rust 和 Tauri 2 框架` → Built on high-performance Rust with the Tauri 2 framework
  - `内置 Clash.Meta(mihomo) 内核，并支持切换 Alpha 版本内核` → Ships with embedded Mihomo core and supports switching to the Alpha channel
  - `简洁美观的用户界面，支持自定义主题颜色、代理组/托盘图标以及 CSS Injection` → Clean UI with theme color controls, proxy group/tray icons, and CSS Injection
  - `配置文件管理和增强（Merge 和 Script），配置文件语法提示` → Enhanced profile management (Merge and Script helpers) with configuration syntax hints
  - `系统代理和守卫、TUN(虚拟网卡) 模式` → System proxy controls, guard mode, and TUN (virtual network adapter) support
  - `可视化节点和规则编辑` → Visual editors for nodes and rules
  - `WebDav 配置备份和同步` → WebDAV-based backup and sync for configurations

- **Why users pick Verge Rev over alternatives**
  - Versus **Clash for Windows (CFW)** / **ClashX** (archived, original Clash kernel, Electron) → Verge Rev uses **Mihomo** so VLESS/Reality/Hysteria2/TUIC/WireGuard parse instead of `unsupported proxy type`
  - Versus **Clash Verge (original zzzgydi)** → original archived; Rev adds Tauri 2, React 19, service mode overhaul, WebDAV, active releases
  - Versus **FlClash / Clash Nyanpasu (Flutter)** → Verge Rev is Rust+React, deeper Windows service integration (`sysproxy.exe` injection), richer JS merge/script chain
  - Versus **sing-box GUI clients** → Verge Rev is Clash YAML native; conversion needed for sing-box JSON → Mihomo YAML via subconverter

- **Three-layer architecture (DeepWiki fetch 2026-08-30)**
  - Frontend (React/TS) → Tauri IPC Bridge (`cmds.ts` + `tauri-plugin-mihomo-api` pool min 3 max 32) → Backend (Rust: CoreManager, Config `IVerge/IClash/IProfiles`, ServiceManager, AsyncHandler/Tokio)
  - Data flow on settings change: `patch_verge_config` / `patch_clash_config` → Draft pattern (`clash-verge-draft` atomic) → apply Merge/Script enhancements → CoreManager writes `config.yaml` → signals Mihomo `-ext-ctl` reload

---

## 2. Supported Protocols via Mihomo — HOW Each Proxy Type Works

> Clash Verge Rev implements **no protocol itself** — 100% delegated to the **Mihomo (Clash.Meta) Go core** (`MetaCubeX/mihomo`) spawned as a Tauri sidecar. The registry below mirrors `constant/adapters.go`, `wiki.metacubex.one/en/config/proxies/`, and `target_profile.rs:64 MIHOMO_CAPABILITIES`.

- **Mihomo adapter enum — complete set that Verge Rev can render**
  - Built-in policies: `DIRECT`, `REJECT`, `REJECT-DROP`, `COMPATIBLE`, `PASS`, `DNS`
  - Group types: `select`, `fallback`, `url-test`, `load-balance`, `relay`
  - Proxy types (outbound): `ss`, `ssr`, `socks5`, `http`, `snell`, `vmess`, `vless`, `trojan`, `hysteria`, `hysteria2`, `tuic` (v4/v5), `wireguard`, `ssh`, `anytls`, `mieru`, `sudoku`, `shadowquic`, `shadow-tls`, `shadowsocks` inbound variants, `masque`, `trusttunnel`, `zerotier`, `tailscale`, `openvpn`
  - Inbound listeners (Verge can configure via YAML): `http`, `socks`, `mixed`, `redir`, `tproxy`, `tun`, `shadow-tls`, `mieru`, `tuic`, `hysteria2`, `snell`, `anytls`, `vmess`, `vless`, `trojan`, `shadowquic`, `wireguard`
  - Common fields every node supports (wiki `proxies/index.en.md: Common fields`):
    - `name`, `type`, `server`, `port`, `ip-version: dual/ipv4/ipv6/ipv4-prefer/ipv6-prefer`, `udp: true/false`, `interface-name: eth0`, `routing-mark: 1234`, `tfo`, `mptcp`, `dialer-proxy: GROUP`, `smux: { enabled, protocol: smux/yamux/h2mux, max-connections, min-streams, max-streams, statistic, only-tcp, padding, brutal-opts: { enabled, up, down } }`

- **Shadowsocks — `type: ss`**
  - HOW it works:
    - Symmetric AEAD encryption (password + cipher) → TCP relay; lightweight, minimal handshake
    - Mihomo ciphers: `aes-128-gcm`, `aes-192-gcm`, `aes-256-gcm`, `aes-128-cfb/ctr`, `chacha20-ietf`, `xchacha20`, `chacha20-ietf-poly1305`, `xchacha20-ietf-poly1305`, `2022-blake3-aes-128-gcm`, `2022-blake3-aes-256-gcm`, `2022-blake3-chacha20-poly1305`
    - Optional `plugin: obfs` / `v2ray-plugin` (`mode: http/tls`, `host`, `path`) for simple obfuscation
  - HOW Verge Rev surfaces:
    - Profiles editor lists cipher dropdown; `udp: true` toggle per node; `udp-over-tcp` when UDP blocked
    - Delay test respects `udp` flag — if `udp: false` on UDP probes, Verge skips and shows grayed
  - Verge YAML snippet pattern:
    - `- { name: HK-SS, type: ss, server: 1.2.3.4, port: 8388, cipher: aes-256-gcm, password: xxx, udp: true }`

- **ShadowsocksR — `type: ssr`**
  - Legacy obfuscated SS fork; fields: `cipher`, `password`, `obfs: plain/http_simple/http_post`, `protocol: origin/auth_sha1_v4/auth_aes128_md5`, `obfs-param`, `protocol-param`
  - Mihomo keeps adapter for backward compat; Verge Rev still parses SSR links from old providers
  - Recommendation: migrate provider to `2022-blake3` SS or VLESS; SSR has known fingerprint issues

- **VMess — `type: vmess` (V2Ray native)**
  - HOW it works:
    - UUID + `alterId` + `cipher: auto/aes-128-gcm/chacha20-poly1305/none` + timestamp auth; full inner encryption
    - `network:` transports: `tcp` (default), `ws` via `ws-opts: { path, headers: { Host } }`, `h2` via `h2-opts: { host: [], path }`, `http`, `grpc` via `grpc-opts: { grpc-service-name: gunService, ping-interval }`, `xhttp` (Mihomo extension)
    - `tls: true` + `servername`, `alpn: [h2, http/1.1]`, `fingerprint` pin, `client-fingerprint: chrome/firefox/safari/ios/random/edge/qq`, `skip-cert-verify`, `ech-opts`
    - `mTLS`: `certificate` + `private-key` PEM maps
  - HOW Verge Rev handles:
    - Import decodes `vmess://base64-json` → fills editor; visual WS path editor; `smux` toggles in advanced drawer
    - `smux.enabled: true` + choice `smux/yamux/h2mux` editable per node
  - Caveat vs VLESS: double encryption overhead (VMess cipher + TLS) vs VLESS delegating to TLS only

- **VLESS — `type: vless` (Mihomo-exclusive)**
  - HOW it differs from VMess:
    - **No inner encryption** — header only `uuid` + control; confidentiality from outer `tls: true`
    - Shorter header → lower CPU, plus `flow: xtls-rprx-vision` allows TLS record passthrough without re-encryption (high throughput)
    - **Reality** option: `reality-opts: { public-key: x25519, short-id: hex, server-name: sni, fingerprint: chrome }` — steals real site TLS fingerprint → no own cert/domain needed
    - Fields: `uuid`, `flow: xtls-rprx-vision` (or empty), `packet-encoding: xudp`, `tls: { enable, servername, alpn, fingerprint, client-fingerprint, skip-cert-verify, shadow-tls-opts: { version:3, password }, restls-opts: { password, version-hint: tls13 }, jls-opts, reality-opts }`, `network: tcp/ws/http/h2/grpc/xhttp`
    - Must be `tls: true` or `reality-opts` present — bare VLESS without TLS rejected by Mihomo validator (`verify()` in `subscribe/clash.py:522`)
    - `MIHOMO_CAPABILITIES` flag: `reality: true`, `client_fingerprint: true`, `udp_over_tcp: true` — Stash/Original Clash lack these (Stash has `client_fingerprint: false`)
  - HOW Verge Rev handles:
    - Reality fields rendered as `reality-opts` collapsible; Verge validates `flow` matches server `xtls-rprx-vision` vs plain
    - Provider `vless://uuid@host:443?encryption=none&flow=xtls-rprx-vision&security=reality&...` auto-split into Mihomo keys on import
  - Failure mode: mismatch `fingerprint`/`short-id`/`public-key` → handshake `406` or `reality verification failed` in core logs

- **Trojan — `type: trojan`**
  - HOW it works:
    - Password over TLS 443; outside view = normal HTTPS; auth is single `password` line
    - Core fields: `password`, `sni`, `alpn`, `client-fingerprint`, `fingerprint` (SHA256 pin), `skip-cert-verify`, `tls: true`
    - Transports: plain TLS (`network: tcp`) or `network: ws` + `ws-opts`, `network: grpc` + `grpc-opts`, `network: h2`
    - `ss-opts: { enabled, method, password }` — inner Shadowsocks inside Trojan (Trojan-Go style)
  - HOW Verge Rev handles:
    - Trojan nodes show `sni` + `alpn` badges; WebSocket path editor shares VMess component
    - `trojan://password@host:443?sni=...&type=ws&path=...#name` parsed on subscription import
  - Self-host guide link in wiki: Trojan needs domain+cert → best disguise on port 443; otherwise use Trojan+WS+TLS behind CDN

- **HTTP / HTTPS / SOCKS5 — `type: http`, `type: socks5`**
  - Plain relay (`http`: CONNECT tunnel, `socks5`: SOCKS5 handshake); fields: `username`, `password`, `tls`, `sni`, `skip-cert-verify`, `ip-version`, `udp: true` (SOCKS5 UoT)
  - Verge dual use:
    - As **local inbound** (`mixed-port: 7890` yields HTTP+SOCKS on one port) — configured in Verge Settings → `Clash Config` → `mixed-port`
    - As **outbound** for upstream corporate forward proxies (e.g., corporate `http://proxy.corp:8080` chained via `dialer-proxy`)
  - Subscriptions rarely emit these as primary nodes; Verge shows them as `DIRECT`-like relay nodes

- **Snell — `type: snell` (Surge)**
  - HOW it works:
    - Surge proprietary, versions `1`-`4`; fields: `psk`, `version: 3`, `obfs-opts: { mode: http/tls, host: bing.com }`
    - Comment in Mihomo `docs/config.yaml: snell` → `No UDP support yet` on some versions — verify per `version`
  - HOW Verge Rev handles: version dropdown; obfs host field; Verge warns if UDP rule routes to Snell with `udp: false`

- **Hysteria (v1) — `type: hysteria`**
  - HOW it works:
    - UDP-based QUIC-like with custom congestion; fields: `auth-str`/`auth_str`, `obfs`, `protocol: udp/wechat-video/faketcp`, `up: 50 Mbps`, `down: 100 Mbps`, `sni`, `alpn: h3`, `skip-cert-verify`, `recv_window_conn`, `recv_window`, `disable_mtu_discovery`
    - Superseded by Hysteria2; Mihomo keeps for compat; Verge shows `(deprecated)` hint
  - HOW Verge Rev handles: `up`/`down` bandwidth normalized to Mbps; `ports` range not present in v1

- **Hysteria2 — `type: hysteria2` (Mihomo-exclusive, QUIC/RFC9000)**
  - HOW it works:
    - Over UDP + QUIC; 0-RTT handshake, connection migration (Wi-Fi↔cell switch no reconnect), BBR-style aggressive CC that saturates even with 20% loss
    - Fields: `password` (auth string), `obfs: salamander`, `obfs-password`, `up`/`down` (link capacity, e.g., `20 Mbps`), `ports: 443` or `ports: 443-500`, `sni`, `alpn: h3`, `skip-cert-verify`, `fingerprint`, `pinSHA256`, `masquerade: https://bing.com` (HTTP/3 disguise)
    - Link format: `hysteria2://password@host:443/?sni=...&obfs=salamander&obfs-password=...#name` or `hy2://`
  - HOW Verge Rev handles:
    - Hysteria2 cards show up/down, obfs toggle, ports range; delay test opens QUIC 0-RTT; logs show `hysteria2 handshake` level debug
    - Docs recommend `hysteria2` for transoceanic / noisy 4G/5G where TCP retrans storms hurt
  - Battery note: aggressive CC keeps radio awake — provider should tune keepalive; Verge exposes `lazy: true` on url-test to reduce wakeups

- **TUIC v5 — `type: tuic` (Mihomo-exclusive, QUIC)**
  - HOW it works:
    - QUIC wrapper focused on **low overhead** vs Hysteria2's throughput push; native UDP relay modes:
      - `udp-relay-mode: native` — UDP datagrams → QUIC DATAGRAM frames (lowest latency, gaming/voice)
      - `udp-relay-mode: quic` — UDP over QUIC streams (reliable fallback)
    - Fields: `token` **or** (`uuid` + `password`), `ip`, `port`, `congestion-controller: bbr/cubic/new_reno`, `heartbeat-interval`, `alpn: h3`, `sni`, `skip-cert-verify`, `disable-sni`, `reduce-rtt: true`, `max-udp-relay-packet-size`, `fast-open`, `ecn: true`
    - QUIC details: uses `qlog` congestion; sticks with standard QUIC CC → more graceful under UDP throttling than Hysteria2's Brutal
    - Link: `tuic://uuid:password@host:443?congestion_control=bbr&udp_relay_mode=native&alpn=h3#name`
  - HOW Verge Rev handles:
    - TUIC editor shows congestion dropdown, relay mode radio, heartbeat slider
    - Versus Hysteria2 decision: TUIC for **latency-sensitive** gaming/video; Hysteria2 for **bandwidth-saturated** lossy links

- **WireGuard — `type: wireguard` / `wg`**
  - HOW it works:
    - Modern L3 VPN via Noise protocol (~4000 LOC, kernel 5.6+); Mihomo embeds so WG can be a proxy node inside rule engine
    - Fields: `private-key`, `public-key`/`peers: [{ public-key, allowed-ips: [0.0.0.0/0], endpoint: host:port, pre-shared-key }]`, `ip: 172.16.0.2/32`, `ipv6: fd00::2/128`, `allowed-ips`, `reserved: [0,0,0]` (WARP zero), `mtu: 1280`, `dns: [1.1.1.1]`, `keepalive: 25`, `workers: 8`, `udp: true`, `amnezia-wg-option: { jc: 5, jmin: 30, jmax: 1000, s1..s4, h1..h4 }` (AmneziaWG junk obfuscation)
    - When `peers:` array present → top-level `server/port/public-key` ignored except `private-key`
  - HOW Verge Rev handles:
    - WG cards expand to peer list; `reserved` three-int array for WARP; `mtu` editable
    - Use case: VPS self-host WG endpoint, or WARP (`engage.cloudflareclient.com:2408`) as one node in select group
  - Subscriptions: `wireguard://` rarely emitted directly; providers wrap as `type: wireguard` inside Clash YAML

- **SSH — `type: ssh`**
  - HOW it works:
    - SSH tunnel (`server`, `port`, `username`, `password` **or** `private-key` + `private-key-passphrase`, `host-key: [ssh-ed25519 AAA...]`, `host-key-algorithms`, `client-version`)
    - Adapter exists for reusing existing `sshd` as SOCKS-like proxy; not many commercial providers emit SSH links
  - HOW Verge Rev handles: renders key fields; warns that hop adds SSH handshake latency → prefer native proxy types

- **AnyTLS — `type: anytls` (Mihomo-exclusive)**
  - HOW it works:
    - TLS-based lightweight proxy introduced in Mihomo 2024+; fields: `password`, `server`, `port`, `sni`, `alpn`, `skip-cert-verify`, `client-fingerprint`, `idle-session-check-interval`, `idle-session-timeout`, `min-idle-session`
    - Flag: `MIHOMO_CAPABILITIES` includes `AnyTls` (seen `target_profile.rs:79`)
  - HOW Verge Rev handles: editor shares Trojan TLS section; provider links `anytls://password@host:443?sni=...#name`

- **Mieru / Sudoku / ShadowQUIC / VLESS-inbound variants / MASQUE etc.**
  - HOW to think:
    - Mihomo config enumerates many **inbound listeners** (`config/inbound/listeners/`) and corresponding **outbound adapters** (`config/proxies/`): `mieru`, `sudoku`, `shadowquic`, `shadow-tls`, `shadow-tls`+VLESS, `masque`, `trusttunnel`, `zerotier`, `tailscale`, `openvpn`, `hysteria2-realm`
    - Most commercial subscriptions **do not** emit these; they appear only for self-hosters who run `inbound: { type: mieru, ... }` on server
    - Verge Rev still parses them if present in YAML (shows badge with type string) but docs mark as advanced
  - Reference: `https://wiki.metacubex.one/en/config/proxies/` left nav lists all 24 proxy docs; `https://wiki.metacubex.one/en/config/inbound/listeners/` lists TUIC v4/v5, ShadowQUIC, Hysteria2 Realm, etc.

- **Common TLS/transport knobs — HOW Verge propagates to every protocol**
  - `udp: true/false` — enables UDP relay (DNS, QUIC, gaming, VoIP); per Mihomo `common fields` note `enabled by default for TUIC/direct/dns`
  - `udp-over-tcp: true` — tunnel UDP inside TCP when UDP blocked (Mihomo adds `UoT` fallback)
  - `ip-version: dual/ipv4/ipv6/ipv4-prefer/ipv6-prefer` — node outbound resolution; `ipv4-prefer` races both but prefers v4
  - `tfo: true` (TCP Fast Open), `mptcp: true` (Multipath TCP) — transport flags editable in Verge advanced per-node sheet
  - `smux` multiplex (TCP only): `enabled: true`, `protocol: h2mux` (default Go `x/net/http2`), or `smux` (xtaci) or `yamux` (hashicorp); `max-connections: 4`, `min-streams: 4`, `max-streams: 0`, `only-tcp: false`, `padding: true`, `brutal-opts: { enabled, up, down }`
  - `dialer-proxy: SELECTOR-NAME` — chain node through another group/node (Verge chain proxy: `dialer-proxy` dropdown)
  - `fingerprint` (pin SHA256), `servername` (SNI override), `client-fingerprint` (uTLS), `ech-opts` (ECH), `skip-cert-verify`, `alpn`, `tls: true`
  - HOW Verge surfaces: global overrides via `proxy-providers.override:` or Merge/Script can flip `tfo/mptcp/udp/interface-name/routing-mark/dialer-proxy` en masse

---

## 3. Config Formats & Subscription Handling — HOW Verge Handles Profiles

- **Primary format: Clash YAML (Mihomo-compatible)**
  - HOW it looks — top-level keys Verge expects/edits (from `https://github.com/MetaCubeX/mihomo/blob/Meta/docs/config.yaml` complete example):
    - `mixed-port: 7890` (or legacy `port`/`socks-port`/`redir-port`/`tproxy-port`) — Verge controls this field itself (overridden, see below)
    - `allow-lan: false`, `bind-address: '*'`, `ipv6: false`, `unified-delay: false`, `tcp-concurrent: true`, `keep-alive-interval: 30`
    - `mode: rule` (default) / `global` / `direct` — Verge toggles via tray / `Clash Mode` selector
    - `log-level: info` (`debug`/`info`/`warning`/`error`/`silent`) — Settings → `Log Level`
    - `external-controller: 127.0.0.1:9090` + `secret: ""` — Verge reserves these; Merge override on these keys is ignored (see `cannot override` note)
    - `proxies: [{ name, type, server, port, ... }]` — inline nodes
    - `proxy-providers: { name: { type: http/file, url, path, interval: 3600, proxy: DIRECT, size-limit, header: { User-Agent } } }`
    - `proxy-groups: [{ name, type: select/fallback/url-test/load-balance/relay, proxies: [], use: [], url, interval, ... }]`
    - `rules: ["DOMAIN,ad.com,REJECT", "MATCH,PROXY"]` — ordered list
    - `rule-providers: { name: { type: http, behavior: domain/ipcidr/classical, format: yaml/text/mrs, url, path, interval } }`
    - `dns: { enable: true, listen, enhanced-mode, fake-ip-range, nameserver, fallback, ... }`
    - `tun: { enable, stack, auto-route, dns-hijack, ... }`
    - `sniffer: { enable, sniff: { HTTP: { ports }, TLS: { ports }, QUIC: {...} }, skip-domain }`, `hosts: {}`, `profile: { store-selected, store-fake-ip }`, `geodata-mode`, `geox-url`, `listeners: []`, `ntp`, `experimental`
  - Verge **parses directly** — no subconverter needed for Clash YAML (unlike sing-box JSON)

- **Mihomo YAML extensions — HOW they extend classic Clash**
  - Extra proxy types listed above (`vless`, `tuic`, `hysteria2`, `wireguard`, `anytls`, `mieru` ...) — original Clash shows `unsupported proxy type` on these
  - Extra rule syntax:
    - `GEOSITE,category,PROXY` (v2fly domain-list-community geosite DB), `GEOIP,CN,DIRECT` now with `mmdb`/`country-lite.mmdb`, `RULE-SET,providername,proxy` + `rule-providers` with `behavior: domain/ipcidr/classical` + `format: yaml/text/mrs` (binary MRS compiled via `mihomo convert-ruleset`)
  - Extra DNS (see DNS section): `nameserver-policy`, `proxy-server-nameserver`, `direct-nameserver`, `fallback-filter: { geoip, geosite, ipcidr, domain }`, `fake-ip-filter-mode: blacklist/whitelist/rule`, `prefer-h3`, `cache-algorithm: arc`
  - Extra TUN (see TUN section): `stack: system/gvisor/mixed`, `strict-route`, `endpoint-independent-nat`, `route-address`, `smux.brutal-opts`
  - Extra sniffer, NTP, experimental, `listeners` inbound, `sub-rule`, `tunnels`
  - Backward compat is **one-way**: Mihomo accepts original Clash YAML unchanged; original Clash chokes on Mihomo fields

- **Subscription links — HOW Verge imports**
  - Verge supports **3 import entrypoints** (Profiles page → `New` / `Import`):
    - **`Remote` URL** — `https://sub.example.com/clash?token=xxx` returning Clash YAML (most common: provider subscription link)
      - HOW: paste URL → Verge fetches via Rust `reqwest` (uses `User-Agent: clash-verge/v2.x` + `clash-verge` UA) → saves to `profiles/{uuid}.yaml` cache
      - Supports `clash://` / `clashmeta://` / `clash-verge://` deep links via `tauri-plugin-deep-link` (URL Schemes page: `clash://install-config?url=...`)
      - Example deep link: `clash://install-config?url=https://sub.example.com/clash.yaml&name=MySub`
    - **`Local` File** — drag-and-drop `.yaml` / `.yml` onto Verge window or `Import → File` picker
      - HOW: Rust reads file → validates YAML → copies to profiles dir → shows in Profiles list
    - **`Content` / Inline** — paste raw YAML text into editor (clipboard import, `New → Paste Content`)
    - `Merge` (`*.yaml` + `prepend-*/append-*` semantics) and `Script` (`*.js` via `boa_engine`) are **not** main profiles but **enhanced** (see below)
  - Auto-update:
    - Each Remote profile stores `interval` (default provider header or Verge `updateInterval: 720` minutes) and `updatedAt`
    - Verge shows countdown; `Update All` button or per-profile `Update` (↻) fetches anew
    - Settings → `Profiles` → `Auto Update` toggles cron fetch; on failure Verge keeps last-good cached file and shows red dot + error toast via `showNotice`
  - Advanced import knobs:
    - Verge docs (`guide/profile.html`) show subscription via `clash://` scheme auto-registers on Windows (`registry URL protocol`) and macOS (`Info.plist` + `CFBundleURLSchemes`)
    - Providers returning non-YAML (e.g., base64 `ss://` list) → Verge shows parse error; need provider to add `&flag=clash` param or run through `sub-store` / `subconverter` before import

- **sub-store / subconverter — HOW non-Clash formats reach Verge**
  - Verge **does not** bundle a built-in sing-box JSON → Clash converter (unlike some sing-box clients that bundle subconverter WASM)
  - If provider emits `sing-box` JSON (`{ "outbounds": [{ "type": "vless", ... }] }`) or plain `ss://` / `vmess://` share links:
    - Workarounds:
      - Provider side: request `&target=clash` / `&flag=clash` endpoint (many airports offer dual `Clash` and `sing-box` links — pick `Clash/Mihomo`)
      - Client side: run `subconverter` / `sub-store` (ACL4SSR) externally: `subconverter --target clash --url 'https://...' --output clash.yaml` then import produced `clash.yaml` as Local file
      - Verge Script: write a `main(config)` JS that remaps sing-box JSON keys to Mihomo `proxies:{ name,type,server,port }` (error-prone — only for power users, documented in Verge Script examples)
  - Reference `target_profile.rs:64-84 MIHOMO_CAPABILITIES` shows subconverter's Mihomo flavor includes `Shadowsocks, ShadowsocksR, VMess, Trojan, Snell, HTTP, HTTPS, Socks5, WireGuard, Hysteria, Hysteria2, Vless, AnyTls, Tuic` — tells Verge which types survive conversion

- **Profile chain & enhanced mode — HOW Verge layers Merge + Script (CFW-inspired)**
  - Types (from Verge docs `guide/profile.html` + `clashvergerev.com/en/guide`):
    - **Main profiles** (2): `Remote` (URL) + `Local` (file/content) — exactly **one** selected as active (green indicator) at a time; if none selected → empty default config
    - **Enhanced profiles** (2): `Merge` (YAML patch) + `Script` (JavaScript `main(config)`) — modify the main profile **in chain**
  - `Merge` profile:
    - File format `*.yaml` with keys:
      - `prepend-rules: []`, `append-rules: []` (rules prepend/append)
      - `prepend-proxies: []`, `append-proxies: []`
      - `prepend-proxy-groups: []`, `append-proxy-groups: []`
      - `prepend-rule-providers: {}`, `append-rule-providers: {}`
      - `prepend-proxy-providers: {}`, `append-proxy-providers: {}`
      - Direct override keys: any top-level Mihomo key like `dns: { ipv6: false }`, `tun: { stack: mixed }`, `sniffer: {...}` — Verge merges them (shallow + deep merge)
    - HOW to enable: `Right-click Merge card → Enable` → colored indicator on card; after edit `Disable → Enable` or top-right 🔥 button to re-apply
    - Order: multiple Merge cards execute **sequentially in activation order** (first enabled → first applied)
    - Warning: Verge **cannot override** fields it reserves for itself (`mixed-port`, `external-controller`, `secret`, `log-level` controlled via Verge Settings) — override on those keys is silently dropped to preserve self-control
    - Example (add custom rule before original `MATCH`):
      - `prepend-rules: ["DOMAIN-SUFFIX,google.com,PROXY", "DOMAIN-KEYWORD,telegram,PROXY"]`
      - `dns: { ipv6: false }` to force-disable AAAA
  - `Script` profile:
    - Language: `javascript` (QuickJS / `boa_engine` — not Node; no `fs` access)
    - Entry: `function main(config) { /* mutate config object */ return config; }` — `config` is parsed YAML as JSON object
    - HOW to enable: paste JS → `Enable` → on success green indicator; on throw → red indicator + error message shown, changes skipped
    - Multiple Scripts: chained sequentially like Merge (output of Script N becomes input of N+1)
    - Example (force all ws nodes to use `ws-opts` new schema, from Verge docs):
      - `function main(c){ if(!c.proxies) return c; c.proxies.forEach(p=>{ if(p.network==="ws"&&(p["ws-path"]||p["ws-headers"])){ const o=p["ws-opts"]||{}; o.path=p["ws-path"]; o.headers=p["ws-headers"]; delete p["ws-path"]; delete p["ws-headers"]; } }); return c; }`
  - **Profile processing flow (Verge canonical order):**
    1. Select active main profile (`Remote`/`Local`) or empty default if none
    2. Apply each enabled `Merge` in activation order (prepend/append + direct overrides)
    3. Apply each enabled `Script` in activation order (`main()` chain), QuickJS execution with no `fetch`/`fs`
    4. Rust drafts final YAML into `clash-verge-draft` atomic write → validates via `validate_and_fix_config` → CoreManager writes `config.yaml` → signals Mihomo `SIGHUP` / `PUT /configs` reload
    - If any Script throws → that Script's changes skipped, profile turns red with stack, but chain continues

- **Profile files on disk — HOW Verge persists**
  - Directory: Settings → `Open Config Directory` shows path
    - Windows: `%APPDATA%\io.github.clash-verge-rev.clash-verge-rev\` → `profiles/` subdir + `config.yaml` (merged) + `verge.yaml` (app settings) + `clash.yaml` draft
    - macOS: `~/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev/`
    - Linux: `~/.config/clash-verge-rev/` or `~/.local/share/`
  - Files:
    - `profiles/*.yaml` — raw Remote/Local/Merge YAML + `*.js` for Script profiles (+ `.meta.json` per profile storing URL, interval, last-updated)
    - Verge YAML syntax hints: Profiles editor uses Monaco editor with Mihomo JSON schema hints (prefix autocomplete for `type:`, `rules:`)

---

## 4. Core — Mihomo (ClashMeta) Sidecar — HOW Tauri Spawns & Controls Core

- **What Mihomo is**
  - Lineage: **Original Clash** (Dreamacro/clash, Go, archived, Premium TUN closed-source) → **ClashMeta / Clash.Meta** (community fork, added VLESS/Hysteria/TUIC/WG, before original archive) → **Mihomo** (renamed `MetaCubeX/mihomo`, actively maintained, now `KERNEL mihomo` badge on ecosystem sites)
  - Reference: wiki `Clash Encyclopedia` table: Original Clash `Archived`, Mihomo `Actively maintained`; protocol coverage `Everything original supports plus VLESS/REALITY/Hysteria2/TUIC/WireGuard/ShadowTLS`

- **Sidecar pattern — HOW Verge embeds a Go binary**
  - Binaries in `src-tauri/sidecar/` (per platform `verge-mihomo` + `verge-mihomo-alpha`):
    - Stable core: `verge-mihomo` — Mihomo release channel `Stable` (pinned version, e.g., `1.18.10` in `v2.0.2` changelog → `Meta(mihomo)内核升级 1.18.10`)
    - Alpha core: `verge-mihomo-alpha` — newer Mihomo pre-release (bleeding VLESS/TUIC bugfixes); user picks channel in Settings → `Clash Core` → `Stable` / `Alpha`
    - Downloaded during `pnpm run prebuild` (mandatory before first `pnpm dev`; skips → panic `missing sidecar binary`)
    - Tauri `tauri.conf.json` `externalBin` lists sidecars so Tauri bundles correct arch (`x86_64-pc-windows-msvc`, `aarch64-apple-darwin`, `x86_64-unknown-linux-gnu`, `aarch64-unknown-linux-gnu`)
  - Spawn:
    - Rust `CoreManager` (`src-tauri/src/core/mod.rs`) calls Tauri sidecar API: `sidecar("verge-mihomo").args(["-d", workDir, "-f", configPath, "-ext-ctl", "127.0.0.1:9090", "-ext-ctl-unix", "mihomo.sock"])`
    - Flags Mihomo actually sees: `-d` (home dir), `-f` (config path), `-ext-ctl` (REST API address), `-secret` if set
    - On Windows `sysproxy` path, args also include `-ext-ctl-tls` variants when user enables TLS controller

- **Tauri IPC → core control — HOW commands reach Rust**
  - Frontend `src/services/cmds.ts` centralizes `invoke()` wrappers:
    - `getVergeConfig` → `get_verge_config`, `patchVergeConfig` → `patch_verge_config`, `getProfiles` → `get_profiles`, `getClashInfo` → `get_clash_info`, `getProxies` → plugin, `patchClashConfig`, `changeProxy`, `testDelay`, etc. (full table in `DeepWiki Frontend-Backend Communication` doc)
  - React hooks `useVerge` / `useClash` wrap cmds with `@tanstack/react-query` (staleTime 5000ms, auto revalidate on focus)
  - Validation before reload:
    - Backend `validate_and_fix_config` (`src-tauri/src/core/mod.rs:13`) parses YAML, injects Verge-reserved keys, checks for duplicate group names, invalid `DOMAIN-REGEX`
    - On failure → `showNotice` toast with line number + error; Profiles card turns red; core keeps running old config

- **REST API (`external-controller`) — HOW Verge & external dashboards talk to Mihomo**
  - Verge starts Mihomo with `--ext-ctl 127.0.0.1:CE1A` (random free port per launch, not fixed 9090) + optional `--ext-ctl-unix` (Unix socket `mihomo.sock`, no secret check) + `--ext-ctl-pipe \\.\pipe\mihomo` (Windows named pipe) + `--ext-ctl-tls` if TLS controller enabled
  - Endpoints Verge polls (via `tauri-plugin-mihomo-api` which maintains connection pool min 3 max 32 sockets):
    - `GET /version` — Mihomo semver shown in Settings → `Clash Core Version`
    - `GET /proxies` + `getProxyProviders` → Proxies page cards + delay dots
    - `PUT /proxies/:groupName` (body `{ name: proxyName }`) → select node in group
    - `GET /connections` + `DELETE /connections/:id` / `DELETE /connections` → Connections page (live closes)
    - `GET /traffic` (WebSocket-like stream) → traffic graph in sidebar (`src/pages/_layout.tsx`)
    - `GET /logs?level=info` (SSE) → Logs page + level filter
    - `GET /rules` → Rules page inspector
    - `GET /configs` + `PUT /configs` → hot reload / `PATCH` after Merge/Script apply
    - `PUT /dns/query?name=example.com` — DNS test
  - `tauri-plugin-mihomo-api` purpose: bypass standard Tauri command routing for perf-critical paths (thousands of proxies, real-time traffic)
  - Security:
    - Verge sets `secret: ""` when binding to `127.0.0.1` loopback; warns if user binds `external-controller: 0.0.0.0` without secret → API can rewrite routing globally
    - `external-controller-cors: { allow-origins: [], allow-private-network: true }` controls browser dashboards (`metacubexd`/`yacd-meta`)

- **Version selection per profile — HOW Verge switches cores**
  - Setting: `Settings → Clash Core → Core Type: verge-mihomo / verge-mihomo-alpha`
  - Verge stores `clashCore: "verge-mihomo"` or `"verge-mihomo-alpha"` in `verge.yaml`; on toggle → kills current sidecar (`CoreManager::stop`) → spawns new binary
  - Logs show `Core version: mihomo/1.18.10` after swap; `Debug` log level captures sidecar stdout/stderr

- **Service vs sidecar — HOW privilege is handled**
  - Sidecar mode (default, no admin):
    - Mihomo runs as **child process** of Verge (same user, no extra privilege); can set System Proxy but **cannot** create TUN interface (TUN needs elevated `NET_ADMIN` / `SeLoadDriver`)
    - `pnpm dev` behavior: preserves existing service state; if service not installed → starts sidecar; `pnpm dev:sidecar` forces unprivileged workflow
  - Service mode (elevated, recommended for TUN):
    - Verge installs `clash-verge-service` via `ServiceManager` (`src-tauri/src/service/`)
      - Windows: Windows Service (`services.msc` entry `Clash Verge Service`, executable `clash-verge-service.exe`, handles TUN adapter + `sysproxy.exe` registry writes without per-launch UAC)
      - macOS: privileged helper `io.github.clash-verge-rev.clash-verge-rev.helper` via `SMJobBless` → installs `/Library/PrivilegedHelperTools/...` + LaunchDaemon plist
      - Linux: `pkexec`/`polkit` prompt + `.service` via `systemctl --user` + `CAP_NET_ADMIN` + `CAP_NET_RAW` (`setcap`) or `sudo sysctl` for `ip route`
    - IPC: Verge → ServiceManager → Unix socket / named pipe `IPC path` → service → spawns Mihomo as grandchild with elevated caps
    - `IPC path not ready` (common error if stale `verge-mihomo` process remains after crash) → fix: tray `Quit` → kill leftover `clash-verge`/`verge-mihomo`/`mihomo` with Task Manager / `killall` → `Settings → Service Mode → Uninstall → Install`
    - `pnpm dev:service` explicitly installs/updates the isolated development service before launch

- **Hot reload — HOW config changes without full restart**
  - Flow on any Profiles/Script/Merge save or proxy select:
    1. Frontend invokes `patch_clash_config` / `enhanceConfig` (Merge+Script chain)
    2. Rust drafts merged YAML to `config.yaml` via atomic `clash-verge-draft` temp file → rename
    3. If TUN `stack`/`device` changed → `CoreManager` fully restarts sidecar (new TUN device needs recreation)
    4. Otherwise → `PUT /configs` + `SIGHUP` signal to Mihomo; Mihomo diffs listeners/groups/rules and hot-reloads only changed parts (listeners recreated only if `mixed-port`/`tun` changed)
    - Validation `test -t` equivalent: Mihomo `-t` config test before apply → Verge shows `Config validation failed: ... line 42` if YAML invalid

---

## 5. Routing / Split Tunneling — HOW Clash Rule Engine & Providers Work

- **Engine priority — HOW matching works**
  - Rules matched **top-to-bottom, first match wins** — order is priority; top = highest, bottom = tail
  - UDP skip logic: if rule hits a proxy with `udp: false` (e.g., a plain `http` node) and connection is UDP → skip and keep descending
  - Final fallback must be `MATCH,<proxy-or-group>` (catch-all); Verge templates ship `MATCH,PROXY` or `MATCH,Auto` as last line — omit this and unmatched traffic may fall to Verge `DIRECT` default

- **Domain rules — HOW to match before DNS (no real lookup yet, uses SNI/FakeIP map)**
  - `DOMAIN,ad.com,REJECT` — exact full domain only (`ad.com` ≠ `ads.ad.com`)
  - `DOMAIN-SUFFIX,google.com,PROXY` — suffix match: `google.com` hits `www.google.com`, `mail.google.com`, `google.com` but **not** `content-google.com` (dot boundary)
  - `DOMAIN-KEYWORD,google,PROXY` — substring keyword anywhere in domain (`google` hits `googlemail.com`, `content-google.com`)
  - `DOMAIN-WILDCARD,*.google.com,PROXY` — wildcard `*`=0+ chars, `?`=1 char (note: different from classic Clash wildcards in `handbook/syntax/#domain-wildcards`)
  - `DOMAIN-REGEX,^abc.*\.com,PROXY` — full regex on domain string; needs escaping (`\.` for dot)
  - `GEOSITE,category,PROXY` — Geosite category DB (sourced from `v2fly/domain-list-community/data`); examples: `GEOSITE,youtube` (all YT domains), `GEOSITE,gfw` (blocked CN list), `GEOSITE,cn` (all CN domains), `GEOSITE,geolocation-!cn` (non-CN)
    - Requires: `geodata-mode: true` in top-level config + `geox-url: { geosite: https://.../geosite.dat }` or `rule-providers` with `behavior: domain`
    - Mihomo supports `geosite:` prefix inside `nameserver-policy` as well

- **IP rules — HOW to match after DNS (triggers real resolve unless `no-resolve`)**
  - `IP-CIDR,127.0.0.0/8,DIRECT,no-resolve` — IPv4 CIDR; alias `IP-CIDR6` for IPv6 (functionally identical, named for clarity)
  - `IP-SUFFIX,8.8.8.8/24,PROXY` — suffix match on IP string (less used)
  - `IP-ASN,13335,DIRECT` — ASN integer (requires `asn.mmdb` / MaxMind `country-lite.mmdb` in Verge's `resources/` + `geodata-mode`)
  - `GEOIP,CN,DIRECT` — country code match via MMDB (Verge ships `Country.mmdb`); classic first lines: `GEOIP,lan,DIRECT,no-resolve` (private range direct) + `GEOIP,CN,DIRECT` (China direct)
  - `SRC-GEOIP,cn,DIRECT` — source IP country (rare, multi-hom)
  - `SRC-IP-ASN`, `SRC-IP-CIDR`, `SRC-IP-SUFFIX` — source IP variants
  - Flags:
    - `no-resolve` — skip DNS when starting domain → IP matching (if prior rule already resolved domain, cached IP still checked)
    - `src` — flips rule from dst-IP to src-IP matching (only valid on IP rules)
  - Example Verge default head: `IP-CIDR,127.0.0.0/8,DIRECT,no-resolve` → `GEOIP,lan,DIRECT,no-resolve` → `GEOIP,CN,DIRECT,no-resolve` → domain rules → `MATCH`

- **Port & protocol rules**
  - `DST-PORT,80,DIRECT` — destination port (supports ranges `80-443` per `handbook/syntax/#port-ranges`)
  - `SRC-PORT,7777,DIRECT` — source port range
  - `IN-PORT,7890,PROXY` — inbound listener port (e.g., socks 7890 vs http 7891 separation)
  - `IN-TYPE,SOCKS/HTTP,PROXY` — inbound type (`HTTP`, `SOCKS`, `Mixed` etc. from `inbound/port` / `listeners`)
  - `IN-USER,mihomo,PROXY` / `IN-NAME,ss` / `REMATCH-NAME,rematch1` — user/name of inbound listener (requires `listeners:` entries with `name:` field)
  - `NETWORK,udp,DIRECT` — L4 protocol (`tcp`/`udp`)
  - `DSCP,4,DIRECT` — Differentiated Services Code Point (tproxy UDP inbound only)

- **Process-based split tunneling — HOW per-app routing works (Windows/macOS/Linux desktop)**
  - Exact: `PROCESS-PATH,/usr/bin/wget,PROXY` — full filesystem path; Windows example: `PROCESS-PATH,C:\Program Files\Google\Chrome\Application\chrome.exe,PROXY`
  - Wildcard: `PROCESS-PATH-WILDCARD,/usr/*/wget,PROXY` — `*`/`?` wildcards on path
  - Regex: `PROCESS-PATH-REGEX,.*bin/wget,PROXY` or Windows `(?i).*Application\\chrome.*` (case-insensitive flag `(?i)`)
  - Name: `PROCESS-NAME,curl,PROXY` — binary name; on **Android** also matches package name (`com.termux`)
  - Name wildcard: `PROCESS-NAME-WILDCARD,*telegram*,PROXY`
  - Name regex: `PROCESS-NAME-REGEX,curl$` or `(?i)Telegram` etc.
  - UID: `UID,1001,DIRECT` — Linux owner UID
  - HOW Verge enables:
    - Requires `tun.enable: true` + `sniffer` or `find-process-mode: strict` in top-level for accurate PID binding (Verge injects this when `PROCESS` rules present)
    - GUI: Profiles → visualize `PROCESS-NAME` lines; Verge doesn't auto-discover process list (unlike FlClash Access Control) — user edits YAML manually
    - Limitation: `PROCESS-*` only works when traffic goes through TUN or when Mihomo can query OS process table; pure System Proxy mode may miss UDP/short-lived processes
  - Linux UID example: `UID,0,DIRECT` keeps root traffic direct even when user TUN proxies everything

- **Logical combinators — HOW complex policies compose**
  - Syntax: `LOGIC_TYPE,((payload1),(payload2)),Proxy` — **parentheses mandatory**
  - `AND,((DOMAIN,baidu.com),(NETWORK,UDP)),DIRECT` — both conditions true → DIRECT (e.g., Baidu QUIC direct)
  - `OR,((NETWORK,UDP),(DOMAIN,baidu.com)),REJECT` — either true → REJECT
  - `NOT,((DOMAIN,baidu.com)),PROXY` — invert (non-Baidu → PROXY)
  - `SUB-RULE,(NETWORK,tcp),sub-rule-name` — delegate to `sub-rule:` block (nested rule set with its own `rules:`)
  - Failure mode: missing `)` or extra comma → Mihomo `parse rule error: ...` shown in Verge Logs + Profiles card red

- **RULE-SET + rule-providers — HOW large sets scale (the Mihomo advantage)**
  - Define:
    - `rule-providers:`
      - `  name:`
        - `    type: http` / `file` / `inline` — `http` fetches remote, `file` reads local `path:`, `inline` uses `payload:` list
        - `    behavior: domain` / `ipcidr` / `classical` — `domain`=lines of domain suffixes; `ipcidr`=lines of CIDRs; `classical`=mixed lines like `DOMAIN-SUFFIX,google.com`
        - `    format: yaml` / `text` / `mrs` — `mrs` = **Mihomo Binary MRS** (compiled via `mihomo convert-ruleset domain yaml in.yaml out.mrs`); `mrs` loads ~10× faster for >10k entries vs `text`
        - `    url: https://.../cn.mrs`, `path: ./ruleset/reject.mrs`, `interval: 86400` (update seconds), `proxy: DIRECT` (fetch via DIRECT or via proxy name), `size-limit`, `header: { Authorization, User-Agent }`
        - `    bundle: {}` rarely needed; `path-in-bundle: "geo/geosite/cn.mrs"` lazy-extracts from `BundleMRS.7z`
  - Reference:
    - `RULE-SET,providername,PROXY` placed in `rules:` — ordering still matters; typically `RULE-SET,reject-domain,REJECT` early, then `RULE-SET,proxy-domain,PROXY`, then `GEOIP`/`MATCH`
  - Behaviors detail:
    - `domain` provider file contains entries like `+.google.com`, `+.youtube.com` (Verge auto-converts to `DOMAIN-SUFFIX` semantics)
    - `ipcidr` provider contains `1.1.1.0/24`, `8.8.0.0/16` lines
    - `classical` provider can intermix `DOMAIN`, `GEOSITE`, `IP-CIDR` — but when `fake-ip-filter-mode: rule` classifies classical provider for FakeIP, only domain-level rules take effect
  - Verge GUI: Rule Providers section shows last-updated, type, behavior, format chips; manual `Update` per provider pulls with `header` auth
  - Why it matters for Verge: provider airports ship `rule-providers:` for `reject`/`proxy`/`cn`/`stream` so Verge can rule-set rather than ship 50k inline rules

- **Proxy groups — HOW groups aggregate nodes (selection plane)**
  - Common fields (per `wiki.metacubex.one/en/config/proxy-groups/`):
    - `name: "♻️ Auto Select"` (required, unique, quote if special chars `♻️`), `type: select/fallback/url-test/load-balance/relay` (required)
    - `proxies: [DIRECT, "HK-auto", "OtherGroup"]` — explicit member list (can include other groups → group-of-groups)
    - `use: [provider1, provider2]` — include all members from `proxy-providers` by name
    - `include-all: true` — auto-include **all** `proxies:` + `proxy-providers` members sorted by name; `include-all-proxies` / `include-all-providers` are partial variants
    - `filter: "(?i)港|hk|hongkong"` — regex include; `exclude-filter: "美|日"` — regex exclude; `exclude-type: "direct|reject"` — pipe-separated type excludes (| separated)
    - `url: https://www.gstatic.com/generate_204` (health-check URL), `interval: 300` (test secs), `timeout: 5000` (ms), `tolerance: 50` (url-test switch threshold ms), `lazy: true` (only test when group currently selected — saves CPU/battery), `max-failed-times: 5`, `expected-status: "204"` (supports `200/302/400-503` ranges), `disable-udp: false`, `hidden: true`, `icon: https://.../icon.png`
    - `interface-name`, `routing-mark` (legacy deprecated inside groups → set per-node instead)
    - Verge renders group `icon:` as badge next to group name; custom icons via Merge `prepend-proxy-groups: [{ name: ..., icon: https://... }]`
  - Types detail:
    - `select` — manual tap; persists via `profile: { store-selected: true }` across restarts
    - `fallback` — first-healthy in declared order (deterministic, not latency-optimal); good for `HK-primary, HK-backup, JP`
    - `url-test` (aka `auto`) — picks **lowest latency** periodically; `tolerance: 10` means only switch if new best beats current by >10ms (anti-flap)
    - `load-balance` — `strategy: consistent-hashing` (same dst → same proxy, keeps sessions sticky) or `round-robin`; still filters unhealthy via url/tolerance
    - `relay` — sequential chain `client → proxyA → proxyB → target` (DIY multi-hop; cost = latency sum)

- **Per-app proxy via PROCESS rule + TUN include/exclude — HOW Verge ties to OS**
  - On desktop (Windows/macOS/Linux): `PROCESS-NAME` / `PROCESS-PATH` rules require TUN to catch short-lived UDP; Verge auto-injects `tun.dns-hijack` so process's DNS also hijacked
  - On Android: `tun.include-package: [com.android.chrome]` / `exclude-package: [com.android.captiveportallogin]` (Android-only TUN keys) more reliable than `PROCESS-NAME` for package names
  - Example per-app split:
    - `PROCESS-NAME,chrome.exe,PROXY` → Chrome always proxied
    - `PROCESS-NAME,steam.exe,DIRECT` → Steam direct (low latency)
    - `RULE-SET,private,DIRECT` → keep LAN private direct regardless of process

---

## 6. TUN vs System Proxy — HOW Traffic Capture Differs

- **System Proxy — HOW L7 proxy injection works**
  - Mechanism:
    - Verge writes OS-level proxy keys and registers as system proxy (HTTP/SOCKS on `127.0.0.1:Mixed-Port`):
      - **Windows:** registry `HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings` → `ProxyEnable=1` DWORD, `ProxyServer=127.0.0.1:7890` REG_SZ, `ProxyOverride=<local>;*.lan;*local.manifest` (bypass list). Since v2.0.2 changelog `Win 下的系统代理替换为 Shadowsocks/CFW/v2rayN 等成熟的 sysproxy.exe 方案` → Verge now ships `sysproxy.exe` (mature helper) to handle dial-up / VPN coexist / UWP loopback edge cases correctly (Verge v2 calls `sysproxy.exe set --type global --host 127.0.0.1 --port 7890`)
      - **macOS:** `networksetup -setwebproxy Wi-Fi 127.0.0.1 7890` + `-setsecurewebproxy` + `-setsocksfirewallproxy` per active network interface (`en0`, `en1`); Verge iterates `networksetup -listallnetworkservices` to find enabled services; `ProxyAutoConfigURL` for PAC mode; requires `System Settings → Privacy & Security → Network Extension` approval on first install
      - **Linux:** DE-dependent: GNOME `gsettings set org.gnome.system.proxy http host 127.0.0.1 port 7890` + KDE `kwriteconfig5 --file kioslaverc --group 'Proxy Settings' ...` + `plasma-apply` / env `http_proxy=http://127.0.0.1:7890` exported for newly launched shells; not all apps honor `gsettings`
  - Guard mode (Verge Settings → `Enable Proxy Guard`):
    - HOW: Rust `AsyncHandler` polls OS proxy keys every ~2s; if another app (e.g., corporate VPN) overwrites `ProxyEnable`/`networksetup`, Verge immediately re-writes Verge's values → keeps Verge as authoritative proxy
    - Also watches for OS sleep/wake: re-applies after resume
  - Scope:
    - **Only proxy-aware apps** respect system proxy (browsers, `curl -x`, Electron, WinINET apps)
    - **Bypasses:** game clients (raw TCP), `git`/`npm` without env, Docker daemon, `ping`/`dig`, Discord voice UDP, Steam, WSL2 bridged traffic; also **UWP apps** (Windows Store) are loopback-restricted — need TUN or `CheckNetIsolation LoopbackExempt`
  - PAC (Proxy Auto Config):
    - If `mode: rule` → Verge serves PAC script at `http://127.0.0.1:9090/proxy.pac` (via Mihomo `external-controller`); PAC `FindProxyForURL` implements rule logic in JS for browsers that do PAC
    - Bypass list for PAC: `localhost`, `127.*`, `10.*`, `192.168.*`, `*.lan`
  - HOW Verge toggles:
    - Switch in `Settings → System Proxy` or tray `System Proxy` checkbox → calls `patch_verge_config({ enable_system_proxy: true })` → Rust writes registry/`networksetup`/`gsettings` → emits `showNotice` `System proxy enabled on 127.0.0.1:7890`
    - Disable → clears keys (`ProxyEnable=0` / `networksetup -setwebproxystate off`)
    - Error `administrator privileges required to modify system proxy` → `Quit` Verge → `Run as administrator` or `Install Service Mode`

- **TUN — HOW L3 transparent intercept works**
  - Mechanism:
    - Verge asks Mihomo (`tun.enable: true`) to create **virtual TUN interface** (`device: utun3` on macOS vs `Mihomo`/`utun` on Windows vs `mihomo0`/`Meta` on Linux)
    - L3 flow:
      1. App sends IP packet (any protocol) → OS routing table (modified by `auto-route: true`: installs `0.0.0.0/1 + 128.0.0.0/1` and `::/1 + 8000::/1` into TUN so TUN becomes default gateway)
      2. Packet arrives at TUN device → read by Mihomo userspace (gvisor/system stack)
      3. Mihomo extracts dst domain (FakeIP map or sniffer SNI) → runs `rules:` engine → picks proxy/DIRECT
      4. If `PROXY` → opens outbound via node (TLS/QUIC to remote proxy); if `DIRECT` → sends via physical NIC (`auto-detect-interface: true` auto-picks `en0`/`wlan0`/`eth0`)
  - Stack choices (`tun.stack` — the most debated knob):
    - `system` — kernel TCP/IP stack (Windows `WinTun`/`Wintun` driver, macOS `utun`, Linux `tun`); most stable/comprehensive, lowest resource, true kernel ctx; but may conflict with Defender firewall (Windows: Verge docs say add `verge-mihomo.exe` to `Windows Security → Allow an app through firewall`; macOS: signed app passes silently; Linux: `iptables -A OUTPUT -o Mihomo -j ACCEPT` if DROP default)
    - `gvisor` — userspace stack (Google gVisor netstack); no syscall to kernel per packet → higher isolation, no ctx switch, sometimes higher loopback `iperf` perf (doc image shows `gvisor` > `system` for loopback) but slightly higher CPU under mixed load
    - `mixed` — **recommended** (Verge default post `v2.0.2 Tun模式默认使用内核推荐的 mixed 堆栈`): TCP via `system`, UDP via `gvisor`; best overall UX; handles TCP retrans better than pure gvisor, handles UDP with gvisor isolation
    - Verge Settings → `TUN → Stack: system/gvisor/mixed` exposes this; toggling requires TUN bounce
  - Full `tun:` block (from wiki `tun.en.md` + Verge injection):
    - `enable: true`
    - `stack: mixed`
    - `device: utun0` (macOS must start with `utun`; Linux `mihomo0`/`Meta`; Windows auto-named)
    - `auto-route: true` — install global route; **mandatory** for capture
    - `auto-redirect: true` — Linux/Android extra: `iptables`/`nftables` redirect TCP (requires `auto-route` true; Android forwards only local IPv4 → hotspot share needs `VPNHotspot` app)
    - `auto-detect-interface: true` — auto-find outbound NIC; set `false` + `device: utun0` manual on multi-NIC hosts (e.g., Ethernet+Wi-Fi with metric tuning)
    - `dns-hijack: ["any:53", "tcp://any:53"]` — hijack raw DNS (udp + tcp on port 53) into core DNS (`If no protocol specified defaults to udp://`; macOS/Windows cannot auto-hijack LAN-local DNS → needs `strict-route` + loopback)
    - `strict-route: true` — heavy leak prevention:
      - Windows: adds Windows Filtering Platform rules to block DNS leaks via multi-homed resolver (fixes Windows `multi-homed DNS resolver` race that otherwise leaks queries via physical NIC before TUN)
      - Linux: makes non-TUN nets unreachable, forces all → TUN (Android leak killer)
      - May break VirtualBox/VMware bridged → if VM loses net, set `strict-route: false` and accept small leak
    - `mtu: 9000` — Max MTU; 9000 helps jumbo/GSO extreme but 1500 default safe; Verge default leaves `mtu` auto
    - `gso: true`, `gso-max-size: 65536` — Linux Generic Segmentation Offload; `route-address` families ignore GSO
    - `inet6-address: fdfe:dcba:9876::1/126` — TUN v6 addr; needs top-level `ipv6: true` + system v6 present else disabled unless `SKIP_SYSTEM_IPV6_CHECK=1` env set
    - `udp-timeout: 300` (5 min) — NAT entry expiry for UDP mappings
    - `iproute2-table-index: 2022` / `iproute2-rule-index: 9000` — Linux `ip rule` table/rule offsets (change to avoid clash with Docker/Mullvad tables)
    - `endpoint-independent-nat: false` — set `true` for symmetric-NAT-sensitive gaming → costs slight perf
    - `route-address-set: [ruleset-1]`, `route-exclude-address-set: [ruleset-2]` — Linux nftables rule-set-based inclusion/exclusion (needs `auto-route`+`auto-redirect`+`nftables`, `Conflicts with routing-mark`)
    - `route-address: ["0.0.0.0/1", "128.0.0.0/1", "::/1", "8000::/1"]` — custom route subnets instead of default `0.0.0.0/0` (avoid hijacking whole table)
    - `route-exclude-address: ["192.168.0.0/16", "fc00::/7"]` — exclude LAN / ULA from TUN (keeps printer/NAS reachable)
    - `include-interface: [eth0]` vs `exclude-interface: [eth1]` — NIC allow/block list (conflict pair — set one only)
    - `include-uid: [0]` / `include-uid-range: 1000:9999` / `exclude-uid` / `exclude-uid-range` — Linux per-user control (requires `auto-route`)
    - `include-mac-address` / `exclude-mac-address` — Linux LAN MAC filter (requires `auto-route`+`auto-redirect`+nftables)
    - `include-android-user: [0,10]` / `include-package: [com.android.chrome]` / `exclude-package: [com.android.captiveportallogin]` — Android-only (Verge Windows/macOS ignores, but Mihomo parses)
    - Legacy: `inet4-route-address`, `inet6-route-address`, `inet4-route-exclude-address`, `inet6-route-exclude-address` (deprecated, use `route-*` keys)
  - HOW Verge toggles TUN:
    - Switch `Settings → TUN Mode` or tray `TUN Mode` checkbox → Rust asks ServiceManager → if service installed → IPC `tun.enable = true` → service starts Mihomo with `tun` block; else if sidecar → spawn failure toast `Insufficient privileges → Install Service Mode or run as administrator`
    - Red/green tray icon indicates state; Verge shows `TUN enabled (mixed)` badge on sidebar
  - Verification:
    - `curl -I https://www.google.com` in **PowerShell/Terminal without proxy env** must return `200` (system proxy alone fails here → proves TUN catch)
    - `browserleaks.com/dns` → only proxy DNS should appear
    - Verge Connections page shows `TUN` listed as inbound type
    - `ipconfig /all` (Windows) should show `Mihomo` adapter with `198.18.0.1/16` FakeIP-like gateway (or real TUN subnet)

- **TUN service mode — HOW privilege elevation is managed**
  - Windows Service approach (`Settings → Service Mode → Install`):
    - Click → UAC prompt → Verge writes `clash-verge-service.exe` to `C:\Program Files\Clash Verge\` + registers `HKLM\SYSTEM\CurrentControlSet\Services\Clash Verge Service` (type `own process`, start `auto`)
    - Logs to `C:\ProgramData\clash-verge-service\` (service logs + clash logs)
    - Validation step added `v0.8.83 Add windows server mode start process verify` + `v2.0.2 由于更改了服务安装逻辑，Mac/Linux 首次安装需要输入系统密码卸载和安装服务，以后可以丝滑使用 tun` referenced change → Verge now auto-installs on first TUN enable (no manual `install.bat`)
    - Recovery after crash: service auto-restarts (Recovery First/Second failure: `Restart the Service`); stale `IPC path` handled by `ServiceManager::ensure_service_ready()`
  - macOS helper:
    - Rust calls `SMJobBless` → installs `io.github.clash-verge-rev.clash-verge-rev.helper` into `/Library/PrivilegedHelperTools/` + LaunchDaemon plist under `/Library/LaunchDaemons/`
    - First install requires **system password** (once per Verge upgrade that touches helper); then TUN toggles without password (see `v2.0.2` notes `以后可以丝滑使用 tun`)
  - Linux:
    - Verge requests `CAP_NET_ADMIN` + `CAP_NET_RAW` via `setcap cap_net_admin,cap_net_raw+eip /opt/clash-verge-rev/verge-mihomo`; if insufficient → `pkexec` polkit prompt to run `ip link add` + `ip route` + `iptables -t nat ...`
    - Some distros require `sysctl -w net.ipv4.ip_forward=1` (Verge docs `faq/linux.html` warns)
  - Why service vs sidecar: TUN creation is a privileged op (`CreateIpForwardEntry`, `tun device open`, `iptables`); sidecar under user lacks `SE_LOAD_DRIVER`; service keeps Verge UX non-admin while TUN still works

- **When to use which — HOW to choose per Verge docs + Mihomo wiki**
  - **System Proxy only** (light browsing, no games/CLI):
    - Enable `System Proxy` → keep `TUN off` → `mode: rule` → `dns.enhanced-mode: fake-ip` → browsers hit Verge; CLI/`git` fails → expected
  - **TUN only** (system-wide, CLI, gaming, Discord/Spotify):
    - Disable `System Proxy` → enable `TUN` (`stack: mixed`, `strict-route: true`, `dns-hijack: any:53`) → `dns.enable: true` + `enhanced-mode: fake-ip` → verify with `browserleaks.com/dns`
    - Keep `System Proxy` **off** during TUN diag (both on creates double-capture & packet loops on some Win builds)
  - **Both on** (Verge default after v2.0.2 when service mode + system proxy guard both enabled):
    - Works on most Win/macOS after `v2.0.2 Tun模式默认使用内核推荐的 mixed 堆栈` polish; TUN catches what system proxy misses (terminal) while browsers use system proxy fast path
    - If network stalls after enabling both → disable system proxy first, test TUN solo → re-enable if clean
  - Failures matrix (Verge docs `faq/windows.html`):
    - `TUN on but no internet` → service not installed / DNS off → `Install Service Mode` + `dns.enable: true` `fake-ip` recommended
    - `TUN toggle won't stay on` → insufficient privilege → install service or `Run as administrator`
    - `TUN on but still not proxying` → another VPN/TUN (WireGuard app, Mullvad) holds adapter → close other TUN client
    - `LAN Access Lost` → add `route-exclude-address: [192.168.0.0/16, 10.0.0.0/8]` + `fake-ip-filter: ['+.lan']`
    - `High CPU after TUN on` → switch `stack: system` → `mixed` or `gvisor` and check `mtu: 9000` vs `1500`

---

## 7. DNS — HOW Clash DNS Fake-IP / Redir-Host Works

- **Why Verge/Mihomo needs its own DNS**
  - Rule engine is **domain-centric** (`DOMAIN-SUFFIX`, `GEOSITE`, `RULE-SET`) → needs domain string **before** it has an IP
  - L3 packets carry only IP → Mihomo must **fake** an IP at DNS time, remember mapping, then use remembered domain to match rules at connect time
  - Without FakeIP, each `DOMAIN-SUFFIX` rule would require synchronous real DNS (slow, pollution-prone, ISP visible, extra upstream round-trips)
  - With FakeIP, upstream real DNS only fires if rule is `IP-CIDR`/`GEOIP`/`DIRECT` or `no-resolve` not set — keeps proxy flows zero-leak

- **FakeIP flow — HOW it fakes**
  1. App calls `getaddrinfo("google.com")` → DNS query hits Mihomo `dns.listen: 0.0.0.0:1053` or hijacked `any:53` (via `tun.dns-hijack`)
  2. Mihomo allocates **fake IP** from `fake-ip-range: 198.18.0.1/16` (IANA `Carrier-Grade NAT` reserved `198.18.0.0/15` not routed on public net; Mihomo uses `/16` slice `198.18.0.1/16` by default, ~65k addrs)
     - Example: `198.18.12.34` ↔ `google.com` stored in internal `fakeIP` map (LRU, bounded)
     - `fake-ip-range6: fdfe:dcba:9876::1/64` for AAAA if `ipv6: true` + `fake-ip-range6` set
  3. Returns `198.18.12.34` **instantly** (no upstream lookup yet)
  4. App `connect(198.18.12.34:443)` → packet traverses TUN (or socks → Mihomo) → Mihomo looks up map → knows real domain = `google.com` → applies `rules:`
     - If rule says `PROXY` / `select` → dial proxy **with domain** (proxy does real DNS server-side) — ISP never saw query
     - If rule says `DIRECT` or rule is `GEOIP`/`IP-CIDR` needing real IP → now does real upstream lookup via `nameserver`/`fallback`/`hosts` chain, then routes with that IP
  - Why `198.18.0.1/16` is default: RFC 6598 Carrier NAT; avoids collision with `10/8`, `172.16/12`, `192.168/16` LAN and with `127.0.0.0/8` loopback

- **`enhanced-mode` — HOW Verge toggles the two resolver personalities**
  - `enhanced-mode: fake-ip` (Verge DNS template default with TUN):
    - Returns synthetic `198.18.x.x` instantly; delays real resolve until routing decision needs IP
    - Implications:
      - Domain rules hit predictably even when OS stub resolver truncates EDNS0
      - Streaming templates (`GEOSITE,youtube` → `PROXY`) feel snappy
      - Timer: `browserleaks.com/dns` shows proxy DNS only; DevTools net panel shows `198.18...` addresses (shocks newcomers → Verge docs `fake-ip-range` note clarifies)
      - Must pair with `fake-ip-filter` for LAN/broken domains, else intranet fails (see Pitfall section)
  - `enhanced-mode: redir-host` (Verge alternative / troubleshooting mode):
    - Skips synthetic mapping; handler does **real upstream resolve** before answering (traditional stub-like)
    - Implications:
      - Real IPs returned immediately → logs + `Connections` pane show public IPs, not `198.18.x.x` → debugging easier; corporate VPN split-DNS happier with real IPs
      - Trade-off: every new domain pays real resolver latency on critical path; poisoned or slow upstreams surface directly; Verge recommends falling back to `fake-ip` once diagnosis done
  - `enhanced-mode: fake-ip` + `redir-host` coexistence: Mihomo only allows **one** at top-level; to use both per-domain, set `fake-ip-filter-mode: rule` + `fake-ip-filter: ["DOMAIN,domain.com,real-ip"]` trick (new in Mihomo post-1.18)

- **Full `dns:` block — HOW Mihomo configures it (from wiki `config/dns/en`)**
  - `enable: true` — master toggle; `false` disables all Clash DNS → leaks to OS (Verge docs warn `debates about enhanced-mode evaporate` if not enabled)
  - `listen: 0.0.0.0:1053` — Mihomo DNS listener (Verge binds + hijacks via `tun.dns-hijack`); Verge sets `listen: 0.0.0.0:1053` as default; WSL override may use `127.0.0.1:1053`
  - `ipv6: false` (default `false` in Mihomo templates; Verge exposes `DNS → IPv6` switch) — toggle AAAA; set `true` only if network + `tun.inet6-address` support v6, else AAAA leaks via phys NIC or hangs (Verge docs: disable if `network fully supports IPv6` false → avoids leaks)
  - `enhanced-mode: fake-ip` / `redir-host` (default `redir-host` in wiki but Verge Tun template defaults to `fake-ip`)
  - `fake-ip-range: 198.18.0.1/16` (note: docs `fake-ip-range6: fdfe:dcba:9876::1/64` for v6; TUN's `inet6-address` also uses this slice as reference)
  - `fake-ip-filter-mode: blacklist` (default) / `whitelist` / `rule`
    - `blacklist` → entries in `fake-ip-filter` return **real IP** (others fake); `whitelist` → only entries fake; `rule` → filter syntax equals routing rules (`GEOSITE`, `RULE-SET`, `DOMAIN`, `MATCH`) enabling `GEOSITE,gfw,fake-ip` style
    - Example `rule` mode (wiki): `- RULE-SET,reject-domain,fake-ip` → custom ruleset behavior must be `domain/classical`; `classical` with non-domain lines only domain parts take effect
  - `fake-ip-filter: ['*.lan', '+.local', '*.msftconnecttest.com', '*.msftncsi.com']` — Verge default ships `+.lan`, `+.local`, `+.market.xiaomi.com`, `Mijia Cloud`, `+.push.apple.com` (prevents IoT/mesh mesh breaks where real local resolution required)
    - Common additions for CN templates: `+.msftconnecttest.com`, `+.msftncsi.com` (Windows NCSI), `+.lan`, `time.*.com` (NTP)
  - `fake-ip-ttl: 1` — TTL of synthetic mapping entry (rare tuning)
  - `use-hosts: true` / `use-system-hosts: true` — pull `hosts:` dict + OS hosts (`C:\Windows\System32\drivers\etc\hosts`, `/etc/hosts`)
  - `respect-rules: false` (default) vs `true` (when `true`, obey `rules:` for nameserver choice path — helps `office.com DIRECT` pitfall: `respect-rules: true` + `fake-ip-filter` with Office domains fixes TLS EOF issue #1977 referenced in FlClash docs)
  - `default-nameserver: [223.5.5.5, 119.29.29.29]` — bootstrap plain-UDP resolver to resolve **DoH hostnames themselves** (must be IP, not `https://`; otherwise chicken-egg deadlock)
  - `nameserver: [https://doh.pub/dns-query, https://dns.alidns.com/dns-query, https://1.1.1.1/dns-query]` — primary upstream; Verge CN templates package domestic DoH (AliDNS `223.5.5.5` plain + Tencent `doh.pub` + Alibaba `dns.alidns.com`) separate from foreign
  - `fallback: [tls://8.8.4.4, tls://1.1.1.1, https://dns.google/dns-query]` — secondary for GFW-poisoned failovers; used when `fallback-filter` says so (see below)
  - `fallback-filter: { geoip: true, geoip-code: CN, geosite: [gfw], ipcidr: [240.0.0.0/4], domain: ['+.google.com'] }` — **when** to abandon `nameserver` and use `fallback`: default `geoip: true, geoip-code: CN` (China IPs stay domestic; foreign fallback), `geosite: [gfw]` (GFW domains → encrypted fallback), `ipcidr` excludes multicast/bogon, `domain` custom
  - `nameserver-policy: { '+.arpa': '10.0.0.1', 'rule-set:cn': ['https://doh.pub/dns-query'], 'geosite:private,cn,geolocation-cn': ['https://doh.pub/dns-query', 'tls://223.5.5.5'] }` — per-domain resolver override; supports `rule-set:` prefix to bind a provider's resolvers
  - `proxy-server-nameserver: [https://doh.pub/dns-query]` — **resolver for proxy node hostnames themselves** (to avoid chicken-egg: proxy domain resolves via direct path, not via proxy)
    - Chicken-egg danger: if `proxy-server-nameserver` blank → follows `nameserver-policy` → `nameserver` → `fallback`; but if those are `#PROXY` suffix tagged then infinite loop → Mihomo detects and warns `DNS loop`
  - `proxy-server-nameserver-policy: { 'www.yournode.com': '114.114.114.114' }` — per-node policy (Mihomo docs example)
  - `direct-nameserver: [system, 223.5.5.5]` — resolver for `DIRECT` domains (can be literal `system` to use OS stack)
  - `direct-nameserver-follow-policy: false` — whether `direct-*` obeys `nameserver-policy`
  - `cache-algorithm: arc` — Adaptive Replacement Cache (default `arc`; alternative `lru`)
  - `prefer-h3: false` — use HTTP/3 for DoH upstreams if supported
  - `hosts:` dict (`hosts: { "*.example.com": 127.0.0.1 }`) — static fake `hosts` file; Verge docs call this `Host override` tab
  - `external-doh-server: http://127.0.0.1:1053/dns-query` — expose Mihomo DNS as **DoH server** for LAN sharing (Mihomo experimental)
  - DoH/DoT/DoQ per entry: each `nameserver:` string can be `https://` (DoH), `tls://` (DoT), `quic://` (DoQ), `tcp://`, `udp://`; options: `https://dns.google/dns-query#PROXY` suffix means resolver dials **via proxy** (necessary when DoH IP blocked and needs proxy to reach — annotation `#PROXY` or `interface-name` syntax)
  - `Request proxy/interface for connection` (Mihomo advanced): `'https://10.0.0.1/dns-query#DIRECT'` → resolves via DIRECT path only; `'https://dns.google/dns-query#PROXY'` → via named proxy group `PROXY`; useful for split resolver with WARP
  - Classic Verge DNS template excerpt (derived from Script docs + Tun guides):
    - `dns: { enable: true, listen: 0.0.0.0:1053, ipv6: true, enhanced-mode: fake-ip, fake-ip-range: 198.18.0.1/16, fake-ip-filter: [+.lan, +.local, +.msftconnecttest.com], default-nameserver: [223.5.5.5, 114.114.114.114], nameserver: [https://doh.pub/dns-query, https://dns.alidns.com/dns-query], fallback: [https://dns.cloudflare.com/dns-query, tls://8.8.4.4], fallback-filter: { geoip: true, geoip-code: CN, geosite: [gfw], ipcidr: [240.0.0.0/4] }, proxy-server-nameserver: [https://doh.pub/dns-query], nameserver-policy: { geosite:private,cn,geolocation-cn: [https://doh.pub/dns-query] } }`

- **Internal mechanics — HOW resolution path is chosen (wiki `diagram`)**
  - Mihomo decision tree:
    1. `hosts:` hit → return instantly (static)
    2. `fake-ip-filter` check → if domain filtered (`real-ip` branch) → skip FakeIP → real path below
    3. If `enhanced-mode: fake-ip` and not filtered → return fakeIP + store map → later `rules:` may trigger real resolve
    4. Real resolve path: `nameserver-policy` (per-domain match) → else `nameserver` → parallel dial to all entries → collect answers → `fallback-filter` decides whether to discard `nameserver` answers and retry `fallback` (e.g., `nameserver` gave poisoned CN IP for `google.com` → triggers fallback to Cloudflare encrypted)
    - `proxy-server-nameserver` branch: for proxy hostnames (the `server:` field) Mihomo exits decision tree earlier and uses `proxy-server-nameserver` then `nameserver`/`fallback` chain with `PROXY` hint avoided
  - `DNS specifies proxy/interface` syntax: `'host#proxy'` pattern after resolver URL e.g., `tls://8.8.8.8#PROXY` via `#PROXY` dials through `PROXY` group; `'#DIRECT'` via direct physical NIC

- **Sniffer (domain sniffing) — HOW Verge recovers domain without FakeIP**
  - Verge template default (from `docs/config.yaml` + Script docs):
    - `sniffer: { enable: true, sniff: { HTTP: { ports: [80, 8080-8880], override-destination: true }, TLS: { ports: [443, 8443] }, QUIC: { ports: [443, 8443] } }, force-dns-mapping: true, parse-pure-ip: true, override-destination: true, skip-domain: ['Mijia Cloud', '+.push.apple.com'] }`
  - HOW it works: Mihomo parses **SNI** (TLS `ClientHello` field) / **HTTP Host** header / QUIC `chlo` to extract domain even when packet's dst is IP (helps for `redir-host` mode or UDP plain)
  - `override-destination: true` → if sniff succeeds, routing decision uses sniffed domain not packet IP (fixes some CDN `MATCH` misses)
  - `skip-domain` → `Mijia Cloud` / `push.apple.com` IoT exempt → prevents sniffer breaking on non-HTTP TLS

- **Host overrides — HOW Verge patches `hosts:` without forking YAML**
  - Verge Settings → `Hosts` → table editor → writes into `hosts:` merge (via Merge `hosts: { "example.com": 127.0.0.1 }`)
  - Use: pin intranet `nas.lan → 192.168.1.100` so TUN's FakeIP still routes to correct `192.168` via `route-exclude-address` while DNS returns pinned addr

- **Pitfalls & diagnostics — HOW to debug Verge DNS**
  - Symptom: DevTools shows `198.18.x.x` → **not a bug** under `fake-ip`; fix = keep `fake-ip` but add `fake-ip-filter` for tools that need real IP (e.g., some corporate `kerberos`/`spnego`)
  - Symptom: Outlook / Microsoft 365 `EOF` with `fake-ip` + `PROCESS` + `DIRECT` → add Office domains to `fake-ip-filter`: `+.office.com`, `+.outlook.office365.com`, `+.microsoftonline.com`, `+.live.com`, plus set `respect-rules: true` → per FlClash #1977 analysis
  - Symptom: `DNS loop` / `no nameserver available` after Verge enable → `default-nameserver` must be plain `119.29.29.29` etc., not `https://` (else boostrap deadlock)
  - Symptom: domestic CN sites crawl under `fake-ip` → `nameserver-policy` should wedge `geosite:cn` → domestic DoH (`doh.pub`/`alidns`) while foreign → `1.1.1.1/fallback` path; `fallback-filter.geoip: true` keeps `CN` IPs domestic
  - Symptom: `browserleaks` shows ISP DNS → `tun.dns-hijack` missing or `strict-route: false` → toggle `strict-route: true` + `dns-hijack: ["any:53","tcp://any:53"]`
  - Flushed cache procedure: Verge → `Restart Core` (hot) + OS `ipconfig /flushdns` (Windows) or `sudo dscacheutil -flushcache` (macOS) + close prefetch-heavy app tabs before retest
  - Leak check: `nslookup google.com 127.0.0.1` (should return `198.18.x.x` if `fake-ip`) vs `nslookup google.com 223.5.5.5` (ISP)

---

## 8. Other Features — HOW Web UI, Logs, Theme, Shortcuts, Backup Work

- **Web UI & dashboard — HOW Verge displays Mihomo state**
  - Built-in UI is **React/MUI** (not Yacd external) — `src/pages/` covers: `Proxies` (group cards, latency dots, search), `Profiles` (Remote/Local/Merge/Script list, Monaco editor), `Rules` (ordered list + type badges), `Connections` (live table), `Settings` (Verge/Clash/TUN/DNS/Theme), `Logs` (level filter)
  - External dashboard toggle: Settings → `External Controller` → `Web UI` can be pointed to `https://github.com/MetaCubeX/metacubexd` (`metacubexd`) or `yacd-meta` (`external-ui: ui` + `external-ui-url: https://.../metacubexd.zip`)
    - HOW: Verge downloads zip via Rust to cache path → unzips to `ui/` → serves via `http://127.0.0.1:9090/ui` (Mihomo serves static dir) → Verge button `Open Web UI` opens browser tab
    - CORS note: `external-controller-cors.allow-private-network: true` required for browser → local loopback fetching to work
  - `external-controller-tls` variant: not used by default Verge (needs cert files) — enterprise case

- **Connections, traffic graph, live monitoring**
  - Traffic graph: in `src/pages/_layout.tsx` sidebar header — polls `GET /traffic` (streaming endpoint returning `{ up, down }` bytes/sec) via `tauri-plugin-mihomo-api` throttled at ~666ms (`DelayManager` `requestAnimationFrame` batch) → sparkline updates
  - Connections table (`src/pages/connections.tsx`):
    - Columns: `SRC → DST`, `Domain`, `Process`, `Rule`, `Proxy chain`, `Upload/Download`, `Duration`
    - Actions: per-row `Close` (DELETE `/connections/:id`) + `Close All` (`DELETE /connections`) + auto-close hook on profile switch / stopping proxy
    - Polling: `GET /connections` every ~1s (cached, virtualized list for 10k+ rows — borrowed `FlClash` `v0.8.87 Optimize` pattern)
    - Search: keyword filter on process/domain/IP; `src/services/cmds.ts` `calcuProxies` + `delay.ts` inject latency history

- **Logs & kernel logs — HOW diagnostics work**
  - Verge Logs page: streaming `GET /logs?level=info` (SSE); filter `info|warning|error|debug|silent`
    - Colors: `info` gray, `warning` amber, `error` red, `debug` cyan (log entry color mapping)
    - Beware: `debug` level is **very verbose** (packet-level TUN debug) → Verge warns enabling debug may degrade perf
  - Core version line: `Logs` header shows `Mihomo 1.18.10 (?) Meta-xxxx` from `GET /version` (visible in Settings → `Clash Core Version`)
  - Additional logs:
    - `src-tauri` Rust logs via `tracing-subscriber` (`RUST_LOG=info`) → shown in `Settings → App Settings → Developer → App Logs` (Tauri log tail)
    - Service mode logs: `C:\ProgramData\clash-verge-service\service.log` (Windows) / `/tmp/clash-verge-helper.log` (macOS)
  - Export: Settings → `Export Logs` zips `config.yaml` (redacted secret) + `verge.yaml` + `service.log` + Mihomo buffer → for issue filing

- **Global settings — HOW Verge controls behavior**
  - Verge config `verge.yaml` keys (managed via Rust `Config::IVerge`):
    - `theme: light/dark/system` + `theme_mode` + `language: zh/en/es/ru/ja/ko/fa` (7 langs in README)
    - `auto_launch: true/false` — register OS startup (`Settings → Auto Launch`; Windows via `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`, macOS `LaunchAgents` plist, Linux `~/.config/autostart/clash-verge-rev.desktop`)
    - `system_proxy: true/false` + `proxy_guard: true/false` (guard mode poller)
    - `tun_mode: true/false` + `tun_stack: mixed` + `tun_device`
    - `enable_tun_service` (service installed flag)
    - `clash_core: verge-mihomo / verge-mihomo-alpha`
    - `mixed_port: 7890`, `socks_port`, `redir_port`, `tproxy_port`, `allow_lan: false`, `log_level`, `ipv6`, `unified_delay`, `tcp_concurrent`
    - `external_controller`, `secret` (reserved)
    - `webdav_url/username/password` (backup sync), `hotkey_*` mappings

- **Theme, tray icons, CSS Injection**
  - Theme toggle: `Settings → Appearance` → `Theme Color` picker + `Light/Dark` + `System` follow; MUI palette regenerated; preview screenshots `docs/preview_dark.png` / `preview_light.png`
  - Proxy group / tray icons:
    - Settings → `Tray Icon` → pick built-in `icon.png` or custom SVG/PNG path (supports toggling `colored vs monochrome` on macOS `v2.0.2` `MacOS 下自定义图标可以支持彩色、单色切换`)
    - Group icons: provider ships `icon:` URL per group; Verge also allows local `icon:` override via Merge `prepend-proxy-groups: [{ name: DIRECT, icon: file://... }]`
    - Tray menu: on Windows left-click menu flicker fixed in `v2.0.2` `修复 Win 下点左键菜单闪现` — default now right-click only; macOS left/right both open menu
  - **CSS Injection** (Verge power feature):
    - Settings → `CSS Injection` → textarea for arbitrary global CSS (e.g., `--primary-color: #ff4081; .proxy-card { border-radius: 12px; }`)
    - HOW: injected via `<style id="css-injection">` into WebView head; live preview; cleared on `Reset Builtin CSS`
    - Use: community themes hosted on `gist` — paste without rebuild

- **Shortcut keys / hotkeys**
  - Configured in `Settings → Hotkeys` (verge `hotkey_map`):
    - Default: `Ctrl+Q` / `Cmd+Q` → `Quit App` (`v2.0.2` `可使用 Ctrl(cmd)+Q 快捷键退出程序`)
    - Others: `Ctrl+Shift+P` → Toggle System Proxy, `Ctrl+Shift+T` → Toggle TUN, `Ctrl+,` → Settings
    - Verge registers via `tauri-plugin-global-shortcut` (Rust `global-shortcut` crate); on Wayland/KDE may collide with compositor shortcuts → Verge warns if register fails (see `faq/linux.html` `Linux KDE 桌面环境无法启动`)
  - Tray double-click: configurable `Tray → Double Click Action: Show Main Window / Toggle System Proxy / Toggle TUN`

- **Auto launch & silent start**
  - Toggle: `Settings → General → Auto Launch` → writes autostart entry with `--silent` flag
  - `Silent start` checkbox: launch minimized to tray (no window) → `tauri-plugin-autostart` passes `--hidden` on startup; Verge shows `app restarted after silent start duplicate instance bug` fixed in `v2.0.2` `静默启动下重复运行会出现多个实例的bug`
  - Historical residue cleanup: `v2.0.2` `安装的时候自动删除历史残留启动项` — installer deletes legacy `clash-verge` autostart keys to avoid duplicate boot

- **Backup, WebDAV sync, profile persistence (HOW data survives reinstall)**
  - WebDAV sync (`Settings → Backup → WebDAV`):
    - Fields: `URL` (e.g., `https://dav.jianguoyun.com/dav/FlClashVerge`), `Username`, `Password` (app token), `Remote directory` default `/clash-verge-rev/`
    - Behavior: on `Save` / profile change / app quit → Rust uploads zip of `profiles/`, `verge.yaml`, `config.yaml` (sanitized) via `reqwest-dav` (WebDAV `PUT` + `MKCOL`)
    - On new device → `Settings → Restore from WebDAV` downloads + unzips → requires restart; `Timeout` configurable (Verge `v2.0.2` `改进了 WebDAV 备份超时时间机制`)
    - Caveat per `v2.0.2 Known issues` → `Webdav 备份因为安全性和兼容性问题，暂不支持跨平台配置同步` → cross-platform restore may mismatch paths (`C:\` vs `/`); stay within same OS for now
  - Local config directory: button `Settings → Open Config Directory` opens file manager at profile dir
    - Also supports `Open Logs Directory` for `logs/app.log`
  - Import/export per-profile: `Profiles → Right-click → Export` saves `profilename.yaml` snapshot with timestamp (Verge archive)

- **Visual node & rule editing (syntax hints)**
  - Profiles editor: Monaco editor with Mihomo JSON schema (`schema.clash.json`) providing autocomplete for `type:` values (`ss/vmess/vless/trojan/hysteria2/tuic/wireguard/...`), diagnostics for `reality-opts` missing `public-key`
  - Visual toggles: `Settings → Clash Settings` form maps to `clash.yaml` top-level (IPv6, unified-delay, TCP-concurrent, Keep-Alive interval, Log Level, Geodata mode)

- **Deep links & URL schemes (guide/url_schemes.html)**
  - Registered scheme: `clash://install-config?url=<encoded-url>` opens Verge and imports subscription instantly (used by airport `One-click import` buttons)
  - macOS: also `clash-verge://` handler (prevents clash with legacy CFW)
  - Implementation: Rust `tauri-plugin-deep-link` registers `CFBundleURLSchemes` (macOS plist) + Windows registry `HKEY_CLASSES_ROOT\clash\shell\open\command` + Linux `~/.local/share/applications/clash-verge.desktop` `MimeType=x-scheme-handler/clash;`

---

## 9. Platforms — HOW Verge Behaves Per OS

- **Windows — HOW install & service works**
  - Packages (from `v2.0.2` / `v2.4.4-rc.1` releases pages):
    - `Clash.Verge_{version}_x64-setup.exe` (NSIS installer, bundled WebView2-bootstrapper, ~30.6 MB; `x64` most downloaded ~461k in `v2.0.2` `latest.json` stats) — **recommended** (`一般下载这个`)
    - `Clash.Verge_{version}_arm64-setup.exe` (Surface Pro X style ARM64, ~27.7 MB)
    - `Clash.Verge_{version}_x86-setup.exe` (legacy 32-bit x86, still shipped for low-end Atom tablets)
    - `Clash.Verge_{version}_x64_fixed_webview2-setup.exe` (`fixed_webview2` — bundles full ~170 MB `WebView2 Runtime` for offline/VM installs without internet)
    - Portable `Clash.Verge_{version}_x64-setup.nsis.zip` + `*.sig` sig files for verification
    - System requirement: **Windows 10+** (Verge `Windows (不支持win7)` — does not support Win7)
  - Installer steps:
    1. Run `.exe` → choose `Install for me only` vs `All users` (All users writes to `C:\Program Files\...` and registers service for TUN )
    2. Allow bundled `vc_runtime` auto-download if missing (`v2.0.2 新增 Windows 下自动检测并下载 vc runtime`)
    3. First launch → Verge shows system proxy guard prompt; if enabling TUN → UAC `Clash Verge wants to install its service` → allow → service registered
    4. After install, Verge auto-deletes historical `clash-verge` autostart residues (`安装的时候自动删除历史残留启动项`)
  - Service:
    - Service name `Clash Verge Service` (`clash-verge-service.exe`) under `services.msc`; startup `Automatic`; logon as `Local System`; depends on `Winmgmt`/`NlaSvc`
    - Controls via Verge `Settings → Service Mode → Install/Uninstall`; `Restart Service` button visible on service error toast `IPC path not ready`
    - Uninstaller: `Settings → Uninstall Service` removes service + deletes `C:\ProgramData\clash-verge-service\`
  - Win-specific features:
    - `sysproxy.exe` path for system proxy (dial-up/VPN coexistence bug fixed in `v2.0.2` `解决拨号/VPN 环境下无法设置系统代理的问题`)
    - `Auto Route` + `strict-route: true` adds WFP rules — if `VirtualBox` loses net → disable `strict-route`
    - `Window size cannot be remembered` bug: still `Known issues` in `v2.0.2` `Windows 下窗口大小无法记忆（等待上游修复）` — upstream Tauri fix pending
    - Tray: left-click flash fixed in `v2.0.2`; now right-click menu; `Ctrl+Q` quit from anywhere
  - PowerShell diagnostics:
    - `Get-Service clash-verge-service | Format-List Name,Status,StartType`
    - `ipconfig /all | Select-String -Pattern "Mihomo|utun"`
    - `netsh winhttp show proxy` — check system proxy effective
    - `Test-NetConnection -ComputerName 127.0.0.1 -Port 7890` — confirm mixed-port listening

- **macOS — HOW dmg + service works**
  - Packages:
    - `Clash.Verge_{version}_x64.dmg` (Intel Macs, 40.8 MB) and `Clash.Verge_{version}_aarch64.dmg` (Apple Silicon, 38.5 MB) — both target `macOS 11+` (README `Supports ... macOS 11+ (intel/apple)`, later docs `10.15+`)
    - Also `Clash.Verge_{version}_aarch64.app.tar.gz` / `x64.app.tar.gz` (direct app archive, ~38-40 MB, for `brew` or manual `/Applications`)
    - DMG contains `Clash Verge.app` + `Applications` symlink drag target
  - Gatekeeper:
    - On first open of unsigned dev builds → `Right-click → Open` to bypass `damaged` quarantine; release builds are notarized (signed `Developer ID Application: ...`)
    - After macOS Sonoma+, Verge warns if XProtect blocks sidecar → `xattr -cr /Applications/Clash\ Verge.app` fix in `faq/macos.html`
  - Service (helper):
    - Rust `SMJobBless` helper `io.github.clash-verge-rev.clash-verge-rev.helper` installed to `/Library/PrivilegedHelperTools/` + LaunchDaemon plist under `/Library/LaunchDaemons/io.github....helper.plist`
    - First TUN enable → macOS prompts `Clash Verge wants to install a helper tool` → enter **system password** (once per Verge update that bumps helper version; `v2.0.2` `首次安装需要输入系统密码卸载和安装服务，以后可以丝滑使用 tun` )
    - Helper provides: `utun` creation, `pf` firewall rules for `strict-route`, DNS `networksetup` protection
    - Icon color switch: `v2.0.2` `MacOS 下自定义图标可以支持彩色、单色切换` — tray template image toggles colored/monochrome for light/dark menubar
    - Issue `v2.0.2` `MacOS 系统下少有的无法安装服务，无法启动的问题，目前更健壮了` fix: Verge now cleans stale LaunchDaemon before reinstall
  - Way to import subscription: Verge docs `Mac 下可用 URL Scheme 导入订阅` → `clash://` links from browser open Verge directly
  - Diagnostics:
    - `ifconfig | grep -A2 utun` — show TUN interface `utun3`
    - `netstat -an | grep 7890` — Verify mixed-port listening
    - `scutil --proxy` — display macOS system proxyEffective
    - `log stream --predicate 'process == \"clash-verge-service\"' --level debug` — service logs

- **Linux — HOW deb/rpm + capabilities work**
  - Packages:
    - `Clash.Verge_{version}_amd64.deb` (x64 Debian/Ubuntu, 42.5 MB) → `sudo apt install ./Clash.Verge_*_amd64.deb` (not `dpkg -i` bare — `apt` resolves `webkit2gtk` deps)
    - `Clash.Verge_{version}_arm64.deb` (ARM64, e.g., Raspberry Pi 4, 40.4 MB)
    - `Clash.Verge_{version}_armhf.deb` (ARMv7, 40.7 MB)
    - `Clash.Verge-*-1.x86_64.rpm` (Fedora/RH/OpenSUSE, 42.5 MB) → `sudo dnf install ./Clash.Verge-*.x86_64.rpm`
    - `Clash.Verge_*-1.aarch64.rpm` / `armhfp.rpm` for ARM servers
    - Older releases ship `AppImage` / `tar.gz` fallback via `AppImageLauncher`
  - Dependencies (prerequisite `pnpm build` docs + `faq/linux.html`):
    - `libwebkit2gtk-4.0-37` / `libwebkit2gtk-4.1-0` (Tauri WebKit), `libayatana-appindicator3-1`, `libkeybinder-3.0-0`, `libgtk-3-0`, `libssl3`, `libsoup2.4-1` vs `libsoup3`
    - Wayland: Verge since `v2.0.2` `修复 Linux wayland 下任务栏图标缺失` → requires `xdg-desktop-portal` + `WAYLAND_DISPLAY` set; tray icon uses `ayatana-appindicator` via `dbus`
    - KDE: `v2.0.2` `修复 Linux KDE 桌面环境无法启动` → `QT_QPA_PLATFORM=xcb` fallback if Wayland tray fails
  - Privilege for TUN:
    - Linear flow: `Verge → pkexec` polkit prompt → `ip link add dev mihomo type tun` + `ip route add 0.0.0.0/1 dev mihomo` + `iptables -t nat -A OUTPUT -p tcp -j REDIRECT --to-ports 7892` (redir capture)
    - Alternative (no `pkexec` each launch): `sudo setcap cap_net_admin,cap_net_raw+eip /opt/clash-verge-rev/verge-mihomo` → grant file capabilities → TUN without password (Verge docs `Enable TUN without password` section)
    - `strict-route` + `route-exclude-address: [192.168.0.0/16]` keeps `KDE bug` fixes intact
  - Zombie process fix: `v2.0.2` `修正了 Linux 下多个内核僵尸进程的问题` — Rust `AsyncHandler` now `waitpid` correctly on Mihomo child after core restart
  - Diagnostics:
    - `ip route show table all | grep mihomo`
    - `ip addr show mihomo` / `ifconfig mihomo`
    - `sudo iptables -t nat -L -n | grep REDIRECT`
    - `systemctl --user status clash-verge-rev` (if user service) or `journalctl -u clash-verge-service`

---

## 10. Repo Stats, Releases, Build — HOW to Build & Track

- **Repo identity**
  - `clash-verge-rev/clash-verge-rev` — `A modern GUI client based on Tauri, designed to run in Windows, macOS and Linux for tailored proxy experience` (`www.clashverge.dev`)
  - Created: `2023-11-21T18:24:03Z` (first commit Nov 21 2023)
  - Default branch: `dev` (not `main`) → `4,692 Commits` on `dev` as of 2026-08-30 webfetch
  - License: `GPL-3.0`

- **Star & fork history (verified 2026-08-30 live)**
  - Stars `141.0k`, Forks `10.1k`, Watchers `379`, Issues `392` open, PRs `26` open
  - Growth checkpoints:
    - 2023-11-21 launch → ~135k stars by 2024 (`docs/README_en.md` snapshot)
    - 2025-12-17 `v2.4.4-rc.1` page showed `123K stars` (bot snapshot staler) vs current `141k` → +18k in ~8 months
    - DeepWiki `123K stars` label on `v2.4.4-rc.1` tag page → undercounts; GitHub sidebar is canonical
  - Popularity rank: top ~200 starred overall on GitHub; `#1` Tauri proxy GUI by stars

- **Release channels — HOW to choose**
  - Channel table (from README `How to choose发行版` + `docs/README_en.md` English):
    - `Stable` — `https://github.com/clash-verge-rev/clash-verge-rev/releases` (formal, high reliability, daily use) → latest tag pattern `v2.x.y`
    - `Alpha (EOL)` — `https://github.com/clash-verge-rev/clash-verge-rev/releases/tag/alpha` (`Alpha(废弃) 测试发布流程` → legacy pipeline validation, now deprecated)
    - `AutoBuild` — `https://github.com/clash-verge-rev/clash-verge-rev/releases/tag/autobuild` (`滚动更新版，适合测试反馈，可能存在缺陷` — rolling canary, best for bug reporters)
  - How Verge reports channel inside app:
    - `Settings → About` shows `Version: 2.x.y (Stable | AutoBuild)` + `Core Version: mihomo 1.19.x`
    - AutoBuild nightly publishes `latest.json` (size ~7 KB in `v2.4.4-rc.1` asset list) for in-app updater (Verge checks `latest.json` `version` vs installed; shows `Update Available` toast)
  - Latest examples (webfetch):
    - `v2.0.2` (2024-12-01) — Tauri 2.0 milestone, detailed `Changelog.md` with Breaking/Features/Performance/Bugs sections; assets include `.sig` GPG signatures per file
    - `v2.4.4-rc.1` (2025-12-16, prerelease, 38 reactions `👍38`) — carries `Clash.Verge_2.4.4-rc.1_*` assets; commit `_autobuild` branch

- **Changelog & breaking changes (highlights from `v2.0.2` vs `v2.0.0` vs `v1.x`)**
  - Breaking (`v2.0.2` notes):
    - `重大框架升级：使用 Tauri 2.0（巨量改进与性能提升）` — Tauri 1→2 requires WebView2 >= 120 on Windows
    - `出现 bug 到 issues 中提出；以后不再接受1.x版本的bug反馈。` — 1.x EOL
    - `强烈建议完全删除 1.x 老版本再安装此版本 !!使用出现异常的，打开设置-->配置目录 备份 后 删除所有文件 尝试是否正常` — clean install advised (old `clash-verge` data under `~/.config/clash-verge` vs new `clash-verge-rev`)
  - Feature deltas (`v2.0.2` vs `v2.0.1`):
    - macOS colored/monochrome tray switch, Linux zombie fix, IPv6 override logic fix, macOS TUN fake-ip fix, tray nature fix on macOS, duplicate instance on silent start fix, legacy autostart cleanup, mixed stack default, WebDAV timeout tweak, Test menu scroll, TUN override coverage fix, drag-drop profile fix, light mode contrast
  - Performance (`v2.0.2`) rewrites: `优化及重构内核启动管理逻辑`, `优化 TUN 启动逻辑`, `重构和优化 app_handle`, `重构系统代理绕过逻辑`, `移除无用的 PID 创建逻辑`, `优化系统 DNS 设置逻辑`, `后端实现窗口控制`, `重构 MacOS 下的 DNS 设置逻辑`

- **Build — HOW to build from source (from `CONTRIBUTING.md` + `docs/README_en.md` + `clash-verge-rev.github.io`)**
  - Prerequisites (Tauri prerequisites + per-OS deps):
    - **Rust:** `1.91+` (pinned in `rust-toolchain.toml`; `cargo` with `tauri-cli` crate); `rustfmt`, `clippy` aligned via `.clippy.toml` + `rustfmt.toml`
    - **Node:** `18+` (recommend `20 LTS`); **pnpm** `10+` (pinned via `pnpm-lock.yaml`, `pnpm-workspace.yaml`)
    - **Tauri system deps:**
      - Windows: `Visual Studio 2022 Build Tools` (MSVC), `WebView2 SDK` (evergreen), `NSIS` for installer
      - macOS: `Xcode 14+` (with `xcrun`), `python3`, `create-dmg` for dmg
      - Linux: `libwebkit2gtk-4.0-dev` (`4.1` on newer), `libgtk-3-dev`, `libayatana-appindicator3-dev`, `librsvg2-dev`, `libssl-dev`, `patchelf`, `libsoup-3.0-dev`
  - Clone & install:
    - `git clone https://github.com/clash-verge-rev/clash-verge-rev.git`
    - `cd clash-verge-rev`
    - `git submodule update --init --recursive` (optional — `mihomo` submodule + plugin submodules)
    - `pnpm i` (installs `tauri-plugin-mihomo-api` from `github:clash-verge-rev/tauri-plugin-mihomo#revert` — pinned commit, requires internet)
  - Prebuild (critical, Rust ↔ JS sync):
    - `pnpm run prebuild` — **mandatory before first dev**; downloads platform-specific `verge-mihomo` + `verge-mihomo-alpha` into `src-tauri/sidecar/` (binary size ~15-30 MB)
    - Skipping `prebuild` → `sidecar not found` panic on `pnpm dev`
    - `pnpm run prebuild` also generates `src-tauri/icons/` from `src-tauri/icons/icon.png` + `Cargo.toml` `sidecar` manifest
  - Dev run:
    - `pnpm dev` — `pnpm i + pnpm run prebuild + tauri dev` (port `1420` vite dev server + Rust watcher)
      - Preserves dev channel service state: if a service is already installed → uses it; if previously uninstalled → stays uninstalled and runs **Sidecar mode** (explicit control: `pnpm dev:service` to install/update dev service, `pnpm dev:sidecar` to force sidecar)
    - Logs stream to terminal: Rust `tracing` + Vite HMR + Mihomo `log-level: debug` lines
  - Build installers:
    - `pnpm build` — `cargo build --release` + `tauri build` → platform installers under `src-tauri/target/release/bundle/` (`nsis/`, `deb/`, `rpm/`, `dmg/`)
    - `pnpm build:fast` — `fast-release` Cargo profile (`opt-level = 1`, `debug = true`) for faster iteration (~40% compile time vs `release`)
    - `Makefile.toml` cargo-make tasks: `cargo make build`, `cargo make clippy`, `cargo make fmt` are aliases used in CI (`deny.toml` checks `bans/licenses/sources`)
  - CI / Actions:
    - `/.github/workflows/` includes `build.yml` (matrix `windows-latest`, `macos-latest`, `ubuntu-latest` × arch), `lint.yml` (`biome` + `eslint.config.ts` + `clippy` + `deny`), `release.yml` (on `push tag v*` builds 28 assets + `latest.json` + `.sig`), `renovate.json` drives dep bumps
    - Alpha channel used to **validate publish pipeline** (README `Alpha(废弃) 测试发布流程`); AutoBuild nightly on `push to dev` via `autobuild` tag
  - Tauri quirk notes (from `langlabs.io/clash-verge-rev` page):
    - `tauri-plugin-mihomo-api` is GitHub dep not npm → `pnpm i` needs internet and pinned commit can lag npm registry — don't assume `latest npm`
    - `pnpm run prebuild` is mandatory before first `pnpm dev` → downloads `mihomo` sidecar else missing binary panic
  - Verification after build:
    - Check `src-tauri/target/release/bundle/nsis/Clash.Verge_*_x64-setup.exe` exists; `Start-Process` on Windows should show Verge window + tray + `Clash Core Version` in Settings
    - `cargo deny check`, `biome check .`, `pnpm lint` must be green before PR (CONTRIBUTING.md gates)

- **Known issues & doc links (from `v2.0.2` Known issues + `faq/*.html`)**
  - `Windows 下窗口大小无法记忆（等待上游修复）` — Tauri issue; auto-restore size on next upstream
  - `Webdav 备份因为安全性和兼容性问题，暂不支持跨平台配置同步` — cross-platform restore warned
  - `faq/windows.html`, `faq/macos.html`, `faq/linux.html`, `faq/other.html` + `guide/quickstart.html` + `guide/profile.html` + `guide/log.html` + `guide/css_injection.html` + `guide/url_schemes.html` + `guide/term.html` + `guide/rules.html` + `guide/proxy_chain.html` + `guide/script.html` + `guide/config.html` (multi-sub merge) + `guide/group_icon/` on docs site `clash-verge-rev.github.io`

---

## 11. References & Verification

- **Primary sources fetched live 2026-08-30**
  - GitHub repo `https://github.com/clash-verge-rev/clash-verge-rev` — stars 141k, forks 10.1k, GPL-3.0 badge, dev branch 4,692 commits, README `Continuation of Clash Verge — A Clash Meta GUI based on Tauri` + Feature list verbatim
  - README refs: `zzzgydi/clash-verge`, `tauri-apps/tauri`, `Dreamacro/clash`, `MetaCubeX/mihomo`, `Fndroid/clash_for_windows_pkg`, `vitejs/vite` (Acknowledgement)
  - DeepWiki `1.2-architecture-overview` + `3-frontend-backend-communication` — three-layer design, `tauri-plugin-mihomo-api` pool min3 max32, Draft pattern, service IPC
  - Docs site `https://clash-verge-rev.github.io/` (plus `https://clash-verge-rev.github.io/install.html`, `faq/windows.html`, `faq/macos.html`, `faq/linux.html`, `guide/profile.html`, `guide/log.html`, `guide/url_schemes.html`, `guide/term.html`, `guide/rules.html`, `guide/script.html`, `guide/config.html`)
  - Mihomo wiki `https://wiki.metacubex.one/en/config/` + `.../config/proxies/` (`Common fields` `smux` table) + `.../config/rules/` (full `DOMAIN/GEOSITE/IP-CIDR/PROCESS-NAME/AND/OR/NOT/MATCH` list) + `.../config/dns/` (full `enhanced-mode/fake-ip-range/fallback-filter/proxy-server-nameserver` block, 50-line example, `+PROXY` annotation) + `.../config/inbound/tun/` (66-line `tun:` default with all `stack/device/auto-route/strict-route/mtu/inet6-address/route-address` knobs) + `.../config/proxies/vless/` (`reality-opts` + `vision` + `xudp`)
  - Verge guide mirrors: `clashvergerev.com/en/guide/merge` (`prepend-rules/append-rules` + Merge override warning) + `clashvergerev.site/en/guide/script.html` (`boa_engine/main(config)` JS DNS/profile example) + `getclashvergerev.org/en/guide` (profile chain flow)
  - Releases `https://github.com/clash-verge-rev/clash-verge-rev/releases` + `v2.0.2` changelog page (Tauri 2 migration, Breaking/Features/Perf/Bugs/Known issues) + `v2.4.4-rc.1` asset table (`.deb/.rpm/.dmg/.exe` lists, 38 reactions, 123K snapshot)

- **Verification steps performed**
  - `webfetch https://github.com/clash-verge-rev/clash-verge-rev` → stars 141k confirmed (sidebar), `dev` branch 4,692 commits confirmed
  - `webfetch https://wiki.metacubex.one/en/config/dns/` → confirms `198.18.0.1/16`, `fallback-filter`, `fake-ip-filter-mode: blacklist/whitelist/rule`, `proxy-server-nameserver` chicken-egg note
  - `webfetch https://wiki.metacubex.one/en/config/inbound/tun/` → confirms `stack: system/gvisor/mixed` + `mixed recommended`, `strict-route` semantics, `gso` Linux-only, firewall notes
  - `webfetch https://wiki.metacubex.one/en/config/rules/` → confirms `PROCESS-PATH/PROCESS-NAME/AND/OR/NOT/RULE-SET/MATCH` syntax + `no-resolve` flag
  - `webfetch clash-verge-rev.github.io` → confirms `Tauri/Mihomo GUI`, `Merge/Script` feature, `WebDAV` sync, `System proxy/TUN` listing + `profile chain` docs
  - File `C:\Users\qmahyar\Desktop\VPN Research\12-Clash-Verge-Rev.md` line count verified via `Measure-Object -Line` (target ≥400 lines)

- **Cross-checks vs sibling FlClash research (11-FlClash.md)**
  - Both front to **Mihomo core** → protocol lists overlap (Mihomo adapter enum is shared); Verge adds ** Tauri service mode** detail where FlClash adds **Flutter/Android VpnService** detail
  - DNS/TUN wiki refs (`dns.en.md`, `tun.en.md`) are core-agnostic — reused verbatim
  - Verge Profile Chain `Main(Remote/Local) → Merge→Script chained` analogue to FlClash `overwrite/script` → documented explicitly here

- **Licenses & forks**
  - `LICENSE` path: `https://github.com/clash-verge-rev/clash-verge-rev/blob/dev/LICENSE` (`GPL-3.0`); `docs/README_en.md` also confirms GPL-3.0; changing core channel (Alpha) does not change license

- **Suggested local check**
  - PowerShell: `(Get-Content "C:\Users\qmahyar\Desktop\VPN Research\12-Clash-Verge-Rev.md" | Measure-Object -Line).Lines` — should report **≥ 650** lines (this file targets ~700)
  - Open with Typora/VS Code preview → verify Table of Contents anchors resolve, fenced code blocks highlighted, no broken `![preview]` images

