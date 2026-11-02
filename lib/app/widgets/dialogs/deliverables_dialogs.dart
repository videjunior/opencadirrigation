/// The technical documents of Reports → Technical documents (1.6.0): the
/// water permit table with its self-monitoring sheet, the descriptive and
/// calculation memorial, the operation and maintenance plan, the budget by
/// compositions and the life-cycle cost of the alternatives. Each dialog
/// edits the settings of its document in place (OK keeps them as one undo
/// step, Cancel puts them back), shows what the document will hold, and
/// exports it as PDF, XLSX, CSV or Markdown with the settings as they are.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/budget.dart';
import '../../../core/design/life_cycle.dart';
import '../../../core/design/memorial.dart';
import '../../../core/design/om_plan.dart';
import '../../../core/design/permit.dart';
import '../../../core/design/report_tables.dart' show ReportLabels;
import '../../../core/io/tech_doc.dart';
import '../../../core/model/deliverables.dart';
import '../../../core/units.dart';
import '../../actions.dart' show deliverExport;
import '../../io/pdf_font_loader.dart';
import '../../state/controller.dart';
import '../../theme.dart';
import '../fields.dart';
import 'terrain_dialogs.dart' show dialogWidth;

/// The formats every document exports to.
enum DocFormat {
  pdf('pdf', 'application/pdf'),
  xlsx('xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
  csv('csv', 'text/csv'),
  md('md', 'text/markdown');

  const DocFormat(this.extension, this.mime);
  final String extension;
  final String mime;
}

/// Where the documents go: the app's own download helper (tests replace it
/// to read the files). The data is a [String] (text) or bytes.
Future<void> Function(ProjectController c, String filename, String mime, Object data) docFileSink = (c, filename, mime, data) => deliverExport(c, filename, mime, () => data);

/// The data of [doc] in [f] (a PDF has its fonts loaded first).
Future<Object> techDocumentData(ProjectController c, TechDocument doc, DocFormat f) async {
  switch (f) {
    case DocFormat.pdf:
      await preparePdfFonts(doc.texts, language: c.lang);
      return techDocumentPdf(doc, t: c.t.call, author: c.project.meta.designer);
    case DocFormat.xlsx:
      return doc.toXlsx();
    case DocFormat.csv:
      return doc.toCsv();
    case DocFormat.md:
      return doc.toMarkdown();
  }
}

/// The file name of document [doc]: the project's and the document's.
String techDocumentFileName(ProjectController c, TechDocument doc, DocFormat f) {
  final n = c.project.meta.name.trim();
  final stem = (n.isEmpty ? c.t('name.newProject') : n).replaceAll(RegExp(r'[^\w\-]+', unicode: true), '_');
  return '${stem}_${c.t('prb.file.${doc.key}')}.${f.extension}';
}

/// Exports [doc] as [f] through [docFileSink].
Future<void> exportTechDocument(ProjectController c, TechDocument doc, DocFormat f) async {
  final data = await techDocumentData(c, doc, f);
  await docFileSink(c, techDocumentFileName(c, doc, f), f.mime, data);
}

/// The documents of the project, by key (`permit`, `memorial`, `om`,
/// `budget`, `lcc`), built from its current settings and results.
TechDocument buildTechDocument(ProjectController c, String key) {
  final p = c.project;
  final r = c.results;
  final labels = c.exporter().labels;
  return switch (key) {
    'permit' => permitDocument(p, buildPermitStudy(p, r, cropName: labels.category), c.t.call, entityName: c.entityName),
    'memorial' => buildMemorial(p, r, labels),
    'om' => buildOmPlan(p, r, labels),
    'budget' => budgetDocument(p, buildBudget(p, r, describe: c.t.call), labels),
    'lcc' => lifeCycleDocument(p, buildLifeCycleStudy(p, r, currentName: c.t('prb.lcc.current')), labels),
    _ => throw ArgumentError(key),
  };
}

/// The keys of the documents.
const techDocumentKeys = ['permit', 'memorial', 'om', 'budget', 'lcc'];

// ---------------------------------------------------------------- shared parts

/// Fields side by side, each at least [minWidth] wide; on a narrow dialog
/// (a phone, large text) they wrap into more lines.
Widget _row(List<Widget> children, {double minWidth = 150}) => LayoutBuilder(
  builder: (context, box) {
    final per = box.maxWidth.isFinite ? math.max(1, math.min(children.length, ((box.maxWidth + 8) / (minWidth + 8)).floor())) : children.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i += per)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var j = i; j < i + per; j++) ...[if (j > i) const SizedBox(width: 8), Expanded(child: j < children.length ? children[j] : const SizedBox.shrink())],
            ],
          ),
      ],
    );
  },
);

