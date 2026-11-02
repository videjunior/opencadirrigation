/// File → Export document package (1.6.0 PRD, PRD-04): one PDF for the
/// reader it is written for — the client's proposal, the water permit and
/// licensing, the installation package, the technical memorial, the
/// operation and maintenance — with a cover, contents, numbered sections,
/// the drawing sheets and the signature. The sections of each package come
/// ticked as the package proposes; any can be left out, and sections of
/// other packages can be added.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/io/doc_package.dart';
import '../../../core/io/doc_pdf.dart';
import '../../../core/io/doc_sections.dart' show docSheetOptions;
import '../../../core/io/pdf_sheet.dart' show PageSize, SheetOptions;
import '../../actions.dart' show deliverExport, pdfTexts;
import '../../io/pdf_font_loader.dart';
import '../../io/sheet_basemap.dart';
import '../../state/controller.dart';
import '../../theme.dart';
import '../fields.dart';
import 'title_block_dialog.dart';

/// Where an exported package goes: the app's download helper (tests read
/// the bytes here).
Future<void> Function(ProjectController c, String filename, Uint8List data) documentPackageSink = (c, filename, data) => deliverExport(c, filename, 'application/pdf', () => data);

/// The context the sections of a package are built from, for the project
/// of [c] (with the base map [rasters] under its sheets).
DocContext documentContextOf(ProjectController c, DocProfile profile, {PageSize page = PageSize.a3, SheetOptions? withMap}) {
  final ex = c.exporter();
  return DocContext(
    project: c.project,
    results: c.results,
    labels: ex.labels,
    profile: profile,
    layerNames: ex.layerNames,
    unconnected: ex.unconnected,
    sheetPage: page,
    rasters: withMap?.rasters ?? const [],
    attribution: withMap?.attribution ?? '',
  );
}

/// The file name of a package: the project and the package ("Orchard_Technical_report.pdf").
String documentPackageFileName(ProjectController c, DocProfile p) {
  String safe(String s) => s.replaceAll(RegExp(r'[^\w\-]+', unicode: true), '_');
  final n = c.project.meta.name.trim();
  return '${safe(n.isEmpty ? c.t('name.newProject') : n)}_${safe(docProfileTitle(c.t, p))}.pdf';
}

/// Builds package [o] for [c] (the base map under the sheets when
/// [baseMap] and the project shows one) and hands it to
/// [documentPackageSink]; returns the package, or null when it failed.
Future<DocPackage?> exportDocumentPackageAction(ProjectController c, DocPackageOptions o, {PageSize page = PageSize.a3, bool baseMap = true}) async {
  try {
    var ctx = documentContextOf(c, o.profile, page: page);
    final mapAvailable = c.project.meta.georef != null && c.baseMap != BaseMap.none && c.baseMapSnapshot != null;
    final sheets = packageSections(ctx, o).any((s) => s.id == 'prd.sheets');
    if (baseMap && mapAvailable && sheets) ctx = documentContextOf(c, o.profile, page: page, withMap: await withSheetBaseMap(c, docSheetOptions(ctx)));
    await preparePdfFonts([...pdfTexts(c, reports: true), o.title, o.recipient], language: c.lang);
    final pack = buildDocumentPackage(ctx, o);
    await documentPackageSink(c, documentPackageFileName(c, o.profile), pack.bytes);
    return pack;
  } catch (e) {
    c.notify(c.t('msg.error', {'e': c.describeError(e)}));
    return null;
  }
}

