/// Dialogs added with the CAD-editing / persistence / engine-UI work:
/// array, pump selection, 3D terrain, recovery, versions,
/// image georeferencing and the catalog editor.
library;

import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/design/pump_selection.dart';
import '../../../core/hydraulics/emitter.dart';
import '../../../core/hydraulics/minor_losses.dart';
import '../../../core/io/catalog_io.dart';
import '../../../core/model/catalog.dart';
import '../../../core/model/entities.dart';
import '../../../core/model/geometry.dart';
import '../../../core/units.dart';
import '../../io/file_io.dart';
import '../../io/project_store.dart';
import '../../state/controller.dart';
import '../../state/workspace.dart';
import '../dem_view.dart';
import '../fields.dart';
import 'catalog_packs_dialog.dart';

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

Widget _row(List<Widget> children) => Row(children: [for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(width: 8), Expanded(child: children[i])]]);

String _when(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

// ---------------------------------------------------------------- array

Future<void> showArrayDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final u = c.units;
  if (c.selection.isEmpty) {
    c.notify(t('msg.nothingSelected'));
    return Future.value();
  }
  var b = Bounds.empty;
  for (final e in c.project.entities.where((e) => c.selection.contains(e.id))) {
    b = b.union(e.bounds);
  }
  final o = ArrayOptions(center: b.isEmpty ? Pt.zero : b.center, dx: b.isEmpty ? 5 : b.width + 2, dy: b.isEmpty ? 5 : b.height + 2);
  return _show(context, c, t('arr.title'), StatefulBuilder(builder: (ctx, setState) {
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t('arr.selection', {'n': '${c.selection.length}'}), style: const TextStyle(fontSize: 11.5, color: Colors.white54)),
      SegmentedButton<bool>(segments: [ButtonSegment(value: false, label: Text(t('arr.rect'))), ButtonSegment(value: true, label: Text(t('arr.polar')))], selected: {o.polar}, onSelectionChanged: (v) => setState(() => o.polar = v.first)),
      if (!o.polar) ...[
        _row([
          NumField(label: t('arr.rows'), value: o.rows.toDouble(), decimals: 0, onChanged: (v) => o.rows = v.round().clamp(1, 500)),
          NumField(label: t('arr.cols'), value: o.cols.toDouble(), decimals: 0, onChanged: (v) => o.cols = v.round().clamp(1, 500)),
        ]),
        _row([
          NumField(label: '${t('arr.dx')} (${u.lengthLabel})', value: u.lengthFromSi(o.dx), onChanged: (v) => o.dx = u.lengthToSi(v)),
          NumField(label: '${t('arr.dy')} (${u.lengthLabel})', value: u.lengthFromSi(o.dy), onChanged: (v) => o.dy = u.lengthToSi(v)),
        ]),
        NumField(label: t('arr.angle'), value: o.angleDeg, onChanged: (v) => o.angleDeg = v),
      ] else ...[
        _row([
          NumField(label: t('arr.count'), value: o.count.toDouble(), decimals: 0, onChanged: (v) => o.count = v.round().clamp(2, 720)),
          NumField(label: t('arr.total'), value: o.totalAngleDeg, onChanged: (v) => o.totalAngleDeg = v),
        ]),
        _row([
          NumField(label: '${t('arr.center')} X', value: u.lengthFromSi(o.center.x), onChanged: (v) => o.center = Pt(u.lengthToSi(v), o.center.y)),
          NumField(label: '${t('arr.center')} Y', value: u.lengthFromSi(o.center.y), onChanged: (v) => o.center = Pt(o.center.x, u.lengthToSi(v))),
        ]),
        SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(t('arr.rotateItems'), style: const TextStyle(fontSize: 12)), value: o.rotateItems, onChanged: (v) => setState(() => o.rotateItems = v)),
      ],
    ]);
  }), actions: [
    TextButton(onPressed: () => Navigator.pop(context), child: Text(t('cancel'))),
    FilledButton(key: const Key('array_ok'), onPressed: () {
      final n = c.arraySelected(o);
      c.notify(t('msg.arrayDone', {'n': '$n'}));
      Navigator.pop(context);
    }, child: Text(t('ok'))),
  ], width: 440);
}

// ---------------------------------------------------------------- pump selection

