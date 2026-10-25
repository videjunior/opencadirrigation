/// LandXML 1.2 reader and writer: terrain surfaces (TIN), survey points and
/// pipe networks, the exchange format of civil and survey software.
///
/// Writer: the project's terrain as a Surface — the Delaunay TIN of
/// tin.dart in Definition (Pnts and Faces) and the contour lines and spot
/// heights it was built from in SourceData (Contours, DataPoints) — the point
/// items (heads, valves, supplies, pumps, devices, junctions) as CgPoints at
/// the ground with a `code` naming their type, for stake-out, and the pipes as
/// PipeNetworks: one per zone and one for the mainline, a Pipe per drawn
/// segment (CircPipe with the inner diameter and Hazen-Williams C, PipeFlow
/// with the design flow and the hydraulic grade at both ends when results
/// exist) between Structs at the vertices, whose Invert elevations are the
/// ground minus the burial depth (the pipe axis, the elevation of our
/// analysis) minus half the inner diameter.
///
/// Reader: CgPoints (nested groups too), Surfaces — the Definition (Pnts and
/// Faces, the TIN kept in [LandXmlImportResult.surfaces]) or the SourceData
/// (Contours, Breaklines, DataPoints, Boundaries) — decimated on a grid to at
/// most `Terrain.maxTinPoints` points, and the pipes of PipeNetworks, into the
/// intermediate drawing of the other readers ([DxfDocument]). The
/// CoordinateSystem (epsgCode, ogcWktCode or a name) places the data through
/// datum.dart; Imperial units are converted to metres.
///
/// LandXML coordinates are "northing easting [elevation]" (in that order).
///
/// Reference: the LandXML 1.2 schema (2008),
/// http://www.landxml.org/schema/LandXML-1.2/LandXML-1.2.xsd — element order
/// of its sequences, required attributes and the document-wide unique Struct
/// and Pipe names (keys StructKey and PipeKey) are respected.
library;

import 'dart:math' as math;

import 'package:xml/xml.dart';

import '../design/network_builder.dart';
import '../design/results.dart';
import '../model/catalog.dart';
import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import '../model/terrain.dart';
import 'datum.dart';
import 'dxf.dart';
import 'geo.dart';
import 'point_grid.dart';

/// A TIN read from a Surface Definition, in local coordinates.
class LandXmlSurface {
  LandXmlSurface({required this.name, required this.points, required this.faces});
  final String name;

  /// Every vertex (local x, y) with its elevation (the spot heights of the
  /// drawing may be a decimated subset of them).
  final List<(Pt, double)> points;

  /// Visible triangles as indices into [points].
  final List<(int, int, int)> faces;
}

/// A pipe of a PipeNetwork, in local coordinates.
class LandXmlPipe {
  LandXmlPipe({required this.name, required this.network, required this.points, this.diameter, this.invertStart, this.invertEnd});
  final String name;
  final String network;

  /// Start struct, the arc's centre point when given, end struct.
  final List<Pt> points;

  /// Inner diameter (m) of a CircPipe.
  final double? diameter;

  /// Invert elevations (m) at the start and end structs.
  final double? invertStart, invertEnd;
}

class LandXmlImportResult {
  LandXmlImportResult({required this.document, required this.georef, required this.crs, required this.surfaces, required this.cgPointCount, required this.pipes, required this.warnings, required this.localOrigin});
  final DxfDocument document;
  final GeoReference? georef;
  final CrsInfo crs;
  final List<LandXmlSurface> surfaces;
  final int cgPointCount;

  /// Pipes of the PipeNetworks (also drawn as polylines in [document]).
  final List<LandXmlPipe> pipes;
  int get pipeCount => pipes.length;

  /// Message codes: CRS problems, `landxml_decimated:<surface>:<in>:<out>`.
  final List<String> warnings;
  final Pt localOrigin;
}

/// Which data of a Surface becomes spot heights.
enum LandXmlSurfaceSource {
  /// SourceData when the surface has it, else the Definition.
  auto,
  definition,
  sourceData,
}

class LandXmlReader {
  static const _ns = 'http://www.landxml.org/schema/LandXML-1.2';

