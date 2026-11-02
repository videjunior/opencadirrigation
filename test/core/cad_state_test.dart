import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/canvas/basemap.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/io/gps.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/io/sheet_basemap.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_job.dart';
import 'package:opencadirrigation/app/state/design_runner_io.dart';
import 'package:opencadirrigation/app/state/workspace.dart';
import 'package:opencadirrigation/core/design/auto_fix.dart';
import 'package:opencadirrigation/core/io/geo.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

/// A runner that holds every job until it is cancelled (or [finish] runs
/// it), and says when it was disposed.
class _HeldRunner implements DesignRunner {
  Completer<DesignResponse>? job;
  DesignRequest? request;
  bool disposed = false;
  int cancels = 0;

  @override
  Future<DesignResponse> run(DesignRequest request, {void Function(DesignProgress progress)? onProgress, void Function(String mode)? onMode, Future<void> Function()? yieldControl}) {
    this.request = request;
    return (job = Completer<DesignResponse>()).future;
  }

  /// Runs the held job in this thread and answers it.
  Future<void> finish() async => job!.complete(await InThreadDesignRunner().run(request!));

  @override
  void cancel() {
    cancels++;
    final j = job;
    if (j != null && !j.isCompleted) j.completeError(const DesignCancelled());
  }

  @override
  void dispose() => disposed = true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProjectController fresh() {
    setPref('lang', 'en');
    final c = ProjectController()..autosaveEnabled = false;
    c.newProject();
    c.designRunner = InThreadDesignRunner();
    return c;
  }

  ProjectController designed() {
    final c = fresh();
    loadExampleAction(c, ExampleId.garden);
    return c;
  }

  setUp(() => LocalProjectStore().clearAll());

  group('undo and the results (CAD-07, CAD-08)', () {
    test('undo and redo bring the results back with the drawing', () async {
      final c = designed();
      await c.runDesign();
      final r = c.results!;
      final v = c.project.entities.whereType<ControlValveEntity>().first;
      c.mutateSelected<ControlValveEntity>((e) => e.zoneName = 'x');
      c.select([v.id]);
      c.mutateSelected<ControlValveEntity>((e) => e.zoneName = 'renamed', invalidateResults: false);
      expect(identical(c.results, r), isTrue);
      c.undo();
      expect(identical(c.results, r), isTrue, reason: 'the step kept the results: so does its undo');
      // the design step itself: undone, no results; redone, the same results
      while (c.historyEntries.where((e) => e.current).single.label != 'hist.design') {
        c.undo();
      }
      c.undo();
      expect(c.results, isNull);
      c.redo();
      expect(identical(c.results, r), isTrue);
    });

    test('notes keep the results; the terrain, areas and wiring drop them', () async {
      final c = designed();
      await c.runDesign();
      expect(c.results, isNotNull);
      c.addEntity(TextEntity(id: 'note', position: Pt.zero, text: 'Pump house'));
      c.addEntity(CommentEntity(id: 'cm', position: const Pt(1, 1), text: 'check'));
      c.addEntity(ContourEntity(id: 'gen', points: [Pt.zero, const Pt(5, 0)], elevation: 10, derived: true));
      expect(c.results, isNotNull, reason: 'a note, a comment and a generated contour do not change the results');
      c.select(['note']);
      c.moveSelected(const Pt(2, 2));
      c.deleteSelected();
      expect(c.results, isNotNull);
      c.addEntity(ContourEntity(id: 'survey', points: [Pt.zero, const Pt(5, 0)], elevation: 10));
      expect(c.results, isNull, reason: 'a surveyed contour changes the terrain');
      await c.runDesign();
      c.setGrip('survey', 0, const Pt(-1, 0));
      expect(c.results, isNull, reason: 'dragging the contour changes the terrain too');
    });
  });

