/// Engineering operations of the analyses of the designed network, with
/// every option of their dialogs (Mainline and Design menus): on-demand
/// operation, the time-of-use tariff schedule, the energy grouping of the
/// zones, the wire routes with the two-wire sizing, pipe criticality, the
/// roughness calibration from field readings, fertigation, hydraulic
/// transients, the 24-hour simulation, air valves and the densogram. The
/// analyses change nothing; their "apply" options make the change the
/// dialog's Apply button makes, as one undo step.
library;

import 'dart:math' as math;

import '../../core/api.dart';
import '../widgets/dialogs/transient_dialogs.dart' show lastTransientAnalysis;
import 'agent_tools.dart';
import 'ops_eng_common.dart';

/// The last transient analysis run by [transient_study], valid while the
/// project, its history position and its results stay the same.
final _lastTransient = Expando<(Object, Object?, int, TransientAnalysis)>();

TransientAnalysis? _transientOf(AgentToolbox b) {
  final c = b.c;
  final v = _lastTransient[c];
  if (v != null && identical(v.$1, c.project) && identical(v.$2, c.results) && v.$3 == c.historyIndex) return v.$4;
  return lastTransientAnalysis(c);
}

ToolEffect _applyEffect(Map<String, dynamic> i) => i['apply'] == true || i['insert'] == true ? ToolEffect.write : ToolEffect.read;

/// The model's pressure at every measuring point and the flow leaving every
/// supply for [sf] (the calibration dialog's "model" column).
(Map<String, double>, Map<String, double>) _modelOf(Designer d, SystemFlow sf, List<MeasurePoint> points) {
  final built = d.mainlineNetworkFor(sf);
  if (built == null) return (const {}, const {});
  final (net, res, _) = built;
  final pr = <String, double>{};
  for (final m in points) {
    final n = net.nodes[m.nodeId];
    if (n == null) continue;
    pr[m.entityId] = n.kind == HNodeKind.reservoir ? (n.fixedHead ?? n.elevation) - n.elevation : (res.nodes[m.nodeId]?.pressure ?? 0);
  }
  final q = <String, double>{};
  for (final s in points.where((m) => m.kind == MeasurePointKind.supply)) {
    var out = 0.0;
    for (final l in net.links) {
      final f = res.links[l.id]?.flow ?? 0;
      if (l.from == s.nodeId) out += f;
      if (l.to == s.nodeId) out -= f;
    }
    q[s.entityId] = out;
  }
  return (pr, q);
}

/// Compass bearing (0 = north, clockwise) of a mathematical angle (degrees
/// counter-clockwise from east), and back.
double _compassOf(double mathDeg) => ((90 - mathDeg) % 360 + 360) % 360;
double _mathOf(double compassDeg) => ((90 - compassDeg) % 360 + 360) % 360;