Future<void> showDocumentPackageDialog(BuildContext context, ProjectController c, {DocProfile profile = DocProfile.memorial}) {
  final t = c.t;
  var p = profile;
  var page = PageSize.a3;
  final mapAvailable = c.project.meta.georef != null && c.baseMap != BaseMap.none && c.baseMapSnapshot != null;
  var withMap = mapAvailable;
  final title = TextEditingController();
  final recipient = TextEditingController();
  var ctx0 = documentContextOf(c, p);
  var chosen = defaultSectionIds(p, ctx0).toSet();
  var busy = false;
  return showDialog<void>(
    context: context,
    builder: (dctx) {
      final compact = MediaQuery.sizeOf(dctx).width < 700;
      return StatefulBuilder(
        builder: (dctx, setState) {
          final own = profileSections(p);
          final others = [
            for (final s in documentSections())
              if (!s.profiles.containsKey(p)) s,
          ];
          Widget tile(DocSection s) {
            final can = s.canBuild(ctx0);
            final why = can ? null : t(s.needsResults && c.results == null ? 'prd.pkg.needsResults' : 'prd.pkg.noData');
            return CheckboxListTile(
              key: Key('pkg_section_${s.id}'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(t(s.titleKey), style: const TextStyle(fontSize: 12)),
              subtitle: why == null ? null : Text(why, style: TextStyle(fontSize: 11, color: Cad.fg54)),
              value: can && chosen.contains(s.id),
              onChanged: can ? (v) => setState(() => v == true ? chosen.add(s.id) : chosen.remove(s.id)) : null,
            );
          }

          return AlertDialog(
            title: Text(t('prd.pkg.title'), style: const TextStyle(fontSize: 15)),
            content: SizedBox(
              width: compact ? MediaQuery.sizeOf(dctx).width - 48 : 620,
              child: ScrollBody(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t('prd.pkg.hint'), style: TextStyle(fontSize: 12, color: Cad.fg70, height: 1.35)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<DocProfile>(
                      key: const Key('pkg_profile'),
                      isExpanded: true,
                      initialValue: p,
                      decoration: InputDecoration(labelText: t('prd.pkg.profile'), isDense: true),
                      style: TextStyle(fontSize: 12, color: Cad.fg),
                      items: [
                        for (final x in DocProfile.values) DropdownMenuItem(value: x, child: Text(docProfileTitle(t, x), style: const TextStyle(fontSize: 12))),
                      ],
                      onChanged: (v) => setState(() {
                        p = v ?? p;
                        ctx0 = documentContextOf(c, p);
                        chosen = defaultSectionIds(p, ctx0).toSet();
                      }),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(t('prd.pkg.for.${p.name}'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
                    ),
                    TextField(
                      key: const Key('pkg_title'),
                      controller: title,
                      decoration: InputDecoration(labelText: t('prd.pkg.docTitle'), hintText: docProfileTitle(t, p), isDense: true),
                      style: const TextStyle(fontSize: 12),
                    ),
                    TextField(
                      key: const Key('pkg_recipient'),
                      controller: recipient,
                      decoration: InputDecoration(labelText: t('prd.doc.recipient'), isDense: true),
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<PageSize>(
                      key: const Key('pkg_page'),
                      isExpanded: true,
                      initialValue: page,
                      decoration: InputDecoration(labelText: t('prd.pkg.sheetPage'), isDense: true),
                      style: TextStyle(fontSize: 12, color: Cad.fg),
                      items: [
                        for (final x in PageSize.values) DropdownMenuItem(value: x, child: Text('${x.label}  (${x.shortMm.round()} × ${x.longMm.round()} mm)', style: const TextStyle(fontSize: 12))),
                      ],
                      onChanged: (v) => setState(() => page = v ?? page),
                    ),
                    CheckboxListTile(
                      key: const Key('pkg_base_map'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(t('plot.baseMap'), style: const TextStyle(fontSize: 12)),
                      value: withMap && mapAvailable,
                      onChanged: mapAvailable ? (v) => setState(() => withMap = v ?? false) : null,
                    ),
                    SectionTitle(t('prd.pkg.sections')),
                    for (final s in own) tile(s),
                    if (others.isNotEmpty) ...[SectionTitle(t('prd.pkg.otherSections')), for (final s in others) tile(s)],
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        key: const Key('pkg_title_block'),
                        icon: const Icon(Icons.badge_outlined, size: 16),
                        label: Text(t('prd.menu.titleBlock')),
                        onPressed: () async {
                          await showTitleBlockDialog(dctx, c);
                          if (dctx.mounted) setState(() => ctx0 = documentContextOf(c, p));
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(key: const Key('pkg_cancel'), onPressed: () => Navigator.pop(dctx), child: Text(t('cancel'))),
              FilledButton(
                key: const Key('pkg_export'),
                onPressed: busy || chosen.isEmpty
                    ? null
                    : () async {
                        setState(() => busy = true);
                        final pack = await exportDocumentPackageAction(
                          c,
                          DocPackageOptions(profile: p, sections: chosen.toList(), title: title.text.trim(), recipient: recipient.text.trim()),
                          page: page,
                          baseMap: withMap,
                        );
                        if (!dctx.mounted) return;
                        if (pack == null) {
                          setState(() => busy = false);
                          return;
                        }
                        Navigator.pop(dctx);
                      },
                child: busy ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Text(t('prd.pkg.export')),
              ),
            ],
          );
        },
      );
    },
  );
}
