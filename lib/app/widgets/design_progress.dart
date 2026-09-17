import 'package:flutter/material.dart';

import '../../core/design/designer.dart';
import '../../core/model/entities.dart';
import '../state/controller.dart';

/// Compact progress card shown in a corner of the canvas while a design
/// runs. It blocks nothing: the user keeps panning, zooming, selecting and
/// reading reports meanwhile (the controller refuses edits until the run
/// ends). Names the current stage (zone i of n, mainline, flushing…) and
/// shows the fraction of steps completed.
class DesignProgressOverlay extends StatelessWidget {
  const DesignProgressOverlay({super.key, required this.c, this.compact = false});

  final ProjectController c;

  /// Phone layout: fills the width it is given and drops the hint line.
  final bool compact;

  String _stageLabel() {
    final t = c.t;
    final p = c.progress;
    if (p == null) return t('design.progress.start');
    switch (p.stage) {
      case DesignStage.zones:
        final e = p.zoneId == null ? null : c.project.byId(p.zoneId!);
        final name = e == null
            ? ''
            : (e is ControlValveEntity && e.zoneName.isNotEmpty
                  ? e.zoneName
                  : e.name);
        final base = t('design.progress.zones', {
          'i': '${p.zoneIndex}',
          'n': '${p.zoneCount}',
        });
        return name.isEmpty ? base : '$base: $name';
      case DesignStage.mainline:
        return t('design.progress.mainline');
      case DesignStage.splits:
        return t('design.progress.splits');
      case DesignStage.flushing:
        return t('design.progress.flushing');
      case DesignStage.surge:
        return t('design.progress.surge');
      case DesignStage.bom:
        return t('design.progress.bom');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = c.t;
    final p = c.progress;
    final fraction = p?.fraction ?? 0;
    return Material(
      key: const Key('design_progress'),
      elevation: 8,
      borderRadius: BorderRadius.circular(8),
      color: const Color(0xF2262B32),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: compact ? double.infinity : 320),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // determinate: an indeterminate spinner freezes mid-arc while a step runs
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(value: fraction, strokeWidth: 2.5, backgroundColor: Colors.white12)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t('design.progress.title'),
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${(fraction * 100).round()}%',
                    key: const Key('design_progress_pct'),
                    style: const TextStyle(fontSize: 11, color: Colors.white54),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Semantics(
                liveRegion: true,
                child: Text(
                  _stageLabel(),
                  key: const Key('design_progress_stage'),
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                  maxLines: compact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: p?.fraction,
                  minHeight: 4,
                  backgroundColor: Colors.white12,
                ),
              ),
              if (!compact) ...[
                const SizedBox(height: 8),
                Text(
                  key: const Key('design_progress_hint'),
                  t(c.designMode == 'thread' ? 'design.progress.hint' : 'design.progress.bg'),
                  style: const TextStyle(fontSize: 10.5, color: Colors.white38),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
