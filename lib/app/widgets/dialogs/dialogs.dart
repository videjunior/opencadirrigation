
import 'package:flutter/material.dart';

import '../../../core/design/agronomy.dart';
import '../../../core/design/block_generator.dart';
import '../../../core/design/management.dart';
import '../../../core/hydraulics/emitter.dart';
import '../../../core/hydraulics/friction.dart';
import '../../../core/hydraulics/lateral.dart';
import '../../../core/hydraulics/pump.dart';
import '../../../core/hydraulics/water_hammer.dart';
import '../../../core/model/catalog.dart';
import '../../../core/model/currency.dart';
import '../../../core/model/entities.dart';
import '../../../core/model/geometry.dart';
import '../../../core/model/project.dart';
import '../../../core/model/terrain.dart';
import '../../../core/units.dart';
import '../../io/file_io.dart';
import '../../io/links.dart';
import '../../io/prefs.dart';
import '../../state/controller.dart';
import '../../version.dart';
import '../fields.dart';

Future<void> _show(BuildContext context, ProjectController c, String title, Widget body, {List<Widget>? actions, double width = 520}) => showDialog<void>(
  context: context,
  builder: (ctx) {
    final compact = MediaQuery.sizeOf(ctx).width < 700;
    return AlertDialog(
      title: Text(title, style: const TextStyle(fontSize: 15)),
      scrollable: compact,
      content: SizedBox(width: compact ? MediaQuery.sizeOf(ctx).width - 48 : width, child: body),
      actions: actions ?? [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(c.t('close')))],
    );
  },
);

/// A dialog that edits the project settings in place: however it is closed
/// (OK, Esc, a tap outside), what was changed becomes one undo step and
/// marks the project as modified (see [ProjectController.commitSettingsEdit]).
Future<void> _showSettings(BuildContext context, ProjectController c, String label, String title, Widget body, {double width = 520, List<Widget> extraActions = const []}) {
  final edit = c.beginSettingsEdit(label);
  return _show(context, c, title, body, width: width, actions: [
    ...extraActions,
    FilledButton(onPressed: () => _closeCommitting(context), child: Text(c.t('ok'))),
  ]).then((_) => _commitAfterFocus(c, edit));
}

/// Takes the focus from the field being typed in (it commits its value on
/// focus loss) and closes the dialog.
void _closeCommitting(BuildContext context) {
  FocusManager.instance.primaryFocus?.unfocus();
  Navigator.pop(context);
}

/// Commits after the focus change has been applied (focus listeners run in
/// a microtask), so the last value typed is part of the edit.
Future<void> _commitAfterFocus(ProjectController c, SettingsEdit edit) async {
  await Future<void>.delayed(Duration.zero);
  c.commitSettingsEdit(edit);
}

Widget _row(List<Widget> children) => Row(children: [for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(width: 8), Expanded(child: children[i])]]);

// ---------------------------------------------------------------- project details

Future<void> showProjectDetailsDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final m = c.project.meta;
  return _showSettings(context, c, 'hist.details', t('file.details'), StatefulBuilder(builder: (ctx, setState) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      TextFieldRow(label: t('dlg.project'), value: m.name, onChanged: (v) => m.name = v),
      TextFieldRow(label: t('dlg.client'), value: m.client, onChanged: (v) => m.client = v),
      TextFieldRow(label: t('dlg.site'), value: m.site, onChanged: (v) => m.site = v),
      TextFieldRow(label: t('dlg.designer'), value: m.designer, onChanged: (v) => m.designer = v),
      TextFieldRow(label: t('dlg.notes'), value: m.notes, onChanged: (v) => m.notes = v, maxLines: 3),
    ]);
  }));
}

// ---------------------------------------------------------------- design parameters

