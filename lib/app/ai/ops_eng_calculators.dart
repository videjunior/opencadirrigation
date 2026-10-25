/// Engineering operations: the calculators of the Tools menu (lateral,
/// pump operating point, water hammer, solar pumping, wetted bulb, water
/// budget with cycle and soak, travelling gun, surface irrigation, gated
/// pipe) and the project settings the Tools and Design menus edit by hand
/// (display units, currency, site climate typed in). The calculators change
/// nothing; they call the same engine functions as the dialogs, with the
/// dialogs' defaults.
library;

import 'dart:math' as math;

import '../../core/api.dart';
import '../io/prefs.dart';
import 'agent_tools.dart';
import 'ops_eng_common.dart';

List<AgentTool> calculatorOperations(AgentToolbox b) {
  final c = b.c;
  final t = b.t;
  return [
    // ---------------------------------------------------------------- lateral
    engOp(
      b,
      name: 'lateral_calculator',
      description: 'Tools → Lateral calculator: hydraulics of ONE lateral from its inlet head — drip tape or a pipe with emitters (sprinklers, micro-sprinklers, drippers) every few metres — on a uniform slope: emitter count, inlet flow, friction loss, end, lowest and highest pressure, variation, velocity, uniformity (CU, DU, EU, US, qvar) and the longest lateral that keeps the pressures within the tolerances. Use it to size a lateral before drawing it; it changes nothing (for laterals already drawn run_design gives the real results). Inputs: kind "tape" (tape id) or "emitter" (outlet id, nozzle id, lateral pipe id, emitter_spacing_m); length_m 1–2000 (default 100); inlet_head_m 0.5–200 m of head (default 10); slope_pct −50…50, positive = the lateral runs downhill (default 0); tol_below_pct / tol_above_pct 0–60 % of the inlet head (default 10 each). Ids from search_catalog. Output: one line per figure, heads in m, flows in L/h and m³/h.',
      schema: obj({
        'kind': str('Lateral type (default tape when the catalogue has tapes).', ['tape', 'emitter']),
        'tape': str('Drip tape id (kind tape); default the first tape.'),
        'outlet': str('Emitter id (kind emitter); default the first emitter with nozzles.'),
        'nozzle': str('Nozzle id of that emitter; default its first nozzle.'),
        'pipe': str('Lateral pipe id (kind emitter); default the first lateral pipe.'),
        'emitter_spacing_m': num_('Emitter spacing along the pipe (kind emitter), 0.05–100 m; default 4.'),
        'length_m': num_('Lateral length, 1–2000 m; default 100.'),
        'inlet_head_m': num_('Head at the inlet, 0.5–200 m; default 10.'),
        'slope_pct': num_('Ground slope along the lateral, −50…50 %; positive runs downhill; default 0.'),
        'tol_below_pct': num_('Allowed pressure drop below the inlet head, 0–60 %; default 10.'),
        'tol_above_pct': num_('Allowed pressure rise above the inlet head, 0–60 %; default 10.'),
      }),
      run: (a, _) async {
        final cat = b.p.catalog;
        final params = b.p.params;
        final tapes = cat.tapes;
        final outlets = cat.outlets.where((o) => o.nozzles.isNotEmpty).toList();
        final pipes = cat.pipesFor(PipeUsage.lateral);
        final kind = a.str('kind') ?? (tapes.isNotEmpty ? 'tape' : 'emitter');
        final length = a.number('length_m', min: 1, max: 2000) ?? 100;
        final inlet = a.number('inlet_head_m', min: 0.5, max: 200) ?? 10;
        final slope = a.number('slope_pct', min: -50, max: 50) ?? 0;
        final below = a.number('tol_below_pct', min: 0, max: 60) ?? 10;
        final above = a.number('tol_above_pct', min: 0, max: 60) ?? 10;
        LateralSpec spec;
        double cv;
        String what;
        if (kind == 'tape') {
          if (tapes.isEmpty) throw ToolInputError('The catalogue has no drip tape: use kind "emitter" or add a tape (edit_catalog).');
          final id = a.str('tape') ?? tapes.first.id;
          final tp = cat.tape(id) ?? (throw ToolInputError('Unknown tape "$id". Tapes: ${tapes.map((x) => x.id).join(', ')}.'));
          spec = LateralSpec(
            length: length,
            diameter: tp.innerDiameter,
            spacing: tp.emitterSpacingM,
            emitter: tp.emitter,
            barbK: tp.barbK,
            method: params.frictionMethod,
            hazenC: tp.hazenC,
            roughness: tp.roughnessMm / 1000,
            kinematicViscosity: params.kinematicViscosity,
          );
          cv = tp.cv;
          what = 'tape ${tp.id} (${tp.name}), emitters every ${engN(tp.emitterSpacingM)} m';
        } else {
          if (outlets.isEmpty || pipes.isEmpty) throw ToolInputError('An emitter lateral needs an emitter with nozzles and a lateral pipe in the catalogue.');
          final oid = a.str('outlet') ?? outlets.first.id;
          final o = cat.outlet(oid) ?? (throw ToolInputError('Unknown emitter "$oid" (search_catalog kind "emitter").'));
          final n = o.nozzle(a.str('nozzle') ?? o.nozzles.first.id) ?? (throw ToolInputError('Emitter "$oid" has no nozzle "${a.str('nozzle')}"; nozzles: ${o.nozzles.map((x) => x.id).join(', ')}.'));
          final pid = a.str('pipe') ?? pipes.first.id;
          final pipe = cat.pipe(pid) ?? (throw ToolInputError('Unknown pipe "$pid" (search_catalog kind "pipe", usage "lateral").'));
          final spacing = a.number('emitter_spacing_m', min: 0.05, max: 100) ?? 4;
          spec = LateralSpec(
            length: length,
            diameter: pipe.innerDiameter,
            spacing: spacing,
            emitter: n.curve,
            firstOffset: spacing / 2,
            method: params.frictionMethod,
            hazenC: pipe.hazenC,
            roughness: pipe.roughness,
            kinematicViscosity: params.kinematicViscosity,
          );
          cv = n.cv;
          what = 'emitter ${o.id}/${n.id} every ${engN(spacing)} m on pipe ${pipe.id} (${pipe.name})';
        }
        double z(double d) => -slope / 100 * d;
        final res = analyzeLateralFromInlet(spec, inlet, elevationAt: z, manufacturerCv: cv);
        final maxLen = maxLateralLength(spec, nominalPressure: inlet, minPressure: inlet * (1 - below / 100), maxPressure: inlet * (1 + above / 100), elevationAt: z, maxLength: 600);
        final uf = res.uniformity;
        return ToolOutput(
          [
            'Lateral of ${engN(length, 1)} m: $what, inlet ${engN(inlet, 2)} m, slope ${engN(slope, 2)} %.',
            'Emitters: ${spec.outletCount}',
            'Inlet flow: ${engN(res.inletFlow / m3sPerLph, 1)} L/h (${engQ(res.inletFlow, 3)})',
            'Friction loss: ${engN(res.frictionLoss, 2)} m',
            'End pressure: ${engN(res.endPressure, 2)} m',
            'Lowest / highest pressure: ${engN(res.minPressure, 2)} m at ${engN(res.minPressureDistance, 0)} m / ${engN(res.maxPressure, 2)} m',
            'Pressure variation: ${engN(res.pressureVariationPct, 1)} %',
            'Highest velocity: ${engN(res.maxVelocity, 2)} m/s',
            'Uniformity CU / DU / EU / US: ${engN(uf.cu, 1)} / ${engN(uf.du, 1)} / ${engN(uf.eu, 1)} / ${engN(uf.us, 1)} %; qvar ${engN(uf.qvar, 1)} %',
            'Longest lateral within −${engN(below, 0)} % / +${engN(above, 0)} % of the inlet head (searched up to 600 m): ${engN(maxLen, 1)} m',
          ].join('\n'),
        );
      },
    ),
    // ---------------------------------------------------------------- pump operating point
    engOp(
      b,
      name: 'pump_operating_point',
      description: 'Tools → Pump calculator: where a catalogue pump meets a simple system curve (a static lift plus the friction of one pipe, Hazen-Williams): flow, head, pipe velocity, hydraulic and shaft power, annual energy and its cost, shut-off head and run-out flow. A quick check of a pump against a duty; it changes nothing (rank_pumps ranks the catalogue for the designed duty; apply_pump installs one). Inputs: pump (id, default the first), static_head_m 0–500 m (default 20), pipe (mainline pipe id, default the third mainline pipe), length_m 1–50000 (default 500), speed_ratio 0.3–1.5 of the rated speed (default 1), hours_per_year 1–8760 (default the design parameter). Output: one line per figure; "the pump cannot deliver" when the curves do not cross.',
      schema: obj({
        'pump': str('Pump id (search_catalog kind "pump").'),
        'static_head_m': num_('Static lift, 0–500 m; default 20.'),
        'pipe': str('Pipe id of the line (search_catalog kind "pipe").'),
        'length_m': num_('Pipe length, 1–50000 m; default 500.'),
        'speed_ratio': num_('Speed over the rated speed, 0.3–1.5; default 1.'),
        'hours_per_year': num_('Running hours per year, 1–8760; default the design parameter hoursPerYear.'),
      }),
      run: (a, _) async {
        final cat = b.p.catalog;
        if (cat.pumps.isEmpty) throw ToolInputError('The catalogue has no pump (edit_catalog adds one).');
        final mains = cat.pipesFor(PipeUsage.mainline);
        if (mains.isEmpty) throw ToolInputError('The catalogue has no mainline pipe.');
        final pid = a.str('pump') ?? cat.pumps.first.id;
        final pump = cat.pump(pid) ?? (throw ToolInputError('Unknown pump "$pid" (search_catalog kind "pump").'));
        final lid = a.str('pipe') ?? mains[math.min(2, mains.length - 1)].id;
        final pipe = cat.pipe(lid) ?? (throw ToolInputError('Unknown pipe "$lid" (search_catalog kind "pipe").'));
        final stat = a.number('static_head_m', min: 0, max: 500) ?? 20;
        final length = a.number('length_m', min: 1, max: 50000) ?? 500;
        final speed = a.number('speed_ratio', min: 0.3, max: 1.5) ?? 1;
        final hours = a.number('hours_per_year', min: 1, max: 8760) ?? b.p.params.hoursPerYear;
        final curve = pump.curve.withSpeed(speed);
        final k = hazenWilliamsResistance(diameter: pipe.innerDiameter, length: length, c: pipe.hazenC);
        final op = operatingPoint(curve, SystemCurve(staticHead: stat, k: k, n: 1.852), qMax: 0.05);
        final cur = b.p.params.currency;
        final lines = ['Pump ${pump.id} (${pump.name}) at ${engN(speed, 2)} × speed on ${engN(length, 0)} m of ${pipe.id} (${pipe.name}), static lift ${engN(stat, 1)} m.'];
        if (op == null) {
          lines.add('The pump cannot deliver against this system (the curves do not cross): lower the lift, take a larger pipe or another pump.');
        } else {
          final shaft = shaftPower(flow: op.$1, head: op.$2, efficiency: pump.efficiency);
          lines.addAll([
            'Operating point: ${engQ(op.$1)} at ${engN(op.$2, 2)} m',
            'Pipe velocity: ${engN(velocity(flow: op.$1, diameter: pipe.innerDiameter), 2)} m/s',
            'Hydraulic power: ${engN(hydraulicPower(flow: op.$1, head: op.$2) / 1000, 2)} kW',
            'Shaft power at ${engN(pump.efficiency * 100, 0)} % efficiency: ${engN(shaft / 1000, 2)} kW (${engN(shaft / 735.5, 1)} cv)',
            'Annual energy: ${engN(shaft / 1000 * hours, 0)} kWh → $cur ${engN(annualEnergyCost(flow: op.$1, head: op.$2, hoursPerYear: hours, costPerKwh: b.p.params.powerCostPerKwh, pumpEfficiency: pump.efficiency), 0)} ($hours h/year)',
          ]);
        }
        lines.add('Shut-off head / run-out flow: ${engN(curve.shutoffHead, 1)} m / ${curve.runoutFlow.isFinite ? engQ(curve.runoutFlow, 1) : '∞'}');
        return ToolOutput(lines.join('\n'));
      },
    ),
    // ---------------------------------------------------------------- water hammer
    engOp(
      b,
      name: 'water_hammer_calculator',
      description: 'Tools → Water hammer (Joukowsky): the wave speed of a catalogue pipe, the surge of a sudden velocity change, the critical closure time 2L/a, the surge of a slower closure and the total head against the pipe class at the water temperature. A first estimate for one pipe; it changes nothing (transient_study simulates the whole designed mainline). Inputs: pipe (id, default the first mainline pipe), velocity_change_mps 0–10 m/s (default 1.5), length_m 1–50000 (default 500), closure_s 0–600 s (default 2), static_head_m 0–500 m (default 40). Output: one line per figure in m of head.',
      schema: obj({
        'pipe': str('Pipe id (search_catalog kind "pipe").'),
        'velocity_change_mps': num_('Velocity stopped, 0–10 m/s; default 1.5.'),
        'length_m': num_('Pipe length to the reflection point, 1–50000 m; default 500.'),
        'closure_s': num_('Valve closure time, 0–600 s; default 2.'),
        'static_head_m': num_('Steady head before the closure, 0–500 m; default 40.'),
      }),
      run: (a, _) async {
        final cat = b.p.catalog;
        final mains = cat.pipesFor(PipeUsage.mainline);
        if (cat.pipes.isEmpty) throw ToolInputError('The catalogue has no pipe.');
        final id = a.str('pipe') ?? (mains.isNotEmpty ? mains.first.id : cat.pipes.first.id);
        final pipe = cat.pipe(id) ?? (throw ToolInputError('Unknown pipe "$id" (search_catalog kind "pipe").'));
        final vel = a.number('velocity_change_mps', min: 0, max: 10) ?? 1.5;
        final length = a.number('length_m', min: 1, max: 50000) ?? 500;
        final closure = a.number('closure_s', min: 0, max: 600) ?? 2;
        final stat = a.number('static_head_m', min: 0, max: 500) ?? 40;
        final wave = waveCelerity(diameter: pipe.innerDiameter, wallThickness: pipe.wallThicknessMm / 1000, material: pipe.material);
        final dh = joukowskySurgeHead(celerity: wave, velocityChange: vel);
        final tc = criticalClosureTime(length: length, celerity: wave);
        final eff = closure < tc ? dh : dh * tc / closure;
        final rating = pipe.ratingAt(b.p.params.waterTempC);
        return ToolOutput(
          [
            'Pipe ${pipe.id} (${pipe.name}, ${pipe.material.name}), ${engN(length, 0)} m, velocity change ${engN(vel, 2)} m/s, closure ${engN(closure, 1)} s.',
            'Wave speed: ${engN(wave, 0)} m/s',
            'Joukowsky surge (sudden closure): ${engN(dh, 1)} m',
            'Critical closure time 2L/a: ${engN(tc, 2)} s (${closure < tc ? 'the closure is quicker: the full surge applies' : 'the closure is slower: the surge is reduced'})',
            'Surge of this closure: ${engN(eff, 1)} m',
            'Total head: ${engN(stat + eff, 1)} m against the pipe class ${engN(rating, 0)} m at ${engN(b.p.params.waterTempC, 0)} °C${stat + eff > rating ? ' — ABOVE THE CLASS' : ''}',
          ].join('\n'),
        );
      },
    ),
    // ---------------------------------------------------------------- solar pumping
    engOp(
      b,
      name: 'solar_pumping',
      description: 'Tools → Solar pumping: sizes a photovoltaic array for the pumping of the project from the daily volume of every month, the pump head and the monthly irradiation at the site: peak sun hours, kWp needed per month, the critical month, the modules, the water pumped against the demand and the grid energy it saves. It changes nothing. Defaults as the dialog: daily volumes from the irrigation requirement of the areas, head from the design (the largest pump head or required supply head), irradiation from the site climate (download_climate) else 5 kWh/m²/day, latitude of the site else −15°. Inputs: daily_volume_m3 (12 numbers m³/day, Jan…Dec), radiation_kwh_m2_day (12 numbers), head_m 0–1000, motor_pump_efficiency 0.05–0.95 (default 0.45), module_wp 10–1000 W (default 550), tilt_deg 0–90 (default |latitude|), latitude_deg −90…90. Output: a month table and the array summary.',
      schema: obj({
        'daily_volume_m3': numbers('Water to pump per day for each month, m³/day, Jan…Dec (12 numbers).', n: 12),
        'radiation_kwh_m2_day': numbers('Global horizontal irradiation for each month, kWh/m²/day (12 numbers).', n: 12),
        'head_m': num_('Total dynamic head of the pump, 0–1000 m.'),
        'motor_pump_efficiency': num_('Motor-pump set efficiency, 0.05–0.95; default 0.45.'),
        'module_wp': num_('Peak power of one module, 10–1000 W; default 550.'),
        'tilt_deg': num_('Tilt of the modules, 0–90°; default the absolute latitude.'),
        'latitude_deg': num_('Site latitude, −90…90°; default the georeferenced site, else −15.'),
      }),
      run: (a, i) async {
        final p = b.p;
        final volume =
            engNumbers(i['daily_volume_m3'], 'daily_volume_m3', length: 12, min: 0, max: 1e7) ??
            () {
              final v = List<double>.filled(12, 0);
              for (final table in areaRequirementTables(p, c.results).values) {
                for (final row in table.monthly) {
                  v[row.start.month - 1] += row.dailyVolumeM3;
                }
              }
              return v;
            }();
        final radiation = engNumbers(i['radiation_kwh_m2_day'], 'radiation_kwh_m2_day', length: 12, min: 0, max: 15) ?? [...(p.climate?.solarKWhM2Day ?? List.filled(12, 5.0))];
        double designHead() {
          var h = 0.0;
          for (final f in c.results?.systemFlows ?? const <SystemFlowResult>[]) {
            for (final d in f.devices) {
              h = math.max(h, d.pumpHead);
            }
            for (final s in f.supplies) {
              if (s.calculated) h = math.max(h, s.requiredHead);
            }
          }
          return h;
        }

        final head = a.number('head_m', min: 0, max: 1000) ?? designHead();
        final lat = a.number('latitude_deg', min: -90, max: 90) ?? c.siteLatLon?.$1 ?? -15.0;
        final module = a.number('module_wp', min: 10, max: 1000) ?? 550;
        final res = sizeSolarPumping(
          SolarPumpInput(
            months: [for (var m = 0; m < 12; m++) SolarPumpMonth(month: m + 1, dailyVolumeM3: volume[m], horizontalKWhM2Day: radiation[m])],
            latitudeDeg: lat,
            headM: head,
            tiltDeg: a.number('tilt_deg', min: 0, max: 90) ?? c.siteLatLon?.$1.abs() ?? 15.0,
            motorPumpEfficiency: a.number('motor_pump_efficiency', min: 0.05, max: 0.95) ?? 0.45,
            modulePowerWp: module,
            gridTariffPerKWh: p.params.powerCostPerKwh,
          ),
        );
        final cur = p.params.currency;
        return ToolOutput(
          [
                'Head ${engN(head, 1)} m, latitude ${engN(lat, 2)}°, tilt ${engN(res.tiltDeg, 1)}°${p.climate?.solarKWhM2Day == null && !i.containsKey('radiation_kwh_m2_day') ? ' (no irradiation in the site climate: 5 kWh/m²/day assumed; download_climate gives the real values)' : ''}.',
                engTable(
                  ['month', 'demand m³/d', 'irradiation kWh/m²/d', 'peak sun h', 'kWp needed', 'pumped m³/d', 'pumping h'],
                  [
                    for (final m in res.months)
                      [
                        '${engMonths[m.month - 1]}${m.month == res.criticalMonth ? ' *' : ''}',
                        engN(m.demandM3Day, 1),
                        engN(radiation[m.month - 1], 2),
                        engN(m.peakSunHours, 2),
                        engN(m.requiredKWp, 2),
                        '${engN(m.pumpedM3Day, 1)}${m.pumpedM3Day + 1e-6 < m.demandM3Day ? ' (short)' : ''}',
                        engN(m.pumpingHours, 1),
                      ],
                  ],
                ),
                if (volume.every((v) => v <= 0)) 'No water to pump: the areas have no irrigation requirement (a crop and the site climate) — give daily_volume_m3.',
                'Critical month (*): ${res.criticalMonth == null ? '-' : engMonths[res.criticalMonth! - 1]}',
                'Array: ${res.modules} × ${engN(module, 0)} Wp = ${engN(res.arrayKWp, 2)} kWp',
                'Year: ${engN(res.annualPumpedM3, 0)} m³ pumped of ${engN(res.annualDemandM3, 0)} m³ needed',
                'Grid energy replaced: ${engN(res.annualGridKWh, 0)} kWh = $cur ${engN(res.annualGridCost, 2)}/year',
              ].join('\n') +
              engCodes(b, res.warnings, name: (m) => engMonths[(int.tryParse(m) ?? 1).clamp(1, 12) - 1]),
        );
      },
    ),
    // ---------------------------------------------------------------- wetted bulb
    engOp(
      b,
      name: 'wetted_bulb',
      description: 'Tools → Wetted bulb (Schwartzman–Zur): width and depth of the soil a dripper wets with one irrigation, and the wetted share of the ground for an emitter and lateral spacing — to choose the dripper flow and spacing for a soil. It changes nothing. Inputs: soil (texture, default loam), flow_lph 0.1–100 L/h (default 2), volume_l 0–1000 L per emitter per irrigation (default 8), emitter_spacing_m 0.05–10 (default 0.5), lateral_spacing_m 0.1–20 (default 1, one lateral per row). Output: width m, depth m, wetted %, the soil Ksat; a note when outside the range of the fit.',
      schema: obj({
        'soil': str('Soil texture; default loam.', [for (final k in soilTable.keys) k.substring(5)]),
        'flow_lph': num_('Dripper flow, 0.1–100 L/h; default 2.'),
        'volume_l': num_('Water per dripper per irrigation, 0–1000 L; default 8.'),
        'emitter_spacing_m': num_('Dripper spacing, 0.05–10 m; default 0.5.'),
        'lateral_spacing_m': num_('Lateral (row) spacing, 0.1–20 m; default 1.'),
      }),
      run: (a, _) async {
        final key = 'soil.${a.str('soil') ?? 'loam'}';
        final s = soilTable[key] ?? (throw ToolInputError('Unknown soil "${a.str('soil')}". One of: ${soilTable.keys.map((k) => k.substring(5)).join(', ')}.'));
        final flow = a.number('flow_lph', min: 0.1, max: 100) ?? 2;
        final volume = a.number('volume_l', min: 0, max: 1000) ?? 8;
        final se = a.number('emitter_spacing_m', min: 0.05, max: 10) ?? 0.5;
        final sl = a.number('lateral_spacing_m', min: 0.1, max: 20) ?? 1;
        final bulb = schwartzmanZurBulb(flowLph: flow, volumeL: volume, ksatMmH: s.ksatMmH);
        final pw = percentWettedAreaOfLaterals(lateralsPerRow: 1, emitterSpacingM: se, wettedWidthM: bulb.widthM, rowSpacingM: sl);
        return ToolOutput(
          [
            '${t(key)} (Ksat ${engN(s.ksatMmH, 1)} mm/h), ${engN(flow, 2)} L/h, ${engN(volume, 1)} L per irrigation, emitters every ${engN(se, 2)} m, laterals every ${engN(sl, 2)} m.',
            'Wetted width: ${engN(bulb.widthM, 2)} m',
            'Wetted depth: ${engN(bulb.depthM, 2)} m',
            'Wetted share of the ground: ${engN(pw, 0)} %',
            if (bulb.extrapolated) 'Note: outside the soils and flows the fit was made for; treat as indicative.',
          ].join('\n'),
        );
      },
    ),
    // ---------------------------------------------------------------- water budget
    engOp(
      b,
      name: 'water_budget',
      description: 'Tools → Landscape water budget (model water-efficient landscape ordinance): the irrigated areas marked with a plant water use (area property "pwu": veryLow|low|moderate|high) as hydrozones, the maximum applied water allowance (MAWA) of the annual ETo against the estimated total water use (ETWU), the average ETAF against its limit, and the cycle-and-soak split of every area on its soil and slope (needs the area soil "soil" and its design precipitation rate). It changes nothing. Inputs: eto_mm_year 0–5000 mm (default the sum of the site climate, else 1500), residential (default true; non-residential has the lower ETAF limit). Output: the hydrozone table, the budget and the cycle-and-soak table.',
      schema: obj({'eto_mm_year': num_('Reference evapotranspiration of the year, 0–5000 mm.'), 'residential': bool_('Residential landscape (ETAF limit 0.55; 0.45 otherwise). Default true.')}),
      run: (a, _) async {
        final p = b.p;
        final areas = p.entities.whereType<AreaEntity>().where((x) => x.plantWaterUse.isNotEmpty).toList();
        if (areas.isEmpty) throw ToolInputError('No irrigated area has a plant water use: set "pwu" (veryLow, low, moderate or high) on the areas with update_entities first.');
        final cl = p.climate;
        final eto =
            a.number('eto_mm_year', min: 0, max: 5000) ?? (cl == null ? 1500.0 : [for (var m = 0; m < 12; m++) cl.etoMmDay[m] * DateTime.utc(2001, m + 2, 0).day].fold<double>(0.0, (x, y) => x + y));
        final residential = a.flag('residential') ?? true;
        double pf(String use) {
          final (lo, hi) = plantFactorRange(PlantWaterUse.values.asNameMap()[use] ?? PlantWaterUse.moderate);
          return (lo + hi) / 2;
        }

        final zones = [
          for (final x in areas)
            Hydrozone(id: x.id, area: x.area, plantFactor: pf(x.plantWaterUse), irrigationEfficiency: x.irrigationMethod == 'localized' ? mweloEfficiencyDrip : mweloEfficiencySpray),
        ];
        final wb = mweloWaterBudget(etoPerYear: eto, hydrozones: zones, residential: residential);
        final req = {for (final r in areaRequirements(p, c.results)) r.areaId: r};
        final soak = <List<Object?>>[];
        for (final x in areas) {
          final r = req[x.id];
          final soil = soilTable[x.soilKey];
          if (r == null || soil == null || !(r.precipitationMmH > 0) || !(r.grossDepthMm > 0)) {
            soak.add([b.nameOf(x), '-', '-', '-', '-', soil == null ? 'needs a soil' : 'needs a precipitation rate and a depth']);
            continue;
          }
          final cs = cycleAndSoakForSoil(precipitationRateMmH: r.precipitationMmH, depthMm: r.grossDepthMm, texture: soil.texture, slopePct: x.slopePct);
          soak.add([b.nameOf(x), engN(r.precipitationMmH, 1), engN(r.grossDepthMm, 1), '${cs.cycles}', engN(cs.runMinutesPerCycle, 0), cs.cycles > 1 ? engN(cs.soakMinutes, 0) : '-']);
        }
        return ToolOutput(
          [
            'ETo ${engN(eto, 0)} mm/year, ${residential ? 'residential' : 'non-residential'}.',
            engTable(
              ['area', 'm²', 'plant factor', 'irrigation efficiency', 'ETAF'],
              [
                for (var k = 0; k < areas.length; k++) [b.nameOf(areas[k]), engN(zones[k].area, 0), engN(zones[k].plantFactor, 2), engN(zones[k].irrigationEfficiency, 2), engN(zones[k].etaf, 2)],
              ],
            ),
            'MAWA: ${engN(wb.mawa / 1000, 1)} m³/year; ETWU: ${engN(wb.etwu / 1000, 1)} m³/year (${wb.etwu <= wb.mawa ? 'within' : 'ABOVE'} the allowance).',
            'Average ETAF ${engN(wb.averageEtaf, 2)} against the limit ${engN(wb.etafLimit, 2)}.',
            'Cycle and soak:',
            engTable(['area', 'precipitation mm/h', 'depth mm', 'cycles', 'run min/cycle', 'soak min'], soak),
          ].join('\n'),
        );
      },
    ),
    // ---------------------------------------------------------------- travelling gun
    engOp(
      b,
      name: 'traveller_gun',
      description: 'Tools → Travelling gun (hose reel): lane spacing for the wind, the travel speed for a target depth (or the depth of a given speed), lanes, times per lane and per cycle, application rate, hose friction and velocity, pressure at the hydrant and pump power. A field machine that is not drawn; it changes nothing. Gun: a catalogue gun (gun + nozzle ids, search_catalog kind "emitter", kind gun) gives the flow and wetted diameter at gun_pressure_m; otherwise flow_m3h and wetted_diameter_m. Inputs (defaults as the dialog: a 30 m³/h gun at 45 m on 350 m of 90 mm hose): gun_pressure_m 5–150, sector_deg 1–360, hose_length_m, hose_bore_mm, hose_c (Hazen-Williams), drive_loss_m (turbine/drive loss), gun_height_m, ground_rise_m, wind none|light|moderate|strong, tapered_nozzle, lane_spacing_m (0 = recommended), lane_length_m (0 = the hose length), field_width_m, target_depth_mm (default 25), speed_m_min (0 = from the depth), setup_h, hours_per_day 0.5–24, pump_efficiency_pct 5–95, soil_intake_mm_h (0 = not checked), min_speed_m_min / max_speed_m_min (machine limits, 0 = none). Output: one line per figure and the machine messages.',
      schema: obj({
        'gun': str('Catalogue gun id (kind gun); omit to type the flow and diameter.'),
        'nozzle': str('Nozzle id of that gun; default its first.'),
        'flow_m3h': num_('Gun flow without a catalogue gun, 1–500 m³/h; default 30.'),
        'wetted_diameter_m': num_('Wetted diameter without a catalogue gun, 5–250 m; default 90.'),
        'gun_pressure_m': num_('Pressure at the gun, 5–150 m; default 45.'),
        'sector_deg': num_('Sector the gun wets, 1–360°; default 360.'),
        'hose_length_m': num_('Hose length, 10–1500 m; default 350.'),
        'hose_bore_mm': num_('Hose bore, 20–200 mm; default 90.'),
        'hose_c': num_('Hazen-Williams C of the hose, 60–160; default 150.'),
        'drive_loss_m': num_('Loss of the drive turbine and reel, 0–50 m; default 8.'),
        'gun_height_m': num_('Gun height above the hydrant, −10…10 m; default 0.'),
        'ground_rise_m': num_('Ground rise from the hydrant to the gun, −100…100 m; default 0.'),
        'wind': str('Wind class; default light.', [for (final w in WindClass.values) w.name]),
        'tapered_nozzle': bool_('Tapered (true, default) or ring nozzle.'),
        'lane_spacing_m': num_('Lane spacing, 0–300 m; 0 = the recommended spacing for the wind.'),
        'lane_length_m': num_('Run length of a lane, 0–2000 m; 0 = the hose length.'),
        'field_width_m': num_('Field width across the lanes, 0–20000 m; 0 = one lane.'),
        'target_depth_mm': num_('Gross depth per pass, 0–200 mm; default 25.'),
        'speed_m_min': num_('Travel speed, 0–10 m/min; 0 = the speed for the target depth.'),
        'setup_h': num_('Hours to move and set up per lane, 0–24; default 0.5.'),
        'hours_per_day': num_('Working hours per day, 0.5–24; default 22.'),
        'pump_efficiency_pct': num_('Pump efficiency, 5–95 %; default 70.'),
        'soil_intake_mm_h': num_('Soil intake rate to check the application rate, 0–500 mm/h; 0 = not checked.'),
        'min_speed_m_min': num_('Slowest speed of the machine, 0–10 m/min; 0 = none.'),
        'max_speed_m_min': num_('Fastest speed of the machine, 0–10 m/min; 0 = none.'),
      }),
      run: (a, _) async {
        final p = b.p;
        final pressure = a.number('gun_pressure_m', min: 5, max: 150) ?? 45;
        double flow = (a.number('flow_m3h', min: 1, max: 500) ?? 30) * m3sPerM3h, diameter = a.number('wetted_diameter_m', min: 5, max: 250) ?? 90;
        var gunText = 'typed gun';
        final gid = a.str('gun');
        if (gid != null) {
          final gun = p.catalog.outlet(gid);
          if (gun == null || gun.kind != OutletKind.gun || gun.nozzles.isEmpty) {
            throw ToolInputError('"$gid" is not a gun of the catalogue. Guns: ${p.catalog.outlets.where((o) => o.kind == OutletKind.gun).map((o) => o.id).join(', ')}.');
          }
          final nz =
              gun.nozzle(a.str('nozzle') ?? gun.nozzles.first.id) ?? (throw ToolInputError('Gun "$gid" has no nozzle "${a.str('nozzle')}"; nozzles: ${gun.nozzles.map((x) => x.id).join(', ')}.'));
          (flow, diameter) = gunPerformance(nz, pressure);
          gunText = 'gun ${gun.id}/${nz.id}';
        }
        final r = analyzeTraveller(
          TravellerSpec(
            gunFlow: flow,
            gunPressureM: pressure,
            wettedDiameterM: diameter,
            sectorDeg: a.number('sector_deg', min: 1, max: 360) ?? 360,
            hoseLengthM: a.number('hose_length_m', min: 10, max: 1500) ?? 350,
            hoseInnerMm: a.number('hose_bore_mm', min: 20, max: 200) ?? 90,
            hoseHazenC: a.number('hose_c', min: 60, max: 160) ?? 150,
            method: p.params.frictionMethod,
            kinematicViscosity: p.params.kinematicViscosity,
            driveLossM: a.number('drive_loss_m', min: 0, max: 50) ?? 8,
            gunHeightM: a.number('gun_height_m', min: -10, max: 10) ?? 0,
            groundRiseM: a.number('ground_rise_m', min: -100, max: 100) ?? 0,
            wind: WindClass.values.byName(a.str('wind') ?? 'light'),
            taperedNozzle: a.flag('tapered_nozzle') ?? true,
            laneSpacingM: a.number('lane_spacing_m', min: 0, max: 300) ?? 0,
            laneLengthM: a.number('lane_length_m', min: 0, max: 2000) ?? 0,
            fieldWidthM: a.number('field_width_m', min: 0, max: 20000) ?? 0,
            targetDepthMm: a.number('target_depth_mm', min: 0, max: 200) ?? 25,
            speedMPerMin: a.number('speed_m_min', min: 0, max: 10) ?? 0,
            setupHours: a.number('setup_h', min: 0, max: 24) ?? 0.5,
            hoursPerDay: a.number('hours_per_day', min: 0.5, max: 24) ?? 22,
            pumpEfficiency: (a.number('pump_efficiency_pct', min: 5, max: 95) ?? 70) / 100,
            soilIntakeMmH: a.number('soil_intake_mm_h', min: 0, max: 500) ?? 0,
            minSpeedMPerMin: a.number('min_speed_m_min', min: 0, max: 10) ?? 0,
            maxSpeedMPerMin: a.number('max_speed_m_min', min: 0, max: 10) ?? 0,
          ),
        );
        return ToolOutput(
          [
                '$gunText: ${engQ(flow, 1)} at ${engN(pressure, 1)} m, wetted diameter ${engN(diameter, 1)} m.',
                'Lane spacing: ${engN(r.laneSpacingM, 1)} m = ${engN(r.laneSpacingPct, 0)} % of the wetted diameter (recommended ${engN(r.recommendedPct, 0)} %)',
                'Lanes: ${r.lanes}; run length ${engN(r.laneLengthM, 0)} m',
                'Speed: ${r.speedMPerMin > 0 ? '${engN(r.speedMPerMin, 2)} m/min (${engN(r.speedMPerMin * 60, 0)} m/h)' : '-'}',
                'Gross depth: ${engN(r.grossDepthMm, 1)} mm',
                'Travel per lane: ${engN(r.travelHours, 1)} h; lane with set-up: ${engN(r.laneHours, 1)} h',
                'Cycle over the field: ${engN(r.cycleHours, 1)} h = ${engN(r.cycleDays, 1)} days',
                'Area per lane: ${engN(r.areaPerLaneM2 / 1e4, 2)} ha; volume per lane ${engN(r.volumePerLaneM3, 0)} m³',
                'Application rate: ${engN(r.applicationRateMmH, 1)} mm/h',
                'Hose friction: ${engN(r.hoseFrictionM, 1)} m at ${engN(r.hoseVelocity, 2)} m/s',
                'Pressure at the hydrant: ${engN(r.inletHeadM, 1)} m',
                'Power hydraulic / shaft: ${engN(r.hydraulicPowerKw, 2)} / ${engN(r.shaftPowerKw, 2)} kW',
              ].join('\n') +
              engCodes(b, r.warnings),
        );
      },
    ),
    // ---------------------------------------------------------------- surface irrigation
    engOp(
      b,
      name: 'surface_irrigation',
      description: 'Tools → Surface irrigation (FAO 45 volume balance): furrows, open-end borders or level basins. Mode "design" finds the inflow of best application efficiency and its cutoff for the required depth (with a table of the inflows tried); mode "evaluate" rates a given inflow and cutoff: advance, cutoff, recession, inlet depth, application and requirement efficiency, low-quarter DU, deep percolation, tailwater, depths and the volume applied. It changes nothing. Infiltration: an NRCS intake family (in/h; first or later irrigation) or typed Kostiakov-Lewis k, a, f0 per minute (furrow: m³/m/min^a and m³/m/min; border/basin: m/min^a and m/min). Inputs (defaults of the dialog, the FAO 45 example furrow): system, mode, length_m 5–2000 (200), slope_pct 0–10 (0.1; basins level), manning_n (furrow 0.04, border/basin 0.15), furrow_spacing_m (0.75), required_depth_mm 1–500 (80), field_width_m (0 = one furrow / unit width), intake_family 0.05–4 in/h (0.5), later_irrigation, kostiakov {k, a, f0}, max_velocity_m_min (13, design), inflow_lps (evaluate: per furrow, or per metre of border width; default 0.6 / 5), cutoff_min (evaluate, default 450). Output: the figures, the design table and the messages.',
      schema: obj({
        'system': str('Default furrow.', [for (final s in SurfaceSystem.values) s.name]),
        'mode': str('design (default) or evaluate.', ['design', 'evaluate']),
        'length_m': num_('Run length, 5–2000 m; default 200.'),
        'slope_pct': num_('Slope along the run, 0–10 %; default 0.1.'),
        'manning_n': num_('Manning roughness n, 0.01–0.6; default by system.'),
        'furrow_spacing_m': num_('Furrow spacing, 0.2–3 m; default 0.75.'),
        'required_depth_mm': num_('Depth to infiltrate, 1–500 mm; default 80.'),
        'field_width_m': num_('Field width for the total flow, 0–10000 m; default 0.'),
        'intake_family': num_('NRCS intake family (in/h): 0.05, 0.1, 0.15, 0.2, 0.25, 0.3, 0.35, 0.4, 0.45, 0.5, 0.6, 0.7, 0.8, 0.9, 1, 1.5, 2, 3 or 4; default 0.5.'),
        'later_irrigation': bool_('NRCS family of a later irrigation (default false: the first one).'),
        'kostiakov': obj(
          {
            'k': num_('Kostiakov k per minute (furrow m³/m/min^a; border, basin m/min^a).'),
            'a': num_('Exponent a, 0.01–1.'),
            'f0': num_('Basic intake f0 per minute (furrow m³/m/min; border, basin m/min); default 0.'),
          },
          required: ['k', 'a'],
        ),
        'max_velocity_m_min': num_('Design: largest non-erosive velocity, 1–60 m/min; default 13.'),
        'inflow_lps': num_('Evaluate: inflow, L/s per furrow (furrows) or per metre of width (borders, basins).'),
        'cutoff_min': num_('Evaluate: cutoff time, 1–5000 min; default 450.'),
      }),
      run: (a, i) async {
        final system = SurfaceSystem.values.byName(a.str('system') ?? 'furrow');
        final furrow = system == SurfaceSystem.furrow;
        final design = (a.str('mode') ?? 'design') == 'design';
        final req = (a.number('required_depth_mm', min: 1, max: 500) ?? 80) / 1000;
        KostiakovLewis intake;
        String intakeText;
        if (i['kostiakov'] is Map) {
          final m = Map<String, dynamic>.from(i['kostiakov'] as Map);
          final kv = ToolArgs(m);
          final k = kv.number('k', min: 1e-9, max: 10, required: true)!, ax = kv.number('a', min: 0.01, max: 1, required: true)!, f0 = kv.number('f0', min: 0, max: 1) ?? 0;
          intake = KostiakovLewis.perMinute(k: k, a: ax, f0: f0);
          intakeText = 'Kostiakov-Lewis k ${engN(k, 6)}, a ${engN(ax, 3)}, f0 ${engN(f0, 7)} per minute';
        } else {
          final family = a.number('intake_family', min: 0.05, max: 4) ?? 0.5;
          final known = [for (final f in nrcsIntakeFamiliesInitial) f.family];
          if (!known.any((f) => (f - family).abs() < 1e-9)) throw ToolInputError('"intake_family" must be one of ${known.map((f) => engN(f, 2)).join(', ')} in/h.');
          final later = a.flag('later_irrigation') ?? false;
          intake = furrow ? nrcsFurrowIntake(family, later: later) : nrcsBorderIntake(family, later: later);
          intakeText = 'NRCS family ${engN(family, 2)} in/h (${later ? 'later' : 'first'} irrigation)';
        }
        final spacing = a.number('furrow_spacing_m', min: 0.2, max: 3) ?? 0.75;
        final spec = SurfaceSpec(
          system: system,
          lengthM: a.number('length_m', min: 5, max: 2000) ?? 200,
          intake: intake,
          slope: (system == SurfaceSystem.basin ? 0 : (a.number('slope_pct', min: 0, max: 10) ?? 0.1)) / 100,
          manningN: a.number('manning_n', min: 0.01, max: 0.6) ?? (furrow ? 0.04 : 0.15),
          furrowSpacingM: spacing,
        );
        final width = a.number('field_width_m', min: 0, max: 10000) ?? 0;
        final SurfaceDesign? d = design ? designSurface(spec, requiredDepthM: req, maxVelocity: (a.number('max_velocity_m_min', min: 1, max: 60) ?? 13) / 60) : null;
        final inflowLps = a.number('inflow_lps', min: 0.001, max: 1000);
        final e = design ? d!.best : evaluateSurface(spec, inflow: (inflowLps ?? (furrow ? 0.6 : 5)) / 1000, cutoffS: (a.number('cutoff_min', min: 1, max: 5000) ?? 450) * 60, requiredDepthM: req);
        final qUnit = furrow ? 'L/s per furrow' : 'L/s per m of width';
        String min(double s) => s.isFinite ? '${engN(s / 60, 0)} min' : 'incomplete';
        final out = <String>[
          '${system.name}, ${design ? 'design' : 'evaluation'}, ${engN(spec.lengthM, 0)} m, slope ${engN(spec.slope * 100, 3)} %, n ${engN(spec.manningN, 3)}, $intakeText, required depth ${engN(req * 1000, 0)} mm.',
        ];
        if (e == null) {
          out.add('The water does not reach the end of the run with any inflow tried: shorten the run, raise the slope or the inflow.');
        } else {
          final count = width > 0 && spacing > 0 ? math.max(1, (width / spacing).round()) : 0;
          out.addAll([
            '${design ? 'Best inflow' : 'Inflow'}: ${engN(e.inflow * 1000, 3)} $qUnit${design ? ' (range tried ${engN(d!.minInflow * 1000, 3)}–${engN(d.maxInflow * 1000, 3)})' : ''}',
            'Advance: ${min(e.advanceS)}${e.complete ? '' : ' (the water does not reach the end)'}; cutoff ${min(e.cutoffS)}${system == SurfaceSystem.border ? '; recession ${min(e.recessionS)}' : ''}',
            'Inlet flow depth: ${engN(e.inletDepthM * 1000, 0)} mm',
            'Application efficiency ${engN(e.efficiency * 100, 1)} %, requirement efficiency ${engN(e.requirementEfficiency * 100, 1)} %, low-quarter DU ${engN(e.lowQuarterDu * 100, 1)} %',
            'Deep percolation ${engN(e.deepPercolationRatio * 100, 1)} %, tailwater ${engN(e.tailwaterRatio * 100, 1)} %',
            'Depths mean / least / most: ${engN(e.meanDepthM * 1000, 1)} / ${engN(e.minDepthM * 1000, 1)} / ${engN(e.maxDepthM * 1000, 1)} mm',
            'Applied: ${engN(e.appliedM3, 2)} m³ ${furrow ? 'per furrow' : 'per m of width'}',
            if (width > 0) 'Total flow over the field: ${furrow ? '${engQ(e.inflow * count, 1)} ($count furrows)' : engQ(e.inflow * width, 1)}',
          ]);
        }
        if (d != null && d.rows.isNotEmpty) {
          out.add(
            engTable(
              ['inflow $qUnit', 'advance min', 'cutoff min', 'Ea %', 'DU %', 'tailwater %', 'deep perc. %'],
              [
                for (final row in d.rows)
                  [
                    engN(row.inflow * 1000, 3),
                    row.advanceS.isFinite ? engN(row.advanceS / 60, 0) : '-',
                    row.cutoffS.isFinite ? engN(row.cutoffS / 60, 0) : '-',
                    engN(row.efficiency * 100, 1),
                    engN(row.lowQuarterDu * 100, 1),
                    engN(row.tailwaterRatio * 100, 1),
                    engN(row.deepPercolationRatio * 100, 1),
                  ],
              ],
            ),
          );
        }
        return ToolOutput(out.join('\n') + engCodes(b, design ? d!.warnings : (e?.warnings ?? const [])));
      },
    ),
    // ---------------------------------------------------------------- gated pipe
    engOp(
      b,
      name: 'gated_pipe',
      description: 'Tools → Gated pipe: the opening of every gate of a gated pipe feeding furrows (or the standard hole), so each furrow gets its flow with the friction and the slope gate by gate, and the least inlet head that serves them all. It changes nothing. Inputs (defaults of the dialog): gates 1–2000 (40), gate_spacing_m 0.2–5 (0.76, the furrow spacing), flow_per_gate_lps 0.01–50 L/s (1), first_gate_m (distance of the first gate from the inlet; −1 = half a spacing), pipe_bore_mm 50–600 (250), hazen_c 60–160 (150), slope_pct −5…5 (0; positive falls away from the inlet), inlet_head_m 0–20 (0 = the least head), discharge_coefficient 0.1–1 (0.61). Output: the summary and the gate table.',
      schema: obj({
        'gates': int_('Number of gates, 1–2000; default 40.'),
        'gate_spacing_m': num_('Gate spacing, 0.2–5 m; default 0.76.'),
        'flow_per_gate_lps': num_('Flow each furrow takes, 0.01–50 L/s; default 1.'),
        'first_gate_m': num_('Distance of the first gate from the inlet, 0–100 m; −1 (default) = half a spacing.'),
        'pipe_bore_mm': num_('Inner diameter of the gated pipe, 50–600 mm; default 250.'),
        'hazen_c': num_('Hazen-Williams C, 60–160; default 150.'),
        'slope_pct': num_('Slope along the pipe, −5…5 %; default 0.'),
        'inlet_head_m': num_('Head at the inlet, 0–20 m; 0 (default) = the least that serves every gate.'),
        'discharge_coefficient': num_('Gate discharge coefficient, 0.1–1; default 0.61.'),
      }),
      run: (a, _) async {
        final p = b.p.params;
        final first = a.number('first_gate_m', min: -1, max: 100) ?? -1;
        final r = designGatedPipe(
          GatedPipeSpec(
            outlets: a.integer('gates', min: 1, max: 2000) ?? 40,
            outletSpacingM: a.number('gate_spacing_m', min: 0.2, max: 5) ?? 0.76,
            targetFlow: (a.number('flow_per_gate_lps', min: 0.01, max: 50) ?? 1) / 1000,
            firstOutletM: first < 0 ? -1 : first,
            pipeInnerMm: a.number('pipe_bore_mm', min: 50, max: 600) ?? 250,
            hazenC: a.number('hazen_c', min: 60, max: 160) ?? 150,
            method: p.frictionMethod,
            kinematicViscosity: p.kinematicViscosity,
            slope: (a.number('slope_pct', min: -5, max: 5) ?? 0) / 100,
            inletHeadM: a.number('inlet_head_m', min: 0, max: 20) ?? 0,
            dischargeCoefficient: a.number('discharge_coefficient', min: 0.1, max: 1) ?? 0.61,
          ),
        );
        return ToolOutput(
          [
                'Inlet head used: ${engN(r.inletHeadM, 3)} m (least that serves every gate ${engN(r.minInletHeadM, 3)} m${r.inletHeadOk ? '' : ' — THE HEAD GIVEN IS TOO LOW'})',
                'Total flow: ${engQ(r.totalFlow, 1)} (${engN(r.totalFlow * 1000, 1)} L/s)',
                'Friction loss ${engN(r.frictionLossM, 3)} m, elevation gain ${engN(r.elevationGainM, 3)} m, inlet velocity ${engN(r.inletVelocity, 2)} m/s',
                engTable(
                  ['gate', 'distance m', 'pipe flow L/s', 'head m', 'target L/s', 'opening mm²', 'equivalent Ø mm', 'hole mm', 'opening %', 'full-open L/s'],
                  [
                    for (final g in r.gates)
                      [
                        '${g.index}',
                        engN(g.distanceM, 2),
                        engN(g.pipeFlow * 1000, 2),
                        engN(g.headM, 3),
                        engN(g.targetFlow * 1000, 2),
                        engN(g.areaMm2, 0),
                        engN(g.diameterMm, 1),
                        g.holeMm > 0 ? engN(g.holeMm, 1) : '-',
                        g.holeMm > 0 ? engN(g.openingPct, 0) : '-',
                        g.holeMm > 0 ? engN(g.fullFlow * 1000, 2) : '-',
                      ],
                  ],
                ),
              ].join('\n') +
              engCodes(b, r.warnings),
        );
      },
    ),
    // ---------------------------------------------------------------- currency
    engOp(
      b,
      name: 'set_currency',
      effect: ToolEffect.write,
      description: 'Design → Parameters → Currency: changes the currency of the project and, by default, converts every price (catalogue, energy price, quote) with the reference exchange rate or the rate given; the design results are discarded (costs change). One undo step. Use it when the user works in another currency or a catalogue pack came in another one; to only rename the currency set convert_prices false. Inputs: code (ISO 4217, e.g. BRL, USD, EUR), convert_prices (default true), rate (units of the new currency per unit of the current one; default the reference rate — required when none is known), symbol (shown symbol; default the currency\'s), make_default (also the currency of new projects on this browser; default false). Output: what changed.',
      schema: obj(
        {
          'code': str('ISO 4217 code.', [for (final x in currencies) x.code]),
          'convert_prices': bool_('Convert the prices (default true).'),
          'rate': num_('New currency per unit of the current one, > 0.'),
          'symbol': str('Symbol shown, e.g. "R\$".'),
          'make_default': bool_('Also the default of new projects (default false).'),
        },
        required: ['code'],
      ),
      summary: (i) => t('ai.op.set_currency', {'n': '${i['code']}'}),
      run: (a, _) async {
        engNotBusy(c);
        final code = a.str('code', required: true)!;
        final from = b.p.params.currencyCode;
        final convert = a.flag('convert_prices') ?? true;
        final rate = a.number('rate', min: 1e-9, max: 1e9) ?? exchangeRate(from, code);
        if (convert && rate == null) throw ToolInputError('No reference rate from "${from.isEmpty ? b.p.params.currency : from}" to $code: give "rate", or convert_prices false.');
        c.setProjectCurrency(code, rate: convert ? rate : null, symbol: a.str('symbol'));
        if (a.flag('make_default') ?? false) setPref('currency', code);
        return ToolOutput(
          'Currency ${from.isEmpty ? '(none)' : from} → $code (${b.p.params.currency})${convert ? '; prices converted at ${engN(rate!, 6)}' : '; prices kept as they were'}. Results discarded: run the design again for the costs.',
        );
      },
    ),
    // ---------------------------------------------------------------- site climate typed in
    engOp(
      b,
      name: 'set_site_climate',
      effect: ToolEffect.write,
      description: 'Design → Site climate, typed by hand: stores the twelve monthly reference evapotranspiration (ETo), rain, dependable rain and solar irradiation values of the site in the project (the irrigation requirement, the crop and schedule reports and solar_pumping use them), or clears them. Use it for values from a local station or a study; download_climate fetches them from an online archive instead. Arrays not given keep the values the project has (zeros when it has none). One undo step. Inputs (12 numbers each, January first): eto_mm_day 0–20, rain_mm 0–2000 (per month), dependable_rain_mm 0–2000, solar_kwh_m2_day 0–15; clear true removes the climate. Output: the stored table.',
      schema: obj({
        'eto_mm_day': numbers('Reference evapotranspiration, mm/day, Jan…Dec.', n: 12),
        'rain_mm': numbers('Rain, mm per month, Jan…Dec.', n: 12),
        'dependable_rain_mm': numbers('Dependable rain, mm per month, Jan…Dec.', n: 12),
        'solar_kwh_m2_day': numbers('Global horizontal irradiation, kWh/m²/day, Jan…Dec.', n: 12),
        'clear': bool_('Remove the site climate.'),
      }),
      run: (a, i) async {
        engNotBusy(c);
        if (a.flag('clear') ?? false) {
          c.setClimate(null);
          return const ToolOutput('Site climate removed.');
        }
        final cur = b.p.climate;
        final eto = engNumbers(i['eto_mm_day'], 'eto_mm_day', length: 12, min: 0, max: 20);
        final rain = engNumbers(i['rain_mm'], 'rain_mm', length: 12, min: 0, max: 2000);
        final dep = engNumbers(i['dependable_rain_mm'], 'dependable_rain_mm', length: 12, min: 0, max: 2000);
        final rs = engNumbers(i['solar_kwh_m2_day'], 'solar_kwh_m2_day', length: 12, min: 0, max: 15);
        if (eto == null && rain == null && dep == null && rs == null) throw ToolInputError('Give at least one of eto_mm_day, rain_mm, dependable_rain_mm, solar_kwh_m2_day (or clear).');
        final site = c.siteLatLon;
        final e = eto ?? cur?.etoMmDay ?? List.filled(12, 0.0), r = rain ?? cur?.rainMm ?? List.filled(12, 0.0);
        final d = dep ?? cur?.dependableRainMm, s = rs ?? cur?.solarKWhM2Day;
        final sc = SiteClimate(
          etoMmDay: [...e],
          rainMm: [...r],
          dependableRainMm: d == null || d.every((x) => x == 0) ? null : [...d],
          solarKWhM2Day: s == null || s.every((x) => x == 0) ? null : [...s],
          // values typed over a download keep its credit but are no longer the service's
          source: eto != null || rain != null || cur == null ? 'manual' : cur.source,
          firstYear: cur?.firstYear ?? 0,
          lastYear: cur?.lastYear ?? 0,
          latitudeDeg: site?.$1 ?? cur?.latitudeDeg ?? 0,
          longitudeDeg: site?.$2 ?? cur?.longitudeDeg ?? 0,
          retrieved: cur?.retrieved ?? '',
          attribution: cur?.attribution ?? '',
        );
        c.setClimate(sc);
        String row(List<double>? v) => v == null ? '-' : [for (final x in v) engN(x, 1)].join(' ');
        return ToolOutput(
          'Site climate (${sc.source}), Jan…Dec:\nETo mm/day: ${row(sc.etoMmDay)}\nRain mm: ${row(sc.rainMm)}\nDependable rain mm: ${row(sc.dependableRainMm)}\nIrradiation kWh/m²/day: ${row(sc.solarKWhM2Day)}',
        );
      },
    ),
  ];
}
