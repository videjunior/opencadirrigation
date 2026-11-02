/// Automatic design dialogs: the head layout of a lawn or bed (zoned by flow
/// and routed on demand), the subdivision of a field into blocks of
/// laterals, drip rings round orchard trees, the sports turf and golf
/// templates and the centre pivot fitted to a field (engine modules
/// `auto_layout.dart`, `zoning.dart`, `routing.dart`, `field_subdivision.dart`,
/// `tree_rings.dart`, `templates.dart` and `pivot_fit.dart`). Every dialog
/// shows its result live and generates it as one undo step.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/auto_layout.dart';
import '../../../core/design/block_generator.dart';
import '../../../core/design/densogram.dart' show SprayProfile, sprayProfileKey;
import '../../../core/design/field_subdivision.dart';
import '../../../core/design/pivot_fit.dart';
import '../../../core/design/proposal.dart' show defaultMainlineDepthM, defaultZonePipeDepthM;
import '../../../core/design/routing.dart';
import '../../../core/design/templates.dart';
import '../../../core/design/tree_rings.dart';
import '../../../core/design/zoning.dart';
import '../../../core/model/catalog.dart';
import '../../../core/model/entities.dart';
import '../../../core/model/geometry.dart';
import '../../../core/model/project.dart';
import '../../../core/units.dart';
import '../../state/controller.dart';
import '../../theme.dart';
import '../fields.dart';
import 'terrain_dialogs.dart' show dialogWidth;

/// Opens the automatic design dialog named [name] (`autoLayout`, `template`,
/// `fieldBlocks`, `treeRings`, `pivotFit`), for command aliases.
Future<void>? showAutoDesignDialog(BuildContext context, ProjectController c, String name) => switch (name) {
  'autoLayout' => showAutoLayoutDialog(context, c),
  'template' => showTemplateDialog(context, c),
  'fieldBlocks' => showFieldSubdivisionDialog(context, c),
  'treeRings' => showTreeRingsDialog(context, c),
  'pivotFit' => showPivotFitDialog(context, c),
  _ => null,
};

// ---------------------------------------------------------------- shared

Widget _row(List<Widget> children) => Row(
  children: [
    for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(width: 8), Expanded(child: children[i])],
  ],
);

Widget _note(String s, {Color? color}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 2),
  child: Text(s, style: TextStyle(fontSize: 11.5, color: color ?? Cad.fg70)),
);

Widget _switch(String label, bool value, ValueChanged<bool>? onChanged, {Key? key}) => SwitchListTile(
  key: key,
  dense: true,
  contentPadding: EdgeInsets.zero,
  title: Text(label, style: const TextStyle(fontSize: 12)),
  value: value,
  onChanged: onChanged,
);

/// A fraction typed as a percentage.
Widget _pct(String label, double fraction, ValueChanged<double> onChanged) => NumField(label: label, value: fraction * 100, decimals: 0, onChanged: (v) => onChanged((v < 0 ? 0 : v) / 100));

/// A number with the decimals its size calls for (1234 · 12.3 · 1.23).
String _n(double v) => fmt(v, v.abs() >= 100 ? 0 : (v.abs() >= 10 ? 1 : 2));

/// A number without trailing zeros (34.4, 12.8, 0), for lists typed back.
String _compact(double v) {
  final s = fmt(v, 2);
  return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
}

String _len(Units u, double m) => '${_n(u.lengthFromSi(m))} ${u.lengthLabel}';
String _flow(Units u, double q) => '${_n(u.flowFromSi(q))} ${u.flowLabel}';
String _head(Units u, double h) => '${fmt(u.pressureFromHead(h), 1)} ${u.pressureLabel}';
String _rate(Units u, double mmH) => '${fmt(u.depthFromMm(mmH), u.length == LengthUnit.ft ? 2 : 1)} ${u.depthRateLabel}';
String _hectares(Units u, double m2) => '${fmt(u.areaFromSi(m2), 2)} ${u.areaLabel}';
String _surface(Units u, double m2) => u.length == LengthUnit.ft ? '${fmt(m2 / (metersPerFoot * metersPerFoot), 0)} ft² (${_hectares(u, m2)})' : '${fmt(m2, 0)} m² (${_hectares(u, m2)})';

Color _grade(double v, double good, double fair) => v >= good ? Cad.ok : (v >= fair ? Cad.warning : Cad.unconnected);

/// Most trees or laterals a dialog generates: a spacing typed far too small
/// for the area would otherwise stall the page.
const _maxItems = 20000;

/// Thrown by a computation that would generate more than [_maxItems].
class _TooMany implements Exception {
  const _TooMany();
}

/// Thrown inside a stepwise computation whose inputs changed meanwhile.
class _Cancelled implements Exception {
  const _Cancelled();
}

/// A running stepwise computation of a [_Preview]: [pause] lets the screen
/// paint between two steps and throws [_Cancelled] once the inputs changed
/// (or the dialog closed); [say] shows how far it got.
class _Job {
  _Job(this._stale, this._say);
  final bool Function() _stale;
  final void Function(String text) _say;

  bool get cancelled => _stale();

  void say(String text) => _say(text);

  Future<void> pause() async {
    await Future<void>.delayed(Duration.zero);
    if (_stale()) throw const _Cancelled();
  }
}

/// The live result of a dialog. It is computed again only when the inputs
/// (summed up in a key) change, a moment after the last change (typing a
/// few values in a row computes once) and after the frame that shows it,
/// so the dialog keeps up while a large area is laid out; meanwhile the
/// last result stays on screen, marked as [stale]. A stepwise computation
/// ([watch]'s `steps`) gives the screen back between its steps, says how
/// far it got and stops as soon as the inputs change again.
class _Preview<T extends Object> {
  /// Wait after a change before computing.
  static const debounce = Duration(milliseconds: 150);

  String? _key, _wanted;
  T? value;
  Object? error;

  /// What the running computation is doing ('' when none says).
  String progress = '';
  Timer? _timer;
  int _generation = 0;

  bool get stale => _wanted != null;

  T? watch(String key, T? Function() compute, BuildContext ctx, StateSetter setState, {Future<T?> Function(_Job job)? steps}) {
    if (key == _key) {
      if (_wanted != null) {
        // back to the inputs on screen: drop what was pending
        _timer?.cancel();
        _generation++;
        _wanted = null;
        progress = '';
      }
      return value;
    }
    if (key == _wanted) return value;
    _wanted = key;
    _timer?.cancel();
    final gen = ++_generation;
    bool gone() => gen != _generation || !ctx.mounted;
    void refresh() {
      if (ctx.mounted) setState(() {});
    }

    // the frame that shows the change (and the progress bar) is drawn
    // before the timer fires
    _timer = Timer(_key == null ? Duration.zero : debounce, () async {
      if (gone()) return;
      if (steps == null) {
        _run(key, compute);
        refresh();
        return;
      }
      final job = _Job(gone, (text) {
        if (gone()) return;
        progress = text;
        refresh();
      });
      try {
        final v = await steps(job);
        if (gone()) return;
        value = v;
        error = null;
      } on _Cancelled {
        return;
      } catch (e) {
        if (gone()) return;
        value = null;
        error = e;
      }
      _key = key;
      if (_wanted == key) _wanted = null;
      progress = '';
      refresh();
    });
    return value;
  }

  /// The result for [key] now, computed at once when the inputs changed
  /// since (generate pressed right after typing a value); a computation
  /// under way is dropped.
  T? now(String key, T? Function() compute) {
    if (key != _key) {
      _timer?.cancel();
      _generation++;
      _run(key, compute);
    }
    return value;
  }

  void _run(String key, T? Function() compute) {
    try {
      value = compute();
      error = null;
    } catch (e) {
      value = null;
      error = e;
    }
    _key = key;
    if (_wanted == key) _wanted = null;
    progress = '';
  }

  /// Progress bar (and what the computation is doing) while stale, and the
  /// error of the last computation.
  List<Widget> status(ProjectController c) => [
    if (stale) const Padding(padding: EdgeInsets.symmetric(vertical: 3), child: LinearProgressIndicator(minHeight: 2)),
    if (stale && progress.isNotEmpty) _note(progress, color: Cad.fg54),
    if (error != null) _note(error is _TooMany ? c.t('auto.tooMany', {'n': '$_maxItems'}) : c.describeError(error!), color: Cad.warning),
  ];
}

/// Closed outline of [e] (an area, a closed polyline or spline, a hatch, a
/// revision cloud, a circle or the wetted outline of a pivot), or null.
List<Pt>? _outlineOf(Entity e) {
  final List<Pt>? pts = switch (e) {
    CircleEntity c => [for (var i = 0; i < 72; i++) c.center + Pt.polar(c.radius, 2 * math.pi * i / 72)],
    PivotEntity p => p.outline(),
    SplineEntity s => s.closed ? s.curve() : null,
    _ => e.isClosedShape ? e.linearPoints : null,
  };
  return pts == null || pts.length < 3 || polygonArea(pts).abs() < 1e-6 ? null : List.of(pts);
}

/// What the automatic tools take from the selection: the closed shapes (the
/// largest is the area or field, the others exclusions or obstacles), open
/// lines, mainline pipes, symbols and spot heights.
class _Picked {
  _Picked(ProjectController c) {
    final shapes = <(Entity, List<Pt>)>[];
    for (final e in c.project.entities) {
      if (!c.selection.contains(e.id)) continue;
      bounds = bounds.union(e.bounds);
      final o = _outlineOf(e);
      if (o != null) {
        shapes.add((e, o));
      } else if (e is PipeEntity) {
        if (e.scope == HydraulicScope.mainline && e.points.length >= 2) mainlines.add(e);
      } else if (e is SymbolEntity) {
        symbols.add(e);
      } else if (e is SpotHeightEntity) {
        spots.add(e);
      } else if (e is LineEntity || e is PolylineEntity || e is SplineEntity || e is ArcEntity || e is ContourEntity) {
        final pts = e is SplineEntity ? e.curve() : e.linearPoints;
        if (pts != null && pts.length >= 2) lines.add(List.of(pts));
      }
    }
    shapes.sort((a, b) => polygonArea(b.$2).abs().compareTo(polygonArea(a.$2).abs()));
    if (shapes.isNotEmpty) {
      areaEntity = shapes.first.$1;
      area = shapes.first.$2;
      others = [for (final s in shapes.skip(1)) s.$2];
    }
  }

  Bounds bounds = Bounds.empty;
  Entity? areaEntity;
  List<Pt>? area;
  List<List<Pt>> others = const [];
  final List<PipeEntity> mainlines = [];
  final List<SymbolEntity> symbols = [];
  final List<SpotHeightEntity> spots = [];
  final List<List<Pt>> lines = [];
}