Future<void> showDesignParamsDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final p = c.project.params;
  return _showSettings(context, c, 'hist.params', t('design.params'), width: 560, StatefulBuilder(builder: (ctx, setState) {
    return ScrollBody(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionTitle(t('dlg.hydraulics')),
        SpecDropdown<FrictionMethod>(label: t('dlg.frictionFormula'), value: p.frictionMethod.name, items: FrictionMethod.values, labelOf: (m) => m == FrictionMethod.hazenWilliams ? t('dlg.hw') : t('dlg.dw'), idOf: (m) => m.name, onChanged: (v) => setState(() => p.frictionMethod = FrictionMethod.values.byName(v!))),
        _row([
          NumField(label: t('dlg.waterTemp'), value: p.waterTempC, onChanged: (v) => p.waterTempC = v),
          NumField(label: t('dlg.vLateral'), value: p.maxLateralVelocity, onChanged: (v) => p.maxLateralVelocity = v),
        ]),
        _row([
          NumField(label: t('dlg.vZone'), value: p.maxZoneVelocity, onChanged: (v) => p.maxZoneVelocity = v),
          NumField(label: t('dlg.vMain'), value: p.maxMainlineVelocity, onChanged: (v) => p.maxMainlineVelocity = v),
        ]),
        _row([
          NumField(label: t('dlg.minorPct'), value: p.minorLossPct, onChanged: (v) => p.minorLossPct = v),
          NumField(label: t('dlg.connectTol'), value: p.connectTolerance, decimals: 3, onChanged: (v) => p.connectTolerance = v),
        ]),
        SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(t('dlg.applyMinor'), style: const TextStyle(fontSize: 12)), value: p.applyMinorLosses, onChanged: (v) => setState(() => p.applyMinorLosses = v)),
        _row([
          NumField(label: t('dlg.cScale'), value: p.hazenCScale, decimals: 3, onChanged: (v) => p.hazenCScale = v),
          NumField(label: t('dlg.cOffset'), value: p.hazenCOffset, onChanged: (v) => p.hazenCOffset = v),
        ]),
        SectionTitle(t('dlg.sizing')),
        SpecDropdown<SizingMethod>(label: t('dlg.sizingMethod'), value: p.sizingMethod.name, items: SizingMethod.values, labelOf: (m) => m == SizingMethod.lp ? t('dlg.lp') : t('dlg.greedy'), idOf: (m) => m.name, onChanged: (v) => setState(() => p.sizingMethod = SizingMethod.values.byName(v!))),
        _row([
          NumField(label: t('dlg.maxLateralSizes'), value: p.maxLateralSizes.toDouble(), decimals: 0, onChanged: (v) => p.maxLateralSizes = v.round().clamp(1, 3)),
          NumField(label: t('dlg.maxSubmainSizes'), value: p.maxSubmainSizes.toDouble(), decimals: 0, onChanged: (v) => p.maxSubmainSizes = v.round().clamp(1, 5)),
          NumField(label: t('dlg.maxMainlineSizes'), value: p.maxMainlineSizes.toDouble(), decimals: 0, onChanged: (v) => p.maxMainlineSizes = v.round().clamp(1, 5)),
        ]),
        _row([
          NumField(label: t('dlg.zoneVar'), value: p.maxZoneVariationPct, onChanged: (v) => p.maxZoneVariationPct = v),
          NumField(label: t('dlg.epp'), value: p.emittersPerPlant.toDouble(), decimals: 0, onChanged: (v) => p.emittersPerPlant = v.round().clamp(1, 20)),
        ]),
        _row([
          NumField(label: t('dlg.maxNodes'), value: p.maxNodesPerLateral.toDouble(), decimals: 0, onChanged: (v) => p.maxNodesPerLateral = v.round().clamp(2, 500)),
          NumField(label: t('dlg.densify'), value: p.terrainDensify, onChanged: (v) => p.terrainDensify = v),
        ]),
        SpecDropdown<TerrainMethod>(label: t('dlg.terrainMethod'), value: p.terrainMethod.name, items: TerrainMethod.values, labelOf: (m) => t(m == TerrainMethod.tin ? 'terrain.tin' : 'terrain.idw'), idOf: (m) => m.name, onChanged: (v) => setState(() => p.terrainMethod = TerrainMethod.values.byName(v!))),
        SectionTitle(t('dlg.flushing')),
        _row([
          NumField(label: t('dlg.flushV'), value: p.flushingVelocity, onChanged: (v) => p.flushingVelocity = v),
          NumField(label: t('dlg.flushH'), value: p.flushingMinEndHeadM, onChanged: (v) => p.flushingMinEndHeadM = v),
        ]),
        SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(t('dlg.checkSurge'), style: const TextStyle(fontSize: 12)), value: p.checkSurge, onChanged: (v) => setState(() => p.checkSurge = v)),
        NumField(label: t('dlg.closure'), value: p.valveClosureTimeS, onChanged: (v) => p.valveClosureTimeS = v),
        SectionTitle(t('dlg.bom')),
        SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(t('dlg.fittings'), style: const TextStyle(fontSize: 12)), value: p.selectFittings, onChanged: (v) => setState(() => p.selectFittings = v)),
        NumField(label: t('dlg.stick'), value: p.pipeStickLengthM, onChanged: (v) => p.pipeStickLengthM = v),
        SectionTitle(t('dlg.electrical')),
        _row([
          NumField(key: const Key('param_inrush'), label: t('dlg.inrushA'), value: p.solenoidInrushA, decimals: 3, onChanged: (v) => p.solenoidInrushA = v <= 0 ? p.solenoidInrushA : v),
          NumField(label: t('dlg.holdingA'), value: p.solenoidHoldingA, decimals: 3, onChanged: (v) => p.solenoidHoldingA = v < 0 ? p.solenoidHoldingA : v),
        ]),
        _row([
          NumField(label: t('dlg.minVolts'), value: p.solenoidMinVolts, onChanged: (v) => p.solenoidMinVolts = v <= 0 ? p.solenoidMinVolts : v),
          NumField(label: t('dlg.wireSlack'), value: p.wireSlackPct, onChanged: (v) => p.wireSlackPct = v < 0 ? 0 : v),
        ]),
        SectionTitle(t('dlg.economics')),
        SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(t('dlg.tradeCapital'), style: const TextStyle(fontSize: 12)), value: p.tradeCapitalVsRunning, onChanged: (v) => setState(() => p.tradeCapitalVsRunning = v)),
        _row([
          NumField(label: t('dlg.interest'), value: p.interestRate, decimals: 3, onChanged: (v) => p.interestRate = v),
          NumField(label: t('dlg.term'), value: p.termYears.toDouble(), decimals: 0, onChanged: (v) => p.termYears = v.round()),
        ]),
        _row([
          NumField(key: ValueKey('kwh_${p.currencyCode}_${p.currency}'), label: t('dlg.energyCost', {'c': p.currency}), value: p.powerCostPerKwh, decimals: 3, onChanged: (v) => p.powerCostPerKwh = v),
          NumField(label: t('dlg.pumpEff'), value: p.pumpEfficiency, onChanged: (v) => p.pumpEfficiency = v),
        ]),
        _row([
          NumField(label: t('dlg.hoursMain'), value: p.hoursPerYear, decimals: 0, onChanged: (v) => p.hoursPerYear = v),
          NumField(label: t('dlg.hoursZone'), value: p.zoneHoursPerYear, decimals: 0, onChanged: (v) => p.zoneHoursPerYear = v),
        ]),
        _row([
          SpecDropdown<Currency>(
            key: ValueKey('cur_${p.currencyCode}'),
            label: t('dlg.currency'),
            value: p.currencyCode.isEmpty ? null : p.currencyCode,
            items: currencies,
            allowNull: p.currencyCode.isEmpty,
            nullLabel: p.currency,
            labelOf: (x) => '${x.code} — ${x.symbol}',
            idOf: (x) => x.code,
            onChanged: (v) async {
              if (v == null || v == p.currencyCode) return;
              final rate = await askCurrencyConversion(ctx, c, p.currencyCode, v);
              if (rate == null) {
                setState(() {});
                return;
              }
              c.setProjectCurrency(v, rate: rate.$1 ? rate.$2 : null);
              setPref('currency', v);
              if (rate.$1) c.notify(t('msg.pricesConverted', {'from': rate.$3, 'to': v, 'r': fmtRate(rate.$2)}));
              setState(() {});
            },
          ),
          TextFieldRow(key: ValueKey('sym_${p.currencyCode}'), label: t('dlg.currencySymbol'), value: p.currency, onChanged: (v) => p.currency = v),
        ]),
        Text(t('dlg.currencyNote', {'d': exchangeRatesDate}), style: const TextStyle(fontSize: 10.5, color: Colors.white38)),
      ]),
    );
  }));
}

// ---------------------------------------------------------------- units

Future<void> showUnitsDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  var u = c.project.params.units;
  return _show(context, c, t('tools.units'), StatefulBuilder(builder: (ctx, setState) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        FilledButton.tonal(onPressed: () => setState(() => u = Units.metric), child: Text(t('dlg.metric'))),
        const SizedBox(width: 8),
        FilledButton.tonal(onPressed: () => setState(() => u = Units.us), child: Text(t('dlg.us'))),
      ]),
      SpecDropdown<LengthUnit>(label: t('dlg.length'), value: u.length.name, items: LengthUnit.values, labelOf: (x) => x.name, idOf: (x) => x.name, onChanged: (v) => setState(() => u = u.copyWith(length: LengthUnit.values.byName(v!)))),
      SpecDropdown<FlowUnit>(label: t('dlg.flow'), value: u.flow.name, items: FlowUnit.values, labelOf: (x) => x.name, idOf: (x) => x.name, onChanged: (v) => setState(() => u = u.copyWith(flow: FlowUnit.values.byName(v!)))),
      SpecDropdown<PressureUnit>(label: t('dlg.pressure'), value: u.pressure.name, items: PressureUnit.values, labelOf: (x) => x.name, idOf: (x) => x.name, onChanged: (v) => setState(() => u = u.copyWith(pressure: PressureUnit.values.byName(v!)))),
      SpecDropdown<DiameterUnit>(label: t('dlg.diameter'), value: u.diameter.name, items: DiameterUnit.values, labelOf: (x) => x.name, idOf: (x) => x.name, onChanged: (v) => setState(() => u = u.copyWith(diameter: DiameterUnit.values.byName(v!)))),
    ]);
  }), actions: [FilledButton(onPressed: () {
    final edit = c.beginSettingsEdit('hist.units');
    c.project.params.units = u;
    c.commitSettingsEdit(edit);
    Navigator.pop(context);
  }, child: Text(t('ok')))], width: 360);
}

