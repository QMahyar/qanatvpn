

=====DIM 1 : competition-audit =====
SUMMARY: Qanat wins on AmneziaWG depth + validation, unified 30-field/3-tier/AND-OR routing, and a combined Lockdown+WFP kill switch; ties on protocol/transport/DNS/subs via shared sing-box/Xray/amneziawg-go engines (Tor sidecar, ECH deferred). It loses on platform breadth (no iOS/macOS/Linux), legacy SSR + NaiveProxy, WG Tunnel automation (auto-tunnel/kernel/Lockdown-dummy/biometric/quick-tile), and maturity extras (30+ locales, WebDAV/iCloud sync, Clash REST/mrs ecosystem).

[1] WIN: AmneziaWG all-values + pre-handshake validation (star) [info]
EV: intent.md:2.2 (Jc/Jmin/Jmax, S1-S4, H1-H4 ranges, I1-I5 CPS, ChaCha HeaderProtection, ContentPadding, RandomTrailers, Id/Ip/Ib) + intent.md:2.3 'you validate H1∩H2 before handshake (no other does)'; 09-WG-Tunnel.md:2 documents same AWG 1.0-3.1 params as the tuner to match; 02-Throne.md AWG section shows Throne is manual-JSON type:awg with no UI and a routing-rules bug
IMP: Differentiator in highly censored networks where vanilla WG is fingerprinted; parity with WG Tunnel tuner plus a validation step competitors lack.
REC: 

[2] WIN: 30-field routing + 3-tier groups + AND/OR in one typed policy [info]
EV: intent.md:2.4 (RoutingCompiler, RoutingPolicy→CompiledRoute isValid, 30 inputs + logical and/or + Monaco fallback, auto→selector→proxy + TOR-CHAIN relay); competitors split: 02-Throne.md per-process routing only, FlClash/Verge rule-providers only
IMP: Single-policy unification no one competitor does end to end (per-process AND providers AND rule-sets).
REC: 

[3] WIN: Hardcore kill switch combining both patterns + 7 leak tests [info]
EV: intent.md:2.5 (WG Tunnel Lockdown dummy VPN + WireSock WFP Network Lock + Karing single TUN, WFP/iptables/pf anchors, 7 scenarios where 6/16 leaked per RTINGS Jul 2026)
IMP: Stronger fail-closed story than Karing/Throne soft restore-proxy behavior.
REC: 

