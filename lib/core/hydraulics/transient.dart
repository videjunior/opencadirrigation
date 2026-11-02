/// Transient flow (water hammer) in pipe networks by the method of
/// characteristics (MOC).
///
/// A [TransientModel] is built from a [HydraulicNetwork] and its steady
/// solution ([NetworkResult]); [TransientModel.simulate] starts from that
/// steady state, so nothing moves until an event — a valve closing or
/// opening, a pump trip, a demand stop — disturbs it, and returns the head
/// and pressure envelopes of every node and pipe grid point, time series at
/// chosen points and message codes.
///
/// Method (Wylie & Streeter 1993, *Fluid Transients in Systems*; Chaudhry
/// 2014, *Applied Hydraulic Transients*):
/// - compatibility equations along C± in head and flow form, H_P = C_P − B_P·Q_P
///   and H_P = C_M + B_M·Q_P, with B = a/(gA) and the friction term
///   linearised as B_P = B + R·|Q_A| (Wylie & Streeter 1993), which keeps
///   the steady state exact and the scheme stable with large friction;
/// - one time step Δt for the whole system and Δx = a·Δt in every pipe: wave
///   speeds are adjusted to fit within [TransientOptions.maxWaveSpeedAdjustment]
///   (Wylie & Streeter 1993); a pipe that cannot be fitted uses space-line
///   interpolation with a Courant number below one (Chaudhry 2014); a pipe
///   much shorter than a·Δt is lumped into a rigid water column (inertia
///   L/(gA) and friction). Every adjustment is reported in the result;
/// - series pipes of the same diameter and celerity, joined at nodes that
///   draw no water, are merged into one characteristic grid that keeps the
///   elevation profile, so high points inside it still cavitate;
/// - quasi-steady friction: Darcy-Weisbach with a constant factor per pipe,
///   the one that reproduces the steady head loss at the steady flow; a
///   Hazen-Williams pipe thus gets its equivalent Darcy factor at the
///   steady flow (a pipe without flow, below 0.02 m/s, uses the factor at
///   1 m/s);
/// - boundary conditions node by node, coupled only where point elements
///   join nodes (Newton on a small dense system): reservoirs, dead ends,
///   series and branching junctions, valves with the orifice relation
///   ΔH = (Q/(τ·C))², pumps after a power failure (homologous head from the
///   affinity laws, a torque model and the inertia of pump and motor, check
///   valve closing on reverse flow), demands and emitters as orifices,
///   combination air valves with an isothermal air pocket, air vessels with a
///   polytropic gas and the discrete vapour cavity model (DVCM) for column
///   separation at every node and grid point.
///
/// Units are SI: flow m³/s, head and pressure head m of water (gauge, as in
/// [HydraulicNetwork]), time s, volume m³.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../units.dart';
import 'friction.dart';
import 'minor_losses.dart';
import 'network.dart';
import 'pump.dart';
import 'water_hammer.dart';

// ---------------------------------------------------------------- physics

/// Specific gas constant of dry air (J/(kg·K)).
const double airGasConstant = 287.05;

/// Isentropic exponent κ of air.
const double _kappa = 1.4;

/// Critical pressure ratio (2/(κ+1))^(κ/(κ−1)) ≈ 0.528: below it the flow of
/// air through an orifice is choked (sonic).
final double _criticalRatio = math.pow(2 / (_kappa + 1), _kappa / (_kappa - 1)).toDouble();

/// √κ·(2/(κ+1))^((κ+1)/(2(κ−1))) ≈ 0.685, the sonic mass-flow factor.
final double _sonicFactor = math.sqrt(_kappa) * math.pow(2 / (_kappa + 1), (_kappa + 1) / (2 * (_kappa - 1))).toDouble();

/// Mass flow (kg/s) of air through an orifice of effective area [cdArea]
/// (discharge coefficient × area, m²) from the absolute pressure [upstream]
/// to [downstream] (Pa), with the upstream gas at [temperature] (K).
///
/// Isentropic flow of a perfect gas through a nozzle, the relation Wylie &
/// Streeter (1993) use for air valves: subsonic,
/// ṁ = CdA·√(2κ/(κ−1)·p_u·ρ_u·[r^(2/κ) − r^((κ+1)/κ)]) with r = p_d/p_u, while
/// r is above the critical ratio 0.528; choked below it,
/// ṁ = CdA·p_u·√κ/√(R·T)·(2/(κ+1))^((κ+1)/(2(κ−1))) = 0.685·CdA·p_u/√(R·T).
double airOrificeMassFlow({required double cdArea, required double upstream, required double downstream, double temperature = 293.15}) {
  if (!(upstream > 0) || !(cdArea > 0) || downstream >= upstream) return 0;
  final rt = airGasConstant * temperature;
  final r = math.max(downstream, 0.0) / upstream;
  if (r > _criticalRatio) {
    final rho = upstream / rt;
    final s = math.pow(r, 2 / _kappa) - math.pow(r, (_kappa + 1) / _kappa);
    return cdArea * math.sqrt(math.max(0.0, 2 * _kappa / (_kappa - 1) * upstream * rho * s));
  }
  return cdArea * upstream * _sonicFactor / math.sqrt(rt);
}

/// Moment of inertia (kg·m²) of a pump and its motor estimated from the
/// rated power [powerKw] and speed [speedRpm] by the empirical correlations
/// of Thorley & Faithfull (1992), *Inertias of pumps and their driving
/// motors* (also in Thorley 2004, *Fluid Transients in Pipeline Systems*):
/// I_pump = 0.03768·(P/N³)^0.9556 and I_motor = 0.0043·(P/N)^1.48, with P in
/// kW and N in thousands of rpm.
double estimatePumpInertia({required double powerKw, required double speedRpm}) {
  final p = math.max(powerKw, 1e-3);
  final n = math.max(speedRpm, 1.0) / 1000;
  final pump = 0.03768 * math.pow(p / (n * n * n), 0.9556);
  final motor = 0.0043 * math.pow(p / n, 1.48);
  return pump + motor;
}

// ---------------------------------------------------------------- input

/// Data of a link that the steady network does not carry.
class TransientLinkData {
  const TransientLinkData({this.celerity, this.length, this.rating, this.minRating});

  /// Celerity from the pipe wall by [waveCelerity] (Korteweg formula).
  factory TransientLinkData.fromPipe({required double diameter, required double wallThickness, required PipeMaterial material, double? length, double? rating, double? minRating}) => TransientLinkData(
    celerity: waveCelerity(diameter: diameter, wallThickness: wallThickness, material: material),
    length: length,
    rating: rating,
    minRating: minRating,
  );

  /// Wave celerity a (m/s); null takes [TransientModel.defaultCelerity].
  final double? celerity;

  /// Physical length (m) when [HLink.length] includes an allowance (the
  /// designer adds the minor losses as extra length); null takes the link
  /// length. The steady head loss is kept either way.
  final double? length;

  /// Pressure rating (m of water): `transient_overpressure:<linkId>` when the
  /// maximum pressure along the link exceeds it.
  final double? rating;

  /// Lowest allowable pressure head (m, negative below atmospheric), such as
  /// the collapse limit of a thin wall: `transient_underpressure:<linkId>`
  /// when the minimum pressure along the link falls below it.
  final double? minRating;
}

/// Relative opening τ(t) = (Cd·A)/(Cd·A)ref of a valve, or factor of a demand,
/// as a function of the time since its event started.
class ValveMotion {
  /// From [from] to [to] in [time] seconds (0 = at once). The stroke is
  /// τ = to + (from − to)·(1 − t/T)^E when closing and τ = from + (to − from)·(t/T)^E
  /// when opening, E = [exponent] (1 = linear; Wylie & Streeter 1993 use
  /// (1 − t/T)^E for valve closures).
  const ValveMotion.linear({this.time = 0, this.from = 1, this.to = 0, this.exponent = 1}) : points = null;

  /// User table of (t, τ) points, linear in between and held after the last
  /// one; the first point is the opening of the steady state.
  const ValveMotion.table(List<(double, double)> this.points) : time = 0, from = 0, to = 0, exponent = 1;

  final double time;
  final double from;
  final double to;
  final double exponent;
  final List<(double, double)>? points;

  /// Opening at [t] seconds after the start.
  double at(double t) {
    final p = points;
    if (p != null) {
      if (p.isEmpty) return 1;
      if (t <= p.first.$1) return math.max(0.0, p.first.$2);
      for (var i = 1; i < p.length; i++) {
        if (t <= p[i].$1) {
          final (t0, v0) = p[i - 1];
          final (t1, v1) = p[i];
          return math.max(0.0, t1 > t0 ? v0 + (v1 - v0) * (t - t0) / (t1 - t0) : v1);
        }
      }
      return math.max(0.0, p.last.$2);
    }
    if (t <= 0) return from;
    if (time <= 0 || t >= time) return to;
    final s = t / time;
    final e = exponent > 0 ? exponent : 1.0;
    return to <= from ? to + (from - to) * math.pow(1 - s, e) : from + (to - from) * math.pow(s, e);
  }

  /// Opening of the steady state (t = 0).
  double get initial => at(0);
}

/// What disturbs the steady state.
enum TransientEventKind { valveClosure, valveOpening, pumpTrip, demandStop }

/// How a demand stops: [ramp] prescribes the flow, falling linearly to the
/// final factor (the boundary condition of Michaud's formula); [orifice]
/// keeps the orifice relation Q = τ·Q₀·√(p/p₀) with τ falling linearly.
enum DemandStopMode { ramp, orifice }

/// An event of a transient simulation.
class TransientEvent {
  const TransientEvent._({
    required this.kind,
    required this.target,
    this.startTime = 0,
    this.motion,
    this.inertia,
    this.speedRpm = 2900,
    this.powerKw,
    this.efficiency = 0.7,
    this.shutoffTorqueRatio = 0.5,
    this.demandMode = DemandStopMode.ramp,
  });

  /// Valve on link [linkId] closing in [closureTime] seconds (0 = at once) to
  /// [finalOpening], with the stroke [exponent] of [ValveMotion.linear], or
  /// following [table] (t, τ). A device or PRV link is the valve itself (its
  /// steady loss calibrates the orifice relation, ΔH = ΔH₀·(Q/(τ·Q₀))²). On a
  /// pipe a valve is added at its downstream end with the open loss of a
  /// gate valve, ΔH = K·V²/2g·(1/τ² − 1): with so small a loss it throttles
  /// only near the end of its stroke, so its effective closure is much
  /// shorter than the stroke.
  factory TransientEvent.valveClosure(String linkId, {double closureTime = 0, double exponent = 1, double startTime = 0, double finalOpening = 0, List<(double, double)>? table}) => TransientEvent._(
    kind: TransientEventKind.valveClosure,
    target: linkId,
    startTime: startTime,
    motion: table != null ? ValveMotion.table([...table]..sort((a, b) => a.$1.compareTo(b.$1))) : ValveMotion.linear(time: closureTime, from: 1, to: finalOpening, exponent: exponent),
  );

  /// Valve on link [linkId] opening from [initialOpening] to fully open in
  /// [openingTime] seconds, or following [table] (t, τ). A closed link
  /// ([HLinkKind.closed]) opens with the loss of its device curve.
  factory TransientEvent.valveOpening(String linkId, {double openingTime = 0, double exponent = 1, double startTime = 0, double initialOpening = 0, List<(double, double)>? table}) => TransientEvent._(
    kind: TransientEventKind.valveOpening,
    target: linkId,
    startTime: startTime,
    motion: table != null ? ValveMotion.table([...table]..sort((a, b) => a.$1.compareTo(b.$1))) : ValveMotion.linear(time: openingTime, from: initialOpening, to: 1, exponent: exponent),
  );

  /// Power failure of the pump on link [linkId]: the set runs down with its
  /// moment of inertia [inertia] (kg·m², pump + motor + water; null =
  /// [estimatePumpInertia] from [powerKw], or the shaft power at the
  /// operating point, and [speedRpm]), the running speed [speedRpm] and the
  /// [efficiency] at the operating point; [shutoffTorqueRatio] is the torque
  /// at zero flow relative to the operating torque. The built-in check valve
  /// closes on reverse flow.
  factory TransientEvent.pumpTrip(String linkId, {double? inertia, double speedRpm = 2900, double? powerKw, double efficiency = 0.7, double shutoffTorqueRatio = 0.5, double startTime = 0}) =>
      TransientEvent._(
        kind: TransientEventKind.pumpTrip,
        target: linkId,
        startTime: startTime,
        inertia: inertia,
        speedRpm: speedRpm,
        powerKw: powerKw,
        efficiency: efficiency,
        shutoffTorqueRatio: shutoffTorqueRatio,
      );

