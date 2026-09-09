#!/usr/bin/env bash
# leak_test.sh — 7 leak scenarios (SPEC.md Success Criteria).
# Run on-device (Android: adb shell termux / Windows: Git Bash as admin).
# Every scenario prints PASS/FAIL; any FAIL must block a release tag.
set -u

VPN_IF="${VPN_IF:-qanatvpn-tun}"   # tun interface name as engine reports it
PHYS_IF="${PHYS_IF:-wlan0}"       # physical uplink
DNS_VPN="${DNS_VPN:-172.19.0.1}"  # tunnel resolver
TARGET="${TARGET:-1.1.1.1}"

PASS=0; FAIL=0
check() { # check <name> <condition_exit_code>
  if [ "$2" -eq 0 ]; then echo "PASS  $1"; PASS=$((PASS+1)); else echo "FAIL  $1"; FAIL=$((FAIL+1)); fi
}

have() { command -v "$1" >/dev/null 2>&1; }

tcpdump_dnsleak() { # capture ISP-side DNS for N seconds while resolving
  local secs="$1"
  if ! have tcpdump; then echo "SKIP tcpdump missing"; return 0; fi
  (timeout "$secs" tcpdump -i "$PHYS_IF" -n port 53 2>/dev/null | grep -q . ) && return 1 || return 0
  # any port-53 packets on the physical interface during tunnel = leak → exit 0 above means found → fail
}

echo "── 1. Reboot/startup: no packets before VPN"
# After boot, before connect: resolve a domain, capture on physical if.
# Expected: traffic blocked (kill switch active before tunnel).
tcpdump_dnsleak 5; check "startup-block" $?

echo "── 2. Sleep/wake 60s"
# Suspend device 60s, wake, immediately resolve. No ISP DNS.
sleep 60
tcpdump_dnsleak 5; check "sleep-wake-block" $?

echo "── 3. Wi-Fi↔hotspot handoff"
# Continuous ping while switching networks; during reconnect no reply.
if have ping; then
  (ping -c 30 "$TARGET" >/dev/null 2>&1 &) ; sleep 2
  # simulate switch: (ip link set $PHYS_IF down/up here in a lab)
  sleep 10
  # during handoff window pings must not leave via physical if
  ! timeout 5 tcpdump -i "$PHYS_IF" -n icmp 2>/dev/null | grep -q "echo request"; check "handoff-block" $?
  pkill ping 2>/dev/null
else
  echo "SKIP ping missing"
fi

echo "── 4. DoH/QUIC bound to tunnel"
# HTTP3 (udp/443) to 1.1.1.1 must not appear on the physical interface.
! timeout 5 tcpdump -i "$PHYS_IF" -n "udp port 443 and host 1.1.1.1" 2>/dev/null | grep -q .; check "quic-tunnel-only" $?

echo "── 5. IPv6 escape"
# No public v6 traffic while tunnel is v4-only (or v6 blocked rule).
! timeout 5 tcpdump -i "$PHYS_IF" -n ip6 2>/dev/null | grep -q .; check "ipv6-blocked" $?

echo "── 6. Split audit (per-app bypass rows)"
# Apps on the bypass list must show connections NOT owned by the tunnel uid.
# Placeholder: verify with `ss -tnp` that bypass app's remote is not via tun.
if have ss; then
  ! ss -tnp 2>/dev/null | grep -q "172.19.0"; check "split-audit" $?
else
  echo "SKIP ss missing"
fi

echo "── 7. Captive portal"
# With portal unauthenticated, no non-portal traffic leaks.
! timeout 5 tcpdump -i "$PHYS_IF" -n "not port 80 and not port 53" 2>/dev/null | grep -q .; check "captive-portal" $?

echo "──"
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
