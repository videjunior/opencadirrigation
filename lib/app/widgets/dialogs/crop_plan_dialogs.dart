/// Agronomy dialogs added in 1.6.0: the user's own crops (crops the FAO-56
/// table does not have, with their stages, PRD-15), the fertigation by
/// growth stage of an area, and the uniformity in the field: the depth one
/// event of the programme applies, virtual catch cans and the evaluation of
/// the cans or emitter flows measured on site (PRD-28).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/catch_cans.dart';
import '../../../core/design/densogram.dart';
import '../../../core/design/fertigation_stages.dart';
import '../../../core/design/report_tables.dart';
import '../../../core/model/agronomy_plan.dart';
import '../../../core/model/entities.dart';
import '../../io/file_io.dart';
import '../../state/controller.dart';
import '../../theme.dart';
import '../fields.dart';
import '../reports_panel.dart' show ReportTableView;
import 'terrain_dialogs.dart' show dialogWidth;

Widget _row(List<Widget> children) => Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(width: 8), Expanded(child: children[i])],
  ],
);

/// Fields [per] a row, one under the other on a narrow screen.
Widget _grid(BuildContext ctx, List<Widget> fields, {int per = 3}) {
  final n = MediaQuery.sizeOf(ctx).width < 520 ? 1 : per;
  if (n == 1) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: fields);
  return Column(
    children: [
      for (var i = 0; i < fields.length; i += n) _row([for (var k = i; k < i + n; k++) k < fields.length ? fields[k] : const SizedBox.shrink()]),
    ],
  );
}

Widget _hint(String s) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Text(s, style: TextStyle(fontSize: 11.5, color: Cad.fg70)),
);

Widget _table(ReportTable tb, {double height = 200}) => SizedBox(
  height: height,
  child: ReportTableView(headers: tb.headers, rows: tb.rows, rowIds: tb.ids, rowColors: [for (final w in tb.warn) w ? Cad.tintWarning : null], title: tb.key, tools: true),
);

String _areaName(AreaEntity a) => a.name.isEmpty ? a.id : a.name;

// ---------------------------------------------------------------- user crops