Widget _hint(String s, {Color? color}) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Text(s, style: TextStyle(fontSize: 11.5, color: color ?? Cad.fg70)),
);

Widget _switch(String label, bool value, ValueChanged<bool> onChanged, {Key? key}) => SwitchListTile(
  key: key,
  dense: true,
  contentPadding: EdgeInsets.zero,
  title: Text(label, style: const TextStyle(fontSize: 12)),
  value: value,
  onChanged: onChanged,
);

/// The export buttons of a document.
Widget _exportRow(ProjectController c, TechDocument Function() doc) {
  final t = c.t;
  String label(DocFormat f) => switch (f) {
    DocFormat.pdf => t('exp.reportPdf'),
    DocFormat.xlsx => t('exp.xlsx'),
    DocFormat.csv => t('exp.csv'),
    DocFormat.md => t('prb.fmt.md'),
  };
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      SectionTitle(t('prb.dlg.export')),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final f in DocFormat.values)
            OutlinedButton.icon(
              key: Key('prb_export_${f.name}'),
              onPressed: () {
                FocusManager.instance.primaryFocus?.unfocus();
                // the value being typed is committed on the focus change first
                Future<void>.delayed(Duration.zero, () => exportTechDocument(c, doc(), f));
              },
              icon: Icon(f == DocFormat.pdf ? Icons.picture_as_pdf_outlined : (f == DocFormat.md ? Icons.notes : Icons.table_view), size: 16),
              label: Text(label(f), style: const TextStyle(fontSize: 12)),
            ),
        ],
      ),
    ],
  );
}

/// The titles of the sections of [doc], for a look at what it holds.
Widget _sections(ProjectController c, TechDocument doc) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  mainAxisSize: MainAxisSize.min,
  children: [
    SectionTitle(c.t('prb.dlg.sections')),
    for (var i = 0; i < doc.sections.length; i++)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Text('${i + 1}. ${doc.sections[i].title}', style: TextStyle(fontSize: 11.5, color: Cad.fg70)),
      ),
  ],
);

/// A document dialog: [body] edits the settings in place (rebuilt with
/// its setState), the export buttons write [doc] as it is; OK makes the
/// changes one undo step, Cancel puts them back.
Future<void> _documentDialog(
  BuildContext context,
  ProjectController c, {
  required String title,
  required String historyLabel,
  required String docKey,
  required List<Widget> Function(StateSetter setState) body,
  double width = 640,
}) {
  final edit = c.beginSettingsEdit(historyLabel);
  return showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 15)),
        content: SizedBox(
          width: dialogWidth(ctx, width),
          child: ScrollBody(
            child: Column(
              key: Key('prb_dialog_$docKey'),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [...body(setState), _exportRow(c, () => buildTechDocument(c, docKey))],
            ),
          ),
        ),
        actions: [
          TextButton(key: const Key('prb_cancel'), onPressed: () => _close(ctx, false), child: Text(c.t('cancel'))),
          FilledButton(key: const Key('prb_ok'), onPressed: () => _close(ctx, true), child: Text(c.t('ok'))),
        ],
      ),
    ),
  ).then((ok) async {
    // the field being typed commits on the focus change, before the edit ends
    await Future<void>.delayed(Duration.zero);
    if (ok == true) {
      c.commitSettingsEdit(edit);
    } else {
      c.cancelSettingsEdit(edit);
    }
  });
}

void _close(BuildContext context, bool ok) {
  FocusManager.instance.primaryFocus?.unfocus();
  Navigator.pop(context, ok);
}

ReportLabels _labels(ProjectController c) => c.exporter().labels;

// ---------------------------------------------------------------- water permit table (PRD-02)

