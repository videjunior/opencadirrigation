/// File → Title block (1.6.0 PRD, PRD-01): the professional title block of
/// the sheets and the covers of the document packages — company and logo,
/// the technical lead with the council, registration and ART/RRT/TRT, the
/// CAR and the water permit, the municipality, the stage, the drawing
/// number, the date of issue and the revision table. OK makes the change
/// one undo step; Cancel puts everything back. The professional's own part
/// (company, logo, lead, council, registration) can be kept for new
/// projects ("Save as my default") and filled in from there.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/io/title_block_sheet.dart' show normalizeLogo;
import '../../../core/model/title_block.dart';
import '../../io/file_io.dart';
import '../../io/prefs.dart';
import '../../state/controller.dart';
import '../../theme.dart';
import '../fields.dart';

/// Where the professional's default title block is kept (this browser).
const titleBlockDefaultsPref = 'prd.titleBlockDefaults';

/// The professional's default title block (company, logo, lead, council,
/// registration), or null when none was saved.
TitleBlock? titleBlockDefaults() {
  final s = getPref(titleBlockDefaultsPref);
  if (s == null || s.isEmpty) return null;
  try {
    final j = jsonDecode(s);
    return j is Map ? TitleBlock.fromJson(j.cast<String, dynamic>()) : null;
  } on FormatException {
    return null;
  }
}

/// Keeps the owner part of [tb] as the default of new title blocks.
void saveTitleBlockDefaults(TitleBlock tb) => setPref(titleBlockDefaultsPref, jsonEncode(tb.ownerPart().toJson()));

/// Puts the picture [bytes] as the logo of [tb]; false when it is no
/// picture (PNG or JPEG; others are converted to PNG).
bool setTitleBlockLogo(TitleBlock tb, Uint8List bytes) {
  final logo = normalizeLogo(bytes);
  if (logo == null) return false;
  tb.logo = logo.$1;
  tb.logoMime = logo.$2;
  return true;
}