/// The crops of the project that the FAO-56 table does not have (PRD-15):
/// each with its single crop coefficient curve (Kc ini, mid and end and the
/// four stage lengths), planting month, root depth, depletion fraction,
/// height, salt tolerance, Ky and the source of its values. The areas pick
/// them in their crop list; "Use on the selected areas" assigns one.
Future<void> showUserCropsDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final p = c.project;
  final crops = [for (final u in p.agronomy.userCrops) u.copy()];
  var sel = crops.isEmpty ? -1 : 0;
  final assign = <String, String>{}; // area id → crop id
  var gen = 0;
  final selectedAreas = [
    for (final id in c.selection)
      if (p.byId(id) case final AreaEntity a) a,
  ];
  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final u = sel >= 0 && sel < crops.length ? crops[sel] : null;
        Widget num(String key, String label, double value, ValueChanged<double> on, {int decimals = 2}) =>
            NumField(key: ValueKey('uc_${key}_${u?.id}_$gen'), label: label, value: value, decimals: decimals, onChanged: (v) => setState(() => on(v)));
        int usedBy(UserCrop x) => p.entities.whereType<AreaEntity>().where((a) => a.cropKey == x.key).length + assign.values.where((v) => v == x.id).length;
        final body = <Widget>[
          _hint(t('uc.hint')),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (var i = 0; i < crops.length; i++)
                ChoiceChip(
                  key: ValueKey('uc_crop_${crops[i].id}'),
                  label: Text(crops[i].name.isEmpty ? crops[i].id : crops[i].name, style: const TextStyle(fontSize: 12)),
                  selected: i == sel,
                  onSelected: (_) => setState(() {
                    sel = i;
                    gen++;
                  }),
                ),
              ActionChip(
                key: const Key('uc_add'),
                avatar: const Icon(Icons.add, size: 16),
                label: Text(t('uc.add'), style: const TextStyle(fontSize: 12)),
                onPressed: () => setState(() {
                  final name = '${t('uc.newName')} ${crops.length + 1}';
                  crops.add(UserCrop(id: userCropIdFor(name, crops.map((x) => x.id)), name: name));
                  sel = crops.length - 1;
                  gen++;
                }),
              ),
            ],
          ),
          if (u == null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(t('uc.none'), style: TextStyle(color: Cad.fg54, fontSize: 12)),
            )
          else ...[
            const SizedBox(height: 6),
            TextFieldRow(key: ValueKey('uc_name_${u.id}_$gen'), label: t('uc.name'), value: u.name, onChanged: (v) => setState(() => u.name = v.trim())),
            Text('${t('uc.key')}: ${u.key}', style: TextStyle(fontSize: 11, color: Cad.fg54)),
            _grid(ctx, [
              num('kcIni', 'Kc ini', u.kcIni, (v) => u.kcIni = v.clamp(0, 2).toDouble()),
              num('kcMid', 'Kc mid', u.kcMid, (v) => u.kcMid = v.clamp(0, 2).toDouble()),
              num('kcEnd', 'Kc end', u.kcEnd, (v) => u.kcEnd = v.clamp(0, 2).toDouble()),
            ]),
            Text(t('uc.stagesHint'), style: TextStyle(fontSize: 11, color: Cad.fg60)),
            _grid(ctx, [
              num('ini', t('fst.stage.initial'), u.initialDays, (v) => u.initialDays = v.clamp(0, 400).toDouble(), decimals: 0),
              num('dev', t('fst.stage.development'), u.developmentDays, (v) => u.developmentDays = v.clamp(0, 400).toDouble(), decimals: 0),
              num('mid', t('fst.stage.mid'), u.midDays, (v) => u.midDays = v.clamp(0, 400).toDouble(), decimals: 0),
              num('late', t('fst.stage.late'), u.lateDays, (v) => u.lateDays = v.clamp(0, 400).toDouble(), decimals: 0),
            ], per: 4),
            _grid(ctx, [
              SpecDropdown<int>(
                key: ValueKey('uc_month_${u.id}'),
                label: t('uc.plantingMonth'),
                value: '${u.plantingMonth}',
                items: [for (var m = 1; m <= 12; m++) m],
                labelOf: (m) => t('mon.$m'),
                idOf: (m) => '$m',
                onChanged: (v) => setState(() => u.plantingMonth = int.tryParse(v ?? '') ?? 1),
              ),
              num('zr', t('uc.rootDepth'), u.rootDepthM, (v) => u.rootDepthM = v.clamp(0.05, 5).toDouble()),
              num('p', t('uc.depletion'), u.depletionFraction, (v) => u.depletionFraction = v.clamp(0.05, 0.95).toDouble()),
              num('h', t('uc.height'), u.maxHeightM, (v) => u.maxHeightM = v.clamp(0, 30).toDouble()),
              num('ece', t('uc.eceThreshold'), u.eceThreshold, (v) => u.eceThreshold = v.clamp(0, 100).toDouble(), decimals: 1),
              num('eceMax', t('uc.eceMax'), u.eceMax, (v) => u.eceMax = v.clamp(0, 100).toDouble(), decimals: 1),
              num('ky', 'Ky', u.ky, (v) => u.ky = v.clamp(0, 3).toDouble()),
            ]),
            SwitchListTile(
              key: ValueKey('uc_perennial_${u.id}'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(t('uc.perennial'), style: const TextStyle(fontSize: 12)),
              value: u.perennial,
              onChanged: (v) => setState(() => u.perennial = v),
            ),
            TextFieldRow(key: ValueKey('uc_source_${u.id}_$gen'), label: t('uc.source'), value: u.source, maxLines: 2, onChanged: (v) => setState(() => u.source = v.trim())),
            if (u.eceThreshold > 0 && u.eceMax <= u.eceThreshold) Text(t('uc.eceBad'), style: TextStyle(fontSize: 11, color: Cad.caution)),
            Text(t('uc.usedBy', {'n': '${usedBy(u)}'}), style: TextStyle(fontSize: 11, color: Cad.fg60)),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                FilledButton.tonal(
                  key: const Key('uc_assign'),
                  onPressed: selectedAreas.isEmpty
                      ? null
                      : () => setState(() {
                          for (final a in selectedAreas) {
                            assign[a.id] = u.id;
                          }
                        }),
                  child: Text(t('uc.assign', {'n': '${selectedAreas.length}'})),
                ),
                TextButton(
                  key: const Key('uc_delete'),
                  onPressed: () => setState(() {
                    assign.removeWhere((_, v) => v == u.id);
                    crops.removeAt(sel);
                    sel = crops.isEmpty ? -1 : 0;
                    gen++;
                  }),
                  child: Text(t('uc.delete')),
                ),
              ],
            ),
          ],
        ];
        return AlertDialog(
          title: Text(t('uc.title'), style: const TextStyle(fontSize: 15)),
          content: SizedBox(
            width: dialogWidth(ctx, 620),
            child: ScrollBody(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: body),
            ),
          ),
          actions: [
            TextButton(key: const Key('uc_cancel'), onPressed: () => Navigator.pop(ctx), child: Text(t('cancel'))),
            FilledButton(
              key: const Key('uc_ok'),
              onPressed: () {
                FocusManager.instance.primaryFocus?.unfocus();
                Future<void>.delayed(Duration.zero, () {
                  final ids = {for (final x in crops) x.id};
                  bool deleted(AreaEntity a) => a.cropKey.startsWith(userCropPrefix) && !ids.contains(a.cropKey.substring(userCropPrefix.length));
                  final areasChanged = assign.isNotEmpty || p.entities.whereType<AreaEntity>().any(deleted);
                  c.mutate(
                    () {
                      p.agronomy.userCrops
                        ..clear()
                        ..addAll(crops);
                      for (final a in p.entities.whereType<AreaEntity>()) {
                        final to = assign[a.id];
                        if (to != null) {
                          final x = crops.firstWhere((k) => k.id == to);
                          a
                            ..cropKey = x.key
                            ..crop = x.name
                            ..useWaterBalance = true
                            ..rootDepthM = x.rootDepthM
                            ..mad = x.depletionFraction
                            ..kc = x.kcMid;
                        } else if (deleted(a)) {
                          // a crop deleted: the area keeps its typed Kc
                          a.cropKey = '';
                        }
                      }
                    },
                    invalidateResults: areasChanged,
                    label: 'hist.userCrops',
                  );
                });
                Navigator.pop(ctx);
              },
              child: Text(t('ok')),
            ),
          ],
        );
      },
    ),
  );
}

