/// Operations (find_operations / run_operation) added in 1.6.0 for the model, catalogues and command line:
/// [OpTool]s built like those of lib/app/ai/ops_cad_*.dart and ops_eng_*.dart,
/// joined to [AgentToolbox.operations].
library;

import '../../../core/ai/agent_loop.dart';
import '../../../core/model/area_holes.dart';
import '../../../core/model/entities.dart';
import '../../../core/model/geometry.dart';
import '../agent_tools.dart';
import '../ops_cad_common.dart';
import '../ops_cad_edit.dart' show cadPolygon;

List<AgentTool> opsMod(AgentToolbox b) => [..._areaHoleOps(b)];

/// The islands of irrigated areas (AUT-29): Edit → Geometry → Subtract from
/// area, and the islands set or removed.
List<AgentTool> _areaHoleOps(AgentToolbox b) {
  String ha(double m2) => cadN(m2 / 1e4, 4);
  String describe(AreaEntity a) =>
      '${a.id} «${b.nameOf(a)}»: ${ha(a.area)} ha irrigated${a.holes.isEmpty ? '' : ' of ${ha(a.grossArea)} ha inside the outline, ${a.holes.length} island(s)'}, ${a.points.length} vertices';
  return [
    cadOp(
      b,
      group: 'edit',
      name: 'subtract_from_area',
      effect: ToolEffect.write,
      description:
          'Edit → Geometry → Subtract from area: takes a closed shape out of irrigated areas, as the menu command does. A shape inside an area becomes an island of it (a pond, a building, a bed of other plants: not irrigated, left out of its surface, of the water it needs, of the uniformity check and of the automatic layout); one across the outline cuts a notch; one across the whole area splits it in pieces (the first keeps the id and the properties, the others copy them); islands that overlap merge. "shape": id or name of a closed polyline, circle, closed spline, hatch, revision cloud or another area; or "pts", the polygon. "area": the area to cut (default: every area the shape meets). The shape item is deleted (its outline is the island now) unless "keep_shape" is true or it is an area. One undo step; returns the areas with their irrigated surface.',
      schema: obj({
        'shape': str('Id or name of the closed shape to take out.'),
        'pts': pointsWith('The polygon to take out (instead of "shape"), at least 3 points.'),
        'area': str('Id or name of the area to cut; default: every area the shape meets.'),
        'keep_shape': bool_('Keep the shape item in the drawing (default false).'),
      }),
      args: (i) => {'n': '${i['shape'] ?? 'polygon'}'},
      run: (a, i) async {
        cadNotBusy(b);
        final cut = cadPolygon(b, a, areaKey: 'shape', ptsKey: 'pts');
        final shapeRef = a.str('shape');
        final shape = shapeRef == null ? null : b.find(shapeRef);
        final areaRef = a.str('area');
        final List<AreaEntity> targets;
        if (areaRef != null) {
          final e = b.find(areaRef);
          if (e is! AreaEntity) throw ToolInputError('"$areaRef" is a ${b.kindOf(e)}, not an irrigated area.');
          targets = [e];
        } else {
          final box = Bounds.ofPoints(cut);
          targets = [
            for (final e in b.p.entities)
              if (e is AreaEntity && !identical(e, shape) && box.intersects(e.bounds)) e,
          ];
        }
        if (targets.isEmpty) throw ToolInputError('No irrigated area meets the shape.');
        final locked = [
          for (final x in targets)
            if (b.p.isLocked(x.layer)) x.id,
        ];
        if (locked.isNotEmpty) throw ToolInputError('Areas on locked layers: ${locked.join(', ')}. Unlock the layer first (edit_layers action "unlock").');
        if (!targets.any((x) => subtractFromArea(x, cut, () => 'probe') != null)) {
          throw ToolInputError('The shape does not cut ${targets.length == 1 ? 'the area' : 'any of the ${targets.length} areas'} (it lies outside, or inside an island already): nothing to do.');
        }
        final shapeId = shape?.id;
        final removeShape = shape != null && shape is! AreaEntity && !(a.flag('keep_shape') ?? false) && !b.p.isLocked(shape.layer);
        final done = b.change('subtract_from_area', () {
          final r = subtractFromAreas(b.p, targets, [cut]);
          if (removeShape) b.p.entities.removeWhere((e) => e.id == shapeId);
          return r;
        });
        final lines = [
          for (final id in done.changed)
            if (b.p.byId(id) case final AreaEntity x) describe(x),
        ];
        final whole = done.removed.isEmpty ? '' : '; taken whole: ${done.removed.join(', ')}';
        final gone = removeShape ? '; the shape $shapeId was deleted' : '';
        return ToolOutput('${done.changed.length} area(s) after the cut$whole$gone:\n${lines.join('\n')}');
      },
    ),
    cadOp(
      b,
      group: 'edit',
      name: 'set_area_holes',
      effect: ToolEffect.write,
      description:
          'Sets the islands of an irrigated area: closed polygons inside its outline that are not irrigated (a pond, a building, a bed), left out of its surface, of the water it needs, of the uniformity check and of the automatic layout. "holes": the polygons [[[x, y], …], …] (each of at least 3 points, inside the outline), replacing the islands it has; [] removes them all (Edit → Geometry → Remove the islands of the area). To cut a drawn shape out of an area (also across its outline) use subtract_from_area. One undo step.',
      schema: obj({
        'area': str('Id or name of the area.'),
        'holes': arr(points, 'The islands, each a polygon [[x, y], …] of at least 3 points; [] removes them.', 200),
      }, required: ['area', 'holes']),
      args: (i) => {'n': '${i['area']}'},
      run: (a, i) async {
        cadNotBusy(b);
        final ref = a.str('area', required: true)!;
        final e = cadEditable(b, [ref]).single;
        if (e is! AreaEntity) throw ToolInputError('"$ref" is a ${b.kindOf(e)}, not an irrigated area.');
        final raw = i['holes'];
        if (raw is! List) throw ToolInputError('"holes" must be a list of polygons [[[x, y], …], …].');
        if (raw.length > 200) throw ToolInputError('At most 200 islands.');
        final holes = <List<Pt>>[];
        for (var k = 0; k < raw.length; k++) {
          final h = ToolArgs.pointsOf(raw[k], '"holes[$k]"', min: 3);
          if (polygonArea(h).abs() < 1e-6) throw ToolInputError('"holes[$k]" encloses no surface.');
          if (!h.every((q) => pointInPolygon(q, e.points))) throw ToolInputError('"holes[$k]" is not inside the outline of ${e.id}: cut a notch with subtract_from_area instead.');
          holes.add(h);
        }
        b.change('set_area_holes', () {
          e.holes = holes;
          return holes.length;
        });
        return ToolOutput('${describe(e)}.');
      },
    ),
  ];
}
