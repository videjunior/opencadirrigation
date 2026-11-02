/// ESRI Shapefile writer: the project's entities as one shapefile per layer
/// and geometry type (points, polylines, polygons; the Z variants where an
/// elevation is meaningful: contours, spot heights and, when the project has
/// a terrain, the pipes at their burial elevation and the point items at the
/// ground), with .shx index, .dbf attributes in UTF-8 (declared by a .cpg),
/// a .prj and everything zipped.
///
/// Attributes are those of the GeoJSON export (id, type, layer, name) plus
/// typed fields: catalogue item, nominal and inner diameter, length, flows,
/// velocities and pressures when results exist (in the project's units,
/// named in the field: FLOW_M3H, PMIN_MCA…), elevations, areas and crops.
///
/// Coordinates are the project's UTM zone (or geographic longitude/latitude)
/// on SIRGAS 2000 or WGS 84 (identical at mapping accuracy, see datum.dart)
/// when it is georeferenced, local metres otherwise (no .prj).
///
/// References: ESRI Shapefile Technical Description (ESRI white paper,
/// July 1998); dBASE III file structure (field descriptors, 0x0D header
/// terminator, 0x1A end of file); the .cpg code page file; WKT 1 in the
/// ESRI flavour for the .prj (see datum.dart).
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../design/results.dart';
import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import '../model/terrain.dart';
import '../units.dart';
import 'datum.dart';
import 'safe_archive.dart';

/// Shape types of the specification.
enum ShpShapeType {
  point(1),
  polyLine(3),
  polygon(5),
  pointZ(11),
  polyLineZ(13),
  polygonZ(15);

  const ShpShapeType(this.code);
  final int code;
  bool get hasZ => code > 10;
}

/// The files of one shapefile.
class ShapefileParts {
  ShapefileParts({required this.name, required this.shp, required this.shx, required this.dbf, this.prj, this.cpg = 'UTF-8', this.shapeType = ShpShapeType.point, this.recordCount = 0});
  final String name;
  final Uint8List shp, shx, dbf;
  final String? prj;
  final String? cpg;
  final ShpShapeType shapeType;
  final int recordCount;

  /// Splits a zip of shapefiles into their parts (by base name). Only the
  /// parts of shapefiles are decompressed, each up to the ceiling of an
  /// entry (`zip_too_large` beyond it).
  static List<ShapefileParts> unzip(Uint8List zip) {
    final arc = openZip(zip);
    final byBase = <String, Map<String, List<int>>>{};
    const parts = {'shp', 'shx', 'dbf', 'prj', 'cpg'};
    for (final f in arc.files) {
      if (!f.isFile) continue;
      final name = f.name.split('/').last;
      final dot = name.lastIndexOf('.');
      if (dot <= 0) continue;
      final ext = name.substring(dot + 1).toLowerCase();
      if (!parts.contains(ext)) continue;
      byBase.putIfAbsent(name.substring(0, dot), () => {})[ext] = zipEntryBytes(f, maxBytes: ext == 'prj' || ext == 'cpg' ? 1 << 20 : maxArchiveEntryBytes);
    }
    final out = <ShapefileParts>[];
    byBase.forEach((base, files) {
      final shp = files['shp'];
      if (shp == null) return;
      final type = shp.length >= 36 ? ByteData.sublistView(Uint8List.fromList(shp)).getInt32(32, Endian.little) : 0;
      out.add(
        ShapefileParts(
          name: base,
          shp: Uint8List.fromList(shp),
          shx: Uint8List.fromList(files['shx'] ?? const []),
          dbf: Uint8List.fromList(files['dbf'] ?? const []),
          prj: files['prj'] != null ? latin1.decode(files['prj']!) : null,
          cpg: files['cpg'] != null ? latin1.decode(files['cpg']!).trim() : null,
          shapeType: ShpShapeType.values.where((t) => t.code == type).firstOrNull ?? ShpShapeType.point,
        ),
      );
    });
    return out;
  }
}

