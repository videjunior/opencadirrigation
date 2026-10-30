/// The view_snapshot tool of the AI assistant and the inputs the picture
/// tools share: the area to frame (a region, a bbox, items, or a part of an
/// earlier picture), the base map ("current", "satellite", "street",
/// "none"), the grid and labels, and the registration of every picture with
/// its id and exact pixel ↔ world mapping (vision_mapping.dart). The
/// pictures themselves are drawn by vision_render.dart.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/painting.dart' show Color;

import '../../core/ai/agent_loop.dart';
import '../../core/model/entities.dart';
import '../../core/model/geometry.dart';
import '../../core/units.dart';
import '../state/controller.dart';
import 'agent_tools.dart';
import 'vision_mapping.dart';
import 'vision_marks.dart';
import 'vision_render.dart';
import 'vision_tiles.dart';

export 'vision_mapping.dart' show PictureFrame, PictureLimits, SnapshotMapping, VisionSession, maxPictureSide, defaultPictureSide, maxPicturePixels;
export 'vision_render.dart';
export 'vision_tiles.dart' show TileFetcher, HttpTileFetcher, TileCache, MapUnavailable, mapSourceName;

// ---------------------------------------------------------------- tool inputs

/// Schema of `base_map`: a choice or, as before, a boolean.
final Map<String, Object?> baseMapInput = {
  'type': ['string', 'boolean'],
  'description': '"satellite" (aerial imagery: Esri World Imagery, or Google satellite when the user set a Google key; the default whenever the project is georeferenced), "current" (the map the screen shows; the default otherwise), "street" (a street map) or "none". The user\'s own base map is never changed. true/false are read as the default/"none".',
};

/// The base maps to try for the `base_map` input [choice] (null or true:
/// "satellite" when the project is georeferenced — the model draws over
/// what is really on the ground — else "current" when the screen shows a
/// map, else none).
List<BaseMap> pictureMapsFor(ProjectController c, Object? choice) {
  final shown = c.baseMap;
  final key = (c.googleMapsKey ?? '').isNotEmpty;
  final pick = switch (choice) {
    null || true => c.project.meta.georef != null ? 'satellite' : (shown != BaseMap.none ? 'current' : 'none'),
    false => 'none',
    final String s => s.trim().toLowerCase(),
    _ => '?',
  };
  return switch (pick) {
    'none' => const [],
    'current' => shown == BaseMap.none ? const [] : [shown],
    'satellite' || 'aerial' => [if (key) BaseMap.googleSatellite, BaseMap.satellite],
    'street' || 'streets' => [if (isStreetMap(shown) && (!shown.isGoogle || key)) shown, if (shown != BaseMap.streets) BaseMap.streets],
    _ => throw ToolInputError('"base_map" must be "current", "satellite", "street" or "none" (or true/false).'),
  };
}

/// Schema of `size`, with the limit of the model in use.
Map<String, Object?> pictureSizeInput(AgentToolbox b) {
  final l = b.pictures;
  return int_(
    'Longest side in pixels, 256–${l.maxSide} (default $defaultPictureSide); the picture also stays under about ${fmt(l.maxPixels / 1e6, 2)} megapixels${l.maxShortSide == null ? '' : ' with its shorter side at most ${l.maxShortSide} px'}, the most the model in use reads pixel for pixel. '
    'A picture costs about width × height / 784 input tokens (a $defaultPictureSide px square about ${(defaultPictureSide * defaultPictureSide / 784).round()}, the largest about ${l.maxTokens}): ask for more pixels where detail matters (tracing on the satellite image), or zoom into a part.',
  );
}

/// The longest side asked for, within the limit of the model in use (a
/// larger one is reduced, with a note in [notes]).
int pictureSideOf(AgentToolbox b, ToolArgs a, List<String> notes) {
  final asked = a.integer('size', min: 256, max: 8192);
  if (asked == null) return defaultPictureSide;
  final max = b.pictures.maxSide;
  if (asked <= max) return asked;
  notes.add('size $asked was reduced to $max px, the most the model in use reads pixel for pixel.');
  return max;
}

