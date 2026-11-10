/// Reading a curve off a picture of a chart (a catalogue page, a
/// screenshot, a photo of a data sheet): the calibration of the two axes by
/// two clicked points each, the mapping from the pixels of the picture to
/// the values of the chart, and the curves the user clicks (1.7.0, DGZ).
///
/// The mapping is the general affine one, so a scan that is rotated or
/// sheared still reads right: the two points clicked on the horizontal axis
/// give its values and its direction (the vertical value does not change
/// along it), the two points of the vertical axis give its values and its
/// direction (the horizontal value does not change along it). That is six
/// equations for the six coefficients of
///
///     u = a·px + b·py + c        v = d·px + e·py + f
///
/// where u and v are the values of the axes, or their decimal logarithms on
/// a logarithmic axis (the way a chart with log scales is drawn). It is
/// the calibration of the usual chart digitisers (two points per axis); a
/// picture taken at an angle (perspective) is not affine and reads only
/// approximately.
library;

import 'dart:math' as math;

import '../model/geometry.dart';
import '../units.dart';

/// How an axis is graduated.
enum AxisScale { linear, log }

/// What an axis of a chart measures.
enum ChartQuantity { flow, head, efficiency, power, distance, rate }

/// kW per mechanical horsepower (550 ft·lbf/s).
const double kwPerHp = 0.745699872;

/// kW per metric horsepower ("cavalo-vapor", 75 kgf·m/s).
const double kwPerCv = 0.73549875;

/// A unit of an axis: a [quantity] and the [code] of one of its units — the
/// name of a [FlowUnit], [PressureUnit] or [LengthUnit] of the app, or
/// `pct`/`fraction` (efficiency), `kw`/`hp`/`cv` (power), `mmh`/`inh`
/// (application rate). The values of the engine are SI: m³/s, metres of
/// water, a fraction, kW, metres and mm/h.
class AxisUnit {
  const AxisUnit(this.quantity, this.code);
  final ChartQuantity quantity;
  final String code;

  /// `quantity.code`, e.g. `flow.m3h`.
  String get id => '${quantity.name}.$code';

  /// The units an axis of [q] can be read in.
  static List<AxisUnit> all(ChartQuantity q) => switch (q) {
    ChartQuantity.flow => [for (final f in FlowUnit.values) AxisUnit(q, f.name)],
    ChartQuantity.head => [for (final p in PressureUnit.values) AxisUnit(q, p.name)],
    ChartQuantity.efficiency => const [AxisUnit(ChartQuantity.efficiency, 'pct'), AxisUnit(ChartQuantity.efficiency, 'fraction')],
    ChartQuantity.power => const [AxisUnit(ChartQuantity.power, 'kw'), AxisUnit(ChartQuantity.power, 'hp'), AxisUnit(ChartQuantity.power, 'cv')],
    ChartQuantity.distance => [for (final l in LengthUnit.values) AxisUnit(q, l.name)],
    ChartQuantity.rate => const [AxisUnit(ChartQuantity.rate, 'mmh'), AxisUnit(ChartQuantity.rate, 'inh')],
  };

  /// The unit of [q] with [code], or null.
  static AxisUnit? of(ChartQuantity q, String? code) {
    for (final u in all(q)) {
      if (u.code == code) return u;
    }
    return null;
  }

  Units get _units => switch (quantity) {
    ChartQuantity.flow => Units(flow: FlowUnit.values.byName(code)),
    ChartQuantity.head => Units(pressure: PressureUnit.values.byName(code)),
    ChartQuantity.distance => Units(length: LengthUnit.values.byName(code)),
    _ => Units.metric,
  };

  /// The symbol shown with the values (the app's labels).
  String get label => switch (quantity) {
    ChartQuantity.flow => _units.flowLabel,
    ChartQuantity.head => _units.pressureLabel,
    ChartQuantity.distance => _units.lengthLabel,
    ChartQuantity.efficiency => code == 'pct' ? '%' : '0–1',
    ChartQuantity.power => switch (code) {
      'hp' => 'hp',
      'cv' => 'cv',
      _ => 'kW',
    },
    ChartQuantity.rate => code == 'inh' ? 'in/h' : 'mm/h',
  };

