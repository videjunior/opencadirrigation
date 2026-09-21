import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/io/catalog_io.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/catalog_packs.dart';
import 'package:opencadirrigation/core/model/currency.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/project.dart';

/// Project currencies: defaults by language and region, reference exchange
/// rates, conversion of every price, packs priced in another currency and the
/// economic sizing with pipes that have no price.
void main() {
  group('currency table', () {
    test('every interface language has a default currency with a symbol and a rate', () {
      for (final l in supportedLanguages) {
        final code = currencyForLanguage(l);
        expect(currencyByCode(code), isNotNull, reason: '$l → $code');
        expect(unitsPerBrl[code], isNotNull, reason: '$l → $code');
      }
      expect(currencyForLanguage('pt'), 'BRL');
      expect(currencyForLanguage('ja'), 'JPY');
    });

    test('every currency and region has a reference rate; codes are unique', () {
      expect(currencies.map((c) => c.code).toSet().length, currencies.length);
      for (final c in currencies) {
        expect(unitsPerBrl[c.code], isNotNull, reason: c.code);
        expect(unitsPerBrl[c.code]! > 0, isTrue, reason: c.code);
      }
      for (final e in regionCurrencies.entries) {
        expect(currencyByCode(e.value), isNotNull, reason: '${e.key} → ${e.value}');
      }
      expect(exchangeRatesDate, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    });

    test('the region of a locale of the interface language picks the currency', () {
      expect(currencyForLocale('pt', ['pt-BR']), 'BRL');
      expect(currencyForLocale('pt', ['pt-PT', 'en-US']), 'EUR');
      expect(currencyForLocale('en', ['en-IN', 'en-US']), 'INR');
      expect(currencyForLocale('de', ['en-US', 'de-CH']), 'CHF');
      expect(currencyForLocale('zh', ['zh-Hans-CN']), 'CNY');
      expect(currencyForLocale('es', ['es_AR']), 'ARS');
      // a locale of another language does not count; no region → language default
      expect(currencyForLocale('en', ['pt-BR']), 'USD');
      expect(currencyForLocale('es', const []), 'MXN');
      expect(currencyForLocale('fr', ['fr']), 'EUR');
    });

    test('rates convert both ways; symbols of older files map to codes', () {
      expect(exchangeRate('BRL', 'USD'), unitsPerBrl['USD']);
      expect(exchangeRate('EUR', 'EUR'), 1);
      expect(exchangeRate('USD', 'EUR')! * exchangeRate('EUR', 'USD')!, closeTo(1, 1e-12));
      expect(exchangeRate('BRL', 'XYZ'), isNull);
      expect(exchangeRate('', 'BRL'), isNull);
      expect(currencyCodeForSymbol(r'R$'), 'BRL');
      expect(currencyCodeForSymbol('€'), 'EUR');
      expect(currencyCodeForSymbol('usd'), 'USD');
      expect(currencyCodeForSymbol(r'$'), 'USD');
      expect(currencyCodeForSymbol('?!'), isNull);
      expect(fmtRate(0.169492), '0.1695');
      expect(fmtRate(30.6062), '30.61');
      expect(fmtRate(267526), '267526');
    });
  });

  group('project prices', () {
    test('the currency code survives JSON; older files get it from the symbol', () {
      final p = DesignParameters()..currencyCode = 'EUR'..currency = '€';
      expect(DesignParameters.fromJson(p.toJson()).currencyCode, 'EUR');
      final old = DesignParameters().toJson()..remove('currencyCode');
      expect(DesignParameters.fromJson(old).currencyCode, 'BRL');
      expect(DesignParameters.fromJson({...old, 'currency': '€'}).currencyCode, 'EUR');
      expect(DesignParameters.fromJson({...old, 'currency': 'Kz?'}).currencyCode, '');
    });

    test('the built-in catalogue is priced in reais and converted with the reference rate', () {
      final brl = Catalog.defaultCatalog(lang: 'en');
      final usd = Catalog.defaultCatalog(lang: 'en', currency: 'USD');
      final rate = exchangeRate('BRL', 'USD')!;
      for (var i = 0; i < brl.pipes.length; i++) {
        expect(usd.pipes[i].costPerM, closeTo(brl.pipes[i].costPerM * rate, 1e-9));
      }
      for (var i = 0; i < brl.fittings.length; i++) {
        expect(usd.fittings[i].cost, closeTo(brl.fittings[i].cost * rate, 1e-9));
      }
      expect(usd.pumps.first.cost, closeTo(brl.pumps.first.cost * rate, 1e-9));
      // an unknown code keeps the reference prices
      expect(Catalog.defaultCatalog(currency: '').pipes.first.costPerM, brl.pipes.first.costPerM);
      final fit = Catalog.defaultFittings(brl.pipes, currency: 'JPY');
      expect(fit.first.cost, closeTo(brl.fittings.first.cost * exchangeRate('BRL', 'JPY')!, 1e-9));
    });

    test('setCurrency converts catalogue, energy tariff and pivot costs', () {
      final p = buildExample(ExampleId.pivot, I18n('pt').call, lang: 'pt');
      expect(p.params.currencyCode, 'BRL');
      final pv = p.entities.whereType<PivotEntity>().first;
      final machine = pv.machineCost, kwh = p.params.powerCostPerKwh, pipe = p.catalog.pipes.first.costPerM;
      p.setCurrency('EUR', rate: 0.2);
      expect(p.params.currencyCode, 'EUR');
      expect(p.params.currency, '€');
      expect(pv.machineCost, closeTo(machine * 0.2, 1e-6));
      expect(p.params.powerCostPerKwh, closeTo(kwh * 0.2, 1e-12));
      expect(p.catalog.pipes.first.costPerM, closeTo(pipe * 0.2, 1e-12));
      // without a rate only the currency changes
      p.setCurrency('USD', symbol: r'$');
      expect(p.params.currency, r'$');
      expect(p.catalog.pipes.first.costPerM, closeTo(pipe * 0.2, 1e-12));
    });

    test('examples are written in the currency of their language and size the same pipes', () {
      final t = I18n('en').call;
      final pt = buildExample(ExampleId.orchard, t, lang: 'pt');
      final ja = buildExample(ExampleId.orchard, t, lang: 'ja');
      expect(pt.params.currencyCode, 'BRL');
      expect(ja.params.currencyCode, 'JPY');
      expect(ja.params.currency, '¥');
      final rate = exchangeRate('BRL', 'JPY')!;
      expect(ja.params.powerCostPerKwh, closeTo(pt.params.powerCostPerKwh * rate, 1e-9));
      final rPt = Designer(pt, label: t).designAll();
      final rJa = Designer(ja, label: t).designAll();
      Map<String, String?> sizes(Project p) => {for (final e in p.entities.whereType<PipeEntity>()) e.id: e.pipeSpecId};
      expect(sizes(ja), sizes(pt), reason: 'prices scaled by one factor must not change the economic sizing');
      expect(rJa.capitalCost, closeTo(rPt.capitalCost * rate, rPt.capitalCost * rate * 1e-6));
    });
  });

  group('packs and unpriced items', () {
    Catalog priced() => Catalog(pipes: [PipeSpec(id: 'x_pvc50', name: 'X 50', nominalMm: 50, innerDiameterMm: 46, costPerM: 10)]);

    test('a pack priced in another currency is converted; the pack itself is untouched', () {
      final target = Catalog.defaultCatalog();
      final pack = CatalogPack(meta: const CatalogPackMeta(id: 'x', brand: 'X', currency: 'USD'), catalog: priced());
      final r = addCatalogPack(target, pack, projectCurrency: 'BRL');
      expect(r.added, 1);
      expect(r.converted, isTrue);
      expect(target.pipe('x_pvc50')!.costPerM, closeTo(10 * exchangeRate('USD', 'BRL')!, 1e-9));
      expect(pack.catalog.pipes.first.costPerM, 10);
      expect(identical(target.pipe('x_pvc50'), pack.catalog.pipes.first), isFalse);
    });

    test('a pack without currency keeps its prices and says so; an unpriced pack needs no rate', () {
      final a = Catalog.defaultCatalog();
      final r = addCatalogPack(a, CatalogPack(meta: const CatalogPackMeta(id: 'x', brand: 'X'), catalog: priced()), projectCurrency: 'EUR');
      expect(r.unknownCurrency, isTrue);
      expect(a.pipe('x_pvc50')!.costPerM, 10);
      final free = priced()..pipes.first.costPerM = 0;
      final r2 = addCatalogPack(Catalog.defaultCatalog(), CatalogPack(meta: const CatalogPackMeta(id: 'x', brand: 'X'), catalog: free), projectCurrency: 'EUR');
      expect(r2.unknownCurrency, isFalse);
      expect(r2.converted, isFalse);
      // the pack format carries the currency and the source documents
      const meta = CatalogPackMeta(id: 'x', brand: 'X', currency: 'USD', sources: ['sheet A', 'https://x.example/b.pdf']);
      final back = CatalogIo.parsePack(CatalogIo.encodePack(meta, priced())).meta;
      expect(back.currency, 'USD');
      expect(back.sources, meta.sources);
      expect(CatalogIndexEntry(meta: meta, file: 'x.oci.cat').toJson().containsKey('sources'), isFalse);
    });

    test('pipes without a price get a sizing cost proportional to the wall, calibrated on priced pipes', () {
      final c = Catalog.defaultCatalog();
      final ref = c.pipe('pvc100')!;
      c.pipes.add(PipeSpec(id: 'u100', name: 'unpriced 100', nominalMm: 100, innerDiameterMm: ref.innerDiameterMm, wallThicknessMm: ref.wallThicknessMm));
      c.pipes.add(PipeSpec(id: 'u150', name: 'unpriced 150', nominalMm: 150, innerDiameterMm: 144, wallThicknessMm: 3.8));
      final costs = c.sizingPipeCosts();
      expect(costs['pvc100'], ref.costPerM);
      expect(costs['u100']! > 0, isTrue);
      expect(costs['u150']!, greaterThan(costs['u100']!));
      // same wall as a priced PVC pipe: the estimate is of the same order
      expect(costs['u100']! / ref.costPerM, inInclusiveRange(0.3, 3));
      // nothing priced: still ordered by size
      final bare = Catalog(pipes: [PipeSpec(id: 'a', name: 'a', nominalMm: 50, innerDiameterMm: 46), PipeSpec(id: 'b', name: 'b', nominalMm: 75, innerDiameterMm: 70)]);
      final bc = bare.sizingPipeCosts();
      expect(bc['b']!, greaterThan(bc['a']!));
    });

    test('a design with catalogue items without a price says so', () {
      final t = I18n('pt').call;
      final p = buildExample(ExampleId.orchard, t, lang: 'pt');
      for (final o in p.catalog.outlets) {
        o.cost = 0;
      }
      final r = Designer(p, label: t).designAll();
      expect(r.messages.any((m) => m.startsWith('bom_unpriced:')), isTrue);
      final clean = Designer(buildExample(ExampleId.orchard, t, lang: 'pt'), label: t).designAll();
      expect(clean.messages.any((m) => m.startsWith('bom_unpriced')), isFalse);
    });
  });
}
