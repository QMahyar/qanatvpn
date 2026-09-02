# Scaffold — How to Start a Big Flutter+Go Project (YOURVPN) — Research-Driven

> Research date: 2026-08-30 — Sources: Very Good Ventures FFCA (`engineering.verygood.ventures`), VeryGood CLI (`cli.vgv.dev`), `flutter_architect` (pub.dev), `Ali-El-Khatib/flutter-production-starter`, `jassim-bashir/ultimate-flutter-project-template`, `amos5464/flutter-mobile-app-template`, `thynqit/blueprint-accelerator-flutter`, `samioda.com` monorepo Melos, `amirsheibani/Skeleton`. All via websearch 2026-08-30. This file is the decision behind `SPEC.md:Project Structure` and `tasks/todo.md:1`.

**Status:** FROZEN — use this to run `todo.md:1` scaffold. No `flutter create` guesswork.

> **Executed 2026-09-01 with real SDK** (see `tasks/progress-2026-09-01.md`): ran `flutter create --platforms=android,windows --project-name yourvpn --org com.yourvpn .` — produced `android/` (build.gradle.kts, settings.gradle.kts, gradle wrapper, AndroidManifest, res) + `windows/` (runner+CMake) + `.metadata`; removed default counter `test/widget_test.dart`. **Toolchain pinned:** Flutter **3.47.2** (`C:\tools\flutter`, Dart 3.13.2), Android **SDK 36**, NDK 28, JDK 17, Go 1.26.5 + gomobile. **Android 7+** = Flutter min API 24 (supported). Version note: `material_3_expressive` **1.x** requires Flutter ≥ 3.44 / Dart ≥ 3.12 + `material_ui`, so the spec's `3.41.9` pin was bumped to `3.47.2`. Pubspec fixed: `cue ^0.3.1`, `material_3_expressive ^1.1.1`, add `material_ui ^1.1.0`, `flutter_foreground_task ^11.0.1`. Non-go: `flutter analyze` clean, 154 deps resolved. **One deviation:** no `go/amnezia-box/submodules/wireguard-go` — the fork wires AmneziaWG via its own go.mod `replace`; root `go.mod` stale replace to be fixed at todo:2.

---

## 1. The question

You have one app (`yourvpn` Android+Win first) with **10+ features** (vpn, routing_editor, groups, logs, diagnostics, updates, profiles, settings, onboarding, health) and **10 modules** (`core`, `tunnel`, `routing`, `dns`, `ui`, `platform`, `sec`, `diag`, `l10n`, `updates`) that must stay deep (see `architecture-review-20260830-074725.html`). You will use AI agents (this AGENTS.md) and need deterministic targets (one legal home per artifact), bounded context (agent reads only `cart_presentation` plus its `cart_domain`, not whole repo), and mechanical enforcement (layer violation = compile error, not review comment).

**Three scaffolding families were compared:**

| Family | Top-level unit | Packages | When it wins | When it loses |
|---|---|---|---|---|
| **A. Layer-organized (classic)** — Very Good Layered Architecture, `lib/features/counter/` + `lib/core/` + `lib/shared/` inside one `yourvpn` package | Layer (data/domain/presentation as folders inside one package) | 1 package (`yourvpn`) | Single app, <3 features, no AI, no reuse | 10+ features → any feature spread across 3 layers, no package boundary for agent, import anything |
| **B. Feature-first folders inside one package (light FFCA)** — `lib/features/<feature>/data|domain|presentation/` + `lib/core/` + `lib/shared/` + `lib/app/` (used by `ultimate-flutter-project-template`, `Skeleton`, `flutter-clean-architecture-template`) | Feature as folder, layers as subfolders inside same package | Single app, 5-10 features, want folder-first without Melos overhead | Agent still sees whole repo as one package, can import anything — boundary is convention, not compiler |
| **C. Feature-first **packages** monorepo (FFCA)** — Very Good Ventures FFCA: `apps/mobile_app` + `features/product/product_domain` + `features/product/product_data` + `features/product/product_presentation` + `shared/ui_kit` as **separate Dart/Flutter packages** via Dart workspaces + Melos | Feature as **package**, each layer as separate package | AI-assisted, monorepo, multi-app reuse, 10+ features, need compile-time boundaries | Overhead of ~3 packages per feature, needs Melos + Dart workspaces + barrel files |

**Your case: B for MVP, graduate to C when second app appears.** Why: You have one app now (`yourvpn` Android+Win), 10 features, AI agents, 6 deep modules that need bounded context — B gives you feature-first folders with clean architecture dependency rule (`presentation → domain ← data`, `domain` pure Dart, no Flutter) and deterministic targets without Melos overhead. C's package boundaries would give compile-time enforcement and deferred loading (Flutter `deferred import` per feature, Android dynamic feature modules), but at the cost of ~30 packages + `melos bootstrap` + barrel files — worth it when you add `admin_app` or `kiosk_app` or split teams per feature. Start B, keep C's naming conventions so graduation is a `dart fix` + `melos.yaml`, not a rewrite.

