/// Agronomy dialogs: the site climate (downloaded or typed), solar pumping,
/// the drip wetted bulb and the landscape water budget.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/area_requirement.dart';
import '../../../core/design/designer.dart' show areaRequirements;
import '../../../core/design/solar_pumping.dart';
import '../../../core/design/soils.dart';
import '../../../core/design/water_budget.dart';
import '../../../core/design/wetted_bulb.dart';
import '../../../core/io/climate_online.dart' show ClimateSource;
import '../../../core/model/entities.dart';
import '../../../core/model/site_climate.dart';
import '../../../core/units.dart';
import '../../state/controller.dart';
import '../../theme.dart';
import '../fields.dart';
import 'terrain_dialogs.dart' show dialogWidth;

Widget _row(List<Widget> children) => Row(
  children: [
    for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(width: 8), Expanded(child: children[i])],
  ],
);

Widget _cell(String s, {bool bold = false, Color? color}) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
  child: Text(
    s,
    style: TextStyle(fontSize: 11.5, fontWeight: bold ? FontWeight.w600 : null, color: color),
  ),
);

// ---------------------------------------------------------------- site climate

/// Monthly climate of the site: downloaded from a public service for the
/// georeferenced site, or typed and edited by hand; stored in the project.
Future<void> showSiteClimateDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final cur = c.project.climate;
  final eto = _months(cur?.etoMmDay);
  final rain = _months(cur?.rainMm);
  final dep = _months(cur?.dependableRainMm);
  final rs = _months(cur?.solarKWhM2Day);
  var source = ClimateSource.openMeteo;
  var years = 10;
  var busy = false;
  var progress = 0.0;
  var cancel = false;
  String? error;
  var info = cur;
  var gen = 0;
  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final site = c.siteLatLon;
        Future<void> download() async {
          setState(() {
            busy = true;
            cancel = false;
            error = null;
            progress = 0;
          });
          try {
            final sc = await c.downloadClimate(
              source,
              years: years,
              onProgress: (d, n) {
                if (ctx.mounted) setState(() => progress = n == 0 ? 0 : d / n);
              },
              cancelled: () => cancel,
            );
            for (var m = 0; m < 12; m++) {
              eto[m] = sc.etoMmDay[m];
              rain[m] = sc.rainMm[m];
              dep[m] = sc.dependableRainMm?[m] ?? sc.rainMm[m];
              rs[m] = sc.solarKWhM2Day?[m] ?? 0;
            }
            info = sc;
            gen++;
          } catch (e) {
            error = c.describeError(e);
          }
          if (ctx.mounted) setState(() => busy = false);
        }

        void save() {
          final now = c.project.climate;
          if (now != null && _same(eto, now.etoMmDay) && _same(rain, now.rainMm) && _same(dep, _months(now.dependableRainMm)) && _same(rs, _months(now.solarKWhM2Day))) return;
          // values typed over a download keep its credit but are no longer the service's
          final base = info;
          final edited = base == null || !_same(eto, base.etoMmDay) || !_same(rain, base.rainMm);
          c.setClimate(
            SiteClimate(
              etoMmDay: [...eto],
              rainMm: [...rain],
              dependableRainMm: dep.any((v) => v > 0) ? [...dep] : null,
              solarKWhM2Day: rs.any((v) => v > 0) ? [...rs] : null,
              source: edited ? 'manual' : base.source,
              firstYear: base?.firstYear ?? 0,
              lastYear: base?.lastYear ?? 0,
              latitudeDeg: site?.$1 ?? base?.latitudeDeg ?? 0,
              longitudeDeg: site?.$2 ?? base?.longitudeDeg ?? 0,
              retrieved: base?.retrieved ?? '',
              attribution: base?.attribution ?? '',
            ),
          );
        }

        Widget num(List<double> v, int m, {int decimals = 1}) => SizedBox(
          width: 72,
          child: NumField(key: ValueKey('clim_${v.hashCode}_${m}_$gen'), label: '', value: v[m], decimals: decimals, onChanged: (x) => v[m] = x < 0 ? 0 : x),
        );
        return AlertDialog(
          title: Text(t('clim.title'), style: const TextStyle(fontSize: 15)),
          content: SizedBox(
            width: dialogWidth(ctx, 640),
            child: ScrollBody(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // while the download runs, Esc and a tap outside do not close the dialog (its Cancel stops it)
                  PopScope(
                    canPop: !busy,
                    onPopInvokedWithResult: (didPop, _) {
                      if (!didPop) c.notify(t('ui.downloadRunning'));
                    },
                    child: const SizedBox.shrink(),
                  ),
                  Text(t('clim.hint'), style: TextStyle(fontSize: 12, color: Cad.fg70)),
                  const SizedBox(height: 8),
                  if (site == null)
                    Text(t('msg.climate_no_site'), style: TextStyle(fontSize: 12, color: Cad.warning))
                  else ...[
                    Text('${t('clim.site')}: ${fmt(site.$1, 4)}°, ${fmt(site.$2, 4)}°', style: const TextStyle(fontSize: 12)),
                    _row([
                      SpecDropdown<ClimateSource>(
                        label: t('clim.source'),
                        value: source.name,
                        items: ClimateSource.values,
                        labelOf: (s) => t('clim.src.${s.name}'),
                        idOf: (s) => s.name,
                        onChanged: (v) => setState(() => source = ClimateSource.values.byName(v!)),
                      ),
                      NumField(label: t('clim.years'), value: years.toDouble(), decimals: 0, onChanged: (v) => years = v.round().clamp(1, 40)),
                    ]),
                    Row(
                      children: [
                        FilledButton.icon(
                          key: const Key('clim_download'),
                          onPressed: busy ? null : download,
                          icon: const Icon(Icons.cloud_download_outlined, size: 16),
                          label: Text(t('clim.download')),
                        ),
                        const SizedBox(width: 8),
                        if (busy) ...[
                          SizedBox(width: 120, child: LinearProgressIndicator(value: progress > 0 ? progress : null)),
                          TextButton(onPressed: () => cancel = true, child: Text(t('cancel'))),
                        ],
                      ],
                    ),
                  ],
                  if (error != null) Text(error!, style: TextStyle(fontSize: 12, color: Cad.warning)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Table(
                      defaultColumnWidth: const IntrinsicColumnWidth(),
                      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                      children: [
                        TableRow(
                          children: [
                            _cell(t('req.month'), bold: true),
                            _cell('ETo (mm/d)', bold: true),
                            _cell('${t('req.rain')} (mm)', bold: true),
                            _cell('${t('clim.dependable')} (mm)', bold: true),
                            _cell('${t('clim.radiation')} (kWh/m²/d)', bold: true),
                          ],
                        ),
                        for (var m = 0; m < 12; m++) TableRow(children: [_cell(t('mon.${m + 1}')), num(eto, m, decimals: 2), num(rain, m), num(dep, m), num(rs, m, decimals: 2)]),
                      ],
                    ),
                  ),
                  if (info != null && info!.attribution.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${info!.attribution}${info!.firstYear > 0 ? ' · ${info!.firstYear}–${info!.lastYear}' : ''}${info!.retrieved.isNotEmpty ? ' · ${info!.retrieved}' : ''}',
                      style: TextStyle(fontSize: 10.5, color: Cad.fg54),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            if (c.project.climate != null)
              TextButton(
                onPressed: () {
                  c.setClimate(null);
                  Navigator.pop(ctx);
                },
                child: Text(t('clim.clear')),
              ),
            TextButton(key: const Key('clim_cancel'), onPressed: busy ? () => setState(() => cancel = true) : () => Navigator.pop(ctx), child: Text(t('cancel'))),
            FilledButton(
              key: const Key('clim_ok'),
              onPressed: busy
                  ? null
                  : () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      Future<void>.delayed(Duration.zero, save);
                      Navigator.pop(ctx);
                    },
              child: Text(t('ok')),
            ),
          ],
        );
      },
    ),
  );
}

