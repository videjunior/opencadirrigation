/// Unit conversion helpers. Internal engine units are SI:
/// length m, flow m³/s, head m of water column (m.c.a.), pressure Pa,
/// diameter m, velocity m/s.
library;

import 'dart:math' as math;

const double gravity = 9.80665; // m/s²
const double waterDensity = 998.2; // kg/m³ at 20 °C
const double kPaPerMeterHead = 9.80665; // kPa per metre of water
const double kPaPerPsi = 6.894757293168; // 1 lbf/in²
const double psiPerMeterHead = kPaPerMeterHead / kPaPerPsi; // psi per metre of water (1.42233)
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

/// Pressure units; [ftH2O] is feet of water, the head of the pump curves of
/// American manufacturers (TDH); [kgfcm2] the kilogram-force per square
/// centimetre of older gauges and data sheets (98.0665 kPa, 10 m of water;
/// 1.6.0 CAD, PRD-26).
enum PressureUnit { mH2O, kPa, bar, psi, ftH2O, kgfcm2 }

/// Metres of water per kgf/cm² (98.0665 kPa ÷ 9.80665 kPa/m).
const double metersHeadPerKgfCm2 = 10.0;

enum DiameterUnit { mm, inch }

class Units {
  const Units({this.length = LengthUnit.m, this.flow = FlowUnit.lph, this.pressure = PressureUnit.mH2O, this.diameter = DiameterUnit.mm});

  final LengthUnit length;
  final FlowUnit flow;
  final PressureUnit pressure;
  final DiameterUnit diameter;

  static const metric = Units();
  static const us = Units(length: LengthUnit.ft, flow: FlowUnit.gpm, pressure: PressureUnit.psi, diameter: DiameterUnit.inch);

  Units copyWith({LengthUnit? length, FlowUnit? flow, PressureUnit? pressure, DiameterUnit? diameter}) =>
      Units(length: length ?? this.length, flow: flow ?? this.flow, pressure: pressure ?? this.pressure, diameter: diameter ?? this.diameter);

  Map<String, dynamic> toJson() => {'length': length.name, 'flow': flow.name, 'pressure': pressure.name, 'diameter': diameter.name};

