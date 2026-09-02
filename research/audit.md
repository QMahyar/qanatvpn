# Decision Audit — What Must Change (websearch 2026-08-30)

> Every decision from goal.md web-searched against upstream docs/issues. This is what breaks if you don't change it.
> **2026-08-30 update:** Sections 3–5 were Tauri v2 + React+MUI era. Stack is now Flutter 3.47.2 + Go 1.25 + material_3_expressive per `SPEC.md:Tech Stack` and `scaffold.md:Decision B`. Keep Tauri findings for history — do not scaffold Tauri; use Flutter. ECH moved to v1.1 per SPEC.

**Date:** 2026-08-30 (amended 2026-08-30 — Flutter+Go supersedes Tauri)
**Sources re-checked:** SagerNet/sing-box issues #4045/#2557/#3384, hoaxisr/amnezia-box, Leadaxe/sing-box-lx, sing-box docs Tor outbound, Flutter M3E/cue/drift, Tauri v2 mobile docs/issues #15067/#14177 (historical), tauri-plugin-webview-upgrade, MUI Android scrollbar #47506

---

## 1. Core = sing-box + Xray + amneziawg-go hybrid — MUST CHANGE VENDOR

**Your decision:** sing-box + Xray + amneziawg-go via Go sidecars (Tauri Rust spawner)

**Websearch finding:**
- **Upstream SagerNet/sing-box REJECTS AmneziaWG.** Issues #1928, #2557 (canonical rejection: "not obfuscation, just adding invalid data to packet header... I won't consider this stuff"), PR #2670 closed in 2 days, #4045 open but cites prior wontfix. Maintainer explicitly recommends `swgp-go` over AmneziaWG.
- **Working implementations are forks:** `hoaxisr/amnezia-box` (sing-box fork tracking upstream, AWG 2.0 via `amneziawg-go`, build tag `with_awg` + `with_gvisor...with_awg`), `Leadaxe/sing-box-lx` (thin fork, AWG 2.0 H1-H4/S3-S4/I1-I5 + WireSock masquerade `id/ip/ib`, validated against real AWG server, tag `with_awg`), `amnezia-vpn/amneziawg-go` itself.

**What must change if you keep AmneziaWG:**
- You **cannot** use vanilla `SagerNet/sing-box` from `go.mod`. You must vendor a fork:
  - Option A (recommended for you): `hoaxisr/amnezia-box` — tracks `dev-next`, minimal divergence, AWG 2.0 only.
  - Option B: `Leadaxe/sing-box-lx` — adds XHTTP + AWG2 + MASQUE behind tags, rebaseable onto tags, larger surface but includes XHTTP you also want.
- Build command must include `-tags with_awg` (plus `with_gvisor,with_quic,with_dhcp,with_wireguard,with_utls,with_clash_api` per hoaxisr example). CI must init submodules (`--recurse-submodules` for `wireguard-go-awg2-lx`).
- Doc risk: Upstream will never merge this — you own the fork rebase cost. Mihomo *does* ship AmneziaWG (v1.18.9+), Hiddify/Karing already use forks — you're in good company, but be explicit in SPEC.md.

