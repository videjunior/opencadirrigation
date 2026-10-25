/// The vision tools of the AI assistant: pictures of the drawing over the
/// base map (the satellite image whenever the project is georeferenced)
/// with the exact pixel ↔ world mapping (view_snapshot, image_to_world),
/// proposed geometry drawn before it is created (preview_geometry), the
/// ground relief and its numbers (terrain_picture, terrain_profile,
/// terrain_info), and the helpers the assistant uses to show the model the
/// drawing after its changes and to let the user attach a picture of the
/// view.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/ai/agent_loop.dart';
import '../../core/model/entities.dart';
import '../../core/model/geometry.dart';
import '../../core/model/terrain.dart';
import '../../core/units.dart';
import '../state/controller.dart';
import 'agent_tools.dart';
import 'view_snapshot.dart';
import 'vision_terrain.dart';

/// Schema of a list of pixel positions.
Map<String, Object?> _pixels(String description) => {
  'type': 'array',
  'items': {
    'type': 'array',
    'items': {'type': 'number'},
  },
  'description': description,
  'maxItems': 500,
};

final Map<String, Object?> _pixelBox = {
  'type': 'array',
  'items': {'type': 'number'},
  'description': '[px0, py0, px1, py1]: a rectangle of pixels of that picture (from its top-left corner) to show at full resolution.',
};

Map<String, Object?> _grid() => str('Labelled coordinate grid: "normal" (about 8 lines; default), "dense" (about 16, labels on all four edges), "none".', ['none', 'normal', 'dense']);
Map<String, Object?> _size() => int_('Longest side in pixels, 256–1568 (default 1024); the picture also stays under about 1.15 megapixels so no provider rescales it.');

/// Positions `[[px, py], …]` in pixels.
List<(double, double)> _pixelsOf(Object? v, String what, {int max = 500}) {
  if (v is! List) throw ToolInputError('$what must be a list of pixel positions [[px, py], …].');
  if (v.isEmpty || v.length > max) throw ToolInputError('$what needs 1 to $max positions (got ${v.length}).');
  return [
    for (var i = 0; i < v.length; i++)
      switch (v[i]) {
        [final num x, final num y, ...] when x.isFinite && y.isFinite => (x.toDouble(), y.toDouble()),
        _ => throw ToolInputError('$what[$i] must be [px, py] in pixels from the top-left corner.'),
      },
  ];
}

String _json(Iterable<Pt> pts) => jsonEncode([
  for (final q in pts) [roundTo(q.x, 2), roundTo(q.y, 2)],
]);

String _jsonPx(Iterable<(double, double)> px) => jsonEncode([
  for (final (x, y) in px) [roundTo(x, 1), roundTo(y, 1)],
]);

/// The summary of a view_snapshot call, in the user's language.
String _snapshotSummary(AgentToolbox b, Map<String, dynamic> i) {
  final t = b.t;
  if (i['pixel_bbox'] != null) return t('ai.vis.zoom', {'n': '${i['snapshot'] ?? ''}'});
  if (i['drawing'] == false) return t('ai.vis.mapOnly');
  return switch (i['base_map']) {
    'satellite' => t('ai.vis.snapshotSatellite'),
    'street' => t('ai.vis.snapshotStreet'),
    'current' => t('ai.vis.snapshotCurrent'),
    _ => t('ai.tool.snapshot'),
  };
}

