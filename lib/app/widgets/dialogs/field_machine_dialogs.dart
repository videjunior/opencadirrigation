/// Dialogs of the field machines of 1.6.0: several centre pivots arranged
/// in a property with their common mainline, travelling-gun lanes laid
/// across a field (or one lane edited), and a furrow set fed from a head
/// line (or one set edited). Each shows the analysis as the fields change;
/// Apply draws the result as one undo step.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/field_machines.dart';
import '../../../core/design/mechanised.dart' show closedOutlineOf;
import '../../../core/design/multi_pivot.dart';
import '../../../core/design/traveller.dart' show WindClass;
import '../../../core/model/catalog.dart';
import '../../../core/model/entities.dart';
import '../../../core/model/geometry.dart';
import '../../../core/model/project.dart';
import '../../state/controller.dart';
import '../../theme.dart';
import '../fields.dart';
import 'mechanised_dialogs.dart' show fieldGrid, resultTable;
import 'terrain_dialogs.dart' show dialogWidth;

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

String _fx(double v, [int d = 1]) => fmtUi(v, d);

/// The closed shapes of the selection (id and outline), in selection order.
List<(String, List<Pt>)> _selectedShapes(ProjectController c) => [
  for (final id in c.selection)
    if (c.project.byId(id) is! PivotEntity)
      if (closedOutlineOf(c.project, id) case final pts?) (id, pts),
];

// ---------------------------------------------------------------- several pivots