  group('versions and uids (CAD-01, CAD-05, MOD-03)', () {
    test('restoring a version is one undo step and keeps the uid', () {
      final c = fresh();
      c.addEntity(LineEntity(id: 'a', a: Pt.zero, b: const Pt(1, 0)));
      final v1 = c.saveJson();
      c.addEntity(LineEntity(id: 'b', a: Pt.zero, b: const Pt(2, 0)));
      final uid = c.project.meta.uid;
      expect(c.restoreVersionJson(v1, version: 1), isTrue);
      expect(c.project.entities.map((e) => e.id), ['a']);
      expect(c.project.meta.uid, uid);
      expect(c.historyEntries.last.label, 'hist.versionRestore|1');
      c.undo();
      expect(c.project.entities.map((e) => e.id), ['a', 'b'], reason: 'the work before the restore comes back');
    });

    test('two tabs never share a uid; links, gallery files and kept copies open as copies', () async {
      final w = Workspace(systemClipboard: false);
      final src = fresh();
      loadExampleAction(src, ExampleId.garden);
      final json = src.saveJson();
      final a = openJsonInTab(w, json)!;
      final b = openJsonInTab(w, json)!;
      expect(a.project.meta.uid, src.project.meta.uid);
      expect(b.project.meta.uid, isNot(a.project.meta.uid), reason: 'the second tab is a copy');
      expect(b.lastMessage, contains(b.t('msg.openedAsCopyTab')));
      // a shared link carries the sender's uid
      final linked = openJsonInTab(w, json, asCopy: true)!;
      expect(linked.project.meta.uid, isNot(src.project.meta.uid));
      // the gallery files of the site all carry the same uid
      final gallery = (jsonDecode(json) as Map<String, dynamic>)..['meta'] = {...(jsonDecode(json) as Map)['meta'] as Map, 'uid': 'example-garden-en'};
      final g = openJsonInTab(w, jsonEncode(gallery))!;
      expect(g.project.meta.uid, isNot('example-garden-en'));
      // a file of a project whose copy here has unsaved changes: the copy stays offered
      final kept = fresh();
      kept.addEntity(LineEntity(id: 'x', a: Pt.zero, b: const Pt(1, 0)));
      final keptJson = kept.saveJson();
      kept.store.save(kept.project.meta.uid, 'Kept', keptJson, kind: 'autosave');
      final opened = openJsonInTab(w, keptJson)!;
      expect(opened.project.meta.uid, isNot(kept.project.meta.uid));
      expect(opened.store.recoverable().map((e) => e.uid), contains(kept.project.meta.uid));
    });
  });

  group('the design job (CAD-13, ENG-05, ENG-18, CAD-30)', () {
    test('Cancel stops the design: editing at once, no undo step, the redo steps kept', () async {
      final c = designed();
      c.addEntity(LineEntity(id: 'l', a: Pt.zero, b: const Pt(1, 0)));
      c.undo();
      expect(c.canRedo, isTrue);
      final held = _HeldRunner();
      c.designRunner = held;
      final steps = c.historyEntries.length;
      final run = c.runDesign();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(c.busy, isTrue);
      c.cancelDesign();
      await run;
      expect(c.busy, isFalse);
      expect(c.lastMessage, c.t('msg.designCancelled'));
      expect(c.historyEntries.length, steps, reason: 'a cancelled design is not an undo step');
      expect(c.canRedo, isTrue, reason: 'nor does it clear the redo');
      expect(c.results, isNull);
    });

    test('the job number and the build travel with every answer', () async {
      final p = Project();
      final messages = <Map<String, dynamic>>[];
      await runDesignJob({...DesignRequest.of(p, lang: 'en').toJson(), jobKey: 7}, messages.add);
      expect(messages, isNotEmpty);
      expect(messages.every((m) => m[jobKey] == 7 && isSameBuild(m)), isTrue);
      expect(isSameBuild({'type': 'done'}), isFalse, reason: 'a worker of an earlier version sends no build');
      expect(
        isSameBuild({
          buildKey: {'v': '0.0.1', 'p': designJobProtocol},
        }),
        isFalse,
      );
    });

    test('the thread and the isolate runners stop when cancelled', () async {
      final c = designed();
      final request = DesignRequest.of(c.project, lang: 'en');
      final thread = InThreadDesignRunner();
      var steps = 0;
      final f = thread.run(
        request,
        yieldControl: () async {
          if (++steps == 2) thread.cancel();
        },
      );
      await expectLater(f, throwsA(isA<DesignCancelled>()));
      final iso = IsolateDesignRunner();
      final g = iso.run(request);
      iso.cancel();
      await expectLater(g, throwsA(isA<DesignCancelled>()));
      // and run again afterwards
      final r = await IsolateDesignRunner().run(request);
      expect(r.results.zones, isNotEmpty);
    });

    test('nothing edits between the rounds of "optimise"; a cancel puts the project back', () async {
      final c = designed();
      await c.runDesign();
      final before = c.project.toJsonString();
      final held = _HeldRunner();
      c.designRunner = held;
      final opt = c.optimizeDesign(const OptimizeOptions());
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(c.editAllowed(), isFalse, reason: 'refused between the rounds');
      c.cancelDesign();
      expect(await opt, isNull);
      expect(c.project.toJsonString(), before);
      expect(c.editAllowed(), isTrue);
    });

    test('a refused delete says nothing was deleted and keeps the selection', () async {
      final c = designed();
      c.addEntity(LineEntity(id: 'l', a: Pt.zero, b: const Pt(1, 0)));
      c.select(['l']);
      final held = _HeldRunner();
      c.designRunner = held;
      final run = c.runDesign();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(c.deleteSelected(), 0);
      expect(c.selection, {'l'});
      expect(c.project.byId('l'), isNotNull);
      c.cancelDesign();
      await run;
    });
  });

