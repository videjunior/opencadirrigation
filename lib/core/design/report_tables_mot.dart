/// Report tables added in 1.6.0 for the hydraulic engine (MOT+): the pumps
/// of every pump station in every system flow (PRD-17) and the real
/// operation of the zones at the pressure the mainline gives them. Built by
/// [buildReportTables] like the others, so the screen and every exporter
/// show the same numbers.
library;

import '../model/project.dart';
import 'report_tables.dart';
import 'results.dart';

/// The tables of this part that have rows, for [buildReportTables].
List<ReportTable> motReportTables(Project project, DesignResults r, ReportLabels labels) => [
  if (r.systemFlows.any((f) => f.stations.isNotEmpty)) pumpStationTable(project, r, labels),
  if (r.systemFlows.any((f) => f.operation.isNotEmpty)) zoneOperationTable(project, r, labels),
];

/// Every pump of every station in every system flow: running (its flow,
/// head, efficiency from the wire to the water and electric power), left
/// off by the staging, or on standby.
ReportTable pumpStationTable(Project project, DesignResults r, ReportLabels labels) {
  final t = labels.t;
  final u = project.params.units;
  final rows = <List<Object>>[];
  final warn = <bool>[];
  final ids = <String?>[];
  for (final f in r.systemFlows) {
    for (final s in f.stations) {
      final flagged = f.warnings.any((w) => w == 'pump_out_of_range:${s.entityId}' || w == 'pump_below_min_flow:${s.entityId}' || w == 'pump_npsh:${s.entityId}');
      for (final x in s.units) {
        rows.add([
          f.name,
          s.name,
          '${x.index}: ${x.name}',
          x.standby ? t('pumpStation.standby') : (x.running ? t('pumpStation.on') : t('pumpStation.off')),
          RNum(u.flowFromSi(x.flow), 1),
          RNum(u.pressureFromHead(x.head), 1),
          x.running ? RNum(100 * x.efficiency, 0) : '',
          x.running ? RNum(x.powerKw, 2) : '',
        ]);
        warn.add(flagged && x.running);
        ids.add(s.entityId);
      }
    }
  }
  return ReportTable(
    key: 'stations',
    title: t('reports.stations'),
    headers: [
      t('rep.flowName'),
      t('rep.station'),
      t('rep.pump'),
      t('rep.status'),
      '${t('rep.q')} (${u.flowLabel})',
      '${t('rep.pumpHead')} (${u.pressureLabel})',
      '${t('pumpStation.efficiency')} %',
      '${t('pumpStation.power')} (kW)',
    ],
    rows: rows,
    warn: warn,
    ids: ids,
  );
}

/// Every zone and pivot of every system flow at the pressure the mainline
/// really gives it: the flow delivered against the design flow, the
/// pressure at the valve against the need, the emitter pressures and the
/// uniformity at that point.
ReportTable zoneOperationTable(Project project, DesignResults r, ReportLabels labels) {
  final t = labels.t;
  final u = project.params.units;
  final rows = <List<Object>>[];
  final warn = <bool>[];
  final ids = <String?>[];
  for (final f in r.systemFlows) {
    for (final o in f.operation) {
      final status = o.short ? t('zoneOp.short') : (o.excess ? t('zoneOp.excess') : t('rep.ok'));
      rows.add([
        f.name,
        o.zoneName,
        RNum(u.flowFromSi(o.designFlow), 2),
        RNum(u.flowFromSi(o.flow), 2),
        RNum(100 * o.delivered, 0),
        RNum(u.pressureFromHead(o.requiredHead), 1),
        RNum(u.pressureFromHead(o.availableHead), 1),
        o.pivot ? '' : RNum(u.pressureFromHead(o.minPressure), 1),
        o.pivot ? '' : RNum(u.pressureFromHead(o.maxPressure), 1),
        o.pivot || o.eu <= 0 ? '' : RNum(o.eu, 0),
        status,
      ]);
      warn.add(o.short || o.excess);
      ids.add(o.valveId);
    }
  }
  return ReportTable(
    key: 'operation',
    title: t('reports.operation'),
    headers: [
      t('rep.flowName'),
      t('rep.zone'),
      '${t('zoneOp.designFlow')} (${u.flowLabel})',
      t('zoneOp.realFlow'),
      t('zoneOp.delivered'),
      '${t('rep.pRequired')} (${u.pressureLabel})',
      t('rep.pAvailable'),
      t('rep.pMin'),
      t('rep.pMax'),
      'EU %',
      t('rep.status'),
    ],
    rows: rows,
    warn: warn,
    ids: ids,
  );
}
