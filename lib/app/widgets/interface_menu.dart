/// View → Interface: the size of the whole interface, high contrast, focus
/// mode and the side panel folded away (see lib/app/ui_prefs.dart).
library;

import 'package:flutter/material.dart';

import '../state/controller.dart';
import '../ui_prefs.dart';

/// The size of [uiScales] nearest to the current one (a radio group needs
/// one of its values).
double nearestUiScale() {
  var best = uiScales.first;
  for (final s in uiScales) {
    if ((s - uiScale.value).abs() < (best - uiScale.value).abs()) best = s;
  }
  return best;
}

/// "115 %".
String uiScalePercent(double s) => '${(s * 100).round()} %';

/// The submenu of View in the menu bar.
SubmenuButton interfaceMenu(ProjectController c, {VoidCallback? onOpen, VoidCallback? onClose}) {
  final t = c.t;
  final scale = nearestUiScale();
  return SubmenuButton(
    key: const Key('menu_interface'),
    onOpen: onOpen,
    onClose: onClose,
    leadingIcon: const Icon(Icons.aspect_ratio, size: 16),
    menuChildren: [
      for (final s in uiScales)
        RadioMenuButton<double>(
          key: Key('menu_ui_scale_${(s * 100).round()}'),
          value: s,
          groupValue: scale,
          onChanged: (v) => setUiScale(v ?? 1),
          child: Text(t('uiv.scaleItem', {'p': uiScalePercent(s)})),
        ),
      const Divider(height: 1),
      CheckboxMenuButton(key: const Key('menu_ui_contrast'), value: uiHighContrast.value, onChanged: (v) => setHighContrast(v ?? false), child: Text(t('uiv.contrast'))),
      CheckboxMenuButton(key: const Key('menu_ui_focus'), value: uiFocusMode.value, onChanged: (v) => setFocusMode(v ?? false), child: Text('${t('uiv.focus')}  (Ctrl+Alt+F)')),
      CheckboxMenuButton(key: const Key('menu_ui_side'), value: uiSideFolded.value, onChanged: (v) => setSideFolded(v ?? false), child: Text(t('uiv.side'))),
    ],
    child: Text(t('uiv.menu')),
  );
}