// ---------------------------------------------------------------- fertigation by stage

/// The fertigation of one area by growth stage: the doses of N, P₂O₅ and
/// K₂O of the cycle, the share of each stage (by the crop's water use, or
/// typed), the three products, every how many irrigations, the stock
/// solution and the injection share; the products, stock, injection rate,
/// concentration and EC rise of every stage. Save keeps the plan for the
/// area (the report shows it).
Future<void> showFertigationStagesDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final p = c.project;
  final areas = [
    for (final a in p.entities.whereType<AreaEntity>())
      if (a.points.length >= 3 && a.useWaterBalance) a,
  ];
  if (areas.isEmpty) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('fst.title'), style: const TextStyle(fontSize: 15)),
        content: SizedBox(width: dialogWidth(ctx, 420), child: Text(t('swb.noAreas'), style: const TextStyle(fontSize: 12.5))),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('close')))],
      ),
    );
  }
  final selected = [
    for (final id in c.selection)
      if (p.byId(id) case final AreaEntity a when areas.contains(a)) a,
  ];
  var area = selected.isNotEmpty ? selected.first : areas.first;
  var plan = (p.agronomy.fertigation[area.id] ?? FertigationStagePlan()).copy();
  var gen = 0;
  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final f = fertigationSchedule(p, area, plan: plan, results: c.results);
        Widget num(String key, String label, double value, ValueChanged<double> on, {int decimals = 1}) =>
            NumField(key: ValueKey('fst_${key}_$gen'), label: label, value: value, decimals: decimals, onChanged: (v) => setState(() => on(v)));
        const nutrients = ['N', 'P₂O₅', 'K₂O'];
        final body = <Widget>[
          _hint(t('fst.hint')),
          SpecDropdown<AreaEntity>(
            key: const Key('fst_area'),
            label: t('rep.area'),
            value: area.id,
            items: areas,
            labelOf: _areaName,
            idOf: (a) => a.id,
            onChanged: (v) => setState(() {
              area = areas.firstWhere((a) => a.id == v);
              plan = (p.agronomy.fertigation[area.id] ?? FertigationStagePlan()).copy();
              gen++;
            }),
          ),
          _grid(ctx, [for (var k = 0; k < 3; k++) num('dose$k', '${nutrients[k]} (kg/ha)', plan.doseKgHa[k], (v) => plan.doseKgHa[k] = v.clamp(0, 5000).toDouble(), decimals: 0)]),
          SwitchListTile(
            key: const Key('fst_share_auto'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(t('fst.shareAuto'), style: const TextStyle(fontSize: 12)),
            value: plan.sharePct == null,
            onChanged: (v) => setState(() {
              plan.sharePct = v ? null : [for (final s in f?.stages ?? const <FertStage>[]) List.of(s.sharePct)];
              if (!v && plan.sharePct!.length != 4) plan.sharePct = [for (var s = 0; s < 4; s++) List.filled(3, 25.0)];
              gen++;
            }),
          ),
          if (plan.sharePct != null)
            for (var s = 0; s < 4; s++)
              _grid(ctx, [
                for (var k = 0; k < 3; k++)
                  num(
                    'share${s}_$k',
                    '${t('fst.stage.${fertStageNames[s]}')} · ${nutrients[k]} (%)',
                    plan.sharePct![s][k],
                    (v) => plan.sharePct![s][k] = v.clamp(0, 100).toDouble(),
                    decimals: 0,
                  ),
              ]),
          const SizedBox(height: 4),
          Text(t('fst.products'), style: TextStyle(fontSize: 11.5, color: Cad.fg70)),
          for (var k = 0; k < 3; k++)
            _grid(ctx, [
              TextFieldRow(
                key: ValueKey('fst_prod_${k}_$gen'),
                label: t('fst.product${['N', 'P', 'K'][k]}'),
                value: _prodName(c, plan.products[k]),
                onChanged: (v) => setState(() => plan.products[k] = _withName(plan.products[k], v.trim())),
              ),
              num('pn$k', '% N', plan.products[k].nPct, (v) => plan.products[k] = _withGrade(plan.products[k], n: v), decimals: 1),
              num('pp$k', '% P₂O₅', plan.products[k].p2o5Pct, (v) => plan.products[k] = _withGrade(plan.products[k], p: v), decimals: 1),
              num('pk$k', '% K₂O', plan.products[k].k2oPct, (v) => plan.products[k] = _withGrade(plan.products[k], k: v), decimals: 1),
            ], per: 4),
          _grid(ctx, [
            num('every', t('fst.everyNth'), plan.everyNth.toDouble(), (v) => plan.everyNth = v.round().clamp(1, 30), decimals: 0),
            num('stock', t('fst.stockKgL'), plan.stockKgPerL, (v) => plan.stockKgPerL = v.clamp(0.01, 2).toDouble(), decimals: 2),
            num('inject', t('fst.injectionPct'), plan.injectionPct, (v) => plan.injectionPct = v.clamp(5, 100).toDouble(), decimals: 0),
          ]),
          const SizedBox(height: 6),
          if (f == null)
            Text(t('swb.none'), style: TextStyle(color: Cad.caution, fontSize: 12))
          else ...[
            KV(t('fst.totals'), [for (var k = 0; k < 3; k++) '${_prodName(c, plan.products[k])} ${fmtUi(f.productTotalsKg[k], 1)} kg'].join(' · ')),
            KV(
              'ECw',
              '${fmtUi(f.ecwDsM, 2)} → ${fmtUi(f.peakEcwDsM, 2)} dS/m${f.ecwLimitDsM == null ? '' : ' (${t('fst.ecLimit')} ${fmtUi(f.ecwLimitDsM!, 2)})'}',
              color: f.warnings.any((w) => w.startsWith('fert_ec_high')) ? Cad.caution : null,
            ),
            for (final w in f.warnings) Text(c.t.warning(w), style: TextStyle(fontSize: 11, color: Cad.caution)),
            _table(
              ReportTable(
                key: 'fertigation_${_areaName(area)}',
                title: t('reports.fertigationStages'),
                headers: [
                  t('fst.stage'),
                  t('fst.days'),
                  for (final n in nutrients) '$n (kg/ha)',
                  t('fst.events'),
                  for (var k = 0; k < 3; k++) '${_prodName(c, plan.products[k])} (kg)',
                  '${t('fst.stock')} (L)',
                  '${t('fst.injection')} (L/h)',
                  '${t('fst.concentration')} (g/L)',
                  'ΔEC (dS/m)',
                ],
                rows: [
                  for (final s in f.stages)
                    [
                      t('fst.stage.${fertStageNames[s.stage]}'),
                      s.days,
                      for (var k = 0; k < 3; k++) RNum(s.kgHa[k], 1),
                      s.fertigations,
                      for (var k = 0; k < 3; k++) RNum(s.productKgPerEvent[k], 2),
                      RNum(s.stockLPerEvent, 1),
                      RNum(s.injectionLph, 1),
                      RNum(s.concentrationGL, 2),
                      RNum(s.ecRiseDsM, 2),
                    ],
                ],
              ),
              height: 170,
            ),
          ],
        ];
        return AlertDialog(
          title: Text(t('fst.title'), style: const TextStyle(fontSize: 15)),
          content: SizedBox(
            width: dialogWidth(ctx, 680),
            child: ScrollBody(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: body),
            ),
          ),
          actions: [
            TextButton(key: const Key('fst_close'), onPressed: () => Navigator.pop(ctx), child: Text(t('close'))),
            FilledButton(
              key: const Key('fst_save'),
              onPressed: () {
                FocusManager.instance.primaryFocus?.unfocus();
                final keep = plan.copy();
                final id = area.id;
                c.mutate(() => p.agronomy.fertigation[id] = keep, invalidateResults: false, label: 'hist.fertigationStages');
                c.notify(t('fst.saved'));
              },
              child: Text(t('fst.save')),
            ),
          ],
        );
      },
    ),
  );
}

