part of 'designer.dart';

// 1.6.0 MOT+: pump stations (PRD-17), the real operation of the zones at
// the pressure the mainline gives them, and pilot valves. Kept in a part of
// the designer so its private state stays in one place.

/// A pump of a station: its place (1 = the lead pump, the item's own), its
/// catalogue model, standby or not, and the speed it turns at.
typedef _StationUnit = ({int index, PumpSpec? spec, bool standby, double speed});

extension _MotDesign on Designer {
  // ---------------------------------------------------------------- pump stations

  /// The pump links of the model whose item stands for a station (more
  /// pumps than its own), by entity id.
  Map<String, (GLink, PumpEntity, PumpStation)> get _stations {
    if (!identical(_stationModel, model)) {
      _stationModel = model;
      _stationCurves.clear();
      final out = <String, (GLink, PumpEntity, PumpStation)>{};
      for (final l in model.links) {
        if (l.kind != GLinkKind.pump) continue;
        final e = project.byId(l.entityId);
        if (e is PumpEntity && e.station != null && !e.station!.isEmpty) out[e.id] = (l, e, e.station!);
      }
      _stationsOf = out;
    }
    return _stationsOf;
  }

  /// The pumps of station [s] of item [p] in their order, the lead first,
  /// each at the speed it turns at: the speed a variable-speed drive was
  /// given in the flow being analysed, else the item's speed on the mains of
  /// the parameters (a curve of other mains turns faster or slower).
  List<_StationUnit> _unitsOf(PumpEntity p, PumpStation s) {
    final vfd = p.targetPressureM > 0 ? _vfdSpeed[p.id] : null;
    double speedOf(PumpSpec? spec) => vfd ?? p.speedRatio * (p.targetPressureM > 0 ? 1 : (spec?.mainsSpeedRatio(params.mainsHz) ?? 1));
    final lead = catalog.pump(p.pumpSpecId);
    final out = <_StationUnit>[(index: 1, spec: lead, standby: false, speed: speedOf(lead))];
    for (var i = 0; i < s.units.length; i++) {
      final spec = catalog.pump(s.units[i].specId ?? p.pumpSpecId);
      out.add((index: i + 2, spec: spec, standby: s.units[i].standby, speed: speedOf(spec)));
    }
    return out;
  }

  /// The duty pumps of station [s] that run: the first ones in their order,
  /// as many as the staging of the flow being analysed starts (every one
  /// when the flow did not stage it: the sizing analyses).
  List<_StationUnit> _runningUnits(PumpEntity p, PumpStation s) {
    final duty = [
      for (final u in _unitsOf(p, s))
        if (!u.standby) u,
    ];
    final k = (_stationRunning[p.id] ?? duty.length).clamp(1, duty.length);
    return duty.sublist(0, k);
  }

  /// The curve the solver runs the station of pump link [l] on: its running
  /// pumps joined in parallel or in series; null when [l] is a single pump.
  PumpCurve? _stationCurve(GLink l) {
    final st = _stations[l.entityId];
    if (st == null) return null;
    final (_, p, s) = st;
    final run = _runningUnits(p, s);
    final curves = [
      for (final u in run)
        if (u.spec != null) u.spec!.curve.withSpeed(u.speed),
    ];
    if (curves.isEmpty) return null;
    final key = '${p.id}|${s.arrangement.name}|${[for (final u in run) '${u.spec?.id}@${u.speed}'].join(',')}';
    if (_stationCurves.length > 64) _stationCurves.clear();
    return _stationCurves[key] ??= s.arrangement == PumpArrangement.series ? PumpCurve.series(curves) : PumpCurve.parallel(curves);
  }

