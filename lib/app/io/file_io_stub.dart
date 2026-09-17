/// Desktop (macOS / Windows / Linux) file access without platform plugins:
/// an in-app file browser dialog built on dart:io, so the app is usable
/// where it is compiled for desktop.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'app_keys.dart';
import 'prefs.dart';

Future<void> saveTextFile(String filename, String content, {String mime = 'application/json'}) async {
  final path = await _pickPath(filename, save: true);
  if (path == null) return;
  await File(path).writeAsString(content);
}

Future<void> saveBinaryFile(String filename, Uint8List bytes, {String mime = 'application/octet-stream'}) async {
  final path = await _pickPath(filename, save: true);
  if (path == null) return;
  await File(path).writeAsBytes(bytes);
}

Future<(String, String)?> openTextFile({String accept = ''}) async {
  final path = await _pickPath('', save: false, accept: accept);
  if (path == null) return null;
  final f = File(path);
  return (f.uri.pathSegments.last, await f.readAsString());
}

Future<(String, Uint8List)?> openBinaryFile({String accept = ''}) async {
  final path = await _pickPath('', save: false, accept: accept);
  if (path == null) return null;
  final f = File(path);
  return (f.uri.pathSegments.last, await f.readAsBytes());
}

/// Shows the in-app browser; returns the chosen path or null. Falls back to
/// the current directory when no navigator is mounted (tests, CLI).
Future<String?> _pickPath(String suggested, {required bool save, String accept = ''}) async {
  final nav = appNavigatorKey.currentState;
  if (nav == null) return save ? suggested : null;
  final start = getPref('desktop.dir') ?? Directory.current.path;
  final exts = accept.split(',').map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toList();
  final r = await nav.push<String>(MaterialPageRoute(builder: (_) => _FileDialog(startDir: start, suggested: suggested, save: save, extensions: exts), fullscreenDialog: true));
  if (r != null) setPref('desktop.dir', File(r).parent.path);
  return r;
}

class _FileDialog extends StatefulWidget {
  const _FileDialog({required this.startDir, required this.suggested, required this.save, required this.extensions});
  final String startDir;
  final String suggested;
  final bool save;
  final List<String> extensions;

  @override
  State<_FileDialog> createState() => _FileDialogState();
}

class _FileDialogState extends State<_FileDialog> {
  late Directory _dir = Directory(widget.startDir);
  late final TextEditingController _name = TextEditingController(text: widget.suggested);
  late final TextEditingController _path = TextEditingController(text: widget.startDir);
  List<FileSystemEntity> _items = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    try {
      final list = _dir.listSync()..sort((a, b) {
          final da = a is Directory, db = b is Directory;
          if (da != db) return da ? -1 : 1;
          return a.path.toLowerCase().compareTo(b.path.toLowerCase());
        });
      _items = list.where((e) {
        if (e is Directory) return true;
        if (widget.extensions.isEmpty) return true;
        final l = e.path.toLowerCase();
        return widget.extensions.any(l.endsWith);
      }).toList();
      _error = null;
      _path.text = _dir.path;
    } catch (e) {
      _error = '$e';
      _items = [];
    }
    setState(() {});
  }

  void _go(String path) {
    final d = Directory(path);
    if (d.existsSync()) {
      _dir = d;
      _refresh();
    }
  }

  void _done(String path) => Navigator.of(context).pop(path);

  @override
  Widget build(BuildContext context) {
    final sep = Platform.pathSeparator;
    return Scaffold(
      appBar: AppBar(title: Text(widget.save ? 'Save as' : 'Open'), actions: [
        IconButton(icon: const Icon(Icons.arrow_upward), tooltip: '..', onPressed: () => _go(_dir.parent.path)),
        IconButton(icon: const Icon(Icons.home_outlined), onPressed: () => _go(Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? Directory.current.path)),
      ]),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(8), child: TextField(controller: _path, decoration: const InputDecoration(labelText: 'Folder', isDense: true), onSubmitted: _go)),
        if (_error != null) Padding(padding: const EdgeInsets.all(8), child: Text(_error!, style: const TextStyle(color: Colors.orange))),
        Expanded(
          child: ListView.builder(
            itemCount: _items.length,
            itemBuilder: (ctx, i) {
              final e = _items[i];
              final name = e.path.split(sep).last;
              final isDir = e is Directory;
              return ListTile(
                dense: true,
                leading: Icon(isDir ? Icons.folder : Icons.insert_drive_file_outlined, size: 18),
                title: Text(name),
                onTap: () {
                  if (isDir) {
                    _go(e.path);
                  } else if (widget.save) {
                    setState(() => _name.text = name);
                  } else {
                    _done(e.path);
                  }
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            Expanded(child: TextField(key: const Key('desktop_filename'), controller: _name, decoration: const InputDecoration(labelText: 'File name', isDense: true), onSubmitted: (_) => _confirm())),
            const SizedBox(width: 8),
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            FilledButton(onPressed: _confirm, child: Text(widget.save ? 'Save' : 'Open')),
          ]),
        ),
      ]),
    );
  }

  void _confirm() {
    final n = _name.text.trim();
    if (n.isEmpty) return;
    final full = n.contains(Platform.pathSeparator) ? n : '${_dir.path}${Platform.pathSeparator}$n';
    if (!widget.save && !File(full).existsSync()) return;
    _done(full);
  }
}
