import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/core/design/area_water.dart';
import 'package:opencadirrigation/core/model/agronomy_plan.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/model/read_report.dart';
import 'package:opencadirrigation/core/model/site_climate.dart';

/// The agronomy plan kept in the project (1.6.0 AGR): the user's crops
/// (PRD-15), the programme, water balance and fertigation settings and the
/// field evaluations, written only when they differ from a new project's,
/// read item by item with the unknown fields kept; the daily climate of the
/// site; the realistic ground cover of the drip areas of the gallery.
void main() {
  String t(String key, [Map<String, String>? args]) => key;
  const square = [Pt(0, 0), Pt(100, 0), Pt(100, 100), Pt(0, 100)];

  UserCrop passionFruit() => UserCrop(
    id: 'maracuja',
    name: 'Maracujá',
    kcIni: 0.5,
    kcMid: 1.1,
    kcEnd: 0.9,
    initialDays: 60,
    developmentDays: 90,
    midDays: 120,
    lateDays: 60,
    plantingMonth: 9,
    rootDepthM: 0.5,
    depletionFraction: 0.35,
    maxHeightM: 2,
    ky: 1.1,
    source: 'boletim de extensão',
  );

  AgronomyPlan full() => AgronomyPlan(
    userCrops: [passionFruit()],
    programme: ProgrammeSettings(windowStartHour: 20, windowHours: 10, cycleSoak: true, seasonalPct: List.filled(12, 80.0), inReports: true),
    balance: {'a': BalanceSettings(trigger: BalanceTrigger.interval, intervalDays: 4, allowedDepletion: [0, 0, 0.6, 0.7], refillPct: 80, year: 2019, ky: 1.2)},
    fertigation: {
      'a': FertigationStagePlan(
        doseKgHa: [120, 60, 90],
        sharePct: [
          [10, 30, 10],
          [30, 30, 30],
          [40, 30, 40],
          [20, 10, 20],
        ],
        everyNth: 2,
      ),
    },
    fieldTests: [FieldTest(id: 'ft1', name: 'Zona 1', date: '2026-11-01', zoneId: 'v1', origin: const Pt(1.5, 1.5), cols: 2, values: [100, null, 120, 110])],
  );

  group('agronomy plan in the project file', () {
    test('a new project writes no agronomy and reads it back as the default', () {
      expect(AgronomyPlan().isDefault, isTrue);
      expect(AgronomyPlan().toJson(), isEmpty);
      final p = Project();
      expect(p.toJson().containsKey('agronomy'), isFalse);
      final back = Project.fromJsonString(jsonEncode(p.toJson()));
      expect(back.agronomy.isDefault, isTrue);
      // settings equal to the defaults are not written either
      final same = Project()..agronomy.balance['a'] = BalanceSettings();
      expect(same.toJson().containsKey('agronomy'), isFalse);
    });

    test('every part survives a save and a reopen', () {
      final p = Project(entities: [AreaEntity(id: 'a', points: square)], agronomy: full());
      final json = jsonEncode(p.toJson());
      final back = Project.fromJsonString(json);
      expect(jsonEncode(back.agronomy.toJson()), jsonEncode(p.agronomy.toJson()));
      final crop = back.agronomy.userCrop('user.maracuja')!;
      expect(crop.name, 'Maracujá');
      expect(crop.seasonDays, 330);
      expect(crop.ky, 1.1);
      expect(back.agronomy.programme.windowStartHour, 20);
      expect(back.agronomy.programme.effectiveWindowHours, 10);
      expect(back.agronomy.programme.cycleSoak, isTrue);
      expect(back.agronomy.balance['a']!.trigger, BalanceTrigger.interval);
      expect(back.agronomy.balance['a']!.deficit, isTrue);
      expect(back.agronomy.fertigation['a']!.sharePct![2], [40, 30, 40]);
      expect(back.agronomy.fertigation['a']!.products.map((x) => x.name), ['urea', 'map', 'kcl']);
      final ft = back.agronomy.fieldTests.single;
      expect(ft.values, [100, null, 120, 110]);
      expect(ft.position(3).x, closeTo(4.5, 1e-9));
      expect(ft.position(3).y, closeTo(4.5, 1e-9));
    });

    test('fields of a newer version are kept; a damaged crop is left out and noted', () {
      final rep = ProjectReadReport();
      final plan = AgronomyPlan.fromJson({
        'crops': [
          {'id': 'not an id!', 'name': 'x'},
          {'id': 'cacau', 'name': 'Cacau', 'kc': [0.9, 1.05, 1.05], 'days': [0, 0, 0, 0], 'future': 7},
          {'id': 'cacau', 'name': 'Second'},
          'not an object',
        ],
        'later': true,
      }, report: rep);
      expect(plan.userCrops.map((u) => u.name), ['Cacau'], reason: 'the first of an id is kept');
      expect(rep.skipped['agronomy'], 2);
      final json = plan.toJson();
      expect(json['later'], isTrue);
      expect((json['crops'] as List).single['future'], 7);
      // no stage lengths: the crop is evergreen at Kc mid
      final data = plan.userCrops.single.toCropData();
      expect(data.stages, isNull);
      expect(data.curve.at(200), closeTo(1.05, 1e-12));
      expect(data.tabulated, isFalse);
    });

    test('a free identifier for a crop name', () {
      expect(userCropIdFor('Maracujá amarelo', const []), 'maracuja_amarelo');
      expect(userCropIdFor('Maracujá amarelo', const ['maracuja_amarelo']), 'maracuja_amarelo_2');
      expect(userCropIdFor('  ', const []), 'crop');
      expect(validUserCropId('pimenta-do-reino'), isTrue);
      expect(validUserCropId('com espaço'), isFalse);
    });
  });

  group("the user's crops in the water rule (PRD-15)", () {
    test('an area on a crop of the user takes its curve and planting month', () {
      final uc = passionFruit();
      final a = AreaEntity(id: 'a', points: square, cropKey: uc.key, useWaterBalance: true, irrigationMethod: 'localized', wettedFraction: 0.5, groundCover: 0.6);
      final p = Project(entities: [a], agronomy: AgronomyPlan(userCrops: [uc]));
      final data = cropDataOf(p, uc.key)!;
      expect(data.key, 'user.maracuja');
      expect(data.kcMid, 1.1);
      expect(data.stages!.total, 330);
      expect(data.depletionFraction, 0.35);
      expect(cropDataOf(p, 'crop.tomato'), isNotNull);
      expect(cropDataOf(p, 'user.unknown'), isNull);
      expect(cropDataOf(p, ''), isNull);
      expect(cropNameOf(p, uc.key, t), 'Maracujá');
      expect(cropNameOf(p, 'crop.tomato', t), 'crop.tomato');
      final req = requirementInputOf(p, a)!;
      final cycle = req.cycles.single;
      expect(cycle.cropKey, 'user.maracuja');
      expect(cycle.curve.kcIni, closeTo(0.5, 1e-12));
      expect(cycle.planting.month, 9);
      expect(areaWaterBasis(p, a).grossMmDay, greaterThan(0));
    });

    test('in the southern hemisphere a crop of the user keeps the month typed for it', () {
      final uc = passionFruit();
      final mine = AreaEntity(id: 'a', points: square, cropKey: uc.key);
      final (date, how) = readPlantingDate(mine, southern: true, crop: uc.toCropData());
      expect(date.month, 9);
      expect(how, isNot(PlantingRead.invalid));
      // a row of the FAO-56 table moves six months (April → October)
      final tomato = AreaEntity(id: 'b', points: square, cropKey: 'crop.tomato');
      expect(readPlantingDate(tomato, southern: true).$1.month, 10);
    });
  });

  group('daily climate of the site', () {
    test('days in any order become one value a day, the gaps NaN', () {
      final d = DailyClimate.fromDays([(DateTime.utc(2019, 1, 3), 5.0, 0.0), (DateTime.utc(2019, 1, 1), 4.0, 12.0), (DateTime.utc(2019, 1, 4), null, 2.0)], source: 'inmet')!;
      expect(d.start, DateTime.utc(2019, 1, 1));
      expect(d.length, 4);
      expect(d.etoMm[0], 4.0);
      expect(d.etoMm[1].isNaN, isTrue);
      expect(d.rainMm[1].isNaN, isTrue);
      expect(d.etoMm[3].isNaN, isTrue);
      expect(d.rainMm[3], 2.0);
      expect(DailyClimate.fromDays(const []), isNull);
      // a missing ETo takes the month of the normals, missing rain is none
      final days = d.yearDays(2019, fill: List.filled(12, 6.0));
      expect(days.map((x) => x.$2), [4.0, 6.0, 5.0, 6.0]);
      expect(days.map((x) => x.$3), [12.0, 0.0, 0.0, 2.0]);
      expect(d.yearDays(2018), isEmpty);
      expect(d.completeYears, isEmpty, reason: 'four days are not a year');
    });

    test('a complete year is listed; the days survive the file', () {
      final y = [for (var i = 0; i < 365; i++) (DateTime.utc(2019).add(Duration(days: i)), 4.5, i % 10 == 0 ? 8.0 : 0.0)];
      final d = DailyClimate.fromDays(y, source: 'inmet')!;
      expect(d.completeYears, [2019]);
      final sc = SiteClimate(etoMmDay: List.filled(12, 4.5), rainMm: List.filled(12, 24.0), source: 'inmet', daily: d);
      final back = SiteClimate.fromJson(jsonDecode(jsonEncode(sc.toJson())) as Map<String, dynamic>)!;
      expect(back.daily, isNotNull);
      expect(back.daily!.length, 365);
      expect(back.daily!.start, DateTime.utc(2019, 1, 1));
      expect(back.daily!.rainMm[10], 8.0);
      expect(back.daily!.source, 'inmet');
      expect(back.copyWith().daily!.length, 365);
    });
  });

  group('ground cover of the drip areas of the gallery (owner decision)', () {
    test('the localized areas of the crops shade part of the ground', () {
      final covers = <String, double>{};
      for (final id in [ExampleId.orchard, ExampleId.rowCrop, ExampleId.greenhouse, ExampleId.coffee, ExampleId.gravity, ExampleId.bananas]) {
        final p = buildExample(id, t);
        for (final a in p.entities.whereType<AreaEntity>()) {
          if (isLocalizedArea(a) && a.groundCover < 1) covers['${id.name}/${a.id}'] = a.groundCover;
        }
        expect(covers.keys.where((k) => k.startsWith('${id.name}/')), isNotEmpty, reason: id.name);
      }
      final coffee = buildExample(ExampleId.coffee, t).entities.whereType<AreaEntity>().firstWhere(isLocalizedArea);
      expect(coffee.groundCover, 0.6);
      expect(areaKr(coffee), closeTo(0.7746, 1e-4));
    });
  });
}
