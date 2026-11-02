/// Results added in 1.6.0 for the hydraulic engine (MOT+): the duty of the
/// pumps of a pump station in a system flow (PRD-17) and the real operation
/// of the zones at the pressure the mainline gives them. Serialisable like
/// the rest of `results.dart`, which exports them.
library;

double _d(Map<String, dynamic> j, String k, [double def = 0]) {
  final v = j[k];
  return v is num && v.isFinite ? v.toDouble() : def;
}

/// One pump of a station in a system flow: running, off (a duty pump the
/// staging left off) or on standby.
class StationUnitDuty {
  StationUnitDuty({
    required this.index,
    required this.specId,
    required this.name,
    this.standby = false,
    this.running = false,
    this.flow = 0,
    this.head = 0,
    this.efficiency = 0,
    this.powerKw = 0,
    this.speedRatio = 1,
  });

  /// Place in the station, from 1 (the lead pump: the item's own).
  final int index;
  final String specId;
  final String name;
  final bool standby;
  final bool running;

  /// Flow (m³/s) and head (m) of this pump.
  final double flow;
  final double head;

  /// Efficiency from the wire to the water (pump curve × motor and drive).
  final double efficiency;

  /// Electric power drawn (kW).
  final double powerKw;
  final double speedRatio;

  Map<String, dynamic> toJson() => {
    'i': index,
    'spec': specId,
    'name': name,
    if (standby) 'sb': true,
    if (running) 'on': true,
    'q': flow,
    'h': head,
    'eff': efficiency,
    'kw': powerKw,
    if (speedRatio != 1) 'n': speedRatio,
  };

  static StationUnitDuty fromJson(Map<String, dynamic> j) => StationUnitDuty(
    index: (j['i'] as num?)?.toInt() ?? 0,
    specId: j['spec'] as String? ?? '',
    name: j['name'] as String? ?? '',
    standby: j['sb'] == true,
    running: j['on'] == true,
    flow: _d(j, 'q'),
    head: _d(j, 'h'),
    efficiency: _d(j, 'eff'),
    powerKw: _d(j, 'kw'),
    speedRatio: _d(j, 'n', 1),
  );
}

/// A pump station in a system flow: the flow it passes, the head it adds
/// and the duty of each of its pumps.
class StationDuty {
  StationDuty({required this.entityId, required this.name, required this.arrangement, required this.staged, required this.flow, required this.head, required this.units});

  /// The pump item that stands for the station.
  final String entityId;
  final String name;

  /// `parallel` or `series`.
  final String arrangement;

  /// Whether the duty pumps start one after another by the flow.
  final bool staged;

  /// Flow (m³/s) through the station and head (m) it adds.
  final double flow;
  final double head;
  final List<StationUnitDuty> units;

  int get running => units.where((u) => u.running).length;
  int get duty => units.where((u) => !u.standby).length;
  int get standby => units.where((u) => u.standby).length;

  /// Electric power the running pumps draw (kW).
  double get powerKw => units.fold(0.0, (s, u) => s + u.powerKw);

  Map<String, dynamic> toJson() => {
    'ent': entityId,
    'name': name,
    'arr': arrangement,
    if (!staged) 'staged': false,
    'q': flow,
    'h': head,
    'units': [for (final u in units) u.toJson()],
  };

  static StationDuty fromJson(Map<String, dynamic> j) => StationDuty(
    entityId: j['ent'] as String? ?? '',
    name: j['name'] as String? ?? '',
    arrangement: j['arr'] as String? ?? 'parallel',
    staged: j['staged'] as bool? ?? true,
    flow: _d(j, 'q'),
    head: _d(j, 'h'),
    units: [
      for (final u in (j['units'] as List?) ?? const [])
        if (u is Map) StationUnitDuty.fromJson(u.cast<String, dynamic>()),
    ],
  );
}

/// A zone (or pivot) of a system flow run at the pressure the mainline
/// really gives it: the emitters deliver what that pressure allows, a valve
/// that does not regulate passes a surplus on, and the line and the pumps
/// settle at the flows that follow.
class ZoneOperation {
  ZoneOperation({
    required this.valveId,
    required this.zoneName,
    required this.designFlow,
    required this.flow,
    required this.requiredHead,
    required this.availableHead,
    this.downstreamHead = 0,
    this.minPressure = 0,
    this.maxPressure = 0,
    this.allowedMin = 0,
    this.allowedMax = 0,
    this.eu = 0,
    this.regulates = true,
    this.pivot = false,
  });

  final String valveId;
  final String zoneName;

  /// Flow of the design (m³/s) and the flow at the real operating point.
  final double designFlow;
  final double flow;

  /// Pressure head (m) the design needs at the mainline node and the one the
  /// mainline gives there at the real operating point.
  final double requiredHead;
  final double availableHead;

  /// Pressure head (m) after the valve, and the lowest and highest emitter
  /// pressure, at the real operating point (0 for a pivot).
  final double downstreamHead;
  final double minPressure;
  final double maxPressure;

  /// Pressure window of the emitters of the zone (m).
  final double allowedMin;
  final double allowedMax;

  /// Emission uniformity (%) at the real operating point (0 when unknown).
  final double eu;

  /// Whether the valve holds its outlet pressure (a surplus stays upstream).
  final bool regulates;
  final bool pivot;

  /// Share of the design flow delivered (1 = all of it).
  double get delivered => designFlow > 0 ? flow / designFlow : 1;

  /// Short of pressure (less than 98 % of the flow, or emitters below the
  /// window) or above it (a surplus a plain valve passes on).
  bool get short => delivered < 0.98 || (allowedMin > 0 && minPressure < allowedMin - 0.01 && availableHead < requiredHead - 0.01);
  bool get excess => !regulates && maxPressure > allowedMax + 0.01 && allowedMax > 0;

  Map<String, dynamic> toJson() => {
    'id': valveId,
    'name': zoneName,
    'q0': designFlow,
    'q': flow,
    'hreq': requiredHead,
    'h': availableHead,
    'hd': downstreamHead,
    'pmin': minPressure,
    'pmax': maxPressure,
    'amin': allowedMin,
    'amax': allowedMax,
    'eu': eu,
    if (!regulates) 'reg': false,
    if (pivot) 'pivot': true,
  };

  static ZoneOperation fromJson(Map<String, dynamic> j) => ZoneOperation(
    valveId: j['id'] as String? ?? '',
    zoneName: j['name'] as String? ?? '',
    designFlow: _d(j, 'q0'),
    flow: _d(j, 'q'),
    requiredHead: _d(j, 'hreq'),
    availableHead: _d(j, 'h'),
    downstreamHead: _d(j, 'hd'),
    minPressure: _d(j, 'pmin'),
    maxPressure: _d(j, 'pmax'),
    allowedMin: _d(j, 'amin'),
    allowedMax: _d(j, 'amax'),
    eu: _d(j, 'eu'),
    regulates: j['reg'] as bool? ?? true,
    pivot: j['pivot'] == true,
  );
}
