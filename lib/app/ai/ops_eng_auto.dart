/// Engineering operations of the automatic design dialogs (Design → Auto
/// design) with the options the short tools (layout_sprinklers,
/// sports_template, subdivide_field, tree_rings, fit_pivot) leave at their
/// defaults: the advanced layout rules, the connection of the routing, the
/// catalogue items of the generated blocks and rings, the template
/// dimensions and the spans of the pivot. Same engine calls as
/// the dialogs; each generation is one undo step.
library;

import 'dart:math' as math;

import '../../core/api.dart';
import 'agent_tools.dart';
import 'agent_tools_design.dart' show outlineOf, pivotFitHelp, pivotObstacleShapes, zoneFlowDefault, zoneNames;
import 'ops_eng_common.dart';

List<Pt> _outline(AgentToolbox b, String ref) {
  final o = outlineOf(b.find(ref));
  if (o == null) throw ToolInputError('"$ref" is not a closed shape (use an area, a closed polyline, a circle or a pivot).');
  return o;
}

String _made(AgentToolbox b, List<Entity> made) {
  final counts = <String, int>{};
  for (final e in made) {
    final k = b.kindOf(e);
    counts[k] = (counts[k] ?? 0) + 1;
  }
  final ids = made.map((e) => e.id).toList();
  return 'Added ${made.length} items (${[for (final e in counts.entries) '${e.value} × ${e.key}'].join(', ')}); ids ${ids.take(60).join(', ')}${ids.length > 60 ? '…' : ''}. Results were discarded: run_design next.';
}

/// The sprinkler family [id], else the turf rotor, else the first.
OutletSpec _family(AgentToolbox b, String? id) {
  final fams = [
    for (final o in b.p.catalog.outlets)
      if (o.enabled && o.nozzles.isNotEmpty && (o.kind == OutletKind.sprinkler || o.kind == OutletKind.microSprinkler)) o,
  ];
  if (fams.isEmpty) throw ToolInputError('The catalogue has no enabled sprinkler or micro-sprinkler. ${catalogNextStep('emitter')}');
  if (id != null) return fams.where((o) => o.id == id).firstOrNull ?? (throw ToolInputError('"$id" is not an enabled sprinkler. Choose one of: ${fams.map((o) => o.id).join(', ')}.'));
  final last = b.p.catalog.outlet(b.c.toolSettings.outletSpecId);
  if (last != null && last.kind == OutletKind.sprinkler && fams.contains(last)) return last;
  return fams.where((f) => f.id == 'rotor').firstOrNull ?? fams.first;
}

/// The point of connection named by [ref] (a water supply or a pump), the
/// first supply when null; a mainline pipe gives its points instead.
(Pt?, List<Pt>?) _connection(AgentToolbox b, String? ref) {
  if (ref == null) {
    for (final e in b.p.entities) {
      if (e is WaterSupplyEntity) return (e.position, null);
      if (e is PumpEntity && e.scope == HydraulicScope.mainline) return (e.position, null);
    }
    return (null, null);
  }
  if (ref == 'none') return (null, null);
  final e = b.find(ref);
  return switch (e) {
    WaterSupplyEntity x => (x.position, null),
    PumpEntity x => (x.position, null),
    PipeEntity x when x.scope == HydraulicScope.mainline && x.points.length >= 2 => (null, List<Pt>.of(x.points)),
    _ => throw ToolInputError('"$ref" is not a water supply, a pump or a mainline pipe.'),
  };
}

Pt? _dir(ToolArgs a) => a.has('direction_deg') ? Pt.polar(1, degToRad(a.number('direction_deg')!)) : null;

String _codes(AgentToolbox b, Iterable<String> codes) => engCodes(b, [for (final w in codes) w.split(':').first]);

