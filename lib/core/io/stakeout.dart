/// Points for setting out a design in the field: the list a total station
/// or a GNSS RTK receiver loads directly (comma-separated P,N,E,Z,D or
/// P,E,N,Z,D, the order of the surveying software), with the project's UTM
/// coordinates (the local ones when the project has no georeference) and
/// the terrain elevation of each point, for the emitters and outlets, the
/// valves and the other hydraulic items, the vertices of the pipes and the
/// ends of the laterals and drip lines.
library;

import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';

/// The order of the columns.
enum StakeoutOrder {
  /// Point, northing, easting, elevation, description.
  pnezd,

  /// Point, easting, northing, elevation, description.
  penzd,
}

/// What goes into the list.
enum StakeoutKind {
  /// Sprinklers, emitters and the outlets of the laterals.
  outlets,

  /// Zone valves.
  valves,

  /// Pumps, water supplies, devices (filters, air valves…), junctions and controllers.
  devices,

  /// The vertices of the mainline and zone pipes.
  pipeVertices,

  /// The start and the end of each lateral and drip line.
  lateralEnds,
}

/// One point of the list.
class StakeoutPoint {
  const StakeoutPoint(this.number, this.easting, this.northing, this.elevation, this.description, this.kind);
  final int number;
  final double easting, northing;

  /// Terrain elevation (m); null without terrain data.
  final double? elevation;
  final String description;
  final StakeoutKind kind;
}

/// The points of [project] for setting out: of [kinds], numbered from
/// [firstNumber], described with [label] (the kind, translated) and the
/// item's name. Coordinates are UTM (local plus the georeference origin)
/// or local metres without a georeference.
List<StakeoutPoint> stakeoutPoints(
  Project project, {
  Set<StakeoutKind> kinds = const {StakeoutKind.outlets, StakeoutKind.valves, StakeoutKind.devices, StakeoutKind.pipeVertices},
  int firstNumber = 1,
  String Function(StakeoutKind kind, Entity e)? label,
}) {
  final g = project.meta.georef;
  final terrain = project.buildTerrain();
  final hasTerrain = project.entities.any((e) => e is SpotHeightEntity || (e is ContourEntity && !e.derived) || e is BreaklineEntity);
  final out = <StakeoutPoint>[];
  final seen = <(int, int)>{};
  var n = firstNumber;
  void add(Pt p, StakeoutKind kind, Entity e) {
    if (!p.x.isFinite || !p.y.isFinite) return;
    // one point per place (pipe vertices shared by two pipes, a valve on a pipe end)
    if (!seen.add(((p.x * 1000).round(), (p.y * 1000).round()))) return;
    final z = hasTerrain ? terrain.elevationAt(p, fallback: double.nan) : double.nan;
    final name = e.name.isNotEmpty ? e.name : (e is ControlValveEntity ? e.zoneName : '');
    final what = label?.call(kind, e) ?? kind.name;
    out.add(StakeoutPoint(n++, p.x + (g?.originEasting ?? 0), p.y + (g?.originNorthing ?? 0), z.isFinite ? z : null, name.isEmpty ? what : '$what $name', kind));
  }

  for (final e in project.entities) {
    switch (e) {
      case OutletEntity o when kinds.contains(StakeoutKind.outlets):
        add(o.position, StakeoutKind.outlets, o);
      case SpraylineEntity s:
        if (kinds.contains(StakeoutKind.outlets)) {
          for (final p in s.outletPositions()) {
            add(p, StakeoutKind.outlets, s);
          }
        }
        if (kinds.contains(StakeoutKind.lateralEnds) && s.points.length >= 2) {
          add(s.points.first, StakeoutKind.lateralEnds, s);
          add(s.points.last, StakeoutKind.lateralEnds, s);
        }
      case TapeEntity t when kinds.contains(StakeoutKind.lateralEnds) && t.points.length >= 2:
        add(t.points.first, StakeoutKind.lateralEnds, t);
        add(t.points.last, StakeoutKind.lateralEnds, t);
      case ControlValveEntity v when kinds.contains(StakeoutKind.valves):
        add(v.position, StakeoutKind.valves, v);
      case PumpEntity() || WaterSupplyEntity() || MiscHydraulicEntity() || JunctionEntity() || ControllerEntity() when kinds.contains(StakeoutKind.devices):
        add((e as PointEntity).position, StakeoutKind.devices, e);
      case PipeEntity p when kinds.contains(StakeoutKind.pipeVertices):
        for (final v in p.points) {
          add(v, StakeoutKind.pipeVertices, p);
        }
      default:
        break;
    }
  }
  return out;
}

/// The list as text: one line per point in [order], [decimals] decimals in
/// the coordinates, the elevation empty when unknown; descriptions without
/// the separator (a comma becomes a space).
String stakeoutCsv(List<StakeoutPoint> points, {StakeoutOrder order = StakeoutOrder.pnezd, int decimals = 3, String separator = ','}) {
  final b = StringBuffer();
  String f(double v) => v.toStringAsFixed(decimals);
  for (final p in points) {
    final d = p.description.replaceAll(separator, ' ').replaceAll(RegExp(r'[\r\n"]'), ' ').trim();
    final ne = order == StakeoutOrder.pnezd ? '${f(p.northing)}$separator${f(p.easting)}' : '${f(p.easting)}$separator${f(p.northing)}';
    b.write('${p.number}$separator$ne$separator${p.elevation == null ? '' : f(p.elevation!)}$separator$d\r\n');
  }
  return b.toString();
}