  /// The demand (and the emitters) of node [nodeId] stopping in [stopTime]
  /// seconds to [finalFactor] of the steady value: a zone valve closing as
  /// seen from the mainline.
  factory TransientEvent.demandStop(String nodeId, {double stopTime = 0, double startTime = 0, DemandStopMode mode = DemandStopMode.ramp, double finalFactor = 0}) => TransientEvent._(
    kind: TransientEventKind.demandStop,
    target: nodeId,
    startTime: startTime,
    demandMode: mode,
    motion: ValveMotion.linear(time: stopTime, from: 1, to: finalFactor),
  );

  final TransientEventKind kind;

  /// Link id (valves, pumps) or node id (demands).
  final String target;

  /// Time of the start of the event (s).
  final double startTime;

  /// Opening of a valve, or factor of a demand, after [startTime].
  final ValveMotion? motion;

  /// Pump trip: moment of inertia (kg·m²), running speed (rpm), rated power
  /// (kW), efficiency at the operating point and shutoff torque ratio.
  final double? inertia;
  final double speedRpm;
  final double? powerKw;
  final double efficiency;
  final double shutoffTorqueRatio;

  /// Demand stop: prescribed flow or orifice.
  final DemandStopMode demandMode;
}

/// Combination air valve at a node (AWWA M51 terminology): the large
/// [inflowDiameter] orifice admits air when the pressure falls below
/// atmospheric and the [outflowDiameter] orifice exhausts it (equal for a
/// plain air/vacuum valve, smaller for an anti-slam exhaust). The air
/// admitted forms an isothermal pocket at the node (Wylie & Streeter 1993).
class AirValve {
  const AirValve({required this.nodeId, required this.inflowDiameter, double? outflowDiameter, this.inflowCd = 0.6, this.outflowCd = 0.6, this.elevation})
    : outflowDiameter = outflowDiameter ?? inflowDiameter;
  final String nodeId;

  /// Orifice diameters (m).
  final double inflowDiameter;
  final double outflowDiameter;

  /// Discharge coefficients of the orifices.
  final double inflowCd;
  final double outflowCd;

  /// Elevation of the valve (m); null = the node elevation.
  final double? elevation;
}

/// Air vessel (hydropneumatic tank) at a node: gas following the polytropic
/// law H*·∀ⁿ = constant (H* the absolute head of the gas), connected through
/// an orifice with different loss coefficients for inflow and outflow
/// (Wylie & Streeter 1993; Chaudhry 2014).
class SurgeVessel {
  const SurgeVessel({
    required this.nodeId,
    required this.gasVolume,
    this.totalVolume,
    this.polytropicExponent = 1.2,
    this.connectionDiameter = 0.1,
    this.inflowLossK = 2.5,
    this.outflowLossK = 1.0,
    this.area,
    this.elevation,
  });
  final String nodeId;

  /// Gas volume in the steady state (m³).
  final double gasVolume;

  /// Volume of the vessel (m³); null = 3 × the gas volume. When the gas
  /// fills it, `transient_vessel_drained:<nodeId>`.
  final double? totalVolume;

  /// Polytropic exponent n (1 isothermal, 1.4 adiabatic; 1.2 is the usual
  /// design value).
  final double polytropicExponent;

  /// Connection orifice diameter (m) and its loss coefficients (velocity
  /// heads) into and out of the vessel (a differential orifice throttles
  /// the inflow more).
  final double connectionDiameter;
  final double inflowLossK;
  final double outflowLossK;

  /// Free-surface area (m²) for the change of the water level; null ignores it.
  final double? area;

  /// Elevation of the water surface in the steady state (m); null = node elevation.
  final double? elevation;
}

/// A point whose time series is recorded.
class TransientProbe {
  /// Head, pressure, outflow and volume (air pocket, vessel gas or vapour
  /// cavity) of node [id].
  const TransientProbe.node(this.id) : isLink = false, fraction = 0;

  /// Head, pressure and flow at [fraction] of link [id] from its `from` node
  /// (pumps also record the speed ratio). The check valve or event valve of
  /// a pipe sits at its `to` end: the probe sees the pipe side of it.
  const TransientProbe.link(this.id, {this.fraction = 0.5}) : isLink = true;

  final String id;
  final bool isLink;
  final double fraction;
}

/// Simulation settings.
class TransientOptions {
  const TransientOptions({
    this.duration = 30,
    this.timeStep,
    this.maxTimeStep,
    this.minReaches = 8,
    this.maxWaveSpeedAdjustment = 0.1,
    this.maxLumpedShare = 0.02,
    this.maxWork = 4e7,
    this.barometricHead = 10.33,
    this.vapourHead = vapourHead20C,
    this.columnSeparation = true,
    this.cavityWeight = 0.5,
    this.demandExponent = 0.5,
    this.vacuumLimit,
    this.airTemperature = 293.15,
    this.probes = const [],
    this.recordInterval = 0,
  });

  /// Simulated time (s).
  final double duration;

  /// Fixed time step (s); null chooses it (see [maxWaveSpeedAdjustment]).
  final double? timeStep;

  /// Upper bound of the chosen time step (s).
  final double? maxTimeStep;

  /// Reaches of the longest pipe at least (when the work budget allows).
  final int minReaches;

  /// Largest relative wave-speed change |a'/a − 1| accepted to fit a pipe to
  /// the common time step; pipes that do not fit are interpolated.
  final double maxWaveSpeedAdjustment;

  /// Largest share of the total pipe length that may be lumped into rigid
  /// columns when choosing the time step.
  final double maxLumpedShare;

  /// Work budget: grid points × time steps; it bounds the smallest time step.
  final double maxWork;

  /// Atmospheric pressure head (m; 10.33 at sea level, see [atmosphericHead]).
  final double barometricHead;

  /// Vapour pressure head of water, absolute (m; 0.24 at 20 °C).
  final double vapourHead;

  /// Discrete vapour cavity model at every node and grid point; false lets
  /// the pressure fall below the vapour pressure.
  final bool columnSeparation;

  /// Weighting ψ of the cavity-volume integration (0.5 to 1; Bergant,
  /// Simpson & Tijsseling 2006).
  final double cavityWeight;

  /// Exponent x of the demands as orifices, Q = Q₀·(p/p₀)^x (0 = fixed flow).
  final double demandExponent;

  /// Pressure head (m, gauge) that counts as vacuum for `transient_vacuum`;
  /// null = the vapour pressure.
  final double? vacuumLimit;

  /// Temperature of the air admitted by air valves (K).
  final double airTemperature;

  /// Points whose time series are recorded.
  final List<TransientProbe> probes;

  /// Interval between recorded samples (s); 0 records every time step.
  final double recordInterval;
}

// ---------------------------------------------------------------- output

/// Envelope of a node.
class TransientNodeEnvelope {
  const TransientNodeEnvelope({
    required this.nodeId,
    required this.elevation,
    required this.steadyHead,
    required this.maxHead,
    required this.minHead,
    required this.timeOfMax,
    required this.timeOfMin,
    this.maxCavityVolume = 0,
    this.maxAirVolume = 0,
    this.minGasVolume = 0,
    this.maxGasVolume = 0,
  });
  final String nodeId;
  final double elevation;
  final double steadyHead;
  final double maxHead;
  final double minHead;
  final double timeOfMax;
  final double timeOfMin;

  /// Largest vapour cavity (m³, DVCM).
  final double maxCavityVolume;

  /// Largest air pocket admitted by an air valve (m³).
  final double maxAirVolume;

  /// Gas volume range of an air vessel (m³).
  final double minGasVolume;
  final double maxGasVolume;

  double get steadyPressure => steadyHead - elevation;
  double get maxPressure => maxHead - elevation;
  double get minPressure => minHead - elevation;
}

/// Envelope at one point of a link.
class TransientPointEnvelope {
  const TransientPointEnvelope({required this.chainage, required this.elevation, required this.maxHead, required this.minHead, this.maxCavityVolume = 0});

  /// Distance from the link's `from` node (m).
  final double chainage;
  final double elevation;
  final double maxHead;
  final double minHead;
  final double maxCavityVolume;
  double get maxPressure => maxHead - elevation;
  double get minPressure => minHead - elevation;
}

/// How a link was represented.
enum TransientLinkTreatment {
  /// Characteristic grid with Δx = a·Δt (wave speed adjusted if needed).
  grid,

  /// Characteristic grid with space-line interpolation (Courant number < 1).
  interpolated,

  /// Rigid water column (much shorter than a·Δt).
  lumped,

  /// Point element: valve, device, PRV, pump or closed link.
  element,
}

/// Envelope of a link: its end nodes and the grid points in between.
class TransientLinkEnvelope {
  const TransientLinkEnvelope({required this.linkId, required this.points, required this.treatment, this.celerity = 0, this.reaches = 0});
  final String linkId;

  /// From the `from` node to the `to` node.
  final List<TransientPointEnvelope> points;
  final TransientLinkTreatment treatment;

  /// Wave speed used (m/s, after the adjustment) and reaches of its grid.
  final double celerity;
  final int reaches;

  double get maxHead => points.fold(-double.infinity, (m, p) => math.max(m, p.maxHead));
  double get minHead => points.fold(double.infinity, (m, p) => math.min(m, p.minHead));
  double get maxPressure => points.fold(-double.infinity, (m, p) => math.max(m, p.maxPressure));
  double get minPressure => points.fold(double.infinity, (m, p) => math.min(m, p.minPressure));
}

/// Time series of a probe, one value per entry of [TransientResult.times].
class TransientSeries {
  TransientSeries(this.probe);
  final TransientProbe probe;
  final List<double> heads = [];
  final List<double> pressures = [];

  /// Link flow from → to (link probes) or the node's outflow to demands,
  /// emitters and an air vessel (node probes), m³/s.
  final List<double> flows = [];

  /// Speed ratio of a pump (pump link probes; empty otherwise).
  final List<double> speeds = [];

  /// Air pocket, vessel gas or vapour cavity volume (node probes), m³.
  final List<double> volumes = [];
}

/// Result of [TransientModel.simulate].
class TransientResult {
  const TransientResult({
    required this.timeStep,
    required this.steps,
    required this.duration,
    required this.reaches,
    required this.maxWaveSpeedAdjustment,
    required this.waveSpeeds,
    required this.interpolatedLinks,
    required this.lumpedLinks,
    required this.nodes,
    required this.links,
    required this.times,
    required this.series,
    required this.checkValveClosures,
    required this.messages,
  });

  /// Common time step (s) and number of steps.
  final double timeStep;
  final int steps;
  final double duration;

  /// Characteristic reaches in all the grids.
  final int reaches;

  /// Largest relative wave-speed adjustment |a'/a − 1| applied.
  final double maxWaveSpeedAdjustment;

  /// Wave speed used per pipe link (m/s).
  final Map<String, double> waveSpeeds;

  /// Pipe links solved with interpolation, and lumped into rigid columns.
  final List<String> interpolatedLinks;
  final List<String> lumpedLinks;

  /// Envelopes per node and per link of the network.
  final Map<String, TransientNodeEnvelope> nodes;
  final Map<String, TransientLinkEnvelope> links;

  /// Sample times (s) of [series].
  final List<double> times;
  final List<TransientSeries> series;

  /// Time of the first closure of every check valve that closed (pumps,
  /// check valve devices and pipes, PRVs), s.
  final Map<String, double> checkValveClosures;

  /// Codes: `transient_overpressure:<linkId>`, `transient_underpressure:<linkId>`,
  /// `transient_vacuum:<nodeId>`, `transient_vacuum_pipe:<linkId>`,
  /// `transient_column_separation:<nodeId>`, `transient_column_separation_pipe:<linkId>`,
  /// `transient_air_admitted:<nodeId>`, `transient_vessel_drained:<nodeId>`,
  /// `transient_not_converged:<t>` (t in ms), `transient_steady_not_converged`,
  /// `transient_unknown_link:<id>`, `transient_unknown_node:<id>`,
  /// `transient_not_a_pump:<id>`, `transient_not_a_valve:<id>` (a valve event
  /// on a pump), `transient_no_demand:<id>`, `transient_closed_link_flow:<id>`
  /// (a closed link that carried flow in the steady state, e.g. a demand fed
  /// only through it: the simulation starts out of balance).
  final List<String> messages;

  /// Series of the probe of [id] (the first one).
  TransientSeries? seriesOf(String id) {
    for (final s in series) {
      if (s.probe.id == id) return s;
    }
    return null;
  }
}

// ---------------------------------------------------------------- model

/// A network ready for transient simulations.
class TransientModel {
  /// [linkData] gives the celerity, physical length and ratings of the
  /// links (pipes without a celerity take [defaultCelerity]); [airValves]
  /// and [surgeVessels] protect nodes.
  TransientModel.fromNetwork(this.network, this.steady, {this.linkData = const {}, this.defaultCelerity = 1000, this.airValves = const [], this.surgeVessels = const []});

