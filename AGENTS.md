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

- **2026-09-02 (sessions 8a-k, commits `8277f07` → `5cb7150` → `d47e9b7`, 180 tests): FULL APP RUNTIME WIRED.** Engine start (libbox 1.14 `CommandServer.startOrReloadService` via `BoxEngine.kt`; TUN opened by Go `openTun` callback — fd never crosses to Dart; legacy establish/protect removed). Updates UI + workmanager 24h + latest.json single-producer (android metadata job). Routing 30/30 fields + groups 3-tier + TOR-CHAIN (detour; no chain outbound in 1.14). Groups/rules editors + stores, endpoint import→store→engine (6 protocols probed on real sing-box), AWG profile editor UI (todo-04 UI), wizard per-app→OverrideOptions, Windows sing-box.exe subprocess adapter, crash events via CommandClient log stream, live logs tab, diagnostics tab (Health module wired), tag selection, UI polish (l10n everywhere, TextScaler clamp 0.9-1.35, ReduceMotion), golden infra (matchesGoldenFile — caught+fixed real EndpointTile overflow). **All 5 tabs real screens; tabs.dart deleted.** Per-session details → `tasks/progress-2026-09-02.md`.
- **Engine truths probed on the real binary (do not re-derive):** aar has NO `Box` class (daemon architecture); `endpoints[].id/ip/ib` FATAL (WireSock-only — parse but never emit); tuic `alpn` must be under `tls.alpn`; reality REQUIRES utls; no `chain` outbound (chaining = `DialerOptions.detour`); CommandClient has only 6 commands (no service-status — crash detection = FATAL scan in log stream). Full list → `docs/decisions.tsv`.
- **2026-09-01 (sessions 1-7):** scaffold (Flutter 3.47.2/Dart 3.13.2/NDK 28/JDK 17), fork pinned `1.14.0-rc.1-awgm.15` SHA `57276220` (aar via Makefile + `with_awg`, javapkg `com.yourvpn`; Windows pivot = sing-box.exe subprocess), 17/17 todos (tunnel/geo/ingestion/routing/dns/awg deep modules + UI + health + updates + sec + CI + site + upstream tracking), 8-way review + critical fixes, 96 tests, git init (`5592cf3`).
- **Open (all need external resources):** on-device proof (no adb device), push/CI (no git remote — user creates repo), website polish, logical AND/OR rule-groups UI (compiler+store support it), on-device 7 leak tests. → `tasks/handoff.md`

## Pointers (keep top short, details behind pointers)

- Next session first read → `tasks/handoff.md` (60 sec) + latest `tasks/progress-*.md`
- Deep modules interface details → `SPEC.md:Architecture — Deep Modules`
- Build order + risks + verification → `tasks/plan.md`
- Why WG/AWG + routing vs pure WG → `goal.md:4-6` + `audit.md`
- Upstream rebase steps → `tasks/plan.md:Upstream tracker` + `go/amnezia-box` README
- Hallmark theme tokens → `docs/prototype-final.html` `:root` + `references/themes/`