  /// What every pump of station [s] does while the station passes [flow]
  /// (m³/s) with the head [head] (m): in parallel the running pumps share the
  /// head, each at the flow its curve gives there; in series they share the
  /// flow, each adding the head of its curve (both scaled to the station's
  /// own figures, which the joined curve gives). Pumps left off and standby
  /// pumps do nothing.
  List<StationUnitDuty> _unitDuties(PumpEntity p, PumpStation s, double flow, double head) {
    final run = _runningUnits(p, s);
    final on = {for (final u in run) u.index};
    final q = <int, double>{}, h = <int, double>{};
    if (flow > 0) {
      if (s.arrangement == PumpArrangement.parallel) {
        for (final u in run) {
          q[u.index] = u.spec?.curve.withSpeed(u.speed).flowAt(head) ?? 0;
          h[u.index] = head;
        }
        final sum = q.values.fold(0.0, (a, b) => a + b);
        for (final k in q.keys.toList()) {
          q[k] = sum > 0 ? q[k]! * flow / sum : flow / run.length;
        }
      } else {
        for (final u in run) {
          final c = u.spec?.curve.withSpeed(u.speed);
          h[u.index] = c == null ? 0 : c.head(math.max(flow, c.peakFlow));
          q[u.index] = flow;
        }
        final sum = h.values.fold(0.0, (a, b) => a + b);
        for (final k in h.keys.toList()) {
          h[k] = sum > 0 ? h[k]! * head / sum : head / run.length;
        }
      }
    }
    return [
      for (final u in _unitsOf(p, s))
        if (on.contains(u.index) && (q[u.index] ?? 0) > 0)
          _unitDuty(p, u, q[u.index]!, h[u.index] ?? 0)
        else
          StationUnitDuty(index: u.index, specId: u.spec?.id ?? '', name: u.spec?.name ?? '?', standby: u.standby, running: on.contains(u.index), speedRatio: u.speed),
    ];
  }

  StationUnitDuty _unitDuty(PumpEntity p, _StationUnit u, double q, double h) {
    final eff = wireToWaterEfficiency(u.spec, p, q, speed: u.speed, fallback: params.pumpEfficiency);
    return StationUnitDuty(
      index: u.index,
      specId: u.spec?.id ?? '',
      name: u.spec?.name ?? '?',
      standby: u.standby,
      running: true,
      flow: q,
      head: h,
      efficiency: eff,
      powerKw: h > 0 ? hydraulicPower(flow: q, head: h) / math.max(eff, 0.05) / 1000 : 0,
      speedRatio: u.speed,
    );
  }

  /// Whether every running pump of station [s] works inside the flow range
  /// of its catalogue model (scaled with its speed) in solution [lr].
  bool _stationInRange(PumpEntity p, PumpStation s, LinkResult lr) {
    for (final u in _unitDuties(p, s, lr.flow, lr.pumpHead)) {
      if (!u.running) continue;
      final spec = catalog.pump(u.specId);
      if (spec == null) continue;
      if (u.flow <= 0 || u.flow > spec.maxFlow * u.speedRatio + 1e-9) return false;
    }
    return true;
  }

  /// Stages the duty pumps of every station of the mainline for the flow
  /// that [build] makes: the fewest pumps, in their order, that pass the
  /// flow with every running pump inside its range and leave no demand short
  /// of pressure ([deficit] of a solution, m). With a calculated supply,
  /// which makes up the pressure, the range alone counts. [tune] sets the
  /// variable-speed drives for each trial. A station that is not staged, or
  /// none of whose trials passes, runs every duty pump.
  void _stageStations(HydraulicNetwork Function() build, double Function(NetworkResult r) deficit, {required bool calculated, required void Function() tune}) {
    _stationRunning.clear();
    for (final (l, p, s) in _stations.values) {
      final duty = s.dutyCount;
      if (!model.mainlineLinks.contains(l.id)) continue;
      if (!s.staged || duty <= 1) {
        _stationRunning[p.id] = duty;
        continue;
      }
      int? pick;
      for (var k = 1; k <= duty && pick == null; k++) {
        _stationRunning[p.id] = k;
        tune();
        final r = build().solve();
        final lr = r.links[l.id];
        if (lr == null) break;
        if (lr.flow > 0 && _stationInRange(p, s, lr) && (calculated || deficit(r) <= 0.01)) pick = k;
      }
      _stationRunning[p.id] = pick ?? duty;
    }
  }

