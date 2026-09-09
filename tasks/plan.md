# Plan: QANATVPN — From Spec to Ship (All Protocols, WG+AWG Priority First, 6 Deep Modules) — v1.0

> Source: `SPEC.md` v2.0 + `goal.md` FROZEN FINAL (All protocols, WG/AWG priority first, original self-contained, Flutter+Go+M3E, 1 TUN fork) + `architecture-review-20260830-074725.html` (6 deepening opportunities, grilling Q1-10 locked). This is the gated plan; human reviews before `todo.md` execution.

## Major Components and Dependencies

```
Component graph (Mermaid — build order must respect arrows):

flowchart TD
  CORE[core: Go amnezia-box fork + Xray via gomobile → libbox.aar] --> TUNNEL[tunnel: Tunnel Lifecycle 03 — deep, owns Dart↔Kotlin↔Go seam, max WFP]
  CORE --> GEO[geo: GeoAsset 05 — SRS pipeline]
  CORE --> SUB[ingestion: IngestionAdapter 02 — sealed union parsers]
  TUNNEL --> ROUTING[routing: RoutingCompiler 01 — 30 fields + 3-tier]
  SUB --> ROUTING
  ROUTING --> AWG[amnezia: AwgProfile/AwgConfig 04 — all values]
  GEO --> HEALTH[health: Health 06 — snapshot+stream]
  TUNNEL --> HEALTH
  ROUTING --> UI[ui: Flutter M3E + cue + bento home + 30-field editor + wizard EN/FA RTL]
  GEO --> DNS[dns: FakeIP+DoH, uses GeoAsset path]
  SUB --> UI
  UI --> PLATFORM[platform: MethodChannel → VpnService/WinTun + foreground + battery]
  TUNNEL --> PLATFORM
  PLATFORM --> SEC[sec: AGPL + max firewall + 7 leak tests + Play disclosure]
  GEO --> UPDATES[updates: daily GitHub platform-aware + 6h cache]
  UPDATES --> SEC
  HEALTH --> DIAG[diag: DNS scanner + ping + traceroute]
  L10N[l10n: EN/FA ARB + a11y] --> UI
  SEC --> RELEASE[release: GitHub Releases 3 jobs parallel + signing + latest.json]
  RELEASE --> WEBSITE[website: GitHub Pages — docs, download, api latest.json]
  CORE --> UPSTREAM[upstream: fork rebase tracker — amnezia-box/Xray/sing-box tags]
  RELEASE --> TRACKING[tracking: cross-session agent progress — handoff + show-me-your-work + agent-memory]
  UI --> TRACKING
```

