import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/ai/agent_tools.dart';
import 'package:opencadirrigation/app/ai/ops_eng_common.dart';
import 'package:opencadirrigation/app/ai/ops_eng_exports.dart';
import 'package:opencadirrigation/app/ai/vision_render.dart';
import 'package:opencadirrigation/app/ai/vision_tiles.dart';
import 'package:opencadirrigation/app/canvas/basemap.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/io/sheet_basemap.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/core/io/geo.dart';
import 'package:opencadirrigation/core/io/pdf_sheet.dart';
import 'package:opencadirrigation/core/model/geometry.dart';

/// Map tiles without a network: a tile is green, red, blue or yellow as its
/// centre lies north-west, north-east, south-west or south-east of
/// [lat0], [lon0]; or every request fails.
class _QuadrantTiles extends TileFetcher {
  _QuadrantTiles(this.lat0, this.lon0, {this.offline = false});
  final double lat0, lon0;
  final bool offline;
  final urls = <String>[];
  final Map<int, Uint8List> _png = {};

  static const colours = {'nw': 0xFF1EB432, 'ne': 0xFFDC2828, 'sw': 0xFF2846DC, 'se': 0xFFE6C81E};

  static String quadrant(double lat, double lon, double lat0, double lon0) => '${lat >= lat0 ? 'n' : 's'}${lon < lon0 ? 'w' : 'e'}';

  @override
  Future<Uint8List> bytes(String url) async {
    urls.add(url);
    if (offline) throw StateError('offline');
    // Esri: /tile/z/row/column
    final m = RegExp(r'/tile/(\d+)/(\d+)/(\d+)').firstMatch(url)!;
    final z = int.parse(m.group(1)!), y = int.parse(m.group(2)!), x = int.parse(m.group(3)!);
    final n = math.pow(2, z).toDouble();
    final lon = (x + 0.5) / n * 360 - 180;
    final v = math.pi * (1 - 2 * (y + 0.5) / n);
    final lat = math.atan((math.exp(v) - math.exp(-v)) / 2) * 180 / math.pi;
    final argb = colours[quadrant(lat, lon, lat0, lon0)]!;
    return _png[argb] ??= Uint8List.fromList(img.encodePng(img.fill(img.Image(width: 256, height: 256), color: img.ColorRgb8((argb >> 16) & 0xFF, (argb >> 8) & 0xFF, argb & 0xFF))));
  }

  @override
  Future<String> text(String method, String url, {Map<String, String> headers = const {}, String? body}) async => throw StateError('no Google here');
}

