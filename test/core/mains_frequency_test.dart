import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/pump_selection.dart';
import 'package:opencadirrigation/core/io/catalog_io.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/units.dart';

/// Pump curves measured at one mains frequency used on another: a
/// fixed-speed motor turns in proportion (affinity laws), a variable speed
/// drive does not care.
void main() {
  final t = I18n('pt');

  test('the curve frequency and the mains frequency travel through the files', () {
    final cat = Catalog.defaultCatalog();
    final p = cat.pumps.first..ratedHz = 60;
    expect(p.mainsSpeedRatio(50), closeTo(5 / 6, 1e-12));
    expect(p.mainsSpeedRatio(60), 1);
    expect((PumpSpec.fromJson(jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>)).ratedHz, 60);
    expect(cat.pumps[1].toJson().containsKey('hz'), isFalse, reason: 'not stated: no key');
    expect(cat.pumps[1].mainsSpeedRatio(50), 1, reason: 'a curve of unknown frequency is read as it is');
    final csv = CatalogIo.exportCsv(cat, CatalogGroup.pumps);
    expect(CatalogIo.parse(csv, group: CatalogGroup.pumps).catalog.pumps.first.ratedHz, 60);

    final params = DesignParameters();
    expect(params.toJson().containsKey('hz'), isFalse, reason: 'the 60 Hz default writes nothing');
    params.mainsHz = 50;
    expect(DesignParameters.fromJson(jsonDecode(jsonEncode(params.toJson())) as Map<String, dynamic>).mainsHz, 50);
  });

  test('a 60 Hz pump on 50 Hz mains runs at 5/6 of the speed; a variable speed drive is not slowed', () {
    Project example(double hz, {bool vfd = false}) {
      final p = buildExample(ExampleId.orchard, t.call, lang: 'pt');
      final pump = p.entities.whereType<PumpEntity>().first;
      p.catalog.pump(pump.pumpSpecId)!.ratedHz = 60;
      p.params.mainsHz = hz;
      if (vfd) pump.targetPressureM = 30;
      return p;
    }

    double speedOf(Project p) {
      final r = Designer(p, label: (k) => t(k)).designAll();
      final pump = p.entities.whereType<PumpEntity>().first;
      return r.systemFlows.expand((f) => f.devices).firstWhere((d) => d.entityId == pump.id).speedRatio;
    }

    expect(speedOf(example(60)), 1);
    expect(speedOf(example(50)), closeTo(5 / 6, 1e-9));
    expect(speedOf(example(50, vfd: true)), isNot(closeTo(5 / 6, 1e-9)), reason: 'the drive sets its own speed');
  });

  test('pump selection reads the curves at the speed of the mains', () {
    final cat = Catalog.defaultCatalog();
    for (final p in cat.pumps) {
      p.ratedHz = 60;
    }
    final at60 = rankPumps(cat, flow: 18 * m3sPerM3h, head: 32, staticHead: 20, hoursPerYear: 2000, costPerKwh: 0.75);
    final at50 = rankPumps(cat, flow: 18 * m3sPerM3h, head: 32, staticHead: 20, hoursPerYear: 2000, costPerKwh: 0.75, mainsHz: 50);
    final a = at60.firstWhere((c) => c.parallelCount == 1);
    final b = at50.firstWhere((c) => c.spec.id == a.spec.id && c.parallelCount == 1);
    // H(Q) at speed n: n²·H₀(Q/n); at the same flow the slower pump gives less
    expect(b.headAtDuty, lessThan(a.headAtDuty));
    expect(b.headAtDuty, closeTo(a.spec.curve.withSpeed(5 / 6).head(18 * m3sPerM3h), 1e-9));
  });
}
