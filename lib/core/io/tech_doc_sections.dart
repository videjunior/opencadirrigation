/// The technical documents of 1.6.0 PRB (the water permit table, the
/// descriptive and calculation memorial, the operation and maintenance
/// plan, the budget by compositions and the life-cycle cost) as sections of
/// the document packages (doc_package.dart). Each section builds its
/// document as its own export does (tech_doc.dart) and turns every section
/// of it into a sub-heading of the package ("3.1") followed by its
/// paragraphs, fields, formulas, notes and tables.
///
/// Places: the permit table after the abstraction points of the permit
/// package (225); the memorial after the identification of the memorial
/// package (160, without its own identification: the cover and the first
/// section have it), offered in the permit package; the operation and
/// maintenance plan after the summary of the operation package (160); the
/// budget after the quote (410) and the life-cycle cost after the works
/// schedule (460) of the proposal, both offered but not ticked (the quote
/// stays the one price of a proposal), the life-cycle cost also offered in
/// the memorial (650).
library;

import '../design/budget.dart';
import '../design/life_cycle.dart';
import '../design/memorial.dart';
import '../design/om_plan.dart';
import '../design/permit.dart';
import 'doc_package.dart';
import 'tech_doc.dart';

const _p = DocProfile.proposal, _l = DocProfile.permit, _m = DocProfile.memorial, _o = DocProfile.operation;

/// The blocks of [doc] in a package section: each of its sections (but
/// those whose [TechSection.key] is in [skip]) as a sub-heading, a
/// sub-section as a bold line, followed by its content.
List<DocBlock> techDocumentBlocks(TechDocument doc, {Set<String> skip = const {}}) => [
  for (final s in doc.sections)
    if (!skip.contains(s.key)) ...[if (s.level <= 1) DocHeading(s.title) else DocParagraph(s.title, bold: true), for (final b in s.blocks) ..._docBlocks(b)],
];

/// [b] as blocks of a package: a formula is its expression in bold, the
/// meaning of its symbols and its source in grey; a note that needs action
/// is bold, the others grey.
List<DocBlock> _docBlocks(TechBlock b) => switch (b) {
  TechParagraph x => [DocParagraph(x.text)],
  TechBullets x when x.numbered => [for (var i = 0; i < x.items.length; i++) DocParagraph('${i + 1}. ${x.items[i]}')],
  TechBullets x => [DocBullets(x.items)],
  TechFields x => [DocFields(x.rows)],
  TechFormula x => [DocParagraph(x.expression, bold: true), if (x.where.isNotEmpty) DocFields(x.where), if (x.source.isNotEmpty) DocNote(x.source)],
  TechNote x => [if (x.warning) DocParagraph(x.text, bold: true) else DocNote(x.text)],
  TechTable x => [DocTable(x.table), if (x.note.isNotEmpty) DocNote(x.note)],
};

// the studies a section needs both to say whether it can be made and to make it, once per package
final _permits = Expando<PermitStudy>('prb.permit');
final _budgets = Expando<Budget>('prb.budget');
final _lifeCycles = Expando<LifeCycleStudy>('prb.lcc');

PermitStudy _permit(DocContext c) => _permits[c] ??= buildPermitStudy(c.project, c.results, cropName: c.labels.category);

Budget _budget(DocContext c) => _budgets[c] ??= buildBudget(c.project, c.results, describe: c.t);

LifeCycleStudy _lifeCycle(DocContext c) => _lifeCycles[c] ??= buildLifeCycleStudy(c.project, c.results, currentName: c.t('prb.lcc.current'));

/// The name of entity [id] as the reports write it (its own, else the id).
String _entityName(DocContext c, String id) {
  final n = c.project.byId(id)?.name ?? '';
  return n.isEmpty ? c.labels.name(id) : n;
}

/// The sections of the area PRB in the document packages (joined in
/// [documentSections]).
final prbDocumentSections = <DocSection>[
  DocSection(
    id: 'prb.permit',
    titleKey: 'prb.permit.title',
    profiles: const {_l: 225},
    available: (c) => _permit(c).sources.isNotEmpty,
    landscape: true,
    build: (c) => techDocumentBlocks(permitDocument(c.project, _permit(c), c.t, entityName: (id) => _entityName(c, id))),
  ),
  DocSection(
    id: 'prb.memorial',
    titleKey: 'prb.mem.title',
    profiles: const {_m: 160, _l: 230},
    optional: const {_l},
    build: (c) => techDocumentBlocks(buildMemorial(c.project, c.results, c.labels), skip: const {'identification'}),
  ),
  DocSection(id: 'prb.om', titleKey: 'prb.om.title', profiles: const {_o: 160}, build: (c) => techDocumentBlocks(buildOmPlan(c.project, c.results, c.labels))),
  DocSection(
    id: 'prb.budget',
    titleKey: 'prb.bud.title',
    profiles: const {_p: 410},
    optional: const {_p},
    available: (c) => _budget(c).services.isNotEmpty || _budget(c).materials.isNotEmpty,
    landscape: true,
    build: (c) => techDocumentBlocks(budgetDocument(c.project, _budget(c), c.labels)),
  ),
  DocSection(
    id: 'prb.lcc',
    titleKey: 'prb.lcc.title',
    profiles: const {_p: 460, _m: 650},
    optional: const {_p, _m},
    available: (c) => _lifeCycle(c).alternatives.isNotEmpty,
    landscape: true,
    build: (c) => techDocumentBlocks(lifeCycleDocument(c.project, _lifeCycle(c), c.labels)),
  ),
];
