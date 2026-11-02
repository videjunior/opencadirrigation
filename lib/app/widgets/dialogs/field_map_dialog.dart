/// View → Base map → Keep the map of the area for the field (1.6.0, PRD-09): says what the terms of the base map on
/// screen allow (the tiles already shown, the user's own server downloaded, or nothing for the Google maps), then
/// keeps the map of the area as a picture of the project (lib/app/io/field_map.dart).
library;

import 'package:flutter/material.dart';

import '../../ai/vision_tiles.dart' show mapSourceName;
import '../../canvas/seen_tiles.dart';
import '../../io/field_map.dart';
import '../../state/controller.dart';
import '../../theme.dart';
import '../fields.dart';
import 'terrain_dialogs.dart' show dialogWidth;

Future<void> showFieldMapDialog(BuildContext context, ProjectController c) async {
  final t = c.t;
  final how = fieldMapSource(c.baseMap);
  final geo = c.project.meta.georef != null;
  final ready = geo && how != FieldMapSource.refused;
  final what = !geo
      ? t('fieldmap.err.noGeo')
      : how == FieldMapSource.refused
      ? t(c.baseMap == BaseMap.none ? 'fieldmap.err.noMap' : 'fieldmap.err.google')
      : t('fieldmap.how.${how.name}', {'m': mapSourceName(c.baseMap), 'n': '${seenTiles.length}'});
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(t('fieldmap.title'), style: const TextStyle(fontSize: 15)),
      content: SizedBox(
        width: dialogWidth(ctx, 560),
        child: ScrollBody(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t('fieldmap.explain'), style: TextStyle(fontSize: 12, color: Cad.fg70)),
              const SizedBox(height: 8),
              Text(what, key: const Key('fieldmap_what'), style: TextStyle(fontSize: 12, color: ready ? null : Cad.warning)),
              const SizedBox(height: 6),
              Text(t('fieldmap.tip'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('cancel'))),
        FilledButton(key: const Key('fieldmap_keep'), onPressed: ready ? () => Navigator.pop(ctx, true) : null, child: Text(t('fieldmap.keep'))),
      ],
    ),
  );
  if (ok != true) return;
  try {
    final r = await keepFieldMap(c);
    c.notify('${t('fieldmap.done', {'m': mapSourceName(c.baseMap), 'n': '${r.tiles}'})}${r.missing > 0 ? ' ${t('fieldmap.missing', {'n': '${r.missing}'})}' : ''}');
  } on FieldMapError catch (e) {
    c.notify(t(e.key));
  }
}
