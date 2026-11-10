/// The machine side of the MCP server of the command line (`oci mcp`,
/// docs/MCP.md): the root folder every path is confined to, the isolate
/// each tool call runs in (so that a cancellation or the time limit stops
/// it), and the stdio transport (one JSON-RPC message per line on stdin and
/// stdout, diagnostics on stderr). The protocol and the tools are pure Dart
/// in lib/core/mcp; this file holds what needs dart:io and dart:isolate.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:opencadirrigation/core/mcp/mcp_server.dart';
import 'package:opencadirrigation/core/mcp/oci_mcp_tools.dart';

/// The folder an MCP server may read and write, and nothing outside it.
///
/// A path is taken relative to the root, or absolute when it lies inside
/// it; `..` is refused outright (also where it would come back inside), `~`
/// is not expanded, and every symbolic link on the way is resolved before
/// the check, so a link that leads out of the root is refused as well. Only
/// regular files and folders are read (no devices or pipes). What this
/// cannot see: a hard link inside the root to a file elsewhere is that
/// file, and a link changed between the check and the use (the server is a
/// program of the user, not a sandbox).
final class McpRootDirectory {
  McpRootDirectory._(this.path, this._windows);

  /// Opens [folder] (it must exist and be a folder) as the root, its links
  /// resolved. [windows] chooses the path rules (default: the system's).
  factory McpRootDirectory.open(String folder, {bool? windows}) {
    final w = windows ?? Platform.isWindows;
    final dir = Directory(folder);
    if (!dir.existsSync()) throw FileSystemException('no such folder', folder);
    var real = dir.resolveSymbolicLinksSync();
    while (real.length > 1 && (real.endsWith('/') || (w && real.endsWith(r'\') && !real.endsWith(r':\')))) {
      real = real.substring(0, real.length - 1);
    }
    return McpRootDirectory._(real, w);
  }

  /// The root, absolute, links resolved, without a trailing separator.
  final String path;
  final bool _windows;
  static var _serial = 0;

  String get _sep => _windows ? r'\' : '/';

  /// [p] for comparisons: `/` separators, and lower case on Windows.
  String _key(String p) {
    final s = _windows ? p.replaceAll(r'\', '/').toLowerCase() : p;
    return s.length > 1 && s.endsWith('/') ? s.substring(0, s.length - 1) : s;
  }

  bool _within(String real) {
    final r = _key(path), p = _key(real);
    return p == r || p.startsWith(r.endsWith('/') ? r : '$r/');
  }

  String _relative(String real) {
    if (_key(real) == _key(path)) return '';
    return real.substring(path.length + (path.endsWith(_sep) ? 0 : 1)).replaceAll(r'\', '/');
  }

  bool _absolute(String p) => p.startsWith('/') || (_windows && RegExp(r'^[A-Za-z]:/').hasMatch(p));

  /// [p] (`/` separators) without `.` and empty segments, in the system's form.
  String _clean(String p) {
    final drive = _windows && RegExp(r'^[A-Za-z]:/').hasMatch(p) ? p.substring(0, 2) : '';
    final unc = _windows && p.startsWith('//');
    final parts = [
      for (final s in p.substring(drive.length).split('/'))
        if (s.isNotEmpty && s != '.') s,
    ];
    final body = parts.join(_sep);
    if (unc) return '$_sep$_sep$body';
    return drive.isNotEmpty ? '$drive$_sep$body' : '$_sep$body';
  }

  /// The folder of [p] ([p] itself for the top of the file system).
  String _parent(String p) {
    final i = p.lastIndexOf(_sep);
    if (i < 0) return p;
    if (i == 0) return _sep;
    final head = p.substring(0, i);
    if (_windows && RegExp(r'^[A-Za-z]:$').hasMatch(head)) return '$head$_sep';
    return head;
  }

  String _name(String p) => p.substring(p.lastIndexOf(_sep) + 1);

  /// The real path of [p]: its longest existing part with the links
  /// resolved, and the rest as given.
  String _real(String p, String input) {
    var head = p;
    final rest = <String>[];
    for (var guard = 0; guard < 4096; guard++) {
      if (FileSystemEntity.typeSync(head, followLinks: false) != FileSystemEntityType.notFound) {
        final String resolved;
        try {
          resolved = File(head).resolveSymbolicLinksSync();
        } on FileSystemException {
          throw McpToolError('$input: a symbolic link on the way leads nowhere');
        }
        return rest.isEmpty ? resolved : [resolved.endsWith(_sep) ? resolved.substring(0, resolved.length - 1) : resolved, ...rest].join(_sep);
      }
      final parent = _parent(head);
      if (parent == head) return p;
      rest.insert(0, _name(head));
      head = parent;
    }
    return p;
  }

  /// [input] as a file or folder under the root; throws [McpToolError] with
  /// the reason when it is not allowed.
  McpFile resolve(String input) {
    var s = input.trim();
    if (s.isEmpty) throw McpToolError('an empty path: give one relative to the root, e.g. "field.oci.json"');
    if (s.contains('\u0000')) throw McpToolError('the path holds a NUL character');
    if (s.startsWith('file:')) {
      try {
        s = Uri.parse(s).toFilePath(windows: _windows);
      } catch (_) {
        throw McpToolError('$input: not a file URI');
      }
    }
    if (s.startsWith('~')) throw McpToolError('$input: "~" is not expanded here; give the path relative to the root');
    final unified = s.replaceAll(r'\', '/');
    if (unified.split('/').contains('..')) throw McpToolError('$input: ".." is not allowed in a path (every path stays under the root folder)');
    final absolute = _absolute(unified);
    final real = _real(_clean(absolute ? unified : '${path.replaceAll(r'\', '/')}/$unified'), input);
    if (!_within(real)) {
      throw McpToolError(absolute ? '$input is outside the root folder of the server' : '$input leads outside the root folder (through a symbolic link)');
    }
    final type = FileSystemEntity.typeSync(real);
    if (type != FileSystemEntityType.notFound && type != FileSystemEntityType.file && type != FileSystemEntityType.directory) {
      throw McpToolError('$input is not a regular file');
    }
    final exists = type != FileSystemEntityType.notFound;
    final stat = exists && type == FileSystemEntityType.file ? File(real).statSync() : null;
    return McpFile(path: _relative(real), absolute: real, exists: exists, isDirectory: type == FileSystemEntityType.directory, size: stat?.size ?? 0, modified: stat?.modified);
  }

  /// The regular files under [folder] in path order, hidden ones (a name
  /// starting with a dot) and links that lead out of the root left out; links
  /// to folders are not followed (no cycles), nor folders deeper than 16.
  List<McpFile> list(McpFile folder, {required bool recursive, required int limit}) {
    final out = <McpFile>[];
    void walk(String dir, String rel, int depth) {
      final List<FileSystemEntity> entries;
      try {
        entries = Directory(dir).listSync(followLinks: false)..sort((a, b) => a.path.compareTo(b.path));
      } on FileSystemException {
        return;
      }
      for (final e in entries) {
        if (out.length >= limit) return;
        final name = e.path.substring(e.path.lastIndexOf(_sep) + 1);
        if (name.startsWith('.')) continue;
        final String real;
        try {
          real = e.resolveSymbolicLinksSync();
        } on FileSystemException {
          continue;
        }
        if (!_within(real)) continue;
        final path = rel.isEmpty ? name : '$rel/$name';
        final type = FileSystemEntity.typeSync(real);
        if (type == FileSystemEntityType.directory) {
          if (recursive && e is! Link && depth < 16) walk(real, path, depth + 1);
        } else if (type == FileSystemEntityType.file) {
          final st = File(real).statSync();
          out.add(McpFile(path: path, absolute: real, exists: true, size: st.size, modified: st.modified));
        }
      }
    }

    walk(folder.absolute, folder.path, 0);
    return out;
  }

  /// The bytes of [file], refused above [maxBytes].
  Uint8List read(McpFile file, {required int maxBytes}) {
    final f = resolve(file.path);
    if (!f.exists || f.isDirectory) throw McpToolError('${file.path}: no such file');
    if (f.size > maxBytes) throw McpToolError('${file.path}: ${f.size} bytes, above the $maxBytes a tool reads');
    return File(f.absolute).readAsBytesSync();
  }

  /// Makes the folders of [file] (inside the root) and gives it checked
  /// again, now that they exist.
  McpFile makeFolders(McpFile file) {
    final f = resolve(file.path);
    if (f.isDirectory) throw McpToolError('${file.path} is a folder');
    try {
      Directory(_parent(f.absolute)).createSync(recursive: true);
    } on FileSystemException catch (x) {
      throw McpToolError('${file.path}: its folder cannot be made (${x.osError?.message ?? x.message})');
    }
    return resolve(file.path);
  }

  /// Writes [file] whole: into a temporary file of the same folder, then
  /// renamed over it, so that a reader never sees half a file; the folders
  /// are made (inside the root) when missing.
  void write(McpFile file, List<int> bytes) {
    final f = makeFolders(file);
    // hidden (a listing leaves it out if a cancelled call leaves it behind),
    // and unique across the isolates of the calls
    final tmp = File('${_parent(f.absolute)}$_sep.${_name(f.absolute)}.$pid-${DateTime.now().microsecondsSinceEpoch}-${_serial++}.tmp');
    try {
      tmp.writeAsBytesSync(bytes, flush: true);
      tmp.renameSync(f.absolute);
    } on FileSystemException catch (x) {
      if (tmp.existsSync()) tmp.deleteSync();
      throw McpToolError('${file.path} cannot be written (${x.osError?.message ?? x.message})');
    }
  }
}

/// Runs every tool call in an isolate of its own: the server stays free to
/// answer (and to hear a cancellation) while a design runs, and a call that
/// is cancelled or outlives the time limit is killed. A [print] inside goes
/// to stderr, never to the message channel.
class IsolateExecutor implements McpExecutor {
  const IsolateExecutor({this.log});
  final void Function(String line)? log;

  @override
  Future<McpToolResult> run(Future<McpToolResult> Function() work, {required Future<void> stop}) async {
    final port = RawReceivePort();
    final done = Completer<McpToolResult>();
    port.handler = (Object? m) {
      if (done.isCompleted) return;
      if (m is McpToolResult) {
        done.complete(m);
      } else if (m is List && m.length == 2) {
        // an uncaught error of the isolate (onError)
        log?.call('mcp: a tool stopped: ${m[0]}\n${m[1]}');
        done.complete(McpToolResult.error('the tool stopped: ${m[0]}'));
      } else {
        // the isolate ended without a result (onExit)
        done.complete(McpToolResult.error('the tool stopped without a result (out of memory?)'));
      }
    };
    final Isolate isolate;
    try {
      isolate = await Isolate.spawn(_entry, (work, port.sendPort), onExit: port.sendPort, onError: port.sendPort, debugName: 'oci mcp tool');
    } on ArgumentError catch (e) {
      // something of the work cannot cross to another isolate: run it here
      port.close();
      log?.call('mcp: running a call in the main isolate ($e)');
      return const InlineExecutor().run(work, stop: stop);
    }
    unawaited(
      stop.then((_) {
        if (done.isCompleted) return;
        isolate.kill(priority: Isolate.immediate);
        done.completeError(const McpCallStopped());
      }),
    );
    try {
      return await done.future;
    } finally {
      port.close();
    }
  }

  static Future<void> _entry((Future<McpToolResult> Function(), SendPort) message) async {
    final (work, port) = message;
    final result = await runZoned(() async {
      try {
        return await work();
      } catch (e, st) {
        stderr.writeln('oci mcp: $e\n$st');
        return McpToolResult.error('failed: $e');
      }
    }, zoneSpecification: ZoneSpecification(print: (self, parent, zone, line) => stderr.writeln(line)));
    Isolate.exit(port, result);
  }
}

/// Splits [input] into lines (without the newline and a carriage return
/// before it), decoded as UTF-8; a line longer than [maxBytes] gives
/// [tooLong] and is dropped up to its end.
Stream<String> mcpLines(Stream<List<int>> input, {int maxBytes = mcpMaxMessageBytes, void Function()? tooLong}) async* {
  final buf = BytesBuilder(copy: false);
  var skipping = false;
  String line(Uint8List bytes) {
    var s = utf8.decode(bytes, allowMalformed: true);
    if (s.endsWith('\r')) s = s.substring(0, s.length - 1);
    return s;
  }

  await for (final chunk in input) {
    var start = 0;
    for (var i = 0; i < chunk.length; i++) {
      if (chunk[i] != 10) continue;
      if (!skipping) {
        buf.add(chunk.sublist(start, i));
        if (buf.length > maxBytes) {
          buf.clear();
          tooLong?.call();
        } else {
          yield line(buf.takeBytes());
        }
      }
      skipping = false;
      start = i + 1;
    }
    if (skipping) continue;
    buf.add(chunk.sublist(start));
    if (buf.length > maxBytes) {
      buf.clear();
      skipping = true;
      tooLong?.call();
    }
  }
  if (!skipping && buf.length > 0) yield line(buf.takeBytes());
}

/// Serves the server [build] makes over [input] (default stdin) and
/// [output] (default stdout) until the input ends: one message per line out,
/// diagnostics to [errors] (default stderr). A [print] anywhere goes to
/// [errors] too, so that nothing but messages reaches the output.
Future<void> serveMcpStdio(McpServer Function(void Function(String message) send, void Function(String line) log) build, {Stream<List<int>>? input, StringSink? output, StringSink? errors}) async {
  final out = output ?? stdout;
  final err = errors ?? stderr;
  final server = build((m) => out.write('$m\n'), err.writeln);
  await runZoned(() async {
    await for (final line in mcpLines(input ?? stdin, tooLong: server.rejectTooLong)) {
      server.receive(line);
    }
  }, zoneSpecification: ZoneSpecification(print: (self, parent, zone, line) => err.writeln(line)));
  await server.close();
  if (out is IOSink) await out.flush();
}
