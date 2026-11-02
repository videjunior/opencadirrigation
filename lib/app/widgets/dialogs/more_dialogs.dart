/// Dialogs added with the CAD-editing / persistence / engine-UI work:
/// array, pump selection, 3D terrain, recovery, versions,
/// image georeferencing and the catalog editor.
library;

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
import '../../io/prefs.dart';
import '../../io/project_store.dart';
import '../../io/window_locks.dart';
import '../../state/controller.dart';
import '../../state/workspace.dart';
import '../dem_view.dart';
import '../fields.dart';
import 'cad_plus_dialogs.dart' show openVersionInTabAction, showCompareDialog;
import 'catalog_packs_dialog.dart';
import '../../theme.dart';
import '../../project_name.dart'; // 1.6.0 UI
import 'help_dialog.dart' show helpTitle; // 1.6.0 UI

Future<T?> _show<T>(BuildContext context, ProjectController c, String title, Widget body, {List<Widget>? actions, double width = 520}) => showDialog<T>(
  context: context,
  builder: (ctx) {
    final compact = MediaQuery.sizeOf(ctx).width < 700;
    // the content always scrolls (see the dialogs.dart helper)
    return AlertDialog(
      title: helpTitle(c, title, style: const TextStyle(fontSize: 15)), // 1.6.0 UI: its "?" when the manual explains it
      content: SizedBox(
        width: compact ? MediaQuery.sizeOf(ctx).width - 48 : width,
        child: body is ScrollBody ? body : ScrollBody(child: body),
      ),
      actions: actions ?? [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(c.t('close')))],
    );
  },
);