/// Several centre pivots in the selected field (the first closed shape of
/// the selection; the other closed shapes and the machines already drawn
/// are obstacles): the arrangement that irrigates the most, the flow of
/// each machine and the common mainline from the water supply.
Future<void> showMultiPivotDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final u = c.units;
  final shapes = _selectedShapes(c);
  if (shapes.isEmpty) return _show(context, c, t('agb.mp.title'), 460, (ctx, _) => _column([_hint(t('agb.mp.needField'))]));
  final field = shapes.first.$2;
  final obstacles = [
    for (final s in shapes.skip(1)) s.$2,
    for (final p in c.project.entities.whereType<PivotEntity>()) p.outline(),
  ];
  final supply = c.project.entities.whereType<WaterSupplyEntity>().firstOrNull?.position;
  var endThrow = 5.0, clearance = 5.0, minRadius = 100.0, maxFlowM3h = 0.0, depth = 8.0, hours = 21.0;
  var maxPivots = 12, minSpans = 2, maxSpans = 12;
  var corners = false, mainline = true;
  MultiPivotLayout? layout;
  MultiPivotOptions options() => MultiPivotOptions(
    obstacles: obstacles,
    endThrowM: endThrow,
    clearanceM: clearance,
    minRadiusM: minRadius,
    maxTotalFlow: maxFlowM3h / 3600,
    grossDepthMm: depth,
    hoursPerCycle: hours,
    maxPivots: maxPivots,
    minSpans: minSpans,
    maxSpans: math.max(minSpans, maxSpans),
    corners: corners,
    supply: supply,
  );
  return _show(
    context,
    c,
    t('agb.mp.title'),
    720,
    (ctx, setState) {
      void set(void Function() f) => setState(() {
        f();
        layout = null;
      });
      final l = layout;
      return _column([
        _hint(t('agb.mp.hint')),
        fieldGrid([
          NumField(label: '${t('agb.mp.endThrow')} (${u.lengthLabel})', value: u.lengthFromSi(endThrow), decimals: 1, onChanged: (v) => set(() => endThrow = u.lengthToSi(v).clamp(0, 100).toDouble())),
          NumField(
            label: '${t('agb.mp.clearance')} (${u.lengthLabel})',
            value: u.lengthFromSi(clearance),
            decimals: 1,
            onChanged: (v) => set(() => clearance = u.lengthToSi(v).clamp(0, 500).toDouble()),
          ),
          NumField(
            label: '${t('agb.mp.minRadius')} (${u.lengthLabel})',
            value: u.lengthFromSi(minRadius),
            decimals: 0,
            onChanged: (v) => set(() => minRadius = u.lengthToSi(v).clamp(20, 2000).toDouble()),
          ),
          NumField(label: t('agb.mp.maxPivots'), value: maxPivots.toDouble(), decimals: 0, onChanged: (v) => set(() => maxPivots = v.round().clamp(1, 60))),
          NumField(label: t('agb.mp.minSpans'), value: minSpans.toDouble(), decimals: 0, onChanged: (v) => set(() => minSpans = v.round().clamp(1, 30))),
          NumField(label: t('agb.mp.maxSpans'), value: maxSpans.toDouble(), decimals: 0, onChanged: (v) => set(() => maxSpans = v.round().clamp(1, 30))),
          NumField(label: '${t('agb.mp.maxFlow')} (m³/h; 0 = ${t('agb.mp.noLimit')})', value: maxFlowM3h, decimals: 0, onChanged: (v) => set(() => maxFlowM3h = v.clamp(0, 1e6).toDouble())),
          NumField(label: '${t('agb.mp.depth')} (mm)', value: depth, decimals: 1, onChanged: (v) => set(() => depth = v.clamp(0.5, 100).toDouble())),
          NumField(label: '${t('agb.mp.hours')} (h)', value: hours, decimals: 0, onChanged: (v) => set(() => hours = v.clamp(1, 240).toDouble())),
        ], minWidth: 170),
        _switch(t('agb.mp.corners'), corners, (v) => set(() => corners = v), key: const Key('agb_mp_corners')),
        _switch(t('agb.mp.mainline'), mainline, (v) => setState(() => mainline = v), key: const Key('agb_mp_mainline')),
        if (supply == null) _hint(t('agb.mp.noSupply')),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: FilledButton.icon(
            key: const Key('agb_mp_run'),
            onPressed: () => setState(() => layout = layoutPivots(field, options())),
            icon: const Icon(Icons.radar, size: 16),
            label: Text(t('agb.mp.run')),
          ),
        ),
        if (l != null) ...[
          KV(t('agb.mp.result'), '${l.pivots.length} · ${_fx(l.irrigatedAreaM2 / 1e4, 1)} ha (${_fx(l.coverage * 100, 0)} %)', color: Cad.ok),
          KV(t('agb.mp.totalFlow'), '${_fx(l.totalFlow * 3600, 0)} m³/h'),
          if (mainline && l.mainline.isNotEmpty) KV(t('agb.mp.mainlineLength'), '${_fx(u.lengthFromSi(l.mainlineLengthM), 0)} ${u.lengthLabel}'),
          resultTable(
            ['#', '${t('agb.mp.radius')} (${u.lengthLabel})', t('pivot.towers'), '${t('agb.mp.area')} (ha)', 'm³/h'],
            [
              for (var i = 0; i < l.pivots.length; i++)
                ['${i + 1}', _fx(u.lengthFromSi(l.pivots[i].irrigatedRadius), 0), '${l.pivots[i].spans.count}', _fx(l.pivots[i].areaM2 / 1e4, 1), _fx(l.pivots[i].flow * 3600, 0)],
            ],
            key: const Key('agb_mp_table'),
          ),
          _notes(c, l.messages),
        ],
      ]);
    },
    actions: (ctx) => [
      FilledButton(
        key: const Key('agb_mp_apply'),
        onPressed: () {
          final l = layout ?? layoutPivots(field, options());
          if (l.pivots.isEmpty) {
            Navigator.pop(ctx);
            c.notify(t('warn.mpivot_none'));
            return;
          }
          final n = c.mutate(() {
            final p = c.project;
            final first = p.entities.whereType<PivotEntity>().length;
            for (var i = 0; i < l.pivots.length; i++) {
              p.entities.add(l.pivots[i].toEntity(p, name: '${t('tool.pivot')} ${first + i + 1}', grossDepthMm: depth, hoursPerCycle: hours));
            }
            if (mainline) {
              for (final (a, b) in l.mainline) {
                p.entities.add(PipeEntity(id: p.newId(), points: [a, b], scope: HydraulicScope.mainline));
              }
            }
            return l.pivots.length;
          }, label: 'hist.multiPivot');
          Navigator.pop(ctx);
          if (n != null) c.notify(t('agb.mp.applied', {'n': '$n'}));
        },
        child: Text(t('apply')),
      ),
    ],
  );
}

// ---------------------------------------------------------------- traveller lanes

