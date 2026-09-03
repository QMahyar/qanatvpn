# Handoff — YOURVPN — full app runtime committed (read this first, 60 sec)

## Repo state
- **Git `master`, 4 commits:** `5592cf3` (MVP core) → `a1fab54` (docs) → `8277f07` (full app runtime, sessions 8a-j) → `5cb7150` (advanced editors) → `d47e9b7` (AWG profile editor). **No remote — user creates repo, then push + tag `v0.1.0` → 3-job release + gh-pages run for real.**
- **180 tests green, `flutter analyze` clean, `sing-box check -c profiles/config.wg-awg.json` exit 0, debug APK builds, real sing-box.exe spawn/kill smoke green.**
- **All 5 tabs are real screens** (home, groups editor, rules editor, live logs, diagnostics) — `tabs.dart` deleted. Binary artifacts (aar/exe) gitignored; fork pinned as gitlink at `go/amnezia-box` SHA `57276220` (tag `1.14.0-rc.1-awgm.15`).

## Engine truths probed on the real binary (do NOT re-derive)
- aar (libbox 1.14) has **NO `Box` class** — daemon architecture: `Libbox.setup` → `newCommandServer` → `startOrReloadService(config)`; TUN fd comes from Go calling **back** into Kotlin `PlatformInterface.openTun` (fd never crosses to Dart; `PlatformAdapter.engineManagedTun=true` on Android AND Windows).
- `endpoints[].id/ip/ib` **FATAL** (WireSock-only — parse from INI but never emit; `AwgValues.toEngineJson`).
- tuic `alpn` must be under `tls.alpn`; **reality REQUIRES utls**; vmess tls/transport are siblings.
- **No `chain` outbound** — chaining = `DialerOptions.detour` (TOR-CHAIN = socks 127.0.0.1:9050 + endpoint detour).
- CommandClient has only **6 commands** (no service-status) — crash detection = FATAL scan in the log stream while engineRunning.
- Route fields verified in `option/rule.go`: `ip_version` enum 4/6, `port_range` `min:max`, `user_id` int32, `ip_is_private` bools; urltest `interval` is a duration string (`5m`).

## Key files map
- **Engine seam:** `android/.../BoxEngine.kt` (setup+CommandServer+PlatformInterfaceWrapper+log watcher), `YourVpnService.kt` (openTun target), `VpnServiceBridge.kt` (`vpn_service` + `box_events` channels), `lib/core/services/tunnel.dart` (guarded deep seam), `channel_adapters.dart` (channel impls), `windows_box_process.dart` (subprocess engine), `desktop_platform_adapter.dart`.
- **Config pipeline:** `lib/modules/vpn/repositories/profile_config_source.dart` (merges split + endpoints + groups + rules into the vendored profile; broken pieces ship unmodified, never FATAL the engine) ← `endpoint_store.dart`, `../routing/policy_store.dart` + `rule_store.dart`, `../onboarding/split_store.dart`; builders in `ingestion/endpoint_outbound.dart` + `../amnezia/awg_config.dart` (`wireGuardEndpointToJson`).
- **Editors/UI:** `routing/groups_*`, `routing/rules_*`, `vpn/amnezia/awg_profile_screen.dart`, `vpn/repositories/endpoints_screen.dart`, `updates/updates_screen.dart`, `logs/log_bus.dart` + `logs_screen.dart`, `health/diagnostics_*`.
- **Selection:** `vpn/logic/selected_endpoint.dart` (group default → first endpoint → vendored tag).
- Spec gate: `SPEC.md` · frozen intent: `goal.md` · glossary: `CONTEXT.md` · plan: `tasks/plan.md` · todos: `tasks/todo.md` (17/17) · progress: `tasks/progress-2026-09-02.md` · decisions: `docs/decisions.tsv` (40+ rows) · CI: `.github/workflows/` (latest.json single producer = build-android `metadata` job).

## Next session (in value order)
1. **On-device proof (needs device):** `flutter install` → wizard → connect → verify tun0 + proxied egress + crash events + logs (placeholder keys = handshake fails, expected). Then the 7 leak tests (`scripts/leak_test.sh`).
2. **Push/CI (needs user):** `git remote add origin <url>` → push → tag `v0.1.0` → 3-job release + gh-pages run for real; verify latest.json lands complete.
3. **Implementable leftovers:** logical AND/OR rule-groups UI (compiler+store already support it), advanced rules fields (process_path/user_id etc. — compiler done), website polish, DNS fake-ip-filter-mode (fork schema lacks it — documented).

## Verify (30 sec)
```
& C:\tools\flutter\bin\flutter.bat test --no-pub        # +180 all pass
& C:\tools\flutter\bin\flutter.bat analyze              # No issues
windows\sing-box.exe check -c profiles/config.wg-awg.json  # exit 0
git log --oneline -4                                    # d47e9b7 … 5592cf3
```

## Command cheatsheet
- Build engine: `pwsh scripts/libbox.ps1 main` (aar) / `windows` (exe); CI: `make lib_android`
- Regenerate profile: `& C:\tools\flutter\bin\dart.bat run tool\gen_profile.dart`
- Golden regen: `flutter test --update-goldens test/golden`
- Full verify: analyze + test + sing-box check (above)
