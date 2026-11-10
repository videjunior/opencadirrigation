/// The irrigation programme played on the plan (1.7.0): a player over the
/// drawing — play, pause, speed, a slider over the cycle of the programme
/// and its runs, the moment shown on the drawing (playback_overlay.dart) —
/// that leaves the drawing visible and usable (pan, zoom) beneath it, and
/// its exports: the moment as a PNG, the cycle as an animated GIF, the
/// programme as a calendar file (.ics) for the phone.
///
/// Without design results or without any run in the programme the player
/// does not open: a dialog says what is missing and how to get it.
library;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/design/programme_calendar.dart';
import '../../../core/design/programme_playback.dart';
import '../../actions.dart' show deliverExport;
import '../../canvas/playback_overlay.dart';
import '../../io/playback_export.dart';
import '../../state/controller.dart';
import '../../theme.dart';
import '../fields.dart';
import '../layout_mode.dart';
import 'terrain_dialogs.dart' show dialogWidth;

/// Where the exports of the player go: the app's download (tests replace
/// it to read the files). [data] is a String (text) or a Uint8List.
Future<void> Function(ProjectController c, String filename, String mime, Object data) playbackFileSink = (c, filename, mime, data) => deliverExport(c, filename, mime, () => data);

/// Why the programme of [c] cannot be played (null: it can), and the
/// playback when it can.
(ProgrammePlayback?, String?) loadProgrammePlayback(ProjectController c, {int? month, DateTime? startDate, bool withReservoirs = true}) {
  final r = c.results;
  if (r == null) return (null, c.t('ply.needResults'));
  final pb = ProgrammePlayback.build(c.project, r, month: month, startDate: startDate, withReservoirs: withReservoirs);
  if (pb.timeline.isEmpty) return (null, c.t('ply.noRuns'));
  return (pb, null);
}

/// The panel of the player of every tab.
final _panels = Expando<OverlayEntry>('programmePlayerPanel');

/// Design → Agronomy → Play the programme on the plan: opens the player
/// over the drawing (or says what is missing).
Future<void> showProgrammePlayer(BuildContext context, ProjectController c) async {
  final (pb, problem) = loadProgrammePlayback(c);
  if (pb == null) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(c.t('ply.title'), style: const TextStyle(fontSize: 15)),
        content: SizedBox(
          width: dialogWidth(ctx, 420),
          child: Text(problem ?? '', key: const Key('ply_missing'), style: const TextStyle(fontSize: 12.5)),
        ),
        actions: [TextButton(key: const Key('ply_missing_close'), onPressed: () => Navigator.pop(ctx), child: Text(c.t('close')))],
      ),
    );
    return;
  }
  final pl = c.programmePlayer;
  pl.show(pb, hour: pb.timeline.spans.first.start);
  final open = _panels[c];
  if (open != null && open.mounted) {
    open.markNeedsBuild();
    return;
  }
  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _PlayerPanel(
      c: c,
      onClose: () {
        if (entry.mounted) entry.remove();
        if (identical(_panels[c], entry)) _panels[c] = null;
        c.programmePlayer.hide();
      },
    ),
  );
  _panels[c] = entry;
  overlay.insert(entry);
}

/// Hours of the programme per second of play.
const playbackSpeeds = [0.25, 0.5, 1.0, 2.0, 4.0, 8.0, 12.0, 24.0];

/// The speed that plays a cycle of [hours] in about half a minute.
double playbackSpeedFor(double hours) => playbackSpeeds.firstWhere((s) => s >= hours / 30, orElse: () => playbackSpeeds.last);

class _PlayerPanel extends StatefulWidget {
  const _PlayerPanel({required this.c, required this.onClose});
  final ProjectController c;
  final VoidCallback onClose;

  @override
  State<_PlayerPanel> createState() => _PlayerPanelState();
}

class _PlayerPanelState extends State<_PlayerPanel> with SingleTickerProviderStateMixin {
  ProjectController get c => widget.c;
  ProgrammePlayer get pl => c.programmePlayer;
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;
  bool _playing = false;
  late double _speed = playbackSpeedFor(pl.playback?.timeline.hours ?? 24);
  String? _stale;

  /// A dialog or a sheet is open over the drawing, or the drawing of this
  /// tab is not shown (another tab is): the panel (which lives in the
  /// overlay above the routes) steps aside and the play pauses.
  bool _covered = false;

