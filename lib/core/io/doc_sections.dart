/// The built-in sections of the document packages (1.6.0 PRD; see
/// doc_package.dart for how sections are made and added).
library;

import 'dart:math' as math;

import '../design/report_standards.dart';
import '../design/report_tables.dart';
import '../hydraulics/friction.dart' show FrictionMethod;
import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import '../model/title_block.dart';
import '../translate.dart';
import '../units.dart';
import 'doc_package.dart';
import 'pdf_sheet.dart';
import 'plot_charts.dart' show designCharts;
import 'title_block_sheet.dart' show sheetRevisions;

const _p = DocProfile.proposal, _l = DocProfile.permit, _i = DocProfile.installation, _m = DocProfile.memorial, _o = DocProfile.operation;

/// [deg] in degrees, minutes and seconds to a tenth of a second, with the
/// hemisphere letter ("15°47'30.5"S").
String docDms(double deg, {required bool latitude, Translate? t}) {
  final tenths = (deg.abs() * 36000).round();
  final d = tenths ~/ 36000, m = (tenths % 36000) ~/ 600, s = (tenths % 600) / 10;
  final hemi = latitude ? (deg < 0 ? 's' : 'n') : (deg < 0 ? 'w' : 'e');
  return '$d°${m.toString().padLeft(2, '0')}\'${s.toStringAsFixed(1).padLeft(4, '0')}"${t?.call('prd.grid.$hemi') ?? hemi.toUpperCase()}';
}

/// The site of the project: the centre of the drawing in UTM (with its
/// datum and zone) and in degrees; empty without a georeference.
String docSiteCoordinates(Project p, Translate t) {
  final g = p.meta.georef;
  if (g == null) return '';
  final b = p.bounds;
  final c = b.isEmpty ? Pt.zero : b.center;
  final (e, n) = g.toUtm(c.x, c.y);
  final (lat, lon) = g.toLatLon(c.x, c.y);
  return '${g.crsName}: E ${fmt(e, 0)} N ${fmt(n, 0)} · ${docDms(lat, latitude: true, t: t)} ${docDms(lon, latitude: false, t: t)}';
}

/// The irrigated area of [p] (m²).
double _irrigatedArea(Project p) => p.entities.whereType<AreaEntity>().fold(0.0, (a, e) => a + (e.points.length >= 3 ? e.area : 0));

String _stage(Translate t, ProjectStage s) => s == ProjectStage.none ? '' : t('prd.stage.${s.name}');

List<DocBlock> _identification(DocContext ctx) {
  final t = ctx.t, m = ctx.project.meta, tb = m.titleBlock;
  return [
    DocFields([
      (t('dlg.project'), m.name),
      (t('dlg.client'), m.client),
      (t('prd.tb.property'), m.site),
      (t('prd.tb.municipality'), tb.municipality),
      (t('prd.tb.car'), tb.car),
      (t('prd.tb.permit'), tb.waterPermit),
      (t('prd.tb.stage'), _stage(t, tb.stage)),
      (t('prd.doc.site'), docSiteCoordinates(ctx.project, t)),
      (t('prd.tb.company'), tb.company),
      (t('prd.tb.responsible'), tb.responsible),
      (t('prd.tb.registration'), tb.registrationText),
      (tb.recordName, tb.responsibilityRecord),
      (t('dlg.designer'), m.designer),
      (t('prd.tb.drawingNumber'), tb.drawingNumber),
      (t('pdf.rev'), tb.currentRevision),
    ]),
    if (m.notes.trim().isNotEmpty) DocParagraph(m.notes.trim()),
  ];
}