/// A DBF field: C (text, UTF-8 bytes) or N (number).
class DbfField {
  const DbfField(this.name, this.type, this.length, [this.decimals = 0]);
  final String name;
  final String type;
  final int length;
  final int decimals;
}

class _Feature {
  _Feature(this.layer, this.kind, this.parts, this.attrs);
  final String layer;

  /// 'point', 'line' or 'polygon'.
  final String kind;

  /// (x, y, z?) per vertex, one list per part.
  final List<List<(double, double, double?)>> parts;
  final Map<String, Object?> attrs;
}

class ShapefileWriter {
  ShapefileWriter({required this.project, this.results, this.layerNames = const {}, this.geographic = false, this.datum = GeodeticDatum.sirgas2000});
  final Project project;
  final DesignResults? results;

  /// Display names of the layers (the LAYER attribute); raw names otherwise.
  final Map<String, String> layerNames;

  /// Longitude/latitude instead of UTM (needs a georeference).
  final bool geographic;

  /// Datum named in the .prj (SIRGAS 2000 or WGS 84 give the same numbers).
  final GeodeticDatum datum;

  /// Message codes of the last [shapefiles] call (`shp_no_georef`).
  final warnings = <String>[];

  late final Terrain _terrain = project.buildTerrain();
  Units get _u => project.params.units;

  /// One shapefile per layer and geometry type.
  List<ShapefileParts> shapefiles() {
    warnings.clear();
    final g = project.meta.georef;
    if (g == null) warnings.add('shp_no_georef');
    final crs = g == null ? null : (geographic ? CrsInfo.geographic(datum) : CrsInfo.utm(g.zone, g.north, datum: datum));
    (double, double) coord(Pt p) {
      if (g == null) return (p.x, p.y);
      if (geographic) {
        final (lat, lon) = g.toLatLon(p.x, p.y);
        return (lon, lat);
      }
      return g.toUtm(p.x, p.y);
    }

    final groups = <String, List<_Feature>>{};
    for (final f in _features()) {
      groups.putIfAbsent('${f.layer}\u0000${f.kind}', () => []).add(f);
    }
    final out = <ShapefileParts>[];
    final usedNames = <String>{};
    for (final entry in groups.entries) {
      final feats = entry.value;
      final kind = feats.first.kind;
      final hasZ = feats.any((f) => f.parts.any((pt) => pt.any((v) => v.$3 != null)));
      final type = switch (kind) {
        'point' => hasZ ? ShpShapeType.pointZ : ShpShapeType.point,
        'line' => hasZ ? ShpShapeType.polyLineZ : ShpShapeType.polyLine,
        _ => hasZ ? ShpShapeType.polygonZ : ShpShapeType.polygon,
      };
      var base = '${_asciiName(feats.first.layer)}_${kind == 'point' ? 'points' : (kind == 'line' ? 'lines' : 'polygons')}';
      for (var k = 2; usedNames.contains(base.toLowerCase()); k++) {
        base = '${base}_$k';
      }
      usedNames.add(base.toLowerCase());
      final records = [
        for (final f in feats)
          [
            for (final part in f.parts) [for (final v in part) (coord(Pt(v.$1, v.$2)), v.$3 ?? 0.0)],
          ],
      ];
      final (shp, shx) = writeShapes(type, records);
      final fields = _fieldsFor(feats);
      final dbf = writeDbf(fields, [for (final f in feats) f.attrs]);
      out.add(ShapefileParts(name: base, shp: shp, shx: shx, dbf: dbf, prj: crs?.toEsriWkt(), shapeType: type, recordCount: feats.length));
    }
    return out;
  }

  /// Every shapefile in one zip (`<layer>_<points|lines|polygons>.shp`,
  /// `.shx`, `.dbf`, `.cpg`, `.prj`).
  Uint8List zip() {
    final arc = Archive();
    for (final s in shapefiles()) {
      arc.addFile(ArchiveFile.bytes('${s.name}.shp', s.shp));
      arc.addFile(ArchiveFile.bytes('${s.name}.shx', s.shx));
      arc.addFile(ArchiveFile.bytes('${s.name}.dbf', s.dbf));
      arc.addFile(ArchiveFile.bytes('${s.name}.cpg', utf8.encode(s.cpg ?? 'UTF-8')));
      if (s.prj != null) arc.addFile(ArchiveFile.bytes('${s.name}.prj', utf8.encode(s.prj!)));
    }
    return ZipEncoder().encodeBytes(arc);
  }