List<AgentTool> visionTools(AgentToolbox b) {
  final t = b.t;
  return [
    FnTool(
      name: 'view_snapshot',
      description:
          'A picture (PNG) of the project as the user sees it: the drawing with its layer colours and result overlay over the base map, composed into ONE image with a labelled metre grid, its id (e.g. "s3") and the exact pixel ↔ world mapping. '
          'Use it to look at the layout, to check what you changed, to read the site on the satellite image (fields, buildings, roads, trees, water, the well) and trace it, and to zoom into details (a smaller bbox, or snapshot + pixel_bbox, at full resolution). '
          'Not for numbers (get_entity, list_entities, get_report_table) nor heights (terrain_picture, terrain_profile). '
          'base_map "satellite" works whenever the project is georeferenced, even when the screen shows another map or none (Esri World Imagery, or Google satellite when the user set a Google key); the user\'s view and base map stay as they are. '
          'Output: the image and its text: picture id, world bbox [minX, minY, maxX, maxY] in m, s = metres per pixel and x = minX + px·s, y = maxY − py·s (pixels from the top-left corner, py down, north up), the map source with its tile zoom and imagery credit, the grid step, and the labels or legend asked for. Convert positions you pick with image_to_world instead of computing them. '
          'No side effects (only when the tiles of the map on screen cannot be fetched off screen does the view move there for a moment and back; the result says so). Without a georeference there is no map (set_site); when the tiles fail (offline) the picture shows the drawing alone and says why.',
      inputSchema: obj({
        'region': str(
          'What to frame: "view" (what the user\'s screen shows; default), "drawing" (everything drawn), "bbox", "items" (the ids), "snapshot" (the area of an earlier picture, or its part pixel_bbox).',
          ['view', 'drawing', 'bbox', 'items', 'snapshot'],
        ),
        'bbox': bbox,
        'ids': arr(str(), 'Items to frame (ids or names; region "items").'),
        'snapshot': str('Id of an earlier picture ("s3"): its area again, or with pixel_bbox a part of it.'),
        'pixel_bbox': _pixelBox,
        'base_map': baseMapInput,
        'drawing': bool_('Draw the project over the map (default true; false shows the map alone).'),
        'size': _size(),
        'grid': _grid(),
        'labels': str('Short labels next to the items: "ids", "names" or "none" (default). Hydraulic items first; labels that would overlap are left out.', ['none', 'ids', 'names']),
        'legend': bool_('A legend of the layer colours of the items shown, top right (default false).'),
      }),
      summary: (i) => _snapshotSummary(b, i),
      handler: (i) async => snapshotTool(b, ToolArgs(i)),
    ),
    FnTool(
      name: 'image_to_world',
      description:
          'Converts positions exactly between a picture and the project, so you never do the arithmetic: pixels [[px, py], …] you picked on picture `snapshot` (from its top-left corner, px right, py down; fractions allowed) → project coordinates [x, y] in metres (x east, y north), ready for create_entities or preview_geometry; and back, pts [[x, y], …] in metres → their pixel positions on that picture (world_to_image), e.g. to see where an item falls on the satellite image. '
          'closed true takes the pixels as a polygon and adds its area and perimeter. Pick vertices on clear corners and edges; one pixel is s metres, so zoom in (view_snapshot with snapshot + pixel_bbox) where precision matters. '
          'Up to 500 positions each way. No side effects. Errors: an unknown picture id (pictures live for this conversation only: take a new one).',
      inputSchema: obj(
        {
          'snapshot': str('Picture id, e.g. "s3" (from view_snapshot, preview_geometry, terrain_picture), or "u1" for one the user attached.'),
          'pixels': _pixels('[[px, py], …] on that image, pixels from its top-left corner (px right, py down).'),
          'pts': {...points, 'maxItems': 500, 'description': '[[x, y], …] in metres: project points to place on that image.'},
          'closed': bool_('The pixels outline a polygon: also give its area and perimeter.'),
        },
        required: ['snapshot'],
      ),
      summary: (i) => t('ai.vis.toWorld', {'n': '${((i['pixels'] as List?)?.length ?? 0) + ((i['pts'] as List?)?.length ?? 0)}', 's': '${i['snapshot'] ?? ''}'}),
      handler: (i) async {
        final a = ToolArgs(i);
        final m = pictureMappingOf(b, a.str('snapshot', required: true));
        if (!a.has('pixels') && !a.has('pts')) throw ToolInputError('Give pixels [[px, py], …] (to project coordinates) or pts [[x, y], …] in metres (to pixels).');
        final out = <String>['Picture ${m.id}: ${m.width}×${m.height} px, s = ${fmt(m.mpp, m.mpp < 1 ? 5 : 4)} m per pixel, world bbox ${AgentToolbox.box(m.world)} m.'];
        if (a.has('pixels')) {
          final px = _pixelsOf(i['pixels'], '"pixels"');
          final world = [for (final (x, y) in px) m.toWorld(x, y)];
          out.add('World points [x, y] in m: ${_json(world)}');
          final outside = [
            for (var k = 0; k < px.length; k++)
              if (!m.contains(px[k].$1, px[k].$2)) '#${k + 1}',
          ];
          if (outside.isNotEmpty) out.add('Pixels outside the picture (extrapolated along the same mapping): ${outside.join(', ')}.');
          if (a.flag('closed') ?? false) {
            if (world.length < 3) throw ToolInputError('closed needs at least 3 pixels.');
            final area = polygonArea(world).abs();
            out.add(
              'Closed outline: area ${fmt(area, 1)} m² (${fmt(area / 1e4, 4)} ha), perimeter ${fmt(polylineLength([...world, world.first]), 2)} m, centroid ${AgentToolbox.pt(polygonCentroid(world))}.',
            );
          }
        }
        if (a.has('pts')) {
          final pts = a.points('pts', max: 500)!;
          final px = [for (final q in pts) m.toPixel(q)];
          out.add('Pixels [px, py] on ${m.id}: ${_jsonPx(px)}');
          final outside = [
            for (var k = 0; k < px.length; k++)
              if (!m.contains(px[k].$1, px[k].$2)) '#${k + 1}',
          ];
          if (outside.isNotEmpty) out.add('Outside the picture: ${outside.join(', ')}.');
        }
        return ToolOutput(out.join('\n'));
      },
    ),
    FnTool(
      name: 'preview_geometry',
      description:
          'Draws geometry you propose (points, polylines, polygons) in magenta over a fresh picture of the project without changing it, to check a traced field, an obstacle, a route or positions against the satellite image and the drawing before creating them. Each shape gets its label (P1, P2… by default) and dots on its vertices. '
          'Coordinates: pts in metres, or pixels of an earlier picture snapshot (converted exactly). The picture frames all shapes with a margin (or bbox), with the same options as view_snapshot (base_map default as there). '
          'Output: the image with its id and mapping, and per shape its world points rounded to 0.01 m (ready for create_entities), length, polygon area and warnings (an outline that crosses itself, too few points). '
          'No side effects: nothing is added to the project and no undo step is made. Errors: an unknown snapshot id; a shape without points.',
      inputSchema: obj(
        {
          'shapes': arr(
            obj(
              {
                'kind': str('"point" (each position a marker), "polyline" or "polygon" (closed).', ['point', 'polyline', 'polygon']),
                'pts': points,
                'pixels': _pixels('Positions in pixels of the picture `snapshot` instead of pts.'),
                'label': str('Short text drawn by the shape (default P1, P2…).'),
              },
              required: ['kind'],
            ),
            'Up to 30 shapes, each with pts (m) or pixels.',
            30,
          ),
          'snapshot': str('Picture id the pixels refer to, e.g. "s3".'),
          'bbox': bbox,
          'base_map': baseMapInput,
          'drawing': bool_('Draw the project under the shapes (default true).'),
          'size': _size(),
          'grid': _grid(),
        },
        required: ['shapes'],
      ),
      summary: (i) => t('ai.vis.preview', {'n': '${(i['shapes'] as List?)?.length ?? 0}'}),
      handler: (i) async => _previewTool(b, ToolArgs(i)),
    ),
    FnTool(
      name: 'terrain_picture',
      description:
          'A picture of the ground relief from the terrain model of the project (contours, spot heights, breaklines, downloaded elevations): a hillshade with colours by elevation (legend with the range in m), or the app\'s slope classes in % or the aspect; labelled contour lines at an automatic or given interval; hatching where heights are far from any data. '
          'It can lie over the satellite image (base_map) and under the drawing (drawing true), with the same picture id and exact pixel ↔ world mapping as view_snapshot (image_to_world works on it). '
          'Use it before laying out blocks, rows, laterals and the mainline on sloping ground, and to place the source and see the high and low ground; numbers along a line come from terrain_profile, single heights from get_elevations, the reliability of the data from terrain_info. '
          'Output: the image and its text: the mapping, the elevation range and slopes in the picture, the contour interval, the colour key, the vertical exaggeration of the hillshade and where data are missing. '
          'No side effects. Errors: no terrain data → download_terrain (needs a georeference: set_site), import_attachment of a survey, or spot heights from the user.',
      inputSchema: obj({
        'region': str('What to frame: "view" (the screen; default when there is one), "terrain" (the extent of the terrain data; default otherwise), "drawing", "bbox", "items", "snapshot".', [
          'view',
          'terrain',
          'drawing',
          'bbox',
          'items',
          'snapshot',
        ]),
        'bbox': bbox,
        'ids': arr(str(), 'Items to frame (region "items").'),
        'snapshot': str('Id of an earlier picture: its area, or with pixel_bbox a part of it.'),
        'pixel_bbox': _pixelBox,
        'colour': str('"elevation" (default: green low → white high), "slope" (the app\'s slope classes in %), "aspect" (the direction the ground faces), "none".', [
          'elevation',
          'slope',
          'aspect',
          'none',
        ]),
        'hillshade': bool_('Shade the relief, lit from the north-west (default true).'),
        'contours': bool_('Labelled contour lines (default true).'),
        'interval_m': num_('Contour interval in m, 0.1–500 (default: a round value giving 10–15 lines).'),
        'base_map': {...baseMapInput, 'description': 'Map under the terrain colours: "none" (default), "satellite", "current" or "street".'},
        'opacity': num_('Opacity of the terrain colours, 0.2–1 (default 1, or 0.55 over a base map).'),
        'drawing': bool_('Draw the project over the terrain (default false).'),
        'size': _size(),
        'grid': _grid(),
      }),
      summary: (i) => i['colour'] == 'slope' || i['colour'] == 'aspect' ? t('ai.vis.terrainSlope') : t('ai.vis.terrain'),
      handler: (i) async => _terrainPictureTool(b, ToolArgs(i)),
    ),
    FnTool(
      name: 'terrain_profile',
      description:
          'The ground along a line from the terrain model: length, start and end elevations, total rise and total fall, steepest uphill and downhill slopes, the highest and lowest points, local high points (air gathers there in a pipe) and low points, rise and mean slope per segment, where the line leaves the terrain data, and a table d (m from the start) | x | y | z (m) | slope (%) to the next row, uphill positive. '
          'Use it to route the mainline or a submain (along the contours for level laterals, a steady fall, around high points or with an air valve there), to choose the lateral direction on a slope, or for the lift from the source to a field. '
          'Inputs: pts (2–500 vertices, in metres) or id (an item whose line to follow). Output: text only. No side effects. Errors: no terrain data → download_terrain (needs a georeference: set_site).',
      inputSchema: obj({
        'pts': {...points, 'maxItems': 500, 'description': 'The line, [[x, y], …] in metres (2–500 vertices).'},
        'id': str('Or an item to follow instead of pts: a pipe, lateral, area outline or other line (id or name).'),
        'step_m': num_('Sampling interval in m, 0.5–500 (default: a hundredth of the length, 1–50 m).'),
        'rows': int_('Rows of the table, 2–200 (default 40).'),
      }),
      summary: (i) {
        final u = b.u;
        double len;
        try {
          len = i['pts'] is List ? polylineLength(ToolArgs.pointsOf(i['pts'], 'pts')) : (b.find('${i['id']}').linearPoints?.let(polylineLength) ?? 0);
        } catch (_) {
          len = 0;
        }
        return t('ai.vis.profile', {'n': '${fmt(u.lengthFromSi(len), 0)} ${u.lengthLabel}'});
      },
      handler: (i) async {
        final a = ToolArgs(i);
        final tr = b.terrain;
        if (tr.isEmpty) throw ToolInputError(_noTerrain(b));
        List<Pt> pts;
        if (a.has('pts')) {
          pts = a.points('pts', min: 2, max: 500)!;
        } else if (a.has('id')) {
          final e = b.find(a.str('id')!);
          final line = e.linearPoints;
          if (line == null || line.length < 2) throw ToolInputError('${e.id} is not a line: give pts instead.');
          pts = e.isClosedShape ? [...line, line.first] : line;
        } else {
          throw ToolInputError('Give pts [[x, y], …] in metres (2–500 vertices) or the id of a line item.');
        }
        if (polylineLength(pts) <= 0) throw ToolInputError('The line has no length.');
        final method = b.p.params.terrainMethod == TerrainMethod.tin ? 'TIN' : 'inverse-distance';
        return ToolOutput(terrainProfileText(tr, pts, step: a.number('step_m', min: 0.5, max: 500), rows: a.integer('rows', min: 2, max: 200) ?? 40, method: method));
      },
    ),
    FnTool(
      name: 'terrain_info',
      description:
          'What the terrain model of the project is made of and how far its heights can be trusted: the interpolation (TIN or inverse distance), the number of height samples and their sources (contour lines, own spot heights, downloaded elevation points on the DEM layer, breaklines), the extent and elevation range of the data, the density (samples per hectare, mean spacing), how much of the drawing lies inside the data, the zones where heights are interpolated far from the nearest sample, and the hydraulic items there. '
          'Use it before trusting terrain_picture, terrain_profile or get_elevations, and to decide whether to download_terrain or ask the user for a survey. No inputs. No side effects. With no data it says so and how to get some.',
      inputSchema: obj({}),
      summary: (_) => t('ai.vis.terrainInfo'),
      handler: (_) async => ToolOutput(terrainInfoText(b.p, b.terrain)),
    ),
  ];
}

