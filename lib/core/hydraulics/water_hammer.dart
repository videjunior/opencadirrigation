/// Water hammer (surge) estimates by the Joukowsky equation.
library;

import 'dart:math' as math;

import '../units.dart';

/// Young's modulus (Pa) and Poisson's ratio of common pipe materials.
enum PipeMaterial {
  pvc(3.0e9, 'PVC', 0.38),
  pehd(0.9e9, 'HDPE/PE100', 0.45),
  peld(0.3e9, 'LDPE', 0.45),
  steel(2.0e11, 'Steel', 0.30),
  ductileIron(1.7e11, 'Ductile iron', 0.28),
  aluminium(7.0e10, 'Aluminium', 0.33),
  concrete(3.0e10, 'Concrete', 0.20);

  const PipeMaterial(this.youngModulus, this.label, this.poissonRatio);
  final double youngModulus;
  final String label;
  final double poissonRatio;
}

/// Head (m of water) of the outside pressure that buckles a long thin pipe
/// of inner [diameter] and [wallThickness] with nothing around it (the
/// pressure inside below the atmosphere by as much collapses it): the
/// critical pressure of a long thin tube, p = 2E/(1 − ν²)·(t/Dm)³ with the
/// mean diameter Dm (Timoshenko & Gere 1961, Theory of Elastic Stability,
/// §7.3; the formula of AWWA M23 and M55 for pipe without soil support).
double collapsePressureHead({required double diameter, required double wallThickness, required PipeMaterial material}) {
  if (!(diameter > 0) || !(wallThickness > 0)) return double.infinity;
  final nu = material.poissonRatio;
  final r = wallThickness / (diameter + wallThickness);
  return 2 * material.youngModulus / (1 - nu * nu) * r * r * r / (waterDensity * gravity);
}

const double waterBulkModulus = 2.2e9; // Pa

/// Pressure-wave celerity a = sqrt((K/ρ) / (1 + K·D/(E·e))).
double waveCelerity({required double diameter, required double wallThickness, required PipeMaterial material}) {
  final kOverRho = waterBulkModulus / waterDensity;
  final term = 1 + waterBulkModulus * diameter / (material.youngModulus * wallThickness);
  return math.sqrt(kOverRho / term);
}

/// Joukowsky surge head ΔH = a·ΔV/g (metres of water).
double joukowskySurgeHead({required double celerity, required double velocityChange}) => celerity * velocityChange / gravity;

/// Critical closure time 2L/a (s): closures faster than this give the full surge.
double criticalClosureTime({required double length, required double celerity}) => 2 * length / celerity;
