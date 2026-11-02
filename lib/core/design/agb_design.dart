/// The machines, electrical and water analyses of 1.6.0 run as a step of
/// the design (after the valve wiring): the pump house electrics and the
/// pivots' supply (`pump_house.dart`), solar pumping (`solar_design.dart`),
/// the water quality and treatment (`water_quality.dart`) and the two-wire
/// decoder wiring (`two_wire.dart`), kept in [DesignResults.agb] and put in
/// the bill of materials by [agbBomLines].
library;

import 'dart:math' as math;

import '../model/agb_settings.dart';
import '../model/entities.dart';
import '../model/project.dart';
import '../model/terrain.dart';
import '../units.dart';
import 'field_machines.dart';
import 'pump_house.dart';
import 'results.dart';
import 'solar_design.dart';
import 'two_wire.dart';
import 'water_quality.dart';

/// What the step worked out (each part null when it is off).
class AgbResults {
  AgbResults({this.pumpHouse, this.solar, this.water, this.twoWire, this.travellers = const [], this.furrows = const []});
  final PumpHouseResult? pumpHouse;
  final SolarDesign? solar;
  final WaterQualityResult? water;
  final TwoWireResult? twoWire;

  /// Travelling-gun lanes and furrow sets of the drawing.
  final List<TravellerLaneResult> travellers;
  final List<FurrowSetResult> furrows;

  bool get isEmpty => pumpHouse == null && solar == null && water == null && twoWire == null && travellers.isEmpty && furrows.isEmpty;

  /// Message codes of every part.
  List<String> get warnings => [
    ...?pumpHouse?.warnings,
    ...?solar?.warnings,
    ...?water?.warnings,
    ...?twoWire?.warnings,
    for (final t in travellers) ...t.result.warnings,
    for (final f in furrows) ...f.warnings,
  ];

  Map<String, dynamic> toJson() => {
    if (pumpHouse != null) 'ph': pumpHouse!.toJson(),
    if (solar != null) 'solar': solar!.toJson(),
    if (water != null) 'water': water!.toJson(),
    if (twoWire != null) 'tw': twoWire!.toJson(),
    if (travellers.isNotEmpty) 'trav': [for (final t in travellers) t.toJson()],
    if (furrows.isNotEmpty) 'furrows': [for (final f in furrows) f.toJson()],
  };

  static AgbResults fromJson(Map<String, dynamic> j) {
    Map<String, dynamic>? o(String k) => j[k] is Map ? (j[k] as Map).cast<String, dynamic>() : null;
    return AgbResults(
      pumpHouse: o('ph') == null ? null : PumpHouseResult.fromJson(o('ph')!),
      solar: o('solar') == null ? null : SolarDesign.fromJson(o('solar')!),
      water: o('water') == null ? null : WaterQualityResult.fromJson(o('water')!),
      twoWire: o('tw') == null ? null : TwoWireResult.fromJson(o('tw')!),
      travellers: [for (final t in (j['trav'] as List?) ?? const []) TravellerLaneResult.fromJson((t as Map).cast<String, dynamic>())],
      furrows: [for (final f in (j['furrows'] as List?) ?? const []) FurrowSetResult.fromJson((f as Map).cast<String, dynamic>())],
    );
  }
}

/// The two-wire spec of the settings.
TwoWireSpec twoWireSpecOf(TwoWireSettings s) => TwoWireSpec(
  outputVolts: s.outputVolts,
  minVolts: s.minVolts,
  decoderIdleA: s.decoderIdleMa / 1000,
  maxSolenoidCableM: s.solenoidReachM,
  groundEveryDecoders: s.groundEveryDecoders,
  groundEveryM: s.groundEveryM,
);

/// Whether the project wires its valves with decoders.
bool twoWireOn(Project p) => p.agb.twoWire.enabled;

/// The analyses of [p] on the design [r]; [flows] are the valve sets that
/// run together (the system flows with their valve-in-head stations).
/// Null when every part is off.
AgbResults? designAgb(Project p, DesignResults r, {List<Set<String>> flows = const [], Terrain? terrain}) {
  final s = p.agb;
  final hasPivotElectrics = r.mechanised.values.any((m) => m.electrical != null);
  final ph = s.pumpHouse.enabled || hasPivotElectrics ? designPumpHouse(p, r) : null;
  // a pump house switched off still reports the pivots' supply
  final pumpHouse = ph == null || s.pumpHouse.enabled
      ? ph
      : PumpHouseResult(
          voltage: ph.voltage,
          supply: ph.supply,
          circuits: const [],
          pivots: ph.pivots,
          runningKva: 0,
          demandKw: 0,
          installedKw: 0,
          largestStartKva: 0,
          sourceKvaRequired: 0,
          sourceKva: 0,
          ukPct: 0,
          ik3SourceKa: double.infinity,
          tariffGroup: ph.tariffGroup,
          warnings: [
            for (final w in ph.warnings)
              if (w.startsWith('agb_pivot_')) w,
          ],
        );
  final solar = designSolar(p, r);
  final water = designWaterQuality(p, r);
  final tw = s.twoWire.enabled ? designTwoWire(p, flows: flows, spec: twoWireSpecOf(s.twoWire)) : null;
  final lanes = [
    for (final e in p.entities.whereType<TravellerEntity>())
      if (!r.unconnected.contains(e.id)) analyzeTravellerLane(p, e, terrain: terrain)..availableHead = availableHeadOf(r, e.id),
  ];
  final furrows = [
    for (final e in p.entities.whereType<FurrowEntity>())
      if (!r.unconnected.contains(e.id)) analyzeFurrowSet(p, e, terrain: terrain)..availableHead = availableHeadOf(r, e.id),
  ];
  final out = AgbResults(pumpHouse: pumpHouse, solar: solar, water: water, twoWire: tw, travellers: lanes, furrows: furrows);
  return out.isEmpty ? null : out;
}

