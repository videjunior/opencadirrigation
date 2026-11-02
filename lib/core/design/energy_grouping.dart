/// Grouping of the zones into system flows for the least pumping energy. The
/// pump of a group must deliver the highest head any of its zones needs, so
/// the zones that need less get more pressure than they use: grouping zones
/// with similar required heads saves energy. This is the sectoring problem of
/// Jiménez-Bello, Martínez Alzamora, Bou Soler & Bartolín Ayala (2010,
/// "Methodology for grouping intakes of pressurised irrigation networks into
/// sectors to minimise energy consumption", Biosystems Engineering 105(4))
/// and of Carrillo Cobo, Rodríguez Díaz, Montesinos, López Luque & Camacho
/// Poyato (2011, "Low energy consumption seasonal calendar for sectoring
/// operation in pressurized irrigation networks", Irrigation Science 29),
/// who search with a genetic algorithm and a network model; here a
/// constructive dynamic programme and a local search are compared with the
/// first-fit decreasing grouping by flow of `management.dart`.
///
/// Model. Zone i draws q_i for t_i hours and needs the pressure head h_i at
/// its valve, whose node lies at z_i. A group pumps Q = Σ q_i from the
/// source level z_s and must deliver H = max_i (z_i + h_i + k_i·Q^m) − z_s,
/// k_i·Q^m being the loss from the pump to valve i (m = 1.852, Hazen-Williams;
/// the whole group flow is taken along the path, exact for a single pipe and
/// on the safe side for a branched mainline). The pump holds H while any zone
/// of the group is open, so the group uses E = ρ·g·H·Σ q_i·t_i / η. A
/// `groupHead` callback can give H exactly (the designer solving the mainline
/// for that set of valves): the search runs on the formula, then a second
/// local search refines the grouping with the callback (at most
/// `maxHeadCalls` calls), and the energies reported use it.
///
/// Method. (1) First-fit decreasing by flow: the baseline. (2) The zones,
/// sorted by required piezometric head, are cut into consecutive groups by a
/// dynamic programme over (zones placed, groups used), every group within
/// the flow cap and the zones per group, for every number of groups allowed;
/// the cheapest within the daily hours is kept. (3) From the better of (1)
/// and (2): moves of one zone to another group (or to a new one when
/// allowed) and swaps of two zones, while one lowers the energy within every
/// limit. Deterministic.
library;

import 'dart:math' as math;

import '../model/project.dart';
import '../units.dart';
import 'management.dart';
import 'results.dart';

/// A zone to group.
class EnergyZone {
  const EnergyZone({required this.id, required this.flow, required this.requiredHead, this.elevation = 0, this.hours = 1, this.lossCoefficient = 0});

  /// Valve (demand) id.
  final String id;

  /// Flow (m³/s) and hours per irrigation.
  final double flow;
  final double hours;

  /// Pressure head needed at the valve's mainline node (m) and the node's
  /// elevation (m): ZoneResult.requiredUpstreamHead and valveElevation.
  final double requiredHead;
  final double elevation;

  /// Loss from the pump to the valve per (group flow)^m (m per (m³/s)^m; 0 =
  /// no loss).
  final double lossCoefficient;

  double get piezometric => elevation + requiredHead;

  Map<String, dynamic> toJson() => {'id': id, 'q': flow, 'h': hours, 'hreq': requiredHead, 'z': elevation, 'k': lossCoefficient};
  static EnergyZone fromJson(Map<String, dynamic> j) =>
      EnergyZone(id: j['id'] as String, flow: _d(j['q']), hours: _d(j['h'], 1), requiredHead: _d(j['hreq']), elevation: _d(j['z']), lossCoefficient: _d(j['k']));
}

/// Limits and constants of [groupZonesForEnergy].
class GroupingOptions {
  const GroupingOptions({
    this.maxFlow = 0,
    this.maxGroups = 0,
    this.maxHours = 0,
    this.maxZonesPerGroup = 0,
    this.sourceElevation = 0,
    this.pumpEfficiency = 0.65,
    this.lossExponent = 1.852,
    this.maxEvaluations = 20000,
    this.maxHeadCalls = 200,
  });

  /// Largest flow of a group (m³/s; 0 = none). A zone above it alone gets a
  /// group of its own.
  final double maxFlow;

  /// Most groups and most hours a day of all groups together (0 = none).
  final int maxGroups;
  final double maxHours;

  /// Most zones per group (0 = none).
  final int maxZonesPerGroup;

