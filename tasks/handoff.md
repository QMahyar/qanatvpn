# Handoff — YOURVPN — engine-runtime-start wired (read this first, 60 sec)

## Repo state
- **Git initialized, root commit `5592cf3`** ("feat: YOURVPN MVP core — 17/17 todos, 96 tests"). Binary artifacts (aar/exe) gitignored; fork pinned as gitlink at `go/amnezia-box` SHA `57276220`.
- **176 tests green, `flutter analyze` clean, `sing-box check -c profiles/config.wg-awg.json` exit 0, debug APK builds, real sing-box.exe smoke green.**
- **All 5 tabs are real screens** (home, groups editor, rules editor, live logs, diagnostics health) — tabs.dart deleted.
- All 17 todos done + 8-way parallel review complete + critical/high findings fixed + **engine runtime start wired (session 8, 2026-09-02)**: libbox 1.14 `CommandServer.startOrReloadService` behind `boxStart`/`boxStop` channel methods, TUN opened by Go `openTun` callback into Kotlin `PlatformInterfaceWrapper`, `tunnelProvider` fully wired in main.dart. Legacy Dart-side establish/protect removed on Android (engine-managed TUN).
- **Updates→UI wired + latest.json race fixed (session 8b):** UpdateStore/UpdateSource/controller/screen + workmanager 24h + UpdateTile; build-android `metadata` job is now the single latest.json producer (waits for windows asset, uploads --clobber); gh-pages pulls it from the release. **AWG gaps closed:** Id/Ip/Ib parsed but never emitted to engine (probe: fork FATALs on `id` — WireSock-only keys), IPv6 bracket-aware endpoint split validated against real sing-box.
- **Routing 30/30 + groups 3-tier + TOR-CHAIN seam (session 8c):** 6 missing rule fields added (fork-native shapes verified in option/rule.go); OutboundGroup selector/urlTest with all-at-once member validation; TOR-CHAIN = socks sidecar + endpoint `detour` (1.14 has no chain outbound — probed). 3-tier + detour configs pass real sing-box check.

## Post-review fixes already applied (session 7)
- Workflow parse blocker + signing-before-build + latest.json attached + permissions
- Health RangeError, epoch reset parsing, routing 1.14 fatal fields (geosite→rule_set, int ports, action:reject, selector member, default_domain_resolver)
- Ingestion base64 standard-alphabet + multi-peer INI + fuzz contract
- Tunnel epoch race guard, leak_test.sh grep, wizard RTL

## Open findings — next session work, in value order
1. **On-device engine start proof (needs a device/adb):** sessions 8a-j wired everything implementable headless — engine start, updates, routing 30/30 + groups + rules editors + TOR-CHAIN, UI polish + goldens, Windows subprocess engine, per-app split, endpoint import→engine, tag selection, log-stream crash events, live logs tab, diagnostics health tab. 176 tests + analyze + apk green. Remaining on device: install APK, tap connect, prove tun0 + lifecycle + crash-event firing (placeholder keys = handshake fails, expected).
2. **CI first real run** (needs push + tag — no commits requested yet); website polish; advanced rules-editor fields (compiler supports all 30; UI additions possible).
3. **DNS fake-ip-filter-mode** not serializable in fork schema (documented).

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
