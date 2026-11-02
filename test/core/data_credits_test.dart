import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/io/climate_online.dart';
import 'package:opencadirrigation/core/io/data_credits.dart';
import 'package:opencadirrigation/core/io/dem_online.dart';
import 'package:opencadirrigation/core/io/plot.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/model/site_climate.dart';

/// The third-party data of a project and their credits (PRD-06): the online elevation of its spot heights, the
/// downloaded climate and the base map pictures kept for the field, each source once, with what its free use allows;
/// the credits a sheet prints under the base map's own.
void main() {
  SiteClimate climate(String source, String credit) =>
      SiteClimate(etoMmDay: List.filled(12, 5), rainMm: List.filled(12, 60), source: source, attribution: credit, retrieved: credit.isEmpty ? '' : '2026-11-02');

  ImageEntity picture(Project p, String credit, {String layer = Layers.images}) => ImageEntity(
    id: p.newId(),
    layer: layer,
    name: 'Map for the field (OpenStreetMap)',
    origin: Pt.zero,
    width: 100,
    height: 80,
    mime: 'image/jpeg',
    data: Uint8List(4),
    source: '$baseMapPictureMark $credit',
  );

  SpotHeightEntity demPoint(Project p, DemSource s, double x) => SpotHeightEntity(id: p.newId(), layer: Layers.dem, position: Pt(x, 0), elevation: 100, name: 'DEM ${s.name}');

  test('each source once, with its credit and what its free use allows', () {
    final p = Project();
    p.entities.addAll([demPoint(p, DemSource.terrainTiles, 0), demPoint(p, DemSource.terrainTiles, 10), demPoint(p, DemSource.openMeteo, 20)]);
    p.climate = climate('openMeteo', ClimateSource.openMeteo.attribution);
    p.entities.addAll([picture(p, '© OpenStreetMap contributors'), picture(p, '© OpenStreetMap contributors')]);
    // a photo of the user's is no third-party map
    p.entities.add(ImageEntity(id: p.newId(), origin: Pt.zero, width: 10, height: 10, source: 'drone.jpg'));
    final credits = projectDataCredits(p);
    expect([for (final c in credits) c.kind], [DataKind.elevation, DataKind.elevation, DataKind.climate, DataKind.baseMap]);
    expect(credits[0].credit, DemSource.terrainTiles.attribution);
    expect(credits[0].use, DataUse.any);
    expect(credits[1].use, DataUse.nonCommercial, reason: 'the free Open-Meteo API is non-commercial');
    expect(credits[2].source, 'Open-Meteo');
    expect(credits[2].credit, '${ClimateSource.openMeteo.attribution} (2026-11-02)');
    expect(credits[2].use, DataUse.nonCommercial);
    expect(credits[3].credit, '© OpenStreetMap contributors');
    expect(credits[3].use, DataUse.provider);
  });

  test('NASA POWER is free for any use; typed or station climate carries no credit', () {
    final p = Project()..climate = climate('nasaPower', ClimateSource.nasaPower.attribution);
    expect(projectDataCredits(p).single.use, DataUse.any);
    expect(projectDataCredits(p).single.source, 'NASA POWER');
    p.climate = climate('manual', '');
    expect(projectDataCredits(p), isEmpty);
    expect(projectDataCredits(Project()), isEmpty);
  });

  test('a sheet prints the base map credit first, then the kept pictures and the elevation it shows, one per line', () {
    final p = Project();
    expect(sheetCredits(p, 'Esri, Maxar, Earthstar Geographics'), 'Esri, Maxar, Earthstar Geographics');
    expect(sheetCredits(p, ''), '');
    p.entities.add(picture(p, '© OpenStreetMap contributors'));
    p.entities.add(demPoint(p, DemSource.terrainTiles, 0));
    expect(sheetCredits(p, 'Esri, Maxar, Earthstar Geographics'), 'Esri, Maxar, Earthstar Geographics\n© OpenStreetMap contributors\n${DemSource.terrainTiles.attribution}');
    expect(sheetCredits(p, '© OpenStreetMap contributors'), '© OpenStreetMap contributors\n${DemSource.terrainTiles.attribution}', reason: 'each credit once');
    // what the sheet does not show carries no credit
    p.layerNamed(Layers.images).visible = false;
    p.layerNamed(Layers.dem).visible = false;
    expect(sheetCredits(p, ''), '');
    // the plot scene of the sheets and of the SVG carries them
    p.layerNamed(Layers.images).visible = true;
    final scene = buildPlotScene(p, unitsPerMm: 1, attribution: 'Esri');
    expect(scene.attribution, 'Esri\n© OpenStreetMap contributors');
  });

  test('every source of the terms has its page and credit; Help → Terms of the data lists them all', () {
    expect(dataSources.map((s) => s.id).toSet(), {'terrainTiles', 'openMeteoDem', 'openTopoData', 'nasaPower', 'openMeteo', 'nominatim'});
    for (final s in dataSources) {
      expect(s.url, startsWith('https://'), reason: s.id);
      expect(s.credit, isNotEmpty, reason: s.id);
    }
    expect(dataSources.firstWhere((s) => s.id == 'openMeteo').use, DataUse.nonCommercial);
    expect(dataSources.firstWhere((s) => s.id == 'nasaPower').use, DataUse.any);
    expect(baseMapPictureCredit(ImageEntity(id: 'i', origin: Pt.zero, width: 1, height: 1, source: 'basemap: © CARTO')), '© CARTO');
    expect(baseMapPictureCredit(ImageEntity(id: 'j', origin: Pt.zero, width: 1, height: 1, source: 'scan.png')), isNull);
  });
}