  @override
  void initState() {
    super.initState();
    c.addListener(_onController);
    pl.addListener(_onPlayer);
    SchedulerBinding.instance.addPostFrameCallback(_watchRoutes);
  }

  /// After every frame: whether a route stands over the drawing (the check
  /// runs only when frames are drawn, as a route that opens draws them).
  void _watchRoutes(Duration _) {
    if (!mounted) return;
    final covered = (Navigator.maybeOf(context, rootNavigator: true)?.canPop() ?? false) || c.keyTarget == null;
    if (covered != _covered) {
      if (covered) _pause();
      setState(() => _covered = covered);
    }
    SchedulerBinding.instance.addPostFrameCallback(_watchRoutes);
  }

  @override
  void dispose() {
    _ticker.dispose();
    c.removeListener(_onController);
    pl.removeListener(_onPlayer);
    super.dispose();
  }

  void _onPlayer() {
    if (mounted) setState(() {});
  }

  /// The results the player last could not play (not tried again).
  Object? _failedFor;

  /// The design ran again: the player follows its results (or says it
  /// cannot while there are none, and plays again after the next design).
  void _onController() {
    final pb = pl.playback;
    final r = c.results;
    if (pb != null ? identical(pb.results, r) : (r == null || identical(_failedFor, r))) return;
    _pause();
    final (next, problem) = loadProgrammePlayback(c);
    if (next == null) {
      _failedFor = r;
      pl.clear();
      setState(() => _stale = problem == c.t('ply.needResults') ? c.t('ply.stale') : problem);
      return;
    }
    _failedFor = null;
    setState(() => _stale = null);
    pl.show(next, hour: pl.hour);
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt > 0) pl.hour = pl.hour + dt * _speed;
  }

  void _play() {
    if (_playing || pl.playback == null) return;
    _last = Duration.zero;
    _ticker.start();
    setState(() => _playing = true);
  }

  void _pause() {
    if (!_playing) return;
    _ticker.stop();
    if (mounted) setState(() => _playing = false);
  }

  void _next() {
    final h = pl.playback?.timeline.nextStart(pl.hour);
    if (h != null) pl.hour = h;
  }

  Future<void> _png() async {
    final pb = pl.playback;
    if (pb == null) return;
    _pause();
    final hour = pl.hour;
    try {
      final png = await playbackPng(c, pb, hour, baseMap: c.baseMap != BaseMap.none);
      await playbackFileSink(c, playbackFileName(c, 'png'), 'image/png', png);
    } catch (e, st) {
      debugPrint('$e\n$st');
      c.notify(c.t('msg.error', {'e': c.describeError(e)}));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_covered) return const Positioned(left: 0, bottom: 0, child: SizedBox.shrink());
    final pb = pl.playback;
    final phone = shellLayoutOf(context) == ShellLayout.phone;
    final pad = MediaQuery.paddingOf(context);
    final body = pb == null ? _staleBody() : _body(context, pb, phone);
    return Positioned(
      left: 8 + pad.left,
      right: 8 + pad.right,
      bottom: 8 + pad.bottom + (phone ? 0 : 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Material(
            key: const Key('ply_panel'),
            elevation: 8,
            color: Cad.panel,
            borderRadius: BorderRadius.circular(10),
            child: Padding(padding: const EdgeInsets.fromLTRB(8, 4, 4, 6), child: body),
          ),
        ),
      ),
    );
  }

  Widget _close() => IconButton(key: const Key('ply_close'), tooltip: c.t('close'), visualDensity: VisualDensity.compact, icon: const Icon(Icons.close, size: 18), onPressed: widget.onClose);

  Widget _staleBody() => Row(
    children: [
      Icon(Icons.info_outline, size: 18, color: Cad.caution),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          _stale ?? c.t('ply.stale'),
          key: const Key('ply_stale'),
          style: TextStyle(fontSize: 12, color: Cad.fg87),
        ),
      ),
      _close(),
    ],
  );

  Widget _body(BuildContext context, ProgrammePlayback pb, bool phone) {
    final t = c.t;
    final tl = pb.timeline;
    final f = pl.frame!;
    String speedText(double s) => '${fmtUi(s, s < 1 ? 2 : 0)} h/s';
    final names = {for (final s in f.running) s.run.cycles > 1 ? '${s.run.flowName} (${s.run.cycle}/${s.run.cycles})' : s.run.flowName}.join(' + ');
    final u = c.units;
    final status = f.idle ? t('ply.idle') : '$names · ${fmtUi(u.flowFromSi(f.totalFlow), 1)} ${u.flowLabel}';
    final buttons = <Widget>[
      IconButton(key: const Key('ply_restart'), tooltip: t('ply.restart'), visualDensity: VisualDensity.compact, icon: const Icon(Icons.skip_previous, size: 20), onPressed: () => pl.hour = 0),
      IconButton(
        key: const Key('ply_play'),
        tooltip: _playing ? t('ply.pause') : t('ply.play'),
        visualDensity: VisualDensity.compact,
        icon: Icon(_playing ? Icons.pause_circle_filled : Icons.play_circle_filled, size: 28, color: Cad.accentIcon),
        onPressed: _playing ? _pause : _play,
      ),
      IconButton(key: const Key('ply_next'), tooltip: t('ply.next'), visualDensity: VisualDensity.compact, icon: const Icon(Icons.skip_next, size: 20), onPressed: _next),
    ];
    final speed = Tooltip(
      message: t('ply.speed'),
      child: DropdownButton<double>(
        key: const Key('ply_speed'),
        value: _speed,
        isDense: true,
        underline: const SizedBox.shrink(),
        style: TextStyle(fontSize: 12, color: Cad.fg87),
        items: [for (final s in playbackSpeeds) DropdownMenuItem(value: s, child: Text(speedText(s)))],
        onChanged: (v) => setState(() => _speed = v ?? _speed),
      ),
    );
    final clock = Text(
      playbackClock(c, pb, pl.hour),
      key: const Key('ply_clock'),
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Cad.fg),
    );
    final running = Text(
      status,
      key: const Key('ply_running'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 12, color: f.idle ? Cad.fg60 : Cad.accentText),
    );
    void gif() {
      _pause();
      showProgrammeGifDialog(context, c);
    }

    void ics() {
      _pause();
      showProgrammeCalendarDialog(context, c);
    }

    // (on a phone the exports are icons beside the controls)
    final exports = phone
        ? <Widget>[
            IconButton(key: const Key('ply_png'), tooltip: t('ply.png'), visualDensity: VisualDensity.compact, icon: const Icon(Icons.image_outlined, size: 20), onPressed: _png),
            IconButton(key: const Key('ply_gif'), tooltip: t('ply.gif'), visualDensity: VisualDensity.compact, icon: const Icon(Icons.movie_outlined, size: 20), onPressed: gif),
            IconButton(key: const Key('ply_ics'), tooltip: t('ply.ics'), visualDensity: VisualDensity.compact, icon: const Icon(Icons.event_outlined, size: 20), onPressed: ics),
          ]
        : <Widget>[
            TextButton.icon(
              key: const Key('ply_png'),
              onPressed: _png,
              icon: const Icon(Icons.image_outlined, size: 16),
              label: Text(t('ply.png'), style: const TextStyle(fontSize: 12)),
            ),
            TextButton.icon(
              key: const Key('ply_gif'),
              onPressed: gif,
              icon: const Icon(Icons.movie_outlined, size: 16),
              label: Text(t('ply.gif'), style: const TextStyle(fontSize: 12)),
            ),
            TextButton.icon(
              key: const Key('ply_ics'),
              onPressed: ics,
              icon: const Icon(Icons.event_outlined, size: 16),
              label: Text(t('ply.ics'), style: const TextStyle(fontSize: 12)),
            ),
          ];
    final cycle = tl.days <= 1
        ? t('ply.cycleDay')
        : tl.exact
        ? t('ply.cycleDays', {'n': '${tl.days}'})
        : t('ply.cycleCut', {'p': '${tl.periodDays}', 'n': '${tl.days}'});
    final notes = <String>[
      for (final r in pb.reservoirs)
        if (r.dry || r.spills) '${t('res.level')} ${c.project.byId(r.supplyId)?.name ?? ''}: ${[if (r.dry) t('ply.dry'), if (r.spills) t('ply.spills')].join(', ')}',
      if (tl.overlaps) t('ply.overlap'),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (phone) ...[
          Row(children: [...buttons, const Spacer(), ...exports, _close()]),
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Row(
              children: [
                clock,
                const SizedBox(width: 10),
                Expanded(child: running),
                speed,
              ],
            ),
          ),
        ] else
          Row(
            children: [
              ...buttons,
              speed,
              const SizedBox(width: 8),
              clock,
              const SizedBox(width: 10),
              Expanded(child: running),
              _close(),
            ],
          ),
        SizedBox(
          height: 34,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(left: 24, right: 24, top: 2, height: 6, child: CustomPaint(painter: _SpansPainter(tl, Cad.accent, Cad.fg24, Cad.fg54))),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(trackHeight: 2, overlayShape: const RoundSliderOverlayShape(overlayRadius: 12)),
                child: Slider(key: const Key('ply_slider'), min: 0, max: tl.hours, value: pl.hour.clamp(0, tl.hours).toDouble(), onChanged: (v) => pl.hour = v),
              ),
            ],
          ),
        ),
        if (!phone)
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  cycle,
                  key: const Key('ply_cycle'),
                  style: TextStyle(fontSize: 11, color: Cad.fg60),
                ),
              ),
              ...exports,
            ],
          ),
        for (final n in notes)
          Padding(
            padding: const EdgeInsets.only(left: 6, top: 2),
            child: Text(n, style: TextStyle(fontSize: 11, color: Cad.caution)),
          ),
      ],
    );
  }
}

