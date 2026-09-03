import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'log_bus.dart';

/// Logs tab: live engine log (ring-buffered, newest at bottom, auto-scroll).
class LogsScreen extends ConsumerWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<EngineLogLine> lines = ref.watch(logsControllerProvider);
    final ThemeData theme = Theme.of(context);
    final ScrollController scroll = ScrollController();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text('Logs', style: theme.textTheme.headlineSmall),
                ),
                IconButton(
                  tooltip: 'Clear',
                  onPressed: () =>
                      ref.read(logsControllerProvider.notifier).clear(),
                  icon: const Icon(Icons.delete_sweep_outlined),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (lines.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'No engine logs yet. Connect to start the engine.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsetsDirectional.all(8),
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (ScrollNotification notification) {
                      return false;
                    },
                    child: ListView.builder(
                      controller: scroll,
                      itemCount: lines.length,
                      itemBuilder: (BuildContext context, int index) {
                        final EngineLogLine line = lines[index];
                        return SelectableText(
                          line.level.isEmpty
                              ? line.message
                              : '[${line.level}] ${line.message}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: line.isError
                                ? theme.colorScheme.error
                                : null,
                            fontFamily: 'monospace',
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