| Id | Module | Responsibility | Depends on | Why this seam |
|---|---|---|---|---|
| `core` | Go `amnezia-box` `with_awg` (all Jc/H1/I1/Id/Ip/Ib + ChaCha) + `XTLS/Xray-core` via `gomobile bind -androidapi 24` → `libbox.aar/.dll` | — | Hides fork rebase (weekly `git fetch amnezia/master + merge`) behind `replace` directive. Typed `AwgConfig` inside, not in UI. |
| `tunnel` | **03 Deep — Tunnel Lifecycle** — `Tunnel.connect(tag) -> TunnelState`, `disconnect()`, `status Stream` | `core` | Owns Dart↔Kotlin↔Go 12-step sequence + Tor SOCKS detour + foreground `dataSync` + battery `isIgnoringBatteryOptimizations` + WFP max firewall. One deep call does 12 steps for wizard/QuickTile/auto-tunnel. |
| `geo` | **05 Deep — GeoAsset** — `ensure(tag)->Path` always via `initial_path` + `refreshAll()` ETag 6h stale-while-revalidate | `core` | Owns SRS `binary` + `update_interval 24h` + `CacheFile` + `download_detour:proxy` + `x-ratelimit-reset`. Hides compile/decompile. |
| `sub` | **02 Deep — IngestionAdapter** — `parseAndNormalize(RawSubscription) -> List<NormalizedEndpoint>` sealed union | `core` | Hides 7 parsers (Clash YAML, sing-box JSON, vmess/vless/ss/sip008/trojan/hysteria2/tuic/WG INI) + `amnezia_values` presets + ETag. |
| `routing` | **01 Deep — RoutingCompiler** — `compile(RoutingPolicy) -> CompiledRoute {rulesJson, ruleSets, isValid, validationErrors}` | `tunnel`, `sub`, `geo` | Hides 30 `route.rules` fields + 3-tier `auto→selector→proxy` + `TOR-CHAIN relay` + `logical and/or` + `invert` + OR-group AND-logic (`route/rule/rule_default.go:17`). |
| `awg` | **04 Deep — AmneziaWG Domain** — `AwgProfile.fromPreset()` / `generateRandom()` → `AwgConfig` validated | `sub`, `routing` | Hides `H1∩H2=∅`, `S1+56≠S2`, `Jmax<MTU`, must-match vs may-differ, `Id/Ip/Ib` masquerade. Preset + Custom advanced. |
| `dns` | FakeIP `198.18/15` + DoH split + bootstrap + hijack | `tunnel`, `routing`, `geo` | Uses `GeoAsset.getPath(tag)` not network. |
| `ui` | Flutter M3E 45 + `cue` + `motion_kit` + `transit_kit` + bento home + 30-field editor + wizard EN/FA RTL | `routing`, `sub`, `geo`, `dns` | Blended `01-bento-specimen` × `10-grid-hum` → `prototype-final.html` (hero prism, pulse, draggable sheet, glass dialog). |
| `platform` | `MethodChannel vpn_service` Dart↔Kotlin `VpnService.Builder` + `protect(fd)` + WinTun | `tunnel`, `ui` | Thin Kotlin adapter only `fd` + `protect()`, no VPN logic (in Go). |
| `updates` | Daily `workmanager` + GitHub platform-aware (`android-arm64`/`windows-x64`) + `latest.json` | `sub`, `geo` | Hides `x-ratelimit-remaining:0` + `retry-after` + 6h cache (sesori pattern). |
| `diag` | Full diagnostics + `drift` + `network_reachability` Rust | `platform` | DNS scanner 0-6 + Prism HMAC + Simple Ping TCP 5000ms + PingRoute per-hop + `fl_chart` — provides data to `health` |
| `health` | **06 Deep — Health** — `snapshot() -> HealthReport` + `stream` hierarchical Logs→Ping→Stats | `geo`, `tunnel`, `diag` | Hides scanner, pinger, Rust `guard()`, Drift retention. Depends on `geo` for DNS probe detour, `tunnel` for status, `diag` for scanner. |
| `l10n` | EN/FA ARB + `EdgeInsetsDirectional` + `Semantics` + `ReduceMotion` | `ui` | `flutter gen-l10n`, 200% scale, WCAG AA. |
| `sec` | AGPL + WFP max firewall + 7 leak tests + Play disclosure | `platform`, `tunnel`, `health` | `WFP/iptables/pf` anchors, in-tunnel DNS `10.x`, IPv6 block, 90s video. |
| `release` | **Shipping** — GitHub Releases 3 jobs parallel + signing (`key.properties`, `upload-keystore.jks` pin `e9fe39...`) + `latest.json` + `sha256` | `sec` | `subosito/flutter-action@v2` 3.47.2 + Go 1.25 + NDK 28 + JDK 17. |
| `website` | **GitHub Pages** — `docs/` → `gh-pages` branch, landing + download + API `latest.json` mirror + docs from `SPEC.md`/`CONTEXT.md` (self-contained) | `release` | Jekyll or `flutter build web` static, `CNAME` + `latest.json` fetch. |
| `upstream` | **Upstream tracker** — `amnezia-box`, `sing-box`, `Xray-core`, `wireguard-go-awg2-lx` tags → rebase + `strings libbox.so` sanity | `core` | Weekly `git fetch --all` + `make lib_android` + `softprops/action-gh-release` version check. `show-me-your-work` TSV log per decision. |
| `tracking` | **Cross-session agent progress** — `agent-memory` + `handoff` + `show-me-your-work` + `wayfinder` | `release`, `ui` | So session-to-session agents know where they are and what to do (see § Tracking). |

