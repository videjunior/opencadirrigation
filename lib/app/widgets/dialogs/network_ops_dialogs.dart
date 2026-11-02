/// Network operation dialogs: the mainline under on-demand operation
/// (Clément flows and the random-demand check), the time-of-use tariff
/// schedule of the system flows, the grouping of zones that saves pumping
/// energy, automatic wire routes with the sizing of a two-wire system, the
/// failure of each pipe (criticality), the roughness calibration from field
/// readings and the timing of a fertigation. The analyses run on the design
/// (`network_ops.dart`); the changes they propose are one undo step each.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/calibration.dart' show CalibrationResidual, MeasurementKind;
import '../../../core/design/designer.dart';
import '../../../core/design/energy_grouping.dart';
import '../../../core/design/fertigation.dart';
import '../../../core/design/management.dart' show demandName, suppliesDesignFlow;
import '../../../core/design/network_builder.dart' show GLink;
import '../../../core/design/network_ops.dart';
import '../../../core/design/on_demand.dart';
import '../../../core/design/results.dart';
import '../../../core/design/tariff.dart';
import '../../../core/design/two_wire.dart';
import '../../../core/design/wire_routing.dart';
import '../../../core/hydraulics/network.dart' show HNodeKind;
import '../../../core/model/entities.dart';
import '../../../core/model/project.dart';
import '../../../core/units.dart';
import '../../state/controller.dart';
import '../../theme.dart';
import '../fields.dart';
import 'terrain_dialogs.dart' show dialogWidth;

// ---------------------------------------------------------------- shared

Widget _row(List<Widget> children) => Row(
  children: [
    for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(width: 8), Expanded(child: children[i])],
  ],
);

Widget _column(List<Widget> children) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: children);

Widget _cell(String s, {bool bold = false, Color? color}) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
  child: Text(
    s,
    style: TextStyle(fontSize: 11.5, fontWeight: bold ? FontWeight.w600 : null, color: color),
  ),
);

/// A table with its header row, as wide as its cells (scrolls sideways on a
/// narrow screen).
Widget _table(List<String> headers, List<List<Widget>> rows) => SingleChildScrollView(
  scrollDirection: Axis.horizontal,
  child: Table(
    defaultColumnWidth: const IntrinsicColumnWidth(),
    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
    children: [
      TableRow(children: [for (final h in headers) _cell(h, bold: true)]),
      for (final r in rows) TableRow(children: r),
    ],
  ),
);

Widget _hint(String s) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Text(s, style: TextStyle(fontSize: 12, color: Cad.fg70)),
);

Widget _note(String s, {Color? color}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 2),
  child: Text(s, style: TextStyle(fontSize: 11, color: color ?? Cad.warning)),
);

Widget _switch(String label, bool value, ValueChanged<bool> onChanged, {Key? key}) => SwitchListTile(
  key: key,
  dense: true,
  contentPadding: EdgeInsets.zero,
  title: Text(label, style: const TextStyle(fontSize: 12)),
  value: value,
  onChanged: onChanged,
);

/// A button that starts a computation, with a bar while it runs.
Widget _runButton(Key key, String label, IconData icon, bool busy, VoidCallback onPressed) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 6),
  child: Wrap(
    spacing: 8,
    runSpacing: 6,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      FilledButton.icon(key: key, onPressed: busy ? null : onPressed, icon: Icon(icon, size: 16), label: Text(label)),
      if (busy) const SizedBox(width: 120, child: LinearProgressIndicator()),
    ],
  ),
);

/// The messages of an analysis, translated (`warn.<code>`), each once.
Widget _codes(ProjectController c, Iterable<String> codes, String Function(String id) name) {
  final lines = codes.map((w) => c.t.warning(w, entityName: name)).toSet();
  return lines.isEmpty ? const SizedBox.shrink() : _note(lines.join('\n'));
}

/// Names for the ids of the tables and messages: the zone of a valve or
/// pivot, the name of an entity (an unnamed pipe by its id), the entity of a
/// link of the designer's network.
String Function(String id) _namer(ProjectController c, [Designer? d]) {
  final links = d == null ? const <String, GLink>{} : modelLinks(d);
  return (id) {
    final e = c.project.byId(id);
    if (e is ControlValveEntity || e is PivotEntity) return demandName(c.project, id);
    if (e is PipeEntity && e.name.isEmpty) return '${c.t('rep.pipe')} $id';
    if (e != null) return c.entityName(id);
    final l = links[id];
    return l != null ? c.entityName(l.entityId) : id;
  };
}

/// A dialog of the house style: the [body] in a scrolling column of [width],
/// Close and the [actions]. Never `scrollable`: the content scrolls itself,
/// and a scrollable dialog asks its content for intrinsic sizes, which the
/// text fields, dropdowns and [KV] rows (built on LayoutBuilder) cannot give.
Future<void> _show(
  BuildContext context,
  ProjectController c,
  String title,
  double width,
  Widget Function(BuildContext ctx, StateSetter setState) body, {
  List<Widget> Function(BuildContext ctx)? actions,
}) => showDialog<void>(
  context: context,
  builder: (ctx) => StatefulBuilder(
    builder: (ctx, setState) => AlertDialog(
      title: Text(title, style: const TextStyle(fontSize: 15)),
      content: SizedBox(
        width: dialogWidth(ctx, width),
        child: ScrollBody(child: body(ctx, setState)),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(c.t('close'))),
        ...?actions?.call(ctx),
      ],
    ),
  ),
);

/// The analyses work on a design: a short dialog saying what is missing.
Future<void> _missing(BuildContext context, ProjectController c, String title, [String key = 'msg.noResults']) => _show(context, c, title, 420, (ctx, _) => _column([_hint(c.t(key))]));

String _q(Units u, double v) => fmt(u.flowFromSi(v), u.flow == FlowUnit.lph ? 0 : 2);
String _pr(Units u, double h) => fmt(u.pressureFromHead(h), 1);
String _len(Units u, double m) => fmt(u.lengthFromSi(m), 1);
String _pct(double x, [int decimals = 0]) => '${fmt(x * 100, decimals)} %';
String _minutes(double s) => fmt(s / 60, 1);

/// Hours and minutes of a duration in seconds ("2:05").
String _hm(double s) {
  final m = (s / 60).round();
  return '${m ~/ 60}:${(m % 60).toString().padLeft(2, '0')}';
}

/// The system flow carrying the most water in the design (the worst case
/// of the analyses that look at one flow).
String _largestFlow(List<SystemFlow> flows, DesignResults r) {
  var best = flows.first.id;
  var q = -1.0;
  for (final f in flows) {
    final x = r.systemFlows.where((s) => s.flowId == f.id).firstOrNull?.totalFlow ?? 0;
    if (x > q) {
      q = x;
      best = f.id;
    }
  }
  return best;
}

Widget _flowPicker(ProjectController c, List<SystemFlow> flows, String id, ValueChanged<String> onChanged, {Key? key}) => SpecDropdown<SystemFlow>(
  key: key,
  label: c.t('sch.flow'),
  value: id,
  items: flows,
  labelOf: (f) => f.name,
  idOf: (f) => f.id,
  onChanged: (v) {
    if (v != null) onChanged(v);
  },
);

// ---------------------------------------------------------------- on demand

