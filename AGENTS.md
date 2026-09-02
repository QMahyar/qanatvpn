# AGENTS.md — YOURVPN

> Flutter+Go VPN (Android+Win first, 1 TUN fork, all protocols WG/AWG priority first, 30-field routing, max WFP firewall). Original self-contained, AGPL. Read this before any task — it turns a generic agent into a project-aware one at fixed cost.

## Project overview

Yourvpn wins vs 13 researched VPNs on every capability row, star is WG+AmneziaWG (all values Jc/H1-H4/I1-I5/Id/Ip/Ib) + sing-box advanced routing for highly censored networks. Stack: Flutter 3.47.2 + material_3_expressive 45 M3E + cue/motion_kit + Go 1.25 `hoaxisr/amnezia-box` `with_awg` → `libbox.aar` via gomobile. Platforms: Android + Windows first (MVP). Docs are self-contained original — README contains no external VPN names, LICENSE contains AGPL + third-party SHAs.

## Where to find what (progress, ongoing, what's left)

| Area | Read first | What it tells you |
|---|---|---|
| **Spec (what to build)** | `SPEC.md` v2.0 | Objective, Tech Stack, Commands, Project Structure, Code Style, Testing, Boundaries (Always/Ask/Never), Success Criteria, Open Questions, Deep Modules (6 deepening) |
| **Intent (why this vs competition)** | `intent.md` | 13 VPNs matrix vs your 22 locks, comparison per capability, build order WG/AWG first |
| **Decisions (why not how)** | `goal.md` FROZEN FINAL + `CONTEXT.md` | 22 locks, 10 glossary terms, grilling Q1-10, 1 TUN fork rebase rationale |
| **Plan (how to build, in what order)** | `tasks/plan.md` | Dependency graph, build order `03→01+02→04→05→06`, risks, parallel/seq, verification checkpoints |
| **Tasks (what to do next)** | `tasks/todo.md` | 17 discrete tasks, each ≤5 files, Acceptance/Verify/Files, ordered by dependency |
| **Progress (what's done, what's left)** | `tasks/progress-*.md` + `handoff.md` + `docs/decisions.tsv` | Daily logs, show-me-your-work TSV per decision, compact handoff for next session |
| **Architecture diagram** | `docs/archify.html` (showcase, 950×560, 9/9 checks) + `docs/archify-candidate.json` | Interactive arch: 10 nodes, 8 orthogonal routes, region `Flutter+Go` + sg-tunnel; build `node bin/archify.mjs deliver architecture docs/archify-candidate.json docs/archify.html --quality showcase` |
| **Architecture review** | `C:\Users\qmahyar\AppData\Local\Temp\architecture-review-20260830-074725.html` | 6 deepening candidates, top pick 03 Tunnel, before/after Mermaid |
| **Prototype (what it looks/feels like)** | `docs/prototype-final.html` (blended Bento×Hum, all screens) + `hallmark-variants/01` + `10` | Hero prism, bento home 10 tiles, 30-field editor, DNS scanner 0-6, wizard 3-step, live logs |
| **Research (competition)** | `research/01-Karing.md … 13-Matsuri-SagerNet.md` + `research/audit.md` | 13 VPNs extreme detail, 6 must-changes (fork SHA-pin, Tor SOCKS sidecar, Flutter+M3E scaffold, ECH→v1.1, Keep All slice, AGPL+THIRD_PARTY) |

## Tracking progress across sessions

**Every developed feature must update the trackers before handoff:**

1. After each `todo.md` task, append `tasks/progress-YYYY-MM-DD.md` (daily log), update `tasks/todo.md` checkbox, append `docs/decisions.tsv` (what/why/evidence/result), run `handoff` to emit `handoff.md` (compact: done/next/blockers + file pointers).
2. Next session's agent runs `recall` — reads `handoff.md` + latest `progress-*.md` + `CONTEXT.md` + `tasks/todo.md` — then `context-engineering` loads only that todo's files (guard context window).
3. If work exceeds one session, `wayfinder` splits `todo.md` into `tasks/tickets/*.md` with `blocked-on` edges. Parallel agents claim disjoint files (see `tasks/plan.md` parallel vs sequential).
4. Long-term facts live in `agent-memory` vault (`C:\Users\qmahyar\.config\opencode\agent-memory`), not in chat. Use `recall` to surface.

