/// Engineering operations of the mechanised machines (the machine dialog of
/// a centre pivot or linear move, opened from its properties): the
/// sprinkler package and nozzle chart, the drive train and timer, the
/// corner arm, the variable-rate prescription and the electrical supply —
/// read, changed (one undo step) and the prescription saved as a file.
library;

import '../../core/api.dart';
import '../widgets/dialogs/mechanised_dialogs.dart' show tyreRollingDiameterFromSize;
import 'agent_tools.dart';
import 'ops_eng_common.dart';

/// The sections of the machine report.
const machineSections = ['package', 'drive', 'arm', 'vri', 'electrical'];

PivotEntity _pivot(AgentToolbox b, String? ref) {
  if (ref != null) {
    final e = b.find(ref);
    if (e is! PivotEntity) throw ToolInputError('"$ref" is not a centre pivot or linear move.');
    return e;
  }
  final all = b.p.entities.whereType<PivotEntity>().toList();
  if (all.isEmpty) throw ToolInputError('The drawing has no centre pivot or linear move (fit_pivot or create_entities type "pivot").');
  if (all.length > 1) throw ToolInputError('The drawing has ${all.length} machines (${all.map((x) => '${x.id} ${b.nameOf(x)}').join(', ')}): give "pivot".');
  return all.single;
}

String _pivotName(AgentToolbox b, PivotEntity p) => p.name.isNotEmpty ? p.name : (p.zoneName.isNotEmpty ? p.zoneName : b.t(p.kind == PivotKind.pivot ? 'pivot.kindPivot' : 'pivot.kindLinear'));

MechanisedResult _analyse(AgentToolbox b, PivotEntity p) {
  final available = b.c.results?.pivots[p.id]?.availableHead ?? 0;
  final tr = b.terrain;
  return analyzeMechanised(b.p, p, terrain: tr.isEmpty ? null : tr, availableInletHeadM: available > 0 ? available : 0);
}

