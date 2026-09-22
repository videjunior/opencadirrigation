/// All project exporters in one place: DXF, KML/KMZ, GeoJSON, SVG, PDF and
/// the tabular reports (CSV, TXT, XLSX, PDF). Pure Dart, no Flutter.
library;

import 'dart:typed_data';

import '../design/report_tables.dart';
import '../design/results.dart';
import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import '../translate.dart';
import '../units.dart';
import 'dwg_writer.dart';
import 'dxf.dart';
import 'geo.dart';
import 'geo_export.dart';
import 'pdf_sheet.dart';
import 'plot.dart';
import 'svg.dart';
import 'xlsx.dart';

/// Thrown by the geographic exporters when the project has no [GeoReference].
class GeoReferenceMissing implements Exception {
  const GeoReferenceMissing();
  @override
  String toString() => 'GeoReferenceMissing';
}

enum DrawingFormat {
  dxf('dxf', 'application/dxf'),
  dwg('dwg', 'image/vnd.dwg'),
  pdf('pdf', 'application/pdf'),
  svg('svg', 'image/svg+xml'),
  kml('kml', 'application/vnd.google-earth.kml+xml'),
  kmz('kmz', 'application/vnd.google-earth.kmz'),
  geojson('geojson', 'application/geo+json');

  const DrawingFormat(this.extension, this.mime);
  final String extension;
  final String mime;
  bool get needsGeoref => this == kml || this == kmz || this == geojson;
  bool get isBinary => this == pdf || this == kmz || this == dwg;
}

enum ReportFormat {
  csv('csv', 'text/csv'),
  txt('txt', 'text/plain'),
  xlsx('xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
  pdf('pdf', 'application/pdf');

  const ReportFormat(this.extension, this.mime);
  final String extension;
  final String mime;
  bool get isBinary => this == xlsx || this == pdf;
}

class ProjectExporter {
  ProjectExporter({required this.project, this.results, required this.labels, this.unconnected = const {}, Map<String, String>? layerNames}) : layerNames = layerNames ?? const {};
  final Project project;
  final DesignResults? results;
  final ReportLabels labels;
  final Set<String> unconnected;

  /// Translated layer names (legend, KML folders).
  final Map<String, String> layerNames;

  Units get units => project.params.units;
  Translate get t => labels.t;
  String layerLabel(String l) => layerNames[l] ?? l;

  // ------------------------------------------------------------------ DXF / DWG

  String dxf() => DxfWriter.write(dxfDocument());

  /// AutoCAD 2000 DWG with the same content as the DXF export.
  Uint8List dwg() => DwgWriter.write(dxfDocument());

