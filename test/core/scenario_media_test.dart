import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/results.dart';
import 'package:opencadirrigation/core/io/share_link.dart';
import 'package:opencadirrigation/core/model/currency.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/model/scenario.dart';

/// Alternatives keep no copy of the pictures (MOD-04) and follow a change of
/// currency (MOD-14).
void main() {
  Project withPictures() {
    final p = Project();
    p.entities.add(ImageEntity(id: p.newId(), origin: Pt.zero, width: 100, height: 100, data: Uint8List(2 * 1024 * 1024)..[7] = 9));
    p.entities.add(CommentEntity(id: p.newId(), position: Pt.zero, text: 'well', photo: 'SECRETPHOTO' * 1000));
    return p;
  }

  Scenario alternative(Project p, int k, {DesignResults? results}) =>
      Scenario(id: 'scn$k', name: 'Alt $k', created: DateTime(2026), metrics: {'capital': 1000, 'pMin': 12}, snapshot: scenarioSnapshot(p, results));

  group('alternatives without pictures (MOD-04)', () {
    test('neither the file nor the link carry a copy of the image or the photo per alternative', () {
      final p = withPictures();
      final single = p.toJsonString().length;
      for (var k = 0; k < 2; k++) {
        p.scenarios.add(alternative(p, k, results: DesignResults(timestamp: DateTime(2026))));
      }
      expect(p.toJsonString().length, lessThan(single * 1.05), reason: 'one copy of the picture, in the project');
      final link = shareableProjectJson(p.toJson());
      expect(link, isNot(contains('SECRETPHOTO')));
      expect(link.length, lessThan(200000));
      expect(jsonDecode(link)['scenarios'][0]['project'].containsKey('results'), isFalse, reason: 'the receiver designs again');
      // the saved file keeps the results of each alternative
      expect(p.scenarios.first.snapshot.containsKey('results'), isTrue);
    });

    test('restoring an alternative takes the pictures from the current project', () {
      final p = withPictures();
      final s = alternative(p, 0);
      final back = s.restoredInto(p)!;
      expect(back.entities.whereType<ImageEntity>().single.data!.length, 2 * 1024 * 1024);
      expect(back.entities.whereType<ImageEntity>().single.data![7], 9);
      expect(back.entities.whereType<CommentEntity>().single.photo, startsWith('SECRETPHOTO'));
    });

    test('alternatives of earlier files lose their copies when read', () {
      final p = withPictures();
      final old = {
        'id': 'scn1',
        'name': 'old',
        'created': '2026-01-01T00:00:00.000',
        'metrics': {'capital': 1},
        'project': p.toJson()..remove('scenarios'),
      };
      final s = Scenario.fromJson(jsonDecode(jsonEncode(old)) as Map<String, dynamic>);
      final text = jsonEncode(s.toJson());
      expect(text, isNot(contains('SECRETPHOTO')));
      expect(text.length, lessThan(100000));
    });

    test('the share link guard still leaves the pictures of the project out', () {
      expect(File('lib/core/io/share_link.dart').readAsStringSync(), contains("remove('photo')"));
    });
  });

  group('currency conversion (MOD-14)', () {
    test('hour meters, controller accessories and alternatives are converted', () {
      final p = Project();
      final pump = PumpEntity(id: p.newId(), position: Pt.zero, hourMeter: true, hourMeterCost: 100);
      final ctl = ControllerEntity(id: p.newId(), position: Pt.zero, cost: 500, accessories: {'rain': 80, 'flow': 300});
      p.entities.addAll([pump, ctl]);
      p.scenarios.add(alternative(p, 0, results: DesignResults(timestamp: DateTime(2026))));
      final rate = exchangeRate('BRL', 'USD')!;
      final pipeBrl = p.catalog.pipe('pvc50')!.costPerM;
      p.setCurrency('USD', rate: rate);
      expect(pump.hourMeterCost, closeTo(100 * rate, 1e-9));
      expect(ctl.cost, closeTo(500 * rate, 1e-9));
      expect(ctl.accessories, {'rain': closeTo(80 * rate, 1e-9), 'flow': closeTo(300 * rate, 1e-9)});
      final s = p.scenarios.single;
      expect(s.metrics['capital'], closeTo(1000 * rate, 1e-9));
      expect(s.metrics['pMin'], 12, reason: 'not money');
      expect(s.snapshot['params']['currencyCode'], 'USD');
      expect(s.snapshot.containsKey('results'), isFalse, reason: 'priced in the old currency');
      final restored = s.restoredInto(p)!;
      expect(restored.params.currencyCode, 'USD');
      expect(restored.catalog.pipe('pvc50')!.costPerM, closeTo(pipeBrl * rate, 1e-9));
      expect(restored.entities.whereType<PumpEntity>().single.hourMeterCost, closeTo(100 * rate, 1e-9));
    });

    test('a relabelled currency keeps the numbers and the results', () {
      final p = Project();
      p.scenarios.add(alternative(p, 0, results: DesignResults(timestamp: DateTime(2026))));
      p.setCurrency('USD');
      expect(p.scenarios.single.metrics['capital'], 1000);
      expect(p.scenarios.single.snapshot['params']['currencyCode'], 'USD');
      expect(p.scenarios.single.snapshot.containsKey('results'), isTrue);
    });

    test('every money field of an entity is listed and converted', () {
      // the JSON keys holding a price, read from the entity writers
      final src = File('lib/core/model/entities.dart').readAsStringSync();
      final keys = {for (final m in RegExp(r"'(\w+)': (\w*(?:[Cc]ost|[Pp]rice)\w*)\b").allMatches(src)) m.group(1)!};
      final listed = {for (final s in Project.entityMoneyKeys.values) ...s};
      expect(listed, containsAll(keys), reason: 'a new price field must be converted by Project.scalePrices and listed in entityMoneyKeys');
      final p = Project();
      p.entities.addAll([
        PivotEntity(id: 'pv', center: Pt.zero, machineCost: 10, towerCost: 20),
        ControllerEntity(id: 'c', position: Pt.zero, cost: 30, accessories: {'a': 40}),
        PumpEntity(id: 'pu', position: Pt.zero, hourMeter: true, hourMeterCost: 50),
      ]);
      final before = {for (final e in p.entities) e.id: e.toJson()};
      p.scalePrices(2);
      for (final e in p.entities) {
        final money = Project.entityMoneyKeys[e.type]!;
        final b = before[e.id]!, a = e.toJson();
        for (final k in b.keys) {
          if (b[k] is num) expect(a[k], money.contains(k) ? b[k] * 2 : b[k], reason: '${e.type.name}.$k');
        }
        if (money.contains('acc')) expect((a['acc'] as Map)['a'], 80);
      }
    });
  });
}
