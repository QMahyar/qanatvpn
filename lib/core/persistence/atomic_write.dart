import 'dart:io';

/// Crash-safe file write: content lands in a sibling tmp file first, then
/// atomically renames over the target. A kill mid-write leaves either the
/// old file or the new file — never half-written JSON that `read()` would
/// parse as corrupt and silently drop to empty.
Future<void> atomicWriteString(File file, String content) async {
  await file.parent.create(recursive: true);
  final tmp = File('${file.path}.$pid.tmp');
  await tmp.writeAsString(content, flush: true);
  await tmp.rename(file.path);
}

/// Crash-safe byte write, same tmp+rename guarantee as [atomicWriteString].
Future<void> atomicWriteBytes(File file, List<int> bytes) async {
  await file.parent.create(recursive: true);
  final tmp = File('${file.path}.$pid.tmp');
  await tmp.writeAsBytes(bytes, flush: true);
  await tmp.rename(file.path);
}
