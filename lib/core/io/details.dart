/// Standard construction details drawn by code: a trench section, a valve
/// in its box, a sprinkler on a swing joint or a riser, the start connector
/// of a drip line on the submain, an air valve, a thrust block at a bend, the
/// suction of a surface pump with its foot valve and a filter station.
///
/// Each detail is a parametric function of a [DetailContext] gathered from
/// the design (pipe diameters, burial depths, the trench settings of the
/// quote, the catalogue models in use, pressures from the results), so the
/// detail sheet tells the installer the sizes of this project. Geometry is
/// in metres, drawn at a "nice" detail scale chosen to fit a cell of the
/// sheet; text heights and dimension offsets are paper millimetres, as in
/// [PlotScene]. Typical values follow common practice: the minimum covers of
/// ASAE S376.2 for buried thermoplastic irrigation pipelines when the
/// project has no depth, the suction submergence S = 2.5·D + 0.1 m of the
/// hydraulics textbooks (e.g. Azevedo Netto, Manual de Hidráulica), and the
/// thrust of a bend T = 2·p·A·sin(θ/2) against an allowable soil bearing.
library;

import 'dart:math' as math;

import '../design/proposal.dart' show TrenchRow, trenchRows;
import '../design/results.dart';
import '../hydraulics/pump.dart' show maxSuctionLift;
import '../model/catalog.dart';
import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import '../translate.dart';
import '../units.dart';
import 'plot.dart';

enum DetailKind { trench, valveBox, sprinklerRiser, dripConnection, airValve, thrustBlock, pumpSuction, filterStation }

/// Layer name of the detail items (SVG groups, legends).
const detailLayer = 'DETAILS';

/// The values of the design the details print.
class DetailContext {
  DetailContext({
    this.units = Units.metric,
    this.mainPipeName = '',
    this.mainOdM = 0.075,
    this.mainDepthM = 0,
    this.mainRatingM = 0,
    this.trenchWidthM = 0,
    this.beddingM = 0.1,
    this.initialBackfillM = 0.15,
    this.trenches = const [],
    this.zonePipeName = '',
    this.zoneOdM = 0.032,
    this.zoneDepthM = 0,
    this.valveName = '',
    this.valveSizeMm = 0,
    this.sprinklerName = '',
    this.riserHeightM = 0,
    this.sprinklerInletMm = 20,
    this.tapeName = '',
    this.tapeOdMm = 16,
    this.emitterSpacingM = 0.3,
    this.airValveName = '',
    this.airValveSizeMm = 0,
    this.airValveCount = 0,
    this.maxWorkingHeadM = 0,
    this.soilBearingKpa = 50,
    this.pumpName = '',
    this.submersible = false,
    this.suctionLiftM = 0,
    this.siteElevationM = 0,
    this.filterName = '',
    this.filterSizeMm = 0,
    this.filterCount = 0,
  });

  final Units units;

  /// Largest mainline pipe: name, outside diameter (m), depth of its axis
  /// (m; 0 = not set) and pressure rating (m).
  final String mainPipeName;
  final double mainOdM;
  final double mainDepthM;
  final double mainRatingM;

  /// Trench settings of the quote ([ProposalSettings]): width (0 = outside
  /// diameter + 0.2 m, at least 0.3 m) and bedding under the pipe; fine
  /// backfill over the pipe crown.
  final double trenchWidthM;
  final double beddingM;
  final double initialBackfillM;

  /// Trenches of the buried pipes of the project (volume note).
  final List<TrenchRow> trenches;

  /// Zone pipe used the most: name, outside diameter, axis depth (0 = not set).
  final String zonePipeName;
  final double zoneOdM;
  final double zoneDepthM;

  /// Control valve model used the most.
  final String valveName;
  final double valveSizeMm;

  /// Sprinkler model used the most and the height of its riser (0 = a
  /// pop-up head on a swing joint) and inlet (mm).
  final String sprinklerName;
  final double riserHeightM;
  final double sprinklerInletMm;

  /// Drip line used the most: name, diameter (mm) and emitter spacing (m).
  final String tapeName;
  final double tapeOdMm;
  final double emitterSpacingM;

  /// Air valves of the drawing.
  final String airValveName;
  final double airValveSizeMm;
  final int airValveCount;

  /// Highest working pressure head on the mainline (m, from the results; 0 = unknown).
  final double maxWorkingHeadM;

  /// Allowable bearing of the soil behind thrust blocks (kPa).
  final double soilBearingKpa;

  /// Pump: model, whether it is submersible, static suction lift (m; 0 =
  /// unknown) and site elevation (m) for the practical lift limit.
  final String pumpName;
  final bool submersible;
  final double suctionLiftM;
  final double siteElevationM;

  /// Filters of the drawing.
  final String filterName;
  final double filterSizeMm;
  final int filterCount;

  /// Typical minimum cover (m) over a buried thermoplastic pipe of outside
  /// diameter [odM] (ASAE S376.2: 0.45 m up to 65 mm, 0.60 m up to 125 mm,
  /// 0.75 m above).
  static double minimumCover(double odM) => odM <= 0.065 ? 0.45 : (odM <= 0.125 ? 0.60 : 0.75);

  /// Depth of the mainline axis used by the details (typed, or the minimum cover plus half the pipe).
  double get mainAxisDepth => mainDepthM > 0 ? mainDepthM : minimumCover(mainOdM) + mainOdM / 2;
  double get zoneAxisDepth => zoneDepthM > 0 ? zoneDepthM : math.max(0.3, minimumCover(zoneOdM) - 0.15) + zoneOdM / 2;
  double get trenchWidth => trenchWidthM > 0 ? trenchWidthM : math.max(0.3, mainOdM + 0.2);

  /// Pressure head the thrust blocks are sized for: the test pressure, 1.5 ×
  /// the highest working pressure, or the pipe rating when not designed.
  double get thrustHeadM => maxWorkingHeadM > 0 ? 1.5 * maxWorkingHeadM : (mainRatingM > 0 ? mainRatingM : 60);