List<AgentTool> networkOperations(AgentToolbox b) {
  final c = b.c;
  final t = b.t;
  final flowArg = str('System flow id or name (get_report_table "mainline" or the project summary lists them); default the one carrying the most water.');
  return [
    // ---------------------------------------------------------------- on demand
    engOp(
      b,
      name: 'on_demand_study',
      description: 'Mainline → On-demand operation (FAO 59): every zone valve and pivot taken as a hydrant its user opens whenever needed, open with the probability of its hours of use. Clément flows per mainline pipe for the quality of operation asked, against the flows of the system flows the pipes were sized for; the head each supply must hold; and the random check (configurations of open hydrants drawn and solved: the share that leaves a hydrant short). Needs design results; changes nothing. run_analysis "on_demand" gives a short default answer; this op takes every option. Inputs: quality_pct 50–99.9 (default 95), utilisation 0.05–1 (default 1), min_simultaneous 0–50 hydrants (default 4), hours {hydrant id or zone name: hours per day 0–24} (default 8 h or the demand hours of the design), supply_head_m {supply id: head m} (default the design pressure), random_configurations 0 (skip) or 10–5000 (default 200), fixed_discharge (draws at the Clément source flow; default false: independent draws), flow_limited (default false), pipes_limit 1–500 (default 40). Output: hydrant table (with reliability after the random check), pipe table, U(Pq), source flow against the design peak, supply heads needed, the critical hydrant and the messages.',
      schema: obj({
        'quality_pct': num_('Quality of operation, 50–99.9 %; default 95.'),
        'utilisation': num_('Network utilisation coefficient, 0.05–1; default 1.'),
        'min_simultaneous': int_('Clément: least hydrants open together, 0–50; default 4.'),
        'hours': {'type': 'object', 'description': 'Hours of use per day of each hydrant: {valve or pivot id or zone name: hours 0–24}.'},
        'supply_head_m': {'type': 'object', 'description': 'Head at each water supply for the random check: {supply id: m}.'},
        'random_configurations': int_('Configurations of the random check, 10–5000; 0 skips it; default 200.'),
        'fixed_discharge': bool_('Draw at the Clément source flow (default false).'),
        'flow_limited': bool_('Hydrants with flow limiters (default false).'),
        'pipes_limit': int_('Rows of the pipe table, 1–500; default 40.'),
      }),
      run: (a, i) async {
        engNeedResults(c);
        final r = c.results!;
        final m = onDemandModel(b.p, r, label: t.call);
        if (m == null || m.hydrants.isEmpty) throw ToolInputError('No water supply or no demand on the mainline: nothing to operate on demand.');
        final name = engNamer(b, m.designer);
        final hours = {for (final h in m.hydrants) h.id: h.hoursPerDay};
        if (i['hours'] is Map) {
          for (final e in (i['hours'] as Map).entries) {
            final id = b.find('${e.key}').id;
            if (!hours.containsKey(id)) throw ToolInputError('hours: "${e.key}" is not a hydrant of the mainline (a zone valve or pivot with a design result).');
            final v = e.value;
            if (v is! num || v < 0 || v > 24) throw ToolInputError('hours["${e.key}"] must be 0–24.');
            hours[id] = v.toDouble();
          }
        }
        final pressure = {...m.supplyPressure};
        if (i['supply_head_m'] is Map) {
          for (final e in (i['supply_head_m'] as Map).entries) {
            final id = b.find('${e.key}').id;
            if (!pressure.containsKey(id)) throw ToolInputError('supply_head_m: "${e.key}" is not a water supply of the design. Supplies: ${pressure.keys.join(', ')}.');
            final v = e.value;
            if (v is! num || v < 0 || v > 1000) throw ToolInputError('supply_head_m["${e.key}"] must be 0–1000 m.');
            pressure[id] = v.toDouble();
          }
        }
        final hydrants = [for (final h in m.hydrants) Hydrant(id: h.id, nodeId: h.nodeId, discharge: h.discharge, minPressure: h.minPressure, hoursPerDay: hours[h.id] ?? 0)];
        final cl = await engSoon(
          () => clementFlows(
            m.network,
            hydrants,
            options: ClementOptions(
              operatingQuality: (a.number('quality_pct', min: 50, max: 99.9) ?? 95) / 100,
              utilisation: a.number('utilisation', min: 0.05, max: 1) ?? 1,
              minSimultaneous: a.integer('min_simultaneous', min: 0, max: 50) ?? 4,
            ),
          ),
        );
        final pipes = onDemandPipeRows(m, cl);
        final need = clementSupplyPressure(m, cl);
        final source = cl.sourceFlow.values.fold(0.0, (x, y) => x + y);
        final configs = a.integer('random_configurations', min: 0, max: 5000) ?? 200;
        if (configs > 0 && configs < 10) throw ToolInputError('"random_configurations" must be 0 or 10–5000.');
        final check = configs == 0
            ? null
            : await engSoon(
                () => checkRandomConfigurations(
                  onDemandCheckNetwork(m, pressure),
                  hydrants,
                  probabilities: cl.probabilities,
                  options: RandomCheckOptions(configurations: configs, upstreamDischarge: (a.flag('fixed_discharge') ?? false) ? source : 0, flowLimited: a.flag('flow_limited') ?? false),
                ),
              );
        final rel = {for (final h in check?.hydrants ?? const <HydrantReliability>[]) h.hydrantId: h};
        final peak = r.systemFlows.fold(0.0, (x, f) => math.max(x, f.totalFlow));
        final vmax = b.p.params.maxMainlineVelocity;
        final out = <String>[
          engTable(
            [
              'hydrant',
              'flow m³/h',
              'hours/day',
              'p open',
              'min head m',
              if (check != null) ...['reliability %', 'max deficit m'],
            ],
            [
              for (final h in m.hydrants)
                [
                  '${name(h.id)}${h.id == cl.criticalHydrant ? ' (critical)' : ''}',
                  engN(h.discharge * 3600, 2),
                  engN(hours[h.id] ?? 0, 1),
                  engN(cl.probabilities[h.id] ?? 0, 3),
                  engN(h.minPressure, 1),
                  if (check != null) ...[engN((rel[h.id]?.reliability ?? 1) * 100, 1), engN(rel[h.id]?.maxDeficit ?? 0, 1)],
                ],
            ],
          ),
          engTable(
            ['pipe', 'hydrants downstream', 'Clément m³/h', 'design m³/h', 'ratio', 'velocity m/s', 'rule'],
            [
              for (final row in pipes)
                [
                  name(row.entityId),
                  '${row.hydrants}',
                  engN(row.flow * 3600, 2),
                  engN(row.designFlow * 3600, 2),
                  row.ratio.isFinite ? '${engN(row.ratio, 2)}${row.ratio > 1 + 1e-9 ? ' (above)' : ''}' : '∞',
                  '${engN(row.velocity, 2)}${row.velocity > vmax + 1e-9 ? ' (fast)' : ''}',
                  row.rule.name,
                ],
            ],
            max: a.integer('pipes_limit', min: 1, max: 500) ?? 40,
          ),
          'U(Pq) ${engN(cl.u, 3)}; Clément source flow ${engQ(source)} against the design peak ${engQ(peak)}${source > peak + 1e-9 ? ' (ABOVE: the mainline was sized for less)' : ''}.',
          for (final e in need.entries) 'Supply ${name(e.key)}: needs ${engN(e.value, 1)} m, has ${engN(pressure[e.key] ?? 0, 1)} m${e.value > (pressure[e.key] ?? 0) + 0.01 ? ' (SHORT)' : ''}.',
          if (check != null)
            'Random check: ${check.configurations} configurations, ${engN((1 - check.satisfiedShare) * 100, 1)} % leave a hydrant short; mean open ${engN(check.meanOpen, 1)} hydrants (${engQ(check.meanDischarge)}); unsatisfied mean / p90 / max ${engN(check.meanUnsatisfied * 100, 1)} / ${engN(check.p90Unsatisfied * 100, 1)} / ${engN(check.maxUnsatisfied * 100, 1)} %.',
        ];
        return ToolOutput(out.join('\n') + engCodes(b, [...cl.codes, ...?check?.codes], name: name));
      },
    ),
    // ---------------------------------------------------------------- tariff
    engOp(
      b,
      name: 'tariff_schedule',
      effect: ToolEffect.read,
      effectFor: _applyEffect,
      description: 'Design → Tariff schedule: a time-of-use energy tariff (price bands of the day, demand charges, an irrigation discount in a window of the day such as the Brazilian rural irrigation tariff, or a custom one) and the daily schedule of the system flows that costs least under it (start times and discount blocks), compared with their start hours as they are. Needs design results. Without apply it only computes; apply true sets the start hours of the system flows (one undo step; the results are kept). Inputs: base_price_per_kwh (default the energy price of the parameters), demand_charge_per_kw, peak_demand_charge_per_kw (per kW per month, default 0), bands [{from_h, to_h, price_per_kwh, peak}] (default one peak band 18–21 h at 2.5 × the base price), discount none|brazil|custom (default brazil for BRL projects, else none), brazil_group a|b, brazil_region northeastSudene|northCentreWestMinas|others, custom_discount_pct 0–100 (60), custom_window_h 0–24 (8.5), custom_max_blocks 1–48 (3), excluded_from_h / excluded_to_h (17 / 21.5: no discount then), step_min 5–60 (15), max_hours_per_day 0–24 (0 = no limit), motor_efficiency 0.05–1 (1), keep_order (keep the order of the flows; default false), apply. Output: the schedule table, discount blocks, costs per day and month, the saving against the current start hours, and whether the schedule is optimal (exact) or heuristic.',
      schema: obj({
        'base_price_per_kwh': num_('Energy price outside the bands (currency/kWh).'),
        'demand_charge_per_kw': num_('Demand charge per kW per month.'),
        'peak_demand_charge_per_kw': num_('Demand charge per kW drawn in peak bands, per month.'),
        'bands': arr(
          obj(
            {'from_h': num_('0–24'), 'to_h': num_('0–24'), 'price_per_kwh': num_('Energy price in the band, currency/kWh.'), 'peak': bool_('A peak band (for the peak demand charge).')},
            required: ['from_h', 'to_h', 'price_per_kwh'],
          ),
          'Price bands of the day.',
          24,
        ),
        'discount': str('Irrigation discount.', ['none', 'brazil', 'custom']),
        'brazil_group': str('Consumer group of the Brazilian discount (default b).', [for (final g in BrazilConsumerGroup.values) g.name]),
        'brazil_region': str('Region of the Brazilian discount (default others).', [for (final g in BrazilDiscountRegion.values) g.name]),
        'custom_discount_pct': num_('Custom discount, 0–100 %; default 60.'),
        'custom_window_h': num_('Hours a day with the discount, 0–24; default 8.5.'),
        'custom_max_blocks': int_('Discount blocks a day, 1–48; default 3.'),
        'excluded_from_h': num_('Start of the hours without discount; default 17.'),
        'excluded_to_h': num_('End of the hours without discount; default 21.5.'),
        'step_min': int_('Schedule step, 5–60 min; default 15.'),
        'max_hours_per_day': num_('Pumping hours allowed per day, 0–24; 0 = no limit.'),
        'motor_efficiency': num_('Motor efficiency, 0.05–1; default 1.'),
        'keep_order': bool_('Keep the order of the system flows (default false).'),
        'apply': bool_('Set the start hours of the system flows to the schedule (one undo step).'),
      }),
      summary: (i) => t(i['apply'] == true ? 'ai.op.tariff_schedule.apply' : 'ai.op.tariff_schedule'),
      run: (a, i) async {
        engNeedResults(c);
        final r = c.results!;
        final p = b.p;
        final base = a.number('base_price_per_kwh', min: 0, max: 100) ?? p.params.powerCostPerKwh;
        final bands = <TariffBand>[];
        if (i['bands'] is List) {
          final raw = i['bands'] as List;
          for (var k = 0; k < raw.length; k++) {
            final x = ToolArgs(Map<String, dynamic>.from(raw[k] as Map));
            bands.add(
              TariffBand(
                startMinute: (x.number('from_h', min: 0, max: 24, required: true)! * 60).round(),
                endMinute: (x.number('to_h', min: 0, max: 24, required: true)! * 60).round(),
                pricePerKwh: x.number('price_per_kwh', min: 0, max: 100, required: true)!,
                peak: x.flag('peak') ?? false,
              ),
            );
          }
        } else {
          bands.add(TariffBand(startMinute: 18 * 60, endMinute: 21 * 60, pricePerKwh: base * 2.5, peak: true));
        }
        final kind = a.str('discount') ?? (p.params.currencyCode == 'BRL' ? 'brazil' : 'none');
        final IrrigationDiscount? disc = switch (kind) {
          'brazil' => IrrigationDiscount.brazil(BrazilConsumerGroup.values.byName(a.str('brazil_group') ?? 'b'), BrazilDiscountRegion.values.byName(a.str('brazil_region') ?? 'others')),
          'custom' => IrrigationDiscount(
            fraction: (a.number('custom_discount_pct', min: 0, max: 100) ?? 60) / 100,
            windowMinutes: ((a.number('custom_window_h', min: 0, max: 24) ?? 8.5) * 60).round(),
            maxBlocks: a.integer('custom_max_blocks', min: 1, max: 48) ?? 3,
            excluded: [(((a.number('excluded_from_h', min: 0, max: 24) ?? 17) * 60).round(), ((a.number('excluded_to_h', min: 0, max: 24) ?? 21.5) * 60).round())],
          ),
          _ => null,
        };
        final season = TariffSeason(
          id: 'day',
          basePricePerKwh: base,
          demandChargePerKw: a.number('demand_charge_per_kw', min: 0, max: 1e5) ?? 0,
          peakDemandChargePerKw: a.number('peak_demand_charge_per_kw', min: 0, max: 1e5) ?? 0,
          discount: disc,
          bands: bands,
        );
        final jobs = tariffJobsFromDesign(p, r, motorEfficiency: a.number('motor_efficiency', min: 0.05, max: 1) ?? 1);
        final s = await engSoon(
          () => scheduleJobs(
            jobs,
            season,
            options: ScheduleOptions(
              stepMinutes: a.integer('step_min', min: 5, max: 60) ?? 15,
              maxHoursPerDay: a.number('max_hours_per_day', min: 0, max: 24) ?? 0,
              keepOrder: a.flag('keep_order') ?? false,
            ),
          ),
        );
        final names = {for (final x in r.systemFlows) x.flowId: x.name, for (final x in p.systemFlows) x.id: x.name};
        final cur = p.params.currency;
        String money(double v) => '$cur ${engN(v, 2)}';
        final out = <String>[
          engTable(
            ['flow', 'start', 'end', 'hours', 'kW', 'kWh', 'h in discount', 'cost', 'cost without discount'],
            [
              for (final j in s.jobs)
                [
                  names[j.id] ?? j.id,
                  clockOf(j.startMinute),
                  clockOf(j.endMinute),
                  engN(j.minutes / 60, 2),
                  engN(j.powerKw, 2),
                  engN(j.energyKwh, 1),
                  engN(j.windowMinutes / 60, 2),
                  engN(j.cost, 2),
                  engN(j.costWithoutDiscount, 2),
                ],
            ],
          ),
          'Discount blocks: ${s.blocks.isEmpty ? '-' : s.blocks.map((x) => '${clockOf(x.startMinute)}–${clockOf(x.endMinute)}').join(', ')}',
          'Energy ${money(s.energyCost)} (${engN(s.energyKwh, 1)} kWh)${disc != null ? '; without the discount ${money(s.energyCostWithoutDiscount)} (saving ${money(s.discountSaving)})' : ''}${s.demandCost > 0 ? '; demand ${money(s.demandCost)}' : ''}; per day ${money(s.dailyCost)}, per month ${money(s.dailyCost * season.daysPerMonth)}.',
          if (s.baselineCost != null) 'With the start hours as they are: ${money(s.baselineCost!)} per day (saving ${money(s.baselineCost! - s.dailyCost)}).',
          s.exact ? 'The schedule is optimal for the model (every order solved).' : 'The schedule is a heuristic (too many flows to try every order).',
        ];
        final applicable = s.jobs.any((j) => p.systemFlows.any((x) => x.id == j.id));
        if (a.flag('apply') ?? false) {
          if (!applicable) throw ToolInputError('The schedule has no system flow of the project to apply (set_system_flows first).');
          final n = b.change('tariff_schedule', () => applyTariffSchedule(b.p, s), invalidate: false);
          out.add('Applied: start hours of $n system flows set.');
        } else if (!applicable) {
          out.add('The design runs every zone at once (no system flows): set_system_flows first to schedule them.');
        }
        return ToolOutput(out.join('\n') + engCodes(b, s.violations, name: (id) => names[id] ?? id));
      },
    ),
    // ---------------------------------------------------------------- energy grouping
    engOp(
      b,
      name: 'energy_grouping_study',
      effect: ToolEffect.read,
      effectFor: _applyEffect,
      description: 'Design → Energy grouping, with every option: system flows (groups of zones opened together) that need the least pumping energy — zones of similar required head together, within the flow the pump delivers, the groups and the hours allowed — against the system flows as they are. Needs design results. apply true replaces the system flows with the proposal (one undo step; results discarded). run_analysis "energy_grouping" / apply_energy_grouping are the short default versions. Inputs: max_flow_m3h (default the supplies\' design flow, else the largest flow of the design), max_groups (0 = no limit), max_hours 0–168 (default 24), max_zones_per_group (0 = no limit), pump_efficiency 0.05–1 (default the parameter), exact (heads from the network model; false = a quicker formula; default true), apply. Output: the groups (zones, flow, head, hours, energy, cost), the energy now, of one zone at a time and proposed, the saving.',
      schema: obj({
        'max_flow_m3h': num_('Largest flow of a group, m³/h.'),
        'max_groups': int_('Most groups, 0–999; 0 = no limit.'),
        'max_hours': num_('Hours a round of the groups may take, 0–168; default 24.'),
        'max_zones_per_group': int_('Most zones in a group, 0–999; 0 = no limit.'),
        'pump_efficiency': num_('0.05–1; default the design parameter.'),
        'exact': bool_('Group heads from the network model (default true).'),
        'apply': bool_('Replace the system flows with the proposal.'),
      }),
      summary: (i) => t(i['apply'] == true ? 'ai.op.energy_grouping_study.apply' : 'ai.op.energy_grouping_study'),
      run: (a, _) async {
        engNeedResults(c);
        final r = c.results!;
        final p = b.p;
        final d = opsDesigner(p, r, label: t.call);
        final (zones, source) = energyZonesWithPivots(d, r);
        if (zones.isEmpty) throw ToolInputError('No zone with a design result to group.');
        final maxFlow = a.has('max_flow_m3h')
            ? a.number('max_flow_m3h', min: 0.001, max: 1e6)! * m3sPerM3h
            : math.max(suppliesDesignFlow(p), [for (final f in r.systemFlows) f.totalFlow, for (final z in zones) z.flow].fold(0.0, math.max)) * (1 + 1e-9);
        final exact = a.flag('exact') ?? true;
        final eff = a.number('pump_efficiency', min: 0.05, max: 1) ?? p.params.pumpEfficiency;
        double head(List<EnergyZone> g) => exact ? designerGroupHead(d, g.map((z) => z.id)) : formulaGroupHead(g, source);
        final g = await engSoon(
          () => groupZonesForEnergy(
            zones,
            options: GroupingOptions(
              maxFlow: maxFlow,
              maxGroups: a.integer('max_groups', min: 0, max: 999) ?? 0,
              maxHours: a.number('max_hours', min: 0, max: 168) ?? 24,
              maxZonesPerGroup: a.integer('max_zones_per_group', min: 0, max: 999) ?? 0,
              sourceElevation: source,
              pumpEfficiency: eff,
            ),
            groupHead: exact ? head : null,
          ),
        );
        final now = groupingEnergyKwh([for (final f in d.effectiveSystemFlows()) f.valveIds], zones, head, efficiency: eff);
        final name = engNamer(b, d);
        final price = p.params.powerCostPerKwh, cur = p.params.currency;
        final out = <String>[
          engTable(
            ['group', 'zones', 'flow m³/h', 'head m', 'hours', 'kWh', 'cost $cur'],
            [
              for (var k = 0; k < g.groups.length; k++)
                [
                  '${k + 1}',
                  g.groups[k].zoneIds.map(name).join(' + '),
                  engN(g.groups[k].flow * 3600, 2),
                  engN(g.groups[k].head, 1),
                  engN(g.groups[k].hours, 2),
                  engN(g.groups[k].energyKwh, 1),
                  engN(g.groups[k].energyKwh * price, 2),
                ],
            ],
          ),
          'Energy per round: now ${engN(now, 1)} kWh ($cur ${engN(now * price, 2)}); one zone at a time ${engN(g.baselineEnergyKwh, 1)} kWh; proposed ${engN(g.energyKwh, 1)} kWh ($cur ${engN(g.energyKwh * price, 2)}) in ${engN(g.hours, 1)} h${now > 0 ? '; saving ${engN(now - g.energyKwh, 1)} kWh (${engN((now - g.energyKwh) / now * 100, 1)} %)' : ''}.',
        ];
        if (a.flag('apply') ?? false) {
          if (g.groups.isEmpty) throw ToolInputError('No grouping to apply.');
          final start = p.systemFlows.isEmpty ? 6.0 : p.systemFlows.map((f) => f.startHour).reduce(math.min);
          final n = b.change('energy_grouping_study', () {
            final next = systemFlowsFromGroups(b.p, g.groups, firstStartHour: start, label: t.call);
            b.p.systemFlows
              ..clear()
              ..addAll(next);
            return next.length;
          });
          out.add('Applied: $n system flows set. Results discarded: run the design again.');
        }
        return ToolOutput(out.join('\n') + engCodes(b, g.codes, name: name));
      },
    ),
    // ---------------------------------------------------------------- wire routing
    engOp(
      b,
      name: 'wire_routing_study',
      effect: ToolEffect.read,
      effectFor: _applyEffect,
      description: 'Zone → Wire routes, with every option: routes along the pipe trenches from every controller to its zone valves, master valves and pump-start relays (stations allocated by distance), and the sizing of a two-wire (decoder) system on those routes: cable, decoders, current, the worst voltage, the reach of each wire size, the grounds. Needs controllers (create_entities type "controller") and pipes. apply true draws the routes as wire entities (replacing the wires drawn unless replace false; one undo step); the valve wiring of the design then follows them. route_wires is the short default version. Inputs: mode shortestPaths|steiner (default shortestPaths), zone_pipes (also route along zone pipes; default true), master_stations, relay_stations (stations for master valves and pump relays; default true), max_stub_m 0–500 (default 30), replace (default true), apply; two-wire: volts 1–100 (34), min_volts 1–100 (24), idle_ma 0–100 (1 mA per decoder), solenoid_reach_m 0–500 (30), ground_every_decoders 0–999 (12), ground_every_m 0–5000 (150). Output: per-controller summary, the station table, the two-wire paths and stations, the messages.',
      schema: obj({
        'mode': str(null, [for (final m in RoutingMode.values) m.name]),
        'zone_pipes': bool_('Also route along the zone pipes (default true).'),
        'master_stations': bool_('Stations for master valves (default true).'),
        'relay_stations': bool_('Stations for pump-start relays (default true).'),
        'max_stub_m': num_('Longest stub from a trench to an item, 0–500 m; default 30.'),
        'replace': bool_('Replace the wires drawn (default true).'),
        'apply': bool_('Draw the routes as wires (one undo step).'),
        'volts': num_('Two-wire output voltage; default 34.'),
        'min_volts': num_('Least voltage at a decoder; default 24.'),
        'idle_ma': num_('Idle current per decoder, mA; default 1.'),
        'solenoid_reach_m': num_('Longest cable from a decoder to its solenoid, m; default 30.'),
        'ground_every_decoders': int_('A ground every this many decoders; default 12.'),
        'ground_every_m': num_('A ground every this many metres; default 150.'),
      }),
      summary: (i) => t(i['apply'] == true ? 'ai.op.wire_routing_study.apply' : 'ai.op.wire_routing_study'),
      // drawing them replaces the wires drawn: confirmed whatever the mode
      confirm: (i) => i['apply'] == true && (i['replace'] ?? true) == true && b.p.entities.any((e) => e is WireEntity),
      run: (a, _) async {
        final p = b.p;
        if (!p.entities.any((e) => e is ControllerEntity)) throw ToolInputError('The drawing has no controller: add one (create_entities type "controller") near the valves first.');
        final r = await engSoon(
          () => routeProjectWires(
            p,
            options: WireRoutingOptions(
              mode: RoutingMode.values.byName(a.str('mode') ?? 'shortestPaths'),
              includeZonePipes: a.flag('zone_pipes') ?? true,
              masterValveStations: a.flag('master_stations') ?? true,
              pumpRelayStations: a.flag('relay_stations') ?? true,
              maxStubM: a.number('max_stub_m', min: 0, max: 500) ?? 30,
              tolerance: math.max(p.params.connectTolerance, 0.1),
            ),
          ),
        );
        final name = engNamer(b);
        final minVolts = a.number('min_volts', min: 1, max: 100) ?? 24;
        final tw = r.routes.isEmpty
            ? null
            : designTwoWire(
                p,
                flows: wiringFlows(p),
                routes: [for (final w in r.routes) w.points],
                spec: TwoWireSpec(
                  outputVolts: a.number('volts', min: 1, max: 100) ?? 34,
                  minVolts: minVolts,
                  decoderIdleA: (a.number('idle_ma', min: 0, max: 100) ?? 1) / 1000,
                  maxSolenoidCableM: a.number('solenoid_reach_m', min: 0, max: 500) ?? 30,
                  groundEveryDecoders: a.integer('ground_every_decoders', min: 0, max: 999) ?? 12,
                  groundEveryM: a.number('ground_every_m', min: 0, max: 5000) ?? 150,
                ),
              );
        String wire(String? id) => id == null ? '-' : (p.catalog.wire(id)?.name ?? id);
        final out = <String>[
          for (final ctl in p.entities.whereType<ControllerEntity>())
            'Controller ${name(ctl.id)}: ${r.stations.where((s) => s.controllerId == ctl.id && s.station > 0).length} of ${ctl.stations} stations used, routes ${engN(r.routeLengthOf(ctl.id), 0)} m.',
          if (r.stations.isNotEmpty)
            engTable(
              ['controller', 'station', 'kind', 'item', 'route m'],
              [
                for (final s in r.stations) [name(s.controllerId), s.station == 0 ? 'dedicated' : '${s.station}', s.kind.name, name(s.entityId), engN(s.routeM, 0)],
              ],
            ),
        ];
        if (tw != null) {
          for (final path in tw.paths.where((x) => x.used > 0)) {
            final by = <int, int>{};
            for (final d in tw.decoders.where((d) => d.controllerId == path.controllerId)) {
              by[d.capacity] = (by[d.capacity] ?? 0) + 1;
            }
            out.add(
              'Two-wire ${name(path.controllerId)}: wire ${wire(path.wireId)}, route ${engN(path.routeM, 0)} m / cable ${engN(path.cableM, 0)} m, decoders ${by.isEmpty ? '0' : (by.keys.toList()..sort()).map((k) => '${by[k]} × $k').join(' · ')}, most open together ${path.maxOpen}, peak ${engN(path.peakCurrentA, 2)} A, worst ${engN(path.worstVolts, 1)} V${path.worstVolts < minVolts - 1e-9 ? ' (BELOW the minimum)' : ''}, reach ${path.maxDistanceM.isFinite ? '${engN(path.maxDistanceM, 0)} m' : '∞'}${path.sizes.isEmpty ? '' : '; sizes: ${path.sizes.map((s) => '${wire(s.wireId)} ${engN(s.worstVolts, 1)} V${s.ok ? '' : ' (too low)'}').join(', ')}'}.',
            );
          }
          if (tw.stations.isNotEmpty) {
            out.add(
              engTable(
                ['station', 'zone', 'decoder', 'route m', 'solenoid cable m', 'V'],
                [
                  for (final s in tw.stations)
                    ['${s.station}', s.zoneName.isNotEmpty ? s.zoneName : name(s.valveId), s.decoderId, engN(s.routeM, 0), engN(s.solenoidCableM, 0), '${engN(s.volts, 1)}${s.ok ? '' : ' (low)'}'],
                ],
              ),
            );
          }
          out.add('Grounds: ${tw.grounds.length}.');
        }
        if (a.flag('apply') ?? false) {
          if (r.routes.isEmpty) throw ToolInputError('No route to draw.${engCodes(b, r.warnings, name: name)}');
          final replace = a.flag('replace') ?? true;
          final n = b.change('wire_routing_study', () {
            if (replace) b.p.entities.removeWhere((e) => e is WireEntity);
            final wires = wireEntitiesOf(b.p, r);
            b.p.entities.addAll(wires);
            return wires.length;
          });
          out.add('Applied: $n wire routes drawn${replace ? ' (the wires drawn before were replaced)' : ''}, ${engN(r.totalRouteM, 0)} m in all.');
        } else if (r.routes.isEmpty) {
          out.add('No route.');
        }
        return ToolOutput(out.join('\n') + engCodes(b, [...r.warnings, ...?tw?.warnings], name: name));
      },
    ),
    // ---------------------------------------------------------------- criticality
    engOp(
      b,
      name: 'criticality_study',
      description: 'Mainline → Criticality, with its options: the mainline of one system flow with every pipe out of service in turn — the pipes whose loss cuts zones off or leaves them short of pressure, from the worst, with the demand lost and, pressure-driven, the share still delivered. Needs design results; changes nothing. run_analysis "criticality" is the short default version. Inputs: flow (system flow id or name; default the largest), pressure_driven (default true; false = demand-driven), limit 1–200 rows (default 20). Output: the total demand, the rows (pipe, demand lost m³/h and %, zones cut off, zones short with their deficit) and the messages.',
      schema: obj({'flow': flowArg, 'pressure_driven': bool_('Pressure-driven solution (default true).'), 'limit': int_('Rows, 1–200; default 20.')}),
      run: (a, _) async {
        engNeedResults(c);
        final r = c.results!;
        final d = opsDesigner(b.p, r, label: t.call);
        final sf = engFlowOf(d.effectiveSystemFlows(), r, a.str('flow'));
        final v = await engSoon(() => criticalityOf(d, r, sf, pressureDriven: a.flag('pressure_driven') ?? true));
        if (v == null) throw ToolInputError('The flow "${sf.name}" has no water supply on the mainline.');
        final name = engNamer(b, d);
        final total = v.result.totalDemand;
        // the segments of one pipe item fail alike: one row each, counted
        final rows = <(int, CriticalityRow, int)>[];
        for (final row in v.rows) {
          final last = rows.isEmpty ? null : rows.last;
          if (last != null &&
              last.$2.entityId == row.entityId &&
              (last.$2.scenario.lostDemand - row.scenario.lostDemand).abs() < 1e-12 &&
              last.$2.cutOff.join() == row.cutOff.join() &&
              last.$2.short.isEmpty &&
              row.short.isEmpty) {
            rows[rows.length - 1] = (last.$1, last.$2, last.$3 + 1);
          } else {
            rows.add((rows.length, row, 1));
          }
        }
        final out = <String>[
          'Flow ${sf.name}: total demand ${engQ(total)}.${v.result.tree ? ' The mainline is a tree: every pipe failure cuts the zones downstream off.' : ''}',
          if (v.result.baseDeficits.isNotEmpty) 'Already short with every pipe in service: ${{for (final x in v.result.baseDeficits) ...?v.demandsAt[x.nodeId]}.map(name).join(', ')}.',
          v.rows.isEmpty
              ? 'No single pipe failure leaves a demand short.'
              : engTable(
                  ['#', 'pipe', 'lost m³/h', 'lost %', 'cut off', 'short (deficit m, share delivered)'],
                  [
                    for (final (k, row, n) in rows)
                      [
                        '${k + 1}',
                        '${name(row.entityId)}${n > 1 ? ' ($n segments)' : ''}',
                        engN(row.scenario.lostDemand * 3600, 2),
                        total > 0 ? engN(100 * row.scenario.lostDemand / total, 1) : '-',
                        row.cutOff.map(name).join(', '),
                        row.short.map((e) => '${name(e.$1)} −${engN(e.$2.deficit, 1)} m (${engN(e.$2.demand > 0 ? 100 * e.$2.delivered / e.$2.demand : 100, 0)} %)').join('; '),
                      ],
                  ],
                  max: a.integer('limit', min: 1, max: 200) ?? 20,
                ),
        ];
        return ToolOutput(out.join('\n') + engCodes(b, v.result.codes, name: name));
      },
    ),
    // ---------------------------------------------------------------- calibration
    engOp(
      b,
      name: 'calibrate_roughness',
      effect: ToolEffect.read,
      effectFor: _applyEffect,
      description: 'Mainline → Calibration: fits the Hazen-Williams C scale of the design parameters to pressures read in the field at points of the mainline (valves, supplies, junctions, devices) and flows leaving the supplies while one system flow runs, with the residuals before and after. Needs design results. Call it without readings to list the measuring points with the model\'s pressure and supply flows. apply true sets hazenCScale (and hazenCOffset) of the parameters to the fitted values (one undo step; results discarded). Inputs: flow (system flow id or name; default the largest), pressures [{point (entity id or name), head_m (pressure head read, m), sigma_m (reading accuracy, 0.01–50; default 0.5)}], flows [{supply (id), flow_m3h, sigma_m3h (default 0: from the readings)}], apply. Output: the factor ± standard error, the C scale before → after, the objective, the pressure RMSE, the residual table and the messages.',
      schema: obj({
        'flow': flowArg,
        'pressures': arr(
          obj({'point': str('Measuring point (entity id or name).'), 'head_m': num_('Pressure head read, m.'), 'sigma_m': num_('Accuracy, 0.01–50 m.')}, required: ['point', 'head_m']),
          'Pressure readings.',
          100,
        ),
        'flows': arr(
          obj({'supply': str('Water supply id.'), 'flow_m3h': num_('Flow read, m³/h.'), 'sigma_m3h': num_('Accuracy, m³/h.')}, required: ['supply', 'flow_m3h']),
          'Flow readings at the supplies.',
          20,
        ),
        'apply': bool_('Set the fitted C scale in the parameters.'),
      }),
      summary: (i) => t(i['apply'] == true ? 'ai.op.calibrate_roughness.apply' : 'ai.op.calibrate_roughness'),
      run: (a, i) async {
        engNeedResults(c);
        final r = c.results!;
        final d = opsDesigner(b.p, r, label: t.call);
        final flows = d.effectiveSystemFlows();
        final points = measurePoints(d);
        if (flows.isEmpty || !points.any((m) => m.kind == MeasurePointKind.supply)) throw ToolInputError('Nothing to calibrate: the mainline needs a water supply and a system flow.');
        final sf = engFlowOf(flows, r, a.str('flow'));
        final name = engNamer(b, d);
        final rawP = (i['pressures'] as List?) ?? const [];
        final rawQ = (i['flows'] as List?) ?? const [];
        if (rawP.isEmpty && rawQ.isEmpty) {
          final model = _modelOf(d, sf, points);
          return ToolOutput(
            'Measuring points of the flow ${sf.name} (model values before the calibration; give readings to fit):\n${engTable(['point', 'kind', 'model head m', 'model flow m³/h'], [
              for (final m in points) [name(m.entityId).contains(m.entityId) ? name(m.entityId) : '${name(m.entityId)} (${m.entityId})', m.kind.name, engN(model.$1[m.entityId] ?? 0, 2), m.kind == MeasurePointKind.supply ? engN((model.$2[m.entityId] ?? 0) * 3600, 2) : ''],
            ])}',
          );
        }
        final byId = {for (final m in points) m.entityId: m};
        final pressures = <FieldReading>[];
        for (var k = 0; k < rawP.length; k++) {
          final x = ToolArgs(Map<String, dynamic>.from(rawP[k] as Map));
          final e = b.find(x.str('point', required: true)!);
          if (!byId.containsKey(e.id)) throw ToolInputError('pressures[$k]: "${x.str('point')}" is not a measuring point of the mainline (call without readings for the list).');
          pressures.add(FieldReading(entityId: e.id, value: x.number('head_m', min: -20, max: 1000, required: true)!, sigma: x.number('sigma_m', min: 0.01, max: 50) ?? 0.5));
        }
        final readings = <FieldReading>[];
        for (var k = 0; k < rawQ.length; k++) {
          final x = ToolArgs(Map<String, dynamic>.from(rawQ[k] as Map));
          final e = b.find(x.str('supply', required: true)!);
          if (byId[e.id]?.kind != MeasurePointKind.supply) throw ToolInputError('flows[$k]: "${x.str('supply')}" is not a water supply of the mainline.');
          readings.add(FieldReading(entityId: e.id, value: x.number('flow_m3h', min: -1e5, max: 1e5, required: true)! * m3sPerM3h, sigma: (x.number('sigma_m3h', min: 0, max: 1e5) ?? 0) * m3sPerM3h));
        }
        final res = await engSoon(() => calibrateFromField(d, sf, pressures: pressures, flows: readings));
        if (res == null) throw ToolInputError('The mainline of "${sf.name}" could not be built for the calibration.');
        final cr = res.result;
        final params = b.p.params;
        final (scale, offset) = cr.scales.isEmpty ? (params.hazenCScale, params.hazenCOffset) : calibratedC(params, cr.scales.single);
        String value(CalibrationResidual x, double v) => x.kind == MeasurementKind.pressure ? '${engN(v, 2)} m' : engQ(x.measured < 0 ? -v : v);
        final out = <String>[
          if (cr.scales.isNotEmpty) 'Factor ${engN(cr.scales.single, 3)}${cr.standardErrors.single.isFinite ? ' ± ${engN(cr.standardErrors.single, 3)}' : ''}.',
          'C scale ${engN(params.hazenCScale, 3)} → ${engN(scale, 3)}${params.hazenCOffset != 0 ? '; C offset ${engN(params.hazenCOffset, 1)} → ${engN(offset, 1)}' : ''}.',
          'Objective ${engN(cr.initialObjective, 2)} → ${engN(cr.objective, 2)}${cr.residuals.any((x) => x.kind == MeasurementKind.pressure) ? '; pressure RMSE ${engN(cr.rmsePressure, 2)} m' : ''}.',
          if (cr.residuals.isNotEmpty)
            engTable(
              ['point', 'measured', 'before', 'after', 'residual'],
              [
                for (final x in cr.residuals)
                  [name(res.entityOf[x.id] ?? x.id), value(x, x.measured), value(x, x.before), value(x, x.after), '${value(x, x.residual)}${(x.residual / x.sigma).abs() > 2 ? ' (large)' : ''}'],
              ],
            ),
          if (res.boundary.isNotEmpty) 'Boundary points (held, not fitted): ${res.boundary.map(name).join(', ')}.',
        ];
        if (a.flag('apply') ?? false) {
          final f = cr.scales.isEmpty ? double.nan : cr.scales.single;
          if (cr.residuals.isEmpty || !f.isFinite || f <= 0 || (f - 1).abs() <= 1e-6 || cr.codes.contains('calibration_not_hazen_williams')) {
            throw ToolInputError('Nothing to apply: the fit gives no usable factor (see the messages), or it is 1.${engCodes(b, cr.codes, name: name)}');
          }
          b.change('calibrate_roughness', () {
            b.p.params
              ..hazenCScale = scale
              ..hazenCOffset = offset;
            return 1;
          });
          out.add('Applied: hazenCScale ${engN(scale, 3)}${offset != 0 ? ', hazenCOffset ${engN(offset, 1)}' : ''}. Results discarded: run the design again.');
        }
        return ToolOutput(
          out.join('\n') +
              engCodes(b, [
                for (final x in cr.codes) x.startsWith('calibration_insensitive') || x.startsWith('calibration_at_bound') || x.startsWith('calibration_empty_group') ? x.split(':').first : x,
              ], name: name),
        );
      },
    ),
    // ---------------------------------------------------------------- fertigation
    engOp(
      b,
      name: 'fertigation_plan',
      description: 'Mainline → Fertigation: the product injected at a supply or pump during one system flow, its travel along the mainline to every valve and on to the farthest emitter of each zone (plug flow along the design flows), the injection plan (pre-wetting, injection and flushing times, product, stock solution, injection rate, concentration, dilution) and the check of a venturi injector on a bypass of a mainline device (or a typed differential). Needs design results; changes nothing. Inputs: flow (system flow id or name; default the first), injection (supply or pump id; default the first injection point), irrigation_hours 0.1–48 (default the flow duration), area_ha (default the area the flow irrigates), dose_kg_ha 0–10000 (50), nutrient_pct 0.1–100 (100), stock_kg_l 0–5 (0.25), tank_l 0–1e6 (0 = no tank), pre_wetting_pct 0–100 (25), flushing_pct 0–100 (25), flushing_margin 0–10 (1), venturi_device (id of a mainline device whose loss drives the venturi; default none: venturi_differential_m), venturi_differential_m 0–100 (5), venturi_min_differential_pct 0–100 (20), venturi_curve [[differential_m, suction_lph], …] (≥2 points; default none: suction not checked). Output: the travel table, the plan and the venturi check with the messages.',
      schema: obj({
        'flow': str('System flow id or name; default the first.'),
        'injection': str('Injection point: water supply or pump id.'),
        'irrigation_hours': num_('Irrigation time, 0.1–48 h.'),
        'area_ha': num_('Area fertilised, ha.'),
        'dose_kg_ha': num_('Dose of nutrient, kg/ha; default 50.'),
        'nutrient_pct': num_('Nutrient in the product, 0.1–100 %; default 100.'),
        'stock_kg_l': num_('Product per litre of stock solution, 0–5 kg/L; default 0.25.'),
        'tank_l': num_('Tank volume, L; 0 = none.'),
        'pre_wetting_pct': num_('Share of the time before the injection, %; default 25.'),
        'flushing_pct': num_('Share of the time for flushing, %; default 25.'),
        'flushing_margin': num_('Safety factor on the flushing time, 0–10; default 1.'),
        'venturi_device': str('Mainline device id across which the venturi bypass works.'),
        'venturi_differential_m': num_('Differential available to the venturi, 0–100 m; default 5.'),
        'venturi_min_differential_pct': num_('Least differential the venturi needs, % of its inlet pressure; default 20.'),
        'venturi_curve': arr(numbers('[differential_m, suction_lph]', n: 2), 'Suction curve of the venturi.', 20),
      }),
      run: (a, i) async {
        engNeedResults(c);
        final r = c.results!;
        final d = opsDesigner(b.p, r, label: t.call);
        final flows = d.effectiveSystemFlows();
        final points = injectionPoints(d);
        if (flows.isEmpty || points.isEmpty) throw ToolInputError('Fertigation needs a system flow and a water supply or pump on the mainline.');
        final fref = a.str('flow');
        final sf = fref == null ? flows.first : engFlowOf(flows, r, fref);
        final injection = a.has('injection') ? b.find(a.str('injection')!).id : points.first;
        if (!points.contains(injection)) throw ToolInputError('"${a.str('injection')}" is not an injection point. Points: ${points.join(', ')}.');
        final s = await engSoon(() => fertigationSetup(d, r, sf, injection));
        final name = engNamer(b, d);
        if (s == null) throw ToolInputError('The water from ${name(injection)} does not reach the zones of ${sf.name}.');
        final plan = planFertigation(
          FertigationInput(
            irrigationHours: a.number('irrigation_hours', min: 0.1, max: 48) ?? sf.durationHours,
            flow: s.flow,
            areaHa: a.number('area_ha', min: 0, max: 1e5) ?? s.areaM2 / 1e4,
            doseKgPerHa: a.number('dose_kg_ha', min: 0, max: 10000) ?? 50,
            nutrientFraction: (a.number('nutrient_pct', min: 0.1, max: 100) ?? 100) / 100,
            stockKgPerL: a.number('stock_kg_l', min: 0, max: 5) ?? 0.25,
            preWettingFraction: (a.number('pre_wetting_pct', min: 0, max: 100) ?? 25) / 100,
            flushingFraction: (a.number('flushing_pct', min: 0, max: 100) ?? 25) / 100,
            flushingMargin: a.number('flushing_margin', min: 0, max: 10) ?? 1,
            tankLitres: a.number('tank_l', min: 0, max: 1e6) ?? 0,
          ),
          s.combined,
        );
        final sites = venturiSites(s);
        VenturiSite? site;
        if (a.has('venturi_device')) {
          final e = b.find(a.str('venturi_device')!);
          site = sites.where((x) => x.entityId == e.id || x.linkId == e.id).firstOrNull;
          if (site == null) throw ToolInputError('"${a.str('venturi_device')}" is not a mainline device carrying water in this flow. Devices: ${sites.map((x) => x.entityId).join(', ')}.');
        }
        final curve = engPairs(i['venturi_curve'], 'venturi_curve', minItems: 2, maxItems: 20) ?? const [];
        final venturi = checkVenturi(
          VenturiSpec(
            curve: [
              for (final (dp, q) in curve)
                if (dp > 0 && q > 0) (dp, q / 3.6e6),
            ],
            minDifferentialFraction: (a.number('venturi_min_differential_pct', min: 0, max: 100) ?? 20) / 100,
          ),
          injectionRate: plan.injectionRate,
          inletPressure: site?.inletPressure ?? (s.result.nodes[s.injectionNode]?.pressure ?? 0),
          availableDifferential: site?.headLoss ?? (a.number('venturi_differential_m', min: 0, max: 100) ?? 5),
        );
        String mins(double sec) => engN(sec / 60, 1);
        final out = <String>[
          'Flow ${sf.name}, injection at ${name(injection)}: ${engQ(s.flow)}, mainline volume ${engN(s.mainline.volume, 2)} m³, the product reaches the farthest emitter in ${mins(s.farthestArrival)} min (everywhere in ${mins(s.fullArrival)} min).',
          engTable(
            ['zone', 'valve first min', 'valve full min', 'emitter first min', 'emitter full min'],
            [
              for (final z in s.zones)
                [name(z.demandId), mins(z.valveFirst), mins(z.valveFull), z.emitterFirst == null ? '-' : mins(z.emitterFirst!), z.emitterFull == null ? '-' : mins(z.emitterFull!)],
            ],
          ),
          'Plan: pre-wetting ${engHm(plan.preWetting / 3600)}, injection ${engHm(plan.injection / 3600)}${plan.injection > 0 ? '' : ' (NO TIME LEFT TO INJECT)'}, flushing ${engHm(plan.flushing / 3600)} (h:mm); product ${engN(plan.productKg, 1)} kg, stock solution ${engN(plan.stockLitres, 1)} L, injection rate ${engN(plan.injectionRate * 3.6e6, 1)} L/h, concentration ${engN(plan.concentration * 1000, 0)} g/m³${plan.dilution > 0 ? ', dilution 1:${engN(plan.dilution, 0)}' : ''}.',
          'Venturi${site == null ? ' (typed differential)' : ' across ${name(site.entityId)}'}: needs ${engN(venturi.requiredDifferential, 2)} m, has ${engN(venturi.availableDifferential, 2)} m${venturi.suctionCapacity.isFinite ? ', suction ${engN(venturi.suctionCapacity * 3.6e6, 1)} L/h' : ''} — ${venturi.ok ? 'OK' : 'NOT ENOUGH'}.',
        ];
        return ToolOutput(out.join('\n') + engCodes(b, [...s.mainline.codes, ...plan.codes, ...venturi.codes], name: name));
      },
    ),
    // ---------------------------------------------------------------- transients
    engOp(
      b,
      name: 'transient_study',
      description: 'Mainline → Transients, with every option: hydraulic transients (water hammer, method of characteristics) of the system flows for the scenarios chosen — the zone valves closing, a power failure tripping the pumps, an isolation valve closing — with the envelopes, the pipes against their pressure class and the vacuum risk. Works best with design results (steady state of the design). It changes nothing; air_valve_study can then use its minimum envelope. run_analysis "transients" is the short default version. Inputs: scenarios (valveClosure, pumpTrip, isolationClosure; default [valveClosure]), flow (system flow id or name; default every flow), closure_s 0–600 (default the design parameter), isolation (isolation valve id; default the first), isolation_closure_s 0–600 (default max(closure, 5)), motor_poles 2|4 (pump speed for the trip), inertia_kgm2 (0 = estimated), duration_s 0–600 (0 = automatic), column_separation (default true), air_valves (model the air valves drawn; default true), pipes_limit 1–500 (default 30). Output: one line per run (worst surge, highest and lowest pressure, check valves, time step), the pipe table (class, steady, max, min, status) and the messages.',
      schema: obj({
        'scenarios': arr(str(null, [for (final s in TransientScenario.values) s.name]), 'Scenarios to simulate.'),
        'flow': str('System flow id or name; default every flow.'),
        'closure_s': num_('Valve closure time, 0–600 s.'),
        'isolation': str('Isolation valve id (scenario isolationClosure).'),
        'isolation_closure_s': num_('Closure time of the isolation valve, 0–600 s.'),
        'motor_poles': int_('Pump motor poles, 2 or 4 (scenario pumpTrip).'),
        'inertia_kgm2': num_('Pump and motor inertia, 0–1000 kg·m²; 0 = estimated.'),
        'duration_s': num_('Simulated time, 0–600 s; 0 = automatic.'),
        'column_separation': bool_('Model vapour cavities (default true).'),
        'air_valves': bool_('Model the air valves drawn (default true).'),
        'pipes_limit': int_('Rows of the pipe table, 1–500; default 30.'),
      }),
      run: (a, _) async {
        engNotBusy(c);
        final p = b.p;
        final scenarios = {for (final s in a.strings('scenarios')) TransientScenario.values.byName(s)};
        if (scenarios.isEmpty) scenarios.add(TransientScenario.valveClosure);
        String? flowId;
        if (a.has('flow')) {
          final ref = a.str('flow')!, low = ref.toLowerCase();
          final f = p.systemFlows.where((x) => x.id == ref || x.name.toLowerCase() == low).firstOrNull;
          if (f == null) throw ToolInputError('No system flow "$ref". Flows: ${p.systemFlows.map((x) => '${x.id} (${x.name})').join(', ')}.');
          flowId = f.id;
        }
        final iso = isolationDevices(p);
        String? isoId;
        if (a.has('isolation')) {
          isoId = b.find(a.str('isolation')!).id;
          if (!iso.any((x) => x.id == isoId)) throw ToolInputError('"${a.str('isolation')}" is not an isolation valve of the mainline. Isolation valves: ${iso.map((x) => x.id).join(', ')}.');
        } else if (iso.isNotEmpty) {
          isoId = iso.first.id;
        }
        final poles = a.integer('motor_poles', min: 2, max: 4) ?? 2;
        if (poles != 2 && poles != 4) throw ToolInputError('"motor_poles" must be 2 or 4.');
        final closure = a.number('closure_s', min: 0, max: 600) ?? p.params.valveClosureTimeS;
        final inertia = a.number('inertia_kgm2', min: 0, max: 1000) ?? 0, duration = a.number('duration_s', min: 0, max: 600) ?? 0;
        final study = TransientStudy(
          p,
          results: c.results,
          label: t.call,
          options: TransientStudyOptions(
            scenarios: scenarios,
            flowIds: flowId == null ? null : {flowId},
            closureTime: closure,
            isolationId: isoId,
            isolationClosureTime: a.number('isolation_closure_s', min: 0, max: 600) ?? math.max(closure, 5),
            motorPoles: poles,
            inertia: inertia > 0 ? inertia : null,
            duration: duration > 0 ? duration : null,
            columnSeparation: a.flag('column_separation') ?? true,
            airValves: a.flag('air_valves') ?? true,
          ),
        );
        final runs = <TransientRun>[];
        for (final j in study.jobs) {
          runs.add(study.run(j));
          await Future<void>.delayed(Duration.zero);
          if (b.host?.stopped ?? false) throw ToolInputError('Stopped by the user after ${runs.length} of ${study.jobs.length} runs.');
        }
        final an = TransientStudy.combine(runs);
        _lastTransient[c] = (c.project, c.results, c.historyIndex, an);
        String nm(String? id) => engItemName(b, id);
        final out = <String>[
          if (c.results == null) 'No design results: the steady state is solved here; run_design first for the designed one.',
          if (an.runs.isEmpty) 'Nothing to simulate (no system flow on the mainline, or no pump/valve for the scenarios).',
          for (final r in an.runs)
            r.ran
                ? '${r.flowName} — ${r.scenario.name}${r.targetId == null ? '' : ' (${nm(r.targetId)})'}: worst surge ${engN(r.maxSurge, 1)} m${r.maxSurgeEntity == null ? '' : ' at ${nm(r.maxSurgeEntity)}'}; highest ${engN(r.maxPressure, 1)} m, lowest ${engN(r.minPressure, 1)} m; ${r.overRatingCount} pipes above their class, ${r.vacuumCount} with vacuum${r.checkValves.isEmpty ? '' : '; check valves close at ${r.checkValves.entries.map((e) => '${nm(e.key)} ${engN(e.value, 2)} s').join(', ')}'}; step ${engN(r.timeStep * 1000, 1)} ms over ${engN(r.duration, 0)} s.'
                : '${r.flowName} — ${r.scenario.name}: not run (${t.warning(r.skipped!, entityName: nm)}).',
          if (an.pipes.isNotEmpty)
            engTable(
              ['pipe', 'size', 'class m', 'steady max m', 'max m', 'min m', 'status'],
              [
                for (final e in [...an.pipes]..sort((x, y) => (y.overRating || y.vacuum ? 1 : 0).compareTo(x.overRating || x.vacuum ? 1 : 0)))
                  [
                    nm(e.entityId),
                    e.pipeName,
                    e.rating > 0 ? engN(e.rating, 0) : '-',
                    engN(e.steadyMaxPressure, 1),
                    engN(e.maxPressure, 1),
                    engN(e.minPressure, 1),
                    e.ok ? 'ok' : [if (e.overRating) 'ABOVE CLASS', if (e.vacuum) 'VACUUM' else if (e.belowAtmosphere) 'below atmosphere'].join(', '),
                  ],
              ],
              max: a.integer('pipes_limit', min: 1, max: 500) ?? 30,
            ),
        ];
        return ToolOutput(out.join('\n') + engCodes(b, an.messages.take(30), name: nm));
      },
    ),
    // ---------------------------------------------------------------- 24 hours
    engOp(
      b,
      name: 'eps_day',
      description: 'Mainline → 24-hour simulation, with its options: a day of operation — the system flows at their hours, the pumps on while a flow they serve runs — with the energy and cost per pump and per hour at an energy price with an optional peak band, and the lowest pressure at the running valves hour by hour. Better with design results; changes nothing. run_analysis "eps" is the short default version. Inputs: price_per_kwh (default the parameter), peak_start_hour / peak_end_hour 0–24 (18 / 21), peak_factor 0–20 (price multiplier in the peak band; default 1 = no peak). Output: the day\'s energy, cost and volume, the pump table, the hourly table (hours with flow) and the messages.',
      schema: obj({
        'price_per_kwh': num_('Energy price, currency/kWh.'),
        'peak_start_hour': num_('Start of the peak band, 0–24; default 18.'),
        'peak_end_hour': num_('End of the peak band, 0–24; default 21.'),
        'peak_factor': num_('Price multiplier in the peak band, 0–20; default 1.'),
      }),
      run: (a, _) async {
        engNotBusy(c);
        final p = b.p;
        final o = EpsDayOptions(
          pricePerKwh: a.number('price_per_kwh', min: 0, max: 100) ?? p.params.powerCostPerKwh,
          peakStartHour: a.number('peak_start_hour', min: 0, max: 24) ?? 18,
          peakEndHour: a.number('peak_end_hour', min: 0, max: 24) ?? 21,
          peakMultiplier: a.number('peak_factor', min: 0, max: 20) ?? 1,
        );
        final m = MainlineFlows(p, results: c.results, label: t.call);
        final d = await engSoon(() => simulateDayOn(m, options: o));
        final cur = p.params.currency;
        String flowName(String id) => m.flows.where((f) => f.id == id).firstOrNull?.name ?? engItemName(b, id);
        String hh(int h) => '${h.toString().padLeft(2, '0')}:00';
        final out = <String>[
          if (c.results == null) 'No design results: the pumps and valves as drawn; run_design first for the designed system.',
          'Day: ${engN(d.energyKwh, 1)} kWh, $cur ${engN(d.cost, 2)}, ${engN(d.volume, 0)} m³${d.converged ? '' : ' (some steps did not converge)'}.',
          // 1.6.0 MOT: the level of every reservoir through the day
          for (final e in d.levels.entries)
            if (e.value.isNotEmpty)
              'Reservoir of ${engItemName(b, e.key)}: ${engN(e.value.first, 2)} m at midnight, lowest ${engN(e.value.reduce(math.min), 2)} m, ${engN(e.value.last, 2)} m at the end of the day.',
          d.pumps.isEmpty
              ? 'No pump runs.'
              : engTable(
                  ['pump', 'kWh', cur, 'hours on', 'm³', 'peak kW'],
                  [
                    for (final x in d.pumps)
                      ['${x.calculated ? 'supply ' : ''}${engItemName(b, x.entityId)}', engN(x.energyKwh, 2), engN(x.cost, 2), engN(x.hoursOn, 2), engN(x.volume, 1), engN(x.maxPowerKw, 2)],
                  ],
                ),
          engTable(
            ['hour', 'flows', 'm³/h', 'kW', 'kWh', cur, 'lowest valve head m'],
            [
              for (final h in d.hours)
                if (h.flows.isNotEmpty || h.powerKw > 0)
                  [
                    '${hh(h.hour)}–${hh(h.hour + 1)}${o.peakMultiplier != 1 && o.inPeak(h.hour + 0.5) ? ' (peak)' : ''}',
                    h.flows.map(flowName).join(', '),
                    engN(h.flow * 3600, 2),
                    engN(h.powerKw, 2),
                    engN(h.energyKwh, 2),
                    engN(h.cost, 2),
                    h.lowestPressure.isFinite ? '${engN(h.lowestPressure, 1)} (${engNamer(b)(h.lowestValve ?? '')})${h.lowestMargin.isFinite && h.lowestMargin < -0.05 ? ' SHORT' : ''}' : '-',
                  ],
            ],
          ),
        ];
        return ToolOutput(out.join('\n') + engCodes(b, d.messages.take(30), name: (id) => id.contains(':') ? id : flowName(id)));
      },
    ),
    // ---------------------------------------------------------------- air valves
    engOp(
      b,
      name: 'air_valve_study',
      effect: ToolEffect.read,
      effectFor: _applyEffect,
      description: 'Mainline → Air valves, with every option (AWWA M51): the places the mainline needs air valves (high points, long rises and falls, spacing, pumps, vacuum in the last transient_study when use_transient), their type and orifice sizes and the catalogue valve that fits; insert true draws the missing ones on the pipes (one undo step). suggest_air_valves / insert_air_valves are the short default versions. Inputs: max_spacing_m 50–5000 (default 800; the least spacing is half of it), combination (prefer combination valves; default true), use_transient (use the vacuum of the last transient_study of this project state; default true when there is one), insert. Output: the suggestion table (pipe, chainage, type, reasons, large/small orifice and nominal size mm, catalogue valve, existing or missing) and the messages.',
      schema: obj({
        'max_spacing_m': num_('Longest stretch without an air valve, 50–5000 m; default 800.'),
        'combination': bool_('Prefer combination valves (default true).'),
        'use_transient': bool_('Use the vacuum of the last transient_study.'),
        'insert': bool_('Draw the missing catalogue valves (one undo step).'),
      }),
      summary: (i) => t(i['insert'] == true ? 'ai.op.air_valve_study.insert' : 'ai.op.air_valve_study'),
      run: (a, _) async {
        final max = a.number('max_spacing_m', min: 50, max: 5000) ?? 800;
        final tr = _transientOf(b);
        final use = (a.flag('use_transient') ?? true) && tr != null;
        final m = MainlineFlows(b.p, results: c.results, label: t.call);
        final st = await engSoon(
          () => suggestMainlineAirValvesOn(
            m,
            transient: use ? tr : null,
            options: AirValveOptions(maxSpacing: max, minSpacing: max / 2, preferCombination: a.flag('combination') ?? true, barometricHead: atmosphericHead(m.siteElevation)),
          ),
        );
        String mm(double x) => x > 0 ? engN(x * 1000, 0) : '-';
        final out = <String>[
          '${st.suggestions.length} places, ${st.missing.length} without a valve${st.usedTransient ? ' (transient vacuum used)' : (a.flag('use_transient') == true && tr == null ? ' (no transient_study of this project state to use)' : '')}.',
          if (st.suggestions.isNotEmpty)
            engTable(
              ['#', 'pipe', 'chainage m', 'position', 'type', 'reasons', 'large mm', 'small mm', 'size mm', 'catalogue valve', 'status'],
              [
                for (var k = 0; k < st.suggestions.length; k++)
                  () {
                    final v = st.suggestions[k];
                    return [
                      '${k + 1}',
                      engItemName(b, v.pipeEntityId),
                      engN(v.chainage, 0),
                      AgentToolbox.pt(v.position),
                      v.type.name,
                      v.reasons.map((x) => x.code).join('/'),
                      mm(v.sizing.largeOrifice),
                      mm(v.sizing.smallOrifice),
                      mm(v.sizing.nominalSize),
                      v.specId == null ? 'none in the catalogue' : (b.p.catalog.valve(v.specId)?.name ?? v.specId!),
                      v.existing ? 'existing (${engItemName(b, v.existingId)})' : 'MISSING',
                    ];
                  }(),
              ],
            ),
        ];
        if (a.flag('insert') ?? false) {
          final missing = [
            for (final v in st.missing)
              if (v.specId != null) v,
          ];
          if (missing.isEmpty) {
            out.add('Nothing to insert (no missing valve with a catalogue item).');
          } else {
            final n = b.change('air_valve_study', () {
              final list = airValveEntities(missing, b.p.newId);
              b.p.entities.addAll(list);
              return list.length;
            });
            out.add('Inserted $n air valves. Results discarded: run the design again.');
          }
        }
        return ToolOutput(out.join('\n') + engCodes(b, st.messages, name: (id) => engItemName(b, id)));
      },
    ),
    // ---------------------------------------------------------------- densogram
    engOp(
      b,
      name: 'densogram',
      description: 'Zone → Densogram, with its options: the water the sprinklers apply over a grid (mm/h), its uniformity — Christiansen CU, low-quarter DU, scheduling coefficient SC, dry share — over the irrigated areas (else the wetted cells), and per area. The options are kept for the user\'s densogram dialog and map; show true also shows the map on the drawing (a view change, not part of the project). It changes nothing in the project. run_analysis "uniformity" gives the figures with the current options. Inputs: profile triangular|elliptical|uniform (radial profile of the nozzles without a measured one), cell_m 0–20 (0 = automatic), use_measured (nozzle profiles measured in the catalogue; default true), wind_mps 0–15 (default 0), wind_bearing_deg (compass bearing the wind blows towards: 0 = north, 90 = east), use_results (pressures of the design; default true when there are results), zones (valve ids or zone names; empty = every zone), show. Output: the statistics and the areas.',
      schema: obj({
        'profile': str(null, [for (final x in SprayProfile.values) x.name]),
        'cell_m': num_('Grid cell, 0–20 m; 0 = automatic.'),
        'use_measured': bool_('Use measured nozzle profiles.'),
        'wind_mps': num_('Wind speed, 0–15 m/s.'),
        'wind_bearing_deg': num_('Compass bearing the wind blows towards (0 north, 90 east).'),
        'use_results': bool_('Use the design pressures.'),
        'zones': arr(str(), 'Zones to include (valve ids or zone names); empty = all.'),
        'show': bool_('Show the map on the drawing.'),
      }),
      run: (a, i) async {
        final o = c.densogramOptions;
        if (a.has('profile')) o.profile = SprayProfile.values.byName(a.str('profile')!);
        o.cellSize = a.number('cell_m', min: 0, max: 20) ?? o.cellSize;
        o.useMeasured = a.flag('use_measured') ?? o.useMeasured;
        o.windSpeed = a.number('wind_mps', min: 0, max: 15) ?? o.windSpeed;
        if (a.has('wind_bearing_deg')) o.windTowardsDeg = _mathOf(a.number('wind_bearing_deg', min: -360, max: 720)!);
        o.useResults = a.flag('use_results') ?? o.useResults;
        if (i.containsKey('zones')) {
          final ids = <String>{};
          for (final z in a.strings('zones')) {
            final e = b.find(z);
            if (e is! ControlValveEntity) throw ToolInputError('"$z" is not a zone valve.');
            ids.add(e.id);
          }
          o.valveIds = ids.isEmpty ? null : ids;
        }
        final d = await engSoon(() => (a.flag('show') ?? false) ? c.showDensogram() : c.densogram);
        if (a.flag('show') ?? false) c.refresh();
        if (d.isEmpty) return ToolOutput(t('dens.none'));
        final s = d.stats;
        return ToolOutput(
          [
            'Options: profile ${o.profile.name}, cell ${engN(d.cell, 2)} m${o.cellSize == 0 ? ' (automatic)' : ''}, measured profiles ${o.useMeasured}, wind ${engN(o.windSpeed, 1)} m/s towards ${engN(_compassOf(o.windTowardsDeg), 0)}°, ${d.fromResults ? 'design pressures' : 'nominal pressures'}, zones ${o.valveIds == null ? 'all' : o.valveIds!.map(c.entityName).join(', ')}.',
            '${d.sources.length} sprinklers over ${engN(s.areaM2, 0)} m² (${engN(s.areaM2 / 1e4, 3)} ha) of ${d.masked ? 'irrigated areas' : 'wetted cells'}.',
            'Mean ${engN(s.mean, 2)} mm/h (least ${engN(s.min, 2)}, most ${engN(s.max, 2)}); CU ${engN(s.cu, 1)} %, DU ${engN(s.du, 1)} %, SC ${s.sc.isFinite ? engN(s.sc, 2) : '∞'}, dry ${engN(s.dryPct, 1)} %.',
            if (d.areas.length > 1)
              'By area: ${[for (var k = 0; k < d.areas.length; k++) '${d.areas[k].name.isNotEmpty ? d.areas[k].name : 'area ${k + 1}'} ${engN(d.areas[k].stats.mean, 1)} mm/h, CU ${engN(d.areas[k].stats.cu, 0)} %, DU ${engN(d.areas[k].stats.du, 0)} %'].join('; ')}.',
            if (a.flag('show') ?? false) 'The map is shown on the drawing.',
          ].join('\n'),
        );
      },
    ),
    engOp(
      b,
      name: 'export_densogram_csv',
      effect: ToolEffect.export,
      description: 'Saves the densogram grid as a CSV file (x; y; mm/h; inside the target) with the options last set (densogram op or dialog), as the densogram dialog\'s "Export CSV". Always confirmed by the user (a download in the browser). No input. Output: the file name and the cell count.',
      schema: obj({}),
      run: (a, _) async {
        final d = await engSoon(() => c.densogram);
        if (d.isEmpty) throw ToolInputError(t('dens.none'));
        final file = '${b.p.meta.name}_densogram.csv';
        await engFileSink(c, file, 'text/csv', d.toCsv());
        return ToolOutput('Saved $file (${d.nx} × ${d.ny} cells of ${engN(d.cell, 2)} m).');
      },
    ),
  ];
}
