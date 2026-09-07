# Handoff — YOURVPN — mother-audit W2 core product landed (352 tests): selection, settings, wizard, reconnect, ingestion, failure detail (60 sec)

## W2 shipped (commits a0cbed1, this one)

- **W2.1 selection**: persisted tap-to-select (SelectionStore + writable SelectedEndpointNotifier); selected tile highlighted; clearInvalid on delete. 5 tests.
- **W2.2 settings**: SettingsScreen + route + app-bar gear; theme/language/auto-connect/reconnect persist immediately (SettingsStore); effectiveThemeMode/Locale providers wired into MaterialApp; auto-connect on launch (UncontrolledProviderScope + postFrame hook). 5 tests.
- **W2.3 wizard**: completion persisted (wizardDone marker); cold start skips done wizard; skip button ends the consent dead-end. 3 tests.
- **W2.4 reconnect**: crash-while-connected -> reconnecting state (UI shows it + crash detail), exp backoff 1-16s cap 5, exhaustion -> blocked 'gave up after 5', user disconnect cancels. 3 tests.
- **W2.6 ingestion**: per-line TypeError/RangeError isolation; vmess typed fields + ws Host preserved; percent-decoded userinfo (trojan/hy2/tuic/vless); port range validation; pasted-import cache keyed by content hash. 9 tests.
- **W2.7 failure detail**: every _block carries engine/exception text; home tile shows it clamped; reconnecting detail visible.


## Repo state

- **Mother audit done** (5 workflows, 117 finders, 1003 findings, 351 confirmed): full report `tasks/mother-audit-2026-09-05.md`, machine-readable `tasks/salvage-joined-2026-09-05.json`, fix queue `tasks/todo.md` (W1 done, W2-W4 open).
- **W1 shipped** (`8ba372e`): LICENSE+THIRD_PARTY · plainFetch UA (GitHub 403 hole) · Windows exe resolution (bundle-root first — released app can now spawn engine) · app_paths.dart path_provider + ~/.yourvpn migration (Android store writes work) · UpdateVerifier sha256 fail-closed install (12 tests; CI emits sibling .sha256; latest.json carries sha256; Android installs via FileProvider from verified blob) · real README. 326 tests green, analyze clean.
- v1.0 state below: 302→326 tests, engine truths unchanged.

## Next (value order)

1. **W1.7 CI proof** — `gh workflow run build-android.yml/gh-pages.yml --ref master` (needs YOUR admin token; local gh got HTTP 403 on dispatch) → verify 3 APKs land on a re-cut v0.1.1 release + `latest.json` live on Pages. Then set the 4 signing secrets.
2. **W2 core product** (todo.md): endpoint tap-to-select, settings screen, wizard persistence, auto-reconnect, subscription ETag-24h model, ingestion hardening, engine-failure detail.
3. **W3 security**: kill-switch reality, key redaction in logs, secrets at rest, HTTPS-only subs, FLAG_SECURE, backup AAD.
4. **W4**: geo seeding initial_path, orphaned sing-box.exe job object, FA l10n completion, pubspec.lock repin to pub.dev.

## Verify (30 sec)

```
flutter test --no-pub        # 326 pass
flutter analyze              # No issues
gh api repos/QMahyar/yourvpn --jq .license.spdx_id   # AGPL-3.0 after GitHub reindex
curl -s https://qmahyar.github.io/yourvpn/latest.json  # after W1.7 pages run
```

---

# Previous handoff (v0.1.0 state, 2026-09-04)

## Repo state

- **Git `master`** at the session close-out commit (7 commits on top of `790301d`: `cf92abf` updates fail-closed → `c7f2e59` urltest → `c4e83ac` transports → `1486dde` backup → `cf4201b` metrics tile → `438c7b4` review hardening → `418ac7f` stray-file cleanup). Clean tree.
- **302 tests green, analyze clean, sing-box check exit 0.** New emitter shapes probed against the real exe.
- Two workflows ran this session: scout (7 agents, facts below) + adversarial review (5 dimensions → 28 raw findings → skeptic-verified 22 confirmed → ALL fixed in `438c7b4`). The review caught two critical regressions the cluster author introduced (type-only transport emission for tcp/h2/kcp FATALs the engine; ws fallback ignoring network type) — verifiers demonstrated them by running `sing-box.exe check`. Review JSON: session transcript `wopp73ah2.output`.