---

## Implementation Order (what must be built first)

**Gated order from grilling Q1 + Q9 + dependencies:**

1. **Phase 0 — Scaffolding (1 day, no code):** `flutter create qanatvpn` + `go mod init` + `CONTEXT.md` (done) + `.hallmark/preflight.json` + `analysis_options.yaml` (require `EdgeInsetsDirectional`, require `Semantics`) + `l10n` ARB skeleton + `Makefile.lx` with `with_awg` tag + `submodules/wireguard-go`.
2. **Phase 1 — `core` (2 days):** `amnezia-box` fork `awg-1.14-rc1` via `replace` → `gomobile bind` → `libbox.aar` sanity `grep amneziawg` + `libbox-legacy.aar`. Xray stub (week 3).
3. **Phase 2 — `tunnel` 03 Deep (3 days, top pick):** `Tunnel` deep module + `PlatformAdapter` fake fd + `BoxAdapter` typed + `FirewallAdapter` + `TorAdapter` SOCKS. Sequence `grant→battery→foreground→establish→protect→start→firewall` hidden. **Checkpoint:** `flutter test` with fake adapters, no device.
4. **Phase 3 — `geo` 05 + `sub` 02 in parallel (2 days):** `GeoAsset` (ensure/refreshAll with 6h cache, initial_path) + `IngestionAdapter` sealed union (7 parsers) with `amnezia_values` presets. **Checkpoint:** `ingestion` unit tests raw `clash YAML / vless:// / wg_ini` → `NormalizedEndpoint` without file IO; `geo` fake http 403/429 → fallback.
5. **Phase 4 — `routing` 01 Deep + `dns` (2 days):** `RoutingCompiler` typed `RoutingPolicy` → `CompiledRoute` with `isValid`. 3-tier groups private inside. `dns` uses `GeoAsset` path. WG/AWG priority first.
6. **Phase 5 — `awg` 04 Deep (1 day):** `AwgProfile` preset + Custom advanced disclosure, `generateRandom()` validated, `toEndpointJson()`. Reuses WG-Tunnel overlap logic. **Checkpoint:** `awg` unit tests `H` overlap, `S1+56≠S2`, no real server.
7. **Phase 6 — `platform` + `ui` bento home + wizard EN/FA (3 days):** `MethodChannel vpn_service` thin adapter + Flutter M3E bento 10 tiles (blended `01×10`), wizard 3-step (VPN permission → battery → per-app), `go_router` + `cue` spring, `EdgeInsetsDirectional`, `Semantics`, `ReduceMotion`. WG/AWG star first.
8. **Phase 7 — `health` 06 Deep + `diag` + `l10n` (2 days, after 05):** `Health.snapshot()+stream` hierarchical, DNS scanner 0-6 + Prism HMAC + ping TCP 5000ms + `network_reachability` Rust + `drift` + `fl_chart`. `flutter gen-l10n` EN/FA RTL + golden.
9. **Phase 8 — `updates` + `sec` max firewall + 7 leak tests (2 days):** Daily `workmanager` + GitHub platform-aware + `GitHubRateLimitException` + `latest.json`, WFP max firewall, in-tunnel DNS pin, IPv6 block, 7 scenarios (reboot/sleep/handoff/DoH/QUIC/IPv6/split).
10. **Phase 9 — `release` + `website` + `upstream` + `tracking` (2 days):** GitHub Actions 3 jobs parallel (Android libbox+APK split per `nick4man/amnezia-box-for-android` + Windows zip + Linux), `softprops/action-gh-release`, `latest.json` platform map, `sha256`, `CNAME` GH Pages (`docs/` → `gh-pages`), `show-me-your-work` TSV log, `agent-memory` vault.

**Total:** 9–10 weeks (MVP week 2 shippable: WG/AWG + routing; week 4 full win — see `SPEC.md:Success Criteria 1`). Gated slices: `wayfinder` tickets for `VLESS/Hysteria2/TUIC/Tor` slice. 18-day estimate was without buffers/device tests — replaced.