---

## 2. Decision — B (feature-first folders inside one package) for MVP

**What B looks like (from `jassim-bashir` + `Skeleton` + `EngGemy95`):**

```
lib/
├── app/                    # App-wide: router (go_router), provider setup, app_bootstrap, app_shell, app_lifecycle, error_boundary
│   ├── router.dart         # GoRouter + ShellRoute bottom nav, AppRouterPath enum
│   └── di/                 # GetIt + injectable (or Riverpod composition root)
├── core/                   # Shared infrastructure, no feature code, no feature imports
│   ├── network/            # Dio ApiClient, interceptors, ETag cache, NetworkInfo
│   ├── storage/            # drift sqlite + flutter_secure_storage + Hive, SecureStorage/KeyValueStorage/MemoryCache contracts
│   ├── env/                # --dart-define-from-file, env_config.dart
│   ├── di/                 # service_locator.dart + feature injection
│   ├── error/              # Failure hierarchy (Sealed), exception mapping
│   ├── theme/              # M3E tokens: AppTheme (material_3_expressive) → M3ETheme, motor spring
│   ├── l10n/               # gen_l10n ARB (app_en.arb, app_fa.arb)
│   └── widgets/            # Reusable UI (AppButton, AppLoader) — no feature screens
├── design_system/          # Standalone ui_kit package later, now core/theme + tokens
│   ├── tokens/             # Spacing, Radius, Durations, AppTheme light/dark
│   └── widgets/            # AppCard, AppBottomNav, etc.
├── features/               # One folder per feature, each with data/domain/presentation
│   ├── vpn/
│   │   ├── data/           # datasources/ (remote/local) + models/ DTO toEntity + repositories/ Impl
│   │   ├── domain/         # entities/ + repositories/ (abstract interface Either<Failure, T>) + use_cases/
│   │   └── presentation/   # manager/ (Notifier/Provider + State) + pages/ + widgets/ + vpn_module.dart
│   ├── routing_editor/     # 30-field M3E, domain = RoutingPolicy, data = singbox ms, presentation = editor
│   ├── groups/             # 3-tier, domain = GroupTree
│   ├── logs/               # domain = HealthReport, data = drift + network_reachability Rust
│   ├── diagnostics/        # scanner 0-6, ping, traceroute
│   ├── updates/            # daily workmanager + GitHub
│   ├── profiles/           # subscriptions
│   └── settings/           # theme/network/tunnel/updates/security
├── shared/                 # Reusable, feature-agnostic: domain_models (Money, IDs), api_client, logging
│   ├── domain_models/      # stable primitives, not API DTOs
│   └── api_client/         # Dio setup, auth interceptors, retry
├── main_dev.dart / main_staging.dart / main_prod.dart  # Flavors
└── gen/                    # Generated assets (gen_l10n, assets)
```

**Layer rule (non-negotiable, from `ultimate-flutter-project-template` + `Skeleton`):**

```
presentation (UI) → domain (business logic, pure Dart, no Flutter) ← data (APIs, DB, mappers)
     |                        ^                         |
     |                        | implements               | depends on domain
     +------------------------+-------------------------+
                    domain is pure Dart, no Flutter imports
```

- `domain` has no Flutter imports. `data` depends on `domain`. `presentation` depends on `domain`, never on `data`.
- One responsibility per file. No shared mutable state. Explicit DI (GetIt + injectable or Riverpod). No hidden singletons. No cross-feature imports (goes via `core` or explicit dependency).
- Features must never import other features directly. Shared logic goes in `core` or `shared`.

**Naming (FFCA convention, keep for graduation):**

| Package (when you graduate to C) | Convention | Example now (folder) |
|---|---|---|
| Feature domain | `{feature}_domain` | `features/vpn/domain/` |
| Feature data | `{feature}_data` | `features/vpn/data/` |
| Feature presentation | `{feature}_presentation` | `features/vpn/presentation/` |
| Data with backend | `{feature}_data_{backend}` | `vpn_data_singbox` (later) |
| Shared | descriptive | `shared/ui_kit`, `shared/api_client` |

**Barrel files:** Each layer has `lib/{feature}_{layer}.dart` + subfeature barrels per screen. App imports `package:yourvpn/features/vpn/presentation/vpn_module.dart`, not deep paths.

---

## 3. Three scaffold commands — pick one, all produce B, C is next step

### Option A — `flutter create` + `flutter_architect` (fastest, Clean or MVVM, flavors, l10n, CI)

For when you want a CLI that scaffolds B with your choices and generates feature skeletons.