  /// Parses LandXML text (1.0–1.2; namespaces are ignored). With [georef]
  /// the data is placed relative to the project's origin.
  static LandXmlImportResult parse(String xml, {GeoReference? georef, int? maxPoints, LandXmlSurfaceSource source = LandXmlSurfaceSource.auto}) {
    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(xml);
    } on XmlException {
      throw const FormatException('landxml_invalid');
    }
    final root = doc.rootElement;
    if (root.name.local != 'LandXML') throw const FormatException('landxml_invalid');
    final limit = maxPoints ?? Terrain.maxTinPoints;
    final warnings = <String>[];
    // units: metres per linear unit
    final units = _child(root, 'Units');
    final metric = units == null ? null : _child(units, 'Metric');
    final imperial = units == null ? null : _child(units, 'Imperial');
    final lin = metric != null
        ? switch (metric.getAttribute('linearUnit')) { 'millimeter' => 0.001, 'centimeter' => 0.01, 'kilometer' => 1000.0, _ => 1.0 }
        : imperial != null
        ? switch (imperial.getAttribute('linearUnit')) { 'USSurveyFoot' => 1200 / 3937, 'inch' => 0.0254, 'mile' => 1609.344, _ => 0.3048 }
        : 1.0;
    final diam = metric != null
        ? switch (metric.getAttribute('diameterUnit')) { 'millimeter' => 0.001, 'centimeter' => 0.01, 'kilometer' => 1000.0, 'meter' => 1.0, _ => lin }
        : imperial != null
        ? switch (imperial.getAttribute('diameterUnit')) { 'inch' => 0.0254, 'foot' => 0.3048, 'USSurveyFoot' => 1200 / 3937, _ => lin }
        : lin;
    // coordinate system
    CrsInfo? crs;
    final cs = _child(root, 'CoordinateSystem');
    if (cs != null) {
      final epsg = int.tryParse(cs.getAttribute('epsgCode') ?? '');
      final wkt = cs.getAttribute('ogcWktCode') ?? '';
      final names = [cs.getAttribute('projectedCoordinateSystemName'), cs.getAttribute('name'), cs.getAttribute('horizontalCoordinateSystemName')].whereType<String>().where((s) => s.trim().isNotEmpty);
      if (epsg != null) {
        crs = crsFromEpsg(epsg);
      } else if (wkt.isNotEmpty) {
        crs = parseCrs(wkt);
      } else {
        for (final n in names) {
          final c = parseCrs(n);
          if (c.recognised) {
            crs = c;
            break;
          }
        }
        if (crs == null && names.isNotEmpty) crs = CrsInfo(kind: CrsKind.unknown, name: names.first, problem: 'crs_unparsed');
      }
    }
    if (crs != null && crs.kind != CrsKind.geographic && lin != 1 && crs.kind == CrsKind.projected) {
      // projected coordinates in the file's linear unit
      crs = CrsInfo(kind: crs.kind, datum: crs.datum, projection: crs.projection, epsg: crs.epsg, name: crs.name, unitM: lin, problem: crs.problem);
    }
    final unitXY = crs == null || crs.kind == CrsKind.unknown ? lin : 1.0;