  /// Units of a file; a unit this version does not know falls back to the
  /// metric one (the project still opens).
  static Units fromJson(Map<String, dynamic>? j) {
    if (j == null) return metric;
    return Units(
      length: LengthUnit.values.asNameMap()[j['length']] ?? LengthUnit.m,
      flow: FlowUnit.values.asNameMap()[j['flow']] ?? FlowUnit.lph,
      pressure: PressureUnit.values.asNameMap()[j['pressure']] ?? PressureUnit.mH2O,
      diameter: DiameterUnit.values.asNameMap()[j['diameter']] ?? DiameterUnit.mm,
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
    PressureUnit.ftH2O => v * metersPerFoot,
    PressureUnit.kgfcm2 => v * metersHeadPerKgfCm2,
  };
  double pressureFromHead(double h) => switch (pressure) {
    PressureUnit.mH2O => h,
    PressureUnit.kPa => h * kPaPerMeterHead,
    PressureUnit.bar => h * barPerMeterHead,
    PressureUnit.psi => h * psiPerMeterHead,
    PressureUnit.ftH2O => h / metersPerFoot,
    PressureUnit.kgfcm2 => h / metersHeadPerKgfCm2,
  };
  String get pressureLabel => switch (pressure) {
    PressureUnit.mH2O => 'm.c.a.',
    PressureUnit.kPa => 'kPa',
    PressureUnit.bar => 'bar',
    PressureUnit.psi => 'psi',
    PressureUnit.ftH2O => 'ft H₂O',
    PressureUnit.kgfcm2 => 'kgf/cm²',
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

  // ---- areas, depths and volumes of water (US customary with feet) ----
  bool get _us => length == LengthUnit.ft;
  double areaFromSi(double m2) => _us ? m2 / 4046.8564224 : m2 / 10000;
  String get areaLabel => _us ? 'ac' : 'ha';
  double depthFromMm(double mm) => _us ? mm / 25.4 : mm;
  double depthToMm(double v) => _us ? v * 25.4 : v;
  String get depthLabel => _us ? 'in' : 'mm';
  String get depthPerDayLabel => _us ? 'in/d' : 'mm/d';
  String get depthRateLabel => _us ? 'in/h' : 'mm/h';
  double volumeFromM3(double m3) => _us ? m3 * 264.1720524 : m3;
  String get volumeLabel => _us ? 'gal' : 'm³';
  double velocityFromSi(double v) => length == LengthUnit.ft ? v / metersPerFoot : v;
  double velocityToSi(double v) => length == LengthUnit.ft ? v * metersPerFoot : v;
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

/// Interface languages that write the decimal separator as a comma
/// ("12,5"); the others (English, Chinese, Japanese, the languages of India,
/// Arabic and Urdu in Latin digits, Hausa, Swahili) write a point.
const decimalCommaLanguages = {'pt', 'es', 'de', 'fr', 'id', 'tr', 'ru', 'vi'};

/// The decimal separator of the interface language [lang]: ',' or '.'.
String decimalSeparatorOf(String lang) => decimalCommaLanguages.contains(lang) ? ',' : '.';

/// [fmt] in the notation of the interface language [lang]: the same digits
/// with a decimal comma where the language writes one ("12,50" in
/// Portuguese, "12.50" in English). Only for the screen: files, exports
/// and the AI keep [fmt]'s decimal point.
String fmtLocale(double v, int decimals, String lang) {
  final s = fmt(v, decimals);
  return decimalSeparatorOf(lang) == ',' ? s.replaceAll('.', ',') : s;
}

/// The numbers inside [text] (built with [fmt]) in the notation of [lang]:
/// "12.5 m @ 3.25 bar" becomes "12,5 m @ 3,25 bar" in Portuguese. A number
/// with more than one point ("1.6.0"), one with a point and a comma
/// ("1,234.5", a price already formatted) or one inside a word ("e12.5")
/// is left as it is.
String localizeNumbers(String text, String lang) {
  if (decimalSeparatorOf(lang) == '.' || !text.contains('.')) return text;
  return text.replaceAllMapped(_decimalPoint, (m) => '${m[1]},${m[2]}');
}

final _decimalPoint = RegExp(r'(?<![\w.,])(\d+)\.(\d+)(?![\w.]|,\d)');

/// Whether [text] reads two ways for a language whose decimal separator is
/// [decimalSeparator]: a single separator of the other kind followed by
/// exactly three digits ("2.000" or "1,500"), which is a thousands
/// separator in one notation and a decimal one in the other. [parseNumber]
/// then follows [decimalSeparator]; a field shows the other reading too.
bool numberIsAmbiguous(String text, String decimalSeparator) {
  final other = decimalSeparator == ',' ? '.' : ',';
  return RegExp('^[-+]?[1-9]\\d{0,2}\\$other\\d{3}\$').hasMatch(text.trim());
}

/// Parses a number written in any usual notation: a decimal point or comma
/// and thousands separators ("1.234,56", "1,234.56", "1 234,5"). With
/// [lenient], the first number inside other text is taken ("R$ 1.234,56",
/// "35 m"); otherwise the whole text must be the number. Null when there
/// is none.
///
/// A single separator is the decimal one ("12,5" = "12.5" = 12.5), except
/// with [decimalSeparator], the one of the language the user types in: a
/// single separator of the other kind followed by exactly three digits is
/// then a thousands separator ("2.000" is 2000 with ',', "1,500" is 1500
/// with '.'; see [numberIsAmbiguous]), any other is still decimal ("2.5"
/// is 2.5 in Portuguese).
double? parseNumber(String text, {bool lenient = false, String? decimalSeparator}) {
  if (decimalSeparator != null && !lenient && numberIsAmbiguous(text, decimalSeparator)) {
    return double.tryParse(text.trim().replaceAll(RegExp('[.,]'), ''));
  }
  final plain = double.tryParse(text.trim());
  // "NaN" and "Infinity" parse in Dart but are no value a field can hold
  // (a project with them could not be saved)
  if (plain != null) return plain.isFinite ? plain : null;
  // spaces between digit groups (also no-break and thin spaces)
  final s = text.replaceAll(RegExp(r'(?<=\d)[ \u00A0\u202F](?=\d{3}(?!\d))'), '').trim();
  final m = lenient ? _numberPattern.firstMatch(s) : _numberPattern.matchAsPrefix(s);
  if (m == null || (!lenient && m.end != s.length)) return null;
  var t = m.group(0)!;
  final dots = '.'.allMatches(t).length, commas = ','.allMatches(t).length;
  if (dots > 0 && commas > 0) {
    // the last separator is the decimal one
    final decimalComma = t.lastIndexOf(',') > t.lastIndexOf('.');
    t = decimalComma ? t.replaceAll('.', '').replaceAll(',', '.') : t.replaceAll(',', '');
  } else if (decimalSeparator != null && numberIsAmbiguous(t, decimalSeparator)) {
    t = t.replaceAll(RegExp('[.,]'), '');
  } else if (commas > 0) {
    t = commas == 1 ? t.replaceAll(',', '.') : t.replaceAll(',', '');
  } else if (dots > 1) {
    t = t.replaceAll('.', '');
  }
  return double.tryParse(t);
}

/// The decimal separator a column of numbers read from a file uses, from
/// the values that tell ("1.234,5", "12,25", "0.5"): ',' or '.', or null
/// when none tells (only integers, or only "d.ddd" / "d,ddd" values, which
/// read both ways). For the import of tables whose notation is not known.
String? guessDecimalSeparator(Iterable<String> values) {
  var comma = 0, point = 0;
  for (final raw in values) {
    final v = raw.trim();
    final lastComma = v.lastIndexOf(','), lastPoint = v.lastIndexOf('.');
    if (lastComma >= 0 && lastPoint >= 0) {
      lastComma > lastPoint ? comma++ : point++;
    } else if (lastComma >= 0 || lastPoint >= 0) {
      final sep = lastComma >= 0 ? ',' : '.';
      if (sep.allMatches(v).length > 1) {
        // "1.234.567": thousands
        sep == ',' ? point++ : comma++;
      } else if (!numberIsAmbiguous(v, sep == ',' ? '.' : ',')) {
        sep == ',' ? comma++ : point++;
      }
    }
  }
  if (comma == point) return null;
  return comma > point ? ',' : '.';
}

/// Rows of numbers pasted or typed as a table (one row per line): fields
/// split by tabs, else by semicolons, else by spaces, else by commas (when
/// the numbers use decimal points), each read by [parseNumber] so decimal
/// commas and thousands separators work; unreadable fields and empty lines
/// are skipped.
List<List<double>> parseNumberRows(String text) {
  final rows = <List<double>>[];
  for (final raw in text.split(RegExp(r'\r?\n'))) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    final sep = line.contains('\t') ? RegExp('\t') : (line.contains(';') ? RegExp(';') : (line.contains(RegExp(r'\s')) ? RegExp(r'\s+') : RegExp(',')));
    final fields = line.split(sep);
    final row = [for (final f in fields) ?parseNumber(f.trim())];
    if (row.isNotEmpty) rows.add(row);
  }
  return rows;
}

final _numberPattern = RegExp(r'[-+]?(?:\d[\d.,]*|[.,]\d+)(?:[eE][-+]?\d+)?');

double roundTo(double v, int decimals) {
  final p = math.pow(10, decimals).toDouble();
  return (v * p).round() / p;
}