  /// [v] in this unit to the engine's unit.
  double toSi(double v) => switch (quantity) {
    ChartQuantity.flow => _units.flowToSi(v),
    ChartQuantity.head => _units.pressureToHead(v),
    ChartQuantity.distance => _units.lengthToSi(v),
    ChartQuantity.efficiency => code == 'pct' ? v / 100 : v,
    ChartQuantity.power => switch (code) {
      'hp' => v * kwPerHp,
      'cv' => v * kwPerCv,
      _ => v,
    },
    ChartQuantity.rate => code == 'inh' ? v * 25.4 : v,
  };

  /// [si] in the engine's unit to this unit.
  double fromSi(double si) => switch (quantity) {
    ChartQuantity.flow => _units.flowFromSi(si),
    ChartQuantity.head => _units.pressureFromHead(si),
    ChartQuantity.distance => _units.lengthFromSi(si),
    ChartQuantity.efficiency => code == 'pct' ? si * 100 : si,
    ChartQuantity.power => switch (code) {
      'hp' => si / kwPerHp,
      'cv' => si / kwPerCv,
      _ => si,
    },
    ChartQuantity.rate => code == 'inh' ? si / 25.4 : si,
  };

  @override
  bool operator ==(Object other) => other is AxisUnit && other.quantity == quantity && other.code == code;

  @override
  int get hashCode => Object.hash(quantity, code);

  @override
  String toString() => id;
}

/// The two points clicked on an axis (picture pixels) and the values typed
/// for them (in the axis unit), and how the axis is graduated.
class AxisCalibration {
  AxisCalibration({this.p1, this.p2, this.v1, this.v2, this.scale = AxisScale.linear});
  Pt? p1;
  Pt? p2;
  double? v1;
  double? v2;
  AxisScale scale;

  bool get hasPoints => p1 != null && p2 != null;
  bool get complete => hasPoints && v1 != null && v2 != null && v1!.isFinite && v2!.isFinite;

  AxisCalibration copy() => AxisCalibration(p1: p1, p2: p2, v1: v1, v2: v2, scale: scale);
}

/// Why two axis calibrations give no mapping.
enum CalibrationError {
  /// A point or a value of an axis is missing.
  incomplete,

  /// The two points of an axis are (nearly) at the same place.
  samePoints,

  /// The two values of an axis are equal.
  sameValues,

  /// A logarithmic axis with a value at or below zero.
  logValues,

  /// The two axes run (nearly) along the same line.
  parallel,
}

/// Fewest pixels between the two points of an axis: closer, they are one
/// tick clicked twice.
const double minCalibrationSpanPx = 2;

/// Smallest angle between the two axes: below it the clicks of both axes
/// lie along one line and the error of a click is multiplied by more than
/// 1/sin 10° = 5.8 (a guard against an ill-conditioned calibration, not a
/// property of charts).
const double minAxisAngleDeg = 10;

/// From the pixels of a picture to the values of a chart and back: the
/// affine mapping of the axis coordinates (the values, or their decimal
/// logarithms on a logarithmic axis).
class ChartMapping {
  const ChartMapping._(this.a, this.b, this.c, this.d, this.e, this.f, this.xScale, this.yScale);

  /// u = a·px + b·py + c (horizontal axis coordinate).
  final double a, b, c;

  /// v = d·px + e·py + f (vertical axis coordinate).
  final double d, e, f;
  final AxisScale xScale;
  final AxisScale yScale;

  static double axisCoordinate(double value, AxisScale s) => s == AxisScale.log ? math.log(value) / math.ln10 : value;
  static double valueOfCoordinate(double u, AxisScale s) => s == AxisScale.log ? math.pow(10, u).toDouble() : u;