// ---------------------------------------------------------------- management

Future<void> showManagementDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final u = c.units;
  final project = c.project;
  // zone valves and pivots: every demand a system flow can open
  final demands = demandIds(project);
  final flows = project.systemFlows;
  var tab = 0;
  var days = 7;
  var dayStart = 6.0;
  var keepStart = false;
  var showAuto = false;
  final auto = AutoFlowOptions(firstStartHour: flows.isEmpty ? 6 : flows.first.startHour);
  Map<String, double>? demandQ;
  AutoFlowPlan? lastPlan;
  String newId() => 'sf${DateTime.now().microsecondsSinceEpoch}';
  return _showSettings(context, c, 'hist.flows', t('design.management'), width: 620, StatefulBuilder(builder: (ctx, setState) {
    if (tab == 1) {
      final prog = buildControllerProgram(project, c.results, days: days, dayStartHour: dayStart, keepStartHours: keepStart);
      String hhmm(double h) {
        final hh = h.floor() % 24, mm = ((h - h.floor()) * 60).round();
        return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
      }

      return SizedBox(
        height: 460,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SegmentedButton<int>(segments: [ButtonSegment(value: 0, label: Text(t('mgmt.flows'))), ButtonSegment(value: 1, label: Text(t('mgmt.schedule')))], selected: {tab}, onSelectionChanged: (v) => setState(() => tab = v.first)),
          const SizedBox(height: 6),
          if (c.results == null) Text(t('mgmt.needResults'), style: const TextStyle(fontSize: 11.5, color: Colors.orange)),
          _row([
            NumField(label: t('mgmt.days'), value: days.toDouble(), decimals: 0, onChanged: (v) => setState(() => days = v.round().clamp(1, 60))),
            NumField(label: t('mgmt.dayStart'), value: dayStart, onChanged: (v) => setState(() => dayStart = v.clamp(0, 23))),
          ]),
          SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(t('mgmt.keepStart'), style: const TextStyle(fontSize: 12)), value: keepStart, onChanged: (v) => setState(() => keepStart = v)),
          for (final f in flows) Text(t('mgmt.perFlow', {'name': f.name, 'h': fmt(prog.perFlowHours[f.id] ?? 0, 2)}), style: const TextStyle(fontSize: 11.5)),
          Text(t('mgmt.maxDaily', {'h': fmt(prog.maxDailyHours, 1)}), style: TextStyle(fontSize: 11.5, color: prog.maxDailyHours > 24 ? Colors.orange : Colors.white70)),
          for (final w in prog.warnings) Text(c.t.warning(w), style: const TextStyle(fontSize: 11, color: Colors.orange)),
          Wrap(spacing: 8, runSpacing: 6, children: [
            FilledButton.tonal(onPressed: prog.entries.isEmpty ? null : () => setState(() {
              for (final f in flows) {
                final h = prog.perFlowHours[f.id];
                if (h != null && h > 0) f.durationHours = double.parse(h.toStringAsFixed(2));
              }
            }), child: Text(t('mgmt.apply'))),
            OutlinedButton(onPressed: prog.entries.isEmpty ? null : () => saveTextFile('${project.meta.name}_schedule.csv', controllerProgramCsv(prog, t: c.t.call), mime: 'text/csv'), child: Text(t('mgmt.export'))),
          ]),
          const SizedBox(height: 4),
          Expanded(
            child: SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingTextStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  dataTextStyle: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                  columns: [DataColumn(label: Text(t('sch.date'))), DataColumn(label: Text(t('sch.flow'))), DataColumn(label: Text(t('sch.zones'))), DataColumn(label: Text(t('sch.start'))), DataColumn(label: Text(t('sch.end'))), DataColumn(label: Text(t('sch.duration')))],
                  rows: [for (final e in prog.entries) DataRow(cells: [DataCell(Text(e.day.toIso8601String().substring(0, 10))), DataCell(Text(e.flowName)), DataCell(Text(e.zones.join(' + '))), DataCell(Text(hhmm(e.startHour))), DataCell(Text(hhmm(e.endHour))), DataCell(Text(fmt(e.durationHours, 2)))])],
                ),
              ),
            ),
          ),
        ]),
      );
    }
    String q(double v) => '${fmt(u.flowFromSi(v), 1)} ${u.flowLabel}';
    Widget autoPanel() {
      final cap = auto.maxFlow > 0 ? auto.maxFlow : suppliesDesignFlow(project);
      return Container(
        key: const Key('mgmt_auto_panel'),
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(4)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('mgmt.autoHint'), style: const TextStyle(fontSize: 11, color: Colors.white60)),
          const SizedBox(height: 6),
          _row([
            NumField(key: const Key('mgmt_auto_q'), label: t('mgmt.autoMaxFlow', {'u': u.flowLabel}), value: u.flowFromSi(auto.maxFlow), onChanged: (v) => setState(() => auto.maxFlow = v <= 0 ? 0 : u.flowToSi(v))),
            NumField(key: const Key('mgmt_auto_n'), label: t('mgmt.autoMaxValves'), value: auto.maxValves.toDouble(), decimals: 0, onChanged: (v) => setState(() => auto.maxValves = v.round().clamp(0, 999))),
          ]),
          _row([
            NumField(label: t('dlg.startHour'), value: auto.firstStartHour, onChanged: (v) => setState(() => auto.firstStartHour = v.clamp(0, 23.99))),
            NumField(label: t('dlg.durationHours'), value: auto.durationHours, onChanged: (v) => setState(() => auto.durationHours = v <= 0 ? 1 : v)),
          ]),
          Text(cap > 0 ? t('mgmt.autoCap', {'q': q(cap)}) : t('mgmt.autoNoCap'), style: TextStyle(fontSize: 11, color: cap > 0 ? Colors.white70 : Colors.orange)),
          const SizedBox(height: 4),
          FilledButton(key: const Key('mgmt_auto_run'), onPressed: demands.isEmpty ? null : () => setState(() {
            final plan = autoSystemFlows(project, auto, results: c.results, label: t.call);
            demandQ = plan.demands;
            lastPlan = plan;
            flows
              ..clear()
              ..addAll(plan.flows);
          }), child: Text(t('mgmt.autoRun'))),
          if (lastPlan != null) ...[
            Text(t('mgmt.autoResult', {'n': '${lastPlan!.flows.length}', 'q': q(peakFlowDemand(lastPlan!.flows, lastPlan!.demands))}), style: const TextStyle(fontSize: 11.5)),
            if (lastPlan!.oversized.isNotEmpty)
              Text(t('mgmt.autoOversized', {'z': lastPlan!.oversized.map((id) => demandName(project, id)).join(', ')}), style: const TextStyle(fontSize: 11, color: Colors.orange)),
          ],
        ]),
      );
    }

    return SizedBox(
      height: 460,
      child: Column(children: [
        SegmentedButton<int>(segments: [ButtonSegment(value: 0, label: Text(t('mgmt.flows'))), ButtonSegment(value: 1, label: Text(t('mgmt.schedule')))], selected: {tab}, onSelectionChanged: (v) => setState(() => tab = v.first)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          FilledButton.tonal(onPressed: demands.isEmpty ? null : () => setState(() {
            flows
              ..clear()
              ..add(SystemFlow(id: newId(), name: t('name.allZones'), valveIds: demands.toSet(), startHour: auto.firstStartHour));
          }), child: Text(t('dlg.allTogether'))),
          FilledButton.tonal(onPressed: demands.isEmpty ? null : () => setState(() {
            flows.clear();
            final base = newId();
            for (var i = 0; i < demands.length; i++) {
              flows.add(SystemFlow(id: '${base}_${i + 1}', name: '${t('name.flow')} ${i + 1} — ${demandName(project, demands[i])}', valveIds: {demands[i]}, startHour: (auto.firstStartHour + i) % 24));
            }
          }), child: Text(t('dlg.oneAtATime'))),
          FilledButton.tonal(key: const Key('mgmt_auto'), onPressed: () => setState(() {
            showAuto = !showAuto;
            demandQ ??= nominalDemands(project, results: c.results);
          }), child: Text(t('mgmt.auto'))),
          FilledButton.tonal(onPressed: () => setState(() => flows.add(SystemFlow(id: newId(), name: '${t('name.flow')} ${flows.length + 1}'))), child: Text(t('dlg.addFlow'))),
          TextButton(onPressed: () => setState(flows.clear), child: Text(t('clear'))),
        ]),
        if (showAuto) autoPanel(),
        const SizedBox(height: 6),
        Expanded(
          child: ListView(children: [
            for (final f in flows)
              Card(
                key: ObjectKey(f),
                margin: const EdgeInsets.symmetric(vertical: 3),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: TextFieldRow(label: t('dlg.name'), value: f.name, onChanged: (v) => f.name = v)),
                      const SizedBox(width: 6),
                      SizedBox(width: 90, child: NumField(label: t('dlg.startHour'), value: f.startHour, onChanged: (v) => f.startHour = v)),
                      const SizedBox(width: 6),
                      SizedBox(width: 90, child: NumField(label: t('dlg.durationHours'), value: f.durationHours, onChanged: (v) => f.durationHours = v)),
                      IconButton(icon: const Icon(Icons.delete_outline, size: 16), onPressed: () => setState(() => flows.remove(f))),
                    ]),
                    Wrap(spacing: 4, children: [
                      for (final id in demands)
                        FilterChip(label: Text(demandName(project, id), style: const TextStyle(fontSize: 11)), selected: f.valveIds.contains(id), onSelected: (s) => setState(() => s ? f.valveIds.add(id) : f.valveIds.remove(id))),
                    ]),
                    if (demandQ != null) Text(t('mgmt.demand', {'q': q(f.valveIds.fold(0.0, (s, id) => s + (demandQ![id] ?? 0)))}), style: const TextStyle(fontSize: 11, color: Colors.white60)),
                  ]),
                ),
              ),
            if (flows.isEmpty) Padding(padding: const EdgeInsets.all(12), child: Text(t('dlg.noFlows'), style: const TextStyle(color: Colors.white54))),
          ]),
        ),
      ]),
    );
  }));
}

