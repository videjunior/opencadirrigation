/// 1.6.0 AUT: the computed maximum length of a lateral in the dialogs that
/// lay laterals out — the block (B), the subdivision of a field (SUBDIV)
/// and the automatic layout (LAYOUT): from the tape, or the emitter on its
/// lateral pipe, the slope of the ground along the rows (the terrain of the
/// project, fitted over the block) and the flow variation allowed, the
/// longest lateral fed uphill and downhill (lateral_limit.dart), what stops
/// it, the longest lateral of the block against it and, where the dialog
/// takes a maximum length, a button that fills it in.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/design/block_generator.dart' show SubmainPosition;
import '../../core/design/lateral_limit.dart';
import '../../core/hydraulics/lateral.dart';
import '../../core/model/catalog.dart';
import '../../core/model/project.dart';
import '../../core/units.dart';
import '../state/controller.dart';
import '../theme.dart';
import 'fields.dart';

/// What [LateralLimitView] computes: a lateral and how it works.
class LateralLimitInput {
  const LateralLimitInput({required this.key, required this.spec, required this.nominalHeadM, this.minHeadM, this.maxHeadM, this.slopePct, this.maxVelocity = 3, this.pipeName});

  /// The inputs summed up (the view computes again when it changes).
  final String key;
  final LateralSpec spec;

  /// Mean emitter pressure (m) and the pressure window of the emitter.
  final double nominalHeadM;
  final double? minHeadM, maxHeadM;

  /// Slope of the ground along the rows (%, rising along their direction
  /// positive); null without terrain data (level).
  final double? slopePct;
  final double maxVelocity;

  /// The lateral pipe the estimate takes (when the dialog leaves it to the
  /// design: the largest of the catalogue).
  final String? pipeName;
}

/// The lateral of a drip tape [tapeId] of [p] at [inletHeadM], or null when
/// the catalogue has no such tape.
LateralLimitInput? tapeLimitInput(Project p, String? tapeId, double inletHeadM, double? slopePct) {
  final tp = tapeId == null ? null : p.catalog.tape(tapeId);
  if (tp == null || !(tp.emitterSpacingM > 0) || !(inletHeadM > 0)) return null;
  return LateralLimitInput(
    key: 'tape|${tp.id}|$inletHeadM|$slopePct',
    spec: tapeLateralSpec(tp, p.params),
    nominalHeadM: inletHeadM,
    minHeadM: tp.minHeadM > 0 ? tp.minHeadM : null,
    maxHeadM: tp.maxHeadM > 0 ? tp.maxHeadM : null,
    slopePct: slopePct,
    maxVelocity: p.params.maxLateralVelocity,
  );
}

/// The largest enabled lateral pipe of [cat] (the one the design may go
/// up to when the dialog leaves the pipe to it).
PipeSpec? largestLateralPipe(Catalog cat) {
  PipeSpec? best;
  for (final x in cat.pipesFor(PipeUsage.lateral)) {
    if (best == null || x.innerDiameter > best.innerDiameter) best = x;
  }
  return best;
}

/// The lateral of the nozzle [nozzleId] of emitter [outletId] at [headM]
/// every [spacing] metres on the lateral pipe [pipeId] (the largest lateral
/// pipe when null), or null when the catalogue lacks one of them.
LateralLimitInput? emitterLimitInput(Project p, String? outletId, String? nozzleId, double headM, String? pipeId, double spacing, double? slopePct, {bool halfOffset = true}) {
  final cat = p.catalog;
  final o = outletId == null ? null : cat.outlet(outletId);
  final n = o?.nozzle(nozzleId) ?? o?.nozzles.firstOrNull;
  final pipe = (pipeId == null ? null : cat.pipe(pipeId)) ?? largestLateralPipe(cat);
  if (n == null || pipe == null || !(spacing > 0) || !(headM > 0)) return null;
  return LateralLimitInput(
    key: 'emitter|${o!.id}|${n.id}|$headM|${pipe.id}|$spacing|$halfOffset|$slopePct',
    spec: emitterLateralSpec(n.curve, pipe, spacing, p.params, firstOffset: halfOffset ? spacing / 2 : spacing),
    nominalHeadM: headM,
    minHeadM: n.minHeadM > 0 ? n.minHeadM : null,
    maxHeadM: n.maxHeadM > 0 ? n.maxHeadM : null,
    slopePct: slopePct,
    maxVelocity: p.params.maxLateralVelocity,
    pipeName: pipeId == null ? pipe.name : null,
  );
}

/// The run that limits laterals fed from [feed] on ground of [slopePct]
/// along the rows (rising along their direction positive): fed at the start
/// they run along the direction, at the end against it, from the middle
/// both ways; unknown, the shorter way.
LateralRun limitingRun(LateralRunsBothWays r, double slopePct, SubmainPosition? feed) {
  if (feed == null || feed == SubmainPosition.centre || slopePct.abs() < 1e-9) return r.shorter;
  final rising = (feed == SubmainPosition.start) == (slopePct > 0);
  return rising ? r.uphill : r.downhill;
}