---

## Risks and Mitigation

| Risk | Likelihood | Impact | Mitigation (with skill) |
|---|---|---|---|
| **AmneziaWG rebase breaks** — `hoaxisr/amnezia-box` lags behind `SagerNet/sing-box` 1.14 tag, `with_awg` compile fails | Medium | High — blocks `core` + `awg` + 7 leak tests | Pin `awg-1.14-rc1`, weekly `git fetch --all` + `make lib_android` + sanity `strings libbox.so | grep amneziawg` in CI before merge. Fallback `sing-box-lx` (thin rebaseable) as adapter. Track via `upstream` module TSV (`show-me-your-work`). |
| **Doze kills foreground** — `Service.startForeground(dataSync)` without `isIgnoringBatteryOptimizations` → killed on API 23+ | High | High — tunnel drops, leak tests fail | Wizard step 2 forces `requestIgnoreBatteryOptimization()` (VPN acceptable use per `developer.android.com`), `flutter_foreground_task` with `dataSync|remoteMessaging`, `autoRunOnBoot` true. Test via `androidTest` Doze simulation. |
| **GitHub 60/hr rate limit** — daily SRS + app checks from many users hit `x-ratelimit-remaining:0` | High | Medium — updates fail offline | 6h `stale-while-revalidate` via `flutter_cache_manager` + `compute()` isolate (Gate VPN pattern), respect `x-ratelimit-reset`/`retry-after` (sesori), `initial_path` fallback, `CacheFile.enabled`. Unit test 403/429/401. |
| **Play VpnService rejection** — missing prominent disclosure or 90s video, or wrong `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` category | Medium | High — cannot ship Play v1.1 | Add disclosure dialog before `VpnService.prepare()`, record 90s screen capture, declare `Network-related tools` + encryption `device→tunnel` in Play Console per `support.google.com/googleplay/answer/12564964`. Docs self-contained but `LICENSE` contains AGPL + third-party SHAs. |
| **WG/AWG param mismatch** — `H1∩H2` overlap or `S1+56==S2` causes timeout, hard to debug for highly censored users | Medium | High — star feature fails silently | `AwgConfig.generateRandom()` validates before Go call; unit tests `H` overlap, `S1+56≠S2`, `Jmax<MTU`, must-match vs may-differ split co-located in `awg` module (04). Integration sanity vs real AWG 2.0 server handshake. |
| **Tor FATAL #4200** — `type:tor` entry blocked → `FATAL start outbound/tor: context canceled` takes down sing-box | Low | High — whole VPN down | Use `TorAdapter` SOCKS sidecar `127.0.0.1:9050` detour `tor-socks`, not `type:tor`. `Tunnel` watches Tor process, falls back to `block` if down. Tested via killing Tor in integration. |
| **Shallow routing re-introduced** — caller bypasses `RoutingCompiler` and builds raw `Map` 30 fields | Medium | Medium — leaks SRS tags, breaks `invert` logic | Enforce `analysis_options.yaml` lint: forbid `RouteRule` raw construction outside `routing` module, require `RoutingPolicy`. `code-review-and-quality` gate. |
| **Delete-immediately migration breaks** — Q10 chosen delete, no deprecated adapters, callers break in 9-10w window | Medium | Medium — schedule slip | Mitigate via `incremental-implementation` thin vertical slices + `test-driven-development` red-green per slice + `show-me-your-work` TSV per decision. Offer ADR if hard to reverse (per `domain-modeling`). |
| **i18n RTL break** — `EdgeInsets.only(left:)` not `EdgeInsetsDirectional` → FA layout mirrored wrong | Medium | Low — FA users see broken padding | Lint `require EdgeInsetsDirectional`, golden localization tests EN/FA at 200% scale, `flutter gen-l10n` CI gate fails on missing keys. |
| **Scope creep Keep All + ECH v1** — 9-10w risk (SPEC success criteria 1 says WG/AWG priority first, but Keep All pushes to 9-10w) | High | Medium — delay vs slice | Mitigate via `wayfinder` tickets + `principle-sequence-verifiable-units` — slice `VLESS/VMess/Trojan/SS` week 3, `Hysteria2/TUIC/SSH/Tor` week 4, but WG/AWG + routing win by week 2 is shippable MVP per `tunnel` checkpoint. |