/// Reports → Technical documents → Water permit table: the regime of every
/// month of each point of abstraction, its permit data and the
/// self-monitoring.
Future<void> showPermitTableDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  return _documentDialog(
    context,
    c,
    title: t('prb.permit.title'),
    historyLabel: 'hist.prb.permit',
    docKey: 'permit',
    body: (setState) {
      final p = c.project;
      final s = p.deliverables.permit;
      final study = buildPermitStudy(p, c.results, cropName: _labels(c).category);
      return [
        _hint(t('prb.dlg.permitHint')),
        SectionTitle(t('prb.dlg.regime')),
        _row([
          NumField(
            key: const Key('prb_permit_hours'),
            label: t('prb.dlg.fixedHours'),
            value: s.fixedHoursPerDay,
            decimals: 1,
            onChanged: (v) => setState(() => s.fixedHoursPerDay = v.clamp(0, 24).toDouble()),
          ),
          NumField(
            key: const Key('prb_permit_max_hours'),
            label: t('prb.dlg.maxHours'),
            value: s.maxHoursPerDay,
            decimals: 1,
            onChanged: (v) => setState(() => s.maxHoursPerDay = v.clamp(1, 24).toDouble()),
          ),
        ]),
        _switch(t('prb.dlg.floor'), s.federalFloor, (v) => setState(() => s.federalFloor = v), key: const Key('prb_permit_floor')),
        SpecDropdown<MonitoringUnit>(
          label: t('prb.permit.unit'),
          value: monitoringUnitOf(s.monitoringUnit).key,
          items: monitoringUnits,
          labelOf: (u) => t('prb.unit.${u.key}'),
          idOf: (u) => u.key,
          onChanged: (v) => setState(() => s.monitoringUnit = v == null || v == 'other' ? '' : v),
        ),
        KV(t('prb.permit.obligation'), t('prb.obligation.${study.obligation}')),
        if (study.sources.isEmpty) _hint(t('prb.warn.permit_no_source'), color: Cad.attention),
        for (final w in study.warnings) _hint(permitWarningText(w, t.call, name: c.entityName), color: Cad.attention),
        for (final src in study.sources) ..._sourceFields(c, src, s.source(src.supply.id), setState),
      ];
    },
  );
}

List<Widget> _sourceFields(ProjectController c, PermitSource src, SourcePermitInfo info, StateSetter setState) {
  final t = c.t;
  final id = src.supply.id;
  final name = src.supply.name.isNotEmpty ? src.supply.name : '${t('tool.supply')} $id';
  return [
    SectionTitle('${t('prb.permit.point')}: $name'),
    _row([
      SpecDropdown<String>(
        key: Key('prb_permit_kind_$id'),
        label: t('prb.permit.kind'),
        value: info.kind,
        items: SourcePermitInfo.kinds,
        labelOf: (k) => t('prb.kind.$k'),
        idOf: (k) => k,
        onChanged: (v) => setState(() => info.kind = v ?? 'surface'),
      ),
      SpecDropdown<String>(
        label: t('prb.permit.status'),
        value: info.status,
        items: SourcePermitInfo.statuses,
        labelOf: (k) => t('prb.status.$k'),
        idOf: (k) => k,
        onChanged: (v) => setState(() => info.status = v ?? 'project'),
      ),
    ]),
    _row([
      TextFieldRow(key: Key('prb_permit_body_$id'), label: t('prb.permit.waterBody'), value: info.waterBody, onChanged: (v) => setState(() => info.waterBody = v.trim())),
      TextFieldRow(label: t('prb.permit.basin'), value: info.basin, onChanged: (v) => setState(() => info.basin = v.trim())),
    ]),
    _row([
      TextFieldRow(label: t('prb.permit.municipality'), value: info.municipality, onChanged: (v) => setState(() => info.municipality = v.trim())),
      TextFieldRow(label: t('prb.permit.registry'), value: info.registry, onChanged: (v) => setState(() => info.registry = v.trim())),
      TextFieldRow(label: t('prb.permit.number'), value: info.permitNumber, onChanged: (v) => setState(() => info.permitNumber = v.trim())),
    ]),
    KV(t('prb.permit.maxFlow'), '${fmt(src.maxFlowM3h, 1)} m³/h'),
    KV(t('prb.permit.annualVolume'), '${fmt(src.annualM3, 0)} m³'),
    KV(t('prb.permit.months'), [for (final m in src.months) t('prb.mon.$m')].join(', ')),
    if (src.lat != null) KV(t('prb.permit.lat'), permitDms(src.lat!, t('compass.n'), t('compass.s'))),
    if (src.lon != null) KV(t('prb.permit.lon'), permitDms(src.lon!, t('compass.e'), t('compass.w'))),
    for (final w in src.warnings)
      _hint(
        permitWarningText(w, t.call, src: src, s: c.project.deliverables.permit, name: c.entityName),
        color: w == 'permit_federal_floor' ? null : Cad.attention,
      ),
  ];
}