/// Where the water comes from: a selected mainline pipe, a water supply or
/// pump of the drawing, or nothing (the last entry).
class _Source {
  const _Source(this.id, this.label, {this.point, this.mainline});
  final String id;
  final String label;
  final Pt? point;
  final List<Pt>? mainline;
}

List<_Source> _sources(ProjectController c, _Picked sel, {bool mainlines = false}) {
  final t = c.t;
  final out = <_Source>[];
  if (mainlines) {
    for (final m in sel.mainlines) {
      out.add(_Source('m:${m.id}', m.name.isNotEmpty ? '${t('auto.connMainline')}: ${m.name}' : t('auto.connMainline'), mainline: m.points));
    }
  }
  var supplies = 0, pumps = 0;
  for (final e in c.project.entities) {
    if (e is WaterSupplyEntity) {
      supplies++;
      out.add(_Source('s:${e.id}', e.name.isNotEmpty ? e.name : '${t('tool.supply')} $supplies', point: e.position));
    } else if (e is PumpEntity && e.scope == HydraulicScope.mainline) {
      pumps++;
      out.add(_Source('p:${e.id}', e.name.isNotEmpty ? e.name : '${t('tool.pump')} $pumps', point: e.position));
    }
  }
  out.add(_Source('', t('auto.connNone')));
  return out;
}

_Source _sourceOf(List<_Source> sources, String id) => sources.firstWhere((s) => s.id == id, orElse: () => sources.last);

/// [n] zone names "[prefix] k" that no valve, outlet or pivot of [p] uses
/// yet.
List<String> _zoneNames(Project p, String prefix, int n) {
  final used = <String>{
    for (final e in p.entities)
      if (e is ControlValveEntity) e.zoneName else if (e is OutletEntity) e.zoneName else if (e is PivotEntity) e.zoneName,
  };
  final out = <String>[];
  for (var i = 1; out.length < n; i++) {
    if (!used.contains('$prefix $i')) out.add('$prefix $i');
  }
  return out;
}

/// Sprinkler and micro-sprinkler families of the catalogue (the head layouts
/// need a wetted radius).
List<OutletSpec> _sprinklerFamilies(Catalog cat) => [
  for (final o in cat.outlets)
    if (o.enabled && o.nozzles.isNotEmpty && (o.kind == OutletKind.sprinkler || o.kind == OutletKind.microSprinkler)) o,
];

/// The family last used by the outlet tool when it is a sprinkler, else
/// the turf rotor, else the first one.
String _defaultFamily(ProjectController c, List<OutletSpec> families) {
  final last = c.project.catalog.outlet(c.toolSettings.outletSpecId);
  if (last != null && last.kind == OutletKind.sprinkler && families.contains(last)) return last.id;
  if (families.any((f) => f.id == 'rotor')) return 'rotor';
  return families.firstOrNull?.id ?? '';
}

/// The message codes of an engine module translated, each code once; the
/// items a code points at (zones, blocks, rows) are named by [name] when
/// there are a few, else counted by [count].
List<String> _messages(ProjectController c, Iterable<String> codes, {String Function(String rest)? name, String Function(int n)? count}) {
  final byKey = <String, List<String>>{};
  for (final m in codes) {
    final i = m.indexOf(':');
    final list = byKey[i > 0 ? m.substring(0, i) : m] ??= [];
    if (i > 0) list.add(m.substring(i + 1));
  }
  return [
    for (final MapEntry(:key, :value) in byKey.entries)
      value.isEmpty ? c.t.warning(key) : '${c.t.warning(key)} (${name != null && value.length <= 3 ? value.map(name).join(', ') : (count?.call(value.length) ?? '${value.length}')})',
  ];
}

Widget _messageBlock(List<String> lines) => lines.isEmpty
    ? const SizedBox.shrink()
    : Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(lines.map((l) => '• $l').join('\n'), style: TextStyle(fontSize: 11, color: Cad.warning)),
      );

/// The inputs beside the live summary on a wide screen (both scroll on their
/// own), the summary under the inputs otherwise. The dialogs are never
/// `scrollable`, not even on a phone: a scrollable AlertDialog measures the
/// intrinsic height of its content, which KV (a LayoutBuilder) cannot give;
/// the ScrollBody scrolls instead.
Widget _body(BuildContext ctx, List<Widget> inputs, List<Widget> summary) {
  Widget col(List<Widget> ws) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: ws);
  if (MediaQuery.sizeOf(ctx).width < 1000) {
    return SizedBox(
      width: dialogWidth(ctx, 580),
      child: ScrollBody(child: col([...inputs, ...summary])),
    );
  }
  return SizedBox(
    width: dialogWidth(ctx, 960),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: ScrollBody(child: col(inputs))),
        const SizedBox(width: 16),
        SizedBox(width: 350, child: ScrollBody(child: col(summary))),
      ],
    ),
  );
}

/// The dialog shown when the selection holds nothing the tool can work on.
Widget _nothingSelected(BuildContext ctx, ProjectController c, String title, String hint, String message) => AlertDialog(
  title: Text(title, style: const TextStyle(fontSize: 15)),
  content: SizedBox(
    width: dialogWidth(ctx, 480),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _note(hint),
        const SizedBox(height: 8),
        _note(message, color: Cad.warning),
      ],
    ),
  ),
  actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(c.t('close')))],
);

/// Takes the focus from the field being typed in (it commits its value on
/// focus loss, in a microtask) and then runs [generate].
void _afterCommit(VoidCallback generate) {
  FocusManager.instance.primaryFocus?.unfocus();
  Future<void>.delayed(Duration.zero, generate);
}

List<Widget> _actions(BuildContext ctx, ProjectController c, Key key, VoidCallback? generate) => [
  TextButton(onPressed: () => Navigator.pop(ctx), child: Text(c.t('cancel'))),
  FilledButton(key: key, onPressed: generate == null ? null : () => _afterCommit(generate), child: Text(c.t('auto.generate'))),
];

/// Heads, flow, nozzle, spacing, pressure and uniformity of a head layout.
List<Widget> _layoutSummary(ProjectController c, OutletSpec family, LandscapeLayout l) {
  final t = c.t, u = c.units;
  var corners = 0, edges = 0;
  for (final h in l.heads) {
    if (h.role == HeadRole.corner) corners++;
    if (h.role == HeadRole.edge) edges++;
  }
  final ref = family.nozzles.where((n) => n.id == l.referenceNozzleId).firstOrNull;
  final m = l.metrics;
  return [
    KV(t('dens.sources'), t('autolay.headsValue', {'n': '${l.heads.length}', 'c': '$corners', 'e': '$edges', 'i': '${l.heads.length - corners - edges}'})),
    KV(t('auto.flowTotal'), _flow(c.units, l.totalFlow)),
    if (ref != null) KV(t('autolay.reference'), '${ref.name} · R ${_len(u, ref.curve.radius(l.headM))}'),
    if (l.spacing > 0) KV(t('autolay.spacings'), '${_len(u, l.spacing)} · ${l.rowSpacing > 0 ? _len(u, l.rowSpacing) : '-'}'),
    KV(t('dlg.pressure'), _head(u, l.headM)),
    if (l.heads.isNotEmpty) KV(t('autolay.grossRate'), _rate(u, l.grossRateMmH)),
    if (m != null && m.heads > 0) ...[
      KV(t('dens.mean'), _rate(u, m.meanRateMmH)),
      KV('CU (Christiansen)', '${fmt(m.cu, 1)} %', color: _grade(m.cu, 84, 75)),
      KV('DU (${t('dens.lowQuarter')})', '${fmt(m.du, 1)} %', color: _grade(m.du, 75, 65)),
      KV(t('dens.sc'), m.sc.isFinite ? fmt(m.sc, 2) : '∞', color: m.sc <= 1.3 ? Cad.ok : (m.sc <= 1.5 ? Cad.warning : Cad.unconnected)),
      KV(t('dens.dry'), '${fmt(m.dryPct, 1)} %', color: m.dryPct <= 2 ? null : Cad.warning),
      KV(t('autolay.overspray'), '${fmt(m.oversprayPct, 1)} %', color: m.oversprayPct <= 10 ? null : Cad.warning),
    ],
  ];
}

String _headCount(ProjectController c, int n) => c.t('auto.nHeads', {'n': '$n'});

// ---------------------------------------------------------------- automatic layout

/// What the automatic layout would generate.
class _LayoutPlan {
  _LayoutPlan(this.family, this.layout, this.zoning, this.routing, this.groups, this.names);
  final OutletSpec family;
  final LandscapeLayout layout;
  final ZoningResult? zoning;
  final RoutingResult? routing;

  /// Heads of every zone (one zone of every head when routed without
  /// zoning) and the names the zones get.
  final List<List<int>> groups;
  final List<String> names;

  double flowOf(int zone) => groups[zone].fold(0.0, (s, i) => s + layout.heads[i].flow);
}

