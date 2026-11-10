/// Operations (find_operations / run_operation) added in 1.7.0 for the
/// climate risk over the years (Design → Agronomy): built like those of
/// lib/app/ai/ops_eng_*.dart, joined to [AgentToolbox.operations].
library;

import 'dart:math' as math;

import '../../../core/ai/agent_loop.dart';
import '../../../core/design/climate_risk.dart';
import '../../../core/design/climate_risk_stats.dart';
import '../../../core/io/climate_online.dart' show ClimateException;
import '../../../core/model/entities.dart' show AreaEntity;
import '../../i18n.dart';
import '../../widgets/dialogs/climate_risk_dialog.dart' show climateRiskSources, runClimateRisk;
import '../agent_tools.dart';
import '../ops_eng_common.dart';

/// "P50 1.2, P80 1.5, P90 1.7, P95 1.8, max 2.0".
String _spread(List<double> xs, int d) =>
    xs.isEmpty ? '-' : [for (final f in climateRiskLevels) 'P${(f * 100).round()} ${engN(quantileAt(xs, f)!, d)}', 'max ${engN(xs.reduce(math.max), d)}'].join(', ');

String _trend(List<int> years, List<double> xs, String unit, int d) {
  final tr = senMannKendall(years, xs);
  if (tr == null) return 'no trend test (fewer than $minTrendYears years)';
  return 'Sen\'s slope ${tr.slopePerDecade >= 0 ? '+' : ''}${engN(tr.slopePerDecade, d)} $unit per decade, Mann-Kendall Z ${engN(tr.z, 2)} (${tr.significant ? 'significant' : 'not significant'} at 5 %)';
}

final I18n _en = I18n('en');

const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