Future<void> showPumpSelectionDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final u = c.units;
  final r = c.results;
  final cat = c.project.catalog;
  final p = c.project.params;
  final supplies = c.project.entities.whereType<WaterSupplyEntity>().toList();
  if (r == null || supplies.isEmpty) return _show(context, c, t('pump.title'), Text(t('pump.noSupply')));
  var supplyId = supplies.first.id;
  return _show(context, c, t('pump.title'), StatefulBuilder(builder: (ctx, setState) {
    final s = supplies.firstWhere((x) => x.id == supplyId);
    final pd = worstPumpDuty(r, s.id);
    final duty = pd?.supply;
    if (pd == null || duty == null) return Text(t('pump.noSupply'));
    final dutyHead = pd.head;
    final stat = staticLift(c.project, r, s, duty);
    final others = [for (final d in pumpDuties(r, s.id)) if (d.flowName != pd.flowName) (d.supply.flow, d.head)];
    final cands = rankPumps(cat, flow: duty.flow, head: dutyHead, staticHead: stat, hoursPerYear: p.hoursPerYear, costPerKwh: p.powerCostPerKwh, otherDuties: others, requireSubmersible: suctionLiftTooDeep(s, duty));
    final existing = c.project.entities.whereType<PumpEntity>().toList();
    return SizedBox(
      height: 420,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (supplies.length > 1) SpecDropdown<WaterSupplyEntity>(label: t('pump.supply'), value: supplyId, items: supplies, labelOf: (x) => x.name, idOf: (x) => x.id, onChanged: (v) => setState(() => supplyId = v ?? supplyId)),
        Text(t('pump.duty', {'q': '${fmt(u.flowFromSi(duty.flow), 1)} ${u.flowLabel}', 'h': '${fmt(u.pressureFromHead(dutyHead), 1)} ${u.pressureLabel}', 's': '${fmt(u.pressureFromHead(stat), 1)} ${u.pressureLabel}'}), style: const TextStyle(fontSize: 12)),
        Text(t('pump.candidates'), style: const TextStyle(fontSize: 11, color: Colors.white54)),
        const SizedBox(height: 6),
        Expanded(
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingTextStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                dataTextStyle: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                columns: [DataColumn(label: Text(t('props.pump'))), DataColumn(label: Text(t('pump.parallel'))), DataColumn(label: Text('${t('pump.hAtDuty')} (${u.pressureLabel})')), DataColumn(label: Text(t('pump.margin'))), DataColumn(label: Text(t('pump.opPoint'))), DataColumn(label: Text('${t('pump.power')} (kW)')), DataColumn(label: Text(t('pump.motor'))), DataColumn(label: Text('${t('pump.energy')} (${p.currency})')), DataColumn(label: Text(p.currency)), const DataColumn(label: Text(''))],
                rows: [
                  for (final k in cands)
                    DataRow(
                      color: k.suitable ? null : WidgetStatePropertyAll(Colors.orange.withValues(alpha: 0.12)),
                      cells: [
                        DataCell(Text(k.spec.name)),
                        DataCell(Text('${k.parallelCount}')),
                        DataCell(Text(fmt(u.pressureFromHead(k.headAtDuty), 1))),
                        DataCell(Text(k.suitable ? '+${fmt(u.pressureFromHead(k.margin), 1)}' : (!k.suctionOk ? t('pump.suction') : (k.inRange ? fmt(u.pressureFromHead(k.margin), 1) : t('pump.unsuitable'))))),
                        DataCell(Text(k.operatingFlow > 0 ? '${fmt(u.flowFromSi(k.operatingFlow), 1)} ${u.flowLabel} @ ${fmt(u.pressureFromHead(k.operatingHead), 1)}' : '—')),
                        DataCell(Text(fmt(k.shaftPowerKw * k.parallelCount, 1))),
                        DataCell(Builder(builder: (_) {
                          final m = standardMotor(k.shaftPowerKw);
                          return Text(m == null ? '—' : '${fmt(m.$1, m.$1 < 10 ? 1 : 0)} kW · ${fmt(m.$2, m.$2 < 10 ? 1 : 0)} cv${k.parallelCount > 1 ? ' ×${k.parallelCount}' : ''}');
                        })),
                        DataCell(Text(fmt(k.annualEnergy * k.parallelCount, 0))),
                        DataCell(Text(fmt(k.spec.cost * k.parallelCount, 0))),
                        DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                          TextButton(key: Key('pump_apply_${k.spec.id}'), onPressed: () {
                            _applyPump(c, s, k.spec, existing);
                            Navigator.pop(ctx);
                          }, child: Text(existing.isEmpty ? t('pump.insert') : t('pump.replace'), style: const TextStyle(fontSize: 11))),
                        ])),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }), width: 900);
}

void _applyPump(ProjectController c, WaterSupplyEntity s, PumpSpec spec, List<PumpEntity> existing) {
  // nearest existing pump to the supply, else a new one on the mainline pipe
  // leaving the supply (1.5 m along it)
  PumpEntity? target;
  var best = double.infinity;
  for (final p in existing) {
    final d = p.position.distanceTo(s.position);
    if (d < best) {
      best = d;
      target = p;
    }
  }
  if (target != null && best < 50) {
    final tp = target;
    c.mutate(() => tp.pumpSpecId = spec.id);
  } else {
    Pt pos = s.position + const Pt(2, 0);
    for (final pipe in c.project.entities.whereType<PipeEntity>()) {
      if (pipe.scope != HydraulicScope.mainline || pipe.points.length < 2) continue;
      if (pipe.points.first.distanceTo(s.position) < 0.05) {
        pos = pointAlongPolyline(pipe.points, 1.5);
        break;
      }
      if (pipe.points.last.distanceTo(s.position) < 0.05) {
        pos = pointAlongPolyline(pipe.points, pipe.length - 1.5);
        break;
      }
    }
    c.addPointItem(PumpEntity(id: c.project.newId(), position: pos, pumpSpecId: spec.id), pos, scopes: [HydraulicScope.mainline]);
  }
  c.notify(c.t('msg.pumpApplied', {'n': spec.name}));
}

// ---------------------------------------------------------------- 3D DEM

Future<void> showDemDialog(BuildContext context, ProjectController c) => showDialog<void>(
  context: context,
  builder: (ctx) => AlertDialog(
    title: Text(c.t('dem.title'), style: const TextStyle(fontSize: 15)),
    content: SizedBox(width: 820, height: 520, child: DemView(c: c)),
    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(c.t('close')))],
  ),
);

