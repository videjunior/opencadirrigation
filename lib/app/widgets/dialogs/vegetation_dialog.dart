/// Vegetation detection (Design → Automatic design → Detect vegetation): the
/// lawns, trees and shrubs of the base map on screen or of a selected aerial
/// photo, found by image processing on this device (engine module
/// `vegetation.dart`), shown live over the image and generated as irrigated
/// areas (and the exclusions inside them) in one undo step.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../core/design/vegetation.dart';
import '../../../core/model/entities.dart';
import '../../../core/model/geometry.dart';
import '../../../core/units.dart';
import '../../state/controller.dart';
import '../../theme.dart';
import '../fields.dart';
import 'terrain_dialogs.dart' show dialogWidth;

/// Where the pixels come from.
enum VegetationSource { baseMap, image }

/// Base maps that are photographs (the others are drawn maps: their green
/// is a park symbol, not grass).
const _imagery = {BaseMap.satellite, BaseMap.googleSatellite, BaseMap.googleHybrid, BaseMap.custom};

// drawn over the photograph, so the same in both themes
const _turfColour = Color(0xFFB2FF59), _treesColour = Color(0xFF1DE9B6), _leftOutColour = Color(0xFFFFD740), _exclusionColour = Color(0xFFFFA726);

/// Opens the vegetation detection dialog.
Future<void> showVegetationDialog(BuildContext context, ProjectController c) => showDialog<void>(
  context: context,
  builder: (_) => VegetationDialog(controller: c),
);

class VegetationDialog extends StatefulWidget {
  const VegetationDialog({super.key, required this.controller});
  final ProjectController controller;

  @override
  State<VegetationDialog> createState() => _VegetationDialogState();
}

/// A source that cannot give pixels, with the reason (i18n key).
class _Unavailable implements Exception {
  const _Unavailable(this.key, [this.args = const {}]);
  final String key;
  final Map<String, String> args;
}

class _VegetationDialogState extends State<VegetationDialog> {
  ProjectController get c => widget.controller;

  /// The aerial photo selected in the drawing, if any (with its pixels).
  late final ImageEntity? _photo = c.project.entities.whereType<ImageEntity>().where((e) => c.selection.contains(e.id) && e.data != null).firstOrNull;
  late VegetationSource _source = _photo != null ? VegetationSource.image : VegetationSource.baseMap;
  final _o = VegetationOptions();
  final Map<VegetationSource, VegetationImage> _prepared = {};

  bool _loading = false;
  String? _error;
  VegetationResult? _result;
  String? _resultKey;

  /// Outlines of the result in raster fractions, for the preview.
  List<(List<Offset>, Color)> _outlines = const [];
  ui.Image? _preview;
  Timer? _debounce;
  int _loadGen = 0, _previewGen = 0;

  @override
  void initState() {
    super.initState();
    // the dialog shows first, then the pixels are read
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _loadGen++;
    _previewGen++;
    _preview?.dispose();
    super.dispose();
  }

  VegetationImage? get _image => _prepared[_source];
  String get _key => '${_source.name}|${_o.key}';
  bool get _stale => _result != null && _resultKey != _key;

  // ------------------------------------------------------------ pixels

