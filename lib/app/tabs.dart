import 'package:flutter/material.dart';

/// Placeholder tab screens; bento home carries the MVP, these land with
/// their deep modules (groups/rules with routing editor, logs with health).
class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) => const _Centered('Groups');
}

class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) => const _Centered('Rules');
}

class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context) => const _Centered('Logs');
}

class DiagnosticsScreen extends StatelessWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context) => const _Centered('Diagnostics');
}

class _Centered extends StatelessWidget {
  const _Centered(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(title));
  }
}