/// The gun, hose and lane data of [e] as fields; [set] wraps a change.
List<Widget> _travellerFields(ProjectController c, TravellerEntity e, void Function(void Function()) set) {
  final t = c.t;
  final u = c.units;
  final cur = c.project.params.currency;
  final guns = c.project.catalog.outlets.where((o) => o.enabled && o.kind == OutletKind.gun).toList();
  final gun = c.project.catalog.outlet(e.gunSpecId);
  return [
    SpecDropdown<OutletSpec>(
      key: const Key('agb_trav_gun'),
      label: t('agb.trav.gun'),
      value: e.gunSpecId,
      items: guns,
      allowNull: true,
      nullLabel: t('agb.trav.typed'),
      labelOf: (o) => o.name,
      idOf: (o) => o.id,
      onChanged: (v) => set(() {
        e.gunSpecId = v;
        e.gunNozzleId = c.project.catalog.outlet(v)?.nozzles.firstOrNull?.id;
      }),
    ),
    if (gun != null)
      SpecDropdown<NozzleSpec>(label: t('agb.trav.nozzle'), value: e.gunNozzleId, items: gun.nozzles, labelOf: (n) => n.name, idOf: (n) => n.id, onChanged: (v) => set(() => e.gunNozzleId = v)),
    if (gun == null)
      NumField(
        label: '${t('rep.flow')} (${u.flowLabel})',
        value: u.flowFromSi(e.gunFlow),
        decimals: 2,
        onChanged: (v) => set(() => e.gunFlow = u.flowToSi(v).clamp(1e-5, 1).toDouble()),
      ),
    if (gun == null)
      NumField(
        label: '${t('agb.trav.wettedDiameter')} (${u.lengthLabel})',
        value: u.lengthFromSi(e.wettedDiameterM),
        decimals: 0,
        onChanged: (v) => set(() => e.wettedDiameterM = u.lengthToSi(v).clamp(5, 300).toDouble()),
      ),
    NumField(
      label: '${t('agb.trav.gunPressure')} (${u.pressureLabel})',
      value: u.pressureFromHead(e.gunPressureM),
      decimals: 1,
      onChanged: (v) => set(() => e.gunPressureM = u.pressureToHead(v).clamp(5, 150).toDouble()),
    ),
    NumField(label: '${t('agb.trav.sector')} (°)', value: e.sectorDeg, decimals: 0, onChanged: (v) => set(() => e.sectorDeg = v.clamp(30, 360).toDouble())),
    NumField(
      label: '${t('agb.trav.hose')} (${u.lengthLabel}; 0 = ${t('auto')})',
      value: u.lengthFromSi(e.hoseLengthM),
      decimals: 0,
      onChanged: (v) => set(() => e.hoseLengthM = u.lengthToSi(v).clamp(0, 2000).toDouble()),
    ),
    NumField(label: '${t('agb.trav.hoseBore')} (mm)', value: e.hoseInnerMm, decimals: 0, onChanged: (v) => set(() => e.hoseInnerMm = v.clamp(20, 200).toDouble())),
    NumField(
      label: '${t('agb.trav.driveLoss')} (${u.pressureLabel})',
      value: u.pressureFromHead(e.driveLossM),
      decimals: 1,
      onChanged: (v) => set(() => e.driveLossM = u.pressureToHead(v).clamp(0, 50).toDouble()),
    ),
    NumField(
      label: '${t('agb.trav.laneWidth')} (${u.lengthLabel}; 0 = ${t('auto')})',
      value: u.lengthFromSi(e.laneWidthM),
      decimals: 1,
      onChanged: (v) => set(() => e.laneWidthM = u.lengthToSi(v).clamp(0, 300).toDouble()),
    ),
    NumField(label: '${t('agb.rep.depth')} (mm)', value: e.targetDepthMm, decimals: 1, onChanged: (v) => set(() => e.targetDepthMm = v.clamp(1, 200).toDouble())),
    SpecDropdown<WindClass>(
      label: t('agb.trav.wind'),
      value: e.wind.name,
      items: WindClass.values,
      labelOf: (w) => t('agb.wind.${w.name}'),
      idOf: (w) => w.name,
      onChanged: (v) => set(() => e.wind = WindClass.values.byName(v ?? e.wind.name)),
    ),
    NumField(label: '${t('agb.trav.setup')} (h)', value: e.setupHours, decimals: 2, onChanged: (v) => set(() => e.setupHours = v.clamp(0, 24).toDouble())),
    NumField(label: '${t('agb.trav.hoursPerDay')} (h)', value: e.hoursPerDay, decimals: 0, onChanged: (v) => set(() => e.hoursPerDay = v.clamp(1, 24).toDouble())),
    TextFieldRow(label: t('agb.rep.machine'), value: e.machine, onChanged: (v) => set(() => e.machine = v.trim().isEmpty ? 'A' : v.trim())),
    NumField(label: '${t('agb.trav.machineCost')} ($cur)', value: e.machineCost, onChanged: (v) => set(() => e.machineCost = v < 0 ? 0 : v)),
    NumField(label: '${t('agb.trav.hydrantCost')} ($cur)', value: e.hydrantCost, onChanged: (v) => set(() => e.hydrantCost = v < 0 ? 0 : v)),
  ];
}

