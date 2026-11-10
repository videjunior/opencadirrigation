import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:opencadirrigation/app/ai/agent_tools.dart';
import 'package:opencadirrigation/app/ai/vision_render.dart';
import 'package:opencadirrigation/app/ai/vision_tiles.dart';
import 'package:opencadirrigation/app/canvas/cad_canvas.dart';
import 'package:opencadirrigation/app/io/crop_row_pixels.dart';
import 'package:opencadirrigation/app/io/http.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/app/widgets/dialogs/auto_design_dialogs.dart';
import 'package:opencadirrigation/app/widgets/dialogs/crop_rows_dialog.dart';
import 'package:opencadirrigation/core/ai/agent_loop.dart';
import 'package:opencadirrigation/core/design/crop_rows.dart';
import 'package:opencadirrigation/core/io/geo.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/main.dart';

/// Map tiles drawn from the world, for the projection of [g]: inside
/// [field] (project metres) rows of dark canopy every [spacing] m along
/// [dirDeg] (45 % of the spacing wide, centred on p·n = k·spacing), on red
/// soil; outside it the same soil.
class _RowTiles extends TileFetcher {
  _RowTiles(this.g, this.field, {this.dirDeg = 30, this.spacing = 4});
  final GeoReference g;
  final Bounds field;
  final double dirDeg, spacing;
  final _cache = <String, Uint8List>{};
  int requests = 0;

  @override
  Future<Uint8List> bytes(String url) async {
    requests++;
    final m = RegExp(r'/(\d+)/(\d+)/(\d+)').firstMatch(url)!;
    final z = int.parse(m.group(1)!), ty = int.parse(m.group(2)!), tx = int.parse(m.group(3)!);
    return _cache.putIfAbsent(url, () {
      final im = img.Image(width: 256, height: 256);
      final rnd = math.Random(tx * 31 + ty);
      final th = dirDeg * math.pi / 180;
      final n = Pt(-math.sin(th), math.cos(th));
      Pt at(double u, double v) {
        final k = math.pow(2.0, z);
        final lon = (tx + u) / k * 360 - 180;
        final s = math.pi * (1 - 2 * (ty + v) / k);
        final lat = math.atan((math.exp(s) - math.exp(-s)) / 2) * 180 / math.pi;
        final (x, y) = g.fromLatLon(lat, lon);
        return Pt(x, y);
      }

      final p00 = at(0, 0), p10 = at(1, 0), p01 = at(0, 1);
      for (var j = 0; j < 256; j++) {
        for (var i = 0; i < 256; i++) {
          final q = p00 + (p10 - p00) * ((i + 0.5) / 256) + (p01 - p00) * ((j + 0.5) / 256);
          final u = q.dot(n) / spacing;
          final row = field.contains(q) && (u - u.round()).abs() <= 0.225;
          final (r, gg, b) = row ? (45, 88, 38) : (152, 108, 74);
          final k = rnd.nextInt(17) - 8;
          im.setPixelRgb(i, j, (r + k).clamp(0, 255), (gg + k).clamp(0, 255), (b + k).clamp(0, 255));
        }
      }
      return img.encodePng(im);
    });
  }

  @override
  Future<String> text(String method, String url, {Map<String, String> headers = const {}, String? body}) async => throw HttpStatusException(404);
}

List<Pt> _rect(double x0, double y0, double x1, double y1) => [Pt(x0, y0), Pt(x1, y0), Pt(x1, y1), Pt(x0, y1)];

double _angleError(double a, double b) {
  final d = (a - b).abs() % 180;
  return math.min(d, 180 - d);
}

