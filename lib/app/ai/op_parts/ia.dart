/// Operations (find_operations / run_operation) added in 1.6.0 for the AI assistant itself (and the functions of 1.6.0 wave 1 still without an operation):
/// [OpTool]s built like those of lib/app/ai/ops_cad_*.dart and ops_eng_*.dart,
/// joined to [AgentToolbox.operations].
///
/// Wave 1 left these functions without a way for the assistant: the
/// geometry edits of the drawing (stretch, fillet, chamfer, break at two
/// points, join, explode, outline to area), Save as copy and the browser
/// storage, the terms of the base maps, and the ETo worked out from the
/// normals of a weather station. Each calls what the program's own tool,
/// menu item or dialog calls.
library;

import 'dart:math' as math;

import '../../../core/ai/agent_loop.dart';
import '../../../core/design/climate.dart';
import '../../../core/model/entities.dart';
import '../../../core/model/geometry.dart';
import '../../../core/model/site_climate.dart';
import '../../actions.dart' show projectExtension;
import '../../canvas/basemap.dart' show BaseMapLayer;
import '../../io/storage_info.dart';
import '../../state/controller.dart';
import '../../tools/edit_commands.dart';
import '../../widgets/dialogs/basemap_dialogs.dart' show osmTilePolicyUrl;
import '../../widgets/dialogs/storage_dialog.dart' show zipStoredProjects;
import '../agent_tools.dart';
import '../ops_cad_common.dart';
import '../ops_eng_common.dart';

List<AgentTool> opsIa(AgentToolbox b) => [...geometryEditOperations(b), ...storageOperations(b), ...stationClimateOperations(b)];

// ---------------------------------------------------------------- geometry edits (CAD-26)

