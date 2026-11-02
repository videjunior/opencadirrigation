/// Design results and report data structures (serialisable so they can be
/// stored in the project file and reopened without re-running the design).
library;

import 'dart:math' as math;

import '../hydraulics/uniformity.dart';
import '../model/geometry.dart';
import 'electrical.dart';
import 'mechanised.dart';
import 'pivot.dart';

export 'mechanised.dart' show MechanisedResult;
export 'pivot.dart' show PivotResult, PivotTowerRow, PivotKind;

double _d(Map<String, dynamic> j, String k, [double def = 0]) => (j[k] as num?)?.toDouble() ?? def;
List<double> _pt(Pt p) => p.toList();
Pt _p(dynamic l) => l == null ? Pt.zero : Pt.fromList(l as List);

class PipeSegmentResult {
  PipeSegmentResult({
    required this.linkId,
    required this.entityId,
    required this.segmentIndex,
    required this.a,
    required this.b,
    required this.elevationA,
    required this.elevationB,
    required this.length,
    required this.diameter,
    required this.pipeSpecId,
    required this.pipeName,
    required this.flow,
    required this.velocity,
    required this.headLoss,
    required this.pressureStart,
    required this.pressureEnd,
    required this.pressureRating,
    this.zoneId,
    this.overVelocity = false,
  });
  final String linkId;
  final String entityId;
  final int segmentIndex;
  final Pt a;
  final Pt b;
  final double elevationA;
  final double elevationB;
  final double length;
  final double diameter;
  final String? pipeSpecId;
  final String pipeName;
  final double flow;
  final double velocity;
  final double headLoss;
  final double pressureStart;
  final double pressureEnd;
  final double pressureRating;
  final String? zoneId;
  final bool overVelocity;
  bool get overPressure => pressureRating > 0 && (pressureStart > pressureRating || pressureEnd > pressureRating);

  Map<String, dynamic> toJson() => {
    'link': linkId,
    'ent': entityId,
    'seg': segmentIndex,
    'a': _pt(a),
    'b': _pt(b),
    'za': elevationA,
    'zb': elevationB,
    'len': length,
    'd': diameter,
    if (pipeSpecId != null) 'spec': pipeSpecId,
    'name': pipeName,
    'q': flow,
    'v': velocity,
    'hf': headLoss,
    'p0': pressureStart,
    'p1': pressureEnd,
    'pn': pressureRating,
    if (zoneId != null) 'zone': zoneId,
    if (overVelocity) 'ov': true,
  };
  static PipeSegmentResult fromJson(Map<String, dynamic> j) => PipeSegmentResult(
    linkId: j['link'] as String,
    entityId: j['ent'] as String,
    segmentIndex: (j['seg'] as num?)?.toInt() ?? 0,
    a: _p(j['a']),
    b: _p(j['b']),
    elevationA: _d(j, 'za'),
    elevationB: _d(j, 'zb'),
    length: _d(j, 'len'),
    diameter: _d(j, 'd'),
    pipeSpecId: j['spec'] as String?,
    pipeName: j['name'] as String? ?? '',
    flow: _d(j, 'q'),
    velocity: _d(j, 'v'),
    headLoss: _d(j, 'hf'),
    pressureStart: _d(j, 'p0'),
    pressureEnd: _d(j, 'p1'),
    pressureRating: _d(j, 'pn'),
    zoneId: j['zone'] as String?,
    overVelocity: j['ov'] as bool? ?? false,
  );
}

class OutletResult {
  OutletResult({
    required this.entityId,
    required this.index,
    required this.p,
    required this.elevation,
    required this.pressure,
    required this.flow,
    required this.nominalFlow,
    required this.count,
    required this.allowedMin,
    required this.allowedMax,
    required this.label,
  });
  final String entityId;
  final int index;
  final Pt p;
  final double elevation;
  final double pressure;

  /// Flow per emitter (m³/s).
  final double flow;
  final double nominalFlow;
  final int count;
  final double allowedMin;
  final double allowedMax;
  final String label;
  bool get inWindow => pressure >= allowedMin - 1e-6 && pressure <= allowedMax + 1e-6;

