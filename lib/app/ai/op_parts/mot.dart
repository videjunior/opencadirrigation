/// Operations (find_operations / run_operation) added in 1.6.0 for the hydraulic engine:
/// [OpTool]s built like those of lib/app/ai/ops_cad_*.dart and ops_eng_*.dart,
/// joined to [AgentToolbox.operations]. The reservoir and air vessel
/// operations are in mot_reservoir.dart, the ageing and clogging scenarios
/// in mot_scenarios.dart; here the pump stations (PRD-17) and the real
/// operation of the zones at the pressure the mainline gives them.
library;

import '../../../core/ai/agent_loop.dart';
import '../../../core/design/network_ops.dart' show opsDesigner;
import '../../../core/design/results.dart';
import '../../../core/model/entities.dart';
import '../agent_tools.dart';
import '../ops_eng_common.dart';
import 'mot_reservoir.dart';
import 'mot_scenarios.dart';

List<AgentTool> opsMot(AgentToolbox b) => [..._opsPlus(b), ...opsMotReservoir(b), ...opsMotScenarios(b)];

List<AgentTool> _opsPlus(AgentToolbox b) {
  final c = b.c;
  final flowArg = str('System flow id or name (get_report_table "mainline" lists them); default every flow.');
  String stationText(PumpEntity p) {
    final s = p.station;
    final lead = b.p.catalog.pump(p.pumpSpecId)?.name ?? p.pumpSpecId ?? '-';
    if (s == null || s.isEmpty) return '${engItemName(b, p.id)}: a single pump ($lead).';
    final units = [
      '1 $lead (lead, duty)',
      for (var i = 0; i < s.units.length; i++) '${i + 2} ${b.p.catalog.pump(s.units[i].specId ?? p.pumpSpecId)?.name ?? s.units[i].specId ?? lead} (${s.units[i].standby ? 'standby' : 'duty'})',
    ];
    return '${engItemName(b, p.id)}: ${s.dutyCount} duty + ${s.standbyCount} standby in ${s.arrangement.name}, ${s.staged ? 'staged by the flow' : 'all duty pumps always on'}: ${units.join('; ')}.';
  }

  return [
    // ---------------------------------------------------------------- pump stations
    engOp(
      b,
      name: 'set_pump_station',
      effect: ToolEffect.write,
      description: 'Pump item → Pump station…: makes a pump item stand for a pump station: its own pump (the lead, pump 1) and the pumps after it, joined in parallel (they share the flow at one head) or in series (they add their heads), each on duty or on standby. With staged true (default) the duty pumps start one after another, in their order, until the station gives the flow of each system flow within the range of every running pump and the pressure the valves need (with a calculated supply the range alone); false = every duty pump always runs. Standby pumps never run and go in the bill of materials. The design solves the station on the joined curve of its running pumps and reports every pump (get_report_table "stations"). Inputs: pump (id or name), units [{spec (catalogue pump id; default the lead\'s model), standby (default false)}] (replaces the list; [] = a single pump again), arrangement ("parallel" | "series"), staged. One undo step; results discarded.',
      schema: obj(
        {
          'pump': str('Pump item id or name.'),
          'units': arr(
            obj({'spec': str('Catalogue pump id (search_catalog kind "pump"); default the lead pump\'s model.'), 'standby': bool_('Kept on standby (default false).')}),
            'The pumps after the lead pump, in their starting order (at most 11).',
            11,
          ),
          'arrangement': str('How the duty pumps are joined (default: as now, else parallel).', ['parallel', 'series']),
          'staged': bool_('Start the duty pumps by the flow (default: as now, else true).'),
        },
        required: ['pump'],
      ),
      summary: (i) => b.t('ai.op.set_pump_station', {'n': '${i['pump'] ?? ''}'}),
      run: (a, i) async {
        engNotBusy(c);
        final e = b.find(a.str('pump', required: true)!);
        if (e is! PumpEntity) throw ToolInputError('${e.id} is not a pump item.');
        if (b.p.isLocked(e.layer)) throw ToolInputError('${e.id} is on the locked layer "${e.layer}".');
        final s = e.station?.copy() ?? PumpStation();
        final raw = i['units'];
        if (raw != null) {
          if (raw is! List || raw.length > 11) throw ToolInputError('"units" must be a list of at most 11 pumps.');
          final units = <PumpUnit>[];
          for (var k = 0; k < raw.length; k++) {
            final x = raw[k];
            if (x is! Map) throw ToolInputError('units[$k] must be an object {spec, standby}.');
            final spec = x['spec'];
            if (spec != null && (spec is! String || b.p.catalog.pump(spec) == null)) throw ToolInputError('units[$k]: no catalogue pump "$spec" (search_catalog kind "pump").');
            final sb = x['standby'];
            if (sb != null && sb is! bool) throw ToolInputError('units[$k].standby must be true or false.');
            units.add(PumpUnit(specId: spec as String?, standby: sb == true));
          }
          s.units
            ..clear()
            ..addAll(units);
        }
        final layout = a.str('arrangement');
        if (layout != null) s.arrangement = PumpArrangement.values.firstWhere((x) => x.name == layout, orElse: () => throw ToolInputError('"arrangement" must be parallel or series.'));
        s.staged = a.flag('staged') ?? s.staged;
        b.change('set_pump_station', () {
          e.station = s.isEmpty ? null : s;
          return 1;
        });
        return ToolOutput('${stationText(e)} Results discarded: run the design again.');
      },
    ),
    engOp(
      b,
      name: 'pump_stations',
      description: 'The pump stations of the project (pump items standing for several pumps, set_pump_station) with their pumps, and, after a design, the duty of every pump in each system flow: running or off by the staging or on standby, flow, head, efficiency from the wire to the water and electric power. Read-only. Input: pump (id or name; default every station).',
      schema: obj({'pump': str('Pump item id or name; default every station.')}),
      run: (a, _) async {
        final ref = a.str('pump');
        final pumps = ref == null ? b.p.entities.whereType<PumpEntity>().where((p) => !(p.station?.isEmpty ?? true)).toList() : [b.find(ref)];
        if (pumps.isEmpty) return const ToolOutput('No pump item stands for a station (set_pump_station makes one).');
        final out = <String>[];
        for (final e in pumps) {
          if (e is! PumpEntity) throw ToolInputError('${e.id} is not a pump item.');
          out.add(stationText(e));
          for (final f in c.results?.systemFlows ?? const <SystemFlowResult>[]) {
            for (final d in f.stations.where((d) => d.entityId == e.id)) {
              out.add(
                '${f.name}: ${d.running} of ${d.duty} duty pumps on, ${engQ(d.flow)} at ${engN(d.head, 1)} m, ${engN(d.powerKw, 2)} kW\n${engTable(['pump', 'model', 'state', 'm³/h', 'head m', 'efficiency %', 'kW'], [
                  for (final x in d.units) [x.index, x.name, x.standby ? 'standby' : (x.running ? 'on' : 'off'), engN(x.flow * 3600, 2), engN(x.head, 1), x.running ? engN(100 * x.efficiency, 0) : '-', x.running ? engN(x.powerKw, 2) : '-'],
                ])}',
              );
            }
          }
        }
        if (c.results == null) out.add('No design results: run_design gives the duty of every pump.');
        return ToolOutput(out.join('\n'));
      },
    ),
    // ---------------------------------------------------------------- real operation
    engOp(
      b,
      name: 'real_zone_operation',
      description: 'Mainline → real operation of the zones: every zone and pivot of a system flow run at the pressure the mainline really gives it (the supplies at the pressure of the design, the pump stations staged as there): the emitters deliver what that pressure allows, a valve that does not regulate passes a surplus on (more flow), a regulating one (PRV model, set outlet pressure or reducing pilot) holds its outlet, a sustaining pilot keeps the line before it, and the line and the pumps settle at the flows that follow. The design parameter realZoneOperation (set_parameters) makes every design report it (get_report_table "operation"); this computes it now from the results. Needs design results; changes nothing. Inputs: flow (id or name; default every flow). Output per zone: design and real flow, share delivered, pressure needed and available at the valve, lowest and highest emitter pressure, EU.',
      schema: obj({'flow': flowArg}),
      run: (a, _) async {
        engNeedResults(c);
        final r = c.results!;
        final d = opsDesigner(b.p, r, label: b.t.call);
        final flows = d.effectiveSystemFlows();
        final ref = a.str('flow');
        final picked = ref == null ? flows : [engFlowOf(flows, r, ref)];
        final out = <String>[];
        for (final sf in picked) {
          final f = r.systemFlows.where((x) => x.flowId == sf.id).firstOrNull;
          if (f == null) continue;
          final ops = await engSoon(() => d.realOperation(sf, f));
          if (ops.isEmpty) {
            out.add('${sf.name}: no zone or pivot with a water supply to run.');
            continue;
          }
          out.add(
            '${sf.name}:\n${engTable(['zone', 'design m³/h', 'real m³/h', 'delivered %', 'needs m', 'gets m', 'emitters min–max m', 'EU %', 'status'], [
              for (final o in ops) [o.zoneName, engN(o.designFlow * 3600, 2), engN(o.flow * 3600, 2), engN(100 * o.delivered, 0), engN(o.requiredHead, 1), engN(o.availableHead, 1), o.pivot ? '-' : '${engN(o.minPressure, 1)}–${engN(o.maxPressure, 1)}', o.pivot || o.eu <= 0 ? '-' : engN(o.eu, 0), o.short ? 'short of pressure' : (o.excess ? 'above the window (valve does not regulate)' : 'ok')],
            ])}',
          );
        }
        return ToolOutput(out.isEmpty ? 'No system flow to run.' : out.join('\n'));
      },
    ),
  ];
}
