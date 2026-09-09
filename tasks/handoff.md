# Handoff — QanatVPN — v0.1.1 RELEASED + renamed everywhere (60 sec)

## Milestone: first complete release (2026-09-09)

- Repo renamed `QMahyar/qanatvpn` (Pages: qmahyar.github.io/qanatvpn/).
- **v0.1.1 live**: 3 ABI APKs + Windows zip + latest.json (all with .sha256)
  at github.com/QMahyar/qanatvpn/releases/tag/v0.1.1.
- **latest.json LIVE on Pages** — the in-app updater finally has a real
  endpoint (W1.7 CLOSED).
- CI: build-android ✗->✔ (API 36 + tagless-dispatch fixes), build-windows ✔,
  gh-pages ✔ (release_tag input; env protection rejects tag refs — dispatch
  from master with -f release_tag instead), upstream-check green.
- Local Windows build works (ATL installed; 87MB debug engine artifact
  self-provided from Downloads).
- Everything renamed QanatVPN: applicationId com.qanatvpn.app, Kotlin pkg
  com.qanatvpn.app, pubspec qanatvpn, libbox.aar REBUILT javapkg
  com.qanatvpn (gomobile; bash `=E:` env-var panic worked around via
  clean-env launcher), artifact names qanatvpn_v*, Runner.rc, docs.
- Test-count 372 green; CI APK job fully green incl. tests.

## Gotchas (do not re-derive)

- Bash on this machine exports hidden `=E:`/`=C:` drive-cwd env vars;
  gomobile v0.1.13 panics on them. Launch builds via clean-env
  (`env -i PATH=... bash script`) — recipe in go/amnezia-box history +
  scripts/libbox.ps1.
- `git -c http.version=HTTP/1.1 push` required (plain push stalls).
- github-pages env protection rejects tag refs; deploy from master with
  `-f release_tag=vX.Y.Z` (gh-pages.yml takes an input now).
- markTestSkipped inside async test bodies = FAILURE not skip; use
  test-level `skip:` param (all real-check tests converted).

## Next (value order)

1. Signing: set the 4 GitHub secrets (KEYSTORE_BASE64, STORE_PASSWORD,
   KEY_ALIAS, KEY_PASSWORD) — release currently debug-signed.
2. W3.3 secrets at rest (flutter_secure_storage migration).
3. W3.7 branch protection + release environment approval.
4. W4.3 l10n part 2 (AWG editor + home stats), W4.6 leak_test hardening,
   W4.8-4.10 (split doc, diagnostics self-test, CI matrix pass).
5. On-device proof: install arm64 APK -> wizard -> connect -> scripts/leak_test.sh.

## Verify (30 sec)

```
curl -s https://qmahyar.github.io/qanatvpn/latest.json   # v0.1.1 + sha256s
gh release view v0.1.1 --repo QMahyar/qanatvpn           # 10 assets
gh auth status                                            # QMahyar admin
git -c http.version=HTTP/1.1 push                        # needed on this net
```
