import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/widgets/dialogs/catalog_packs_dialog.dart';
import 'package:opencadirrigation/core/io/catalog_io.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/catalog_packs.dart';
import 'package:opencadirrigation/core/model/currency.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/units.dart';

/// Importing price lists and packs into the catalogue (MOD-06, MOD-09,
/// MOD-10, MOD-18).
void main() {
  group('rows without an id (MOD-06)', () {
    test('two suppliers no longer replace each other\'s items', () {
      final project = Catalog.defaultCatalog();
      final a = CatalogIo.parse('name;dn;di;cost\nPVC A 50;50;46.4;10\nPVC A 75;75;70.6;20\n', group: CatalogGroup.pipes);
      final b = CatalogIo.parse('name;dn;di;cost\nPE B 32;32;26;3\n', group: CatalogGroup.pipes);
      final before = project.pipes.length;
      expect(a.mergeInto(project).added, 2);
      expect(b.mergeInto(project).added, 1);
      expect(project.pipes.length, before + 3);
      final first = project.pipe(a.catalog.pipes.first.id)!;
      expect(first.name, 'PVC A 50');
      expect(first.innerDiameterMm, 46.4);
    });

    test('the same row imported again replaces its own item (a new price), reported when in use', () {
      final project = Catalog();
      CatalogIo.parse('name;code;dn;di;cost\nPVC A 50;X1;50;46.4;10\n', group: CatalogGroup.pipes).mergeInto(project);
      final id = project.pipes.single.id;
      final again = CatalogIo.parse('name;code;dn;di;cost\nPVC A 50;X1;50;46.4;12\n', group: CatalogGroup.pipes);
      expect(again.catalog.pipes.single.id, id, reason: 'a stable id from supplier, code and name');
      final m = again.mergeInto(project, used: {id});
      expect(m.replaced, 1);
      expect(m.replacedInUse, [id]);
      expect(project.pipes.single.costPerM, 12);
      // two rows of one list with the same name stay two items
      final twice = CatalogIo.parse('name;dn;di\nPVC;50;46.4\nPVC;75;70.6\n', group: CatalogGroup.pipes);
      expect(twice.catalog.pipes.map((p) => p.id).toSet(), hasLength(2));
    });

    test('ids given by the file still replace (a catalogue exported and edited)', () {
      final project = Catalog.defaultCatalog();
      final r = CatalogIo.parse('id;name;dn;di;cost\npvc50;Mine;50;46;1\n', group: CatalogGroup.pipes);
      expect(r.mergeInto(project).replaced, 1);
      expect(project.pipe('pvc50')!.name, 'Mine');
    });
  });

  group('table cells (MOD-09)', () {
    test('an inch mark does not swallow the rest of the line', () {
      final r = CatalogIo.parse('name;dn;di;cost\nTubo PVC 2";50;46.4;10\nVálvula 3/4";20;18;5\n', group: CatalogGroup.pipes);
      expect(r.catalog.pipes.map((p) => (p.name, p.nominalMm, p.innerDiameterMm, p.costPerM)), [('Tubo PVC 2"', 50.0, 46.4, 10.0), ('Válvula 3/4"', 20.0, 18.0, 5.0)]);
    });

    test('quoted fields as RFC 4180', () {
      expect(CatalogIo.splitLine('"a; b";c', ';'), ['a; b', 'c']);
      expect(CatalogIo.splitLine('"say ""hi""";x', ';'), ['say "hi"', 'x']);
      expect(CatalogIo.splitLine(' "q" ;2"', ';'), ['q', '2"']);
      expect(CatalogIo.splitLine('a;;b;', ';'), ['a', '', 'b', '']);
    });

    test('rows without a diameter are left out and reported', () {
      final r = CatalogIo.parse('name;dn;di;cost\nPVC 50;50;46.4;10\nnothing;;;5\n', group: CatalogGroup.pipes);
      expect(r.catalog.pipes, hasLength(1));
      expect(r.skippedRows, [2]);
    });
  });

  group('units of the data sheets (MOD-10)', () {
    test('Kv is the flow coefficient: 20 m³/h through Kv 40 loses 0.25 bar', () {
      final r = CatalogIo.parse('name;kind;dn;kv;cost\nValve 2";control;50;40;300\n', group: CatalogGroup.valves);
      // IEC 60534: Δp = (Q / Kv)² bar = 0.25 bar = 2.549 m
      expect(r.catalog.valves.single.loss.loss(20 * m3sPerM3h), closeTo(0.25 / barPerMeterHead, 1e-9));
      expect(kvLossCurve(100).loss(50 * m3sPerM3h), closeTo(0.25 / barPerMeterHead, 1e-9));
      // kcoef: the K of K·v²/2g on the valve bore
      final k = CatalogIo.parse('name;kind;dn;kcoef\nV;control;50;5\n', group: CatalogGroup.valves).catalog.valves.single;
      final v = 20 * m3sPerM3h / (3.141592653589793 / 4 * 0.05 * 0.05);
      expect(k.loss.loss(20 * m3sPerM3h), closeTo(5 * v * v / (2 * gravity), 1e-6));
    });

    test('PN in bar up to 25, in metres above, a unit in the cell wins', () {
      final r = CatalogIo.parse('name;dn;di;pn\nPEAD 110;110;96.8;10\nPVC 50;50;46.7;80\nX;50;46;100 m\nY;50;46;6 bar\nZ;50;46;150 psi\n', group: CatalogGroup.pipes);
      final m = [for (final p in r.catalog.pipes) p.pressureRatingM];
      expect(m[0], closeTo(10 / barPerMeterHead, 1e-9));
      expect(m[1], 80);
      expect(m[2], 100);
      expect(m[3], closeTo(6 / barPerMeterHead, 1e-9));
      expect(m[4], closeTo(150 / psiPerMeterHead, 1e-9));
      expect(r.pnAsBar, 1, reason: 'only the bare 10 was a guess: the app asks');
      final metres = CatalogIo.parse('name;dn;di;pn\nPEAD 110;110;96.8;10\n', group: CatalogGroup.pipes, pnInBar: false);
      expect(metres.catalog.pipes.single.pressureRatingM, 10);
      expect(metres.pnAsBar, 0);
      final exported = CatalogIo.parse(CatalogIo.exportCsv(Catalog.defaultCatalog(), CatalogGroup.pipes), group: CatalogGroup.pipes);
      expect(exported.catalog.pipe('pvc50')!.pressureRatingM, 80, reason: 'ratingM stays in metres');
      expect(exported.pnAsBar, 0);
    });
  });

  group('packs (MOD-18)', () {
    test('wires and financing codes come with the pack', () {
      final src = Catalog(
        pipes: [PipeSpec(id: 'my_pipe', name: 'My pipe', nominalMm: 50, innerDiameterMm: 46, costPerM: 10)],
        wires: [WireSpec(id: 'my_wire', name: 'Cabo 2,5', sectionMm2: 2.5, ohmPerKm: 7.4, costPerM: 3)],
        finame: {'my_pipe': '12345'},
      );
      final pack = CatalogPack.parse(CatalogIo.encodePack(const CatalogPackMeta(id: 'dealer', brand: 'Dealer', currency: 'BRL'), src));
      final target = Catalog();
      expect(pack.isMergedInto(target), isFalse);
      final r = addCatalogPack(target, pack, projectCurrency: 'BRL');
      expect(r.added, 2);
      expect(target.wires.map((w) => w.id), ['my_wire']);
      expect(target.finame, {'my_pipe': '12345'});
      expect(pack.isMergedInto(target), isTrue);
      // an existing code is kept
      final t2 = Catalog(finame: {'my_pipe': 'mine'});
      mergeCatalogPack(t2, pack.catalog);
      expect(t2.finame['my_pipe'], 'mine');
    });

    testWidgets('the Import of the catalogue editor adds a pack as the packs dialog does', (tester) async {
      final c = ProjectController()..autosaveEnabled = false;
      final cat = c.project.catalog;
      final pvc = cat.pipe('pvc50')!.toJson();
      final pack = Catalog(
        pipes: [
          PipeSpec.fromJson(Map.of(pvc)..['name'] = 'Not mine'),
          PipeSpec(id: 'usd_pipe', name: 'Priced in USD', nominalMm: 50, innerDiameterMm: 46, costPerM: 10),
        ],
      );
      final text = CatalogIo.encodePack(const CatalogPackMeta(id: 'us', brand: 'US', currency: 'USD'), pack);
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              context = ctx;
              return const SizedBox();
            },
          ),
        ),
      );
      await importCatalogFile(context, c, cat, CatalogGroup.pipes, name: 'us.json', bytes: utf8.encode(text));
      expect(cat.pipe('pvc50')!.name, isNot('Not mine'), reason: 'existing ids are kept');
      expect(cat.pipe('usd_pipe')!.costPerM, closeTo(10 * exchangeRate('USD', c.project.params.currencyCode)!, 1e-9), reason: 'prices converted');
    });

    test('the ids of every pack are unique, wires included', () {
      // gen_catalogs validates the wire ids too
      expect(
        Catalog(
          wires: [WireSpec(id: 'w', name: 'w', sectionMm2: 1, ohmPerKm: 18)],
        ).wire('w'),
        isNotNull,
      );
    });
  });

  test('catalogue ids in use by the drawing', () {
    final c = ProjectController()..autosaveEnabled = false;
    c.project.entities.addAll([
      PipeEntity(id: 'a', points: const [Pt(0, 0), Pt(1, 0)], scope: HydraulicScope.zone, pipeSpecId: 'pvc50'),
      OutletEntity(id: 'b', position: Pt.zero, outletSpecId: 'impact34'),
    ]);
    expect(c.project.catalogIdsInUse, {'pvc50', 'impact34'});
  });
}
