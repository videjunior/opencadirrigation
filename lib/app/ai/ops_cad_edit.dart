/// Drawing edits of the AI assistant (groups "edit" and "zone"): offset,
/// trim, extend, split, array, two-point alignment, vertices and grips,
/// the clipboard, the properties update_entities cannot change, laterals
/// to plain pipe, devices on laterals, the feed envelope, the block and
/// sprinkler-grid dialogs. Each calls the controller function the tool or
/// dialog of the program calls.
library;

import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../../core/ai/agent_loop.dart';
import '../../core/design/block_generator.dart';
import '../../core/design/proposal.dart' show selectionBom, unsizedPipeLength;
import '../../core/hydraulics/emitter.dart' show gridOverlapCU, precipitationMmPerHour, precipitationRate;
import '../../core/model/catalog.dart';
import '../../core/model/entities.dart';
import '../../core/model/geometry.dart';
import '../../core/model/split.dart' show offsetEntity;
import '../io/file_io.dart' show saveTextFile;
import '../state/controller.dart';
import '../state/workspace.dart' show ClipboardPayload;
import 'agent_tools.dart';
import 'agent_tools_design.dart' show outlineOf;
import 'ops_cad_common.dart';
import 'ops_cad_view.dart' show AiWorkspaceHost;

/// The last payload copied by the assistant (the system clipboard may be
/// unreadable: tests, browser permissions).
ClipboardPayload? aiClipboard;

/// Keys update_extra_properties changes, by entity type.
const extraKeys = <String, List<String>>{
  'dimension': ['a', 'b', 'off'],
  'angularDimension': ['v', 'a', 'b', 'r'],
  'radialDimension': ['c', 'p', 'dia'],
  'ordinateDimension': ['p', 'e', 'o', 'x'],
  'image': ['p', 'w', 'h', 'rot', 'op'],
  'revisionCloud': ['pts', 'rev', 'date', 'desc', 'arc'],
  'contour': ['gen'],
  'controller': ['acc'],
};

const _pointKeys = {'a', 'b', 'v', 'c', 'p', 'e', 'o'};

/// The polygon of [ref] (a closed item) or [pts].
List<Pt> cadPolygon(AgentToolbox b, ToolArgs a, {String areaKey = 'area', String ptsKey = 'pts'}) {
  final ref = a.str(areaKey);
  if (ref != null) {
    final o = outlineOf(b.find(ref));
    if (o == null) throw ToolInputError('"$ref" is not a closed shape (an area, a closed polyline, a circle or a pivot).');
    return o;
  }
  final pts = a.points(ptsKey, min: 3);
  if (pts == null) throw ToolInputError('Give "$areaKey" (id of a closed shape) or "$ptsKey" (the polygon).');
  if (polygonArea(pts).abs() < 0.01) throw ToolInputError('"$ptsKey" encloses no surface.');
  return pts;
}

/// Direction of the longest edge of [poly], in degrees counter-clockwise
/// from east (the block dialog's default).
double longestEdgeDeg(List<Pt> poly) {
  var best = 0.0, dir = 0.0;
  for (var i = 0; i < poly.length; i++) {
    final a = poly[i], b = poly[(i + 1) % poly.length];
    if (a.distanceTo(b) > best) {
      best = a.distanceTo(b);
      dir = radToDeg((b - a).angle);
    }
  }
  return dir;
}

