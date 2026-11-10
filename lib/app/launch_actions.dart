/// What the installed app does with what the system hands it (lib/app/io/launch_files.dart, 1.6.0): a project file
/// opens in a tab of its own, a PDF plan goes through its import dialog, a drawing, a survey or a picture is imported
/// into a new project tab (the blank tab of a fresh start is used), an OpenCADIrrigation link in a shared text opens
/// its project, and the launch of the window already open does what its address asks (an example, the sized sample,
/// the tutorial, the AI assistant, a shared project), as the same address does when it opens the app.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/io/share_link.dart';
import '../core/model/project.dart';
import 'actions.dart';
import 'examples.dart';
import 'io/launch_files.dart';
import 'state/controller.dart';
import 'state/workspace.dart';
import 'widgets/dialogs/ai_assistant_dialog.dart';
import 'widgets/dialogs/import_progress_dialog.dart';
import 'widgets/dialogs/pdf_import_dialog.dart';
import 'widgets/dialogs/share_confirm_dialog.dart' show confirmSharedProject;

/// How a launched file opens.
enum LaunchKind { project, pdf, import }

/// How the file [name] with [bytes] opens: a project by its extension, or a JSON file whose "format" names the
/// project format; a PDF plan; anything else is imported (and refused there, with the reason, when unknown).
LaunchKind launchKindOf(String name, Uint8List bytes) {
  final n = name.toLowerCase();
  if (n.endsWith('.oci.json') || n.endsWith('.oci') || n.endsWith('.icad')) return LaunchKind.project;
  if (n.endsWith('.pdf')) return LaunchKind.pdf;
  if (n.endsWith('.json')) {
    try {
      final j = jsonDecode(utf8.decode(bytes, allowMalformed: true));
      if (j is Map && (j['format'] == Project.formatName || j['format'] == Project.legacyFormatName)) return LaunchKind.project;
    } on FormatException {
      // not JSON: imported, and refused there with the reason
    }
  }
  return LaunchKind.import;
}

/// Opens or imports what [r] brings into [ws]. [startTutorial] starts the tutorial at a step (the shell's own).
Future<void> handleLaunch(BuildContext context, Workspace ws, LaunchRequest r, {void Function(int step)? startTutorial}) async {
  if (r.failed) {
    ws.current.notify(ws.current.t('launch.shareFailed'));
    return;
  }
  var opened = 0;
  for (final f in r.files) {
    if (!context.mounted) return;
    if (await openLaunchedFile(context, ws, f)) opened++;
  }
  // a shared text, or the address of a launch into the window already open (a link the installed app was asked to
  // open): an OpenCADIrrigation link carries its project in the address
  final linkPattern = RegExp(r'#p=[^\s]+');
  final link = linkPattern.firstMatch(r.text)?.group(0) ?? linkPattern.firstMatch(r.url)?.group(0);
  if (link != null) {
    if (!context.mounted) return;
    if (await openShareLinkAction(context, ws, link) != null) opened++;
  }
  if (r.shared && opened == 0 && r.files.isEmpty && link == null) ws.current.notify(ws.current.t('launch.nothing'));
  if (r.url.isEmpty) return;
  // a launch into the window already open: what its address asks
  final q = Uri.tryParse(r.url)?.queryParameters ?? const <String, String>{};
  final example = exampleIdFromName(q['example']);
  final design = q['design'] == '1';
  if (example != null || design) {
    if (!context.mounted) return;
    await openExampleAction(context, ws.current, example ?? ExampleId.orchard, ws: ws);
    if (design) ws.current.runDesign();
  }
  final step = int.tryParse(q['tutorial'] ?? '');
  if (step != null && step > 0) startTutorial?.call(step - 1);
  if (q['ai'] == '1') {
    if (!context.mounted) return;
    showAiAssistantDialog(context, ws.current);
  }
}

/// Opens the project a share link carries ([link]: the link, or its fragment `#p=…`) in a tab of its own (the blank
/// tab of a fresh start is used), as a copy, since the link carries the uid of whoever sent it; a large one only when
/// the user says so (FMT-09). A link that cannot be read is told. The tab it opened in, or null (declined, damaged).
/// The start-up opens the link that opened the page with it, the shell those pasted later into the address bar.
Future<ProjectController?> openShareLinkAction(BuildContext context, Workspace ws, String link) async {
  final json = projectJsonFromLink(link);
  if (json == null) {
    ws.current.notify(ws.current.t('share.damaged'));
    return null;
  }
  if (!await confirmSharedProject(context, ws.current, json) || !context.mounted) return null;
  final opened = openJsonInTab(ws, json, asCopy: true);
  if (opened == null) ws.current.notify(ws.current.t('share.damaged'));
  return opened;
}

/// Opens one launched file: a project in a tab of its own, a PDF plan through its import dialog, anything else
/// imported into a new project tab (the blank tab of a fresh start is used). False when nothing opened.
Future<bool> openLaunchedFile(BuildContext context, Workspace ws, LaunchFile f) async {
  final kind = launchKindOf(f.name, f.bytes);
  if (kind == LaunchKind.project) {
    final String text;
    try {
      text = utf8.decode(f.bytes);
    } on FormatException catch (e) {
      ws.current.notify(openErrorMessage(ws.current, e));
      return false;
    }
    return openJsonInTab(ws, text) != null;
  }
  final cur = ws.current;
  final target = cur.project.entities.isEmpty && !cur.dirty ? cur : ws.addTab();
  if (kind == LaunchKind.pdf) {
    await importPdfAction(context, target, f.name, f.bytes);
    return true;
  }
  try {
    final summary = await showImportProgressDialog(context, target, f.name, f.bytes);
    target.notify(summary == null ? target.t('fmt.import.cancelled') : '${target.t('msg.imported')}: $summary');
    return summary != null;
  } catch (e) {
    target.notify(target.t('msg.error', {'e': target.describeError(e)}));
    return false;
  }
}