/// Fields side by side, each at least [minWidth] wide, wrapping on a
/// narrow dialog (a phone).
Widget _fieldRow(List<Widget> children, {double minWidth = 150}) => LayoutBuilder(
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

Future<void> showTitleBlockDialog(BuildContext context, ProjectController c) async {
  final t = c.t;
  final edit = c.beginSettingsEdit('prd.hist.titleBlock');
  final m = c.project.meta;
  final tb = m.titleBlock;
  String? dateError;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final compact = MediaQuery.sizeOf(ctx).width < 700;
      return StatefulBuilder(
        builder: (ctx, setState) {
          final defaults = titleBlockDefaults();
          Widget text(String key, String label, String value, ValueChanged<String> apply) =>
              TextFieldRow(key: Key('tb_$key'), label: label, value: value, onChanged: (v) => setState(() => apply(v.trim())));
          return AlertDialog(
            title: Text(t('prd.tb.title'), style: const TextStyle(fontSize: 15)),
            content: SizedBox(
              width: compact ? MediaQuery.sizeOf(ctx).width - 48 : 640,
              child: ScrollBody(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t('prd.tb.hint'), style: TextStyle(fontSize: 12, color: Cad.fg70, height: 1.35)),
                    SectionTitle(t('prd.tb.secProject')),
                    _fieldRow([
                      text('client', t('dlg.client'), m.client, (v) => m.client = v),
                      text('site', t('prd.tb.property'), m.site, (v) => m.site = v),
                    ]),
                    _fieldRow([
                      text('municipality', t('prd.tb.municipality'), tb.municipality, (v) => tb.municipality = v),
                      text('car', t('prd.tb.carLong'), tb.car, (v) => tb.car = v),
                    ]),
                    text('permit', t('prd.tb.permitLong'), tb.waterPermit, (v) => tb.waterPermit = v),
                    SectionTitle(t('prd.tb.secLead')),
                    _fieldRow([
                      text('responsible', t('prd.tb.responsible'), tb.responsible, (v) => tb.responsible = v),
                      text('designer', t('dlg.designer'), m.designer, (v) => m.designer = v),
                    ]),
                    _fieldRow([
                      text('council', t('prd.tb.council'), tb.council, (v) => tb.council = v),
                      text('registration', t('prd.tb.registrationNo'), tb.registration, (v) => tb.registration = v),
                      text('record', t('prd.tb.recordNo', {'r': tb.recordName}), tb.responsibilityRecord, (v) => tb.responsibilityRecord = v),
                    ], minWidth: 140),
                    SectionTitle(t('prd.tb.secSheets')),
                    _fieldRow([
                      DropdownButtonFormField<ProjectStage>(
                        key: const Key('tb_stage'),
                        isExpanded: true,
                        initialValue: tb.stage,
                        decoration: InputDecoration(labelText: t('prd.tb.stage'), isDense: true),
                        style: TextStyle(fontSize: 12, color: Cad.fg),
                        items: [
                          for (final s in ProjectStage.values) DropdownMenuItem(value: s, child: Text(t('prd.stage.${s.name}'), style: const TextStyle(fontSize: 12))),
                        ],
                        onChanged: (v) => setState(() => tb.stage = v ?? ProjectStage.none),
                      ),
                      text('drawingNumber', t('prd.tb.drawingNumber'), tb.drawingNumber, (v) => tb.drawingNumber = v),
                      text('issued', t('prd.tb.issued'), tb.issueDate, (v) {
                        final d = parseTitleDate(v);
                        tb.issueDate = v.isEmpty || d == null ? v : titleDateText(d);
                        dateError = v.isEmpty || d != null ? null : t('prd.tb.badDate');
                      }),
                    ], minWidth: 140),
                    if (dateError != null) Text(dateError!, style: TextStyle(fontSize: 11.5, color: Cad.attention)),
                    SectionTitle(t('prd.tb.secCompany')),
                    text('company', t('prd.tb.company'), tb.company, (v) => tb.company = v),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (tb.logo != null)
                          Container(
                            key: const Key('tb_logo_preview'),
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Cad.fg24)),
                            child: Image.memory(tb.logo!, height: 48, fit: BoxFit.contain, gaplessPlayback: true, errorBuilder: (_, _, _) => const SizedBox(width: 48, height: 48)),
                          ),
                        OutlinedButton.icon(
                          key: const Key('tb_logo_load'),
                          icon: const Icon(Icons.image_outlined, size: 16),
                          label: Text(t(tb.logo == null ? 'prd.tb.logoLoad' : 'prd.tb.logoChange')),
                          onPressed: () async {
                            final f = await openBinaryFile(accept: '.png,.jpg,.jpeg,.webp,.gif,.bmp');
                            if (f == null || !ctx.mounted) return;
                            if (!setTitleBlockLogo(tb, f.$2)) {
                              c.notify(t('prd.tb.logoBad'));
                              return;
                            }
                            setState(() {});
                          },
                        ),
                        if (tb.logo != null)
                          TextButton(key: const Key('tb_logo_remove'), onPressed: () => setState(() => tb.logo = null), child: Text(t('prd.tb.logoRemove'))),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(t('prd.tb.logoHint'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
                    ),
                    SectionTitle(t('pdf.revisions')),
                    for (var i = 0; i < tb.revisions.length; i++)
                      Row(
                        key: ValueKey('tb_rev_${identityHashCode(tb.revisions[i])}'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _fieldRow([
                              text('rev_$i', t('pdf.rev'), tb.revisions[i].revision, (v) => tb.revisions[i].revision = v),
                              text('revDate_$i', t('pdf.date'), tb.revisions[i].date, (v) => tb.revisions[i].date = v),
                              text('revDesc_$i', t('rep.description'), tb.revisions[i].description, (v) => tb.revisions[i].description = v),
                              text('revBy_$i', t('prd.tb.revAuthor'), tb.revisions[i].author, (v) => tb.revisions[i].author = v),
                            ], minWidth: 110),
                          ),
                          IconButton(
                            key: Key('tb_rev_remove_$i'),
                            tooltip: t('prd.tb.revRemove'),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: () => setState(() => tb.revisions.removeAt(i)),
                          ),
                        ],
                      ),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        key: const Key('tb_rev_add'),
                        icon: const Icon(Icons.add, size: 16),
                        label: Text(t('prd.tb.revAdd')),
                        onPressed: () => setState(() => tb.revisions.add(TitleRevision(revision: nextTitleRevision(tb), date: titleDateText(DateTime.now())))),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              if (defaults != null)
                TextButton(
                  key: const Key('tb_defaults_fill'),
                  onPressed: () => setState(() => tb.adoptOwner(defaults)),
                  child: Text(t('prd.tb.defaultsFill')),
                ),
              TextButton(
                key: const Key('tb_defaults_save'),
                onPressed: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  // the field being typed in commits on the next microtask
                  Future<void>.delayed(Duration.zero, () {
                    saveTitleBlockDefaults(tb);
                    c.notify(t('prd.tb.defaultsSaved'));
                    if (ctx.mounted) setState(() {});
                  });
                },
                child: Text(t('prd.tb.defaultsSave')),
              ),
              TextButton(key: const Key('tb_cancel'), onPressed: () => _close(ctx, false), child: Text(t('cancel'))),
              FilledButton(key: const Key('tb_ok'), onPressed: () => _close(ctx, true), child: Text(t('ok'))),
            ],
          );
        },
      );
    },
  );
  // the last field typed in commits when it loses the focus (a microtask)
  await Future<void>.delayed(Duration.zero);
  if (ok == true) {
    c.commitSettingsEdit(edit);
  } else {
    c.cancelSettingsEdit(edit);
  }
}

void _close(BuildContext context, bool ok) {
  FocusManager.instance.primaryFocus?.unfocus();
  Navigator.pop(context, ok);
}

/// The revision after the last one of [tb] (A → B, 3 → 4; "0" to start).
String nextTitleRevision(TitleBlock tb) {
  final last = tb.currentRevision;
  if (last.isEmpty) return '0';
  final n = int.tryParse(last);
  if (n != null) return '${n + 1}';
  final code = last.codeUnitAt(last.length - 1);
  if ((code >= 65 && code < 90) || (code >= 97 && code < 122)) return '${last.substring(0, last.length - 1)}${String.fromCharCode(code + 1)}';
  return '$last.1';
}
