/// Pipe friction head-loss models.
///
/// All functions use SI: flow Q in m³/s, diameter D in m, length L in m,
/// head loss in metres of water.
library;

import 'dart:math' as math;

import '../units.dart';

enum FrictionMethod { hazenWilliams, darcyWeisbach }

/// Hazen-Williams head loss (SI form): hf = 10.67·L·Q^1.852 / (C^1.852·D^4.871).
double hazenWilliamsLoss({
  required double flow,
  required double diameter,
  required double length,
  required double c,
}) {
  if (flow == 0 || length == 0) return 0;
  final q = flow.abs();
  final hf = 10.67 *
      length *
      math.pow(q, 1.852) /
      (math.pow(c, 1.852) * math.pow(diameter, 4.871));
  return flow < 0 ? -hf : hf;
}

/// Hazen-Williams resistance coefficient r so that hf = r·Q^1.852.
double hazenWilliamsResistance({
  required double diameter,
  required double length,
  required double c,
}) =>
    10.67 * length / (math.pow(c, 1.852) * math.pow(diameter, 4.871));

/// Unit head-loss gradient J (m/m) by Hazen-Williams.
double hazenWilliamsGradient({
  required double flow,
  required double diameter,
  required double c,
}) =>
    hazenWilliamsLoss(flow: flow, diameter: diameter, length: 1, c: c);

/// Reynolds number for a full circular pipe.
double reynolds({
  required double flow,
  required double diameter,
  double kinematicViscosity = 1.004e-6,
}) {
  final v = velocity(flow: flow.abs(), diameter: diameter);
  return v * diameter / kinematicViscosity;
}

/// Mean velocity (m/s).
double velocity({required double flow, required double diameter}) =>
    flow / (math.pi * diameter * diameter / 4);

double flowForVelocity({required double velocity, required double diameter}) =>
    velocity * math.pi * diameter * diameter / 4;

/// Explicit Swamee-Jain approximation of the Colebrook-White friction factor.
double swameeJain({required double reynolds, required double relRoughness}) {
  final term = relRoughness / 3.7 + 5.74 / math.pow(reynolds, 0.9);
  final l = math.log(term) / math.ln10;
  return 0.25 / (l * l);
}

/// Colebrook-White friction factor solved iteratively (reference accuracy).
double colebrook({
  required double reynolds,
  required double relRoughness,
  int maxIter = 50,
}) {
  var f = swameeJain(reynolds: reynolds, relRoughness: relRoughness);
  for (var i = 0; i < maxIter; i++) {
    final rhs = -2 *
        math.log(relRoughness / 3.7 + 2.51 / (reynolds * math.sqrt(f))) /
        math.ln10;
    final fNew = 1 / (rhs * rhs);
    if ((fNew - f).abs() < 1e-10) return fNew;
    f = fNew;
  }
  return f;
}

/// Blasius friction factor for hydraulically smooth pipes (Re < 1e5).
double blasius(double reynolds) => 0.3164 / math.pow(reynolds, 0.25);

/// Darcy friction factor covering laminar, transitional (cubic interpolation
/// as in EPANET) and turbulent (Swamee-Jain) regimes.
double darcyFrictionFactor({
  required double reynolds,
  required double relRoughness,
}) {
  final re = reynolds;
  if (re <= 0) return 0;
  if (re < 2000) return 64 / re;
  if (re < 4000) {
    // EPANET cubic interpolation between the laminar value at Re = 2000
    // (0.032) and the Swamee-Jain value and slope at Re = 4000 (Dunlop's
    // polynomial). Both y2 and y3 are evaluated at Re = 4000; using the
    // current Re in y2 breaks the slope match and dents the curve.
    final y2 = relRoughness / 3.7 + 5.74 / math.pow(4000, 0.9);
    final y3 = -2 / math.ln10 * math.log(y2); // = -2·log10(y2)
    final fa = math.pow(y3, -2).toDouble();
    final fb = fa * (2 - 0.00514215 / (y2 * y3));
    final r = re / 2000;
    final x1 = 7 * fa - fb;
    final x2 = 0.128 - 17 * fa + 2.5 * fb;
    final x3 = -0.128 + 13 * fa - 2 * fb;
    final x4 = r * (0.032 - 3 * fa + 0.5 * fb);
    return x1 + r * (x2 + r * (x3 + x4));
  }
  return swameeJain(reynolds: re, relRoughness: relRoughness);
}

