/// Design → Agronomy → Climate risk over the years (1.7.0 CLR): the daily
/// weather series of the site (NASA POWER, downloaded on request and kept on
/// the device, or the series of the site climate), the daily water balance
/// of every area season by season with and without the capacity of the
/// designed system, and the result: the spread of the yearly requirement
/// and of the peak-period demand beside the figures the design uses, the
/// reliability, the worst years and dry spells, the trend, a chart per year
/// and an exceedance curve (lib/core/design/climate_risk.dart has the
/// method). The summary is kept in the project (one undo step); the report
/// tables show it.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/climate_risk.dart';
import '../../../core/design/climate_risk_stats.dart';
import '../../../core/io/climate_online.dart';
import '../../../core/model/entities.dart';
import '../../io/data_cache_store.dart';
import '../../state/controller.dart';
import '../../theme.dart';
import '../fields.dart';
import '../reports_panel.dart' show ReportTableView;
import 'terrain_dialogs.dart' show dialogWidth;

// ---------------------------------------------------------------- the run

/// The sources of the daily series: the NASA POWER download, or the series
/// kept with the site climate.
const climateRiskSources = ['nasaPower', 'site'];

/// Today, for the last complete year of the download and the date of the
/// summary (tests fix it).
DateTime Function() climateRiskClock = DateTime.now;

/// The daily NASA POWER series of the site from [climateRiskFirstYear] to
/// the last complete year, through the app's climate download (the same
/// host, pacing, retries and errors as Design → Site climate) and its data
/// cache: a series kept on the device is read from there, with no pacing,
/// so a second run is instant and works offline. The site is rounded to
/// 0.01° (about 1 km, the reanalysis cell being about 50 km) so the kept
/// series still serves the project after the drawing changes. Throws
/// [ClimateException] (`climate_no_site` without a georeference).
Future<ClimateSeries> downloadClimateRiskSeries(ProjectController c, {DateTime? today, void Function(int done, int total)? onProgress, bool Function()? cancelled}) async {
  final ll = c.siteLatLon;
  if (ll == null) throw const ClimateException('climate_no_site', '');
  final now = (today ?? climateRiskClock()).toUtc();
  final lat = (ll.$1 * 100).round() / 100, lon = (ll.$2 * 100).round() / 100;
  const src = ClimateSource.nasaPower;
  final last = now.year - 1;
  final cache = appDataCache();
  // every part already on the device: nothing goes to the network, so no pause between parts
  var kept = cache.enabled;
  for (final (s, e) in climateRequestPeriods(src, climateRiskFirstYear, last, today: now)) {
    if (!kept) break;
    try {
      kept = await cache.store.get('climate:${climateRequestUrl(src, lat, lon, s, e)}') != null;
    } on Object {
      kept = false;
    }
  }
  return climateDownload(
    src,
    latitudeDeg: lat,
    longitudeDeg: lon,
    firstYear: climateRiskFirstYear,
    lastYear: last,
    fetch: cache.text(ProjectController.climateUrlLoader, 'climate'),
    today: now,
    onProgress: onProgress,
    cancelled: cancelled,
    callsPerMinute: kept ? 0 : null,
    minInterval: kept ? Duration.zero : null,
  );
}

/// The areas the analysis can run (closed, with a water balance).
List<AreaEntity> climateRiskAreas(ProjectController c) => [
  for (final a in c.project.entities.whereType<AreaEntity>())
    if (a.points.length >= 3 && a.useWaterBalance) a,
];

