/// GPX (GPS Exchange Format) reader and writer, for field work with a GPS
/// receiver or phone: stake-out of the designed items and import of what was
/// walked or marked in the field.
///
/// - The writer puts every point item of the project (heads, the outlets of
///   the laterals, valves, junctions, pumps, supplies, devices, controllers,
///   pivot centres) as a waypoint with its name, its type, the catalogue item
///   and the ground elevation, and the linear items (pipes, laterals, tapes,
///   wire routes, the outlines of areas and pivots, drawing lines) as tracks
///   or routes. Coordinates are WGS 84 from the project georeference.
/// - The reader takes waypoints (name and elevation: spot heights), routes
///   and tracks (one polyline per track segment), GPX 1.1 or 1.0, into the
///   intermediate drawing of the other readers ([DxfDocument]).
///
/// Reference: GPX 1.1 Schema Documentation (2004), the schema at the
/// format's namespace (http://www.topografix.com/GPX/1/1/gpx.xsd) — the element order of the schema
/// sequences (wpt: ele, time, name, cmt, desc, sym, type; trk: name, desc,
/// type, trkseg) is kept.
library;

import 'package:xml/xml.dart';

import '../design/results.dart';
import '../model/catalog.dart';
import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import '../units.dart';
import 'datum.dart';
import 'dxf.dart';
import 'geo.dart';
import 'project_export.dart' show GeoReferenceMissing;

class GpxImportResult {
  GpxImportResult({required this.document, required this.georef, required this.waypointCount, required this.routeCount, required this.trackCount, required this.warnings});
  final DxfDocument document;
  final GeoReference? georef;
  final int waypointCount, routeCount, trackCount;
  final List<String> warnings;
}

/// How the writer stores lines: tracks (any GPS shows them) or routes
/// (navigable, but some receivers limit the number of route points).
enum GpxLineKind { track, route }

class GpxReader {
  /// Parses GPX text. With [georef] the data is placed relative to the
  /// project's origin (else one is created). With [pointsAsSpots] every
  /// route and track point with an elevation also becomes a spot height (a
  /// walked survey); [layer] names the layer of everything read.
  static GpxImportResult parse(String xml, {GeoReference? georef, bool pointsAsSpots = false, String layer = 'GPX'}) {
    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(xml);
    } on XmlException {
      throw const FormatException('gpx_invalid');
    }
    final root = doc.rootElement;
    if (root.name.local != 'gpx') throw const FormatException('gpx_invalid');
    final wpts = <_GpxPoint>[];
    final lines = <(String, List<_GpxPoint>)>[];
    var routes = 0, tracks = 0;
    for (final el in root.childElements) {
      switch (el.name.local) {
        case 'wpt':
          final p = _point(el);
          if (p != null) wpts.add(p);
        case 'rte':
          routes++;
          lines.add((_text(el, 'name'), [for (final r in el.childElements.where((c) => c.name.local == 'rtept')) ?_point(r)]));
        case 'trk':
          tracks++;
          final name = _text(el, 'name');
          for (final seg in el.childElements.where((c) => c.name.local == 'trkseg')) {
            lines.add((name, [for (final t in seg.childElements.where((c) => c.name.local == 'trkpt')) ?_point(t)]));
          }
      }
    }
    final sample = [
      for (final p in wpts) (p.lon, p.lat),
      for (final (_, l) in lines)
        for (final p in l) (p.lon, p.lat),
    ];
    final placement = GeoPlacement.plan(CrsInfo.geographic(), sample, georef: georef);
    final out = DxfDocument(layers: [DxfLayer(layer, color: 3)]);
    for (final w in wpts) {
      final p = placement.place(w.lon, w.lat);
      out.entities.add(DxfEntity(type: 'POINT', layer: layer, points: [p], elevation: w.ele, name: w.name));
      if (w.name.isNotEmpty) out.entities.add(DxfEntity(type: 'TEXT', layer: layer, points: [p + const Pt(1, 1)], text: w.name, height: 1.5));
    }
    for (final (name, pts) in lines) {
      if (pts.isEmpty) continue;
      final xy = [for (final p in pts) placement.place(p.lon, p.lat)];
      final eles = [for (final p in pts) p.ele];
      final same = eles.every((e) => e != null && (e - eles.first!).abs() < 1e-6);
      if (xy.length >= 2) {
        final closed = xy.length > 3 && xy.first.distanceTo(xy.last) < 1e-6;
        out.entities.add(DxfEntity(type: 'POLYLINE', layer: layer, points: closed ? xy.sublist(0, xy.length - 1) : xy, closed: closed, elevation: same ? eles.first : null, name: name));
      }
      if (pointsAsSpots) {
        for (var i = 0; i < pts.length; i++) {
          if (pts[i].ele != null) out.entities.add(DxfEntity(type: 'POINT', layer: layer, points: [xy[i]], elevation: pts[i].ele));
        }
      }
    }
    return GpxImportResult(document: out, georef: placement.georef, waypointCount: wpts.length, routeCount: routes, trackCount: tracks, warnings: placement.warnings);
  }

  static _GpxPoint? _point(XmlElement el) {
    final lat = double.tryParse(el.getAttribute('lat') ?? ''), lon = double.tryParse(el.getAttribute('lon') ?? '');
    if (lat == null || lon == null || lat.abs() > 90 || lon.abs() > 180) return null;
    return _GpxPoint(lat, lon, double.tryParse(_text(el, 'ele')), _text(el, 'name'));
  }

  static String _text(XmlElement el, String name) {
    for (final c in el.childElements) {
      if (c.name.local == name) return c.innerText.trim();
    }
    return '';
  }
}

