/// File → Import of a PDF plan: the page (with a preview), the scale (a
/// paper scale 1:N, the one written on the sheet when found, or a factor
/// in metres per PDF unit), where the bottom-left corner of the sheet goes,
/// what to bring in and on which layers. The import is one undo step and
/// leaves the plan selected, ready for the two-point align tool.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/io/pdf_import.dart';
import '../../../core/io/pdf_reader.dart';
import '../../../core/model/geometry.dart';
import '../../../core/units.dart';
import '../../io/prefs.dart';
import '../../state/controller.dart';
import '../../theme.dart';
import '../fields.dart';
import 'terrain_dialogs.dart' show dialogWidth;

/// Opens the PDF [bytes] (file [name]) and imports it through the dialog;
/// tells the user when the file cannot be read.
Future<void> importPdfAction(BuildContext context, ProjectController c, String name, Uint8List bytes) async {
  final PdfReader doc;
  try {
    doc = PdfReader.open(bytes);
  } on Object catch (e) {
    c.notify(c.t('msg.error', {'e': pdfErrorText(c, e)}));
    return;
  }
  if (!context.mounted) return;
  final summary = await showPdfImportDialog(context, c, name, doc);
  if (summary != null) c.notify('${c.t('msg.imported')}: $summary');
}

/// The message for an error of the PDF reader (`pdf_encrypted` → `pdfimp.err.encrypted`).
String pdfErrorText(ProjectController c, Object e) {
  if (e is FormatException && e.message.startsWith('pdf_')) {
    final key = 'pdfimp.err.${e.message.substring(4)}';
    if (c.t.has(key)) return c.t(key);
  }
  return c.describeError(e);
}

/// The import summary: entities, layers and the reader's notes.
String pdfImportSummary(ProjectController c, PdfImportResult r, Iterable<String> warnings) {
  final notes = {
    for (final w in [...warnings, ...r.warnings]) c.t.warning(w),
  }.toList();
  return c.t('pdfimp.done', {'n': '${r.entities.length}', 'l': '${r.layers.length}'}) + (notes.isEmpty ? '' : ' — ${notes.join('; ')}');
}