    // ---- gather raw data (x = easting, y = northing in file units)
    final cg = <({double x, double y, double? z, String name, String layer, String code})>[];
    for (final g in root.findAllElements('CgPoints')) {
      final lname = g.getAttribute('name') ?? 'CGPOINTS';
      for (final p in g.childElements.where((e) => e.name.local == 'CgPoint')) {
        final v = _nums(p.innerText);
        if (v.length < 2) continue;
        cg.add((x: v[1], y: v[0], z: v.length > 2 ? v[2] * lin : null, name: p.getAttribute('name') ?? p.getAttribute('oID') ?? '', layer: lname.isEmpty ? 'CGPOINTS' : lname, code: p.getAttribute('code') ?? ''));
      }
    }
    final surfaces = <({String name, List<(double, double, double)> pts, List<int> ids, List<(int, int, int)> faces, List<({String kind, List<List<double>> pts, double? elev, String name})> source})>[];
    for (final s in root.findAllElements('Surface')) {
      final name = s.getAttribute('name') ?? 'SURFACE';
      final pts = <(double, double, double)>[];
      final ids = <int>[];
      final faces = <(int, int, int)>[];
      final def = _child(s, 'Definition');
      if (def != null) {
        final byId = <int, int>{};
        final pnts = _child(def, 'Pnts');
        for (final p in pnts?.childElements.where((e) => e.name.local == 'P') ?? const <XmlElement>[]) {
          final v = _nums(p.innerText);
          final id = int.tryParse(p.getAttribute('id') ?? '');
          if (v.length < 3 || id == null) continue;
          byId[id] = pts.length;
          ids.add(id);
          pts.add((v[1], v[0], v[2] * lin));
        }
        for (final fs in def.childElements.where((e) => e.name.local == 'Faces')) {
          for (final f in fs.childElements.where((e) => e.name.local == 'F')) {
            if (f.getAttribute('i') == '1') continue; // invisible face
            final v = f.innerText.trim().split(RegExp(r'\s+')).map(int.tryParse).toList();
            if (v.length < 3 || v.take(3).any((i) => i == null || !byId.containsKey(i))) continue;
            faces.add((byId[v[0]]!, byId[v[1]]!, byId[v[2]]!));
            if (v.length >= 4 && v[3] != null && byId.containsKey(v[3])) faces.add((byId[v[0]]!, byId[v[2]]!, byId[v[3]]!)); // grid face
          }
        }
      }
      final src = <({String kind, List<List<double>> pts, double? elev, String name})>[];
      final sd = _child(s, 'SourceData');
      if (sd != null) {
        for (final c in sd.findAllElements('Contour')) {
          final l = _child(c, 'PntList2D');
          if (l != null) src.add((kind: 'contour', pts: _pairs(l.innerText, 2), elev: double.tryParse(c.getAttribute('elev') ?? ''), name: c.getAttribute('name') ?? ''));
        }
        for (final b in sd.findAllElements('Breakline')) {
          final l3 = _child(b, 'PntList3D'), l2 = _child(b, 'PntList2D');
          if (l3 != null) src.add((kind: 'breakline', pts: _pairs(l3.innerText, 3), elev: null, name: b.getAttribute('name') ?? ''));
          if (l2 != null) src.add((kind: 'breakline', pts: _pairs(l2.innerText, 2), elev: null, name: b.getAttribute('name') ?? ''));
        }
        for (final d in sd.findAllElements('DataPoints')) {
          for (final l in d.childElements.where((e) => e.name.local == 'PntList3D')) {
            src.add((kind: 'points', pts: _pairs(l.innerText, 3), elev: null, name: d.getAttribute('name') ?? ''));
          }
        }
        for (final b in sd.findAllElements('Boundary')) {
          final l = _child(b, 'PntList2D') ?? _child(b, 'PntList3D');
          if (l != null) src.add((kind: 'boundary', pts: _pairs(l.innerText, l.name.local == 'PntList3D' ? 3 : 2), elev: null, name: b.getAttribute('name') ?? ''));
        }
      }
      surfaces.add((name: name, pts: pts, ids: ids, faces: faces, source: src));
    }
    final pipes = <({String name, String layer, List<(double, double)> pts, double? diameter, double? invertStart, double? invertEnd})>[];
    for (final net in root.findAllElements('PipeNetwork')) {
      final lname = net.getAttribute('name') ?? 'PIPES';
      final centre = <String, (double, double)>{};
      final inverts = <String, double>{}; // "struct|pipe" → invert elevation
      for (final st in net.findAllElements('Struct')) {
        final sname = st.getAttribute('name') ?? '';
        final c = _child(st, 'Center');
        final v = c == null ? const <double>[] : _nums(c.innerText);
        if (v.length >= 2) centre[sname] = (v[1], v[0]);
        for (final inv in st.childElements.where((e) => e.name.local == 'Invert')) {
          final z = double.tryParse(inv.getAttribute('elev') ?? '');
          if (z != null) inverts['$sname|${inv.getAttribute('refPipe') ?? ''}'] = z * lin;
        }
      }
      for (final p in net.findAllElements('Pipe')) {
        final s0 = p.getAttribute('refStart') ?? '', s1 = p.getAttribute('refEnd') ?? '', name = p.getAttribute('name') ?? '';
        final a = centre[s0], b = centre[s1];
        if (a == null || b == null) continue;
        final mid = _child(p, 'Center');
        final m = mid == null ? const <double>[] : _nums(mid.innerText);
        final d = double.tryParse(_child(p, 'CircPipe')?.getAttribute('diameter') ?? '');
        pipes.add((name: name, layer: lname, pts: [a, if (m.length >= 2) (m[1], m[0]), b], diameter: d == null ? null : d * diam, invertStart: inverts['$s0|$name'], invertEnd: inverts['$s1|$name']));
      }
    }

