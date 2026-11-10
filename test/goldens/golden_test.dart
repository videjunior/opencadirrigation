@Tags(['golden'])
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:opencadirrigation/app/canvas/painter.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/theme.dart';
import 'package:opencadirrigation/app/widgets/dialogs/dialogs.dart';
import 'package:opencadirrigation/core/io/plot.dart';
import 'package:opencadirrigation/core/io/svg.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';

/// Pictures of the drawing and of the interface compared with the images of
/// test/goldens/images: a regression that draws in the wrong colour, place
/// or width passes the call-recording tests of the painter, not these.
///
/// A small project made here (not an example, which changes with the
/// engine) on the light and the dark canvas, a dense drawing at 2 device
/// pixels per pixel (the hairline mode), a dialog at phone size (390 × 844)
/// and the SVG of the plot. Text renders in the test font (blocks); shapes
/// come out the same to the pixel on macOS and on Linux, the blocks a pixel
/// taller on Linux, which [TolerantGoldenComparator] takes as the same
/// picture. Rebuild the images after a deliberate change with
/// `flutter test --update-goldens test/goldens` and look at them before
/// committing.
void main() {
  setUpAll(() {
    // the images come from one machine and run on others (CI is Linux):
    // edges may sit a pixel away (1 % of the pixels at most), and next to
    // nothing may differ in any other way (see the comparator)
    final base = goldenFileComparator as LocalFileComparator;
    goldenFileComparator = TolerantGoldenComparator(base.basedir.resolve('golden_test.dart'), edges: 0.01, apart: 0.0002);
  });

  setUp(() => setPref('lang', 'en'));
  tearDown(() => Cad.use(Brightness.dark));

  testWidgets('a small zone on the light canvas', (tester) async {
    Cad.use(Brightness.light);
    final c = smallProject();
    final image = (await tester.runAsync(() => render(c)))!;
    await expectLater(image, matchesGoldenFile('images/canvas_light.png'));
    image.dispose();
  });

  testWidgets('the same zone on the dark canvas', (tester) async {
    Cad.use(Brightness.dark);
    final c = smallProject();
    final image = (await tester.runAsync(() => render(c)))!;
    await expectLater(image, matchesGoldenFile('images/canvas_dark.png'));
    image.dispose();
  });

  testWidgets('a dense drawing on a 2x screen keeps thin lines', (tester) async {
    Cad.use(Brightness.dark);
    final c = denseProject();
    final image = (await tester.runAsync(() => render(c, dpr: 2)))!;
    expect((image.width, image.height), (640, 400));
    await expectLater(image, matchesGoldenFile('images/canvas_dense_2x.png'));
    image.dispose();
  });

  testWidgets('the units dialog on a phone', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Cad.use(Brightness.dark);
    final c = ProjectController()..autosaveEnabled = false;
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildCadTheme(Brightness.dark),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(onPressed: () => showUnitsDialog(context, c), child: const Text('open')),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('images/units_dialog_phone.png'));
  });

  test('the comparator takes soft edges and edges a pixel away, refuses a change and says where it is', () async {
    final dir = Directory.systemTemp.createTempSync('oci_golden');
    addTearDown(() => dir.deleteSync(recursive: true));
    // a blue square of 20 × 20 and a thin line on white, 80 × 50
    img.Image picture({int soft = 0, int grow = 0, int shift = 0, bool line = true, bool dot = false, bool pale = false}) {
      final im = img.Image(width: 80, height: 50, numChannels: 4);
      img.fill(im, color: img.ColorRgba8(255, 255, 255, 255));
      final blue = pale ? img.ColorRgba8(130, 150, 225, 255) : img.ColorRgba8(30, 60, 200, 255);
      img.fillRect(im, x1: 10 + shift, y1: 10 - (grow > 0 ? 1 : 0), x2: 29 + shift + (grow > 1 ? 1 : 0), y2: 29 + (grow > 1 ? 1 : 0), color: blue);
      if (grow > 1) img.fillRect(im, x1: 9, y1: 9, x2: 9, y2: 30, color: blue);
      // the row above the square, as another rasteriser would shade it
      for (var i = 10; soft > 0 && i <= 29; i++) {
        im.setPixelRgba(i, 9, 255 - soft, 255 - soft, 255, 255);
      }
      if (line) img.fillRect(im, x1: 40, y1: 25, x2: 69, y2: 25, color: img.ColorRgba8(40, 40, 40, 255));
      if (dot) img.fillRect(im, x1: 60, y1: 40, x2: 63, y2: 42, color: img.ColorRgba8(200, 30, 30, 255));
      return im;
    }

    File('${dir.path}/golden.png').writeAsBytesSync(img.encodePng(picture()));
    final comparator = TolerantGoldenComparator(Uri.file('${dir.path}/x_test.dart'), edges: 0.01, apart: 0.0002);
    final golden = Uri.parse('golden.png');
    Future<String?> refused(img.Image im) async {
      try {
        expect(await comparator.compare(img.encodePng(im), golden), isTrue);
        return null;
      } on FlutterError catch (e) {
        return '$e';
      }
    }

    expect(await refused(picture()), isNull);
    // the edge shaded by 20 levels: the same colour
    expect(await refused(picture(soft: 20)), isNull);
    // shaded by 90 levels: between the square and the white next to it
    expect(await refused(picture(soft: 90)), isNull);
    // the square a row taller (what the text blocks are on Linux): an edge a pixel away
    expect(await refused(picture(grow: 1)), isNull);
    // a pixel larger on every side: edges still, but more than 1 % of the picture
    final grown = await refused(picture(grow: 2));
    expect(grown, contains('84 of 4000 pixels (2.10 %) have a channel off by more than 24 levels; 1.00 % are allowed. Largest difference: 225 levels.'));
    expect(grown, contains('0 of them (0.00 %) are a change, not an edge a pixel away; 0.02 % are allowed.'));
    expect(grown, contains('They are inside x 9–30, y 9–30 of 80 × 50.'));
    // moved by two pixels (all but its four corners), the line gone, another colour, a dot of 4 × 3: changes
    expect(await refused(picture(shift: 2)), contains('76 of them (1.90 %) are a change'));
    expect(await refused(picture(line: false)), contains('30 of them (0.75 %) are a change'));
    expect(await refused(picture(pale: true)), contains('400 of them (10.00 %) are a change'));
    final text = (await refused(picture(dot: true)))!;
    expect(text, contains('12 of 4000 pixels (0.30 %) have a channel off by more than 24 levels; 1.00 % are allowed. Largest difference: 225 levels.'));
    expect(text, contains('12 of them (0.30 %) are a change, not an edge a pixel away; 0.02 % are allowed.'));
    expect(text, contains('3988 equal, 0 by 1–8, 0 by 9–24, 0 by 25–64, 0 by 65–128, 12 by more.'));
    expect(text, contains('The changed ones are inside x 60–63, y 40–42 of 80 × 50.'));
    expect(text, contains('(60, 40) #ffc81e1e for #ffffffff'));
    final map = text.split('\n').where((l) => RegExp(r'^[.#1-9]+$').hasMatch(l)).toList();
    expect(map, hasLength(25));
    expect(map.every((l) => l.length == 40), isTrue);
    expect(map[20].substring(28, 34), '..##..');
    expect(map[21].substring(28, 34), '..55..');
    expect(map.join().replaceAll('.', '').length, 4);
    // another size has no pixels to compare
    expect(GoldenDifference.of(img.encodePng(img.Image(width: 4, height: 4)), img.encodePng(picture()), levels: 24), isNull);
  });

  test('the SVG of the plot', () {
    final svg = SvgWriter.write(buildPlotScene(smallProject().project, unitsPerMm: 0.2), title: 'golden');
    final file = File('test/goldens/images/plot.svg');
    if (autoUpdateGoldenFiles) file.writeAsStringSync(svg);
    expect(file.existsSync(), isTrue, reason: 'flutter test --update-goldens test/goldens');
    expect(svg, file.readAsStringSync(), reason: 'the plot changed: look at it, then flutter test --update-goldens test/goldens');
  });
}

