/// Operations (find_operations / run_operation) added in 1.6.0 for agronomy and the irrigation programme:
/// [OpTool]s built like those of lib/app/ai/ops_cad_*.dart and ops_eng_*.dart,
/// joined to [AgentToolbox.operations].
library;

import 'dart:typed_data';

import '../../../core/ai/agent_loop.dart';
import '../../../core/design/agronomy.dart' show clockText;
import '../../../core/design/catch_cans.dart';
import '../../../core/design/fertigation_stages.dart';
import '../../../core/design/irrigation_programme.dart';
import '../../../core/design/runoff_potential.dart';
import '../../../core/design/soil_water_balance.dart';
import '../../../core/design/system_capacity.dart';
import '../../../core/io/inmet_csv.dart';
import '../../../core/model/agronomy_plan.dart';
import '../../../core/model/entities.dart';
import '../../../core/model/geometry.dart';
import '../agent_tools.dart';
import '../ops_eng_common.dart';

List<AgentTool> opsAgr(AgentToolbox b) {
  final c = b.c;
  final t = b.t;
  AreaEntity area(String? ref) {
    if (ref == null) throw ToolInputError('Missing "area" (id or name of an irrigated area; list_entities type area).');
    final e = b.find(ref);
    if (e is! AreaEntity) throw ToolInputError('"$ref" is not an irrigated area.');
    return e;
  }

  String areaName(AreaEntity a) => a.name.isEmpty ? a.id : a.name;
  String d10(DateTime d) => d.toIso8601String().substring(0, 10);
  return [
    // ---------------------------------------------------------------- daily water balance
    engOp(
      b,
      name: 'water_balance',
      effectFor: (i) => i['save'] == true ? ToolEffect.write : ToolEffect.read,
      description:
          'Design → Agronomy → Daily water balance: the daily soil water balance of the root zone of ONE irrigated area over its season (FAO-56 chapter 8): Kc of its crop (FAO-56 table or user crop, else the Kc typed on the area), ETc,loc = Kr·Kc·ETo, stress Ks once the depletion passes RAW (eq. 84), rain below 0.2·ETo lost, deep percolation above field capacity, irrigation when the depletion reaches the allowed depletion of the stage (RAW unless a regulated deficit is set), every n days or never (rainfed), and the yield response 1 − Ya/Ym = Ky·(1 − ETa/ETc) (FAO-56 eq. 90, Ky of FAO-33). Weather: a typical year of the site climate normals (rain in rain_events equal events a month) or a year of its daily series (download or station file). Inputs: area (id or name, required); trigger depletion|interval|rainfed; interval_days 1–60; allowed_depletion [4 fractions of the total available water for the initial, development, mid-season and late stages; 0 = p, no stress; above p = deficit]; refill_pct 10–100; initial_depletion_pct 0–100; rain_events 1–31; year (0 = typical year); ky 0–3 (0 = the crop\'s); events_limit 1–400 (default 60); save (keep these settings for the area: the report uses them; one undo step). Output: totals (ETc, ETa, rain, effective rain, net and gross irrigation, deep percolation), stress days, relative yield, warnings and the irrigations.',
      schema: obj({
        'area': str('Irrigated area id or name.'),
        'trigger': str('When to irrigate.', [for (final x in BalanceTrigger.values) x.name]),
        'interval_days': int_('Days between irrigations (trigger interval), 1–60.'),
        'allowed_depletion': numbers('Allowed depletion per stage (fraction of TAW; 0 = p).', n: 4),
        'refill_pct': num_('Share of the depletion each irrigation refills, 10–100 %.'),
        'initial_depletion_pct': num_('Depletion at the start, 0–100 % of TAW.'),
        'rain_events': int_('Typical year: rain events a month, 1–31.'),
        'year': int_('Year of the daily series; 0 = typical year.'),
        'ky': num_('Seasonal yield response factor, 0–3; 0 = the crop\'s.'),
        'events_limit': int_('Irrigations listed, 1–400.'),
        'save': bool_('Keep the settings for the area.'),
      }, required: ['area']),
      summary: (i) => t(i['save'] == true ? 'ai.op.water_balance.save' : 'ai.op.water_balance'),
      run: (a, i) async {
        final ar = area(a.str('area'));
        if (!ar.useWaterBalance) throw ToolInputError('${areaName(ar)} has a fixed daily depth, no water balance: set its water balance on (update_entities wb true) with a crop or ETo and Kc.');
        final s = balanceSettingsOf(b.p, ar).copy();
        if (a.has('trigger')) s.trigger = BalanceTrigger.values.byName(a.str('trigger')!);
        s.intervalDays = a.integer('interval_days', min: 1, max: 60) ?? s.intervalDays;
        final mad = engNumbers(i['allowed_depletion'], 'allowed_depletion', length: 4, min: 0, max: 0.95);
        if (mad != null) {
          for (var k = 0; k < 4; k++) {
            s.allowedDepletion[k] = mad[k];
          }
        }
        s.refillPct = a.number('refill_pct', min: 10, max: 100) ?? s.refillPct;
        s.initialDepletionPct = a.number('initial_depletion_pct', min: 0, max: 100) ?? s.initialDepletionPct;
        s.rainEventsPerMonth = a.integer('rain_events', min: 1, max: 31) ?? s.rainEventsPerMonth;
        if (a.has('year')) {
          final y = a.integer('year', min: 0, max: 3000)!;
          if (y != 0 && !balanceYears(b.p).contains(y)) {
            throw ToolInputError(balanceYears(b.p).isEmpty ? 'The site climate has no daily series: download it or import a station file, or use year 0 (typical year).' : 'No complete year $y in the daily series; years: ${balanceYears(b.p).join(', ')}.');
          }
          s.year = y;
        }
        s.ky = a.number('ky', min: 0, max: 3) ?? s.ky;
        final r = areaWaterBalance(b.p, ar, settings: s);
        if (r == null || r.days.isEmpty) throw ToolInputError('No balance for ${areaName(ar)}.');
        if (a.flag('save') ?? false) {
          b.change('water_balance', () {
            b.p.agronomy.balance[ar.id] = s;
            return true;
          }, invalidate: false);
        }
        final y = r.relativeYield;
        final out = [
          '${areaName(ar)}: ${r.days.first.date.toIso8601String().substring(0, 10)} … ${d10(r.days.last.date)} (${r.days.length} days), ${s.year == 0 ? 'typical year of the normals' : 'year ${s.year} of the daily series'}, ${s.trigger.name}${s.deficit ? ' with deficit ${s.allowedDepletion.map((x) => engN(x, 2)).join('/')}' : ''}.',
          'ETc ${engN(r.etcMm, 0)} mm, ETa ${engN(r.etaMm, 0)} mm (${engN(100 * r.relativeEt, 1)} %), rain ${engN(r.rainMm, 0)} mm (effective ${engN(r.effectiveRainMm, 0)}), net irrigation ${engN(r.netMm, 0)} mm, gross ${engN(r.grossMm, 0)} mm (${engN(r.grossMm / 1000 * ar.area, 0)} m³), deep percolation ${engN(r.deepPercolationMm, 0)} mm.',
          '${r.events.length} irrigations, ${r.stressDays} days of stress${y == null ? '' : ', relative yield ${engN(100 * y, 1)} % (Ky ${engN(r.ky!, 2)})'}.',
          if (a.flag('save') ?? false) 'Settings kept for the area (the report shows them).',
          engTable(['date', 'depletion mm', 'net mm', 'gross mm'], [
            for (final e in r.events) [d10(e.date), e.depletionMm, e.netMm, e.grossMm],
          ], max: a.integer('events_limit', min: 1, max: 400) ?? 60),
        ];
        return ToolOutput(out.join('\n') + engCodes(b, r.warnings));
      },
    ),
    // ---------------------------------------------------------------- runoff
    engOp(
      b,
      name: 'runoff_potential',
      description:
          'Design → Agronomy → Runoff potential: the runoff of the sprinkler irrigation against the soil. Machines (centre pivots, linear moves) station by station: mean and peak rate of the elliptical pattern (peak = 4/π of the mean, whatever the speed), the time a pass takes, the runoff of a pass at the design depth against the revised NRCS intake family of the soil (NEH 623 ch. 4, time compression) and its surface storage, the largest depth per pass without runoff and the smallest timer setting that keeps it. Sprinkler areas: their rate against the basic intake rate, the runoff of an event run without pause and the cycle and soak that avoids it. The soil is the class of the area under the pivot point (intake family estimated from NEH 652 Table 2-6) unless family / storage_mm are given. Inputs: pivot (id or name; default every machine), family 0.05–4 in/h, storage_mm 0–50, initial_irrigation (the intake of a first irrigation after tillage instead of later ones; default false). Output: the tables.',
      schema: obj({
        'pivot': str('Pivot or linear id or name; default all.'),
        'family': num_('NRCS intake family (in/h), 0.05–4.'),
        'storage_mm': num_('Surface storage before runoff, 0–50 mm.'),
        'initial_irrigation': bool_('Intake of a first irrigation after tillage.'),
      }),
      run: (a, _) async {
        final machines = a.has('pivot')
            ? [
                () {
                  final e = b.find(a.str('pivot')!);
                  if (e is! PivotEntity) throw ToolInputError('"${a.str('pivot')}" is not a pivot or linear.');
                  return e;
                }(),
              ]
            : b.p.entities.whereType<PivotEntity>().toList();
        final out = <String>[];
        for (final m in machines) {
          var soil = runoffSoilAt(b.p, m.center);
          if (a.has('family') || a.has('storage_mm')) {
            soil = RunoffSoil(family: a.number('family', min: 0.05, max: 4) ?? soil?.family ?? 0.5, surfaceStorageMm: a.number('storage_mm', min: 0, max: 50) ?? soil?.surfaceStorageMm ?? 5, areaId: soil?.areaId);
          }
          final r = soil == null ? null : machineRunoff(b.p, m, soil: soil, results: c.results, laterIrrigations: !(a.flag('initial_irrigation') ?? false));
          if (r == null) {
            out.add('${m.name.isEmpty ? m.id : m.name}: no soil under the pivot point (set the soil of the area, or give family and storage_mm) or no flow.');
            continue;
          }
          out.add('${r.name}: intake family ${engN(r.soil.family, 2)} in/h, surface storage ${engN(r.soil.surfaceStorageMm, 1)} mm${r.depthAt100Mm > 0 ? ', ${engN(r.depthAt100Mm, 1)} mm a pass at 100 %' : ''}.');
          out.add(
            engTable(['radius m', 'mean mm/h', 'peak mm/h', 'pass min', 'depth mm', 'runoff mm', 'runoff %', 'max depth mm', 'min timer %'], [
              for (final w in r.rows) [w.radiusM, w.meanRateMmH, w.peakRateMmH, w.passMinutes, w.depthMm, w.runoffMm, w.runoffPct, w.maxDepthMm, w.minTimerPct == null ? '-' : engN(w.minTimerPct!, 0)],
            ]),
          );
        }
        final zones = zoneRunoff(b.p, results: c.results);
        if (zones.isNotEmpty) {
          out.add('Sprinkler areas:');
          out.add(
            engTable(['area', 'rate mm/h', 'intake mm/h', 'storage mm', 'depth mm', 'run h', 'runoff mm', 'max run min', 'cycles', 'soak min'], [
              for (final z in zones) [z.name, z.rateMmH, z.intakeMmH, z.surfaceStorageMm, z.depthMm, z.runHours, z.runoffMm, z.maxRunMinutes.isFinite ? engN(z.maxRunMinutes, 0) : '∞', z.cycles, z.soakMinutes],
            ]),
          );
        }
        if (out.isEmpty) return ToolOutput('Nothing to analyse: no machine and no sprinkler area with a soil class.');
        return ToolOutput(out.join('\n'));
      },
    ),
    // ---------------------------------------------------------------- capacity
    engOp(
      b,
      name: 'system_capacity',
      description:
          'Design check → capacity against the peak demand: the hours a day every system flow needs on the peak day (the area of its zones that needs most: gross daily volume of the design month over the flow of its emitters), their sum against the irrigation window of the programme (24 h when none is set; irrigation_programme sets it), and every centre pivot or linear move: the depth it applies a day in the window (d·W/T) against the peak gross requirement of the area under it. Uses the design flows when there are results, else the nominal ones. No input. Output: the hours per flow, the total, the machines and whether the system keeps up.',
      schema: obj({}),
      run: (a, _) async {
        final cap = systemCapacity(b.p, results: c.results);
        if (cap.flows.isEmpty && cap.machines.isEmpty) return ToolOutput('No area with a water need watered by a zone or machine.');
        return ToolOutput(
          [
            'Irrigation window ${engN(cap.windowHours, 1)} h a day; the flows need ${engN(cap.totalHours, 2)} h on the peak day: ${cap.flowsFit ? 'they fit' : 'THEY DO NOT FIT'}.',
            for (final f in cap.flows) '- ${f.name.isEmpty ? 'all zones' : f.name}: ${engN(f.hours, 2)} h${f.areaId == null ? '' : ' (area ${engItemName(b, f.areaId)})'}',
            for (final m in cap.machines) '- machine ${m.name}: ${engN(m.capacityMmDay, 2)} mm/day in the window against a peak of ${engN(m.peakGrossMmDay, 2)} mm/day (needs ${engN(m.hoursNeeded, 1)} h a day)${m.short ? ' — SHORT' : ''}',
          ].join('\n'),
        );
      },
    ),
    // ---------------------------------------------------------------- programme
    engOp(
      b,
      name: 'irrigation_programme',
      effectFor: (i) => i['save'] == true ? ToolEffect.write : ToolEffect.read,
      description:
          'Design → Agronomy → Irrigation programme: the controller programme as a controller is set — the system flows on their days (shortest interval of their areas, longest run they need), one after another from the start of the daily irrigation window, with cycle and soak for the sprinkler zones whose rate the soil does not take (cycles no longer than the run before runoff, the soak pause before the next cycle of the same flow, other flows running meanwhile), the seasonal adjustment of every month (% of the design month\'s run time, from the monthly requirement, or typed), and per controller station (from the valve wiring) the zone, areas, flow, rate, interval and the run time per event of every month (PRD-27). Inputs (settings, kept with save; one undo step): window_start_hour 0–24, window_hours 1–24 (24 = whole day; also the window of the capacity check), cycle_soak, min_cycle_minutes 1–120, max_cycles 1–24, seasonal_pct [12 values %] or seasonal_auto true (from the requirement), in_reports (put the station table and the runs in the reports); view: days 1–60 (default 7), month 1–12 (default the design month of every area), rows_limit 1–500 (default 60); save. Output: warnings, cycle and soak, seasonal %, stations and runs.',
      schema: obj({
        'window_start_hour': num_('Start of the irrigation window, 0–24 h.'),
        'window_hours': num_('Length of the window, 1–24 h.'),
        'cycle_soak': bool_('Split runs that run off into cycles.'),
        'min_cycle_minutes': num_('Shortest cycle, 1–120 min.'),
        'max_cycles': int_('Most cycles of one event, 1–24.'),
        'seasonal_pct': numbers('Seasonal adjustment of every month (%), January first.', n: 12),
        'seasonal_auto': bool_('Seasonal adjustment from the monthly requirement.'),
        'in_reports': bool_('Show the station table and the runs in the reports.'),
        'days': int_('Days of runs, 1–60.'),
        'month': int_('Month of the programme, 1–12.'),
        'rows_limit': int_('Rows of each table, 1–500.'),
        'save': bool_('Keep the settings.'),
      }),
      summary: (i) => t(i['save'] == true ? 'ai.op.irrigation_programme.save' : 'ai.op.irrigation_programme'),
      run: (a, i) async {
        final s = b.p.agronomy.programme.copy();
        s.windowStartHour = a.number('window_start_hour', min: 0, max: 24) ?? s.windowStartHour;
        s.windowHours = a.number('window_hours', min: 1, max: 24) ?? s.windowHours;
        s.cycleSoak = a.flag('cycle_soak') ?? s.cycleSoak;
        s.minCycleMinutes = a.number('min_cycle_minutes', min: 1, max: 120) ?? s.minCycleMinutes;
        s.maxCycles = a.integer('max_cycles', min: 1, max: 24) ?? s.maxCycles;
        final pct = engNumbers(i['seasonal_pct'], 'seasonal_pct', length: 12, min: 0, max: 300);
        if (pct != null) s.seasonalPct = pct;
        if (a.flag('seasonal_auto') ?? false) s.seasonalPct = null;
        s.inReports = a.flag('in_reports') ?? s.inReports;
        final days = a.integer('days', min: 1, max: 60) ?? 7, month = a.integer('month', min: 1, max: 12);
        // the programme with these settings (the project's are put back at once)
        final prog = await engSoon(() {
          final old = b.p.agronomy.programme;
          b.p.agronomy.programme = s;
          try {
            return buildIrrigationProgramme(b.p, c.results, days: days, month: month);
          } finally {
            b.p.agronomy.programme = old;
          }
        });
        if (a.flag('save') ?? false) {
          b.change('irrigation_programme', () {
            b.p.agronomy.programme = s;
            return true;
          }, invalidate: false);
        }
        final limit = a.integer('rows_limit', min: 1, max: 500) ?? 60;
        final out = <String>[
          if (c.results == null) 'No design results: the flows are estimated from the catalogue; run_design for the real ones.',
          'Window ${engN(prog.windowStartHour, 2)} h + ${engN(prog.windowHours, 1)} h; busiest day uses ${engN(prog.maxDailyWindowHours, 2)} h of it.',
          if (prog.cycles.isNotEmpty) 'Cycle and soak: ${prog.cycles.values.map((x) => '${engItemName(b, x.flowId)} ${x.cycles} × ${engN(x.runMinutes, 0)} min / ${engN(x.soakMinutes, 0)} min').join('; ')}.',
          'Seasonal adjustment (%): ${[for (var m = 0; m < 12; m++) '${engMonths[m]} ${engN(prog.seasonalPct[m], 0)}'].join(', ')}.',
          if (prog.stations.isNotEmpty)
            engTable(['controller', 'station', 'zone', 'areas', 'm³/h', 'mm/h', 'every d', ...engMonths.map((m) => '$m min')], [
              for (final st in prog.stations) [st.controller.isEmpty ? '-' : st.controller, st.station, st.name, st.areas.join(' + '), st.flowM3h, st.rateMmH, st.intervalDays, for (final x in st.minutesByMonth) engN(x, 0)],
            ], max: limit),
          engTable(['date', 'flow', 'cycle', 'start', 'end', 'hours'], [
            for (final r in prog.runs) [d10(r.day), r.flowName, '${r.cycle}/${r.cycles}', clockText(r.startHour), clockText(r.endHour), r.durationHours],
          ], max: limit),
          if (a.flag('save') ?? false) 'Settings kept.',
        ];
        return ToolOutput(out.join('\n') + engCodes(b, prog.warnings));
      },
    ),
    engOp(
      b,
      name: 'export_irrigation_programme',
      effect: ToolEffect.export,
      description:
          'Irrigation programme → Export CSV: saves the programme by controller station and month (zone, areas, flow, rate, interval, cycle and soak, run time per event of every month and the seasonal adjustment, PRD-27) or its runs (date, flow, zones, cycle, start, end, hours) as a CSV file, with the settings kept (irrigation_programme). Always confirmed by the user (a download in the browser). Inputs: what stations|runs (default stations), days 1–60 (runs; default 14). Output: the file name and the rows.',
      schema: obj({'what': str('What to export.', ['stations', 'runs']), 'days': int_('Days of runs, 1–60; default 14.')}),
      run: (a, _) async {
        final prog = await engSoon(() => buildIrrigationProgramme(b.p, c.results, days: a.integer('days', min: 1, max: 60) ?? 14));
        final runs = a.str('what') == 'runs';
        if (runs ? prog.runs.isEmpty : prog.stations.isEmpty) throw ToolInputError('${t('msg.noAreas')} (nothing to export: the areas need a crop or a daily depth and the flows zones).');
        final file = '${engStem(c)}_${runs ? 'programme_runs' : 'programme_stations'}.csv';
        await engFileSink(c, file, 'text/csv', runs ? programmeRunsCsv(prog, t: t.call) : programmeStationsCsv(prog, t: t.call));
        return ToolOutput('Saved $file (${runs ? prog.runs.length : prog.stations.length} rows).');
      },
    ),
    // ---------------------------------------------------------------- depth densogram and catch cans
    engOp(
      b,
      name: 'depth_densogram',
      description:
          'Zone → Densogram by applied depth: the depth (mm) one irrigation event of the programme lays on the ground (every sprinkler\'s rate times the hours its zone runs per event in its system flow), its uniformity over the irrigated areas (CU, DU, SC, dry share) and per area; show true shows the map on the drawing (a view change; the densogram options of the dialog are kept). Inputs: month 1–12 (default the design month), show. Output: the statistics.',
      schema: obj({'month': int_('Month of the programme, 1–12.'), 'show': bool_('Show the map on the drawing.')}),
      run: (a, _) async {
        final month = a.integer('month', min: 1, max: 12);
        final d = await engSoon(() => depthDensogram(b.p, c.results, base: c.densogramOptions, month: month));
        if (d.isEmpty) return ToolOutput('${t('dens.none')} (or no sprinkler zone runs in the programme).');
        if (a.flag('show') ?? false) {
          c.densogramOptions.depthHours = eventHoursByEntity(b.p, c.results, month: month);
          c.showDensogram();
          c.refresh();
        }
        final s = d.stats;
        return ToolOutput(
          [
            'Depth of one event over ${engN(s.areaM2, 0)} m²: mean ${engN(s.mean, 2)} mm (least ${engN(s.min, 2)}, most ${engN(s.max, 2)}); CU ${engN(s.cu, 1)} %, DU ${engN(s.du, 1)} %, SC ${s.sc.isFinite ? engN(s.sc, 2) : '∞'}, dry ${engN(s.dryPct, 1)} %.',
            if (d.areas.length > 1) 'By area: ${[for (final x in d.areas) '${x.name.isEmpty ? x.areaId : x.name} ${engN(x.stats.mean, 1)} mm, CU ${engN(x.stats.cu, 0)} %, DU ${engN(x.stats.du, 0)} %'].join('; ')}.',
            if (a.flag('show') ?? false) 'The map is shown on the drawing.',
          ].join('\n'),
        );
      },
    ),
    engOp(
      b,
      name: 'virtual_catch_cans',
      description:
          'Uniformity in the field → Virtual catch cans: a grid of cans over an irrigated area (every dx × dy metres, rotated by angle_deg) and what each can would catch in a test of one zone (the zone\'s rate map at the design pressures times the test hours): depth (mm) and volume (mL for the can mouth), with CU and DU — the layout and the expected readings of a field test. It changes nothing (set_field_test keeps a test). Inputs: area (id or name, required), zone (valve id or zone name; default every zone over the area), dx_m and dy_m 0.5–50 (default 3), angle_deg, mouth_mm 20–500 (default 100), hours 0.05–24 (default 1), rows_limit 1–1000 (default 100). Output: the statistics and the cans (row, column, x, y, mm, mL).',
      schema: obj({
        'area': str('Irrigated area id or name.'),
        'zone': str('Valve id or zone name of the zone tested.'),
        'dx_m': num_('Can spacing along x, 0.5–50 m.'),
        'dy_m': num_('Can spacing along y, 0.5–50 m.'),
        'angle_deg': num_('Rotation of the grid (degrees counter-clockwise).'),
        'mouth_mm': num_('Can mouth diameter, 20–500 mm.'),
        'hours': num_('Test duration, 0.05–24 h.'),
        'rows_limit': int_('Cans listed, 1–1000.'),
      }, required: ['area']),
      run: (a, _) async {
        final ar = area(a.str('area'));
        var zone = '';
        if (a.has('zone')) {
          final z = b.find(a.str('zone')!);
          if (z is! ControlValveEntity) throw ToolInputError('"${a.str('zone')}" is not a zone valve.');
          zone = z.id;
        }
        final grid = canGridOver(
          ar.points,
          id: 'virtual',
          dx: a.number('dx_m', min: 0.5, max: 50) ?? 3.0,
          dy: a.number('dy_m', min: 0.5, max: 50) ?? 3.0,
          angleDeg: a.number('angle_deg', min: -360, max: 360) ?? 0.0,
          mouthMm: a.number('mouth_mm', min: 20, max: 500) ?? 100.0,
          hours: a.number('hours', min: 0.05, max: 24) ?? 1.0,
          zoneId: zone,
          areaId: ar.id,
        );
        if (grid.values.length > 20000) throw ToolInputError('That grid has ${grid.values.length} cans: use a wider spacing.');
        // the expected readings: volumes from the predicted depths
        final e0 = evaluateFieldTest(b.p, grid, results: c.results);
        final cans = [
          for (var k = 0; k < grid.values.length; k++)
            if (e0.predicted[k] != null) (k, e0.predicted[k]!),
        ];
        final s = FieldStats.of([for (final x in cans) x.$2]);
        return ToolOutput(
          [
            '${cans.length} cans every ${engN(grid.spacingXM, 1)} × ${engN(grid.spacingYM, 1)} m in ${areaName(ar)} (${grid.cols} columns), ${engN(grid.durationH, 2)} h of ${zone.isEmpty ? 'every zone' : engItemName(b, zone)}: mean ${engN(s.mean, 2)} mm (${engN(canVolumeMl(s.mean, grid.canMouthMm), 0)} mL), least ${engN(s.min, 2)}, most ${engN(s.max, 2)}; CU ${engN(s.cu, 1)} %, DU ${engN(s.du, 1)} %.',
            engTable(['row', 'col', 'x', 'y', 'mm', 'mL'], [
              for (final (k, mm) in cans) [k ~/ grid.cols + 1, k % grid.cols + 1, grid.position(k).x, grid.position(k).y, mm, canVolumeMl(mm, grid.canMouthMm)],
            ], max: a.integer('rows_limit', min: 1, max: 1000) ?? 100),
          ].join('\n'),
        );
      },
    ),
    engOp(
      b,
      name: 'set_field_test',
      effect: ToolEffect.write,
      description:
          'Uniformity in the field → keep a field evaluation in the project (PRD-28): catch cans read after a test of one zone (volumes in mL, row by row on a grid) or emitter flows measured in a drip zone (L/h); a new test unless id names one. The grid is from_area (the grid over the area, as virtual_catch_cans lays it) or origin [x, y] with cols, dx_m, dy_m and angle_deg. One undo step. Inputs: id, name, date (YYYY-MM-DD), kind cans|emitters, zone (valve id or zone name), area (id or name), from_area, origin, cols, dx_m, dy_m, angle_deg, mouth_mm, hours, values (numbers, null for a lost can). Output: the evaluation (CU, DU, US of what was measured against the design).',
      schema: obj({
        'id': str('Id of the test to change; new when absent.'),
        'name': str('Name of the test.'),
        'date': str('Date of the test (YYYY-MM-DD).'),
        'kind': str('What was measured.', [for (final x in FieldTestKind.values) x.name]),
        'zone': str('Valve id or zone name of the zone tested.'),
        'area': str('Irrigated area id or name.'),
        'from_area': bool_('Lay the grid over the area.'),
        'origin': numbers('First can [x, y] (m).', n: 2),
        'cols': int_('Cans in a row, 1–10000.'),
        'dx_m': num_('Spacing along a row, 0.5–50 m.'),
        'dy_m': num_('Spacing between rows, 0.5–50 m.'),
        'angle_deg': num_('Rotation of the grid (degrees counter-clockwise).'),
        'mouth_mm': num_('Can mouth diameter, 20–500 mm.'),
        'hours': num_('Test duration, 0.05–24 h.'),
        'values': arr({'type': ['number', 'null']}, 'Readings row by row (mL or L/h); null = lost can.', 20000),
      }),
      run: (a, i) async {
        final tests = b.p.agronomy.fieldTests;
        final id = a.str('id');
        final old = id == null ? null : tests.where((x) => x.id == id).firstOrNull;
        if (id != null && old == null) throw ToolInputError('No field test "$id". Tests: ${tests.map((x) => x.id).join(', ')}.');
        final ar = a.has('area') ? area(a.str('area')) : null;
        var zone = old?.zoneId ?? '';
        if (a.has('zone')) {
          final z = b.find(a.str('zone')!);
          if (z is! ControlValveEntity) throw ToolInputError('"${a.str('zone')}" is not a zone valve.');
          zone = z.id;
        }
        final dx = a.number('dx_m', min: 0.5, max: 50) ?? old?.spacingXM ?? 3.0;
        final dy = a.number('dy_m', min: 0.5, max: 50) ?? old?.spacingYM ?? 3.0;
        final angle = a.number('angle_deg', min: -360, max: 360) ?? old?.angleDeg ?? 0.0;
        FieldTest ft;
        final fromArea = a.flag('from_area') ?? false;
        if (fromArea) {
          if (ar == null) throw ToolInputError('from_area needs "area".');
          ft = canGridOver(ar.points, id: old?.id ?? 'ft${DateTime.now().microsecondsSinceEpoch}', dx: dx, dy: dy, angleDeg: angle, zoneId: zone, areaId: ar.id);
        } else {
          ft = old?.copy() ?? FieldTest(id: 'ft${DateTime.now().microsecondsSinceEpoch}');
          ft
            ..spacingXM = dx
            ..spacingYM = dy
            ..angleDeg = angle;
          final o = engNumbers(i['origin'], 'origin', length: 2);
          if (o != null) ft.origin = Pt(o[0], o[1]);
          ft.cols = a.integer('cols', min: 1, max: 10000) ?? ft.cols;
        }
        ft
          ..name = a.str('name') ?? old?.name ?? ''
          ..date = a.str('date') ?? old?.date ?? ''
          ..zoneId = zone
          ..areaId = ar?.id ?? old?.areaId ?? ''
          ..canMouthMm = a.number('mouth_mm', min: 20, max: 500) ?? old?.canMouthMm ?? 100.0
          ..durationH = a.number('hours', min: 0.05, max: 24) ?? old?.durationH ?? 1.0;
        if (a.has('kind')) ft.kind = FieldTestKind.values.byName(a.str('kind')!);
        final v = i['values'];
        if (v != null) {
          if (v is! List) throw ToolInputError('"values" must be a list of numbers (null for a lost can).');
          final read = [for (final x in v) x is num && x.isFinite && x >= 0 ? x.toDouble() : null];
          if (fromArea) {
            // the readings of the cans inside the area, in grid order (or every slot of the grid)
            final inside = [
              for (var k = 0; k < ft.values.length; k++)
                if (ft.values[k] != null) k,
            ];
            if (read.length == ft.values.length) {
              ft.values
                ..clear()
                ..addAll(read);
            } else if (read.length == inside.length) {
              for (var k = 0; k < inside.length; k++) {
                ft.values[inside[k]] = read[k];
              }
            } else {
              throw ToolInputError('The grid over the area has ${inside.length} cans (${ft.values.length} slots with those outside): give that many values.');
            }
          } else {
            ft.values
              ..clear()
              ..addAll(read);
          }
        } else if (fromArea) {
          throw ToolInputError('A grid laid over the area needs its readings: give "values" (virtual_catch_cans lists the cans).');
        }
        if (ft.values.isEmpty) throw ToolInputError('The test has no readings: give "values".');
        b.change('set_field_test', () {
          final k = tests.indexWhere((x) => x.id == ft.id);
          if (k >= 0) {
            tests[k] = ft;
          } else {
            tests.add(ft);
          }
          return true;
        }, invalidate: false);
        final e = evaluateFieldTest(b.p, ft, results: c.results);
        return ToolOutput(_fieldEvaluationText(b, e));
      },
    ),
    engOp(
      b,
      name: 'field_test_evaluation',
      description:
          'Uniformity in the field → the evaluation of a field test kept in the project: Christiansen CU, low-quarter DU and statistical uniformity of the readings (cans as depths, emitters as flows), the mean rate of the test, and the design\'s values at the same cans (the zone\'s rate map times the test hours) or the zone\'s design mean flow. Inputs: id (default every test). Output: one block per test.',
      schema: obj({'id': str('Field test id; default all.')}),
      run: (a, _) async {
        final tests = b.p.agronomy.fieldTests;
        if (tests.isEmpty) return ToolOutput('No field test in the project (set_field_test keeps one).');
        final id = a.str('id');
        final pick = id == null ? tests : tests.where((x) => x.id == id).toList();
        if (pick.isEmpty) throw ToolInputError('No field test "$id". Tests: ${tests.map((x) => x.id).join(', ')}.');
        return ToolOutput([for (final ft in pick) _fieldEvaluationText(b, evaluateFieldTest(b.p, ft, results: c.results))].join('\n\n'));
      },
    ),
    engOp(
      b,
      name: 'delete_field_test',
      effect: ToolEffect.write,
      confirm: (_) => true,
      description: 'Uniformity in the field → deletes a field test kept in the project (its readings are lost; one undo step). Always confirmed by the user. Input: id (required). Output: what was deleted.',
      schema: obj({'id': str('Field test id.')}, required: ['id']),
      run: (a, _) async {
        final id = a.str('id', required: true)!;
        final tests = b.p.agronomy.fieldTests;
        if (!tests.any((x) => x.id == id)) throw ToolInputError('No field test "$id". Tests: ${tests.map((x) => x.id).join(', ')}.');
        b.change('delete_field_test', () {
          tests.removeWhere((x) => x.id == id);
          return true;
        }, invalidate: false);
        return ToolOutput('Field test $id deleted.');
      },
    ),
    // ---------------------------------------------------------------- fertigation by stage
    engOp(
      b,
      name: 'fertigation_by_stage',
      effectFor: (i) => i['save'] == true ? ToolEffect.write : ToolEffect.read,
      description:
          'Design → Agronomy → Fertigation by stage: the doses of N, P₂O₅ and K₂O of the crop cycle of ONE area split over its four FAO-56 growth stages (by the crop\'s water use in each stage, or by typed shares) and given in the irrigations of the stage (the events of the daily water balance, every n-th), with the product of each event (phosphate and potash products first, their N counted), the stock solution, its injection rate, the concentration while injecting and the rise of the EC (TDS/640, FAO-29; urea left out) against the crop\'s full-yield water salinity (ECe threshold/1.5). Inputs: area (required); dose_kg_ha [N, P2O5, K2O]; share_pct [4 rows of 3 %] (or share_auto true); products [3 objects {name, n, p2o5, k2o, ionic}] for N, P₂O₅, K₂O (default urea 45-0-0, MAP 11-52-0, KCl 0-0-60); every_nth 1–30; stock_kg_l 0.01–2; injection_pct 5–100 (share of the event injecting; default 50); save (keep the plan for the area; one undo step). Output: the stages and the warnings.',
      schema: obj({
        'area': str('Irrigated area id or name.'),
        'dose_kg_ha': numbers('N, P2O5, K2O for the cycle (kg/ha).', n: 3),
        'share_pct': arr(numbers('N, P2O5, K2O (%) of one stage.', n: 3), 'Shares of the four stages.', 4),
        'share_auto': bool_('Shares by the water use of the stages.'),
        'products': arr(
          obj({'name': str(), 'n': num_('% N'), 'p2o5': num_('% P2O5'), 'k2o': num_('% K2O'), 'ionic': bool_('A salt (raises the EC); false for urea.')}),
          'Products for N, P2O5 and K2O.',
          3,
        ),
        'every_nth': int_('Fertigate every n-th irrigation, 1–30.'),
        'stock_kg_l': num_('Product per litre of stock solution, 0.01–2 kg/L.'),
        'injection_pct': num_('Share of the event injecting, 5–100 %.'),
        'save': bool_('Keep the plan for the area.'),
      }, required: ['area']),
      summary: (i) => t(i['save'] == true ? 'ai.op.fertigation_by_stage.save' : 'ai.op.fertigation_by_stage'),
      run: (a, i) async {
        final ar = area(a.str('area'));
        final pl = (b.p.agronomy.fertigation[ar.id] ?? FertigationStagePlan()).copy();
        final dose = engNumbers(i['dose_kg_ha'], 'dose_kg_ha', length: 3, min: 0, max: 5000);
        if (dose != null) {
          for (var k = 0; k < 3; k++) {
            pl.doseKgHa[k] = dose[k];
          }
        }
        final share = i['share_pct'];
        if (share != null) {
          if (share is! List || share.length != 4) throw ToolInputError('"share_pct" needs 4 rows of 3 numbers.');
          pl.sharePct = [for (var s = 0; s < 4; s++) engNumbers(share[s], 'share_pct[$s]', length: 3, min: 0, max: 100)!];
        }
        if (a.flag('share_auto') ?? false) pl.sharePct = null;
        final prods = i['products'];
        if (prods != null) {
          if (prods is! List || prods.length != 3) throw ToolInputError('"products" needs 3 objects (the products of N, P2O5 and K2O).');
          pl.products
            ..clear()
            ..addAll([
              for (final x in prods)
                if (x is Map)
                  FertProduct(
                    name: '${x['name'] ?? ''}',
                    nPct: (x['n'] as num?)?.toDouble() ?? 0,
                    p2o5Pct: (x['p2o5'] as num?)?.toDouble() ?? 0,
                    k2oPct: (x['k2o'] as num?)?.toDouble() ?? 0,
                    ionic: x['ionic'] as bool? ?? true,
                  )
                else
                  throw ToolInputError('Each product is an object {name, n, p2o5, k2o, ionic}.'),
            ]);
        }
        pl.everyNth = a.integer('every_nth', min: 1, max: 30) ?? pl.everyNth;
        pl.stockKgPerL = a.number('stock_kg_l', min: 0.01, max: 2) ?? pl.stockKgPerL;
        pl.injectionPct = a.number('injection_pct', min: 5, max: 100) ?? pl.injectionPct;
        final f = fertigationSchedule(b.p, ar, plan: pl, results: c.results);
        if (f == null) throw ToolInputError('${areaName(ar)} has no water balance (a crop or ETo and Kc): no stages to fertigate.');
        if (a.flag('save') ?? false) {
          b.change('fertigation_by_stage', () {
            b.p.agronomy.fertigation[ar.id] = pl;
            return true;
          }, invalidate: false);
        }
        final tot = f.productTotalsKg;
        return ToolOutput(
          [
            '${areaName(ar)} (${engN(f.areaHa, 2)} ha): N ${engN(pl.doseKgHa[0], 0)}, P2O5 ${engN(pl.doseKgHa[1], 0)}, K2O ${engN(pl.doseKgHa[2], 0)} kg/ha; products ${pl.products.map((x) => '${x.name} ${engN(x.nPct, 0)}-${engN(x.p2o5Pct, 0)}-${engN(x.k2oPct, 0)}').join(', ')}; every ${pl.everyNth} irrigation(s).',
            'Products of the cycle: ${[for (var k = 0; k < 3; k++) '${pl.products[k].name} ${engN(tot[k], 1)} kg'].join(', ')}; ECw ${engN(f.ecwDsM, 2)} → up to ${engN(f.peakEcwDsM, 2)} dS/m while injecting${f.ecwLimitDsM == null ? '' : ' (full-yield limit ${engN(f.ecwLimitDsM!, 2)})'}.',
            engTable(['stage', 'from', 'to', 'days', 'N kg/ha', 'P2O5 kg/ha', 'K2O kg/ha', 'fertigations', '${pl.products[0].name} kg/event', '${pl.products[1].name} kg/event', '${pl.products[2].name} kg/event', 'stock L', 'L/h', 'g/L', 'ΔEC'], [
              for (final s in f.stages)
                [
                  fertStageNames[s.stage],
                  d10(s.start),
                  d10(s.end),
                  s.days,
                  s.kgHa[0],
                  s.kgHa[1],
                  s.kgHa[2],
                  s.fertigations,
                  s.productKgPerEvent[0],
                  s.productKgPerEvent[1],
                  s.productKgPerEvent[2],
                  s.stockLPerEvent,
                  s.injectionLph,
                  s.concentrationGL,
                  s.ecRiseDsM,
                ],
            ]),
            if (a.flag('save') ?? false) 'Plan kept for the area (the report shows it).',
          ].join('\n') +
              engCodes(b, [for (final w in f.warnings) w.split(':').first]),
        );
      },
    ),
    // ---------------------------------------------------------------- user crops
    engOp(
      b,
      name: 'list_user_crops',
      description:
          'Design → Agronomy → User crops: the crops of the project that the FAO-56 table does not have (PRD-15), with their key (user.<id>, the crop key "ck" of an area that uses one), Kc ini/mid/end, stage lengths, planting month, root depth, depletion fraction, height, salt tolerance, Ky and source, and the areas using each. No input.',
      schema: obj({}),
      run: (a, _) async {
        final crops = b.p.agronomy.userCrops;
        if (crops.isEmpty) return ToolOutput('No user crop (set_user_crop adds one).');
        return ToolOutput(
          engTable(['key', 'name', 'Kc ini/mid/end', 'days ini/dev/mid/late', 'month', 'root m', 'p', 'h m', 'perennial', 'ECe 100%/0%', 'Ky', 'source', 'areas'], [
            for (final u in crops)
              [
                u.key,
                u.name,
                '${engN(u.kcIni)}/${engN(u.kcMid)}/${engN(u.kcEnd)}',
                '${engN(u.initialDays, 0)}/${engN(u.developmentDays, 0)}/${engN(u.midDays, 0)}/${engN(u.lateDays, 0)}',
                u.plantingMonth,
                u.rootDepthM,
                u.depletionFraction,
                u.maxHeightM,
                u.perennial,
                u.eceThreshold > 0 ? '${engN(u.eceThreshold, 1)}/${engN(u.eceMax, 1)}' : '-',
                u.ky > 0 ? engN(u.ky, 2) : '-',
                u.source.isEmpty ? '-' : u.source,
                [
                  for (final x in b.p.entities.whereType<AreaEntity>())
                    if (x.cropKey == u.key) areaName(x),
                ].join(', '),
              ],
          ]),
        );
      },
    ),
    engOp(
      b,
      name: 'set_user_crop',
      effect: ToolEffect.write,
      description:
          'Design → Agronomy → User crops: adds or changes a crop the FAO-56 table does not have (passion fruit, papaya, açaí, cocoa, black pepper, eucalyptus…; PRD-15) with its FAO-56 single crop coefficient curve, so its areas get the monthly requirement table, the programme and the water balance like a table crop. id names one to change (else a new one from the name). Inputs: id, name (required for a new crop), kc [ini, mid, end] 0–2, stage_days [initial, development, mid, late] 0–400 (all 0 = evergreen), planting_month 1–12, root_depth_m 0.05–5, depletion_fraction 0.05–0.95, height_m 0–30 (0 = no climatic adjustment of Kc), perennial, ece [threshold, zero-yield] dS/m, ky 0–3, source (where the values come from: a water permit asks), assign_areas (area ids or names to use it: sets their crop key, root depth and depletion fraction as the panel does). One undo step; results discarded when areas change. Output: the crop and the areas assigned.',
      schema: obj({
        'id': str('Id of the crop to change.'),
        'name': str('Crop name.'),
        'kc': numbers('Kc ini, Kc mid, Kc end.', n: 3),
        'stage_days': numbers('Initial, development, mid-season and late stage (days).', n: 4),
        'planting_month': int_('Planting or green-up month, 1–12.'),
        'root_depth_m': num_('Root depth for scheduling, 0.05–5 m.'),
        'depletion_fraction': num_('Depletion fraction p, 0.05–0.95.'),
        'height_m': num_('Maximum crop height, 0–30 m.'),
        'perennial': bool_('Repeats every year (trees, perennial crops).'),
        'ece': numbers('Soil salinity ECe at 100 % and at zero yield (dS/m).', n: 2),
        'ky': num_('Seasonal yield response factor, 0–3.'),
        'source': str('Where the values come from.'),
        'assign_areas': arr(str(), 'Areas (ids or names) that take the crop.'),
      }),
      run: (a, i) async {
        final crops = b.p.agronomy.userCrops;
        final id = a.str('id');
        final old = id == null ? null : crops.where((x) => x.id == id).firstOrNull;
        if (id != null && old == null) throw ToolInputError('No user crop "$id". Crops: ${crops.map((x) => x.id).join(', ')}.');
        final name = a.str('name') ?? old?.name;
        if (name == null || name.trim().isEmpty) throw ToolInputError('A new crop needs "name".');
        final u = old?.copy() ?? UserCrop(id: userCropIdFor(name, crops.map((x) => x.id)), name: name.trim());
        u.name = name.trim();
        final kc = engNumbers(i['kc'], 'kc', length: 3, min: 0, max: 2);
        if (kc != null) {
          u
            ..kcIni = kc[0]
            ..kcMid = kc[1]
            ..kcEnd = kc[2];
        }
        final days = engNumbers(i['stage_days'], 'stage_days', length: 4, min: 0, max: 400);
        if (days != null) {
          u
            ..initialDays = days[0]
            ..developmentDays = days[1]
            ..midDays = days[2]
            ..lateDays = days[3];
        }
        u.plantingMonth = a.integer('planting_month', min: 1, max: 12) ?? u.plantingMonth;
        u.rootDepthM = a.number('root_depth_m', min: 0.05, max: 5) ?? u.rootDepthM;
        u.depletionFraction = a.number('depletion_fraction', min: 0.05, max: 0.95) ?? u.depletionFraction;
        u.maxHeightM = a.number('height_m', min: 0, max: 30) ?? u.maxHeightM;
        u.perennial = a.flag('perennial') ?? u.perennial;
        final ece = engNumbers(i['ece'], 'ece', length: 2, min: 0, max: 100);
        if (ece != null) {
          if (ece[0] > 0 && ece[1] <= ece[0]) throw ToolInputError('"ece": the zero-yield ECe must be above the threshold.');
          u
            ..eceThreshold = ece[0]
            ..eceMax = ece[1];
        }
        u.ky = a.number('ky', min: 0, max: 3) ?? u.ky;
        u.source = a.str('source') ?? u.source;
        final assign = [for (final r in a.strings('assign_areas')) area(r)];
        b.change('set_user_crop', () {
          final k = crops.indexWhere((x) => x.id == u.id);
          if (k >= 0) {
            crops[k] = u;
          } else {
            crops.add(u);
          }
          for (final x in assign) {
            x
              ..cropKey = u.key
              ..crop = u.name
              ..useWaterBalance = true
              ..rootDepthM = u.rootDepthM
              ..mad = u.depletionFraction
              ..kc = u.kcMid;
          }
          return true;
        }, invalidate: assign.isNotEmpty);
        return ToolOutput(
          'User crop ${u.key} (${u.name}): Kc ${engN(u.kcIni)}/${engN(u.kcMid)}/${engN(u.kcEnd)}, ${engN(u.seasonDays, 0)} days${u.seasonDays <= 0 ? ' (evergreen: Kc mid all year)' : ''}, root ${engN(u.rootDepthM, 2)} m, p ${engN(u.depletionFraction, 2)}.${assign.isEmpty ? '' : ' Assigned to ${assign.map(areaName).join(', ')}; results discarded.'}',
        );
      },
    ),
    engOp(
      b,
      name: 'delete_user_crop',
      effect: ToolEffect.write,
      confirm: (_) => true,
      description:
          'Design → Agronomy → User crops: deletes a user crop (one undo step). Areas that use it keep its name with the single Kc typed on them (their crop key is cleared). Always confirmed by the user. Input: id (required). Output: the crop and the areas changed.',
      schema: obj({'id': str('User crop id.')}, required: ['id']),
      run: (a, _) async {
        final id = a.str('id', required: true)!;
        final crops = b.p.agronomy.userCrops;
        final u = crops.where((x) => x.id == id).firstOrNull;
        if (u == null) throw ToolInputError('No user crop "$id". Crops: ${crops.map((x) => x.id).join(', ')}.');
        final using = [
          for (final x in b.p.entities.whereType<AreaEntity>())
            if (x.cropKey == u.key) x,
        ];
        b.change('delete_user_crop', () {
          crops.remove(u);
          for (final x in using) {
            x.cropKey = '';
          }
          return true;
        }, invalidate: using.isNotEmpty);
        return ToolOutput('User crop ${u.key} deleted${using.isEmpty ? '' : '; areas now with the typed Kc: ${using.map(areaName).join(', ')}'}.');
      },
    ),
    // ---------------------------------------------------------------- station file
    engOp(
      b,
      name: 'import_station_climate',
      effect: ToolEffect.write,
      description:
          'Design → Site climate → Station file: reads a weather station file the user attached — the CSV of an INMET automatic station of the historical data portal (hourly) or a BDMEP export (daily or hourly), or a zip of several of them (the years of one station) — works out the daily FAO-56 Penman-Monteith ETo (radiation measured, or from sunshine or the temperature range) and stores the monthly normals (ETo, mean and dependable rain, radiation, RHmin and wind at 2 m for the Kc adjustment) with the daily ETo and rain for the water balance as the site climate (one undo step). Inputs: name (file as attached, required), wind_height_m 0.5–50 (anemometer; INMET 10), station (code or name when the zip holds several stations; default the one with most days), latitude_deg / elevation_m (when the file lacks them; default the site). Output: the station, the period and the monthly values.',
      schema: obj({
        'name': str('File name as attached.'),
        'wind_height_m': num_('Anemometer height, 0.5–50 m.'),
        'station': str('Station code or name.'),
        'latitude_deg': num_('Station latitude (°, south negative).'),
        'elevation_m': num_('Station elevation (m).'),
      }, required: ['name']),
      summary: (i) => t('ai.op.import_station_climate', {'n': '${i['name']}'}),
      run: (a, _) async {
        engNotBusy(c);
        final files = b.host?.files ?? const <String, Uint8List>{};
        final name = a.str('name', required: true)!;
        final bytes = files[name] ?? files.entries.where((e) => e.key.toLowerCase() == name.toLowerCase()).firstOrNull?.value;
        if (bytes == null) throw ToolInputError(files.isEmpty ? 'No file was attached in this conversation.' : 'No attached file "$name". Attached: ${files.keys.join(', ')}.');
        final site = c.siteLatLon;
        final wind = a.number('wind_height_m', min: 0.5, max: 50) ?? 10.0;
        final lat = a.number('latitude_deg', min: -90, max: 90) ?? site?.$1;
        final elev = a.number('elevation_m', min: -400, max: 6000);
        List<StationFile> read() {
          try {
            return mergeStationFiles(readStationFiles(bytes, windHeightM: wind, latitudeDeg: lat, elevationM: elev));
          } on FormatException catch (e) {
            throw ToolInputError('"$name" is not a station file this program reads (${e.message}).');
          }
        }

        final stations = read();
        final want = a.str('station')?.toLowerCase();
        final pick = want == null
            ? (stations..sort((x, y) => y.days.length.compareTo(x.days.length))).first
            : stations.where((s) => s.code.toLowerCase() == want || s.name.toLowerCase() == want).firstOrNull ??
                  (throw ToolInputError('No station "${a.str('station')}" in the file: ${stations.map((s) => '${s.code} ${s.name}').join(', ')}.'));
        final now = DateTime.now();
        final sc = stationClimate(pick, retrieved: now.toIso8601String().substring(0, 10));
        if (sc == null) throw ToolInputError('${pick.name}: no complete month with temperatures (or no latitude: give latitude_deg).');
        b.change('import_station_climate', () {
          b.p.climate = sc;
          return true;
        }, invalidate: false);
        return ToolOutput(
          [
            'Site climate from INMET ${pick.name} (${pick.code}), ${pick.first == null ? '' : '${d10(pick.first!)} … ${d10(pick.last!)}'}, ${pick.days.length} days (${pick.etoDays} with ETo), ${pick.files} file(s)${stations.length > 1 ? '; other stations in the file: ${stations.where((s) => s != pick).map((s) => s.code).join(', ')}' : ''}.',
            engTable(['month', 'ETo mm/d', 'rain mm', 'dependable mm', 'RHmin %', 'u2 m/s'], [
              for (var m = 0; m < 12; m++) [engMonths[m], sc.etoMmDay[m], sc.rainMm[m], sc.dependableRainMm?[m] ?? '-', sc.rhMinPct?[m] ?? '-', sc.windSpeed2mMs?[m] ?? '-'],
            ]),
            'The daily series (${sc.daily?.completeYears.length ?? 0} complete years) is kept for the water balance (water_balance year).',
          ].join('\n'),
        );
      },
    ),
  ];
}

