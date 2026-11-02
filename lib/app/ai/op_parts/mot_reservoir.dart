/// Operations added in 1.6.0 (MOT+) for reservoirs, dams and air vessels
/// drawn in the project (PRD-16, PRD-31), joined to [opsMot].
library;

import '../../../core/ai/agent_loop.dart';
import '../../../core/design/reservoir.dart';
import '../../../core/model/entities.dart';
import '../agent_tools.dart';
import '../ops_eng_common.dart';

List<AgentTool> opsMotReservoir(AgentToolbox b) {
  final c = b.c;
  WaterSupplyEntity supplyOf(String ref) {
    final e = b.find(ref);
    if (e is! WaterSupplyEntity) throw ToolInputError('${e.id} is not a water supply.');
    return e;
  }

  return [
    engOp(
      b,
      name: 'set_reservoir',
      effect: ToolEffect.write,
      description:
          'Water supply → Reservoir…: makes a water supply take its water from a reservoir or dam drawn as a closed polyline or an area (the water line at the full level). kind "terrain" = a dam or a pond, the basin is the ground of the terrain model inside the outline; "excavated" = a flat bottom (bottom_m) with the sides sloping up to the outline (side_slope horizontal per vertical). The design pumps from min_level_m (the worst case); the 24-hour simulation (Mainline → 24 h) lets the level fall from initial_level_m with what the supply delivers and rise with inflow_m3h; reservoir_study gives its stage–area–volume curve, usable volume, cut, days of demand and filling time. Inputs: supply (id or name), outline (id or name), kind, full_level_m, min_level_m, initial_level_m, bottom_m, side_slope, inflow_m3h (only those given change), remove (true takes the reservoir off). One undo step; results discarded.',
      schema: obj({
        'supply': str('Water supply id or name.'),
        'outline': str('Id or name of the closed polyline or area that bounds the water at the full level.'),
        'kind': str('"terrain" (dam or pond) or "excavated" (flat bottom, sloping sides).', ['terrain', 'excavated']),
        'full_level_m': num_('Elevation of the full water level (m).'),
        'min_level_m': num_('Elevation of the lowest level the intake draws from (m); default the bottom.'),
        'initial_level_m': num_('Elevation of the water at the start of the day (m); default full.'),
        'bottom_m': num_('Excavated: elevation of the flat bottom (m); default 3 m below the full level.'),
        'side_slope': num_('Excavated: side slope, horizontal per vertical, 0–20 (default 2).'),
        'inflow_m3h': num_('Water flowing in all the time, m³/h (a stream, a spring, a well).'),
        'remove': bool_('true takes the reservoir off the supply.'),
      }, required: ['supply']),
      summary: (i) => b.t('ai.op.set_reservoir', {'n': '${i['supply'] ?? ''}'}),
      run: (a, i) async {
        engNotBusy(c);
        final s = supplyOf(a.str('supply', required: true)!);
        if (b.p.isLocked(s.layer)) throw ToolInputError('${s.id} is on the locked layer "${s.layer}".');
        if (a.flag('remove') ?? false) {
          b.change('set_reservoir', () {
            s.reservoir = null;
            return 1;
          });
          return ToolOutput('${s.id}: no reservoir now. Results discarded: run the design again.');
        }
        final r = s.reservoir?.copy() ?? ReservoirSpec(fullLevelM: b.terrain.elevationAt(s.position) + s.waterLevelOffsetM);
        final outline = a.str('outline');
        if (outline != null) {
          final e = b.find(outline);
          if (e is! AreaEntity && !(e is PolylineEntity && e.points.length >= 3)) throw ToolInputError('${e.id} is not a closed polyline or an area.');
          r.outlineId = e.id;
        }
        final kind = a.str('kind');
        if (kind != null) r.kind = ReservoirKind.values.firstWhere((k) => k.name == kind, orElse: () => throw ToolInputError('"kind" must be terrain or excavated.'));
        r.fullLevelM = a.number('full_level_m', min: -500, max: 9000) ?? r.fullLevelM;
        if (a.has('min_level_m')) r.minLevelM = a.number('min_level_m', min: -500, max: 9000);
        if (a.has('initial_level_m')) r.initialLevelM = a.number('initial_level_m', min: -500, max: 9000);
        if (a.has('bottom_m')) r.bottomM = a.number('bottom_m', min: -500, max: 9000);
        r.sideSlope = a.number('side_slope', min: 0, max: 20) ?? r.sideSlope;
        final q = a.number('inflow_m3h', min: 0, max: 1e6);
        if (q != null) r.inflow = q / 3600;
        if (r.outlineId.isEmpty) throw ToolInputError('Give "outline": the closed polyline or area of the reservoir.');
        b.change('set_reservoir', () {
          s.reservoir = r;
          return 1;
        });
        final st = reservoirStudy(b.p, s);
        return ToolOutput(
          '${s.id}: reservoir ${r.kind.name} bounded by ${r.outlineId}, full at ${engN(r.fullLevelM, 2)} m${st == null || st.curve.isEmpty ? '' : '; bottom ${engN(st.bottom, 2)} m, ${engN(st.volume, 0)} m³ full, ${engN(st.usableVolume, 0)} m³ usable'}. Results discarded: run the design again.${engCodes(b, st?.messages ?? const [])}',
        );
      },
    ),
    engOp(
      b,
      name: 'reservoir_study',
      description:
          'Water supply → Reservoir…: the stage–area–volume curve of the reservoir or dam of a water supply (set_reservoir) from the terrain model, its bottom, surface, volume full and usable (between the lowest operating and the full level), the earth an excavated one takes out, the water the system flows of the design draw from it in a day, the days of demand it holds (the inflow counted) and the hours the inflow takes to fill it. Read-only. Input: supply (id or name).',
      schema: obj({'supply': str('Water supply id or name.')}, required: ['supply']),
      run: (a, _) async {
        final s = supplyOf(a.str('supply', required: true)!);
        final st = reservoirStudy(b.p, s, results: c.results);
        if (st == null) return ToolOutput('${s.id} has no reservoir (set_reservoir gives it one).');
        if (st.curve.isEmpty) return ToolOutput('${s.id}: the reservoir has no closed outline of three points or more.${engCodes(b, st.messages)}');
        return ToolOutput(
          [
            'Reservoir of ${s.id}: bottom ${engN(st.bottom, 2)} m, full ${engN(st.fullLevel, 2)} m, lowest operating ${engN(st.minLevel, 2)} m; surface ${engN(st.surfaceArea, 0)} m², volume ${engN(st.volume, 0)} m³, usable ${engN(st.usableVolume, 0)} m³${st.cut > 0 ? ', cut ${engN(st.cut, 0)} m³' : ''}.',
            c.results == null
                ? 'No design results: run_design gives the daily demand.'
                : 'Daily demand ${engN(st.dailyDemand, 0)} m³; days of demand ${st.autonomyDays.isFinite ? engN(st.autonomyDays, 1) : 'unlimited (the inflow covers it)'}.',
            if (st.inflow > 0) 'Inflow ${engQ(st.inflow)}: fills the usable volume in ${engN(st.fillHours, 1)} h.',
            engTable(['level m', 'surface m²', 'volume m³'], [
              for (final r in st.curve) [engN(r.level, 2), engN(r.area, 0), engN(r.volume, 0)],
            ]),
          ].join('\n') +
              engCodes(b, st.messages),
        );
      },
    ),
  ];
}
