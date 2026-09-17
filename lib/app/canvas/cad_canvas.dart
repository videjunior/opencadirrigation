import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/model/geometry.dart';
import '../state/controller.dart';
import '../keys/canvas_keys.dart';
import '../state/workspace.dart';
import '../tools/tools.dart';
import 'basemap.dart';
import 'painter.dart';
import 'snapping.dart';

class CadCanvas extends StatefulWidget {
  const CadCanvas({
    super.key,
    required this.controller,
    required this.host,
    required this.focusNode,
    this.workspace,
    this.onArray,
  });
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
  bool _spaceDown = false;
  final _repaint = ValueNotifier<int>(0);
  final BaseMapLayer basemap = BaseMapLayer();

  /// Active touch pointers (id → position) for pinch zoom / two-finger pan.
  final Map<int, Offset> _touches = {};
  double? _pinchDistance;
  Offset? _pinchCenter;
  bool _touchGesture = false;
  bool _touchDrawPending = false;

  ProjectController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _snapper = Snapper(c);
    c.keyTarget = this;
    _tool = createTool(c.activeTool, c, widget.host);
    c.addListener(_onController);
    basemap.addListener(_redraw);
  }

  @override
  void dispose() {
    if (identical(c.keyTarget, this)) c.keyTarget = null;
    c.removeListener(_onController);
    basemap.removeListener(_redraw);
    basemap.dispose();
    super.dispose();
  }

  void _onController() {
    if (_tool.id != c.activeTool) {
      _tool.cancel();
      _tool = createTool(c.activeTool, c, widget.host);
      _snap = null;
    }
    _repaint.value++;
  }

  void _redraw() => _repaint.value++;

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
    _snap = _snapper.snap(
      raw,
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
    if (_isTouch(e)) {
      _touches[e.pointer] = e.localPosition;
      if (_touches.length >= 2) {
        // second finger: cancel any single-finger drawing and start a gesture
        if (_touchDrawPending) {
          _touchDrawPending = false;
        }
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
      return;
    }
    if (e.buttons == kMiddleMouseButton ||
        e.buttons == kSecondaryMouseButton ||
        _spaceDown ||
        c.activeTool == ToolId.pan) {
      _panning = true;
      return;
    }
    if (e.buttons == kPrimaryMouseButton) {
      _primaryDown(e.localPosition);
    }
  }

  void _primaryDown(Offset local) {
    final now = DateTime.now();
    final isDouble =
        now.difference(_lastDown).inMilliseconds < 350 &&
        _lastDownPos != null &&
        (_lastDownPos! - local).distance < 6;
    _lastDown = now;
    _lastDownPos = local;
    final p = _snapped(local);
    final keys = HardwareKeyboard.instance;
    if (isDouble) {
      _tool.onDoubleClick(p);
    } else {
      _tool.onDown(
        p,
        shift: keys.isShiftPressed,
        ctrl: keys.isControlPressed || keys.isMetaPressed,
      );
      if (_snap?.locked ?? false) c.track('lock');
    }
    _dragging = true;
    _redraw();
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
            _primaryDown(_lastPointer!);
          }
        }
      }
    }
    if (_panning && _lastPointer != null) {
      c.camera.panPixels(e.localPosition - _lastPointer!);
      _lastPointer = e.localPosition;
      _redraw();
      return;
    }
    _lastPointer = e.localPosition;
    final p = _snapped(e.localPosition);
    _tool.onMove(p, dragging: _dragging);
    _updateStatus(p);
    _redraw();
  }

  void _onPointerHover(PointerHoverEvent e) {
    _lastPointer = e.localPosition;
    final p = _snapped(e.localPosition);
    _tool.onMove(p);
    if (_tool is SelectTool) {
      final hit = c.pick(
        _world(e.localPosition),
        c.snap.tolerancePx / c.camera.scale,
      );
      final id = hit?.id;
      if (id != c.hoverId) c.hoverId = id;
    }
    _updateStatus(p);
    _redraw();
  }

  void _updateStatus(Pt p) {
    final u = c.units;
    widget.host.setStatus(
      'X ${u.lengthFromSi(p.x).toStringAsFixed(2)}  Y ${u.lengthFromSi(p.y).toStringAsFixed(2)} ${u.lengthLabel}${_snap != null && _snap!.isSnapped ? '   [${_snap!.kind}]' : ''}',
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
      if (_touchDrawPending) {
        // simple tap: run the tool's down + up at the tap position
        _touchDrawPending = false;
        _primaryDown(e.localPosition);
      }
    }
    if (_panning) {
      _panning = false;
      c.track('pan');
      return;
    }
    if (_dragging) {
      _dragging = false;
      final p = _snapped(e.localPosition);
      _tool.onUp(p);
      _redraw();
    }
  }

  void _onPointerCancel(PointerCancelEvent e) {
    _touches.remove(e.pointer);
    if (_touches.isEmpty) {
      _touchGesture = false;
      _touchDrawPending = false;
      _panning = false;
    }
  }

  void _onSignal(PointerSignalEvent e) {
    if (e is PointerScrollEvent) {
      final factor = e.scrollDelta.dy > 0 ? 1 / 1.15 : 1.15;
      c.camera.zoomAt(e.localPosition, factor);
      c.track('zoom');
      _redraw();
    } else if (e is PointerScaleEvent) {
      // trackpad pinch
      c.camera.zoomAt(e.localPosition, e.scale.clamp(0.5, 2.0));
      _redraw();
    }
  }

  // ---- CanvasKeyTarget: keys arrive through the app-wide dispatcher (see
  // keys/hotkeys.dart), whatever widget has the focus.
  @override
  void toolKey(String key) {
    _tool.onKey(key);
    _redraw();
  }

  @override
  bool get toolIdle => _tool is! PolyTool || (_tool as PolyTool).pts.isEmpty;

  @override
  void setSpaceHeld(bool held) => _spaceDown = held;

  @override
  void modifiersChanged() {
    final lp = _lastPointer;
    if (lp == null || _panning) return;
    final p = _snapped(lp);
    _tool.onMove(p, dragging: _dragging);
    _updateStatus(p);
    _redraw();
  }

  @override
  void redraw() => _redraw();

  @override
  Widget build(BuildContext context) {
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
            cursor: c.activeTool == ToolId.pan || _panning
                ? SystemMouseCursors.grab
                : (c.activeTool == ToolId.select
                      ? SystemMouseCursors.basic
                      : SystemMouseCursors.precise),
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
                        painter: CadPainter(
                          c: c,
                          tool: _tool,
                          snapResult: _snap,
                          basemap: basemap,
                          repaint: Listenable.merge([_repaint, c]),
                        ),
                        size: Size.infinite,
                      ),
                    ),
                    // touch-friendly zoom buttons
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Column(
                        children: [
                          _roundButton(Icons.add, () => c.zoomBy(1.25)),
                          const SizedBox(height: 4),
                          _roundButton(Icons.remove, () => c.zoomBy(0.8)),
                          const SizedBox(height: 4),
                          _roundButton(Icons.fit_screen, c.zoomAll),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _roundButton(IconData icon, VoidCallback onTap) => Material(
    color: const Color(0xAA1B1F24),
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox(width: math.max(28, 32), height: 32, child: Icon(icon, size: 16, color: Colors.white70)),
    ),
  );
}