    // ---- placement
    final sample = <(double, double)>[
      for (final p in cg) (p.x * unitXY, p.y * unitXY),
      for (final s in surfaces) ...[for (final p in s.pts) (p.$1 * unitXY, p.$2 * unitXY), for (final x in s.source) for (final q in x.pts) (q[1] * unitXY, q[0] * unitXY)],
      for (final p in pipes) for (final q in p.pts) (q.$1 * unitXY, q.$2 * unitXY),
    ];
    final placement = GeoPlacement.plan(crs, sample, georef: georef);
    warnings.addAll(placement.warnings);
    Pt place(double x, double y) => placement.place(x * unitXY, y * unitXY);

    final out = DxfDocument();
    final layers = <String, DxfLayer>{};
    void layer(String n) => layers.putIfAbsent(n, () => DxfLayer(n, color: 3));
    for (final p in cg) {
      layer(p.layer);
      out.entities.add(DxfEntity(type: 'POINT', layer: p.layer, points: [place(p.x, p.y)], elevation: p.z, name: p.name));
    }
    final result = <LandXmlSurface>[];
    for (final s in surfaces) {
      final useSource = source == LandXmlSurfaceSource.sourceData || (source == LandXmlSurfaceSource.auto && s.source.any((x) => x.kind != 'boundary'));
      final local = [for (final p in s.pts) (place(p.$1, p.$2), p.$3)];
      result.add(LandXmlSurface(name: s.name, points: local, faces: s.faces));
      layer(s.name);
      if (!useSource && local.isNotEmpty) {
        var keep = local;
        if (local.length > limit) {
          final b = Bounds.ofPoints(local.map((p) => p.$1));
          final dec = PointGridDecimator(minX: b.minX, minY: b.minY, maxX: b.maxX, maxY: b.maxY, maxCells: limit, reduce: GridReduce.nearestCentre);
          for (final (p, z) in local) {
            dec.add(p.x, p.y, z);
          }
          keep = [for (final (x, y, z) in dec.result()) (Pt(x, y), z)];
          warnings.add('landxml_decimated:${s.name}:${local.length}:${keep.length}');
        }
        for (final (p, z) in keep) {
          out.entities.add(DxfEntity(type: 'POINT', layer: s.name, points: [p], elevation: z));
        }
      }
      if (useSource) {
        for (final x in s.source) {
          final pts = [for (final q in x.pts) place(q[1], q[0])];
          final zs = [for (final q in x.pts) q.length > 2 ? q[2] * lin : null];
          switch (x.kind) {
            case 'contour':
              if (pts.length >= 2 && x.elev != null) out.entities.add(DxfEntity(type: 'POLYLINE', layer: s.name, points: pts, elevation: x.elev! * lin, name: x.name));
            case 'breakline':
              final same = zs.isNotEmpty && zs.every((z) => z != null && (z - zs.first!).abs() < 1e-6);
              if (pts.length >= 2) out.entities.add(DxfEntity(type: 'POLYLINE', layer: s.name, points: pts, elevation: same ? zs.first : null, name: x.name));
              if (!same) {
                for (var i = 0; i < pts.length; i++) {
                  if (zs[i] != null) out.entities.add(DxfEntity(type: 'POINT', layer: s.name, points: [pts[i]], elevation: zs[i]));
                }
              }
            case 'points':
              for (var i = 0; i < pts.length; i++) {
                if (zs[i] != null) out.entities.add(DxfEntity(type: 'POINT', layer: s.name, points: [pts[i]], elevation: zs[i]));
              }
            case 'boundary':
              if (pts.length >= 3) out.entities.add(DxfEntity(type: 'POLYLINE', layer: s.name, points: pts, closed: true, name: x.name));
          }
        }
      }
    }
    final pipeOut = <LandXmlPipe>[];
    for (final p in pipes) {
      layer(p.layer);
      final pts = [for (final q in p.pts) place(q.$1, q.$2)];
      out.entities.add(DxfEntity(type: 'POLYLINE', layer: p.layer, points: pts, name: p.name));
      pipeOut.add(LandXmlPipe(name: p.name, network: p.layer, points: pts, diameter: p.diameter, invertStart: p.invertStart, invertEnd: p.invertEnd));
    }
    out.layers.addAll(layers.values);
    return LandXmlImportResult(document: out, georef: placement.georef, crs: placement.crs, surfaces: result, cgPointCount: cg.length, pipes: pipeOut, warnings: warnings, localOrigin: placement.localOrigin);
  }

  static XmlElement? _child(XmlElement e, String local) {
    for (final c in e.childElements) {
      if (c.name.local == local) return c;
    }
    return null;
  }

  static List<double> _nums(String s) => [for (final t in s.trim().split(RegExp(r'[\s,]+'))) ?double.tryParse(t)];

  static List<List<double>> _pairs(String s, int n) {
    final v = _nums(s);
    return [for (var i = 0; i + n <= v.length; i += n) v.sublist(i, i + n)];
  }

  /// The LandXML 1.2 namespace.
  static String get namespace => _ns;
}