/// The name of product [x]: the translated name of a default product.
String _prodName(ProjectController c, FertProduct x) => c.t.has('fst.prod.${x.name}') ? c.t('fst.prod.${x.name}') : x.name;

FertProduct _withName(FertProduct x, String name) => FertProduct(name: name, nPct: x.nPct, p2o5Pct: x.p2o5Pct, k2oPct: x.k2oPct, ionic: x.ionic);
FertProduct _withGrade(FertProduct x, {double? n, double? p, double? k}) =>
    FertProduct(name: x.name, nPct: (n ?? x.nPct).clamp(0, 100).toDouble(), p2o5Pct: (p ?? x.p2o5Pct).clamp(0, 100).toDouble(), k2oPct: (k ?? x.k2oPct).clamp(0, 100).toDouble(), ionic: x.ionic);

// ---------------------------------------------------------------- uniformity in the field

/// Uniformity in the field: the depth one irrigation event of the
/// programme lays on the ground (the depth densogram, shown on the drawing
/// on request), virtual catch cans over an area with the readings the
/// design expects, and the field tests kept in the project — catch cans
/// read after a test of a zone, or emitter flows measured in a drip zone —
/// with their CU, DU and US against the design (PRD-28).
Future<void> showFieldUniformityDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final p = c.project;
  final tests = [for (final x in p.agronomy.fieldTests) x.copy()];
  final areas = [
    for (final a in p.entities.whereType<AreaEntity>())
      if (a.points.length >= 3) a,
  ];
  final valves = p.entities.whereType<ControlValveEntity>().toList();
  var sel = tests.isEmpty ? -1 : 0;
  var gen = 0;
  Densogram? depth;
  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        depth ??= depthDensogram(p, c.results, base: c.densogramOptions);
        final d = depth!;
        final ft = sel >= 0 && sel < tests.length ? tests[sel] : null;
        final e = ft == null || ft.values.isEmpty ? null : evaluateFieldTest(p, ft, results: c.results);
        Widget num(String key, String label, double value, ValueChanged<double> on, {int decimals = 1}) =>
            NumField(key: ValueKey('ft_${key}_${ft?.id}_$gen'), label: label, value: value, decimals: decimals, onChanged: (v) => setState(() => on(v)));
        String newId() => 'ft${DateTime.now().microsecondsSinceEpoch}';
        final body = <Widget>[
          _hint(t('ft.hint')),
          // ---- the depth of one event
          SectionTitle(t('ft.depthTitle')),
          if (d.isEmpty)
            Text(t('ft.depthNone'), style: TextStyle(fontSize: 12, color: Cad.fg60))
          else ...[
            KV(t('ft.depthMean'), '${fmtUi(d.stats.mean, 2)} mm (${fmtUi(d.stats.min, 1)} … ${fmtUi(d.stats.max, 1)})'),
            KV('CU / DU / SC', '${fmtUi(d.stats.cu, 1)} % / ${fmtUi(d.stats.du, 1)} % / ${d.stats.sc.isFinite ? fmtUi(d.stats.sc, 2) : '∞'}'),
            for (final a in d.areas) KV(a.name.isEmpty ? a.areaId : a.name, '${fmtUi(a.stats.mean, 1)} mm · CU ${fmtUi(a.stats.cu, 0)} % · DU ${fmtUi(a.stats.du, 0)} %'),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  key: const Key('ft_show_depth'),
                  onPressed: () => setState(() {
                    c.densogramOptions.depthHours = eventHoursByEntity(p, c.results);
                    c.showDensogram();
                  }),
                  child: Text(t('ft.showDepth')),
                ),
                TextButton(
                  key: const Key('ft_show_rate'),
                  onPressed: c.densogramOptions.depthHours == null
                      ? null
                      : () => setState(() {
                          c.densogramOptions.depthHours = null;
                          c.showDensogram();
                        }),
                  child: Text(t('ft.showRate')),
                ),
              ],
            ),
          ],
          // ---- the field tests
          SectionTitle(t('ft.testsTitle')),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (var i = 0; i < tests.length; i++)
                ChoiceChip(
                  key: ValueKey('ft_test_${tests[i].id}'),
                  label: Text(tests[i].name.isEmpty ? tests[i].id : tests[i].name, style: const TextStyle(fontSize: 12)),
                  selected: i == sel,
                  onSelected: (_) => setState(() {
                    sel = i;
                    gen++;
                  }),
                ),
              ActionChip(
                key: const Key('ft_add'),
                avatar: const Icon(Icons.add, size: 16),
                label: Text(t('ft.add'), style: const TextStyle(fontSize: 12)),
                onPressed: () => setState(() {
                  final a = areas.isEmpty ? null : areas.first;
                  final grid = a == null ? FieldTest(id: newId()) : canGridOver(a.points, id: newId(), areaId: a.id, zoneId: valves.isEmpty ? '' : valves.first.id);
                  grid.name = '${t('ft.newName')} ${tests.length + 1}';
                  grid.date = DateTime.now().toIso8601String().substring(0, 10);
                  tests.add(grid);
                  sel = tests.length - 1;
                  gen++;
                }),
              ),
            ],
          ),
          if (ft == null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(t('ft.none'), style: TextStyle(color: Cad.fg54, fontSize: 12)),
            )
          else ...[
            _grid(ctx, [
              TextFieldRow(key: ValueKey('ft_name_${ft.id}_$gen'), label: t('ft.name'), value: ft.name, onChanged: (v) => setState(() => ft.name = v.trim())),
              TextFieldRow(key: ValueKey('ft_date_${ft.id}_$gen'), label: t('ft.date'), value: ft.date, onChanged: (v) => setState(() => ft.date = v.trim())),
              SpecDropdown<FieldTestKind>(
                key: ValueKey('ft_kind_${ft.id}'),
                label: t('ft.kind'),
                value: ft.kind.name,
                items: FieldTestKind.values,
                labelOf: (k) => t('ft.kind.${k.name}'),
                idOf: (k) => k.name,
                onChanged: (v) => setState(() => ft.kind = FieldTestKind.values.byName(v!)),
              ),
              SpecDropdown<ControlValveEntity>(
                key: ValueKey('ft_zone_${ft.id}'),
                label: t('sch.zones'),
                value: ft.zoneId.isEmpty ? null : ft.zoneId,
                allowNull: true,
                nullLabel: t('ft.allZones'),
                items: valves,
                labelOf: (v) => v.zoneName.isEmpty ? v.id : v.zoneName,
                idOf: (v) => v.id,
                onChanged: (v) => setState(() => ft.zoneId = v ?? ''),
              ),
              SpecDropdown<AreaEntity>(
                key: ValueKey('ft_area_${ft.id}'),
                label: t('rep.area'),
                value: ft.areaId.isEmpty ? null : ft.areaId,
                allowNull: true,
                items: areas,
                labelOf: _areaName,
                idOf: (a) => a.id,
                onChanged: (v) => setState(() => ft.areaId = v ?? ''),
              ),
            ]),
            if (ft.kind == FieldTestKind.cans) ...[
              _grid(ctx, [
                num('dx', t('ft.dx'), ft.spacingXM, (v) => ft.spacingXM = v.clamp(0.5, 50).toDouble()),
                num('dy', t('ft.dy'), ft.spacingYM, (v) => ft.spacingYM = v.clamp(0.5, 50).toDouble()),
                num('deg', t('ft.angle'), ft.angleDeg, (v) => ft.angleDeg = v.clamp(-360, 360).toDouble(), decimals: 0),
                num('mouth', t('ft.mouth'), ft.canMouthMm, (v) => ft.canMouthMm = v.clamp(20, 500).toDouble(), decimals: 0),
                num('hours', t('ft.hours'), ft.durationH, (v) => ft.durationH = v.clamp(0.05, 24).toDouble(), decimals: 2),
                num('cols', t('ft.cols'), ft.cols.toDouble(), (v) => ft.cols = v.round().clamp(1, 10000), decimals: 0),
              ]),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  FilledButton.tonal(
                    key: const Key('ft_grid'),
                    onPressed: p.byId(ft.areaId) is! AreaEntity
                        ? null
                        : () => setState(() {
                            final a = p.byId(ft.areaId) as AreaEntity;
                            final g = canGridOver(
                              a.points,
                              id: ft.id,
                              dx: ft.spacingXM,
                              dy: ft.spacingYM,
                              angleDeg: ft.angleDeg,
                              mouthMm: ft.canMouthMm,
                              hours: ft.durationH,
                              zoneId: ft.zoneId,
                              areaId: a.id,
                            );
                            ft
                              ..origin = g.origin
                              ..cols = g.cols
                              ..values.clear()
                              ..values.addAll(g.values);
                            gen++;
                          }),
                    child: Text(t('ft.layGrid')),
                  ),
                  OutlinedButton(
                    key: const Key('ft_expected_csv'),
                    onPressed: ft.values.isEmpty ? null : () => saveTextFile('${p.meta.name}_${ft.name.isEmpty ? ft.id : ft.name}_cans.csv', _expectedCsv(c, ft), mime: 'text/csv'),
                    child: Text(t('ft.expectedCsv')),
                  ),
                ],
              ),
            ],
            TextFieldRow(
              key: ValueKey('ft_values_${ft.id}_$gen'),
              label: ft.kind == FieldTestKind.cans ? t('ft.valuesCans') : t('ft.valuesEmitters'),
              value: [for (final v in ft.values) v == null ? '-' : fmtUi(v, 1)].join(' '),
              maxLines: 4,
              onChanged: (v) => setState(() {
                final read = _parseUiValues(v);
                ft.values
                  ..clear()
                  ..addAll(read);
              }),
            ),
            if (e != null) ...[
              KV(t('ft.measured'), '${fmtUi(e.measuredStats.mean, 2)} ${ft.kind == FieldTestKind.cans ? 'mm' : 'L/h'} · CU ${fmtUi(e.measuredStats.cu, 1)} % · DU ${fmtUi(e.measuredStats.du, 1)} % · US ${fmtUi(e.measuredStats.us, 1)} %'),
              if (ft.kind == FieldTestKind.cans) KV(t('ft.rate'), '${fmtUi(e.meanRateMmH, 2)} mm/h'),
              if (e.predictedStats.count > 0)
                KV(t('ft.design'), '${fmtUi(e.predictedStats.mean, 2)} mm · CU ${fmtUi(e.predictedStats.cu, 1)} % · DU ${fmtUi(e.predictedStats.du, 1)} %'),
              if (e.designMean > 0) KV(t('ft.meanRatio'), '${fmtUi(100 * e.meanRatio, 0)} %', color: (e.meanRatio - 1).abs() > 0.1 ? Cad.caution : Cad.ok),
              if (ft.kind == FieldTestKind.cans && ft.cols > 0)
                SizedBox(
                  height: 140,
                  child: CustomPaint(
                    key: const Key('ft_map'),
                    painter: CanMapPainter(e.measured, ft.cols, mean: e.measuredStats.mean, empty: Cad.fg12),
                    child: const SizedBox.expand(),
                  ),
                ),
            ],
            TextButton(
              key: const Key('ft_delete'),
              onPressed: () => setState(() {
                tests.removeAt(sel);
                sel = tests.isEmpty ? -1 : 0;
                gen++;
              }),
              child: Text(t('ft.delete')),
            ),
          ],
        ];
        return AlertDialog(
          title: Text(t('ft.title'), style: const TextStyle(fontSize: 15)),
          content: SizedBox(
            width: dialogWidth(ctx, 660),
            child: ScrollBody(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: body),
            ),
          ),
          actions: [
            TextButton(key: const Key('ft_cancel'), onPressed: () => Navigator.pop(ctx), child: Text(t('cancel'))),
            FilledButton(
              key: const Key('ft_ok'),
              onPressed: () {
                FocusManager.instance.primaryFocus?.unfocus();
                Future<void>.delayed(Duration.zero, () {
                  c.mutate(
                    () => p.agronomy.fieldTests
                      ..clear()
                      ..addAll(tests),
                    invalidateResults: false,
                    label: 'hist.fieldTests',
                  );
                });
                Navigator.pop(ctx);
              },
              child: Text(t('ok')),
            ),
          ],
        );
      },
    ),
  );
}