  Map<String, dynamic> toJson() => {
    'ent': entityId,
    'i': index,
    'p': _pt(p),
    'z': elevation,
    'h': pressure,
    'q': flow,
    'qn': nominalFlow,
    'n': count,
    'lo': allowedMin,
    'hi': allowedMax,
    'label': label,
  };
  static OutletResult fromJson(Map<String, dynamic> j) => OutletResult(
    entityId: j['ent'] as String,
    index: (j['i'] as num?)?.toInt() ?? -1,
    p: _p(j['p']),
    elevation: _d(j, 'z'),
    pressure: _d(j, 'h'),
    flow: _d(j, 'q'),
    nominalFlow: _d(j, 'qn'),
    count: (j['n'] as num?)?.toInt() ?? 1,
    allowedMin: _d(j, 'lo'),
    allowedMax: _d(j, 'hi', double.infinity),
    label: j['label'] as String? ?? '',
  );
}

class DeviceResult {
  DeviceResult({
    required this.entityId,
    required this.linkId,
    required this.flow,
    required this.headLoss,
    required this.pumpHead,
    required this.upstreamPressure,
    required this.downstreamPressure,
    this.status = '',
    this.elevation = 0,
    this.speedRatio = 1,
  });
  final String entityId;
  final String linkId;
  final double flow;
  final double headLoss;
  final double pumpHead;
  final double upstreamPressure;
  final double downstreamPressure;
  final String status;

  /// Elevation of the device (m): the installation level of a submersible
  /// pump, the pipe level otherwise.
  final double elevation;

  /// Speed ratio of a pump in this flow (a variable-speed drive sets it).
  final double speedRatio;

  Map<String, dynamic> toJson() => {
    'ent': entityId,
    'link': linkId,
    'q': flow,
    'hf': headLoss,
    'hp': pumpHead,
    'pu': upstreamPressure,
    'pd': downstreamPressure,
    'st': status,
    'z': elevation,
    if (speedRatio != 1) 'n': speedRatio,
  };
  static DeviceResult fromJson(Map<String, dynamic> j) => DeviceResult(
    entityId: j['ent'] as String,
    linkId: j['link'] as String? ?? '',
    flow: _d(j, 'q'),
    headLoss: _d(j, 'hf'),
    pumpHead: _d(j, 'hp'),
    upstreamPressure: _d(j, 'pu'),
    downstreamPressure: _d(j, 'pd'),
    status: j['st'] as String? ?? '',
    elevation: _d(j, 'z'),
    speedRatio: (j['n'] as num?)?.toDouble() ?? 1,
  );
}

class ZoneResult {
  ZoneResult({
    required this.valveId,
    required this.zoneName,
    required this.converged,
    required this.totalFlow,
    required this.downstreamHead,
    required this.valveLoss,
    required this.requiredUpstreamHead,
    required this.minOutletPressure,
    required this.maxOutletPressure,
    required this.allowedMin,
    required this.allowedMax,
    required this.nominalPressure,
    required this.uniformity,
    required this.pipes,
    required this.outlets,
    required this.devices,
    required this.warnings,
    required this.valveElevation,
    this.valveSpecName = '',
    this.emitterCount = 0,
    this.pipeCost = 0,
    this.annualEnergyCost = 0,
    this.overlapCu = 0,
    this.emittersPerPlant = 1,
  });
  final String valveId;
  final String zoneName;
  final bool converged;
  final double totalFlow;
  final double downstreamHead;
  final double valveLoss;
  final double requiredUpstreamHead;
  final double minOutletPressure;
  final double maxOutletPressure;
  final double allowedMin;
  final double allowedMax;
  final double nominalPressure;
  final UniformityStats uniformity;
  final List<PipeSegmentResult> pipes;
  final List<OutletResult> outlets;
  final List<DeviceResult> devices;
  final List<String> warnings;
  final double valveElevation;
  final String valveSpecName;
  final int emitterCount;
  final double pipeCost;
  final double annualEnergyCost;

  /// Christiansen CU of the overlapped sprinkler pattern (0 when not a
  /// sprinkler zone).
  final double overlapCu;
  final int emittersPerPlant;

  double get allowedVariationPct => nominalPressure > 0 ? 100 * (allowedMax - allowedMin) / nominalPressure : 0;
  double get actualVariationPct => nominalPressure > 0 ? 100 * (maxOutletPressure - minOutletPressure) / nominalPressure : 0;
  bool get withinWindow => minOutletPressure >= allowedMin - 1e-6 && maxOutletPressure <= allowedMax + 1e-6;
  OutletResult? get minOutlet => outlets.isEmpty ? null : outlets.reduce((a, b) => a.pressure <= b.pressure ? a : b);
  OutletResult? get maxOutlet => outlets.isEmpty ? null : outlets.reduce((a, b) => a.pressure >= b.pressure ? a : b);