/// The crop rows read from the image (1.7.0 ROW): the dialog from the
/// selection to the result and the apply in one undo step, its messages
/// without a field or a georeference, the phone layout and the Stop button,
/// the defaults it leaves for Field blocks, and the assistant's operations.
void main() {
  final g = GeoReference.fromLatLonOrigin(-22.5, -47.5);
  const fieldBox = Bounds(-60, -40, 60, 40);

  Future<void> settle(WidgetTester tester, [int n = 4]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<ProjectController> pumpShell(WidgetTester tester, {Size size = const Size(1920, 1080)}) async {
    TutorialController.markDone();
    setPref('lang', 'pt');
    LocalProjectStore().clearAll();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const IrrigationCadApp(autoTutorial: false, offerRecovery: false));
    await settle(tester);
    final c = (tester.state(find.byType(AppShell)) as dynamic).c as ProjectController;
    c
      ..autosaveEnabled = false
      ..designRunner = InThreadDesignRunner();
    c.snap.enabled = false;
    c.newProject();
    await settle(tester);
    return c;
  }

  BuildContext ctxOf(WidgetTester tester) => tester.element(find.byType(CadCanvas));

  /// A georeferenced project with the field as an irrigated area, selected.
  AreaEntity addField(ProjectController c) {
    c.project.meta.georef = g;
    final a = AreaEntity(id: c.project.newId(), points: _rect(fieldBox.minX + 5, fieldBox.minY + 5, fieldBox.maxX - 5, fieldBox.maxY - 5), name: 'Cafezal');
    c.addEntities([a]);
    c.select([a.id]);
    return a;
  }

  /// Lets the reading run until [done]: the dialog starts it in the test's
  /// fake time (its steps advance with the pumps) and the images decode in
  /// real time (between them).
  Future<void> until(WidgetTester tester, bool Function() done, {int max = 3000}) async {
    for (var i = 0; i < max && !done(); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(done(), isTrue, reason: 'condition not reached');
    await settle(tester, 2);
  }

  tearDown(() => CropRowSession.renderer = const CanvasSnapshots());

  testWidgets('the rows of the selected area are read, shown and applied in one undo step', (tester) async {
    final c = await pumpShell(tester);
    final a = addField(c);
    final tiles = _RowTiles(g, fieldBox, dirDeg: 30, spacing: 4);
    CropRowSession.renderer = CanvasSnapshots(tiles: tiles);
    final s = CropRowSession.of(c);
    s.last = null;
    showCropRowsDialog(ctxOf(tester), c);
    await tester.pump();
    await until(tester, () => s.last != null);
    final r = s.last!;
    expect(r.verdict, CropRowVerdict.rows, reason: '${r.messages}');
    expect(_angleError(r.directionDeg, 30), lessThan(1));
    expect((r.spacingM - 4).abs() / 4, lessThan(0.03));
    expect(tiles.requests, greaterThan(0));
    expect(find.text('Direção das fileiras'), findsOneWidget);
    expect(find.text('Espaçamento entre fileiras'), findsOneWidget);
    expect(find.byKey(const Key('row_preview')), findsOneWidget);
    expect(find.byKey(const Key('row_detail')), findsOneWidget);
    expect(s.preview, isNotEmpty, reason: 'the rows are drawn over the drawing while the dialog is open');
    // the guides too, then apply
    final guides = find.byKey(const Key('row_apply_guides'));
    await tester.ensureVisible(guides);
    await tester.tap(guides);
    await settle(tester, 1);
    final step = c.historyIndex;
    final before = c.project.entities.length;
    await tester.tap(find.byKey(const Key('row_apply')));
    await settle(tester);
    expect(find.byType(CropRowsDialog), findsNothing);
    expect(s.preview, isEmpty, reason: 'the preview goes with the dialog');
    expect(c.historyIndex, step + 1, reason: 'one undo step');
    expect(_angleError(a.rowDirectionDeg!, 30), lessThan(1));
    expect(a.rowSpacingM, closeTo(4, 0.12));
    expect(a.groundCover, closeTo(0.45, 0.06));
    final lines = c.project.entities.whereType<LineEntity>().where((e) => e.layer == cropRowLayer).toList();
    expect(lines.length, c.project.entities.length - before);
    expect(lines.length, greaterThanOrEqualTo(r.rows));
    expect(c.lastMessage, contains('Fileiras aplicadas'));
    // the field blocks of the area start from those rows
    c.select([a.id]);
    showFieldSubdivisionDialog(ctxOf(tester), c);
    await settle(tester);
    expect(find.text('Direção e espaçamento das fileiras lidos da imagem para esta área.'), findsOneWidget);
    expect(find.text('Direção das fileiras (°)'), findsOneWidget, reason: 'the direction typed, not the longest edge');
    await tester.tap(find.text('Cancelar').last);
    await settle(tester);
    // undo takes all of it back
    c.undo();
    expect((c.project.byId(a.id)! as AreaEntity).rowDirectionDeg, isNull, reason: 'the area as it was (undo restores a copy)');
    expect(c.project.entities.whereType<LineEntity>(), isEmpty);
  });

  testWidgets('without a field it says what to select; without a georeference, what to do', (tester) async {
    final c = await pumpShell(tester);
    showCropRowsDialog(ctxOf(tester), c);
    await settle(tester);
    expect(find.byKey(const Key('row_no_area')), findsOneWidget);
    await tester.tap(find.text('Fechar'));
    await settle(tester);
    // an area, but no georeference
    final a = AreaEntity(id: c.project.newId(), points: _rect(0, 0, 50, 30));
    c.addEntities([a]);
    c.select([a.id]);
    showCropRowsDialog(ctxOf(tester), c);
    await tester.pump();
    await until(tester, () => find.byKey(const Key('row_error')).evaluate().isNotEmpty, max: 300);
    expect(find.textContaining('georreferência'), findsWidgets);
    expect(find.byKey(const Key('row_apply')), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('row_apply'))).onPressed, isNull);
  });

  testWidgets('on a phone: the dialog fits, Stop stops the reading', (tester) async {
    final c = await pumpShell(tester, size: const Size(390, 844));
    addField(c);
    CropRowSession.renderer = CanvasSnapshots(tiles: _RowTiles(g, fieldBox));
    showCropRowsDialog(ctxOf(tester), c);
    await tester.pump();
    await tester.pump();
    // reading at once: Stop
    expect(find.byKey(const Key('row_stop')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('row_stop')));
    await tester.tap(find.byKey(const Key('row_stop')));
    await tester.pump();
    expect(find.byKey(const Key('row_stop')), findsNothing);
    expect(find.text('Detecção interrompida.'), findsOneWidget);
    // and again, to the end
    final s = CropRowSession.of(c)..last = null;
    await tester.ensureVisible(find.byKey(const Key('row_detect')));
    await tester.tap(find.byKey(const Key('row_detect')));
    await tester.pump();
    await until(tester, () => s.last != null);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('row_preview')), findsOneWidget);
    final size = tester.getSize(find.byType(AlertDialog));
    expect(size.width, lessThanOrEqualTo(390));
  });

  group('the assistant', () {
    late ProjectController c;
    setUp(() async {
      LocalProjectStore().clearAll();
      c = ProjectController()
        ..autosaveEnabled = false
        ..designRunner = InThreadDesignRunner();
      c.newProject();
      await c.setLanguage('en', persist: false);
    });

    testWidgets('detect_crop_rows reads, apply_crop_rows writes in one undo step; the design tools default to the rows', (tester) async {
      final a = addField(c);
      final box = AgentToolbox(c, snapshots: CanvasSnapshots(tiles: _RowTiles(g, fieldBox, dirDeg: 120, spacing: 5)));
      final detect = box.operations.firstWhere((o) => o.name == 'detect_crop_rows');
      final apply = box.operations.firstWhere((o) => o.name == 'apply_crop_rows');
      expect(detect.effectOf(const {}), ToolEffect.read);
      expect(apply.effectOf(const {}), ToolEffect.write);
      ToolOutput? out;
      await tester.runAsync(() async {
        out = await detect.run({'area': a.id});
      });
      expect(out!.isError, isFalse, reason: out!.text);
      expect(out!.text, contains('Verdict: rows'));
      final m = RegExp(r'direction_deg ([0-9.]+).*row spacing ([0-9.]+) m').firstMatch(out!.text)!;
      expect(_angleError(double.parse(m.group(1)!), 120), lessThan(1));
      expect(double.parse(m.group(2)!), closeTo(5, 0.15));
      expect(a.rowDirectionDeg, isNull, reason: 'detect changes nothing');
      final step = c.historyIndex;
      await tester.runAsync(() async {
        out = await apply.run({'area': a.id, 'guides': true});
      });
      expect(out!.isError, isFalse, reason: out!.text);
      expect(c.historyIndex, step + 1);
      expect(c.historyEntries.last.label, 'hist.aiTool|apply_crop_rows');
      expect(_angleError(a.rowDirectionDeg!, 120), lessThan(1));
      expect(a.rowSpacingM, closeTo(5, 0.15));
      expect(c.project.entities.whereType<LineEntity>().where((e) => e.layer == cropRowLayer), isNotEmpty);
      // the assistant's field blocks follow the stored rows
      final sub = box.tools.firstWhere((t) => t.name == 'subdivide_field');
      await tester.runAsync(() async {
        out = await sub.run({'area': a.id, 'lateral': 'tape'});
      });
      expect(out!.isError, isFalse, reason: out!.text);
      final tapes = c.project.entities.whereType<TapeEntity>().toList();
      expect(tapes, isNotEmpty);
      final d = tapes.first.points.last - tapes.first.points.first;
      expect(_angleError(radToDeg(d.angle) % 180, 120), lessThan(1), reason: 'laterals along the rows read');
      // errors the model can act on
      Object? error;
      await tester.runAsync(() async {
        try {
          await detect.run({'area': tapes.first.id});
        } catch (e) {
          error = e;
        }
      });
      expect(error, isA<ToolInputError>());
      expect('$error', contains('not a closed outline'));
      c.project.meta.georef = null;
      error = null;
      await tester.runAsync(() async {
        try {
          await detect.run({'area': a.id});
        } catch (e) {
          error = e;
        }
      });
      expect(error, isA<ToolInputError>());
      expect('$error', contains('georeference'));
    });
  });
}
