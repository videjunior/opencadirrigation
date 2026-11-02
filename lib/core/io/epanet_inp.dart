/// EPANET 2.2 input files (.inp): the hydraulic network of a project written
/// for EPANET (US EPA, public domain) and a reader that builds our
/// [HydraulicNetwork] from any input file.
///
/// The writer starts from the graph of [NetworkBuilder] (laterals lumped into
/// emitter nodes, devices inserted in line, a valve between mainline and zone)
/// with the pipe specs the entities carry (a designed project carries the
/// sized ones) and the project catalogue: inner diameters, Hazen-Williams C
/// (with the project's C adjustment) or Darcy-Weisbach roughness, the
/// lateral barb losses as minor losses, emitter and nozzle curves, valve and
/// pump curves. Pipe lengths include the minor-loss allowance of the design
/// parameters (equivalent length), as in our own analysis.
///
/// Mapping to the EPANET 2.2 input format (EPANET 2.2 Users Manual,
/// EPA/600/R-20/133, chapter "Input file format", sections [TITLE] … [END]):
/// - water supplies and the inlet of an exported zone are RESERVOIRS whose head
///   is the elevation plus the supply pressure (from the results, the design
///   head of a fixed supply or [EpanetOptions.supplyHeads]);
/// - pipes, laterals and tapes are PIPES; check valves are a GPV with their
///   loss curve in series with a short pipe of status CV;
/// - pumps are PUMPS with a multi-point HEAD curve sampled from the
///   catalogue parabola (EPANET interpolates it linearly) and their SPEED;
/// - pressure-reducing, pressure-sustaining and flow-control valves are PRV,
///   PSV and FCV (setting = downstream or upstream pressure, or the flow; the
///   open loss as an equivalent minor-loss coefficient); zone valves and
///   devices with a loss h = K·Q^n + C are GPV with a HEADLOSS curve;
/// - lumped emitters q = k·H^x become [EMITTERS] coefficients in the chosen
///   flow units per metre^γ, γ being the single global EMITTER EXPONENT of
///   EPANET (the most common exponent of the network). An emitter with
///   another exponent keeps its flow at its nominal pressure (code
///   `epanet_emitter_exponent:<entity>`); a pressure-compensating one
///   (x < 0.1) and a demand point are a fixed base demand at their nominal
///   flow (`epanet_emitter_compensating:<entity>`). A junction carrying one
///   emitter group lies at the emitter's elevation (riser and burial depth
///   included); further groups at a node hang from short pipes;
/// - [COORDINATES] and [VERTICES] are UTM (the project georeference) or local
///   metres; [OPTIONS] give the units (LPS or CMH, PRESSURE METERS), the
///   head-loss formula (H-W, D-W, or C-M for Manning; Scobey is written as
///   D-W with a warning) and the relative viscosity of the water at
///   the design temperature;
/// - a mainline outlet (valve-in-head head) is an emitter in the system flow
///   exported when that flow runs its station (`valve_in_head.dart`: a
///   station some flow lists runs only in those flows, one that no flow lists
///   in all of them), and in the export with everything open; off, its
///   junction stays without an emitter.
library;

import 'dart:math' as math;

import '../design/designer.dart';
import '../design/network_builder.dart';
import '../design/results.dart';
import '../hydraulics/emitter.dart';
import '../hydraulics/friction.dart';
import '../hydraulics/minor_losses.dart';
import '../hydraulics/network.dart';
import '../hydraulics/pump.dart';
import '../model/catalog.dart';
import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import '../units.dart';
import 'datum.dart';
import 'dxf.dart';
import 'geo.dart';

/// Flow units written to [OPTIONS] (SI: pressures in metres, diameters in mm).
enum EpanetFlowUnits {
  lps('LPS', 1000),
  cmh('CMH', 3600);

  const EpanetFlowUnits(this.keyword, this.perM3s);
  final String keyword;

  /// Units per m³/s.
  final double perM3s;
}

enum EpanetScopeKind { zone, systemFlow, all }

/// What part of the project goes into the file.
class EpanetScope {
  /// One zone and its valve, fed by a reservoir at the pressure the zone needs
  /// upstream of the valve.
  const EpanetScope.zone(String valveId) : kind = EpanetScopeKind.zone, id = valveId, detailedZones = true, includeClosedZones = false;

  /// The mainline with system flow [flowId] running (an id of
  /// `project.systemFlows`, or `auto` when the project defines none): the
  /// zones of the flow as demands at their valves, or with [detailedZones]
  /// the zones themselves behind their valves; [includeClosedZones] adds the
  /// other zones with their valves CLOSED in [STATUS].
  const EpanetScope.systemFlow(String flowId, {this.detailedZones = false, this.includeClosedZones = false}) : kind = EpanetScopeKind.systemFlow, id = flowId;

  /// Everything, every valve open.
  const EpanetScope.all() : kind = EpanetScopeKind.all, id = '', detailedZones = true, includeClosedZones = false;

  final EpanetScopeKind kind;
  final String id;
  final bool detailedZones;
  final bool includeClosedZones;
}

class EpanetOptions {
  const EpanetOptions({this.flowUnits = EpanetFlowUnits.lps, this.mergeChains = false, this.supplyHeads = const {}, this.title = const [], this.accuracy = 1e-4, this.trials = 500});
  final EpanetFlowUnits flowUnits;

  /// Joins runs of identical pipes through plain nodes into one pipe with
  /// [VERTICES] (a lighter file; the pressure at those vertices is not reported).
  final bool mergeChains;

  /// Pressure head (m) of supplies by entity id, overriding the results.
  final Map<String, double> supplyHeads;

  /// [TITLE] lines (translated by the caller); the project name by default.
  final List<String> title;

  /// ACCURACY of [OPTIONS]: EPANET's relative flow change for convergence.
  /// On networks of thousands of emitters EPANET stalls near 10⁻⁴, so a
  /// tighter value ends "unbalanced" with the same heads; our reader solves
  /// to 10⁻⁵ whatever the file says.
  final double accuracy;

  /// TRIALS of [OPTIONS].
  final int trials;
}

/// The written file and how the network maps to it.
class EpanetExport {
  EpanetExport({required this.text, required this.warnings, required this.nodeIds, required this.linkIds, required this.reversedLinks, required this.emitterExponent, required this.crs});
  final String text;

  /// Message codes (`epanet_emitter_exponent:<entity>`, …).
  final List<String> warnings;

  /// Network node id → EPANET node id (junctions merged away are absent).
  final Map<String, String> nodeIds;

  /// Network link id → EPANET link id (a merged chain maps several links to one).
  final Map<String, String> linkIds;

  /// Network links drawn against the direction of their EPANET pipe.
  final Set<String> reversedLinks;
  final double emitterExponent;

  /// CRS of [COORDINATES]: the project's UTM zone, or local metres.
  final CrsInfo crs;
}

// ====================================================================== writer

class EpanetWriter {
  /// Writes the network of [project] for [scope]. Boundary conditions (zone
  /// inlet pressures, supply pressures, zone and pivot flows) come from
  /// [results] when given, else from an analysis run here.
  static EpanetExport write(Project project, {DesignResults? results, EpanetScope scope = const EpanetScope.all(), EpanetOptions options = const EpanetOptions()}) =>
      _InpBuilder(project, results, scope, options).build();
}

class _Jn {
  _Jn(this.id, this.elevation, this.p, {this.demand = 0, this.comment = ''});
  final String id;
  double elevation;
  final Pt p;
  double demand;
  double? emitter;
  String comment;
}

class _Rs {
  _Rs(this.id, this.head, this.p, this.comment);
  final String id;
  final double head;
  final Pt p;
  final String comment;
}

class _Pp {
  _Pp(this.id, this.n1, this.n2, this.length, this.diameterMm, this.roughness, this.minorK, {this.status = 'Open', this.comment = ''});
  final String id;
  String n1, n2;
  double length;
  final double diameterMm, roughness;
  double minorK;
  final String status;
  final String comment;
  final List<Pt> vertices = [];
}

class _Pu {
  _Pu(this.id, this.n1, this.n2, this.curve, this.speed, this.comment);
  final String id, n1, n2, curve;
  final double speed;
  final String comment;
}

