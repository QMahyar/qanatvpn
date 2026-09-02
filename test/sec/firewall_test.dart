import 'package:flutter_test/flutter_test.dart';
import 'package:yourvpn/core/services/tunnel.dart';
import 'package:yourvpn/modules/sec/firewall.dart';

void main() {
  group('FirewallPolicy.baseRules', () {
    test('hijack-dns is always first (leak order guarantee)', () {
      final rules = const FirewallPolicy().baseRules();

      expect(rules.first['action'], 'hijack-dns');
    });

    test('default: ipv6 blocked, lan blocked, dns pinned', () {
      final rules = const FirewallPolicy().baseRules();
      final outbounds = rules
          .where((r) => r.containsKey('outbound'))
          .map((r) => r['outbound'])
          .toList();

      expect(outbounds, contains('BLOCK'));
      final v6Block = rules.firstWhere(
        (r) => (r['ip_cidr'] as List<dynamic>?)?.contains('::/0') == true,
      );
      expect(v6Block['outbound'], 'BLOCK');
      final lanBlock = rules.firstWhere(
        (r) =>
            (r['ip_cidr'] as List<dynamic>?)?.contains('192.168.0.0/16') == true,
      );
      expect(lanBlock['outbound'], 'BLOCK');
    });

    test('allowLan drops the lan block rule', () {
      final rules = const FirewallPolicy(allowLan: true).baseRules();

      expect(
        rules.any(
          (r) =>
              (r['ip_cidr'] as List<dynamic>?)?.contains('192.168.0.0/16') ==
              true,
        ),
        isFalse,
      );
    });

    test('pinned dns: only tunnel resolver passes as DIRECT', () {
      final rules = const FirewallPolicy().baseRules();
      final directRules = rules
          .where((r) => r['outbound'] == 'DIRECT')
          .expand((r) => r['ip_cidr'] as List<dynamic>)
          .toList();

      expect(directRules, <String>['172.19.0.1']);
    });
  });

  group('enforce timing', () {
    test('enforce while connected or blocked, relax on disconnect', () {
      expect(FirewallPolicy.shouldEnforce(TunnelState.connected), isTrue);
      expect(FirewallPolicy.shouldEnforce(TunnelState.blocked), isTrue);
      expect(FirewallPolicy.shouldEnforce(TunnelState.connecting), isFalse);
      expect(FirewallPolicy.shouldEnforce(TunnelState.disconnected), isFalse);
      expect(FirewallPolicy.shouldEnforce(TunnelState.disconnecting), isFalse);
    });
  });
}
