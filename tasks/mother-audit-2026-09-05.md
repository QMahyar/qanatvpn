# Mother Audit Report — 2026-09-05

## What ran today

5 parallel audit workflows (bug-hunt, security, product-gaps, repo-prod, engine-parity)
spawned ~130 finder agents across every module, with adversarial verification on each.
13/34 batch-verifier waves completed before power loss — all work survived on disk.

**Raw**: 1,003 unique findings from 117 finder agents
**Verified**: 351 confirmed, 38 overrated, 1 underrated, 613 pending (verifier incomplete)
**Confirmed severity**: 94 critical, 257 high

## How the data was produced

- **wf4 repo-prod**: 23/23 finders complete, ~30/39 verified — most complete wave
- **wf3 product**: 24/24 finders complete, 33 verified — full coverage
- **wf2 security**: 20/26 finders, ~32 verified
- **wf5 engine**: 19/24 finders, 11 verified
- **wf1 bug-hunt**: 7/28 finders, 5 verified — weakest (only bootstrap→ingestion partitions)
- **wf-salvage**: 13/34 batch-verifier chunks completed over 1,003 findings

All salvaged findings and verifier verdicts are in `tasks/salvage-joined-2026-09-05.json`

---

## SHIP-BLOCKING CRITICALS (must fix before v0.2.0)

### A. Windows cannot start the engine
**File**: `lib/core/services/windows_box_process.dart`
**Issue**: `_resolvedExe` defaults to `<exeDir>/windows/sing-box.exe` but CI bundles the exe at `<exeDir>/sing-box.exe`. Every Windows connect fails with engine-not-found.
**Fix**: Change default path to `path.join(path.dirname(Platform.resolvedExecutable), 'sing-box.exe')` or restructure the build to match the code path.

### B. Android store writes fail
**File**: `lib/modules/onboarding/split_store.dart` (and all 4 other stores)
**Issue**: All stores resolve paths via `HOME`/`USERPROFILE` env vars which are unset on Android. `Directory.systemTemp` fallback lands in an inaccessible app-internal dir.
**Fix**: Use `path_provider` for cross-platform app data directory.

### C. Selected endpoint never reaches the engine
**File**: `lib/modules/vpn/repositories/profile_config_source.dart`
**Issue**: PROXY selector has no default. Connect routes through PROXY whose only member is DIRECT → fresh-install connects to nothing useful.
**Fix**: Set default selector to the first non-DIRECT outbound, or validate at least one real endpoint exists before connect.

### D. Subscriptions are one-shot imports
**Files**: `lib/modules/vpn/repositories/endpoints_controller.dart`, `lib/main.dart`
**Issue**: Subscription URLs are fetched once and never refreshed. No ETag, no 24h interval, no stored subscription entity. Node lists rot silently.
**Fix**: Add `Subscription` model with URL + ETag + lastRefresh; wire to WorkManager 24h periodic task; implement If-None-Match on re-fetch.

### E. No server selection UI
**Files**: `lib/modules/vpn/repositories/endpoints_screen.dart`, `lib/modules/vpn/logic/selected_endpoint.dart`
**Issue**: Endpoint list has no tap-to-connect. Selection auto-picks the first stored endpoint. No way to choose which server to connect to.
**Fix**: Add tap handler on list tiles; selectedEndpointProvider must be writable from UI.

### F. No settings screen
**Files**: `lib/modules/vpn/screens/home.dart` (and app.dart routes)
**Issue**: Zero settings screens, routes, or entry points. No theme, language, MTU, keepalive, DNS, or notification preferences.
**Fix**: Add settings module with router entry + minimal essential settings.

### G. Wizard forces restart on every launch
**Files**: `lib/app/app.dart`, `lib/modules/onboarding/wizard.dart`
**Issue**: Cold open re-runs the 3-step wizard every launch. Home is unreachable until completed. VPN consent decline = app unusable.
**Fix**: Persist completion state; skip wizard on subsequent launches; make consent decline show a "permission needed" screen, not a dead end.