// ---------------------------------------------------------------- block

Future<void> showBlockDialog(BuildContext context, ProjectController c, List<Pt> polygon) {
  final t = c.t;
  final cat = c.project.catalog;
  final s = c.toolSettings;
  var isTape = false;
  var lateralSpacing = 4.0;
  var outletSpacing = s.spacing;
  var direction = 0.0;
  var submainPos = SubmainPosition.start;
  var valvePos = ValvePosition.centre;
  var stub = 1.5;
  var halfOffset = true;
  var headM = s.headM;
  var tapeInlet = s.tapeInletHeadM;
  String? lateralPipe = s.lateralPipeSpecId;
  String? submainPipe;
  var valveSpec = s.valveSpecId;
  var outletSpec = s.outletSpecId;
  var nozzle = s.nozzleId;
  var tapeSpec = s.tapeSpecId;
  // a selected line / polyline / contour / spline becomes the guide of
  // curved laterals (spray lines along the contours)
  final guideEntity = c.project.entities.where((e) => c.selection.contains(e.id) && (e is PolylineEntity || e is ContourEntity || e is SplineEntity || e is LineEntity)).firstOrNull;
  final guidePts = guideEntity == null ? null : (guideEntity is SplineEntity ? guideEntity.curve() : guideEntity.linearPoints);
  var useGuide = guidePts != null && guidePts.length >= 2;
  var best = 0.0;
  for (var i = 0; i < polygon.length; i++) {
    final a = polygon[i], b = polygon[(i + 1) % polygon.length];
    if (a.distanceTo(b) > best) {
      best = a.distanceTo(b);
      direction = radToDeg((b - a).angle);
    }
  }
  final u = c.units;
  return _show(context, c, t('design.block'), StatefulBuilder(builder: (ctx, setState) {
    final outlet = cat.outlet(outletSpec);
    return ScrollBody(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        SegmentedButton<bool>(segments: [ButtonSegment(value: false, label: Text(t('dlg.sprayBlock'))), ButtonSegment(value: true, label: Text(t('dlg.dripBlock')))], selected: {isTape}, onSelectionChanged: (v) => setState(() => isTape = v.first)),
        SectionTitle(t('dlg.laterals')),
        if (!isTape) ...[
          SpecDropdown<OutletSpec>(label: t('props.outlet'), value: outletSpec, items: cat.outlets.where((o) => o.enabled && o.kind != OutletKind.demandPoint).toList(), labelOf: (x) => x.name, idOf: (x) => x.id, onChanged: (v) => setState(() {
            outletSpec = v ?? outletSpec;
            nozzle = cat.outlet(outletSpec)?.nozzles.firstOrNull?.id;
            headM = cat.outlet(outletSpec)?.nozzles.firstOrNull?.defaultHeadM ?? headM;
          })),
          if (outlet != null) SpecDropdown<NozzleSpec>(label: t('props.nozzle'), value: nozzle, items: outlet.nozzles, labelOf: (x) => x.name, idOf: (x) => x.id, onChanged: (v) => setState(() {
            nozzle = v;
            headM = outlet.nozzle(v)?.defaultHeadM ?? headM;
          })),
          _row([
            NumField(label: '${t('props.head')} (${u.pressureLabel})', value: u.pressureFromHead(headM), onChanged: (v) => headM = u.pressureToHead(v)),
            NumField(label: '${t('dlg.emitterSpacing')} (${u.lengthLabel})', value: u.lengthFromSi(outletSpacing), onChanged: (v) => setState(() => outletSpacing = v > 0 ? u.lengthToSi(v) : outletSpacing)),
          ]),
          SpecDropdown<PipeSpec>(label: t('dlg.lateralPipe'), value: lateralPipe, items: cat.pipesFor(PipeUsage.lateral), labelOf: (x) => x.name, idOf: (x) => x.id, allowNull: true, nullLabel: t('auto'), onChanged: (v) => setState(() => lateralPipe = v)),
          SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(t('props.halfSpacing'), style: const TextStyle(fontSize: 12)), value: halfOffset, onChanged: (v) => setState(() => halfOffset = v)),
        ] else ...[
          SpecDropdown<TapeSpec>(label: t('props.tape'), value: tapeSpec, items: cat.tapes.where((x) => x.enabled).toList(), labelOf: (x) => x.name, idOf: (x) => x.id, onChanged: (v) => setState(() {
            tapeSpec = v ?? tapeSpec;
            tapeInlet = cat.tape(tapeSpec)?.defaultInletHeadM ?? tapeInlet;
          })),
          NumField(label: '${t('props.inlet')} (${u.pressureLabel})', value: u.pressureFromHead(tapeInlet), onChanged: (v) => tapeInlet = u.pressureToHead(v)),
        ],
        _row([
          NumField(label: '${t('dlg.lateralSpacing')} (${u.lengthLabel})', value: u.lengthFromSi(lateralSpacing), onChanged: (v) => setState(() => lateralSpacing = v > 0 ? u.lengthToSi(v) : lateralSpacing)),
          NumField(label: t('dlg.lateralDirection'), value: direction, decimals: 1, onChanged: (v) => direction = v, enabled: !useGuide),
        ]),
        if (guidePts != null && guidePts.length >= 2)
          SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(t('dlg.followGuide', {'n': guideEntity!.name.isEmpty ? t('tool.${guideEntity is ContourEntity ? 'contour' : (guideEntity is SplineEntity ? 'spline' : (guideEntity is LineEntity ? 'line' : 'polyline'))}') : guideEntity.name}), style: const TextStyle(fontSize: 12)), value: useGuide, onChanged: (v) => setState(() => useGuide = v)),
        SectionTitle(t('dlg.submainValve')),
        SpecDropdown<SubmainPosition>(label: t('dlg.submainPosition'), value: submainPos.name, items: SubmainPosition.values, labelOf: (x) => switch (x) { SubmainPosition.start => t('dlg.submainStart'), SubmainPosition.centre => t('dlg.submainCentre'), SubmainPosition.end => t('dlg.submainEnd') }, idOf: (x) => x.name, onChanged: (v) => setState(() => submainPos = SubmainPosition.values.byName(v!))),
        SpecDropdown<PipeSpec>(label: t('dlg.submainPipe'), value: submainPipe, items: cat.pipesFor(PipeUsage.zone), labelOf: (x) => x.name, idOf: (x) => x.id, allowNull: true, nullLabel: t('auto'), onChanged: (v) => setState(() => submainPipe = v)),
        _row([
          SpecDropdown<ValveSpec>(label: t('props.valve'), value: valveSpec, items: cat.valves.where((x) => x.enabled && x.kind == ValveKind.control).toList(), labelOf: (x) => x.name, idOf: (x) => x.id, onChanged: (v) => setState(() => valveSpec = v ?? valveSpec)),
          SpecDropdown<ValvePosition>(label: t('dlg.valvePosition'), value: valvePos.name, items: ValvePosition.values, labelOf: (x) => switch (x) { ValvePosition.start => t('dlg.posStart'), ValvePosition.centre => t('dlg.posCentre'), ValvePosition.end => t('dlg.posEnd') }, idOf: (x) => x.name, onChanged: (v) => setState(() => valvePos = ValvePosition.values.byName(v!))),
        ]),
        NumField(label: '${t('dlg.stub')} (${u.lengthLabel})', value: u.lengthFromSi(stub), onChanged: (v) => stub = u.lengthToSi(v)),
      ]),
    );
  }), actions: [
    TextButton(onPressed: () => Navigator.pop(context), child: Text(t('cancel'))),
    FilledButton(onPressed: () {
      final dir = Pt.polar(1, degToRad(direction));
      c.addBlock(BlockOptions(
        polygon: polygon,
        direction: dir,
        guide: useGuide ? guidePts : null,
        lateralSpacing: lateralSpacing,
        isTape: isTape,
        tapeSpecId: tapeSpec,
        tapeInletHeadM: tapeInlet,
        outletSpecId: outletSpec,
        nozzleId: nozzle,
        outletSpacing: outletSpacing,
        outletOffsetHalf: halfOffset,
        headM: headM,
        lateralPipeSpecId: lateralPipe,
        submainPipeSpecId: submainPipe,
        submainPosition: submainPos,
        valveSpecId: valveSpec,
        valvePosition: valvePos,
        submainStub: stub,
        zoneName: c.project.uniqueZoneName(t('name.zone')),
        submainLabel: t('name.submain'),
        stubLabel: t('name.stub'),
        lateralPrefix: t('name.lateral'),
      ));
      c.setTool(ToolId.select);
      Navigator.pop(context);
    }, child: Text(t('ok'))),
  ], width: 560);
}