/// Schema of `colour_by`.
Map<String, Object?> colourByInput() => str(
  'What the drawing is coloured by in this picture, whatever the user\'s screen shows (the screen does not change): "screen" (as the user sees it; default), "layers" (the layer colours, no results), "pressure" or "velocity" (pipes and laterals by their design results), '
  '"sizes" (pipes labelled with their catalogue pipe), "min_max" (the lowest and highest emitter pressure of every zone), "zones" (every zone in its own colour with its name at its valve, the mainline white: to check the zoning and what each valve feeds).',
  ['screen', 'layers', 'pressure', 'velocity', 'sizes', 'min_max', 'zones'],
);

/// Schema of `marks`.
Map<String, Object?> marksInput() => arr(
  str(null, ['changes', 'issues']),
  'Marks over the drawing: "changes" (what you added (cyan halo), changed (amber halo) and removed (dashed red outline) since your first change of this task: check your own work), '
  '"issues" (every design message at its items, numbered as get_design_messages numbers them, red errors, amber warnings, blue notes: see where the problems are).',
);

/// How a picture colours and marks the drawing (`colour_by`, `marks`).
class PictureLook {
  PictureLook._(this.overlay, this.showLabels, this.zones, this.issues, this.changes, this.notes);

  static PictureLook of(AgentToolbox b, ToolArgs a) {
    final c = b.c;
    final notes = <String>[];
    OverlayMode? overlay;
    bool? labels;
    ZoneColours? zones;
    final results = c.results != null;
    String noResults(String what) => '$what: there are no design results now, so the pipes keep their layer colours (run_design or analyse_design first).';
    switch (a.str('colour_by')) {
      case null || 'screen':
        notes.add('Colours as on the user\'s screen: ${_overlayText(c, c.overlay)}');
      case 'layers':
        overlay = OverlayMode.none;
        notes.add('Colours: the layer colours, no results.');
      case 'pressure':
        overlay = OverlayMode.pressure;
        notes.add(results ? 'Colours: ${_overlayText(c, OverlayMode.pressure)}' : noResults('Colours by pressure'));
      case 'velocity':
        overlay = OverlayMode.velocity;
        notes.add(results ? 'Colours: ${_overlayText(c, OverlayMode.velocity)}' : noResults('Colours by velocity'));
      case 'sizes':
        overlay = OverlayMode.sizes;
        labels = true;
        notes.add('Labels: every pipe, lateral and tape with the name of its catalogue pipe at its middle, where the picture has at least 0.8 px per metre (layer colours).');
      case 'min_max':
        overlay = OverlayMode.minMax;
        notes.add(
          results
              ? 'Marks of the design: in every zone a downward triangle at the emitter with the lowest pressure (blue, or red outside its window) and an upward one at the highest (purple, or orange outside), each with its pressure.'
              : noResults('Lowest and highest pressures'),
        );
      case 'zones':
        overlay = OverlayMode.none;
        zones = ZoneColours.of(c);
      case final s:
        throw ToolInputError('"colour_by" must be "screen", "layers", "pressure", "velocity", "sizes", "min_max" or "zones" (got "$s").');
    }
    final marks = a.strings('marks');
    for (final m in marks) {
      if (m != 'changes' && m != 'issues') throw ToolInputError('"marks" takes "changes" and "issues" (got "$m").');
    }
    ChangeMarks? changes;
    if (marks.contains('changes')) {
      final d = b.changes.task;
      if (d == null) {
        notes.add('Changes: you have changed nothing in this task yet.');
      } else {
        changes = ChangeMarks(d, since: b.changes.taskEnded ? 'since the start of your last task that changed the drawing' : 'since your first change of this task');
      }
    }
    return PictureLook._(overlay, labels, zones, marks.contains('issues') ? IssueMarks(c) : null, changes, notes);
  }

  final OverlayMode? overlay;
  final bool? showLabels;
  final ZoneColours? zones;
  final IssueMarks? issues;
  final ChangeMarks? changes;

  /// What the colours are (written before the picture is made).
  final List<String> notes;

  Color? Function(Entity e)? get tint => zones?.tint;

  /// The marks over the drawing, for [VisionSpec.over].
  List<PictureLayer> over(ProjectController c) => [
    if (zones != null)
      (f) async =>
          (canvas, frame) => zones!.paintLabels(c, canvas, frame),
    if (changes != null) (f) async => changes!.paint,
    if (issues != null) (f) async => issues!.prepare(f),
  ];