/// The mainline operated on demand: every zone valve and pivot a hydrant
/// opened by its user whenever needed, open with the probability of its
/// hours of use. Clément's flows per pipe for the quality of operation
/// asked, against the flows of the system flows the design sized the pipes
/// for, and the random check: configurations of open hydrants drawn at
/// random and solved, the share of them that leave a hydrant short of
/// pressure (FAO Irrigation and Drainage Paper 59).
Future<void> showOnDemandDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final title = t('od.title');
  final r = c.results;
  if (r == null) return _missing(context, c, title);
  final m = onDemandModel(c.project, r, label: (k) => t(k));
  if (m == null || m.hydrants.isEmpty) return _missing(context, c, title, 'od.none');
  final u = c.units;
  final name = _namer(c, m.designer);
  final hours = {for (final h in m.hydrants) h.id: h.hoursPerDay};
  final pressure = {...m.supplyPressure};
  var quality = 95.0, utilisation = 1.0;
  var nMin = 4, configurations = 200;
  var fixedDischarge = false, flowLimited = false, busy = false;
  RandomCheckResult? check;
  final vmax = c.project.params.maxMainlineVelocity;
  final peak = r.systemFlows.fold(0.0, (a, f) => math.max(a, f.totalFlow));
  return _show(context, c, title, 780, (ctx, setState) {
    final hydrants = [for (final h in m.hydrants) Hydrant(id: h.id, nodeId: h.nodeId, discharge: h.discharge, minPressure: h.minPressure, hoursPerDay: hours[h.id] ?? 0)];
    final cl = clementFlows(
      m.network,
      hydrants,
      options: ClementOptions(operatingQuality: quality / 100, utilisation: utilisation, minSimultaneous: nMin),
    );
    final pipes = onDemandPipeRows(m, cl);
    final need = clementSupplyPressure(m, cl);
    final source = cl.sourceFlow.values.fold(0.0, (a, b) => a + b);
    // a change of the inputs makes the last random check stale
    void change(VoidCallback f) => setState(() {
      f();
      check = null;
    });
    Future<void> run() async {
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() => busy = true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final res = checkRandomConfigurations(
        onDemandCheckNetwork(m, pressure),
        hydrants,
        probabilities: cl.probabilities,
        options: RandomCheckOptions(configurations: configurations, upstreamDischarge: fixedDischarge ? source : 0, flowLimited: flowLimited),
      );
      if (ctx.mounted) {
        setState(() {
          check = res;
          busy = false;
        });
      }
    }

    final ch = check;
    final rel = {for (final h in ch?.hydrants ?? const <HydrantReliability>[]) h.hydrantId: h};
    return _column([
      _hint(t('od.hint')),
      _row([
        NumField(key: const Key('od_quality'), label: t('od.quality'), value: quality, decimals: 1, onChanged: (v) => change(() => quality = v.clamp(50, 99.9).toDouble())),
        NumField(label: t('od.utilisation'), value: utilisation, onChanged: (v) => change(() => utilisation = v.clamp(0.05, 1).toDouble())),
        NumField(label: t('od.nMin'), value: nMin.toDouble(), decimals: 0, onChanged: (v) => change(() => nMin = v.round().clamp(0, 50))),
      ]),
      Wrap(
        spacing: 8,
        children: [
          for (final e in pressure.entries)
            SizedBox(
              width: 240,
              child: NumField(
                label: '${t('od.supplyPressure', {'s': name(e.key)})} (${u.pressureLabel})',
                value: u.pressureFromHead(e.value),
                decimals: 1,
                onChanged: (v) => change(() => pressure[e.key] = u.pressureToHead(v)),
              ),
            ),
        ],
      ),
      SectionTitle(t('od.hydrants')),
      _table(
        [
          t('rep.zone'),
          '${t('rep.flow')} (${u.flowLabel})',
          t('od.hours'),
          'p',
          '${t('od.minPressure')} (${u.pressureLabel})',
          if (ch != null) ...[t('od.reliability'), '${t('od.maxDeficit')} (${u.pressureLabel})'],
        ],
        [
          for (final h in m.hydrants)
            [
              _cell(name(h.id), bold: h.id == cl.criticalHydrant),
              _cell(_q(u, h.discharge)),
              SizedBox(
                width: 70,
                child: NumField(key: ValueKey('od_hours_${h.id}'), label: '', value: hours[h.id] ?? 0, decimals: 1, onChanged: (v) => change(() => hours[h.id] = v.clamp(0, 24).toDouble())),
              ),
              _cell(fmt(cl.probabilities[h.id] ?? 0, 3)),
              _cell(_pr(u, h.minPressure)),
              if (ch != null) ...[_cell(_pct(rel[h.id]?.reliability ?? 1, 1), color: (rel[h.id]?.reliability ?? 1) < 1 ? Cad.warning : Cad.ok), _cell(_pr(u, rel[h.id]?.maxDeficit ?? 0))],
            ],
        ],
      ),
      SectionTitle(t('od.pipes')),
      _table(
        [t('rep.pipe'), t('od.downstream'), '${t('od.clementFlow')} (${u.flowLabel})', '${t('od.designFlow')} (${u.flowLabel})', t('od.ratio'), 'V (${u.velocityLabel})', t('od.rule')],
        [
          for (final row in pipes.take(200))
            [
              _cell(name(row.entityId)),
              _cell('${row.hydrants}'),
              _cell(_q(u, row.flow)),
              _cell(_q(u, row.designFlow)),
              _cell(row.ratio.isFinite ? fmt(row.ratio, 2) : '∞', color: row.ratio > 1 + 1e-9 ? Cad.warning : null),
              _cell(fmt(u.velocityFromSi(row.velocity), 2), color: row.velocity > vmax + 1e-9 ? Cad.warning : null),
              _cell(t('od.rule.${row.rule.name}')),
            ],
        ],
      ),
      SectionTitle(t('dens.results')),
      KV('U(Pq)', fmt(cl.u, 3)),
      KV(t('od.sourceFlow'), '${_q(u, source)} ${u.flowLabel} (${t('od.designPeak')} ${_q(u, peak)})', color: source > peak + 1e-9 ? Cad.warning : null),
      for (final e in need.entries)
        KV(t('od.supplyNeed', {'s': name(e.key)}), '${_pr(u, e.value)} / ${_pr(u, pressure[e.key] ?? 0)} ${u.pressureLabel}', color: e.value > (pressure[e.key] ?? 0) + 0.01 ? Cad.warning : Cad.ok),
      if (cl.criticalHydrant != null) KV(t('od.critical'), name(cl.criticalHydrant!)),
      _codes(c, cl.codes, name),
      SectionTitle(t('od.random')),
      _row([
        NumField(
          key: const Key('od_configs'),
          label: t('od.configurations'),
          value: configurations.toDouble(),
          decimals: 0,
          onChanged: (v) => change(() => configurations = v.round().clamp(10, 5000)),
        ),
        SpecDropdown<bool>(
          label: t('od.draws'),
          value: '$fixedDischarge',
          items: const [false, true],
          labelOf: (v) => t(v ? 'od.draws.fixed' : 'od.draws.independent'),
          idOf: (v) => '$v',
          onChanged: (v) => change(() => fixedDischarge = v == 'true'),
        ),
      ]),
      _switch(t('od.flowLimited'), flowLimited, (v) => change(() => flowLimited = v)),
      _runButton(const Key('od_run'), t('od.run'), Icons.casino_outlined, busy, run),
      if (ch != null) ...[
        KV(t('od.configs'), '${ch.configurations}'),
        KV(t('od.failShare'), _pct(1 - ch.satisfiedShare, 1), color: ch.satisfiedShare < 1 ? Cad.warning : Cad.ok),
        KV(t('od.meanOpen'), '${fmt(ch.meanOpen, 1)} · ${_q(u, ch.meanDischarge)} ${u.flowLabel}'),
        KV(t('od.unsatisfied'), '${_pct(ch.meanUnsatisfied, 1)} · ${_pct(ch.p90Unsatisfied, 1)} · ${_pct(ch.maxUnsatisfied, 1)}'),
        _codes(c, ch.codes, name),
      ],
    ]);
  });
}

// ---------------------------------------------------------------- tariff

class _Band {
  _Band(this.from, this.to, this.price, this.peak);
  double from, to, price;
  bool peak;
}

/// What the tariff dialog was given, kept for the session per project.
class _TariffForm {
  _TariffForm(this.base, {required bool brazil}) : bands = [_Band(18, 21, base * 2.5, true)], discount = brazil ? 'brazil' : 'none';
  double base;
  final List<_Band> bands;
  double demand = 0, peakDemand = 0, customPct = 60, windowH = 8.5, excludedFrom = 17, excludedTo = 21.5, maxHours = 0, motorEfficiency = 1;
  String discount;
  BrazilConsumerGroup group = BrazilConsumerGroup.b;
  BrazilDiscountRegion region = BrazilDiscountRegion.others;
  int blocks = 3, step = 15;
  bool keepOrder = false;

  IrrigationDiscount? get irrigationDiscount => switch (discount) {
    'brazil' => IrrigationDiscount.brazil(group, region),
    'custom' => IrrigationDiscount(
      fraction: (customPct / 100).clamp(0.0, 1.0),
      windowMinutes: (windowH * 60).round(),
      maxBlocks: blocks,
      excluded: [((excludedFrom * 60).round(), (excludedTo * 60).round())],
    ),
    _ => null,
  };