const canvasSize = Size(320, 200);

/// The project drawn by [c] at [canvasSize] logical pixels and [dpr] device
/// pixels per pixel, as the canvas draws it.
Future<ui.Image> render(ProjectController c, {double dpr = 1}) async {
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec)..scale(dpr);
  CadPainter(c: c, tool: null, snapResult: null, repaint: c, devicePixelRatio: dpr).paint(canvas, canvasSize);
  return rec.endRecording().toImage((canvasSize.width * dpr).round(), (canvasSize.height * dpr).round());
}

/// An area with a grid of spray heads on laterals, a valve, a mainline from
/// the water supply, a label and two trees, framed in the view.
ProjectController smallProject() {
  final c = ProjectController()..autosaveEnabled = false;
  final p = c.project;
  final es = <Entity>[
    AreaEntity(id: p.newId(), points: const [Pt(0, 0), Pt(40, 0), Pt(40, 24), Pt(0, 24)]),
  ];
  for (var row = 0; row < 3; row++) {
    final y = 4.0 + 8 * row;
    es.add(PipeEntity(id: p.newId(), points: [Pt(-2, y), Pt(36, y)], scope: HydraulicScope.zone));
    for (var col = 0; col < 4; col++) {
      es.add(OutletEntity(id: p.newId(), position: Pt(4.0 + 10 * col, y), outletSpecId: 'spray'));
    }
  }
  es
    ..add(PipeEntity(id: p.newId(), points: const [Pt(-2, 4), Pt(-2, 20)], scope: HydraulicScope.zone))
    ..add(ControlValveEntity(id: p.newId(), position: const Pt(-2, 12), zoneName: 'A1'))
    ..add(PipeEntity(id: p.newId(), points: const [Pt(-14, 12), Pt(-2, 12)], scope: HydraulicScope.mainline))
    ..add(WaterSupplyEntity(id: p.newId(), position: const Pt(-14, 12)))
    ..add(TextEntity(id: p.newId(), position: const Pt(14, 26), text: 'A1', height: 2))
    ..add(SymbolEntity(id: p.newId(), position: const Pt(46, 6)))
    ..add(SymbolEntity(id: p.newId(), position: const Pt(46, 18), size: 3));
  c.addEntities(es);
  c.camera.size = canvasSize;
  c.zoomAll();
  return c;
}

