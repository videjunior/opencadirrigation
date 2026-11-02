/// Drawings, maps and surveys into a project, in the engine (1.6.0 MOD,
/// MOD-22): the conversion File → Import does of a drawing into entities
/// ([importDrawingInto], which the app calls), and the reading of a file
/// by its extension ([importFileInto]) for the command line and other
/// programs: DXF, DWG, DGN, KML/KMZ, shapefiles (one, or every one of a
/// zip), GeoJSON, GPX, LandXML, EPANET .inp, LAS point clouds, GeoTIFF
/// elevations and CSV point lists. PDF plans and pictures need the app's
/// dialogs and stay there.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import 'cad_drawing.dart' show aciRgb;
import 'codepages.dart' show decodeTextBytes;
import 'dem_tiff.dart';
import 'dgn.dart';
import 'dwg.dart';
import 'dxf.dart';
import 'epanet_inp.dart';
import 'geojson_reader.dart';
import 'gpx.dart';
import 'kml.dart';
import 'landxml.dart';
import 'las.dart';
import 'points_csv.dart';
import 'shp.dart';
import 'shp_writer.dart' show ShapefileParts;

/// What [importDrawingInto] added to the project.
class DrawingImport {
  const DrawingImport(this.entities, this.notes);

  /// The entities made, in the order of the drawing.
  final List<Entity> entities;

  /// Notes on the placement of the drawing: `cad_moved_to_georef`,
  /// `cad_far_from_georef`, `cad_utm_no_georef`.
  final List<String> notes;
}

/// Adds the entities of the imported drawing [doc] to [p] (contours and
/// spot heights when elevations are present) and returns them.
///
/// Points without an elevation (GPS waypoints, the markers of a KML, the
/// points of a 2D drawing, a list of points without Z) become small
/// circles: a spot height at zero would pull the terrain down. Layers are
/// matched without regard to case, as CAD programs do ("Text" and "TEXT"
/// are one layer), and new ones take the colour (index or true colour) and
/// the off or frozen state of the file. A drawing in UTM coordinates
/// imported into a georeferenced project is moved by the project origin
/// (with a note); into a project without one, the note says so. Geometry
/// that is not a number (a damaged file) is left out.
DrawingImport importDrawingInto(Project p, DxfDocument doc) {
  final notes = <String>[];
  final s = doc.unitScale;
  final shift = _utmShift(p, doc, notes);
  Pt at(Pt q) => Pt(q.x * s - shift.x, q.y * s - shift.y);
  final list = <Entity>[];
  final byKey = {for (final l in p.layers) l.name.toLowerCase(): l.name};
  for (final l in doc.layers) {
    final key = l.name.toLowerCase();
    if (byKey.containsKey(key)) continue;
    p.layers.add(Layer(name: l.name, color: 0xFF000000 | (l.rgb ?? aciRgb(l.color)), visible: l.visible));
    byKey[key] = l.name;
  }
  for (final e in doc.entities) {
    // a damaged file may hold "nan" or huge exponents: such geometry is
    // left out (it could neither be drawn nor saved)
    if (!_finiteGeometry(e)) continue;
    final layer = byKey[e.layer.toLowerCase()] ?? e.layer;
    final elev = e.elevation != null && e.elevation!.isFinite ? e.elevation : null;
    switch (e.type) {
      case 'LINE':
        list.add(LineEntity(id: p.newId(), layer: layer, name: e.name, a: at(e.points[0]), b: at(e.points[1])));
      case 'POLYLINE':
        if (e.points.length < 2) break;
        final pts = e.points.map(at).toList();
        if (!e.closed && looksLikeBreaklineLayer(layer)) {
          list.add(BreaklineEntity(id: p.newId(), layer: Layers.breaklines, name: e.name, points: pts, elevations: elev == null ? null : List.filled(pts.length, elev * s)));
        } else if (elev != null && elev != 0 && !e.closed && looksLikeContourLayer(layer)) {
          list.add(ContourEntity(id: p.newId(), layer: Layers.contours, name: e.name, points: pts, elevation: elev * s));
        } else if (elev != null && elev != 0 && !e.closed && pts.length >= 3) {
          list.add(ContourEntity(id: p.newId(), layer: Layers.contours, name: e.name, points: pts, elevation: elev * s));
        } else {
          list.add(PolylineEntity(id: p.newId(), layer: layer, name: e.name, points: pts, closed: e.closed));
        }
      case 'SPLINE':
        if (e.points.length >= 2) list.add(SplineEntity(id: p.newId(), layer: layer, name: e.name, points: e.points.map(at).toList(), closed: e.closed));
      case 'HATCH':
        if (e.points.length >= 3) {
          list.add(HatchEntity(id: p.newId(), layer: layer, name: e.name, points: e.points.map(at).toList(), angleDeg: e.rotation, spacing: e.height > 0 ? e.height * s : 1, solid: e.solid));
        }
      case 'CIRCLE':
        list.add(CircleEntity(id: p.newId(), layer: layer, name: e.name, center: at(e.center!), radius: e.radius * s));
      case 'ARC':
        // one turn at most, whatever the angles of the file
        final sweep = radToDeg(cadSweepRad(degToRad(e.startAngle), degToRad(e.endAngle)));
        list.add(ArcEntity(id: p.newId(), layer: layer, name: e.name, center: at(e.center!), radius: e.radius * s, startRad: degToRad(cadNormalizeDeg(e.startAngle)), sweepRad: degToRad(sweep)));
      case 'TEXT':
        list.add(TextEntity(id: p.newId(), layer: layer, name: e.name, position: at(e.points[0]), text: e.text, height: e.height * s, rotationDeg: e.rotation));
      case 'POINT':
        if (elev == null) {
          // a place without an elevation: a marker, never a spot height at zero
          list.add(CircleEntity(id: p.newId(), layer: layer, name: e.name, center: at(e.points[0]), radius: 0.5));
        } else {
          list.add(SpotHeightEntity(id: p.newId(), layer: Layers.spotHeights, name: e.name, position: at(e.points[0]), elevation: elev * s));
        }
    }
  }
  p.entities.addAll(list);
  return DrawingImport(list, notes);
}

