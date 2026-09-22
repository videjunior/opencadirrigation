import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/core/design/agronomy.dart';
import 'package:opencadirrigation/core/design/design_check.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/units.dart';

/// Defects found by checking the example gallery (2026-09-22), each pinned
/// by a test that fails without its fix: heads on an area's outline, laterals
/// crossing it, the uniformity of matched-precipitation zones, flushing that
/// did not converge, stacked programme days and pivots left out of the water
/// table.
void main() {
  String t(String key, [Map<String, String>? args]) => key;

  group('heads on the outline of an area', () {
    final square = [const Pt(0, 0), const Pt(10, 0), const Pt(10, 10), const Pt(0, 10)];

    test('count when their arc opens into the area', () {
      // south edge, half circle swept counter-clockwise from east: north, inwards
      expect(watersArea(const Pt(5, 0), square, arcDeg: 180, orientationDeg: 0), isTrue);
      // the same head turned outwards
      expect(watersArea(const Pt(5, 0), square, arcDeg: 180, orientationDeg: 180), isFalse);
      // south-west corner, quarter circle into the square
      expect(watersArea(const Pt(0, 0), square, arcDeg: 90, orientationDeg: 0), isTrue);
      expect(watersArea(const Pt(0, 0), square, arcDeg: 90, orientationDeg: 180), isFalse);
      // a half circle at a corner whose bisector runs along the other side
      expect(watersArea(const Pt(0, 0), square, arcDeg: 180, orientationDeg: 0), isTrue);
      // a full circle on the outline, and points well inside or outside
      expect(watersArea(const Pt(10, 5), square), isTrue);
      expect(watersArea(const Pt(5, 5), square, arcDeg: 90, orientationDeg: 180), isTrue);
      expect(watersArea(const Pt(15, 5), square), isFalse);
      expect(pointOnPolygonBoundary(const Pt(10, 5), square), isTrue);
      expect(pointOnPolygonBoundary(const Pt(9, 5), square), isFalse);
    });

    test('the lawn whose heads all sit on its edges gets their whole flow', () {
      final p = buildExample(ExampleId.garden, t);
      final r = Designer(p, label: t).designAll();
      final back = p.entities.whereType<AreaEntity>().firstWhere((a) => a.name == 'ex.g.back');
      final zone = r.zones.values.firstWhere((z) => z.zoneName == 'ex.g.zone2');
      final req = areaRequirements(p, r).firstWhere((a) => a.areaId == back.id);
      // eight of its nine rotors are on the outline: only the middle one
      // counted before
      expect(req.flow, closeTo(zone.totalFlow, zone.totalFlow * 1e-6));
      expect(areasOfZone(p, r, zone.valveId).map((a) => a.id), contains(back.id));
    });

    test('a zone whose heads run along the edge of the pitch belongs to it', () {
      final p = buildExample(ExampleId.sportsField, t);
      final r = Designer(p, label: t).designAll();
      final pitch = p.entities.whereType<AreaEntity>().single;
      for (final z in r.zones.values) {
        expect(areasOfZone(p, r, z.valveId).map((a) => a.id), [pitch.id], reason: z.zoneName);
      }
      final total = r.zones.values.fold(0.0, (s, z) => s + z.totalFlow);
      expect(areaRequirements(p, r).single.flow, closeTo(total, total * 1e-6));
      expect(buildControllerProgram(p, r, startDate: DateTime(2026, 1, 1)).warnings, isEmpty);
    });

    test('a zone shared by two beds belongs to both', () {
      final p = buildExample(ExampleId.garden, t);
      final r = Designer(p, label: t).designAll();
      final drip = r.zones.values.firstWhere((z) => z.zoneName == 'ex.g.zone3');
      expect(areasOfZone(p, r, drip.valveId).map((a) => a.name).toSet(), {'ex.g.bed 1', 'ex.g.bed 2'});
    });
  });

  test('a bed crossed by driplines whose ends lie outside it is not reported empty', () {
    final p = buildExample(ExampleId.garden, t);
    expect(runDesignCheck(p).issues.where((i) => i.code == 'area_no_emitters'), isEmpty);
  });

  test('matched-precipitation nozzles do not lower the uniformity of their zone', () {
    // quarter, half and full circles of the same series deliver 1 : 2 : 4
    // flows by design; only pressure and manufacturing make them uneven
    final p = buildExample(ExampleId.garden, t);
    final r = Designer(p, label: t).designAll();
    for (final name in ['ex.g.zone1', 'ex.g.zone2']) {
      final z = r.zones.values.firstWhere((z) => z.zoneName == name);
      expect(z.actualVariationPct, lessThan(5), reason: name);
      expect(z.uniformity.cu, greaterThan(98), reason: name);
      expect(z.uniformity.eu, greaterThan(90), reason: name);
    }
  });

  test('flushing converges and finds the same valve pressure for identical blocks', () {
    // the open tape ends were emitters with exponent 0 on satellite links;
    // the solver never converged and the bisection ended at a meaningless
    // pressure on two of the three blocks
    final p = buildExample(ExampleId.coffee, t);
    final r = Designer(p, label: t).designAll();
    expect(r.flushing, hasLength(3));
    for (final f in r.flushing) {
      expect(f.converged, isTrue, reason: f.zoneName);
      expect(f.minEndHead, closeTo(p.params.flushingMinEndHeadM, 0.01), reason: f.zoneName);
      expect(f.maxVelocity, greaterThanOrEqualTo(p.params.flushingVelocity - 1e-6), reason: f.zoneName);
    }
    final heads = r.flushing.map((f) => f.requiredDownstreamHead).toList();
    expect(heads.last, closeTo(heads.first, 0.01));
  });

  test('flows that water every few days start on staggered days', () {
    // two shifts of about 22 hours every 11 days: both on the first day made
    // a 44-hour day
    final p = buildExample(ExampleId.coffee, t);
    final r = Designer(p, label: t).designAll();
    final prog = buildControllerProgram(p, r, startDate: DateTime(2026, 1, 1));
    expect(prog.warnings, isEmpty);
    expect(prog.maxDailyHours, lessThan(24));
    final days = {for (final f in p.systemFlows) f.id: prog.entries.where((e) => e.flowId == f.id).map((e) => e.day).toSet()};
    expect(days.values.every((d) => d.isNotEmpty), isTrue);
    expect(days.values.first.intersection(days.values.last), isEmpty);
  });

  test('a pivot waters its area in the water table', () {
    for (final id in [ExampleId.pivot, ExampleId.sectorPivot, ExampleId.linear]) {
      final p = buildExample(id, t);
      final r = Designer(p, label: t).designAll();
      final pivot = r.pivots.values.single;
      final req = areaRequirements(p, r).single;
      // the area is the irrigated outline: all the flow falls on it
      expect(req.flow, closeTo(pivot.flow, pivot.flow * 0.03), reason: id.name);
      expect(req.precipitationMmH, greaterThan(0), reason: id.name);
      expect(req.hoursPerDay, inExclusiveRange(12, 24), reason: '${id.name}: ${req.hoursPerDay} h a day at ${pivot.flow / m3sPerM3h} m³/h');
    }
  });
}