  /// Gathers the values of [p] (and its design results [r]).
  factory DetailContext.of(Project p, [DesignResults? r]) {
    final cat = p.catalog;
    PipeSpec? pipeOf(Entity e, String? specId) => cat.pipe(specId) ?? cat.pipe(r?.pipesByEntity[e.id]?.firstOrNull?.pipeSpecId);
    // mainline: the largest pipe and the depth it is laid at
    PipeSpec? main;
    var mainDepth = 0.0, anyDepth = 0.0;
    final zoneUse = <String, double>{};
    final zoneSpecs = <String, PipeSpec>{};
    var zoneDepth = 0.0;
    for (final e in p.entities.whereType<PipeEntity>()) {
      final sp = pipeOf(e, e.pipeSpecId);
      if (e.scope == HydraulicScope.mainline) {
        anyDepth = math.max(anyDepth, e.depth);
        if (sp != null && (main == null || sp.nominalMm > main.nominalMm)) {
          main = sp;
          mainDepth = e.depth;
        } else if (sp != null && sp.id == main?.id) {
          mainDepth = math.max(mainDepth, e.depth);
        }
      } else if (sp != null) {
        zoneUse[sp.id] = (zoneUse[sp.id] ?? 0) + e.length;
        zoneSpecs[sp.id] = sp;
        zoneDepth = math.max(zoneDepth, e.depth);
      }
    }
    final zone = zoneSpecs[_most(zoneUse)];
    // the models used the most
    final valves = <String, double>{}, outlets = <String, double>{}, tapes = <String, double>{};
    var riser = 0.0;
    for (final e in p.entities) {
      switch (e) {
        case ControlValveEntity v when v.valveSpecId != null:
          valves[v.valveSpecId!] = (valves[v.valveSpecId!] ?? 0) + 1;
        case OutletEntity o:
          outlets[o.outletSpecId] = (outlets[o.outletSpecId] ?? 0) + 1;
          riser = math.max(riser, o.riserHeight);
        case SpraylineEntity s:
          outlets[s.outletSpecId] = (outlets[s.outletSpecId] ?? 0) + s.outletCount;
          riser = math.max(riser, s.riserHeight);
          if (s.depth > 0) zoneDepth = math.max(zoneDepth, s.depth);
        case TapeEntity t:
          tapes[t.tapeSpecId] = (tapes[t.tapeSpecId] ?? 0) + t.length;
        default:
          break;
      }
    }
    final valve = cat.valve(_most(valves));
    final outlet = cat.outlet(_most(outlets));
    if (riser <= 0) riser = outlet?.riserHeightM ?? 0;
    final tape = cat.tape(_most(tapes));
    // devices on the mainline
    final airs = <MiscHydraulicEntity>[], filters = <MiscHydraulicEntity>[];
    for (final m in p.entities.whereType<MiscHydraulicEntity>()) {
      final k = cat.valve(m.valveSpecId)?.kind;
      if (k == ValveKind.airRelease) airs.add(m);
      if (k == ValveKind.filter) filters.add(m);
    }
    final air = airs.isEmpty ? null : cat.valve(airs.first.valveSpecId);
    final filter = filters.isEmpty ? null : cat.valve(filters.first.valveSpecId);
    // pump and the water level it lifts from
    final pumpEntity = p.entities.whereType<PumpEntity>().where((e) => cat.pump(e.pumpSpecId) != null).firstOrNull;
    final pump = cat.pump(pumpEntity?.pumpSpecId);
    var lift = 0.0, siteZ = 0.0;
    final supply = p.entities.whereType<WaterSupplyEntity>().firstOrNull;
    if (supply != null && supply.waterLevelOffsetM < 0) lift = -supply.waterLevelOffsetM;
    var maxHead = 0.0;
    if (r != null) {
      for (final f in r.systemFlows) {
        for (final s in f.pipes) {
          maxHead = math.max(maxHead, math.max(s.pressureStart, s.pressureEnd));
        }
        for (final d in f.devices) {
          if (pumpEntity != null && d.entityId == pumpEntity.id) {
            siteZ = d.elevation;
            // a negative inlet pressure is the suction lift with its losses
            if (lift <= 0 && d.upstreamPressure < 0) lift = -d.upstreamPressure;
          }
        }
        for (final s in f.supplies) {
          if (supply != null && s.supplyId == supply.id) siteZ = s.elevation;
        }
      }
    }
    return DetailContext(
      units: p.params.units,
      mainPipeName: main?.name ?? '',
      mainOdM: (main?.nominalMm ?? 75) / 1000,
      mainDepthM: mainDepth > 0 ? mainDepth : anyDepth,
      mainRatingM: main?.pressureRatingM ?? 0,
      trenchWidthM: p.proposal.trenchWidthM,
      beddingM: math.max(0, p.proposal.beddingM),
      trenches: trenchRows(p, p.proposal),
      zonePipeName: zone?.name ?? '',
      zoneOdM: (zone?.nominalMm ?? 32) / 1000,
      zoneDepthM: zoneDepth,
      valveName: valve?.name ?? '',
      valveSizeMm: valve?.sizeMm ?? 0,
      sprinklerName: outlet?.name ?? '',
      riserHeightM: riser,
      sprinklerInletMm: outlet?.inletMm ?? 20,
      tapeName: tape?.name ?? '',
      tapeOdMm: tape?.nominalMm ?? 16,
      emitterSpacingM: tape?.emitterSpacingM ?? 0.3,
      airValveName: air?.name ?? '',
      airValveSizeMm: air?.sizeMm ?? 0,
      airValveCount: airs.length,
      maxWorkingHeadM: maxHead,
      pumpName: pump?.name ?? '',
      submersible: pump?.submersible ?? false,
      suctionLiftM: lift,
      siteElevationM: siteZ,
      filterName: filter?.name ?? '',
      filterSizeMm: filter?.sizeMm ?? 0,
      filterCount: filters.length,
    );
  }

  static String? _most(Map<String, double> use) {
    String? best;
    for (final e in use.entries) {
      if (best == null || e.value > use[best]!) best = e.key;
    }
    return best;
  }
}

/// A detail drawn at its scale: items in metres around its own origin.
class DetailDrawing {
  DetailDrawing({required this.kind, required this.title, required this.items, required this.bounds, required this.scale, required this.notes});
  final DetailKind kind;
  final String title;
  final List<PlotItem> items;

  /// Extent of every item, text included (m).
  final Bounds bounds;

  /// Scale denominator (1:N).
  final double scale;

  /// Notes printed under the drawing (values of the design, rules).
  final List<String> notes;

  double get unitsPerMm => scale / 1000;
}

/// "Nice" scales of the details.
const detailScales = [1, 2, 2.5, 5, 10, 15, 20, 25, 30, 40, 50, 75, 100, 150, 200, 250, 500];

/// Width of the column of callouts beside a detail (paper mm).
const detailCalloutColumnMm = 31.0;

/// Draws detail [kind] to fit in [widthMm] × [heightMm] of paper (the
/// drawing with its dimensions and callouts; the cell title and notes go
/// around it).
DetailDrawing buildDetail(DetailKind kind, DetailContext ctx, {required double widthMm, required double heightMm, Translate? t}) {
  String tr(String k, [Map<String, String>? a]) => t?.call(k, a) ?? k;
  // pass 1: the geometry alone sets the scale (callouts and dimensions keep
  // their paper size whatever the scale)
  final probe = _Pen(0.01, ctx.units, tr);
  _draw(kind, probe, ctx);
  final g = probe.geometry.isEmpty ? const Bounds(0, 0, 1, 1) : probe.geometry;
  final columnMm = probe.callouts.isEmpty ? 0.0 : detailCalloutColumnMm + _dimMarginMm + 2;
  final availW = math.max(10.0, widthMm - columnMm - 2 * _dimMarginMm), availH = math.max(10.0, heightMm - 2 * _dimMarginMm);
  final need = math.max(g.width / availW, g.height / availH) * 1000;
  var scale = detailScales.last.toDouble();
  for (final s in detailScales) {
    if (s >= need) {
      scale = s.toDouble();
      break;
    }
  }
  if (need > detailScales.last) scale = (need / 100).ceil() * 100.0;
  final pen = _Pen(scale / 1000, ctx.units, tr);
  final notes = _draw(kind, pen, ctx);
  pen.finish();
  var b = pen.geometry;
  for (final it in pen.items) {
    b = b.union(_itemBounds(it, pen.upm));
  }
  return DetailDrawing(kind: kind, title: tr(_titleKey(kind, ctx)), items: pen.items, bounds: b, scale: scale, notes: notes);
}

/// Translation key of the title of [kind] (the sprinkler detail depends on
/// the riser of the project).
String detailTitleKey(DetailKind kind, DetailContext ctx) => _titleKey(kind, ctx);

String _titleKey(DetailKind kind, DetailContext ctx) => kind == DetailKind.sprinklerRiser && ctx.riserHeightM < 0.05 ? 'det.sprinklerSwing' : 'det.${kind.name}';

/// Room for dimensions around the geometry (paper mm).
const _dimMarginMm = 7.0;

Bounds _itemBounds(PlotItem it, double upm) => switch (it) {
  PlotPath p => Bounds.ofPoints(p.points),
  PlotCircle c => Bounds(c.center.x - c.radius, c.center.y - c.radius, c.center.x + c.radius, c.center.y + c.radius),
  PlotImage im => Bounds.ofPoints(im.corners),
  PlotText tx => _textBounds(tx, upm),
};

Bounds _textBounds(PlotText tx, double upm) {
  final w = tx.text.length * tx.heightMm * 0.62 * upm, h = tx.heightMm * upm;
  if (tx.rotationDeg.abs() > 45) return Bounds(tx.position.x - h, tx.position.y - w / 2, tx.position.x + h * 0.2, tx.position.y + w / 2);
  final (x0, x1) = switch (tx.anchor) {
    PlotAnchor.bottomRight => (-w, 0.0),
    PlotAnchor.bottomCenter || PlotAnchor.center => (-w / 2, w / 2),
    _ => (0.0, w),
  };
  final dy = tx.anchor == PlotAnchor.center || tx.anchor == PlotAnchor.centerLeft ? -h / 2 : 0.0;
  return Bounds(tx.position.x + x0, tx.position.y + dy, tx.position.x + x1, tx.position.y + dy + h);
}

List<String> _draw(DetailKind kind, _Pen d, DetailContext x) => switch (kind) {
  DetailKind.trench => _trench(d, x),
  DetailKind.valveBox => _valveBox(d, x),
  DetailKind.sprinklerRiser => x.riserHeightM < 0.05 ? _swingJoint(d, x) : _riser(d, x),
  DetailKind.dripConnection => _drip(d, x),
  DetailKind.airValve => _airValve(d, x),
  DetailKind.thrustBlock => _thrustBlock(d, x),
  DetailKind.pumpSuction => _suction(d, x),
  DetailKind.filterStation => _filters(d, x),
};

// ---------------------------------------------------------------- drawing kit