  /// The text about the colours and marks of the picture [f].
  List<String> describe(ProjectController c, PictureFrame f) => [...notes, if (zones != null) zones!.describe(c, f), if (changes != null) changes!.describe(f), ...?issues?.lines];
}

/// The colours an overlay gives the drawing, for the model.
String _overlayText(ProjectController c, OverlayMode ov) {
  final p = c.project.params;
  final results = c.results != null;
  return switch (ov) {
    OverlayMode.velocity when results =>
      'pipes and laterals with design results are coloured by flow velocity against the limit of their scope (zone ${fmt(p.maxZoneVelocity, 2)} m/s, mainline ${fmt(p.maxMainlineVelocity, 2)} m/s): blue when still, green at half the limit, orange at the limit, red at 1.5 times it and above; the rest in layer colours.',
    OverlayMode.pressure when results => 'pipes and laterals with design results are coloured by their mean pressure: red below 0 m, light blue at 0 m turning to green at 60 m (or at the pipe\'s rating when higher), purple above; emitters likewise against their pressure window; the rest in layer colours.',
    OverlayMode.minMax when results => 'layer colours, the lowest and highest emitter pressure of every zone marked.',
    OverlayMode.velocity || OverlayMode.pressure || OverlayMode.minMax => 'layer colours (the result overlay has no design results to show).',
    OverlayMode.sizes => 'layer colours, pipes labelled with their catalogue pipe.',
    OverlayMode.densogram => 'layer colours over the densogram (water applied by the sprinklers, mm/h).',
    OverlayMode.slope || OverlayMode.aspect => 'layer colours over the ${ov.name} map of the terrain.',
    OverlayMode.none => 'layer colours, no results.',
  };
}

GridDensity pictureGridOf(ToolArgs a, {GridDensity fallback = GridDensity.normal}) => switch (a.str('grid')) {
  null => fallback,
  'none' => GridDensity.none,
  'normal' => GridDensity.normal,
  'dense' => GridDensity.dense,
  final s => throw ToolInputError('"grid" must be "none", "normal" or "dense" (got "$s").'),
};

ItemLabels pictureLabelsOf(ToolArgs a) => switch (a.str('labels')) {
  null || 'none' => ItemLabels.none,
  'ids' => ItemLabels.ids,
  'names' => ItemLabels.names,
  final s => throw ToolInputError('"labels" must be "none", "ids" or "names" (got "$s").'),
};

/// The georeference of [c] as the pictures record it: the plane
/// coordinates of a picture are the project's while it is the same.
String pictureGeoKey(ProjectController c) {
  final g = c.project.meta.georef;
  return g == null ? '' : jsonEncode(g.toJson());
}

/// The picture [id] of this conversation (or one the user attached); refused
/// once the georeference has changed since it was drawn.
SnapshotMapping pictureMappingOf(AgentToolbox b, String? id) {
  if (id == null || id.isEmpty) throw ToolInputError('Missing "snapshot": the id of an earlier picture, e.g. "s3".');
  final m = VisionSession.of(b)[id] ?? VisionSession.of(b.c)[id];
  if (m == null) {
    final known = [...VisionSession.of(b).ids, ...VisionSession.of(b.c).ids];
    throw ToolInputError('No picture "$id" in this conversation${known.isEmpty ? '' : ' (known: ${known.reversed.take(12).join(', ')})'}: take a new one with view_snapshot.');
  }
  if (m.geo != pictureGeoKey(b.c)) {
    throw ToolInputError(
      'Picture ${m.id} was drawn before the georeference changed (set_site, set_georeference or an undo moved the origin): its pixels no longer match the project coordinates. Take a new picture.',
    );
  }
  return m;
}

/// `[px0, py0, px1, py1]` pixels of a picture.
List<double> picturePixelBoxOf(Object? v) {
  if (v is List && v.length == 4 && v.every((x) => x is num && x.isFinite)) return [for (final x in v) (x as num).toDouble()];
  throw ToolInputError('"pixel_bbox" must be [px0, py0, px1, py1]: pixels of the snapshot from its top-left corner.');
}

