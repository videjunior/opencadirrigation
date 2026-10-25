/// Site and data tools of the AI assistant: finding the site from an
/// address (OpenStreetMap Nominatim, one search at a time, at most one a
/// second, with its attribution), the georeference, the base map, the
/// online terrain and climate through the app's own downloads, and the
/// import of drawings and GIS files the user attached.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../../core/ai/agent_loop.dart';
import '../../core/io/climate_online.dart';
import '../../core/io/dem_online.dart';
import '../../core/io/project_export.dart' show GeoReferenceMissing;
import '../../core/units.dart';
import '../io/http.dart';
import '../state/controller.dart';
import '../version.dart';
import 'agent_tools.dart';

/// GET [url] with [headers], the body as text (tests replace it).
typedef SiteFetch = Future<String> Function(Uri url, Map<String, String> headers);

/// How find_site reaches Nominatim.
SiteFetch siteFetch = (url, headers) => httpRequest('GET', url.toString(), headers: headers);

/// Nominatim's terms: one request a second at most, the application named,
/// the results cached, the data attributed.
const nominatimAttribution = 'Search results © OpenStreetMap contributors (ODbL), by Nominatim.';
const _nominatimGap = Duration(milliseconds: 1100);
DateTime? _lastSearch;
final Map<String, String> _searchCache = {};

/// Searches allowed per conversation (a user's lookups, not bulk geocoding).
const maxSiteSearches = 8;

/// Base maps the model may choose (those that need no key or template).
const _maps = {
  'none': BaseMap.none,
  'streets': BaseMap.streets,
  'topo': BaseMap.topo,
  'carto': BaseMap.carto,
  'satellite': BaseMap.satellite,
  'esri_streets': BaseMap.esriStreets,
  'esri_topo': BaseMap.esriTopo,
};

