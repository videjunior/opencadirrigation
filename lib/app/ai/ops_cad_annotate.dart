/// Annotation, user blocks and layers for the AI assistant (groups
/// "annotate", "blocks" and "layers"): dimensions of the four kinds,
/// revision clouds, the label rules in force, the block library (list,
/// save the selection, insert, delete) and the layer list. Texts, leaders,
/// comments, hatches and symbols are create_entities items.
library;

import 'dart:math' as math;

import '../../core/ai/agent_loop.dart';
import '../../core/model/blocks.dart';
import '../../core/model/entities.dart';
import '../../core/model/geometry.dart';
import '../../core/model/label_rules.dart';
import '../tools/insert_block_tool.dart' show BlockCommands;
import '../tools/tools.dart' show AngularDimensionTool, OrdinateDimensionTool;
import '../widgets/dialogs/dialogs.dart' show nextRevisionTag;
import 'agent_tools.dart';
import 'ops_cad_common.dart';

List<AgentTool> annotateOperations(AgentToolbox b) {
  final c = b.c;
  final t = b.t;
  return [
    cadOp(
      b,
      group: 'annotate',
      name: 'add_dimension',
      effect: ToolEffect.write,
      description: 'Adds dimensions as the dimension tools do (D, DAN, DRA, DOR), on the DIMENSIONS layer unless "layer" is given:\n- linear {a, b, offset_m}: the distance a–b, the dimension line offset_m to the left of a→b (default tool.dimension_offset_m); with segments_of (id of a line, polyline, pipe, lateral, area…) one dimension per segment;\n- angular {vertex, a, b, side?, radius_m}: the angle between the rays vertex→a and vertex→b counter-clockwise, or the sector holding "side";\n- radial {center, point | of + angle_deg, diameter}: radius (or diameter) from the centre to a point on the circle; "of" a circle or arc takes its centre and radius;\n- ordinate {point, leader_end, axis, origin}: the X or Y of a point from the datum (default origin [0, 0]; axis from the leader direction: mostly vertical writes X).\nOne undo step; returns the ids and the values measured.',
      schema: obj(
        {
          'kind': str(null, ['linear', 'angular', 'radial', 'ordinate']),
          'a': pointWith('linear: first point; angular: a point on the first ray.'),
          'b': pointWith('linear: second point; angular: a point on the second ray.'),
          'offset_m': num_('linear: offset of the dimension line (m, positive to the left of a→b).'),
          'segments_of': str('linear: id of an item to dimension segment by segment.'),
          'vertex': pointWith('angular: the vertex.'),
          'side': pointWith('angular: a point inside the sector to dimension.'),
          'radius_m': num_('angular: arc radius (default tool.angular_dim_radius_m).'),
          'center': pointWith('radial: the centre.'),
          'point': pointWith('radial: a point on the circle; ordinate: the feature point.'),
          'of': str('radial: id of a circle or arc.'),
          'angle_deg': num_('radial with "of": where the dimension points, degrees counter-clockwise from east (default 45).'),
          'diameter': bool_('radial: write the diameter (default tool.radial_diameter).'),
          'leader_end': pointWith('ordinate: where the text goes.'),
          'axis': str('ordinate: the coordinate written (default from the leader).', ['x', 'y']),
          'origin': pointWith('ordinate: the datum (default [0, 0]).'),
          'layer': str('Layer (default DIMENSIONS).'),
        },
        required: ['kind'],
      ),
      args: (i) => {'n': '${i['kind']}'},
      run: (a, i) async {
        cadNotBusy(b);
        final s = c.toolSettings;
        final kind = a.str('kind', required: true)!;
        final layer = a.str('layer') ?? Layers.dimensions;
        final made = <Entity>[];
        final values = <String>[];
        String id() => b.p.newId();
        // ids are taken inside the undo step, built here as templates
        final build = <Entity Function()>[];
        switch (kind) {
          case 'linear':
            final off = a.number('offset_m', min: -1e5, max: 1e5) ?? s.dimensionOffset;
            final of = a.str('segments_of');
            final segs = <(Pt, Pt)>[];
            if (of != null) {
              final e = b.find(of);
              final pts = e is SplineEntity ? null : e.linearPoints;
              if (pts == null || pts.length < 2) throw ToolInputError('"$of" has no straight segments to dimension.');
              for (var k = 1; k < pts.length + (e.isClosedShape ? 1 : 0); k++) {
                segs.add((pts[k - 1], pts[k % pts.length]));
              }
            } else {
              segs.add((a.point('a', required: true)!, a.point('b', required: true)!));
            }
            for (final (p, q) in segs) {
              if (p.distanceTo(q) < 1e-9) continue;
              build.add(() => DimensionEntity(id: id(), layer: layer, a: p, b: q, offset: off));
              values.add('${cadN(p.distanceTo(q), 3)} m');
            }
          case 'angular':
            final v = a.point('vertex', required: true)!, pa = a.point('a', required: true)!, pb = a.point('b', required: true)!;
            if (v.distanceTo(pa) < 1e-9 || v.distanceTo(pb) < 1e-9) throw ToolInputError('"a" and "b" must differ from the vertex.');
            final r = a.number('radius_m', min: 0.1, max: 1e5) ?? s.angularDimRadius;
            final side = a.point('side');
            final probe = side == null ? AngularDimensionEntity(id: '', vertex: v, a: pa, b: pb, radius: r) : AngularDimensionTool.orientedAngularDimension('', v, pa, pb, side, r);
            build.add(() => AngularDimensionEntity(id: id(), layer: layer, vertex: probe.vertex, a: probe.a, b: probe.b, radius: r));
            values.add('${cadN(probe.angleDeg, 2)}°');
          case 'radial':
            Pt center;
            Pt point;
            final of = a.str('of');
            if (of != null) {
              final e = b.find(of);
              final (cc, rr) = switch (e) {
                CircleEntity x => (x.center, x.radius),
                ArcEntity x => (x.center, x.radius),
                _ => throw ToolInputError('"$of" is not a circle or an arc.'),
              };
              center = cc;
              point = cc + Pt.polar(rr, degToRad(a.number('angle_deg') ?? 45));
            } else {
              center = a.point('center', required: true)!;
              point = a.point('point', required: true)!;
            }
            if (center.distanceTo(point) < 1e-9) throw ToolInputError('"point" must differ from the centre.');
            final dia = a.flag('diameter') ?? s.radialDiameter;
            build.add(() => RadialDimensionEntity(id: id(), layer: layer, center: center, point: point, diameter: dia));
            values.add('${dia ? 'Ø' : 'R'} ${cadN(center.distanceTo(point) * (dia ? 2 : 1), 3)} m');
          default:
            final p = a.point('point', required: true)!, end = a.point('leader_end', required: true)!;
            final axis = a.str('axis');
            final x = axis == null ? OrdinateDimensionTool.xAxisFor(p, end) : axis == 'x';
            final o = a.point('origin') ?? Pt.zero;
            build.add(() => OrdinateDimensionEntity(id: id(), layer: layer, point: p, leaderEnd: end, origin: o, xAxis: x));
            values.add('${x ? 'X' : 'Y'} = ${cadN(x ? p.x - o.x : p.y - o.y, 3)} m');
        }
        if (build.isEmpty) throw ToolInputError('Nothing to dimension.');
        b.change('add_dimension', () {
          b.p.layerNamed(layer);
          for (final f in build) {
            made.add(f());
          }
          b.p.entities.addAll(made);
          return made.length;
        }, invalidate: false);
        return ToolOutput('Added ${made.length} $kind dimension${made.length == 1 ? '' : 's'}: ${[for (var k = 0; k < made.length; k++) '${made[k].id} ${values[k]}'].take(80).join(', ')}.');
      },
    ),
    cadOp(
      b,
      group: 'annotate',
      name: 'add_revision_cloud',
      effect: ToolEffect.write,
      description: 'Draws a revision cloud around what changed, as the Revision cloud tool (RC) and its dialog: a closed outline drawn as a chain of arcs, tagged with the revision (default the next one after those drawn: A, B… or 1, 2…), today\'s date and a description; the revision table of the sheet lists them. One undo step; returns the id.',
      schema: obj(
        {
          'pts': pointsWith('Outline around the change (≥3 points, m).', minItems: 3, maxItems: 2000),
          'revision': str('Revision tag (default: the next one).'),
          'description': str('What changed.'),
          'date': str('YYYY-MM-DD (default today).'),
          'arc_length_m': num_('Chord of each arc (default 0 = from the size of the outline).'),
        },
        required: ['pts'],
      ),
      args: (i) => {'n': '${i['revision'] ?? ''}'},
      run: (a, i) async {
        cadNotBusy(b);
        final pts = a.points('pts', min: 3, max: 2000, required: true)!;
        if (polygonArea(pts).abs() < 1e-6) throw ToolInputError('The outline encloses no surface.');
        final tag = a.str('revision') ?? nextRevisionTag([for (final r in b.p.entities.whereType<RevisionCloudEntity>()) r.revision]);
        final e = b.change('add_revision_cloud', () {
          final x = RevisionCloudEntity(
            id: b.p.newId(),
            points: pts,
            revision: tag,
            date: a.str('date') ?? cadToday(),
            description: a.str('description') ?? '',
            arcLength: a.number('arc_length_m', min: 0, max: 1000) ?? 0,
          );
          b.p.layerNamed(x.layer);
          b.p.entities.add(x);
          return x;
        }, invalidate: false);
        return ToolOutput('Revision cloud ${e.id}: revision "${e.revision}", ${e.date}${e.description.isEmpty ? '' : ', "${AgentToolbox.short(e.description, 80)}"'}.');
      },
    ),
    cadOp(
      b,
      group: 'annotate',
      name: 'get_label_rules',
      description: 'The conditional label rules in force (View → Conditional labels): which results label the pipes, outlets or valves, when, and in which colour, values in SI (m/s, m³/s, m of head, m). set_label_rules replaces them.',
      schema: obj({}),
      run: (a, i) async {
        final rules = b.p.labelRules;
        if (rules.isEmpty) return const ToolOutput('No label rule.');
        return ToolOutput(
          '${rules.length} rules:\n${[for (final r in rules) '${r.enabled ? '' : '(off) '}${r.target}.${r.field} ${r.op}${r.op == 'any' ? '' : ' ${showSi(r.value)}'} → #${(r.color & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}'].join('\n')}\nFields by target: ${[for (final x in LabelRule.targets) '$x: ${LabelRule.fieldsOf(x).join(', ')}'].join('; ')}.',
        );
      },
    ),
    // ------------------------------------------------ blocks
    cadOp(
      b,
      group: 'blocks',
      name: 'list_blocks',
      description: 'The project\'s block library (Edit → Insert block): name, description, items and size of each block (block coordinates: the base point at [0, 0]).',
      schema: obj({}),
      run: (a, i) async {
        final lib = b.p.blocks;
        if (lib.isEmpty) return const ToolOutput('The project has no block yet (save_block makes one from items).');
        return ToolOutput(
          '${lib.blocks.length} blocks:\n${[for (final x in lib.blocks) '"${x.name}"${x.description.isEmpty ? '' : ' — ${x.description}'}: ${x.entities.length} items, extent ${AgentToolbox.box(x.bounds)}'].join('\n')}',
        );
      },
    ),
    cadOp(
      b,
      group: 'blocks',
      name: 'save_block',
      effect: ToolEffect.write,
      description: 'Edit → Save selection as block (WBLOCK): keeps copies of the items as a named block of the project (a valve box, a manifold, a standard detail) with its base point at the bottom-left corner of the items, their centre, or a point given; a block of that name is replaced. The drawing keeps its items. One undo step.',
      schema: obj({
        'name': str('Block name (default: the next free "Block n").'),
        'ids': idsWith('Items of the block (default: the selection).', maxItems: 5000),
        'description': str(),
        'base': str('Base point: "corner" (default), "center" or "point".', ['corner', 'center', 'point']),
        'base_point': pointWith('With base "point": the base point (m).'),
      }),
      args: (i) => {'n': '${i['name'] ?? ''}'},
      binder: (i) => cadBindDefaultIds(b, i),
      run: (a, i) async {
        cadNotBusy(b);
        final ids = a.strings('ids');
        final es = ids.isEmpty
            ? [
                for (final e in b.p.entities)
                  if (c.selection.contains(e.id)) e,
              ]
            : b.findAll(ids);
        if (es.isEmpty) throw ToolInputError('No items: give "ids" or select them first.');
        final lib = b.p.blocks;
        final name = a.str('name') ?? lib.uniqueName(t('blk.default'));
        final bx = es.fold(Bounds.empty, (Bounds x, e) => x.union(e.bounds));
        final at = switch (a.str('base') ?? 'corner') {
          'center' => bx.center,
          'point' => a.point('base_point', required: true)!,
          _ => Pt(bx.minX, bx.minY),
        };
        final replaced = lib.byName(name) != null;
        if (!c.saveBlock(lib, BlockDefinition.fromEntities(name, es, at, description: a.str('description') ?? '', project: b.p))) {
          throw ToolInputError('The block was not saved (a design is running).');
        }
        return ToolOutput('${replaced ? 'Replaced' : 'Saved'} block "$name": ${es.length} items, base point ${cadPt(at)}.');
      },
    ),
    cadOp(
      b,
      group: 'blocks',
      name: 'insert_block',
      effect: ToolEffect.write,
      description: 'Edit → Insert block (INSERT, IB) at a typed point: copies of block "name" with its base point at "at" (or at each of "points"), turned rotation_deg counter-clockwise and scaled; missing layers and catalogue items come with it. One undo step per insertion; returns the new ids (they become the selection).',
      schema: obj(
        {
          'name': str('Block name (list_blocks).'),
          'at': pointWith('Insertion point (m).'),
          'points': pointsWith('Several insertion points instead of "at".', maxItems: 500),
          'rotation_deg': num_('Default 0.'),
          'scale': num_('0.001–1000 (default 1).'),
        },
        required: ['name'],
      ),
      args: (i) => {'n': '${i['name']}'},
      run: (a, i) async {
        cadNotBusy(b);
        final name = a.str('name', required: true)!;
        final blk = b.p.blocks.byName(name);
        if (blk == null) throw ToolInputError('No block "$name". Blocks: ${b.p.blocks.blocks.map((x) => x.name).join(', ')}.');
        final at = [?a.point('at'), ...?a.points('points', max: 500)];
        if (at.isEmpty) throw ToolInputError('Give "at" (or "points").');
        final rot = a.number('rotation_deg') ?? 0;
        final sc = a.number('scale', min: 0.001, max: 1000) ?? 1;
        final ids = <String>[];
        for (final p in at) {
          ids.addAll(c.insertBlock(blk, p, rotationDeg: rot, scale: sc));
        }
        if (ids.isEmpty) throw ToolInputError('Nothing inserted (an empty block, or a design is running).');
        return ToolOutput('Inserted "$name" ${at.length} time${at.length == 1 ? '' : 's'}.\n${cadMade(b, ids)}');
      },
    ),
    cadOp(
      b,
      group: 'blocks',
      name: 'delete_block',
      effect: ToolEffect.write,
      description: 'Removes block "name" from the project\'s library (the insert dialog\'s delete); copies already in the drawing stay. One undo step.',
      schema: obj({'name': str('Block name.')}, required: ['name']),
      args: (i) => {'n': '${i['name']}'},
      run: (a, i) async {
        cadNotBusy(b);
        final name = a.str('name', required: true)!;
        if (!c.deleteBlock(b.p.blocks, name)) throw ToolInputError('No block "$name".');
        return ToolOutput('Block "$name" deleted.');
      },
    ),
    // ------------------------------------------------ layers
    cadOp(
      b,
      group: 'layers',
      name: 'list_layers',
      description: 'The layers panel: every layer with its name, colour, visibility, lock, item count and which one is current (new drawing items go there). edit_layers changes them; update_entities moves items to another layer ("layer").',
      schema: obj({}),
      run: (a, i) async {
        final counts = <String, int>{};
        for (final e in b.p.entities) {
          counts[e.layer] = (counts[e.layer] ?? 0) + 1;
        }
        return ToolOutput(
          '${b.p.layers.length} layers (current: ${b.p.currentLayer}):\nname | colour | visible | locked | items | built-in\n${[for (final l in b.p.layers) '${l.name}${t.has('layer.${l.name}') ? ' (${t('layer.${l.name}')})' : ''} | #${(l.color & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()} | ${l.visible} | ${l.locked} | ${counts[l.name] ?? 0} | ${Layers.all.contains(l.name)}'].join('\n')}',
        );
      },
    ),
  ];
}

/// An SI value for the model.
String showSi(double v) => v.abs() >= 1000 || v == v.roundToDouble() ? cadN(v, 0) : cadN(v, math.max(2, 4 - '${v.abs().floor()}'.length));