class _Vl {
  _Vl(this.id, this.n1, this.n2, this.diameterMm, this.type, this.setting, this.minorK, this.comment);
  final String id;
  String n1, n2;
  final double diameterMm;
  final String type, setting;
  final double minorK;
  final String comment;
}

class _InpBuilder {
  _InpBuilder(this.project, this.results, this.scope, this.options);
  final Project project;
  final DesignResults? results;
  final EpanetScope scope;
  final EpanetOptions options;

  late final Designer designer = Designer(project);
  late final Map<String, Entity> _byId = {for (final e in project.entities) e.id: e};
  NetworkModel get model => designer.model;
  Catalog get catalog => project.catalog;
  DesignParameters get params => project.params;
  double get fq => options.flowUnits.perM3s;

  final warnings = <String>{};
  final junctions = <String, _Jn>{};
  final reservoirs = <String, _Rs>{};
  final pipes = <_Pp>[];
  final pumps = <_Pu>[];
  final valves = <_Vl>[];
  final curves = <String, (String, List<(double, double)>)>{};
  final status = <String, String>{};
  final labels = <(Pt, String)>[];
  final nodeIds = <String, String>{};
  final linkIds = <String, String>{};
  final reversed = <String>{};
  final keepNodes = <String>{};

  /// Flow (m³/s) seen through each network link in the analyses used.
  final linkFlow = <String, double>{};
  final zoneResults = <String, ZoneResult>{};
  final pivotFlows = <String, double>{};

  /// What the exported system flow lists: the mainline outlets
  /// (valve-in-head heads) whose station it does not run have no emitter
  /// (`valve_in_head.dart`); null for a zone.
  Set<String>? _listed;
  bool _runs(EmitterRef e) => _listed == null || designer.vih.headRuns(e.entityId, _listed!);

  EpanetExport build() {
    final linkById = {for (final l in model.links) l.id: l};
    final nodes = <String>{};
    final links = <String>{};
    final heads = <String, double>{};
    final demand = <String, double>{};
    String scopeLabel;
    switch (scope.kind) {
      case EpanetScopeKind.zone:
        final v = scope.id;
        final vn = model.valveNodes[v];
        if (vn == null) throw StateError('epanet_zone_unknown:$v');
        final zr = _zone(v);
        nodes
          ..addAll(model.zoneNodes[v] ?? const {})
          ..add(vn.$1);
        links
          ..addAll(model.zoneLinks[v] ?? const {})
          ..add('cv_$v');
        heads[vn.$1] = model.nodes[vn.$1]!.elevation + zr.requiredUpstreamHead;
        scopeLabel = 'zone: ${(project.byId(v) as ControlValveEntity?)?.zoneName ?? v}';
      case EpanetScopeKind.systemFlow:
      case EpanetScopeKind.all:
        final all = scope.kind == EpanetScopeKind.all;
        final flows = designer.effectiveSystemFlows();
        final SystemFlow sf;
        if (all) {
          // every valve-in-head station open too
          sf = SystemFlow(id: 'all', name: 'all', valveIds: {...model.valveNodes.keys, ...model.pivotNodes.keys, ...designer.vih.heads.keys});
        } else {
          sf = flows.where((f) => f.id == scope.id).firstOrNull ?? (throw StateError('epanet_flow_unknown:${scope.id}'));
        }
        _listed = sf.valveIds;
        scopeLabel = all ? 'all valves open' : 'system flow: ${sf.name}';
        nodes.addAll(model.mainlineNodes);
        links.addAll(model.mainlineLinks);
        final fr = _flowResult(sf, all);
        for (final s in project.entities.whereType<WaterSupplyEntity>()) {
          final nid = model.supplyNodes[s.id];
          if (nid == null || !model.mainlineNodes.contains(nid)) continue;
          heads[nid] = model.nodes[nid]!.elevation + _supplyHead(s, fr);
        }
        for (final vid in model.valveNodes.keys) {
          final open = sf.valveIds.contains(vid);
          if (!scope.detailedZones) {
            if (open) demand[model.valveNodes[vid]!.$1] = (demand[model.valveNodes[vid]!.$1] ?? 0) + _zone(vid).totalFlow;
            continue;
          }
          if (!open && !scope.includeClosedZones) continue;
          nodes.addAll(model.zoneNodes[vid] ?? const {});
          links
            ..addAll(model.zoneLinks[vid] ?? const {})
            ..add('cv_$vid');
          if (!open) status['cv_$vid'] = 'Closed';
        }
        for (final pid in model.pivotNodes.keys) {
          if (!sf.valveIds.contains(pid)) continue;
          final nid = model.pivotNodes[pid]!;
          demand[nid] = (demand[nid] ?? 0) + _pivotFlow(pid);
        }
    }
    // nodes without any link of the scope would be unconnected in EPANET
    final touched = <String>{};
    for (final lid in links) {
      final l = linkById[lid];
      if (l == null) continue;
      touched
        ..add(l.from)
        ..add(l.to);
    }
    nodes.retainWhere(touched.contains);
    links.retainWhere((id) => linkById[id] != null && nodes.contains(linkById[id]!.from) && nodes.contains(linkById[id]!.to));
    if (heads.keys.where(nodes.contains).isEmpty) warnings.add('epanet_no_source');
    if (params.frictionMethod == FrictionMethod.scobey) warnings.add('epanet_friction_scobey');

    // the downstream nodes of PRVs keep their pipe elevation (the setting is
    // a pressure there): emitters hang from them through short pipes
    final prvDownstream = <String>{};
    for (final lid in links) {
      final l = linkById[lid]!;
      if (l.kind == GLinkKind.prv || (l.kind == GLinkKind.controlValve && _isPrvValve(l))) prvDownstream.add(l.to);
    }
    final exponent = _emitterExponent(nodes);
    for (final e in project.entities) {
      if (e is JunctionEntity) {
        for (final n in model.nodes.values) {
          if (n.entityIds.contains(e.id)) keepNodes.add(n.id);
        }
      }
    }
    // nodes
    for (final id in model.nodes.keys) {
      if (!nodes.contains(id)) continue;
      final n = model.nodes[id]!;
      final comment = _nodeComment(n);
      if (heads.containsKey(id)) {
        reservoirs[id] = _Rs(id, heads[id]!, n.p, comment);
        nodeIds[id] = id;
        continue;
      }
      final j = _Jn(id, n.elevation, n.p, demand: (demand[id] ?? 0) * fq, comment: comment);
      junctions[id] = j;
      nodeIds[id] = id;
      _emitters(n, j, exponent, satellitesOnly: prvDownstream.contains(id));
    }
    // links
    for (final l in model.links) {
      if (!links.contains(l.id)) continue;
      switch (l.kind) {
        case GLinkKind.pipe:
          _pipe(l);
        case GLinkKind.controlValve:
          _controlValve(l);
        case GLinkKind.device:
          _device(l);
        case GLinkKind.prv:
          _prv(l, l.settingM, catalog.valve(l.valveSpecId), l.id);
        case GLinkKind.psv:
          _prv(l, l.settingM, catalog.valve(l.valveSpecId), l.id, type: 'PSV');
        case GLinkKind.fcv:
          _prv(l, l.settingFlow * fq, catalog.valve(l.valveSpecId), l.id, type: 'FCV');
        case GLinkKind.pump:
          _pump(l);
      }
    }
    _separatePrvs();
    if (options.mergeChains) _mergeChains();
    for (final v in project.entities.whereType<ControlValveEntity>()) {
      final vn = model.valveNodes[v.id];
      if (vn != null && nodes.contains(vn.$2)) labels.add((v.position, v.zoneName.isEmpty ? v.id : v.zoneName));
    }
    final g = project.meta.georef;
    // 1.6.0 PRD: the datum the georeference names (SIRGAS 2000 in Brazil)
    final crs = g != null ? projectUtmCrs(g, datum: g.effectiveDatum) : CrsInfo.local;
    final text = _write(scopeLabel, exponent, g);
    return EpanetExport(text: text, warnings: warnings.toList(), nodeIds: nodeIds, linkIds: linkIds, reversedLinks: reversed, emitterExponent: exponent, crs: crs);
  }

  // ------------------------------------------------------------ boundary conditions