  /// The drawing as a plain CAD document (layers + primitive entities).
  DxfDocument dxfDocument() {
    final layers = project.layers.map((l) => DxfLayer(l.name, color: argbToAci(l.color))).toList();
    final ents = <DxfEntity>[];
    for (final e in project.entities) {
      switch (e) {
        case LineEntity l:
          ents.add(DxfEntity(type: 'LINE', layer: l.layer, points: [l.a, l.b]));
        case PolylineEntity p:
          ents.add(DxfEntity(type: 'POLYLINE', layer: p.layer, points: p.points, closed: p.closed));
        case CircleEntity c:
          ents.add(DxfEntity(type: 'CIRCLE', layer: c.layer, center: c.center, radius: c.radius));
        case ArcEntity a:
          ents.add(DxfEntity(type: 'ARC', layer: a.layer, center: a.center, radius: a.radius, startAngle: radToDeg(a.startRad), endAngle: radToDeg(a.startRad + a.sweepRad)));
        case SplineEntity sp:
          ents.add(DxfEntity(type: 'POLYLINE', layer: sp.layer, points: sp.curve(), closed: sp.closed));
        case HatchEntity h:
          ents.add(DxfEntity(type: 'POLYLINE', layer: h.layer, points: h.points, closed: true));
          for (final l in h.patternLines()) {
            ents.add(DxfEntity(type: 'LINE', layer: h.layer, points: l));
          }
        case SymbolEntity sy:
          for (final st in sy.strokes()) {
            ents.add(DxfEntity(type: 'POLYLINE', layer: sy.layer, points: st));
          }
        case AngularDimensionEntity ad:
          ents.add(DxfEntity(type: 'POLYLINE', layer: ad.layer, points: [ad.a, ad.vertex, ad.b]));
          ents.add(DxfEntity(type: 'POLYLINE', layer: ad.layer, points: ad.arcPoints()));
          ents.add(DxfEntity(type: 'TEXT', layer: ad.layer, points: [ad.textPoint], text: '${fmt(ad.angleDeg, 1)}°', height: 0.5));
        case RadialDimensionEntity rd:
          ents.add(DxfEntity(type: 'LINE', layer: rd.layer, points: [rd.start, rd.point]));
          ents.add(DxfEntity(type: 'TEXT', layer: rd.layer, points: [rd.diameter ? rd.center : Pt.lerp(rd.center, rd.point, 0.5)], text: '${rd.diameter ? 'Ø' : 'R'} ${fmt(rd.value)}', height: 0.5));
        case OrdinateDimensionEntity od:
          ents.add(DxfEntity(type: 'POLYLINE', layer: od.layer, points: od.leader));
          ents.add(DxfEntity(type: 'TEXT', layer: od.layer, points: [od.leaderEnd], text: '${od.xAxis ? 'X' : 'Y'} ${fmt(od.value)}', height: 0.5));
        case WireEntity w:
          ents.add(DxfEntity(type: 'POLYLINE', layer: w.layer, points: w.points));
        case ControllerEntity k:
          ents.add(DxfEntity(type: 'POLYLINE', layer: k.layer, points: [k.position + const Pt(-1, -1), k.position + const Pt(1, -1), k.position + const Pt(1, 1), k.position + const Pt(-1, 1)], closed: true));
          ents.add(DxfEntity(type: 'TEXT', layer: Layers.labels, points: [k.position + const Pt(1.3, 0)], text: k.name, height: 0.8));
        case LeaderEntity le:
          ents.add(DxfEntity(type: 'POLYLINE', layer: le.layer, points: le.points));
          ents.add(DxfEntity(type: 'TEXT', layer: le.layer, points: [le.textPosition], text: le.text, height: le.height));
        case ImageEntity im:
          ents.add(DxfEntity(type: 'POLYLINE', layer: im.layer, points: im.corners, closed: true));
        case TextEntity tx:
          ents.add(DxfEntity(type: 'TEXT', layer: tx.layer, points: [tx.position], text: tx.text, height: tx.height, rotation: tx.rotationDeg));
        case DimensionEntity d:
          final n = d.normal * d.offset;
          ents.add(DxfEntity(type: 'POLYLINE', layer: d.layer, points: [d.a, d.a + n, d.b + n, d.b]));
          ents.add(DxfEntity(type: 'TEXT', layer: d.layer, points: [Pt.lerp(d.a, d.b, 0.5) + n], text: fmt(d.length), height: 0.5));
        case ContourEntity c:
          ents.add(DxfEntity(type: 'POLYLINE', layer: c.layer, points: c.points));
          if (c.points.isNotEmpty) ents.add(DxfEntity(type: 'TEXT', layer: c.layer, points: [c.points.first], text: fmt(c.elevation, 1), height: 0.5));
        case SpotHeightEntity s:
          ents.add(DxfEntity(type: 'POINT', layer: s.layer, points: [s.position]));
          ents.add(DxfEntity(type: 'TEXT', layer: s.layer, points: [s.position], text: fmt(s.elevation, 1), height: 0.5));
        case PipeEntity p:
          ents.add(DxfEntity(type: 'POLYLINE', layer: p.layer, points: p.points));
          final spec = project.catalog.pipe(p.pipeSpecId);
          if (spec != null && p.points.length >= 2) ents.add(DxfEntity(type: 'TEXT', layer: Layers.labels, points: [Pt.lerp(p.points[0], p.points[1], 0.5)], text: spec.name, height: 0.6));
        case SpraylineEntity s:
          ents.add(DxfEntity(type: 'POLYLINE', layer: s.layer, points: s.points));
          for (final o in s.outletPositions()) {
            ents.add(DxfEntity(type: 'CIRCLE', layer: Layers.outlets, center: o, radius: 0.3));
          }
        case TapeEntity tp:
          ents.add(DxfEntity(type: 'POLYLINE', layer: tp.layer, points: tp.points));
        case OutletEntity o:
          ents.add(DxfEntity(type: 'CIRCLE', layer: o.layer, center: o.position, radius: 0.5));
        case ControlValveEntity v:
          ents.add(DxfEntity(type: 'CIRCLE', layer: v.layer, center: v.position, radius: 1.0));
          ents.add(DxfEntity(type: 'TEXT', layer: Layers.labels, points: [v.position + const Pt(1.2, 0)], text: v.zoneName, height: 0.8));
        case WaterSupplyEntity s:
          ents.add(DxfEntity(type: 'CIRCLE', layer: s.layer, center: s.position, radius: 1.5));
          ents.add(DxfEntity(type: 'TEXT', layer: Layers.labels, points: [s.position + const Pt(1.8, 0)], text: s.name, height: 0.8));
        case PumpEntity p:
          ents.add(DxfEntity(type: 'CIRCLE', layer: p.layer, center: p.position, radius: 1.0));
        case MiscHydraulicEntity m:
          ents.add(DxfEntity(type: 'CIRCLE', layer: m.layer, center: m.position, radius: 0.8));
        case JunctionEntity j:
          ents.add(DxfEntity(type: 'POINT', layer: j.layer, points: [j.position]));
        case AreaEntity a:
          ents.add(DxfEntity(type: 'POLYLINE', layer: a.layer, points: a.points, closed: true));
        case PivotEntity pv:
          ents.add(DxfEntity(type: 'POLYLINE', layer: pv.layer, points: pv.outline(), closed: true));
          ents.add(DxfEntity(type: 'LINE', layer: pv.layer, points: [pv.center, pv.endPoint]));
          ents.add(DxfEntity(type: 'CIRCLE', layer: pv.layer, center: pv.center, radius: 1.5));
          for (final tw in pv.towerPositions()) {
            ents.add(DxfEntity(type: 'CIRCLE', layer: pv.layer, center: tw, radius: 0.8));
          }
          ents.add(DxfEntity(type: 'TEXT', layer: Layers.labels, points: [pv.center + const Pt(2, 1.5)], text: pv.name, height: 1.0));
        default:
          break;
      }
    }
    return DxfDocument(entities: ents, layers: layers);
  }

