/// Fields of the properties panel for the editing tools added in 1.6.0:
/// the coordinates of the selected item.
library;

import 'package:flutter/material.dart';

import '../../core/model/entities.dart';
import '../../core/model/geometry.dart';
import '../state/controller.dart';
import 'fields.dart';

/// Vertices listed with their coordinates; the others are edited with the
/// grips on the drawing.
const maxCoordinateRows = 40;

/// X and Y of [e] in the display unit (CAD-06): the position of a point
/// item, the ends of a line or a linear dimension, the centre of a circle,
/// an arc or a pivot, the vertices of a polyline-like item. A new value
/// moves that grip as dragging it does: one undo step, and the pipes and
/// items joined there go along when "keep connections" is on.
List<Widget> coordinateFields(ProjectController c, Entity e) {
  final t = c.t;
  final rows = <(String, int)>[
    ...switch (e) {
      PointEntity _ || OrdinateDimensionEntity _ => [(t('xy.position'), 0)],
      LineEntity _ || DimensionEntity _ => [(t('xy.start'), 0), (t('xy.end'), 1)],
      CircleEntity _ || ArcEntity _ || PivotEntity _ || RadialDimensionEntity _ => [(t('xy.center'), 0)],
      PolyEntity p => [
        for (var i = 0; i < p.points.length && i < maxCoordinateRows; i++) (t('xy.vertex', {'n': '${i + 1}'}), i),
      ],
      _ => const <(String, int)>[],
    },
  ];
  if (rows.isEmpty) return const [];
  final grips = e.grips;
  final locked = c.project.isLocked(e.layer);
  return [
    SectionTitle(e is PolyEntity ? t('xy.vertices') : t('xy.position')),
    for (final (title, grip) in rows)
      if (grip < grips.length) _CoordinateRow(key: ValueKey('xy_${e.id}_$grip'), c: c, id: e.id, grip: grip, title: title, at: grips[grip], enabled: !locked),
    if (e is PolyEntity && e.points.length > maxCoordinateRows) Text(t('xy.more', {'n': '${e.points.length - maxCoordinateRows}'}), style: const TextStyle(fontSize: 11)),
  ];
}

/// Moves grip [grip] of item [id] to [p], with the joints when it is a
/// pipe-like item (the select tool's grip drag does the same).
void setGripFromPanel(ProjectController c, String id, int grip, Pt p) {
  final e = c.project.byId(id);
  final g = e?.grips;
  if (e == null || g == null || grip >= g.length) return;
  // a field commits on Enter and again when it loses the focus: the same
  // point twice is one edit, not two undo steps
  if (g[grip].distanceTo(p) < 1e-12) return;
  c.setGrip(id, grip, p, keepConnections: c.toolSettings.keepConnections && (e is PolyEntity || e is LineEntity));
}

class _CoordinateRow extends StatelessWidget {
  const _CoordinateRow({super.key, required this.c, required this.id, required this.grip, required this.title, required this.at, required this.enabled});
  final ProjectController c;
  final String id;
  final int grip;
  final String title;
  final Pt at;
  final bool enabled;

  /// The grip as the project holds it now (the panel may be older).
  Pt _current() {
    final g = c.project.byId(id)?.grips;
    return g != null && grip < g.length ? g[grip] : at;
  }

  @override
  Widget build(BuildContext context) {
    final u = c.units;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          width: 70,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(title, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
          ),
        ),
        Expanded(
          child: NumField(
            key: Key('xy_${id}_${grip}_x'),
            label: 'X (${u.lengthLabel})',
            value: u.lengthFromSi(at.x),
            decimals: 3,
            enabled: enabled,
            onChanged: (v) => setGripFromPanel(c, id, grip, Pt(u.lengthToSi(v), _current().y)),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: NumField(
            key: Key('xy_${id}_${grip}_y'),
            label: 'Y (${u.lengthLabel})',
            value: u.lengthFromSi(at.y),
            decimals: 3,
            enabled: enabled,
            onChanged: (v) => setGripFromPanel(c, id, grip, Pt(_current().x, u.lengthToSi(v))),
          ),
        ),
      ],
    );
  }
}
