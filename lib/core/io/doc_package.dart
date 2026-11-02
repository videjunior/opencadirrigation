/// Document packages by reader (1.6.0 PRD, PRD-04): one PDF for each person
/// the project goes to, instead of every table at once. A package has a
/// cover (the title block's logo, company, client, property, technical
/// lead and records), a table of contents, numbered sections with page
/// headers and numbers, the drawing sheets where the reader needs them,
/// and the signature of the technical lead (and the client's acceptance in
/// a proposal). The packages ([DocProfile]):
/// - proposal to the client: the system in brief, the scope (bill of
///   materials), the quote and its terms, the works schedule, the plan;
/// - water permit and licensing: the site and its records (CAR, permit),
///   the abstraction points in SIRGAS 2000 / UTM and degrees, the water
///   requirement, the licensing category, the slope, the plan and the
///   slope sheet;
/// - installation: the sheets of every zone with the construction details,
///   the pressures to check, the bill of materials by zone, the wiring,
///   flushing and the schedule;
/// - technical memorial: the criteria and their standards, the hydraulic
///   design, the checks, the charts and every sheet;
/// - operation and maintenance: what the operator runs and checks.
///
/// ## Sections: how other parts of the program add theirs
/// A package is made of [DocSection]s. Each says which packages it belongs
/// to and where ([DocSection.profiles]: package → place, smaller first),
/// whether it needs the design results and how it is built: a function of
/// the [DocContext] (the project, results, report tables, translations,
/// the sheet builder) that returns [DocBlock]s — headings, paragraphs,
/// fields, report tables, charts, drawing sheets, notes. The writer
/// (doc_pdf.dart) numbers them, lists them in the contents and paginates.
///
/// The built-in sections are in doc_sections.dart ([prdDocumentSections]).
/// To add sections from another part of the program, either
/// - append a list of them in [documentSections] (the integrator adds
///   `...prbDocumentSections` there: the order of the packages comes from
///   the places, not from the list), or
/// - call [registerDocumentSection] once at start-up (a section with the id
///   of another replaces it).
/// Ids are namespaced by area (`prd.quote`, `prb.memorial`…); places run
/// from 100 (identification) to 990 (signature), with gaps of 10 or more so
/// a section can go between two others. The texts of a section are i18n
/// keys of its area ([DocSection.titleKey]).
library;

import '../design/report_tables.dart';
import '../design/results.dart';
import '../model/project.dart';
import '../translate.dart';
import '../units.dart';
import 'doc_sections.dart';
import 'fonts/pdf_fonts.dart';
import 'pdf_sheet.dart';
import 'plot.dart' show PlotRaster;
import 'plot_charts.dart' show PlotChart;

/// Who a document package is written for.
enum DocProfile { proposal, permit, installation, memorial, operation }

/// A piece of a section, laid out by the writer.
sealed class DocBlock {
  const DocBlock();
}

/// A sub-heading of a section (numbered "2.1" and listed in the contents).
class DocHeading extends DocBlock {
  const DocHeading(this.text);
  final String text;
}

/// A paragraph of text (wrapped to the page).
class DocParagraph extends DocBlock {
  const DocParagraph(this.text, {this.bold = false});
  final String text;
  final bool bold;
}

/// Labelled values in two columns ("Client: …"); pairs with an empty value
/// are left out.
class DocFields extends DocBlock {
  const DocFields(this.fields);
  final List<(String, String)> fields;
}

/// A list of items with bullets.
class DocBullets extends DocBlock {
  const DocBullets(this.items);
  final List<String> items;
}

/// A report table (paginated, its header repeated), with the standards of
/// its criteria under its title when [standards].
class DocTable extends DocBlock {
  const DocTable(this.table, {this.standards = true});
  final ReportTable table;
  final bool standards;
}

/// A chart (grade line, profile, pump curve) across the page.
class DocChart extends DocBlock {
  const DocChart(this.chart);
  final PlotChart chart;
}

/// Drawing sheets (and detail and thematic sheets) of [options], each on a
/// page of its own paper size, with its own title block.
class DocSheets extends DocBlock {
  const DocSheets(this.options);
  final SheetOptions options;
}

/// A small note in grey.
class DocNote extends DocBlock {
  const DocNote(this.text);
  final String text;
}

/// The signature of the technical lead (name, council and registration,
/// record of responsibility, place and date), and the client's acceptance
/// when [client].
class DocSignature extends DocBlock {
  const DocSignature({this.client = false});
  final bool client;
}

/// What follows starts on a new page.
class DocPageBreak extends DocBlock {
  const DocPageBreak();
}

