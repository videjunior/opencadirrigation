/// 1.7.0 ROW: Crop rows from the image (Design → Automatic design): the
/// direction, spacing and count of the planting rows of the selected field
/// read from the satellite base map or a placed aerial photo by image
/// processing on this device (engine module `crop_rows.dart`), shown over
/// the image in the dialog and over the drawing, and applied in one undo
/// step: the row direction and spacing of the area (the defaults of Field
/// blocks, Tree rings and Block over it), its ground cover, guide lines of
/// the rows on a layer of their own.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/design/auto_layout.dart' show LayoutRegion, maximumInscribedCircle;
import '../../../core/design/crop_rows.dart';
import '../../../core/model/entities.dart';
import '../../../core/model/geometry.dart';
import '../../io/crop_row_pixels.dart';
import '../../state/controller.dart';
import '../../theme.dart';
import '../fields.dart';
import 'terrain_dialogs.dart' show dialogWidth;

// drawn over the photograph, so the same in both themes
const _rowColour = Color(0xFFFFD740), _outlineColour = Color(0xFF00E5FF);

/// Pixels a side of the detail at the centre of the field.
const _detailSide = 150;

/// Opens the crop rows dialog for the selected field.
Future<void> showCropRowsDialog(BuildContext context, ProjectController c) => showDialog<void>(
  context: context,
  builder: (_) => CropRowsDialog(controller: c),
);

class CropRowsDialog extends StatefulWidget {
  const CropRowsDialog({super.key, required this.controller});
  final ProjectController controller;

  @override
  State<CropRowsDialog> createState() => _CropRowsDialogState();
}

/// A picture of the dialog and the world rectangle it shows.
class _Shot {
  _Shot(this.image, this.world);
  final ui.Image image;
  final Bounds world;
}

class _CropRowsDialogState extends State<CropRowsDialog> {
  ProjectController get c => widget.controller;
  CropRowSession get _session => CropRowSession.of(c);

  late final CropRowField? _field = cropRowField(c);
  late final List<ImageEntity> _photos = _field == null ? const [] : cropRowPhotos(c, _field);

  /// 'map' or the id of the photo read.
  late String _source = _photos.where((e) => c.selection.contains(e.id)).firstOrNull?.id ?? 'map';
  double _minS = 1.5, _maxS = 12;
  bool _otherBand = false;

  int _gen = 0;
  bool _busy = false, _reading = false, _stopped = false;
  double _progress = 0;
  String? _error;
  CropRowResult? _result;
  String? _resultKey;
  CropRowPixels? _pixels;
  String? _pixelsKey;
  _Shot? _overview, _detail;

  bool _applyRows = true, _applyCover = true, _applyGuides = false;

