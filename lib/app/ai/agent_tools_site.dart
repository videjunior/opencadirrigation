/// Site and data tools of the AI assistant: finding the site from an
/// address (OpenStreetMap Nominatim, one search at a time, at most one a
/// second, with its attribution), the georeference, the base map, the
/// online terrain and climate through the app's own downloads, and the
/// import of drawings and GIS files the user attached.
library;

import '../../core/ai/agent_loop.dart';
import '../../core/io/climate_online.dart';
import '../../core/io/dem_online.dart';
import '../../core/io/project_export.dart' show GeoReferenceMissing;
import '../../core/model/geometry.dart';
import '../../core/units.dart';
import '../io/place_search.dart';
import '../state/controller.dart';
import 'agent_tools.dart';

export '../io/place_search.dart' show SiteFetch, siteFetch, nominatimAttribution;

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
        final List<PlaceHit> hits;
        try {
          hits = await searchPlaces(q, lang: c.lang, countryCodes: a.str('country_codes'));
        } on PlaceSearchError catch (e) {
          throw ToolInputError(e.status == null ? '${e.message} Ask the user for the coordinates.' : (e.status == 429 ? '${e.message} Wait, or ask the user for coordinates.' : e.message));
        }
        if (hits.isEmpty) return ToolOutput('No place found for "$q". Try a simpler query (town, region, country) or ask the user for coordinates.\n$nominatimAttribution');
        final lines = [
          for (final h in hits)
            '${h.name} | lat ${h.lat}, lon ${h.lon} | ${h.kind}${h.bbox != null ? ' | bbox lat ${h.bbox![0]}…${h.bbox![1]}, lon ${h.bbox![2]}…${h.bbox![3]}' : ''}',
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
      description: 'Imports a file the user attached to the conversation into the project, as File → Import does: DXF, DWG, DGN, KML/KMZ, shapefile (.shp or a .zip), GeoJSON, GPX, LandXML, EPANET .inp, LAS point clouds, GeoTIFF elevations, CSV points, images, PDF drawings (page 1 at 1:100; import_pdf_attachment sets the page and the scale). One undo step; the items of a CAD drawing become the selection. Returns what came in and its extent; a CAD drawing (DXF, DWG, DGN, PDF) keeps its own coordinates, so when it is not on the map yet the result says how to place it (set_georeference "utm" for UTM coordinates, else set_site and align_entities onto two points of the satellite picture). Project files (.oci.json) open with open_attached_project; IFC is written by the program, not read.',
      inputSchema: obj({'name': str('File name as attached.')}, required: ['name']),
      summary: (i) => t('ai.do.import', {'n': '${i['name']}'}),
      handler: (i) async {
        final files = b.host?.files ?? const {};
        final name = ToolArgs(i).str('name', required: true)!;
        final bytes = files[name] ?? files.entries.where((e) => e.key.toLowerCase() == name.toLowerCase()).firstOrNull?.value;
        if (bytes == null) throw ToolInputError(files.isEmpty ? 'No file was attached in this conversation.' : 'No attached file "$name". Attached: ${files.keys.join(', ')}.');
        final lower = name.toLowerCase();
        if (lower.endsWith('.ifc')) {
          throw ToolInputError('"$name" is an IFC model: the program writes IFC (export_file "ifc") but does not read it. Ask the user for the plan as DXF, DWG or PDF instead.');
        }
        if (lower.endsWith('.oci.json') || lower.endsWith('.oci')) {
          throw ToolInputError('"$name" is a project file, not a drawing: run_operation open_attached_project opens it in a new tab.');
        }
        if (lower.endsWith('.oci.cat')) throw ToolInputError('"$name" is a catalogue: run_operation import_catalog_attachment adds its items to the project catalogue.');
        if (c.busy) throw ToolInputError('A design is running; wait until it finishes.');
        final hadGeoref = c.project.meta.georef != null;
        final before = {for (final e in c.project.entities) e.id};
        final String what;
        try {
          what = c.importFile(name, bytes);
        } catch (e) {
          throw ToolInputError('The file could not be imported (${c.describeError(e)}).');
        }
        final added = [
          for (final e in c.project.entities)
            if (!before.contains(e.id)) e,
        ];
        if (added.isEmpty) {
          return ToolOutput.error(
            'Nothing came in from "$name" ($what). import_attachment reads DXF, DWG, DGN, KML/KMZ, shapefiles, GeoJSON, GPX, LandXML, EPANET .inp, LAS, GeoTIFF, CSV points, images and PDF drawings: ask the user for the plan in one of them.',
          );
        }
        final box = added.fold(Bounds.empty, (Bounds x, e) => x.union(e.bounds));
        final cad = isCadFile(lower);
        final placement = importPlacementText(b, box, hadGeoref: hadGeoref, cad: cad);
        // a drawing to place comes in selected, for align_entities or transform_entities
        final select = cad || placement.isNotEmpty;
        if (select) c.select(added.map((e) => e.id));
        return ToolOutput(
          'Imported $name: $what\n${added.length} item${added.length == 1 ? '' : 's'}${select ? ', now selected' : ''}; extent ${AgentToolbox.box(box)} (${fmt(box.width, 0)} × ${fmt(box.height, 0)} m).${placement.isEmpty ? '' : '\n$placement'}',
        );
      },
    ),
  ];
}

