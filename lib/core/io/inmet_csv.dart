/// Weather station files of INMET (Instituto Nacional de Meteorologia,
/// Brazil) read into daily values: the CSV files of the automatic stations
/// of the historical data portal (portal.inmet.gov.br/dadoshistoricos:
/// hourly rows, one file per station and year, zipped by year) and the
/// exports of BDMEP (daily or hourly rows). Both are semicolon-separated,
/// in Latin-1 or UTF-8, with a block of station data above the column
/// titles (`ESTACAO:;…`, `LATITUDE:;-15,78`… or `Nome: …`, `Latitude: …`),
/// decimal commas or points, and empty cells, `null` or `-9999` where a
/// value is missing. The columns are found by their titles (precipitation,
/// global radiation, maximum and minimum temperature, dew point, relative
/// humidity, wind speed, sunshine), whatever their order.
///
/// Hourly rows (UTC, each one closing the hour it describes) are put on
/// the local day of the station (UTC offset from its longitude, Brasília
/// time without it) and summed or averaged: rain and radiation are summed
/// (kJ/m² to MJ/m²), the day's maximum and minimum taken from the hourly
/// extremes, the humidity extremes and mean and the mean wind (measured at
/// 10 m by the INMET stations, taken to 2 m with FAO-56 eq. 47). A day
/// needs 20 hours of temperature and 22 of rain; its radiation counts when
/// most daylight hours have it (else FAO-56 estimates it from the
/// temperature range). The daily ETo is the FAO-56 Penman-Monteith
/// equation (climate.dart) with the station's latitude and altitude.
///
/// BR-DWGD (the gridded daily data of Xavier et al.) is not read: it comes
/// in NetCDF files of many gigabytes, served without the cross-origin
/// headers a browser needs.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../design/climate.dart';
import '../model/site_climate.dart';
import 'climate_online.dart';
import 'codepages.dart' show decodeTextBytes;
import 'safe_archive.dart';

/// The days of one station read from one or more files.
class StationFile {
  const StationFile({required this.name, required this.code, this.latitudeDeg, this.longitudeDeg, this.elevationM, required this.days, required this.hourly, required this.rows, this.files = 1});
  final String name;
  final String code;
  final double? latitudeDeg, longitudeDeg, elevationM;

  /// Days in date order (temperatures, humidity, wind at 2 m, radiation,
  /// rain and the Penman-Monteith ETo where the day has the data).
  final List<ClimateDay> days;
  final bool hourly;

  /// Data rows read and files merged.
  final int rows;
  final int files;

  DateTime? get first => days.isEmpty ? null : days.first.date;
  DateTime? get last => days.isEmpty ? null : days.last.date;

  /// Days with an ETo.
  int get etoDays => days.where((d) => d.etoMmDay != null).length;
}

/// Words of a title without accents, in capitals.
String _norm(String s) {
  const from = 'ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑáàâãäéèêëíìîïóòôõöúùûüçñ';
  const to = 'AAAAAEEEEIIIIOOOOOUUUUCNAAAAAEEEEIIIIOOOOOUUUUCN';
  final b = StringBuffer();
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    final i = from.indexOf(c);
    b.write(i >= 0 ? to[i] : c);
  }
  return b.toString().toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// A number of a cell: decimal comma or point (`,2` = 0.2); null when the
/// cell is empty, `null`, a dash or the missing marker −9999.
double? inmetNumber(String raw) {
  var s = raw.trim().replaceAll('"', '');
  if (s.isEmpty || s == '-' || s.toLowerCase() == 'null' || s.toLowerCase() == 'nan') return null;
  if (s.contains(',') && s.contains('.')) s = s.replaceAll('.', '');
  s = s.replaceAll(',', '.');
  if (s.startsWith('.')) s = '0$s';
  if (s.startsWith('-.')) s = '-0${s.substring(1)}';
  final v = double.tryParse(s);
  if (v == null || !v.isFinite || v <= -9990) return null;
  return v;
}

