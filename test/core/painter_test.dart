import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/canvas/basemap.dart';
import 'package:opencadirrigation/app/canvas/painter.dart';
import 'package:opencadirrigation/app/canvas/snapping.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_job.dart';
import 'package:opencadirrigation/app/theme.dart';
import 'package:opencadirrigation/app/tools/tools.dart';
import 'package:opencadirrigation/core/io/geo.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';

/// Records the drawing calls the painter makes.
class RecordingCanvas implements Canvas {
  final circles = <(Offset, double, Color)>[];
  final rects = <(Rect, Color)>[];
  final paths = <Color>[];
  final lines = <(Offset, Offset)>[];
  final paragraphs = <Offset>[];
  var images = 0;

  /// Stroke widths of the paths, and of the segments drawn as points.
  final pathWidths = <double>[];
  final segmentPaints = <Paint>[];

  /// The kinds of call in order: line, path, points, text.
  final ops = <String>[];

  @override
  void drawCircle(Offset c, double radius, Paint paint) => circles.add((c, radius, paint.color));
  @override
  void drawRect(Rect rect, Paint paint) => rects.add((rect, paint.color));
  @override
  void drawPath(Path path, Paint paint) {
    paths.add(paint.color);
    pathWidths.add(paint.strokeWidth);
    ops.add('path');
  }

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) {
    lines.add((p1, p2));
    lineColors.add(paint.color);
    ops.add('line');
  }

  final lineColors = <Color>[];

  @override
  void drawParagraph(ui.Paragraph paragraph, Offset offset) {
    paragraphs.add(offset);
    ops.add('text');
  }
  @override
  void drawImage(ui.Image image, Offset offset, Paint paint) => images++;

  /// Dots and segments the painter gathers by paint: one circle (radius =
  /// half the point size) or line each.
  @override
  void drawRawPoints(ui.PointMode mode, Float32List points, Paint paint) {
    if (mode == ui.PointMode.points) {
      for (var i = 0; i + 1 < points.length; i += 2) {
        circles.add((Offset(points[i], points[i + 1]), paint.strokeWidth / 2, paint.color));
      }
    } else if (mode == ui.PointMode.lines) {
      for (var i = 0; i + 3 < points.length; i += 4) {
        lines.add((Offset(points[i], points[i + 1]), Offset(points[i + 2], points[i + 3])));
      }
      segmentPaints.add(paint);
    }
    ops.add(mode == ui.PointMode.lines ? 'line' : 'points');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// The drawing painter: result overlays (pressure colours, min/max markers,
/// pipe sizes), drawing entities, embedded images, snap markers, the base
/// map notes and the preview image.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProjectController c;

  setUp(() async {
    setPref('lang', 'pt');
    c = ProjectController()..autosaveEnabled = false;
    c.designRunner = InThreadDesignRunner();
    loadExampleAction(c);
    c.camera.size = const Size(1200, 800);
    c.zoomAll();
  });

  RecordingCanvas paint({Tool? tool, SnapResult? snap, BaseMapLayer? basemap}) {
    final canvas = RecordingCanvas();
    CadPainter(c: c, tool: tool, snapResult: snap, repaint: c, basemap: basemap).paint(canvas, const Size(1200, 800));
    return canvas;
  }

  bool pressureColour(Color col) {
    const lo = Color(0xFF29B6F6), hi = Color(0xFF66BB6A);
    if (col.toARGB32() == 0xFFE53935 || col.toARGB32() == 0xFFAB47BC) return true;
    // on the blue → green ramp
    final t = (col.g - lo.g) / (hi.g - lo.g);
    final expect = Color.lerp(lo, hi, t.clamp(0, 1))!;
    return (col.r - expect.r).abs() < 0.02 && (col.b - expect.b).abs() < 0.02;
  }

  test('pressure overlay colours every emitter on the blue → green ramp inside the window', () async {
    await c.runDesign();
    c.camera.scale = 3;
    final plain = paint();
    c.overlay = OverlayMode.pressure;
    final coloured = paint();
    final extra = coloured.circles.length - plain.circles.length;
    final outlets = c.results!.zones.values.fold<int>(0, (n, z) => n + z.outlets.length);
    expect(extra, greaterThan(0));
    expect(extra, lessThanOrEqualTo(outlets));
    final added = coloured.circles.where((x) => !plain.circles.any((y) => y.$1 == x.$1 && y.$3 == x.$3)).map((x) => x.$3).toList();
    expect(added.every(pressureColour), isTrue);
    expect(added.where((x) => x.toARGB32() == 0xFFE53935), isEmpty, reason: 'the example stays inside its pressure window');
  });

  test('min/max overlay marks the extreme emitter of every zone with a label', () async {
    await c.runDesign();
    c.overlay = OverlayMode.minMax;
    final r = paint();
    final zones = c.results!.zones.length;
    int count(List<int> argb) => r.paths.where((col) => argb.contains(col.toARGB32())).length;
    expect(count([0xFF29B6F6, Cad.unconnected.toARGB32()]), zones, reason: 'one low marker per zone');
    expect(count([0xFFAB47BC, Cad.warning.toARGB32()]), zones, reason: 'one high marker per zone');
    c.overlay = OverlayMode.sizes;
    c.showLabels = true;
    final sizes = paint();
    expect(sizes.paragraphs.length, greaterThan(r.paragraphs.length - 2 * zones), reason: 'pipe size labels');
  });

  test('drawing entities, a decoded image and the snap markers', () async {
    c.newProject();
    c.camera.center = Pt.zero;
    c.camera.scale = 10;
    final rec = ui.PictureRecorder();
    Canvas(rec).drawRect(const Rect.fromLTWH(0, 0, 4, 4), Paint()..color = Colors.red);
    final image = await rec.endRecording().toImage(4, 4);
    c.addEntities([
      SplineEntity(id: 'sp', points: [const Pt(-20, 0), const Pt(-15, 5), const Pt(-10, 0)]),
      AngularDimensionEntity(id: 'ad', vertex: Pt.zero, a: const Pt(10, 0), b: const Pt(0, 10), radius: 4),
      RadialDimensionEntity(id: 'rd', center: const Pt(20, 0), point: const Pt(23, 4)),
      JunctionEntity(id: 'j', position: const Pt(-5, -5)),
      HatchEntity(id: 'hs', points: [const Pt(0, -20), const Pt(5, -20), const Pt(5, -15)], solid: true),
      HatchEntity(id: 'hf', points: [const Pt(10, -20), const Pt(15, -20), const Pt(15, -15)], spacing: 0.01),
      ImageEntity(id: 'im', origin: const Pt(-30, -30), width: 10, height: 10, data: Uint8List(1)),
    ]);
    c.images['im'] = image;
    c.select(['sp']);
    final r = paint();
    expect(r.images, 1, reason: 'the decoded image is drawn');
    expect(r.circles.where((x) => x.$2 == 2).length, greaterThanOrEqualTo(3), reason: 'fit points of the selected spline');
    expect(r.circles.any((x) => x.$1 == c.camera.toScreen(const Pt(-5, -5)) && x.$2 == 3), isTrue, reason: 'junction dot');
    expect(r.paths.length, greaterThanOrEqualTo(2), reason: 'solid and too-fine hatches are filled');
    expect(r.paragraphs.length, greaterThanOrEqualTo(2), reason: 'angle and radius texts');
    final line = createTool(ToolId.line, c, _NoHost());
    for (final (kind, isRect) in [('endpoint', true), ('node', true), ('midpoint', false), ('on', false), ('grid', false)]) {
      final s = paint(tool: line, snap: SnapResult(const Pt(1, 1), kind));
      final at = c.camera.toScreen(const Pt(1, 1));
      final snapRects = s.rects.where((x) => x.$1.center == at && x.$1.width == 10);
      expect(snapRects.isNotEmpty, isRect, reason: kind);
    }
    final none = paint(tool: createTool(ToolId.pan, c, _NoHost()), snap: const SnapResult(Pt(1, 1), 'endpoint'));
    expect(none.rects.where((x) => x.$1.width == 10), isEmpty, reason: 'tools without snap show no marker');
  });

  test('texts, symbols and spot heights are drawn, the texts over the linework', () {
    c.newProject();
    c.camera.center = Pt.zero;
    c.camera.scale = 10;
    c.showLabels = true;
    c.addEntities([
      TextEntity(id: 't', position: const Pt(-10, 0), text: 'Casa', height: 2),
      SymbolEntity(id: 's', position: const Pt(10, 0), size: 2),
      SpotHeightEntity(id: 'h', position: const Pt(0, 10), elevation: 101.5),
      LineEntity(id: 'l', a: const Pt(-20, 10), b: const Pt(20, 10)),
    ]);
    final r = paint();
    expect(r.paragraphs.length, greaterThanOrEqualTo(2), reason: 'the text and the spot height label');
    // the line, the cross of the spot height and the strokes of the tree
    expect(r.lines.length, greaterThan(10));
    expect(r.ops.lastIndexOf('text'), greaterThan(r.ops.lastIndexOf('line')), reason: 'labels are not crossed by lines drawn later');
  });

  test('the item under the cursor is drawn again in the hover colour, over the scene', () {
    c.newProject();
    c.camera.center = Pt.zero;
    c.camera.scale = 10;
    c.addEntities([
      LineEntity(id: 'l', a: const Pt(-10, 0), b: const Pt(10, 0)),
      TextEntity(id: 't', position: const Pt(0, 5), text: 'Casa', height: 2),
    ]);
    // (as ARGB: a paint gives its colour back in single precision)
    final hover = Cad.hover.toARGB32();
    List<int> argb(RecordingCanvas r) => [for (final x in r.lineColors) x.toARGB32()];
    final plain = paint();
    expect(argb(plain), isNot(contains(hover)));
    c.hoverId = 'l';
    expect(argb(paint()).last, hover, reason: 'drawn last, over the scene');
    c.hoverId = 't';
    expect(paint().paragraphs.length, plain.paragraphs.length + 1, reason: 'a text too');
    // the selection wins over the hover
    c.select(['l']);
    c.hoverId = 'l';
    expect(argb(paint()), isNot(contains(hover)));
  });

  test('a view packed with linework on a high-density screen draws its 1 px lines one device pixel wide', () {
    c.newProject();
    c.camera.center = const Pt(500, 450);
    c.camera.scale = 1.2;
    c.addEntities([for (var i = 0; i < 300; i++) PolylineEntity(id: 'p$i', points: [for (var k = 0; k <= 200; k++) Pt(k * 5.0, i * 3.0 + (k.isEven ? 0 : 1))])]);
    RecordingCanvas at(double dpr) {
      final canvas = RecordingCanvas();
      CadPainter(c: c, tool: null, snapResult: null, repaint: c, devicePixelRatio: dpr).paint(canvas, const Size(1200, 800));
      return canvas;
    }

    final dense = at(2);
    expect(dense.pathWidths, contains(0.0), reason: 'hairlines, which the GPU draws fast');
    expect(dense.segmentPaints.where((p) => p.strokeWidth == 1), isEmpty);
    // a standard screen: 1 px is one device pixel anyway
    expect(at(1).pathWidths, contains(1.0));
    // a few lines keep their 2 device pixels, segment by segment with square ends
    c.newProject();
    c.addEntities([PolylineEntity(id: 'q', points: const [Pt(400, 400), Pt(500, 420), Pt(600, 400)])]);
    c.camera.center = const Pt(500, 450);
    c.camera.scale = 1.2;
    final sparse = at(2);
    expect(sparse.pathWidths, isNot(contains(0.0)));
    final wide = sparse.segmentPaints.where((p) => p.strokeWidth == 1);
    expect(wide, isNotEmpty);
    expect(wide.every((p) => p.strokeCap == StrokeCap.square), isTrue);
  });

  test('base map notes: missing Google key, invalid custom template', () {
    c.project.meta.georef = GeoReference.fromLatLonOrigin(-15.78, -47.93);
    final layer = BaseMapLayer();
    removePref('basemap.googleKey');
    c.setGoogleMapsKey('');
    c.baseMap = BaseMap.googleSatellite;
    final google = paint(basemap: layer);
    c.baseMap = BaseMap.custom;
    c.setCustomTileUrl('');
    final custom = paint(basemap: layer);
    c.baseMap = BaseMap.none;
    final none = paint(basemap: layer);
    expect(google.paragraphs.length, none.paragraphs.length + 1, reason: 'the key note');
    expect(custom.paragraphs.length, none.paragraphs.length + 1, reason: 'the template note');
    layer.dispose();
  });

  test('the preview image has the requested size', () async {
    final img = await renderPreview(CadPainter(c: c, tool: null, snapResult: null, repaint: c), const Size(320, 200));
    expect((img.width, img.height), (320, 200));
    img.dispose();
  });
}

class _NoHost implements ToolHost {
  @override
  void showCommentDialog(Pt position) {}
  @override
  void showRevisionDialog(List<Pt> polygon) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