class _GpxPoint {
  _GpxPoint(this.lat, this.lon, this.ele, this.name);
  final double lat, lon;
  final double? ele;
  final String name;
}

class GpxWriter {
  /// GPX 1.1 of [project] (throws [GeoReferenceMissing] without a
  /// georeference). [lateralOutlets] adds the outlets along the laterals as
  /// waypoints (for staking them out); [time] stamps the metadata.
  static String write(
    Project project, {
    DesignResults? results,
    GpxLineKind lines = GpxLineKind.track,
    bool lateralOutlets = true,
    Map<String, String> layerNames = const {},
    DateTime? time,
    String creator = 'OpenCADIrrigation',
  }) {
    final g = project.meta.georef ?? (throw const GeoReferenceMissing());
    final terrain = project.buildTerrain();
    final cat = project.catalog;
    final u = project.params.units;
    final wpts = <({Pt p, String name, String type, String desc, String cmt})>[];
    final paths = <({List<Pt> pts, String name, String type, String desc})>[];
    String layer(Entity e) => layerNames[e.layer] ?? e.layer;
    String nameOr(Entity e, String fallback) => e.name.isNotEmpty ? e.name : (fallback.isNotEmpty ? fallback : e.id);
    final outletRes = results?.outletsByEntity ?? const <String, List<OutletResult>>{};
    String pressureNote(OutletResult? r) => r == null ? '' : '${fmt(u.pressureFromHead(r.pressure), 1)} ${u.pressureLabel} · ${fmt(u.flowFromSi(r.flow), 1)} ${u.flowLabel}';

    for (final e in project.entities) {
      switch (e) {
        case OutletEntity o:
          final spec = cat.outlet(o.outletSpecId);
          wpts.add((
            p: o.position,
            name: nameOr(e, ''),
            type: spec?.kind.name ?? 'outlet',
            desc: [?spec?.name, ?spec?.nozzle(o.nozzleId)?.name].join(' · '),
            cmt: pressureNote(outletRes[o.id]?.firstOrNull),
          ));
        case SpraylineEntity s:
          final spec = cat.outlet(s.outletSpecId);
          if (lateralOutlets) {
            final pos = s.outletPositions();
            final res = outletRes[s.id];
            for (var i = 0; i < pos.length; i++) {
              wpts.add((
                p: pos[i],
                name: '${nameOr(e, '')}-${i + 1}',
                type: spec?.kind.name ?? 'outlet',
                desc: [?spec?.name, ?spec?.nozzle(s.nozzleId)?.name].join(' · '),
                cmt: pressureNote(res?.where((r) => i >= r.index && i < r.index + r.count).firstOrNull),
              ));
            }
          }
          paths.add((pts: s.points, name: nameOr(e, ''), type: e.type.name, desc: cat.pipe(s.pipeSpecId)?.name ?? ''));
        case ControlValveEntity v:
          final z = results?.zones[v.id];
          wpts.add((
            p: v.position,
            name: v.zoneName.isNotEmpty ? v.zoneName : nameOr(e, ''),
            type: 'valve',
            desc: cat.valve(v.valveSpecId)?.name ?? '',
            cmt: z == null ? '' : '${fmt(u.flowFromSi(z.totalFlow), 1)} ${u.flowLabel} · ${fmt(u.pressureFromHead(z.requiredUpstreamHead), 1)} ${u.pressureLabel}',
          ));
        case JunctionEntity j:
          wpts.add((p: j.position, name: nameOr(e, ''), type: 'junction', desc: '', cmt: ''));
        case PumpEntity pu:
          wpts.add((p: pu.position, name: nameOr(e, cat.pump(pu.pumpSpecId)?.name ?? ''), type: 'pump', desc: cat.pump(pu.pumpSpecId)?.name ?? '', cmt: ''));
        case WaterSupplyEntity s:
          wpts.add((p: s.position, name: nameOr(e, ''), type: 'supply', desc: '', cmt: ''));
        case MiscHydraulicEntity m:
          final spec = cat.valve(m.valveSpecId);
          wpts.add((p: m.position, name: nameOr(e, spec?.name ?? ''), type: spec?.kind.name ?? ValveKind.other.name, desc: spec?.name ?? '', cmt: ''));
        case ControllerEntity k:
          wpts.add((p: k.position, name: nameOr(e, ''), type: 'controller', desc: '${k.stations}', cmt: ''));
        case PivotEntity pv:
          wpts.add((p: pv.center, name: nameOr(e, pv.zoneName), type: pv.kind.name, desc: '', cmt: ''));
          paths.add((pts: [...pv.outline(), pv.outline().first], name: nameOr(e, pv.zoneName), type: pv.kind.name, desc: ''));
        case PipeEntity p:
          paths.add((pts: p.points, name: nameOr(e, cat.pipe(p.pipeSpecId)?.name ?? ''), type: e.type.name, desc: cat.pipe(p.pipeSpecId)?.name ?? ''));
        case TapeEntity t:
          paths.add((pts: t.points, name: nameOr(e, ''), type: e.type.name, desc: cat.tape(t.tapeSpecId)?.name ?? ''));
        case WireEntity w:
          paths.add((pts: w.points, name: nameOr(e, ''), type: e.type.name, desc: ''));
        case AreaEntity a:
          paths.add((pts: [...a.points, if (a.points.isNotEmpty) a.points.first], name: nameOr(e, a.crop), type: e.type.name, desc: a.crop));
        case PolylineEntity pl:
          paths.add((pts: [...pl.points, if (pl.closed && pl.points.isNotEmpty) pl.points.first], name: nameOr(e, layer(e)), type: e.type.name, desc: layer(e)));
        case LineEntity l:
          paths.add((pts: [l.a, l.b], name: nameOr(e, layer(e)), type: e.type.name, desc: layer(e)));
        default:
          break;
      }
    }
    String ll(Pt p) {
      final (lat, lon) = g.toLatLon(p.x, p.y);
      return 'lat="${lat.toStringAsFixed(8)}" lon="${lon.toStringAsFixed(8)}"';
    }

    String ele(Pt p) => terrain.isEmpty ? '' : '<ele>${terrain.elevationAt(p).toStringAsFixed(2)}</ele>';
    String el(String tag, String v) => v.isEmpty ? '' : '<$tag>${_esc(v)}</$tag>';
    final b = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln(
        '<gpx version="1.1" creator="${_esc(creator)}" xmlns="http://www.topografix.com/GPX/1/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">',
      );
    final all = [for (final w in wpts) w.p, for (final p in paths) ...p.pts];
    b.write(
      '<metadata>${el('name', project.meta.name)}${el('desc', [project.meta.client, project.meta.site].where((s) => s.isNotEmpty).join(' · '))}<time>${(time ?? DateTime.now()).toUtc().toIso8601String().split('.').first}Z</time>',
    );
    if (all.isNotEmpty) {
      var minLat = 90.0, maxLat = -90.0, minLon = 180.0, maxLon = -180.0;
      for (final p in all) {
        final (lat, lon) = g.toLatLon(p.x, p.y);
        if (lat < minLat) minLat = lat;
        if (lat > maxLat) maxLat = lat;
        if (lon < minLon) minLon = lon;
        if (lon > maxLon) maxLon = lon;
      }
      b.write('<bounds minlat="${minLat.toStringAsFixed(8)}" minlon="${minLon.toStringAsFixed(8)}" maxlat="${maxLat.toStringAsFixed(8)}" maxlon="${maxLon.toStringAsFixed(8)}"/>');
    }
    b.writeln('</metadata>');
    for (final w in wpts) {
      b.writeln('<wpt ${ll(w.p)}>${ele(w.p)}${el('name', w.name)}${el('cmt', w.cmt)}${el('desc', w.desc)}${el('type', w.type)}</wpt>');
    }
    for (final p in paths) {
      if (p.pts.length < 2) continue;
      if (lines == GpxLineKind.route) {
        b.write('<rte>${el('name', p.name)}${el('desc', p.desc)}${el('type', p.type)}');
        for (final q in p.pts) {
          b.write('<rtept ${ll(q)}>${ele(q)}</rtept>');
        }
        b.writeln('</rte>');
      } else {
        b.write('<trk>${el('name', p.name)}${el('desc', p.desc)}${el('type', p.type)}<trkseg>');
        for (final q in p.pts) {
          b.write('<trkpt ${ll(q)}>${ele(q)}</trkpt>');
        }
        b.writeln('</trkseg></trk>');
      }
    }
    b.writeln('</gpx>');
    return b.toString();
  }

  static String _esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
}
