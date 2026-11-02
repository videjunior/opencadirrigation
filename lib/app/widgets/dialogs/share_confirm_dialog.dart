/// The question asked before a large project from a shared link opens: the
/// link was opened in the browser (by the user, or by a page that sent
/// them there), and a project of several megabytes takes a while and much
/// memory, so it opens only when the user says so.
library;

import 'package:flutter/material.dart';

import '../../state/controller.dart';
import '../../theme.dart';
import '../fields.dart';
import 'terrain_dialogs.dart' show dialogWidth;

/// Projects of a link from this size on (characters of their JSON) are
/// opened only when the user confirms.
const shareLinkConfirmChars = 1 << 20;

/// How many items the project JSON [json] holds (its entities, roughly).
int sharedItemCount(String json) => '"type":'.allMatches(json).length;

/// Whether the project of a link [json] may open: at once when it is
/// small, else when the user confirms.
Future<bool> confirmSharedProject(BuildContext context, ProjectController c, String json) async {
  if (json.length < shareLinkConfirmChars) return true;
  return showLargeLinkDialog(context, c, json);
}

Future<bool> showLargeLinkDialog(BuildContext context, ProjectController c, String json) async {
  final t = c.t;
  final mb = json.length / (1 << 20);
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text(t('share.large.title'), style: const TextStyle(fontSize: 15)),
      content: SizedBox(
        width: dialogWidth(ctx, 420),
        child: ScrollBody(
          child: Text(
            t('share.large.body', {'mb': fmtUi(mb, mb < 10 ? 1 : 0), 'n': fmtUi(sharedItemCount(json).toDouble(), 0)}),
            key: const Key('share_large_body'),
            style: TextStyle(fontSize: 12.5, color: Cad.fg),
          ),
        ),
      ),
      actions: [
        TextButton(key: const Key('share_large_cancel'), onPressed: () => Navigator.pop(ctx, false), child: Text(t('cancel'))),
        FilledButton(key: const Key('share_large_open'), onPressed: () => Navigator.pop(ctx, true), child: Text(t('share.large.open'))),
      ],
    ),
  );
  return ok ?? false;
}