// ---------------------------------------------------------------- autohead grid

Future<void> showAutoheadDialog(BuildContext context, ProjectController c, List<Pt> polygon) {
  final t = c.t;
  final cat = c.project.catalog;
  final s = c.toolSettings;
  var outletSpec = s.outletSpecId;
  var nozzle = s.nozzleId;
  var headM = s.headM;
  var pattern = GridPattern.square;
  var pct = 50.0;
  var direction = 0.0;
  final u = c.units;
  return _show(context, c, t('design.autohead'), StatefulBuilder(builder: (ctx, setState) {
    final outlet = cat.outlet(outletSpec);
    final nz = outlet?.nozzle(nozzle);
    final radius = nz?.curve.radius(headM) ?? 0;
    final spacing = radius > 0 ? 2 * radius * pct / 100 : 10.0;
    final between = pattern == GridPattern.triangular ? spacing * 0.866 : spacing;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      SpecDropdown<OutletSpec>(label: t('props.outlet'), value: outletSpec, items: cat.outlets.where((o) => o.enabled && (o.kind == OutletKind.sprinkler || o.kind == OutletKind.microSprinkler)).toList(), labelOf: (x) => x.name, idOf: (x) => x.id, onChanged: (v) => setState(() {
        outletSpec = v ?? outletSpec;
        nozzle = cat.outlet(outletSpec)?.nozzles.firstOrNull?.id;
        headM = cat.outlet(outletSpec)?.nozzles.firstOrNull?.defaultHeadM ?? headM;
      })),
      if (outlet != null) SpecDropdown<NozzleSpec>(label: t('props.nozzle'), value: nozzle, items: outlet.nozzles, labelOf: (x) => x.name, idOf: (x) => x.id, onChanged: (v) => setState(() => nozzle = v)),
      NumField(label: '${t('props.head')} (${u.pressureLabel})', value: u.pressureFromHead(headM), onChanged: (v) => setState(() => headM = u.pressureToHead(v))),
      _row([
        NumField(label: t('dlg.spacingPct'), value: pct, onChanged: (v) => setState(() => pct = v > 0 ? v : pct)),
        NumField(label: t('dlg.direction'), value: direction, onChanged: (v) => direction = v),
      ]),
      SegmentedButton<GridPattern>(segments: [ButtonSegment(value: GridPattern.square, label: Text(t('dlg.square'))), ButtonSegment(value: GridPattern.triangular, label: Text(t('dlg.triangular')))], selected: {pattern}, onSelectionChanged: (v) => setState(() => pattern = v.first)),
      const SizedBox(height: 8),
      Text(
        t('dlg.gridSummary', {
          'r': fmt(radius, 1),
          's': fmt(spacing, 1),
          'pr': fmt(precipitationMmPerHour(precipitationRate(flow: nz?.curve.flow(headM) ?? 0, spacingAlong: spacing, spacingBetween: between)), 1),
          'cu': fmt(gridOverlapCU(radius: radius, spacingAlong: spacing, spacingBetween: between, triangular: pattern == GridPattern.triangular), 0),
        }),
        style: const TextStyle(fontSize: 11.5, color: Colors.white70),
      ),
    ]);
  }), actions: [
    TextButton(onPressed: () => Navigator.pop(context), child: Text(t('cancel'))),
    FilledButton(onPressed: () {
      final nz = cat.outlet(outletSpec)?.nozzle(nozzle);
      final radius = nz?.curve.radius(headM) ?? 0;
      final spacing = radius > 0 ? 2 * radius * pct / 100 : 10.0;
      c.addSprinklerGrid(SprinklerGridOptions(polygon: polygon, outletSpecId: outletSpec, nozzleId: nozzle, spacingAlong: spacing, spacingBetween: pattern == GridPattern.triangular ? spacing * 0.866 : spacing, pattern: pattern, direction: Pt.polar(1, degToRad(direction)), headM: headM));
      c.setTool(ToolId.select);
      Navigator.pop(context);
    }, child: Text(t('ok'))),
  ], width: 460);
}

