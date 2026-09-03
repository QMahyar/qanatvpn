# Handoff — YOURVPN — production hardening done, uncommitted (60 sec)

## Repo state
- **Git `master`, 5 commits** (`16a270e` latest). **Working tree DIRTY: 23 modified + `pubspec.lock` untracked** — the whole session below is uncommitted. Next: review `git diff`, `git add pubspec.lock` + files, commit, then push + tag `v0.1.0` (no remote yet — user creates repo).
- **194 tests green** (+14 new), **`flutter analyze` clean**, **`sing-box check` exit 0**, real exe smoke green.
- Session: `prod-audit` workflow (9 dims → 123 raw → adversarial vote → 39 confirmed; ~102 late verifiers 502'd, synthesis OK) → fixed all 14 P0 + exe-gated skips. Details: `tasks/progress-2026-09-03.md`, decisions: `docs/decisions.tsv` (+14 rows).

## Engine truths (do NOT re-derive — prior handoff still holds)
- aar (libbox 1.14) has **NO `Box` class** — daemon arch; TUN fd via Go→Kotlin `openTun`; `engineManagedTun=true` both platforms.
- `endpoints[].id/ip/ib` **FATAL**; tuic `alpn` under `tls.alpn`; reality REQUIRES utls; no `chain` outbound (detour); CommandClient 6 commands only (FATAL-scan crash detection).
- NEW: `outbound: BLOCK` passes `sing-box check` (probed); `reject`-action vs `BLOCK`-outbound both valid — compiler emits `reject`, firewall policy asserts `BLOCK` shape.
- NEW: `windows/sing-box.exe` must be spawned via absolute path (`p.join(Directory.current.path, ...)`) — relative path breaks Win process lookup in tests.

## What changed this session (files)
- Engine: `core/services/tunnel.dart` (Timeouts+epoch+connecting-crash), `channel_adapters.dart` (30/10s), `windows_box_process.dart` (LogBus pipes), `main.dart` (fail-closed firewall adapter), `vpn/logic/vpn_notifier.dart` (dispose), `sec/firewall.dart` (validateOrdering).
- Routing: `routing_compiler.dart` (port/CIDR/regex/enum/SRS/outbound validation), `routing_policy.dart` (shape errors), `rule_store.dart` (v2 30-field), `profile_config_source.dart` (per-group fallback, deep-copy, WG selector).
- Ingestion/build: `parsers.dart` (base64 no-recurse), `ingestion_adapter.dart` (isolate+cache), `endpoints_controller.dart` (>64KB isolate), `.gitignore` (track pubspec.lock), `build-android.yml` (SDK 37, size gate).
- Tests: 5 tunnel + 8 compiler + v2 round-trip + base64 regression; all exe tests `markTestSkipped` when exe absent.

## Next (value order)
1. **Commit:** review diff → `git add -A` (incl. `pubspec.lock`) → commit `feat: production hardening — ...`.
2. **Push/CI:** `git remote add origin <url>` → push → tag `v0.1.0` → verify 3-job release + latest.json.
3. **On-device proof:** `flutter install` → wizard → connect → tun0 + egress + logs; then 7 leak tests.
4. **P1 (not started):** config rebuild cache, store coalescing, startup parallelize, connect-latency metrics, log filter/export, l10n strings, 2.0 goldens, sentry, per-ABI splits.

## Verify (30 sec)
```
& C:\tools\flutter\bin\flutter.bat test --no-pub        # 194 pass
& C:\tools\flutter\bin\flutter.bat analyze              # No issues
windows\sing-box.exe check -c profiles/config.wg-awg.json  # exit 0
git status --short | head -25                            # dirty, 23 mod + lock
```
