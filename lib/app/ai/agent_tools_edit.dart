/// The tools that change the project: items of the drawing, design
/// parameters, catalogue, system flows, layers, project details, quote and
/// label rules. Every input is checked before anything changes, so a
/// refused call leaves the project as it was; each accepted call is one
/// undo step (the assistant folds a whole turn into one).
library;

import '../../core/ai/agent_loop.dart';
import '../../core/design/management.dart';
import '../../core/design/pivot.dart' show PivotKind;
import '../../core/design/valve_in_head.dart' show VihStations;
import '../../core/hydraulics/emitter.dart';
import '../../core/hydraulics/friction.dart';
import '../../core/hydraulics/minor_losses.dart';
import '../../core/hydraulics/water_hammer.dart' show PipeMaterial;
import '../../core/model/catalog.dart';
import '../../core/model/entities.dart';
import '../../core/model/geometry.dart';
import '../../core/model/label_rules.dart';
import '../../core/model/project.dart';
import '../../core/model/terrain.dart';
import '../../core/units.dart';
import '../state/controller.dart';
import 'agent_tools.dart';
import 'ops_cad_common.dart' show cadBindSelected;

// ---------------------------------------------------------------- entity format

/// Properties each creatable type takes (the project-file keys), besides
/// `name` and `layer`.
const entityKeys = <String, List<String>>{
  'area': ['pts', 'depth', 'eff', 'crop', 'epp', 'wb', 'eto', 'kc', 'awc', 'root', 'mad', 'psp', 'rsp', 'wf', 'ck', 'pd', 'soil', 'slope', 'im', 'gc', 'ecw', 'erm', 'dep', 'pwu'],
  'pipe': ['pts', 'scope', 'spec', 'auto', 'depth'],
  'sprayline': ['pts', 'spec', 'auto', 'outlet', 'nozzle', 'head', 'sp', 'off', 'arc', 'riser', 'depth'],
  'tape': ['pts', 'spec', 'inlet', 'reg', 'submin', 'depth', 'flush'],
  'outlet': ['p', 'scope', 'outlet', 'nozzle', 'head', 'arc', 'rot', 'riser', 'zone'],
  'controlValve': ['p', 'spec', 'zone', 'rot', 'fixed', 'depth'],
  'waterSupply': ['p', 'calc', 'dh', 'mh', 'dq', 'mq', 'wl'],
  'pump': ['p', 'spec', 'speed', 'rot', 'scope', 'hm', 'vfd', 'vmin', 'meff'],
  'misc': ['p', 'spec', 'scope', 'set', 'rot', 'setq'],
  'junction': ['p', 'scope', 'z'],
  'pivot': [
    'p',
    'r',
    'ang',
    'kind',
    'travel',
    'span',
    'spec',
    'idmm',
    'c',
    'hp',
    'hend',
    'qg',
    'hg',
    'throw',
    'depth',
    'hours',
    'ww',
    'hm',
    'imax',
    'sector',
    'cost',
    'zone',
    'ssp',
    'sspec',
    'rspec',
    'tcost',
  ],
  'controller': ['p', 'st', 'v', 'cost', 'sim'],
  'wire': ['pts'],
  'contour': ['pts', 'z'],
  'spotHeight': ['p', 'z'],
  'breakline': ['pts', 'zs'],
  'polyline': ['pts', 'closed'],
  'spline': ['pts', 'closed'],
  'line': ['a', 'b'],
  'circle': ['p', 'r'],
  'arc': ['p', 'r', 's', 'w'],
  'hatch': ['pts', 'ang', 'sp', 'solid'],
  'text': ['p', 'text', 'h', 'rot'],
  'leader': ['pts', 'text', 'h'],
  'symbol': ['p', 'kind', 'size', 'rot'],
  'comment': ['p', 'text', 'author', 'date', 'done'],
  // 1.6.0 AGB
  'traveller': ['a', 'b', 'w', 'gun', 'noz', 'q', 'hg', 'dw', 'sector', 'hose', 'hosemm', 'hd', 'zg', 'depth', 'v', 'setup', 'hday', 'wind', 'ring', 'mach', 'cost', 'hcost'],
  'furrows': ['pts', 'right', 'len', 'sp', 'slope', 'n', 'fam', 'depth', 'q', 'set', 'ditch', 'mm', 'c', 'cost', 'gcost'],
};

/// Properties a new item of each type must have.
const entityRequired = <String, List<String>>{
  'area': ['pts'],
  'pipe': ['pts', 'scope'],
  'sprayline': ['pts', 'outlet'],
  'tape': ['pts', 'spec'],
  'outlet': ['p', 'outlet'],
  'controlValve': ['p'],
  'waterSupply': ['p'],
  'pump': ['p'],
  'misc': ['p', 'spec'],
  'junction': ['p'],
  'pivot': ['p', 'r'],
  'controller': ['p'],
  'wire': ['pts'],
  'contour': ['pts', 'z'],
  'spotHeight': ['p', 'z'],
  'breakline': ['pts'],
  'polyline': ['pts'],
  'spline': ['pts'],
  'line': ['a', 'b'],
  'circle': ['p', 'r'],
  'arc': ['p', 'r', 's', 'w'],
  'hatch': ['pts'],
  'text': ['p', 'text'],
  'leader': ['pts', 'text'],
  'symbol': ['p'],
  'comment': ['p', 'text'],
  // 1.6.0 AGB
  'traveller': ['a', 'b'],
  'furrows': ['pts'],
};

const _pointKeys = {'p', 'a', 'b'};

/// What the model reads about the format (create_entities, update_entities):
/// every key of every creatable type (a test keeps it in step with
/// [entityKeys]), the main ones with their unit; read_manual "entities"
/// has every key with its default and valid values.
final String entityLegend =
    '''Item format = the project file: SI units (metres, m³/s, metres of water head), points [x, y] with x east and y north, angles in degrees counter-clockwise from east. Every item also takes "name" and "layer" (default: its type's own layer).
- area {pts (≥3, a closed polygon), crop (name shown in reports), ck (FAO-56 crop key "crop.…"), im ("sprinkler" | "localized" for drip and micro | "surface"), depth (net mm/day when wb is false), eff (application efficiency 0–1), wb (true: requirement from eto × kc and the soil), eto (mm/day), kc, awc (mm per m of soil), root (m), mad (0–1), psp and rsp (plant and row spacing m), wf (wetted fraction 0–1), epp (emitters per plant; 0 = the project's), soil ("soil.…"), slope (%), pd (planting "MM-DD"), gc (ground cover 0–1), ecw (water salinity dS/m), erm (effective-rain method), dep (dependable rain), pwu (hydrozone plant water use)}: an irrigated field, lawn or bed; the layout tools fill areas, the agronomy reports read them.
- pipe {pts (≥2), scope ("zone" | "mainline", required), spec (catalogue pipe id; omit and the design sizes it), auto (default true: the design may resize it; false with a spec keeps it fixed), depth (burial m)}.
- sprayline {pts, outlet (emitter id, required), nozzle (nozzle id; default the family's first), head (pressure at the emitters m), sp (emitter spacing m), off (first emitter's distance from the first point m; 0 = one spacing), arc (deg), riser (m), spec and auto (the lateral pipe, as for pipes), depth}: a lateral with emitters along it, measured from its first point; zone scope.
- tape {pts, spec (tape id, required), inlet (inlet pressure m), depth, flush (end flow m³/s for the flushing analysis), reg and submin (kept with the item, not used by the analysis)}: drip tape or dripline with an emitter every tape spacing from its first point; zone scope.
- outlet {p, outlet (emitter id, required), nozzle, head (m), arc (deg), rot (where the arc starts; it runs counter-clockwise), riser (m), scope (default "zone"; "mainline" = a valve-in-head head), zone (valve-in-head station name)}: one sprinkler; it must lie on a pipe or lateral of its scope.
- controlValve {p, spec (control valve id; without one the zone has no valve loss and no flow check), zone (zone name, unique; default "Zone n"), fixed (downstream pressure m to analyse the zone at), rot, depth}: the mainline must reach p and the zone pipes start at p.
- waterSupply {p, calc (default true: the design finds the pressure needed), dh (pressure m it gives when calc is false), mh (largest pressure m it can give; 0 = no limit), dq (design flow m³/s; 0 = unknown), mq (largest flow m³/s), wl (water level relative to the ground m: −8 in a well, +4 for a raised tank)}: the start of the mainline.
- pump {p, spec (pump id), scope (default "mainline"), speed (speed ratio, default 1), vfd (outlet pressure m a variable-speed drive keeps; 0 = fixed speed), vmin (drive's least speed ratio), meff (motor and drive efficiency 0.05–1, default 1), hm (hour meter price; the key present = fitted), rot}; misc {p, spec (device id, required: filter, meter, PRV, PSV, FCV, check, backflow, gate, air or master valve), scope (default "mainline"), set (PRV/PSV pressure m), setq (FCV flow m³/s), rot}: both in line on a pipe of their scope.
- junction {p, scope (default "zone"), z (fixed elevation m)}.
- pivot {p (centre, on the mainline), r (span pipe length m, required), kind (${PivotKind.values.map((k) => '"${k.name}"').join(' | ')}), ang (span direction deg), sector (deg), span (m between towers), travel (linear travel m), depth (gross mm per cycle), hours (per cycle), hend (end pressure m), qg and hg (end gun m³/s and m), throw (m), spec, idmm and c (span pipe), hp (pipe height m), ww (wetted width m), hm (machine losses m), imax (soil intake mm/h), zone, ssp (sprinkler spacing m), sspec and rspec (sprinkler and regulator ids), cost, tcost (per tower)}: a centre pivot or linear move.
- controller {p, st (stations), v (output volts), sim (most stations at once; 0 = from the system flows), cost}; wire {pts}: a wire route along the trenches from a controller.
- contour {pts, z}; spotHeight {p, z}; breakline {pts, zs (elevation per vertex, null = from the terrain)}.
- polyline {pts, closed}; spline {pts, closed}; line {a, b}; circle {p, r}; arc {p, r, s, w (start and sweep in radians)}; hatch {pts, ang, sp, solid}; text {p, text, h (height m), rot}; leader {pts, text, h}; symbol {p, kind (${SymbolKind.values.map((k) => k.name).join(' | ')}), size (m), rot}; comment {p, text, author, date, done}.
- traveller {a (hydrant and reel, on the mainline), b (far end of the run), w (lane spacing m; 0 = wind table), gun and noz (catalogue gun and nozzle), q (gun flow m³/s without a gun), hg (gun pressure m), dw (wetted diameter m without a gun), sector (deg), hose (m; 0 = the run), hosemm (bore mm), hd (turbine and drum loss m), zg (gun height m), depth (gross mm), v (speed m/min; 0 = from depth), setup (h), hday (h/day), wind ("none" | "light" | "moderate" | "strong"), ring (ring nozzle), mach (reel label), cost, hcost (hydrant price)}: one lane of a travelling gun, a demand on the mainline at its hydrant.
- furrows {pts (head line, first point the inlet on the mainline), right (furrows to the right), len (furrow length m), sp (spacing m), slope (m/m), n (Manning), fam (NRCS intake family in/h), depth (mm to infiltrate), q (L/s per furrow; 0 = best), set (furrows at once; 0 = all), ditch (head ditch instead of gated pipe), mm (pipe bore), c (Hazen-Williams C), cost (pipe per m), gcost (gate)}: a furrow set fed by a gated pipe, a demand on the mainline at its inlet.
read_manual "entities" (item: a type) has every key with its unit, default and values; read_manual "drawing" the connection rules.''';