  /// The worst shortfall (m) of the demands of [required] (the pressure
  /// head each needs at its mainline node, by demand id) and of the
  /// valve-in-head [needs] in solution [r], as [Designer.analyzeSystemFlow]
  /// measures it.
  double _demandDeficit(NetworkResult r, Map<String, double> required, List<(String, double)> needs) {
    var d = -double.infinity;
    for (final e in required.entries) {
      final nr = r.nodes[_demandNode(e.key) ?? ''];
      if (nr != null) d = math.max(d, e.value - nr.pressure);
    }
    for (final (node, need) in needs) {
      final nr = r.nodes[node];
      if (nr != null) d = math.max(d, need - nr.pressure);
    }
    return d.isFinite ? d : 0;
  }

  /// The duty of every station of the mainline in solution [r], pump by pump.
  List<StationDuty> _stationDuties(NetworkResult r) => [
    for (final (l, p, s) in _stations.values)
      if (model.mainlineLinks.contains(l.id))
        if (r.links[l.id] case final lr?)
          StationDuty(
            entityId: p.id,
            name: p.name.isNotEmpty ? p.name : (catalog.pump(p.pumpSpecId)?.name ?? p.id),
            arrangement: s.arrangement.name,
            staged: s.staged,
            flow: math.max(lr.flow, 0),
            head: lr.flow > 0 ? lr.pumpHead : 0,
            units: _unitDuties(p, s, lr.flow, lr.pumpHead),
          ),
  ];

  /// The checks of [Designer._checkPump] for every running pump of the
  /// station of [l], at its own flow and head (in series each one's inlet is
  /// the outlet of the one before it); false when [l] is a single pump.
  bool _checkStation(GLink l, LinkResult lr, double inletPressure, double elevation, List<String> warnings) {
    final st = _stations[l.entityId];
    if (st == null) return false;
    final (_, p, s) = st;
    var inlet = inletPressure;
    for (final u in _unitDuties(p, s, lr.flow, lr.pumpHead)) {
      if (!u.running) continue;
      final spec = catalog.pump(u.specId);
      if (spec != null) {
        if (u.flow > spec.maxFlow * u.speedRatio + 1e-9 || u.flow <= 0) {
          warnings.add('pump_out_of_range:${l.entityId}');
        } else if (spec.minFlow > 0 && u.flow < spec.minFlow * u.speedRatio - 1e-9) {
          warnings.add('pump_below_min_flow:${l.entityId}');
        }
        if (!spec.submersible && u.flow > 0 && -inlet > maxSuctionLift(elevation) + 1e-6) warnings.add('pump_suction_lift:${l.entityId}');
        final npshr = spec.npshrAt(u.flow, speed: u.speedRatio);
        if (npshr != null && u.flow > 0 && npshAvailable(inletPressure: inlet, elevation: elevation, tempC: params.waterTempC) < npshr + npshMargin) {
          warnings.add('pump_npsh:${l.entityId}');
        }
        final motor = pumpMotorLoad(spec, u.flow, u.head, speed: u.speedRatio);
        if (motor != null) warnings.add('$motor:${l.entityId}');
      }
      if (s.arrangement == PumpArrangement.series) inlet += u.head;
    }
    return true;
  }

  /// Annual energy cost of the station of pump link [l] passing [flow] with
  /// [head] for [hours] a year: the sum over its running pumps, each on its
  /// own curve and motor; null when [l] is a single pump.
  double? _stationEnergy(GLink l, double flow, double head, double hours) {
    final st = _stations[l.entityId];
    if (st == null) return null;
    final (_, p, s) = st;
    var kw = 0.0;
    for (final u in _unitDuties(p, s, flow, head)) {
      kw += u.powerKw;
    }
    return kw * hours * params.powerCostPerKwh;
  }

  // ---------------------------------------------------------------- pilot valves

