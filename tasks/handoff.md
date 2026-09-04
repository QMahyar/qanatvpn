# Handoff — YOURVPN — P0 fail-closed + P1 emit-parity merged, clean tree (60 sec)

## Repo state
- **Git `master`, 13 commits** (`e9a98ed` latest). **Working tree CLEAN, no branches, no stashes, single worktree.**
- **251 tests green, `flutter analyze` clean, `sing-box check` exit 0**, real exe smoke green (Hy2/TUIC/reality probed).
- Arc: deep-review swarm (12 dims, `tasks/review-swarm-full.md`) → P0 fail-closed (`bce7604`) → P1 emit-parity (`e9a98ed`), both fast-forward merged, branches deleted.
- Decisions: `docs/decisions.tsv` +4 rows (P0×3, P1×1). Prior P1/P2-perf backfill + `tasks/todo.md` 17/17 staleness still open.

## Engine truths (do NOT re-derive)
- aar (libbox 1.14) has **NO `Box` class** — daemon arch; TUN fd via Go→Kotlin `openTun`; `engineManagedTun=true` both platforms.
- `endpoints[].id/ip/ib` **FATAL**; tuic `alpn` under `tls.alpn`; reality REQUIRES utls (emitter defaults `chrome`); no `chain` outbound (detour); CommandClient 6 commands only (FATAL-scan crash detection).
- `outbound: BLOCK` passes check (probed); compiler emits `reject`, firewall policy asserts `BLOCK` shape — both valid.
- `windows/sing-box.exe` spawned via absolute path from `Platform.resolvedExecutable` parent — relative breaks installed app.
- Fork `FakeIPDNSServerOptions` has ONLY `inet4_range`/`inet6_range` — no filter/mode fields exist, so `filterMode`/`fakeIpFilters` stay Dart-side data (swarm emit proposal refuted by struct, P0 row).
- Hy2 `server_ports` uses `min:max` colon syntax — Clash/URI dash `mport` normalized on emit (`_hy2Ports`); `hop_interval` emits `${n}s`; TUIC `udp_relay_mode` native/quic passes through.

## What landed since the last handoff (commits `8b52a05`→`e9a98ed`)
- **P0 fail-closed** (`bce7604`, `test/p0` ×4): assembler prepends `baseRules()`; validator exempts pinned DIRECT; TOR-CHAIN + `tor-entry` both valid; `baseRulesScoped()` forces LAN BLOCK; airplane before foreground; `_block()` stops foreground; absolute exe; dns non-emission documented.
- **P1 emit-parity** (`e9a98ed`, `test/p1` ×6): Clash full AWG (S3/S4/I1-I5/id/ip/ib); Hy2 mport/hop + TUIC relay emitted; reality fp default; `stringField`/`intField` hardening (no TypeError DoS); real `sing-box check` on all three.
- **Review:** `tasks/review-swarm-full.md` (11 dims, 70+ findings); top-20 gaps + P0-P3 ship plan in report tail.

## Next (value order)
1. **Push/CI:** `git remote add origin <url>` → push → tag `v0.1.0` → verify 3-job release + latest.json.
2. **On-device proof:** `flutter install` → wizard → connect → tun0 + egress + logs; then 7 leak tests (`scripts/leak_test.sh`).
3. **Leftovers (roadmap P2/P3, not started):** P2 transports (SSH/XHTTP emitters), best-node urltest, encrypted backup export/import, Sentry, per-ABI splits, chain-detour tests, connect-metrics tile wiring, TextScaler 2.0 goldens.
4. **Docs debt (remaining):** older P1-perf/P2-UX rows in `decisions.tsv`; `tasks/todo.md` still 17/17 pre-hardening.

## Verify (30 sec)
```
& C:\tools\flutter\bin\flutter.bat test --no-pub        # 251 pass
& C:\tools\flutter\bin\flutter.bat analyze              # No issues
windows\sing-box.exe check -c profiles/config.wg-awg.json  # exit 0
git log --oneline -4                                     # e9a98ed … 8b52a05
git branch -vv; git stash list; git worktree list        # master only, no stash, single worktree
```