/// More vertices of linework in view than [CadPainter.denseSegments] (60
/// wavy contours of 701 vertices): the drawing the canvas keeps in thin
/// lines on a high-density screen.
ProjectController denseProject() {
  final c = ProjectController()..autosaveEnabled = false;
  final p = c.project;
  c.addEntities([
    for (var i = 0; i < 60; i++) ContourEntity(id: p.newId(), points: [for (var x = 0; x <= 700; x++) Pt(x.toDouble(), 4.0 * i + 1.5 * math.sin(x / 15 + i / 3))], elevation: 100.0 + i),
  ]);
  c.camera.size = canvasSize;
  c.zoomAll();
  return c;
}

/// A [LocalFileComparator] for images made on one machine and compared on
/// others (CI is Linux), where the same drawing differs in two ways only:
/// anti-aliasing moves the colour of an edge pixel by a few levels, and the
/// font rasteriser puts the edge of a glyph up to a pixel away (the blocks
/// of the test font are a row taller on Linux than on macOS; everything
/// else is the same to the pixel). So a pixel is taken as the same when its
/// colour is within [levels] of the golden's, and as an edge when its colour
/// lies between the darkest and the lightest of the 3 × 3 pixels around it
/// in the other picture, either way round. What is neither is a change: an
/// item that is missing, extra, moved by two pixels or in another colour.
///
/// The image passes with at most [apart] of its pixels changed and at most
/// [edges] of them off by more than [levels], edges included (many edges
/// that moved a pixel are a change too: every line a pixel wider). When it
/// is refused, the message says how many pixels differ, by how much and
/// where, so that a failure on another machine can be understood from the
/// message alone.
class TolerantGoldenComparator extends LocalFileComparator {
  TolerantGoldenComparator(super.testFile, {required this.edges, required this.apart});

