/// Operations (find_operations / run_operation) added in 1.6.0 for deliverables (title block, sheets, document packages):
/// [OpTool]s built like those of lib/app/ai/ops_cad_*.dart and ops_eng_*.dart,
/// joined to [AgentToolbox.operations].
/// - get_title_block / set_title_block: File → Title block (company and
///   logo, technical lead, council, registration, ART/RRT/TRT, CAR, water
///   permit, municipality, stage, drawing number, date of issue, revisions;
///   the user's defaults for new projects);
/// - set_datum: the datum of the georeference (File → Georeference);
/// - list_document_packages / export_document_package: File → Export
///   document package (the readers' PDFs with cover, contents and
///   signature).
/// The coordinate grid and the thematic terrain sheets of the PDF are
/// options of export_sheet_pdf (ops_eng_exports.dart); the slope by
/// irrigated area is the report table "slopeClasses" (get_report_table).
library;

import '../../../core/ai/agent_loop.dart';
import '../../../core/io/datum.dart' show GeodeticDatum, projectDatumLabel, projectDatums;
import '../../../core/io/doc_package.dart';
import '../../../core/io/doc_pdf.dart';
import '../../../core/io/doc_sections.dart' show docSheetOptions;
import '../../../core/io/pdf_sheet.dart' show PageSize;
import '../../../core/model/title_block.dart';
import '../../actions.dart' show pdfTexts;
import '../../io/pdf_font_loader.dart';
import '../../io/sheet_basemap.dart';
import '../../state/controller.dart' show BaseMap;
import '../../widgets/dialogs/document_package_dialog.dart' show documentContextOf, documentPackageFileName;
import '../../widgets/dialogs/title_block_dialog.dart' show nextTitleRevision, saveTitleBlockDefaults, setTitleBlockLogo, titleBlockDefaults;
import '../agent_tools.dart';
import '../agent_tools_ops.dart';
import '../ops_eng_common.dart' show engFileSink;
import '../vision_render.dart' show CanvasSnapshots;
import '../vision_tiles.dart' show HttpTileFetcher;

/// An operation of this area: the approval line is `ai.op.<name>`.
OpTool _op(
  AgentToolbox b, {
  required String group,
  required String name,
  required String description,
  required Map<String, Object?> schema,
  ToolEffect effect = ToolEffect.read,
  required Future<ToolOutput> Function(ToolArgs a) run,
}) => OpTool(group: group, name: name, description: description, inputSchema: schema, effect: effect, summary: (_) => b.t('ai.op.$name'), handler: (i) => run(ToolArgs(i)));

/// The title block of [b]'s project as text for the model.
String _titleBlockText(AgentToolbox b) {
  final m = b.p.meta, tb = m.titleBlock;
  String v(String s) => s.trim().isEmpty ? '-' : '"${s.trim()}"';
  String rev(TitleRevision r) => '${r.revision} ${r.date} "${r.description}"${r.author.isEmpty ? '' : ' by ${r.author}'}';
  final lines = [
    'Sheets print the ${tb.isProfessional ? 'professional title block (cells of project, records, technical lead, sheet and company)' : 'plain title block (nothing of the professional one is set)'}.',
    'client ${v(m.client)}; property ${v(m.site)}; designer ${v(m.designer)} (project details, also set here)',
    'company ${v(tb.company)}; logo ${tb.logo == null ? 'none' : '${tb.logoMime} ${(tb.logo!.length / 1024).toStringAsFixed(0)} KB'}',
    'responsible ${v(tb.responsible)}; council ${v(tb.council)}; registration ${v(tb.registration)}; record (${tb.recordName}) ${v(tb.responsibilityRecord)}',
    'car ${v(tb.car)}; water_permit ${v(tb.waterPermit)}; municipality ${v(tb.municipality)}',
    'stage ${tb.stage.name}; drawing_number ${v(tb.drawingNumber)}; issue_date ${v(tb.issueDate)}${tb.issueDate.isNotEmpty && tb.issued == null ? ' (not a date: the sheets use today)' : ''}',
    tb.revisions.isEmpty ? 'revisions: none' : 'revisions (oldest first): ${tb.revisions.map(rev).join('; ')}',
    'The user\'s saved defaults for new projects: ${titleBlockDefaults() == null ? 'none' : 'saved (fill_from_defaults fills the empty company, logo, responsible, council and registration)'}.',
  ];
  return lines.join('\n');
}