/// Lays out the heads of a sprinkler family over the selected closed shape
/// (the largest one; the other closed shapes selected are left out: houses,
/// beds), with the uniformity of the result; on demand zones the heads by
/// flow and routes the valves, zone pipes and mainline from a water supply,
/// a pump or onto a selected mainline pipe.
Future<void> showAutoLayoutDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final u = c.units;
  final sel = _Picked(c);
  final area = sel.area;
  final region = area == null ? null : LayoutRegion(area, exclusions: sel.others);
  final families = _sprinklerFamilies(c.project.catalog);
  var familyId = _defaultFamily(c, families);
  final o = LandscapeLayoutOptions();
  var autoDirection = true;
  var directionDeg = area == null ? 0.0 : normalizeDeg(radToDeg(longestEdgeDirection(normalizePolygon(area)).angle));
  var zoneOn = false, routeOn = false;
  // the largest zone flow follows the family until the user types one
  var zoneFlowTyped = false;
  ({double flow, double supply, double valve, bool typical}) zoneDefault() => defaultMaxZoneFlow(c.project, family: c.project.catalog.outlet(familyId), headM: o.headM > 0 ? o.headM : null);
  var maxZoneFlow = zoneDefault().flow;
  var itemsPerZone = 0;
  final sources = _sources(c, sel, mainlines: true);
  var sourceId = sources.first.id;
  var placement = ValvePlacement.nearZone;
  final preview = _Preview<_LayoutPlan>();

  String layoutKey() => [
    familyId,
    o.headM,
    o.referenceNozzleId,
    o.spacingRule.name,
    o.spacingPercent,
    o.spacingM,
    o.pattern.name,
    o.partCircles.name,
    autoDirection,
    directionDeg,
    o.cornerAngleDeg,
    o.minCornerArcDeg,
    o.minSpacingFraction,
    o.narrowStripFraction,
    o.edgeClearanceFraction,
    o.coverageFraction,
    o.rowStretchFraction,
    o.smallExclusionFactor,
    o.relaxIterations,
    o.minRadiusRatio,
    o.profile.name,
  ].join('|');
  String zoningKey() => '${layoutKey()}|$zoneOn|$maxZoneFlow|$itemsPerZone';
  String key() => '${zoningKey()}|$routeOn|$sourceId|${placement.name}';

  // the stages of the last computation: changing the zoning or the routing
  // does not lay the heads out again
  (String, LandscapeLayout)? laid;
  (String, ZoningResult?)? zoned;

  ZoneRouter routerFor(LandscapeLayout layout, List<List<int>> groups) {
    final src = _sourceOf(sources, sourceId);
    return ZoneRouter([
      for (final g in groups) [for (final i in g) layout.heads[i].position],
    ], RouteOptions(exclusions: sel.others, mainline: src.mainline, pointOfConnection: src.point, placement: placement, direction: layout.direction, boundary: area));
  }

  _LayoutPlan? compute() {
    final family = c.project.catalog.outlet(familyId);
    if (family == null || area == null) return null;
    final lk = layoutKey(), zk = zoningKey();
    if (laid?.$1 != lk) {
      laid = (lk, layoutLandscape(outline: area, exclusions: sel.others, family: family, options: o.copy()..direction = autoDirection ? null : Pt.polar(1, degToRad(directionDeg))));
    }
    final layout = laid!.$2;
    if (zoned?.$1 != zk) {
      zoned = (
        zk,
        zoneOn && layout.heads.isNotEmpty
            ? zoneByFlow(zoneItemsOf(layout, family, areas: c.project.entities.whereType<AreaEntity>()), ZoningOptions(maxZoneFlow: maxZoneFlow, maxItemsPerZone: itemsPerZone))
            : null,
      );
    }
    final zoning = zoned!.$2;
    final groups = zoning != null ? [for (final z in zoning.zones) z.items] : [if (routeOn && layout.heads.isNotEmpty) List<int>.generate(layout.heads.length, (i) => i)];
    final names = _zoneNames(c.project, t('name.zone'), groups.length);
    RoutingResult? routing;
    if (routeOn && groups.isNotEmpty) {
      final router = routerFor(layout, groups);
      while (router.step()) {}
      routing = router.result;
    }
    return _LayoutPlan(family, layout, zoning, routing, groups, names);
  }

  // the same in steps, for the live summary: the screen is given back
  // between the layout, the zoning and every zone routed, with the step on
  // screen, and a change of the inputs stops it
  Future<_LayoutPlan?> steps(_Job job) async {
    final family = c.project.catalog.outlet(familyId);
    if (family == null || area == null) return null;
    final lk = layoutKey(), zk = zoningKey();
    if (laid?.$1 != lk) {
      job.say(t('auto.step.layout'));
      await job.pause();
      laid = (lk, layoutLandscape(outline: area, exclusions: sel.others, family: family, options: o.copy()..direction = autoDirection ? null : Pt.polar(1, degToRad(directionDeg))));
    }
    final layout = laid!.$2;
    if (zoned?.$1 != zk) {
      if (zoneOn) job.say(t('auto.step.zoning'));
      await job.pause();
      zoned = (
        zk,
        zoneOn && layout.heads.isNotEmpty
            ? zoneByFlow(zoneItemsOf(layout, family, areas: c.project.entities.whereType<AreaEntity>()), ZoningOptions(maxZoneFlow: maxZoneFlow, maxItemsPerZone: itemsPerZone))
            : null,
      );
    }
    final zoning = zoned!.$2;
    final groups = zoning != null ? [for (final z in zoning.zones) z.items] : [if (routeOn && layout.heads.isNotEmpty) List<int>.generate(layout.heads.length, (i) => i)];
    final names = _zoneNames(c.project, t('name.zone'), groups.length);
    RoutingResult? routing;
    if (routeOn && groups.isNotEmpty) {
      final router = routerFor(layout, groups);
      do {
        job.say(t('auto.step.routing', {'n': '${math.min(router.routed + 1, groups.length)}', 'm': '${groups.length}'}));
        await job.pause();
      } while (router.step());
      routing = router.result;
    }
    return _LayoutPlan(family, layout, zoning, routing, groups, names);
  }

  void generate(BuildContext ctx) {
    if (!ctx.mounted) return;
    final plan = preview.now(key(), compute);
    if (plan == null || plan.layout.heads.isEmpty) return;
    final zoneOf = <int, int>{
      for (var z = 0; z < plan.groups.length; z++)
        for (final i in plan.groups[z]) i: z,
    };
    final made = c.mutate(() {
      final p = c.project;
      final out = <Entity>[
        ...plan.layout.toOutlets(p, zoneName: plan.groups.isEmpty ? null : (i) => plan.names[zoneOf[i] ?? 0]),
        // 1.6.0 AUT: buried zone pipes and mainline (their trenches go in the quote)
        ...?plan.routing?.toEntities(
          p,
          zoneNames: plan.names,
          valveSpecIds: [for (var z = 0; z < plan.groups.length; z++) pickZoneValve(p.catalog, plan.flowOf(z))?.id],
          depth: defaultZonePipeDepthM,
          mainlineDepth: defaultMainlineDepthM,
        ),
      ];
      p.entities.addAll(out);
      return out;
    }, label: 'hist.autoLayout');
    if (made == null) return;
    c.select(made.map((e) => e.id));
    if (ctx.mounted) Navigator.pop(ctx);
  }

  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        if (area == null || region == null) return _nothingSelected(ctx, c, t('autolay.title'), t('autolay.hint'), t('auto.noArea'));
        final plan = preview.watch(key(), compute, ctx, setState, steps: steps);
        final family = c.project.catalog.outlet(familyId);
        final inputs = <Widget>[
          _note(t('autolay.hint')),
          _note(t('auto.areaInfo', {'a': _surface(u, region.area), 'n': '${sel.others.length}'}), color: Cad.fg),
          SpecDropdown<OutletSpec>(
            key: const Key('al_family'),
            label: t('autolay.family'),
            value: familyId,
            items: families,
            labelOf: (x) => x.name,
            idOf: (x) => x.id,
            onChanged: (v) => setState(() {
              familyId = v ?? familyId;
              o.referenceNozzleId = null;
              if (!zoneFlowTyped) maxZoneFlow = zoneDefault().flow;
            }),
          ),
          NumField(label: t('autolay.pressure', {'u': u.pressureLabel}), value: u.pressureFromHead(o.headM), onChanged: (v) => setState(() => o.headM = v > 0 ? u.pressureToHead(v) : 0)),
          _row([
            SpecDropdown<SpacingRule>(
              label: t('autolay.rule'),
              value: o.spacingRule.name,
              items: SpacingRule.values,
              labelOf: (r) => t('autolay.rule.${r.name}'),
              idOf: (r) => r.name,
              onChanged: (v) => setState(() {
                o.spacingRule = SpacingRule.values.byName(v!);
                if (o.spacingRule == SpacingRule.fixed && !(o.spacingM > 0)) o.spacingM = preview.value?.layout.spacing ?? 10;
              }),
            ),
            switch (o.spacingRule) {
              SpacingRule.percentOfDiameter => NumField(
                label: t('dlg.spacingPct'),
                value: o.spacingPercent,
                decimals: 0,
                onChanged: (v) => setState(() => o.spacingPercent = v > 0 ? v : o.spacingPercent),
              ),
              SpacingRule.fixed => NumField(
                label: t('autolay.spacing', {'u': u.lengthLabel}),
                value: u.lengthFromSi(o.spacingM),
                onChanged: (v) => setState(() => o.spacingM = v > 0 ? u.lengthToSi(v) : o.spacingM),
              ),
              SpacingRule.headToHead => const SizedBox.shrink(),
            },
          ]),
          _row([
            SpecDropdown<PartCircleMode>(
              label: t('autolay.parts'),
              value: o.partCircles.name,
              items: PartCircleMode.values,
              labelOf: (m) => t('autolay.parts.${m.name}'),
              idOf: (m) => m.name,
              onChanged: (v) => setState(() => o.partCircles = PartCircleMode.values.byName(v!)),
            ),
            SegmentedButton<GridPattern>(
              segments: [
                ButtonSegment(value: GridPattern.square, label: Text(t('dlg.square'))),
                ButtonSegment(value: GridPattern.triangular, label: Text(t('dlg.triangular'))),
              ],
              selected: {o.pattern},
              onSelectionChanged: (v) => setState(() => o.pattern = v.first),
            ),
          ]),
          ExpansionTile(
            key: const Key('al_advanced'),
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            title: Text(t('autolay.advanced'), style: const TextStyle(fontSize: 12.5)),
            children: [
              if (family != null)
                SpecDropdown<NozzleSpec>(
                  key: ValueKey('al_ref_$familyId'),
                  label: t('autolay.refNozzle'),
                  value: o.referenceNozzleId,
                  items: [
                    for (final n in family.nozzles)
                      if (n.arcDeg >= 360 - 1e-6) n,
                  ],
                  labelOf: (n) => n.name,
                  idOf: (n) => n.id,
                  allowNull: true,
                  nullLabel: t('auto'),
                  onChanged: (v) => setState(() => o.referenceNozzleId = v),
                ),
              _switch(t('auto.longestEdge'), autoDirection, (v) => setState(() => autoDirection = v)),
              if (!autoDirection) NumField(label: t('auto.direction'), value: directionDeg, decimals: 1, onChanged: (v) => setState(() => directionDeg = normalizeDeg(v))),
              _row([
                NumField(label: t('autolay.cornerAngle'), value: o.cornerAngleDeg, decimals: 0, onChanged: (v) => setState(() => o.cornerAngleDeg = v.clamp(1, 179).toDouble())),
                NumField(label: t('autolay.minCornerArc'), value: o.minCornerArcDeg, decimals: 0, onChanged: (v) => setState(() => o.minCornerArcDeg = v.clamp(0, 180).toDouble())),
              ]),
              _pct(t('autolay.minSpacing'), o.minSpacingFraction, (v) => setState(() => o.minSpacingFraction = v)),
              _pct(t('autolay.narrowStrip'), o.narrowStripFraction, (v) => setState(() => o.narrowStripFraction = v)),
              _pct(t('autolay.edgeClearance'), o.edgeClearanceFraction, (v) => setState(() => o.edgeClearanceFraction = v)),
              _pct(t('autolay.coverage'), o.coverageFraction ?? 0, (v) => setState(() => o.coverageFraction = v > 0 ? v : null)),
              _pct(t('autolay.rowStretch'), o.rowStretchFraction, (v) => setState(() => o.rowStretchFraction = v)),
              NumField(label: t('autolay.smallExclusion'), value: o.smallExclusionFactor, decimals: 1, onChanged: (v) => setState(() => o.smallExclusionFactor = v < 0 ? 0 : v)),
              _pct(t('autolay.minRadius'), o.minRadiusRatio, (v) => setState(() => o.minRadiusRatio = v)),
              _row([
                NumField(label: t('autolay.relax'), value: o.relaxIterations.toDouble(), decimals: 0, onChanged: (v) => setState(() => o.relaxIterations = v.round().clamp(0, 20))),
                SpecDropdown<SprayProfile>(
                  label: t('dens.profile'),
                  value: o.profile.name,
                  items: SprayProfile.values,
                  labelOf: (p) => t(sprayProfileKey(p)),
                  idOf: (p) => p.name,
                  onChanged: (v) => setState(() => o.profile = SprayProfile.values.byName(v!)),
                ),
              ]),
            ],
          ),
          SectionTitle(t('autolay.zoningTitle')),
          _switch(t('autolay.zoning'), zoneOn, (v) => setState(() => zoneOn = v), key: const Key('al_zoning')),
          if (zoneOn) ...[
            _row([
              NumField(
                key: const Key('al_zone_flow'),
                label: t('autolay.maxZoneFlow', {'u': u.flowLabel}),
                value: u.flowFromSi(maxZoneFlow),
                onChanged: (v) => setState(() {
                  maxZoneFlow = v > 0 ? u.flowToSi(v) : 0;
                  zoneFlowTyped = true;
                }),
              ),
              NumField(label: t('autolay.itemsPerZone'), value: itemsPerZone.toDouble(), decimals: 0, onChanged: (v) => setState(() => itemsPerZone = v < 0 ? 0 : v.round())),
            ]),
            if (zoneDefault() case final zd) ...[
              _note(t('autolay.zoneFlowHint', {'s': zd.supply > 0 ? _flow(u, zd.supply) : '-', 'v': zd.valve > 0 ? _flow(u, zd.valve) : '-'}), color: Cad.fg54),
              // 1.6.0 AUT: without the supply's flow the zones start from a usual one
              if (zd.typical) _note(t('autolay.noSupplyFlow', {'q': _flow(u, zd.flow)}), color: Cad.warning),
            ],
          ],
          _switch(t('autolay.routing'), routeOn, (v) => setState(() => routeOn = v), key: const Key('al_routing')),
          if (routeOn)
            _row([
              SpecDropdown<_Source>(
                key: const Key('al_source'),
                label: t('auto.connection'),
                value: sourceId,
                items: sources,
                labelOf: (s) => s.label,
                idOf: (s) => s.id,
                onChanged: (v) => setState(() => sourceId = v ?? ''),
              ),
              SpecDropdown<ValvePlacement>(
                label: t('autolay.placement'),
                value: placement.name,
                items: ValvePlacement.values,
                labelOf: (p) => t('autolay.place.${p.name}'),
                idOf: (p) => p.name,
                onChanged: (v) => setState(() => placement = ValvePlacement.values.byName(v!)),
              ),
            ]),
        ];
        final zoning = plan?.zoning, routing = plan?.routing;
        final summary = <Widget>[
          SectionTitle(t('auto.summary')),
          ...preview.status(c),
          if (plan == null && preview.stale) _note(t('auto.computing'), color: Cad.fg54),
          if (plan != null) ...[
            ..._layoutSummary(c, plan.family, plan.layout),
            if (zoning != null) KV(t('dens.zones'), '${zoning.zones.length} · ${_flow(u, zoning.minFlow)} – ${_flow(u, zoning.maxFlow)}'),
            if (routing != null) ...[
              KV(t('autolay.placement'), '${routing.zones.length}'),
              KV(t('autolay.zonePipes'), _len(u, routing.zonePipeLength)),
              KV(t('scope.mainline'), _len(u, routing.mainlineLength)),
              KV(t('autolay.crossings'), '${routing.crossings}', color: routing.crossings > 0 ? Cad.warning : null),
            ],
            _messageBlock([
              ..._messages(c, plan.layout.messages, count: (n) => _headCount(c, n)),
              if (zoning != null) ..._messages(c, zoning.messages, count: (n) => _headCount(c, n)),
              if (routing != null) ..._messages(c, routing.messages, name: (z) => plan.names.elementAtOrNull(int.tryParse(z) ?? -1) ?? z, count: (n) => t('auto.nZones', {'n': '$n'})),
            ]),
          ],
        ];
        return AlertDialog(
          title: Text(t('autolay.title'), style: const TextStyle(fontSize: 15)),
          content: _body(ctx, inputs, summary),
          actions: _actions(ctx, c, const Key('al_generate'), plan == null || plan.layout.heads.isEmpty ? null : () => generate(ctx)),
        );
      },
    ),
  );
}

