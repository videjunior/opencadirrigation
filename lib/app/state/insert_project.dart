/// File → Insert project… (1.6.0 MOD): another project file inserted into
/// the one open ([insertProject]), in one undo step.
library;

import 'package:flutter/widgets.dart';

import '../../core/model/project.dart';
import '../../core/model/project_merge.dart';
import '../io/file_io.dart';
import 'controller.dart';

/// Inserting another project, on the controller.
extension InsertProjectCommand on ProjectController {
  /// Inserts the project file [json] (named [name]) into this project, in
  /// one undo step: the inserted items become the selection and the view
  /// shows them. Null when the file is no project (the user is told) or the
  /// edit was refused (a design runs).
  InsertProjectResult? insertProjectJson(String json, {String name = ''}) {
    track('insertProject');
    final ProjectFile f;
    try {
      f = readProjectFile(json);
    } catch (_) {
      // not JSON, another kind of JSON, a damaged project
      notify(t('insert.notProject'));
      return null;
    }
    final r = mutate(() => insertProject(project, f.project), label: 'hist.insertProject');
    if (r == null) return null;
    select(r.ids);
    if (r.ids.isNotEmpty) zoomAll();
    final notes = [
      if (r.placement == InsertPlacement.georeferenced) t('insert.placedGeo'),
      if (r.placement == InsertPlacement.georeferenceTaken) t('insert.tookGeo'),
      if (r.placement == InsertPlacement.asDrawn && f.project.meta.georef != null && project.meta.georef == null) t('insert.noGeo'),
      if (r.paste.renamedItems.isNotEmpty) t('insert.renamed', {'n': '${r.paste.renamedItems.length}'}),
      if (r.paste.rate != null) t('insert.converted', {'c': f.project.params.currencyCode, 't': project.params.currencyCode}),
    ];
    final what = t('insert.done', {'n': '${r.ids.length}', 'f': name.isEmpty ? f.project.meta.name : name, 'l': '${r.layers}', 's': '${r.flows}', 'b': '${r.blocks}'});
    notify(notes.isEmpty ? what : '$what — ${notes.join('; ')}');
    return r;
  }
}

/// The menu action: picks a project file and inserts it into [c].
Future<void> insertProjectAction(BuildContext context, ProjectController c) async {
  final f = await openTextFile(accept: '.json,.oci,.icad');
  if (f == null) return;
  c.insertProjectJson(f.$2, name: f.$1);
}
