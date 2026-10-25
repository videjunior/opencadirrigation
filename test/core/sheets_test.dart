import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/report_tables.dart';
import 'package:opencadirrigation/core/design/results.dart';
import 'package:opencadirrigation/core/io/details.dart';
import 'package:opencadirrigation/core/io/pdf.dart';
import 'package:opencadirrigation/core/io/pdf_sheet.dart';
import 'package:opencadirrigation/core/io/plot.dart';
import 'package:opencadirrigation/core/io/plot_charts.dart';
import 'package:opencadirrigation/core/io/project_export.dart';
import 'package:opencadirrigation/core/io/sheet_canvas.dart';
import 'package:opencadirrigation/core/io/sheet_set.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/units.dart';

final i18n = I18n('pt');

/// The orchard example (two zones in two irrigated areas, a pump and a
/// filter on the mainline), designed.
(Project, DesignResults) orchard() {
  final p = buildExample(ExampleId.orchard, i18n.call, lang: 'pt');
  return (p, Designer(p, label: (k) => i18n(k)).designAll());
}

PdfSheetBuilder builderFor(Project p, DesignResults? r) => PdfSheetBuilder(project: p, results: r, t: i18n.call, units: p.params.units);

int pageCount(List<int> pdf) => int.parse(RegExp(r'/Count (\d+)').firstMatch(latin1.decode(pdf))!.group(1)!);

String strip(String s) => s.replaceAll(RegExp(r'/CreationDate \(D:\d+\)'), '');

