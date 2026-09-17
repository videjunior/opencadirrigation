/// Water hammer (surge) estimates by the Joukowsky equation.
library;

import 'dart:math' as math;

import '../units.dart';

/// Young's modulus (Pa) of common pipe materials.
enum PipeMaterial {
  pvc(3.0e9, 'PVC'),
  pehd(0.9e9, 'HDPE/PE100'),
  peld(0.3e9, 'LDPE'),
  steel(2.0e11, 'Steel'),
  ductileIron(1.7e11, 'Ductile iron'),
  aluminium(7.0e10, 'Aluminium'),
  concrete(3.0e10, 'Concrete');

  const PipeMaterial(this.youngModulus, this.label);
  final double youngModulus;
  final String label;
}

const double waterBulkModulus = 2.2e9; // Pa

/// Pressure-wave celerity a = sqrt((K/ρ) / (1 + K·D/(E·e))).
double waveCelerity({required double diameter, required double wallThickness, required PipeMaterial material}) {
  final kOverRho = waterBulkModulus / waterDensity;
  final term = 1 + waterBulkModulus * diameter / (material.youngModulus * wallThickness);
  return math.sqrt(kOverRho / term);
}

/// Joukowsky surge head ΔH = a·ΔV/g (metres of water).
double joukowskySurgeHead({required double celerity, required double velocityChange}) =>
    celerity * velocityChange / gravity;

/// Critical closure time 2L/a (s): closures faster than this give the full surge.
double criticalClosureTime({required double length, required double celerity}) => 2 * length / celerity;