// ---------------------------------------------------------------- templates

enum _Template { pitch, track, green, tee, fairway }

/// Head layout templates of sports turf and golf: a football pitch, the
/// infield of a running track, a green ringed by part circles (an ellipse,
/// or the selected closed shape), a tee and a fairway (straight, or along a
/// selected line), placed at the centre of the selection or of the view.
/// Generates the heads and the irrigated area of the turf.
Future<void> showTemplateDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final u = c.units;
  final sel = _Picked(c);
  final families = _sprinklerFamilies(c.project.catalog);
  var familyId = _defaultFamily(c, families);
  var headM = 0.0;
  String? nozzleId;
  var kind = _Template.pitch;
  var rotation = 0.0;
  var pitchLength = 105.0, pitchWidth = 68.0, rows = 0;
  var straight = 84.39, bend = 36.5;
  var greenLength = 30.0, greenWidth = 22.0, setback = 1.5, arcMargin = 15.0;
  var useShape = sel.area != null;
  var teeLength = 30.0, teeWidth = 8.0;
  var fairwayLength = 300.0, fairwayWidth = 35.0, edgeParts = false;
  var useLine = sel.lines.isNotEmpty;
  final atSelection = !sel.bounds.isEmpty;
  final centre = atSelection ? sel.bounds.center : c.camera.center;
  final preview = _Preview<LandscapeLayout>();

  String key() => [
    familyId,
    headM,
    nozzleId,
    kind.name,
    rotation,
    pitchLength,
    pitchWidth,
    rows,
    straight,
    bend,
    greenLength,
    greenWidth,
    setback,
    arcMargin,
    useShape,
    teeLength,
    teeWidth,
    fairwayLength,
    fairwayWidth,
    edgeParts,
    useLine,
  ].join('|');

  LandscapeLayout? compute() {
    final family = c.project.catalog.outlet(familyId);
    if (family == null) return null;
    final rot = degToRad(rotation);
    final opts = LandscapeLayoutOptions(headM: headM, referenceNozzleId: nozzleId);
    return switch (kind) {
      _Template.pitch => sportsPitchLayout(
        family: family,
        length: pitchLength,
        width: pitchWidth,
        rows: rows,
        origin: centre - Pt(pitchLength / 2, pitchWidth / 2).rotate(rot),
        rotationDeg: rotation,
        headM: headM,
        nozzleId: nozzleId,
      ),
      _Template.track => runningTrackInfieldLayout(family: family, straight: straight, radius: bend, center: centre, rotationDeg: rotation, options: opts),
      _Template.green => golfGreenLayout(
        family: family,
        green: useShape && sel.area != null ? sel.area! : ellipseOutline(centre, greenLength, greenWidth, rotationDeg: rotation),
        setback: setback,
        headM: headM,
        nozzleId: nozzleId,
        arcMarginDeg: arcMargin,
      ),
      _Template.tee => teeLayout(family: family, length: teeLength, width: teeWidth, center: centre, rotationDeg: rotation, options: opts),
      _Template.fairway => fairwayLayout(
        family: family,
        centreline: useLine && sel.lines.isNotEmpty ? sel.lines.first : [centre - Pt.polar(fairwayLength / 2, rot), centre + Pt.polar(fairwayLength / 2, rot)],
        width: fairwayWidth,
        headM: headM,
        nozzleId: nozzleId,
        edgePartCircles: edgeParts,
      ),
    };
  }

  void generate(BuildContext ctx) {
    if (!ctx.mounted) return;
    final l = preview.now(key(), compute);
    if (l == null || l.heads.isEmpty) return;
    // a green drawn as an irrigated area already is one
    final hasArea = kind == _Template.green && useShape && sel.areaEntity is AreaEntity;
    final made = c.mutate(() {
      final p = c.project;
      final out = <Entity>[...l.toOutlets(p), if (!hasArea && l.region.outline.length >= 3) AreaEntity(id: p.newId(), points: List.of(l.region.outline), name: t('tpl.${kind.name}'))];
      p.entities.addAll(out);
      return out;
    }, label: 'hist.template');
    if (made == null) return;
    c.select(made.map((e) => e.id));
    if (ctx.mounted) Navigator.pop(ctx);
  }

  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final l = preview.watch(key(), compute, ctx, setState);
        final family = c.project.catalog.outlet(familyId);
        NumField size(String label, double v, ValueChanged<double> set, {Key? key}) =>
            NumField(key: key, label: label, value: u.lengthFromSi(v), onChanged: (x) => setState(() => set(x > 0 ? math.min(2000, u.lengthToSi(x)) : v)));
        final lengthLabel = '${t('dlg.length')} (${u.lengthLabel})', widthLabel = '${t('rep.width')} (${u.lengthLabel})';
        final fixedShape = (kind == _Template.green && useShape && sel.area != null) || (kind == _Template.fairway && useLine && sel.lines.isNotEmpty);
        final inputs = <Widget>[
          _note(t('tpl.hint')),
          SpecDropdown<_Template>(
            key: const Key('tpl_kind'),
            label: t('tpl.kind'),
            value: kind.name,
            items: _Template.values,
            labelOf: (k) => t('tpl.${k.name}'),
            idOf: (k) => k.name,
            onChanged: (v) => setState(() => kind = _Template.values.byName(v!)),
          ),
          SpecDropdown<OutletSpec>(
            label: t('autolay.family'),
            value: familyId,
            items: families,
            labelOf: (x) => x.name,
            idOf: (x) => x.id,
            onChanged: (v) => setState(() {
              familyId = v ?? familyId;
              nozzleId = null;
            }),
          ),
          NumField(label: t('autolay.pressure', {'u': u.pressureLabel}), value: u.pressureFromHead(headM), onChanged: (v) => setState(() => headM = v > 0 ? u.pressureToHead(v) : 0)),
          if (family != null)
            SpecDropdown<NozzleSpec>(
              key: ValueKey('tpl_nozzle_$familyId'),
              label: t('autolay.refNozzle'),
              value: nozzleId,
              items: [
                for (final n in family.nozzles)
                  if (n.arcDeg >= 360 - 1e-6) n,
              ],
              labelOf: (n) => n.name,
              idOf: (n) => n.id,
              allowNull: true,
              nullLabel: t('auto'),
              onChanged: (v) => setState(() => nozzleId = v),
            ),
          ...switch (kind) {
            _Template.pitch => [
              _row([size(lengthLabel, pitchLength, (v) => pitchLength = v), size(widthLabel, pitchWidth, (v) => pitchWidth = v)]),
              NumField(label: t('tpl.rows'), value: rows.toDouble(), decimals: 0, onChanged: (v) => setState(() => rows = v.round() <= 0 ? 0 : v.round().clamp(2, 50))),
            ],
            _Template.track => [
              _row([
                size(t('tpl.straight', {'u': u.lengthLabel}), straight, (v) => straight = v),
                size(t('tpl.bendRadius', {'u': u.lengthLabel}), bend, (v) => bend = v),
              ]),
            ],
            _Template.green => [
              if (sel.area != null) _switch(t('tpl.useShape'), useShape, (v) => setState(() => useShape = v)),
              if (!useShape || sel.area == null) _row([size(lengthLabel, greenLength, (v) => greenLength = v), size(widthLabel, greenWidth, (v) => greenWidth = v)]),
              _row([
                NumField(label: t('tpl.setback', {'u': u.lengthLabel}), value: u.lengthFromSi(setback), onChanged: (v) => setState(() => setback = v < 0 ? 0 : u.lengthToSi(v))),
                NumField(label: t('tpl.arcMargin'), value: arcMargin, decimals: 0, onChanged: (v) => setState(() => arcMargin = v.clamp(0, 90).toDouble())),
              ]),
            ],
            _Template.tee => [
              _row([size(lengthLabel, teeLength, (v) => teeLength = v), size(widthLabel, teeWidth, (v) => teeWidth = v)]),
            ],
            _Template.fairway => [
              if (sel.lines.isNotEmpty) _switch(t('tpl.useLine'), useLine, (v) => setState(() => useLine = v)),
              _row([if (!useLine || sel.lines.isEmpty) size(lengthLabel, fairwayLength, (v) => fairwayLength = v), size(widthLabel, fairwayWidth, (v) => fairwayWidth = v)]),
              _switch(t('tpl.edgeParts'), edgeParts, (v) => setState(() => edgeParts = v)),
            ],
          },
          if (!fixedShape) ...[
            NumField(label: t('props.rotation'), value: rotation, decimals: 1, onChanged: (v) => setState(() => rotation = v)),
            _note(t('tpl.at', {'x': _n(u.lengthFromSi(centre.x)), 'y': _n(u.lengthFromSi(centre.y)), 's': t(atSelection ? 'tpl.atSelection' : 'tpl.atView')}), color: Cad.fg54),
          ],
        ];
        final summary = <Widget>[
          SectionTitle(t('auto.summary')),
          ...preview.status(c),
          if (l == null && preview.stale) _note(t('auto.computing'), color: Cad.fg54),
          if (l != null && family != null) ...[KV(t('rep.area'), _surface(u, l.region.area)), ..._layoutSummary(c, family, l), _messageBlock(_messages(c, l.messages, count: (n) => _headCount(c, n)))],
        ];
        return AlertDialog(
          title: Text(t('tpl.title'), style: const TextStyle(fontSize: 15)),
          content: _body(ctx, inputs, summary),
          actions: _actions(ctx, c, const Key('tpl_generate'), l == null || l.heads.isEmpty ? null : () => generate(ctx)),
        );
      },
    ),
  );
}