/// Runs the climate risk of the project of [c] with the daily series of
/// [source] (`nasaPower`: downloaded or read from the device; `site`: the
/// series of the site climate) and, with [keep], stores its summary in the
/// project (one undo step, the design results kept). Throws
/// [ClimateException]: `clr_no_areas` (nothing to analyse, nothing is
/// downloaded), `clr_no_series` (no daily series in the site climate),
/// `clr_busy` (a design is running), or a download's error.
Future<ClimateRiskSummary> runClimateRisk(
  ProjectController c, {
  String source = 'nasaPower',
  double probability = 0.8,
  int peakDays = 30,
  bool keep = true,
  DateTime? today,
  void Function(int done, int total)? onProgress,
  bool Function()? cancelled,
}) async {
  final now = today ?? climateRiskClock();
  if (climateRiskAreas(c).isEmpty) throw const ClimateException('clr_no_areas');
  if (keep && c.busy) throw const ClimateException('clr_busy');
  final RiskSeries series;
  if (source == 'site') {
    final sc = c.project.climate;
    final d = sc?.daily;
    if (sc == null || d == null || d.completeYears.isEmpty) throw const ClimateException('clr_no_series');
    series = RiskSeries.ofDaily(d, attribution: sc.attribution, latitudeDeg: sc.latitudeDeg, longitudeDeg: sc.longitudeDeg);
  } else {
    final s = await downloadClimateRiskSeries(c, today: now, onProgress: onProgress, cancelled: cancelled);
    series = RiskSeries.ofClimateSeries(s, attribution: ClimateSource.nasaPower.attribution);
  }
  if (cancelled?.call() ?? false) throw const ClimateException('climate_cancelled');
  // the project as it is now (an undo during the download replaces it)
  final summary = climateRiskAnalysis(c.project, series, results: c.results, probability: probability, peakDays: peakDays, today: now);
  if (keep) {
    final done = c.mutate(
      () {
        c.project.climateRisk = summary;
        return true;
      },
      invalidateResults: false,
      label: 'hist.clr',
    );
    if (done != true) throw const ClimateException('clr_busy');
  }
  return summary;
}

/// The message of an error of [runClimateRisk] in the user's language.
String climateRiskError(ProjectController c, Object e) => e is ClimateException && e.code.startsWith('clr_') ? c.t('clr.err.${e.code}') : c.describeError(e);

// ---------------------------------------------------------------- the dialog

Widget _hint(String s) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Text(s, style: TextStyle(fontSize: 11.5, color: Cad.fg70)),
);

Widget _line(String label, String value, {Color? color}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 2),
  child: Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: '$label: ',
          style: TextStyle(color: Cad.fg60),
        ),
        TextSpan(
          text: localizeUi(value),
          style: TextStyle(color: color ?? Cad.fg),
        ),
      ],
    ),
    style: const TextStyle(fontSize: 11.5),
  ),
);

Widget _legend(Color color, String label) => Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    Container(width: 10, height: 10, color: color),
    const SizedBox(width: 4),
    // a long label wraps on a phone
    Flexible(child: Text(label, style: const TextStyle(fontSize: 11))),
  ],
);