  group('the tab and its work (CAD-12, CAD-15, CAD-16, CAD-20, CAD-31)', () {
    test('a closed tab stops its GPS, timers and design job', () async {
      final stops = <int>[];
      final saved = ProjectController.gpsWatcher;
      ProjectController.gpsWatcher = (onFix, onError) =>
          () => stops.add(1);
      addTearDown(() => ProjectController.gpsWatcher = saved);
      final w = Workspace(systemClipboard: false);
      final tab = w.addTab();
      final held = _HeldRunner();
      tab.designRunner = held;
      tab.startGps();
      w.closeTab(w.tabs.indexOf(tab));
      await Future<void>.delayed(Duration.zero);
      expect(stops, [1]);
      expect(held.disposed, isTrue);
      expect(tab.disposed, isTrue);
      tab.notify('after'); // a late message of a closed tab goes nowhere
    });

    test('a walk finished while a design runs is kept; a stopped walk goes on later', () async {
      final saved = ProjectController.gpsWatcher;
      void Function(GpsFix)? feed;
      ProjectController.gpsWatcher = (onFix, onError) {
        feed = onFix;
        return () {};
      };
      addTearDown(() => ProjectController.gpsWatcher = saved);
      final c = designed();
      c.setGeoreferenceAt(-15.8, -47.9);
      c.startGpsTrack();
      final g = c.project.meta.georef!;
      for (var i = 0; i < 4; i++) {
        final (lat, lon) = g.toLatLon(i * 10.0, (i % 2) * 10.0);
        feed!(GpsFix(lat: lat, lon: lon, accuracyM: 2, time: DateTime.now()));
      }
      expect(c.gpsTrack!.length, 4);
      final held = _HeldRunner();
      c.designRunner = held;
      final run = c.runDesign();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(c.finishGpsTrack(asArea: true), isNull);
      expect(c.gpsTrack!.length, 4, reason: 'the walk is not lost');
      c.cancelDesign();
      await run;
      // the GPS stopped: the walk is kept and resumes
      c.stopGps();
      expect(c.gpsTrack, isNull);
      expect(c.hasKeptWalk, isTrue);
      c.startGpsTrack();
      expect(c.gpsTrack!.length, 4);
      final area = c.finishGpsTrack(asArea: true);
      expect(area, isA<AreaEntity>());
      expect(c.hasKeptWalk, isFalse);
      c.stopGps();
    });

    test('an edit that throws changes nothing', () {
      final c = fresh();
      c.addEntity(LineEntity(id: 'a', a: Pt.zero, b: const Pt(1, 0)));
      final steps = c.historyEntries.length;
      expect(
        () => c.mutate(() {
          c.project.entities.clear();
          throw StateError('half done');
        }),
        throwsStateError,
      );
      expect(c.project.entities.map((e) => e.id), ['a']);
      expect(c.historyEntries.length, steps);
    });

    test('undo never gives an id twice', () {
      final c = fresh();
      c.addEntity(LineEntity(id: c.project.newId(), a: Pt.zero, b: const Pt(1, 0)));
      final id = c.project.newId();
      c.addEntity(LineEntity(id: id, a: Pt.zero, b: const Pt(2, 0)));
      c.undo();
      expect(c.project.newId(), isNot(id));
    });

    test('the history names trims, extensions, cuts, grips, vertices and layers', () {
      final c = fresh();
      c.addEntity(LineEntity(id: 'edge', a: const Pt(5, -5), b: const Pt(5, 5)));
      c.addEntity(LineEntity(id: 'l', a: Pt.zero, b: const Pt(3, 0)));
      expect(c.extendAt('l', const Pt(3, 0)), isTrue);
      c.addEntity(PolylineEntity(id: 'p', points: [Pt.zero, const Pt(10, 0), const Pt(10, 10)]));
      c.cutAt('p', const Pt(5, 0));
      c.addEntity(PolylineEntity(id: 'q', points: [const Pt(0, 20), const Pt(10, 20), const Pt(10, 30)]));
      c.setGrip('q', 0, const Pt(0, 21));
      c.insertVertex('q', 1, const Pt(5, 20));
      c.removeVertex('q', 1);
      c.addLayer('Notes');
      c.setLayerColor('Notes', 0xFF00FF00);
      c.renameLayer('Notes', 'Remarks');
      c.removeLayer('Remarks');
      final labels = [for (final e in c.historyEntries) e.label];
      for (final k in ['hist.extend', 'hist.cut', 'hist.grip', 'hist.vertexAdd', 'hist.vertexRemove', 'hist.layerAdd', 'hist.layerColor', 'hist.layerRename', 'hist.layerRemove']) {
        expect(labels, contains(k));
        expect(c.t.has(k), isTrue, reason: k);
      }
    });
  });