  ZoneResult copyWith({List<String>? warnings, double? overlapCu, int? emittersPerPlant, UniformityStats? uniformity}) => ZoneResult(
    valveId: valveId,
    zoneName: zoneName,
    converged: converged,
    totalFlow: totalFlow,
    downstreamHead: downstreamHead,
    valveLoss: valveLoss,
    requiredUpstreamHead: requiredUpstreamHead,
    minOutletPressure: minOutletPressure,
    maxOutletPressure: maxOutletPressure,
    allowedMin: allowedMin,
    allowedMax: allowedMax,
    nominalPressure: nominalPressure,
    uniformity: uniformity ?? this.uniformity,
    pipes: pipes,
    outlets: outlets,
    devices: devices,
    warnings: warnings ?? this.warnings,
    valveElevation: valveElevation,
    valveSpecName: valveSpecName,
    emitterCount: emitterCount,
    pipeCost: pipeCost,
    annualEnergyCost: annualEnergyCost,
    overlapCu: overlapCu ?? this.overlapCu,
    emittersPerPlant: emittersPerPlant ?? this.emittersPerPlant,
  );

  Map<String, dynamic> toJson() => {
    'valve': valveId,
    'name': zoneName,
    'conv': converged,
    'q': totalFlow,
    'hd': downstreamHead,
    'hv': valveLoss,
    'hreq': requiredUpstreamHead,
    'pmin': minOutletPressure,
    'pmax': maxOutletPressure,
    'lo': allowedMin,
    'hi': allowedMax,
    'pn': nominalPressure,
    'uni': uniformity.toJson(),
    'pipes': pipes.map((p) => p.toJson()).toList(),
    'outlets': outlets.map((o) => o.toJson()).toList(),
    'devices': devices.map((d) => d.toJson()).toList(),
    'warn': warnings,
    'zv': valveElevation,
    'valveName': valveSpecName,
    'n': emitterCount,
    'cost': pipeCost,
    'energy': annualEnergyCost,
    'ocu': overlapCu,
    'epp': emittersPerPlant,
  };
  static ZoneResult fromJson(Map<String, dynamic> j) => ZoneResult(
    valveId: j['valve'] as String,
    zoneName: j['name'] as String? ?? '',
    converged: j['conv'] as bool? ?? false,
    totalFlow: _d(j, 'q'),
    downstreamHead: _d(j, 'hd'),
    valveLoss: _d(j, 'hv'),
    requiredUpstreamHead: _d(j, 'hreq'),
    minOutletPressure: _d(j, 'pmin'),
    maxOutletPressure: _d(j, 'pmax'),
    allowedMin: _d(j, 'lo'),
    allowedMax: _d(j, 'hi'),
    nominalPressure: _d(j, 'pn'),
    uniformity: UniformityStats.fromJson(j['uni'] as Map<String, dynamic>?),
    pipes: ((j['pipes'] as List?) ?? []).map((p) => PipeSegmentResult.fromJson(p as Map<String, dynamic>)).toList(),
    outlets: ((j['outlets'] as List?) ?? []).map((p) => OutletResult.fromJson(p as Map<String, dynamic>)).toList(),
    devices: ((j['devices'] as List?) ?? []).map((p) => DeviceResult.fromJson(p as Map<String, dynamic>)).toList(),
    warnings: ((j['warn'] as List?) ?? []).cast<String>(),
    valveElevation: _d(j, 'zv'),
    valveSpecName: j['valveName'] as String? ?? '',
    emitterCount: (j['n'] as num?)?.toInt() ?? 0,
    pipeCost: _d(j, 'cost'),
    annualEnergyCost: _d(j, 'energy'),
    overlapCu: _d(j, 'ocu'),
    emittersPerPlant: (j['epp'] as num?)?.toInt() ?? 1,
  );
}

class SupplyDuty {
  SupplyDuty({
    required this.supplyId,
    required this.name,
    required this.flow,
    required this.head,
    required this.requiredHead,
    required this.elevation,
    required this.calculated,
    this.designHead = 0,
    this.maxHead = 0,
    this.designFlow = 0,
    this.maxFlow = 0,
    this.pumpBoost,
  });
  final String supplyId;
  final String name;
  final double flow;