  ZoneResult _zone(String valveId) => zoneResults[valveId] ??= () {
    final z = results?.zones[valveId] ?? designer.analyzeZone(valveId);
    for (final p in z.pipes) {
      linkFlow[p.linkId] = p.flow.abs();
    }
    for (final d in z.devices) {
      linkFlow[d.linkId] = d.flow.abs();
    }
    linkFlow['cv_$valveId'] = z.totalFlow;
    return z;
  }();

  double _pivotFlow(String pivotId) => pivotFlows[pivotId] ??= () {
    final r = results?.pivots[pivotId];
    if (r != null) return r.flow;
    final p = project.byId(pivotId);
    return p is PivotEntity ? designer.analyzePivotEntity(p).flow : 0.0;
  }();

  SystemFlowResult? _flowResult(SystemFlow sf, bool all) {
    SystemFlowResult? fr;
    if (!all) fr = results?.systemFlows.where((f) => f.flowId == sf.id).firstOrNull;
    if (fr == null) {
      // zone results first, so the demands are the ones of this export
      for (final v in sf.valveIds) {
        if (model.valveNodes.containsKey(v)) designer.results.zones[v] = _zone(v);
      }
      fr = designer.analyzeSystemFlow(sf);
    }
    for (final p in fr.pipes) {
      linkFlow[p.linkId] = math.max(linkFlow[p.linkId] ?? 0, p.flow.abs());
    }
    for (final d in fr.devices) {
      linkFlow[d.linkId] = math.max(linkFlow[d.linkId] ?? 0, d.flow.abs());
    }
    return fr;
  }

  double _supplyHead(WaterSupplyEntity s, SystemFlowResult? fr) {
    final o = options.supplyHeads[s.id];
    if (o != null) return o;
    final duty = fr?.supplies.where((d) => d.supplyId == s.id).firstOrNull;
    if (duty != null) return duty.head;
    if (!s.calculatePressure) return s.designHeadM;
    warnings.add('epanet_supply_head_assumed:${s.id}');
    return 0;
  }

  // ------------------------------------------------------------ emitters

  /// The global emitter exponent: the most common exponent (by emitter
  /// count) among the emitters that stay emitters.
  double _emitterExponent(Set<String> nodes) {
    final count = <double, int>{};
    for (final id in nodes) {
      for (final e in model.nodes[id]!.emitters) {
        if (e.index == -2 || e.curve.isPressureCompensating || !_runs(e)) continue;
        final x = (e.curve.x * 1000).round() / 1000;
        count[x] = (count[x] ?? 0) + e.count;
      }
    }
    if (count.isEmpty) return 0.5;
    return count.entries.reduce((a, b) => a.value > b.value || (a.value == b.value && (a.key - 0.5).abs() <= (b.key - 0.5).abs()) ? a : b).key;
  }

  void _emitters(GNode n, _Jn j, double gamma, {required bool satellitesOnly}) {
    final groups = <String, (EmitterRef, int)>{};
    for (final e in n.emitters) {
      // a valve-in-head head off in the exported flow
      if (!_runs(e)) continue;
      if (e.index == -2) {
        // open tape end while flushing: a fixed outflow
        j.demand += e.curve.k * e.count * fq;
        continue;
      }
      if (e.curve.isPressureCompensating) {
        j.demand += e.curve.flow(e.nominalHead) * e.count * fq;
        warnings.add('epanet_emitter_compensating:${e.entityId}');
        continue;
      }
      final key = '${e.curve.k}|${e.curve.x}|${e.offset}';
      final g = groups[key];
      groups[key] = g == null ? (e, e.count) : (g.$1, g.$2 + e.count);
    }
    var first = !satellitesOnly;
    var k = 0;
    for (final (e, count) in groups.values) {
      final c = _coefficient(e, count, gamma);
      if (first) {
        j.elevation = n.elevation + e.offset;
        j.emitter = c;
        first = false;
        continue;
      }
      final sid = '${n.id}_e${++k}';
      junctions[sid] = _Jn(sid, n.elevation + e.offset, n.p, comment: _entityLabel(e.entityId))..emitter = c;
      pipes.add(_Pp('sat_$sid', n.id, sid, 0.01, 500, _plainRoughness, 0, comment: 'emitter'));
    }
  }

  double _coefficient(EmitterRef e, int count, double gamma) {
    final x = e.curve.x;
    var k = e.curve.k * count;
    if ((x - gamma).abs() > 1e-6) {
      // the same flow at the nominal pressure with the global exponent
      final hn = e.nominalHead > 0 ? e.nominalHead : 10.0;
      k = k * math.pow(hn, x) / math.pow(hn, gamma);
      warnings.add('epanet_emitter_exponent:${e.entityId}');
    }
    return k * fq;
  }

  // ------------------------------------------------------------ links

  /// Roughness of the short connecting pipes (as the satellites of our
  /// analysis): C 150, Manning n 0.009 or 0.0015 mm.
  double get _plainRoughness => switch (params.frictionMethod) {
    FrictionMethod.hazenWilliams => 150,
    FrictionMethod.manning => 0.009,
    _ => 0.0015,
  };

  /// Head-loss formula of [OPTIONS]: Manning is EPANET's Chezy-Manning;
  /// Scobey has no EPANET counterpart and is written as Darcy-Weisbach.
  String get _headloss => switch (params.frictionMethod) {
    FrictionMethod.hazenWilliams => 'H-W',
    FrictionMethod.manning => 'C-M',
    _ => 'D-W',
  };

  void _pipe(GLink l) {
    final tape = catalog.tape(l.tapeSpecId);
    var spec = catalog.pipe(l.pipeSpecId);
    if (tape == null && spec == null) {
      final c = catalog.pipesFor(l.usage);
      spec = c.isEmpty ? null : c.first;
      warnings.add('epanet_pipe_unsized:${l.entityId}');
    }
    final d = tape?.innerDiameterMm ?? spec?.innerDiameterMm ?? 50;
    final rough = switch (params.frictionMethod) {
      FrictionMethod.hazenWilliams => params.adjustedC(tape?.hazenC ?? spec?.hazenC ?? 150),
      FrictionMethod.manning => spec?.manningN ?? 0.009,
      _ => tape?.roughnessMm ?? spec?.roughnessMm ?? 0.0015,
    };
    final len = math.max(l.length * (params.applyMinorLosses && l.usage != PipeUsage.lateral ? 1 + params.minorLossPct / 100 : 1), 1e-3);
    pipes.add(_Pp(l.id, l.from, l.to, len, d, rough, params.applyMinorLosses ? l.minorK : 0, comment: _entityLabel(l.entityId)));
    linkIds[l.id] = l.id;
  }

  bool _isPrvValve(GLink l) {
    final v = _byId[l.entityId];
    return scope.kind != EpanetScopeKind.zone && v is ControlValveEntity && v.fixedDownstreamHeadM != null;
  }

  void _controlValve(GLink l) {
    final v = _byId[l.entityId] as ControlValveEntity?;
    final spec = catalog.valve(l.valveSpecId);
    if (_isPrvValve(l)) {
      _prv(l, v!.fixedDownstreamHeadM!, spec, l.id);
      return;
    }
    final curve = spec?.loss ?? const DeviceLossCurve(k: 1e-3);
    final cid = _lossCurve(spec?.id ?? 'default', curve, _qMax(l, spec));
    valves.add(_Vl(l.id, l.from, l.to, _valveDiameter(l, spec), 'GPV', cid, 0, _entityLabel(l.entityId)));
    linkIds[l.id] = l.id;
  }

  void _device(GLink l) {
    final spec = catalog.valve(l.valveSpecId);
    final raw = spec?.loss ?? const DeviceLossCurve(k: 0);
    final curve = raw.k > 0 ? raw : const DeviceLossCurve(k: 1e-3);
    final cid = _lossCurve(raw.k > 0 ? (spec?.id ?? 'default') : 'minimal', curve, _qMax(l, spec));
    final d = _valveDiameter(l, spec);
    if (spec?.kind == ValveKind.check) {
      // EPANET valves cannot be one-way: the loss in a GPV, then a short CV pipe
      final mid = '${l.id}_m';
      junctions[mid] = _Jn(mid, model.nodes[l.to]!.elevation, l.b, comment: 'check valve');
      valves.add(_Vl(l.id, l.from, mid, d, 'GPV', cid, 0, _entityLabel(l.entityId)));
      pipes.add(_Pp('${l.id}_cv', mid, l.to, 0.01, d, _plainRoughness, 0, status: 'CV', comment: 'check valve'));
    } else {
      valves.add(_Vl(l.id, l.from, l.to, d, 'GPV', cid, 0, _entityLabel(l.entityId)));
    }
    linkIds[l.id] = l.id;
  }