## Engine truths (additions — do NOT re-derive)

- **xhttp `x_padding_bytes` is MANDATORY on the fork** (struct field has no omitempty; absent → zero Range → FATAL `x_padding_bytes cannot be disabled`). Emitter always writes `100-1000`; applies inside `download` sub-blocks too. `headers` must not contain a host key (FATAL).
- **SSH is outbound-only** (`endpoints[]` FATALs `unknown endpoint type: ssh`). Keys: OpenSSH-PEM, true PKCS8, PKCS1-RSA all parse; `ssh-keygen -m PKCS8 -e` EXPORT output does NOT (`ssh: no key found`). Cipher/mac/kex NOT validated at check.
- **ECH**: `tls.ech{enabled:true}` without config = DNS HTTPS-record fetch at runtime (check passes); config must be PEM `ECH CONFIGS`; `pq_signature_schemes_enabled`/`dynamic_record_sizing_disabled` still parse but FATAL at init — never emit.
- **urltest** accepts `idle_timeout` + `interrupt_exist_connections` (Dart model still lacks them — cheap follow-up; must update BOTH `routing_compiler.dart:101` and `profile_config_source.dart:_groupJson` if added).
- **pub.dev 403s on this network** — use `PUB_HOSTED_URL=https://pub.flutter-io.cn` for any pub add. Added deps this session: `cryptography ^2.9.0` (Argon2id/AesGcm pure-Dart, smoke-probed), `file_picker ^12.2.0` (static API: `FilePicker.saveFile` consumes `bytes` itself).

## What landed (clusters A–E; details + evidence → tasks/progress-2026-09-04.md)

- **Updates fail-closed**: epoch reset parse; StoredUpdate envelope (restart semantics fixed); mirror wired both paths; bg task real localVersion; ABI fail-closed; geo seeding actually wired (rootBundle fallback now works on Android).
- **urltest best-node**: form fields landed (were dropped); interval guard on the real connect emitter; urltest group connects as GROUP tag (engine auto-picks); latency sweep module + UI.
- **Transports**: SSH + XHTTP/gRPC/HTTPUpgrade/http + ECH — import AND emit, all `sing-box check`-probed; 6 exhaustive switch sites; store round-trip.
- **Encrypted backup**: Argon2id+AES-GCM envelope over endpoints/rules/policy/split; replace + merge-by-tag; endpoints-screen UI; fail-closed wrong-password.
- **Metrics tile + 200% goldens**: StatsTile real data; clamp-bypass golden proves raw layout; two real overflows fixed.

## Review workflow outcome

5-dimension adversarial review over `790301d..HEAD`; findings that survived skeptic verification were fixed before close-out (see progress log + decisions.tsv rows for the session clusters).

## Next (value order)

1. ~~Push/CI~~ **DONE 2026-09-04**: repo live at `github.com/QMahyar/yourvpn` (public, AGPL). Tag `v0.1.0` pushed; CI fixes landed (`555c223` secrets-in-if parse error, `.gitmodules` was missing while CI runs `submodules: recursive`, Pages enabled via API). Verify latest.json + APKs attached to the release, then site mirror at `https://qmahyar.github.io/yourvpn/`.
2. **Signing**: release currently debug-signs — set the 4 GitHub secrets (`KEYSTORE_BASE64`, `STORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`) before any Play/manual distribution; Gradle already reads `key.properties` when present.
3. **On-device proof**: install → wizard → connect → leak tests (`scripts/leak_test.sh`).
4. **v1.0 gate leftovers (Dim 11)**: `scripts/compare_capabilities.py` matrix (highest ROI, ~1h), Sentry, AND/OR group editor UI.
5. **Quick engine-parity follow-up**: urltest `idle_timeout`/`interrupt_exist_connections` in model + both emitters.

## Verify (30 sec)

```
& C:\tools\flutter\bin\flutter.bat test --no-pub        # 302 pass
& C:\tools\flutter\bin\flutter.bat analyze              # No issues
windows\sing-box.exe check -c profiles/config.wg-awg.json  # exit 0
git remote -v                                           # origin -> QMahyar/yourvpn
gh release view v0.1.0 --repo QMahyar/yourvpn           # APKs + windows zip + latest.json
```