const _ink = 0xFF1A1A1A;
const _soil = 0xFF8D6E63;
const _sand = 0xFFFFF4D2;
const _sandDot = 0xFFB08D57;
const _fill = 0xFFF6EDE4;
const _pipe = 0xFF5C8FC4;
const _pipeIn = 0xFFD6E6F5;
const _concrete = 0xFFE4E4E4;
const _gravel = 0xFFE8E0DA;
const _water = 0xFFD4ECF7;
const _waterLine = 0xFF0277BD;
const _device = 0xFFFFD9A0;
const _dark = 0xFF455A64;

/// Text height of labels and callouts (paper mm).
const _textH = 1.7;

/// Collects the items of a detail at a paper scale.
class _Pen {
  _Pen(this.upm, this.units, this.t);

  /// World metres per paper millimetre.
  final double upm;
  final Units units;
  final String Function(String key, [Map<String, String>? args]) t;
  final items = <PlotItem>[];

  /// Extent of the geometry (not of text and dimensions).
  var geometry = Bounds.empty;
  final callouts = <(Pt, List<String>)>[];

  double mm(double v) => v * upm;

  void poly(List<Pt> pts, {bool closed = false, double w = 0.35, int color = _ink, int? fill, bool dashed = false, bool geo = true}) {
    if (pts.length < 2) return;
    items.add(PlotPath(layer: detailLayer, color: color, points: pts, closed: closed, widthMm: w, dashed: dashed, fillColor: fill));
    if (geo) geometry = geometry.union(Bounds.ofPoints(pts));
  }

  void rect(double x0, double y0, double x1, double y1, {double w = 0.35, int color = _ink, int? fill, bool dashed = false}) =>
      poly([Pt(x0, y0), Pt(x1, y0), Pt(x1, y1), Pt(x0, y1)], closed: true, w: w, color: color, fill: fill, dashed: dashed);

  void circle(Pt c, double r, {double w = 0.35, int color = _ink, int? fill, bool stroke = true}) {
    items.add(PlotCircle(layer: detailLayer, color: color, center: c, radius: r, widthMm: w, fillColor: fill, stroke: stroke));
    geometry = geometry.union(Bounds(c.x - r, c.y - r, c.x + r, c.y + r));
  }

  /// A pipe of outside diameter [od] along [pts] (a band of that width).
  void pipe(List<Pt> pts, double od, {int color = _pipe}) {
    poly(pts, w: math.max(0.5, od / upm), color: color);
    // the extent of the band
    for (final p in pts) {
      geometry = geometry.union(Bounds(p.x - od / 2, p.y - od / 2, p.x + od / 2, p.y + od / 2));
    }
  }

  /// Parallel hatch lines [spacingMm] apart inside [poly].
  void hatch(List<Pt> poly, {double angleDeg = 45, double spacingMm = 1.6, int color = _soil, double w = 0.13}) {
    for (final l in hatchLines(poly, degToRad(angleDeg), mm(spacingMm))) {
      items.add(PlotPath(layer: detailLayer, color: color, points: l, widthMm: w));
    }
  }

  /// Dots on a staggered grid inside [poly] (sand), or rings (gravel).
  void dots(List<Pt> poly, {double spacingMm = 1.4, double radiusMm = 0.12, int color = _sandDot, bool rings = false}) {
    final b = Bounds.ofPoints(poly);
    final s = mm(spacingMm);
    var row = 0;
    for (var y = b.minY + s / 2; y < b.maxY; y += s * 0.87, row++) {
      for (var x = b.minX + (row.isOdd ? s : s / 2); x < b.maxX; x += s) {
        final p = Pt(x, y);
        if (!pointInPolygon(p, poly)) continue;
        items.add(PlotCircle(layer: detailLayer, color: color, center: p, radius: mm(radiusMm), widthMm: 0.12, fillColor: rings ? null : color, stroke: rings));
      }
    }
  }

  /// Ground surface from [x0] to [x1] at [y], with the earth hatch under it
  /// (left open between [gapFrom] and [gapTo], where something cuts it).
  void ground(double x0, double x1, double y, {double? gapFrom, double? gapTo}) {
    final depth = mm(2.2);
    void strip(double a, double b) {
      if (b - a <= 1e-9) return;
      poly([Pt(a, y), Pt(b, y)], w: 0.5);
      hatch([Pt(a, y), Pt(b, y), Pt(b, y - depth), Pt(a, y - depth)], angleDeg: 45, spacingMm: 1.2, w: 0.15);
    }

    if (gapFrom != null && gapTo != null) {
      strip(x0, gapFrom);
      strip(gapTo, x1);
    } else {
      strip(x0, x1);
    }
  }

  void label(Pt p, String s, {double h = _textH, PlotAnchor anchor = PlotAnchor.bottomLeft, bool bold = false, int color = _ink, double rotation = 0}) {
    if (s.isEmpty) return;
    items.add(PlotText(layer: detailLayer, color: color, position: p, text: s, heightMm: h, rotationDeg: rotation, bold: bold, anchor: anchor));
  }

  /// Horizontal dimension of [x0]..[x1] measured at [y], drawn [offMm] above
  /// it (below when negative).
  void dimH(double x0, double x1, double y, String text, {double offMm = 5}) {
    if ((x1 - x0).abs() < 1e-9) return;
    final yy = y + mm(offMm), ext = mm(offMm > 0 ? 1.2 : -1.2);
    poly([Pt(x0, y), Pt(x0, yy + ext)], w: 0.13, geo: false);
    poly([Pt(x1, y), Pt(x1, yy + ext)], w: 0.13, geo: false);
    poly([Pt(x0 - mm(1), yy), Pt(x1 + mm(1), yy)], w: 0.18, geo: false);
    for (final x in [x0, x1]) {
      poly([Pt(x - mm(0.8), yy - mm(0.8)), Pt(x + mm(0.8), yy + mm(0.8))], w: 0.3, geo: false);
    }
    // a text longer than the span goes beyond its right end
    if (_textMm(text) + 2 > (x1 - x0).abs() / upm) {
      label(Pt(math.max(x0, x1) + mm(1.5), yy + mm(0.8)), text);
    } else {
      label(Pt((x0 + x1) / 2, yy + mm(0.8)), text, anchor: PlotAnchor.bottomCenter);
    }
  }

  /// Approximate length of [s] on paper (mm).
  double _textMm(String s, [double h = _textH]) => s.length * h * 0.62;

  /// Vertical dimension of [y0]..[y1] measured at [x], drawn [offMm] to the
  /// right of it (to the left when negative); the text reads upwards.
  void dimV(double x, double y0, double y1, String text, {double offMm = 5}) {
    if ((y1 - y0).abs() < 1e-9) return;
    final xx = x + mm(offMm), ext = mm(offMm > 0 ? 1.2 : -1.2);
    poly([Pt(x, y0), Pt(xx + ext, y0)], w: 0.13, geo: false);
    poly([Pt(x, y1), Pt(xx + ext, y1)], w: 0.13, geo: false);
    poly([Pt(xx, y0 - mm(1)), Pt(xx, y1 + mm(1))], w: 0.18, geo: false);
    for (final y in [y0, y1]) {
      poly([Pt(xx - mm(0.8), y - mm(0.8)), Pt(xx + mm(0.8), y + mm(0.8))], w: 0.3, geo: false);
    }
    if (_textMm(text) + 2 <= (y1 - y0).abs() / upm) {
      label(Pt(xx - mm(0.8), (y0 + y1) / 2), text, anchor: PlotAnchor.bottomCenter, rotation: 90);
    } else {
      // a text longer than the span: level, beside the line, away from the drawing
      final y = (y0 + y1) / 2 - mm(_textH / 2);
      label(Pt(xx + mm(offMm > 0 ? 1.2 : -1.2), y), text, anchor: offMm > 0 ? PlotAnchor.bottomLeft : PlotAnchor.bottomRight);
    }
  }

  /// Break symbol across a member [width] wide centred at [c] (horizontal
  /// member when [vertical] is false): the member is shown shorter than it is.
  void breakMark(Pt c, double width, {bool vertical = true}) {
    final g = mm(1.2);
    for (final s in [-1, 1]) {
      final o = vertical ? Pt(0, s * g) : Pt(s * g, 0);
      final pts = [
        for (final (u, v) in const [(-0.6, 0.0), (-0.17, 0.0), (-0.08, 1.0), (0.08, -1.0), (0.17, 0.0), (0.6, 0.0)]) vertical ? Pt(u * width, v * mm(1.4)) : Pt(v * mm(1.4), u * width),
      ];
      if (s == -1) {
        final a = [for (final p in pts) c + p + o], b = [for (final p in pts.reversed) c + p - o];
        poly([...a, ...b], closed: true, w: 0.05, color: 0xFFFFFFFF, fill: 0xFFFFFFFF, geo: false);
      }
      poly([for (final p in pts) c + p + o], w: 0.25, geo: false);
    }
  }