**Evidence before synthesis:** Run `flutter test --coverage`, `sing-box check -c`, `strings libbox.so | grep -q amneziawg` — not "seems right".

## Build and test commands (read, don't guess)

```bash
flutter pub get && flutter gen-l10n
make -C go/amnezia-box lib_android && cp go/amnezia-box/libbox.aar android/app/libs/
flutter test --coverage && flutter test test/updater/github_releases_api_test.dart
dart format --set-exit-if-changed . && flutter analyze && golangci-lint run ./...
sing-box check -c profiles/config.wg-awg.json && sing-box rule-set compile schemas/geosite-cn.json -o rule_sets/geosite-cn.srs
flutter build apk --split-per-abi && flutter build windows
```

CI: 3 jobs parallel (`subosito/flutter-action@v2` 3.47.2 + `setup-go@v5` 1.25 + `android-actions/setup-android@v3` NDK 28 + JDK 17) → `softprops/action-gh-release@v2` + `latest.json` + `sha256`. See `SPEC.md:Commands`.

## Code style (one snippet beats 3 paragraphs)

- Tokens locked: `var(--color-*)` + `var(--font-*)` — no inline `oklch()` outside `:root` (Hallmark). `EdgeInsetsDirectional` not `EdgeInsets.only(left:)` (FA RTL). `Semantics` on icon-only, `TextScaler.clamp 0.9-1.35`, `ReduceMotion` guard.
- Naming: `lowerCamelCase` Dart, `PascalCase` widgets (`VpnNotifier`), `snake_case` Go, `SCREAMING_SNAKE` constants. Files: `vpn_notifier.dart`, `route_rule.dart`, `singbox_config_builder.dart:18`.
- Active voice, sentence case, no em dashes, no bold-label lists, no puffery — see `SPEC.md:Code Style` example (`VpnNotifier.connect(tag)` + `RouteRule` 30 fields + `WireGuardAWGOptions`).

## Project structure — YAGNI (current + future, create only when needed)

**Rule:** YAGNI — don't pre-create empty folders. Current files live where they are now; future dirs are listed but not created until their `tasks/todo.md` task needs them. One place per asset, no duplicates.

```
VPN Research/  (repo root — no empty dirs)
├── AGENTS.md, SPEC.md, goal.md, CONTEXT.md, intent.md, scaffold.md  # specs at root — discoverable, single source
├── research/              # 13 VPNs + audit — competition facts only
│   ├── 01-Karing.md … 13-Matsuri-SagerNet.md (13 × 60-100KB)
│   └── audit.md           # 6 must-changes + 3 refines distilled from research
├── docs/                  # rendered artifacts — never code
│   ├── archify-candidate.json  # showcase arch spec (10 nodes, 950×560, source for archify.html)
│   ├── archify.html            # delivered showcase (9/9 checks, visual-check pass)
│   ├── archify.visual-check.*.png + .json/.html  # containment evidence
│   └── prototype-final.html    # blended Bento×Hum prototype (was root, now docs)
├── tasks/                 # planning + progress — single writer per session
│   ├── plan.md            # dependency graph + Phase 0-9 order
│   ├── todo.md            # 16 tasks ≤5 files each
│   ├── progress-YYYY-MM-DD.md  # future — daily log, create after each task
│   ├── tickets/*.md            # future — wayfinder tickets, only if >1 session
│   ├── handoff.md              # future — compact hand for next agent
│   └── decisions.tsv           # future — show-me-your-work log (docs/decisions.tsv alt)
│
├── (future — create on demand per todo, not now)
│   ├── lib/               # Flutter Dart — Feature-Based MVVM (created at todo:1 scaffold)
│   │   ├── main.dart + app/ (M3EMaterialApp + go_router ShellRoute)
│   │   ├── core/ (network 6h cache + routing + services/MethodChannel vpn_service)
│   │   ├── modules/vpn/ (logic/VpnNotifier + models + repositories + screens)
│   │   ├── modules/routing_editor/ + groups/ + logs/ + diagnostics/ + updates/ + profiles/ + i18n/
│   │   ├── l10n/ (app_en.arb, app_fa.arb) + utils/singbox_config_builder.dart
│   ├── android/app/libs/libbox.aar (from go/amnezia-box with_awg)  # todo:2 core
│   ├── windows/libbox.dll + runner/                                 # todo:2
│   ├── go/amnezia-box/ (submodule hoaxisr/amnezia-box awg-1.14-rc1) # todo:2
│   ├── go/xray-core/ + go/tor/ (SOCKS 9050)                          # todo:5
│   ├── rule_sets/*.srs + assets/geoip/ + profiles/config.wg-awg.json # todo:4,6
│   ├── test/updater/ + test/routing/ + test/health/                 # todo:3..8
│   ├── .github/workflows/build-*.yml (3 jobs parallel)             # todo:9
│   └── scripts/compare_capabilities.py (future — success criteria 1)
```