/// The layer a new item of [e]'s type goes to when none is given.
String defaultLayerOf(Entity e) => switch (e) {
  PipeEntity p => p.scope == HydraulicScope.zone ? Layers.zonePipes : Layers.mainlinePipes,
  SpraylineEntity _ => Layers.spraylines,
  TapeEntity _ => Layers.tapes,
  OutletEntity _ => Layers.outlets,
  ControlValveEntity _ => Layers.controlValves,
  WaterSupplyEntity _ => Layers.waterSupply,
  PumpEntity _ => Layers.pumps,
  MiscHydraulicEntity _ => Layers.misc,
  JunctionEntity _ => Layers.junctions,
  PivotEntity _ => Layers.pivots,
  // 1.6.0 AGB
  TravellerEntity _ => Layers.travellers,
  FurrowEntity _ => Layers.surface,
  AreaEntity _ => Layers.areas,
  ControllerEntity _ => Layers.controllers,
  WireEntity _ => Layers.wires,
  ContourEntity _ => Layers.contours,
  SpotHeightEntity _ => Layers.spotHeights,
  BreaklineEntity _ => Layers.breaklines,
  TextEntity _ => Layers.text,
  LeaderEntity _ => Layers.dimensions,
  SymbolEntity _ => Layers.symbols,
  HatchEntity _ => Layers.hatches,
  CommentEntity _ => Layers.comments,
  _ => Layers.drawing,
};

/// [raw] with its points checked and turned into number lists.
Map<String, dynamic> _normalised(Map<String, dynamic> raw, String where) {
  final j = <String, dynamic>{...raw};
  for (final k in raw.keys) {
    if (k == 'pts') {
      j[k] = [
        for (final q in ToolArgs.pointsOf(raw[k], '$where.pts', max: 20000)) [q.x, q.y],
      ];
    } else if (_pointKeys.contains(k)) {
      final q = ToolArgs.pointOf(raw[k], '$where.$k');
      j[k] = [q.x, q.y];
    } else if (k == 'photo' && raw[k] != '') {
      // the model reads a note in place of the photo: writing it back would
      // lose the photo
      throw ToolInputError('$where.photo: only "" (removes the photo); add_photo_comment pins a photo the user attached.');
    }
  }
  return j;
}

/// Checks the catalogue references and the geometry of [e].
void _check(AgentToolbox b, Entity e, String where) {
  final cat = b.p.catalog;
  void pipe(String? id) {
    if (id != null && cat.pipe(id) == null) throw ToolInputError('$where: unknown pipe "$id" (search_catalog kind "pipe").');
  }

  void emitter(String id, String? nozzle) {
    final o = cat.outlet(id);
    if (o == null) throw ToolInputError('$where: unknown emitter "$id" (search_catalog kind "emitter").');
    if (nozzle != null && !o.nozzles.any((n) => n.id == nozzle)) throw ToolInputError('$where: emitter "$id" has no nozzle "$nozzle"; its nozzles: ${o.nozzles.map((n) => n.id).join(', ')}.');
  }

  final pts = e.linearPoints;
  if (pts != null && pts.length < 2) throw ToolInputError('$where: needs at least 2 points.');
  switch (e) {
    case PipeEntity x:
      pipe(x.pipeSpecId);
    case SpraylineEntity x:
      pipe(x.pipeSpecId);
      emitter(x.outletSpecId, x.nozzleId);
      if (!(x.spacing > 0)) throw ToolInputError('$where: "sp" (emitter spacing) must be above 0.');
    case TapeEntity x:
      if (cat.tape(x.tapeSpecId) == null) throw ToolInputError('$where: unknown tape "${x.tapeSpecId}" (search_catalog kind "tape").');
    case OutletEntity x:
      emitter(x.outletSpecId, x.nozzleId);
    case ControlValveEntity x:
      if (x.valveSpecId != null && cat.valve(x.valveSpecId) == null) throw ToolInputError('$where: unknown valve "${x.valveSpecId}" (search_catalog kind "valve").');
    case PumpEntity x:
      if (x.pumpSpecId != null && cat.pump(x.pumpSpecId) == null) throw ToolInputError('$where: unknown pump "${x.pumpSpecId}" (search_catalog kind "pump").');
    case MiscHydraulicEntity x:
      if (cat.valve(x.valveSpecId) == null) throw ToolInputError('$where: unknown device "${x.valveSpecId}" (search_catalog kind "valve").');
    case PivotEntity x:
      pipe(x.pipeSpecId);
      if (!(x.radiusM > 0)) throw ToolInputError('$where: "r" must be above 0.');
    case AreaEntity x:
      if (x.points.length < 3 || polygonArea(x.points).abs() < 0.01) throw ToolInputError('$where: an area needs at least 3 points enclosing a surface.');
    case HatchEntity x:
      if (x.points.length < 3) throw ToolInputError('$where: a hatch needs at least 3 points.');
    case CircleEntity x:
      if (!(x.radius > 0)) throw ToolInputError('$where: "r" must be above 0.');
    default:
      break;
  }
}

/// Builds item [index] of a create call (with a temporary id).
Entity _build(AgentToolbox b, Object? item, int index, Set<String> zones) {
  final where = 'entities[$index]';
  if (item is! Map) throw ToolInputError('$where must be an object.');
  final raw = Map<String, dynamic>.from(item);
  final type = raw['type'];
  final keys = entityKeys[type];
  if (keys == null) throw ToolInputError('$where: type "$type" cannot be created. Types: ${entityKeys.keys.join(', ')}.');
  final unknown = [
    for (final k in raw.keys)
      if (k != 'type' && k != 'name' && k != 'layer' && !keys.contains(k)) k,
  ];
  if (unknown.isNotEmpty) throw ToolInputError('$where ($type): unknown properties ${unknown.join(', ')}. Allowed: ${keys.join(', ')}, name, layer.');
  final missing = [
    for (final k in entityRequired[type] ?? const <String>[])
      if (raw[k] == null) k,
  ];
  if (missing.isNotEmpty) throw ToolInputError('$where ($type): needs ${missing.map((k) => '"$k"').join(', ')}.');
  if (raw['name'] != null && raw['name'] is! String) throw ToolInputError('$where: "name" must be a text.');
  final j = _normalised(raw, where)..['id'] = 'tmp$index';
  if (type == 'controlValve' && (j['zone'] as String? ?? '').trim().isEmpty && (j['name'] as String? ?? '').trim().isEmpty) {
    var n = b.p.uniqueZoneName(b.t('name.zone'));
    for (var k = 2; zones.contains(n); k++) {
      n = '${b.t('name.zone')} ${b.p.entities.whereType<ControlValveEntity>().length + k}';
    }
    j['zone'] = n;
  }
  final Entity e;
  try {
    e = Entity.fromJson(j);
  } catch (err) {
    throw ToolInputError('$where ($type): invalid properties (${err.runtimeType}). Check the value types against the format.');
  }
  if (raw['layer'] == null) e.layer = defaultLayerOf(e);
  if (e is ControlValveEntity) zones.add(e.zoneName);
  _check(b, e, '$where ($type)');
  return e;
}

String _kindsText(AgentToolbox b, List<Entity> es) {
  final counts = <String, int>{};
  for (final e in es) {
    final k = b.kindOf(e);
    counts[k] = (counts[k] ?? 0) + 1;
  }
  return [for (final e in counts.entries) '${e.value} × ${e.key}'].join(', ');
}

// ---------------------------------------------------------------- parameters

/// A design parameter as set_parameters, get_parameters and the manual see
/// it: its name, its key in the project file, unit, range or options and
/// what it does.
class AgentParam {
  const AgentParam(this.name, this.jsonKey, this.unit, this.get, this.set, {this.min, this.max, this.options, this.integer = false, this.note = ''});
  final String name, jsonKey, unit, note;
  final Object Function(DesignParameters p) get;
  final void Function(DesignParameters p, Object v) set;
  final double? min, max;
  final List<String>? options;
  final bool integer;
  bool get isBool => min == null && options == null && get(DesignParameters()) is bool;

  /// The allowed values, as get_parameters writes them.
  String get range => options != null ? 'one of ${options!.join(', ')}' : (min != null ? '${_plain(min!)} … ${_plain(max!)}' : 'true/false');

  static String _plain(double v) => v == v.roundToDouble() ? '${v.toInt()}' : fmt(v, 3).replaceAll(RegExp(r'0+$'), '');
}

double _d(Object v) => (v as num).toDouble();