/// The machine report of [p] for the model.
String machineReport(AgentToolbox b, PivotEntity p, MechanisedResult r, {Set<String> sections = const {...machineSections}, int maxOutlets = 40}) {
  final m = p.machine;
  final pk = r.package;
  final cat = b.p.catalog;
  final pivot = p.kind == PivotKind.pivot;
  final out = <String>[
    '${_pivotName(b, p)} (${p.id}, ${p.kind.name}, ${pivot ? 'radius' : 'length'} ${engN(p.radiusM, 1)} m). Machine data (set_pivot_machine names): regulated ${m.regulated}, nozzle_height_m ${engN(m.nozzleHeightM)}, span_arch_m ${engN(m.spanArchM)}, drop_bore_mm ${engN(m.dropInnerMm, 1)}, nozzle_min/max ${m.minNozzleNumber}/${m.maxNozzleNumber}, end_gun ${m.endGun}${m.endGunSpecId == null ? '' : ' (${m.endGunSpecId})'}, end_gun_radius_m ${engN(m.endGunRadiusM, 1)}, booster ${m.endGunBooster}, motor_rpm ${engN(m.motorRpm, 0)}, gears ${engN(m.centerGearRatio, 1)}/${engN(m.wheelGearRatio, 1)}, tyre_diameter_m ${engN(m.tyreRollingDiameterM, 3)}, tower_speed_m_min ${engN(m.towerSpeedMPerMin, 2)}, timer_pct ${engN(m.timerPct, 0)} (min ${engN(m.minTimerPct, 0)}), corner arm ${engN(m.cornerArmLengthM, 1)} m${m.guidePathId == null ? '' : ' guide ${m.guidePathId}'}, vri step ${engN(m.vriStepDeg, 1)}° ${m.vriZones.isNotEmpty ? 'zones ${m.vriZones.length}' : (m.vriSectors.isNotEmpty ? 'sectors ${m.vriSectors.length}' : 'none')}, voltage ${engN(m.voltage, 0)} V.',
  ];
  if (sections.contains('package')) {
    final plugged = pk.outlets.length - pk.sprinklerCount;
    out.addAll([
      '## Package',
      'Sprinklers ${pk.sprinklerCount}${plugged > 0 ? ' ($plugged plugged)' : ''}; system flow ${engQ(pk.systemFlow)}, design ${engQ(pk.designFlow)}, delivered ${engQ(pk.deliveredFlow)}${pk.endGunFlow > 0 ? ', end gun ${engQ(pk.endGunFlow)}${pk.gunNozzle.isEmpty ? '' : ' nozzle ${pk.gunNozzle}'}${pk.gunRadiusM > 0 ? ' R ${engN(pk.gunRadiusM, 1)} m' : ''}' : ''}.',
      '${pivot ? 'Effective radius' : 'Effective length'} ${engN(pk.effectiveRadiusM, 1)} m; last tower ${engN(pk.lastTowerRadiusM, 1)} m. Inlet head required ${engN(pk.requiredInletHeadM, 1)} m${(b.c.results?.pivots[p.id]?.availableHead ?? 0) > 0 ? ', available ${engN(b.c.results!.pivots[p.id]!.availableHead!, 1)} m' : ''}; friction ${engN(pk.frictionLossM, 2)} m; end pressure ${engN(pk.endPressureM, 1)} m; regulator ${pk.regulatorM > 0 ? '${engN(pk.regulatorM, 1)} m${pk.regulatorId.isEmpty ? '' : ' (${cat.valve(pk.regulatorId)?.name ?? pk.regulatorId})'}' : 'none (unregulated)'}${pk.boosterHeadM > 0 ? '; booster ${engN(pk.boosterHeadM, 1)} m, ${engN(pk.boosterPowerKw, 2)} kW' : ''}.',
      if (pk.spans.isNotEmpty)
        engTable(
          ['span', 'from m', 'to m', 'sprinklers', 'required m³/h', 'delivered m³/h', 'pipe ID mm', 'p start m', 'p end m', 'friction m'],
          [
            for (final s in pk.spans)
              [
                s.overhang ? 'overhang' : '${s.index}',
                engN(s.startM, 1),
                engN(s.endM, 1),
                '${s.outlets}',
                engN(s.requiredFlow * 3600, 2),
                engN(s.deliveredFlow * 3600, 2),
                engN(s.pipeInnerMm, 0),
                engN(s.pressureStartM, 1),
                engN(s.pressureEndM, 1),
                engN(s.frictionLossM, 2),
              ],
          ],
        ),
      if (pk.outlets.isNotEmpty && maxOutlets > 0)
        'Nozzle chart (${pk.outlets.length} outlets${pk.outlets.length > maxOutlets ? ', first $maxOutlets' : ''}):\n${engTable(['outlet', 'span', 'distance m', 'spacing m', 'required L/h', 'delivered L/h', 'pipe p m', 'nozzle p m', 'regulator m', 'nozzle', 'drop m'], [
          for (final o in pk.outlets.take(maxOutlets)) ['${o.number}', '${o.span}', engN(o.distanceM, 1), o.plugged ? '-' : engN(o.spacingM, 2), o.plugged ? '-' : engN(o.requiredFlow * 3.6e6, 0), o.plugged ? '-' : engN(o.deliveredFlow * 3.6e6, 0), engN(o.pipePressureM, 1), o.plugged ? '-' : engN(o.nozzlePressureM, 1), o.regulatorM > 0 ? engN(o.regulatorM, 1) : '-', o.plugged ? 'plugged' : (o.nozzle.isNotEmpty ? o.nozzle : (o.nozzleNumber > 0 ? '#${o.nozzleNumber} (${engN(o.nozzleDiameterMm, 2)} mm)' : '-')), o.dropLengthM > 0 ? engN(o.dropLengthM, 2) : '-'],
        ], max: maxOutlets)}',
    ]);
  }
  if (sections.contains('drive')) {
    out.add('## Drive and timer');
    if (pk.speedAt100MPerMin <= 0) {
      out.add('No tower speed: give tower_speed_m_min, or motor_rpm with the gear ratios and the tyre.');
    } else {
      final setting = m.timerPct.clamp(1.0, 100.0).toDouble();
      out.addAll([
        'Speed at 100 %: ${engN(pk.speedAt100MPerMin, 2)} m/min; ${pivot ? 'revolution' : 'pass'} at 100 %: ${engN(pk.hoursAt100, 1)} h, ${engN(pk.depthAt100Mm, 1)} mm${setting < 100 ? '; at ${engN(setting, 0)} %: ${engN(pk.hoursAt100 * 100 / setting, 1)} h, ${engN(pk.depthAtTimer(setting), 1)} mm' : ''}${p.grossDepthMm > 0 ? '; timer for ${engN(p.grossDepthMm, 1)} mm: ${engN(pk.timerForDepth(p.grossDepthMm), 0)} %' : ''}.',
        if (pk.timer.isNotEmpty)
          engTable(
            ['timer %', 'hours', 'depth mm', 'speed m/min'],
            [
              for (final row in pk.timer) [engN(row.timerPct, 0), engN(row.hours, 1), engN(row.depthMm, 1), engN(row.speedMPerMin, 2)],
            ],
          ),
      ]);
    }
  }
  if (sections.contains('arm')) {
    out.add('## Corner arm');
    final a = r.cornerArm;
    if (!pivot) {
      out.add('Centre pivots only.');
    } else if (a == null) {
      out.add('None: give corner_arm_length_m and guide_path (a closed shape of the field edge).');
    } else {
      out.addAll([
        'Area ${engN(a.totalAreaM2 / 1e4, 2)} ha (arm ${engN(a.armAreaM2 / 1e4, 2)} ha, added ${engN(a.addedAreaM2 / 1e4, 2)} ha); flows main ${engQ(a.mainFlow)}, peak ${engQ(a.peakFlow)}, peak pulsed ${engQ(a.peakPulsedFlow)}, least ${engQ(a.minFlow)}; tip speed ratio ${engN(a.maxTipSpeedRatio, 2)}; shortfall ${engN(a.maxShortfallM, 2)} m, overrun ${engN(a.maxOverrunM, 2)} m.',
        engTable(
          ['bank', 'from m', 'to m', 'design m³/h', 'on %'],
          [
            for (final k in a.banks) ['${k.index + 1}', engN(k.startM, 1), engN(k.endM, 1), engN(k.designFlow * 3600, 2), engN(k.onFraction * 100, 0)],
          ],
        ),
      ]);
    }
  }
  if (sections.contains('vri')) {
    out.add('## Variable rate');
    final v = r.vri;
    if (!pivot) {
      out.add('Centre pivots only.');
    } else if (v == null) {
      out.add('No prescription: give vri_zones (closed areas → depth) or vri_sectors.');
    } else {
      out.addAll([
        'Depth at 100 %: ${engN(v.depthAt100Mm, 1)} mm; deepest ${engN(v.maxDepthMm, 1)} mm; ${v.bankEdgesM.length > 2 ? 'zone control, ${v.bankEdgesM.length - 1} banks' : 'speed control'}.',
        engTable(
          ['start °', 'end °', 'timer %', 'depth mm', 'target mm', if (v.bankEdgesM.length > 2) 'bank duty %'],
          [
            for (final row in v.rows)
              [
                engN(row.startDeg, 1),
                engN(row.endDeg, 1),
                engN(row.timerPct, 0),
                engN(row.depthMm, 1),
                engN(row.targetMm, 1),
                if (v.bankEdgesM.length > 2) row.bankDutyPct.map((d) => engN(d, 0)).join('/'),
              ],
          ],
          max: 120,
        ),
      ]);
    }
  }
  if (sections.contains('electrical')) {
    out.add('## Electrical');
    final e = r.electrical;
    if (e == null) {
      out.add('Off: give voltage (three-phase supply, V).');
    } else {
      out.addAll([
        'Span cable ${engN(e.cableMm2, 1)} mm²${m.supplyCableM > 0 ? ', supply cable ${engN(e.supplyCableMm2, 1)} mm² × ${engN(m.supplyCableM, 0)} m' : ''}; motor ${engN(e.motorCurrentA, 2)} A; connected ${engN(e.connectedKw, 2)} kW; running ${engN(e.runningCurrentA, 1)} A, ${engN(e.runningKva, 1)} kVA; drop running ${engN(e.maxRunningDropPct, 2)} %, starting ${engN(e.maxStartingDropPct, 2)} %${e.boosterMotorKw > 0 ? '; booster ${engN(e.boosterShaftKw, 2)} → ${engN(e.boosterMotorKw, 2)} kW, ${engN(e.boosterCurrentA, 1)} A' : ''}; largest starting ${engN(e.largestStartingKva, 1)} kVA; generator ${engN(e.generatorKva, 1)} kVA (needs ≥ ${engN(e.generatorKvaRequired, 1)}); average ${engN(e.averagePowerKw, 2)} kW.',
        engTable(
          ['tower', 'distance m', 'cable m', 'current A', 'volts', 'drop run %', 'drop start %'],
          [
            for (final tw in e.towers) ['${tw.index}', engN(tw.radiusM, 0), engN(tw.cableM, 0), engN(tw.spanCurrentA, 1), engN(tw.volts, 0), engN(tw.runningDropPct, 2), engN(tw.startingDropPct, 2)],
          ],
        ),
      ]);
    }
  }
  return out.join('\n') + engCodes(b, [for (final w in r.warnings) w.split(':').first], title: 'Machine messages');
}

