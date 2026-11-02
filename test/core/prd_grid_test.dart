import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/core/io/fonts/pdf_fonts.dart';
import 'package:opencadirrigation/core/io/geo.dart';
import 'package:opencadirrigation/core/io/pdf_sheet.dart';
import 'package:opencadirrigation/core/io/sheet_check.dart';
import 'package:opencadirrigation/core/io/sheet_grid.dart';
import 'package:opencadirrigation/core/model/geometry.dart';

final i18n = I18n('pt');

/// The coordinate grid of the sheets (1.6.0 PRD): UTM lines of the zone,
/// the graticule in degrees, their values inside the drawing area clear of
/// the sheet's marks.
void main() {
  test('grid steps are round and at least 35 mm apart on paper', () {
    expect(utmGridStep(1), 50, reason: '1:1000 → 35 m needed');
    expect(utmGridStep(2), 100);
    expect(utmGridStep(0.5), 20);
    expect(utmGridStep(10), 500);
    expect(graticuleStepSeconds(1), 2, reason: '35 m is about 1.1"');
    expect(graticuleStepSeconds(10), 15);
    expect(graticuleStepSeconds(100), 120);
  });

  test('degrees, minutes and seconds with the hemisphere of the language', () {
    expect(dmsText(-15.7916667, latitude: true, stepSeconds: 30, t: i18n.call), '15°47\'30"S');
    expect(dmsText(-47.9166667, latitude: false, stepSeconds: 300, t: i18n.call), '47°55\'O');
    expect(dmsText(-47.9166667, latitude: false, stepSeconds: 300, t: I18n('en').call), '47°55\'W');
    expect(dmsText(2, latitude: false, stepSeconds: 3600, t: i18n.call), '2°L');
  });

  test('UTM lines are eastings and northings of the zone; the graticule follows the parallels', () {
    final g = GeoReference.fromLatLonOrigin(-15.78, -47.93);
    const view = Bounds(-300, -200, 300, 200);
    final utm = utmGridLines(g, view, 100);
    final eastings = utm.where((l) => l.kind == GridLineKind.easting).toList();
    expect(eastings.length, inInclusiveRange(5, 7));
    for (final l in eastings) {
      expect(l.value % 100, 0);
      expect(l.points.first.x, closeTo(l.value - g.originEasting, 1e-6));
      expect(l.label, startsWith('E '));
    }
    expect(utm.where((l) => l.kind == GridLineKind.northing).every((l) => l.label.startsWith('N ')), isTrue);
    // without a georeference: the local grid
    expect(utmGridLines(null, view, 100).first.label, startsWith('X '));
    final geo = graticuleLines(g, view, 5, label: (v, lat) => dmsText(v, latitude: lat, stepSeconds: 5));
    final parallels = geo.where((l) => l.kind == GridLineKind.parallel).toList();
    expect(parallels, isNotEmpty);
    for (final l in parallels) {
      // every point of a parallel is at its latitude
      for (final p in l.points) {
        expect(g.toLatLon(p.x, p.y).$1, closeTo(l.value, 1e-7));
      }
    }
    expect(geo.where((l) => l.kind == GridLineKind.meridian), isNotEmpty);
  });

  test('a sheet prints the grid with its values, clear of the marks; none by default', () {
    final p = buildExample(ExampleId.orchard, i18n.call, lang: 'pt')..meta.georef = GeoReference.fromLatLonOrigin(-19.75, -47.93);
    final b = PdfSheetBuilder(project: p, t: i18n.call, units: p.params.units);
    final plain = b.recordSheet(const SheetOptions()).texts.toList();
    // the values of the grid lines (the origin in the title block, "E …  N …",
    // is printed on every georeferenced sheet)
    expect(plain.where((s) => RegExp(r'^[EN] \d+$').hasMatch(s)), isEmpty);
    final sheet = b.recordSheet(const SheetOptions(grid: SheetGrid.both));
    final texts = sheet.texts.toList();
    expect(texts.where((s) => RegExp(r'^E \d+$').hasMatch(s)), isNotEmpty);
    expect(texts.where((s) => RegExp(r'^N \d+$').hasMatch(s)), isNotEmpty);
    expect(texts.where((s) => s.contains('°') && (s.endsWith('S') || s.endsWith('O'))), isNotEmpty);
    expect(texts.any((s) => s.contains(i18n('prd.grid.noteUtm', {'s': ''}).trim())), isTrue, reason: 'the step is told');
    final review = SheetReview(sheet, fonts: PdfFonts.shared);
    final values = [
      for (final t in review.texts)
        if (RegExp(r'^[EN] \d+$').hasMatch(t.text) || t.text.contains('°')) t,
    ];
    expect(values.every((t) => t.region == 0), isTrue, reason: 'drawn in the drawing area');
    expect(review.cut().where((c) => values.contains(c.$1)), isEmpty, reason: 'no value runs off the drawing area');
    expect(values.every((t) => t.capMm >= 1.6), isTrue, reason: 'legible');
    final arrow = review.mark(SheetMarkKind.northArrow)!.box, bar = review.mark(SheetMarkKind.scaleBar)!.box;
    expect(values.where((t) => t.bounds.intersects(arrow) || t.bounds.intersects(bar)), isEmpty);
  });

  test('without a georeference the UTM grid is the local one and the graticule is left out', () {
    final p = buildExample(ExampleId.orchard, i18n.call, lang: 'pt')..meta.georef = null;
    final b = PdfSheetBuilder(project: p, t: i18n.call, units: p.params.units);
    final texts = b.recordSheet(const SheetOptions(grid: SheetGrid.both)).texts.toList();
    expect(texts.where((s) => RegExp(r'^X -?\d+$').hasMatch(s)), isNotEmpty);
    expect(texts.where((s) => s.contains('°') && s.endsWith('S')), isEmpty);
  });
}
