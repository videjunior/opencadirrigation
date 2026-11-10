/// Design → Digitise a curve from a picture (1.7.0, DGZ): a pump's
/// flow–head curve (with its efficiency, NPSH required and power), an
/// outlet's flow–pressure curve or a sprinkler's radial profile read off a
/// picture of a catalogue chart, by clicks or by following the curve's
/// colour, fitted the way the engine fits a data sheet and put into the
/// project's catalogue as one undo step. The maths is in
/// lib/core/design/curve_digitiser.dart, curve_trace.dart and
/// curve_fits.dart; the assistant reaches the same entries through the
/// operations of lib/app/ai/op_parts/dgz.dart.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/design/curve_digitiser.dart';
import '../../../core/design/curve_fits.dart';
import '../../../core/design/curve_trace.dart';
import '../../../core/model/catalog.dart';
import '../../../core/model/geometry.dart';
import '../../../core/units.dart';
import '../../io/file_drop.dart';
import '../../io/file_io.dart' show openBinaryFile;
import '../../ai/ops_eng_common.dart' show engFileSink;
import '../../project_name.dart';
import '../../state/controller.dart';
import '../../theme.dart';
import '../ai/ai_drop.dart';
import '../fields.dart';

/// Opens the digitiser of [c]; [picture] (named [name]) is loaded at once.
/// The picture and the work on it stay with the tab while the dialog is
/// closed.
Future<void> showCurveDigitiserDialog(BuildContext context, ProjectController c, {Uint8List? picture, String name = ''}) => showDialog<void>(
  context: context,
  builder: (_) => CurveDigitiserDialog(c: c, picture: picture, name: name),
);

/// The label of a curve of a chart.
String curveRoleLabel(ProjectController c, CurveRole r) => c.t('dgz.role.${r.name}');

/// The message of a calibration that gives no mapping.
String calibrationErrorText(ProjectController c, CalibrationError e) => c.t('dgz.err.${e.name}');

class CurveDigitiserDialog extends StatefulWidget {
  const CurveDigitiserDialog({super.key, required this.c, this.picture, this.name = ''});
  final ProjectController c;
  final Uint8List? picture;
  final String name;

  @override
  State<CurveDigitiserDialog> createState() => CurveDigitiserDialogState();
}

/// What the clicks on the picture do.
enum DigitiserMode { x, y, points, trace }

/// Where an outlet's curve goes.
enum _EmitterTarget { newOutlet, nozzle, tape }

/// The work of a tab, kept while the dialog is closed.
class _Memory {
  ChartRaster? raster;
  ui.Image? image;
  String name = '';
  DigitiserSession? session;
}

final _memory = Expando<_Memory>('curve digitiser');

/// What is being dragged.
class _Drag {
  _Drag.point(this.index) : axis = null, second = false;
  _Drag.calibration(this.axis, this.second) : index = -1;
  final int index;
  final DigitiserMode? axis;
  final bool second;
}

class CurveDigitiserDialogState extends State<CurveDigitiserDialog> implements AiDropTarget, AiPasteTarget {
  ProjectController get c => widget.c;

  late final _Memory _mem = _memory[c] ??= _Memory();
  ChartRaster? get raster => _mem.raster;
  late DigitiserSession _s = _mem.session ?? DigitiserSession.start(CurveKind.pump, units: c.units);

  /// The session (tests).
  DigitiserSession get session => _s;
  DigitiserMode mode = DigitiserMode.x;
  final List<DigitiserSession> _undo = [];
  bool _loading = false;
  String? _error;

  // the view: screen = pan + picture · zoom
  double _zoom = 1;
  Offset _pan = Offset.zero;
  Size? _canvasSize;
  bool _fitted = false;
  final _canvasKey = GlobalKey();
  final _dialogKey = GlobalKey();
  final _canvasFocus = FocusNode(debugLabel: 'digitiser canvas');

  // the gesture under way
  _Drag? _drag;
  double _startZoom = 1;
  Offset _startPan = Offset.zero, _startFocal = Offset.zero;

  /// Where the magnifier looks (and whether a finger holds it): repaints the
  /// picture alone, not the panel.
  final _lens = ValueNotifier<(Offset, bool)?>(null);
  bool _touch = false;
  int? _selected;

  // the trace
  double? _from, _to;
  int _count = 15;
  double _tolerance = 60;
  String? _traceMsg;

  // the target in the catalogue
  String? _pumpId;
  _EmitterTarget _emitterTarget = _EmitterTarget.newOutlet;
  OutletKind _outletKind = OutletKind.dripper;
  String? _nozzleRef, _tapeId, _profileRef;
  late String _name = widget.name.replaceFirst(RegExp(r'\.[A-Za-z0-9]+$'), '');
  String? _applied;

  @override
  void initState() {
    super.initState();
    if (_mem.session != null && _mem.raster != null) mode = _nextMode();
    AiFileDrop.instance.addPanel(this);
    AiFileDrop.instance.addBox(this);
    final pic = widget.picture;
    if (pic != null) {
      scheduleMicrotask(() => load(pic, widget.name));
    } else if (_mem.raster != null && _mem.image == null) {
      // closed before its picture was drawn: draw it now
      _decodeImage(_mem.raster!);
    }
  }