```bash
# 0. Create base — run from empty repo root (no nested yourvpn/yourvpn)
flutter create . --project-name yourvpn --org com.yourvpn --platforms android,windows

# 1. Scaffold B with YOURVPN stack (not generic Dio+GetIt)
# Use flutter_architect only for folder skeleton, then fix pubspec to SPEC.md:37
dart pub global activate flutter_architect
flutter_architect init
# prompts:
# Architecture: Clean Architecture
# State: Riverpod
# Routing: GoRouter
# Networking: REST (http) — replace Dio with http per SPEC
# DI: Riverpod (not GetIt) — align to SPEC riverpod 2.0
# Localization: Yes → locales en, fa
# Flavors+env: No (YAGNI — add later)
# CI/CD: GitHub Actions
# Auth/sample: No (you add vpn)

# After init, align pubspec.yaml to SPEC pin:
# flutter_riverpod 2.0 + go_router + drift + flutter_secure_storage + http + flutter_cache_manager
flutter pub add flutter_riverpod go_router drift flutter_secure_storage http flutter_cache_manager workmanager package_info_plus fl_chart drift_flutter
# Produces: lib/app/ + lib/core/ + lib/features/ + l10n/ — verify no cross-feature imports

# 2. Add a feature in one command (only vpn first, not 10 at once)
flutter_architect create feature vpn --feature vpn
# Paths auto-chosen: features/vpn/presentation/pages/home/ etc.

# 3. Verify
flutter pub get && dart run build_runner build --delete-conflicting-outputs
flutter analyze && dart format --set-exit-if-changed .
```

*Why this fits you:* `flutter_architect` respects your `Clean Architecture` choice, generates `features/vpn/data|domain|presentation/` with `toEntity()` mappers, wires `service_locator.dart` automatically, and gives `screen`/`widget` micro-generators that put files in the single legal home — deterministic targets for AI agents. Used by `EngGemy95` production ready template.

### Option B — `very_good_cli` FFCA monorepo (when you graduate to C)

For when you have 2+ apps or split teams and need compile-time boundaries + Melos.

```bash
dart pub global activate very_good_cli

# App: Very Good Core (single feature counter, but scalable: lib/app/ + lib/features/counter/ + core)
very_good create flutter_app yourvpn --desc "YourVPN" --org "com.yourvpn"

# Then convert to FFCA monorepo per engineering.verygood.ventures:
mkdir -p apps/mobile_app features/vpn/vpn_domain features/vpn/vpn_data features/vpn/vpn_presentation shared/ui_kit
# Move lib/ into apps/mobile_app/lib/ + features/vpn/* + shared/ui_kit/lib/
# Add Dart workspaces: root pubspec.yaml with workspace: [apps/*, features/*/*, shared/*]
# Add melos.yaml with scripts: bootstrap, analyze, test, generate
melos bootstrap
melos run analyze && melos run test
```

*Why not now:* Overhead of ~30 packages + `melos bootstrap` + barrel files for one app. Keep B's folder structure but use FFCA's naming and dependency rule so `very_good create` is a `dart fix` away.

### Option C — Manual `jassim-bashir/ultimate-flutter-project-template` clone (most control, 5 layers)

For when you want the 5-layer `app/core/design_system/features/shared` with `main_dev.dart` + `gen/` and a decision tree.

```bash
git clone https://github.com/jassim-bashir/ultimate-flutter-project-template yourvpn
cd yourvpn && flutter pub get
# Follow docs/architecture/lego_features.md: features as LEGO modules with intentional public APIs
# Keep: lib/app/ (app_bootstrap, app_shell) + lib/core/ (network, storage, env, di, security) + lib/design_system/ (tokens) + lib/features/<feature>/data|domain|presentation/ + lib/shared/
```

*Why this fits you:* The 5-layer layout (`app/core/design_system/features/shared`) is the closest to `SPEC.md:Project Structure` (which already has `lib/app/` + `lib/core/` + `lib/features/vpn/` + `lib/design_system/` + `lib/shared/`). It has a decision tree (what to use/delete) and a `core` that is stable, opinionated, with explicit public APIs — good for AI agents.

---

## 4. Recommended path for YOURVPN (per todo.md:1)

**Now (MVP, one app, 10 features, AI agents):** **Option A with B structure** — `flutter create yourvpn` + `flutter_architect init` (Clean + Riverpod + GoRouter + Dio + GetIt + en,fa + GitHub Actions). This gives you `lib/app/` + `lib/core/` + `lib/features/` + `lib/shared/` + `lib/design_system/` + `lib/l10n/` + `main_dev.dart` in 2 commands, with barrel files and `service_locator.dart` wired. Keep dependency rule `presentation → domain ← data` and `features never import other features` from day one — that is the real gain, not the tool.