List<AgentTool> siteTools(AgentToolbox b) {
  final c = b.c;
  final t = b.t;
  var searches = 0;
  bool stopped() => b.host?.stopped ?? false;
  return [
    FnTool(
      name: 'find_site',
      effect: ToolEffect.network,
      description: 'Finds a place from an address or place name with OpenStreetMap Nominatim (the query text goes to nominatim.openstreetmap.org; the user approves it unless changes apply automatically). Returns up to 5 matches: name, latitude, longitude (WGS84 degrees) and bounding box. Then call set_site with the right match. Coordinates the user gives need no search. A few searches per conversation; never for lists of places.',
      inputSchema: obj(
        {
          'query': str('Address or place, as precise as known, e.g. "Fazenda Boa Vista, Patos de Minas, MG, Brazil".'),
          'country_codes': str('Optional ISO 3166-1 alpha-2 codes, comma separated, e.g. "br".'),
        },
        required: ['query'],
      ),
      summary: (i) => t('ai.do.findSite', {'n': AgentToolbox.short('${i['query']}', 60)}),
      handler: (i) async {
        final a = ToolArgs(i);
        final q = a.str('query', required: true)!;
        if (++searches > maxSiteSearches) throw ToolInputError('Search limit of this conversation reached ($maxSiteSearches): ask the user for the coordinates.');
        final url = Uri.https('nominatim.openstreetmap.org', '/search', {
          'q': q,
          'format': 'jsonv2',
          'limit': '5',
          'accept-language': c.lang,
          if ((a.str('country_codes') ?? '').isNotEmpty) 'countrycodes': a.str('country_codes')!.toLowerCase(),
        });
        var body = _searchCache[url.toString()];
        if (body == null) {
          final last = _lastSearch;
          if (last != null) {
            final wait = _nominatimGap - DateTime.now().difference(last);
            if (wait > Duration.zero) await Future<void>.delayed(wait);
          }
          _lastSearch = DateTime.now();
          try {
            // browsers send the page as the referrer; elsewhere the application names itself
            body = await siteFetch(url, kIsWeb ? const {} : {'User-Agent': 'OpenCADIrrigation/$appVersion (+https://opencadirrigation.com)'});
          } on HttpStatusException catch (e) {
            throw ToolInputError('The search service answered ${e.status}${e.status == 429 ? ' (too many searches: wait, or ask the user for coordinates)' : ''}.');
          } catch (e) {
            throw ToolInputError('The search service could not be reached ($e). Ask the user for the coordinates.');
          }
          _searchCache[url.toString()] = body;
        }
        final Object? j;
        try {
          j = jsonDecode(body);
        } catch (_) {
          throw ToolInputError('The search service gave no usable answer.');
        }
        final hits = [
          if (j is List)
            for (final h in j)
              if (h is Map) h,
        ];
        if (hits.isEmpty) return ToolOutput('No place found for "$q". Try a simpler query (town, region, country) or ask the user for coordinates.\n$nominatimAttribution');
        final lines = [
          for (final h in hits)
            '${h['display_name']} | lat ${h['lat']}, lon ${h['lon']} | ${h['category'] ?? h['class'] ?? ''}/${h['type'] ?? ''}${h['boundingbox'] is List ? ' | bbox lat ${(h['boundingbox'] as List)[0]}…${(h['boundingbox'] as List)[1]}, lon ${(h['boundingbox'] as List)[2]}…${(h['boundingbox'] as List)[3]}' : ''}',
        ];
        return ToolOutput('${lines.join('\n')}\n$nominatimAttribution');
      },
    ),
    FnTool(
      name: 'set_site',
      effect: ToolEffect.write,
      description: 'Georeferences the project: the drawing origin (0, 0) goes to the given WGS84 latitude/longitude (a UTM-style local grid around it); the base map, the online terrain and the climate need it. When the drawing is empty the view frames a square around the origin. Changing an existing georeference moves the drawing on the map, so it is always confirmed then. One undo step with the rest of the turn.',
      inputSchema: obj(
        {
          'latitude': num_('Degrees, −90…90 (south negative).'),
          'longitude': num_('Degrees, −180…180 (west negative).'),
          'view_size_m': num_('Side of the square the view frames on an empty drawing (default 500).'),
        },
        required: ['latitude', 'longitude'],
      ),
      confirm: (_) => c.project.meta.georef != null,
      summary: (i) => t('ai.do.setSite', {'lat': '${i['latitude']}', 'lon': '${i['longitude']}'}),
      handler: (i) async {
        final a = ToolArgs(i);
        final lat = a.number('latitude', min: -90, max: 90, required: true)!;
        final lon = a.number('longitude', min: -180, max: 180, required: true)!;
        final size = a.number('view_size_m', min: 20, max: 20000) ?? 500;
        if (c.busy) throw ToolInputError('A design is running; wait until it finishes.');
        c.setGeoreferenceAt(lat, lon, viewSizeM: size);
        final g = c.project.meta.georef!;
        return ToolOutput('Georeferenced: origin (0, 0) at ${fmt(lat, 6)}, ${fmt(lon, 6)} (${g.crsName}). Coordinates stay in metres from that origin, x east and y north.');
      },
    ),
    FnTool(
      name: 'set_base_map',
      description: 'Changes the base map under the drawing on the user\'s screen (a view setting, not part of the project): "satellite" for aerial imagery to trace fields, "streets"/"topo"/"carto"/"esri_streets"/"esri_topo", or "none". It needs a georeference (set_site). Map pictures for yourself come from view_snapshot without changing the user\'s choice.',
      inputSchema: obj({'map': str(null, _maps.keys.toList())}, required: ['map']),
      summary: (i) => t('ai.do.baseMap', {'n': '${i['map']}'}),
      handler: (i) async {
        final m = _maps[ToolArgs(i).str('map', required: true)]!;
        c.baseMap = m;
        c.refresh();
        return ToolOutput(
          m == BaseMap.none ? 'Base map off.' : (c.project.meta.georef == null ? 'Base map set to ${m.name}, but the project has no georeference yet: call set_site.' : 'Base map: ${m.name}.'),
        );
      },
    ),
    FnTool(
      name: 'download_terrain',
      effect: ToolEffect.write,
      description: 'Downloads ground elevations for the drawing (or the view when the drawing is empty) from an online elevation model through the app\'s own download, and adds them as spot heights on the DEM layer (one undo step; it sends the area\'s coordinates to the elevation service). "terrainTiles" (default: 30 m SRTM tiles) or "openMeteo" (90 m Copernicus). Needs a georeference. Earlier downloaded points are replaced; the user\'s own contours and spot heights stay unless replace_own is true (do that only when the user agrees: they may use another datum). Reports the elevation range.',
      inputSchema: obj({
        'source': str('Default "terrainTiles".', ['terrainTiles', 'openMeteo']),
        'spacing_m': num_('Grid spacing, 10–200 m (default 25).'),
        'replace_own': bool_('Also remove the user\'s own contours and spot heights (default false).'),
      }),
      summary: (i) => t('ai.do.terrain', {'n': '${i['source'] ?? 'terrainTiles'}'}),
      handler: (i) async {
        final a = ToolArgs(i);
        if (c.project.meta.georef == null) throw ToolInputError('The project has no georeference: call set_site first.');
        if (c.busy) throw ToolInputError('A design is running; wait until it finishes.');
        final src = a.str('source') == 'openMeteo' ? DemSource.openMeteo : DemSource.terrainTiles;
        try {
          final r = await c.importOnlineDem(src, spacing: a.number('spacing_m', min: 10, max: 200) ?? 25, replaceExisting: a.flag('replace_own') ?? false, cancelled: stopped);
          if (r.count == 0) return ToolOutput.error('No elevation came back (offline, or no data there).');
          return ToolOutput(
            '${r.count} spot heights from ${src.label}${r.noData > 0 ? ' (${r.noData} points without data)' : ''}; ground ${fmt(r.range.$1, 1)} … ${fmt(r.range.$2, 1)} m.${r.datumMismatch ? ' The user\'s own heights sit on another datum (range ${fmt(r.ownRange.$1, 1)} … ${fmt(r.ownRange.$2, 1)} m): ask before mixing them (replace_own).' : ''}',
          );
        } on GeoReferenceMissing {
          throw ToolInputError('The project has no georeference: call set_site first.');
        }
      },
    ),
    FnTool(
      name: 'download_climate',
      effect: ToolEffect.write,
      description: 'Downloads daily weather at the site for the last years from an online archive through the app\'s own download and stores its monthly normals (reference evapotranspiration ETo, rain, dependable rain, solar radiation) in the project, where the irrigation requirement and the agronomy reports use them (one undo step; it sends the site\'s coordinates to the service). Needs a georeference.',
      inputSchema: obj({
        'source': str('Default "openMeteo".', ['openMeteo', 'nasaPower']),
        'years': int_('Whole years to average, 1–30 (default 10).'),
      }),
      summary: (i) => t('ai.do.climate', {'n': '${i['source'] ?? 'openMeteo'}'}),
      handler: (i) async {
        final a = ToolArgs(i);
        if (c.busy) throw ToolInputError('A design is running; wait until it finishes.');
        final src = a.str('source') == 'nasaPower' ? ClimateSource.nasaPower : ClimateSource.openMeteo;
        try {
          final sc = await c.downloadClimate(src, years: a.integer('years', min: 1, max: 30) ?? 10, cancelled: stopped);
          String row(List<double> v) => [for (final x in v) fmt(x, 1)].join(' ');
          return ToolOutput(
            'Climate ${sc.firstYear}–${sc.lastYear} from ${src.name} at ${fmt(sc.latitudeDeg, 4)}, ${fmt(sc.longitudeDeg, 4)} (${sc.attribution}).\nETo mm/day, Jan…Dec: ${row(sc.etoMmDay)}\nRain mm/month: ${row(sc.rainMm)}',
          );
        } on ClimateException catch (e) {
          throw ToolInputError(
            e.code == 'climate_no_site' ? 'The project has no georeference: call set_site first.' : 'The climate download failed (${e.code}${(e.detail ?? '').isEmpty ? '' : ': ${e.detail}'}).',
          );
        }
      },
    ),
    FnTool(
      name: 'import_attachment',
      effect: ToolEffect.write,
      description: 'Imports a file the user attached to the conversation into the project, as File → Import does: DXF, DWG, DGN, KML/KMZ, shapefile (.shp or a .zip), GeoJSON, GPX, LandXML, IFC, EPANET .inp, LAS point clouds, GeoTIFF elevations, CSV points, PDF drawings (page 1 at 1:100). One undo step. Check the result with list_entities or view_snapshot.',
      inputSchema: obj({'name': str('File name as attached.')}, required: ['name']),
      summary: (i) => t('ai.do.import', {'n': '${i['name']}'}),
      handler: (i) async {
        final files = b.host?.files ?? const {};
        final name = ToolArgs(i).str('name', required: true)!;
        final bytes = files[name] ?? files.entries.where((e) => e.key.toLowerCase() == name.toLowerCase()).firstOrNull?.value;
        if (bytes == null) throw ToolInputError(files.isEmpty ? 'No file was attached in this conversation.' : 'No attached file "$name". Attached: ${files.keys.join(', ')}.');
        if (c.busy) throw ToolInputError('A design is running; wait until it finishes.');
        try {
          final what = c.importFile(name, bytes);
          return ToolOutput('Imported $name: $what');
        } on FormatException catch (e) {
          throw ToolInputError('The file could not be imported (${e.message}).');
        }
      },
    ),
  ];
}