/// The runs of the cycle as blocks over the slider, with the day breaks.
class _SpansPainter extends CustomPainter {
  _SpansPainter(this.tl, this.run, this.track, this.day);
  final ProgrammeTimeline tl;
  final Color run, track, day;

  @override
  void paint(Canvas canvas, Size size) {
    double x(double h) => size.width * h / tl.hours;
    canvas.drawRect(Offset.zero & size, Paint()..color = track);
    final p = Paint()..color = run;
    for (final s in tl.spans) {
      canvas.drawRect(Rect.fromLTRB(x(s.start), 0, (x(s.end)).clamp(x(s.start) + 1, size.width).toDouble(), size.height), p);
    }
    final d = Paint()..color = day;
    for (var k = 1; k < tl.days; k++) {
      canvas.drawLine(Offset(x(k * 24.0), -2), Offset(x(k * 24.0), size.height + 2), d);
    }
  }

  @override
  bool shouldRepaint(_SpansPainter old) => !identical(old.tl, tl) || old.run != run || old.track != track;
}

// ---------------------------------------------------------------- GIF

/// The player → Animation (GIF): the size and frames, then the cycle drawn
/// frame by frame with its progress and Cancel.
Future<void> showProgrammeGifDialog(BuildContext context, ProjectController c) {
  final pb = c.programmePlayer.playback;
  if (pb == null) return Future.value();
  var side = playbackGifSide;
  var frames = playbackDefaultFrames(pb.timeline.days);
  final canMap = c.baseMap != BaseMap.none && c.project.meta.georef != null;
  var withMap = canMap;
  var busy = false;
  var cancelled = false;
  var done = 0, total = 0;
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final t = c.t;
        Future<void> run() async {
          FocusManager.instance.primaryFocus?.unfocus();
          setState(() {
            busy = true;
            cancelled = false;
            done = 0;
            total = playbackFrameTimes(pb.timeline, frames).length;
          });
          try {
            final gif = await playbackGif(
              c,
              pb,
              maxSide: side,
              frames: frames,
              baseMap: withMap,
              onProgress: (k, n) {
                if (ctx.mounted) setState(() => (done, total) = (k, n));
              },
              cancelled: () => cancelled,
            );
            if (gif == null) {
              c.notify(t('ply.gif.cancelled'));
            } else {
              final file = playbackFileName(c, 'gif');
              await playbackFileSink(c, file, 'image/gif', gif.bytes);
              c.notify(t('ply.gif.done', {'f': file, 'kb': '${(gif.bytes.length / 1024).round()}', 'n': '${gif.frames}'}));
            }
          } catch (e, st) {
            debugPrint('$e\n$st');
            c.notify(t('msg.error', {'e': c.describeError(e)}));
          }
          if (ctx.mounted) Navigator.pop(ctx);
        }

        return AlertDialog(
          title: Text(t('ply.gif.title'), style: const TextStyle(fontSize: 15)),
          content: SizedBox(
            width: dialogWidth(ctx, 440),
            child: ScrollBody(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(t('ply.gif.hint'), style: TextStyle(fontSize: 11.5, color: Cad.fg60)),
                  const SizedBox(height: 8),
                  SpecDropdown<int>(
                    key: const Key('ply_gif_size'),
                    label: t('ply.gif.size'),
                    value: '$side',
                    items: playbackGifSides,
                    labelOf: (s) => '$s px',
                    idOf: (s) => '$s',
                    onChanged: (v) {
                      if (!busy) setState(() => side = int.tryParse(v ?? '') ?? side);
                    },
                  ),
                  NumField(key: const Key('ply_gif_frames'), label: t('ply.gif.frames'), value: frames.toDouble(), decimals: 0, enabled: !busy, onChanged: (v) => frames = v.round().clamp(2, 240)),
                  if (canMap)
                    SwitchListTile(
                      key: const Key('ply_gif_map'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(t('ply.gif.map'), style: const TextStyle(fontSize: 12)),
                      value: withMap,
                      onChanged: busy ? null : (v) => setState(() => withMap = v),
                    ),
                  if (busy) ...[
                    const SizedBox(height: 10),
                    LinearProgressIndicator(key: const Key('ply_gif_progress'), value: total == 0 ? null : done / total),
                    const SizedBox(height: 4),
                    Text(t('ply.gif.progress', {'n': '$done', 'of': '$total'}), style: TextStyle(fontSize: 11, color: Cad.fg60)),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              key: const Key('ply_gif_cancel'),
              onPressed: () {
                if (busy) {
                  cancelled = true;
                } else {
                  Navigator.pop(ctx);
                }
              },
              child: Text(t('cancel')),
            ),
            FilledButton(key: const Key('ply_gif_export'), onPressed: busy ? null : run, child: Text(t('plot.export'))),
          ],
        );
      },
    ),
  );
}