/// The computed maximum lateral length (see the library comment).
class LateralLimitView extends StatefulWidget {
  const LateralLimitView({super.key, required this.c, required this.input, required this.variationPct, required this.onVariation, this.feed, this.longest, this.onUse});
  final ProjectController c;

  /// Null when the dialog has no lateral to compute (no tape or emitter).
  final LateralLimitInput? input;

  /// Flow variation allowed along the lateral (%).
  final double variationPct;
  final ValueChanged<double> onVariation;

  /// Where the laterals of the block are fed (null: unknown).
  final SubmainPosition? feed;

  /// The longest lateral of the block (m), checked against the limit.
  final double? longest;

  /// Takes the limit into the dialog's field of the maximum lateral length.
  final ValueChanged<double>? onUse;

  @override
  State<LateralLimitView> createState() => _LateralLimitViewState();
}

class _LateralLimitViewState extends State<LateralLimitView> {
  String? _key, _pending;
  LateralRunsBothWays? _result;
  Timer? _timer;

  String? get _wanted => widget.input == null ? null : '${widget.input!.key}|${widget.variationPct}';

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _schedule() {
    final want = _wanted;
    if (want == null || want == _key || want == _pending) return;
    _pending = want;
    _timer?.cancel();
    // a moment after the last change, and after the frame that shows it
    _timer = Timer(Duration(milliseconds: _result == null ? 0 : 150), () {
      if (!mounted || _wanted != want) return;
      final i = widget.input!;
      LateralRunsBothWays? r;
      try {
        r = maxLateralRunsBothWays(
          i.spec,
          nominalHeadM: i.nominalHeadM,
          allowedFlowVariationPct: widget.variationPct,
          slopePct: i.slopePct ?? 0,
          minHeadM: i.minHeadM,
          maxHeadM: i.maxHeadM,
          maxVelocity: i.maxVelocity,
        );
      } catch (_) {
        r = null;
      }
      setState(() {
        _result = r;
        _key = want;
        _pending = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c, t = c.t, u = c.units;
    final i = widget.input;
    _schedule();
    String len(double m) => '${fmt(u.lengthFromSi(m), u.lengthFromSi(m) >= 100 ? 0 : 1)} ${u.lengthLabel}';
    String run(LateralRun x) => x.emitters == 0
        ? t('latmax.none')
        : t('latmax.run', {'l': len(x.length), 'n': '${x.emitters}', 'p': '${fmt(u.pressureFromHead(x.inletHeadM), 1)} ${u.pressureLabel}', 'q': '${fmt(x.flowVariationPct, 1)} %'});
    final r = _result;
    final slope = i?.slopePct;
    final stale = _wanted != _key;
    final limit = r == null ? null : limitingRun(r, slope ?? 0, widget.feed);
    final tooLong = limit != null && widget.longest != null && limit.emitters > 0 && widget.longest! > limit.length + 1e-6;
    return Column(
      key: const Key('latmax'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(t('latmax.title')),
        NumField(key: const Key('latmax_variation'), label: t('latmax.variation'), value: widget.variationPct, decimals: 1, onChanged: (v) => widget.onVariation(v.clamp(1, 50).toDouble())),
        if (i == null)
          _text(t('latmax.noLateral'), Cad.fg54)
        else ...[
          KV(t('latmax.slope'), slope == null ? t('latmax.noTerrain') : '${fmt(slope.abs(), 1)} %'),
          if (i.pipeName != null) KV(t('latmax.pipe'), i.pipeName!),
          if (stale) const Padding(padding: EdgeInsets.symmetric(vertical: 3), child: LinearProgressIndicator(minHeight: 2)),
          if (r != null) ...[
            if ((slope ?? 0).abs() < 1e-9) KV(t('latmax.level'), run(r.uphill)) else ...[KV(t('latmax.uphill'), run(r.uphill)), KV(t('latmax.downhill'), run(r.downhill))],
            if (limit != null) _text(t('latmax.by.${limit.limitedBy.name}'), Cad.fg54),
            if (widget.longest != null && widget.longest! > 0) KV(t('latmax.longest'), len(widget.longest!), color: tooLong ? Cad.warning : null),
            if (tooLong) _text(t('latmax.tooLong', {'l': len(widget.longest!), 'm': len(limit.length)}), Cad.warning),
            if (widget.onUse != null && limit != null && limit.emitters > 0)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  key: const Key('latmax_use'),
                  onPressed: () => widget.onUse!(limit.length),
                  icon: const Icon(Icons.straighten, size: 16),
                  label: Text(t('latmax.use', {'l': len(limit.length)})),
                ),
              ),
          ],
        ],
      ],
    );
  }

  Widget _text(String s, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Text(localizeUi(s), style: TextStyle(fontSize: 11.5, color: color)),
  );
}
