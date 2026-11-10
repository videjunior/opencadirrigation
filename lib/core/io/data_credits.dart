/// The third-party data a project carries, with the credit each source asks for and what its free use allows in
/// professional work (PRD-06): the ground elevations of an online elevation model, the climate downloaded for the
/// site and the base map pictures kept for the field. The sheets print the credits of what they show
/// ([sheetCredits], under the base map's own credit), the report lists them all (the "sources" table), and
/// Help → Terms of the data explains each source. Pure Dart.
library;

import '../model/entities.dart';
import '../model/project.dart';
import 'climate_online.dart';
import 'dem_online.dart';
import 'forecast_online.dart'; // 1.7.0 FCT

/// What kind of data a credit is for (1.7.0 FCT: the weather forecast of the irrigation forecast).
enum DataKind { elevation, climate, baseMap, search, forecast }

/// What the free use of a source allows.
enum DataUse {
  /// Any use, professional and commercial work included, with the credit.
  any,

  /// Non-commercial use only: professional work needs the provider's paid plan (a key) or another source.
  nonCommercial,

  /// Light use only: no heavy or bulk use (a service run by volunteers or for testing).
  light,

  /// As the terms of the map provider say (View → Base map → Terms of the maps).
  provider,
}

/// One source of third-party data in a project.
class DataCredit {
  const DataCredit(this.kind, this.source, this.credit, this.use);
  final DataKind kind;

  /// Name of the source, e.g. "NASA POWER".
  final String source;

  /// The credit line the source asks for, as it asks for it (never translated).
  final String credit;
  final DataUse use;
}

/// A source the app can reach, for Help → Terms of the data: its id (the text of its terms is `terms.src.<id>`),
/// name, credit, the page of its terms and what its free use allows.
class DataSource {
  const DataSource(this.id, this.name, this.kind, this.credit, this.url, this.use);
  final String id;
  final String name;
  final DataKind kind;
  final String credit;
  final String url;
  final DataUse use;
}

/// The sources of elevation, climate, address search and weather forecast (the base maps have terms of their own:
/// View → Base map → Terms of the maps).
final List<DataSource> dataSources = [
  DataSource('terrainTiles', 'Terrain Tiles (AWS Open Data)', DataKind.elevation, DemSource.terrainTiles.attribution, 'https://registry.opendata.aws/terrain-tiles/', DataUse.any),
  DataSource('openMeteoDem', 'Open-Meteo Elevation API', DataKind.elevation, DemSource.openMeteo.attribution, 'https://open-meteo.com/en/terms', DataUse.nonCommercial),
  DataSource('openTopoData', 'OpenTopoData', DataKind.elevation, DemSource.openTopoSrtm.attribution, 'https://www.opentopodata.org/', DataUse.light),
  DataSource('nasaPower', 'NASA POWER', DataKind.climate, ClimateSource.nasaPower.attribution, 'https://power.larc.nasa.gov/docs/referencing/', DataUse.any),
  DataSource('openMeteo', 'Open-Meteo Historical Weather API', DataKind.climate, ClimateSource.openMeteo.attribution, 'https://open-meteo.com/en/terms', DataUse.nonCommercial),
  const DataSource('nominatim', 'Nominatim (OpenStreetMap)', DataKind.search, '© OpenStreetMap contributors', 'https://operations.osmfoundation.org/policies/nominatim/', DataUse.light),
  // 1.7.0 FCT: the weather forecast of Design → Agronomy → Irrigation forecast
  DataSource('metNorway', 'MET Norway Locationforecast', DataKind.forecast, ForecastSource.metNorway.attribution, ForecastSource.metNorway.termsUrl, DataUse.any),
  DataSource('openMeteoForecast', 'Open-Meteo Forecast API', DataKind.forecast, ForecastSource.openMeteo.attribution, ForecastSource.openMeteo.termsUrl, DataUse.nonCommercial),
];