**YAGNI enforcement:** No `lib/`, `android/`, `go/`, `rule_sets/` until `todo:1-2` touches them. No `.hallmark/`, `references/`, `ios/` stubs until needed. Keep flat until feature forces nesting. Spec is gate — don't code beyond `SPEC.md:Project Structure` without updating spec.

Scaffold when needed: `flutter create yourvpn` + `flutter pub add material_3_expressive cue drift go_router` + `melos` (see `scaffold.md:3 options`). Keep `lib/` feature-first, `core/` shared, `app/` shell — no cross-feature imports.

## Testing

- Framework: `flutter test` + `go test` + `sing-box check` + leak tests via `tcpdump`/`dnsleaktest.com`/`ipleak.net`.
- Where: `test/` (unit), `test/integration/` (engine), `androidTest/` (VpnService), `go/...` (libbox), `test/l10n/` (ARB golden at 200%).
- Coverage: `flutter test --coverage` ≥70% for `lib/modules/routing_editor`, `lib/services`. Leak tests before every tag.
- Verification checkpoints per phase in `tasks/plan.md:Verification Checkpoints` — run the checkpoint for the phase you just touched, not whole suite.

## Boundaries

- **Always:** Run `flutter test --coverage` + `sing-box check` + `dart format` before commits. Validate `route.rules` via `sing-box rule-set compile`. Use original `MethodChannel` (not `vpnclient_engine_flutter` to avoid Extended GPL attribution) with `with_awg` tag. Cache GitHub API 6h + `x-ratelimit-reset`. Pin flutter 3.47.2, Go 1.25, NDK 28, JDK 17. Encrypt `device→tunnel`.
- **Ask first:** DB schema (`drift`), new deps (`pubspec.yaml`/`go.mod` replace), CI/signing (`key.properties`), new protocol (`outbound.type`), changing `route.rules` `final`/`auto_detect_interface`, new locale beyond EN/FA.
- **Never:** Commit secrets (`key.properties`, `upload-keystore.jks`, tokens), edit `go/amnezia-box` fork directly (rebase via `git fetch`), remove failing `test/updater` 403/429 tests, skip `isIgnoringBatteryOptimizations` (Doze kills), use `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` for non-VPN, ship without `sing-box check` + 7 leak tests, use `EdgeInsets.only(left:)` (breaks FA), copy other VPN text verbatim into README/docs (original self-contained only).

## Git workflow and versioning

- Branch: `main` + feature branches `feat/<module-id>` (e.g., `feat/tunnel-lifecycle-03`). Commit `feat:`, `fix:`, `chore(upstream):`, `docs:`. Tag `v1.2.3` → 3 jobs produce `yourvpn_v1.2.3_arm64.apk` etc. + `latest.json` + `sha256` via `softprops` without manual steps. `latest.json` platform map mirrors `flutter_server_box` + `RecomBox`. Keep `AGENTS.md` + `SPEC.md` + `CONTEXT.md` in version control, update after every major agent session per `writing-for-agents` pruning (one source of truth, no duplication, relevance check, hunt no-ops).

## Skills that apply (from using-agent-skills)

