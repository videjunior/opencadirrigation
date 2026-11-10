/// Operations (find_operations / run_operation) added in 1.7.0 for the crop
/// rows read from the aerial image (Design → Automatic design → Crop rows
/// from the image): [OpTool]s built like those of lib/app/ai/ops_cad_*.dart,
/// joined to [AgentToolbox.operations].
library;

import '../../../core/ai/agent_loop.dart';
import '../../../core/design/crop_rows.dart';
import '../../../core/model/entities.dart';
import '../../../core/units.dart' show fmt;
import '../../io/crop_row_pixels.dart';
import '../agent_tools.dart';
import '../ops_cad_common.dart' show cadOp;
import '../vision_render.dart' show VisionRenderer;

/// The field named by input "area" (id or name), or the selection, or the
/// only irrigated area of the project.
CropRowField _field(AgentToolbox b, ToolArgs a) {
  final ref = a.str('area');
  final f = ref == null || ref.isEmpty ? cropRowField(b.c) : cropRowField(b.c, entity: b.find(ref));
  if (f == null) {
    throw ToolInputError(
      ref == null || ref.isEmpty
          ? 'Give "area": the id of the irrigated area (or closed outline) of the planted field (list_entities with type area lists them).'
          : '"$ref" is not a closed outline: give an irrigated area or a closed polyline, circle or hatch.',
    );
  }
  return f;
}

CropRowOptions _options(ToolArgs a) =>
    CropRowOptions(minSpacingM: a.number('min_spacing_m', min: 0.3, max: 40) ?? 1.5, maxSpacingM: a.number('max_spacing_m', min: 0.5, max: 60) ?? 12, otherBand: a.flag('other_band') ?? false);

/// Reads the rows of [f] (see detect_crop_rows), keeping the reading in the
/// session of the tab.
Future<(CropRowResult, CropRowPixels)> _read(AgentToolbox b, CropRowField f, ToolArgs a) async {
  final c = b.c;
  final source = a.str('source') ?? 'map';
  ImageEntity? photo;
  if (source != 'map') {
    final e = b.find(source);
    if (e is! ImageEntity) throw ToolInputError('"$source" is not an image placed in the drawing: give "map" or the id of an aerial photo.');
    photo = e;
  }
  final renderer = switch (b.snapshots) {
    final VisionRenderer v => v,
    _ => CropRowSession.renderer,
  };
  final session = CropRowSession.of(c);
  final CropRowPixels px;
  try {
    px = await cropRowPixels(c, f, _options(a), renderer: renderer, tiles: session.tiles, photo: photo);
  } on CropRowSourceError catch (e) {
    throw ToolInputError(switch (e.key) {
      'wand.noGeoref' => 'The project has no georeference, so there is no satellite image of the field: set_site first (find_site gives the coordinates of an address), or give "source" an aerial photo placed in the drawing.',
      'row.noImagery' => 'The aerial imagery could not be loaded here (offline, or no imagery in this region): nothing to read.',
      _ => 'The image has no pixels embedded in the project.',
    });
  }
  final r = await detectCropRows(px.raster, f.outline, holes: f.holes, options: _options(a));
  session
    ..last = r
    ..lastId = f.entity.id;
  return (r, px);
}

String _describe(CropRowResult r, CropRowPixels px, CropRowField f) {
  final n = AgentToolbox.n;
  final lines = <String>[
    'Field ${f.entity.id}${f.entity is AreaEntity ? ' (irrigated area)' : ' (outline, not an area)'}; ${f.holes.length} hole(s) left out. Imagery ${n(r.resolutionM, 2)} m per pixel, ${px.raster.width} × ${px.raster.height} px${px.frame.window ? ', a window of ${n(px.frame.world.width, 0)} × ${n(px.frame.world.height, 0)} m in the middle of the field (rows extended over the whole field)' : ''}${px.credit.isEmpty ? '' : '; imagery credit: ${px.credit}'}.',
    'Verdict: ${r.verdict.name} (confidence ${n(r.confidence, 2)}: angular prominence ${n(r.angularContrast, 2)} × periodicity ${n(r.periodicity, 2)}; rows found from ${n(confidenceRows, 2)}, uncertain from ${n(confidenceUncertain, 2)}).',
    if (r.found) ...[
      'direction_deg ${fmt(r.directionDeg, 2)} (counter-clockwise from east, the direction_deg of subdivide_field, field_blocks_advanced, tree_rings and generate_block), row spacing ${fmt(r.spacingM, 3)} m, ${r.rows} rows across the field.',
      'Plant spacing in the row: ${r.plantSpacingM == null ? 'not visible' : '${fmt(r.plantSpacingM!, 2)} m'}; canopy ground cover: ${r.groundCover == null ? 'not separable in the image' : fmt(r.groundCover!, 2)}; the crop band takes ${n(r.bandShare * 100, 0)} % of the spacing${r.swapped ? ' (the rows lie on the band the colour did not favour: a closed canopy with shaded alleys, or other_band)' : ''}.',
    ],
    for (final m in r.messages) 'Remark ${m.code}${m.args.isEmpty ? '' : ' ${m.args.map((k, v) => MapEntry(k, fmt(v, 2)))}'}.',
    if (r.found) 'Look at it (view_snapshot over the field with the satellite map): when the lines fall on the alleys rather than on the plants, run again with other_band true. apply_crop_rows writes it into the project.',
  ];
  return lines.join('\n');
}