/// The use the free service of a climate source allows.
DataUse climateUse(ClimateSource s) => s == ClimateSource.openMeteo ? DataUse.nonCommercial : DataUse.any;

/// The use the free service of an elevation source allows.
DataUse demUse(DemSource s) => switch (s) {
  DemSource.terrainTiles => DataUse.any,
  DemSource.openMeteo => DataUse.nonCommercial,
  DemSource.openTopoSrtm || DemSource.openTopoAster => DataUse.light,
};

/// How a base map picture kept in the project says where it came from: its `source` is this mark and the credit of
/// the map (lib/app/io/field_map.dart writes it).
const baseMapPictureMark = 'basemap:';

/// The credit of the base map picture [e], or null when it is another picture (a photo, a scanned plan).
String? baseMapPictureCredit(ImageEntity e) => e.source.startsWith(baseMapPictureMark) ? e.source.substring(baseMapPictureMark.length).trim() : null;

DemSource? _demSource(String name) {
  for (final s in DemSource.values) {
    if (s.name == name) return s;
  }
  return null;
}

ClimateSource? _climateSource(String name) {
  for (final s in ClimateSource.values) {
    if (s.name == name) return s;
  }
  return null;
}

/// The third-party data [p] carries, each source once: the online elevation models of its spot heights, the climate
/// downloaded for the site (typed or station values have no credit), the base map pictures kept for the field.
List<DataCredit> projectDataCredits(Project p) {
  final out = <DataCredit>[];
  final seen = <String>{};
  void add(DataCredit c) {
    if (c.credit.isNotEmpty && seen.add('${c.kind.name}|${c.credit}')) out.add(c);
  }

  for (final e in p.entities) {
    if (e is SpotHeightEntity && e.isDem) {
      final s = _demSource(e.name.substring(4).trim());
      if (s != null) add(DataCredit(DataKind.elevation, s.label, s.attribution, demUse(s)));
    }
  }
  final climate = p.climate;
  if (climate != null && climate.attribution.isNotEmpty) {
    final s = _climateSource(climate.source);
    final when = climate.retrieved.isEmpty ? '' : ' (${climate.retrieved})';
    add(DataCredit(DataKind.climate, s == null ? climate.source : _climateName(s), '${climate.attribution}$when', s == null ? DataUse.provider : climateUse(s)));
  }
  for (final e in p.entities) {
    if (e is ImageEntity) {
      final credit = baseMapPictureCredit(e);
      if (credit != null) add(DataCredit(DataKind.baseMap, e.name, credit, DataUse.provider));
    }
  }
  return out;
}

String _climateName(ClimateSource s) => switch (s) {
  ClimateSource.openMeteo => 'Open-Meteo',
  ClimateSource.nasaPower => 'NASA POWER',
};

/// The credits a sheet of [p] prints, one per line: [baseMap] (the credit of the base map under the drawing, when
/// there is one), then those of the base map pictures and of the online elevation on the layers it shows.
String sheetCredits(Project p, String baseMap) {
  final visible = {for (final l in p.layers) l.name: l.visible};
  bool shown(String layer) => visible[layer] ?? true;
  final lines = <String>[if (baseMap.trim().isNotEmpty) baseMap.trim()];
  void add(String credit) {
    if (credit.isNotEmpty && !lines.contains(credit)) lines.add(credit);
  }

  var terrain = false;
  for (final e in p.entities) {
    if (!shown(e.layer)) continue;
    if (e is ImageEntity) {
      final credit = baseMapPictureCredit(e);
      if (credit != null) add(credit);
    } else if ((e is SpotHeightEntity && e.isDem) || (e is ContourEntity && e.derived)) {
      terrain = true;
    }
  }
  if (terrain) {
    for (final c in projectDataCredits(p)) {
      if (c.kind == DataKind.elevation) add(c.credit);
    }
  }
  return lines.join('\n');
}