  /// Fraction of the pixels (0–1) allowed to differ by more than [levels].
  final double edges;

  /// Fraction of the pixels (0–1) allowed to differ by more than [levels]
  /// from everything a pixel away in the other picture.
  final double apart;

  /// Difference of a channel (0–255) taken as the same colour.
  static const levels = 24;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final goldenBytes = await getGoldenBytes(golden);
    final result = await GoldenFileComparator.compareLists(imageBytes, goldenBytes);
    final diff = result.passed ? null : GoldenDifference.of(imageBytes, Uint8List.fromList(goldenBytes), levels: levels);
    if (result.passed || (diff != null && diff.off <= edges * diff.pixels && diff.apart <= apart * diff.pixels)) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError('$error\n${diff?.describe(edges: edges, apart: apart) ?? 'The two images have different sizes, or one of them is not a PNG.'}');
  }
}

/// How an image differs from its golden: the pixels with a channel off by
/// more than [levels], the ones among them that no pixel next to them in
/// the other picture explains, how far the channels go and where they are.
class GoldenDifference {
  GoldenDifference._(this.width, this.height, this.levels, this.off, this.apart, this.largest, this.byRange, this.box, this.cell, this.map, this.samples);

  final int width, height, levels;

  /// Pixels with a channel off by more than [levels].
  final int off;

  /// Pixels of [off] whose colour, in one picture or the other, is not
  /// between the darkest and the lightest of the 3 × 3 pixels around the
  /// same place in the other one (give or take [levels]): not an edge a
  /// pixel away.
  final int apart;

  /// The largest difference of a channel (0–255).
  final int largest;

  /// Pixels by their largest channel difference: 0, 1–8, 9–24, 25–64,
  /// 65–128 and above.
  final List<int> byRange;

  /// Left, top, right and bottom of the pixels the map shows, or null.
  final (int, int, int, int)? box;

  /// Side, in pixels, of the squares of [map].
  final int cell;

  /// Share (0–1) of the pixels of each square that count in [apart] (in
  /// [off] when nothing is apart), by rows.
  final List<List<double>> map;

  /// The first pixels the map shows: x, y, the image's colour and the
  /// golden's (0xAARRGGBB).
  final List<(int, int, int, int)> samples;

  int get pixels => width * height;

