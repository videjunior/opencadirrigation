/// Sets of drawing sheets: an overview plus one sheet per zone or per
/// irrigated area (fitted to it, with the other zones greyed out or left
/// out), and windows of the drawing chosen by the user, each sheet with its
/// own scale and title. [PdfSheetBuilder] turns the [SheetSpec]s into pages.
library;

import 'dart:math' as math;

import '../design/network_builder.dart';
import '../design/results.dart';
import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import '../translate.dart';

/// How the drawing is split into sheets.
enum SheetSplit { single, zones, areas }

enum SheetKind { overview, zone, area, window }

/// A region of the drawing printed on a sheet of its own.
class SheetWindow {
  const SheetWindow({required this.bounds, this.scale, this.title = ''});

  /// World rectangle (m) the sheet shows.
  final Bounds bounds;

  /// Scale denominator (1:N); null fits the window to the sheet.
  final double? scale;
  final String title;
}

/// One drawing sheet of a set.
class SheetSpec {
  const SheetSpec({this.kind = SheetKind.overview, this.title = '', this.window, this.scale, this.muted = const {}, this.zones = const []});
  final SheetKind kind;

  /// Shown in the drawing and in the title block of a set of sheets.
  final String title;

  /// World region of the sheet; null = the whole drawing.
  final Bounds? window;

  /// Scale denominator; null = fit (the overview: the scale of the options).
  final double? scale;

  /// Entities drawn only for context (the other zones).
  final Set<String> muted;

  /// Valve ids of the zones the sheet is about (its bill of materials).
  final List<String> zones;

  SheetSpec withScale(double s) => SheetSpec(kind: kind, title: title, window: window, scale: s, muted: muted, zones: zones);
}

/// Entity ids of every zone, by valve id (the valve included): from the
/// design results when there are any, else from the network the design
/// would build.
Map<String, Set<String>> zoneMembers(Project p, [DesignResults? r]) {
  final out = <String, Set<String>>{};
  final valves = p.entities.whereType<ControlValveEntity>().toList();
  if (r != null && r.zones.isNotEmpty) {
    for (final v in valves) {
      final z = r.zones[v.id];
      if (z == null) continue;
      out[v.id] = {v.id, for (final s in z.pipes) s.entityId, for (final o in z.outlets) o.entityId, for (final d in z.devices) d.entityId};
    }
    if (out.isNotEmpty) return out;
  }
  if (valves.isEmpty) return out;
  final NetworkModel m;
  try {
    m = NetworkBuilder(p).build();
  } on Object {
    return out;
  }
  final links = {for (final l in m.links) l.id: l};
  for (final v in valves) {
    final ids = <String>{v.id};
    for (final lid in m.zoneLinks[v.id] ?? const <String>{}) {
      final e = links[lid]?.entityId;
      if (e != null && e.isNotEmpty) ids.add(e);
    }
    for (final nid in m.zoneNodes[v.id] ?? const <String>{}) {
      final n = m.nodes[nid];
      if (n == null) continue;
      ids.addAll(n.entityIds);
      for (final em in n.emitters) {
        ids.add(em.entityId);
      }
    }
    if (ids.length > 1) out[v.id] = ids;
  }
  return out;
}

/// Points that tell where a zone lies: its valve, outlets, lateral and pipe vertices.
List<Pt> _zonePoints(Project p, Set<String> ids) {
  final out = <Pt>[];
  for (final id in ids) {
    final e = p.byId(id);
    switch (e) {
      case PointEntity pe:
        out.add(pe.position);
      case SpraylineEntity s:
        out.addAll(s.outletPositions().take(200));
      case PolyEntity pl:
        out.addAll(pl.points);
      default:
        break;
    }
  }
  return out;
}

/// Zones (valve ids) of every irrigated area, by area id: a zone belongs to
/// the area holding most of its valve, outlets and pipe vertices.
Map<String, List<String>> areaZones(Project p, Map<String, Set<String>> zones) {
  final areas = p.entities.whereType<AreaEntity>().where((a) => a.points.length >= 3).toList();
  final out = {for (final a in areas) a.id: <String>[]};
  for (final z in zones.entries) {
    final pts = _zonePoints(p, z.value);
    AreaEntity? best;
    var bestN = 0;
    for (final a in areas) {
      final b = Bounds.ofPoints(a.points);
      var n = 0;
      for (final q in pts) {
        if (b.contains(q) && pointInPolygon(q, a.points)) n++;
      }
      if (n > bestN) {
        bestN = n;
        best = a;
      }
    }
    if (best != null) out[best.id]!.add(z.key);
  }
  return out;
}