/// A date of a cell: `2019/01/01`, `2019-01-01` or `01/01/2019`.
DateTime? _date(String raw) {
  final s = raw.trim();
  var m = RegExp(r'^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})').firstMatch(s);
  if (m != null) return _valid(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
  m = RegExp(r'^(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})').firstMatch(s);
  if (m != null) {
    var y = int.parse(m.group(3)!);
    if (y < 100) y += y < 50 ? 2000 : 1900;
    return _valid(y, int.parse(m.group(2)!), int.parse(m.group(1)!));
  }
  return null;
}

DateTime? _valid(int y, int mo, int d) {
  if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
  final t = DateTime.utc(y, mo, d);
  return t.month == mo ? t : null;
}

/// The hour of a cell: `1200 UTC`, `12:00`, `12`.
int? _hour(String raw) {
  final m = RegExp(r'^(\d{1,2}):?(\d{2})?').firstMatch(raw.trim());
  if (m == null) return null;
  final digits = raw.trim().split(RegExp(r'\s'))[0].replaceAll(':', '');
  final h = digits.length >= 3 ? int.tryParse(digits.substring(0, digits.length - 2)) : int.tryParse(m.group(1)!);
  return h != null && h >= 0 && h <= 24 ? h : null;
}

/// The columns of the file, by what they hold.
enum _Col { date, hour, rain, radiation, tMax, tMin, tAir, dew, rhMax, rhMin, rh, wind, sunshine }

_Col? _colOf(String title) {
  final t = _norm(title);
  if (t.startsWith('DATA')) return _Col.date;
  if (t.startsWith('HORA')) return _Col.hour;
  if (t.startsWith('PRECIPITACAO')) return _Col.rain;
  if (t.startsWith('RADIACAO GLOBAL')) return _Col.radiation;
  if (t.startsWith('TEMPERATURA MAXIMA')) return _Col.tMax;
  if (t.startsWith('TEMPERATURA MINIMA')) return _Col.tMin;
  if (t.startsWith('TEMPERATURA DO AR') || t.startsWith('TEMPERATURA MEDIA') || t.startsWith('TEMPERATURA DO BULBO SECO')) return _Col.tAir;
  if (t.startsWith('TEMPERATURA DO PONTO DE ORVALHO')) return _Col.dew;
  if (t.startsWith('UMIDADE REL. MAX') || t.startsWith('UMIDADE RELATIVA MAXIMA')) return _Col.rhMax;
  if (t.startsWith('UMIDADE REL. MIN') || t.startsWith('UMIDADE RELATIVA DO AR, MINIMA') || t.startsWith('UMIDADE RELATIVA MINIMA')) return _Col.rhMin;
  if (t.startsWith('UMIDADE RELATIVA')) return _Col.rh;
  if (t.startsWith('VENTO') && t.contains('VELOCIDADE')) return _Col.wind;
  if (t.startsWith('INSOLACAO')) return _Col.sunshine;
  return null;
}

class _Acc {
  final rain = <double>[];
  final rad = <double>[];
  final tMax = <double>[], tMin = <double>[], tAir = <double>[], dew = <double>[];
  final rhMax = <double>[], rhMin = <double>[], rh = <double>[], wind = <double>[];
  double? sunshine;
  int hours = 0;
}

double? _mean(List<double> v) => v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;
double? _max(List<double> v) => v.isEmpty ? null : v.reduce(math.max);
double? _min(List<double> v) => v.isEmpty ? null : v.reduce(math.min);

/// The daily ETo (FAO-56 Penman-Monteith, mm/day) of day [d] at
/// [latitudeDeg] and [elevationM]: from its measured radiation, else its
/// sunshine, else the temperature range (FAO-56 eq. 50); null without
/// both temperatures.
double? dailyPenmanMonteith(ClimateDay d, {required double latitudeDeg, double elevationM = 0, double? sunshineHours}) {
  final tx = d.tMaxC, tn = d.tMinC;
  if (tx == null || tn == null) return null;
  final hi = math.max(tx, tn), lo = math.min(tx, tn);
  return fao56Eto(
    Fao56Input(
      latitudeDeg: latitudeDeg,
      elevationM: elevationM,
      dayOfYear: dayOfYear(d.date),
      tMaxC: hi,
      tMinC: lo,
      tDewC: d.tDewC,
      rhMaxPct: d.rhMaxPct,
      rhMinPct: d.rhMinPct,
      rhMeanPct: d.rhMeanPct,
      windSpeedMs: d.windSpeed2mMs,
      solarRadiationMJ: d.solarMJm2,
      sunshineHours: sunshineHours,
    ),
  ).etoMmDay;
}

/// Reads one INMET station file ([text], already decoded). [windHeightM] is
/// the anemometer height (10 m at INMET stations); [latitudeDeg] and
/// [elevationM] stand in when the file does not give them (else the ETo is
/// left out). Throws a [FormatException] (`station_no_columns`) when no
/// date column with temperatures or rain is found.
StationFile parseInmetCsv(String text, {double windHeightM = 10, double? latitudeDeg, double? elevationM}) {
  final lines = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
  final meta = <String, String>{};
  var header = -1;
  for (var i = 0; i < lines.length && i < 60; i++) {
    final l = lines[i].replaceFirst('﻿', '');
    final cells = l.split(';');
    // the titles (`DATA DE FUNDACAO:;…` is station data)
    if (cells.length >= 3 && !cells.first.contains(':') && _colOf(cells.first) == _Col.date) {
      header = i;
      break;
    }
    final k = l.indexOf(':');
    if (k > 0) meta[_norm(l.substring(0, k))] = l.substring(k + 1).replaceAll(';', ' ').trim();
  }
  if (header < 0) throw const FormatException('station_no_columns');
  String metaOf(List<String> keys) {
    for (final k in keys) {
      for (final e in meta.entries) {
        if (e.key == k || e.key.startsWith('$k ')) return e.value;
      }
    }
    return '';
  }

  final name = metaOf(['ESTACAO', 'NOME']);
  final code = metaOf(['CODIGO (WMO)', 'CODIGO ESTACAO', 'CODIGO']);
  final lat = inmetNumber(metaOf(['LATITUDE'])) ?? latitudeDeg;
  final lon = inmetNumber(metaOf(['LONGITUDE']));
  final elev = inmetNumber(metaOf(['ALTITUDE'])) ?? elevationM;
  final titles = lines[header].replaceFirst('﻿', '').split(';');
  final cols = <_Col, int>{};
  for (var i = 0; i < titles.length; i++) {
    final c = _colOf(titles[i]);
    if (c != null) cols.putIfAbsent(c, () => i);
  }
  if (!cols.containsKey(_Col.date) || !(cols.containsKey(_Col.rain) || cols.containsKey(_Col.tMax) || cols.containsKey(_Col.tAir))) throw const FormatException('station_no_columns');
  final hourly = cols.containsKey(_Col.hour);
  // UTC offset of the station's local day (Brasília time without a longitude)
  final offset = lon == null ? -3 : (lon / 15).round();
  final acc = <DateTime, _Acc>{};
  var rows = 0;
  for (var i = header + 1; i < lines.length; i++) {
    final cells = lines[i].split(';');
    if (cells.length < 2) continue;
    String cell(_Col c) {
      final k = cols[c];
      return k == null || k >= cells.length ? '' : cells[k];
    }

    final date = _date(cell(_Col.date));
    if (date == null) continue;
    var day = date;
    if (hourly) {
      final h = _hour(cell(_Col.hour));
      if (h == null) continue;
      // the row closes its hour: its middle, in local time
      final local = date.add(Duration(minutes: h * 60 + offset * 60 - 30));
      day = DateTime.utc(local.year, local.month, local.day);
    }
    rows++;
    final a = acc.putIfAbsent(day, _Acc.new);
    a.hours++;
    void add(_Col c, List<double> to, {double min = -90, double max = 1e9}) {
      final v = inmetNumber(cell(c));
      if (v != null && v >= min && v <= max) to.add(v);
    }

    add(_Col.rain, a.rain, min: 0, max: 500);
    add(_Col.radiation, a.rad, min: 0, max: hourly ? 5000 : 50000);
    add(_Col.tMax, a.tMax, min: -40, max: 60);
    add(_Col.tMin, a.tMin, min: -40, max: 60);
    add(_Col.tAir, a.tAir, min: -40, max: 60);
    add(_Col.dew, a.dew, min: -60, max: 45);
    add(_Col.rhMax, a.rhMax, min: 0, max: 100);
    add(_Col.rhMin, a.rhMin, min: 0, max: 100);
    add(_Col.rh, a.rh, min: 0, max: 100);
    add(_Col.wind, a.wind, min: 0, max: 60);
    if (!hourly) {
      final n = inmetNumber(cell(_Col.sunshine));
      if (n != null && n >= 0 && n <= 24) a.sunshine = n;
    }
  }
  final days = <ClimateDay>[];
  final keys = acc.keys.toList()..sort();
  for (final d in keys) {
    final a = acc[d]!;
    double? tMax, tMin, rain, rad, rhMax, rhMin, rhMean, wind, dew;
    if (hourly) {
      if (a.tMax.length >= 20 || a.tAir.length >= 20) {
        tMax = _max(a.tMax.length >= 20 ? a.tMax : a.tAir);
        tMin = _min(a.tMin.length >= 20 ? a.tMin : a.tAir);
      }
      if (a.rain.length >= 22) rain = a.rain.fold<double>(0, (s, v) => s + v);
      // radiation: most of the daylight hours (the nights are blank)
      if (lat != null && a.rad.isNotEmpty && a.rad.length >= 0.8 * daylightHours(lat, dayOfYear(d)) - 1) rad = a.rad.fold<double>(0, (s, v) => s + v) / 1000;
      if (a.rhMax.length >= 20) rhMax = _max(a.rhMax);
      if (a.rhMin.length >= 20) rhMin = _min(a.rhMin);
      if (a.rh.length >= 20) rhMean = _mean(a.rh);
      if (a.wind.length >= 20) wind = _mean(a.wind);
      if (a.dew.length >= 20) dew = _mean(a.dew);
    } else {
      tMax = _max(a.tMax) ?? _max(a.tAir);
      tMin = _min(a.tMin) ?? _min(a.tAir);
      rain = a.rain.isEmpty ? null : a.rain.first;
      rad = a.rad.isEmpty ? null : a.rad.first / (a.rad.first > 100 ? 1000 : 1);
      rhMin = _min(a.rhMin);
      rhMax = _max(a.rhMax);
      rhMean = _mean(a.rh);
      wind = _mean(a.wind);
      dew = _mean(a.dew);
    }
    final u2 = wind == null ? null : windSpeedAt2m(wind, windHeightM);
    var day = ClimateDay(date: d, tMaxC: tMax, tMinC: tMin, tDewC: dew, rhMaxPct: rhMax, rhMinPct: rhMin, rhMeanPct: rhMean, windSpeed2mMs: u2, solarMJm2: rad, rainMm: rain);
    final eto = lat == null ? null : dailyPenmanMonteith(day, latitudeDeg: lat, elevationM: elev ?? 0, sunshineHours: a.sunshine);
    if (eto != null) {
      day = ClimateDay(date: d, tMaxC: tMax, tMinC: tMin, tDewC: dew, rhMaxPct: rhMax, rhMinPct: rhMin, rhMeanPct: rhMean, windSpeed2mMs: u2, solarMJm2: rad, rainMm: rain, etoMmDay: eto);
    }
    days.add(day);
  }
  return StationFile(name: name, code: code, latitudeDeg: lat, longitudeDeg: lon, elevationM: elev, days: days, hourly: hourly, rows: rows);
}

/// The station files of [bytes]: one CSV file, or every CSV file of a zip
/// (the yearly archive of the portal, or the years of one station zipped
/// together), each read by [parseInmetCsv]; files that are not station
/// files are skipped. Throws a [FormatException] (`station_no_columns`)
/// when there is none.
List<StationFile> readStationFiles(Uint8List bytes, {double windHeightM = 10, double? latitudeDeg, double? elevationM}) {
  final isZip = bytes.length > 4 && bytes[0] == 0x50 && bytes[1] == 0x4B && bytes[2] == 0x03 && bytes[3] == 0x04;
  final out = <StationFile>[];
  if (isZip) {
    for (final f in openZip(bytes).files) {
      if (!f.isFile || !f.name.toLowerCase().endsWith('.csv')) continue;
      try {
        out.add(
          parseInmetCsv(
            decodeTextBytes(zipEntryBytes(f, maxBytes: 64 << 20)),
            windHeightM: windHeightM,
            latitudeDeg: latitudeDeg,
            elevationM: elevationM,
          ),
        );
      } on FormatException catch (e) {
        if (e.message == 'zip_too_large') rethrow;
      }
    }
  } else {
    out.add(parseInmetCsv(decodeTextBytes(bytes), windHeightM: windHeightM, latitudeDeg: latitudeDeg, elevationM: elevationM));
  }
  if (out.isEmpty) throw const FormatException('station_no_columns');
  return out;
}

/// The files of one station merged (the years of a station read one by
/// one), grouped by station code (or name); a day found twice keeps the one
/// with more data.
List<StationFile> mergeStationFiles(List<StationFile> files) {
  final groups = <String, List<StationFile>>{};
  for (final f in files) {
    (groups[f.code.isNotEmpty ? f.code : f.name] ??= []).add(f);
  }
  int score(ClimateDay d) => [d.tMaxC, d.tMinC, d.rainMm, d.solarMJm2, d.rhMinPct, d.windSpeed2mMs, d.etoMmDay].whereType<double>().length;
  return [
    for (final g in groups.values)
      () {
        final byDate = <DateTime, ClimateDay>{};
        for (final f in g) {
          for (final d in f.days) {
            final old = byDate[d.date];
            if (old == null || score(d) > score(old)) byDate[d.date] = d;
          }
        }
        final days = byDate.values.toList()..sort((a, b) => a.date.compareTo(b.date));
        final f = g.first;
        return StationFile(
          name: f.name,
          code: f.code,
          latitudeDeg: f.latitudeDeg,
          longitudeDeg: f.longitudeDeg,
          elevationM: f.elevationM,
          days: days,
          hourly: g.any((x) => x.hourly),
          rows: g.fold(0, (s, x) => s + x.rows),
          files: g.fold(0, (s, x) => s + x.files),
        );
      }(),
  ];
}

/// The site climate of station [s]: the monthly normals of its complete
/// months (ETo by FAO-56 Penman-Monteith day by day, mean and dependable
/// rain, radiation, RHmin and u2 for the Kc adjustment) and its daily ETo
/// and rain for the soil water balance. Null when no month has ETo.
SiteClimate? stationClimate(StationFile s, {double dependableProbability = 0.8, String retrieved = ''}) {
  final lat = s.latitudeDeg;
  if (lat == null || s.days.isEmpty) return null;
  final normals = monthlyNormalsOfDays(s.days, latitudeDeg: lat, elevationM: s.elevationM ?? 0, dependableProbability: dependableProbability);
  final req = climateNormalsForRequirement(normals);
  if (req == null) return null;
  final rs = [for (final n in normals) n.solarKWhM2Day];
  final years = [for (final d in s.days) d.date.year];
  return SiteClimate(
    etoMmDay: req.etoMmDay,
    rainMm: req.rainMm,
    dependableRainMm: req.dependableRainMm,
    solarKWhM2Day: rs.every((x) => x != null) ? [for (final x in rs) x!] : null,
    rhMinPct: SiteClimate.monthlyRhMin([for (final n in normals) (n.rhMinPct, n.tMaxC, n.tDewC, n.tMinC)]),
    windSpeed2mMs: SiteClimate.monthlyOrNull([for (final n in normals) n.windSpeed2mMs]),
    source: 'inmet',
    firstYear: years.reduce(math.min),
    lastYear: years.reduce(math.max),
    latitudeDeg: lat,
    longitudeDeg: s.longitudeDeg ?? 0,
    retrieved: retrieved,
    attribution: 'INMET ${s.code.isEmpty ? s.name : '${s.name} (${s.code})'}',
    daily: DailyClimate.fromDays([for (final d in s.days) (d.date, d.etoMmDay, d.rainMm)], source: 'inmet'),
  );
}

/// The daily ETo and rain of a downloaded [series] for the soil water
/// balance: the service's ETo (Open-Meteo) or the FAO-56 Penman-Monteith
/// ETo of the day (NASA POWER).
DailyClimate? dailyClimateOfSeries(ClimateSeries series) => DailyClimate.fromDays([
  for (final d in series.days) (d.date, d.etoMmDay ?? dailyPenmanMonteith(d, latitudeDeg: series.latitudeDeg, elevationM: series.elevationM ?? 0), d.rainMm),
], source: series.source.name);
