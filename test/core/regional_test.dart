import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/core/model/currency.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/model/regional.dart';
import 'package:opencadirrigation/core/units.dart';

/// Defaults of a new project by region (MOD-19, MOD-20).
void main() {
  test('mains frequency by the region of the locale', () {
    expect(mainsHzForLocale('pt', ['pt-BR']), 60);
    expect(mainsHzForLocale('pt', ['pt-PT']), 50);
    expect(mainsHzForLocale('pt', ['pt-AO', 'en-US']), 50, reason: 'the first tag of the language');
    expect(mainsHzForLocale('en', ['en-US']), 60);
    expect(mainsHzForLocale('en', ['en-GB']), 50);
    expect(mainsHzForLocale('en', ['en-IN']), 50);
    expect(mainsHzForLocale('es', ['es-MX']), 60);
    expect(mainsHzForLocale('es', ['es-AR']), 50);
    expect(mainsHzForLocale('es', ['es-CL']), 50);
    expect(mainsHzForLocale('ar', ['ar-SA']), 60);
    expect(mainsHzForLocale('ar', ['ar-EG']), 50);
    expect(mainsHzForLocale('zh', ['zh-Hans-CN']), 50);
    expect(mainsHzForLocale('ko', ['ko-KR']), 60);
    // no region: the language default
    expect(mainsHzForLocale('pt', const []), 60);
    expect(mainsHzForLocale('hi', const []), 50);
    expect(mainsHzForLocale('de', ['de']), 50);
  });

  test('US customary units in the United States, metric elsewhere', () {
    expect(unitsForLocale('en', ['en-US']).toJson(), Units.us.toJson());
    expect(unitsForLocale('en', ['en-GB']).toJson(), Units.metric.toJson());
    expect(unitsForLocale('en', const []).toJson(), Units.metric.toJson());
    expect(unitsForLocale('es', ['es-US']).toJson(), Units.us.toJson());
  });

  test('feet of water: 1 psi is 2.3067 ft of head', () {
    const ft = Units(pressure: PressureUnit.ftH2O), psi = Units(pressure: PressureUnit.psi);
    expect(ft.pressureFromHead(psi.pressureToHead(1)), closeTo(2.3067, 1e-4));
    expect(ft.pressureToHead(100), closeTo(30.48, 1e-9));
    expect(ft.pressureLabel, 'ft H₂O');
    expect(Units.fromJson(ft.toJson()).pressure, PressureUnit.ftH2O);
  });

  test('the reference exchange rates say when they get old (MOD-30)', () {
    final date = DateTime.parse(exchangeRatesDate);
    expect(exchangeRatesAgeDays(date), 0);
    expect(exchangeRatesStale(date.add(const Duration(days: 60))), isFalse);
    expect(exchangeRatesStale(date.add(const Duration(days: 91))), isTrue);
  });

  test('a symbol of several currencies is told by the region, never guessed (MOD-30)', () {
    expect(currencyCodeForSymbol(r'R$'), 'BRL');
    expect(currencyCodeForSymbol('kr'), isNull, reason: 'Swedish, Norwegian or Danish krone');
    expect(currencyCodeForSymbol('kr', region: 'NO'), 'NOK');
    expect(currencyCodeForSymbol('kr', region: 'dk'), 'DKK');
    expect(currencyCodeForSymbol('kr', region: 'BR'), isNull);
    expect(currencyCodeForSymbol('Br', region: 'ET'), 'ETB');
    // an old file with the symbol only: the currency stays unknown
    final p = DesignParameters.fromJson({'currency': 'kr'});
    expect(p.currencyCode, '');
    expect(p.currency, 'kr');
  });

  test('new projects take the remembered frequency and units', () {
    setPref('mainsHz', '50');
    setPref('units', jsonEncode(Units.us.toJson()));
    try {
      final c = ProjectController()..autosaveEnabled = false;
      c.newProject();
      expect(c.project.params.mainsHz, 50);
      expect(c.project.params.units.toJson(), Units.us.toJson());
    } finally {
      removePref('mainsHz');
      removePref('units');
    }
    final c = ProjectController()..autosaveEnabled = false;
    c.newProject();
    expect(c.project.params.mainsHz, mainsHzForLocale(c.lang, ProjectController.systemLanguageTags()));
  });
}