/// The climate risk over the years (see the library notes).
Future<void> showClimateRiskDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final p = c.project;
  var summary = p.climateRisk;
  final daily = p.climate?.daily;
  final siteYears = daily?.completeYears ?? const <int>[];
  var source = siteYears.isNotEmpty && c.siteLatLon == null ? 'site' : 'nasaPower';
  var probability = summary?.probability ?? 0.8;
  var peakDays = summary?.peakDays ?? 30;
  if (!climateRiskPeakDays.contains(peakDays)) peakDays = 30;
  if (!climateRiskLevels.contains(probability)) probability = 0.8;
  var busy = false;
  var cancel = false;
  var done = 0, total = 0;
  String? error;
  var view = '';
  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final areas = climateRiskAreas(c);
        final site = c.siteLatLon;
        final lastYear = climateRiskClock().year - 1;
        Future<void> run() async {
          FocusManager.instance.primaryFocus?.unfocus();
          setState(() {
            busy = true;
            cancel = false;
            error = null;
            done = 0;
            total = 0;
          });
          try {
            summary = await runClimateRisk(
              c,
              source: source,
              probability: probability,
              peakDays: peakDays,
              onProgress: (d, n) {
                if (ctx.mounted) {
                  setState(() {
                    done = d;
                    total = n;
                  });
                }
              },
              cancelled: () => cancel,
            );
            if (summary!.areas.every((a) => a.areaId != view)) view = '';
            c.notify(t('clr.saved'));
          } catch (e) {
            error = climateRiskError(c, e);
          }
          if (ctx.mounted) setState(() => busy = false);
        }

        final canRun = !busy && !c.busy && areas.isNotEmpty && (source == 'site' ? siteYears.isNotEmpty : site != null);
        final body = <Widget>[
          _hint(t('clr.hint')),
          if (areas.isEmpty)
            Text(
              t('clr.noAreas'),
              key: const Key('clr_no_areas'),
              style: TextStyle(fontSize: 12, color: Cad.caution),
            ),
          SpecDropdown<String>(
            key: const Key('clr_source'),
            label: t('clr.source'),
            value: source,
            items: ['nasaPower', if (siteYears.isNotEmpty) 'site'],
            labelOf: (s) => s == 'site'
                ? t('clr.src.site', {'s': daily!.source.isEmpty ? '-' : daily.source, 'a': '${siteYears.first}', 'b': '${siteYears.last}'})
                : t('clr.src.nasaPower', {'a': '$climateRiskFirstYear', 'b': '$lastYear'}),
            idOf: (s) => s,
            onChanged: (v) => setState(() => source = v ?? 'nasaPower'),
          ),
          if (source == 'nasaPower' && site == null) Text(t('msg.climate_no_site'), style: TextStyle(fontSize: 12, color: Cad.warning)),
          if (source == 'nasaPower') Text(t('clim.terms.nasaPower'), style: TextStyle(fontSize: 10.5, color: Cad.fg54)),
          Row(
            children: [
              Expanded(
                child: SpecDropdown<double>(
                  key: const Key('clr_probability'),
                  label: t('clr.probability'),
                  value: '$probability',
                  items: climateRiskLevels,
                  labelOf: (x) => '${(x * 100).round()} %',
                  idOf: (x) => '$x',
                  onChanged: (v) => setState(() => probability = double.tryParse(v ?? '') ?? 0.8),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SpecDropdown<int>(
                  key: const Key('clr_peak_days'),
                  label: t('clr.peakDays'),
                  value: '$peakDays',
                  items: climateRiskPeakDays,
                  labelOf: (x) => '$x',
                  idOf: (x) => '$x',
                  onChanged: (v) => setState(() => peakDays = int.tryParse(v ?? '') ?? 30),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                key: const Key('clr_run'),
                onPressed: canRun ? run : null,
                icon: Icon(source == 'nasaPower' ? Icons.cloud_download_outlined : Icons.play_arrow, size: 16),
                label: Text(t('clr.run')),
              ),
              if (busy) ...[
                SizedBox(width: 120, child: LinearProgressIndicator(value: total > 0 ? done / total : null)),
                if (total > 0) Text(t('clr.progress', {'d': '$done', 'n': '$total'}), style: TextStyle(fontSize: 11, color: Cad.fg60)),
                TextButton(key: const Key('clr_cancel'), onPressed: () => cancel = true, child: Text(t('cancel'))),
              ],
            ],
          ),
          if (error != null)
            Text(
              error!,
              key: const Key('clr_error'),
              style: TextStyle(fontSize: 12, color: Cad.warning),
            ),
          if (summary != null) ..._results(ctx, c, summary!, view, probability, (v) => setState(() => view = v)),
        ];
        return AlertDialog(
          title: Text(t('clr.title'), style: const TextStyle(fontSize: 15)),
          content: SizedBox(
            width: dialogWidth(ctx, 720),
            child: ScrollBody(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: body),
            ),
          ),
          actions: [
            TextButton(
              key: const Key('clr_close'),
              onPressed: () {
                cancel = true;
                Navigator.pop(ctx);
              },
              child: Text(t('close')),
            ),
          ],
        );
      },
    ),
  );
}