/// The world area a picture tool asks for: `region` ("view", "drawing",
/// "bbox", "items", "snapshot", and "terrain" when [terrainExtent] is
/// given), `bbox`, `ids`, or `snapshot` with `pixel_bbox` (a part of an
/// earlier picture). Without them [fallback].
Bounds pictureWorld(AgentToolbox b, ToolArgs a, {String fallback = 'view', Bounds Function()? terrainExtent}) {
  final c = b.c;
  final region = a.str('region') ?? (a.has('pixel_bbox') || (a.has('snapshot') && !a.has('bbox') && !a.has('ids')) ? 'snapshot' : (a.has('bbox') ? 'bbox' : (a.has('ids') ? 'items' : fallback)));
  var pad = true;
  Bounds world;
  switch (region) {
    case 'snapshot':
      final m = pictureMappingOf(b, a.str('snapshot'));
      pad = false;
      if (a.has('pixel_bbox')) {
        final q = picturePixelBoxOf(a.input['pixel_bbox']);
        world = Bounds.ofPoints([m.toWorld(q[0], q[1]), m.toWorld(q[2], q[3])]);
        if (world.width < 4 * m.mpp && world.height < 4 * m.mpp) throw ToolInputError('"pixel_bbox" is too small: give at least a few pixels each way.');
      } else {
        world = m.world;
      }
    case 'drawing':
      world = b.p.bounds;
    case 'bbox':
      world = bboxOf(a.input['bbox']);
      pad = false;
    case 'items':
      world = b.findAll(a.strings('ids', required: true)).fold(Bounds.empty, (Bounds x, e) => x.union(e.bounds));
    case 'terrain' when terrainExtent != null:
      world = terrainExtent();
      if (world.isEmpty) throw ToolInputError('The project has no terrain data: download_terrain (needs a georeference, set_site), import_attachment of a survey, or draw contours and spot heights.');
    case 'view':
      if (!c.camera.size.isEmpty) {
        world = c.camera.visible;
        pad = false;
      } else {
        world = b.p.bounds;
        // a georeferenced project with nothing drawn yet: the site around the origin
        if (world.isEmpty && c.project.meta.georef != null) world = const Bounds(-200, -200, 200, 200);
      }
    default:
      throw ToolInputError('Unknown region "$region".');
  }
  if (world.isEmpty) throw ToolInputError('Nothing to show: the drawing is empty. Give a bbox [minX, minY, maxX, maxY] in metres.');
  if (pad) world = world.inflate(math.max(2.0, 0.05 * math.max(world.width, world.height)));
  return pictureMinimumFrame(world);
}

/// [world] grown to what a picture can show: 20 m around a point or a
/// tiny box, and each side at least 2 m and 2 % of the other.
Bounds pictureMinimumFrame(Bounds world) {
  final cen = world.center;
  if (world.width < 2 && world.height < 2) return Bounds(cen.x - 10, cen.y - 10, cen.x + 10, cen.y + 10);
  final side = math.max(2.0, 0.02 * math.max(world.width, world.height));
  if (world.width < side) world = Bounds(cen.x - side / 2, world.minY, cen.x + side / 2, world.maxY);
  if (world.height < side) world = Bounds(world.minX, cen.y - side / 2, world.maxX, cen.y + side / 2);
  return world;
}

/// Renders [spec] (given the new picture's id) for the tools of [b],
/// registers it, and answers with the image and the text for the model:
/// the mapping, [lead], the renderer's notes, then [tail] (both written
/// once the picture is made).
Future<ToolOutput> pictureOutput(
  AgentToolbox b,
  VisionSpec Function(String id) spec, {
  required String Function(SnapshotImage img) what,
  List<String> Function(SnapshotImage img)? lead,
  List<String> Function(SnapshotImage img, SnapshotMapping m)? tail,
}) async {
  final r = switch (b.snapshots) {
    final VisionRenderer v => v,
    _ => throw ToolInputError('Pictures cannot be made here.'),
  };
  final session = VisionSession.of(b);
  final id = session.nextId('s');
  final img = await r.render(b.c, spec(id));
  final m = session.add(id, img.frame, what(img), geo: pictureGeoKey(b.c));
  final text = [m.describe(), ...?lead?.call(img), ...img.notes, ...?tail?.call(img, m)];
  return ToolOutput(text.join('\n'), images: [img.forModel]);
}