  /// Null when the two are not PNG images of the same size.
  static GoldenDifference? of(Uint8List image, Uint8List golden, {required int levels}) {
    final x = img.decodePng(image), y = img.decodePng(golden);
    if (x == null || y == null || x.width != y.width || x.height != y.height) return null;
    final w = x.width, h = x.height;
    final a = x.convert(numChannels: 4).getBytes(order: img.ChannelOrder.rgba), b = y.convert(numChannels: 4).getBytes(order: img.ChannelOrder.rgba);
    // is the colour of p at (i, j) outside what q has around (i, j)?
    bool outside(Uint8List p, Uint8List q, int i, int j) {
      for (var k = 0; k < 4; k++) {
        var lo = 255, hi = 0;
        for (var dj = -1; dj <= 1; dj++) {
          final row = (j + dj).clamp(0, h - 1) * w;
          for (var di = -1; di <= 1; di++) {
            final v = q[(row + (i + di).clamp(0, w - 1)) * 4 + k];
            if (v < lo) lo = v;
            if (v > hi) hi = v;
          }
        }
        final v = p[(j * w + i) * 4 + k];
        if (v < lo - levels || v > hi + levels) return true;
      }
      return false;
    }

    final byRange = List.filled(6, 0);
    final offAt = <int>[], apartAt = <int>[];
    var largest = 0;
    for (var j = 0; j < h; j++) {
      for (var i = 0; i < w; i++) {
        final o = (j * w + i) * 4;
        var d = 0;
        for (var k = 0; k < 4; k++) {
          d = math.max(d, (a[o + k] - b[o + k]).abs());
        }
        byRange[d == 0
            ? 0
            : d <= 8
            ? 1
            : d <= 24
            ? 2
            : d <= 64
            ? 3
            : d <= 128
            ? 4
            : 5]++;
        if (d > largest) largest = d;
        if (d <= levels) continue;
        offAt.add(j * w + i);
        if (outside(a, b, i, j) || outside(b, a, i, j)) apartAt.add(j * w + i);
      }
    }
    // the map and the examples show what is apart; when all are edges, those
    final shown = apartAt.isNotEmpty ? apartAt : offAt;
    final cell = math.max(1, math.max((w / 40).ceil(), (h / 25).ceil()));
    final cols = (w / cell).ceil(), rows = (h / cell).ceil();
    final counts = [for (var r = 0; r < rows; r++) List.filled(cols, 0)];
    final samples = <(int, int, int, int)>[];
    (int, int, int, int)? box;
    int argb(Uint8List p, int o) => (p[o + 3] << 24) | (p[o] << 16) | (p[o + 1] << 8) | p[o + 2];
    for (final at in shown) {
      final i = at % w, j = at ~/ w;
      counts[j ~/ cell][i ~/ cell]++;
      box = box == null ? (i, j, i, j) : (math.min(box.$1, i), math.min(box.$2, j), math.max(box.$3, i), math.max(box.$4, j));
      if (samples.length < 6) samples.add((i, j, argb(a, at * 4), argb(b, at * 4)));
    }
    final map = [
      for (var r = 0; r < rows; r++) [for (var c = 0; c < cols; c++) counts[r][c] / ((math.min(w, (c + 1) * cell) - c * cell) * (math.min(h, (r + 1) * cell) - r * cell))],
    ];
    return GoldenDifference._(w, h, levels, offAt.length, apartAt.length, largest, byRange, box, cell, map, samples);
  }

  /// The difference in words and as a coarse map, for a failure message.
  String describe({required double edges, required double apart}) {
    String pct(num v) => (100 * v).toStringAsFixed(2);
    String hex(int c) => '#${c.toRadixString(16).padLeft(8, '0')}';
    final b = box;
    final what = this.apart > 0 ? 'The changed ones' : 'They';
    return [
      '$off of $pixels pixels (${pct(off / pixels)} %) have a channel off by more than $levels levels; ${pct(edges)} % are allowed. Largest difference: $largest levels.',
      '${this.apart} of them (${pct(this.apart / pixels)} %) are a change, not an edge a pixel away; ${pct(apart)} % are allowed.',
      'Pixels by largest channel difference: ${byRange[0]} equal, ${byRange[1]} by 1–8, ${byRange[2]} by 9–24, ${byRange[3]} by 25–64, ${byRange[4]} by 65–128, ${byRange[5]} by more.',
      if (b != null) '$what are inside x ${b.$1}–${b.$3}, y ${b.$2}–${b.$4} of $width × $height.',
      if (samples.isNotEmpty) 'First ones: ${[for (final s in samples) '(${s.$1}, ${s.$2}) ${hex(s.$3)} for ${hex(s.$4)}'].join('; ')}.',
      if (b != null) 'Where (a character for $cell × $cell pixels: "." none, 1 to 9 the tenths of them, "#" all):',
      if (b != null)
        for (final row in map)
          [
            for (final v in row)
              v <= 0
                  ? '.'
                  : v >= 1
                  ? '#'
                  : '${math.max(1, (v * 10).floor())}',
          ].join(),
    ].join('\n');
  }
}
