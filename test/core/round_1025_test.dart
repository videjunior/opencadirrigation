// Small engine pieces of the 2026-10-25 feature round.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/widgets/dialogs/dialogs.dart' show nextRevisionTag;
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/electrical.dart';
import 'package:opencadirrigation/core/design/report_tables.dart';
import 'package:opencadirrigation/core/hydraulics/emitter.dart';
import 'package:opencadirrigation/core/io/share_link.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/units.dart';

void main() {
  group('master valve and accessories', masterValveTests);
  group('browser storage', storeCompressionTests);
  group('lateral editing', lateralEditTests);
  group('share links', shareLinkTests);
  group('review', reviewTests);
  group('tables typed or pasted from a data sheet', () {
    test('rows split by spaces, tabs, semicolons or commas, decimal commas accepted', () {
      final rows = parseNumberRows('1,5 32 2,1\n2,0\t37\t2,3\r\n2.5,41,2.5\n\n  3;45;2,7  \nabc\n1 234,5 7');
      expect(rows, [
        [1.5, 32, 2.1],
        [2.0, 37, 2.3],
        [2.5, 41, 2.5],
        [3, 45, 2.7],
        [1, 234.5, 7],
      ]);
      expect(parseNumberRows(''), isEmpty);
    });

    test('a nozzle curve and its wetted radius come back from their own table', () {
      const k = 40 * m3sPerLph / 4.47213595499958; // 40 L/h at 20 m, x = 0.5
      final rows = [
        for (final h in [10.0, 15.0, 20.0, 25.0, 30.0]) (h, k * math.sqrt(h), 1.2 * math.pow(h, 0.3).toDouble()),
      ];
      final f = EmitterCurve.fitTable(rows);
      expect(f.isUsable, isTrue);
      expect(f.flowRows, 5);
      expect(f.radiusRows, 5);
      expect(f.curve.k, closeTo(k, k * 1e-9));
      expect(f.curve.x, closeTo(0.5, 1e-9));
      expect(f.curve.radiusA, closeTo(1.2, 1e-9));
      expect(f.curve.radiusB, closeTo(0.3, 1e-9));
      expect(f.maxFlowError, lessThan(1e-9));
      expect(f.maxRadiusError, lessThan(1e-9));
      expect(f.curve.flow(20) / m3sPerLph, closeTo(40, 1e-6));
    });

    test('scattered rows report their worst deviation; one radius uses the default exponent', () {
      final f = EmitterCurve.fitTable([(10, 1.0e-5, null), (20, 1.5e-5, 3.0), (30, 1.7e-5, null)]);
      expect(f.radiusRows, 1);
      expect(f.curve.radiusB, 0.5);
      expect(f.curve.radius(20), closeTo(3.0, 1e-12));
      expect(f.maxFlowError, greaterThan(0.01));
      expect(EmitterCurve.fitTable(const []).isUsable, isFalse);
      expect(EmitterCurve.fitTable([(0, 1.0, 2.0)]).isUsable, isFalse);
    });
  });
}

// ---- master valve, controller accessories and pump hour meter
void masterValveTests() {
  Project site({bool master = true}) {
    final p = Project();
    p.entities.addAll([
      ControllerEntity(id: 'ctl', position: Pt.zero, name: 'Ctrl', stations: 4, accessories: {'rain': 150, 'pumpRelay': 90}),
      WireEntity(id: 'w1', points: [Pt.zero, const Pt(100, 0), const Pt(200, 0)]),
      ControlValveEntity(id: 'vA', position: const Pt(100, 0), zoneName: 'A'),
      ControlValveEntity(id: 'vB', position: const Pt(200, 0), zoneName: 'B'),
      if (master) MiscHydraulicEntity(id: 'mv', position: const Pt(50, 0), valveSpecId: 'mv50', name: 'MV'),
    ]);
    return p;
  }

  test('the master valve is on with every zone: output 0, its own wire and more current on the common', () {
    final flows = [
      {'vA'},
      {'vB'},
    ];
    final withMv = designElectrical(site(), flows: flows)!;
    final without = designElectrical(site(master: false), flows: flows)!;
    expect(withMv.warnings, isEmpty);
    final mv = withMv.runs.firstWhere((r) => r.valveId == 'mv');
    expect(mv.station, 0);
    expect(mv.routeM, closeTo(50, 1e-9));
    expect(mv.openTogether, 2); // with the zone of each flow
    expect([for (final r in withMv.runs.where((r) => r.station > 0)) r.station], [1, 2]);
    expect(withMv.controllers.single.used, 2); // the master output is not a station
    expect(withMv.controllers.single.peakCurrentA, closeTo(0.37 + 0.22, 1e-12));
    final b1 = withMv.runs.firstWhere((r) => r.valveId == 'vB'), b0 = without.runs.firstWhere((r) => r.valveId == 'vB');
    expect(b1.volts, lessThan(b0.volts)); // the master valve loads the common too
  });

  test('accessories and the hour meter reach the bill of materials', () {
    final p = site();
    p.entities.add(PumpEntity(id: 'pu', position: const Pt(-10, 0), pumpSpecId: p.catalog.pumps.first.id, hourMeter: true, hourMeterCost: 75));
    final back = Project.fromJsonString(p.toJsonString());
    final ctl = back.entities.whereType<ControllerEntity>().single;
    expect(ctl.accessories, {'rain': 150.0, 'pumpRelay': 90.0});
    expect(back.entities.whereType<PumpEntity>().single.hourMeterCost, 75);
    expect(back.entities.whereType<PumpEntity>().single.hourMeter, isTrue);
    expect(ctl.clone().accessories, ctl.accessories);
    final d = Designer(back, label: (k) => k);
    d.designWiring();
    d.buildBom();
    final names = {for (final l in d.results.bom) l.description: l.unitCost};
    expect(names['acc.rain'], 150);
    expect(names['acc.pumpRelay'], 90);
    // the hour meter of a pump connected to the network (an isolated item
    // stays out of the bill of materials)
    final ex = buildExampleProject(I18n('en').call, lang: 'en');
    final pump = ex.entities.whereType<PumpEntity>().first
      ..hourMeter = true
      ..hourMeterCost = 75;
    expect(pump.hourMeter, isTrue);
    final r = Designer(ex, label: (k) => k).designAll();
    expect(r.bom.where((l) => l.description == 'acc.hourMeter').single.unitCost, 75);
  });
}