  /// Head (m) the running pumps add in series on the way from this supply
  /// to the valve or head that sets its pressure (pumps in parallel count
  /// once, boosters of other branches not at all); null when unknown. A pump
  /// at the supply must add [requiredHead] plus this.
  double? pumpBoost;

  /// Pressure head available at the supply (m).
  final double head;

  /// Pressure head required at the supply so every valve is satisfied (m).
  final double requiredHead;
  final double elevation;
  final bool calculated;
  final double designHead;
  final double maxHead;
  final double designFlow;
  final double maxFlow;
  bool get flowExceedsDesign => designFlow > 0 && flow > designFlow + 1e-9;
  bool get headExceedsMax => maxHead > 0 && requiredHead > maxHead + 1e-6;

  /// Pressure beyond the need at this supply (m): a calculated supply whose
  /// pumps or elevation already cover the worst valve (its [requiredHead] is
  /// then negative and the analysis runs it at zero), or a fixed supply set
  /// above its requirement. Zero when the need is met exactly or not met.
  double get surplusHead => math.max(0, head - requiredHead);

  Map<String, dynamic> toJson() => {
    'id': supplyId,
    'name': name,
    'q': flow,
    'h': head,
    'hreq': requiredHead,
    'z': elevation,
    'calc': calculated,
    'dh': designHead,
    'mh': maxHead,
    'dq': designFlow,
    'mq': maxFlow,
    if (pumpBoost != null) 'boost': pumpBoost,
  };
  static SupplyDuty fromJson(Map<String, dynamic> j) => SupplyDuty(
    supplyId: j['id'] as String,
    name: j['name'] as String? ?? '',
    flow: _d(j, 'q'),
    head: _d(j, 'h'),
    requiredHead: _d(j, 'hreq'),
    elevation: _d(j, 'z'),
    calculated: j['calc'] as bool? ?? true,
    designHead: _d(j, 'dh'),
    maxHead: _d(j, 'mh'),
    designFlow: _d(j, 'dq'),
    maxFlow: _d(j, 'mq'),
    pumpBoost: (j['boost'] as num?)?.toDouble(),
  );
}

class ValveDuty {
  ValveDuty({required this.valveId, required this.zoneName, required this.flow, required this.availableHead, required this.requiredHead, required this.p, this.regulates = true});
  final String valveId;
  final String zoneName;
  final double flow;
  final double availableHead;
  final double requiredHead;
  final Pt p;

  /// Whether the valve holds its outlet pressure (a set outlet pressure or
  /// a pressure reducing model); a plain valve passes a surplus on.
  final bool regulates;
  double get deficit => requiredHead - availableHead;

  /// Pressure (m) the valve gets above what its zone needs.
  double get surplus => availableHead - requiredHead;

  /// A surplus a valve that does not regulate passes on to its zone, the
  /// larger of 5 m and a fifth of the need: the zone then runs above its
  /// design pressure and flow (`valve_pressure_excess`).
  bool get excessive => !regulates && surplus > math.max(5.0, 0.2 * requiredHead);

  Map<String, dynamic> toJson() => {'id': valveId, 'name': zoneName, 'q': flow, 'h': availableHead, 'hreq': requiredHead, 'p': _pt(p), if (!regulates) 'reg': false};
  static ValveDuty fromJson(Map<String, dynamic> j) => ValveDuty(
    valveId: j['id'] as String,
    zoneName: j['name'] as String? ?? '',
    flow: _d(j, 'q'),
    availableHead: _d(j, 'h'),
    requiredHead: _d(j, 'hreq'),
    p: _p(j['p']),
    regulates: j['reg'] as bool? ?? true,
  );
}

/// A number that may not be finite as JSON (null), as [encodeJson] writes
/// it anyway.
double? _jn(double v) => v.isFinite ? v : null;

/// A valve-in-head station (see `valve_in_head.dart`) running in a system
/// flow: its heads on the mainline, their flow and pressures.
class VihDuty {
  VihDuty({
    required this.stationId,
    required this.name,
    required this.heads,
    required this.flow,
    required this.minPressure,
    required this.maxPressure,
    required this.allowedMin,
    required this.allowedMax,
    required this.criticalId,
    required this.availableHead,
    required this.requiredHead,
    required this.elevation,
    required this.p,
    this.scheduled = true,
  });
  final String stationId;
  final String name;

  /// Heads of the station on the mainline (all of them run together).
  final int heads;

  /// Flow of the heads at their pressures (m³/s).
  final double flow;