/// Readings typed or pasted: numbers in the notation of the interface
/// language split by spaces, tabs, semicolons or line breaks; `-` or `x` is
/// a lost can.
List<double?> _parseUiValues(String text) => [
  for (final cell in text.split(RegExp(r'[\s;]+')))
    if (cell.trim().isNotEmpty)
      () {
        final x = cell.trim();
        if (x == '-' || x.toLowerCase() == 'x') return null;
        final v = parseUiNumber(x);
        return v != null && v.isFinite && v >= 0 ? v : null;
      }(),
];

/// The cans of [ft] with the reading the design expects (position, depth,
/// volume) and the one typed, as CSV.
String _expectedCsv(ProjectController c, FieldTest ft) {
  final e = evaluateFieldTest(c.project, ft, results: c.results);
  final b = StringBuffer('﻿');
  b.writeln([c.t('ft.row'), c.t('ft.col'), 'x', 'y', '${c.t('ft.design')} (mm)', '${c.t('ft.design')} (mL)', c.t('ft.measured')].join(';'));
  for (var k = 0; k < ft.values.length; k++) {
    final pr = e.predicted.length > k ? e.predicted[k] : null;
    if (ft.values[k] == null && pr == null) continue;
    final q = ft.position(k);
    final cols = math.max(1, ft.cols);
    b.writeln(
      [
        k ~/ cols + 1,
        k % cols + 1,
        q.x.toStringAsFixed(2),
        q.y.toStringAsFixed(2),
        pr == null ? '' : pr.toStringAsFixed(2),
        pr == null ? '' : canVolumeMl(pr, ft.canMouthMm).toStringAsFixed(0),
        ft.values[k] == null ? '' : ft.values[k]!.toStringAsFixed(1),
      ].join(';'),
    );
  }
  return b.toString();
}

/// The cans of a test as coloured cells, row by row (the first row at the
/// bottom), each against the mean as the densogram colours it.
class CanMapPainter extends CustomPainter {
  CanMapPainter(this.values, this.cols, {required this.mean, required this.empty});
  final List<double?> values;
  final int cols;
  final double mean;
  final Color empty;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || cols <= 0) return;
    final rows = (values.length / cols).ceil();
    final cell = math.min(size.width / cols, size.height / rows);
    if (cell <= 0) return;
    for (var k = 0; k < values.length; k++) {
      final r = k ~/ cols, col = k % cols;
      final rect = Rect.fromLTWH(col * cell, size.height - (r + 1) * cell, cell - 1, cell - 1);
      final v = values[k];
      canvas.drawRect(rect, Paint()..color = v == null ? empty : Color(densogramColor(v, mean)));
    }
  }

  @override
  bool shouldRepaint(covariant CanMapPainter old) => !identical(old.values, values) || old.mean != mean || old.cols != cols;
}
