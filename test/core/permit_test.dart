import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/core/design/design_check.dart';
import 'package:opencadirrigation/core/design/permit.dart';
import 'package:opencadirrigation/core/io/geo.dart';
import 'package:opencadirrigation/core/io/tech_doc.dart';
import 'package:opencadirrigation/core/io/xlsx.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

/// The water permit table of every point of abstraction (PRD-02): the
/// monthly regime as the federal permits write it (flow, hours/day,
/// days/month, m³/day, m³/month), never below the gross requirement of the
/// areas the point waters; SIRGAS 2000 coordinates in degrees, minutes and
/// seconds and UTM; the capacity check against the peak month; the federal
/// floor of Resolution ANA 1.939/2017; the self-monitoring thresholds of
/// Resolution ANA 188/2024; and the design check of an intake without a
/// meter.
void main() {
  final t = I18n('pt');

  /// One hectare at a fixed net depth of [netMm] mm/day (efficiency 0.9)
  /// fed by one source of [flowM3h] m³/h, near Jataí (GO).
  Project oneHectare({double netMm = 4.5, double flowM3h = 50, bool georef = true}) {
    final p = Project();
    if (georef) p.meta.georef = GeoReference.fromLatLonOrigin(-17.853, -51.85);
    p.entities.addAll([
      WaterSupplyEntity(id: 'e1', name: 'Captação Rio Claro', position: Pt.zero, designFlow: flowM3h / 3600),
      AreaEntity(id: 'e2', name: 'Talhão 1', points: const [Pt(10, 10), Pt(110, 10), Pt(110, 110), Pt(10, 110)], netDepthMmPerDay: netMm, efficiency: 0.9),
    ]);
    return p;
  }

  test('a fixed depth needs its gross volume every day of every month', () {
    final p = oneHectare();
    final n = areaMonthlyNeed(p, p.byId('e2') as AreaEntity);
    // 4.5 / 0.9 = 5 mm/day over 1 ha = 50 m³/day
    expect(n.volumeM3[0], closeTo(50 * 31, 1e-6));
    expect(n.volumeM3[1], closeTo(50 * 28, 1e-6));
    expect(n.days[0], 31);
    expect(n.annualM3, closeTo(50 * 365, 1e-6));
  });

  test('the regime of every month: the days with irrigation and the hours they need', () {
    final p = oneHectare();
    final st = buildPermitStudy(p, null);
    expect(st.sources, hasLength(1));
    final s = st.sources.single;
    expect(s.installedFlowM3h, closeTo(50, 1e-9));
    expect(s.flowFromDemand, isFalse);
    expect(s.daysPerMonth[0], 31);
    expect(s.hoursPerDay[0], closeTo(1.0, 1e-9));
    expect(s.flowM3h[0], closeTo(50, 1e-9));
    expect(s.volumeMonthM3[0], closeTo(1550, 1e-6));
    expect(s.volumeDayM3[0], closeTo(50, 1e-9));
    expect(s.annualM3, closeTo(50 * 365, 1e-6));
    expect(s.hoursPerYear, closeTo(365, 1e-6));
    expect(s.areaHa, closeTo(1, 1e-9));
    expect(s.months, [for (var m = 1; m <= 12; m++) m]);
    expect(s.methods, ['req.method.sprinkler']);
    // never below the need: the hours are rounded up to a tenth
    final q = oneHectare(flowM3h: 47);
    final r = buildPermitStudy(q, null).sources.single;
    for (var m = 0; m < 12; m++) {
      expect(r.volumeMonthM3[m], greaterThanOrEqualTo(r.needM3[m] - 1e-6));
      expect(r.hoursPerDay[m] * 10, closeTo((r.hoursPerDay[m] * 10).roundToDouble(), 1e-9));
    }
  });

  test('fixed hours a day: the days the volume takes', () {
    final p = oneHectare();
    p.deliverables.permit.fixedHoursPerDay = 10;
    final s = buildPermitStudy(p, null).sources.single;
    // 1550 m³ at 50 m³/h × 10 h = 3.1 days → 4 days
    expect(s.hoursPerDay[0], 10);
    expect(s.daysPerMonth[0], 4);
    expect(s.volumeMonthM3[0], closeTo(2000, 1e-6));
    expect(s.volumeMonthM3[0], greaterThanOrEqualTo(s.needM3[0]));
  });

  test('coordinates on SIRGAS 2000: degrees, minutes and seconds, UTM and its EPSG code', () {
    final s = buildPermitStudy(oneHectare(), null).sources.single;
    expect(s.lat, closeTo(-17.853, 1e-6));
    expect(s.lon, closeTo(-51.85, 1e-6));
    expect(permitDms(s.lat!, 'N', 'S'), '17°51\'10.80" S');
    expect(permitDms(s.lon!, 'E', 'W'), '51°51\'00.00" W');
    expect(s.utm!.zone, 22);
    expect(s.utm!.north, isFalse);
    expect(s.epsg, 31982);
    // seconds that round to 60 carry into the minutes
    expect(permitDms(-10.999999, 'N', 'S'), '11°00\'00.00" S');
    // without a georeference the coordinates stay blank, and the table says why
    final none = buildPermitStudy(oneHectare(georef: false), null).sources.single;
    expect(none.lat, isNull);
    expect(none.warnings, contains('permit_no_georef'));
  });

  test('the installed flow is checked against the peak month', () {
    // 50 m³/day at 2.5 m³/h: 20 h/day, within the 21 h
    expect(buildPermitStudy(oneHectare(flowM3h: 2.5), null).sources.single.warnings, isNot(contains('permit_capacity')));
    // at 2.3 m³/h: 21.7 h/day, above the 21 h
    final tight = buildPermitStudy(oneHectare(flowM3h: 2.3), null).sources.single;
    expect(tight.peakHoursNeeded, closeTo(50 / 2.3, 1e-9));
    expect(tight.warnings, contains('permit_capacity'));
    // at 1 m³/h even 24 h a day is not enough
    expect(buildPermitStudy(oneHectare(flowM3h: 1), null).sources.single.warnings, contains('permit_hours_over_24'));
  });

  test('without a flow, the one the peak month needs in the most hours a day', () {
    final p = oneHectare();
    (p.byId('e1') as WaterSupplyEntity).designFlow = 0;
    final s = buildPermitStudy(p, null).sources.single;
    expect(s.flowFromDemand, isTrue);
    expect(s.warnings, contains('permit_flow_from_demand'));
    // 50 m³/day in 21 h → 2.39 m³/h, rounded up to a tenth
    expect(s.installedFlowM3h, closeTo(2.4, 1e-9));
    expect(s.hoursPerDay[0], lessThanOrEqualTo(21));
  });

  test('the federal floor of 300 m³/ha raises the months with irrigation below it', () {
    final p = oneHectare(netMm: 0.2);
    final plain = buildPermitStudy(p, null).sources.single;
    expect(plain.volumeMonthM3[0], lessThan(300));
    p.deliverables.permit.federalFloor = true;
    final s = buildPermitStudy(p, null).sources.single;
    expect(s.volumeMonthM3[0], greaterThanOrEqualTo(300 - 1e-6));
    expect(s.floorRaised[0], isTrue);
    expect(s.warnings, contains('permit_federal_floor'));
    // the need stays the computed one
    expect(s.needM3[0], closeTo(plain.needM3[0], 1e-9));
  });

  test('two sources: each area goes to the nearest one without a design', () {
    final p = oneHectare();
    p.entities.addAll([
      WaterSupplyEntity(id: 'e3', name: 'Poço', position: const Pt(1000, 0), designFlow: 20 / 3600),
      AreaEntity(id: 'e4', points: const [Pt(950, 10), Pt(1050, 10), Pt(1050, 60), Pt(950, 60)], netDepthMmPerDay: 4.5, efficiency: 0.9),
    ]);
    final st = buildPermitStudy(p, null);
    final a = st.sources.firstWhere((s) => s.supply.id == 'e1'), b = st.sources.firstWhere((s) => s.supply.id == 'e3');
    expect(a.areaIds, ['e2']);
    expect(b.areaIds, ['e4']);
    expect(b.areaHa, closeTo(0.5, 1e-9));
    expect(st.totalFlowM3h, closeTo(70, 1e-9));
  });

  test('self-monitoring thresholds of Resolution ANA 188/2024 (Annex I)', () {
    final other = monitoringUnitOf('');
    expect(other.key, 'other');
    expect(monitoringObligation(other, [100]), 'none');
    expect(monitoringObligation(other, [900, 700]), 'annual');
    expect(monitoringObligation(other, [4000]), 'telemetry');
    final verde = monitoringUnitOf('verdeGrande');
    expect(monitoringObligation(verde, [60]), 'monthly');
    expect(monitoringObligation(verde, [2500]), 'telemetry');
    // Art. 5 § 1: points below 10 % of the threshold, together within 20 %
    expect(monitoringExemptions(other, [1500, 100, 120]), [false, true, true]);
    expect(monitoringExemptions(other, [1500, 140, 140, 140]), [false, false, false, false]);
    expect(monitoringExemptions(other, [100]), [false]);
    final st = buildPermitStudy(oneHectare(), null);
    expect(st.obligation, 'none');
  });

  test('the design check flags an intake without a flow meter or an hour meter', () {
    final p = oneHectare();
    final issues = permitChecks(p);
    expect(issues.map((i) => i.code), ['supply_no_meter']);
    expect(issues.single.severity, CheckSeverity.info);
    expect(runDesignCheck(p).issues.map((i) => i.code), contains('supply_no_meter'));
    expect(buildPermitStudy(p, null).sources.single.warnings, contains('permit_no_meter'));
    // a meter of the catalogue near the intake
    final meter = p.catalog.valves.firstWhere((v) => v.kind == ValveKind.meter);
    p.entities.add(MiscHydraulicEntity(id: 'e9', position: const Pt(2, 0), valveSpecId: meter.id));
    expect(permitChecks(p), isEmpty);
    final st = buildPermitStudy(p, null).sources.single;
    expect(st.meter, isTrue);
    expect(st.warnings, isNot(contains('permit_no_meter')));
    // or an hour meter on its pump
    final q = oneHectare()..entities.add(PumpEntity(id: 'e8', position: const Pt(1, 0), hourMeter: true));
    expect(permitChecks(q), isEmpty);
    expect(buildPermitStudy(q, null).sources.single.hourMeter, isTrue);
  });

  test('the document: the enterprise, every point with its regime, the self-monitoring and the criteria', () {
    final p = oneHectare();
    p.deliverables.permit.source('e1')
      ..waterBody = 'Rio Claro'
      ..registry = '223674';
    final st = buildPermitStudy(p, null);
    final doc = permitDocument(p, st, t.call);
    expect(doc.key, 'permit');
    expect(doc.landscape, isTrue);
    expect(doc.sections.map((s) => s.key), ['enterprise', 'point:e1', 'monitoring', 'criteria']);
    final texts = doc.texts.join('\n');
    expect(texts, contains('Rio Claro'));
    expect(texts, contains('223674'));
    expect(texts, contains('17°51\'10.80" S'));
    expect(texts, contains('EPSG:31982'));
    final monthly = doc.tables.firstWhere((x) => x.key == 'permitMonthly:e1');
    expect(monthly.headers, hasLength(14));
    expect(monthly.headers[1], 'Jan');
    expect(monthly.rows.first.first, 'Q (m³/h)');
    final log = doc.tables.firstWhere((x) => x.key == 'permitLog:e1');
    expect(log.rows, hasLength(13));
    // every output of the document holds the table
    expect(doc.toCsv(), contains('Q (m³/h);50.0;'));
    expect(doc.toMarkdown(), contains('| Q (m³/h) | 50.0 |'));
    final sheets = XlsxReader.read(doc.toXlsx());
    expect(sheets.map((s) => s.name), contains(startsWith('Regime de operação mensal')));
    final pdf = techDocumentPdf(doc, t: t.call);
    expect(latin1.decode(pdf.sublist(0, 8)), startsWith('%PDF-1.4'));
  });

  test('without a source the study says so', () {
    final p = Project();
    final st = buildPermitStudy(p, null);
    expect(st.sources, isEmpty);
    expect(st.warnings, ['permit_no_source']);
    expect(permitChecks(p), isEmpty);
    final doc = permitDocument(p, st, t.call);
    expect(doc.texts.join(' '), contains(t('prb.warn.permit_no_source')));
  });
}