  final HydraulicNetwork network;
  final NetworkResult steady;
  final Map<String, TransientLinkData> linkData;
  final double defaultCelerity;
  final List<AirValve> airValves;
  final List<SurgeVessel> surgeVessels;

  /// Simulates [events] from the steady state. Deterministic; does not
  /// change the network.
  TransientResult simulate({List<TransientEvent> events = const [], TransientOptions options = const TransientOptions()}) => _Simulation(this, events, options).run();
}

// ---------------------------------------------------------------- internals

class _PipeEdge {
  _PipeEdge({required this.linkId, required this.from, required this.to, required this.length, required this.diameter, required this.celerity, required this.r, required this.q0});
  final String linkId;
  final String from;
  final String to;
  final double length;
  final double diameter;
  final double celerity;

  /// Loss h = r·Q·|Q| over the whole edge (the steady loss at the steady flow).
  final double r;

  /// Steady flow from → to.
  final double q0;
}

class _ElemDef {
  _ElemDef(this.link, this.from, this.to, {this.inPipe = false, this.pipeClosed = false});
  final HLink link;
  final String from;
  final String to;

  /// Check valve or event valve at the downstream end of a pipe.
  final bool inPipe;
  final bool pipeClosed;
}

class _Chain {
  final List<_PipeEdge> pieces = [];
  final List<int> dirs = [];
  final List<String> nodeIds = [];
  final List<double> xs = [0];
  double d = 0, area = 0, a = 0, q0 = 0;
  int n0 = -1, nk = -1;
  TransientLinkTreatment treatment = TransientLinkTreatment.grid;
  int reaches = 0;
  double theta = 1, aUsed = 0, dx = 0, b = 0;
  int offset = 0;
  int lumpElem = -1;
  // end characteristics of the current step
  double cp = 0, bp = 1, cm = 0, bm = 1;
  double get length => xs.last;
  bool get lumped => treatment == TransientLinkTreatment.lumped;
}

enum _EK { valve, pump, lumped }

class _Elem {
  _Elem(this.id, this.kind, this.from, this.to);
  final String id;
  final _EK kind;
  final int from;
  final int to;
  double q = 0;
  int u = -1;
  bool shut = false;
  bool permanent = false;
  bool check = false;
  bool cvClosed = false;
  int flips = 0;
  // valve: Δh = rNow·Q·|Q|
  double rRef = 0, rNow = 0, tauRef = 1;
  bool excess = false;
  ValveMotion? motion;
  double motionStart = 0;
  // lumped pipe: Δh = r·Q·|Q| + inertia·dQ/dt
  double r = 0, inertia = 0, qPrev = 0;
  List<String> links = const [];
  // pump: H = pa·Q² + pb·α·Q + pc·α²
  double pa = 0, pb = 0, pc = 0;
  double alpha = 1, beta = 1, qr = 1, beta0 = 0.5, kStep = 0;
  bool tripped = false;
  double tripStart = 0;
  bool running = true; // the trip has started (speed equation active)
  bool get active => !shut && !cvClosed;
}

class _Air {
  _Air(this.z, this.cdaIn, this.cdaOut);
  final double z;
  final double cdaIn;
  final double cdaOut;
  bool open = false, lock = false;
  // committed state: air mass (kg), pocket volume (m³), mass flow (kg/s, +in), liquid net inflow (m³/s)
  double m = 0, vol = 0, mdot = 0, imb = 0;
  // last evaluation
  double mP = 0, volP = 0, mdotP = 0;
  double maxVol = 0;
  bool admitted = false;
  void reset() {
    m = 0;
    vol = 0;
    mdot = 0;
    imb = 0;
    mP = 0;
    volP = 0;
    mdotP = 0;
  }
}

class _Vessel {
  _Vessel({required this.cPoly, required this.n, required this.rIn, required this.rOut, required this.area, required this.total, required this.vol, required this.zw});
  final double cPoly;
  final double n;
  final double rIn;
  final double rOut;
  final double area;
  final double total;
  double vol;
  double zw;
  double qs = 0;
  double qsP = 0;
  double dq = 0;
  bool atLimit = false;
  bool drained = false;
  double minVol = double.infinity, maxVol = 0;
}

class _Node {
  _Node(this.id, this.z, this.h0, this.original, this.index) : h = h0;
  final String id;
  final int index;
  final double z;
  final double h0;
  final bool original;
  double h;
  bool fixed = false;
  double s1 = 0, s2 = 0;
  int u = -1;
  double scale = 0;
  final List<int> el = [];
  // demand Q = dem·factor·(p/p0)^x and emitter Q = emK·factor·(p − off)^x
  double dem = 0, demX = 0, demP0 = 1, demPLin = 1e-3, factor = 1;
  double emK = 0, emX = 0.5, emOff = 0, emPLin = 1e-3;
  ValveMotion? demMotion;
  double demStart = 0;
  _Air? air;
  _Vessel? vessel;
  bool simple = true;
  // DVCM
  bool dvcm = false, cav = false, cavLock = false;
  double hVap = -double.infinity, cavVol = 0, cavI = 0, cavVolP = 0, cavIP = 0, cavMax = 0;
  // envelope
  double hMax = -double.infinity, hMin = double.infinity, tMax = 0, tMin = 0;
}

class _Cluster {
  final List<int> nodes = [];
  final List<int> elems = [];
}

/// A merged node inside a chain: its head is interpolated.
class _Mapped {
  _Mapped(this.id, this.chain, this.x, this.z, this.h0);
  final String id;
  final int chain;
  final double x;
  final double z;
  final double h0;
  int s = 0;
  double w = 0;
  double hMax = -double.infinity, hMin = double.infinity, tMax = 0, tMin = 0;
}

class _ProbeRec {
  _ProbeRec(this.series);
  final TransientSeries series;
  int kind = -1; // 0 MOC node, 1 mapped node, 2 grid point, 3 element, 4 lumped point
  int index = -1;
  double x = 0, f = 0;
  int dir = 1;
}

class _Simulation {
  _Simulation(this.model, this.events, this.o);
  final TransientModel model;
  final List<TransientEvent> events;
  final TransientOptions o;

  final messages = <String>[];
  final nodes = <_Node>[];
  final nodeIndex = <String, int>{};
  final elems = <_Elem>[];
  final chains = <_Chain>[];
  final clusters = <_Cluster>[];
  final mapped = <_Mapped>[];
  final mappedIndex = <String, int>{};
  final probes = <_ProbeRec>[];
  final times = <double>[];
  final checkClosures = <String, double>{};
  final pipeOfLink = <String, (int, int)>{}; // link id -> (chain, piece)

  late double dt;
  late double hvg; // gauge vapour head
  late double psi;
  double qRef = 1e-3, qTol = 1e-10, qReg = 1e-9;
  double maxAdjust = 0;
  bool notConvergedReported = false;
  double tNow = 0;

  // sections
  late Float64List h, qu, qd, cav, hN, quN, qdN, cavN, z, hv, rr, hMax, hMin, cavMax;

  // dense Newton buffers
  Float64List _jac = Float64List(0), _res = Float64List(0);
  double _dOut = 0;

  double headOf(String id) => model.steady.nodes[id]?.head ?? model.network.nodes[id]?.elevation ?? 0;

  /// Velocity below which a pipe's steady loss does not calibrate its
  /// friction (m/s).
  static const double _minVelocity = 0.02;

  /// A steady flow that calibrates a valve or a pump, not the trickle a
  /// closed link passes in the steady solver.
  bool _flowing(double q) => q.abs() > math.max(1e-7, 1e-4 * qRef);

  // ------------------------------------------------------------ build

  _PipeEdge _pipeEdge(HLink l, String from, String to, double hl, double q0) {
    final data = model.linkData[l.id];
    final len = math.max(data?.length ?? l.length, 0.0);
    final a = data?.celerity ?? model.defaultCelerity;
    final d = l.diameter > 0 ? l.diameter : 0.05;
    double r;
    if (velocity(flow: q0.abs(), diameter: d) >= _minVelocity && hl * q0 > 0) {
      r = hl / (q0 * q0.abs());
    } else {
      // (almost) no flow: a closed link still passes a trickle in the
      // steady solver, whose loss over Q² means nothing; the friction
      // factor at 1 m/s instead
      final qr = flowForVelocity(velocity: 1, diameter: d);
      final opt = model.network.options;
      final hf = frictionLoss(method: opt.method, flow: qr, diameter: d, length: l.length, c: l.hazenC, roughness: l.roughness, kinematicViscosity: opt.kinematicViscosity);
      final hm = l.minorK > 0 ? minorLoss(k: l.minorK, flow: qr, diameter: d) : 0.0;
      r = (hf + hm) / (qr * qr);
    }
    return _PipeEdge(linkId: l.id, from: from, to: to, length: len, diameter: d, celerity: a > 0 ? a : model.defaultCelerity, r: r.isFinite ? math.max(r, 0.0) : 0, q0: q0);
  }

  void _build() {
    final st = model.steady;
    if (!st.converged) messages.add('transient_steady_not_converged');
    psi = o.cavityWeight.clamp(0.0, 1.0);
    hvg = o.vapourHead - o.barometricHead;
    for (final lr in st.links.values) {
      qRef = math.max(qRef, lr.flow.abs());
    }
    qTol = 1e-10 + 1e-8 * qRef;
    qReg = 1e-6 * qRef;
    _readEvents();
    _buildEdges();
    _buildChains();
    _discretise();
    for (final c in chains) {
      c.n0 = _ensureNode(c.nodeIds.first);
      c.nk = _ensureNode(c.nodeIds.last);
    }
    for (final d in _defs) {
      _ensureNode(d.from);
      _ensureNode(d.to);
    }
    _buildElements();
    _buildGrids();
    _mapMergedNodes();
    _buildClusters();
    _buildProbes();
  }

  // build inputs
  final _linkById = <String, HLink>{};
  final _valveEv = <String, TransientEvent>{};
  final _pumpEv = <String, TransientEvent>{};
  final _demandEv = <String, TransientEvent>{};
  final _airAt = <String, AirValve>{};
  final _vesselAt = <String, SurgeVessel>{};
  final _pipes = <_PipeEdge>[];
  final _defs = <_ElemDef>[];
  final _internalHead = <String, double>{};
  final _internalZ = <String, double>{};
  final _internalOrder = <String>[];

  /// Events, air valves and vessels by their link or node; invalid ones are
  /// reported and left out.
  void _readEvents() {
    final net = model.network;
    for (final l in net.links) {
      _linkById[l.id] = l;
    }
    for (final ev in events) {
      switch (ev.kind) {
        case TransientEventKind.valveClosure:
        case TransientEventKind.valveOpening:
          final l = _linkById[ev.target];
          if (l == null) {
            messages.add('transient_unknown_link:${ev.target}');
          } else if (l.kind == HLinkKind.pump) {
            messages.add('transient_not_a_valve:${ev.target}');
          } else {
            _valveEv[ev.target] = ev;
          }
        case TransientEventKind.pumpTrip:
          final l = _linkById[ev.target];
          if (l == null) {
            messages.add('transient_unknown_link:${ev.target}');
          } else if (l.kind != HLinkKind.pump) {
            messages.add('transient_not_a_pump:${ev.target}');
          } else {
            _pumpEv[ev.target] = ev;
          }
        case TransientEventKind.demandStop:
          final n = net.nodes[ev.target];
          if (n == null) {
            messages.add('transient_unknown_node:${ev.target}');
          } else if (n.demand == 0 && (n.emitter == null || n.emitterCount <= 0)) {
            messages.add('transient_no_demand:${ev.target}');
          } else {
            _demandEv[ev.target] = ev;
          }
      }
    }
    for (final a in model.airValves) {
      if (net.nodes.containsKey(a.nodeId)) {
        _airAt[a.nodeId] = a;
      } else {
        messages.add('transient_unknown_node:${a.nodeId}');
      }
    }
    for (final v in model.surgeVessels) {
      if (net.nodes.containsKey(v.nodeId)) {
        _vesselAt[v.nodeId] = v;
      } else {
        messages.add('transient_unknown_node:${v.nodeId}');
      }
    }
  }