void storeCompressionTests() {
  test('large projects are stored compressed and come back intact; small ones stay plain', () {
    final store = LocalProjectStore();
    store.clearAll();
    final small = Project()..meta.name = 'small';
    final big = Project()..meta.name = 'big';
    for (var i = 0; i < 6000; i++) {
      big.entities.add(LineEntity(id: 'e$i', a: Pt(i * 1.0, 0), b: Pt(i * 1.0, 10)));
    }
    final bigJson = big.toJsonString();
    expect(bigJson.length, greaterThan(LocalProjectStore.compressAbove));
    final packed = LocalProjectStore.encode(bigJson);
    expect(packed.startsWith('gz:'), isTrue);
    expect(packed.length, lessThan(bigJson.length / 4));
    expect(LocalProjectStore.decode(packed), bigJson);
    expect(LocalProjectStore.encode(small.toJsonString()), small.toJsonString());
    expect(LocalProjectStore.decode('gz:not base64!'), isNull);
    store.save(big.meta.uid, 'big', bigJson);
    expect(store.load(big.meta.uid), bigJson);
    expect(store.versions(big.meta.uid).single.bytes, bigJson.length);
    // more than the cap uncompressed, well within it compressed
    final capped = LocalProjectStore(maxBytes: bigJson.length ~/ 2);
    capped.save('x', 'x', bigJson, kind: 'autosave');
    expect(capped.load('x'), bigJson);
    store.clearAll();
  });
}

void lateralEditTests() {
  ProjectController zone() {
    final c = ProjectController()..autosaveEnabled = false;
    c.project = Project();
    c.project.entities.addAll([
      PipeEntity(id: 'sub', points: [Pt.zero, const Pt(0, 20)], scope: HydraulicScope.zone),
      for (var i = 0; i < 3; i++) SpraylineEntity(id: 's$i', points: [Pt(0, 5.0 + i * 5), Pt(30, 5.0 + i * 5)], outletSpecId: 'micro', nozzleId: 'm50', headM: 15, spacing: 4, offset: 2),
      TapeEntity(id: 't0', points: [const Pt(30, 20), const Pt(0, 20)], tapeSpecId: Project().catalog.tapes.first.id),
    ]);
    return c;
  }

  test('a device near the inlet of every selected lateral, at the end that touches the submain', () {
    final c = zone();
    c.select(['s0', 's1', 's2', 't0']);
    expect(c.insertDeviceOnSelectedLaterals('prv50', distanceM: 0.3), 4);
    final devs = c.project.entities.whereType<MiscHydraulicEntity>().toList();
    expect(devs, hasLength(4));
    for (final d in devs.take(3)) {
      expect(d.position.x, closeTo(0.3, 1e-9));
    }
    // the tape is drawn from its far end: the device goes 0.3 m from (0, 20)
    expect(devs.last.position.x, closeTo(0.3, 1e-9));
    expect(devs.every((d) => d.scope == HydraulicScope.zone), isTrue);
    c.undo();
    expect(c.project.entities.whereType<MiscHydraulicEntity>(), isEmpty);
  });

  test('laterals and tapes become plain pipes, one undo step', () {
    final c = zone();
    c.select(['s1', 't0', 'sub']);
    expect(c.convertSelectedToPipe(), 2);
    expect(c.project.entities.whereType<SpraylineEntity>(), hasLength(2));
    expect(c.project.entities.whereType<TapeEntity>(), isEmpty);
    final pipes = c.project.entities.whereType<PipeEntity>().toList();
    expect(pipes, hasLength(3));
    final fromTape = pipes.firstWhere((p) => p.points.first == const Pt(30, 20));
    final bore = c.project.catalog.tapes.first.innerDiameterMm;
    expect(c.project.catalog.pipe(fromTape.pipeSpecId)!.innerDiameterMm, greaterThanOrEqualTo(bore - 0.5));
    expect(c.selection.length, 2);
    c.undo();
    expect(c.project.entities.whereType<TapeEntity>(), hasLength(1));
  });
}

