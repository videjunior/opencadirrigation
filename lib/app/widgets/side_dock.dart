/// The side panel of a wide window (Properties, Layers, History): docked
/// beside the drawing at the width the user dragged its edge to, or folded
/// into a slim strip that gives the drawing the room (View → Interface →
/// Side panel folded away). Both are kept between sessions.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../state/controller.dart';
import '../theme.dart';
import '../ui_prefs.dart';
import 'layout_mode.dart' show touchInput;

class SideDock extends StatelessWidget {
  const SideDock({super.key, required this.c, required this.child, this.panelKey});
  final ProjectController c;
  final Widget child;

  /// Key of the panel itself (the tutorial points at it).
  final Key? panelKey;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(valueListenable: uiSideFolded, builder: (context, folded, _) => folded ? _strip(context) : _docked(context));

  Widget _strip(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const VerticalDivider(width: 1),
      Container(
        key: const Key('side_strip'),
        width: touchInput ? 48 : 30,
        color: Cad.panel,
        alignment: Alignment.topCenter,
        child: IconButton(key: const Key('side_unfold'), tooltip: c.t('ui.sideOpen'), icon: const Icon(Icons.chevron_left, size: 18), onPressed: () => setSideFolded(false)),
      ),
    ],
  );

  Widget _docked(BuildContext context) {
    // (in Arabic and Urdu the panel is on the left: dragging right widens it)
    final sign = Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;
    return ValueListenableBuilder<double>(
      valueListenable: uiSideWidth,
      builder: (context, width, _) {
        // never more than half of the window
        final half = MediaQuery.sizeOf(context).width * 0.5;
        final widest = half < sidePanelWidthMin ? sidePanelWidthMin : half;
        final w = width.clamp(sidePanelWidthMin, widest).toDouble();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: c.t('uiv.resize'),
              waitDuration: const Duration(milliseconds: 800),
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  key: const Key('side_resize'),
                  behavior: HitTestBehavior.opaque,
                  // (from the width shown, read again at every move: several moves can come within a frame)
                  onHorizontalDragUpdate: (d) {
                    final from = math.min(uiSideWidth.value, widest);
                    uiSideWidth.value = (from - sign * d.delta.dx).clamp(sidePanelWidthMin, sidePanelWidthMax).toDouble();
                  },
                  onHorizontalDragEnd: (_) => setSideWidth(uiSideWidth.value),
                  onDoubleTap: () => setSideWidth(sidePanelWidthDefault),
                  child: SizedBox(
                    width: touchInput ? 12 : 5,
                    child: Center(child: VerticalDivider(width: 1, color: Cad.divider)),
                  ),
                ),
              ),
            ),
            SizedBox(key: panelKey, width: w, child: child),
          ],
        );
      },
    );
  }
}