  /// A pressure-reducing (PRV), pressure-sustaining (PSV) or flow-control
  /// (FCV) valve: its setting (pressure head, or flow in the file's units)
  /// and the open valve's loss.
  void _prv(GLink l, double setting, ValveSpec? spec, String id, {String type = 'PRV'}) {
    final d = _valveDiameter(l, spec);
    var k = 0.0;
    final loss = spec?.loss;
    if (loss != null && loss.k > 0) {
      // the open valve's loss as h = K·V²/2g at the reference flow
      final q = _qMax(l, spec) / 2;
      final a = math.pi * math.pow(d / 1000, 2) / 4;
      k = loss.loss(q) * 2 * gravity * a * a / (q * q);
      if ((loss.n - 2).abs() > 1e-9 || loss.c != 0) warnings.add('epanet_prv_open_loss:${l.entityId}');
    }
    valves.add(_Vl(id, l.from, l.to, d, type, _num(setting, 8), k, _entityLabel(l.entityId)));
    linkIds[l.id] = id;
  }

  void _pump(GLink l) {
    final spec = catalog.pump(l.pumpSpecId);
    if (spec == null) {
      warnings.add('epanet_pump_spec_missing:${l.entityId}');
      return;
    }
    final cid = 'PC_${_safe(spec.id)}';
    if (!curves.containsKey(cid)) curves[cid] = ('PUMP', _pumpCurve(spec, l.entityId));
    pumps.add(_Pu(l.id, l.from, l.to, cid, l.speedRatio, _entityLabel(l.entityId)));
    linkIds[l.id] = l.id;
  }

  /// Points (flow units, m) of the catalogue parabola, strictly decreasing as
  /// EPANET requires, from the shutoff (or the top of a rising curve) to the
  /// runout flow.
  List<(double, double)> _pumpCurve(PumpSpec spec, String entityId) {
    final c = spec.curve.withSpeed(1);
    var q0 = 0.0;
    if (c.a < 0 && c.b > 0) {
      q0 = -c.b / (2 * c.a);
      warnings.add('epanet_pump_curve_rising:$entityId');
    }
    var q1 = c.runoutFlow;
    if (c.a > 0 && c.b < 0) q1 = math.min(q1, -c.b / (2 * c.a));
    if (!q1.isFinite || q1 <= q0) q1 = q0 + math.max(spec.maxFlow, 1e-3) * 1.5;
    final pts = <(double, double)>[];
    const n = 60;
    for (var i = 0; i <= n; i++) {
      final q = q0 + (q1 - q0) * i / n;
      pts.add((q * fq, math.max(c.head(q), 0)));
    }
    // EPANET wants strictly decreasing heads: a flat or flattening curve is tilted by 1 mm
    for (var i = 1; i < pts.length; i++) {
      if (pts[i].$2 >= pts[i - 1].$2) {
        pts[i] = (pts[i].$1, pts[i - 1].$2 - 0.001);
        warnings.add('epanet_pump_curve_approx:$entityId');
      }
    }
    return pts;
  }

  /// Flow up to which a device's loss curve is tabulated: twice the largest
  /// flow of the analyses, else the flow of 2 m/s in the valve size.
  double _qMax(GLink l, ValveSpec? spec) {
    final q = linkFlow[l.id];
    if (q != null && q > 1e-9) return 2 * q;
    final d = (spec?.sizeMm ?? 0) > 0 ? spec!.sizeMm / 1000 : 0.05;
    return flowForVelocity(velocity: 2, diameter: d);
  }

  String _lossCurve(String specId, DeviceLossCurve c, double qMax) {
    var id = 'HL_${_safe(specId)}';
    final existing = curves[id];
    if (existing != null && existing.$2.last.$1 >= qMax * fq * 0.999) return id;
    if (existing != null) id = '${id}_${curves.length}';
    final qs = <double>{
      0,
      for (final f in const [0.002, 0.005, 0.01, 0.02]) qMax * f,
      for (var i = 1; i <= 40; i++) qMax * i / 40,
    }.toList()..sort();
    curves[id] = ('HEADLOSS', [for (final q in qs) (q * fq, q == 0 ? c.c : c.k * math.pow(q, c.n) + c.c)]);
    return id;
  }

  /// Diameter (mm) of a valve: its size, else the inner diameter of a pipe
  /// next to it.
  double _valveDiameter(GLink l, ValveSpec? spec) {
    if ((spec?.sizeMm ?? 0) > 0) return spec!.sizeMm;
    for (final id in [l.from, l.to]) {
      for (final o in model.nodes[id]?.links ?? const <GLink>[]) {
        if (o.kind != GLinkKind.pipe) continue;
        final d = catalog.tape(o.tapeSpecId)?.innerDiameterMm ?? catalog.pipe(o.pipeSpecId)?.innerDiameterMm;
        if (d != null) return d;
      }
    }
    return 50;
  }

  /// EPANET refuses a PRV, PSV or FCV joined to a reservoir, two of them in
  /// series or two sharing their downstream node (errors 219 and 220): a
  /// short pipe is put in front of such a valve.
  void _separatePrvs() {
    final prvs = valves.where((v) => const {'PRV', 'PSV', 'FCV'}.contains(v.type)).toList();
    for (final v in prvs) {
      final others = prvs.where((o) => !identical(o, v));
      if (reservoirs.containsKey(v.n1) || others.any((o) => o.n2 == v.n1)) {
        final j = '${v.id}_u';
        final at = junctions[v.n1]?.p ?? reservoirs[v.n1]?.p ?? Pt.zero;
        junctions[j] = _Jn(j, junctions[v.n1]?.elevation ?? model.nodes[v.n1]?.elevation ?? 0, at, comment: 'PRV inlet');
        pipes.add(_Pp('${v.id}_s', v.n1, j, 0.01, v.diameterMm, _plainRoughness, 0, comment: 'PRV inlet'));
        v.n1 = j;
      }
      if (reservoirs.containsKey(v.n2)) warnings.add('epanet_prv_to_reservoir:${v.id}');
      if (others.any((o) => o.n2 == v.n2)) warnings.add('epanet_prv_shared_downstream:${v.id}');
    }
  }

  void _mergeChains() {
    final at = <String, List<_Pp>>{};
    for (final p in pipes) {
      at.putIfAbsent(p.n1, () => []).add(p);
      at.putIfAbsent(p.n2, () => []).add(p);
    }
    final busy = <String>{
      for (final v in valves) ...[v.n1, v.n2],
      for (final p in pumps) ...[p.n1, p.n2],
    };
    bool free(String id) {
      final j = junctions[id];
      if (j == null || j.demand != 0 || j.emitter != null || busy.contains(id) || keepNodes.contains(id)) return false;
      final l = at[id];
      if (l == null || l.length != 2 || identical(l[0], l[1])) return false;
      final a = l[0], b = l[1];
      return a.status == 'Open' && b.status == 'Open' && a.diameterMm == b.diameterMm && a.roughness == b.roughness;
    }

    final done = <_Pp>{};
    final out = <_Pp>[];
    for (final p in pipes) {
      if (done.contains(p)) continue;
      // walk back to the start of the chain through free nodes
      var start = p;
      var startNode = p.n1;
      var guard = 0;
      while (free(startNode) && guard++ < pipes.length) {
        final prev = at[startNode]!.firstWhere((x) => !identical(x, start));
        if (done.contains(prev) || identical(prev, p)) break;
        startNode = prev.n1 == startNode ? prev.n2 : prev.n1;
        start = prev;
      }
      // forward from the start
      final chain = <_Pp>[start];
      final verts = <String>[];
      var node = start.n1 == startNode ? start.n2 : start.n1;
      var cur = start;
      while (free(node)) {
        final next = at[node]!.firstWhere((x) => !identical(x, cur));
        if (chain.any((c) => identical(c, next))) break;
        verts.add(node);
        chain.add(next);
        node = next.n1 == node ? next.n2 : next.n1;
        cur = next;
      }
      done.addAll(chain);
      if (chain.length == 1) {
        out.add(start);
        continue;
      }
      final m = _Pp(start.id, startNode, node, 0, start.diameterMm, start.roughness, 0, comment: start.comment);
      var from = startNode;
      for (final c in chain) {
        m.length += c.length;
        m.minorK += c.minorK;
        final forward = c.n1 == from;
        for (final e in linkIds.entries.where((e) => e.value == c.id).toList()) {
          linkIds[e.key] = m.id;
          if (!forward) reversed.add(e.key);
        }
        from = forward ? c.n2 : c.n1;
      }
      for (final v in verts) {
        m.vertices.add(junctions[v]!.p);
        junctions.remove(v);
        nodeIds.remove(v);
      }
      out.add(m);
    }
    pipes
      ..clear()
      ..addAll(out);
  }