  TariffSeason get season => TariffSeason(
    id: 'day',
    basePricePerKwh: base,
    demandChargePerKw: demand,
    peakDemandChargePerKw: peakDemand,
    discount: irrigationDiscount,
    bands: [for (final b in bands) TariffBand(startMinute: (b.from * 60).round(), endMinute: (b.to * 60).round(), pricePerKwh: b.price, peak: b.peak)],
  );
}

final _tariffForms = <String, _TariffForm>{};

/// A time-of-use tariff (price bands of the day, demand charges and the
/// irrigation discount of a window of the day, as the Brazilian rural
/// irrigation tariff) and the daily schedule of the system flows that costs
/// least under it, compared with their start hours as they are; Apply sets
/// the start hours (one undo step).
Future<void> showTariffDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final title = t('tar.title');
  final r = c.results;
  if (r == null) return _missing(context, c, title);
  final p = c.project;
  final f = _tariffForms.putIfAbsent(p.meta.uid, () => _TariffForm(p.params.powerCostPerKwh, brazil: p.params.currencyCode == 'BRL'));
  final cur = p.params.currency;
  final names = {for (final s in r.systemFlows) s.flowId: s.name, for (final s in p.systemFlows) s.id: s.name};
  TariffSchedule? schedule;
  var busy = false;
  var gen = 0;
  bool applicable(TariffSchedule s) => s.jobs.any((j) => c.project.systemFlows.any((x) => x.id == j.id));
  return _show(
    context,
    c,
    title,
    800,
    (ctx, setState) {
      void change(VoidCallback fn) => setState(() {
        fn();
        schedule = null;
      });
      Future<void> compute() async {
        FocusManager.instance.primaryFocus?.unfocus();
        setState(() => busy = true);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        final jobs = tariffJobsFromDesign(p, r, motorEfficiency: f.motorEfficiency);
        final s = scheduleJobs(
          jobs,
          f.season,
          options: ScheduleOptions(stepMinutes: f.step, maxHoursPerDay: f.maxHours, keepOrder: f.keepOrder),
        );
        if (ctx.mounted) {
          setState(() {
            schedule = s;
            busy = false;
          });
        }
      }

      final disc = f.irrigationDiscount;
      final s = schedule;
      String money(double v) => '$cur ${fmt(v, 2)}';
      return _column([
        _hint(t('tar.hint')),
        SectionTitle(t('tar.prices')),
        _row([
          NumField(key: const Key('tar_base'), label: '${t('tar.basePrice')} ($cur/kWh)', value: f.base, decimals: 3, onChanged: (v) => change(() => f.base = math.max(0, v))),
          NumField(label: '${t('tar.demandCharge')} ($cur/kW)', value: f.demand, onChanged: (v) => change(() => f.demand = math.max(0, v))),
          NumField(label: '${t('tar.peakDemandCharge')} ($cur/kW)', value: f.peakDemand, onChanged: (v) => change(() => f.peakDemand = math.max(0, v))),
        ]),
        for (var i = 0; i < f.bands.length; i++)
          () {
            final fields = _row([
              NumField(label: t('tar.from'), value: f.bands[i].from, onChanged: (v) => change(() => f.bands[i].from = v.clamp(0, 24).toDouble())),
              NumField(label: t('tar.to'), value: f.bands[i].to, onChanged: (v) => change(() => f.bands[i].to = v.clamp(0, 24).toDouble())),
              NumField(label: '${t('tar.price')} ($cur/kWh)', value: f.bands[i].price, decimals: 3, onChanged: (v) => change(() => f.bands[i].price = math.max(0, v))),
            ]);
            final flags = [
              Checkbox(value: f.bands[i].peak, onChanged: (v) => change(() => f.bands[i].peak = v ?? false)),
              Text(t('tar.peak'), style: const TextStyle(fontSize: 12)),
              IconButton(
                tooltip: t('tar.removeBand'),
                icon: const Icon(Icons.delete_outline, size: 18),
                onPressed: () => change(() {
                  f.bands.removeAt(i);
                  gen++;
                }),
              ),
            ];
            return MediaQuery.sizeOf(ctx).width < 700
                ? Column(
                    key: ValueKey('tar_band_${gen}_$i'),
                    children: [
                      fields,
                      Row(children: flags),
                    ],
                  )
                : Row(
                    key: ValueKey('tar_band_${gen}_$i'),
                    children: [
                      Expanded(child: fields),
                      ...flags,
                    ],
                  );
          }(),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('tar_add_band'),
            onPressed: () => change(() => f.bands.add(_Band(6, 18, f.base, false))),
            icon: const Icon(Icons.add, size: 16),
            label: Text(t('tar.addBand')),
          ),
        ),
        SectionTitle(t('tar.discount')),
        SpecDropdown<String>(
          key: const Key('tar_discount'),
          label: t('tar.discount'),
          value: f.discount,
          items: const ['none', 'brazil', 'custom'],
          labelOf: (k) => t('tar.discount.$k'),
          idOf: (k) => k,
          onChanged: (v) => change(() => f.discount = v ?? 'none'),
        ),
        if (f.discount == 'brazil') ...[
          _row([
            SpecDropdown<BrazilConsumerGroup>(
              label: t('tar.group'),
              value: f.group.name,
              items: BrazilConsumerGroup.values,
              labelOf: (g) => t('tar.group.${g.name}'),
              idOf: (g) => g.name,
              onChanged: (v) => change(() => f.group = BrazilConsumerGroup.values.byName(v!)),
            ),
            SpecDropdown<BrazilDiscountRegion>(
              label: t('tar.region'),
              value: f.region.name,
              items: BrazilDiscountRegion.values,
              labelOf: (g) => t('tar.region.${g.name}'),
              idOf: (g) => g.name,
              onChanged: (v) => change(() => f.region = BrazilDiscountRegion.values.byName(v!)),
            ),
          ]),
          _note(t('tar.brazilRule', {'pct': fmt((disc?.fraction ?? 0) * 100, 0)}), color: Cad.fg60),
        ],
        if (f.discount == 'custom') ...[
          _row([
            NumField(label: t('tar.discountPct'), value: f.customPct, decimals: 1, onChanged: (v) => change(() => f.customPct = v.clamp(0, 100).toDouble())),
            NumField(label: t('tar.window'), value: f.windowH, onChanged: (v) => change(() => f.windowH = v.clamp(0, 24).toDouble())),
            NumField(label: t('tar.maxBlocks'), value: f.blocks.toDouble(), decimals: 0, onChanged: (v) => change(() => f.blocks = v.round().clamp(1, 48))),
          ]),
          _row([
            NumField(label: t('tar.excludedFrom'), value: f.excludedFrom, onChanged: (v) => change(() => f.excludedFrom = v.clamp(0, 24).toDouble())),
            NumField(label: t('tar.excludedTo'), value: f.excludedTo, onChanged: (v) => change(() => f.excludedTo = v.clamp(0, 24).toDouble())),
          ]),
        ],
        SectionTitle(t('tar.options')),
        _row([
          NumField(label: t('tar.step'), value: f.step.toDouble(), decimals: 0, onChanged: (v) => change(() => f.step = v.round().clamp(5, 60))),
          NumField(label: t('tar.maxHours'), value: f.maxHours, onChanged: (v) => change(() => f.maxHours = v.clamp(0, 24).toDouble())),
          NumField(label: t('tar.motorEfficiency'), value: f.motorEfficiency, onChanged: (v) => change(() => f.motorEfficiency = v.clamp(0.05, 1).toDouble())),
        ]),
        _switch(t('tar.keepOrder'), f.keepOrder, (v) => change(() => f.keepOrder = v)),
        _runButton(const Key('tar_compute'), t('tar.compute'), Icons.schedule, busy, compute),
        if (s != null) ...[
          SectionTitle(t('tar.schedule')),
          _table(
            [t('sch.flow'), t('sch.start'), t('sch.end'), t('sch.duration'), 'kW', 'kWh', t('tar.inWindow'), '${t('tar.cost')} ($cur)', '${t('tar.costFull')} ($cur)'],
            [
              for (final j in s.jobs)
                [
                  _cell(names[j.id] ?? j.id),
                  _cell(clockOf(j.startMinute)),
                  _cell(clockOf(j.endMinute)),
                  _cell(fmt(j.minutes / 60, 2)),
                  _cell(fmt(j.powerKw, 2)),
                  _cell(fmt(j.energyKwh, 1)),
                  _cell(fmt(j.windowMinutes / 60, 2)),
                  _cell(fmt(j.cost, 2)),
                  _cell(fmt(j.costWithoutDiscount, 2)),
                ],
            ],
          ),
          KV(t('tar.blocks'), s.blocks.isEmpty ? '—' : s.blocks.map((b) => '${clockOf(b.startMinute)}–${clockOf(b.endMinute)}').join(', ')),
          KV(t('tar.energy'), '${money(s.energyCost)} · ${fmt(s.energyKwh, 1)} kWh'),
          if (disc != null) KV(t('tar.withoutDiscount'), '${money(s.energyCostWithoutDiscount)} (${t('tar.saving')} ${money(s.discountSaving)})'),
          if (s.demandCost > 0) KV(t('tar.demandCost'), money(s.demandCost)),
          KV(t('tar.daily'), money(s.dailyCost), color: Cad.ok),
          if (s.baselineCost != null)
            KV(
              t('tar.current'),
              '${money(s.baselineCost!)} (${t('tar.saving')} ${money(s.baselineCost! - s.dailyCost)}${s.baselineCost! > 0 ? ', ${_pct((s.baselineCost! - s.dailyCost) / s.baselineCost!, 1)}' : ''})',
              color: s.baselineCost! + 1e-9 < s.dailyCost ? Cad.warning : null,
            ),
          KV(t('tar.monthly'), money(s.dailyCost * f.season.daysPerMonth)),
          _note(t(s.exact ? 'tar.exact' : 'tar.heuristic'), color: Cad.fg54),
          _codes(c, s.violations, (id) => names[id] ?? id),
          if (!applicable(s)) _note(t('tar.noFlows')),
        ],
      ]);
    },
    actions: (ctx) => [
      FilledButton(
        key: const Key('tar_apply'),
        onPressed: schedule == null || !applicable(schedule!)
            ? null
            : () {
                final s = schedule!;
                final n = c.mutate(() => applyTariffSchedule(c.project, s), label: 'hist.tariff', invalidateResults: false);
                Navigator.pop(ctx);
                if (n != null) c.notify(t('tar.applied', {'n': '$n'}));
              },
        child: Text(t('tar.apply')),
      ),
    ],
  );
}