  @override
  void initState() {
    super.initState();
    _applyGuides = _field?.area == null;
    // the dialog shows first, then the pixels are read
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _field != null) unawaited(_detect());
    });
  }

  @override
  void dispose() {
    _gen++;
    _overview?.image.dispose();
    _detail?.image.dispose();
    // the rows on the drawing go with the dialog (repainted after this
    // frame: the tree is locked while the dialog unmounts)
    if (_session.preview.isNotEmpty) {
      _session.preview = const [];
      final controller = c;
      WidgetsBinding.instance.addPostFrameCallback((_) => controller.refresh());
    }
    super.dispose();
  }

  CropRowOptions get _options => CropRowOptions(minSpacingM: _minS, maxSpacingM: _maxS, otherBand: _otherBand);
  String get _key => '$_source|${_options.sane.key}';
  bool get _stale => _result != null && _resultKey != _key;

  // ------------------------------------------------------------ reading

  Future<void> _detect() async {
    final f = _field;
    if (f == null) return;
    final gen = ++_gen;
    final o = _options;
    final key = _key;
    setState(() {
      _busy = true;
      _stopped = false;
      _error = null;
      _progress = 0;
    });
    try {
      // the frame depends on the source and the closest spacing only
      final pixelsKey = '$_source|${o.sane.minSpacingM}';
      var px = _pixelsKey == pixelsKey ? _pixels : null;
      if (px == null) {
        setState(() => _reading = true);
        final photo = _photos.where((e) => e.id == _source).firstOrNull;
        px = await cropRowPixels(c, f, o, tiles: _session.tiles, photo: photo);
        if (!mounted || gen != _gen) return;
        _pixels = px;
        _pixelsKey = pixelsKey;
        await _makeShots(px, f);
        if (!mounted || gen != _gen) return;
        setState(() => _reading = false);
      }
      final r = await detectCropRows(
        px.raster,
        f.outline,
        holes: f.holes,
        options: o,
        cancelled: () => !mounted || gen != _gen,
        progress: (p) {
          if (mounted && gen == _gen) setState(() => _progress = p);
        },
      );
      if (!mounted || gen != _gen) return;
      _session
        ..last = r
        ..lastId = f.entity.id
        ..preview = r.rowLines;
      c.refresh();
      setState(() {
        _result = r;
        _resultKey = key;
        final area = f.area != null;
        _applyRows = area;
        _applyCover = area && r.groundCover != null;
      });
    } on CropRowsCancelled {
      // stopped, or a newer reading under way
    } on CropRowSourceError catch (e) {
      if (mounted && gen == _gen) setState(() => _error = c.t(e.key, e.args));
    } catch (e) {
      if (mounted && gen == _gen) setState(() => _error = c.describeError(e));
    } finally {
      if (mounted && gen == _gen) {
        setState(() {
          _busy = false;
          _reading = false;
        });
      }
    }
  }

  void _stop() {
    _gen++;
    setState(() {
      _busy = false;
      _reading = false;
      _stopped = true;
    });
  }

  /// The overview of the raster and the detail at the centre of the field,
  /// as images for the preview.
  Future<void> _makeShots(CropRowPixels px, CropRowField f) async {
    final im = px.raster;
    final (rgba, w, h) = cropRowPreview(im, maxSide: 640);
    final overview = await _image(rgba, w, h);
    // the detail: actual pixels round the widest inner point
    final (centre, _) = maximumInscribedCircle(LayoutRegion(f.outline, exclusions: f.holes));
    final (cx, cy) = im.toPixel(centre);
    final side = math.min(_detailSide, math.min(im.width, im.height));
    final x0 = (cx - side / 2).round().clamp(0, im.width - side), y0 = (cy - side / 2).round().clamp(0, im.height - side);
    final crop = Uint8List(side * side * 4);
    for (var y = 0; y < side; y++) {
      crop.setRange(y * side * 4, (y + 1) * side * 4, im.rgba, ((y0 + y) * im.width + x0) * 4);
    }
    final detail = await _image(crop, side, side);
    if (!mounted) {
      overview?.dispose();
      detail?.dispose();
      return;
    }
    _overview?.image.dispose();
    _detail?.image.dispose();
    _overview = overview == null ? null : _Shot(overview, im.world);
    _detail = detail == null
        ? null
        : _Shot(detail, Bounds(im.world.minX + x0 * im.pixelM, im.world.maxY - (y0 + side) * im.pixelM, im.world.minX + (x0 + side) * im.pixelM, im.world.maxY - y0 * im.pixelM));
  }

  static Future<ui.Image?> _image(Uint8List rgba, int w, int h) {
    final done = Completer<ui.Image?>();
    try {
      ui.decodeImageFromPixels(rgba, w, h, ui.PixelFormat.rgba8888, done.complete);
    } catch (_) {
      done.complete(null);
    }
    return done.future.timeout(const Duration(seconds: 5), onTimeout: () => null);
  }

  // ------------------------------------------------------------ applying

  void _apply() {
    final r = _result, f = _field;
    if (r == null || f == null || !r.found || _busy) return;
    final t = c.t;
    final rows = _applyRows && f.area != null, cover = _applyCover && f.area != null && r.groundCover != null;
    final made = c.mutate(
      () => applyCropRows(c.project, f.entity, r, rows: rows, cover: cover, guides: _applyGuides),
      label: 'row.hist',
    );
    if (made == null) return;
    if (made.isNotEmpty) c.select(made.map((e) => e.id));
    c.notify(t('row.applied', {'d': fmtUi(r.directionDeg, 1), 's': _len(r.spacingM), 'n': '${made.length}'}));
    Navigator.pop(context);
  }

  // ------------------------------------------------------------ units

  String _len(double m, [int? decimals]) {
    final u = c.units;
    final v = u.lengthFromSi(m);
    return '${fmtUi(v, decimals ?? (v.abs() >= 100 ? 0 : 2))} ${u.lengthLabel}';
  }

  String _message(CropRowMessage m) {
    String arg(String k, double v) => switch (k) {
      'n' => '${v.round()}',
      'p' => fmtUi(v, 1),
      _ => _len(v),
    };
    return c.t('row.msg.${m.code}', {for (final e in m.args.entries) e.key: arg(e.key, e.value)});
  }

  // ------------------------------------------------------------ view

  @override
  Widget build(BuildContext context) {
    final t = c.t;
    final f = _field;
    if (f == null) {
      return AlertDialog(
        title: Text(t('row.title'), style: const TextStyle(fontSize: 15)),
        content: SizedBox(
          width: dialogWidth(context, 460),
          child: ScrollBody(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _note(t('row.hint')),
                const SizedBox(height: 8),
                Text(
                  t('row.noArea'),
                  key: const Key('row_no_area'),
                  style: TextStyle(fontSize: 12.5, color: Cad.warning),
                ),
              ],
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(t('close')))],
      );
    }
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final pictures = _pictures(context, wide);
    final inputs = _inputs(f);
    final results = _results(f);
    Widget col(List<Widget> ws) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: ws);
    final r = _result;
    final canApply = r != null && r.found && !_busy && !_stale && (_applyGuides || (f.area != null && (_applyRows || (_applyCover && r.groundCover != null))));
    return AlertDialog(
      title: Text(t('row.title'), style: const TextStyle(fontSize: 15)),
      content: wide
          ? SizedBox(
              width: dialogWidth(context, 980),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: ScrollBody(child: col([...inputs, ...results]))),
                  const SizedBox(width: 16),
                  SizedBox(width: 420, child: ScrollBody(child: col(pictures))),
                ],
              ),
            )
          // on a narrow screen the picture first, then the rest
          : SizedBox(
              width: dialogWidth(context, 560),
              child: ScrollBody(child: col([...pictures, ...inputs, ...results])),
            ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(t('cancel'))),
        FilledButton(key: const Key('row_apply'), onPressed: canApply ? _apply : null, child: Text(t('row.apply'))),
      ],
    );
  }

  Widget _note(String s, {Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Text(s, style: TextStyle(fontSize: 11.5, color: color ?? Cad.fg70)),
  );

  List<Widget> _inputs(CropRowField f) {
    final t = c.t, u = c.units;
    final narrow = MediaQuery.sizeOf(context).width < 600;
    Widget row(List<Widget> ws) => narrow
        ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: ws)
        : Row(
            children: [
              for (var i = 0; i < ws.length; i++) ...[if (i > 0) const SizedBox(width: 8), Expanded(child: ws[i])],
            ],
          );
    final name = f.entity.name.isEmpty ? f.entity.id : f.entity.name;
    final areaM2 = (polygonArea(f.outline).abs() - f.holes.fold(0.0, (s, h) => s + polygonArea(h).abs())).clamp(0.0, double.infinity);
    return [
      _note(t('row.hint')),
      _note(t('row.field', {'n': name, 'a': '${fmtUi(u.areaFromSi(areaM2.toDouble()), 2)} ${u.areaLabel}'}), color: Cad.fg),
      if (_photos.isNotEmpty)
        SpecDropdown<String>(
          key: const Key('row_source'),
          label: t('row.source'),
          value: _source,
          items: ['map', for (final p in _photos) p.id],
          labelOf: (id) {
            final p = _photos.where((e) => e.id == id).firstOrNull;
            return p == null ? t('row.source.map') : t('row.source.image', {'n': p.name.isEmpty ? p.id : p.name});
          },
          idOf: (id) => id,
          onChanged: (v) {
            if (v == null || v == _source) return;
            setState(() => _source = v);
            unawaited(_detect());
          },
        ),
      row([
        NumField(
          key: const Key('row_min'),
          label: t('row.minSpacing', {'u': u.lengthLabel}),
          value: u.lengthFromSi(_minS),
          onChanged: (v) => setState(() => _minS = u.lengthToSi(v) > 0 ? u.lengthToSi(v) : _minS),
        ),
        NumField(
          key: const Key('row_max'),
          label: t('row.maxSpacing', {'u': u.lengthLabel}),
          value: u.lengthFromSi(_maxS),
          onChanged: (v) => setState(() => _maxS = u.lengthToSi(v) > 0 ? u.lengthToSi(v) : _maxS),
        ),
      ]),
      SwitchListTile(
        key: const Key('row_other_band'),
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(t('row.otherBand'), style: const TextStyle(fontSize: 12)),
        subtitle: Text(t('row.otherBandHint'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
        value: _otherBand,
        onChanged: _busy
            ? null
            : (v) {
                setState(() => _otherBand = v);
                // the pixels are kept: only the reading runs again
                unawaited(_detect());
              },
      ),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (_busy)
            OutlinedButton.icon(key: const Key('row_stop'), onPressed: _stop, icon: const Icon(Icons.stop, size: 16), label: Text(t('row.stop')))
          else
            FilledButton.tonalIcon(key: const Key('row_detect'), onPressed: () => unawaited(_detect()), icon: const Icon(Icons.image_search, size: 16), label: Text(t('row.detect'))),
          if (_busy)
            Text(
              _reading ? t('row.reading') : t('row.analysing', {'p': fmtUi(_progress * 100, 0)}),
              key: const Key('row_progress'),
              style: TextStyle(fontSize: 11.5, color: Cad.fg70),
            ),
          if (_stopped && !_busy) Text(t('row.stopped'), style: TextStyle(fontSize: 11.5, color: Cad.fg54)),
        ],
      ),
      if (_busy)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: LinearProgressIndicator(minHeight: 2, value: _reading ? null : _progress),
        ),
      if (_source == 'map') _note(t('veg.licence'), color: Cad.fg54),
    ];
  }

  List<Widget> _results(CropRowField f) {
    final t = c.t;
    final r = _result;
    final px = _pixels;
    if (_error != null) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            _error!,
            key: const Key('row_error'),
            style: TextStyle(fontSize: 12, color: Cad.warning),
          ),
        ),
      ];
    }
    if (r == null) return const [];
    final conf = fmtUi(r.confidence * 100, 0);
    final (confText, confColour) = switch (r.verdict) {
      CropRowVerdict.rows => (t('row.conf.rows', {'p': conf}), Cad.ok),
      CropRowVerdict.uncertain => (t('row.conf.uncertain', {'p': conf}), Cad.warning),
      _ => (t('row.conf.none', {'p': conf}), Cad.warning),
    };
    final messages = [
      for (final m in r.messages) _message(m),
      if (px != null && px.frame.window) _message(CropRowMessage('window', {'a': px.frame.world.width, 'b': px.frame.world.height})),
    ];
    final area = f.area;
    return [
      SectionTitle(t('auto.summary')),
      if (r.found) ...[
        KV(t('row.direction'), t('row.directionValue', {'d': fmtUi(r.directionDeg, 1)})),
        KV(t('row.spacing'), _len(r.spacingM)),
        KV(t('row.rows'), '${r.rows}'),
      ],
      KV(t('row.confidence'), confText, color: confColour),
      if (r.found) ...[
        KV(t('row.plant'), r.plantSpacingM == null ? t('row.notVisible') : _len(r.plantSpacingM!)),
        KV(t('row.cover'), r.groundCover == null ? t('row.notVisible') : '${fmtUi(r.groundCover! * 100, 0)} %'),
      ],
      if (px != null) KV(t('veg.resolution'), '${_len(r.resolutionM, 2)} · ${px.raster.width} × ${px.raster.height} px'),
      if (messages.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            messages.map((m) => '• $m').join('\n'),
            key: const Key('row_messages'),
            style: TextStyle(fontSize: 11, color: Cad.warning),
          ),
        ),
      if (r.found) ...[
        SectionTitle(t('row.applyTitle')),
        if (area == null) _note(t('row.areaOnly'), color: Cad.fg54),
        _check(const Key('row_apply_rows'), t('row.apply.rows'), _applyRows && area != null, area == null ? null : (v) => setState(() => _applyRows = v)),
        _check(
          const Key('row_apply_cover'),
          t('row.apply.cover', {'p': r.groundCover == null ? '—' : fmtUi(r.groundCover! * 100, 0)}),
          _applyCover && area != null && r.groundCover != null,
          area == null || r.groundCover == null ? null : (v) => setState(() => _applyCover = v),
        ),
        _check(const Key('row_apply_guides'), t('row.apply.guides', {'l': cropRowLayer}), _applyGuides, (v) => setState(() => _applyGuides = v)),
      ],
    ];
  }

  Widget _check(Key key, String label, bool value, ValueChanged<bool>? onChanged) => CheckboxListTile(
    key: key,
    dense: true,
    contentPadding: EdgeInsets.zero,
    controlAffinity: ListTileControlAffinity.leading,
    title: Text(label, style: const TextStyle(fontSize: 12)),
    value: value,
    onChanged: onChanged == null ? null : (v) => onChanged(v ?? false),
  );

  /// The overview and the detail with the field and the rows over them.
  List<Widget> _pictures(BuildContext context, bool wide) {
    final t = c.t;
    final r = _result;
    final lines = r?.rowLines ?? const <List<Pt>>[];
    final f = _field!;
    final maxH = wide ? 340.0 : math.min(260.0, MediaQuery.sizeOf(context).height * 0.32);
    Widget frame(Key key, _Shot? shot, double aspect, double maxHeight, {bool thick = false}) => LayoutBuilder(
      builder: (context, box) {
        var w = box.maxWidth, h = w / aspect;
        if (h > maxHeight) {
          h = maxHeight;
          w = h * aspect;
        }
        return Center(
          child: SizedBox(
            key: key,
            width: w,
            height: h,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Cad.insetDeep,
                border: Border.all(color: Cad.fg24),
              ),
              child: shot == null
                  ? Center(
                      child: _busy || _reading
                          ? const SizedBox(width: 120, child: LinearProgressIndicator(minHeight: 2))
                          : (_error != null ? Icon(Icons.image_not_supported_outlined, color: Cad.fg54) : const SizedBox()),
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        RawImage(image: shot.image, fit: BoxFit.fill, filterQuality: thick ? FilterQuality.none : FilterQuality.medium),
                        CustomPaint(painter: _RowsPainter(shot.world, f.outline, f.holes, lines, thick: thick)),
                        if (_busy && !_reading) const Align(alignment: Alignment.topCenter, child: LinearProgressIndicator(minHeight: 2)),
                      ],
                    ),
            ),
          ),
        );
      },
    );
    final ov = _overview;
    return [
      frame(const Key('row_preview'), ov, ov == null ? 4 / 3 : ov.world.width / ov.world.height, maxH),
      if (_detail != null) ...[
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 2),
          child: Text(t('row.detail'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
        ),
        frame(const Key('row_detail'), _detail, 1, wide ? 220 : 180, thick: true),
      ],
      if (_pixels != null && _pixels!.credit.isNotEmpty) _note(_pixels!.credit, color: Cad.fg54),
    ];
  }
}

