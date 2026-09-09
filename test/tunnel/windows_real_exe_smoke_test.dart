import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qanatvpn/core/services/tunnel.dart';
import 'package:qanatvpn/core/services/windows_box_process.dart';

/// Real sing-box.exe smoke through the production adapter: spawn → started →
/// stop → stopped. Skips wherever the exe is not built (linux CI, before the
/// build step). The config is TUN-free so no admin rights are needed.
void main() {
  final exe = p.join(Directory.current.path, 'windows', 'sing-box.exe');
  final available = File(exe).existsSync();

  test('WindowsBoxProcessAdapter spawns the real engine', () async {
    if (!available) {
      // CI (ubuntu) / fresh clones without the exe: nothing to prove here.
      return;
    }
    final adapter = WindowsBoxProcessAdapter(executablePath: exe);

    final events = <BoxEvent>[];
    final sub = adapter.events.listen(events.add);

    await adapter.start(
      const TypedConfig(
        tag: 'smoke',
        json: <String, dynamic>{
          'log': <String, dynamic>{'level': 'warn'},
          'outbounds': <dynamic>[
            <String, dynamic>{'type': 'direct', 'tag': 'DIRECT'},
          ],
        },
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(events.map((e) => e.kind), contains(BoxEventKind.started));

    await adapter.stop();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(events.map((e) => e.kind), contains(BoxEventKind.stopped));
    expect(events.map((e) => e.kind), isNot(contains(BoxEventKind.crashed)));
  }, timeout: const Timeout(Duration(seconds: 60)));
}