// ---------------------------------------------------------------- energy grouping

/// System flows (groups of zones opened together) that need the least
/// pumping energy: zones of similar required head together, within the flow
/// the pump delivers, the groups and the hours of the day allowed, against
/// the system flows as they are; Apply replaces the system flows (one undo
/// step).
Future<void> showEnergyGroupingDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final title = t('eg.title');
  final r = c.results;
  if (r == null) return _missing(context, c, title);
  final p = c.project;
  final d = opsDesigner(p, r, label: (k) => t(k));
  final (zones, source) = energyZonesWithPivots(d, r);
  if (zones.isEmpty) return _missing(context, c, title, 'eg.none');
  final u = c.units;
  final name = _namer(c, d);
  final cur = p.params.currency;
  final price = p.params.powerCostPerKwh;
  // what the pump already delivers: the supplies' design flow, else the
  // largest flow of the design (never below the largest zone)
  var maxFlow = math.max(suppliesDesignFlow(p), [for (final f in r.systemFlows) f.totalFlow, for (final z in zones) z.flow].fold(0.0, math.max)) * (1 + 1e-9);
  var maxGroups = 0, maxZones = 0;
  var maxHours = 24.0, efficiency = p.params.pumpEfficiency;
  var exact = true, busy = false;
  EnergyGroupingResult? result;
  var currentKwh = 0.0;
  final currentHours = p.systemFlows.fold(0.0, (s, f) => s + f.durationHours);
  double head(List<EnergyZone> g) => exact ? designerGroupHead(d, g.map((z) => z.id)) : formulaGroupHead(g, source);
  return _show(
    context,
    c,
    title,
    780,
    (ctx, setState) {
      void change(VoidCallback fn) => setState(() {
        fn();
        result = null;
      });
      Future<void> compute() async {
        FocusManager.instance.primaryFocus?.unfocus();
        setState(() => busy = true);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        final g = groupZonesForEnergy(
          zones,
          options: GroupingOptions(maxFlow: maxFlow, maxGroups: maxGroups, maxHours: maxHours, maxZonesPerGroup: maxZones, sourceElevation: source, pumpEfficiency: efficiency),
          groupHead: exact ? head : null,
        );
        final now = groupingEnergyKwh([for (final f in d.effectiveSystemFlows()) f.valveIds], zones, head, efficiency: efficiency);
        if (ctx.mounted) {
          setState(() {
            result = g;
            currentKwh = now;
            busy = false;
          });
        }
      }

      final g = result;
      return _column([
        _hint(t('eg.hint')),
        _row([
          NumField(key: const Key('eg_max_flow'), label: '${t('eg.maxFlow')} (${u.flowLabel})', value: u.flowFromSi(maxFlow), onChanged: (v) => change(() => maxFlow = v <= 0 ? 0 : u.flowToSi(v))),
          NumField(key: const Key('eg_max_groups'), label: t('eg.maxGroups'), value: maxGroups.toDouble(), decimals: 0, onChanged: (v) => change(() => maxGroups = v.round().clamp(0, 999))),
          NumField(label: t('eg.maxHours'), value: maxHours, onChanged: (v) => change(() => maxHours = v.clamp(0, 168).toDouble())),
          NumField(label: t('eg.maxZones'), value: maxZones.toDouble(), decimals: 0, onChanged: (v) => change(() => maxZones = v.round().clamp(0, 999))),
        ]),
        _row([
          NumField(label: t('eg.efficiency'), value: efficiency, onChanged: (v) => change(() => efficiency = v.clamp(0.05, 1).toDouble())),
          _switch(t('eg.exact'), exact, (v) => change(() => exact = v)),
        ]),
        _note(t('eg.currentFlows', {'n': '${p.systemFlows.length}', 'h': fmt(currentHours, 1)}), color: Cad.fg54),
        _runButton(const Key('eg_compute'), t('eg.compute'), Icons.bolt, busy, compute),
        if (g != null) ...[
          SectionTitle(t('eg.proposal')),
          _table(
            [t('eg.group'), t('sch.zones'), '${t('rep.flow')} (${u.flowLabel})', '${t('eg.head')} (${u.pressureLabel})', t('eg.hours'), '${t('eg.energy')} (kWh)', '${t('eg.cost')} ($cur)'],
            [
              for (var i = 0; i < g.groups.length; i++)
                [
                  _cell('${i + 1}'),
                  _cell(g.groups[i].zoneIds.map(name).join(' + ')),
                  _cell(_q(u, g.groups[i].flow)),
                  _cell(_pr(u, g.groups[i].head)),
                  _cell(fmt(g.groups[i].hours, 1)),
                  _cell(fmt(g.groups[i].energyKwh, 1)),
                  _cell(fmt(g.groups[i].energyKwh * price, 2)),
                ],
            ],
          ),
          KV(t('eg.currentEnergy'), '${fmt(currentKwh, 1)} kWh · $cur ${fmt(currentKwh * price, 2)}'),
          KV(t('eg.baselineEnergy'), '${fmt(g.baselineEnergyKwh, 1)} kWh'),
          KV(t('eg.proposedEnergy'), '${fmt(g.energyKwh, 1)} kWh · $cur ${fmt(g.energyKwh * price, 2)} · ${fmt(g.hours, 1)} h', color: Cad.ok),
          if (currentKwh > 0)
            KV(t('eg.saving'), '${fmt(currentKwh - g.energyKwh, 1)} kWh (${_pct((currentKwh - g.energyKwh) / currentKwh, 1)})', color: g.energyKwh <= currentKwh + 1e-9 ? Cad.ok : Cad.warning),
          _codes(c, g.codes, name),
        ],
      ]);
    },
    actions: (ctx) => [
      FilledButton(
        key: const Key('eg_apply'),
        onPressed: result == null || result!.groups.isEmpty
            ? null
            : () {
                final groups = result!.groups;
                final flows = c.project.systemFlows;
                final start = flows.isEmpty ? 6.0 : flows.map((f) => f.startHour).reduce(math.min);
                final n = c.mutate(() {
                  final next = systemFlowsFromGroups(c.project, groups, firstStartHour: start, label: (k) => t(k));
                  c.project.systemFlows
                    ..clear()
                    ..addAll(next);
                  return next.length;
                }, label: 'hist.energyGroups');
                Navigator.pop(ctx);
                if (n != null) c.notify(t('eg.applied', {'n': '$n'}));
              },
        child: Text(t('eg.apply')),
      ),
    ],
  );
}

