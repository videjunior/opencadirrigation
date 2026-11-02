/// The reservoir or dam behind a water supply (1.6.0 MOT+, PRD-16): the
/// closed outline of the drawing that bounds it, how its basin is made
/// (the ground of a dam or pond, or an excavation with sloping sides), its
/// levels and its inflow, with the stage–area–volume curve worked out from
/// the terrain model (`design/reservoir.dart`), the volume between the
/// lowest and the full level, the earth an excavation takes out, the days of
/// demand it holds and the time the inflow takes to fill it. The 24-hour
/// simulation lets its level fall and rise. The changes are one undo step.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/reservoir.dart';
import '../../../core/model/entities.dart';
import '../../state/controller.dart';
import '../../theme.dart';
import '../fields.dart';
import 'terrain_dialogs.dart' show dialogWidth;

/// The closed polylines and the areas of the drawing that can bound a
/// reservoir.
List<Entity> reservoirOutlines(ProjectController c) => [
  for (final e in c.project.entities)
    if ((e is PolylineEntity && (e.closed || (e.points.length > 3 && e.points.first.distanceTo(e.points.last) < 1e-6))) || e is AreaEntity) e,
];

Future<void> showReservoirDialog(BuildContext context, ProjectController c, WaterSupplyEntity s) {
  final t = c.t;
  final u = c.units;
  // a new reservoir full at the water level of the supply
  final work = s.reservoir?.copy() ?? ReservoirSpec(fullLevelM: c.project.buildTerrain().elevationAt(s.position) + s.waterLevelOffsetM);
  final outlines = reservoirOutlines(c);
  if (work.outlineId.isEmpty && outlines.isNotEmpty) work.outlineId = outlines.first.id;
  String lengthText(double v) => '${fmtUi(u.lengthFromSi(v), 2)} ${u.lengthLabel}';
  String vol(double v) => '${fmtUi(u.volumeFromM3(v), 1)} ${u.volumeLabel}';
  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        // the study of the reservoir as it is in the dialog
        final probe = s.clone()..reservoir = work;
        final study = reservoirStudy(c.project, probe, results: c.results, cells: 10000);
        final rows = study == null || study.curve.isEmpty
            ? const <ReservoirStage>[]
            : [
                for (var i = 0; i < study.curve.length; i += math.max(1, study.curve.length ~/ 6)) study.curve[i],
                if ((study.curve.length - 1) % math.max(1, study.curve.length ~/ 6) != 0) study.curve.last,
              ];
        return AlertDialog(
          title: Text('${t('res.title')}${s.name.isEmpty ? '' : ' — ${s.name}'}', style: const TextStyle(fontSize: 15)),
          content: SizedBox(
            width: dialogWidth(ctx, 640),
            child: ScrollBody(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('res.hint'), style: TextStyle(fontSize: 11.5, color: Cad.fg70)),
                  SpecDropdown<Entity>(
                    key: const Key('res_outline'),
                    label: t('res.outline'),
                    value: work.outlineId.isEmpty ? null : work.outlineId,
                    items: outlines,
                    labelOf: (e) => e.name.isEmpty ? '${t('tool.${ProjectController.toolKeyOf(e)}')} ${e.id}' : e.name,
                    idOf: (e) => e.id,
                    allowNull: true,
                    nullLabel: t('res.noOutline'),
                    onChanged: (v) => setState(() => work.outlineId = v ?? ''),
                  ),
                  SpecDropdown<ReservoirKind>(
                    key: const Key('res_kind'),
                    label: t('res.kind'),
                    value: work.kind.name,
                    items: ReservoirKind.values,
                    labelOf: (k) => t('res.kind.${k.name}'),
                    idOf: (k) => k.name,
                    onChanged: (v) => setState(() => work.kind = ReservoirKind.values.firstWhere((k) => k.name == v, orElse: () => ReservoirKind.terrain)),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      SizedBox(
                        width: 180,
                        child: NumField(key: const Key('res_full'), label: '${t('res.full')} (${u.lengthLabel})', value: u.lengthFromSi(work.fullLevelM), onChanged: (v) => setState(() => work.fullLevelM = u.lengthToSi(v))),
                      ),
                      SizedBox(
                        width: 180,
                        child: NumField(
                          key: const Key('res_min'),
                          label: '${t('res.min')} (${u.lengthLabel})',
                          value: u.lengthFromSi(work.minLevelM ?? 0),
                          onChanged: (v) => setState(() => work.minLevelM = v == 0 ? null : u.lengthToSi(v)),
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        child: NumField(
                          key: const Key('res_init'),
                          label: '${t('res.initial')} (${u.lengthLabel})',
                          value: u.lengthFromSi(work.initialLevelM ?? 0),
                          onChanged: (v) => setState(() => work.initialLevelM = v == 0 ? null : u.lengthToSi(v)),
                        ),
                      ),
                      if (work.kind == ReservoirKind.excavated) ...[
                        SizedBox(
                          width: 180,
                          child: NumField(
                            key: const Key('res_bottom'),
                            label: '${t('res.bottom')} (${u.lengthLabel})',
                            value: u.lengthFromSi(work.bottomM ?? 0),
                            onChanged: (v) => setState(() => work.bottomM = v == 0 ? null : u.lengthToSi(v)),
                          ),
                        ),
                        SizedBox(
                          width: 180,
                          child: NumField(key: const Key('res_slope'), label: t('res.slope'), value: work.sideSlope, onChanged: (v) => setState(() => work.sideSlope = v.clamp(0, 20).toDouble())),
                        ),
                      ],
                      SizedBox(
                        width: 180,
                        child: NumField(
                          key: const Key('res_inflow'),
                          label: '${t('res.inflow')} (${u.flowLabel})',
                          value: u.flowFromSi(work.inflow),
                          onChanged: (v) => setState(() => work.inflow = v <= 0 ? 0 : u.flowToSi(v)),
                        ),
                      ),
                    ],
                  ),
                  SectionTitle(t('res.study')),
                  if (study == null || study.curve.isEmpty)
                    Text(t('res.noOutline'), style: TextStyle(fontSize: 11.5, color: Cad.warning))
                  else ...[
                    for (final m in study.messages) Text(t.warning(m, entityName: c.entityName), style: TextStyle(fontSize: 11, color: Cad.warning)),
                    KV(t('res.bottomFound'), lengthText(study.bottom)),
                    KV(t('res.surface'), '${fmtUi(u.areaFromSi(study.surfaceArea), 2)} ${u.areaLabel}'),
                    KV(t('res.volume'), vol(study.volume)),
                    KV(t('res.usable'), vol(study.usableVolume)),
                    if (work.kind == ReservoirKind.excavated) KV(t('res.cut'), vol(study.cut)),
                    KV(t('res.daily'), c.results == null ? t('res.needDesign') : vol(study.dailyDemand)),
                    if (c.results != null && study.dailyDemand > 0) KV(t('res.autonomy'), study.autonomyDays.isFinite ? fmtUi(study.autonomyDays, 1) : '∞'),
                    if (study.inflow > 0) KV(t('res.fill'), '${fmtUi(study.fillHours, 1)} h'),
                    const SizedBox(height: 4),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Table(
                        defaultColumnWidth: const IntrinsicColumnWidth(),
                        children: [
                          TableRow(
                            children: [
                              _cell('${t('res.level')} (${u.lengthLabel})', bold: true),
                              _cell('${t('res.surface')} (${u.areaLabel})', bold: true),
                              _cell('${t('res.volume')} (${u.volumeLabel})', bold: true),
                            ],
                          ),
                          for (final r in rows)
                            TableRow(children: [_cell(fmtUi(u.lengthFromSi(r.level), 2)), _cell(fmtUi(u.areaFromSi(r.area), 3)), _cell(fmtUi(u.volumeFromM3(r.volume), 1))]),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            if (s.reservoir != null)
              TextButton(
                key: const Key('res_remove'),
                onPressed: () {
                  c.mutate(() => s.reservoir = null, label: 'hist.reservoir');
                  Navigator.pop(ctx);
                },
                child: Text(t('res.remove')),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('cancel'))),
            FilledButton(
              key: const Key('res_apply'),
              onPressed: () {
                c.mutate(() => s.reservoir = work, label: 'hist.reservoir');
                Navigator.pop(ctx);
              },
              child: Text(t('apply')),
            ),
          ],
        );
      },
    ),
  );
}

Widget _cell(String s, {bool bold = false}) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
  child: Text(s, style: TextStyle(fontSize: 11.5, fontWeight: bold ? FontWeight.w600 : null)),
);
