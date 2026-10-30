import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/ai/agent_ops_engineering.dart';
import 'package:opencadirrigation/app/ai/agent_tools.dart';
import 'package:opencadirrigation/app/ai/ops_eng_common.dart';
import 'package:opencadirrigation/app/ai/ops_eng_exports.dart';
import 'package:opencadirrigation/app/ai/vision_mapping.dart';
import 'package:opencadirrigation/app/ai/vision_render.dart';
import 'package:opencadirrigation/app/ai/vision_tiles.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/core/ai/agent_loop.dart';
import 'package:opencadirrigation/core/io/geo.dart';
import 'package:opencadirrigation/core/io/pdf_sheet.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';

/// Map tiles without a network: every tile is the same noisy picture (a
/// photograph to the encoders); or nothing is served.
class _NoiseTiles extends TileFetcher {
  final urls = <String>[];
  Uint8List? _png;

  @override
  Future<Uint8List> bytes(String url) async {
    urls.add(url);
    return _png ??= () {
      final r = math.Random(7);
      final im = img.Image(width: 256, height: 256);
      for (var y = 0; y < 256; y++) {
        for (var x = 0; x < 256; x++) {
          im.setPixelRgb(x, y, r.nextInt(256), r.nextInt(256), r.nextInt(256));
        }
      }
      return Uint8List.fromList(img.encodePng(im));
    }();
  }

  @override
  Future<String> text(String method, String url, {Map<String, String> headers = const {}, String? body}) async => throw StateError('no Google here');
}