/// What a section is built from.
class DocContext {
  DocContext({
    required this.project,
    this.results,
    required this.labels,
    this.profile = DocProfile.memorial,
    this.layerNames = const {},
    this.unconnected = const {},
    this.fonts,
    DateTime? date,
    this.rasters = const [],
    this.attribution = '',
    this.sheetPage = PageSize.a3,
  }) : date = date ?? DateTime.now();
  final Project project;
  final DesignResults? results;
  final ReportLabels labels;
  final DocProfile profile;
  final Map<String, String> layerNames;
  final Set<String> unconnected;
  final PdfFonts? fonts;

  /// The date the package is issued (the cover, the signature).
  final DateTime date;

  /// The base map under the drawing sheets (the plot dialog's), and its credit.
  final List<PlotRaster> rasters;
  final String attribution;

  /// Paper of the drawing sheets.
  final PageSize sheetPage;

  Translate get t => labels.t;
  Units get units => project.params.units;

  /// The report tables of the project (as the reports show them).
  late final List<ReportTable> tables = buildReportTables(project: project, results: results, labels: labels, unconnected: unconnected);

  /// The report table [key] when it has rows, else null.
  ReportTable? table(String key) {
    for (final tb in tables) {
      if (tb.key == key) return tb.isEmpty ? null : tb;
    }
    return null;
  }

  /// The tables of [keys] that have rows, as blocks.
  List<DocBlock> tablesOf(Iterable<String> keys) => [
    for (final k in keys)
      if (table(k) case final tb?) DocTable(tb),
  ];

  /// The sheet builder of the project (its sheets and charts).
  late final PdfSheetBuilder sheets = PdfSheetBuilder(project: project, results: results, t: t, layerNames: layerNames, units: units, fonts: fonts);
}

/// A section of the document packages (see the library comment).
class DocSection {
  const DocSection({
    required this.id,
    required this.titleKey,
    required this.profiles,
    required this.build,
    this.needsResults = false,
    this.available,
    this.landscape = false,
    this.optional = const {},
  });

  /// Unique, namespaced by area ("prd.quote").
  final String id;

  /// i18n key of its heading.
  final String titleKey;

  /// The packages it belongs to, each with its place in that package
  /// (smaller first).
  final Map<DocProfile, int> profiles;

  /// Its content.
  final List<DocBlock> Function(DocContext ctx) build;

  /// Needs the design results (offered but not available without them).
  final bool needsResults;

  /// Whether the project has what it shows (null: always).
  final bool Function(DocContext ctx)? available;

  /// Its pages in landscape (wide tables).
  final bool landscape;

  /// Packages where it is offered but left out until the user ticks it.
  final Set<DocProfile> optional;

  /// Whether it can be made for [ctx].
  bool canBuild(DocContext ctx) => (!needsResults || ctx.results != null) && (available?.call(ctx) ?? true);
}

/// Sections registered at run time ([registerDocumentSection]).
final List<DocSection> _registered = [];

/// Adds [s] to the sections of the packages (one with the same id is
/// replaced).
void registerDocumentSection(DocSection s) {
  _registered
    ..removeWhere((x) => x.id == s.id)
    ..add(s);
}

/// Removes the registered section [id] (tests).
void unregisterDocumentSection(String id) => _registered.removeWhere((x) => x.id == id);

/// Every section of the packages: the built-in ones, the lists of the other
/// parts of the program, then the registered ones; a later one with the id
/// of an earlier one replaces it.
List<DocSection> documentSections() {
  final byId = <String, DocSection>{};
  for (final s in [
    ...prdDocumentSections,
    // the sections of the other areas join here (see the library comment)
    ..._registered,
  ]) {
    byId[s.id] = s;
  }
  return byId.values.toList();
}

/// The sections of package [p], in their order.
List<DocSection> profileSections(DocProfile p) {
  final out = [
    for (final s in documentSections())
      if (s.profiles.containsKey(p)) s,
  ];
  out.sort((a, b) {
    final c = a.profiles[p]!.compareTo(b.profiles[p]!);
    return c != 0 ? c : a.id.compareTo(b.id);
  });
  return out;
}

/// The sections of package [p] ticked when the dialog opens: those not
/// [DocSection.optional] there that [ctx] can build.
List<String> defaultSectionIds(DocProfile p, DocContext ctx) => [
  for (final s in profileSections(p))
    if (!s.optional.contains(p) && s.canBuild(ctx)) s.id,
];

/// The section [id], or null.
DocSection? documentSection(String id) {
  for (final s in documentSections()) {
    if (s.id == id) return s;
  }
  return null;
}
