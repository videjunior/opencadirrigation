import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/core/design/advisor.dart';
import 'package:opencadirrigation/core/design/auto_fix.dart';
import 'package:opencadirrigation/core/design/design_check.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/network_builder.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/catalog_check.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/units.dart';

/// Checks of the drawing data: elevations extrapolated beyond the survey
/// (MOD-01), outlines crossing themselves (MOD-21), nozzles missing from
/// their item (MOD-15) and motors at their duty point (MOD-16).
void main() {
  group('elevations beyond the terrain data (MOD-01)', () {
    Project surveyed() {
      final p = Project();
      for (final (x, y) in [(0.0, 0.0), (100.0, 0.0), (100.0, 100.0), (0.0, 100.0)]) {
        p.entities.add(SpotHeightEntity(id: p.newId(), position: Pt(x, y), elevation: 100 + x * 0.05));
      }
      return p;
    }

    test('a pump 150 m off the survey is reported; one on its edge is not', () {
      final p = surveyed();
      final far = PumpEntity(id: p.newId(), position: const Pt(-150, 50));
      final near = PumpEntity(id: p.newId(), position: const Pt(-5, 50));
      p.entities.addAll([
        far,
        near,
        PipeEntity(id: p.newId(), points: const [Pt(50, 50), Pt(250, 50)], scope: HydraulicScope.mainline),
      ]);
      final issue = runDesignCheck(p).issues.firstWhere((i) => i.code == 'outside_terrain');
      expect(issue.severity, CheckSeverity.warning);
      expect(issue.entityIds, containsAll([far.id, p.entities.last.id]));
      expect(issue.entityIds, isNot(contains(near.id)));
      expect(issue.value, '2');
      final advice = buildAdvice(p).firstWhere((a) => a.code == 'outside_terrain');
      expect(advice.level, AdviceLevel.warning);
    });

    test('without terrain data nothing is extrapolated', () {
      final p = Project()..entities.add(PumpEntity(id: 'e1', position: const Pt(-150, 50)));
      expect(runDesignCheck(p).issues.map((i) => i.code), isNot(contains('outside_terrain')));
    });
  });

  group('area outlines crossing themselves (MOD-21)', () {
    test('a bow tie is found and cut into its two triangles', () {
      const bow = [Pt(0, 0), Pt(10, 10), Pt(10, 0), Pt(0, 10)];
      expect(polygonArea(bow), 0, reason: 'the loops cancel out');
      final x = polygonSelfCrossing(bow)!;
      expect(x.$3.distanceTo(const Pt(5, 5)), lessThan(1e-9));
      final rings = splitSelfIntersecting(bow);
      expect(rings, hasLength(2));
      expect(rings.fold(0.0, (s, r) => s + polygonArea(r).abs()), closeTo(50, 1e-9));
      for (final r in rings) {
        expect(polygonSelfCrossing(r), isNull);
      }
      expect(polygonSelfCrossing(const [Pt(0, 0), Pt(10, 0), Pt(10, 10), Pt(0, 10)]), isNull);
      expect(splitSelfIntersecting(const [Pt(0, 0), Pt(10, 0), Pt(10, 10), Pt(0, 10)]), hasLength(1));
      // a ribbon twisted three times: four simple loops
      const ribbon = [Pt(0, 0), Pt(10, 10), Pt(20, 0), Pt(30, 10), Pt(30, 0), Pt(20, 10), Pt(10, 0), Pt(0, 10)];
      final parts = splitSelfIntersecting(ribbon);
      expect(parts, hasLength(4));
      for (final r in parts) {
        expect(polygonSelfCrossing(r), isNull);
      }
      // two end triangles of 25 m² and two middle squares of 50 m²
      expect(parts.fold(0.0, (s, r) => s + polygonArea(r).abs()), closeTo(150, 1e-9));
    });

    test('the check reports it and the correction splits the area', () {
      final p = Project();
      final a = AreaEntity(id: p.newId(), name: 'Talhão', points: const [Pt(0, 0), Pt(10, 10), Pt(10, 0), Pt(0, 10)], netDepthMmPerDay: 6);
      // (the design check looks at a drawing with hydraulics)
      p.entities.addAll([a, WaterSupplyEntity(id: p.newId(), position: const Pt(-20, 0))]);
      final issue = runDesignCheck(p).issues.firstWhere((i) => i.code == 'area_self_intersecting');
      expect(issue.entityIds, [a.id]);
      expect(issue.at!.distanceTo(const Pt(5, 5)), lessThan(1e-9));
      final advice = buildAdvice(p).firstWhere((x) => x.code == 'area_self_intersecting');
      expect(advice.fixes, [FixKind.splitArea]);
      final r = applyFix(p, advice, FixKind.splitArea);
      expect(r.ok, isTrue);
      expect(r.key, 'fixed.splitArea');
      final areas = p.entities.whereType<AreaEntity>().toList();
      expect(areas, hasLength(2));
      expect(areas.first.id, a.id, reason: 'the first piece keeps the item');
      expect(areas.every((x) => x.name == 'Talhão' && x.netDepthMmPerDay == 6), isTrue);
      expect(runDesignCheck(p).issues.map((i) => i.code), isNot(contains('area_self_intersecting')));
    });
  });

  group('a nozzle the item no longer has (MOD-15)', () {
    test('is reported, not replaced by the first nozzle', () {
      final cat = Catalog.defaultCatalog();
      final impact = cat.outlet('impact34')!;
      expect(impact.nozzle(null), impact.nozzles.first, reason: 'no id: the first nozzle');
      expect(impact.nozzle('i3.5')!.id, 'i3.5');
      expect(impact.nozzle('gone'), isNull);
      final p = Project();
      final o = OutletEntity(id: p.newId(), position: const Pt(5, 0), outletSpecId: 'impact34', nozzleId: 'gone');
      p.entities.addAll([
        WaterSupplyEntity(id: p.newId(), position: Pt.zero),
        ControlValveEntity(id: p.newId(), position: const Pt(1, 0), zoneName: 'Z1'),
        PipeEntity(id: p.newId(), points: const [Pt(1, 0), Pt(5, 0)], scope: HydraulicScope.zone),
        o,
      ]);
      expect(NetworkBuilder(p).build().warnings, contains('nozzle_missing:${o.id}'));
      final issue = runDesignCheck(p).issues.firstWhere((i) => i.code == 'nozzle_missing');
      expect(issue.severity, CheckSeverity.error);
      final advice = buildAdvice(p).firstWhere((a) => a.raw == 'nozzle_missing');
      expect(advice.code, 'spec_missing');
      expect(advice.fixes, [FixKind.assignModel]);
      expect(applyFix(p, advice, FixKind.assignModel).ok, isTrue);
      expect(o.nozzleId, impact.nozzles.first.id, reason: 'now chosen on purpose, and said so');
    });
  });

  group('the motor at the duty point (MOD-16)', () {
    test('within, within the service factor, above it', () {
      final spec = PumpSpec(id: 'p', name: 'p', points: [(0, 80), (25 * m3sPerM3h, 60)], efficiency: 0.68, powerKw: 5.5);
      // 25 m³/h at 60 m: 4.08 kW of water, 6.0 kW at the shaft
      expect(pumpMotorLoad(spec, 25 * m3sPerM3h, 60), 'pump_motor_sf');
      expect(pumpMotorLoad(spec, 20 * m3sPerM3h, 60), isNull);
      expect(pumpMotorLoad(spec, 30 * m3sPerM3h, 60), 'pump_motor_overload');
      expect(
        pumpMotorLoad(PumpSpec(id: 'q', name: 'q', points: [(0, 80), (25 * m3sPerM3h, 60)]), 30 * m3sPerM3h, 60),
        isNull,
        reason: 'no rated power, no check',
      );
    });

    test('the design reports a motor too small for its duty', () {
      final t = I18n('en').call;
      final ok = buildExample(ExampleId.linear, t);
      final rOk = Designer(ok).designAll();
      final codes = [for (final f in rOk.systemFlows) ...f.warnings];
      expect(codes.where((w) => w.startsWith('pump_motor')), isEmpty, reason: 'the example pump fits its motor');
      for (final (kw, code) in [(21.0, 'pump_motor_sf'), (18.0, 'pump_motor_overload')]) {
        final p = buildExample(ExampleId.linear, t);
        p.catalog.pump('pump_big')!.powerKw = kw;
        final r = Designer(p).designAll();
        final w = [for (final f in r.systemFlows) ...f.warnings];
        expect(w.where((x) => x.startsWith('$code:')), isNotEmpty, reason: '$kw kW');
        final advice = buildAdvice(p, results: r).firstWhere((a) => a.code == code);
        expect(advice.level, code == 'pump_motor_sf' ? AdviceLevel.info : AdviceLevel.warning);
      }
    });
  });
}