/// The assistant's look at a plot sheet before it exports it (preview_sheet):
/// one picture of the sheet as it prints, within the pixels the model in use
/// reads unscaled, with the base map when the export prints one (a JPEG
/// then); the sheets of the set and their scales; the title block with the
/// empty fields flagged; a layout check that finds texts printed over each
/// other, texts too small to read and a drawing that fills too little of
/// its viewport or runs out of it, with the fixes; and no side effects.
void main() {
  late ProjectController c;
  final files = <String, Object>{};
  final saveFiles = engFileSink;

  setUp(() async {
    LocalProjectStore().clearAll();
    c = ProjectController()
      ..autosaveEnabled = false
      ..designRunner = InThreadDesignRunner();
    c.newProject();
    await c.setLanguage('en', persist: false);
    files.clear();
    engFileSink = (c, name, mime, data) async => files[name] = data;
  });
  tearDown(() => engFileSink = saveFiles);

  AgentTool op(AgentToolbox box) => box.operations.firstWhere((o) => o.name == 'preview_sheet');

  Future<ToolOutput> preview(WidgetTester tester, AgentToolbox box, Map<String, dynamic> input) async {
    late ToolOutput out;
    await tester.runAsync(() async => out = await op(box).run(input));
    return out;
  }

  img.Image picture(ToolOutput out) => img.decodeImage(base64Decode(out.images.single.base64))!;

  void withinLimits(img.Image im, PictureLimits l) {
    expect(math.max(im.width, im.height), lessThanOrEqualTo(l.maxSide));
    expect(im.width * im.height, lessThanOrEqualTo(l.maxPixels));
    if (l.maxShortSide != null) expect(math.min(im.width, im.height), lessThanOrEqualTo(l.maxShortSide!));
  }

  /// A field with a label, two notes written on top of each other and one
  /// too small to read at the scale the sheet fits the drawing at.
  (TextEntity, TextEntity, TextEntity) fieldWithNotes() {
    final p = c.project;
    final one = TextEntity(id: p.newId(), position: const Pt(40, 30), text: 'Overlap one', height: 1.6);
    final two = TextEntity(id: p.newId(), position: const Pt(40, 30), text: 'Overlap two', height: 1.6);
    final tiny = TextEntity(id: p.newId(), position: const Pt(10, 8), text: 'tiny note', height: 0.2);
    p.entities.addAll([
      AreaEntity(id: p.newId(), name: 'Field', points: const [Pt(0, 0), Pt(100, 0), Pt(100, 60), Pt(0, 60)]),
      one,
      two,
      tiny,
    ]);
    c.entitiesChanged();
    return (one, two, tiny);
  }

  testWidgets('the operation: found with the exports, a read, translated; the exports say to look first', (tester) async {
    final box = AgentToolbox(c);
    final o = op(box);
    expect(engineeringOperations(box).map((x) => x.name), contains('preview_sheet'));
    expect(o.effectOf(const {}), ToolEffect.read);
    expect(o.mustConfirm(const {}), isFalse);
    expect(o.describe(const {'sheet': 2}), 'Look at sheet 2 as it will print, before exporting');
    final props = (o.inputSchema['properties'] as Map).keys;
    final pdf = box.operations.firstWhere((x) => x.name == 'export_sheet_pdf');
    expect(props, containsAll([...(pdf.inputSchema['properties'] as Map).keys, 'sheet', 'size']));
    for (final name in ['export_sheet_pdf', 'export_sheet_png']) {
      expect(box.operations.firstWhere((x) => x.name == name).description, contains('preview_sheet'), reason: name);
    }
    expect(engineeringCoverage.values, contains('op:preview_sheet'));
  });

  testWidgets('a designed project: sheet 1 as one picture within the model\'s limits, the sheets and their scales, the empty title block fields; nothing saved, the project unchanged', (tester) async {
    loadExampleAction(c, ExampleId.orchard);
    await tester.runAsync(() => c.runDesign());
    expect(c.results, isNotNull, reason: c.lastMessage);
    c.project.meta
      ..client = ''
      ..designer = '';
    final box = AgentToolbox(c, snapshots: CanvasSnapshots(tiles: _NoiseTiles()));
    final history = c.historyIndex, seq = c.editSeq, before = jsonEncode(c.project.toJson());
    final out = await preview(tester, box, {'split': 'zones'});
    expect(out.isError, isFalse);
    final im = picture(out);
    withinLimits(im, PictureLimits.standard);
    expect(math.max(im.width, im.height), greaterThan(1000), reason: 'as large as the model reads');
    expect(out.images.single.mediaType, 'image/png', reason: 'a drawing on white paper');
    final text = out.text;
    expect(text, contains('${im.width}×${im.height} px'));
    expect(text, contains('px per paper mm'));
    // the set: the overview at the scale the PDF fits it at, then a sheet per zone
    final fit = c.exporter().sheetBuilder().sheetScale(const SheetOptions());
    expect(text, contains('Sheet 1 of '));
    expect(text, contains('1. overview "Overview", 1:${fit.round()} (fitted)  ← this picture'));
    expect(text, contains('2. zone "'));
    expect(text, contains('A3 landscape (420 × 297 mm)'));
    expect(text, contains('Drawing area: sheet ['));
    // the title block: the empty fields flagged, and what fills them
    expect(text, contains('Client: EMPTY'));
    expect(text, contains('Designer: EMPTY'));
    expect(text, isNot(contains('Project: EMPTY')));
    expect(text, contains('set_project_info {client, designer}'));
    expect(text, contains('North arrow: yes'));
    expect(text, contains('Scale bar: yes'));
    expect(text, contains('Legend: yes'));
    expect(text, contains(RegExp('Materials table: (yes|CUT)')));
    // the picture is registered: inside the drawing area its pixels are world positions
    final id = RegExp(r'Picture (s\d+):').firstMatch(text)!.group(1)!;
    final m = VisionSession.of(box)[id]!;
    final b = c.project.bounds;
    expect(m.world.contains(b.center), isTrue);
    expect(m.width, im.width);
    // nothing saved, nothing changed
    expect(files, isEmpty);
    expect(c.historyIndex, history);
    expect(c.editSeq, seq);
    expect(jsonEncode(c.project.toJson()), before);
    // another sheet of the set; one that does not exist
    final zone = await preview(tester, box, {'split': 'zones', 'sheet': 2});
    expect(zone.text, contains('Sheet 2 of '));
    expect(zone.text, contains('2. zone "'));
    expect(zone.text, contains('← this picture'));
    late Object error;
    await tester.runAsync(() async {
      try {
        await op(box).run({'sheet': 9});
      } on Object catch (e) {
        error = e;
      }
    });
    expect(error, isA<ToolInputError>());
    expect('$error', contains('The set has 1 sheet'));
  });

  testWidgets('the picture stays within what each model reads: OpenAI\'s shorter side, Claude\'s high resolution, a size asked for', (tester) async {
    fieldWithNotes();
    final box = AgentToolbox(
      c,
      snapshots: CanvasSnapshots(tiles: _NoiseTiles()),
      pictures: PictureLimits.openai,
    );
    final openai = picture(await preview(tester, box, const {}));
    withinLimits(openai, PictureLimits.openai);
    expect(math.min(openai.width, openai.height), greaterThan(700));
    box.pictures = PictureLimits.high;
    final high = picture(await preview(tester, box, const {}));
    withinLimits(high, PictureLimits.high);
    expect(math.max(high.width, high.height), previewSheetSide);
    box.pictures = PictureLimits.standard;
    final asked = await preview(tester, box, const {'size': 4000, 'page': 'a4', 'landscape': false});
    withinLimits(picture(asked), PictureLimits.standard);
    expect(asked.text, contains('size 4000 was reduced to ${PictureLimits.standard.maxSide} px'));
    final small = picture(await preview(tester, box, const {'size': 600}));
    expect(math.max(small.width, small.height), 600);
  });

  testWidgets('the layout check: texts on top of each other, a text too small to read, with their items and the fixes', (tester) async {
    final (one, two, tiny) = fieldWithNotes();
    final box = AgentToolbox(c, snapshots: CanvasSnapshots(tiles: _NoiseTiles()));
    final text = (await preview(tester, box, const {})).text;
    expect(text, contains('Overlapping texts: 1 place:'));
    expect(text, contains('"Overlap one" (Text ${one.id}) × "Overlap two" (Text ${two.id})'));
    expect(RegExp(r'mm into each other at sheet \[[\d.]+, [\d.]+\] mm, picture \[\d+, \d+\] px, world \[[\d.]+, [\d.]+\] m').hasMatch(text), isTrue, reason: text);
    expect(text, contains('Texts lower than 1.6 mm'));
    expect(text, contains('"tiny note" (Text ${tiny.id})'));
    // where it is: the sheet, the picture and the world agree (the note is written at [10, 8])
    final at = RegExp(r'"tiny note" \(Text \w+\): ([\d.]+) mm at sheet \[[\d.]+, [\d.]+\] mm, picture \[(\d+), (\d+)\] px, world \[10\.0, 8\.0\] m').firstMatch(text);
    expect(at, isNotNull, reason: text);
    expect(double.parse(at!.group(1)!), closeTo(0.2 / (c.exporter().sheetBuilder().sheetScale(const SheetOptions()) / 1000), 0.01));
    final id = RegExp(r'Picture (s\d+):').firstMatch(text)!.group(1)!;
    final back = VisionSession.of(box)[id]!.toWorld(double.parse(at.group(2)!), double.parse(at.group(3)!));
    expect(back.distanceTo(const Pt(10, 8)), lessThan(1), reason: '$back');
    expect(text, isNot(contains('"Field  ')), reason: 'the area label is clear of the others');
    expect(text, contains('Overlapping texts: give them room'));
    expect(text, contains('update_entities {"h": '));
    expect(text, contains('set_label_rules) colour results on the screen only'));
    expect(text, contains('No design results: run_design first'));
    // apart, at a size that reads: nothing to report
    c.project.entities
      ..remove(two)
      ..remove(tiny);
    c.entitiesChanged();
    final clean = (await preview(tester, box, const {})).text;
    expect(clean, contains('Overlapping texts: none.'));
    expect(clean, contains('Texts lower than 1.6 mm (cap height in print): none.'));
  });

  testWidgets('the viewport: a scale too small leaves the paper empty, one too large cuts the drawing off', (tester) async {
    fieldWithNotes();
    final box = AgentToolbox(c, snapshots: CanvasSnapshots(tiles: _NoiseTiles()));
    final fit = c.exporter().sheetBuilder().sheetScale(const SheetOptions());
    final fitted = (await preview(tester, box, const {})).text;
    expect(fitted, isNot(contains('is a small scale')));
    expect(fitted, isNot(contains('runs out of it')));
    final tiny = (await preview(tester, box, {'scale': fit * 10})).text;
    expect(tiny, contains('is a small scale for this sheet (1:${fit.round()} fills it)'));
    expect(tiny, contains('The drawing fills little of its viewport: scale ${fit.round()}'));
    final huge = (await preview(tester, box, {'scale': fit / 5})).text;
    expect(huge, contains('runs out of it'));
    expect(huge, contains('fit the scale (omit scale: it fits at 1:${fit.round()})'));
  });

  testWidgets('a few items far from the rest stretch the sheet: named, with a window of the main part', (tester) async {
    fieldWithNotes();
    final p = c.project;
    for (var i = 0; i < 8; i++) {
      for (var j = 0; j < 5; j++) {
        p.entities.add(SpotHeightEntity(id: p.newId(), position: Pt(10.0 + i * 11, 8.0 + j * 11), elevation: 100.0 + i));
      }
    }
    final far = TextEntity(id: p.newId(), position: const Pt(1500, 900), text: 'Stray', height: 20);
    p.entities.add(far);
    c.entitiesChanged();
    final box = AgentToolbox(c, snapshots: CanvasSnapshots(tiles: _NoiseTiles()));
    final text = (await preview(tester, box, const {})).text;
    expect(text, contains('Most of the drawing'));
    expect(text, contains('far from it stretch the sheet'));
    expect(text, contains('Text ${far.id}'));
    expect(text, contains('windows [{"bbox": ['));
    // without the stray the drawing fills its sheet
    p.entities.remove(far);
    c.entitiesChanged();
    expect((await preview(tester, box, const {})).text, isNot(contains('Most of the drawing')));
  });

  testWidgets('over the base map: the tiles downloaded as for the export, the picture a JPEG', (tester) async {
    fieldWithNotes();
    c.project.meta.georef = GeoReference.fromLatLonOrigin(-20.3, -47.4);
    c.baseMap = BaseMap.satellite;
    c.baseMapSnapshot = () async => null; // a canvas is there
    final tiles = _NoiseTiles();
    final box = AgentToolbox(c, snapshots: CanvasSnapshots(tiles: tiles));
    final history = c.historyIndex;
    final out = await preview(tester, box, const {});
    expect(tiles.urls, isNotEmpty);
    expect(out.images.single.mediaType, 'image/jpeg');
    withinLimits(picture(out), PictureLimits.standard);
    expect(out.text, contains('the base map under the drawing'));
    expect(out.text, contains('Base map: under the drawing'));
    expect(files, isEmpty);
    expect(c.historyIndex, history);
    // without it: the reason
    final plain = await preview(tester, box, const {'base_map': false});
    expect(plain.images.single.mediaType, 'image/png');
    expect(plain.text, contains('Base map: off (base_map false)'));
  });

  testWidgets('through run_operation, as the model calls it', (tester) async {
    fieldWithNotes();
    final box = AgentToolbox(c, snapshots: CanvasSnapshots(tiles: _NoiseTiles()));
    final run = box.tools.firstWhere((x) => x.name == 'run_operation');
    expect(run.effectOf({'name': 'preview_sheet', 'input': <String, dynamic>{}}), ToolEffect.read);
    late ToolOutput out;
    await tester.runAsync(
      () async => out = await run.run({
        'name': 'preview_sheet',
        'input': {'sheet': 1, 'legend': false},
      }),
    );
    expect(out.images, hasLength(1));
    expect(out.text, contains('Legend: none (legend false)'));
    expect(out.text, contains('legend true adds the legend'));
  });
}