List<DocBlock> _summary(DocContext ctx) {
  final t = ctx.t, p = ctx.project, u = ctx.units, r = ctx.results;
  final m = p.meta;
  final zones = p.entities.whereType<ControlValveEntity>().length;
  final emitters = r != null && r.zones.isNotEmpty
      ? r.zones.values.fold<int>(0, (a, z) => a + z.emitterCount)
      : p.entities.fold<int>(0, (a, e) => a + (e is SpraylineEntity ? e.outletCount : (e is OutletEntity ? 1 : 0)));
  final area = _irrigatedArea(p);
  var flow = 0.0, head = 0.0;
  for (final f in r?.systemFlows ?? const []) {
    flow = math.max(flow, f.totalFlow);
    for (final s in f.supplies) {
      head = math.max(head, s.requiredHead);
    }
  }
  double length(bool Function(Entity e) test) => p.entities.where(test).fold(0.0, (a, e) => a + (e is PolyEntity ? polylineLength(e.points) : 0));
  final mainline = length((e) => e is PipeEntity && e.scope == HydraulicScope.mainline);
  final zonePipes = length((e) => e is PipeEntity && e.scope == HydraulicScope.zone);
  final laterals = length((e) => e is SpraylineEntity || e is TapeEntity);
  final pumps = <String>{for (final e in p.entities.whereType<PumpEntity>()) p.catalog.pump(e.pumpSpecId)?.name ?? (e.name.isEmpty ? t('tool.pump') : e.name)};
  final crops = <String>{
    for (final a in p.entities.whereType<AreaEntity>())
      if (a.crop.trim().isNotEmpty) a.crop.trim(),
  };
  String len(double v) => v > 0 ? '${fmt(u.lengthFromSi(v), 0)} ${u.lengthLabel}' : '';
  return [
    DocParagraph(
      t('prd.doc.intro.${ctx.profile.name}', {
        'client': m.client.trim().isEmpty ? t('prd.doc.theClient') : m.client.trim(),
        'site': m.site.trim().isEmpty ? (m.name.trim().isEmpty ? t('name.newProject') : m.name.trim()) : m.site.trim(),
      }),
    ),
    DocFields([
      (t('prd.doc.irrigatedArea'), area > 0 ? '${fmt(u.areaFromSi(area), 2)} ${u.areaLabel}' : ''),
      (t('prd.doc.crops'), crops.join(', ')),
      (t('prd.doc.zones'), zones > 0 ? '$zones' : ''),
      (t('prd.doc.emitters'), emitters > 0 ? '$emitters' : ''),
      (t('prd.doc.flow'), flow > 0 ? '${fmt(u.flowFromSi(flow), 1)} ${u.flowLabel}' : ''),
      (t('prd.doc.head'), head > 0 ? '${fmt(u.pressureFromHead(head), 1)} ${u.pressureLabel}' : ''),
      (t('prd.doc.pumps'), pumps.join(', ')),
      (t('prd.doc.mainline'), len(mainline)),
      (t('prd.doc.zonePipes'), len(zonePipes)),
      (t('prd.doc.laterals'), len(laterals)),
    ]),
    if (r == null) DocNote(t('prd.doc.noResults')),
  ];
}

List<DocBlock> _criteria(DocContext ctx) {
  final t = ctx.t, p = ctx.project.params, u = ctx.units;
  final friction = switch (p.frictionMethod) {
    FrictionMethod.hazenWilliams => 'Hazen-Williams',
    FrictionMethod.darcyWeisbach => 'Darcy-Weisbach',
    FrictionMethod.scobey => 'Scobey',
    FrictionMethod.manning => 'Manning',
  };
  final rows = <List<Object>>[
    for (final e in reportCriteria.entries) [t('prd.std.${e.key}'), e.value.join(', ')],
  ];
  return [
    DocFields([
      (t('dlg.frictionFormula'), friction),
      (t('dlg.waterTemp'), '${fmt(p.waterTempC, 0)} °C'),
      (t('dlg.vZone'), '${fmt(u.velocityFromSi(p.maxZoneVelocity), 2)} ${u.velocityLabel}'),
      (t('dlg.vMain'), '${fmt(u.velocityFromSi(p.maxMainlineVelocity), 2)} ${u.velocityLabel}'),
      (t('dlg.minorPct'), p.applyMinorLosses ? '${fmt(p.minorLossPct, 0)} %' : '-'),
    ]),
    DocHeading(t('prd.doc.standards')),
    DocTable(ReportTable(key: 'prdCriteria', title: t('prd.doc.standards'), headers: [t('prd.doc.criterion'), t('prd.doc.references')], rows: rows), standards: false),
  ];
}