List<AgentTool> autoDesignOperations(AgentToolbox b) {
  final c = b.c;
  final t = b.t;
  return [
    // ---------------------------------------------------------------- automatic layout
    engOp(
      b,
      name: 'layout_sprinklers_advanced',
      effect: ToolEffect.write,
      description: 'Design → Auto design → Automatic layout with every option of the dialog (layout_sprinklers is the short version): sprinkler heads over a closed area on a square or triangular grid with part circles at edges and corners, the advanced placement rules, the zoning by flow (and heads per zone) and the routing of valves, zone pipes and mainline to a chosen connection with the valves at the zones or in a manifold. One undo step. Inputs (SI): area (closed shape id), exclusions (closed shape ids inside to leave dry), outlet (sprinkler family id), nozzle (reference nozzle, full circle), head_m, pattern, spacing head_to_head|percent_of_diameter|fixed, spacing_percent 20–100, spacing_m, direction_deg (row direction; default the longest edge), part_circles auto|always|never; advanced: corner_angle_deg 1–179 (25: sharper corners get a corner head), min_corner_arc_deg 0–180 (45), min_spacing_pct (40 % of the spacing: closest two heads), narrow_strip_pct (60), edge_clearance_pct (50), coverage_pct (0 = automatic), row_stretch_pct (12), small_exclusion_factor (3), min_radius_pct (90: least throw of a part circle against the reference), relax_iterations 0–20 (4), profile triangular|elliptical|uniform (for the uniformity figures); zoning, max_zone_flow_m3h, heads_per_zone (0 = no limit); routing, connection (supply, pump or mainline pipe id; "none"; default the first supply), placement nearZone|manifold. Output: heads, spacing, flow, CU/DU, zones, routing lengths, the new ids and the messages.',
      schema: obj(
        {
          'area': str('Closed shape id.'),
          'exclusions': arr(str(), 'Closed shapes inside to leave dry.'),
          'outlet': str('Sprinkler family id.'),
          'nozzle': str('Reference nozzle id (full circle).'),
          'head_m': num_('Operating head, 0–120 m; 0 = the family default.'),
          'pattern': str(null, ['square', 'triangular']),
          'spacing': str(null, ['head_to_head', 'percent_of_diameter', 'fixed']),
          'spacing_percent': num_('20–100 % of the throw diameter.'),
          'spacing_m': num_('Fixed spacing, 0.5–100 m.'),
          'direction_deg': num_('Row direction, degrees counter-clockwise from east.'),
          'part_circles': str(null, ['auto', 'always', 'never']),
          'corner_angle_deg': num_('1–179°.'),
          'min_corner_arc_deg': num_('0–180°.'),
          'min_spacing_pct': num_('0–100 %.'),
          'narrow_strip_pct': num_('0–100 %.'),
          'edge_clearance_pct': num_('0–100 %.'),
          'coverage_pct': num_('0–100 %; 0 = automatic.'),
          'row_stretch_pct': num_('0–100 %.'),
          'small_exclusion_factor': num_('0–20.'),
          'min_radius_pct': num_('0–100 %.'),
          'relax_iterations': int_('0–20.'),
          'profile': str(null, [for (final x in SprayProfile.values) x.name]),
          'zoning': bool_('Group the heads into zones by flow.'),
          'max_zone_flow_m3h': num_('Zone flow limit, m³/h; default the supply / largest valve.'),
          'heads_per_zone': int_('Most heads per zone, 0 = no limit.'),
          'routing': bool_('Add zone valves, pipes and a mainline.'),
          'connection': str('Water supply, pump or mainline pipe id; "none".'),
          'placement': str(null, [for (final x in ValvePlacement.values) x.name]),
        },
        required: ['area'],
      ),
      summary: (i) => t('ai.op.layout_sprinklers_advanced', {'n': '${i['area']}'}),
      run: (a, _) async {
        engNotBusy(c);
        final area = _outline(b, a.str('area', required: true)!);
        final ex = [for (final id in a.strings('exclusions')) _outline(b, id)];
        final family = _family(b, a.str('outlet'));
        double pct(String k, double def) => (a.number(k, min: 0, max: 100) ?? def * 100) / 100;
        final coverage = a.number('coverage_pct', min: 0, max: 100) ?? 0;
        final o = LandscapeLayoutOptions()
          ..headM = a.number('head_m', min: 0, max: 120) ?? 0
          ..referenceNozzleId = a.str('nozzle')
          ..pattern = (a.str('pattern') ?? 'square') == 'triangular' ? GridPattern.triangular : GridPattern.square
          ..spacingRule = switch (a.str('spacing')) {
            'percent_of_diameter' => SpacingRule.percentOfDiameter,
            'fixed' => SpacingRule.fixed,
            _ => SpacingRule.headToHead,
          }
          ..spacingPercent = a.number('spacing_percent', min: 20, max: 100) ?? 50
          ..spacingM = a.number('spacing_m', min: 0.5, max: 100) ?? 0
          ..direction = _dir(a)
          ..partCircles = PartCircleMode.values.byName(a.str('part_circles') ?? 'auto')
          ..cornerAngleDeg = a.number('corner_angle_deg', min: 1, max: 179) ?? 25
          ..minCornerArcDeg = a.number('min_corner_arc_deg', min: 0, max: 180) ?? 45
          ..minSpacingFraction = pct('min_spacing_pct', 0.4)
          ..narrowStripFraction = pct('narrow_strip_pct', 0.6)
          ..edgeClearanceFraction = pct('edge_clearance_pct', 0.5)
          ..coverageFraction = coverage > 0 ? coverage / 100 : null
          ..rowStretchFraction = pct('row_stretch_pct', 0.12)
          ..smallExclusionFactor = a.number('small_exclusion_factor', min: 0, max: 20) ?? 3
          ..minRadiusRatio = pct('min_radius_pct', 0.9)
          ..relaxIterations = a.integer('relax_iterations', min: 0, max: 20) ?? 4
          ..profile = SprayProfile.values.byName(a.str('profile') ?? 'triangular');
        if (o.spacingRule == SpacingRule.fixed && o.spacingM <= 0) throw ToolInputError('"spacing_m" is needed with the fixed rule.');
        if (o.referenceNozzleId != null && family.nozzle(o.referenceNozzleId) == null) throw ToolInputError('Family "${family.id}" has no nozzle "${o.referenceNozzleId}".');
        final layout = await engSoon(() => layoutLandscape(outline: area, exclusions: ex, family: family, options: o));
        if (layout.heads.isEmpty) throw ToolInputError('No head fits.${_codes(b, layout.messages)}');
        final zoning = (a.flag('zoning') ?? false)
            ? zoneByFlow(
                zoneItemsOf(layout, family),
                ZoningOptions(
                  maxZoneFlow: (a.number('max_zone_flow_m3h', min: 0.01, max: 1e5) ?? zoneFlowDefault(b.p) / m3sPerM3h) * m3sPerM3h,
                  maxItemsPerZone: a.integer('heads_per_zone', min: 0, max: 10000) ?? 0,
                ),
              )
            : null;
        final routeOn = a.flag('routing') ?? false;
        final groups = zoning != null ? [for (final z in zoning.zones) z.items] : [if (routeOn) List<int>.generate(layout.heads.length, (k) => k)];
        final names = zoneNames(b.p, t('name.zone'), groups.length);
        final (poc, mainline) = _connection(b, a.str('connection'));
        final routing = routeOn && groups.isNotEmpty
            ? routeZones([
                for (final g in groups) [for (final k in g) layout.heads[k].position],
              ], RouteOptions(exclusions: ex, mainline: mainline, pointOfConnection: poc, placement: ValvePlacement.values.byName(a.str('placement') ?? 'nearZone'), direction: layout.direction))
            : null;
        final zoneOf = <int, int>{
          for (var z = 0; z < groups.length; z++)
            for (final k in groups[z]) k: z,
        };
        double flowOf(int z) => groups[z].fold(0.0, (s, k) => s + layout.heads[k].flow);
        final made = b.change('layout_sprinklers_advanced', () {
          final p = b.p;
          final out = <Entity>[
            ...layout.toOutlets(p, zoneName: groups.isEmpty ? null : (k) => names[zoneOf[k] ?? 0]),
            ...?routing?.toEntities(p, zoneNames: names, valveSpecIds: [for (var z = 0; z < groups.length; z++) pickZoneValve(p.catalog, flowOf(z))?.id]),
          ];
          p.entities.addAll(out);
          return out;
        });
        c.select(made.map((e) => e.id));
        final m = layout.metrics;
        return ToolOutput(
          '${layout.heads.length} heads of ${family.id} at ${engN(layout.headM, 1)} m, spacing ${engN(layout.spacing, 2)} × ${engN(layout.rowSpacing, 2)} m, total ${engQ(layout.totalFlow)}, gross rate ${engN(layout.grossRateMmH, 1)} mm/h${m == null ? '' : ', CU ${engN(m.cu, 1)} %, DU ${engN(m.du, 1)} %, dry ${engN(m.dryPct, 1)} %, overspray ${engN(m.oversprayPct, 1)} %'}.${zoning == null ? '' : ' ${zoning.zones.length} zones (${engQ(zoning.minFlow)}–${engQ(zoning.maxFlow)}).'}${routing == null ? '' : ' Routing: zone pipes ${engN(routing.zonePipeLength, 0)} m, mainline ${engN(routing.mainlineLength, 0)} m, ${routing.crossings} crossings.'}\n${_made(b, made)}${_codes(b, [...layout.messages, ...?zoning?.messages, ...?routing?.messages])}',
        );
      },
    ),
    // ---------------------------------------------------------------- templates
    engOp(
      b,
      name: 'sports_template_advanced',
      effect: ToolEffect.write,
      description: 'Design → Auto design → Templates with every option of the dialog (sports_template is the short version): a football pitch (rows of heads across, 0 = automatic), a running-track infield (straight length and bend radius), a golf green (an ellipse or a closed shape, with the setback of the heads and the arc margin of the part circles), a tee, or a fairway (straight, or along a line of the drawing, with part circles on the edges). Adds the heads and the turf area (one undo step). Inputs: kind pitch|track|green|tee|fairway, center [x, y] (default the view centre), rotation_deg, outlet (sprinkler family), nozzle (reference nozzle), head_m, length_m / width_m (pitch 105 × 68, green 30 × 22, tee 30 × 8, fairway 300 × 35), rows (pitch), straight_m (84.39) and bend_radius_m (36.5) (track), area (green: a closed shape), setback_m (1.5) and arc_margin_deg 0–90 (15) (green), line (fairway: a line id as centreline), edge_part_circles (fairway). Output: heads, uniformity, flow, the new ids and the messages.',
      schema: obj(
        {
          'kind': str(null, ['pitch', 'track', 'green', 'tee', 'fairway']),
          'center': point,
          'rotation_deg': num_('Rotation, degrees counter-clockwise; default 0.'),
          'outlet': str('Sprinkler family id.'),
          'nozzle': str('Reference nozzle id.'),
          'head_m': num_('0–120 m; 0 = the family default.'),
          'length_m': num_('1–2000 m.'),
          'width_m': num_('1–2000 m.'),
          'rows': int_('Pitch: rows of heads across, 2–50; 0 = automatic.'),
          'straight_m': num_('Track: straight length, 10–500 m.'),
          'bend_radius_m': num_('Track: bend radius, 5–200 m.'),
          'area': str('Green: closed shape id.'),
          'setback_m': num_('Green: heads set back from the edge, 0–20 m.'),
          'arc_margin_deg': num_('Green: arc margin of the part circles, 0–90°.'),
          'line': str('Fairway: id of a line, polyline or spline as the centreline.'),
          'edge_part_circles': bool_('Fairway: part circles on the edges.'),
        },
        required: ['kind'],
      ),
      summary: (i) => t('ai.op.sports_template_advanced', {'n': '${i['kind']}'}),
      run: (a, _) async {
        engNotBusy(c);
        final kind = a.str('kind', required: true)!;
        final family = _family(b, a.str('outlet'));
        final nozzle = a.str('nozzle');
        if (nozzle != null && family.nozzle(nozzle) == null) throw ToolInputError('Family "${family.id}" has no nozzle "$nozzle".');
        final centre = a.point('center') ?? (c.camera.size.isEmpty ? (b.p.bounds.isEmpty ? Pt.zero : b.p.bounds.center) : c.camera.center);
        final rot = a.number('rotation_deg', min: -3600, max: 3600) ?? 0;
        final headM = a.number('head_m', min: 0, max: 120) ?? 0;
        double len(double d) => a.number('length_m', min: 1, max: 2000) ?? d;
        double wid(double d) => a.number('width_m', min: 1, max: 2000) ?? d;
        final opts = LandscapeLayoutOptions(headM: headM, referenceNozzleId: nozzle);
        final green = a.has('area') ? _outline(b, a.str('area')!) : null;
        List<Pt>? line;
        if (a.has('line')) {
          final e = b.find(a.str('line')!);
          final pts = e is SplineEntity ? e.curve() : e.linearPoints;
          if (pts == null || pts.length < 2) throw ToolInputError('"${a.str('line')}" is not a line.');
          line = List.of(pts);
        }
        final rows = a.integer('rows', min: 0, max: 50) ?? 0;
        final l = await engSoon(
          () => switch (kind) {
            'pitch' => sportsPitchLayout(
              family: family,
              length: len(105),
              width: wid(68),
              rows: rows == 1 ? 2 : rows,
              origin: centre - Pt(len(105) / 2, wid(68) / 2).rotate(degToRad(rot)),
              rotationDeg: rot,
              headM: headM,
              nozzleId: nozzle,
            ),
            'track' => runningTrackInfieldLayout(
              family: family,
              straight: a.number('straight_m', min: 10, max: 500) ?? 84.39,
              radius: a.number('bend_radius_m', min: 5, max: 200) ?? 36.5,
              center: centre,
              rotationDeg: rot,
              options: opts,
            ),
            'green' => golfGreenLayout(
              family: family,
              green: green ?? ellipseOutline(centre, len(30), wid(22), rotationDeg: rot),
              setback: a.number('setback_m', min: 0, max: 20) ?? 1.5,
              headM: headM,
              nozzleId: nozzle,
              arcMarginDeg: a.number('arc_margin_deg', min: 0, max: 90) ?? 15,
            ),
            'tee' => teeLayout(family: family, length: len(30), width: wid(8), center: centre, rotationDeg: rot, options: opts),
            _ => fairwayLayout(
              family: family,
              centreline: line ?? [centre - Pt.polar(len(300) / 2, degToRad(rot)), centre + Pt.polar(len(300) / 2, degToRad(rot))],
              width: wid(35),
              headM: headM,
              nozzleId: nozzle,
              edgePartCircles: a.flag('edge_part_circles') ?? false,
            ),
          },
        );
        if (l.heads.isEmpty) throw ToolInputError('No head fits.${_codes(b, l.messages)}');
        final hasArea = kind == 'green' && a.has('area') && b.find(a.str('area')!) is AreaEntity;
        final made = b.change('sports_template_advanced', () {
          final p = b.p;
          final out = <Entity>[...l.toOutlets(p), if (!hasArea && l.region.outline.length >= 3) AreaEntity(id: p.newId(), points: List.of(l.region.outline), name: t('tpl.$kind'))];
          p.entities.addAll(out);
          return out;
        });
        c.select(made.map((e) => e.id));
        final m = l.metrics;
        return ToolOutput(
          '${l.heads.length} heads over ${engN(l.region.area, 0)} m²${m == null ? '' : ', CU ${engN(m.cu, 1)} %, DU ${engN(m.du, 1)} %'}, total ${engQ(l.totalFlow)}.\n${_made(b, made)}${_codes(b, l.messages)}',
        );
      },
    ),
    // ---------------------------------------------------------------- field subdivision
    engOp(
      b,
      name: 'subdivide_field_advanced',
      effect: ToolEffect.write,
      description: 'Design → Auto design → Field blocks with every option of the dialog (subdivide_field is the short version): cuts a field into blocks (strips along the rows, or a grid that also limits the lateral length) by area or by the flow a block may draw, with roads and a least block width, and fills every block with laterals (drip tape, or emitters on a lateral pipe), a submain (chosen pipe or sized by the design) with its stub, and the zone valve (chosen, or picked by flow); on demand a mainline from the connection to the valves. One undo step. Inputs: area (field id), mode strips|grid, max_block_area_m2 (20000) or max_block_flow_m3h, max_lateral_length_m (0 = none), road_width_m (4), min_block_width_m (10), centre_feed, direction_deg; lateral tape|sprayline, lateral_spacing_m (1.5 / 12), tape, inlet_head_m, outlet, nozzle, head_m, emitter_spacing_m, lateral_pipe (sprayline; default sized), submain_pipe (default sized), valve (default picked by flow), stub_m (1.5), connection (supply or pump id; default the first; "none"), mainline. Output: the blocks with area and flow, the new ids and the messages.',
      schema: obj(
        {
          'area': str('Field id.'),
          'mode': str(null, ['strips', 'grid']),
          'max_block_area_m2': num_('100–1e7 m²; default 20000.'),
          'max_block_flow_m3h': num_('Limit by flow instead, m³/h.'),
          'max_lateral_length_m': num_('Grid mode: longest lateral, 10–2000 m; 0 = none.'),
          'road_width_m': num_('0–50 m; default 4.'),
          'min_block_width_m': num_('2–500 m; default 10.'),
          'centre_feed': bool_('Submains across the middle, laterals both ways.'),
          'direction_deg': num_('Row direction; default the longest edge.'),
          'lateral': str(null, ['tape', 'sprayline']),
          'lateral_spacing_m': num_('0.1–100 m.'),
          'tape': str('Tape id.'),
          'inlet_head_m': num_('Tape inlet head, 0.5–60 m.'),
          'outlet': str('Emitter id (sprayline).'),
          'nozzle': str('Nozzle id of that emitter; default its first.'),
          'head_m': num_('Emitter head, 0.5–120 m.'),
          'emitter_spacing_m': num_('0.05–50 m.'),
          'lateral_pipe': str('Lateral pipe id (sprayline); default sized by the design.'),
          'submain_pipe': str('Submain pipe id; default sized by the design.'),
          'valve': str('Zone valve id; default picked by the block flow.'),
          'stub_m': num_('Stub from the submain to the valve, 0–50 m; default 1.5.'),
          'connection': str('Water supply or pump id; "none".'),
          'mainline': bool_('Route a mainline from the connection to the valves.'),
        },
        required: ['area'],
      ),
      summary: (i) => t('ai.op.subdivide_field_advanced', {'n': '${i['area']}'}),
      run: (a, _) async {
        engNotBusy(c);
        final field = _outline(b, a.str('area', required: true)!);
        final s = c.toolSettings, cat = b.p.catalog;
        final isTape = (a.str('lateral') ?? 'tape') == 'tape';
        final tapeSpec = a.str('tape') ?? (cat.tape(s.tapeSpecId)?.enabled ?? false ? s.tapeSpecId : (cat.tapes.where((x) => x.enabled).firstOrNull?.id ?? ''));
        final tapeInlet = a.number('inlet_head_m', min: 0.5, max: 60) ?? cat.tape(tapeSpec)?.defaultInletHeadM ?? s.tapeInletHeadM;
        final outletSpec = a.str('outlet') ?? s.outletSpecId;
        final nozzle = a.str('nozzle') ?? (a.has('outlet') ? cat.outlet(outletSpec)?.nozzles.firstOrNull?.id : s.nozzleId);
        final headM = a.number('head_m', min: 0.5, max: 120) ?? (a.has('outlet') ? cat.outlet(outletSpec)?.nozzle(nozzle)?.defaultHeadM : null) ?? s.headM;
        final outletSpacing = a.number('emitter_spacing_m', min: 0.05, max: 50) ?? s.spacing;
        if (isTape && cat.tape(tapeSpec) == null) {
          throw ToolInputError(cat.tapes.any((x) => x.enabled) ? 'Unknown tape "$tapeSpec" (search_catalog kind "tape").' : 'The catalogue has no enabled drip tape or dripline. ${catalogNextStep('tape')}');
        }
        if (!isTape && cat.outlet(outletSpec)?.nozzle(nozzle) == null) throw ToolInputError('Unknown emitter or nozzle "$outletSpec/$nozzle" (search_catalog kind "emitter").');
        for (final (k, usage) in [('lateral_pipe', PipeUsage.lateral), ('submain_pipe', PipeUsage.zone)]) {
          final id = a.str(k);
          if (id != null && !cat.pipesFor(usage).any((x) => x.id == id)) throw ToolInputError('"$id" is not a ${usage.name} pipe of the catalogue.');
        }
        final valve = a.str('valve');
        if (valve != null && cat.valve(valve)?.kind != ValveKind.control) throw ToolInputError('"$valve" is not a control valve of the catalogue.');
        final sl = a.number('lateral_spacing_m', min: 0.1, max: 100) ?? (isTape ? 1.5 : 12);
        double q = 0, se = 0;
        if (isTape) {
          final tp = cat.tape(tapeSpec)!;
          (q, se) = (tp.emitter.flow(tapeInlet), tp.emitterSpacingM);
        } else {
          (q, se) = (cat.outlet(outletSpec)!.nozzle(nozzle)!.curve.flow(headM), outletSpacing);
        }
        final perHa = q > 0 && se > 0 ? q * 1e4 / (se * sl) : 0.0;
        final byFlow = a.has('max_block_flow_m3h');
        final (poc, _) = a.str('connection') == null ? _connection(b, null) : (a.str('connection') == 'none' ? (null, null) : _connection(b, a.str('connection')));
        final sub = await engSoon(
          () => subdivideField(
            field,
            FieldSubdivisionOptions(
              direction: _dir(a) ?? longestEdgeDirection(normalizePolygon(field)),
              mode: (a.str('mode') ?? 'strips') == 'grid' ? SubdivisionMode.grid : SubdivisionMode.strips,
              maxBlockArea: byFlow ? 0 : (a.number('max_block_area_m2', min: 100, max: 1e7) ?? 2e4),
              maxBlockFlow: byFlow ? a.number('max_block_flow_m3h', min: 0.01, max: 1e5)! * m3sPerM3h : 0,
              flowPerHectare: perHa,
              maxLateralLength: a.number('max_lateral_length_m', min: 0, max: 2000) ?? 0,
              centreFeed: a.flag('centre_feed') ?? false,
              minBlockWidth: a.number('min_block_width_m', min: 2, max: 500) ?? 10,
              roadWidth: a.number('road_width_m', min: 0, max: 50) ?? 4,
              pointOfConnection: poc,
            ),
          ),
        );
        if (sub.blocks.isEmpty) throw ToolInputError('No block.${_codes(b, sub.messages)}');
        final names = zoneNames(b.p, t('subdiv.block'), sub.blocks.length);
        final mainline = (a.flag('mainline') ?? false) && poc != null;
        final made = b.change('subdivide_field_advanced', () {
          final p = b.p;
          final out = <Entity>[];
          final valves = <Pt>[];
          for (var k = 0; k < sub.blocks.length; k++) {
            final blk = sub.blocks[k];
            final res = generateBlock(
              p,
              blockOptionsFor(
                blk,
                sub.direction,
                lateralSpacing: sl,
                isTape: isTape,
                tapeSpecId: tapeSpec,
                tapeInletHeadM: tapeInlet,
                outletSpecId: outletSpec,
                nozzleId: nozzle,
                outletSpacing: outletSpacing,
                headM: headM,
                lateralPipeSpecId: isTape ? null : a.str('lateral_pipe'),
                submainPipeSpecId: a.str('submain_pipe'),
                valveSpecId: valve ?? (blk.flow > 0 ? pickZoneValve(p.catalog, blk.flow)?.id : s.valveSpecId),
                submainStub: a.number('stub_m', min: 0, max: 50) ?? 1.5,
                zoneName: names[k],
                submainLabel: t('name.submain'),
                stubLabel: t('name.stub'),
                lateralPrefix: t('name.lateral'),
              ),
            );
            out.addAll(res.all);
            if (res.valve != null) valves.add(res.valve!.position);
          }
          if (mainline && valves.isNotEmpty) {
            for (final m in routeMainline(poc, valves)) {
              out.add(PipeEntity(id: p.newId(), points: List.of(m.points), scope: HydraulicScope.mainline));
            }
          }
          p.entities.addAll(out);
          return out;
        });
        c.select(made.map((e) => e.id));
        return ToolOutput(
          '${sub.blocks.length} blocks (${[for (var k = 0; k < sub.blocks.length; k++) '${names[k]} ${engN(sub.blocks[k].area / 1e4, 2)} ha${sub.blocks[k].flow > 0 ? ' ${engQ(sub.blocks[k].flow)}' : ''}, lateral ${engN(sub.blocks[k].lateralLength, 0)} m'].take(40).join('; ')}).\n${_made(b, made)}${_codes(b, sub.messages)}',
        );
      },
    ),
    // ---------------------------------------------------------------- tree rings
    engOp(
      b,
      name: 'tree_rings_advanced',
      effect: ToolEffect.write,
      description: 'Design → Auto design → Tree rings with every option of the dialog (tree_rings is the short version): drip rings round the trees of a planting grid inside an area (with row and plant offsets) or round given tree symbols (surveyed positions; their rows are found from the trees), a ring of dripline (chosen tape and inlet head) or of drippers (chosen dripper, nozzle, head and count per tree) on a ring pipe round every trunk, laterals along the rows (chosen lateral pipe), a submain at the start, centre or end with its stub, and the zone valve (chosen, or picked by flow) with its zone name. One undo step. Inputs: area (orchard id) or trees (tree symbol ids), plant_spacing_m (6), row_spacing_m (7), row_offset_m, plant_offset_m, ring_radius_m 0.05–10 (0.75), direction_deg, kind dripline|drippers, tape, inlet_head_m, dripper, nozzle, head_m, drippers_per_tree 1–24 (4), lateral_pipe, submain start|centre|end, stub_m (1.5), valve, zone_name. Output: trees, laterals, ring length, flow, the new ids and the messages.',
      schema: obj({
        'area': str('Orchard area id.'),
        'trees': arr(str(), 'Tree symbol ids (surveyed trees).', 20000),
        'plant_spacing_m': num_('0.3–50 m.'),
        'row_spacing_m': num_('0.3–50 m.'),
        'row_offset_m': num_('Shift of the rows across, m.'),
        'plant_offset_m': num_('Shift of the trees along the rows, m.'),
        'ring_radius_m': num_('0.05–10 m.'),
        'direction_deg': num_('Row direction.'),
        'kind': str(null, ['dripline', 'drippers']),
        'tape': str('Dripline (tape) id.'),
        'inlet_head_m': num_('Dripline inlet head, 0.5–60 m.'),
        'dripper': str('Dripper or bubbler id.'),
        'nozzle': str('Nozzle id of that dripper; default its first.'),
        'head_m': num_('Dripper head, 0.5–120 m.'),
        'drippers_per_tree': int_('1–24.'),
        'lateral_pipe': str('Lateral pipe id.'),
        'submain': str(null, ['start', 'centre', 'end']),
        'stub_m': num_('0–50 m.'),
        'valve': str('Zone valve id.'),
        'zone_name': str('Zone name of the valve; default the next free "Zone n".'),
      }),
      summary: (i) => t('ai.op.tree_rings_advanced', {'n': '${i['area'] ?? '${(i['trees'] as List?)?.length ?? 0}'}'}),
      run: (a, _) async {
        engNotBusy(c);
        final area = a.has('area') ? _outline(b, a.str('area')!) : null;
        final trees = <Pt>[];
        for (final e in b.findAll(a.strings('trees'))) {
          if (e is! SymbolEntity || e.kind != SymbolKind.tree) throw ToolInputError('"${e.id}" is not a tree symbol.');
          trees.add(e.position);
        }
        if (area == null && trees.isEmpty) throw ToolInputError('Give "area" (a planting grid inside it) or "trees" (tree symbols).');
        final cat = b.p.catalog, s = c.toolSettings;
        final plant = a.number('plant_spacing_m', min: 0.3, max: 50) ?? 6, row = a.number('row_spacing_m', min: 0.3, max: 50) ?? 7;
        if (trees.isEmpty && polygonArea(area!).abs() / (plant * row) > 20000) throw ToolInputError('More than 20000 trees: subdivide the field first.');
        final kind = (a.str('kind') ?? 'dripline') == 'drippers' ? RingKind.drippers : RingKind.dripline;
        final tapeSpec = a.str('tape') ?? (cat.tape(s.tapeSpecId)?.enabled ?? false ? s.tapeSpecId : (cat.tapes.where((x) => x.enabled).firstOrNull?.id ?? ''));
        final tapeInlet = a.number('inlet_head_m', min: 0.5, max: 60) ?? cat.tape(tapeSpec)?.defaultInletHeadM ?? s.tapeInletHeadM;
        final drippers = [
          for (final o in cat.outlets)
            if (o.enabled && o.nozzles.isNotEmpty && (o.kind == OutletKind.dripper || o.kind == OutletKind.bubbler)) o,
        ];
        final dripper = a.has('dripper')
            ? (drippers.where((o) => o.id == a.str('dripper')).firstOrNull ?? (throw ToolInputError('"${a.str('dripper')}" is not a dripper or bubbler of the catalogue.')))
            : drippers.firstOrNull;
        final nz = a.has('nozzle') ? (dripper?.nozzle(a.str('nozzle')) ?? (throw ToolInputError('No nozzle "${a.str('nozzle')}" on ${dripper?.id}.'))) : dripper?.nozzles.first;
        final headM = a.number('head_m', min: 0.5, max: 120) ?? nz?.defaultHeadM ?? 10;
        if (kind == RingKind.dripline && cat.tape(tapeSpec) == null) {
          throw ToolInputError(
            a.has('tape') ? 'Unknown tape "$tapeSpec" (search_catalog kind "tape").' : 'The catalogue has no enabled dripline for the rings. ${catalogNextStep('tape')} Then give "tape", or use kind "drippers".',
          );
        }
        if (kind == RingKind.drippers && nz == null) throw ToolInputError('The catalogue has no enabled dripper or bubbler for the rings. ${catalogNextStep('emitter')} Then give "dripper", or use kind "dripline".');
        final lateralPipe = a.str('lateral_pipe') ?? s.lateralPipeSpecId;
        if (a.has('lateral_pipe') && !cat.pipesFor(PipeUsage.lateral).any((x) => x.id == lateralPipe)) throw ToolInputError('"$lateralPipe" is not a lateral pipe of the catalogue.');
        final valve = a.str('valve');
        if (valve != null && cat.valve(valve)?.kind != ValveKind.control) throw ToolInputError('"$valve" is not a control valve of the catalogue.');
        final dir = _dir(a) ?? (area != null && trees.isEmpty ? longestEdgeDirection(normalizePolygon(area)) : Pt.polar(1, 0));
        final r = await engSoon(
          () => layoutTreeRings(
            area: area,
            trees: trees.isEmpty ? null : trees,
            options: TreeRingOptions(
              direction: dir,
              plantSpacing: plant,
              rowSpacing: row,
              rowOffset: a.number('row_offset_m', min: -100, max: 100) ?? 0,
              plantOffset: a.number('plant_offset_m', min: -100, max: 100) ?? 0,
              ringRadius: a.number('ring_radius_m', min: 0.05, max: 10) ?? 0.75,
              kind: kind,
              drippersPerTree: a.integer('drippers_per_tree', min: 1, max: 24) ?? 4,
              submainPosition: SubmainPosition.values.byName(a.str('submain') ?? 'start'),
              submainStub: a.number('stub_m', min: 0, max: 50) ?? 1.5,
            ),
          ),
        );
        if (r.trees.isEmpty) throw ToolInputError('No tree.${_codes(b, r.messages)}');
        double flow() {
          if (kind == RingKind.dripline) {
            final tp = cat.tape(tapeSpec);
            return tp == null || !(tp.emitterSpacingM > 0) ? 0 : r.ringLength / tp.emitterSpacingM * tp.emitter.flow(tapeInlet);
          }
          return nz == null ? 0 : r.dripperCount * nz.curve.flow(headM);
        }

        final made = b.change('tree_rings_advanced', () {
          final p = b.p;
          final zone = (a.str('zone_name') ?? '').isEmpty ? zoneNames(p, t('name.zone'), 1).first : a.str('zone_name')!;
          final out = r.toEntities(
            p,
            tapeSpecId: tapeSpec,
            tapeInletHeadM: tapeInlet,
            outletSpecId: dripper?.id,
            nozzleId: nz?.id,
            headM: headM,
            valveSpecId: valve ?? pickZoneValve(p.catalog, flow())?.id,
            zoneName: zone,
            lateralPipeSpecId: lateralPipe,
          );
          p.entities.addAll(out);
          return out;
        });
        c.select(made.map((e) => e.id));
        return ToolOutput(
          '${r.trees.length} trees, ${r.laterals.length} laterals (${engN(r.laterals.fold(0.0, (m, l) => m + polylineLength(l)), 0)} m), ${kind.name} rings ${engN(r.ringLength, 0)} m${kind == RingKind.drippers ? ', ${r.dripperCount} drippers' : ''}, zone flow ${engQ(flow())}.\n${_made(b, made)}${_codes(b, r.messages)}',
        );
      },
    ),
    // ---------------------------------------------------------------- pivot fit
    engOp(
      b,
      name: 'fit_pivot_advanced',
      effect: ToolEffect.write,
      description: 'Design → Auto design → Pivot fit with every option of the dialog (fit_pivot is the short version): the largest centre pivot — full circle or the sector that irrigates the most — that a field holds, avoiding obstacle shapes and point obstacles (trees, posts, spot heights) with a clearance, built from the span lengths and overhangs given within a span count. Adds the pivot (one undo step). Inputs: area (field id), sector (allow a sector), obstacles (closed shape ids, [] for none; default every closed shape inside or across the field that does not hold it — a property line, a second outline or a hatch of the field holds it), point_obstacles (point item ids; default the symbols inside the field), clearance_m 0–100 (10), spans_m (default 34.4, 41.8, 48.8, 54.9, 62.2), overhangs_m (default 0, 6.4, 12.8, 19.2, 25.9), min_spans 1–60 (1), max_spans 1–60 (20), end_throw_m 0–80 (5), min_sweep_deg 1–360 (30, sector). Output: the centre, the machine (spans + overhang), the irrigated radius, the area and coverage, the new id and the messages.',
      schema: obj(
        {
          'area': str('Field id.'),
          'sector': bool_('Allow a sector (part circle).'),
          'obstacles': arr(str(), 'Closed shapes to avoid.'),
          'point_obstacles': arr(str(), 'Point items to avoid (symbols, spot heights).'),
          'clearance_m': num_('Clearance round a point obstacle, 0–100 m.'),
          'spans_m': numbers('Span lengths available, m.'),
          'overhangs_m': numbers('Overhang lengths available, m (0 = none).'),
          'min_spans': int_('1–60.'),
          'max_spans': int_('1–60.'),
          'end_throw_m': num_('End gun throw, 0–80 m.'),
          'min_sweep_deg': num_('Least sector, 1–360°.'),
        },
        required: ['area'],
      ),
      summary: (i) => t('ai.op.fit_pivot_advanced', {'n': '${i['area']}'}),
      run: (a, i) async {
        engNotBusy(c);
        final ref = a.str('area', required: true)!;
        final field = _outline(b, ref);
        final self = b.find(ref).id;
        final shapes = i.containsKey('obstacles') ? [for (final id in a.strings('obstacles')) (b.find(id), _outline(b, id))] : pivotObstacleShapes(b.p, self, field);
        final obstacles = [for (final (_, o) in shapes) o];
        final pts = i.containsKey('point_obstacles')
            ? [
                for (final e in b.findAll(a.strings('point_obstacles')))
                  if (e is PointEntity) e.position else throw ToolInputError('"${e.id}" is not a point item.'),
              ]
            : [
                for (final e in b.p.entities)
                  if (e is SymbolEntity && pointInPolygon(e.position, field)) e.position,
              ];
        final spans = engNumbers(i['spans_m'], 'spans_m', min: 1, max: 200) ?? defaultSpanLengths;
        final overhangs = engNumbers(i['overhangs_m'], 'overhangs_m', min: 0, max: 100) ?? defaultOverhangs;
        if (spans.isEmpty || overhangs.isEmpty) throw ToolInputError('"spans_m" and "overhangs_m" need at least one length (an overhang may be 0).');
        final minSpans = a.integer('min_spans', min: 1, max: 60) ?? 1;
        final maxSpans = math.max(minSpans, a.integer('max_spans', min: 1, max: 60) ?? 20);
        final clearance = a.number('clearance_m', min: 0, max: 100) ?? 10;
        final o = PivotFitOptions(
          obstacles: obstacles,
          pointObstacles: [for (final q in pts) PointObstacle(q, clearance)],
          spanLengths: spans,
          overhangs: overhangs,
          minSpans: minSpans,
          maxSpans: maxSpans,
          endThrowM: a.number('end_throw_m', min: 0, max: 80) ?? 5,
          minSweepDeg: a.number('min_sweep_deg', min: 1, max: 360) ?? 30,
        );
        final fit = await engSoon(() => (a.flag('sector') ?? false) ? fitSectorPivot(field, o) : fitFullCirclePivot(field, o));
        if (fit.spans == null) throw ToolInputError('No pivot fits (available radius ${engN(fit.availableRadius, 1)} m).${_codes(b, fit.messages)}${pivotFitHelp(b, field, shapes, fit.messages)}');
        final s = c.toolSettings;
        final made = b.change('fit_pivot_advanced', () {
          final p = b.p;
          final n = p.entities.whereType<PivotEntity>().length + 1;
          final e = fit.toPivotEntity(p, name: '${t('tool.pivot').split('/').first.trim()} $n')
            ..grossDepthMm = s.pivotDepthMm
            ..hoursPerCycle = s.pivotHours
            ..endPressureM = s.pivotEndPressureM;
          p.entities.add(e);
          return e;
        });
        c.select([made.id]);
        final sp = fit.spans!;
        final counts = <double, int>{};
        for (final v in sp.spans) {
          counts[v] = (counts[v] ?? 0) + 1;
        }
        return ToolOutput(
          'Pivot ${made.id}: centre ${AgentToolbox.pt(fit.center)}, machine ${[for (final e in counts.entries) '${e.value} × ${engN(e.key, 1)}', if (sp.overhang > 0) '${engN(sp.overhang, 1)} overhang'].join(' + ')} = ${engN(sp.length, 1)} m, irrigated radius ${engN(fit.irrigatedRadius, 1)} m, ${fit.fullCircle ? 'full circle' : 'sector ${engN(fit.sectorStartDeg, 0)}° + ${engN(fit.sectorSweepDeg, 0)}°'}, ${engN(fit.area / 1e4, 2)} ha = ${engN(fit.coverage * 100, 1)} % of the field. Connect its centre to the mainline, then run_design.${_codes(b, fit.messages)}',
        );
      },
    ),
  ];
}
