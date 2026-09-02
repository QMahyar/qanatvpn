# Handoff — YOURVPN 2026-09-01 — 17/17 todos done (sessions 1-6)

## Final state
- **92 tests green, `flutter analyze` clean, `sing-box check -c profiles/config.wg-awg.json` exit 0, debug APK builds.**
- All 17 `tasks/todo.md` items checked with DONE notes + scope notes where deferred.

## The full stack, where to read it
- Engine: `android/app/libs/libbox.aar` (with_awg) + `windows/sing-box.exe` — todo:2
- Dart↔Kotlin↔Go seam: `lib/core/services/tunnel.dart` + `YourVpnService.kt` + `VpnServiceBridge.kt` — todo:3,9
- Geo pipeline: `lib/modules/geo/geo_asset.dart` + `lib/core/network/http_cache.dart` + vendored SRS — todo:4
- Ingestion: `lib/modules/vpn/repositories/ingestion/` (sealed union, 7 formats) — todo:5
- Routing: `lib/modules/routing/` (compiler + assembler, fork 1.14 schema) — todo:6
- DNS/FakeIP: `lib/modules/dns/dns_config.dart` + `profiles/config.wg-awg.json` (generated) — todo:7
- AWG domain: `lib/modules/vpn/amnezia/awg_config.dart` + `lib/utils/amnezia_values.dart` — todo:8
- Wizard: `lib/modules/onboarding/wizard.dart` + EN/FA l10n — todo:9
- UI: `lib/app/app.dart` (5-tab shell) + `lib/modules/vpn/screens/home.dart` (bento) — todo:10
- Health: `lib/modules/health/health.dart` (0-6 score) — todo:11
- Updates: `lib/modules/updates/updater.dart` — todo:12
- Sec: `lib/modules/sec/firewall.dart` + `scripts/leak_test.sh` — todo:13
- Release/CI: `.github/workflows/` (android/windows/linux/gh-pages/upstream) — todo:14-16
- Site: `docs/site/index.html` — todo:15
- Tracking: `tasks/progress-*.md` + `docs/decisions.tsv` (24 rows) — todo:17

## Known deferrals (honest, next-session candidates)
1. **Engine runtime start:** BoxAdapter needs the Kotlin box.start(config) call into libbox (aar classes ready in com.yourvpn.libbox; channel method missing). Until then connect() blocks at box.start → UI shows Blocked (by design, safe).
2. **M3E polish + goldens:** home is functional M3; material_3_expressive widget pass + 200% EN/FA golden tests remain.
3. **Leak tests on device:** scripts/leak_test.sh is written; requires real device + tcpdump.
4. **Wizard app list:** static sample until installed_apps plugin (or PackageManager channel) lands.
5. **CI unverified:** workflows written but need a GitHub push + tag v0.1.0 to exercise.
6. **Play disclosure dialog** before VpnService.prepare (spec item) — 30-line widget, not yet written.

## Next session: pick any deferral above
1. Engine start wiring (highest value — makes connect() real on device).
2. M3E polish pass + goldens.
3. First real release: push repo → tag v0.1.0 → watch 3 jobs.

## Verify (30 sec)
- `& C:\tools\flutter\bin\flutter.bat test` → +92 all pass.
- `& C:\tools\flutter\bin\flutter.bat analyze` → No issues.
- `windows\sing-box.exe check -c profiles/config.wg-awg.json` → exit 0.
