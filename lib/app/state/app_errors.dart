/// What the app does with an error nothing else caught (a pointer handler,
/// a tool, a build of a panel, a future no one awaited): the error goes to
/// the console, the work of every tab is copied in the browser at once, and
/// the user is told in a short message (at most every few seconds) instead
/// of the action failing in silence. A part of the window that fails to
/// build shows a small panel with a button to save the project, in place
/// of a grey area.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../i18n.dart';
import '../io/file_io.dart';
import '../theme.dart';
import 'controller.dart';
import 'workspace.dart';

abstract final class AppErrors {
  static Workspace? _ws;
  static void Function(String message)? _show;
  static DateTime _lastShown = DateTime.fromMillisecondsSinceEpoch(0);
  static DateTime _lastCopy = DateTime.fromMillisecondsSinceEpoch(0);

  /// Errors seen since start-up (tests read it).
  static int count = 0;

  /// Installs the handlers (once, from main()).
  static void install() {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      (previous ?? FlutterError.presentError)(details);
      report(details.exception, details.stack);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('$error\n$stack');
      report(error, stack);
      return true;
    };
    // the red error box stays for the developer; the published app shows a panel
    if (!kDebugMode) ErrorWidget.builder = errorWidget;
  }

  /// The tabs whose work is copied on an error, and how the user is told.
  static void attach(Workspace ws, void Function(String message) show) {
    _ws = ws;
    _show = show;
  }

  static void detach(Workspace ws) {
    if (!identical(_ws, ws)) return;
    _ws = null;
    _show = null;
  }

  /// An error nothing else caught.
  static void report(Object error, StackTrace? stack) {
    count++;
    final ws = _ws;
    if (ws == null) return;
    final now = DateTime.now();
    // the work first: what follows the error may be a crash
    if (now.difference(_lastCopy) > const Duration(seconds: 10)) {
      _lastCopy = now;
      for (final t in ws.tabs) {
        unawaited(t.autosaveIfChanged().catchError((Object _) {}));
      }
    }
    if (now.difference(_lastShown) < const Duration(seconds: 5)) return;
    _lastShown = now;
    final c = ws.tabs.isEmpty ? null : ws.current;
    _show?.call((c?.t ?? I18n(uiLanguage.value)).call('err.unexpected'));
  }

  /// Saves the project of the current tab to a file (the button of the
  /// error panel).
  static Future<void> saveCurrent() async {
    final ws = _ws;
    if (ws == null || ws.tabs.isEmpty) return;
    final c = ws.current;
    final name = c.project.meta.name.trim().isEmpty ? 'project' : c.project.meta.name.trim().replaceAll(RegExp(r'[^\w\-]+', unicode: true), '_');
    final (file, compact) = c.fileJson();
    final r = await saveProjectFile('$name.oci.json', file);
    if (r == FileSaveResult.saved || r == FileSaveResult.downloaded) c.markSaved(compact: compact);
  }

  /// The panel shown in place of a part of the window that failed to build.
  static Widget errorWidget(FlutterErrorDetails details) {
    final t = I18n(uiLanguage.value);
    return Material(
      color: Cad.panel,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Cad.attention, size: 20),
              const SizedBox(height: 6),
              Text(
                t('err.part'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Cad.fg70),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(onPressed: saveCurrent, icon: const Icon(Icons.save_outlined, size: 16), label: Text(t('file.save'))),
            ],
          ),
        ),
      ),
    );
  }
}
