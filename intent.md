# Intent — YOURVPN vs 13 Competition VPNs — Why This Matrix Wins

> This is the user-facing companion to `goal.md` (frozen, self-contained) and `SPEC.md` (buildable). `goal.md` is the source of truth for agents; this file is the human-readable comparison that an objective agent (or reviewer) can use to check `you >=` every researched VPN on every row. All data below comes from `01-Karing.md … 13-Matsuri-SagerNet.md` (websearch 2026-08-30) plus live grilling locks.
> Self-contained original — no external project names in README/docs, but this intent file is internal and may name them for comparison.

**Last updated:** 2026-08-30 08:00 — **Status:** FROZEN FINAL — All protocols, WG+AmneziaWG priority first — 22 locks — 1 TUN fork — 30-field routing — max firewall — Flutter+Go+M3E — EN/FA RTL
**Next:** `tasks/todo.md:1` scaffold → `core` libbox.aar → `tunnel` 03 Deep.

---

## 1. Endgame in one breath

You are building an **original public AGPL Flutter+Go VPN (Android+Win first, 1 TUN unified via `amnezia-box` fork)** that a reviewer can compare, row by row, to 13 open-source VPNs like Karing, Throne, NekoBox, Nekoray, V2RayN, V2RayNG, Hiddify, Exclave, WG Tunnel, WireSock, FlClash, Clash Verge Rev, Matsuri/SagerNet and find `you >=` on every capability — with **WG + AmneziaWG (all values Jc/Jmin/Jmax/S1-S4/H1-H4/I1-I5/Id/Ip/Ib + ChaCha) as the star** for highly censored networks where vanilla WireGuard is fingerprinted by TSPU. The win is not on one trick, but on the **matrix**: protocols + transports + split tunneling + TUN + DNS + subscriptions + DPI + UI + groups + logs + updates, all self-contained, source-driven from official docs.

**Build order that makes the star testable earliest:** WG/AWG + core routing week 1-2 → VLESS/VMess/Trojan/SS week 3 → Hysteria2/TUIC/SSH/Tor week 4. Full win vs 13 by week 4, but WG/AWG + 30-field routing win by week 2 (SPEC success criteria 1).

---

## 2. Competition matrix — 13 VPNs vs YOUR intent (22 locks)

> How to read: Each row is a capability dimension. Columns are what the research found each VPN does (extreme detail, with where it lives), vs what you will do. `you >=` means you match or extend. Sources are `VPN Research/*.md` files (65k-103k bytes each, 400-580 lines).

### 2.1 Core engine

