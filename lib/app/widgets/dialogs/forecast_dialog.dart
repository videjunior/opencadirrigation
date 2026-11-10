/// Design → Agronomy → Irrigation forecast (1.7.0 FCT): the weather forecast of the site (MET Norway by default, free
/// for any use; Open-Meteo, non-commercial) turned into the irrigation of the next days for every irrigated area: the
/// days as columns, the ETo and the rain on top, a small chart, the run time of each area (or "skip") and the water
/// budget against the programme of the design; the source, its credit and the time the forecast was fetched; the
/// tables export to CSV, XLSX and PDF. The project is not changed; nothing is fetched until the user asks.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/irrigation_forecast.dart';
import '../../../core/design/report_tables.dart';
import '../../../core/io/project_export.dart' show ReportFormat;
import '../../../core/io/xlsx.dart';
import '../../../core/model/entities.dart';
import '../../actions.dart' show deliverExport;
import '../../io/forecast_http.dart';
import '../../io/links.dart';
import '../../io/pdf_font_loader.dart';
import '../../project_name.dart';
import '../../state/controller.dart';
import '../../theme.dart';
import '../fields.dart';
import '../reports_panel.dart' show ReportTableView;
import 'terrain_dialogs.dart' show dialogWidth;

// what the dialog remembers while the page is open
ForecastSource _source = ForecastSource.metNorway;
bool _full = true;
int _daysAgo = 2;
double _depthMm = 0;

/// The soil at the start as the dialog holds it.
ForecastStart forecastStartOf({required bool full, int daysAgo = 0, double depthMm = 0}) =>
    full ? const ForecastStart.full() : ForecastStart.last(daysAgo.clamp(0, 60), depthMm: depthMm > 0 ? depthMm : null);

/// The message of a fetch error.
String forecastErrorText(ProjectController c, Object e) {
  final t = c.t;
  if (e is ForecastException) {
    final base = t.has('fct.err.${e.code}') ? t('fct.err.${e.code}') : e.code;
    return e.code == 'fc_service_error' && (e.detail ?? '').isNotEmpty ? '$base (${e.detail})' : base;
  }
  return '${t('fct.err.fc_network')} ($e)';
}

String _two(int v) => v.toString().padLeft(2, '0');

/// A time of this device: `yyyy-MM-dd HH:mm`.
String forecastLocalTime(DateTime t) {
  final l = t.toLocal();
  return '${l.year}-${_two(l.month)}-${_two(l.day)} ${_two(l.hour)}:${_two(l.minute)}';
}

Widget _pairs(BuildContext ctx, List<Widget> fields) {
  if (MediaQuery.sizeOf(ctx).width < 520) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: fields);
  return Column(
    children: [
      for (var i = 0; i < fields.length; i += 2)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: fields[i]),
            const SizedBox(width: 8),
            Expanded(child: i + 1 < fields.length ? fields[i + 1] : const SizedBox.shrink()),
          ],
        ),
    ],
  );
}

Widget _small(String s, {Color? color, Key? key}) => Padding(
  padding: const EdgeInsets.only(bottom: 4),
  child: Text(
    s,
    key: key,
    style: TextStyle(fontSize: 11.5, color: color ?? Cad.fg70),
  ),
);

Future<void> _message(BuildContext context, ProjectController c, String text) => showDialog<void>(
  context: context,
  builder: (ctx) => AlertDialog(
    title: Text(c.t('fct.title'), style: const TextStyle(fontSize: 15)),
    content: SizedBox(
      width: dialogWidth(ctx, 420),
      child: Text(text, key: const Key('fct_message'), style: const TextStyle(fontSize: 12.5)),
    ),
    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(c.t('close')))],
  ),
);

/// The file of the tables of [plan] as [f] (CSV, XLSX or PDF): its name and its data (text or bytes).
Future<(String, Object)> forecastExportFile(ProjectController c, ForecastPlan plan, ReportFormat f) async {
  final tables = forecastTables(plan, c.exporter().labels, c.project.params.units);
  final name = '${projectFileStem(c.t, c.project.meta.name)}_${c.t('fct.file')}.${f.extension}';
  switch (f) {
    case ReportFormat.csv || ReportFormat.txt:
      return (name, reportTablesToCsv(tables));
    case ReportFormat.xlsx:
      return (
        name,
        XlsxWriter.write([
          for (final tb in tables)
            XlsxSheet(
              name: tb.title,
              headers: tb.headers,
              rows: [
                for (final r in tb.rows) [for (final x in r) x is RNum ? double.parse(x.value.toStringAsFixed(x.decimals)) : x],
              ],
            ),
        ]),
      );
    case ReportFormat.pdf:
      await preparePdfFonts([
        c.project.meta.name,
        for (final tb in tables) ...[tb.title, ...tb.headers, for (final r in tb.rows) ...r.whereType<String>()],
      ], language: c.lang);
      return (name, c.exporter().sheetBuilder().buildReport(tables));
  }
}