---

## What Can Be Built in Parallel vs Sequential

**Parallel (independent seams):**

- Phase 3 `01 RoutingCompiler` and `02 IngestionAdapter` in parallel (no shared files) — both deep, both feed `core` but not each other.
- `l10n` ARB + `diag` DB schema can parallelize with `geo` after `core`.

**Sequential (must respect dependencies):**

- `03 Tunnel` before `01/02` — unlocks testable ordering.
- `04 AmneziaWG` after `02` — needs `NormalizedEndpoint` sealed union shape.
- `05 GeoAsset` before `06 Health` — Health needs GeoAsset path for DNS probe detour (Q9).
- `ui` bento home after `routing` + `awg` — needs `RoutingPolicy` + `AwgProfile` types for 30-field editor and H1 sliders.
- `sec` max firewall after `tunnel` + `health` — needs `Tunnel.status Stream` + `Health.snapshot()`.
- `release` after `sec` — needs leak tests pass + `latest.json` platform map.
- `website` after `release` — needs `latest.json` + `SPEC.md`/`CONTEXT.md` self-contained docs.
- `upstream` tracking runs continuously from `core` onward, not a phase end.

---

## Verification Checkpoints Between Phases

| Checkpoint | Gates | Evidence |
|---|---|---|
| **After Phase 2 (Tunnel)** | `flutter test` with `FakePlatformAdapter` (fake fd) + `FakeBoxAdapter` passes ordering, airplane→block, Tor down→block without device. `strings libbox.so | grep amneziawg >0` passes. | `flutter test test/tunnel/` + CI log `amneziawg references: N` |
| **After Phase 3 (Geo+Ingestion)** | `IngestionAdapter` unit: raw `clash YAML / vless:// Reality / wg_ini` → `NormalizedEndpoint` sealed union. `GeoAsset` fake http 403/429 `If-None-Match` → fallback to `initial_path`. No file IO leak. | `flutter test test/ingestion/ test/geo/` |
| **After Phase 4 (Routing+DNS)** | `RoutingCompiler` 30 fields → `sing-box check -c` + `rule-set compile` round-trip, OR-group AND-logic validated. `isValid` shows all errors at once. `dns` uses `GeoAsset.getPath`. | `flutter test test/routing/` + `sing-box check -c profiles/config.wg-awg.json` |
| **After Phase 5 (Awg)** | `AwgConfig.generateRandom()` never overlaps `H`, `S1+56≠S2`, `Custom.validate()` catches bad ranges without real server. Integration handshake vs real AWG 2.0 server passes. | `flutter test test/awg/` + manual LTE handshake |
| **After Phase 6 (Platform+UI)** | Wizard 3-step (VPN permission → battery → per-app) + bento home 10 tiles + 30-field editor + EN/FA RTL `EdgeInsetsDirectional` + `Semantics` + `ReduceMotion` at 200% scale, no `overflow-x` at 320/375/414/768. `M3EMaterialApp` spring. | `flutter test test/l10n/` golden + manual 4-width check |
| **After Phase 7 (Health+Diag)** | `Health.snapshot()` hierarchical Logs→Ping→Stats with fake `DnsProber` + `Pinger` + Rust `guard()` → correct score without network. `drift` retention test. | `flutter test test/health/` |
| **After Phase 8 (Updates+Sec)** | Daily `workmanager` ETag 24h + 6h cache + `x-ratelimit-reset`/`retry-after` (sesori) + `latest.json` platform filter + 7 leak tests (reboot/sleep/handoff/DoH/QUIC/IPv6/split) all show VPN IP/DNS only via `tcpdump` + `dnsleaktest.com`. `WFP` max firewall enforced. | `flutter test test/updater/` + on-device `ipleak.net` + `tcpdump` |
| **After Phase 9 (Release+Website+Upstream+Tracking)** | GitHub Actions 3 jobs parallel produce `..._arm64.apk` + `_windows-x64.zip` + `latest.json` + `sha256` via `softprops/action-gh-release@v2` without manual steps. GH Pages `qanatvpn.github.io` serves landing + download + `latest.json` mirror (Jekyll or `flutter build web`). `show-me-your-work` TSV per decision + `agent-memory` vault + `handoff` doc for next session. | CI green + `https://qanatvpn.github.io/latest.json` fetch + `handoff` doc exists |