  /// Pipes become grid edges and the other links point elements. A pipe
  /// with a check valve, closed in the steady state or closing in an event
  /// gets a valve at its downstream end, on an internal node `<id>#`.
  void _buildEdges() {
    final net = model.network;
    final st = model.steady;
    for (final l in net.links) {
      if (!net.nodes.containsKey(l.from) || !net.nodes.containsKey(l.to)) continue;
      final lr = st.links[l.id];
      final q0 = lr?.flow ?? 0.0;
      if (l.kind == HLinkKind.pipe) {
        final closed = lr?.status == LinkStatus.closed;
        if (l.checkValve || closed || _valveEv.containsKey(l.id)) {
          final mid = '${l.id}#';
          _internalZ[mid] = net.nodes[l.to]!.elevation;
          _internalHead[mid] = closed ? headOf(l.from) : headOf(l.to);
          _internalOrder.add(mid);
          _pipes.add(_pipeEdge(l, l.from, mid, closed ? 0 : headOf(l.from) - headOf(l.to), closed ? 0 : q0));
          _defs.add(_ElemDef(l, mid, l.to, inPipe: true, pipeClosed: closed));
        } else {
          _pipes.add(_pipeEdge(l, l.from, l.to, headOf(l.from) - headOf(l.to), q0));
        }
      } else {
        _defs.add(_ElemDef(l, l.from, l.to));
      }
    }
  }

  double _zOf(String id) => _internalZ[id] ?? model.network.nodes[id]?.elevation ?? 0;
  double _h0Of(String id) => _internalHead[id] ?? headOf(id);

  /// Chains of series pipes of the same bore and celerity through nodes
  /// that draw no water and join nothing else (merged into one grid).
  void _buildChains() {
    final net = model.network;
    final pipes = _pipes;
    final pipeAt = <String, List<int>>{};
    final elemCount = <String, int>{};
    for (var i = 0; i < pipes.length; i++) {
      final p = pipes[i];
      if (p.from == p.to) continue;
      (pipeAt[p.from] ??= []).add(i);
      (pipeAt[p.to] ??= []).add(i);
    }
    for (final d in _defs) {
      elemCount[d.from] = (elemCount[d.from] ?? 0) + 1;
      elemCount[d.to] = (elemCount[d.to] ?? 0) + 1;
    }
    final mergeable = <String, bool>{};
    bool canMerge(String id) {
      final cached = mergeable[id];
      if (cached != null) return cached;
      var ok = false;
      final n = net.nodes[id];
      final at = pipeAt[id];
      if (n != null &&
          n.kind == HNodeKind.junction &&
          at != null &&
          at.length == 2 &&
          (elemCount[id] ?? 0) == 0 &&
          n.demand == 0 &&
          (n.emitter == null || n.emitterCount <= 0) &&
          !_airAt.containsKey(id) &&
          !_vesselAt.containsKey(id) &&
          !_demandEv.containsKey(id)) {
        final a = pipes[at[0]], b = pipes[at[1]];
        ok = (a.diameter - b.diameter).abs() <= 1e-9 * math.max(a.diameter, b.diameter) && (a.celerity - b.celerity).abs() <= 1e-9 * math.max(a.celerity, b.celerity);
      }
      mergeable[id] = ok;
      return ok;
    }

    final visited = List<bool>.filled(pipes.length, false);
    void walk(String start, int first) {
      final c = _Chain()..nodeIds.add(start);
      var cur = start;
      var ei = first;
      while (true) {
        visited[ei] = true;
        final e = pipes[ei];
        final dir = e.from == cur ? 1 : -1;
        final next = dir == 1 ? e.to : e.from;
        c.pieces.add(e);
        c.dirs.add(dir);
        c.xs.add(c.xs.last + e.length);
        c.nodeIds.add(next);
        if (next == start || !canMerge(next)) break;
        final at = pipeAt[next]!;
        final other = at[0] == ei ? at[1] : at[0];
        if (visited[other]) break;
        cur = next;
        ei = other;
      }
      final p0 = c.pieces.first;
      c.d = p0.diameter;
      c.area = math.pi * c.d * c.d / 4;
      c.a = p0.celerity;
      c.q0 = p0.q0 * c.dirs.first;
      chains.add(c);
    }

    for (final id in [...net.nodes.keys, ..._internalOrder]) {
      if (canMerge(id)) continue;
      for (final ei in pipeAt[id] ?? const <int>[]) {
        if (!visited[ei]) walk(id, ei);
      }
    }
    for (var i = 0; i < pipes.length; i++) {
      if (visited[i] || pipes[i].from == pipes[i].to) continue;
      // a ring of merged nodes: break it at one of them
      mergeable[pipes[i].from] = false;
      walk(pipes[i].from, i);
    }
  }

  /// The common time step, and how every chain is represented: a grid with
  /// its wave speed adjusted within the tolerance, a grid with space-line
  /// interpolation, or a rigid column.
  void _discretise() {
    for (final e in _pumpEv.entries) {
      final l = _linkById[e.key]!;
      final p = l.pump;
      if (p != null) _trips[e.key] = _tripConstants(l, p, e.value);
    }
    dt = _chooseTimeStep();
    final tol = math.max(o.maxWaveSpeedAdjustment, 0.0);
    for (final c in chains) {
      final tau = c.a > 0 ? c.length / c.a : 0.0;
      final r = tau / dt;
      final n = r.round();
      if (c.length <= 0 || n == 0) {
        c.treatment = TransientLinkTreatment.lumped;
      } else if ((r / n - 1).abs() <= tol + 1e-12) {
        c.treatment = TransientLinkTreatment.grid;
        c.reaches = n;
        c.aUsed = c.length / (n * dt);
        c.theta = 1;
        maxAdjust = math.max(maxAdjust, (c.aUsed / c.a - 1).abs());
      } else if (r.floor() >= 1) {
        c.treatment = TransientLinkTreatment.interpolated;
        c.reaches = r.floor();
        c.aUsed = c.a;
        c.theta = c.reaches * dt / tau;
      } else {
        c.treatment = TransientLinkTreatment.lumped;
      }
      if (!c.lumped) {
        c.dx = c.length / c.reaches;
        c.b = c.aUsed / (gravity * c.area);
      }
    }
  }

  /// The MOC node of [id], created with its demand and emitters as
  /// orifices calibrated on the steady state, its air valve and vessel.
  int _ensureNode(String id) {
    final have = nodeIndex[id];
    if (have != null) return have;
    final net = model.network;
    final n = _Node(id, _zOf(id), _h0Of(id), net.nodes.containsKey(id), nodes.length);
    final hn = net.nodes[id];
    if (hn != null && hn.kind == HNodeKind.reservoir) {
      n.fixed = true;
    } else if (hn != null) {
      final ev = _demandEv[id];
      if (ev != null) {
        n.demMotion = ev.motion;
        n.demStart = ev.startTime;
      }
      if (hn.demand != 0) {
        n.dem = hn.demand;
        final p0 = n.h0 - n.z;
        final ramp = ev != null && ev.demandMode == DemandStopMode.ramp;
        n.demX = !ramp && hn.demand > 0 && p0 > 0.01 ? math.max(o.demandExponent, 0.0) : 0;
        if (ev != null && ev.demandMode == DemandStopMode.orifice && n.demX == 0 && hn.demand > 0 && p0 > 0.01) n.demX = 0.5;
        n.demP0 = p0 > 0 ? p0 : 1;
        n.demPLin = 1e-3 * math.max(n.demP0, 1);
      }
      final em = hn.emitter;
      if (em != null && hn.emitterCount > 0) {
        final x = math.max(em.x, 0.01);
        final off = hn.emitterOffset;
        final p0 = n.h0 - n.z - off;
        final q0 = model.steady.nodes[id]?.emitterFlow ?? 0;
        n.emX = x;
        n.emOff = off;
        n.emK = q0 > 0 && p0 > 0 ? q0 / math.pow(p0, x) : em.k * hn.emitterCount * (em.x < 0.01 ? math.pow(10.0, em.x - x) : 1.0);
        n.emPLin = 1e-3;
      }
      final av = _airAt[id];
      if (av != null) {
        final aIn = math.pi * av.inflowDiameter * av.inflowDiameter / 4 * av.inflowCd;
        final aOut = math.pi * av.outflowDiameter * av.outflowDiameter / 4 * av.outflowCd;
        n.air = _Air(av.elevation ?? n.z, aIn, aOut);
      }
      final sv = _vesselAt[id];
      if (sv != null && sv.gasVolume > 0) {
        final ac = math.pi * sv.connectionDiameter * sv.connectionDiameter / 4;
        final zw = sv.elevation ?? n.z;
        final hStar = n.h0 - zw + o.barometricHead;
        final ex = math.max(sv.polytropicExponent, 1.0);
        n.vessel = _Vessel(
          cPoly: math.max(hStar, 1e-3) * math.pow(sv.gasVolume, ex),
          n: ex,
          rIn: sv.inflowLossK / (2 * gravity * ac * ac),
          rOut: sv.outflowLossK / (2 * gravity * ac * ac),
          area: sv.area ?? 0,
          total: sv.totalVolume ?? 3 * sv.gasVolume,
          vol: sv.gasVolume,
          zw: zw,
        );
      }
    }
    n.simple = n.demX == 0 && n.emK == 0 && n.air == null && n.vessel == null;
    n.dvcm = o.columnSeparation && !n.fixed && n.air == null && n.vessel == null;
    n.hVap = n.z + hvg;
    n.hMax = n.hMin = n.h0;
    nodeIndex[id] = nodes.length;
    nodes.add(n);
    return nodes.length - 1;
  }

  /// Valves, devices, PRVs, closed links and pumps as point elements,
  /// calibrated on the steady state; lumped chains as rigid columns.
  void _buildElements() {
    final st = model.steady;
    for (final d in _defs) {
      final l = d.link;
      final from = nodeIndex[d.from]!, to = nodeIndex[d.to]!;
      final lr = st.links[l.id];
      final q0 = lr?.flow ?? 0.0;
      final dh0 = nodes[from].h0 - nodes[to].h0;
      final ev = _valveEv[l.id];
      if (l.kind == HLinkKind.pump) {
        _addPump(l, from, to, q0, lr, _pumpEv[l.id]);
        continue;
      }
      final e = _Elem(l.id, _EK.valve, from, to);
      if (d.inPipe) {
        e.check = l.checkValve;
        e.cvClosed = d.pipeClosed;
        e.q = d.pipeClosed ? 0 : q0;
        if (ev != null) {
          e.excess = true;
          e.motion = ev.motion;
          e.motionStart = ev.startTime;
          e.tauRef = math.max(ev.motion!.initial, 1e-6);
          e.rRef = minorLossFlowCoefficient(k: FittingK.gateValveOpen, diameter: l.diameter > 0 ? l.diameter : 0.05);
        }
      } else {
        final calibrated = _flowing(q0) && dh0 * q0 > 0 && lr?.status != LinkStatus.closed;
        switch (l.kind) {
          case HLinkKind.prv:
            // frozen at its steady opening, one-way
            e.check = true;
            if (calibrated && q0 > 0) {
              e.rRef = dh0 / (q0 * q0);
            } else {
              e.shut = true;
              e.permanent = true;
            }
          case HLinkKind.closed:
            e.shut = true;
            e.permanent = ev == null;
            e.rRef = _fullOpenR(l);
          default: // device
            e.check = l.checkValve;
            e.cvClosed = lr?.status == LinkStatus.closed;
            e.rRef = calibrated ? dh0 / (q0 * q0.abs()) : _fullOpenR(l);
        }
        e.q = e.active && calibrated ? q0 : 0;
        if (ev != null) {
          e.motion = ev.motion;
          e.motionStart = ev.startTime;
          e.tauRef = calibrated ? math.max(ev.motion!.initial, 1e-6) : 1;
          if (ev.motion!.initial <= 1e-9) {
            e.shut = true;
            e.q = 0;
          }
        }
      }
      e.rNow = e.rRef;
      // a closed link that carries real flow in the steady state (a demand
      // fed only through it) starts the simulation out of balance
      if (!e.active && _flowing(q0)) messages.add('transient_closed_link_flow:${l.id}');
      _attach(e);
    }

    for (var ci = 0; ci < chains.length; ci++) {
      final c = chains[ci];
      for (var k = 0; k < c.pieces.length; k++) {
        pipeOfLink[c.pieces[k].linkId] = (ci, k);
      }
      if (!c.lumped) continue;
      final e = _Elem('lumped:${c.pieces.first.linkId}', _EK.lumped, c.n0, c.nk);
      var r = 0.0, inertia = 0.0;
      for (final p in c.pieces) {
        r += p.r;
        inertia += p.length / (gravity * c.area);
      }
      e.r = r;
      e.inertia = inertia;
      e.q = c.q0;
      e.qPrev = c.q0;
      e.links = [for (final p in c.pieces) p.linkId];
      c.lumpElem = elems.length;
      _attach(e);
    }
  }