  // ------------------------------------------------------------ labels

  String _entityLabel(String id) {
    final e = _byId[id];
    if (e == null) return '';
    final name = switch (e) {
      ControlValveEntity v => v.zoneName.isNotEmpty ? v.zoneName : v.name,
      _ => e.name,
    };
    return name.isEmpty ? '${e.type.name} $id' : '$name (${e.type.name})';
  }

  String _nodeComment(GNode n) {
    for (final id in n.entityIds) {
      final e = _byId[id];
      if (e is WaterSupplyEntity || e is ControlValveEntity || e is JunctionEntity || e is OutletEntity || e is PivotEntity) return _entityLabel(id);
    }
    return '';
  }

  // ------------------------------------------------------------ text

  String _write(String scopeLabel, double exponent, GeoReference? g) {
    // EPANET ids: at most 31 characters, no spaces, semicolons or quotes
    final safe = <String, String>{};
    final used = <String>{};
    String sid(String raw) => safe[raw] ??= () {
      var s = raw.replaceAll(RegExp(r'[^A-Za-z0-9_.\-]'), '_');
      if (s.isEmpty) s = 'x';
      if (s.length > 31) s = s.substring(0, 31);
      var t = s;
      for (var k = 1; used.contains(t); k++) {
        final suffix = '_$k';
        t = (s.length + suffix.length > 31 ? s.substring(0, 31 - suffix.length) : s) + suffix;
      }
      used.add(t);
      return t;
    }();
    for (final id in [...junctions.keys, ...reservoirs.keys, ...pipes.map((p) => p.id), ...pumps.map((p) => p.id), ...valves.map((v) => v.id)]) {
      sid(id);
    }
    nodeIds.updateAll((_, v) => sid(v));
    linkIds.updateAll((_, v) => sid(v));
    status.keys.toList().forEach((k) => status[sid(k)] = status.remove(k)!);
    final b = StringBuffer();
    String c(String s) => s.isEmpty ? '' : '\t;${s.replaceAll(RegExp(r'[\r\n;]'), ' ')}';
    String xy(Pt p) {
      final (x, y) = g != null ? g.toUtm(p.x, p.y) : (p.x, p.y);
      return '${_num(x, 15, maxDecimals: 3)}\t${_num(y, 15, maxDecimals: 3)}';
    }

    b.writeln('[TITLE]');
    final title = options.title.isNotEmpty
        ? options.title
        : [if (project.meta.name.trim().isNotEmpty) project.meta.name, if (project.meta.site.isNotEmpty) project.meta.site, 'OpenCADIrrigation $scopeLabel'];
    for (final t in title) {
      b.writeln(t.replaceAll(RegExp(r'[\r\n]'), ' '));
    }
    b
      ..writeln()
      ..writeln('[JUNCTIONS]')
      ..writeln(';ID\tElev\tDemand\tPattern');
    for (final j in junctions.values) {
      b.writeln('${sid(j.id)}\t${_num(j.elevation, 12, maxDecimals: 6)}\t${_num(j.demand, 9)}\t${c(j.comment)}');
    }
    b
      ..writeln()
      ..writeln('[RESERVOIRS]')
      ..writeln(';ID\tHead\tPattern');
    for (final r in reservoirs.values) {
      b.writeln('${sid(r.id)}\t${_num(r.head, 12, maxDecimals: 6)}\t${c(r.comment)}');
    }
    b
      ..writeln()
      ..writeln('[TANKS]')
      ..writeln(';ID\tElevation\tInitLevel\tMinLevel\tMaxLevel\tDiameter\tMinVol\tVolCurve')
      ..writeln()
      ..writeln('[PIPES]')
      ..writeln(';ID\tNode1\tNode2\tLength\tDiameter\tRoughness\tMinorLoss\tStatus');
    for (final p in pipes) {
      b.writeln('${sid(p.id)}\t${sid(p.n1)}\t${sid(p.n2)}\t${_num(p.length, 10)}\t${_num(p.diameterMm, 8)}\t${_num(p.roughness, 8)}\t${_num(p.minorK, 8)}\t${p.status}${c(p.comment)}');
    }
    b
      ..writeln()
      ..writeln('[PUMPS]')
      ..writeln(';ID\tNode1\tNode2\tParameters');
    for (final p in pumps) {
      b.writeln('${sid(p.id)}\t${sid(p.n1)}\t${sid(p.n2)}\tHEAD ${p.curve}${(p.speed - 1).abs() > 1e-12 ? '\tSPEED ${_num(p.speed, 8)}' : ''}${c(p.comment)}');
    }
    b
      ..writeln()
      ..writeln('[VALVES]')
      ..writeln(';ID\tNode1\tNode2\tDiameter\tType\tSetting\tMinorLoss');
    for (final v in valves) {
      b.writeln('${sid(v.id)}\t${sid(v.n1)}\t${sid(v.n2)}\t${_num(v.diameterMm, 8)}\t${v.type}\t${v.setting}\t${_num(v.minorK, 8)}${c(v.comment)}');
    }
    b
      ..writeln()
      ..writeln('[EMITTERS]')
      ..writeln(';Junction\tCoefficient');
    for (final j in junctions.values) {
      if (j.emitter != null) b.writeln('${sid(j.id)}\t${_num(j.emitter!, 10)}');
    }
    b
      ..writeln()
      ..writeln('[CURVES]')
      ..writeln(';ID\tX-Value\tY-Value');
    curves.forEach((id, curve) {
      b.writeln(';${curve.$1}: $id');
      for (final (x, y) in curve.$2) {
        b.writeln('$id\t${_num(x, 10)}\t${_num(y, 10)}');
      }
    });
    b
      ..writeln()
      ..writeln('[STATUS]')
      ..writeln(';ID\tStatus/Setting');
    status.forEach((id, s) => b.writeln('$id\t$s'));
    b
      ..writeln()
      ..writeln('[ENERGY]')
      ..writeln('Global Efficiency\t${_num(params.pumpEfficiency * 100, 6)}')
      ..writeln('Global Price\t${_num(params.powerCostPerKwh, 6)}')
      ..writeln()
      ..writeln('[OPTIONS]')
      ..writeln('Units\t${options.flowUnits.keyword}')
      ..writeln('Pressure\tMETERS')
      ..writeln('Headloss\t$_headloss')
      ..writeln('Specific Gravity\t1.0')
      ..writeln('Viscosity\t${_num(params.kinematicViscosity / epanetReferenceViscosity, 7)}')
      ..writeln('Trials\t${options.trials}')
      ..writeln('Accuracy\t${_num(options.accuracy, 6)}')
      ..writeln('Unbalanced\tContinue 10')
      ..writeln('Demand Multiplier\t1.0')
      ..writeln('Emitter Exponent\t${_num(exponent, 6)}')
      ..writeln('Demand Model\tDDA')
      ..writeln('Quality\tNone')
      ..writeln()
      ..writeln('[TIMES]')
      ..writeln('Duration\t0:00')
      ..writeln('Hydraulic Timestep\t1:00')
      ..writeln('Pattern Timestep\t1:00')
      ..writeln('Report Timestep\t1:00')
      ..writeln('Report Start\t0:00')
      ..writeln('Start ClockTime\t12 am')
      ..writeln('Statistic\tNone')
      ..writeln()
      ..writeln('[REPORT]')
      ..writeln('Status\tYes')
      ..writeln('Summary\tNo')
      ..writeln('Page\t0')
      ..writeln('Nodes\tAll')
      ..writeln('Links\tAll')
      ..writeln()
      ..writeln('[COORDINATES]')
      ..writeln(';Node\tX-Coord\tY-Coord');
    for (final j in junctions.values) {
      b.writeln('${sid(j.id)}\t${xy(j.p)}');
    }
    for (final r in reservoirs.values) {
      b.writeln('${sid(r.id)}\t${xy(r.p)}');
    }
    b
      ..writeln()
      ..writeln('[VERTICES]')
      ..writeln(';Link\tX-Coord\tY-Coord');
    for (final p in pipes) {
      for (final v in p.vertices) {
        b.writeln('${sid(p.id)}\t${xy(v)}');
      }
    }
    b
      ..writeln()
      ..writeln('[LABELS]')
      ..writeln(';X-Coord\tY-Coord\tLabel');
    for (final (p, text) in labels) {
      b.writeln('${xy(p + const Pt(1, 1))}\t"${text.replaceAll('"', "'")}"');
    }
    final all = [...junctions.values.map((j) => j.p), ...reservoirs.values.map((r) => r.p)];
    if (all.isNotEmpty) {
      final bb = Bounds.ofPoints(all).inflate(10);
      b
        ..writeln()
        ..writeln('[BACKDROP]')
        ..writeln('Dimensions\t${xy(Pt(bb.minX, bb.minY))}\t${xy(Pt(bb.maxX, bb.maxY))}')
        ..writeln('Units\tMeters');
    }
    b
      ..writeln()
      ..writeln('[END]');
    return b.toString();
  }
}