/// A copy of twelve monthly values (zeros when there are none).
List<double> _months(List<double>? v) => [...(v ?? List.filled(12, 0.0))];

bool _same(List<double> a, List<double> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if ((a[i] - b[i]).abs() > 1e-9) return false;
  }
  return true;
}

// ---------------------------------------------------------------- solar pumping

/// Size a photovoltaic array for the pumping of the project: the daily
/// volume of every month (from the requirement of the areas, or typed), the
/// pump's total dynamic head (from the design, or typed) and the monthly
/// irradiation of the site climate.
Future<void> showSolarPumpingDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final req = areaRequirementTables(c.project, c.results);
  final volume = List<double>.filled(12, 0);
  for (final table in req.values) {
    for (final row in table.monthly) {
      volume[row.start.month - 1] += row.dailyVolumeM3;
    }
  }
  final r = c.results;
  var head = 0.0;
  for (final f in r?.systemFlows ?? const []) {
    for (final d in f.devices) {
      head = math.max(head, d.pumpHead);
    }
    for (final s in f.supplies) {
      if (s.calculated) head = math.max(head, s.requiredHead);
    }
  }
  final radiation = [...(c.project.climate?.solarKWhM2Day ?? List.filled(12, 5.0))];
  var modulePower = 550.0, efficiency = 0.45, tilt = c.siteLatLon?.$1.abs() ?? 15.0;
  final cur = c.project.params.currency;
  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final lat = c.siteLatLon?.$1 ?? -15.0;
        final res = sizeSolarPumping(
          SolarPumpInput(
            months: [for (var m = 0; m < 12; m++) SolarPumpMonth(month: m + 1, dailyVolumeM3: volume[m], horizontalKWhM2Day: radiation[m])],
            latitudeDeg: lat,
            headM: head,
            tiltDeg: tilt,
            motorPumpEfficiency: efficiency,
            modulePowerWp: modulePower,
            gridTariffPerKWh: c.project.params.powerCostPerKwh,
          ),
        );
        Widget num(List<double> v, int m) => SizedBox(
          width: 70,
          child: NumField(label: '', value: v[m], onChanged: (x) => setState(() => v[m] = x < 0 ? 0 : x)),
        );
        return AlertDialog(
          title: Text(t('solar.title'), style: const TextStyle(fontSize: 15)),
          content: SizedBox(
            width: dialogWidth(ctx, 720),
            child: ScrollBody(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('solar.hint'), style: TextStyle(fontSize: 12, color: Cad.fg70)),
                  const SizedBox(height: 6),
                  _row([
                    NumField(key: const Key('solar_head'), label: t('solar.head'), value: head, onChanged: (v) => setState(() => head = v < 0 ? 0 : v)),
                    NumField(label: t('solar.efficiency'), value: efficiency, onChanged: (v) => setState(() => efficiency = v.clamp(0.05, 0.95).toDouble())),
                    NumField(label: t('solar.module'), value: modulePower, decimals: 0, onChanged: (v) => setState(() => modulePower = v < 10 ? 10 : v)),
                    NumField(label: t('solar.tilt'), value: tilt, onChanged: (v) => setState(() => tilt = v.clamp(0, 90).toDouble())),
                  ]),
                  if (c.project.climate?.solarKWhM2Day == null) Text(t('solar.noRadiation'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Table(
                      defaultColumnWidth: const IntrinsicColumnWidth(),
                      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                      children: [
                        TableRow(
                          children: [
                            _cell(t('req.month'), bold: true),
                            _cell('${t('solar.volume')} (m³/d)', bold: true),
                            _cell('${t('clim.radiation')} (kWh/m²/d)', bold: true),
                            _cell(t('solar.sunHours'), bold: true),
                            _cell('${t('solar.required')} (kWp)', bold: true),
                            _cell('${t('solar.pumped')} (m³/d)', bold: true),
                            _cell(t('solar.hours'), bold: true),
                          ],
                        ),
                        for (final m in res.months)
                          TableRow(
                            children: [
                              _cell(t('mon.${m.month}'), bold: m.month == res.criticalMonth),
                              num(volume, m.month - 1),
                              num(radiation, m.month - 1),
                              _cell(fmt(m.peakSunHours, 2)),
                              _cell(fmt(m.requiredKWp, 2), color: m.month == res.criticalMonth ? Cad.warning : null),
                              _cell(fmt(m.pumpedM3Day, 1), color: m.pumpedM3Day + 1e-6 < m.demandM3Day ? Cad.warning : null),
                              _cell(fmt(m.pumpingHours, 1)),
                            ],
                          ),
                      ],
                    ),
                  ),
                  SectionTitle(t('solar.result')),
                  KV(t('solar.critical'), res.criticalMonth == null ? '-' : t('mon.${res.criticalMonth}')),
                  KV(t('solar.array'), '${res.modules} × ${fmt(modulePower, 0)} Wp = ${fmt(res.arrayKWp, 2)} kWp'),
                  KV(t('solar.annual'), '${fmt(res.annualPumpedM3, 0)} m³ (${fmt(res.annualDemandM3, 0)} m³)'),
                  KV(t('solar.grid'), '${fmt(res.annualGridKWh, 0)} kWh · $cur ${fmt(res.annualGridCost, 2)}'),
                  if (res.warnings.isNotEmpty)
                    Text(
                      res.warnings.map((w) => c.t.warning(w, entityName: (m) => t('mon.$m'))).toSet().join('\n'),
                      style: TextStyle(fontSize: 11, color: Cad.warning),
                    ),
                ],
              ),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('close')))],
        );
      },
    ),
  );
}

