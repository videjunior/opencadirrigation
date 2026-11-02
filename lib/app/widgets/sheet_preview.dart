/// The preview of the export dialog of a sheet (PDF or PNG): the sheet the
/// options make — paper, scale, title block, legend, the sheets of a set —
/// drawn small as it will be exported, one sheet of the set at a time,
/// redrawn a moment after an option changes. The base map, fetched only
/// for the export, is not in it.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/io/pdf_sheet.dart';
import '../../core/io/sheet_canvas.dart' show RecordedSheet;
import '../io/png_export.dart' show UiSheetCanvas;
import '../state/controller.dart';
import '../theme.dart';

/// Projects with more items than this are previewed on request (the sheet
/// is recorded on the interface thread).
const sheetPreviewAutoItems = 20000;

class SheetPreview extends StatefulWidget {
  const SheetPreview({super.key, required this.c, required this.options, this.listen, this.maxHeight = 220});
  final ProjectController c;

  /// The options as the dialog stands now.
  final SheetOptions Function() options;

  /// Changes the dialog makes without rebuilding (the scale typed).
  final Listenable? listen;
  final double maxHeight;

  @override
  State<SheetPreview> createState() => _SheetPreviewState();
}

class _SheetPreviewState extends State<SheetPreview> {
  RecordedSheet? sheet;
  int index = 0, count = 1;
  String? error;
  Timer? _wait;
  late bool _onRequest = widget.c.project.entities.length > sheetPreviewAutoItems;

  ProjectController get c => widget.c;

  @override
  void initState() {
    super.initState();
    widget.listen?.addListener(_schedule);
    if (!_onRequest) _schedule(now: true);
  }

  @override
  void didUpdateWidget(SheetPreview old) {
    super.didUpdateWidget(old);
    if (!identical(old.listen, widget.listen)) {
      old.listen?.removeListener(_schedule);
      widget.listen?.addListener(_schedule);
    }
    if (!_onRequest) _schedule();
  }

  @override
  void dispose() {
    _wait?.cancel();
    widget.listen?.removeListener(_schedule);
    super.dispose();
  }

  void _schedule({bool now = false}) {
    _wait?.cancel();
    if (now) {
      _record();
      return;
    }
    _wait = Timer(const Duration(milliseconds: 250), _record);
  }

  void _record() {
    if (!mounted) return;
    try {
      final o = widget.options();
      final b = c.exporter().sheetBuilder();
      final n = math.max(1, b.sheetCount(o));
      final i = index.clamp(0, n - 1);
      final s = b.recordSheet(o, index: i);
      setState(() {
        count = n;
        index = i;
        sheet = s;
        error = null;
      });
    } catch (e) {
      setState(() => error = c.describeError(e));
    }
  }

  void _go(int by) {
    index = (index + by).clamp(0, count - 1);
    _record();
  }

  void _enlarge(RecordedSheet s) => showDialog<void>(
    context: context,
    builder: (ctx) {
      final size = MediaQuery.sizeOf(ctx);
      final w = math.min(size.width - 48, (size.height - 120) * s.width / s.height);
      return Dialog(
        key: const Key('sheet_preview_large'),
        insetPadding: const EdgeInsets.all(16),
        child: InteractiveViewer(
          maxScale: 8,
          child: SizedBox(
            width: w,
            height: w * s.height / s.width,
            child: CustomPaint(painter: SheetPainter(s)),
          ),
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final t = c.t;
    final s = sheet;
    final caption = TextStyle(fontSize: 11, color: Cad.fg54);
    Widget body;
    if (_onRequest && s == null) {
      body = Center(
        child: OutlinedButton.icon(
          key: const Key('sheet_preview_show'),
          onPressed: () {
            _onRequest = false;
            _record();
          },
          icon: const Icon(Icons.visibility_outlined, size: 16),
          label: Text(t('prev.show')),
        ),
      );
    } else if (error != null) {
      body = Text(t('prev.failed', {'e': error!}), style: TextStyle(fontSize: 11.5, color: Cad.error));
    } else if (s == null) {
      body = const Center(child: SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)));
    } else {
      body = LayoutBuilder(
        builder: (context, box) {
          final maxW = box.maxWidth.isFinite ? box.maxWidth : 300.0;
          var w = maxW, h = w * s.height / s.width;
          if (h > widget.maxHeight) {
            h = widget.maxHeight;
            w = h * s.width / s.height;
          }
          return Center(
            child: Tooltip(
              message: t('prev.title'),
              child: InkWell(
                key: const Key('sheet_preview'),
                onTap: () => _enlarge(s),
                child: Container(
                  width: w,
                  height: h,
                  decoration: BoxDecoration(
                    border: Border.all(color: Cad.divider),
                    boxShadow: [BoxShadow(color: Cad.scrim, blurRadius: 4)],
                  ),
                  child: CustomPaint(painter: SheetPainter(s)),
                ),
              ),
            ),
          );
        },
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(t('prev.title'), style: TextStyle(fontSize: 12, color: Cad.fg70)),
            ),
            if (count > 1) ...[
              IconButton(
                key: const Key('sheet_preview_prev'),
                tooltip: t('prev.prev'),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_left, size: 18),
                onPressed: index > 0 ? () => _go(-1) : null,
              ),
              Text(t('prev.sheet', {'i': '${index + 1}', 'n': '$count'}), key: const Key('sheet_preview_page'), style: caption),
              IconButton(
                key: const Key('sheet_preview_next'),
                tooltip: t('prev.next'),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_right, size: 18),
                onPressed: index < count - 1 ? () => _go(1) : null,
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        body,
        const SizedBox(height: 4),
        Text(t('prev.noMap'), style: caption),
      ],
    );
  }
}

/// A recorded sheet drawn to fit the painted size, on white paper.
class SheetPainter extends CustomPainter {
  SheetPainter(this.sheet);
  final RecordedSheet sheet;

  @override
  void paint(Canvas canvas, Size size) {
    if (sheet.width <= 0 || size.isEmpty) return;
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFFFFFF));
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    sheet.replay(UiSheetCanvas(canvas, sheet.width, sheet.height, size.width / sheet.width));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SheetPainter old) => !identical(old.sheet, sheet);
}