---

## How This Plan Uses Skills (from using-agent-skills)

- **spec-driven-development** → this SPEC is gate (done, now in plan).
- **planning-and-task-breakdown** → this plan's dependency graph + vertical slices (this file) — canonical source for `todo.md`.
- **incremental-implementation** + **test-driven-development** → each phase is thin vertical slice, red-green per `todo.md` task.
- **source-driven-development** → verify against `sing-box.sagernet.org`, `developer.android.com` VpnService/Doze, `pub.dev` `material_3_expressive`/`drift` before code.
- **context-engineering** → load `SPEC.md` + `CONTEXT.md` + `goal.md` + one module's source per task, not whole spec.
- **show-me-your-work** → TSV log `docs/decisions.tsv` with what/why/evidence/result per deepening (required for 9-10w review).
- **wayfinder** → if work exceeds one session, tickets with blocking edges per `todo.md` order.
- **handoff** + **agent-memory** + **recall** → cross-session tracking (see Tracking section below).
- **shipping-and-launch** + **ci-cd-and-automation** + **git-workflow-and-versioning** → release + GH Pages + upstream rebase (see Release/Website/Upstream).
- **observability-and-instrumentation** → instrument as you build (logs + `Health` metrics), not after.
- **doubt-driven-development** → fresh-context review before `sec` max firewall (leak tests).

---

## What We Haven’t Spoken About — Now In Plan

### Release & Publishing

- **Where:** `shipping-and-launch` skill. Pre-launch checklist: `flutter analyze` + `dart format` + `golangci-lint` + 7 leak tests + `strings libbox.so` sanity + Play disclosure video + `THIRD_PARTY.md` + `src` tarball per AGPL.
- **How:** `ci-cd-and-automation` → 3 parallel jobs (Android libbox+APK split per `nick4man/amnezia-box-for-android` + Windows zip + Linux stub) via `subosito/flutter-action@v2` 3.47.2 + `setup-go@v5` 1.25 + `android-actions/setup-android@v3` + `sdkmanager ndk;28` + `softprops/action-gh-release@v2` + `svenstaro/upload-release-action`. Signing via `secrets.KEYSTORE_BASE64` → `upload-keystore.jks` + `key.properties` (pin `e9fe39...`), `latest.json` platform map like `lollipopkit/flutter_server_box` + `RecomBox`.
- **Rollback:** Tag `v1.2.3` → `v1.2.2` via `git tag -d` + `softprops` overwrite, plus `latest.json` revert.

### GitHub Pages Website for VPN

- **What:** Static landing + docs + download + API mirror for `latest.json`. Not in spec before, now added as `website` component.
- **How:** `docs/` folder → `gh-pages` branch via `peaceiris/actions-gh-pages@v4` or `flutter build web` → `build/web` → `gh-pages`. Content: hero prism (from `prototype-final.html` signature), download buttons filtered by platform (`navigator.platform`), `fetch('https://qanatvpn.github.io/latest.json')` for in-app updater mirror, docs from `SPEC.md`/`CONTEXT.md` self-contained (no external VPN names), `CNAME` `vpn.yourdomain.com`. Style: blended Bento×Hum, `material_3_expressive` tokens, `M3EMaterialApp` web.

### Keeping Up With Upstream Sources