  /// The downstream pressure a reducing pilot set to a pressure holds the
  /// zone of [v] at; null without one (a reducing pilot set to 0 keeps the
  /// pressure the design finds for the zone).
  double? _pilotHead(ControlValveEntity v) => v.pilot.reduces && v.pilotReduceM > 0 ? v.pilotReduceM : null;

  /// [need] (m at the mainline node), or the setting of the sustaining pilot
  /// of [v] when that is higher: the valve keeps the mainline before it at
  /// least there.
  double _sustained(ControlValveEntity v, double need) => v.pilot.sustains && v.pilotSustainM > 0 ? math.max(need, v.pilotSustainM) : need;

  // ---------------------------------------------------------------- real operation

  /// Every zone and pivot of each system flow at the pressure the mainline
  /// really gives it, when the parameters ask for it ([DesignParameters.realZoneOperation]).
  void _operateFlows() {
    if (!params.realZoneOperation) return;
    final flows = effectiveSystemFlows();
    for (final f in results.systemFlows) {
      final sf = flows.where((x) => x.id == f.flowId).firstOrNull;
      if (sf != null) f.operation = _operateFlow(sf, f);
    }
  }

  /// Flow (m³/s) of zone [vid] with its valve outlet at pressure head [h],
  /// every emitter at the pressure the zone network gives it.
  double _zoneFlowAt(String vid, double h) {
    final r = _zoneNetwork(vid, math.max(h, 0), true).solve();
    var q = 0.0;
    for (final id in model.zoneNodes[vid] ?? const <String>{}) {
      final n = model.nodes[id]!;
      final nr = r.nodes[id];
      if (nr == null) continue;
      for (final e in n.emitters) {
        q += e.curve.flow(math.max(nr.head - (n.elevation + e.offset), 0)) * e.count;
      }
    }
    return q;
  }

  /// The emitter q = k·√(p − o) (k, o) that stands for zone [vid] on the
  /// mainline: through its flow [q] at outlet pressure [h] with the slope of
  /// its flow there (a second solution 5 % lower), so that the mainline
  /// solved with it meets the zone where the zone itself would be.
  (double, double) _zoneEmitter(String vid, double h, double q) {
    final hh = math.max(h, 0.05);
    final slope = (q - _zoneFlowAt(vid, hh * 0.95)) / (0.05 * hh);
    // dq/dp = q / (2 (p − o))
    final span = (slope > 0 ? q / (2 * slope) : 800.0).clamp(0.05, 800.0);
    return (q > 0 ? q / math.sqrt(span) : 0.0, hh - span);
  }

  /// Adds to [net] (a mainline without the demand of [vid]) what stands for
  /// the zone or pivot [vid]: a node with the emitter [fit] (k, o) behind
  /// its valve. A valve that regulates holds the design pressure after it
  /// (a PRV), a sustaining pilot keeps its setting before it (a PSV), a
  /// plain valve loses what its curve says; a pivot, whose regulators keep
  /// its flow, is a PRV set to the inlet pressure it needs before an
  /// orifice.
  void _attachOperation(HydraulicNetwork net, String vid, (double, double) fit) {
    final main = _demandNode(vid)!;
    final mn = model.nodes[main]!;
    final id = 'op_$vid';
    final emitter = EmitterCurve(k: fit.$1, x: 0.5);
    final pv = results.pivots[vid];
    if (pv != null) {
      net.addNode(HNode(id: id, elevation: mn.elevation, emitter: emitter, emitterOffset: fit.$2));
      net.addLink(HLink(id: 'opv_$vid', from: main, to: id, kind: HLinkKind.prv, prvSetting: pv.inletHead));
      return;
    }
    final valve = project.byId(vid) as ControlValveEntity;
    final zn = model.nodes[model.valveNodes[vid]!.$2]!;
    net.addNode(HNode(id: id, elevation: zn.elevation, emitter: emitter, emitterOffset: fit.$2));
    final loss = catalog.valve(valve.valveSpecId)?.loss ?? const DeviceLossCurve(k: 1e-3);
    final reduces = _regulates(vid);
    final sustain = valve.pilot.sustains && valve.pilotSustainM > 0 ? valve.pilotSustainM : 0.0;
    var from = main;
    if (sustain > 0) {
      if (!reduces) {
        net.addLink(HLink(id: 'ops_$vid', from: main, to: id, kind: HLinkKind.psv, prvSetting: sustain, device: loss));
        return;
      }
      net.addNode(HNode(id: 'opm_$vid', elevation: mn.elevation));
      net.addLink(HLink(id: 'ops_$vid', from: main, to: 'opm_$vid', kind: HLinkKind.psv, prvSetting: sustain));
      from = 'opm_$vid';
    }
    final z = results.zones[vid]!;
    net.addLink(
      reduces
          ? HLink(id: 'opv_$vid', from: from, to: id, kind: HLinkKind.prv, prvSetting: z.downstreamHead, device: loss)
          : HLink(id: 'opv_$vid', from: from, to: id, kind: HLinkKind.device, device: loss),
    );
  }

