/// Gated pipe (or lay-flat pipe with punched holes) feeding furrows: the
/// opening of every gate, or the hole diameter from a standard list, so
/// each furrow receives its target flow, and the inlet head that makes it
/// possible.
///
/// * Along the pipe the flow falls gate by gate; the pressure head changes
///   with the friction of the flow left in the pipe (Hazen-Williams or
///   Darcy-Weisbach) and with the ground slope — the energy balance of NRCS
///   NEH 623 ch. 4, eq. 4-89, applied stretch by stretch instead of with the
///   whole flow over the whole length (velocity-head recovery neglected).
/// * Every gate is an orifice q = Cd·A·√(2gh), h the pressure head at the
///   gate; Cd = 0.61 for a sharp-edged opening (U.S. Bureau of Reclamation,
///   Water Measurement Manual, ch. 13).
/// * The required area gives an equivalent diameter; the hole is the
///   smallest standard diameter at least that large, partly closed to the
///   required area (an adjustable gate) or, for fixed holes, passing the
///   flow of the full hole. The minimum inlet head delivers the target
///   through the largest hole at the critical gate.
library;

import 'dart:math' as math;

import '../hydraulics/friction.dart';
import '../units.dart';

/// Hole diameters (mm) of the usual punches for lay-flat gated pipe: 1/2 to
/// 1-1/2 inch in 1/8-inch steps, then 1-3/4 and 2 inches.
const standardGateHolesMm = <double>[12.7, 15.9, 19.1, 22.2, 25.4, 28.6, 31.8, 34.9, 38.1, 44.5, 50.8];

/// Gated pipe data for [designGatedPipe]. All values in SI.
class GatedPipeSpec {
  const GatedPipeSpec({
    required this.outlets,
    required this.outletSpacingM,
    required this.targetFlow,
    this.targetFlows = const [],
    this.firstOutletM = -1,
    this.pipeInnerMm = 250,
    this.hazenC = 150,
    this.method = FrictionMethod.hazenWilliams,
    this.roughnessMm = 0.007,
    this.kinematicViscosity = 1.004e-6,
    this.slope = 0,
    this.inletHeadM = 0,
    this.dischargeCoefficient = 0.61,
    this.holeDiametersMm = standardGateHolesMm,
  });

  /// Number of gates and their spacing (the furrow spacing, m).
  final int outlets;
  final double outletSpacingM;

  /// Flow every gate must deliver (m³/s), or one value per gate.
  final double targetFlow;
  final List<double> targetFlows;

  /// Distance of the first gate from the inlet (m); negative = half the spacing.
  final double firstOutletM;

  /// Pipe inner diameter (mm) and friction data.
  final double pipeInnerMm;
  final double hazenC;
  final FrictionMethod method;
  final double roughnessMm;
  final double kinematicViscosity;

  /// Fall of the ground along the pipe in the direction of flow (m/m; positive downhill).
  final double slope;

  /// Pressure head at the inlet (m, at the gate level); 0 = the minimum one.
  final double inletHeadM;

  /// Discharge coefficient of the gates and the hole diameters available (mm).
  final double dischargeCoefficient;
  final List<double> holeDiametersMm;

  double flowOf(int i) => i < targetFlows.length ? targetFlows[i] : targetFlow;
}

/// One gate of the gated pipe.
class GateRow {
  const GateRow({required this.index, required this.distanceM, required this.pipeFlow, required this.headM, required this.targetFlow, required this.areaMm2, required this.diameterMm, required this.holeMm, required this.openingPct, required this.fullFlow});

  /// 1-based gate number from the inlet and its distance (m).
  final int index;
  final double distanceM;

  /// Flow in the pipe arriving at the gate (m³/s) and pressure head at the gate (m).
  final double pipeFlow;
  final double headM;

  /// Target flow (m³/s), required opening area (mm²) and its equivalent diameter (mm).
  final double targetFlow;
  final double areaMm2;
  final double diameterMm;

  /// Standard hole chosen (mm; 0 = none large enough), the opening of an
  /// adjustable gate (% of the hole area) and the flow of the full hole (m³/s).
  final double holeMm;
  final double openingPct;
  final double fullFlow;

  Map<String, dynamic> toJson() => {'i': index, 'x': distanceM, 'qp': pipeFlow, 'h': headM, 'q': targetFlow, 'a': areaMm2, 'd': diameterMm, 'hole': holeMm, 'open': openingPct, 'qf': fullFlow};
  static GateRow fromJson(Map<String, dynamic> j) {
    double d(String k) => (j[k] as num?)?.toDouble() ?? 0;
    return GateRow(index: (j['i'] as num?)?.toInt() ?? 0, distanceM: d('x'), pipeFlow: d('qp'), headM: d('h'), targetFlow: d('q'), areaMm2: d('a'), diameterMm: d('d'), holeMm: d('hole'), openingPct: d('open'), fullFlow: d('qf'));
  }
}

/// Gates, heads and inlet check of a gated pipe.
class GatedPipeResult {
  const GatedPipeResult({required this.gates, required this.inletHeadM, required this.minInletHeadM, required this.totalFlow, required this.frictionLossM, required this.elevationGainM, required this.inletVelocity, required this.warnings});
  final List<GateRow> gates;

  /// Inlet head used (m) and the smallest that delivers every target with the largest hole (m).
  final double inletHeadM;
  final double minInletHeadM;
  final double totalFlow;

  /// Friction from the inlet to the last gate (m) and head gained by the slope (m).
  final double frictionLossM;
  final double elevationGainM;
  final double inletVelocity;

