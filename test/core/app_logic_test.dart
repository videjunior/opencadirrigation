import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart' show PageRouteBuilder, SizedBox;
import 'package:flutter/widgets.dart' show Route;
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/app/i18n_assets.dart';
import 'package:opencadirrigation/app/io/app_keys.dart';
import 'package:opencadirrigation/app/io/file_io.dart';
import 'package:opencadirrigation/app/io/links.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/keys/hotkeys.dart';
import 'package:opencadirrigation/app/shortcuts.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_job.dart';
import 'package:opencadirrigation/app/state/design_runner_thread.dart' as thread;
import 'package:opencadirrigation/app/state/workspace.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/core/design/advisor.dart';
import 'package:opencadirrigation/core/design/auto_fix.dart';
import 'package:opencadirrigation/core/io/dem_online.dart';
import 'package:opencadirrigation/core/io/geo.dart';
import 'package:opencadirrigation/core/io/project_export.dart' show GeoReferenceMissing;
import 'package:opencadirrigation/core/model/currency.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';

/// A runner whose design always fails.
class FailingRunner implements DesignRunner {
  @override
  Future<DesignResponse> run(DesignRequest request, {void Function(DesignProgress progress)? onProgress, void Function(String mode)? onMode, Future<void> Function()? yieldControl}) async => throw DesignJobException('boom');

  @override
  void dispose() {}
}