/// Every design parameter the tools can set, in the order of the parameters
/// dialog.
final designParameters = <AgentParam>[
  AgentParam(
    'frictionMethod',
    'method',
    '',
    (p) => p.frictionMethod.name,
    (p, v) => p.frictionMethod = FrictionMethod.values.byName(v as String),
    options: [for (final m in FrictionMethod.values) m.name],
    note: 'pipe friction formula: hazenWilliams (each pipe\'s C), darcyWeisbach (roughness, viscosity from waterTempC), scobey or manning',
  ),
  AgentParam('waterTempC', 'temp', '°C', (p) => p.waterTempC, (p, v) => p.waterTempC = _d(v), min: 0, max: 60, note: 'water viscosity, and the derating of PVC and PE pressure classes in warm water'),
  AgentParam(
    'maxLateralVelocity',
    'vLat',
    'm/s',
    (p) => p.maxLateralVelocity,
    (p, v) => p.maxLateralVelocity = _d(v),
    min: 0.3,
    max: 5,
    note: 'limit in laterals: the sizing respects it, faster segments are flagged (velocity_exceeded)',
  ),
  AgentParam('maxZoneVelocity', 'vZone', 'm/s', (p) => p.maxZoneVelocity, (p, v) => p.maxZoneVelocity = _d(v), min: 0.3, max: 5, note: 'limit in zone pipes (submains, manifolds)'),
  AgentParam('maxMainlineVelocity', 'vMain', 'm/s', (p) => p.maxMainlineVelocity, (p, v) => p.maxMainlineVelocity = _d(v), min: 0.3, max: 5, note: 'limit in mainline pipes'),
  AgentParam('applyMinorLosses', 'minor', '', (p) => p.applyMinorLosses, (p, v) => p.applyMinorLosses = v as bool, note: 'add local losses (minorLossMethod) to the friction'),
  AgentParam(
    'minorLossMethod',
    'minorMethod',
    '',
    (p) => p.minorLossMethod.name,
    (p, v) => p.minorLossMethod = MinorLossMethod.values.byName(v as String),
    options: [for (final m in MinorLossMethod.values) m.name],
    note: 'percent: minorLossPct of each pipe\'s length as equivalent length; fittings: the K of the bends (from 22.5°) and tees the drawing implies',
  ),
  AgentParam('minorLossPct', 'minorPct', '% of length', (p) => p.minorLossPct, (p, v) => p.minorLossPct = _d(v), min: 0, max: 100, note: 'with minorLossMethod percent'),
  AgentParam(
    'hazenCScale',
    'cScale',
    '',
    (p) => p.hazenCScale,
    (p, v) => p.hazenCScale = _d(v),
    min: 0.3,
    max: 1.5,
    note: 'calibration: every Hazen-Williams C is multiplied by it (below 1 for aged pipes)',
  ),
  AgentParam('hazenCOffset', 'cOffset', '', (p) => p.hazenCOffset, (p, v) => p.hazenCOffset = _d(v), min: -50, max: 50, note: 'calibration: added to every C after the scale'),
  AgentParam(
    'sizingMethod',
    'sizing',
    '',
    (p) => p.sizingMethod.name,
    (p, v) => p.sizingMethod = SizingMethod.values.byName(v as String),
    options: [for (final m in SizingMethod.values) m.name],
    note: 'lp: least annual cost (pipe annuity, plus energy when tradeCapitalVsRunning) within the pressure windows and velocity limits; greedy: velocity, then the pressure window, then cost',
  ),
  AgentParam(
    'maxLateralSizes',
    'latSizes',
    'sizes',
    (p) => p.maxLateralSizes,
    (p, v) => p.maxLateralSizes = (v as num).toInt(),
    min: 1,
    max: 3,
    integer: true,
    note: 'diameters along one lateral (telescoping)',
  ),
  AgentParam('maxSubmainSizes', 'subSizes', 'sizes', (p) => p.maxSubmainSizes, (p, v) => p.maxSubmainSizes = (v as num).toInt(), min: 1, max: 5, integer: true, note: 'diameters along one zone pipe'),
  AgentParam(
    'maxMainlineSizes',
    'mainSizes',
    'sizes',
    (p) => p.maxMainlineSizes,
    (p, v) => p.maxMainlineSizes = (v as num).toInt(),
    min: 1,
    max: 5,
    integer: true,
    note: 'diameters along one mainline pipe',
  ),
  AgentParam(
    'maxZoneVariationPct',
    'zoneVar',
    '%',
    (p) => p.maxZoneVariationPct,
    (p, v) => p.maxZoneVariationPct = _d(v),
    min: 0,
    max: 60,
    note: 'above 0 it narrows every zone\'s pressure window to its mean nominal pressure ± half this (20 → ±10 %); 0 = the emitters\' own windows',
  ),
  AgentParam(
    'emittersPerPlant',
    'epp',
    '',
    (p) => p.emittersPerPlant,
    (p, v) => p.emittersPerPlant = (v as num).toInt(),
    min: 1,
    max: 20,
    integer: true,
    note: 'emitters per plant in the Keller-Karmeli emission uniformity (an area\'s epp overrides it)',
  ),
  AgentParam(
    'maxNodesPerLateral',
    'maxNodes',
    'nodes',
    (p) => p.maxNodesPerLateral,
    (p, v) => p.maxNodesPerLateral = (v as num).toInt(),
    min: 2,
    max: 500,
    integer: true,
    note: 'the emitters of a lateral are lumped into at most this many nodes (accuracy against speed)',
  ),
  AgentParam(
    'connectTolerance',
    'tol',
    'm',
    (p) => p.connectTolerance,
    (p, v) => p.connectTolerance = _d(v),
    min: 0.001,
    max: 1,
    note: 'points closer than this are one node of the network; the connect correction reaches 20 times as far (at least 2 m)',
  ),
  AgentParam('terrainDensify', 'densify', 'm', (p) => p.terrainDensify, (p, v) => p.terrainDensify = _d(v), min: 0, max: 100, note: 'spacing of the points taken along contours for the terrain model'),
  AgentParam(
    'terrainMethod',
    'terrain',
    '',
    (p) => p.terrainMethod.name,
    (p, v) => p.terrainMethod = TerrainMethod.values.byName(v as String),
    options: [for (final m in TerrainMethod.values) m.name],
    note: 'tin: triangulation of the terrain data, exact on planes; idw: inverse-distance weighting, smooth and defined outside the data too',
  ),
  AgentParam(
    'flushingVelocity',
    'flushV',
    'm/s',
    (p) => p.flushingVelocity,
    (p, v) => p.flushingVelocity = _d(v),
    min: 0,
    max: 3,
    note: 'velocity at the open end of the tapes in the flushing analysis',
  ),
  AgentParam('flushingMinEndHeadM', 'flushH', 'm', (p) => p.flushingMinEndHeadM, (p, v) => p.flushingMinEndHeadM = _d(v), min: 0, max: 50, note: 'least pressure kept at the open end while flushing'),
  AgentParam('checkSurge', 'surge', '', (p) => p.checkSurge, (p, v) => p.checkSurge = v as bool, note: 'Joukowsky surge check of every pipe\'s pressure class (surge table)'),
  AgentParam(
    'valveClosureTimeS',
    'closure',
    's',
    (p) => p.valveClosureTimeS,
    (p, v) => p.valveClosureTimeS = _d(v),
    min: 0,
    max: 600,
    note: 'closure time for the surge check; 0 = instantaneous (the worst case); solenoid valves close in about 3 s',
  ),
  AgentParam('selectFittings', 'fittings', '', (p) => p.selectFittings, (p, v) => p.selectFittings = v as bool, note: 'pick the fittings (tees, elbows, reducers, couplers) for the bill of materials'),
  AgentParam(
    'pipeStickLengthM',
    'stick',
    'm',
    (p) => p.pipeStickLengthM,
    (p, v) => p.pipeStickLengthM = _d(v),
    min: 0,
    max: 20,
    note: 'pipe length per stick for counting couplers; 0 = no couplers per stick',
  ),
  AgentParam('solenoidInrushA', 'inrushA', 'A', (p) => p.solenoidInrushA, (p, v) => p.solenoidInrushA = _d(v), min: 0.01, max: 5, note: 'valve solenoid current while it opens (wiring check)'),
  AgentParam('solenoidHoldingA', 'holdA', 'A', (p) => p.solenoidHoldingA, (p, v) => p.solenoidHoldingA = _d(v), min: 0, max: 5, note: 'valve solenoid current once open'),
  AgentParam(
    'solenoidMinVolts',
    'minV',
    'V',
    (p) => p.solenoidMinVolts,
    (p, v) => p.solenoidMinVolts = _d(v),
    min: 1,
    max: 48,
    note: 'least voltage that opens a solenoid; the wiring check compares each valve\'s voltage with it (elec_voltage)',
  ),
  AgentParam('wireSlackPct', 'slack', '%', (p) => p.wireSlackPct, (p, v) => p.wireSlackPct = _d(v), min: 0, max: 50, note: 'wire added to the routes for splices and loops'),
  AgentParam(
    'tradeCapitalVsRunning',
    'trade',
    '',
    (p) => p.tradeCapitalVsRunning,
    (p, v) => p.tradeCapitalVsRunning = v as bool,
    note: 'the sizing weighs energy against pipe cost; false = the cheapest pipes that meet the limits',
  ),
  AgentParam(
    'interestRate',
    'interest',
    'fraction/year',
    (p) => p.interestRate,
    (p, v) => p.interestRate = _d(v),
    min: 0,
    max: 0.5,
    note: 'capital recovery: costs annualised over termYears at this rate',
  ),
  AgentParam('termYears', 'term', 'years', (p) => p.termYears, (p, v) => p.termYears = (v as num).toInt(), min: 1, max: 100, integer: true, note: 'economic life for the annual capital cost'),
  AgentParam('powerCostPerKwh', 'kwh', 'currency/kWh', (p) => p.powerCostPerKwh, (p, v) => p.powerCostPerKwh = _d(v), min: 0, max: 100, note: 'energy tariff, in the project currency'),
  AgentParam(
    'pumpEfficiency',
    'eff',
    'fraction',
    (p) => p.pumpEfficiency,
    (p, v) => p.pumpEfficiency = _d(v),
    min: 0.2,
    max: 0.95,
    note: 'efficiency for the energy of a calculated supply (pumps use their own curve)',
  ),
  AgentParam(
    'hoursPerYear',
    'hours',
    'h/year',
    (p) => p.hoursPerYear,
    (p, v) => p.hoursPerYear = _d(v),
    min: 1,
    max: 8760,
    note: 'mainline and pump operating hours, shared among the system flows by their durations',
  ),
  AgentParam(
    'zoneHoursPerYear',
    'zoneHours',
    'h/year',
    (p) => p.zoneHoursPerYear,
    (p, v) => p.zoneHoursPerYear = _d(v),
    min: 1,
    max: 8760,
    note: 'hours each zone runs a year: the weight of its inlet pressure in the zone sizing',
  ),
  AgentParam(
    'mainsHz',
    'hz',
    'Hz',
    (p) => p.mainsHz,
    (p, v) => p.mainsHz = _d(v),
    min: 50,
    max: 60,
    note: 'mains frequency: fixed-speed pumps rated at another frequency turn proportionally faster or slower',
  ),
];