/// The base map under the plot sheets: downloaded for everything the sheets
/// show (not the part of the drawing the screen happened to show), placed
/// on its georeference, stored once in the PDF however many sheets show it,
/// and the view on screen when nothing can be downloaded.
void main() {
  late ProjectController c;
  setUp(() async {
    LocalProjectStore().clearAll();
    c = ProjectController()
      ..autosaveEnabled = false
      ..designRunner = InThreadDesignRunner();
    c.newProject();
    await c.setLanguage('en', persist: false);
    loadExampleAction(c, ExampleId.orchard);
    c.project.meta.georef = GeoReference.fromLatLonOrigin(-20.3, -47.4);
    c.baseMap = BaseMap.satellite;
  });

  /// Tiles split into quadrants at the centre of what the sheets of [o] show.
  (_QuadrantTiles, Bounds) tilesFor(SheetOptions o) {
    var all = Bounds.empty;
    for (final (v, _) in c.exporter().sheetBuilder().sheetViews(o)) {
      all = all.union(v);
    }
    final (lat, lon) = c.project.meta.georef!.toLatLon(all.center.x, all.center.y);
    return (_QuadrantTiles(lat, lon), all);
  }

  Bounds boundsOf(List<Pt> corners) => Bounds.ofPoints(corners);

  testWidgets('the map covers every sheet, north up, each quadrant where the georeference puts it', (tester) async {
    const o = SheetOptions(page: PageSize.a4);
    final (tiles, views) = tilesFor(o);
    late SheetOptions out;
    late img.Image picture;
    await tester.runAsync(() async {
      out = await withSheetBaseMap(c, o, fetcher: tiles);
      picture = img.decodeJpg(out.rasters.single.bytes)!;
    });
    final r = out.rasters.single;
    expect(r.mime, 'image/jpeg');
    expect(r.opacity, c.baseMapOpacity);
    expect(out.attribution, BaseMapLayer.attribution(BaseMap.satellite));
    expect(tiles.urls, isNotEmpty);
    final b = boundsOf(r.corners);
    expect(b.minX, lessThanOrEqualTo(views.minX + 1e-6));
    expect(b.minY, lessThanOrEqualTo(views.minY + 1e-6));
    expect(b.maxX, greaterThanOrEqualTo(views.maxX - 1e-6));
    expect(b.maxY, greaterThanOrEqualTo(views.maxY - 1e-6));
    expect(b.maxX - views.maxX, lessThan(1), reason: 'not more than a pixel beyond the sheets');
    // square pixels at the print resolution (200 dpi at the sheet's scale), within the size limits
    final mpp = b.width / picture.width;
    expect(b.height / picture.height, closeTo(mpp, 1e-6));
    final scale = c.exporter().sheetBuilder().sheetScale(o);
    expect(mpp, greaterThanOrEqualTo(scale / 1000 * 25.4 / sheetMapDpi - 1e-9));
    expect(math.max(picture.width, picture.height), lessThanOrEqualTo(sheetMapMaxSide));
    // the four quadrants around the centre of the sheets
    List<int> rgbAt(Pt p) {
      final px = picture.getPixel(((p.x - b.minX) / mpp).floor(), ((b.maxY - p.y) / mpp).floor());
      return [px.r.toInt(), px.g.toInt(), px.b.toInt()];
    }

    final ctr = views.center;
    final dx = views.width * 0.4, dy = views.height * 0.4;
    for (final (q, p) in [('nw', Pt(ctr.x - dx, ctr.y + dy)), ('ne', Pt(ctr.x + dx, ctr.y + dy)), ('sw', Pt(ctr.x - dx, ctr.y - dy)), ('se', Pt(ctr.x + dx, ctr.y - dy))]) {
      final want = _QuadrantTiles.colours[q]!;
      final got = rgbAt(p);
      for (final (i, shift) in [(0, 16), (1, 8), (2, 0)]) {
        expect(got[i], closeTo((want >> shift) & 0xFF, 40), reason: '$q at $p: $got');
      }
    }
  });

  testWidgets('a set of sheets: the map spans the zone sheets and windows too, one image in the PDF', (tester) async {
    final window = SheetWindow(bounds: Bounds(c.project.bounds.maxX + 300, c.project.bounds.minY, c.project.bounds.maxX + 340, c.project.bounds.minY + 40), title: 'Well');
    final o = SheetOptions(page: PageSize.a4, split: SheetSplit.zones, windows: [window]);
    final views = c.exporter().sheetBuilder().sheetViews(o);
    expect(views.length, greaterThan(2), reason: 'overview, zones and the window');
    final (tiles, all) = tilesFor(o);
    late SheetOptions out;
    await tester.runAsync(() async => out = await withSheetBaseMap(c, o, fetcher: tiles));
    final b = boundsOf(out.rasters.single.corners);
    for (final (v, _) in views) {
      expect(b.minX <= v.minX + 1e-6 && b.minY <= v.minY + 1e-6 && b.maxX >= v.maxX - 1e-6 && b.maxY >= v.maxY - 1e-6, isTrue, reason: 'view $v');
    }
    expect(b.minX, lessThanOrEqualTo(all.minX + 1e-6));
    expect(b.maxX, greaterThanOrEqualTo(window.bounds.maxX));
    // every sheet draws the same JPEG, which the PDF holds once
    final pdf = latin1.decode(c.exporter().pdfSheet(out));
    expect(RegExp(r'/Type /Page\b').allMatches(pdf).length, views.length);
    expect(RegExp(r'/Subtype /Image').allMatches(pdf).length, 1);
    expect(pdf, contains('/Filter /DCTDecode'));
  });

  testWidgets('offline: the map seen on screen; no georeference or no base map: no map', (tester) async {
    final (online, _) = tilesFor(const SheetOptions());
    final tiles = _QuadrantTiles(online.lat0, online.lon0, offline: true);
    final screen = Uint8List.fromList(img.encodePng(img.Image(width: 4, height: 4)));
    final corners = [const Pt(0, 0), const Pt(10, 0), const Pt(10, 10), const Pt(0, 10)];
    c.baseMapSnapshot = () async => (screen, corners);
    c.baseMapAttribution = () => 'Screen credit';
    late SheetOptions out;
    await tester.runAsync(() async => out = await withSheetBaseMap(c, const SheetOptions(), fetcher: tiles));
    expect(tiles.urls, isNotEmpty, reason: 'the download was tried first');
    expect(out.rasters.single.bytes, same(screen));
    expect(out.rasters.single.corners, corners);
    expect(out.attribution, 'Screen credit');
    // nothing on screen either
    c.baseMapSnapshot = () async => null;
    await tester.runAsync(() async => out = await withSheetBaseMap(c, const SheetOptions(), fetcher: tiles));
    expect(out.rasters, isEmpty);
    // no base map shown, or no georeference: nothing is downloaded
    final quiet = _QuadrantTiles(0, 0);
    c.baseMap = BaseMap.none;
    await tester.runAsync(() async => out = await withSheetBaseMap(c, const SheetOptions(), fetcher: quiet));
    expect(out.rasters, isEmpty);
    c.baseMap = BaseMap.satellite;
    c.project.meta.georef = null;
    await tester.runAsync(() async => out = await withSheetBaseMap(c, const SheetOptions(), fetcher: quiet));
    expect(out.rasters, isEmpty);
    expect(quiet.urls, isEmpty);
  });

  testWidgets('the assistant\'s PDF export downloads the map for its sheets too', (tester) async {
    final files = <String, Object>{};
    final save = engFileSink;
    engFileSink = (c, name, mime, data) async => files[name] = data;
    addTearDown(() => engFileSink = save);
    c.baseMapSnapshot = () async => null; // a canvas is there
    final (tiles, _) = tilesFor(const SheetOptions(page: PageSize.a4));
    final op = exportOperations(AgentToolbox(c, snapshots: CanvasSnapshots(tiles: tiles))).firstWhere((t) => t.name == 'export_sheet_pdf');
    late String text;
    await tester.runAsync(() async => text = (await op.run({'page': 'a4'})).text);
    expect(text, contains('base map under the drawing'));
    expect(tiles.urls, isNotEmpty);
    final pdf = latin1.decode(files.values.single as Uint8List);
    expect(pdf, contains('/Filter /DCTDecode'));
  });
}
