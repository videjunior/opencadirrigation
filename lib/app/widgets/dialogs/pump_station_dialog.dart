/// The pump station of a pump item (1.6.0 MOT+, PRD-17): the pumps the
/// item stands for besides its own, joined in parallel or in series, on
/// duty or on standby, the staged start by the flow of each system flow,
/// and the operating point of every pump in each system flow of the latest
/// design. The changes are one undo step.
library;

import 'package:flutter/material.dart';

import '../../../core/design/results.dart';
import '../../../core/model/catalog.dart';
import '../../../core/model/entities.dart';
import '../../state/controller.dart';
import '../../theme.dart';
import '../fields.dart';
import 'terrain_dialogs.dart' show dialogWidth;

/// One line about the station of [p]: how many pumps on duty and on
/// standby, and how they are joined ("single pump" without a station).
String pumpStationSummary(ProjectController c, PumpEntity p) {
  final s = p.station;
  if (s == null || s.isEmpty) return c.t('pumpStation.single');
  return c.t('pumpStation.summary', {'serving': '${s.dutyCount}', 'standby': '${s.standbyCount}', 'arr': c.t('pumpStation.${s.arrangement.name}')});
}

/// The duty of the station of [entityId] in every system flow of [r].
List<(String, StationDuty)> stationDutiesOf(DesignResults? r, String entityId) => [
  for (final f in r?.systemFlows ?? const <SystemFlowResult>[])
    for (final d in f.stations)
      if (d.entityId == entityId) (f.name, d),
];

Future<void> showPumpStationDialog(BuildContext context, ProjectController c, PumpEntity p) {
  final t = c.t;
  final cat = c.project.catalog;
  final pumps = cat.pumps.where((x) => x.enabled).toList();
  final work = p.station?.copy() ?? PumpStation();
  final duties = stationDutiesOf(c.results, p.id);
  final u = c.units;
  String q(double v) => '${fmtUi(u.flowFromSi(v), 1)} ${u.flowLabel}';
  String h(double v) => '${fmtUi(u.pressureFromHead(v), 1)} ${u.pressureLabel}';
  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final lead = cat.pump(p.pumpSpecId);
        return AlertDialog(
          title: Text('${t('pumpStation.title')}${p.name.isEmpty ? '' : ' — ${p.name}'}', style: const TextStyle(fontSize: 15)),
          content: SizedBox(
            width: dialogWidth(ctx, 620),
            child: ScrollBody(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('pumpStation.hint'), style: TextStyle(fontSize: 11.5, color: Cad.fg70)),
                  const SizedBox(height: 6),
                  SpecDropdown<PumpArrangement>(
                    key: const Key('station_arrangement'),
                    label: t('pumpStation.arrangement'),
                    value: work.arrangement.name,
                    items: PumpArrangement.values,
                    labelOf: (a) => t('pumpStation.${a.name}'),
                    idOf: (a) => a.name,
                    onChanged: (v) => setState(() => work.arrangement = PumpArrangement.values.firstWhere((a) => a.name == v, orElse: () => PumpArrangement.parallel)),
                  ),
                  SwitchListTile(
                    key: const Key('station_staged'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(t('pumpStation.staged'), style: const TextStyle(fontSize: 12)),
                    subtitle: Text(t('pumpStation.stagedHint'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
                    value: work.staged,
                    onChanged: (v) => setState(() => work.staged = v),
                  ),
                  SectionTitle(t('pumpStation.pumps')),
                  KV(t('pumpStation.lead'), lead?.name ?? '—'),
                  for (var i = 0; i < work.units.length; i++)
                    Row(
                      key: Key('station_unit_$i'),
                      children: [
                        Expanded(
                          child: SpecDropdown<PumpSpec>(
                            label: t('pumpStation.unit', {'n': '${i + 2}'}),
                            value: work.units[i].specId,
                            items: pumps,
                            labelOf: (x) => x.name,
                            idOf: (x) => x.id,
                            allowNull: true,
                            nullLabel: t('pumpStation.sameModel'),
                            onChanged: (v) => setState(() => work.units[i].specId = v),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(t('pumpStation.standby'), style: const TextStyle(fontSize: 10.5)),
                            Switch(key: Key('station_standby_$i'), value: work.units[i].standby, onChanged: (v) => setState(() => work.units[i].standby = v)),
                          ],
                        ),
                        IconButton(
                          key: Key('station_remove_$i'),
                          tooltip: t('pumpStation.remove'),
                          icon: const Icon(Icons.remove_circle_outline, size: 20),
                          onPressed: () => setState(() => work.units.removeAt(i)),
                        ),
                      ],
                    ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      key: const Key('station_add'),
                      onPressed: work.units.length >= 11 ? null : () => setState(() => work.units.add(PumpUnit())),
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(t('pumpStation.add'), style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                  KV(
                    t('pumpStation.title'),
                    work.isEmpty
                        ? t('pumpStation.single')
                        : t('pumpStation.summary', {'serving': '${work.dutyCount}', 'standby': '${work.standbyCount}', 'arr': t('pumpStation.${work.arrangement.name}')}),
                  ),
                  SectionTitle(t('pumpStation.duty')),
                  if (duties.isEmpty)
                    Text(t('pumpStation.noResults'), style: TextStyle(fontSize: 11.5, color: Cad.fg54))
                  else
                    for (final (flow, d) in duties) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '$flow: ${t('pumpStation.running', {'n': '${d.running}', 'serving': '${d.duty}'})} · ${q(d.flow)} · ${h(d.head)} · ${fmtUi(d.powerKw, 1)} kW',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                      for (final x in d.units)
                        Text(
                          '  ${t('pumpStation.unit', {'n': '${x.index}'})} (${x.name}): ${x.standby ? t('pumpStation.standby') : (x.running ? '${q(x.flow)} · ${h(x.head)} · η ${fmtUi(100 * x.efficiency, 0)} % · ${fmtUi(x.powerKw, 1)} kW' : t('pumpStation.off'))}',
                          style: TextStyle(fontSize: 11.5, color: x.running ? Cad.fg : Cad.fg54),
                        ),
                    ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('cancel'))),
            FilledButton(
              key: const Key('station_apply'),
              onPressed: () {
                c.mutate(() => p.station = work.isEmpty ? null : work, label: 'hist.pumpStation');
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