// ---------------------------------------------------------------- wire routing

/// Decoders of a two-wire path by size ("3 × 1 · 1 × 4").
String _decoders(TwoWireResult tw, String controllerId) {
  final by = <int, int>{};
  for (final d in tw.decoders) {
    if (d.controllerId == controllerId) by[d.capacity] = (by[d.capacity] ?? 0) + 1;
  }
  final caps = by.keys.toList()..sort();
  return caps.isEmpty ? '0' : caps.map((k) => '${by[k]} × $k').join(' · ');
}

/// Wire routes drawn automatically along the pipe trenches from every
/// controller to its valves, master valves and pump-start relays (the
/// stations allocated by distance), and the sizing of a two-wire (decoder)
/// system on those routes; Apply draws the routes as wire entities (one undo
/// step), which the valve wiring of the design then follows.
Future<void> showWireRoutingDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final p = c.project;
  final u = c.units;
  final name = _namer(c);
  var mode = RoutingMode.shortestPaths;
  var zonePipes = true, masterStations = true, relayStations = true, replace = true;
  var maxStub = 30.0;
  final hasWires = p.entities.any((e) => e is WireEntity);
  var volts = 34.0, minVolts = 24.0, idleMa = 1.0, solenoidCable = 30.0, groundM = 150.0;
  var groundDecoders = 12;
  WireRoutingResult route() => routeProjectWires(
    p,
    options: WireRoutingOptions(
      mode: mode,
      includeZonePipes: zonePipes,
      masterValveStations: masterStations,
      pumpRelayStations: relayStations,
      maxStubM: maxStub,
      tolerance: math.max(p.params.connectTolerance, 0.1),
    ),
  );
  return _show(
    context,
    c,
    t('wr.title'),
    760,
    (ctx, setState) {
      final r = route();
      final tw = r.routes.isEmpty
          ? null
          : designTwoWire(
              p,
              flows: wiringFlows(p),
              routes: [for (final w in r.routes) w.points],
              spec: TwoWireSpec(outputVolts: volts, minVolts: minVolts, decoderIdleA: idleMa / 1000, maxSolenoidCableM: solenoidCable, groundEveryDecoders: groundDecoders, groundEveryM: groundM),
            );
      String wire(String? id) => id == null ? '—' : (p.catalog.wire(id)?.name ?? id);
      return _column([
        _hint(t('wr.hint')),
        _row([
          SpecDropdown<RoutingMode>(
            key: const Key('wr_mode'),
            label: t('wr.mode'),
            value: mode.name,
            items: RoutingMode.values,
            labelOf: (m) => t('wr.mode.${m.name}'),
            idOf: (m) => m.name,
            onChanged: (v) => setState(() => mode = RoutingMode.values.byName(v!)),
          ),
          NumField(label: '${t('wr.maxStub')} (${u.lengthLabel})', value: u.lengthFromSi(maxStub), decimals: 1, onChanged: (v) => setState(() => maxStub = math.max(0, u.lengthToSi(v)))),
        ]),
        _switch(t('wr.zonePipes'), zonePipes, (v) => setState(() => zonePipes = v)),
        _switch(t('wr.masterStations'), masterStations, (v) => setState(() => masterStations = v)),
        _switch(t('wr.relayStations'), relayStations, (v) => setState(() => relayStations = v)),
        SectionTitle(t('wr.routes')),
        for (final ctl in p.entities.whereType<ControllerEntity>())
          KV(
            name(ctl.id),
            t('wr.controllerSummary', {
              'used': '${r.stations.where((s) => s.controllerId == ctl.id && s.station > 0).length}',
              'n': '${ctl.stations}',
              'len': _len(u, r.routeLengthOf(ctl.id)),
              'u': u.lengthLabel,
            }),
          ),
        if (r.stations.isNotEmpty)
          _table(
            [t('rep.controller'), t('rep.station'), t('wr.kind'), t('wr.item'), '${t('wr.route')} (${u.lengthLabel})'],
            [
              for (final s in r.stations)
                [_cell(name(s.controllerId)), _cell(s.station == 0 ? t('wr.dedicated') : '${s.station}'), _cell(t('wr.kind.${s.kind.name}')), _cell(name(s.entityId)), _cell(_len(u, s.routeM))],
            ],
          ),
        _codes(c, r.warnings, name),
        if (hasWires) _switch(t('wr.replace'), replace, (v) => setState(() => replace = v), key: const Key('wr_replace')),
        SectionTitle(t('tw.title')),
        _hint(t('tw.hint')),
        _row([
          NumField(label: t('tw.volts'), value: volts, decimals: 1, onChanged: (v) => setState(() => volts = v.clamp(1, 100).toDouble())),
          NumField(label: t('tw.minVolts'), value: minVolts, decimals: 1, onChanged: (v) => setState(() => minVolts = v.clamp(1, 100).toDouble())),
          NumField(label: t('tw.idle'), value: idleMa, decimals: 2, onChanged: (v) => setState(() => idleMa = v.clamp(0, 100).toDouble())),
        ]),
        _row([
          NumField(
            label: '${t('tw.solenoidReach')} (${u.lengthLabel})',
            value: u.lengthFromSi(solenoidCable),
            decimals: 1,
            onChanged: (v) => setState(() => solenoidCable = math.max(0, u.lengthToSi(v))),
          ),
          NumField(label: t('tw.groundDecoders'), value: groundDecoders.toDouble(), decimals: 0, onChanged: (v) => setState(() => groundDecoders = v.round().clamp(0, 999))),
          NumField(label: '${t('tw.groundEvery')} (${u.lengthLabel})', value: u.lengthFromSi(groundM), decimals: 0, onChanged: (v) => setState(() => groundM = math.max(0, u.lengthToSi(v)))),
        ]),
        if (tw != null) ...[
          for (final path in tw.paths.where((x) => x.used > 0)) ...[
            KV(name(path.controllerId), wire(path.wireId)),
            KV(t('tw.length'), '${_len(u, path.routeM)} / ${_len(u, path.cableM)} ${u.lengthLabel}'),
            KV(t('tw.decoders'), _decoders(tw, path.controllerId)),
            KV(t('elec.maxOpen'), '${path.maxOpen}'),
            KV(t('elec.peak'), '${fmt(path.peakCurrentA, 2)} A'),
            KV(t('tw.worst'), '${fmt(path.worstVolts, 1)} V', color: path.worstVolts >= minVolts - 1e-9 ? Cad.ok : Cad.warning),
            KV(t('tw.maxDistance'), path.maxDistanceM.isFinite ? '${_len(u, path.maxDistanceM)} ${u.lengthLabel}' : '∞'),
            if (path.sizes.isNotEmpty)
              _table(
                [t('tw.wire'), '${t('tw.worst')} (V)', '${t('tw.maxDistance')} (${u.lengthLabel})'],
                [
                  for (final s in path.sizes)
                    [
                      _cell(wire(s.wireId), bold: s.wireId == path.wireId),
                      _cell(fmt(s.worstVolts, 1), color: s.ok ? Cad.ok : Cad.warning),
                      _cell(s.maxDistanceM.isFinite ? _len(u, s.maxDistanceM) : '∞'),
                    ],
                ],
              ),
          ],
          if (tw.stations.isNotEmpty)
            _table(
              [t('rep.station'), t('rep.zone'), t('tw.decoder'), '${t('wr.route')} (${u.lengthLabel})', '${t('tw.solenoidCable')} (${u.lengthLabel})', 'V'],
              [
                for (final s in tw.stations)
                  [
                    _cell('${s.station}'),
                    _cell(s.zoneName.isNotEmpty ? s.zoneName : name(s.valveId)),
                    _cell(s.decoderId),
                    _cell(_len(u, s.routeM)),
                    _cell(_len(u, s.solenoidCableM)),
                    _cell(fmt(s.volts, 1), color: s.ok ? null : Cad.warning),
                  ],
              ],
            ),
          KV(t('tw.grounds'), '${tw.grounds.length}'),
          _codes(c, tw.warnings, name),
        ],
      ]);
    },
    actions: (ctx) {
      final r = route();
      return [
        FilledButton(
          key: const Key('wr_apply'),
          onPressed: r.routes.isEmpty
              ? null
              : () {
                  final n = c.mutate(() {
                    if (replace) c.project.entities.removeWhere((e) => e is WireEntity);
                    final wires = wireEntitiesOf(c.project, r);
                    c.project.entities.addAll(wires);
                    return wires.length;
                  }, label: 'hist.wireRoutes');
                  Navigator.pop(ctx);
                  if (n != null) c.notify(t('wr.applied', {'n': '$n'}));
                },
          child: Text(t('wr.apply')),
        ),
      ];
    },
  );
}