  /// Grid points of every chain: elevation, steady head and flow, vapour
  /// head, and the friction of every reach (the share of every pipe in it).
  void _buildGrids() {
    var total = 0;
    for (final c in chains) {
      if (c.lumped) continue;
      c.offset = total;
      total += c.reaches + 1;
    }
    h = Float64List(total);
    qu = Float64List(total);
    qd = Float64List(total);
    cav = Float64List(total);
    hN = Float64List(total);
    quN = Float64List(total);
    qdN = Float64List(total);
    cavN = Float64List(total);
    z = Float64List(total);
    hv = Float64List(total);
    rr = Float64List(total);
    hMax = Float64List(total);
    hMin = Float64List(total);
    cavMax = Float64List(total);
    for (final c in chains) {
      if (c.lumped) continue;
      final zs = [for (final id in c.nodeIds) _zOf(id)];
      final hs = [for (final id in c.nodeIds) _h0Of(id)];
      var k = 0;
      for (var j = 0; j <= c.reaches; j++) {
        final x = j == c.reaches ? c.length : j * c.dx;
        while (k < c.pieces.length - 1 && c.xs[k + 1] < x) {
          k++;
        }
        final x0 = c.xs[k], x1 = c.xs[k + 1];
        final w = x1 > x0 ? ((x - x0) / (x1 - x0)).clamp(0.0, 1.0) : 0.0;
        final s = c.offset + j;
        z[s] = zs[k] + (zs[k + 1] - zs[k]) * w;
        h[s] = hs[k] + (hs[k + 1] - hs[k]) * w;
        hv[s] = o.columnSeparation ? z[s] + hvg : -double.infinity;
        qu[s] = c.q0;
        qd[s] = c.q0;
        hMax[s] = h[s];
        hMin[s] = h[s];
      }
      var p = 0;
      for (var j = 0; j < c.reaches; j++) {
        final a0 = j * c.dx, a1 = (j + 1) * c.dx;
        while (p < c.pieces.length - 1 && c.xs[p + 1] <= a0) {
          p++;
        }
        var rj = 0.0;
        for (var q = p; q < c.pieces.length && c.xs[q] < a1; q++) {
          final ov = math.min(a1, c.xs[q + 1]) - math.max(a0, c.xs[q]);
          final len = c.pieces[q].length;
          if (ov > 0 && len > 0) rj += c.pieces[q].r * ov / len;
        }
        rr[c.offset + j] = rj;
      }
      // the end sections take the node heads (equal to the steady ones)
      h[c.offset] = nodes[c.n0].h0;
      h[c.offset + c.reaches] = nodes[c.nk].h0;
    }
  }

  /// Merged nodes inside chains, with their place between grid points.
  void _mapMergedNodes() {
    for (var ci = 0; ci < chains.length; ci++) {
      final c = chains[ci];
      for (var k = 1; k < c.nodeIds.length - 1; k++) {
        final id = c.nodeIds[k];
        if (nodeIndex.containsKey(id)) continue;
        final m = _Mapped(id, ci, c.xs[k], _zOf(id), _h0Of(id));
        if (!c.lumped) {
          final f = m.x / c.dx;
          m.s = math.min(f.floor(), c.reaches - 1).clamp(0, math.max(c.reaches - 1, 0));
          m.w = (f - m.s).clamp(0.0, 1.0);
        } else {
          m.w = c.length > 0 ? m.x / c.length : 0;
        }
        m.hMax = m.hMin = m.h0;
        mappedIndex[id] = mapped.length;
        mapped.add(m);
      }
    }
  }

  /// Clusters of nodes joined by point elements (solved together), and the
  /// buffers of their Newton iterations.
  void _buildClusters() {
    final parent = List<int>.generate(nodes.length, (i) => i);
    int find(int i) {
      while (parent[i] != i) {
        parent[i] = parent[parent[i]];
        i = parent[i];
      }
      return i;
    }

    for (final e in elems) {
      final a = find(e.from), b = find(e.to);
      if (a != b) parent[a] = b;
    }
    final byRoot = <int, _Cluster>{};
    for (var i = 0; i < nodes.length; i++) {
      final c = byRoot.putIfAbsent(find(i), () {
        final cl = _Cluster();
        clusters.add(cl);
        return cl;
      });
      c.nodes.add(i);
    }
    for (var k = 0; k < elems.length; k++) {
      byRoot[find(elems[k].from)]!.elems.add(k);
    }
    var maxDim = 1;
    for (final c in clusters) {
      maxDim = math.max(maxDim, c.nodes.length + c.elems.length);
    }
    _jac = Float64List(maxDim * maxDim);
    _res = Float64List(maxDim);
    _dx = Float64List(maxDim);
    _x0 = Float64List(maxDim);
  }

  /// Probes resolved to MOC nodes, merged nodes, grid points, elements or
  /// rigid columns.
  void _buildProbes() {
    for (final p in o.probes) {
      final rec = _ProbeRec(TransientSeries(p));
      if (!p.isLink) {
        final ni = nodeIndex[p.id];
        final mi = mappedIndex[p.id];
        if (ni != null && nodes[ni].original) {
          rec.kind = 0;
          rec.index = ni;
        } else if (mi != null) {
          rec.kind = 1;
          rec.index = mi;
        } else {
          messages.add('transient_unknown_node:${p.id}');
          continue;
        }
      } else {
        final f = p.fraction.clamp(0.0, 1.0);
        final pc = pipeOfLink[p.id];
        if (pc != null) {
          final c = chains[pc.$1];
          final piece = c.pieces[pc.$2];
          final dir = c.dirs[pc.$2];
          rec.index = pc.$1;
          rec.dir = dir;
          rec.x = dir == 1 ? c.xs[pc.$2] + f * piece.length : c.xs[pc.$2 + 1] - f * piece.length;
          rec.kind = c.lumped ? 4 : 2;
        } else {
          final ei = elems.indexWhere((e) => e.id == p.id);
          if (ei < 0) {
            messages.add('transient_unknown_link:${p.id}');
            continue;
          }
          rec.kind = 3;
          rec.index = ei;
          rec.f = f;
        }
      }
      probes.add(rec);
    }
  }

  /// Loss coefficient r (h = r·Q²) of a valve or device fully open: its
  /// device curve, or the open loss of a gate valve at the link diameter.
  double _fullOpenR(HLink l) {
    final d = l.device;
    final dia = l.diameter > 0 ? l.diameter : 0.05;
    if (d != null && d.k > 0) {
      if ((d.n - 2).abs() < 1e-9) return d.k;
      final qr = flowForVelocity(velocity: 1, diameter: dia);
      return d.loss(qr) / (qr * qr);
    }
    return minorLossFlowCoefficient(k: FittingK.gateValveOpen, diameter: dia);
  }

  void _addPump(HLink l, int from, int to, double q0, LinkResult? lr, TransientEvent? trip) {
    final e = _Elem(l.id, _EK.pump, from, to);
    final p = l.pump;
    e.check = true;
    if (p == null) {
      e.shut = true;
      e.permanent = true;
      _attach(e);
      return;
    }
    final w = p.speedRatio;
    final gain = nodes[to].h0 - nodes[from].h0;
    final running = lr?.status != LinkStatus.closed && q0 > 0 && _flowing(q0);
    if (p.throughPoints) {
      // a curve through the manufacturer's points: its tangent parabola at
      // the operating point (at half the runout flow when idle)
      final (pa, pb, pc) = p.localParabola(running ? q0 : (p.runoutFlow.isFinite ? p.runoutFlow / 2 : 0.01));
      e.pa = pa;
      e.pb = pb;
      e.pc = pc;
    } else {
      e.pa = p.a;
      e.pb = p.b * w;
      e.pc = p.c * w * w;
    }
    if (running) {
      e.pc += gain - p.head(q0);
      e.q = q0;
    } else {
      e.cvClosed = true;
      e.q = 0;
    }
    final tc = _trips[l.id];
    if (trip != null && tc != null) {
      e.tripped = true;
      e.tripStart = trip.startTime;
      e.beta0 = trip.shutoffTorqueRatio.clamp(0.0, 3.0);
      final (qr, torque, inertia, omega) = tc;
      e.qr = qr;
      // speed equation I·ω_R·dα/dt = −T_R·β (Wylie & Streeter 1993), per step
      e.kStep = torque * dt / (inertia * omega);
    }
    _attach(e);
  }

  /// Tripped pumps: rated flow, torque (N·m), moment of inertia (kg·m²) and
  /// speed (rad/s) at the operating point.
  final _trips = <String, (double, double, double, double)>{};

  (double, double, double, double) _tripConstants(HLink l, PumpCurve p, TransientEvent trip) {
    final lr = model.steady.links[l.id];
    final q0 = lr?.flow ?? 0.0;
    final gain = headOf(l.to) - headOf(l.from);
    final running = lr?.status != LinkStatus.closed && q0 > 0 && _flowing(q0);
    final qr = running ? q0 : (p.runoutFlow.isFinite ? p.runoutFlow / 2 : 0.01);
    final hr = math.max(running ? gain : p.head(qr), 0.1);
    final eff = trip.efficiency.clamp(0.05, 1.0);
    final omega = math.max(trip.speedRpm, 1.0) * 2 * math.pi / 60;
    final shaft = waterDensity * gravity * qr * hr / eff; // W
    final inertia = math.max(trip.inertia ?? estimatePumpInertia(powerKw: trip.powerKw ?? shaft / 1000, speedRpm: trip.speedRpm), 1e-9);
    return (qr, shaft / omega, inertia, omega);
  }

  void _attach(_Elem e) {
    final k = elems.length;
    elems.add(e);
    nodes[e.from].el.add(k);
    nodes[e.to].el.add(k);
  }

  double _chooseTimeStep() {
    final forced = o.timeStep;
    if (forced != null && forced > 0) return forced;
    final taus = <double>[], lens = <double>[];
    var tauMax = 0.0, sumTau = 0.0, total = 0.0;
    for (final c in chains) {
      if (c.length <= 0 || c.a <= 0) continue;
      final t = c.length / c.a;
      taus.add(t);
      lens.add(c.length);
      tauMax = math.max(tauMax, t);
      sumTau += t;
      total += c.length;
    }
    if (taus.isEmpty) return o.maxTimeStep ?? math.max(o.duration / 2000, 1e-4);
    var upper = tauMax / math.max(1, o.minReaches);
    if (o.maxTimeStep != null && o.maxTimeStep! > 0) upper = math.min(upper, o.maxTimeStep!);
    // a tenth of the run-down time I·ω/T of every tripped pump
    for (final (_, torque, inertia, omega) in _trips.values) {
      upper = math.min(upper, inertia * omega / torque / 10);
    }
    final floor = math.sqrt(sumTau * math.max(o.duration, 1e-6) / math.max(o.maxWork, 1.0));
    if (floor > upper) upper = floor;
    final tol = math.max(o.maxWaveSpeedAdjustment, 0.0);
    final extra = tol > 0 ? (1 / (2 * tol)).ceil() + 2 : 4;
    final cands = <double>{upper};
    for (final t in taus) {
      final n0 = math.max(1, (t / upper - 1e-12).ceil());
      for (var n = n0; n <= n0 + extra; n++) {
        final v = t / n;
        if (v < floor) break;
        if (v <= upper) cands.add(v);
      }
    }
    final sorted = cands.toList()..sort((a, b) => b.compareTo(a));
    bool acceptable(double v) {
      var lumped = 0.0;
      for (var i = 0; i < taus.length; i++) {
        final r = taus[i] / v;
        final n = r.round();
        if (n == 0) {
          lumped += lens[i];
        } else if ((r / n - 1).abs() > tol + 1e-12) {
          if (r.floor() >= 1) return false;
          lumped += lens[i];
        }
      }
      return lumped <= o.maxLumpedShare * total + 1e-12;
    }

    for (final v in sorted) {
      if (acceptable(v)) return v;
    }
    return floor;
  }

  // ------------------------------------------------------------ run

  TransientResult run() {
    _build();
    final steps = math.max(1, (o.duration / dt - 1e-9).ceil());
    final every = o.recordInterval > 0 ? math.max(1, (o.recordInterval / dt).round()) : 1;
    _record(0);
    for (var k = 1; k <= steps; k++) {
      final t = k * dt;
      _step(t);
      if (k % every == 0 || k == steps) _record(t);
    }
    return _results(steps);
  }