/// The dialog; completes with the import summary, or null when cancelled.
Future<String?> showPdfImportDialog(BuildContext context, ProjectController c, String name, PdfReader doc) {
  final t = c.t;
  final pages = doc.pages;
  var page = 0;
  // the scale: 1:N (a preset, or typed) or a factor; the last choice is remembered
  var choice = getPref('pdfimp.choice') ?? '100';
  var denominator = double.tryParse(getPref('pdfimp.scale') ?? '') ?? 100;
  var factor = double.tryParse(getPref('pdfimp.factor') ?? '') ?? 0.001;
  if (choice != 'other' && choice != 'factor' && !pdfScales.contains(int.tryParse(choice))) choice = '100';
  var scaleTouched = false;
  int? found;
  var vectors = true, texts = true, images = true, useLayers = true, hidden = false, byColour = false;
  final layerCtl = TextEditingController(text: pdfLayerName(name));
  var origin = Pt.zero;
  var rotation = 0.0;
  var originTouched = false;
  PdfPageContent? content;
  String? error;
  var reading = false, importing = false, started = false;
  var seq = 0;

  double metresPerUnit() => switch (choice) {
    'factor' => factor > 0 ? factor : 0.001,
    'other' => PdfImportOptions.atScale(denominator > 0 ? denominator : 100),
    _ => PdfImportOptions.atScale(double.tryParse(choice) ?? 100),
  };

  // a new drawing starts at the origin; otherwise the sheet is centred on the view
  Pt defaultOrigin() {
    if (c.project.entities.isEmpty || c.camera.size.isEmpty) return Pt.zero;
    final k = metresPerUnit();
    final v = c.camera.visible.center;
    return Pt((v.x - pages[page].width * k / 2).roundToDouble(), (v.y - pages[page].height * k / 2).roundToDouble());
  }

  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        void scaleChanged() {
          if (!originTouched) origin = defaultOrigin();
        }

        void load(int i) {
          reading = true;
          content = null;
          error = null;
          final token = ++seq;
          // a frame first, so that the dialog shows while the page is read
          Future<void>.delayed(const Duration(milliseconds: 30), () {
            if (token != seq || !ctx.mounted) return;
            PdfPageContent? r;
            String? err;
            try {
              r = doc.readPage(i, images: false);
            } on Object catch (e) {
              err = pdfErrorText(c, e);
            }
            if (!ctx.mounted || token != seq) return;
            setState(() {
              content = r;
              error = err;
              reading = false;
              found = r == null ? null : pdfScaleOnSheet(r);
              if (found != null && !scaleTouched) {
                choice = pdfScales.contains(found) ? '$found' : 'other';
                denominator = found!.toDouble();
              }
              scaleChanged();
            });
          });
        }

        if (!started) {
          started = true;
          origin = defaultOrigin();
          load(page);
        }

        PdfImportOptions options() => PdfImportOptions(
          metresPerUnit: metresPerUnit(),
          origin: origin,
          rotationDeg: rotation,
          vectors: vectors,
          texts: texts,
          images: images,
          useLayers: useLayers,
          hiddenLayers: hidden,
          byColour: byColour,
          layer: layerCtl.text.trim().isEmpty ? pdfLayerName(name) : layerCtl.text.trim(),
          source: name,
        );

        Future<void> run() async {
          final cur = content;
          if (cur == null) return;
          setState(() => importing = true);
          // a frame for the progress, then the pixels of the images (scans can take a while)
          await Future<void>.delayed(const Duration(milliseconds: 30));
          if (!ctx.mounted) return;
          var page0 = cur;
          try {
            if (images && cur.images.isNotEmpty) {
              final withPixels = doc.readPage(page, vectors: false, texts: false, images: true);
              page0 = cur.withImages(withPixels.images, withPixels.warnings);
            }
          } on Object catch (e) {
            setState(() {
              importing = false;
              error = pdfErrorText(c, e);
            });
            return;
          }
          // converted first: an import that brings nothing leaves no undo step
          final r = pdfPageEntities(page0, options(), c.project.newId);
          if (r.entities.isEmpty) {
            setState(() {
              importing = false;
              error = t('pdfimp.nothing');
            });
            return;
          }
          final added = c.mutate(
            () {
              addPdfEntities(c.project, r);
              return true;
            },
            invalidateResults: false,
            label: 'hist.importPdf',
          );
          if (added == null) {
            // a design is running: the controller said so
            setState(() => importing = false);
            return;
          }
          setPref('pdfimp.choice', choice);
          setPref('pdfimp.scale', '$denominator');
          setPref('pdfimp.factor', '$factor');
          c.selection
            ..clear()
            ..addAll(r.entities.map((e) => e.id));
          final b = r.bounds;
          if (!b.isEmpty && !c.camera.size.isEmpty) c.camera.fit(b.inflate(math.max(b.width, b.height) * 0.05 + 1));
          c.refresh();
          Navigator.pop(ctx, pdfImportSummary(c, r, page0.warnings));
        }

        final info = pages[page];
        final k = metresPerUnit();
        final cur = content;
        Widget check(String label, bool value, ValueChanged<bool> on, {Key? key, bool enabled = true}) => CheckboxListTile(
          key: key,
          dense: true,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(label, style: const TextStyle(fontSize: 12)),
          value: value,
          onChanged: enabled && !importing ? (v) => setState(() => on(v ?? false)) : null,
        );
        String pageLabel(PdfPageInfo p) =>
            t('pdfimp.pageItem', {'i': '${p.index + 1}', 'w': fmt(p.widthMm, 0), 'h': fmt(p.heightMm, 0)}) + (p.rotation != 0 ? t('pdfimp.rotated', {'a': '${p.rotation}'}) : '');
        final layerCount = cur?.layers.length ?? 0;
        final hiddenCount = cur?.layers.where((l) => !l.visible).length ?? 0;
        final body = <Widget>[
          Text(
            name,
            style: TextStyle(fontSize: 11.5, color: Cad.fg54),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          if (pages.length > 1)
            DropdownButtonFormField<int>(
              key: const Key('pdfimp_page'),
              isExpanded: true,
              initialValue: page,
              decoration: InputDecoration(labelText: t('pdfimp.page'), isDense: true),
              style: TextStyle(fontSize: 12, color: Cad.fg),
              items: [
                for (final p in pages)
                  DropdownMenuItem(
                    value: p.index,
                    child: Text(pageLabel(p), style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: importing
                  ? null
                  : (v) {
                      if (v == null || v == page) return;
                      setState(() {
                        page = v;
                        load(page);
                      });
                    },
            )
          else
            Text(pageLabel(info), style: TextStyle(fontSize: 12, color: Cad.fg70)),
          const SizedBox(height: 8),
          _Preview(content: cur, page: info, reading: reading, showHidden: hidden),
          const SizedBox(height: 4),
          if (cur != null)
            Text(
              [
                t('pdfimp.counts', {'p': '${cur.paths.length}', 't': '${cur.texts.length}', 'i': '${cur.images.length}'}),
                if (layerCount > 0) t('pdfimp.layersFound', {'n': '$layerCount'}),
              ].join(' · '),
              key: const Key('pdfimp_counts'),
              style: TextStyle(fontSize: 11, color: Cad.fg54),
            )
          else if (reading)
            Text(t('pdfimp.reading'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                error!,
                key: const Key('pdfimp_error'),
                style: TextStyle(fontSize: 11.5, color: Cad.warning),
              ),
            ),
          const SizedBox(height: 6),
          SectionTitle(t('pdfimp.scale')),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: KeyedSubtree(
                  // a new field when the choice is set from outside (the scale found on the sheet)
                  key: ValueKey('pdfimp_choice_$choice'),
                  child: DropdownButtonFormField<String>(
                    key: const Key('pdfimp_scale'),
                    isExpanded: true,
                    initialValue: choice,
                    decoration: InputDecoration(labelText: t('pdfimp.scale'), isDense: true),
                    style: TextStyle(fontSize: 12, color: Cad.fg),
                    items: [
                      for (final n in pdfScales)
                        DropdownMenuItem(
                          value: '$n',
                          child: Text('1:$n', style: const TextStyle(fontSize: 12)),
                        ),
                      DropdownMenuItem(
                        value: 'other',
                        child: Text(t('pdfimp.scaleOther'), style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: 'factor',
                        child: Text(t('pdfimp.scaleFactor'), style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                      ),
                    ],
                    onChanged: importing
                        ? null
                        : (v) => setState(() {
                            choice = v ?? choice;
                            scaleTouched = true;
                            scaleChanged();
                          }),
                  ),
                ),
              ),
              if (choice == 'other' || choice == 'factor') ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 130,
                  child: choice == 'other'
                      ? NumField(
                          key: const Key('pdfimp_denominator'),
                          label: t('plot.scale'),
                          value: denominator,
                          decimals: 0,
                          onChanged: (v) => setState(() {
                            if (v > 0) denominator = v;
                            scaleTouched = true;
                            scaleChanged();
                          }),
                        )
                      : NumField(
                          key: const Key('pdfimp_factor'),
                          label: 'm',
                          value: factor,
                          decimals: 6,
                          onChanged: (v) => setState(() {
                            if (v > 0) factor = v;
                            scaleTouched = true;
                            scaleChanged();
                          }),
                        ),
                ),
              ],
            ],
          ),
          if (choice == 'factor')
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(t('pdfimp.factorHint'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
            ),
          if (found != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                t('pdfimp.scaleFound', {'n': '$found'}),
                key: const Key('pdfimp_found'),
                style: TextStyle(fontSize: 11, color: Cad.ok),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              t('pdfimp.size', {'x': fmt(info.width * k, 1), 'y': fmt(info.height * k, 1)}),
              key: const Key('pdfimp_size'),
              style: TextStyle(fontSize: 11, color: Cad.fg54),
            ),
          ),
          SectionTitle(t('pdfimp.origin')),
          Row(
            children: [
              Expanded(
                child: NumField(
                  key: const Key('pdfimp_x'),
                  label: 'X (m)',
                  value: origin.x,
                  onChanged: (v) => setState(() {
                    origin = Pt(v, origin.y);
                    originTouched = true;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: NumField(
                  key: const Key('pdfimp_y'),
                  label: 'Y (m)',
                  value: origin.y,
                  onChanged: (v) => setState(() {
                    origin = Pt(origin.x, v);
                    originTouched = true;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: NumField(key: const Key('pdfimp_rotation'), label: t('pdfimp.rotation'), value: rotation, decimals: 1, onChanged: (v) => setState(() => rotation = v)),
              ),
            ],
          ),
          SectionTitle(t('pdfimp.what')),
          check(t('pdfimp.vectors'), vectors, (v) => vectors = v, key: const Key('pdfimp_vectors')),
          check(t('pdfimp.texts'), texts, (v) => texts = v, key: const Key('pdfimp_texts')),
          check(t('pdfimp.images'), images, (v) => images = v, key: const Key('pdfimp_images'), enabled: cur == null || cur.images.isNotEmpty),
          SectionTitle(t('pdfimp.layers')),
          TextField(
            key: const Key('pdfimp_layer'),
            controller: layerCtl,
            enabled: !importing,
            decoration: InputDecoration(labelText: t('pdfimp.layer'), isDense: true),
            style: const TextStyle(fontSize: 12),
          ),
          if (layerCount > 0) check(t('pdfimp.useLayers', {'n': '$layerCount'}), useLayers, (v) => useLayers = v, key: const Key('pdfimp_use_layers')),
          if (hiddenCount > 0) check(t('pdfimp.hidden', {'n': '$hiddenCount'}), hidden, (v) => hidden = v, key: const Key('pdfimp_hidden')),
          check(t('pdfimp.byColour'), byColour, (v) => byColour = v, key: const Key('pdfimp_by_colour')),
          const SizedBox(height: 4),
          Text(t('pdfimp.alignHint'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
        ];
        return AlertDialog(
          title: Text(t('pdfimp.title'), style: const TextStyle(fontSize: 15)),
          content: SizedBox(
            width: dialogWidth(ctx, 520),
            child: ScrollBody(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: body),
            ),
          ),
          actions: [
            TextButton(onPressed: importing ? null : () => Navigator.pop(ctx), child: Text(t('cancel'))),
            FilledButton.icon(
              key: const Key('pdfimp_ok'),
              onPressed: cur == null || importing || reading ? null : run,
              icon: importing ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download_done, size: 16),
              label: Text(t('pdfimp.import')),
            ),
          ],
        );
      },
    ),
  );
}

/// The page in small: its outline, the paths, the text baselines and the
/// image frames, in the colours the import gives them.
class _Preview extends StatelessWidget {
  const _Preview({required this.content, required this.page, required this.reading, required this.showHidden});
  final PdfPageContent? content;
  final PdfPageInfo page;
  final bool reading, showHidden;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxHeight: 200),
    child: Center(
      child: AspectRatio(
        aspectRatio: page.height > 0 ? (page.width / page.height).clamp(0.3, 4.0) : 1.4,
        child: Container(
          key: const Key('pdfimp_preview'),
          decoration: BoxDecoration(
            color: Cad.canvas,
            border: Border.all(color: Cad.fg24),
          ),
          child: reading && content == null
              ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)))
              : RepaintBoundary(
                  child: CustomPaint(painter: _PreviewPainter(content, page, showHidden), size: Size.infinite),
                ),
        ),
      ),
    ),
  );
}