  /// Level the water is pumped from (m) and the pump efficiency.
  final double sourceElevation;
  final double pumpEfficiency;
  final double lossExponent;

  /// Bound on the candidates of the local search, and on the calls of the
  /// `groupHead` callback when one is given (each may be a network solution).
  final int maxEvaluations;
  final int maxHeadCalls;
}

/// A group of zones operating together.
class EnergyGroup {
  EnergyGroup({required this.zoneIds, required this.flow, required this.head, required this.hours, required this.volume, required this.energyKwh});
  final List<String> zoneIds;

  /// Flow (m³/s), pumping head (m), duration (h: the longest zone), volume
  /// pumped (m³) and energy (kWh) per irrigation.
  final double flow;
  final double head;
  final double hours;
  final double volume;
  final double energyKwh;

  Map<String, dynamic> toJson() => {'zones': zoneIds, 'q': flow, 'h': head, 't': hours, 'v': volume, 'e': energyKwh};
  static EnergyGroup fromJson(Map<String, dynamic> j) =>
      EnergyGroup(zoneIds: ((j['zones'] as List?) ?? []).cast<String>(), flow: _d(j['q']), head: _d(j['h']), hours: _d(j['t']), volume: _d(j['v']), energyKwh: _d(j['e']));
}

/// Outcome of [groupZonesForEnergy].
class EnergyGroupingResult {
  EnergyGroupingResult({required this.groups, required this.baseline, required this.codes});

  /// The groups found and the first-fit decreasing ones.
  final List<EnergyGroup> groups;
  final List<EnergyGroup> baseline;

  /// `grouping_oversized:<zone>` (a zone above the flow cap, alone),
  /// `grouping_groups_exceeded` and `grouping_hours_exceeded` (no grouping
  /// found within the limit: the closest is returned).
  final List<String> codes;

  double get energyKwh => groups.fold(0.0, (s, g) => s + g.energyKwh);
  double get baselineEnergyKwh => baseline.fold(0.0, (s, g) => s + g.energyKwh);
  double get savingKwh => baselineEnergyKwh - energyKwh;
  double get savingShare => baselineEnergyKwh > 0 ? savingKwh / baselineEnergyKwh : 0;
  double get hours => groups.fold(0.0, (s, g) => s + g.hours);

  Map<String, dynamic> toJson() => {'groups': groups.map((g) => g.toJson()).toList(), 'base': baseline.map((g) => g.toJson()).toList(), 'codes': codes};
  static EnergyGroupingResult fromJson(Map<String, dynamic> j) => EnergyGroupingResult(
    groups: [for (final g in (j['groups'] as List?) ?? []) EnergyGroup.fromJson(g as Map<String, dynamic>)],
    baseline: [for (final g in (j['base'] as List?) ?? []) EnergyGroup.fromJson(g as Map<String, dynamic>)],
    codes: ((j['codes'] as List?) ?? []).cast<String>(),
  );
}

/// Groups [zones] for the least pumping energy (see the library comment).
EnergyGroupingResult groupZonesForEnergy(List<EnergyZone> zones, {GroupingOptions options = const GroupingOptions(), double Function(List<EnergyZone> group)? groupHead}) =>
    _Grouper(zones, options, groupHead).run();