  /// Arrow from [from] to [to] with a filled head.
  void arrow(Pt from, Pt to, {int color = _ink, double w = 0.35}) {
    poly([from, to], w: w, color: color);
    final u = (to - from).normalized, n = u.perpendicular;
    poly([to, to - u * mm(2.2) + n * mm(0.9), to - u * mm(2.2) - n * mm(0.9)], closed: true, w: 0.2, color: color, fill: color);
  }

  /// A note pointing at [target], set in the column right of the drawing.
  void callout(Pt target, String text) {
    if (text.trim().isEmpty) return;
    callouts.add((target, wrapText(text, (detailCalloutColumnMm / (_textH * 0.62)).floor())));
  }

  /// Places the callouts in a column right of the geometry, top to bottom
  /// in the order of their targets, each with a leader to its target.
  void finish() {
    if (callouts.isEmpty || geometry.isEmpty) return;
    final colX = geometry.maxX + mm(_dimMarginMm + 2);
    final lineH = mm(_textH * 1.55);
    final order = [...callouts]..sort((a, b) => b.$1.y.compareTo(a.$1.y));
    final heights = [for (final c in order) c.$2.length * lineH + mm(1.6)];
    final total = heights.fold(0.0, (a, b) => a + b);
    // start at the top of the geometry, or higher when the column is taller
    var top = math.max(geometry.maxY, geometry.center.y + total / 2);
    for (var i = 0; i < order.length; i++) {
      final (target, lines) = order[i];
      // as close to the target as the notes above allow
      final want = target.y + lineH * 0.6;
      final remaining = heights.sublist(i).fold(0.0, (a, b) => a + b);
      var y = math.min(top, math.max(want, geometry.minY - mm(4) + remaining - mm(1.6)));
      y = math.min(y, top);
      for (var k = 0; k < lines.length; k++) {
        label(Pt(colX, y - (k + 1) * lineH + mm(0.5)), lines[k]);
      }
      final ly = y - lineH * 0.55;
      poly([target, Pt(colX - mm(3), ly), Pt(colX - mm(0.8), ly)], w: 0.15, geo: false);
      items.add(PlotCircle(layer: detailLayer, color: _ink, center: target, radius: mm(0.45), widthMm: 0.1, fillColor: _ink, stroke: false));
      top = y - heights[i];
    }
  }

  /// A length in the project units (dimension text).
  String len(double m) {
    final v = units.lengthFromSi(m);
    final d = switch (units.length) {
      LengthUnit.m || LengthUnit.ft => 2,
      LengthUnit.inch => 1,
      _ => 0,
    };
    return '${fmt(v, d)} ${units.lengthLabel}';
  }

  /// A pipe or device diameter in the project units.
  String dia(double m) => '${fmt(units.diameterFromSi(m), units.diameter == DiameterUnit.mm ? 0 : 2)} ${units.diameterLabel}';

  /// "name (Ø 50 mm)", or the diameter alone when the model has no name.
  String named(String name, double od) => name.isEmpty ? 'Ø ${dia(od)}' : '$name (Ø ${dia(od)})';
}

/// Splits [s] into lines of at most [maxChars] characters at spaces.
List<String> wrapText(String s, int maxChars) {
  final out = <String>[];
  var cur = '';
  for (final w in s.split(RegExp(r'\s+'))) {
    if (w.isEmpty) continue;
    final cand = cur.isEmpty ? w : '$cur $w';
    if (cand.length <= maxChars || cur.isEmpty) {
      cur = cand;
    } else {
      out.add(cur);
      cur = w;
    }
  }
  if (cur.isNotEmpty) out.add(cur);
  return out.isEmpty ? [''] : out;
}

/// Valve symbol (two triangles tip to tip) centred at [c], [s] long,
/// horizontal; with a square actuator on top when [actuator].
void _valve(_Pen d, Pt c, double s, {bool actuator = false, bool handle = false}) {
  final h = s * 0.32;
  d.poly([c + Pt(-s / 2, h), c, c + Pt(-s / 2, -h)], closed: true, w: 0.3, fill: _device);
  d.poly([c + Pt(s / 2, h), c, c + Pt(s / 2, -h)], closed: true, w: 0.3, fill: _device);
  if (actuator) {
    d.poly([c, c + Pt(0, s * 0.45)], w: 0.3);
    d.rect(c.x - s * 0.22, c.y + s * 0.45, c.x + s * 0.22, c.y + s * 0.8, w: 0.3, fill: _dark);
  }
  if (handle) {
    d.poly([c, c + Pt(0, s * 0.5)], w: 0.3);
    d.poly([c + Pt(-s * 0.28, s * 0.5), c + Pt(s * 0.28, s * 0.5)], w: 0.5);
  }
}

/// Pressure gauge on a stem at [p] (dial of radius [r] above it).
void _gauge(_Pen d, Pt p, double r) {
  d.poly([p, p + Pt(0, r * 1.2)], w: 0.3);
  final c = p + Pt(0, r * 2.2);
  d.circle(c, r, w: 0.3, fill: 0xFFFFFFFF);
  d.poly([c, c + Pt.polar(r * 0.8, degToRad(55))], w: 0.25);
}

// ---------------------------------------------------------------- details

/// Trench section: native soil, sand bedding, the pipe, selected fine
/// backfill over its crown and the compacted backfill in layers.
List<String> _trench(_Pen d, DetailContext x) {
  final od = x.mainOdM, axis = x.mainAxisDepth, w = x.trenchWidth, bed = x.beddingM;
  final depth = axis + od / 2 + bed, crown = -(axis - od / 2);
  final fine = math.min(0.0, crown + x.initialBackfillM);
  final m = math.max(0.15, w * 0.4);
  // native soil on both sides and under the bottom
  final soil = d.mm(3.0);
  for (final s in [-1, 1]) {
    final xa = s * w / 2, xb = s * (w / 2 + m);
    d.hatch([Pt(math.min(xa, xb), 0), Pt(math.max(xa, xb), 0), Pt(math.max(xa, xb), -depth - soil), Pt(math.min(xa, xb), -depth - soil)], spacingMm: 2.2, w: 0.15);
  }
  d.hatch([Pt(-w / 2, -depth), Pt(w / 2, -depth), Pt(w / 2, -depth - soil), Pt(-w / 2, -depth - soil)], spacingMm: 2.2, w: 0.15);
  // backfill (compacted in layers of at most 0.20 m), fine material, bedding
  d.rect(-w / 2, fine, w / 2, 0, w: 0.1, color: _fill, fill: _fill);
  for (var y = -0.2; y > fine + 0.02; y -= 0.2) {
    d.poly([Pt(-w / 2, y), Pt(w / 2, y)], w: 0.13, color: _soil, dashed: true);
  }
  d.rect(-w / 2, -depth + bed, w / 2, fine, w: 0.1, color: _sand, fill: _sand);
  d.dots([Pt(-w / 2, -depth + bed), Pt(w / 2, -depth + bed), Pt(w / 2, fine), Pt(-w / 2, fine)], spacingMm: 2.0, radiusMm: 0.1);
  if (bed > 0) {
    d.rect(-w / 2, -depth, w / 2, -depth + bed, w: 0.1, color: _sand, fill: 0xFFFFE9A8);
    d.dots([Pt(-w / 2, -depth), Pt(w / 2, -depth), Pt(w / 2, -depth + bed), Pt(-w / 2, -depth + bed)], spacingMm: 1.1);
  }
  // the pipe sits on the bedding
  d.circle(Pt(0, -axis), od / 2, w: 0.45, color: _pipe, fill: _pipeIn);
  d.circle(Pt(0, -axis), od / 2 * 0.86, w: 0.2, color: _pipe);
  // trench walls and the ground
  d.poly([Pt(-w / 2, 0), Pt(-w / 2, -depth), Pt(w / 2, -depth), Pt(w / 2, 0)], w: 0.5);
  d.ground(-w / 2 - m, w / 2 + m, 0, gapFrom: -w / 2, gapTo: w / 2);
  // dimensions
  d.dimH(-w / 2, w / 2, 0, d.len(w), offMm: 5);
  d.dimV(w / 2 + m, -depth, 0, d.len(depth), offMm: 4);
  d.dimV(-w / 2 - m, crown, 0, d.len(-crown), offMm: -4);
  if (bed > 0) d.dimV(-w / 2 - m, -depth, -depth + bed, d.len(bed), offMm: -4);
  // what is what
  d.callout(Pt(w / 2 + m * 0.6, -depth * 0.15), d.t('det.c.ground'));
  d.callout(Pt(w * 0.25, fine / 2), d.t('det.c.backfill', {'h': d.len(0.2)}));
  d.callout(Pt(-w * 0.3, (crown + fine) / 2 - od * 0.1), d.t('det.c.selected', {'h': d.len(x.initialBackfillM)}));
  d.callout(Pt(od / 2 * 0.7, -axis + od / 2 * 0.7), d.t('det.c.pipe', {'n': d.named(x.mainPipeName, od)}));
  if (bed > 0) d.callout(Pt(w * 0.3, -depth + bed / 2), d.t('det.c.bedding'));
  final notes = [
    d.t('det.n.trench', {'d': d.len(axis), 'w': d.len(w), 'h': d.len(depth)}),
  ];
  if (x.mainDepthM <= 0) notes.add(d.t('det.n.cover', {'c': d.len(DetailContext.minimumCover(od))}));
  final volume = x.trenches.fold(0.0, (a, r) => a + r.volume);
  if (volume > 0) notes.add(d.t('det.n.volume', {'v': '${fmt(x.units.volumeFromM3(volume), 1)} ${x.units.volumeLabel}', 'l': d.len(x.trenches.fold(0.0, (a, r) => a + r.length))}));
  return notes;
}