// ---------------------------------------------------------------- text

Future<void> showTextDialog(BuildContext context, ProjectController c, Pt position) {
  final t = c.t;
  var text = c.toolSettings.text;
  var height = c.toolSettings.textHeight;
  return _show(context, c, t('tool.text'), Column(mainAxisSize: MainAxisSize.min, children: [
    TextFieldRow(label: t('props.text'), value: text, onChanged: (v) => text = v),
    NumField(label: t('props.textHeight'), value: height, onChanged: (v) => height = v),
  ]), actions: [
    TextButton(onPressed: () => Navigator.pop(context), child: Text(t('cancel'))),
    FilledButton(onPressed: () {
      c.toolSettings.text = text;
      c.toolSettings.textHeight = height;
      c.addEntity(TextEntity(id: c.project.newId(), position: position, text: text, height: height));
      Navigator.pop(context);
    }, child: Text(t('ok'))),
  ], width: 380);
}

// ---------------------------------------------------------------- leader

Future<void> showLeaderDialog(BuildContext context, ProjectController c, List<Pt> points) {
  final t = c.t;
  var text = c.toolSettings.leaderText;
  var height = c.toolSettings.textHeight;
  return _show(context, c, t('tool.leader'), Column(mainAxisSize: MainAxisSize.min, children: [
    TextFieldRow(label: t('props.text'), value: text, onChanged: (v) => text = v),
    NumField(label: t('props.textHeight'), value: height, onChanged: (v) => height = v),
  ]), actions: [
    TextButton(onPressed: () => Navigator.pop(context), child: Text(t('cancel'))),
    FilledButton(onPressed: () {
      c.toolSettings.leaderText = text;
      c.addEntity(LeaderEntity(id: c.project.newId(), points: points, text: text, height: height));
      Navigator.pop(context);
    }, child: Text(t('ok'))),
  ], width: 380);
}

// ---------------------------------------------------------------- lateral calculator