void shareLinkTests() {
  test('a project travels in the link fragment and comes back whole, without pictures and results', () {
    final p = buildExampleProject(I18n('en').call, lang: 'en');
    p.entities.add(ImageEntity(id: 'img', origin: Pt.zero, width: 10, height: 10, mime: 'image/png', data: Uint8List.fromList(List.filled(5000, 7))));
    final j = p.toJson()..['results'] = {'x': 1};
    final json = shareableProjectJson(j);
    expect(json.contains('"results"'), isFalse);
    final link = shareLinkFor(json, base: 'https://example.org/');
    expect(link.startsWith('https://example.org/#p='), isTrue);
    expect(link.contains('='), isTrue);
    expect(link.substring(link.indexOf('#p=') + 3).contains('='), isFalse); // no padding
    expect(link.length, lessThan(json.length)); // compressed
    final back = projectJsonFromLink(link)!;
    expect(back, json);
    final project = Project.fromJsonString(back);
    expect(project.entities.length, p.entities.length);
    expect(project.entities.whereType<ImageEntity>().single.data, isNull);
    expect(projectJsonFromLink('#${link.split('#').last}'), json);
    expect(projectJsonFromLink('https://example.org/'), isNull);
    expect(projectJsonFromLink('#p=garbage!'), isNull);
    expect(projectJsonFromLink('#xp=abc'), isNull);
  });
}

void reviewTests() {
  test('comments and revision clouds survive the file, clouds bulge outwards', () {
    final p = Project();
    p.entities.addAll([
      CommentEntity(id: 'c1', position: const Pt(3, 4), text: 'Move the valve', author: 'Ana', date: '2026-10-25'),
      RevisionCloudEntity(id: 'r1', points: [Pt.zero, const Pt(20, 0), const Pt(20, 10), const Pt(0, 10)], revision: 'B', date: '2026-10-25', description: 'New zone 3'),
    ]);
    final back = Project.fromJsonString(p.toJsonString());
    final cm = back.byId('c1') as CommentEntity;
    expect([cm.text, cm.author, cm.date, cm.resolved], ['Move the valve', 'Ana', '2026-10-25', false]);
    final rc = back.byId('r1') as RevisionCloudEntity;
    expect([rc.revision, rc.description], ['B', 'New zone 3']);
    final ring = rc.scallops();
    expect(ring.first, ring.last);
    // every scallop point is on or outside the outline (counter-clockwise ring)
    expect(ring.every((q) => !pointInPolygon(q, rc.points) || pointOnPolygonBoundary(q, rc.points, tol: 1e-6)), isTrue);
    // a clockwise outline bulges outwards too
    final cw = RevisionCloudEntity(id: 'r2', points: rc.points.reversed.toList());
    expect(cw.scallops().every((q) => !pointInPolygon(q, cw.points) || pointOnPolygonBoundary(q, cw.points, tol: 1e-6)), isTrue);
    expect(rc.transformed(Affine.scaling(2)).effectiveArc, closeTo(rc.effectiveArc * 2, 1e-9));
    expect(rc.isClosedShape, isTrue);
  });

  test('revision tags count on', () {
    expect(nextRevisionTag(const []), 'A');
    expect(nextRevisionTag(const ['A']), 'B');
    expect(nextRevisionTag(const ['A', 'B', '']), 'C');
    expect(nextRevisionTag(const ['3']), '4');
    expect(nextRevisionTag(const ['R1A']), 'R1B');
    expect(nextRevisionTag(const ['Z']), 'Z.1');
  });

  test('the review tables list them', () {
    final t = I18n('pt');
    final p = Project()
      ..entities.addAll([
        CommentEntity(id: 'c1', position: Pt.zero, text: 'x', resolved: true),
        CommentEntity(id: 'c2', position: Pt.zero, text: 'y'),
        RevisionCloudEntity(id: 'r1', points: [Pt.zero, const Pt(1, 0), const Pt(1, 1)], revision: 'A', date: '2026-01-02'),
      ]);
    final tables = buildReportTables(project: p, results: null, labels: ReportLabels(t: t.call, has: t.has, warning: (w) => t.warning(w)));
    final comments = tables.firstWhere((x) => x.key == 'comments');
    expect(comments.rows, hasLength(2));
    expect(comments.warn, [false, true]);
    expect(tables.firstWhere((x) => x.key == 'revisions').rows.single.first, 'A');
  });
}