/// Control valve in its box: the riser from the mainline, the isolation
/// valve, the solenoid valve with its wires, the zone pipe leaving the box,
/// and the gravel bed that drains it.
List<String> _valveBox(_Pen d, DetailContext x) {
  final main = x.mainOdM, zone = x.zoneOdM;
  final mainAxis = math.max(x.mainAxisDepth, 0.35), zoneAxis = math.min(x.zoneAxisDepth, mainAxis);
  final bw = 0.5, bd = (zoneAxis + 0.12).clamp(0.3, 0.5).toDouble(), gravel = 0.1, wall = 0.02;
  final vy = -bd + 0.16; // valve level
  final vs = math.max(0.1, (x.valveSizeMm > 0 ? x.valveSizeMm : 25) / 1000 * 3.2);
  // gravel bed under the box
  final gpoly = [Pt(-bw / 2 - 0.05, -bd - gravel), Pt(bw / 2 + 0.05, -bd - gravel), Pt(bw / 2 + 0.05, -bd), Pt(-bw / 2 - 0.05, -bd)];
  d.poly(gpoly, closed: true, w: 0.15, color: _soil, fill: _gravel);
  d.dots(gpoly, spacingMm: 1.8, radiusMm: 0.45, color: _soil, rings: true);
  // box walls and lid (flush with the ground)
  d.rect(-bw / 2 - wall, -bd, -bw / 2, 0, w: 0.3, fill: _dark);
  d.rect(bw / 2, -bd, bw / 2 + wall, 0, w: 0.3, fill: _dark);
  d.rect(-bw / 2 - wall, -0.03, bw / 2 + wall, 0.0, w: 0.3, fill: _dark);
  d.ground(-bw / 2 - 0.22, bw / 2 + 0.22, 0, gapFrom: -bw / 2 - wall, gapTo: bw / 2 + wall);
  // mainline below, riser, isolation valve, solenoid valve, riser down, zone pipe out
  final xr = -bw / 2 + 0.07, xd = bw / 2 - 0.07;
  d.pipe([Pt(-bw / 2 - 0.22, -mainAxis), Pt(bw / 2 + 0.22, -mainAxis)], main);
  d.pipe([Pt(xr, -mainAxis), Pt(xr, vy), Pt(xd, vy), Pt(xd, -zoneAxis), Pt(bw / 2 + 0.22, -zoneAxis)], zone);
  _valve(d, Pt(xr + 0.11, vy), vs * 0.75, handle: true);
  _valve(d, Pt(0.04, vy), vs, actuator: true);
  for (final ux in [xr + 0.2, xd - 0.04]) {
    d.poly([Pt(ux, vy - zone * 0.9), Pt(ux, vy + zone * 0.9)], w: 0.5);
  }
  // solenoid wires to the connectors and down along the mainline
  final top = Pt(0.04, vy + vs * 0.8);
  d.poly([top, top + Pt(0.06, 0.03), Pt(xd - 0.03, vy + vs * 0.85), Pt(bw / 2 - 0.03, -bd + 0.05), Pt(bw / 2 + 0.2, -mainAxis + main * 0.9)], w: 0.25, color: 0xFFC62828);
  d.rect(xd - 0.06, vy + vs * 0.78, xd, vy + vs * 0.92, w: 0.2, fill: 0xFFFFEB3B);
  // dimensions and callouts
  d.dimV(bw / 2 + 0.22, -bd, 0, d.len(bd), offMm: 4);
  d.dimV(-bw / 2 - 0.22, -mainAxis, 0, d.len(mainAxis), offMm: -4);
  d.callout(Pt(bw / 4, -0.015), d.t('det.c.box'));
  d.callout(Pt(0.04 + vs * 0.3, vy + vs * 0.1), x.valveName.isEmpty ? d.t('det.c.valve', {'n': d.t('det.c.solenoid')}) : x.valveName);
  d.callout(Pt(xd - 0.03, vy + vs * 0.85), d.t('det.c.connectors'));
  d.callout(Pt(xr + 0.11, vy + vs * 0.3), d.t('det.c.ballValve'));
  d.callout(Pt(xd - 0.04, vy - zone * 0.9), d.t('det.c.union'));
  d.callout(Pt(bw / 2 + 0.15, -zoneAxis), d.t('det.c.zonePipe', {'n': d.named(x.zonePipeName, zone)}));
  d.callout(Pt(-bw / 2 + 0.04, -bd - gravel / 2), d.t('det.c.gravelBed', {'h': d.len(gravel)}));
  d.callout(Pt(-bw / 2 - 0.12, -mainAxis), d.t('det.c.mainline', {'n': d.named(x.mainPipeName, main)}));
  return [
    d.t('det.n.valveBox', {'w': d.len(bw), 'd': d.len(bd)}),
  ];
}

/// Pop-up sprinkler on a swing joint: the lateral, a tee, three elbows that
/// let the head be set to the finished grade.
List<String> _swingJoint(_Pen d, DetailContext x) {
  final lat = x.zoneOdM, axis = x.zoneAxisDepth;
  final inlet = math.max(0.02, x.sprinklerInletMm / 1000);
  final body = 0.16, bodyW = math.max(0.05, inlet * 2.2);
  d.ground(-0.35, 0.45, 0, gapFrom: 0.25 - bodyW / 2, gapTo: 0.25 + bodyW / 2);
  // the lateral (section along it) and the tee
  d.pipe([Pt(-0.35, -axis), Pt(0.45, -axis)], lat);
  d.rect(-0.03, -axis - lat * 0.65, 0.03, -axis + lat * 0.65, w: 0.3, fill: _pipeIn);
  // swing joint: up from the tee, across, up to the head
  final a = Pt(0, -axis + lat / 2), b = Pt(0, -axis + lat / 2 + 0.05), c = Pt(0.25, -axis + lat / 2 + 0.05), e = Pt(0.25, -body);
  d.pipe([a, b, c, e], inlet, color: 0xFF607D8B);
  for (final p in [b, c, Pt(0.25, -body - 0.01)]) {
    d.circle(p, inlet * 0.75, w: 0.3, fill: 0xFFFFFFFF);
  }
  // the sprinkler body, flush with the grade, and its pop-up stem
  d.rect(0.25 - bodyW / 2, -body, 0.25 + bodyW / 2, 0, w: 0.35, fill: 0xFF37474F);
  d.rect(0.25 - bodyW * 0.18, 0, 0.25 + bodyW * 0.18, 0.08, w: 0.25, dashed: true);
  for (final s in [-1, 1]) {
    d.poly([for (var i = 0; i <= 8; i++) Pt(0.25 + s * i * 0.03, 0.08 + 0.05 * math.sin(i / 8 * math.pi * 0.8))], w: 0.18, color: _waterLine, dashed: true, geo: false);
  }
  d.dimV(-0.35, -axis, 0, d.len(axis), offMm: -4);
  d.callout(Pt(0.25 + bodyW / 2, -body / 2), x.sprinklerName.isEmpty ? d.t('det.c.sprinkler') : x.sprinklerName);
  d.callout(Pt(0.25 + bodyW * 0.18, 0.0), d.t('det.c.grade'));
  d.callout(Pt(0.13, -axis + lat / 2 + 0.05), d.t('det.c.swing'));
  d.callout(Pt(0.02, -axis), d.t('det.c.tee'));
  d.callout(Pt(0.4, -axis - lat / 2), d.t('det.c.lateral', {'n': d.named(x.zonePipeName, lat)}));
  return [d.t('det.n.swing')];
}