  void _step(double t) {
    tNow = t;
    // events
    for (final e in elems) {
      e.flips = 0;
      switch (e.kind) {
        case _EK.valve:
          final m = e.motion;
          if (m != null && !e.permanent) {
            final tau = t <= e.motionStart ? m.at(0) : m.at(t - e.motionStart);
            if (tau <= 1e-9) {
              e.shut = true;
              e.q = 0;
            } else {
              e.shut = false;
              e.rNow = e.excess ? e.rRef * math.max(0.0, 1 / (tau * tau) - 1 / (e.tauRef * e.tauRef)) : e.rRef * (e.tauRef / tau) * (e.tauRef / tau);
            }
          }
        case _EK.lumped:
          e.qPrev = e.q;
        case _EK.pump:
          if (e.tripped && t > e.tripStart + 1e-12) e.running = false;
      }
    }
    for (final n in nodes) {
      n.s1 = 0;
      n.s2 = 0;
      n.cavLock = false;
      n.air?.lock = false;
      final m = n.demMotion;
      if (m != null) n.factor = t <= n.demStart ? m.at(0) : m.at(t - n.demStart);
    }
    // interior points and end characteristics
    for (final c in chains) {
      if (!c.lumped) _interior(c);
    }
    // boundary conditions
    for (final c in clusters) {
      _solveCluster(c);
    }
    // end sections
    for (final c in chains) {
      if (c.lumped) continue;
      final s0 = c.offset, sk = c.offset + c.reaches;
      final h0 = nodes[c.n0].h, hk = nodes[c.nk].h;
      final q0 = (h0 - c.cm) / c.bm, qk = (c.cp - hk) / c.bp;
      hN[s0] = h0;
      quN[s0] = q0;
      qdN[s0] = q0;
      cavN[s0] = 0;
      hN[sk] = hk;
      quN[sk] = qk;
      qdN[sk] = qk;
      cavN[sk] = 0;
      if (h0 > hMax[s0]) hMax[s0] = h0;
      if (h0 < hMin[s0]) hMin[s0] = h0;
      if (hk > hMax[sk]) hMax[sk] = hk;
      if (hk < hMin[sk]) hMin[sk] = hk;
    }
    var tmp = h;
    h = hN;
    hN = tmp;
    tmp = qu;
    qu = quN;
    quN = tmp;
    tmp = qd;
    qd = qdN;
    qdN = tmp;
    tmp = cav;
    cav = cavN;
    cavN = tmp;
    // envelopes
    for (final n in nodes) {
      if (n.h > n.hMax) {
        n.hMax = n.h;
        n.tMax = t;
      }
      if (n.h < n.hMin) {
        n.hMin = n.h;
        n.tMin = t;
      }
    }
    for (final m in mapped) {
      final hh = _mappedHead(m);
      if (hh > m.hMax) {
        m.hMax = hh;
        m.tMax = t;
      }
      if (hh < m.hMin) {
        m.hMin = hh;
        m.tMin = t;
      }
    }
  }

  /// Head of a merged node, interpolated between its grid points; with the
  /// cavity model it does not fall below its own vapour head (a high point
  /// between grid points would otherwise borrow the lower points' heads).
  double _mappedHead(_Mapped m) {
    final c = chains[m.chain];
    final double hh;
    if (c.lumped) {
      hh = nodes[c.n0].h + (nodes[c.nk].h - nodes[c.n0].h) * m.w;
    } else {
      final s = c.offset + m.s;
      hh = h[s] + (h[s + 1] - h[s]) * m.w;
    }
    return o.columnSeparation ? math.max(hh, m.z + hvg) : hh;
  }

  /// Interior grid points of chain [c] (C+ and C− with the linearised
  /// friction of Wylie & Streeter 1993, space-line interpolation when the
  /// Courant number θ < 1, DVCM cavities) and its end characteristics.
  void _interior(_Chain c) {
    final o0 = c.offset, n = c.reaches;
    final b = c.b, th = c.theta;
    final h = this.h, qu = this.qu, qd = this.qd, cav = this.cav, rr = this.rr, hv = this.hv;
    final hN = this.hN, quN = this.quN, qdN = this.qdN, cavN = this.cavN, hMax = this.hMax, hMin = this.hMin, cavMax = this.cavMax;
    final dt = this.dt, psi = this.psi;
    for (var i = 1; i < n; i++) {
      final s = o0 + i;
      final hs = h[s];
      final hR = hs - th * (hs - h[s - 1]);
      final qR = qu[s] - th * (qu[s] - qd[s - 1]);
      final cp = hR + b * qR;
      final bp = b + th * rr[s - 1] * qR.abs();
      final hS = hs - th * (hs - h[s + 1]);
      final qS = qd[s] - th * (qd[s] - qu[s + 1]);
      final cm = hS - b * qS;
      final bm = b + th * rr[s] * qS.abs();
      var hp = (cp * bm + cm * bp) / (bp + bm);
      double qup, qdp;
      if (cav[s] > 0 || hp < hv[s]) {
        // vapour cavity: the head is the vapour head, the flows on both
        // sides differ and the volume integrates their difference (DVCM)
        hp = hv[s];
        qup = (cp - hp) / bp;
        qdp = (hp - cm) / bm;
        var vol = cav[s] + dt * (psi * (qdp - qup) + (1 - psi) * (qd[s] - qu[s]));
        if (vol <= 0) {
          vol = 0;
          // it collapses when the flows of this step fill it; emptied only
          // by those of the last one, the liquid head would fall below the
          // vapour head, so it stays, empty, at the vapour head
          if (qup > qdp) {
            hp = (cp * bm + cm * bp) / (bp + bm);
            qup = (cp - cm) / (bp + bm);
            qdp = qup;
          }
        }
        cavN[s] = vol;
        if (vol > cavMax[s]) cavMax[s] = vol;
      } else {
        qup = (cp - cm) / (bp + bm);
        qdp = qup;
        cavN[s] = 0;
      }
      hN[s] = hp;
      quN[s] = qup;
      qdN[s] = qdp;
      if (hp > hMax[s]) hMax[s] = hp;
      if (hp < hMin[s]) hMin[s] = hp;
    }
    // downstream end: C+ from the last reach
    final sk = o0 + n;
    final hk = h[sk];
    final hR = hk - th * (hk - h[sk - 1]);
    final qR = qu[sk] - th * (qu[sk] - qd[sk - 1]);
    c.cp = hR + b * qR;
    c.bp = b + th * rr[sk - 1] * qR.abs();
    final nk = nodes[c.nk];
    nk.s1 += c.cp / c.bp;
    nk.s2 += 1 / c.bp;
    // upstream end: C− from the first reach
    final h0 = h[o0];
    final hS = h0 - th * (h0 - h[o0 + 1]);
    final qS = qd[o0] - th * (qd[o0] - qu[o0 + 1]);
    c.cm = hS - b * qS;
    c.bm = b + th * rr[o0] * qS.abs();
    final n0 = nodes[c.n0];
    n0.s1 += c.cm / c.bm;
    n0.s2 += 1 / c.bm;
  }

  // ------------------------------------------------------------ nodes

  /// Outflow of [n] to its demand and emitters at head [hh], with its
  /// derivative in [_dOut].
  double _demandOut(_Node n, double hh) {
    var q = 0.0, d = 0.0;
    if (n.dem != 0) {
      final qd = n.dem * n.factor;
      if (n.demX == 0) {
        q += qd;
      } else {
        final p = hh - n.z;
        if (p >= n.demPLin) {
          final v = qd * math.pow(p / n.demP0, n.demX);
          q += v;
          d += n.demX * v / p;
        } else if (p > 0) {
          final v1 = qd * math.pow(n.demPLin / n.demP0, n.demX);
          q += v1 * p / n.demPLin;
          d += v1 / n.demPLin;
        }
      }
    }
    if (n.emK > 0) {
      final p = hh - n.z - n.emOff;
      final k = n.emK * n.factor;
      if (p >= n.emPLin) {
        final v = k * math.pow(p, n.emX);
        q += v;
        d += n.emX * v / p;
      } else if (p > 0) {
        final v1 = k * math.pow(n.emPLin, n.emX);
        q += v1 * p / n.emPLin;
        d += v1 / n.emPLin;
      }
    }
    _dOut = d;
    return q;
  }

  /// External outflow of [n] at head [hh] — demand and emitters as orifices,
  /// flow into an air vessel, minus the growth of an air pocket — with its
  /// derivative in [_dOut].
  double _out(_Node n, double hh) {
    var q = _demandOut(n, hh);
    var d = _dOut;
    final ves = n.vessel;
    if (ves != null) {
      q += _vesselFlow(ves, hh);
      d += ves.dq;
    }
    final air = n.air;
    if (air != null && air.open) {
      final t0 = _airTerm(air, hh);
      final mP = air.mP, volP = air.volP, mdotP = air.mdotP;
      const dh = 1e-4;
      final t1 = _airTerm(air, hh + dh), t2 = _airTerm(air, hh - dh);
      air.mP = mP;
      air.volP = volP;
      air.mdotP = mdotP;
      q -= t0;
      d -= (t1 - t2) / (2 * dh);
    }
    _dOut = d;
    return q;
  }

  /// Air pocket of [a] at head [hh]: isothermal gas p·∀ = m·R·T, mass by the
  /// trapezoidal rule of the orifice flows (Wylie & Streeter 1993). Returns
  /// 2·(∀_P − ∀)/Δt + I, the liquid inflow the node needs so that the pocket
  /// grows from ∀ to ∀_P (I = the liquid net inflow of the last step).
  double _airTerm(_Air a, double hh) {
    final pa = waterDensity * gravity * o.barometricHead;
    final pMin = waterDensity * gravity * math.max(o.vapourHead, 1e-3);
    final p = math.max(waterDensity * gravity * (hh - a.z + o.barometricHead), pMin);
    final temp = o.airTemperature;
    double flowAt(double p) =>
        p < pa ? airOrificeMassFlow(cdArea: a.cdaIn, upstream: pa, downstream: p, temperature: temp) : -airOrificeMassFlow(cdArea: a.cdaOut, upstream: p, downstream: pa, temperature: temp);
    // the orifice flow grows with √Δp, infinitely steep at Δp = 0, where
    // Newton steps went back and forth for ever: within 1 mm of water of
    // the atmospheric pressure it is interpolated linearly
    const band = 10.0; // Pa
    final mdot = (p - pa).abs() >= band ? flowAt(p) : (p < pa ? flowAt(pa - band) * (pa - p) / band : flowAt(pa + band) * (p - pa) / band);
    final m = math.max(0.0, a.m + 0.5 * dt * (a.mdot + mdot));
    final vol = m * airGasConstant * temp / p;
    a.mdotP = mdot;
    a.mP = m;
    a.volP = vol;
    return 2 * (vol - a.vol) / dt + a.imb;
  }

  /// Flow into vessel [v] at node head [hh]: the root of
  /// H − R·Q|Q| − z_w(Q) − C/∀(Q)ⁿ + H_b = 0 with ∀(Q) = ∀ − Δt·(Q₀ + Q)/2
  /// (Wylie & Streeter 1993; Chaudhry 2014); dQ/dH in [_Vessel.dq].
  double _vesselFlow(_Vessel v, double hh) {
    final half = 0.5 * dt;
    double gAt(double q, List<double> d) {
      final vq = v.vol - half * (v.qs + q);
      final r = q >= 0 ? v.rIn : v.rOut;
      final zq = v.area > 0 ? v.zw + half * (v.qs + q) / v.area : v.zw;
      final hg = v.cPoly / math.pow(vq, v.n);
      d[0] = -2 * r * q.abs() - (v.area > 0 ? half / v.area : 0) - v.n * hg / vq * half;
      return hh - r * q * q.abs() - zq - hg + o.barometricHead;
    }

    final der = [0.0];
    final qHi = (2 * v.vol / dt - v.qs) * (1 - 1e-9) - 1e-12;
    final qLo = 2 * (v.vol - v.total) / dt - v.qs;
    v.atLimit = false;
    if (gAt(qLo, der) <= 0) {
      v.dq = 0;
      v.qsP = qLo;
      v.atLimit = true;
      return qLo;
    }
    var lo = qLo, hi = qHi;
    var q = v.qsP.clamp(lo, hi);
    for (var it = 0; it < 60; it++) {
      final g = gAt(q, der);
      if (g > 0) {
        lo = q;
      } else {
        hi = q;
      }
      var qn = der[0] < 0 ? q - g / der[0] : 0.5 * (lo + hi);
      if (!(qn > lo && qn < hi)) qn = 0.5 * (lo + hi);
      if ((qn - q).abs() <= 1e-14 + 1e-12 * q.abs()) {
        q = qn;
        break;
      }
      q = qn;
    }
    gAt(q, der);
    v.dq = der[0] < 0 ? -1 / der[0] : 0;
    v.qsP = q;
    return q;
  }

  /// Net inflow of [n] at head [hh]: pipe characteristics, active elements
  /// and the external outflow.
  double _inflow(_Node n, double hh) {
    var f = n.s1 - n.s2 * hh;
    for (final k in n.el) {
      final e = elems[k];
      if (!e.active) continue;
      if (e.to == n.index) {
        f += e.q;
      } else {
        f -= e.q;
      }
    }
    return f - (n.simple ? (n.dem != 0 ? n.dem * n.factor : 0) : _out(n, hh));
  }