  /// Lowest and highest pressure at the nozzles (m) and the window every
  /// head of the station allows (m).
  final double minPressure;
  final double maxPressure;
  final double allowedMin;
  final double allowedMax;

  /// The head furthest below its nominal pressure: its outlet id, the
  /// pressure head at its mainline node, the head it needs there (nominal
  /// pressure plus riser) and the node's elevation (m) and position.
  final String criticalId;
  final double availableHead;
  final double requiredHead;
  final double elevation;
  final Pt p;

  /// Whether a system flow lists the station: only then does its need set
  /// the supply pressure (a station no flow lists runs in every flow, as
  /// mainline outlets always did).
  final bool scheduled;

  double get deficit => requiredHead - availableHead;
  bool get withinWindow => minPressure >= allowedMin - 1e-6 && maxPressure <= allowedMax + 1e-6;

  Map<String, dynamic> toJson() => {
    'id': stationId,
    'name': name,
    'n': heads,
    'q': flow,
    'pmin': _jn(minPressure),
    'pmax': _jn(maxPressure),
    'lo': _jn(allowedMin),
    'hi': _jn(allowedMax),
    'crit': criticalId,
    'h': _jn(availableHead),
    'hreq': _jn(requiredHead),
    'z': elevation,
    'p': _pt(p),
    if (!scheduled) 'sch': false,
  };
  static VihDuty fromJson(Map<String, dynamic> j) => VihDuty(
    stationId: j['id'] as String,
    name: j['name'] as String? ?? '',
    heads: (j['n'] as num?)?.toInt() ?? 0,
    flow: _d(j, 'q'),
    minPressure: _d(j, 'pmin', double.nan),
    maxPressure: _d(j, 'pmax', double.nan),
    allowedMin: _d(j, 'lo', double.nan),
    allowedMax: _d(j, 'hi', double.infinity),
    criticalId: j['crit'] as String? ?? '',
    availableHead: _d(j, 'h', double.nan),
    requiredHead: _d(j, 'hreq', double.nan),
    elevation: _d(j, 'z'),
    p: _p(j['p']),
    scheduled: j['sch'] as bool? ?? true,
  );
}

class SystemFlowResult {
  SystemFlowResult({
    required this.flowId,
    required this.name,
    required this.converged,
    required this.supplies,
    required this.valves,
    required this.pipes,
    required this.devices,
    required this.warnings,
    required this.totalFlow,
    required this.durationHours,
    this.annualEnergyCost = 0,
    this.heads = const [],
  });
  final String flowId;
  final String name;
  final bool converged;
  final List<SupplyDuty> supplies;
  final List<ValveDuty> valves;
  final List<PipeSegmentResult> pipes;
  final List<DeviceResult> devices;
  final List<String> warnings;
  final double totalFlow;
  final double durationHours;
  final double annualEnergyCost;

  /// Valve-in-head stations running in this flow.
  final List<VihDuty> heads;
  double get maxDeficit => valves.isEmpty ? 0 : valves.map((v) => v.deficit).reduce((a, b) => a > b ? a : b);

  Map<String, dynamic> toJson() => {
    'id': flowId,
    'name': name,
    'conv': converged,
    'supplies': supplies.map((s) => s.toJson()).toList(),
    'valves': valves.map((v) => v.toJson()).toList(),
    'pipes': pipes.map((p) => p.toJson()).toList(),
    'devices': devices.map((d) => d.toJson()).toList(),
    'warn': warnings,
    'q': totalFlow,
    'dur': durationHours,
    'energy': annualEnergyCost,
    if (heads.isNotEmpty) 'vih': heads.map((h) => h.toJson()).toList(),
  };
  static SystemFlowResult fromJson(Map<String, dynamic> j) => SystemFlowResult(
    flowId: j['id'] as String,
    name: j['name'] as String? ?? '',
    converged: j['conv'] as bool? ?? false,
    supplies: ((j['supplies'] as List?) ?? []).map((s) => SupplyDuty.fromJson(s as Map<String, dynamic>)).toList(),
    valves: ((j['valves'] as List?) ?? []).map((s) => ValveDuty.fromJson(s as Map<String, dynamic>)).toList(),
    pipes: ((j['pipes'] as List?) ?? []).map((p) => PipeSegmentResult.fromJson(p as Map<String, dynamic>)).toList(),
    devices: ((j['devices'] as List?) ?? []).map((p) => DeviceResult.fromJson(p as Map<String, dynamic>)).toList(),
    warnings: ((j['warn'] as List?) ?? []).cast<String>(),
    totalFlow: _d(j, 'q'),
    durationHours: _d(j, 'dur', 1),
    annualEnergyCost: _d(j, 'energy'),
    heads: [for (final h in (j['vih'] as List?) ?? const []) VihDuty.fromJson(h as Map<String, dynamic>)],
  );
}

