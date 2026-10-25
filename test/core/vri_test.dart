import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/vri.dart';
import 'package:opencadirrigation/core/model/geometry.dart';

void main() {
  const c = Pt(500, 500);

  group('speed control from sectors', () {
    const spec = VriSpec(center: c, radiusM: 400, depthAt100Mm: 10, minTimerPct: 5);
    final r = vriFromSectors(spec, const [
      VriSectorTarget(startDeg: 0, endDeg: 90, depthMm: 20),
      VriSectorTarget(startDeg: 90, endDeg: 180, depthMm: 10),
      VriSectorTarget(startDeg: 180, endDeg: 270, depthMm: 5),
      VriSectorTarget(startDeg: 270, endDeg: 360, depthMm: 250),
    ], id: 'v');

    test('timer = 100·d100/d within the limits, merged into one row per setting', () {
      expect(r.rows.length, 4);
      expect(r.rows[0].startDeg, 0);
      expect(r.rows[0].endDeg, 90);
      expect(r.rows[0].timerPct, closeTo(50, 1e-9));
      expect(r.rows[0].depthMm, closeTo(20, 1e-9));
      expect(r.rows[1].timerPct, closeTo(100, 1e-9));
      expect(r.rows[1].limit, 0);
      // 5 mm is below the depth at full speed: runs at 100 % and applies 10 mm
      expect(r.rows[2].timerPct, 100);
      expect(r.rows[2].depthMm, 10);
      expect(r.rows[2].limit, 1);
      // 250 mm would need 4 %: capped at the slowest setting
      expect(r.rows[3].timerPct, 5);
      expect(r.rows[3].depthMm, closeTo(200, 1e-9));
      expect(r.rows[3].limit, 2);
      expect(r.maxDepthMm, closeTo(200, 1e-9));
      expect(r.warnings, containsAll(['vri_below_minimum:v', 'vri_above_maximum:v']));
    });

    test('a sector across 0° and the base depth elsewhere', () {
      final w = vriFromSectors(const VriSpec(center: c, radiusM: 400, depthAt100Mm: 10, baseDepthMm: 12), const [VriSectorTarget(startDeg: 330, endDeg: 30, depthMm: 25)]);
      expect(w.rows.first.startDeg, 0);
      expect(w.rows.first.endDeg, 30);
      expect(w.rows.first.timerPct, closeTo(40, 1e-9));
      expect(w.rows[1].timerPct, closeTo(100 * 10 / 12, 1e-9));
      expect(w.rows.last.startDeg, 330);
      expect(w.rows.last.timerPct, closeTo(40, 1e-9));
    });

    test('CSV in drawing angles and as compass bearings', () {
      final csv = r.toCsv();
      final lines = csv.trim().split('\n');
      expect(lines.first, 'start_deg,end_deg,timer_pct,depth_mm,target_mm');
      expect(lines[1], '0.00,90.00,50.00,20.00,20.00');
      expect(lines.length, 5);
      final compass = r.toCsv(compass: true, header: ['a', 'b', 'c', 'd', 'e']).trim().split('\n');
      expect(compass.first, 'a,b,c,d,e');
      // 0–90° counter-clockwise from east is north-east: bearings 0 to 90 clockwise
      expect(compass[1].startsWith('0.00,90.00,'), isTrue);
      // 90–180° (north to west) runs clockwise from 270 to 360/0
      expect(compass[2].startsWith('270.00,0.00,'), isTrue);
    });
  });

  group('speed and zone control from polygons', () {
    // east half of the circle wetter
    final east = VriZone(polygon: [c + const Pt(0, -600), c + const Pt(600, -600), c + const Pt(600, 600), c + const Pt(0, 600)], depthMm: 15);

    test('area-weighted sector targets', () {
      final r = vriFromZones(const VriSpec(center: c, radiusM: 400, depthAt100Mm: 10), [east]);
      expect(r.rows.length, 3);
      expect(r.rows[0].endDeg, closeTo(90, 1e-9));
      expect(r.rows[0].timerPct, closeTo(100 * 10 / 15, 1e-9));
      expect(r.rows[1].startDeg, closeTo(90, 1e-9));
      expect(r.rows[1].endDeg, closeTo(270, 1e-9));
      expect(r.rows[1].timerPct, closeTo(100, 1e-9));
      expect(r.rows[2].timerPct, closeTo(100 * 10 / 15, 1e-9));
    });

    test('maximum and minimum rules on a sector cut by a zone edge', () {
      // zone edge along the 45° line: a 2° sector straddling it holds both depths
      final wedge = VriZone(polygon: [c, c + const Pt(1000, 0), c + const Pt(1000, 1000)], depthMm: 20);
      const base = VriSpec(center: c, radiusM: 400, depthAt100Mm: 10, startDeg: 44, sweepDeg: 2, sectorStepDeg: 2);
      final mean = vriFromZones(base, [wedge]).rows.single;
      final mx = vriFromZones(const VriSpec(center: c, radiusM: 400, depthAt100Mm: 10, startDeg: 44, sweepDeg: 2, sectorStepDeg: 2, rule: VriSectorRule.maximum), [wedge]).rows.single;
      final mn = vriFromZones(const VriSpec(center: c, radiusM: 400, depthAt100Mm: 10, startDeg: 44, sweepDeg: 2, sectorStepDeg: 2, rule: VriSectorRule.minimum), [wedge]).rows.single;
      expect(mean.targetMm, closeTo(15, 1e-9));
      expect(mx.targetMm, 20);
      expect(mn.targetMm, 10);
    });

    test('zone control: the sector runs at the speed of its wettest bank, the others pulse', () {
      // a zone covering the outer part of the east side only
      final outer = VriZone(polygon: [c + const Pt(250, -600), c + const Pt(600, -600), c + const Pt(600, 600), c + const Pt(250, 600)], depthMm: 20);
      final r = vriFromZones(const VriSpec(center: c, radiusM: 400, depthAt100Mm: 10, bankEdgesM: [200]), [outer]);
      expect(r.bankEdgesM, [0, 200, 400]);
      final first = r.rows.first;
      expect(first.bankDutyPct.length, 2);
      expect(first.bankDutyPct[1], closeTo(100, 1e-9));
      expect(first.depthMm, closeTo(first.targetMm, 1e-9));
      expect(first.timerPct, closeTo(100 * 10 / first.targetMm, 1e-9));
      expect(first.bankDutyPct[0], closeTo(100 * 10 / first.depthMm, 1e-9));
      // 6 of the 8 equal-area samples of the outer ring lie beyond x = 250 m near 0°
      expect(first.targetMm, closeTo(17.5, 1e-9));
      // the west side is plain: full speed, both banks on
      final west = r.rows.firstWhere((row) => row.startDeg <= 180 && row.endDeg >= 180);
      expect(west.timerPct, 100);
      expect(west.bankDutyPct, [100, 100]);
      final csv = r.toCsv().split('\n').first;
      expect(csv, 'start_deg,end_deg,timer_pct,depth_mm,target_mm,bank1_pct,bank2_pct');
      final back = VriResult.fromJson(r.toJson());
      expect(back.rows.length, r.rows.length);
      expect(back.rows.first.bankDutyPct, r.rows.first.bankDutyPct);
    });

    test('no depth at 100 % gives no prescription', () {
      final r = vriFromZones(const VriSpec(center: c, radiusM: 400, depthAt100Mm: 0), [east], id: 'v');
      expect(r.rows, isEmpty);
      expect(r.warnings, contains('vri_no_depth:v'));
    });
  });
}