/// The evaluation [e] in words for the model.
String _fieldEvaluationText(AgentToolbox b, FieldEvaluation e) {
  final ft = e.test;
  final m = e.measuredStats;
  final cans = ft.kind == FieldTestKind.cans;
  final unit = cans ? 'mm' : 'L/h';
  return [
    'Field test ${ft.id}${ft.name.isEmpty ? '' : ' "${ft.name}"'}${ft.date.isEmpty ? '' : ' (${ft.date})'}: ${cans ? 'catch cans' : 'emitter flows'}${ft.zoneId.isEmpty ? '' : ' of ${engItemName(b, ft.zoneId)}'}, ${m.count} readings.',
    'Measured: mean ${engN(m.mean, 2)} $unit (least ${engN(m.min, 2)}, most ${engN(m.max, 2)}); CU ${engN(m.cu, 1)} %, DU ${engN(m.du, 1)} %, US ${engN(m.us, 1)} %${cans ? '; mean rate ${engN(e.meanRateMmH, 2)} mm/h' : ''}.',
    if (cans && e.predictedStats.count > 0) 'Design at the same cans: mean ${engN(e.predictedStats.mean, 2)} mm, CU ${engN(e.predictedStats.cu, 1)} %, DU ${engN(e.predictedStats.du, 1)} %; measured/design ${engN(100 * e.meanRatio, 0)} %.',
    if (!cans && e.designMean > 0) 'Design mean flow of the zone ${engN(e.designMean, 2)} L/h; measured/design ${engN(100 * e.meanRatio, 0)} %.',
  ].join('\n');
}