Widget _row(List<Widget> children) => Row(
  children: [
    for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(width: 8), Expanded(child: children[i])],
  ],
);

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
  return _show(
    context,
    c,
    t('arr.title'),
    StatefulBuilder(
      builder: (ctx, setState) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t('arr.selection', {'n': '${c.selection.length}'}), style: TextStyle(fontSize: 11.5, color: Cad.fg54)),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text(t('arr.rect'))),
                ButtonSegment(value: true, label: Text(t('arr.polar'))),
              ],
              selected: {o.polar},
              onSelectionChanged: (v) => setState(() => o.polar = v.first),
            ),
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
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(t('arr.rotateItems'), style: const TextStyle(fontSize: 12)),
                value: o.rotateItems,
                onChanged: (v) => setState(() => o.rotateItems = v),
              ),
            ],
          ],
        );
      },
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: Text(t('cancel'))),
      FilledButton(
        key: const Key('array_ok'),
        onPressed: () {
          final n = c.arraySelected(o);
          c.notify(t('msg.arrayDone', {'n': '$n'}));
          Navigator.pop(context);
        },
        child: Text(t('ok')),
      ),
    ],
    width: 440,
  );
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
  return _show(
    context,
    c,
    t('pump.title'),
    StatefulBuilder(
      builder: (ctx, setState) {
        final s = supplies.firstWhere((x) => x.id == supplyId);
        final pd = worstPumpDuty(r, s.id);
        final duty = pd?.supply;
        if (pd == null || duty == null) return Text(t('pump.noSupply'));
        final dutyHead = pd.head;
        final stat = staticLift(c.project, r, s, duty);
        final others = [
          for (final d in pumpDuties(r, s.id))
            if (d.flowName != pd.flowName) (d.supply.flow, d.head),
        ];
        final cands = rankPumps(
          cat,
          flow: duty.flow,
          head: dutyHead,
          staticHead: stat,
          hoursPerYear: p.hoursPerYear,
          costPerKwh: p.powerCostPerKwh,
          otherDuties: others,
          requireSubmersible: suctionLiftTooDeep(s, duty),
          mainsHz: p.mainsHz,
          crf: pumpRankingCrf(p),
        );
        final existing = c.project.entities.whereType<PumpEntity>().toList();
        return SizedBox(
          height: 420,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (supplies.length > 1)
                SpecDropdown<WaterSupplyEntity>(
                  label: t('pump.supply'),
                  value: supplyId,
                  items: supplies,
                  labelOf: (x) => x.name,
                  idOf: (x) => x.id,
                  onChanged: (v) => setState(() => supplyId = v ?? supplyId),
                ),
              Text(
                t('pump.duty', {
                  'q': '${fmtUi(u.flowFromSi(duty.flow), 1)} ${u.flowLabel}',
                  'h': '${fmtUi(u.pressureFromHead(dutyHead), 1)} ${u.pressureLabel}',
                  's': '${fmtUi(u.pressureFromHead(stat), 1)} ${u.pressureLabel}',
                }),
                style: const TextStyle(fontSize: 12),
              ),
              Text(t('pump.candidates'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
              const SizedBox(height: 6),
              Expanded(
                child: SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingTextStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      dataTextStyle: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                      columns: [
                        DataColumn(label: Text(t('props.pump'))),
                        DataColumn(label: Text(t('pump.parallel'))),
                        DataColumn(label: Text('${t('pump.hAtDuty')} (${u.pressureLabel})')),
                        DataColumn(label: Text(t('pump.margin'))),
                        DataColumn(label: Text(t('pump.opPoint'))),
                        DataColumn(label: Text('${t('pump.power')} (kW)')),
                        DataColumn(label: Text(t('pump.motor'))),
                        DataColumn(label: Text('${t('pump.energy')} (${p.currency})')),
                        DataColumn(label: Text(p.currency)),
                        const DataColumn(label: Text('')),
                      ],
                      rows: [
                        for (final k in cands)
                          DataRow(
                            color: k.suitable ? null : WidgetStatePropertyAll(Cad.caution.withValues(alpha: 0.12)),
                            cells: [
                              DataCell(Text(k.spec.name)),
                              DataCell(Text('${k.parallelCount}')),
                              DataCell(Text(fmtUi(u.pressureFromHead(k.headAtDuty), 1))),
                              DataCell(
                                Text(
                                  k.suitable
                                      ? '+${fmtUi(u.pressureFromHead(k.margin), 1)}'
                                      : (!k.suctionOk ? t('pump.suction') : (k.inRange ? fmtUi(u.pressureFromHead(k.margin), 1) : t('pump.unsuitable'))),
                                ),
                              ),
                              DataCell(Text(k.operatingFlow > 0 ? '${fmtUi(u.flowFromSi(k.operatingFlow), 1)} ${u.flowLabel} @ ${fmtUi(u.pressureFromHead(k.operatingHead), 1)}' : '—')),
                              DataCell(Text(fmtUi(k.shaftPowerKw * k.parallelCount, 1))),
                              DataCell(
                                Builder(
                                  builder: (_) {
                                    final m = standardMotor(k.shaftPowerKw);
                                    return Text(m == null ? '—' : '${fmtUi(m.$1, m.$1 < 10 ? 1 : 0)} kW · ${fmtUi(m.$2, m.$2 < 10 ? 1 : 0)} cv${k.parallelCount > 1 ? ' ×${k.parallelCount}' : ''}');
                                  },
                                ),
                              ),
                              DataCell(Text(fmtUi(k.annualEnergy * k.parallelCount, 0))),
                              DataCell(Text(fmtUi(k.spec.cost * k.parallelCount, 0))),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextButton(
                                      key: Key('pump_apply_${k.spec.id}'),
                                      onPressed: () {
                                        _applyPump(c, s, k.spec, existing, parallel: k.parallelCount);
                                        Navigator.pop(ctx);
                                      },
                                      child: Text(existing.isEmpty ? t('pump.insert') : t('pump.replace'), style: const TextStyle(fontSize: 11)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
    width: 900,
  );
}

void _applyPump(ProjectController c, WaterSupplyEntity s, PumpSpec spec, List<PumpEntity> existing, {int parallel = 1}) {
  // 1.6.0 MOT: pumps in parallel become a pump station of equal pumps (the
  // standby ones of a station kept, of the new model)
  PumpStation? stationFor(PumpEntity? old) {
    final units = [
      for (var i = 1; i < parallel; i++) PumpUnit(),
      for (final u in old?.station?.units ?? const <PumpUnit>[])
        if (u.standby) PumpUnit(standby: true),
    ];
    return units.isEmpty ? null : PumpStation(units: units, staged: old?.station?.staged ?? true);
  }

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
    c.mutate(() {
      tp.pumpSpecId = spec.id;
      tp.station = stationFor(tp);
    });
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
    c.addPointItem(
      PumpEntity(id: c.project.newId(), position: pos, pumpSpecId: spec.id, station: stationFor(null)),
      pos,
      scopes: [HydraulicScope.mainline],
    );
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

/// Offers, at start-up, the copies of projects with changes that were not
/// saved to a file (the app or the browser closed before): one line per
/// project, each ticked to restore or to discard, and Later keeps them all
/// for another time. A project open in another window of this browser, or
/// in a tab here, is left out (it is alive there). Discarding drops only
/// the copy with the unsaved changes: a project saved before goes back to
/// its last saved version, whose history stays. Returns the number of
/// projects restored into tabs.
Future<int> showRecoveryDialog(BuildContext context, Workspace ws) async {
  final c = ws.current;
  final t = c.t;
  await c.store.prepare();
  final elsewhere = await windowLocks.openElsewhere();
  final open = {for (final x in ws.tabs) x.project.meta.uid};
  final items = c.store.recoverable().where((p) => !elsewhere.contains(p.uid) && !open.contains(p.uid)).toList();
  if (items.isEmpty || !context.mounted) return 0;
  final picked = {for (final p in items) p.uid};
  final choice = await showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(t('rec.title'), style: const TextStyle(fontSize: 15)),
        content: SizedBox(
          width: 480,
          child: ScrollBody(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('rec.text2'), style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 6),
                for (final p in items)
                  CheckboxListTile(
                    key: Key('rec_item_${p.uid}'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: picked.contains(p.uid),
                    onChanged: (v) => setState(() => v == true ? picked.add(p.uid) : picked.remove(p.uid)),
                    title: Text(t('rec.item', {'name': projectTitle(t, p.name), 'when': _when(p.savedAt), 'kb': (p.bytes / 1024).toStringAsFixed(0)}), style: const TextStyle(fontSize: 11.5)),
                    subtitle: c.store.versions(p.uid).isEmpty ? null : Text(t('rec.hasVersions', {'n': '${c.store.versions(p.uid).length}'}), style: TextStyle(fontSize: 10.5, color: Cad.fg54)),
                  ),
                const SizedBox(height: 4),
                Text(t('rec.discardNote'), style: TextStyle(fontSize: 10.5, color: Cad.fg54)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(key: const Key('rec_discard'), onPressed: picked.isEmpty ? null : () => Navigator.pop(ctx, 'discard'), child: Text(t('rec.discard'))),
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('rec.later'))),
          FilledButton(key: const Key('rec_restore'), onPressed: picked.isEmpty ? null : () => Navigator.pop(ctx, 'restore'), child: Text(t('rec.restore'))),
        ],
      ),
    ),
  );
  final chosen = items.where((p) => picked.contains(p.uid)).toList();
  if (choice == 'discard') {
    for (final p in chosen) {
      await c.store.discardAutosave(p.uid);
    }
    return 0;
  }
  if (choice != 'restore') return 0;
  var n = 0;
  for (final p in chosen) {
    final json = await c.store.load(p.uid);
    if (json == null) continue;
    final blank = ws.current.project.entities.isEmpty && !ws.current.dirty;
    final target = blank && n == 0 ? ws.current : ws.addTab();
    try {
      target.loadJson(json, fromStore: true);
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

/// File → Version history: the versions of this project kept in this
/// browser (every save keeps one). Restoring one is an undo step (Ctrl+Z
/// brings the work back as it was); a project with changes not saved to a
/// file asks first.
Future<void> showVersionsDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final versions = c.store.versions(c.project.meta.uid);
  Future<void> restore(BuildContext ctx, StoredProject v) async {
    if (c.dirty) {
      final ok = await showDialog<bool>(
        context: ctx,
        builder: (q) => AlertDialog(
          title: Text(t('ver.restore')),
          content: Text(t('ver.restoreConfirm', {'v': '${v.version}'})),
          actions: [
            TextButton(onPressed: () => Navigator.pop(q, false), child: Text(t('cancel'))),
            FilledButton(key: const Key('ver_restore_ok'), onPressed: () => Navigator.pop(q, true), child: Text(t('ok'))),
          ],
        ),
      );
      if (ok != true) return;
      // the work as it was also stays in the browser's copy until the next one
      await c.autosaveIfChanged();
    }
    final json = await c.store.load(v.uid, version: v.version);
    if (json == null) {
      c.notify(t('store.err.read'));
      return;
    }
    if (!c.restoreVersionJson(json, version: v.version)) return;
    c.notify(t('msg.versionRestoredUndo', {'v': '${v.version}'}));
    if (ctx.mounted) Navigator.pop(ctx);
  }

  return _show(
    context,
    c,
    t('ver.title', {'name': projectTitle(t, c.project.meta.name)}),
    SizedBox(
      height: 320,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: versions.isEmpty
                ? Text(t('ver.none'), style: TextStyle(fontSize: 12, color: Cad.fg70))
                : Builder(
                    builder: (ctx) => ListView(
                      children: [
                        for (final v in versions)
                          ListTile(
                            dense: true,
                            title: Text(t('ver.item', {'v': '${v.version}', 'when': _when(v.savedAt)}), style: const TextStyle(fontSize: 12)),
                            subtitle: Text('${(v.bytes / 1024).toStringAsFixed(0)} kB${v.label.isNotEmpty ? ' · ${v.label}' : ''}', style: const TextStyle(fontSize: 10.5)),
                            // 1.6.0 CAD: compare it with the drawing open, or open it in a tab of its own (PRD-11)
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(key: Key('ver_restore_${v.version}'), onPressed: () => restore(ctx, v), child: Text(t('ver.restore'))),
                                PopupMenuButton<String>(
                                  key: Key('ver_more_${v.version}'),
                                  tooltip: t('ver.more'),
                                  icon: const Icon(Icons.more_vert, size: 18),
                                  onSelected: (choice) async {
                                    if (choice == 'compare') {
                                      Navigator.pop(ctx);
                                      await showCompareDialog(context, c, version: v);
                                    } else if (await openVersionInTabAction(c, v) && ctx.mounted) {
                                      Navigator.pop(ctx);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    PopupMenuItem(key: Key('ver_compare_${v.version}'), value: 'compare', child: Text(t('ver.compare'))),
                                    PopupMenuItem(key: Key('ver_tab_${v.version}'), value: 'tab', child: Text(t('ver.openTab'))),
                                  ],
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 6),
          // what these copies are, and are not
          Text(
            t('store.notBackup'),
            key: const Key('ver_note'),
            style: TextStyle(fontSize: 10.5, color: Cad.fg54),
          ),
        ],
      ),
    ),
    width: 480,
  );
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
  return _show(
    context,
    c,
    t('gimg.title'),
    StatefulBuilder(
      builder: (ctx, setState) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t('gimg.explain'), style: TextStyle(fontSize: 11.5, color: Cad.fg70)),
            _row([
              NumField(label: 'X (${u.lengthLabel})', value: u.lengthFromSi(x), onChanged: (v) => x = u.lengthToSi(v)),
              NumField(label: 'Y (${u.lengthLabel})', value: u.lengthFromSi(y), onChanged: (v) => y = u.lengthToSi(v)),
            ]),
            _row([
              NumField(
                label: '${t('props.imageWidth')} ',
                value: u.lengthFromSi(w),
                onChanged: (v) => setState(() {
                  w = u.lengthToSi(v);
                  if (keepAspect) h = w * aspect;
                }),
              ),
              NumField(
                label: '${t('props.imageHeight')} ',
                value: u.lengthFromSi(h),
                onChanged: (v) => setState(() {
                  h = u.lengthToSi(v);
                  if (keepAspect) w = h / aspect;
                }),
              ),
            ]),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(t('gimg.keepAspect'), style: const TextStyle(fontSize: 12)),
              value: keepAspect,
              onChanged: (v) => setState(() => keepAspect = v),
            ),
            NumField(label: t('props.rotation'), value: rot, onChanged: (v) => rot = v),
          ],
        );
      },
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: Text(t('cancel'))),
      FilledButton(
        onPressed: () {
          c.mutate(() {
            e.origin = Pt(x, y);
            e.width = w <= 0 ? e.width : w;
            e.height = h <= 0 ? e.height : h;
            e.rotationDeg = rot;
          }, invalidateResults: false);
          Navigator.pop(context);
        },
        child: Text(t('ok')),
      ),
    ],
    width: 420,
  );
}

// ---------------------------------------------------------------- catalog editor

Future<void> showCatalogEditorDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final cat = c.project.catalog;
  final cur = c.project.params.currency;
  var tab = CatalogGroup.pipes;
  final edit = c.beginSettingsEdit('hist.catalog');
  return _show<bool>(
    context,
    c,
    t('design.catalog'),
    StatefulBuilder(
      builder: (ctx, setState) {
        // 1.6.0 MOD (MOD-20): the editor in the units of the project (the
        // catalogue keeps mm, m, m³/s and prices per metre): diameters in
        // inches, heads in the pressure unit, lengths and prices per foot,
        // device and pump flows in gpm; in the metric defaults every value
        // is shown as kept (device and pump flows in m³/h)
        final u = c.units;
        final inch = u.diameter == DiameterUnit.inch, mH2O = u.pressure == PressureUnit.mH2O, ft = u.length == LengthUnit.ft, gpm = u.flow == FlowUnit.gpm;
        final m3h = !gpm;
        double dia(double mm) => inch ? u.diameterFromSi(mm / 1000) : mm;
        double diaBack(double v) => inch ? u.diameterToSi(v) * 1000 : v;
        double prs(double m) => mH2O ? m : u.pressureFromHead(m);
        double prsBack(double v) => mH2O ? v : u.pressureToHead(v);
        double perLen(double perM) => ft ? perM * metersPerFoot : perM;
        double perLenBack(double v) => ft ? v / metersPerFoot : v;
        double len(double m) => ft ? m / metersPerFoot : m;
        double lenBack(double v) => ft ? v * metersPerFoot : v;
        double flw(double si) => m3h ? si / m3sPerM3h : u.flowFromSi(si);
        double flwBack(double v) => m3h ? v * m3sPerM3h : u.flowToSi(v);
        final dDec = inch ? 3 : 2;
        String dnLabel(String key) => inch ? '${t(key)} (${u.diameterLabel})' : t(key);
        final idLabel = inch ? t('cat.idU', {'u': u.diameterLabel}) : t('cat.idmm');
        final pnLabel = mH2O ? t('cat.pn') : t('cat.pnU', {'u': u.pressureLabel});
        final costLabel = ft ? t('cat.costFt', {'c': cur}) : t('cat.costM', {'c': cur});
        String pLabel(String key) => mH2O ? t(key) : '${t(key)} (${u.pressureLabel})';
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
              actions: [
                TextButton(onPressed: () => Navigator.pop(d, false), child: Text(t('cancel'))),
                FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(t('ok'))),
              ],
            ),
          );
          return ok == true;
        }

        Widget removeBtn(String id, String name, VoidCallback remove) => IconButton(
          key: Key('cat_rm_$id'),
          tooltip: t('cat.remove'),
          icon: const Icon(Icons.delete_outline, size: 15),
          onPressed: () async {
            if (await confirmRemove(id, name)) setState(remove);
          },
        );
        Widget dupBtn(VoidCallback dup) => IconButton(icon: const Icon(Icons.copy_outlined, size: 15), tooltip: t('cat.duplicate'), onPressed: () => setState(dup));

        // an item switched off while objects use it: they keep it (UI-10)
        void warnDisabled(String id, bool on) {
          final n = used[id] ?? 0;
          if (!on && n > 0) c.notify(t('cat.disabledInUse', {'n': '$n'}));
        }

        List<String> ids(Catalog k) => [
          for (final x in k.pipes) x.id,
          for (final x in k.outlets) x.id,
          for (final x in k.tapes) x.id,
          for (final x in k.valves) x.id,
          for (final x in k.pumps) x.id,
          for (final x in k.fittings) x.id,
          for (final x in k.wires) x.id,
        ];

        /// Asks before the project catalogue is replaced by [d], saying what
        /// leaves it: the items [d] does not have and how many objects of
        /// the drawing use them (they keep the id and lose the model).
        Future<bool> confirmReplace(String title, Catalog d) async {
          final keep = ids(d).toSet();
          final lost = [
            for (final id in ids(cat))
              if (!keep.contains(id)) id,
          ];
          final inUse = lost.where((id) => (used[id] ?? 0) > 0).toList();
          final objects = inUse.fold<int>(0, (n, id) => n + used[id]!);
          final ok = await showDialog<bool>(
            context: ctx,
            builder: (dc) => AlertDialog(
              title: Text(title, style: const TextStyle(fontSize: 15)),
              content: Text(
                [
                  lost.isEmpty ? t('cat.replaceNoLoss') : t('cat.replaceLoss', {'n': '${lost.length}'}),
                  if (inUse.isNotEmpty) t('cat.replaceInUse', {'n': '${inUse.length}', 'm': '$objects'}),
                  t('cat.replaceUndo'),
                ].join('\n\n'),
                key: const Key('cat_replace_text'),
                style: const TextStyle(fontSize: 12),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dc, false), child: Text(t('cancel'))),
                FilledButton(key: const Key('cat_replace_ok'), onPressed: () => Navigator.pop(dc, true), child: Text(t('cat.replace'))),
              ],
            ),
          );
          return ok == true;
        }

        void replaceWith(Catalog d) {
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
        }

        void addItem() {
          setState(() {
            switch (tab) {
              case CatalogGroup.pipes:
                cat.pipes.add(PipeSpec(id: cat.newId('pipe'), name: 'PVC DN 50', nominalMm: 50, innerDiameterMm: 46, costPerM: 5));
              case CatalogGroup.outlets:
                cat.outlets.add(
                  OutletSpec(
                    id: cat.newId('out'),
                    name: t('tool.outlet'),
                    kind: OutletKind.microSprinkler,
                    nozzles: [
                      NozzleSpec(
                        id: 'n1',
                        name: '50 L/h',
                        curve: EmitterCurve.fromNominal(flow: 50 * m3sPerLph, head: 15, radius: 3.5, radiusB: 0.35),
                        defaultHeadM: 15,
                        minHeadM: 10,
                        maxHeadM: 30,
                      ),
                    ],
                    cost: 2,
                  ),
                );
              case CatalogGroup.tapes:
                cat.tapes.add(
                  TapeSpec(
                    id: cat.newId('tape'),
                    name: t('tool.tape'),
                    innerDiameterMm: 15.6,
                    emitterSpacingM: 0.3,
                    emitter: EmitterCurve.fromNominal(flow: 1.0 * m3sPerLph, head: 8),
                    costPerM: 0.5,
                  ),
                );
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

        // supplier, manufacturer code and the BNDES FINAME code of the item
        Widget meta(String id, String sup, String code, void Function(String) onSup, void Function(String) onCode) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 110,
              child: TextFieldRow(label: '', value: sup, onChanged: onSup),
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 90,
              child: TextFieldRow(label: '', value: code, onChanged: onCode),
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 90,
              child: Tooltip(
                message: t('cat.finameTip'),
                child: TextFieldRow(key: Key('cat_finame_$id'), label: '', value: cat.finame[id] ?? '', onChanged: (v) => v.trim().isEmpty ? cat.finame.remove(id) : cat.finame[id] = v.trim()),
              ),
            ),
          ],
        );

        Widget pipes() => _catTable(
          [t('cat.use'), t('cat.name'), dnLabel('cat.dn'), idLabel, t('cat.c'), pnLabel, costLabel, '${t('cat.supplier')} / ${t('cat.code')} / FINAME', ''],
          [
            for (final p in cat.pipes)
              [
                Checkbox(
                  value: p.enabled,
                  onChanged: (v) => setState(() {
                    p.enabled = v ?? true;
                    warnDisabled(p.id, p.enabled);
                  }),
                ),
                _cell(p.name, (v) => p.name = v),
                _num(dia(p.nominalMm), (v) => p.nominalMm = diaBack(v), decimals: dDec),
                _num(dia(p.innerDiameterMm), (v) => p.innerDiameterMm = diaBack(v), decimals: dDec),
                _num(p.hazenC, (v) => p.hazenC = v),
                _num(prs(p.pressureRatingM), (v) => p.pressureRatingM = prsBack(v)),
                _num(perLen(p.costPerM), (v) => p.costPerM = perLenBack(v)),
                meta(p.id, p.supplier, p.code, (v) => p.supplier = v, (v) => p.code = v),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [dupBtn(() => cat.pipes.add(PipeSpec.fromJson(p.toJson()..['id'] = cat.newId('pipe'))..name = '${p.name} *')), removeBtn(p.id, p.name, () => cat.pipes.remove(p))],
                ),
              ],
          ],
        );
        Widget outlets() => _catTable(
          [t('cat.use'), t('cat.outlet'), t('cat.nozzle'), t('cat.k'), t('cat.x'), pLabel('cat.pMin'), pLabel('cat.pMax'), pLabel('cat.pDefault'), t('cat.cv'), t('cat.tol'), cur, ''],
          [
            for (final o in cat.outlets)
              for (final n in o.nozzles)
                [
                  Checkbox(
                    value: o.enabled,
                    onChanged: (v) => setState(() {
                      o.enabled = v ?? true;
                      warnDisabled(o.id, o.enabled);
                    }),
                  ),
                  identical(n, o.nozzles.first) ? _cell(o.name, (v) => o.name = v) : Text(o.name, style: TextStyle(fontSize: 11, color: Cad.fg38)),
                  _cell(n.name, (v) => n.name = v),
                  _num(n.curve.k / m3sPerLph, (v) => n.curve = EmitterCurve(k: v * m3sPerLph, x: n.curve.x, radiusA: n.curve.radiusA, radiusB: n.curve.radiusB), decimals: 3),
                  _num(n.curve.x, (v) => n.curve = EmitterCurve(k: n.curve.k, x: v, radiusA: n.curve.radiusA, radiusB: n.curve.radiusB), decimals: 3),
                  _num(prs(n.minHeadM), (v) => n.minHeadM = prsBack(v)),
                  _num(prs(n.maxHeadM), (v) => n.maxHeadM = prsBack(v)),
                  _num(prs(n.defaultHeadM), (v) => n.defaultHeadM = prsBack(v)),
                  _num(n.cv, (v) => n.cv = v, decimals: 3),
                  _num(n.flowTolBelow * 100, (v) {
                    n.flowTolBelow = v / 100;
                    n.flowTolAbove = v / 100;
                  }),
                  _num(o.cost, (v) => o.cost = v),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.table_chart_outlined, size: 15),
                        tooltip: t('cat.fitTable'),
                        onPressed: () async {
                          final curve = await showNozzleFitDialog(context, c, n);
                          if (curve != null) setState(() => n.curve = curve);
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.blur_circular, size: 15, color: n.profile.isEmpty ? null : Cad.positive),
                        tooltip: t('cat.profile'),
                        onPressed: () async {
                          final prof = await showNozzleProfileDialog(context, c, n);
                          if (prof != null) setState(() => n.profile = prof);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 15),
                        tooltip: t('cat.nozzle'),
                        onPressed: () => setState(
                          () => o.nozzles.add(
                            NozzleSpec(
                              id: '${o.id}_n${o.nozzles.length + 1}',
                              name: '${n.name} *',
                              curve: n.curve,
                              minHeadM: n.minHeadM,
                              maxHeadM: n.maxHeadM,
                              defaultHeadM: n.defaultHeadM,
                              cv: n.cv,
                              arcDeg: n.arcDeg,
                            ),
                          ),
                        ),
                      ),
                      if (identical(n, o.nozzles.first))
                        removeBtn(o.id, o.name, () => cat.outlets.remove(o))
                      else
                        IconButton(tooltip: t('ui.removeNozzle'), icon: const Icon(Icons.remove, size: 15), onPressed: () => setState(() => o.nozzles.remove(n))),
                    ],
                  ),
                ],
          ],
        );
        Widget tapes() => _catTable(
          [
            t('cat.use'),
            t('cat.name'),
            idLabel,
            ft ? t('cat.spacingFt') : t('cat.spacing'),
            t('cat.qNom'),
            t('cat.x'),
            t('cat.kd'),
            t('cat.cv'),
            pLabel('cat.pMin'),
            pLabel('cat.pMax'),
            costLabel,
            '',
          ],
          [
            for (final tp in cat.tapes)
              [
                Checkbox(
                  value: tp.enabled,
                  onChanged: (v) => setState(() {
                    tp.enabled = v ?? true;
                    warnDisabled(tp.id, tp.enabled);
                  }),
                ),
                _cell(tp.name, (v) => tp.name = v),
                _num(dia(tp.innerDiameterMm), (v) => tp.innerDiameterMm = diaBack(v), decimals: dDec),
                _num(len(tp.emitterSpacingM), (v) => tp.emitterSpacingM = v > 0 ? lenBack(v) : tp.emitterSpacingM),
                _num(tp.emitter.flow(tp.defaultInletHeadM) / m3sPerLph, (v) => tp.emitter = EmitterCurve.fromNominal(flow: v * m3sPerLph, head: tp.defaultInletHeadM, x: tp.emitter.x)),
                _num(tp.emitter.x, (v) => tp.emitter = EmitterCurve(k: tp.emitter.k, x: v), decimals: 3),
                _num(tp.barbK, (v) => tp.barbK = v),
                _num(tp.cv, (v) => tp.cv = v, decimals: 3),
                _num(prs(tp.minHeadM), (v) => tp.minHeadM = prsBack(v)),
                _num(prs(tp.maxHeadM), (v) => tp.maxHeadM = prsBack(v)),
                _num(perLen(tp.costPerM), (v) => tp.costPerM = perLenBack(v)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [dupBtn(() => cat.tapes.add(TapeSpec.fromJson(tp.toJson()..['id'] = cat.newId('tape'))..name = '${tp.name} *')), removeBtn(tp.id, tp.name, () => cat.tapes.remove(tp))],
                ),
              ],
          ],
        );
        Widget valves() => _catTable(
          [
            t('cat.use'),
            t('cat.name'),
            t('cat.type'),
            dnLabel('cat.dn'),
            t('cat.kLoss'),
            t('cat.n'),
            m3h ? t('cat.qMax') : t('cat.qMaxU', {'u': u.flowLabel}),
            cur,
            '',
          ],
          [
            for (final v in cat.valves)
              [
                Checkbox(
                  value: v.enabled,
                  onChanged: (x) => setState(() {
                    v.enabled = x ?? true;
                    warnDisabled(v.id, v.enabled);
                  }),
                ),
                _cell(v.name, (x) => v.name = x),
                SizedBox(
                  width: 110,
                  child: SpecDropdown<ValveKind>(
                    label: '',
                    value: v.kind.name,
                    items: ValveKind.values,
                    labelOf: (k) => k.name,
                    idOf: (k) => k.name,
                    onChanged: (x) => setState(() => v.kind = ValveKind.values.byName(x!)),
                  ),
                ),
                _num(dia(v.sizeMm), (x) => v.sizeMm = diaBack(x), decimals: dDec),
                _num(v.loss.k, (x) => v.loss = DeviceLossCurve(k: x, n: v.loss.n, c: v.loss.c), decimals: 0),
                _num(v.loss.n, (x) => v.loss = DeviceLossCurve(k: v.loss.k, n: x, c: v.loss.c)),
                _num(flw(v.maxFlow), (x) => v.maxFlow = flwBack(x)),
                _num(v.cost, (x) => v.cost = x),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [dupBtn(() => cat.valves.add(ValveSpec.fromJson(v.toJson()..['id'] = cat.newId('valve'))..name = '${v.name} *')), removeBtn(v.id, v.name, () => cat.valves.remove(v))],
                ),
              ],
          ],
        );
        Widget pumps() => _catTable(
          [
            t('cat.use'),
            t('cat.name'),
            m3h && mH2O ? t('cat.points') : t('cat.pointsU', {'q': m3h ? 'm³/h' : u.flowLabel, 'h': u.pressureLabel}),
            t('cat.eff'),
            m3h ? t('cat.effPoints') : t('cat.effPointsU', {'q': u.flowLabel}),
            m3h && mH2O ? t('cat.npshPoints') : t('cat.npshPointsU', {'q': m3h ? 'm³/h' : u.flowLabel, 'h': u.pressureLabel}),
            'kW',
            t('cat.ratedHz'),
            t('cat.submersible'),
            cur,
            '',
          ],
          [
            for (final p in cat.pumps)
              [
                Checkbox(
                  value: p.enabled,
                  onChanged: (x) => setState(() {
                    p.enabled = x ?? true;
                    warnDisabled(p.id, p.enabled);
                  }),
                ),
                _cell(p.name, (x) => p.name = x),
                _cell(p.points.map((pt) => '${fmtUi(flw(pt.$1), 1)}@${fmtUi(prs(pt.$2), 1)}').join(', '), (x) {
                  final pts = [for (final (q, h) in CatalogIo.parseCurvePoints(x)) (flwBack(q), prsBack(h))];
                  if (pts.length >= 2) {
                    p.points = pts;
                    p.refit();
                  }
                }),
                _num(p.efficiency, (x) => p.efficiency = x),
                _cell(p.efficiencyPoints.map((pt) => '${fmtUi(flw(pt.$1), 1)}@${fmtUi(pt.$2 * 100, 0)}').join(', '), (x) {
                  p.efficiencyPoints = [
                    for (final (q, e) in CatalogIo.parseCurvePoints(x))
                      if (e > 0) (flwBack(q), e > 1 ? e / 100 : e),
                  ];
                }),
                _cell(p.npshPoints.map((pt) => '${fmtUi(flw(pt.$1), 1)}@${fmtUi(prs(pt.$2), 1)}').join(', '), (x) {
                  p.npshPoints = [for (final (q, h) in CatalogIo.parseCurvePoints(x)) (flwBack(q), prsBack(h))];
                }),
                _num(p.powerKw, (x) => p.powerKw = x),
                _num(p.ratedHz, (x) => p.ratedHz = x < 0 ? 0 : x),
                Checkbox(value: p.submersible, onChanged: (x) => setState(() => p.submersible = x ?? false)),
                _num(p.cost, (x) => p.cost = x),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [dupBtn(() => cat.pumps.add(PumpSpec.fromJson(p.toJson()..['id'] = cat.newId('pump'))..name = '${p.name} *')), removeBtn(p.id, p.name, () => cat.pumps.remove(p))],
                ),
              ],
          ],
        );
        Widget fittings() => _catTable(
          [t('cat.use'), t('cat.name'), t('cat.kind'), dnLabel('cat.dn'), dnLabel('cat.size2'), cur, '${t('cat.supplier')} / ${t('cat.code')} / FINAME', ''],
          [
            for (final f in cat.fittings)
              [
                Checkbox(
                  value: f.enabled,
                  onChanged: (x) => setState(() {
                    f.enabled = x ?? true;
                    warnDisabled(f.id, f.enabled);
                  }),
                ),
                _cell(f.name, (x) => f.name = x),
                SizedBox(
                  width: 120,
                  child: SpecDropdown<FittingKind>(
                    label: '',
                    value: f.kind.name,
                    items: FittingKind.values,
                    labelOf: (k) => t('fit.${k.name}'),
                    idOf: (k) => k.name,
                    onChanged: (x) => setState(() => f.kind = FittingKind.values.byName(x!)),
                  ),
                ),
                _num(dia(f.sizeMm), (x) => f.sizeMm = diaBack(x), decimals: dDec),
                _num(dia(f.size2Mm), (x) => f.size2Mm = diaBack(x), decimals: dDec),
                _num(f.cost, (x) => f.cost = x),
                meta(f.id, f.supplier, f.code, (v) => f.supplier = v, (v) => f.code = v),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [dupBtn(() => cat.fittings.add(FittingSpec.fromJson(f.toJson()..['id'] = cat.newId('fit'))..name = '${f.name} *')), removeBtn(f.id, f.name, () => cat.fittings.remove(f))],
                ),
              ],
          ],
        );
        Widget wires() => _catTable(
          [t('cat.use'), t('cat.name'), t('cat.mm2'), t('cat.ohmKm'), costLabel, '${t('cat.supplier')} / ${t('cat.code')} / FINAME', ''],
          [
            for (final w in cat.wires)
              [
                Checkbox(
                  value: w.enabled,
                  onChanged: (x) => setState(() {
                    w.enabled = x ?? true;
                    warnDisabled(w.id, w.enabled);
                  }),
                ),
                _cell(w.name, (x) => w.name = x),
                _num(w.sectionMm2, (x) {
                  // a new section keeps the copper resistance unless it was edited
                  if ((w.ohmPerKm - copperOhmPerKm(w.sectionMm2)).abs() < 0.01 && x > 0) w.ohmPerKm = double.parse(copperOhmPerKm(x).toStringAsFixed(3));
                  w.sectionMm2 = x;
                  setState(() {});
                }),
                _num(w.ohmPerKm, (x) => w.ohmPerKm = x, decimals: 3),
                _num(perLen(w.costPerM), (x) => w.costPerM = perLenBack(x)),
                meta(w.id, w.supplier, w.code, (v) => w.supplier = v, (v) => w.code = v),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [dupBtn(() => cat.wires.add(WireSpec.fromJson(w.toJson()..['id'] = cat.newId('wire'))..name = '${w.name} *')), removeBtn(w.id, w.name, () => cat.wires.remove(w))],
                ),
              ],
          ],
        );
        // a phone: the buttons wrap into more lines and the table keeps its room
        // (the dialog's content scrolls)
        final narrow = MediaQuery.sizeOf(ctx).width < 700;
        return SizedBox(
          height: narrow ? 820 : 520,
          child: Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<CatalogGroup>(
                  segments: [
                    for (final g in CatalogGroup.values)
                      ButtonSegment(
                        value: g,
                        label: Text(t('cat.${g.name}'), style: const TextStyle(fontSize: 11.5)),
                      ),
                  ],
                  selected: {tab},
                  onSelectionChanged: (v) => setState(() => tab = v.first),
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  FilledButton.tonal(key: const Key('cat_add'), onPressed: addItem, child: Text(t('cat.add'))),
                  OutlinedButton(
                    key: const Key('cat_import'),
                    onPressed: () async {
                      final f = await openBinaryFile(accept: '.json,.csv,.txt,.xlsx,.cat');
                      if (f == null || !ctx.mounted) return;
                      // 1.6.0 MOD: packs keep the existing ids, rows without id never replace another item
                      await importCatalogFile(ctx, c, cat, tab, name: f.$1, bytes: f.$2);
                      setState(() {});
                    },
                    child: Text(t('cat.importAny')),
                  ),
                  OutlinedButton(onPressed: () => saveTextFile('catalog.json', CatalogIo.exportJson(cat)), child: Text(t('cat.export'))),
                  OutlinedButton(
                    onPressed: () => saveTextFile('catalog_${tab.name}.csv', CatalogIo.exportCsv(cat, tab, units: u), mime: 'text/csv'),
                    child: Text(t('cat.exportCsv')),
                  ),
                  OutlinedButton(
                    key: const Key('cat_export_xlsx'),
                    onPressed: () => saveBinaryFile('catalog.xlsx', CatalogIo.exportXlsx(cat), mime: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
                    child: Text(t('cat.exportXlsx')),
                  ),
                  OutlinedButton.icon(
                    key: const Key('cat_packs'),
                    onPressed: () async {
                      await showCatalogPacksDialog(ctx, c);
                      setState(() {});
                    },
                    icon: const Icon(Icons.factory_outlined, size: 15),
                    label: Text(t('cat.packs')),
                  ),
                  OutlinedButton(key: const Key('cat_export_pack'), onPressed: () => showExportCatalogPackDialog(ctx, c), child: Text(t('cat.packExport'))),
                  OutlinedButton(
                    onPressed: () {
                      c.saveDefaultCatalog();
                      c.notify(t('msg.catalogDefaultSaved'));
                    },
                    child: Text(t('cat.setDefault')),
                  ),
                  // three separate choices: the factory catalogue in this project, the
                  // user's saved default in this project, forgetting that default
                  OutlinedButton(
                    key: const Key('cat_factory'),
                    onPressed: () async {
                      final d = Catalog.defaultCatalog(lang: c.lang, currency: c.project.params.currencyCode);
                      if (!await confirmReplace(t('cat.factory'), d)) return;
                      setState(() => replaceWith(d));
                      c.notify(t('msg.catalogFactory'));
                    },
                    child: Text(t('cat.factory')),
                  ),
                  if (hasSavedDefaultCatalog()) ...[
                    OutlinedButton(
                      key: const Key('cat_load_default'),
                      onPressed: () async {
                        final d = c.defaultCatalog();
                        if (!await confirmReplace(t('cat.loadDefault'), d)) return;
                        setState(() => replaceWith(d));
                        c.notify(t('msg.catalogDefaultLoaded'));
                      },
                      child: Text(t('cat.loadDefault')),
                    ),
                    OutlinedButton(
                      key: const Key('cat_forget_default'),
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: ctx,
                          builder: (d) => AlertDialog(
                            title: Text(t('cat.forgetDefault'), style: const TextStyle(fontSize: 15)),
                            content: Text(t('cat.forgetConfirm'), style: const TextStyle(fontSize: 12)),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(d, false), child: Text(t('cancel'))),
                              FilledButton(key: const Key('cat_forget_ok'), onPressed: () => Navigator.pop(d, true), child: Text(t('cat.forget'))),
                            ],
                          ),
                        );
                        if (ok != true) return;
                        c.clearDefaultCatalog();
                        setState(() {});
                        c.notify(t('msg.catalogDefaultForgotten'));
                      },
                      child: Text(t('cat.forgetDefault')),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                flex: 4,
                child: switch (tab) {
                  CatalogGroup.pipes => pipes(),
                  CatalogGroup.outlets => outlets(),
                  CatalogGroup.tapes => tapes(),
                  CatalogGroup.valves => valves(),
                  CatalogGroup.pumps => pumps(),
                  CatalogGroup.fittings => fittings(),
                  CatalogGroup.wires => wires(),
                },
              ),
              // what the import reads (1.6.0 MOD: and its units), cut short
              // before the table loses its room (large text)
              Flexible(
                child: Text(
                  '${t('cat.importHint')}\n${t('cat.importUnits')}${inch || !mH2O || ft || gpm ? '\n${t('cat.unitsNote')}' : ''}',
                  style: TextStyle(fontSize: 10, color: Cad.fg38),
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    ),
    actions: [
      TextButton(
        key: const Key('cat_cancel'),
        onPressed: () {
          FocusManager.instance.primaryFocus?.unfocus();
          Navigator.pop(context, false);
        },
        child: Text(t('cancel')),
      ),
      FilledButton(
        key: const Key('cat_ok'),
        onPressed: () {
          FocusManager.instance.primaryFocus?.unfocus();
          Navigator.pop(context, true);
        },
        child: Text(t('ok')),
      ),
    ],
    width: 1000,
  ).then((ok) async {
    // OK: the edits become one undo step; Cancel, Esc or a tap outside put
    // the catalogue back as it was (after the field being typed in commits)
    await Future<void>.delayed(Duration.zero);
    if (ok == true) {
      c.commitSettingsEdit(edit);
    } else {
      c.cancelSettingsEdit(edit);
    }
  });
}

