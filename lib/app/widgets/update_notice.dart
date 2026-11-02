/// "A new version is ready" (SIT-07): the installed app and a tab left open
/// for days keep running the build they started with while the service
/// worker installs a newer one; this banner says so and reloads into it on
/// request, after a word about the unsaved changes, which the autosave
/// keeps for the recovery offered at the next start.
library;

import 'package:flutter/material.dart';

import '../io/app_update.dart';
import '../io/unload.dart';
import '../state/workspace.dart';
import '../theme.dart';

/// Shows the banner over the shell of [context]. [unsaved] tells whether a
/// reload loses something (an unsaved project, a conversation of the AI
/// assistant that is not kept); [reload] defaults to [applyAppUpdate].
void showUpdateBanner(BuildContext context, Workspace ws, {required bool Function() unsaved, VoidCallback? reload}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final t = ws.current.t;
  messenger.showMaterialBanner(
    MaterialBanner(
      key: const Key('update_banner'),
      leading: Builder(builder: (_) => Icon(Icons.system_update_alt, color: Cad.accentIcon)),
      content: Text(t('update.ready')),
      actions: [
        TextButton(key: const Key('update_later'), onPressed: messenger.hideCurrentMaterialBanner, child: Text(t('update.later'))),
        FilledButton(key: const Key('update_reload'), onPressed: () => _reload(context, ws, unsaved, reload ?? applyAppUpdate), child: Text(t('update.reload'))),
      ],
    ),
  );
}

Future<void> _reload(BuildContext context, Workspace ws, bool Function() unsaved, VoidCallback reload) async {
  if (unsaved()) {
    final t = ws.current.t;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('update.unsavedTitle')),
        content: Text(t('update.unsaved')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('cancel'))),
          FilledButton(key: const Key('update_reload_confirm'), onPressed: () => Navigator.pop(ctx, true), child: Text(t('update.reload'))),
        ],
      ),
    );
    if (ok != true) return;
    // the unsaved projects go to the autosave, offered for recovery at the next start
    for (final tab in ws.tabs) {
      if (tab.dirty) tab.autosaveNow();
    }
  }
  // the user agreed: no second "leave the page?" question from the browser
  setUnloadGuard(() => false);
  reload();
}