// ---------------------------------------------------------------- recovery

/// Offers to recover autosaved projects (called at start-up). Returns the
/// number of projects restored into new tabs.
Future<int> showRecoveryDialog(BuildContext context, Workspace ws) async {
  final c = ws.current;
  final t = c.t;
  final items = c.store.recoverable();
  if (items.isEmpty) return 0;
  final chosen = await showDialog<List<StoredProject>>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(t('rec.title'), style: const TextStyle(fontSize: 15)),
      content: SizedBox(
        width: 460,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('rec.text'), style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          for (final p in items) Text('• ${t('rec.item', {'name': p.name, 'when': _when(p.savedAt), 'kb': (p.bytes / 1024).toStringAsFixed(0)})}', style: const TextStyle(fontSize: 11.5)),
        ]),
      ),
      actions: [
        TextButton(key: const Key('rec_discard'), onPressed: () {
          for (final p in items) {
            c.store.remove(p.uid);
          }
          Navigator.pop(ctx, <StoredProject>[]);
        }, child: Text(t('rec.discard'))),
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('rec.later'))),
        FilledButton(key: const Key('rec_restore'), onPressed: () => Navigator.pop(ctx, items), child: Text(t('rec.restore'))),
      ],
    ),
  );
  if (chosen == null || chosen.isEmpty) return 0;
  var n = 0;
  for (final p in chosen) {
    final json = c.store.load(p.uid);
    if (json == null) continue;
    final blank = ws.current.project.entities.isEmpty && !ws.current.dirty;
    final target = blank && n == 0 ? ws.current : ws.addTab();
    try {
      target.loadJson(json);
      target.dirty = true;
      c.store.acknowledge(p.uid);
      n++;
    } catch (_) {
      if (!identical(target, ws.current) || !blank) ws.closeTab(ws.tabs.indexOf(target));
    }
  }
  if (n > 0) ws.current.notify(t('msg.recovered', {'n': '$n'}));
  return n;
}

// ---------------------------------------------------------------- versions

Future<void> showVersionsDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final versions = c.store.versions(c.project.meta.uid);
  return _show(context, c, t('ver.title', {'name': c.project.meta.name}), SizedBox(
    height: 300,
    child: versions.isEmpty
        ? Text(t('ver.none'), style: const TextStyle(fontSize: 12, color: Colors.white70))
        : ListView(children: [
            for (final v in versions)
              ListTile(
                dense: true,
                title: Text(t('ver.item', {'v': '${v.version}', 'when': _when(v.savedAt)}), style: const TextStyle(fontSize: 12)),
                subtitle: Text('${(v.bytes / 1024).toStringAsFixed(0)} kB${v.label.isNotEmpty ? ' · ${v.label}' : ''}', style: const TextStyle(fontSize: 10.5)),
                trailing: TextButton(key: Key('ver_restore_${v.version}'), onPressed: () {
                  final json = c.store.load(v.uid, version: v.version);
                  if (json == null) return;
                  c.loadJson(json);
                  c.dirty = true;
                  c.notify(t('msg.versionRestored', {'v': '${v.version}'}));
                  Navigator.pop(context);
                }, child: Text(t('ver.restore'))),
              ),
          ]),
  ), width: 480);
}

