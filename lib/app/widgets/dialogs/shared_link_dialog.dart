/// A project shared by link (#p=…) that is large: it opens only once the
/// user agrees (FMT-09), since reading it can hold the page for a while;
/// the link's text is already inflated (with the ceiling of
/// lib/core/io/share_link.dart) and the address bar cleared.
library;

import 'package:flutter/material.dart';

import '../../state/controller.dart';
import '../fields.dart' show fmtUi;

/// Above this many characters of JSON a linked project asks first (a
/// project that fits a link is usually far smaller).
const largeSharedProjectChars = 3000000;

bool isLargeSharedProject(String json) => json.length > largeSharedProjectChars;

/// About how many items the project holds (each item has a "type"), counted
/// without reading the JSON.
int sharedProjectItemCount(String json) => RegExp(r'"type"\s*:').allMatches(json).length;

/// Asks whether to open the large project of a link; true to open it.
Future<bool> confirmLargeSharedProject(BuildContext context, ProjectController c, String json) async {
  final t = c.t;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: const Key('link_big'),
      title: Text(t('link.bigTitle'), style: const TextStyle(fontSize: 15)),
      content: Text(t('link.big', {'mb': fmtUi(json.length / 1e6, 1), 'n': '${sharedProjectItemCount(json)}'})),
      actions: [
        TextButton(key: const Key('link_big_cancel'), onPressed: () => Navigator.pop(ctx, false), child: Text(t('cancel'))),
        FilledButton(key: const Key('link_big_open'), onPressed: () => Navigator.pop(ctx, true), child: Text(t('link.open'))),
      ],
    ),
  );
  return ok == true;
}
