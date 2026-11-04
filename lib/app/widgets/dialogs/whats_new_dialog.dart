/// Help → What's new, and once after an update of the web app (SIT-07: the
/// banner of a new version reloads into it; this says what came with it).
/// The highlights of each version are in the string table, the full list in
/// CHANGELOG.md (English) and CHANGELOG.pt-BR.md.
library;

import 'package:flutter/material.dart';

import '../../io/links.dart';
import '../../io/prefs.dart';
import '../../state/controller.dart';
import '../../theme.dart';
import '../../tutorial/tutorial.dart' show TutorialController;
import '../../version.dart';
import '../fields.dart' show ScrollBody;
import 'terrain_dialogs.dart' show dialogWidth;

/// The highlights of each version, newest first: `new.v<digits>.<id>` in
/// the string table.
const whatsNewNotes = <String, List<String>>{
  '1.6.0': ['palette', 'help', 'interface', 'tutorial', 'sheets', 'numbers', 'touch', 'reports', 'editing', 'safety', 'engine'],
};

/// The version whose highlights are shown: this one, or the newest with
/// notes (a build before its release).
String get whatsNewVersion => whatsNewNotes.containsKey(appVersion) ? appVersion : whatsNewNotes.keys.first;

/// The i18n keys of the highlights of [version].
List<String> whatsNewKeys(String version) => [for (final id in whatsNewNotes[version] ?? const <String>[]) 'new.v${version.replaceAll('.', '')}.$id'];

/// The version whose news the user was last shown.
const whatsNewSeenPref = 'whatsnew_seen';

/// Whether version [a] comes before version [b] (`1.5.2` before `1.6.0`,
/// `1.9.3` before `1.10.0`; a build number after `+` does not count).
bool versionBefore(String a, String b) {
  List<int> parts(String v) => [for (final p in v.split('+').first.split('.')) int.tryParse(p) ?? 0];
  final x = parts(a);
  final y = parts(b);
  for (var i = 0; i < x.length || i < y.length; i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d < 0;
  }
  return false;
}

/// Whether to show the news at start-up: once per version, to someone who
/// used an earlier one (a version seen before, projects kept in this
/// browser or the tutorial done); a first visit only notes the version. A
/// version without news of its own (a patch release) shows those of the
/// newest version that has them, to whoever had not seen that one yet.
bool shouldShowWhatsNew(ProjectController c) {
  final seen = getPref(whatsNewSeenPref);
  if (seen == appVersion) return false;
  final returning = seen != null || c.store.list().isNotEmpty || TutorialController.isDone;
  setPref(whatsNewSeenPref, appVersion);
  return returning && whatsNewNotes.containsKey(whatsNewVersion) && (seen == null || versionBefore(seen, whatsNewVersion));
}

/// The full history of the versions, in Portuguese for a Portuguese
/// interface and in English otherwise.
String changelogUrl(String lang) => '$appRepositoryUrl/blob/main/${lang == 'pt' ? 'CHANGELOG.pt-BR.md' : 'CHANGELOG.md'}';

Future<void> showWhatsNewDialog(BuildContext context, ProjectController c, {bool afterUpdate = false}) {
  final t = c.t;
  final version = whatsNewVersion;
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: const Key('whats_new'),
      title: Text(t('new.title', {'v': version}), style: const TextStyle(fontSize: 15)),
      content: SizedBox(
        width: dialogWidth(ctx, 560),
        child: ScrollBody(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (afterUpdate) ...[
                Text(
                  t('new.updated', {'v': appVersion}),
                  key: const Key('whats_new_updated'),
                  style: TextStyle(fontSize: 12.5, color: Cad.accentText),
                ),
                const SizedBox(height: 10),
              ],
              for (final k in whatsNewKeys(version))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(Icons.check_circle_outline, size: 16, color: Cad.ok),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(t(k), style: const TextStyle(fontSize: 12.5, height: 1.4))),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(key: const Key('whats_new_all'), onPressed: () => openExternalLink(changelogUrl(c.lang)), icon: const Icon(Icons.open_in_new, size: 16), label: Text(t('new.all'))),
        FilledButton(key: const Key('whats_new_close'), onPressed: () => Navigator.pop(ctx), child: Text(t('close'))),
      ],
    ),
  );
}