### H. No auto-reconnect
**File**: `lib/core/services/tunnel.dart`
**Issue**: `TunnelState.reconnecting` is dead code. No reconnection on network switch, network loss, or engine crash. Every failure = manual reconnect.
**Fix**: Implement reconnect loop with exponential backoff; detect network change via `connectivity_plus`.

---

## SECURITY CRITICALS

### I. No kill-switch / firewall
**Files**: `lib/main.dart`, `lib/modules/sec/firewall.dart`
**Issue**: "Max WFP firewall" is a no-op validator. Engine death reverts all traffic to cleartext instantly. No OS-level block on either platform.
**Fix**: Implement actual WFP callout on Windows; ipables rules with crash handler on Android.

### J. Private keys leaked in logs and files
**Files**: `lib/modules/logs/log_bus.dart`, `lib/core/services/windows_box_process.dart`
**Issue**: Engine FATAL messages echo private keys in hex to the log stream. Full config with all keys written to `%TEMP%` as plaintext. All keys stored as plaintext JSON on disk.
**Fix**: Redact key material from logs; encrypt temp config files; use Android Keystore / Windows DPAPI for at-rest storage.

### K. Update artifacts have no hash verification
**Files**: `lib/modules/updates/updates_screen.dart`, `lib/modules/updates/updater.dart`
**Issue**: SHA-256 files generated in CI are never checked by the updater. Downloaded APKs/ZIPs are installed without integrity verification.
**Fix**: Verify sha256 against release asset before install; verify sha256 file itself is signed or same-origin.

### L. plainFetch sends no User-Agent
**File**: `lib/core/network/plain_fetch.dart`
**Issue**: GitHub API rejects requests without User-Agent with 403. All update checks silently fail; fallback to mirror.
**Fix**: Add `User-Agent: yourvpn/VERSION` header.

### M. HTTP subscription URLs leak credentials
**File**: `lib/modules/vpn/repositories/endpoints_controller.dart`
**Issue**: Subscription import accepts and fetches `http://` URLs, sending server credentials over cleartext.
**Fix**: Enforce HTTPS-only on subscription URLs.

---

## PRODUCTION / CI CRITICALS

### N. build-android has never produced APKs
**File**: `.github/workflows/build-android.yml`
**Issue**: sdkmanager not on PATH (exit 127). The fix commit is unpushed. Pipeline broken on every run.
**Fix**: Use `android-actions/setup-android@v3` (already in handoff notes). Push the fix.

### O. No LICENSE file anywhere
**Issue**: Repo, tag v0.1.0, and release zip contain no LICENSE file despite AGPL-3.0 claims in SPEC, AGENTS.md, and the site footer. GitHub reports `license: null`.
**Fix**: Add LICENSE (AGPL-3.0) + THIRD_PARTY.md with dependency licenses and SHAs.

### P. gh-pages never deployed — latest.json 404
**File**: `.github/workflows/gh-pages.yml`
**Issue**: Pages workflow failed. `qmahyar.github.io/yourvpn/latest.json` returns 404. In-app updater mirror fallback is dead.
**Fix**: Fix the workflow; generate and push latest.json with correct platform map.

### Q. Release v0.1.0 has zero Android APKs
**Issue**: build-android failed, so the release has only a Windows zip. Flagship platform has no distributable.
**Fix**: Fix CI, re-release v0.2.0 with APK splits + latest.json.

### R. README is untouched flutter create template
**File**: `README.md`
**Issue**: 17-line placeholder is the public face of a released censorship-evasion VPN.
**Fix**: Replace with proper README: what it is, screenshots, install (Releases), build from source, contributing, license.

---

## HIGH-IMPACT ISSUES (top 20 of 257 confirmed)

