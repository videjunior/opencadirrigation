/// Dialogs of the machines, electrical and water design of 1.6.0: the pump
/// house electrics (motors, starters, feeders, transformer) with the
/// pivots' supply, solar pumping in the design, the water analysis with its
/// filtration and treatment, and two-wire (decoder) valve wiring. Each one
/// edits a copy of its settings and shows the result worked out on the last
/// design as the fields change; Apply stores the settings as one undo step
/// (the design results, priced with the old ones, are discarded).
library;

import 'package:flutter/material.dart';

import '../../../core/design/agb_design.dart';
import '../../../core/design/network_ops.dart' show wiringFlows;
import '../../../core/design/pump_house.dart';
import '../../../core/design/solar_design.dart';
import '../../../core/design/two_wire.dart';
import '../../../core/design/water_quality.dart';
import '../../../core/model/agb_settings.dart';
import '../../../core/model/entities.dart';
import '../../../core/model/project.dart';
import '../../state/controller.dart';
import '../../theme.dart';
import '../fields.dart';
import 'mechanised_dialogs.dart' show fieldGrid, resultTable;
import 'terrain_dialogs.dart' show dialogWidth;

// ---------------------------------------------------------------- shared

Widget _column(List<Widget> children) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: children);

Widget _hint(String s) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Text(s, style: TextStyle(fontSize: 12, color: Cad.fg70)),
);

Widget _notes(ProjectController c, Iterable<String> codes) {
  final lines = codes.map((w) => c.t.warning(w, entityName: c.entityName)).toSet();
  if (lines.isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Text(lines.join('\n'), style: TextStyle(fontSize: 11.5, color: Cad.warning)),
  );
}

Widget _switch(String label, bool value, ValueChanged<bool> onChanged, {Key? key}) => SwitchListTile(
  key: key,
  dense: true,
  contentPadding: EdgeInsets.zero,
  title: Text(label, style: const TextStyle(fontSize: 12)),
  value: value,
  onChanged: onChanged,
);

/// A dialog of the house style (never `scrollable`: the body scrolls
/// itself); Close and the [actions].
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

/// [f] worked out with [draft] in place of the project's settings.
T withAgbSettings<T>(Project p, AgbSettings draft, T Function() f) {
  final keep = p.agb;
  p.agb = draft;
  try {
    return f();
  } finally {
    p.agb = keep;
  }
}

/// Stores [draft] as the project's settings: one undo step; the results go.
bool applyAgbSettings(ProjectController c, AgbSettings draft) {
  if (!c.editAllowed()) return false;
  final edit = c.beginSettingsEdit('hist.agb');
  c.project.agb = draft;
  return c.commitSettingsEdit(edit);
}

/// A number that may be left empty (not analysed).
class _OptNum extends StatefulWidget {
  const _OptNum({super.key, required this.label, required this.value, required this.onChanged, this.decimals = 2});
  final String label;
  final double? value;
  final int decimals;
  final ValueChanged<double?> onChanged;
  @override
  State<_OptNum> createState() => _OptNumState();
}

class _OptNumState extends State<_OptNum> {
  late final TextEditingController _c = TextEditingController(text: widget.value == null ? '' : fmtUi(widget.value!, widget.decimals));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: TextField(
      controller: _c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(fontSize: 12),
      decoration: InputDecoration(labelText: widget.label, isDense: true),
      onChanged: (s) {
        final t = s.trim();
        if (t.isEmpty) {
          widget.onChanged(null);
          return;
        }
        final v = parseUiNumber(t);
        if (v != null && v.isFinite && v >= 0) widget.onChanged(v);
      },
    ),
  );
}

String _fx(double v, [int d = 1]) => fmtUi(v, d);

// ---------------------------------------------------------------- pump house

