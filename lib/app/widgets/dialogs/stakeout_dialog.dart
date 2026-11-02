/// File → Export drawing → Stake-out points: the list a total station or a
/// GNSS RTK receiver loads directly (P,N,E,Z,D or P,E,N,Z,D), with the
/// kinds of points to include, the first number and the decimals, and the
/// count, the coordinate system and whether the elevations are known
/// shown before the file is written (lib/core/io/stakeout.dart).
library;

import 'package:flutter/material.dart';

import '../../../core/io/stakeout.dart';
import '../../../core/model/entities.dart';
import '../../actions.dart' show deliverExport;
import '../../state/controller.dart';
import '../../theme.dart';
import '../fields.dart';
import 'terrain_dialogs.dart' show dialogWidth;

/// The description (D column) of a point of [kind]: short, in capitals and
/// without accents (surveying instruments show ASCII).
String stakeoutLabel(ProjectController c, StakeoutKind kind) => c.t('stake.desc.${kind.name}');

/// The points of the project with the options of the dialog.
List<StakeoutPoint> stakeoutPointsOf(ProjectController c, Set<StakeoutKind> kinds, {int firstNumber = 1}) =>
    stakeoutPoints(c.project, kinds: kinds, firstNumber: firstNumber, label: (k, Entity _) => stakeoutLabel(c, k));

/// The file name of the list of [c]'s project.
String stakeoutFileName(ProjectController c) {
  final n = c.project.meta.name.trim();
  final stem = (n.isEmpty ? c.t('name.newProject') : n).replaceAll(RegExp(r'[^\w\-]+', unicode: true), '_');
  return '${stem}_${c.t('stake.file')}.csv';
}

Future<void> showStakeoutDialog(BuildContext context, ProjectController c) async {
  final t = c.t;
  var order = StakeoutOrder.pnezd;
  final kinds = {StakeoutKind.outlets, StakeoutKind.valves, StakeoutKind.devices, StakeoutKind.pipeVertices};
  var first = 1.0;
  var decimals = 3;
  final hasTerrain = c.project.entities.any((e) => e is SpotHeightEntity || (e is ContourEntity && !e.derived) || e is BreaklineEntity);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final points = stakeoutPointsOf(c, kinds, firstNumber: first.round());
        Widget note(String s, {Key? key}) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(s, key: key, style: TextStyle(fontSize: 11.5, color: Cad.attention)),
        );
        return AlertDialog(
          title: Text(t('stake.title'), style: const TextStyle(fontSize: 15)),
          content: SizedBox(
            width: dialogWidth(ctx, 460),
            child: ScrollBody(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('stake.explain'), style: TextStyle(fontSize: 12, color: Cad.fg70)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<StakeoutOrder>(
                    key: const Key('stake_order'),
                    isExpanded: true,
                    initialValue: order,
                    decoration: InputDecoration(labelText: t('stake.order'), isDense: true),
                    style: TextStyle(fontSize: 12, color: Cad.fg),
                    items: [
                      for (final o in StakeoutOrder.values) DropdownMenuItem(value: o, child: Text(o.name.toUpperCase(), style: const TextStyle(fontSize: 12))),
                    ],
                    onChanged: (v) => setState(() => order = v ?? order),
                  ),
                  const SizedBox(height: 4),
                  for (final k in StakeoutKind.values)
                    CheckboxListTile(
                      key: Key('stake_kind_${k.name}'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(t('stake.kind.${k.name}'), style: const TextStyle(fontSize: 12)),
                      value: kinds.contains(k),
                      onChanged: (v) => setState(() => v == true ? kinds.add(k) : kinds.remove(k)),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: NumField(key: const Key('stake_first'), label: t('stake.firstNumber'), value: first, decimals: 0, signed: false, onChanged: (v) => setState(() => first = v.clamp(0, 1e9).toDouble())),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          key: const Key('stake_decimals'),
                          isExpanded: true,
                          initialValue: decimals,
                          decoration: InputDecoration(labelText: t('stake.decimals'), isDense: true),
                          style: TextStyle(fontSize: 12, color: Cad.fg),
                          items: [
                            for (final d in const [2, 3, 4]) DropdownMenuItem(value: d, child: Text('$d', style: const TextStyle(fontSize: 12))),
                          ],
                          onChanged: (v) => setState(() => decimals = v ?? decimals),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(points.isEmpty ? t('stake.none') : t('stake.count', {'n': '${points.length}'}), key: const Key('stake_count'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  if (c.project.meta.georef == null) note(t('stake.noGeoref'), key: const Key('stake_no_georef')),
                  if (!hasTerrain) note(t('stake.noTerrain'), key: const Key('stake_no_terrain')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('cancel'))),
            FilledButton(key: const Key('stake_export'), onPressed: points.isEmpty ? null : () => Navigator.pop(ctx, true), child: Text(t('stake.export'))),
          ],
        );
      },
    ),
  );
  if (ok != true) return;
  final text = stakeoutCsv(stakeoutPointsOf(c, kinds, firstNumber: first.round()), order: order, decimals: decimals);
  await deliverExport(c, stakeoutFileName(c), 'text/csv', () => text);
}