/// Offset of a drawing whose coordinates are UTM ones (eastings of 100 to
/// 900 km, northings up to 10 000 km) for the georeferenced project [p]:
/// its origin, when the drawing lands within 100 km of it ([notes] says the
/// drawing was moved, or that it lies far away and was kept). Raw CAD
/// coordinates only reach here that large: the GIS readers place theirs.
Pt _utmShift(Project p, DxfDocument doc, List<String> notes) {
  final b = doc.bounds;
  if (b.isEmpty) return Pt.zero;
  final s = doc.unitScale;
  final cx = (b.minX + b.maxX) / 2 * s, cy = (b.minY + b.maxY) / 2 * s;
  if (!cx.isFinite || !cy.isFinite || (cx.abs() <= 100000 && cy.abs() <= 100000)) return Pt.zero;
  final utm = cx >= 100000 && cx <= 900000 && cy >= 0 && cy <= 10000000;
  if (!utm) return Pt.zero;
  final g = p.meta.georef;
  if (g == null) {
    notes.add('cad_utm_no_georef');
    return Pt.zero;
  }
  if ((cx - g.originEasting).abs() > 100000 || (cy - g.originNorthing).abs() > 100000) {
    notes.add('cad_far_from_georef');
    return Pt.zero;
  }
  notes.add('cad_moved_to_georef');
  return Pt(g.originEasting, g.originNorthing);
}

bool _finiteGeometry(DxfEntity e) {
  bool ok(Pt q) => q.x.isFinite && q.y.isFinite;
  return e.points.every(ok) && (e.center == null || ok(e.center!)) && e.radius.isFinite && e.startAngle.isFinite && e.endAngle.isFinite && e.rotation.isFinite && e.height.isFinite;
}

/// Layers of breaklines in survey drawings ("BREAKLINES", "linha de
/// quebra", "quiebre", "ruptura").
bool looksLikeBreaklineLayer(String layer) {
  final l = layer.toLowerCase();
  return l.contains('break') || l.contains('quebra') || l.contains('quiebre') || l.contains('ruptura');
}

/// Layers of contour lines in survey drawings ("CONTOURS", "curvas de
/// nível", "topo", "elev"…).
bool looksLikeContourLayer(String layer) {
  final l = layer.toLowerCase();
  return l.contains('cont') || l.contains('curva') || l.contains('nivel') || l.contains('nível') || l.contains('topo') || l.contains('elev');
}

// ---------------------------------------------------------------- files

/// What [importFileInto] did.
class FileImport {
  const FileImport({required this.kind, required this.entities, this.counts = const {}, this.warnings = const [], this.georefTaken = false});

  /// The kind of file read: `dxf`, `dwg`, `dgn`, `kml`, `kmz`, `points`,
  /// `shp`, `geojson`, `gpx`, `landxml`, `inp`, `las` or `dem`.
  final String kind;

  /// The entities added to the project.
  final List<Entity> entities;

  /// What the file held, for the summary (records, placemarks, features,
  /// points read, the coordinate system…).
  final Map<String, String> counts;