  // ------------------------------------------------------------------ features

  String _layer(String l) => layerNames[l] ?? l;
  double? _ground(Pt p) => _terrain.isEmpty ? null : _terrain.elevationAt(p);
  String get _flowField => 'FLOW_${_u.flow.name.toUpperCase()}';
  String get _pressureSuffix => switch (_u.pressure) {
    PressureUnit.mH2O => 'MCA',
    PressureUnit.kPa => 'KPA',
    PressureUnit.bar => 'BAR',
    PressureUnit.psi => 'PSI',
    PressureUnit.ftH2O => 'FTH2O',
    // 1.6.0 CAD
    PressureUnit.kgfcm2 => 'KGFCM2',
  };
  String get _velocityField => _u.velocityLabel == 'ft/s' ? 'VEL_FTS' : 'VEL_MS';

  List<_Feature> _features() {
    final out = <_Feature>[];
    final cat = project.catalog;
    final pipeRes = results?.pipesByEntity ?? const <String, List<PipeSegmentResult>>{};
    final outletRes = results?.outletsByEntity ?? const <String, List<OutletResult>>{};
    final zoneNames = {for (final v in project.entities.whereType<ControlValveEntity>()) v.id: v.zoneName};
    final devices = <String, List<DeviceResult>>{};
    for (final z in results?.zones.values ?? const <ZoneResult>[]) {
      for (final d in z.devices) {
        devices.putIfAbsent(d.entityId, () => []).add(d);
      }
    }
    for (final f in results?.systemFlows ?? const <SystemFlowResult>[]) {
      for (final d in f.devices) {
        devices.putIfAbsent(d.entityId, () => []).add(d);
      }
    }

    Map<String, Object?> base(Entity e, {String? name}) => {'ID': e.id, 'TYPE': e.type.name, 'LAYER': _layer(e.layer), 'NAME': name ?? e.name};
    List<(double, double, double?)> flat(List<Pt> pts, [double? z]) => [for (final p in pts) (p.x, p.y, z)];
    List<(double, double, double?)> buried(List<Pt> pts, double depth) => [
      for (final p in pts)
        if (_ground(p) case final z?) (p.x, p.y, z - depth) else (p.x, p.y, null),
    ];
    void add(Entity e, String kind, List<List<(double, double, double?)>> parts, Map<String, Object?> attrs) {
      if (parts.isEmpty || parts.any((p) => p.isEmpty)) return;
      out.add(_Feature(_layer(e.layer), kind, parts, attrs));
    }

    void hydraulics(Map<String, Object?> a, List<PipeSegmentResult>? segs) {
      if (segs == null || segs.isEmpty) return;
      var q = 0.0, v = 0.0, pmin = double.infinity, pmax = -double.infinity;
      String? zone;
      for (final s in segs) {
        q = math.max(q, s.flow.abs());
        v = math.max(v, s.velocity.abs());
        pmin = math.min(pmin, math.min(s.pressureStart, s.pressureEnd));
        pmax = math.max(pmax, math.max(s.pressureStart, s.pressureEnd));
        zone ??= s.zoneId;
      }
      a[_flowField] = _u.flowFromSi(q);
      a[_velocityField] = _u.velocityFromSi(v);
      a['PMIN_$_pressureSuffix'] = _u.pressureFromHead(pmin);
      a['PMAX_$_pressureSuffix'] = _u.pressureFromHead(pmax);
      if (zone != null) a['ZONE'] = zoneNames[zone] ?? zone;
    }

    for (final e in project.entities) {
      switch (e) {
        case LineEntity l:
          add(
            e,
            'line',
            [
              flat([l.a, l.b]),
            ],
            {...base(e), 'LENGTH_M': l.length},
          );
        case PolylineEntity p:
          add(e, p.closed && p.points.length >= 3 ? 'polygon' : 'line', [flat(p.points)], {...base(e), if (p.closed) 'AREA_HA': p.area / 10000 else 'LENGTH_M': p.length});
        case CircleEntity c:
          add(e, 'line', [
            flat([for (var i = 0; i <= 36; i++) c.center + Pt.polar(c.radius, 2 * math.pi * i / 36)]),
          ], base(e));
        case ArcEntity a:
          add(e, 'line', [flat(a.polyline())], {...base(e), 'LENGTH_M': a.length});
        case SplineEntity sp:
          add(e, sp.closed ? 'polygon' : 'line', [flat(sp.curve())], base(e));
        case HatchEntity h:
          add(e, 'polygon', [flat(h.points)], {...base(e), 'AREA_HA': h.area / 10000});
        case SymbolEntity sy:
          add(e, 'point', [
            flat([sy.position]),
          ], base(e, name: sy.name.isEmpty ? sy.kind.name : sy.name));
        case TextEntity tx:
          add(e, 'point', [
            flat([tx.position]),
          ], base(e, name: tx.text));
        case LeaderEntity le:
          add(e, 'line', [flat(le.points)], base(e, name: le.text));
        case DimensionEntity d:
          add(
            e,
            'line',
            [
              flat([d.a, d.b]),
            ],
            {...base(e), 'LENGTH_M': d.length},
          );
        case WireEntity w:
          add(e, 'line', [flat(w.points)], {...base(e), 'LENGTH_M': w.length});
        case ControllerEntity k:
          add(
            e,
            'point',
            [
              flat([k.position], _ground(k.position)),
            ],
            {...base(e), 'STATIONS': k.stations},
          );
        case ImageEntity im:
          add(e, 'polygon', [flat(im.corners)], base(e, name: im.name.isEmpty ? im.source : im.name));
        case ContourEntity c:
          add(e, 'line', [flat(c.points, c.elevation)], {...base(e), 'ELEV': c.elevation});
        case SpotHeightEntity s:
          add(
            e,
            'point',
            [
              flat([s.position], s.elevation),
            ],
            {...base(e), 'ELEV': s.elevation},
          );
        case PipeEntity p:
          final spec = cat.pipe(p.pipeSpecId);
          final a = {
            ...base(e, name: p.name.isEmpty ? (spec?.name ?? '') : p.name),
            'LENGTH_M': p.length,
            'SPEC': spec?.name,
            'DN_MM': spec?.nominalMm,
            'ID_MM': spec?.innerDiameterMm,
            'DEPTH_M': p.depth,
          };
          hydraulics(a, pipeRes[p.id]);
          add(e, 'line', [buried(p.points, p.depth)], a);
        case SpraylineEntity s:
          final spec = cat.pipe(s.pipeSpecId);
          final outlet = cat.outlet(s.outletSpecId);
          final a = {
            ...base(e),
            'LENGTH_M': s.length,
            'SPEC': spec?.name,
            'DN_MM': spec?.nominalMm,
            'ID_MM': spec?.innerDiameterMm,
            'EMITTER': outlet?.name ?? s.outletSpecId,
            'OUTLETS': s.outletCount,
            'SPACING_M': s.spacing,
            'DEPTH_M': s.depth,
          };
          hydraulics(a, pipeRes[s.id]);
          add(e, 'line', [buried(s.points, s.depth)], a);
        case TapeEntity tp:
          final spec = cat.tape(tp.tapeSpecId);
          final a = {
            ...base(e, name: tp.name.isEmpty ? (spec?.name ?? '') : tp.name),
            'LENGTH_M': tp.length,
            'SPEC': spec?.name,
            'DN_MM': spec?.nominalMm,
            'ID_MM': spec?.innerDiameterMm,
            'SPACING_M': spec?.emitterSpacingM,
            'DEPTH_M': tp.depth,
          };
          hydraulics(a, pipeRes[tp.id]);
          add(e, 'line', [buried(tp.points, tp.depth)], a);
        case OutletEntity o:
          final spec = cat.outlet(o.outletSpecId);
          final nz = spec?.nozzle(o.nozzleId);
          final a = {...base(e, name: o.name.isEmpty ? (spec?.name ?? '') : o.name), 'SPEC': spec?.name, 'NOZZLE': nz?.name, 'ARC_DEG': o.arcDeg};
          final r = outletRes[o.id];
          if (r != null && r.isNotEmpty) {
            a[_flowField] = _u.flowFromSi(r.first.flow);
            a['PMIN_$_pressureSuffix'] = _u.pressureFromHead(r.first.pressure);
            a['PMAX_$_pressureSuffix'] = _u.pressureFromHead(r.first.pressure);
          }
          add(e, 'point', [
            flat([o.position], _ground(o.position)),
          ], a);
        case ControlValveEntity v:
          final spec = cat.valve(v.valveSpecId);
          final z = results?.zones[v.id];
          add(
            e,
            'point',
            [
              flat([v.position], _ground(v.position)),
            ],
            {
              ...base(e, name: v.zoneName.isEmpty ? v.name : v.zoneName),
              'SPEC': spec?.name,
              'DN_MM': spec?.sizeMm,
              'ZONE': v.zoneName,
              if (z != null) _flowField: _u.flowFromSi(z.totalFlow),
              if (z != null) 'PREQ_$_pressureSuffix': _u.pressureFromHead(z.requiredUpstreamHead),
            },
          );
        case WaterSupplyEntity s:
          final duties = [for (final f in results?.systemFlows ?? const <SystemFlowResult>[]) ...f.supplies.where((d) => d.supplyId == s.id)];
          add(
            e,
            'point',
            [
              flat([s.position], _ground(s.position)),
            ],
            {
              ...base(e),
              if (duties.isNotEmpty) _flowField: _u.flowFromSi(duties.map((d) => d.flow).reduce(math.max)),
              if (duties.isNotEmpty) 'PREQ_$_pressureSuffix': _u.pressureFromHead(duties.map((d) => d.requiredHead).reduce(math.max)),
            },
          );
        case PumpEntity pu:
          final spec = cat.pump(pu.pumpSpecId);
          final a = {...base(e, name: pu.name.isEmpty ? (spec?.name ?? '') : pu.name), 'SPEC': spec?.name};
          _deviceAttrs(a, devices[pu.id]);
          add(e, 'point', [
            flat([pu.position], _ground(pu.position)),
          ], a);
        case MiscHydraulicEntity m:
          final spec = cat.valve(m.valveSpecId);
          final a = {...base(e, name: m.name.isEmpty ? (spec?.name ?? '') : m.name), 'SPEC': spec?.name, 'DN_MM': spec?.sizeMm};
          _deviceAttrs(a, devices[m.id]);
          add(e, 'point', [
            flat([m.position], _ground(m.position)),
          ], a);
        case JunctionEntity j:
          add(e, 'point', [
            flat([j.position], j.fixedElevation ?? _ground(j.position)),
          ], base(e));
        case AreaEntity a:
          // 1.6.0 MOD: its islands as inner rings
          add(
            e,
            'polygon',
            [
              flat(a.points),
              for (final h in a.holes)
                if (h.length >= 3) flat(h),
            ],
            {...base(e), 'AREA_HA': a.area / 10000, 'CROP': a.crop},
          );
        case PivotEntity pv:
          final r = results?.pivots[pv.id];
          add(
            e,
            'polygon',
            [flat(pv.outline())],
            {
              ...base(e, name: pv.name.isEmpty ? pv.zoneName : pv.name),
              'LENGTH_M': pv.radiusM,
              if (r != null) _flowField: _u.flowFromSi(r.flow),
              if (r != null) 'PREQ_$_pressureSuffix': _u.pressureFromHead(r.inletHead),
            },
          );
        default:
          break;
      }
    }
    return out;
  }