  /// The mapping of the calibrations [x] (horizontal axis) and [y]
  /// (vertical axis), or the reason there is none.
  static (ChartMapping?, CalibrationError?) solve(AxisCalibration x, AxisCalibration y) {
    if (!x.complete || !y.complete) return (null, CalibrationError.incomplete);
    for (final cal in [x, y]) {
      if (cal.p1!.distanceTo(cal.p2!) < minCalibrationSpanPx) return (null, CalibrationError.samePoints);
    }
    for (final cal in [x, y]) {
      if (cal.scale == AxisScale.log && (cal.v1! <= 0 || cal.v2! <= 0)) return (null, CalibrationError.logValues);
    }
    final u1 = axisCoordinate(x.v1!, x.scale), u2 = axisCoordinate(x.v2!, x.scale);
    final w1 = axisCoordinate(y.v1!, y.scale), w2 = axisCoordinate(y.v2!, y.scale);
    if ((u2 - u1).abs() <= 1e-12 * math.max(1, u1.abs()) || (w2 - w1).abs() <= 1e-12 * math.max(1, w1.abs())) return (null, CalibrationError.sameValues);
    final ex = x.p2! - x.p1!; // the horizontal axis: v constant along it
    final dy = y.p2! - y.p1!; // the vertical axis: u constant along it
    final det = ex.cross(dy);
    if (det.abs() < math.sin(minAxisAngleDeg * math.pi / 180) * ex.length * dy.length) return (null, CalibrationError.parallel);
    // u: a·ex + b·ey = u2 − u1 and a·dx + b·dy = 0
    final a = (u2 - u1) * dy.y / det;
    final b = -(u2 - u1) * dy.x / det;
    final c = u1 - a * x.p1!.x - b * x.p1!.y;
    // v: d·dx + e·dy = w2 − w1 and d·ex + e·ey = 0
    final d = -(w2 - w1) * ex.y / det;
    final e = (w2 - w1) * ex.x / det;
    final f = w1 - d * y.p1!.x - e * y.p1!.y;
    return (ChartMapping._(a, b, c, d, e, f, x.scale, y.scale), null);
  }

  /// Axis coordinates (u, v) of pixel [p].
  (double, double) coordinatesAt(Pt p) => (a * p.x + b * p.y + c, d * p.x + e * p.y + f);

  /// The values (horizontal, vertical) of the chart at pixel [p].
  (double, double) valueAt(Pt p) {
    final (u, v) = coordinatesAt(p);
    return (valueOfCoordinate(u, xScale), valueOfCoordinate(v, yScale));
  }

  /// The pixel of the axis coordinates (u, v).
  Pt pixelOfCoordinates(double u, double v) {
    final det = a * e - b * d;
    final du = u - c, dv = v - f;
    return Pt((e * du - b * dv) / det, (-d * du + a * dv) / det);
  }

  /// The pixel where the chart has the values ([x], [y]); null for a value
  /// a logarithmic axis cannot show.
  Pt? pixelOf(double x, double y) {
    if ((xScale == AxisScale.log && !(x > 0)) || (yScale == AxisScale.log && !(y > 0))) return null;
    return pixelOfCoordinates(axisCoordinate(x, xScale), axisCoordinate(y, yScale));
  }

  double get _det => a * e - b * d;

  /// Unit direction in the picture along which the horizontal value grows
  /// and the vertical one stays.
  Pt get xDirection => (Pt(e, -d) * _det.sign).normalized;

  /// Unit direction in the picture along which the vertical value grows
  /// and the horizontal one stays.
  Pt get yDirection => (Pt(-b, a) * _det.sign).normalized;

  /// Change of the horizontal axis coordinate per pixel along [xDirection].
  double get xRatePerPixel {
    final s = xDirection;
    return a * s.x + b * s.y;
  }
}

/// What the picture holds, and so where its curves go.
enum CurveKind {
  /// A pump: head, and as further curves efficiency, NPSH required and power,
  /// all against the flow.
  pump,

  /// An outlet or sprinkler: flow against pressure (q = k·Hˣ).
  emitter,

  /// A sprinkler's radial application profile: rate against the distance
  /// from the head.
  profile,
}

/// One curve of a picture.
enum CurveRole { head, efficiency, npsh, power, flowPressure, profile }

/// The curves a picture of [kind] can hold, the first one the main one.
List<CurveRole> rolesOf(CurveKind kind) => switch (kind) {
  CurveKind.pump => const [CurveRole.head, CurveRole.efficiency, CurveRole.npsh, CurveRole.power],
  CurveKind.emitter => const [CurveRole.flowPressure],
  CurveKind.profile => const [CurveRole.profile],
};