// ---------------------------------------------------------------- memorial (PRD-03)

/// Reports → Technical documents → Memorial: the objective and the closing
/// remarks of the designer; the rest is built from the project.
Future<void> showMemorialDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  return _documentDialog(
    context,
    c,
    title: t('prb.mem.title'),
    historyLabel: 'hist.prb.memorial',
    docKey: 'memorial',
    body: (setState) {
      final s = c.project.deliverables.memorial;
      return [
        _hint(t('prb.dlg.memHint')),
        if (c.results == null) _hint(t('prb.dlg.needDesign'), color: Cad.attention),
        TextFieldRow(key: const Key('prb_mem_objective'), label: t('prb.dlg.objective'), value: s.objective, maxLines: 4, onChanged: (v) => setState(() => s.objective = v.trim())),
        TextFieldRow(key: const Key('prb_mem_notes'), label: t('prb.dlg.notes'), value: s.notes, maxLines: 4, onChanged: (v) => setState(() => s.notes = v.trim())),
        _sections(c, buildMemorial(c.project, c.results, _labels(c))),
      ];
    },
  );
}

// ---------------------------------------------------------------- operation and maintenance (PRD-12)

/// Reports → Technical documents → Operation and maintenance plan: the
/// figures of the plan the project does not hold.
Future<void> showOmPlanDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final u = c.project.params.units;
  return _documentDialog(
    context,
    c,
    title: t('prb.om.title'),
    historyLabel: 'hist.prb.om',
    docKey: 'om',
    body: (setState) {
      final s = c.project.deliverables.om;
      return [
        _hint(t('prb.dlg.omHint')),
        if (c.results == null) _hint(t('prb.dlg.needDesign'), color: Cad.attention),
        _row([
          NumField(
            key: const Key('prb_om_filter'),
            label: '${t('prb.dlg.filterDelta')} (${u.pressureLabel})',
            value: u.pressureFromHead(s.filterDeltaM),
            onChanged: (v) => setState(() => s.filterDeltaM = u.pressureToHead(v).clamp(0.1, 50).toDouble()),
          ),
          NumField(key: const Key('prb_om_spares'), label: t('prb.dlg.spares'), value: s.sparesPct, decimals: 1, onChanged: (v) => setState(() => s.sparesPct = v.clamp(0, 100).toDouble())),
        ]),
        _row([
          NumField(label: t('prb.dlg.clProduct'), value: s.chlorineProductPct, decimals: 1, onChanged: (v) => setState(() => s.chlorineProductPct = v.clamp(0.1, 100).toDouble())),
          NumField(label: t('prb.dlg.clCont'), value: s.chlorineContinuousMgL, decimals: 1, onChanged: (v) => setState(() => s.chlorineContinuousMgL = v.clamp(0, 100).toDouble())),
          NumField(label: t('prb.dlg.clShock'), value: s.chlorineShockMgL, decimals: 1, onChanged: (v) => setState(() => s.chlorineShockMgL = v.clamp(0, 500).toDouble())),
        ]),
        _sections(c, buildOmPlan(c.project, c.results, _labels(c))),
      ];
    },
  );
}

// ---------------------------------------------------------------- budget by compositions (PRD-21)

