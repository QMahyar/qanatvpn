# Handoff — QanatVPN — v0.1.1 released, rename complete, CI green (60 sec)

> Layer-2 context: read after AGENTS.md, before tasks/todo.md. Machine
> gotchas live in AGENTS.md (git push HTTP/1.1, flutter path, pub mirror,
> clean-env gomobile, gh CLI admin).

## Milestone (2026-09-09)

- **v0.1.1 released** — 3 ABI APKs + Windows zip + latest.json (all sha256'd)
  at github.com/QMahyar/qanatvpn/releases/tag/v0.1.1; latest.json LIVE on
  Pages. In-app updater has a real, verified endpoint. W1.7 CLOSED.
- Repo renamed **QanatVPN** everywhere: GitHub, applicationId
  com.qanatvpn.app, Kotlin com.qanatvpn.app, pubspec qanatvpn, libbox.aar
  rebuilt javapkg com.qanatvpn (gomobile, BUILD EXIT 0), artifacts
  qanatvpn_v*, docs.
- CI **all green**: build-android (tests fully pass on Linux for the first
  time — platform-proof test fixes), build-windows (job object compiles),
  gh-pages, upstream-check.
- 372 tests green, analyze clean. Audit: 19/22 shipped; open queue in
  tasks/todo.md (W3.3, W3.7, W4.3 part2, W4.6, W4.8–4.10).

## Release procedure (proven — reuse for v0.2.x)

1. Commit work on master, bump pubspec version.
2. `git tag vX.Y.Z && git -c http.version=HTTP/1.1 push origin master vX.Y.Z`
3. build-android + build-windows run on the tag → release assets
   (APKs + zip + sha256 siblings).
4. metadata job builds latest.json (needs windows asset; gates on tag).
5. If Pages missed it: `gh workflow run gh-pages.yml --ref master
   -f release_tag=vX.Y.Z` (env protection rejects tag refs — use master +
   input).
6. Verify: `curl -s https://qmahyar.github.io/qanatvpn/latest.json`.

## Gotchas (machine/session — full table in AGENTS.md)

- `git -c http.version=HTTP/1.1 push` — plain push stalls on this network.
- gomobile: launch via clean env (`env -i ... bash script`) — bash's
  hidden `=E:` drive-cwd vars panic it; recipe proven 2026-09-09
  (aar_build took ~7 min).
- flutter: `C:/tools/flutter/bin/flutter.bat` via `cmd //c`; tests
  `--no-pub`; analyze via dart or flutter.bat.
- gh CLI: QMahyar admin token works for workflow dispatch + env edits.
- Async tests: NEVER markTestSkipped in async bodies (throws = failure);
  use test-level `skip:` param — all real-check tests converted; keep new
  ones in that style. Goldens are Windows-only (Linux font shaping).
- flutter_secure_storage forced to compileSdk 36 via gradle.beforeProject
  hook (API 37 not on stable sdkmanager) — see android/build.gradle.kts.

## Open queue (value order)

1. Signing: 4 GitHub secrets (KEYSTORE_BASE64, STORE_PASSWORD, KEY_ALIAS,
   KEY_PASSWORD) — release currently debug-signed; gradle reads
   key.properties when present.
2. W3.3 secrets at rest: flutter_secure_storage migration for
   credential-bearing store fields (dep present; store migration is the lift).
3. W3.7 branch protection + release environment approval.
4. W4.3 l10n part 2 (AWG editor + home stats EN->FA), W4.6 leak_test
   hardening (SKIP≠PASS), W4.8 Windows split doc/emit, W4.9 diagnostics
   self-test flow, W4.10 CI matrix pass.
5. On-device proof: install arm64 APK → wizard → connect →
   scripts/leak_test.sh.

## Verify (30 sec)

```
C:/tools/flutter/bin/flutter.bat test --no-pub      # 372 pass
curl -s https://qmahyar.github.io/qanatvpn/latest.json   # v0.1.1 + sha256s
gh release view v0.1.1 --repo QMahyar/qanatvpn --json assets --jq '[.assets[].name] | length'  # 10
```