/// App logic without widgets: command aliases, the controller features the
/// widget tests do not reach, the actions that need no dialog, the route
/// observer, the design runner fallback, desktop files and language assets.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProjectController fresh({LocalProjectStore? store}) {
    setPref('lang', 'pt');
    final c = ProjectController(store: store)..autosaveEnabled = false;
    c.newProject();
    c.designRunner = InThreadDesignRunner();
    return c;
  }

  group('command aliases', () {
    test('every action has a translated label and every target is reachable', () {
      final en = I18n('en'), pt = I18n('pt');
      for (final a in CadAction.values) {
        final key = actionLabelKey(a);
        expect(en.has(key), isTrue, reason: '${a.name} → $key');
        expect(pt(key), isNot(key));
        expect(commandAliases.values, contains(a), reason: 'no alias runs ${a.name}');
      }
      for (final v in commandAliases.values) {
        expect(v is ToolId || v is CadAction, isTrue);
      }
      expect(commandAliases.keys.every((k) => k == k.toUpperCase() && k.isNotEmpty), isTrue, reason: 'aliases are typed in upper case');
      final drawing = ToolId.values.where((t) => t != ToolId.select);
      for (final t in drawing) {
        expect(aliasOf(t), isNotNull, reason: '${t.name} has no alias');
      }
      expect(aliasOf(ToolId.line), 'L');
      expect(aliasOf(ToolId.zonePipe), 'ZP');
      expect(aliasOf(ToolId.select), isNull);
    });

    test('labels with the alias and the typed-command hint', () {
      final t = I18n('pt');
      expect(toolLabel(t, ToolId.line), '${t('tool.line')}  [L]');
      expect(toolLabel(t, ToolId.select), '${t('tool.select')}  [Esc]');
      expect(commandTargetLabel(t, 'PL'), '  → ${t('tool.polyline')} ⏎');
      expect(commandTargetLabel(t, 'ZE'), '  → ${t('view.zoomAll')} ⏎');
      expect(commandTargetLabel(t, 'FIX'), '  → ${t('adv.fixAll')} ⏎');
      expect(commandTargetLabel(t, 'QQQ'), '');
    });
  });

  test('tutorial navigation: start, next, back, jump, the interactive count and the end', () {
    final steps = buildTutorialSteps('pt');
    final tut = TutorialController();
    var changes = 0;
    tut.addListener(() => changes++);
    tut.start(steps, startAt: 999);
    expect(tut.active, isTrue);
    expect(tut.index, steps.length - 1, reason: 'a start past the end is clamped');
    expect(tut.isLast, isTrue);
    tut.goTo(-5);
    expect(tut.index, 0);
    tut.prev();
    expect(tut.index, 0, reason: 'no step before the first');
    tut.next();
    expect(tut.current.id, steps[1].id);
    tut.goTo(3);
    expect(tut.current.id, steps[3].id);
    expect(tut.interactiveCount, steps.where((s) => s.interactive).length);
    expect(tut.interactiveCount, greaterThan(35));
    expect(changes, greaterThanOrEqualTo(5));
    TutorialController.reset();
    tut.goTo(steps.length - 1);
    tut.next();
    expect(tut.active, isFalse, reason: 'next on the last step finishes');
    expect(TutorialController.isDone, isTrue);
  });

  test('readable descriptions of key events and design errors', () {
    expect(const HotkeyEvent('s', ctrl: true).toString(), 'HotkeyEvent(down s ctrl)');
    expect(const HotkeyEvent('F5', down: false, shift: true, alt: true, meta: true).toString(), 'HotkeyEvent(up F5 meta shift alt)');
    expect(DesignJobException('Not an OpenCADIrrigation project', 'stack').toString(), 'Not an OpenCADIrrigation project');
  });

  test('without workers or isolates the design runs on the UI thread', () {
    expect(thread.createDesignRunner(), isA<InThreadDesignRunner>());
  });

  test('the route observer tracks the top route through push, remove, replace and pop', () {
    Route<void> route() => PageRouteBuilder<void>(pageBuilder: (_, _, _) => const SizedBox());
    final o = AppRouteObserver();
    final a = route(), b = route(), c = route();
    expect(o.top, isNull);
    o.didPush(a, null);
    o.didPush(b, a);
    expect(o.top, same(b));
    o.didRemove(b, a);
    expect(o.top, same(a));
    o.didReplace(newRoute: c, oldRoute: a);
    expect(o.top, same(c));
    o.didPop(c, null);
    expect(o.top, isNull);
    openExternalLink('https://opencadirrigation.com'); // a no-op outside the browser
  });

  group('desktop files without a window', () {
    test('open asks nothing and returns null; save writes where it is told', () async {
      expect(await openTextFile(accept: '.json'), isNull);
      expect(await openBinaryFile(accept: '.dxf'), isNull);
      final dir = Directory.systemTemp.createTempSync('oci_files');
      try {
        final txt = '${dir.path}/a.txt';
        await saveTextFile(txt, 'olá');
        expect(File(txt).readAsStringSync(), 'olá');
        final bin = '${dir.path}/b.bin';
        await saveBinaryFile(bin, Uint8List.fromList([1, 2, 255]));
        expect(File(bin).readAsBytesSync(), [1, 2, 255]);
      } finally {
        dir.deleteSync(recursive: true);
      }
    });
  });

  group('language assets', () {
    test('packs load from the asset bundle; fonts need no warm-up off the web', () async {
      final saved = languageLoader;
      try {
        useAssetLanguageLoader();
        expect(languageLoader, same(loadLanguageAsset));
        final de = await loadLanguageAsset('de');
        expect((de['strings'] as Map)['menu.file'], 'Datei');
        expect(de['language'], 'de');
        await warmUpFonts('ja');
        await warmUpFonts('de');
        expect(fallbackFontLanguages, containsAll(['zh', 'ja', 'ar']));
        expect(fallbackFontLanguages, isNot(contains('de')));
      } finally {
        languageLoader = saved;
      }
    });
  });

  group('controller', () {
    test('vertex removal, toggled selection and the edit counter', () {
      final c = fresh();
      c.addEntity(PolylineEntity(id: 'p', points: [Pt.zero, const Pt(10, 0), const Pt(10, 10)]));
      final seq = c.editSeq;
      c.removeVertex('p', 1);
      expect((c.project.byId('p') as PolylineEntity).points, [Pt.zero, const Pt(10, 10)]);
      expect(c.editSeq, greaterThan(seq));
      c.removeVertex('p', 0);
      expect((c.project.byId('p') as PolylineEntity).points.length, 2, reason: 'two vertices are the minimum');
      c.removeVertex('nope', 0);
      c.undo();
      expect((c.project.byId('p') as PolylineEntity).points.length, 3);
      c.setLayerLocked(Layers.drawing, true);
      c.removeVertex('p', 1);
      expect((c.project.byId('p') as PolylineEntity).points.length, 3, reason: 'a locked layer is not edited');
      c.setLayerLocked(Layers.drawing, false);
      c.toggleSelect('p');
      expect(c.selection, {'p'});
      c.toggleSelect('p');
      expect(c.selection, isEmpty);
    });

    test('connectivity check, design without valves and a failing design', () async {
      final c = fresh();
      loadExampleAction(c);
      c.checkConnectivity();
      expect(c.lastMessage, 'Todos os itens estão conectados');
      expect(c.unconnected, isEmpty);
      final pump = c.project.entities.whereType<PumpEntity>().first;
      pump.position = pump.position + const Pt(0, 30);
      c.checkConnectivity();
      expect(c.unconnected, contains(pump.id));
      expect(c.lastMessage, '${c.unconnected.length} itens não conectados (marcados em vermelho)');
      expect(c.eventCount('check'), 2);
      final empty = fresh();
      await empty.runDesign();
      expect(empty.lastMessage, 'Nenhuma válvula de controle no projeto');
      expect(empty.results, isNull);
      final failing = fresh();
      loadExampleAction(failing);
      failing.designRunner = FailingRunner();
      await failing.runDesign();
      expect(failing.results, isNull);
      expect(failing.busy, isFalse);
      expect(failing.lastMessage, contains('boom'));
    });

    test('a correction that fails leaves no undo step; one that works redesigns', () async {
      final c = fresh();
      loadExampleAction(c);
      await c.runDesign();
      final pump = c.project.entities.whereType<PumpEntity>().first;
      final history = c.historyEntries.length;
      pump.position = pump.position + const Pt(0, 40);
      final far = Advice(code: 'unconnected', raw: 'unconnected', level: AdviceLevel.error, entityIds: [pump.id]);
      final res = await c.applyAdviceFix(far, FixKind.connect);
      expect(res!.ok, isFalse);
      expect(c.historyEntries.length, history, reason: 'the failed attempt is not an undo step');
      expect(c.lastMessage, startsWith('Não foi possível corrigir'));
      pump.position = pump.position + const Pt(0, -39.4);
      final near = c.advice.firstWhere((a) => a.code == 'unconnected' && a.entityIds.contains(pump.id));
      final ok = await c.applyAdviceFix(near, near.fixes.first);
      expect(ok!.ok, isTrue);
      expect(c.results, isNotNull, reason: 'with results on screen the design runs again');
      expect(c.historyEntries.length, history + 1);
    });

    test('an optimisation that gains nothing restores the project', () async {
      final c = fresh();
      loadExampleAction(c);
      await c.runDesign();
      await c.optimizeDesign(const OptimizeOptions());
      final json = c.project.toJsonString();
      final base = c.results;
      final history = c.historyEntries.length;
      final report = await c.optimizeDesign(const OptimizeOptions(choosePumps: false, resizeValves: false));
      expect(report, isNotNull);
      if (!report!.improved) {
        expect(c.lastMessage, I18n('pt')('opt.reverted'));
        expect(c.project.toJsonString(), json);
        expect(identical(c.results, base), isTrue);
        expect(c.historyEntries.length, history, reason: 'no undo step for nothing');
      } else {
        expect(c.lastMessage, I18n('pt')('opt.kept'));
      }
      expect(c.assistantProgress, '');
    });

    test('feed envelope of a tape and the messages of the action', () {
      final c = fresh();
      final tape = TapeEntity(id: 't', points: [Pt.zero, const Pt(80, 0)], tapeSpecId: c.project.catalog.tapes.first.id, inletHeadM: 10);
      c.addEntity(tape);
      feedEnvelopeAction(c);
      expect(c.lastMessage, 'Selecione uma ou mais laterais (sprayline ou fita)');
      c.select(['t']);
      feedEnvelopeAction(c);
      expect(c.lastMessage, contains('1 laterais'));
      final env = c.feedEnvelope['t']!;
      expect(env.length, 21);
      expect(env.first.variation, greaterThan(env[10].variation), reason: 'centre feed is best on flat ground');
    });

    test('online DEM through the replaceable loader: no-data points and replacement', () async {
      final saved = ProjectController.demUrlLoader;
      final c = fresh();
      c.addEntity(LineEntity(id: 'l', a: Pt.zero, b: const Pt(200, 100)));
      c.project.meta.georef = GeoReference.fromLatLonOrigin(-22.9, -47.1);
      var calls = 0;
      ProjectController.demUrlLoader = (url) async {
        calls++;
        final lats = Uri.parse(url).queryParameters['latitude']!.split(',');
        return jsonEncode({'elevation': [for (var i = 0; i < lats.length; i++) i % 5 == 0 ? null : 600 + i * 0.1]});
      };
      try {
        final r = await c.importOnlineDem(DemSource.openMeteo, spacing: 25);
        expect(calls, greaterThan(0));
        expect(r.noData, greaterThan(0));
        final dem = c.project.entities.whereType<SpotHeightEntity>().where((e) => e.isDem).length;
        expect(dem, r.count);
        expect(r.count + r.noData, demGrid(c.project.bounds, 25, c.project.meta.georef!).length);
        expect(c.project.findLayer(Layers.dem), isNotNull);
        expect(r.range.$1, greaterThanOrEqualTo(600));
        await c.importOnlineDem(DemSource.openMeteo, spacing: 50);
        expect(c.project.entities.whereType<SpotHeightEntity>().where((e) => e.isDem).length, lessThan(dem), reason: 'the previous download is replaced');
        c.project.meta.georef = null;
        await expectLater(c.importOnlineDem(DemSource.openMeteo), throwsA(isA<GeoReferenceMissing>()));
      } finally {
        ProjectController.demUrlLoader = saved;
      }
    });

    test('currency: saved choice, project conversion in one undo step', () {
      final c = fresh();
      setPref('currency', 'EUR');
      expect(c.defaultCurrency(), 'EUR');
      setPref('currency', 'XYZ');
      expect(c.defaultCurrency(), isNot('XYZ'), reason: 'an unknown code is ignored');
      removePref('currency');
      c.project.setCurrency('BRL', symbol: r'R$');
      final price = c.project.catalog.pipes.first.costPerM;
      final history = c.historyEntries.length;
      c.setProjectCurrency('USD', rate: exchangeRate('BRL', 'USD'));
      expect(c.project.params.currencyCode, 'USD');
      expect(c.project.catalog.pipes.first.costPerM, closeTo(price * exchangeRate('BRL', 'USD')!, 1e-9));
      expect(c.historyEntries.length, history + 1);
      c.undo();
      expect(c.project.params.currencyCode, 'BRL');
      expect(c.project.catalog.pipes.first.costPerM, closeTo(price, 1e-12));
    });

    test('broken results in a file are dropped; errors are described', () {
      final c = fresh();
      loadExampleAction(c);
      final j = jsonDecode(c.saveJson()) as Map<String, dynamic>;
      j['results'] = {'zones': 'not a map'};
      c.loadJson(jsonEncode(j));
      expect(c.results, isNull);
      expect(c.project.entities, isNotEmpty);
      expect(c.describeError(const FormatException('kmz_no_kml')), 'KMZ sem arquivo .kml');
      expect(c.describeError(const FormatException('shp_bad_header')), 'Arquivo SHP inválido');
      expect(c.describeError(const FormatException('something odd')), 'something odd');
      expect(c.describeError(StateError('x')), 'Bad state: x');
    });

    test('DXF polylines with an elevation become contours, scaled to metres', () {
      final c = fresh();
      const dxf = '0\nSECTION\n2\nHEADER\n9\n\$INSUNITS\n70\n4\n0\nENDSEC\n0\nSECTION\n2\nENTITIES\n'
          '0\nLWPOLYLINE\n8\nOBRA\n90\n3\n70\n0\n38\n105000\n10\n0\n20\n0\n10\n1000\n20\n0\n10\n2000\n20\n500\n'
          '0\nLWPOLYLINE\n8\nOBRA\n90\n2\n70\n0\n38\n106000\n10\n0\n20\n0\n10\n1000\n20\n0\n'
          '0\nLWPOLYLINE\n8\nCURVAS\n90\n2\n70\n0\n38\n107000\n10\n0\n20\n1000\n10\n1000\n20\n1000\n0\nENDSEC\n0\nEOF\n';
      final n = c.importDxf(dxf);
      expect(n, 3);
      final contours = c.project.entities.whereType<ContourEntity>().toList();
      expect(contours.map((e) => e.elevation), [closeTo(105, 1e-9), closeTo(107, 1e-9)], reason: 'three points with a height, or a contour layer');
      expect(contours.first.points.last, const Pt(2, 0.5));
      expect(contours.every((e) => e.layer == Layers.contours), isTrue);
      expect(c.project.entities.whereType<PolylineEntity>().single.points.length, 2, reason: 'two points on a layer that is not named like contours stay a polyline');
    });

    test('big embedded images are left out of the browser copy; report CSV and debug state', () async {
      ImageEntity photo() => ImageEntity(id: 'img', origin: Pt.zero, width: 10, height: 10, data: Uint8List.fromList(List.filled(300000, 9)), source: 'foto.png');
      final probe = fresh()..addEntity(photo());
      final full = probe.saveJson(pretty: false, markClean: false).length;
      // room for the project, not for its 400 kB of image text
      final store = LocalProjectStore(maxBytes: full - 100000);
      store.clearAll();
      final c = fresh(store: store)..autosaveEnabled = true;
      c.addEntity(photo());
      c.autosaveNow();
      final saved = store.load(c.project.meta.uid)!;
      final entity = ((jsonDecode(saved) as Map)['entities'] as List).single as Map;
      expect(entity.containsKey('data'), isFalse);
      expect(entity['src'] ?? entity['source'], 'foto.png');
      store.clearAll();
      final d = fresh();
      loadExampleAction(d);
      expect(d.debugState(), {'entities': d.project.entities.length, 'selection': 0, 'results': false});
      await d.runDesign();
      expect(d.reportCsv(), d.exporter().reportCsv());
      expect(d.debugState()['results'], isTrue);
    });

    test('offsets of circles and arcs go out or in with the clicked side; polar arrays can keep the orientation', () {
      final c = fresh();
      c.addEntity(CircleEntity(id: 'c', center: Pt.zero, radius: 5));
      c.addEntity(ArcEntity(id: 'a', center: const Pt(50, 0), radius: 5, startRad: 0, sweepRad: 2));
      expect((c.offsetEntityTo('c', 2, const Pt(10, 0)) as CircleEntity).radius, 7);
      expect((c.offsetEntityTo('c', 2, const Pt(1, 0)) as CircleEntity).radius, 3);
      expect((c.offsetEntityTo('a', 1, const Pt(51, 0)) as ArcEntity).radius, 4);
      expect((c.offsetEntityTo('a', 1, const Pt(60, 0)) as ArcEntity).radius, 6);
      expect(c.offsetEntityTo('a', 0, const Pt(60, 0)), isNull);
      c.addEntity(TextEntity(id: 't', position: const Pt(10, 0), text: 'x', rotationDeg: 0));
      c.select(['t']);
      final n = c.arraySelected(ArrayOptions(polar: true, count: 4, center: Pt.zero, totalAngleDeg: 360, rotateItems: false));
      expect(n, 3);
      final copies = c.project.entities.whereType<TextEntity>().where((e) => e.id != 't').toList();
      expect(copies.every((e) => e.rotationDeg.abs() < 1e-9), isTrue, reason: 'upright copies');
      // each copy turned back about its own centre: the centres sit on the circle
      final r0 = (c.project.byId('t') as TextEntity).bounds.center.distanceTo(Pt.zero);
      expect(copies.map((e) => e.bounds.center.distanceTo(Pt.zero)).every((d) => (d - r0).abs() < 1e-6), isTrue);
    });
  });

  group('actions without dialogs', () {
    Workspace ws() => Workspace(systemClipboard: false);

    test('a project opens in the blank tab, in a new tab otherwise; bad files close their tab', () {
      final w = ws();
      w.current.setLanguage('pt');
      final src = fresh();
      loadExampleAction(src);
      final json = src.saveJson();
      final a = openJsonInTab(w, json)!;
      expect(identical(a, w.tabs.first), isTrue, reason: 'the blank tab is reused');
      final b = openJsonInTab(w, json)!;
      expect(w.tabs.length, 2);
      expect(identical(b, w.current), isTrue);
      expect(openJsonInTab(w, '{"format": "nope"}'), isNull);
      expect(w.tabs.length, 2, reason: 'the tab opened for the bad file is closed again');
      expect(w.current.lastMessage, startsWith('Erro'));
    });

    test('recent projects open once: an open one is brought to the front', () {
      final store = LocalProjectStore()..clearAll();
      final w = ws();
      w.current.setLanguage('pt');
      final src = fresh();
      loadExampleAction(src);
      store.save(src.project.meta.uid, 'Pomar', src.saveJson());
      final entry = store.list().single;
      openStoredAction(w, entry);
      expect(w.current.project.meta.uid, src.project.meta.uid);
      w.addTab();
      expect(w.active, 1);
      openStoredAction(w, entry);
      expect(w.active, 0, reason: 'already open: switch to it');
      expect(w.tabs.length, 2);
      store.remove(entry.uid);
      openStoredAction(w, entry);
      expect(w.tabs.length, 2, reason: 'a project that is gone does nothing');
      store.clearAll();
    });

    test('copy, cut and paste report what they did', () async {
      final w = ws();
      final c = w.current..setLanguage('pt');
      await copySelectionAction(w);
      expect(c.lastMessage, 'Nada selecionado');
      await pasteAction(w);
      expect(c.lastMessage, 'Área de transferência vazia');
      c.addEntity(LineEntity(id: c.project.newId(), a: Pt.zero, b: const Pt(1, 1)));
      c.selectAll();
      await copySelectionAction(w, cut: true);
      expect(c.project.entities, isEmpty);
      expect(c.lastMessage, contains('1'));
      await pasteAction(w);
      expect(c.project.entities.length, 1);
    });

    test('exports are delivered as files and failures are reported', () async {
      final c = fresh();
      final dir = Directory.systemTemp.createTempSync('oci_deliver');
      try {
        await deliverExport(c, '${dir.path}/a.txt', 'text/plain', () => 'conteúdo');
        expect(File('${dir.path}/a.txt').readAsStringSync(), 'conteúdo');
        expect(c.lastMessage, 'Exportado: ${dir.path}/a.txt');
        await deliverExport(c, '${dir.path}/b.bin', 'application/octet-stream', () => Uint8List.fromList([7, 8]));
        expect(File('${dir.path}/b.bin').readAsBytesSync(), [7, 8]);
        await deliverExport(c, '${dir.path}/c.kml', 'text/xml', () => throw const GeoReferenceMissing());
        expect(File('${dir.path}/c.kml').existsSync(), isFalse);
        expect(c.lastMessage, contains(c.describeError(const GeoReferenceMissing())));
      } finally {
        dir.deleteSync(recursive: true);
      }
    });
  });
}