/// The geometry edits of the drawing as operations (group "edit"): each
/// calls the controller command the tool or the menu item calls, one undo
/// step with the command's own label in the history.
List<AgentTool> geometryEditOperations(AgentToolbox b) {
  final c = b.c;
  Map<String, String> count(Map<String, dynamic> i) => {'n': '${(i['ids'] as List?)?.length ?? c.selection.length}'};

  // runs [command] over [items] as the selection (what the menu item works
  // on); the user's selection comes back when nothing changed
  int onItems(List<Entity> items, int Function() command) {
    final keep = {...c.selection};
    c.select(items.map((e) => e.id));
    final n = command();
    if (n == 0) c.select(keep.where((id) => b.p.byId(id) != null));
    return n;
  }

  final itemsSchema = obj({'ids': idsWith('Items (ids or names).', maxItems: 5000), 'selected': bool_('The current selection instead of "ids" (e.g. the items of an import, which come in selected).')});
  return [
    cadOp(
      b,
      group: 'edit',
      name: 'stretch_entities',
      effect: ToolEffect.write,
      description:
          'Stretches the drawing like the Stretch tool (STRETCH): what lies inside the crossing window "bbox" moves by dx, dy — the vertices of lines, polylines, pipes, laterals, tapes, contours, wires and area outlines inside it move while those outside stay (the items stretch), an item wholly inside moves whole, a point item, circle, arc or pivot moves with its centre or position, the points of a dimension move — e.g. to lengthen a field and its laterals, or to move the end of a run of pipe. "ids" limits it to those items, as a selection does for the tool; items on locked or hidden layers stay. One undo step; returns the items changed.',
      schema: obj(
        {
          'bbox': {...bbox, 'description': '[minX, minY, maxX, maxY] in metres: the crossing window.'},
          'dx': num_('Move along x (east), m.'),
          'dy': num_('Move along y (north), m.'),
          'ids': idsWith('Only these items (default: everything in the window).', maxItems: 5000),
        },
        required: ['bbox', 'dx', 'dy'],
      ),
      run: (a, i) async {
        cadNotBusy(b);
        final w = bboxOf(i['bbox']);
        final d = Pt(a.number('dx', min: -1e6, max: 1e6, required: true)!, a.number('dy', min: -1e6, max: 1e6, required: true)!);
        if (d.length < 1e-9) throw ToolInputError('dx and dy are both 0: nothing moves.');
        final limit = a.has('ids') ? cadEditable(b, a.strings('ids')) : null;
        final keep = {...c.selection};
        final before = {for (final e in b.p.entities) e.id: e};
        // the tool stretches only the selected items when there is a selection
        c.selection
          ..clear()
          ..addAll([for (final e in limit ?? const <Entity>[]) e.id]);
        var n = 0;
        try {
          n = c.stretchWindow(w, d);
        } finally {
          c.selection
            ..clear()
            ..addAll(keep.where((id) => b.p.byId(id) != null));
        }
        if (n == 0) {
          throw ToolInputError(
            'Nothing stretched: no ${limit == null ? 'item' : 'item of "ids"'} lies in the window ${AgentToolbox.box(w)} on an unlocked, visible layer (list_entities with a bbox lists what is there).',
          );
        }
        final changed = [
          for (final e in b.p.entities)
            if (!identical(before[e.id], e)) e.id,
        ];
        return ToolOutput('Stretched $n item${n == 1 ? '' : 's'} by [${cadN(d.x)}, ${cadN(d.y)}] m: ids ${changed.take(60).join(', ')}${changed.length > 60 ? '…' : ''}.');
      },
    ),
    cadOp(
      b,
      group: 'edit',
      name: 'fillet_corner',
      effect: ToolEffect.write,
      description:
          'Rounds a corner with an arc like the Fillet tool (FILLET): two sides of one polyline-like item (polyline, pipe, lateral, tape, wire, contour, area outline) that meet at a vertex — leave other_id out (or give the same id), with a point on each side — or the end sides of two lines or open items, each trimmed or extended to the corner, the arc between them a drawing arc (vertices of the first item when both are pipes, wires… of one kind). radius_m 0 makes a sharp corner (the two trimmed or extended to meet). The points pick the sides: one on (or near) each side, away from the corner. One undo step; fails when the sides are in line, too short for the radius, or not end sides. Returns the items changed and the arc added.',
      schema: obj(
        {
          'id': str('Item of the first side (id or name).'),
          'at': pointWith('A point on the first side (m).'),
          'other_id': str('Item of the second side (default: the same item).'),
          'other_at': pointWith('A point on the second side (m).'),
          'radius_m': num_('Radius of the arc, 0–10000 m (0: a sharp corner); default the radius set for the tool.'),
        },
        required: ['id', 'at', 'other_at'],
      ),
      args: (i) => {'n': '${i['id']}'},
      run: (a, i) => _corner(b, a, chamfer: false),
    ),
    cadOp(
      b,
      group: 'edit',
      name: 'chamfer_corner',
      effect: ToolEffect.write,
      description:
          'Cuts a corner with a straight segment like the Chamfer tool (CHAMFER): the corner between two sides picked by a point on each — two sides of one polyline-like item meeting at a vertex (leave other_id out), or the end sides of two lines or open items, trimmed or extended to the corner — cut d1_m from the corner along the first side and d2_m along the second (a drawing line between them, or vertices of the first item when both are pipes, wires… of one kind). One undo step; fails when a side is shorter than its distance or the sides are in line. Returns the items changed and the line added.',
      schema: obj(
        {
          'id': str('Item of the first side (id or name).'),
          'at': pointWith('A point on the first side (m).'),
          'other_id': str('Item of the second side (default: the same item).'),
          'other_at': pointWith('A point on the second side (m).'),
          'd1_m': num_('Distance from the corner along the first side, 0–10000 m; default the tool\'s.'),
          'd2_m': num_('Distance along the second side, 0–10000 m; default d1_m when given, else the tool\'s.'),
        },
        required: ['id', 'at', 'other_at'],
      ),
      args: (i) => {'n': '${i['id']}'},
      run: (a, i) => _corner(b, a, chamfer: true),
    ),
    cadOp(
      b,
      group: 'edit',
      name: 'break_entity',
      effect: ToolEffect.write,
      description:
          'Breaks an item at two points like the Break at two points tool (BREAK): the part between the points of it nearest to "from" and "to" is taken out — an open line, polyline, pipe, lateral, tape, contour or wire leaves two pieces (one when a point is at an end; from = to cuts it in two there, as split_entity does), a closed polyline becomes an open one without the part from "from" to "to" in the order of its vertices, a circle becomes an arc (the part counter-clockwise from "from" to "to" goes), an arc up to two arcs. Areas, hatches and revision clouds stay whole. One undo step; the pieces become the selection; returns their ids.',
      schema: obj({'id': str('Item to break (id or name).'), 'from': pointWith('First point (m): the nearest point of the item.'), 'to': pointWith('Second point (m).')}, required: ['id', 'from', 'to']),
      args: (i) => {'n': '${i['id']}'},
      run: (a, i) async {
        cadNotBusy(b);
        final e = cadEditable(b, [a.str('id', required: true)!]).first;
        final p1 = a.point('from', required: true)!, p2 = a.point('to', required: true)!;
        if (!c.breakBetween(e.id, p1, p2)) {
          throw ToolInputError('${e.id} (${b.kindOf(e)}) cannot be broken there: areas, hatches and revision clouds stay whole, and the points must fall on the item (get_entity gives its vertices).');
        }
        return ToolOutput('Broke ${e.id}; pieces now: ${[...c.selection].join(', ')}.');
      },
    ),
    cadOp(
      b,
      group: 'edit',
      name: 'join_entities',
      effect: ToolEffect.write,
      description:
          'Joins items whose ends meet into one item per chain, like Edit → Join (JOIN): lines, open polylines and arcs of the drawing into a polyline (closed when the chain comes back to its start); pipes of one scope, catalogue item, sizing and depth into one pipe; wires; contours of the same elevation; breaklines. A pipe joint with a valve, an outlet or another network item on it is not crossed. Each chain keeps the id, layer and name of its first item. One undo step; the joined items become the selection; returns their ids.',
      schema: itemsSchema,
      args: count,
      binder: (i) => cadBindSelected(b, i),
      run: (a, i) async {
        cadNotBusy(b);
        final n = onItems(cadEditableOrSelection(b, a), c.joinSelected);
        if (n == 0) {
          throw ToolInputError(
            'Nothing joined: no two of these items of one kind have ends that meet (within the connection tolerance, ${cadN(b.p.params.connectTolerance, 3)} m), or the joint carries a network item.',
          );
        }
        final made = [...c.selection];
        return ToolOutput('Joined $n items into ${made.length}: ids ${made.join(', ')}.');
      },
    ),
    cadOp(
      b,
      group: 'edit',
      name: 'explode_entities',
      effect: ToolEffect.write,
      description:
          'Explodes items into their pieces, like Edit → Explode (X): a polyline into its lines (the closing one too), a hatch and a revision cloud into their outline, a spline into a polyline along its curve, a leader into its polyline and its text, a pipe, lateral, tape, contour, wire or breakline into one item per segment (the outlets of a lateral stay where they were). The first piece keeps the item\'s id. One undo step; the pieces become the selection; returns their ids.',
      schema: itemsSchema,
      args: count,
      binder: (i) => cadBindSelected(b, i),
      run: (a, i) async {
        cadNotBusy(b);
        final n = onItems(cadEditableOrSelection(b, a), c.explodeSelected);
        if (n == 0) throw ToolInputError('Nothing exploded: none of these items has pieces (points, texts, circles and areas stay as they are).');
        return ToolOutput(cadMade(b, [...c.selection], verb: 'Exploded $n item${n == 1 ? '' : 's'} into'));
      },
    ),
    cadOp(
      b,
      group: 'edit',
      name: 'convert_to_area',
      effect: ToolEffect.write,
      description:
          'Turns closed outlines into irrigated areas with the same outline, like Edit → Convert to area (TOAREA): closed polylines, hatches, revision clouds, closed splines (their curve), circles (a polygon of many sides) and open polylines whose ends meet. Each area keeps the id and the name of its outline (or gets "Area n"); set its crop, soil and the rest with update_entities. One undo step; the areas become the selection; returns their ids.',
      schema: itemsSchema,
      args: count,
      binder: (i) => cadBindSelected(b, i),
      run: (a, i) async {
        cadNotBusy(b);
        final n = onItems(cadEditableOrSelection(b, a), c.convertSelectedToArea);
        if (n == 0) {
          throw ToolInputError('No area made: none of these items is a closed outline (a closed polyline, hatch, cloud, closed spline, circle, or a polyline whose ends meet); areas stay as they are.');
        }
        return ToolOutput(cadMade(b, [...c.selection], verb: 'Made'));
      },
    ),
  ];
}