Widget _catTable(List<String> headers, List<List<Widget>> rows) => SingleChildScrollView(
  child: SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: DataTable(
      headingTextStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
      dataRowMaxHeight: 44,
      columns: [for (final h in headers) DataColumn(label: Text(h))],
      rows: [
        for (final r in rows) DataRow(cells: [for (final w in r) DataCell(w)]),
      ],
    ),
  ),
);

/// Fits the curve of [nozzle] to the rows of its data sheet (pressure, flow
/// and, optionally, wetted radius per line, pasted from a table or typed);
/// returns the new curve, or null when cancelled.
Future<EmitterCurve?> showNozzleFitDialog(BuildContext context, ProjectController c, NozzleSpec nozzle) {
  final t = c.t;
  final u = c.project.params.units;
  var flowUnit = nozzle.curve.flow(nozzle.defaultHeadM) < 0.05 / 3600 ? FlowUnit.lph : u.flow;
  var text = '';
  return showDialog<EmitterCurve>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final fu = Units(flow: flowUnit);
        final rows = parseNumberRows(text);
        final fit = EmitterCurve.fitTable([
          for (final r in rows)
            if (r.length >= 2) (u.pressureToHead(r[0]), fu.flowToSi(r[1]), r.length >= 3 ? u.lengthToSi(r[2]) : null),
        ]);
        final ok = fit.isUsable && fit.flowRows >= 2;
        final compact = MediaQuery.sizeOf(ctx).width < 700;
        return AlertDialog(
          title: Text('${t('cat.fitTable')}: ${nozzle.name}', style: const TextStyle(fontSize: 15)),
          content: SizedBox(
            width: compact ? MediaQuery.sizeOf(ctx).width - 48 : 480,
            child: ScrollBody(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('cat.fitHint', {'p': u.pressureLabel, 'q': fu.flowLabel, 'r': u.lengthLabel}), style: TextStyle(fontSize: 12, color: Cad.fg70)),
                  const SizedBox(height: 8),
                  SpecDropdown<FlowUnit>(
                    label: t('cat.fitFlowUnit'),
                    value: flowUnit.name,
                    items: FlowUnit.values,
                    labelOf: (f) => Units(flow: f).flowLabel,
                    idOf: (f) => f.name,
                    onChanged: (v) => setState(() => flowUnit = FlowUnit.values.byName(v!)),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('nozzle_fit_rows'),
                    minLines: 5,
                    maxLines: 10,
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    decoration: InputDecoration(border: const OutlineInputBorder(), isDense: true, hintText: '1,5   32   2,1\n2,0   37   2,3\n2,5   41   2,5'),
                    onChanged: (v) => setState(() => text = v),
                  ),
                  const SizedBox(height: 10),
                  if (!ok)
                    Text(t('cat.fitNeedRows'), style: TextStyle(fontSize: 12, color: Cad.attention))
                  else ...[
                    KV('q = k·Hˣ', 'k ${fmtUi(fit.curve.k / m3sPerLph, 4)} L/h·m⁻ˣ   x ${fmtUi(fit.curve.x, 3)}'),
                    KV(
                      t('cat.fitAtDefault', {'p': '${fmtUi(u.pressureFromHead(nozzle.defaultHeadM), 2)} ${u.pressureLabel}'}),
                      '${fmtUi(fu.flowFromSi(fit.curve.flow(nozzle.defaultHeadM)), 2)} ${fu.flowLabel}',
                    ),
                    KV(t('cat.fitFlowError'), '${fmtUi(fit.maxFlowError * 100, 1)} %', color: fit.maxFlowError > 0.05 ? Cad.caution : null),
                    if (fit.radiusRows > 0) ...[
                      KV('R = a·Hᵇ', 'a ${fmtUi(fit.curve.radiusA, 3)}   b ${fmtUi(fit.curve.radiusB, 3)}'),
                      KV(t('cat.fitRadiusError'), '${fmtUi(fit.maxRadiusError * 100, 1)} %', color: fit.maxRadiusError > 0.08 ? Cad.caution : null),
                    ] else
                      Text(t('cat.fitKeepRadius'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('cancel'))),
            FilledButton(
              key: const Key('nozzle_fit_apply'),
              onPressed: !ok
                  ? null
                  : () => Navigator.pop(ctx, fit.radiusRows > 0 ? fit.curve : EmitterCurve(k: fit.curve.k, x: fit.curve.x, radiusA: nozzle.curve.radiusA, radiusB: nozzle.curve.radiusB)),
              child: Text(t('apply')),
            ),
          ],
        );
      },
    ),
  );
}

