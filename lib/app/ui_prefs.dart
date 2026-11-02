/// Preferences of the interface itself (View → Interface), kept in this
/// browser between sessions: the size of the whole interface, independent
/// of the browser zoom; the high-contrast palette; the side panel folded or
/// at the width the user dragged it to, and the height of the reports.
/// Focus mode (the drawing board alone) lasts for the session.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'io/prefs.dart';

/// Sizes offered for the interface (1 = as designed).
const uiScales = [0.85, 1.0, 1.15, 1.3, 1.5];

/// Smallest and largest interface size accepted (a value kept by hand or
/// by an older version is brought inside).
const uiScaleMin = 0.75, uiScaleMax = 2.0;

/// Width of the docked side panel: as designed, and the range the user may
/// drag it to.
const sidePanelWidthDefault = 300.0, sidePanelWidthMin = 220.0, sidePanelWidthMax = 640.0;

/// The size of the interface: every widget, text and icon is drawn at this
/// scale (the drawing keeps its own zoom).
final ValueNotifier<double> uiScale = ValueNotifier<double>(_savedScale());

/// The high-contrast palette (stronger text, borders and accents, in the
/// dark and in the light theme).
final ValueNotifier<bool> uiHighContrast = ValueNotifier<bool>(getPref('ui_contrast') == '1');

/// Focus mode: menus, tabs, tool palette, panels and status bar hidden, the
/// drawing board on the whole window (Ctrl+Alt+F). Not kept.
final ValueNotifier<bool> uiFocusMode = ValueNotifier<bool>(false);

/// The side panel of a wide window folded into a slim strip.
final ValueNotifier<bool> uiSideFolded = ValueNotifier<bool>(getPref('ui_side_folded') == '1');

/// Width the user gave the docked side panel.
final ValueNotifier<double> uiSideWidth = ValueNotifier<double>(_savedDouble('ui_side_width', sidePanelWidthDefault, sidePanelWidthMin, sidePanelWidthMax));

/// Height the user gave the reports panel (null: the default).
double? savedReportsHeight() {
  final v = double.tryParse(getPref('ui_reports_height') ?? '');
  return v == null || !v.isFinite ? null : v.clamp(120.0, 900.0).toDouble();
}

void saveReportsHeight(double h) {
  if (h.isFinite) setPref('ui_reports_height', h.round().toString());
}

double _savedScale() => _savedDouble('ui_scale', 1, uiScaleMin, uiScaleMax);

double _savedDouble(String key, double fallback, double min, double max) {
  final v = double.tryParse(getPref(key) ?? '');
  if (v == null || !v.isFinite) return fallback;
  return v.clamp(min, max).toDouble();
}

/// Sets the interface size (kept).
void setUiScale(double s) {
  final v = s.isFinite ? s.clamp(uiScaleMin, uiScaleMax).toDouble() : 1.0;
  if ((v - 1).abs() < 1e-9) {
    removePref('ui_scale');
  } else {
    setPref('ui_scale', '$v');
  }
  uiScale.value = v;
}

/// The next of [uiScales] after the current size (with [up]) or before it.
double nextUiScale({required bool up}) {
  final cur = uiScale.value;
  if (up) return uiScales.firstWhere((s) => s > cur + 1e-6, orElse: () => uiScales.last);
  return uiScales.lastWhere((s) => s < cur - 1e-6, orElse: () => uiScales.first);
}

void setHighContrast(bool on) {
  if (on) {
    setPref('ui_contrast', '1');
  } else {
    removePref('ui_contrast');
  }
  uiHighContrast.value = on;
}

void setSideFolded(bool folded) {
  if (folded) {
    setPref('ui_side_folded', '1');
  } else {
    removePref('ui_side_folded');
  }
  uiSideFolded.value = folded;
}

void setSideWidth(double w) {
  final v = w.isFinite ? w.clamp(sidePanelWidthMin, sidePanelWidthMax).toDouble() : sidePanelWidthDefault;
  setPref('ui_side_width', v.round().toString());
  uiSideWidth.value = v;
}

void setFocusMode(bool on) => uiFocusMode.value = on;

/// Reads the kept preferences again (a test that changed them, a new
/// shell).
void reloadUiPrefs() {
  uiScale.value = _savedScale();
  uiHighContrast.value = getPref('ui_contrast') == '1';
  uiSideFolded.value = getPref('ui_side_folded') == '1';
  uiSideWidth.value = _savedDouble('ui_side_width', sidePanelWidthDefault, sidePanelWidthMin, sidePanelWidthMax);
  uiFocusMode.value = false;
}

/// Draws [child] at the interface size [uiScale]: it is laid out in a
/// window [uiScale] times smaller and scaled up to fill the real one, so
/// menus, dialogs, tooltips and the on-screen keyboard insets all agree
/// (the drawing is rendered at the finer pixel ratio, never blurred).
class UiScaled extends StatelessWidget {
  const UiScaled({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: uiScale,
    builder: (context, s, _) {
      final mq = MediaQuery.of(context);
      // a larger interface never leaves less than 320 × 320 to lay out in
      var k = s;
      if (k > 1) k = math.max(1.0, math.min(k, math.min(mq.size.width, mq.size.height) / 320));
      if ((k - 1).abs() < 1e-6 || mq.size.isEmpty) return child;
      final inner = mq.size / k;
      return MediaQuery(
        data: mq.copyWith(
          size: inner,
          devicePixelRatio: mq.devicePixelRatio * k,
          padding: mq.padding / k,
          viewPadding: mq.viewPadding / k,
          viewInsets: mq.viewInsets / k,
          systemGestureInsets: mq.systemGestureInsets / k,
        ),
        child: FittedBox(
          fit: BoxFit.fill,
          alignment: Alignment.topLeft,
          child: SizedBox(width: inner.width, height: inner.height, child: child),
        ),
      );
    },
  );
}