/// Keys of the parameters in the project file that set_parameters does not
/// change, and where the user changes them.
const otherParameterKeys = <String, String>{
  'units': 'display units of the reports and labels: set_setting units.system, units.length, units.flow, units.pressure, units.diameter (Design → Units); tool inputs stay SI',
  'currency': 'symbol shown next to prices (Design → Parameters)',
  'currencyCode': 'ISO 4217 code of every price; the user changes it in Design → Parameters, which converts the catalogue prices',
};

String parametersText(AgentToolbox b) {
  final p = b.p.params;
  return [
    'Design parameters (name = value; set_parameters takes these names). Currency ${p.currency}; display units: flow ${b.u.flowLabel}, pressure ${b.u.pressureLabel}.',
    for (final x in designParameters) '${x.name} = ${x.get(p)}${x.unit.isEmpty ? '' : ' ${x.unit}'} (${x.range})${x.note.isEmpty ? '' : ' — ${x.note}'}',
  ].join('\n');
}

// ---------------------------------------------------------------- catalogue

Object? _pick(Map<String, dynamic> m, String k) => m[k];

double _num(Map<String, dynamic> m, String k, String where, {double? def, double min = -1e12, double max = 1e12}) {
  final v = _pick(m, k);
  if (v == null) {
    if (def != null) return def;
    throw ToolInputError('$where: needs "$k".');
  }
  if (v is! num || !v.isFinite) throw ToolInputError('$where: "$k" must be a number.');
  final d = v.toDouble();
  if (d < min || d > max) throw ToolInputError('$where: "$k" = $d is outside $min … $max.');
  return d;
}

String _text(Map<String, dynamic> m, String k, String where, {String? def}) {
  final v = m[k];
  if (v == null) {
    if (def != null) return def;
    throw ToolInputError('$where: needs "$k".');
  }
  if (v is! String || v.trim().isEmpty) throw ToolInputError('$where: "$k" must be a non-empty text.');
  return v.trim();
}

T _enum<T extends Enum>(List<T> values, Map<String, dynamic> m, String k, String where, {T? def}) {
  final v = m[k];
  if (v == null && def != null) return def;
  for (final x in values) {
    if (x.name == v) return x;
  }
  throw ToolInputError('$where: "$k" must be one of ${values.map((x) => x.name).join(', ')}.');
}

const _catalogKinds = ['pipe', 'emitter', 'tape', 'valve', 'pump', 'wire'];

/// The catalogue fields edit_catalog takes, with their defaults.
final String catalogLegend =
    '''Fields by kind (* = required to add; the unit is in the name; defaults in brackets):
- pipe {name*, inner_diameter_mm* (2–3000), pressure_rating_m* (class as metres of head, e.g. PN 6 = 60), nominal_mm [the inner Ø], material (${PipeMaterial.values.map((m) => m.name).join(' | ')}) [pvc], hazen_c (40–160) [150], roughness_mm [0.0015], wall_mm [2], cost_per_m [0], usage (list of ${PipeUsage.values.map((u) => '"${u.name}"').join(', ')}) [zone and mainline], supplier, code}
- emitter {name*, kind* (${OutletKind.values.map((k) => k.name).join(' | ')}), nozzles* [{name*, flow_lph*, head_m* (the pressure of that flow), exponent (flow ∝ pressure^x: 0.5 orifice, about 0 pressure compensating) [0.5], min_head_m [0.6 × head_m], max_head_m [1.6 × head_m], radius_m (wetted radius at head_m) [0], arc_deg [360], id [<emitter id>_n1, _n2…]}], cost [0], inlet_mm [20], riser_m [0], supplier, code}
- tape {name*, inner_diameter_mm* (4–60), emitter_spacing_m* (0.05–5), emitter_flow_lph* (at head_m), head_m [10], exponent [0.5], min_head_m [4], max_head_m [15], pressure_rating_m [25], nominal_mm [16], cost_per_m [0], supplier, code}
- valve {name*, kind* (${ValveKind.values.map((k) => k.name).join(' | ')}), size_mm* (5–2000), max_flow_m3h*, min_flow_m3h [0], loss_m (head loss at max_flow_m3h) [K = 5 for the size], setting_m (PRV/PSV) [0], cost [0], supplier, code}
- pump {name*, curve* ([[flow_m3h, head_m], …] at least 3 points, flow rising), efficiency (0.2–0.95) [0.7], power_kw [0], submersible [false], rated_hz (curve frequency; 0 = the mains) [0], min_flow_m3h and max_flow_m3h [the curve's ends], cost [0], supplier, code}
- wire {name*, section_mm2* (0.2–300), ohm_per_km [copper for the section], cost_per_m [0], supplier, code}''';

PipeSpec _pipeOf(String id, Map<String, dynamic> m, String w, {PipeSpec? base}) {
  final usage = m['usage'];
  return PipeSpec(
    id: id,
    name: m['name'] == null && base != null ? base.name : _text(m, 'name', w),
    innerDiameterMm: _num(m, 'inner_diameter_mm', w, def: base?.innerDiameterMm, min: 2, max: 3000),
    nominalMm: _num(m, 'nominal_mm', w, def: base?.nominalMm ?? _num(m, 'inner_diameter_mm', w, def: base?.innerDiameterMm, min: 2, max: 3000), min: 2, max: 3000),
    pressureRatingM: _num(m, 'pressure_rating_m', w, def: base?.pressureRatingM, min: 1, max: 1000),
    material: _enum(PipeMaterial.values, m, 'material', w, def: base?.material ?? PipeMaterial.pvc),
    hazenC: _num(m, 'hazen_c', w, def: base?.hazenC ?? 150, min: 40, max: 160),
    roughnessMm: _num(m, 'roughness_mm', w, def: base?.roughnessMm ?? 0.0015, min: 0, max: 10),
    wallThicknessMm: _num(m, 'wall_mm', w, def: base?.wallThicknessMm ?? 2, min: 0.1, max: 100),
    costPerM: _num(m, 'cost_per_m', w, def: base?.costPerM ?? 0, min: 0),
    usage: usage == null
        ? (base?.usage ?? {PipeUsage.zone, PipeUsage.mainline})
        : {
            for (final u in (usage is List ? usage : const [])) _enum(PipeUsage.values, {'u': u}, 'u', '$w.usage'),
          },
    enabled: base?.enabled ?? true,
    supplier: m['supplier'] as String? ?? base?.supplier ?? '',
    code: m['code'] as String? ?? base?.code ?? '',
  );
}

NozzleSpec _nozzleOf(String id, Object? raw, String w) {
  if (raw is! Map) throw ToolInputError('$w must be an object.');
  final m = Map<String, dynamic>.from(raw);
  final head = _num(m, 'head_m', w, min: 0.1, max: 200);
  final flow = _num(m, 'flow_lph', w, min: 0.01, max: 1e6) * m3sPerLph;
  final minH = _num(m, 'min_head_m', w, def: head * 0.6, min: 0, max: 200), maxH = _num(m, 'max_head_m', w, def: head * 1.6, min: 0, max: 300);
  if (minH >= maxH) throw ToolInputError('$w: min_head_m must be below max_head_m.');
  return NozzleSpec(
    id: m['id'] is String && (m['id'] as String).trim().isNotEmpty ? (m['id'] as String).trim() : id,
    name: _text(m, 'name', w),
    curve: EmitterCurve.fromNominal(flow: flow, head: head, x: _num(m, 'exponent', w, def: 0.5, min: 0, max: 1), radius: _num(m, 'radius_m', w, def: 0, min: 0, max: 200)),
    arcDeg: _num(m, 'arc_deg', w, def: 360, min: 1, max: 360),
    minHeadM: minH,
    maxHeadM: maxH,
    defaultHeadM: head,
  );
}

OutletSpec _emitterOf(String id, Map<String, dynamic> m, String w, {OutletSpec? base}) {
  final nz = m['nozzles'];
  if (nz == null && base == null) throw ToolInputError('$w: needs "nozzles".');
  if (nz != null && (nz is! List || nz.isEmpty)) throw ToolInputError('$w: "nozzles" must be a non-empty list.');
  return OutletSpec(
    id: id,
    name: m['name'] == null && base != null ? base.name : _text(m, 'name', w),
    kind: _enum(OutletKind.values, m, 'kind', w, def: base?.kind),
    nozzles: nz == null ? base!.nozzles : [for (var i = 0; i < (nz as List).length; i++) _nozzleOf('${id}_n${i + 1}', nz[i], '$w.nozzles[$i]')],
    cost: _num(m, 'cost', w, def: base?.cost ?? 0, min: 0),
    inletMm: _num(m, 'inlet_mm', w, def: base?.inletMm ?? 20, min: 1, max: 500),
    riserHeightM: _num(m, 'riser_m', w, def: base?.riserHeightM ?? 0, min: 0, max: 20),
    enabled: base?.enabled ?? true,
    supplier: m['supplier'] as String? ?? base?.supplier ?? '',
    code: m['code'] as String? ?? base?.code ?? '',
  );
}

TapeSpec _tapeOf(String id, Map<String, dynamic> m, String w, {TapeSpec? base}) {
  final head = _num(m, 'head_m', w, def: base?.defaultInletHeadM ?? 10, min: 0.5, max: 100);
  final flow = m['emitter_flow_lph'] == null && base != null ? null : _num(m, 'emitter_flow_lph', w, min: 0.05, max: 100);
  final x = _num(m, 'exponent', w, def: base?.emitter.x ?? 0.5, min: 0, max: 1);
  return TapeSpec(
    id: id,
    name: m['name'] == null && base != null ? base.name : _text(m, 'name', w),
    innerDiameterMm: _num(m, 'inner_diameter_mm', w, def: base?.innerDiameterMm, min: 4, max: 60),
    emitterSpacingM: _num(m, 'emitter_spacing_m', w, def: base?.emitterSpacingM, min: 0.05, max: 5),
    emitter: flow == null ? base!.emitter : EmitterCurve.fromNominal(flow: flow * m3sPerLph, head: head, x: x),
    nominalMm: _num(m, 'nominal_mm', w, def: base?.nominalMm ?? 16, min: 4, max: 63),
    minHeadM: _num(m, 'min_head_m', w, def: base?.minHeadM ?? 4, min: 0, max: 100),
    maxHeadM: _num(m, 'max_head_m', w, def: base?.maxHeadM ?? 15, min: 0.5, max: 200),
    defaultInletHeadM: head,
    pressureRatingM: _num(m, 'pressure_rating_m', w, def: base?.pressureRatingM ?? 25, min: 1, max: 300),
    costPerM: _num(m, 'cost_per_m', w, def: base?.costPerM ?? 0, min: 0),
    enabled: base?.enabled ?? true,
    supplier: m['supplier'] as String? ?? base?.supplier ?? '',
    code: m['code'] as String? ?? base?.code ?? '',
  );
}