  /// The zones and pivots of system flow [sf], designed as [f], at the
  /// pressure the mainline really gives them: the supplies at the pressure
  /// of the design, the pump stations staged as there, every zone standing
  /// on the mainline for the emitter of [_zoneEmitter] behind its valve,
  /// fitted again at the pressure it gets until the zone and the mainline
  /// agree (within 0.1 % of the design flow).
  List<ZoneOperation> _operateFlow(SystemFlow sf, SystemFlowResult f) {
    final supplies = _supplies;
    if (supplies.isEmpty) return const [];
    final ids = [
      for (final vid in sf.valveIds)
        if (_demandNode(vid) != null && ((results.zones[vid]?.totalFlow ?? 0) > 0 || (results.pivots[vid]?.flow ?? 0) > 0)) vid,
    ];
    if (ids.isEmpty) return const [];
    final listed = sf.valveIds;
    final pressure = <String, double>{
      for (final s in supplies) s.id: s.calculatePressure ? (f.supplies.where((d) => d.supplyId == s.id).firstOrNull?.head ?? 0) : s.designHeadM,
    };
    final demand = {for (final vid in ids) vid: _demandOf(vid).$1};
    final required = {for (final vid in ids) vid: _demandOf(vid).$2};
    final needs = _headNeeds(listed);
    _vfdSpeed.clear();
    _stageStations(
      () => _mainlineNetwork(pressure, demand, listed),
      (r) => _demandDeficit(r, required, needs),
      calculated: supplies.any((s) => s.calculatePressure),
      tune: () => _tuneVfd(() => _mainlineNetwork(pressure, demand, listed), []),
    );
    final fit = <String, (double, double)>{};
    for (final vid in ids) {
      final z = results.zones[vid];
      final pv = results.pivots[vid];
      fit[vid] = z != null ? _zoneEmitter(vid, z.downstreamHead, z.totalFlow) : (pv!.flow / math.sqrt(math.max(pv.inletHead, 0.1)), 0.0);
    }
    HydraulicNetwork build() {
      final net = _mainlineNetwork(pressure, const {}, listed);
      for (final vid in ids) {
        _attachOperation(net, vid, fit[vid]!);
      }
      return net;
    }

    NetworkResult? r;
    for (var it = 0; it < 12; it++) {
      _tuneVfd(build, []);
      final res = r = build().solve();
      var worst = 0.0;
      for (final vid in ids) {
        if (results.zones[vid] == null) continue;
        final h = res.nodes['op_$vid']?.pressure ?? 0;
        final q = _zoneFlowAt(vid, h);
        final (k, o) = fit[vid]!;
        worst = math.max(worst, (q - k * math.sqrt(math.max(h - o, 0))).abs() / math.max(demand[vid]!, 1e-12));
        if (q > 0) fit[vid] = _zoneEmitter(vid, h, q);
      }
      if (worst < 1e-3) break;
    }
    final out = <ZoneOperation>[];
    final res = r!;
    for (final vid in ids) {
      final avail = res.nodes[_demandNode(vid)!]?.pressure ?? 0;
      final h = res.nodes['op_$vid']?.pressure ?? 0;
      final z = results.zones[vid];
      if (z == null) {
        final pv = results.pivots[vid]!;
        out.add(
          ZoneOperation(valveId: vid, zoneName: pv.name, designFlow: pv.flow, flow: fit[vid]!.$1 * math.sqrt(math.max(h, 0)), requiredHead: pv.inletHead, availableHead: avail, pivot: true),
        );
        continue;
      }
      final zr = analyzeZone(vid, downstreamHead: math.max(h, 0));
      out.add(
        ZoneOperation(
          valveId: vid,
          zoneName: z.zoneName,
          designFlow: z.totalFlow,
          flow: zr.totalFlow,
          requiredHead: z.requiredUpstreamHead,
          availableHead: avail,
          downstreamHead: h,
          minPressure: zr.minOutletPressure,
          maxPressure: zr.maxOutletPressure,
          allowedMin: z.allowedMin,
          allowedMax: z.allowedMax,
          eu: zr.uniformity.eu,
          regulates: _regulates(vid),
        ),
      );
    }
    _vfdSpeed.clear();
    _stationRunning.clear();
    return out;
  }