/// Electrical design of the pump house: the supply, the cables and the
/// motor data of every pump, with the circuits, the transformer or
/// generator, the short-circuit level, the tariff group and the pivots'
/// supply worked out on the last design.
Future<void> showPumpHouseDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final u = c.units;
  final draft = c.project.agb.clone();
  final pumps = c.project.entities.whereType<PumpEntity>().toList();
  return _show(
    context,
    c,
    t('agb.ph.title'),
    820,
    (ctx, setState) {
      final s = draft.pumpHouse;
      final r = withAgbSettings(c.project, draft, () => designPumpHouse(c.project, c.results));
      void set(void Function() f) => setState(f);
      return _column([
        _hint(t('agb.ph.hint')),
        _switch(t('agb.ph.enabled'), s.enabled, (v) => set(() => s.enabled = v), key: const Key('agb_ph_enabled')),
        fieldGrid([
          NumField(key: const Key('agb_ph_voltage'), label: '${t('agb.rep.voltage')} (V)', value: s.voltage, decimals: 0, onChanged: (v) => set(() => s.voltage = v.clamp(110, 1000).toDouble())),
          SpecDropdown<PowerSupplyKind>(
            key: const Key('agb_ph_supply'),
            label: t('agb.rep.supplyKind'),
            value: s.supply.name,
            items: PowerSupplyKind.values,
            labelOf: (k) => t('agb.supply.${k.name}'),
            idOf: (k) => k.name,
            onChanged: (v) => set(() => s.supply = PowerSupplyKind.values.byName(v ?? s.supply.name)),
          ),
          SpecDropdown<CableInsulation>(
            label: t('agb.ph.insulation'),
            value: s.insulation.name,
            items: CableInsulation.values,
            labelOf: (k) => t('agb.ins.${k.name}'),
            idOf: (k) => k.name,
            onChanged: (v) => set(() => s.insulation = CableInsulation.values.byName(v ?? s.insulation.name)),
          ),
          SpecDropdown<CableMethod>(
            label: t('agb.ph.method'),
            value: s.method.name,
            items: CableMethod.values,
            labelOf: (k) => t('agb.method.${k.name}'),
            idOf: (k) => k.name,
            onChanged: (v) => set(() => s.method = CableMethod.values.byName(v ?? s.method.name)),
          ),
          NumField(label: '${t('agb.ph.ambient')} (°C)', value: s.ambientC ?? (s.method == CableMethod.d ? 20 : 30), decimals: 0, onChanged: (v) => set(() => s.ambientC = v.clamp(0, 80).toDouble())),
          NumField(label: t('agb.ph.grouping'), value: s.groupingFactor, onChanged: (v) => set(() => s.groupingFactor = v.clamp(0.3, 1).toDouble())),
          NumField(
            label: '${t('agb.ph.defaultLength')} (${u.lengthLabel})',
            value: u.lengthFromSi(s.defaultFeederM),
            decimals: 0,
            onChanged: (v) => set(() => s.defaultFeederM = u.lengthToSi(v).clamp(1, 20000).toDouble()),
          ),
          NumField(label: '${t('agb.ph.directMax')} (kW)', value: s.directMaxKw, decimals: 1, onChanged: (v) => set(() => s.directMaxKw = v.clamp(0, 1000).toDouble())),
          NumField(label: t('agb.ph.serviceFactor'), value: s.serviceFactor, onChanged: (v) => set(() => s.serviceFactor = v.clamp(1, 1.5).toDouble())),
          NumField(label: t('agb.ph.softMultiple'), value: s.softStartMultiple, decimals: 1, onChanged: (v) => set(() => s.softStartMultiple = v.clamp(1, 6).toDouble())),
          NumField(label: '${t('agb.ph.maxRunDrop')} (%)', value: s.maxRunningDropPct, decimals: 1, onChanged: (v) => set(() => s.maxRunningDropPct = v.clamp(0, 15).toDouble())),
          NumField(label: '${t('agb.rep.uk')} (%)', value: s.transformerUkPct, decimals: 1, onChanged: (v) => set(() => s.transformerUkPct = v.clamp(0, 15).toDouble())),
          NumField(label: '${t('agb.ph.otherLoads')} (kVA)', value: s.otherLoadsKva, decimals: 1, onChanged: (v) => set(() => s.otherLoadsKva = v.clamp(0, 5000).toDouble())),
          NumField(label: '${t('agb.ph.panelCost')} (${c.project.params.currency})', value: s.panelCost, onChanged: (v) => set(() => s.panelCost = v < 0 ? 0 : v)),
          NumField(label: '${t('agb.ph.transformerCost')} (${c.project.params.currency})', value: s.transformerCost, onChanged: (v) => set(() => s.transformerCost = v < 0 ? 0 : v)),
        ], minWidth: 170),
        _switch(t('agb.ph.includePivots'), s.includePivots, (v) => set(() => s.includePivots = v)),
        if (pumps.isNotEmpty) ...[
          SectionTitle(t('agb.ph.pumps')),
          for (final e in pumps)
            () {
              final f = s.pumps.putIfAbsent(e.id, PumpFeeder.new);
              return fieldGrid([
                _switch('${c.entityName(e.id)} — ${t('agb.ph.electric')}', f.electric, (v) => set(() => f.electric = v), key: Key('agb_ph_electric_${e.id}')),
                NumField(
                  key: Key('agb_ph_len_${e.id}'),
                  label: '${t('agb.rep.length')} (${u.lengthLabel})',
                  value: u.lengthFromSi(f.lengthM ?? s.defaultFeederM),
                  decimals: 0,
                  onChanged: (v) => set(() => f.lengthM = u.lengthToSi(v).clamp(1, 20000).toDouble()),
                ),
                SpecDropdown<StarterKind>(
                  label: t('agb.rep.starter'),
                  value: f.starter.name,
                  items: StarterKind.values,
                  labelOf: (k) => t('agb.starter.${k.name}'),
                  idOf: (k) => k.name,
                  onChanged: (v) => set(() => f.starter = StarterKind.values.byName(v ?? f.starter.name)),
                ),
                NumField(label: '${t('agb.rep.motor')} (kW; 0 = ${t('auto')})', value: f.motorKw, decimals: 1, onChanged: (v) => set(() => f.motorKw = v.clamp(0, 2000).toDouble())),
              ], minWidth: 160);
            }(),
        ],
        SectionTitle(t('dens.results')),
        if (r.circuits.isNotEmpty)
          resultTable(
            [t('agb.rep.pump'), 'kW', 'A', t('agb.rep.starter'), '${t('agb.rep.startCurrent')} (A)', 'mm²', 'PE', 'Iz (A)', '${t('agb.rep.dropRun')} %', '${t('agb.rep.dropStart')} %', 'Ik (kA)'],
            [
              for (final x in r.circuits)
                [
                  x.name,
                  _fx(x.motorKw),
                  _fx(x.currentA),
                  t('agb.starter.${x.starter.name}'),
                  _fx(x.startCurrentA, 0),
                  _fx(x.sectionMm2, x.sectionMm2 < 10 ? 1 : 0),
                  _fx(x.peMm2, x.peMm2 < 10 ? 1 : 0),
                  _fx(x.ampacityA, 0),
                  '${_fx(x.runningDropPct, 2)} / ${_fx(x.runningLimitPct)}',
                  _fx(x.startingDropPct),
                  x.ik3EndKa.isFinite ? _fx(x.ik3EndKa, 2) : '-',
                ],
            ],
            warn: [for (final x in r.circuits) x.warnings.isNotEmpty],
            key: const Key('agb_ph_table'),
          ),
        if (r.circuits.isNotEmpty || r.pivots.isNotEmpty) ...[
          KV(t('agb.rep.demand'), '${_fx(r.demandKw)} kW · ${_fx(r.runningKva)} kVA'),
          KV(t('agb.rep.installed'), '${_fx(r.installedKw)} kW · ${t('agb.rep.tariffGroup')}: ${t('agb.group.${r.tariffGroup}')}'),
          if (s.supply != PowerSupplyKind.lowVoltage)
            KV(t(s.supply == PowerSupplyKind.generator ? 'agb.rep.generator' : 'agb.rep.transformer'), '${_fx(r.sourceKva)} kVA (≥ ${_fx(r.sourceKvaRequired)} kVA)', color: Cad.ok),
          KV(t('agb.rep.ikSource'), r.ik3SourceKa.isFinite ? '${_fx(r.ik3SourceKa, 2)} kA' : '-'),
        ],
        if (r.pivots.isNotEmpty)
          resultTable(
            [
              t('tool.pivot'),
              t('agb.rep.spanCable'),
              'AWG',
              '${t('agb.rep.spanCurrent')} (A)',
              'Iz (A)',
              '${t('agb.rep.ring')} (A)',
              '${t('agb.rep.endTower')} (V)',
              '${t('agb.rep.ownTransformer')} (kVA)',
            ],
            [
              for (final x in r.pivots)
                [
                  x.name,
                  '${_fx(x.spanCableMm2)} mm²${x.spanMinMm2 > x.spanCableMm2 + 1e-9 ? ' → ${_fx(x.spanMinMm2)}' : ''}',
                  x.awg > 0 ? '${x.awg}' : '-',
                  _fx(x.spanCurrentA),
                  _fx(x.spanAmpacityA, 0),
                  _fx(x.collectorRingA, 0),
                  _fx(x.endTowerVolts, 0),
                  _fx(x.transformerKva),
                ],
            ],
            warn: [for (final x in r.pivots) x.warnings.isNotEmpty],
          ),
        if (c.results == null) _hint(t('agb.needResults')),
        _notes(c, r.warnings),
      ]);
    },
    actions: (ctx) => [
      FilledButton(
        key: const Key('agb_ph_apply'),
        onPressed: () {
          draft.pumpHouse.pumps.removeWhere((_, f) => f.isDefault);
          if (applyAgbSettings(c, draft)) c.notify(t('agb.applied'));
          Navigator.pop(ctx);
        },
        child: Text(t('apply')),
      ),
    ],
  );
}