List<AgentTool> machineOperations(AgentToolbox b) {
  final c = b.c;
  final t = b.t;
  return [
    engOp(
      b,
      name: 'pivot_machine',
      description: 'Reads the mechanised-machine data of a centre pivot or linear move (the machine dialog of its properties) and analyses them as the dialog does: the sprinkler package (flows, inlet head required against the head the design leaves, friction, end pressure, regulator, end gun and booster), the span table and the nozzle chart; the drive train, speed and timer chart; the corner arm (areas, flows, banks); the variable-rate prescription (sectors, timer, depths, bank duty); the electrical supply (cables, currents, voltage drops, generator). It changes nothing; set_pivot_machine changes the data. Inputs: pivot (id or name; default the only machine), sections (package, drive, arm, vri, electrical; default all), outlets_limit 1–400 rows of the nozzle chart (default 40). Run run_design first for the available inlet head. Output: the data line (with the set_pivot_machine names) and a block per section with tables.',
      schema: obj({
        'pivot': str('Id or name of the pivot or linear move.'),
        'sections': arr(str(null, machineSections), 'Sections to report (all when omitted).'),
        'outlets_limit': int_('Rows of the nozzle chart, 1–400; default 40.'),
      }),
      summary: (i) => t('ai.op.pivot_machine', {'n': '${i['pivot'] ?? ''}'}),
      run: (a, _) async {
        final p = _pivot(b, a.str('pivot'));
        final secs = a.strings('sections').toSet();
        final r = await engSoon(() => _analyse(b, p));
        return ToolOutput(machineReport(b, p, r, sections: secs.isEmpty ? {...machineSections} : secs, maxOutlets: a.integer('outlets_limit', min: 1, max: 400) ?? 40));
      },
    ),
    engOp(
      b,
      name: 'set_pivot_machine',
      effect: ToolEffect.write,
      description: 'Changes the mechanised-machine data of a centre pivot or linear move (the machine dialog), one undo step; the design results are discarded. Give only the fields to change (SI: m, mm, kW, V, degrees counter-clockwise from east). Package: regulated, nozzle_height_m (0 = on the pipe), span_arch_m, drop_bore_mm, nozzle_min / nozzle_max (numbered series 1–400, used without catalogue nozzles), end_gun auto|none|fullCircle|corners, end_gun_spec (gun id; "" clears), end_gun_radius_m (0 = from the gun), end_gun_booster. Drive: motor_rpm, center_gear_ratio, wheel_gear_ratio, tyre_diameter_m or tyre_size (sidewall size such as "11.2-38" or "320/85R38"), tower_speed_m_min (speed at 100 %, wins over the drive train), timer_pct 1–100, min_timer_pct 1–100. Corner arm (pivots): corner_arm_length_m (0 = none), corner_arm_overhang_m, corner_arm_max_deg 0–179, corner_arm_banks 1–30, guide_path (id of a closed shape along the field edge; "" clears), guide_offset_m, clockwise. Variable rate (pivots): vri_step_deg 0.5–90, vri_bank_edges_m (radii of the bank boundaries for zone control; [] = speed control), vri_zones ({closed shape id: target gross depth mm}; replaces the zones and drops the sectors), vri_sectors ([[start_deg, end_deg, depth_mm], …]; replaces the sectors and drops the zones). Electrical: voltage (three-phase V; 0 = off), tower_motor_kw, supply_cable_m, supply_cable_mm2 (0 = sized). Output: the new analysis summary (package and drive) and the messages; pivot_machine shows the rest.',
      schema: obj({
        'pivot': str('Id or name of the pivot or linear move.'),
        'regulated': bool_('Pressure-regulated package (default true).'),
        'nozzle_height_m': num_('0–10 m.'),
        'span_arch_m': num_('0–5 m.'),
        'drop_bore_mm': num_('5–60 mm.'),
        'nozzle_min': int_('1–400.'),
        'nozzle_max': int_('1–400.'),
        'end_gun': str(null, ['auto', 'none', 'fullCircle', 'corners']),
        'end_gun_spec': str('Gun id, or "" to clear.'),
        'end_gun_radius_m': num_('0–100 m.'),
        'end_gun_booster': bool_('Booster pump at the end gun.'),
        'motor_rpm': num_('0–5000.'),
        'center_gear_ratio': num_('0–500.'),
        'wheel_gear_ratio': num_('0–500.'),
        'tyre_diameter_m': num_('0–3 m.'),
        'tyre_size': str('Tyre sidewall size, e.g. "11.2-38", "14.9x24", "320/85R38".'),
        'tower_speed_m_min': num_('0–10 m/min.'),
        'timer_pct': num_('1–100 %.'),
        'min_timer_pct': num_('1–100 %.'),
        'corner_arm_length_m': num_('0–150 m.'),
        'corner_arm_overhang_m': num_('0–50 m.'),
        'corner_arm_max_deg': num_('0–179°.'),
        'corner_arm_banks': int_('1–30.'),
        'guide_path': str('Closed shape id, or "" to clear.'),
        'guide_offset_m': num_('−200…200 m (inwards positive).'),
        'clockwise': bool_('Direction of travel of the machine (default counter-clockwise).'),
        'vri_step_deg': num_('0.5–90°.'),
        'vri_bank_edges_m': numbers('Bank boundary radii (m).'),
        'vri_zones': {'type': 'object', 'description': 'Closed shape id → target gross depth (mm).'},
        'vri_sectors': arr(numbers('[start_deg, end_deg, depth_mm]', n: 3), 'Sectors of the prescription.', 72),
        'voltage': num_('0–1000 V.'),
        'tower_motor_kw': num_('0.1–10 kW.'),
        'supply_cable_m': num_('0–10000 m.'),
        'supply_cable_mm2': num_('0–500 mm².'),
      }),
      summary: (i) => t('ai.op.set_pivot_machine', {'n': '${i['pivot'] ?? ''}'}),
      run: (a, i) async {
        engNotBusy(c);
        final p = _pivot(b, a.str('pivot'));
        if (b.p.isLocked(p.layer)) throw ToolInputError('The layer "${p.layer}" of ${p.id} is locked.');
        final keys = [
          for (final k in i.keys)
            if (k != 'pivot') k,
        ];
        if (keys.isEmpty) throw ToolInputError('Give at least one field to change.');
        final m = p.machine.clone();
        final pivotOnly = {
          'corner_arm_length_m',
          'corner_arm_overhang_m',
          'corner_arm_max_deg',
          'corner_arm_banks',
          'guide_path',
          'guide_offset_m',
          'clockwise',
          'vri_step_deg',
          'vri_bank_edges_m',
          'vri_zones',
          'vri_sectors',
        };
        if (p.kind != PivotKind.pivot) {
          final bad = keys.where(pivotOnly.contains).toList();
          if (bad.isNotEmpty) throw ToolInputError('${bad.join(', ')}: centre pivots only (${p.id} is a linear move).');
        }
        double? n(String k, double min, double max) => a.number(k, min: min, max: max);
        m.regulated = a.flag('regulated') ?? m.regulated;
        m.nozzleHeightM = n('nozzle_height_m', 0, 10) ?? m.nozzleHeightM;
        m.spanArchM = n('span_arch_m', 0, 5) ?? m.spanArchM;
        m.dropInnerMm = n('drop_bore_mm', 5, 60) ?? m.dropInnerMm;
        m.minNozzleNumber = a.integer('nozzle_min', min: 1, max: 400) ?? m.minNozzleNumber;
        m.maxNozzleNumber = a.integer('nozzle_max', min: 1, max: 400) ?? m.maxNozzleNumber;
        if (m.minNozzleNumber > m.maxNozzleNumber) throw ToolInputError('nozzle_min must not exceed nozzle_max.');
        m.endGun = a.str('end_gun') ?? m.endGun;
        if (a.has('end_gun_spec')) {
          final g = a.str('end_gun_spec')!;
          if (g.isEmpty) {
            m.endGunSpecId = null;
          } else {
            final o = b.p.catalog.outlet(g);
            if (o == null || o.kind != OutletKind.gun) {
              throw ToolInputError('"$g" is not a gun of the catalogue. Guns: ${b.p.catalog.outlets.where((x) => x.kind == OutletKind.gun).map((x) => x.id).join(', ')}.');
            }
            m.endGunSpecId = g;
          }
        }
        m.endGunRadiusM = n('end_gun_radius_m', 0, 100) ?? m.endGunRadiusM;
        m.endGunBooster = a.flag('end_gun_booster') ?? m.endGunBooster;
        m.motorRpm = n('motor_rpm', 0, 5000) ?? m.motorRpm;
        m.centerGearRatio = n('center_gear_ratio', 0, 500) ?? m.centerGearRatio;
        m.wheelGearRatio = n('wheel_gear_ratio', 0, 500) ?? m.wheelGearRatio;
        m.tyreRollingDiameterM = n('tyre_diameter_m', 0, 3) ?? m.tyreRollingDiameterM;
        if (a.has('tyre_size')) {
          final d = tyreRollingDiameterFromSize(a.str('tyre_size')!);
          if (d == null) throw ToolInputError('"${a.str('tyre_size')}" is not a tyre size (e.g. "11.2-38", "14.9x24", "320/85R38").');
          m.tyreRollingDiameterM = d;
        }
        m.towerSpeedMPerMin = n('tower_speed_m_min', 0, 10) ?? m.towerSpeedMPerMin;
        m.timerPct = n('timer_pct', 1, 100) ?? m.timerPct;
        m.minTimerPct = n('min_timer_pct', 1, 100) ?? m.minTimerPct;
        m.cornerArmLengthM = n('corner_arm_length_m', 0, 150) ?? m.cornerArmLengthM;
        m.cornerArmOverhangM = n('corner_arm_overhang_m', 0, 50) ?? m.cornerArmOverhangM;
        m.cornerArmMaxDeg = n('corner_arm_max_deg', 0, 179) ?? m.cornerArmMaxDeg;
        m.cornerArmBanks = a.integer('corner_arm_banks', min: 1, max: 30) ?? m.cornerArmBanks;
        if (a.has('guide_path')) {
          final g = a.str('guide_path')!;
          if (g.isEmpty) {
            m.guidePathId = null;
          } else {
            final e = b.find(g);
            if (closedOutlineOf(b.p, e.id) == null) throw ToolInputError('"$g" is not a closed shape (use an area, a closed polyline or a circle along the field edge).');
            m.guidePathId = e.id;
          }
        }
        m.guideOffsetM = n('guide_offset_m', -200, 200) ?? m.guideOffsetM;
        m.clockwise = a.flag('clockwise') ?? m.clockwise;
        m.vriStepDeg = n('vri_step_deg', 0.5, 90) ?? m.vriStepDeg;
        final edges = engNumbers(i['vri_bank_edges_m'], 'vri_bank_edges_m', min: 0, max: 2000);
        if (edges != null) {
          m.vriBankEdgesM
            ..clear()
            ..addAll(
              [
                for (final x in edges)
                  if (x > 0) x,
              ]..sort(),
            );
        }
        if (i['vri_zones'] != null && i['vri_sectors'] != null) throw ToolInputError('Give vri_zones or vri_sectors, not both (the prescription comes from one of them).');
        if (i['vri_zones'] != null) {
          final z = i['vri_zones'];
          if (z is! Map) throw ToolInputError('"vri_zones" must be an object {shape id: depth mm}.');
          final next = <String, double>{};
          for (final e in z.entries) {
            final shape = b.find('${e.key}');
            if (closedOutlineOf(b.p, shape.id) == null) throw ToolInputError('vri_zones: "${e.key}" is not a closed shape.');
            final d = e.value;
            if (d is! num || d < 0 || d > 500) throw ToolInputError('vri_zones["${e.key}"] must be a depth 0–500 mm.');
            next[shape.id] = d.toDouble();
          }
          m.vriZones
            ..clear()
            ..addAll(next);
          m.vriSectors.clear();
        }
        if (i['vri_sectors'] != null) {
          final raw = i['vri_sectors'] as List;
          final next = <VriSectorDepth>[];
          for (var k = 0; k < raw.length; k++) {
            final v = engNumbers(raw[k], 'vri_sectors[$k]', length: 3)!;
            if (v[0] < 0 || v[0] > 360 || v[1] < 0 || v[1] > 360 || v[2] < 0 || v[2] > 500) throw ToolInputError('vri_sectors[$k]: angles 0–360°, depth 0–500 mm.');
            next.add(VriSectorDepth(v[0], v[1], v[2]));
          }
          m.vriSectors
            ..clear()
            ..addAll(next);
          m.vriZones.clear();
        }
        m.voltage = n('voltage', 0, 1000) ?? m.voltage;
        m.towerMotorKw = n('tower_motor_kw', 0.1, 10) ?? m.towerMotorKw;
        m.supplyCableM = n('supply_cable_m', 0, 10000) ?? m.supplyCableM;
        m.supplyCableMm2 = n('supply_cable_mm2', 0, 500) ?? m.supplyCableMm2;
        b.change('set_pivot_machine', () {
          final live = b.p.byId(p.id);
          if (live is PivotEntity) live.machine = m;
          return 1;
        });
        final live = b.p.byId(p.id) as PivotEntity;
        final r = await engSoon(() => _analyse(b, live));
        return ToolOutput(
          'Machine of ${_pivotName(b, live)} changed (${keys.join(', ')}). Results discarded: run_design again for the available head.\n${machineReport(b, live, r, sections: const {'package', 'drive'}, maxOutlets: 0)}',
        );
      },
    ),
    engOp(
      b,
      name: 'export_vri_prescription',
      effect: ToolEffect.export,
      description: 'Saves the variable-rate prescription of a centre pivot as a CSV file for the machine controller (the "save CSV" of the variable-rate tab): one row per sector with start and end angle, timer %, depth, target and the duty of every bank. Always confirmed by the user (a download in the browser). Inputs: pivot (id or name; default the only machine), compass (angles as bearings clockwise from north instead of counter-clockwise from east; default false). Needs a prescription (set_pivot_machine vri_zones or vri_sectors). Output: the file name and the row count.',
      schema: obj({'pivot': str('Id or name of the pivot.'), 'compass': bool_('Bearings clockwise from north (default false).')}),
      summary: (i) => t('ai.op.export_vri_prescription', {'n': '${i['pivot'] ?? ''}'}),
      run: (a, _) async {
        final p = _pivot(b, a.str('pivot'));
        final r = await engSoon(() => _analyse(b, p));
        final v = r.vri;
        if (v == null || v.rows.isEmpty) throw ToolInputError('${p.id} has no variable-rate prescription: set vri_zones or vri_sectors with set_pivot_machine first.');
        String safe(String s) => s.trim().replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');
        final file = '${safe(b.p.meta.name)}_${safe(_pivotName(b, p))}_vri.csv';
        await engFileSink(c, file, 'text/csv', v.toCsv(compass: a.flag('compass') ?? false));
        return ToolOutput('Saved $file (${v.rows.length} sectors).');
      },
    ),
  ];
}
