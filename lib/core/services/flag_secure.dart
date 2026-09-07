import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Screens showing credentials (AWG private keys, backup passwords) flip
/// FLAG_SECURE for their lifetime so they never appear in screenshots or
/// the app switcher (audit W3.5). Windows is a no-op (no system screenshot
/// flag; DPI/overlay equivalents tracked separately).
class FlagSecure {
  static const MethodChannel _channel = MethodChannel('vpn_service');

  /// Enables FLAG_SECURE; call from initState of a credential screen.
  static Future<void> enable() => _set(true);

  /// Disables FLAG_SECURE; call from dispose of a credential screen.
  static Future<void> disable() => _set(false);

  /// Wraps a credential-displaying widget: enables on mount, disables on
  /// dispose. Re-entry (two stacked screens) is ordered by route push/pop —
  /// the outermost dispose runs last, so the flag clears only when all are
  /// gone.
  static Widget guard({required Widget child}) =>
      _FlagSecureLifecycle(child: child);

  static Future<void> _set(bool enabled) async {
    try {
      if (defaultTargetPlatform != TargetPlatform.android) {
        return;
      }
      await _channel.invokeMethod<void>('setFlagSecure', {
        'enabled': enabled,
      });
    } on Object {
      // Missing handler (tests, desktop): the flag is Android-only anyway.
    }
  }
}

class _FlagSecureLifecycle extends StatefulWidget {
  const _FlagSecureLifecycle({required this.child});

  final Widget child;

  @override
  State<_FlagSecureLifecycle> createState() => _FlagSecureLifecycleState();
}

class _FlagSecureLifecycleState extends State<_FlagSecureLifecycle>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FlagSecure.enable();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Backgrounded app-switcher snapshot shows the last frame: keep the
    // flag enabled for the whole route lifetime (enable/disable bracket it).
  }

  @override
  void dispose() {
    FlagSecure.disable();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