/// "the drawing over Esri World Imagery (tile zoom 18)" and the like.
String pictureWhat(SnapshotImage img, {required bool drawing, String subject = 'the drawing'}) {
  final m = img.map;
  final map = m == null ? null : '${mapSourceName(m)}${img.zoom == null ? '' : ' (tile zoom ${img.zoom})'}';
  if (!drawing) return map == null ? 'no base map' : '$map without the drawing';
  return map == null ? subject : '$subject over $map';
}

// ---------------------------------------------------------------- view_snapshot

/// The view_snapshot tool.
Future<ToolOutput> snapshotTool(AgentToolbox b, ToolArgs a) async {
  final s = b.snapshots;
  if (s == null) throw ToolInputError('Pictures of the drawing cannot be made here.');
  final c = b.c;
  final world = pictureWorld(b, a);
  final lead = <String>[];
  final size = pictureSideOf(b, a, lead);
  final asked = a.input['base_map'];
  final wantsMap = asked == true || (asked is String && asked.trim().toLowerCase() != 'none');
  var maps = pictureMapsFor(c, asked);
  final drawing = a.flag('drawing') ?? true;
  if (c.project.meta.georef == null) {
    if (wantsMap || maps.isNotEmpty) lead.add('No base map: the project has no georeference (set_site with its latitude and longitude, or ask the user).');
    maps = const [];
  } else if (asked is String && asked.trim().toLowerCase() == 'current' && c.baseMap == BaseMap.none) {
    lead.add('The screen shows no base map ("current" is none); base_map "satellite" gives the aerial image.');
  }
  if (s is! VisionRenderer) return _plainSnapshot(b, s, world, size, maps.isNotEmpty || wantsMap, drawing);
  if (!drawing && maps.isEmpty) {
    throw ToolInputError(
      c.project.meta.georef == null
          ? 'Nothing to show: drawing false needs a base map, and the project has no georeference (set_site).'
          : 'Nothing to show: drawing false needs a base map (base_map "satellite").',
    );
  }
  final grid = pictureGridOf(a);
  final labels = pictureLabelsOf(a);
  final legend = a.flag('legend') ?? false;
  final look = drawing ? PictureLook.of(b, a) : null;
  return pictureOutput(
    b,
    (id) => VisionSpec(
      world: world,
      maxSide: size,
      maxPixels: b.pictures.maxPixels,
      maxShort: b.pictures.maxShortSide,
      maps: maps,
      drawing: drawing,
      grid: grid,
      labels: labels,
      legend: legend,
      caption: id,
      tiles: VisionSession.of(b).tiles,
      nameOf: b.nameOf,
      overlay: look?.overlay,
      showLabels: look?.showLabels,
      tint: look?.tint,
      over: look?.over(c) ?? const [],
    ),
    what: (img) => pictureWhat(img, drawing: drawing),
    lead: (_) => lead,
    tail: (img, _) => [
      ...?look?.describe(c, img.frame),
      if (img.map != null && img.map != c.baseMap) 'The user\'s screen keeps its own base map (${c.baseMap == BaseMap.none ? 'none' : mapSourceName(c.baseMap)}).',
    ],
  );
}

/// view_snapshot with a renderer of plain pictures (no composite): the base
/// map and the drawing as separate images.
Future<ToolOutput> _plainSnapshot(AgentToolbox b, ViewSnapshots s, Bounds world, int size, bool wantMap, bool wantDrawing) async {
  final c = b.c;
  final session = VisionSession.of(b);
  final images = <ToolImage>[];
  final text = <String>[];
  if (wantMap) {
    final m = await s.baseMap(c, world, size);
    if (m == null) {
      text.add(
        c.project.meta.georef == null
            ? 'No base map: the project has no georeference (set_site with its latitude and longitude, or ask the user).'
            : 'The base map did not load (offline, or no map on screen): try again.',
      );
    } else {
      world = m.world;
      images.add(m.forModel);
      text.add(session.add(session.nextId('s'), m.frame, 'the base map', geo: pictureGeoKey(c)).describe());
    }
  }
  if (wantDrawing) {
    final d = await s.drawing(c, world, size);
    images.add(d.forModel);
    text.add(session.add(session.nextId('s'), d.frame, 'the drawing', geo: pictureGeoKey(c)).describe());
  }
  if (images.isEmpty) return ToolOutput(text.join('\n'), isError: true);
  return ToolOutput(text.join('\n'), images: images);
}
