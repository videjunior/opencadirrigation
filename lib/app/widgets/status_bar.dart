import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../state/controller.dart';
import '../shortcuts.dart';
import '../tutorial/tutorial.dart';
import '../version.dart';
import '../theme.dart';
import 'ai/ai_panel.dart';
import '../canvas/snapping.dart' show snapModeKey;
import 'dialogs/cad_plus_dialogs.dart' show showSnapSettingsDialog;
import 'dialogs/storage_dialog.dart';
import 'layout_mode.dart';

class StatusBar extends StatelessWidget {
  const StatusBar({super.key, required this.c, required this.status, required this.hint});
  final ProjectController c;

  /// Cursor coordinates and the view scale (rebuilt on their own as the
  /// cursor moves).
  final ValueListenable<(String, double)> status;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final t = c.t;
    Widget toggle(String label, bool on, VoidCallback onTap) => _Toggle(
      label: label,
      on: on,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: on ? Cad.accentFill : Colors.transparent, borderRadius: BorderRadius.circular(3)),
        // white on the blue fill in the light theme
        child: Text(label, style: TextStyle(fontSize: 11, color: on && Cad.isLight ? Colors.white : null)),
      ),
    );
    return Container(
      // (grows with the text size the user chose, so the text is never cut)
      height: math.max(24.0, MediaQuery.textScalerOf(context).scale(11) + 13),
      color: Cad.panel,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: _StatusRow(
        children: [
          Expanded(
            child: Text(
              hint,
              style: TextStyle(fontSize: 11, color: Cad.fg60),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (c.command.isNotEmpty) ...[
            Container(
              key: const Key('command_line'),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              decoration: BoxDecoration(
                border: Border.all(color: Cad.accent),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                '${t('status.command')}: ${c.command}_${commandTargetLabel(t, c.command)}',
                style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: Cad.accentText),
              ),
            ),
            const SizedBox(width: 12),
          ],
          ValueListenableBuilder(
            valueListenable: status,
            builder: (_, s, _) => Text(s.$1, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
          ),
          const SizedBox(width: 12),
          if (c.autoAnalyze) ...[
            Tooltip(
              message: t('design.autoAnalyzeTip'),
              child: Text(
                c.autoRunning ? '⟳ ${t('design.autoRunning')}' : '⟳ ${t('design.autoOn')}',
                key: const Key('auto_chip'),
                style: TextStyle(fontSize: 11, color: c.autoRunning ? Cad.highlight : Cad.fg54),
              ),
            ),
            const SizedBox(width: 12),
          ],
          // the copy in the browser failed: stays until a later one is kept
          if (c.storeProblem case final problem?) ...[
            Tooltip(
              message: problem,
              child: InkWell(
                key: const Key('store_problem_chip'),
                onTap: () => showStorageDialog(context, c),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: Cad.attention.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(3)),
                  child: Text('⚠ ${t('store.problem')}', style: TextStyle(fontSize: 11, color: Cad.attention)),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          if (c.gpsActive) ...[
            InkWell(
              key: const Key('gps_chip'),
              onTap: c.stopGps,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: Cad.infoFill.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(3)),
                child: Text(c.gpsFix == null ? t('gps.waiting') : '${c.gpsTrack != null ? '● ' : ''}GPS ±${c.gpsFix!.accuracyM.round()} m', style: TextStyle(fontSize: 11, color: Cad.info)),
              ),
            ),
            const SizedBox(width: 12),
          ],
          if (c.angleLockActive) ...[
            Container(
              key: const Key('angle_lock'),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: Cad.accent.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(3)),
              child: Text('⇧ 45°', style: TextStyle(fontSize: 11, color: Cad.accentText)),
            ),
            const SizedBox(width: 12),
          ],
          // (on narrow windows the assistant stays in the Design menu and the AI command)
          if (assistantDocks(context)) ...[AiPanelButton(c: c), const SizedBox(width: 8)],
          Row(
            key: TutorialTargets.statusToggles,
            mainAxisSize: MainAxisSize.min,
            children: [
              toggle('${t('status.snap')} F3', c.snap.enabled, () {
                c.snap.enabled = !c.snap.enabled;
                c.refresh();
              }),
              toggle('${t('status.grid')} F9', c.snap.grid, () {
                c.snap.grid = !c.snap.grid;
                c.refresh();
              }),
              toggle('${t('status.ortho')} F8', c.snap.ortho, () {
                c.snap.ortho = !c.snap.ortho;
                c.refresh();
              }),
              Tooltip(
                message: t('status.polarTip'),
                child: toggle(c.snap.polarStepDeg > 0 ? '${t('status.polar')} ${c.snap.polarStepDeg.round()}° F10' : '${t('status.polar')} F10', c.snap.polarStepDeg > 0, () {
                  c.snap.nextPolarStep();
                  c.refresh();
                }),
              ),
              Tooltip(
                message: t('status.keepLinksTip'),
                child: toggle(t('status.keepLinks'), c.toolSettings.keepConnections, () {
                  c.toolSettings.keepConnections = !c.toolSettings.keepConnections;
                  c.refresh();
                }),
              ),
              // 1.6.0 CAD: the object snaps one by one (and a snap chosen for the next point)
              Tooltip(
                message: t('snap.settings'),
                child: InkWell(
                  key: const Key('status_snap_settings'),
                  onTap: () => showSnapSettingsDialog(context, c),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    child: Text(c.snap.once == null ? '⋯' : '→ ${t(snapModeKey(c.snap.once!))}', style: TextStyle(fontSize: 11, color: c.snap.once == null ? Cad.fg54 : Cad.accentText)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder(
            valueListenable: status,
            builder: (_, _, _) => Tooltip(
              message: t('ui.scaleTip'),
              child: Text(
                '${c.project.entities.length} ent.  1:${screenScaleDenominator(c.camera.scale).round()}',
                key: const Key('status_scale'),
                style: TextStyle(fontSize: 11, color: Cad.fg54),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Tooltip(
            message: '$appName ${t('about.version', {'v': appVersionLabel})}',
            child: Text(
              'v$appVersionFull',
              key: const Key('status_version'),
              style: TextStyle(fontSize: 11, color: Cad.fg38),
            ),
          ),
        ],
      ),
    );
  }
}

/// A toggle of the status bar: its fill says whether it is on, and so does
/// its semantics (the screen reader says "on" / "off").
class _Toggle extends StatelessWidget {
  const _Toggle({required this.label, required this.on, required this.onTap, required this.child});
  final String label;
  final bool on;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    toggled: on,
    label: label,
    excludeSemantics: true,
    child: InkWell(onTap: onTap, child: child),
  );
}

/// The row of the status bar: the hint (its first child, [Expanded]) takes
/// what is left, and the indicators and toggles after it scroll instead of
/// overflowing a narrow window (their end stays in view).
class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => Row(
      children: [
        children.first,
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: math.max(0, box.maxWidth - 120)),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Row(mainAxisSize: MainAxisSize.min, children: children.sublist(1)),
          ),
        ),
      ],
    ),
  );
}

/// Millimetres one logical pixel measures on a screen of 96 dots per inch
/// (the reference pixel of the CSS and of Flutter).
const screenMmPerPixel = 25.4 / 96;

/// N of the scale 1:N the drawing has on the screen at [pixelsPerMetre]
/// (the camera scale): one metre of the drawing over the millimetres it
/// takes on the screen.
double screenScaleDenominator(double pixelsPerMetre) => pixelsPerMetre <= 0 ? double.infinity : 1000 / (pixelsPerMetre * screenMmPerPixel);