**Graduate to C (FFCA packages) when:** you add second app (`apps/admin_app` for SlipGate-like server) or split teams per feature (`tunnel` vs `routing` vs `diag`) and need `melos` + `Dart workspaces` to make `cart_presentation` import failure a compile error. The package boundaries then give AI agents bounded context (only `cart_domain` + `shared` resolve when working in `cart_presentation`) and mechanical enforcement via `analyzer` hook. Until then, B's folders + `analysis_options.yaml` custom lint (`import 'package:yourvpn/features/**'`) is enough.

**If you hate CLIs:** Option C clone + `melos` manually is the same B, just with more docs.

---

## 5. Skeletons to create on day one (so every feature has one legal home)

Per `SPEC.md:Project Structure` + `tasks/todo.md:1`, create these empty skeletons before any logic (all ≤5 files per task, but scaffolding is one task that creates the tree):

```bash
# After flutter_architect init — YAGNI: create only 2 dirs now, features lazily per todo
mkdir -p lib/l10n lib/app

# Verify boundaries (no cross-feature imports yet)
flutter pub get && dart run build_runner build --delete-conflicting-outputs
flutter analyze  # must show no cross-feature import errors
flutter test

# Deep modules skeletons (single legal homes per SPEC.md:Architecture — keep SPEC paths)
touch lib/core/services/tunnel.dart  # 03 Deep — owns Dart↔Kotlin↔Go seam (not lib/modules/tunnel/)
touch lib/modules/routing/routing_compiler.dart  # 01
touch lib/modules/vpn/repositories/ingestion/ingestion_adapter.dart  # 02
touch lib/modules/vpn/amnezia/awg_profile.dart  # 04
touch lib/modules/geo/geo_asset.dart  # 05
touch lib/modules/health/health.dart  # 06

# L10n — create ARB skeleton first
mkdir -p lib/l10n && touch lib/l10n/app_en.arb lib/l10n/app_fa.arb
flutter gen-l10n  # from lib/l10n/app_en.arb + app_fa.arb

# Future dirs (do NOT pre-create until todo touches them):
# go/amnezia-box, go/xray-core, go/tor, rule_sets/, assets/geoip, profiles/, test/updater etc. — see AGENTS.md YAGNI
```

**Skeletons are not logic.** They are empty files with `// TODO: deep module per SPEC.md:Architecture — Deep Modules, interface: ...` and a failing test that asserts the file exists. This satisfies `tunnel` checkpoint `FakePlatformAdapter` test before any UI.

---

## 6. How this scaffold serves 6 deep modules

| Deep module | Where it lives in scaffold | Interface file (single source of truth) |
|---|---|---|
| 03 Tunnel | `lib/core/services/tunnel.dart` (deep, owns Dart↔Kotlin↔Go seam) + `android/.../ForegroundService.kt` thin adapter | `Tunnel.connect(tag) -> TunnelState` |
| 01 RoutingCompiler | `lib/modules/routing/routing_compiler.dart` | `compile(RoutingPolicy) -> CompiledRoute` — note: `lib/modules/` = `lib/features/` in scaffold B; single legal home |
| 02 IngestionAdapter | `lib/modules/vpn/repositories/ingestion/ingestion_adapter.dart` | `parseAndNormalize(RawSubscription) -> List<NormalizedEndpoint>` sealed union |
| 04 AmneziaWG | `lib/modules/vpn/amnezia/awg_profile.dart` + `awg_config.dart` | `AwgProfile.fromPreset()` / `generateRandom()` |
| 05 GeoAsset | `lib/modules/geo/geo_asset.dart` | `ensure(tag) -> Path` always via `initial_path` |
| 06 Health | `lib/modules/health/health.dart` | `snapshot() -> HealthReport` + `stream` |

Each lives in one package/folder, not scattered. `domain` is pure Dart, `data` depends on `domain`, `presentation` depends on `domain` — so `drift` (data) can be swapped without touching `HealthReport` (domain). The 30-field editor lives in `routing_editor/presentation`, not in `core`.

---

## 7. What to run after scaffolding (per SPEC.md:Verification Checkpoints)

```bash
flutter analyze && dart format --set-exit-if-changed . && golangci-lint run ./...
flutter test --coverage  # ≥70% for routing_editor + services
sing-box check -c profiles/config.wg-awg.json
sing-box rule-set compile schemas/geosite-cn.json -o rule_sets/geosite-cn.srs
flutter gen-l10n && flutter test test/l10n/
# Leak tests before tag: ipleak.net + dnsleaktest.com + browserleaks.com + 7 scenarios
```

If any fails, the scaffold is wrong — fix the boundary, not the test.

---

**This scaffold file is the answer to “what’s the best way to start a big Flutter+Go project.” Use Option A now, keep FFCA naming so `melos bootstrap` is a one-line graduation later. All paths above are the single legal homes — ask two agents where a new mapper belongs and they land in the same directory.**