/// A fillet ([chamfer] false) or a chamfer of the corner between the sides
/// picked at "at" and "other_at" ([GeometryCommands.cornerAt]), with the
/// radius or the distances given for this call only: the tool's own
/// settings come back after it.
Future<ToolOutput> _corner(AgentToolbox b, ToolArgs a, {required bool chamfer}) async {
  final c = b.c;
  cadNotBusy(b);
  final first = cadEditable(b, [a.str('id', required: true)!]).first;
  final other = a.has('other_id') ? cadEditable(b, [a.str('other_id', required: true)!]).first : first;
  final at = a.point('at', required: true)!, otherAt = a.point('other_at', required: true)!;
  final s = c.editSettings;
  final r0 = s.filletRadius, d10 = s.chamferDistance1, d20 = s.chamferDistance2;
  final before = cadIds(b);
  var ok = false;
  try {
    if (chamfer) {
      final d1 = a.number('d1_m', min: 0, max: 10000);
      s
        ..chamferDistance1 = d1 ?? d10
        ..chamferDistance2 = a.number('d2_m', min: 0, max: 10000) ?? d1 ?? d20;
    } else {
      s.filletRadius = a.number('radius_m', min: 0, max: 10000) ?? r0;
    }
    ok = c.cornerAt(first.id, at, other.id, otherAt, chamfer: chamfer);
  } finally {
    s
      ..filletRadius = r0
      ..chamferDistance1 = d10
      ..chamferDistance2 = d20;
  }
  final what = chamfer ? 'chamfer' : 'fillet';
  if (!ok) {
    throw ToolInputError(
      identical(first, other)
          ? 'No $what: the points ${cadPt(at)} and ${cadPt(otherAt)} must lie on two sides of ${first.id} that meet at a vertex, each long enough for the ${chamfer ? 'distance' : 'radius'} (get_entity gives the vertices).'
          : 'No $what: the points must lie on end sides (the first or last segment) of ${first.id} and ${other.id}, lines or open items not in line, each long enough for the ${chamfer ? 'distance' : 'radius'} (get_entity gives the vertices).',
    );
  }
  final added = cadAdded(b, before);
  final kept = [
    first.id,
    if (!identical(first, other)) other.id,
  ].where((id) => b.p.byId(id) != null);
  return ToolOutput(
    '${chamfer ? 'Chamfered' : 'Rounded'} the corner: ${kept.join(', ')} changed${added.isEmpty ? '' : '; added ${[for (final id in added) '$id (${b.kindOf(b.p.byId(id)!)})'].join(', ')}'}.',
  );
}