// ---------------------------------------------------------------- solar

/// Solar pumping in the design: an off-grid array for the month of largest
/// need, or a grid-tied array whose energy is compensated on the bill (Lei
/// 14.300/2022), with its energy and cost against the grid.
Future<void> showSolarDesignDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final u = c.units;
  final draft = c.project.agb.clone();
  final cur = c.project.params.currency;
  return _show(
    context,
    c,
    t('agb.solar.title'),
    760,
    (ctx, setState) {
      final s = draft.solar;
      void set(void Function() f) => setState(f);
      final r = withAgbSettings(c.project, draft, () => designSolar(c.project, c.results));
      final grid = s.mode == SolarMode.gridTied;
      return _column([
        _hint(t('agb.solar.hint')),
        fieldGrid([
          SpecDropdown<SolarMode>(
            key: const Key('agb_solar_mode'),
            label: t('agb.rep.solarMode'),
            value: s.mode.name,
            items: SolarMode.values,
            labelOf: (k) => t('agb.solar.${k.name}'),
            idOf: (k) => k.name,
            onChanged: (v) => set(() => s.mode = SolarMode.values.byName(v ?? s.mode.name)),
          ),
          NumField(label: '${t('solar.module')} (Wp)', value: s.moduleWp, decimals: 0, onChanged: (v) => set(() => s.moduleWp = v.clamp(10, 1000).toDouble())),
          NumField(label: '${t('agb.solar.moduleArea')} (m²)', value: s.moduleAreaM2, onChanged: (v) => set(() => s.moduleAreaM2 = v.clamp(0.1, 10).toDouble())),
          NumField(label: '${t('agb.rep.tilt')} (°)', value: s.tiltDeg ?? siteLatitude(c.project).abs(), decimals: 0, onChanged: (v) => set(() => s.tiltDeg = v.clamp(0, 90).toDouble())),
          NumField(label: t('agb.solar.oversize'), value: s.oversize, onChanged: (v) => set(() => s.oversize = v.clamp(0.5, 3).toDouble())),
          NumField(label: t('agb.solar.converter'), value: s.converterEfficiency, onChanged: (v) => set(() => s.converterEfficiency = v.clamp(0.5, 1).toDouble())),
          NumField(label: '${t('agb.solar.efficiency')} (0 = ${t('auto')})', value: s.motorPumpEfficiency, onChanged: (v) => set(() => s.motorPumpEfficiency = v.clamp(0, 1).toDouble())),
          NumField(
            label: '${t('agb.rep.head')} (${u.lengthLabel}; 0 = ${t('auto')})',
            value: u.lengthFromSi(s.headM),
            decimals: 1,
            onChanged: (v) => set(() => s.headM = u.lengthToSi(v).clamp(0, 2000).toDouble()),
          ),
          if (grid) NumField(label: t('agb.solar.dcac'), value: s.dcAcRatio, onChanged: (v) => set(() => s.dcAcRatio = v.clamp(0.8, 2).toDouble())),
          if (grid) NumField(label: t('agb.solar.simultaneity'), value: s.simultaneity, onChanged: (v) => set(() => s.simultaneity = v.clamp(0, 1).toDouble())),
          if (grid) NumField(label: '${t('agb.solar.fioB')} (%)', value: s.fioBSharePct, decimals: 1, onChanged: (v) => set(() => s.fioBSharePct = v.clamp(0, 100).toDouble())),
          if (grid) NumField(label: t('agb.solar.year'), value: s.billingYear.toDouble(), decimals: 0, onChanged: (v) => set(() => s.billingYear = v.round().clamp(2020, 2100))),
          NumField(label: '${t('agb.solar.modulePrice')} ($cur)', value: s.modulePrice, onChanged: (v) => set(() => s.modulePrice = v < 0 ? 0 : v)),
          NumField(label: '${t('agb.solar.inverterPrice')} ($cur/kW)', value: s.inverterPricePerKw, onChanged: (v) => set(() => s.inverterPricePerKw = v < 0 ? 0 : v)),
          NumField(label: '${t('agb.solar.structurePrice')} ($cur)', value: s.structurePricePerModule, onChanged: (v) => set(() => s.structurePricePerModule = v < 0 ? 0 : v)),
        ], minWidth: 170),
        if (grid) _switch(t('agb.solar.grandfathered'), s.grandfathered, (v) => set(() => s.grandfathered = v)),
        if (r != null) ...[
          SectionTitle(t('dens.results')),
          KV(t('agb.rep.array'), '${r.modules} × ${_fx(r.moduleWp, 0)} Wp = ${_fx(r.arrayKWp, 2)} kWp · ${_fx(r.areaM2, 0)} m²', color: Cad.ok),
          KV(t(grid ? 'agb.rep.inverter' : 'agb.rep.pumpDrive'), '${_fx(r.inverterKw)} kW'),
          KV(t('agb.rep.generation'), '${_fx(r.generationKWh, 0)} kWh · ${_fx(r.yieldKWhPerKWp, 0)} kWh/kWp'),
          KV(t('agb.rep.consumption'), '${_fx(r.consumptionKWh, 0)} kWh'),
          if (grid) KV(t('agb.rep.compensated'), '${_fx(r.compensatedKWh, 0)} kWh · Fio B ${_fx(r.fioBPaidPct, 0)} %'),
          KV(t('agb.rep.gridCost'), '$cur ${_fx(r.gridCost, 2)}'),
          KV(t('agb.rep.netCost'), '$cur ${_fx(r.netCost, 2)}', color: Cad.ok),
          resultTable(
            [t('req.month'), t('solar.sunHours'), if (!grid) '${t('solar.volume')} (m³/d)', if (!grid) '${t('solar.pumped')} (m³/d)', '${t('agb.rep.generation')} (kWh)'],
            [
              for (final m in r.months) [t('mon.${m.month}'), _fx(m.peakSunHours, 2), if (!grid) _fx(m.demandM3Day), if (!grid) _fx(m.pumpedM3Day), _fx(m.generationKWh, 0)],
            ],
            warn: [for (final m in r.months) !grid && m.pumpedM3Day + 1e-6 < m.demandM3Day],
            key: const Key('agb_solar_months'),
          ),
          _notes(c, r.warnings),
        ],
        if (c.results == null) _hint(t('agb.needResults')),
      ]);
    },
    actions: (ctx) => [
      FilledButton(
        key: const Key('agb_solar_apply'),
        onPressed: () {
          if (applyAgbSettings(c, draft)) c.notify(t('agb.applied'));
          Navigator.pop(ctx);
        },
        child: Text(t('apply')),
      ),
    ],
  );
}

