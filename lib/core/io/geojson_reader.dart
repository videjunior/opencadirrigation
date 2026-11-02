/// GeoJSON reader producing a [DxfDocument] in local metric coordinates, the
/// same intermediate drawing the KML and shapefile readers produce.
///
/// Accepts a FeatureCollection, a single Feature, a GeometryCollection or a
/// bare geometry; every geometry type (Point, LineString, Polygon with its
/// holes, MultiPoint, MultiLineString, MultiPolygon, nested collections).
/// Coordinates are RFC 7946 longitude/latitude on WGS 84; the `crs` member of
/// the 2008 GeoJSON specification (`{"type": "name", "properties": {"name":
/// "urn:ogc:def:crs:EPSG::31983"}}`, or the older `{"type": "EPSG", …}`) is
/// honoured, so UTM data on SIRGAS 2000, SAD 69 or Córrego Alegre lands in
/// the right place (datum.dart). A third coordinate is the elevation;
/// properties name the feature (`name`, `nome`, `nombre`, `id`, `label`)
/// and give an elevation (`elevation`, `elev`, `z`, `cota`, `altitude`), a
/// `layer` property (as written by our exporter) its layer.
///
/// References: RFC 7946 "The GeoJSON Format" (IETF, 2016); "The GeoJSON
/// Format Specification" rev. 1.0 (2008) for the `crs` member.
library;

import 'dart:convert';

import '../model/geometry.dart';
import 'datum.dart';
import 'dxf.dart';
import 'geo.dart';

class GeoJsonImportResult {
  GeoJsonImportResult({required this.document, required this.georef, required this.featureCount, required this.crs, required this.warnings, required this.localOrigin});
  final DxfDocument document;

  /// Georeference used or created (null for data in an unrecognised CRS).
  final GeoReference? georef;
  final int featureCount;
  final CrsInfo crs;

  /// Message codes: CRS problems (`crs_epsg_unknown`, …), `crs_datum_shift:…`,
  /// `geojson_geometry_skipped:<type>`.
  final List<String> warnings;

  /// Offset subtracted from coordinates of an unrecognised CRS.
  final Pt localOrigin;
}

class GeoJsonReader {
  static const _nameKeys = ['name', 'nome', 'nombre', 'nom', 'title', 'label', 'id'];
  static const _elevKeys = ['elevation', 'elev', 'z', 'cota', 'altitude', 'alt', 'height', 'altura', 'elevacao', 'elevação'];
  static const _layerKeys = ['layer', 'camada', 'capa', 'folder'];

  /// Parses GeoJSON text. With [georef] the data is placed relative to the
  /// project's existing origin; [layer] names the layer of features that
  /// carry no `layer` property.
  static GeoJsonImportResult parse(String text, {GeoReference? georef, String layer = 'GEOJSON'}) {
    final Object? root;
    try {
      root = jsonDecode(text);
    } on FormatException {
      throw const FormatException('geojson_invalid');
    }
    if (root is! Map<String, dynamic> || root['type'] is! String) throw const FormatException('geojson_invalid');
    final crs = _crs(root['crs']);
    final feats = <_Feat>[];
    final warnings = <String>[];
    _collect(root, null, feats, warnings);
    final sample = <(double, double)>[];
    for (final f in feats) {
      for (final part in f.parts) {
        for (final c in part) {
          sample.add((c.$1, c.$2));
        }
      }
    }
    final placement = GeoPlacement.plan(crs, sample, georef: georef);
    warnings.addAll(placement.warnings);
    final layers = <String, DxfLayer>{};
    final doc = DxfDocument();
    for (final f in feats) {
      final props = f.props;
      final lname = _string(props, _layerKeys) ?? layer;
      layers.putIfAbsent(lname, () => DxfLayer(lname, color: 3));
      final name = _string(props, _nameKeys) ?? '';
      final elevProp = _number(props, _elevKeys);
      for (final part in f.parts) {
        final pts = [for (final c in part) placement.place(c.$1, c.$2)];
        final zs = [for (final c in part) c.$3];
        final hasZ = zs.any((z) => z != null);
        final sameZ = hasZ && zs.every((z) => z != null && (z - zs.first!).abs() < 1e-6);
        switch (f.kind) {
          case 'point':
            if (pts.isEmpty) break;
            doc.entities.add(DxfEntity(type: 'POINT', layer: lname, points: [pts.first], elevation: elevProp ?? zs.first, name: name));
            if (name.isNotEmpty) doc.entities.add(DxfEntity(type: 'TEXT', layer: lname, points: [pts.first + const Pt(1, 1)], text: name, height: 1.5));
          case 'line':
            if (pts.length >= 2) doc.entities.add(DxfEntity(type: 'POLYLINE', layer: lname, points: pts, elevation: elevProp ?? (sameZ ? zs.first : null), name: name));
          case 'ring':
            var ring = pts;
            if (ring.length > 3 && ring.first.distanceTo(ring.last) < 1e-9) ring = ring.sublist(0, ring.length - 1);
            if (ring.length >= 3) doc.entities.add(DxfEntity(type: 'POLYLINE', layer: lname, points: ring, closed: true, elevation: elevProp ?? (sameZ ? zs.first : null), name: name));
        }
      }
    }
    doc.layers.addAll(layers.values);
    return GeoJsonImportResult(
      document: doc,
      georef: placement.georef,
      featureCount: feats.map((f) => f.id).toSet().length,
      crs: placement.crs,
      warnings: warnings,
      localOrigin: placement.localOrigin,
    );
  }