// ---------------------------------------------------------------- files, browser storage, base maps

/// Save as copy, what the browser keeps of the projects (File → Browser
/// storage) and the terms of the base maps.
List<AgentTool> storageOperations(AgentToolbox b) {
  final c = b.c;
  final t = b.t;
  String two(int v) => '$v'.padLeft(2, '0');
  String stamp(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  String mb(int n) => (n / 1e6).toStringAsFixed(n < 1e7 ? 1 : 0);
  return [
    cadOp(
      b,
      group: 'file',
      name: 'save_as_copy',
      effect: ToolEffect.export,
      description:
          'File → Save as copy: the open project becomes a copy of its own — a new uid, so its copy in this browser, its saved versions and its recent entry no longer mix with the original\'s, which stays as it was — named as the menu names a copy ("<name> (copy)" in the user\'s language, or "name"), then its project file (.oci.json) is saved for the user (a download in the browser). Use it before trying an alternative on a project the user wants to keep as it is. Always confirmed by the user. Output: the new name and uid, and the file.',
      schema: obj({'name': str('Name of the copy (default: the project\'s name marked as a copy).')}),
      run: (a, i) async {
        cadNotBusy(b);
        final old = b.p.meta.uid;
        c.renewUid();
        final given = a.str('name');
        if (given != null && given.isNotEmpty) {
          c.project.meta.name = given;
        } else {
          final suffix = t('file.copyName', {'n': ''}).trim();
          if (!c.project.meta.name.trimRight().endsWith(suffix)) c.project.meta.name = t('file.copyName', {'n': c.project.meta.name});
        }
        c.fileHandle = null;
        c.refresh();
        final (file, compact) = c.fileJson();
        final name = '${engStem(c)}$projectExtension';
        await engFileSink(c, name, 'application/json', file);
        c.markSaved(compact: compact);
        return ToolOutput('The project is now a copy of its own, "${c.project.meta.name}" (uid ${c.project.meta.uid}; the original, uid $old, stays as it was in this browser). Saved $name.');
      },
    ),
    cadOp(
      b,
      group: 'file',
      name: 'browser_storage',
      description:
          'File → Browser storage: what this browser keeps of the projects — where (the IndexedDB of this browser, its localStorage, or memory), the storage used of the quota, whether the browser keeps it when space runs short (persistent), a problem keeping this project, and each project kept: name, uid, kind (autosave: the copy of work not saved to a file; saved: the copy of the last save), when, size and saved versions. These copies are not a backup: the project file is (download_stored_projects downloads them all as one ZIP; persist_storage asks the browser to keep them). Read-only.',
      schema: obj({}),
      run: (a, i) async {
        final store = c.store;
        final estimate = await storageEstimate();
        final persisted = await storagePersisted();
        final kept = store.list();
        final problem = c.storeProblem;
        final where = switch (store.bodies.kind) {
          'indexeddb' => 'the IndexedDB database of this browser, on this device only',
          'localstorage' => 'the localStorage of this browser (small: about 5 MB for the whole site)',
          _ => 'memory (nothing is kept once the program closes)',
        };
        final out = <String>[
          'Kept in $where.',
          estimate == null ? 'Storage used: unknown.' : 'Storage used: ${mb(estimate.$1)} MB of ${mb(estimate.$2)} MB.',
          switch (persisted) {
            true => 'Persistent: the browser keeps this storage when it runs short of space.',
            false => 'Not persistent: the browser may erase this storage when it runs short of space (persist_storage asks it to keep it).',
            null => 'Persistence: the browser cannot say.',
          },
          if (browserIsSafari) 'Safari erases the storage of a site not visited for seven days unless the app is installed (Share → Add to Home Screen, or File → Install).',
          if (problem != null) 'Problem keeping this project: $problem',
          if (kept.isEmpty)
            'No project is kept.'
          else ...[
            '${kept.length} project${kept.length == 1 ? '' : 's'} kept:',
            engTable(
              ['name', 'uid', 'kind', 'saved', 'MB', 'versions', ''],
              [
                for (final p in kept)
                  [
                    p.name.isEmpty ? '-' : p.name,
                    p.uid,
                    p.kind == 'autosave' ? 'autosave (not saved to a file)' : 'saved',
                    stamp(p.savedAt),
                    mb(p.stored + store.versions(p.uid).fold(0, (s, v) => s + v.stored)),
                    '${store.versions(p.uid).length}',
                    p.uid == c.project.meta.uid ? 'this tab' : '',
                  ],
              ],
            ),
          ],
        ];
        return ToolOutput(out.join('\n'));
      },
    ),
    cadOp(
      b,
      group: 'file',
      name: 'download_stored_projects',
      effect: ToolEffect.export,
      description:
          'File → Browser storage → Download all (ZIP): every project this browser keeps, as one ZIP of their project files ("<name> (<uid>).oci.json", the saved versions in versions/) — the way to back them up or to move them to another browser or device. Always confirmed by the user (a download). Input: versions (also the saved versions; default true). Output: the file name and how many projects.',
      schema: obj({'versions': bool_('Also the saved versions (default true).')}),
      run: (a, i) async {
        final kept = c.store.list();
        if (kept.isEmpty) throw ToolInputError('This browser keeps no project (browser_storage says what it keeps).');
        final zip = await zipStoredProjects(c.store, versions: a.flag('versions') ?? true);
        final d = DateTime.now();
        final name = 'opencadirrigation-${d.year}-${two(d.month)}-${two(d.day)}.zip';
        await engFileSink(c, name, 'application/zip', zip);
        return ToolOutput('Saved $name: ${kept.length} project${kept.length == 1 ? '' : 's'} (${mb(zip.length)} MB).');
      },
    ),
    cadOp(
      b,
      group: 'file',
      name: 'persist_storage',
      effect: ToolEffect.write,
      // a choice about the user's browser: always the user's say-so
      confirm: (_) => true,
      description:
          'File → Browser storage → Ask to keep it: asks the browser to keep this site\'s storage (the copies of the projects, their versions and the assistant\'s conversations) when it runs short of space. Chromium browsers decide by themselves; Firefox shows the user its own question. Always confirmed by the user first; changes nothing in the project. Output: whether the browser keeps the storage now.',
      schema: obj({}),
      run: (a, i) async {
        if (await storagePersisted() == true) return const ToolOutput('The browser already keeps this site\'s storage (persistent): nothing to ask.');
        final r = await requestPersistentStorage();
        return ToolOutput(switch (r) {
          true => 'Granted: the browser keeps this site\'s storage when it runs short of space.',
          false => 'Not granted${browserIsFirefox ? ' (the user declined Firefox\'s question, or it was dismissed)' : ' (the browser decides by itself: a site used more often, or installed as an app, is usually granted)'}. The project file stays the backup.',
          null => 'This browser (or this build of the program) cannot be asked.',
        });
      },
    ),
    cadOp(
      b,
      group: 'view',
      name: 'base_map_terms',
      description:
          'View → Base map → Terms of the maps: who provides each base map, what its terms allow and the links to them, as the dialog lists them, with the base map on screen and the street map server in use — to tell the user what a map may be used for (a printed sheet, a commercial project). Read-only.',
      schema: obj({}),
      run: (a, i) async {
        final sources = <(BaseMap, String, String, String)>[
          (BaseMap.streets, 'basemap.terms.osm', osmTilePolicyUrl, ''),
          (BaseMap.topo, 'basemap.terms.topo', BaseMapLayer.attributionUrl(BaseMap.topo), ''),
          (BaseMap.carto, 'basemap.terms.carto', BaseMapLayer.attributionUrl(BaseMap.carto), ''),
          (BaseMap.satellite, 'basemap.terms.esri', BaseMapLayer.attributionUrl(BaseMap.satellite), ', also esriStreets and esriTopo'),
          (BaseMap.googleSatellite, 'basemap.terms.google', BaseMapLayer.attributionUrl(BaseMap.googleSatellite), ', also googleRoads, googleHybrid and googleTerrain: the user\'s own key'),
        ];
        final streets = c.streetsTileUrl.trim();
        final custom = c.customTileUrl.trim();
        final out = <String>[
          t('basemap.terms.intro'),
          for (final (m, key, url, more) in sources) '## ${t('view.baseMap.${m.name}')} (view.base_map "${m.name}"$more)\nCredit: ${BaseMapLayer.attribution(m)}\n${t(key)}\nTerms: $url',
          'On screen now: view.base_map "${c.baseMap.name}"${c.project.meta.georef == null ? ' (the project has no georeference: no map shows)' : ''}.',
          streets.isEmpty
              ? 'Street map server: the OpenStreetMap Foundation\'s own (${BaseMapLayer.defaultStreetsTemplate}), run by volunteers; its usage policy asks programs used by many people to arrange heavy use first (setting view.streets_tile_url sets another server of the same tiles).'
              : 'Street map server: $streets (setting view.streets_tile_url; its terms are its provider\'s).',
          if (custom.isNotEmpty) 'Custom base map: $custom (its terms are its provider\'s).',
        ];
        return ToolOutput(out.join('\n'));
      },
    ),
  ];
}

// ---------------------------------------------------------------- the normals of a weather station (AGR-13)

/// The site climate from the normals of a weather station: the monthly
/// FAO-56 Penman-Monteith ETo, as the station tab of Design → Site climate
/// works it out.
List<AgentTool> stationClimateOperations(AgentToolbox b) {
  final c = b.c;
  final t = b.t;
  return [
    engOp(
      b,
      name: 'eto_from_station_normals',
      effect: ToolEffect.read,
      effectFor: (i) => i['apply'] == true ? ToolEffect.write : ToolEffect.read,
      description:
          'Design → Site climate → Station normals: the monthly grass reference evapotranspiration (ETo) by FAO-56 Penman-Monteith from the climatological normals of a weather station, month by month with the soil heat flux from the neighbouring months, estimating what the station lacks as FAO-56 chapter 3 says (humidity from Tmin as the dew point, radiation from the temperature range, wind 2 m/s). Each monthly input is 12 values, January first, null for a month without data: tmax_c and tmin_c (mean daily maximum and minimum, °C; a month needs both), rh_mean_pct (mean relative humidity), wind_ms (mean wind) measured at wind_height_m (default 2 m), sunshine_h (mean daily bright sunshine), rain_mm (monthly rain); latitude_deg (default the site\'s), elevation_m (the station\'s; default 0), coastal (near the coast or a large lake: kRs 0.19 instead of 0.16). It changes nothing unless apply is true: then the result goes into the site climate, one undo step, source "station" — the ETo, the rain where given, the minimum relative humidity (FAO-56 eq. 63) and the wind at 2 m that adjust the crop coefficients, and the irradiation where the project has none; the months without both temperatures keep their values. Output: the monthly table (ETo mm/day and mm/month, Rs, RHmin, u2, rain, what was estimated) and the ETo of the year.',
      schema: obj(
        {
          'tmax_c': numbers('Mean daily maximum temperature, °C, Jan…Dec (null: no data).', n: 12),
          'tmin_c': numbers('Mean daily minimum temperature, °C, Jan…Dec (null: no data).', n: 12),
          'rh_mean_pct': numbers('Mean relative humidity, %, Jan…Dec.', n: 12),
          'wind_ms': numbers('Mean wind speed, m/s, Jan…Dec, measured at wind_height_m.', n: 12),
          'wind_height_m': num_('Height of the wind measurements, 0.5–20 m; default 2.'),
          'sunshine_h': numbers('Mean daily bright sunshine, hours, Jan…Dec.', n: 12),
          'rain_mm': numbers('Rain, mm per month, Jan…Dec.', n: 12),
          'latitude_deg': num_('Latitude of the station, −90…90; default the site\'s.'),
          'elevation_m': num_('Elevation of the station, −500…6000 m; default 0.'),
          'coastal': bool_('Near the coast or a large water body (default false).'),
          'apply': bool_('Store the result in the site climate (one undo step; default false).'),
        },
        required: ['tmax_c', 'tmin_c'],
      ),
      summary: (i) => t(i['apply'] == true ? 'ai.op.eto_from_station_normals.apply' : 'ai.op.eto_from_station_normals'),
      run: (a, i) async {
        // twelve monthly values, null where the station has none
        List<double?> monthly(String k, double min, double max) {
          final v = i[k];
          if (v == null) return List<double?>.filled(12, null);
          if (v is! List || v.length != 12) throw ToolInputError('"$k" needs 12 monthly values, January first (null for a month without data).');
          return [
            for (var m = 0; m < 12; m++)
              switch (v[m]) {
                null => null,
                final num x when x.isFinite && x >= min && x <= max => x.toDouble(),
                final x => throw ToolInputError('"$k" for ${engMonths[m]} is $x: give a number from ${engN(min, 0)} to ${engN(max, 0)}, or null.'),
              },
          ];
        }

        final tMax = monthly('tmax_c', -60, 60), tMin = monthly('tmin_c', -70, 50);
        final rh = monthly('rh_mean_pct', 0, 100), wind = monthly('wind_ms', 0, 60), sun = monthly('sunshine_h', 0, 24), rain = monthly('rain_mm', 0, 3000);
        final height = a.number('wind_height_m', min: 0.5, max: 20) ?? 2;
        final site = c.siteLatLon;
        final lat = a.number('latitude_deg', min: -90, max: 90) ?? site?.$1;
        if (lat == null) throw ToolInputError('Give latitude_deg: the project has no georeference (set_site places it).');
        final elevation = a.number('elevation_m', min: -500, max: 6000) ?? 0;
        final coastal = a.flag('coastal') ?? false;
        final months = [
          for (var m = 0; m < 12; m++)
            if (tMax[m] != null && tMin[m] != null)
              MonthlyClimate(
                month: m + 1,
                tMaxC: math.max(tMax[m]!, tMin[m]!),
                tMinC: math.min(tMax[m]!, tMin[m]!),
                rhMeanPct: rh[m]?.clamp(1.0, 100.0).toDouble(),
                windSpeed2mMs: wind[m] == null ? null : windSpeedAt2m(wind[m]!, height),
                sunshineHours: sun[m],
                rainMm: rain[m] ?? 0,
              ),
        ];
        if (months.isEmpty) throw ToolInputError('No month has both tmax_c and tmin_c: give them (null only for the months without data).');
        final res = fao56MonthlySeries(months, latitudeDeg: lat, elevationM: elevation, kRs: coastal ? 0.19 : 0.16);
        // FAO-56 eq. 63: the minimum relative humidity of the month from its vapour pressure
        double rhMinOf(int m) => (100 * res[m]!.eaKPa / saturationVapourPressureKPa(math.max(tMax[m]!, tMin[m]!))).clamp(0.0, 100.0).toDouble();
        var year = 0.0;
        final rows = <List<Object?>>[];
        for (var m = 0; m < 12; m++) {
          final r = res[m];
          if (r == null) {
            rows.add([engMonths[m], '-', '-', '-', '-', '-', rain[m] == null ? '-' : engN(rain[m]!, 0), 'no temperatures']);
            continue;
          }
          final days = daysInMonth(2001, m + 1);
          year += r.etoMmDay * days;
          rows.add([
            engMonths[m],
            engN(r.etoMmDay, 2),
            engN(r.etoMmDay * days, 0),
            engN(r.rsMJ / mjPerKWh, 2),
            engN(rhMinOf(m), 0),
            engN(r.u2Ms, 2),
            rain[m] == null ? '-' : engN(rain[m]!, 0),
            r.estimated.isEmpty ? '-' : r.estimated.map((x) => x.name).join(', '),
          ]);
        }
        final head =
            'FAO-56 Penman-Monteith ETo from the station normals, latitude ${engN(lat, 4)}°, elevation ${engN(elevation, 0)} m, kRs ${coastal ? '0.19 (coastal)' : '0.16 (interior)'}, wind measured at ${engN(height, 1)} m: ${months.length} of 12 months; ${months.length == 12 ? 'the year' : 'these months'} ${engN(year, 0)} mm.';
        final table = engTable(['month', 'ETo mm/day', 'ETo mm/month', 'Rs kWh/m²/day', 'RHmin %', 'u2 m/s', 'rain mm', 'estimated'], rows);
        if (!(a.flag('apply') ?? false)) return ToolOutput('$head\n$table\nNot stored: apply true keeps it in the site climate.');
        engNotBusy(c);
        // the months the station has replace those of the climate the project has
        final cur = b.p.climate;
        List<double> twelve(List<double>? v, double fill) => [for (var m = 0; m < 12; m++) v != null && m < v.length ? v[m] : fill];
        final eto = twelve(cur?.etoMmDay, 0), rainOut = twelve(cur?.rainMm, 0), rs = twelve(cur?.solarKWhM2Day, 0);
        final rhMin = twelve(cur?.rhMinPct, double.nan), u2 = twelve(cur?.windSpeed2mMs, double.nan);
        var computed = 0, rained = 0;
        for (var m = 0; m < 12; m++) {
          final r = res[m];
          if (r == null) continue;
          computed++;
          eto[m] = r.etoMmDay;
          final mm = rain[m];
          if (mm != null) {
            rainOut[m] = mm;
            rained++;
          }
          rhMin[m] = rhMinOf(m);
          u2[m] = r.u2Ms;
          if (rs[m] <= 0) rs[m] = r.rsMJ / mjPerKWh;
        }
        final dep = cur?.dependableRainMm;
        final sc = SiteClimate(
          etoMmDay: eto,
          rainMm: rainOut,
          dependableRainMm: dep == null || dep.every((x) => x == 0) ? null : [...dep],
          solarKWhM2Day: rs.any((v) => v > 0) ? rs : null,
          rhMinPct: SiteClimate.monthlyOrNull(rhMin),
          windSpeed2mMs: SiteClimate.monthlyOrNull(u2),
          source: 'station',
          firstYear: cur?.firstYear ?? 0,
          lastYear: cur?.lastYear ?? 0,
          latitudeDeg: site?.$1 ?? cur?.latitudeDeg ?? lat,
          longitudeDeg: site?.$2 ?? cur?.longitudeDeg ?? 0,
          retrieved: cur?.retrieved ?? '',
          attribution: cur?.attribution ?? '',
        );
        c.setClimate(sc);
        final kc = sc.rhMinPct != null && sc.windSpeed2mMs != null
            ? 'the RHmin and the wind at 2 m of the twelve months (the Kc adjustment uses them)'
            : 'the RHmin and the wind of these months (the Kc adjustment needs all twelve: give the other months, or set_site_climate rh_min_pct and wind_2m_ms)';
        return ToolOutput(
          '$head\n$table\nStored in the site climate (source "station", one undo step): the ETo of $computed month${computed == 1 ? '' : 's'}, the rain of $rained, $kc, and the irradiation where the project had none. The irrigation requirement and the reports follow it.',
        );
      },
    ),
  ];
}