/// The quantities (horizontal, vertical) of a curve of [role]; an outlet's
/// chart with the flow along the bottom is [swapped].
(ChartQuantity, ChartQuantity) quantitiesOf(CurveRole role, {bool swapped = false}) => switch (role) {
  CurveRole.head => (ChartQuantity.flow, ChartQuantity.head),
  CurveRole.efficiency => (ChartQuantity.flow, ChartQuantity.efficiency),
  CurveRole.npsh => (ChartQuantity.flow, ChartQuantity.head),
  CurveRole.power => (ChartQuantity.flow, ChartQuantity.power),
  CurveRole.flowPressure => swapped ? (ChartQuantity.flow, ChartQuantity.head) : (ChartQuantity.head, ChartQuantity.flow),
  CurveRole.profile => (ChartQuantity.distance, ChartQuantity.rate),
};

/// A curve of the picture: its vertical axis (each curve may have its own:
/// a pump's efficiency on the right, its NPSH in a chart below) and the
/// points clicked or traced, in picture pixels.
class CurveSeries {
  CurveSeries(this.role, {AxisCalibration? y, required this.yUnit, List<Pt>? pixels}) : y = y ?? AxisCalibration(), pixels = pixels ?? [];
  final CurveRole role;
  final AxisCalibration y;
  AxisUnit yUnit;
  final List<Pt> pixels;

  CurveSeries copy() => CurveSeries(role, y: y.copy(), yUnit: yUnit, pixels: [...pixels]);
}

/// A digitising session: the picture's horizontal axis (shared by its
/// curves), the curves and their points.
class DigitiserSession {
  DigitiserSession({required this.kind, required this.xUnit, required this.series, AxisCalibration? x, this.swapped = false, CurveRole? current})
    : x = x ?? AxisCalibration(),
      current = current ?? rolesOf(kind).first;

  /// A new session for [kind] with the default units of a project in [units].
  factory DigitiserSession.start(CurveKind kind, {Units units = Units.metric, bool swapped = false}) {
    final roles = rolesOf(kind);
    final (xq, _) = quantitiesOf(roles.first, swapped: swapped);
    return DigitiserSession(
      kind: kind,
      swapped: swapped,
      xUnit: defaultAxisUnit(xq, units, kind: kind),
      series: {
        for (final r in roles)
          r: CurveSeries(
            r,
            yUnit: defaultAxisUnit(quantitiesOf(r, swapped: swapped).$2, units, kind: kind),
          ),
      },
    );
  }

  final CurveKind kind;
  final AxisCalibration x;
  AxisUnit xUnit;

  /// An outlet's chart with the flow along the horizontal axis.
  final bool swapped;
  final Map<CurveRole, CurveSeries> series;
  CurveRole current;

  CurveSeries get active => series[current]!;

  DigitiserSession copy() => DigitiserSession(kind: kind, xUnit: xUnit, x: x.copy(), swapped: swapped, current: current, series: {for (final e in series.entries) e.key: e.value.copy()});

  /// This session with the quantities of the axes of an outlet's chart
  /// exchanged (the flow along the bottom, or up the side): the clicks and
  /// the values typed stay, the units go with their quantity.
  DigitiserSession withSwapped(bool to) {
    if (to == swapped || kind != CurveKind.emitter) return copy();
    final s = series[CurveRole.flowPressure]!;
    return DigitiserSession(
      kind: kind,
      xUnit: s.yUnit,
      x: x.copy(),
      swapped: to,
      current: current,
      series: {
        CurveRole.flowPressure: CurveSeries(CurveRole.flowPressure, y: s.y.copy(), yUnit: xUnit, pixels: [...s.pixels]),
      },
    );
  }

  /// The mapping of curve [role], or why there is none.
  (ChartMapping?, CalibrationError?) mapping([CurveRole? role]) => ChartMapping.solve(x, series[role ?? current]!.y);