/// A valve-in-head station over the system flows it runs in
/// ([DesignResults.vihStations]).
class VihStationResult {
  VihStationResult({
    required this.stationId,
    required this.name,
    required this.flowIds,
    required this.heads,
    required this.flow,
    required this.minPressure,
    required this.maxPressure,
    required this.allowedMin,
    required this.allowedMax,
    required this.worstDeficit,
    required this.scheduled,
  });
  final String stationId;
  final String name;

  /// The flows it runs in, in operating order.
  final List<String> flowIds;

  /// Heads, the largest flow (m³/s) and the lowest and highest nozzle
  /// pressure of those flows (m), the window of the heads (m) and the worst
  /// shortfall below the nominal pressure (m; negative = a margin).
  final int heads;
  final double flow;
  final double minPressure;
  final double maxPressure;
  final double allowedMin;
  final double allowedMax;
  final double worstDeficit;
  final bool scheduled;
}

class BomLine {
  BomLine({required this.category, required this.description, required this.unit, required this.quantity, required this.unitCost, this.specId, this.code = '', this.supplier = '', this.finame = ''});
  final String category;
  final String description;
  final String unit;
  double quantity;
  final double unitCost;
  final String? specId;
  final String code;
  final String supplier;

  /// BNDES FINAME code of the item ('' = not credentialed).
  final String finame;
  double get total => quantity * unitCost;

  Map<String, dynamic> toJson() => {
    'cat': category,
    'desc': description,
    'unit': unit,
    'qty': quantity,
    'cost': unitCost,
    if (specId != null) 'spec': specId,
    if (code.isNotEmpty) 'code': code,
    if (supplier.isNotEmpty) 'sup': supplier,
    if (finame.isNotEmpty) 'finame': finame,
  };
  static BomLine fromJson(Map<String, dynamic> j) => BomLine(
    category: j['cat'] as String,
    description: j['desc'] as String? ?? '',
    unit: j['unit'] as String? ?? '',
    quantity: _d(j, 'qty'),
    unitCost: _d(j, 'cost'),
    specId: j['spec'] as String?,
    code: j['code'] as String? ?? '',
    supplier: j['sup'] as String? ?? '',
    finame: j['finame'] as String? ?? '',
  );
}

/// Flushing analysis of a zone: tapes flushed with open ends.
class FlushingResult {
  FlushingResult({
    required this.valveId,
    required this.zoneName,
    required this.flow,
    required this.requiredDownstreamHead,
    required this.requiredUpstreamHead,
    required this.tapeCount,
    required this.minEndHead,
    required this.maxVelocity,
    required this.flushingVelocity,
    this.converged = true,
  });
  final String valveId;
  final String zoneName;
  final double flow;
  final double requiredDownstreamHead;
  final double requiredUpstreamHead;
  final int tapeCount;
  final double minEndHead;
  final double maxVelocity;
  final double flushingVelocity;
  final bool converged;

  Map<String, dynamic> toJson() => {
    'valve': valveId,
    'name': zoneName,
    'q': flow,
    'hd': requiredDownstreamHead,
    'hreq': requiredUpstreamHead,
    'n': tapeCount,
    'hend': minEndHead,
    'vmax': maxVelocity,
    'vf': flushingVelocity,
    'conv': converged,
  };
  static FlushingResult fromJson(Map<String, dynamic> j) => FlushingResult(
    valveId: j['valve'] as String,
    zoneName: j['name'] as String? ?? '',
    flow: _d(j, 'q'),
    requiredDownstreamHead: _d(j, 'hd'),
    requiredUpstreamHead: _d(j, 'hreq'),
    tapeCount: (j['n'] as num?)?.toInt() ?? 0,
    minEndHead: _d(j, 'hend'),
    maxVelocity: _d(j, 'vmax'),
    flushingVelocity: _d(j, 'vf'),
    converged: j['conv'] as bool? ?? true,
  );
}

