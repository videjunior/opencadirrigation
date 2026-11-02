/// Slope of the terrain by irrigated area (1.6.0 PRD): the area of each
/// slope class inside each irrigated area, for the report ("Slope by
/// irrigated area") and the slope sheet of the PDF. The classes are those
/// of the slope map of the screen ([slopeClasses]); the map is the same
/// grid the screen draws (the extent of the terrain data, at most 60 000
/// cells), made once for each terrain model.
library;

import 'dart:math' as math;

import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import '../model/slope_map.dart';
import '../model/terrain.dart';
import '../translate.dart';
import '../units.dart';
import 'report_tables.dart';

/// The slope maps made, by terrain model ([Project.buildTerrain] gives the
/// same model while the terrain data stays the same).
final _maps = Expando<SlopeMap>('slopeMap');

/// The slope map of the terrain of [p] over the extent of its data (empty
/// without terrain data).
SlopeMap terrainSlopeMap(Project p) {
  final terrain = p.buildTerrain();
  final known = _maps[terrain];
  if (known != null) return known;
  final m = slopeMapOf(terrain);
  _maps[terrain] = m;
  return m;
}

/// The slope map of [terrain] over the extent of its samples, as the
/// screen's overlay makes it.
SlopeMap slopeMapOf(Terrain terrain) {
  if (terrain.isEmpty) return SlopeMap.empty;
  var minX = double.infinity, minY = double.infinity, maxX = -double.infinity, maxY = -double.infinity;
  for (final s in terrain.samples) {
    minX = math.min(minX, s.p.x);
    minY = math.min(minY, s.p.y);
    maxX = math.max(maxX, s.p.x);
    maxY = math.max(maxY, s.p.y);
  }
  if (!(maxX > minX) || !(maxY > minY)) return SlopeMap.empty;
  return SlopeMap.compute(terrain, Bounds(minX, minY, maxX, maxY));
}

/// The area (m²) of each slope class of [m] (in the order of
/// [slopeClasses]) inside [polygon] (everywhere when null), the area left
/// without terrain data inside it, and the mean and largest slope (%).
class SlopeClassAreas {
  const SlopeClassAreas(this.byClass, this.noData, this.meanPct, this.maxPct);
  final List<double> byClass;
  final double noData;
  final double meanPct, maxPct;

  double get mapped => byClass.fold(0.0, (a, b) => a + b);
  double get total => mapped + noData;

  /// Share (0–1) of the mapped area in class [k].
  double share(int k) => mapped > 0 ? byClass[k] / mapped : 0;
}

/// [SlopeClassAreas] of the cells of [m] whose centres lie inside
/// [polygon] (all mapped cells when null); [polygonArea] (m²) gives the
/// area without data (the polygon's area less the mapped one).
SlopeClassAreas slopeClassAreas(SlopeMap m, {List<Pt>? polygon, double? polygonAreaM2}) {
  final byClass = List<double>.filled(slopeClasses.length, 0);
  if (m.isEmpty) return SlopeClassAreas(byClass, polygonAreaM2 ?? 0, 0, 0);
  final cellArea = m.cell * m.cell;
  var i0 = 0, i1 = m.nx - 1, j0 = 0, j1 = m.ny - 1;
  if (polygon != null) {
    final b = Bounds.ofPoints(polygon);
    i0 = math.max(0, ((b.minX - m.origin.x) / m.cell).floor());
    i1 = math.min(m.nx - 1, ((b.maxX - m.origin.x) / m.cell).ceil());
    j0 = math.max(0, ((b.minY - m.origin.y) / m.cell).floor());
    j1 = math.min(m.ny - 1, ((b.maxY - m.origin.y) / m.cell).ceil());
  }
  var sum = 0.0, max = 0.0;
  var n = 0;
  for (var j = j0; j <= j1; j++) {
    for (var i = i0; i <= i1; i++) {
      final v = m.slopePct[j * m.nx + i];
      if (v.isNaN) continue;
      if (polygon != null && !pointInPolygon(Pt(m.origin.x + (i + 0.5) * m.cell, m.origin.y + (j + 0.5) * m.cell), polygon)) continue;
      byClass[slopeClassOf(v)] += cellArea;
      sum += v;
      max = math.max(max, v);
      n++;
    }
  }
  final mapped = n * cellArea;
  final noData = polygonAreaM2 == null ? 0.0 : math.max(0.0, polygonAreaM2 - mapped);
  return SlopeClassAreas(byClass, noData, n == 0 ? 0 : sum / n, max);
}

