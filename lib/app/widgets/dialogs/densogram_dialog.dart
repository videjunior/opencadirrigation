/// Densogram dialog (Zone → Densogram): options, uniformity of the water
/// applied by the sprinklers and the map on the drawing.
library;

import 'package:flutter/material.dart';

import '../../../core/design/densogram.dart';
import '../../../core/model/entities.dart';
import '../../../core/units.dart';
import '../../io/file_io.dart';
import '../../state/controller.dart';
import '../../theme.dart';
import '../fields.dart';
import 'terrain_dialogs.dart' show dialogWidth;

Future<void> showDensogramDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final o = c.densogramOptions;
  final valves = c.project.entities.whereType<ControlValveEntity>().toList();
  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      final d = c.densogram;
      final s = d.stats;
      final hasResults = c.results != null;
      Widget kv(String k, String v, {Color? color}) => KV(k, v, color: color);
      Color grade(double v, double good, double fair) => v >= good ? CadColors.ok : (v >= fair ? CadColors.warning : CadColors.unconnected);
      return AlertDialog(
        title: Text(t('dens.title'), style: const TextStyle(fontSize: 15)),
        content: SizedBox(
          width: dialogWidth(ctx, 460),
          child: ScrollBody(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t('dens.hint'), style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
              const SizedBox(height: 6),
              SpecDropdown<SprayProfile>(key: const Key('dens_profile'), label: t('dens.profile'), value: o.profile.name, items: SprayProfile.values, labelOf: (p) => t(sprayProfileKey(p)), idOf: (p) => p.name, onChanged: (v) => setState(() => o.profile = SprayProfile.values.byName(v!))),
              NumField(key: const Key('dens_cell'), label: t('dens.cell'), value: o.cellSize, onChanged: (v) => setState(() => o.cellSize = v < 0 ? 0 : v)),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(t('dens.useResults'), style: const TextStyle(fontSize: 12)),
                subtitle: hasResults ? null : Text(t('dens.noResults'), style: const TextStyle(fontSize: 10.5, color: Colors.white54)),
                value: o.useResults && hasResults,
                onChanged: hasResults ? (v) => setState(() => o.useResults = v) : null,
              ),
              if (valves.isNotEmpty) ...[
                Text(t('dens.zones'), style: const TextStyle(fontSize: 11.5, color: Colors.white60)),
                Wrap(spacing: 4, runSpacing: 2, children: [
                  FilterChip(key: const Key('dens_all'), label: Text(t('name.allZones'), style: const TextStyle(fontSize: 11)), selected: o.valveIds == null, onSelected: (_) => setState(() => o.valveIds = null)),
                  for (final v in valves)
                    FilterChip(
                      label: Text(v.zoneName.isEmpty ? v.id : v.zoneName, style: const TextStyle(fontSize: 11)),
                      selected: o.valveIds?.contains(v.id) ?? false,
                      onSelected: (on) => setState(() {
                        final ids = {...?o.valveIds};
                        on ? ids.add(v.id) : ids.remove(v.id);
                        o.valveIds = ids.isEmpty ? null : ids;
                      }),
                    ),
                ]),
              ],
              SectionTitle(t('dens.results')),
              if (d.isEmpty)
                Text(t('dens.none'), style: const TextStyle(fontSize: 12, color: CadColors.warning))
              else ...[
                kv(t('dens.sources'), '${d.sources.length}'),
                kv(t('dens.target'), t(d.masked ? 'dens.targetAreas' : 'dens.targetWetted')),
                kv(t('dens.area'), '${fmt(s.areaM2, 0)} m² (${fmt(s.areaM2 / 10000, 3)} ha)'),
                kv(t('dens.cellUsed'), '${fmt(d.cell, 2)} m'),
                kv(t('dens.basis'), t(d.fromResults ? 'dens.fromResults' : 'dens.nominal')),
                kv(t('dens.mean'), '${fmt(s.mean, 2)} mm/h'),
                kv(t('dens.minMax'), '${fmt(s.min, 2)} / ${fmt(s.max, 2)} mm/h'),
                kv('CU (Christiansen)', '${fmt(s.cu, 1)} %', color: grade(s.cu, 84, 75)),
                kv('DU (${t('dens.lowQuarter')})', '${fmt(s.du, 1)} %', color: grade(s.du, 75, 65)),
                kv(t('dens.sc'), s.sc.isFinite ? fmt(s.sc, 2) : '∞', color: s.sc <= 1.3 ? CadColors.ok : (s.sc <= 1.5 ? CadColors.warning : CadColors.unconnected)),
                kv(t('dens.dry'), '${fmt(s.dryPct, 1)} %', color: s.dryPct <= 2 ? null : CadColors.warning),
                // every area against its own mean (zones of different rates)
                if (d.areas.length > 1) ...[
                  SectionTitle(t('dens.targetAreas')),
                  for (var i = 0; i < d.areas.length; i++)
                    kv(d.areas[i].name.isNotEmpty ? d.areas[i].name : '${t('tool.area')} ${i + 1}', '${fmt(d.areas[i].stats.mean, 1)} mm/h · CU ${fmt(d.areas[i].stats.cu, 0)} % · DU ${fmt(d.areas[i].stats.du, 0)} %', color: grade(d.areas[i].stats.cu, 84, 75)),
                ],
                const SizedBox(height: 4),
                Text(t('dens.scHint'), style: const TextStyle(fontSize: 10.5, color: Colors.white54)),
              ],
            ]),
          ),
        ),
        actions: [
          TextButton(key: const Key('dens_csv'), onPressed: d.isEmpty ? null : () => saveTextFile('${c.project.meta.name}_densogram.csv', d.toCsv(), mime: 'text/csv'), child: Text(t('dens.exportCsv'))),
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('close'))),
          FilledButton(key: const Key('dens_show'), onPressed: d.isEmpty ? null : () {
            c.showDensogram();
            Navigator.pop(ctx);
          }, child: Text(t('dens.show'))),
        ],
      );
    }),
  );
}
