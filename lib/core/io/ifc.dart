/// IFC4 export of the irrigation system for BIM and site-works software: a
/// STEP physical file (ISO 10303-21) of the IFC4 schema (ISO 16739-1:2018,
/// IFC4 ADD2 TC1), Reference View.
///
/// Spatial structure: IfcProject → IfcSite (site works need no building;
/// IFC4 elements may be contained in the site), with the terrain TIN as the
/// site's body (IfcTriangulatedFaceSet) and, when the project is
/// georeferenced, IfcMapConversion + IfcProjectedCRS (EPSG code of the UTM
/// zone, SIRGAS 2000 or WGS 84) and the reference latitude/longitude of the
/// site. Geometry is in local metres from the project origin; elevations are
/// absolute (OrthogonalHeight 0).
///
/// Elements, each with its standard property sets and a custom one
/// (`OCI_Hydraulics`: flow, pressures in pascals and as metres of head,
/// velocity, catalogue item, zone):
/// - pipes, laterals and tapes: IfcPipeSegment (FLEXIBLESEGMENT for
///   polyethylene and tapes, RIGIDSEGMENT for PVC and metal) with an
///   IfcSweptDiskSolid (outer and inner radius) along the pipe at the burial
///   depth (ground − depth, the axis, sampled along the terrain), an 'Axis'
///   Curve3D, Pset_PipeSegmentTypeCommon and Pset_PipeSegmentOccurrence;
/// - heads, emitters and the outlets of the laterals: IfcFlowTerminal. IFC4
///   has no terminal class for irrigation outlets — IfcFireSuppressionTerminal
///   SPRINKLER is a fire-protection head with fire property sets, and
///   IfcSanitaryTerminal a sanitary fixture — so the generic flow terminal is
///   used, with ObjectType `IRRIGATION_<KIND>` (SPRINKLER, MICROSPRINKLER,
///   DRIPPER, BUBBLER, GUN, DEMANDPOINT); IfcFlowTerminal has no
///   PredefinedType in IFC4. The integral drippers of a tape are not
///   instantiated (the tape segment carries their count and spacing);
/// - zone valves and devices: IfcValve (zone valves USERDEFINED `ZONECONTROL`,
///   no enumeration value fits a remotely operated on/off zone valve;
///   PRESSUREREDUCING, ISOLATING, CHECK, DOUBLECHECK, AIRRELEASE), filters
///   IfcFilter WATERFILTER, meters IfcFlowMeter WATERMETER, with
///   Pset_ValveTypeCommon / Pset_FilterTypeCommon;
/// - pumps: IfcPump (SUBMERSIBLEPUMP or NOTDEFINED); reservoirs: IfcTank STORAGE;
/// - fittings are not exported: the design selects them for the bill of
///   materials without positions.
/// Catalogue items carry Pset_ManufacturerTypeInformation (shared by every
/// element of the item). Every zone and the mainline is an
/// IfcDistributionSystem (USERDEFINED `IRRIGATION`) serving the site.
///
/// GlobalIds are derived from the project id and the entity ids, so the same
/// project exports the same ids.
library;

import 'dart:convert';
import 'dart:math' as math;

import '../design/network_builder.dart';
import '../design/results.dart';
import '../hydraulics/water_hammer.dart' show PipeMaterial;
import '../model/catalog.dart';
import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import '../model/terrain.dart';
import 'datum.dart';

/// The written file and what it holds.
class IfcExport {
  IfcExport({required this.text, required this.counts, required this.warnings});
  final String text;

  /// Instances written per IFC element class (IFCPIPESEGMENT …).
  final Map<String, int> counts;

  /// Message codes (`ifc_no_georef`, `ifc_fittings_not_exported`, `ifc_terminals_limited:<n>`).
  final List<String> warnings;
}

class IfcWriter {
  /// IFC4 of [project]. [lateralOutlets] adds an IfcFlowTerminal at every
  /// outlet of the laterals (at most [maxTerminals] terminals); [terrain]
  /// gives the site the TIN as its body; pipes follow the ground with a
  /// vertex every [densify] metres.
  static IfcExport write(Project project, {DesignResults? results, String fileName = 'project.ifc', DateTime? time, String applicationVersion = '', GeodeticDatum datum = GeodeticDatum.sirgas2000, bool terrain = true, bool lateralOutlets = true, int maxTerminals = 20000, double densify = 5}) =>
      _IfcBuilder(project, results, fileName, time ?? DateTime.now(), applicationVersion, datum, terrain, lateralOutlets, maxTerminals, densify).build();
}

// ------------------------------------------------------------------ STEP values

class _Ref {
  const _Ref(this.id);
  final int id;
}

class _Enum {
  const _Enum(this.v);
  final String v;
}

class _Int {
  const _Int(this.v);
  final int v;
}

class _Typed {
  const _Typed(this.type, this.value);
  final String type;
  final Object value;
}

class _Derived {
  const _Derived();
}

const _star = _Derived();