/// Zones of a design: every zone result of [results] with its flow, required
/// head at the valve and valve elevation, the hours of the system flow that
/// holds it (else [defaultHours]) and the loss from the supply estimated
/// from that flow's analysis (the supply head plus the pump heads less the
/// head at the valve, over the flow's total flow to the power m). Pivots are
/// left out (their results do not carry the node elevation). The source
/// level is the elevation of the first supply of the analyses (else 0).
/// The valve-in-head stations the system flows schedule are zones too, at
/// the node of their most demanding head (the highest need above the
/// source over the flows they run in) with their largest flow; a station
/// no flow lists runs in every flow and stays out of the grouping.
(List<EnergyZone>, double) energyZonesFromDesign(Project p, DesignResults results, {double defaultHours = 1, double lossExponent = 1.852}) {
  final hours = <String, double>{};
  for (final f in p.systemFlows) {
    for (final v in f.valveIds) {
      hours[v] = math.max(hours[v] ?? 0, f.durationHours);
    }
  }
  final loss = <String, double>{};
  double? source;
  final heads = <String, VihDuty>{};
  final headFlow = <String, double>{};
  for (final f in results.systemFlows) {
    for (final h in f.heads) {
      if (!h.scheduled || !(h.flow > 0)) continue;
      headFlow[h.stationId] = math.max(headFlow[h.stationId] ?? 0, h.flow);
      final cur = heads[h.stationId];
      if (cur == null || h.elevation + h.requiredHead > cur.elevation + cur.requiredHead) heads[h.stationId] = h;
    }
    if (f.supplies.isEmpty || f.totalFlow <= 0) continue;
    final s = f.supplies.first;
    source ??= s.elevation;
    final pumps = f.devices.fold(0.0, (a, d) => a + math.max(0.0, d.pumpHead));
    final top = s.elevation + s.head + pumps;
    for (final v in f.valves) {
      final z = results.zones[v.valveId]?.valveElevation;
      if (z == null) continue;
      final k = math.max(0.0, top - (z + v.availableHead)) / math.pow(f.totalFlow, lossExponent);
      loss[v.valveId] = math.max(loss[v.valveId] ?? 0, k);
    }
    for (final h in f.heads) {
      if (!h.scheduled) continue;
      final k = math.max(0.0, top - (h.elevation + h.availableHead)) / math.pow(f.totalFlow, lossExponent);
      loss[h.stationId] = math.max(loss[h.stationId] ?? 0, k);
    }
  }
  final zones = [
    for (final z in results.zones.values)
      if (z.totalFlow > 0)
        EnergyZone(id: z.valveId, flow: z.totalFlow, requiredHead: z.requiredUpstreamHead, elevation: z.valveElevation, hours: hours[z.valveId] ?? defaultHours, lossCoefficient: loss[z.valveId] ?? 0),
    for (final h in heads.values)
      EnergyZone(
        id: h.stationId,
        flow: headFlow[h.stationId]!,
        requiredHead: h.requiredHead,
        elevation: h.elevation,
        hours: hours[h.stationId] ?? defaultHours,
        lossCoefficient: loss[h.stationId] ?? 0,
      ),
  ];
  return (zones, source ?? 0);
}

/// System flows for the [groups] of [p], named and started like those of
/// [autoSystemFlows] (one after the other from [firstStartHour], each as long
/// as its group). [label] translates `name.flow`.
List<SystemFlow> systemFlowsFromGroups(Project p, List<EnergyGroup> groups, {double firstStartHour = 6, String Function(String key) label = _id}) {
  final drawn = demandIds(p);
  int rank(String id) {
    final i = drawn.indexOf(id);
    return i < 0 ? drawn.length : i;
  }

  final sorted = [
    for (final g in groups) [...g.zoneIds]..sort((a, b) => rank(a).compareTo(rank(b))),
  ];
  final order = List<int>.generate(groups.length, (i) => i)..sort((a, b) => rank(sorted[a].first).compareTo(rank(sorted[b].first)));
  final taken = {for (final f in p.systemFlows) f.id};
  final out = <SystemFlow>[];
  var start = firstStartHour;
  for (var k = 0; k < order.length; k++) {
    final ids = sorted[order[k]];
    var id = 'sf${k + 1}';
    for (var n = 2; taken.contains(id); n++) {
      id = 'sf${k + 1}_$n';
    }
    final dur = groups[order[k]].hours > 0 ? groups[order[k]].hours : 1.0;
    out.add(SystemFlow(id: id, name: '${label('name.flow')} ${k + 1} — ${ids.map((v) => demandName(p, v)).join(' + ')}', valveIds: ids.toSet(), startHour: start % 24, durationHours: dur));
    start += dur;
  }
  return out;
}

String _id(String k) => k;

class _Grouper {
  _Grouper(this.zones, this.options, this.groupHead);
  final List<EnergyZone> zones;
  final GroupingOptions options;
  final double Function(List<EnergyZone> group)? groupHead;
  final List<String> codes = [];
  final Map<String, double> _headCache = {};

  bool _oversized(int i) => options.maxFlow > 0 && zones[i].flow > options.maxFlow + 1e-12;

  /// A group may hold [members]: within the flow cap (or a single zone) and
  /// the zones per group.
  bool _fits(List<int> members) {
    if (members.isEmpty) return true;
    if (options.maxZonesPerGroup > 0 && members.length > options.maxZonesPerGroup) return false;
    if (members.length == 1) return true;
    final q = members.fold(0.0, (s, i) => s + zones[i].flow);
    return options.maxFlow <= 0 || q <= options.maxFlow + 1e-12;
  }

  double _formulaHead(List<int> members, double q) {
    var h = -double.infinity;
    for (final i in members) {
      final z = zones[i];
      h = math.max(h, z.piezometric + (z.lossCoefficient > 0 ? z.lossCoefficient * math.pow(q, options.lossExponent) : 0));
    }
    return math.max(0.0, h - options.sourceElevation);
  }