/// EPANET's reference kinematic viscosity (1.1·10⁻⁵ ft²/s, water near
/// 20 °C) in m²/s: VISCOSITY in [OPTIONS] is relative to it.
const double epanetReferenceViscosity = 1.1e-5 * 0.09290304;

String _safe(String s) {
  final t = s.replaceAll(RegExp(r'[^A-Za-z0-9_.\-]'), '_');
  return t.length > 24 ? t.substring(0, 24) : t;
}

/// Plain decimal with [sig] significant digits (no exponent), trailing
/// zeros removed.
String _num(double v, int sig, {int maxDecimals = 12}) {
  if (!v.isFinite || v == 0) return '0';
  final mag = (math.log(v.abs()) / math.ln10).floor();
  final dec = (sig - 1 - mag).clamp(0, maxDecimals);
  var s = v.toStringAsFixed(dec);
  if (s.contains('.')) s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  if (s == '-0') s = '0';
  return s;
}

// ====================================================================== reader

/// One record of an input file section, already in SI (m, m³/s, m head).
class InpJunction {
  InpJunction(this.id, this.elevation, this.baseDemand, this.pattern);
  final String id;
  final double elevation;

  /// Primary demand (m³/s) before patterns; [InpModel.demands] may replace it.
  final double baseDemand;
  final String pattern;
}

class InpReservoir {
  InpReservoir(this.id, this.head, this.pattern);
  final String id;
  final double head;
  final String pattern;
}

class InpTank {
  InpTank(this.id, this.elevation, this.initLevel, this.minLevel, this.maxLevel, this.diameter);
  final String id;
  final double elevation, initLevel, minLevel, maxLevel, diameter;
}

class InpPipe {
  InpPipe(this.id, this.n1, this.n2, this.length, this.diameter, this.roughness, this.minorLoss, this.status);
  final String id, n1, n2;
  final double length, diameter;

  /// Hazen-Williams C, or Darcy-Weisbach roughness in metres.
  final double roughness;
  final double minorLoss;

  /// OPEN, CLOSED or CV.
  final String status;
}

class InpPump {
  InpPump(this.id, this.n1, this.n2, {this.headCurve, this.power, this.speed = 1, this.pattern = ''});
  final String id, n1, n2;
  final String? headCurve;

  /// Constant power (kW) of a POWER pump.
  final double? power;
  final double speed;
  final String pattern;
}

class InpValve {
  InpValve(this.id, this.n1, this.n2, this.diameter, this.type, this.setting, this.minorLoss);
  final String id, n1, n2;
  final double diameter;

  /// PRV, PSV, PBV, FCV, TCV or GPV.
  final String type;

  /// Pressure head (m) for PRV/PSV/PBV, flow (m³/s) for FCV, loss coefficient
  /// for TCV, curve id for GPV.
  final String setting;
  final double minorLoss;
}

/// An EPANET input file, in SI units.
class InpModel {
  String title = '';
  final options = <String, String>{};
  final junctions = <InpJunction>[];
  final reservoirs = <InpReservoir>[];
  final tanks = <InpTank>[];
  final pipes = <InpPipe>[];
  final pumps = <InpPump>[];
  final valves = <InpValve>[];

  /// Curves in SI: pump (m³/s, m), head loss (m³/s, m) and others as written.
  final curves = <String, List<(double, double)>>{};
  final patterns = <String, List<double>>{};

  /// Emitter coefficient k of q = k·p^γ (m³/s per m^γ) by junction.
  final emitters = <String, double>{};

  /// Extra demands (m³/s, pattern) by junction from [DEMANDS].
  final demands = <String, List<(double, String)>>{};

  /// Initial status or setting by link id (OPEN, CLOSED, ACTIVE or a number).
  final status = <String, String>{};
  final coordinates = <String, (double, double)>{};
  final vertices = <String, List<(double, double)>>{};

  /// Message codes (`inp_controls_ignored`, `inp_valve_unsupported:<id>:<type>`, …).
  final warnings = <String>[];
  FrictionMethod method = FrictionMethod.hazenWilliams;
  double emitterExponent = 0.5;

  /// Kinematic viscosity (m²/s).
  double viscosity = epanetReferenceViscosity;
  double demandMultiplier = 1;
  int trials = 200;
  double accuracy = 0.001;

