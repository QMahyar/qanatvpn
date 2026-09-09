# CONTEXT.md — QANATVPN Domain Glossary

> Glossary only. No implementation details. Source-driven, self-contained original.
> Created 2026-08-30 during architecture review (grilling round 1 — 03→01+02→04→05+06, Tunnel tag seam, Routing field validation).

## Core domain terms

- **Endpoint** — A single outbound destination with its protocol and address. Not the JSON that configures it. Example: HKG-02 as `WireGuardEndpoint` with `AwgProfile` vs `VlessEndpoint` with Reality. Lives behind Ingestion adapter.

- **RoutingPolicy** — User intent for traffic splitting. A list of `Rule` plus `RuleGroup` tree, not the 30 `route.rules` fields. Example: `Rule { domain: "test.com", processName: "curl", ruleSet: "geosite-cn", action: route, outbound: PROXY }`. Compiles to `CompiledRoute`.

- **CompiledRoute** — Result of `RoutingCompiler.compile(policy)`. Contains `rulesJson`, `ruleSets`, `validationErrors`, `isValid`. Caller checks `isValid`, not try/catch.

- **Tunnel** — Deep module owning the Dart↔Kotlin↔Go seam. Interface `Tunnel.connect(tag) -> TunnelState`, `disconnect()`, `status Stream`. Hides MethodChannel, Go bridge, foreground, battery, firewall, Tor detour. Tag seam chosen over typed Endpoint for leverage.

- **AwgProfile** — Domain concept for AmneziaWG 3.1 obfuscation. Either a named preset (`quic-mimic`, `balanced`) or `Custom` with 30 params hidden as private invariants. Validated via `AwgConfig.fromPreset()` / `generateRandom()` before Go call.

- **AwgConfig** — Validated, ready-to-use Amnezia config with `obfuscationStrength`, `overhead %`, `toEndpointJson()`. Hides `H1∩H2` overlap check, `S1+56≠S2`, `Jmax < MTU`, must-match vs may-differ split.

- **GeoAsset** — Remote SRS binary lifecycle owner. Interface `GeoAsset.ensure(tag) -> Path` (always succeeds via `initial_path`), `refreshAll()` daily ETag-aware. Hides 6h stale-while-revalidate, `x-ratelimit-reset`, `CacheFile`, compile.

- **HealthReport** — Result of `Health.snapshot()`. Contains `score 0-6`, `hijacked bool`, `pingMs`, `stability`, `routeHops`. Hides scanner, Prism HMAC, ping TCP, Rust `guard()`, Drift retention.

- **NormalizedEndpoint** — Sealed union behind Ingestion adapter. Variants: `VlessEndpoint`, `VmessEndpoint`, `WireGuardEndpoint` (with `AwgProfile`), `Hysteria2Endpoint`, etc. Not a flat struct with type tag (decision pending round 2).

## Architecture terms (codebase-design vocabulary)

- **Module** — Anything with an interface and implementation. Scale-agnostic.
- **Interface** — What caller must know + test surface. Not just type signature.
- **Depth** — Simple interface, hidden complexity. Deep = high leverage per interface unit.
- **Seam** — Place where interface lives. Where you can alter behaviour without editing in that place.
- **Adapter** — Translation at a seam between two domains that should not know each other.
- **Leverage** — Capability caller gets per interface unit.
- **Locality** — Related knowledge lives together; fix once, fixed everywhere.

## Decisions captured

- 03 Tunnel: `connect(tag)` over `connect(endpoint)` — caller knows tags, not Go structs.
- 01 RoutingCompiler: `validationErrors` field + `isValid` over throw — pure, shows all errors.
- Sequence: 03 → 01+02 parallel → 04 → 05+06.
- 02 Ingestion: `NormalizedEndpoint` sealed union (VlessEndpoint, WireGuardEndpoint with AwgProfile, etc.) over flat struct — depth, exhaustive when.
- 04 AmneziaWG: `AwgProfile` preset + Custom advanced disclosure over preset-only — 2-3 presets default, 30 sliders behind Advanced for highly censored.
- 05 GeoAsset: `ensure(tag) -> Path` always succeeds via `initial_path` over throw — offline first-run guaranteed.
- 06 Health: `snapshot() -> HealthReport` + `stream` auto-refresh over snapshot only — live badge + one-shot.
- 05→06 Sequence: sequential `05 GeoAsset` then `06 Health` over parallel — Health needs GeoAsset path for DNS probe detour.
- Migration: delete shallow modules immediately and migrate callers in same wave over keep deprecated adapters — faster but riskier for 9-10w (user chose, warrants ADR if hard to reverse).

## Out of scope for glossary

No `libbox.aar` paths, no `with_awg` tags, no `VpnService.Builder` call order — those are implementation details, not domain terms.