/// Exports the tables of [plan] as [f] (a download in the browser, the save dialog on the desktop).
Future<void> exportForecastTables(ProjectController c, ForecastPlan plan, ReportFormat f) async {
  final (name, data) = await forecastExportFile(c, plan, f);
  await deliverExport(c, name, f.mime, () => data);
}

/// The irrigation forecast of the project of [c] (see the library notes).
Future<void> showIrrigationForecastDialog(BuildContext context, ProjectController c) async {
  final t = c.t;
  final p = c.project;
  if (c.siteLatLon == null) return _message(context, c, t('fct.err.fc_no_site'));
  if (!p.entities.any((e) => e is AreaEntity && e.points.length >= 3)) return _message(context, c, t('fct.noAreas'));
  ForecastSeries? series = await keptSiteForecast(c, _source);
  if (!context.mounted) return;
  var busy = false;
  String? error;
  var gen = 0;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final u = p.params.units;
        final now = forecastClock();
        final start = forecastStartOf(full: _full, daysAgo: _daysAgo, depthMm: _depthMm);
        final plan = series == null ? null : irrigationForecast(p, c.results, series!, now: now, start: start);
        final tables = plan == null ? const <ReportTable>[] : forecastTables(plan, c.exporter().labels, u);
        final tooSoon = series != null && now.toUtc().isBefore(series!.askAgainAfter);

        Future<void> fetch() async {
          setState(() {
            busy = true;
            error = null;
          });
          try {
            final s = await fetchSiteForecast(c, _source, refresh: series != null && series!.source == _source);
            series = s;
            if (s.staleCode != null) error = forecastErrorText(c, ForecastException(s.staleCode!));
          } catch (e) {
            error = forecastErrorText(c, e);
          }
          if (ctx.mounted) setState(() => busy = false);
        }

        void locate(String id) {
          if (p.byId(id) == null) return;
          c.select([id]);
          c.zoomToEntity(id);
        }

        final s = series;
        final body = <Widget>[
          _small(t('fct.hint')),
          _pairs(ctx, [
            SpecDropdown<ForecastSource>(
              key: const Key('fct_source'),
              label: t('fct.source'),
              value: _source.name,
              items: ForecastSource.values,
              labelOf: (x) => t('fct.src.${x.name}'),
              idOf: (x) => x.name,
              onChanged: (v) => setState(() {
                _source = ForecastSource.values.byName(v!);
                if (series?.source != _source) series = null;
                error = null;
              }),
            ),
            SpecDropdown<bool>(
              key: const Key('fct_start'),
              label: t('fct.start'),
              value: '$_full',
              items: const [true, false],
              labelOf: (x) => t(x ? 'fct.start.full' : 'fct.start.last'),
              idOf: (x) => '$x',
              onChanged: (v) => setState(() {
                _full = v == 'true';
                gen++;
              }),
            ),
            if (!_full)
              NumField(
                key: ValueKey('fct_days_ago_$gen'),
                label: t('fct.daysAgo'),
                value: _daysAgo.toDouble(),
                decimals: 0,
                signed: false,
                onChanged: (v) => setState(() => _daysAgo = v.round().clamp(0, 60)),
              ),
            if (!_full)
              NumField(
                key: ValueKey('fct_depth_$gen'),
                label: '${t('fct.depth')} (${u.depthLabel})',
                value: u.depthFromMm(_depthMm),
                decimals: 1,
                signed: false,
                onChanged: (v) => setState(() => _depthMm = math.max(0.0, u.depthToMm(v))),
              ),
          ]),
          _small(t(_source == ForecastSource.metNorway ? 'terms.src.metNorway' : 'terms.src.openMeteoForecast'), key: const Key('fct_terms'), color: _source.commercialUse ? Cad.fg60 : Cad.warning),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                key: const Key('fct_fetch'),
                onPressed: busy || (tooSoon && s?.source == _source) ? null : fetch,
                icon: const Icon(Icons.cloud_download_outlined, size: 16),
                label: Text(s == null ? t('fct.fetch') : t('fct.refresh')),
              ),
              TextButton.icon(
                key: const Key('fct_terms_link'),
                onPressed: () => openExternalLink(_source.termsUrl),
                icon: const Icon(Icons.open_in_new, size: 14),
                label: Text(_source.host, style: const TextStyle(fontSize: 11)),
              ),
            ],
          ),
          if (tooSoon && s != null) _small(t('fct.refreshAfter', {'t': forecastLocalTime(s.askAgainAfter).substring(11)}), key: const Key('fct_too_soon'), color: Cad.fg54),
          if (busy) const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: LinearProgressIndicator(minHeight: 3)),
          if (error != null) _small(error!, key: const Key('fct_error'), color: Cad.caution),
          if (plan != null && s != null) ...[
            KV(t('fct.fetched'), '${forecastLocalTime(s.fetchedAt)}${s.fromDevice ? ' · ${t('fct.kept')}' : ''}'),
            KV(t('src.credit'), s.source.attribution),
            _small(plan.days.any((d) => d.byService) ? t('fct.etoBy.service') : t('fct.etoBy.pm'), color: Cad.fg60),
            for (final w in plan.warnings) _small(t('fct.w.$w'), color: Cad.caution),
            if (plan.days.isNotEmpty) ...[
              const SizedBox(height: 4),
              SizedBox(
                height: 120,
                child: CustomPaint(
                  key: const Key('fct_chart'),
                  painter: ForecastChartPainter(plan.days, eto: Cad.accent, rainfall: Cad.info, grid: Cad.chartGrid, text: Cad.fg60, depth: u.depthFromMm, depthLabel: u.depthLabel),
                  child: const SizedBox.expand(),
                ),
              ),
              Wrap(spacing: 10, children: [_legend(Cad.accent, 'ETo'), _legend(Cad.info, t('req.rain'))]),
              SectionTitle(tables.first.title),
              SizedBox(
                height: 220,
                child: ReportTableView(
                  key: const Key('fct_table'),
                  headers: tables.first.headers,
                  rows: tables.first.rows,
                  rowIds: tables.first.ids,
                  // on a phone the toolbar of the table has no room for the highlighted-rows filter: the messages follow the table
                  rowColors: MediaQuery.sizeOf(ctx).width < 520 ? null : [for (final w in tables.first.warn) w ? Cad.tintWarning : null],
                  onLocate: locate,
                  title: tables.first.key,
                  tools: true,
                ),
              ),
              for (final a in plan.areas)
                if (a.warnings.isNotEmpty) _small('${a.name}: ${[for (final w in a.warnings) t('fct.w.$w')].join('; ')}', color: Cad.caution),
              const SizedBox(height: 4),
              _small(t('fct.assume'), key: const Key('fct_assume'), color: Cad.fg60),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final f in const [ReportFormat.csv, ReportFormat.xlsx, ReportFormat.pdf])
                    OutlinedButton(key: Key('fct_export_${f.extension}'), onPressed: () => exportForecastTables(c, plan, f), child: Text(f.extension.toUpperCase())),
                ],
              ),
              SectionTitle(tables.last.title),
              SizedBox(
                height: 200,
                child: ReportTableView(
                  key: const Key('fct_days_table'),
                  headers: tables.last.headers,
                  rows: tables.last.rows,
                  rowIds: tables.last.ids,
                  onLocate: locate,
                  title: tables.last.key,
                  tools: true,
                ),
              ),
            ],
          ],
        ];
        return AlertDialog(
          title: Text(t('fct.title'), style: const TextStyle(fontSize: 15)),
          content: SizedBox(
            width: dialogWidth(ctx, 760),
            child: ScrollBody(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: body),
            ),
          ),
          actions: [TextButton(key: const Key('fct_close'), onPressed: () => Navigator.pop(ctx), child: Text(t('close')))],
        );
      },
    ),
  );
}

