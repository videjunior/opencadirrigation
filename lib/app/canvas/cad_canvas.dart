import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/model/geometry.dart';
import '../state/controller.dart';
import '../io/links.dart';
import '../keys/canvas_keys.dart';
import '../state/workspace.dart';
import '../../core/model/entities.dart';
import '../tools/cad_plus_commands.dart';
import '../tools/context_menu.dart';
import '../tools/edit_commands.dart';
import '../tools/tools.dart';
import 'basemap.dart';
import 'painter.dart';
import 'scene_cache.dart';
import 'snapping.dart';
import '../theme.dart';
import '../widgets/layout_mode.dart' show touchInput; // 1.6.0 UI

class CadCanvas extends StatefulWidget {
  const CadCanvas({super.key, required this.controller, required this.host, required this.focusNode, this.workspace, this.onArray});
  final ProjectController controller;
  final ToolHost host;
  final FocusNode focusNode;

  /// Enables Ctrl+C / Ctrl+X / Ctrl+V and the clipboard commands.
  final Workspace? workspace;

  /// Opens the array dialog (AR command); null = unavailable.
  final VoidCallback? onArray;

  @override
  State<CadCanvas> createState() => _CadCanvasState();
}

class _CadCanvasState extends State<CadCanvas> implements CanvasKeyTarget {
  late Tool _tool;
  late Snapper _snapper;
  SnapResult? _snap;
  Offset? _lastPointer;
  bool _panning = false;
  bool _dragging = false;
  DateTime _lastDown = DateTime.fromMillisecondsSinceEpoch(0);
  Offset? _lastDownPos;

  /// Dead zone around a press: the tool only sees a drag once the pointer has
  /// travelled this far, so clicking an item to look at it never nudges it out
  /// of the pipe it sits on. Touch gets more room than a mouse.
  static const dragSlopPx = 5.0;
  static const touchDragSlopPx = 14.0;
  bool _dragArmed = false;
  Offset? _dragOrigin;
  double _dragSlop = dragSlopPx;
  bool _spaceDown = false;
  final _repaint = ValueNotifier<int>(0);
  final BaseMapLayer basemap = BaseMapLayer();

  /// The drawing kept between frames, and the one painter that uses it
  /// (the tool and the snap are updated in it as the cursor moves).
  late final SceneCache _scene = SceneCache(onSettle: _redraw);
  late final CadPainter _painter = CadPainter(
    c: c,
    tool: _tool,
    snapResult: _snap,
    basemap: basemap,
    scene: _scene,
    // the marks for the AI change without an edit of the project
    repaint: Listenable.merge([_repaint, c, c.aiMarks]),
  );

  /// Active touch pointers (id → position) for pinch zoom / two-finger pan.
  final Map<int, Offset> _touches = {};
  double? _pinchDistance;
  Offset? _pinchCenter;
  bool _touchGesture = false;
  bool _touchDrawPending = false;

  // 1.6.0 EDT: a finger held still (CAD-17): dragged afterwards, it opens a
  // selection window where a plain drag pans
  static const holdDelay = Duration(milliseconds: 500);
  Timer? _holdTimer;
  Offset? _holdAt;
  bool _held = false;

