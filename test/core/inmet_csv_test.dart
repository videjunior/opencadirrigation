import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/climate.dart' show windSpeedAt2m;
import 'package:opencadirrigation/core/io/inmet_csv.dart';

/// Weather station files of INMET (1.6.0 AGR, AGR-13): the hourly CSV of
/// the automatic stations (UTC rows put on the local day), the daily
/// exports of BDMEP, zips of years, and the site climate they give.
void main() {
  String two(int v) => v.toString().padLeft(2, '0');
  String comma(double v) => v.toString().replaceAll('.', ',');

  const hourlyTitles =
      'Data;Hora UTC;PRECIPITAÇÃO TOTAL, HORÁRIO (mm);PRESSAO ATMOSFERICA AO NIVEL DA ESTACAO, HORARIA (mB);RADIACAO GLOBAL (Kj/m²);'
      'TEMPERATURA DO AR - BULBO SECO, HORARIA (°C);TEMPERATURA DO PONTO DE ORVALHO (°C);TEMPERATURA MÁXIMA NA HORA ANT. (AUT) (°C);'
      'TEMPERATURA MÍNIMA NA HORA ANT. (AUT) (°C);UMIDADE REL. MAX. NA HORA ANT. (AUT) (%);UMIDADE REL. MIN. NA HORA ANT. (AUT) (%);'
      'UMIDADE RELATIVA DO AR, HORARIA (%);VENTO, DIREÇÃO HORARIA (gr) (° (gr));VENTO, RAJADA MAXIMA (m/s);VENTO, VELOCIDADE HORARIA (m/s);';

  /// Three days of hourly rows (UTC) of a station at Brasília time: 1 mm of
  /// rain every hour of the 1st (local), sun from 07 to 18 local.
  String hourly() {
    final b = StringBuffer('REGIAO:;CO\nUF:;DF\nESTACAO:;BRASILIA\nCODIGO (WMO):;A001\nLATITUDE:;-15,78944444\nLONGITUDE:;-47,92583332\nALTITUDE:;1160,96\nDATA DE FUNDACAO:;07/05/00\n');
    b.writeln(hourlyTitles);
    for (var d = 1; d <= 3; d++) {
      for (var h = 0; h < 24; h++) {
        final utc = DateTime.utc(2019, 1, d, h);
        final local = utc.subtract(const Duration(hours: 3, minutes: 30));
        final hourOfDay = local.hour + 1; // the local hour the row closes, 1–24
        final temp = 15 + hourOfDay / 2;
        final rain = local.day == 1 ? 1.0 : 0.0;
        final sun = hourOfDay >= 8 && hourOfDay <= 19 ? '1000' : '';
        b.writeln(
          '2019/01/${two(d)};${two(h)}00 UTC;${comma(rain)};887,7;$sun;${comma(temp)};12,0;${comma(temp + 0.5)};${comma(temp - 0.5)};80;40;60;90;5,0;2,0;',
        );
      }
    }
    return b.toString();
  }

  /// A year of daily BDMEP rows: [rain] mm every day.
  String bdmep(int year, {double rain = 1}) {
    final b = StringBuffer(
      'Nome: BRASILIA\nCodigo Estacao: 83377\nLatitude: -15.78\nLongitude: -47.92\nAltitude: 1159.54\nSituacao: Operante\nPeriodicidade da Medicao: Diaria\n\n',
    );
    b.writeln(
      'Data Medicao;PRECIPITACAO TOTAL, DIARIO(mm);TEMPERATURA MAXIMA, DIARIA(°C);TEMPERATURA MINIMA, DIARIA(°C);'
      'UMIDADE RELATIVA DO AR, MEDIA DIARIA(%);UMIDADE RELATIVA DO AR, MINIMA DIARIA(%);VENTO, VELOCIDADE MEDIA DIARIA(m/s);',
    );
    for (var d = DateTime.utc(year); d.year == year; d = d.add(const Duration(days: 1))) {
      b.writeln('${d.year}-${two(d.month)}-${two(d.day)};${comma(rain)};28,1;18,2;70,5;45;2,1;');
    }
    return b.toString();
  }

  test('numbers of a cell: decimal commas, missing markers', () {
    expect(inmetNumber('1,5'), 1.5);
    expect(inmetNumber(',2'), closeTo(0.2, 1e-12));
    expect(inmetNumber('-,5'), closeTo(-0.5, 1e-12));
    expect(inmetNumber('1.234,5'), 1234.5);
    expect(inmetNumber('12.5'), 12.5);
    expect(inmetNumber('-9999'), isNull);
    expect(inmetNumber('null'), isNull);
    expect(inmetNumber(''), isNull);
    expect(inmetNumber(' "3,0" '), 3.0);
  });

  test('hourly rows of an automatic station on the local day', () {
    final s = parseInmetCsv(hourly());
    expect(s.name, 'BRASILIA');
    expect(s.code, 'A001');
    expect(s.latitudeDeg, closeTo(-15.789, 1e-3));
    expect(s.longitudeDeg, closeTo(-47.926, 1e-3));
    expect(s.elevationM, closeTo(1160.96, 1e-9));
    expect(s.hourly, isTrue);
    expect(s.rows, 72);
    // the first rows close hours of the 31st (local), the last of the 3rd
    final byDay = {for (final d in s.days) d.date: d};
    final jan1 = byDay[DateTime.utc(2019, 1, 1)]!, jan2 = byDay[DateTime.utc(2019, 1, 2)]!;
    expect(jan1.rainMm, closeTo(24, 1e-9));
    expect(jan2.rainMm, 0);
    expect(jan1.tMaxC, closeTo(15 + 24 / 2 + 0.5, 1e-9));
    expect(jan1.tMinC, closeTo(15 + 1 / 2 - 0.5, 1e-9));
    expect(jan1.rhMaxPct, 80);
    expect(jan1.rhMinPct, 40);
    expect(jan1.rhMeanPct, 60);
    expect(jan1.tDewC, closeTo(12, 1e-9));
    expect(jan1.solarMJm2, closeTo(12, 1e-9), reason: '12 hours of 1000 kJ/m²');
    expect(jan1.windSpeed2mMs, closeTo(windSpeedAt2m(2.0, 10), 1e-9), reason: 'anemometer at 10 m');
    expect(jan1.etoMmDay, inExclusiveRange(2, 8));
    expect(jan2.etoMmDay, isNotNull);
    // a day with four hours has no temperatures nor rain
    final dec31 = byDay[DateTime.utc(2018, 12, 31)]!;
    expect(dec31.tMaxC, isNull);
    expect(dec31.rainMm, isNull);
    expect(dec31.etoMmDay, isNull);
    // the 3rd has the 20 hours of temperature a day needs, not the 22 of rain
    final jan3 = byDay[DateTime.utc(2019, 1, 3)]!;
    expect(jan3.tMaxC, isNotNull);
    expect(jan3.rainMm, isNull);
    expect(s.days, hasLength(4));
    expect(s.etoDays, 3);
  });

  test('daily rows of BDMEP', () {
    final s = parseInmetCsv(bdmep(2019));
    expect(s.name, 'BRASILIA');
    expect(s.code, '83377');
    expect(s.hourly, isFalse);
    expect(s.days, hasLength(365));
    final d = s.days.first;
    expect(d.date, DateTime.utc(2019, 1, 1));
    expect(d.rainMm, 1);
    expect(d.tMaxC, closeTo(28.1, 1e-9));
    expect(d.tMinC, closeTo(18.2, 1e-9));
    expect(d.rhMinPct, 45);
    expect(d.rhMeanPct, closeTo(70.5, 1e-9));
    expect(d.windSpeed2mMs, closeTo(windSpeedAt2m(2.1, 10), 1e-9));
    expect(d.etoMmDay, inExclusiveRange(2, 8), reason: 'radiation from the temperature range (FAO-56 eq. 50)');
    expect(() => parseInmetCsv('not;a;station\n1;2;3'), throwsA(isA<FormatException>()));
  });

  test('a zip of the years of one station, merged; the site climate it gives', () {
    final archive = Archive();
    for (final (name, text) in [('INMET_CO_DF_83377_2019.CSV', bdmep(2019)), ('INMET_CO_DF_83377_2020.csv', bdmep(2020, rain: 2)), ('readme.txt', 'not a station')]) {
      final bytes = latin1.encode(text.replaceAll('°', 'o').replaceAll('²', '2'));
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }
    final zip = Uint8List.fromList(ZipEncoder().encode(archive));
    final files = readStationFiles(zip);
    expect(files, hasLength(2));
    final merged = mergeStationFiles(files);
    expect(merged, hasLength(1));
    final st = merged.single;
    expect(st.files, 2);
    expect(st.days, hasLength(365 + 366));
    expect(st.first, DateTime.utc(2019, 1, 1));
    expect(st.last, DateTime.utc(2020, 12, 31));
    final sc = stationClimate(st, retrieved: '2026-11-02')!;
    expect(sc.source, 'inmet');
    expect(sc.firstYear, 2019);
    expect(sc.lastYear, 2020);
    expect(sc.latitudeDeg, closeTo(-15.78, 1e-9));
    // January: 31 mm in 2019, 62 mm in 2020
    expect(sc.rainMm[0], closeTo((31 + 62) / 2, 1e-9));
    expect(sc.etoMmDay.every((e) => e > 0 && e < 10), isTrue);
    expect(sc.attribution, contains('83377'));
    expect(sc.daily!.completeYears, [2019, 2020]);
    expect(sc.daily!.source, 'inmet');
    expect(() => readStationFiles(Uint8List.fromList(utf8.encode('hello'))), throwsA(isA<FormatException>()));
  });
}