/// Sprinkler on a riser above the crop, held by a stake.
List<String> _riser(_Pen d, DetailContext x) {
  final lat = x.zoneOdM, h = x.riserHeightM;
  final inlet = math.max(0.02, x.sprinklerInletMm / 1000);
  final axis = x.zoneDepthM > 0 ? x.zoneAxisDepth : lat / 2 + 0.005; // on the surface unless buried
  final buried = x.zoneDepthM > 0;
  d.ground(-0.4, 0.4, 0, gapFrom: buried ? -0.02 : null, gapTo: buried ? 0.02 : null);
  final yLat = buried ? -axis : lat / 2;
  d.pipe([Pt(-0.4, yLat), Pt(0.4, yLat)], lat);
  d.rect(-0.03, yLat - lat * 0.65, 0.03, yLat + lat * 0.65, w: 0.3, fill: _pipeIn);
  // riser up to the sprinkler
  d.pipe([Pt(0, yLat + lat / 2), Pt(0, h)], inlet, color: 0xFF607D8B);
  // impact sprinkler: body, arm and nozzle jet
  d.rect(-inlet, h, inlet, h + 0.06, w: 0.3, fill: 0xFFB0BEC5);
  d.poly([Pt(-inlet * 1.5, h + 0.08), Pt(inlet * 3, h + 0.1)], w: 0.4);
  d.poly([Pt(inlet, h + 0.04), Pt(0.12, h + 0.09)], w: 0.4);
  d.poly([for (var i = 0; i <= 10; i++) Pt(0.12 + i * 0.03, h + 0.09 + 0.06 * math.sin(i / 10 * math.pi * 0.7))], w: 0.18, color: _waterLine, dashed: true, geo: false);
  // stake with clamps
  final sx = -0.08, stakeDepth = math.max(0.3, h * 0.3);
  d.poly([Pt(sx, -stakeDepth), Pt(sx, h * 0.85)], w: 0.6, color: _dark);
  for (final y in [h * 0.35, h * 0.75]) {
    d.poly([Pt(sx, y), Pt(inlet, y)], w: 0.4);
  }
  d.dimV(0.4, 0, h, d.len(h), offMm: 4);
  d.dimV(-0.4, -stakeDepth, 0, d.len(stakeDepth), offMm: -4);
  d.callout(Pt(inlet, h + 0.05), x.sprinklerName.isEmpty ? d.t('det.c.sprinkler') : x.sprinklerName);
  d.callout(Pt(inlet / 2, h * 0.55), d.t('det.c.riser', {'d': d.dia(inlet)}));
  d.callout(Pt(sx, h * 0.15), d.t('det.c.stake'));
  d.callout(Pt(0.3, yLat), d.t('det.c.lateral', {'n': d.named(x.zonePipeName, lat)}));
  return [
    d.t('det.n.riser', {'h': d.len(h)}),
  ];
}

/// Start connector of a drip line on the submain (section across the
/// submain): grommet, connector, an optional line valve and the drip line on
/// the ground with its emitters.
List<String> _drip(_Pen d, DetailContext x) {
  final sub = math.max(0.032, x.zoneOdM), tape = math.max(0.012, x.tapeOdMm / 1000);
  final buried = x.zoneDepthM > 0;
  final cy = buried ? -x.zoneAxisDepth : sub / 2;
  final spacing = x.emitterSpacingM.clamp(0.05, 2.0).toDouble();
  // two emitters, the gap between them shortened (with a break) when long
  final e0 = 0.17, ds = math.min(spacing, 0.2), run = e0 + ds + 0.08;
  d.ground(-0.12, run + 0.05, 0, gapFrom: buried ? -sub / 2 : null, gapTo: buried ? sub / 2 : null);
  // submain section with the grommet in its wall
  d.circle(Pt(0, cy), sub / 2, w: 0.45, color: _pipe, fill: _pipeIn);
  d.circle(Pt(0, cy), sub / 2 * 0.85, w: 0.2, color: _pipe);
  final top = cy + sub / 2;
  d.rect(-0.006, top - 0.006, 0.006, top + 0.004, w: 0.2, fill: _ink);
  // connector stem, line valve and the drip line leaving on the surface
  final yl = math.max(top + 0.03, tape / 2);
  d.pipe([Pt(0, top), Pt(0, yl), Pt(run, yl)], tape * 0.8, color: 0xFF263238);
  d.rect(-tape * 0.7, top + 0.004, tape * 0.7, top + 0.02, w: 0.25, fill: _device);
  _valve(d, Pt(0.08, yl), math.max(0.03, tape * 2.4), handle: true);
  for (final e in [e0, e0 + ds]) {
    d.rect(e - 0.007, yl - tape * 0.45, e + 0.007, yl + tape * 0.45, w: 0.15, fill: _waterLine);
  }
  if (spacing > ds) d.breakMark(Pt(e0 + ds / 2, yl), tape * 2.2, vertical: false);
  d.dimH(e0, e0 + ds, yl + tape / 2, d.len(spacing), offMm: 4);
  if (buried) d.dimV(-0.12, cy, 0, d.len(-cy), offMm: -4);
  d.callout(Pt(sub * 0.3, cy - sub * 0.2), d.t('det.c.submain', {'n': d.named(x.zonePipeName, sub)}));
  d.callout(Pt(0.006, top), d.t('det.c.grommet'));
  d.callout(Pt(tape * 0.7, top + 0.012), d.t('det.c.startConnector'));
  d.callout(Pt(0.08, yl + tape), d.t('det.c.lineValve'));
  d.callout(
    Pt(run - 0.03, yl),
    d.t('det.c.dripLine', {
      'n': x.tapeName.isEmpty ? d.t('det.c.dripGeneric', {'d': d.dia(tape)}) : x.tapeName,
      's': d.len(spacing),
    }),
  );
  return [d.t('det.n.drip')];
}

/// Air valve over the mainline: tee, isolation valve, the valve and its
/// vented box.
List<String> _airValve(_Pen d, DetailContext x) {
  final main = x.mainOdM, axis = math.max(x.mainAxisDepth, 0.3);
  final size = math.max(0.025, (x.airValveSizeMm > 0 ? x.airValveSizeMm : 50) / 1000);
  final bw = math.max(0.35, main + 0.2), bd = axis - main / 2 + 0.05, wall = 0.02;
  // gravel around the tee, box walls, vented lid
  final gpoly = [Pt(-bw / 2, -bd), Pt(bw / 2, -bd), Pt(bw / 2, -bd + 0.08), Pt(-bw / 2, -bd + 0.08)];
  d.poly(gpoly, closed: true, w: 0.15, color: _soil, fill: _gravel);
  d.dots(gpoly, spacingMm: 1.8, radiusMm: 0.45, color: _soil, rings: true);
  d.rect(-bw / 2 - wall, -bd, -bw / 2, 0, w: 0.3, fill: _dark);
  d.rect(bw / 2, -bd, bw / 2 + wall, 0, w: 0.3, fill: _dark);
  d.rect(-bw / 2 - wall, -0.03, -0.03, 0, w: 0.3, fill: _dark);
  d.rect(0.03, -0.03, bw / 2 + wall, 0, w: 0.3, fill: _dark);
  d.ground(-bw / 2 - 0.3, bw / 2 + 0.3, 0, gapFrom: -bw / 2 - wall, gapTo: bw / 2 + wall);
  d.pipe([Pt(-bw / 2 - 0.3, -axis), Pt(bw / 2 + 0.3, -axis)], main);
  // tee up, isolation valve, air valve body with the vent
  final yv = -axis + main / 2 + 0.1;
  d.pipe([Pt(0, -axis + main / 2), Pt(0, yv + 0.08)], size, color: 0xFF607D8B);
  final vs = size * 2.2;
  d.poly([Pt(-vs / 2, yv - vs * 0.3), Pt(0, yv), Pt(-vs / 2, yv + vs * 0.3)], closed: true, w: 0.3, fill: _device);
  d.poly([Pt(vs / 2, yv - vs * 0.3), Pt(0, yv), Pt(vs / 2, yv + vs * 0.3)], closed: true, w: 0.3, fill: _device);
  final by = yv + 0.08, bh = math.max(0.12, size * 3);
  d.rect(-size * 1.4, by, size * 1.4, by + bh, w: 0.35, fill: 0xFF90A4AE);
  d.poly([for (var i = 0; i <= 12; i++) Pt(-size * 1.4 + size * 2.8 * i / 12, by + bh + math.sin(i / 12 * math.pi) * size * 0.9)], closed: true, w: 0.35, fill: 0xFF90A4AE);
  d.arrow(Pt(0, by + bh + size), Pt(0, by + bh + size + 0.07), color: _waterLine);
  d.dimV(-bw / 2 - 0.3, -axis, 0, d.len(axis), offMm: -4);
  d.callout(Pt(size * 1.4, by + bh * 0.6), x.airValveName.isEmpty ? '${d.t('det.c.airValve')} Ø ${d.dia(size)}' : x.airValveName);
  d.callout(Pt(vs / 2, yv), d.t('det.c.isolation'));
  d.callout(Pt(size / 2, -axis + main / 2 + 0.02), d.t('det.c.teeUp'));
  d.callout(Pt(bw / 2 - 0.02, -0.015), d.t('det.c.ventBox'));
  d.callout(Pt(bw / 4, -bd + 0.04), d.t('det.c.gravel'));
  d.callout(Pt(bw / 2 + 0.2, -axis), d.t('det.c.mainline', {'n': d.named(x.mainPipeName, main)}));
  return [
    x.airValveCount > 0 ? d.t('det.n.airValve', {'n': '${x.airValveCount}'}) : d.t('det.n.airValve0'),
  ];
}