  /// The network for our solver. Steady state at time zero: demands and
  /// reservoir heads times the first multiplier of their patterns; tanks are
  /// fixed heads at their initial level.
  HydraulicNetwork toNetwork() {
    final net = HydraulicNetwork(
      options: NetworkOptions(method: method, kinematicViscosity: viscosity, maxIterations: math.max(trials, 200), flowTolerance: math.min(accuracy, 1e-5)),
    );
    double mult(String pattern) {
      final p = patterns[pattern.isEmpty ? (options['PATTERN'] ?? '1') : pattern];
      return p == null || p.isEmpty ? 1.0 : p.first;
    }

    for (final j in junctions) {
      final extra = demands[j.id];
      final d = extra != null ? extra.fold(0.0, (s, e) => s + e.$1 * mult(e.$2)) : j.baseDemand * mult(j.pattern);
      final k = emitters[j.id];
      net.addNode(
        HNode(
          id: j.id,
          elevation: j.elevation,
          demand: d * demandMultiplier,
          emitter: k != null && k > 0 ? EmitterCurve(k: k, x: emitterExponent) : null,
        ),
      );
    }
    for (final r in reservoirs) {
      final h = r.head * (r.pattern.isEmpty ? 1.0 : (patterns[r.pattern]?.firstOrNull ?? 1.0));
      net.addNode(HNode(id: r.id, kind: HNodeKind.reservoir, elevation: h, fixedHead: h));
    }
    for (final t in tanks) {
      net.addNode(HNode(id: t.id, kind: HNodeKind.reservoir, elevation: t.elevation, fixedHead: t.elevation + t.initLevel));
    }
    for (final p in pipes) {
      final st = (status[p.id] ?? p.status).toUpperCase();
      final rough = method == FrictionMethod.hazenWilliams ? p.roughness : 0.0;
      net.addLink(
        HLink(
          id: p.id,
          from: p.n1,
          to: p.n2,
          kind: st == 'CLOSED' ? HLinkKind.closed : HLinkKind.pipe,
          diameter: p.diameter,
          length: p.length,
          hazenC: method == FrictionMethod.hazenWilliams ? rough : 150,
          roughness: method == FrictionMethod.darcyWeisbach ? p.roughness : 1.5e-6,
          manningN: method == FrictionMethod.manning && p.roughness > 0 ? p.roughness : 0.009,
          minorK: p.minorLoss,
          checkValve: p.status.toUpperCase() == 'CV',
        ),
      );
    }
    for (final p in pumps) {
      final st = (status[p.id] ?? 'OPEN').toUpperCase();
      final speed = double.tryParse(st) ?? p.speed;
      final pts = p.headCurve != null ? curves[p.headCurve!] : null;
      if (p.power != null || pts == null || pts.isEmpty) {
        warnings.add('inp_pump_unsupported:${p.id}');
        net.addLink(HLink(id: p.id, from: p.n1, to: p.n2, kind: HLinkKind.closed));
        continue;
      }
      net.addLink(HLink(id: p.id, from: p.n1, to: p.n2, kind: st == 'CLOSED' || speed == 0 ? HLinkKind.closed : HLinkKind.pump, pump: PumpCurve.fit(pts).withSpeed(speed == 0 ? 1 : speed)));
    }
    for (final v in valves) {
      final st = (status[v.id] ?? '').toUpperCase();
      final open = DeviceLossCurve.fromK(v.minorLoss > 0 ? v.minorLoss : 1e-3, v.diameter);
      if (st == 'CLOSED') {
        net.addLink(HLink(id: v.id, from: v.n1, to: v.n2, kind: HLinkKind.closed, diameter: v.diameter));
        continue;
      }
      switch (v.type) {
        case 'PRV':
          if (st == 'OPEN') {
            net.addLink(HLink(id: v.id, from: v.n1, to: v.n2, kind: HLinkKind.device, diameter: v.diameter, device: open));
          } else {
            net.addLink(HLink(id: v.id, from: v.n1, to: v.n2, kind: HLinkKind.prv, diameter: v.diameter, prvSetting: double.tryParse(v.setting) ?? 0, device: open));
          }
        case 'PSV':
          if (st == 'OPEN') {
            net.addLink(HLink(id: v.id, from: v.n1, to: v.n2, kind: HLinkKind.device, diameter: v.diameter, device: open));
          } else {
            net.addLink(HLink(id: v.id, from: v.n1, to: v.n2, kind: HLinkKind.psv, diameter: v.diameter, prvSetting: double.tryParse(v.setting) ?? 0, device: open));
          }
        case 'FCV':
          if (st == 'OPEN') {
            net.addLink(HLink(id: v.id, from: v.n1, to: v.n2, kind: HLinkKind.device, diameter: v.diameter, device: open));
          } else {
            net.addLink(HLink(id: v.id, from: v.n1, to: v.n2, kind: HLinkKind.fcv, diameter: v.diameter, fcvFlow: double.tryParse(v.setting) ?? 0, device: open));
          }
        case 'GPV':
          final pts = curves[v.setting];
          if (pts == null || pts.isEmpty) {
            warnings.add('inp_curve_missing:${v.id}');
            net.addLink(HLink(id: v.id, from: v.n1, to: v.n2, kind: HLinkKind.device, diameter: v.diameter, device: open));
          } else {
            net.addLink(HLink(id: v.id, from: v.n1, to: v.n2, kind: HLinkKind.device, diameter: v.diameter, device: lossCurveFromPoints(pts)));
          }
        case 'TCV':
          final k = double.tryParse(v.setting) ?? v.minorLoss;
          net.addLink(HLink(id: v.id, from: v.n1, to: v.n2, kind: HLinkKind.device, diameter: v.diameter, device: DeviceLossCurve.fromK(k > 0 ? k : 1e-3, v.diameter)));
        default:
          // PBV has no counterpart in our solver: an open valve
          warnings.add('inp_valve_unsupported:${v.id}:${v.type}');
          net.addLink(HLink(id: v.id, from: v.n1, to: v.n2, kind: HLinkKind.device, diameter: v.diameter, device: open));
      }
    }
    return net;
  }

  /// The network drawn: pipes, pumps and valves as polylines on the layers
  /// EPANET_PIPES / EPANET_PUMPS / EPANET_VALVES, node ids as text, reservoirs
  /// and tanks as circles. Coordinates are placed through [crs] (null: an
  /// input file names no CRS, so local metres unless they look like degrees).
  (DxfDocument, GeoPlacement) toDocument({CrsInfo? crs, GeoReference? georef}) {
    final placement = GeoPlacement.plan(crs, coordinates.values, georef: georef);
    final doc = DxfDocument(layers: [DxfLayer('EPANET_PIPES', color: 5), DxfLayer('EPANET_PUMPS', color: 1), DxfLayer('EPANET_VALVES', color: 2), DxfLayer('EPANET_NODES', color: 7)]);
    Pt? at(String id) {
      final c = coordinates[id];
      return c == null ? null : placement.place(c.$1, c.$2);
    }

    void link(String id, String n1, String n2, String layer) {
      final a = at(n1), b = at(n2);
      if (a == null || b == null) return;
      final pts = [a, for (final v in vertices[id] ?? const <(double, double)>[]) placement.place(v.$1, v.$2), b];
      doc.entities.add(DxfEntity(type: 'POLYLINE', layer: layer, points: pts, name: id));
    }

    for (final p in pipes) {
      link(p.id, p.n1, p.n2, 'EPANET_PIPES');
    }
    for (final p in pumps) {
      link(p.id, p.n1, p.n2, 'EPANET_PUMPS');
    }
    for (final v in valves) {
      link(v.id, v.n1, v.n2, 'EPANET_VALVES');
    }
    for (final id in [...reservoirs.map((r) => r.id), ...tanks.map((t) => t.id)]) {
      final p = at(id);
      if (p != null) doc.entities.add(DxfEntity(type: 'CIRCLE', layer: 'EPANET_NODES', center: p, radius: 1.5, name: id));
    }
    for (final j in junctions) {
      final p = at(j.id);
      if (p != null) doc.entities.add(DxfEntity(type: 'TEXT', layer: 'EPANET_NODES', points: [p + const Pt(0.5, 0.5)], text: j.id, height: 0.8, name: j.id));
    }
    return (doc, placement);
  }
}

/// A head-loss law h = K·Q^n + C fitted to the points (Q, h) of a GPV curve:
/// C from the point at zero flow, K and n by a log-log fit of the rest
/// (exact for points sampled from such a law).
DeviceLossCurve lossCurveFromPoints(List<(double, double)> pts) {
  final c = pts.first.$1 == 0 ? math.max(pts.first.$2, 0.0) : 0.0;
  final fit = DeviceLossCurve.fit([
    for (final (q, h) in pts)
      if (q > 0 && h - c > 0) (q, h - c),
  ]);
  return DeviceLossCurve(k: fit.k, n: fit.n, c: c);
}