  /// Message codes (`gated_pipe_*`, with `:<id>` when an id was given).
  final List<String> warnings;

  bool get inletHeadOk => inletHeadM >= minInletHeadM - 1e-9;

  Map<String, dynamic> toJson() => {'gates': gates.map((g) => g.toJson()).toList(), 'hin': inletHeadM, 'hmin': minInletHeadM, 'q': totalFlow, 'hf': frictionLossM, 'dz': elevationGainM, 'v': inletVelocity, 'warn': warnings};
  static GatedPipeResult fromJson(Map<String, dynamic> j) {
    double d(String k) => (j[k] as num?)?.toDouble() ?? 0;
    return GatedPipeResult(
      gates: ((j['gates'] as List?) ?? const []).map((g) => GateRow.fromJson(g as Map<String, dynamic>)).toList(), inletHeadM: d('hin'), minInletHeadM: d('hmin'), totalFlow: d('q'), frictionLossM: d('hf'),
      elevationGainM: d('dz'), inletVelocity: d('v'), warnings: ((j['warn'] as List?) ?? const []).cast<String>(),
    );
  }
}

/// Opening or hole of every gate and the inlet head needed.
GatedPipeResult designGatedPipe(GatedPipeSpec s, {String id = ''}) {
  final warnings = <String>[];
  void warn(String code) {
    final c = id.isEmpty ? code : '$code:$id';
    if (!warnings.contains(c)) warnings.add(c);
  }

  final n = math.max(0, s.outlets);
  final d = s.pipeInnerMm / 1000;
  final cd = s.dischargeCoefficient;
  final holes = [...s.holeDiametersMm.where((h) => h > 0)]..sort();
  final first = s.firstOutletM >= 0 ? s.firstOutletM : s.outletSpacingM / 2;
  final xs = [for (var i = 0; i < n; i++) first + i * s.outletSpacingM];
  final qs = [for (var i = 0; i < n; i++) math.max(0.0, s.flowOf(i))];
  final total = qs.fold(0.0, (a, b) => a + b);
  double loss(double flow, double len) {
    if (flow <= 0 || len <= 0 || d <= 0) return 0;
    return switch (s.method) {
      FrictionMethod.hazenWilliams => hazenWilliamsLoss(flow: flow, diameter: d, length: len, c: s.hazenC),
      FrictionMethod.darcyWeisbach => darcyWeisbachLoss(flow: flow, diameter: d, length: len, roughness: s.roughnessMm / 1000, kinematicViscosity: s.kinematicViscosity),
      // plastic lay-flat or rigid gated pipe
      FrictionMethod.scobey => scobeyLoss(flow: flow, diameter: d, length: len, ks: 0.32),
      FrictionMethod.manning => manningLoss(flow: flow, diameter: d, length: len, n: 0.009),
    };
  }

  // head change from the inlet to every gate (independent of the inlet head)
  final delta = <double>[];
  final pipeFlow = <double>[];
  var flow = total, x = 0.0, change = 0.0, hfTotal = 0.0;
  for (var i = 0; i < n; i++) {
    final len = xs[i] - x;
    final hf = loss(flow, len);
    hfTotal += hf;
    change += s.slope * len - hf;
    delta.add(change);
    pipeFlow.add(flow);
    flow -= qs[i];
    x = xs[i];
  }
  // smallest inlet head that delivers every target through the largest hole
  final aMax = holes.isEmpty ? 0.0 : math.pi / 4 * math.pow(holes.last / 1000, 2);
  var hMin = 0.0;
  for (var i = 0; i < n; i++) {
    if (qs[i] <= 0) continue;
    final need = aMax > 0 && cd > 0 ? math.pow(qs[i] / (cd * aMax), 2) / (2 * gravity) : 0.0;
    hMin = math.max(hMin, need - delta[i]);
  }
  if (aMax <= 0 && s.inletHeadM <= 0) warn('gated_pipe_no_holes');
  final inlet = s.inletHeadM > 0 ? s.inletHeadM : hMin;
  if (s.inletHeadM > 0 && s.inletHeadM < hMin - 1e-9) warn('gated_pipe_low_head');
  final gates = <GateRow>[];
  for (var i = 0; i < n; i++) {
    final h = inlet + delta[i];
    var area = 0.0, hole = 0.0, opening = 0.0, full = 0.0;
    if (h <= 0) {
      warn('gated_pipe_no_head');
    } else if (qs[i] > 0 && cd > 0) {
      area = qs[i] / (cd * math.sqrt(2 * gravity * h));
      for (final dh in holes) {
        final a = math.pi / 4 * math.pow(dh / 1000, 2);
        if (a >= area - 1e-12) {
          hole = dh;
          opening = 100 * area / a;
          full = cd * a * math.sqrt(2 * gravity * h);
          break;
        }
      }
      if (hole == 0) warn('gated_pipe_hole_too_small');
    }
    gates.add(GateRow(index: i + 1, distanceM: xs[i], pipeFlow: pipeFlow[i], headM: h, targetFlow: qs[i], areaMm2: area * 1e6, diameterMm: math.sqrt(4 * area / math.pi) * 1000, holeMm: hole, openingPct: opening, fullFlow: full));
  }
  return GatedPipeResult(
    gates: gates, inletHeadM: inlet, minInletHeadM: hMin, totalFlow: total, frictionLossM: hfTotal, elevationGainM: n > 0 ? s.slope * xs.last : 0, inletVelocity: d > 0 ? velocity(flow: total, diameter: d) : 0, warnings: warnings,
  );
}