/// Reports → Technical documents → Budget by compositions: the BDI, the
/// hourly costs and the period of the schedule.
Future<void> showBudgetDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final cur = c.project.params.currency;
  return _documentDialog(
    context,
    c,
    title: t('prb.bud.title'),
    historyLabel: 'hist.prb.budget',
    docKey: 'budget',
    body: (setState) {
      final p = c.project;
      final s = p.deliverables.budget;
      final b = buildBudget(p, c.results, describe: t.call);
      Widget pct(String label, double v, ValueChanged<double> apply, {Key? key}) => NumField(key: key, label: label, value: v, onChanged: (x) => setState(() => apply(x.clamp(0, 100).toDouble())));
      final out = !bdiWithin(b.servicesBdi, bdiReferenceRanges.services) || !bdiWithin(b.materialsBdi, bdiReferenceRanges.materials);
      return [
        _hint(t('prb.dlg.budHint')),
        SectionTitle(t('prb.dlg.bdiParts')),
        _row([
          pct(t('prb.bud.ac'), s.centralAdminPct, (v) => s.centralAdminPct = v, key: const Key('prb_bud_ac')),
          pct(t('prb.bud.sg'), s.insuranceGuaranteePct, (v) => s.insuranceGuaranteePct = v),
          pct(t('prb.bud.risk'), s.riskPct, (v) => s.riskPct = v),
        ]),
        _row([pct(t('prb.bud.df'), s.financialPct, (v) => s.financialPct = v), pct(t('prb.bud.profit'), s.profitPct, (v) => s.profitPct = v, key: const Key('prb_bud_profit'))]),
        SectionTitle(t('prb.dlg.taxes')),
        _row([
          pct(t('prb.bud.pis'), s.pisPct, (v) => s.pisPct = v),
          pct(t('prb.bud.cofins'), s.cofinsPct, (v) => s.cofinsPct = v),
          pct(t('prb.bud.iss'), s.issPct, (v) => s.issPct = v, key: const Key('prb_bud_iss')),
          pct(t('prb.bud.cprb'), s.cprbPct, (v) => s.cprbPct = v),
        ]),
        _switch(t('prb.dlg.matBdiSame'), s.materialsBdiPct < 0, (v) => setState(() => s.materialsBdiPct = v ? -1.0 : 11.10), key: const Key('prb_bud_same')),
        if (s.materialsBdiPct >= 0) pct(t('prb.dlg.matBdi'), s.materialsBdiPct, (v) => s.materialsBdiPct = v, key: const Key('prb_bud_matbdi')),
        KV(t('prb.bud.servicesBdi'), '${fmt(b.servicesBdi * 100, 2)} %', color: out ? Cad.attention : null),
        KV(t('prb.bud.materialsBdi'), '${fmt(b.materialsBdi * 100, 2)} %', color: out ? Cad.attention : null),
        if (out) _hint(t('prb.dlg.bdiOut'), color: Cad.attention),
        SectionTitle(t('prb.dlg.rates')),
        _row([
          for (final res in budgetResources)
            NumField(
              key: Key('prb_bud_rate_${res.key}'),
              label: '${t('prb.res.${res.key}')} ($cur/h)',
              value: budgetHourlyCost(p, res),
              onChanged: (v) => setState(() => s.rates[res.key] = math.max(0.0, v)),
            ),
        ], minWidth: 170),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: const Key('prb_bud_reset'),
            onPressed: s.rates.isEmpty ? null : () => setState(s.rates.clear),
            icon: const Icon(Icons.restart_alt, size: 16),
            label: Text(t('prb.dlg.resetRates'), style: const TextStyle(fontSize: 12)),
          ),
        ),
        SpecDropdown<int>(
          label: t('prb.dlg.period'),
          value: '${s.periodDays}',
          items: const [5, 22],
          labelOf: (d) => t(d == 5 ? 'prb.dlg.periodWeek' : 'prb.dlg.periodMonth'),
          idOf: (d) => '$d',
          onChanged: (v) => setState(() => s.periodDays = int.tryParse(v ?? '') ?? 22),
        ),
        SectionTitle(t('prb.bud.summary')),
        KV(t('prb.bud.servicesPrice'), '$cur ${fmt(b.servicesPrice, 2)}'),
        KV(t('prb.bud.materialsPrice'), '$cur ${fmt(b.materialsPrice, 2)}'),
        KV(t('prb.bud.total'), '$cur ${fmt(b.total, 2)}', color: Cad.positive),
        KV(t('prb.bud.duration'), t('works.daysN', {'n': '${b.durationDays}'})),
        if (b.materials.isEmpty) _hint(t('prb.bud.noMaterials'), color: Cad.attention),
      ];
    },
  );
}

// ---------------------------------------------------------------- life-cycle cost (PRD-20)