// ---------------------------------------------------------------- field subdivision

/// What the field subdivision would generate.
class _FieldPlan {
  _FieldPlan(this.subdivision, this.flowPerHectare, this.emitterFlow, this.emitterSpacing, this.lateralSpacing, this.names);
  final FieldSubdivision subdivision;

  /// Emitter flow per hectare (m³/s) from one emitter's flow (m³/s), the
  /// emitter spacing and the lateral spacing (m).
  final double flowPerHectare, emitterFlow, emitterSpacing, lateralSpacing;

  /// Zone name of every block.
  final List<String> names;
}

Widget _cell(String s, {bool bold = false}) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
  child: Text(s, style: TextStyle(fontSize: 11, fontWeight: bold ? FontWeight.w600 : null)),
);

/// Cuts the selected field into blocks of equal net area with roads between
/// them, limited by an area or by the flow a block may draw (from the
/// emitter flow and spacings of the laterals), as strips along the rows or
/// as a grid that also limits the lateral length; generates the laterals,
/// submain and valve of every block with the block generator and, on
/// demand, a mainline from the point of connection to the valves.
Future<void> showFieldSubdivisionDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final u = c.units;
  final s = c.toolSettings;
  final cat = c.project.catalog;
  final sel = _Picked(c);
  final field = sel.area;
  var autoDirection = true;
  var directionDeg = field == null ? 0.0 : normalizeDeg(radToDeg(longestEdgeDirection(normalizePolygon(field)).angle));
  var mode = SubdivisionMode.strips;
  var byFlow = false;
  var maxArea = 2e4;
  // without the supply's flow, a usual field block (not the largest valve)
  final zd = defaultMaxZoneFlow(c.project);
  var maxFlow = zd.typical ? (zd.valve > 0 ? math.min(30 * m3sPerM3h, zd.valve) : 30 * m3sPerM3h) : zd.flow;
  var maxLateral = 0.0, road = 4.0, minWidth = 10.0;
  var centreFeed = false;
  var isTape = true;
  var tapeLateral = 1.5, sprayLateral = 12.0;
  var tapeSpec = cat.tape(s.tapeSpecId) != null ? s.tapeSpecId : (cat.tapes.firstOrNull?.id ?? '');
  var tapeInlet = cat.tape(tapeSpec)?.defaultInletHeadM ?? s.tapeInletHeadM;
  var outletSpec = s.outletSpecId;
  var nozzle = s.nozzleId;
  var headM = s.headM;
  var outletSpacing = s.spacing;
  String? lateralPipe = s.lateralPipeSpecId;
  String? submainPipe;
  String? valveSpec;
  var stub = 1.5;
  final sources = _sources(c, sel);
  var sourceId = sources.first.id;
  var mainlineOn = false;
  final preview = _Preview<_FieldPlan>();

  String key() => [
    autoDirection,
    directionDeg,
    mode.name,
    byFlow,
    maxArea,
    maxFlow,
    maxLateral,
    road,
    minWidth,
    centreFeed,
    isTape,
    tapeLateral,
    sprayLateral,
    tapeSpec,
    tapeInlet,
    outletSpec,
    nozzle,
    headM,
    outletSpacing,
    sourceId,
  ].join('|');

  _FieldPlan? compute() {
    if (field == null) return null;
    double q = 0, se = 0;
    if (isTape) {
      final tp = c.project.catalog.tape(tapeSpec);
      if (tp != null) (q, se) = (tp.emitter.flow(tapeInlet), tp.emitterSpacingM);
    } else {
      final nz = c.project.catalog.outlet(outletSpec)?.nozzle(nozzle);
      if (nz != null) (q, se) = (nz.curve.flow(headM), outletSpacing);
    }
    final sl = isTape ? tapeLateral : sprayLateral;
    final perHa = q > 0 && se > 0 && sl > 0 ? q * 1e4 / (se * sl) : 0.0;
    final sub = subdivideField(
      field,
      FieldSubdivisionOptions(
        direction: autoDirection ? longestEdgeDirection(normalizePolygon(field)) : Pt.polar(1, degToRad(directionDeg)),
        mode: mode,
        maxBlockArea: byFlow ? 0 : maxArea,
        maxBlockFlow: byFlow ? maxFlow : 0,
        flowPerHectare: perHa,
        maxLateralLength: maxLateral,
        centreFeed: centreFeed,
        minBlockWidth: minWidth,
        roadWidth: road,
        pointOfConnection: _sourceOf(sources, sourceId).point,
        // 1.6.0 AUT: the other closed shapes selected are left out of the blocks
        exclusions: sel.others,
      ),
    );
    // the laterals the blocks would get: one a lateral spacing across the rows (two with the submain in the middle)
    final across = sub.direction.perpendicular;
    var laterals = 0.0;
    for (final b in sub.blocks) {
      final vs = [for (final q in b.polygon) q.dot(across)];
      laterals += (vs.reduce(math.max) - vs.reduce(math.min)) / sl * (b.submain == SubmainPosition.centre ? 2 : 1);
    }
    if (laterals > _maxItems) throw const _TooMany();
    return _FieldPlan(sub, perHa, q, se, sl, _zoneNames(c.project, t('subdiv.block'), sub.blocks.length));
  }

  void generate(BuildContext ctx) {
    if (!ctx.mounted) return;
    final plan = preview.now(key(), compute);
    if (plan == null || plan.subdivision.blocks.isEmpty) return;
    final sub = plan.subdivision;
    final poc = _sourceOf(sources, sourceId).point;
    final made = c.mutate(() {
      final p = c.project;
      final out = <Entity>[];
      final valves = <Pt>[];
      for (var i = 0; i < sub.blocks.length; i++) {
        final b = sub.blocks[i];
        final res = generateBlock(
          p,
          blockOptionsFor(
            b,
            sub.direction,
            lateralSpacing: plan.lateralSpacing,
            isTape: isTape,
            tapeSpecId: tapeSpec,
            tapeInletHeadM: tapeInlet,
            outletSpecId: outletSpec,
            nozzleId: nozzle,
            outletSpacing: outletSpacing,
            headM: headM,
            lateralPipeSpecId: isTape ? null : lateralPipe,
            submainPipeSpecId: submainPipe,
            valveSpecId: valveSpec ?? (b.flow > 0 ? pickZoneValve(p.catalog, b.flow)?.id : s.valveSpecId),
            submainStub: stub,
            zoneName: plan.names[i],
            submainLabel: t('name.submain'),
            stubLabel: t('name.stub'),
            lateralPrefix: t('name.lateral'),
            submainDepth: defaultZonePipeDepthM,
            exclusions: sel.others,
          ),
        );
        out.addAll(res.all);
        if (res.valve != null) valves.add(res.valve!.position);
      }
      if (mainlineOn && poc != null && valves.isNotEmpty) {
        for (final m in routeMainline(poc, valves, boundary: field)) {
          out.add(PipeEntity(id: p.newId(), points: List.of(m.points), scope: HydraulicScope.mainline, depth: defaultMainlineDepthM));
        }
      }
      p.entities.addAll(out);
      return out;
    }, label: 'hist.fieldBlocks');
    if (made == null) return;
    c.select(made.map((e) => e.id));
    if (ctx.mounted) Navigator.pop(ctx);
  }

  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        if (field == null) return _nothingSelected(ctx, c, t('subdiv.title'), t('subdiv.hint'), t('auto.noField'));
        final plan = preview.watch(key(), compute, ctx, setState);
        final cat = c.project.catalog;
        final outlet = cat.outlet(outletSpec);
        String lenLabel(String k) => t(k, {'u': u.lengthLabel});
        NumField len(String label, double v, ValueChanged<double> set, {bool zero = false, Key? key}) =>
            NumField(key: key, label: label, value: u.lengthFromSi(v), onChanged: (x) => setState(() => set(x > 0 || (zero && x == 0) ? u.lengthToSi(x) : v)));
        final inputs = <Widget>[
          _note(t('subdiv.hint')),
          _note(t('auto.fieldInfo', {'a': _hectares(u, polygonArea(field).abs())}), color: Cad.fg),
          // 1.6.0 AUT: the other closed shapes are holes in the blocks
          if (sel.others.isNotEmpty) _note(t('auto.exclusionsLeftOut', {'n': '${sel.others.length}'}), color: Cad.fg54),
          _switch(t('auto.longestEdge'), autoDirection, (v) => setState(() => autoDirection = v)),
          if (!autoDirection) NumField(label: t('auto.direction'), value: directionDeg, decimals: 1, onChanged: (v) => setState(() => directionDeg = normalizeDeg(v))),
          SegmentedButton<SubdivisionMode>(
            key: const Key('fs_mode'),
            segments: [
              ButtonSegment(value: SubdivisionMode.strips, label: Text(t('subdiv.mode.strips'))),
              ButtonSegment(value: SubdivisionMode.grid, label: Text(t('subdiv.mode.grid'))),
            ],
            selected: {mode},
            onSelectionChanged: (v) => setState(() => mode = v.first),
          ),
          const SizedBox(height: 6),
          SegmentedButton<bool>(
            key: const Key('fs_limit'),
            segments: [
              ButtonSegment(value: false, label: Text(t('subdiv.limit.area'))),
              ButtonSegment(value: true, label: Text(t('subdiv.limit.flow'))),
            ],
            selected: {byFlow},
            onSelectionChanged: (v) => setState(() => byFlow = v.first),
          ),
          if (byFlow)
            NumField(
              key: const Key('fs_max_flow'),
              label: t('subdiv.maxFlow', {'u': u.flowLabel}),
              value: u.flowFromSi(maxFlow),
              onChanged: (v) => setState(() => maxFlow = v > 0 ? u.flowToSi(v) : maxFlow),
            )
          else
            NumField(
              key: const Key('fs_max_area'),
              label: t('subdiv.maxArea', {'u': u.areaLabel}),
              value: u.areaFromSi(maxArea),
              onChanged: (v) => setState(() => maxArea = v > 0 ? v / u.areaFromSi(1) : maxArea),
            ),
          len(lenLabel('subdiv.maxLateral'), maxLateral, (v) => maxLateral = v <= 0 ? 0 : math.max(10, v), zero: true),
          _row([len(lenLabel('subdiv.road'), road, (v) => road = v, zero: true), len(lenLabel('subdiv.minWidth'), minWidth, (v) => minWidth = math.max(2, v))]),
          _switch(t('subdiv.centreFeed'), centreFeed, (v) => setState(() => centreFeed = v)),
          SectionTitle(t('dlg.laterals')),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: false, label: Text(t('dlg.sprayBlock'))),
              ButtonSegment(value: true, label: Text(t('dlg.dripBlock'))),
            ],
            selected: {isTape},
            onSelectionChanged: (v) => setState(() => isTape = v.first),
          ),
          if (isTape) ...[
            _row([
              SpecDropdown<TapeSpec>(
                label: t('props.tape'),
                value: tapeSpec,
                items: cat.tapes.where((x) => x.enabled).toList(),
                labelOf: (x) => x.name,
                idOf: (x) => x.id,
                onChanged: (v) => setState(() {
                  tapeSpec = v ?? tapeSpec;
                  tapeInlet = cat.tape(tapeSpec)?.defaultInletHeadM ?? tapeInlet;
                }),
              ),
              NumField(label: '${t('props.inlet')} (${u.pressureLabel})', value: u.pressureFromHead(tapeInlet), onChanged: (v) => setState(() => tapeInlet = v > 0 ? u.pressureToHead(v) : tapeInlet)),
            ]),
            len('${t('dlg.lateralSpacing')} (${u.lengthLabel})', tapeLateral, (v) => tapeLateral = math.max(0.1, v), key: const Key('fs_lateral_spacing')),
          ] else ...[
            _row([
              SpecDropdown<OutletSpec>(
                label: t('props.outlet'),
                value: outletSpec,
                items: cat.outlets.where((o) => o.enabled && o.kind != OutletKind.demandPoint && o.nozzles.isNotEmpty).toList(),
                labelOf: (x) => x.name,
                idOf: (x) => x.id,
                onChanged: (v) => setState(() {
                  outletSpec = v ?? outletSpec;
                  nozzle = cat.outlet(outletSpec)?.nozzles.firstOrNull?.id;
                  headM = cat.outlet(outletSpec)?.nozzles.firstOrNull?.defaultHeadM ?? headM;
                }),
              ),
              if (outlet != null)
                SpecDropdown<NozzleSpec>(
                  key: ValueKey('fs_nozzle_$outletSpec'),
                  label: t('props.nozzle'),
                  value: nozzle,
                  items: outlet.nozzles,
                  labelOf: (x) => x.name,
                  idOf: (x) => x.id,
                  onChanged: (v) => setState(() {
                    nozzle = v;
                    headM = outlet.nozzle(v)?.defaultHeadM ?? headM;
                  }),
                ),
            ]),
            NumField(label: '${t('props.head')} (${u.pressureLabel})', value: u.pressureFromHead(headM), onChanged: (v) => setState(() => headM = v > 0 ? u.pressureToHead(v) : headM)),
            _row([
              len('${t('dlg.emitterSpacing')} (${u.lengthLabel})', outletSpacing, (v) => outletSpacing = math.max(0.05, v)),
              len('${t('dlg.lateralSpacing')} (${u.lengthLabel})', sprayLateral, (v) => sprayLateral = math.max(0.1, v)),
            ]),
            SpecDropdown<PipeSpec>(
              label: t('dlg.lateralPipe'),
              value: lateralPipe,
              items: cat.pipesFor(PipeUsage.lateral),
              labelOf: (x) => x.name,
              idOf: (x) => x.id,
              allowNull: true,
              nullLabel: t('auto'),
              onChanged: (v) => setState(() => lateralPipe = v),
            ),
          ],
          SectionTitle(t('dlg.submainValve')),
          _row([
            SpecDropdown<PipeSpec>(
              label: t('dlg.submainPipe'),
              value: submainPipe,
              items: cat.pipesFor(PipeUsage.zone),
              labelOf: (x) => x.name,
              idOf: (x) => x.id,
              allowNull: true,
              nullLabel: t('auto'),
              onChanged: (v) => setState(() => submainPipe = v),
            ),
            SpecDropdown<ValveSpec>(
              label: t('props.valve'),
              value: valveSpec,
              items: cat.valves.where((x) => x.enabled && x.kind == ValveKind.control).toList(),
              labelOf: (x) => x.name,
              idOf: (x) => x.id,
              allowNull: true,
              nullLabel: t('auto.valveAuto'),
              onChanged: (v) => setState(() => valveSpec = v),
            ),
          ]),
          _row([
            SpecDropdown<_Source>(label: t('auto.connection'), value: sourceId, items: sources, labelOf: (x) => x.label, idOf: (x) => x.id, onChanged: (v) => setState(() => sourceId = v ?? '')),
            len('${t('dlg.stub')} (${u.lengthLabel})', stub, (v) => stub = v, zero: true),
          ]),
          if (_sourceOf(sources, sourceId).point != null) _switch(t('subdiv.mainline'), mainlineOn, (v) => setState(() => mainlineOn = v), key: const Key('fs_mainline')),
        ];
        final sub = plan?.subdivision;
        final blocks = sub?.blocks ?? const <FieldBlock>[];
        double least(double Function(FieldBlock b) f) => blocks.fold(double.infinity, (m, b) => math.min(m, f(b)));
        double most(double Function(FieldBlock b) f) => blocks.fold(0.0, (m, b) => math.max(m, f(b)));
        final summary = <Widget>[
          SectionTitle(t('auto.summary')),
          ...preview.status(c),
          if (plan == null && preview.stale) _note(t('auto.computing'), color: Cad.fg54),
          if (plan != null && sub != null) ...[
            KV(
              t('subdiv.flowPerArea'),
              plan.flowPerHectare > 0
                  ? '${_n(u.flowFromSi(plan.flowPerHectare) / u.areaFromSi(1e4))} ${u.flowLabel}/${u.areaLabel} (${_flow(u, plan.emitterFlow)} · ${_len(u, plan.emitterSpacing)} × ${_len(u, plan.lateralSpacing)})'
                  : '-',
            ),
            KV(t('subdiv.blocks'), '${blocks.length}'),
            if (blocks.isNotEmpty) ...[
              KV(t('subdiv.blockArea'), '${_hectares(u, least((b) => b.area))} – ${_hectares(u, most((b) => b.area))}'),
              if (plan.flowPerHectare > 0) KV(t('subdiv.blockFlow'), '${_flow(u, least((b) => b.flow))} – ${_flow(u, most((b) => b.flow))}'),
              KV(t('subdiv.longestLateral'), _len(u, most((b) => b.lateralLength))),
              KV(t('subdiv.roads'), _hectares(u, math.max(0.0, sub.fieldArea - sub.blocksArea))),
              const SizedBox(height: 4),
              Table(
                defaultColumnWidth: const IntrinsicColumnWidth(),
                children: [
                  TableRow(
                    children: [_cell(t('subdiv.block'), bold: true), _cell(u.areaLabel, bold: true), _cell(u.flowLabel, bold: true), _cell('${t('subdiv.lateral')} (${u.lengthLabel})', bold: true)],
                  ),
                  for (var i = 0; i < math.min(blocks.length, 30); i++)
                    TableRow(
                      children: [_cell(plan.names[i]), _cell(fmt(u.areaFromSi(blocks[i].area), 2)), _cell(_n(u.flowFromSi(blocks[i].flow))), _cell(_n(u.lengthFromSi(blocks[i].lateralLength)))],
                    ),
                ],
              ),
              if (blocks.length > 30) _note(t('subdiv.more', {'n': '${blocks.length - 30}'}), color: Cad.fg54),
            ],
            _messageBlock(_messages(c, sub.messages, name: (b) => plan.names.elementAtOrNull(int.tryParse(b) ?? -1) ?? b, count: (n) => t('auto.nBlocks', {'n': '$n'}))),
          ],
        ];
        return AlertDialog(
          title: Text(t('subdiv.title'), style: const TextStyle(fontSize: 15)),
          content: _body(ctx, inputs, summary),
          actions: _actions(ctx, c, const Key('fs_generate'), plan == null || blocks.isEmpty ? null : () => generate(ctx)),
        );
      },
    ),
  );
}