| VPN | What it uses | How it implements 1 TUN + routing |
|---|---|---|
| **Karing** (14.6k★, Flutter+sing-box 1.14, `KaringX/karing` + `KaringX/sing-box` fork) | `sing-box` dev-next via `vpn_service` → `lib/app/utils/singbox_config_builder.dart:18` → `VPNService.setServer` → Go `Libbox` | Single TUN, system/gvisor/lwip, `route.rules` + `.srs` via `karing-ruleset`, TUN DNS hijack |
| **Throne** (6.8k★, Qt+sing-box) | `SagerNet/sing-box` 1.13.20 + `XTLS/Xray-core` 1.260327 + `Matsuri/sing-box-extra` via `throne-sing-box` fork; `with_awg` via `hoaxisr/amnezia-box` for AWG (issue #1353, `v14d4n/throne-sing-box-awg` 2,310 commits, `type: awg` + FakeIP DNS fix) | Single TUN (gvisor/system/mixed, auto_route/strict_route, Wintun/nft), custom config `throne://` |
| **NekoBox** (MatsuriDayo, sing-box Android) | `sing-box` + `sing-box-extra` + `libbox` JNI | Android `VpnService`, tun2socks via sing-box `tun` inbound, per-app VPN |
| **Nekoray** (Qt, archived 2025-03-17, fork 23★) | `sing-box` 1.9.7-neko1 + `Xray-core` 3.10-3.26 | `db/ConfigBuilder.cpp:200-1050`, TUN gvisor/system, service mode systemd |
| **V2RayN** (114k★, C# WPF+Avalonia, .NET) | `Xray-core` primary + `sing-box`/`mihomo`/`hysteria2` per-profile `coreType` via `AppHandler.GetCoreType` → `bin/{CoreType}` | System proxy PAC/manual vs TUN `xray_tun`/`sing-box tun` via `tun2socks.exe`, `EnableLegacyProtect`, `observatory`/`leastPing` balancer |
| **V2RayNG** (61k★, Kotlin, Android) | `Xray-core` via `AndroidLibXrayLite` (`gomobile bind -androidapi 24`, 467★) | `VpnService` `Builder.establish()` fd `10.10.14.1/30` + `fd00::/126`, `hev-socks5-tunnel`, per-app `addAllowed/DisallowedApplication` |
| **Hiddify** (20k★, Flutter+sing-box 1.11) | `hiddify-core` + `hiddify-sing-box` forks, `sing-box` 1.11 | TUN system/gvisor, `tun: stack`, subscription `hiddify://`, auto ETag |
| **Exclave** (2.6k★, Kotlin, SagerNet→husi→Exclave) | `libexclavecore` 539 commits (`sing-box` 1.13.19 + `quic-go` + `sing-mux` + `sing-juicity`) with `with_clash` tag (GPL-3 dual) | gVisor vs system NAT-rewrite, `addAllowedApplication`, F-Droid `com.github.dyhkwong.sagernet` `e9fe39...` |
| **WG Tunnel** (3k★ Android + 224★ desktop, Kotlin+Go) | `amneziawg-go` (Go) + `wireguard-go` + `hev-socks5-tunnel` + `gVisor netstack` + `WinTun` | `VpnService.Builder.establish()` fd + `protect()` DoH bootstrap, `Lockdown` dummy VPN via hev→SOCKS→netstack, `Local Proxy` 1080/8080, `H1-H4` tuner UI, kernel vs userspace |
| **WireSock** (Windows, proprietary + AGPL `wg-quick-config` 9★) | `wiresock-service` (proxy/NAT, NDIS LWF not WFP/LSP) + `wg-quick-config` Go + `boringtun` Rust + `WinpkFilter` | WFP/NDIS `AllowedApps`/`DisallowedApps`/`DisallowedIPs`, global vs per-profile AND, `wgbooster` SDK `wgb/wgbp`, `#@ws:` INI extensions |
| **FlClash** (50k★, Flutter+Mihomo) | `Mihomo` (ClashMeta) Go via `external-controller:127.0.0.1:9090` REST + FFI, `:core` process split v0.8.88 | TUN `stack:mixed` `auto-route/strict-route/mtu`, registry `networksetup`/`gsettings`, `rule-providers` `mrs`/`yaml`, `fake-ip-range 198.18.0.1/16`, WebDAV sync, SQLite Drift |
| **Clash Verge Rev** (141k★, Tauri 2 + Rust + React 19 + MUI 7) | `verge-mihomo` stable + `verge-mihomo-alpha` sidecar `--ext-ctl` | TUN `system/gvisor/mixed`, `sysproxy.exe`, `DNS enhanced-mode fake-ip` vs `redir-host`, `sniffer SNI`, `tauri-plugin-mihomo-api` pool |
| **Matsuri/SagerNet** (Kotlin, SagerNet successor) | `libcore` + `Xray` via plugins (`Shadowsocks-libev` SIP003, `hysteria-plugin` etc.) | `VpnService`, `tun2socks`, plugin APKs, dex classpath scanner per-app |

**You (YOURVPN):** Flutter 3.47.2 + Go `amnezia-box` `awg-1.14-rc1` `with_awg` → `libbox.aar` (all Jc/H1/I1/Id/Ip/Ib + ChaCha + FakeIP DNS fix via `dnsRouter.Lookup`) + `XTLS/Xray-core` 26.x side lib for VLESS edge, via `gomobile bind -androidapi 24` → single TUN `mixed` via `Tunnel` deep module `connect(tag)` (not `setServer(json string)`). **Why you >=:** You unify the two winning TUN patterns — Karing/Throne single TUN + WG Tunnel `protect()` + WireSock WFP per-app — behind one deep `Tunnel` seam (03), with typed `Endpoint` hidden. No other single VPN does 1 TUN + all Amnezia values + 30 fields + per-app PROCESS-NAME.

### 2.2 Protocols

| Dimension | Competition coverage | You |
|---|---|---|
| **VLESS+Reality/Vision/XHTTP** | Karing, Throne, Hiddify, V2RayN/NG, FlClash, Verge: Reality `x25519mlkem768plus` + Vision `xtls-rprx-vision-udp443` + XHTTP `packet-up/stream-up` via `sing-box` or `Xray` | **All values, priority first** — both sing-box and Xray Reality, `vision` + `XHTTP` auto/packet-up, week 3 after WG/AWG star |
| **VMess** | All Xray/sing-box clients: AEAD/MD5, WS/gRPC/QUIC | Yes, week 3, with `alterId` compat |
| **Trojan** | All | Yes |
| **Shadowsocks (+2022)** | Karing, Throne, Exclave (SIP003 plugins), FlClash/Verge: `2022-blake3-*` + EIH (ReducedIvHeadEntropy) | Yes, SS + SS2022 `2022-blake3` + EIH, SIP003 `simple-obfs`/`v2ray-plugin` not needed (built-in) |
| **Hysteria2** | Hiddify, FlClash, Verge, Exclave: `salamander`/`gecko`, Brutal/BBR, `mport` hopInterval, `pinSHA256`, Chrome parrot | Yes, week 4, `mport` hopping + `hopInterval` + `pinSHA256` |
| **TUIC v5** | Hiddify, FlClash, Verge | Yes, week 4, QUIC `congestion_control: bbr` |
| **WireGuard** | WG Tunnel, WireSock, FlClash/Verge, Throne: `wireguard-go` vs `boringtun` vs `wireguard-nt`, `allowed_ips`, `persistent_keepalive` | **Star — WG + AWG (all values) week 1-2** — `wireguard-go` via `amnezia-box` fork, `boringtun` fallback, `preshared_key` + `local_address` |
| **AmneziaWG** | WG Tunnel 3k★ (full tuner H1-H4 ranges, S3/S4, I1-I5, HeaderProtection ChaCha, ContentPadding, RandomTrailers), Throne via `hoaxisr/amnezia-box` `type: awg` (manual JSON, no UI), WireSock via `boringtun` fork, Karing/FlClash via fork, MahsaNG via Xray fragmentor (not AWG) | **All values:** `Jc`/`Jmin`/`Jmax` junk packets, `S1-S4` padding, `H1-H4` ranges per-packet random + single, `I1-I5` CPS `<b><t><r>`, `HeaderProtection` ChaCha20, `ContentPaddingAddition`, `Custom Timings` ranges, `RandomTrailers`, `DisableCookies`, `Id/Ip/Ib` masquerade (`quic`/`dns`/`stun`/`sip` via `i1` + `quic` fragmented Initial) — `AmneziaWG Domain` deep module `AwgConfig.fromPreset('quic-mimic')` + `generateRandom()` validated (`H1∩H2=∅`, `S1+56≠S2`, `Jmax<MTU`, must-match vs may-differ) + `toEndpointJson()`. UI: `quic-mimic`/`balanced`/`stealth` presets + Advanced disclosure for 30 sliders (WG Tunnel tuner parity). |
| **SSH + AnyTLS/Mieru/Juicity + Naive/ShadowTLS/Snell/ShadowQUIC** | Exclave, Throne: SSH `keepalive@`, AnyTLS v2, Mieru v3 reliable UDP, Juicity `sing-juicity`, ShadowTLS `JLS 0.17.47`, Naive `cronet-go`, Snell v4/v6 `sing-snell`, ShadowQUIC | **Niche obfuscation kept but not star:** SSH dynamic forwarding, AnyTLS v2, Mieru v3 via sing-box, Juicity via `sing-juicity`, ShadowTLS via `with_shadowtls` — hidden behind Ingestion adapter, not top-level UI. Naive deferred (Chromium dep heavy). |
| **Tor + chaining** | WG Tunnel Local Proxy, Exclave chain, sing-box `chain` outbound (`sing-box-lx` `with_lx_chain`), VLESS `relay` groups | **Chain kept:** `chain` outbound `tor → wg` via Tor sidecar `127.0.0.1:9050` SOCKS detour `tor-socks` (not `type:tor` FATAL #4200 per `audit.md`), isolated so sing-box stays up if Tor entry blocked. 1 TUN, not 2. |

**You >=:** You cover every protocol that any of the 13 covers, via the same Go engines they use (`sing-box`, `Xray`, `amneziawg-go`, `amneziawg-go` 3-way merge `Leadaxe/wireguard-go-awg2-lx`), plus you unify them behind one `IngestionAdapter` sealed union instead of 7 shallow parsers. No other single VPN in the set does **all** of SS2022 EIH + Hysteria2 `mport` + TUIC v5 + AWG 3.1 all values + `Id/Ip/Ib` + Tor sidecar chain in one build.

### 2.3 Transports & DPI evasion

| Transport / trick | Who does it | You |
|---|---|---|
| **Reality** | Xray/sing-box: `x25519mlkem768plus` + `mldsa` | Both sing-box and Xray Reality, `spx` |
| **uTLS fingerprint** | Reality clients: `chrome`/`firefox`/`safari` | Yes, `utls` `chrome` via `sing-box` `with_utls` |
| **Fragment / mixed-case / XHTTP padding** | Dragon VPN `ByeDPI` toolchain + Xray `fragment` + sing-box `fragment` | Yes, `fragment` + `mixed-case` + `XHTTP` `packet-up`/`stream-up` |
| **ECH** | Experimental in `sing-box` naive outbound, `rustls` not GA (per mavi-vpn TODO) | **v1 per your Keep All** — behind flag, not promise (risk noted in `audit.md:4`) |
| **AmneziaWG junk/padding** | WG Tunnel `H1-H4` UI, Throne `type: awg` JSON, Karing `AmneziaWG 2.0` | **All 3.1:** `H1-H4` single or `"N-M"` range + `S3/S4` + `I1-I5` CPS + `HeaderProtection` ChaCha20 + `ContentPadding` + `Timings` + `RandomTrailers` + `Id/Ip/Ib` masquerade — validated before Go call |
| **WireSock WFP junk / Warp chain** | WireSock `#@ws:` `AllowedApps`/`DisallowedIPs` + `warp=on` via MASQUE `CONNECT-IP` `h3`/`h2` (sing-box-lx) | **Optional:** `with_lx` `masque` `CONNECT-IP` `h3`/`h2` for Cloudflare WARP via `sing-box-lx` thin fork if needed week 4; otherwise deferred |

**You >=:** All tricks ON like Exclave/Hiddify `All tricks ON`, but you validate Amnezia `H1∩H2` before handshake (no other does).

### 2.4 Split tunneling & routing

| Feature | Competition | You |
|---|---|---|
| **Per-app include/exclude** | Android `addAllowed/DisallowedApplication` (NekoBox, V2RayNG, Exclave) vs Windows WFP `AllowedApps`/`DisallowedApps` (WireSock `AllowedApps` global vs per-profile AND, Throne PROCESS-NAME) | **Both:** `package_name` / `package_name_regex` (`com.termux.*`) on Android + `process_name`/`process_path`/`process_path_regex` (`curl`, `/usr/bin/curl`, `Telegram.exe`) on Windows/Linux via `find_process` + per-app `wifi_ssid`/`bssid` + `network_type` |
| **Rule-based** | sing-box: 30 fields `domain/suffix/keyword/regex/geosite/geoip/ip_cidr/ip_is_private/port/range/process_name/package_name/user/clash_mode/network_type` + `rule_set` SRS `binary` + `logical and/or` + `invert`; Clash: `DOMAIN/GEOSITE/GEOIP/IP-CIDR/PROCESS-NAME/RULE-SET/MATCH` + `rule-providers` `mrs`/`yaml` + `no-resolve` | **Full 30 fields** via `RoutingCompiler` deep module — `RoutingPolicy` → `CompiledRoute` with `isValid` + `validationErrors` (not throw). `OR-group AND-logic` (`route/rule/rule_default.go:17`) hidden. UI: Full M3E editor with 30 inputs + `logical and/or` nesting + Monaco YAML fallback. **3-tier groups** `auto (urltest filter HongKong\|HK)` → `selector MANUAL` → `proxy PROXY` + `TOR-CHAIN relay` `filter`/`exclude-filter`/`exclude-type`/`icon`/`hidden` like Clash, but via sing-box `GroupTree` private inside compiler. |
| **Providers** | FlClash/Verge: `proxy-providers` + `rule-providers` `type: http` `behavior: classical/domain/ipcidr` `interval: 86400` + `RULE-SET` | Yes, `rule_set` remote `url` + `format: binary` + `update_interval 24h` + `download_detour: proxy` + `initial_path` + `CacheFile` via `GeoAsset` 05 Deep — same as Hiddify `CacheFile` + `geodat2srs` |
| **Chain** | Exclave chain, sing-box-lx `chain` `with_lx_chain` (`direct` at position ≥1 off-switch, `strip`/`rewrite`), Clash `relay` (traffic enters first, exits last, all hops must work) | Yes, `relay` selector + `chain` virtual multi-hop via `detourList` + `GetChains` RPC (`with_lx_command`), lazy warmed links, `idle_timeout`, per-layer latency |

**You >=:** No other does `process_name` on Windows + `package_name` on Android + `wifi_ssid` + `rule_set` SRS + 3-tier + `logical and/or` in one typed policy. Throne has per-process but no 30-field UI; FlClash has providers but no per-packet H1 ranges.

### 2.5 TUN vs System Proxy + Kill switch

| Mode | Competition | You |
|---|---|---|
| **TUN** | Karing/Throne/NekoBox: `tun` inbound `gvisor/system/mixed`, `auto_route/strict_route/mtu`, `gso`; FlClash/Verge: `stack:mixed` + `auto-route`/`strict-route`/`route-address`; V2RayN: `tun2socks.exe` `xray_tun`; Exclave: gVisor vs system NAT-rewrite | **Both, user toggles** like Karing/FlClash + `mixed` recommended + `gso` + `route-address` + endpoint-independent NAT + DNS hijack always-on under TUN. `auto_detect_interface` true, `default_interface`/`default_mark`, `find_process` + `find_neighbor` |
| **System Proxy** | V2RayN/FlClash/Verge: PAC/manual via `registry`/`networksetup`/`gsettings`, `sysproxy.exe`, guard mode | Yes, PAC/manual, `sysproxy.exe` helper for elevation, `guard` mode |
| **Kill switch** | WG Tunnel Lockdown (dummy VPN via hev→SOCKS→netstack, blocks all if TUN down) + WireSock Network Lock (WFP) + Floppa stealth `iptables` — **hardcore** vs Karing/Throne soft (just restore proxy) | **Hardcore** like WG Tunnel/WireSock — `WFP/iptables/pf` anchors `block drop out on en0 all` + `pass out on utunX` (vendors manage anchors), `NE` DNS pin `10.x`/`fdxx::`, IPv6 block unless routed, `PF` `block drop` + `pass out on utun`. Tested via 7 leak tests (reboot/sleep/handoff/DoH/QUIC/IPv6/split) per RTINGS July 2026 (6/16 leaked via DNS fails-open, IPv6, QUIC). |
| **Local SOCKS/HTTP** | WG Tunnel Local Proxy 1080/8080, Exclave Local Proxy, V2RayN `10808/10809` | Yes, `127.0.0.1:10808` SOCKS5 + `10809` HTTP for AdGuard chaining |

**You >=:** You combine the two winning kill switches (WG Tunnel Lockdown + WireSock Network Lock) + Karing single TUN, tested via 7 scenarios where 6/16 leaked.

### 2.6 DNS

| Feature | Competition | You |
|---|---|---|
| **FakeIP** | FlClash/Verge/Karing: `fake-ip-range 198.18.0.1/16` + `fake-ip-filter-mode blacklist` | `fake-ip-range 198.18.0.1/16` + `fake-ip-filter-mode blacklist` (Verge) |
| **Upstream** | DoH `https://1.1.1.1/dns-query`, DoT, DoQ, plain `8.8.8.8` | DoH `1.1.1.1` + `dns.google` + domestic `doh.pub` |
| **Split** | `nameserver` + `fallback` + `fallback-filter` + `proxy-server-nameserver https://1.1.1.1#PROXY` chicken-egg fix (Clash Verge) | Same, `https://1.1.1.1#PROXY` to solve bootstrap |
| **Hijack** | Sing-box `dns.hijack` always-on under TUN, `sniffer SNI` | `dns.hijack` always-on, `sniffer SNI` |

**You >=:** Same as most modern, but you isolate bootstrap via `GeoAsset` not manual.

### 2.7 Subscriptions

| Format | Competition | You |
|---|---|---|
| **Clash YAML** | All Clash/Mihomo clients: full via `fkYAML`, `proxy-providers` + `rule-providers` `mrs`/`yaml`, `interval: 86400` | Yes, via `IngestionAdapter` |
| **sing-box JSON** | Karing, Hiddify | Yes, `outbound` array |
| **URI** | `vmess://`/`vless://`/`ss://`/`trojan://`/`socks://`/`http://` + `hysteria2://`/`hy2://`/`tuic://`/`wireguard://` INI `[Interface]` | Yes, all via sealed union |
| **Other** | SIP008 `server_key`, Hiddify subscription `hiddify://`, `v2rayn://`, `mrs`/`srs` providers | Yes, SIP008, `mrs`/`srs`, `hiddify://`, `yourvpn://` deeplink |
| **Update** | ETag `If-None-Match`, `interval: 86400`, `path` | Same, `ETag` + 6h stale-while-revalidate + `x-ratelimit-reset`/`retry-after` (sesori) + `initial_path` fallback, `CacheFile.enabled` |

**You >=:** You add sealed union normalization + ETag inside `IngestionAdapter`, not leaking format quirks into `VpnServer` like shallow parsers.

### 2.8 DPI — see 2.3, UI — see prototype, Groups/Logs/Updates — see bento home

**UI stacks compared:**

| VPN | Stack | You (blended Bento×Hum) |
|---|---|---|
| Karing/Hiddify/FlClash | Flutter+Dart+Go | **Flutter 3.47.2 + material_3_expressive 45 M3E + cue/motion_kit/transit_kit** — faithful Flutter M3 Expressive like Slipnet Compose M3 in Flutter (not just Material You) — 45 M3E + `motor` spring + `material_new_shapes` + `dynamic_color`, blended `01-bento-specimen` (Bento Grid 10 tiles irregular) × `10-grid-hum` (push shift + color-shift cards + eye blink) → `prototype-final.html` (hero prism Jc/H1/I1 beams, pulse, draggable bottom sheet, glass dialog). Self-contained original, no external VPN names in README/docs. |
| Throne/Nekoray | Qt C++ + sing-box | — |
| V2RayN | C# WPF + Xray | — |
| V2RayNG/NekoBox/Exclave | Kotlin + Go | — |
| Clash Verge Rev | Tauri 2 + Rust + React 19 + MUI 7 | — |

**Extra features:**

| Feature | Competition | You (All power features day 1) |
|---|---|---|
| Latency test | V2RayN `Tcping vs Real ping`, Throne speedtest, Verge/FlClash `urltest` | Yes, `urltest` + TCP ping + real-delay, `observatory`/`leastPing` balancer, sort by ping |
| Groups | Nekoray/Throne folders | Yes, 3-tier `auto`/`selector`/`proxy` + `TOR-CHAIN relay` |
| Traffic stats | All | Yes, per-proxy/per-app, `fl_chart` |
| Backup/sync | Karing `iCloud/WebDAV/LAN ZIP` + FlClash WebDAV `drift` | Yes, WebDAV + LAN ZIP, `drift` sqlite |
| Geo updater | `geodat2srs` + `sing-box rule-set compile` + `CacheFile` | Yes, `GeoAsset` 05 Deep |
| Hotkeys/tray/deeplink | Throne `QHotkey`, Karing `yourvpn://` | Yes, `QHotkey` + tray + `yourvpn://` |
| Logs | Verge `core version/logs` + FlClash `connections polling` | Yes, `SubscribeDNSQueries` + pcap toggle + `fl_chart` + `Health` hierarchical Logs→Ping→Stats |

---

## 3. Your 22 locks — how they compare

| Lock | Your choice | Vs competition — where you extend |
|---|---|---|
| 1. Who | Public open-source | — |
| 2. Platforms | Android+Win first | Like NekoBox/V2RayNG (Android) + V2RayN/Throne (Win) — same hot spots |
| 3. Core | `amnezia-box` fork `with_awg` + Xray side lib, 1 TUN, `gomobile bind` — internal, not in README | Karing/Throne single TUN + WG Tunnel `protect()` — you unify both |
| 4. Protocols | **All protocols, WG/AWG priority first** (week 1-2 WG/AWG + routing, week 3 VLESS etc., week 4 Hysteria2/TUIC/Tor) — not WG-only, not pure multi without priority | All do All, but no one does WG/AWG star first with all-values validated before Go call |
| 5. DPI | All tricks ON + ECH v1 (risk noted) — Reality+Vision+XHTTP+uTLS+Fragment+ECH+AnyTLS/ShadowTLS/Salamander + Amnezia 3.1 all values + `Id/Ip/Ib` | WG Tunnel has H1-H4 UI + Leadaxe `wireguard-go-awg2-lx` 3-way merge — you match it plus add validation `H1∩H2=∅` |
| 6. Routing | 30 fields + 3-tier + `logical and/or` + `invert` + `rule_set` SRS via `RoutingCompiler` deep module, Full M3E editor with 30 inputs + Monaco fallback | Throne per-process + FlClash providers — you do both in one typed policy |
| 7. Capture | Both TUN `mixed` + Proxy PAC + hardcore WFP max + Local SOCKS 10808 | WG Tunnel Lockdown + WireSock Network Lock — you do both + Karing single TUN |
| 8. DNS | FakeIP 198.18/15 + DoH split + `proxy-server-nameserver https://1.1.1.1#PROXY` + hijack | Same as modern, but isolated via `GeoAsset` |
| 9. Subs | All formats + ETag 24h + 6h cache + QR/ZIP deeplink via `IngestionAdapter` sealed union | Karing ServerManager + Hiddify ray2sing — you hide quirks behind adapter |
| 10. UI | Flutter 3.47.2 + M3E 45 + cue/motion_kit/transit_kit, blended Bento×Hum | Slipnet Compose M3 in Flutter — no other does 45 M3E + Bento 10 tiles + Hum push shift |
| 11. Extras | All power features day 1 | Same as Karing/FlClash — you keep `All` but risk 9-10w noted |
| 12. Privacy | AGPL + zero telemetry + encrypted secrets + max firewall + 7 tests + 90s video | Same as reputable, but self-contained LICENSE, README no external names |
| 13. Distro | GitHub Releases only MVP, 3 jobs parallel, `latest.json` platform map | Like `lollipopkit/flutter_server_box` + `RecomBox` — you do same + `sha256` + `src` tarball |
| 14-18. Deeps 01-06 | `03→01+02→04→05→06` with `connect(tag)`, `isValid` field, sealed union, preset+Custom, `ensure→Path` always, `snapshot+stream` | No competition does 6 deep modules with `interface is test surface` as proposed — this is your leverage |
| 19. i18n/RTL | EN + FA RTL ARB + `EdgeInsetsDirectional` + `Semantics` + `ReduceMotion` | Like GRoute EN/FA — you do same + 200% scale golden |
| 20. Diagnostics | Full: Slipnet scanner 0-6 + Prism HMAC + Simple Ping TCP 5000ms + PingRoute per-hop + `network_reachability` Rust + `drift` | Slipnet 0-6 + WG-Tunnel health LED hierarchy — you do both + `Health` deep module |
| 21. Branding | Original self-contained, no external thanks in README/docs, LICENSE self-contained | VPNclient Extended GPL would require thanks — you avoid it via original MethodChannel |
| 22. Library | `material_3_expressive` (Slipnet-like) + cue/motion_kit | Slipnet Compose M3 — you are its Flutter faithful |

---

## 4. What you deferred (and why it still wins)

- **VLESS etc. deferred to week 3-4, not dropped** — SPEC success criteria 1 says WG/AWG + routing win by week 2 is shippable MVP, full win vs 13 by week 4. This respects `Keep All + ECH = 9-10w` risk while making star testable earliest.
- **ECH + All extras kept per your Keep All** — risk noted in `audit.md:4`, but you locked it. Mitigated via `wayfinder` tickets + `principle-sequence-verifiable-units`.
- **Delete-immediately migration** — you chose delete shallow modules immediately (Q10) over deprecated adapters — faster but riskier, warrants ADR if hard to reverse (per `domain-modeling`).

---

## 5. How to use this file

- **Agent:** Before any task, read `SPEC.md:Architecture — Deep Modules` + `CONTEXT.md` + `tasks/plan.md` build order + this intent's row for the capability you touch.
- **Reviewer:** Pick a row, open the `VPN Research/*.md` source, and check `you >=` with `scripts/compare_capabilities.py` (to be built per SPEC success criteria 1).
- **Next:** `tasks/todo.md:1` scaffold → `core` libbox.aar → `tunnel` 03 Deep (fake fd test without device).

---

**Intent frozen from `goal.md` FROZEN FINAL (2026-08-30 08:00) — 22 locks — All protocols WG/AWG priority first — original self-contained — source-driven from `docs.flutter.dev`, `sing-box.sagernet.org`, `developer.android.com`, `pub.dev` — no copy-paste from other VPNs.**