  void _deviceAttrs(Map<String, Object?> a, List<DeviceResult>? ds) {
    if (ds == null || ds.isEmpty) return;
    final d = ds.reduce((x, y) => x.flow.abs() >= y.flow.abs() ? x : y);
    a[_flowField] = _u.flowFromSi(d.flow.abs());
    a['PMIN_$_pressureSuffix'] = _u.pressureFromHead(math.min(d.upstreamPressure, d.downstreamPressure));
    a['PMAX_$_pressureSuffix'] = _u.pressureFromHead(math.max(d.upstreamPressure, d.downstreamPressure));
  }

  /// The DBF fields used by [feats], in a fixed order.
  List<DbfField> _fieldsFor(List<_Feature> feats) {
    final ps = _pressureSuffix;
    final all = <DbfField>[
      const DbfField('ID', 'C', 24),
      const DbfField('TYPE', 'C', 20),
      const DbfField('LAYER', 'C', 60),
      const DbfField('NAME', 'C', 120),
      const DbfField('SPEC', 'C', 120),
      const DbfField('EMITTER', 'C', 80),
      const DbfField('NOZZLE', 'C', 60),
      const DbfField('ZONE', 'C', 60),
      const DbfField('LENGTH_M', 'N', 14, 3),
      const DbfField('DN_MM', 'N', 10, 1),
      const DbfField('ID_MM', 'N', 10, 2),
      const DbfField('DEPTH_M', 'N', 8, 3),
      DbfField(_flowField, 'N', 16, 4),
      DbfField(_velocityField, 'N', 10, 3),
      DbfField('PMIN_$ps', 'N', 12, 3),
      DbfField('PMAX_$ps', 'N', 12, 3),
      DbfField('PREQ_$ps', 'N', 12, 3),
      const DbfField('ELEV', 'N', 12, 3),
      const DbfField('AREA_HA', 'N', 16, 4),
      const DbfField('CROP', 'C', 60),
      const DbfField('OUTLETS', 'N', 8, 0),
      const DbfField('SPACING_M', 'N', 10, 3),
      const DbfField('ARC_DEG', 'N', 6, 1),
      const DbfField('STATIONS', 'N', 6, 0),
    ];
    const always = {'ID', 'TYPE', 'LAYER', 'NAME'};
    return [
      for (final f in all)
        if (always.contains(f.name) || feats.any((x) => x.attrs[f.name] != null)) f,
    ];
  }

