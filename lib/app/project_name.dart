/// The name of a project as the interface shows it. A new project has no
/// name of its own (an empty `meta.name`): the tab, the title bar, the
/// lists of kept projects and the file names say "New project" in the
/// interface language of the moment, so a page reloaded in another language
/// never shows the name of the language the tab was created in.
library;

import 'i18n.dart';
import 'io/project_store.dart' show StoredProject;

/// The names a new project was given by versions before 1.6.0, which wrote
/// "New project" in the interface language into the file when the tab was
/// created: they stand for "no name" as well.
const _legacyDefaults = {'Novo projeto', 'New project', 'Nuevo proyecto'};

/// Whether [name] is no name of its own: empty, or the default name an
/// earlier version wrote.
bool isUnnamedProject(String name) {
  final n = name.trim();
  return n.isEmpty || _legacyDefaults.contains(n);
}

/// [name], or "New project" in the language of [t] when the project has
/// none.
String projectTitle(I18n t, String name) => isUnnamedProject(name) ? t('name.newProject') : name.trim();

/// [projectTitle] as the stem of a file name: what is not a letter, a
/// digit, `_` or `-` becomes `_`.
String projectFileStem(I18n t, String name) => projectTitle(t, name).replaceAll(RegExp(r'[^\w\-]+', unicode: true), '_');

/// How a project kept in this browser is listed (File → Recent projects):
/// its name, or "New project" with the time it was kept when it has none, so
/// two unnamed ones can be told apart.
String storedProjectLabel(I18n t, StoredProject p) {
  if (!isUnnamedProject(p.name)) return p.name.trim();
  final d = p.savedAt.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t('name.newProject')} · ${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}