class EpanetInpReader {
  /// Parses the text of an input file. Unknown sections are skipped; a
  /// file without [JUNCTIONS] or [PIPES] and [RESERVOIRS] or [TANKS] is
  /// rejected (`inp_no_network`).
  static InpModel parse(String text) {
    final m = InpModel();
    final rows = <String, List<List<String>>>{};
    var section = '';
    final titleLines = <String>[];
    for (final raw in text.split(RegExp(r'\r?\n'))) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('[')) {
        final e = line.indexOf(']');
        section = (e > 0 ? line.substring(1, e) : line.substring(1)).trim().toUpperCase();
        continue;
      }
      if (section == 'TITLE') {
        if (!line.startsWith(';')) titleLines.add(line);
        continue;
      }
      final tokens = _tokens(line);
      if (tokens.isEmpty) continue;
      rows.putIfAbsent(section, () => []).add(tokens);
    }
    m.title = titleLines.join('\n');
    if (rows['CONTROLS']?.isNotEmpty == true || rows['RULES']?.isNotEmpty == true) m.warnings.add('inp_controls_ignored');
    // options first: the units decide every conversion
    for (final r in rows['OPTIONS'] ?? const <List<String>>[]) {
      final u = r.map((t) => t.toUpperCase()).toList();
      if (u.length >= 3 && (u[0] == 'SPECIFIC' || u[0] == 'DEMAND' || u[0] == 'EMITTER' || u[0] == 'MAXIMUM' || u[0] == 'MINIMUM' || u[0] == 'REQUIRED' || u[0] == 'PRESSURE' && u[1] == 'EXPONENT')) {
        m.options['${u[0]} ${u[1]}'] = r[2];
      } else if (u.length >= 2) {
        m.options[u[0]] = r[1];
      }
    }
    final flowUnits = (m.options['UNITS'] ?? 'GPM').toUpperCase();
    const flowFactor = {
      'CFS': 0.028316846592,
      'GPM': 6.30901964e-5,
      'MGD': 0.0438126364,
      'IMGD': 0.0526167,
      'AFD': 0.0142764,
      'LPS': 1e-3,
      'LPM': 1 / 60000,
      'MLD': 1 / 86.4,
      'CMH': 1 / 3600,
      'CMD': 1 / 86400,
    };
    final fq = flowFactor[flowUnits] ?? (throw const FormatException('inp_units_unknown'));
    final si = const {'LPS', 'LPM', 'MLD', 'CMH', 'CMD'}.contains(flowUnits);
    final fl = si ? 1.0 : metersPerFoot; // lengths, elevations, heads
    final fd = si ? 1e-3 : metersPerInch; // diameters
    final fr = si ? 1e-3 : 1e-3 * metersPerFoot; // D-W roughness (mm or millifeet)
    final sg = double.tryParse(m.options['SPECIFIC GRAVITY'] ?? '') ?? 1.0;
    final pu = (m.options['PRESSURE'] ?? (si ? 'METERS' : 'PSI')).toUpperCase();
    // pressure units per foot of head (EPANET's conversion constants)
    final perFt = switch (pu) {
      'PSI' => 0.4333 * sg,
      'KPA' => 6.895 * 0.4333 * sg,
      'BAR' => 0.06895 * 0.4333 * sg,
      'FEET' => 1.0 * sg,
      _ => metersPerFoot * sg,
    };
    double pressureToHead(double p) => pu == 'METERS' || !const {'PSI', 'KPA', 'BAR', 'FEET'}.contains(pu) ? p / sg : p / perFt * metersPerFoot;
    final hl = (m.options['HEADLOSS'] ?? 'H-W').toUpperCase();
    m.method = switch (hl) {
      'D-W' => FrictionMethod.darcyWeisbach,
      'C-M' => FrictionMethod.manning,
      _ => FrictionMethod.hazenWilliams,
    };
    m.emitterExponent = double.tryParse(m.options['EMITTER EXPONENT'] ?? '') ?? 0.5;
    m.demandMultiplier = double.tryParse(m.options['DEMAND MULTIPLIER'] ?? '') ?? 1;
    m.trials = int.tryParse(m.options['TRIALS'] ?? '') ?? 200;
    m.accuracy = double.tryParse(m.options['ACCURACY'] ?? '') ?? 0.001;
    final visc = double.tryParse(m.options['VISCOSITY'] ?? '');
    if (visc != null && visc > 0) m.viscosity = visc > 1e-3 ? visc * epanetReferenceViscosity : visc * (si ? 1 : 0.09290304);
    double n(List<String> r, int i, [double def = 0]) => i < r.length ? (double.tryParse(r[i]) ?? def) : def;
    String s(List<String> r, int i) => i < r.length ? r[i] : '';

    for (final r in rows['JUNCTIONS'] ?? const <List<String>>[]) {
      m.junctions.add(InpJunction(r[0], n(r, 1) * fl, n(r, 2) * fq, s(r, 3)));
    }
    for (final r in rows['RESERVOIRS'] ?? const <List<String>>[]) {
      m.reservoirs.add(InpReservoir(r[0], n(r, 1) * fl, s(r, 2)));
    }
    for (final r in rows['TANKS'] ?? const <List<String>>[]) {
      m.tanks.add(InpTank(r[0], n(r, 1) * fl, n(r, 2) * fl, n(r, 3) * fl, n(r, 4) * fl, n(r, 5) * fl));
    }
    for (final r in rows['PIPES'] ?? const <List<String>>[]) {
      if (r.length < 6) continue;
      final rough = m.method == FrictionMethod.darcyWeisbach ? n(r, 5) * fr : n(r, 5);
      m.pipes.add(InpPipe(r[0], r[1], r[2], n(r, 3) * fl, n(r, 4) * fd, rough, n(r, 6), r.length > 7 ? r[7].toUpperCase() : 'OPEN'));
    }
    for (final r in rows['PUMPS'] ?? const <List<String>>[]) {
      if (r.length < 4) continue;
      String? curve;
      double? power;
      var speed = 1.0;
      var pattern = '';
      for (var i = 3; i + 1 < r.length; i += 2) {
        switch (r[i].toUpperCase()) {
          case 'HEAD':
            curve = r[i + 1];
          case 'POWER':
            power = double.tryParse(r[i + 1]);
          case 'SPEED':
            speed = double.tryParse(r[i + 1]) ?? 1;
          case 'PATTERN':
            pattern = r[i + 1];
        }
      }
      m.pumps.add(InpPump(r[0], r[1], r[2], headCurve: curve, power: power, speed: speed, pattern: pattern));
    }
    for (final r in rows['VALVES'] ?? const <List<String>>[]) {
      if (r.length < 6) continue;
      final type = r[4].toUpperCase();
      final setting = switch (type) {
        'PRV' || 'PSV' || 'PBV' => '${pressureToHead(n(r, 5))}',
        'FCV' => '${n(r, 5) * fq}',
        _ => r[5],
      };
      m.valves.add(InpValve(r[0], r[1], r[2], n(r, 3) * fd, type, setting, n(r, 6)));
    }
    // curves: pump curves and GPV head-loss curves in SI
    final pumpCurves = {for (final p in m.pumps) ?p.headCurve};
    final lossCurves = {
      for (final v in m.valves)
        if (v.type == 'GPV') v.setting,
    };
    for (final r in rows['CURVES'] ?? const <List<String>>[]) {
      if (r.length < 3) continue;
      final id = r[0];
      final x = n(r, 1), y = n(r, 2);
      final conv = pumpCurves.contains(id) || lossCurves.contains(id) ? (x * fq, y * fl) : (x, y);
      m.curves.putIfAbsent(id, () => []).add(conv);
    }
    for (final r in rows['PATTERNS'] ?? const <List<String>>[]) {
      m.patterns.putIfAbsent(r[0], () => []).addAll([for (final t in r.skip(1)) ?double.tryParse(t)]);
    }
    for (final r in rows['DEMANDS'] ?? const <List<String>>[]) {
      if (r.length < 2) continue;
      m.demands.putIfAbsent(r[0], () => []).add((n(r, 1) * fq, s(r, 2)));
    }
    // emitter coefficients: q (flow units) = C·p^γ (pressure units)
    for (final r in rows['EMITTERS'] ?? const <List<String>>[]) {
      if (r.length < 2) continue;
      m.emitters[r[0]] = n(r, 1) * fq * math.pow(perFt / metersPerFoot, m.emitterExponent);
    }
    for (final r in rows['STATUS'] ?? const <List<String>>[]) {
      if (r.length >= 2) m.status[r[0]] = r[1];
    }
    for (final r in rows['COORDINATES'] ?? const <List<String>>[]) {
      if (r.length >= 3) m.coordinates[r[0]] = (n(r, 1), n(r, 2));
    }
    for (final r in rows['VERTICES'] ?? const <List<String>>[]) {
      if (r.length >= 3) m.vertices.putIfAbsent(r[0], () => []).add((n(r, 1), n(r, 2)));
    }
    if (m.junctions.isEmpty && m.reservoirs.isEmpty && m.tanks.isEmpty) throw const FormatException('inp_no_network');
    return m;
  }

  /// Whitespace-separated tokens of a data line, comments (after `;`) removed;
  /// double quotes group a token with spaces.
  static List<String> _tokens(String line) {
    final out = <String>[];
    final b = StringBuffer();
    var quoted = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        quoted = !quoted;
        continue;
      }
      if (!quoted && ch == ';') break;
      if (!quoted && (ch == ' ' || ch == '\t')) {
        if (b.isNotEmpty) {
          out.add(b.toString());
          b.clear();
        }
        continue;
      }
      b.write(ch);
    }
    if (b.isNotEmpty) out.add(b.toString());
    return out;
  }
}
