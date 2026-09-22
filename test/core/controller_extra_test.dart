import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/canvas/painter.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_job.dart';
import 'package:opencadirrigation/core/design/design_check.dart';
import 'package:opencadirrigation/core/design/densogram.dart';
import 'package:opencadirrigation/core/design/results.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/units.dart';

/// Counts what the painter draws (enough to see that a layer was painted).
class _Canvas implements Canvas {
  var calls = 0;
  var rects = 0;
  var images = 0;
  @override
  void drawRect(Rect rect, Paint paint) {
    rects++;
    calls++;
  }

  @override
  void drawImageRect(ui.Image image, Rect src, Rect dst, Paint paint) => images++;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls++;
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProjectController c;

  setUp(() {
    setPref('lang', 'pt');
    c = ProjectController()..autosaveEnabled = false;
    c.designRunner = InThreadDesignRunner();
    loadExampleAction(c);
    c.camera.size = const Size(1200, 800);
    c.zoomAll();
  });

  group('opening a project', () {
    test('an example drops the marks, profile, check and history of the previous project', () {
      c.addEntity(LineEntity(id: c.project.newId(), a: Pt.zero, b: const Pt(1, 1)));
      c.unconnected = {'e5', 'e9'};
      c.profilePath = [Pt.zero, const Pt(10, 0)];
      c.checkReport = DesignCheckReport(const []);
      c.hoverId = 'e3';
      expect(c.canUndo, isTrue);
      loadExampleAction(c);
      expect(c.unconnected, isEmpty, reason: 'ids of the old project would mark the example');
      expect(c.profilePath, isNull);
      expect(c.checkReport, isNull);
      expect(c.hoverId, isNull);
      expect(c.canUndo, isFalse);
      expect(c.dirty, isTrue, reason: 'an example is not saved yet');
    });

    test('a file keeps its results and unconnected marks but not the old views', () {
      final r = DesignResults(timestamp: DateTime(2026))..unconnected.add('x1');
      final j = c.project.toJson()..['results'] = r.toJson();
      c.profilePath = [Pt.zero, const Pt(1, 0)];
      c.loadJson(jsonEncode(j));
      expect(c.results, isNotNull);
      expect(c.unconnected, {'x1'});
      expect(c.profilePath, isNull);
      expect(c.dirty, isFalse);
      c.newProject();
      expect(c.results, isNull);
      expect(c.profilePath, isNull);
    });
  });

  group('settings edited by a dialog', () {
    test('one undo step, results dropped for parameters, kept for display units', () {
      c.results = DesignResults(timestamp: DateTime(2026));
      final n = c.historyIndex;
      final edit = c.beginSettingsEdit('hist.params');
      c.project.params.maxZoneVelocity = 1.1;
      expect(c.commitSettingsEdit(edit), isTrue);
      expect(c.historyIndex, n + 1);
      expect(c.results, isNull);
      expect(c.dirty, isTrue);
      c.undo();
      expect(c.project.params.maxZoneVelocity, 1.5);
      c.results = DesignResults(timestamp: DateTime(2026));
      final u = c.beginSettingsEdit('hist.units');
      c.project.params.units = c.project.params.units.copyWith(length: LengthUnit.values.firstWhere((l) => l != c.project.params.units.length));
      expect(c.commitSettingsEdit(u), isTrue);
      expect(c.results, isNotNull, reason: 'the display units do not change any result');
    });

    test('nothing changed: no undo step; another project opened meanwhile: ignored', () {
      final n = c.historyIndex;
      final edit = c.beginSettingsEdit();
      expect(c.commitSettingsEdit(edit), isFalse);
      expect(c.historyIndex, n);
      final stale = c.beginSettingsEdit();
      c.newProject();
      c.project.params.maxZoneVelocity = 0.9;
      expect(c.commitSettingsEdit(stale), isFalse);
      expect(c.canUndo, isFalse);
    });

    test('edits made through mutate while the dialog is open fold into the same step', () {
      c.project.entities.add(PivotEntity(id: 'pv', center: Pt.zero, machineCost: 1000));
      final code = c.project.params.currencyCode;
      final n = c.historyIndex;
      final edit = c.beginSettingsEdit('hist.params');
      c.setProjectCurrency('USD', rate: 0.2); // an undo step of its own
      c.project.params.maxMainlineVelocity = 1.7;
      expect(c.commitSettingsEdit(edit), isTrue);
      expect(c.historyIndex, n + 1, reason: 'the currency conversion is part of the dialog session');
      expect((c.project.byId('pv') as PivotEntity).machineCost, closeTo(200, 1e-9));
      c.undo();
      expect(c.project.params.currencyCode, code);
      expect(c.project.params.maxMainlineVelocity, 2.0);
      expect((c.project.byId('pv') as PivotEntity).machineCost, closeTo(1000, 1e-9));
    });

    test('undo and redo with nothing to undo still tell the listeners', () {
      c.newProject();
      var n = 0;
      c.addListener(() => n++);
      c.undo();
      c.redo();
      expect(n, 2);
      expect(c.eventCount('undo'), 1);
    });
  });