/// Water-hammer check of a pipe (worst segment).
class SurgeResult {
  SurgeResult({
    required this.entityId,
    required this.context,
    required this.pipeName,
    required this.velocity,
    required this.celerity,
    required this.surgeHead,
    required this.maxStaticHead,
    required this.rating,
    required this.closureTime,
    required this.criticalTime,
    this.pathLength = 0,
  });
  final String entityId;
  final String context;
  final String pipeName;
  final double velocity;
  final double celerity;
  final double surgeHead;
  final double maxStaticHead;
  final double rating;
  final double closureTime;
  final double criticalTime;

  /// Length (m) of the water path the critical time 2L/a is taken over: from
  /// the supply (or the zone valve) to the farthest point fed through the
  /// pipe, at least the pipe itself.
  final double pathLength;
  double get totalHead => maxStaticHead + surgeHead;
  bool get exceeds => rating > 0 && totalHead > rating + 1e-6;

  Map<String, dynamic> toJson() => {
    'ent': entityId,
    'ctx': context,
    'name': pipeName,
    'v': velocity,
    'a': celerity,
    'dh': surgeHead,
    'hs': maxStaticHead,
    'pn': rating,
    'tc': closureTime,
    'tcrit': criticalTime,
    if (pathLength > 0) 'L': pathLength,
  };
  static SurgeResult fromJson(Map<String, dynamic> j) => SurgeResult(
    entityId: j['ent'] as String,
    context: j['ctx'] as String? ?? '',
    pipeName: j['name'] as String? ?? '',
    velocity: _d(j, 'v'),
    celerity: _d(j, 'a'),
    surgeHead: _d(j, 'dh'),
    maxStaticHead: _d(j, 'hs'),
    rating: _d(j, 'pn'),
    closureTime: _d(j, 'tc'),
    criticalTime: _d(j, 'tcrit'),
    pathLength: _d(j, 'L'),
  );
}

class DesignResults {
  DesignResults({required this.timestamp, this.method = ''});
  final DateTime timestamp;

  /// Sizing method used (lp / greedy / analysis).
  String method;
  final Map<String, ZoneResult> zones = {};

  /// Centre pivots / linear moves by entity id.
  final Map<String, PivotResult> pivots = {};

  /// Sprinkler package, timer chart and, when configured, corner arm,
  /// variable-rate prescription and electrical design of every machine, by
  /// pivot id.
  final Map<String, MechanisedResult> mechanised = {};
  final List<SystemFlowResult> systemFlows = [];
  final List<String> messages = [];
  final List<BomLine> bom = [];

  /// The bill of materials split by where it goes: a zone (valve id), the
  /// mainline (''), a pivot (its id) or the electrical part ('elec').
  final Map<String, List<BomLine>> bomByZone = {};
  final List<FlushingResult> flushing = [];
  final List<SurgeResult> surge = [];
  final Set<String> unconnected = {};

  /// Valve wiring (controllers, wire sizes, solenoid voltages); null when
  /// the drawing has no controller and no wire route.
  ElectricalResult? electrical;
  double capitalCost = 0;
  double annualCapitalCost = 0;
  double annualEnergyCost = 0;

  Map<String, List<PipeSegmentResult>>? _pipesCache;
  Map<String, List<OutletResult>>? _outletsCache;

  /// Pipe segment results by entity id (latest analysis, any context).
  Map<String, List<PipeSegmentResult>> get pipesByEntity {
    final cached = _pipesCache;
    if (cached != null) return cached;
    final m = <String, List<PipeSegmentResult>>{};
    for (final z in zones.values) {
      for (final p in z.pipes) {
        m.putIfAbsent(p.entityId, () => []).add(p);
      }
    }
    // mainline: keep the worst (max flow) segment per link
    final best = <String, PipeSegmentResult>{};
    for (final f in systemFlows) {
      for (final p in f.pipes) {
        final cur = best[p.linkId];
        if (cur == null || p.flow.abs() > cur.flow.abs()) best[p.linkId] = p;
      }
    }
    for (final p in best.values) {
      m.putIfAbsent(p.entityId, () => []).add(p);
    }
    return _pipesCache = m;
  }

  Map<String, List<OutletResult>> get outletsByEntity {
    final cached = _outletsCache;
    if (cached != null) return cached;
    final m = <String, List<OutletResult>>{};
    for (final z in zones.values) {
      for (final o in z.outlets) {
        m.putIfAbsent(o.entityId, () => []).add(o);
      }
    }
    return _outletsCache = m;
  }