/// The abstraction points (water supplies and pumps) with their coordinates.
ReportTable? sourcesTable(DocContext ctx) {
  final p = ctx.project, t = ctx.t, u = ctx.units, g = p.meta.georef;
  final points = <Entity>[
    for (final e in p.entities)
      if (e is WaterSupplyEntity || e is PumpEntity) e,
  ];
  if (points.isEmpty) return null;
  final terrain = p.buildTerrain();
  final r = ctx.results;
  final rows = <List<Object>>[];
  for (final e in points) {
    final pos = (e as PointEntity).position;
    final kind = e is WaterSupplyEntity ? t('tool.supply') : t('tool.pump');
    final name = e.name.isNotEmpty ? e.name : (e is PumpEntity ? (p.catalog.pump(e.pumpSpecId)?.name ?? kind) : kind);
    final z = terrain.isEmpty ? double.nan : terrain.elevationAt(pos, fallback: double.nan);
    var flow = 0.0, head = 0.0;
    if (e is WaterSupplyEntity) {
      for (final f in r?.systemFlows ?? const []) {
        for (final s in f.supplies) {
          if (s.supplyId == e.id) {
            flow = math.max(flow, s.flow);
            head = math.max(head, s.requiredHead);
          }
        }
      }
    }
    final (x, y) = g == null ? (pos.x, pos.y) : g.toUtm(pos.x, pos.y);
    final (lat, lon) = g == null ? (double.nan, double.nan) : g.toLatLon(pos.x, pos.y);
    rows.add([
      name,
      kind,
      RNum(x, 1),
      RNum(y, 1),
      g == null ? '-' : docDms(lat, latitude: true, t: t),
      g == null ? '-' : docDms(lon, latitude: false, t: t),
      z.isNaN ? '-' : RNum(u.lengthFromSi(z), 1),
      flow > 0 ? RNum(u.flowFromSi(flow), 1) : '-',
      head > 0 ? RNum(u.pressureFromHead(head), 1) : '-',
    ]);
  }
  return ReportTable(
    key: 'prdSources',
    title: g == null ? t('prd.doc.sources') : '${t('prd.doc.sources')} (${g.crsName})',
    headers: [
      t('prd.doc.name'),
      t('prd.doc.kind'),
      g == null ? 'X (m)' : 'E (m)',
      g == null ? 'Y (m)' : 'N (m)',
      t('geo.lat'),
      t('geo.lon'),
      '${t('prd.doc.elevation')} (${u.lengthLabel})',
      '${t('rep.flow')} (${u.flowLabel})',
      '${t('rep.pRequired')} (${u.pressureLabel})',
    ],
    rows: rows,
    ids: [for (final e in points) e.id],
  );
}

/// The revision table of the title block and of the revision clouds.
ReportTable? revisionsTable(DocContext ctx) {
  final revs = sheetRevisions(ctx.project);
  if (revs.isEmpty) return null;
  final t = ctx.t;
  return ReportTable(
    key: 'prdRevisions',
    title: t('pdf.revisions'),
    headers: [t('pdf.rev'), t('pdf.date'), t('rep.description'), t('prd.tb.revAuthor')],
    rows: [
      for (final r in revs) [r.revision, r.date, r.description, r.author],
    ],
  );
}

List<DocBlock> _quote(DocContext ctx) {
  final t = ctx.t, s = ctx.project.proposal;
  return [
    ...ctx.tablesOf(const ['proposal', 'trench']),
    DocHeading(t('prd.doc.terms')),
    DocFields([
      (t('prd.doc.validity'), t('prd.doc.validityDays', {'n': '${s.validityDays}'})),
      (t('prd.doc.payment'), s.paymentTerms.trim()),
    ]),
    if (s.notes.trim().isNotEmpty) DocParagraph(s.notes.trim()),
  ];
}

