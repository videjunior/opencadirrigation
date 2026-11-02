import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/energy_grouping.dart';
import 'package:opencadirrigation/core/design/results.dart';
import 'package:opencadirrigation/core/hydraulics/uniformity.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/units.dart';

/// Energy (kWh) of pumping [volume] m³ to [head] m at [eff].
double _kwh(double head, double volume, [double eff = 0.65]) => waterDensity * gravity * head * volume / eff / 3.6e6;

ZoneResult _zone(String id, double q, double h, double z) => ZoneResult(
  valveId: id,
  zoneName: id,
  converged: true,
  totalFlow: q,
  downstreamHead: h,
  valveLoss: 0,
  requiredUpstreamHead: h,
  minOutletPressure: 0,
  maxOutletPressure: 0,
  allowedMin: 0,
  allowedMax: 0,
  nominalPressure: 0,
  uniformity: UniformityStats.empty,
  pipes: const [],
  outlets: const [],
  devices: const [],
  warnings: const [],
  valveElevation: z,
);

void main() {
  // high and low zones alternating in the drawing: first fit by flow pairs
  // them as they come
  const zones = [
    EnergyZone(id: 'H1', flow: 0.01, requiredHead: 50, hours: 2),
    EnergyZone(id: 'L1', flow: 0.01, requiredHead: 20, hours: 2),
    EnergyZone(id: 'H2', flow: 0.01, requiredHead: 50, hours: 2),
    EnergyZone(id: 'L2', flow: 0.01, requiredHead: 20, hours: 2),
  ];

  test('zones of similar head together: 30 % less energy than first fit by flow', () {
    final r = groupZonesForEnergy(zones, options: const GroupingOptions(maxFlow: 0.02));
    expect(
      [for (final g in r.baseline) g.zoneIds],
      [
        ['H1', 'L1'],
        ['H2', 'L2'],
      ],
    );
    expect(
      [for (final g in r.groups) g.zoneIds],
      [
        ['H1', 'H2'],
        ['L1', 'L2'],
      ],
    );
    const v = 0.02 * 2 * 3600;
    expect(r.baselineEnergyKwh, closeTo(2 * _kwh(50, v), 1e-9));
    expect(r.energyKwh, closeTo(_kwh(50, v) + _kwh(20, v), 1e-9));
    expect(r.savingShare, closeTo(0.3, 1e-9));
    expect(r.savingKwh, closeTo(_kwh(30, v), 1e-9));
    expect(r.groups.first.head, 50);
    expect(r.groups.first.flow, closeTo(0.02, 1e-15));
    expect(r.groups.first.hours, 2);
    expect(r.hours, 4);
    expect(r.codes, isEmpty);
    final back = EnergyGroupingResult.fromJson(jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>);
    expect(back.energyKwh, closeTo(r.energyKwh, 1e-12));
    expect(back.groups.first.zoneIds, ['H1', 'H2']);
  });

  test('limits: one group, the hours, a zone above the cap', () {
    final one = groupZonesForEnergy(zones, options: const GroupingOptions(maxGroups: 1));
    expect(one.groups.single.zoneIds, ['H1', 'L1', 'H2', 'L2']);
    expect(one.energyKwh, closeTo(_kwh(50, 0.04 * 2 * 3600), 1e-9));
    // only two groups fit in four hours
    final hours = groupZonesForEnergy(zones, options: const GroupingOptions(maxHours: 4));
    expect(hours.groups.length, 2);
    expect(hours.energyKwh, closeTo(_kwh(50, 0.02 * 7200) + _kwh(20, 0.02 * 7200), 1e-9));
    // without limits every zone alone uses as little, and the fewest groups
    // are kept on a tie
    final free = groupZonesForEnergy(zones);
    expect(free.groups.length, 2);
    expect(free.energyKwh, closeTo(_kwh(50, 0.01 * 7200) * 2 + _kwh(20, 0.01 * 7200) * 2, 1e-9));
    final over = groupZonesForEnergy([...zones, const EnergyZone(id: 'X', flow: 0.05, requiredHead: 30)], options: const GroupingOptions(maxFlow: 0.02));
    expect(over.codes, ['grouping_oversized:X']);
    expect(over.groups.where((g) => g.zoneIds.contains('X')).single.zoneIds, ['X']);
    final tight = groupZonesForEnergy(zones, options: const GroupingOptions(maxFlow: 0.02, maxGroups: 1));
    expect(tight.codes, contains('grouping_groups_exceeded'));
    expect(groupZonesForEnergy(zones, options: const GroupingOptions(maxZonesPerGroup: 1)).groups.length, 4);
  });

  test('the pump also covers the loss to the farthest valve of its group', () {
    // k·Q^m to each valve, with the elevation and the source level
    const zs = [EnergyZone(id: 'A', flow: 0.01, requiredHead: 25, elevation: 10, lossCoefficient: 2000), EnergyZone(id: 'B', flow: 0.01, requiredHead: 25, elevation: 0, lossCoefficient: 500)];
    final r = groupZonesForEnergy(zs, options: const GroupingOptions(maxGroups: 1, sourceElevation: -5));
    final head = math.max(10 + 25 + 2000 * math.pow(0.02, 1.852), 0 + 25 + 500 * math.pow(0.02, 1.852)) + 5;
    expect(r.groups.single.head, closeTo(head, 1e-9));
    // an exact head from the caller is used for the energies reported
    var calls = 0;
    final exact = groupZonesForEnergy(
      zs,
      options: const GroupingOptions(maxGroups: 1),
      groupHead: (g) {
        calls++;
        return 77;
      },
    );
    expect(exact.groups.single.head, 77);
    expect(calls, greaterThan(0));
  });

  test('the caller\'s heads refine the grouping, within a budget of calls', () {
    // the two high zones together lose much more than the formula says
    double head(List<EnergyZone> g) => g.where((z) => z.id.startsWith('H')).length == 2 ? 100 : g.map((z) => z.requiredHead).reduce(math.max);
    var calls = 0;
    final r = groupZonesForEnergy(
      zones,
      options: const GroupingOptions(maxFlow: 0.02),
      groupHead: (g) {
        calls++;
        return head(g);
      },
    );
    // free: the high zones apart
    expect(
      [for (final g in r.groups) g.zoneIds],
      [
        ['H1'],
        ['L1', 'L2'],
        ['H2'],
      ],
    );
    expect(r.energyKwh, closeTo(2 * _kwh(50, 72) + _kwh(20, 144), 1e-9));
    expect(calls, lessThan(30));
    // two groups: a high zone with a low one in each
    final two = groupZonesForEnergy(zones, options: const GroupingOptions(maxFlow: 0.02, maxGroups: 2), groupHead: head);
    expect(
      [for (final g in two.groups) g.zoneIds],
      [
        ['H1', 'L2'],
        ['L1', 'H2'],
      ],
    );
    expect(two.energyKwh, closeTo(2 * _kwh(50, 144), 1e-9));
    var few = 0;
    groupZonesForEnergy(
      zones,
      options: const GroupingOptions(maxFlow: 0.02, maxHeadCalls: 2),
      groupHead: (g) {
        few++;
        return head(g);
      },
    );
    // two for the search, the rest for the groups reported
    expect(few, lessThanOrEqualTo(2 + 4 + 2));
  });

  test('zones of a design and system flows for the groups', () {
    final p = Project();
    p.entities.addAll([ControlValveEntity(id: 'v1', position: Pt.zero, zoneName: 'North'), ControlValveEntity(id: 'v2', position: const Pt(10, 0), zoneName: 'South')]);
    p.systemFlows.add(SystemFlow(id: 'sf1', name: 'old', valveIds: {'v1', 'v2'}, durationHours: 3));
    final r = DesignResults(timestamp: DateTime(2026));
    r.zones['v1'] = _zone('v1', 0.01, 30, 12);
    r.zones['v2'] = _zone('v2', 0.02, 20, 2);
    r.systemFlows.add(
      SystemFlowResult(
        flowId: 'sf1',
        name: 'old',
        converged: true,
        totalFlow: 0.03,
        durationHours: 3,
        pipes: const [],
        devices: const [],
        warnings: const [],
        supplies: [SupplyDuty(supplyId: 's', name: 's', flow: 0.03, head: 50, requiredHead: 50, elevation: 0, calculated: true)],
        valves: [
          ValveDuty(valveId: 'v1', zoneName: 'North', flow: 0.01, availableHead: 30, requiredHead: 30, p: Pt.zero),
          ValveDuty(valveId: 'v2', zoneName: 'South', flow: 0.02, availableHead: 45, requiredHead: 20, p: Pt.zero),
        ],
      ),
    );
    final (zs, source) = energyZonesFromDesign(p, r);
    expect(source, 0);
    final z1 = zs.firstWhere((z) => z.id == 'v1');
    expect(z1.flow, 0.01);
    expect(z1.requiredHead, 30);
    expect(z1.elevation, 12);
    expect(z1.hours, 3);
    // loss to v1: 0 + 50 − (12 + 30) = 8 m at 30 L/s
    expect(z1.lossCoefficient, closeTo(8 / math.pow(0.03, 1.852), 1e-6));
    final z2 = zs.firstWhere((z) => z.id == 'v2');
    expect(z2.lossCoefficient, closeTo(3 / math.pow(0.03, 1.852), 1e-6));
    final groups = groupZonesForEnergy(zs, options: GroupingOptions(maxFlow: 0.02, sourceElevation: source)).groups;
    final flows = systemFlowsFromGroups(p, groups, firstStartHour: 22, label: (k) => k == 'name.flow' ? 'Flow' : k);
    expect(flows.length, 2);
    expect(flows[0].id, 'sf1_2');
    expect(flows[0].name, 'Flow 1 — North');
    expect(flows[0].startHour, 22);
    expect(flows[1].startHour, 1);
    expect(flows[1].valveIds, {'v2'});
  });
}