/// Extent of the entities [ids] plus the throw of their sprinklers.
Bounds membersBounds(Project p, Iterable<String> ids) {
  var b = Bounds.empty;
  var reach = 0.0;
  for (final id in ids) {
    final e = p.byId(id);
    if (e == null) continue;
    b = b.union(e.bounds);
    final (spec, nozzle, head) = switch (e) {
      OutletEntity o => (o.outletSpecId, o.nozzleId, o.headM),
      SpraylineEntity s => (s.outletSpecId, s.nozzleId, s.headM),
      _ => ('', null, 0.0),
    };
    if (spec.isNotEmpty) reach = math.max(reach, p.catalog.outlet(spec)?.nozzle(nozzle)?.curve.radius(head) ?? 0);
  }
  return b.isEmpty ? b : b.inflate(reach);
}

/// Natural order of names ("Zone 2" before "Zone 10").
int naturalCompare(String a, String b) {
  final re = RegExp(r'(\d+)|(\D+)');
  final pa = re.allMatches(a).map((m) => m.group(0)!).toList(), pb = re.allMatches(b).map((m) => m.group(0)!).toList();
  for (var i = 0; i < math.min(pa.length, pb.length); i++) {
    final na = int.tryParse(pa[i]), nb = int.tryParse(pb[i]);
    final c = na != null && nb != null ? na.compareTo(nb) : pa[i].toLowerCase().compareTo(pb[i].toLowerCase());
    if (c != 0) return c;
  }
  return pa.length.compareTo(pb.length);
}

/// The sheets of a set: the overview first, then one per zone or per
/// irrigated area as [split] asks (zones in natural order of their names,
/// areas in drawing order), then the [windows]. Scales are left to the
/// sheet builder (null) except for windows that set one.
List<SheetSpec> sheetSpecs(Project p, SheetSplit split, {DesignResults? results, Translate? t, List<SheetWindow> windows = const []}) {
  String tr(String k, [Map<String, String>? a]) => t?.call(k, a) ?? k;
  final multi = split != SheetSplit.single || windows.isNotEmpty;
  final out = <SheetSpec>[SheetSpec(title: multi ? tr('sheet.overview') : '')];
  if (split != SheetSplit.single) {
    final zones = zoneMembers(p, results);
    final valves = {for (final v in p.entities.whereType<ControlValveEntity>()) v.id: v};
    String zoneTitle(String id) {
      final v = valves[id];
      return v == null ? id : (v.zoneName.isNotEmpty ? v.zoneName : (v.name.isNotEmpty ? v.name : id));
    }

    if (split == SheetSplit.zones) {
      final order = zones.keys.toList()..sort((a, b) => naturalCompare(zoneTitle(a), zoneTitle(b)));
      for (final id in order) {
        final mine = zones[id]!;
        final others = {
          for (final e in zones.entries)
            if (e.key != id) ...e.value,
        }..removeAll(mine);
        final w = membersBounds(p, mine);
        if (w.isEmpty) continue;
        out.add(SheetSpec(kind: SheetKind.zone, title: zoneTitle(id), window: w, muted: others, zones: [id]));
      }
    } else {
      final byArea = areaZones(p, zones);
      var n = 0;
      for (final a in p.entities.whereType<AreaEntity>()) {
        final mineZones = byArea[a.id];
        if (mineZones == null) continue;
        n++;
        final mine = {a.id, for (final z in mineZones) ...zones[z]!};
        final others = <String>{
          for (final e in zones.entries)
            if (!mineZones.contains(e.key)) ...e.value,
          for (final o in p.entities.whereType<AreaEntity>())
            if (o.id != a.id) o.id,
        }..removeAll(mine);
        final w = Bounds.ofPoints(a.points).union(membersBounds(p, mine));
        out.add(SheetSpec(kind: SheetKind.area, title: a.name.isNotEmpty ? a.name : '${tr('tool.area')} $n', window: w, muted: others, zones: mineZones));
      }
    }
  }
  for (final w in windows) {
    if (w.bounds.isEmpty) continue;
    out.add(SheetSpec(kind: SheetKind.window, title: w.title.isNotEmpty ? w.title : tr('sheet.view'), window: w.bounds, scale: w.scale));
  }
  return out;
}