Widget _legend(Color color, String label) => Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    Container(width: 10, height: 10, color: color),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 11)),
  ],
);

/// The ETo and the rain of every day of the forecast as pairs of bars, with the day of the month under them.
class ForecastChartPainter extends CustomPainter {
  ForecastChartPainter(this.days, {required this.eto, required this.rainfall, required this.grid, required this.text, required this.depth, required this.depthLabel});
  final List<ForecastWeatherDay> days;
  final Color eto, rainfall, grid, text;
  final double Function(double mm) depth;
  final String depthLabel;

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty || size.width < 40 || size.height < 40) return;
    const left = 30.0, bottom = 14.0, top = 4.0;
    final w = size.width - left - 4, h = size.height - top - bottom;
    final top0 = days.fold(1.0, (m, d) => math.max(m, math.max(d.etoMm, d.rainMm)));
    final scale = (top0 / 5).ceil() * 5.0;
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    TextPainter label(String s) => TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontSize: 9, color: text),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    for (var k = 0; k <= 2; k++) {
      final y = top + h * (1 - k / 2);
      canvas.drawLine(Offset(left, y), Offset(left + w, y), gridPaint);
      final tp = label(fmtUi(depth(scale * k / 2), 0));
      tp.paint(canvas, Offset(left - tp.width - 3, y - tp.height / 2));
    }
    final slot = w / days.length;
    final bw = math.max(1.0, slot * 0.36);
    for (var i = 0; i < days.length; i++) {
      final d = days[i];
      final x0 = left + slot * i + slot / 2;
      final he = h * (d.etoMm / scale).clamp(0.0, 1.0), hr = h * (d.rainMm / scale).clamp(0.0, 1.0);
      canvas.drawRect(Rect.fromLTWH(x0 - bw, top + h - he, bw, he), Paint()..color = eto.withValues(alpha: d.estimated ? 0.45 : 0.85));
      if (hr > 0) canvas.drawRect(Rect.fromLTWH(x0, top + h - hr, bw, hr), Paint()..color = rainfall.withValues(alpha: 0.75));
      final tp = label('${d.date.day}${d.estimated ? '*' : ''}');
      tp.paint(canvas, Offset(x0 - tp.width / 2, top + h + 2));
    }
  }

  @override
  bool shouldRepaint(covariant ForecastChartPainter old) => !identical(old.days, days) || old.eto != eto || old.text != text;
}