  group('georeference (CAD-18, CAD-29, FMT-17, UI-34)', () {
    const kml =
        '<?xml version="1.0"?><kml xmlns="http://www.opengis.net/kml/2.2"><Document><Placemark><name>edge</name><LineString><coordinates>-47.9,-15.8,0 -47.899,-15.801,0</coordinates></LineString></Placemark></Document></kml>';

    test('undoing an import takes the georeference it brought away', () {
      final c = fresh();
      expect(c.project.meta.georef, isNull);
      c.importFile('field.kml', Uint8List.fromList(utf8.encode(kml)));
      expect(c.project.meta.georef, isNotNull);
      expect(c.project.entities, isNotEmpty);
      c.undo();
      expect(c.project.meta.georef, isNull, reason: 'the KML that was undone no longer places the project');
      expect(c.project.entities, isEmpty);
      c.redo();
      expect(c.project.meta.georef, isNotNull);
    });

    test('setting or removing the georeference is an undo step', () {
      final c = fresh();
      expect(c.setGeoreference(GeoReference.fromLatLonOrigin(-15.8, -47.9)), isTrue);
      expect(c.setGeoreference(null), isTrue);
      expect(c.project.meta.georef, isNull);
      expect(c.historyEntries.last.label, 'hist.georefRemove');
      c.undo();
      expect(c.project.meta.georef, isNotNull);
    });

    test('pasting between projects placed at different origins keeps the place on the map', () async {
      Future<void> check(GeoReference from, GeoReference to) async {
        final w = Workspace(systemClipboard: false);
        final a = w.current..autosaveEnabled = false;
        a.setGeoreference(from);
        a.addEntity(CircleEntity(id: 'well', center: const Pt(100, 50), radius: 2));
        a.select(['well']);
        await w.copy();
        final b = w.addTab()..autosaveEnabled = false;
        b.setGeoreference(to);
        expect(await w.paste(), 1);
        final pasted = b.project.entities.whereType<CircleEntity>().single;
        final (lat, lon) = to.toLatLon(pasted.center.x, pasted.center.y);
        final (lat0, lon0) = from.toLatLon(100, 50);
        expect(lat, closeTo(lat0, 1e-6));
        expect(lon, closeTo(lon0, 1e-6));
        expect(w.lastPaste!.placedOnMap, isTrue);
      }

      // the same UTM zone, origins 200 m apart
      await check(GeoReference.fromLatLonOrigin(-15.8, -47.9), GeoReference.fromLatLonOrigin(-15.801, -47.902));
      // across the zone boundary at 48° W
      await check(GeoReference.fromLatLonOrigin(-15.8, -48.001), GeoReference.fromLatLonOrigin(-15.8, -47.999));
    });

    test('a cut refused while a design runs copies and deletes nothing', () async {
      final w = Workspace(systemClipboard: false);
      final c = w.current..autosaveEnabled = false;
      loadExampleAction(c, ExampleId.garden);
      c.addEntity(LineEntity(id: 'l', a: Pt.zero, b: const Pt(1, 0)));
      c.select(['l']);
      final held = _HeldRunner();
      c.designRunner = held;
      final run = c.runDesign();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(await w.copy(cut: true), 0);
      expect(w.clipboard, isNull);
      expect(c.project.byId('l'), isNotNull);
      c.cancelDesign();
      await run;
    });
  });