  /// Nearest AutoCAD colour index for an ARGB colour.
  static int argbToAci(int argb) {
    final r = (argb >> 16) & 0xFF, g = (argb >> 8) & 0xFF, b = argb & 0xFF;
    if (r > 200 && g < 120 && b < 120) return 1;
    if (r > 200 && g > 200 && b < 120) return 2;
    if (g > 180 && r < 150 && b < 150) return 3;
    if (b > 200 && r < 120) return 5;
    if (r > 150 && b > 150 && g < 120) return 6;
    return 7;
  }

  // ------------------------------------------------------------------ geographic

  GeoReference requireGeoref() => project.meta.georef ?? (throw const GeoReferenceMissing());

  /// Entities as WGS84 features (throws [GeoReferenceMissing] without georef).
  List<GeoFeature> geoFeatures() {
    final g = requireGeoref();
    final out = <GeoFeature>[];
    final u = units;
    final pipeRes = results?.pipesByEntity ?? const <String, List<PipeSegmentResult>>{};
    (double, double, double) ll(Pt p, [double alt = 0]) {
      final (lat, lon) = g.toLatLon(p.x, p.y);
      return (lon, lat, alt);
    }

    int col(String layer) => 0xFF000000 | (project.layerNamed(layer).color & 0xFFFFFF);
    List<(double, double, double)> ring(Pt c, double r, [int n = 36]) => [for (var i = 0; i <= n; i++) ll(c + Pt.polar(r, 2 * 3.141592653589793 * i / n))];
    void add(Entity e, String type, List<(double, double, double)> coords, {String? name, String description = '', Map<String, String>? data, double fillAlpha = 0}) {
      if (coords.isEmpty) return;
      out.add(GeoFeature(name: name ?? e.name, folder: layerLabel(e.layer), type: type, coords: coords, color: col(e.layer), widthPx: e is PipeEntity && e.scope == HydraulicScope.mainline ? 3 : 2, description: description, data: {'id': e.id, 'type': e.type.name, ...?data}, fillAlpha: fillAlpha));
    }

    String pipeInfo(String id, String? specName) {
      final parts = <String>[?specName];
      final res = pipeRes[id];
      if (res != null && res.isNotEmpty) {
        final r = res.reduce((a, b) => a.flow.abs() >= b.flow.abs() ? a : b);
        parts.add('${fmt(u.flowFromSi(r.flow.abs()), 1)} ${u.flowLabel} · ${fmt(u.velocityFromSi(r.velocity), 2)} ${u.velocityLabel}');
      }
      return parts.join(' · ');
    }

    for (final e in project.entities) {
      switch (e) {
        case LineEntity l:
          add(e, 'LineString', [ll(l.a), ll(l.b)]);
        case PolylineEntity p:
          add(e, p.closed ? 'Polygon' : 'LineString', p.points.map(ll).toList());
        case CircleEntity c:
          add(e, 'LineString', ring(c.center, c.radius));
        case ArcEntity a:
          final n = 24;
          add(e, 'LineString', [for (var i = 0; i <= n; i++) ll(a.center + Pt.polar(a.radius, a.startRad + a.sweepRad * i / n))]);
        case SplineEntity sp:
          add(e, sp.closed ? 'Polygon' : 'LineString', sp.curve().map(ll).toList());
        case HatchEntity h:
          add(e, 'Polygon', h.points.map(ll).toList(), fillAlpha: 0.4);
        case SymbolEntity sy:
          add(e, 'Point', [ll(sy.position)], name: sy.name.isEmpty ? sy.kind.name : sy.name);
        case AngularDimensionEntity ad:
          add(e, 'LineString', [ll(ad.a), ll(ad.vertex), ll(ad.b)], name: '${fmt(ad.angleDeg, 1)}°');
        case RadialDimensionEntity rd:
          add(e, 'LineString', [ll(rd.start), ll(rd.point)], name: '${rd.diameter ? 'Ø' : 'R'} ${fmt(u.lengthFromSi(rd.value))} ${u.lengthLabel}');
        case OrdinateDimensionEntity od:
          add(e, 'LineString', od.leader.map(ll).toList(), name: '${od.xAxis ? 'X' : 'Y'} ${fmt(u.lengthFromSi(od.value))} ${u.lengthLabel}');
        case WireEntity w:
          add(e, 'LineString', w.points.map(ll).toList(), name: w.name.isEmpty ? t('tool.wire') : w.name, data: {'length_m': fmt(w.length, 2)});
        case ControllerEntity k:
          final duty = results?.electrical?.controllers.where((d) => d.controllerId == k.id).firstOrNull;
          add(e, 'Point', [ll(k.position)], name: k.name.isEmpty ? t('tool.controller') : k.name, description: duty == null ? '${k.stations}' : '${duty.used}/${k.stations}', data: {'stations': '${k.stations}', if (duty != null) 'used': '${duty.used}'});
        case LeaderEntity le:
          add(e, 'LineString', le.points.map(ll).toList(), name: le.text);
        case ImageEntity im:
          add(e, 'Polygon', im.corners.map(ll).toList(), name: im.name.isEmpty ? im.source : im.name);
        case TextEntity tx:
          add(e, 'Point', [ll(tx.position)], name: tx.text);
        case DimensionEntity d:
          final n = d.normal * d.offset;
          add(e, 'LineString', [ll(d.a), ll(d.a + n), ll(d.b + n), ll(d.b)], name: '${fmt(u.lengthFromSi(d.length))} ${u.lengthLabel}');
        case ContourEntity c:
          add(e, 'LineString', c.points.map((p) => ll(p, c.elevation)).toList(), name: c.name.isEmpty ? fmt(c.elevation, 1) : c.name, data: {'ELEV': fmt(c.elevation, 2)});
        case SpotHeightEntity s:
          add(e, 'Point', [ll(s.position, s.elevation)], name: s.name.isEmpty ? fmt(s.elevation, 1) : s.name, data: {'ELEV': fmt(s.elevation, 2)});
        case PipeEntity p:
          final spec = project.catalog.pipe(p.pipeSpecId);
          add(e, 'LineString', p.points.map(ll).toList(), name: p.name.isEmpty ? (spec?.name ?? t('tool.${p.scope == HydraulicScope.zone ? 'zonePipe' : 'mainPipe'}')) : p.name, description: pipeInfo(p.id, spec?.name), data: {'length_m': fmt(p.length, 2), if (spec != null) 'pipe': spec.name});
        case SpraylineEntity s:
          final spec = project.catalog.pipe(s.pipeSpecId);
          final outlet = project.catalog.outlet(s.outletSpecId);
          add(e, 'LineString', s.points.map(ll).toList(), name: s.name.isEmpty ? t('tool.sprayline') : s.name, description: '${outlet?.name ?? s.outletSpecId} × ${s.outletCount} · ${pipeInfo(s.id, spec?.name)}', data: {'length_m': fmt(s.length, 2), 'outlets': '${s.outletCount}', 'spacing_m': fmt(s.spacing, 2)});
        case TapeEntity tp:
          final spec = project.catalog.tape(tp.tapeSpecId);
          add(e, 'LineString', tp.points.map(ll).toList(), name: tp.name.isEmpty ? (spec?.name ?? t('tool.tape')) : tp.name, description: pipeInfo(tp.id, spec?.name), data: {'length_m': fmt(tp.length, 2)});
        case OutletEntity o:
          add(e, 'Point', [ll(o.position)], name: o.name.isEmpty ? (project.catalog.outlet(o.outletSpecId)?.name ?? t('tool.outlet')) : o.name);
        case ControlValveEntity v:
          final z = results?.zones[v.id];
          add(e, 'Point', [ll(v.position)], name: v.zoneName, description: z == null ? (project.catalog.valve(v.valveSpecId)?.name ?? '') : '${fmt(u.flowFromSi(z.totalFlow), 1)} ${u.flowLabel} · ${fmt(u.pressureFromHead(z.requiredUpstreamHead), 1)} ${u.pressureLabel}', data: {if (z != null) 'flow': fmt(u.flowFromSi(z.totalFlow), 1), if (z != null) 'required_head': fmt(u.pressureFromHead(z.requiredUpstreamHead), 1)});
        case WaterSupplyEntity s:
          add(e, 'Point', [ll(s.position)], name: s.name.isEmpty ? t('tool.supply') : s.name);
        case PumpEntity p:
          add(e, 'Point', [ll(p.position)], name: p.name.isEmpty ? (project.catalog.pump(p.pumpSpecId)?.name ?? t('tool.pump')) : p.name);
        case MiscHydraulicEntity m:
          add(e, 'Point', [ll(m.position)], name: m.name.isEmpty ? (project.catalog.valve(m.valveSpecId)?.name ?? t('tool.misc')) : m.name);
        case JunctionEntity j:
          add(e, 'Point', [ll(j.position)], name: j.name.isEmpty ? t('tool.junction') : j.name);
        case AreaEntity a:
          add(e, 'Polygon', a.points.map(ll).toList(), name: a.name.isEmpty ? t('tool.area') : a.name, description: '${fmt(a.area / 10000, 2)} ha${a.crop.isNotEmpty ? ' · ${a.crop}' : ''}', data: {'area_ha': fmt(a.area / 10000, 3), if (a.crop.isNotEmpty) 'crop': a.crop}, fillAlpha: 0.3);
        default:
          break;
      }
    }
    return out;
  }