  // ---------------------------------------------------------------- the surge class in the sizing

  /// Learns from the analysed [pipes] what the surge of a closure asks of
  /// the class of every unit of [units] whose pipe does not hold it: its
  /// largest flow and the (pressure head, distance along the water path) of
  /// its points, kept when worse than the duty learnt before. The candidates
  /// of the unit then hold the operating pressure plus the surge of
  /// [_surgeClassNeed] at the velocity each would have. True when a unit got
  /// a new requirement (another sizing pass is worth it).
  bool _learnSurge(Iterable<PipeSegmentResult> pipes, Map<String, List<GLink>> units) {
    if (!identical(_alongModel, model)) {
      _alongModel = model;
      _alongOf = _distancesAlongWater();
    }
    final along = _alongOf;
    final q = <String, double>{};
    final pts = <String, List<(double, double)>>{};
    for (final p in pipes) {
      if (!units.containsKey(p.entityId)) continue;
      final e = project.byId(p.entityId);
      final own = e is PolyEntity ? e.length : p.length;
      final l = model.linkById(p.linkId);
      q[p.entityId] = math.max(q[p.entityId] ?? 0, p.flow.abs());
      (pts[p.entityId] ??= []).addAll([(p.pressureStart, along[l?.from] ?? own), (p.pressureEnd, along[l?.to] ?? own)]);
    }
    var changed = false;
    for (final e in q.entries) {
      final spec = _specOf(units[e.key]!.first);
      if (spec == null || spec.pressureRatingM <= 0) continue;
      final duty = (e.value, pts[e.key]!);
      if (_surgeClassNeed(spec, duty) <= _rating(spec) + 1e-6) continue;
      final before = _surgeDuty[e.key];
      if (before != null && _surgeClassNeed(spec, before) >= _surgeClassNeed(spec, duty) - 1e-6) continue;
      _surgeDuty[e.key] = duty;
      _networkInputs++;
      changed = true;
    }
    return changed;
  }

  /// The pressure head (m) the class of pipe [s] must hold for [duty] (the
  /// largest flow, and the pressure and distance along the water path of
  /// every point): at the worst point the operating pressure plus the surge
  /// of a closure in the closure time of the parameters at the velocity of
  /// that flow in [s], as [Designer.checkSurge] screens it (Joukowsky,
  /// Michaud's envelope for a closure slower than 2L/a).
  double _surgeClassNeed(PipeSpec s, (double, List<(double, double)>) duty) {
    final (q, pts) = duty;
    final v = velocity(flow: q, diameter: s.innerDiameter);
    final a = waveCelerity(diameter: s.innerDiameter, wallThickness: math.max(s.wallThicknessMm, 0.5) / 1000, material: s.material);
    final full = joukowskySurgeHead(celerity: a, velocityChange: v);
    final closure = params.valveClosureTimeS;
    var worst = 0.0;
    for (final (p, x) in pts) {
      worst = math.max(worst, p + (closure <= 0 ? full : math.min(full, 2 * x * v / (gravity * closure))));
    }
    return worst;
  }