- **Which upstreams:** `hoaxisr/amnezia-box` (`awg-1.14-rc1` branch `awg-1.14-rc1` tracking `dev-next`), `SagerNet/sing-box` (baseline `sing-box` tags), `XTLS/Xray-core` 26.x, `Leadaxe/wireguard-go-awg2-lx` (via `submodules/wireguard-go` 3-way merge), `SagerNet/sing-box-for-android` (for `libbox` build pattern), `Loyalsoldier/v2ray-rules-dat` (for `geodat2srs` → `*.srs`).
- **How to update (with `git-workflow-and-versioning` + `principle-make-operations-idempotent`):**
  ```bash
  # Single source of truth: go/amnezia-box + go.mod replace directive
  cd go/amnezia-box && git fetch --all && git log --oneline origin/awg-1.14-rc1 -5
  git merge origin/awg-1.14-rc1 --no-edit --strategy-option theirs # rebase onto new tag
  cd ../.. && go mod tidy && make -C go/amnezia-box lib_android
  strings android/app/libs/libbox.so | grep -q amneziawg || exit 1
  flutter test && sing-box check -c profiles/config.wg-awg.json
  git add go/amnezia-box android/app/libs/libbox.aar && git commit -m "chore(upstream): bump amnezia-box to 1.14-rc2 (with_awg)"
  ```
  Track via `show-me-your-work` TSV: `what=bump amnezia-box, why=new sing-box tag, evidence=strings + flutter test, result=green`. `deprecation-and-migration` for breaking `option/wireguard_awg.go` struct changes (migrate callers then delete legacy). Automate via weekly `dependabot` + `cargo-update` analogue for Go (`go list -m -u`).

### Tracking Progress Across Sessions of AI Agents

- **Problem:** Your last sentence — how do session-to-session agents know where they are and what to do across 9-10w, 10 modules, 3 jobs parallel?
- **Skills that apply (from using-agent-skills):**
  - `agent-memory` — persistent vault across sessions: long-term facts (`CONTEXT.md` terms), daily logs (`tasks/progress-2026-08-30.md`), topic notes (`tasks/decisions.tsv`), scratchpad checklist.
  - `handoff` — compact conversation into `handoff.md` for next agent (what was done, what’s next, blockers).
  - `show-me-your-work` — TSV log `docs/decisions.tsv` with one row per decision (what, why, evidence, result) — reviewable trail for unattended work.
  - `wayfinder` — plan huge work as decision tickets on tracker with blocking edges (`To Do (3 blocked on checklist)` → `Next Up (?)`).
  - `recall` — reconstruct context from chat history, live state, shared record before resuming.
  - `reflect` — post-session review, spawn 3 parallel reviewers, route learnings to skill edit.
  - `context-engineering` — load only `SPEC.md` + `CONTEXT.md` + one module’s source per task, not whole repo, to guard context window.
- **How we wire it (concrete, not theory):**
  1. **After each phase checkpoint** (see Verification Checkpoints above), the agent writes `tasks/progress-YYYY-MM-DD.md` (daily log) + appends `show-me-your-work` TSV row + updates `tasks/todo.md` checkbox + runs `handoff` to emit `handoff.md` (compact).
  2. **Next session's agent** runs `recall` (reads `handoff.md` + `progress-*.md` + `CONTEXT.md` + `tasks/todo.md`), then `context-engineering` loads only that todo's files, then continues per `plan.md` build order. No guessing.
  3. **If work exceeds one agent session**, `wayfinder` splits `todo.md` into tickets `tasks/tickets/*.md` with `blocked-on` edges, so parallel agents don't collide on `core` vs `routing`.

---

## Next Step (human reviews this plan before `todo.md` execution)

Human reviews dependency direction (no cycles), build order (03→01+02→04→05→06, with `wayfinder` for huge work), and `show-me-your-work` TSV requirement. Getting the plan wrong is expensive; reviewing this page is not. Then `todo.md` breaks this plan into ≤5-files-per-task slices with `Acceptance / Verify / Files`.

> Save this plan to `tasks/plan.md` (this file) and `tasks/todo.md` per `planning-and-task-breakdown` convention. Downstream `/build` expects these defaults.
