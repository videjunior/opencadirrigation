import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../state/controller.dart';
import '../shortcuts.dart';
import '../tutorial/tutorial.dart';
import '../version.dart';
import '../theme.dart';
import 'ai/ai_panel.dart';
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
    Widget toggle(String label, bool on, VoidCallback onTap) => Semantics(
      button: true,
      toggled: on,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: on ? Cad.accentFill : Colors.transparent, borderRadius: BorderRadius.circular(3)),
          // white on the blue fill in the light theme
          child: Text(label, style: TextStyle(fontSize: 11, color: on && Cad.isLight ? Colors.white : null)),
        ),
      ),
    );
    return Container(
      // (grows with the text size the user chose, so the text is never cut)
      height: math.max(24.0, MediaQuery.textScalerOf(context).scale(11) + 13),
      color: Cad.panel,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: LayoutBuilder(
        builder: (context, box) => Row(
          children: [
            Expanded(
              child: Text(
                hint,
                style: TextStyle(fontSize: 11, color: Cad.fg60),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // narrow windows: the indicators and toggles scroll instead of overflowing
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: math.max(0, box.maxWidth - 120)),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Millimetres one logical pixel measures on a screen of 96 dots per inch
/// (the reference pixel of the CSS and of Flutter).
const screenMmPerPixel = 25.4 / 96;

/// N of the scale 1:N the drawing has on the screen at [pixelsPerMetre]
/// (the camera scale): one metre of the drawing over the millimetres it
/// takes on the screen.
double screenScaleDenominator(double pixelsPerMetre) => pixelsPerMetre <= 0 ? double.infinity : 1000 / (pixelsPerMetre * screenMmPerPixel);