// ---------------------------------------------------------------- criticality

/// The mainline of a system flow with every pipe out of service in turn:
/// the links whose loss cuts zones off or leaves them short of pressure,
/// from the worst, with the deficit and the share of the demand a
/// pressure-driven solution still delivers.
Future<void> showCriticalityDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final title = t('crit.title');
  final r = c.results;
  if (r == null) return _missing(context, c, title);
  final d = opsDesigner(c.project, r, label: (k) => t(k));
  final flows = d.effectiveSystemFlows();
  if (flows.isEmpty) return _missing(context, c, title);
  final u = c.units;
  final name = _namer(c, d);
  var flowId = _largestFlow(flows, r);
  var pressureDriven = true, busy = false;
  CriticalityView? view;
  return _show(context, c, title, 780, (ctx, setState) {
    Future<void> run() async {
      setState(() => busy = true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final v = criticalityOf(d, r, flows.firstWhere((f) => f.id == flowId), pressureDriven: pressureDriven);
      if (ctx.mounted) {
        setState(() {
          view = v;
          busy = false;
        });
      }
    }

    final v = view;
    final total = v?.result.totalDemand ?? 0;
    return _column([
      _hint(t('crit.hint')),
      _flowPicker(
        c,
        flows,
        flowId,
        (id) => setState(() {
          flowId = id;
          view = null;
        }),
      ),
      _switch(
        t('crit.pressureDriven'),
        pressureDriven,
        (x) => setState(() {
          pressureDriven = x;
          view = null;
        }),
      ),
      _runButton(const Key('crit_run'), t('crit.run'), Icons.call_split, busy, run),
      if (v != null) ...[
        KV(t('crit.total'), '${_q(u, total)} ${u.flowLabel}'),
        if (v.result.tree) _note(t('crit.tree'), color: Cad.fg60),
        if (v.result.baseDeficits.isNotEmpty)
          _note(
            t('crit.baseShort', {
              'z': {for (final x in v.result.baseDeficits) ...?v.demandsAt[x.nodeId]}.map(name).join(', '),
            }),
          ),
        if (v.rows.isEmpty)
          _note(t('crit.noneShort'), color: Cad.ok)
        else
          _table(
            ['#', t('rep.pipe'), '${t('crit.lost')} (${u.flowLabel})', t('crit.lostShare'), t('crit.cutOff'), t('crit.short')],
            [
              for (var i = 0; i < math.min(v.rows.length, 200); i++)
                [
                  _cell('${i + 1}'),
                  _cell(name(v.rows[i].entityId)),
                  _cell(_q(u, v.rows[i].scenario.lostDemand)),
                  _cell(total > 0 ? _pct(v.rows[i].scenario.lostDemand / total, 1) : '-'),
                  _cell(v.rows[i].cutOff.map(name).join(', ')),
                  _cell(
                    v.rows[i].short.map((e) => '${name(e.$1)}: −${_pr(u, e.$2.deficit)} ${u.pressureLabel} (${_pct(e.$2.demand > 0 ? e.$2.delivered / e.$2.demand : 1)})').join('\n'),
                    color: v.rows[i].short.isEmpty ? null : Cad.warning,
                  ),
                ],
            ],
          ),
        _codes(c, v.result.codes, name),
      ],
    ]);
  });
}

// ---------------------------------------------------------------- calibration

class _Reading {
  _Reading(this.entityId, this.value, [this.sigma = 0]);
  String entityId;
  double value;
  double sigma;
}