// ---------------------------------------------------------------- wetted bulb

/// Wetted bulb of a dripper: width and depth for its flow, the water of one
/// irrigation and the soil, and the wetted share of the ground for the
/// emitter and lateral spacing.
Future<void> showWettedBulbDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  var flow = 2.0, volume = 8.0, emitterSpacing = 0.5, lateralSpacing = 1.0;
  var soil = 'soil.loam';
  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final s = soilTable[soil]!;
        final b = schwartzmanZurBulb(flowLph: flow, volumeL: volume, ksatMmH: s.ksatMmH);
        final pw = percentWettedAreaOfLaterals(lateralsPerRow: 1, emitterSpacingM: emitterSpacing, wettedWidthM: b.widthM, rowSpacingM: lateralSpacing);
        return AlertDialog(
          title: Text(t('bulb.title'), style: const TextStyle(fontSize: 15)),
          content: SizedBox(
            width: dialogWidth(ctx, 460),
            child: ScrollBody(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('bulb.hint'), style: TextStyle(fontSize: 12, color: Cad.fg70)),
                  SpecDropdown<String>(label: t('req.soil'), value: soil, items: soilTable.keys.toList(), labelOf: (k) => t(k), idOf: (k) => k, onChanged: (v) => setState(() => soil = v ?? soil)),
                  _row([
                    NumField(key: const Key('bulb_flow'), label: t('bulb.flow'), value: flow, onChanged: (v) => setState(() => flow = v <= 0 ? flow : v)),
                    NumField(label: t('bulb.volume'), value: volume, onChanged: (v) => setState(() => volume = v < 0 ? 0 : v)),
                  ]),
                  _row([
                    NumField(label: t('bulb.emitterSpacing'), value: emitterSpacing, onChanged: (v) => setState(() => emitterSpacing = v <= 0 ? emitterSpacing : v)),
                    NumField(label: t('bulb.lateralSpacing'), value: lateralSpacing, onChanged: (v) => setState(() => lateralSpacing = v <= 0 ? lateralSpacing : v)),
                  ]),
                  SectionTitle(t('dens.results')),
                  KV(t('bulb.width'), '${fmt(b.widthM, 2)} m'),
                  KV(t('bulb.depth'), '${fmt(b.depthM, 2)} m'),
                  KV(t('bulb.wetted'), '${fmt(pw, 0)} %'),
                  KV('Ksat', '${fmt(s.ksatMmH, 1)} mm/h'),
                  if (b.extrapolated) Text(t('bulb.extrapolated'), style: TextStyle(fontSize: 11, color: Cad.warning)),
                ],
              ),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('close')))],
        );
      },
    ),
  );
}

