import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/model/deliverables.dart';
import 'package:opencadirrigation/core/model/project.dart';

/// The settings of the technical documents (1.6.0): only what differs from
/// a new project is written (a file that never used them does not change),
/// fields of a newer version are kept, a damaged section opens with the
/// defaults and stays in the file, the money converts with the currency,
/// and the BDI follows the formula of Acórdão TCU 2622/2013.
void main() {
  test('a new project writes no deliverables key, and reads back the same', () {
    final p = Project();
    expect(p.deliverables.isDefault, isTrue);
    expect(p.toJson().containsKey('deliverables'), isFalse);
    final back = Project.fromJson(jsonDecode(p.toJsonString()) as Map<String, dynamic>);
    expect(back.deliverables.isDefault, isTrue);
  });

  test('every section round-trips through the project file', () {
    final p = Project();
    final d = p.deliverables;
    d.permit
      ..fixedHoursPerDay = 18
      ..maxHoursPerDay = 20
      ..federalFloor = true
      ..monitoringUnit = 'verdeGrande';
    d.permit.source('e7')
      ..kind = 'groundwater'
      ..waterBody = 'Aquífero Urucuia'
      ..basin = 'São Francisco'
      ..municipality = 'Luís Eduardo Magalhães/BA'
      ..registry = '123456'
      ..permitNumber = 'Portaria 1/2026'
      ..status = 'operation';
    d.memorial
      ..objective = 'Irrigar o café'
      ..notes = 'Sem notas';
    d.om
      ..filterDeltaM = 7
      ..chlorineProductPct = 12
      ..chlorineContinuousMgL = 2
      ..chlorineShockMgL = 20
      ..sparesPct = 3;
    d.budget
      ..centralAdminPct = 4
      ..issPct = 5
      ..cprbPct = 4.5
      ..materialsBdiPct = -1
      ..periodDays = 5
      ..rates['helper'] = 30;
    d.lifeCycle
      ..years = 15
      ..discountPct = 8
      ..energyEscalationPct = 2
      ..waterPrice = 0.05
      ..residual = false
      ..life['bom.tapes'] = 3
      ..maintenance['bom.pumps'] = 4;
    final j = jsonDecode(p.toJsonString()) as Map<String, dynamic>;
    expect(j['deliverables'], isA<Map<String, dynamic>>());
    final back = Project.fromJson(j).deliverables;
    expect(back.permit.fixedHoursPerDay, 18);
    expect(back.permit.maxHoursPerDay, 20);
    expect(back.permit.federalFloor, isTrue);
    expect(back.permit.monitoringUnit, 'verdeGrande');
    final src = back.permit.sources['e7']!;
    expect(src.kind, 'groundwater');
    expect(src.waterBody, 'Aquífero Urucuia');
    expect(src.basin, 'São Francisco');
    expect(src.municipality, 'Luís Eduardo Magalhães/BA');
    expect(src.registry, '123456');
    expect(src.permitNumber, 'Portaria 1/2026');
    expect(src.status, 'operation');
    expect(back.memorial.objective, 'Irrigar o café');
    expect(back.memorial.notes, 'Sem notas');
    expect(back.om.filterDeltaM, 7);
    expect(back.om.chlorineProductPct, 12);
    expect(back.om.chlorineContinuousMgL, 2);
    expect(back.om.chlorineShockMgL, 20);
    expect(back.om.sparesPct, 3);
    expect(back.budget.centralAdminPct, 4);
    expect(back.budget.issPct, 5);
    expect(back.budget.cprbPct, 4.5);
    expect(back.budget.materialsBdiPct, -1);
    expect(back.budget.periodDays, 5);
    expect(back.budget.rates, {'helper': 30});
    expect(back.lifeCycle.years, 15);
    expect(back.lifeCycle.discountPct, 8);
    expect(back.lifeCycle.energyEscalationPct, 2);
    expect(back.lifeCycle.waterPrice, 0.05);
    expect(back.lifeCycle.residual, isFalse);
    expect(back.lifeCycle.life, {'bom.tapes': 3});
    expect(back.lifeCycle.maintenance, {'bom.pumps': 4});
    // only what differs from the defaults
    final perm = (j['deliverables'] as Map)['permit'] as Map;
    expect(perm.containsKey('maxHours'), isTrue);
    final om = (j['deliverables'] as Map)['om'] as Map;
    expect(om.keys.toSet(), {'filterDp', 'clProduct', 'clCont', 'clShock', 'spares'});
  });

  test('a source left at its defaults is not written', () {
    final p = Project();
    p.deliverables.permit.source('e1');
    expect(p.deliverables.isDefault, isTrue);
    expect(p.toJson().containsKey('deliverables'), isFalse);
  });

  test('fields of a newer version are kept, at every level', () {
    final j = Project().toJson()
      ..['deliverables'] = {
        'future': 1,
        'permit': {
          'hours': 12,
          'later': 'x',
          'sources': {
            'e3': {'body': 'Rio Claro', 'gps': true},
          },
        },
        'budget': {
          'ac': 5,
          'tomorrow': [1, 2],
        },
      };
    final p = Project.fromJson(j);
    expect(p.deliverables.permit.fixedHoursPerDay, 12);
    expect(p.deliverables.permit.sources['e3']!.waterBody, 'Rio Claro');
    final again = jsonDecode(p.toJsonString()) as Map<String, dynamic>;
    final d = again['deliverables'] as Map<String, dynamic>;
    expect(d['future'], 1);
    expect((d['permit'] as Map)['later'], 'x');
    expect(((d['permit'] as Map)['sources'] as Map)['e3'], {'body': 'Rio Claro', 'gps': true});
    expect((d['budget'] as Map)['tomorrow'], [1, 2]);
    expect((d['budget'] as Map)['ac'], 5);
  });

  test('a damaged section opens with the defaults and stays in the file', () {
    final j = Project().toJson()
      ..['deliverables'] = {
        'om': 'not an object',
        'memorial': {'objective': 'ok'},
      };
    final p = Project.fromJson(j);
    expect(p.deliverables.om.isDefault, isTrue);
    expect(p.deliverables.memorial.objective, 'ok');
    final again = jsonDecode(p.toJsonString()) as Map<String, dynamic>;
    expect((again['deliverables'] as Map)['om'], 'not an object');
    // a deliverables value that is no object is kept as it was
    final k = Project().toJson()..['deliverables'] = [1, 2, 3];
    final q = Project.fromJson(k);
    expect(q.deliverables.isDefault, isTrue);
    expect(jsonDecode(q.toJsonString())['deliverables'], [1, 2, 3]);
  });

  test('values out of range are brought back into it', () {
    final s = DeliverableSettings.fromJson({
      'permit': {'hours': 30, 'maxHours': 0},
      'budget': {'ac': -5, 'period': 0},
      'lcc': {'years': 0, 'rate': 300, 'water': -1},
    });
    expect(s.permit.fixedHoursPerDay, 24);
    expect(s.permit.maxHoursPerDay, 1);
    expect(s.budget.centralAdminPct, 0);
    expect(s.budget.periodDays, 1);
    expect(s.lifeCycle.years, 1);
    expect(s.lifeCycle.discountPct, 100);
    expect(s.lifeCycle.waterPrice, 0);
  });

  test('the money converts with the currency of the project', () {
    final p = Project();
    p.deliverables.budget.rates['helper'] = 25;
    p.deliverables.lifeCycle.waterPrice = 0.1;
    p.setCurrency('USD', rate: 0.2);
    expect(p.deliverables.budget.rates['helper'], closeTo(5, 1e-9));
    expect(p.deliverables.lifeCycle.waterPrice, closeTo(0.02, 1e-12));
  });

  test('BDI by the formula of Acórdão TCU 2622/2013', () {
    // the worked composition of a state agency for water-supply works:
    // AC 3.50, S+G 0.35, R 1.00, DF 0.70, L 6.50, ISS 3.00, COFINS 3.00,
    // PIS 0.65 → 20.46 %; with the 4.5 % CPRB of Law 13.161/2015 → 26.56 %
    final b = BudgetSettings(centralAdminPct: 3.5, insuranceGuaranteePct: 0.35, riskPct: 1, financialPct: 0.7, profitPct: 6.5, pisPct: 0.65, cofinsPct: 3, issPct: 3);
    expect(b.servicesBdi * 100, closeTo(20.46, 0.005));
    b.cprbPct = 4.5;
    expect(b.servicesBdi * 100, closeTo(26.56, 0.005));
    // the defaults: the first quartile of the ruling for water-supply networks
    final d = BudgetSettings();
    expect(d.servicesBdi, greaterThan(0.2076 - 1e-9));
    expect(d.servicesBdi, lessThan(0.2644));
    expect(d.materialsBdi, closeTo(0.111, 1e-12));
    d.materialsBdiPct = -1;
    expect(d.materialsBdi, d.servicesBdi);
  });
}