void main() {
  group('sets of sheets', () {
    test('one sheet stays the classic sheet; a recorded sheet replays to the same page', () {
      final (p, r) = orchard();
      final b = builderFor(p, r);
      expect(b.sheetCount(const SheetOptions()), 1);
      expect(pageCount(b.buildSheet(const SheetOptions())), 1);
      // drawn directly or recorded and replayed on a page: the same PDF
      final a = PdfDocument(title: 'x');
      b.addSheetPage(a, const SheetOptions());
      final c = PdfDocument(title: 'x');
      b.recordSheet(const SheetOptions()).replay(PdfSheetCanvas(c.addPage(widthPt: 420 * ptPerMm, heightPt: 297 * ptPerMm)));
      expect(strip(latin1.decode(c.build(compress: false))), strip(latin1.decode(a.build(compress: false))));
      final texts = b.recordSheet(const SheetOptions()).texts.toList();
      expect(texts, contains('1/1'));
      expect(texts, isNot(contains(i18n('sheet.overview'))), reason: 'a single sheet has no sheet title');
    });

    test('overview plus one sheet per zone: fitted to the zone, the other zone greyed, sheet numbers', () {
      final (p, r) = orchard();
      final b = builderFor(p, r);
      const o = SheetOptions(split: SheetSplit.zones);
      final plan = b.sheetPlan(o);
      final valves = p.entities.whereType<ControlValveEntity>().toList();
      expect(plan, hasLength(1 + valves.length));
      expect(plan.first.kind, SheetKind.overview);
      expect(plan.first.title, i18n('sheet.overview'));
      final members = zoneMembers(p, r);
      for (final s in plan.skip(1)) {
        expect(s.kind, SheetKind.zone);
        final id = s.zones.single;
        expect(s.title, valves.firstWhere((v) => v.id == id).zoneName);
        // the window holds the zone, the scale is closer than the overview's
        for (final e in members[id]!) {
          final eb = p.byId(e)!.bounds;
          expect(s.window!.contains(eb.center), isTrue, reason: e);
        }
        expect(s.scale, lessThanOrEqualTo(plan.first.scale!));
        expect(s.muted.intersection(members[id]!), isEmpty);
        expect(s.muted, containsAll(members.entries.where((m) => m.key != id).expand((m) => m.value).where((x) => !members[id]!.contains(x))));
      }
      final pdf = b.buildSheet(o);
      expect(pageCount(pdf), plan.length);
      final second = b.recordSheet(o, index: 1).texts.toList();
      expect(second, contains('2/${plan.length} · ${plan[1].title}'));
      expect(second, contains(plan[1].title), reason: 'caption in the drawing');
      expect(second.any((x) => x.startsWith('1:${plan[1].scale!.round()}  (')), isTrue, reason: 'the scale of the zone sheet');
    });

    test('a zone sheet lists the zone\'s own materials; the other zones can be left out', () {
      final (p, r) = orchard();
      final b = builderFor(p, r);
      final plan = b.sheetPlan(const SheetOptions(split: SheetSplit.zones));
      final zone = plan[1];
      final own = r.bomByZone[zone.zones.single]!;
      final texts = b.recordSheet(const SheetOptions(split: SheetSplit.zones), index: 1).texts.toList();
      expect(texts, contains(i18n('pdf.bom')));
      final shown = own.where((l) => l.quantity > 0).map((l) => l.description).toSet();
      expect(texts.where(shown.contains), isNotEmpty);
      // greyed (default) or hidden: the other zone's laterals
      final other = zoneMembers(p, r).entries.firstWhere((e) => e.key != zone.zones.single).value;
      final lateral = other.firstWhere((id) => p.byId(id) is SpraylineEntity || p.byId(id) is TapeEntity);
      PlotScene scene({required bool hide}) => buildPlotScene(
        p,
        results: r,
        unitsPerMm: 0.5,
        options: PlotOptions(muted: zone.muted, hideMuted: hide),
      );
      final pts = (p.byId(lateral)! as PolyEntity).points;
      bool drawn(PlotScene s) => s.items.whereType<PlotPath>().any((x) => identical(x.points, pts));
      final grey = scene(hide: false);
      expect(drawn(grey), isTrue);
      final path = grey.items.whereType<PlotPath>().firstWhere((x) => identical(x.points, pts));
      expect(path.color, mutedColor(printColor(p.layerNamed(p.byId(lateral)!.layer).color)));
      expect(drawn(scene(hide: true)), isFalse);
    });

    test('overview plus one sheet per irrigated area; windows of the view with their own scale', () {
      final (p, r) = orchard();
      final b = builderFor(p, r);
      final areas = p.entities.whereType<AreaEntity>().toList();
      final plan = b.sheetPlan(const SheetOptions(split: SheetSplit.areas));
      expect(plan, hasLength(1 + areas.length));
      for (var i = 0; i < areas.length; i++) {
        final s = plan[i + 1];
        expect(s.kind, SheetKind.area);
        expect(s.title, areas[i].name);
        expect(
          s.muted,
          containsAll([
            for (final a in areas)
              if (a.id != areas[i].id) a.id,
          ]),
        );
        expect(s.zones, isNotEmpty, reason: 'each block of the orchard has its zone');
        expect(s.window!.contains(Bounds.ofPoints(areas[i].points).center), isTrue);
      }
      // a window: its scale and title
      final w = SheetWindow(bounds: Bounds.ofPoints(areas.first.points), scale: 250, title: 'Detalhe');
      final o = SheetOptions(windows: [w]);
      final withWindow = b.sheetPlan(o);
      expect(withWindow, hasLength(2));
      expect(withWindow.last.scale, 250);
      final texts = b.recordSheet(o, index: 1).texts.toList();
      expect(texts, contains('2/2 · Detalhe'));
      expect(texts.any((x) => x.startsWith('1:250')), isTrue);
      expect(pageCount(b.buildSheet(o)), 2);
    });

    test('a project without zones splits into the overview alone, the classic sheet', () {
      final p = Project()..entities.add(LineEntity(id: 'e1', a: Pt.zero, b: const Pt(50, 20)));
      final b = builderFor(p, null);
      expect(b.sheetPlan(const SheetOptions(split: SheetSplit.zones)), hasLength(1));
      expect(b.recordSheet(const SheetOptions(split: SheetSplit.zones)).texts, contains('1/1'));
      expect(zoneMembers(p), isEmpty);
    });

    test('zone members come from the network when there are no results', () {
      final (p, r) = orchard();
      final fromResults = zoneMembers(p, r), fromNetwork = zoneMembers(p);
      expect(fromNetwork.keys.toSet(), fromResults.keys.toSet());
      for (final k in fromResults.keys) {
        // every lateral of the zone is found both ways
        final laterals = {
          for (final id in fromResults[k]!)
            if (p.byId(id) is SpraylineEntity || p.byId(id) is TapeEntity) id,
        };
        expect(fromNetwork[k], containsAll(laterals));
      }
      expect(naturalCompare('Zona 2', 'Zona 10'), lessThan(0));
    });
  });

  group('entities printed on the sheets', () {
    Project annotated() {
      final p = Project();
      p.entities.addAll([
        LineEntity(id: 'e1', a: Pt.zero, b: const Pt(100, 60)),
        RevisionCloudEntity(id: 'e2', points: const [Pt(10, 10), Pt(40, 10), Pt(40, 30), Pt(10, 30)], revision: 'B', date: '2026-10-25', description: 'Válvula deslocada'),
        RevisionCloudEntity(id: 'e3', points: const [Pt(50, 10), Pt(70, 10), Pt(70, 25)], revision: 'A', date: '2026-10-01', description: 'Emissão inicial'),
        CommentEntity(id: 'e4', position: const Pt(60, 40), text: 'Conferir\ncota', author: 'MJ'),
        CommentEntity(id: 'e5', position: const Pt(20, 50), text: 'Resolvido', resolved: true),
        BreaklineEntity(id: 'e6', points: const [Pt(0, 55), Pt(50, 58), Pt(100, 55)], elevations: [101.25, double.nan, 99.5]),
      ]);
      return p;
    }

    test('revision clouds, open comments and breaklines; resolved comments left out', () {
      final p = annotated();
      final scene = buildPlotScene(p, unitsPerMm: 0.5, t: i18n.call);
      final texts = scene.items.whereType<PlotText>().map((x) => x.text).toList();
      // the cloud: a closed scalloped outline and its tag
      final cloud = scene.items.whereType<PlotPath>().where((x) => x.layer == Layers.revisions && x.closed && x.points.length > 20);
      expect(cloud, hasLength(2));
      expect(texts, containsAll(['B', 'A']));
      // the open comment, on one line with its author; the resolved one is not printed
      expect(texts, contains('MJ: Conferir cota'));
      expect(texts, isNot(contains('Resolvido')));
      expect(scene.items.where((x) => x.layer == Layers.comments), hasLength(2), reason: 'balloon and text of the open comment');
      // breakline: dashed, with the typed elevations only
      expect(scene.items.whereType<PlotPath>().where((x) => x.layer == Layers.breaklines && x.dashed), hasLength(1));
      expect(texts, containsAll(['101.25', '99.50']));
      expect(texts.where((x) => x == 'NaN' || x == '-'), isEmpty);
    });

    test('the revision table lists every revision under the legend', () {
      final p = annotated();
      final b = builderFor(p, null);
      final texts = b.recordSheet(const SheetOptions()).texts.toList();
      expect(texts, contains(i18n('pdf.revisions')));
      expect(texts.join(' '), allOf(contains('Válvula deslocada'), contains('Emissão inicial'), contains('2026-10-25')));
      // oldest revision drawn first (bottom row)
      expect(texts.indexOf('2026-10-01'), lessThan(texts.indexOf('2026-10-25')));
      expect(b.revisions.map((r) => r.revision), ['A', 'B']);
    });

    test('a culling window leaves out what the sheet would clip', () {
      final p = annotated()..entities.add(LineEntity(id: 'far', a: const Pt(5000, 5000), b: const Pt(5100, 5000)));
      final all = buildPlotScene(p, unitsPerMm: 0.5);
      final near = buildPlotScene(p, unitsPerMm: 0.5, options: const PlotOptions(window: Bounds(-10, -10, 200, 200)));
      bool hasFar(PlotScene s) => s.items.whereType<PlotPath>().any((x) => x.points.any((q) => q.x >= 5000));
      expect(hasFar(all), isTrue);
      expect(hasFar(near), isFalse);
      expect(near.items.length, all.items.length - 1);
    });
  });

  group('construction details', () {
    test('every detail draws at a nice scale with notes from the design', () {
      final (p, r) = orchard();
      final ctx = DetailContext.of(p, r);
      expect(ctx.mainPipeName, isNotEmpty);
      expect(ctx.pumpName, isNotEmpty);
      expect(ctx.filterCount, greaterThan(0));
      for (final k in DetailKind.values) {
        final d = buildDetail(k, ctx, widthMm: 95, heightMm: 90, t: i18n.call);
        expect(d.items, isNotEmpty, reason: k.name);
        expect(detailScales.map((s) => s.toDouble()), contains(d.scale), reason: k.name);
        expect(d.notes, isNotEmpty, reason: k.name);
        expect(d.title, i18n(detailTitleKey(k, ctx)));
        final texts = d.items.whereType<PlotText>().map((x) => x.text).join(' | ');
        expect(texts, isNot(contains('det.')), reason: 'translated captions of ${k.name}');
        // drawn to fit the cell (text included, give or take the callouts)
        expect(d.bounds.width / d.unitsPerMm, lessThan(95 * 1.25), reason: k.name);
      }
    });

    test('the trench follows the quote settings and the pipe; dimensions in the project units', () {
      final p = Project();
      final spec = p.catalog.pipes.reduce((a, b) => a.nominalMm >= b.nominalMm ? a : b);
      p.entities.add(PipeEntity(id: 'e1', points: const [Pt(0, 0), Pt(100, 0)], scope: HydraulicScope.mainline, pipeSpecId: spec.id, depth: 0.8));
      p.proposal.trenchWidthM = 0.5;
      p.proposal.beddingM = 0.15;
      final ctx = DetailContext.of(p);
      expect(ctx.mainOdM, closeTo(spec.nominalMm / 1000, 1e-12));
      expect(ctx.mainAxisDepth, 0.8);
      expect(ctx.trenchWidth, 0.5);
      final d = buildDetail(DetailKind.trench, ctx, widthMm: 95, heightMm: 90, t: i18n.call);
      final texts = d.items.whereType<PlotText>().map((x) => x.text).toList();
      final depth = 0.8 + spec.nominalMm / 2000 + 0.15;
      expect(texts, containsAll(['0.50 m', '${fmt(depth, 2)} m', '0.15 m']));
      expect(d.notes.first, i18n('det.n.trench', {'d': '0.80 m', 'w': '0.50 m', 'h': '${fmt(depth, 2)} m'}));
      // US customary units
      p.params.units = Units.us;
      final us = buildDetail(DetailKind.trench, DetailContext.of(p), widthMm: 95, heightMm: 90, t: i18n.call);
      expect(us.items.whereType<PlotText>().map((x) => x.text), contains('${fmt(0.5 / 0.3048, 2)} ft'));
      // without a depth: the usual minimum cover, said in a note
      p.params.units = Units.metric;
      (p.entities.first as PipeEntity).depth = 0;
      final noDepth = DetailContext.of(p);
      expect(noDepth.mainAxisDepth, closeTo(DetailContext.minimumCover(noDepth.mainOdM) + noDepth.mainOdM / 2, 1e-12));
      expect(buildDetail(DetailKind.trench, noDepth, widthMm: 95, heightMm: 90, t: i18n.call).notes.join(), contains('ASAE S376.2'));
    });

    test('thrust block sized from the test pressure; suction submergence from the pipe', () {
      final ctx = DetailContext(mainOdM: 0.1, maxWorkingHeadM: 40, mainPipeName: 'PVC 100');
      expect(ctx.thrustHeadM, 60);
      final d = buildDetail(DetailKind.thrustBlock, ctx, widthMm: 95, heightMm: 90, t: i18n.call);
      // T = 2·p·A·sin 45°, p = 60 m of water, A = π·0.1²/4
      final p = 60 * gravity * waterDensity / 1000, a = 3.141592653589793 * 0.01 / 4;
      expect(d.notes.first, contains('${fmt(2 * p * a * 0.7071067811865476, 1)} kN'));
      expect(d.notes[1], contains('${fmt(2 * p * a * 0.7071067811865476 / 50, 3)} m²'));
      final s = buildDetail(DetailKind.pumpSuction, DetailContext(mainOdM: 0.1, suctionLiftM: 4), widthMm: 95, heightMm: 90, t: i18n.call);
      expect(s.notes[1], contains('0.35 m'), reason: 'S = 2.5·0.1 + 0.1');
      expect(s.notes.first, contains('4.00 m'));
      // a submersible pump says the detail is for surface pumps
      expect(buildDetail(DetailKind.pumpSuction, DetailContext(submersible: true), widthMm: 95, heightMm: 90, t: i18n.call).notes.last, i18n('det.n.submersible'));
      // a sprinkler with a riser, or a pop-up on a swing joint
      expect(detailTitleKey(DetailKind.sprinklerRiser, DetailContext(riserHeightM: 1)), 'det.sprinklerRiser');
      expect(detailTitleKey(DetailKind.sprinklerRiser, DetailContext()), 'det.sprinklerSwing');
      expect(wrapText('um dois três quatro', 9), ['um dois', 'três', 'quatro']);
    });

    test('detail sheets after the drawing sheets, numbered with them', () {
      final (p, r) = orchard();
      final b = builderFor(p, r);
      const o = SheetOptions(details: DetailKind.values);
      final sheets = b.detailSheets(o);
      expect(sheets.expand((x) => x), DetailKind.values);
      expect(sheets, hasLength(1), reason: 'eight details fit an A3 sheet');
      expect(b.detailSheets(const SheetOptions(page: PageSize.a4, landscape: false, details: DetailKind.values)).length, greaterThan(1));
      expect(b.sheetCount(o), 2);
      expect(pageCount(b.buildSheet(o)), 2);
      final texts = b.recordSheet(o, index: 1).texts.toList();
      expect(texts, contains('2/2 · ${i18n('det.title')}'));
      expect(texts, contains(i18n('det.trench')));
      expect(texts.any((x) => x.startsWith(i18n('det.scaleAsShown'))), isTrue);
      expect(texts, containsAll(['1', '8']), reason: 'numbered cells');
    });
  });

  group('charts', () {
    test('the critical mainline path runs from the supply to the valve with the least margin', () {
      final (p, r) = orchard();
      for (final f in r.systemFlows) {
        final path = criticalMainlinePath(p, f);
        expect(path, isNotEmpty, reason: f.name);
        final supply = p.byId(f.supplies.first.supplyId)! as WaterSupplyEntity;
        final first = path.first.forward ? path.first.seg.a : path.first.seg.b;
        final last = path.last.forward ? path.last.seg.b : path.last.seg.a;
        final valve = f.valves.reduce((a, b) => a.deficit >= b.deficit ? a : b);
        expect(first.distanceTo(supply.position), lessThan(1));
        expect(last.distanceTo(valve.p), lessThan(1));
        // consecutive steps share their ends
        for (var i = 1; i < path.length; i++) {
          final end = path[i - 1].forward ? path[i - 1].seg.b : path[i - 1].seg.a;
          final start = path[i].forward ? path[i].seg.a : path[i].seg.b;
          expect(end.distanceTo(start), lessThan(0.011));
        }
      }
    });

    test('grade line, profile and pump curves with the duty points', () {
      final (p, r) = orchard();
      final charts = designCharts(p, r, t: i18n.call, u: p.params.units);
      final hgl = charts.where((c) => c.title.startsWith(i18n('chart.hglTitle', {'f': ''}).trim())).toList();
      expect(hgl, hasLength(r.systemFlows.length));
      for (final c in hgl) {
        final line = c.series.firstWhere((s) => s.label == i18n('chart.hgl'));
        for (var i = 1; i < line.points.length; i++) {
          expect(line.points[i].$1, greaterThanOrEqualTo(line.points[i - 1].$1), reason: 'stations increase');
        }
        expect(c.markers, hasLength(2));
      }
      final pump = p.entities.whereType<PumpEntity>().first;
      final pumpChart = charts.firstWhere((c) => c.title.contains(p.catalog.pump(pump.pumpSpecId)!.name));
      final duties = r.systemFlows.expand((f) => f.devices).where((d) => d.entityId == pump.id && d.flow > 0).toList();
      expect(pumpChart.markers.where((m) => m.label.isNotEmpty), hasLength(duties.length));
      expect(pumpChart.notes, hasLength(duties.length));
      // each duty point sits on the curve at its speed
      final curve = p.catalog.pump(pump.pumpSpecId)!.curve;
      for (final d in duties) {
        expect(d.pumpHead, closeTo(curve.withSpeed(d.speedRatio).head(d.flow), 0.5));
      }
      // a path drawn with the profile tool gets its own chart when the terrain allows
      final drawn = designCharts(p, r, t: i18n.call, profilePath: [p.bounds.center, p.bounds.center + const Pt(50, 0)]);
      expect(drawn.length, charts.length + (p.buildTerrain().isEmpty ? 0 : 1));
    });

    test('chart layout stays in its frame; chart pages follow the reports', () {
      final chart = PlotChart(
        title: 'T',
        xLabel: 'x',
        yLabel: 'y',
        series: const [
          ChartSeries(label: 'a', points: [(0, 10), (50, 12), (120, 9)]),
        ],
        markers: const [ChartMarker(x: 120, y: 9, label: 'end')],
      );
      final scene = chartScene(chart, widthMm: 200, heightMm: 70);
      for (final it in scene.items.whereType<PlotPath>()) {
        for (final q in it.points) {
          expect(q.x >= -1e-9 && q.x <= 200 + 1e-9 && q.y >= -1e-9 && q.y <= 70 + 1e-9, isTrue);
        }
      }
      expect(niceTicks(0, 120), [0, 20, 40, 60, 80, 100, 120]);
      expect(niceTicks(0.3, 1.1, target: 4), [0.4, 0.6, 0.8, 1.0]);
      final (p, r) = orchard();
      final b = builderFor(p, r);
      final labels = ReportLabels(t: i18n.call, has: i18n.has, warning: (w) => i18n.warning(w));
      final tables = ProjectExporter(project: p, results: r, labels: labels).reportTables();
      final plain = pageCount(b.buildSheet(const SheetOptions(includeReports: true), reports: tables));
      final withCharts = pageCount(b.buildSheet(const SheetOptions(includeReports: true, charts: true), reports: tables));
      expect(withCharts, greaterThan(plain));
      // charts alone, on their own pages
      expect(pageCount(b.buildSheet(const SheetOptions(charts: true))), greaterThan(1));
    });
  });
}