  String kml() => KmlWriter.write(geoFeatures(), documentName: project.meta.name, description: _docDescription());
  Uint8List kmz() => KmlWriter.writeKmz(kml());
  String geoJson() => GeoJsonWriter.write(geoFeatures(), name: project.meta.name);

  String _docDescription() {
    final m = project.meta;
    return [if (m.client.isNotEmpty) m.client, if (m.site.isNotEmpty) m.site, if (m.designer.isNotEmpty) m.designer, 'OpenCADIrrigation'].join(' · ');
  }

  // ------------------------------------------------------------------ plot

  PdfSheetBuilder sheetBuilder() => PdfSheetBuilder(project: project, results: results, t: t, layerNames: layerNames, units: units);

  /// Plot scene at the sheet's scale.
  PlotScene scene(SheetOptions o) => buildPlotScene(project, results: results, unitsPerMm: sheetBuilder().sheetScale(o) / 1000, options: PlotOptions(wettedRadii: o.wettedRadii, labels: o.labels, results: o.labels), units: units, t: t);

  String svg([SheetOptions o = const SheetOptions()]) => SvgWriter.write(scene(o), marginMm: o.marginMm, title: project.meta.name, layerNames: layerNames);

  Uint8List pdfSheet([SheetOptions o = const SheetOptions()]) => sheetBuilder().buildSheet(o, reports: o.includeReports ? reportTables() : const []);