/// The drawing sheets of a package: the plan for the client and for the
/// authorities (with the slope sheet and the coordinate grid), every zone
/// with the construction details for the installer, the plan with the
/// details and the slope for the memorial.
SheetOptions docSheetOptions(DocContext ctx) {
  final hasTerrain = !ctx.project.buildTerrain().isEmpty;
  final grid = ctx.project.meta.georef != null ? SheetGrid.utm : SheetGrid.none;
  final base = SheetOptions(page: ctx.sheetPage, rasters: ctx.rasters, attribution: ctx.attribution, bomOnSheet: ctx.results != null, grid: grid);
  return switch (ctx.profile) {
    DocProfile.proposal => base.copyWith(grid: SheetGrid.none),
    DocProfile.permit => base.copyWith(grid: ctx.project.meta.georef != null ? SheetGrid.both : SheetGrid.none, themes: hasTerrain ? const [SheetTheme.slope] : const [], bomOnSheet: false),
    DocProfile.installation => base.copyWith(split: SheetSplit.zones, details: DetailKind.values),
    DocProfile.memorial => base.copyWith(details: DetailKind.values, themes: hasTerrain ? const [SheetTheme.slope] : const []),
    DocProfile.operation => base.copyWith(split: SheetSplit.zones),
  };
}

bool _has(DocContext ctx, List<String> keys) => keys.any((k) => ctx.table(k) != null);