/// Concrete thrust block behind a 90° bend (plan): the thrust of the bend
/// at the test pressure and the bearing area the soil needs.
List<String> _thrustBlock(_Pen d, DetailContext x) {
  final od = x.mainOdM, u = x.units;
  final head = x.thrustHeadM;
  final p = head * gravity * waterDensity / 1000; // kPa
  final area = math.pi * od * od / 4;
  final thrust = 2 * p * area * math.sin(math.pi / 4); // kN, 90° bend
  final tee = p * area;
  final bearing = thrust / math.max(1, x.soilBearingKpa); // m²
  final face = math.max(0.25, math.sqrt(bearing));
  final depthB = math.max(0.25, face * 0.6);
  // the bend: legs at ±45°, thrust straight down
  final legL = math.max(0.6, face * 1.4);
  final dl = Pt(-math.cos(math.pi / 4), math.sin(math.pi / 4)), dr = Pt(math.cos(math.pi / 4), math.sin(math.pi / 4));
  // block: hugging the outside of the bend, bearing face on the soil below
  final topW = math.max(od * 2.2, face * 0.6), yTop = od * 0.2, yBot = -(od * 0.5 + depthB);
  final block = [Pt(-topW / 2, yTop), Pt(topW / 2, yTop), Pt(face / 2, yBot), Pt(-face / 2, yBot)];
  d.poly(block, closed: true, w: 0.45, fill: _concrete);
  d.dots(block, spacingMm: 2.2, radiusMm: 0.25, color: 0xFF9E9E9E, rings: true);
  d.hatch(block, angleDeg: 30, spacingMm: 3.2, color: 0xFF9E9E9E, w: 0.1);
  final soil = [Pt(-face / 2 - 0.12, yBot), Pt(face / 2 + 0.12, yBot), Pt(face / 2 + 0.12, yBot - d.mm(3)), Pt(-face / 2 - 0.12, yBot - d.mm(3))];
  d.hatch(soil, spacingMm: 1.2, w: 0.15);
  d.poly([soil[0], soil[1]], w: 0.4);
  d.pipe([dl * legL, Pt.zero, dr * legL], od);
  d.circle(Pt.zero, od * 0.55, w: 0.3, fill: _pipeIn);
  d.arrow(Pt(0, -od * 0.2), Pt(0, yBot + depthB * 0.25), color: 0xFFC62828, w: 0.5);
  d.label(Pt(d.mm(1.2), (yBot + yTop) / 2), 'T', bold: true, color: 0xFFC62828);
  d.dimH(-face / 2, face / 2, yBot, d.len(face), offMm: -6);
  d.dimV(topW / 2 + 0.1, yBot, yTop, d.len(yTop - yBot), offMm: 4);
  d.callout(Pt(topW / 4, -od), d.t('det.c.block'));
  d.callout(Pt(face / 2, yBot - d.mm(1.5)), d.t('det.c.soil'));
  d.callout(dr * legL * 0.7, d.t('det.c.pipe', {'n': d.named(x.mainPipeName, od)}));
  final us = u.length == LengthUnit.ft;
  String force(double kn) => us ? '${fmt(kn * 224.809, 0)} lbf' : '${fmt(kn, 1)} kN';
  String sq(double m2) => us ? '${fmt(m2 * 10.7639, 2)} ft²' : '${fmt(m2, 3)} m²';
  final pressure = '${fmt(u.pressureFromHead(head), 1)} ${u.pressureLabel}';
  final sigma = us ? '${fmt(x.soilBearingKpa * 20.8854, 0)} lbf/ft²' : '${fmt(x.soilBearingKpa, 0)} kPa';
  return [
    d.t('det.n.thrust1', {'t': force(thrust), 'p': pressure}),
    d.t('det.n.thrust2', {'a': sq(bearing), 's': sigma}),
    d.t('det.n.thrust3', {'t': force(tee)}),
  ];
}

