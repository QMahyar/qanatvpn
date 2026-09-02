import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/services/tunnel.dart';
import 'modules/onboarding/wizard.dart';

void main() {
  runApp(
    ProviderScope(
      overrides: [
        platformAdapterProvider
            .overrideWithValue(MethodChannelPlatformAdapter()),
      ],
      child: const YourVpnApp(),
    ),
  );
}