  // ---------------------------------------------------------------- the profile of the mainline

  /// The high points of the mainline: nodes above every neighbour along its
  /// pipes (two or more of them), off the suction side of the pumps, each
  /// with the least drop (m) the line makes on any side of it before it
  /// climbs again.
  Map<String, double> get _highPoints {
    if (identical(_hillModel, model)) return _hillsOf;
    _hillModel = model;
    final suction = _suctionLinks;
    final out = <String, double>{};
    for (final id in model.mainlineNodes) {
      final n = model.nodes[id]!;
      if (n.isSupply) continue;
      final pipes = [
        for (final l in n.links)
          if (l.kind == GLinkKind.pipe && model.mainlineLinks.contains(l.id)) l,
      ];
      if (pipes.length < 2 || pipes.any((l) => suction.contains(l.id))) continue;
      if (pipes.any((l) => model.nodes[l.other(id)]!.elevation > n.elevation + 1e-9)) continue;
      var drop = double.infinity;
      for (final l in pipes) {
        drop = math.min(drop, n.elevation - _lowestDownhill(id, l));
      }
      if (drop > 1e-6) out[id] = drop;
    }
    return _hillsOf = out;
  }

  /// The lowest elevation the mainline reaches from node [from] along pipe
  /// [first], going on down (the steepest way at a junction) while it does
  /// not climb.
  double _lowestDownhill(String from, GLink first) {
    var prev = from, l = first, low = model.nodes[from]!.elevation;
    for (var steps = 0; steps < 100000; steps++) {
      final next = l.other(prev);
      final z = model.nodes[next]!.elevation;
      if (z > low + 1e-9) break;
      low = z;
      GLink? best;
      var bz = double.infinity;
      for (final x in model.nodes[next]!.links) {
        if (x.kind != GLinkKind.pipe || identical(x, l) || !model.mainlineLinks.contains(x.id)) continue;
        final zz = model.nodes[x.other(next)]!.elevation;
        if (zz < bz) {
          bz = zz;
          best = x;
        }
      }
      if (best == null || bz > low + 1e-9) break;
      prev = next;
      l = best;
    }
    return low;
  }

  /// Least drop (m) on every side that makes a high point of the mainline
  /// need an air valve, and the distance (m) within which one counts.
  static const _hillDrop = 1.0;
  static const _airValveReach = 25.0;

  /// `air_valve_missing:<pipe>` for every high point of the mainline (a drop
  /// of [_hillDrop] or more on every side) without an air valve of the
  /// mainline within [_airValveReach]: the air the water carries gathers
  /// there and chokes the line (AWWA M51).
  void _checkHighPoints() {
    final hills = _highPoints;
    if (hills.isEmpty) return;
    final valves = [
      for (final e in project.entities)
        if (e is MiscHydraulicEntity && e.scope == HydraulicScope.mainline && catalog.valve(e.valveSpecId)?.kind == ValveKind.airRelease) e.position,
    ];
    for (final h in hills.entries) {
      if (h.value < _hillDrop) continue;
      final n = model.nodes[h.key]!;
      if (valves.any((p) => p.distanceTo(n.p) <= _airValveReach)) continue;
      final pipe = n.links.firstWhere((l) => l.kind == GLinkKind.pipe).entityId;
      _note('air_valve_missing:$pipe');
    }
  }