  static String _asciiName(String s) {
    const from = 'ÀÁÂÃÄÅàáâãäåÈÉÊËèéêëÌÍÎÏìíîïÒÓÔÕÖòóôõöÙÚÛÜùúûüÇçÑñ';
    const to = 'AAAAAAaaaaaaEEEEeeeeIIIIiiiiOOOOOoooooUUUUuuuuCcNn';
    final b = StringBuffer();
    for (final ch in s.split('')) {
      final i = from.indexOf(ch);
      final c = i >= 0 ? to[i] : ch;
      b.write(RegExp(r'[A-Za-z0-9_\-]').hasMatch(c) ? c : '_');
    }
    var t = b.toString().replaceAll(RegExp(r'_+'), '_');
    if (t.isEmpty) t = 'layer';
    return t.length > 40 ? t.substring(0, 40) : t;
  }

  // ------------------------------------------------------------------ binary writers

  /// Whether [p] lies inside the ring [ring] (even-odd rule).
  static bool _inRing((double, double) p, List<((double, double), double)> ring) {
    var inside = false;
    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final (xi, yi) = ring[i].$1;
      final (xj, yj) = ring[j].$1;
      if ((yi > p.$2) != (yj > p.$2) && p.$1 < (xj - xi) * (p.$2 - yi) / (yj - yi) + xi) inside = !inside;
    }
    return inside;
  }

  /// Main file (.shp) and index (.shx) of [records]: per record its parts, per
  /// part ((x, y), z). Polygon rings are closed and oriented as the
  /// specification asks: outer rings clockwise, holes (a later ring of the
  /// record inside its first one: the islands of an area) counter-clockwise.
  static (Uint8List, Uint8List) writeShapes(ShpShapeType type, List<List<List<((double, double), double)>>> records) {
    final bodies = <Uint8List>[];
    var minX = double.infinity, minY = double.infinity, maxX = -double.infinity, maxY = -double.infinity, minZ = double.infinity, maxZ = -double.infinity;
    for (final rec in records) {
      var parts = rec;
      if (type == ShpShapeType.polygon || type == ShpShapeType.polygonZ) {
        parts = [
          for (var k = 0; k < rec.length; k++)
            () {
              final ring = rec[k];
              final hole = k > 0 && ring.isNotEmpty && _inRing(ring.first.$1, rec.first);
              var r = List.of(ring);
              if (r.length >= 2 && (r.first.$1.$1 != r.last.$1.$1 || r.first.$1.$2 != r.last.$1.$2)) r.add(r.first);
              // shoelace: positive = counter-clockwise (y up)
              var a = 0.0;
              for (var i = 0; i + 1 < r.length; i++) {
                a += r[i].$1.$1 * r[i + 1].$1.$2 - r[i + 1].$1.$1 * r[i].$1.$2;
              }
              if (hole ? a < 0 : a > 0) r = r.reversed.toList();
              return r;
            }(),
        ];
      }
      final pts = [for (final p in parts) ...p];
      for (final ((x, y), z) in pts) {
        minX = math.min(minX, x);
        maxX = math.max(maxX, x);
        minY = math.min(minY, y);
        maxY = math.max(maxY, y);
        minZ = math.min(minZ, z);
        maxZ = math.max(maxZ, z);
      }
      if (type == ShpShapeType.point || type == ShpShapeType.pointZ) {
        final ((x, y), z) = pts.first;
        final bd = ByteData(type.hasZ ? 36 : 20)
          ..setInt32(0, type.code, Endian.little)
          ..setFloat64(4, x, Endian.little)
          ..setFloat64(12, y, Endian.little);
        if (type.hasZ) {
          bd
            ..setFloat64(20, z, Endian.little)
            ..setFloat64(28, 0, Endian.little); // M
        }
        bodies.add(bd.buffer.asUint8List());
        continue;
      }
      final n = pts.length;
      final np = parts.length;
      final len = 44 + 4 * np + 16 * n + (type.hasZ ? 16 + 8 * n : 0);
      final bd = ByteData(len);
      var bx0 = double.infinity, by0 = double.infinity, bx1 = -double.infinity, by1 = -double.infinity, bz0 = double.infinity, bz1 = -double.infinity;
      for (final ((x, y), z) in pts) {
        bx0 = math.min(bx0, x);
        by0 = math.min(by0, y);
        bx1 = math.max(bx1, x);
        by1 = math.max(by1, y);
        bz0 = math.min(bz0, z);
        bz1 = math.max(bz1, z);
      }
      bd
        ..setInt32(0, type.code, Endian.little)
        ..setFloat64(4, bx0, Endian.little)
        ..setFloat64(12, by0, Endian.little)
        ..setFloat64(20, bx1, Endian.little)
        ..setFloat64(28, by1, Endian.little)
        ..setInt32(36, np, Endian.little)
        ..setInt32(40, n, Endian.little);
      var idx = 0;
      for (var k = 0; k < np; k++) {
        bd.setInt32(44 + 4 * k, idx, Endian.little);
        idx += parts[k].length;
      }
      var off = 44 + 4 * np;
      for (final ((x, y), _) in pts) {
        bd
          ..setFloat64(off, x, Endian.little)
          ..setFloat64(off + 8, y, Endian.little);
        off += 16;
      }
      if (type.hasZ) {
        bd
          ..setFloat64(off, bz0, Endian.little)
          ..setFloat64(off + 8, bz1, Endian.little);
        off += 16;
        for (final (_, z) in pts) {
          bd.setFloat64(off, z, Endian.little);
          off += 8;
        }
      }
      bodies.add(bd.buffer.asUint8List());
    }
    if (records.isEmpty) minX = minY = maxX = maxY = minZ = maxZ = 0;
    if (!type.hasZ) minZ = maxZ = 0;
    ByteData header(int fileWords) {
      final h = ByteData(100)
        ..setInt32(0, 9994, Endian.big)
        ..setInt32(24, fileWords, Endian.big)
        ..setInt32(28, 1000, Endian.little)
        ..setInt32(32, type.code, Endian.little)
        ..setFloat64(36, minX, Endian.little)
        ..setFloat64(44, minY, Endian.little)
        ..setFloat64(52, maxX, Endian.little)
        ..setFloat64(60, maxY, Endian.little)
        ..setFloat64(68, minZ, Endian.little)
        ..setFloat64(76, maxZ, Endian.little);
      return h;
    }

    final shpLen = 100 + bodies.fold<int>(0, (s, b) => s + 8 + b.length);
    final shp = BytesBuilder(copy: false)..add(header(shpLen ~/ 2).buffer.asUint8List());
    final shx = BytesBuilder(copy: false)..add(header((100 + 8 * bodies.length) ~/ 2).buffer.asUint8List());
    var offsetWords = 50;
    for (var i = 0; i < bodies.length; i++) {
      final rh = ByteData(8)
        ..setInt32(0, i + 1, Endian.big)
        ..setInt32(4, bodies[i].length ~/ 2, Endian.big);
      shp
        ..add(rh.buffer.asUint8List())
        ..add(bodies[i]);
      final ix = ByteData(8)
        ..setInt32(0, offsetWords, Endian.big)
        ..setInt32(4, bodies[i].length ~/ 2, Endian.big);
      shx.add(ix.buffer.asUint8List());
      offsetWords += (8 + bodies[i].length) ~/ 2;
    }
    return (shp.toBytes(), shx.toBytes());
  }

  /// dBASE III table: text in UTF-8 (cut at a character boundary), numbers
  /// right-aligned, empty values blank.
  static Uint8List writeDbf(List<DbfField> fields, List<Map<String, Object?>> rows, {DateTime? date}) {
    final d = date ?? DateTime.now();
    final headerLen = 32 + 32 * fields.length + 1;
    final recLen = 1 + fields.fold<int>(0, (s, f) => s + f.length);
    final out = BytesBuilder(copy: false);
    final h = ByteData(32)
      ..setUint8(0, 0x03)
      ..setUint8(1, d.year - 1900)
      ..setUint8(2, d.month)
      ..setUint8(3, d.day)
      ..setUint32(4, rows.length, Endian.little)
      ..setUint16(8, headerLen, Endian.little)
      ..setUint16(10, recLen, Endian.little);
    out.add(h.buffer.asUint8List());
    for (final f in fields) {
      final fd = Uint8List(32);
      final nb = latin1.encode(f.name.length > 10 ? f.name.substring(0, 10) : f.name);
      fd.setRange(0, nb.length, nb);
      fd[11] = f.type.codeUnitAt(0);
      fd[16] = f.length;
      fd[17] = f.decimals;
      out.add(fd);
    }
    out.addByte(0x0D);
    for (final r in rows) {
      final rec = Uint8List(recLen)..fillRange(0, recLen, 0x20);
      var off = 1;
      for (final f in fields) {
        final v = r[f.name];
        List<int> bytes;
        if (v == null) {
          bytes = const [];
        } else if (f.type == 'N') {
          final n = v is num ? v.toDouble() : double.tryParse('$v');
          var s = n == null || !n.isFinite ? '' : n.toStringAsFixed(f.decimals);
          if (s.length > f.length) s = n!.toStringAsFixed(0);
          if (s.length > f.length) s = '';
          bytes = latin1.encode(s.padLeft(f.length));
        } else {
          var b = utf8.encode('$v');
          if (b.length > f.length) {
            // cut at a character boundary (continuation bytes are 10xxxxxx)
            var end = f.length;
            while (end > 0 && (b[end] & 0xC0) == 0x80) {
              end--;
            }
            b = b.sublist(0, end);
          }
          bytes = b;
        }
        rec.setRange(off, off + bytes.length, bytes);
        off += f.length;
      }
      out.add(rec);
    }
    out.addByte(0x1A);
    return out.toBytes();
  }
}