  // ------------------------------------------------------------------ reports

  List<ReportTable> reportTables() => buildReportTables(project: project, results: results, labels: labels, unconnected: unconnected);

  String reportCsv() => reportTablesToCsv(reportTables());

  String reportTxt() {
    final m = project.meta;
    return reportTablesToText(reportTables(), header: [
      'OpenCADIrrigation · ${t('pdf.reportTitle')}',
      '${t('dlg.project')}: ${m.name}',
      if (m.client.isNotEmpty) '${t('dlg.client')}: ${m.client}',
      if (m.site.isNotEmpty) '${t('dlg.site')}: ${m.site}',
      if (m.designer.isNotEmpty) '${t('dlg.designer')}: ${m.designer}',
      '${t('pdf.date')}: ${PdfSheetBuilder.dateString(DateTime.now())}',
    ]);
  }

  Uint8List reportXlsx() => XlsxWriter.write([
    for (final tb in reportTables())
      XlsxSheet(name: tb.title, headers: tb.headers, rows: [
        for (final r in tb.rows) [for (final c in r) c is RNum ? double.parse(c.value.toStringAsFixed(c.decimals)) : c],
      ]),
  ]);

  Uint8List reportPdf() => sheetBuilder().buildReport(reportTables());

  // ------------------------------------------------------------------ dispatch

  /// Drawing export by format; text formats return [String], binary [Uint8List].
  Object exportDrawing(DrawingFormat f, {SheetOptions sheet = const SheetOptions()}) => switch (f) {
    DrawingFormat.dxf => dxf(),
    DrawingFormat.dwg => dwg(),
    DrawingFormat.pdf => pdfSheet(sheet),
    DrawingFormat.svg => svg(sheet),
    DrawingFormat.kml => kml(),
    DrawingFormat.kmz => kmz(),
    DrawingFormat.geojson => geoJson(),
  };

  Object exportReport(ReportFormat f) => switch (f) {
    ReportFormat.csv => reportCsv(),
    ReportFormat.txt => reportTxt(),
    ReportFormat.xlsx => reportXlsx(),
    ReportFormat.pdf => reportPdf(),
  };
}