Future<void> showLateralCalculator(BuildContext context, ProjectController c) {
  final t = c.t;
  final cat = c.project.catalog;
  final u = c.units;
  // a catalogue without tapes, emitters or lateral pipes offers what it has
  final tapes = cat.tapes;
  final outlets = cat.outlets.where((o) => o.nozzles.isNotEmpty).toList();
  final pipes = cat.pipesFor(PipeUsage.lateral);
  final canTape = tapes.isNotEmpty, canEmitter = outlets.isNotEmpty && pipes.isNotEmpty;
  if (!canTape && !canEmitter) {
    c.notify(t('msg.lateralNeedsCatalog'));
    return Future.value();
  }
  var useTape = canTape;
  var tapeId = canTape ? tapes.first.id : '';
  var outletId = canEmitter ? outlets.first.id : '';
  String? nozzleId = canEmitter ? outlets.first.nozzles.first.id : null;
  var pipeId = canEmitter ? pipes.first.id : '';
  var length = 100.0;
  var spacing = 4.0;
  var inlet = 10.0;
  var slopePct = 0.0;
  var tolBelow = 10.0;
  var tolAbove = 10.0;
  return _show(context, c, t('tools.lateral'), StatefulBuilder(builder: (ctx, setState) {
    LateralSpec spec;
    double cv;
    if (useTape) {
      final tp = cat.tape(tapeId)!;
      spec = LateralSpec(length: length, diameter: tp.innerDiameter, spacing: tp.emitterSpacingM, emitter: tp.emitter, barbK: tp.barbK, method: c.project.params.frictionMethod, hazenC: tp.hazenC, roughness: tp.roughnessMm / 1000, kinematicViscosity: c.project.params.kinematicViscosity);
      cv = tp.cv;
    } else {
      final o = cat.outlet(outletId)!;
      final n = o.nozzle(nozzleId)!;
      final p = cat.pipe(pipeId)!;
      spec = LateralSpec(length: length, diameter: p.innerDiameter, spacing: spacing, emitter: n.curve, firstOffset: spacing / 2, method: c.project.params.frictionMethod, hazenC: p.hazenC, roughness: p.roughness, kinematicViscosity: c.project.params.kinematicViscosity);
      cv = n.cv;
    }
    final nominal = inlet;
    double z(double d) => -slopePct / 100 * d;
    final res = analyzeLateralFromInlet(spec, inlet, elevationAt: z, manufacturerCv: cv);
    final lo = nominal * (1 - tolBelow / 100), hi = nominal * (1 + tolAbove / 100);
    final maxLen = maxLateralLength(spec, nominalPressure: nominal, minPressure: lo, maxPressure: hi, elevationAt: z, maxLength: 600);
    return ScrollBody(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        SegmentedButton<bool>(segments: [ButtonSegment(value: true, label: Text(t('dlg.tapeLateral')), enabled: canTape), ButtonSegment(value: false, label: Text(t('dlg.emitterLateral')), enabled: canEmitter)], selected: {useTape}, onSelectionChanged: (v) => setState(() => useTape = v.first)),
        if (useTape)
          SpecDropdown<TapeSpec>(label: t('props.tape'), value: tapeId, items: tapes, labelOf: (x) => x.name, idOf: (x) => x.id, onChanged: (v) => setState(() => tapeId = v!))
        else ...[
          SpecDropdown<OutletSpec>(label: t('props.outlet'), value: outletId, items: outlets, labelOf: (x) => x.name, idOf: (x) => x.id, onChanged: (v) => setState(() {
            outletId = v!;
            nozzleId = cat.outlet(v)!.nozzles.first.id;
          })),
          SpecDropdown<NozzleSpec>(label: t('props.nozzle'), value: nozzleId, items: cat.outlet(outletId)!.nozzles, labelOf: (x) => x.name, idOf: (x) => x.id, onChanged: (v) => setState(() => nozzleId = v)),
          SpecDropdown<PipeSpec>(label: t('props.pipe'), value: pipeId, items: pipes, labelOf: (x) => x.name, idOf: (x) => x.id, onChanged: (v) => setState(() => pipeId = v!)),
          NumField(label: '${t('props.spacing')} (${u.lengthLabel})', value: u.lengthFromSi(spacing), onChanged: (v) => setState(() => spacing = v > 0 ? u.lengthToSi(v) : spacing)),
        ],
        _row([
          NumField(label: '${t('props.length')} (${u.lengthLabel})', value: u.lengthFromSi(length), onChanged: (v) => setState(() => length = u.lengthToSi(v))),
          NumField(label: '${t('props.inlet')} (${u.pressureLabel})', value: u.pressureFromHead(inlet), onChanged: (v) => setState(() => inlet = u.pressureToHead(v))),
          NumField(label: t('dlg.slope'), value: slopePct, onChanged: (v) => setState(() => slopePct = v)),
        ]),
        _row([
          NumField(label: t('dlg.tolBelow'), value: tolBelow, onChanged: (v) => setState(() => tolBelow = v)),
          NumField(label: t('dlg.tolAbove'), value: tolAbove, onChanged: (v) => setState(() => tolAbove = v)),
        ]),
        SectionTitle(t('dlg.results')),
        KV(t('dlg.emittersCount'), '${spec.outletCount}'),
        KV(t('dlg.inletFlow'), '${fmt(u.flowFromSi(res.inletFlow), 1)} ${u.flowLabel}'),
        KV(t('dlg.totalLoss'), '${fmt(u.pressureFromHead(res.frictionLoss), 2)} ${u.pressureLabel}'),
        KV(t('dlg.endPressure'), '${fmt(u.pressureFromHead(res.endPressure), 2)} ${u.pressureLabel}'),
        KV(t('dlg.pMinMax'), '${fmt(u.pressureFromHead(res.minPressure), 2)} (${fmt(res.minPressureDistance, 0)} m) / ${fmt(u.pressureFromHead(res.maxPressure), 2)} ${u.pressureLabel}'),
        KV(t('dlg.pVariation'), '${fmt(res.pressureVariationPct, 1)} %'),
        KV(t('dlg.maxVelocity'), '${fmt(res.maxVelocity, 2)} m/s'),
        KV(t('dlg.uniformity4'), '${fmt(res.uniformity.cu, 1)} / ${fmt(res.uniformity.du, 1)} / ${fmt(res.uniformity.eu, 1)} / ${fmt(res.uniformity.us, 1)} %'),
        KV(t('dlg.qvar'), '${fmt(res.uniformity.qvar, 1)} %'),
        KV(t('dlg.maxLength'), '${fmt(u.lengthFromSi(maxLen), 1)} ${u.lengthLabel}'),
      ]),
    );
  }), width: 620);
}

// ---------------------------------------------------------------- pump calculator

Future<void> showPumpCalculator(BuildContext context, ProjectController c) {
  final t = c.t;
  final cat = c.project.catalog;
  final u = c.units;
  var pumpId = cat.pumps.first.id;
  var staticHead = 20.0;
  var lengthM = 500.0;
  var pipeId = cat.pipesFor(PipeUsage.mainline)[2].id;
  var speed = 1.0;
  var hours = c.project.params.hoursPerYear;
  return _show(context, c, t('tools.pump'), StatefulBuilder(builder: (ctx, setState) {
    final pump = cat.pump(pumpId)!;
    final pipe = cat.pipe(pipeId)!;
    final curve = pump.curve.withSpeed(speed);
    final k = hazenWilliamsResistance(diameter: pipe.innerDiameter, length: lengthM, c: pipe.hazenC);
    final sys = SystemCurve(staticHead: staticHead, k: k, n: 1.852);
    final op = operatingPoint(curve, sys, qMax: 0.05);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      SpecDropdown<PumpSpec>(label: t('props.pump'), value: pumpId, items: cat.pumps, labelOf: (x) => x.name, idOf: (x) => x.id, onChanged: (v) => setState(() => pumpId = v!)),
      _row([
        NumField(label: '${t('dlg.staticHead')} (${u.pressureLabel})', value: u.pressureFromHead(staticHead), onChanged: (v) => setState(() => staticHead = u.pressureToHead(v))),
        NumField(label: t('dlg.speed'), value: speed, onChanged: (v) => setState(() => speed = v)),
      ]),
      SpecDropdown<PipeSpec>(label: t('dlg.mainPipe'), value: pipeId, items: cat.pipesFor(PipeUsage.mainline), labelOf: (x) => x.name, idOf: (x) => x.id, onChanged: (v) => setState(() => pipeId = v!)),
      _row([
        NumField(label: '${t('props.length')} (${u.lengthLabel})', value: u.lengthFromSi(lengthM), onChanged: (v) => setState(() => lengthM = u.lengthToSi(v))),
        NumField(label: t('dlg.hoursYear'), value: hours, decimals: 0, onChanged: (v) => setState(() => hours = v)),
      ]),
      SectionTitle(t('dlg.operatingPoint')),
      if (op == null) Text(t('dlg.pumpCannot'), style: const TextStyle(color: Colors.orange)) else ...[
        KV(t('dlg.flow'), '${fmt(u.flowFromSi(op.$1), 2)} ${u.flowLabel}'),
        KV(t('dlg.head'), '${fmt(u.pressureFromHead(op.$2), 2)} ${u.pressureLabel}'),
        KV(t('dlg.velocityMain'), '${fmt(velocity(flow: op.$1, diameter: pipe.innerDiameter), 2)} m/s'),
        KV(t('dlg.hydraulicPower'), '${fmt(hydraulicPower(flow: op.$1, head: op.$2) / 1000, 2)} kW'),
        KV(t('dlg.shaftPower', {'e': fmt(pump.efficiency * 100, 0)}), '${fmt(shaftPower(flow: op.$1, head: op.$2, efficiency: pump.efficiency) / 1000, 2)} kW (${fmt(shaftPower(flow: op.$1, head: op.$2, efficiency: pump.efficiency) / 735.5, 1)} cv)'),
        KV(t('dlg.annualEnergy'), '${fmt(shaftPower(flow: op.$1, head: op.$2, efficiency: pump.efficiency) / 1000 * hours, 0)} kWh → ${c.project.params.currency} ${fmt(annualEnergyCost(flow: op.$1, head: op.$2, hoursPerYear: hours, costPerKwh: c.project.params.powerCostPerKwh, pumpEfficiency: pump.efficiency), 0)}'),
      ],
      KV(t('dlg.shutoffRunout'), '${fmt(u.pressureFromHead(curve.shutoffHead), 1)} ${u.pressureLabel} / ${curve.runoutFlow.isFinite ? fmt(u.flowFromSi(curve.runoutFlow), 1) : '∞'} ${u.flowLabel}'),
    ]);
  }), width: 520);
}