  /// Message codes of the reader and the placement (as the app's import
  /// summary shows them).
  final List<String> warnings;

  /// The project took the georeference the file brought.
  final bool georefTaken;
}

/// The extensions [importFileInto] reads.
const drawingImportExtensions = [
  '.dxf',
  '.dwg',
  '.dgn',
  '.kml',
  '.kmz',
  '.shp',
  '.zip',
  '.geojson',
  '.json',
  '.gpx',
  '.xml',
  '.landxml',
  '.inp',
  '.las',
  '.laz',
  '.csv',
  '.txt',
  '.xyz',
  '.pnezd',
  '.pts',
  '.tif',
  '.tiff',
];

/// Reads the file [name] ([bytes]) into [p] by its extension, as File →
/// Import does in the app: the drawing's entities (see [importDrawingInto]),
/// the georeference a GIS file brings when [p] has none, the ground points
/// of a LAS cloud and the heights of a GeoTIFF as spot heights (`DEM
/// <name>`, replacing those of an earlier import of the same file). Throws
/// a [FormatException]: `import_format` for an extension it does not read
/// (PDF plans and pictures need the app), `import_not_dem` for a GeoTIFF
/// that holds no elevations, `file_corrupt` for a file that trips a reader.
FileImport importFileInto(Project p, String name, Uint8List bytes) {
  final lower = name.toLowerCase();
  final had = p.meta.georef;
  try {
    final r = _importFile(p, name, lower, bytes);
    return FileImport(kind: r.kind, entities: r.entities, counts: r.counts, warnings: r.warnings, georefTaken: had == null && p.meta.georef != null);
  } on Error {
    // a damaged file trips the readers' bounds (index, type, state errors)
    throw const FormatException('file_corrupt');
  }
}

bool _zipHas(Uint8List bytes, String ext) {
  // cheap check of the central directory names
  final s = latin1.decode(bytes.length > 200000 ? bytes.sublist(bytes.length - 200000) : bytes, allowInvalid: true).toLowerCase();
  return s.contains(ext);
}

