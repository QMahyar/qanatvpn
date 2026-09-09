# AGENTS.md — QanatVPN

> Censorship-resistant VPN client: Flutter 3.47.2 + material_3_expressive, Go engine
> (sing-box 1.14-rc1 + AmneziaWG fork, `with_awg`) as libbox.aar (Android) and
> sing-box.exe subprocess (Windows). AGPL. Original, self-contained.
>
> **READ THIS FILE TOP-DOWN. It is a progressive index — follow the pointers, do not
> load everything.** Session state lives in `tasks/handoff.md` (read that first, 60 sec).

## State at a glance

- **v0.1.1 RELEASED** — first complete distribution (3 ABI APKs + Windows zip +
  latest.json with sha256, live at qmahyar.github.io/qanatvpn/latest.json).
- 372 tests green, analyze clean. Repo: github.com/QMahyar/qanatvpn.
- Full audit trail: mother-audit (5 workflows, 1003 findings, 351 confirmed) →
  W1–W4 remediation, 19/22 shipped. Open queue: `tasks/todo.md`.

## Session start (in order)

1. `tasks/handoff.md` — current state, gotchas, next steps (60 sec)
2. `tasks/todo.md` — the fix queue; only the section you work on
3. `docs/project-map.md` — module map; load only your task's section
4. Source files + one existing test for the pattern

## Verify loop (run before every commit)

```bash
C:/tools/flutter/bin/flutter.bat test --no-pub    # 372 pass
C:/tools/flutter/bin/flutter.bat analyze           # no issues
# if routing/config touched:
windows/sing-box.exe check -c profiles/config.wg-awg.json
```

## Environment gotchas (this machine — do not re-derive)

| Gotcha | Workaround |
|---|---|
| Plain `git push` stalls mid-upload | `git -c http.version=HTTP/1.1 push origin master` |
| pub.dev 403s | `PUB_HOSTED_URL=https://pub.dev` + `pub get --offline` (cache is warm) |
| Flutter is NOT on PATH | `C:/tools/flutter/bin/flutter.bat` (run via `cmd //c`) |
| gomobile panics on bash's hidden `=E:` env vars | Launch via clean env: `env -i PATH=... HOME=... bash script` — see decisions.tsv |
| pubspec.lock pinned to pub.dev (151 pkgs) | Never `pub add`; edit constraints + `pub get` |
| GitHub CLI logged in as QMahyar (admin) | `gh workflow run` works; pages env rejects tag refs — dispatch from master with `-f release_tag=vX.Y.Z` |

## Engine truths (verified on the real binary — never re-derive, trust these)

| Truth | Consequence |
|---|---|
| aar has NO `Box` class (daemon architecture) | Engine control via `CommandServer.startOrReloadService` only |
| `endpoints[].id/ip/ib` are WireSock-only | Parse, never emit (FATAL) |
| tuic `alpn` must live under `tls.alpn` | Top-level alpn FATALs |
| reality REQUIRES utls | Emit fp always |
| No `chain` outbound | Chaining = `DialerOptions.detour` |
| `CommandClient` has 6 commands, no service-status | Crash detection = FATAL scan in log stream |
| xhttp `x_padding_bytes` MANDATORY (no omitempty) | Absent field FATALs; headers must not contain host key |
| SSH outbound-only, ECH pq/dynamic fields FATAL at init | Emit guards in place |
| urltest accepts `idle_timeout` + `interrupt_exist_connections` | Model + both emitters support them |
| Local geo rule-sets (type local, seeded via `ensure()`) | Never remote-only — start dies if PROXY not up |
| Kill-switch rules injected into every profile | hijack-dns first, ip_version-6 reject, LAN reject (probed) |

Full list: `docs/decisions.tsv` (85 rows).

## Task routing (load only what your task needs)

| Task touches | Read first | Then |
|---|---|---|
| Tunnel / engine lifecycle | `docs/project-map.md` § tunnel | `lib/core/services/tunnel.dart`, `test/tunnel/` |
| Routing editor / config emit | project-map § routing | `lib/modules/routing/`, `lib/modules/vpn/repositories/profile_config_source.dart` |
| Ingestion / parsers | project-map § ingestion | `lib/modules/vpn/repositories/ingestion/` |
| Updates / releases | project-map § updates | `lib/modules/updates/`, `.github/workflows/` |
| Security items | project-map § sec | `lib/modules/sec/`, `lib/core/backup/backup_service.dart`, `lib/modules/logs/log_bus.dart` |
| UI / screens | project-map § ui | target screen + one golden test |
| Docs / spec | project-map § docs | SPEC.md section only |

## Boundaries

**Always:** verify loop before commits · probe engine claims on the real binary
(`windows/sing-box.exe check`) · update `tasks/handoff.md` + `tasks/progress-YYYY-MM-DD.md`
+ `docs/decisions.tsv` after every task · `EdgeInsetsDirectional` (FA RTL) ·
`Semantics` on icon-only · TextScaler clamp 0.9–1.35.

**Ask first:** DB schema · new deps · CI/signing changes · new protocol ·
`route.rules` `final`/`auto_detect_interface` semantics · locales beyond EN/FA.

**Never:** commit secrets (`key.properties`, `upload-keystore.jks`) · edit
`go/amnezia-box` directly (rebase via fetch) · remove failing updater tests ·
skip `isIgnoringBatteryOptimizations` check · use `ACTION_REQUEST_IGNORE_BATTERY_
OPTIMIZATIONS` for non-VPN · ship without the verify loop · copy other VPN
clients' text · plain `git push` (stalls — see gotchas) · `pub add` (lock drift).

## Pointers (deep docs — load per task, not at session start)

| Level | File | When |
|---|---|---|
| 2 | `tasks/handoff.md` | Session start (always) |
| 2 | `docs/project-map.md` | Per task — module map with key files + patterns |
| 3 | `SPEC.md` | Architecture/deep modules; §Commands; §Boundaries |
| 3 | `goal.md` | Frozen intent, 22 capability locks |
| 3 | `tasks/plan.md` | Dependency graph, phases |
| 3 | `docs/decisions.tsv` | Every decision with evidence |
| 4 | `tasks/progress-*.md` | Daily logs |
| 4 | `tasks/mother-audit-2026-09-05.md` | The full audit report |
| 4 | `research/` + `docs/prototype-final.html` | Competition facts, design target |

## History (condensed — details in git log)

- 2026-09-01: MVP core, 17/17 todos, 96 tests
- 2026-09-02: full app runtime wired, 180 tests
- 2026-09-04: P2 sweep (transports, urltest, backup, metrics), 302 tests
- 2026-09-05/06: mother-audit (1003 findings) → W1 ship-blockers, W2 all 7,
  W3 security (redaction, HTTPS-only, FLAG_SECURE, AAD, kill-switch rules),
  W4 (geo local rule-sets, urltest parity, registry repin, job object, l10n)
- 2026-09-08/09: renamed QanatVPN everywhere, libbox.aar rebuilt
  (javapkg com.qanatvpn), CI fully green, **v0.1.1 released**