/// Puts one device (pressure regulator, on/off valve…) on every selected
/// lateral and tape, near its inlet.
Future<void> showDeviceOnLateralsDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final u = c.project.params.units;
  final specs = c.project.catalog.valves.where((v) => v.enabled && v.kind != ValveKind.control && v.kind != ValveKind.master).toList();
  final lines = c.editableSelection.where((e) => e is SpraylineEntity || e is TapeEntity).length;
  var specId = specs.where((v) => v.kind == ValveKind.prv).firstOrNull?.id ?? specs.firstOrNull?.id;
  var distance = 0.3;
  return _show(
    context,
    c,
    t('zone.deviceOnLaterals'),
    StatefulBuilder(
      builder: (ctx, setState) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t('zone.deviceOnLateralsHint', {'n': '$lines'}), style: TextStyle(fontSize: 12, color: Cad.fg70)),
            const SizedBox(height: 8),
            SpecDropdown<ValveSpec>(label: t('props.misc'), value: specId, items: specs, labelOf: (v) => v.name, idOf: (v) => v.id, onChanged: (v) => setState(() => specId = v)),
            NumField(label: '${t('zone.deviceDistance')} (${u.lengthLabel})', value: u.lengthFromSi(distance), onChanged: (v) => distance = u.lengthToSi(v)),
          ],
        );
      },
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: Text(t('cancel'))),
      FilledButton(
        key: const Key('device_laterals_ok'),
        onPressed: lines == 0
            ? null
            : () {
                Navigator.pop(context);
                final id = specId;
                if (id == null || !c.editAllowed()) return;
                final n = c.insertDeviceOnSelectedLaterals(id, distanceM: distance);
                c.notify(t('msg.deviceOnLateralsDone', {'n': '$n'}));
              },
        child: Text(t('ok')),
      ),
    ],
  );
}