  void _endHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _held = false;
  }

  // 1.6.0 CAD: a finger dragged while drawing aims with a magnifier (the
  // point goes where it is lifted), the text edited in place, and the
  // length and angle beside the cursor
  bool _aiming = false;
  Offset? _aimAt;
  String? _editingText;
  TextEditingController? _textCtl;
  final FocusNode _textFocus = FocusNode(debugLabel: 'textInPlace');
  final ValueNotifier<Offset?> _dynAt = ValueNotifier<Offset?>(null);

  /// Whether a finger aims with the magnifier now: a drawing tool, the
  /// magnifier on.
  bool get _aimsWithLoupe => c.cadPlus.touchLoupe && c.activeTool != ToolId.select && c.activeTool != ToolId.pan && _tool.usesSnap;

  ProjectController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _snapper = Snapper(c);
    c.keyTarget = this;
    _tool = createTool(c.activeTool, c, widget.host);
    c.addListener(_onController);
    basemap.addListener(_redraw);
    // fonts fetched on demand: the labels are laid out again with them
    PaintingBinding.instance.systemFonts.addListener(_redraw);
    c.baseMapSnapshot = _baseMapSnapshot;
    c.baseMapAttribution = _baseMapAttribution;
  }

  /// The base map of the view as the sheet's background (see [BaseMapLayer.snapshot]).
  Future<(Uint8List, List<Pt>)?> _baseMapSnapshot() {
    final g = c.project.meta.georef;
    if (g == null || c.baseMap == BaseMap.none) return Future.value();
    return basemap.snapshot(c.camera, g, BaseMapOptions(c.baseMap, opacity: c.baseMapOpacity, googleKey: c.googleMapsKey, customUrl: c.customTileUrl, lang: c.lang, epoch: c.baseMapEpoch));
  }

  String _baseMapAttribution() => basemap.attributionText(c.baseMap);

  @override
  void dispose() {
    if (c.baseMapSnapshot == _baseMapSnapshot) c.baseMapSnapshot = null;
    if (c.baseMapAttribution == _baseMapAttribution) c.baseMapAttribution = null;
    if (identical(c.keyTarget, this)) c.keyTarget = null;
    c.removeListener(_onController);
    basemap.removeListener(_redraw);
    PaintingBinding.instance.systemFonts.removeListener(_redraw);
    basemap.dispose();
    _scene.dispose();
    _endHold();
    _textFocus.dispose();
    _textCtl?.dispose();
    _dynAt.dispose();
    super.dispose();
  }

  void _onController() {
    if (_tool.id != c.activeTool) {
      final old = _tool;
      _tool = createTool(c.activeTool, c, widget.host);
      _snap = null;
      // 1.6.0 EDT: the old tool keeps a polyline in progress (CAD-10); the
      // new one is in place first, as keeping it notifies again
      old.leave();
    }
    _redraw();
  }

  void _redraw() {
    _painter
      ..tool = _tool
      ..snapResult = _snap;
    _repaint.value++;
  }

  Pt _world(Offset local) => c.camera.toWorld(local);

  Pt _snapped(Offset local) {
    final raw = _world(local);
    if (!_tool.usesSnap) {
      _snap = null;
      if (c.angleLockActive) {
        c.angleLockActive = false;
        c.refresh();
      }
      return raw;
    }
    // while an item or a node is dragged the snap runs on the dragged point,
    // not on the cursor (see Tool.snapOffset)
    final offset = _tool.snapOffset;
    _snap = _snapper.snap(
      offset == null ? raw : raw - offset,
      reference: _tool.referencePoint,
      ignoreSelection: _tool is SelectTool,
      // Shift held while drawing: lock the segment to 0°/45°/90°
      angleLock: HardwareKeyboard.instance.isShiftPressed && _tool is! SelectTool,
    );
    final locked = _snap!.locked;
    if (locked != c.angleLockActive) {
      c.angleLockActive = locked;
      c.refresh();
    }
    return _snap!.point;
  }

  bool _isTouch(PointerEvent e) => e.kind == PointerDeviceKind.touch;

  void _onPointerDown(PointerDownEvent e) {
    widget.focusNode.requestFocus();
    _lastPointer = e.localPosition;
    _lastTouch = _isTouch(e);
    if (_isTouch(e)) {
      _touches[e.pointer] = e.localPosition;
      if (_touches.length >= 2) {
        // second finger: cancel any single-finger drawing and start a gesture
        if (_touchDrawPending) {
          _touchDrawPending = false;
        }
        _endHold();
        if (_dragging) {
          _tool.cancel();
          _dragging = false;
        }
        _touchGesture = true;
        final pts = _touches.values.toList();
        _pinchDistance = (pts[0] - pts[1]).distance;
        _pinchCenter = (pts[0] + pts[1]) / 2;
        return;
      }
      // single finger: behaves as the primary button, but the tap is only
      // committed on pointer up so a pinch can still cancel it
      _touchDrawPending = true;
      _endHold();
      _holdAt = e.localPosition;
      _holdTimer = Timer(holdDelay, () {
        if (!mounted || !_touchDrawPending || _touches.length != 1) return;
        _touchDrawPending = false;
        _held = true;
        HapticFeedback.selectionClick();
      });
      return;
    }
    // 1.6.0 EDT: the buttons by bit (a pen touching with its side button
    // pressed has two); the right button — the pen's side button — taps
    // the menu of the drawing and drags the view (CAD-34)
    final b = e.buttons;
    if ((b & kSecondaryButton) != 0) {
      _secondaryAt = e.localPosition;
      _secondaryMoved = false;
      _panning = true;
      return;
    }
    if ((b & kTertiaryButton) != 0 || _spaceDown || c.activeTool == ToolId.pan) {
      _panning = true;
      return;
    }
    if ((b & kPrimaryButton) != 0) {
      _primaryDown(e.localPosition);
    }
  }

  // 1.6.0 EDT: a press of the right button, until it moves (CAD-34)
  Offset? _secondaryAt;
  bool _secondaryMoved = false;

  /// A finger lands farther from the last tap than a mouse does: a double
  /// tap allows this much (a double click 6 px).
  static const doubleTapSlopPx = 24.0;

  void _openMenu(Offset global) {
    if (!mounted) return;
    showCanvasContextMenu(context, c, this, global);
  }

  void _primaryDown(Offset local, {bool touch = false}) {
    final now = DateTime.now();
    final isDouble = now.difference(_lastDown).inMilliseconds < (touch ? 400 : 350) && _lastDownPos != null && (_lastDownPos! - local).distance < (touch ? doubleTapSlopPx : 6);
    _lastDown = now;
    _lastDownPos = local;
    final p = _snapped(local);
    final keys = HardwareKeyboard.instance;
    if (isDouble) {
      _tool.onDoubleClick(p);
      // 1.6.0 CAD: a double click on a text, a leader or a comment edits its text in place
      if (_tool is SelectTool) _editTextAt(local);
    } else {
      // 1.6.0 EDT: "add to the selection" stands in for Shift on a touch screen
      _tool.onDown(p, shift: keys.isShiftPressed || c.editSettings.addToSelection, ctrl: keys.isControlPressed || keys.isMetaPressed);
      if (_snap?.locked ?? false) c.track('lock');
    }
    // 1.6.0 CAD: a snap chosen for one point is used up by it
    if (c.snap.once != null && _tool.usesSnap) c.snap.once = null;
    _dragging = true;
    _dragArmed = false;
    _dragOrigin = local;
    _dragSlop = touch ? touchDragSlopPx : dragSlopPx;
    _redraw();
  }

  /// True once the pointer has left the dead zone of the current press.
  bool _armDrag(Offset local) {
    if (_dragging && !_dragArmed && _dragOrigin != null && (local - _dragOrigin!).distance > _dragSlop) {
      _dragArmed = true;
    }
    return _dragging && _dragArmed;
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (_isTouch(e)) {
      _touches[e.pointer] = e.localPosition;
      if (_touchGesture && _touches.length >= 2) {
        final pts = _touches.values.toList();
        final d = (pts[0] - pts[1]).distance;
        final center = (pts[0] + pts[1]) / 2;
        if (_pinchDistance != null && _pinchDistance! > 0 && d > 0) {
          c.camera.zoomAt(center, (d / _pinchDistance!).clamp(0.5, 2.0));
        }
        if (_pinchCenter != null) c.camera.panPixels(center - _pinchCenter!);
        _pinchDistance = d;
        _pinchCenter = center;
        _redraw();
        return;
      }
      if (_held && _holdAt != null && !_dragging) {
        // 1.6.0 EDT: held still, then dragged: a selection window from where
        // the finger was held, whatever lies under it (CAD-17)
        if ((e.localPosition - _holdAt!).distance <= touchDragSlopPx) return;
        final st = _tool;
        if (st is! SelectTool) {
          _held = false;
          _primaryDown(_holdAt!, touch: true);
        } else {
          st.startWindow(_world(_holdAt!), add: c.editSettings.addToSelection);
          _dragging = true;
          _dragArmed = true;
          _dragOrigin = _holdAt;
        }
      }
      // 1.6.0 CAD: aiming with the magnifier
      if (_aiming) {
        _aim(e.localPosition);
        return;
      }
      if (_touchDrawPending && _lastPointer != null && _aimsWithLoupe && (e.localPosition - _lastPointer!).distance > 8 && !_dragging) {
        _touchDrawPending = false;
        _endHold();
        _aiming = true;
        _aim(e.localPosition);
        return;
      }
      if (_touchDrawPending && _lastPointer != null) {
        // a finger drag before any tap commits: pan (touch-friendly), unless
        // the select tool is moving a selection
        final moved = (e.localPosition - _lastPointer!).distance;
        if (moved > 8 && !_dragging) {
          if (c.activeTool == ToolId.pan || (c.activeTool == ToolId.select && c.pick(_world(_lastPointer!), c.snap.tolerancePx * 1.5 / c.camera.scale) == null)) {
            _touchDrawPending = false;
            _panning = true;
          } else {
            _touchDrawPending = false;
            _primaryDown(_lastPointer!, touch: true);
          }
        }
      }
    }
    if (_panning && _lastPointer != null) {
      // a right press pans only once it leaves the dead zone (a tap opens the menu)
      if (_secondaryAt != null && !_secondaryMoved) {
        if ((e.localPosition - _secondaryAt!).distance <= dragSlopPx) return;
        _secondaryMoved = true;
      }
      c.camera.panPixels(e.localPosition - _lastPointer!);
      _lastPointer = e.localPosition;
      _redraw();
      return;
    }
    _lastPointer = e.localPosition;
    final dragging = _armDrag(e.localPosition);
    final p = _snapped(e.localPosition);
    _tool.onMove(p, dragging: dragging);
    _updateStatus(p);
    _redraw();
  }

  void _onPointerHover(PointerHoverEvent e) {
    _lastPointer = e.localPosition;
    _lastTouch = false;
    final p = _snapped(e.localPosition);
    _tool.onMove(p);
    if (_tool is SelectTool) {
      final hit = c.pick(_world(e.localPosition), c.snap.tolerancePx / c.camera.scale);
      final id = hit?.id;
      if (id != c.hoverId) c.hoverId = id;
    }
    _updateStatus(p);
    _redraw();
  }

  void _updateStatus(Pt p) {
    // 1.6.0 CAD: the dynamic input follows the cursor
    _dynAt.value = _lastPointer;
    final u = c.units;
    // distance and angle from the previous point, as typed input expects them
    final ref = _tool.referencePoint;
    final rel = ref == null || ref == p ? '' : '   Δ ${u.lengthFromSi(ref.distanceTo(p)).toStringAsFixed(2)}  ∠ ${((p - ref).angle * 180 / math.pi % 360 + 360).remainder(360).toStringAsFixed(1)}°';
    widget.host.setStatus(
      'X ${u.lengthFromSi(p.x).toStringAsFixed(2)}  Y ${u.lengthFromSi(p.y).toStringAsFixed(2)} ${u.lengthLabel}$rel${_snap != null && _snap!.isSnapped ? '   [${c.t(snapKindKey(_snap!.kind))}]' : ''}',
    );
  }

  void _onPointerUp(PointerUpEvent e) {
    if (_isTouch(e)) {
      _touches.remove(e.pointer);
      if (_touchGesture) {
        if (_touches.isEmpty) _touchGesture = false;
        _pinchDistance = null;
        _pinchCenter = null;
        return;
      }
      _holdTimer?.cancel();
      if (_held && !_dragging) {
        // 1.6.0 EDT: held still and lifted: the menu of the drawing (CAD-17, CAD-34)
        _held = false;
        _openMenu(e.position);
        return;
      }
      _held = false;
      // 1.6.0 CAD: the point aimed at with the magnifier goes where the finger is lifted
      if (_aiming) {
        _aiming = false;
        _aimAt = null;
        setState(() {});
        _primaryDown(e.localPosition, touch: true);
      }
      if (_touchDrawPending) {
        // simple tap: run the tool's down + up at the tap position
        _touchDrawPending = false;
        _primaryDown(e.localPosition, touch: true);
      }
    }
    if (_panning) {
      _panning = false;
      final tapped = _secondaryAt != null && !_secondaryMoved;
      _secondaryAt = null;
      if (tapped) {
        // 1.6.0 EDT: a right click (no drag): the menu of the drawing (CAD-34)
        _openMenu(e.position);
        return;
      }
      c.track('pan');
      return;
    }
    if (_dragging) {
      final p = _snapped(e.localPosition);
      _dragging = false;
      _dragArmed = false;
      _dragOrigin = null;
      _tool.onUp(p);
      _redraw();
    }
  }

  void _onPointerCancel(PointerCancelEvent e) {
    _touches.remove(e.pointer);
    _endHold();
    _secondaryAt = null;
    if (_touches.isEmpty) {
      _touchGesture = false;
      _touchDrawPending = false;
      // 1.6.0 CAD
      if (_aiming) setState(() => _aiming = false);
      _panning = false;
      _dragArmed = false;
      _dragOrigin = null;
    }
  }

  void _onSignal(PointerSignalEvent e) {
    if (e is PointerScrollEvent) {
      final factor = e.scrollDelta.dy > 0 ? 1 / 1.15 : 1.15;
      c.camera.zoomAt(e.localPosition, factor);
      c.track('zoom');
      _updateStatus(_world(e.localPosition));
      _redraw();
    } else if (e is PointerScaleEvent) {
      // trackpad pinch
      c.camera.zoomAt(e.localPosition, e.scale.clamp(0.5, 2.0));
      _updateStatus(_world(e.localPosition));
      _redraw();
    }
  }

  // ---- CanvasKeyTarget: keys arrive through the app-wide dispatcher (see
  // keys/hotkeys.dart), whatever widget has the focus.
  @override
  void toolKey(String key) {
    // 1.6.0 EDT: 'Cancel' (the Cancel button) drops what is in progress
    if (key == 'Cancel') {
      _tool.cancel();
    } else {
      _tool.onKey(key);
    }
    _redraw();
  }

  @override
  bool get toolIdle => _tool.idle;

  @override
  Pt? get referencePoint => _tool.referencePoint;

  @override
  Pt? get cursorPoint => _tool.cursor;

  @override
  void feedPoint(Pt p) {
    _tool.onDown(p);
    _tool.onUp(p);
    _tool.onMove(p);
    // 1.6.0 CAD: a snap chosen for one point is used up by a typed one too
    c.snap.once = null;
    _updateStatus(p);
    _redraw();
  }

  // 1.6.0 EDT: options and step values typed on the command line
  @override
  bool toolInput(String text) {
    final taken = _tool.onInput(text);
    if (taken) _redraw();
    return taken;
  }

  @override
  void setSpaceHeld(bool held) => _spaceDown = held;

  @override
  void modifiersChanged() {
    final lp = _lastPointer;
    if (lp == null || _panning) return;
    final p = _snapped(lp);
    _tool.onMove(p, dragging: _dragging && _dragArmed);
    _updateStatus(p);
    _redraw();
  }

  @override
  void redraw() => _redraw();

  // ---- 1.6.0 CAD: aiming on a touch screen, text in place, dynamic input

  /// The finger aims at [local]: the snap, the rubber band and the
  /// magnifier follow it.
  void _aim(Offset local) {
    _aimAt = local;
    _lastPointer = local;
    final p = _snapped(local);
    _tool.onMove(p);
    _updateStatus(p);
    _redraw();
    if (mounted) setState(() {});
  }

  /// Opens the text of the item under [local] for editing in place.
  void _editTextAt(Offset local) {
    final hit = c.pick(_world(local), c.snap.tolerancePx / c.camera.scale);
    if (hit == null || !hasEditableText(hit) || c.project.isLocked(hit.layer)) return;
    _textCtl?.dispose();
    setState(() {
      _editingText = hit.id;
      _textCtl = TextEditingController(text: editableTextOf(hit));
    });
    c.track('textInPlace');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _editingText != null) _textFocus.requestFocus();
    });
  }

  /// Ends the edit in place: the text typed goes to the item (one undo
  /// step) unless [cancel].
  void _commitText({bool cancel = false}) {
    final id = _editingText, ctl = _textCtl;
    if (id == null || ctl == null) return;
    _editingText = null;
    _textCtl = null;
    if (!cancel) c.setEntityText(id, ctl.text);
    if (mounted) setState(() {});
    // the field lets the controller go once it is off the screen
    WidgetsBinding.instance.addPostFrameCallback((_) => ctl.dispose());
    widget.focusNode.requestFocus();
  }

  Widget _textEditor() {
    final e = c.entityById(_editingText!);
    if (e == null) return const SizedBox.shrink();
    final at = switch (e) {
      LeaderEntity l => l.textPosition,
      PointEntity p => p.position,
      _ => e.bounds.center,
    };
    final o = c.camera.toScreen(at);
    final size = c.camera.size;
    final multi = _textCtl!.text.contains('\n') || e is! TextEntity;
    const w = 280.0;
    return Positioned(
      left: o.dx.clamp(4.0, math.max(4.0, size.width - w - 4)),
      top: (o.dy - (multi ? 96 : 52)).clamp(4.0, math.max(4.0, size.height - 100)),
      width: w,
      child: Material(
        key: const Key('text_in_place'),
        color: Cad.panel,
        elevation: 4,
        borderRadius: BorderRadius.circular(4),
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () => _commitText(cancel: true),
            const SingleActivator(LogicalKeyboardKey.enter, control: true): _commitText,
            const SingleActivator(LogicalKeyboardKey.enter, meta: true): _commitText,
          },
          child: Focus(
            onFocusChange: (has) {
              if (!has) _commitText();
            },
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: TextField(
                key: const Key('text_in_place_field'),
                controller: _textCtl,
                focusNode: _textFocus,
                minLines: 1,
                maxLines: multi ? 4 : 1,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(isDense: true, helperText: c.t(multi ? 'cadp.textInPlaceMulti' : 'cadp.textInPlaceHint'), helperMaxLines: 2),
                onSubmitted: multi ? null : (_) => _commitText(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The length and angle of the segment beside the cursor (or X and Y
  /// before the first point), with what is being typed in its field: Tab
  /// keeps the length and goes on to the angle (see the dispatcher).
  Widget _dynamicInput() => ListenableBuilder(
    listenable: Listenable.merge([_dynAt, c]),
    builder: (context, _) {
      final at = _dynAt.value;
      final show = at != null && c.cadPlus.dynamicInput && c.activeTool != ToolId.select && c.activeTool != ToolId.pan && _tool.usesSnap && !_aiming && !touchInputActive;
      final cur = _tool.cursor;
      if (!show || cur == null) return const Positioned(left: 0, top: 0, child: SizedBox.shrink());
      final u = c.units;
      String l(double v) => u.lengthFromSi(v).toStringAsFixed(2);
      final ref = _tool.referencePoint;
      final typed = c.command;
      final List<(String, String, bool)> fields;
      if (ref == null) {
        fields = [('X', l(cur.x), false), ('Y', l(cur.y), false)];
      } else {
        final d = cur - ref;
        final ang = ((math.atan2(d.y, d.x) * 180 / math.pi) % 360 + 360) % 360;
        final polar = RegExp(r'^@([^<]*)<(.*)$').firstMatch(typed);
        fields = polar != null
            ? [(c.t('cadp.dynLength'), polar.group(1)!, false), ('∠', '${polar.group(2)!}_', true)]
            : [(c.t('cadp.dynLength'), typed.isNotEmpty ? '${typed}_' : l(d.length), typed.isNotEmpty), ('∠', '${ang.toStringAsFixed(1)}°', false)];
      }
      final size = c.camera.size;
      return Positioned(
        left: math.min(at.dx + 18, math.max(0.0, size.width - 200)),
        top: math.min(at.dy + 18, math.max(0.0, size.height - 30)),
        child: IgnorePointer(
          child: Container(
            key: const Key('dynamic_input'),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(color: Cad.overlay, borderRadius: BorderRadius.circular(3)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (label, value, active) in fields) ...[
                  Text('$label ', style: TextStyle(fontSize: 10.5, color: Cad.fg54)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(border: Border.all(color: active ? Cad.accent : Cad.fg24), borderRadius: BorderRadius.circular(2)),
                    child: Text(value, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );

  /// Whether the last pointer was a finger (the dynamic input is for a mouse).
  bool get touchInputActive => _lastTouch;
  bool _lastTouch = false;

  /// The magnifier over the finger at [at]: 2.5 times the drawing round
  /// the point aimed at, above the finger (below it at the top edge).
  Widget _loupe(Offset at) {
    const s = 128.0, gap = 40.0;
    final size = c.camera.size;
    final left = (at.dx - s / 2).clamp(0.0, math.max(0.0, size.width - s));
    var top = at.dy - s - gap;
    if (top < 0) top = math.min(at.dy + gap, math.max(0.0, size.height - s));
    final centre = Offset(left + s / 2, top + s / 2);
    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: RawMagnifier(
          key: const Key('touch_loupe'),
          size: const Size(s, s),
          magnificationScale: 2.5,
          focalPointOffset: at - centre,
          decoration: MagnifierDecoration(
            shape: CircleBorder(side: BorderSide(color: Cad.accent, width: 2)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1.6.0 CAD: the text edited in place lies outside the canvas's own keys
    return Stack(
      children: [
        Positioned.fill(child: _canvas(context)),
        if (_editingText != null && _textCtl != null) _textEditor(),
      ],
    );
  }

  Widget _canvas(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      autofocus: true,
      // Shortcuts are handled by the app-wide dispatcher before focus
      // dispatch; swallowing the keys here keeps arrows from moving the
      // focus and Enter/Space from activating other widgets.
      onKeyEvent: (node, e) => e.logicalKey == LogicalKeyboardKey.tab ? KeyEventResult.ignored : KeyEventResult.handled,
      child: LayoutBuilder(
        builder: (context, constraints) {
          c.camera.size = Size(constraints.maxWidth, constraints.maxHeight);
          return MouseRegion(
            cursor: c.activeTool == ToolId.pan || _panning ? SystemMouseCursors.grab : (c.activeTool == ToolId.select ? SystemMouseCursors.basic : SystemMouseCursors.precise),
            onHover: _onPointerHover,
            onExit: (_) {
              _tool.cursor = null;
              _redraw();
            },
            child: Listener(
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerCancel,
              onPointerSignal: _onSignal,
              behavior: HitTestBehavior.opaque,
              // ClipRect: CustomPaint does not clip, so world-space geometry
              // would otherwise bleed under the palette and the panels.
              child: ClipRect(
                child: Stack(
                  children: [
                    RepaintBoundary(
                      child: CustomPaint(
                        painter: _painter
                          ..tool = _tool
                          ..snapResult = _snap
                          ..devicePixelRatio = MediaQuery.devicePixelRatioOf(context),
                        size: Size.infinite,
                      ),
                    ),
                    // the credit of the base map: readable, and a link to the source's copyright and terms
                    if (c.baseMap != BaseMap.none && c.project.meta.georef != null && basemap.attributionText(c.baseMap).isNotEmpty)
                      Positioned(
                        left: 8,
                        bottom: 30,
                        child: _AttributionLink(text: basemap.attributionText(c.baseMap), url: BaseMapLayer.attributionUrl(c.baseMap)),
                      ),
                    // touch-friendly zoom buttons
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Column(
                        children: [
                          // 1.6.0 UI (UI-23): named for the screen reader and the pointer, finger-sized on touch screens
                          _roundButton(Icons.add, () => c.zoomBy(1.25), c.t('view.zoomIn'), const Key('canvas_zoom_in')),
                          const SizedBox(height: 4),
                          _roundButton(Icons.remove, () => c.zoomBy(0.8), c.t('view.zoomOut'), const Key('canvas_zoom_out')),
                          const SizedBox(height: 4),
                          _roundButton(Icons.fit_screen, c.zoomAll, c.t('view.zoomAll'), const Key('canvas_zoom_all')),
                        ],
                      ),
                    ),
                    // 1.6.0 CAD: length and angle beside the cursor, the magnifier over the finger
                    _dynamicInput(),
                    if (_aiming && _aimAt != null) _loupe(_aimAt!),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _roundButton(IconData icon, VoidCallback onTap, String label, Key key) {
    final side = touchInput ? 48.0 : 32.0;
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: Cad.overlay,
          shape: const CircleBorder(),
          child: InkWell(
            key: key,
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: side,
              height: side,
              child: Icon(icon, size: touchInput ? 22 : 16, color: Cad.fg70),
            ),
          ),
        ),
      ),
    );
  }
}

/// The credit of the base map over the canvas, as the sources ask: plain
/// to read, and a link to their copyright and terms page.
class _AttributionLink extends StatelessWidget {
  const _AttributionLink({required this.text, required this.url});
  final String text;
  final String url;

  @override
  Widget build(BuildContext context) => Material(
    key: const Key('basemap_credit'),
    color: Cad.overlay,
    borderRadius: BorderRadius.circular(3),
    child: InkWell(
      borderRadius: BorderRadius.circular(3),
      onTap: url.isEmpty ? null : () => openExternalLink(url),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          text,
          style: TextStyle(fontSize: 11, color: Cad.fg70, decoration: url.isEmpty ? null : TextDecoration.underline, decorationColor: Cad.fg38),
        ),
      ),
    ),
  );
}