// ---------------------------------------------------------------- tree rings

/// Row direction of surveyed [trees] (degrees, in [0, 180)): the commonest
/// direction from a tree to its nearest neighbour, the trees of a row
/// standing closer together than the rows (5° classes, the mean of the
/// commonest one). 0 for fewer than two trees.
double _rowDirectionDeg(List<Pt> trees) {
  if (trees.length < 2) return 0;
  final b = Bounds.ofPoints(trees);
  final grid = PointGrid(pointGridCell(b, trees.length), origin: Pt(b.minX, b.minY));
  for (final p in trees) {
    grid.add(p);
  }
  final classes = <int, List<double>>{};
  for (var i = 0; i < trees.length; i++) {
    final j = grid.nearest(trees[i], skip: (k) => k == i);
    if (j < 0) continue;
    final a = normalizeDeg(radToDeg((trees[j] - trees[i]).angle)) % 180;
    (classes[(a / 5).floor() % 36] ??= []).add(a);
  }
  if (classes.isEmpty) return 0;
  final best = classes.entries.reduce((x, y) => y.value.length > x.value.length || (y.value.length == x.value.length && y.key < x.key) ? y : x).value;
  return best.fold(0.0, (s, a) => s + a) / best.length;
}

/// Drip rings round orchard trees: the trees of a planting grid inside the
/// selected area (or the selected tree symbols, surveyed positions), a ring
/// of dripline or drippers on a small ring pipe round every trunk, laterals
/// along the rows from a submain with the zone valve.
Future<void> showTreeRingsDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final u = c.units;
  final s = c.toolSettings;
  final cat = c.project.catalog;
  final sel = _Picked(c);
  final area = sel.area;
  final trees = [
    for (final e in sel.symbols)
      if (e.kind == SymbolKind.tree) e.position,
  ];
  var autoDirection = area != null && trees.isEmpty;
  var directionDeg = trees.isNotEmpty ? _rowDirectionDeg(trees) : (area == null ? 0.0 : normalizeDeg(radToDeg(longestEdgeDirection(normalizePolygon(area)).angle)));
  var plantSpacing = 6.0, rowSpacing = 7.0, rowOffset = 0.0, plantOffset = 0.0, ringRadius = 0.75;
  var kind = RingKind.dripline;
  var drippers = 4;
  var tapeSpec = cat.tape(s.tapeSpecId) != null ? s.tapeSpecId : (cat.tapes.firstOrNull?.id ?? '');
  var tapeInlet = cat.tape(tapeSpec)?.defaultInletHeadM ?? s.tapeInletHeadM;
  final dripperFamilies = [
    for (final o in cat.outlets)
      if (o.enabled && o.nozzles.isNotEmpty && (o.kind == OutletKind.dripper || o.kind == OutletKind.bubbler)) o,
  ];
  var dripperSpec = dripperFamilies.firstOrNull?.id;
  var nozzle = dripperFamilies.firstOrNull?.nozzles.first.id;
  var headM = dripperFamilies.firstOrNull?.nozzles.first.defaultHeadM ?? 10.0;
  var side = SubmainPosition.start;
  var stub = 1.5;
  String? lateralPipe = s.lateralPipeSpecId;
  String? valveSpec;
  var zoneName = _zoneNames(c.project, t('name.zone'), 1).first;
  final preview = _Preview<TreeRingLayout>();

  String key() => [autoDirection, directionDeg, plantSpacing, rowSpacing, rowOffset, plantOffset, ringRadius, kind.name, drippers, side.name, stub].join('|');

  TreeRingLayout? compute() {
    if (trees.isEmpty && area == null) return null;
    if (trees.isEmpty && polygonArea(area!).abs() / (plantSpacing * rowSpacing) > _maxItems) throw const _TooMany();
    final dir = autoDirection && area != null ? longestEdgeDirection(normalizePolygon(area)) : Pt.polar(1, degToRad(directionDeg));
    return layoutTreeRings(
      area: area,
      trees: trees.isEmpty ? null : trees,
      options: TreeRingOptions(
        direction: dir,
        plantSpacing: plantSpacing,
        rowSpacing: rowSpacing,
        rowOffset: rowOffset,
        plantOffset: plantOffset,
        ringRadius: ringRadius,
        kind: kind,
        drippersPerTree: drippers,
        submainPosition: side,
        submainStub: stub,
        // 1.6.0 AUT: no trees in the other closed shapes selected
        exclusions: sel.others,
      ),
    );
  }

  /// Flow of every emitter of [r] at its pressure (m³/s).
  double flowOf(TreeRingLayout r) {
    if (r.kind == RingKind.dripline) {
      final tp = c.project.catalog.tape(tapeSpec);
      return tp == null || !(tp.emitterSpacingM > 0) ? 0 : r.ringLength / tp.emitterSpacingM * tp.emitter.flow(tapeInlet);
    }
    final nz = c.project.catalog.outlet(dripperSpec)?.nozzle(nozzle);
    return nz == null ? 0 : r.dripperCount * nz.curve.flow(headM);
  }

  void generate(BuildContext ctx) {
    if (!ctx.mounted) return;
    final r = preview.now(key(), compute);
    if (r == null || r.trees.isEmpty) return;
    final made = c.mutate(() {
      final p = c.project;
      final zone = zoneName.trim().isEmpty ? _zoneNames(p, t('name.zone'), 1).first : zoneName.trim();
      final out = r.toEntities(
        p,
        tapeSpecId: tapeSpec,
        tapeInletHeadM: tapeInlet,
        outletSpecId: dripperSpec,
        nozzleId: nozzle,
        headM: headM,
        valveSpecId: valveSpec ?? pickZoneValve(p.catalog, flowOf(r))?.id,
        zoneName: zone,
        lateralPipeSpecId: lateralPipe,
      );
      p.entities.addAll(out);
      return out;
    }, label: 'hist.treeRings');
    if (made == null) return;
    c.select(made.map((e) => e.id));
    if (ctx.mounted) Navigator.pop(ctx);
  }

  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        if (area == null && trees.isEmpty) return _nothingSelected(ctx, c, t('rings.title'), t('rings.hint'), t('rings.noSource'));
        final r = preview.watch(key(), compute, ctx, setState);
        final cat = c.project.catalog;
        final dripper = cat.outlet(dripperSpec);
        NumField len(String label, double v, ValueChanged<double> set, {bool zero = false, Key? key}) =>
            NumField(key: key, label: label, value: u.lengthFromSi(v), onChanged: (x) => setState(() => set(x > 0 || (zero && x == 0) ? u.lengthToSi(x) : v)));
        String lenLabel(String k) => t(k, {'u': u.lengthLabel});
        final inputs = <Widget>[
          _note(t('rings.hint')),
          _note(trees.isNotEmpty ? t('rings.fromTrees', {'n': '${trees.length}'}) : t('rings.fromArea', {'a': _hectares(u, polygonArea(area!).abs())}), color: Cad.fg),
          if (trees.isEmpty && sel.others.isNotEmpty) _note(t('auto.exclusionsLeftOut', {'n': '${sel.others.length}'}), color: Cad.fg54),
          // surveyed trees give their own rows: the direction found is shown
          if (area != null && trees.isEmpty) _switch(t('auto.longestEdge'), autoDirection, (v) => setState(() => autoDirection = v)),
          if (!autoDirection) NumField(key: const Key('tr_direction'), label: t('auto.direction'), value: directionDeg, decimals: 1, onChanged: (v) => setState(() => directionDeg = normalizeDeg(v))),
          _row([
            len(lenLabel('rings.plantSpacing'), plantSpacing, (v) => plantSpacing = math.max(0.3, v), key: const Key('tr_plant')),
            len(lenLabel('rings.rowSpacing'), rowSpacing, (v) => rowSpacing = math.max(0.3, v), key: const Key('tr_row')),
          ]),
          if (trees.isEmpty) ...[len(lenLabel('rings.rowOffset'), rowOffset, (v) => rowOffset = v, zero: true), len(lenLabel('rings.plantOffset'), plantOffset, (v) => plantOffset = v, zero: true)],
          len(lenLabel('rings.radius'), ringRadius, (v) => ringRadius = v.clamp(0.05, 10).toDouble()),
          SegmentedButton<RingKind>(
            key: const Key('tr_kind'),
            segments: [
              ButtonSegment(value: RingKind.dripline, label: Text(t('rings.kind.dripline'))),
              ButtonSegment(value: RingKind.drippers, label: Text(t('rings.kind.drippers'))),
            ],
            selected: {kind},
            onSelectionChanged: (v) => setState(() => kind = v.first),
          ),
          if (kind == RingKind.dripline)
            _row([
              SpecDropdown<TapeSpec>(
                label: t('props.tape'),
                value: tapeSpec,
                items: cat.tapes.where((x) => x.enabled).toList(),
                labelOf: (x) => x.name,
                idOf: (x) => x.id,
                onChanged: (v) => setState(() {
                  tapeSpec = v ?? tapeSpec;
                  tapeInlet = cat.tape(tapeSpec)?.defaultInletHeadM ?? tapeInlet;
                }),
              ),
              NumField(label: '${t('props.inlet')} (${u.pressureLabel})', value: u.pressureFromHead(tapeInlet), onChanged: (v) => setState(() => tapeInlet = v > 0 ? u.pressureToHead(v) : tapeInlet)),
            ])
          else ...[
            _row([
              SpecDropdown<OutletSpec>(
                label: t('rings.dripper'),
                value: dripperSpec,
                items: dripperFamilies,
                labelOf: (x) => x.name,
                idOf: (x) => x.id,
                onChanged: (v) => setState(() {
                  dripperSpec = v ?? dripperSpec;
                  nozzle = cat.outlet(dripperSpec)?.nozzles.firstOrNull?.id;
                  headM = cat.outlet(dripperSpec)?.nozzles.firstOrNull?.defaultHeadM ?? headM;
                }),
              ),
              if (dripper != null)
                SpecDropdown<NozzleSpec>(
                  key: ValueKey('tr_nozzle_$dripperSpec'),
                  label: t('props.nozzle'),
                  value: nozzle,
                  items: dripper.nozzles,
                  labelOf: (x) => x.name,
                  idOf: (x) => x.id,
                  onChanged: (v) => setState(() {
                    nozzle = v;
                    headM = dripper.nozzle(v)?.defaultHeadM ?? headM;
                  }),
                ),
            ]),
            _row([
              NumField(label: '${t('props.head')} (${u.pressureLabel})', value: u.pressureFromHead(headM), onChanged: (v) => setState(() => headM = v > 0 ? u.pressureToHead(v) : headM)),
              NumField(label: t('rings.drippers'), value: drippers.toDouble(), decimals: 0, onChanged: (v) => setState(() => drippers = v.round().clamp(1, 24))),
            ]),
          ],
          SectionTitle(t('dlg.submainValve')),
          SpecDropdown<PipeSpec>(
            label: t('dlg.lateralPipe'),
            value: lateralPipe,
            items: cat.pipesFor(PipeUsage.lateral),
            labelOf: (x) => x.name,
            idOf: (x) => x.id,
            allowNull: true,
            nullLabel: t('auto'),
            onChanged: (v) => setState(() => lateralPipe = v),
          ),
          _row([
            SpecDropdown<SubmainPosition>(
              label: t('dlg.submainPosition'),
              value: side.name,
              items: SubmainPosition.values,
              labelOf: (x) => switch (x) {
                SubmainPosition.start => t('dlg.submainStart'),
                SubmainPosition.centre => t('dlg.submainCentre'),
                SubmainPosition.end => t('dlg.submainEnd'),
              },
              idOf: (x) => x.name,
              onChanged: (v) => setState(() => side = SubmainPosition.values.byName(v!)),
            ),
            len('${t('dlg.stub')} (${u.lengthLabel})', stub, (v) => stub = v),
          ]),
          _row([
            SpecDropdown<ValveSpec>(
              label: t('props.valve'),
              value: valveSpec,
              items: cat.valves.where((x) => x.enabled && x.kind == ValveKind.control).toList(),
              labelOf: (x) => x.name,
              idOf: (x) => x.id,
              allowNull: true,
              nullLabel: t('auto.valveAuto'),
              onChanged: (v) => setState(() => valveSpec = v),
            ),
            TextFieldRow(label: t('props.zone'), value: zoneName, onChanged: (v) => setState(() => zoneName = v)),
          ]),
        ];
        final summary = <Widget>[
          SectionTitle(t('auto.summary')),
          ...preview.status(c),
          if (r == null && preview.stale) _note(t('auto.computing'), color: Cad.fg54),
          if (r != null) ...[
            KV(t('rings.trees'), '${r.trees.length}'),
            KV(t('dlg.laterals'), '${r.laterals.length}'),
            KV(t('rings.lateralLength'), _len(u, r.laterals.fold(0.0, (m, l) => m + polylineLength(l)))),
            KV(t('rings.ringLength'), _len(u, r.ringLength)),
            if (r.kind == RingKind.drippers) KV(t('dlg.emittersCount'), '${r.dripperCount}'),
            KV(t('auto.flowTotal'), _flow(u, flowOf(r))),
            _messageBlock(_messages(c, r.messages, name: (k) => '${t('rings.row')} ${(int.tryParse(k) ?? 0) + 1}', count: (n) => t('auto.nRows', {'n': '$n'}))),
          ],
        ];
        return AlertDialog(
          title: Text(t('rings.title'), style: const TextStyle(fontSize: 15)),
          content: _body(ctx, inputs, summary),
          actions: _actions(ctx, c, const Key('tr_generate'), r == null || r.trees.isEmpty ? null : () => generate(ctx)),
        );
      },
    ),
  );
}

