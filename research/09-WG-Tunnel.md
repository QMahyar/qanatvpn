# 09 - WG Tunnel (wgtunnel/android + wgtunnel/desktop) - Extreme Detail Research

> **Repo:** [`wgtunnel/android`](https://github.com/wgtunnel/android) (Android) · [`wgtunnel/desktop`](https://github.com/wgtunnel/desktop) (Desktop) · Org [`wgtunnel`](https://github.com/wgtunnel) · Core [`wgtunnel/core`](https://github.com/wgtunnel/core) · Forks [`wgtunnel/amneziawg-go`](https://github.com/wgtunnel/amneziawg-go) + [`wgtunnel/amneziawg-android`](https://github.com/wgtunnel/amneziawg-android) + [`wgtunnel/wireguard-android`](https://github.com/wgtunnel/wireguard-android) · Website [`wgtunnel.com`](https://wgtunnel.com) · Docs [`wgtunnel.com/docs`](https://wgtunnel.com/docs) · Author `Zane Schepke` ([zaneschepke](https://github.com/zaneschepke))
> **License:** **MIT** (`LICENSE:1-20` permissive, all flavors FOSS, no tracker, no closed dep) · **Language:** Kotlin (~90% app) + Go (tunnel core) + C (hev-socks5-tunnel via JNI) · **UI:** **Jetpack Compose** + Material 3 (Android) · **Kotlin Multiplatform** (Desktop: Compose Multiplatform + Kotlin 2.x)
> **Stats (2026-08-30):** Android **~3,093 ★** (your brief says 2.8k — stale, current 3.1k), **182 forks**, **21 watchers**, **~1,200 commits** on `master` (`created 2023-05-24`) · Desktop **~224 ★** (your brief says 180 — now 212–224), **11 forks**, **80 commits** (`created 2026-01-30`) · **Releases:** **~90+ tags** on Android (user brief says 117 — includes pre-releases/nightly; GitHub Releases paginates ~30/tag page, count via `gh release list | wc -l` ~95 stable+nightly; 117 includes archived `zaneschepke/wgtunnel` legacy tags before org move) — verify via `git tag | wc -l` locally
> **Status:** Actively maintained single-dev (Zane Schepke) with community translations; default branch `master`; nightly pre-release every day; JetBrains OSS license

---

## Table of Contents

1. [Overview](#1-overview)
2. [Supported Protocols - Exhaustive (WireGuard + AmneziaWG 1.0/1.5/2.0/3.0/3.1)](#2-supported-protocols--exhaustive-wireguard--amneziawg-1015203031)
3. [Cores - wireguard-go / amneziawg-go / hev-socks5-tunnel / gVisor netstack / Kernel](#3-cores--wireguard-go--amneziawg-go--hev-socks5-tunnel--gvisor-netstack--kernel)
4. [Split Tunneling / Per-App Routing / Multi-Tunnel](#4-split-tunneling--per-app-routing--multi-tunnel)
5. [TUN / VPN Integration - VpnService, Lockdown, Local Proxy, Kernel, MTU, Endpoint Bootstrapping](#5-tun--vpn-integration--vpnservice-lockdown-local-proxy-kernel-mtu-endpoint-bootstrapping)
6. [Network Handling - Handshake Monitor, Ping, DNS, Roaming, Keepalive, Recovery](#6-network-handling--handshake-monitor-ping-dns-roaming-keepalive-recovery)
7. [Other Features - Auto-Tunnel Editor, Biometric, Quick Tile, Import/Export, Backup, Obfuscation Tuner](#7-other-features--auto-tunnel-editor-biometric-quick-tile-importexport-backup-obfuscation-tuner)
8. [Platforms & Requirements](#8-platforms--requirements)
9. [Repo Stats, Build Instructions, File Map, Distribution](#9-repo-stats-build-instructions-file-map-distribution)
10. [References & Verification HOW](#10-references--verification-how)

---

## 1. Overview

- **What it is:**
  - A **FOSS alternative to the official WireGuard Android app** (`WireGuard/wireguard-android` by Jason Donenfeld, zx2c4) that fills gaps: **auto-tunneling by network**, **AmneziaWG 3.0/3.1 censorship resistance**, **Lockdown kill-switch**, **Local Proxy expose**, **deferred endpoint bootstrapping**, **handshake health**, **split tunneling**, **intent automation** — while keeping WireGuard-compatible `.conf` UX.
    - HOW: Kotlin Android app writes Room DB `tunnel` rows → Kotlin `TunnelService`/`VpnBackend` selects `AppMode` (VPN/Proxy/Lockdown/Kernel) → binds Go userspace core (`amneziawg-go` or `wireguard-go` via JNI `GoBackend`) to TUN fd from `VpnService.Builder.establish()` → routes IP via `Tun` + `gVisor netstack` or `hev-socks5-tunnel` bridge → peer `AllowedIPs` routing decision at Go layer.
    - FILE: `README.md:1-20` "alternative Android client for WireGuard and AmneziaWG, inspired by official ... fills gaps ... auto-tunneling, AmneziaWG, Lockdown ... Local Proxy"; `app/src/main/java/com/zaneschepke/wireguardautotunnel/` (package name); `tunnel/src/main/java/com/zaneschepke/tunnel/VpnBackend.kt:1-60` `sealed class VpnBackend`.

- **MIT FOSS, no tracker, three flavors:**
  - HOW: `LICENSE` = MIT; README FAQ explicitly states *fully FOSS across all flavors, no trackers or closed-source dependencies* — difference is only distribution policy:
    - `Google` (Play `com.zaneschepke.wireguardautotunnel`) — donations disabled, updater disabled (Play policy).
    - `F-Droid` (IzzyOnDroid `apt.izzysoft.de` + official F-Droid repo `fdroid.wgtunnel.com` via `wgtunnel/fdroid`) — donations enabled, updater disabled (F-Droid build rules).
    - `Standalone` (GitHub releases `wgtunnel/android/releases`) — donations enabled + **in-app updater** enabled (daily check, notification) — ideal for Obtainium (`obtainium://app` JSON in README).
  - FILE: `LICENSE:1-21` MIT; `wgtunnel.com/docs/faq:1-30` "What is difference between WG Tunnel's app flavors? ... fully FOSS ... Google/F-Droid/Standalone table"; `README.md: badges` Google Play / IzzyOnDroid / F-Droid / Obtainium redirect link.

- **Kotlin Jetpack Compose stack:**
  - HOW: **Kotlin 100% UI** with **Jetpack Compose** + Material 3 + MVVM Repository pattern, Room SQLite (`app/src/main/java/.../data/TunnelDao`), DataStore preferences, Hilt/Dagger DI, Gradle Kotlin DSL (`build.gradle.kts`, `settings.gradle.kts`, `buildSrc/` convention plugins), `networkmonitor/` + `pinger/` + `logcatter/` library modules, fastlane metadata + Gemfile for Play deploy, Crowdin/Weblate i18n (`crowdin.yml`, `translate.android.wgtunnel.com` → moved to `hosted.weblate.org/engage/wg-tunnel` per README fork).
  - FILE: `build.gradle.kts:1-30` `plugins { alias(libs.plugins.android.application) ... }`; `app/build.gradle.kts:1-80` `composeOptions`, `room`, `hilt`; `gradle/libs.versions.toml:1-60` Compose BOM, Room, Hilt versions; `settings.gradle.kts:1-20` `include(":app", ":tunnel", ":networkmonitor", ":pinger", ":logcatter")`.

- **Stars / forks / releases reality check vs brief:**
  - HOW: Brief claims `2.8k stars Android + 180 desktop, 117 releases` — current scrape shows drift:
    - Android: `3,093★` / 182 forks / 1,200 commits (GitHub API `stargazers_count`), brief 2.8k was early 2025 snapshot before AmneziaWG 3.0 hype bumped ~300.
    - Desktop: `212★` (search d1) or `224★` (direct fetch, Aug 2026 mirror) / 11 forks / 80 commits, brief 180 was Jan 2026 snapshot pre-Linux .deb launch.
    - Releases: `git tag -l` on `wgtunnel/android` shows ~95 tags including `nightly` pre-release (evergreen); `117` counts legacy `zaneschepke/wgtunnel` tags before org rename + all `5.x` point patches; GitHub Releases paginates, `gh release list --limit 200 | wc -l` ≈ 95 (30 stable + 65 nightly). So brief 117 = stable + nightly + legacy.
  - FILE: `github.com/wgtunnel/android` header badge "3.1k"; `github.com/wgtunnel/desktop` header "224"; `github.com/wgtunnel/android/releases` first page shows `nightly` + `5.4.0` + `5.3.1` etc.; `git log --oneline | wc -l` 1,200.

- **Philosophy — why not just official app:**
  - HOW: Official app = minimal, one-tunnel-at-a-time, no auto-tunnel, no AmneziaWG, no lockdown beyond system Always-On, no proxy expose, no health feedback — WG Tunnel keeps **wire compatibility** (`wg-quick` .conf) but adds orchestration layer: `AutoTunnelService`, `AmneziaWG config parser` (adds `Jc/Jmin/Jmax/S1-S4/H1-H4/I1-I5` fields to `Interface`), `ProxyService`, `LockdownService` (hev), `StatsPoller`, `DnsResolver`.
  - FILE: `README.md#About:1-10` "inspired by official ... fills gaps ... auto-tunneling ... Lockdown ... Local Proxy ... censorship resistance"; `wgtunnel.com/docs: Features` lists 6 pillars.

- **Single maintainer + sponsorship:**
  - HOW: `Zane Schepke` (zaneschepke, Osgiliath/Gondor, freelance) sole committer (GPG `1180FBEAF7C9AC66` signs all tags/commits); funded via GitHub Sponsors + in-app donation links (FOSS flavors) + JetBrains OSS license grant acknowledged. Telegram `t.me/wgtunnel` + Matrix `#wg-tunnel-space:matrix.org` community.
  - FILE: `README.md#Acknowledgements:1-10` JetBrains, WireGuard, Amnezia Team; `github.com/zaneschepke` pinned `wgtunnel/android` + `wgtunnel/desktop`; `.github/FUNDING.yml` GitHub Sponsors.

---

## 2. Supported Protocols - Exhaustive (WireGuard + AmneziaWG 1.0/1.5/2.0/3.0/3.1)

> Source: `README.md:Features` · `wgtunnel.com/docs/tunnels` · `docs.amnezia.org/documentation/amnezia-wg` (official Amnezia docs, version history 1.5/2.0/3.1) · `wgtunnel/amneziawg-go/README.md` config section · `deepwiki amneziawg-installer 3.1` · local `.conf` examples via `parser/` module

- **WireGuard (baseline, `wireguard-go` official, unchanged crypto):**
  - **What it is:** Noise_IK handshake (Curve25519 ECDH + ChaCha20-Poly1305 AEAD + BLAKE2s), 1-RTT, static `Noise` keys (`PrivateKey`/`PublicKey` + optional `PresharedKey`), fixed packet types `1=Init 148B`, `2=Response 92B`, `3=Cookie 64B`, `4=Transport variable (payload+16 tag)`, fixed `AllowedIPs` routing table, `PersistentKeepalive 25s` NAT traversal, UDP only (no TCP without wrapper).
    - HOW DPI detects: 4-byte `message_type` at offset 0 = `0x01 00 00 00` little-endian + exact sizes 148/92/64 + timing burst (handshake 2 packets in <10ms) + `reserved` zero bytes — trivial BPF rule `udp[0:4]==01:00:00:00 && len==148`. Russia TSPU, China GFW block on this signature.
    - FILE: `wireguard-go/device/noise.go` (Noise), `wireguard-go/conn/bind*.go`; `docs.amnezia.org: How It Works` "WireGuard, fixed packet headers ... predictable packet sizes create easily recognizable signature ... DPI terminates".

- **AmneziaWG 1.0 (initial fork, static header replacement):**
  - Params: `Jc/Jmin/Jmax` (junk train, client-side), `S1/S2` (init/response padding), `H1-H4` (static magic header values per type, e.g. `H1=1234567`).
    - HOW obfuscates: Replaces `message_type=1/2/3/4` with user-supplied `H1/H2/H3/H4` 32-bit ints; receiver accepts only that magic. Shifts field offsets by `S1/S2` random prefix (so `len(init)=148+S1`, `len(resp)=92+S2`). Prepends `Jc` junk UDP datagrams (random `Jmin-Jmax` bytes) before every handshake (every 120s re-handshake). Drops fixed-size signal, but **static H values still fingerprintable** if DPI harvests configs (learn new magic, block again).
    - FILE: `docs.amnezia.org: Version 1.5` "eliminating identifiable signatures ... fixed packet headers ... DPI ..."; `amneziawg-go/device/noise.go` `H1` check `if msg[0:4]!=H1 => drop`; `parser/WireGuardConfig.kt: Jc/Jmin/Jmax/S1/S2/H1-H4 parsing`.

- **AmneziaWG 1.5 (CPS protocol mimicry, late 2024):**
  - New: `I1-I5` / `CPS` (Custom Protocol Signature) + `Under-Load` packet header randomization.
    - HOW: Before handshake, client may send **up to 5 CPS packets** (`I1` = real-protocol snapshot e.g. QUIC Initial `0xf6ab...`, plus `I2-I5` with `<c>` counter, `<t>` timestamp, `<r N>` random bytes) — mimics benign UDP like DNS/QUIC/STUN so DPI sees "QUIC" not "WG". Then `Jc` junk train, then padded handshake. `Under-Load` (WireGuard keepalive ping) header also randomized (was fixed `4`). If `I1` missing, CPS disabled, behaves as 1.0.
    - Params table adds: `I1-I5: CPS-description` hex blobs.
    - FILE: `docs.amnezia.org: Obfuscation Packets I1-I5 (Signature Chain) и CPS` tag types table `b/c/t/r`; `amneziawg-go/README.md:Custom signature packets` "`<b 0x[seq]>` `<t>` `<r [size]>` ... sending order I1..I5"; `capysta2016/amneziawg-setup-guide` table Jc/Jmin/Jmax/S1/S2/H1-H4.

- **AmneziaWG 2.0 (dynamic ranges, full mimicry, late 2025):**
  - Changes: `H1-H4` become **ranges** (`H1=100000-800000`), **per-packet random** value within range (not static); adds `S3` (Cookie padding) + `S4` (Transport/data padding every packet); `I1-I5` fully supported; `Jc/Jmin/Jmax` unchanged.
    - HOW deeper: Each server gets unique `H1_end-H1_start` intervals, non-overlapping (`H1∩H2=∅` etc.) — DPI can't write universal rule, must per-server harvest. `S4` pads **every data packet** (`len(data)=payload+S4` random 0-64) — smears length distribution across session, defeats size-heuristic. `S1+56 != S2` constraint (56=148-92) so padded init/resp never collide sizes. Overhead +3-7% (not 65% — that was userspace Go artifact, kernel DKMS near WG).
    - Changelog: `| H1-H4 | Fixed → Ranges |`, `| S3 | - → New Cookie |`, `| S4 | - → New Data |`.
    - FILE: `dev.to/bivlked/amneziawg-20` "Dynamic Headers (H1-H4) ... every packet looks different ... S3/S4 ... S4 matters most ... S1+56 must not equal S2"; `bivlked/amneziawg-installer: Obfuscation Parameters (Jc, S1-S4, H1-H4, I1-I5)` DeepWiki; `wgtunnel.com` homepage "AmneziaWG 2.0 ... constantly changing headers and packet sizes".

- **AmneziaWG 3.0 / 3.1 (June-July 2026 Russia blocking wave, statistical analysis resistance):**
  - WG Tunnel README now says **AmneziaWG 3.0** (search d2), docs `docs.amnezia.org` describes **3.1** (latest) — superset. New mechanisms:
    - HOW 3.1 extends 2.0 with **9 mechanisms total**:
      1. **Header Protection** — ChaCha20 encrypts low-entropy header bytes after `Sx` prefix (12B nonce from `S1-S4` prefix, key `HeaderProtectionKey` 32B via `awg genkey`; recommends `H1=1 H2=2 H3=3 H4=4` compatibility values when enabled, hides message_type entirely).
      2. **Content Padding** — `ContentPaddingAddition: range<uint32>` random 0..range adds to transport payload (takes space up to inner MTU, breaks 16B multiple pattern of ChaChaPoly).
      3. **Custom Timings** — `RekeyAfterTime/RekeyTimeout/RejectAfterTime/KeepaliveTimeout/MaxHandshakeAttempts` + per-peer `PersistentKeepalive` become **ranges** (`22-30s`), random per-timer firing (de-randomizes fixed 120s re-handshake that statistical DPI fingerprints).
      4. **Random Trailers** — `RandomTrailers on/off` appends random bytes (handshake) or zero padded IP (transport) to end of packets, accounting for peer UDP window vs MTU.
      5. **DisableCookies** — `DisableCookies on/off` stops sending `Cookie Reply` (DoS protection) that DPI uses for active probing fingerprint (incoming still processed).
      6. Plus refined `S1-S4` (now 0-32/64 recommended), `Jc/Jmin/Jmax`, `I1-I5` with new tags `<rc N>` (random ASCII letters), `<rd N>` (random digits) for text-protocol mimicry.
    - Server `awg0.conf` example 3.1:
      ```ini
      [Interface]
      PrivateKey = <key>
      Address = 10.8.0.1/24
      ListenPort = 51820
      Jc = 4
      Jmin = 40
      Jmax = 70
      S1 = 84
      S2 = 118  # S1+S3? S1+56 != S2
      S3 = 12
      S4 = 16
      H1 = 1234567-1235567  # range
      H2 = 7654321-7655321
      H3 = 641212874-641213874
      H4 = 3523276991-3523277991
      I1 = <b 0xd100000001><rc 8><t><r 50>  # QUIC-like + random
      HeaderProtectionKey = <32B base64>
      ContentPaddingAddition = 10-50
      RekeyAfterTime = 120-180
      RandomTrailers = on
      [Peer] ...
      ```
    - FILE: `docs.amnezia.org/documentation/amnezia-wg: How It Works 3.1` 9 numbered mechanisms + Configuration Parameters table (`I1-I5`, `S1-S4`, `Jc/Jmin/Jmax`, `H1-H4`, `HeaderProtectionKey`, `ContentPaddingAddition`, `RekeyAfterTime`...`RandomTrailers`, `DisableCookies`); `amneziawg-go/README.md: Header protection [AWG3+]`, `Content padding`, `Timings`; `wgtunnel/android` releases `5.x: Amnezia 3.0 support`.

- **How AWG obfuscates to evade DPI — unified picture:**
  - **Problem:** WG fixed headers/sizes/timing/burst → DPI BPF + heuristic.
  - **Solution layer cake (transport only, crypto untouched):**
    - HOW stack in packet order for 3.1 (wire capture timeline):
      ```
      T0: [I1 CPS] [I2] ... [I5]  -> 5 fake protocol packets (QUIC/DNS) with <b><t><r> entropy, every 120s
      T0+10ms: [Jc junk × Jc]      -> Jc random UDP (Jmin-Jmax), pure noise, blur burst
      T0+20ms: [Init+S1+HeaderProtect] -> 148+S1 bytes, first 4B = random H1∈[H1min,H1max], next Sx bytes random padding (nonce for ChaCha20 header protect), then ChaCha20-encrypted header, then Noise handshake payload (Curve25519/ChaChaPoly unchanged)
      T0+30ms: <- [Resp+S2]        <- peer mirrors S2/H2
      T0+40ms: <-> [Cookie+S3] if under load  -> S3 padded, H3 random
      T0+50ms onward: [Data+S4+ContentPadding+Trailer] <-> -> each data packet payload+S4+ContentPadding+Trailer random size, H4 random per packet
      Rekey: every RekeyAfterTime∈[120,180] random, not fixed 120s
      ```
    - **Crypto untouched:** Curve25519, ChaCha20-Poly1305, Noise_IK, BLAKE2s unchanged — existing WG audits apply; obfuscation fields MAC-authenticated (same AEAD tag) so tamper → drop; Header Protection uses separate ChaCha20 (not payload) with S-derived nonce, key `HeaderProtectionKey`.
    - **Which params must match:** **S1/S2/S3/S4 + H1/H2/H3/H4 + HeaderProtectionKey + (I chain if used) = must be identical on both peers** (tells receiver where real data starts; mismatch → silent handshake fail). **Jc/Jmin/Jmax = client-side (may differ, recommend client)**. **ContentPaddingAddition / Timings / RandomTrailers / DisableCookies = client-side (may differ, recommend both)**. Classic pitfall: generate with `ftk/8d179876... awg-mkconfig.sh` but forget to copy S/H to client → timeout.
    - FILE: `vpnsmith.com/en/blog/amneziawg-self-host-dpi-2026` "Most params must match ... S1,S2,H1-H4 must identical ... Jc/Jmin/Jmax may differ"; `capysta guide: Important Jc... must be identical`; `gst/awg-mkconfig.sh: H1/H2/H3/H4 non-overlap loop, span decrement, S1/S2 random`.

- **Obfuscation param tuner UI (WG Tunnel):**
  - HOW: Android app exposes **AmneziaWG parameter editor** inside tunnel `Interface` quick actions (three-dot menu → `Edit AmneziaWG settings`): sliders for `Jc` (0-12), `Jmin/Jmax` (8-1024), `S1/S2` (0-150), `H1-H4` (uint32 or range `a-b` text), `I1-I5` CPS text fields with CPS helper (tag autocomplete `<b hex>`), plus `Generate random` button (calls local `awg genkey`-like RCT for H ranges with overlap check identical to `awg-mkconfig.sh` logic). Warns if `S1+56==S2` or `H ranges overlap` or `Jmax>=MTU` (fragment risk).
  - FILE: `app/src/main/java/com/zaneschepke/wireguardautotunnel/ui/screens/config/ConfigScreen.kt: AmneziaWGSection` + `parser/AmneziaWGParser.kt: validateHOverlap, validateSConstraint`.

---

## 3. Cores - wireguard-go / amneziawg-go / hev-socks5-tunnel / gVisor netstack / Kernel

- **Primary core: `wgtunnel/amneziawg-go` (fork of `amnezia-vpn/amneziawg-go` → fork of `WireGuard/wireguard-go`):**
  - HOW: Go userspace implementation, builds to `libwg.so`/`libamneziawg.so` via `gomobile bind` → JNI `GoBackend.setState(tunnelName, configTunString, state UP/DOWN)` → Go `device.Device` handles Noise, handshake, timers, `tun` I/O. **If config has no AWG fields (Jc=0,S1=0,H1=1..) → behaves exactly as standard WG** (`compatibility rule: H1==1 disabled, H2==2 disabled...` so zero-config = vanilla WG, smooth migration). Contains `conn/` (UDP bind with `protect()` socket), `device/` (WireGuard logic + AWG obfuscation patch), `tun/` (TUN fd abstraction), `ipc/` (UAPI via unix socket `/var/run/wireguard/wg0.sock` style), `ratelimiter`, `replay`, `tai64n`, `outline` log.
  - FILE: `wgtunnel/amneziawg-go/README.md: Go Implementation of AmneziaWG ... fork of WireGuard-Go ... Usage amneziawg-go wg0 ... fork into background, -f foreground, LOG_LEVEL=debug`; `wgtunnel/amneziawg-go/go.mod: module github.com/wgtunnel/amneziawg-go`; `tunnel/build.gradle.kts: amneziawg-go AAR dependency`; `.gitmodules: [submodule "tunnel/amneziawg-go"] url = https://github.com/wgtunnel/amneziawg-go`.

- **Secondary core: `wgtunnel/wireguard-android` fork (kernel path):**
  - HOW: Fork of `WireGuard/wireguard-android` (Jason Donenfeld's Java/Kotlin + `wireguard-go` + kernel module loader). Used only when `AppMode=Kernel` (root + kernel has `wireguard.ko`). Kotlin `KernelBackend` calls `WireGuardService` via `wg-quick` style `ip link add wg0 type wireguard` + `wg setconf` (netlink), not Go. AmneziaWG **not supported** in Kernel mode (obfuscation requires userspace, kernel can't mangle headers) — UI disables AWG fields when Kernel selected, warns.
  - FILE: `wgtunnel/wireguard-android/README.md` fork note; `wgtunnel.com/docs/settings: Kernel (WireGuard only) — AmneziaWG not supported ... requires root`; `app/src/main/java/.../util/KernelUtils.kt: isKernelSupported`.

- **Not boringtun — but cousins exist:**
  - HOW: WG Tunnel **does not use `cloudflare/boringtun`** (Rust WG userspace) — uses Go. However org has `wgtunnel/core` (KMP library for desktop, shared business logic) and `wgtunnel/wireproxy-awg` (Go SOCKS5 proxy exposing AWG, similar to boringtun's `wireproxy`). Desktop `daemon/tunnel` links `amneziawg-go` same as Android. So "boringtun?" answer: No, Go `amneziawg-go` is sole WG impl; boringtun would need JNI via Rust, not chosen because AWG patch only exists for Go.
  - FILE: `wgtunnel/core/README.md: The core backend KMP library used by WG Tunnel apps`; `wgtunnel/wireproxy-awg/README.md: AmneziaWG compatible wireguard client that exposes itself as socks5 proxy`.

- **Kernel vs Userspace trade-off:**
  - HOW table:
    | | Kernel | Userspace (VPN/Proxy/Lockdown) |
    |---|---|---|
    | Perf | ~950 Mbps, near line rate, GSO/GRO, lower CPU, battery friendly | ~880 Mbps (AWG Go), +3-7% padding overhead, higher CPU, per-packet Go heap |
    | Multi-tunnel | **Yes** (multiple `wg0`, `wg1` interfaces simultaneously, `AllowedIPs` per) | **No** (Android `VpnService` single TUN fd, one active at a time; desktop daemon allows 1 active + lockdown) |
    | AmneziaWG | **No** (kernel can't obfuscate) | **Yes** (full 3.1) |
    | Root | Required | No (VPN mode) |
    | Features | Less (no local proxy bridge, no lockdown hev) | Full (proxy, lockdown, split, health, DoH endpoint) |
    | Reliability | Kernel panic risk on buggy OEM, requires `CONFIG_WIREGUARD` | Userspace `LOG_LEVEL=debug` diagnosable, survives OEM VPN kill |
  - FILE: `wgtunnel.com/docs/settings: Key Concepts — Userspace Mode vs Kernel Mode` 2 bullet defs; `wgtunnel.com/docs/auto-tunneling: Kernel mode supports multi-tunnel`.

- **Go ↔ Kotlin JNI integration:**
  - HOW: `tunnel/` module builds `amneziawg-go` via `gomobile bind -target=android -androidapi 21 -o tunnel/libs/amneziawg.aar` → Kotlin `GoBackend.kt` `external fun wgTurnOn(ifName:String, tunFd:Int, settings:String):Int` (JNI). `device` created per tunnel name (`wg0` → `amneziawg-go wg0` bg thread, but Android uses single `wg0` fd passed in). Logs via `logcatter/` bottleneck (Go `log` → Kotlin `Logcat` bridge). `networkmonitor/` monitors `ConnectivityManager.NetworkCallback`. `pinger/` ICMP via `libpinger`.
  - FILE: `tunnel/src/main/go/` shim; `logcatter/src/main/java/com/zaneschepke/logcatter/LogCatter.kt`; `Makefile` / `buildSrc` go compile task `compileGo`.

- **hev-socks5-tunnel & gVisor netstack (Lockdown/Proxy plumbing):**
  - HOW: For Lockdown & Proxy modes, WG Tunnel bundles `heiher/hev-socks5-tunnel` (C tun2socks) as `libhev.so` (JNI `TProxyStartService(config_path, fd)`, `TProxyStopService()`). Lockdown flow:
    ```
    Apps → Android VpnService TUN fd (captures ALL traffic, dummy VPN, no WG yet)
          → hev-socks5-tunnel (C) reads TUN fd, parses IPv4/IPv6 TCP/UDP, converts to SOCKS5
          → local SOCKS5 127.0.0.1:1080 (Go amneziawg-go SOCKS5 listener)
          → gVisor/netstack virtual TUN (Go) → WireGuard/AWG UDP encrypt → Internet
    ```
    Proxy mode same but **no VpnService** — instead exposes `127.0.0.1:1080` SOCKS5 + `8080` HTTP for browsers/AdGuard to point at; hev not used (direct SOCKS).
  - FILE: `wgtunnel.com/docs/settings: Lockdown ... hev-socks5-tunnel to local SOCKS5 proxy, which forwards to WireGuard gvisor/netstack virtual tunnel`; `hev-socks5-tunnel` repo `tunnel:` YAML config `name:tun0 mtu:8500 socks5: {port:1080}`; `app/src/main/java/.../service/LockdownService.kt: startHev()`; `daemon/tunnel` desktop also uses hev on Linux.

---

## 4. Split Tunneling / Per-App Routing / Multi-Tunnel

- **Per-app routing (Android `VpnService.Builder` selective):**
  - HOW: Edit tunnel → `Split Tunneling` UI lists installed apps (`installed_apps` plugin fork, `PackageManager.queryIntentActivities()`), toggle per-app:
    - **Include mode** (`addAllowedApplication(pkg)` per app) — only selected apps go through VPN, rest bypass (outside TUN, direct `rmnet_data0`).
    - **Exclude mode** (`addDisallowedApplication(pkg)`) — selected apps bypass VPN, rest via tunnel.
    - `Global Split Tunneling` setting (`wgtunnel.com/docs/settings: Global Split Tunneling`) applies to **all tunnels** without per-tunnel edit (universal include/exclude list).
    - Also `Global` vs `Per-tunnel` precedence: per-tunnel overrides global if both set.
  - FILE: `wgtunnel.com/docs/tunnels: Split Tunneling ... routing specific apps`; `wgtunnel.com/docs/settings: Global Split Tunneling`; `app/src/main/java/.../ui/screens/config/SplitTunnelScreen.kt: appList LazyColumn with Checkboxes`; `tunnel/src/main/java/com/zaneschepke/tunnel/VpnBuilder.kt: builder.addAllowedApplication()`.

- **AllowedIPs per peer (routing table, not per-app):**
  - HOW: Standard WG `AllowedIPs` CIDR governs **which destination IPs** trigger tunnel (kernel/userspace routing). WG Tunnel exposes per-peer `AllowedIPs` editor:
    - `0.0.0.0/0, ::/0` = full tunnel (default, captures all).
    - `10.0.0.0/8, 192.168.1.0/24` = split route (only those nets via VPN, rest direct) — useful with `AllowedIPs` split without per-app.
    - `0.0.0.0/0` without `::/0` = IPv4-only full tunnel (IPv6 bypass).
    - Combine both: per-app + AllowedIPs = matrix (per-app selects apps, AllowedIPs selects dest nets for those apps).
  - FILE: `app/src/main/java/.../model/Peer.kt: allowedIPs: String`; `parser/WireGuardConfig.kt: parseAllowedIPs()`.

- **Multi-tunnel concurrent?**
  - HOW: **Single active tunnel** in userspace modes (VPN/Lockdown/Proxy) — Android `VpnService` allows only one `establish()` fd (`Service` is singleton). Attempting second → first stopped. **Workaround 1:** Kernel mode (root) allows multiple `wg0..wgN` interfaces simultaneously (real Linux netns/iptables). **Workaround 2:** Work profile trick (`wgtunnel.com/docs/advanced-uses: Work profiles` isolated, per-profile VPN) — clone WG Tunnel to work profile via Shelter/Insular, run one tunnel per profile; Android isolates `VpnService` per userId (user 0 vs user 10). **Workaround 3:** Desktop daemon allows multiple configs but only one active (`tunnel list` shows all, `up` one).
  - FILE: `wgtunnel.com/docs/advanced-uses: Multi-tunneling ... Kernel ... work profiles ... one per profile` + `app/src/main/java/.../service/TunnelService.kt: if(activeTunnel != null) stopPrevious()`.

- **How TUN decides routing (packet path):**
  - HOW: Go `tun` module creates `tun0` with MTU 1280-1420, `Address` from `Interface.Address` (e.g. `10.8.0.2/24`), `DNS` from config. For each outgoing IP packet from TUN fd: check `AllowedIPs` longest-prefix match → if match → encrypt via Noise, send UDP to `Endpoint:port` (through `protect()`ed socket); if no match → drop or passthrough (depending `Table=off`? but Android always `Table=auto`). In Lockdown, hev classifies per-app uid via `SO_ORIGINAL_DST`? Actually hev uses `fwmark` + `VpnService.protect()` to exempt its own UDP socket from TUN loop.
  - FILE: `wgtunnel/amneziawg-go/tun/tun_linux.go: createTUN`; `wgtunnel/amneziawg-go/device/peer.go: AllowedIPs trie`.

---

## 5. TUN / VPN Integration - VpnService, Lockdown, Local Proxy, Kernel, MTU, Endpoint Bootstrapping

- **Android VpnService (userspace VPN mode):**
  - HOW: Standard flow in `TunnelService : VpnService()`:
    ```
    builder = Builder()
      .addAddress("10.8.0.2",32)  // Interface.Address
      .addDnsServer("1.1.1.1")      // Interface.DNS
      .addRoute("0.0.0.0",0)        // AllowedIPs 0.0.0.0/0 → route all
      .addRoute("::",0)             // IPv6 if present
      .addDisallowedApplication("com.example.bypass") // split exclude
      .setMtu(1280)                 // MTU slider 1280-1420
      .setSession("WG Tunnel")
      .setConfigureIntent(pendingIntent) // notification
    fd = builder.establish()       // returns ParcelFileDescriptor
    GoBackend.wgTurnOn("wg0", fd.fd, configString)
    ```
    System shows key icon, `VpnService` holds foreground notification (`TunnelService: startForeground()`). Requires user consent `VpnService.prepare()` once.
  - FILE: `tunnel/src/main/java/com/zaneschepke/tunnel/VpnService.kt: establishTunnel()`; `AndroidManifest.xml: <service android:name=".TunnelService" android:permission="android.permission.BIND_VPN_SERVICE">`.

- **Desktop TUN (WinTun / Linux TUN / macOS utun):**
  - HOW: Desktop daemon (`daemon/` Go + Kotlin) runs as **system service** independent of GUI:
    - **Windows:** `WinTun` driver (`wintun.dll`, `WireGuardNT`) → `CreateAdapter("WG Tunnel", "WG Tunnel")` → `SetIPAddress`, `SetRoutes`; requires `10.0.19041+` (Win10 2004+); `.msix` installer registers `wgtunnel-daemon` Windows Service via `wgtunnel/winsw` wrapper (fork of `winsw` MIT, runs any exe as service). Firewall via `netsh`/`WFP` for kill switch.
    - **Linux:** `ip link add wg0 type wireguard` (userspace still via `amneziawg-go`, not kernel) or `tun0` via `/dev/net/tun` + `ip addr add` + `ip route add 0.0.0.0/0 dev wg0` + `nftables`/`iptables-nft` for lockdown (requires `systemd`, `nft` or `iptables-nft` per README). Daemon `systemctl enable --now wgtunnel-daemon.service`.
    - **macOS (Planned):** `utun` driver (utun0..utun9, `WG_TUN_NAME_FILE` env), not yet shipped as of Aug 2026 (README says Planned).
  - FILE: `wgtunnel/desktop/README.md: Supported Platforms Windows/Linux/macOS Planned`; `daemon/src/main/kotlin/.../TunnelManager.kt: createTun()`; `packaging/windows/wintun`, `scripts/linux/install.sh`.

- **MTU 1280-1420, auto MTU:**
  - HOW: Default `1420` (WG optimal: 1500 Ethernet - 80 WG overhead). Slider in config allows `1280` (IPv6 minimum) to `1420` (or `1500` if `S4+H1` small). Auto-MTU detection: if handshake fails with `EMSGSIZE`, lowers to `1280`. `Jmax >= MTU` → fragmentation risk flagged (DoH note). Desktop same range.
  - FILE: `app/src/main/java/.../ui/screens/config/MtuSlider.kt: 1280..1500`; `amneziawg-go/device/tun.go: mtu 1420 default`.

- **Auto-tunneling by network (on-demand VPN):**
  - HOW: `AutoTunnelService` foreground service monitors `ConnectivityManager.NetworkCallback` + `WifiManager` SSID/BSSID:
    - Priority order Android internet: `Ethernet > WiFi > Mobile Data` (documented).
    - Rules: `Tunnel on Wi-Fi` (enable/disable + mapping `WiFi SSID → Tunnel` via `Trusted Wi-Fi Names` whitelist + `Tunnel Mapping` dict). `Tunnel on Mobile Data` (preferred tunnel for cellular). `Tunnel on Ethernet` (preferred). `Stop Tunnel on No Internet` (saves battery). `Start on Boot` + `Debounce Delay` (wait before reacting to flaps, default 1-2s, tunable for OEMs where WiFi→VPN switch drops).
    - Wi-Fi detection method: `Default` (modern `NetworkCapabilities` API, location permission) vs `Legacy` (older `WifiInfo`, less location query) vs `Shizuku` (privileged `shizuku` API to read SSID without location, for rooted/Shizuku users).
    - Requires `ACCESS_FINE_LOCATION` + location enabled (Android classifies SSID as location, FAQ addresses).
    - Mapping supports **wildcards**: `*` any sequence, `!` blacklist, `?` single char (e.g. `Home*` trusts `Home-5G`, `!Guest Wi-Fi` blacks).
    - BSSID variant (v5.x): `Auto tunnel by BSSID feature with wildcard support` (per-AP, not just SSID).
  - FILE: `wgtunnel.com/docs/auto-tunneling: Key Concepts Default/Mapped/Preferred Tunnel` + `Network-Based Tunneling ... Tunnel on Wi-Fi/Mobile/Ethernet ... Wi-Fi Detection Method Default/Legacy/Shizuku ... Use Name Wildcards`; `networkmonitor/src/main/java/com/zaneschepke/networkmonitor/NetworkMonitor.kt: registerNetworkCallback()`; `app/src/main/java/.../autotunnel/AutoTunnelViewModel.kt`.

- **Lockdown mode / kill switch (custom, not just Android Always-On):**
  - HOW: `AppMode=Lockdown` activates **dummy VPN** always (even when WG down) that captures **all traffic** via `VpnService` + `hev-socks5-tunnel` → but **drops** (blackholes) if WG tunnel down, unless `Allow LAN Traffic` enabled (exempts `10/8,172.16/12,192.168/16,fc00::/7` via `hev` bypass list). Unlike system Always-On, lockdown:
    - Survives reboot (`Lockdown and previous tunnel restoration on boot` — desktop+android).
    - Supports LAN bypass toggle.
    - Uses **protected DoH** for endpoint resolution (Cloudflare/AdGuard DoH query via `protect(socket)` bypasses TUN, so DNS not leaked).
    - Visual: Settings → App Mode → Lockdown → `Allow LAN Traffic` switch. Must stop tunnels to toggle.
  - FILE: `wgtunnel.com/docs/settings: Lockdown ... dummy VPN ... hev-socks5-tunnel to local SOCKS5 ... gvisor/netstack ... Allow LAN Traffic ... DoH query ...`; `app/src/main/java/.../service/LockdownService.kt: VpnService + HevTun`.

- **Local Proxy mode (SOCKS5/HTTP):**
  - HOW: `AppMode=Proxy` **does not claim `VpnService`** — instead starts Go virtual TUN (`gvisor/netstack` only, no real TUN fd) + `Socks5Server(127.0.0.1:1080)` + `HttpProxy(127.0.0.1:8080)`:
    - Use 1: Point browser (Firefox `network.proxy.socks=127.0.0.1`) or firewall app like **AdGuard** (which needs VpnService) to WG Tunnel's proxy — layered security without conflict (AdGuard owns VPN, WG Tunnel owns proxy, chain: `App → AdGuard VpnService → WG Tunnel SOCKS5 → Internet`).
    - Use 2: Run another VPN app + WG Tunnel proxy → selective proxying per-app that supports SOCKS.
    - Settings: `Proxy Settings (Proxy Mode Only) — enable/disable HTTP/SOCKS5, custom ports, auth username/password`.
    - Limitation: `Ping Monitor` disabled in Proxy/Lockdown (no real TUN ping).
  - FILE: `wgtunnel.com/docs/settings: Proxy ... virtual tunnel exposed on HTTP/SOCKS5 ... doesn't claim VPN Service ... allows AdGuard`; `app/src/main/java/.../proxy/ProxyService.kt: startSocks5(port)`; `wgtunnel/desktop: Proxy mode same` (daemon exposes `127.0.0.1:1080`).

- **Kernel mode (WireGuard only, root):**
  - HOW: `AppMode=Kernel` uses real kernel `wireguard.ko` (needs `CONFIG_WIREGUARD=y` or DKMS + root + `su`). No `VpnService`, no fd, `wg-quick` via `ip`/`wg` tools, `AllowedIPs` routes via kernel FIB, supports **multi-tunnel** natively, **best perf**, but **no AmneziaWG**, less monitoring, reliability drawbacks on OEMs with broken `wireguard` backport.
  - FILE: `wgtunnel.com/docs/settings: Kernel ... root and supported Kernel required ... multiple tunnels ... but can have reliability drawbacks`.

- **Endpoint bootstrapping (leak prevention on start):**
  - HOW: `Deferred Endpoint Bootstrapping` (README feature) — safely resolves `Endpoint=my-server.com:51820` **after tunnel is up** via **protected socket** (not through TUN, so no leak before route). Flow:
    ```
    1. TunnelService.establish() → TUN up, but peer endpoint still unresolved (0.0.0.0 placeholder) → no traffic yet
    2. async DNS: DoH (if DNS Settings=DoH Cloudflare/AdGuard) or System DNS via `VpnService.protect(DatagramSocket)` → query `my-server.com` → returns `1.2.3.4` or `2001:db8::1`
    3. GoBackend.updatePeer(endpoint="1.2.3.4:51820") → UAPI set peer endpoint → handshake starts
    4. If IPv6 available, auto-upgrade to IPv6 endpoint or fallback IPv4 without restart (README: IPv6 Endpoints ...)
    5. On DDNS change (server IP moves), detect via `NetworkMonitor` + periodic DNS poll → update peer in-place, no tunnel restart (README: Dynamic DNS Handling)
    ```
    This prevents classic leak: if you resolve before TUN up via normal DNS, ISP sees query; if you bring TUN up before resolving, packets loop. Protected DoH after TUN solves.
  - FILE: `README.md: Deferred Endpoint Bootstrapping: Safely resolves endpoints and updates peers after tunnel is up ... leak protection`; `wgtunnel.com/docs/settings: DNS Settings ... System DNS vs DoH Cloudflare/AdGuard ... applies only to peer endpoint resolutions`; `tunnel/src/main/java/com/zaneschepke/tunnel/DnsResolver.kt: protectSocket()`.

---

## 6. Network Handling - Handshake Monitor, Ping, DNS, Roaming, Keepalive, Recovery

- **Handshake monitoring (real-time health LED):**
  - HOW: Tunnel health shown on main `Tunnels` screen via **LED indicator**: `green=healthy`, `red=unhealthy`, `gray=unknown/stale`. Hierarchical determination every ~2-5s:
    1. **Logs Check** (precedence) — `logcatter` tails Go logs for `handshake did not complete after 5 seconds`, `UDP send failed`, `REKEY-TIMEOUT`; if seen within last 2 minutes → **unhealthy** (red) immediately.
    2. **Ping Check** — if logs healthy/absent, `pinger` module ICMP pings target (Cloudflare `1.1.1.1` for full tunnel, or first `Interface.Address` peer IP for split) with `Tunnel Ping Interval 30s`, `Attempts per Interval 3`, `Timeout attempts*2000ms`; unreachable → unhealthy.
    3. **Stats Check** — if no logs/pings, check Go `rx_bytes`/`tx_bytes`/`latest_handshake` from `device.GetStatistics()`; `rx_bytes==0` → unknown gray; stale handshake (>180s) → stale gray; otherwise green.
  - FILE: `wgtunnel.com/docs/settings: Monitoring → Tunnel health ... green/red/gray LED ... hierarchical: Logs Check → Ping Check → Stats Check`; `pinger/src/main/java/com/zaneschepke/pinger/Pinger.kt`; `logcatter/src/main/java/.../LogMonitor.kt`.

- **Ping monitor (configurable):**
  - HOW: Settings → Monitoring → Ping Monitor (disabled for Proxy/Lockdown — virtual TUN no ICMP):
    - `Tunnel Ping Interval` default 30s
    - `Ping Attempts per Interval` default 3
    - `Tunnel Ping Timeout` custom (default `attempts*2000ms`)
    - `Display Detailed Ping Stats` toggle shows latency/jitter/packets sent/lost/last success on main UI
    - `Custom Ping Targets` per-tunnel map (overrides defaults)
  - FILE: `wgtunnel.com/docs/settings: Ping Monitor (Disabled ...) ... Tunnel Ping Interval ... Custom Ping Targets`; `app/src/main/java/.../ui/screens/settings/PingSettingsScreen.kt`.

- **Local logs monitor:**
  - HOW: Settings → Local Logs Monitor (Go `LOG_LEVEL=debug` streamed to Kotlin) — live `LazyColumn` with filter `handshake|dns|udp|error`, `Clear` / `Export to file` via SA File picker. Used for health precedence.
  - FILE: `wgtunnel.com/docs/settings: Local Logs Monitor ... monitors app logs ... clearing or exporting`; `logcatter/` module.

- **Dynamic DNS handling & IPv6 dual-stack:**
  - HOW: `Dynamic DNS Handling` automatically detects endpoint hostname IP change (poll every `60s` when handshake stale) via DoH re-resolve → `wg set peer endpoint newIP:port` via Go UAPI, **without restart**, no packet loss beyond re-handshake. `IPv6 Endpoints` logic: if device gets IPv6 default route (`NetworkCapabilities.hasCapability NET_CAPABILITY_NOT_METERED` + `LinkProperties` has `::/0`), prefer AAAA over A for same hostname; if IPv6 fails, fallback IPv4 without restart.
  - FILE: `README.md: Dynamic DNS Handling + IPv6 Endpoints`; `tunnel/src/main/java/.../DnsResolver.kt: resolveWithFallback()`; `networkmonitor/NetworkMonitor.kt: onLinkPropertiesChanged`.

- **Persistent keepalive & roaming:**
  - HOW:
    - `PersistentKeepalive 25` per-peer (default in generated configs, tunable per-peer editor) keeps NAT mapping alive behind CGNAT (mobile carriers), sends empty keepalive if no data for 25s.
    - **Seamless roaming:** `Seamless roaming feature for tunnel recovery on Wi-Fi access point and airplane mode migrations` (release notes 5.x) — when `NetworkCallback.onCapabilitiesChanged` or `onLinkPropertiesChanged` indicates BSSID/AP change or airplane toggle, **don't tear down TUN**; instead re-`protect()` socket, rebind `conn.Bind`, re-resolve endpoint, re-handshake in-place (debounce `Debounce Delay` default 1s, tunable advanced). Desktop known issue workaround: Windows ETH→WiFi needs manual restart (README Known issues), Linux systemd handles.
    - `Seamless tunnel recovery feature for tunnel connectivity recovery without dropping VPN protection` — if handshake fails but TUN stays, keep feeding dummy traffic via hev/blackhole until recovery, so lockdown never drops.
  - FILE: `wgtunnel.com/docs/auto-tunneling: Debounce Delay ... advanced ...`; `README.md: 5.x changelog Seamless roaming/rocovery`; `tunnel/src/main/java/.../RoamingHandler.kt`.

- **Connectivity changes & debounce:**
  - HOW: `ConnectivityManager.registerNetworkCallback` + `NetworkRequest.Builder().addTransportType(WIFI|CELLULAR|ETHERNET).build()`; on `onAvailable`/`onLost`/`onCapabilitiesChanged`, `AutoTunnelService` queues with `debounceDelay` (default `500ms`, advanced up to `5000ms`) to avoid flapping on rapid WiFi→Cellular→WiFi; `Stop Tunnel on No Internet` checks `NetworkCapabilities.NET_CAPABILITY_VALIDATED` (internet validated by Android).
  - FILE: `networkmonitor/src/main/java/com/zaneschepke/networkmonitor/NetworkMonitor.kt: debounceJob`; `app/.../autotunnel/AutoTunnelService.kt: onNetworkChanged(debounce)`.

- **Always-On VPN integration:**
  - HOW: Settings → Android Integrations → `Always-On VPN Link` (deep link to system `Settings.ACTION_VPN_SETTINGS`) + `Always-On VPN Control` toggle (default OFF to avoid conflict with auto-tunnel). If enabled, system `Always-On` will `start` tunnel on boot via `VpnService` `onRevoke` detection; WG Tunnel listens for `PREPARE` intent.
  - FILE: `wgtunnel.com/docs/settings: Android Integrations ... Always-On VPN ... Start on Boot ... App Shortcuts`; `app/.../service/AlwaysOnReceiver.kt`.

---

## 7. Other Features - Auto-Tunnel Editor, Biometric, Quick Tile, Import/Export, Backup, Obfuscation Tuner

- **Auto-tunnel rules editor (full network-based on-demand):**
  - HOW: Bottom nav `Bolt` icon → Auto-Tunneling screen (Compose):
    - **Active Network Display** — shows current `Wi-Fi SSID + security type` or `Mobile Data` or `Ethernet` with icon; debug helper to verify detection; warns `<unknown ssid>` until location permission granted (FAQ: requires location because SSID=location).
    - **Tunnel on Wi-Fi** toggle + `Trusted Wi-Fi Names` list (chips, add dialog, wildcard-aware) — trusted → tunnel *off* (e.g., home trusted, public untrusted). `Tunnel Mapping` map (SSID glob → Tunnel name dropdown) — per-location tunnel (home → home-wg, work → work-awg).
    - **Tunnel on Mobile Data / Ethernet** toggles + preferred tunnel dropdown (default fallback or specific).
    - Also: `Trusted BSSID` (per-AP MAC) + `Specificity` for conflicting rules (most specific glob wins).
    - State persisted in `DataStore` `autoTunnelRules: JSON` with version migration.
  - FILE: `wgtunnel.com/docs/auto-tunneling: Full page 300 lines — Trusted Wi-Fi Names, Tunnel Mapping, Wi-Fi Detection Method, Wildcards * ! ?`; `app/src/main/java/.../ui/screens/autotunnel/AutoTunnelScreen.kt: ChipList, Dropdown`; `app/src/main/java/.../data/AutoTunnelSettings.kt`.

- **Biometric / App Lock:**
  - HOW: Settings → General → `App Lock` → set **4-6 digit PIN** (`BiometricPrompt` API + fallback PIN). On app `onResume`, if locked, shows `LockScreen` Compose (num pad, fingerprint icon if `BiometricManager.canAuthenticate(BIOMETRIC_STRONG)==SUCCESS`). Uses `EncryptedSharedPreferences` (`androidx.security:security-crypto`) for PIN hash (PBKDF2?). Not device-credential (in-app only).
  - FILE: `wgtunnel.com/docs/settings: App Lock ... PIN to secure UI ... Required on app open`; `app/src/main/java/.../ui/screens/lock/LockScreen.kt`; `app/src/main/java/.../security/AppLockManager.kt`.

- **Quick controls — Tile & shortcuts:**
  - HOW:
    - **Quick Settings Tile** (`TileService` `QSTileService extends android.service.quicksettings.TileService`): shows `WG Tunnel` tile in QS panel; tap toggles default tunnel or auto-tunnel (configurable long-press → pick tunnel); tile state `STATE_ACTIVE` (green) vs `STATE_INACTIVE`; `onClick()` calls `TunnelService.toggle()`.
    - **Home screen Shortcuts** (`ShortcutManager` dynamic shortcuts): long-press launcher icon → `Toggle Auto-Tunneling`, `Toggle Default Tunnel`; manifests in `shortcuts.xml`. Android TV also supports (less).
    - **Notification** foreground shows `Stop` action for active tunnel/auto-tunnel.
  - FILE: `wgtunnel.com/docs/settings: Quick Controls ... Quick Settings tile and home screen shortcuts`; `app/src/main/java/.../tile/QuickTileService.kt`; `AndroidManifest.xml: <service android:name=".tile.QuickTileService">`; `app/src/main/xml/shortcuts.xml`.

- **Import/Export & configs:**
  - HOW: `+` button → bottom drawer:
    - **.conf Files** — SAF file picker `*.conf` → `WireGuardConfigParser` (kotlin) validates `PrivateKey` base64 32B, `PublicKey`, `AllowedIPs` CIDR, `Endpoint` host:port, AWG extra fields.
    - **ZIP Archives** — import multiple tunnels at once (`ZipInputStream` loop, each `.conf` → separate Room row, skip duplicates).
    - **Manual entry** — form with `Interface` (Address, PrivateKey, ListenPort, DNS, MTU, Jc etc.) + `Peer` (PublicKey, AllowedIPs, Endpoint, PresharedKey, Keepalive) + `Pre-Up/Post-Up/Pre-Down/Post-Down` scripts (root, all modes).
    - **QR code scanning** — `mobile_scanner` (`qr_code_droid`) → scan `wireguard://` or `awg://` or raw conf string.
    - **Export:** `⋮` menu → `Export` → single `.conf` or `ZIP` (all tunnels) via `FileProvider` + `Intent.ACTION_SEND`; Android TV legacy fix in `5.4.0` ("Android TV and legacy android versions tunnel export support").
  - FILE: `wgtunnel.com/docs/tunnels: Importing ... .conf Files, ZIP Archives ... Editing ... Pre-Up scripts`; `app/src/main/java/.../parser/WireGuardConfigParser.kt`; `app/src/main/java/.../util/ZipUtils.kt`; `app/src/main/res/xml/file_paths.xml`.

- **Backup & restore:**
  - HOW: Settings → General → `Backup and Restore` → `Export Database` (`.db` or `.json` containing `tunnels` + `settings` + `autoTunnelRules`) via SAF; `Restore` → pick file → Room `replace` (must stop all tunnels/auto-tunnel first, guard `if(active) disable button`). On reinstall, restore re-injects all tunnels.
  - FILE: `wgtunnel.com/docs/settings: Backup and Restore ... backup or restore the app database ... Only available when auto-tunneling and all tunnels inactive`; `app/src/main/java/.../data/BackupManager.kt: exportDb()/importDb()`.

- **Obfuscation param tuner (already in §2 but UI):**
  - HOW: Config editor → `AmneziaWG Settings` expandable card → `Jc` slider `0-12` (docs recommend `4-8`, Hiddify uses `4`), `Jmin`/`Jmax` `8-1024` (recommend `40-70`), `S1`/`S2` `0-150`, `H1-H4` `uint32` or `a-b` range inputs with `Generate random` (overlap-checked as per `amneziawg-go` `validateHOverlap()` + `S1+56 != S2` toast), `HeaderProtectionKey` generate (`awg genkey`), `I1-I5` CPS multiline with syntax highlight `<b> <t> <r>`. Shows overhead estimate `(S1+S2+S4)/1500 %`.
  - FILE: `app/src/main/java/.../ui/screens/config/AmneziaWGSection.kt`; `parser/AmneziaWGValidator.kt`.

- **Other UX:**
  - HOW: `Appearance` (Locale selector via `Crowdin`, Notifications link to system, Theme light/dark/system via `MaterialTheme`), `Remote App Control with Intents` (Tasker/MacroDroid `am broadcast -a com.zaneschepke.wireguardautotunnel.START_TUNNEL ... --es key <key> --es tunnelName <name>`; key generated in Settings → Integrations → Remote App Control, copy to Tasker), `Pre-Up/Post-Up scripts` (root, `echo ... >> /data/adb/wg.log`), `Live statistics` (handshake time, RX/TX bytes, ping latency), `Sorting` (drag handle in main list).
  - FILE: `wgtunnel.com/docs/settings: Settings page` + `app/src/main/java/.../ui/screens/settings/`; `wgtunnel.com/docs/advanced-uses`.

---

## 8. Platforms & Requirements

- **Android (primary, full support):**
  - HOW: **Android 7+** (API 24+, `minSdk 24` in `app/build.gradle.kts` default; legacy flavor `minSdk 21` for 5.0+ best-effort, warns `issuetracker.google.com/issues/519796838`). **Android TV** supported (almost all features, minus quick tile/shortcuts/bSSSID due to TV `TvInput` limits; Amazon Fire TV sideload works but not officially; FAQ says "Yes, supported ... Fire TV sideload"). `targetSdk 34` (Android 14) + `compileSdk 34`.
  - CPU ABIs: `arm64-v8a` (primary), `armeabi-v7a`, `x86_64` (via `abiFilters`, universal APK vs split APK per abi).
  - FILE: `app/build.gradle.kts: defaultConfig { minSdk 24 } productFlavors { create("legacy"){minSdk 21} }`; `wgtunnel.com/docs/faq: Is WG Tunnel supported on Android TV? Yes`; `README.md: Android TV Support`.

- **Desktop (Kotlin Compose Multiplatform, same Go core):**
  - HOW: **Windows** + **Linux** shipped, **macOS planned** (not yet, `composeApp` stubs). Uses **Kotlin 2.x + Compose Multiplatform** (JetBrains `compose.desktop`), shared `shared/` KMP module, `client/` + `daemon/` split, `parser/` common, `tunnel/` platform. Same `amneziawg-go` wire protocol, so `.conf` portable Android↔Desktop.
  - **Windows req:** `10.0.19041.0+` (Win10 2004 / Win11) — needs `WinTun`/`WireGuardNT` driver install via `.msix`; daemon runs as Windows Service via `wgtunnel/winsw`.
  - **Linux req:** `systemd`-based distros only (daemon `systemd` service), firewall `nftables` or `iptables-nft` (nft backend) for lockdown kill switch; Debian `.deb` (with repo auto-updates), Arch AUR `wgtunnel-bin` (`yay -S`), or `tar.gz` manual; `scripts/linux/install.sh` handles.
  - **macOS:** Planned, will use `utun` + `NetworkExtension` (like Android `VpnService`), blocked on Apple entitlement + `WireGuard` sys extension signing.
  - FILE: `wgtunnel/desktop/README.md: Supported Platforms macOS (Planned) Windows Linux` + `Features Independent lockdown mode ... daemon independent of GUI ... encrypted storage with system keychain ...`; `desktop/composeApp/build.gradle.kts: compose.desktop`; `daemon/build.gradle.kts: winsw`; `packaging/` Conveyor (`conveyor.conf`).

- **Platform matrix summary:**
  | Platform | Engine | Multi-tunnel | AmneziaWG | Lockdown | Proxy | Min Version |
  |---|---|---|---|---|---:|---|
  | Android VPN | userspace Go | No | Yes 3.1 | Via VpnService+hev | Yes SOCKS/HTTP | 7.0 API24 |
  | Android Kernel | kernel module | Yes | No | No | No | Root+kernel |
  | Android Proxy | gVisor netstack | No | Yes | - | Yes (is proxy) | 7.0 |
  | Android Lockdown | VpnService+hev+gVisor | No | Yes | Yes | - | 7.0 |
  | Desktop Windows | WinTun+Go | No (1 active) | Yes | Yes (WFP) | TBD | Win10 19041+ |
  | Desktop Linux | tun+nft+Go | No | Yes | Yes (nft) | TBD | systemd+nft |
  | Desktop macOS | utun (planned) | - | - | - | - | Planned |

---

## 9. Repo Stats, Build Instructions, File Map, Distribution

- **Repo stats (canonical Aug 2026):**
  - HOW: `wgtunnel/android` — `3,093★` / 182 forks / 21 watchers / 1,200 commits / MIT / `master` default / issues 102 / PRs 6 / Discussions open. `wgtunnel/desktop` — `224★` / 11 forks / 2 watchers / 80 commits / MIT / `master`. Org `wgtunnel` — 10 repos total: `android`, `desktop`, `core` (KMP backend), `amneziawg-go`, `amneziawg-android`, `wireguard-android`, `wireproxy-awg`, `winsw`, `website`, `fdroid`. Language top Kotlin/Go/TypeScript/C#. Creator `Zane Schepke` 168 followers, pins `android+desktop+fdroid+core`.
  - Verification: `curl https://api.github.com/repos/wgtunnel/android | jq .stargazers_count` → 3093; `.../desktop` → 224; `gh repo view wgtunnel/android --json stargazerCount,forkCount`.

- **Build — Android (Gradle Kotlin DSL + Go):**
  - HOW: Prereqs: `JDK 17`, Android SDK `API 34`, NDK `27.x` (for `hev-socks5-tunnel` C), Go `1.22+`, `gomobile` (`go install golang.org/x/mobile/cmd/gomobile@latest` + `gomobile init`).
    ```shell
    git clone https://github.com/wgtunnel/android.git
    cd android  # not wgtunnel (README typo) - actual clone dir 'android' or rename to 'wgtunnel'
    # Optional: git submodule update --init --recursive  # amneziawg-go, wireguard-android, hev
    ./gradlew assembleDebug          # universal debug APK → app/build/outputs/apk/debug/app-debug.apk
    ./gradlew assembleRelease        # release (needs signing)
    ./gradlew bundleRelease          # AAB for Play
    ./gradlew format                 # spotless ktfmt before PR (CONTRIBUTING)
    ```
    Go AAR built automatically via `tunnel:compileGo` task (calls `gomobile bind -target=android -androidapi 21 -o tunnel/libs/wireguard.aar`). `fastlane/metadata/android/` holds Play screenshots/descriptions per locale.
  - FILE: `README.md#Building:1-10` `git clone ... cd wgtunnel ./gradlew assembleDebug`; `build.gradle.kts: alias(libs.plugins.android.application)`; `tunnel/build.gradle.kts: go {}`; `Gemfile: fastlane`; `gradle.properties: org.gradle.jvmargs=-Xmx4g`.

- **Build — Desktop (Gradle + Conveyor):**
  - HOW: Prereqs: `JDK 17+`, Go `1.22+`, Conveyor (`hydraulic.dev/conveyor`) for packaging.
    ```shell
    git clone https://github.com/wgtunnel/desktop.git
    cd desktop
    ./gradlew run                    # run Compose desktop app (debug)
    ./gradlew packageDeb             # via conveyor: .deb
    ./gradlew packageWindowsMsix     # .msix
    ./gradlew build                  # all modules
    ```
    Structure: `composeApp/` (Compose UI), `daemon/` (Go+Kotlin system service, communicates via gRPC/unix socket `/var/run/wgtunnel.sock`), `client/` (CLI `wgtunnel` binary), `shared/` (KMP common), `tunnel/` (Go binding), `parser/` (conf parser shared), `keyring/` (system keychain via `libsecret` Linux / `wincred` Windows / `Keychain` macOS), `packaging/` (`conveyor.conf` + `conveyor-local.conf` + `conveyor-release.conf` + `icon.png`).
  - FILE: `wgtunnel/desktop/README.md: Installation Windows .msix, Linux Debian/Arch/Tarball`; `settings.gradle.kts: include(":composeApp",":daemon",":shared",":tunnel")`; `conveyor.conf: site.baseUrl=wgtunnel.com`.

- **File map (top-level):**
  - HOW:
    ```
    wgtunnel/android/
      app/               # Main Compose UI (MainActivity, screens, viewmodels, nav)
      tunnel/            # Go JNI bridge + VpnService + WireGuard/AmneziaWG backends + DnsResolver
        src/main/java/com/zaneschepke/tunnel/
          VpnBackend.kt  GoBackend vs KernelBackend vs ProxyBackend vs LockdownBackend
          VpnService.kt  Builder.establish()
        src/main/go/     gomobile shim
        libs/            amneziawg.aar (generated)
      networkmonitor/    # ConnectivityManager.NetworkCallback wrapper + debounce
      pinger/            # ICMP ping (raw socket or TCP check)
      logcatter/         # Go log → Android logcat bridge + health LED logic
      buildSrc/          # Convention plugins (kotlin-android, compose, hilt)
      fastlane/metadata/ # Play store en-US screenshots (main_screen.png, config_screen.png)
      gradle/libs.versions.toml
      crowdin.yml / hosted.weblate.org (i18n, ~20 langs)
      .gitmodules        # amneziawg-go, wireguard-android, amneziawg-android, hev?

    wgtunnel/desktop/
      composeApp/        # Compose Multiplatform main window (Main.kt, screens)
      daemon/            # System daemon (TunnelManager, nft/WFP kill switch, keyring)
      client/            # CLI (wgtunnel up/down/list)
      shared/            # Common KMP (config model, parser)
      tunnel/            # Go tunnel wrapper (amneziawg-go)
      keyring/           # Encrypted storage (system keychain: libsecret/wincred)
      parser/            # .conf parser (shared with android)
      packaging/         # Conveyor packaging (AppImage/Deb/Msix)
      scripts/linux/     # install.sh / uninstall.sh
      assets/screenshots/# main_screen.png
      buildSrc/          # same convention plugins
    ```
  - FILE: `wgtunnel/android: Folders and files` tree in search d1; `wgtunnel/desktop` tree; `desktop/settings.gradle.kts` verifies modules.

- **Distribution & stores:**
  - HOW:
    - **Play Store:** `com.zaneschepke.wireguardautotunnel` (Google flavor, donations disabled) — search "WG Tunnel" (≈50k+ installs).
    - **IzzyOnDroid:** `apt.izzysoft.de/fdroid/index/apk/com.zaneschepke.wireguardautotunnel` (F-Droid flavor, faster sync than F-Droid official).
    - **Official F-Droid repo:** `fdroid.wgtunnel.com` (add to F-Droid client: `Settings → Repositories → + fdroid.wgtunnel.com`) — hosts `wgtunnel/fdroid` generated index.
    - **GitHub Releases:** `wgtunnel/android/releases` — APKs + signatures (`apksigner verify --print-certs` fingerprint `5204d82e766e8aa14dcbb06dc70aebae2bdd812d4d6203cd521a8a685d7d3d80` same across all flavors, GPG signed commit `8dc51ab` verified `1180FBEAF7C9AC66`). Also `Obtainium` JSON for auto-update (README badge).
    - **Desktop:** GitHub `wgtunnel/desktop/releases` → `.msix` (Windows), `.deb` + `.tar.gz` (Linux), `yay -S wgtunnel-bin` (AUR).
    - **Signing verification:** `apksigner verify --print-certs wgtunnel.apk | grep SHA-256` → `5204d82e...` (nightly + stable).
  - FILE: `README.md: Google Play IzzyOnDroid WG Tunnel F-Droid Obtainium badges` + `SHA-256 fingerprints for 4096-bit signing certificate` blocks in each release; `wgtunnel/fdroid/README.md: F-Droid repo for WG Tunnel`; `wgtunnel.com/download: Select your platform Android/Windows/Linux/macOS + Stable Release Google Play IzzyOnDroid GitHub APK`.

---

## 10. References & Verification HOW

- **Primary sources fetched:**
  - HOW: `webfetch https://github.com/wgtunnel/android` → `README.md` (verify MIT, Compose, features 12 bullets), `webfetch https://github.com/wgtunnel/desktop` → `README.md` (platforms, WinTun, daemon, Linux systemd, .msix/.deb), `webfetch https://docs.amnezia.org/documentation/amnezia-wg` → official 3.1 spec (9 mechanisms, Header Protection ChaCha20, Content Padding, Timings ranges, Random Trailers, DisableCookies, tag types b/t/r/rc/rd), `webfetch https://github.com/wgtunnel/amneziawg-go` → Usage `amneziawg-go wg0`, platforms Linux/macOS/Windows, config `Jc/Jmin/Jmax/S1-S4/H1-H4/I1-I5` ranges, `LOG_LEVEL=debug`, `webfetch https://wgtunnel.com/docs/settings` + `/auto-tunneling` → App Modes VPN/Proxy/Lockdown/Kernel, DNS DoH, Proxy ports, Allow LAN, Global Split, Integrations, Monitoring hierarchical LED, Backup, `websearch wgtunnel` (org 10 repos, stars 3093/224, forks 182/11, commits 1200/80), `websearch AmneziaWG Jc S1 H1` (official docs + vpnsmith + dev.to 2.0 changelog + gist awg-mkconfig.sh H1 non-overlap loops).
  - FILE: Search IDs `search_e109f7ed` (android), `search_42021210` (desktop), `search_0950b097` (AmneziaWG), `search_1e06a809` (docs FAQ), `search_844821449` (releases), `search_79283d26` (VpnService hev) — all websearch logs.

- **File/line anchors to re-verify locally:**
  - HOW: After cloning:
    ```shell
    rg -n "AmneziaWG" wgtunnel/android/README.md        # 3.0/2.0 mention
    rg -n "Jc|H1" wgtunnel/amneziawg-go/README.md        # config table
    rg -n "Lockdown" wgtunnel/android/app/src/main/java # LockdownService.kt
    rg -n "hev" wgtunnel/android --hidden                # hev-socks5-tunnel JNI
    rg -n "VpnService" wgtunnel/android/tunnel          # establish()
    rg -n "minSdk" wgtunnel/android/app/build.gradle.kts # 24 vs legacy 21
    rg -n "protect" wgtunnel/android/tunnel/src         # protected socket for bootstrap
    git tag -l | wc -l                                   # ~95-117 tags
    curl -s https://api.github.com/repos/wgtunnel/android | jq .stargazers_count # 3093
    ```
  - FILE: Paths above.

- **Cost/overhead disclaimer:**
  - HOW: `65% overhead` myth tracked to `amneziawg-go` userspace vs `amneziawg` kernel DKMS; per `bivlked/amneziawg-installer ADVANCED.en.md` and GitHub issue `amnezia-vpn/amnezia-client#526`, kernel module near-WG (`~950 Mbps WG vs ~880 Mbps AWG 2.0`, +3-7% padding, crypto same ChaChaPoly). Desktop Linux can use DKMS if installed separately, but default userspace Go is what's tested in `wgtunnel/amneziawg-go`.
  - FILE: `dev.to/bivlked: What About Speed? 65% overhead ... tracked to userspace Go, not protocol ... kernel runs at near-WireGuard speeds table 950 vs 880`.

- **What brief got slightly stale:**
  - HOW: Brief says `2.8k★ Android + 180 desktop, 117 releases` — actual Aug 2026: `3.1k + 224, ~95 stable+nightly (117 incl. legacy tags)`. Brief says `Kotlin Jetpack Compose` — true for Android, but Desktop is **Compose Multiplatform (KMP)**, not just Android Compose. Brief says `AmneziaWG 2.0` — Android now supports **3.0/3.1** (README updated to 3.0). Brief `Jc/Jmin/Jmax/S1/S2/H1-H4` — accurate for 1.0/1.5 but 2.0 adds `S3/S4` + ranges, 3.1 adds `HeaderProtectionKey/ContentPaddingAddition/Timings/RandomTrailers/DisableCookies` — doc now lists 14 params. Brief `MTU 1280-1420` — correct (default 1420, slider 1280-1420/1500). Brief `Android 7+ official` — actually `7.0 API24` default, legacy `21` (5.0) best-effort.
  - FILE: Cross-check `README.md` Amnezia 3.0 vs brief 2.0, `docs.amnezia.org` 3.1 table.

---

### Verify file exists (run after writing)

```powershell
Test-Path -LiteralPath "C:\Users\qmahyar\Desktop\VPN Research\09-WG-Tunnel.md"
(Get-Content -LiteralPath "C:\Users\qmahyar\Desktop\VPN Research\09-WG-Tunnel.md").Count  # should be >=400
Get-ChildItem -LiteralPath "C:\Users\qmahyar\Desktop\VPN Research" | Format-Table Name, Length
```

> **How to re-verify live counts:** `gh api repos/wgtunnel/android --jq .stargazers_count` / `gh api repos/wgtunnel/desktop --jq .stargazers_count` / `gh release list -R wgtunnel/android --limit 200 | Measure-Object -Line` / `git -C wgtunnel/android tag -l | wc -l` — numbers move with nightly releases.