/// "P50 1.2 · P80 1.5 · P90 1.7 · P95 1.8 · max 2.0 mm/d".
String _spread(ProjectController c, List<double> xs, double Function(double) conv, int dec, String unit) {
  if (xs.isEmpty) return '-';
  final parts = [for (final f in climateRiskLevels) 'P${(f * 100).round()} ${fmtUi(conv(quantileAt(xs, f)!), dec)}', '${c.t('clr.col.max')} ${fmtUi(conv(xs.reduce(math.max)), dec)}'];
  return '${parts.join(' · ')} $unit';
}

String _trend(ProjectController c, List<int> years, List<double> xs, double Function(double) conv, int dec, String unit) {
  final tr = senMannKendall(years, xs);
  if (tr == null) return '-';
  final v = conv(tr.slopePerDecade);
  return c.t('clr.trend', {'v': '${v >= 0 ? '+' : ''}${fmtUi(v, dec)} $unit', 's': c.t(tr.significant ? 'clr.trend.sig' : 'clr.trend.ns')});
}

String _warning(ProjectController c, String code, ClimateRiskSummary s) {
  final i = code.indexOf(':');
  final key = i < 0 ? code : code.substring(0, i);
  final id = i < 0 ? '' : code.substring(i + 1);
  final name = s.areas.where((a) => a.areaId == id).firstOrNull?.name ?? c.entityName(id);
  return c.t('clr.w.$key', {'n': name});
}