String _noTerrain(AgentToolbox b) =>
    'The project has no terrain data (no contours, spot heights or breaklines): ${b.p.meta.georef == null ? 'set_site, then download_terrain' : 'download_terrain'} adds online elevations; import_attachment takes a survey; or ask the user for spot heights.';

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

// ---------------------------------------------------------------- preview_geometry

/// Magenta: no layer of the program uses it.
const _proposal = Color(0xFFFF2BD6);

class _Shape {
  _Shape(this.kind, this.pts, this.label);
  final String kind;
  final List<Pt> pts;
  final String label;
}

Future<ToolOutput> _previewTool(AgentToolbox b, ToolArgs a) async {
  final raw = a.input['shapes'];
  if (raw is! List || raw.isEmpty) throw ToolInputError('"shapes" needs at least one shape {kind, pts or pixels}.');
  if (raw.length > 30) throw ToolInputError('At most 30 shapes per call (got ${raw.length}).');
  final snapId = a.str('snapshot');
  final m = snapId == null ? null : pictureMappingOf(b, snapId);
  final shapes = <_Shape>[];
  var total = 0;
  for (var k = 0; k < raw.length; k++) {
    final s = raw[k];
    if (s is! Map) throw ToolInputError('shapes[$k] must be an object {kind, pts or pixels, label}.');
    final sa = ToolArgs(Map<String, dynamic>.from(s));
    final kind = sa.str('kind', required: true)!;
    if (!const ['point', 'polyline', 'polygon'].contains(kind)) throw ToolInputError('shapes[$k].kind must be "point", "polyline" or "polygon".');
    List<Pt> pts;
    if (sa.has('pts')) {
      pts = sa.points('pts', max: 2000)!;
    } else if (sa.has('pixels')) {
      if (m == null) throw ToolInputError('shapes[$k] gives pixels: say which picture with "snapshot".');
      pts = [for (final (x, y) in _pixelsOf(s['pixels'], 'shapes[$k].pixels', max: 2000)) m.toWorld(x, y)];
    } else {
      throw ToolInputError('shapes[$k] has no points: give pts [[x, y], …] in metres or pixels of the snapshot.');
    }
    if (kind == 'polygon' && pts.length >= 2 && pts.first.distanceTo(pts.last) < 1e-9) pts = pts.sublist(0, pts.length - 1);
    if (kind == 'polygon' && pts.length < 3) throw ToolInputError('shapes[$k] is a polygon with ${pts.length} points: it needs at least 3.');
    if (kind == 'polyline' && pts.length < 2) throw ToolInputError('shapes[$k] is a polyline with one point: give at least 2 (or kind "point").');
    total += pts.length;
    if (total > 5000) throw ToolInputError('At most 5000 points in all.');
    final label = sa.str('label');
    shapes.add(_Shape(kind, pts, label == null || label.isEmpty ? 'P${k + 1}' : AgentToolbox.short(label, 24)));
  }
  final all = Bounds.ofPoints([for (final s in shapes) ...s.pts]);
  Bounds world;
  if (a.has('bbox')) {
    world = bboxOf(a.input['bbox']);
  } else if (m != null && !all.isEmpty && m.world.contains(Pt(all.minX, all.minY)) && m.world.contains(Pt(all.maxX, all.maxY))) {
    world = m.world;
  } else {
    final span = math.max(all.width, all.height);
    world = all.inflate(math.max(10.0, 0.15 * span));
  }
  final size = a.integer('size', min: 256, max: maxPictureSide) ?? defaultPictureSide;
  final maps = pictureMapsFor(b.c, a.input['base_map']);
  final drawing = a.flag('drawing') ?? true;
  final grid = pictureGridOf(a);
  // what each shape is, and what may be wrong with it
  final lines = <String>[];
  final warnings = <String>[];
  for (final s in shapes) {
    switch (s.kind) {
      case 'polygon':
        final area = polygonArea(s.pts).abs();
        lines.add(
          '${s.label} polygon, ${s.pts.length} vertices: area ${fmt(area, 1)} m² (${fmt(area / 1e4, 4)} ha), perimeter ${fmt(polylineLength([...s.pts, s.pts.first]), 2)} m; pts ${_json(s.pts)}',
        );
        final cross = _selfCrossing(s.pts);
        if (cross != null) warnings.add('${s.label}: its outline crosses itself (edges ${cross.$1 + 1} and ${cross.$2 + 1}); reorder the vertices.');
        if (area < 1e-6) warnings.add('${s.label}: the polygon has no area (its points are in a line).');
      case 'polyline':
        lines.add('${s.label} polyline, ${s.pts.length} vertices: length ${fmt(polylineLength(s.pts), 2)} m; pts ${_json(s.pts)}');
      default:
        lines.add('${s.label} ${s.pts.length == 1 ? 'point' : '${s.pts.length} points'}: ${_json(s.pts)}');
    }
  }
  final out = await pictureOutput(
    b,
    (id) => VisionSpec(
      world: world,
      maxSide: size,
      maps: maps,
      drawing: drawing,
      grid: grid,
      caption: id,
      tiles: VisionSession.of(b).tiles,
      over: [
        (f) async =>
            (canvas, frame) => _paintShapes(canvas, frame, shapes),
      ],
    ),
    what: (img) => '${pictureWhat(img, drawing: drawing)} with ${shapes.length} proposed shape${shapes.length == 1 ? '' : 's'} in magenta',
    tail: (img, pic) => [
      ...lines,
      if (warnings.isNotEmpty) 'Warnings: ${warnings.join(' ')}',
      if (shapes.any((s) => s.pts.any((q) => !img.world.contains(q)))) 'Some vertices lie outside the picture: give a larger bbox to see them all.',
      'The project was not changed.',
    ],
  );
  return out;
}