// ---------------------------------------------------------------- pivot fit

/// Lengths typed in the user's length unit, separated by semicolons, else by
/// spaces or by a comma and a space ("34,4; 41,8", "34.4, 41.8", "48,8": a
/// lone comma is the decimal one).
List<double> _lengths(Units u, String text, {bool zero = false}) => [
  for (final item in text.contains(';') ? text.split(';') : text.split(RegExp(r',\s+|\s+')))
    if (parseNumber(item.trim()) case final v? when v > 0 || (zero && v == 0)) u.lengthToSi(v),
];

String _lengthList(Units u, List<double> vs) => vs.map((v) => _compact(u.lengthFromSi(v))).join('; ');

/// "6 × 54.9 + 1 × 48.8 + 12.8 (overhang) = 390.7 m".
String _machine(ProjectController c, SpanCombination s) {
  final u = c.units;
  final counts = <double, int>{};
  for (final v in s.spans) {
    counts[v] = (counts[v] ?? 0) + 1;
  }
  final parts = [for (final e in counts.entries) '${e.value} × ${_compact(u.lengthFromSi(e.key))}', if (s.overhang > 0) '${_compact(u.lengthFromSi(s.overhang))} (${c.t('pfit.overhang')})'];
  return '${parts.join(' + ')} = ${_len(u, s.length)}';
}