/// The kept result: the line of its source, the chosen view (the project or
/// one area), its figures, the chart per year, the exceedance curve, the
/// report tables, the warnings and the notes on the data and the method. The
/// design values are read at the [probability] chosen now (the years are
/// kept, so no new run is needed for it).
List<Widget> _results(BuildContext ctx, ProjectController c, ClimateRiskSummary s, String view, double probability, ValueChanged<String> onView) {
  final t = c.t;
  final p = c.project;
  final u = p.params.units;
  final dl = u.depthLabel, dd = u.depthPerDayLabel, vl = u.volumeLabel;
  final area = s.areas.where((a) => a.areaId == view).firstOrNull;
  final pct = '${(probability * 100).round()}';
  final etoLabel = t('clr.q.eto', {'n': '${s.peakDays}'});
  final peakLabel = t('clr.q.peak', {'n': '${s.peakDays}'});
  final out = <Widget>[
    const Divider(height: 18),
    Text(
      t('clr.stored', {'d': s.computed, 's': s.source == 'nasaPower' ? 'NASA POWER' : s.source, 'a': '${s.firstYear}', 'b': '${s.lastYear}'}),
      key: const Key('clr_stored'),
      style: const TextStyle(fontSize: 12),
    ),
    if (s.attribution.isNotEmpty) Text(s.attribution, style: TextStyle(fontSize: 10.5, color: Cad.fg54)),
    SpecDropdown<String>(
      key: const Key('clr_view'),
      label: t('clr.view'),
      value: area?.areaId ?? '',
      items: ['', for (final a in s.areas) a.areaId],
      labelOf: (id) => id.isEmpty ? t('clr.project') : s.areas.firstWhere((a) => a.areaId == id).name,
      idOf: (id) => id,
      onChanged: (v) => onView(v ?? ''),
    ),
  ];
  // the figures, the bars per year and the exceedance curve of the view
  final List<String> labels;
  final List<double> bars;
  final List<bool> flagged;
  final double? barRef;
  final List<double> curve;
  final List<(double, Color)> curveRefs;
  final String barUnit, curveUnit;
  double Function(double) barConv;
  if (area == null) {
    final years = [for (final y in s.site) y.year];
    final peak = [for (final y in s.site) y.peakEtoMmDay];
    final full = s.project.where((y) => y.complete).toList();
    final volume = [for (final y in full) y.requirementM3];
    final designM3 = s.areas.fold(0.0, (a, x) => a + x.designYearGrossMm / 1000 * x.areaM2);
    final ok = full.where((y) => y.deficitDays == 0).length;
    final worstDry = [...s.site]..sort((a, b) => b.drySpellDays.compareTo(a.drySpellDays));
    final worstVol = [...full]..sort((a, b) => b.requirementM3.compareTo(a.requirementM3));
    final atP = quantileAt(peak, probability);
    out.addAll([
      _line(t('swb.period'), '${s.firstYear}–${s.lastYear} (${s.site.length})'),
      _line(etoLabel, _spread(c, peak, u.depthFromMm, 2, dd)),
      if (atP != null)
        _line(
          t('clr.col.project'),
          t('clr.designEto', {'p': pct, 'v': '${fmtUi(u.depthFromMm(atP), 2)} $dd', 'w': s.projectEtoMmDay == null ? '-' : '${fmtUi(u.depthFromMm(s.projectEtoMmDay!), 2)} $dd'}),
          color: s.projectEtoMmDay != null && atP > s.projectEtoMmDay! ? Cad.caution : null,
        ),
      _line('ETo ($dl)', _spread(c, [for (final y in s.site) y.etoMm], u.depthFromMm, 0, dl)),
      _line(t('req.rain'), _spread(c, [for (final y in s.site) y.rainMm], u.depthFromMm, 0, dl)),
      _line('${t('req.rain')} · ${t('clr.trend.title')}', _trend(c, years, [for (final y in s.site) y.rainMm], u.depthFromMm, 0, dl)),
      if (worstDry.isNotEmpty)
        _line(
          t('clr.q.dry'),
          [
            for (final y in worstDry.take(3))
              if (y.drySpellStart != null) t('clr.drySpell', {'n': '${y.drySpellDays}', 'd': y.drySpellStart!.toIso8601String().substring(0, 10)}),
          ].join(' · '),
        ),
      if (volume.isNotEmpty) ...[
        _line(t('clr.q.volume'), _spread(c, volume, u.volumeFromM3, 0, vl)),
        if (designM3 > 0) _line(t('clr.col.project'), '${fmtUi(u.volumeFromM3(designM3), 0)} $vl · ${t('clr.exceeded', {'k': '${countAbove(volume, designM3)}', 'n': '${volume.length}'})}'),
        _line(t('clr.q.pumped'), _spread(c, [for (final y in full) y.pumpedM3], u.volumeFromM3, 0, vl)),
        _line(t('clr.trend.title'), _trend(c, [for (final y in full) y.year], volume, u.volumeFromM3, 0, vl)),
        _line(t('clr.q.deficit'), t('clr.reliability', {'k': '$ok', 'n': '${full.length}', 'p': fmtUi(100 * ok / full.length, 0)}), color: ok < full.length ? Cad.caution : Cad.ok),
        _line(
          t('clr.worst'),
          [for (final y in worstVol.take(3)) '${ClimateRiskSummary.yearLabel(y.year, crosses: s.areas.any((a) => a.crossesYear))} (${fmtUi(u.volumeFromM3(y.requirementM3), 0)} $vl)'].join(' · '),
        ),
      ],
    ]);
    labels = [for (final y in full) ClimateRiskSummary.yearLabel(y.year)];
    bars = volume;
    flagged = [for (final y in full) y.deficitDays > 0];
    barRef = designM3 > 0 ? designM3 : null;
    barConv = u.volumeFromM3;
    barUnit = vl;
    curve = peak;
    curveRefs = [if (s.projectEtoMmDay != null) (s.projectEtoMmDay!, Cad.info)];
    curveUnit = '$etoLabel ($dd)';
  } else {
    final a = area;
    final cap = a.capacityGrossMmDay;
    final atP = quantileAt(a.peakGrossMmDay, probability);
    out.addAll([
      _line(t('clr.season'), '${a.startDay} ${t('mon.${a.startMonth}')} · ${a.seasonDays} d${a.crossesYear ? ' (${t('clr.crosses')})' : ''}'),
      _line(t('clr.capacityTitle'), cap == null ? t('clr.capacityUnknown') : '${fmtUi(u.depthFromMm(cap), 2)} $dd (${fmtUi(s.windowHours, 1)} h/d)', color: cap == null ? Cad.caution : null),
      _line(t('clr.q.gross'), _spread(c, a.grossMm, u.depthFromMm, 0, dl)),
      _line(t('clr.col.project'), '${fmtUi(u.depthFromMm(a.designYearGrossMm), 0)} $dl · ${t('clr.exceeded', {'k': '${countAbove(a.grossMm, a.designYearGrossMm)}', 'n': '${a.seasons.length}'})}'),
      _line(peakLabel, _spread(c, a.peakGrossMmDay, u.depthFromMm, 2, dd)),
      if (atP != null)
        _line(
          t('clr.col.project'),
          t('clr.designPeak', {
            'p': pct,
            'v': '${fmtUi(u.depthFromMm(atP), 2)} $dd',
            'w': '${fmtUi(u.depthFromMm(a.designPeakGrossMmDay), 2)} $dd',
            'c': cap == null ? '-' : '${fmtUi(u.depthFromMm(cap), 2)} $dd',
          }),
          color: cap != null && atP > cap ? Cad.caution : null,
        ),
      _line(etoLabel, _spread(c, a.peakEtoMmDay, u.depthFromMm, 2, dd)),
      _line(t('clr.q.pumped'), _spread(c, a.pumpedM3, u.volumeFromM3, 0, vl)),
      _line(t('clr.trend.title'), _trend(c, a.years, a.grossMm, u.depthFromMm, 0, dl)),
      if (a.seasons.isNotEmpty)
        _line(
          t('clr.q.deficit'),
          t('clr.reliability', {'k': '${a.reliableSeasons}', 'n': '${a.seasons.length}', 'p': fmtUi(100 * a.reliability!, 0)}),
          color: a.reliableSeasons < a.seasons.length ? Cad.caution : Cad.ok,
        ),
      if (a.seasons.isNotEmpty)
        _line(
          t('clr.worst'),
          [for (final w in a.worst()) '${ClimateRiskSummary.yearLabel(w.year, crosses: a.crossesYear)} (${fmtUi(u.depthFromMm(w.grossMm), 0)} $dl, ${w.deficitDays} d)'].join(' · '),
        ),
      for (final w in a.warnings) Text(_warning(c, w, s), style: TextStyle(fontSize: 11, color: Cad.caution)),
    ]);
    labels = [for (final x in a.seasons) ClimateRiskSummary.yearLabel(x.year)];
    bars = a.grossMm;
    flagged = [for (final x in a.seasons) x.deficitDays > 0];
    barRef = a.designYearGrossMm > 0 ? a.designYearGrossMm : null;
    barConv = u.depthFromMm;
    barUnit = dl;
    curve = a.peakGrossMmDay;
    curveRefs = [if (a.designPeakGrossMmDay > 0) (a.designPeakGrossMmDay, Cad.info), if (cap != null) (cap, Cad.error)];
    curveUnit = '$peakLabel ($dd)';
  }
  if (bars.isNotEmpty) {
    out.addAll([
      SectionTitle(t('clr.chart.years')),
      SizedBox(
        height: 170,
        child: CustomPaint(
          key: const Key('clr_chart_years'),
          painter: YearBarsPainter(
            labels: labels,
            values: [for (final v in bars) barConv(v)],
            flagged: flagged,
            reference: barRef == null ? null : barConv(barRef),
            bar: Cad.accent,
            flag: Cad.caution,
            line: Cad.info,
            grid: Cad.chartGrid,
            text: Cad.fg60,
            unit: barUnit,
          ),
          child: const SizedBox.expand(),
        ),
      ),
      Wrap(spacing: 10, children: [_legend(Cad.accent, t('clr.leg.year')), _legend(Cad.caution, t('clr.leg.deficit')), _legend(Cad.info, t('clr.col.project'))]),
    ]);
  }
  if (curve.isNotEmpty) {
    out.addAll([
      SectionTitle(t('clr.chart.curve')),
      SizedBox(
        height: 170,
        child: CustomPaint(
          key: const Key('clr_chart_curve'),
          painter: ExceedanceCurvePainter(
            points: [for (final (f, v) in exceedanceCurve(curve)) (f, u.depthFromMm(v))],
            references: [for (final (v, col) in curveRefs) (u.depthFromMm(v), col)],
            probability: probability,
            line: Cad.accent,
            grid: Cad.chartGrid,
            text: Cad.fg60,
            unit: curveUnit,
          ),
          child: const SizedBox.expand(),
        ),
      ),
      Wrap(spacing: 10, children: [_legend(Cad.accent, curveUnit), _legend(Cad.info, t('clr.col.project')), if (area?.capacityGrossMmDay != null) _legend(Cad.error, t('clr.capacityTitle'))]),
    ]);
  }
  for (final tb in climateRiskTables(p, c.exporter().labels)) {
    out.addAll([
      SectionTitle(tb.title),
      SizedBox(
        height: 220,
        child: ReportTableView(
          headers: tb.headers,
          rows: tb.rows,
          rowIds: tb.ids,
          rowColors: [for (final w in tb.warn) w ? Cad.tintWarning : null],
          onLocate: (id) {
            if (p.byId(id) == null) return;
            c.select([id]);
            c.zoomToEntity(id);
          },
          title: tb.key,
          tools: true,
        ),
      ),
    ]);
  }
  for (final w in s.warnings) {
    out.add(Text(_warning(c, w, s), style: TextStyle(fontSize: 11, color: Cad.caution)));
  }
  out.addAll([
    const SizedBox(height: 6),
    Text(
      t('clr.reanalysis'),
      key: const Key('clr_reanalysis'),
      style: TextStyle(fontSize: 11, color: Cad.fg70),
    ),
    Text(t('clr.method'), style: TextStyle(fontSize: 10.5, color: Cad.fg54)),
  ]);
  return out;
}