class _PreviewPainter extends CustomPainter {
  _PreviewPainter(this.content, this.page, this.showHidden);
  final PdfPageContent? content;
  final PdfPageInfo page;
  final bool showHidden;

  /// Most segments drawn (enough to recognise the plan).
  static const _budget = 40000;

  @override
  void paint(Canvas canvas, Size size) {
    final c = content;
    if (c == null || page.width <= 0 || page.height <= 0) return;
    final s = math.min(size.width / page.width, size.height / page.height);
    final dx = (size.width - page.width * s) / 2, dy = (size.height - page.height * s) / 2;
    Offset at(Pt p) => Offset(dx + p.x * s, size.height - dy - p.y * s);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    var budget = _budget;
    for (final im in c.images) {
      if (im.hidden && !showHidden) continue;
      final path = Path()..addPolygon([for (final p in im.corners) at(p)], true);
      canvas.drawPath(path, Paint()..color = Cad.fg10);
      canvas.drawPath(path, paint..color = Cad.fg30);
    }
    for (final p in c.paths) {
      if (p.hidden && !showHidden) continue;
      if (budget <= 0) break;
      budget -= p.segments;
      final path = Path()..addPolygon([for (final q in p.points) at(q)], p.closed);
      canvas.drawPath(path, paint..color = Cad.ink(Color(pdfCanvasColour(p.rgb))));
    }
    for (final x in c.texts) {
      if (x.hidden && !showHidden) continue;
      if (budget-- <= 0) break;
      // a text as a line along its baseline, about as long as it is
      final a = x.angleDeg * math.pi / 180;
      final len = x.height * 0.5 * x.text.length;
      canvas.drawLine(at(x.origin), at(x.origin + Pt(math.cos(a) * len, math.sin(a) * len)), paint..color = Cad.ink(Color(pdfCanvasColour(x.rgb))).withValues(alpha: 0.7));
    }
  }

  @override
  bool shouldRepaint(covariant _PreviewPainter old) => !identical(old.content, content) || old.showHidden != showHidden || old.page != page;
}