class LandXmlWriter {
  /// LandXML 1.2 of the project: terrain surface, CgPoints and pipe
  /// networks. Coordinates are the project's UTM zone on [datum] (named in
  /// CoordinateSystem) when it is georeferenced, local metres otherwise.
  static String write(Project project, {DesignResults? results, String applicationVersion = '', DateTime? time, GeodeticDatum datum = GeodeticDatum.sirgas2000, String surfaceName = 'TERRAIN'}) {
    final g = project.meta.georef;
    final now = time ?? DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    String ne(Pt p) {
      final (e, n) = g != null ? g.toUtm(p.x, p.y) : (p.x, p.y);
      return '${_n(n)} ${_n(e)}';
    }

    final terrain = project.buildTerrain();
    final b = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln('<LandXML xmlns="${LandXmlReader.namespace}" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="${LandXmlReader.namespace} http://www.landxml.org/schema/LandXML-1.2/LandXML-1.2.xsd" '
          'date="${now.year}-${two(now.month)}-${two(now.day)}" time="${two(now.hour)}:${two(now.minute)}:${two(now.second)}" version="1.2" language="English" readOnly="false">')
      ..writeln('  <Units><Metric areaUnit="squareMeter" linearUnit="meter" volumeUnit="cubicMeter" temperatureUnit="celsius" pressureUnit="HPA" diameterUnit="millimeter" velocityUnit="metersPerSecond" flowUnit="cubicMeterSecond" angularUnit="decimal degrees" directionUnit="decimal degrees"/></Units>');
    if (g != null) {
      final crs = CrsInfo.utm(g.zone, g.north, datum: datum);
      b.writeln('  <CoordinateSystem name="${_esc(crs.name)}"${crs.epsgCode != null ? ' epsgCode="${crs.epsgCode}"' : ''} ogcWktCode="${_esc(crs.toOgcWkt())}" horizontalDatum="${_esc(datum.ogcName)}" projectedCoordinateSystemName="${_esc(crs.name)}"/>');
    }
    final m = project.meta;
    b
      ..writeln('  <Project name="${_esc(m.name)}"${[m.client, m.site].any((s) => s.isNotEmpty) ? ' desc="${_esc([m.client, m.site].where((s) => s.isNotEmpty).join(' · '))}"' : ''}/>')
      ..writeln('  <Application name="OpenCADIrrigation"${applicationVersion.isNotEmpty ? ' version="${_esc(applicationVersion)}"' : ''} manufacturerURL="https://opencadirrigation.com"/>');

    // ---- CgPoints: the point items at the ground, for stake-out
    final cat = project.catalog;
    final cg = <(String, Pt, String)>[];
    for (final e in project.entities) {
      final (Pt? p, String code) = switch (e) {
        OutletEntity o => (o.position, cat.outlet(o.outletSpecId)?.kind.name ?? 'outlet'),
        ControlValveEntity v => (v.position, 'valve'),
        WaterSupplyEntity s => (s.position, 'supply'),
        PumpEntity pu => (pu.position, 'pump'),
        MiscHydraulicEntity mh => (mh.position, cat.valve(mh.valveSpecId)?.kind.name ?? ValveKind.other.name),
        JunctionEntity j => (j.position, 'junction'),
        ControllerEntity k => (k.position, 'controller'),
        _ => (null, ''),
      };
      if (p != null) cg.add((e is ControlValveEntity && e.zoneName.isNotEmpty ? e.zoneName : (e.name.isEmpty ? e.id : e.name), p, code));
    }
    if (cg.isNotEmpty) {
      b.writeln('  <CgPoints name="HYDRAULICS">');
      final used = <String>{};
      for (final (name, p, code) in cg) {
        var n = name;
        for (var k = 2; !used.add(n); k++) {
          n = '$name ($k)';
        }
        final z = terrain.isEmpty ? '' : ' ${_n(terrain.elevationAt(p))}';
        b.writeln('    <CgPoint name="${_esc(n)}" code="${_esc(code)}">${ne(p)}$z</CgPoint>');
      }
      b.writeln('  </CgPoints>');
    }

    // ---- Surface: TIN and its source data
    final contours = project.entities.whereType<ContourEntity>().where((c) => c.points.length >= 2).toList();
    final spots = project.entities.whereType<SpotHeightEntity>().toList();
    final tin = terrain.isEmpty ? null : terrain.tin;
    if ((tin != null && !tin.isEmpty) || contours.isNotEmpty || spots.length >= 2) {
      b.writeln('  <Surfaces>');
      b.writeln('    <Surface name="${_esc(surfaceName)}">');
      if (contours.isNotEmpty || spots.length >= 2) {
        b.writeln('      <SourceData>');
        if (contours.isNotEmpty) {
          b.writeln('        <Contours>');
          for (final c in contours) {
            b.writeln('          <Contour elev="${_n(c.elevation)}"><PntList2D>${c.points.map(ne).join(' ')}</PntList2D></Contour>');
          }
          b.writeln('        </Contours>');
        }
        if (spots.length >= 2) b.writeln('        <DataPoints name="SPOT_HEIGHTS"><PntList3D>${spots.map((s) => '${ne(s.position)} ${_n(s.elevation)}').join(' ')}</PntList3D></DataPoints>');
        b.writeln('      </SourceData>');
      }
      if (tin != null && !tin.isEmpty) {
        var zMin = double.infinity, zMax = -double.infinity, area = 0.0;
        for (final z in tin.zs) {
          zMin = math.min(zMin, z);
          zMax = math.max(zMax, z);
        }
        for (final t in tin.triangles) {
          area += ((tin.xs[t.b] - tin.xs[t.a]) * (tin.ys[t.c] - tin.ys[t.a]) - (tin.xs[t.c] - tin.xs[t.a]) * (tin.ys[t.b] - tin.ys[t.a])).abs() / 2;
        }
        b.writeln('      <Definition surfType="TIN" area2DSurf="${_n(area)}" elevMax="${_n(zMax)}" elevMin="${_n(zMin)}">');
        b.writeln('        <Pnts>');
        for (var i = 0; i < tin.pointCount; i++) {
          b.writeln('          <P id="${i + 1}">${ne(tin.vertex(i))} ${_n(tin.zs[i])}</P>');
        }
        b
          ..writeln('        </Pnts>')
          ..writeln('        <Faces>');
        for (final t in tin.triangles) {
          b.writeln('          <F>${t.a + 1} ${t.b + 1} ${t.c + 1}</F>');
        }
        b
          ..writeln('        </Faces>')
          ..writeln('      </Definition>');
      }
      b
        ..writeln('    </Surface>')
        ..writeln('  </Surfaces>');
    }

    // ---- PipeNetworks: the mainline and one network per zone
    final nets = _networks(project);
    if (nets.isNotEmpty) {
      b.writeln('  <PipeNetworks name="IRRIGATION">');
      final pipeRes = <String, List<PipeSegmentResult>>{};
      for (final z in results?.zones.values ?? const <ZoneResult>[]) {
        for (final s in z.pipes) {
          pipeRes.putIfAbsent(s.entityId, () => []).add(s);
        }
      }
      for (final f in results?.systemFlows ?? const <SystemFlowResult>[]) {
        for (final s in f.pipes) {
          pipeRes.putIfAbsent(s.entityId, () => []).add(s);
        }
      }
      var structSeq = 0, pipeSeq = 0;
      for (final (name, entities) in nets) {
        // structs at the vertices (shared vertices are one struct), found
        // through a hash of cells as wide as the connection tolerance
        final structs = <({String name, Pt p, List<(String, double, String)> inverts})>[];
        final tol = math.max(project.params.connectTolerance, 1e-6);
        final grid = <int, List<int>>{};
        int key(int ix, int iy) => ix * 73856093 ^ iy * 19349663;
        int structAt(Pt p) {
          final ix = (p.x / tol).floor(), iy = (p.y / tol).floor();
          for (var dx = -1; dx <= 1; dx++) {
            for (var dy = -1; dy <= 1; dy++) {
              for (final i in grid[key(ix + dx, iy + dy)] ?? const <int>[]) {
                if (structs[i].p.distanceTo(p) <= tol) return i;
              }
            }
          }
          structs.add((name: 'S${++structSeq}', p: p, inverts: []));
          grid.putIfAbsent(key(ix, iy), () => []).add(structs.length - 1);
          return structs.length - 1;
        }

        final pipes = StringBuffer();
        for (final e in entities) {
          final pts = (e as PolyEntity).points;
          final depth = switch (e) { PipeEntity p => p.depth, SpraylineEntity s => s.depth, TapeEntity t => t.depth, _ => 0.0 };
          final pipe = switch (e) { PipeEntity p => cat.pipe(p.pipeSpecId), SpraylineEntity s => cat.pipe(s.pipeSpecId), _ => null };
          final tape = e is TapeEntity ? cat.tape(e.tapeSpecId) : null;
          final dMm = tape?.innerDiameterMm ?? pipe?.innerDiameterMm ?? 0;
          final c = tape?.hazenC ?? pipe?.hazenC;
          final wall = pipe?.wallThicknessMm;
          final segs = pipeRes[e.id] ?? const <PipeSegmentResult>[];
          for (var i = 1; i < pts.length; i++) {
            var a = pts[i - 1], bb = pts[i];
            // the segment's results: the analysis splits at outlets, so the
            // pieces inside this drawn segment are averaged by length
            final inSeg = segs.where((s) => distanceToSegment(s.a, a, bb) < 1e-3 && distanceToSegment(s.b, a, bb) < 1e-3).toList();
            final flow = inSeg.isEmpty ? null : inSeg.map((s) => s.flow).reduce((x, y) => x.abs() >= y.abs() ? x : y);
            if (flow != null && flow < 0) (a, bb) = (bb, a);
            final sa = structAt(a), sb = structAt(bb);
            if (sa == sb) continue;
            final pname = 'P${++pipeSeq}';
            double invert(Pt p) => terrain.elevationAt(p) - depth - dMm / 2000;
            structs[sa].inverts.add((pname, invert(a), 'out'));
            structs[sb].inverts.add((pname, invert(bb), 'in'));
            double? hgl(Pt p) {
              for (final s in inSeg) {
                if (s.a.distanceTo(p) < 1e-3) return s.elevationA + s.pressureStart;
                if (s.b.distanceTo(p) < 1e-3) return s.elevationB + s.pressureEnd;
              }
              return null;
            }

            final desc = [?pipe?.name, ?tape?.name, if (e.name.isNotEmpty) e.name].join(' · ');
            pipes.write('        <Pipe name="$pname" refStart="${structs[sa].name}" refEnd="${structs[sb].name}" length="${_n(a.distanceTo(bb))}"${desc.isNotEmpty ? ' desc="${_esc(desc)}"' : ''}>');
            pipes.write('<CircPipe diameter="${_n(dMm > 0 ? dMm : 1)}"${c != null ? ' hazenWilliams="${_n(c)}"' : ''}${pipe != null ? ' material="${pipe.material.name}"' : ''}${wall != null && wall > 0 ? ' thickness="${_n(wall)}"' : ''}/>');
            if (flow != null) {
              final hu = hgl(a), hd = hgl(bb);
              pipes.write('<PipeFlow flowIn="${_n(flow.abs(), 9)}"${hu != null ? ' hglUp="${_n(hu)}"' : ''}${hd != null ? ' hglDown="${_n(hd)}"' : ''}/>');
            }
            pipes.writeln('</Pipe>');
          }
        }
        if (structs.length < 2 || pipes.isEmpty) continue;
        b
          ..writeln('    <PipeNetwork name="${_esc(name)}" pipeNetType="water">')
          ..writeln('      <Structs>');
        for (final s in structs) {
          final ground = terrain.elevationAt(s.p);
          final sump = s.inverts.isEmpty ? ground : s.inverts.map((i) => i.$2).reduce(math.min);
          b.write('        <Struct name="${s.name}" elevRim="${_n(ground)}" elevSump="${_n(sump)}"><Center>${ne(s.p)}</Center><Connection/>');
          for (final (pipe, z, dir) in s.inverts) {
            b.write('<Invert elev="${_n(z)}" flowDir="$dir" refPipe="$pipe"/>');
          }
          b.writeln('</Struct>');
        }
        b
          ..writeln('      </Structs>')
          ..writeln('      <Pipes>')
          ..write(pipes)
          ..writeln('      </Pipes>')
          ..writeln('    </PipeNetwork>');
      }
      b.writeln('  </PipeNetworks>');
    }
    b.writeln('</LandXML>');
    return b.toString();
  }

