import '../../core/services/tunnel.dart';

/// Firewall/kill-switch policy for the max-firewall mode.
///
/// On every platform the engine (sing-box) owns packet filtering; this module
/// computes the *policy* the engine enforces and the ordering guarantees:
/// firewall ON before traffic flows, relaxed only after box.stop.
class FirewallPolicy {
  const FirewallPolicy({
    this.blockIpv6 = true,
    this.allowLan = false,
    this.allowPinnedDnsOnly = true,
    this.pinnedDns = const <String>['172.19.0.1'],
  });

  /// No v6 escape hatch unless the tunnel routes it.
  final bool blockIpv6;

  /// RFC1918 reachable while tunneled (printers, NAS).
  final bool allowLan;

  /// DNS may only leave via the tunnel resolver (hijack) — never the ISP.
  final bool allowPinnedDnsOnly;
  final List<String> pinnedDns;

  /// The route.rules entries the engine needs BEFORE any proxy rules, so
  /// leaks are impossible even for one packet.
  List<Map<String, dynamic>> baseRules() {
    return <Map<String, dynamic>>[
      const <String, dynamic>{
        'protocol': 'dns',
        'action': 'hijack-dns',
      },
      if (allowPinnedDnsOnly)
        for (final dns in pinnedDns)
          <String, dynamic>{
            'ip_cidr': <String>[dns],
            'outbound': 'DIRECT',
          },
      if (blockIpv6)
        const <String, dynamic>{
          'ip_cidr': <String>['::/0'],
          'outbound': 'BLOCK',
        },
      if (!allowLan)
        const <String, dynamic>{
          'ip_cidr': <String>[
            '10.0.0.0/8',
            '172.16.0.0/12',
            '192.168.0.0/16',
          ],
          'outbound': 'BLOCK',
        },
    ];
  }

  /// Modes the Tunnel drives: enforce while connected/blocked, relax only on
  /// clean disconnect. Mirrors FirewallAdapter semantics in tunnel.dart.
  static bool shouldEnforce(TunnelState state) {
    return state == TunnelState.connected || state == TunnelState.blocked;
  }
}