/// Roughness calibration: pressures read in the field at points of the
/// mainline (valves, supplies, junctions, devices) and flows leaving the
/// supplies, while one system flow runs, and the Hazen-Williams C scale that
/// fits them best, with the residuals before and after; Apply sets the C
/// scale of the design parameters (one undo step).
Future<void> showCalibrationDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final title = t('cal.title');
  final r = c.results;
  if (r == null) return _missing(context, c, title);
  final p = c.project;
  final d = opsDesigner(p, r, label: (k) => t(k));
  final flows = d.effectiveSystemFlows();
  final points = measurePoints(d);
  final supplies = [
    for (final m in points)
      if (m.kind == MeasurePointKind.supply) m,
  ];
  if (flows.isEmpty || supplies.isEmpty) return _missing(context, c, title, 'cal.none');
  final u = c.units;
  final name = _namer(c, d);
  String pointLabel(MeasurePoint m) {
    final kind = switch (m.kind) {
      MeasurePointKind.valve => p.byId(m.entityId) is PivotEntity ? 'tool.pivot' : 'tool.valve',
      MeasurePointKind.supply => 'tool.supply',
      MeasurePointKind.junction => 'tool.junction',
      MeasurePointKind.device => 'tool.misc',
    };
    return '${t(kind)}: ${name(m.entityId)}';
  }

  /// The model of a flow before the calibration: pressure at every point
  /// and the flow leaving every supply.
  (Map<String, double>, Map<String, double>) modelOf(String id) {
    final built = d.mainlineNetworkFor(flows.firstWhere((f) => f.id == id));
    if (built == null) return (const {}, const {});
    final (net, res, _) = built;
    final pr = <String, double>{};
    for (final m in points) {
      final n = net.nodes[m.nodeId];
      if (n == null) continue;
      pr[m.entityId] = n.kind == HNodeKind.reservoir ? (n.fixedHead ?? n.elevation) - n.elevation : (res.nodes[m.nodeId]?.pressure ?? 0);
    }
    final q = <String, double>{};
    for (final s in supplies) {
      var out = 0.0;
      for (final l in net.links) {
        final f = res.links[l.id]?.flow ?? 0;
        if (l.from == s.nodeId) out += f;
        if (l.to == s.nodeId) out -= f;
      }
      q[s.entityId] = out;
    }
    return (pr, q);
  }

  var flowId = _largestFlow(flows, r);
  var model = modelOf(flowId);
  final pressures = <_Reading>[];
  final flowReadings = <_Reading>[];
  final sf0 = flows.firstWhere((f) => f.id == flowId);
  final first = points.where((m) => m.kind == MeasurePointKind.valve && sf0.valveIds.contains(m.entityId)).firstOrNull ?? points.first;
  pressures.add(_Reading(first.entityId, ((model.$1[first.entityId] ?? 0) * 10).roundToDouble() / 10, 0.5));
  FieldCalibration? result;
  var busy = false;
  var gen = 0;
  final params = p.params;
  bool canApply() {
    final res = result?.result;
    if (res == null || res.residuals.isEmpty || res.scales.isEmpty) return false;
    final f = res.scales.single;
    return f.isFinite && f > 0 && (f - 1).abs() > 1e-6 && !res.codes.contains('calibration_not_hazen_williams');
  }

  return _show(
    context,
    c,
    title,
    760,
    (ctx, setState) {
      void change(VoidCallback fn) => setState(() {
        fn();
        result = null;
      });
      Future<void> run() async {
        FocusManager.instance.primaryFocus?.unfocus();
        setState(() => busy = true);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        final res = calibrateFromField(
          d,
          flows.firstWhere((f) => f.id == flowId),
          pressures: [for (final x in pressures) FieldReading(entityId: x.entityId, value: x.value, sigma: x.sigma)],
          flows: [for (final x in flowReadings) FieldReading(entityId: x.entityId, value: x.value, sigma: x.sigma)],
        );
        if (ctx.mounted) {
          setState(() {
            result = res;
            busy = false;
          });
        }
      }

      // a reading: where, the value, its σ, the model's value and removal;
      // the place on a line of its own on a phone
      Widget reading(Key key, Widget picker, Widget measured, Widget sigma, String modelText, VoidCallback remove) {
        final rest = [
          Expanded(child: measured),
          const SizedBox(width: 8),
          SizedBox(width: 70, child: sigma),
          const SizedBox(width: 8),
          Expanded(
            child: Text(modelText, style: TextStyle(fontSize: 11, color: Cad.fg54)),
          ),
          IconButton(tooltip: t('cal.remove'), icon: const Icon(Icons.delete_outline, size: 18), onPressed: remove),
        ];
        return MediaQuery.sizeOf(ctx).width < 700
            ? Column(
                key: key,
                children: [
                  picker,
                  Row(children: rest),
                ],
              )
            : Row(
                key: key,
                children: [
                  Expanded(flex: 3, child: picker),
                  const SizedBox(width: 8),
                  ...rest,
                ],
              );
      }

      final res = result?.result;
      // a flow reading is fitted along its link: shown as the user gave it
      String value(CalibrationResidual x, double v) => x.kind == MeasurementKind.pressure ? '${_pr(u, v)} ${u.pressureLabel}' : '${_q(u, x.measured < 0 ? -v : v)} ${u.flowLabel}';
      final (scale, offset) = res == null || res.scales.isEmpty ? (params.hazenCScale, params.hazenCOffset) : calibratedC(params, res.scales.single);
      return _column([
        _hint(t('cal.hint')),
        _flowPicker(
          c,
          flows,
          flowId,
          (id) => change(() {
            flowId = id;
            model = modelOf(id);
          }),
        ),
        SectionTitle(t('cal.pressures')),
        for (var i = 0; i < pressures.length; i++)
          reading(
            ValueKey('cal_prow_${gen}_$i'),
            SpecDropdown<MeasurePoint>(
              label: t('cal.point'),
              value: pressures[i].entityId,
              items: points,
              labelOf: pointLabel,
              idOf: (m) => m.entityId,
              onChanged: (v) => change(() => pressures[i].entityId = v ?? pressures[i].entityId),
            ),
            NumField(
              key: ValueKey('cal_p_$i'),
              label: '${t('cal.measured')} (${u.pressureLabel})',
              value: u.pressureFromHead(pressures[i].value),
              onChanged: (v) => change(() => pressures[i].value = u.pressureToHead(v)),
            ),
            NumField(label: 'σ (m)', value: pressures[i].sigma, onChanged: (v) => change(() => pressures[i].sigma = v.clamp(0.01, 50).toDouble())),
            '${t('cal.model')} ${_pr(u, model.$1[pressures[i].entityId] ?? 0)}',
            () => change(() {
              pressures.removeAt(i);
              gen++;
            }),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('cal_add_p'),
            onPressed: () => change(() {
              final m = points.first;
              pressures.add(_Reading(m.entityId, model.$1[m.entityId] ?? 0, 0.5));
            }),
            icon: const Icon(Icons.add, size: 16),
            label: Text(t('cal.addPressure')),
          ),
        ),
        SectionTitle(t('cal.flows')),
        for (var i = 0; i < flowReadings.length; i++)
          reading(
            ValueKey('cal_qrow_${gen}_$i'),
            SpecDropdown<MeasurePoint>(
              label: t('tool.supply'),
              value: flowReadings[i].entityId,
              items: supplies,
              labelOf: (m) => name(m.entityId),
              idOf: (m) => m.entityId,
              onChanged: (v) => change(() => flowReadings[i].entityId = v ?? flowReadings[i].entityId),
            ),
            NumField(
              key: ValueKey('cal_q_$i'),
              label: '${t('cal.measured')} (${u.flowLabel})',
              value: u.flowFromSi(flowReadings[i].value),
              onChanged: (v) => change(() => flowReadings[i].value = u.flowToSi(v)),
            ),
            NumField(label: 'σ (${u.flowLabel})', value: u.flowFromSi(flowReadings[i].sigma), onChanged: (v) => change(() => flowReadings[i].sigma = math.max(0, u.flowToSi(v)))),
            '${t('cal.model')} ${_q(u, model.$2[flowReadings[i].entityId] ?? 0)}',
            () => change(() {
              flowReadings.removeAt(i);
              gen++;
            }),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('cal_add_q'),
            onPressed: () => change(() => flowReadings.add(_Reading(supplies.first.entityId, model.$2[supplies.first.entityId] ?? 0))),
            icon: const Icon(Icons.add, size: 16),
            label: Text(t('cal.addFlow')),
          ),
        ),
        _note(t('cal.sigmaHint'), color: Cad.fg54),
        _runButton(const Key('cal_run'), t('cal.run'), Icons.tune, busy, run),
        if (res != null) ...[
          SectionTitle(t('dens.results')),
          if (res.scales.isNotEmpty) KV(t('cal.factor'), '${fmt(res.scales.single, 3)}${res.standardErrors.single.isFinite ? ' ± ${fmt(res.standardErrors.single, 3)}' : ''}'),
          KV(t('cal.scale'), '${fmt(params.hazenCScale, 3)} → ${fmt(scale, 3)}', color: canApply() ? Cad.ok : null),
          if (params.hazenCOffset != 0) KV(t('cal.offset'), '${fmt(params.hazenCOffset, 1)} → ${fmt(offset, 1)}'),
          KV(t('cal.objective'), '${fmt(res.initialObjective, 2)} → ${fmt(res.objective, 2)}'),
          if (res.residuals.any((x) => x.kind == MeasurementKind.pressure)) KV(t('cal.rmse'), '${_pr(u, res.rmsePressure)} ${u.pressureLabel}'),
          if (res.residuals.isNotEmpty)
            _table(
              [t('cal.point'), t('cal.measured'), t('cal.before'), t('cal.after'), t('cal.residual')],
              [
                for (final x in res.residuals)
                  [
                    _cell(name(result!.entityOf[x.id] ?? x.id)),
                    _cell(value(x, x.measured)),
                    _cell(value(x, x.before)),
                    _cell(value(x, x.after)),
                    _cell(value(x, x.residual), color: (x.residual / x.sigma).abs() > 2 ? Cad.warning : null),
                  ],
              ],
            ),
          if (result!.boundary.isNotEmpty) _note(t('cal.boundary', {'s': result!.boundary.map(name).join(', ')}), color: Cad.fg60),
          // one global factor: the group in the codes is always the first
          _codes(c, [
            for (final x in res.codes) x.startsWith('calibration_insensitive') || x.startsWith('calibration_at_bound') || x.startsWith('calibration_empty_group') ? x.split(':').first : x,
          ], name),
        ],
      ]);
    },
    actions: (ctx) => [
      FilledButton(
        key: const Key('cal_apply'),
        onPressed: !canApply()
            ? null
            : () {
                if (!c.editAllowed()) return;
                final factor = result!.result.scales.single;
                final edit = c.beginSettingsEdit('hist.calibration');
                final (s, o) = calibratedC(c.project.params, factor);
                c.project.params
                  ..hazenCScale = s
                  ..hazenCOffset = o;
                c.commitSettingsEdit(edit);
                Navigator.pop(ctx);
                c.notify(t('cal.applied', {'s': fmt(s, 3)}));
              },
        child: Text(t('cal.apply')),
      ),
    ],
  );
}

// ---------------------------------------------------------------- fertigation