ValveSpec _valveOf(String id, Map<String, dynamic> m, String w, {ValveSpec? base}) {
  final size = _num(m, 'size_mm', w, def: base?.sizeMm, min: 5, max: 2000);
  final maxQ = m['max_flow_m3h'] == null && base != null ? base.maxFlow : _num(m, 'max_flow_m3h', w, min: 0.001, max: 1e5) * m3sPerM3h;
  final loss = m['loss_m'] == null ? (base?.loss ?? DeviceLossCurve.fromK(5, size / 1000)) : DeviceLossCurve(k: _num(m, 'loss_m', w, min: 0, max: 200) / (maxQ * maxQ), n: 2);
  return ValveSpec(
    id: id,
    name: m['name'] == null && base != null ? base.name : _text(m, 'name', w),
    kind: _enum(ValveKind.values, m, 'kind', w, def: base?.kind),
    sizeMm: size,
    loss: loss,
    minFlow: _num(m, 'min_flow_m3h', w, def: (base?.minFlow ?? 0) / m3sPerM3h, min: 0) * m3sPerM3h,
    maxFlow: maxQ,
    cost: _num(m, 'cost', w, def: base?.cost ?? 0, min: 0),
    defaultSettingM: _num(m, 'setting_m', w, def: base?.defaultSettingM ?? 0, min: 0, max: 300),
    enabled: base?.enabled ?? true,
    supplier: m['supplier'] as String? ?? base?.supplier ?? '',
    code: m['code'] as String? ?? base?.code ?? '',
  );
}

PumpSpec _pumpOf(String id, Map<String, dynamic> m, String w, {PumpSpec? base}) {
  List<(double, double)> pts;
  final raw = m['curve'];
  if (raw == null && base != null) {
    pts = base.points;
  } else {
    if (raw is! List || raw.length < 3) throw ToolInputError('$w: "curve" needs at least 3 points [flow_m3h, head_m].');
    pts = [
      for (var i = 0; i < raw.length; i++)
        () {
          final q = ToolArgs.pointOf(raw[i], '$w.curve[$i]');
          return (q.x * m3sPerM3h, q.y);
        }(),
    ];
    for (var i = 1; i < pts.length; i++) {
      if (!(pts[i].$1 > pts[i - 1].$1)) throw ToolInputError('$w: the curve flows must rise point by point.');
    }
    if (pts.any((x) => x.$1 < 0 || x.$2 <= 0)) throw ToolInputError('$w: curve flows ≥ 0 and heads > 0.');
  }
  return PumpSpec(
    id: id,
    name: m['name'] == null && base != null ? base.name : _text(m, 'name', w),
    points: pts,
    efficiency: _num(m, 'efficiency', w, def: base?.efficiency ?? 0.7, min: 0.2, max: 0.95),
    minFlow: _num(m, 'min_flow_m3h', w, def: (base?.minFlow ?? pts.first.$1) / m3sPerM3h, min: 0) * m3sPerM3h,
    maxFlow: _num(m, 'max_flow_m3h', w, def: (base?.maxFlow ?? pts.last.$1) / m3sPerM3h, min: 0) * m3sPerM3h,
    cost: _num(m, 'cost', w, def: base?.cost ?? 0, min: 0),
    powerKw: _num(m, 'power_kw', w, def: base?.powerKw ?? 0, min: 0, max: 5000),
    submersible: m['submersible'] as bool? ?? base?.submersible ?? false,
    ratedHz: _num(m, 'rated_hz', w, def: base?.ratedHz ?? 0, min: 0, max: 60),
    enabled: base?.enabled ?? true,
    supplier: m['supplier'] as String? ?? base?.supplier ?? '',
    code: m['code'] as String? ?? base?.code ?? '',
  );
}

WireSpec _wireOf(String id, Map<String, dynamic> m, String w, {WireSpec? base}) {
  final mm2 = _num(m, 'section_mm2', w, def: base?.sectionMm2, min: 0.2, max: 300);
  return WireSpec(
    id: id,
    name: m['name'] == null && base != null ? base.name : _text(m, 'name', w),
    sectionMm2: mm2,
    ohmPerKm: _num(m, 'ohm_per_km', w, def: base?.ohmPerKm ?? copperOhmPerKm(mm2), min: 0.01, max: 200),
    costPerM: _num(m, 'cost_per_m', w, def: base?.costPerM ?? 0, min: 0),
    enabled: base?.enabled ?? true,
    supplier: m['supplier'] as String? ?? base?.supplier ?? '',
    code: m['code'] as String? ?? base?.code ?? '',
  );
}

/// The list of [kind] in [cat] (typed as dynamic: the specs share no base).
List<dynamic> _listOf(Catalog cat, String kind) => switch (kind) {
  'pipe' => cat.pipes,
  'emitter' => cat.outlets,
  'tape' => cat.tapes,
  'valve' => cat.valves,
  'pump' => cat.pumps,
  _ => cat.wires,
};

/// Items of the drawing that refer to catalogue item [id].
int _uses(Project p, String id) => p.entities
    .where(
      (e) => switch (e) {
        PipeEntity x => x.pipeSpecId == id,
        SpraylineEntity x => x.pipeSpecId == id || x.outletSpecId == id,
        TapeEntity x => x.tapeSpecId == id,
        OutletEntity x => x.outletSpecId == id,
        ControlValveEntity x => x.valveSpecId == id,
        PumpEntity x => x.pumpSpecId == id,
        MiscHydraulicEntity x => x.valveSpecId == id,
        PivotEntity x => x.pipeSpecId == id || x.sprinklerSpecId == id || x.regulatorSpecId == id,
        _ => false,
      },
    )
    .length;

// ---------------------------------------------------------------- tools