// ---------------------------------------------------------------- charts

void _text(Canvas canvas, String s, Offset at, Color color, {double size = 9, bool right = false}) {
  final tp = TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(fontSize: size, color: color),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, right ? at - Offset(tp.width, tp.height / 2) : at);
}

/// Bars of one value a year (flagged years in another colour) and the
/// figure of the design as a line across.
class YearBarsPainter extends CustomPainter {
  YearBarsPainter({
    required this.labels,
    required this.values,
    required this.flagged,
    this.reference,
    required this.bar,
    required this.flag,
    required this.line,
    required this.grid,
    required this.text,
    required this.unit,
  });
  final List<String> labels;
  final List<double> values;
  final List<bool> flagged;
  final double? reference;
  final Color bar, flag, line, grid, text;
  final String unit;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || size.width < 60 || size.height < 40) return;
    const left = 44.0, bottom = 16.0, top = 12.0;
    final w = size.width - left - 4, h = size.height - top - bottom;
    final top0 = math.max(values.reduce(math.max), reference ?? 0) * 1.08;
    final scale = top0 > 0 ? top0 : 1.0;
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var k = 0; k <= 4; k++) {
      final y = top + h * (1 - k / 4);
      canvas.drawLine(Offset(left, y), Offset(left + w, y), gridPaint);
      _text(canvas, fmtUi(scale * k / 4, scale >= 100 ? 0 : 1), Offset(left - 3, y), text, right: true);
    }
    _text(canvas, unit, const Offset(2, 0), text);
    final n = values.length;
    final slot = w / n;
    final bw = math.max(1.0, slot * 0.75);
    for (var i = 0; i < n; i++) {
      final v = math.max(values[i], 0.0);
      final bh = h * v / scale;
      canvas.drawRect(Rect.fromLTWH(left + slot * i + (slot - bw) / 2, top + h - bh, bw, bh), Paint()..color = i < flagged.length && flagged[i] ? flag : bar);
    }
    if (reference != null && reference! > 0) {
      final y = top + h * (1 - reference! / scale);
      final pen = Paint()
        ..color = line
        ..strokeWidth = 1.6;
      // dashed
      for (var x = left; x < left + w; x += 8) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 5, left + w), y), pen);
      }
    }
    // a year label every few bars
    final every = math.max(1, (n / math.max(1, w ~/ 44)).ceil());
    for (var i = 0; i < n; i += every) {
      _text(canvas, labels[i].length > 4 ? labels[i].substring(0, 4) : labels[i], Offset(left + slot * i, top + h + 2), text);
    }
  }

  @override
  bool shouldRepaint(covariant YearBarsPainter old) => old.values != values || old.reference != reference || old.bar != bar || old.text != text;
}