/// The first pair of non-adjacent edges of the closed outline [pts] that
/// cross, or null.
(int, int)? _selfCrossing(List<Pt> pts) {
  final n = pts.length;
  if (n < 4 || n > 600) return null;
  for (var i = 0; i < n; i++) {
    final a = pts[i], b = pts[(i + 1) % n];
    for (var j = i + 2; j < n; j++) {
      if (i == 0 && j == n - 1) continue;
      if (segmentIntersection(a, b, pts[j], pts[(j + 1) % n]) != null) return (i, j);
    }
  }
  return null;
}

void _paintShapes(Canvas canvas, PictureFrame f, List<_Shape> shapes) {
  final halo = Paint()
    ..color = const Color(0xB3000000)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;
  final line = Paint()
    ..color = _proposal
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;
  final fill = Paint()..color = _proposal.withValues(alpha: 0.16);
  final dot = Paint()..color = _proposal;
  final ring = Paint()
    ..color = const Color(0xFF000000)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;
  for (final s in shapes) {
    final px = [for (final q in s.pts) f.toPx(q)];
    if (s.kind == 'point') {
      for (final o in px) {
        canvas.drawCircle(o, 7, halo);
        canvas.drawCircle(o, 7, line);
        canvas.drawLine(o + const Offset(-11, 0), o + const Offset(11, 0), line);
        canvas.drawLine(o + const Offset(0, -11), o + const Offset(0, 11), line);
      }
    } else {
      final path = Path()..addPolygon(px, s.kind == 'polygon');
      if (s.kind == 'polygon') canvas.drawPath(path, fill);
      canvas.drawPath(path, halo);
      canvas.drawPath(path, line);
      for (final o in px) {
        canvas.drawCircle(o, 3.2, dot);
        canvas.drawCircle(o, 3.2, ring);
      }
    }
    // the label by the shape: inside a polygon, mid-way along a line, above a point
    Pt at;
    if (s.kind == 'polygon') {
      final cen = polygonCentroid(s.pts);
      at = pointInPolygon(cen, s.pts) ? cen : s.pts.first;
    } else if (s.kind == 'polyline') {
      at = pointAlongPolyline(s.pts, polylineLength(s.pts) / 2);
    } else {
      at = s.pts.first;
    }
    final o = f.toPx(at) + (s.kind == 'point' ? const Offset(10, -24) : const Offset(6, -8));
    final tp = TextPainter(
      text: TextSpan(
        text: s.label,
        style: const TextStyle(fontSize: 11, color: Color(0xFFFFFFFF), fontFamily: 'monospace', fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.drawRect(Rect.fromLTWH(o.dx, o.dy, tp.width + 6, tp.height + 2), Paint()..color = const Color(0xE6A0007F));
    tp.paint(canvas, o + const Offset(3, 1));
    tp.dispose();
  }
}

// ---------------------------------------------------------------- terrain_picture

Future<ToolOutput> _terrainPictureTool(AgentToolbox b, ToolArgs a) async {
  final tr = b.terrain;
  if (tr.isEmpty) throw ToolInputError(_noTerrain(b));
  final world = pictureWorld(b, a, fallback: b.c.camera.size.isEmpty ? 'terrain' : 'view', terrainExtent: () => terrainExtent(tr));
  final colour = switch (a.str('colour')) {
    null || 'elevation' => TerrainColour.elevation,
    'slope' => TerrainColour.slope,
    'aspect' => TerrainColour.aspect,
    'none' => TerrainColour.none,
    final s => throw ToolInputError('"colour" must be "elevation", "slope", "aspect" or "none" (got "$s").'),
  };
  final maps = a.has('base_map') ? pictureMapsFor(b.c, a.input['base_map']) : const <BaseMap>[];
  final o = TerrainPictureOptions(
    colour: colour,
    hillshade: a.flag('hillshade') ?? true,
    contours: a.flag('contours') ?? true,
    interval: a.number('interval_m', min: 0.1, max: 500),
    opacity: a.number('opacity', min: 0.2, max: 1) ?? (maps.isEmpty ? 1 : 0.55),
  );
  final drawing = a.flag('drawing') ?? false;
  final size = a.integer('size', min: 256, max: maxPictureSide) ?? defaultPictureSide;
  TerrainLayer? layer;
  try {
    return await pictureOutput(
      b,
      (id) => VisionSpec(
        world: world,
        maxSide: size,
        maps: maps,
        drawing: drawing,
        grid: pictureGridOf(a),
        caption: id,
        tiles: VisionSession.of(b).tiles,
        mapOpacity: 1,
        under: [
          (f) async {
            layer = await prepareTerrainLayer(tr, f, o);
            return layer!.paintUnder;
          },
        ],
        over: [(f) async => layer?.paintLegend],
      ),
      what: (img) {
        final parts = [
          if (o.hillshade) 'hillshade',
          switch (colour) {
            TerrainColour.elevation => 'elevation colours',
            TerrainColour.slope => 'slope classes',
            TerrainColour.aspect => 'aspect colours',
            TerrainColour.none => null,
          },
          if (o.contours && (layer?.lines ?? 0) > 0) 'contours every ${fmt(layer!.interval, layer!.interval < 1 ? 2 : 1)} m',
        ].nonNulls;
        final map = img.map == null ? '' : ' over ${mapSourceName(img.map!)}${img.zoom == null ? '' : ' (tile zoom ${img.zoom})'}';
        return 'terrain relief (${parts.join(', ')})$map${drawing ? ', the drawing on top' : ''}';
      },
      lead: (_) => ['Terrain: ${b.p.params.terrainMethod == TerrainMethod.tin ? 'TIN' : 'inverse-distance'} model from ${TerrainCoverage.of(tr).samples.length} height samples.', ?layer?.describe()],
    );
  } finally {
    layer?.dispose();
  }
}

// ---------------------------------------------------------------- helpers for the assistant

/// A picture for the user to attach to a message: what they see, with the
/// pixel ↔ world mapping written out.
class ViewPicture {
  const ViewPicture(this.png, this.mapping, {this.name = 'view.png'});
  final Uint8List png;

  /// The picture id, world rectangle, metres per pixel and the formula, for
  /// the model (image_to_world takes the id).
  final String mapping;
  final String name;
}

/// The current view as the user sees it: the drawing over the base map on
/// screen, with a light coordinate grid, up to [maxSide] pixels, rendered
/// off screen (the view does not move). It is registered as picture "u1",
/// "u2"… of the project tab, so the model can convert positions on it with
/// image_to_world. Null where it cannot be drawn.
Future<ViewPicture?> captureUserView(ProjectController c, {ViewSnapshots? snapshots, int maxSide = defaultPictureSide}) async {
  final s = snapshots ?? const CanvasSnapshots();
  var world = c.camera.size.isEmpty ? c.project.bounds : c.camera.visible;
  if (world.isEmpty) return null;
  if (c.camera.size.isEmpty) world = world.inflate(math.max(2.0, 0.05 * math.max(world.width, world.height)));
  final side = maxSide.clamp(256, maxPictureSide);
  try {
    final session = VisionSession.of(c);
    final id = session.nextId('u');
    final SnapshotImage img;
    if (s is VisionRenderer) {
      final r = s as VisionRenderer;
      img = await r.render(c, VisionSpec(world: world, maxSide: side, maps: c.baseMap == BaseMap.none ? const [] : [c.baseMap], caption: id, onScreenFallback: false));
    } else {
      img = await s.drawing(c, world, side);
    }
    final m = session.add(id, img.frame, pictureWhat(img, drawing: true, subject: 'the user\'s view of the drawing'));
    return ViewPicture(img.png, [m.describe(), ...img.notes].join('\n'), name: 'view-$id.png');
  } catch (_) {
    return null;
  }
}

/// A small picture (768 px) of the whole drawing over the base map on
/// screen after a change, for the setting "show the AI the drawing after
/// its changes". Registered like the tools' pictures: its id is written in
/// its corner and [lastFeedbackMapping] gives its mapping. Null where it
/// cannot be drawn.
Future<ToolImage?> feedbackPicture(AgentToolbox b) async {
  final s = b.snapshots;
  if (s == null) return null;
  final c = b.c;
  var world = b.p.bounds;
  if (world.isEmpty) return null;
  world = world.inflate(math.max(2.0, 0.05 * math.max(world.width, world.height)));
  try {
    final session = VisionSession.of(b);
    final id = session.nextId('s');
    final SnapshotImage img;
    if (s is VisionRenderer) {
      final r = s as VisionRenderer;
      img = await r.render(c, VisionSpec(world: world, maxSide: 768, maps: c.baseMap == BaseMap.none ? const [] : [c.baseMap], caption: id, tiles: session.tiles, onScreenFallback: false));
    } else {
      img = await s.drawing(c, world, 768);
    }
    final m = session.add(id, img.frame, pictureWhat(img, drawing: true, subject: 'the drawing after the change'));
    session.lastFeedback = m.describe();
    return ToolImage('image/png', base64Encode(img.png));
  } catch (_) {
    return null;
  }
}

/// The mapping of the last [feedbackPicture] of [b], to send with it.
String? lastFeedbackMapping(AgentToolbox b) => VisionSession.of(b).lastFeedback;
