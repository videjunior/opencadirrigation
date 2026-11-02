/// A reservoir or dam behind a water supply item (1.6.0 MOT+, PRD-16): the
/// closed outline drawn around it, how its basin is made, its levels and
/// the water that flows into it. `design/reservoir.dart` works out its
/// stage–area–volume curve from the terrain; the 24-hour simulation lets
/// its level fall and rise.
library;

import 'read_report.dart';

/// How the basin of a reservoir is made.
enum ReservoirKind {
  /// A dam or a natural pond: the basin is the ground inside the outline.
  terrain,

  /// Excavated: a flat bottom, the sides sloping up to the outline (the
  /// water line at the full level) at the side slope.
  excavated,
}

class ReservoirSpec {
  ReservoirSpec({this.outlineId = '', this.kind = ReservoirKind.terrain, this.fullLevelM = 0, this.minLevelM, this.initialLevelM, this.bottomM, this.sideSlope = 2, this.inflow = 0});

  /// The closed polyline or area item of the drawing that bounds the water
  /// at the full level.
  String outlineId;
  ReservoirKind kind;

  /// Elevation (m) of the full water level.
  double fullLevelM;

  /// Elevation (m) of the lowest level the intake draws from (null = the
  /// bottom): the design pumps from it, the worst case.
  double? minLevelM;

  /// Elevation (m) of the water at the start of the day in the 24-hour
  /// simulation (null = full).
  double? initialLevelM;

  /// Excavated: elevation (m) of the flat bottom (null = 3 m below the full
  /// level) and the slope of the sides (horizontal per vertical).
  double? bottomM;
  double sideSlope;

  /// Water flowing in all the time (m³/s): a stream, a spring, a well.
  double inflow;

  /// Fields of a newer version, kept as read.
  Map<String, dynamic>? extra;

  /// The level the design draws from (m): the lowest operating level, else
  /// the full level; null while the full level is not set.
  double? get designLevelM => fullLevelM != 0 ? (minLevelM ?? fullLevelM) : null;

  ReservoirSpec copy() =>
      ReservoirSpec(outlineId: outlineId, kind: kind, fullLevelM: fullLevelM, minLevelM: minLevelM, initialLevelM: initialLevelM, bottomM: bottomM, sideSlope: sideSlope, inflow: inflow)
        ..extra = extra;

  Map<String, dynamic> toJson() => {
    ...?extra,
    'outline': outlineId,
    if (kind != ReservoirKind.terrain) 'kind': kind.name,
    'full': fullLevelM,
    if (minLevelM != null) 'min': minLevelM,
    if (initialLevelM != null) 'init': initialLevelM,
    if (bottomM != null) 'bottom': bottomM,
    if (sideSlope != 2) 'slope': sideSlope,
    if (inflow > 0) 'inflow': inflow,
  };

  /// Reads a reservoir; null when [json] holds none. Options this version
  /// does not know take their default (noted in [report]).
  static ReservoirSpec? fromJson(Object? json, {ProjectReadReport? report}) {
    if (json is! Map) return null;
    final j = KeyLog(json.cast<String, dynamic>());
    double? n(String k) {
      final v = j[k];
      return v is num && v.isFinite ? v.toDouble() : null;
    }

    final outline = j['outline'];
    return ReservoirSpec(
      outlineId: outline is String ? outline : '',
      kind: enumByName(ReservoirKind.values, j['kind'], ReservoirKind.terrain, report: report, key: 'kind'),
      fullLevelM: n('full') ?? 0,
      minLevelM: n('min'),
      initialLevelM: n('init'),
      bottomM: n('bottom'),
      sideSlope: (n('slope') ?? 2).clamp(0.0, 20.0).toDouble(),
      inflow: (n('inflow') ?? 0).clamp(0.0, double.infinity).toDouble(),
    )..extra = j.unread;
  }
}