/// Reports → Technical documents → Life-cycle cost: the horizon and the
/// rates of the study, the life and maintenance of every category, and the
/// comparison of the current design with the alternatives saved.
Future<void> showLifeCycleDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final cur = c.project.params.currency;
  return _documentDialog(
    context,
    c,
    title: t('prb.lcc.title'),
    historyLabel: 'hist.prb.lcc',
    docKey: 'lcc',
    body: (setState) {
      final p = c.project;
      final s = p.deliverables.lifeCycle;
      final st = buildLifeCycleStudy(p, c.results, currentName: t('prb.lcc.current'));
      final best = st.best;
      final cats = {...lifeCycleReference.keys, for (final a in st.alternatives) ...a.items.map((i) => i.category)}.toList();
      return [
        _hint(t('prb.dlg.lccHint')),
        _row([
          NumField(key: const Key('prb_lcc_years'), label: t('prb.dlg.years'), value: s.years.toDouble(), decimals: 0, onChanged: (v) => setState(() => s.years = v.round().clamp(1, 100))),
          NumField(
            key: const Key('prb_lcc_escalation'),
            label: t('prb.dlg.escalation'),
            value: s.energyEscalationPct,
            decimals: 1,
            onChanged: (v) => setState(() => s.energyEscalationPct = v.clamp(-50, 50).toDouble()),
          ),
          NumField(key: const Key('prb_lcc_water'), label: t('prb.dlg.waterPrice', {'c': cur}), value: s.waterPrice, decimals: 3, onChanged: (v) => setState(() => s.waterPrice = math.max(0.0, v))),
        ]),
        _switch(t('prb.dlg.rateFromParams'), s.discountPct == null, (v) => setState(() => s.discountPct = v ? null : p.params.interestRate * 100), key: const Key('prb_lcc_rate_params')),
        if (s.discountPct != null)
          NumField(key: const Key('prb_lcc_rate'), label: t('prb.dlg.rate'), value: s.discountPct!, decimals: 2, onChanged: (v) => setState(() => s.discountPct = v.clamp(0, 100).toDouble())),
        _switch(t('prb.dlg.residual'), s.residual, (v) => setState(() => s.residual = v), key: const Key('prb_lcc_residual')),
        ExpansionTile(
          key: const Key('prb_lcc_categories'),
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: Text(t('prb.dlg.categories'), style: const TextStyle(fontSize: 12.5)),
          children: [
            for (final cat in cats)
              _row([
                NumField(
                  label: '${cat == 'other' ? t('prb.lcc.other') : _labels(c).category(cat)} — ${t('prb.lcc.life')} (${t('prb.lcc.years')})',
                  value: lifeCycleOf(p, cat).$1,
                  decimals: 0,
                  onChanged: (v) => setState(() => s.life[cat] = v.clamp(1, 100).toDouble()),
                ),
                NumField(label: '${t('prb.lcc.maintPct')} (%)', value: lifeCycleOf(p, cat).$2, decimals: 1, onChanged: (v) => setState(() => s.maintenance[cat] = v.clamp(0, 100).toDouble())),
              ], minWidth: 170),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const Key('prb_lcc_reset'),
                onPressed: s.life.isEmpty && s.maintenance.isEmpty
                    ? null
                    : () => setState(() {
                        s.life.clear();
                        s.maintenance.clear();
                      }),
                icon: const Icon(Icons.restart_alt, size: 16),
                label: Text(t('prb.dlg.reset'), style: const TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
        SectionTitle(t('prb.dlg.alternatives')),
        if (st.alternatives.isEmpty) _hint(t('prb.lcc.none'), color: Cad.attention),
        for (final a in st.alternatives)
          KV(
            a.approximate ? '${a.name} *' : a.name,
            'LCC $cur ${fmt(a.lcc, 0)} · ${t('prb.lcc.eac')} $cur ${fmt(a.eac, 0)}${a.areaHa > 0 ? ' · $cur ${fmt(a.perHaYear, 0)}/ha' : ''}',
            color: identical(a, best) && st.alternatives.length > 1 ? Cad.positive : null,
          ),
        if (st.alternatives.any((a) => a.approximate)) _hint(t('prb.lcc.approximate')),
      ];
    },
  );
}