List<AgentTool> editOperations(AgentToolbox b) {
  final c = b.c;
  final t = b.t;
  Map<String, String> count(Map<String, dynamic> i, [String key = 'ids']) => {'n': '${(i[key] as List?)?.length ?? 1}'};
  return [
    cadOp(
      b,
      group: 'edit',
      name: 'offset_entities',
      effect: ToolEffect.write,
      description: 'Offsets items like the Offset tool (O): a parallel copy at a distance — lines, polylines, splines, contours, pipes, laterals, tapes and areas side by side, circles and arcs with a larger or smaller radius; closed shapes stay closed. "side": left or right of the drawing direction (first vertex → last), outside or inside for circles, arcs and closed shapes; or "side_point", a point on the side wanted. "copies" > 1 repeats it (k × distance), e.g. parallel laterals. One undo step; returns the new ids. Items on locked layers are refused.',
      schema: obj(
        {
          'ids': idsWith('Items to offset (ids or names).', maxItems: 200),
          'distance_m': num_('Offset distance (m), above 0.'),
          'side': str('Default "left" ("outside" for circles and arcs).', ['left', 'right', 'outside', 'inside']),
          'side_point': pointWith('A point on the side to offset towards (instead of "side").'),
          'copies': int_('Copies at 1×, 2×… the distance, 1–100 (default 1).'),
        },
        required: ['ids', 'distance_m'],
      ),
      args: count,
      run: (a, i) async {
        cadNotBusy(b);
        final es = cadEditable(b, a.strings('ids', required: true));
        final d = a.number('distance_m', min: 1e-6, max: 1e6, required: true)!;
        final sideGiven = a.str('side');
        final sp = a.point('side_point');
        final copies = a.integer('copies', min: 1, max: 100) ?? 1;
        final plan = <(Entity, double)>[];
        for (final e in es) {
          final round = e is CircleEntity || e is ArcEntity;
          final closed = e.isClosedShape;
          final side = sideGiven ?? (round ? 'outside' : 'left');
          double sign;
          if (sp != null) {
            if (e is CircleEntity) {
              sign = sp.distanceTo(e.center) > e.radius ? 1 : -1;
            } else if (e is ArcEntity) {
              sign = sp.distanceTo(e.center) > e.radius ? 1 : -1;
            } else {
              final pts = e.linearPoints;
              if (pts == null || pts.length < 2) throw ToolInputError('${e.id} (${b.kindOf(e)}) cannot be offset.');
              var best = double.infinity;
              sign = 1;
              final n = pts.length + (closed ? 1 : 0);
              for (var k = 1; k < n; k++) {
                final p0 = pts[k - 1], p1 = pts[k % pts.length];
                final dist = distanceToSegment(sp, p0, p1);
                if (dist < best) {
                  best = dist;
                  sign = (p1 - p0).cross(sp - p0) >= 0 ? 1 : -1;
                }
              }
            }
          } else if (round) {
            if (side == 'left' || side == 'right') throw ToolInputError('${e.id} is a ${b.kindOf(e)}: use side "outside" or "inside".');
            sign = side == 'outside' ? 1 : -1;
          } else if (side == 'outside' || side == 'inside') {
            final pts = e.linearPoints;
            if (!closed || pts == null) throw ToolInputError('${e.id} is not closed: use side "left" or "right" (of the direction first vertex → last).');
            // left of a counter-clockwise ring is inside
            final ccw = polygonArea(pts) > 0;
            sign = (side == 'inside') == ccw ? 1 : -1;
          } else {
            sign = side == 'left' ? 1 : -1;
          }
          if (offsetEntity(e, sign * d, 'probe') == null) {
            throw ToolInputError(
              '${e.id} (${b.kindOf(e)}) cannot be offset${e is CircleEntity || e is ArcEntity ? ' that far inside' : ' (lines, polylines, splines, contours, pipes, laterals, tapes, areas, circles and arcs can)'}.',
            );
          }
          plan.add((e, sign * d));
        }
        final made = b.change('offset_entities', () {
          final out = <Entity>[];
          for (final (e, sd) in plan) {
            for (var k = 1; k <= copies; k++) {
              final o = offsetEntity(e, sd * k, b.p.newId());
              if (o != null) out.add(o);
            }
          }
          b.p.entities.addAll(out);
          return out;
        }, invalidate: plan.any((x) => x.$1.isHydraulic));
        c.select(made.map((e) => e.id));
        return ToolOutput(cadMade(b, made.map((e) => e.id)));
      },
    ),
    cadOp(
      b,
      group: 'edit',
      name: 'trim_entity',
      effect: ToolEffect.write,
      description: 'Trims a line, polyline, pipe, lateral, tape, contour or spline like the Trim tool (TR): the part around "at" between the nearest crossings with the boundary items is removed (the rest may become two pieces). Boundaries: the items given, else every visible line of the drawing. Open items only. One undo step; returns the pieces left. Fails when no boundary crosses the item around that point.',
      schema: obj(
        {'id': str('Item to trim (id or name).'), 'at': pointWith('A point on the part to remove (m).'), 'boundaries': idsWith('Cutting items (default: every visible line).', maxItems: 500)},
        required: ['id', 'at'],
      ),
      args: (i) => {'n': '${i['id']}'},
      run: (a, i) async {
        cadNotBusy(b);
        final e = cadEditable(b, [a.str('id', required: true)!]).first;
        final at = a.point('at', required: true)!;
        final bounds = a.strings('boundaries');
        final keep = {...c.selection};
        final before = cadIds(b);
        c.selection
          ..clear()
          ..addAll(b.findAll(bounds).map((x) => x.id).where((x) => x != e.id));
        final ok = c.trimAt(e.id, at);
        c.selection
          ..clear()
          ..addAll(keep.where((x) => b.p.byId(x) != null));
        if (!ok) throw ToolInputError('Nothing trimmed: no boundary crosses ${e.id} around ${cadPt(at)} (or it is closed, or not a line). Check with get_entity, or give "boundaries".');
        final added = cadAdded(b, before);
        return ToolOutput(
          'Trimmed ${e.id}${b.p.byId(e.id) == null ? '' : ' (kept)'}; pieces now: ${[
            ...?b.p.byId(e.id) == null ? null : [e.id],
            ...added,
          ].join(', ')}.',
        );
      },
    ),
    cadOp(
      b,
      group: 'edit',
      name: 'extend_entity',
      effect: ToolEffect.write,
      description: 'Extends the end of a line, polyline, pipe, lateral, tape or contour nearest to "at" until it meets a boundary item, like the Extend tool (EX). Boundaries: the items given, else every visible line. One undo step; returns the new end point. Fails when nothing lies ahead of that end.',
      schema: obj(
        {'id': str('Item to extend (id or name).'), 'at': pointWith('A point near the end to extend (m).'), 'boundaries': idsWith('Items to extend to (default: every visible line).', maxItems: 500)},
        required: ['id', 'at'],
      ),
      args: (i) => {'n': '${i['id']}'},
      run: (a, i) async {
        cadNotBusy(b);
        final e = cadEditable(b, [a.str('id', required: true)!]).first;
        final at = a.point('at', required: true)!;
        final keep = {...c.selection};
        c.selection
          ..clear()
          ..addAll(b.findAll(a.strings('boundaries')).map((x) => x.id).where((x) => x != e.id));
        final ok = c.extendAt(e.id, at);
        c.selection
          ..clear()
          ..addAll(keep);
        if (!ok) throw ToolInputError('Nothing extended: no boundary lies ahead of the end of ${e.id} nearest ${cadPt(at)} (or it is closed, or not a line).');
        final pts = b.p.byId(e.id)?.linearPoints;
        return ToolOutput('Extended ${e.id}${pts == null ? '' : ': it now runs ${cadPt(pts.first)} → ${cadPt(pts.last)}, ${cadN(AgentToolbox.lengthOf(pts), 2)} m'}.');
      },
    ),
    cadOp(
      b,
      group: 'edit',
      name: 'split_entity',
      effect: ToolEffect.write,
      description: 'Cuts a pipe, lateral, tape, line, polyline or contour into pieces at the points closest to "at" (or each of "points"), like the Cut pipe tool (CUT, BR): the pieces keep the properties and join at the cut, so a valve or device can go there. One undo step per cut; returns the ids of the pieces.',
      schema: obj(
        {'id': str('Item to cut (id or name).'), 'at': pointWith('Where to cut (m): the closest point of the item.'), 'points': pointsWith('Several cut points instead of "at".', maxItems: 100)},
        required: ['id'],
      ),
      args: (i) => {'n': '${i['id']}'},
      run: (a, i) async {
        cadNotBusy(b);
        final e = cadEditable(b, [a.str('id', required: true)!]).first;
        if (e.linearPoints == null) throw ToolInputError('${e.id} (${b.kindOf(e)}) is not a line that can be cut.');
        final cuts = [?a.point('at'), ...?a.points('points', max: 100)];
        if (cuts.isEmpty) throw ToolInputError('Give "at" or "points".');
        var pieces = <String>[e.id];
        var done = 0;
        for (final q in cuts) {
          // the piece nearest to the cut point
          Entity? best;
          var bd = double.infinity;
          for (final id in pieces) {
            final x = b.p.byId(id);
            if (x == null) continue;
            final d = x.distanceTo(q);
            if (d < bd) {
              bd = d;
              best = x;
            }
          }
          if (best == null) continue;
          final before = cadIds(b);
          if (c.cutAt(best.id, q)) {
            done++;
            // the first piece keeps the id of the item cut
            pieces = [...pieces.where((x) => b.p.byId(x) != null), ...cadAdded(b, before)];
          }
        }
        if (done == 0) throw ToolInputError('No cut made: the points fall on an end of ${e.id}, or past it.');
        return ToolOutput('$done cut${done == 1 ? '' : 's'}; pieces: ${pieces.join(', ')}.');
      },
    ),
    cadOp(
      b,
      group: 'edit',
      name: 'array_entities',
      effect: ToolEffect.write,
      description: 'Copies items in a rectangular or polar array, as Edit → Array (ARRAY): rows × columns at the spacings along the row direction, or "count" copies around "center" over "total_angle_deg" (turned with the array unless rotate_items is false). Defaults as the dialog: spacings the size of the items + 2 m, centre the centre of the items. One undo step; returns the new ids.',
      schema: obj(
        {
          'ids': idsWith('Items to repeat.', maxItems: 2000),
          'kind': str('Default "rectangular".', ['rectangular', 'polar']),
          'rows': int_('Rows, 1–500 (default 2).'),
          'cols': int_('Columns, 1–500 (default 2).'),
          'col_spacing_m': num_('Distance between columns along the row direction (m).'),
          'row_spacing_m': num_('Distance between rows (m).'),
          'angle_deg': num_('Row direction, degrees counter-clockwise from east (default 0).'),
          'count': int_('Polar: items in all, the original included, 2–720 (default 6).'),
          'total_angle_deg': num_('Polar: angle filled (default 360).'),
          'center': pointWith('Polar: centre (default: the centre of the items).'),
          'rotate_items': bool_('Polar: turn the copies with the array (default true).'),
        },
        required: ['ids'],
      ),
      args: count,
      run: (a, i) async {
        cadNotBusy(b);
        final es = cadEditable(b, a.strings('ids', required: true));
        final bx = es.fold(Bounds.empty, (Bounds x, e) => x.union(e.bounds));
        final polar = a.str('kind') == 'polar';
        final o = ArrayOptions(
          polar: polar,
          rows: a.integer('rows', min: 1, max: 500) ?? 2,
          cols: a.integer('cols', min: 1, max: 500) ?? 2,
          dx: a.number('col_spacing_m', min: -1e5, max: 1e5) ?? (bx.isEmpty ? 5 : bx.width + 2),
          dy: a.number('row_spacing_m', min: -1e5, max: 1e5) ?? (bx.isEmpty ? 5 : bx.height + 2),
          angleDeg: a.number('angle_deg') ?? 0,
          count: a.integer('count', min: 2, max: 720) ?? 6,
          center: a.point('center') ?? (bx.isEmpty ? Pt.zero : bx.center),
          totalAngleDeg: a.number('total_angle_deg', min: -3600, max: 3600) ?? 360,
          rotateItems: a.flag('rotate_items') ?? true,
        );
        final copies = polar ? (o.count - 1) * es.length : (o.rows * o.cols - 1) * es.length;
        if (copies > 20000) throw ToolInputError('That makes $copies copies; at most 20000 per call.');
        final before = cadIds(b);
        c.select(es.map((e) => e.id));
        final n = c.arraySelected(o);
        if (n == 0) throw ToolInputError('Nothing copied (an array of 1 × 1?).');
        return ToolOutput(cadMade(b, cadAdded(b, before)));
      },
    ),
    cadOp(
      b,
      group: 'edit',
      name: 'align_entities',
      effect: ToolEffect.write,
      description: 'Aligns items by two point pairs, like the two-point Align tool (AL, File → Align image): the similarity transform (move, turn and scale; scale kept with keep_scale) that takes from_a to to_a and from_b to to_b — e.g. an imported plan or image onto surveyed points or the base map. One undo step; returns the scale and rotation applied.',
      schema: obj(
        {
          'ids': idsWith('Items to align (an image, an imported plan…).', maxItems: 20000),
          'from_a': pointWith('First reference point on the items (m).'),
          'to_a': pointWith('Where it goes (m).'),
          'from_b': pointWith('Second reference point on the items (m), away from the first.'),
          'to_b': pointWith('Where it goes (m).'),
          'keep_scale': bool_('Move and turn only (default: tool.align_keep_scale).'),
        },
        required: ['ids', 'from_a', 'to_a', 'from_b', 'to_b'],
      ),
      args: count,
      run: (a, i) async {
        cadNotBusy(b);
        final es = cadEditable(b, a.strings('ids', required: true));
        final fa = a.point('from_a', required: true)!, ta = a.point('to_a', required: true)!, fb = a.point('from_b', required: true)!, tb = a.point('to_b', required: true)!;
        if (fa.distanceTo(fb) < 1e-6 || ta.distanceTo(tb) < 1e-6) throw ToolInputError('The two points of each pair must differ.');
        final tr = similarityFromPairs(fa, fb, ta, tb, keepScale: a.flag('keep_scale') ?? c.toolSettings.alignKeepScale);
        if (tr == null) throw ToolInputError('No transform takes those points onto each other.');
        c.select(es.map((e) => e.id));
        final n = c.transformSelected(tr, label: 'hist.align');
        c.track('align');
        return ToolOutput('Aligned $n items: scale ${cadN(tr.scale, 4)}, rotation ${cadN(radToDeg(tr.transformAngle(0)), 3)}°, ${cadPt(fa)} → ${cadPt(tr.apply(fa))}.');
      },
    ),
    cadOp(
      b,
      group: 'edit',
      name: 'edit_vertices',
      effect: ToolEffect.write,
      description: 'Edits the grips of an item as the selection tool does: "move" a grip (vertex of a line or polyline, position of a point item, corner of an image, dimension points) to "point", dragging along the pipes and items joined there when keep_connections is true (the default for pipes: their joints stay connected); "insert" a vertex at "index" of a polyline-like item (pipe, lateral, polyline…); "remove" vertex "index" (at least 2 stay). Grips and vertices are numbered from 0 as get_entity lists them. One undo step.',
      schema: obj(
        {
          'id': str('Item (id or name).'),
          'action': str(null, ['move', 'insert', 'remove']),
          'index': int_('Grip or vertex index (insert: the index the new vertex takes).'),
          'point': pointWith('New position (move, insert) in metres.'),
          'keep_connections': bool_('move: drag the joined pipe ends and items too (default tool.keep_connections).'),
        },
        required: ['id', 'action', 'index'],
      ),
      args: (i) => {'n': '${i['id']}', 'op': '${i['action']}'},
      run: (a, i) async {
        cadNotBusy(b);
        final e = cadEditable(b, [a.str('id', required: true)!]).first;
        final action = a.str('action', required: true)!;
        final index = a.integer('index', min: 0, required: true)!;
        switch (action) {
          case 'move':
            final p = a.point('point', required: true)!;
            if (index >= e.grips.length) throw ToolInputError('${e.id} has ${e.grips.length} grips (0–${e.grips.length - 1}).');
            c.setGrip(e.id, index, p, keepConnections: a.flag('keep_connections') ?? (c.toolSettings.keepConnections && (e is PolyEntity || e is LineEntity)));
          case 'insert':
            if (e is! PolyEntity) throw ToolInputError('${e.id} (${b.kindOf(e)}) has no vertex list to insert into.');
            if (index > e.points.length) throw ToolInputError('${e.id} has ${e.points.length} vertices: insert at 0–${e.points.length}.');
            if (!c.insertVertex(e.id, index, a.point('point', required: true)!)) throw ToolInputError('The vertex was not inserted.');
          default:
            if (e is! PolyEntity) throw ToolInputError('${e.id} (${b.kindOf(e)}) has no vertex list.');
            if (index >= e.points.length) throw ToolInputError('${e.id} has ${e.points.length} vertices (0–${e.points.length - 1}).');
            if (e.points.length <= 2) throw ToolInputError('${e.id} keeps at least 2 vertices.');
            c.removeVertex(e.id, index);
        }
        final now = b.p.byId(e.id)!;
        return ToolOutput('${e.id}: $action done; grips now ${now.grips.length > 30 ? '${now.grips.length} (first 30) ' : ''}${[for (final g in now.grips.take(30)) cadPt(g)].join(' ')}.');
      },
    ),
    cadOp(
      b,
      group: 'edit',
      name: 'clipboard',
      effectFor: (i) => i['action'] == 'copy' ? ToolEffect.read : ToolEffect.write,
      description: 'Edit → Copy / Cut / Paste (Ctrl+C, Ctrl+X, Ctrl+V) for items: "copy" puts items (with their layers and catalogue items) on the clipboard the program shares between tabs and windows; "cut" copies and deletes them; "paste" adds the clipboard\'s items to this project (new ids; 2 m east and south of the originals when pasted back where they came from). Copying changes nothing; cut and paste are one undo step. To copy within the project with an offset use transform_entities "copy".',
      schema: obj(
        {
          'action': str(null, ['copy', 'cut', 'paste']),
          'ids': idsWith('copy/cut: the items (default: the selection).', maxItems: 20000),
        },
        required: ['action'],
      ),
      args: (i) => {'n': '${(i['ids'] as List?)?.length ?? ''}', 'op': '${i['action']}'},
      run: (a, i) async {
        final action = a.str('action', required: true)!;
        final ws = b.host is AiWorkspaceHost ? b.host as AiWorkspaceHost : null;
        if (action == 'paste') {
          cadNotBusy(b);
          final before = cadIds(b);
          if (ws != null) {
            final n = await ws.paste();
            if (n == 0) throw ToolInputError('The clipboard is empty.');
          } else {
            ClipboardPayload? p;
            try {
              p = ClipboardPayload.tryParse((await Clipboard.getData(Clipboard.kTextPlain).timeout(const Duration(milliseconds: 800)))?.text);
            } catch (_) {
              p = null;
            }
            p ??= aiClipboard;
            if (p == null) throw ToolInputError('The clipboard is empty.');
            p.pasteInto(c);
          }
          return ToolOutput(cadMade(b, cadAdded(b, before), verb: 'Pasted'));
        }
        final ids = a.strings('ids');
        final es = ids.isEmpty
            ? [
                for (final e in b.p.entities)
                  if (c.selection.contains(e.id)) e,
              ]
            : b.findAll(ids);
        if (es.isEmpty) throw ToolInputError('Nothing to ${action == 'cut' ? 'cut' : 'copy'}: give "ids" or select items first.');
        if (action == 'cut') {
          cadNotBusy(b);
          cadEditable(b, es.map((e) => e.id));
        }
        c.select(es.map((e) => e.id));
        if (ws != null) {
          await ws.copySelection(cut: action == 'cut');
        } else {
          final p = ClipboardPayload.fromSelection(c);
          aiClipboard = p;
          try {
            await Clipboard.setData(ClipboardData(text: p.encode())).timeout(const Duration(milliseconds: 800));
          } catch (_) {
            // the assistant's own copy is enough to paste here
          }
          if (action == 'cut') c.deleteSelected();
        }
        return ToolOutput('${action == 'cut' ? 'Cut' : 'Copied'} ${es.length} items to the clipboard (paste them with clipboard "paste", or the user with Ctrl+V in any tab).');
      },
    ),
    cadOp(
      b,
      group: 'edit',
      name: 'update_extra_properties',
      effect: ToolEffect.write,
      description:
          'Changes the properties update_entities cannot, as the properties panel does, in one undo step (project-file keys, SI, points [x, y] in metres):\n- dimension {a, b (measured points), off (offset of the dimension line, m, positive to the left of a→b)}\n- angularDimension {v (vertex), a, b (points on the two rays), r (arc radius m)}\n- radialDimension {c (centre), p (point on the circle), dia (true: diameter)}\n- ordinateDimension {p (feature point), e (leader end), o (datum origin), x (true: writes X, false: Y)}\n- image {p (bottom-left corner), w, h (size m), rot (deg counter-clockwise), op (opacity 0.05–1)}\n- revisionCloud {pts, rev (tag), date (YYYY-MM-DD), desc, arc (arc chord m, 0 = automatic)}\n- contour {gen (false: a generated contour becomes survey data that feeds the terrain)}\n- controller {acc: {accessory: price} with accessories ${controllerAccessoryKinds.join(', ')}; the map replaces the fitted ones}.\nItems on locked layers are refused.',
      schema: obj(
        {
          'updates': arr(
            obj(
              {
                'id': str('Id or name of the item.'),
                'set': {'type': 'object', 'description': 'Properties to change.'},
              },
              required: ['id', 'set'],
            ),
            null,
            300,
          ),
        },
        required: ['updates'],
      ),
      args: (i) => count(i, 'updates'),
      run: (a, i) async {
        cadNotBusy(b);
        final ups = i['updates'] as List;
        final plan = <(Entity, Entity)>[];
        for (var k = 0; k < ups.length; k++) {
          final u = Map<String, dynamic>.from(ups[k] as Map);
          final e = cadEditable(b, ['${u['id']}']).first;
          final where = 'updates[$k] (${e.id})';
          final keys = extraKeys[e.type.name];
          if (keys == null) throw ToolInputError('$where: ${e.type.name} items change with update_entities.');
          final set = u['set'];
          if (set is! Map || set.isEmpty) throw ToolInputError('$where: "set" must be a non-empty object.');
          final bad = [
            for (final key in set.keys)
              if (!keys.contains(key)) key,
          ];
          if (bad.isNotEmpty) throw ToolInputError('$where: unknown properties ${bad.join(', ')}. Allowed for ${e.type.name}: ${keys.join(', ')}.');
          final j = {...e.toJson()};
          for (final en in set.entries) {
            final key = '${en.key}';
            final v = en.value;
            if (key == 'pts') {
              j[key] = [for (final q in ToolArgs.pointsOf(v, '$where.pts', min: 3)) q.toList()];
            } else if (_pointKeys.contains(key)) {
              j[key] = ToolArgs.pointOf(v, '$where.$key').toList();
            } else if (key == 'acc') {
              if (v is! Map) throw ToolInputError('$where: "acc" must be an object accessory → price.');
              final acc = <String, double>{};
              for (final x in v.entries) {
                if (!controllerAccessoryKinds.contains(x.key)) throw ToolInputError('$where: unknown accessory "${x.key}"; one of ${controllerAccessoryKinds.join(', ')}.');
                if (x.value is! num || (x.value as num) < 0) throw ToolInputError('$where: the price of "${x.key}" must be a number ≥ 0.');
                acc['${x.key}'] = (x.value as num).toDouble();
              }
              j[key] = acc;
            } else if (key == 'dia' || key == 'x' || key == 'gen') {
              if (v is! bool) throw ToolInputError('$where: "$key" must be true or false.');
              j[key] = v;
            } else if (key == 'rev' || key == 'date' || key == 'desc') {
              if (v is! String) throw ToolInputError('$where: "$key" must be a text.');
              j[key] = v;
            } else {
              if (v is! num || !v.isFinite) throw ToolInputError('$where: "$key" must be a number.');
              final d = v.toDouble();
              if ((key == 'w' || key == 'h') && d <= 0) throw ToolInputError('$where: "$key" must be above 0.');
              if (key == 'op' && (d < 0.05 || d > 1)) throw ToolInputError('$where: "op" must be 0.05 … 1.');
              if ((key == 'r' || key == 'arc') && d < 0) throw ToolInputError('$where: "$key" must be ≥ 0.');
              j[key] = d;
            }
          }
          if (j['gen'] == false) j.remove('gen');
          if (j['dia'] == false) j.remove('dia');
          final Entity ne;
          try {
            ne = Entity.fromJson(j);
          } catch (err) {
            throw ToolInputError('$where: invalid properties (${err.runtimeType}).');
          }
          plan.add((e, ne));
        }
        b.change('update_extra_properties', () {
          for (final (old, ne) in plan) {
            final idx = b.p.entities.indexWhere((x) => x.id == old.id);
            if (idx >= 0) b.p.entities[idx] = ne;
          }
          return plan.length;
        }, invalidate: plan.any((x) => x.$1 is ContourEntity));
        return ToolOutput('Updated ${plan.length} items: ${[for (final (_, e) in plan) '${e.id} (${b.kindOf(e)})'].join(', ')}.');
      },
    ),
    cadOp(
      b,
      group: 'edit',
      name: 'selection_bom',
      effectFor: (i) => i['csv'] == true ? ToolEffect.export : ToolEffect.read,
      description: 'Edit → Materials of the selection: the bill of materials of some items (a stretch of the works, a supplier\'s order) — category, description, code, unit, quantity, unit cost and total in the project currency — with the length of pipe still unsized (run the design to size it). With csv true it also saves the list as a CSV file for the user (always confirmed). get_report_table "bom" is the whole project.',
      schema: obj({'ids': idsWith('The items (default: the selection).', maxItems: 20000), 'csv': bool_('Save the list as a CSV file (default false).')}),
      args: count,
      run: (a, i) async {
        final ids = a.strings('ids');
        final set = ids.isEmpty ? {...c.selection} : {for (final e in b.findAll(ids)) e.id};
        if (set.isEmpty) throw ToolInputError('No items: give "ids" or select them first.');
        final lines = selectionBom(b.p, set);
        final unsized = unsizedPipeLength(b.p, set);
        final cur = b.p.params.currency;
        final total = lines.fold(0.0, (s, l) => s + l.total);
        String cat(String k) => t.has(k) ? t(k) : k;
        final rows = [for (final l in lines) '${cat(l.category)} | ${l.description} | ${l.code} | ${l.unit} | ${cadN(l.quantity, 2)} | ${cadN(l.unitCost, 2)} | ${cadN(l.total, 2)}'];
        if (a.flag('csv') ?? false) {
          String q(String s) => '"${s.replaceAll('"', '""')}"';
          final csv = StringBuffer(
            '﻿${[t('rep.category'), t('rep.description'), t('rep.code'), t('rep.unit'), t('rep.quantity'), '${t('rep.unitCost')} ($cur)', '${t('rep.total')} ($cur)'].map(q).join(';')}\n',
          );
          for (final l in lines) {
            csv.writeln([q(cat(l.category)), q(l.description), q(l.code), q(l.unit), cadN(l.quantity, 2), cadN(l.unitCost, 2), cadN(l.total, 2)].join(';'));
          }
          csv.writeln([q(t('rep.totalRow')), '', '', '', '', '', cadN(total, 2)].join(';'));
          await saveTextFile('${t('bomSel.file')}.csv', csv.toString(), mime: 'text/csv');
        }
        return ToolOutput(
          '${lines.isEmpty ? 'No priced material in those ${set.length} items.' : 'Materials of ${set.length} items ($cur):\ncategory | description | code | unit | quantity | unit cost | total\n${rows.join('\n')}\nTotal ${cadN(total, 2)} $cur.'}${unsized > 0 ? '\n${cadN(unsized, 1)} m of pipe has no size yet (run_design sizes it).' : ''}${a.flag('csv') ?? false ? '\nSaved ${t('bomSel.file')}.csv.' : ''}',
        );
      },
    ),
    // ------------------------------------------------ zone
    cadOp(
      b,
      group: 'zone',
      name: 'convert_to_pipe',
      effect: ToolEffect.write,
      description: 'Zone → To plain pipe: turns spray laterals and drip tapes into plain zone pipes without emitters (e.g. the blank head of a line before the crop starts), keeping geometry, name and depth; a tape becomes the smallest enabled lateral pipe whose bore holds it. One undo step; returns the new pipe ids. Other items are ignored.',
      schema: obj({'ids': idsWith('Laterals and tapes (ids or names).', maxItems: 5000)}, required: ['ids']),
      args: count,
      run: (a, i) async {
        cadNotBusy(b);
        final es = cadEditable(b, a.strings('ids', required: true)).where((e) => e is SpraylineEntity || e is TapeEntity).toList();
        if (es.isEmpty) throw ToolInputError('None of the items is a spray lateral or a tape.');
        c.select(es.map((e) => e.id));
        final n = c.convertSelectedToPipe();
        return ToolOutput('Converted $n laterals to plain pipes: ${c.selection.take(100).join(', ')}.');
      },
    ),
    cadOp(
      b,
      group: 'zone',
      name: 'insert_device_on_laterals',
      effect: ToolEffect.write,
      description: 'Zone → Device on laterals: puts one inline device (pressure regulator, on/off valve, flow regulator… from the catalogue; not a zone control valve) on each lateral and tape given, "distance_m" from its inlet (the end that touches a zone pipe), where the network splits the line. One undo step; returns the devices added.',
      schema: obj(
        {
          'ids': idsWith('Laterals and tapes.', maxItems: 5000),
          'device': str('Catalogue valve id (search_catalog kind "valve"; not control or master).'),
          'distance_m': num_('From the inlet, 0.05 m … half the lateral (default 0.3).'),
        },
        required: ['ids', 'device'],
      ),
      args: count,
      run: (a, i) async {
        cadNotBusy(b);
        final id = a.str('device', required: true)!;
        final spec = b.p.catalog.valve(id);
        if (spec == null || spec.kind == ValveKind.control || spec.kind == ValveKind.master) {
          throw ToolInputError('"$id" is not an inline device of the catalogue (search_catalog kind "valve": a PRV, isolation, check or other device).');
        }
        final es = cadEditable(b, a.strings('ids', required: true)).where((e) => e is SpraylineEntity || e is TapeEntity).toList();
        if (es.isEmpty) throw ToolInputError('None of the items is a spray lateral or a tape.');
        final before = cadIds(b);
        c.select(es.map((e) => e.id));
        final n = c.insertDeviceOnSelectedLaterals(id, distanceM: a.number('distance_m', min: 0.05, max: 1000) ?? 0.3);
        return ToolOutput('$n devices ${spec.name} placed.\n${cadMade(b, cadAdded(b, before))}');
      },
    ),
    cadOp(
      b,
      group: 'zone',
      name: 'feed_envelope',
      description: 'Zone → Feed envelope (FE): for each spray lateral or tape, the positions along it where a submain may feed it so every emitter stays in its pressure window (with the slope of the terrain), as the properties panel then shows: the best position (fraction of the length from the first vertex) with its pressure variation, and the range of positions that work. Changes nothing in the project (the result shows on the selected laterals).',
      schema: obj({'ids': idsWith('Laterals and tapes (default: the selected ones).', maxItems: 2000)}),
      args: count,
      run: (a, i) async {
        final ids = a.strings('ids');
        final es = ids.isEmpty
            ? [
                for (final e in b.p.entities)
                  if (c.selection.contains(e.id)) e,
              ]
            : b.findAll(ids);
        final lines = es.where((e) => e is SpraylineEntity || e is TapeEntity).toList();
        if (lines.isEmpty) throw ToolInputError('Give spray laterals or tapes ("ids"), or select them.');
        final n = c.computeFeedEnvelope(ids: lines.map((e) => e.id));
        final out = <String>['Feed envelope of $n of ${lines.length} laterals (fraction 0 = first vertex, 1 = last):'];
        for (final e in lines) {
          final res = c.feedEnvelope[e.id];
          if (res == null || res.isEmpty) {
            out.add('${e.id}: not computed (unknown emitter, nozzle or pipe)');
            continue;
          }
          var best = res.first;
          for (final r in res) {
            if (r.variation < best.variation) best = r;
          }
          final ok = res.where((r) => r.ok).toList();
          out.add(
            '${e.id} (${b.nameOf(e)}): best feed at ${cadN(best.fraction * 100, 0)} % (variation ${cadN(best.variation, 2)} m); ${ok.isEmpty ? 'no position keeps every emitter in its window' : 'works from ${cadN(ok.first.fraction * 100, 0)} % to ${cadN(ok.last.fraction * 100, 0)} %'}.',
          );
        }
        return ToolOutput(out.join('\n'));
      },
    ),
    cadOp(
      b,
      group: 'zone',
      name: 'fill_block',
      effect: ToolEffect.write,
      description: 'Fills a polygon with one irrigation block exactly as the Block tool and its dialog (B): parallel laterals (spray laterals with emitters, or drip tape), a submain at the start, centre or end with its stub, and the zone valve; the laterals can follow a guide line (a contour or polyline) instead of a straight direction. Every option of the dialog, with its defaults (the tool defaults of tool.*). One undo step; returns the ids. generate_block does the same with fewer options.',
      schema: obj({
        'area': str('Id or name of a closed shape to fill (or give "pts").'),
        'pts': pointsWith('The polygon instead of "area".', minItems: 3),
        'lateral': str('Default "sprayline".', ['sprayline', 'tape']),
        'lateral_spacing_m': num_('Between laterals, 0.1–200 m (default 4).'),
        'direction_deg': num_('Lateral direction, degrees counter-clockwise from east (default: the longest edge).'),
        'guide': str('Id of a line, polyline, contour or spline the laterals follow (curved laterals).'),
        'outlet': str('Sprayline: emitter id (default tool.outlet_spec).'),
        'nozzle': str('Sprayline: nozzle id (default tool.nozzle).'),
        'head_m': num_('Sprayline: emitter head, m (default tool.head_m).'),
        'emitter_spacing_m': num_('Sprayline: along the lateral, m (default tool.spacing_m).'),
        'half_spacing_offset': bool_('Sprayline: first emitter at half the spacing (default true).'),
        'lateral_pipe': str('Sprayline: lateral pipe id (default tool.lateral_pipe_spec; "auto" = sized by the design).'),
        'tape': str('Tape: tape id (default tool.tape_spec).'),
        'inlet_head_m': num_('Tape: inlet head, m (default tool.tape_inlet_head_m).'),
        'submain': str('Default "start".', ['start', 'centre', 'end']),
        'submain_pipe': str('Submain pipe id (default sized by the design).'),
        'valve': str('Zone valve id (default tool.valve_spec).'),
        'valve_position': str('Along the submain; default "centre".', ['start', 'centre', 'end']),
        'stub_m': num_('Stub between valve and submain, m (default 1.5).'),
        'zone_name': str('Default: the next free zone name.'),
      }),
      args: (i) => {'n': '${i['area'] ?? ''}'},
      run: (a, i) async {
        cadNotBusy(b);
        final poly = cadPolygon(b, a);
        final s = c.toolSettings;
        final cat = b.p.catalog;
        final tape = a.str('lateral') == 'tape';
        final tapeId = a.str('tape') ?? s.tapeSpecId;
        final outlet = a.str('outlet') ?? s.outletSpecId;
        if (tape && cat.tape(tapeId) == null) throw ToolInputError('Unknown tape "$tapeId" (search_catalog kind "tape").');
        if (!tape && cat.outlet(outlet) == null) throw ToolInputError('Unknown emitter "$outlet" (search_catalog kind "emitter").');
        final nozzle = a.str('nozzle') ?? (a.has('outlet') ? cat.outlet(outlet)?.nozzles.firstOrNull?.id : s.nozzleId);
        if (!tape && nozzle != null && exactNozzle(cat.outlet(outlet), nozzle) == null) throw ToolInputError('Emitter "$outlet" has no nozzle "$nozzle".');
        String? pipeOf(String key, String? def) {
          final v = a.str(key);
          if (v == null) return def;
          if (v == 'auto') return null;
          if (cat.pipe(v) == null) throw ToolInputError('Unknown pipe "$v" (search_catalog kind "pipe").');
          return v;
        }

        final valve = a.str('valve') ?? s.valveSpecId;
        if (cat.valve(valve) == null) throw ToolInputError('Unknown valve "$valve" (search_catalog kind "valve").');
        List<Pt>? guide;
        final g = a.str('guide');
        if (g != null) {
          final e = b.find(g);
          guide = e is SplineEntity ? e.curve() : e.linearPoints;
          if (guide == null || guide.length < 2 || e.isClosedShape && e is! SplineEntity) throw ToolInputError('"$g" is not an open line the laterals can follow.');
        }
        final before = cadIds(b);
        c.addBlock(
          BlockOptions(
            polygon: poly,
            direction: Pt.polar(1, degToRad(a.number('direction_deg') ?? longestEdgeDeg(poly))),
            guide: guide,
            lateralSpacing: a.number('lateral_spacing_m', min: 0.1, max: 200) ?? 4,
            isTape: tape,
            tapeSpecId: tapeId,
            tapeInletHeadM: a.number('inlet_head_m', min: 0.5, max: 60) ?? (a.has('tape') ? cat.tape(tapeId)?.defaultInletHeadM ?? s.tapeInletHeadM : s.tapeInletHeadM),
            outletSpecId: outlet,
            nozzleId: nozzle,
            outletSpacing: a.number('emitter_spacing_m', min: 0.05, max: 100) ?? s.spacing,
            outletOffsetHalf: a.flag('half_spacing_offset') ?? true,
            headM: a.number('head_m', min: 0.5, max: 120) ?? (a.has('nozzle') || a.has('outlet') ? cat.outlet(outlet)?.nozzle(nozzle)?.defaultHeadM ?? s.headM : s.headM),
            lateralPipeSpecId: pipeOf('lateral_pipe', s.lateralPipeSpecId),
            submainPipeSpecId: pipeOf('submain_pipe', null),
            submainPosition: SubmainPosition.values.byName(a.str('submain') ?? 'start'),
            valveSpecId: valve,
            valvePosition: ValvePosition.values.byName(a.str('valve_position') ?? 'centre'),
            submainStub: a.number('stub_m', min: 0, max: 100) ?? 1.5,
            zoneName: a.str('zone_name') ?? b.p.uniqueZoneName(t('name.zone')),
            submainLabel: t('name.submain'),
            stubLabel: t('name.stub'),
            lateralPrefix: t('name.lateral'),
          ),
        );
        final made = cadAdded(b, before);
        if (made.isEmpty) throw ToolInputError('No block fits in the polygon (check the lateral spacing and the direction).');
        return ToolOutput('${cadMade(b, made)} Results were discarded: run_design next.');
      },
    ),
    cadOp(
      b,
      group: 'zone',
      name: 'sprinkler_grid',
      effect: ToolEffect.write,
      description: 'Fills a polygon with sprinklers on a square or triangular grid, exactly as the Autohead tool and its dialog (AH): the spacing is a percentage of the wetted diameter of the nozzle at the head (10 m without a radius), heads clipped to the polygon, full circles. Returns the heads, the spacing, the precipitation rate and the expected overlap CU. layout_sprinklers does a fuller layout (part circles at the edges, zones, piping).',
      schema: obj({
        'area': str('Id or name of a closed shape (or give "pts").'),
        'pts': pointsWith('The polygon instead of "area".', minItems: 3),
        'outlet': str('Sprinkler or micro-sprinkler id (default tool.outlet_spec).'),
        'nozzle': str('Nozzle id (default: the first of the emitter, or tool.nozzle).'),
        'head_m': num_('Head, m (default: the nozzle default, or tool.head_m).'),
        'spacing_pct': num_('Spacing as % of the wetted diameter, 10–100 (default 50 = head to head).'),
        'direction_deg': num_('Row direction, degrees counter-clockwise from east (default 0).'),
        'pattern': str('Default "square".', ['square', 'triangular']),
      }),
      args: (i) => {'n': '${i['area'] ?? ''}'},
      run: (a, i) async {
        cadNotBusy(b);
        final poly = cadPolygon(b, a);
        final s = c.toolSettings;
        final cat = b.p.catalog;
        final outletId = a.str('outlet') ?? s.outletSpecId;
        final outlet = cat.outlet(outletId);
        if (outlet == null || !(outlet.kind == OutletKind.sprinkler || outlet.kind == OutletKind.microSprinkler)) {
          throw ToolInputError('"$outletId" is not a sprinkler or micro-sprinkler (search_catalog kind "emitter").');
        }
        final nozzleId = a.str('nozzle') ?? (a.has('outlet') ? outlet.nozzles.firstOrNull?.id : (exactNozzle(outlet, s.nozzleId) != null ? s.nozzleId : outlet.nozzles.firstOrNull?.id));
        final nz = exactNozzle(outlet, nozzleId);
        if (nozzleId != null && nz == null) throw ToolInputError('Emitter "$outletId" has no nozzle "$nozzleId".');
        final headM = a.number('head_m', min: 0.5, max: 120) ?? (a.has('outlet') || a.has('nozzle') ? nz?.defaultHeadM ?? s.headM : s.headM);
        final pct = a.number('spacing_pct', min: 10, max: 100) ?? 50;
        final triangular = a.str('pattern') == 'triangular';
        final radius = nz?.curve.radius(headM) ?? 0;
        final spacing = radius > 0 ? 2 * radius * pct / 100 : 10.0;
        final between = triangular ? spacing * 0.866 : spacing;
        final before = cadIds(b);
        c.addSprinklerGrid(
          SprinklerGridOptions(
            polygon: poly,
            outletSpecId: outletId,
            nozzleId: nozzleId,
            spacingAlong: spacing,
            spacingBetween: between,
            pattern: triangular ? GridPattern.triangular : GridPattern.square,
            direction: Pt.polar(1, degToRad(a.number('direction_deg') ?? 0)),
            headM: headM,
          ),
        );
        final made = cadAdded(b, before);
        if (made.isEmpty) throw ToolInputError('No head fits in the polygon at ${cadN(spacing, 1)} m spacing.');
        final rate = precipitationMmPerHour(precipitationRate(flow: nz?.curve.flow(headM) ?? 0, spacingAlong: spacing, spacingBetween: between));
        final cu = gridOverlapCU(radius: radius, spacingAlong: spacing, spacingBetween: between, triangular: triangular);
        return ToolOutput(
          '${made.length} heads ${outlet.name} at ${cadN(headM, 1)} m, radius ${cadN(radius, 1)} m, spacing ${cadN(spacing, 2)} × ${cadN(between, 2)} m, ${cadN(rate, 1)} mm/h, overlap CU ≈ ${cadN(cu, 0)} %.\n${cadMade(b, made)} Results were discarded: connect them and run_design.',
        );
      },
    ),
  ];
}
