/// The progress of a file import: while the readers work in slices (see
/// [ProjectController.importFileAsync]) a dialog shows the file, how far the
/// reading got and a button to cancel it. Quick imports finish before it
/// appears.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/io/work_slicer.dart';
import '../../state/controller.dart';
import 'terrain_dialogs.dart' show dialogWidth;

/// Imports the file [name] with its progress shown after a moment and a
/// cancel button. Returns the summary of the import, or null when the user
/// cancelled it (nothing changed then); errors are thrown as by
/// [ProjectController.importFile].
Future<String?> showImportProgressDialog(BuildContext context, ProjectController c, String name, Uint8List bytes) async {
  final progress = ValueNotifier<double?>(null);
  final slicer = WorkSlicer(onProgress: (f) => progress.value = f);
  var done = false;
  BuildContext? dialogContext;
  void close() {
    final d = dialogContext;
    if (d != null && d.mounted) Navigator.of(d).pop();
    dialogContext = null;
  }

  // the dialog only for imports that take a while
  final timer = Timer(const Duration(milliseconds: 300), () {
    if (done || !context.mounted) return;
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          dialogContext = ctx;
          // the import may have ended before the dialog was built
          if (done) WidgetsBinding.instance.addPostFrameCallback((_) => close());
          return PopScope(
            canPop: false,
            child: AlertDialog(
              title: Text(c.t('fmt.import.reading', {'f': name}), maxLines: 2, overflow: TextOverflow.ellipsis),
              content: SizedBox(
                width: dialogWidth(ctx, 360),
                child: ValueListenableBuilder<double?>(
                  valueListenable: progress,
                  builder: (_, v, _) => LinearProgressIndicator(value: v),
                ),
              ),
              actions: [TextButton(onPressed: slicer.cancel, child: Text(c.t('cancel')))],
            ),
          );
        },
      ),
    );
  });
  try {
    return await c.importFileAsync(name, bytes, slicer);
  } on ImportCancelled {
    return null;
  } finally {
    done = true;
    timer.cancel();
    close();
  }
}