// ---------------------------------------------------------------- water

/// Water analysis (empty fields = not analysed), the clogging hazard, the
/// filters and the chlorine and acid doses of the water.
Future<void> showWaterQualityDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final draft = c.project.agb.clone();
  final cur = c.project.params.currency;
  return _show(
    context,
    c,
    t('agb.water.title'),
    760,
    (ctx, setState) {
      final w = draft.water;
      void set(void Function() f) => setState(f);
      final r = withAgbSettings(c.project, draft, () => designWaterQuality(c.project, c.results));
      _OptNum opt(String key, String label, double? v, void Function(double?) f, [int d = 2]) =>
          _OptNum(key: Key('agb_water_$key'), label: label, value: v, decimals: d, onChanged: (x) => set(() => f(x)));
      return _column([
        _hint(t('agb.water.hint')),
        SpecDropdown<WaterSource>(
          key: const Key('agb_water_source'),
          label: t('agb.water.source'),
          value: w.source.name,
          items: WaterSource.values,
          labelOf: (k) => t('agb.source.${k.name}'),
          idOf: (k) => k.name,
          onChanged: (v) => set(() => w.source = WaterSource.values.byName(v ?? w.source.name)),
        ),
        fieldGrid([
          opt('ph', t('agb.water.ph'), w.ph, (x) => w.ph = x),
          opt('ec', '${t('agb.water.ec')} (dS/m)', w.ecDsM, (x) => w.ecDsM = x),
          opt('tds', '${t('agb.water.tds')} (mg/L)', w.tdsMgL, (x) => w.tdsMgL = x, 0),
          opt('tss', '${t('agb.water.tss')} (mg/L)', w.tssMgL, (x) => w.tssMgL = x, 0),
          opt('fe', '${t('agb.water.fe')} (mg/L)', w.ironMgL, (x) => w.ironMgL = x),
          opt('mn', '${t('agb.water.mn')} (mg/L)', w.manganeseMgL, (x) => w.manganeseMgL = x),
          opt('h2s', '${t('agb.water.h2s')} (mg/L)', w.sulfideMgL, (x) => w.sulfideMgL = x),
          opt('ca', '${t('agb.water.ca')} (mg/L)', w.calciumMgL, (x) => w.calciumMgL = x, 0),
          opt('hco3', '${t('agb.water.hco3')} (mg/L)', w.bicarbonateMgL, (x) => w.bicarbonateMgL = x, 0),
          opt('bact', '${t('agb.water.bact')} (/mL)', w.bacteriaPerMl, (x) => w.bacteriaPerMl = x, 0),
          NumField(label: '${t('agb.water.temp')} (°C)', value: w.temperatureC, decimals: 0, onChanged: (v) => set(() => w.temperatureC = v.clamp(0, 50).toDouble())),
        ], minWidth: 150),
        SectionTitle(t('agb.water.treatment')),
        fieldGrid([
          NumField(label: '${t('agb.rep.passage')} (mm; 0 = ${t('auto')})', value: w.emitterPassageMm, onChanged: (v) => set(() => w.emitterPassageMm = v.clamp(0, 20).toDouble())),
          NumField(label: t('agb.water.meshRatio'), value: w.meshRatio, decimals: 0, onChanged: (v) => set(() => w.meshRatio = v.clamp(1, 20).toDouble())),
          SpecDropdown<ChlorinationMode>(
            label: t('agb.rep.chlorination'),
            value: w.chlorination.name,
            items: ChlorinationMode.values,
            labelOf: (k) => t('agb.cl.${k.name}'),
            idOf: (k) => k.name,
            onChanged: (v) => set(() => w.chlorination = ChlorinationMode.values.byName(v ?? w.chlorination.name)),
          ),
          NumField(label: '${t('agb.water.residual')} (mg/L)', value: w.chlorineResidualMgL, onChanged: (v) => set(() => w.chlorineResidualMgL = v.clamp(0, 20).toDouble())),
          NumField(label: '${t('agb.water.shock')} (mg/L)', value: w.shockMgL, onChanged: (v) => set(() => w.shockMgL = v.clamp(0, 100).toDouble())),
          NumField(label: '${t('agb.water.shockMinutes')} (min)', value: w.shockMinutes, decimals: 0, onChanged: (v) => set(() => w.shockMinutes = v.clamp(0, 600).toDouble())),
          NumField(label: t('agb.water.shocksPerMonth'), value: w.shocksPerMonth, decimals: 0, onChanged: (v) => set(() => w.shocksPerMonth = v.clamp(0, 31).toDouble())),
          NumField(label: '${t('agb.water.hypochlorite')} (%)', value: w.hypochloritePct, decimals: 1, onChanged: (v) => set(() => w.hypochloritePct = v.clamp(0.5, 20).toDouble())),
          opt('acidph', t('agb.water.acidPh'), w.acidTargetPh, (x) => w.acidTargetPh = x?.clamp(2, 9).toDouble(), 1),
          SpecDropdown<AcidProduct>(
            label: t('agb.rep.acid'),
            value: w.acid.name,
            items: AcidProduct.values,
            labelOf: (k) => t('agb.acid.${k.name}'),
            idOf: (k) => k.name,
            onChanged: (v) => set(() => w.acid = AcidProduct.values.byName(v ?? w.acid.name)),
          ),
          NumField(label: '${t('agb.water.filterCost')} ($cur)', value: w.filterCost, onChanged: (v) => set(() => w.filterCost = v < 0 ? 0 : v)),
          NumField(label: '${t('agb.water.injectorCost')} ($cur)', value: w.injectorCost, onChanged: (v) => set(() => w.injectorCost = v < 0 ? 0 : v)),
        ], minWidth: 170),
        if (r == null) _hint(t('agb.water.noAnalysis')),
        if (r != null) ...[
          SectionTitle(t('dens.results')),
          resultTable(
            [t('agb.rep.parameter'), t('agb.rep.value'), t('agb.rep.risk')],
            [
              for (final h in r.hazards) [t('agb.water.${h.key}'), _fx(h.value, h.key == 'bact' ? 0 : 2), t('agb.risk.${h.risk.name}')],
              if (r.lsi != null) [t('agb.water.lsi'), _fx(r.lsi!, 2), t(r.lsi! > 0 ? 'agb.risk.scaling' : 'agb.risk.low')],
            ],
            warn: [for (final h in r.hazards) h.risk == ClogRisk.severe, if (r.lsi != null) r.lsi! > 0],
            key: const Key('agb_water_hazards'),
          ),
          KV(t('agb.rep.risk'), t('agb.risk.${r.overall.name}'), color: r.overall == ClogRisk.severe ? Cad.warning : Cad.ok),
          KV(t('agb.rep.filterType'), '${t(r.media ? 'agb.filter.media' : (r.discFilter ? 'agb.filter.disc' : 'agb.filter.screen'))} · ${r.mesh} mesh (${_fx(r.openingUm, 0)} µm)'),
          if (r.media && r.mediaTanks > 0) KV(t('agb.rep.mediaTanks'), '${r.mediaTanks} × Ø ${_fx(r.tankDiameterM * 1000, 0)} mm'),
          if (c.project.catalog.valve(r.safetyFilterId) case final f? when r.safetyFilters > 0) KV(t('agb.rep.safetyFilter'), '${r.safetyFilters} × ${f.name}'),
          KV(t('agb.rep.chlorination'), '${t('agb.cl.${r.chlorination.name}')}${r.chlorineDoseMgL > 0 ? ' · ${_fx(r.chlorineDoseMgL, 2)} mg/L · ${_fx(r.hypochloriteLph, 2)} L/h' : ''}'),
          if (r.acidTargetPh != null) KV(t('agb.rep.acid'), 'pH ${_fx(r.acidTargetPh!)} · ${_fx(r.acidMlM3)} mL/m³ · ${_fx(r.acidLph, 2)} L/h'),
          _notes(c, r.warnings),
        ],
        if (c.results == null) _hint(t('agb.needResults')),
      ]);
    },
    actions: (ctx) => [
      FilledButton(
        key: const Key('agb_water_apply'),
        onPressed: () {
          if (applyAgbSettings(c, draft)) c.notify(t('agb.applied'));
          Navigator.pop(ctx);
        },
        child: Text(t('apply')),
      ),
    ],
  );
}