/// Whether an import of [lowerName] is a CAD drawing, which keeps its own
/// coordinates (GIS files and georeferenced rasters are placed by their
/// coordinate system).
bool isCadFile(String lowerName) {
  const placed = ['.kml', '.kmz', '.shp', '.zip', '.geojson', '.json', '.gpx', '.xml', '.landxml', '.csv', '.txt', '.xyz', '.pnezd', '.pts', '.las', '.laz', '.tif', '.tiff', '.inp', '.jpg', '.jpeg', '.png'];
  return !placed.any(lowerName.endsWith);
}

/// Whether [box] looks like UTM coordinates: eastings 100–900 km, northings
/// 0–10 000 km, over a site-sized extent.
bool utmLike(Bounds box) => !box.isEmpty && box.minX >= 1e5 && box.maxX <= 9e5 && box.minY >= 0 && box.maxY <= 1e7 && box.width < 2e5 && box.height < 2e5;

/// Imported items further than this from the georeference origin are off
/// the site (m).
const farFromOrigin = 20000.0;

/// How the items an import added over [box] reach their place on the map,
/// for the model: '' when the file placed them (a GIS file read in its
/// coordinate system). [hadGeoref]: the project was georeferenced before
/// the import; [cad]: a CAD drawing (DXF, DWG, DGN, PDF), which keeps its
/// own coordinates.
String importPlacementText(AgentToolbox b, Bounds box, {required bool hadGeoref, required bool cad}) {
  if (box.isEmpty) return '';
  final g = b.p.meta.georef;
  String km(double m) => fmt(m / 1000, m < 1e4 ? 1 : 0);
  const align =
      'pick two points you recognise both in the drawing (get_entity gives its vertices) and on a satellite picture of the site (view_snapshot {region "bbox", bbox around the site, base_map "satellite"}; image_to_world gives their positions), then run_operation align_entities {selected true, from_a, to_a, from_b, to_b, keep_scale true} moves the imported items there (they are selected; keep_scale false for a plan that is not to scale)';
  if (g == null) {
    if (utmLike(box)) {
      return 'The project has no georeference and these coordinates look like UTM (eastings ${km(box.minX)}–${km(box.maxX)} km, northings ${km(box.minY)}–${km(box.maxY)} km). Next: run_operation set_georeference {mode "utm", zone, north, easting_m 0, northing_m 0}: the drawing\'s coordinates are then read as UTM coordinates as they are, and nothing moves. The zone (1–60) and the hemisphere come from the drawing\'s title block or notes (e.g. "UTM 23S") or from the user, else from the site: zone = floor((longitude + 180) / 6) + 1, north true north of the equator (find_site gives the latitude and longitude). Then view_snapshot {region "drawing", base_map "satellite"} to check that it lies on the site; do not call set_site afterwards (it would replace that georeference).';
    }
    return 'The project has no georeference, so the drawing keeps its own coordinates and shows on no map. Next: find_site and set_site at the site (the origin [0, 0] goes there; nothing moves)${box.center.length > farFromOrigin ? ', transform_entities {selected true, operation "move", dx ${fmt(-box.center.x, 0)}, dy ${fmt(-box.center.y, 0)}} brings the drawing beside the origin' : ''}; then $align.';
  }
  if (!hadGeoref && !cad) return '';
  final off = box.center.length;
  if (off > farFromOrigin) {
    if (utmLike(box)) {
      final d = (box.center - Pt(g.originEasting, g.originNorthing)).length;
      if (d < 1e5) {
        return 'These items lie ${km(off)} km from the origin [0, 0]: their coordinates look like UTM coordinates of the project\'s zone (${g.crsName}), whose origin is UTM E ${fmt(g.originEasting, 0)}, N ${fmt(g.originNorthing, 0)}. Next: transform_entities {selected true, operation "move", dx ${fmt(-g.originEasting, 2)}, dy ${fmt(-g.originNorthing, 2)}} puts them in place (they are selected); then view_snapshot {region "drawing", base_map "satellite"} to check. If the drawing is in another zone or system, ask the user which.';
      }
      return 'These items lie ${km(off)} km from the origin [0, 0]: their coordinates look like UTM, but ${km(d)} km away from the site in the project\'s zone (${g.crsName}), so the drawing is in another zone or system: ask the user which (a title block often says, e.g. "UTM 22S"). Or $align.';
    }
    return 'These items lie ${km(off)} km from the origin [0, 0] (the drawing\'s own coordinate system). Next: transform_entities {selected true, operation "move", dx ${fmt(-box.center.x, 0)}, dy ${fmt(-box.center.y, 0)}} brings them beside the site; then $align.';
  }
  if (!cad) return '';
  return 'A CAD drawing keeps its own coordinates: it lies on the site only if it was drawn from this origin. Check with view_snapshot {region "drawing", base_map "satellite"}; if it is off, $align.';
}
