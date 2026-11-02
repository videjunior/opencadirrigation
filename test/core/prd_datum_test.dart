import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/core/design/report_tables.dart';
import 'package:opencadirrigation/core/io/datum.dart';
import 'package:opencadirrigation/core/io/geo.dart';
import 'package:opencadirrigation/core/io/project_export.dart';
import 'package:opencadirrigation/core/model/project.dart';

final i18n = I18n('en');

ProjectExporter exporterOf(Project p) => ProjectExporter(project: p, labels: ReportLabels(t: i18n.call, has: i18n.has, warning: i18n.warning));

/// The datum of a project's georeference (1.6.0 PRD): named by the user or
/// by the site, written only when chosen, used on the sheets and in the
/// projected files.
void main() {
  test('the official datum of the site', () {
    const sirgas = {
      'Brasília': (-15.78, -47.93),
      'Manaus': (-3.10, -60.02),
      'Porto Alegre': (-30.03, -51.23),
      'Petrolina': (-9.39, -40.50),
      'Fernando de Noronha': (-3.85, -32.42),
      'Buenos Aires': (-34.60, -58.38),
      'Santiago': (-33.45, -70.67),
      'Lima': (-12.05, -77.04),
      'Bogotá': (4.71, -74.07),
      'Guatemala City': (14.63, -90.51),
    };
    const etrs = {
      'Lisbon': (38.72, -9.14),
      'Faro': (37.02, -7.93),
      'Madrid': (40.42, -3.70),
      'Almería': (36.84, -2.46),
      'Palma': (39.57, 2.65),
      'Paris': (48.86, 2.35),
      'Warsaw': (52.23, 21.01),
      'Vilnius': (54.69, 25.28),
      'Helsinki': (60.17, 24.94),
      'Athens': (37.98, 23.73),
    };
    const wgs = {
      'Miami': (25.76, -80.19),
      'Houston': (29.76, -95.37),
      'Mexico City': (19.43, -99.13),
      'Tangier': (35.77, -5.80),
      'Algiers': (36.75, 3.06),
      'Tunis': (36.81, 10.18),
      'Istanbul': (41.01, 28.98),
      'Kyiv': (50.45, 30.52),
      'Tokyo': (35.68, 139.69),
      'Canary Islands': (28.29, -16.63),
    };
    for (final e in sirgas.entries) {
      expect(defaultProjectDatum(e.value.$1, e.value.$2), GeodeticDatum.sirgas2000, reason: e.key);
    }
    for (final e in etrs.entries) {
      expect(defaultProjectDatum(e.value.$1, e.value.$2), GeodeticDatum.etrs89, reason: e.key);
    }
    for (final e in wgs.entries) {
      expect(defaultProjectDatum(e.value.$1, e.value.$2), GeodeticDatum.wgs84, reason: e.key);
    }
    expect(defaultProjectDatum(double.nan, 0), GeodeticDatum.wgs84);
  });

  test('a georeference names its datum; the file keeps it only when chosen', () {
    final br = GeoReference.fromLatLonOrigin(-15.78, -47.93);
    expect(br.datum, isNull);
    expect(br.effectiveDatum, GeodeticDatum.sirgas2000);
    expect(br.crsName, 'SIRGAS 2000 / UTM 23S');
    expect(br.epsg, 31983);
    expect(br.toJson().containsKey('datum'), isFalse, reason: 'an old file stays as it was');
    final w = br.withDatum(GeodeticDatum.wgs84);
    expect((w.zone, w.north, w.originEasting, w.originNorthing), (br.zone, br.north, br.originEasting, br.originNorthing));
    expect(w.crsName, 'WGS84 / UTM 23S');
    expect(w.epsg, 32723);
    final back = GeoReference.fromJson(jsonDecode(jsonEncode(w.toJson())) as Map<String, dynamic>);
    expect(back.datum, GeodeticDatum.wgs84);
    // a datum a project cannot name (it would move the coordinates): by the site
    final odd = GeoReference.fromJson({...br.toJson(), 'datum': 'sad69'});
    expect(odd.datum, isNull);
    expect(GeoReference.fromLatLonOrigin(40.42, -3.70).crsName, 'ETRS89 / UTM 30N');
    expect(GeoReference.fromLatLonOrigin(25.76, -80.19).crsName, 'WGS84 / UTM 17N');
    // a project saved and read again
    final p = Project()..meta.georef = br.withDatum(GeodeticDatum.etrs89);
    final q = Project.fromJson(jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);
    expect(q.meta.georef!.datum, GeodeticDatum.etrs89);
  });

  test('the projected files name the datum of the georeference', () {
    final p = buildExample(ExampleId.sportsField, i18n.call, lang: 'en')..meta.georef = GeoReference.fromLatLonOrigin(-15.78, -47.93);
    String prj(Project p) {
      final zip = ZipDecoder().decodeBytes(exporterOf(p).exportDrawing(DrawingFormat.shp) as List<int>);
      final f = zip.files.firstWhere((f) => f.name.endsWith('.prj'));
      return utf8.decode(f.content as List<int>);
    }

    expect(prj(p), contains('SIRGAS_2000'));
    p.meta.georef = p.meta.georef!.withDatum(GeodeticDatum.wgs84);
    expect(prj(p), contains('WGS_1984'));
    expect(prj(p), isNot(contains('SIRGAS')));
    // in Spain: ETRS89 by the site
    p.meta.georef = GeoReference.fromLatLonOrigin(40.42, -3.70);
    expect(prj(p), contains('ETRS_1989'));
    final xml = exporterOf(p).exportDrawing(DrawingFormat.landxml) as String;
    expect(xml, contains('ETRS89'));
    final ifc = exporterOf(p).exportDrawing(DrawingFormat.ifc) as String;
    expect(ifc, contains('ETRS89'));
  });
}