/// The sections of the packages that come with the program.
final prdDocumentSections = <DocSection>[
  DocSection(id: 'prd.identification', titleKey: 'prd.doc.sec.identification', profiles: const {_p: 100, _l: 100, _i: 100, _m: 100, _o: 100}, build: _identification),
  DocSection(id: 'prd.summary', titleKey: 'prd.doc.sec.summary', profiles: const {_p: 200, _l: 200, _i: 150, _m: 200, _o: 150}, build: _summary),
  DocSection(id: 'prd.criteria', titleKey: 'prd.doc.sec.criteria', profiles: const {_m: 300, _l: 300}, optional: const {_l}, build: _criteria),
  DocSection(
    id: 'prd.sources',
    titleKey: 'prd.doc.sec.sources',
    profiles: const {_l: 220, _m: 240, _i: 240},
    optional: const {_i},
    available: (c) => sourcesTable(c) != null,
    build: (c) => [DocTable(sourcesTable(c)!, standards: false)],
    landscape: true,
  ),
  DocSection(
    id: 'prd.water',
    titleKey: 'prd.doc.sec.water',
    profiles: const {_l: 250, _m: 250, _o: 250},
    optional: const {_o},
    available: (c) => _has(c, const ['requirement', 'requirementTotals', 'water']),
    build: (c) => c.tablesOf(const ['requirement', 'requirementTotals', 'water']),
    landscape: true,
  ),
  DocSection(
    id: 'prd.crops',
    titleKey: 'prd.doc.sec.crops',
    profiles: const {_m: 260, _o: 200, _l: 260, _i: 650},
    optional: const {_l, _i},
    available: (c) => _has(c, const ['crop', 'schedule']),
    build: (c) => c.tablesOf(const ['crop', 'schedule']),
    landscape: true,
  ),
  DocSection(
    id: 'prd.licensing',
    titleKey: 'prd.doc.sec.licensing',
    profiles: const {_l: 270, _m: 270},
    optional: const {_m},
    available: (c) => _has(c, const ['licensing']),
    build: (c) => c.tablesOf(const ['licensing']),
  ),
  DocSection(
    id: 'prd.slope',
    titleKey: 'prd.doc.sec.slope',
    profiles: const {_l: 280, _m: 280},
    available: (c) => _has(c, const ['slopeClasses']),
    build: (c) => c.tablesOf(const ['slopeClasses']),
    landscape: true,
  ),
  DocSection(
    id: 'prd.sheets',
    titleKey: 'prd.doc.sec.sheets',
    profiles: const {_p: 700, _l: 700, _i: 300, _m: 700, _o: 700},
    optional: const {_o},
    available: (c) => c.project.entities.isNotEmpty,
    build: (c) => [DocSheets(docSheetOptions(c))],
  ),
  DocSection(
    id: 'prd.hydraulics',
    titleKey: 'prd.doc.sec.hydraulics',
    profiles: const {_m: 400, _i: 400, _o: 400},
    optional: const {_o},
    needsResults: true,
    available: (c) => _has(c, const ['zones', 'mainline', 'devices', 'vih']),
    build: (c) => c.tablesOf(const ['zones', 'mainline', 'devices', 'vih']),
    landscape: true,
  ),
  DocSection(
    id: 'prd.pipes',
    titleKey: 'prd.doc.sec.pipes',
    profiles: const {_m: 410, _i: 410},
    optional: const {_i},
    needsResults: true,
    available: (c) => _has(c, const ['pipes', 'outlets']),
    build: (c) => c.tablesOf(const ['pipes', 'outlets']),
    landscape: true,
  ),
  DocSection(
    id: 'prd.pivots',
    titleKey: 'prd.doc.sec.pivots',
    profiles: const {_m: 450, _i: 450, _o: 450},
    optional: const {_o},
    needsResults: true,
    available: (c) => _has(c, const ['pivots', 'pivotSpans', 'pivotPackageSummary', 'pivotPackage', 'pivotTimer', 'cornerArm', 'vri', 'pivotElectrical']),
    build: (c) => c.tablesOf(const ['pivots', 'pivotSpans', 'pivotPackageSummary', 'pivotPackage', 'pivotTimer', 'cornerArm', 'vri', 'pivotElectrical']),
    landscape: true,
  ),
  DocSection(
    id: 'prd.checks',
    titleKey: 'prd.doc.sec.checks',
    profiles: const {_m: 500, _i: 500, _o: 300},
    optional: const {_i},
    needsResults: true,
    available: (c) => _has(c, const ['flushing', 'surge']),
    build: (c) => c.tablesOf(const ['flushing', 'surge']),
    landscape: true,
  ),
  DocSection(
    id: 'prd.electrical',
    titleKey: 'prd.doc.sec.electrical',
    profiles: const {_m: 550, _i: 550},
    needsResults: true,
    available: (c) => _has(c, const ['electrical']),
    build: (c) => c.tablesOf(const ['electrical']),
    landscape: true,
  ),
  DocSection(
    id: 'prd.bom',
    titleKey: 'prd.doc.sec.bom',
    profiles: const {_p: 300, _i: 500, _m: 600},
    needsResults: true,
    available: (c) => _has(c, const ['bom']),
    build: (c) => c.tablesOf(const ['bom']),
  ),
  DocSection(
    id: 'prd.bomZones',
    titleKey: 'prd.doc.sec.bomZones',
    profiles: const {_i: 510},
    needsResults: true,
    available: (c) => _has(c, const ['bomZones']),
    build: (c) => c.tablesOf(const ['bomZones']),
  ),
  DocSection(id: 'prd.quote', titleKey: 'prd.doc.sec.quote', profiles: const {_p: 400}, needsResults: true, available: (c) => _has(c, const ['proposal']), build: _quote),
  DocSection(
    id: 'prd.works',
    titleKey: 'prd.doc.sec.works',
    profiles: const {_p: 450, _i: 600},
    available: (c) => _has(c, const ['works']),
    build: (c) => c.tablesOf(const ['works']),
    landscape: true,
  ),
  DocSection(
    id: 'prd.charts',
    titleKey: 'prd.doc.sec.charts',
    profiles: const {_m: 750},
    optional: const {_m},
    available: (c) => designCharts(c.project, c.results, t: c.t, u: c.units).isNotEmpty,
    build: (c) => [for (final ch in designCharts(c.project, c.results, t: c.t, u: c.units)) DocChart(ch)],
    landscape: true,
  ),
  DocSection(
    id: 'prd.messages',
    titleKey: 'prd.doc.sec.messages',
    profiles: const {_m: 800},
    optional: const {_m},
    available: (c) => _has(c, const ['messages']),
    build: (c) => c.tablesOf(const ['messages']),
  ),
  DocSection(
    id: 'prd.revisions',
    titleKey: 'prd.doc.sec.revisions',
    profiles: const {_m: 850, _i: 850, _l: 850, _p: 850},
    optional: const {_p, _l},
    available: (c) => revisionsTable(c) != null,
    build: (c) => [DocTable(revisionsTable(c)!, standards: false)],
  ),
  DocSection(
    id: 'prd.signature',
    titleKey: 'prd.doc.sec.signature',
    profiles: const {_p: 990, _l: 990, _i: 990, _m: 990, _o: 990},
    build: (c) => [DocSignature(client: c.profile == DocProfile.proposal)],
  ),
];