/// The summary [s] as text for the model (SI units): the series, the site,
/// the project and every area, and the years of the project or of area
/// [areaId].
String climateRiskText(ClimateRiskSummary s, {String? areaId, String Function(String code)? warning}) {
  final out = StringBuffer(
    'Climate risk over ${s.firstYear}–${s.lastYear} from ${s.source == 'nasaPower' ? 'the NASA POWER daily point series' : 'the site climate\'s daily series (${s.source})'} at ${engN(s.latitudeDeg, 2)}, ${engN(s.longitudeDeg, 2)}, computed ${s.computed}. '
    'Irrigation years from 1 ${_months[s.startMonth - 1]}; peak period ${s.peakDays} days; P = non-exceedance probability (Weibull positions); design values at P${(s.probability * 100).round()}; programme window ${engN(s.windowHours, 1)} h/day. '
    'Reanalysis data smooth local extremes (a station on the site may show higher peaks and longer dry spells).${s.attribution.isEmpty ? '' : ' Credit: ${s.attribution}.'}',
  );
  final peak = [for (final y in s.site) y.peakEtoMmDay];
  final years = [for (final y in s.site) y.year];
  out.write('\n\nSite (${s.site.length} years): peak ${s.peakDays}-day ETo mm/day ${_spread(peak, 2)}');
  if (s.projectEtoMmDay != null) out.write('; the design\'s largest monthly ETo ${engN(s.projectEtoMmDay!, 2)} mm/day, exceeded in ${countAbove(peak, s.projectEtoMmDay!)} of ${peak.length} years');
  out.write('. Yearly ETo mm ${_spread([for (final y in s.site) y.etoMm], 0)} (${_trend(years, [for (final y in s.site) y.etoMm], 'mm', 0)}).');
  out.write(' Yearly rain mm ${_spread([for (final y in s.site) y.rainMm], 0)} (${_trend(years, [for (final y in s.site) y.rainMm], 'mm', 0)}).');
  final dry = [...s.site]..sort((a, b) => b.drySpellDays.compareTo(a.drySpellDays));
  out.write(' Longest dry spells (days with < 1 mm): ${[for (final y in dry.take(3)) '${y.drySpellDays} d from ${y.drySpellStart?.toIso8601String().substring(0, 10) ?? '-'}'].join(', ')}.');
  final full = s.project.where((y) => y.complete).toList();
  final designM3 = s.areas.fold(0.0, (a, x) => a + x.designYearGrossMm / 1000 * x.areaM2);
  if (full.isNotEmpty) {
    final vol = [for (final y in full) y.requirementM3];
    final ok = full.where((y) => y.deficitDays == 0).length;
    final worst = [...full]..sort((a, b) => b.requirementM3.compareTo(a.requirementM3));
    out.write(
      '\n\nProject (${full.length} years with every area): gross volume needed m³ ${_spread(vol, 0)}; the design\'s typical year ${engN(designM3, 0)} m³, exceeded in ${countAbove(vol, designM3)} years; '
      'volume pumped with the capacity m³ ${_spread([for (final y in full) y.pumpedM3], 0)}; $ok of ${full.length} years without a deficit day (${engN(100 * ok / full.length, 0)} %); '
      'largest years ${[for (final y in worst.take(3)) '${y.year} (${engN(y.requirementM3, 0)} m³)'].join(', ')}; ${_trend([for (final y in full) y.year], vol, 'm³', 0)}.',
    );
  }
  for (final a in s.areas) {
    final cap = a.capacityGrossMmDay;
    out.write(
      '\n\nArea ${a.areaId} "${a.name}" (${engN(a.areaM2 / 10000, 2)} ha): season from ${a.startDay} ${_months[a.startMonth - 1]}, ${a.seasonDays} days${a.crossesYear ? ' (into the next year)' : ''}; ${a.seasons.length} seasons; capacity ${cap == null ? 'unknown' : '${engN(cap, 2)} mm/day gross'}.',
    );
    if (a.seasons.isEmpty) continue;
    out.write(
      '\nGross irrigation needed mm ${_spread(a.grossMm, 0)}; design ${engN(a.designYearGrossMm, 0)} mm, exceeded in ${countAbove(a.grossMm, a.designYearGrossMm)} seasons; ${_trend(a.years, a.grossMm, 'mm', 0)}.'
      '\nPeak ${s.peakDays}-day gross demand mm/day ${_spread(a.peakGrossMmDay, 2)}; design ${engN(a.designPeakGrossMmDay, 2)}, exceeded in ${countAbove(a.peakGrossMmDay, a.designPeakGrossMmDay)} seasons${cap == null ? '' : '; above the capacity in ${countAbove(a.peakGrossMmDay, cap)} seasons'}.'
      '\nPeak ${s.peakDays}-day ETo in the season mm/day ${_spread(a.peakEtoMmDay, 2)}; design ETo ${engN(a.designEtoMmDay, 2)}, exceeded in ${countAbove(a.peakEtoMmDay, a.designEtoMmDay)} seasons.'
      '\nVolume pumped m³ ${_spread(a.pumpedM3, 0)}. Days past the allowed depletion ${_spread(a.deficitDays, 0)}; ${a.reliableSeasons} of ${a.seasons.length} seasons without one (${engN(100 * (a.reliability ?? 0), 0)} %). '
      'Worst seasons: ${[for (final w in a.worst()) '${w.year} (${engN(w.grossMm, 0)} mm, ${w.deficitDays} d)'].join(', ')}.',
    );
    for (final w in a.warnings) {
      out.write('\n- ${warning?.call(w) ?? w}');
    }
  }
  for (final w in s.warnings) {
    out.write('\n- ${warning?.call(w) ?? w}');
  }
  final area = areaId == null ? null : s.areas.where((a) => a.areaId == areaId).firstOrNull;
  if (area != null) {
    out.write('\n\nSeasons of ${area.name}:\n');
    out.write(
      engTable(
        ['start year', 'gross needed mm', 'net mm', 'gross applied mm', 'peak gross mm/d', 'peak ETo mm/d', 'deficit days', 'filled days'],
        [
          for (final x in area.seasons) [x.year, x.grossMm, x.netMm, x.appliedGrossMm, x.peakGrossMmDay, x.peakEtoMmDay, x.deficitDays, x.filledDays],
        ],
      ),
    );
  } else {
    final siteBy = {for (final y in s.site) y.year: y};
    final projBy = {for (final y in s.project) y.year: y};
    final all = {...siteBy.keys, ...projBy.keys}.toList()..sort();
    out.write('\n\nYear by year:\n');
    out.write(
      engTable(
        ['year', 'ETo mm', 'rain mm', 'peak ETo mm/d', 'dry spell d', 'needed m³', 'pumped m³', 'deficit days', 'areas in deficit'],
        [
          for (final y in all)
            [
              y,
              siteBy[y]?.etoMm,
              siteBy[y]?.rainMm,
              siteBy[y]?.peakEtoMmDay,
              siteBy[y]?.drySpellDays,
              projBy[y]?.complete ?? false ? projBy[y]!.requirementM3 : null,
              projBy[y]?.complete ?? false ? projBy[y]!.pumpedM3 : null,
              projBy[y]?.deficitDays,
              projBy[y]?.areasInDeficit,
            ],
        ],
      ),
    );
  }
  return out.toString();
}

