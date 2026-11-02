import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/core/design/report_tables.dart';
import 'package:opencadirrigation/core/design/slope_report.dart';
import 'package:opencadirrigation/core/io/pdf_sheet.dart';
import 'package:opencadirrigation/core/io/sheet_theme.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

final i18n = I18n('pt');

/// A field of 200 × 200 m that rises 1.5 % to the east up to x = 100 and
/// 8 % beyond (spot heights every 10 m), with an irrigated area on each side.
Project kinked() {
  final p = Project();
  for (var x = 0.0; x <= 200; x += 10) {
    for (var y = 0.0; y <= 200; y += 10) {
      final z = x <= 100 ? 100 + 0.015 * x : 101.5 + 0.08 * (x - 100);
      p.entities.add(SpotHeightEntity(id: p.newId(), position: Pt(x, y), elevation: z));
    }
  }
  p.entities.add(AreaEntity(id: p.newId(), name: 'Gentle', points: [const Pt(10, 20), const Pt(90, 20), const Pt(90, 180), const Pt(10, 180)]));
  p.entities.add(AreaEntity(id: p.newId(), name: 'Steep', points: [const Pt(110, 20), const Pt(190, 20), const Pt(190, 180), const Pt(110, 180)]));
  return p;
}

ReportLabels labels() => ReportLabels(t: i18n.call, has: i18n.has, warning: i18n.warning);

/// The slope map in the PDF and the area of each slope class (1.6.0 PRD,
/// PRD-30).
void main() {
  test('the area of each slope class inside each irrigated area', () {
    final p = kinked();
    final rows = areaSlopeClasses(p);
    expect(rows.map((r) => r.$1.name), ['Gentle', 'Steep']);
    final (_, gentle) = rows[0];
    final (_, steep) = rows[1];
    // 80 × 160 m = 1.28 ha each, all in one class
    expect(gentle.mapped, closeTo(12800, 400));
    expect(gentle.share(0), greaterThan(0.97), reason: '1.5 % is in 0–2 %');
    expect(steep.share(2), greaterThan(0.97), reason: '8 % is in 5–10 %');
    expect(gentle.meanPct, closeTo(1.5, 0.1));
    expect(steep.maxPct, closeTo(8, 0.2));
    expect(gentle.noData, lessThan(400));
    expect(identical(areaSlopeClasses(p), rows), isTrue, reason: 'made once while nothing changes');
    p.entities.whereType<AreaEntity>().first.points[1] = const Pt(80, 20);
    expect(identical(areaSlopeClasses(p), rows), isFalse, reason: 'an outline that moved is measured again');
    expect(slopeClassLabel(0), '0–2 %');
    expect(slopeClassLabel(7), '> 45 %');
  });

  test('the report table, with its standard, without design results', () {
    final p = kinked();
    final tables = buildReportTables(project: p, results: null, labels: labels());
    final tb = tables.firstWhere((t) => t.key == 'slopeClasses');
    expect(tb.title, i18n('prd.rep.slope'));
    expect(tb.rows.length, 3, reason: 'two areas and the total');
    expect(tb.headers, contains('0–2 % (ha)'));
    final gentle = tb.rows.first;
    expect(gentle.first, 'Gentle');
    expect((gentle[4] as RNum).value, closeTo(1.28, 0.05), reason: 'the 0–2 % class of the gentle area, in ha');
    expect(tb.ids, [for (final a in p.entities.whereType<AreaEntity>()) a.id]);
    expect(tb.standards, contains('USDA Soil Survey Manual'));
    // no terrain: no table
    final flat = Project()..entities.add(AreaEntity(id: 'a1', points: const [Pt(0, 0), Pt(10, 0), Pt(10, 10)]));
    expect(buildReportTables(project: flat, results: null, labels: labels()).any((t) => t.key == 'slopeClasses'), isFalse);
  });

  test('the slope and aspect sheets: the classes under the drawing with their key', () {
    final p = kinked();
    final b = PdfSheetBuilder(project: p, t: i18n.call, units: p.params.units);
    const o = SheetOptions(themes: [SheetTheme.slope, SheetTheme.aspect]);
    final plan = b.sheetPlan(o);
    expect([for (final s in plan) s.theme], [null, SheetTheme.slope, SheetTheme.aspect]);
    expect(plan.first.title, i18n('sheet.overview'), reason: 'a set of sheets now');
    final slope = b.recordSheet(o, index: 1);
    final texts = slope.texts.toList();
    expect(texts, containsAll([i18n('prd.sheet.slope'), i18n('prd.sheet.slopeKey'), '0–2 %', '5–10 %', 'Gentle', 'Steep']));
    expect(texts.any((s) => s.startsWith('2/3')), isTrue);
    // the cells are drawn as filled runs of the class colours
    final m = ThemeMap.of(p, SheetTheme.slope)!;
    expect(m.areas[0], closeTo(m.areas[2], m.mappedArea * 0.1), reason: 'half gentle, half steep');
    final aspect = b.recordSheet(o, index: 2).texts.toList();
    expect(aspect, contains(i18n('prd.sheet.aspectKey')));
    expect(aspect, contains(i18n('compass.w')), reason: 'the ground falls to the west');
    final a = ThemeMap.of(p, SheetTheme.aspect)!;
    expect(a.areas[6] / a.mappedArea, greaterThan(0.9), reason: 'west sector');
    // no terrain: no thematic sheet
    final none = PdfSheetBuilder(
      project: Project()..entities.add(AreaEntity(id: 'a1', points: const [Pt(0, 0), Pt(10, 0), Pt(10, 10)])),
      t: i18n.call,
    );
    expect(none.sheetCount(o), 1);
  });
}
