import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yourvpn/core/services/tunnel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('listInstalledApps memoizes per session until invalidated', () async {
    const channel = MethodChannel('vpn_service');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var hits = 0;
    messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
      if (call.method == 'listInstalledApps') {
        hits++;
        return <Map<String, String>>[
          {'packageName': 'com.example.one', 'label': 'One'},
          {'packageName': 'com.example.two', 'label': 'Two'},
        ];
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final adapter = MethodChannelPlatformAdapter();

    final first = await adapter.listInstalledApps();
    final second = await adapter.listInstalledApps();

    expect(hits, 1);
    expect(first.length, 2);
    expect(identical(first, second), isTrue);
    expect(second[0].packageName, 'com.example.one');
    expect(second[1].label, 'Two');

    adapter.invalidateAppsCache();
    final third = await adapter.listInstalledApps();

    expect(hits, 2);
    expect(third.length, 2);
    expect(third[0].packageName, 'com.example.one');
  });
}
