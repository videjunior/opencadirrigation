/// The tools that run the program's automations for the model: the design
/// and its corrections, the automatic layouts (heads, blocks, rings,
/// templates, pivots), pump selection, air valves, the analyses
/// (transients, 24-hour simulation, criticality, on-demand, energy
/// grouping, uniformity), exports and the view. Each calls the same engine
/// functions as the program's own dialogs, with the dialogs' defaults.
library;

import 'dart:math' as math;

import '../../core/api.dart';
import '../actions.dart' show deliverExport, pdfTexts;
import '../io/file_io.dart';
import '../io/pdf_font_loader.dart';
import '../state/controller.dart';
import '../widgets/advice_panel.dart' show adviceTitle;
import 'agent_tools.dart';
import 'view_snapshot.dart' show fetchBaseMap;

// ---------------------------------------------------------------- helpers

/// Closed outline of [e] (polygon, area, circle, pivot, closed spline).
List<Pt>? outlineOf(Entity e) {
  final List<Pt>? pts = switch (e) {
    CircleEntity c => [for (var i = 0; i < 72; i++) c.center + Pt.polar(c.radius, 2 * math.pi * i / 72)],
    PivotEntity p => p.outline(),
    SplineEntity s => s.closed ? s.curve() : null,
    _ => e.isClosedShape ? e.linearPoints : null,
  };
  return pts == null || pts.length < 3 || polygonArea(pts).abs() < 1e-6 ? null : List.of(pts);
}

List<Pt> _outline(AgentToolbox b, String ref) {
  final e = b.find(ref);
  final o = outlineOf(e);
  if (o == null) throw ToolInputError('"$ref" is not a closed shape (use an area, a closed polyline, a circle or a pivot).');
  return o;
}

/// The first [n] names `prefix i` no zone uses yet.
List<String> zoneNames(Project p, String prefix, int n) {
  final used = <String>{
    for (final e in p.entities)
      if (e is ControlValveEntity) e.zoneName else if (e is OutletEntity) e.zoneName else if (e is PivotEntity) e.zoneName,
  };
  final out = <String>[];
  for (var i = 1; out.length < n; i++) {
    final name = '$prefix $i';
    if (!used.contains(name)) out.add(name);
  }
  return out;
}

/// The zone flow the dialogs propose: the smaller of the supply design flow
/// and the largest control valve.
double zoneFlowDefault(Project p) {
  final supply = p.entities.whereType<WaterSupplyEntity>().fold(0.0, (m, s) => math.max(m, s.designFlow));
  final valve = p.catalog.valves.where((v) => v.enabled && v.kind == ValveKind.control).fold(0.0, (m, v) => math.max(m, v.maxFlow));
  return supply > 0 && valve > 0 ? math.min(supply, valve) : math.max(supply, valve);
}

/// The sprinkler family [id], else the one the dialogs pick.
OutletSpec _family(AgentToolbox b, String? id) {
  final cat = b.p.catalog;
  final fams = [
    for (final o in cat.outlets)
      if (o.enabled && o.nozzles.isNotEmpty && (o.kind == OutletKind.sprinkler || o.kind == OutletKind.microSprinkler)) o,
  ];
  if (id != null) {
    final f = fams.where((o) => o.id == id).firstOrNull;
    if (f == null) throw ToolInputError('"$id" is not an enabled sprinkler or micro-sprinkler. Choose one of: ${fams.map((o) => o.id).join(', ')}.');
    return f;
  }
  if (fams.isEmpty) throw ToolInputError('The catalogue has no enabled sprinkler.');
  final last = cat.outlet(b.c.toolSettings.outletSpecId);
  if (last != null && last.kind == OutletKind.sprinkler && fams.contains(last)) return last;
  return fams.where((f) => f.id == 'rotor').firstOrNull ?? fams.first;
}

/// Nozzle [id] of [family] (an error listing its nozzles when it has none
/// of that id); without [id], [fallback] when the family has it, else its
/// first nozzle.
NozzleSpec? _nozzleOf(OutletSpec family, String? id, {String? fallback}) {
  if (id != null) {
    final n = family.nozzles.where((z) => z.id == id).firstOrNull;
    if (n == null) throw ToolInputError('Emitter "${family.id}" has no nozzle "$id"; its nozzles: ${family.nozzles.map((z) => z.id).join(', ')}.');
    return n;
  }
  return family.nozzles.where((z) => z.id == fallback).firstOrNull ?? family.nozzles.firstOrNull;
}

/// Nominal flow (m³/s) of the laterals [es]: tape emitters at the inlet
/// pressure, spray emitters at their set pressure.
double _blockFlow(Catalog cat, Iterable<Entity> es) {
  var q = 0.0;
  for (final e in es) {
    switch (e) {
      case TapeEntity x:
        final tp = cat.tape(x.tapeSpecId);
        if (tp != null && tp.emitterSpacingM > 0) q += (x.length / tp.emitterSpacingM).floor() * tp.emitter.flow(x.inletHeadM);
      case SpraylineEntity x:
        final nz = cat.outlet(x.outletSpecId)?.nozzle(x.nozzleId);
        if (nz != null) q += x.outletCount * nz.curve.flow(x.headM);
      default:
        break;
    }
  }
  return q;
}

String _warn(AgentToolbox b, Iterable<String> codes) => codes.isEmpty ? '' : '\nMessages: ${codes.map((w) => b.t.warning(w, entityName: b.c.entityName)).join('; ')}';

Pt? _firstSource(Project p) {
  for (final e in p.entities) {
    if (e is WaterSupplyEntity) return e.position;
    if (e is PumpEntity && e.scope == HydraulicScope.mainline) return e.position;
  }
  return null;
}

/// After a generator: what was added.
String _made(AgentToolbox b, List<Entity> made) {
  final counts = <String, int>{};
  for (final e in made) {
    final k = b.kindOf(e);
    counts[k] = (counts[k] ?? 0) + 1;
  }
  final ids = made.map((e) => e.id).toList();
  return 'Added ${made.length} items (${[for (final e in counts.entries) '${e.value} × ${e.key}'].join(', ')}); ids ${ids.take(60).join(', ')}${ids.length > 60 ? '…' : ''}. Results were discarded: run_design next.';
}

/// What the design produced, compactly.
String designSummary(AgentToolbox b) {
  final c = b.c;
  final r = c.results;
  if (r == null) return 'No design results. ${c.lastMessage ?? ''}';
  final u = b.u;
  final out = <String>[];
  final zones = r.zones.values.toList();
  final bad = [
    for (final z in zones)
      if (!z.withinWindow) z,
  ];
  out.add(
    '${zones.length} zones; ${bad.isEmpty ? 'all within their pressure window' : '${bad.length} outside the pressure window: ${bad.take(10).map((z) => '${z.zoneName} (${fmt(u.pressureFromHead(z.minOutletPressure), 1)}–${fmt(u.pressureFromHead(z.maxOutletPressure), 1)} vs ${fmt(u.pressureFromHead(z.allowedMin), 1)}–${fmt(u.pressureFromHead(z.allowedMax), 1)} ${u.pressureLabel})').join(', ')}'}.',
  );
  for (final f in r.systemFlows) {
    final s = [
      for (final d in f.supplies)
        '${d.name}: ${fmt(u.flowFromSi(d.flow), 1)} ${u.flowLabel} at ${fmt(u.pressureFromHead(d.head), 1)} ${u.pressureLabel} (needs ${fmt(u.pressureFromHead(math.max(0, d.requiredHead)), 1)})',
    ];
    final deficit = f.valves.where((v) => v.deficit > 0.01).map((v) => v.zoneName).toList();
    out.add(
      'Flow ${f.name}: ${fmt(u.flowFromSi(f.totalFlow), 1)} ${u.flowLabel}; ${s.join('; ')}${deficit.isEmpty ? '' : '; pressure short at ${deficit.take(8).join(', ')}'}${f.converged ? '' : '; NOT CONVERGED'}.',
    );
  }
  if (r.pivots.isNotEmpty) out.add('${r.pivots.length} pivots${r.pivots.values.any((p) => p.warnings.isNotEmpty) ? ' (with warnings)' : ''}.');
  final over =
      [
        for (final z in zones)
          for (final p in z.pipes)
            if (p.overVelocity) p,
      ].length +
      [
        for (final f in r.systemFlows)
          for (final p in f.pipes)
            if (p.overVelocity) p,
      ].length;
  if (over > 0) out.add('$over pipe segments above the velocity limit.');
  out.add('Costs (${b.p.params.currency}): materials ${fmt(r.capitalCost, 2)}, annual energy ${fmt(r.annualEnergyCost, 2)}, annual total ${fmt(r.annualCapitalCost + r.annualEnergyCost, 2)}.');
  final adv = c.advice;
  final errors = adv.where((a) => a.level == AdviceLevel.error).toList();
  out.add(
    'Messages: ${errors.length} errors, ${adv.where((a) => a.level == AdviceLevel.warning).length} warnings${adv.isEmpty ? '' : ' — ${adv.take(8).map((a) => '[${a.code}] ${adviceTitle(c, a)}').join('; ')}'}${adv.length > 8 ? '…' : ''} (get_design_messages for details).',
  );
  return out.join('\n');
}

void _needResults(ProjectController c) {
  if (c.results == null) throw ToolInputError('This needs design results: call run_design first.');
}

void _notBusy(ProjectController c) {
  if (c.busy) throw ToolInputError('A design is running; wait until it finishes.');
}

/// Runs [f] after giving the interface a frame (the analyses are long
/// synchronous computations).
Future<T> _soon<T>(T Function() f) async {
  await Future<void>.delayed(const Duration(milliseconds: 20));
  return f();
}

String _largestFlow(List<SystemFlow> flows, DesignResults r) {
  var best = flows.first.id;
  var q = -1.0;
  for (final f in flows) {
    final x = r.systemFlows.where((s) => s.flowId == f.id).firstOrNull?.totalFlow ?? 0;
    if (x > q) {
      q = x;
      best = f.id;
    }
  }
  return best;
}