/// The analysis of lanes [lanes] as a table.
Widget _laneTable(ProjectController c, List<TravellerLaneResult> lanes) {
  final t = c.t;
  final u = c.units;
  return resultTable(
    [
      t('agb.rep.lane'),
      '${t('agb.rep.length')} (${u.lengthLabel})',
      '${t('agb.rep.laneWidth')} (${u.lengthLabel})',
      '${t('rep.flow')} (${u.flowLabel})',
      'm/min',
      'mm',
      '${t('agb.rep.laneTime')} (h)',
      '${t('rep.pRequired')} (${u.pressureLabel})',
    ],
    [
      for (final l in lanes)
        [
          l.name,
          _fx(u.lengthFromSi(l.result.laneLengthM), 0),
          _fx(u.lengthFromSi(l.result.laneSpacingM)),
          _fx(u.flowFromSi(l.flow), 2),
          _fx(l.result.speedMPerMin, 2),
          _fx(l.result.grossDepthMm),
          _fx(l.result.laneHours),
          _fx(u.pressureFromHead(l.requiredHead)),
        ],
    ],
    warn: [for (final l in lanes) l.result.warnings.isNotEmpty],
    key: const Key('agb_trav_table'),
  );
}

/// Travelling-gun lanes: with a lane selected, its data; with a closed
/// shape selected, lanes laid across it (hydrants on its edge, a mainline
/// along them and a system flow per lane when asked).
Future<void> showTravellerLanesDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final selected = [for (final id in c.selection) c.project.byId(id)].whereType<TravellerEntity>().firstOrNull;
  if (selected != null) {
    final draft = selected.clone();
    return _show(
      context,
      c,
      t('agb.trav.title'),
      720,
      (ctx, setState) {
        void set(void Function() f) => setState(f);
        final r = analyzeTravellerLane(c.project, draft, terrain: c.project.buildTerrain());
        return _column([
          _hint(t('agb.trav.editHint')),
          fieldGrid(_travellerFields(c, draft, set), minWidth: 170),
          _laneTable(c, [r]),
          _notes(c, r.result.warnings),
        ]);
      },
      actions: (ctx) => [
        FilledButton(
          key: const Key('agb_trav_apply'),
          onPressed: () {
            c.mutate(() {
              final i = c.project.entities.indexWhere((x) => x.id == selected.id);
              if (i >= 0) c.project.entities[i] = draft;
            }, label: 'hist.travellerLanes');
            Navigator.pop(ctx);
          },
          child: Text(t('apply')),
        ),
      ],
    );
  }
  final shapes = _selectedShapes(c);
  if (shapes.isEmpty) return _show(context, c, t('agb.trav.title'), 460, (ctx, _) => _column([_hint(t('agb.trav.needField'))]));
  final field = shapes.first.$2;
  // lanes across the longest edge of the field by default
  var longest = 0.0, angle = 0.0;
  for (var i = 0; i < field.length; i++) {
    final d = field[(i + 1) % field.length] - field[i];
    if (d.length > longest) {
      longest = d.length;
      angle = radToDeg(d.angle) + 90;
    }
  }
  final template = TravellerEntity(id: '', start: Pt.zero, end: const Pt(100, 0));
  var hydrantLine = true, flows = true;
  var seq = 0;
  List<TravellerEntity> lanes() => layoutTravellerLanes(c.project, field, template, angleDeg: angle, newId: () => 'tmp${seq++}', name: (i) => '${t('agb.rep.lane')} ${i + 1}');
  return _show(
    context,
    c,
    t('agb.trav.title'),
    760,
    (ctx, setState) {
      void set(void Function() f) => setState(f);
      final ls = lanes();
      final terrain = c.project.buildTerrain();
      final rs = [for (final l in ls) analyzeTravellerLane(c.project, l, terrain: terrain)];
      return _column([
        _hint(t('agb.trav.hint')),
        fieldGrid([
          NumField(key: const Key('agb_trav_angle'), label: '${t('agb.trav.angle')} (°)', value: angle, decimals: 0, onChanged: (v) => set(() => angle = v)),
          ..._travellerFields(c, template, set),
        ], minWidth: 170),
        _switch(t('agb.trav.hydrantLine'), hydrantLine, (v) => set(() => hydrantLine = v)),
        _switch(t('agb.trav.flows'), flows, (v) => set(() => flows = v)),
        KV(t('agb.trav.lanes'), '${ls.length}', color: ls.isEmpty ? Cad.warning : Cad.ok),
        if (rs.isNotEmpty) _laneTable(c, rs),
        _notes(c, [for (final r in rs) ...r.result.warnings]),
      ]);
    },
    actions: (ctx) => [
      FilledButton(
        key: const Key('agb_trav_apply'),
        onPressed: () {
          final n = c.mutate(() {
            final p = c.project;
            final made = layoutTravellerLanes(p, field, template, angleDeg: angle, newId: p.newId, name: (i) => '${t('agb.rep.lane')} ${i + 1}');
            p.layerNamed(Layers.travellers);
            p.entities.addAll(made);
            if (hydrantLine && made.length > 1) {
              final pts = [for (final l in made) l.start];
              p.entities.add(PipeEntity(id: p.newId(), points: pts, scope: HydraulicScope.mainline));
            }
            if (flows && made.isNotEmpty) agbAddFlows(p, made, t('name.allZones'));
            return made.length;
          }, label: 'hist.travellerLanes');
          Navigator.pop(ctx);
          if (n != null) c.notify(t('agb.trav.applied', {'n': '$n'}));
        },
        child: Text(t('apply')),
      ),
    ],
  );
}

