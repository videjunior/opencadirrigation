/// Climate of the site kept in the project: monthly normals of reference
/// evapotranspiration, rain (mean and dependable), solar radiation and,
/// for the climatic adjustment of the crop coefficients, the minimum
/// relative humidity and the wind speed at 2 m, downloaded from a public
/// service or typed in, with their provenance.
library;

import '../design/irrigation_requirement.dart';

class SiteClimate {
  SiteClimate({
    required this.etoMmDay,
    required this.rainMm,
    this.dependableRainMm,
    this.solarKWhM2Day,
    this.rhMinPct,
    this.windSpeed2mMs,
    this.source = 'manual',
    this.firstYear = 0,
    this.lastYear = 0,
    this.latitudeDeg = 0,
    this.longitudeDeg = 0,
    this.retrieved = '',
    this.attribution = '',
  });

  /// Twelve monthly values, January first.
  final List<double> etoMmDay;
  final List<double> rainMm;
  final List<double>? dependableRainMm;

  /// Global horizontal irradiation (kWh/m²/day), for solar pumping.
  final List<double>? solarKWhM2Day;

  /// Mean daily minimum relative humidity (%) and mean wind speed at 2 m
  /// (m/s) of every month, for the Kc adjustment of FAO-56 eqs. 62 and 65
  /// (null when unknown).
  final List<double>? rhMinPct;
  final List<double>? windSpeed2mMs;

  /// Twelve values when every month has one, else null.
  static List<double>? monthlyOrNull(List<double?> v) => v.length == 12 && v.every((x) => x != null && x.isFinite) ? [for (final x in v) x!] : null;

  /// `openMeteo`, `nasaPower` or `manual`.
  final String source;
  final int firstYear, lastYear;
  final double latitudeDeg, longitudeDeg;

  /// Date of the download (`YYYY-MM-DD`).
  final String retrieved;

  /// Credit the data service asks for.
  final String attribution;

  ClimateNormals get normals => ClimateNormals(etoMmDay: etoMmDay, rainMm: rainMm, dependableRainMm: dependableRainMm);

  SiteClimate copyWith({
    List<double>? etoMmDay,
    List<double>? rainMm,
    List<double>? dependableRainMm,
    List<double>? solarKWhM2Day,
    List<double>? rhMinPct,
    List<double>? windSpeed2mMs,
    String? source,
  }) => SiteClimate(
    etoMmDay: etoMmDay ?? this.etoMmDay,
    rainMm: rainMm ?? this.rainMm,
    dependableRainMm: dependableRainMm ?? this.dependableRainMm,
    solarKWhM2Day: solarKWhM2Day ?? this.solarKWhM2Day,
    rhMinPct: rhMinPct ?? this.rhMinPct,
    windSpeed2mMs: windSpeed2mMs ?? this.windSpeed2mMs,
    source: source ?? this.source,
    firstYear: firstYear,
    lastYear: lastYear,
    latitudeDeg: latitudeDeg,
    longitudeDeg: longitudeDeg,
    retrieved: retrieved,
    attribution: attribution,
  );

  Map<String, dynamic> toJson() => {
    'eto': etoMmDay,
    'rain': rainMm,
    if (dependableRainMm != null) 'rainDep': dependableRainMm,
    if (solarKWhM2Day != null) 'rs': solarKWhM2Day,
    if (rhMinPct != null) 'rhmin': rhMinPct,
    if (windSpeed2mMs != null) 'u2': windSpeed2mMs,
    'source': source,
    if (firstYear > 0) 'y0': firstYear,
    if (lastYear > 0) 'y1': lastYear,
    'lat': latitudeDeg,
    'lon': longitudeDeg,
    if (retrieved.isNotEmpty) 'at': retrieved,
    if (attribution.isNotEmpty) 'credit': attribution,
  };

  static List<double>? _months(Object? v) {
    if (v is! List || v.length != 12) return null;
    return [for (final x in v) (x is num && x.isFinite) ? x.toDouble() : 0.0];
  }

  static SiteClimate? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    final eto = _months(j['eto']), rain = _months(j['rain']);
    if (eto == null || rain == null) return null;
    return SiteClimate(
      etoMmDay: eto,
      rainMm: rain,
      dependableRainMm: _months(j['rainDep']),
      solarKWhM2Day: _months(j['rs']),
      rhMinPct: _months(j['rhmin']),
      windSpeed2mMs: _months(j['u2']),
      source: j['source'] as String? ?? 'manual',
      firstYear: (j['y0'] as num?)?.toInt() ?? 0,
      lastYear: (j['y1'] as num?)?.toInt() ?? 0,
      latitudeDeg: (j['lat'] as num?)?.toDouble() ?? 0,
      longitudeDeg: (j['lon'] as num?)?.toDouble() ?? 0,
      retrieved: j['at'] as String? ?? '',
      attribution: j['credit'] as String? ?? '',
    );
  }
}
