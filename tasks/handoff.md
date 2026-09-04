# Handoff — YOURVPN — P0+P1+P2 committed, clean tree (60 sec)

## Repo state
- **Git `master`, 11 commits** (`6213424` latest). **Working tree CLEAN.**
- **241 tests green, `flutter analyze` clean, `sing-box check` exit 0**, real exe smoke green.
- Arc: `prod-audit` (39 confirmed) → P0 (all 14) → P1 perf → P1 reliability → P2 UX. Progress logs: `tasks/progress-2026-09-03.md` (P0), P1/P2 below. Decisions: `docs/decisions.tsv` (+14 P0 rows; P1/P2 rows pending).

## Engine truths (do NOT re-derive)
- aar (libbox 1.14) has **NO `Box` class** — daemon arch; TUN fd via Go→Kotlin `openTun`; `engineManagedTun=true` both platforms.
- `endpoints[].id/ip/ib` **FATAL**; tuic `alpn` under `tls.alpn`; reality REQUIRES utls; no `chain` outbound (detour); CommandClient 6 commands only (FATAL-scan crash detection).
- `outbound: BLOCK` passes check (probed); compiler emits `reject`, firewall policy asserts `BLOCK` shape — both valid.
- `windows/sing-box.exe` must be spawned via absolute path (`p.join(Directory.current.path, ...)`) — relative breaks Win lookup.
- Fork `FakeIPDNSServerOptions` has ONLY `inet4_range`/`inet6_range` — no filter/mode fields exist, so `filterMode`/`fakeIpFilters` stay Dart-side data (P2 deliberately did NOT emit them).

## What landed since the last handoff (commits `1d62f8a`→`6213424`)
- **P1 startup/apps** (`1d62f8a`): PhaseTimer + `latestStartupReport`, updater deferred post-frame, wizard 1500ms app-list timeout, Kotlin bg-thread + 60s TTL app query, Dart app memoize.
- **P1 perf** (`4d9bf0e`): config fingerprint cache + shared asset load; tmp+rename atomic writes everywhere; debounced controllers (state now, disk 300ms, `flushPending`); LogBus 2000/4KB + repeat-collapse + 250ms UI batching + static RegExps.
- **P1 reliability** (`b7770c1`): per-phase `ConnectMetrics` + `lastConnectMetrics`; SelectedEndpoint live-tag validation + `deadTag` + real vendored tag `awg-hkg-02`; UpdateController injectable fetch/key + 5 tests; channel/Tor/plainFetch/desktop coverage (12 tests).
- **P2 UX** (`1459539`+`6213424`): 44 EN/FA strings + regen; l10n everywhere touched; edit/delete tooltips + semantic labels; live-region errors; protocol display names; rule Save disabled until a condition + inline hint + typing listeners; Logs rewrite (owns ScrollController, filter/search/pause/tail/export); l10n parity test.

## Next (value order)
1. **Push/CI:** `git remote add origin <url>` → push → tag `v0.1.0` → verify 3-job release + latest.json.
2. **On-device proof:** `flutter install` → wizard → connect → tun0 + egress + logs; then 7 leak tests (`scripts/leak_test.sh`).
3. **Leftovers (roadmap P2/P3, not started):** diagnostics connect-metrics tile (data ready via `lastConnectMetrics`), TextScaler 2.0 goldens, sentry/crash reporting, per-ABI splits, chain-detour integration tests, VpnNotifier blocked/reconnecting edge tests.
4. **Docs debt:** `docs/decisions.tsv` needs P1/P2 rows; `tasks/todo.md` still shows 17/17 pre-hardening state.

## Verify (30 sec)
```
& C:\tools\flutter\bin\flutter.bat test --no-pub        # 241 pass
& C:\tools\flutter\bin\flutter.bat analyze              # No issues
windows\sing-box.exe check -c profiles/config.wg-awg.json  # exit 0
git log --oneline -6                                     # 6213424 … 3c011ab
```