/// Measured radial profile of [nozzle] from a catch-can test: rows of
/// distance from the head and depth (or rate); returns the profile scaled
/// to the wetted radius and the largest depth, an empty list to remove it,
/// or null when cancelled.
Future<List<(double, double)>?> showNozzleProfileDialog(BuildContext context, ProjectController c, NozzleSpec nozzle) {
  final t = c.t;
  final u = c.project.params.units;
  var text = nozzle.profile.isEmpty ? '' : [for (final (x, y) in nozzle.profile) '${fmtUi(u.lengthFromSi(x * nozzle.curve.radius(nozzle.defaultHeadM)), 2)}\t${fmtUi(y, 3)}'].join('\n');
  final field = TextEditingController(text: text);
  return showDialog<List<(double, double)>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final rows = [
          for (final r in parseNumberRows(text))
            if (r.length >= 2) (u.lengthToSi(r[0]), r[1]),
        ];
        final prof = profileFromTable(rows);
        return AlertDialog(
          title: Text('${t('cat.profile')}: ${nozzle.name}', style: const TextStyle(fontSize: 15)),
          content: SizedBox(
            width: 460,
            child: ScrollBody(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('cat.profileHint', {'r': u.lengthLabel}), style: TextStyle(fontSize: 12, color: Cad.fg70)),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('nozzle_profile_rows'),
                    controller: field,
                    minLines: 6,
                    maxLines: 14,
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, hintText: '0   4,1\n2   4,4\n4   4,0\n6   3,1\n8   1,8\n10  0,6\n11  0'),
                    onChanged: (v) => setState(() => text = v),
                  ),
                  const SizedBox(height: 8),
                  if (prof == null) Text(t('cat.profileNeed'), style: TextStyle(fontSize: 12, color: Cad.attention)) else KV(t('cat.profileStations'), '${prof.length}'),
                ],
              ),
            ),
          ),
          actions: [
            if (nozzle.profile.isNotEmpty) TextButton(onPressed: () => Navigator.pop(ctx, const <(double, double)>[]), child: Text(t('cat.profileRemove'))),
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('cancel'))),
            FilledButton(key: const Key('nozzle_profile_apply'), onPressed: prof == null ? null : () => Navigator.pop(ctx, prof), child: Text(t('apply'))),
          ],
        );
      },
    ),
  ).whenComplete(field.dispose);
}

Widget _cell(String v, ValueChanged<String> onChanged) => SizedBox(
  width: 200,
  child: TextFieldRow(label: '', value: v, onChanged: onChanged),
);
Widget _num(double v, ValueChanged<double> onChanged, {int decimals = 2}) => SizedBox(
  width: 80,
  child: NumField(label: '', value: v, decimals: decimals, onChanged: onChanged),
);

/// Whether the user saved a catalogue as the default of new projects (in
/// this browser).
bool hasSavedDefaultCatalog() => getPref('catalog.default') != null;