  /// The linear hydraulic entities grouped into networks: the mainline, then
  /// one per zone (the valve that feeds them, from the network graph), then
  /// anything unconnected. Names are unique (the schema's uPipeNetName).
  static List<(String, List<Entity>)> _networks(Project project) {
    final linear = project.entities.where((e) => e.isLinearHydraulic && (e as PolyEntity).points.length >= 2).toList();
    if (linear.isEmpty) return const [];
    final model = NetworkBuilder(project).build();
    final linkById = {for (final l in model.links) l.id: l};
    final zoneOf = <String, String>{};
    for (final v in model.zoneLinks.keys) {
      final valve = project.byId(v);
      final name = valve is ControlValveEntity && valve.zoneName.isNotEmpty ? valve.zoneName : v;
      for (final lid in model.zoneLinks[v]!) {
        final l = linkById[lid];
        if (l != null) zoneOf.putIfAbsent(l.entityId, () => name);
      }
    }
    final main = <Entity>[], other = <Entity>[];
    final zones = <String, List<Entity>>{};
    for (final e in linear) {
      if (e.hydraulicScope == HydraulicScope.mainline) {
        main.add(e);
      } else if (zoneOf[e.id] != null) {
        zones.putIfAbsent(zoneOf[e.id]!, () => []).add(e);
      } else {
        other.add(e);
      }
    }
    final used = <String>{};
    String unique(String n) {
      var t = n;
      for (var k = 2; !used.add(t); k++) {
        t = '$n ($k)';
      }
      return t;
    }

    return [if (main.isNotEmpty) (unique('MAINLINE'), main), for (final z in zones.entries) (unique(z.key), z.value), if (other.isNotEmpty) (unique('ZONES'), other)];
  }

  static String _n(double v, [int decimals = 3]) {
    if (!v.isFinite) return '0';
    var s = v.toStringAsFixed(decimals);
    if (s.contains('.')) s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    return s == '-0' ? '0' : s;
  }

  static String _esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
}