1. **Orphaned sing-box.exe on app exit** — TUN/routes stay up, temp config with keys persists
2. **parseShareLines catches only FormatException** — one TypeError from a bad vmess node aborts the entire import
3. **vmess base64 parser casts unvalidated fields** — missing/non-string 'add'/'id' throws _TypeError
4. **Clash YAML parser breaks on standard mihomo scalar form** — `obfs: salamander` as string vs map
5. **Share-link userinfo never percent-decoded** — percent-encoded credentials imported corrupted
6. **vmess ws Host header silently dropped** — all import paths lose it
7. **No FLAG_SECURE** — WG/AWG private keys visible in screen recordings
8. **No response timeout in plainFetch** — stalled server hangs forever
9. **Geo assets dead wiring** — no `initial_path` in config; engine must re-download through PROXY every start
10. **Dependency lock pinned to pub.flutter-io.cn** — CI resolves against pub.dev (divergence)
11. **Unprotected tag push auto-publishes release** — master branch unprotected
12. **Full config written to %TEMP% as plaintext** — survives crash/force-quit
13. **No FLAG_SECURE anywhere** — awg_profile_screen shows private keys in clear
14. **Backup envelope has no AAD** — same-password forgery possible (Argon2id+AES-GCM without associated data)
15. **leak_test.sh can't detect broken kill-switch** — SKIP counts as PASS
16. **per-app split has no data-plane enforcement** — sing-box routing applies to all traffic
17. **Engine crash detail discarded** — 6 one-line enum labels are the entire failure taxonomy
18. **install flow opens URL in browser** — no direct APK download
19. **Persian l10n is a facade** — diagnostics, AWG editor, rules/groups, updates, backup, home-stats all hardcoded EN
20. **6h parse cache keyed by URL** — pasted imports share 'pasted' key, re-imports return stale data

---

## STATS

| Category | Total unique | Verified confirmed | Overrated | Pending |
|----------|-------------|-------------------|-----------|---------|
| wf1 bug-hunt | 148 | 18 | 1 | 129 |
| wf2 security | 220 | 36 | 12 | 172 |
| wf3 product | 314 | 149 | 15 | 150 |
| wf4 repo-prod | 279 | 139 | 10 | 130 |
| wf5 engine | 42 | 9 | 0 | 33 |
| **TOTAL** | **1003** | **351** | **38** | **613** |

**Confirmed by severity**: 94 critical, 257 high
**Verifiers completed**: 13/34 batch chunks (390/1003 findings adjudicated)
**Gap finders completed**: 0/12 (launched but power loss arrived first)

---

## RECOMMENDED v0.2.0 FIX ORDER

### Phase 1 — Ship fixes (week 1)
1. Windows exe path fix (item A) — one-line change, unlocks Windows
2. Android store path fix (item B) — use path_provider, unlocks Android
3. Add LICENSE + THIRD_PARTY (item O) — legal requirement for AGPL
4. Fix build-android CI (item N) — push the sdkmanager fix
5. Fix gh-pages + latest.json (item P) — unlocks updater
6. Fix README (item R) — public face
7. plainFetch User-Agent (item L) — trivial, unlocks GitHub API
8. Verify sha256 on update install (item K) — security gate

### Phase 2 — Core product (weeks 2-3)
9. Endpoint selection UI (item E) — users can't choose servers
10. Settings screen (item F) — no preferences at all
11. Wizard persistence (item G) — cold start unusable
12. Auto-reconnect (item H) — daily driver requirement
13. Subscription refresh model (item D) — goal.md frozen lock
14. parseShareLines error handling (high #2) — import breaks on one bad node

### Phase 3 — Security hardening (weeks 3-4)
15. Kill-switch implementation (item I) — max firewall promise
16. Key material redaction in logs (item J)
17. Encrypt at-rest key storage (item J)
18. HTTPS-only subscription URLs (item M)
19. Config temp-file protection (high #12)
20. FLAG_SECURE on key screens (high #13)

### Phase 4 — Engine parity + i18n (weeks 4-6)
21. vmess/Clash parser fixes (high #3-6)
22. Share-link percent decoding (high #5)
23. Persian l10n completion (high #19)
24. Engine failure detail surfacing (high #17)
25. Geo asset seeding fix (high #9)

---

*Report generated from salvaged journals. 351/1003 findings verified by adversarial skeptics.
613 findings pending verification — a second verifier pass can confirm or dismiss them.
Full data: tasks/salvage-joined-2026-09-05.json*