  /// The CRS named by a 2008 `crs` member; RFC 7946 (WGS 84) when absent.
  static CrsInfo _crs(Object? member) {
    if (member is! Map) return CrsInfo.geographic();
    final props = member['properties'];
    if (member['type'] == 'name' && props is Map && props['name'] is String) return parseCrs(props['name'] as String);
    if (member['type'] == 'EPSG' && props is Map && props['code'] != null) {
      final code = int.tryParse('${props['code']}');
      if (code != null) return crsFromEpsg(code);
    }
    return const CrsInfo(kind: CrsKind.unknown, name: 'crs', problem: 'crs_unparsed');
  }

  static int _seq = 0;

  static void _collect(Map<String, dynamic> o, Map<String, dynamic>? props, List<_Feat> out, List<String> warnings) {
    switch (o['type']) {
      case 'FeatureCollection':
        for (final f in (o['features'] as List?) ?? const []) {
          if (f is Map<String, dynamic>) _collect(f, null, out, warnings);
        }
      case 'Feature':
        final p = o['properties'];
        final g = o['geometry'];
        if (g is Map<String, dynamic>) _geometry(g, p is Map<String, dynamic> ? p : const {}, out, warnings, _seq++);
      default:
        _geometry(o, props ?? const {}, out, warnings, _seq++);
    }
  }

  static void _geometry(Map<String, dynamic> g, Map<String, dynamic> props, List<_Feat> out, List<String> warnings, int id) {
    final c = g['coordinates'];
    switch (g['type']) {
      case 'Point':
        final p = _pos(c);
        if (p != null) {
          out.add(
            _Feat(id, 'point', [
              [p],
            ], props),
          );
        }
      case 'MultiPoint':
        for (final q in (c as List?) ?? const []) {
          final p = _pos(q);
          if (p != null) {
            out.add(
              _Feat(id, 'point', [
                [p],
              ], props),
            );
          }
        }
      case 'LineString':
        out.add(_Feat(id, 'line', [_line(c)], props));
      case 'MultiLineString':
        out.add(_Feat(id, 'line', [for (final l in (c as List?) ?? const []) _line(l)], props));
      case 'Polygon':
        out.add(_Feat(id, 'ring', [for (final r in (c as List?) ?? const []) _line(r)], props));
      case 'MultiPolygon':
        out.add(
          _Feat(id, 'ring', [
            for (final poly in (c as List?) ?? const [])
              for (final r in (poly as List?) ?? const []) _line(r),
          ], props),
        );
      case 'GeometryCollection':
        for (final sub in (g['geometries'] as List?) ?? const []) {
          if (sub is Map<String, dynamic>) _geometry(sub, props, out, warnings, id);
        }
      default:
        warnings.add('geojson_geometry_skipped:${g['type']}');
    }
  }

  static (double, double, double?)? _pos(Object? c) {
    if (c is! List || c.length < 2 || c[0] is! num || c[1] is! num) return null;
    final x = (c[0] as num).toDouble(), y = (c[1] as num).toDouble();
    if (!x.isFinite || !y.isFinite) return null;
    final z = c.length > 2 && c[2] is num ? (c[2] as num).toDouble() : null;
    return (x, y, z != null && z.isFinite ? z : null);
  }

  static List<(double, double, double?)> _line(Object? c) => [for (final q in (c as List?) ?? const []) ?_pos(q)];

  static String? _string(Map<String, dynamic> props, List<String> keys) {
    for (final k in keys) {
      for (final e in props.entries) {
        if (e.key.toLowerCase() == k && e.value != null && '${e.value}'.trim().isNotEmpty) return '${e.value}'.trim();
      }
    }
    return null;
  }

  static double? _number(Map<String, dynamic> props, List<String> keys) {
    for (final k in keys) {
      for (final e in props.entries) {
        if (e.key.toLowerCase() != k) continue;
        final v = e.value;
        final n = v is num ? v.toDouble() : double.tryParse('$v'.trim().replaceAll(',', '.'));
        if (n != null && n.isFinite) return n;
      }
    }
    return null;
  }
}

class _Feat {
  _Feat(this.id, this.kind, this.parts, this.props);
  final int id;

  /// 'point', 'line' or 'ring' (a polygon ring, closed on import).
  final String kind;
  final List<List<(double, double, double?)>> parts;
  final Map<String, dynamic> props;
}
