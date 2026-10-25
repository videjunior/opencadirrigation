/// Valve-in-head stations. A mainline outlet (an [OutletEntity] drawn in the
/// mainline scope) is a sprinkler with its valve in the head: it hangs on
/// the mainline and opens when its controller station is on. The station is
/// the unit the system flows schedule and the controller wires:
///
/// * a head whose `zoneName` is empty is a station of its own, and its
///   outlet id is the station id;
/// * heads sharing a non-empty `zoneName` (trimmed) are one station, id
///   `vih:<zoneName>` ([vihStationId]); their solenoids hang in parallel on
///   one station conductor of one controller, so they open and close
///   together.
///
/// A system flow schedules a station by listing its id in
/// [SystemFlow.valveIds], beside the zone valves and pivots. A station some
/// flow lists runs only in the flows that list it, and the design then
/// gives its heads their nominal pressure as it gives a zone valve the
/// pressure its zone needs. A station no flow lists runs in every flow, as
/// every mainline outlet did before the heads could be scheduled, so the
/// projects that never scheduled them keep their results.
///
/// Renaming a station (the `zoneName` of all its heads) changes its id: the
/// flows that listed the old id no longer run it, and the advisor reports
/// the station as in no flow.
library;

import '../model/entities.dart';
import '../model/project.dart';

/// Prefix of the id of a station of several heads.
const vihPrefix = 'vih:';

/// Whether [e] is a valve-in-head sprinkler (an outlet on the mainline).
bool isVihHead(Entity? e) => e is OutletEntity && e.scope == HydraulicScope.mainline;

/// Station id of the head [o] (see the library comment).
String vihStationId(OutletEntity o) {
  final z = o.zoneName.trim();
  return z.isEmpty ? o.id : '$vihPrefix$z';
}

/// The valve-in-head stations of a project and how its system flows
/// schedule them.
class VihStations {
  const VihStations._(this.heads, this.stationOf, this.scheduled, this._names);

  /// No station: every mainline outlet a plain emitter of every flow, as
  /// before the heads could be scheduled.
  const VihStations.none() : heads = const {}, stationOf = const {}, scheduled = const {}, _names = const {};

  factory VihStations.of(Project p) {
    final heads = <String, List<String>>{};
    final stationOf = <String, String>{};
    final names = <String, String>{};
    for (final e in p.entities) {
      if (e is! OutletEntity || e.scope != HydraulicScope.mainline) continue;
      final s = vihStationId(e);
      heads.putIfAbsent(s, () => []).add(e.id);
      stationOf[e.id] = s;
      names.putIfAbsent(s, () => s == e.id ? (e.name.isNotEmpty ? e.name : e.id) : e.zoneName.trim());
    }
    final scheduled = {
      for (final f in p.systemFlows)
        for (final id in f.valveIds)
          if (heads.containsKey(id)) id,
    };
    return VihStations._(heads, stationOf, scheduled, names);
  }

  /// Head (outlet) ids of every station in drawing order, the stations in
  /// the drawing order of their first head.
  final Map<String, List<String>> heads;

  /// Station id of every head.
  final Map<String, String> stationOf;

  /// Stations some system flow of the project lists.
  final Set<String> scheduled;
  final Map<String, String> _names;

  bool get isEmpty => heads.isEmpty;

  bool isStation(String id) => heads.containsKey(id);

  /// Display name: the station name of a group, the name (else the id) of a
  /// head of its own.
  String nameOf(String id) => _names[id] ?? (id.startsWith(vihPrefix) ? id.substring(vihPrefix.length) : id);

  /// Whether station [id] runs in a flow that opens [listed].
  bool runs(String id, Set<String> listed) => !scheduled.contains(id) || listed.contains(id);

  /// Whether the head [outletId] runs in a flow that opens [listed]; true
  /// for an outlet that is no valve-in-head head.
  bool headRuns(String outletId, Set<String> listed) {
    final s = stationOf[outletId];
    return s == null || runs(s, listed);
  }

  /// Whether the head [outletId] belongs to a station some flow lists.
  bool headScheduled(String outletId) => scheduled.contains(stationOf[outletId]);

  /// The stations that run in a flow opening [listed], in drawing order.
  List<String> runningIn(Set<String> listed) => [
    for (final s in heads.keys)
      if (runs(s, listed)) s,
  ];

  /// Stations no flow lists although the project has [flows]: they run in
  /// every flow.
  List<String> unscheduled(List<SystemFlow> flows) => flows.isEmpty
      ? const []
      : [
          for (final s in heads.keys)
            if (!scheduled.contains(s)) s,
        ];

  /// The flows of [flows] that run station [id] (all of them while no flow
  /// lists it).
  List<SystemFlow> flowsOf(String id, List<SystemFlow> flows) => [
    for (final f in flows)
      if (runs(id, f.valveIds)) f,
  ];
}