// ---------------------------------------------------------------- two-wire

/// Two-wire (decoder) wiring in the design: the path of every controller
/// along the wire routes, the decoders and the surge protection, and their
/// place in the bill of materials instead of the station wires.
Future<void> showTwoWireDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final u = c.units;
  final draft = c.project.agb.clone();
  final cur = c.project.params.currency;
  return _show(
    context,
    c,
    t('agb.tw.title'),
    700,
    (ctx, setState) {
      final s = draft.twoWire;
      void set(void Function() f) => setState(f);
      final r = designTwoWire(c.project, flows: wiringFlows(c.project), spec: twoWireSpecOf(s));
      final caps = <int, int>{};
      for (final d in r?.decoders ?? const <TwoWireDecoder>[]) {
        caps[d.capacity] = (caps[d.capacity] ?? 0) + 1;
      }
      return _column([
        _hint(t('agb.tw.hint')),
        _switch(t('agb.tw.enabled'), s.enabled, (v) => set(() => s.enabled = v), key: const Key('agb_tw_enabled')),
        fieldGrid([
          NumField(label: t('tw.volts'), value: s.outputVolts, decimals: 1, onChanged: (v) => set(() => s.outputVolts = v.clamp(1, 100).toDouble())),
          NumField(label: t('tw.minVolts'), value: s.minVolts, decimals: 1, onChanged: (v) => set(() => s.minVolts = v.clamp(1, 100).toDouble())),
          NumField(label: t('tw.idle'), value: s.decoderIdleMa, onChanged: (v) => set(() => s.decoderIdleMa = v.clamp(0, 100).toDouble())),
          NumField(
            label: '${t('tw.solenoidReach')} (${u.lengthLabel})',
            value: u.lengthFromSi(s.solenoidReachM),
            decimals: 0,
            onChanged: (v) => set(() => s.solenoidReachM = u.lengthToSi(v).clamp(0, 1000).toDouble()),
          ),
          NumField(label: t('tw.groundDecoders'), value: s.groundEveryDecoders.toDouble(), decimals: 0, onChanged: (v) => set(() => s.groundEveryDecoders = v.round().clamp(0, 999))),
          NumField(
            label: '${t('tw.groundEvery')} (${u.lengthLabel})',
            value: u.lengthFromSi(s.groundEveryM),
            decimals: 0,
            onChanged: (v) => set(() => s.groundEveryM = u.lengthToSi(v).clamp(0, 10000).toDouble()),
          ),
          for (final k in const [1, 2, 4, 6]) NumField(label: '${t('agb.bom.decoder')} $k ($cur)', value: s.decoderPrices[k] ?? 0, onChanged: (v) => set(() => s.decoderPrices[k] = v < 0 ? 0 : v)),
          NumField(label: '${t('agb.bom.arrester')} ($cur)', value: s.arresterPrice, onChanged: (v) => set(() => s.arresterPrice = v < 0 ? 0 : v)),
        ], minWidth: 160),
        if (r == null) _hint(t('agb.tw.noRoutes')),
        if (r != null) ...[
          SectionTitle(t('dens.results')),
          for (final path in r.paths.where((x) => x.used > 0))
            KV(
              c.entityName(path.controllerId),
              '${path.wireId == null ? '-' : (c.project.catalog.wire(path.wireId)?.name ?? path.wireId!)} · ${_fx(u.lengthFromSi(path.cableM), 0)} ${u.lengthLabel} · ${_fx(path.worstVolts)} V',
            ),
          KV(t('tw.decoders'), caps.isEmpty ? '0' : (caps.keys.toList()..sort()).map((k) => '${caps[k]} × $k').join(' · ')),
          KV(t('tw.grounds'), '${r.grounds.length}'),
          _notes(c, r.warnings),
        ],
      ]);
    },
    actions: (ctx) => [
      FilledButton(
        key: const Key('agb_tw_apply'),
        onPressed: () {
          if (applyAgbSettings(c, draft)) c.notify(t('agb.applied'));
          Navigator.pop(ctx);
        },
        child: Text(t('apply')),
      ),
    ],
  );
}