List<AgentTool> opsPrd(AgentToolbox b) {
  final c = b.c;
  final t = b.t;
  return [
    _op(
      b,
      group: 'documents',
      name: 'get_title_block',
      description:
          'Reads the professional title block of the sheets and of the covers of the document packages (File → Title block): company and logo, technical lead, professional council (CREA, CAU, CFTA, CFT or another) and registration, the number of the record of technical responsibility (ART at CREA, RRT at CAU, TRT at CFTA/CFT), CAR, water permit (outorga), municipality/state, stage, drawing number, date of issue and the revision table, with the client, property and designer of the project details. Read-only.',
      schema: obj({}),
      run: (a) async => ToolOutput(_titleBlockText(b)),
    ),
    _op(
      b,
      group: 'documents',
      name: 'set_title_block',
      effect: ToolEffect.write,
      description:
          'Changes the title block of the sheets and covers (File → Title block), only the fields given: client, property (the site of the project details), designer, company, responsible (the technical lead who signs), council (CREA, CAU, CFTA, CFT or another body), registration (number with the state, e.g. "SP 5060123456"), record (the ART/RRT/TRT number), car, water_permit, municipality ("Uberaba/MG"), stage, drawing_number (sheet n of a set prints as "<number>-0n"), issue_date (YYYY-MM-DD; "" = the day of export), revisions (replaces the table: [{revision, date, description, by}]), add_revision ({revision default the next one, date default today, description, by}), logo_attachment (the file name of a picture the user attached: PNG or JPEG, scaled to 512 px), remove_logo, fill_from_defaults (fills the empty company, logo, responsible, council and registration from the user\'s saved defaults), save_as_defaults (keeps company, logo, responsible, council and registration in this browser for new projects; not a change of the project). Empty text clears a field. One undo step; the design results stay.',
      schema: obj({
        'client': str(),
        'property': str(),
        'designer': str(),
        'company': str(),
        'responsible': str(),
        'council': str(),
        'registration': str(),
        'record': str('Number of the ART, RRT or TRT.'),
        'car': str(),
        'water_permit': str(),
        'municipality': str(),
        'stage': str(null, [for (final s in ProjectStage.values) s.name]),
        'drawing_number': str(),
        'issue_date': str('YYYY-MM-DD or DD/MM/YYYY; "" for the day of export.'),
        'revisions': arr(obj({'revision': str(), 'date': str(), 'description': str(), 'by': str()}), 'Replaces the revision table, oldest first.', 50),
        'add_revision': obj({'revision': str(), 'date': str(), 'description': str(), 'by': str()}),
        'logo_attachment': str('File name of an attached picture.'),
        'remove_logo': bool_(),
        'fill_from_defaults': bool_(),
        'save_as_defaults': bool_(),
      }),
      run: (a) async {
        final changes = <String>[];
        // the picture first, so a wrong file changes nothing
        final logoName = a.str('logo_attachment');
        final files = b.host?.files ?? const {};
        final logoBytes = logoName == null ? null : (files[logoName] ?? files.entries.where((e) => e.key.toLowerCase() == logoName.toLowerCase()).firstOrNull?.value);
        if (logoName != null && logoBytes == null) throw ToolInputError('No file "$logoName" is attached in this conversation. Attached: ${files.keys.isEmpty ? 'none' : files.keys.join(', ')}.');
        final stage = a.str('stage');
        if (stage != null && !ProjectStage.values.any((s) => s.name == stage)) throw ToolInputError('"stage" is one of ${ProjectStage.values.map((s) => s.name).join(', ')}.');
        final date = a.str('issue_date');
        if (date != null && date.isNotEmpty && parseTitleDate(date) == null) throw ToolInputError('"issue_date" must be YYYY-MM-DD or DD/MM/YYYY.');
        final defaults = (a.flag('fill_from_defaults') ?? false) ? titleBlockDefaults() : null;
        if ((a.flag('fill_from_defaults') ?? false) && defaults == null) throw ToolInputError('The user has saved no defaults (File → Title block → Save as my defaults).');
        String field(Map r, String k) => '${r[k] ?? ''}'.trim();
        final rawRevisions = a.input['revisions'];
        final revisions = rawRevisions is List
            ? [
                for (final r in rawRevisions)
                  if (r is Map) TitleRevision(revision: field(r, 'revision'), date: field(r, 'date'), description: field(r, 'description'), author: field(r, 'by')),
              ]
            : null;
        final add = a.input['add_revision'];
        final project = a.has('client') || a.has('property') || a.has('designer');
        final fields = {'company', 'responsible', 'council', 'registration', 'record', 'car', 'water_permit', 'municipality', 'stage', 'drawing_number', 'issue_date'}.any(a.has);
        final edits = project || fields || revisions != null || add is Map || logoBytes != null || (a.flag('remove_logo') ?? false) || defaults != null;
        if (edits) {
          b.change('set_title_block', () {
            final m = b.p.meta, tb = m.titleBlock;
            void take(String key, void Function(String v) apply) {
              final v = a.str(key);
              if (v == null) return;
              apply(v);
              changes.add(key);
            }

            take('client', (v) => m.client = v);
            take('property', (v) => m.site = v);
            take('designer', (v) => m.designer = v);
            take('company', (v) => tb.company = v);
            take('responsible', (v) => tb.responsible = v);
            take('council', (v) => tb.council = v);
            take('registration', (v) => tb.registration = v);
            take('record', (v) => tb.responsibilityRecord = v);
            take('car', (v) => tb.car = v);
            take('water_permit', (v) => tb.waterPermit = v);
            take('municipality', (v) => tb.municipality = v);
            take('drawing_number', (v) => tb.drawingNumber = v);
            take('issue_date', (v) {
              final d = parseTitleDate(v);
              tb.issueDate = d == null ? '' : titleDateText(d);
            });
            if (stage != null) {
              tb.stage = ProjectStage.values.byName(stage);
              changes.add('stage');
            }
            if (revisions != null) {
              tb.revisions
                ..clear()
                ..addAll(revisions);
              changes.add('revisions');
            }
            if (add is Map) {
              final revision = field(add, 'revision'), date = field(add, 'date');
              tb.revisions.add(
                TitleRevision(
                  revision: revision.isEmpty ? nextTitleRevision(tb) : revision,
                  date: date.isEmpty ? titleDateText(DateTime.now()) : date,
                  description: field(add, 'description'),
                  author: field(add, 'by'),
                ),
              );
              changes.add('add_revision');
            }
            if (a.flag('remove_logo') ?? false) {
              tb.logo = null;
              changes.add('remove_logo');
            }
            if (logoBytes != null) {
              if (!setTitleBlockLogo(tb, logoBytes)) throw ToolInputError('"$logoName" is not a picture the program reads (PNG or JPEG).');
              changes.add('logo');
            }
            if (defaults != null) {
              tb.adoptOwner(defaults);
              changes.add('fill_from_defaults');
            }
            return true;
          }, invalidate: false);
        }
        if (a.flag('save_as_defaults') ?? false) {
          saveTitleBlockDefaults(b.p.meta.titleBlock);
          changes.add('save_as_defaults');
        }
        if (changes.isEmpty) return const ToolOutput('Nothing to change: give the fields to set.');
        return ToolOutput('Set ${changes.join(', ')}.\n${_titleBlockText(b)}');
      },
    ),
    _op(
      b,
      group: 'site',
      name: 'set_datum',
      effect: ToolEffect.write,
      description:
          'Names the datum of the georeference (File → Georeference → Datum): "auto" (by the site: SIRGAS 2000 in South and Central America, ETRS89 in Europe, WGS84 elsewhere), "sirgas2000", "wgs84", "etrs89" or "nad83". They agree at the accuracy of a project map, so no coordinate moves: the datum names the coordinates on the sheets (title block, grid) and in the SHP, LandXML, IFC and EPANET files. Needs a georeference (set_site). One undo step.',
      schema: obj({
        'datum': str(null, ['auto', for (final d in projectDatums) d.name]),
      }, required: ['datum']),
      run: (a) async {
        final g = b.p.meta.georef;
        if (g == null) throw ToolInputError('The project has no georeference: set_site first.');
        final name = a.str('datum', required: true)!;
        final GeodeticDatum? d = name == 'auto' ? null : projectDatums.where((x) => x.name == name).firstOrNull;
        if (name != 'auto' && d == null) throw ToolInputError('"datum" is one of auto, ${projectDatums.map((x) => x.name).join(', ')}.');
        b.change('set_datum', () {
          b.p.meta.georef = g.withDatum(d);
          return true;
        }, invalidate: false);
        final now = b.p.meta.georef!;
        final named = d == null ? 'by the site: ${projectDatumLabel(now.effectiveDatum)}' : projectDatumLabel(d);
        return ToolOutput('Datum $named; coordinates ${now.crsName}${now.epsg == null ? '' : ' (EPSG:${now.epsg})'}.');
      },
    ),
    _op(
      b,
      group: 'documents',
      name: 'list_document_packages',
      description:
          'Lists the document packages of File → Export document package — proposal (to the client), permit (water permit and licensing), installation, memorial (technical report), operation (operation and maintenance) — with their sections in order: id, title, whether it is in the package by default or optional, and whether the project can make it now (some need the design results or data such as terrain, pivots or wiring). Read-only.',
      schema: obj({
        'profile': str('Only this package.', [for (final p in DocProfile.values) p.name]),
      }),
      run: (a) async {
        final only = a.str('profile');
        final out = StringBuffer();
        for (final p in DocProfile.values) {
          if (only != null && p.name != only) continue;
          final ctx = documentContextOf(c, p);
          out.writeln('${p.name} — ${docProfileTitle(t, p)}:');
          for (final s in profileSections(p)) {
            final state = s.canBuild(ctx) ? 'available' : (s.needsResults && c.results == null ? 'needs the design results' : 'no data in the project');
            out.writeln('  ${s.id} | ${t(s.titleKey)} | ${s.optional.contains(p) ? 'optional' : 'default'} | $state');
          }
        }
        out.write('The cover takes the title block (get_title_block). export_document_package makes the PDF.');
        return ToolOutput(out.toString());
      },
    ),
    _op(
      b,
      group: 'documents',
      name: 'export_document_package',
      effect: ToolEffect.export,
      description:
          'File → Export document package: one PDF for one reader — proposal, permit, installation, memorial or operation (list_document_packages gives their sections) — with a cover from the title block (logo, company, client, property, technical lead, records), contents, numbered sections with the report tables and the standards of their criteria, the drawing sheets on their own paper (the permit with the slope sheet and the coordinate grid, the installation with a sheet per zone and the construction details) and the signature block (with the client\'s acceptance in a proposal). Inputs: profile, sections (ids; default the package\'s own), title (the cover\'s; default the package\'s name), recipient (who it is addressed to), sheet_page (paper of the drawings, default a3), base_map (the base map shown on screen under the sheets; default true when there is one). Always confirmed by the user (a download).',
      schema: obj({
        'profile': str(null, [for (final p in DocProfile.values) p.name]),
        'sections': arr(str(), 'Section ids (list_document_packages).', 40),
        'title': str(),
        'recipient': str(),
        'sheet_page': str(null, [for (final p in PageSize.values) p.name]),
        'base_map': bool_(),
      }, required: ['profile']),
      run: (a) async {
        if (b.p.entities.isEmpty) throw ToolInputError(t('msg.nothingToExport'));
        final p = DocProfile.values.byName(a.str('profile', required: true)!);
        final ids = a.has('sections') ? a.strings('sections') : null;
        final unknown = [
          for (final id in ids ?? const <String>[])
            if (documentSection(id) == null) id,
        ];
        if (unknown.isNotEmpty) throw ToolInputError('No section ${unknown.join(', ')}: list_document_packages gives the ids.');
        final page = PageSize.values.byName(a.str('sheet_page') ?? 'a3');
        final o = DocPackageOptions(profile: p, sections: ids, title: a.str('title') ?? '', recipient: a.str('recipient') ?? '');
        var ctx = documentContextOf(c, p, page: page);
        final sections = packageSections(ctx, o);
        if (sections.isEmpty) throw ToolInputError('None of those sections can be made for this project (list_document_packages says why).');
        final mapAvailable = b.p.meta.georef != null && c.baseMap != BaseMap.none && c.baseMapSnapshot != null;
        if ((a.flag('base_map') ?? true) && mapAvailable && sections.any((s) => s.id == 'prd.sheets')) {
          final snaps = b.snapshots;
          ctx = documentContextOf(c, p, page: page, withMap: await withSheetBaseMap(c, docSheetOptions(ctx), fetcher: snaps is CanvasSnapshots ? snaps.tiles : const HttpTileFetcher()));
        }
        await preparePdfFonts([...pdfTexts(c, reports: true), o.title, o.recipient], language: c.lang);
        final pack = buildDocumentPackage(ctx, o);
        final name = documentPackageFileName(c, p);
        await engFileSink(c, name, 'application/pdf', pack.bytes);
        return ToolOutput('Exported $name: ${pack.pageCount} pages; sections ${[for (final s in pack.sections) t(s.titleKey)].join(', ')}.');
      },
    ),
  ];
}