  /// Head of a node without active elements: F(H) = S₁ − S₂·H − Out(H) = 0,
  /// F decreasing, by Newton safeguarded with bisection.
  double _scalar(_Node n) {
    if (n.simple) {
      if (n.s2 <= 0) return n.h;
      return (n.s1 - (n.dem != 0 ? n.dem * n.factor : 0)) / n.s2;
    }
    var hh = n.h;
    var lo = -double.infinity, hi = double.infinity;
    for (var it = 0; it < 80; it++) {
      final out = _out(n, hh);
      final f = n.s1 - n.s2 * hh - out;
      final df = -n.s2 - _dOut;
      if (f > 0) {
        lo = hh;
      } else {
        hi = hh;
      }
      double hn;
      if (df < 0) {
        hn = hh - f / df;
      } else {
        hn = hh + (f > 0 ? 1 : -1);
      }
      if (!(hn > lo && hn < hi)) {
        if (lo.isFinite && hi.isFinite) {
          hn = 0.5 * (lo + hi);
        } else if (lo.isFinite) {
          hn = math.max(hn, lo + math.max(1.0, (hh - lo).abs()));
        } else if (hi.isFinite) {
          hn = math.min(hn, hi - math.max(1.0, (hh - hi).abs()));
        }
      }
      if ((hn - hh).abs() <= 1e-11 * (1 + hh.abs())) {
        hh = hn;
        break;
      }
      hh = hn;
    }
    return hh;
  }

  void _solveCluster(_Cluster c) {
    // only the solve after the last status change counts: a step that fails
    // while a state is about to change (an air pocket closing) is redone
    var solved = true;
    for (var pass = 0; pass < 16; pass++) {
      for (final i in c.nodes) {
        final n = nodes[i];
        if (n.fixed) {
          n.h = n.h0;
        } else if (n.cav) {
          n.h = n.hVap;
        }
      }
      if (c.elems.isEmpty) {
        for (final i in c.nodes) {
          final n = nodes[i];
          if (!n.fixed && !n.cav) n.h = _scalar(n);
        }
      } else {
        solved = _newton(c);
      }
      if (!_statusChecks(c)) break;
    }
    if (!solved && !notConvergedReported) {
      notConvergedReported = true;
      messages.add('transient_not_converged:${(tNow * 1000).round()}');
    }
    _commit(c);
  }

  /// Newton on the heads of the free nodes and the flows of the active
  /// elements of a cluster (dense, with partial pivoting). Nodes that the
  /// active elements join into a group without a pipe, an outflow or a
  /// fixed head (water trapped between two shut check valves) have no
  /// defined head: the group keeps its heads and passes no flow.
  bool _newton(_Cluster c) {
    // groups of nodes joined by active elements
    for (final i in c.nodes) {
      nodes[i].u = i;
    }
    int root(int i) {
      while (nodes[i].u != i) {
        i = nodes[i].u;
      }
      return i;
    }

    for (final k in c.elems) {
      final e = elems[k];
      if (!e.active) continue;
      final a = root(e.from), b = root(e.to);
      if (a != b) nodes[a].u = b;
    }
    final anchored = <int>{};
    for (final i in c.nodes) {
      final n = nodes[i];
      if (n.fixed || n.cav || n.s2 > 0 || !n.simple) anchored.add(root(i));
    }
    final roots = {for (final i in c.nodes) i: root(i)};
    var m = 0;
    for (final i in c.nodes) {
      final n = nodes[i];
      n.u = n.fixed || n.cav || !anchored.contains(roots[i]) ? -1 : m++;
    }
    for (final k in c.elems) {
      final e = elems[k];
      if (e.active && !anchored.contains(roots[e.from])) e.q = 0;
      e.u = e.active && anchored.contains(roots[e.from]) ? m++ : -1;
    }
    if (m == 0) return true;
    final res = _res, dx = _dx, x0 = _x0;
    var merit = _assemble(c, m, true);
    for (var it = 0; it < 60; it++) {
      if (merit < 1e-10) return true;
      for (var i = 0; i < m; i++) {
        res[i] = -res[i];
      }
      if (!_dense(_jac, res, m)) return false;
      for (var i = 0; i < m; i++) {
        dx[i] = res[i];
      }
      _saveState(c, x0);
      // backtracking on the largest residual, in metres of head
      var lambda = 1.0, trial = 0.0, small = true;
      for (var ls = 0; ls < 8; ls++) {
        small = _applyStep(c, x0, dx, lambda);
        trial = _assemble(c, m, false);
        if (trial < merit || trial < 1e-10 || small) break;
        lambda *= 0.5;
      }
      if (small) return true;
      merit = _assemble(c, m, true);
    }
    // a tiny residual left by a non-smooth law is accepted
    return merit < 1e-6;
  }

  Float64List _dx = Float64List(0), _x0 = Float64List(0);

  /// Residuals (and, with [jacobian], the Jacobian) of the cluster at the
  /// current heads and flows; returns the largest residual in metres of head:
  /// a node's flow residual is divided by the conductance of its pipe
  /// characteristics and outflows (not by that of its elements, infinite
  /// for a lossless check valve, which would hide any imbalance), with a
  /// floor for nodes joined only by elements.
  double _assemble(_Cluster c, int m, bool jacobian) {
    final jac = _jac, res = _res;
    if (jacobian) {
      for (var i = 0; i < m * m; i++) {
        jac[i] = 0;
      }
    }
    for (final i in c.nodes) {
      final n = nodes[i];
      final u = n.u;
      if (u < 0) continue;
      final out = n.simple ? (n.dem != 0 ? n.dem * n.factor : 0.0) : _out(n, n.h);
      final dOut = n.simple ? 0.0 : _dOut;
      res[u] = n.s1 - n.s2 * n.h - out;
      if (jacobian) jac[u * m + u] = -n.s2 - dOut;
      n.scale = n.s2 + dOut + 1e-3 * qRef;
    }
    var merit = 0.0;
    for (final k in c.elems) {
      final e = elems[k];
      final u = e.u;
      if (u < 0) continue;
      final nf = nodes[e.from], nt = nodes[e.to];
      final dhd = _elemLoss(e, e.q);
      res[u] = nf.h - nt.h - dhd;
      merit = math.max(merit, res[u].abs());
      if (jacobian) jac[u * m + u] = -_dLoss;
      if (nf.u >= 0) {
        res[nf.u] -= e.q;
        if (jacobian) {
          jac[u * m + nf.u] = 1;
          jac[nf.u * m + u] = -1;
        }
      }
      if (nt.u >= 0) {
        res[nt.u] += e.q;
        if (jacobian) {
          jac[u * m + nt.u] = -1;
          jac[nt.u * m + u] = 1;
        }
      }
    }
    for (final i in c.nodes) {
      final n = nodes[i];
      if (n.u < 0) continue;
      merit = math.max(merit, res[n.u].abs() / math.max(n.scale, 1e-12));
    }
    return merit;
  }

  void _saveState(_Cluster c, Float64List x0) {
    for (final i in c.nodes) {
      final n = nodes[i];
      if (n.u >= 0) x0[n.u] = n.h;
    }
    for (final k in c.elems) {
      final e = elems[k];
      if (e.u >= 0) x0[e.u] = e.q;
    }
  }

  /// Sets x = x0 + λ·dx (head changes capped at 100 m); true when the step
  /// is below the convergence threshold.
  bool _applyStep(_Cluster c, Float64List x0, Float64List dx, double lambda) {
    var small = true;
    for (final i in c.nodes) {
      final n = nodes[i];
      if (n.u < 0) continue;
      var d = lambda * dx[n.u];
      if (d.abs() > 100) d = d.sign * 100;
      n.h = x0[n.u] + d;
      if (d.abs() > 1e-10 * (1 + n.h.abs())) small = false;
    }
    for (final k in c.elems) {
      final e = elems[k];
      if (e.u < 0) continue;
      final d = lambda * dx[e.u];
      e.q = x0[e.u] + d;
      if (d.abs() > 1e-12 + 1e-10 * e.q.abs()) small = false;
    }
    return small;
  }

  double _dLoss = 0;

  /// Linear loss floor of valves and lumped pipes, m per m³/s (10⁻⁹ m at
  /// 1 m³/s).
  static const double _linearFloor = 1e-9;

  /// Head loss H_from − H_to that element [e] requires at flow [q], with its
  /// derivative in [_dLoss].
  double _elemLoss(_Elem e, double q) {
    final s = math.sqrt(q * q + qReg * qReg);
    switch (e.kind) {
      case _EK.valve:
        // orifice relation h = r·Q·|Q| (regularised near zero flow), with a
        // negligible linear floor so that a lossless check valve between two
        // fixed heads still has a defined flow
        _dLoss = e.rNow * (s + q * q / s) + _linearFloor;
        return e.rNow * q * s + _linearFloor * q;
      case _EK.lumped:
        _dLoss = e.r * (s + q * q / s) + e.inertia / dt + _linearFloor;
        return e.r * q * s + e.inertia / dt * (q - e.qPrev) + _linearFloor * q;
      case _EK.pump:
        // H = a·Q·|Q| + b·α·Q + c·α²: the affinity laws; with Q < 0 (only
        // inside the iterations, the check valve shuts reverse flow) the
        // impeller is a loss, which keeps the law monotone
        final (al, da) = _speed(e, q);
        final hp = e.pa * q * q.abs() + e.pb * al * q + e.pc * al * al;
        final dhp = 2 * e.pa * q.abs() + e.pb * al + (e.pb * q + 2 * e.pc * al) * da;
        _dLoss = -dhp;
        return -hp;
    }
  }

  /// Speed ratio α_P of pump [e] at the end of the step for flow [q] and
  /// dα_P/dQ. Running pumps keep α = 1; after the trip the speed equation
  /// α_P = α − (k/2)·(β + β_P) is solved with the torque model
  /// β = β₀·α² + (1 − β₀)·α·v (v = Q/Q_R ≥ 0): the torque at zero flow is β₀ of
  /// the operating torque and the power grows linearly with the flow at
  /// constant speed, a documented simplification of the homologous torque
  /// curve of a radial pump; the head follows the affinity laws,
  /// H = a·Q² + b·α·Q + c·α², the quadratic of the curve extended beyond its
  /// range (at α = 0 the stopped impeller is a quadratic loss).
  (double, double) _speed(_Elem e, double q) {
    if (e.running) return (1.0, 0.0);
    final k = e.kStep;
    final v = math.max(q, 0.0) / e.qr;
    final rhs = e.alpha - 0.5 * k * e.beta;
    if (rhs <= 0) return (0.0, 0.0);
    final a2 = 0.5 * k * e.beta0;
    final a1 = 1 + 0.5 * k * (1 - e.beta0) * v;
    final disc = a1 * a1 + 4 * a2 * rhs;
    final den = a1 + math.sqrt(math.max(disc, 0.0));
    if (den <= 0) return (0.0, 0.0);
    final al = 2 * rhs / den;
    final dadv = -0.5 * k * (1 - e.beta0) * al / (2 * a2 * al + a1);
    return (al, q > 0 ? dadv / e.qr : 0.0);
  }

  /// Gaussian elimination with partial pivoting of a·x = b (n×n, row major);
  /// the solution replaces b.
  static bool _dense(Float64List a, Float64List b, int n) {
    for (var col = 0; col < n; col++) {
      var piv = col;
      var best = a[col * n + col].abs();
      for (var r = col + 1; r < n; r++) {
        final v = a[r * n + col].abs();
        if (v > best) {
          best = v;
          piv = r;
        }
      }
      if (best < 1e-300) return false;
      if (piv != col) {
        for (var k = 0; k < n; k++) {
          final t = a[col * n + k];
          a[col * n + k] = a[piv * n + k];
          a[piv * n + k] = t;
        }
        final t = b[col];
        b[col] = b[piv];
        b[piv] = t;
      }
      final d = a[col * n + col];
      for (var r = col + 1; r < n; r++) {
        final f = a[r * n + col] / d;
        if (f == 0) continue;
        for (var k = col; k < n; k++) {
          a[r * n + k] -= f * a[col * n + k];
        }
        b[r] -= f * b[col];
      }
    }
    for (var r = n - 1; r >= 0; r--) {
      var s = b[r];
      for (var k = r + 1; k < n; k++) {
        s -= a[r * n + k] * b[k];
      }
      b[r] = s / a[r * n + r];
    }
    return true;
  }

  /// Volume (m³) below which a shrinking air pocket closes its valve.
  static const double _airVolumeFloor = 1e-6;