// ---------------------------------------------------------------- tools

List<AgentTool> designTools(AgentToolbox b) {
  final c = b.c;
  final t = b.t;
  String m3h(double m3s) => AgentToolbox.m3h(m3s);
  return [
    FnTool(
      name: 'run_design',
      effect: ToolEffect.write,
      description: 'Runs the program\'s design: sizes every pipe and lateral the design may size (no spec, or auto true) for the least annual cost within the emitters\' pressure windows and the velocity limits, then analyses the whole system, each zone and then the mainline for every system flow. It needs a water supply and a zone valve or pivot. It changes pipe sizes (an undo step) and replaces the results, which any later change discards. Returns the summary: zones outside their pressure window (their pressures against the allowed range), each system flow\'s total flow and supply duty (pressure available and needed), valves short of pressure, flows that did not converge, pivots, pipe segments over the velocity limit, costs (materials, annual energy, annual total) and the message counts with the first messages; then read get_design_messages and the report tables. read_manual "design" explains each step.',
      inputSchema: obj({
        'mode': str('"all" (default) sizes zones and mainline; "zones" only zone pipes and laterals; "mainline" only the mainline. The rest is analysed as it is.', ['all', 'zones', 'mainline']),
      }),
      summary: (i) => t('ai.do.design', {'n': '${i['mode'] ?? 'all'}'}),
      handler: (i) async {
        _notBusy(c);
        final mode = ToolArgs(i).str('mode') ?? 'all';
        await c.runDesign(sizeZones: mode != 'mainline', sizeMain: mode != 'zones');
        if (c.results == null) throw ToolInputError('The design did not run: ${c.lastMessage ?? 'check the water supply and the zone valves'}.');
        return ToolOutput(designSummary(b));
      },
    ),
    FnTool(
      name: 'analyse_design',
      description: 'Analyses the system as drawn, resizing nothing, and returns the same summary as run_design. Use it to see the effect of a manual change or to check a design whose pipes are fixed. It changes no item; it replaces the results.',
      inputSchema: obj({}),
      summary: (_) => t('ai.tool.analyse'),
      handler: (_) async {
        _notBusy(c);
        await c.runDesign(sizeZones: false, sizeMain: false);
        if (c.results == null) throw ToolInputError('The analysis did not run: ${c.lastMessage ?? 'check the water supply and the zone valves'}.');
        return ToolOutput(designSummary(b));
      },
    ),
    FnTool(
      name: 'apply_fix',
      effect: ToolEffect.write,
      description: 'Applies one automatic correction offered by a message of get_design_messages: its number, its code (checked, so a changed list is caught) and one of the corrections listed for it. One undo step; with design results present the design runs again and its summary follows. Fails when the messages changed (read them again) or that correction is not offered for the message.',
      inputSchema: obj(
        {
          'index': int_('Message number (# in get_design_messages).'),
          'code': str('The message code, as listed.'),
          'fix': str('One of the corrections listed for that message.', [for (final k in FixKind.values) k.name]),
        },
        required: ['index', 'code', 'fix'],
      ),
      summary: (i) => t('ai.do.fix', {
        'n': t.has('fix.${i['fix']}') ? t('fix.${i['fix']}', {'d': ''}).replaceAll(RegExp(r'\s*\(\s*\)'), '') : '${i['fix']}',
      }),
      handler: (i) async {
        _notBusy(c);
        final a = ToolArgs(i);
        final adv = c.advice;
        final k = a.integer('index', min: 0, required: true)!;
        if (k >= adv.length || adv[k].code != a.str('code', required: true)) throw ToolInputError('The messages changed: call get_design_messages again.');
        final fix = FixKind.values.byName(a.str('fix', required: true)!);
        if (!adv[k].fixes.contains(fix)) throw ToolInputError('"${fix.name}" is not offered for message #$k; offered: ${adv[k].fixes.map((f) => f.name).join(', ')}.');
        final res = await c.applyAdviceFix(adv[k], fix);
        if (res == null) throw ToolInputError('Refused: a design is running.');
        return ToolOutput('${res.ok ? 'Applied' : 'Not applied'}: ${t(res.key, res.args)}${c.results == null ? '' : '\n${designSummary(b)}'}', isError: !res.ok);
      },
    ),
    FnTool(
      name: 'auto_fix',
      effect: ToolEffect.write,
      description: 'Runs "Fix automatically" (the Messages panel button): applies the safe correction of every message and designs again, in rounds, until nothing more can be fixed. The safe corrections restore consistency or pick catalogue items for a known duty (connect, delete zero-length pipes, rename duplicate zones, calculate the supply pressure, choose a pump, a valve or a pipe class, split the system flows, reset out-of-range settings…); joining crossing pipes and placing a supply stay with apply_fix. One undo step. Returns the corrections applied, the number of messages left and the design summary.',
      inputSchema: obj({}),
      summary: (_) => t('adv.fixAll'),
      handler: (_) async {
        _notBusy(c);
        final r = await c.autoFixAll();
        if (r == null) throw ToolInputError('Refused: a design is running.');
        return ToolOutput(
          '${r.applied.isEmpty ? 'Nothing could be fixed automatically.' : 'Applied ${r.applied.length}: ${r.applied.map((f) => t(f.key, f.args)).join('; ')}'}\nLeft: ${r.remaining.length} messages.\n${designSummary(b)}',
        );
      },
    ),
    FnTool(
      name: 'optimize_design',
      effect: ToolEffect.write,
      description: 'Looks for the design with the lowest annual cost (capital annuity plus energy) without more errors: switches to LP sizing that trades pipe cost against energy, optionally frees the pipes sized by hand, gives each zone the smallest control valve that carries its flow and each supply with a pump within 50 m the pump with the lowest life-cycle cost, and designs. The result is kept only when it has fewer errors or, with as many, a lower annual cost; otherwise the project is restored as it was. One undo step. Returns before and after (errors, warnings, annual cost) and the changes.',
      inputSchema: obj({
        'choose_pumps': bool_('Pick the pump of each pumped supply (default true).'),
        'resize_valves': bool_('Pick the zone valves by flow (default true).'),
        'resize_fixed_pipes': bool_('Let the design resize the pipes fixed by hand too (default false).'),
      }),
      summary: (_) => t('adv.optimize'),
      handler: (i) async {
        _notBusy(c);
        final a = ToolArgs(i);
        final r = await c.optimizeDesign(
          OptimizeOptions(choosePumps: a.flag('choose_pumps') ?? true, resizeValves: a.flag('resize_valves') ?? true, resizeFixedPipes: a.flag('resize_fixed_pipes') ?? false),
        );
        if (r == null) throw ToolInputError('Refused: a design is running.');
        String s(DesignScore d) => '${d.errors} errors, ${d.warnings} warnings, annual cost ${fmt(d.annualTotal, 2)}';
        return ToolOutput(
          '${r.after.betterThan(r.before) ? 'Kept' : 'Not better: restored'}. Before: ${s(r.before)}. After: ${s(r.after)}.${r.applied.isEmpty ? '' : ' Changes: ${r.applied.map((f) => t(f.key, f.args)).join('; ')}.'}',
        );
      },
    ),
    FnTool(
      name: 'layout_sprinklers',
      effect: ToolEffect.write,
      description: 'Automatic sprinkler layout over a closed area (lawn, sports turf, field): heads of one sprinkler or micro-sprinkler family on a square or triangular grid, with matched part-circle heads along the edges and in the corners, keeping the exclusions dry. zoning groups the heads into zones by flow; routing also adds a zone valve per zone (chosen for its flow), the zone pipes and laterals, and a mainline from the water supply (or from the mainline pipe the user selected) to the valves. One undo step; the new items become the selection. Returns the head count, spacing, total flow, gross precipitation and the expected uniformity of the layout (CU, DU, dry %), the zones with their flow, the items added and the layout\'s notes. Without routing, join the heads with pipes yourself.',
      inputSchema: obj(
        {
          'area': str('Id or name of the closed area (area, closed polyline, circle).'),
          'exclusions': arr(str(), 'Ids or names of closed shapes inside to keep dry (buildings, beds, paving).'),
          'outlet': str('Sprinkler or micro-sprinkler family id (search_catalog kind "emitter"); default: the last used, else the rotor.'),
          'nozzle': str('Full-circle nozzle of that family that sets the spacing; default chosen by the layout.'),
          'head_m': num_('Pressure at the heads, 0–120 m; default the family\'s nominal.'),
          'pattern': str('Grid of the interior heads (default square; triangular rows are 0.866 × spacing apart, offset half a spacing).', ['square', 'triangular']),
          'spacing': str('Spacing rule (default head_to_head: spacing = the wetted radius).', ['head_to_head', 'percent_of_diameter', 'fixed']),
          'spacing_percent': num_('percent_of_diameter: spacing as % of the wetted diameter, 20–100 (default 50).'),
          'spacing_m': num_('fixed: the spacing, 0.5–100 m.'),
          'direction_deg': num_('Row direction, degrees counter-clockwise from east; default along the longest edge.'),
          'part_circles': str('Part circles on edges and corners: auto (when the family has matched part-circle nozzles), always or never.', ['auto', 'always', 'never']),
          'zoning': bool_('Group the heads into zones by flow (default false).'),
          'max_zone_flow_m3h': num_('zoning: largest zone flow (m³/h); default the smaller of the supply design flow and the largest control valve.'),
          'routing': bool_('Add the valves, zone pipes, laterals and the mainline (default false; needs a water supply or a selected mainline pipe).'),
        },
        required: ['area'],
      ),
      summary: (i) => t('ai.do.layout', {'n': '${i['area']}'}),
      handler: (i) async {
        final a = ToolArgs(i);
        final area = _outline(b, a.str('area', required: true)!);
        final ex = [for (final id in a.strings('exclusions')) _outline(b, id)];
        final family = _family(b, a.str('outlet'));
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
          ..direction = a.has('direction_deg') ? Pt.polar(1, degToRad(a.number('direction_deg')!)) : null
          ..partCircles = PartCircleMode.values.byName(a.str('part_circles') ?? 'auto');
        if (o.spacingRule == SpacingRule.fixed && o.spacingM <= 0) throw ToolInputError('"spacing_m" is needed with the fixed rule.');
        final layout = await _soon(() => layoutLandscape(outline: area, exclusions: ex, family: family, options: o));
        if (layout.heads.isEmpty) throw ToolInputError('No head fits.${_warn(b, layout.messages)}');
        final zoning = (a.flag('zoning') ?? false)
            ? zoneByFlow(zoneItemsOf(layout, family), ZoningOptions(maxZoneFlow: (a.number('max_zone_flow_m3h', min: 0.01) ?? zoneFlowDefault(b.p) / m3sPerM3h) * m3sPerM3h))
            : null;
        final routeOn = a.flag('routing') ?? false;
        final groups = zoning != null ? [for (final z in zoning.zones) z.items] : [if (routeOn) List<int>.generate(layout.heads.length, (k) => k)];
        final names = zoneNames(b.p, t('name.zone'), groups.length);
        final selMain = [
          for (final e in b.p.entities)
            if (c.selection.contains(e.id) && e is PipeEntity && e.scope == HydraulicScope.mainline && e.points.length >= 2) e,
        ].firstOrNull;
        final routing = routeOn && groups.isNotEmpty
            ? routeZones(
                [
                  for (final g in groups) [for (final k in g) layout.heads[k].position],
                ],
                RouteOptions(exclusions: ex, mainline: selMain?.points, pointOfConnection: selMain == null ? _firstSource(b.p) : null, placement: ValvePlacement.nearZone, direction: layout.direction),
              )
            : null;
        final zoneOf = <int, int>{
          for (var z = 0; z < groups.length; z++)
            for (final k in groups[z]) k: z,
        };
        double flowOf(int z) => groups[z].fold(0.0, (s, k) => s + layout.heads[k].flow);
        final made = b.change('layout_sprinklers', () {
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
          '${layout.heads.length} heads of ${family.id} at ${fmt(layout.headM, 1)} m, spacing ${fmt(layout.spacing, 2)} × ${fmt(layout.rowSpacing, 2)} m, total ${m3h(layout.totalFlow)}, gross rate ${fmt(layout.grossRateMmH, 1)} mm/h${m == null ? '' : ', CU ${fmt(m.cu, 1)} %, DU ${fmt(m.du, 1)} %, dry ${fmt(m.dryPct, 1)} %'}.${zoning == null ? '' : ' ${zoning.zones.length} zones: ${[for (var z = 0; z < zoning.zones.length; z++) '${names[z]} ${m3h(zoning.zones[z].flow)}'].join(', ')}.'}\n${_made(b, made)}${_warn(b, [...layout.messages, ...?zoning?.messages, ...?routing?.messages])}',
        );
      },
    ),
    FnTool(
      name: 'generate_block',
      effect: ToolEffect.write,
      description: 'Fills a closed area with one irrigation block (one zone): parallel laterals every lateral_spacing_m (drip tape, or spraylines with emitters), the submain that feeds them, a zone stub and the zone valve outside the submain, in one undo step. The laterals run along direction_deg (default: the longest edge of the area), or follow a guide line: offset copies of a contour, polyline, spline or line every lateral_spacing_m, clipped to the area (laterals on the contour; draw the guide a little past the area\'s ends and keep the block narrower than the guide\'s bends). The first lateral lies half a spacing inside the area. Without "valve" the smallest catalogue control valve whose flow range holds the block\'s nominal flow is chosen. Then join a mainline to the valve position the result gives and run the design. Returns the items added, the zone, the valve and its position, and the nominal block flow.',
      inputSchema: obj(
        {
          'area': str('Id or name of the closed area (area, closed polyline, circle).'),
          'lateral': str('"tape" for drip tape or dripline; "sprayline" for emitters on a lateral pipe.', ['tape', 'sprayline']),
          'lateral_spacing_m': num_('Distance between laterals (the row spacing), 0.2–100 m.'),
          'direction_deg': num_('Lateral direction, degrees counter-clockwise from east; default along the longest edge. Ignored with a guide.'),
          'guide': str('Id or name of a line, polyline, contour or spline whose shape the laterals follow.'),
          'tape': str('Tape id (tape laterals); default the tape last used, else the first.'),
          'inlet_head_m': num_('Tape inlet pressure, 0.5–60 m; default the tape\'s nominal inlet pressure.'),
          'outlet': str('Emitter id (spray laterals); default the emitter last used.'),
          'nozzle': str('Nozzle id of that emitter; default its first nozzle.'),
          'emitter_spacing_m': num_('Emitter spacing along spray laterals, 0.1–50 m; default the last used.'),
          'head_m': num_('Emitter pressure, 0.5–120 m; default the nozzle\'s nominal pressure.'),
          'half_spacing': bool_('Spray laterals: first emitter half a spacing from the submain (default true; false = one spacing).'),
          'lateral_pipe': str('Pipe id of the spray laterals (usage lateral); default: sized by the design.'),
          'submain_pipe': str('Pipe id of the submain and stub (usage zone); default: sized by the design.'),
          'submain': str('Submain side: "start" (default) where the laterals begin (direction_deg points away from it), "end" the opposite side, "centre" across the middle with laterals both ways.', [
            'start',
            'centre',
            'end',
          ]),
          'valve': str('Zone valve id (search_catalog kind "valve", a control valve); default chosen by the block flow.'),
          'valve_position': str('Where the valve feeds the submain: at its first row (start: the right-hand end looking along the laterals), its middle (centre, default) or its last row (end).', [
            'start',
            'centre',
            'end',
          ]),
          'stub_m': num_('Length of the zone pipe from the valve to the submain, 0–20 m (default 1.5; 0 puts the valve on the submain).'),
          'zone_name': str('Zone name, unique; default "Zone n".'),
        },
        required: ['area', 'lateral', 'lateral_spacing_m'],
      ),
      summary: (i) => t('ai.do.block', {'n': '${i['area']}'}),
      handler: (i) async {
        _notBusy(c);
        final a = ToolArgs(i);
        final poly = _outline(b, a.str('area', required: true)!);
        final tape = a.str('lateral', required: true) == 'tape';
        final cat = b.p.catalog;
        final s = c.toolSettings;
        final tapeId = a.str('tape') ?? (cat.tape(s.tapeSpecId) != null ? s.tapeSpecId : cat.tapes.firstOrNull?.id);
        final outlet = a.str('outlet') ?? s.outletSpecId;
        if (tape && cat.tape(tapeId) == null) throw ToolInputError('Unknown tape "$tapeId" (search_catalog kind "tape").');
        final family = tape ? null : cat.outlet(outlet);
        if (!tape && family == null) throw ToolInputError('Unknown emitter "$outlet" (search_catalog kind "emitter").');
        final nozzle = tape ? null : _nozzleOf(family!, a.str('nozzle'), fallback: a.has('outlet') ? null : s.nozzleId);
        final valve = a.str('valve');
        if (valve != null && cat.valve(valve) == null) throw ToolInputError('Unknown valve "$valve" (search_catalog kind "valve").');
        for (final (k, usage) in [('lateral_pipe', PipeUsage.lateral), ('submain_pipe', PipeUsage.zone)]) {
          final id = a.str(k);
          if (id != null && cat.pipe(id) == null) throw ToolInputError('Unknown pipe "$id" for $k (search_catalog kind "pipe", usage ${usage.name}).');
        }
        List<Pt>? guide;
        if (a.has('guide')) {
          final g = b.find(a.str('guide')!);
          guide = switch (g) {
            SplineEntity x => x.curve(),
            LineEntity _ || PolylineEntity _ || ContourEntity _ || BreaklineEntity _ => g.linearPoints,
            _ => null,
          };
          if (guide == null || guide.length < 2) throw ToolInputError('"${a.str('guide')}" is not a line, polyline, contour or spline.');
        }
        final dir = a.has('direction_deg') ? Pt.polar(1, degToRad(a.number('direction_deg')!)) : longestEdgeDirection(normalizePolygon(poly));
        final opts = BlockOptions(
          polygon: poly,
          direction: dir,
          guide: guide,
          lateralSpacing: a.number('lateral_spacing_m', min: 0.2, max: 100, required: true)!,
          isTape: tape,
          tapeSpecId: tape ? tapeId : null,
          tapeInletHeadM: a.number('inlet_head_m', min: 0.5, max: 60) ?? cat.tape(tapeId)?.defaultInletHeadM ?? s.tapeInletHeadM,
          outletSpecId: tape ? null : outlet,
          nozzleId: nozzle?.id,
          outletSpacing: a.number('emitter_spacing_m', min: 0.1, max: 50) ?? s.spacing,
          outletOffsetHalf: a.flag('half_spacing') ?? true,
          headM: a.number('head_m', min: 0.5, max: 120) ?? nozzle?.defaultHeadM ?? s.headM,
          lateralPipeSpecId: tape ? null : a.str('lateral_pipe'),
          submainPipeSpecId: a.str('submain_pipe'),
          valveSpecId: valve ?? s.valveSpecId,
          valvePosition: ValvePosition.values.byName(a.str('valve_position') ?? 'centre'),
          submainStub: a.number('stub_m', min: 0, max: 20) ?? 1.5,
          submainPosition: SubmainPosition.values.byName(a.str('submain') ?? 'start'),
          zoneName: a.str('zone_name') ?? b.p.uniqueZoneName(t('name.zone')),
          submainLabel: t('name.submain'),
          stubLabel: t('name.stub'),
          lateralPrefix: t('name.lateral'),
        );
        var flow = 0.0;
        final made = b.change('generate_block', () {
          final res = generateBlock(b.p, opts);
          flow = _blockFlow(b.p.catalog, res.laterals);
          if (valve == null && res.valve != null) res.valve!.valveSpecId = pickZoneValve(b.p.catalog, flow)?.id ?? opts.valveSpecId;
          b.p.entities.addAll(res.all);
          return res.all;
        });
        if (made.isEmpty) throw ToolInputError('No block fits in the area (check the lateral spacing${guide == null ? '' : ' and that the guide crosses the area'}).');
        c.select(made.map((e) => e.id));
        final v = made.whereType<ControlValveEntity>().firstOrNull;
        final spec = cat.valve(v?.valveSpecId);
        final range = spec == null ? '' : ' (${fmt(spec.minFlow * 3600, 1)}–${fmt(spec.maxFlow * 3600, 1)} m³/h)';
        return ToolOutput(
          '${v == null ? 'No valve.' : 'Zone "${v.zoneName}": valve ${v.id} ${v.valveSpecId ?? '-'}$range at ${AgentToolbox.pt(v.position)}, nominal block flow ${m3h(flow)}.'}\n${_made(b, made)}',
        );
      },
    ),
    FnTool(
      name: 'subdivide_field',
      effect: ToolEffect.write,
      description: 'Cuts a field into irrigation blocks and fills each one as generate_block does (laterals, submain, stub and a zone valve chosen for the block\'s flow; zones named "Block n"): "strips" across the lateral direction, or "grid", which also cuts along the rows so no lateral is longer than max_lateral_length_m; blocks no larger than max_block_area_m2, or drawing no more than max_block_flow_m3h, with roads of road_width_m between them. With mainline true it also routes a mainline from the water supply (or a mainline pump) to every valve. One undo step; the items become the selection. Returns each block with its area and flow, and the items added.',
      inputSchema: obj(
        {
          'area': str('Id or name of the field (a closed shape).'),
          'mode': str('Default strips.', ['strips', 'grid']),
          'max_block_area_m2': num_('Largest block, at least 100 m² (default 20000).'),
          'max_block_flow_m3h': num_('Limit the blocks by flow (m³/h) instead of area.'),
          'lateral': str('Default tape.', ['tape', 'sprayline']),
          'lateral_spacing_m': num_('0.2–100 m; default 1.5 (tape) or 12 (spray).'),
          'tape': str('Tape id; default the last used, else the first.'),
          'inlet_head_m': num_('Tape inlet pressure, 0.5–60 m; default the tape\'s nominal.'),
          'outlet': str('Emitter id of spray laterals; default the last used.'),
          'nozzle': str('Nozzle id of that emitter; default its first.'),
          'head_m': num_('Emitter pressure, 0.5–120 m; default the nozzle\'s nominal.'),
          'emitter_spacing_m': num_('Emitter spacing along spray laterals, 0.1–50 m; default the last used.'),
          'road_width_m': num_('0–50 m (default 4).'),
          'direction_deg': num_('Lateral direction, degrees counter-clockwise from east; default along the longest edge.'),
          'max_lateral_length_m': num_('grid: longest lateral, 5–2000 m (the blocks are also cut along the rows); default none.'),
          'centre_feed': bool_('Submains across the middle of the blocks, laterals both ways (default false).'),
          'mainline': bool_('Route a mainline from the water supply to the valves (default false).'),
        },
        required: ['area'],
      ),
      summary: (i) => t('ai.do.subdivide', {'n': '${i['area']}'}),
      handler: (i) async {
        final a = ToolArgs(i);
        final field = _outline(b, a.str('area', required: true)!);
        final s = c.toolSettings, cat = b.p.catalog;
        final isTape = (a.str('lateral') ?? 'tape') == 'tape';
        final tapeSpec = a.str('tape') ?? (cat.tape(s.tapeSpecId) != null ? s.tapeSpecId : (cat.tapes.firstOrNull?.id ?? ''));
        final tapeInlet = a.number('inlet_head_m', min: 0.5, max: 60) ?? cat.tape(tapeSpec)?.defaultInletHeadM ?? s.tapeInletHeadM;
        final outletSpec = a.str('outlet') ?? s.outletSpecId;
        final outletSpacing = a.number('emitter_spacing_m', min: 0.1, max: 50) ?? s.spacing;
        if (isTape && cat.tape(tapeSpec) == null) throw ToolInputError('Unknown tape "$tapeSpec" (search_catalog kind "tape").');
        final family = isTape ? null : cat.outlet(outletSpec);
        if (!isTape && family == null) throw ToolInputError('Unknown emitter "$outletSpec" (search_catalog kind "emitter").');
        final nz0 = isTape ? null : _nozzleOf(family!, a.str('nozzle'), fallback: a.has('outlet') ? null : s.nozzleId);
        final nozzle = nz0?.id ?? s.nozzleId;
        final headM = a.number('head_m', min: 0.5, max: 120) ?? nz0?.defaultHeadM ?? s.headM;
        final sl = a.number('lateral_spacing_m', min: 0.2, max: 100) ?? (isTape ? 1.5 : 12);
        var q = 0.0, se = 0.0;
        if (isTape) {
          final tp = cat.tape(tapeSpec)!;
          q = tp.emitter.flow(tapeInlet);
          se = tp.emitterSpacingM;
        } else {
          final nz = cat.outlet(outletSpec)?.nozzle(nozzle);
          if (nz != null) (q, se) = (nz.curve.flow(headM), outletSpacing);
        }
        final perHa = q > 0 && se > 0 ? q * 1e4 / (se * sl) : 0.0;
        final byFlow = a.has('max_block_flow_m3h');
        final poc = _firstSource(b.p);
        final sub = await _soon(
          () => subdivideField(
            field,
            FieldSubdivisionOptions(
              direction: a.has('direction_deg') ? Pt.polar(1, degToRad(a.number('direction_deg')!)) : longestEdgeDirection(normalizePolygon(field)),
              mode: (a.str('mode') ?? 'strips') == 'grid' ? SubdivisionMode.grid : SubdivisionMode.strips,
              maxBlockArea: byFlow ? 0 : (a.number('max_block_area_m2', min: 100) ?? 2e4),
              maxBlockFlow: byFlow ? a.number('max_block_flow_m3h', min: 0.01)! * m3sPerM3h : 0,
              flowPerHectare: perHa,
              roadWidth: a.number('road_width_m', min: 0, max: 50) ?? 4,
              maxLateralLength: a.number('max_lateral_length_m', min: 5, max: 2000) ?? 0,
              centreFeed: a.flag('centre_feed') ?? false,
              pointOfConnection: poc,
            ),
          ),
        );
        if (sub.blocks.isEmpty) throw ToolInputError('No block.${_warn(b, sub.messages)}');
        final names = zoneNames(b.p, t('subdiv.block'), sub.blocks.length);
        final mainline = (a.flag('mainline') ?? false) && poc != null;
        final made = b.change('subdivide_field', () {
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
                valveSpecId: blk.flow > 0 ? pickZoneValve(p.catalog, blk.flow)?.id : s.valveSpecId,
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
        final noMain = (a.flag('mainline') ?? false) && poc == null ? '\nNo mainline: the drawing has no water supply (or mainline pump) to start it from.' : '';
        return ToolOutput(
          '${sub.blocks.length} blocks (${[for (var k = 0; k < sub.blocks.length; k++) '${names[k]} ${fmt(sub.blocks[k].area / 1e4, 2)} ha${sub.blocks[k].flow > 0 ? ' ${m3h(sub.blocks[k].flow)}' : ''}'].join(', ')}).\n${_made(b, made)}$noMain${_warn(b, sub.messages)}',
        );
      },
    ),
    FnTool(
      name: 'tree_rings',
      effect: ToolEffect.write,
      description: 'Orchard drip rings (young trees): a ring of dripline, or a few drippers, around each tree of a planting grid over the area (plant_spacing_m along the rows, row_spacing_m between them, rows along direction_deg), or around the tree symbols inside it, with a lateral along each row, a submain and a zone valve chosen for the flow, as one zone. One undo step; the items become the selection. Returns the tree count, the zone flow and the items added. More than 20000 trees: subdivide the field first.',
      inputSchema: obj(
        {
          'area': str('Id or name of the orchard area.'),
          'plant_spacing_m': num_('Along the row, 0.3–50 m (default 6).'),
          'row_spacing_m': num_('Between rows, 0.3–50 m (default 7).'),
          'ring_radius_m': num_('0.1–5 m (default 0.75).'),
          'kind': str('Default dripline.', ['dripline', 'drippers']),
          'drippers_per_tree': int_('drippers: 1–24 (default 4).'),
          'direction_deg': num_('Row direction, degrees counter-clockwise from east; default along the longest edge.'),
          'use_tree_symbols': bool_('Ring the tree symbols inside the area instead of a grid.'),
          'tape': str('Dripline id for the rings and laterals; default the tape last used, else the first.'),
          'outlet': str('drippers: dripper or bubbler id; default the catalogue\'s first.'),
          'zone_name': str('Zone name; default "Zone n".'),
        },
        required: ['area'],
      ),
      summary: (i) => t('ai.do.rings', {'n': '${i['area']}'}),
      handler: (i) async {
        final a = ToolArgs(i);
        final area = _outline(b, a.str('area', required: true)!);
        final trees = (a.flag('use_tree_symbols') ?? false)
            ? [
                for (final e in b.p.entities)
                  if (e is SymbolEntity && e.kind == SymbolKind.tree && pointInPolygon(e.position, area)) e.position,
              ]
            : <Pt>[];
        final cat = b.p.catalog, s = c.toolSettings;
        final plant = a.number('plant_spacing_m', min: 0.3, max: 50) ?? 6, row = a.number('row_spacing_m', min: 0.3, max: 50) ?? 7;
        if (trees.isEmpty && polygonArea(area).abs() / (plant * row) > 20000) throw ToolInputError('More than 20000 trees: subdivide the field first.');
        final kind = (a.str('kind') ?? 'dripline') == 'drippers' ? RingKind.drippers : RingKind.dripline;
        final r = await _soon(
          () => layoutTreeRings(
            area: area,
            trees: trees.isEmpty ? null : trees,
            options: TreeRingOptions(
              direction: a.has('direction_deg') ? Pt.polar(1, degToRad(a.number('direction_deg')!)) : longestEdgeDirection(normalizePolygon(area)),
              plantSpacing: plant,
              rowSpacing: row,
              ringRadius: a.number('ring_radius_m', min: 0.1, max: 5) ?? 0.75,
              kind: kind,
              drippersPerTree: a.integer('drippers_per_tree', min: 1, max: 24) ?? 4,
            ),
          ),
        );
        if (r.trees.isEmpty) throw ToolInputError('No tree.${_warn(b, r.messages)}');
        final tapeSpec = a.str('tape') ?? (cat.tape(s.tapeSpecId) != null ? s.tapeSpecId : (cat.tapes.firstOrNull?.id ?? ''));
        if (a.has('tape') && cat.tape(tapeSpec) == null) throw ToolInputError('Unknown tape "$tapeSpec" (search_catalog kind "tape").');
        final tapeInlet = cat.tape(tapeSpec)?.defaultInletHeadM ?? s.tapeInletHeadM;
        final dripper = a.has('outlet')
            ? (cat.outlet(a.str('outlet')) ?? (throw ToolInputError('Unknown emitter "${a.str('outlet')}" (search_catalog kind "emitter").')))
            : cat.outlets.where((o) => o.enabled && o.nozzles.isNotEmpty && (o.kind == OutletKind.dripper || o.kind == OutletKind.bubbler)).firstOrNull;
        final nz = dripper?.nozzles.first;
        final headM = nz?.defaultHeadM ?? 10;
        double flow() {
          if (kind == RingKind.dripline) {
            final tp = cat.tape(tapeSpec);
            return tp == null || !(tp.emitterSpacingM > 0) ? 0 : r.ringLength / tp.emitterSpacingM * tp.emitter.flow(tapeInlet);
          }
          return nz == null ? 0 : r.dripperCount * nz.curve.flow(headM);
        }

        final made = b.change('tree_rings', () {
          final p = b.p;
          final out = r.toEntities(
            p,
            tapeSpecId: tapeSpec,
            tapeInletHeadM: tapeInlet,
            outletSpecId: dripper?.id,
            nozzleId: nz?.id,
            headM: headM,
            valveSpecId: pickZoneValve(p.catalog, flow())?.id,
            zoneName: a.str('zone_name') ?? zoneNames(p, t('name.zone'), 1).first,
            lateralPipeSpecId: s.lateralPipeSpecId,
          );
          p.entities.addAll(out);
          return out;
        });
        c.select(made.map((e) => e.id));
        return ToolOutput('${r.trees.length} trees, ${kind.name} rings, zone flow ${m3h(flow())}.\n${_made(b, made)}${_warn(b, r.messages)}');
      },
    ),
    FnTool(
      name: 'sports_template',
      effect: ToolEffect.write,
      description: 'Sprinkler templates for sports turf and golf, centred on center and turned by rotation_deg: a football pitch (3 to 5 rows of heads along the touchlines, as few as the family\'s largest nozzle reaches across), a running-track infield and a tee (laid out as lawns), a golf green (rotors round its outline, a closed area given or an ellipse length × width, opening onto it) or a fairway along a centreline of the given length (staggered rows). Adds the heads and the turf area outline (not for a green on an existing area); zones, valves and pipes come next (layout_sprinklers with routing does all for an area). One undo step; the heads become the selection. Returns the head count, the uniformity of the pattern and the total flow.',
      inputSchema: obj(
        {
          'kind': str(null, ['pitch', 'track', 'green', 'tee', 'fairway']),
          'center': {...point, 'description': '[x, y] in metres; default the centre of the view (or of the drawing).'},
          'rotation_deg': num_('Long axis, degrees counter-clockwise from east (default 0).'),
          'length_m': num_('1–5000 m; defaults: pitch 105, green 30, tee 30, fairway 300.'),
          'width_m': num_('1–1000 m; defaults: pitch 68, green 22, tee 8, fairway 35.'),
          'area': str('green: id or name of a closed area to use as the green.'),
          'outlet': str('Sprinkler family id; default the last used, else the rotor.'),
          'head_m': num_('Pressure at the heads, 0–120 m; default the family\'s nominal.'),
        },
        required: ['kind'],
      ),
      summary: (i) => t('ai.do.template', {'n': '${i['kind']}'}),
      handler: (i) async {
        final a = ToolArgs(i);
        final kind = a.str('kind', required: true)!;
        final family = _family(b, a.str('outlet'));
        final centre = a.point('center') ?? (c.camera.size.isEmpty ? (b.p.bounds.isEmpty ? Pt.zero : b.p.bounds.center) : c.camera.center);
        final rot = a.number('rotation_deg') ?? 0;
        final headM = a.number('head_m', min: 0, max: 120) ?? 0;
        double len(double d) => a.number('length_m', min: 1, max: 5000) ?? d;
        double wid(double d) => a.number('width_m', min: 1, max: 1000) ?? d;
        final opts = LandscapeLayoutOptions(headM: headM);
        final greenArea = a.has('area') ? _outline(b, a.str('area')!) : null;
        final l = await _soon(
          () => switch (kind) {
            'pitch' => sportsPitchLayout(
              family: family,
              length: len(105),
              width: wid(68),
              rows: 0,
              origin: centre - Pt(len(105) / 2, wid(68) / 2).rotate(degToRad(rot)),
              rotationDeg: rot,
              headM: headM,
            ),
            'track' => runningTrackInfieldLayout(family: family, center: centre, rotationDeg: rot, options: opts),
            'green' => golfGreenLayout(
              family: family,
              green: greenArea ?? ellipseOutline(centre, len(30), wid(22), rotationDeg: rot),
              headM: headM,
            ),
            'tee' => teeLayout(family: family, length: len(30), width: wid(8), center: centre, rotationDeg: rot, options: opts),
            _ => fairwayLayout(family: family, centreline: [centre - Pt.polar(len(300) / 2, degToRad(rot)), centre + Pt.polar(len(300) / 2, degToRad(rot))], width: wid(35), headM: headM),
          },
        );
        if (l.heads.isEmpty) throw ToolInputError('No head fits.${_warn(b, l.messages)}');
        final made = b.change('sports_template', () {
          final p = b.p;
          final out = <Entity>[...l.toOutlets(p), if (greenArea == null && l.region.outline.length >= 3) AreaEntity(id: p.newId(), points: List.of(l.region.outline), name: t('tpl.$kind'))];
          p.entities.addAll(out);
          return out;
        });
        c.select(made.map((e) => e.id));
        final m = l.metrics;
        return ToolOutput('${l.heads.length} heads${m == null ? '' : ', CU ${fmt(m.cu, 1)} %, DU ${fmt(m.du, 1)} %'}, total ${m3h(l.totalFlow)}.\n${_made(b, made)}${_warn(b, l.messages)}');
      },
    ),
    FnTool(
      name: 'fit_pivot',
      effect: ToolEffect.write,
      description: 'Places the largest centre pivot a field holds: a full circle or, with sector true, a part circle of at least 30°, built from standard span lengths, keeping clear of the other closed shapes inside or across the field and 10 m from the symbols (trees, posts) inside it; terrain points are no obstacle. The machine takes the depth, hours per cycle and end pressure of the pivot tool settings (change them with update_entities). Join its centre to the mainline (a mainline pipe ending at the centre) before run_design. One undo step. Returns the pivot id, centre, machine length, irrigated radius, sweep, area and the share of the field covered.',
      inputSchema: obj(
        {
          'area': str('Id or name of the field (a closed shape).'),
          'sector': bool_('Allow a part circle when it covers more (default false).'),
          'end_throw_m': num_('Throw of the end sprinkler or gun beyond the machine, 0–80 m (default 5).'),
        },
        required: ['area'],
      ),
      summary: (i) => t('ai.do.pivot', {'n': '${i['area']}'}),
      handler: (i) async {
        final a = ToolArgs(i);
        final ref = a.str('area', required: true)!;
        final field = _outline(b, ref);
        final self = b.find(ref).id;
        // shapes that hold the whole field (a property line, a second outline
        // of it) are no obstacles, nor are elevation points
        final others = [
          for (final e in b.p.entities)
            if (e.id != self && e.bounds.intersects(Bounds.ofPoints(field)))
              if (outlineOf(e) case final o? when !field.every((q) => pointInPolygon(q, o))) o,
        ];
        final pts = [
          for (final e in b.p.entities)
            if (e is SymbolEntity && pointInPolygon(e.position, field)) e.position,
        ];
        final o = PivotFitOptions(
          obstacles: others.where((x) => !identical(x, field)).toList(),
          pointObstacles: [for (final q in pts) PointObstacle(q, 10)],
          endThrowM: a.number('end_throw_m', min: 0, max: 80) ?? 5,
          minSweepDeg: 30,
        );
        final fit = await _soon(() => (a.flag('sector') ?? false) ? fitSectorPivot(field, o) : fitFullCirclePivot(field, o));
        if (fit.spans == null) throw ToolInputError('No pivot fits.${_warn(b, fit.messages)}');
        final s = c.toolSettings;
        final made = b.change('fit_pivot', () {
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
        return ToolOutput(
          'Pivot ${made.id}: centre ${AgentToolbox.pt(fit.center)}, machine ${fmt(fit.machineLength, 1)} m, irrigated radius ${fmt(fit.irrigatedRadius, 1)} m, ${fit.fullCircle ? 'full circle' : 'sector ${fmt(fit.sectorSweepDeg, 0)}°'}, ${fmt(fit.area / 1e4, 2)} ha = ${fmt(fit.coverage * 100, 1)} % of the field. Connect its centre to the mainline, then run_design.${_warn(b, fit.messages)}',
        );
      },
    ),
    FnTool(
      name: 'create_vegetation_areas',
      effect: ToolEffect.write,
      description: 'Detects the vegetated areas (turf, trees and shrubs) in the aerial base map of the view or of a bbox and adds them as irrigated areas with crop presets, plus closed outlines of the holes to keep dry (buildings, pools, paving). The image analysis runs in the program on the aerial imagery: the user\'s aerial base map when one is on screen, else the satellite imagery (the user\'s choice of base map is not changed). Needs a georeferenced project (set_site). One undo step. Returns the areas (id, name, ha), the outlines and the share of the image found vegetated; check them with view_snapshot and delete or edit what is wrong.',
      inputSchema: obj({
        'bbox': {...bbox, 'description': '[minX, minY, maxX, maxY] in metres; default the view.'},
        'min_area_m2': num_('Smallest area kept, 0.5–1e6 m² (default 5).'),
        'turf': bool_('Keep lawns and turf (default true).'),
        'trees': bool_('Keep trees and shrubs (default true).'),
        'threshold_offset': num_('−0.2 … 0.2 (default 0): below 0 finds more vegetation, above 0 less.'),
        'exclusions': bool_('Add the holes as outlines (default true).'),
      }),
      summary: (_) => t('ai.do.vegetation'),
      handler: (i) async {
        final a = ToolArgs(i);
        // the satellite imagery even when the screen shows another map or none
        final aerial = c.baseMap == BaseMap.satellite || c.baseMap.name == 'googleSatellite' || c.baseMap.name == 'googleHybrid';
        final got = await fetchBaseMap(c, a.has('bbox') ? bboxOf(i['bbox']) : null, map: aerial ? null : (c.project.meta.georef != null ? BaseMap.satellite : null));
        if (got == null) throw ToolInputError('No aerial image: the satellite or aerial base map needs a georeference (set_site), and its imagery must load (offline?).');
        final o = VegetationOptions(
          minAreaM2: a.number('min_area_m2', min: 0.5, max: 1e6) ?? 5,
          keepTurf: a.flag('turf') ?? true,
          keepTrees: a.flag('trees') ?? true,
          thresholdOffset: a.number('threshold_offset', min: -0.2, max: 0.2) ?? 0,
        );
        final r = await _soon(() => detectVegetation(VegetationImage.fromEncoded(got.$1, got.$2), o));
        if (r.patches.isEmpty) throw ToolInputError('No vegetation found (${fmt(r.vegetatedFraction * 100, 1)} % of the image looked vegetated). Try threshold_offset below 0, or another view.');
        final made = b.change('create_vegetation_areas', () {
          final out = vegetationEntities(
            b.p,
            r.patches,
            name: (cls) => t('veg.name.${cls.name}'),
            exclusionName: (area, n) => t('veg.name.exclusion', {'n': '$n', 'a': area}),
            exclusions: a.flag('exclusions') ?? true,
          );
          b.p.entities.addAll(out);
          return out;
        });
        final areas = made.whereType<AreaEntity>().toList();
        return ToolOutput(
          '${areas.length} areas (${areas.map((x) => '${x.id} ${x.name} ${fmt(polygonArea(x.points).abs() / 1e4, 3)} ha').take(40).join('; ')}), ${made.length - areas.length} exclusion outlines; ${fmt(r.vegetatedFraction * 100, 1)} % of the image vegetated${r.patches.any((p) => p.touchesEdge) ? '; some areas touch the image edge (look wider to get them whole)' : ''}.${r.messages.isEmpty ? '' : ' Notes: ${r.messages.map((m) => m.code).join(', ')}.'}',
        );
      },
    ),
    FnTool(
      name: 'rank_pumps',
      description: 'Ranks the catalogue pumps for the duty the design found at a water supply: the flow and pressure of its worst system flow, with the other flows\' duties and the static lift. Suitable pumps first (the duty within the curve\'s range; only submersibles when the water is deeper than a surface pump can lift, about 7 m at sea level), then by life-cycle cost (price plus energy over the economic life at hoursPerYear and powerCostPerKwh). Needs design results. Read-only. Returns the duty and the best 10: head at the duty, margin, shaft power, annual energy, in range, suction ok and pumps in parallel. apply_pump installs one.',
      inputSchema: obj({'supply': str('Id or name of the water supply; default the first.')}),
      summary: (_) => t('design.pumpSelect'),
      handler: (i) async {
        _needResults(c);
        final s = _supply(b, ToolArgs(i).str('supply'));
        final r = c.results!;
        final pd = worstPumpDuty(r, s.id);
        if (pd == null) throw ToolInputError('The design has no duty for this supply.');
        final p = b.p.params;
        final cands = rankPumps(
          b.p.catalog,
          flow: pd.supply.flow,
          head: pd.head,
          staticHead: staticLift(b.p, r, s, pd.supply),
          hoursPerYear: p.hoursPerYear,
          costPerKwh: p.powerCostPerKwh,
          otherDuties: [
            for (final d in pumpDuties(r, s.id))
              if (d.flowName != pd.flowName) (d.supply.flow, d.head),
          ],
          requireSubmersible: suctionLiftTooDeep(s, pd.supply),
          mainsHz: p.mainsHz,
        );
        if (cands.isEmpty) return const ToolOutput('No catalogue pump fits this duty.');
        return ToolOutput(
          'Duty: ${m3h(pd.supply.flow)} at ${fmt(pd.head, 1)} m (${pd.flowName}).\nid | name | head at duty m | margin m | shaft kW | energy/year | in range | suction ok | parallel\n${[for (final x in cands.take(10)) '${x.spec.id} | ${x.spec.name} | ${fmt(x.headAtDuty, 1)} | ${fmt(x.margin, 1)} | ${fmt(x.shaftPowerKw, 2)} | ${fmt(x.annualEnergy, 0)} | ${x.inRange} | ${x.suctionOk} | ${x.parallelCount}'].join('\n')}',
        );
      },
    ),
    FnTool(
      name: 'apply_pump',
      effect: ToolEffect.write,
      description: 'Installs a pump for a water supply: the catalogue pump given, or the one with the lowest life-cycle cost that meets every system flow\'s duty. The pump nearest the supply within 50 m gets the new model; without one, a pump is added on the mainline pipe leaving the supply (1.5 m along it), or 2 m east of the supply when no mainline starts there (then join it). Needs design results; one undo step; run the design again to see its operating point.',
      inputSchema: obj({'supply': str('Id or name of the water supply; default the first.'), 'pump': str('Pump id (search_catalog kind "pump"); default: the best for the duty.')}),
      summary: (i) => t('ai.do.pump', {'n': '${i['pump'] ?? '★'}'}),
      handler: (i) async {
        _needResults(c);
        final a = ToolArgs(i);
        final s = _supply(b, a.str('supply'));
        final id = a.str('pump');
        if (id == null) {
          final res = b.change('apply_pump', () => choosePumpFor(b.p, c.results!, s));
          return ToolOutput('${res.ok ? 'Done' : 'Not done'}: ${t(res.key, res.args)}. Run the design again.', isError: !res.ok);
        }
        final spec = b.p.catalog.pump(id);
        if (spec == null) throw ToolInputError('Unknown pump "$id".');
        final near = b.p.entities.whereType<PumpEntity>().where((x) => x.position.distanceTo(s.position) < 50).toList()
          ..sort((x, y) => x.position.distanceTo(s.position).compareTo(y.position.distanceTo(s.position)));
        if (near.isNotEmpty) {
          b.change('apply_pump', () => near.first.pumpSpecId = spec.id);
          return ToolOutput('Pump ${near.first.id} is now ${spec.name}. Run the design again.');
        }
        final main = b.p.entities
            .whereType<PipeEntity>()
            .where((x) => x.scope == HydraulicScope.mainline && x.points.length >= 2 && (x.points.first.distanceTo(s.position) < 0.5 || x.points.last.distanceTo(s.position) < 0.5))
            .firstOrNull;
        final pos = main == null
            ? s.position + const Pt(2, 0)
            : () {
                final from = main.points.first.distanceTo(s.position) < 0.5 ? main.points.first : main.points.last;
                final to = identical(from, main.points.first) ? main.points[1] : main.points[main.points.length - 2];
                final d = to - from;
                return from + d * (math.min(1.5, d.length * 0.5) / math.max(d.length, 1e-9));
              }();
        final e = b.change('apply_pump', () {
          final x = PumpEntity(id: b.p.newId(), position: pos, pumpSpecId: spec.id);
          b.p.entities.add(x);
          return x;
        });
        return ToolOutput(
          'Added pump ${e.id} (${spec.name}) at ${AgentToolbox.pt(pos)}${main == null ? ': connect it between the supply and the mainline' : ' on the mainline'}. Run the design again.',
        );
      },
    ),
    FnTool(
      name: 'suggest_air_valves',
      description:
          'Studies the mainline for air valves after AWWA M51: where they go (${AirValveReason.values.map((r) => r.code).join(', ')}, and every max_spacing_m along long runs), the type (${AirValveType.values.map((x) => x.name).join(', ')}) and the catalogue model of each, marking those already drawn. Uses the transient results when an analysis ran. Read-only. Returns each position with its chainage, pipe, reasons and model, existing or MISSING; insert_air_valves adds the missing ones.',
      inputSchema: obj({'max_spacing_m': num_('Longest run without an air valve, 50–5000 m (default 800).')}),
      summary: (_) => t('av.menu'),
      handler: (i) async {
        final st = await _soon(() => _airStudy(b, ToolArgs(i)));
        final missing = st.missing;
        return ToolOutput(
          '${st.suggestions.length} positions, ${missing.length} without a valve yet${st.usedTransient ? ' (transient results used)' : ''}.\n${[for (final v in st.suggestions.take(40)) '${v.existing ? 'existing' : 'MISSING'} ${v.type.name} at ${AgentToolbox.pt(v.position)} chainage ${fmt(v.chainage, 0)} m, pipe ${v.pipeEntityId ?? '-'}, ${v.reasons.map((x) => x.code).join('/')}, spec ${v.specId ?? 'none in the catalogue'}'].join('\n')}${_warn(b, st.messages)}',
        );
      },
    ),
    FnTool(
      name: 'insert_air_valves',
      effect: ToolEffect.write,
      description: 'Inserts, as devices on the mainline, the air valves suggest_air_valves reports as missing that have a catalogue model (those without one are left out). One undo step; the design results are discarded. Returns the items added.',
      inputSchema: obj({'max_spacing_m': num_('As for suggest_air_valves, 50–5000 m (default 800).')}),
      summary: (_) => t('ai.do.airValves'),
      handler: (i) async {
        final st = await _soon(() => _airStudy(b, ToolArgs(i)));
        final missing = [
          for (final v in st.missing)
            if (v.specId != null) v,
        ];
        if (missing.isEmpty) return const ToolOutput('No air valve to insert.');
        final made = b.change('insert_air_valves', () {
          final list = airValveEntities(missing, b.p.newId);
          b.p.entities.addAll(list);
          return list;
        });
        return ToolOutput(_made(b, made));
      },
    ),
    FnTool(
      name: 'run_analysis',
      description: 'Runs one analysis of the current design and returns its summary; nothing in the drawing changes. "transients": water hammer when each valve closes (method of characteristics): worst surge, pipes above their class, vacuum below −5 m. "eps": a 24-hour simulation of the system flows at their start hours: energy, cost, volume, pump hours and power hour by hour. "criticality": the single pipe failures that cut demand off, in the largest system flow. "on_demand": Clément peak flows for on-demand hydrants and a check of 200 random configurations. "energy_grouping": the system flows that need the least energy (apply_energy_grouping sets them). "uniformity": the densogram of the sprinklers (CU, DU, SC, dry area), at the design pressures after a design. criticality, on_demand and energy_grouping need design results; the others use them when present.',
      inputSchema: obj(
        {
          'kind': str(null, ['transients', 'eps', 'criticality', 'on_demand', 'energy_grouping', 'uniformity']),
        },
        required: ['kind'],
      ),
      summary: (i) => t('ai.tool.analysis', {'n': '${i['kind']}'}),
      handler: (i) async => ToolOutput(await _analysis(b, ToolArgs(i).str('kind', required: true)!)),
    ),
    FnTool(
      name: 'apply_energy_grouping',
      effect: ToolEffect.write,
      description: 'Replaces the system flows with the least-energy grouping (run_analysis "energy_grouping"), each flow within the supplies\' flow, starting at the earliest start hour of the current flows (6 without flows). Needs design results; one undo step; the results are discarded. Returns the flows set and the energy per round against the current flows.',
      inputSchema: obj({'max_hours': num_('Longest time all the flows together may take, 1–168 h (default 24).')}),
      summary: (_) => t('eg.menu'),
      handler: (i) async {
        _needResults(c);
        final g = await _soon(() => _grouping(b, ToolArgs(i).number('max_hours', min: 1, max: 168) ?? 24));
        if (g.$1.groups.isEmpty) throw ToolInputError('No grouping found.');
        final start = b.p.systemFlows.isEmpty ? 6.0 : b.p.systemFlows.map((f) => f.startHour).reduce(math.min);
        final n = b.change('apply_energy_grouping', () {
          final next = systemFlowsFromGroups(b.p, g.$1.groups, firstStartHour: start, label: t.call);
          b.p.systemFlows
            ..clear()
            ..addAll(next);
          return next.length;
        });
        return ToolOutput('$n system flows set (${fmt(g.$1.energyKwh, 0)} kWh/day against ${fmt(g.$2, 0)} now). Run the design again.');
      },
    ),
    FnTool(
      name: 'route_wires',
      effect: ToolEffect.write,
      description: 'Routes the valve wiring along the pipe trenches (mainline pipes and, by default, zone pipes; never laterals) from the controllers: every zone valve, master valve (a master or control valve device on the mainline) and pump-start relay joins the controller nearest along the trenches and gets a station: the zone valves first, by distance, and after them each valve-in-head station, master valve and relay; an item off the pipes joins through a short stub. The routes become wire items, replacing those drawn (unless replace is false), in one undo step; the design then checks the wire sizes and the voltage at each solenoid. Needs a controller (create_entities type "controller" {p, st}) and pipes. Returns, per controller, the stations used against its st (more than it has: raise st, add a controller, or apply the elec_stations correction), the station list and the routing notes.',
      inputSchema: obj({
        'mode': str('"shortest_paths" (default): each valve by its shortest trench path, for one conductor per station; "steiner": the shortest total route, for a two-wire decoder system.', [
          'shortest_paths',
          'steiner',
        ]),
        'include_zone_pipes': bool_('Zone pipes are trenches too (default true).'),
        'master_valve_stations': bool_('Master valves take stations after the zone valves (default true; false = the controller\'s dedicated terminal).'),
        'pump_relay_stations': bool_('Pump-start relays take stations (default true; false = the dedicated terminal).'),
        'max_stub_m': num_('Stubs longer than this from an item to the nearest pipe are reported, 0–1000 m (default 30).'),
        'replace': bool_('Remove the wire routes already drawn (default true).'),
      }),
      summary: (_) => t('wr.menu'),
      handler: (i) async {
        final a = ToolArgs(i);
        final options = WireRoutingOptions(
          mode: a.str('mode') == 'steiner' ? RoutingMode.steiner : RoutingMode.shortestPaths,
          includeZonePipes: a.flag('include_zone_pipes') ?? true,
          masterValveStations: a.flag('master_valve_stations') ?? true,
          pumpRelayStations: a.flag('pump_relay_stations') ?? true,
          maxStubM: a.number('max_stub_m', min: 0, max: 1000) ?? 30,
          tolerance: math.max(b.p.params.connectTolerance, 0.1),
        );
        final replace = a.flag('replace') ?? true;
        final r = await _soon(() => routeProjectWires(b.p, options: options));
        if (r.routes.isEmpty) throw ToolInputError('No route.${_warn(b, r.warnings)}');
        final n = b.change('route_wires', () {
          if (replace) b.p.entities.removeWhere((e) => e is WireEntity);
          final wires = wireEntitiesOf(b.p, r);
          b.p.entities.addAll(wires);
          return wires.length;
        });
        String label(String id) => id.startsWith(vihPrefix) ? demandName(b.p, id) : c.entityName(id);
        final controllers = [
          for (final k in b.p.entities.whereType<ControllerEntity>())
            () {
              final used = r.stations.where((x) => x.controllerId == k.id && x.station > 0).length;
              return '${b.nameOf(k)} (${k.id}): $used stations used of ${k.stations}${used > k.stations ? ', more than it has' : ''}; routes ${fmt(r.routeLengthOf(k.id), 0)} m';
            }(),
        ];
        final stations = [
          for (final x in r.stations.take(80))
            '${c.entityName(x.controllerId)} ${x.station == 0 ? 'dedicated terminal' : 'station ${x.station}'}: ${x.kind.name} ${label(x.entityId)} (${fmt(x.routeM, 0)} m)',
        ];
        return ToolOutput(
          '$n wire routes, ${fmt(r.totalRouteM, 0)} m in all.\n${controllers.join('\n')}\n${stations.join('\n')}${r.stations.length > 80 ? '\n… ${r.stations.length - 80} more' : ''}${_warn(b, r.warnings)}',
        );
      },
    ),
    FnTool(
      name: 'export_file',
      effect: ToolEffect.export,
      description:
          'Saves a file for the user (a download in the browser, a save on the desktop), named after the project: the drawing (${DrawingFormat.values.map((f) => f.name).join(', ')}: pdf is the plot sheet, shp a zipped shapefile, inp EPANET, landxml the terrain and pipes, dxfR12 for older CAD; ${DrawingFormat.values.where((f) => f.needsGeoref).map((f) => f.name).join(', ')} need a georeference), the reports (${ReportFormat.values.map((f) => 'report_${f.name}').join(', ')}: every report table; they need design results) or the project file (project, .oci.json). Export only when the user asks; it is always confirmed by the user. Changes nothing in the project.',
      inputSchema: obj(
        {
          'format': str(null, [for (final f in DrawingFormat.values) f.name, for (final f in ReportFormat.values) 'report_${f.name}', 'project']),
        },
        required: ['format'],
      ),
      summary: (i) => t('ai.do.export', {'n': '${i['format']}'}),
      handler: (i) async {
        final f = ToolArgs(i).str('format', required: true)!;
        if (b.p.entities.isEmpty) throw ToolInputError('The drawing is empty.');
        final name = (b.p.meta.name.trim().isEmpty ? t('name.newProject') : b.p.meta.name.trim()).replaceAll(RegExp(r'[^\w\-]+', unicode: true), '_');
        if (f == 'project') {
          await saveTextFile('$name.oci.json', c.saveJson());
          return ToolOutput('Saved $name.oci.json.');
        }
        if (f.startsWith('report_')) {
          _needResults(c);
          final rf = ReportFormat.values.byName(f.substring(7));
          if (rf == ReportFormat.pdf) await preparePdfFonts(pdfTexts(c, reports: true), language: c.lang);
          final file = '${name}_${t('name.report')}.${rf.extension}';
          await deliverExport(c, file, rf.mime, () => c.exporter().exportReport(rf));
          return ToolOutput('Exported $file.');
        }
        final df = DrawingFormat.values.byName(f);
        if (df.needsGeoref && b.p.meta.georef == null) throw ToolInputError('$f needs a georeference: set_site with the latitude and longitude of the drawing origin, or ask the user.');
        if (df == DrawingFormat.pdf) await preparePdfFonts(pdfTexts(c), language: c.lang);
        final file = '$name.${df.extension}';
        await deliverExport(c, file, df.mime, () => c.exporter().exportDrawing(df));
        return ToolOutput('Exported $file.');
      },
    ),
    FnTool(
      name: 'select_entities',
      description: 'Selects items on the user\'s drawing, to point them out or to prepare the user\'s next action (the properties panel shows the selection; layout_sprinklers routes to a selected mainline pipe). Changes no item. Returns the selection size.',
      inputSchema: obj({'ids': arr(str(), 'Ids or names of the items.'), 'add': bool_('Add to the selection instead of replacing it.')}, required: ['ids']),
      summary: (i) => t('ai.tool.select', {'n': '${(i['ids'] as List?)?.length ?? 0}'}),
      handler: (i) async {
        final a = ToolArgs(i);
        final es = b.findAll(a.strings('ids', required: true));
        c.select(es.map((e) => e.id), add: a.flag('add') ?? false);
        return ToolOutput('${c.selection.length} items selected.');
      },
    ),
    FnTool(
      name: 'zoom_to',
      description:
          'Moves the user\'s view to items, to a bbox or to the whole drawing (a view change; the project is untouched). Pictures for yourself come from view_snapshot without moving the view.',
      inputSchema: obj({'ids': arr(str(), 'Ids or names of the items to frame.'), 'bbox': bbox, 'all': bool_('The whole drawing.')}),
      summary: (_) => t('ai.tool.zoom'),
      handler: (i) async {
        final a = ToolArgs(i);
        if (a.flag('all') ?? false) {
          c.zoomAll();
        } else {
          final box = a.has('bbox') ? bboxOf(i['bbox']) : b.findAll(a.strings('ids', required: true)).fold(Bounds.empty, (Bounds x, e) => x.union(e.bounds));
          if (box.isEmpty) throw ToolInputError('Nothing to zoom to.');
          c.camera.fit(box.inflate(math.max(2.0, 0.05 * math.max(box.width, box.height))));
          c.refresh();
        }
        return const ToolOutput('View moved.');
      },
    ),
    FnTool(
      name: 'show_message',
      description: 'Shows a short message (up to 200 characters) in the program\'s status bar, for a note the user should see outside the chat. Changes nothing.',
      inputSchema: obj({'text': str('The message, in the user\'s language.')}, required: ['text']),
      summary: (_) => t('ai.tool.message'),
      handler: (i) async {
        c.notify(AgentToolbox.short(ToolArgs(i).str('text', required: true)!, 200));
        return const ToolOutput('Shown.');
      },
    ),
  ];
}

WaterSupplyEntity _supply(AgentToolbox b, String? ref) {
  if (ref != null) {
    final e = b.find(ref);
    if (e is! WaterSupplyEntity) throw ToolInputError('"$ref" is not a water supply.');
    return e;
  }
  final s = b.p.entities.whereType<WaterSupplyEntity>().firstOrNull;
  if (s == null) throw ToolInputError('The drawing has no water supply.');
  return s;
}

AirValveStudy _airStudy(AgentToolbox b, ToolArgs a) {
  final c = b.c;
  final m = MainlineFlows(b.p, results: c.results, label: c.t.call);
  final max = a.number('max_spacing_m', min: 50, max: 5000) ?? 800;
  return suggestMainlineAirValvesOn(
    m,
    options: AirValveOptions(maxSpacing: max, minSpacing: max / 2, preferCombination: true, barometricHead: atmosphericHead(m.siteElevation)),
  );
}

(EnergyGroupingResult, double) _grouping(AgentToolbox b, double maxHours) {
  final c = b.c;
  final p = b.p, r = c.results!, d = opsDesigner(p, r, label: c.t.call);
  final (zones, source) = energyZonesWithPivots(d, r);
  if (zones.isEmpty) throw ToolInputError('No zone to group.');
  final maxFlow = math.max(suppliesDesignFlow(p), [for (final f in r.systemFlows) f.totalFlow, for (final z in zones) z.flow].fold(0.0, math.max)) * (1 + 1e-9);
  double head(List<EnergyZone> g) => designerGroupHead(d, g.map((z) => z.id));
  final g = groupZonesForEnergy(
    zones,
    options: GroupingOptions(maxFlow: maxFlow, maxHours: maxHours, sourceElevation: source, pumpEfficiency: p.params.pumpEfficiency),
    groupHead: head,
  );
  final now = groupingEnergyKwh([for (final f in d.effectiveSystemFlows()) f.valveIds], zones, head, efficiency: p.params.pumpEfficiency);
  return (g, now);
}

Future<String> _analysis(AgentToolbox b, String kind) async {
  final c = b.c;
  final p = b.p;
  final u = b.u;
  String head(double h) => '${fmt(u.pressureFromHead(h), 1)} ${u.pressureLabel}';
  switch (kind) {
    case 'transients':
      final study = TransientStudy(p, results: c.results, label: c.t.call);
      final runs = <TransientRun>[];
      for (final j in study.jobs) {
        runs.add(study.run(j));
        await Future<void>.delayed(Duration.zero);
      }
      final a = TransientStudy.combine(runs);
      final ran = a.runs.where((r) => r.ran).toList();
      final over = a.pipes.where((x) => x.overRating).toList();
      final low = a.pipes.where((x) => x.minPressure < -5).toList();
      return '${ran.length} of ${a.runs.length} scenarios ran.${ran.isEmpty ? '' : ' Worst surge ${head(ran.map((r) => r.maxSurge).reduce(math.max))}.'}\nPipes above their pressure class: ${over.isEmpty ? 'none' : over.take(15).map((x) => '${x.pipeName} (${c.entityName(x.entityId)}) max ${head(x.maxPressure)} vs class ${head(x.rating)}').join('; ')}.\nPipes with pressures below −5 m (vacuum risk): ${low.isEmpty ? 'none' : low.take(10).map((x) => '${c.entityName(x.entityId)} min ${head(x.minPressure)}').join('; ')}.${_warn(b, a.messages.take(20))}';
    case 'eps':
      final d = simulateDayOn(
        MainlineFlows(p, results: c.results, label: c.t.call),
        options: EpsDayOptions(pricePerKwh: p.params.powerCostPerKwh),
      );
      return 'Day: ${fmt(d.energyKwh, 1)} kWh, ${fmt(d.cost, 2)} ${p.params.currency}, ${fmt(d.volume, 0)} m³${d.converged ? '' : ', not converged'}.\nPumps: ${d.pumps.isEmpty ? 'none' : d.pumps.map((x) => '${c.entityName(x.entityId)} ${fmt(x.hoursOn, 1)} h, ${fmt(x.energyKwh, 1)} kWh, peak ${fmt(x.maxPowerKw, 1)} kW').join('; ')}.\nHours with flow: ${[for (final h in d.hours)
        if (h.flow > 0) '${h.hour}h ${AgentToolbox.m3h(h.flow)} ${fmt(h.powerKw, 1)} kW'].join(', ')}.${_warn(b, d.messages.take(20))}';
    case 'criticality':
      _needResults(c);
      final r = c.results!, d = opsDesigner(p, r, label: c.t.call);
      final flows = d.effectiveSystemFlows();
      if (flows.isEmpty) throw ToolInputError('No system flow.');
      final v = criticalityOf(d, r, flows.firstWhere((f) => f.id == _largestFlow(flows, r)));
      if (v == null) throw ToolInputError('No water supply.');
      final total = v.result.totalDemand;
      return v.rows.isEmpty
          ? 'No single pipe failure leaves a demand short.'
          : 'Most critical pipes (share of the demand lost):\n${v.rows.take(20).map((x) => '${c.entityName(x.entityId)}: ${fmt(total > 0 ? 100 * x.scenario.lostDemand / total : 0, 1)} %, cuts off ${x.cutOff.take(6).map((id) => demandName(p, id)).join(', ')}').join('\n')}';
    case 'on_demand':
      _needResults(c);
      final m = onDemandModel(p, c.results!, label: c.t.call);
      if (m == null || m.hydrants.isEmpty) throw ToolInputError('No supply or no demands on the mainline.');
      final cl = clementFlows(m.network, m.hydrants, options: const ClementOptions());
      final rows = onDemandPipeRows(m, cl);
      final check = checkRandomConfigurations(onDemandCheckNetwork(m, m.supplyPressure), m.hydrants, probabilities: cl.probabilities, options: const RandomCheckOptions(configurations: 200));
      final source = cl.sourceFlow.values.fold(0.0, (s, x) => s + x);
      return 'Clément source flow ${AgentToolbox.m3h(source)} (peak of the system flows ${AgentToolbox.m3h(c.results!.systemFlows.fold(0.0, (mx, f) => math.max(mx, f.totalFlow)))}); ${rows.where((x) => x.ratio > 1).length} pipes would carry more than their design flow; random check: ${fmt(check.satisfiedShare * 100, 1)} % of ${check.configurations} configurations satisfied.';
    case 'energy_grouping':
      _needResults(c);
      final (g, now) = _grouping(b, 24);
      return 'Least-energy grouping: ${g.groups.length} flows, ${fmt(g.energyKwh, 1)} kWh per round against ${fmt(now, 1)} kWh with the current flows (${fmt(g.energyKwh * p.params.powerCostPerKwh, 2)} vs ${fmt(now * p.params.powerCostPerKwh, 2)} ${p.params.currency}).\n${[for (final x in g.groups) '${x.zoneIds.map((id) => demandName(p, id)).join(' + ')}: ${AgentToolbox.m3h(x.flow)}, ${fmt(x.head, 1)} m, ${fmt(x.hours, 2)} h'].join('\n')}\napply_energy_grouping sets them.';
    default:
      final d = c.densogram;
      if (d.isEmpty) return c.t('dens.none');
      final s = d.stats;
      return 'Uniformity of the sprinklers${d.fromResults ? ' (design pressures)' : ' (nominal pressures: run the design for real ones)'}: mean ${fmt(s.mean, 1)} mm/h (${fmt(s.min, 1)}–${fmt(s.max, 1)}), CU ${fmt(s.cu, 1)} %, DU ${fmt(s.du, 1)} %, SC ${fmt(s.sc, 2)}, dry ${fmt(s.dryPct, 1)} % of ${fmt(s.areaM2 / 1e4, 3)} ha.${d.areas.isEmpty ? '' : '\nBy area: ${d.areas.map((x) => '${x.name}: CU ${fmt(x.stats.cu, 1)} %, DU ${fmt(x.stats.du, 1)} %').join('; ')}'}';
  }
}