  @override
  void dispose() {
    _mem.session = _s;
    AiFileDrop.instance.removePanel(this);
    AiFileDrop.instance.removeBox(this);
    _canvasFocus.dispose();
    _lens.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- files

  @override
  Rect? get rect {
    final box = mounted ? _dialogKey.currentContext?.findRenderObject() as RenderBox? : null;
    if (box == null || !box.hasSize || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// A picture pasted while the dialog is open comes here (a text paste
  /// into its fields is left alone: only pastes of files are taken).
  @override
  bool get focused => mounted;

  @override
  Future<void> take(List<DroppedFile> files) async {
    for (final f in files) {
      final pic = f.type.startsWith('image/') || RegExp(r'\.(png|jpe?g|webp|gif|bmp)$', caseSensitive: false).hasMatch(f.name);
      if (!pic) continue;
      final bytes = await f.read();
      if (bytes != null && mounted) await load(bytes, f.name);
      return;
    }
    if (mounted) setState(() => _error = c.t('dgz.err.picture'));
  }

  Future<void> _open() async {
    final f = await openBinaryFile(accept: '.png,.jpg,.jpeg,.webp,.gif,.bmp');
    if (f == null || !mounted) return;
    await load(f.$2, f.$1);
  }

  /// Reads the picture [bytes]: the calibration and the curves start again
  /// (the kind of curve stays).
  Future<void> load(Uint8List bytes, String name) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    // the spinner shows before the decoding holds the page
    await Future<void>.delayed(const Duration(milliseconds: 20));
    ChartRaster r;
    try {
      r = ChartRaster.decode(bytes);
    } on FormatException {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = c.t('dgz.err.picture');
        });
      }
      return;
    }
    if (!mounted) return;
    _mem.image?.dispose();
    _mem
      ..raster = r
      ..image = null
      ..name = name;
    setState(() {
      _loading = false;
      _fitted = false;
      _undo.clear();
      _selected = null;
      _s = DigitiserSession.start(_s.kind, units: c.units, swapped: _s.swapped);
      _from = _to = null;
      _traceMsg = _applied = null;
      if (_name.isEmpty) _name = name.replaceFirst(RegExp(r'\.[A-Za-z0-9]+$'), '');
      mode = DigitiserMode.x;
    });
    await _decodeImage(r);
  }

  /// The picture of [r] for the screen (the same pixels the trace reads).
  Future<void> _decodeImage(ChartRaster r) async {
    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(r.rgba, r.width, r.height, ui.PixelFormat.rgba8888, done.complete);
    final im = await done.future;
    if (!identical(_mem.raster, r) || _mem.image != null) {
      im.dispose();
      return;
    }
    _mem.image = im;
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------- the session

  void _push() {
    _undo.add(_s.copy());
    if (_undo.length > 200) _undo.removeAt(0);
  }

  void undo() {
    if (_undo.isEmpty) return;
    setState(() {
      _s = _undo.removeLast();
      _selected = null;
    });
  }

  void setKind(CurveKind k) {
    if (k == _s.kind) return;
    _push();
    setState(() {
      _s = DigitiserSession.start(k, units: c.units);
      _selected = null;
      _applied = null;
      mode = raster == null ? DigitiserMode.x : _nextMode();
    });
  }

  void _setRole(CurveRole r) {
    setState(() {
      _s.current = r;
      _selected = null;
      mode = _nextMode();
    });
  }

  /// The step a click goes to now: the axes not yet clicked, then points.
  DigitiserMode _nextMode() {
    if (!_s.x.hasPoints) return DigitiserMode.x;
    if (!_s.active.y.hasPoints) return DigitiserMode.y;
    return mode == DigitiserMode.trace ? DigitiserMode.trace : DigitiserMode.points;
  }

  (ChartMapping?, CalibrationError?) get _mapping => _s.mapping();

  // ---------------------------------------------------------------- the view

  Pt _toPicture(Offset local) => Pt((local.dx - _pan.dx) / _zoom, (local.dy - _pan.dy) / _zoom);
  Offset _toScreen(Pt p) => Offset(_pan.dx + p.x * _zoom, _pan.dy + p.y * _zoom);

  /// Where picture point [p] is on the screen (global; tests).
  Offset screenOf(Pt p) {
    final box = _canvasKey.currentContext!.findRenderObject() as RenderBox;
    return box.localToGlobal(_toScreen(p));
  }

  void _fit(Size size) {
    final r = raster;
    if (r == null || size.isEmpty) return;
    _zoom = math.min(size.width / r.width, size.height / r.height) * 0.96;
    _pan = Offset((size.width - r.width * _zoom) / 2, (size.height - r.height * _zoom) / 2);
    _fitted = true;
  }

  void _zoomAt(Offset at, double k) {
    final z = (_zoom * k).clamp(0.02, 40.0);
    final p = _toPicture(at);
    setState(() {
      _zoom = z;
      _pan = Offset(at.dx - p.x * z, at.dy - p.y * z);
    });
  }

  double get _hitRadius => _touch ? 22 : 12;

  /// The mark under [local] that a drag moves in this mode.
  _Drag? _hit(Offset local) {
    bool near(Pt? p) => p != null && (_toScreen(p) - local).distance <= _hitRadius;
    switch (mode) {
      case DigitiserMode.x:
        if (near(_s.x.p1)) return _Drag.calibration(DigitiserMode.x, false);
        if (near(_s.x.p2)) return _Drag.calibration(DigitiserMode.x, true);
      case DigitiserMode.y:
        if (near(_s.active.y.p1)) return _Drag.calibration(DigitiserMode.y, false);
        if (near(_s.active.y.p2)) return _Drag.calibration(DigitiserMode.y, true);
      case DigitiserMode.points || DigitiserMode.trace:
        final i = _pointAt(local);
        if (i != null) return _Drag.point(i);
    }
    return null;
  }

  int? _pointAt(Offset local) {
    int? best;
    var bestD = _hitRadius;
    final pts = _s.active.pixels;
    for (var i = 0; i < pts.length; i++) {
      final d = (_toScreen(pts[i]) - local).distance;
      if (d <= bestD) {
        bestD = d;
        best = i;
      }
    }
    return best;
  }

  void _moveDrag(Offset local) {
    final d = _drag;
    if (d == null) return;
    final p = _toPicture(local);
    setState(() {
      _lens.value = (local, _touch);
      if (d.index >= 0) {
        if (d.index < _s.active.pixels.length) _s.active.pixels[d.index] = p;
      } else {
        final cal = d.axis == DigitiserMode.x ? _s.x : _s.active.y;
        if (d.second) {
          cal.p2 = p;
        } else {
          cal.p1 = p;
        }
      }
    });
  }

  /// A click (or a press held and let go) at [local] on the picture.
  void tapAt(Offset local) {
    if (raster == null) return;
    _canvasFocus.requestFocus();
    final p = _toPicture(local);
    switch (mode) {
      case DigitiserMode.x || DigitiserMode.y:
        final cal = mode == DigitiserMode.x ? _s.x : _s.active.y;
        _push();
        setState(() {
          // the second point of the axis moves on to the next step; with both
          // set, a click moves the nearer one and stays
          final completes = cal.p1 != null && cal.p2 == null;
          if (cal.p1 == null) {
            cal.p1 = p;
          } else if (cal.p2 == null) {
            cal.p2 = p;
          } else if (cal.p1!.distanceTo(p) <= cal.p2!.distanceTo(p)) {
            cal.p1 = p;
          } else {
            cal.p2 = p;
          }
          if (completes) mode = _nextMode();
        });
      case DigitiserMode.points:
        final hit = _pointAt(local);
        if (hit != null) {
          setState(() => _selected = hit);
          return;
        }
        _push();
        setState(() {
          _s.active.pixels.add(p);
          _selected = _s.active.pixels.length - 1;
        });
      case DigitiserMode.trace:
        _trace(p);
    }
  }

  void _deleteAt(Offset local) {
    final i = _pointAt(local);
    if (i == null) return;
    _push();
    setState(() {
      _s.active.pixels.removeAt(i);
      _selected = null;
    });
  }

  void deleteSelected() {
    final i = _selected;
    if (i == null || i >= _s.active.pixels.length) return;
    _push();
    setState(() {
      _s.active.pixels.removeAt(i);
      _selected = null;
    });
  }

  void _clear() {
    if (_s.active.pixels.isEmpty) return;
    _push();
    setState(() {
      _s.active.pixels.clear();
      _selected = null;
    });
  }

  (double, double) get _limits {
    final a = _s.x.v1 ?? 0, b = _s.x.v2 ?? 0;
    return (_from ?? math.min(a, b), _to ?? math.max(a, b));
  }

  void _trace(Pt seed) {
    final t = c.t;
    final r = raster;
    final (m, err) = _mapping;
    if (r == null) return;
    if (m == null) {
      setState(() => _traceMsg = calibrationErrorText(c, err!));
      return;
    }
    final (from, to) = _limits;
    final out = traceCurve(
      r,
      m,
      seed,
      from: from,
      to: to,
      settings: TraceSettings(tolerance: _tolerance),
    );
    if (out.track == null) {
      setState(() => _traceMsg = t(out.error == TraceError.background ? 'dgz.trace.background' : 'dgz.trace.none'));
      return;
    }
    final pts = sampleTrack(out.track!, m, from: from, to: to, count: _count);
    if (pts.isEmpty) {
      setState(() => _traceMsg = t('dgz.trace.none'));
      return;
    }
    _push();
    setState(() {
      _s.active.pixels
        ..clear()
        ..addAll(pts);
      _selected = null;
      _traceMsg = t('dgz.trace.done', {'n': '${pts.length}', 'm': '${_count - pts.length}'});
    });
  }

  // ---------------------------------------------------------------- fits

  PumpChartFit _pumpFit() => fitPumpChart(head: _s.si(CurveRole.head), efficiency: _s.si(CurveRole.efficiency), npsh: _s.si(CurveRole.npsh), power: _s.si(CurveRole.power));
  EmitterChartFit _emitterFit() => fitEmitterChart(_s.si(CurveRole.flowPressure));
  ProfileChartFit _profileFit() => fitProfileChart(_s.si(CurveRole.profile));

  /// The fitted curve of the active series, in picture pixels.
  List<Pt> _fitLine() {
    final (m, _) = _mapping;
    if (m == null) return const [];
    final xu = _s.xUnit, yu = _s.active.yUnit;
    Pt? at(double xSi, double ySi) => m.pixelOf(xu.fromSi(xSi), yu.fromSi(ySi));
    List<Pt> sample(double a, double b, (double, double)? Function(double v) f) => [
      for (var i = 0; i <= 48; i++)
        if (f(a + (b - a) * i / 48) case final xy?) ?at(xy.$1, xy.$2),
    ];
    switch (_s.current) {
      case CurveRole.head:
        final f = _pumpFit();
        final curve = f.curve;
        if (curve == null) return const [];
        return sample(f.head.first.$1, f.head.last.$1, (q) => (q, curve.head(q)));
      case CurveRole.flowPressure:
        final f = _emitterFit();
        if (!f.isUsable) return const [];
        return sample(f.minHead, f.maxHead, (h) => _s.swapped ? (f.curve.flow(h), h) : (h, f.curve.flow(h)));
      case CurveRole.efficiency || CurveRole.npsh || CurveRole.power || CurveRole.profile:
        // kept as the catalogue keeps them: straight between the points
        return [for (final (x, y) in _s.values()) ?m.pixelOf(x, y)];
    }
  }

  bool get _canApply => switch (_s.kind) {
    CurveKind.pump => _pumpId == null ? _pumpFit().head.length >= minPumpHeadPoints : !_pumpFit().isEmpty,
    CurveKind.emitter =>
      _emitterFit().isUsable && (_emitterTarget == _EmitterTarget.newOutlet || (_emitterTarget == _EmitterTarget.nozzle ? _nozzle(_nozzleRef) != null : c.project.catalog.tape(_tapeId) != null)),
    CurveKind.profile => _profileFit().isUsable && _nozzle(_profileRef) != null,
  };

  (OutletSpec, NozzleSpec)? _nozzle(String? ref, [Catalog? cat]) {
    if (ref == null) return null;
    final i = ref.indexOf('|');
    if (i < 0) return null;
    final o = (cat ?? c.project.catalog).outlet(ref.substring(0, i));
    final n = o?.nozzle(ref.substring(i + 1));
    if (o == null || n == null || n.id != ref.substring(i + 1)) return null;
    return (o, n);
  }

  List<(OutletSpec, NozzleSpec)> get _nozzles => [
    for (final o in c.project.catalog.outlets)
      for (final n in o.nozzles) (o, n),
  ];

  /// The nozzle's name of a new outlet: its flow at the middle of the
  /// chart's pressures.
  String _nozzleName(EmitterChartFit f) {
    final u = c.units;
    final h = (f.minHead + f.maxHead) / 2;
    final fu = _s.swapped ? _s.xUnit : _s.active.yUnit;
    return '${fmt(fu.fromSi(f.curve.flow(h)), 2)} ${fu.label} @ ${fmt(u.pressureFromHead(h), 2)} ${u.pressureLabel}';
  }

  /// Puts the curves into the catalogue: one undo step.
  void apply() {
    final t = c.t;
    final cat = c.project.catalog;
    final String label;
    switch (_s.kind) {
      case CurveKind.pump:
        label = _pumpId == null ? (_name.trim().isEmpty ? t('tool.pump') : _name.trim()) : (cat.pump(_pumpId)?.name ?? '');
      case CurveKind.emitter:
        label = switch (_emitterTarget) {
          _EmitterTarget.newOutlet => _name.trim().isEmpty ? t('tool.outlet') : _name.trim(),
          _EmitterTarget.nozzle => _nozzle(_nozzleRef)?.$1.name ?? '',
          _EmitterTarget.tape => cat.tape(_tapeId)?.name ?? '',
        };
      case CurveKind.profile:
        label = _nozzle(_profileRef)?.$1.name ?? '';
    }
    String? created;
    try {
      final done = c.mutate<bool>(() {
        final k = c.project.catalog;
        switch (_s.kind) {
          case CurveKind.pump:
            created = putPumpChart(k, _pumpFit(), pumpId: _pumpId, name: _pumpId == null ? label : '').id;
          case CurveKind.emitter:
            final f = _emitterFit();
            switch (_emitterTarget) {
              case _EmitterTarget.newOutlet:
                final o = putNewOutlet(k, f, name: label, kind: _outletKind, nozzleName: _nozzleName(f));
                created = '${o.id}|${o.nozzles.first.id}';
              case _EmitterTarget.nozzle:
                putNozzleCurve((_nozzle(_nozzleRef, k) ?? (throw const ChartApplyError('no_item'))).$2, f);
              case _EmitterTarget.tape:
                putTapeEmitter(k.tape(_tapeId) ?? (throw const ChartApplyError('no_item')), f);
            }
          case CurveKind.profile:
            putNozzleProfile((_nozzle(_profileRef, k) ?? (throw const ChartApplyError('no_item'))).$2, _profileFit());
        }
        return true;
      }, label: 'hist.dgz.apply|$label');
      if (done != true) return;
    } on ChartApplyError catch (e) {
      setState(
        () => _applied = t(e.code == 'pump_head' ? 'dgz.err.pumpHead' : (e.code == 'no_item' ? 'dgz.err.noItem' : 'dgz.fit.need'), {
          'n': '${e.code == 'pump_head' ? minPumpHeadPoints : minCurvePoints}',
        }),
      );
      return;
    }
    final msg = t('dgz.applied', {'n': label});
    c.notify(msg);
    setState(() {
      _applied = msg;
      // the next Apply updates what was just added
      if (created != null) {
        if (_s.kind == CurveKind.pump) {
          _pumpId = created;
        } else {
          _emitterTarget = _EmitterTarget.nozzle;
          _nozzleRef = created;
        }
      }
    });
  }

  /// The points of every curve, in the axis units.
  List<CurveColumns> get _columns => [
    for (final r in rolesOf(_s.kind))
      if (_s.values(r).isNotEmpty) (name: curveRoleLabel(c, r), x: _s.xUnit.label, y: _s.series[r]!.yUnit.label, points: _s.values(r)),
  ];

  Future<void> _exportCsv() async {
    final cols = _columns;
    if (cols.isEmpty) return;
    final file = '${projectFileStem(c.t, c.project.meta.name)}_${c.t('dgz.file')}.csv';
    // the app's download helper, as File → Export and the assistant's
    // exports (it says "Exported"; tests read the file through it)
    await engFileSink(c, file, 'text/csv', curvePointsCsv(cols));
  }

  Future<void> _copy() async {
    final cols = _columns;
    if (cols.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: curvePointsTsv(cols, decimalSeparator: decimalSeparatorOf(c.lang))));
    c.notify(c.t('dgz.copied'));
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final compact = mq.size.width < 700;
    final inset = compact ? const EdgeInsets.all(8) : const EdgeInsets.symmetric(horizontal: 28, vertical: 20);
    final width = compact ? mq.size.width - inset.horizontal : math.min(1240.0, mq.size.width - inset.horizontal);
    final room = mq.size.height - mq.viewInsets.bottom - mq.padding.vertical - inset.vertical;
    final height = math.max(320.0, compact ? room : math.min(room, 860.0));
    final canvas = _canvas();
    final panel = ScrollBody(
      child: Padding(padding: const EdgeInsets.fromLTRB(10, 4, 0, 10), child: _panel(compact)),
    );
    return Dialog(
      key: const Key('dgz_dialog'),
      insetPadding: inset,
      child: SizedBox(
        key: _dialogKey,
        width: width,
        height: height,
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.delete): deleteSelected,
            const SingleActivator(LogicalKeyboardKey.backspace): deleteSelected,
            const SingleActivator(LogicalKeyboardKey.keyZ, control: true): undo,
            const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): undo,
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(),
              const Divider(height: 1),
              Expanded(
                child: compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: math.max(180.0, (height - 60) * 0.46), child: canvas),
                          const Divider(height: 1),
                          Expanded(child: panel),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: canvas),
                          const VerticalDivider(width: 1),
                          SizedBox(width: 380, child: panel),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 6, 4, 4),
    child: Row(
      children: [
        Icon(Icons.show_chart, size: 20, color: Cad.accentText),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            c.t('dgz.title'),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(key: const Key('dgz_close'), tooltip: c.t('close'), icon: const Icon(Icons.close, size: 18), onPressed: () => Navigator.of(context).pop()),
      ],
    ),
  );

  Widget _canvas() {
    final t = c.t;
    final r = raster;
    if (r == null || _loading) {
      return Container(
        color: Cad.inset,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: _loading
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 10),
                  Text(t('dgz.loading'), style: TextStyle(fontSize: 12, color: Cad.fg70)),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_photo_alternate_outlined, size: 44, color: Cad.fg54),
                  const SizedBox(height: 10),
                  Text(
                    t('dgz.empty'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: Cad.fg70),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(key: const Key('dgz_open'), onPressed: _open, icon: const Icon(Icons.folder_open, size: 16), label: Text(t('dgz.open'))),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      key: const Key('dgz_error'),
                      style: TextStyle(fontSize: 12, color: Cad.attention),
                    ),
                  ],
                ],
              ),
      );
    }
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        if (!_fitted || _canvasSize == null) {
          _fit(size);
        } else if (_canvasSize != size) {
          // the window changed: keep the picture's centre where it was
          final old = _canvasSize!;
          _pan += Offset((size.width - old.width) / 2, (size.height - old.height) / 2);
        }
        _canvasSize = size;
        return Focus(
          focusNode: _canvasFocus,
          child: Listener(
            onPointerDown: (e) => _touch = e.kind == PointerDeviceKind.touch || e.kind == PointerDeviceKind.stylus,
            onPointerSignal: (e) {
              if (e is PointerScrollEvent) _zoomAt(e.localPosition, e.scrollDelta.dy < 0 ? 1.15 : 1 / 1.15);
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.precise,
              onHover: (e) {
                _touch = false;
                _lens.value = (e.localPosition, false);
              },
              onExit: (_) => _lens.value = null,
              child: GestureDetector(
                key: _canvasKey,
                behavior: HitTestBehavior.opaque,
                // a drag starts where the finger went down: on the point it moves
                dragStartBehavior: DragStartBehavior.down,
                onTapUp: (d) => tapAt(d.localPosition),
                onSecondaryTapUp: (d) => _deleteAt(d.localPosition),
                onLongPressStart: (d) => _lens.value = (d.localPosition, _touch),
                onLongPressMoveUpdate: (d) => _lens.value = (d.localPosition, _touch),
                onLongPressEnd: (d) {
                  tapAt(d.localPosition);
                  if (_touch) _lens.value = null;
                },
                onScaleStart: (d) {
                  _drag = d.pointerCount == 1 ? _hit(d.localFocalPoint) : null;
                  if (_drag != null) {
                    _push();
                    return;
                  }
                  _startZoom = _zoom;
                  _startPan = _pan;
                  _startFocal = d.localFocalPoint;
                  _lens.value = null;
                },
                onScaleUpdate: (d) {
                  if (_drag != null) {
                    _moveDrag(d.localFocalPoint);
                    return;
                  }
                  final z = (_startZoom * d.scale).clamp(0.02, 40.0);
                  final p = (_startFocal - _startPan) / _startZoom;
                  setState(() {
                    _zoom = z;
                    _pan = d.localFocalPoint - p * z;
                  });
                },
                onScaleEnd: (_) {
                  if (_drag != null && _touch) _lens.value = null;
                  setState(() => _drag = null);
                },
                child: Stack(
                  children: [
                    CustomPaint(size: size, painter: _painter(size)),
                    // the whole picture again after zooming in
                    Positioned(
                      top: 6,
                      right: 6,
                      child: IconButton.filledTonal(
                        key: const Key('dgz_fit_view'),
                        tooltip: c.t('view.zoomAll'),
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.fit_screen, size: 18),
                        onPressed: () => setState(() => _fit(size)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  _DigitiserPainter _painter(Size size) {
    final others = <Pt>[
      for (final e in _s.series.entries)
        if (e.key != _s.current) ...e.value.pixels,
    ];
    final (m, _) = _mapping;
    List<Pt>? limits;
    if (mode == DigitiserMode.trace && m != null) {
      final (from, to) = _limits;
      limits = [
        for (final v in [from, to]) ?m.pixelOf(v, _s.active.y.v1 ?? 1),
      ];
    }
    return _DigitiserPainter(
      image: _mem.image,
      pictureSize: Size(raster!.width.toDouble(), raster!.height.toDouble()),
      zoom: _zoom,
      pan: _pan,
      x: _s.x,
      y: _s.active.y,
      points: _s.active.pixels,
      others: others,
      selected: _selected,
      fit: _fitLine(),
      limits: limits,
      limitDirection: m?.yDirection,
      lens: _lens,
      mode: mode,
    );
  }

  // ---------------------------------------------------------------- the panel

  Widget _panel(bool compact) {
    final t = c.t;
    final r = raster;
    final (m, err) = _mapping;
    final hint = Text(
      t('dgz.hint.${mode.name}'),
      key: const Key('dgz_hint'),
      style: TextStyle(fontSize: 11.5, color: Cad.fg70),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(key: const Key('dgz_open_again'), onPressed: _open, icon: const Icon(Icons.folder_open, size: 15), label: Text(t('dgz.open'))),
            if (r != null)
              Text(
                '${_mem.name} · ${r.width}×${r.height}',
                style: TextStyle(fontSize: 10.5, color: Cad.fg54),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        Text(t('dgz.pasteHint'), style: TextStyle(fontSize: 10.5, color: Cad.fg54)),
        if (_error != null && r != null) Text(_error!, style: TextStyle(fontSize: 11.5, color: Cad.attention)),
        SectionTitle(t('dgz.curve')),
        SpecDropdown<CurveKind>(
          key: Key('dgz_kind:${_s.kind.name}'),
          label: t('dgz.kind'),
          value: _s.kind.name,
          items: CurveKind.values,
          labelOf: (k) => t('dgz.kind.${k.name}'),
          idOf: (k) => k.name,
          onChanged: (v) => setKind(CurveKind.values.byName(v!)),
        ),
        if (_s.kind == CurveKind.pump)
          Wrap(
            spacing: 6,
            runSpacing: 2,
            children: [
              for (final role in rolesOf(CurveKind.pump))
                ChoiceChip(
                  key: Key('dgz_role_${role.name}'),
                  visualDensity: VisualDensity.compact,
                  label: Text('${curveRoleLabel(c, role)} (${_s.series[role]!.pixels.length})', style: const TextStyle(fontSize: 11.5)),
                  selected: _s.current == role,
                  onSelected: (_) => _setRole(role),
                ),
            ],
          ),
        if (_s.kind == CurveKind.emitter)
          CheckboxListTile(
            key: const Key('dgz_swap'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _s.swapped,
            title: Text(t('dgz.swap'), style: const TextStyle(fontSize: 12)),
            onChanged: (v) {
              _push();
              setState(() => _s = _s.withSwapped(v ?? false));
            },
          ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 2,
          children: [
            for (final md in DigitiserMode.values)
              ChoiceChip(
                key: Key('dgz_mode_${md.name}'),
                visualDensity: VisualDensity.compact,
                avatar: (md == DigitiserMode.x && _s.x.complete) || (md == DigitiserMode.y && _s.active.y.complete) ? Icon(Icons.check, size: 14, color: Cad.positive) : null,
                label: Text(t('dgz.mode.${md.name}'), style: const TextStyle(fontSize: 11.5)),
                selected: mode == md,
                onSelected: (_) => setState(() => mode = md),
              ),
          ],
        ),
        const SizedBox(height: 4),
        hint,
        if (m == null && err != CalibrationError.incomplete)
          Text(
            calibrationErrorText(c, err!),
            key: const Key('dgz_cal_error'),
            style: TextStyle(fontSize: 11.5, color: Cad.attention),
          ),
        _axis(t('dgz.mode.x'), _s.x, _s.xUnit, 'x', (u) => setState(() => _s.xUnit = u)),
        _axis('${t('dgz.mode.y')} · ${curveRoleLabel(c, _s.current)}', _s.active.y, _s.active.yUnit, 'y', (u) => setState(() => _s.active.yUnit = u)),
        if (mode == DigitiserMode.trace) ..._traceFields(),
        SectionTitle(t('dgz.points', {'n': '${_s.active.pixels.length}'})),
        Wrap(
          spacing: 2,
          children: [
            TextButton.icon(key: const Key('dgz_undo'), onPressed: _undo.isEmpty ? null : undo, icon: const Icon(Icons.undo, size: 15), label: Text(t('edit.undo'))),
            TextButton.icon(key: const Key('dgz_delete'), onPressed: _selected == null ? null : deleteSelected, icon: const Icon(Icons.remove_circle_outline, size: 15), label: Text(t('dgz.delete'))),
            TextButton.icon(key: const Key('dgz_clear'), onPressed: _s.active.pixels.isEmpty ? null : _clear, icon: const Icon(Icons.clear_all, size: 15), label: Text(t('dgz.clear'))),
          ],
        ),
        _pointsTable(),
        SectionTitle(t('dgz.fit')),
        ..._fitRows(),
        SectionTitle(t('dgz.target')),
        ..._targetFields(),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          alignment: WrapAlignment.end,
          children: [
            OutlinedButton(key: const Key('dgz_csv'), onPressed: _columns.isEmpty ? null : _exportCsv, child: Text(t('dgz.csv'))),
            OutlinedButton(key: const Key('dgz_copy'), onPressed: _columns.isEmpty ? null : _copy, child: Text(t('dgz.copy'))),
            FilledButton(key: const Key('dgz_apply'), onPressed: _canApply ? apply : null, child: Text(t('dgz.apply'))),
          ],
        ),
        if (_applied != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _applied!,
              key: const Key('dgz_applied'),
              style: TextStyle(fontSize: 11.5, color: Cad.positive),
            ),
          ),
      ],
    );
  }

  /// The fields of an axis: its two values, its unit and its scale.
  Widget _axis(String title, AxisCalibration cal, AxisUnit unit, String k, ValueChanged<AxisUnit> onUnit) {
    final t = c.t;
    String mark(Pt? p) => p == null ? '' : ' ✓';
    void set(void Function() f) {
      _push();
      setState(f);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(title),
        Row(
          children: [
            Expanded(
              child: NumField(key: Key('dgz_${k}1'), label: '${k.toUpperCase()}1${mark(cal.p1)}', value: cal.v1 ?? double.nan, onChanged: (v) => set(() => cal.v1 = v)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: NumField(key: Key('dgz_${k}2'), label: '${k.toUpperCase()}2${mark(cal.p2)}', value: cal.v2 ?? double.nan, onChanged: (v) => set(() => cal.v2 = v)),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: SpecDropdown<AxisUnit>(
                key: Key('dgz_${k}_unit:${unit.id}'),
                label: t('dgz.unit'),
                value: unit.code,
                items: AxisUnit.all(unit.quantity),
                labelOf: (u) => u.label,
                idOf: (u) => u.code,
                onChanged: (v) => onUnit(AxisUnit.of(unit.quantity, v)!),
              ),
            ),
            const SizedBox(width: 8),
            FilterChip(
              key: Key('dgz_${k}_log'),
              visualDensity: VisualDensity.compact,
              label: Text(t('dgz.log'), style: const TextStyle(fontSize: 11.5)),
              selected: cal.scale == AxisScale.log,
              onSelected: (on) => set(() => cal.scale = on ? AxisScale.log : AxisScale.linear),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _traceFields() {
    final t = c.t;
    final (from, to) = _limits;
    return [
      SectionTitle(t('dgz.mode.trace')),
      Row(
        children: [
          Expanded(
            child: NumField(key: const Key('dgz_from'), label: '${t('dgz.from')} (${_s.xUnit.label})', value: from, onChanged: (v) => setState(() => _from = v)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: NumField(key: const Key('dgz_to'), label: '${t('dgz.to')} (${_s.xUnit.label})', value: to, onChanged: (v) => setState(() => _to = v)),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: NumField(
              key: const Key('dgz_count'),
              label: t('dgz.mode.points'),
              value: _count.toDouble(),
              decimals: 0,
              signed: false,
              onChanged: (v) => setState(() => _count = v.round().clamp(2, 200)),
            ),
          ),
        ],
      ),
      Row(
        children: [
          Text(t('dgz.tolerance'), style: TextStyle(fontSize: 11.5, color: Cad.fg60)),
          Expanded(
            child: Slider(key: const Key('dgz_tolerance'), min: 15, max: 150, divisions: 27, value: _tolerance, label: _tolerance.round().toString(), onChanged: (v) => setState(() => _tolerance = v)),
          ),
        ],
      ),
      if (_traceMsg != null)
        Text(
          _traceMsg!,
          key: const Key('dgz_trace_msg'),
          style: TextStyle(fontSize: 11.5, color: Cad.fg87),
        ),
    ];
  }

  /// The points of the active curve with their gap from the fit.
  Widget _pointsTable() {
    final vals = _s.values();
    if (vals.isEmpty) return const SizedBox.shrink();
    final xu = _s.xUnit, yu = _s.active.yUnit;
    List<String?> gaps = List.filled(vals.length, null);
    switch (_s.current) {
      case CurveRole.head:
        final f = _pumpFit();
        if (f.curve != null) {
          gaps = [for (final (x, y) in vals) fmtUi(y - yu.fromSi(f.curve!.head(xu.toSi(x))), 2)];
        }
      case CurveRole.flowPressure:
        final f = _emitterFit();
        if (f.isUsable) {
          gaps = [
            for (final (x, y) in vals)
              () {
                final (h, q) = _s.swapped ? (yu.toSi(y), xu.toSi(x)) : (xu.toSi(x), yu.toSi(y));
                final fq = f.curve.flow(h);
                return fq > 0 && h > 0 ? '${fmtUi((q - fq) / fq * 100, 1)} %' : null;
              }(),
          ];
        }
      default:
        break;
    }
    final head = TextStyle(fontSize: 10.5, color: Cad.fg54, fontWeight: FontWeight.bold);
    const cell = TextStyle(fontSize: 11, fontFamily: 'monospace');
    return Table(
      key: const Key('dgz_table'),
      columnWidths: const {0: FlexColumnWidth(), 1: FlexColumnWidth(), 2: FlexColumnWidth()},
      children: [
        TableRow(
          children: [
            Text(xu.label, style: head),
            Text(yu.label, style: head),
            Text(c.t('dgz.gap'), style: head),
          ],
        ),
        for (var i = 0; i < vals.length && i < 80; i++)
          TableRow(
            children: [
              Text(_num(vals[i].$1), style: cell),
              Text(_num(vals[i].$2), style: cell),
              Text(gaps[i] ?? '–', style: cell),
            ],
          ),
      ],
    );
  }

  List<Widget> _fitRows() {
    final t = c.t;
    final u = c.units;
    final need = Text(
      t('dgz.fit.need', {'n': '${_s.kind == CurveKind.pump ? minPumpHeadPoints : minCurvePoints}'}),
      key: const Key('dgz_fit_need'),
      style: TextStyle(fontSize: 11.5, color: Cad.fg54),
    );
    switch (_s.kind) {
      case CurveKind.pump:
        final f = _pumpFit();
        final curve = f.curve;
        final hu = _s.series[CurveRole.head]!.yUnit, pu = _s.series[CurveRole.power]!.yUnit;
        return [
          if (curve == null)
            need
          else ...[
            KV('H(Q)', t(curve.throughPoints ? 'dgz.fit.cubic' : 'dgz.fit.parabola'), key: const Key('dgz_fit_form')),
            KV(
              t('dgz.fit.maxGap'),
              '${fmt(hu.fromSi(f.maxGap), 2)} ${hu.label} (${fmt(f.topHead > 0 ? f.maxGap / f.topHead * 100 : 0, 1)} %)',
              key: const Key('dgz_fit_gap'),
              color: f.topHead > 0 && f.maxGap / f.topHead > 0.03 ? Cad.caution : null,
            ),
            KV(t('dgz.fit.rms'), '${fmt(hu.fromSi(f.rmsGap), 2)} ${hu.label}'),
          ],
          if (f.bestEfficiency != null) KV(t(f.efficiencyFromPower ? 'dgz.fit.effPower' : 'dgz.fit.eff'), '${fmt(f.bestEfficiency! * 100, 1)} %'),
          if (f.rejectedEfficiency > 0) Text(t('dgz.fit.effRejected', {'n': '${f.rejectedEfficiency}'}), style: TextStyle(fontSize: 11, color: Cad.caution)),
          if (f.npsh.length >= minCurvePoints) KV(curveRoleLabel(c, CurveRole.npsh), '${f.npsh.length}'),
          if (f.maxPowerKw != null) KV(t('dgz.fit.maxPower'), '${fmt(pu.fromSi(f.maxPowerKw!), 2)} ${pu.label}'),
        ];
      case CurveKind.emitter:
        final f = _emitterFit();
        if (!f.isUsable) return [need];
        return [
          KV('q = k·Hˣ', 'k ${fmt(f.curve.k / m3sPerLph, 4)} L/h·m⁻ˣ   x ${fmt(f.curve.x, 3)}', key: const Key('dgz_fit_form')),
          KV(t('cat.fitFlowError'), '${fmt(f.fit.maxFlowError * 100, 1)} %', key: const Key('dgz_fit_gap'), color: f.fit.maxFlowError > 0.05 ? Cad.caution : null),
          KV(t('dgz.fit.range'), '${fmt(u.pressureFromHead(f.minHead), 2)} – ${fmt(u.pressureFromHead(f.maxHead), 2)} ${u.pressureLabel}'),
        ];
      case CurveKind.profile:
        final f = _profileFit();
        if (!f.isUsable) return [need];
        final n = _nozzle(_profileRef)?.$2;
        return [
          KV(t('dgz.fit.radius'), '${fmt(u.lengthFromSi(f.radiusM), 2)} ${u.lengthLabel}', key: const Key('dgz_fit_form')),
          if (n != null && n.curve.radius(n.defaultHeadM) > 0)
            KV(t('dgz.fit.nozzleRadius', {'p': '${fmt(u.pressureFromHead(n.defaultHeadM), 2)} ${u.pressureLabel}'}), '${fmt(u.lengthFromSi(n.curve.radius(n.defaultHeadM)), 2)} ${u.lengthLabel}'),
          KV(t('cat.profileStations'), '${f.profile!.length}', key: const Key('dgz_fit_gap')),
        ];
    }
  }

  List<Widget> _targetFields() {
    final t = c.t;
    final cat = c.project.catalog;
    final nameField = TextFieldRow(key: Key('dgz_name_${_s.kind.name}'), label: t('cat.name'), value: _name, onChanged: (v) => setState(() => _name = v));
    switch (_s.kind) {
      case CurveKind.pump:
        if (_pumpId != null && cat.pump(_pumpId) == null) _pumpId = null;
        return [
          SpecDropdown<PumpSpec>(
            key: Key('dgz_pump:$_pumpId'),
            label: t('dgz.into'),
            value: _pumpId,
            items: cat.pumps,
            allowNull: true,
            nullLabel: t('dgz.target.newPump'),
            labelOf: (p) => '${t('dgz.target.update')}: ${p.name}',
            idOf: (p) => p.id,
            onChanged: (v) => setState(() => _pumpId = v),
          ),
          if (_pumpId == null) nameField,
          Text(t('dgz.target.pumpHint'), style: TextStyle(fontSize: 10.5, color: Cad.fg54)),
        ];
      case CurveKind.emitter:
        final nozzles = _nozzles;
        if (_emitterTarget == _EmitterTarget.nozzle && _nozzle(_nozzleRef) == null) _nozzleRef = nozzles.isEmpty ? null : '${nozzles.first.$1.id}|${nozzles.first.$2.id}';
        if (_emitterTarget == _EmitterTarget.tape && cat.tape(_tapeId) == null) _tapeId = cat.tapes.firstOrNull?.id;
        return [
          SpecDropdown<_EmitterTarget>(
            key: Key('dgz_emitter_target:${_emitterTarget.name}'),
            label: t('dgz.into'),
            value: _emitterTarget.name,
            items: _EmitterTarget.values,
            labelOf: (e) => t('dgz.target.${e.name}'),
            idOf: (e) => e.name,
            onChanged: (v) => setState(() => _emitterTarget = _EmitterTarget.values.byName(v!)),
          ),
          if (_emitterTarget == _EmitterTarget.newOutlet) ...[
            nameField,
            SpecDropdown<OutletKind>(
              key: const Key('dgz_outlet_kind'),
              label: t('cat.type'),
              value: _outletKind.name,
              items: const [OutletKind.dripper, OutletKind.microSprinkler, OutletKind.sprinkler, OutletKind.bubbler, OutletKind.gun],
              labelOf: (k) => t('dgz.okind.${k.name}'),
              idOf: (k) => k.name,
              onChanged: (v) => setState(() => _outletKind = OutletKind.values.byName(v!)),
            ),
          ],
          if (_emitterTarget == _EmitterTarget.nozzle) _nozzleDropdown(nozzles, _nozzleRef, (v) => setState(() => _nozzleRef = v)),
          if (_emitterTarget == _EmitterTarget.tape)
            SpecDropdown<TapeSpec>(
              key: Key('dgz_tape:$_tapeId'),
              label: t('cat.tapes'),
              value: _tapeId,
              items: cat.tapes,
              labelOf: (x) => x.name,
              idOf: (x) => x.id,
              onChanged: (v) => setState(() => _tapeId = v),
            ),
          Text(t('dgz.target.emitterHint'), style: TextStyle(fontSize: 10.5, color: Cad.fg54)),
        ];
      case CurveKind.profile:
        final nozzles = _nozzles;
        if (nozzles.isEmpty) {
          return [
            Text(
              t('dgz.noNozzle'),
              key: const Key('dgz_no_nozzle'),
              style: TextStyle(fontSize: 11.5, color: Cad.attention),
            ),
          ];
        }
        if (_nozzle(_profileRef) == null) {
          final pick = nozzles.where((x) => x.$1.kind == OutletKind.sprinkler || x.$1.kind == OutletKind.microSprinkler).firstOrNull ?? nozzles.first;
          _profileRef = '${pick.$1.id}|${pick.$2.id}';
        }
        return [_nozzleDropdown(nozzles, _profileRef, (v) => setState(() => _profileRef = v)), Text(t('dgz.target.profileHint'), style: TextStyle(fontSize: 10.5, color: Cad.fg54))];
    }
  }

  Widget _nozzleDropdown(List<(OutletSpec, NozzleSpec)> nozzles, String? value, ValueChanged<String?> onChanged) => SpecDropdown<(OutletSpec, NozzleSpec)>(
    key: Key('dgz_nozzle:$value'),
    label: '${c.t('cat.outlet')} · ${c.t('cat.nozzle')}',
    value: value,
    items: nozzles,
    labelOf: (x) => '${x.$1.name} · ${x.$2.name}',
    idOf: (x) => '${x.$1.id}|${x.$2.id}',
    onChanged: onChanged,
  );
}

/// [v] with three significant digits or two decimals, whichever shows more,
/// in the notation of the interface (the values read off a chart).
String _num(double v) {
  final a = v.abs();
  return fmtUi(v, a >= 100 ? 1 : (a >= 1 || a == 0 ? 2 : math.min(6, 2 - (math.log(a) / math.ln10).floor())));
}

/// The picture, the marks of the calibration, the points, the fitted curve
/// and the magnifier.
class _DigitiserPainter extends CustomPainter {
  _DigitiserPainter({
    required this.image,
    required this.pictureSize,
    required this.zoom,
    required this.pan,
    required this.x,
    required this.y,
    required this.points,
    required this.others,
    required this.selected,
    required this.fit,
    required this.limits,
    required this.limitDirection,
    required this.lens,
    required this.mode,
  }) : xp1 = x.p1,
       xp2 = x.p2,
       yp1 = y.p1,
       yp2 = y.p2,
       pts = [...points],
       super(repaint: lens);

  final ui.Image? image;
  final Size pictureSize;
  final double zoom;
  final Offset pan;
  final AxisCalibration x, y;
  final List<Pt> points, others;
  final int? selected;
  final List<Pt> fit;
  final List<Pt>? limits;
  final Pt? limitDirection;
  final ValueListenable<(Offset, bool)?> lens;
  final DigitiserMode mode;

  // what the marks were when painted (the session is edited in place)
  final Pt? xp1, xp2, yp1, yp2;
  final List<Pt> pts;

  static const _lensRadius = 62.0;
  static const _lensZoom = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = Cad.inset);
    _scene(canvas, pan, zoom, marks: true);
    final at = lens.value;
    if (at == null) return;
    final (l, touch) = at;
    // the magnifier: beside the cursor, above the finger
    var centre = touch ? l + const Offset(0, -_lensRadius - 46) : l + const Offset(_lensRadius + 26, -_lensRadius - 26);
    if (centre.dy - _lensRadius < 0) centre = Offset(centre.dx, l.dy + _lensRadius + 46);
    if (centre.dx + _lensRadius > size.width) centre = Offset(l.dx - _lensRadius - 26, centre.dy);
    if (centre.dx - _lensRadius < 0) centre = Offset(_lensRadius + 4, centre.dy);
    final k = _lensZoom;
    final circle = Rect.fromCircle(center: centre, radius: _lensRadius);
    canvas.save();
    canvas.clipPath(Path()..addOval(circle));
    canvas.drawRect(circle, Paint()..color = Cad.inset);
    _scene(canvas, centre + (pan - l) * k, zoom * k, marks: true);
    final cross = Paint()
      ..color = Cad.attention
      ..strokeWidth = 1;
    canvas.drawLine(centre - const Offset(12, 0), centre - const Offset(3, 0), cross);
    canvas.drawLine(centre + const Offset(3, 0), centre + const Offset(12, 0), cross);
    canvas.drawLine(centre - const Offset(0, 12), centre - const Offset(0, 3), cross);
    canvas.drawLine(centre + const Offset(0, 3), centre + const Offset(0, 12), cross);
    canvas.restore();
    canvas.drawCircle(
      centre,
      _lensRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Cad.fg54,
    );
  }

  /// The picture and its marks with the view [p] + picture · [z].
  void _scene(Canvas canvas, Offset p, double z, {required bool marks}) {
    Offset s(Pt q) => Offset(p.dx + q.x * z, p.dy + q.y * z);
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.scale(z);
    final im = image;
    if (im != null) {
      canvas.drawImage(im, Offset.zero, Paint()..filterQuality = z > 2 ? FilterQuality.none : FilterQuality.medium);
    } else {
      canvas.drawRect(Offset.zero & pictureSize, Paint()..color = const Color(0xFFFFFFFF));
    }
    canvas.restore();
    if (!marks) return;
    final halo = Paint()
      ..color = const Color(0xD0FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    Paint line(Color c, [double w = 1.6]) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round;
    // the axes clicked
    void axis(Pt? a, Pt? b, Color col) {
      if (a == null || b == null) return;
      canvas.drawLine(s(a), s(b), halo);
      canvas.drawLine(s(a), s(b), line(col, 1));
    }

    axis(xp1, xp2, Cad.info);
    axis(yp1, yp2, Cad.positive);
    // the limits of the trace
    final lim = limits, dir = limitDirection;
    if (lim != null && dir != null) {
      final reach = pictureSize.longestSide * 2;
      for (final q in lim) {
        final a = s(q - dir * reach), b = s(q + dir * reach);
        canvas.drawLine(a, b, line(Cad.amber, 1));
      }
    }
    // the fitted curve
    if (fit.length >= 2) {
      final path = Path()..moveTo(s(fit.first).dx, s(fit.first).dy);
      for (final q in fit.skip(1)) {
        path.lineTo(s(q).dx, s(q).dy);
      }
      canvas.drawPath(path, halo);
      canvas.drawPath(path, line(Cad.attention, 1.6));
    }
    // the other curves' points, then this one's
    for (final q in others) {
      canvas.drawCircle(s(q), 3, Paint()..color = const Color(0xD0FFFFFF));
      canvas.drawCircle(s(q), 2, Paint()..color = Cad.fg54);
    }
    for (var i = 0; i < pts.length; i++) {
      final at = s(pts[i]);
      final sel = i == selected;
      canvas.drawCircle(at, sel ? 6.5 : 5, Paint()..color = const Color(0xE0FFFFFF));
      canvas.drawCircle(at, sel ? 5 : 3.5, Paint()..color = sel ? Cad.attention : Cad.accent);
    }
    // the calibration points, labelled
    void mark(Pt? q, String label, Color col) {
      if (q == null) return;
      final at = s(q);
      canvas.drawCircle(at, 7, halo);
      canvas.drawCircle(at, 7, line(col, 2));
      canvas.drawLine(at - const Offset(10, 0), at + const Offset(10, 0), line(col, 1));
      canvas.drawLine(at - const Offset(0, 10), at + const Offset(0, 10), line(col, 1));
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: col),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final box = Rect.fromLTWH(at.dx + 9, at.dy - tp.height - 7, tp.width + 6, tp.height + 2);
      canvas.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(3)), Paint()..color = const Color(0xE0FFFFFF));
      tp.paint(canvas, box.topLeft + const Offset(3, 1));
    }

    mark(xp1, 'X1', Cad.info);
    mark(xp2, 'X2', Cad.info);
    mark(yp1, 'Y1', Cad.positive);
    mark(yp2, 'Y2', Cad.positive);
  }

  @override
  bool shouldRepaint(_DigitiserPainter o) => true;
}
