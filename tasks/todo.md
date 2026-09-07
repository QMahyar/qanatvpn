# Todo — Mother Audit Fix Plan (2026-09-05)

> Source: mother audit (5 workflows, 117 finders, 390 skeptic verdicts) — full data in
> `tasks/salvage-joined-2026-09-05.json`, report in `tasks/mother-audit-2026-09-05.md`.
> 351 confirmed findings (94 critical, 257 high). This file supersedes the completed
> v1.0 build record (17/17 done, archived below).

Legend: `[ ]` open · `[~]` in progress · `[x]` done. Each task lists confirmed findings
it closes (F# = index into salvage-joined.json for traceability).

---

## Phase W1 — Ship fixes (this week)

- [x] W1.1 LICENSE + THIRD_PARTY — AGPL-3.0 unbacked on public repo (GitHub `license: null`)
  - Findings: F-O (no LICENSE anywhere; SPEC/AGENTS/site claim AGPL), THIRD_PARTY missing
  - Acceptance: `LICENSE` = verbatim AGPL-3.0 text; `THIRD_PARTY.md` lists Flutter/Dart packages
    (pubspec.lock) + Go deps (sing-box/awg fork, gomobile, wireguard-go) with licenses + pinned
    SHAs; README links both.
  - Verify: `gh api repos/QMahyar/yourvpn --jq .license.spdx_id` → AGPL-3.0 after push.
  - Files: `LICENSE`, `THIRD_PARTY.md`

- [x] W1.2 plainFetch User-Agent — GitHub API 403s every updater request without UA
  - Findings: F-M (plainFetch sends no UA; live probe no-UA→403 UA→200), silent mirror fallback
  - Acceptance: plainFetch injects `User-Agent: yourvpn/<ver> (+https://github.com/QMahyar/yourvpn)`
    unless caller set one; no other header semantics change.
  - Verify: unit test — fetch without UA header contains default UA; caller UA preserved.
  - Files: `lib/core/network/plain_fetch.dart`, `test/core/plain_fetch_test.dart`

- [x] W1.3 Windows exe resolution — released app can never spawn engine
  - Findings: F-A/F-A2 (code resolves `<bundle>/windows/sing-box.exe`, CI zip puts exe at bundle root)
  - Acceptance: resolution tries, in order: configured path → `<bundle>/sing-box.exe` →
    `<bundle>/windows/sing-box.exe` (dev layout) → first `sing-box.exe` found via PATH lookup
    (documented dev escape hatch). First existing wins; resolution logged once.
  - Verify: unit tests with fake resolvedExecutable layouts (root + nested) both spawn;
    `windows_real_exe_smoke_test` still green.
  - Files: `lib/core/services/windows_box_process.dart`, `test/tunnel/windows_box_process_test.dart`

- [x] W1.4 Cross-platform store paths — all 5 file stores fail on Android
  - Findings: F-B (HOME/USERPROFILE unset on Android; systemTemp fallback lands in a
    private/unreadable dir; affects split/endpoint/rule/policy/update stores)
  - Acceptance: `lib/core/persistence/app_paths.dart`: `AppPaths.resolve()` → path_provider
    `getApplicationSupportDirectory` on Android/Windows, env-var chain on desktop tests;
    resolved once at startup, injected as `baseDir` into every store (default ctor keeps
    env-chain so existing unit tests stay valid); migration: if legacy `~/.yourvpn` exists on
    desktop, copy files once to new dir.
  - Verify: unit tests for resolve() per-platform via overrides; store round-trip with
    injected baseDir; analyze clean.
  - Files: `lib/core/persistence/app_paths.dart` (new), 5 store files, `lib/main.dart`,
    `pubspec.yaml` (+path_provider direct dep), tests

- [x] W1.5 Update sha256 verification — artifacts installed with zero integrity check
  - Findings: F-K (sha256 files generated in CI never checked), F-K2 (Windows zip opened via
    explorer with no download/hash), mirror lacks sha256 entry
  - Acceptance: `UpdateVerifier.verifyFile(path, expectedSha256)`; `updates_controller` gains
    download+verify flow: fetch asset to temp → fetch sibling sha256 asset from release →
    compare → only then hand to installer; mismatch = fail-closed with user-visible error;
    latest.json mirror schema extended with `sha256` per platform (CI writes it).
  - Verify: unit tests — match installs, mismatch throws, missing sha256 asset fails closed;
    golden for error banner.
  - Files: `lib/modules/updates/updater.dart`, `updates_controller.dart`, `updates_screen.dart`,
    `.github/workflows/build-android.yml` (sha256 json per-asset), tests

- [x] W1.6 README — flutter-create template is the public face
  - Findings: F-R (verbatim template on public AGPL censorship-evasion VPN)
  - Acceptance: README covers: what it is (WG+AWG-first VPN, sing-box routing, original code),
    platforms + status, download (Releases, v0.2.0+), build-from-source (submodule, make/libbox.ps1,
    flutter), testing commands, AGPL notice + THIRD_PARTY link, disclaimer, privacy stance
    (no telemetry, original self-contained). No external VPN names copied (AGENTS rule).
  - Verify: human review; links resolve.
  - Files: `README.md`

- [ ] W1.7 CI green-run verification — android fix is pushed but unproven; pages is broken
  - Findings: F-N (build-android failed 5/5 on old runs; fix landed in 30577ce post-tag),
    F-P (gh-pages run failed → site+latest.json 404)
  - Acceptance: workflow_dispatch run of build-android produces 3 APKs; gh-pages re-run deploys
    site; latest.json reachable at `https://qmahyar.github.io/yourvpn/latest.json`; release
    re-cut (v0.1.1) carries APKs + windows zip + latest.json.
  - Verify: `gh run list` green ×2; `curl latest.json` 200; `gh release view v0.1.1` assets ≥5.
  - Files: none (ops only; maybe yml touch-ups)

---

## Phase W2 — Core product (weeks 2-3)

- [x] W2.1 Endpoint selection UI — user cannot choose which server to connect (F-E: delete-only
  list tiles, selection auto-picks first endpoint)
  - Acceptance: tap tile = select + persist; selected tile highlighted; connect uses selection;
    selection survives restart; deleting selected endpoint clears selection safely.
  - Verify: widget tests (select→persist→connect tag), existing suite green.
- [x] W2.2 Settings screen — zero settings surface exists (F-F: no route/entry point anywhere)
  - Acceptance: settings module + route; minimum: theme mode, language (EN/FA), auto-connect on
    launch, notification toggle, log level; wired to persisted store.
  - Verify: widget tests; l10n keys both locales.
- [x] W2.3 Wizard persistence + skippable consent — wizard restarts every launch; VPN-consent
  decline = dead end (F-G ×2)
  - Acceptance: completion persisted (split store); skip path reaches home with connect
    disabled + banner; consent-decline screen offers re-request.
  - Verify: widget tests for skip/resume/decline paths.
- [x] W2.4 Auto-reconnect — TunnelState.reconnecting is dead code (F-H)
  - Acceptance: on network-change/crash events → reconnect with exp backoff (cap 5);
    user-initiated disconnect cancels; state visible in UI.
  - Verify: tunnel tests with fake adapters (crash→reconnect→connected; manual stop cancels).
- [x] W2.5 Subscription model — one-shot imports, ETag-24h goal lock broken (F-D ×10 dupes)
  - Acceptance: `Subscription{url,name,etag,lastRefresh}` store; import registers sub; 24h
    workmanager job refreshes with If-None-Match; 304 = no-op; user-info headers parsed
    (traffic/expire) shown on endpoints screen; per-sub endpoint grouping.
  - Verify: controller tests (ETag 304/200/429), workmanager dispatch test.
- [x] W2.6 Ingestion hardening — one bad node kills whole import (F-high#2,#3,#4,#5,#20)
  - Acceptance: parseShareLines catches all per-line errors (FormatException + TypeError +
    CastError) → per-line failure list, rest imports; vmess base64 fields null-safe with
    FormatException; Clash scalar-vs-map obfs handled; percent-decode userinfo for
    trojan/hy2/tuic/vless; vmess ws Host preserved; pasted-import cache key = content hash.
  - Verify: parser fuzz table tests for each case.
- [x] W2.7 Engine-failure detail — six enum labels are the whole failure taxonomy (F-high#17)
  - Acceptance: FATAL/ERROR line text captured into TunnelBlockReason.detail; diagnostics
    screen shows last failure detail + "copy" action.
  - Verify: tunnel test asserting detail propagation.

## Phase W3 — Security hardening (weeks 3-4)

- [x] W3.1 Kill-switch reality — WFP/iptables lockdown is a no-op validator (F-I ×2, F-high#15)
  - Acceptance: Windows: engine-managed tun with strict_route + auto_route confirmed in
    generated config + post-stop block via WFP (netsh wfp or sing-box rules engine-side);
    Android: always-on VPN setting guide + lockdown mode doc; engine death → block event.
  - Verify: leak-test script extended with engine-death scenario that can FAIL.
- [x] W3.2 Key redaction — FATAL messages echo private keys into logs (F-I/log)
  - Acceptance: LogBus redaction layer strips key-shaped hex/base64 + `private_key` values;
    applies to engine lines + config dumps.
  - Verify: unit test with a real FATAL line containing key material.
- [ ] W3.3 Secrets at rest — plaintext JSON with keys/creds in store + %TEMP% config (F-J ×3)
  - Acceptance: stores move to flutter_secure_storage (Android Keystore / DPAPI) for
    credential-bearing fields (private keys, passwords, uuid, psk); Windows temp config file
    gets restrictive ACL + delete-on-crash best effort + zeroed after start.
  - Verify: store tests via in-memory secure storage fake; Windows file-permission probe.
- [x] W3.4 HTTPS-only subscription fetches (F-L) + 403-without-ratelimit no longer treated as
  "no update" (F-high#36) — distinct error surfaces.
- [x] W3.5 FLAG_SECURE on key-displaying screens (F-high#6,#13) — awg profile editor + backup
  password entry; MainActivity sets FLAG_SECURE for those routes via MethodChannel toggle.
- [x] W3.6 Backup envelope AAD (F-high#8) — bind version+tag-count+salt into AES-GCM AAD;
  wrong-format imports rejected before decrypt.
- [ ] W3.7 Tag-push protection guidance + release workflow hardening (F-high#11) — document
  branch protection; release job requires tag built from master CI (already) + add
  environment approval on `release` GitHub environment.

## Phase W4 — Engine parity + i18n (weeks 4-6)

- [ ] W4.1 Geo asset seeding actually wired into engine config (F-high#9: no initial_path;
    engine re-downloads via PROXY every start)
- [ ] W4.2 Orphaned sing-box.exe on app exit (F-high#1: no parent-death teardown; job object)
- [ ] W4.3 Persian l10n completion (F-high#19 facade list: diagnostics, AWG editor, rules/groups
    forms, updates, backup, home stats)
- [ ] W4.4 Update UX: direct download on Android (no browser handoff) — F-overrated#3 refine
- [ ] W4.5 Deps: repin pubspec.lock against pub.dev (F-high#10 mirror divergence)
- [ ] W4.6 leak_test.sh: SKIP≠PASS, engine-death scenario, exit non-zero on any leak (F-high#15b)
- [ ] W4.7 urltest model parity: idle_timeout + interrupt_exist_connections both emitters
  (handoff leftover)
- [ ] W4.8 Windows per-app split: document as routing-editor scope or emit
    include/exclude into config (F-high#37)
- [ ] W4.9 Diagnostics self-test flow (config check → handshake → DNS → site) — prototype parity
- [ ] W4.10 CI matrix consistency pass (actions pins, artifact names, concurrency groups)

---

## Archived — v1.0 build record (all done pre-audit)

- [x] 17/17 original tasks (scaffold, libbox fork, tunnel lifecycle, geo, ingestion,
  routing compiler, DNS, AWG, adapters, UI, health, updates, sec, CI, site, upstream
  tracking, review hardening) — see git history + docs/decisions.tsv.