  group('base maps (CAD-24, CAD-35)', () {
    test('the street map server can be another one; volunteer servers give fewer tiles to the sheets', () {
      final c = fresh();
      expect(BaseMapLayer.url(BaseMap.streets, 3, 1, 2), 'https://tile.openstreetmap.org/3/1/2.png');
      expect(BaseMapLayer.sharedServer(BaseMap.streets), isTrue);
      c.setStreetsTileUrl('https://osm.example.org/{z}/{x}/{y}.png');
      expect(BaseMapLayer.url(BaseMap.streets, 3, 1, 2), 'https://osm.example.org/3/1/2.png');
      expect(BaseMapLayer.sharedServer(BaseMap.streets), isFalse);
      expect(getPref('basemap.osmUrl'), 'https://osm.example.org/{z}/{x}/{y}.png');
      c.setStreetsTileUrl('');
      expect(BaseMapLayer.url(BaseMap.streets, 3, 1, 2), startsWith('https://tile.openstreetmap.org/'));
      expect(sheetMapMaxTilesShared, lessThan(sheetMapMaxTiles));
      // the credit of each source links to its copyright and terms
      for (final m in BaseMap.values) {
        if (m == BaseMap.none || m == BaseMap.custom) continue;
        expect(BaseMapLayer.attributionUrl(m), startsWith('https://'), reason: m.name);
      }
      expect(BaseMapLayer.attributionUrl(BaseMap.streets), 'https://www.openstreetmap.org/copyright');
    });

    test('the Google key can be kept for this visit only', () {
      final c = fresh();
      c.setGoogleMapsKey('AIza-session', remember: false);
      expect(c.googleMapsKey, 'AIza-session');
      expect(getPref('basemap.googleKey'), isNull);
      expect(fresh().googleMapsKey, 'AIza-session', reason: 'another tab of the page has it');
      c.setGoogleMapsKey('AIza-kept');
      expect(getPref('basemap.googleKey'), 'AIza-kept');
      c.setGoogleMapsKey(null);
      expect(getPref('basemap.googleKey'), isNull);
    });
  });

  group('large drawings (CAD-19, CAD-21)', () {
    test('a few very dense contours keep fewer undo steps', () {
      final c = fresh();
      c.mutate(() {
        for (var i = 0; i < 400; i++) {
          c.project.entities.add(ContourEntity(id: c.project.newId(), points: [for (var k = 0; k < 2500; k++) Pt(k * 1.0, i * 1.0)], elevation: i * 0.5));
        }
      });
      for (var i = 0; i < 12; i++) {
        c.addEntity(TextEntity(id: c.project.newId(), position: Pt(i * 1.0, 0), text: '$i'));
      }
      // one million vertices a step: the budget keeps four of them
      expect(c.historyIndex, lessThanOrEqualTo(ProjectController.undoVertexBudget ~/ 1000000 + 1));
      expect(c.canUndo, isTrue);
    });

    test('locking a layer with tens of thousands selected does not look every id up the slow way', () {
      final c = fresh();
      c.mutate(() {
        for (var i = 0; i < 60000; i++) {
          c.project.entities.add(LineEntity(id: c.project.newId(), layer: 'L${i % 10}', a: Pt(i * 1.0, 0), b: Pt(i * 1.0, 1)));
        }
        for (var i = 0; i < 10; i++) {
          c.project.layers.add(Layer(name: 'L$i', color: 0xFF888888));
        }
      });
      c.selectAll();
      expect(c.selection.length, 60000);
      final sw = Stopwatch()..start();
      c.setLayerLocked('L3', true);
      expect(sw.elapsedMilliseconds, lessThan(1500));
      expect(c.selection.length, 54000);
    });
  });
}