// ---------------------------------------------------------------- calendar

/// The player → Calendar (.ics): the days it repeats for and the month of
/// the run times, then the file.
Future<void> showProgrammeCalendarDialog(BuildContext context, ProjectController c) {
  var days = 30;
  var month = 0;
  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final t = c.t;
        Future<void> export() async {
          FocusManager.instance.primaryFocus?.unfocus();
          final (pb, problem) = loadProgrammePlayback(c, month: month == 0 ? null : month, withReservoirs: false);
          if (pb == null) {
            c.notify(problem ?? '');
            return;
          }
          final text = programmeCalendar(pb.timeline, projectName: c.project.meta.name.isEmpty ? t('ply.title') : c.project.meta.name, stamp: DateTime.now(), horizonDays: days, t: t.call);
          final file = playbackFileName(c, 'ics');
          await playbackFileSink(c, file, 'text/calendar', text);
          c.notify(t('ply.ics.done', {'f': file, 'n': '${'BEGIN:VEVENT'.allMatches(text).length}'}));
          if (ctx.mounted) Navigator.pop(ctx);
        }

        return AlertDialog(
          title: Text(t('ply.ics.title'), style: const TextStyle(fontSize: 15)),
          content: SizedBox(
            width: dialogWidth(ctx, 440),
            child: ScrollBody(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(t('ply.ics.hint'), style: TextStyle(fontSize: 11.5, color: Cad.fg60)),
                  const SizedBox(height: 8),
                  NumField(key: const Key('ply_ics_days'), label: t('ply.ics.days'), value: days.toDouble(), decimals: 0, onChanged: (v) => days = v.round().clamp(1, 366)),
                  SpecDropdown<int>(
                    key: const Key('ply_ics_month'),
                    label: t('mgmt.month'),
                    value: '$month',
                    items: [for (var m = 0; m <= 12; m++) m],
                    labelOf: (m) => m == 0 ? t('mgmt.monthDesign') : t('mon.$m'),
                    idOf: (m) => '$m',
                    onChanged: (v) => setState(() => month = int.tryParse(v ?? '') ?? 0),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(key: const Key('ply_ics_cancel'), onPressed: () => Navigator.pop(ctx), child: Text(t('cancel'))),
            FilledButton(key: const Key('ply_ics_export'), onPressed: export, child: Text(t('plot.export'))),
          ],
        );
      },
    ),
  );
}