/// The exceedance curve: the sorted values against their non-exceedance
/// probability (Weibull positions), the figures of the design as lines and
/// the chosen probability as a vertical line.
class ExceedanceCurvePainter extends CustomPainter {
  ExceedanceCurvePainter({required this.points, required this.references, required this.probability, required this.line, required this.grid, required this.text, required this.unit});
  final List<(double, double)> points;
  final List<(double, Color)> references;
  final double probability;
  final Color line, grid, text;
  final String unit;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || size.width < 60 || size.height < 40) return;
    const left = 44.0, bottom = 16.0, top = 12.0;
    final w = size.width - left - 8, h = size.height - top - bottom;
    final ys = [for (final p in points) p.$2, for (final r in references) r.$1];
    var lo = ys.reduce(math.min), hi = ys.reduce(math.max);
    if (hi - lo < 1e-9) {
      lo -= 1;
      hi += 1;
    }
    final pad = (hi - lo) * 0.08;
    lo = math.max(0, lo - pad);
    hi += pad;
    double x(double f) => left + w * f.clamp(0.0, 1.0);
    double y(double v) => top + h * (1 - (v - lo) / (hi - lo));
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var k = 0; k <= 4; k++) {
      final yy = top + h * k / 4;
      canvas.drawLine(Offset(left, yy), Offset(left + w, yy), gridPaint);
      _text(canvas, fmtUi(hi - (hi - lo) * k / 4, 1), Offset(left - 3, yy), text, right: true);
    }
    for (var k = 0; k <= 4; k++) {
      final xx = x(k / 4);
      canvas.drawLine(Offset(xx, top), Offset(xx, top + h), gridPaint);
      _text(canvas, '${k * 25} %', Offset(xx - 8, top + h + 2), text);
    }
    _text(canvas, unit, const Offset(2, 0), text);
    final pv = Paint()
      ..color = text
      ..strokeWidth = 1;
    canvas.drawLine(Offset(x(probability), top), Offset(x(probability), top + h), pv);
    for (final (v, c) in references) {
      canvas.drawLine(
        Offset(left, y(v)),
        Offset(left + w, y(v)),
        Paint()
          ..color = c
          ..strokeWidth = 1.4,
      );
    }
    final path = Path()..moveTo(x(points.first.$1), y(points.first.$2));
    for (final p in points.skip(1)) {
      path.lineTo(x(p.$1), y(p.$2));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    final dot = Paint()..color = line;
    for (final p in points) {
      canvas.drawCircle(Offset(x(p.$1), y(p.$2)), 2.2, dot);
    }
  }

  @override
  bool shouldRepaint(covariant ExceedanceCurvePainter old) => old.points != points || old.probability != probability || old.line != line || old.text != text;
}
