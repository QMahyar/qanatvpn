# QanatVPN Project Map

> Per-module summaries with key files + established patterns. Load ONLY the
> section your task needs. Companion to AGENTS.md (index) and
> tasks/handoff.md (session state).

## app/ — shell, routing, theme

- `lib/app/app.dart`: GoRouter ShellRoute, 5 tabs + /settings + /updates,
  MaterialApp with themeMode/locale from settings providers, wizard gate,
  TextScaler clamp 0.9–1.35.
- Pattern: riverpod NotifierProvider per concern; providers overridden in
  `lib/main.dart` with real adapters.
- Tests: `test/golden/home_golden_test.dart` (Windows-rendered goldens —
  skip silently off-Windows), `test/settings/`.

## core/services/ — the engine seam (most critical code)

- `lib/core/services/tunnel.dart`: deep module. `connect(tag) -> TunnelState` guarded sequence
  grant → battery → airplane → foreground → establish → protect → start →
  firewall. Every failure path → `_block(reason, detail)` (fail closed,
  firewall enforced). Auto-reconnect loop (exp backoff 1–16s, cap 5,
  exhaustion → blocked with detail). `blockDetail` carries engine FATAL text.
- `lib/core/services/windows_box_process.dart`: sing-box.exe subprocess adapter.
  `resolveWindowsExe()` probes bundle-root before dev layout. Writes config
  to %TEMP% (qanatvpn_box_*.json).
- `lib/core/services/channel_adapters.dart`: MethodChannel `vpn_service` bridge; FATAL scan →
  crash events.
- `lib/core/services/desktop_platform_adapter.dart`: Windows safe defaults
  (engineManagedTun=true).
- `lib/core/services/flag_secure.dart`: FLAG_SECURE bracketing for credential screens.
- Pattern: adapters are interfaces (`BoxAdapter`, `PlatformAdapter`, …);
  fakes live in `test/tunnel/tunnel_test.dart`; epoch counter invalidates
  stale in-flight connects.
- Tests: `test/tunnel/` (the deepest suite — state machine + P0 hardening +
  reconnect).

## core/persistence/ — storage primitives

- `lib/core/persistence/app_paths.dart`: cross-platform dir resolution (path_provider at startup,
  legacy `~/.yourvpn` migration; workmanager isolates re-resolve via
  `resolveAppSupportDir()`). Stores accept `baseDir` (tests inject temp dirs).
- `lib/core/persistence/atomic_write.dart` (tmp+rename), `lib/core/persistence/debounced_saver.dart` (300ms coalesce;
  `flushPendingWrites()` before external writes).
- Pattern: sync file IO with startup-cached dir; never compute paths from
  env vars directly — use `defaultBaseDirSync()`.
- Tests: `test/core/`.

## modules/vpn/ — endpoints, ingestion, selection

- `lib/modules/vpn/repositories/ingestion/parsers.dart`: share-link parsers
  (vless/vmess/ss/trojan/hysteria2/tuic/wg). Rules: per-line errors are
  FormatException (TypeError/RangeError caught upstream in
  `parseShareLines`); userinfo percent-decoded (`decodedUserInfo`); port
  range validated (`sharePort`); vmess fields type-checked.
- `lib/modules/vpn/repositories/ingestion/ingestion_adapter.dart`: content-sniffing +
  6h cache (pasted imports keyed by content hash) + isolate parse for >64KB.
- `lib/modules/vpn/repositories/endpoint_store.dart` + `lib/modules/vpn/repositories/endpoints_controller.dart`:
  dedupe-by-tag; URL imports register managed subscriptions
  (HTTPS-only enforced).
- `lib/modules/vpn/repositories/selection_store.dart` + `lib/modules/vpn/logic/selected_endpoint.dart`:
  persisted user selection; resolution user → group → endpoint → vendored;
  `clearInvalid(tag)` on delete.
- `lib/modules/vpn/logic/vpn_notifier.dart`: VpnState phase/tag/blockReason/blockDetail.
- `lib/modules/vpn/amnezia/awg_config.dart`: presets + `generateRandom()` + invariant
  validation (H1∩H2=∅, S1+56≠S2, Jmax<MTU).
- Pattern: `NormalizedEndpoint` sealed union; toJson re-serializable.
- Tests: `test/vpn/` (largest area), `test/ingestion/`.

## modules/routing/ — the 30-field rule compiler

- `lib/modules/routing/routing_policy.dart`: RouteRule (30 fields), OutboundGroup
  (selector/urltest incl. idle_timeout + interrupt_exist_connections),
  TorChainOptions (socks 127.0.0.1:9050, never type:tor).
- `lib/modules/routing/routing_compiler.dart`: compile to engine JSON; `action: reject` for
  BLOCK; accumulates ALL errors for the editor.
- `lib/modules/routing/config_assembler.dart`: tun (auto_route, strict_route) + firewall
  baseRules first + user rules after.