[4] TIE: Protocol/transport/DNS/subscription parity via shared engines [info]
EV: intent.md:2.2-2.3,2.6-2.8 (VLESS/Reality/Vision/XHTTP, VMess, Trojan, SS2022+EIH, Hysteria2 mport, TUIC v5, uTLS, fragment, FakeIP 198.18/16, DoH split, ETag, sealed IngestionAdapter); audit.md:1-2,4 (amnezia-box with_awg fork, Tor sidecar 127.0.0.1:9050 instead of fatal type:tor #4200, ECH deferred to v1.1)
IMP: you >= on paper by reusing the same Go engines (sing-box/Xray/amneziawg-go); moat is the unified seams (Tunnel/Ingestion/RoutingCompiler), not novel protocols.
REC: 

[5] LOSE: Platform breadth — Android+Win only vs 4-6 OS rivals [high]
EV: intent.md locks 2 (Android+Win first); 01-Karing.md:Overview (Windows, macOS>=12 dmg, Linux deb/rpm/AppImage, Android>=8, iOS>=15/tvOS>=17 AppStore 6472431552); 02-Throne.md header + downloads (Qt Windows/macOS/Linux, 1.2.4 14 assets incl. deb, macOS ZIP, universal installer)
IMP: Reviewer comparing on iOS/macOS/Linux rows scores Qanat 0; expansion needs xcframework/service-binary work outside libbox.aar scope.
REC: 

[6] LOSE: Legacy/migration protocols — SSR and NaiveProxy missing [medium]
EV: 01-Karing.md:Protocol matrix SSR section (ssr:// full support via ShadowsocksROutboundOptions, kept via fork though upstream deprecates); 02-Throne.md:NaiveProxy (type:naive, Chromium stack, most stealth for TSPU) + Snell/Mieru/Juicity/TrustTunnel breadth; intent.md:2.2 admits Naive deferred (Chromium dep heavy)
IMP: Users migrating old ssr:// subs or needing Chrome-mimic Naïve have no path; niche but explicitly covered by Karing/Throne.
REC: 

[7] LOSE: WG Tunnel automation/UX — auto-tunnel, kernel mode, Lockdown dummy VPN, biometric/quick-tile [medium]
EV: 09-WG-Tunnel.md:1 Overview (auto-tunneling by network, Lockdown kill-switch, Local Proxy expose, deferred endpoint bootstrapping, handshake health, split tunneling, intent automation; AppMode VPN/Proxy/Lockdown/Kernel via VpnBackend.kt; flavors Google/F-Droid/Standalone with in-app updater + Obtainium)
IMP: Qanat has wifi_ssid/per-app fields (intent 2.4) but no auto-tunnel orchestrator, kernel-vs-userspace toggle, hev-socks5 Lockdown dummy VPN, or biometric/quick-tile/intent layer.
REC: 

[8] LOSE: Maturity extras — 30+ locales, sync, Clash REST ecosystem [low]
EV: 01-Karing.md stack/i18n (slang 30+ langs incl. FA/AR/ZH vs Qanat EN/FA only per intent lock 19) + iCloud/WebDAV/LAN ZIP sync (intent.md:2.8 extras table: Karing iCloud/WebDAV/LAN ZIP, FlClash WebDAV+drift); 11-FlClash/12-Verge pattern: Mihomo external-controller 127.0.0.1:9090 REST + mrs/yaml rule-providers + observatory/leastPing balancer
IMP: EN/FA-only, GitHub-Releases-only MVP without WebDAV-sync maturity or external-controller API means power-user/automation rows lag FlClash/Verge/Karing.
REC: 


=====DIM 2 : routing-dns-firewall =====
SUMMARY: Audited routing_compiler.dart, routing_policy.dart, config_assembler.dart, dns_config.dart, firewall.dart, profiles/config.wg-awg.json, test/routing, test/dns, test/sec. 30-field/groups/invert/SRS-shape handling is solid. The real gaps are fail-closed wiring (kill-switch blocks never reach the shipped config), TOR-CHAIN tag mismatch, FakeIP excludes silently dropped, IPv6/firewall-timing incoherence, CN-only SRS registry, unguarded per-app fields, and a stub baseRulesScoped().

[1] Kill-switch blocks not wired into shipped config (fail-open) [high]
EV: ConfigAssembler.build route.rules = [...dns.hijackRules(), ...compiled.rulesJson]; FirewallPolicy.baseRules() (hijack + pinned-DNS DIRECT + ::/0 BLOCK + RFC1918 BLOCK) is never called in build. profiles/config.wg-awg.json route.rules has only hijack + 2 user rules, no ::/0 or LAN blocks. route.final = PROXY.
IMP: Kill-switch policy exists but is not shipped: IPv6 and LAN traffic can leave via PROXY/DIRECT on first packet; no fail-closed final (block) if endpoint dies.
REC: Prepend FirewallPolicy().baseRules() in assembler (or enforce validateOrdering in build) and consider route.final action=reject or a BLOCK fallback.

[2] TOR-CHAIN tag mismatch: rules reference TOR-CHAIN, sidecar emitted as tor-entry [high]
EV: TorChainOptions default tag='tor-entry'; _compileGroups emits socks tag=torChain.tag ('tor-entry'), but _compileRule/_checkOutboundRef/known-set validate the literal 'TOR-CHAIN' as the outbound name. Rule outbound 'TOR-CHAIN' therefore references a tag that never exists in outbounds.
IMP: Any TOR-CHAIN rule compiles valid but FATALs/dangles at engine start (no matching outbound tag).
REC: Emit the sidecar with tag 'TOR-CHAIN' (or accept torChain.tag as valid ref); add a compiler test asserting rule outbound appears in outboundsJson tags.

[3] FakeIP exclude filters silently dropped from dns JSON [high]
EV: DnsConfig declares filterMode='whitelist' and fakeIpFilters=[+.lan, +.local, msftconnecttest, ntp...] but toDnsJson() never emits them (no fake_ip_filter / fake-ip-filter / filter field in dns servers/rules/fakeip block). dns_config_test only asserts pool ranges, never filters.
IMP: LAN (.lan/.local), connectivity-check and NTP names get FakeIP answers instead of real IPs; breakage of printers/NAS/captive-portal/NTP, masked by passing tests.
REC: Emit the 1.14 FakeIP exclude schema (fake_ip_filter + mode) from filterMode/fakeIpFilters; extend dns_config_test to assert exclusion.

[4] IPv6 incoherent + firewall relaxed during connecting handshake [medium]
EV: FirewallPolicy(blockIpv6:true default) emits ::/0->BLOCK, yet TUN inbound always carries fdfe:dcba:9876::1/126, dns fakeip inet6_range fc00::/18, endpoints allowed_ips ::/0, dns query_type includes AAAA. shouldEnforce() returns false for connecting/disconnecting.
IMP: Self-contradictory v6 story (dead v6 TUN/FakeIP entries while blocked; v6 escape during handshake when firewall relaxed) plus leak window on bootstrap.
REC: Decide one v6 story (drop v6 TUN+AAAA+::/0 when blocked, or route v6 through tunnel) and enforce firewall during connecting; document the choice.

[5] SRS registry CN-only; forced geosite-cn download over PROXY detour [medium]
EV: GeoAsset.registry contains only geosite-cn/geoip-cn; compiler _validRuleSetTag rejects anything else ('geosite-foobar' test proves strictness). Assembler forces tags={'geosite-cn',...} so every config downloads geosite-cn even with empty policy; rule_set download_detour=PROXY.
IMP: No geo routing for the product's own region (IR/Middle-East sets impossible); always-on CN download wastes proxy bandwidth and is a first-boot chicken-and-egg (needs tunnel before tunnel is up).
REC: Register needed sets (at least geosite-ir/geoip-ir + category sets) with local SRS fallbacks, and make the forced geosite-cn entry opt-in.

[6] Per-app fields emitted without platform guard (silent no-op) [medium]
EV: RouteRule exposes packageNames (Android-only), processNames/processPaths (desktop-only), userIds/wifiSsids/wifiBssids (platform-specific); compiler _addEnumList/addList emits them unconditionally with no platform guard or warning. profiles/config uses process_name steam.exe in a mobile-first config.
IMP: Per-app rules silently no-op on the wrong OS (Android ignores process_name, Windows ignores package_name); users believe an app is excluded/included when it is not.
REC: Add platform warnings (or assembler-time strip/flag) for package_name vs process_* mismatches; document which fields apply per OS.

[7] baseRulesScoped() is an unimplemented alias of baseRules() [low]
EV: FirewallPolicy.baseRulesScoped() documented as merge-safe scoped form (only pinned /32 when allowLan) but body is literally `return baseRules();`. allowLan:true path therefore drops the whole LAN block in baseRules, relying on callers to know the difference.
IMP: Dead/confusing API: future caller using baseRulesScoped expecting scoped semantics gets unscoped behavior; allowLan currently opens all RFC1918 with no DNS-pin scoping.
REC: Implement the scoped variant (pinned-DNS DIRECT + no broad LAN open) or delete it; add a test pinning allowLan behavior.

[8] 30 fields, groups, invert: no defect found [info]
EV: 30-field coverage verified: RouteRule carries ~30 condition fields and compiler handles each (ports/CIDR/regex/enum validated, geosite/geoip merged to rule_set, logical and/or + invert, BLOCK->reject). Tests cover dedup, merge, invalid tags, outbound typos, shape errors.
IMP: Positive: no missing-field or invert/groups regression found; this area needs no work.
REC: None; keep the P0 validation tests as the gate.


=====DIM 3 : tunnel lifecycle =====
SUMMARY: Tunnel ordering/timeouts/epoch are solid (guarded sequence, per-phase timeouts, stale-epoch aborts, crash-during-connect covered by tests). The real gaps are platform glue: relative Windows exe path, blocked paths leaking the foreground service, Android 14 foreground-service type, swallowed foreground errors, racy Windows startup/taskkill, disconnect-failure misreport, and tag loss in VpnNotifier.

[1] Windows exe path is relative, not absolute [high]
EV: windows_box_process.dart:17 default executablePath='windows/sing-box.exe'; processFactory called with relative path, never resolved against Platform.resolvedExecutable directory
IMP: Windows connect fails whenever the working directory is not the bundle root (installed app, flutter run from subdir): spawn throws FileSystemException -> blocked/boxStartFailed.
REC: Resolve to absolute path at construction: File(Platform.resolvedExecutable).parent.resolve('sing-box.exe'); keep override for tests.

[2] Block path never stops foreground service [high]
EV: tunnel.dart _block() enforces firewall + closes fd + sets blocked but never calls foreground.stop(); airplane check runs AFTER foreground.start, and every _block path inherits the leak
IMP: Airplane-mode (and every other) block leaves the foreground notification/service running with no tunnel — battery drain and stale 'Tunnel active' UX.
REC: Stop foreground inside _block (best-effort, like disconnect) or move airplane check before foreground.start.

[3] Crash-during-connect/disconnect failure state races [medium]
EV: tunnel.dart disconnect(): box.stop() failure routes to _block(boxCrashed); _onBoxEvent is sync void firing async _block fire-and-forget while connect() continues its own publishMetrics/_block
IMP: A failed disconnect misreports as blocked/crash; crash-during-connect has two concurrent _block writers racing on _firewallEnforced/_fd (double enforce, possible double closeFd).
REC: Disconnect failure should still tear down (fd, foreground, relax) and end disconnected with logged error; serialize _block with a guard/await or make _onBoxEvent only bump epoch and let connect() own the block.

[4] Firewall enforced after engine start (leak window by design) [low]
EV: tunnel.dart connect(): box.start runs, then firewall.enforce; disconnect(): box.stop -> fd close -> foreground.stop -> firewall.relax
IMP: Brief window each connect where traffic flows before kill-switch enforce; on disconnect the firewall stays enforced until last, which is correct, but a slow/failing enforce on connect leaves the box running until the catch stops it.
REC: Keep as-is only if intentional (documented 'enforce last'); otherwise enforce firewall before box.start so fail-closed has no leak window. At minimum keep the existing box.stop-on-enforce-failure catch (already present) and add a test for it.

[5] Foreground service type wrong for VPN on Android 14+ [high]
EV: ForegroundService.kt onStartCommand: API 34+ startForeground(NOTIFICATION_ID, n, DATA_SYNC|REMOTE_MESSAGING); YourVpnService.kt onStartCommand returns START_NOT_STICKY and never calls startForeground
IMP: Android 14+ may reject the FGS start (wrong type for a VPN; expected SPECIAL_USE/connectedDevice with matching permission) and Doze can kill the non-sticky VpnService mid-tunnel.
REC: Use FOREGROUND_SERVICE_TYPE_SPECIAL_USE (with FOREGROUND_SERVICE_SPECIAL_USE permission, API 34+) or SHORT_SERVICE, and make YourVpnService sticky or explicitly managed; verify on API 34 device.

[6] Foreground start failures swallowed; service wait busy-loops [medium]
EV: channel_adapters.dart MethodChannelForegroundAdapter.start/stop swallow all errors (.onError(_, _){}); BoxEngine.kt SERVICE_WAIT_MS=3000 busy-waits Thread.sleep(50) on box-engine thread
IMP: A dead/failed foreground start is invisible (connect proceeds as if protected from Doze); 3s sleep-loop delays every connect and still throws if the service is slow.
REC: Surface foreground.start failures to Tunnel (fail closed or warn) and replace the sleep-loop with a latch/countdown or early return when INSTANCE is already set.

[7] Windows startup detection racy; taskkill by bare PID [medium]
EV: windows_box_process.dart: 300ms hardcoded startup delay; _hasExited() polls exitCode.timeout(Duration.zero); stop() shells Process.run('taskkill', /PID <pid>) without image-name check
IMP: Slow AV/sandbox spawn (>300ms) misreported as startup crash; zero-timeout poll is racy; taskkill by bare PID risks killing a reused PID and is untestable/unmockable.
REC: Inject clock/timeouts (like TunnelTimeouts), await first log/exit race instead of fixed sleep, verify PID image (tasklist filter) or prefer process.kill() then taskkill /F fallback.

[8] VpnNotifier drops endpoint tag on blocked/reconnecting [low]
EV: vpn_notifier.dart build(): reconnecting maps to VpnState.connecting() and blocked maps to VpnState.blocked(reason) — both drop _lastTag; connected uses _lastTag ?? ''
IMP: UI loses which endpoint is reconnecting/blocked and can show connected('') if the tunnel was driven outside the notifier.
REC: Preserve _lastTag in blocked/connecting states (add tag param to those factories) and fall back to tunnel's current tag rather than ''.


=====DIM 4 : deep-modules audit (depth, interface size, raw-Map bypass) =====
SUMMARY: 5 of 6 modules are deep/small and match SPEC; RoutingCompiler is the exemplar (typed policy in, validated JSON out, errors accumulate). Two raw-Map bypasses (TypedConfig.json, isolate rehydrate + GeoAsset.getPath advisory path) and two SPEC drifts (Health missing hops/stream, AwgConfig missing strength/overhead) are the actionable gaps. No module needs splitting; fixes are additive and narrow.

[1] Health module incomplete vs SPEC: no hops, no stream [high]
EV: health.dart: HealthReport{score,hijacked,pingMs,stability} has no hops; class Health exposes only snapshot(), no stream/auto-refresh. SPEC 06 requires snapshot()->{score 0-6,hijacked,pingMs,stability,hops} + stream auto-refresh hiding scanner 0-6, Prism HMAC, PingRoute, Rust guard().
IMP: Spec drift: diagnostics UI LED (Logs→Ping→Stats) and PingRoute per-hop view have no data source; future traceroute/Prism work has no seam to land in.
REC: Add hops field (List<Hop>, empty until PingRoute lands) and a watch()/stream getter with throttle; keep snapshot() as the one-shot path.

[2] Tunnel TypedConfig.json is a raw-Map bypass at the Dart↔Go seam [medium]
EV: tunnel.dart: TypedConfig{tag, json: Map<String,dynamic>, requiresTor, include/excludePackages}; BoxAdapter.start(TypedConfig). SPEC demands typed bridge, not Setup(string).
IMP: Callers/builders can smuggle arbitrary engine JSON past the type system; engine-start FATALs surface at runtime instead of at resolve()/compile time.
REC: Keep tag+split fields typed, but replace free-form json with an opaque CompiledConfig built only by ConfigAssembler (private map inside), or validate JSON schema in resolve().

[3] GeoAsset.getPath lets callers bypass ensure/initial_path [medium]
EV: geo_asset.dart: getPath(tag) is a pure string concat with no existence check; docs say 'Call ensure() at startup first'. routing/dns builders can call getPath without ensure and emit dangling initial_path.
IMP: Offline-first guarantee is advisory, not enforced; a missed ensure() ships a config pointing at a nonexistent .srs and sing-box FATALs on unknown rule_set.
REC: Either remove getPath (return path from ensure, cache it) or make getPath fall back to initialDir path / throw a typed MissingAssetException the assembler maps to a validation error.

[4] AwgConfig missing strength/overhead from SPEC interface [medium]
EV: awg_config.dart: AwgConfig exposes validate()/isValid/toEndpointJson()/peerHost()/peerPort(); no strength/overhead signal. SPEC 04 interface promises AwgConfig{strength,overhead,toEndpointJson()} for preset-vs-custom comparison and UI cost display.
IMP: UI cannot show junk-overhead cost of stealth vs balanced presets; callers hand-roll overhead math inconsistently.
REC: Add int overheadBytes (or double overheadRatio) + strength level derived from Jc/Jmin/Jmax/S/H values, computed in one place with tests.

[5] Ingestion isolate seam leaks raw-Map (rehydrate burden on caller) [low]
EV: ingestion_adapter.dart: parseInIsolate returns List<Map<String,dynamic>> via normalizedToJson(); callers must call normalizedFromJson to rehydrate. Sealed union is lost across the isolate seam.
IMP: Every isolate caller repeats the rehydrate step; a skipped/failed rehydrate silently works on raw maps, defeating the sealed-union guarantee.
REC: Return List<NormalizedEndpoint> directly from Isolate.run (transferable via existing JSON codec internally) or provide parseInIsolateTyped wrapper that rehydrates before returning.

[6] Test-only AwgConfig constructor widens the deep-module interface [low]
EV: awg_config.dart top-level awgConfigForTest() constructs AwgConfig._ with arbitrary AwgValues; production file carries a test-only constructor bypass.
IMP: Prod API surface is larger than SPEC (fromPreset/generateRandom only); reviewers must audit an extra construction path that skips preset invariants.
REC: Move awgConfigForTest to test/helpers, or gate with @visibleForTesting and document that validate() (not construction) is the invariant gate.


=====DIM 5 : code quality and test gates =====
SUMMARY: Dart test tree is real and well-organized (32 test files across tunnel/routing/awg/updater/goldens), but the two release gates named in SPEC are non-gates: the capability script is an always-pass TODO stub and the leak script SKIP-passes without tooling. Analyzer config is thinner than the SPEC style contract (and already violated by print calls), SDK pin is loose in pubspec, goldens cover one tile EN-only, and trackers (todo.md, decisions.tsv) lag the handoff's 241-test claim. No coverage gate enforces the stated 70% floor.

[1] Capability gate is a no-op stub that always exits 0 [high]
EV: scripts/compare_capabilities.py prints TODO and calls sys.exit(0) unconditionally
IMP: SPEC success-criteria-1 gate always passes without checking the 13-VPN matrix; regressions invisible to CI.
REC: Implement row-by-row compare (parse research/*.md + intent.md matrix) and exit non-zero on any row where yourvpn < best competitor; wire into CI.

[2] Leak-test script degrades to SKIP-pass and is not CI-runnable [high]
EV: scripts/leak_test.sh: tcpdump_dnsleak echoes SKIP and returns 0 when tcpdump missing; ss/ping branches echo SKIP; sleep 60 in test 2; handoff Next step 2 still lists it as the on-device gate
IMP: On machines without tcpdump/ss the script reports PASS=7-equivalent with zero real assertions; 60s sleep makes it unusable in CI; cannot block release tags as claimed.
REC: 

[3] Analyzer gates are weaker than SPEC code-style claims; existing print violation proves it [medium]
EV: analysis_options.yaml includes only flutter_lints plus 4 generic rules; EdgeInsetsDirectional/Semantics enforcement is a comment citing code review; lib/modules/logs/logs_screen.dart:246,248 calls print() despite avoid_print
IMP: Style invariants (RTL, a11y, token discipline) are unenforced; existing avoid_print violation already in tree, so `flutter analyze` as configured does not catch what SPEC requires.
REC: 

[4] Loose SDK constraint contradicts pinned-toolchain policy [medium]
EV: pubspec.yaml declares flutter >=3.44.0 and sdk >=3.12.0 while AGENTS.md/SPEC pin Flutter 3.47.2, Go 1.25, NDK 28, JDK 17
IMP: Local builds can resolve a different SDK/M3E combination than CI pins, producing irreproducible UI/engine behavior.
REC: 

[5] Golden coverage is minimal (one tile, EN-only, no full-screen goldens) [medium]
EV: test/ has 32 *_test.dart files; test/golden has only power_tile_connected_135.png + power_tile_blocked_135.png at 1.35 scale; home_golden_test.dart pumps 2.0 pre-clamp only for overflow, no FA locale golden, no full-home golden
IMP: Visual-regression coverage is one tile × two states × one locale; FA shaping, full-bento overflow at ceiling scale, and theme-token drift go undetected.
REC: 

[6] Trackers stale relative to handoff claims (todo.md, decisions.tsv) [medium]
EV: tasks/handoff.md claims 241 tests green and clean tree at 6213424, but tasks/todo.md still shows the pre-hardening 17/17 state and docs/decisions.tsv lacks P1/P2 rows (self-admitted docs debt)
IMP: Next session cannot trust todo/decisions.tsv as ground truth; progress must be re-derived from git log and progress-*.md.
REC: 

[7] UnimplementedError fallback providers fail at runtime instead of compile time [low]
EV: lib/modules/vpn/logic/vpn_notifier.dart:40-60 and lib/modules/onboarding/wizard.dart:127 expose default providers/adapters that throw UnimplementedError, relying on main.dart overrides; grep shows no test asserting app boots without the override
IMP: A missing override fails at runtime (black screen on startup) rather than at build/test time; easy to regress when adding a new entry point or test harness.
REC: 

[8] No enforced coverage threshold; verification depends on a hardcoded Flutter path [low]
EV: No coverage config or gate found (no coverage: in workflows, no --coverage threshold, no codecov/lcov floor); AGENTS.md cites >=70% for routing_editor/services but nothing enforces it; flutter binary not on PATH in this environment so gates unverifiable here
IMP: Coverage can silently decay; the >=70% requirement is aspirational, and test-count claims (241) cannot be independently re-verified without the pinned toolchain path.
REC: 


=====DIM 6 : security =====
SUMMARY: Audited the 8 named areas; found 8 evidence-backed, exploitable issues. The two key-theft paths (plaintext endpoint store with secure-storage unused, Windows temp config leak) and the traffic-before-firewall window are the highest priority; the remaining five (subscription parser TypeError DoS, updater epoch bug starving patches, permissive manifest backup/cleartext defaults, unredacted log bus, floating supply-chain pins) are concrete but lower severity. No theory-only items included; firewall rule ordering, plain_fetch TLS, and tunnel blocked-state handling were checked and held up.

[1] VPN private keys and passwords stored plaintext on disk; flutter_secure_storage declared but never used [high]
EV: lib/modules/vpn/repositories/endpoint_store.dart: save() jsonEncode(endpoints) to ~/.yourvpn/endpoints.json with no encryption; repo-wide grep for flutter_secure_storage in lib/ returns zero imports/usages (only pubspec.yaml + generated registrant reference it). NormalizedEndpoint includes WireGuard privateKey, presharedKey, ss/trojan passwords.
IMP: Any other process/user with filesystem read, device backup, or synced home dir recovers long-lived VPN credentials. Renders key theft silent and persistent.
REC: 

[2] Windows engine config (private key) written to world-readable temp file, leaks on crash [high]
EV: lib/core/services/windows_box_process.dart start(): File('${Directory.systemTemp.path}/yourvpn_box_${ms}.json') then writeAsString(jsonEncode(config.json)) with default ACLs; _cleanupConfig() runs on spawn-failure and exit/stop paths but a process kill/crash between write and cleanup leaves the key on disk; predictable timestamped name.
IMP: Private key material recoverable from temp dir by other local users/forensics after crash; predictable names aid scraping.
REC: 

[3] Fail-open window: firewall enforced only after engine traffic is flowing [high]
EV: lib/core/services/tunnel.dart connect(): comment 'firewall — enforced last, only once traffic is already flowing', sequence box.start(config).timeout(boxStart) succeeds and only then firewall.enforce(); box-start failure with fd!=null closes fd but every successful start has a window where the TUN routes before enforce() completes.
IMP: First packets (DNS, app traffic) can leave outside kill-switch policy; on slow/failing enforce() the leak window grows to the 8s firewallEnforce timeout.
REC: 

[4] Crafted subscription crashes import via direct `as` casts instead of validated coercion [medium]
EV: lib/modules/vpn/repositories/ingestion/parsers.dart ClashYamlParser._proxy hysteria2/tuic branches use node['server'] as String and node['port'] as int; VmessUriParser uses doc['add'] as String / doc['id'] as String — a YAML/JSON type mismatch throws TypeError, not the FormatException callers catch for malformed input (vless/ss paths use stringField/intField correctly).
IMP: A malicious or corrupt subscription/mirror entry DoSes endpoint import (uncaught-type crash path); attacker-controlled subscription content becomes a client DoS vector.
REC: 

[5] Updater misparses GitHub rate-limit reset epoch, starving security updates [medium]
EV: lib/modules/updates/updater.dart UpdateFetcher._parseReset(): DateTime.now().add(Duration(seconds: value)) treats the absolute epoch (~1.7e9) as a relative offset (correct form in lib/core/network/http_cache.dart is fromMillisecondsSinceEpoch(value*1000)); resulting retryAfter is decades.
IMP: After one GitHub 403 rate-limit, the updater backs off effectively forever, so patched releases are never surfaced — a one-packet rate-limit becomes durable update suppression.
REC: 

[6] Android manifest leaves allowBackup and cleartext defaults permissive [medium]
EV: android/app/src/main/AndroidManifest.xml <application> sets label/name/icon only — no android:allowBackup="false", no android:usesCleartextTraffic="false", no networkSecurityConfig; services/activities export flags are correct (MainActivity exported=true, YourVpnService/ForegroundService exported=false with BIND_VPN_SERVICE).
IMP: adb/cloud backup can exfiltrate app-private files including the plaintext endpoints.json credentials; any future http:// URL (mirror, subscription) is permitted to downgrade to cleartext, enabling credential/config interception.
REC: 

[7] Engine log bus stores and displays secrets verbatim, no redaction [medium]
EV: lib/modules/logs/log_bus.dart LogBus.add()/EngineLogLine.parse() truncate and dedupe only — no redaction of private_key/password/auth/token patterns; lib/core/services/windows_box_process.dart feed() keeps _lastErrorLine on FATAL/ERROR verbatim and throws it as StateError to the UI, and LogBus lines render on the Logs screen.
IMP: Secrets echoed in engine FATAL/config-error lines persist in the in-memory buffer, surface in error dialogs/screenshotted logs, and leak via user-copied diagnostics.
REC: 

[8] Supply chain floats: caret ranges with no committed lock; fork not a verifiable submodule [medium]
EV: pubspec.yaml pins via ^ (material_3_expressive ^1.1.1, drift ^2.34.3, flutter_secure_storage ^11.0.0, …); pubspec.lock exists locally but decisions log notes it untracked ('untracked, add on commit'); git submodule status for go/amnezia-box fails ('no submodule mapping in .gitmodules') so the claimed pin 57276220 cannot be verified or rebased as a submodule.
IMP: CI/developer builds can silently resolve different dependency code than reviewed; fork drift is undetectable, letting upstream or transitive compromise ship without a pin change.
REC: 


=====DIM 7 : UI/UX/i18n audit =====
SUMMARY: UI shell is RTL-clean (EdgeInsetsDirectional throughout), TextScaler clamped 0.9-1.35 with goldens, and Semantics strong on tiles/edit/delete — but M3E is pinned yet unused, hardcoded English litters Diagnostics/editor sheets/wizard/home tiles outside ARB coverage, the wizard hard-gates the app with no step-1 skip and a dead setup-guide tile, Semantics misses 4+ icon-only buttons, error cards risk overflow at ceiling scale, and three microcopy bugs (step count, logs no-matches, static stats) need fixes.

[1] M3E dependency pinned but never applied [high]
EV: lib/app/app.dart builds ThemeData(useMaterial3:true, ColorScheme.fromSeed) though pubspec pins material_3_expressive ^1.1.1 + cue; no M3ExpressiveTheme, expressive component, or cue import anywhere in lib/. Prototype docs/prototype-final.html promises M3E prism/bento hero.
IMP: App ships baseline M3, not the M3E fidelity the spec/prototype sells; expressive shapes, motion, and type remain unverified.
REC: Wire M3Expressive theme (or document deliberate deferral) and add one golden/widget test asserting expressive tokens resolve.

[2] Hardcoded English bypasses EN/FA ARB coverage [high]
EV: diagnostics_screen.dart hardcodes 'Diagnostics', 'Refresh', 'DNS hijack', 'Ping (TCP 1.1.1.1:443)', 'unreachable', 'Stability window', 'hierarchical score: logs → ping → stability', level.name. groups_screen form hardcodes 'Edit group/New group/Tag/Members/Selector/Urltest/Cancel/Save'. rules_screen form hardcodes 8 field labels + 'Clash mode/Invert match'. wizard _SplitStep shows 'No user apps found'. home StatsTile '0 B / 0 B', UpdateTile 'Updates'/'Update x'. l10n parity test only covers ARB keys, so these slip through.
IMP: FA users see English islands across Diagnostics, both editor sheets, wizard empty state, and two home tiles.
REC: Add missing ARB keys (diagnostics*, groupForm*, ruleField*, wizardNoApps, stats, updates*), replace literals, extend l10n_parity test with a no-hardcoded-English literal scan or per-screen pump.

[3] Wizard gates the whole app with no skip on step 1 [high]
EV: AppShell (app.dart) renders Wizard instead of child until step==done; _VpnStep FilledButton is disabled (null) once granted with no Next/Continue, and only advances via requestVpnPermission(). A denied-but-persistent or desktop-no-op permission state strands the user on step 1 with no skip path (battery step has Skip, VPN step does not).
IMP: First-run dead end: user can never reach the 5 tabs if the system dialog is dismissed or permission is already granted.
REC: Add Skip/Continue on the VPN step (or auto-advance when granted) and a widget test pumping AppShell through deny->skip->done.

[4] Dead setup-guide tile; reduce-motion honored in one place [medium]
EV: WizardTile.onTap goes to '/home' which is the wizard-gated route itself; after onboarding it just re-pumps HomeScreen. PowerTile is the only control honoring MediaQuery.disableAnimationsOf; Logs _maybeFollowTail jumpTo, SegmentedButton switches, InkWell ripples have no reduce-motion branch.
IMP: Setup-guide tile is a dead button; vestibular-safety claim rests on one tile while the rest of the app still animates.
REC: Point WizardTile at a real re-runnable onboarding route (or remove it) and centralize a reduce-motion guard (durations zeroed) with a test.

[5] Inconsistent Semantics on icon-only buttons [medium]
EV: Logs clear IconButton has tooltip but no Semantics wrapper (pause/export have it). Diagnostics refresh IconButton likewise tooltip-only. Rules/groups add buttons are bare IconButtons with tooltip only. Screen-reader labels are inconsistent tile-to-tile.
IMP: Icon-only controls announce inconsistently; audit tooling checking Semantics(button) fails on 4+ controls.
REC: Wrap all icon-only IconButtons in Semantics(button:true,label) like the edit/delete buttons already do.

[6] Error cards + bento grid unguarded at ceiling scale [medium]
EV: Rules validation-error Card and groups error Card sit in a fixed Column under Expanded list with unbounded for-loop Text children plus title; long suffix/condition lists and tall FA strings at 1.35 scale can push Column past viewport (no Flexible/ScrollView). Home GridView.count has no childAspectRatio and EndpointTile needed a SingleChildScrollView retrofit already.
IMP: Overflow risk concentrates on the exact screens (30-field editor, FA at ceiling scale) the golden test does not cover — only PowerTile has PNG goldens.
REC: Constrain error cards (Flexible + inner scroll, cap lines), set explicit tile aspect ratio, and add 1.35-scale pump tests for rules/groups/diagnostics in FA.

[7] Step counter, logs empty-state, and stats microcopy bugs [low]
EV: wizardStepOf 'Step {step} of 3' fed state.step.index+1; enum has 4 values (done=3) so any future render at done shows 'Step 4 of 3'. Logs empty-state shows logsSearchHint ('Search logs') when filter/search yields zero but lines exist — wrong string for 'no matches'. StatsTile is static '0 B / 0 B' with no Semantics or l10n.
IMP: Confusing microcopy: impossible step count, misleading empty state, dead stats tile erodes trust in diagnostics-adjacent surfaces.
REC: Derive step count from a step list excluding done; add logsNoMatches key; either wire StatsTile to real counters or mark it placeholder with accessible label.


=====DIM 8 : perf/startup =====
SUMMARY: Startup path itself is lean (3 timed phases, Workmanager post-frame), but main-thread sync file reads, unbounded fetch buffering, 64KB isolate cutoff, 2000-line log buffer with full copies, eager updater import + 300ms Windows delay, and fsync-heavy full rewrites are the perf/battery risks.

[1] Synchronous file IO on main thread (stores + HttpCache) [high]
EV: EndpointStore.read() uses existsSync + readAsStringSync + jsonDecode; EndpointsController.build() calls ref.watch(endpointStoreProvider).read() synchronously on provider build (endpoints_controller.dart:60). Same pattern in UpdateStore.read()/lastCheckedAt() (updater.dart: readAsStringSync/existsSync). HttpCache._readDisk uses existsSync/readAsStringSync/readAsBytesSync on the caller isolate.
IMP: Disk + JSON parse on UI thread blocks first-frame and tab switches; large endpoints.json causes jank/ANR, worse on low-end Android.
REC: Make reads async (readAsString/readAsBytes/exists), preload once in main.dart pre-runApp Future or FutureProvider, cache in memory; keep build() pure from cached state.

[2] Unbounded response buffering in plainFetch [high]
EV: plain_fetch.dart folds response chunks with acc..addAll(chunk) into List<int> then Uint8List.fromList, with no content-length / max-bytes guard; endpoints_controller importText utf8.encode(payload) duplicates full payload before isolate hop.
IMP: Multi-MB subscription download = O(n^2) copies + 2-3x peak memory; OOM/freeze risk and excess radio/battery on metered links.
REC: 

[3] Ingestion isolate threshold leaves medium payloads on UI thread [medium]
EV: endpoints_controller.dart: bytes.length > 64KB goes to Isolate.run, else parseAndNormalize runs inline (WgIni/ClashYaml/SingboxJson + regex sniffing + base64 decode). 30-60KB YAML/JSON still parses ~100ms+ on UI isolate.
IMP: Paste/import of medium subscriptions drops frames during typing-driven import; importing=false spinner janks.
REC: Always parseInIsolate (or lower threshold to ~8-16KB / move sniff+parse off-thread); keep 64KB only as fallback.

[4] LogBus caps + LogsController full-buffer copy each batch [medium]
EV: LogBus default capacity=2000, maxLineLength=4096 (~8MB retained strings) with _buffer.removeRange compaction; LogsController._flush every 250ms does bus.lines (full unmodifiable copy) + sublist copy during floods.
IMP: Engine log flood = repeated O(2000) list copies + widget rebuilds; memory held after flood, scroll jank on Logs tab.
REC: Lower capacity (e.g. 500-1000), render windowed list (ListView.builder on last N), flush by appending _pending delta instead of full-buffer copy; clear buffer on disconnect.

[5] Updater eagerly loaded; Windows start has fixed 300ms delay [low]
EV: main.dart eagerly imports modules/updates/updater.dart, windows_box_process, policy/rule stores; only Workmanager init is post-frame deferred. No deferred import for updater/check path. WindowsBoxProcessAdapter.start awaits 300ms delay + exitCode.timeout(Duration.zero) poll race to detect early exit.
IMP: Larger startup code size / slower first frame; every Windows connect pays +300ms latency and a fragile exit poll.
REC: deferred import updater + windows adapter; replace 300ms sleep + zero-timeout poll with exitCode race against short timer or process liveness callback.

[6] Fsync-heavy full-file rewrites without dirty-check [low]
EV: atomic_write flush:true fsyncs every write; DebouncedSaver delay 300ms coalesces keystrokes but import/delete/manual paths each schedule full endpoints.json rewrite (jsonEncode of whole list) with no size cap; HttpCache._writeDisk does two fsynced writes (meta+body) per fetch.
IMP: Frequent full-file fsyncs wake disk/radio, cost battery and wear; large endpoint lists rewrite MBs per delete.
REC: Keep debounce, add trailing-only + max wait, skip save when content unchanged (hash compare), batch meta+body into one file or use flush:false for cache bodies.


=====DIM 9 : updates/subs/geo audit =====
SUMMARY: Updates/subs/geo are well-tested in isolation (403/429/401, ETag/304, stale-while-revalidate, SRS magic) but production wiring undercuts them: the latest.json mirror is never passed outside tests, the rate-limit reset parser in UpdateFetcher is wrong (epoch treated as offset), the 24h workmanager task covers only the app check and persists a self-comparing version, GeoAsset.ensure() pins the bundled SRS on first run, and platform resolution silently defaults unknown ABIs/platforms to android-arm64.

[1] Mirror fallback is dead code in production paths [high]
EV: updates_controller.dart:77-78 constructs UpdateSource(fetchImpl:...) with no mirrorUrl; updater.dart:297 background task likewise omits mirrorUrl. Only tests pass mirrorUrl (updater_test.dart:174,206,237).
IMP: In production the gh-pages latest.json mirror is never consulted, so the single-producer pipeline (build-android metadata job + gh-pages download from release) provides zero rate-limit resilience despite tests covering it.
REC: Thread mirrorUrl through a provider (e.g. const default mirror https://<org>.github.io/yourvpn/latest.json) into UpdateController.checkNow and updateCheckBackgroundTask; add a test that the default-constructed controller passes a non-null mirrorUrl.

[2] UpdateFetcher misparses x-ratelimit-reset as relative offset [high]
EV: updater.dart _parseReset: DateTime.now().add(Duration(seconds: value)) vs http_cache.dart _parseReset: DateTime.fromMillisecondsSinceEpoch(value*1000, isUtc:true). GitHub sends absolute epoch seconds.
IMP: After a 403 the app reports retry ~55 years out; any backoff/scheduling around resetAt is meaningless.
REC: Copy HttpCache._parseReset (DateTime.fromMillisecondsSinceEpoch(value*1000, isUtc:true)) into UpdateFetcher; add a unit test asserting resetAt ≈ epoch 1750000000.

[3] Workmanager 24h task saves self-version and covers app only [medium]
EV: updater.dart:303 save(info, info.version) — stored localVersion always equals remote version; main.dart:109 registerPeriodicTask frequency 24h, ExistingPeriodicWorkPolicy.keep, Constraints(connected), single task 'updatesDaily' calling only updateCheckBackgroundTask(); no GeoAsset.refreshAll/subs wiring.
IMP: Background update state never surfaces as 'available' correctly; daily task is update-only while spec requires daily SRS+subs+app refresh, and a keep-policy re-register silently keeps stale config.
REC: Save with real localVersion (package_info_plus, passed via inputData) or skip save when !isNewerThan; chain GeoAsset.refreshAll (+ subscription refresh) into the same 24h task or register separate periodic tasks; use ExistingPeriodicWorkPolicy.update or log registration outcome.

[4] GeoAsset.ensure() prefers bundled fallback over live data, refresh path writes by different key [medium]
EV: geo_asset.dart:50-72 ensure: cached-hit return, else copy initialDir/spec.initialFile and return without network; refreshAll writes File(cacheDir/spec.initialFile). Coincides today (geosite-cn.srs) but keys differ conceptually (tag vs initialFile).
IMP: First launch after a bundled-asset refresh pins the stale copy in cacheDir; refreshAll must run before any config build or the VPN routes on outdated geo data. Naming coupling (initialFile vs tag.srs) will silently diverge for the next asset.
REC: In ensure(), copy-then-revalidate (or record bundled version/date and force refreshAll when stale); write refreshAll output to tag.srs (derive filename from tag, not spec.initialFile) or assert equality.

[5] ABI/platform resolution gaps: x86 unmapped, UnsupportedError swallowed [medium]
EV: updater.dart:200-214 resolvePlatformKey defaults any unknown Android ABI to android-arm64; no x86 entry; updates_controller.dart:46-51 catches UnsupportedError and returns 'android-arm64'. platformFilters has only 4 keys (no ios/linux).
IMP: x86 emulators download an arm64 APK (install failure); swallowed UnsupportedError hides unsupported-platform bugs and could offer Android APKs on desktop test harnesses.
REC: Add explicit x86 mapping (or a clear UnsupportedError for unmapped ABI), and surface unsupported platforms as UpdateIdle/Failed with a message instead of silently defaulting to android-arm64.

[6] GeoAsset.getPath() has no existence guarantee; offline fallback ends at ensure() [medium]
EV: geo_asset.dart:76 getPath returns cacheDir/tag.srs string with no exists check; ensure() is the only copy-fallback (geo_asset_test covers ensure/download/refresh + SRS magic 'SRS', but no getPath-missing case). rule_sets/initial_assets/ SRS files verified present with SRS magic (53 52 53 01).
IMP: Config builders (dns/routing via getPath) can reference a nonexistent .srs on fresh installs where ensure() was skipped or failed, breaking sing-box config load despite 'never throws' claims elsewhere.
REC: Make startup call ensure() for all registry tags before assembling config (or have getPath fall back to initialDir path when cache file is absent); add a test for getPath-before-ensure.


=====DIM 10 : release/CI/upstream =====
SUMMARY: Release CI is well-designed (3 tag-triggered jobs, with_awg sanity gate, APK size gate, single-producer latest.json) but has never run: no git remote and no tags exist. Before v0.1.0 the user must add the remote/push/tag, wire Gradle release signing + 4 secrets (Gradle currently debug-signs), and then verify latest.json covers all 4 platform keys. Fork pin (1.14.0-rc.1-awgm.15 / 57276220) is consistent across Makefile, libbox.ps1, and CI; trackers (todo.md, decisions.tsv) need P1/P2 backfill and the Windows AWG assertion deserves hardening.

[1] No git remote, no tags — release CI never executed [high]
EV: git remote -v returns empty; tasks/handoff.md Next #1 says 'git remote add origin <url> → push → tag v0.1.0'. All 3 release workflows trigger only on tags: ['v*'] (+dispatch). No tags exist (git tag --list empty).
IMP: CI has never run end to end; v0.1.0 cannot ship until a remote exists and a v* tag is pushed.
REC: User creates repo, git remote add origin <url>, push master, then tag v0.1.0 and verify the android/windows/metadata jobs plus latest.json attach.

[2] Release signing unwired (debug keys) + signing secrets unset [high]
EV: android/app/build.gradle.kts:31-33 release block uses signingConfigs.getByName("debug") with TODO comment; no key.properties lookup. build-android.yml writes android/key.properties only if secrets.KEYSTORE_BASE64 != '' — secrets unset, and nothing in Gradle reads that file. No *.jks in repo (correct) and no local.properties entry.
IMP: Tagged APKs would ship debug-signed; Play/manual trust and upgrade continuity blocked.
REC: Wire release signingConfig reading android/key.properties (storeFile/storePassword/keyAlias/keyPassword), keep secrets out of repo, set the 4 GitHub secrets before tagging.

[3] latest.json exists only as CI artifact — first-release race/absence risk [medium]
EV: Single producer is build-android metadata job: polls release assets up to 40 min for windows-x64.zip, then writes latest.json via gh release upload --clobber. No dist/latest.json or site/latest.json in repo; gh-pages.yml downloads latest.json from the release (warns and ships without it if absent). Updater (lib/modules/updates/updater.dart:40,101,139) accepts GitHub API or the gh-pages latest.json mirror.
IMP: If the Windows job fails or is slow, the site ships an android-only (or missing) map; in-app update still works via GitHub API fallback, but the documented fetch('latest.json') path is fragile on first release.
REC: On v0.1.0 tag, confirm metadata job attached a 4-key map (android-arm64/arm/x64, windows-x64) and site/latest.json exists; keep the GitHub-API fallback as primary until the mirror is proven.

[4] Fork SHA pinned and consistent, but rebase path is manual/detached [medium]
EV: Makefile, scripts/libbox.ps1 ($version='1.14.0-rc.1-awgm.15'), and workflows all pin 1.14.0-rc.1-awgm.15; go/amnezia-box HEAD is 57276220a20679cad762c9644f6abdaf39ab7688 with `git describe` = 1.14.0-rc.1-awgm.15 — consistent. But submodule is on detached HEAD ('HEAD (no branch)'), and upstream-check.yml only echoes drift (no bump PR, no strings sanity).
IMP: Pin is correct today, but any upstream rebase before v1.0 is manual and error-prone; a wrong rebase silently changes with_awg behavior.
REC: Before tagging, re-confirm strings libbox.so amneziawg check locally; after v0.1.0, turn drift detection into an explicit chore(upstream) PR with the documented make+strings+test+sing-box check evidence row.

[5] Trackers stale: todo.md + decisions.tsv behind P0/P1/P2 [medium]
EV: tasks/todo.md shows 17/17 pre-hardening state although handoff reports P0+P1+P2 landed (241 tests, commits through 6213424); docs/decisions.tsv has 68 rows but handoff admits 'P1/P2 rows pending' and 'todo.md still shows pre-hardening state'.
IMP: Release audit trail is incomplete; reviewers cannot verify what shipped since the last TSV row.
REC: Append the P1/P2 decision rows and flip/add todo checkboxes before tagging so the tag has a matching paper trail.

[6] Windows AWG assertion weak, no shipped-config check in CI [low]
EV: build-windows.yml asserts AWG via `sing-box version | Select-String awg` (version string may not contain 'awg') and never runs `sing-box check -c profiles/config.wg-awg.json` on the shipped exe; build-linux.yml is an intentional v1.1 stub that still 'passes' on every v* tag.
IMP: A Windows asset could pass CI while shipping a non-AWG or config-rejecting binary; the green Linux stub masks MVP platform scope on the tag page.
REC: Strengthen Windows job with the strings-equivalent/config check already used for Android; either scope Linux workflow to non-MVP or leave the stub clearly labeled (as-is) so v1.0 tag checks read honestly.


=====DIM 11 : product gaps =====
SUMMARY: v1.0 gate (do before any tag): implement compare_capabilities.py matrix, build AND/OR group editor UI on the ready model, add Sentry crash reporting, execute 7 leak tests on-device, push + tag v0.1.0 to prove CI/latest.json. v1.1: best-node urltest auto-select, encrypted backup export/import, prototype signature polish. Quick wins under a day: capability script, Sentry, connect-metrics tile, TextScaler goldens, decisions.tsv backfill.

[1] Capability-win script unimplemented (Criterion 1 unverifiable) [high]
EV: scripts/compare_capabilities.py is a 17-line stub: prints file sizes, sys.exit(0), TODO row-by-row compare vs 13 VPNs never implemented.
IMP: Success Criterion 1 has no verification; 'win vs 13 VPNs' is an unverified claim, blocks release gate.
REC: v1.0 quick win (~1h): implement matrix parse (intent.md rows x research/*.md) emitting PASS/FAIL table; run in CI. Highest ROI.

[2] AND/OR logical rule-groups UI missing (model ready, no editor) [high]
EV: SPEC story 2 requires logical 'and' UI in 30-field editor; routing_policy.dart compiles isLogical/and-or (logicalMode, logicalShapeErrors) but rules_screen only disables Save until a condition — no AND/OR group builder UI; handoff lists 'logical AND/OR rule-groups UI' as open.
IMP: Power-user routing story fails; compiler supports it but users cannot build nested groups.
REC: v1.0: add logical-group editor (parent node + and/or toggle + add/remove sub-rules, surface logicalShapeErrors inline). Small UI over ready model.

[3] No crash reporting (only log-stream FATAL scan) [high]
EV: No sentry/firebase_crashlytics dep; only 'crashed' channel event + FATAL-scan in log stream. Handoff 'Leftovers' lists 'sentry/crash reporting' not started.
IMP: Field crashes (native Go/Kotlin + Dart) invisible; cannot triage v1.0 stability.
REC: v1.0 quick win: add sentry_flutter, redact keys/UUIDs, upload on next launch; native crash event -> Sentry breadcrumb. ~half day.

[4] Best-node / urltest auto-select missing [medium]
EV: No urltest/best-node sort in lib; diagnostics has ping/probers but no auto-pick; SPEC story 2 cites 'HKG-AUTO urltest 300s' group, groups_screen/policy_store have 3-tier but no latency benchmark + auto-select.
IMP: Users manually pick nodes; flagship 'best-node' parity gap vs researched VPNs.
REC: v1.1: urltest prober (TCP ping sweep over group members) + 'Auto (best ping)' selector tile + lastConnectMetrics hookup. Needs design first.

[5] No backup/export-sync of profiles and rules [medium]
EV: No backup/export path found: atomic_write + debounced_saver cover crash-safe local writes, no encrypted profile export/import or sync; SPEC/prototype silent on backup.
IMP: Device loss/reset wipes 7 subs + 30-field rules; no migration path — must-have for power users.
REC: v1.1: encrypted JSON export/import (share sheet + file picker, password via flutter_secure_storage key). Ask-first: new file format/schema decision.

[6] 7 leak tests + on-device proof never executed [high]
EV: Criterion 2 demands 7 leak tests green on Android 13+ and Win 11; repo has scripts/leak_test.sh + kill_switch test but handoff 'Leftovers' admits on-device proof + 7 leak tests never run (no adb device).
IMP: Leak-free claim unverified; shipping v1.0 without it risks the exact DNS/IPv6/QUIC leaks 6/16 VPNs had.
REC: v1.0 gate: run leak_test.sh on real devices before any tag; record results in progress log. No code, just hardware time.

[7] Prototype-vs-shipped UI gap: metrics tile unwired, signature polish deferred [medium]
EV: Prototype has blended Bento home (10 tiles), DNS scanner 0-6 display, 3-step wizard, live logs, 30-field editor; shipped UI is functional core (5 tabs, PowerTile+StateTile, groups/rules editors, Logs rewrite, diagnostics tab) with deferred M3E polish; handoff notes diagnostics connect-metrics tile data-ready but unwired, TextScaler 2.0 goldens missing.
IMP: Criterion 5 'UX polished' partially met: works but lacks signature prism/pulse/color-shift identity and metrics tile.
REC: v1.0 quick wins: wire connect-metrics tile (data ready), TextScaler 2.0 goldens. v1.1: prism hero + pulse/motion polish pass.

[8] Release pipeline unverified (no remote, no tag, no per-ABI splits) [medium]
EV: handoff 'Next' lists: no git remote/push/CI run, per-ABI splits skipped (universal APK only), chain-detour integration tests missing, docs debt (decisions.tsv lacks P1/P2 rows, todo.md stale at 17/17).
IMP: Criterion 7 (reproducible 3-job build + latest.json + sha256) unverified; release pipeline is theory until first tag.
REC: v1.0 gate in order: git remote add + push -> tag v0.1.0 -> verify 3 jobs + latest.json; add per-ABI splits + chain-detour tests; backfill decisions.tsv. Quick wins, no product decision needed.


=====LINE 12 RAW=====
{"index":11,"key":"0a3ee96acc66658d4079eaa04fb0c129","ok":true,"text":"# Qanat-VPN Synthesized Review\n\n## 1) Per-dimension verdicts\n\n**Competition-audit: WIN on depth, LOSE on breadth.** Star is real: AWG all-values Jc/Jmin/Jmax, S1-S4, H1-H4, I1-I5 + H1∩H2 pre-handshake validation. Unified 30-field + 3-tier + AND/OR + Lockdown+WFP kill-switch beats split competitors. Parity on VLESS/Reality/Vision/XHTTP, VMess, Trojan, SS2022, Hysteria2, TUIC, uTLS, FakeIP, DoH, subs via shared sing-box/Xray/amneziawg-go. Gap is platform (Android+Win only), SSR/Naive, WG-Tunnel automation, 30+ locales/sync/REST.\n\n**Routing/DNS/Firewall: compiler solid, wiring fail-open.** 30-field/invert/groups/SRS-shape handling verified, no defect. Shipped config fails closed-policy: `FirewallPolicy.baseRules()` never called, TOR-CHAIN tag dangles, FakeIP excludes dropped, v6 incoherent, SRS CN-only forced over PROXY, per-app fields unguarded.\n\n**Tunnel lifecycle: PARTIAL FAIL.** Windows `sing-box.exe` relative path breaks installed-app connect. `_block()` never stops foreground service + airplane check after start = stale notification + drain on every block path.\n\n**Protocols/import-emit: VALIDATE WELL, EMIT LOSSILY.** Strengths: WG INI + validation thorough, Id/Ip/Ib correctly withheld (WireSock-only FATAL), tuic `tls.alpn` + Tor-detour correctly shaped. Losses: Hysteria2 mport/hop dropped, Clash AWG truncates S3/S4/I1-I5, XHTTP/gRPC no emitter, reality-without-uTLS FATAL risk, SSH absent, ECH stub, AWG 3.1 extras + pinSHA256/wireguard-URI/SIP008/AnyTLS tail missing.\n\n## 2) Competitor win / tie / lose\n\n**WIN:**\n- AWG depth + H1∩H2 validation vs WG-Tunnel tuner parity + Throne manual-JSON no-UI + routing bug.\n- 30-field + 3-tier + AND/OR single typed policy vs Throne per-process only, FlClash/Verge providers-only.\n- Lockdown dummy + WFP Network Lock + single TUN + 7 leak tests vs Karing/Throne soft restore-proxy.\n\n**TIE:**\n- Protocols/transports/DNS/subs via same engines; Tor sidecar `127.0.0.1:9050` avoids `type:tor` #4200 fatal; ECH deferred v1.1. Moat is seams (Tunnel/Ingestion/RoutingCompiler), not novel protocols.\n\n**LOSE:**\n- Platform: Android+Win vs Karing Win/macOS/Linux/Android/iOS-tvOS, Throne Qt Win/macOS/Linux.\n- Legacy: SSR (Karing `ShadowsocksROutboundOptions`), NaiveProxy/Snell/Mieru/Juicity (Throne).\n- WG-Tunnel UX: auto-tunnel by network, Kernel/Userspace toggle, hev-socks5 Lockdown dummy, biometric/quick-tile/intents.\n- Maturity: 30+ langs (slang) vs EN/FA, iCloud/WebDAV/LAN-ZIP sync, Mihomo `127.0.0.1:9090` REST + mrs/yaml + observatory/leastPing.\n\n## 3) Top-20 gaps ranked impact x effort\n\n| # | Gap | Sev | I×E | Files |\n|---|---|---|---|---|\n| 1 | Kill-switch blocks never shipped, `final=PROXY` fail-open, no `::/0`/LAN blocks | High | H×1d | `lib/utils/config_assembler.dart`, `lib/modules/routing/firewall.dart`, `profiles/config.wg-awg.json` |\n| 2 | TOR-CHAIN rules ref `TOR-CHAIN`, sidecar emits `tor-entry` -> dangling/FATAL | High | H×2h | `lib/utils/routing_compiler.dart`, `lib/models/tor_chain_options.dart` |\n| 3 | FakeIP `filterMode/fakeIpFilters` dropped from `toDnsJson()` -> .lan/.local/NTP/captive break | High | H×3h | `lib/modules/dns/dns_config.dart`, `test/dns/dns_config_test.dart` |\n| 4 | Windows exe relative `windows/sing-box.exe` -> spawn fail when CWD!=bundle root | High | H×2h | `lib/modules/vpn/windows_box_process.dart` |\n| 5 | Reality without uTLS emits FATAL config | High | H×3h | `lib/utils/endpoint_emitters/reality.dart`, `lib/models/tls_options.dart` |\n| 6 | Clash AWG import truncates S3/S4/I1-I5 | High | H×4h | `lib/modules/profiles/clash_parser.dart`, `lib/models/wireguard_awg_options.dart` |\n| 7 | Hysteria2 `mport/hop` parsed but dropped on emit | High | H×4h | `lib/utils/endpoint_emitters/hysteria2.dart` |\n| 8 | XHTTP/gRPC transport no emitter | High | H×3d | `lib/utils/endpoint_emitters/xhttp_grpc.dart`, `lib/models/transport_options.dart` |\n| 9 | `_block()` never `foreground.stop()`, airplane check after start | High | H×1d | `lib/modules/vpn/tunnel.dart` |\n| 10 | SSH outbound entirely absent | High | H×3d | `lib/models/ssh_options.dart`, `lib/utils/config_assembler.dart` |\n| 11 | IPv6 incoherent: `::/0 BLOCK` + `fdfe::/126` TUN + `fc00::/18` FakeIP + `::/0` allowed_ips + AAAA, relaxed in connecting | Med | M×1d | `lib/modules/routing/firewall.dart`, `lib/modules/dns/dns_config.dart`, `lib/utils/config_assembler.dart` |\n| 12 | SRS registry CN-only + forced `geosite-cn` download over `PROXY` first-boot deadlock | Med | M×1d | `lib/utils/geo_assets.dart`, `lib/utils/routing_compiler.dart`, `lib/utils/config_assembler.dart` |\n| 13 | Per-app `packageNames/processNames/paths/userIds/ssid` emitted unguarded, silent no-op cross-OS | Med | M×4h | `lib/models/route_rule.dart`, `lib/utils/routing_compiler.dart` |\n| 14 | TUIC `udp_relay_mode` dropped | Med | M×2h | `lib/utils/endpoint_emitters/tuic.dart` |\n| 15 | SSR + NaiveProxy no path | Med | M×1w | `lib/modules/profiles/importers/`, `lib/utils/config_assembler.dart` |\n| 16 | WG-Tunnel automation: auto-tunnel/ssid orchestrator, kernel toggle, Lockdown dummy, biometric/quick-tile | Med | M×2w | `lib/modules/vpn/`, `android/app/.../BoxEngine.kt` |\n| 17 | ECH unimplemented | Med | M×3d | `lib/models/tls_options.dart` |\n| 18 | AWG 3.1 extras + pinSHA256/wireguard-URI/SIP008/AnyTLS tail | Med | M×2d | `lib/models/wireguard_awg_options.dart`, `lib/modules/profiles/` |\n| 19 | `baseRulesScoped()` stub returns `baseRules()`, `allowLan` opens all RFC1918 | Low | L×2h | `lib/modules/routing/firewall.dart` |\n| 20 | Platform breadth + maturity: iOS/macOS/Linux, 30+ locales, WebDAV/iCloud sync, Clash REST/mrs | High/Low | H,L×months | `go/amnezia-box/`, `lib/l10n/`, `lib/modules/sync/` |\n\n## 4) Common vs unique\n\n**Common (fix once, fix many):** emit-drops-validated-fields (AWG S-params, Hy2 mport, TUIC relay, FakeIP filter); fail-closed not wired (firewall not called, `final=PROXY`, relaxed-connecting); platform-unaware emission (per-app, v6 TUN, exe path); tag-contract drift (TOR-CHAIN, `tls.alpn`, detour vs chain).\n**Unique:** TOR-CHAIN literal mismatch; forced CN-SRS over PROXY; `_block()` foreground leak; reality-uTLS FATAL; SSH/XHTTP-gRPC missing emitters; iOS/macOS/Linux scope cut.\n\n## 5) Quick wins / medium / big bets\n\n**Quick wins <1d:** #2 TOR tag (`TOR-CHAIN`), #3 emit `fake_ip_filter+mode` + test, #4 `Platform.resolvedExecutable` absolute, #5 reality requires-utls guard, #6 preserve S3/S4/I1-I5, #7 emit mport, #14 emit udp_relay_mode, #19 implement/delete `baseRulesScoped`, #13 platform warnings.\n**Medium <1w:** #1 prepend `baseRules()` + `validateOrdering` + `final=reject` fallback, #9 `_block` stops foreground + check-before-start, #11 one v6 story + enforce connecting, #12 register IR/category sets + local SRS + opt-in CN, #18 AWG 3.1 + URI/SIP008/pinSHA256, #17 ECH behind flag, #15 SSR/Naive importers.\n**Big bets:** #8/#10 XHTTP-gRPC/SSH emitters + probed tests on real sing-box; #16 auto-tunnel/kernel/Lockdown-dummy/biometric; #20 xcframework/service-binary + locales/sync/REST.\n\n## 6) Ticket / branch / loop ship plan\n\n**Loop P0 fail-closed (gate release):** `fix/fw-tor-fakeip-winblock` covers #1,#2,#3,#4,#9. Gate: `sing-box check -c profiles/config.wg-awg.json`, `sing-box rule-set compile`, `flutter test --coverage` >=70% routing/services, `dart format --set-exit-if-changed . && flutter analyze`.\n**Loop P1 emit-parity:** `fix/emit-awg-hy2-tuic-reality` covers #5,#6,#7,#14,#11,#13. Gate: round-trip import->store->emit tests on real sing-box, no FATAL on `endpoints[].id/ip/ib`, `tuic.tls.alpn`, `detour` not `chain`.\n**Loop P2 transports:** `feat/transports-ssh-xhttp` covers #8,#10,#12,#17,#18. Gate: 6-protocol probe matrix + `strings libbox.so \\| grep -q amneziawg`.\n**Loop P3 breadth:** `feat/platform-maturity` covers #15,#16,#20, needs device + signing decisions.\n\n**Verify every loop:**\n```\nflutter test --coverage && sing-box check -c profiles/config.wg-awg.json\ndart format --set-exit-if-changed . && flutter analyze && golangci-lint run ./...\n```\nLeak gate before tag: 7 scenarios + airplane + kill-switch reboot."}