  /// The points of curve [role] as chart values (horizontal, vertical) in
  /// the axis units, sorted along the horizontal axis; empty without a
  /// mapping.
  List<(double, double)> values([CurveRole? role]) {
    final (m, _) = mapping(role);
    if (m == null) return const [];
    return [for (final p in series[role ?? current]!.pixels) m.valueAt(p)]..sort((a, b) => a.$1.compareTo(b.$1));
  }

  /// The points of curve [role] in the engine's units, as the catalogue
  /// keeps them: (Q m³/s, H m | efficiency 0–1 | NPSH m | power kW) for a
  /// pump, (H m, q m³/s) for an outlet whatever axis holds the flow,
  /// (distance m, rate mm/h) for a profile. Sorted by the first value.
  List<(double, double)> si([CurveRole? role]) {
    final r = role ?? current;
    final s = series[r]!;
    final out = [for (final (x, y) in values(r)) (xUnit.toSi(x), s.yUnit.toSi(y))];
    if (r == CurveRole.flowPressure && swapped) {
      return [for (final (q, h) in out) (h, q)]..sort((a, b) => a.$1.compareTo(b.$1));
    }
    return out;
  }
}

/// The unit an axis of [q] starts in for a project in [units]: the
/// project's pressure and length units; pump flows in m³/h (gpm in US
/// units), outlet flows in L/h (gpm); rates in mm/h (in/h with feet);
/// power in kW (hp with feet); efficiency in %.
AxisUnit defaultAxisUnit(ChartQuantity q, Units units, {CurveKind kind = CurveKind.pump}) {
  final us = units.length == LengthUnit.ft;
  return switch (q) {
    ChartQuantity.flow => AxisUnit(q, units.flow == FlowUnit.gpm ? 'gpm' : (kind == CurveKind.pump ? 'm3h' : 'lph')),
    ChartQuantity.head => AxisUnit(q, units.pressure.name),
    ChartQuantity.distance => AxisUnit(q, us ? 'ft' : 'm'),
    ChartQuantity.rate => AxisUnit(q, us ? 'inh' : 'mmh'),
    ChartQuantity.power => AxisUnit(q, us ? 'hp' : 'kw'),
    ChartQuantity.efficiency => const AxisUnit(ChartQuantity.efficiency, 'pct'),
  };
}

/// One curve for [curvePointsCsv]: its [name], the labels of its columns
/// and its points (in the units of the labels).
typedef CurveColumns = ({String name, String x, String y, List<(double, double)> points});

/// The points of [curves] as CSV, the app's way (UTF-8 mark, semicolons,
/// decimal points): one row per point with the curve's name, so several
/// curves of one picture share a file and a spreadsheet filters them.
String curvePointsCsv(List<CurveColumns> curves) {
  String q(String s) => '"${s.replaceAll('"', '""')}"';
  final b = StringBuffer('\u{FEFF}');
  b.writeln('curve;x;y;x unit;y unit');
  for (final c in curves) {
    for (final (x, y) in c.points) {
      b.writeln([q(c.name), _num(x), _num(y), q(c.x), q(c.y)].join(';'));
    }
  }
  return b.toString();
}

/// The points of [curves] as tab-separated text for the clipboard (pasted
/// into a spreadsheet, each value lands in a cell): a heading row per curve
/// and the numbers with [decimalSeparator].
String curvePointsTsv(List<CurveColumns> curves, {String decimalSeparator = '.'}) {
  String n(double v) => decimalSeparator == ',' ? _num(v).replaceAll('.', ',') : _num(v);
  final b = StringBuffer();
  for (final c in curves) {
    if (b.isNotEmpty) b.writeln();
    b.writeln('${c.name}\t\t');
    b.writeln('${c.x}\t${c.y}');
    for (final (x, y) in c.points) {
      b.writeln('${n(x)}\t${n(y)}');
    }
  }
  return b.toString();
}

/// Six significant digits, plain notation.
String _num(double v) {
  if (!v.isFinite) return '';
  final a = v.abs();
  final digits = a == 0 ? 0 : (5 - (math.log(a) / math.ln10).floor()).clamp(0, 12);
  var s = v.toStringAsFixed(digits);
  if (s.contains('.')) s = s.replaceFirst(RegExp(r'\.?0+$'), '');
  return s == '-0' ? '0' : s;
}
