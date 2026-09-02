# Handoff — YOURVPN — post-review state (read this first, 60 sec)

## Repo state
- **Git initialized, root commit `5592cf3`** ("feat: YOURVPN MVP core — 17/17 todos, 96 tests"). Binary artifacts (aar/exe) gitignored; fork pinned as gitlink at `go/amnezia-box` SHA `57276220`.
- **96 tests green, `flutter analyze` clean, `sing-box check -c profiles/config.wg-awg.json` exit 0, debug APK builds.**
- All 17 todos done + 8-way parallel review complete + critical/high findings fixed.

## Post-review fixes already applied (session 7)
- Workflow parse blocker + signing-before-build + latest.json attached + permissions
- Health RangeError, epoch reset parsing, routing 1.14 fatal fields (geosite→rule_set, int ports, action:reject, selector member, default_domain_resolver)
- Ingestion base64 standard-alphabet + multi-peer INI + fuzz contract
- Tunnel epoch race guard, leak_test.sh grep, wizard RTL

## Open findings — next session work, in value order
1. **Engine runtime start (highest value):** Kotlin `YourVpnService` needs a `box.start(config)` path calling `com.yourvpn.libbox.Box` (aar classes already present). Until then connect() safely blocks at box.start → UI shows Blocked. Files: `YourVpnService.kt`, new `BoxAdapter` channel method pair (`boxStart`/`boxStop`), Dart `LibboxBoxAdapter` in `tunnel.dart`.
2. **Kotlin bridge races:** establish callback queue (two rapid establish → first Result dropped), orphaned fd when callback-less onStartCommand, closeFd when INSTANCE null. `VpnServiceBridge.kt:102`, `YourVpnService.kt:24`.
3. **Updates→UI wiring:** `UpdateFetcher` has no screen; workmanager daily registration not in main.dart; latest.json single-producer race (android+windows workflows both write; gh-pages copies repo-root file nothing commits).
4. **AWG gaps:** Id/Ip/Ib fields parsed but never validated/generated; IPv6 peer endpoints break `split(':')` in `awg_config.dart:122`.
5. **Routing depth:** 24/30 fields (missing ip_version, port_range, source_port_range, process_path, user_id, ip_is_private); groups/3-tier (auto→selector→proxy) + TOR-CHAIN seam unbuilt (`RoutingPolicy.groups` absent).
6. **UI polish:** nav labels hardcoded EN (`app.dart:123`), `blockReason!.name` raw enum, no TextScaler clamp, no ReduceMotion guard, M3E widget pass + 200% goldens, fake `listeners`→vmess sentinel in ingestion, DNS fake-ip-filter-mode not serializable in fork schema (documented).

## Key files map
- Spec gate: `SPEC.md` · frozen intent: `goal.md` · glossary: `CONTEXT.md` · plan: `tasks/plan.md` · todos: `tasks/todo.md` (17/17 + notes)
- Deep modules: `lib/core/services/tunnel.dart`, `lib/modules/geo/geo_asset.dart`, `lib/modules/vpn/repositories/ingestion/`, `lib/modules/routing/`, `lib/modules/dns/`, `lib/modules/vpn/amnezia/`, `lib/modules/health/`, `lib/modules/updates/`, `lib/modules/sec/`
- Kotlin seam: `android/.../YourVpnService.kt`, `VpnServiceBridge.kt`, `ForegroundService.kt`, `BatteryOptHelper.kt`
- Engine: `Makefile` + `scripts/libbox.ps1` (twins) · `profiles/config.wg-awg.json` via `tool/gen_profile.dart`
- CI: `.github/workflows/` (5 files) · site: `docs/site/index.html`
- Trackers: `tasks/progress-2026-09-01.md` (7 sessions) · `docs/decisions.tsv` (28 rows) · this file

## Verify (30 sec)
```
& C:\tools\flutter\bin\flutter.bat test        # +96 all pass
& C:\tools\flutter\bin\flutter.bat analyze     # No issues
windows\sing-box.exe check -c profiles/config.wg-awg.json  # exit 0
git log --oneline                              # 5592cf3 root commit
```

## Command cheatsheet
- Build engine: `pwsh scripts/libbox.ps1 main` (aar) / `windows` (exe); CI: `make lib_android`
- Regenerate profile: `& C:\tools\flutter\bin\dart.bat run tool\gen_profile.dart`
- Full verify: analyze + test + sing-box check (above)