/// "0–2 %", "2–5 %"… "> 45 %": the range of slope class [k].
String slopeClassLabel(int k) {
  final lo = k == 0 ? 0.0 : slopeClasses[k - 1].$1, hi = slopeClasses[k].$1;
  return hi.isInfinite ? '> ${fmt(lo, 0)} %' : '${fmt(lo, 0)}–${fmt(hi, 0)} %';
}

/// The class areas of the irrigated areas made last on each slope map,
/// with what they were made from (the areas and their outlines): the
/// reports ask for them on every redraw.
final _areaClasses = Expando<(List<Object>, List<(AreaEntity, SlopeClassAreas)>)>('slopeAreaClasses');

/// The irrigated areas of [p] with an outline and the slope class areas of
/// each, in drawing order.
List<(AreaEntity, SlopeClassAreas)> areaSlopeClasses(Project p, [SlopeMap? map]) {
  final m = map ?? terrainSlopeMap(p);
  if (m.isEmpty) return const [];
  final areas = [
    for (final a in p.entities.whereType<AreaEntity>())
      if (a.points.length >= 3) a,
  ];
  final key = <Object>[
    for (final a in areas) ...[a, a.points.length, for (final q in a.points) ...[q.x, q.y]],
  ];
  final known = _areaClasses[m];
  if (known != null && known.$1.length == key.length) {
    var same = true;
    for (var i = 0; i < key.length && same; i++) {
      final x = known.$1[i], y = key[i];
      same = x is AreaEntity ? identical(x, y) : x == y;
    }
    if (same) return known.$2;
  }
  final out = [for (final a in areas) (a, slopeClassAreas(m, polygon: a.points, polygonAreaM2: a.area))];
  _areaClasses[m] = (key, out);
  return out;
}

/// The report table "Slope by irrigated area": for each area its size, the
/// mean and largest slope, the area of each slope class and the area
/// without terrain data, then the total of all areas; null without terrain
/// data or irrigated areas.
ReportTable? slopeClassesTable(Project p, Translate t) {
  final rows = areaSlopeClasses(p);
  if (rows.isEmpty) return null;
  final u = p.params.units;
  Object area(double m2) => RNum(u.areaFromSi(m2), 2);
  final total = List<double>.filled(slopeClasses.length, 0);
  var noData = 0.0, size = 0.0, weighted = 0.0, mapped = 0.0, max = 0.0;
  final out = <List<Object>>[];
  for (final (a, s) in rows) {
    out.add([
      a.name.isEmpty ? t('tool.area') : a.name,
      area(a.area),
      RNum(s.meanPct, 1),
      RNum(s.maxPct, 1),
      for (final v in s.byClass) area(v),
      area(s.noData),
    ]);
    for (var k = 0; k < total.length; k++) {
      total[k] += s.byClass[k];
    }
    noData += s.noData;
    size += a.area;
    weighted += s.meanPct * s.mapped;
    mapped += s.mapped;
    max = math.max(max, s.maxPct);
  }
  if (rows.length > 1) out.add([t('rep.totalRow'), area(size), RNum(mapped > 0 ? weighted / mapped : 0, 1), RNum(max, 1), for (final v in total) area(v), area(noData)]);
  return ReportTable(
    key: 'slopeClasses',
    title: t('prd.rep.slope'),
    headers: [
      t('rep.area'),
      u.areaLabel,
      t('prd.rep.slopeMean'),
      t('prd.rep.slopeMax'),
      for (var k = 0; k < slopeClasses.length; k++) '${slopeClassLabel(k)} (${u.areaLabel})',
      '${t('prd.rep.noTerrain')} (${u.areaLabel})',
    ],
    rows: out,
    ids: [for (final (a, _) in rows) a.id],
  );
}