/// One system flow per item of [items] (a machine position or a set): the
/// zones and pivots that ran in the automatic flow keep a flow of their own
/// when the project had none.
void agbAddFlows(Project p, List<Entity> items, String allZonesName) {
  if (p.systemFlows.isEmpty) {
    final rest = {
      for (final e in p.entities)
        if ((e is ControlValveEntity || e is PivotEntity) && !items.contains(e)) e.id,
    };
    if (rest.isNotEmpty) p.systemFlows.add(SystemFlow(id: 'sf${p.nextIdValue}', name: allZonesName, valveIds: rest, durationHours: 1));
  }
  for (final e in items) {
    final id = 'sf_${e.id}';
    if (p.systemFlows.any((f) => f.id == id)) continue;
    p.systemFlows.add(SystemFlow(id: id, name: e.name.isNotEmpty ? e.name : e.id, valveIds: {e.id}, durationHours: 1));
  }
}

// ---------------------------------------------------------------- furrow sets

/// A furrow set: with a set selected, its data; with a line or polyline
/// selected, a set fed from it (its first point is the inlet).
Future<void> showFurrowSetDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final u = c.units;
  final cur = c.project.params.currency;
  final sel = [for (final id in c.selection) c.project.byId(id)].whereType<Entity>().toList();
  final existing = sel.whereType<FurrowEntity>().firstOrNull;
  final line = existing != null ? null : sel.map((e) => e.linearPoints).whereType<List<Pt>>().where((pts) => pts.length >= 2).firstOrNull;
  if (existing == null && line == null) return _show(context, c, t('agb.furrow.title'), 460, (ctx, _) => _column([_hint(t('agb.furrow.needLine'))]));
  final draft = existing?.clone() ?? FurrowEntity(id: '', points: List.of(line!), name: '${t('agb.rep.furrowSet')} ${c.project.entities.whereType<FurrowEntity>().length + 1}');
  var flow = existing == null;
  return _show(
    context,
    c,
    t('agb.furrow.title'),
    720,
    (ctx, setState) {
      void set(void Function() f) => setState(f);
      final r = analyzeFurrowSet(c.project, draft, terrain: c.project.buildTerrain());
      return _column([
        _hint(t('agb.furrow.hint')),
        fieldGrid([
          SpecDropdown<bool>(
            key: const Key('agb_furrow_side'),
            label: t('agb.furrow.side'),
            value: '${draft.leftSide}',
            items: const [true, false],
            labelOf: (b) => t(b ? 'agb.furrow.left' : 'agb.furrow.right'),
            idOf: (b) => '$b',
            onChanged: (v) => set(() => draft.leftSide = v == 'true'),
          ),
          NumField(
            label: '${t('agb.furrow.length')} (${u.lengthLabel})',
            value: u.lengthFromSi(draft.furrowLengthM),
            decimals: 0,
            onChanged: (v) => set(() => draft.furrowLengthM = u.lengthToSi(v).clamp(10, 2000).toDouble()),
          ),
          NumField(
            label: '${t('agb.furrow.spacing')} (${u.lengthLabel})',
            value: u.lengthFromSi(draft.furrowSpacingM),
            decimals: 2,
            onChanged: (v) => set(() => draft.furrowSpacingM = u.lengthToSi(v).clamp(0.2, 5).toDouble()),
          ),
          NumField(label: '${t('agb.furrow.slope')} (m/m)', value: draft.slope, decimals: 4, onChanged: (v) => set(() => draft.slope = v.clamp(0, 0.05).toDouble())),
          NumField(label: '${t('agb.furrow.family')} (in/h)', value: draft.intakeFamily, decimals: 2, onChanged: (v) => set(() => draft.intakeFamily = v.clamp(0.05, 4).toDouble())),
          NumField(label: t('agb.furrow.manning'), value: draft.manningN, decimals: 3, onChanged: (v) => set(() => draft.manningN = v.clamp(0.01, 0.2).toDouble())),
          NumField(label: '${t('agb.rep.depth')} (mm)', value: draft.requiredDepthMm, decimals: 0, onChanged: (v) => set(() => draft.requiredDepthMm = v.clamp(5, 300).toDouble())),
          NumField(label: '${t('agb.rep.inflow')} (L/s; 0 = ${t('auto')})', value: draft.inflowLps, decimals: 2, onChanged: (v) => set(() => draft.inflowLps = v.clamp(0, 20).toDouble())),
          NumField(
            label: '${t('agb.rep.perSet')} (0 = ${t('agb.furrow.all')})',
            value: draft.furrowsPerSet.toDouble(),
            decimals: 0,
            onChanged: (v) => set(() => draft.furrowsPerSet = v.round().clamp(0, 100000)),
          ),
          NumField(label: '${t('agb.furrow.pipeBore')} (mm)', value: draft.pipeInnerMm, decimals: 0, onChanged: (v) => set(() => draft.pipeInnerMm = v.clamp(50, 500).toDouble())),
          NumField(label: '${t('agb.furrow.pipeCost')} ($cur/m)', value: draft.pipeCostPerM, onChanged: (v) => set(() => draft.pipeCostPerM = v < 0 ? 0 : v)),
          NumField(label: '${t('agb.furrow.gateCost')} ($cur)', value: draft.gateCost, onChanged: (v) => set(() => draft.gateCost = v < 0 ? 0 : v)),
        ], minWidth: 170),
        _switch(t('agb.furrow.gated'), draft.gatedPipe, (v) => set(() => draft.gatedPipe = v)),
        if (existing == null) _switch(t('agb.furrow.flow'), flow, (v) => set(() => flow = v)),
        SectionTitle(t('dens.results')),
        KV(t('agb.rep.furrowCount'), '${r.furrows} · ${r.perSet} × ${r.sets} ${t('agb.furrow.sets')}'),
        KV(t('agb.rep.inflow'), '${_fx(r.inflow * 1000, 2)} L/s · ${_fx(u.flowFromSi(r.setFlow), 2)} ${u.flowLabel}', color: Cad.ok),
        KV(t('agb.rep.cutoff'), '${_fx(r.cutoffS / 60, 0)} min · ${t('agb.rep.irrigation')} ${_fx(r.irrigationHours)} h'),
        KV('Ea · DU', '${_fx(r.efficiency * 100, 0)} % · ${_fx(r.lowQuarterDu * 100, 0)} %'),
        KV(t('rep.pRequired'), '${_fx(u.pressureFromHead(r.inletHeadM), 2)} ${u.pressureLabel}'),
        _notes(c, r.warnings),
      ]);
    },
    actions: (ctx) => [
      FilledButton(
        key: const Key('agb_furrow_apply'),
        onPressed: () {
          c.mutate(() {
            final p = c.project;
            if (existing != null) {
              final i = p.entities.indexWhere((x) => x.id == existing.id);
              if (i >= 0) p.entities[i] = draft;
              return;
            }
            final e = draft.clone(newId: p.newId());
            p.layerNamed(Layers.surface);
            p.entities.add(e);
            if (flow) agbAddFlows(p, [e], t('name.allZones'));
          }, label: 'hist.furrowSet');
          Navigator.pop(ctx);
        },
        child: Text(t('apply')),
      ),
    ],
  );
}
