# 10 — WireSock & WireSock VPN Gateway — Extreme-Detail Research

> **Sources verified 2026-08-30:** `wiresock.net` docs (Secure Connect, VPN Gateway, Advanced Parameters, Package Overview, CLI Reference, Virtual Adapter vs Transparent), `github.com/wiresock/wg-quick-config`, `github.com/wiresock/ndisapi`, `github.com/wiresock/ndisapi-go`, `wiresock.net/wiresock-secure-connect/download`, `wiresock.net/wiresock-vpn-gateway/download`, NT Kernel forum threads on Wiresock NDIS LWF, `n tkernel.com/windows-packet-filter`.
> **Scope:** WireSock Secure Connect (formerly WireSock VPN Client), WireSock VPN Gateway (wiresock-service + wg-quick-config), SDK/wgbooster, WireSockUI legacy, BoringTun fork.

---

## Table of Contents

- [1. Overview — What WireSock Is and Is Not](#1-overview--what-wiresock-is-and-is-not)
- [2. Supported Protocols](#2-supported-protocols)
- [3. Core Architecture — Drivers, BoringTun, wiresock-service, wg-quick-config, SDK](#3-core-architecture--drivers-boringtun-wiresock-service-wg-quick-config-sdk)
- [4. Split Tunneling — Per-App, Per-IP, Per-Domain, WFP/NDIS Mechanics](#4-split-tunneling--per-app-per-ip-per-domain-wfpndis-mechanics)
- [5. TUN — Virtual Adapter vs Transparent Proxy vs Gateway Mode](#5-tun--virtual-adapter-vs-transparent-proxy-vs-gateway-mode)
- [6. Config Format — WireGuard INI + WireSock Extensions](#6-config-format--wireguard-ini--wiresock-extensions)
- [7. Platforms — Windows Only Matrix](#7-platforms--windows-only-matrix)
- [8. CLI, GUI, Secure Connect App, Service Lifecycle](#8-cli-gui-secure-connect-app-service-lifecycle)
- [9. Repository Stats, Install Docs, Package Overview](#9-repository-stats-install-docs-package-overview)
- [10. Performance, Security, DNS/Killswitch, Troubleshooting, Licensing](#10-performance-security-dnskillswitch-troubleshooting-licensing)

---

## 1. Overview — What WireSock Is and Is Not

- **WireSock Secure Connect = enhanced WireGuard client for Windows — NOT a generic VPN provider**
  - Ships as both CLI (`wiresock-client.exe`) and modern WPF GUI (Secure Connect 3.x), plus headless Windows Service
  - Purpose: selective, app-aware tunneling on Windows where official WireGuard client does only full-tunnel or AllowedIPs-based split
  - Tagline on wiresock.net: *"Sophisticated WireGuard VPN client for Windows — selective application tunneling and IP exclusion, lightweight transparent solution, free\*"*

- **WireSock VPN Gateway = turns a Windows machine into a WireGuard server / LAN gateway**
  - Package = `wiresock-service` (sharing engine) + `wg-quick-config` (Go console utility)
  - Solves “WireGuard has no native server role on Windows + ICS is painful” — offers NAT or transparent proxy sharing for downstream WireGuard peers
  - Positioned as free* for personal/edu/non-profit, commercial requires license via NT Kernel

- **Proprietary core, open peripherals — hybrid licensing model**
  - **Proprietary/closed:** `wiresock-service`, Secure Connect GUI, `wgbooster.dll`, NDIS drivers (Windows Packet Filter / NDIS LightWeight Filter) — not open-source, distributed as signed drivers + DLLs
  - **Open:** `wg-quick-config` (AGPL-3.0 on github.com/wiresock/wg-quick-config), `ndisapi` (MIT-ish, user-mode NDISAPI library), `ndisapi-go` (Go binding), docs and example configs are public
  - **Forks:** `wiresock/boringtun` (Rust BoringTun fork with AmneziaWG patches) — public GitHub, shows how obfuscation is wired
  - Implication: you can audit/automate gateway setup via Go code, but packet-intercept engine remains binary

- **Windows-only heritage — 10/11 first-class, 7/8.1 legacy with limits**
  - Official support: Windows 10/11 x64/x86/ARM64 fully; Windows 7 SP1 / 8.1 x64/x86 with limitations (driver install quirks, .NET dependency)
  - No Linux/macOS client — Linux users just use upstream WireGuard or AmneziaWG; WireSock’s value is Windows integration
  - Even the SDK is Windows-specific — `wgbooster.h` + driver install require Admin, Windows-only syscalls

- **Narrow technical niche — TUN via NDIS LightWeight Filter, NOT plain WFP or LSP**
  - Author Vadim Smirnov explicitly: *“Wiresock is not based on WFP, it is NDIS LightWeight Filter”* (NT Kernel forum, 2021-12-20)
  - Underlying framework = **Windows Packet Filter (WinpkFilter)** from NT Kernel Resources — NDIS LWF driver that sees raw packets at NDIS layer
  - User-mode API = **NDISAPI** (`ndisapi.dll/.lib/.net`) — enumerate adapters, filter/inpect/modify/inject packets with minimal perf hit
  - This is why WireSock can do per-process split without a TAP adapter and without modifying routing tables in transparent mode
  - Contrast with:
    - **WFP** (Windows Filtering Platform) — what simplewall/VPNs often use for per-app callouts; not WireSock’s path
    - **LSP/Winsock LSP** — legacy, deprecated, not used
    - **Wintun** — what `wireguard-go`/`wireguard-nt` use for TUN; WireSock *avoids* it in transparent mode, optionally *creates* a “Wiresock Virtual Adapter” in Virtual Adapter mode (see §5)

- **Brand lineage — from bare `wiresock-client` to Secure Connect 3.x**
  - **Early (2021-2023):** `wiresock-client.exe` (CLI) + community GUI `WireSockUI` (EpexGUI → WireSockUI, now deprecated, points to Secure Connect)
  - **2.2.x → 3.4.x:** Secure Connect with built-in UI, junk-packets, AmneziaWG, QUIC/DNS masking, global split-tunneling, KillSwitch/Network Lock, wgbooster SDK split
  - **Gateway product** has parallel versioning (currently 1.x) — distinct from client versions

- **Why it exists — gap in official WireGuard for Windows**
  - Official client: either all traffic (`0.0.0.0/0`) or manual `AllowedIPs` splits — no per-exe allow/deny, no SOCKS5 handshake wrapping, no DPI obfuscation
  - WireGuard-NT kernel driver is fast but no DPI evasion, no app awareness
  - WireSock fills: per-app `AllowedApps/DisallowedApps`, per-IP `DisallowedIPs`, `Bypass LAN`, SOCKS5 bridging, junk/magic-header obfuscation, transparent proxy gateway — all in one Windows-native stack

---

## 2. Supported Protocols

- **WireGuard (vanilla) — full fidelity**
  - Implements Noise_IK, Curve25519, ChaCha20-Poly1305, BLAKE2s exactly as upstream
  - Crypto itself unchanged even in AmneziaWG mode — obfuscation is transport wrapper, not cipher swap
  - Works with any standard WireGuard server: Linux `wg-quick`, MikroTik, UniFi, `amneziawg-go` in vanilla mode, `boringtun`, `wireguard-go`
  - Config keys: `PrivateKey`, `PublicKey`, `PresharedKey`, `AllowedIPs`, `Endpoint`, `PersistentKeepalive`, `Address`, `DNS`, `MTU` — all pass through unchanged
  - Performance path uses **Cloudflare BoringTun** (Rust, userspace) ported and patched — NT Kernel’s own fork `wiresock/boringtun` integrates cleanly with WinpkFilter
    - Why BoringTun over `wireguard-go` (Go) or `wireguard-nt` (kernel)? Userspace Rust gives DPI flexibility (easier to patch headers), no kernel crash surface, and faster than Go on Windows
    - Forum post: author chose BoringTun as base because *“faster implementations like WireGuardNT could be swapped without patching drivers — obfuscation at routing layer”* is ideal, but AmneziaWG required library patches so BoringTun fork was taken

- **AmneziaWG — supported, but via 2.0/“Amnezia 2.0” posture, not 1.5 I1-I5**
  - **What AmneziaWG is:** fork of `wireguard-go`/`boringtun` that randomizes handshake fingerprints for DPI evasion — junk packets, magic headers, padding, optional I1-I5 CPS chain
  - **WireSock’s stance (docs verbatim):** *“We do not support standard AWG 1.5 `I1`–`I5` parameters. Instead WireSock uses its own, more convenient method for configuring simulation settings”*
    - GUI and manual config expose: `Jc/Jmin/Jmax/Jd` (junk), `S1/S2/H1/H2/H3/H4` (magic headers), `Id/Ip/Ib` (protocol masking)
    - Silently ignores incoming `I1..I5` lines from AmneziaWG-generated configs instead of erroring (fix added 3.4.5.1)
  - **Mapping to AmneziaWG versions:**
    - **1.5 era:** CPS/I1-I5 + `H1-H4` single values + `Jc/Jmin/Jmax/S1/S2` — partially supported via WireSock’s own `Jc/Jmin/Jmax/S1/S2/H1-H4` set
    - **2.0 era:** Adds `S3/S4` and `H1-H4` ranges → WireSock Secure Connect 3.x docs show `S1-S4, H1-H4` (note: `v3/wiresock-secure-connect/connection-profiles.html` lists `S1-S4/H1-H4`; advanced-parameters.html still lists `S1-S2/H1-H4` — docs in transition, client 3.4.8.1 accepts S1-S4)
    - **3.1 era:** Adds `HeaderProtectionKey`, `ContentPaddingAddition`, `RandomTrailers`, `RekeyAfterTime` ranges — NOT yet exposed in WireSock docs; wireSock’s amneziawg-install fork generates S3/S4 + H-ranges for its proxy but client UI not yet 3.1-full
  - **How it handles WG obfuscation under the hood:**
    - **Junk packets (Jc):** `Jc` dummy UDP packets, size `Jmin..Jmax`, optional delay `Jd` (ms), injected *before* handshake — breaks DPI size/timing signatures, works even against standard WG server (server just drops junk as noise)
    - **Magic headers (S1/S2 + H1-H4):** `S1/S2` = random bytes prepended to Init/Response handshake (shifts header), `H1-H4` = replacements for WireGuard message-type uint32 (Init=1, Response=2, Cookie=3, Transport=4 by default) — both sides must match, incompatible with vanilla WG server
    - **Protocol masking (Id/Ip/Ib):** `Id` = domain to mimic (e.g., `somemarketplace.net`), `Ip` = `QUIC`|`DNS`|`SIP`|`STUN` (WireSock docs list QUIC/DNS; proxy layer adds STUN/SIP), `Ib` = `Chrome`|`Firefox`|`cURL` browser fingerprint — rewrites leading bytes so packet looks like QUIC Initial or DNS query on wire
  - **Server requirement:** Standard WG → only `Jc/Jmin/Jmax/Jd` + `Id/Ip/Ib` + SOCKS5 works; AmneziaWG server (`amneziawg-go` or `amneziawg-install` 2.0 template) required for `S1/S2/H`* to negotiate
  - **Does WireSock support AmneziaWG?** Yes — explicitly markets “AmneziaWG 2.0 Support*” as New DPI feature in Secure Connect 3.4.x feature list; asterisk links to docs clarifying the I1-I5 exception
  - **Interop test path:** NT Kernel maintains `wiresock/amneziawg-install` repo — fork of `RomikB/amneziawg-install` extended for 2.0 params (`S3/S4/H-ranges`, migration, `amneziawg-proxy.sh` Rust QUIC/DNS/STUN/SIP obfuscation proxy). README states: *“amneziawg-proxy is most powerful with WireSock Secure Connect 3.5+ — bidirectional imitation requires client 3.5+”* — proves tight coupling tested on real DPI

- **SOCKS5 bridging — two levels, not just handshake**
  - **Handshake-only (legacy):** `Socks5Proxy = host:port` + optional `Socks5ProxyUsername/Password` — only WireGuard handshake UDP is wrapped in SOCKS5 UDP ASSOCIATE; transport stays direct
  - **All-traffic (added in Gateway 1.1.4 / Secure Connect 2.4.x):** `Socks5ProxyAllTraffic = true` — *all* WireGuard UDP (handshake + transport) goes through SOCKS5, masking entire WG flow as SOCKS5 stream — critical for DPI that fingerprints transport packet sizes
  - Implementation: in transparent mode WireSock does `associate_to_socks5_proxy: SOCKS5 ASSOCIATE SUCCESS port: xxxxx` then `C2S: local:port -> endpoint :port` and `C2S: local:port -> socks:port` dual path visible in `-log-level all` — confirms UDP ASSOCIATE bridging
  - Handles `WARP` edge: fix 2.4.22.1 notes `SOCKS5 proxy handling in transparent tunnel mode — WARP IPv6 traffic over IPv4 tunnel could fail when routed through IPv4 SOCKS5 proxy, now correctly processed` — so SOCKS5 path is aware of dual-stack tunneling
  - Gateway’s `wiresock-service` also *“utilizes system’s active HTTP/SOCKS5 proxy settings for outgoing connections”* in proxy mode — different layer: server-side sharing respects host proxy for client-egress

- **Other transports — what is NOT supported**
  - No native VLESS/Shadowsocks/WSTunnel inside WireSock — but users chain `wstunnel` *outside* and test via WireSock’s `Socks5Proxy` or system proxy (forum user confirmed `wstunnel` + WireSock works, though switching default interface leaked)
  - No QUIC *transport* (WireGuard stays UDP), only QUIC *mimicry* via protocol masking — important distinction
  - No TCP fallback for WireGuard itself — if UDP blocked without SOCKS5, handshake fails; SOCKS5 TCP bridge is the escape hatch

---

## 3. Core Architecture — Drivers, BoringTun, wiresock-service, wg-quick-config, SDK

- **wireguard-go vs wireguard-nt vs WireSock’s own driver — why WireSock is third path**
  - **wireguard-go + Wintun:** upstream Go userspace — uses `wintun` (Layer 3 TUN driver) for interface, `CreateTUN`/`StartSession` ring of 8 MiB, packet copy overhead; official Windows client uses this or WireGuardNT; open-source but generic, no app-aware filter
  - **wireguard-nt (WireGuardNT):** kernel driver (`wireguard.dll` side-by-side, `InitializeWireGuardNT`, `WIREGUARD_GET_RUNNING_DRIVER_VERSION_FUNC`) — fastest throughput baseline (kernel crypto, zero-copy), but requires kernel signing, no DPI hooks, no per-app granularity, single global routing table change
  - **WireSock’s choice:** *neither* directly — uses **WinpkFilter NDIS LWF + BoringTun (Rust)**
    - NDIS LWF sits below TCP/IP, sees *every* packet pre-routing → can decide per-packet to divert into BoringTun userspace tunnel or pass through
    - BoringTun does Noise + ChaCha20 in userspace Rust — patched for Amnezia `S1/S2/H1-H4/Jc` logic (`wiresock/boringtun` repo)
    - Return path: decrypted payload injected back via NDISAPI `SendPacket` or virtual adapter’s Wintun-like session
  - **Performance claim:** wiresock.net benchmark (Intel NUC i3-3217U vs Xeon E-2378G + 10Gb Broadcom) shows *transparent mode* download > WireGuardNT kernel, with Virtual Adapter mode also beating Go — attributed to zero routing-table churn + per-packet steer avoiding full stack traversal

- **wiresock-service — Windows service that *is* the gateway**
  - **Language/stack:** native C/C++ service (not Go), built on `ndisapi` + WinpkFilter driver; counterpart to `wiresock-client`’s `wgbooster` but for server-side sharing
  - **What it does:** filters the *WireGuard server interface* (default name `wiresock`) — intercepts TCP/UDP from WG clients, redirects to local transparent proxies for LAN/Internet egress; also handles DNS forwarding
  - **Two modes inside one binary:**
    - `proxy` (default): *transparent TCP/UDP proxy* — userspace NAT-like, respects system HTTP/SOCKS5 proxy; supports TCP+UDP, **no ICMP** (so `ping` fails — documented limit)
    - `nat` (flag `-mode nat`): *NAT gateway* — kernel-level NAT akin to Windows ICS but more reliable; supports ICMP via actual NAT translation, closer to router behavior
  - **DNS handling:** by default forwards client DNS to host’s local resolvers for speed; override via `-dns "4.4.4.4,8.8.4.4"`; falls back to `8.8.8.8,1.1.1.1` if none specified; avoids hardcoding and respects corporate DNS when behind NAT
  - **Service lifecycle:** `wiresock-service install|uninstall|run` with `-start-type 2/3/4`, `-account`/`-password`, `-interface`, `-log-level`, `-dns`, `-mode`; `sc start/stop wiresock-service`; transparent upgrade via `uninstall`→`install`→`sc start`
  - **Relation to client’s `wiresock-client`:** both use same WinpkFilter driver but different driver profiles; they can coexist on same host if interfaces don’t clash (client transparent vs gateway proxy on `wiresock` iface)

- **wg-quick-config — Go console utility that automates `wg-quick` on Windows**
  - **Repo:** `github.com/wiresock/wg-quick-config` — AGPL-3.0, Go 1.18, 7 commits, 9 stars/1 fork/2 watchers (as of 2026-08 fetch), single contributor `wiresock`, default branch `master`, homepage `wiresock.net/wiresock-vpn-gateway`
  - **Purpose-line from README:** *“Simple configuration tool designed for Wiresock VPN Gateway. Streamlines creation, managing, implementing WireGuard configurations. Generates QR codes for hassle-free mobile setup”*
  - **File inventory (from GitHub):**
    - `main.go` — flag parsing (`-start/-stop/-restart/-add/-qrcode`), admin-elevation check, JSON config load/store, orchestrates peer add + tunnel restart
    - `app_config.go` — `appConfig` struct, `Clients[]`, `updateWireguardConfigFiles()`, `showClientQrCode()`, `addClient()`
    - `key.go` — Curve25519 keypair generation (wraps `golang.org/x/crypto/curve25519` or WireGuard key util)
    - `wg_config.go` / `user_config.go` — renders `[Interface]`/`[Peer]` INI files for server and per-client
    - `qrcode.go` — terminal QR via `skip2/go-qrcode` or similar
    - `powershell.go` / `windows.go` — `IsAdminElevated()`, PowerShell `Start-Service`/`Stop-Service` wrappers, registry/env tweaks
    - `port.go` — UDP port picking + firewall `netsh advfirewall` rule injection
    - `go.mod` / `go.sum` — pinned deps
  - **Behavior from `main.go` snippet:**
    - Reads `%ALLUSERSPROFILE%\NT KERNEL\WireSock VPN Gateway\config.json` — if missing, `newConfig()` generates server keys, random UDP port, `Address = 10.x/24`, and first peer
    - `-add -start`: first-run path generates and starts tunnel immediately; later `-add -restart` adds peer, rewrites `wg0.conf`, QRs latest client
    - `-qrcode 1` → `-qrcode N`: renders QR for Nth client’s `clientN.conf` to stdout for phone scan
    - `-stop`/`-start`/`-restart`: calls `stopWireguardTunnel()`/`startWireguardTunnel(configFilePath)` which shell out to `wireguard.exe`/`wiresock-client` or `netsh` under the hood; sleeps 1s between stop→start on restart
    - Admin check: *“Please note to run this application as Administrator to use Start/Stop/Restart flags”* if not elevated (important on UAC)
  - **Config layout on disk:** `%ALLUSERSPROFILE%\NT KERNEL\WireSock VPN Gateway\` contains `config.json` (JSON master), `wg0.conf` (server), `client1.conf`, `client2.conf`, … — same pattern as `wg-quick` on Linux but Windows paths
  - **Idempotency:** `addClient()` appends peer with `AllowedIPs = <clientIP>/32`; `updateWireguardConfigFiles` rewrites both server and client files atomically, so reruns are safe

- **SDK split — `wgbooster` / `wiresock-client` reference + Secure Connect 3.x new arch**
  - **SDK Overview page (docs/sdk-overview.html) — two tunnel modes exposed via `wgbooster` C API:**
    - `wgb_*` — single-tunnel / NAT mode (basic)
    - `wgbp_*` — dual-tunnel / tunnel-adapter mode (enhanced routing & filtering) — name from service header `wgb` vs `wgbp`
    - Handle create: `wgb_get_handle[_ex]` / `wgbp_get_handle[_ex]` — `_ex` variants take extended structs + callbacks
    - Tunnel create: `wgb_create_tunnel_from_file[_w]` / `wgbp_create_tunnel_from_file[_w]` or `wgb_create_tunnel[_ex]` from in-memory `wgb_interface_ex`, `wgb_extra_ex`
    - Lifecycle: `wgb_start_tunnel` / `wgb_stop_tunnel` / `wgb_drop_tunnel` / `wgb_release_handle`
    - State: `wgb_get_tunnel_state`, `wgb_get_tunnel_active`, statistics, etc.
  - **Notable capabilities inside `wgbooster.h` (non-exhaustive from docs):**
    - `allowed_apps` / `disallowed_apps` (in `wgb_extra_ex`) — drives split tunneling at driver level
    - `ignored_ips` (in `wgb_extra[_ex]`) — `DisallowedIPs` backing
    - `socks5` struct (`address, username, password, allTraffic`) — SOCKS5 bridge
    - `pre_up/post_up/pre_down/post_down` + `ScriptExecTimeout` + `WIRESOCK_TUNNEL_NAME` env — script hooks
    - `wgb_set_network_lock_mode` / `wgb_get_network_lock_mode` + recovery `wg_is_network_lock_active` / `wg_reset_network_lock` — KillSwitch
    - `wgb_drop_all_tcp_sockets` — TCP termination on connect
  - **drivers:** shipped as `.sys/.inf/.cat` plus helper exes that `install/start/stop` the LWF; SDK notes *“Administrator privileges may be required”* for driver install and service start
  - **wiresock-client reference:** `wiresock-client.exe` CLI built atop `wgbooster` — demonstrates `run` vs `install` vs `import` (DPAPI `.dpapi` encrypted store) vs `reset-network-lock` — source not public but header-referenced
  - **Secure Connect 3.x new architecture (from release notes):**
    - Split into **dedicated isolated service layer** (privileged, hosts `wgbooster`/driver) + **UI client** (unprivileged, WPF, gRPC over named pipe to service)
    - Benefit: UI can be closed/killed, tunnel stays; start before logon; Virtual Adapter + TCP termination no longer need Admin
    - Evidence in fixes: `Prevented ThreadPool starvation caused by blocking operations in gRPC named pipe handling` (3.4.8.1), `Fixed WPF render thread crash UCEERR_RENDERTHREADFAILURE` — confirms WPF + gRPC pipe split

- **WireSockUI legacy — deprecated but instructive**
  - `github.com/wiresock/WireSockUI` — community WPF GUI for old `wiresock-client` application mode; now archived notice: *“Planned Archival, recommend transitioning to WireSock Secure Connect”*
  - Features it wrapped: easy setup, single-click tunnel toggle, log view, `Process` button to pick `AllowedApps` — all subsumed into Secure Connect’s `wiresock-connect-cli` + new GUI

---

## 4. Split Tunneling — Per-App, Per-IP, Per-Domain, WFP/NDIS Mechanics

- **Mental model — traffic is steered per-packet at NDIS, not by routing table**
  - Classic split: `AllowedIPs = 10.0.0.0/8, 192.168.0.0/16` routes only those subnets via TUN; WireSock keeps that but adds *who* axis
  - WireSock’s NDIS LWF sees every outbound packet *with owning PID* (via `FWPS`/`ALE`-style PID tagging or NDIS metadata) → consults allowed/disallowed sets → either divert into BoringTun WG stack or `pass` to original NIC
  - Result: two orthogonal filters that compose; docs stress `AND` semantics — see “Using AllowedIPs and AllowedApps” page
  - **Important clarification:** despite marketing mention of WFP on gateway page (WinpkFilter), client split uses **NDIS LWF** + NDISAPI static filters (`driver.NewStaticFilters`) — forum: *Wiresock is NDIS LightWeight Filter, not WFP* — the WFP-like PID lookup is at NDIS layer, not WFP callout driver

- **Per-app tunneling — `AllowedApps` / `DisallowedApps` / `Tunneled applications` / `Non-tunneled applications`**
  - **Synonyms:** INI `AllowedApps`/`DisallowedApps` == GUI `Tunneled apps`/`Non-tunneled apps` == SDK `allowed_apps`/`disallowed_apps` — same driver field, different surfaces
  - **Section:** `[Peer]` (per-peer, so different peers can have different app sets) — not `[Interface]` (except junk/masking globals)
  - **Syntax variants:**
    - Bare process name: `AllowedApps = chrome, msoffice, firefox` — match any `chrome.exe`, `msoffice*`, case-insensitive, `.exe` optional; supports wildcards like `ch*` (docs example)
    - Full path: `C:\Program Files (x86)\Google\Chrome\Application\chrome.exe` — exact binary match
    - Folder: `C:\Program Files\` — trailing slash/backslash triggers *directory mode*: all exes under that folder are included/excluded implicitly — convenient for suites
    - Separator: comma `,` — no quotes needed unless path contains comma; spaces trimmed
    - **Compatibility prefix:** `#@ws:AllowedApps = ...` — parsed by WireSock, ignored as comment by vanilla clients
  - **Evaluation order (from Network Settings page):**
    - `1` If both lists empty → all processes **tunneled** (full-tunnel default)
    - `2` If PID matches `AllowedApps` → **tunneled** (allow wins)
    - `3` Else if matches `DisallowedApps` → **excluded** (blocked from tunnel)
    - `4` Else no explicit match →
      - `a` `AllowedApps` empty + `DisallowedApps` has entries → **tunneled** (deny-list mode: everything except denies)
      - `b` `DisallowedApps` empty + `AllowedApps` has entries → **not tunneled** (allow-list mode: only allows get tunnel)
      - `c` Both defined → **not tunneled** unless explicitly in allows (allow-list strict)
    - Tie-break: `AllowedApps` prioritized over `DisallowedApps` when both list same exe (docs: *“If both specified, AllowedApps is prioritized and evaluated first”*)
  - **Non-ASCII support:** Gateway 1.1.4 + client 2.4.x fixed non-ASCII paths in `AllowedApps/DisallowedApps` — needed for localized Program Files, e.g., `C:\プログラム\…`
  - **Script interaction:** `PreUp/PostUp/PreDown/PostDown` run before/after steer is programmed, with `ScriptExecTimeout` — useful to `taskkill` conflicting apps or add firewall rules
  - **Scope caveat — user vs system:**
    - `wiresock-client run` (application mode): only tunnels processes of *current logged-in user*; system services/other users bypass — by design, avoids privilege escalation
    - `wiresock-client install` (service mode) or Secure Connect service layer: system-wide — can steer any PID, including SYSTEM/explorer/other users
    - GitHub issue #93 exposes pitfall: user set `AllowedApps = msedge` in service mode yet `curl` still tunneled — because DNS requests outside Edge were still diverted (see §10 DNS) and global `AllowedIPs=0.0.0.0/0` + empty app filter in *global* network settings overrode profile — fix is to put app list in both profile *and* global or enable `Override profile settings with global ones` correctly

- **Per-IP tunneling — `AllowedIPs` / `DisallowedIPs` / `Tunneled networks` / `Non-tunneled networks` + `Bypass LAN`**
  - **WireGuard native `AllowedIPs`:** routing + crypto ACL — if `0.0.0.0/0, ::/0` → all destinations via WG; if `10.8.0.0/24` → only that subnet via WG (split by destination)
  - **WireSock extension `DisallowedIPs`:** comma list of `IP` or `CIDR` to *exclude* from WG even when covered by `AllowedIPs` — inverse split (tunnel all except)
    - Example from docs: `DisallowedIPs = 192.168.1.0/24, 1.1.1.1` keeps local LAN and Cloudflare direct while everything else goes via WG
    - With `AllowedApps` present, `DisallowedIPs` applies only to those allowed apps’ traffic — AND logic again
    - Ordering tip from issue #97: user put `DisallowedIPs *before* AllowedIPs` to stop WireSockUI blocking LAN — driver processes ignore order but GUI parser in 2.2.x had ordering bug; fixed post-2.4.9.1
  - **GUI labels:** `Tunneled networks/addresses` (required, default `0.0.0.0/0, ::/0` — cannot be empty) + `Non-tunneled networks/addresses` (optional) — same as INI but per-profile vs global
  - **`Bypass LAN Traffic` toggle:** one-click equivalent to `DisallowedIPs = 192.168.0.0/16, 10.0.0.0/8, 172.16.0.0/12, 224.0.0.0/4, 169.254.0.0/16` (exact LAN/multicast/link-local set not enumerated in docs but behavior is standard) — can be global or per-profile, profile wins if explicitly set
  - **AND composition example (docs):**
    - `AllowedIPs = 0.0.0.0/0` + `AllowedApps = chrome` → all Chrome traffic tunneled, rest direct — pure app split
    - `AllowedIPs = 1.1.1.1/32` + `AllowedApps = chrome, firefox` → only Chrome/Firefox → Cloudflare via WG, other apps to CF direct, Chrome to other IPs direct — narrowest split, useful for banking-site-only tunnel
  - **When AND hurts:** users expect `AllowedApps = chrome` to tunnel *all* Chrome IPs even with restrictive `AllowedIPs` — docs warn *“avoid restrictive AllowedIPs if you want all traffic from selected apps through tunnel”* — common misconfig in support threads

- **Per-domain — upcoming, not yet stable (roadmap)**
  - Secure Connect homepage lists **Domain-Based Routing** as *“Coming soon … Route traffic to specific domains through VPN matched via DNS, while leaving rest direct — perfect for banking/corporate portals”*
  - Also lists **Per-App DSCP Marking** (tag DSCP per exe) and **DNS Search Suffixes** (like official WG `DNS = 10.0.0.53` + search `office`) — both upcoming
  - **Current workaround for domain split:** use `DisallowedIPs` + external resolver trick — add domain’s IPs manually, or run local PAC/DNS proxy that returns `DisallowedIPs` entries, or use ProxiFyre tunneled via SOCKS5 per domain (not native)
  - **How it will likely work:** NDIS sniffer + DNS cache (`dnstrace` example in ndisapi shows DNS decode) → build domain→IP map → program `DisallowedIPs` effectively dynamic — pattern seen in `sni_inspector`/`dnstrace` samples

- **Global vs per-profile split — `Network Settings > Apply split tunneling to all profiles`**
  - Two tiers:
    - **Per-profile** (on Connection Profiles edit): `Tunneled apps/networks` etc. inside each `.conf`
    - **Global** (Preferences → Network): `Apply split tunneling to all profiles` checkbox + `Override profile settings with global ones` toggle
  - **Fallback rule:** profile is considered *“no split config”* when *all* of: `Tunneled apps` empty AND `Non-tunneled apps` empty AND `Non-tunneled networks` empty AND `Tunneled networks` empty/default `0.0.0.0/0` → then global settings apply
  - **No merge:** *“Profile and global Split-tunneling settings are not merged: no AND/OR between them”* — one wins, not union; override switch forces global always
  - **Bug fix 3.5.10.1:** *“Fixed global split tunneling settings not being applied to a profile that has no split tunneling rules of its own (with override disabled)”* — proves prior global fallback was broken

- **Implementation excerpt — how the steer is programmed**
  - SDK’s `wgb_extra_ex` marshals GUI lists into driver static filters:
    - `api.GetTcpipBoundAdaptersInfo()` → enumerate bound NICs
    - `driver.NewStaticFilters(api, true, true)` → create NDISAPI static filter table
    - `AddFilterBack(&driver.Filter{ AdapterHandle, Action: Pass/Redirect, SourceAddress, DestAddress, ProcessId/Name })` → per-app/per-IP rule compiled to NDIS LWF BPF-like table
    - `NewQueuedMultiInterfacePacketFilter(ctx, api, adapters, inCb, outCb)` → queued callback that does `BoringTun.Encrypt(packet)` if matched else `ForwardOriginal`
  - Performance note: NDIS LWF runs below TCP/IP, so UDP/TCP checksum offload still works; `HandleTcpMss` etc. examples show MSS clamping inside filter to avoid fragmentation when WG overhead shrinks MTU (WireSock MTU defaults to `1420` like WG, but Virtual Adapter mode sets per-adapter MTU via `Wintun`-like path)

---

## 5. TUN — Virtual Adapter vs Transparent Proxy vs Gateway Mode

- **Two client TUN philosophies — Transparent (default) vs Virtual Adapter (`-lac`)**
  - **Transparent Mode — no adapter, routing tables untouched**
    - What: NDIS LWF intercepts at `NDIS_PACKET_TYPE_PROMISCUOUS` level, diverts matched packets into userspace WG encryptor, injects ciphertext via original NIC’s UDP socket
    - How: no Windows “WireSock Virtual Adapter” appears in `ncpa.cpl`/`ipconfig`; existing Ethernet/Wi-Fi adapter keeps IP; `route print` unchanged — stealthy, minimal side-effects
    - Pros:
      - Lightweight — ~10 MB RAM (Secure Connect service layer measured, per homepage “minimal footprint under 10 MB” for CLI SDK)
      - No routing churn — avoids conflicts with Hyper-V, Docker NAT, corporate VPN route metrics
      - “Stealthy & Efficient” in docs comparison table
      - Works without admin in Secure Connect 3.x (service layer already privileged, UI just gRPCs)
    - Cons:
      - App compatibility: some apps expect TUN interface index for binding (e.g., qBittorrent “bind to interface `wiresock`”); must use folder/exe split instead of interface bind
      - Debugging harder: `ping` via WG is encapsulated, not via adapter IP, so traceroute confusing
    - Performance: benchmark shows transparent slightly faster than virtual-adapter on 10Gb test — fewer NDIS hops

  - **Virtual Adapter Mode — dedicated `Wiresock Virtual Adapter` (`-lac`)**
    - What: creates a classic TUN interface (like Wintun) with display name `Wiresock Virtual Adapter` (or `WiresockPro Virtual Adapter` in Pro) — assigns `Address = 10.66.66.2/32` from `[Interface]`, sets `DNS`, sets routes per `AllowedIPs`
    - How invoked: CLI `wiresock-client run -config X.conf -lac` or `install -lac`; GUI toggle “Use virtual adapter mode” (per-profile or global, profile wins); SDK `wgbp_*` dual-tunnel APIs (`wgbp_create_tunnel_from_file`); `LUID`-based route programming (release notes mention `LUID-based network lock identification` fix)
    - Pros:
      - Better compatibility — apps/tools that enumerate adapters see WG as real NIC; `ping`/`tracert` work as normal routed traffic; some enterprise firewalls whitelist adapter names
      - Stability/isolation — routing table explicitly scoped, less interference from ISP gateway changes; docs: *“Isolates VPN traffic, minimizing interference”*
      - Required for some ICS/hotspot bridging — Windows Mobile Hotspot shares via adapter, not transparent packet pump
    - Cons:
      - Touches global routing table — can clash with existing VPNs (Cisco AnyConnect etc.)
      - Slightly higher resource (extra adapter object, extra NDIS binding)
      - Needs driver install (`.sys/.inf`) — though 3.x no longer needs Admin for toggle, driver still pre-installed by MSI
    - **Setup detail from CLI docs:** installing as service with adapter: `wiresock-client.exe install -start-type 2 -config "C:\path\to\config.conf" -log-level none -lac` — note `-lac` is the only difference vs transparent
    - **Troubleshooting 2.4.x:** watchdog restarts when adapter missing (`Failed to assign DNS to WireSock virtual adapter!`, `WireSock virtual adapter is not available!`) — fixed by adding `-lac` after WireSockUI created adapter with wrong ACL; registry red herring
    - **Comparison table (docs):**

      | Feature | Virtual Adapter | Transparent |
      |---------|-----------------|-------------|
      | Uses Virtual Adapter | ✅ Yes | ❌ No |
      | Traffic Isolation | ✅ High | ✅ High |
      | App Compatibility | ✅ Better | ⚠️ May interfere with some apps |
      | Routing Table Changes | ✅ Yes | ❌ No |
      | Stealth & Perf | ✅ High | ✅ High |

- **KillSwitch / Network Lock — `enabled` / `disabled` (or `on`/`off`) on either mode**
  - **Purpose:** block *all* non-WG traffic if handshake fails — prevents leak when WG endpoint unreachable
  - **CLI:** `-network-lock enabled` on `run/install`; `wiresock-connect-cli` `connect myProfile -network-lock on`; SDK `wgb_set_network_lock_mode`
  - **Driver mechanic:** installs NDIS static deny-all filters with higher priority than allow rules; only WG UDP `Endpoint` + DNS + DHCP survive
  - **Recovery:** if app crashes with lock on, driver stays locked → `wiresock-client.exe reset-network-lock` or `wiresock-connect-cli reset-network-lock` (requires Admin) or SDK `wg_reset_network_lock()` after `wg_is_network_lock_active()` true — documented as crash helper
  - **Stability fixes:** `3.5.10.x` fixed deadlock during teardown; 3.4.5.1 fixed LUID-based identification when adapter transiently down — confirms lock binds to LUID not just IP

- **TCP Socket Termination — `Terminate TCP connections on connect`**
  - **What:** on tunnel up, closes existing TCP sockets that *should* now be tunneled per profile/global rules — forces apps to reconnect through WG instead of staying on pre-VPN socket (avoids 5-min TCP persist leak)
  - **Filtering nuance (2.4.9.1):** previously filtered only by app name; now also checks `network type (tunneled/non-tunneled)` + `local connections` — only sockets whose dst IP is in `Tunneled networks` and whose app is in `Tunneled apps` are killed
  - **Toggle:** GUI `Network Settings > Terminate TCP connections on connect`, per-profile override; CLI via `wiresock-connect-cli -lac` still respects (adapter vs transparent doesn’t matter — it’s socket table walk via `tcpip.sys` handles)

- **DNS handling — anti-leak, AdGuard quirk, search suffixes upcoming**
  - **Interface DNS:** `[Interface] DNS = 94.140.14.14, 94.140.15.15` (AdGuard) or `10.0.0.53` corporate — WireSock programs DNS onto virtual adapter (virtual mode) or hooks DNS UDP 53 via NDIS filter (transparent)
  - **Leak risk noted in issues:** transparent + `AllowedApps=msedge` still tunneled system DNS via WG because DNS service (svchost) not in allows but DNS UDP to `94.140.x.x` was captured via `AllowedIPs` — fix is to include DNS exe or set `DisallowedIPs` for local resolver
  - **AdGuard Home bug:** docs page `DNS Issues When Using AdGuard Home` — AdGuard’s DNS-intercept clashes with WinpkFilter’s; need to exclude `AdGuard.exe`/`AdGuardSvc.exe` from tunnel or set AdGuard to not filter WireSock adapter
  - **Search suffixes (coming soon):** like official WG `DNS = example.com` search list — listed on homepage roadmap as “DNS Search Suffixes — so `printer.office` resolves when connected”

- **Gateway mode for LAN sharing — `wiresock-service` proxy vs NAT, the server-side TUN**
  - **Problem it solves:** Windows `wireguard.exe` can act as client but not as stable gateway (no route for clients’ egress, ICS flaky). Gateway service provides that egress path.
  - **Wire side:** clients connect via WireGuard to Windows host’s `wiresock` interface (name configurable via `-interface wiresock` — default filtering interface). The service taps that interface at NDIS.
  - **Proxy mode (default) — transparent TCP/UDP proxy:**
    - Filters `wiresock` interface packets, spins up per-connection userspace proxies (sockets) that `connect()` to target using host’s routing table (respecting host HTTP/SOCKS5 proxy env)
    - Egress IP = host’s public IP (or host’s proxy egress) — simple, no route injection, no ICS DHCP
    - Limitations: `TCP and UDP only — no ICMP` → clients’ `ping 8.8.8.8` times out; MTU clamped via filter; single-threaded proxy may cap 10Gb but fine for home
    - Use-case: home LAN share where you just need browser/UDP via home IP; easiest, no subnet planning
  - **NAT mode (`-mode nat`) — Internet Gateway clone:**
    - Implements full NAT (like ICS but using WinpkFilter NAT table) — rewrites IP headers, checksum, port map, routes back
    - Supports ICMP echo (ping) because it NATs raw IP, not just TCP/UDP
    - Behaves like `Windows Internet Connection Sharing` but more stable and without ICS’s `192.168.137.1` forced subnet; you define client subnet via `[Interface] Address = 10.66.66.0/24` and `wg-quick-config`’s `10.8.0.x` pool
    - Switching: `wiresock-service uninstall && wiresock-service install -start-type 2 -mode nat -interface wiresock -dns "4.4.4.4,8.8.4.4" -log-level none && sc start wiresock-service` (docs combined example)
  - **DNS inside gateway:** same `-dns` logic — client DNS UDP 53 intercepted on `wiresock` iface, forwarded to host’s resolvers or specified ones, answers proxied back — so client can use `10.66.66.1` as DNS or `8.8.8.8` transparently
  - **Hotspot angle:** homepage notes *“Windows 10 Mobile Hotspot Compatibility — extend secure connectivity to devices connected via Mobile Hotspot”* — gateway proxy mode works with hotspot because hotspot’s NAT is separate; transparent mode client alone also compatible where official WG fails

---

## 6. Config Format — WireGuard INI + WireSock Extensions

- **Base = standard WireGuard INI — fully compatible**
  - File: `.conf` UTF-8, INI-ish, two primary sections: `[Interface]` and one or more `[Peer]`
  - Keys inside `[Interface]` (standard):
    - `PrivateKey = <base64 32-byte Curve25519>`
    - `Address = 10.66.66.2/32, fd42:42:42::2/128` — assigned to TUN (Virtual Adapter mode) or used for routing calc (transparent)
    - `DNS = 94.140.14.14, 94.140.15.15` or `10.0.0.1` — pushed to adapter/filter
    - `MTU = 1420` — defaults to 1420; gateway may override via MSS clamp
    - `ListenPort` — optional, for client usually random; server fixed 51820 via `wg-quick-config` random pick
    - `PreUp/PostUp/PreDown/PostDown = <command>` — script hooks (added in Gateway 1.1.4, supported on client too); `%WIRESOCK_TUNNEL_NAME%` env exposes tunnel/adapter name
    - `ScriptExecTimeout = <secs>` — max script runtime
  - Keys inside `[Peer]` (standard):
    - `PublicKey = <base64>`
    - `PresharedKey = <base64>` — optional
    - `AllowedIPs = 0.0.0.0/0, ::/0` — routing + ACL
    - `Endpoint = vpn.example.com:51820` — host:port UDP; can be IP or hostname; supports dynamic DNS — DPI note: Endpoint DNS lookup may leak if not via tunnel (use SOCKS5 to hide)
    - `PersistentKeepalive = 25` — seconds, for clients behind NAT (gateway clients should set to 25)
  - **Sample bare client (from docs):**

    ```ini
    [Interface]
    PrivateKey = [Your Private Key Here]
    Address = 10.66.66.2/32, fd42:42:42::2/128
    DNS = 94.140.14.14, 94.140.15.15
    MTU = 1420

    [Peer]
    PublicKey = [Peer Public Key Here]
    AllowedIPs = 0.0.0.0/0, ::/0
    Endpoint = [VPN Endpoint Here]:51820
    ```

- **WireSock extensions — live inside same file, scoped to where they matter**
  - **Compatibility prefix `#@ws:` — critical for portability**
    - Prefixing makes line a comment to vanilla parsers but WireSock still parses — e.g., `#@ws:AllowedApps = chrome`
    - Alternative without prefix `AllowedApps = ...` works only in WireSock — breaks import on other clients
    - Recommendation from docs: *always* use `#@ws:` for extensions if file ever leaves WireSock
  - **Per-peer extensions in `[Peer]` (split + proxy):**

    ```ini
    # [Peer] WireSock extensions
    #@ws:AllowedApps = chrome, msoffice
    #@ws:DisallowedApps = Discord
    #@ws:DisallowedIPs = 192.168.1.0/24
    #@ws:Socks5Proxy = socks5.sshvpn.me:1080
    #@ws:Socks5ProxyUsername = myusername
    #@ws:Socks5ProxyPassword = mypassword
    #@ws:Socks5ProxyAllTraffic = true
    ```

    - `AllowedApps` (optional): comma list processes/paths/folders allowed — see §4
    - `DisallowedApps` (optional): deny list — evaluated after allows
    - `DisallowedIPs` (optional): comma IPs/CIDRs excluded — e.g., `192.168.1.0/24, 1.1.1.1`
    - `Socks5Proxy` (optional): `host:port` — wraps WG UDP via SOCKS5 UDP ASSOCIATE
    - `Socks5ProxyUsername/Password` (optional): auth
    - `Socks5ProxyAllTraffic` (optional): `true` → wrap all WG UDP, else handshake only
  - **Per-interface extensions in `[Interface]` (obfuscation):**

    ```ini
    [Interface]
    PrivateKey = ...
    # Amnezia WG extension / Junk / Masking
    Jc = 4
    Jmin = 50
    Jmax = 1000
    Jd = 0
    S1 = 345
    S2 = 678
    H1 = 000111222
    H2 = 4445556666
    H3 = 777888999
    H4 = 1112223333
    # Protocol masking
    Id = somemaketplace.net
    Ip = QUIC
    Ib = cURL
    ```

    - `Jc` (0..200, default 3): number junk packets before handshake — 0 disables, 3-10 recommended
    - `Jmin`/`Jmax` (0..1280): junk size bounds — typical 50/1000 — warning: `Jmax >= system MTU` may fragment and look suspicious
    - `Jd` (0..200 ms, default 0): delay between junk packets — 0 = burst
    - `S1`/`S2` (0..∞): Init/Response junk size — random bytes prepended to handshake — 0 = no prepend; docs list example 345/678; amneziawg-install generates 15-150 constrained `S1+56 != S2`
    - `H1`/`H2`/`H3`/`H4` (uint32 1..4294967295): magic headers replacing message types 1..4 — must be unique, non-overlapping ranges, and match server; `H1=1 H2=2 H3=3 H4=4` = vanilla WG types
    - `Id` (domain): SNI-like domain for QUIC/DNS masking — pick popular regional domain (e.g., e-commerce) for plausible traffic
    - `Ip` (protocol): `QUIC`|`DNS` (+ gateway proxy’s STUN/SIP but not in client INI)
    - `Ib` (browser): `Chrome`|`Firefox`|`cURL` — fingerprint to mimic, only with `Ip=QUIC`
  - **Global network settings vs per-profile — not in INI but in JSON/registry:**
    - INI holds per-peer/per-interface; Secure Connect stores global split `Apply split tunneling to all profiles`, `Bypass LAN`, `Virtual adapter mode` global, `KillSwitch` global, `DPI global override` in app settings (registry `%APPDATA%\WireSock Secure Connect\settings.json` or `config.json` under `%ALLUSERSPROFILE%\NT KERNEL\...` for service)
    - `wg-quick-config` stores gateway pool in `%ALLUSERSPROFILE%\NT KERNEL\WireSock VPN Gateway\config.json` — JSON with `Clients[]`, `Endpoint`, `Port`, `PrivateKey`, `AddressPool` — decoupled from INI

- **JSON alternative?**
  - No JSON *tunnel config* — INI is canonical; JSON only for `wg-quick-config` state and Secure Connect profile import/export metadata
  - SDK’s `wgb_create_tunnel_ex` accepts in-memory structs `wgb_interface_ex`/`wgb_extra_ex` — JSON-wrappers are user-built via SDK integration, not standard

- **Profile text mode in GUI**
  - Secure Connect 3.x GUI has two edit modes: wizard (forms for keys, AllowedApps picker, DPI toggles) and text mode (direct INI editor) — text mode validates keys live: unknown params highlighted red, illegal `Jc>200` etc. block save
  - Import path: `wiresock-connect-cli import /path/to/profile.conf` derives profile name from filename (without `.conf`), refuses to overwrite existing name — must `delete` first; export via `export myProfile myProfile.conf` refuses to overwrite target file (must delete file first)

---

## 7. Platforms — Windows Only Matrix

- **Windows-only — by design, not by accident**
  - All drivers, NDISAPI, WinpkFilter, BoringTun patch, `wiresock-service`, Secure Connect GUI/CLI are Windows PE binaries (`.sys`, `.dll`, `.exe`, `.msi`)
  - No WSL/Linux/macOS build; homepage/docs never list Linux — “via Windows 10 Mobile Hotspot” is nearest cross-platform hint (hotspot *client* can be any OS)
  - Reason: NDIS LWF is Windows NDIS 6.x API — no equivalent on Linux (would be `netfilter`), so port would be rewrite

- **Supported Windows matrix (client 3.4.8.1 / gateway docs converge):**
  - **Fully supported (tested):**
    - Windows 11 (21H2→24H2) x64, x86, ARM64 — Secure Connect, gateway, SDK all publish ARM64 variant (`.msi`/`.dll` ARM64)
    - Windows 10 (1809→22H2) x64, x86, ARM64 — same
    - Windows Server 2012/2016/2019/2022/2025 x64 — gateway quick-start for Server Core explicitly lists Server Core, gateway is desktop + server (MSI `/qn` silent)
  - **With limitations (docs phrase):**
    - Windows 8.1 x64/x86 — works but UWP isolation less, .NET 10 Desktop Runtime may need manual install, some Wintun paths differ
    - Windows 7 SP1 x64/x86 — works via legacy driver path (`Windows Packet Filter for Windows 7 and later` driver), but TLS 1.2, SHA-2 Authenticode, and driver signing quirks; release notes mention `Improved stability of Windows 7/8 support` in 3.4.5.1
  - **Legacy NDIS builds:**
    - `ndisapi` still has `ndisapi.vc6` (Visual C++ 6.0, Windows 95/NT4+) and `ndisapi.vs2012` (XP/2003) — kept for industrial/embedded Windows, not relevant to Secure Connect but proves NDIS range
    - VPNSDK’s `.sys` ships separate `Windows 7 and later drivers` vs older — installer picks correct

- **Architectures published:**
  - **Client (Secure Connect 3.4.8.1):** `windows_x64` (15.84 MB, SHA256 `064E775D362ABBA7F...`), `windows_x32` (15.08 MB), `windows_arm64` (15.04 MB) — same version string, same MSI logic
  - **Gateway:** `wiresock-gateway.msi` x64/x86/ARM64 via `sdc_download` key URLs (keys: `bekfpuv…` for x64, `hyilnmw…` for x86, `7m03u7c…` for ARM64) — Chocolatey `choco install wiresockvpngateway` wraps same MSIs
  - **SDK:** `wiresock-sdk` separate product page `wiresock.net/wiresock-sdk` with matching x64/x86/ARM64 zips containing `wgbooster.dll/.lib`, headers, `wiresock-client.exe`, driver `.sys`

- **Prerequisites — .NET Desktop Runtime 10**
  - Secure Connect GUI (WPF) requires **.NET Desktop Runtime 10** (`dotnet.microsoft.com/download/dotnet/10.0`) — MSI auto-downloads if internet available, but offline installs must pre-install
  - Earlier 2.x required .NET 9.0.5 (see 2.4.9.1 *Updated .NET to 9.0.5*); 3.4.6.1 *Updated bundled .NET to 10.0.7*; 3.4.5.1 to 10.0.6 — tracks LTS
  - CLI-only `wiresock-client.exe` from SDK (~4.5 MB, <10 MB RAM) does *not* need .NET — useful on Server Core

- **Not supported — clarifications that avoid mis-triage:**
  - No Windows XP/2003 for Secure Connect 3.x (NDISAPI samples retain VC6 examples for XP but product installers block)
  - No Windows Phone/Mobile (despite “Windows 10 Mobile Hotspot Compatibility” — that’s hotspot *host* feature, not client OS)
  - No ARM32 (only ARM64) — Surface Pro X etc. are ARM64
  - No “Linux via WSL inside Windows” — WSL2’s vEthernet is separate NDIS adapter; WireSock can tunnel WSL2 if WSL’s `wslhost.exe`/`vmmem` not excluded, but not a Linux-native path

---

## 8. CLI, GUI, Secure Connect App, Service Lifecycle

- **Two CLIs — `wiresock-client.exe` (SDK/reference) vs `wiresock-connect-cli.exe` (Secure Connect 3.x) — don’t confuse**
  - **Legacy/reference — `wiresock-client.exe` (ships with SDK + old VPN Client):**

    ```text
    wiresock-client.exe run -config "C:\path\to\wg0.conf" -log-level info|debug|all|error -lac -network-lock enabled
    wiresock-client.exe install -start-type 2 -config "C:\path\to\wg0.conf" -log-level none [-lac] [-network-lock enabled] [-account User -password Pass] [-fallback-config "C:\backup.conf"]
    wiresock-client.exe uninstall
    wiresock-client.exe import "C:\wg0.conf" [-account User -password Pass]
    wiresock-client.exe reset-network-lock   (Admin)
    ```

    - `run` = foreground process, inherits console, tunnels only current user’s PIDs (app mode)
    - `install` = Windows Service `wiresock-client-service` (or `wiresock-pro-client-service` in Pro) — auto-start 2, manual 3, disabled 4; runs as LocalSystem by default or specified account; full-system steer
    - `import` = DPAPI encrypts `.conf` → `.dpapi` under protected `%PROGRAMDATA%\NT KERNEL\...` — only service account can decrypt, avoids plaintext on disk
    - `-lac` = tunnel adapter mode (LAC = Local Adapter Controller); without = transparent
    - `-network-lock` = KillSwitch on/off
    - `sc start/stop wiresock-client-service` controls installed service; `wiresock-client.exe uninstall` or `sc delete` removes
  - **Modern — `wiresock-connect-cli.exe` (bundled with Secure Connect 3.x GUI, gRPC to service):**

    ```text
    wiresock-connect-cli.exe list
    wiresock-connect-cli.exe connect myProfile [-log-level info] [-lac] [-network-lock on] [-exit]
    wiresock-connect-cli.exe disconnect
    wiresock-connect-cli.exe status
    wiresock-connect-cli.exe import /path/to/profile.conf   (name from filename)
    wiresock-connect-cli.exe export myProfile myProfile.conf
    wiresock-connect-cli.exe delete myProfile
    wiresock-connect-cli.exe reset-network-lock
    ```

    - Lists profiles stored by GUI (same store as GUI, not separate INI folder)
    - `connect` attaches to service via gRPC named pipe, streams logs until Ctrl+C unless `-exit` (then service keeps tunnel after CLI exits)
    - `status` shows `NotConnected|Connecting|Connected|Disconnecting|Disconnected` + external address
    - `import`/`export`/`delete` manage that store — `export` refuses overwrite, `import` refuses duplicate name
    - Pro-only extras: `license activate/import` via same CLI (Professional builds)

- **GUI — WireSock Secure Connect (WPF, 3.x) vs WireSockUI (deprecated)**
  - **Secure Connect 3.x GUI (current):**
    - Main window: profile cards, connect/disconnect toggle, connection timer, logs pane (`view-logs.html`), theme (dark theme added 2.4.1.1, `Slovenian/Persian/Turkish` locales added incremental)
    - Profile wizard: `[Interface]` keys, `[Peer]` endpoints, split tunneling pickers (`Tunneled apps/networks` lists with Browse file / Browse folder / Pick running process buttons), DPI tab (`Junk Packets`, `Magic Headers`, `Protocol Masking`, `SOCKS5`), script hooks
    - Global Preferences → Network: `Bypass LAN`, `Virtual adapter mode` global, `KillSwitch`, `Terminate TCP`, `DPI global`, `Auto-reconnect`, `Connection timeout (Continuous Retry)`
    - Tray: `Minimize to tray`, `Auto-start on login` (Task Scheduler workaround for UAC, distinct from service before-logon), `Run elevated priority` toggle (2.4.16.1)
    - Feedback: `Send Feedback` uploads logs via `SendFeedback` API (docs `send-feedback.html`)
  - **WireSockUI (legacy, archive notice 2024):**
    - Lightweight tray app wrapping `wiresock-client run` — “Easy Setup, Connection Management, Logging & Status, Minimal Resource” — no longer maintained, README points to Secure Connect
    - If you find `WiresockUI/releases` (v1.24.1 last), treat as EOL — do not file new bugs there

- **Service lifecycle — before-logon vs autostart**
  - **Service mode (Secure Connect 3.x architecture):** service `Wiresock Secure Connect Service` (or `WiresockPro`) runs as `SYSTEM` at boot (`SERVICE_AUTO_START`); can establish tunnel *before user logon* — needed for kiosk/IoT
  - **Application mode:** UI/service `run` as logged-in user — tunnel only for that user; survives UI close in 3.x because service holds tunnel (previously UI death killed tunnel)
  - **Elevation notes:** 3.x virtual adapter + TCP termination *no longer require Admin* for UI toggle — service already privileged; only `reset-network-lock` still needs Admin (driver ioctl)
  - **Logging levels:** `error` → `info` → `debug` → `all` (pcap) — `all` writes `pcap` captures per `-log-level all` (NT Kernel forum: `stores traffic into pcap files which can be analyzed in Wireshark`) — handy for leak triage but privacy-sensitive

- **Gateway CLI — `wiresock-service` + `wg-quick-config` pair**
  - `wg-quick-config -add -start` — generate server+first peer+`config.json`, note UDP port, start WG tunnel (via `wireguard.exe`/`wiresock-client` underneath), print QR for phone
  - `wg-quick-config -add -restart` — add peer N, regenerate `clientN.conf`, restart tunnel, show QR
  - `wg-quick-config -qrcode 1` → `-qrcode N` — re-render QR without adding
  - `wg-quick-config -stop` / `-start` — stop/start tunnel without config change
  - `wiresock-service install -start-type 2 -mode nat -interface wiresock -dns "4.4.4.4,8.8.4.4" -log-level none` — gateway sharing engine (must follow tunnel start)
  - Combined flow from docs:

    ```powershell
    wiresock-service uninstall
    wiresock-service install -start-type 2 -mode nat -interface wiresock -dns "4.4.4.4,8.8.4.4" -log-level none
    sc start wiresock-service
    ```

---

## 9. Repository Stats, Install Docs, Package Overview

- **github.com/wiresock/wg-quick-config — open gateway helper**
  - Stats (2026-08-30 live fetch):
    - Stars `9`, Forks `1`, Watchers `2` (was 7/1/7 in earlier snapshot — slight drift), Issues `0`, PRs `0`, Activity sparse
    - License `AGPL-3.0` (copyleft, must publish modifications if hosted)
    - Languages `Go 100%` (Go 1.18 in `go.mod`), single contributor `wiresock`
    - Commits `7`, Default branch `master`, Created `2023-06-23`, Last push `2023-06-23` — stable/frozen, no recent changelog
    - Topics: `gateway`, `vpn`, `wireguard`, `wiresock`; Homepage `wiresock.net/wiresock-vpn-gateway/`
  - Install via Go: `go get github.com/wiresock/wg-quick-config` or `go install` then `%ALLUSERSPROFILE%` path; but recommended is MSI bundle (includes compiled exe)
  - Package consumers: Chocolatey `wiresockvpngateway` (wraps MSI), Docker-less — just Windows service pair

- **github.com/wiresock/ndisapi — NDISAPI user-mode library**
  - Stats: Stars `~527` (was 129 at one point), Forks `~104`, Issues `0`, PRs `1`, Commit history `132` — actively maintained (latest tagged `v3.6.2` 2025-10-23 — patch for driver signing cert + BSOD in Bluetooth on OID)
  - License MIT (README `MIT license` + `include` headers)
  - Components: `ndisapi.dll` (wrapper x86/x64/ARM64), `ndisapi.lib` static, `ndisapi.net` .NET C++/CLI, `examples/` — `listadapters`, `packetsniffer`, `passthru`, `packthru`, `filter`, `wwwcensor`, `gretunnel` (basic), `capture`, `dns_proxy`, `dnstrace`, `sni_inspector`, `socksify`, `udp2tcp`, `rebind` (advanced VS2022), `snat`, `lfnemu` (MFC), `ProxiFyre` (very advanced)
  - Home: `ntkernel.com/windows-packet-filter/` and `ntkernel.com/docs/windows-packet-filter-documentation/` — driver download MSIs `Windows.Packet.Filter.3.6.2.1.x64/x86/ARM64.msi`

- **github.com/wiresock/ndisapi-go — Go binding + `wiresock/boringtun` fork**
  - `ndisapi-go`: pure Go interface to driver, `go get github.com/wiresock/ndisapi-go`, example uses `NewNdisApi()`, `IsDriverLoaded()`, `GetTcpipBoundAdaptersInfo()`, `NewStaticFilters`, `NewQueuedMultiInterfacePacketFilter` with `FilterActionPass`
  - `wiresock/boringtun`: fork of Cloudflare BoringTun (Rust), patched with Amnezia `Jc/S1/H` logic — no separate star count in docs but visible at `github.com/wiresock/boringtun` (Wiresock org)
  - `wiresock/amneziawg-install`: fork of `RomikB/amneziawg-install` extended to generate `S3/S4/H-ranges` + `amneziawg-proxy.sh` Rust UDP obfuscation proxy (QUIC/DNS/STUN/SIP) — designed to pair with WireSock 3.5+ for bidirectional mimicry

- **WireSock org overview (github.com/wiresock):**
  - Repos: `wg-quick-config`, `ndisapi`, `ndisapi-go`, `boringtun`, `ProxiFyre` (proxifyre, advanced socksify evolution), `amneziawg-install`, `WireSockUI` (archived)
  - Social: `reddit.com/r/WireSock/`, `t.me/wiresock`, `discord.gg/hMNttJ7CMX`, `youtube.com/@WireSock` — support triage lives on NT Kernel forum `ntkernel.com/forums/topic/...` + Reddit/Telegram
  - WireSockUI archive notice: *“This repository is no longer actively maintained and will soon be archived. No further updates… transitioning to WireSock Secure Connect”* — do not target for contributions

- **Install docs — Secure Connect (client)**
  - **Winget (modern):** `winget install NTKERNEL.WireSockVPNClient` — pulls 3.4.8.1 MSI, handles upgrade, auto-installs .NET if internet
  - **Direct MSI:** `wiresock.net/wiresock-secure-connect/download` — three links with checksums: `x64 15.84 MB SHA256 064E775D…`, `x32 15.08 MB 53D174E3…`, `ARM64 15.04 MB 2FABE0F4…` (also `_api/download-release.php?product=wiresock-secure-connect&platform=...&version=3.4.8.1`)
  - **Steps from `how-to-setup.html`:** 1) ensure .NET Desktop Runtime 10 (manual fallback: `dotnet.microsoft.com/download/dotnet/10.0`), 2) run MSI, 3) wizard installs kernel modules then app, 4) import or create profile, 5) `Connect` — UI shows external address on success
  - **Silent/server:** extracted via `MsiExec.exe /i wiresock-secure-connect.msi /qn` — for RMM/MDM (Intune)
  - **Offline quirk:** if `TEMP/TMP` points to invalid path, 3.4.8.1 fix says startup fails — ensure env valid
  - **Beta channel:** `3.5.10.1` beta links on same download page (x64 `8D438975…`, ARM64 `D3587F…`) — introduces `Domain-Based Routing` preview + split global fix

- **Install docs — VPN Gateway**
  - **Chocolatey:** `choco install wiresockvpngateway` — idempotent
  - **PowerShell direct (from quick-start-server-core.html):**

    ```powershell
    # x64
    Invoke-WebRequest "https://www.wiresock.net/sdc_download/921/?key=bekfpuvidq5x8ofg2u74j2lqk8zy9y" -OutFile "wiresock-gateway.msi"
    # x86
    Invoke-WebRequest "https://www.wiresock.net/sdc_download/922/?key=hyilnmwdwh37yp3knckqrn5r53z081" -OutFile "wiresock-gateway.msi"
    # ARM64
    Invoke-WebRequest "https://www.wiresock.net/sdc_download/923/?key=7m03u7cp7axlt2jhf62bc186gnx0s3" -OutFile "wiresock-gateway.msi"
    MsiExec.exe /i wiresock-gateway.msi /qn
    wg-quick-config -add -start   # note UDP port
    # then choose gateway mode:
    wiresock-service install -start-type 2 -mode nat -interface wiresock -dns "4.4.4.4,8.8.4.4" -log-level none
    sc start wiresock-service
    ```

  - **Port forward:** gateway docs stress opening UDP port (shown by `wg-quick-config`) on router/VPS firewall — otherwise peers timeout; DDNS re-point if home IP dynamic
  - **Quick-start desktop vs server core:** desktop guide uses UI clicks; server core uses above PowerShell + `sc` only; both end with QR-code phone onboarding
  - **Uninstall:** `MsiExec.exe /x {ProductCode} /qn` or Add/Remove; `wiresock-service uninstall` leaves WireGuard config intact under `%ALLUSERSPROFILE%`

- **Package overview page (`documentation/wiresock-vpn-gateway/package-overview.html`) — the two-component model**
  - **Header:** *“Explore the Core Components of Your VPN Gateway — Package Contents: wiresock-service and wg-quick-config”*
  - **wiresock-service section:**
    - *“Versatile solution for effortless Internet and LAN connection sharing on Windows. Utilizes Windows Packet Filter driver to provide two main functionalities: Transparent TCP/UDP proxy (default) and NAT”*
    - Note: *“Proxy mode supports TCP and UDP, not ICMP — clients will not be able to use tools like ping”*
    - DNS section: *“By default forwards to your local DNS servers, speeding up browsing; specify via -dns; default fallback 8.8.8.8 and 1.1.1.1”*
  - **wg-quick-config section:**
    - *“Console-based utility for comprehensive management of WireGuard servers and clients. Enables: Generate configs, Manage tunnels (start/stop/restart), Add peers, Customize settings”*
    - *“Source code publicly available on GitHub for community review”* — points to `wg-quick-config` repo
    - Link to `Command Line Interface` page for full flag set
  - **CLI reference page (`documentation/wiresock-vpn-gateway/command-line-interface.html`) — full flag doc:**
    - `wiresock-service`: `install [options]` / `uninstall` / `run [options]`; `-start-type 2..4`, `-account`, `-password`, `-mode nat|proxy`, `-interface`, `-log-level none|info|debug|all`, `-dns "<servers>"` — with combined example
    - `wg-quick-config`: `-add`, `-start`, `-stop`, `-restart`, `-qrcode N` — with example `wg-quick-config -add -restart` (note hyphen vs doc’s en-dash)
  - **Download page (`wiresock-vpn-gateway/download/`):**
    - Chocolatey + manual links (same SDC URLs), available for Desktop/Server 7→11/2012→2022, plus release history box `v1.1.4` with `PreUp/PostUp/PreDown/PostDown + WIRESOCK_TUNNEL_NAME`, non-ASCII fix, `Socks5ProxyAllTraffic`

---

## 10. Performance, Security, DNS/Killswitch, Troubleshooting, Licensing

- **Performance — how WireSock claims to beat kernel WG**
  - **Benchmark rigs from wiresock.net “Performance” section:**
    - Old NUC `i3-3217U`, 4 TCP sessions via `iperf3` ×10 runs → WireSock transparent > WireGuardNT > wireguard-go/TunSafe
    - Xeon `E-2378G` + Broadcom `P210tep` 10Gb, 8 TCP sessions ×10 runs → both WireSock modes (transparent & virtual adapter 1.2.37) beat WireGuardNT 0.5.3 on download
  - **Why transparent can be faster than kernel:**
    - No route-table recompute on each AllowedIPs change → fewer `notifyIpInterfaceChange` storms
    - NDIS LWF sees packets before `tcpip.sys` routing — cheaper classify vs WFP ALE
    - BoringTun Rust crypto uses `ring`-like AES-NI/ChaCha fast paths + batching, similar to kernel but avoids `Wintun` ring copy in transparent (direct NDIS inject)
  - **Tuning knobs:**
    - Process priority boost (`2.4.16.1 Added ability to increase process priority, which helps on high CPU`) — sets `HIGH_PRIORITY_CLASS` for service
    - Hardware acceleration toggle (WPF `2.4.16.1`), Log level to `error` in prod (avoid `all` pcap overhead), `MTU 1420` standard
    - For gateway high-throughput, prefer `nat` mode + disable `Socks5ProxyAllTraffic` unless DPI needed

- **Security — crypto, DPI, network lock, TCP termination**
  - **Crypto unchanged:** Noise_IK + Curve25519 + ChaCha20Poly1305 + BLAKE2s; no custom KDF — AMNEZIA docs stress *“cryptographic core remains WireGuard — mechanism is header/padding obfuscation only”*
  - **DPI stack (client):**
    - Level 1 — `Jc/Jmin/Jmax/Jd` (junk) → good enough for standard WG, no server change
    - Level 2 — `Id/Ip/Ib` (protocol masking QUIC/DNS) → emulates browser, configurable globally or per-profile; since 3.4.5.1 QUIC profiles updated to Chrome 147/Firefox 149 fingerprints
    - Level 3 — `S1/S2(+S3/S4)/H1-H4` (magic headers) → strongest, requires AmneziaWG server with same values; `H` ranges `5..2147483647` must not overlap, distinct per peer
    - Level 4 — `Socks5Proxy/AllTraffic` → wraps WG UDP in SOCKS5 TCP/UDP associate — useful when entire UDP blocked or when Endpoints’ SNI fingerprinted
    - Server-side deep: `amneziawg-proxy` Rust fronting AmneziaWG rewrites `S` padding prefix to QUIC short header/DNS/STUN/SIP bytes — WireSock 3.5+ paired for bidirectional mimicry (proxy alone gives server→client mimicry)
  - **Network Lock (KillSwitch):**
    - On enable, driver installs “deny-all except WG Endpoint/DNS/DHCP” static filters — instant block on disconnect
    - Scope coverage: all adapters (LUID-based) — fix 3.4.5.1 corrected `network lock stability when adapter transiently down` and `LUID-based identification`
    - Recovery: `reset-network-lock` (Admin) — also SDK `wg_is_network_lock_active`/`wg_reset_network_lock` for custom apps that crash with lock held
  - **TCP termination:** as above — avoids stale non-VPN sockets persisting; now respects `tunneled networks` so only affected sockets die (prevents killing local SMB/printing sockets)
  - **DPAPI import:** `wiresock-client import` encrypts `.conf` → `.dpapi` via Windows DPAPI (per-account or LocalSystem) — protects private keys at rest on shared PCs

- **DNS — leak vectors and fixes**
  - **Virtual Adapter mode:** assigns `DNS` from `[Interface]` to adapter; Windows resolver uses adapter DNS for tunneled destinations per NRPT (Network Name Resolution Policy Table) — least leaky
  - **Transparent mode:** NDIS filter hooks DNS UDP 53 — captures DNS to `DNS=` servers via WG, but if `AllowedApps` excludes resolver process (`svchost/dns.exe`), system fallback may leak via direct NIC — must tunnel resolver or use `DisallowedIPs` to keep LAN DNS direct and WG DNS tunneled
  - **AdGuard Home clash:** `docs/guide/adguard-home-dns-issue.html` + `guide/drweb.html` note — AdGuard’s own WFP/NDIS driver competes; exclude `AdGuard.exe/AdGuardSvc.exe` or disable AdGuard’s “filter localhost” / “use hosts file”
  - **Upcoming:** `DNS Search Suffixes` — per client 3.x roadmap, will allow `printer.office` short-name resolve via WG DNS suffix list — parity with official WG client

- **Troubleshooting — common traps and fixes drawn from issues, forums, release notes**
  - **AllowedApps not restricting (issue #93):** all traffic tunneled despite `AllowedApps=msedge`
    - Root 1: `AllowedApps` placed in INI without `#@ws:` and parsed as ignored — use prefix; Root 2: global split settings empty → fallback not triggered (fixed 3.5.10.1); Root 3: DNS/svchost not in allows yet DNS via WG matches `AllowedIPs=0.0.0.0/0` AND → captured; Fix: add `svchost` exclusion via `DisallowedApps` or tighten `AllowedIPs` + `DisallowedIPs`
  - **LAN traffic blocked:** default `0.0.0.0/0` captures LAN; fix `DisallowedIPs` before `AllowedIPs` (issue #97) or toggle `Bypass LAN Traffic` global/per-profile
  - **Virtual adapter not available / watchdog restart loop (issue #97):**
    - Symptoms: `Failed to assign DNS to WireSock virtual adapter!`, `watchdog: Tunnel is not active… Schedule restart`
    - Cause: WireSockUI created adapter ACL for current user only; service running as LocalSystem can’t modify — need Admin prompt and `wiresock-client run -lac` as Admin first, or delete adapter via `Device Manager → Network adapters → Wiresock Virtual Adapter → Uninstall` then reinstall MSI
    - Fix in 3.4.8.1 hardened tunnel lifecycle to stop ThreadPool starvation on gRPC restart storms
  - **Network slowdown on 10Gb (`guide/network-slowdown.html`):** disable `Receive Segment Coalescing` / `Large Send Offload` tuning via PowerShell `Set-NetAdapterAdvancedProperty` — driver/MTU mismatch at 10Gb
  - **Surface 5G cellular (`guide/surface-5G-cellular.html`):** APN’s virtual WWAN adapter not enumerated by `GetTcpipBoundAdaptersInfo` early boot — workaround: delayed auto-connect `Automatic reconnect Continuous Retry`
  - **Dr.Web antivirus (`guide/drweb.html`):** browser not routed via WG — Dr.Web injects own WFP filter above WinpkFilter; exclude `drweb.exe`/`dwengine.exe` or add WFP weight registry
  - **Installer fails / .NET corrupted (`windows-installer-errors.html`, `installation-dotnet-runtime-issue.html`):** repair .NET Runtime, clear `%TEMP%`, ensure valid `TEMP/TMP` (3.4.8.1 fixed invalid TEMP crash), retry MSI with `msiexec /i wiresock-*.msi /l*v install.log` → check `wiresock-client-service` event viewer
  - **Crash sources fixed recently (3.4.8.1 / 3.4.6.1):** `WPF render thread UCEERR_RENDERTHREADFAILURE`, `InvalidOperationException on closing`, `ThreadPool starvation in gRPC named pipe`, `System.ServiceProcess.ServiceController missing on MSI upgrade`, `file/folder browse dialog Shell COM error`, `WindowsAPICodePack.Shell.dll missing` — if you still see these, upgrade beyond 3.4.6.1
  - **Pcap debugging:** run `wiresock-client run -config X.conf -log-level all` → dumps `%TEMP%\wiresock*.pcap` + `%TEMP%\filter*.pcap`; open in Wireshark, filter `wireguard` or `udp.port == 51820`; NT Kernel forum asks for these captures for leak triage — remember to redact `PrivateKey`

- **Licensing — free* asterisk decoded**
  - **Secure Connect / Gateway docs footer:** *“WireSock Secure Connect is free for personal (non-commercial), or educational (including non-profit) use. For commercial use, visit Licensing page or contact us”*
  - **Secure Connect Pro (`/wiresock-secure-connect/pro`):** seat-based commercial license, includes SDK (`wgbooster` + driver) redistribution rights, centralized control, predictable `Support & Updates` during active period, license activation via CLI `wiresock-connect-cli license …`
  - **Gateway:** same free* non-profit, commercial via contact — no per-seat since gateway is server side; contact for OEM embedding (e.g., white-label VPN for MSP)
  - **AGPL-3.0 on `wg-quick-config`:** if you modify and *host* the Go tool as network service, you must publish source; personal use/mod no publish needed; does NOT extend to `wgbooster`/driver (proprietary)
  - **Driver signing:** WinpkFilter/NDIS drivers are EV-signed by NT Kernel, WHQL-attested where required — 3.6.2 release note: re-signed due to expired cert that broke load on 3.6.1

- **Release history highlights — what changed beyond version bumps**
  - **3.4.8.1 (current stable 2026-08):** memory footprint cut via GC tuning, lifecycle hardening, ThreadPool gRPC fix, WPF render fix, TEMP invalid fix, Shell COM browse fixes, logger race fixes, license activation bug fix, installer rollback no longer rolls back entire setup on driver fail (partial install)
  - **3.4.5.1/3.4.4.1 (3.x debut):** new arch (service isolation, before-logon connect, UI non-admin), KillSwitch, global split, QUIC/DNS masking updated Chrome 147/Firefox 149, AmneziaWG 2.0 support, `I1-I5` silently ignored, CLI `connect/disconnect/import/export`, multi-line split strings, SHA-2 Authenticode only (SHA-1 removed), WDAC compatibility
  - **2.4.23.1→2.4.9.1 (2.x era):** `Bypass LAN`, per-profile Virtual Adapter, `#@ws:` prefix, `Socks5ProxyAllTraffic`, TCP termination with network filtering, Turkish localization, priority boost, hardware acceleration toggle, SOCKS5+WARP IPv6 fix
  - **Gateway 1.1.4:** `PreUp/PostUp/PreDown/PostDown` + `WIRESOCK_TUNNEL_NAME`, non-ASCII `AllowedApps`, `Socks5ProxyAllTraffic`
  - **Beta 3.5.10.1:** global split fallback fix, profile load crash → error message not app shutdown, missing Profiles folder → “profile not found” not internal server error

- **Ecosystem wrap — how pieces fit for a Windows shop**
  - **Personal user:** install Secure Connect MSI, winget, import Mullvad/IVPN WireGuard `.conf`, add `#@ws:AllowedApps = chrome` and `Jc=4` for DPI airports, `Bypass LAN` on
  - **Remote-work admin:** deploy Gateway MSI via Intune + `wg-quick-config -add -start` + `wiresock-service -mode nat` on office Windows host, distribute `clientN.conf` QRs to field laptops/phones
  - **Vendor embedding:** license Pro SDK, link `wgbooster.lib`, call `wgbp_get_handle_ex` + `wgbp_create_tunnel_from_file_w`, implement `log_printer` + `event_logger` to drive own brand UI and global split across fleet — see `sdk-installation.html` typical layout (drivers `.sys/.inf/.cat`, `wgbooster.dll/.lib`, `wgbooster.h`, `wiresock-client.exe` reference)
  - **Advanced obfuscation lab:** pair `wiresock/boringtun` fork + `amneziawg-install/amneziawg-proxy.sh` (Rust) on Linux server for QUIC/DNS/STUN/SIP front, WireSock 3.5+ client with matching `Jc/S1/H/Id/Ip/Ib` — strongest DPI evasion short of full Shadowsocks tunnel

---

## References & URLs (fetchable)

- WireSock home / Gateway / Secure Connect: `https://wiresock.net/`, `https://wiresock.net/wiresock-vpn-gateway/`, `https://wiresock.net/wiresock-secure-connect`
- Docs: `https://wiresock.net/documentation/wiresock-secure-connect/advanced-parameters.html`, `.../documentation/wiresock-secure-connect/virtual-adapter-mode.html`, `.../documentation/wiresock-vpn-gateway/package-overview.html`, `.../documentation/wiresock-vpn-gateway/command-line-interface.html`, `.../documentation/wiresock-secure-connect/wiresock-connect-cli.html`, `.../documentation/wiresock-secure-connect/network-settings.html`, `.../documentation/wiresock-secure-connect/connection-profiles.html`, `.../documentation/wiresock-secure-connect/sdk-overview.html`, `.../documentation/wiresock-secure-connect/sdk-installation.html`, `.../documentation/wiresock-secure-connect/releases/`
- Downloads: `https://wiresock.net/wiresock-secure-connect/download`, `https://wiresock.net/wiresock-vpn-gateway/download`, `https://wiresock.net/wiresock-sdk`
- GitHub: `https://github.com/wiresock/wg-quick-config`, `https://github.com/wiresock/ndisapi`, `https://github.com/wiresock/ndisapi-go`, `https://github.com/wiresock/boringtun`, `https://github.com/wiresock/amneziawg-install`, `https://github.com/wiresock/WireSockUI` (archived), `https://github.com/wiresock/proxifyre`
- Support: `https://www.ntkernel.com/windows-packet-filter/`, `https://www.ntkernel.com/forums/topic/can-i-select-the-default-interface-when-using-wiresock-vpn-client-on-win10/`, `https://reddit.com/r/WireSock/`, `https://t.me/wiresock`, `https://discord.gg/hMNttJ7CMX`

---

*File generated 2026-08-30 — verify driver versions via `https://github.com/wiresock/ndisapi/releases` and client checksums on wiresock.net download page before prod deploy; re-fetch if you need BoringTun patch diff or ndisapi-go API surface.*
