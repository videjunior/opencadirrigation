/// Terrain, site and imports for the AI assistant (groups "terrain",
/// "site" and "import"): contour generation, the terrain model and its
/// slopes, profiles, the user's own elevation data, the online elevation
/// download with every option of its dialog, the georeference (lat/lon or
/// UTM, or removed), image placement, vegetation detection with every
/// option of its dialog, and the PDF import with its page and scale.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../../core/ai/agent_loop.dart';
import '../../core/design/vegetation.dart';
import '../../core/io/dem_online.dart';
import '../../core/io/geo.dart';
import '../../core/io/pdf_import.dart';
import '../../core/io/pdf_reader.dart';
import '../../core/io/project_export.dart' show GeoReferenceMissing;
import '../../core/model/entities.dart';
import '../../core/model/geometry.dart';
import 'agent_tools.dart';
import 'agent_tools_design.dart' show aerialMapOf, noAerialText, tilesOf;
import 'ops_cad_common.dart';
import 'view_snapshot.dart' show fetchBaseMap;

List<AgentTool> terrainOperations(AgentToolbox b) {
  final c = b.c;
  final t = b.t;
  bool stopped() => b.host?.stopped ?? false;
  final demSources = [
    for (final s in DemSource.values)
      if (s.browserOk || !kIsWeb) s.name,
  ];
  return [
    cadOp(
      b,
      group: 'terrain',
      name: 'generate_contours',
      effect: ToolEffect.write,
      description: 'Design → Terrain → Generate contours: draws contour lines every interval_m from the terrain model (contours, spot heights, breaklines, downloaded elevations) as generated contours ("DTM"), which are drawn and exported but do not feed the model back. replace_previous removes the contours generated before. One undo step; returns how many and the elevation range. Needs terrain data.',
      schema: obj({
        'interval_m': num_('Contour interval (m), above 0 (default: 5 m over 20 m of relief, 1 m over 5 m, else 0.5 m).'),
        'replace_previous': bool_('Remove earlier generated contours (default true).'),
      }),
      args: (i) => {'n': '${i['interval_m'] ?? ''}'},
      run: (a, i) async {
        cadNotBusy(b);
        final terrain = b.p.buildTerrain();
        if (terrain.isEmpty) {
          throw ToolInputError(
            'The drawing has no terrain data (contours, spot heights, breaklines or downloaded elevations). Next: ${b.p.meta.georef == null ? 'set_site, then download_terrain' : 'download_terrain'}, or import_attachment of the user\'s survey.',
          );
        }
        final (lo, hi) = terrain.elevationRange;
        final interval = a.number('interval_m', min: 0.01, max: 1000) ?? ((hi - lo) > 20 ? 5.0 : ((hi - lo) > 5 ? 1.0 : 0.5));
        if ((hi - lo) / interval > 2000) throw ToolInputError('That interval makes ${((hi - lo) / interval).round()} contours: choose a larger one.');
        final n = c.generateContours(interval, replacePrevious: a.flag('replace_previous') ?? true);
        return ToolOutput('$n contours every ${cadN(interval, 2)} m generated (ground ${cadN(lo, 1)} … ${cadN(hi, 1)} m).');
      },
    ),
    cadOp(
      b,
      group: 'terrain',
      name: 'show_profile',
      description: 'Shows the user the elevation profile of a path, as the Profile tool (PR) does: the path is drawn on the drawing and the Profile report tab opens with its chart (a view change; clear_profile removes it). Returns the length, the ground at both ends and the lowest and highest points; terrain_profile gives every number along a line without showing it.',
      schema: obj({'pts': pointsWith('The path (≥2 points, m).', minItems: 2, maxItems: 500), 'id': str('Or an item whose line to follow (a pipe, lateral, polyline…; id or name).')}),
      run: (a, i) async {
        List<Pt>? pts = a.points('pts', min: 2, max: 500);
        final ref = a.str('id');
        if (pts == null && ref != null) {
          final e = b.find(ref);
          final line = e.linearPoints;
          if (line == null || line.length < 2) throw ToolInputError('${e.id} is not a line: give pts instead.');
          pts = e.isClosedShape ? [...line, line.first] : line;
        }
        if (pts == null) throw ToolInputError('Give "pts" (2–500 points, m) or the "id" of a line item.');
        if (b.p.buildTerrain().isEmpty) throw ToolInputError('The drawing has no terrain data: every elevation is 0 m. Next: ${b.p.meta.georef == null ? 'set_site, then download_terrain' : 'download_terrain'}, or import_attachment of the user\'s survey.');
        final samples = c.profileAlong(pts);
        if (samples.isEmpty) throw ToolInputError('The path has no length.');
        c.setProfilePath(pts);
        var lo = samples.first, hi = samples.first;
        for (final s in samples) {
          if (s.$2 < lo.$2) lo = s;
          if (s.$2 > hi.$2) hi = s;
        }
        return ToolOutput(
          'Profile ${cadN(samples.last.$1, 1)} m: from ${cadN(samples.first.$2, 2)} m to ${cadN(samples.last.$2, 2)} m; lowest ${cadN(lo.$2, 2)} m at ${cadN(lo.$1, 1)} m, highest ${cadN(hi.$2, 2)} m at ${cadN(hi.$1, 1)} m. The path is drawn and the Profile tab is open for the user.',
        );
      },
    ),
    cadOp(
      b,
      group: 'terrain',
      name: 'clear_profile',
      description: 'Design → Terrain → Clear profile: removes the profile path from the drawing (a view change).',
      schema: obj({}),
      run: (a, i) async {
        if (c.profilePath == null) return const ToolOutput('No profile is shown.');
        c.clearProfile();
        return const ToolOutput('Profile removed from the drawing.');
      },
    ),
    cadOp(
      b,
      group: 'terrain',
      name: 'remove_own_terrain_data',
      effect: ToolEffect.write,
      confirm: (_) => true,
      description: 'Removes the user\'s own elevation data — surveyed or typed spot heights and source contours, e.g. example data on another datum than a download — keeping the downloaded elevation points and the generated contours, as the online elevation dialog offers when the datums do not match. Always confirmed by the user. One undo step.',
      schema: obj({}),
      run: (a, i) async {
        cadNotBusy(b);
        final own = c.ownTerrainData();
        if (!own.isNotEmpty) return const ToolOutput('There is no own elevation data to remove.');
        final n = c.removeOwnTerrainData();
        return ToolOutput('Removed $n items (${own.spots} spot heights, ${own.contours} contours).');
      },
    ),
    cadOp(
      b,
      group: 'terrain',
      name: 'download_elevations',
      effect: ToolEffect.write,
      description:
          'Design → Terrain → Online elevations with every option of its dialog: a grid of ground elevations over the drawing (or the view) from a public elevation model through the app\'s own download, added as spot heights on the DEM layer (it sends the area\'s coordinates to the service; needs a georeference). Sources: ${demSources.join(', ')} (terrainTiles = 30 m SRTM tiles, the default; openMeteo = 90 m Copernicus). replace_previous drops the points of an earlier download; replace_own also the user\'s own contours and spot heights (only when the user agrees: they may sit on another datum); contours draws contours from the result. One undo step; reports the elevation range and a datum mismatch. download_terrain is the short form.',
      schema: obj({
        'source': str('Default "terrainTiles".', demSources),
        'spacing_m': num_('Grid spacing, 1–200 m (default 25).'),
        'max_points': int_('Most grid points, 100–20000 (default 5000).'),
        'use_view': bool_('Cover the area on screen instead of the drawing (default: the view when the drawing is empty).'),
        'replace_previous': bool_('Replace an earlier download (default true).'),
        'replace_own': bool_('Also remove the user\'s own elevation data (default false).'),
        'contours': bool_('Draw contours from the result (default: when the terrain had no own data).'),
        'contour_interval_m': num_('Their interval (default: automatic, about 20 contours).'),
      }),
      args: (i) => {'n': '${i['source'] ?? 'terrainTiles'}'},
      run: (a, i) async {
        cadNotBusy(b);
        if (b.p.meta.georef == null) throw ToolInputError('The project has no georeference: call set_site (or set_georeference) first.');
        final src = DemSource.values.byName(a.str('source') ?? 'terrainTiles');
        final replaceOwn = a.flag('replace_own') ?? false;
        final contours = a.flag('contours') ?? (c.terrainIsEmpty || replaceOwn);
        try {
          final r = await c.importOnlineDem(
            src,
            spacing: a.number('spacing_m', min: 1, max: 200) ?? 25,
            useView: a.flag('use_view') ?? b.p.bounds.isEmpty,
            replacePrevious: a.flag('replace_previous') ?? true,
            replaceExisting: replaceOwn,
            maxPoints: a.integer('max_points', min: 100, max: 20000) ?? 5000,
            cancelled: stopped,
          );
          if (r.count == 0) return ToolOutput.error('No elevation came back (offline, no data there, or an empty area).');
          var extra = '';
          if (contours) {
            final interval = a.number('contour_interval_m', min: 0.01, max: 1000) ?? c.autoContourInterval();
            extra = ' ${c.generateContours(interval)} contours every ${cadN(interval, 2)} m drawn.';
          }
          return ToolOutput(
            '${r.count} elevation points from ${src.label}${r.noData > 0 ? ' (${r.noData} without data)' : ''}; ground ${cadN(r.range.$1, 1)} … ${cadN(r.range.$2, 1)} m.$extra${r.datumMismatch ? ' The user\'s own heights sit on another datum (${cadN(r.ownRange.$1, 1)} … ${cadN(r.ownRange.$2, 1)} m): ask the user whether to remove them (remove_own_terrain_data).' : ''}',
          );
        } on GeoReferenceMissing {
          throw ToolInputError('The project has no georeference: call set_site (or set_georeference) first.');
        } on DemCancelled {
          throw ToolInputError('The download was cancelled.');
        }
      },
    ),
    // ------------------------------------------------ site
    cadOp(
      b,
      group: 'site',
      name: 'get_georeference',
      description: 'File → Georeference as it stands: the coordinate system (WGS84 / UTM zone), the UTM easting and northing of the drawing origin [0, 0], its latitude and longitude and those of the centre of the drawing. Without a georeference there is no base map, elevation download, climate or KML.',
      schema: obj({}),
      run: (a, i) async {
        final g = b.p.meta.georef;
        if (g == null) return const ToolOutput('The project has no georeference (set_site or set_georeference sets one).');
        final (lat, lon) = g.toLatLon(0, 0);
        final site = c.siteLatLon;
        return ToolOutput(
          '${g.crsName}: origin [0, 0] = UTM E ${cadN(g.originEasting, 2)} m, N ${cadN(g.originNorthing, 2)} m = lat ${lat.toStringAsFixed(6)}, lon ${lon.toStringAsFixed(6)}${site == null ? '' : '; centre of the drawing at lat ${site.$1.toStringAsFixed(6)}, lon ${site.$2.toStringAsFixed(6)}'}.',
        );
      },
    ),
    cadOp(
      b,
      group: 'site',
      name: 'set_georeference',
      effect: ToolEffect.write,
      confirm: (_) => b.p.meta.georef != null,
      description: 'File → Georeference: places the drawing on the Earth. "latlon": the drawing origin [0, 0] goes to latitude/longitude (WGS84 degrees; a UTM grid around it); "utm": a UTM zone (1–60), hemisphere and the easting/northing (m) of the origin, as a survey gives them; "remove" takes the georeference away. The drawing coordinates do not change. Changing or removing an existing georeference moves the drawing on the map, so the user confirms it. One undo step. set_site does the latlon case and frames an empty drawing.',
      schema: obj(
        {
          'mode': str(null, ['latlon', 'utm', 'remove']),
          'latitude': num_('latlon: degrees, −84…84.'),
          'longitude': num_('latlon: degrees, −180…180.'),
          'zone': int_('utm: zone 1–60.'),
          'north': bool_('utm: northern hemisphere (default false).'),
          'easting_m': num_('utm: easting of the origin (m).'),
          'northing_m': num_('utm: northing of the origin (m).'),
        },
        required: ['mode'],
      ),
      args: (i) => {'n': '${i['mode']}'},
      run: (a, i) async {
        cadNotBusy(b);
        final mode = a.str('mode', required: true)!;
        GeoReference? ref;
        switch (mode) {
          case 'latlon':
            ref = GeoReference.fromLatLonOrigin(a.number('latitude', min: -84, max: 84, required: true)!, a.number('longitude', min: -180, max: 180, required: true)!);
          case 'utm':
            ref = GeoReference(
              zone: a.integer('zone', min: 1, max: 60, required: true)!,
              north: a.flag('north') ?? false,
              originEasting: a.number('easting_m', min: -1e7, max: 1e7, required: true)!,
              originNorthing: a.number('northing_m', min: -1e7, max: 2e7, required: true)!,
            );
          default:
            if (b.p.meta.georef == null) return const ToolOutput('The project had no georeference.');
            ref = null;
        }
        b.change('set_georeference', () {
          b.p.meta.georef = ref;
          return 1;
        }, invalidate: false);
        if (ref == null) return const ToolOutput('Georeference removed: no base map, elevation download, climate or KML until one is set.');
        c.notify(t('msg.georefSet', {'crs': ref.crsName}));
        final (lat, lon) = ref.toLatLon(0, 0);
        return ToolOutput(
          'Georeferenced: ${ref.crsName}, origin [0, 0] at lat ${lat.toStringAsFixed(6)}, lon ${lon.toStringAsFixed(6)} (UTM E ${cadN(ref.originEasting, 2)}, N ${cadN(ref.originNorthing, 2)}).',
        );
      },
    ),
    cadOp(
      b,
      group: 'site',
      name: 'place_image',
      effect: ToolEffect.write,
      description: 'File → Georeference image for a raster image item (an aerial photo, a scanned plan): its bottom-left corner, size in metres (keep_aspect keeps the proportions when only one is given), rotation (degrees counter-clockwise) and opacity, as the dialog and the properties panel set them. One undo step. align_entities fits it by two point pairs instead.',
      schema: obj(
        {
          'id': str('Image item (id or name).'),
          'origin': pointWith('Bottom-left corner (m).'),
          'width_m': num_('Width (m), above 0.'),
          'height_m': num_('Height (m), above 0.'),
          'keep_aspect': bool_('With only width or height: keep the proportions (default true).'),
          'rotation_deg': num_('Rotation about the bottom-left corner.'),
          'opacity': num_('0.05–1.'),
        },
        required: ['id'],
      ),
      args: (i) => {'n': '${i['id']}'},
      run: (a, i) async {
        cadNotBusy(b);
        final e = cadEditable(b, [a.str('id', required: true)!]).first;
        if (e is! ImageEntity) throw ToolInputError('"${e.id}" is not an image (${b.kindOf(e)}).');
        final aspect = e.height / e.width;
        var w = a.number('width_m', min: 0.001, max: 1e7), h = a.number('height_m', min: 0.001, max: 1e7);
        if (a.flag('keep_aspect') ?? true) {
          if (w != null && h == null) h = w * aspect;
          if (h != null && w == null) w = h / aspect;
        }
        b.change('place_image', () {
          e.origin = a.point('origin') ?? e.origin;
          e.width = w ?? e.width;
          e.height = h ?? e.height;
          e.rotationDeg = a.number('rotation_deg') ?? e.rotationDeg;
          e.opacity = a.number('opacity', min: 0.05, max: 1) ?? e.opacity;
          return 1;
        }, invalidate: false);
        return ToolOutput(
          'Image ${e.id}: corner ${cadPt(e.origin)}, ${cadN(e.width, 2)} × ${cadN(e.height, 2)} m, ${cadN(e.rotationDeg, 2)}°, opacity ${cadN(e.opacity, 2)}; corners ${e.corners.map(cadPt).join(' ')}.',
        );
      },
    ),
    cadOp(
      b,
      group: 'site',
      name: 'detect_vegetation',
      effectFor: (i) => i['preview_only'] == true ? ToolEffect.read : ToolEffect.write,
      description: 'Design → Automatic design → Detect vegetation with every option of its dialog: finds the lawns, trees and shrubs on the aerial imagery of the view (or of a bbox) — the user\'s aerial base map when one is on screen, else the satellite imagery, without changing the user\'s base map — or on an aerial image item of the drawing, by image analysis on this device, and adds them as irrigated areas with crop presets plus outlines of the holes to keep dry (buildings, pools, paving). preview_only answers what would be found without adding anything. One undo step. Check the result with view_snapshot. create_vegetation_areas is the short form.',
      schema: obj({
        'image': str('Id of an image item to analyse (default: the aerial imagery of the site, which needs a georeference).'),
        'bbox': bbox,
        'threshold_offset': num_('−0.2 … 0.2 on the automatic vegetation threshold: below 0 takes in paler, drier or shaded green, above 0 only lush green (default 0).'),
        'split': bool_('Tell trees and shrubs from turf (default true).'),
        'turf': bool_('Keep turf (default true).'),
        'trees': bool_('Keep trees and shrubs (default true).'),
        'tree_bias': num_('−0.5 … 0.5: below 0 calls more pixels trees and shrubs, above 0 fewer (default 0).'),
        'min_area_m2': num_('Smallest area kept, m² (default 5).'),
        'min_hole_m2': num_('Holes smaller than this are covered, m² (default 4).'),
        'simplify_m': num_('Outline simplification tolerance, m (default 0.25; 0 keeps every vertex).'),
        'smoothing': int_('Smoothing passes of the outline, 0–10 (default 2).'),
        'clean_m': num_('Specks and gaps narrower than about this go, m (default 0.2).'),
        'canopy_clean_m': num_('The same for the canopy mask, m (default 0.3).'),
        'max_patches': int_('Most areas kept, 1–2000 (default 400).'),
        'exclusions': bool_('Add the holes as outlines to keep dry (default true).'),
        'preview_only': bool_('Report only, add nothing (default false).'),
      }),
      run: (a, i) async {
        final imgRef = a.str('image');
        Uint8ListAndCorners? got;
        var georeferenced = true;
        if (imgRef != null) {
          final e = b.find(imgRef);
          if (e is! ImageEntity || e.data == null) throw ToolInputError('"$imgRef" is not an image item with its pixels.');
          got = (e.data!, e.corners);
          georeferenced = b.p.meta.georef != null;
        } else {
          // the satellite imagery even when the screen shows another map or none
          final map = aerialMapOf(c);
          if (map != null && !a.has('bbox') && c.camera.size.isEmpty) throw ToolInputError('Give "bbox" [minX, minY, maxX, maxY] in metres: there is no view to analyse.');
          got = map == null ? null : await fetchBaseMap(c, a.has('bbox') ? bboxOf(i['bbox']) : null, map: map, tiles: tilesOf(b));
          if (got == null) throw ToolInputError('${noAerialText(c)} Or give "image" (an aerial image item).');
        }
        final o = VegetationOptions(
          thresholdOffset: a.number('threshold_offset', min: -0.2, max: 0.2) ?? 0,
          split: a.flag('split') ?? true,
          keepTurf: a.flag('turf') ?? true,
          keepTrees: a.flag('trees') ?? true,
          treeBias: a.number('tree_bias', min: -0.5, max: 0.5) ?? 0,
          minAreaM2: a.number('min_area_m2', min: 0, max: 1e7) ?? 5,
          minHoleM2: a.number('min_hole_m2', min: 0, max: 1e6) ?? 4,
          simplifyM: a.number('simplify_m', min: 0, max: 100) ?? 0.25,
          smoothing: a.integer('smoothing', min: 0, max: 10) ?? 2,
          cleanM: a.number('clean_m', min: 0, max: 50) ?? 0.2,
          canopyCleanM: a.number('canopy_clean_m', min: 0, max: 50) ?? 0.3,
          maxPatches: a.integer('max_patches', min: 1, max: 2000) ?? 400,
        );
        final image = got;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        final r = detectVegetation(VegetationImage.fromEncoded(image.$1, image.$2), o, georeferenced: georeferenced);
        String areaLine(VegetationPatch p) =>
            '${t('veg.name.${p.cls.name}')} ${cadN(p.area, 0)} m²${p.holes.where((h) => h.exclusion).isEmpty ? '' : ', ${p.holes.where((h) => h.exclusion).length} holes'}${p.touchesEdge ? ', touches the image edge' : ''}';
        final summary =
            '${r.patches.length} areas (${[for (final cls in VegetationClass.values)
              if (r.of(cls).isNotEmpty) '${r.of(cls).length} ${cls.name} ${cadN(r.areaOf(cls), 0)} m²'].join(', ')}), ${r.exclusions.length} exclusions; ${cadN(r.vegetatedFraction * 100, 1)} % of the image vegetated, threshold ${cadN(r.threshold, 3)}${r.dropped > 0 ? ', ${r.dropped} small patches left out' : ''}.${r.messages.isEmpty ? '' : ' Notes: ${r.messages.map((m) => m.code).join(', ')}.'}';
        if (r.patches.isEmpty) throw ToolInputError('No vegetation found (${cadN(r.vegetatedFraction * 100, 1)} % of the image looked vegetated). Try threshold_offset below 0, or another view.');
        if (a.flag('preview_only') ?? false) return ToolOutput('Preview (nothing added): $summary\n${r.patches.take(30).map(areaLine).join('\n')}');
        cadNotBusy(b);
        final made = b.change('detect_vegetation', () {
          final out = vegetationEntities(
            b.p,
            r.patches,
            name: (cls) => t('veg.name.${cls.name}'),
            exclusionName: (area, n) => t('veg.name.exclusion', {'n': '$n', 'a': area}),
            exclusions: a.flag('exclusions') ?? true,
          );
          b.p.entities.addAll(out);
          return out;
        });
        return ToolOutput('$summary\n${cadMade(b, made.map((e) => e.id))}');
      },
    ),
    // ------------------------------------------------ import
    cadOp(
      b,
      group: 'import',
      name: 'import_pdf_attachment',
      effect: ToolEffect.write,
      description: 'File → Import of a PDF plan the user attached, with every option of the PDF import dialog: the page, the scale (1:N of the paper — the scale written on the sheet when found, else 1:100 — or metres per PDF unit), where the bottom-left corner of the page goes and its rotation, what comes in (lines, texts, images) and on which layers (one per PDF layer, per colour, or one). One undo step; the plan is selected (align_entities then fits it to the site). import_attachment imports page 1 at 1:100.',
      schema: obj(
        {
          'name': str('File name as attached.'),
          'page': int_('Page number, from 1 (default 1).'),
          'scale': num_('Paper scale denominator N of 1:N (default: the one on the sheet, else 100).'),
          'metres_per_unit': num_('Drawing metres per PDF unit, instead of "scale".'),
          'origin': pointWith('Where the bottom-left corner of the page goes (m; default [0, 0] in an empty drawing, else centred on the view).'),
          'rotation_deg': num_('Rotation of the plan about the origin.'),
          'vectors': bool_('Lines and shapes (default true).'),
          'texts': bool_('Texts (default true).'),
          'images': bool_('Images (default true).'),
          'use_layers': bool_('One layer per PDF layer (default true).'),
          'hidden_layers': bool_('Also the PDF layers that are off (default false).'),
          'by_colour': bool_('One layer per colour (default false).'),
          'layer': str('Layer of the import (default from the file name).'),
        },
        required: ['name'],
      ),
      args: (i) => {'n': '${i['name']}'},
      run: (a, i) async {
        cadNotBusy(b);
        final files = b.host?.files ?? const {};
        final name = a.str('name', required: true)!;
        final bytes = files[name] ?? files.entries.where((e) => e.key.toLowerCase() == name.toLowerCase()).firstOrNull?.value;
        if (bytes == null) throw ToolInputError(files.isEmpty ? 'No file was attached in this conversation.' : 'No attached file "$name". Attached: ${files.keys.join(', ')}.');
        final PdfReader doc;
        try {
          doc = PdfReader.open(bytes);
        } on Object catch (e) {
          throw ToolInputError('"$name" could not be read as a PDF (${c.describeError(e)}).');
        }
        final pages = doc.pages;
        final page = (a.integer('page', min: 1, max: 100000) ?? 1) - 1;
        if (page >= pages.length) throw ToolInputError('"$name" has ${pages.length} pages.');
        final content = doc.readPage(page, images: false);
        final found = pdfScaleOnSheet(content);
        final k = a.number('metres_per_unit', min: 1e-9, max: 1e6) ?? PdfImportOptions.atScale(a.number('scale', min: 1, max: 1e7) ?? found?.toDouble() ?? 100);
        final info = pages[page];
        final origin =
            a.point('origin') ??
            (b.p.entities.isEmpty || c.camera.size.isEmpty
                ? Pt.zero
                : () {
                    final v = c.camera.visible.center;
                    return Pt((v.x - info.width * k / 2).roundToDouble(), (v.y - info.height * k / 2).roundToDouble());
                  }());
        final images = a.flag('images') ?? true;
        var page0 = content;
        if (images && content.images.isNotEmpty) {
          final withPixels = doc.readPage(page, vectors: false, texts: false, images: true);
          page0 = content.withImages(withPixels.images, withPixels.warnings);
        }
        final o = PdfImportOptions(
          metresPerUnit: k,
          origin: origin,
          rotationDeg: a.number('rotation_deg') ?? 0,
          vectors: a.flag('vectors') ?? true,
          texts: a.flag('texts') ?? true,
          images: images,
          useLayers: a.flag('use_layers') ?? true,
          hiddenLayers: a.flag('hidden_layers') ?? false,
          byColour: a.flag('by_colour') ?? false,
          layer: a.str('layer') ?? pdfLayerName(name),
          source: name,
        );
        final r = pdfPageEntities(page0, o, b.p.newId);
        if (r.entities.isEmpty) throw ToolInputError('Nothing to import with those options (page ${page + 1}).');
        b.change('import_pdf_attachment', () {
          addPdfEntities(b.p, r);
          return r.entities.length;
        }, invalidate: false);
        c.select(r.entities.map((e) => e.id));
        final bx = r.bounds;
        if (!bx.isEmpty && !c.camera.size.isEmpty) c.camera.fit(bx.inflate(math.max(bx.width, bx.height) * 0.05 + 1));
        final notes = {
          for (final w in [...page0.warnings, ...r.warnings]) b.t.warning(w),
        };
        return ToolOutput(
          'Imported page ${page + 1} of "$name" at ${a.has('metres_per_unit') ? '${cadN(k, 6)} m per unit' : '1:${cadN(k / PdfImportOptions.atScale(1), 0)}'}${found != null && !a.has('scale') && !a.has('metres_per_unit') ? ' (the scale written on the sheet)' : ''}: ${r.entities.length} items on ${r.layers.length} layers, extent ${AgentToolbox.box(bx)}; they are selected.${notes.isEmpty ? '' : ' Notes: ${notes.join('; ')}.'}',
        );
      },
    ),
  ];
}

/// Encoded pixels and the world corners of an image.
typedef Uint8ListAndCorners = (Uint8List, List<Pt>);