**If you keep vanilla sing-box:** Drop AmneziaWG, use `swgp-go` wrapper instead (requires paired server, not interoperable with existing AmneziaWG infra — operators won't redeploy). You said you're familiar with Amnezia — this would break your use case.

---

## 2. Protocol = Tor + chaining — MUST ISOLATE

**Your decision:** Tor as native outbound + chaining (hop 2)

**Websearch finding:**
- sing-box Tor outbound is **not embedded**: spawns external `tor` binary via `executable_path`, `data_directory`, `torrc` map. From `protocol/tor/outbound.go:NewOutbound` and docs `configuration/outbound/tor/`: "Embedded Tor is not included by default, see Installation" + "The path to the Tor executable" + TCP-only (`ListenPacket` returns `os.ErrInvalid`).
- Failure mode: If Tor entry nodes blocked (common on DPI), sing-box hits `FATAL start service: start outbound/tor: context canceled` and **takes down entire sing-box** (issue #4200, 2026-06-09). No isolation.
- Xray-core and mihomo have **no Tor outbound** — workaround is SOCKS outbound pointing at system Tor SOCKS port.

**What must change:**
- Do **not** embed Tor as a regular outbound in the main sing-box config. Options:
  1. **SOCKS chaining (recommended):** Ship `tor` as separate sidecar process managed by Rust Tauri (like `floppa-vpn` two-process `:vpn` model), expose SOCKS5 `127.0.0.1:9050`, then sing-box `socks` outbound `detour: tor-socks`. This isolates Tor bootstrap failure — sing-box stays up if Tor down.
  2. **External dependency:** Document `tor` package required (`apt install tor` / Homebrew) and use `detour: block` fallback per #4200 repro, but UX is worse.
- Chaining (your must) is native in sing-box-lx via `chain` outbound and in sing-box via `relay` selector — keep, but test multi-hop latency. Tor + chain together will be slow — set expectation.

---

## 3. Platform = Android + Windows first via Flutter+Go — SUPERSEDED (was Tauri v2 — kept for history)

**Your decision (then):** Android + Windows first, Tauri v2 + React+MUI + Rust backend + Go sidecars
**Your decision (now):** Android + Windows first, Flutter 3.47.2 + Go 1.25 + material_3_expressive + cue + drift via MethodChannel → Go libbox (per `SPEC.md:Tech Stack`, `AGENTS.md:Project overview`). Tauri findings below are historical — do not apply.

**Websearch finding (historical, Flutter supersedes):**
- Tauri v2 **does** support Android + Windows ... (kept) — but Flutter now chosen for M3E + Riverpod + Go interop. For Flutter, use `VpnService.Builder` via `MethodChannel` + `go/libbox.aar` (not Kotlin `tauri-plugin-vpn` two-process).

**What must change (Flutter+Go):**
- Do not pin `wry`, `tauri-plugin-webview-upgrade`, or `createHashRouter` — those are Tauri-only.
- For TUN, use `MethodChannel vpn_service` → Go `Libbox.setup()` + `VpnService.Builder` + `protect(fd)` + `Service.startForeground(dataSync)` per `SPEC.md:41` and `scaffold.md`. No Rust Tauri bridge.

---

## 4. Transports = All tricks ON including ECH — TRIM ECH (kept)

**Your decision:** Reality + uTLS + Fragment/XHTTP + ECH + Amnezia junk
**Update:** ECH moved to v1.1 per `SPEC.md:401` — keep Reality + uTLS + Fragment + XHTTP + Amnezia junk as day-1 must.

**Websearch finding:**
- Reality, uTLS, Fragment, XHTTP/SplitHTTP are stable in sing-box and Xray.
- **ECH is NOT stable:** requires `rustls` ECH support not yet GA — blocked, so ECH deferred to v1.1 (see SPEC).

**What must change:**
- Keep Reality + uTLS + Fragment + XHTTP + Amnezia junk as day-1 must.
- ECH behind feature flag, track `rustls` ECH — not in v1.0 success criteria.

---

## 5. UI = Flutter M3E + cue — SUPERSEDED (was React + MUI via Tauri — kept for history)

**Your decision (then):** React 18 + MUI 7 + Tauri v2
**Your decision (now):** Flutter 3.47.2 + `material_3_expressive` 45 M3E + `cue`/`motion_kit`/`transit_kit` + `go_router` + `drift` (per `SPEC.md:34-38`). MUI findings below are historical — do not apply.

**Websearch finding (historical):**
- MUI vs Svelte weight noted, but Flutter M3E now chosen — editorial trust, Slisnet-like Jetpack Compose fidelity, `M3EMaterialApp` + `cue` spring, not WebView.

**What must change (Flutter):**
- Do not use React+MUI or `base: './'` + `createHashRouter` — those are Tauri-only.
- Use `material_3_expressive` tokens `var(--color-*)`, `EdgeInsetsDirectional`, `Semantics`, `ReduceMotion` per `SPEC.md:Code Style`.

---

## 6. Extra = All power features day 1 — SCOPE RISK

**Your decision:** All power features day 1 (groups, stats, backup/WebDAV, best-node, logs, geo updater)

**What must change:**
- This is the biggest schedule risk. Research shows each feature is a separate module:
  - WebDAV sync (FlClash v0.8.4) = `drift` sqlite + WebDAV client
  - Observatory/best-node = background health checker
  - Geo updater = cron + asset download + atomic swap
- **Recommendation:** Keep "all" as vision, but SPEC should define **MVP slice**: groups + speedtest + logs + geo updater = must for "win vs 13". Backup/WebDAV sync + auto-select + custom script = `v1.1` (2 weeks later). Otherwise 6-7 week estimate becomes 9-10 weeks.

---

## 7. License = AGPL — COMPATIBILITY CHECK NEEDED

**Your decision:** AGPL-3.0-only

**What must change / verify:**
- Go cores: sing-box = GPL-3.0, Xray = MPL-2.0, amneziawg-go = GPL-3.0, mihomo = GPL-3.0. AGPL-3.0 is GPL-3.0 compatible but **stronger copyleft** (network use triggers source offer). All are compatible, but you must publish fork sources for `amnezia-box`/`sing-box-lx` anyway.
- Tauri + MUI = MIT/Apache — fine.
- **Action:** Add `LICENSE` = AGPL-3.0, plus `THIRD_PARTY.md` listing fork SHAs, and ensure GitHub Releases include `src` tarball for AGPL compliance.

---

## 8. Distribution = GitHub Releases only — OK

No change needed for MVP. Just ensure Android signing: generate `upload-keystore.jks`, pin cert hash like Exclave `e9fe39e1...` in README, and set `tauri.conf.json` bundle identifiers. Add F-Droid `fdroid` metadata in v1.1 to meet "public open-source win" goal.

---

## Summary — What Must Change Before SPEC (amended Flutter+Go)

1. **Vendor a fork:** Replace `SagerNet/sing-box` with `hoaxisr/amnezia-box@SHA` (pin) in `go.mod` and CI (`-tags with_gvisor,with_quic,with_dhcp,with_wireguard,with_utls,with_acme,with_clash_api,with_awg` + submodules).
2. **Isolate Tor:** Do not use sing-box `tor` outbound directly — run `tor` sidecar + SOCKS chaining (`127.0.0.1:9050` detour `tor-socks`).
3. **Flutter+Go scaffold:** `flutter create . --project-name yourvpn` + `material_3_expressive` + `cue` + `drift` + `MethodChannel` → Go libbox (not Tauri wry/hash routing).
4. **Defer ECH to v1.1:** Keep Reality + uTLS + Fragment + XHTTP + Amnezia junk as must.
5. **Scope split:** Define MVP vs v1.1 for extra features (keep "all" as vision, ship slice first — MVP week2 WG/AWG+routing).
6. **License docs:** AGPL + `THIRD_PARTY.md` with fork SHAs + `src` tarball.

If you agree to these 6 changes, SPEC v2.0 already bakes them (Flutter+Go, 9–10 weeks, 6 deeps). See `SPEC.md:Tech Stack` + `tasks/plan.md`.