/// The energy cost of the design with the solar array (the grid cost when
/// solar pumping is off).
double agbEnergyCost(DesignResults r) => r.agb?.solar?.netCost ?? r.annualEnergyCost;

/// A bill-of-materials line: category, description, unit, quantity, unit
/// cost, catalogue id, code, supplier and where it is installed.
typedef AgbBomAdd = void Function(String cat, String desc, String unit, double qty, double cost, String? specId, {String code, String supplier, String zone});

String _n(double v, [int d = 0]) => fmt(v, d);

/// Puts the items of the analyses of [r] in the bill of materials through
/// [add], the descriptions in the words of [label].
void agbBomLines(Project p, DesignResults r, AgbBomAdd add, String Function(String key) label) {
  final a = r.agb;
  if (a == null) return;
  final cat = p.catalog;
  // ---- pump house: feeder cables, starter panels, transformer or generator
  final ph = a.pumpHouse;
  if (ph != null && p.agb.pumpHouse.enabled) {
    final ins = label(p.agb.pumpHouse.insulation == CableInsulation.pvc ? 'agb.ins.pvc' : 'agb.ins.xlpe');
    for (final c in ph.circuits) {
      // three phases and the protective conductor; a catalogue wire of the same section prices it
      final w = cat.wires.where((x) => x.enabled && (x.sectionMm2 - c.sectionMm2).abs() < 1e-6).firstOrNull;
      final phase = '${label('agb.bom.feeder')} ${_n(c.sectionMm2, c.sectionMm2 < 10 ? 1 : 0)} mm² $ins';
      add('bom.electrical', phase, 'm', 3 * c.lengthM, w?.costPerM ?? 0, w?.id, code: w?.code ?? '', supplier: w?.supplier ?? '', zone: 'elec');
      final pe = cat.wires.where((x) => x.enabled && (x.sectionMm2 - c.peMm2).abs() < 1e-6).firstOrNull;
      final peName = '${label('agb.bom.pe')} ${_n(c.peMm2, c.peMm2 < 10 ? 1 : 0)} mm²';
      add('bom.electrical', peName, 'm', c.lengthM, pe?.costPerM ?? 0, pe?.id, code: pe?.code ?? '', supplier: pe?.supplier ?? '', zone: 'elec');
      final panel = '${label('agb.bom.panel')} — ${label('agb.starter.${c.starter.name}')} ${_n(c.motorKw, c.motorKw < 10 ? 1 : 0)} kW';
      add('bom.electrical', panel, 'un', 1, p.agb.pumpHouse.panelCost, null, zone: 'elec');
    }
    if (ph.sourceKva > 0 && ph.circuits.isNotEmpty) {
      final key = ph.supply == PowerSupplyKind.generator ? 'agb.bom.generator' : 'agb.bom.transformer';
      add('bom.electrical', '${label(key)} ${_n(ph.sourceKva, ph.sourceKva < 100 ? 1 : 0)} kVA', 'un', 1, p.agb.pumpHouse.transformerCost, null, zone: 'elec');
    }
  }
  // ---- pivots: collector ring, end tower box
  for (final s in ph?.pivots ?? const <PivotSupply>[]) {
    final pivot = p.byId(s.pivotId);
    final name = pivot is PivotEntity && pivot.name.isNotEmpty ? pivot.name : label('tool.pivot');
    add('bom.pivots', '$name — ${label('agb.bom.ring')} ≥ ${_n(s.collectorRingA)} A', 'un', 1, 0, null, zone: s.pivotId);
    add('bom.pivots', '$name — ${label('agb.bom.endTower')}${s.boosterKw > 0 ? ' (${label('mech.booster')} ${_n(s.boosterKw, 1)} kW)' : ''}', 'un', 1, 0, null, zone: s.pivotId);
  }
  // ---- solar array
  final sol = a.solar;
  if (sol != null && sol.modules > 0) {
    final st = p.agb.solar;
    add('bom.solar', '${label('agb.bom.module')} ${_n(sol.moduleWp)} Wp', 'un', sol.modules.toDouble(), st.modulePrice, null);
    add('bom.solar', label('agb.bom.structure'), 'un', sol.modules.toDouble(), st.structurePricePerModule, null);
    final inv = math.max(0.5, (sol.inverterKw * 2).ceil() / 2);
    add('bom.solar', '${label(sol.mode == SolarMode.offGrid ? 'agb.bom.pumpDrive' : 'agb.bom.inverter')} ${_n(inv, 1)} kW', 'un', 1, st.inverterPricePerKw * inv, null);
  }
  // ---- filtration and chemical treatment (the filters only when none is drawn)
  final w = a.water;
  if (w != null) {
    final ws = p.agb.water;
    if (w.drawnFilters == 0) {
      if (w.media && w.mediaTanks > 0) add('bom.water', '${label('agb.bom.media')} Ø ${_n(w.tankDiameterM * 1000)} mm', 'un', w.mediaTanks.toDouble(), ws.filterCost, null);
      final spec = cat.valve(w.safetyFilterId);
      if (spec != null && w.safetyFilters > 0) {
        add('bom.water', spec.name, 'un', w.safetyFilters.toDouble(), spec.cost, spec.id, code: spec.code, supplier: spec.supplier);
      }
    }
    if (w.chlorination == ChlorinationMode.continuous || w.chlorination == ChlorinationMode.intermittent) {
      add('bom.water', '${label('agb.bom.injector')} — ${label('agb.water.chlorine')}', 'un', 1, ws.injectorCost, null);
    }
    if (w.acidMeqL > 0) add('bom.water', '${label('agb.bom.injector')} — ${label('agb.acid.${ws.acid.name}')}', 'un', 1, ws.injectorCost, null);
  }
  // ---- travelling guns: one machine per reel label, one hydrant per position
  final lanes = [for (final l in a.travellers) ?p.byId(l.laneId)].whereType<TravellerEntity>().toList();
  final machines = <String, TravellerEntity>{};
  final hydrants = <String, double>{};
  for (final e in lanes) {
    machines.putIfAbsent(e.machine, () => e);
    hydrants.putIfAbsent('${(e.start.x * 2).round()},${(e.start.y * 2).round()}', () => e.hydrantCost);
  }
  for (final e in machines.values) {
    final hose = e.hoseLengthM > 0 ? e.hoseLengthM : lanes.where((x) => x.machine == e.machine).fold(0.0, (m, x) => math.max(m, x.runLengthM));
    final gun = cat.outlet(e.gunSpecId);
    final desc = '${label('agb.bom.traveller')} ${e.machine} — ${label('agb.bom.hose')} Ø ${_n(e.hoseInnerMm)} mm × ${_n(hose)} m${gun == null ? '' : ' · ${gun.name}'}';
    add('bom.travellers', desc, 'un', 1, e.machineCost, null);
  }
  if (hydrants.isNotEmpty) add('bom.travellers', label('agb.bom.hydrant'), 'un', hydrants.length.toDouble(), hydrants.values.fold(0.0, (m, x) => math.max(m, x)), null);
  // ---- furrow sets: gated pipe and its gates (or siphons)
  for (final f in a.furrows) {
    final e = p.byId(f.setId);
    if (e is! FurrowEntity) continue;
    if (e.gatedPipe) {
      add('bom.surface', '${label('agb.bom.gatedPipe')} Ø ${_n(e.pipeInnerMm)} mm', 'm', e.length, e.pipeCostPerM, null);
      add('bom.surface', label('agb.bom.gate'), 'un', f.furrows.toDouble(), e.gateCost, null);
    } else {
      add('bom.surface', label('agb.bom.siphon'), 'un', f.perSet.toDouble(), e.gateCost, null);
    }
  }
  // ---- two-wire: the pair, decoders, surge protection, splices
  final tw = a.twoWire;
  if (tw != null) {
    final st = p.agb.twoWire;
    for (final e in tw.wireMeters.entries) {
      final spec = cat.wire(e.key);
      if (spec != null && e.value > 0) add('bom.electrical', '${label('agb.bom.pair')} — ${spec.name}', 'm', e.value, spec.costPerM, spec.id, code: spec.code, supplier: spec.supplier, zone: 'elec');
    }
    final byCap = <int, int>{};
    for (final d in tw.decoders) {
      byCap[d.capacity] = (byCap[d.capacity] ?? 0) + 1;
    }
    for (final k in (byCap.keys.toList()..sort())) {
      add('bom.electrical', '${label('agb.bom.decoder')} $k ${label('agb.bom.outputs')}', 'un', byCap[k]!.toDouble(), st.decoderPrices[k] ?? 0, null, zone: 'elec');
    }
    if (tw.grounds.isNotEmpty) add('bom.electrical', label('agb.bom.arrester'), 'un', tw.grounds.length.toDouble(), st.arresterPrice, null, zone: 'elec');
    final solenoid = tw.stations.fold(0.0, (s, x) => s + x.solenoidCableM);
    if (solenoid > 0) add('bom.electrical', label('agb.bom.solenoidCable'), 'm', 2 * solenoid, 0, null, zone: 'elec');
    final splices = 2 * tw.decoders.length + 2 * tw.stations.length;
    if (splices > 0) add('bom.electrical', label('elec.splice'), 'un', splices.toDouble(), 0, null, zone: 'elec');
  }
}