// ---------------------------------------------------------------- landscape water budget

/// Landscape water budget: the irrigated areas marked as hydrozones (plant
/// water use) against the maximum applied water allowance of the annual
/// ETo (equations of California's model water-efficient landscape
/// ordinance), with the cycle-and-soak split of every area on its soil.
Future<void> showWaterBudgetDialog(BuildContext context, ProjectController c) {
  final t = c.t;
  final areas = c.project.entities.whereType<AreaEntity>().where((a) => a.plantWaterUse.isNotEmpty).toList();
  final climate = c.project.climate;
  var etoYear = climate == null ? 1500.0 : [for (var m = 0; m < 12; m++) climate.etoMmDay[m] * DateTime.utc(2001, m + 2, 0).day].fold(0.0, (a, b) => a + b);
  var residential = true;
  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final zones = [
          for (final a in areas)
            Hydrozone(id: a.id, area: a.area, plantFactor: _plantFactor(a.plantWaterUse), irrigationEfficiency: a.irrigationMethod == 'localized' ? mweloEfficiencyDrip : mweloEfficiencySpray),
        ];
        final wb = zones.isEmpty ? null : mweloWaterBudget(etoPerYear: etoYear, hydrozones: zones, residential: residential);
        final requirements = {for (final r in areaRequirements(c.project, c.results)) r.areaId: r};
        return AlertDialog(
          title: Text(t('wb.title'), style: const TextStyle(fontSize: 15)),
          content: SizedBox(
            width: dialogWidth(ctx, 560),
            child: ScrollBody(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('wb.hint'), style: TextStyle(fontSize: 12, color: Cad.fg70)),
                  _row([
                    NumField(key: const Key('wb_eto'), label: t('wb.etoYear'), value: etoYear, decimals: 0, onChanged: (v) => setState(() => etoYear = v < 0 ? 0 : v)),
                    SpecDropdown<bool>(
                      label: t('wb.use'),
                      value: '$residential',
                      items: const [true, false],
                      labelOf: (v) => t(v ? 'wb.residential' : 'wb.nonResidential'),
                      idOf: (v) => '$v',
                      onChanged: (v) => setState(() => residential = v == 'true'),
                    ),
                  ]),
                  if (wb == null)
                    Text(t('wb.none'), style: TextStyle(fontSize: 12, color: Cad.warning))
                  else ...[
                    Table(
                      defaultColumnWidth: const IntrinsicColumnWidth(),
                      children: [
                        TableRow(children: [_cell(t('rep.area'), bold: true), _cell('m²', bold: true), _cell('PF', bold: true), _cell('IE', bold: true), _cell('ETAF', bold: true)]),
                        for (var i = 0; i < areas.length; i++)
                          TableRow(
                            children: [
                              _cell(areas[i].name.isNotEmpty ? areas[i].name : areas[i].id),
                              _cell(fmt(zones[i].area, 0)),
                              _cell(fmt(zones[i].plantFactor, 2)),
                              _cell(fmt(zones[i].irrigationEfficiency, 2)),
                              _cell(fmt(zones[i].etaf, 2)),
                            ],
                          ),
                      ],
                    ),
                    SectionTitle(t('dens.results')),
                    KV('MAWA', '${fmt(wb.mawa / 1000, 1)} m³/${t('wb.year')}'),
                    KV('ETWU', '${fmt(wb.etwu / 1000, 1)} m³/${t('wb.year')}', color: wb.etwu <= wb.mawa ? Cad.ok : Cad.warning),
                    KV(t('wb.averageEtaf'), '${fmt(wb.averageEtaf, 2)} (≤ ${fmt(wb.etafLimit, 2)})', color: wb.averageEtaf <= wb.etafLimit + 1e-9 ? Cad.ok : Cad.warning),
                    // cycle and soak: the daily depth split so the water soaks in
                    // instead of running off (the soil and slope of each area)
                    SectionTitle(t('wb.cycleSoak')),
                    Table(
                      defaultColumnWidth: const IntrinsicColumnWidth(),
                      children: [
                        TableRow(
                          children: [
                            _cell(t('rep.area'), bold: true),
                            _cell('mm/h', bold: true),
                            _cell('mm', bold: true),
                            _cell(t('wb.cycles'), bold: true),
                            _cell(t('wb.runMin'), bold: true),
                            _cell(t('wb.soakMin'), bold: true),
                          ],
                        ),
                        for (final a in areas)
                          if (requirements[a.id] case final r?)
                            if (soilTable[a.soilKey] case final soil? when r.precipitationMmH > 0 && r.grossDepthMm > 0)
                              () {
                                final cs = cycleAndSoakForSoil(precipitationRateMmH: r.precipitationMmH, depthMm: r.grossDepthMm, texture: soil.texture, slopePct: a.slopePct);
                                return TableRow(
                                  children: [
                                    _cell(a.name.isNotEmpty ? a.name : a.id),
                                    _cell(fmt(r.precipitationMmH, 1)),
                                    _cell(fmt(r.grossDepthMm, 1)),
                                    _cell('${cs.cycles}'),
                                    _cell(fmt(cs.runMinutesPerCycle, 0)),
                                    _cell(cs.cycles > 1 ? fmt(cs.soakMinutes, 0) : '-'),
                                  ],
                                );
                              }(),
                      ],
                    ),
                    if (areas.any((a) => !soilTable.containsKey(a.soilKey))) Text(t('wb.cycleSoakNeeds'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
                  ],
                ],
              ),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('close')))],
        );
      },
    ),
  );
}

/// Middle of the plant factor range of a water use category.
double _plantFactor(String use) {
  final u = PlantWaterUse.values.asNameMap()[use] ?? PlantWaterUse.moderate;
  final (lo, hi) = plantFactorRange(u);
  return (lo + hi) / 2;
}