- `spec-driven-development` → SPEC is gate
- `planning-and-task-breakdown` → plan's dependency graph (this file's plan section)
- `incremental-implementation` + `test-driven-development` → thin vertical slices, red-green per todo
- `source-driven-development` → verify against `sing-box.sagernet.org`, `developer.android.com`, `pub.dev` before code
- `context-engineering` → load `SPEC.md` + `CONTEXT.md` + one module's source per task
- `show-me-your-work` → TSV `docs/decisions.tsv` per decision
- `wayfinder` → if >1 session, tickets with `blocked-on`
- `handoff` + `agent-memory` + `recall` → cross-session (see Tracking above)
- `shipping-and-launch` + `ci-cd-and-automation` + `git-workflow-and-versioning` → release + GH Pages + upstream
- `frontend-design` + `hallmark` + `unslop` → blended Bento×Hum prototype, distinctive, no AI slop
- `impeccable`/`high-end-visual-design` → polish passes (when UI ready)
- `security-and-hardening` → max WFP firewall, 7 leak tests
- `observability-and-instrumentation` → instrument as you build (Health logs)
- `doubt-driven-development` → fresh-context review before sec

## Latest progress (update after each task — this is the hand)

- **2026-09-01 (session 6, todos 10-17 DONE → 17/17):** **UI 10:** go_router 5-tab shell + bento home (PowerTile→VpnNotifier real, adaptive 4/2/1 cols, Semantics/EdgeInsetsDirectional). **Health 11:** `health.dart` 0-6 hierarchical score (hijack+ping+stability window >=2 samples), FakeIpDnsProber (198.18/15), TcpPinger. **Updates 12:** `updater.dart` platform-filtered GitHub releases, 403/429/401 typed, latest.json platform map. **Sec 13:** `firewall.dart` (hijack-first, pinned DNS, v6/lan BLOCK) + `scripts/leak_test.sh` 7 scenarios. **Release 14 + Website 15 + Upstream 16:** 5 workflows under `.github/workflows/` (android aar+strings sanity+split apk, windows exe+zip, linux stub, gh-pages self-contained site + latest.json mirror, weekly upstream drift). **Tracking 17:** all trackers current. **Deferrals documented in handoff.md:** engine runtime start (box.start channel method), M3E goldens, on-device leak tests, wizard installed-apps, CI first run, Play disclosure dialog. **92 tests, analyze clean.**
- **2026-09-01 (session 5, todo:9 DONE):** **Platform+Wizard:** `YourVpnService.kt` (real VpnService, TUN 172.19.0.1/30, fd registry, static callback handoff), `VpnServiceBridge.kt` (full vpn_service channel incl. requestVpnPermission startActivityForResult), MainActivity wiring, manifest service decl. Dart `requestVpnPermission()` on PlatformAdapter. `lib/modules/onboarding/wizard.dart` 3-step (permission→battery→per-app allowlist/bypass, back nav) + l10n EN/FA 14 keys (gen-l10n `synthetic-package: false` → lib/l10n). 6 wizard tests. Suite **73 tests**, apk green. 9/17.
- **2026-09-01 (session 4, todos 7-8 DONE):** **DNS+FakeIP 07:** `dns_config.dart` (1.14 typed servers, fakeip server type 198.18.0.0/15 — legacy `dns.fakeip` key REMOVED in 1.14 and fork FATALs on it; geosite-cn→local rule; hijack-dns always first rule; FakeIP pool in tun address). `tool/gen_profile.dart` → `profiles/config.wg-awg.json` generated from real modules, `sing-box check -c` exit 0. **AWG Domain 04:** `awg_config.dart` validate-all-at-once (S1+56≠S2, H1∩H2=∅, Jmax<MTU, 32B keys) + `toEndpointJson()` + `AwgProfile` presets/quic-mimic/balanced/stealth + `generateRandom()` secure (invariants by construction, 100-draw test); `amnezia_values.dart` refactored to AwgPreset extension (no duplicate enums). Both proven against real `sing-box check`. Suite: **67 tests, analyze clean**.
- **2026-09-01 (session 3, todos 3-6 DONE):** **Tunnel 03:** deep `lib/core/services/tunnel.dart` (guarded sequence, 6 adapter interfaces, MethodChannelPlatformAdapter safe-defaults, VpnNotifier riverpod) + Kotlin ForegroundService/BatteryOptHelper + manifest VPN perms; 15 tests. **GeoAsset 05:** `http_cache.dart` (ETag/403→GitHubRateLimitException/429/304/stale-serve) + `geo_asset.dart` (ensure never fails offline, real initial SRS vendored, refreshAll 6h SWR); 12 tests. **Ingestion 02:** sealed union 7 formats + all parsers (Uri.parse lowercases base64 hosts — manual parse for vmess/ss); 16 tests. **Routing 01:** RoutingCompiler (1.14-native `type: logical`, errors-all-at-once) + ConfigAssembler (awg→endpoints, new DNS format); **real `sing-box check -c` passes** on compiled config; 9 tests. Deps added: yaml, path(dev).
- **2026-09-01 (core, todo:2 DONE):** Fork pinned `1.14.0-rc.1-awgm.15` SHA `57276220`. Root `go.mod` stale replace REMOVED. **Critical finding:** fork's official `build_libbox` tag list LACKS `with_awg` — built via `Makefile`/`scripts/libbox.ps1` with official set + `with_awg`, sagernet/gomobile v0.1.13 (x/mobile lacks bind flags), javapkg `com.yourvpn`. `android/app/libs/libbox.aar` 123.9MB 4 ABIs; strings arm64: 751 amneziawg hits, stub string absent; `awg` endpoint passes `sing-box check`; `flutter build apk --debug` green (aar wired, compileSdk 37 for flutter_secure_storage, minSdk 24, `kotlin.incremental=false` Windows flake). Windows pivot: libbox is library pkg → no dll; **`windows/sing-box.exe` subprocess** (with_awg,with_purego, CGO off) via command server/clash API. WinLibs gcc installed. `libbox-legacy.aar` skipped (API 21 < minSdk 24).
- **2026-09-01 (deps+scaffold):** Web-verified best modern = **Flutter 3.47.2 + Dart 3.13.2** (3.41.9 exists but modern stack needs ≥3.44). Android 7 support = Flutter min API 24 (OK). Installed to `C:\tools\flutter`; pub get 154 deps (`flutter analyze` clean); Android SDK 35→**36** + build-tools 36 + NDK 28 + JDK 17; Go 1.26.5 + gomobile/gobind/golangci-lint; `go/amnezia-box` deps downloaded (go.sum 613). Platform scaffolded: `flutter create --platforms=android,windows --org com.yourvpn .` → `android/`+`windows/`+`.metadata`, `minSdk=flutter.minSdkVersion`(24). Spec/docs version-aligned (3.41.9→3.47.2, SD 34→36, material_ui note). AndroidManifest default (add VPN perms in platform todo).
- **Done (2026-08-30):** research/13 + audit amended, SPEC v2.0 + deep 6, CONTEXT 10 terms, plan graph fixed 9–10w, todo 17 (1 DONE stubbed), YAGNI reorg `research/` + `docs/` + `tasks/` + `scripts/`, archify showcase `docs/archify.html` 727KB 9/9 pass 950×560, prototype `docs/prototype-final.html`, 5 fixes: graph cycle, scaffold bulk mkdir, SPEC ios stubs, audit ghosts, decisions/progress/scripts stubs. Scaffold stub: `pubspec.yaml` riverpod + `analysis_options.yaml` + `l10n.yaml` + `lib/l10n/app_en/fa.arb` + `lib/app/` + `Makefile with_awg` + `go.mod` replace + `.gitignore` + `.hallmark/preflight.json`; core stub: `go/amnezia-box/README` + `android/app/libs/.gitkeep`.
- **17/17 todos done. Remaining deferrals (see handoff.md):** engine runtime start wiring (box.start channel), M3E polish + 200% goldens, on-device 7 leak tests, wizard installed-apps, CI first real run, Play disclosure dialog.

## Pointers (keep top short, details behind pointers)

- Deep modules interface details → `SPEC.md:Architecture — Deep Modules`
- Build order + risks + verification → `tasks/plan.md`
- Next discrete task → `tasks/todo.md:1`
- Why WG/AWG + routing vs pure WG → `goal.md:4-6` + `audit.md`
- Upstream rebase steps → `tasks/plan.md:Upstream tracker` + `go/amnezia-box` README
- Hallmark theme tokens → `docs/prototype-final.html` `:root` + `references/themes/`