List<AgentTool> opsRow(AgentToolbox b) {
  final c = b.c;
  final common = <String, Object?>{
    'area': str('Id or name of the irrigated area (or closed outline) of the planted field; default the selection, or the only area of the project.'),
    'source': str(
      '"map" (default): the satellite base map (the map on screen when it is imagery, else Google satellite with the user\'s key, else Esri World Imagery); or the id of an aerial photo placed in the drawing.',
    ),
    'min_spacing_m': num_('Closest row spacing looked for, 0.3–40 m (default 1.5); it also sets the pixel size asked of the imagery.'),
    'max_spacing_m': num_('Widest row spacing looked for, 0.5–60 m (default 12).'),
    'other_band': bool_('Put the rows on the other band, half a spacing over (when the first reading put them on the alleys).'),
  };
  return [
    cadOp(
      b,
      group: 'engineering',
      name: 'detect_crop_rows',
      description: 'Design → Automatic design → Crop rows from the image: reads on the aerial image of a field (orchard, coffee, vineyard, citrus, olive…) the direction of its planting rows, their spacing, how many rows cross it and how sure the reading is (confidence 0–1, verdict rows|uncertain|none|noData), plus the plant spacing along the rows and the canopy ground cover where the image shows them. Plain image processing (a projection scan over the directions and the autocorrelation of the profile across the rows), no model. Needs a georeference and the online imagery (or an aerial photo placed in the drawing). Changes nothing; apply_crop_rows writes the result. Output: direction_deg, spacing, rows, confidence and the remarks.',
      schema: obj(common),
      run: (a, _) async {
        final f = _field(b, a);
        final (r, px) = await _read(b, f, a);
        return ToolOutput(_describe(r, px, f));
      },
    ),
    cadOp(
      b,
      group: 'engineering',
      name: 'apply_crop_rows',
      effect: ToolEffect.write,
      description: 'Crop rows from the image, applied in one undo step: reads the rows as detect_crop_rows does (same inputs; the reading of the field the last detect_crop_rows made is reused when the inputs are the same) and writes them: set_rows (default true) sets the area\'s row direction (rdir), row spacing (rsp) and plant spacing (psp, when read) — the defaults of Field blocks, Tree rings and Block over that area, in the dialogs and in subdivide_field, field_blocks_advanced, tree_rings and generate_block; set_cover (default true) its canopy ground cover (gc, when read); guides (default false) the rows as lines on the CROP_ROWS layer (a laterals guide for generate_block). Refused when no rows were found. Output: what was set.',
      schema: obj({
        ...common,
        'set_rows': bool_('Set the area\'s row direction, row spacing and plant spacing (default true).'),
        'set_cover': bool_('Set the area\'s ground cover (default true).'),
        'guides': bool_('Draw the rows as lines on the CROP_ROWS layer (default false).'),
      }),
      run: (a, _) async {
        final f = _field(b, a);
        final (r, _) = await _read(b, f, a);
        if (!r.found) {
          throw ToolInputError(
            'No rows were found in the image of ${f.entity.id} (verdict ${r.verdict.name}, confidence ${AgentToolbox.n(r.confidence, 2)}): nothing applied. ${r.messages.map((m) => m.code).join(', ')}',
          );
        }
        final area = f.area;
        final rows = (a.flag('set_rows') ?? true) && area != null;
        final cover = (a.flag('set_cover') ?? true) && area != null && r.groundCover != null;
        final guides = a.flag('guides') ?? false;
        if (!rows && !cover && !guides) {
          throw ToolInputError(area == null ? '${f.entity.id} is not an irrigated area: only guides can be drawn (guides true).' : 'Nothing to apply: set_rows, set_cover and guides are all off.');
        }
        final made = b.change('apply_crop_rows', () => applyCropRows(b.p, f.entity, r, rows: rows, cover: cover, guides: guides));
        if (made.isNotEmpty) c.select(made.map((e) => e.id));
        return ToolOutput(
          [
            if (rows) '${f.entity.id}: row direction ${fmt(r.directionDeg, 2)}°, row spacing ${fmt(r.spacingM, 3)} m${r.plantSpacingM == null ? '' : ', plant spacing ${fmt(r.plantSpacingM!, 2)} m'}.',
            if (cover) '${f.entity.id}: ground cover ${fmt(r.groundCover!, 2)}.',
            if (guides) '${made.length} guide lines on layer $cropRowLayer (selected).',
            if (!cover && (a.flag('set_cover') ?? true) && area != null) 'The ground cover could not be read from the image: left as it was.',
          ].join('\n'),
        );
      },
    ),
  ];
}