  test('dragging a pipe node takes the valve and its wire along; a wire vertex moves only wires', () {
    c.newProject();
    c.addEntities([
      PipeEntity(id: 'p', points: [Pt.zero, const Pt(10, 0)], scope: HydraulicScope.mainline),
      ControlValveEntity(id: 'v', position: const Pt(10, 0)),
      WireEntity(id: 'w', points: [const Pt(10, 20), const Pt(10, 0)]),
      WireEntity(id: 'w2', points: [const Pt(10, 20), const Pt(30, 20)]),
    ]);
    c.setGrip('p', 1, const Pt(12, 0), keepConnections: true);
    expect((c.project.byId('v') as ControlValveEntity).position, const Pt(12, 0));
    expect((c.project.byId('w') as WireEntity).points.last, const Pt(12, 0), reason: 'the wire stays on its valve');
    // the shared wire vertex: the other route follows, nothing hydraulic moves
    c.setGrip('w', 0, const Pt(15, 25), keepConnections: true);
    expect((c.project.byId('w2') as WireEntity).points.first, const Pt(15, 25));
    c.setGrip('w', 1, const Pt(13, 1), keepConnections: true);
    expect((c.project.byId('v') as ControlValveEntity).position, const Pt(12, 0), reason: 'a valve does not follow its wire');
  });

  test('layers created on demand take their default colour', () {
    final p = Project(layers: [Layer(name: 'X', color: 0xFF000000)]);
    expect(p.layerNamed(Layers.wires).color, Layers.defaultColors[Layers.wires]);
    expect(p.layerNamed(Layers.controllers).color, Layers.defaultColors[Layers.controllers]);
    expect(p.layerNamed('ROADS').color, 0xFFB0BEC5);
  });

  group('painter', () {
    int paint() {
      final canvas = _Canvas();
      CadPainter(c: c, tool: null, snapResult: null, repaint: c).paint(canvas, const Size(1200, 800));
      return canvas.calls;
    }

    test('controllers, wires, ordinate and diameter dimensions are drawn', () {
      final base = paint();
      final b = c.project.bounds;
      c.addEntities([
        ControllerEntity(id: 'k', position: b.center, name: 'K'),
        WireEntity(id: 'w', points: [b.center, b.center + const Pt(20, 0), b.center + const Pt(20, 20)]),
        OrdinateDimensionEntity(id: 'od', point: b.center, leaderEnd: b.center + const Pt(0, 10)),
        RadialDimensionEntity(id: 'rd', center: b.center, point: b.center + const Pt(3, 0), diameter: true),
      ]);
      expect(paint(), greaterThan(base + 10));
    });

    test('the densogram is painted as cells until its picture is ready, with a legend', () async {
      c.overlay = OverlayMode.densogram;
      c.camera.scale = 8;
      c.camera.center = c.densogram.sources.first.p;
      final canvas = _Canvas();
      CadPainter(c: c, tool: null, snapResult: null, repaint: c).paint(canvas, const Size(1200, 800));
      expect(canvas.rects, greaterThan(50), reason: 'cells and the legend ramp');
      // the picture arrives asynchronously and replaces the cells
      for (var i = 0; i < 50 && c.densogramImage == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(c.densogramImage, isNotNull);
      expect(c.densogramImage!.width, c.densogram.nx);
      expect(c.densogramImage!.height, c.densogram.ny);
      final later = _Canvas();
      CadPainter(c: c, tool: null, snapResult: null, repaint: c).paint(later, const Size(1200, 800));
      expect(later.images, 1);
      expect(later.rects, lessThan(canvas.rects));
      // no sprinklers: only the note in the legend
      c.newProject();
      c.overlay = OverlayMode.densogram;
      expect(c.densogram.isEmpty, isTrue);
      expect(() => paint(), returnsNormally);
    });

    test('the densogram is recomputed when the options change', () {
      final a = c.densogram;
      expect(identical(c.densogram, a), isTrue);
      c.densogramOptions.profile = SprayProfile.uniform;
      expect(identical(c.densogram, a), isFalse);
      c.showDensogram();
      expect(c.overlay, OverlayMode.densogram);
      expect(c.eventCount('densogram'), 1);
    });
  });
}