/// The field outline (cyan) and the rows (amber) over a picture of [world].
class _RowsPainter extends CustomPainter {
  _RowsPainter(this.world, this.outline, this.holes, this.lines, {this.thick = false});
  final Bounds world;
  final List<Pt> outline;
  final List<List<Pt>> holes;
  final List<List<Pt>> lines;
  final bool thick;

  @override
  void paint(Canvas canvas, Size size) {
    Offset at(Pt p) => Offset((p.x - world.minX) / world.width * size.width, (world.maxY - p.y) / world.height * size.height);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final ring = Paint()
      ..color = _outlineColour
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final r in [outline, ...holes]) {
      if (r.length < 3) continue;
      canvas.drawPath(Path()..addPolygon([for (final p in r) at(p)], true), ring);
    }
    final ink = Paint()
      ..color = _rowColour
      ..style = PaintingStyle.stroke
      ..strokeWidth = thick ? 1.6 : 0.9;
    final path = Path();
    final b = world;
    for (final l in lines) {
      if (l.length < 2 || !Bounds.ofPoints(l).intersects(b)) continue;
      final a = at(l.first), z = at(l.last);
      path
        ..moveTo(a.dx, a.dy)
        ..lineTo(z.dx, z.dy);
    }
    canvas.drawPath(path, ink);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RowsPainter old) => !identical(old.lines, lines) || old.world != world || !identical(old.outline, outline);
}