  /// Reads and analyses the pixels of the source (kept for the session: the
  /// settings only run the detection again).
  Future<void> _load({bool again = false}) async {
    final source = _source;
    if (again) _prepared.remove(source);
    if (_prepared.containsKey(source)) {
      _run();
      return;
    }
    final gen = ++_loadGen;
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
      _resultKey = null;
      _outlines = const [];
      _setPreview(null);
    });
    try {
      final (bytes, corners) = await _pixels(source);
      // let the progress bar paint before the decoding takes the thread
      await Future<void>.delayed(const Duration(milliseconds: 16));
      if (!mounted || gen != _loadGen) return;
      final im = await _decode(bytes, corners);
      if (!mounted || gen != _loadGen) return;
      _prepared[source] = im;
      _loading = false;
      _run();
    } catch (e) {
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _loading = false;
        _error = e is _Unavailable ? c.t(e.key, e.args) : c.describeError(e);
      });
    }
  }

  /// Where the satellite base map is turned on (for the messages).
  Map<String, String> get _mapMenu => {'m': c.t('view.baseMap.satellite'), 'v': c.t('menu.view'), 'b': c.t('view.baseMap')};

  /// Encoded pixels of [source] and the world corners of the image.
  Future<(Uint8List, List<Pt>)> _pixels(VegetationSource source) async {
    if (source == VegetationSource.image) {
      final e = _photo, data = e?.data;
      if (e == null || data == null) throw const _Unavailable('veg.noPhoto');
      return (data, e.corners);
    }
    final snap = c.baseMapSnapshot;
    (Uint8List, List<Pt>)? got;
    if (snap != null) {
      try {
        got = await snap();
      } catch (_) {
        got = null; // a tile the browser may not read: as no map
      }
    }
    if (got != null) return got;
    if (c.project.meta.georef == null) throw _Unavailable('veg.noGeoref', {'f': c.t('menu.file'), 'g': c.t('file.georef')});
    if (c.baseMap == BaseMap.none) throw _Unavailable('veg.noMap', _mapMenu);
    throw const _Unavailable('veg.mapUnreadable');
  }

  /// Decodes [bytes] to the working raster. On the web through the browser's
  /// decoder, straight to about twice the working size (far faster than
  /// decoding a large photo in Dart, and lighter on memory), the block
  /// averaging of the engine doing the rest; elsewhere, or when that fails,
  /// with the engine's own decoder.
  static Future<VegetationImage> _decode(Uint8List bytes, List<Pt> corners) async {
    if (kIsWeb) {
      try {
        final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
        final codec = await ui.instantiateImageCodecWithSize(
          buffer,
          getTargetSize: (w, h) {
            final (tw, th) = VegetationImage.workingSize(w, h, corners);
            return ui.TargetImageSize(width: math.min(w, 2 * tw), height: math.min(h, 2 * th));
          },
        );
        final frame = await codec.getNextFrame();
        final image = frame.image;
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final w = image.width, h = image.height;
        image.dispose();
        codec.dispose();
        if (data != null) return VegetationImage.fromPixels(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), w, h, corners);
      } catch (_) {
        // the engine's decoder below
      }
    }
    return VegetationImage.fromEncoded(bytes, corners);
  }

  // ------------------------------------------------------------ detection

  /// A setting changed: the detection runs again once the user pauses.
  void _changed(VoidCallback f) {
    setState(f);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) _run();
    });
  }

  void _run() {
    _debounce?.cancel();
    final im = _image;
    if (im == null) return;
    final key = _key;
    if (key == _resultKey && _result != null) return;
    // an image placed in a drawing without georeference may not be to scale
    final georeferenced = _source == VegetationSource.baseMap || c.project.meta.georef != null;
    final VegetationResult r;
    try {
      r = detectVegetation(im, _o.copy(), georeferenced: georeferenced);
    } catch (e) {
      if (mounted) setState(() => _error = c.describeError(e));
      return;
    }
    _error = null;
    _result = r;
    _resultKey = key;
    _outlines = [
      for (final p in r.patches) ...[
        (_unit(im, p.outline), p.cls == VegetationClass.trees ? _treesColour : _turfColour),
        for (final h in p.holes)
          if (h.exclusion) (_unit(im, h.outline), _exclusionColour),
      ],
    ];
    _buildPreview(im, r);
    if (mounted) setState(() {});
  }

  static List<Offset> _unit(VegetationImage im, List<Pt> pts) => [
    for (final p in pts)
      () {
        final (u, v) = im.toUnit(p);
        return Offset(u, v);
      }(),
  ];

  void _buildPreview(VegetationImage im, VegetationResult r) {
    final gen = ++_previewGen;
    final (px, w, h) = vegetationPreview(im, r, maxSide: 640);
    try {
      ui.decodeImageFromPixels(px, w, h, ui.PixelFormat.rgba8888, (decoded) {
        if (!mounted || gen != _previewGen) {
          decoded.dispose();
          return;
        }
        setState(() => _setPreview(decoded));
      });
    } catch (_) {
      // no engine: the outlines alone
    }
  }

  void _setPreview(ui.Image? image) {
    final old = _preview;
    _preview = image;
    if (old != null && !identical(old, image)) old.dispose();
  }

  // ------------------------------------------------------------ generation

  void _create() {
    if (_stale) _run();
    final r = _result;
    if (r == null || r.patches.isEmpty) return;
    final t = c.t;
    final made = c.mutate(() {
      final out = vegetationEntities(c.project, r.patches, name: (cls) => t('veg.name.${cls.name}'), exclusionName: (area, n) => t('veg.name.exclusion', {'n': '$n', 'a': area}));
      c.project.entities.addAll(out);
      return out;
    }, label: 'hist.detectVegetation');
    if (made == null) return;
    c.select(made.map((e) => e.id));
    c.notify(t('veg.created', {'n': '${made.whereType<AreaEntity>().length}', 'x': '${made.whereType<PolylineEntity>().length}'}));
    Navigator.pop(context);
  }

  // ------------------------------------------------------------ units

  bool get _imperial => c.units.length == LengthUnit.ft || c.units.length == LengthUnit.inch;
  double _areaFrom(double m2) => _imperial ? m2 / (metersPerFoot * metersPerFoot) : m2;
  double _areaTo(double v) => _imperial ? v * metersPerFoot * metersPerFoot : v;
  String get _areaLabel => _imperial ? 'ft²' : 'm²';
  String _surface(double m2) => '${fmt(_areaFrom(m2), _areaFrom(m2) >= 100 ? 0 : 1)} $_areaLabel';

  // ------------------------------------------------------------ view

  @override
  Widget build(BuildContext context) {
    final t = c.t;
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final r = _result;
    final n = r?.patches.length ?? 0;
    final inputs = _inputs(context);
    final summary = [_previewBox(context, wide), ..._summary(context)];
    Widget col(List<Widget> ws) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: ws);
    return AlertDialog(
      title: Text(t('veg.title'), style: const TextStyle(fontSize: 15)),
      content: wide
          ? SizedBox(
              width: dialogWidth(context, 1000),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: ScrollBody(child: col(inputs))),
                  const SizedBox(width: 16),
                  SizedBox(width: 440, child: ScrollBody(child: col(summary))),
                ],
              ),
            )
          // on a narrow screen the picture first, then the settings
          : SizedBox(
              width: dialogWidth(context, 580),
              child: ScrollBody(child: col([summary.first, ...inputs, ...summary.skip(1)])),
            ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(t('cancel'))),
        FilledButton(
          key: const Key('veg_create'),
          onPressed: n == 0 || _loading
              ? null
              : () {
                  // the field being typed in commits on focus loss, in a microtask
                  FocusManager.instance.primaryFocus?.unfocus();
                  Future<void>.delayed(Duration.zero, () {
                    if (mounted) _create();
                  });
                },
          child: Text(t('veg.create', {'n': '$n'})),
        ),
      ],
    );
  }

  List<Widget> _inputs(BuildContext context) {
    final t = c.t, u = c.units;
    final im = _image, photo = _photo;
    final auto = im?.autoThreshold;
    Widget note(String s, {Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(s, style: TextStyle(fontSize: 11.5, color: color ?? Cad.fg70)),
    );
    // side by side, but one under the other on a phone (the labels would be cut)
    final narrow = MediaQuery.sizeOf(context).width < 600;
    Widget row(List<Widget> ws) => narrow
        ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: ws)
        : Row(
            children: [
              for (var i = 0; i < ws.length; i++) ...[if (i > 0) const SizedBox(width: 8), Expanded(child: ws[i])],
            ],
          );
    return [
      note(t('veg.hint')),
      row([
        SpecDropdown<VegetationSource>(
          key: const Key('veg_source'),
          label: t('veg.source'),
          value: _source.name,
          items: [VegetationSource.baseMap, if (photo != null) VegetationSource.image],
          labelOf: (s) => s == VegetationSource.image && photo != null ? t('veg.source.image', {'n': photo.name.isEmpty ? photo.id : photo.name}) : t('veg.source.map'),
          idOf: (s) => s.name,
          onChanged: (v) {
            final s = VegetationSource.values.byName(v ?? _source.name);
            if (s == _source) return;
            setState(() => _source = s);
            _load();
          },
        ),
      ]),
      if (_source == VegetationSource.baseMap) ...[
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('veg_reload'),
            onPressed: _loading ? null : () => _load(again: true),
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(t('veg.reload'), style: const TextStyle(fontSize: 12)),
          ),
        ),
        if (photo == null) note(t('veg.photoHint'), color: Cad.fg54),
        if (c.baseMap != BaseMap.none && !_imagery.contains(c.baseMap)) note(t('veg.notImagery', _mapMenu), color: Cad.warning),
        note(t('veg.licence'), color: Cad.fg54),
      ],
      SectionTitle(t('veg.detection')),
      Text(auto == null ? t('veg.thresholdTitle') : t('veg.threshold', {'t': fmt(auto + _o.thresholdOffset, 3), 'a': fmt(auto, 3)}), style: const TextStyle(fontSize: 12)),
      Slider(
        key: const Key('veg_threshold'),
        value: _o.thresholdOffset.clamp(-0.15, 0.15).toDouble(),
        min: -0.15,
        max: 0.15,
        divisions: 60,
        label: '${_o.thresholdOffset >= 0 ? '+' : ''}${fmt(_o.thresholdOffset, 3)}',
        onChanged: (v) => _changed(() => _o.thresholdOffset = v),
      ),
      note(t('veg.thresholdHint'), color: Cad.fg54),
      SwitchListTile(
        key: const Key('veg_split'),
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(t('veg.split'), style: const TextStyle(fontSize: 12)),
        value: _o.split,
        onChanged: (v) => _changed(() => _o.split = v),
      ),
      if (_o.split) ...[
        Wrap(
          spacing: 6,
          runSpacing: 2,
          children: [
            FilterChip(
              key: const Key('veg_turf'),
              label: Text(t('veg.class.turf'), style: const TextStyle(fontSize: 11.5)),
              selected: _o.keepTurf,
              onSelected: (v) => _changed(() => _o.keepTurf = v),
            ),
            FilterChip(
              key: const Key('veg_trees'),
              label: Text(t('veg.class.trees'), style: const TextStyle(fontSize: 11.5)),
              selected: _o.keepTrees,
              onSelected: (v) => _changed(() => _o.keepTrees = v),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(t('veg.treeLimit'), style: const TextStyle(fontSize: 12)),
        Slider(
          key: const Key('veg_tree_limit'),
          // to the right more trees and shrubs: a lower canopy limit
          value: (-_o.treeBias).clamp(-0.5, 0.5).toDouble(),
          min: -0.5,
          max: 0.5,
          divisions: 20,
          label: fmt(-_o.treeBias, 2),
          onChanged: (v) => _changed(() => _o.treeBias = -v),
        ),
        note(t('veg.treeLimitHint'), color: Cad.fg54),
      ],
      SectionTitle(t('veg.outlines')),
      row([
        NumField(
          key: const Key('veg_min_area'),
          label: t('veg.minArea', {'u': _areaLabel}),
          value: _areaFrom(_o.minAreaM2),
          decimals: 1,
          onChanged: (v) => _changed(() => _o.minAreaM2 = math.max(0, _areaTo(v))),
        ),
        NumField(
          key: const Key('veg_min_hole'),
          label: t('veg.minHole', {'u': _areaLabel}),
          value: _areaFrom(_o.minHoleM2),
          decimals: 1,
          onChanged: (v) => _changed(() => _o.minHoleM2 = math.max(0, _areaTo(v))),
        ),
      ]),
      NumField(
        key: const Key('veg_simplify'),
        label: t('veg.simplify', {'u': u.lengthLabel}),
        value: u.lengthFromSi(_o.simplifyM),
        onChanged: (v) => _changed(() => _o.simplifyM = math.max(0, u.lengthToSi(v))),
      ),
      ExpansionTile(
        key: const Key('veg_advanced'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        title: Text(t('veg.advanced'), style: const TextStyle(fontSize: 12.5)),
        children: [
          row([
            NumField(
              key: const Key('veg_clean'),
              label: t('veg.open', {'u': u.lengthLabel}),
              value: u.lengthFromSi(_o.cleanM),
              onChanged: (v) => _changed(() => _o.cleanM = math.max(0, u.lengthToSi(v))),
            ),
            NumField(
              key: const Key('veg_canopy_clean'),
              label: t('veg.close', {'u': u.lengthLabel}),
              value: u.lengthFromSi(_o.canopyCleanM),
              onChanged: (v) => _changed(() => _o.canopyCleanM = math.max(0, u.lengthToSi(v))),
            ),
          ]),
          NumField(key: const Key('veg_smooth'), label: t('veg.smoothing'), value: _o.smoothing.toDouble(), decimals: 0, onChanged: (v) => _changed(() => _o.smoothing = v.round().clamp(0, 10))),
          note(t('veg.advancedHint'), color: Cad.fg54),
        ],
      ),
    ];
  }

  /// The image with the classes tinted and the outlines drawn over it.
  Widget _previewBox(BuildContext context, bool wide) {
    final im = _image;
    final aspect = im == null ? 4 / 3 : im.width / im.height;
    final maxH = wide ? 360.0 : math.min(280.0, MediaQuery.sizeOf(context).height * 0.35);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: LayoutBuilder(
        builder: (context, box) {
          var w = box.maxWidth, h = w / aspect;
          if (h > maxH) {
            h = maxH;
            w = h * aspect;
          }
          return Center(
            child: SizedBox(
              key: const Key('veg_preview'),
              width: w,
              height: h,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Cad.insetDeep,
                  border: Border.all(color: Cad.fg24),
                ),
                child: _loading
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 120, child: LinearProgressIndicator(minHeight: 2)),
                            const SizedBox(height: 6),
                            Text(c.t('veg.reading'), style: TextStyle(fontSize: 11.5, color: Cad.fg70)),
                          ],
                        ),
                      )
                    : _error != null
                    // why there is no picture, where the picture would be
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: Center(
                          child: SingleChildScrollView(
                            child: Text(
                              _error!,
                              key: const Key('veg_error'),
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: Cad.warning),
                            ),
                          ),
                        ),
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          if (_preview != null) RawImage(image: _preview, fit: BoxFit.fill, filterQuality: FilterQuality.medium),
                          CustomPaint(painter: _OutlinePainter(_outlines)),
                          if (_stale) const Align(alignment: Alignment.topCenter, child: LinearProgressIndicator(minHeight: 2)),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _summary(BuildContext context) {
    final t = c.t;
    final im = _image, r = _result;
    Widget legend(Color colour, String label, {bool line = false}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: line ? 3 : 10, color: colour),
        const SizedBox(width: 4),
        Flexible(
          child: Text(label, style: TextStyle(fontSize: 11, color: Cad.fg70)),
        ),
      ],
    );
    return [
      if (r != null && im != null) ...[
        Wrap(
          spacing: 10,
          runSpacing: 2,
          children: [
            if (_o.split) ...[
              if (_o.keepTurf) legend(_turfColour, t('veg.class.turf')),
              if (_o.keepTrees) legend(_treesColour, t('veg.class.trees')),
            ] else
              legend(_turfColour, t('veg.class.vegetation')),
            legend(_leftOutColour, t('veg.leftOut')),
            legend(_exclusionColour, t('veg.exclusions'), line: true),
          ],
        ),
        SectionTitle(t('auto.summary')),
        KV(t('veg.resolution'), '${fmt(im.pixelSizeM * 100, 1)} cm · ${im.width} × ${im.height} px'),
        KV(t('veg.vegetated'), '${fmt(r.vegetatedFraction * 100, 1)} %'),
        for (final cls in VegetationClass.values)
          if (r.of(cls).isNotEmpty) KV(t('veg.class.${cls.name}'), '${r.of(cls).length} · ${_surface(r.areaOf(cls))}'),
        if (r.exclusions.isNotEmpty) KV(t('veg.exclusions'), '${r.exclusions.length} · ${_surface(r.exclusions.fold(0.0, (s, h) => s + h.area))}'),
        if (r.dropped > 0) KV(t('veg.dropped'), '${r.dropped}'),
        if (r.patches.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(t('veg.none'), style: TextStyle(fontSize: 12, color: Cad.warning)),
          ),
        if (r.messages.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(r.messages.map((m) => '• ${t('warn.${m.code}', m.args)}').join('\n'), style: TextStyle(fontSize: 11, color: Cad.warning)),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(t('veg.after'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
        ),
      ],
    ];
  }
}

/// The outlines of the result over the preview, from raster fractions.
class _OutlinePainter extends CustomPainter {
  _OutlinePainter(this.outlines);
  final List<(List<Offset>, Color)> outlines;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round;
    for (final (pts, colour) in outlines) {
      if (pts.length < 2) continue;
      final path = Path()..moveTo(pts.first.dx * size.width, pts.first.dy * size.height);
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx * size.width, p.dy * size.height);
      }
      path.close();
      canvas.drawPath(path, paint..color = colour);
    }
  }

  @override
  bool shouldRepaint(_OutlinePainter old) => !identical(old.outlines, outlines);
}
