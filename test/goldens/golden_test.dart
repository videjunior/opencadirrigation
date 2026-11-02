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
/// and the SVG of the plot. Text renders in the test font (blocks), the same
/// everywhere. Rebuild the images after a deliberate change with
/// `flutter test --update-goldens test/goldens` and look at them before
/// committing.
void main() {
  setUpAll(() {
    // the images come from one machine and run on others (CI is Linux):
    // anti-aliasing may differ in a few edge pixels, a real change does not
    final base = goldenFileComparator as LocalFileComparator;
    goldenFileComparator = TolerantGoldenComparator(base.basedir.resolve('golden_test.dart'), tolerance: 0.005);
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

/// A [LocalFileComparator] that takes an image whose pixels differ from the
/// golden by little (another platform's anti-aliasing moves the colour of
/// edge pixels by a few levels) or in at most [tolerance] of the pixels.
class TolerantGoldenComparator extends LocalFileComparator {
  TolerantGoldenComparator(super.testFile, {required this.tolerance});

  /// Fraction of the pixels (0–1) allowed to differ by more than [levels].
  final double tolerance;

  /// Difference of a channel (0–255) taken as the same colour.
  static const levels = 24;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final goldenBytes = await getGoldenBytes(golden);
    final result = await GoldenFileComparator.compareLists(imageBytes, goldenBytes);
    if (result.passed || _close(imageBytes, Uint8List.fromList(goldenBytes))) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }

  bool _close(Uint8List a, Uint8List b) {
    final x = img.decodePng(a), y = img.decodePng(b);
    if (x == null || y == null || x.width != y.width || x.height != y.height) return false;
    var off = 0;
    for (var j = 0; j < x.height; j++) {
      for (var i = 0; i < x.width; i++) {
        final p = x.getPixel(i, j), q = y.getPixel(i, j);
        if ((p.r - q.r).abs() > levels || (p.g - q.g).abs() > levels || (p.b - q.b).abs() > levels || (p.a - q.a).abs() > levels) off++;
      }
    }
    return off <= tolerance * x.width * x.height;
  }
}
