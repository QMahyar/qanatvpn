# Handoff — YOURVPN — roadmap P2 sweep landed: transports/urltest/backup/metrics (60 sec)

## Repo state

- **Git `master`** at the session close-out commit (5 feature commits on top of `790301d`: `cf92abf` updates fail-closed → `c7f2e59` urltest → `c4e83ac` transports → `1486dde` backup → `cf4201b` metrics tile). Clean tree.
- **301 tests green, analyze clean, sing-box check exit 0.** New emitter shapes probed against the real exe.
- Two workflows ran this session: scout (7 agents, facts below) + adversarial review (5 dims; confirmed findings fixed or listed below).

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

1. **Push/CI** (still first): `git remote add origin <url>` → push → tag `v0.1.0` → verify 3-job release + latest.json.
2. **On-device proof**: install → wizard → connect → leak tests (`scripts/leak_test.sh`).
3. **v1.0 gate leftovers (Dim 11)**: `scripts/compare_capabilities.py` matrix (highest ROI, ~1h), Sentry, AND/OR group editor UI.
4. **Quick engine-parity follow-up**: urltest `idle_timeout`/`interrupt_exist_connections` in model + both emitters.
5. **Docs debt**: none — `decisions.tsv` (81 rows), `todo.md` staleness note, progress + handoff all current.

## Verify (30 sec)

```
& C:\tools\flutter\bin\flutter.bat test --no-pub        # 301 pass
& C:\tools\flutter\bin\flutter.bat analyze              # No issues
windows\sing-box.exe check -c profiles/config.wg-awg.json  # exit 0
git log --oneline -6                                    # cf4201b .. 790301d
```