List<AgentTool> editTools(AgentToolbox b) {
  final c = b.c;
  final t = b.t;
  return [
    FnTool(
      name: 'create_entities',
      effect: ToolEffect.write,
      description:
          'Adds items to the drawing in one undo step and returns one line per new item: id | type | name | details. Use it for what the automations do not draw (supplies, mainlines, devices, valves, single heads, areas, terrain points, notes) and put all the items of a step in one call. Every item is checked first (type, keys, required keys, catalogue ids from search_catalog, geometry): one bad item refuses the whole call with the reason and nothing is added. Items join the network only where their points coincide within connectTolerance (read_manual "drawing"). The design results are discarded: run the design afterwards.\n$entityLegend',
      inputSchema: obj(
        {
          'entities': arr(
            {
              'type': 'object',
              'properties': {
                'type': str('Item type; the other keys follow the item format above.', [...entityKeys.keys]),
              },
              'required': ['type'],
            },
            'Items to add, 1 to 500.',
            500,
          ),
        },
        required: ['entities'],
      ),
      summary: (i) {
        try {
          final zones = <String>{};
          final es = [for (var k = 0; k < (i['entities'] as List).length; k++) _build(b, (i['entities'] as List)[k], k, zones)];
          return t('ai.do.create', {'n': '${es.length}', 'what': _kindsText(b, es)});
        } catch (_) {
          return t('ai.tool.create');
        }
      },
      handler: (i) async {
        final list = i['entities'] as List;
        if (list.isEmpty) throw ToolInputError('"entities" is empty.');
        final zones = <String>{};
        final built = [for (var k = 0; k < list.length; k++) _build(b, list[k], k, zones)];
        final made = b.change('create_entities', () {
          final p = b.p;
          final out = [for (final e in built) e.clone(newId: p.newId())];
          for (final e in out) {
            p.layerNamed(e.layer);
          }
          p.entities.addAll(out);
          return out;
        });
        return ToolOutput('Created ${made.length} items:\n${[for (final e in made) '${e.id} | ${e.type.name} | ${b.nameOf(e)} | ${b.brief(e)}'].join('\n')}');
      },
    ),
    FnTool(
      name: 'update_entities',
      effect: ToolEffect.write,
      description: 'Changes properties of existing items in one undo step and returns their new details. "set" takes the keys of the item format (create_entities; get_entity shows an item\'s current keys), geometry too ("pts", "p"); null clears an optional key, e.g. {"spec": null} lets the design size a pipe again. Each item is rebuilt from its stored keys plus the changes and checked like a new one; one bad update refuses the whole call. Items on locked layers are refused (edit_layers unlock). The layer does not follow a change of scope: set "layer" as well. The design results are discarded.',
      inputSchema: obj(
        {
          'updates': arr(
            obj(
              {
                'id': str('Id or name of the item.'),
                'set': {'type': 'object', 'description': 'Keys to change and their new values, e.g. {"spec": "pvc75", "auto": false}.'},
              },
              required: ['id', 'set'],
            ),
            'Items to change, 1 to 300, each at most once.',
            300,
          ),
        },
        required: ['updates'],
      ),
      summary: (i) {
        final ups = i['updates'] as List? ?? const [];
        try {
          final names = [
            for (final u in ups.take(4))
              () {
                final e = b.find('${(u as Map)['id']}');
                return '${b.kindOf(e)} «${b.nameOf(e)}» (${((u['set'] as Map?)?.keys ?? const []).join(', ')})';
              }(),
          ];
          return t('ai.do.update', {'n': '${ups.length}', 'what': '${names.join('; ')}${ups.length > 4 ? '…' : ''}'});
        } catch (_) {
          return t('ai.tool.update');
        }
      },
      handler: (i) async {
        final ups = i['updates'] as List;
        final plan = <(Entity, Entity)>[];
        final seen = <String>{};
        for (var k = 0; k < ups.length; k++) {
          final u = Map<String, dynamic>.from(ups[k] as Map);
          final e = b.find('${u['id']}');
          final where = 'updates[$k] (${e.id})';
          if (!seen.add(e.id)) throw ToolInputError('$where: the same item twice.');
          if (b.p.isLocked(e.layer)) throw ToolInputError('$where: its layer "${e.layer}" is locked.');
          final set = u['set'];
          if (set is! Map || set.isEmpty) throw ToolInputError('$where: "set" must be a non-empty object.');
          final keys = entityKeys[e.type.name];
          if (keys == null) throw ToolInputError('$where: ${e.type.name} items cannot be changed here.');
          final bad = [
            for (final key in set.keys)
              if (key != 'name' && key != 'layer' && !keys.contains(key)) key,
          ];
          if (bad.isNotEmpty) throw ToolInputError('$where: unknown properties ${bad.join(', ')}. Allowed: ${keys.join(', ')}, name, layer.');
          final j = {...e.toJson(), ..._normalised(Map<String, dynamic>.from(set), where), 'id': e.id, 'type': e.type.name};
          final Entity ne;
          try {
            ne = Entity.fromJson(j);
          } catch (err) {
            throw ToolInputError('$where: invalid properties (${err.runtimeType}).');
          }
          _check(b, ne, where);
          plan.add((e, ne));
        }
        b.change('update_entities', () {
          final p = b.p;
          for (final (old, ne) in plan) {
            final idx = p.entities.indexWhere((x) => x.id == old.id);
            if (idx >= 0) p.entities[idx] = ne;
            p.layerNamed(ne.layer);
          }
          return plan.length;
        });
        return ToolOutput('Updated ${plan.length} items:\n${[for (final (_, e) in plan) '${e.id} | ${b.brief(e)}'].join('\n')}');
      },
    ),
    FnTool(
      name: 'delete_entities',
      effect: ToolEffect.write,
      description:
          'Deletes items in one undo step; deleted valves and pivots also leave the system flows. Deleting more than ${b.largeDelete} items in a task (all its deletions counted together, by any tool) is always confirmed by the user, whatever the mode. Items on locked layers are refused (nothing is deleted then). The design results are discarded. Returns the count by kind.',
      inputSchema: obj({'ids': arr(str(), 'Ids or names of the items, at most 5000.', 5000)}, required: ['ids']),
      // counted over the task: five calls of 20 are confirmed like one of 100
      confirm: (i) => b.removedThisTask + ((i['ids'] as List?)?.length ?? 0) > b.largeDelete,
      summary: (i) {
        try {
          final es = b.findAll([for (final x in i['ids'] as List) '$x']);
          return t('ai.do.delete', {'n': '${es.length}', 'what': _kindsText(b, es)});
        } catch (_) {
          return t('ai.tool.delete');
        }
      },
      handler: (i) async {
        final es = b.findAll(ToolArgs(i).strings('ids', required: true));
        final locked = [
          for (final e in es)
            if (b.p.isLocked(e.layer)) e.id,
        ];
        if (locked.isNotEmpty) throw ToolInputError('Items on locked layers: ${locked.take(10).join(', ')}. Unlock the layer first (edit_layers) or leave them.');
        final ids = {for (final e in es) e.id};
        final n = b.change('delete_entities', () {
          final p = b.p;
          p.entities.removeWhere((e) => ids.contains(e.id));
          for (final f in p.systemFlows) {
            f.valveIds.removeWhere(ids.contains);
          }
          c.selection.removeAll(ids);
          return ids.length;
        });
        return ToolOutput('Deleted $n items (${_kindsText(b, es)}).');
      },
    ),
    FnTool(
      name: 'transform_entities',
      effect: ToolEffect.write,
      description: 'Moves, copies, rotates, scales, mirrors or arrays items (ids, or selected true for the current selection) in one undo step; returns how many items it handled and the ids of new copies. move/copy: dx, dy. rotate: angle_deg (counter-clockwise) about center. scale: factor about center. mirror: the line axis_from → axis_to. keep_original makes rotate, scale and mirror work on a copy. array: a grid of rows × cols cells col_spacing and row_spacing apart (the original is the first cell; rows run along angle_deg), or with polar true, count items (the original included) spread over total_angle_deg about center. center defaults to the centre of the items. Only the given items move, so a pipe end that was joined to an item left in place is no longer joined; items on locked layers stay. The items (or the new copies) become the selection. The design results are discarded.',
      inputSchema: obj(
        {
          'ids': arr(str(), 'Ids or names of the items.'),
          'selected': bool_('Work on the current selection instead of "ids" (e.g. the items of an import, which come in selected).'),
          'operation': str(null, ['move', 'copy', 'rotate', 'scale', 'mirror', 'array']),
          'dx': num_('move/copy: offset east (m), default 0.'),
          'dy': num_('move/copy: offset north (m), default 0.'),
          'center': {...point, 'description': '[x, y] in metres: centre of rotate, scale and polar arrays (default: the centre of the items).'},
          'angle_deg': num_('rotate: angle (degrees counter-clockwise, required); array: direction of the rows (default 0).'),
          'factor': num_('scale: factor, 0.001–1000 (required).'),
          'axis_from': {...point, 'description': 'mirror: first point of the mirror line [x, y] (required).'},
          'axis_to': {...point, 'description': 'mirror: second point of the mirror line [x, y] (required).'},
          'keep_original': bool_('rotate/scale/mirror a copy and keep the original (default false).'),
          'rows': int_('array: rows, 1–500 (default 1).'),
          'cols': int_('array: columns, 1–500 (default 1).'),
          'row_spacing': num_('array: distance between rows (m, default 5).'),
          'col_spacing': num_('array: distance between columns (m, default 5).'),
          'polar': bool_('array: copies around center instead of rows and columns.'),
          'count': int_('polar array: items including the original, 2–720 (default 6).'),
          'total_angle_deg': num_('polar array: angle covered (default 360).'),
        },
        required: ['operation'],
      ),
      summary: (i) => t('ai.do.transform', {'op': '${i['operation']}', 'n': '${i['selected'] == true ? c.selection.length : ((i['ids'] as List?)?.length ?? 0)}'}),
      // the selection as ids when the call is planned: what the card names is what moves
      binder: (i) => cadBindSelected(b, i),
      handler: (i) async {
        final a = ToolArgs(i);
        final selected = a.flag('selected') ?? false;
        if (selected && c.selection.isEmpty) throw ToolInputError('Nothing is selected: give "ids".');
        if (!selected && !a.has('ids')) throw ToolInputError('Give "ids" (or "selected": true for the current selection).');
        final es = selected ? b.findAll([...c.selection]) : b.findAll(a.strings('ids', required: true));
        if (c.busy) throw ToolInputError('A design is running; wait until it finishes.');
        final before = {for (final e in b.p.entities) e.id};
        c.select(es.map((e) => e.id));
        if (c.editableSelection.isEmpty) throw ToolInputError('Every item is on a locked layer.');
        final centre = a.point('center') ?? es.fold(Bounds.empty, (Bounds x, e) => x.union(e.bounds)).center;
        final keep = a.flag('keep_original') ?? false;
        var n = 0;
        switch (a.str('operation', required: true)) {
          case 'move':
            c.moveSelected(Pt(a.number('dx') ?? 0, a.number('dy') ?? 0));
            n = c.editableSelection.length;
          case 'copy':
            n = c.transformSelected(Affine.translation(Pt(a.number('dx') ?? 0, a.number('dy') ?? 0)), copy: true, label: 'hist.aiTool|transform_entities');
          case 'rotate':
            n = c.rotateSelected(centre, degToRad(a.number('angle_deg', required: true)!), copy: keep);
          case 'scale':
            n = c.scaleSelected(centre, a.number('factor', min: 0.001, max: 1000, required: true)!, copy: keep);
          case 'mirror':
            n = c.mirrorSelected(a.point('axis_from', required: true)!, a.point('axis_to', required: true)!, keepSource: keep);
          case 'array':
            final polar = a.flag('polar') ?? false;
            n = c.arraySelected(
              ArrayOptions(
                polar: polar,
                rows: a.integer('rows', min: 1, max: 500) ?? 1,
                cols: a.integer('cols', min: 1, max: 500) ?? 1,
                dx: a.number('col_spacing') ?? 5,
                dy: a.number('row_spacing') ?? 5,
                angleDeg: a.number('angle_deg') ?? 0,
                count: a.integer('count', min: 2, max: 720) ?? 6,
                center: centre,
                totalAngleDeg: a.number('total_angle_deg') ?? 360,
              ),
            );
          default:
            throw ToolInputError('Unknown operation.');
        }
        final added = [
          for (final e in b.p.entities)
            if (!before.contains(e.id)) e.id,
        ];
        return ToolOutput('${a.str('operation')}: $n items${added.isEmpty ? '' : '; new copies: ${added.take(200).join(', ')}${added.length > 200 ? '…' : ''}'}.');
      },
    ),
    FnTool(
      name: 'set_parameters',
      effect: ToolEffect.write,
      description: 'Changes design parameters in one undo step and returns each old → new value. Names, units and allowed values as get_parameters lists them (read_manual "parameters" says what each does); every value is checked first and one bad value refuses the call. The design results are discarded: run the design again.',
      inputSchema: obj(
        {
          'values': {'type': 'object', 'description': 'Parameter name → new value, e.g. {"maxZoneVelocity": 1.8, "sizingMethod": "lp"}.'},
        },
        required: ['values'],
      ),
      summary: (i) => t('ai.do.params', {'what': ((i['values'] as Map?) ?? const {}).entries.map((e) => '${e.key} = ${e.value}').join(', ')}),
      handler: (i) async {
        final values = i['values'];
        if (values is! Map || values.isEmpty) throw ToolInputError('"values" must be a non-empty object.');
        final byName = {for (final x in designParameters) x.name: x};
        final plan = <(AgentParam, Object)>[];
        for (final e in values.entries) {
          final x = byName[e.key];
          if (x == null) throw ToolInputError('Unknown parameter "${e.key}". Known: ${byName.keys.join(', ')}.');
          final v = e.value;
          if (x.options != null) {
            if (v is! String || !x.options!.contains(v)) throw ToolInputError('${x.name} must be one of ${x.options!.join(', ')}.');
          } else if (x.isBool) {
            if (v is! bool) throw ToolInputError('${x.name} must be true or false.');
          } else {
            if (v is! num || !v.isFinite || v < x.min! || v > x.max!) throw ToolInputError('${x.name} must be a number in ${fmt(x.min!, 3)} … ${fmt(x.max!, 3)}.');
            if (x.integer && v != v.roundToDouble()) throw ToolInputError('${x.name} must be a whole number.');
          }
          plan.add((x, v as Object));
        }
        final p = b.p.params;
        final before = [for (final (x, _) in plan) '${x.get(p)}'];
        b.change('set_parameters', () {
          for (final (x, v) in plan) {
            x.set(b.p.params, v);
          }
          return plan.length;
        });
        return ToolOutput('Changed: ${[for (var k = 0; k < plan.length; k++) '${plan[k].$1.name} ${before[k]} → ${plan[k].$1.get(b.p.params)}'].join('; ')}. Results discarded: run the design again.');
      },
    ),
    FnTool(
      name: 'edit_catalog',
      effect: ToolEffect.write,
      description:
          'Adds, updates, enables, disables or removes catalogue items in one undo step, e.g. the models of a manufacturer data sheet the user attached. Every value is checked before anything changes; flows and pressures are in the units the field names say. "add" keeps the id you give when it is free and made of letters, digits, _ or - (else one is made, e.g. pipe3, out2); "update" changes only the fields given. The design only uses enabled items. Removing an item the drawing uses is refused: disable it instead, or change those items first. Returns the id.\n$catalogLegend',
      inputSchema: obj(
        {
          'action': str(null, ['add', 'update', 'enable', 'disable', 'remove']),
          'kind': str(null, _catalogKinds),
          'id': str('Item id: required for update, enable, disable and remove; optional for add.'),
          'item': {'type': 'object', 'description': 'Fields of the item as listed below (add: the required ones; update: only those to change).'},
        },
        required: ['action', 'kind'],
      ),
      summary: (i) => t('ai.do.catalog', {'op': '${i['action']}', 'kind': '${i['kind']}', 'n': '${(i['item'] as Map?)?['name'] ?? i['id'] ?? ''}'}),
      handler: (i) async {
        final a = ToolArgs(i);
        final action = a.str('action', required: true)!;
        final kind = a.str('kind', required: true)!;
        final cat = b.p.catalog;
        final list = _listOf(cat, kind);
        final item = i['item'] is Map ? Map<String, dynamic>.from(i['item'] as Map) : <String, dynamic>{};
        final w = 'item';
        dynamic existing;
        final id = a.str('id');
        if (action != 'add') {
          if (id == null) throw ToolInputError('"id" is needed to $action.');
          existing = list.where((x) => x.id == id).firstOrNull;
          if (existing == null) throw ToolInputError('No $kind "$id" (search_catalog).');
        }
        switch (action) {
          case 'add' || 'update':
            if (action == 'add' && item.isEmpty) throw ToolInputError('"item" is needed to add.');
            var newId = id ?? '';
            if (action == 'add') {
              final valid = RegExp(r'^[a-zA-Z0-9_\-]{1,40}$');
              final taken = list.any((x) => x.id == newId);
              if (newId.isEmpty || !valid.hasMatch(newId) || taken) newId = cat.newId(kind == 'emitter' ? 'out' : kind);
            }
            final spec = switch (kind) {
              'pipe' => _pipeOf(newId, item, w, base: existing as PipeSpec?),
              'emitter' => _emitterOf(newId, item, w, base: existing as OutletSpec?),
              'tape' => _tapeOf(newId, item, w, base: existing as TapeSpec?),
              'valve' => _valveOf(newId, item, w, base: existing as ValveSpec?),
              'pump' => _pumpOf(newId, item, w, base: existing as PumpSpec?),
              _ => _wireOf(newId, item, w, base: existing as WireSpec?),
            };
            b.change('edit_catalog', () {
              final l = _listOf(b.p.catalog, kind);
              final at = l.indexWhere((x) => x.id == newId);
              if (at >= 0) {
                l[at] = spec;
              } else {
                l.add(spec);
              }
              return 1;
            });
            return ToolOutput('${action == 'add' ? 'Added' : 'Updated'} $kind "$newId" (${(spec as dynamic).name}).');
          case 'enable' || 'disable':
            b.change('edit_catalog', () {
              existing.enabled = action == 'enable';
              return 1;
            });
            return ToolOutput('${action == 'enable' ? 'Enabled' : 'Disabled'} $kind "$id".');
          default:
            final used = _uses(b.p, id!);
            if (used > 0) throw ToolInputError('$kind "$id" is used by $used items of the drawing: disable it instead, or change those items first.');
            b.change('edit_catalog', () {
              _listOf(b.p.catalog, kind).removeWhere((x) => x.id == id);
              return 1;
            });
            return ToolOutput('Removed $kind "$id".');
        }
      },
    ),
    FnTool(
      name: 'set_system_flows',
      effect: ToolEffect.write,
      description: 'Sets the system flows (shifts): which zones, pivots and valve-in-head stations run together, from what hour and for how long. The mainline and the supply are designed for every flow, so the flows decide the pump duty. Modes: "auto" packs the demands, largest first, into flows whose total stays within max_flow_m3h, else within the sum of the supplies\' design flows (dq); when neither is known there is no limit and every zone lands in one flow, so for a pumped or calculated supply give max_flow_m3h (the well, pump or connection capacity) or max_valves. A demand alone above the limit gets a flow of its own (the design then reports supply_flow_exceeded). "all_together" one flow with everything; "one_at_a_time" one flow per demand, back to back; "replace" the flows given; "clear" none (the design then runs everything at once). One undo step; the design results are discarded. Returns the flows with their demands, start and duration.',
      inputSchema: obj(
        {
          'mode': str(null, ['auto', 'all_together', 'one_at_a_time', 'replace', 'clear']),
          'flows': arr(
            obj(
              {
                'name': str('Name of the flow, e.g. "Shift 1".'),
                'demands': arr(str(), 'Zone valves and pivots by id or zone name; valve-in-head stations as "vih:<station>" or by a head\'s id.'),
                'start_hour': num_('0–24 (default first_start_hour).'),
                'duration_hours': num_('0.05–24 (default duration_hours).'),
              },
              required: ['name', 'demands'],
            ),
            'replace: the flows, in operating order.',
          ),
          'max_flow_m3h': num_('auto: largest total flow of a system flow (m³/h); default the sum of the supplies\' design flows.'),
          'max_valves': int_('auto: most demands in one flow (0 = no limit).'),
          'first_start_hour': num_('Start of the first flow, 0–24 (default 6).'),
          'duration_hours': num_('Duration of each flow, 0.05–24 h (default 1).'),
        },
        required: ['mode'],
      ),
      summary: (i) => t('ai.do.flows', {'n': '${i['mode']}'}),
      handler: (i) async {
        final a = ToolArgs(i);
        final mode = a.str('mode', required: true)!;
        final p = b.p;
        final start = a.number('first_start_hour', min: 0, max: 24) ?? 6;
        final dur = a.number('duration_hours', min: 0.05, max: 24) ?? 1;
        final demands = demandIds(p);
        final List<SystemFlow> next;
        final notes = <String>[];
        switch (mode) {
          case 'auto':
            final maxValves = a.integer('max_valves', min: 0, max: 999) ?? 0;
            final plan = autoSystemFlows(
              p,
              AutoFlowOptions(maxFlow: (a.number('max_flow_m3h', min: 0) ?? 0) * m3sPerM3h, maxValves: maxValves, durationHours: dur, firstStartHour: start),
              results: c.results,
              label: t.call,
            );
            next = plan.flows;
            if (plan.capacity > 0) {
              notes.add('Flow limit ${AgentToolbox.m3h(plan.capacity)} per system flow.');
            } else if (maxValves <= 0 && plan.demands.length > 1) {
              notes.add(
                'No flow limit was known (no max_flow_m3h, no max_valves, no supply with a design flow dq), so every demand is in one flow. Give max_flow_m3h (the source or pump capacity) or max_valves to split them.',
              );
            }
            if (plan.oversized.isNotEmpty) {
              notes.add(
                'Alone above the limit, each in a flow of its own (the design will report supply_flow_exceeded): ${plan.oversized.map((id) => '${demandName(p, id)} ${AgentToolbox.m3h(plan.demands[id] ?? 0)}').join(', ')}.',
              );
            }
          case 'all_together':
            next = [SystemFlow(id: p.newId('sf'), name: t('name.allZones'), valveIds: demands.toSet(), startHour: start, durationHours: dur)];
          case 'one_at_a_time':
            next = [
              for (var k = 0; k < demands.length; k++)
                SystemFlow(id: p.newId('sf'), name: '${t('name.flow')} ${k + 1} — ${demandName(p, demands[k])}', valveIds: {demands[k]}, startHour: (start + k * dur) % 24, durationHours: dur),
            ];
          case 'replace':
            final raw = i['flows'];
            if (raw is! List || raw.isEmpty) throw ToolInputError('"flows" is needed for replace.');
            final vih = VihStations.of(p);
            next = [];
            for (var k = 0; k < raw.length; k++) {
              final f = Map<String, dynamic>.from(raw[k] as Map);
              final ids = <String>{};
              for (final d in (f['demands'] as List)) {
                final ref = '$d'.trim();
                if (vih.isStation(ref)) {
                  ids.add(ref);
                  continue;
                }
                final e = b.find(ref);
                if (e is OutletEntity && e.scope == HydraulicScope.mainline) {
                  ids.add(vih.stationOf[e.id] ?? e.id);
                  continue;
                }
                if (e is! ControlValveEntity && e is! PivotEntity) throw ToolInputError('flows[$k]: "$d" is not a zone valve, a pivot or a valve-in-head station.');
                ids.add(e.id);
              }
              next.add(
                SystemFlow(
                  id: p.newId('sf'),
                  name: '${f['name']}'.trim(),
                  valveIds: ids,
                  startHour: ((f['start_hour'] as num?)?.toDouble() ?? start).clamp(0, 24).toDouble(),
                  durationHours: ((f['duration_hours'] as num?)?.toDouble() ?? dur).clamp(0.05, 24).toDouble(),
                ),
              );
            }
          default:
            next = [];
        }
        b.change('set_system_flows', () {
          b.p.systemFlows
            ..clear()
            ..addAll(next);
          return next.length;
        });
        return ToolOutput(
          next.isEmpty
              ? 'System flows cleared: the design runs every zone at once.'
              : 'System flows:\n${[for (final f in next) '${f.name}: ${f.valveIds.map((id) => demandName(p, id)).join(', ')} (start ${fmt(f.startHour, 2)} h, ${fmt(f.durationHours, 2)} h)'].join('\n')}${notes.isEmpty ? '' : '\n${notes.join('\n')}'}',
        );
      },
    ),
    FnTool(
      name: 'edit_layers',
      effect: ToolEffect.write,
      description: 'Adds, renames (its items move with it), recolours, locks or unlocks (a locked layer refuses every change to its items), shows or hides (a hidden layer is still designed), removes (its items go to the DRAWING layer; the built-in layers cannot be removed) a layer, or makes it the current one. The design results are kept.',
      inputSchema: obj(
        {
          'action': str(null, ['add', 'rename', 'color', 'lock', 'unlock', 'show', 'hide', 'current', 'remove']),
          'name': str('Layer name (as list_entities shows it).'),
          'new_name': str('rename: the new name.'),
          'color': str('add or color: #RRGGBB (add defaults to #B0BEC5).'),
        },
        required: ['action', 'name'],
      ),
      summary: (i) => t('ai.do.layer', {'op': '${i['action']}', 'n': '${i['name']}'}),
      handler: (i) async {
        final a = ToolArgs(i);
        final name = a.str('name', required: true)!;
        final action = a.str('action', required: true)!;
        final exists = b.p.findLayer(name) != null;
        if (!exists && action != 'add') throw ToolInputError('No layer "$name". Layers: ${b.p.layers.map((l) => l.name).join(', ')}.');
        int color() {
          final s = a.str('color') ?? '#B0BEC5';
          final m = RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch(s);
          if (m == null) throw ToolInputError('"color" must be #RRGGBB.');
          return 0xFF000000 | int.parse(m.group(1)!, radix: 16);
        }

        switch (action) {
          case 'add':
            if (!c.addLayer(name, color: color())) throw ToolInputError('Layer "$name" exists already.');
          case 'rename':
            if (!c.renameLayer(name, a.str('new_name', required: true)!)) throw ToolInputError('Cannot rename "$name": the new name is empty or taken.');
          case 'color':
            c.setLayerColor(name, color());
          case 'lock' || 'unlock':
            c.setLayerLocked(name, action == 'lock');
          case 'show' || 'hide':
            if ((b.p.findLayer(name)!.visible) != (action == 'show')) c.toggleLayer(name);
          case 'current':
            c.setCurrentLayer(name);
          default:
            if (Layers.all.contains(name)) throw ToolInputError('"$name" is a built-in layer and cannot be removed; hide or lock it instead.');
            c.removeLayer(name);
        }
        return ToolOutput('Layer "$name": $action done.');
      },
    ),
    FnTool(
      name: 'set_project_info',
      effect: ToolEffect.write,
      description: 'Sets the project details shown on the sheets and reports (name, client, site, designer, notes); only the fields given change, in an undo step that keeps the design results. latitude and longitude (both, WGS84 degrees) also georeference the drawing origin (0, 0) there, as set_site does (use set_site for that); a georeference change is always confirmed by the user.',
      inputSchema: obj({
        'name': str('Project name.'),
        'client': str(),
        'site': str('Site or farm name and place.'),
        'designer': str(),
        'notes': str(),
        'latitude': num_('Degrees −90…90 of the drawing origin, with longitude.'),
        'longitude': num_('Degrees −180…180 of the drawing origin, with latitude.'),
      }),
      confirm: (i) => i['latitude'] != null || i['longitude'] != null,
      summary: (i) => t('ai.do.info', {
        'what': [for (final k in i.keys) k].join(', '),
      }),
      handler: (i) async {
        final a = ToolArgs(i);
        final lat = a.number('latitude', min: -90, max: 90), lon = a.number('longitude', min: -180, max: 180);
        if ((lat == null) != (lon == null)) throw ToolInputError('Give both latitude and longitude.');
        final meta = ['name', 'client', 'site', 'designer', 'notes'].where(i.containsKey).toList();
        if (meta.isNotEmpty) {
          b.change('set_project_info', () {
            final m = b.p.meta;
            m.name = a.str('name') ?? m.name;
            m.client = a.str('client') ?? m.client;
            m.site = a.str('site') ?? m.site;
            m.designer = a.str('designer') ?? m.designer;
            m.notes = a.str('notes') ?? m.notes;
            return meta.length;
          }, invalidate: false);
        }
        if (lat != null) c.setGeoreferenceAt(lat, lon!);
        return ToolOutput('Done${meta.isEmpty ? '' : ': ${meta.join(', ')}'}${lat == null ? '' : '; georeference at ${fmt(lat, 6)}, ${fmt(lon!, 6)}'}.');
      },
    ),
    FnTool(
      name: 'set_quote',
      effect: ToolEffect.write,
      description: 'Sets the commercial settings of the quote built from the bill of materials; only the fields given change (an undo step that keeps the design results). Money in the project currency. The quote itself is report table "proposal" (after a design).',
      inputSchema: obj({
        'markup_pct': num_('Margin over the material cost, −100…1000 %.'),
        'labour_pct': num_('Installation labour as % of the material cost, 0…1000.'),
        'discount_pct': num_('Discount over the subtotal, 0…100 %.'),
        'tax_pct': num_('Taxes over the discounted subtotal, 0…100 %.'),
        'freight': num_('Freight and delivery, outside the taxes.'),
        'trench_cost_per_m3': num_('Excavation and backfill per m³ of trench.'),
        'trench_width_m': num_('Trench width 0–10 m; 0 = the pipe\'s outside diameter + 0.2 m, at least 0.3 m.'),
        'bedding_m': num_('Bedding under the pipe, 0–2 m, added to the trench depth.'),
        'crews': int_('Installation crews, 1–50 (works schedule).'),
        'validity_days': int_('Days the prices hold, 1–3650.'),
        'payment_terms': str(),
        'notes': str(),
        'annual_benefit': num_('Yearly benefit of the system (harvest, labour, water), for the payback.'),
      }),
      summary: (i) => t('ai.do.quote', {'what': i.keys.join(', ')}),
      handler: (i) async {
        final a = ToolArgs(i);
        final vals = (
          markup: a.number('markup_pct', min: -100, max: 1000),
          labour: a.number('labour_pct', min: 0, max: 1000),
          discount: a.number('discount_pct', min: 0, max: 100),
          tax: a.number('tax_pct', min: 0, max: 100),
          freight: a.number('freight', min: 0),
          trench: a.number('trench_cost_per_m3', min: 0),
          width: a.number('trench_width_m', min: 0, max: 10),
          bedding: a.number('bedding_m', min: 0, max: 2),
          crews: a.integer('crews', min: 1, max: 50),
          validity: a.integer('validity_days', min: 1, max: 3650),
          terms: a.str('payment_terms'),
          notes: a.str('notes'),
          benefit: a.number('annual_benefit', min: 0),
        );
        b.change('set_quote', () {
          final q = b.p.proposal;
          q.markupPct = vals.markup ?? q.markupPct;
          q.labourPct = vals.labour ?? q.labourPct;
          q.discountPct = vals.discount ?? q.discountPct;
          q.taxPct = vals.tax ?? q.taxPct;
          q.freight = vals.freight ?? q.freight;
          q.trenchCostPerM3 = vals.trench ?? q.trenchCostPerM3;
          q.trenchWidthM = vals.width ?? q.trenchWidthM;
          q.beddingM = vals.bedding ?? q.beddingM;
          q.crews = vals.crews ?? q.crews;
          q.validityDays = vals.validity ?? q.validityDays;
          q.paymentTerms = vals.terms ?? q.paymentTerms;
          q.notes = vals.notes ?? q.notes;
          q.annualBenefit = vals.benefit ?? q.annualBenefit;
          return 1;
        }, invalidate: false);
        return const ToolOutput('Quote settings changed (see report table "proposal").');
      },
    ),
    FnTool(
      name: 'set_label_rules',
      effect: ToolEffect.write,
      description:
          'Replaces all the label rules (View → Conditional labels): each shows a design result next to the pipes, outlets or valves where it meets a condition, in its colour, e.g. pipes with velocity > 1.5 m/s in red. Values in SI (m/s, m³/s, metres of head, m). Fields by target: ${[for (final x in LabelRule.targets) '$x (${LabelRule.fieldsOf(x).join(', ')})'].join(', ')}. An empty list removes them all. An undo step that keeps the design results; the labels show once a design has run.',
      inputSchema: obj(
        {
          'rules': arr(
            obj(
              {
                'target': str(null, LabelRule.targets),
                'field': str('A field of the target (see above).'),
                'op': str('">" or "<" compares with value; "any" labels every item.', ['>', '<', 'any']),
                'value': num_('Threshold in SI (default 0).'),
                'color': str('#RRGGBB (default #FF5252).'),
                'enabled': bool_(),
              },
              required: ['target', 'field', 'op'],
            ),
            null,
            30,
          ),
        },
        required: ['rules'],
      ),
      summary: (i) => t('ai.do.labels', {'n': '${(i['rules'] as List?)?.length ?? 0}'}),
      handler: (i) async {
        final rules = <LabelRule>[];
        final raw = i['rules'] as List;
        for (var k = 0; k < raw.length; k++) {
          final r = Map<String, dynamic>.from(raw[k] as Map);
          final target = r['target'] as String, field = '${r['field']}';
          if (!LabelRule.fieldsOf(target).contains(field)) throw ToolInputError('rules[$k]: ${LabelRule.fieldsOf(target).join(', ')} for $target.');
          final m = RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch('${r['color'] ?? '#FF5252'}');
          if (m == null) throw ToolInputError('rules[$k]: "color" must be #RRGGBB.');
          rules.add(
            LabelRule(
              target: target,
              field: field,
              op: r['op'] as String,
              value: (r['value'] as num?)?.toDouble() ?? 0,
              color: 0xFF000000 | int.parse(m.group(1)!, radix: 16),
              enabled: r['enabled'] as bool? ?? true,
            ),
          );
        }
        b.change('set_label_rules', () {
          b.p.labelRules
            ..clear()
            ..addAll(rules);
          return rules.length;
        }, invalidate: false);
        return ToolOutput('${rules.length} label rules set.');
      },
    ),
  ];
}