FileImport _importFile(Project p, String name, String lower, Uint8List bytes) {
  String text() => decodeTextBytes(bytes);
  FileImport drawing(String kind, DxfDocument doc, {Map<String, String> counts = const {}, Iterable<String> warnings = const []}) {
    final d = importDrawingInto(p, doc);
    return FileImport(kind: kind, entities: d.entities, counts: {...counts, 'n': '${d.entities.length}'}, warnings: [...warnings, ...d.notes]);
  }

  FileImport dem(String kind, Iterable<(Pt, double)> samples, {Map<String, String> counts = const {}, Iterable<String> warnings = const []}) {
    final label = 'DEM $name';
    p.entities.removeWhere((e) => e is SpotHeightEntity && e.name == label);
    final made = <Entity>[for (final (q, z) in samples) SpotHeightEntity(id: p.newId(), position: q, elevation: z, name: label)];
    p.entities.addAll(made);
    return FileImport(kind: kind, entities: made, counts: {...counts, 'n': '${made.length}'}, warnings: [...warnings]);
  }

  if (lower.endsWith('.dwg')) {
    final r = DwgReader.parse(bytes);
    return drawing('dwg', r.document, counts: {'v': r.version.toUpperCase(), 'l': '${r.document.layers.length}'}, warnings: r.document.warnings);
  }
  if (lower.endsWith('.kmz')) {
    final r = KmlReader.parseKmz(bytes, georef: p.meta.georef);
    p.meta.georef ??= r.georef;
    return drawing('kmz', r.document, counts: {'k': 'KMZ', 'p': '${r.placemarkCount}', 'crs': r.georef.crsName});
  }
  if (lower.endsWith('.kml')) {
    final r = KmlReader.parse(text(), georef: p.meta.georef);
    p.meta.georef ??= r.georef;
    return drawing('kml', r.document, counts: {'k': 'KML', 'p': '${r.placemarkCount}', 'crs': r.georef.crsName});
  }
  if (lower.endsWith('.csv') || lower.endsWith('.txt') || lower.endsWith('.xyz') || lower.endsWith('.pnezd') || lower.endsWith('.pts')) {
    final r = PointsCsvReader.parse(text(), georef: p.meta.georef);
    if (r.georef != null) p.meta.georef ??= r.georef;
    return drawing('points', r.document, counts: {'geo': r.geographic ? (p.meta.georef?.crsName ?? 'WGS84') : ''}, warnings: r.warnings);
  }
  if (lower.endsWith('.zip') && _zipHas(bytes, '.shp')) {
    // every shapefile of the zip, each on the layer of its name
    final parts = ShapefileParts.unzip(bytes);
    if (parts.length > 1) {
      var records = 0;
      final warnings = <String>{};
      final made = <Entity>[];
      var crs = '';
      for (final f in parts) {
        final r = ShpReader.parse(f.shp, dbf: f.dbf, prj: f.prj, cpg: f.cpg, shx: f.shx.isEmpty ? null : f.shx, georef: p.meta.georef, layer: f.name);
        if (r.georef != null) p.meta.georef ??= r.georef;
        final d = importDrawingInto(p, r.document);
        made.addAll(d.entities);
        warnings.addAll([...r.warnings, ...d.notes]);
        records += r.recordCount;
        if (crs.isEmpty) crs = r.crs;
      }
      return FileImport(kind: 'shp', entities: made, counts: {'r': '$records', 'n': '${made.length}', 'crs': crs.isEmpty ? (p.meta.georef?.crsName ?? '-') : crs}, warnings: [...warnings]);
    }
  }
  if (lower.endsWith('.shp') || (lower.endsWith('.zip') && _zipHas(bytes, '.shp'))) {
    final r = ShpReader.parseAny(name, bytes, georef: p.meta.georef);
    if (r.georef != null) p.meta.georef ??= r.georef;
    return drawing('shp', r.document, counts: {'r': '${r.recordCount}', 'crs': r.crs.isEmpty ? (p.meta.georef?.crsName ?? '-') : r.crs}, warnings: r.warnings);
  }
  if (lower.endsWith('.geojson') || lower.endsWith('.json')) {
    final r = GeoJsonReader.parse(text(), georef: p.meta.georef);
    if (r.georef != null) p.meta.georef ??= r.georef;
    return drawing('geojson', r.document, counts: {'f': '${r.featureCount}', 'crs': r.crs.recognised ? r.crs.name : (p.meta.georef?.crsName ?? '-')}, warnings: r.warnings);
  }
  if (lower.endsWith('.gpx')) {
    final r = GpxReader.parse(text(), georef: p.meta.georef);
    if (r.georef != null) p.meta.georef ??= r.georef;
    return drawing('gpx', r.document, counts: {'w': '${r.waypointCount}', 'r': '${r.routeCount}', 't': '${r.trackCount}'}, warnings: r.warnings);
  }
  if (lower.endsWith('.xml') || lower.endsWith('.landxml')) {
    final r = LandXmlReader.parse(text(), georef: p.meta.georef);
    if (r.georef != null) p.meta.georef ??= r.georef;
    return drawing('landxml', r.document, counts: {'s': '${r.surfaces.length}', 'p': '${r.cgPointCount}'}, warnings: r.warnings);
  }
  if (lower.endsWith('.las') || lower.endsWith('.laz')) {
    // a point cloud: its ground points, thinned to a grid, become terrain
    final r = LasReader.read(bytes, georef: p.meta.georef);
    if (r.georef != null) p.meta.georef ??= r.georef;
    return dem('las', [for (final x in r.samples) (x.p, x.z)], counts: {'p': '${r.pointsRead}', 'c': r.cellSize.toStringAsFixed(1)}, warnings: r.warnings);
  }
  if (lower.endsWith('.dgn')) {
    final r = DgnReader.parse(bytes);
    return drawing('dgn', r.document, counts: {'u': r.masterUnit}, warnings: r.warnings);
  }
  if (lower.endsWith('.inp')) {
    final m = EpanetInpReader.parse(text());
    final (doc, placement) = m.toDocument(georef: p.meta.georef);
    if (placement.georef != null) p.meta.georef ??= placement.georef;
    return drawing('inp', doc, counts: {'j': '${m.junctions.length}', 'l': '${m.pipes.length + m.pumps.length + m.valves.length}'}, warnings: {...m.warnings, ...placement.warnings});
  }
  if (lower.endsWith('.tif') || lower.endsWith('.tiff')) {
    // an elevation raster (one band of heights) becomes terrain
    final d = GeoTiffDemReader.read(bytes, georef: p.meta.georef);
    if (d == null) throw const FormatException('import_not_dem');
    p.meta.georef ??= d.georef;
    return dem('dem', [for (final x in d.samples) (x.p, x.z)], counts: {'w': '${d.widthPx}', 'h': '${d.heightPx}', 'crs': d.crsName}, warnings: d.warnings);
  }
  if (lower.endsWith('.dxf')) {
    // the text in the file's code page ($DWGCODEPAGE) or UTF-8
    final doc = DxfReader.parseBytes(bytes);
    return drawing('dxf', doc, warnings: doc.warnings);
  }
  throw const FormatException('import_format');
}