// ---------------------------------------------------------------- georeference an image

Future<void> showImageGeorefDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final u = c.units;
  final e = c.selectedEntity;
  if (e is! ImageEntity) {
    c.notify(t('msg.nothingSelected'));
    return Future.value();
  }
  var x = e.origin.x, y = e.origin.y, w = e.width, h = e.height, rot = e.rotationDeg;
  var keepAspect = true;
  final aspect = e.height / e.width;
  return _show(context, c, t('gimg.title'), StatefulBuilder(builder: (ctx, setState) {
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t('gimg.explain'), style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
      _row([
        NumField(label: 'X (${u.lengthLabel})', value: u.lengthFromSi(x), onChanged: (v) => x = u.lengthToSi(v)),
        NumField(label: 'Y (${u.lengthLabel})', value: u.lengthFromSi(y), onChanged: (v) => y = u.lengthToSi(v)),
      ]),
      _row([
        NumField(label: '${t('props.imageWidth')} ', value: u.lengthFromSi(w), onChanged: (v) => setState(() {
          w = u.lengthToSi(v);
          if (keepAspect) h = w * aspect;
        })),
        NumField(label: '${t('props.imageHeight')} ', value: u.lengthFromSi(h), onChanged: (v) => setState(() {
          h = u.lengthToSi(v);
          if (keepAspect) w = h / aspect;
        })),
      ]),
      SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(t('gimg.keepAspect'), style: const TextStyle(fontSize: 12)), value: keepAspect, onChanged: (v) => setState(() => keepAspect = v)),
      NumField(label: t('props.rotation'), value: rot, onChanged: (v) => rot = v),
    ]);
  }), actions: [
    TextButton(onPressed: () => Navigator.pop(context), child: Text(t('cancel'))),
    FilledButton(onPressed: () {
      c.mutate(() {
        e.origin = Pt(x, y);
        e.width = w <= 0 ? e.width : w;
        e.height = h <= 0 ? e.height : h;
        e.rotationDeg = rot;
      }, invalidateResults: false);
      Navigator.pop(context);
    }, child: Text(t('ok'))),
  ], width: 420);
}

// ---------------------------------------------------------------- catalog editor