  /// Calls of [groupHead] so far (each a network solution for the caller).
  int _calls = 0;

  double _head(List<int> members, {bool exact = true}) {
    final q = members.fold(0.0, (s, i) => s + zones[i].flow);
    final cb = groupHead;
    if (cb == null || !exact) return _formulaHead(members, q);
    final key = ([...members]..sort()).join(',');
    return _headCache[key] ??= () {
      _calls++;
      return math.max(0.0, cb([for (final i in members) zones[i]]));
    }();
  }

  /// Energy (kWh) of a group.
  double _energy(List<int> members, {bool exact = true}) {
    if (members.isEmpty) return 0;
    final volume = members.fold(0.0, (s, i) => s + zones[i].flow * zones[i].hours * 3600);
    return waterDensity * gravity * _head(members, exact: exact) * volume / math.max(options.pumpEfficiency, 0.05) / 3.6e6;
  }

  double _hours(List<int> members) => members.fold(0.0, (m, i) => math.max(m, zones[i].hours));

  /// (violation of the soft limits, energy) of a grouping, by the formula or,
  /// with [exact], by [groupHead].
  (double, double) _score(List<List<int>> groups, {bool exact = false}) {
    var v = 0.0;
    if (options.maxGroups > 0 && groups.length > options.maxGroups) v += groups.length - options.maxGroups;
    if (options.maxHours > 0) {
      final h = groups.fold(0.0, (s, g) => s + _hours(g));
      if (h > options.maxHours + 1e-9) v += (h - options.maxHours) / options.maxHours;
    }
    return (v, groups.fold(0.0, (s, g) => s + _energy(g, exact: exact)));
  }

  static bool _better((double, double) a, (double, double) b) => a.$1 < b.$1 - 1e-12 || ((a.$1 - b.$1).abs() <= 1e-12 && a.$2 < b.$2 - 1e-9 * math.max(1.0, b.$2.abs()));

  /// First-fit decreasing by flow, as `autoSystemFlows`.
  List<List<int>> _firstFit() {
    final order = List<int>.generate(zones.length, (i) => i)..sort((a, b) => zones[b].flow != zones[a].flow ? zones[b].flow.compareTo(zones[a].flow) : a.compareTo(b));
    final bins = <List<int>>[];
    for (final i in order) {
      if (_oversized(i)) {
        bins.add([i]);
        continue;
      }
      var placed = false;
      for (final b in bins) {
        if (_oversized(b.first)) continue;
        if (_fits([...b, i])) {
          b.add(i);
          placed = true;
          break;
        }
      }
      if (!placed) bins.add([i]);
    }
    return bins;
  }