/// STEP encoding of one attribute value. Every [num] is a REAL (written with
/// a decimal point, also on platforms where 1.0 is an int); integers are [_Int].
String _enc(Object? v) => switch (v) {
  null => r'$',
  _Derived _ => '*',
  _Ref r => '#${r.id}',
  _Enum e => '.${e.v}.',
  _Int i => '${i.v}',
  bool b => b ? '.T.' : '.F.',
  num n => _real(n.toDouble()),
  String s => _str(s),
  _Typed t => '${t.type}(${_enc(t.value)})',
  List l => '(${l.map(_enc).join(',')})',
  _ => throw ArgumentError('ifc_value'),
};

String _real(double v) {
  if (!v.isFinite) return '0.';
  if (v == v.truncateToDouble() && v.abs() < 1e15) return '${v.toInt()}.';
  var s = v.toStringAsPrecision(15);
  var exp = '';
  final e = s.indexOf(RegExp('[eE]'));
  if (e >= 0) {
    exp = 'E${s.substring(e + 1)}';
    s = s.substring(0, e);
  }
  if (!s.contains('.')) s = '$s.';
  s = s.replaceFirst(RegExp(r'0+$'), '');
  return '$s$exp';
}

/// STEP string: quotes doubled, backslashes doubled, characters outside
/// printable ASCII as \X2\…\X0\ (UTF-16 code units in hex).
String _str(String s) {
  final b = StringBuffer("'");
  var wide = false;
  for (final c in s.codeUnits) {
    final printable = c >= 0x20 && c <= 0x7E;
    if (printable && wide) {
      b.write(r'\X0\');
      wide = false;
    }
    if (printable) {
      if (c == 0x27) {
        b.write("''");
      } else if (c == 0x5C) {
        b.write(r'\\');
      } else {
        b.writeCharCode(c);
      }
    } else {
      if (!wide) b.write(r'\X2\');
      wide = true;
      b.write(c.toRadixString(16).toUpperCase().padLeft(4, '0'));
    }
  }
  if (wide) b.write(r'\X0\');
  b.write("'");
  return b.toString();
}

/// 32-bit multiplication modulo 2³², exact on every platform.
int _mul32(int a, int b) => (((a & 0xFFFF) * b) + ((((a >>> 16) * b) & 0xFFFF) << 16)) & 0xFFFFFFFF;

/// A 22-character IFC GlobalId (the 128-bit identifier in the IFC base-64
/// alphabet) derived from [seed].
String ifcGuid(String seed) {
  final bytes = utf8.encode(seed);
  final out = <int>[];
  for (var lane = 0; lane < 4; lane++) {
    var h = (0x811C9DC5 ^ ((lane * 0x9E3779B9) & 0xFFFFFFFF)) & 0xFFFFFFFF;
    for (final c in bytes) {
      h = _mul32((h ^ c) & 0xFFFFFFFF, 0x01000193);
    }
    h = (h ^ (h >>> 16)) & 0xFFFFFFFF;
    h = _mul32(h, 0x85EBCA6B);
    h = (h ^ (h >>> 13)) & 0xFFFFFFFF;
    h = _mul32(h, 0xC2B2AE35);
    h = (h ^ (h >>> 16)) & 0xFFFFFFFF;
    out.addAll([(h >>> 24) & 0xFF, (h >>> 16) & 0xFF, (h >>> 8) & 0xFF, h & 0xFF]);
  }
  const chars = r'0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_$';
  String enc(int v, int n) => [for (var i = n - 1; i >= 0; i--) chars[(v >> (6 * i)) & 63]].join();
  final b = StringBuffer(enc(out[0], 2));
  for (var i = 1; i < 16; i += 3) {
    b.write(enc((out[i] << 16) | (out[i + 1] << 8) | out[i + 2], 4));
  }
  return b.toString();
}

class _Step {
  final b = StringBuffer();
  int n = 0;
  final counts = <String, int>{};

  _Ref add(String type, List<Object?> args) {
    n++;
    b
      ..write('#$n=$type(')
      ..write(args.map(_enc).join(','))
      ..write(');\n');
    counts[type] = (counts[type] ?? 0) + 1;
    return _Ref(n);
  }
}

// ------------------------------------------------------------------ builder

class _IfcBuilder {
  _IfcBuilder(this.project, this.results, this.fileName, this.time, this.version, this.datum, this.withTerrain, this.lateralOutlets, this.maxTerminals, this.densify);
  final Project project;
  final DesignResults? results;
  final String fileName;
  final DateTime time;
  final String version;
  final GeodeticDatum datum;
  final bool withTerrain;
  final bool lateralOutlets;
  final int maxTerminals;
  final double densify;

  final s = _Step();
  final warnings = <String>[];
  late final Terrain terrain = project.buildTerrain();
  Catalog get cat => project.catalog;
  static const double paPerMetre = 9806.65;

  late _Ref origin, zDir, xDir, wcs, body, axis, sitePlacement, metre, identityOp;
  final elements = <_Ref>[];
  final byEntity = <String, List<_Ref>>{};
  final shared = <String, (_Ref, List<_Ref>)>{};
  final maps = <String, _Ref>{};
  var _seq = 0;

  String guid(String seed) => ifcGuid('${project.meta.uid}|$seed');
  String nextGuid(String kind) => guid('$kind#${_seq++}');

  _Ref pt3(double x, double y, double z) => s.add('IFCCARTESIANPOINT', [
        [x, y, z],
      ]);
  _Ref placementAt(double x, double y, double z) => s.add('IFCLOCALPLACEMENT', [sitePlacement, s.add('IFCAXIS2PLACEMENT3D', [pt3(x, y, z), null, null])]);
  double ground(Pt p) => terrain.isEmpty ? 0 : terrain.elevationAt(p);

  IfcExport build() {
    // ---- units
    metre = s.add('IFCSIUNIT', [_star, const _Enum('LENGTHUNIT'), null, const _Enum('METRE')]);
    final second = s.add('IFCSIUNIT', [_star, const _Enum('TIMEUNIT'), null, const _Enum('SECOND')]);
    final units = [
      metre,
      s.add('IFCSIUNIT', [_star, const _Enum('AREAUNIT'), null, const _Enum('SQUARE_METRE')]),
      s.add('IFCSIUNIT', [_star, const _Enum('VOLUMEUNIT'), null, const _Enum('CUBIC_METRE')]),
      s.add('IFCSIUNIT', [_star, const _Enum('PLANEANGLEUNIT'), null, const _Enum('RADIAN')]),
      s.add('IFCSIUNIT', [_star, const _Enum('PRESSUREUNIT'), null, const _Enum('PASCAL')]),
      s.add('IFCSIUNIT', [_star, const _Enum('MASSUNIT'), const _Enum('KILO'), const _Enum('GRAM')]),
      s.add('IFCSIUNIT', [_star, const _Enum('POWERUNIT'), null, const _Enum('WATT')]),
      second,
      s.add('IFCDERIVEDUNIT', [
        [s.add('IFCDERIVEDUNITELEMENT', [metre, const _Int(3)]), s.add('IFCDERIVEDUNITELEMENT', [second, const _Int(-1)])],
        const _Enum('VOLUMETRICFLOWRATEUNIT'),
        null,
      ]),
      s.add('IFCDERIVEDUNIT', [
        [s.add('IFCDERIVEDUNITELEMENT', [metre, const _Int(1)]), s.add('IFCDERIVEDUNITELEMENT', [second, const _Int(-1)])],
        const _Enum('LINEARVELOCITYUNIT'),
        null,
      ]),
    ];
    final unitAssignment = s.add('IFCUNITASSIGNMENT', [units]);
    // ---- contexts
    origin = pt3(0, 0, 0);
    zDir = s.add('IFCDIRECTION', [
      [0, 0, 1],
    ]);
    xDir = s.add('IFCDIRECTION', [
      [1, 0, 0],
    ]);
    wcs = s.add('IFCAXIS2PLACEMENT3D', [origin, null, null]);
    final north = s.add('IFCDIRECTION', [
      [0, 1],
    ]);
    final ctx = s.add('IFCGEOMETRICREPRESENTATIONCONTEXT', [null, 'Model', const _Int(3), 1e-5, wcs, north]);
    body = s.add('IFCGEOMETRICREPRESENTATIONSUBCONTEXT', ['Body', 'Model', _star, _star, _star, _star, ctx, null, const _Enum('MODEL_VIEW'), null]);
    axis = s.add('IFCGEOMETRICREPRESENTATIONSUBCONTEXT', ['Axis', 'Model', _star, _star, _star, _star, ctx, null, const _Enum('GRAPH_VIEW'), null]);
    identityOp = s.add('IFCCARTESIANTRANSFORMATIONOPERATOR3D', [null, null, origin, null, null]);
    final m = project.meta;
    final proj = s.add('IFCPROJECT', [guid('project'), null, m.name, [m.client, m.site].where((x) => x.isNotEmpty).join(' · '), null, m.name, null, [ctx], unitAssignment]);
    // ---- georeference
    final g = m.georef;
    List<_Int>? lat, lon;
    if (g != null) {
      final crs = CrsInfo.utm(g.zone, g.north, datum: datum);
      final pcrs = s.add('IFCPROJECTEDCRS', [crs.epsgCode != null ? 'EPSG:${crs.epsgCode}' : crs.name, crs.name, datum.ogcName.replaceAll(' ', ''), null, 'UTM', '${g.zone}${g.north ? 'N' : 'S'}', metre]);
      s.add('IFCMAPCONVERSION', [ctx, pcrs, g.originEasting, g.originNorthing, 0.0, 1.0, 0.0, 1.0]);
      final (la, lo) = g.toLatLon(0, 0);
      lat = _dms(la);
      lon = _dms(lo);
    } else {
      warnings.add('ifc_no_georef');
    }
    // ---- site with the terrain
    sitePlacement = s.add('IFCLOCALPLACEMENT', [null, wcs]);
    _Ref? siteShape;
    if (withTerrain && !terrain.isEmpty && !terrain.tin.isEmpty) {
      final tin = terrain.tin;
      final pl = s.add('IFCCARTESIANPOINTLIST3D', [
        [for (var i = 0; i < tin.pointCount; i++) [tin.xs[i], tin.ys[i], tin.zs[i]]],
      ]);
      final fs = s.add('IFCTRIANGULATEDFACESET', [pl, null, false, [for (final t in tin.triangles) [_Int(t.a + 1), _Int(t.b + 1), _Int(t.c + 1)]], null]);
      siteShape = s.add('IFCPRODUCTDEFINITIONSHAPE', [null, null, [s.add('IFCSHAPEREPRESENTATION', [body, 'Body', 'Tessellation', [fs]])]]);
    }
    final site = s.add('IFCSITE', [guid('site'), null, m.site.isNotEmpty ? m.site : m.name, null, null, sitePlacement, siteShape, null, const _Enum('ELEMENT'), lat, lon, lat != null ? 0.0 : null, null, null]);
    s.add('IFCRELAGGREGATES', [nextGuid('agg'), null, null, null, proj, [site]]);

    // ---- elements
    _pipes();
    _terminals();
    _valvesPumpsTanks();
    if (results?.bom.any((b) => const {'bom.fittings', 'bom.takeoffs', 'bom.risers'}.contains(b.category)) ?? false) warnings.add('ifc_fittings_not_exported');
    // shared catalogue property sets
    for (final e in shared.entries) {
      s.add('IFCRELDEFINESBYPROPERTIES', [nextGuid('relcat'), null, null, null, e.value.$2, e.value.$1]);
    }
    // ---- systems: the mainline and every zone
    final model = NetworkBuilder(project).build();
    final linkById = {for (final l in model.links) l.id: l};
    List<_Ref> refsOf(Iterable<String> entityIds) => [for (final id in entityIds.toSet()) ...?byEntity[id]];
    final mainIds = <String>{for (final lid in model.mainlineLinks) ?linkById[lid]?.entityId, for (final n in model.mainlineNodes) ...model.nodes[n]!.entityIds};
    final systems = <(String, List<_Ref>)>[
      ('MAINLINE', refsOf(mainIds)),
      for (final v in model.zoneNodes.keys)
        (
          (project.byId(v) is ControlValveEntity && (project.byId(v) as ControlValveEntity).zoneName.isNotEmpty) ? (project.byId(v) as ControlValveEntity).zoneName : v,
          refsOf({v, for (final lid in model.zoneLinks[v] ?? const <String>{}) ?linkById[lid]?.entityId, for (final n in model.zoneNodes[v]!) ...model.nodes[n]!.entityIds}),
        ),
    ];
    for (final (name, refs) in systems) {
      if (refs.isEmpty) continue;
      final sys = s.add('IFCDISTRIBUTIONSYSTEM', [nextGuid('sys'), null, name, null, 'IRRIGATION', null, const _Enum('USERDEFINED')]);
      s.add('IFCRELASSIGNSTOGROUP', [nextGuid('grp'), null, null, null, refs, null, sys]);
      s.add('IFCRELSERVICESBUILDINGS', [nextGuid('srv'), null, null, null, sys, [site]]);
    }
    if (elements.isNotEmpty) s.add('IFCRELCONTAINEDINSPATIALSTRUCTURE', [nextGuid('cont'), null, null, null, elements, site]);

    final t = time.toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp = '${t.year}-${two(t.month)}-${two(t.day)}T${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
    final out = StringBuffer()
      ..writeln('ISO-10303-21;')
      ..writeln('HEADER;')
      ..writeln("FILE_DESCRIPTION(('ViewDefinition [ReferenceView_V1.2]'),'2;1');")
      ..writeln('FILE_NAME(${_str(fileName)},${_str(stamp)},(${_str(m.designer)}),(${_str(m.client)}),${_str('OpenCADIrrigation${version.isNotEmpty ? ' $version' : ''}')},${_str('OpenCADIrrigation')},${_str('')});')
      ..writeln("FILE_SCHEMA(('IFC4'));")
      ..writeln('ENDSEC;')
      ..writeln('DATA;')
      ..write(s.b)
      ..writeln('ENDSEC;')
      ..writeln('END-ISO-10303-21;');
    final counts = <String, int>{};
    for (final k in const ['IFCPIPESEGMENT', 'IFCFLOWTERMINAL', 'IFCVALVE', 'IFCFILTER', 'IFCFLOWMETER', 'IFCPUMP', 'IFCTANK', 'IFCDISTRIBUTIONSYSTEM']) {
      if (s.counts[k] != null) counts[k] = s.counts[k]!;
    }
    return IfcExport(text: out.toString(), counts: counts, warnings: warnings);
  }

  /// Degrees as IfcCompoundPlaneAngleMeasure: degrees, minutes, seconds and
  /// millionths of a second, all with the sign of the angle.
  static List<_Int> _dms(double deg) {
    final sign = deg < 0 ? -1 : 1;
    var micro = (deg.abs() * 3600e6).round();
    final d = micro ~/ 3600000000;
    micro -= d * 3600000000;
    final mi = micro ~/ 60000000;
    micro -= mi * 60000000;
    final se = micro ~/ 1000000;
    micro -= se * 1000000;
    return [_Int(sign * d), _Int(sign * mi), _Int(sign * se), _Int(sign * micro)];
  }

  _Ref _element(String type, Entity? e, String seed, {String? name, String? description, String? objectType, required _Ref placement, _Ref? shape, String? predefined, bool hasPredefined = true}) {
    final r = s.add(type, [guid(seed), null, name, description, objectType, placement, shape, e?.id, if (hasPredefined) (predefined != null ? _Enum(predefined) : null)]);
    elements.add(r);
    if (e != null) byEntity.putIfAbsent(e.id, () => []).add(r);
    return r;
  }

  void _pset(String name, List<_Ref> objects, Map<String, Object?> props) {
    final ps = [
      for (final p in props.entries)
        if (p.value != null) s.add('IFCPROPERTYSINGLEVALUE', [p.key, null, p.value, null]),
    ];
    if (ps.isEmpty || objects.isEmpty) return;
    final set = s.add('IFCPROPERTYSET', [nextGuid('pset'), null, name, null, ps]);
    s.add('IFCRELDEFINESBYPROPERTIES', [nextGuid('rel'), null, null, null, objects, set]);
  }

  /// Pset_ManufacturerTypeInformation of a catalogue item, shared by every
  /// element of the item.
  void _catalogue(String key, String name, String supplier, String code, _Ref element) {
    final cur = shared[key];
    if (cur != null) {
      cur.$2.add(element);
      return;
    }
    final props = [
      s.add('IFCPROPERTYSINGLEVALUE', ['ModelLabel', null, _Typed('IFCLABEL', name), null]),
      if (supplier.isNotEmpty) s.add('IFCPROPERTYSINGLEVALUE', ['Manufacturer', null, _Typed('IFCLABEL', supplier), null]),
      if (code.isNotEmpty) s.add('IFCPROPERTYSINGLEVALUE', ['ArticleNumber', null, _Typed('IFCIDENTIFIER', code), null]),
    ];
    shared[key] = (s.add('IFCPROPERTYSET', [nextGuid('cat'), null, 'Pset_ManufacturerTypeInformation', null, props]), [element]);
  }

  static _Typed? _len(double? v) => v == null || !v.isFinite ? null : _Typed('IFCLENGTHMEASURE', v);
  static _Typed? _pos(double? v) => v == null || !v.isFinite || v <= 0 ? null : _Typed('IFCPOSITIVELENGTHMEASURE', v);
  static _Typed? _pa(double? head) => head == null || !head.isFinite ? null : _Typed('IFCPRESSUREMEASURE', head * paPerMetre);
  static _Typed? _q(double? v) => v == null || !v.isFinite ? null : _Typed('IFCVOLUMETRICFLOWRATEMEASURE', v);
  static _Typed? _label(String? v) => v == null || v.isEmpty ? null : _Typed('IFCLABEL', v);

  /// A vertical cylinder (or box) standing on its local origin, as a
  /// representation map shared by the elements of one kind.
  _Ref _map(String key, {double radius = 0, double x = 0, double y = 0, required double height}) => maps[key] ??= () {
    final pos2 = s.add('IFCAXIS2PLACEMENT2D', [s.add('IFCCARTESIANPOINT', [[0, 0]]), null]);
    final profile = radius > 0 ? s.add('IFCCIRCLEPROFILEDEF', [const _Enum('AREA'), null, pos2, radius]) : s.add('IFCRECTANGLEPROFILEDEF', [const _Enum('AREA'), null, pos2, x, y]);
    final solid = s.add('IFCEXTRUDEDAREASOLID', [profile, wcs, zDir, height]);
    final rep = s.add('IFCSHAPEREPRESENTATION', [body, 'Body', 'SweptSolid', [solid]]);
    return s.add('IFCREPRESENTATIONMAP', [wcs, rep]);
  }();

  _Ref _mapped(_Ref map, [double scale = 1]) {
    final op = scale == 1 ? identityOp : s.add('IFCCARTESIANTRANSFORMATIONOPERATOR3D', [null, null, origin, scale, null]);
    final item = s.add('IFCMAPPEDITEM', [map, op]);
    return s.add('IFCPRODUCTDEFINITIONSHAPE', [null, null, [s.add('IFCSHAPEREPRESENTATION', [body, 'Body', 'MappedRepresentation', [item]])]]);
  }

  Map<String, String> get _zoneNames => {for (final v in project.entities.whereType<ControlValveEntity>()) v.id: v.zoneName.isNotEmpty ? v.zoneName : v.id};

  void _pipes() {
    final res = results?.pipesByEntity ?? const <String, List<PipeSegmentResult>>{};
    final zones = _zoneNames;
    for (final e in project.entities) {
      if (!e.isLinearHydraulic) continue;
      final pts = (e as PolyEntity).points;
      if (pts.length < 2) continue;
      final (depth, PipeSpec? pipe, TapeSpec? tape) = switch (e) {
        PipeEntity p => (p.depth, cat.pipe(p.pipeSpecId), null),
        SpraylineEntity sl => (sl.depth, cat.pipe(sl.pipeSpecId), null),
        TapeEntity t => (t.depth, null, cat.tape(t.tapeSpecId)),
        _ => (0.0, null, null),
      };
      final di = (tape?.innerDiameterMm ?? pipe?.innerDiameterMm ?? 20) / 1000;
      final wall = pipe != null && pipe.wallThicknessMm > 0 ? pipe.wallThicknessMm / 1000 : 0.0;
      var dOut = pipe != null ? math.max(pipe.nominalMm / 1000, di + 2 * wall) : (tape != null ? math.max(tape.nominalMm / 1000, di + 0.0004) : di + 0.002);
      if (dOut <= di) dOut = di + 0.001;
      // the axis along the ground at the burial depth
      final path = <(double, double, double)>[];
      void addPoint(Pt p) {
        final z = ground(p) - depth;
        if (path.isNotEmpty && (path.last.$1 - p.x).abs() < 1e-6 && (path.last.$2 - p.y).abs() < 1e-6) return;
        path.add((p.x, p.y, z));
      }

      for (var i = 0; i < pts.length; i++) {
        if (i > 0 && densify > 0 && !terrain.isEmpty) {
          final n = (pts[i - 1].distanceTo(pts[i]) / densify).floor();
          for (var k = 1; k < n; k++) {
            addPoint(Pt.lerp(pts[i - 1], pts[i], k / n));
          }
        }
        addPoint(pts[i]);
      }
      if (path.length < 2) continue;
      final poly = s.add('IFCPOLYLINE', [[for (final (x, y, z) in path) pt3(x, y, z)]]);
      final solid = s.add('IFCSWEPTDISKSOLID', [poly, dOut / 2, di / 2, null, null]);
      final shape = s.add('IFCPRODUCTDEFINITIONSHAPE', [
        null,
        null,
        [s.add('IFCSHAPEREPRESENTATION', [axis, 'Axis', 'Curve3D', [poly]]), s.add('IFCSHAPEREPRESENTATION', [body, 'Body', 'AdvancedSweptSolid', [solid]])],
      ]);
      final flexible = tape != null || e is TapeEntity || pipe == null || pipe.material == PipeMaterial.peld || pipe.material == PipeMaterial.pehd;
      final specName = tape?.name ?? pipe?.name;
      final el = _element('IFCPIPESEGMENT', e, 'pipe:${e.id}', name: e.name.isNotEmpty ? e.name : specName, description: specName, objectType: e.type.name.toUpperCase(), placement: placementAt(0, 0, 0), shape: shape, predefined: flexible ? 'FLEXIBLESEGMENT' : 'RIGIDSEGMENT');
      _pset('Pset_PipeSegmentTypeCommon', [el], {
        'Reference': pipe?.code.isNotEmpty == true ? _Typed('IFCIDENTIFIER', pipe!.code) : null,
        'NominalDiameter': _pos((tape?.nominalMm ?? pipe?.nominalMm ?? 0) / 1000),
        'InnerDiameter': _pos(di),
        'OuterDiameter': _pos(dOut),
        'WorkingPressure': _pa(tape?.pressureRatingM ?? pipe?.pressureRatingM),
      });
      final rough = tape != null ? tape.roughnessMm / 1000 : pipe?.roughness;
      _pset('Pset_PipeSegmentOccurrence', [el], {'InteriorRoughnessCoefficient': _pos(rough), 'InvertElevation': _len(path.first.$3 - di / 2)});
      final segs = res[e.id] ?? const <PipeSegmentResult>[];
      double? qMax, vMax, pMin, pMax;
      String? zone;
      for (final r in segs) {
        qMax = math.max(qMax ?? 0, r.flow.abs());
        vMax = math.max(vMax ?? 0, r.velocity.abs());
        pMin = math.min(pMin ?? double.infinity, math.min(r.pressureStart, r.pressureEnd));
        pMax = math.max(pMax ?? -double.infinity, math.max(r.pressureStart, r.pressureEnd));
        zone ??= r.zoneId;
      }
      _pset('OCI_Hydraulics', [el], {
        'CatalogueItem': _label(specName),
        'Length': _len(e.length),
        'BurialDepth': _len(depth),
        'HazenWilliamsC': tape?.hazenC != null || pipe?.hazenC != null ? _Typed('IFCREAL', project.params.adjustedC(tape?.hazenC ?? pipe!.hazenC)) : null,
        'Zone': _label(zone != null ? zones[zone] : null),
        'DesignFlow': _q(qMax),
        'MaximumVelocity': vMax == null ? null : _Typed('IFCLINEARVELOCITYMEASURE', vMax),
        'MinimumPressure': _pa(pMin),
        'MaximumPressure': _pa(pMax),
        'MinimumPressureHead': _len(pMin),
        'MaximumPressureHead': _len(pMax),
        if (e is SpraylineEntity) 'Outlets': _Typed('IFCINTEGER', _Int(e.outletCount)),
        if (e is SpraylineEntity) 'OutletSpacing': _pos(e.spacing),
        if (tape != null) 'EmitterSpacing': _pos(tape.emitterSpacingM),
        if (tape != null) 'Emitters': _Typed('IFCINTEGER', _Int(tape.emitterSpacingM > 0 ? (e.length / tape.emitterSpacingM).floor() : 0)),
      });
      if (pipe != null) _catalogue('pipe:${pipe.id}', pipe.name, pipe.supplier, pipe.code, el);
      if (tape != null) _catalogue('tape:${tape.id}', tape.name, tape.supplier, tape.code, el);
    }
  }

  void _terminals() {
    final res = results?.outletsByEntity ?? const <String, List<OutletResult>>{};
    var count = 0;
    void terminal(Entity e, String seed, Pt p, double base, OutletSpec? spec, NozzleSpec? nz, double riser, double arcDeg, OutletResult? r, String name) {
      if (count >= maxTerminals) return;
      count++;
      final kind = (spec?.kind ?? OutletKind.sprinkler).name.toUpperCase();
      final height = math.max(riser, 0.15);
      final map = _map('terminal:$kind:${height.toStringAsFixed(2)}', radius: spec?.kind == OutletKind.gun ? 0.08 : 0.025, height: height);
      final el = _element('IFCFLOWTERMINAL', e, seed, name: name, description: [?spec?.name, ?nz?.name].join(' · '), objectType: 'IRRIGATION_$kind', placement: placementAt(p.x, p.y, base), shape: _mapped(map), hasPredefined: false);
      _pset('OCI_Hydraulics', [el], {
        'CatalogueItem': _label(spec?.name),
        'Nozzle': _label(nz?.name),
        'Arc': _Typed('IFCPLANEANGLEMEASURE', arcDeg * math.pi / 180),
        'RiserHeight': _len(riser),
        'NominalFlow': _q(nz != null && r != null ? r.nominalFlow : null),
        'DesignFlow': _q(r?.flow),
        'Pressure': _pa(r?.pressure),
        'PressureHead': _len(r?.pressure),
        'DischargeCoefficient': nz != null ? _Typed('IFCREAL', nz.curve.k) : null,
        'DischargeExponent': nz != null ? _Typed('IFCREAL', nz.curve.x) : null,
      });
      if (spec != null) _catalogue('outlet:${spec.id}', spec.name, spec.supplier, spec.code, el);
    }

    var limited = false;
    for (final e in project.entities) {
      switch (e) {
        case OutletEntity o:
          final spec = cat.outlet(o.outletSpecId);
          terminal(e, 'outlet:${e.id}', o.position, ground(o.position), spec, spec?.nozzle(o.nozzleId), o.riserHeight + (spec?.riserHeightM ?? 0), spec?.nozzle(o.nozzleId)?.effectiveArcDeg(o.arcDeg) ?? o.arcDeg, res[o.id]?.firstOrNull, o.name.isNotEmpty ? o.name : (spec?.name ?? ''));
        case SpraylineEntity sl when lateralOutlets:
          final spec = cat.outlet(sl.outletSpecId);
          final pos = sl.outletPositions();
          final rs = res[sl.id] ?? const <OutletResult>[];
          for (var i = 0; i < pos.length; i++) {
            if (count >= maxTerminals) {
              limited = true;
              break;
            }
            final r = rs.where((x) => i >= x.index && i < x.index + x.count).firstOrNull;
            terminal(e, 'outlet:${e.id}:$i', pos[i], ground(pos[i]) - sl.depth, spec, spec?.nozzle(sl.nozzleId), sl.riserHeight + (spec?.riserHeightM ?? 0) + sl.depth, sl.arcDeg, r, '${sl.name.isNotEmpty ? sl.name : sl.id}-${i + 1}');
          }
        default:
          break;
      }
    }
    if (limited) warnings.add('ifc_terminals_limited:$maxTerminals');
  }

  void _valvesPumpsTanks() {
    final zones = results?.zones ?? const <String, ZoneResult>{};
    final devices = <String, DeviceResult>{};
    for (final z in zones.values) {
      for (final d in z.devices) {
        devices[d.entityId] = d;
      }
    }
    for (final f in results?.systemFlows ?? const <SystemFlowResult>[]) {
      for (final d in f.devices) {
        final cur = devices[d.entityId];
        if (cur == null || d.flow.abs() > cur.flow.abs()) devices[d.entityId] = d;
      }
    }
    for (final e in project.entities) {
      switch (e) {
        case ControlValveEntity v:
          final spec = cat.valve(v.valveSpecId);
          final size = (spec?.sizeMm ?? 50) / 1000;
          final z = zones[v.id];
          final prv = v.fixedDownstreamHeadM != null;
          final el = _element('IFCVALVE', e, 'valve:${e.id}', name: v.zoneName.isNotEmpty ? v.zoneName : v.name, description: spec?.name, objectType: prv ? null : 'ZONECONTROL', placement: placementAt(v.position.x, v.position.y, ground(v.position) - v.depth), shape: _mapped(_map('valve', radius: 0.06, height: 0.2), math.max(size / 0.05, 0.3)), predefined: prv ? 'PRESSUREREDUCING' : 'USERDEFINED');
          _pset('Pset_ValveTypeCommon', [el], {'Size': _pos(size)});
          _pset('OCI_Hydraulics', [el], {
            'CatalogueItem': _label(spec?.name),
            'Zone': _label(v.zoneName),
            'DesignFlow': _q(z?.totalFlow),
            'HeadLoss': _len(z?.valveLoss),
            'RequiredUpstreamPressure': _pa(z?.requiredUpstreamHead),
            'RequiredUpstreamPressureHead': _len(z?.requiredUpstreamHead),
            'DownstreamPressureHead': _len(z?.downstreamHead ?? v.fixedDownstreamHeadM),
          });
          if (spec != null) _catalogue('valve:${spec.id}', spec.name, spec.supplier, spec.code, el);
        case MiscHydraulicEntity mh:
          final spec = cat.valve(mh.valveSpecId);
          final kind = spec?.kind ?? ValveKind.other;
          final size = (spec?.sizeMm ?? 50) / 1000;
          final (type, predefined, objectType) = switch (kind) {
            ValveKind.filter => ('IFCFILTER', 'WATERFILTER', null),
            ValveKind.meter => ('IFCFLOWMETER', 'WATERMETER', null),
            ValveKind.prv => ('IFCVALVE', 'PRESSUREREDUCING', null),
            ValveKind.isolation => ('IFCVALVE', 'ISOLATING', null),
            ValveKind.check => ('IFCVALVE', 'CHECK', null),
            ValveKind.backflow => ('IFCVALVE', 'DOUBLECHECK', null),
            ValveKind.airRelease => ('IFCVALVE', 'AIRRELEASE', null),
            ValveKind.control => ('IFCVALVE', 'USERDEFINED', 'ZONECONTROL'),
            ValveKind.master => ('IFCVALVE', 'USERDEFINED', 'MASTERVALVE'),
            ValveKind.psv => ('IFCVALVE', 'USERDEFINED', 'PRESSURESUSTAINING'),
            ValveKind.fcv => ('IFCVALVE', 'REGULATING', null),
            ValveKind.other => ('IFCVALVE', 'NOTDEFINED', null),
          };
          final d = devices[mh.id];
          final el = _element(type, e, 'device:${e.id}', name: mh.name.isNotEmpty ? mh.name : spec?.name, description: spec?.name, objectType: objectType, placement: placementAt(mh.position.x, mh.position.y, ground(mh.position)), shape: _mapped(_map(kind == ValveKind.filter ? 'filter' : 'valve', radius: kind == ValveKind.filter ? 0.1 : 0.06, height: kind == ValveKind.filter ? 0.5 : 0.2), math.max(size / 0.05, 0.3)), predefined: predefined);
          if (type == 'IFCVALVE') _pset('Pset_ValveTypeCommon', [el], {'Size': _pos(size)});
          if (type == 'IFCFILTER' && spec != null) _pset('Pset_FilterTypeCommon', [el], {'NominalFlowrate': _q(spec.maxFlow), 'NominalPressureDrop': _pa(spec.loss.loss(spec.maxFlow))});
          _pset('OCI_Hydraulics', [el], {
            'CatalogueItem': _label(spec?.name),
            'Setting': kind == ValveKind.prv || kind == ValveKind.psv ? _len(mh.settingM > 0 ? mh.settingM : spec?.defaultSettingM) : null,
            'FlowSetting': kind == ValveKind.fcv && mh.settingFlow > 0 ? _q(mh.settingFlow) : null,
            'DesignFlow': _q(d?.flow.abs()),
            'HeadLoss': _len(d?.headLoss),
            'UpstreamPressure': _pa(d?.upstreamPressure),
            'DownstreamPressure': _pa(d?.downstreamPressure),
          });
          if (spec != null) _catalogue('valve:${spec.id}', spec.name, spec.supplier, spec.code, el);
        case PumpEntity pu:
          final spec = cat.pump(pu.pumpSpecId);
          final d = devices[pu.id];
          final el = _element('IFCPUMP', e, 'pump:${e.id}', name: pu.name.isNotEmpty ? pu.name : spec?.name, description: spec?.name, placement: placementAt(pu.position.x, pu.position.y, ground(pu.position)), shape: _mapped(_map('pump', x: 0.6, y: 0.35, height: 0.4)), predefined: spec?.submersible == true ? 'SUBMERSIBLEPUMP' : 'NOTDEFINED');
          _pset('OCI_Hydraulics', [el], {
            'CatalogueItem': _label(spec?.name),
            'SpeedRatio': _Typed('IFCREAL', pu.speedRatio),
            'ShutoffHead': _len(spec?.curve.withSpeed(pu.speedRatio).shutoffHead),
            'RatedPower': spec != null && spec.powerKw > 0 ? _Typed('IFCPOWERMEASURE', spec.powerKw * 1000) : null,
            'Efficiency': spec != null ? _Typed('IFCPOSITIVERATIOMEASURE', spec.efficiency) : null,
            'DesignFlow': _q(d?.flow),
            'PumpHead': _len(d?.pumpHead),
          });
          if (spec != null) _catalogue('pump:${spec.id}', spec.name, spec.supplier, spec.code, el);
        case WaterSupplyEntity ws when ws.waterLevelOffsetM > 0:
          final el = _element('IFCTANK', e, 'tank:${e.id}', name: ws.name, placement: placementAt(ws.position.x, ws.position.y, ground(ws.position)), shape: _mapped(_map('tank', radius: 2, height: math.max(ws.waterLevelOffsetM, 0.5))), predefined: 'STORAGE');
          _pset('OCI_Hydraulics', [el], {'WaterLevelAboveGround': _len(ws.waterLevelOffsetM), 'DesignFlow': ws.designFlow > 0 ? _q(ws.designFlow) : null});
        default:
          break;
      }
    }
  }
}
