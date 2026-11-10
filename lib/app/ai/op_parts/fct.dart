/// Operations (find_operations / run_operation) added in 1.7.0 for the irrigation forecast: how much to irrigate
/// today and in the next days, from the weather forecast of the site. Built like those of lib/app/ai/ops_eng_*.dart,
/// joined to [AgentToolbox.operations].
library;

import '../../../core/ai/agent_loop.dart';
import '../../../core/design/irrigation_forecast.dart';
import '../../../core/model/entities.dart';
import '../../i18n.dart';
import '../../io/forecast_http.dart';
import '../../../core/io/project_export.dart' show ReportFormat;
import '../../widgets/dialogs/forecast_dialog.dart' show forecastExportFile, forecastLocalTime, forecastStartOf;
import '../agent_tools.dart';
import '../ops_eng_common.dart';

/// The texts the model reads are in English (as the other operations write them).
final I18n _en = I18n('en');

List<AgentTool> opsFct(AgentToolbox b) {
  final c = b.c;
  String d10(DateTime d) => d.toIso8601String().substring(0, 10);
  return [
    engOp(
      b,
      name: 'irrigation_forecast',
      // 1.7.0 FCT: it asks an online service (like find_site); the project is not changed; a file is always confirmed
      effect: ToolEffect.network,
      effectFor: (i) => i['export'] != null ? ToolEffect.export : ToolEffect.network,
      description: 'Design → Agronomy → Irrigation forecast: how much to irrigate today and in the next days. Fetches the daily weather forecast of the site (it sends the site\'s coordinates, cut to 4 decimals, to the service; a forecast kept on the device is used while it stays valid) and runs, for every irrigated area, the daily soil water balance of the app from today: the ETo of each day (FAO-56 Penman-Monteith on the forecast with the radiation from the temperature range, eq. 50, for MET Norway, which gives no radiation; the service\'s own FAO-56 ETo for Open-Meteo), the Kc of the crop and its growth stage on each date (the planting date read for the hemisphere of the site), the effective rain (below 0.2·ETo it does not count; above field capacity it percolates); an area is irrigated on the day its depletion reaches the net depth of one event of the design programme (or the allowed depletion of the stage, if less), refilling it; run time = gross depth / application rate of the design results (nominal emitters without results). The project is not changed. Inputs: source "met_norway" (default: free for any use, professional work included, credit "MET Norway") or "open_meteo" (its free API is for non-commercial use only: only when the user asks for it); start "full" (default: the soil at field capacity today) or "last" (the last irrigation or rain was days_ago days ago, 0–60, with depth_mm of water into the soil; 0 or absent = it filled the root zone); area (id or name; default every area); days 1–16 (default every day the forecast gives); refresh (ask the service again; never before the time the service allows); export "csv" | "xlsx" | "pdf" (also writes the two tables as a file, as the buttons of the dialog do; always confirmed by the user). Output: the source and its credit (quote it), when the forecast was fetched, ETo and rain of each day, and for each area the programme per event, the water budget % to type into the controller (the water the crop uses less the rain the soil keeps, over what the design programme applies in as many days) and, day by day, irrigate (run time h:mm, gross depth, % of one programmed event) or skip; then the assumptions to tell the user (a forecast is uncertain, more so after three days; the soil as given; no rain after the last day).',
      schema: obj({
        'source': str('Default "met_norway".', ['met_norway', 'open_meteo']),
        'start': str('Soil at the start; default "full".', ['full', 'last']),
        'days_ago': int_('start "last": days since the last irrigation or rain, 0–60.'),
        'depth_mm': num_('start "last": water that went into the soil, 0–500 mm; 0 = it filled the root zone.'),
        'area': str('Irrigated area id or name; default all.'),
        'days': int_('Days to report, 1–16.'),
        'refresh': bool_('Ask the service again (never before the time it allows).'),
        'export': str('Also write the tables as a file.', ['csv', 'xlsx', 'pdf']),
      }),
      run: (a, _) async {
        final source = a.str('source') == 'open_meteo' ? ForecastSource.openMeteo : ForecastSource.metNorway;
        final full = (a.str('start') ?? 'full') != 'last';
        final start = forecastStartOf(full: full, daysAgo: a.integer('days_ago', min: 0, max: 60) ?? 1, depthMm: a.number('depth_mm', min: 0, max: 500) ?? 0);
        AreaEntity? only;
        if (a.has('area')) {
          final e = b.find(a.str('area')!);
          if (e is! AreaEntity) throw ToolInputError('"${a.str('area')}" is not an irrigated area.');
          only = e;
        }
        if (c.siteLatLon == null) throw ToolInputError('The project has no georeference: call set_site first.');
        final ForecastSeries series;
        try {
          series = await fetchSiteForecast(c, source, refresh: a.flag('refresh') ?? false);
        } on ForecastException catch (e) {
          throw ToolInputError('The forecast could not be fetched (${e.code}${(e.detail ?? '').isEmpty ? '' : ': ${e.detail}'}).');
        }
        final plan = irrigationForecast(b.p, c.results, series, now: forecastClock(), start: start, maxDays: a.integer('days', min: 1, max: 16));
        String w(String code) => _en('fct.w.$code');
        final out = StringBuffer(
          'Forecast from ${source.label} for ${engN(series.latitudeDeg, 4)}, ${engN(series.longitudeDeg, 4)}, fetched ${forecastLocalTime(series.fetchedAt)} (device time)${series.fromDevice ? ', kept on this device' : ''}. Credit: ${source.attribution}.',
        );
        if (series.staleCode != null) out.write(' The service did not answer now (${series.staleCode}): this is the kept forecast.');
        if (!source.commercialUse) out.write(' Note: the free Open-Meteo API is for non-commercial use only.');
        for (final x in plan.warnings) {
          out.write('\n${w(x)}');
        }
        if (plan.days.isEmpty) return ToolOutput(out.toString());
        out.write(
          '\nETo ${plan.days.any((d) => d.byService) ? 'published by the service' : 'by FAO-56 Penman-Monteith, radiation from the temperature range (eq. 50)'}.\n${engTable(['date', 'ETo mm', 'rain mm', 'effective rain mm', 'Tmax °C', 'Tmin °C'], [
            for (final d in plan.days) ['${d10(d.date)}${d.estimated ? '*' : ''}', d.etoMm, d.rainMm, d.effectiveRainMm, d.tMaxC, d.tMinC],
          ])}',
        );
        final areas = [
          for (final x in plan.areas)
            if (only == null || x.areaId == only.id) x,
        ];
        if (areas.isEmpty) out.write('\nNo irrigated area with a forecast.');
        for (final ar in areas) {
          out.write('\n\n${ar.name} (${ar.areaId}):');
          if (!ar.balance) {
            out.write(' ${w('fct_fixed_depth')}.');
            continue;
          }
          out.write(
            ' programme ${ar.programmeHours == null ? '-' : engHm(ar.programmeHours!)} per event (${engN(ar.programmeGrossMm, 1)} mm gross, every ${engN(ar.intervalDays, 0)} d), rate ${engN(ar.rateMmH, 2)} mm/h; water budget ${ar.budgetPct == null ? '-' : '${engN(ar.budgetPct!, 0)} %'}; ${ar.irrigations} irrigation${ar.irrigations == 1 ? '' : 's'}, ${engN(ar.grossMm, 1)} mm gross; depletion at the start ${engN(ar.startDepletionMm, 1)} mm.',
          );
          for (final x in ar.warnings) {
            out.write(' ${w(x)}.');
          }
          out.write(
            '\n${engTable(['date', 'stage', 'Kc', 'ETc mm', 'depletion mm', 'decision', 'gross mm', 'run time', '% of event'], [
              for (final d in ar.days) [d10(d.date), forecastStageName(d.stage, _en.call), d.kc, d.etcMm, d.depletionMm, d.irrigate ? 'irrigate' : 'skip', d.grossMm, d.runHours == null ? '-' : engHm(d.runHours!), d.eventPct == null ? '-' : engN(d.eventPct!, 0)],
            ])}',
          );
        }
        out.write('\n\nAssumptions: ${_en('fct.assume')}');
        final format = switch (a.str('export')) {
          'csv' => ReportFormat.csv,
          'xlsx' => ReportFormat.xlsx,
          'pdf' => ReportFormat.pdf,
          _ => null,
        };
        if (format != null) {
          final (name, data) = await forecastExportFile(c, plan, format);
          await engFileSink(c, name, format.mime, data);
          out.write('\nExported $name.');
        }
        return ToolOutput(out.toString());
      },
    ),
  ];
}