List<AgentTool> opsClr(AgentToolbox b) {
  final c = b.c;
  final t = b.t;
  String warning(String code) {
    final i = code.indexOf(':');
    final key = i < 0 ? code : code.substring(0, i);
    final id = i < 0 ? '' : code.substring(i + 1);
    return _en('clr.w.$key', {'n': id.isEmpty ? '' : c.entityName(id)});
  }

  return [
    engOp(
      b,
      name: 'climate_risk',
      // keeping the summary changes the project; else only the download (another service) or nothing
      effectFor: (i) => i['use_kept'] == true ? ToolEffect.read : (i['keep'] == false ? (i['source'] == 'site' ? ToolEffect.read : ToolEffect.network) : ToolEffect.write),
      summary: (_) => t('clr.ai.op'),
      description:
          'Design → Agronomy → Climate risk over the years: how the system as designed would have done in each real year of a daily weather series of the site, instead of the one design figure. Source "nasaPower" (default) downloads the NASA POWER daily point series from $climateRiskFirstYear to the last complete year (temperatures, humidity, wind at 2 m, solar radiation, rain; free for any use; it sends the site\'s coordinates, rounded to 0.01°, to power.larc.nasa.gov; a few MB, kept on the device so a second run needs no network; needs a georeference); "site" uses the daily series kept with the site climate (a station file or an earlier download). '
          'Daily ETo by FAO-56 Penman-Monteith; every irrigated area with a water balance runs the FAO-56 daily soil water balance season by season (its crop, soil, Kc, planting date and the trigger of Design → Agronomy → Daily water balance, rainfed evaluated as irrigating at the allowed depletion) without a limit (the requirement) and limited to the gross depth the designed system can apply a day (emitter rate × the hours of its system flow in the programme window; pivots by depth per cycle), counting the crop days past the allowed depletion (deficit days). '
          'Returns, for the site, the project and every area, P50/P80/P90/P95/max (non-exceedance, Weibull plotting positions) of the yearly gross requirement and volume, the peak-period gross demand and ETo beside the figures the design uses and the capacity, the reliability (seasons without a deficit day), the worst years, the longest dry spells (days with < 1 mm), Sen\'s slope with the Mann-Kendall test, and a table year by year (of the project, or of "area"). '
          'keep (default true) stores the summary in the project (one undo step; the report tables climateRisk and climateRiskYears show it); keep false only answers; use_kept true reads the summary already kept (no computation, no network). Inputs: source, probability (0.5–0.99, default 0.8), peak_days (1–92, default 30, comparable with monthly normals), area, keep, use_kept.',
      schema: obj({
        'source': str('Daily series: nasaPower (download, default) or site (the site climate\'s own series).', climateRiskSources),
        'probability': num_('Non-exceedance probability of the design values, 0.5–0.99 (default 0.8).'),
        'peak_days': int_('Length of the peak period in days, 1–92 (default 30).'),
        'area': str('Irrigated area id or name: list its seasons year by year (omitted: the project year by year).'),
        'keep': bool_('Keep the summary in the project (default true).'),
        'use_kept': bool_('Read the summary already kept in the project instead of computing.'),
      }),
      run: (a, i) async {
        String? areaId;
        final ref = a.str('area');
        if (ref != null && ref.isNotEmpty) {
          final e = b.find(ref);
          if (e is! AreaEntity) throw ToolInputError('"$ref" is not an irrigated area (list_entities type area gives them).');
          areaId = e.id;
        }
        if (a.flag('use_kept') ?? false) {
          final kept = b.p.climateRisk;
          if (kept == null) throw ToolInputError('The project keeps no climate risk yet: run climate_risk without use_kept (it downloads the series or uses the site climate\'s).');
          return ToolOutput(climateRiskText(kept, areaId: areaId, warning: warning));
        }
        final keep = a.flag('keep') ?? true;
        if (keep) engNotBusy(c);
        final source = a.str('source') ?? 'nasaPower';
        final probability = a.number('probability', min: 0.5, max: 0.99) ?? 0.8;
        final peakDays = a.integer('peak_days', min: 1, max: 92) ?? 30;
        try {
          final s = await runClimateRisk(c, source: source, probability: probability, peakDays: peakDays, keep: keep, cancelled: () => b.host?.stopped ?? false);
          return ToolOutput('${keep ? 'Kept in the project (report tables climateRisk, climateRiskYears).\n' : ''}${climateRiskText(s, areaId: areaId, warning: warning)}');
        } on ClimateException catch (e) {
          throw ToolInputError(switch (e.code) {
            'climate_no_site' => 'The project has no georeference: call set_site first, or use source "site" when the site climate has a daily series.',
            'clr_no_areas' => 'Nothing to analyse: no irrigated area with a water balance (draw an area with a crop, or with ETo and Kc).',
            'clr_no_series' => 'The site climate has no daily series: use source "nasaPower", or download_climate / import a station file first.',
            'clr_busy' => 'A design is running; wait until it finishes.',
            _ => 'The climate download failed (${e.code}${(e.detail ?? '').isEmpty ? '' : ': ${e.detail}'}).',
          });
        }
      },
    ),
  ];
}
