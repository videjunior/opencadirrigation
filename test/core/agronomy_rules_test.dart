import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/core/design/agronomy.dart';
import 'package:opencadirrigation/core/design/area_requirement.dart';
import 'package:opencadirrigation/core/design/area_water.dart';
import 'package:opencadirrigation/core/design/crops.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/irrigation_requirement.dart';
import 'package:opencadirrigation/core/design/report_tables.dart';
import 'package:opencadirrigation/core/design/results.dart';
import 'package:opencadirrigation/core/hydraulics/uniformity.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/model/site_climate.dart';

/// The agronomy reports of one field agree with each other (sweep of
/// 2026-11-01, AGR-01 to AGR-24): the FAO-56 requirement table, the water
/// table, the crop water table, the run times and the controller programme
/// follow one rule for localized irrigation (ETc,loc = Kr·Kc·ETo over the
/// whole area, the wetted fraction only in the readily available water;
/// FAO-56 and Keller & Bliesner 1990), use the values typed on the area,
/// keep every area of a system flow within its readily available water and
/// treat machines as machines.
void main() {
  String t(String key, [Map<String, String>? args]) => key;
  const square = [Pt(0, 0), Pt(100, 0), Pt(100, 100), Pt(0, 100)];

  // 1 ha of drip-irrigated young citrus (the case of the sweep)
  AreaEntity citrus({double rootDepthM = 0.4, double mad = 0.3}) => AreaEntity(
    id: 'a1',
    points: square,
    cropKey: 'crop.citrus',
    useWaterBalance: true,
    etoMmDay: 6,
    kc: 0.65,
    awcMmPerM: 120,
    rootDepthM: rootDepthM,
    mad: mad,
    wettedFraction: 0.33,
    irrigationMethod: 'localized',
    groundCover: 0.7,
    efficiency: 0.9,
  );

  ZoneResult zone(String id, Pt p, {double flow = 1e-4, int count = 10}) => ZoneResult(
    valveId: id,
    zoneName: id,
    converged: true,
    totalFlow: flow * count,
    downstreamHead: 20,
    valveLoss: 1,
    requiredUpstreamHead: 25,
    minOutletPressure: 15,
    maxOutletPressure: 20,
    allowedMin: 10,
    allowedMax: 30,
    nominalPressure: 20,
    uniformity: const UniformityStats(count: 1, mean: 1, min: 1, max: 1, cu: 1, du: 1, eu: 1, us: 1, qvar: 0, cv: 0),
    pipes: const [],
    devices: const [],
    warnings: const [],
    valveElevation: 0,
    outlets: [OutletResult(entityId: 'x$id', index: 0, p: p, elevation: 0, pressure: 20, flow: flow, nominalFlow: flow, count: count, allowedMin: 10, allowedMax: 30, label: '')],
  );

  group('one rule for localized irrigation (AGR-01)', () {
    test('Kr from the ground cover reduces ETc; Pw only the readily available water', () {
      final a = citrus();
      expect(isLocalizedArea(a), isTrue);
      // Keller & Bliesner (1990): Kr = 0.1·√Pd, Pd = 70 %
      expect(areaKr(a), closeTo(0.1 * math.sqrt(70), 1e-12));
      expect(areaPw(a), 0.33);
      // a typed Kr wins over the ground cover
      expect(areaKr(a..localizedKr = 0.6), 0.6);
      // sprinkler and surface irrigation: no reduction
      final s = AreaEntity(id: 's', points: square, wettedFraction: 1);
      expect((areaKr(s), areaPw(s), isLocalizedArea(s)), (1.0, 1.0, false));
      // an area left at the default method with a wetted fraction below 1 is drip
      expect(isLocalizedArea(AreaEntity(id: 'd', points: square, wettedFraction: 0.4)), isTrue);
      expect(areaIrrigationMethod(AreaEntity(id: 'd', points: square, wettedFraction: 0.4)), 'localized');
      expect(isLocalizedArea(AreaEntity(id: 'f', points: square, wettedFraction: 0.4, irrigationMethod: 'surface')), isFalse);
    });

    test('the FAO-56 table, the water table, the crop table and the programme give the same daily volume', () {
      final a = citrus();
      final p = Project(entities: [a]);
      final table = irrigationRequirement(requirementInputOf(p, a)!);
      final peak = designRow(table)!;
      // before the fix the water table and the programme used Pw as Kr: 14.3 against 39.0 m³/day
      expect(peak.dailyVolumeM3, closeTo(39.0, 0.1));
      final water = areaRequirements(p, null).single;
      expect(water.dailyVolumeM3, closeTo(peak.dailyVolumeM3, 1e-9));
      expect(water.grossDepthMm, closeTo(peak.grossMmDay, 1e-9));
      final crop = cropWaterRequirements(p, null).single;
      expect(crop.etcMmDay, closeTo(peak.etcLocMmDay, 1e-9));
      expect(crop.volumePerEventM3 / crop.intervalDays, closeTo(peak.dailyVolumeM3, 1e-9));
      expect(crop.kr, closeTo(0.1 * math.sqrt(70), 1e-12));
      expect(crop.month, peak.start.month);
    });

    test('without a crop of the table the balance uses Kr·Kc·ETo and Pw in the RAW', () {
      final a = AreaEntity(id: 'b', points: square, useWaterBalance: true, etoMmDay: 5, kc: 1, awcMmPerM: 100, rootDepthM: 0.5, mad: 0.5, wettedFraction: 0.5, groundCover: 0.49, efficiency: 0.9);
      final p = Project(entities: [a]);
      final b = areaWaterBasis(p, a);
      expect(b.source, AreaWaterSource.balance);
      expect(b.kr, closeTo(0.7, 1e-12)); // 0.1·√49
      expect(b.etcMmDay, closeTo(3.5, 1e-12));
      expect(b.rawMm, closeTo(100 * 0.5 * 0.5 * 0.5, 1e-12));
      expect(b.intervalDays, 3); // 12.5 / 3.5
      final water = areaRequirements(p, null).single;
      // the volume is the gross depth over the whole area: no Pw factor
      expect(water.dailyVolumeM3, closeTo(3.5 / 0.9 * 10000 / 1000, 1e-9));
    });

    test('a fixed net depth is the requirement over the whole area', () {
      final a = AreaEntity(id: 'f', points: square, netDepthMmPerDay: 4, efficiency: 0.8, wettedFraction: 0.5);
      final water = areaRequirements(Project(entities: [a]), null).single;
      expect(water.grossDepthMm, closeTo(5, 1e-12));
      expect(water.dailyVolumeM3, closeTo(50, 1e-9));
    });
  });

  group('the requirement table uses what the area says (AGR-02)', () {
    test('typed root depth, MAD and AWC enter the readily available water', () {
      final a = citrus();
      final input = requirementInputOf(Project(entities: [a]), a)!;
      expect(input.cycles.single.rootDepthM, 0.4);
      expect(input.cycles.single.depletionFraction, 0.3);
      final peak = designRow(irrigationRequirement(input))!;
      expect(peak.tawMm, closeTo(48, 1e-9)); // 120 mm/m × 0.4 m, not the 144 mm of the table's 1.2 m
      // a typed MAD is a management choice: not adjusted to ETc
      expect(peak.depletionFraction, 0.3);
      expect(peak.rawMm, closeTo(48 * 0.3 * 0.33, 1e-9));
      expect(peak.intervalDays, 1);
    });

    test('the table value of p is still adjusted to ETc (FAO-56 Table 22 note 2)', () {
      final crop = fao56Crops['crop.citrus']!;
      final a = citrus(rootDepthM: crop.schedulingRootDepthM!, mad: crop.depletionFraction!);
      final peak = designRow(irrigationRequirement(requirementInputOf(Project(entities: [a]), a)!))!;
      expect(peak.depletionFraction, closeTo(adjustDepletionFraction(crop.depletionFraction!, peak.etcMmDay), 1e-12));
    });

    test('a typed AWC wins over the soil class', () {
      final a = citrus()
        ..soilKey = 'soil.sand'
        ..awcMmPerM = 150;
      expect(requirementInputOf(Project(entities: [a]), a)!.awcMmPerM, 150);
    });
  });

  group('controller programme (AGR-03, AGR-05, AGR-06)', () {
    Project twoAreas({double rootB = 1.0, double awcB = 160}) {
      final a = AreaEntity(id: 'A', points: const [Pt(8, 8), Pt(12, 8), Pt(12, 12), Pt(8, 12)], useWaterBalance: true, etoMmDay: 6, kc: 1, awcMmPerM: 60, rootDepthM: 0.3, mad: 0.5, efficiency: 1);
      final b = AreaEntity(
        id: 'B',
        points: const [Pt(38, 8), Pt(42, 8), Pt(42, 12), Pt(38, 12)],
        useWaterBalance: true,
        etoMmDay: 6,
        kc: 1,
        awcMmPerM: awcB,
        rootDepthM: rootB,
        mad: 0.5,
        efficiency: 1,
      );
      return Project(
        entities: [
          a,
          b,
          OutletEntity(id: 'hA', position: const Pt(10, 10), outletSpecId: 'micro', headM: 20),
          OutletEntity(id: 'hB', position: const Pt(40, 10), outletSpecId: 'micro', headM: 20),
          ControlValveEntity(id: 'vA', position: const Pt(0, -5), zoneName: 'ZA'),
          ControlValveEntity(id: 'vB', position: const Pt(30, -5), zoneName: 'ZB'),
        ],
        systemFlows: [
          SystemFlow(id: 'f1', name: 'F1', valveIds: {'vA', 'vB'}),
        ],
      );
    }

    DesignResults results() {
      final r = DesignResults(timestamp: DateTime(2026));
      r.zones['vA'] = zone('vA', const Pt(10, 10));
      r.zones['vB'] = zone('vB', const Pt(40, 10));
      return r;
    }

    test('a flow takes the shortest interval of its areas: no area goes past its RAW', () {
      final p = twoAreas();
      final r = results();
      final crops = {for (final c in cropWaterRequirements(p, r)) c.areaId: c};
      expect(crops['A']!.intervalDays, 1);
      expect(crops['B']!.intervalDays, 13);
      final prog = buildControllerProgram(p, r, startDate: DateTime(2026, 1, 1), days: 14);
      // before: 30.9 h every 13 days, 78 mm on a bed holding 9 mm
      expect(prog.intervalDays['f1'], 1);
      expect(prog.perFlowHours['f1'], closeTo(crops['A']!.hoursPerEvent, 1e-9));
      expect(prog.entries, hasLength(14));
      for (final c in crops.values) {
        final event = prog.perFlowHours['f1']! * c.applicationRateMmH;
        expect(event, lessThanOrEqualTo(c.rawMm + 1e-9), reason: c.areaId);
        // the same water as the area needs over the 14 days
        expect(prog.entries.length * event, closeTo(14 * c.etcMmDay, 1e-6), reason: c.areaId);
      }
      expect(prog.warnings, isEmpty);
    });

    test('areas of one flow that need very different run times are reported', () {
      final p = twoAreas();
      (p.byId('B') as AreaEntity).kc = 0.5;
      final prog = buildControllerProgram(p, results(), startDate: DateTime(2026, 1, 1), days: 7);
      expect(prog.warnings, contains('schedule_uneven_areas:f1'));
    });

    test('with a site climate and a crop of the table the programme follows the design month', () {
      final a = citrus();
      final p = Project(entities: [a]);
      p.climate = SiteClimate(etoMmDay: [7.5, 7.0, 6.0, 5.0, 4.0, 3.5, 3.5, 4.5, 5.5, 6.5, 7.0, 7.5], rainMm: List.filled(12, 0.0), latitudeDeg: -15);
      final table = areaRequirementTables(p, null)['a1']!;
      final crop = cropWaterRequirements(p, null).single;
      // before: ETo 6 typed on the area, about 20 % short in the peak month
      expect(crop.etcMmDay, closeTo(designRow(table)!.etcLocMmDay, 1e-9));
      expect(crop.month, designRow(table)!.start.month);
      expect(table.areaTotals.peakNetMmDay, closeTo(crop.etcMmDay, 1e-9));
      // or the month asked for
      final july = cropWaterRequirements(p, null, month: 7).single;
      expect(july.month, 7);
      expect(july.etcMmDay, closeTo(designRow(table, month: 7)!.etcLocMmDay, 1e-9));
      expect(july.etcMmDay, lessThan(crop.etcMmDay));
    });

    test('a balance area without a crop takes the ETo of the month asked for from the climate', () {
      final a = AreaEntity(id: 'b', points: square, useWaterBalance: true, etoMmDay: 6, kc: 1);
      final p = Project(entities: [a])..climate = SiteClimate(etoMmDay: List.generate(12, (m) => m + 1.0), rainMm: List.filled(12, 0.0));
      expect(areaWaterBasis(p, a).etoMmDay, 6);
      expect(areaWaterBasis(p, a, month: 3).etoMmDay, 3);
    });

    test('a pivot in a system flow runs the hours its area needs every day', () {
      final p = buildExample(ExampleId.pivot, t);
      final pv = p.entities.whereType<PivotEntity>().first;
      p.systemFlows.add(SystemFlow(id: 'sf1', name: 'Pivot', valveIds: {pv.id}));
      final r = Designer(p, label: t).designAll();
      final crop = cropWaterRequirements(p, r).single;
      expect(crop.machine, isTrue);
      expect(crop.intervalDays, 1);
      // before: "114 h per event every 5 days"
      expect(crop.hoursPerEvent, inExclusiveRange(12, 24));
      final prog = buildControllerProgram(p, r, startDate: DateTime(2026, 1, 1), days: 3);
      expect(prog.warnings, isEmpty, reason: 'no schedule_no_area: the machine waters its field');
      expect(prog.entries, hasLength(3));
      expect(prog.perFlowHours['sf1'], closeTo(crop.hoursPerEvent, 1e-9));
      expect(prog.entries.first.zones, [pv.name.isNotEmpty ? pv.name : pv.id]);
      final water = areaRequirements(p, r).single;
      expect(prog.perFlowHours['sf1'], closeTo(water.hoursPerDay, 1e-6));
    });
  });

  group('planting date (AGR-08)', () {
    (DateTime, PlantingRead) read(String s, {bool southern = false}) => readPlantingDate(
      AreaEntity(id: 'a', points: square, cropKey: 'crop.maize', plantingMonthDay: s),
      southern: southern,
    );

    test('the stored MM-DD, day-first slashes, month names and whole dates', () {
      expect(read('09-15'), (DateTime.utc(2001, 9, 15), PlantingRead.given));
      // the Brazilian habit: 15/09 is 15 September (it was read as 9 December)
      expect(read('15/09'), (DateTime.utc(2001, 9, 15), PlantingRead.given));
      expect(read('31/12'), (DateTime.utc(2001, 12, 31), PlantingRead.given));
      expect(read('15.09'), (DateTime.utc(2001, 9, 15), PlantingRead.given));
      expect(read('set-15'), (DateTime.utc(2001, 9, 15), PlantingRead.given));
      expect(read('15 de setembro'), (DateTime.utc(2001, 9, 15), PlantingRead.given));
      expect(read('Sep 15'), (DateTime.utc(2001, 9, 15), PlantingRead.given));
      expect(read('2026-09-15'), (DateTime.utc(2001, 9, 15), PlantingRead.given));
      expect(read('15/09/2026'), (DateTime.utc(2001, 9, 15), PlantingRead.given));
      expect(read('05/05').$2, PlantingRead.given);
    });

    test('ambiguous and invalid dates are reported, not read silently', () {
      expect(read('05/09'), (DateTime.utc(2001, 9, 5), PlantingRead.ambiguous));
      expect(readPlantingDate(AreaEntity(id: 'a', points: square, plantingMonthDay: '05/09'), monthFirst: true).$1, DateTime.utc(2001, 5, 9));
      // 30 February, an unknown month name and garbage take the default
      expect(read('2-30'), (DateTime.utc(2001, 4, 1), PlantingRead.invalid));
      expect(read('xyz-15'), (DateTime.utc(2001, 4, 1), PlantingRead.invalid));
      expect(read('soon'), (DateTime.utc(2001, 4, 1), PlantingRead.invalid));
    });

    test('without a date the FAO-56 row month, six months later in the south', () {
      expect(read(''), (DateTime.utc(2001, 4, 1), PlantingRead.missing));
      expect(read('', southern: true), (DateTime.utc(2001, 10, 1), PlantingRead.missing));
      final p = Project(
        entities: [AreaEntity(id: 'm', points: square, cropKey: 'crop.maize')],
      )..climate = SiteClimate(etoMmDay: List.filled(12, 5.0), rainMm: List.filled(12, 0.0), latitudeDeg: -15);
      expect(siteIsSouthern(p), isTrue);
      expect(requirementInputOf(p, p.entities.single as AreaEntity)!.cycles.single.planting, DateTime.utc(2001, 10, 1));
    });
  });

  group('requirement table rows (AGR-11, AGR-20, AGR-24)', () {
    test('water too saline for the crop: gross and volume not applicable and out of the totals', () {
      final s = AreaEntity(id: 's1', points: square, cropKey: 'crop.dryBean', ecwDsM: 6, efficiency: 0.75);
      final table = irrigationRequirement(requirementInputOf(Project(entities: [s]), s)!);
      final rows = table.monthly.where((r) => r.netMm > 0).toList();
      expect(rows, isNotEmpty);
      for (final r in rows) {
        // before: LR = 0.9, 927.5 mm gross for 69.6 mm net
        expect(r.applicable, isFalse);
        expect(r.grossMm, 0);
        expect(r.volumeM3, 0);
        expect(r.hoursPerEvent, isNull);
      }
      expect(table.areaTotals.grossMm, 0);
      expect(table.areaTotals.notApplicableRows, rows.length);
      expect(table.warnings, contains('req_leaching_infeasible'));
      // a yield potential the water can keep makes it applicable again
      final lower = AreaEntity(id: 's2', points: square, cropKey: 'crop.dryBean', ecwDsM: 1, efficiency: 0.75, yieldPotentialPct: 75);
      final ok = irrigationRequirement(requirementInputOf(Project(entities: [lower]), lower)!);
      expect(ok.monthly.every((r) => r.applicable), isTrue);
      expect(requirementInputOf(Project(entities: [lower]), lower)!.yieldPotentialPct, 75);
    });

    test('the interval follows ETc,loc: the mean rain lowers the events, not the interval', () {
      final dry = AreaEntity(id: 'd', points: square, cropKey: 'crop.turf', useWaterBalance: true, rootDepthM: 0.5, mad: 0.5, awcMmPerM: 100);
      final p = Project(entities: [dry])..climate = SiteClimate(etoMmDay: List.filled(12, 5.0), rainMm: List.filled(12, 80.0));
      final rows = irrigationRequirement(requirementInputOf(p, dry)!).monthly;
      final pDry = Project(entities: [dry])..climate = SiteClimate(etoMmDay: List.filled(12, 5.0), rainMm: List.filled(12, 0.0));
      final rowsDry = irrigationRequirement(requirementInputOf(pDry, dry)!).monthly;
      for (var i = 0; i < rows.length; i++) {
        final r = rows[i], d = rowsDry[i];
        expect(r.effectiveRainMm, greaterThan(0));
        expect(r.maxIntervalDays, closeTo(r.rawMm / r.etcLocMmDay, 1e-9));
        expect(r.intervalDays, d.intervalDays);
        expect(r.netPerEventMm, closeTo(r.etcLocMmDay * r.intervalDays, 1e-9));
        expect(r.events, lessThan(d.events));
        expect(r.events, closeTo(r.netMm / r.netPerEventMm, 1e-9));
      }
    });

    test('the gross per day column counts the crop days of the month', () {
      // maize planted on 20 April: 11 crop days in April
      final a = AreaEntity(id: 'm', name: 'M', points: square, cropKey: 'crop.maize', plantingMonthDay: '04-20');
      final p = Project(entities: [a]);
      final row = irrigationRequirement(requirementInputOf(p, a)!).monthly.firstWhere((r) => r.start.month == 4);
      expect(row.cropDays, 11);
      final labels = ReportLabels(t: t, has: (_) => true, warning: (w) => w, entityName: (id) => id);
      final tb = buildReportTables(project: p, results: null, labels: labels).firstWhere((x) => x.key == 'requirement');
      final r = tb.rows.firstWhere((r) => r[2] == 'mon.4');
      expect((r[13] as RNum).value, closeTo(row.grossMmDay, 1e-9));
      expect(row.grossMmDay, greaterThan(row.grossMm / 30 * 2));
    });
  });

  group('crop coefficients of the site (AGR-09)', () {
    // maize in a semi-arid climate: RHmin 30 %, u2 3 m/s
    Project semiArid(AreaEntity a) =>
        Project(entities: [a])..climate = SiteClimate(etoMmDay: List.filled(12, 6.0), rainMm: List.filled(12, 0.0), rhMinPct: List.filled(12, 30.0), windSpeed2mMs: List.filled(12, 3.0));

    test('Kc mid and Kc end adjusted to the humidity and the wind (FAO-56 eqs. 62 and 65)', () {
      final a = AreaEntity(id: 'm', points: square, cropKey: 'crop.maize', useWaterBalance: true, irrigationMethod: 'localized', wettedFraction: 0.5);
      final curve = requirementInputOf(semiArid(a), a)!.cycles.single.curve;
      // 1.20 + [0.04(3 − 2) − 0.004(30 − 45)]·(2/3)^0.3 ≈ 1.29
      expect(curve.kcMid, closeTo(adjustKcForClimate(1.20, windSpeed2mMs: 3, rhMinPct: 30, heightM: 2), 1e-12));
      expect(curve.kcMid, closeTo(1.29, 0.005));
      expect(curve.kcEnd, closeTo(adjustKcForClimate(0.60, windSpeed2mMs: 3, rhMinPct: 30, heightM: 2), 1e-12));
      // switched off, or a climate without humidity and wind: the table
      a.climateKc = false;
      expect(requirementInputOf(semiArid(a), a)!.cycles.single.curve.kcMid, 1.20);
      a.climateKc = true;
      final plain = Project(entities: [a])..climate = SiteClimate(etoMmDay: List.filled(12, 6.0), rainMm: List.filled(12, 0.0));
      expect(requirementInputOf(plain, a)!.cycles.single.curve.kcMid, 1.20);
    });

    test('Kc ini of sprinkled crops from the interval and depth of the irrigations (FAO-56 Annex 7)', () {
      // a shallow sandy bed watered every day or two
      final a = AreaEntity(id: 'm', points: square, cropKey: 'crop.maize', useWaterBalance: true, soilKey: 'soil.sand', awcMmPerM: 40, rootDepthM: 0.3, mad: 0.5);
      final p = semiArid(a);
      final input = requirementInputOf(p, a)!;
      final kcIni = input.cycles.single.curve.kcIni;
      expect(kcIni, isNot(closeTo(0.30, 0.01)), reason: 'not the tabulated value');
      // the fixed point: the Kc ini of the irrigations the table gives with it
      final row = irrigationRequirement(input).monthly.firstWhere((r) => r.start.month == 4);
      expect(
        kcIni,
        closeTo(kcIniFromWetting(etoMmDay: row.etoMmDay, wettingIntervalDays: row.intervalDays.toDouble(), infiltrationDepthMm: row.netPerEventMm, texture: SoilWettingTexture.coarse), 0.006),
      );
      expect(row.intervalDays, lessThanOrEqualTo(2));
      expect(kcIni, greaterThan(0.5), reason: 'frequent wetting keeps the soil surface wet');
      // drip keeps the table's Kc ini (its partial wetting is in Kr and Pw)
      a
        ..irrigationMethod = 'localized'
        ..wettedFraction = 0.4;
      expect(requirementInputOf(p, a)!.cycles.single.curve.kcIni, 0.30);
      a
        ..irrigationMethod = 'sprinkler'
        ..wettedFraction = 1
        ..climateKc = false;
      expect(requirementInputOf(p, a)!.cycles.single.curve.kcIni, 0.30);
    });
  });

  group('programme times (AGR-17)', () {
    test('rounded to the minute before splitting; an end after midnight says so', () {
      expect(clockTime(6 + 1.9999), ('08:00', 0));
      expect(clockTime(22 + 4), ('02:00', 1));
      expect(clockText(26), '02:00 +1 d');
      expect(clockText(26, t: (k) => k == 'sch.plusDays' ? '+{n} dia' : k), '02:00 +1 dia');
      final prog = ControllerProgram(
        perFlowHours: const {},
        entries: [
          ScheduleEntry(day: DateTime(2026, 1, 1), flowId: 'f', flowName: 'F', startHour: 6, durationHours: 1.9999, zones: const ['Z'], flow: 0),
        ],
        warnings: const [],
      );
      expect(controllerProgramCsv(prog).split('\n')[1], '2026-01-01;F;Z;06:00;08:00;2.00');
      final late = ControllerProgram(
        perFlowHours: const {},
        entries: [
          ScheduleEntry(day: DateTime(2026, 1, 1), flowId: 'f', flowName: 'F', startHour: 22, durationHours: 4, zones: const ['Z'], flow: 0),
        ],
        warnings: const [],
      );
      expect(controllerProgramCsv(late).split('\n')[1], '2026-01-01;F;Z;22:00;02:00 +1 d;4.00');
    });
  });

  group('the gallery after the rule (AGR-14)', () {
    test('every example: the same daily volume in every report, intervals within the RAW', () {
      for (final ex in exampleGallery) {
        final p = buildExample(ex.id, t);
        final r = Designer(p, label: t).designAll();
        final water = {for (final w in areaRequirements(p, r)) w.areaId: w};
        final tables = areaRequirementTables(p, r);
        for (final c in cropWaterRequirements(p, r)) {
          final a = p.byId(c.areaId) as AreaEntity;
          final w = water[c.areaId]!;
          expect(c.volumePerEventM3 / c.intervalDays, closeTo(w.dailyVolumeM3, 1e-6), reason: '${ex.id.name} ${a.name}');
          if (!c.machine) expect(c.intervalDays * c.etcMmDay, lessThanOrEqualTo(c.rawMm + 1e-9).or(c.intervalDays == 1), reason: '${ex.id.name} ${a.name}');
          final table = tables[c.areaId];
          if (table != null) expect(w.dailyVolumeM3, closeTo(designRow(table)!.dailyVolumeM3, 1e-6), reason: '${ex.id.name} ${a.name}');
        }
        final prog = buildControllerProgram(p, r, startDate: DateTime(2026, 1, 1));
        expect(prog.warnings, isEmpty, reason: ex.id.name);
      }
    });
  });
}

extension on Matcher {
  /// [this] or, when [alternative] holds, anything.
  Matcher or(bool alternative) => alternative ? anything : this;
}
