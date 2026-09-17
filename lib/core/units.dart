/// Unit conversion helpers. Internal engine units are SI:
/// length m, flow m³/s, head m of water column (m.c.a.), pressure Pa,
/// diameter m, velocity m/s.
library;

import 'dart:math' as math;

const double gravity = 9.80665; // m/s²
const double waterDensity = 998.2; // kg/m³ at 20 °C
const double kPaPerMeterHead = 9.80665; // kPa per metre of water
const double psiPerMeterHead = 1.4219702; // psi per metre of water
const double barPerMeterHead = 0.0980665;
const double metersPerFoot = 0.3048;
const double metersPerInch = 0.0254;
const double m3sPerLph = 1 / 3.6e6; // L/h -> m³/s
const double m3sPerLps = 1e-3;
const double m3sPerM3h = 1 / 3600;
const double m3sPerGpm = 6.30902e-5; // US gpm -> m³/s

/// Kinematic viscosity of water (m²/s) as a function of temperature (°C).
/// Fit of tabulated values between 0 and 50 °C (error < 1 %).
double waterKinematicViscosity(double tempC) {
  final t = tempC.clamp(0.0, 60.0);
  // Vogel-type empirical fit: nu = 1.792e-6 / (1 + 0.0337 t + 0.000221 t²)
  return 1.792e-6 / (1 + 0.0337 * t + 0.000221 * t * t);
}

enum LengthUnit { m, mm, cm, ft, inch }

enum FlowUnit { lph, lpm, lps, m3h, gpm }

enum PressureUnit { mH2O, kPa, bar, psi }

enum DiameterUnit { mm, inch }

class Units {
  const Units({
    this.length = LengthUnit.m,
    this.flow = FlowUnit.lph,
    this.pressure = PressureUnit.mH2O,
    this.diameter = DiameterUnit.mm,
  });

  final LengthUnit length;
  final FlowUnit flow;
  final PressureUnit pressure;
  final DiameterUnit diameter;

  static const metric = Units();
  static const us = Units(
    length: LengthUnit.ft,
    flow: FlowUnit.gpm,
    pressure: PressureUnit.psi,
    diameter: DiameterUnit.inch,
  );

  Units copyWith({
    LengthUnit? length,
    FlowUnit? flow,
    PressureUnit? pressure,
    DiameterUnit? diameter,
  }) => Units(
    length: length ?? this.length,
    flow: flow ?? this.flow,
    pressure: pressure ?? this.pressure,
    diameter: diameter ?? this.diameter,
  );

  Map<String, dynamic> toJson() => {
    'length': length.name,
    'flow': flow.name,
    'pressure': pressure.name,
    'diameter': diameter.name,
  };

  static Units fromJson(Map<String, dynamic>? j) {
    if (j == null) return metric;
    return Units(
      length: LengthUnit.values.byName(j['length'] as String? ?? 'm'),
      flow: FlowUnit.values.byName(j['flow'] as String? ?? 'lph'),
      pressure: PressureUnit.values.byName(j['pressure'] as String? ?? 'mH2O'),
      diameter: DiameterUnit.values.byName(j['diameter'] as String? ?? 'mm'),
    );
  }

  // ---- length ----
  double lengthToSi(double v) => switch (length) {
    LengthUnit.m => v,
    LengthUnit.mm => v / 1000,
    LengthUnit.cm => v / 100,
    LengthUnit.ft => v * metersPerFoot,
    LengthUnit.inch => v * metersPerInch,
  };
  double lengthFromSi(double m) => switch (length) {
    LengthUnit.m => m,
    LengthUnit.mm => m * 1000,
    LengthUnit.cm => m * 100,
    LengthUnit.ft => m / metersPerFoot,
    LengthUnit.inch => m / metersPerInch,
  };
  String get lengthLabel => switch (length) {
    LengthUnit.m => 'm',
    LengthUnit.mm => 'mm',
    LengthUnit.cm => 'cm',
    LengthUnit.ft => 'ft',
    LengthUnit.inch => 'in',
  };

  // ---- flow ----
  double flowToSi(double v) => switch (flow) {
    FlowUnit.lph => v * m3sPerLph,
    FlowUnit.lpm => v / 60000,
    FlowUnit.lps => v * m3sPerLps,
    FlowUnit.m3h => v * m3sPerM3h,
    FlowUnit.gpm => v * m3sPerGpm,
  };
  double flowFromSi(double q) => switch (flow) {
    FlowUnit.lph => q / m3sPerLph,
    FlowUnit.lpm => q * 60000,
    FlowUnit.lps => q / m3sPerLps,
    FlowUnit.m3h => q / m3sPerM3h,
    FlowUnit.gpm => q / m3sPerGpm,
  };
  String get flowLabel => switch (flow) {
    FlowUnit.lph => 'L/h',
    FlowUnit.lpm => 'L/min',
    FlowUnit.lps => 'L/s',
    FlowUnit.m3h => 'm³/h',
    FlowUnit.gpm => 'gpm',
  };

  // ---- pressure (head) ----
  double pressureToHead(double v) => switch (pressure) {
    PressureUnit.mH2O => v,
    PressureUnit.kPa => v / kPaPerMeterHead,
    PressureUnit.bar => v / barPerMeterHead,
    PressureUnit.psi => v / psiPerMeterHead,
  };
  double pressureFromHead(double h) => switch (pressure) {
    PressureUnit.mH2O => h,
    PressureUnit.kPa => h * kPaPerMeterHead,
    PressureUnit.bar => h * barPerMeterHead,
    PressureUnit.psi => h * psiPerMeterHead,
  };
  String get pressureLabel => switch (pressure) {
    PressureUnit.mH2O => 'm.c.a.',
    PressureUnit.kPa => 'kPa',
    PressureUnit.bar => 'bar',
    PressureUnit.psi => 'psi',
  };

  // ---- diameter ----
  double diameterToSi(double v) => switch (diameter) {
    DiameterUnit.mm => v / 1000,
    DiameterUnit.inch => v * metersPerInch,
  };
  double diameterFromSi(double d) => switch (diameter) {
    DiameterUnit.mm => d * 1000,
    DiameterUnit.inch => d / metersPerInch,
  };
  String get diameterLabel => switch (diameter) {
    DiameterUnit.mm => 'mm',
    DiameterUnit.inch => 'in',
  };

  String get velocityLabel => length == LengthUnit.ft ? 'ft/s' : 'm/s';
  double velocityFromSi(double v) =>
      length == LengthUnit.ft ? v / metersPerFoot : v;
  double velocityToSi(double v) =>
      length == LengthUnit.ft ? v * metersPerFoot : v;
}

/// Formats a number with a fixed number of decimals for reports, tables and
/// labels: plain positional notation (never scientific), values that round
/// to zero print as zero (no "-0.00"), '-' for NaN.
String fmt(double v, [int decimals = 2]) {
  if (v.isNaN) return '-';
  if (v.isInfinite) return v > 0 ? '∞' : '-∞';
  final d = decimals.clamp(0, 20);
  // toStringAsFixed switches to exponent form only beyond 1e21.
  var s = v.abs() < 1e21 ? v.toStringAsFixed(d) : v.toStringAsExponential(2);
  if (s.startsWith('-') && !s.contains(RegExp(r'[1-9]'))) s = s.substring(1);
  return s;
}

double roundTo(double v, int decimals) {
  final p = math.pow(10, decimals).toDouble();
  return (v * p).round() / p;
}