/// The centre pivot that fits the selected field (the largest selected
/// closed shape; the other closed shapes are obstacles, the selected
/// symbols and spot heights point obstacles): the largest full circle, or
/// the sector that irrigates the most; the machine built from standard
/// spans and overhangs.
Future<void> showPivotFitDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final u = c.units;
  final sel = _Picked(c);
  final field = sel.area;
  final points = [for (final e in sel.symbols) e.position, for (final e in sel.spots) e.position];
  var sector = false;
  var spans = [...defaultSpanLengths];
  var overhangs = [...defaultOverhangs];
  var minSpans = 1, maxSpans = 20;
  var endThrow = 5.0, clearance = 10.0, minSweep = 30.0;
  // a list field shows the list as it was read: it is keyed by it, and by
  // this count of lists that could not be read (the old list stays)
  var unreadable = 0;
  final preview = _Preview<PivotFit>();

  String key() => [sector, spans.join(','), overhangs.join(','), minSpans, maxSpans, endThrow, clearance, minSweep].join('|');

  PivotFit? compute() {
    if (field == null) return null;
    final o = PivotFitOptions(
      obstacles: sel.others,
      pointObstacles: [for (final q in points) PointObstacle(q, clearance)],
      spanLengths: spans,
      overhangs: overhangs,
      minSpans: minSpans,
      maxSpans: maxSpans,
      endThrowM: endThrow,
      minSweepDeg: minSweep,
    );
    return sector ? fitSectorPivot(field, o) : fitFullCirclePivot(field, o);
  }

  void generate(BuildContext ctx) {
    if (!ctx.mounted) return;
    final fit = preview.now(key(), compute);
    if (fit == null || fit.spans == null) return;
    final s = c.toolSettings;
    final made = c.mutate(() {
      final p = c.project;
      final n = p.entities.whereType<PivotEntity>().length + 1;
      final e = fit.toPivotEntity(p, name: '${t('tool.pivot').split('/').first.trim()} $n')
        ..grossDepthMm = s.pivotDepthMm
        ..hoursPerCycle = s.pivotHours
        ..endPressureM = s.pivotEndPressureM;
      p.entities.add(e);
      return e;
    }, label: 'hist.pivotFit');
    if (made == null) return;
    c.select([made.id]);
    if (ctx.mounted) Navigator.pop(ctx);
  }

  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        if (field == null) return _nothingSelected(ctx, c, t('pfit.title'), t('pfit.hint'), t('auto.noField'));
        final fit = preview.watch(key(), compute, ctx, setState);
        final inputs = <Widget>[
          _note(t('pfit.hint')),
          _note(t('pfit.info', {'a': _hectares(u, LayoutRegion(field, exclusions: sel.others).area), 'n': '${sel.others.length}', 'p': '${points.length}'}), color: Cad.fg),
          SegmentedButton<bool>(
            key: const Key('pf_mode'),
            segments: [
              ButtonSegment(value: false, label: Text(t('pfit.full'))),
              ButtonSegment(value: true, label: Text(t('pfit.sector'))),
            ],
            selected: {sector},
            onSelectionChanged: (v) => setState(() => sector = v.first),
          ),
          KeyedSubtree(
            key: const Key('pf_spans'),
            child: TextFieldRow(
              key: ValueKey('${_lengthList(u, spans)}#$unreadable'),
              label: t('pfit.spans', {'u': u.lengthLabel}),
              value: _lengthList(u, spans),
              onChanged: (v) => setState(() {
                final read = _lengths(u, v);
                read.isEmpty ? unreadable++ : spans = read;
              }),
            ),
          ),
          KeyedSubtree(
            key: const Key('pf_overhangs'),
            child: TextFieldRow(
              key: ValueKey('${_lengthList(u, overhangs)}#$unreadable'),
              label: t('pfit.overhangs', {'u': u.lengthLabel}),
              value: _lengthList(u, overhangs),
              onChanged: (v) => setState(() {
                final read = _lengths(u, v, zero: true);
                read.isEmpty ? unreadable++ : overhangs = read;
              }),
            ),
          ),
          _row([
            NumField(label: t('pfit.minSpans'), value: minSpans.toDouble(), decimals: 0, onChanged: (v) => setState(() => minSpans = v.round().clamp(1, 60))),
            NumField(label: t('pfit.maxSpans'), value: maxSpans.toDouble(), decimals: 0, onChanged: (v) => setState(() => maxSpans = math.max(minSpans, v.round().clamp(1, 60)))),
          ]),
          NumField(label: t('pfit.endThrow', {'u': u.lengthLabel}), value: u.lengthFromSi(endThrow), onChanged: (v) => setState(() => endThrow = v < 0 ? 0 : u.lengthToSi(v))),
          if (points.isNotEmpty)
            NumField(label: t('pfit.clearance', {'u': u.lengthLabel}), value: u.lengthFromSi(clearance), onChanged: (v) => setState(() => clearance = v < 0 ? 0 : u.lengthToSi(v))),
          if (sector) NumField(label: t('pfit.minSweep'), value: minSweep, decimals: 0, onChanged: (v) => setState(() => minSweep = v.clamp(1, 360).toDouble())),
        ];
        final summary = <Widget>[
          SectionTitle(t('auto.summary')),
          ...preview.status(c),
          if (fit == null && preview.stale) _note(t('auto.computing'), color: Cad.fg54),
          if (fit != null) ...[
            KV(t('pfit.center'), '${_n(u.lengthFromSi(fit.center.x))}, ${_n(u.lengthFromSi(fit.center.y))} ${u.lengthLabel}'),
            KV(t('pfit.available'), _len(u, fit.availableRadius)),
            if (fit.spans != null) ...[
              KV(t('pfit.machine'), _machine(c, fit.spans!)),
              KV(t('pfit.radius'), _len(u, fit.irrigatedRadius)),
              if (!fit.fullCircle) KV(t('pfit.sectorValue'), '${fmt(fit.sectorStartDeg, 0)}° + ${fmt(fit.sectorSweepDeg, 0)}°'),
              KV(t('pfit.area'), _hectares(u, fit.area)),
            ],
            KV(t('pfit.fieldArea'), _hectares(u, fit.fieldArea)),
            KV(t('pfit.coverage'), '${fmt(fit.coverage * 100, 1)} %'),
            _messageBlock(_messages(c, fit.messages)),
          ],
        ];
        return AlertDialog(
          title: Text(t('pfit.title'), style: const TextStyle(fontSize: 15)),
          content: _body(ctx, inputs, summary),
          actions: _actions(ctx, c, const Key('pf_generate'), fit == null || fit.spans == null ? null : () => generate(ctx)),
        );
      },
    ),
  );
}
