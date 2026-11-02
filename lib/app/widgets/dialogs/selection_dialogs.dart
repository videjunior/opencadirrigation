/// Selection by what the items are (CAD-25): the quick-select dialog.
library;

import 'package:flutter/material.dart';

import '../../state/controller.dart';
import '../../theme.dart';
import '../../tools/edit_commands.dart';
import '../../tools/selection_filters.dart';
import '../fields.dart';

/// Quick select: the items of a kind, a layer, a catalogue item and a zone,
/// with a value in a range (length, area, elevation, pressure, bore),
/// replacing the selection, adding to it, taking them out of it or keeping
/// only them. The count of matching items follows each choice.
Future<void> showQuickSelectDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final u = c.units;
  final cat = c.project.catalog;
  final q = SelectionQuery();
  var mode = c.selection.isEmpty ? SelectionMode.replace : SelectionMode.within;
  final selectable = c.selectableEntities();
  final kinds = <String, int>{};
  for (final e in selectable) {
    final k = selectionKindOf(e);
    kinds[k] = (kinds[k] ?? 0) + 1;
  }
  String kindLabel(String k) => t.has('tool.$k') ? t('tool.$k') : k;
  final kindList = kinds.keys.toList()..sort((a, b) => kindLabel(a).compareTo(kindLabel(b)));
  final layers = [
    for (final l in c.project.layers)
      if (l.visible && !l.locked) l.name,
  ];
  String layerLabel(String l) => t.has('layer.$l') ? t('layer.$l') : l;
  final zones = zoneNames(c.project, c.results);
  // the display unit of each value, to SI and back
  (double Function(double), double Function(double), String) unitOf(SelectionProperty p) => switch (p) {
    SelectionProperty.length || SelectionProperty.elevation => (u.lengthFromSi, u.lengthToSi, u.lengthLabel),
    SelectionProperty.area => (u.areaFromSi, (v) => v / u.areaFromSi(1), u.areaLabel),
    SelectionProperty.head => (u.pressureFromHead, u.pressureToHead, u.pressureLabel),
    SelectionProperty.diameter => (u.diameterFromSi, u.diameterToSi, u.diameterLabel),
  };
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      final compact = MediaQuery.sizeOf(ctx).width < 700;
      return StatefulBuilder(
        builder: (ctx, setState) {
          final specs = <String>{
            if (q.kind != null)
              for (final e in selectable)
                if (selectionKindOf(e) == q.kind) ?specOf(e),
          }.toList()..sort();
          final n = c.queryMatches(q).length;
          final prop = q.property;
          final unit = prop == null ? null : unitOf(prop);
          return AlertDialog(
            title: Text(t('qs.title'), style: const TextStyle(fontSize: 15)),
            content: SizedBox(
              width: compact ? MediaQuery.sizeOf(ctx).width - 48 : 440,
              child: ScrollBody(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SpecDropdown<String>(
                      key: const Key('qs_kind'),
                      label: t('qs.kind'),
                      value: q.kind,
                      items: kindList,
                      labelOf: (k) => '${kindLabel(k)} (${kinds[k]})',
                      idOf: (k) => k,
                      allowNull: true,
                      nullLabel: t('qs.any'),
                      onChanged: (v) => setState(() {
                        q.kind = v;
                        q.spec = null;
                      }),
                    ),
                    SpecDropdown<String>(
                      key: const Key('qs_layer'),
                      label: t('props.layer'),
                      value: q.layer,
                      items: layers,
                      labelOf: layerLabel,
                      idOf: (l) => l,
                      allowNull: true,
                      nullLabel: t('qs.any'),
                      onChanged: (v) => setState(() => q.layer = v),
                    ),
                    if (specs.isNotEmpty)
                      SpecDropdown<String>(
                        key: ValueKey('qs_spec_${q.kind}'),
                        label: t('qs.spec'),
                        value: q.spec,
                        items: specs,
                        labelOf: (id) => specLabel(cat, q.kind!, id, auto: t('auto')),
                        idOf: (id) => id,
                        allowNull: true,
                        nullLabel: t('qs.any'),
                        onChanged: (v) => setState(() => q.spec = v),
                      ),
                    if (zones.isNotEmpty)
                      SpecDropdown<String>(
                        key: const Key('qs_zone'),
                        label: t('props.zone'),
                        value: q.zone,
                        items: zones,
                        labelOf: (z) => z,
                        idOf: (z) => z,
                        allowNull: true,
                        nullLabel: t('qs.any'),
                        onChanged: (v) => setState(() => q.zone = v),
                      ),
                    SpecDropdown<SelectionProperty>(
                      key: const Key('qs_property'),
                      label: t('qs.property'),
                      value: q.property?.name,
                      items: SelectionProperty.values,
                      labelOf: (p) => '${t('qs.prop.${p.name}')} (${unitOf(p).$3})',
                      idOf: (p) => p.name,
                      allowNull: true,
                      nullLabel: t('qs.prop.none'),
                      onChanged: (v) => setState(() {
                        q.property = v == null ? null : SelectionProperty.values.byName(v);
                        q.min = null;
                        q.max = null;
                      }),
                    ),
                    if (unit != null)
                      Row(
                        children: [
                          Expanded(
                            child: NumField(
                              key: ValueKey('qs_min_${prop!.name}'),
                              label: '${t('qs.min')} (${unit.$3})',
                              value: q.min == null ? double.nan : unit.$1(q.min!),
                              onChanged: (v) => setState(() => q.min = unit.$2(v)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: NumField(
                              key: ValueKey('qs_max_${prop.name}'),
                              label: '${t('qs.max')} (${unit.$3})',
                              value: q.max == null ? double.nan : unit.$1(q.max!),
                              onChanged: (v) => setState(() => q.max = unit.$2(v)),
                            ),
                          ),
                        ],
                      ),
                    SpecDropdown<SelectionMode>(
                      key: const Key('qs_mode'),
                      label: t('qs.mode'),
                      value: mode.name,
                      items: [
                        SelectionMode.replace,
                        SelectionMode.add,
                        if (c.selection.isNotEmpty) ...[SelectionMode.remove, SelectionMode.within],
                      ],
                      labelOf: (m) => t('qs.mode.${m.name}'),
                      idOf: (m) => m.name,
                      onChanged: (v) => setState(() => mode = SelectionMode.values.byName(v ?? 'replace')),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      t('qs.matches', {'n': '$n'}),
                      key: const Key('qs_count'),
                      style: TextStyle(fontSize: 12, color: n == 0 ? Cad.warning : Cad.fg70),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('cancel'))),
              FilledButton(
                key: const Key('qs_apply'),
                onPressed: () {
                  final size = c.selectByQuery(q, mode: mode);
                  c.notify(t('mob.selection', {'n': '$size'}));
                  Navigator.pop(ctx);
                },
                child: Text(t('qs.apply')),
              ),
            ],
          );
        },
      );
    },
  );
}
