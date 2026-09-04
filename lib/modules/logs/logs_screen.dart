import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'log_bus.dart';

/// Which lines the Logs tab shows. `errors` keeps FATAL/ERROR — the filter
/// users need when pasting a bug report.
enum LogLevelFilter { all, errors }

/// Logs tab: live engine log (ring-buffered, batched 250ms, auto-scroll).
///
/// ConsumerWidget → StatefulWidget: the screen now owns its ScrollController
/// (created once, disposed once — the old build created + leaked one per
/// log line and reset scroll offset), the pause gate, the level filter, the
/// search query, and the follow-tail behavior.
class LogsScreen extends ConsumerStatefulWidget {
  const LogsScreen({super.key});

  @override
  ConsumerState<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends ConsumerState<LogsScreen> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  LogLevelFilter _filter = LogLevelFilter.all;
  bool _paused = false;
  bool _followTail = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _search.addListener(() {
      if (mounted) {
        setState(() => _query = _search.text.trim().toLowerCase());
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<EngineLogLine> _visible(List<EngineLogLine> lines) {
    return <EngineLogLine>[
      for (final line in lines)
        if (_filter == LogLevelFilter.all || line.isError)
          if (_query.isEmpty ||
              line.message.toLowerCase().contains(_query) ||
              line.level.toLowerCase().contains(_query))
            line,
    ];
  }

  void _maybeFollowTail(int count) {
    if (!_followTail || _paused || count == 0) {
      return;
    }
    // Post-frame: the list extent only exists after layout.
    Timer.run(() {
      if (!mounted || !_scroll.hasClients) {
        return;
      }
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<EngineLogLine> lines = ref.watch(logsControllerProvider);
    final List<EngineLogLine> visible = _paused ? _lastVisible : _visible(
      lines,
    );
    if (!_paused) {
      _lastVisible = visible;
    }
    _maybeFollowTail(visible.length);
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    l10n.logsTitle,
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                Semantics(
                  button: true,
                  label: _paused ? l10n.logsResume : l10n.logsPause,
                  child: IconButton(
                    tooltip: _paused ? l10n.logsResume : l10n.logsPause,
                    onPressed: () =>
                        setState(() => _paused = !_paused),
                    icon: Icon(
                      _paused ? Icons.play_arrow : Icons.pause,
                    ),
                  ),
                ),
                Semantics(
                  button: true,
                  label: l10n.logsExport,
                  child: IconButton(
                    tooltip: l10n.logsExport,
                    onPressed: visible.isEmpty
                        ? null
                        : () => _export(context, ref, visible),
                    icon: const Icon(Icons.share),
                  ),
                ),
                IconButton(
                  tooltip: l10n.logsClear,
                  onPressed: () =>
                      ref.read(logsControllerProvider.notifier).clear(),
                  icon: const Icon(Icons.delete_sweep_outlined),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _search,
                    focusNode: _searchFocus,
                    decoration: InputDecoration(
                      hintText: l10n.logsSearchHint,
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SegmentedButton<LogLevelFilter>(
                  segments: <ButtonSegment<LogLevelFilter>>[
                    ButtonSegment<LogLevelFilter>(
                      value: LogLevelFilter.all,
                      label: Text(l10n.logsLevelAll),
                    ),
                    ButtonSegment<LogLevelFilter>(
                      value: LogLevelFilter.errors,
                      label: Text(l10n.logsLevelErrors),
                    ),
                  ],
                  selected: <LogLevelFilter>{_filter},
                  onSelectionChanged: (Set<LogLevelFilter> selection) =>
                      setState(() => _filter = selection.first),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (visible.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    lines.isEmpty
                        ? l10n.logsEmpty
                        : l10n.logsSearchHint,
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
                      if (notification is ScrollUpdateNotification) {
                        final pos = _scroll.position;
                        // User scrolled up → stop tailing; back at bottom →
                        // resume. 48px tolerance avoids jitter at the edge.
                        _followTail =
                            pos.maxScrollExtent - pos.pixels < 48;
                      }
                      return false;
                    },
                    child: ListView.builder(
                      controller: _scroll,
                      itemCount: visible.length,
                      itemBuilder: (BuildContext context, int index) {
                        final EngineLogLine line = visible[index];
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

  List<EngineLogLine> _lastVisible = const <EngineLogLine>[];

  /// Export without new dependencies: the engine log is already plain text,
  /// so a share sheet is overkill — copy the visible lines to a buffer the
  /// user pastes into a bug report, and confirm via Snackbar.
  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    List<EngineLogLine> visible,
  ) async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final buffer = StringBuffer();
    for (final line in visible) {
      buffer.writeln(
        line.level.isEmpty ? line.message : '[${line.level}] ${line.message}',
      );
    }
    // ignore: avoid_print
    print('--- yourvpn log export (${visible.length} lines) ---');
    // ignore: avoid_print
    print(buffer.toString());
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.logsExported} (${visible.length})'),
        ),
      );
    }
  }
}