// ---------------------------------------------------------------- water hammer

Future<void> showHammerCalculator(BuildContext context, ProjectController c) {
  final t = c.t;
  final cat = c.project.catalog;
  final u = c.units;
  var pipeId = cat.pipesFor(PipeUsage.mainline).first.id;
  var vel = 1.5;
  var lengthM = 500.0;
  var closure = 2.0;
  var staticP = 40.0;
  return _show(context, c, t('tools.hammer'), StatefulBuilder(builder: (ctx, setState) {
    final pipe = cat.pipe(pipeId)!;
    final a = waveCelerity(diameter: pipe.innerDiameter, wallThickness: pipe.wallThicknessMm / 1000, material: pipe.material);
    final dh = joukowskySurgeHead(celerity: a, velocityChange: vel);
    final tc = criticalClosureTime(length: lengthM, celerity: a);
    final effective = closure < tc ? dh : dh * tc / closure;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      SpecDropdown<PipeSpec>(label: t('props.pipe'), value: pipeId, items: cat.pipes, labelOf: (x) => '${x.name} (${t('mat.${x.material.name}')})', idOf: (x) => x.id, onChanged: (v) => setState(() => pipeId = v!)),
      _row([
        NumField(label: t('dlg.velocity'), value: vel, onChanged: (v) => setState(() => vel = v)),
        NumField(label: '${t('props.length')} (${u.lengthLabel})', value: u.lengthFromSi(lengthM), onChanged: (v) => setState(() => lengthM = u.lengthToSi(v))),
      ]),
      _row([
        NumField(label: t('dlg.closureTime'), value: closure, onChanged: (v) => setState(() => closure = v)),
        NumField(label: '${t('dlg.staticPressure')} (${u.pressureLabel})', value: u.pressureFromHead(staticP), onChanged: (v) => setState(() => staticP = u.pressureToHead(v))),
      ]),
      SectionTitle(t('dlg.resultJoukowsky')),
      KV(t('dlg.celerity'), '${fmt(a, 0)} m/s'),
      KV(t('dlg.maxSurge'), '${fmt(u.pressureFromHead(dh), 1)} ${u.pressureLabel}'),
      KV(t('dlg.criticalTime'), '${fmt(tc, 2)} s'),
      KV(t('dlg.estSurge', {'s': fmt(closure, 1)}), '${fmt(u.pressureFromHead(effective), 1)} ${u.pressureLabel}'),
      KV(t('dlg.totalPressure'), '${fmt(u.pressureFromHead(staticP + effective), 1)} ${u.pressureLabel}', color: staticP + effective > pipe.pressureRatingM ? Colors.orange : Colors.green),
      KV(t('dlg.pipeClass'), '${fmt(u.pressureFromHead(pipe.pressureRatingM), 0)} ${u.pressureLabel}'),
    ]);
  }), width: 520);
}

// ---------------------------------------------------------------- about

Future<void> showAboutDialogApp(BuildContext context, ProjectController c) => _show(
  context,
  c,
  c.t('help.about'),
  Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
    Center(child: Padding(padding: const EdgeInsets.only(bottom: 10), child: Image.asset('assets/brand/logo-horizontal.png', width: 380, filterQuality: FilterQuality.medium, semanticLabel: 'OpenCADIrrigation'))),
    // full build identification: version, build number, date and git commit
    Center(
      child: Container(
        key: const Key('about_version'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: const Color(0xFF232830), borderRadius: BorderRadius.circular(4)),
        child: SelectableText(c.t('about.version', {'v': appVersionLabel}), style: const TextStyle(fontSize: 12.5, fontFamily: 'monospace', color: Color(0xFF90CAF9))),
      ),
    ),
    const SizedBox(height: 12),
    Text(c.t('about.text'), style: const TextStyle(fontSize: 13, height: 1.4)),
    const SizedBox(height: 12),
    _ExternalLink(key: const Key('about_site'), icon: Icons.public, label: c.t('about.site'), url: appSiteUrl),
  ]),
);

/// A label with its URL underneath; the whole row opens the page in a new tab.
class _ExternalLink extends StatelessWidget {
  const _ExternalLink({super.key, required this.icon, required this.label, required this.url});
  final IconData icon;
  final String label;
  final String url;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => openExternalLink(url),
    borderRadius: BorderRadius.circular(4),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: Row(children: [
        Icon(icon, size: 18, color: const Color(0xFF64B5F6)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 12.5)),
            Text(url, style: const TextStyle(fontSize: 12, color: Color(0xFF42A5F5), decoration: TextDecoration.underline, decorationColor: Color(0xFF42A5F5))),
          ]),
        ),
        const Icon(Icons.open_in_new, size: 14, color: Colors.white38),
      ]),
    ),
  );
}


/// Asks whether the prices follow a currency change from [from] to [to]:
/// (convert?, rate, from label) or null when the change is cancelled. The
/// reference rate is offered and can be edited.
Future<(bool, double, String)?> askCurrencyConversion(BuildContext context, ProjectController c, String from, String to) {
  final t = c.t;
  final known = exchangeRate(from, to);
  var rate = known ?? 1.0;
  final fromLabel = from.isEmpty ? c.project.params.currency : from;
  return showDialog<(bool, double, String)>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(t('dlg.convertPricesTitle'), style: const TextStyle(fontSize: 15)),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('dlg.convertPricesBody', {'from': fromLabel, 'to': to}), style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          NumField(key: const Key('cur_rate'), label: t('dlg.rate', {'from': fromLabel, 'to': to}), value: rate, decimals: 6, onChanged: (v) => rate = v),
          Text(known == null ? t('dlg.rateUnknown') : t('dlg.rateSource', {'d': exchangeRatesDate}), style: const TextStyle(fontSize: 10.5, color: Colors.white38)),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('cancel'))),
        TextButton(key: const Key('cur_only'), onPressed: () => Navigator.pop(ctx, (false, rate, fromLabel)), child: Text(t('dlg.onlyCurrency'))),
        FilledButton(key: const Key('cur_convert'), onPressed: () => Navigator.pop(ctx, (rate > 0, rate, fromLabel)), child: Text(t('dlg.convert'))),
      ],
    ),
  );
}