/// Fertigation during one system flow: the product injected at a supply or a
/// pump, its travel along the mainline to every valve and on to the
/// farthest emitter of each zone (plug flow along the design flows), the
/// injection plan (pre-wetting, injection, flushing, amounts) and the check
/// of a venturi injector on a bypass of a mainline device.
Future<void> showFertigationDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final title = t('fert.title');
  final r = c.results;
  if (r == null) return _missing(context, c, title);
  final p = c.project;
  final d = opsDesigner(p, r, label: (k) => t(k));
  final flows = d.effectiveSystemFlows();
  final points = injectionPoints(d);
  if (flows.isEmpty || points.isEmpty) return _missing(context, c, title, 'fert.none');
  final u = c.units;
  final name = _namer(c, d);
  var flowId = flows.first.id;
  var injection = points.first;
  FertigationSetup? setup;
  String? setupKey;
  double? hours, areaM2;
  var dose = 50.0, nutrientPct = 100.0, stock = 0.25, tank = 0.0, prePct = 25.0, flushPct = 25.0, margin = 1.0;
  var site = '';
  var typedDp = 5.0, minPct = 20.0;
  final curve = List.generate(3, (_) => [0.0, 0.0]);
  var gen = 0;
  return _show(context, c, title, 780, (ctx, setState) {
    final sf = flows.firstWhere((f) => f.id == flowId);
    final key = '$flowId|$injection';
    if (setupKey != key) {
      setup = fertigationSetup(d, r, sf, injection);
      setupKey = key;
    }
    final s = setup;
    final irrigation = hours ?? sf.durationHours;
    final area = areaM2 ?? s?.areaM2 ?? 0;
    final plan = s == null
        ? null
        : planFertigation(
            FertigationInput(
              irrigationHours: irrigation,
              flow: s.flow,
              areaHa: area / 1e4,
              doseKgPerHa: dose,
              nutrientFraction: nutrientPct / 100,
              stockKgPerL: stock,
              preWettingFraction: prePct / 100,
              flushingFraction: flushPct / 100,
              flushingMargin: margin,
              tankLitres: tank,
            ),
            s.combined,
          );
    final sites = s == null ? const <VenturiSite>[] : venturiSites(s);
    final chosen = sites.where((x) => x.linkId == site).firstOrNull;
    final inlet = chosen?.inletPressure ?? (s?.result.nodes[s.injectionNode]?.pressure ?? 0);
    final dp = chosen?.headLoss ?? typedDp;
    final spec = VenturiSpec(
      curve: [
        for (final pt in curve)
          if (pt[0] > 0 && pt[1] > 0) (pt[0], pt[1] / 3.6e6),
      ],
      minDifferentialFraction: minPct / 100,
    );
    final venturi = plan == null ? null : checkVenturi(spec, injectionRate: plan.injectionRate, inletPressure: inlet, availableDifferential: dp);
    final areaUnit = u.areaFromSi(1);
    return _column([
      _hint(t('fert.hint')),
      _row([
        _flowPicker(
          c,
          flows,
          flowId,
          (id) => setState(() {
            flowId = id;
            hours = null;
            areaM2 = null;
            site = '';
            gen++;
          }),
        ),
        SpecDropdown<String>(
          key: const Key('fert_injection'),
          label: t('fert.injection'),
          value: injection,
          items: points,
          labelOf: name,
          idOf: (x) => x,
          onChanged: (v) => setState(() {
            injection = v ?? injection;
            site = '';
            gen++;
          }),
        ),
      ]),
      if (s == null)
        _note(t('fert.unreached'))
      else ...[
        SectionTitle(t('fert.travel')),
        _table(
          [t('rep.zone'), t('fert.valveFirst'), t('fert.valveFull'), t('fert.emitterFirst'), t('fert.emitterFull')],
          [
            for (final z in s.zones)
              [
                _cell(name(z.demandId)),
                _cell(_minutes(z.valveFirst)),
                _cell(_minutes(z.valveFull)),
                _cell(z.emitterFirst == null ? '-' : _minutes(z.emitterFirst!)),
                _cell(z.emitterFull == null ? '-' : _minutes(z.emitterFull!)),
              ],
          ],
        ),
        KV(t('fert.flow'), '${_q(u, s.flow)} ${u.flowLabel}'),
        KV(t('fert.volume'), '${fmt(u.volumeFromM3(s.mainline.volume), 2)} ${u.volumeLabel}'),
        KV(t('fert.farthest'), '${_minutes(s.farthestArrival)} / ${_minutes(s.fullArrival)} min'),
        _codes(c, s.mainline.codes, name),
        SectionTitle(t('fert.plan')),
        _row([
          NumField(key: ValueKey('fert_hours_$gen'), label: t('fert.hours'), value: irrigation, onChanged: (v) => setState(() => hours = v.clamp(0.1, 48).toDouble())),
          NumField(key: ValueKey('fert_area_$gen'), label: '${t('rep.area')} (${u.areaLabel})', value: u.areaFromSi(area), onChanged: (v) => setState(() => areaM2 = math.max(0, v) / areaUnit)),
          NumField(key: const Key('fert_dose'), label: t('fert.dose'), value: dose, onChanged: (v) => setState(() => dose = math.max(0, v))),
        ]),
        _row([
          NumField(label: t('fert.nutrient'), value: nutrientPct, decimals: 1, onChanged: (v) => setState(() => nutrientPct = v.clamp(0.1, 100).toDouble())),
          NumField(label: t('fert.stock'), value: stock, decimals: 3, onChanged: (v) => setState(() => stock = math.max(0, v))),
          NumField(label: t('fert.tank'), value: tank, decimals: 0, onChanged: (v) => setState(() => tank = math.max(0, v))),
        ]),
        _row([
          NumField(label: t('fert.pre'), value: prePct, decimals: 1, onChanged: (v) => setState(() => prePct = v.clamp(0, 100).toDouble())),
          NumField(label: t('fert.flush'), value: flushPct, decimals: 1, onChanged: (v) => setState(() => flushPct = v.clamp(0, 100).toDouble())),
          NumField(label: t('fert.margin'), value: margin, onChanged: (v) => setState(() => margin = v.clamp(0, 10).toDouble())),
        ]),
        if (plan != null) ...[
          KV(t('fert.preTime'), _hm(plan.preWetting)),
          KV(t('fert.injectionTime'), _hm(plan.injection), color: plan.injection > 0 ? Cad.ok : Cad.warning),
          KV(t('fert.flushTime'), _hm(plan.flushing)),
          KV(t('fert.product'), '${fmt(plan.productKg, 1)} kg'),
          KV(t('fert.stockVolume'), '${fmt(plan.stockLitres, 1)} L'),
          KV(t('fert.rate'), '${fmt(plan.injectionRate * 3.6e6, 1)} L/h'),
          KV(t('fert.concentration'), '${fmt(plan.concentration * 1000, 0)} g/m³ (ppm)'),
          if (plan.dilution > 0) KV(t('fert.dilution'), '1 : ${fmt(plan.dilution, 0)}'),
          _codes(c, plan.codes, name),
        ],
        SectionTitle(t('fert.venturi')),
        _row([
          SpecDropdown<String>(
            key: ValueKey('fert_site_$gen'),
            label: t('fert.bypass'),
            value: site,
            items: ['', for (final x in sites) x.linkId],
            labelOf: (id) => id.isEmpty ? t('fert.typed') : name(sites.firstWhere((x) => x.linkId == id).entityId),
            idOf: (x) => x,
            onChanged: (v) => setState(() => site = v ?? ''),
          ),
          NumField(
            key: ValueKey('fert_dp_${site}_$gen'),
            label: '${t('fert.differential')} (${u.pressureLabel})',
            value: u.pressureFromHead(dp),
            enabled: chosen == null,
            onChanged: (v) => setState(() => typedDp = math.max(0, u.pressureToHead(v))),
          ),
          NumField(label: t('fert.minDifferential'), value: minPct, decimals: 1, onChanged: (v) => setState(() => minPct = v.clamp(0, 100).toDouble())),
        ]),
        _note(t('fert.curveHint'), color: Cad.fg54),
        for (var i = 0; i < curve.length; i++)
          _row([
            NumField(
              label: '${t('fert.curveDp')} ${i + 1} (${u.pressureLabel})',
              value: u.pressureFromHead(curve[i][0]),
              onChanged: (v) => setState(() => curve[i][0] = math.max(0, u.pressureToHead(v))),
            ),
            NumField(label: '${t('fert.curveQ')} ${i + 1} (L/h)', value: curve[i][1], onChanged: (v) => setState(() => curve[i][1] = math.max(0, v))),
          ]),
        if (venturi != null) ...[
          KV(t('fert.vRequired'), '${_pr(u, venturi.requiredDifferential)} ${u.pressureLabel}'),
          KV(t('fert.vAvailable'), '${_pr(u, venturi.availableDifferential)} ${u.pressureLabel}'),
          if (venturi.suctionCapacity.isFinite) KV(t('fert.vSuction'), '${fmt(venturi.suctionCapacity * 3.6e6, 1)} L/h'),
          KV(t('fert.vResult'), t(venturi.ok ? 'fert.vOk' : 'fert.vFail'), color: venturi.ok ? Cad.ok : Cad.warning),
          _codes(c, venturi.codes, name),
        ],
      ],
    ]);
  });
}