  /// Consecutive groups of the zones sorted by piezometric head, for every
  /// number of groups; the best within the hours (or the least violating).
  List<List<int>>? _contiguous() {
    final n = zones.length;
    if (n == 0) return null;
    final order = List<int>.generate(n, (i) => i)..sort((a, b) => zones[b].piezometric != zones[a].piezometric ? zones[b].piezometric.compareTo(zones[a].piezometric) : a.compareTo(b));
    final gmax = options.maxGroups > 0 ? math.min(options.maxGroups, n) : n;
    // cost of the block order[i..j)
    final block = List.generate(n + 1, (_) => List<double>.filled(n + 1, double.nan));
    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j <= n; j++) {
        final members = order.sublist(i, j);
        if (!_fits(members)) break;
        block[i][j] = _energy(members, exact: false);
      }
    }
    final best = List.generate(n + 1, (_) => List<double>.filled(gmax + 1, double.infinity));
    final cut = List.generate(n + 1, (_) => List<int>.filled(gmax + 1, -1));
    best[0][0] = 0;
    for (var j = 1; j <= n; j++) {
      for (var g = 1; g <= gmax; g++) {
        for (var i = j - 1; i >= 0; i--) {
          final c = block[i][j];
          if (c.isNaN) break;
          final v = best[i][g - 1] + c;
          if (v < best[j][g]) {
            best[j][g] = v;
            cut[j][g] = i;
          }
        }
      }
    }
    List<List<int>>? chosen;
    (double, double)? chosenScore;
    for (var g = 1; g <= gmax; g++) {
      if (best[n][g] == double.infinity) continue;
      final groups = <List<int>>[];
      var j = n;
      for (var k = g; k > 0; k--) {
        final i = cut[j][k];
        groups.insert(0, order.sublist(i, j));
        j = i;
      }
      final s = _score(groups);
      if (chosenScore == null || _better(s, chosenScore)) {
        chosen = groups;
        chosenScore = s;
      }
    }
    return chosen;
  }

  /// Moves and swaps while they improve the score (by the formula, or with
  /// [exact] by [groupHead] until [GroupingOptions.maxHeadCalls] calls).
  List<List<int>> _improve(List<List<int>> start, {bool exact = false}) {
    var groups = [
      for (final g in start) [...g],
    ];
    var score = _score(groups, exact: exact);
    var improved = true;
    final budget = options.maxEvaluations;
    var tries = 0;
    (double, double) scoreOf(List<List<int>> cand) {
      // out of calls: every further candidate counts as no better
      if (exact && _calls >= options.maxHeadCalls) tries = budget + 1;
      return tries > budget ? (double.infinity, double.infinity) : _score(cand, exact: exact);
    }

    while (improved && tries < budget) {
      improved = false;
      // move one zone
      outer:
      for (var a = 0; a < groups.length; a++) {
        for (var x = 0; x < groups[a].length; x++) {
          final z = groups[a][x];
          final canOpen = options.maxGroups <= 0 || groups.length < options.maxGroups;
          for (var b = 0; b <= groups.length; b++) {
            if (b == a || (b == groups.length && (!canOpen || groups[a].length == 1))) continue;
            if (++tries > budget) break outer;
            final from = [...groups[a]]..removeAt(x);
            final to = b == groups.length ? [z] : [...groups[b], z];
            if (!_fits(to)) continue;
            final cand = [
              for (var k = 0; k < groups.length; k++)
                if (k == a) from else if (k == b) to else groups[k],
              if (b == groups.length) to,
            ].where((g) => g.isNotEmpty).toList();
            final s = scoreOf(cand);
            if (_better(s, score)) {
              groups = cand;
              score = s;
              improved = true;
              break outer;
            }
          }
        }
      }
      if (improved) continue;
      // swap two zones of different groups
      outer2:
      for (var a = 0; a < groups.length; a++) {
        for (var b = a + 1; b < groups.length; b++) {
          for (var x = 0; x < groups[a].length; x++) {
            for (var y = 0; y < groups[b].length; y++) {
              if (++tries > budget) break outer2;
              final ga = [...groups[a]]..[x] = groups[b][y];
              final gb = [...groups[b]]..[y] = groups[a][x];
              if (!_fits(ga) || !_fits(gb)) continue;
              final cand = [for (var k = 0; k < groups.length; k++) k == a ? ga : (k == b ? gb : groups[k])];
              final s = scoreOf(cand);
              if (_better(s, score)) {
                groups = cand;
                score = s;
                improved = true;
                break outer2;
              }
            }
          }
        }
      }
    }
    return groups;
  }

  List<EnergyGroup> _groups(List<List<int>> groups) {
    final sorted = [
      for (final g in groups) [...g]..sort(),
    ]..sort((a, b) => a.first.compareTo(b.first));
    return [
      for (final g in sorted)
        EnergyGroup(
          zoneIds: [for (final i in g) zones[i].id],
          flow: g.fold(0.0, (s, i) => s + zones[i].flow),
          head: _head(g),
          hours: _hours(g),
          volume: g.fold(0.0, (s, i) => s + zones[i].flow * zones[i].hours * 3600),
          energyKwh: _energy(g),
        ),
    ];
  }

  EnergyGroupingResult run() {
    for (var i = 0; i < zones.length; i++) {
      if (_oversized(i)) codes.add('grouping_oversized:${zones[i].id}');
    }
    final ffd = _firstFit();
    final contiguous = _contiguous();
    var start = ffd;
    if (contiguous != null && _better(_score(contiguous), _score(ffd))) start = contiguous;
    var best = _improve(start);
    // refine with the caller's heads when given
    if (groupHead != null) best = _improve(best, exact: true);
    final (violation, _) = _score(best);
    if (violation > 0) {
      if (options.maxGroups > 0 && best.length > options.maxGroups) codes.add('grouping_groups_exceeded');
      if (options.maxHours > 0 && best.fold(0.0, (s, g) => s + _hours(g)) > options.maxHours + 1e-9) codes.add('grouping_hours_exceeded');
    }
    return EnergyGroupingResult(groups: _groups(best), baseline: _groups(ffd), codes: codes);
  }
}

double _d(Object? v, [double def = 0]) => (v as num?)?.toDouble() ?? def;