Future<void> showCatalogEditorDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final cat = c.project.catalog;
  final cur = c.project.params.currency;
  var tab = CatalogGroup.pipes;
  final edit = c.beginSettingsEdit('hist.catalog');
  return _show(context, c, t('design.catalog'), StatefulBuilder(builder: (ctx, setState) {
    // usage counts (for the remove confirmation)
    final used = <String, int>{};
    for (final e in c.project.entities) {
      final ids = switch (e) {
        PipeEntity x => [x.pipeSpecId],
        SpraylineEntity x => [x.pipeSpecId, x.outletSpecId],
        TapeEntity x => [x.tapeSpecId],
        OutletEntity x => [x.outletSpecId],
        ControlValveEntity x => [x.valveSpecId],
        MiscHydraulicEntity x => [x.valveSpecId],
        PumpEntity x => [x.pumpSpecId],
        PivotEntity x => [x.pipeSpecId, x.sprinklerSpecId, x.regulatorSpecId],
        _ => const <String?>[],
      };
      for (final id in ids) {
        if (id != null) used[id] = (used[id] ?? 0) + 1;
      }
    }
    Future<bool> confirmRemove(String id, String name) async {
      final n = used[id] ?? 0;
      final ok = await showDialog<bool>(
        context: ctx,
        builder: (d) => AlertDialog(
          title: Text(t('cat.remove'), style: const TextStyle(fontSize: 15)),
          content: Text('${t('cat.removeConfirm', {'n': name})}${n > 0 ? '\n${t('cat.inUse', {'n': '$n'})}' : ''}', style: const TextStyle(fontSize: 12)),
          actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: Text(t('cancel'))), FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(t('ok')))],
        ),
      );
      return ok == true;
    }

    Widget removeBtn(String id, String name, VoidCallback remove) => IconButton(key: Key('cat_rm_$id'), icon: const Icon(Icons.delete_outline, size: 15), onPressed: () async {
      if (await confirmRemove(id, name)) setState(remove);
    });
    Widget dupBtn(VoidCallback dup) => IconButton(icon: const Icon(Icons.copy_outlined, size: 15), tooltip: t('cat.duplicate'), onPressed: () => setState(dup));

    void addItem() {
      setState(() {
        switch (tab) {
          case CatalogGroup.pipes:
            cat.pipes.add(PipeSpec(id: cat.newId('pipe'), name: 'PVC DN 50', nominalMm: 50, innerDiameterMm: 46, costPerM: 5));
          case CatalogGroup.outlets:
            cat.outlets.add(OutletSpec(id: cat.newId('out'), name: t('tool.outlet'), kind: OutletKind.microSprinkler, nozzles: [NozzleSpec(id: 'n1', name: '50 L/h', curve: EmitterCurve.fromNominal(flow: 50 * m3sPerLph, head: 15, radius: 3.5, radiusB: 0.35), defaultHeadM: 15, minHeadM: 10, maxHeadM: 30)], cost: 2));
          case CatalogGroup.tapes:
            cat.tapes.add(TapeSpec(id: cat.newId('tape'), name: t('tool.tape'), innerDiameterMm: 15.6, emitterSpacingM: 0.3, emitter: EmitterCurve.fromNominal(flow: 1.0 * m3sPerLph, head: 8), costPerM: 0.5));
          case CatalogGroup.valves:
            cat.valves.add(ValveSpec(id: cat.newId('valve'), name: t('tool.valve'), kind: ValveKind.control, sizeMm: 50, loss: DeviceLossCurve.fromK(5, 0.05), maxFlow: 30 * m3sPerM3h, cost: 300));
          case CatalogGroup.pumps:
            cat.pumps.add(PumpSpec(id: cat.newId('pump'), name: t('tool.pump'), points: [(0, 50), (20 * m3sPerM3h, 45), (40 * m3sPerM3h, 35)], cost: 5000));
          case CatalogGroup.fittings:
            cat.fittings.add(FittingSpec(id: cat.newId('fit'), name: '${t('fit.tee')} 50 mm', kind: FittingKind.tee, sizeMm: 50, cost: 8));
          case CatalogGroup.wires:
            cat.wires.add(WireSpec(id: cat.newId('wire'), name: '${t('cat.wire')} 2.5 mm²', sectionMm2: 2.5, ohmPerKm: copperOhmPerKm(2.5), costPerM: 2.6));
        }
      });
    }

    Widget meta(String sup, String code, void Function(String) onSup, void Function(String) onCode) => Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(width: 110, child: TextFieldRow(label: '', value: sup, onChanged: onSup)),
      const SizedBox(width: 4),
      SizedBox(width: 90, child: TextFieldRow(label: '', value: code, onChanged: onCode)),
    ]);

    Widget pipes() => _catTable([t('cat.use'), t('cat.name'), t('cat.dn'), t('cat.idmm'), t('cat.c'), t('cat.pn'), t('cat.costM', {'c': cur}), '${t('cat.supplier')} / ${t('cat.code')}', ''], [
      for (final p in cat.pipes)
        [
          Checkbox(value: p.enabled, onChanged: (v) => setState(() => p.enabled = v ?? true)),
          _cell(p.name, (v) => p.name = v),
          _num(p.nominalMm, (v) => p.nominalMm = v),
          _num(p.innerDiameterMm, (v) => p.innerDiameterMm = v),
          _num(p.hazenC, (v) => p.hazenC = v),
          _num(p.pressureRatingM, (v) => p.pressureRatingM = v),
          _num(p.costPerM, (v) => p.costPerM = v),
          meta(p.supplier, p.code, (v) => p.supplier = v, (v) => p.code = v),
          Row(mainAxisSize: MainAxisSize.min, children: [
            dupBtn(() => cat.pipes.add(PipeSpec.fromJson(p.toJson()..['id'] = cat.newId('pipe'))..name = '${p.name} *')),
            removeBtn(p.id, p.name, () => cat.pipes.remove(p)),
          ]),
        ],
    ]);
    Widget outlets() => _catTable([t('cat.use'), t('cat.outlet'), t('cat.nozzle'), t('cat.k'), t('cat.x'), t('cat.pMin'), t('cat.pMax'), t('cat.pDefault'), t('cat.cv'), t('cat.tol'), cur, ''], [
      for (final o in cat.outlets)
        for (final n in o.nozzles)
          [
            Checkbox(value: o.enabled, onChanged: (v) => setState(() => o.enabled = v ?? true)),
            identical(n, o.nozzles.first) ? _cell(o.name, (v) => o.name = v) : Text(o.name, style: const TextStyle(fontSize: 11, color: Colors.white38)),
            _cell(n.name, (v) => n.name = v),
            _num(n.curve.k / m3sPerLph, (v) => n.curve = EmitterCurve(k: v * m3sPerLph, x: n.curve.x, radiusA: n.curve.radiusA, radiusB: n.curve.radiusB), decimals: 3),
            _num(n.curve.x, (v) => n.curve = EmitterCurve(k: n.curve.k, x: v, radiusA: n.curve.radiusA, radiusB: n.curve.radiusB), decimals: 3),
            _num(n.minHeadM, (v) => n.minHeadM = v),
            _num(n.maxHeadM, (v) => n.maxHeadM = v),
            _num(n.defaultHeadM, (v) => n.defaultHeadM = v),
            _num(n.cv, (v) => n.cv = v, decimals: 3),
            _num(n.flowTolBelow * 100, (v) {
              n.flowTolBelow = v / 100;
              n.flowTolAbove = v / 100;
            }),
            _num(o.cost, (v) => o.cost = v),
            Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(Icons.add, size: 15), tooltip: t('cat.nozzle'), onPressed: () => setState(() => o.nozzles.add(NozzleSpec(id: '${o.id}_n${o.nozzles.length + 1}', name: '${n.name} *', curve: n.curve, minHeadM: n.minHeadM, maxHeadM: n.maxHeadM, defaultHeadM: n.defaultHeadM, cv: n.cv, arcDeg: n.arcDeg)))),
              if (identical(n, o.nozzles.first)) removeBtn(o.id, o.name, () => cat.outlets.remove(o)) else IconButton(icon: const Icon(Icons.remove, size: 15), onPressed: () => setState(() => o.nozzles.remove(n))),
            ]),
          ],
    ]);
    Widget tapes() => _catTable([t('cat.use'), t('cat.name'), t('cat.idmm'), t('cat.spacing'), t('cat.qNom'), t('cat.x'), t('cat.kd'), t('cat.cv'), t('cat.pMin'), t('cat.pMax'), t('cat.costM', {'c': cur}), ''], [
      for (final tp in cat.tapes)
        [
          Checkbox(value: tp.enabled, onChanged: (v) => setState(() => tp.enabled = v ?? true)),
          _cell(tp.name, (v) => tp.name = v),
          _num(tp.innerDiameterMm, (v) => tp.innerDiameterMm = v),
          _num(tp.emitterSpacingM, (v) => tp.emitterSpacingM = v),
          _num(tp.emitter.flow(tp.defaultInletHeadM) / m3sPerLph, (v) => tp.emitter = EmitterCurve.fromNominal(flow: v * m3sPerLph, head: tp.defaultInletHeadM, x: tp.emitter.x)),
          _num(tp.emitter.x, (v) => tp.emitter = EmitterCurve(k: tp.emitter.k, x: v), decimals: 3),
          _num(tp.barbK, (v) => tp.barbK = v),
          _num(tp.cv, (v) => tp.cv = v, decimals: 3),
          _num(tp.minHeadM, (v) => tp.minHeadM = v),
          _num(tp.maxHeadM, (v) => tp.maxHeadM = v),
          _num(tp.costPerM, (v) => tp.costPerM = v),
          Row(mainAxisSize: MainAxisSize.min, children: [
            dupBtn(() => cat.tapes.add(TapeSpec.fromJson(tp.toJson()..['id'] = cat.newId('tape'))..name = '${tp.name} *')),
            removeBtn(tp.id, tp.name, () => cat.tapes.remove(tp)),
          ]),
        ],
    ]);
    Widget valves() => _catTable([t('cat.use'), t('cat.name'), t('cat.type'), t('cat.dn'), t('cat.kLoss'), t('cat.n'), t('cat.qMax'), cur, ''], [
      for (final v in cat.valves)
        [
          Checkbox(value: v.enabled, onChanged: (x) => setState(() => v.enabled = x ?? true)),
          _cell(v.name, (x) => v.name = x),
          SizedBox(width: 110, child: SpecDropdown<ValveKind>(label: '', value: v.kind.name, items: ValveKind.values, labelOf: (k) => k.name, idOf: (k) => k.name, onChanged: (x) => setState(() => v.kind = ValveKind.values.byName(x!)))),
          _num(v.sizeMm, (x) => v.sizeMm = x),
          _num(v.loss.k, (x) => v.loss = DeviceLossCurve(k: x, n: v.loss.n, c: v.loss.c), decimals: 0),
          _num(v.loss.n, (x) => v.loss = DeviceLossCurve(k: v.loss.k, n: x, c: v.loss.c)),
          _num(v.maxFlow / m3sPerM3h, (x) => v.maxFlow = x * m3sPerM3h),
          _num(v.cost, (x) => v.cost = x),
          Row(mainAxisSize: MainAxisSize.min, children: [
            dupBtn(() => cat.valves.add(ValveSpec.fromJson(v.toJson()..['id'] = cat.newId('valve'))..name = '${v.name} *')),
            removeBtn(v.id, v.name, () => cat.valves.remove(v)),
          ]),
        ],
    ]);
    Widget pumps() => _catTable([t('cat.use'), t('cat.name'), t('cat.points'), t('cat.eff'), 'kW', t('cat.submersible'), cur, ''], [
      for (final p in cat.pumps)
        [
          Checkbox(value: p.enabled, onChanged: (x) => setState(() => p.enabled = x ?? true)),
          _cell(p.name, (x) => p.name = x),
          _cell(p.points.map((pt) => '${fmt(pt.$1 / m3sPerM3h, 1)}@${fmt(pt.$2, 1)}').join(', '), (x) {
            final pts = <(double, double)>[];
            for (final s in x.split(',')) {
              final parts = s.trim().split('@');
              if (parts.length == 2) {
                final q = double.tryParse(parts[0].trim()), h = double.tryParse(parts[1].trim());
                if (q != null && h != null) pts.add((q * m3sPerM3h, h));
              }
            }
            if (pts.length >= 2) {
              p.points = pts;
              p.refit();
            }
          }),
          _num(p.efficiency, (x) => p.efficiency = x),
          _num(p.powerKw, (x) => p.powerKw = x),
          Checkbox(value: p.submersible, onChanged: (x) => setState(() => p.submersible = x ?? false)),
          _num(p.cost, (x) => p.cost = x),
          Row(mainAxisSize: MainAxisSize.min, children: [
            dupBtn(() => cat.pumps.add(PumpSpec.fromJson(p.toJson()..['id'] = cat.newId('pump'))..name = '${p.name} *')),
            removeBtn(p.id, p.name, () => cat.pumps.remove(p)),
          ]),
        ],
    ]);
    Widget fittings() => _catTable([t('cat.use'), t('cat.name'), t('cat.kind'), t('cat.dn'), t('cat.size2'), cur, '${t('cat.supplier')} / ${t('cat.code')}', ''], [
      for (final f in cat.fittings)
        [
          Checkbox(value: f.enabled, onChanged: (x) => setState(() => f.enabled = x ?? true)),
          _cell(f.name, (x) => f.name = x),
          SizedBox(width: 120, child: SpecDropdown<FittingKind>(label: '', value: f.kind.name, items: FittingKind.values, labelOf: (k) => t('fit.${k.name}'), idOf: (k) => k.name, onChanged: (x) => setState(() => f.kind = FittingKind.values.byName(x!)))),
          _num(f.sizeMm, (x) => f.sizeMm = x),
          _num(f.size2Mm, (x) => f.size2Mm = x),
          _num(f.cost, (x) => f.cost = x),
          meta(f.supplier, f.code, (v) => f.supplier = v, (v) => f.code = v),
          Row(mainAxisSize: MainAxisSize.min, children: [
            dupBtn(() => cat.fittings.add(FittingSpec.fromJson(f.toJson()..['id'] = cat.newId('fit'))..name = '${f.name} *')),
            removeBtn(f.id, f.name, () => cat.fittings.remove(f)),
          ]),
        ],
    ]);
    Widget wires() => _catTable([t('cat.use'), t('cat.name'), t('cat.mm2'), t('cat.ohmKm'), t('cat.costM', {'c': cur}), '${t('cat.supplier')} / ${t('cat.code')}', ''], [
      for (final w in cat.wires)
        [
          Checkbox(value: w.enabled, onChanged: (x) => setState(() => w.enabled = x ?? true)),
          _cell(w.name, (x) => w.name = x),
          _num(w.sectionMm2, (x) {
            // a new section keeps the copper resistance unless it was edited
            if ((w.ohmPerKm - copperOhmPerKm(w.sectionMm2)).abs() < 0.01 && x > 0) w.ohmPerKm = double.parse(copperOhmPerKm(x).toStringAsFixed(3));
            w.sectionMm2 = x;
            setState(() {});
          }),
          _num(w.ohmPerKm, (x) => w.ohmPerKm = x, decimals: 3),
          _num(w.costPerM, (x) => w.costPerM = x),
          meta(w.supplier, w.code, (v) => w.supplier = v, (v) => w.code = v),
          Row(mainAxisSize: MainAxisSize.min, children: [
            dupBtn(() => cat.wires.add(WireSpec.fromJson(w.toJson()..['id'] = cat.newId('wire'))..name = '${w.name} *')),
            removeBtn(w.id, w.name, () => cat.wires.remove(w)),
          ]),
        ],
    ]);
    return SizedBox(
      height: 520,
      child: Column(children: [
        SegmentedButton<CatalogGroup>(
          segments: [for (final g in CatalogGroup.values) ButtonSegment(value: g, label: Text(t('cat.${g.name}'), style: const TextStyle(fontSize: 11.5)))],
          selected: {tab},
          onSelectionChanged: (v) => setState(() => tab = v.first),
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
        ),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 4, children: [
          FilledButton.tonal(key: const Key('cat_add'), onPressed: addItem, child: Text(t('cat.add'))),
          OutlinedButton(key: const Key('cat_import'), onPressed: () async {
            final f = await openBinaryFile(accept: '.json,.csv,.txt,.xlsx,.cat');
            if (f == null) return;
            try {
              final lower = f.$1.toLowerCase();
              final r = lower.endsWith('.xlsx')
                  ? CatalogIo.parseXlsx(f.$2)
                  : CatalogIo.parse(utf8.decode(f.$2, allowMalformed: true), group: lower.endsWith('.csv') || lower.endsWith('.txt') ? tab : null);
              final n = cat.merge(r.catalog, replace: true);
              c.notify(t('msg.catalogImported', {'n': '$n'}));
              setState(() {});
            } catch (e) {
              c.notify(t('msg.error', {'e': c.describeError(e)}));
            }
          }, child: Text(t('cat.importAny'))),
          OutlinedButton(onPressed: () => saveTextFile('catalog.json', CatalogIo.exportJson(cat)), child: Text(t('cat.export'))),
          OutlinedButton(onPressed: () => saveTextFile('catalog_${tab.name}.csv', CatalogIo.exportCsv(cat, tab), mime: 'text/csv'), child: Text(t('cat.exportCsv'))),
          OutlinedButton(key: const Key('cat_export_xlsx'), onPressed: () => saveBinaryFile('catalog.xlsx', CatalogIo.exportXlsx(cat), mime: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'), child: Text(t('cat.exportXlsx'))),
          OutlinedButton.icon(key: const Key('cat_packs'), onPressed: () async {
            await showCatalogPacksDialog(ctx, c);
            setState(() {});
          }, icon: const Icon(Icons.factory_outlined, size: 15), label: Text(t('cat.packs'))),
          OutlinedButton(key: const Key('cat_export_pack'), onPressed: () => showExportCatalogPackDialog(ctx, c), child: Text(t('cat.packExport'))),
          OutlinedButton(onPressed: () {
            c.saveDefaultCatalog();
            c.notify(t('msg.catalogDefaultSaved'));
          }, child: Text(t('cat.setDefault'))),
          OutlinedButton(onPressed: () {
            final d = Catalog.defaultCatalog(lang: c.lang, currency: c.project.params.currencyCode);
            setState(() {
              cat.pipes
                ..clear()
                ..addAll(d.pipes);
              cat.outlets
                ..clear()
                ..addAll(d.outlets);
              cat.tapes
                ..clear()
                ..addAll(d.tapes);
              cat.valves
                ..clear()
                ..addAll(d.valves);
              cat.pumps
                ..clear()
                ..addAll(d.pumps);
              cat.fittings
                ..clear()
                ..addAll(d.fittings);
              cat.wires
                ..clear()
                ..addAll(d.wires);
            });
            c.clearDefaultCatalog();
            c.notify(t('msg.catalogReset'));
          }, child: Text(t('cat.reset'))),
        ]),
        const SizedBox(height: 6),
        Expanded(child: switch (tab) { CatalogGroup.pipes => pipes(), CatalogGroup.outlets => outlets(), CatalogGroup.tapes => tapes(), CatalogGroup.valves => valves(), CatalogGroup.pumps => pumps(), CatalogGroup.fittings => fittings(), CatalogGroup.wires => wires() }),
        Text(t('cat.importHint'), style: const TextStyle(fontSize: 10, color: Colors.white38), maxLines: 3, overflow: TextOverflow.ellipsis),
      ]),
    );
  }), actions: [FilledButton(onPressed: () {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.pop(context);
  }, child: Text(t('ok')))], width: 1000).then((_) async {
    // however the dialog closes, the edits become one undo step
    await Future<void>.delayed(Duration.zero);
    c.commitSettingsEdit(edit);
  });
}

Widget _catTable(List<String> headers, List<List<Widget>> rows) => SingleChildScrollView(
  child: SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: DataTable(
      headingTextStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
      dataRowMaxHeight: 44,
      columns: [for (final h in headers) DataColumn(label: Text(h))],
      rows: [for (final r in rows) DataRow(cells: [for (final w in r) DataCell(w)])],
    ),
  ),
);

Widget _cell(String v, ValueChanged<String> onChanged) => SizedBox(width: 200, child: TextFieldRow(label: '', value: v, onChanged: onChanged));
Widget _num(double v, ValueChanged<double> onChanged, {int decimals = 2}) => SizedBox(width: 80, child: NumField(label: '', value: v, decimals: decimals, onChanged: onChanged));