  /// Valve-in-head stations over the system flows they run in, in the order
  /// they first run.
  Map<String, VihStationResult> get vihStations {
    final by = <String, List<(String, VihDuty)>>{};
    for (final f in systemFlows) {
      for (final h in f.heads) {
        by.putIfAbsent(h.stationId, () => []).add((f.flowId, h));
      }
    }
    return {
      for (final e in by.entries)
        e.key: VihStationResult(
          stationId: e.key,
          name: e.value.first.$2.name,
          flowIds: [for (final (f, _) in e.value) f],
          heads: e.value.fold(0, (m, x) => math.max(m, x.$2.heads)),
          flow: e.value.fold(0.0, (m, x) => math.max(m, x.$2.flow)),
          minPressure: e.value.fold(double.infinity, (m, x) => math.min(m, x.$2.minPressure)),
          maxPressure: e.value.fold(-double.infinity, (m, x) => math.max(m, x.$2.maxPressure)),
          allowedMin: e.value.first.$2.allowedMin,
          allowedMax: e.value.first.$2.allowedMax,
          worstDeficit: e.value.fold(-double.infinity, (m, x) => math.max(m, x.$2.deficit)),
          scheduled: e.value.first.$2.scheduled,
        ),
    };
  }

  /// Drops the by-entity caches after zones/flows were modified.
  void invalidateCaches() {
    _pipesCache = null;
    _outletsCache = null;
  }

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'method': method,
    'zones': zones.values.map((z) => z.toJson()).toList(),
    if (pivots.isNotEmpty) 'pivots': pivots.values.map((p) => p.toJson()).toList(),
    if (mechanised.isNotEmpty) 'mech': mechanised.values.map((m) => m.toJson()).toList(),
    'systemFlows': systemFlows.map((f) => f.toJson()).toList(),
    'messages': messages,
    'bom': bom.map((b) => b.toJson()).toList(),
    if (bomByZone.isNotEmpty) 'bomZones': {for (final e in bomByZone.entries) e.key: e.value.map((b) => b.toJson()).toList()},
    'flushing': flushing.map((f) => f.toJson()).toList(),
    'surge': surge.map((s) => s.toJson()).toList(),
    'unconnected': unconnected.toList(),
    if (electrical != null) 'electrical': electrical!.toJson(),
    'capital': capitalCost,
    'annualCapital': annualCapitalCost,
    'annualEnergy': annualEnergyCost,
  };

  static DesignResults fromJson(Map<String, dynamic> j) {
    final r = DesignResults(timestamp: DateTime.tryParse(j['timestamp'] as String? ?? '') ?? DateTime.now(), method: j['method'] as String? ?? '');
    for (final z in (j['zones'] as List?) ?? []) {
      final zr = ZoneResult.fromJson(z as Map<String, dynamic>);
      r.zones[zr.valveId] = zr;
    }
    for (final p in (j['pivots'] as List?) ?? []) {
      final pr = PivotResult.fromJson(p as Map<String, dynamic>);
      r.pivots[pr.pivotId] = pr;
    }
    for (final m in (j['mech'] as List?) ?? []) {
      final mr = MechanisedResult.fromJson(m as Map<String, dynamic>);
      r.mechanised[mr.pivotId] = mr;
    }
    r.systemFlows.addAll(((j['systemFlows'] as List?) ?? []).map((f) => SystemFlowResult.fromJson(f as Map<String, dynamic>)));
    r.messages.addAll(((j['messages'] as List?) ?? []).cast<String>());
    r.bom.addAll(((j['bom'] as List?) ?? []).map((b) => BomLine.fromJson(b as Map<String, dynamic>)));
    for (final e in ((j['bomZones'] as Map?) ?? const {}).entries) {
      r.bomByZone[e.key as String] = [for (final b in (e.value as List)) BomLine.fromJson(b as Map<String, dynamic>)];
    }
    r.flushing.addAll(((j['flushing'] as List?) ?? []).map((b) => FlushingResult.fromJson(b as Map<String, dynamic>)));
    r.surge.addAll(((j['surge'] as List?) ?? []).map((b) => SurgeResult.fromJson(b as Map<String, dynamic>)));
    r.unconnected.addAll(((j['unconnected'] as List?) ?? []).cast<String>());
    final el = j['electrical'];
    if (el is Map<String, dynamic>) r.electrical = ElectricalResult.fromJson(el);
    r.capitalCost = _d(j, 'capital');
    r.annualCapitalCost = _d(j, 'annualCapital');
    r.annualEnergyCost = _d(j, 'annualEnergy');
    return r;
  }
}