  /// The shortfall (m) of the grade line under the pipe at the high points
  /// of the mainline in solution [r]: what a calculated supply must add so
  /// it clears every one (none while each is above the vacuum margin).
  double _hillDeficit(NetworkResult r) {
    var d = -double.infinity;
    for (final id in _highPoints.keys) {
      final nr = r.nodes[id];
      if (nr != null && nr.pressure < Designer._belowAtmosphere && _flowsThrough(id, r)) d = math.max(d, -nr.pressure);
    }
    return d;
  }

  /// Whether water runs through mainline node [id] in solution [r] (an idle
  /// branch rests at the level of the line).
  bool _flowsThrough(String id, NetworkResult r) {
    for (final l in model.nodes[id]!.links) {
      if ((r.links[l.id]?.flow.abs() ?? 0) > 1e-9) return true;
    }
    return false;
  }

  // ---------------------------------------------------------------- looped mainlines in the LP

  /// The energy balance of every loop of the mainline for the flows of
  /// solution [r]: each pipe of the mainline left out of the tree [parent]
  /// (the breadth-first tree from the supplies, [source] the supply of each
  /// node) closes a loop with the tree path between its ends; going round it
  /// the losses, signed by the way the water runs in [r], add up to nothing.
  /// The units of [unitOf] count by their candidates [cands], the rest by
  /// their loss in [r]. A pipe joining the trees of two supplies closes no
  /// loop of its own (their heads differ).
  List<LpLoopConstraint> _loopConstraints(Map<String, GLink?> parent, Map<String, String> source, Map<String, String> unitOf, Map<String, List<PipeSpec>> cands, NetworkResult r) {
    final tree = <String>{
      for (final l in parent.values)
        if (l != null) l.id,
    };
    List<String> up(String n) {
      final out = [n];
      var cur = n;
      for (var guard = 0; guard < 1000000; guard++) {
        final l = parent[cur];
        if (l == null) break;
        cur = l.other(cur);
        out.add(cur);
      }
      return out;
    }

    final out = <LpLoopConstraint>[];
    for (final lid in model.mainlineLinks) {
      if (tree.contains(lid)) continue;
      final chord = model.linkById(lid);
      if (chord == null || chord.kind != GLinkKind.pipe) continue;
      final a = chord.from, b = chord.to;
      if (!parent.containsKey(a) || !parent.containsKey(b) || source[a] != source[b]) continue;
      final ua = up(a), ub = up(b);
      final inA = {for (var i = 0; i < ua.length; i++) ua[i]: i};
      var j = 0;
      while (j < ub.length && !inA.containsKey(ub[j])) {
        j++;
      }
      if (j == ub.length) continue;
      // round the loop: a → b along the chord, b up the tree to where the
      // two ways meet, then down to a; each step from a node along a link
      final steps = <(String, GLink)>[(a, chord)];
      for (var i = 0; i < j; i++) {
        steps.add((ub[i], parent[ub[i]]!));
      }
      for (var k = inA[ub[j]]! - 1; k >= 0; k--) {
        steps.add((ua[k + 1], parent[ua[k]]!));
      }
      final byUnit = <String, Map<String, double>>{};
      var constant = 0.0;
      for (final (x, l) in steps) {
        final lr = r.links[l.id];
        final f = lr?.flow ?? 0;
        final forward = x == l.from ? 1.0 : -1.0;
        if (l.kind != GLinkKind.pipe) {
          constant += forward * (lr?.headLoss ?? 0);
          continue;
        }
        final dir = forward * (f >= 0 ? 1.0 : -1.0);
        final u = unitOf[l.id];
        if (u != null) {
          final m = byUnit.putIfAbsent(u, () => {});
          for (final sp in cands[u] ?? const <PipeSpec>[]) {
            m[sp.id] = (m[sp.id] ?? 0) + dir * _linkLoss(l, sp, f.abs());
          }
        } else {
          constant += dir * _currentLoss(l, f.abs());
        }
      }
      if (byUnit.isEmpty) continue;
      out.add(LpLoopConstraint(lossByUnitSpec: byUnit, constant: constant, tag: lid));
    }
    return out;
  }
}