- Stores: `lib/modules/routing/rule_store.dart`, `lib/modules/routing/policy_store.dart` (+groups) with debounced
  coalescing; controllers expose `flushPendingWrites()`.
- Tests: `test/routing/` incl. real `sing-box check` runs (skipped off-Windows
  via test-level `skip:`).

## modules/geo/ — rule-set pipeline

- `lib/modules/geo/geo_asset.dart`: registry (geosite-cn, geoip-cn); `ensure(tag)` = cache →
  bundled initial asset → download; `ruleSetEntries()` emit LOCAL entries
  pointing at seeded files (never remote-only). ETag refreshAll with 6h
  stale-while-revalidate + rate-limit signaling.
- Seeded at startup in `lib/main.dart` (`_seedGeoAssets`).
- Tests: `test/geo/`, real-binary SRS round-trip in `test/routing/`.

## modules/updates/ — daily updates + sha256-verified install

- `lib/modules/updates/updater.dart`: UpdateFetcher (GitHub API; 403-with-ratelimit →
  GitHubRateLimitException, plain 403 → HttpException), UpdateSource
  (API → gh-pages mirror fallback), UpdateStore (StoredUpdate envelope),
  `resolvePlatformKey()` fail-closed per ABI.
- `lib/modules/updates/update_installer.dart`: download → sha256 verify (sibling `.sha256` or
  release-body digest) fail-closed → platform install (Android FileProvider
  verified blob / Windows explorer reveal).
- Daily workmanager task: update check + subscription refresh
  (`subscriptionsRefreshBackgroundTask` → testable
  `subscriptionsRefreshWithStores`).
- Tests: `test/updates/`, `test/updater/`, `test/p0/`.

## modules/settings/ — user preferences

- `lib/modules/settings/settings_store.dart` (Settings{themeMode, language, autoConnect,
  reconnectEnabled}), `lib/modules/settings/settings_controller.dart` (effectiveThemeMode/
  effectiveLocale providers consumed by MaterialApp), `lib/modules/settings/settings_screen.dart`.
- Pattern: every change persists immediately; tests seed store files
  synchronously (never await store.save inside fake-async).

## modules/sec/ — firewall policy

- `lib/modules/sec/firewall.dart`: FirewallPolicy.baseRules (hijack-dns, v6/LAN reject)
  + validateOrdering; injected into EVERY loaded profile by
  `lib/modules/vpn/repositories/profile_config_source.dart` (`_withKillSwitchGuarantees`) and every
  generated config by `lib/modules/routing/config_assembler.dart`.
- `PolicyFirewallAdapter.enforce()` validates ordering fail-closed.
- Tests: `test/sec/firewall_test.dart`.

## modules/health/ + logs/ — observability

- `lib/modules/logs/log_bus.dart`: ring buffer + repeat-collapse + **secret redaction**
  ([REDACTED] for key/password/psk patterns — W3.2).
- `lib/modules/health/health.dart`/`diagnostics_*`: FATAL-scan probe reporting.
- Tests: `test/logs/log_bus_caps_test.dart` (incl. redaction),
  `test/health/`.

## modules/onboarding/ — wizard + split

- `lib/modules/onboarding/split_store.dart` also carries the `wizardDone` completion marker
  (cold start skips a completed wizard; `skipAll()` ends the consent
  dead-end).
- Tests: `test/onboarding/wizard_test.dart`.

## android/ — Kotlin bridge (com.qanatvpn.app)

- `QanatVpnService` (owns TUN), `BoxEngine` (CommandServer wrapper, FATAL
  scan), `VpnServiceBridge` (vpn_service channel + FileProvider install +
  setFlagSecure), `ForegroundService`, `BatteryOptHelper`, `MainActivity`.
- libbox.aar: REBUILT with javapkg com.qanatvpn (regenerate via
  `make lib_android` — needs clean env, see AGENTS.md gotchas).
- Tests: widget/engine tests in Dart; on-device checks pending.

## windows/ — runner + subprocess engine

- `runner/engine_job.cpp`: kernel job object (KILL_ON_JOB_CLOSE) —
  sing-box.exe dies with the app.
- Engine = `windows/sing-box.exe` (1.14.0-rc.1-awgm.15 with_awg) — resolve
  via `resolveWindowsExe` (bundle root first).

## CI (.github/workflows/) — release chain

- Tag push v* → build-android (3 ABI APKs + sha256) + build-windows (zip +
  sha256) → metadata job (latest.json) → release assets.
- Dispatch runs: same builds upload as run artifacts (no tag → no release).
- gh-pages: deploy site + latest.json; dispatch from master with
  `-f release_tag=vX.Y.Z` (env protection rejects tag refs).
- latest.json contract: {version, platforms: {key: {url, version, sha256}}}
  consumed by lib/modules/updates.