  /// Check valves, vapour cavities and air valves after a solve; true when
  /// a state changed and the cluster must be solved again.
  bool _statusChecks(_Cluster c) {
    var changed = false;
    for (final k in c.elems) {
      final e = elems[k];
      if (!e.check || e.shut || e.flips >= 2) continue;
      if (!e.cvClosed) {
        if (e.q < -qTol) {
          e.cvClosed = true;
          e.q = 0;
          e.flips++;
          changed = true;
          checkClosures.putIfAbsent(e.id, () => tNow);
        }
      } else {
        var drive = nodes[e.from].h - nodes[e.to].h;
        if (e.kind == _EK.pump) {
          final (al, _) = _speed(e, 0);
          drive += e.pc * al * al;
        }
        if (drive > 1e-6) {
          e.cvClosed = false;
          e.flips++;
          changed = true;
        }
      }
    }
    for (final i in c.nodes) {
      final n = nodes[i];
      if (n.fixed) continue;
      if (n.cav) {
        final inflow = _inflow(n, n.hVap);
        final v = n.cavVol - dt * (psi * inflow + (1 - psi) * n.cavI);
        if (v <= 0 && inflow <= 0) {
          // emptied only by the inflow of the last step: this one's would
          // open it again (the liquid head is below the vapour head), so it
          // stays, empty, at the vapour head
          n.cavVolP = 0;
          n.cavIP = inflow;
        } else if (v <= 0) {
          n.cav = false;
          n.cavLock = true;
          n.cavVol = 0;
          n.cavI = 0;
          changed = true;
        } else {
          n.cavVolP = v;
          n.cavIP = inflow;
        }
      } else if (n.dvcm && !n.cavLock && n.h < n.hVap) {
        n.cav = true;
        n.cavVol = 0;
        n.cavI = 0;
        changed = true;
      }
      final air = n.air;
      if (air != null) {
        if (!air.open) {
          if (!air.lock && n.h < air.z - 1e-9) {
            air.open = true;
            air.reset();
            changed = true;
          }
        } else {
          _airTerm(air, n.h);
          // a shrinking pocket below a cubic centimetre is gone: the float
          // has shut, and the stiff law of a vanishing pocket would only
          // stall the Newton of the step
          if (air.mP <= 0 || air.volP <= 1e-15 || (air.volP < _airVolumeFloor && air.volP < air.vol)) {
            air.open = false;
            air.lock = true;
            air.reset();
            changed = true;
          }
        }
      }
    }
    return changed;
  }

  /// Keeps the state of the step: cavities, air pockets, vessels, pump speeds.
  void _commit(_Cluster c) {
    for (final i in c.nodes) {
      final n = nodes[i];
      if (n.fixed) continue;
      if (n.cav) {
        n.h = n.hVap;
        n.cavVol = n.cavVolP;
        n.cavI = n.cavIP;
        if (n.cavVol > n.cavMax) n.cavMax = n.cavVol;
      }
      final air = n.air;
      if (air != null && air.open) {
        _airTerm(air, n.h);
        final volOld = air.vol;
        air.imb = -2 * (air.volP - volOld) / dt - air.imb;
        air.vol = air.volP;
        air.m = air.mP;
        air.mdot = air.mdotP;
        if (air.vol > air.maxVol) air.maxVol = air.vol;
        if (air.vol > 0) air.admitted = true;
      }
      final v = n.vessel;
      if (v != null) {
        final q = _vesselFlow(v, n.h);
        if (v.atLimit) v.drained = true;
        v.vol = v.vol - 0.5 * dt * (v.qs + q);
        if (v.area > 0) v.zw += 0.5 * dt * (v.qs + q) / v.area;
        v.qs = q;
        if (v.vol < v.minVol) v.minVol = v.vol;
        if (v.vol > v.maxVol) v.maxVol = v.vol;
      }
    }
    for (final k in c.elems) {
      final e = elems[k];
      if (!e.active) e.q = 0;
      if (e.kind == _EK.pump && !e.running) {
        final q = e.active ? e.q : 0.0;
        final (al, _) = _speed(e, q);
        e.alpha = al;
        e.beta = e.beta0 * al * al + (1 - e.beta0) * al * q / e.qr;
      }
    }
  }

  // ------------------------------------------------------------ output

  void _record(double t) {
    times.add(t);
    for (final p in probes) {
      final s = p.series;
      switch (p.kind) {
        case 0:
          final n = nodes[p.index];
          s.heads.add(n.h);
          s.pressures.add(n.h - n.z);
          var out = _demandOut(n, n.h);
          if (n.vessel != null) out += n.vessel!.qs;
          s.flows.add(out);
          s.volumes.add(n.air != null ? n.air!.vol : (n.vessel != null ? n.vessel!.vol : n.cavVol));
        case 1:
          final m = mapped[p.index];
          final hh = _mappedHead(m);
          s.heads.add(hh);
          s.pressures.add(hh - m.z);
          s.flows.add(0);
          final c = chains[m.chain];
          s.volumes.add(c.lumped ? 0 : cav[c.offset + (m.w < 0.5 ? m.s : m.s + 1)]);
        case 2:
          final c = chains[p.index];
          final f = (p.x / c.dx).clamp(0.0, c.reaches.toDouble());
          var i = f.floor();
          if (i >= c.reaches) i = c.reaches - 1;
          final w = f - i;
          final sec = c.offset + i;
          final hh = h[sec] + (h[sec + 1] - h[sec]) * w;
          final zz = z[sec] + (z[sec + 1] - z[sec]) * w;
          final q = qd[sec] + (qu[sec + 1] - qd[sec]) * w;
          s.heads.add(hh);
          s.pressures.add(hh - zz);
          s.flows.add(q * p.dir);
        case 3:
          final e = elems[p.index];
          final nf = nodes[e.from], nt = nodes[e.to];
          final hh = nf.h + (nt.h - nf.h) * p.f;
          s.heads.add(hh);
          s.pressures.add(hh - (nf.z + (nt.z - nf.z) * p.f));
          s.flows.add(e.active ? e.q : 0);
          if (e.kind == _EK.pump) s.speeds.add(e.running ? 1 : e.alpha);
        case 4:
          final c = chains[p.index];
          final e = elems[c.lumpElem];
          final w = c.length > 0 ? p.x / c.length : 0.0;
          final n0 = nodes[c.n0], nk = nodes[c.nk];
          final hh = n0.h + (nk.h - n0.h) * w;
          s.heads.add(hh);
          s.pressures.add(hh - (n0.z + (nk.z - n0.z) * w));
          s.flows.add(e.q * p.dir);
      }
    }
  }

  TransientResult _results(int steps) {
    final net = model.network;
    final vacuum = o.vacuumLimit ?? hvg;
    final nodeEnv = <String, TransientNodeEnvelope>{};
    for (final id in net.nodes.keys) {
      final ni = nodeIndex[id];
      final mi = mappedIndex[id];
      if (ni != null) {
        final n = nodes[ni];
        final air = n.air, v = n.vessel;
        nodeEnv[id] = TransientNodeEnvelope(
          nodeId: id,
          elevation: n.z,
          steadyHead: n.h0,
          maxHead: n.hMax,
          minHead: n.hMin,
          timeOfMax: n.tMax,
          timeOfMin: n.tMin,
          maxCavityVolume: n.cavMax,
          maxAirVolume: air?.maxVol ?? 0,
          minGasVolume: v == null ? 0 : math.min(v.minVol, v.vol),
          maxGasVolume: v == null ? 0 : math.max(v.maxVol, v.vol),
        );
        if (n.hMin - n.z <= vacuum + 1e-6) messages.add('transient_vacuum:$id');
        if (n.cavMax > 1e-12) messages.add('transient_column_separation:$id');
        if (air != null && air.admitted) messages.add('transient_air_admitted:$id');
        if (v != null && v.drained) messages.add('transient_vessel_drained:$id');
      } else if (mi != null) {
        final m = mapped[mi];
        final c = chains[m.chain];
        final cv = c.lumped ? 0.0 : math.max(cavMax[c.offset + m.s], m.w > 0 ? cavMax[c.offset + m.s + 1] : 0.0);
        nodeEnv[id] = TransientNodeEnvelope(nodeId: id, elevation: m.z, steadyHead: m.h0, maxHead: m.hMax, minHead: m.hMin, timeOfMax: m.tMax, timeOfMin: m.tMin, maxCavityVolume: cv);
        if (m.hMin - m.z <= vacuum + 1e-6) messages.add('transient_vacuum:$id');
        if (cv > 1e-12) messages.add('transient_column_separation:$id');
      } else {
        final n = net.nodes[id]!;
        final hh = headOf(id);
        nodeEnv[id] = TransientNodeEnvelope(nodeId: id, elevation: n.elevation, steadyHead: hh, maxHead: hh, minHead: hh, timeOfMax: 0, timeOfMin: 0);
      }
    }

    TransientPointEnvelope endPoint(String id, double chainage) {
      final env = nodeEnv[id];
      if (env != null) return TransientPointEnvelope(chainage: chainage, elevation: env.elevation, maxHead: env.maxHead, minHead: env.minHead, maxCavityVolume: env.maxCavityVolume);
      final n = nodes[nodeIndex[id]!];
      return TransientPointEnvelope(chainage: chainage, elevation: n.z, maxHead: n.hMax, minHead: n.hMin, maxCavityVolume: n.cavMax);
    }

    final linkEnv = <String, TransientLinkEnvelope>{};
    final speeds = <String, double>{};
    final interpolated = <String>[], lumped = <String>[];
    var reaches = 0;
    for (final c in chains) {
      reaches += c.reaches;
    }
    final elemById = {for (final e in elems) e.id: e};
    for (final l in net.links) {
      final pc = pipeOfLink[l.id];
      if (pc != null) {
        final c = chains[pc.$1];
        final k = pc.$2;
        final piece = c.pieces[k];
        final dir = c.dirs[k];
        final x0 = c.xs[k], x1 = c.xs[k + 1];
        final pts = <TransientPointEnvelope>[endPoint(piece.from, 0)];
        if (!c.lumped) {
          final inner = <TransientPointEnvelope>[];
          final j0 = (x0 / c.dx).floor() + 1, j1 = (x1 / c.dx).ceil() - 1;
          for (var j = math.max(j0, 1); j <= math.min(j1, c.reaches - 1); j++) {
            final x = j * c.dx;
            if (x <= x0 + 1e-9 || x >= x1 - 1e-9) continue;
            final s = c.offset + j;
            inner.add(TransientPointEnvelope(chainage: dir == 1 ? x - x0 : x1 - x, elevation: z[s], maxHead: hMax[s], minHead: hMin[s], maxCavityVolume: cavMax[s]));
          }
          if (dir != 1) inner.sort((a, b) => a.chainage.compareTo(b.chainage));
          pts.addAll(inner);
        }
        pts.add(endPoint(piece.to, piece.length));
        final treatment = c.treatment;
        linkEnv[l.id] = TransientLinkEnvelope(linkId: l.id, points: pts, treatment: treatment, celerity: c.lumped ? piece.celerity : c.aUsed, reaches: c.lumped ? 0 : c.reaches);
        speeds[l.id] = c.lumped ? piece.celerity : c.aUsed;
        if (treatment == TransientLinkTreatment.interpolated) interpolated.add(l.id);
        if (treatment == TransientLinkTreatment.lumped) lumped.add(l.id);
      } else if (elemById.containsKey(l.id)) {
        linkEnv[l.id] = TransientLinkEnvelope(linkId: l.id, points: [endPoint(l.from, 0), endPoint(l.to, 0)], treatment: TransientLinkTreatment.element);
      }
    }
    for (final l in net.links) {
      final env = linkEnv[l.id];
      if (env == null) continue;
      final data = model.linkData[l.id];
      final rating = data?.rating;
      if (rating != null && rating > 0 && env.maxPressure > rating + 1e-9) messages.add('transient_overpressure:${l.id}');
      final minRating = data?.minRating;
      if (minRating != null && env.minPressure < minRating - 1e-9) messages.add('transient_underpressure:${l.id}');
      if (env.treatment == TransientLinkTreatment.grid || env.treatment == TransientLinkTreatment.interpolated) {
        final inner = env.points.sublist(1, env.points.length - 1);
        if (inner.any((p) => p.minPressure <= vacuum + 1e-6)) messages.add('transient_vacuum_pipe:${l.id}');
        if (inner.any((p) => p.maxCavityVolume > 1e-12)) messages.add('transient_column_separation_pipe:${l.id}');
      }
    }
    return TransientResult(
      timeStep: dt,
      steps: steps,
      duration: steps * dt,
      reaches: reaches,
      maxWaveSpeedAdjustment: maxAdjust,
      waveSpeeds: speeds,
      interpolatedLinks: interpolated,
      lumpedLinks: lumped,
      nodes: nodeEnv,
      links: linkEnv,
      times: times,
      series: [for (final p in probes) p.series],
      checkValveClosures: checkClosures,
      messages: messages,
    );
  }
}
