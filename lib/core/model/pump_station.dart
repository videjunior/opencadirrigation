/// A pump station drawn as one pump item: the item's own pump (the lead
/// pump) and the units installed with it, in parallel or in series, on
/// duty or on standby, with the rule that starts them (1.6.0, PRD-17).
library;

import 'read_report.dart';

/// How the duty pumps of a station are joined: in parallel they share the
/// flow at one head, in series they carry the same flow and add their heads.
enum PumpArrangement { parallel, series }

/// One more pump of a station: a catalogue pump (null = the model of the
/// lead pump) on duty or on standby. A standby pump stays off in every
/// system flow and stands in for one that fails.
class PumpUnit {
  PumpUnit({this.specId, this.standby = false});

  String? specId;
  bool standby;

  /// Fields of a newer version, kept as read.
  Map<String, dynamic>? extra;

  PumpUnit copy() => PumpUnit(specId: specId, standby: standby)..extra = extra;

  Map<String, dynamic> toJson() => {...?extra, if (specId != null) 'spec': specId, if (standby) 'sb': true};

  static PumpUnit fromJson(Object? json) {
    if (json is! Map) return PumpUnit();
    final j = KeyLog(json.cast<String, dynamic>());
    final s = j['spec'];
    return PumpUnit(specId: s is String && s.isNotEmpty ? s : null, standby: j['sb'] == true)..extra = j.unread;
  }
}

/// The pumps a pump item stands for besides its own: [units] after the lead
/// pump, their [arrangement], and whether the duty pumps start one after
/// another as the system flows need them ([staged]) or all run together.
class PumpStation {
  PumpStation({List<PumpUnit>? units, this.arrangement = PumpArrangement.parallel, this.staged = true}) : units = units ?? [];

  /// The units after the lead pump, in their starting order.
  final List<PumpUnit> units;
  PumpArrangement arrangement;

  /// Duty pumps start one after another, in their order, until the running
  /// ones give the flow of the system flow within the range of every pump
  /// and the pressure its valves need; false = every duty pump runs in every
  /// system flow.
  bool staged;

  /// Fields of a newer version, kept as read.
  Map<String, dynamic>? extra;

  /// Duty pumps of the station, the lead pump included.
  int get dutyCount => 1 + units.where((u) => !u.standby).length;

  /// Pumps kept on standby.
  int get standbyCount => units.where((u) => u.standby).length;

  /// Whether the station is more than the lead pump.
  bool get isEmpty => units.isEmpty;

  PumpStation copy() => PumpStation(units: [for (final u in units) u.copy()], arrangement: arrangement, staged: staged)..extra = extra;

  Map<String, dynamic> toJson() => {
    ...?extra,
    'units': [for (final u in units) u.toJson()],
    if (arrangement != PumpArrangement.parallel) 'arr': arrangement.name,
    if (!staged) 'staged': false,
  };

  /// Reads a station; null when [json] holds none (a single pump). Options
  /// this version does not know take their default (noted in [report]).
  static PumpStation? fromJson(Object? json, {ProjectReadReport? report}) {
    if (json is! Map) return null;
    final j = KeyLog(json.cast<String, dynamic>());
    final units = [for (final u in (j['units'] as List?) ?? const []) PumpUnit.fromJson(u)];
    final s = PumpStation(
      units: units,
      arrangement: enumByName(PumpArrangement.values, j['arr'], PumpArrangement.parallel, report: report, key: 'arr'),
      staged: j['staged'] as bool? ?? true,
    )..extra = j.unread;
    return s.isEmpty && s.extra == null ? null : s;
  }
}