/// Suction of a surface pump: foot valve with strainer under the minimum
/// water level, the suction pipe rising all the way to the eccentric
/// reducer at the pump, the discharge with check and isolation valves.
List<String> _suction(_Pen d, DetailContext x) {
  final dn = math.max(0.05, x.mainOdM);
  final known = x.suctionLiftM > 0;
  final lift = known ? x.suctionLiftM : 3.0;
  // a lift taller than the drawing is shown shortened, with breaks
  final shown = math.min(lift, 1.4);
  final sub = 2.5 * dn + 0.1, clear = math.max(0.1, 1.5 * dn);
  final axisY = 0.45; // pump axis above the pad
  final wl = axisY - shown, foot = wl - sub, bottom = foot - clear;
  final px = 0.85, wellR = -0.1, wellL = -0.75;
  // water body and the well walls
  d.poly([Pt(wellL, wl), Pt(wellR, wl), Pt(wellR, bottom), Pt(wellL, bottom)], closed: true, w: 0.1, color: _water, fill: _water);
  d.poly([Pt(wellL, wl), Pt(wellR, wl)], w: 0.35, color: _waterLine);
  // the water-level mark: a small inverted triangle on the surface
  final mx = wellL + 0.1;
  d.poly([Pt(mx, wl), Pt(mx - d.mm(1.1), wl + d.mm(1.6)), Pt(mx + d.mm(1.1), wl + d.mm(1.6))], closed: true, w: 0.2, color: _waterLine, geo: false);
  d.poly([Pt(wellL, 0), Pt(wellL, bottom), Pt(wellR, bottom), Pt(wellR, 0)], w: 0.5);
  d.hatch([Pt(wellL - d.mm(3), 0), Pt(wellL, 0), Pt(wellL, bottom - d.mm(3)), Pt(wellL - d.mm(3), bottom - d.mm(3))], spacingMm: 1.4, w: 0.15);
  d.hatch([Pt(wellR, 0), Pt(wellR + d.mm(3), 0), Pt(wellR + d.mm(3), bottom - d.mm(3)), Pt(wellR, bottom - d.mm(3))], spacingMm: 1.4, w: 0.15);
  d.hatch([Pt(wellL, bottom), Pt(wellR, bottom), Pt(wellR, bottom - d.mm(3)), Pt(wellL, bottom - d.mm(3))], spacingMm: 1.4, w: 0.15);
  d.ground(wellR, px + 0.6, 0);
  // pump pad, pump and motor
  d.rect(px - 0.22, 0, px + 0.55, 0.12, w: 0.35, fill: _concrete);
  d.circle(Pt(px, axisY), 0.15, w: 0.4, fill: 0xFFEF9A9A);
  d.rect(px + 0.15, axisY - 0.11, px + 0.52, axisY + 0.11, w: 0.4, fill: 0xFFBDBDBD);
  d.rect(px - 0.07, 0.12, px + 0.45, axisY - 0.11, w: 0.25, fill: 0xFFBDBDBD);
  // suction: foot valve, rising pipe, long bend, slope up to the reducer
  final xs = (wellL + wellR) / 2;
  d.rect(xs - dn * 0.9, foot - dn * 0.9, xs + dn * 0.9, foot, w: 0.3, fill: _device);
  for (var i = 1; i < 5; i++) {
    final yy = foot - dn * 0.9 * i / 5;
    d.poly([Pt(xs - dn * 0.9, yy), Pt(xs + dn * 0.9, yy)], w: 0.12, geo: false);
  }
  final yIn = axisY - 0.03;
  d.pipe([Pt(xs, foot), Pt(xs, yIn - 0.04 - 0.15), Pt(xs + 0.15, yIn - 0.04), Pt(px - 0.33, yIn - 0.005)], dn);
  // eccentric reducer: straight on top
  d.poly([Pt(px - 0.33, yIn - 0.005 + dn / 2), Pt(px - 0.15, yIn - 0.005 + dn / 2), Pt(px - 0.15, yIn - 0.005 - dn * 0.15), Pt(px - 0.33, yIn - 0.005 - dn / 2)], closed: true, w: 0.3, fill: _pipeIn);
  // discharge: up from the volute, check valve, isolation valve
  final dq = dn * 0.8;
  d.pipe([Pt(px, axisY + 0.15), Pt(px, axisY + 0.65)], dq);
  for (final (y, kind) in [(axisY + 0.3, 0), (axisY + 0.5, 1)]) {
    d.poly([Pt(px - dq * 1.1, y - dq * 0.8), Pt(px + dq * 1.1, y - dq * 0.8), Pt(px, y + dq * 0.4)], closed: true, w: 0.3, fill: _device);
    if (kind == 1) d.poly([Pt(px - dq * 1.1, y + dq * 0.8), Pt(px + dq * 1.1, y + dq * 0.8), Pt(px, y - dq * 0.4)], closed: true, w: 0.3, fill: _device);
  }
  if (lift > shown) {
    final yb = (wl + 0) / 2;
    d.breakMark(Pt(xs, yb), dn * 3);
    d.breakMark(Pt(wellL - d.mm(1.5), yb), d.mm(5));
    d.breakMark(Pt(wellR + d.mm(1.5), yb), d.mm(5));
  }
  d.dimV(wellR + 0.05, wl, axisY, d.len(lift), offMm: 5);
  d.dimV(wellL, foot, wl, d.len(sub), offMm: -4);
  d.dimV(wellL, bottom, foot - dn * 0.9, d.len(clear - dn * 0.9 > 0 ? clear - dn * 0.9 : clear), offMm: -4);
  d.callout(Pt(px + 0.35, axisY + 0.11), x.pumpName.isEmpty ? d.t('det.c.pump') : x.pumpName);
  d.callout(Pt(px, axisY + 0.55), d.t('det.c.discharge'));
  d.callout(Pt(px - 0.24, yIn + dn / 2), d.t('det.c.reducer'));
  d.callout(Pt(px - 0.55, yIn - 0.02), d.t('det.c.rising', {'d': d.named('', dn)}));
  d.callout(Pt(wellR - 0.05, wl), d.t('det.c.waterLevel'));
  d.callout(Pt(xs + dn * 0.9, foot - dn * 0.45), d.t('det.c.footValve'));
  final notes = [
    known ? d.t('det.n.suction1', {'h': d.len(x.suctionLiftM), 'm': d.len(maxSuctionLift(x.siteElevationM))}) : d.t('det.n.suction0', {'h': d.len(3), 'm': d.len(maxSuctionLift(x.siteElevationM))}),
    d.t('det.n.suction2', {'s': d.len(sub)}),
  ];
  if (x.submersible) notes.add(d.t('det.n.submersible'));
  return notes;
}

/// Filter station on its pad: inlet and outlet headers, filters in
/// parallel, gauges before and after, flushing valves and an air valve.
List<String> _filters(_Pen d, DetailContext x) {
  // the filters of the drawing (two in parallel when it has none), at most four drawn
  final n = x.filterCount > 0 ? x.filterCount.clamp(1, 4).toInt() : 2;
  final dn = math.max(0.05, x.mainOdM);
  final fw = 0.2, gap = 0.12, x0 = 0.24;
  final xs = [for (var i = 0; i < n; i++) x0 + i * (fw + gap) + fw / 2];
  final xEnd = xs.last + fw / 2 + 0.22;
  final yIn = 0.3, yOut = 0.92, top = 1.02;
  // pad
  d.rect(-0.06, -0.1, xEnd + 0.1, 0, w: 0.35, fill: _concrete);
  d.hatch([Pt(-0.06, -0.1), Pt(xEnd + 0.1, -0.1), Pt(xEnd + 0.1, 0), Pt(-0.06, 0)], angleDeg: 30, spacingMm: 2.4, color: 0xFF9E9E9E, w: 0.1);
  d.ground(-0.25, xEnd + 0.3, 0, gapFrom: -0.06, gapTo: xEnd + 0.1);
  // headers and filters
  d.pipe([Pt(-0.25, yIn), Pt(xs.last, yIn)], dn);
  d.pipe([Pt(xs.first, yOut), Pt(xEnd + 0.3, yOut)], dn);
  for (final fx in xs) {
    d.pipe([Pt(fx, yIn), Pt(fx, yIn + 0.1)], dn * 0.8);
    d.pipe([Pt(fx, top - 0.1), Pt(fx, yOut)], dn * 0.8);
    d.rect(fx - fw / 2, yIn + 0.1, fx + fw / 2, top - 0.1, w: 0.4, fill: 0xFFE3F2FD);
    d.poly([for (var i = 0; i <= 10; i++) Pt(fx - fw / 2 + fw * i / 10, top - 0.1 + math.sin(i / 10 * math.pi) * 0.045)], w: 0.4, fill: 0xFFE3F2FD);
    for (var k = 1; k < 6; k++) {
      final yy = yIn + 0.1 + (top - yIn - 0.2) * k / 6;
      d.poly([Pt(fx - fw * 0.35, yy), Pt(fx + fw * 0.35, yy)], w: 0.12, color: _pipe, geo: false);
    }
    // flushing valve and drain at the bottom
    d.pipe([Pt(fx + fw / 2, yIn + 0.14), Pt(fx + fw / 2 + 0.06, yIn + 0.14), Pt(fx + fw / 2 + 0.06, 0.03)], dn * 0.5);
    _valve(d, Pt(fx + fw / 2 + 0.06, yIn + 0.04), 0.06);
  }
  // inlet and outlet valves, gauges, air valve
  _valve(d, Pt(0.03, yIn), math.max(0.08, dn * 1.5), handle: true);
  _valve(d, Pt(xEnd + 0.06, yOut), math.max(0.08, dn * 1.5), handle: true);
  _gauge(d, Pt(0.15, yIn + dn / 2), 0.035);
  _gauge(d, Pt(xEnd - 0.08, yOut + dn / 2), 0.035);
  final av = xs.last + fw / 2 + 0.09;
  d.pipe([Pt(av, yOut + dn / 2), Pt(av, yOut + 0.09)], 0.025, color: 0xFF607D8B);
  d.rect(av - 0.035, yOut + 0.09, av + 0.035, yOut + 0.18, w: 0.3, fill: 0xFF90A4AE);
  d.arrow(Pt(-0.22, yIn + 0.1), Pt(-0.08, yIn + 0.1), color: _waterLine);
  d.arrow(Pt(xEnd + 0.13, yOut + 0.1), Pt(xEnd + 0.27, yOut + 0.1), color: _waterLine);
  d.dimH(xs.first - fw / 2, xs.first + fw / 2, top, d.len(fw), offMm: 5);
  final filterName = x.filterName.isEmpty ? d.t('det.c.filterGeneric') : x.filterName;
  d.callout(Pt(xs.last + fw / 2, (yIn + top) / 2), x.filterCount == 1 ? filterName : d.t('det.c.filter', {'n': filterName, 'k': '${x.filterCount > 0 ? x.filterCount : n}'}));
  d.callout(Pt(0.15, yIn + dn / 2 + 0.1), d.t('det.c.gaugeIn'));
  d.callout(Pt(xEnd - 0.08, yOut + dn / 2 + 0.1), d.t('det.c.gaugeOut'));
  d.callout(Pt(av + 0.035, yOut + 0.14), d.t('det.c.airValve'));
  d.callout(Pt(xs.last + fw / 2 + 0.06, yIn + 0.04), d.t('det.c.drain'));
  d.callout(Pt(-0.18, yIn + 0.1), d.t('det.c.fromPump'));
  d.callout(Pt(xEnd + 0.22, yOut + 0.1), d.t('det.c.toMain'));
  d.callout(Pt(xEnd, -0.05), d.t('det.c.pad'));
  return [d.t('det.n.filter')];
}