/// Darcy-Weisbach head loss: hf = f·(L/D)·V²/(2g).
double darcyWeisbachLoss({
  required double flow,
  required double diameter,
  required double length,
  required double roughness, // absolute roughness ε in m
  double kinematicViscosity = 1.004e-6,
}) {
  if (flow == 0 || length == 0) return 0;
  final q = flow.abs();
  final v = velocity(flow: q, diameter: diameter);
  final re = v * diameter / kinematicViscosity;
  final f = darcyFrictionFactor(
    reynolds: re,
    relRoughness: roughness / diameter,
  );
  final hf = f * (length / diameter) * v * v / (2 * gravity);
  return flow < 0 ? -hf : hf;
}

/// Generic friction loss dispatcher.
double frictionLoss({
  required FrictionMethod method,
  required double flow,
  required double diameter,
  required double length,
  double c = 150,
  double roughness = 1.5e-6,
  double kinematicViscosity = 1.004e-6,
}) {
  switch (method) {
    case FrictionMethod.hazenWilliams:
      return hazenWilliamsLoss(
        flow: flow,
        diameter: diameter,
        length: length,
        c: c,
      );
    case FrictionMethod.darcyWeisbach:
      return darcyWeisbachLoss(
        flow: flow,
        diameter: diameter,
        length: length,
        roughness: roughness,
        kinematicViscosity: kinematicViscosity,
      );
  }
}

/// Flow exponent m of the loss law used by the Christiansen factor.
double flowExponent(FrictionMethod method) => switch (method) {
  FrictionMethod.hazenWilliams => 1.852,
  FrictionMethod.darcyWeisbach => 1.85, // ≈ Blasius 1.75 .. fully rough 2.0
};

/// Christiansen (1942) multiple-outlet factor.
/// [outlets] N equally spaced outlets, [m] flow exponent.
/// If [firstOutletAtHalfSpacing] the Jensen-Fratini form is used.
double christiansenF({
  required int outlets,
  double m = 1.852,
  bool firstOutletAtHalfSpacing = false,
}) {
  final n = outlets.toDouble();
  if (outlets <= 0) return 1;
  if (firstOutletAtHalfSpacing) {
    return (2 * n / (2 * n - 1)) *
        (1 / (m + 1) + math.sqrt(m - 1) / (6 * n * n));
  }
  return 1 / (m + 1) + 1 / (2 * n) + math.sqrt(m - 1) / (6 * n * n);
}

/// Scaloppi (1988) adjustment for a first outlet located r·S from the inlet.
double scaloppiF({required int outlets, required double r, double m = 1.852}) {
  final f = christiansenF(outlets: outlets, m: m);
  final n = outlets.toDouble();
  return (n * f + r - 1) / (n + r - 1);
}

/// Equivalent single-pipe diameter for n identical parallel laterals
/// (Hazen-Williams): D = (d^4.871 · n^1.852)^0.2053.
double equivalentDiameterParallel(double d, int n) =>
    math.pow(math.pow(d, 4.871) * math.pow(n, 1.852), 0.2053).toDouble();

/// Hazen-Williams C converted to an equivalent absolute roughness for the
/// given diameter and velocity (Diskin 1960 approximation).
double hazenCToRoughness(double c, double diameter, {double velocity = 1.0}) {
  // ε/D = 3.7·10^(-1/(2·sqrt(f))) - ... use inversion via bisection on f.
  // Compute f from HW: hf = f L V²/(2gD)  and hf = 10.67 L Q^1.852/(C^1.852 D^4.871)
  final q = flowForVelocity(velocity: velocity, diameter: diameter);
  final hf = hazenWilliamsLoss(flow: q, diameter: diameter, length: 1, c: c);
  final f = hf * 2 * gravity * diameter / (velocity * velocity);
  final re = velocity * diameter / 1.004e-6;
  // Solve Colebrook for ε/D given f and Re.
  final inv = 1 / math.sqrt(f);
  final term = math.pow(10, -inv / 2) - 2.51 / (re * math.sqrt(f));
  final relRough = math.max(0.0, term * 3.7);
  return relRough * diameter;
}
