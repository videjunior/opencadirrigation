/// Calculators for field machines and methods that are not drawn as a
/// network: the hose-reel travelling gun, surface irrigation (furrows,
/// borders and basins) and the gated pipe that feeds furrows. Each dialog
/// takes the data of its engine module in the project's display units and
/// shows the results and the translated messages as the data change.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/gated_pipe.dart';
import '../../../core/design/surface_irrigation.dart';
import '../../../core/design/traveller.dart';
import '../../../core/hydraulics/friction.dart' show FrictionMethod;
import '../../../core/model/catalog.dart';
import '../../../core/units.dart';
import '../../state/controller.dart';
import '../../theme.dart';
import '../fields.dart';
import 'mechanised_dialogs.dart' show fieldGrid, flowDecimals, messageLines, resultTable;
import 'terrain_dialogs.dart' show dialogWidth;

TextStyle get _hint => TextStyle(fontSize: 11.5, color: Cad.fg60);

/// An explanation above a group of fields, with room for their floating labels.
Widget _hintText(String s) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Text(s, style: _hint),
);

/// The dialog frame shared by the calculators: title, a scrolling body of
/// [dialogWidth] and a Close button (the calculators change nothing in the project).
AlertDialog _frame(BuildContext ctx, ProjectController c, String title, double width, List<Widget> children) => AlertDialog(
  title: Text(title, style: const TextStyle(fontSize: 15)),
  // the body scrolls by itself (ScrollBody): a scrollable AlertDialog asks its
  // content for intrinsic heights, which the LayoutBuilders of the fields and
  // of KV cannot give (an assertion on phones)
  scrollable: false,
  content: SizedBox(
    width: dialogWidth(ctx, width),
    child: ScrollBody(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: children),
    ),
  ),
  actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(c.t('close')))],
);

String _pct(double fraction) => '${fmtUi(fraction * 100, 1)} %';

// ---------------------------------------------------------------- travelling gun

/// Hose-reel travelling gun: lane spacing for the wind, the speed for a
/// target depth (or the depth of a speed), times per lane and per cycle,
/// application rate, hose friction, pressure at the hydrant and power
/// (`core/design/traveller.dart`). A catalogue gun nozzle gives the flow and
/// wetted diameter at the gun pressure; otherwise they are typed.
Future<void> showTravellerCalculator(BuildContext context, ProjectController c) {
  final t = c.t;
  final u = c.units;
  final params = c.project.params;
  final guns = [
    for (final o in c.project.catalog.outlets)
      if (o.enabled && o.kind == OutletKind.gun && o.nozzles.isNotEmpty) o,
  ];
  String? gunId, nozzleId;
  // a 30 m³/h gun at 45 m on 350 m of 90 mm hose: a common mid-size reel
  var flow = 30 / 3600, pressure = 45.0, diameter = 90.0, sector = 360.0;
  var hoseLength = 350.0, hoseMm = 90.0, hoseC = 150.0, driveLoss = 8.0, gunHeight = 0.0, rise = 0.0;
  var wind = WindClass.light;
  var tapered = true;
  var laneSpacing = 0.0, laneLength = 0.0, fieldWidth = 0.0, targetDepth = 25.0, speed = 0.0;
  var setup = 0.5, hoursPerDay = 22.0, efficiency = 70.0, intake = 0.0, minSpeed = 0.0, maxSpeed = 0.0;
  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final gun = guns.where((g) => g.id == gunId).firstOrNull;
        final nozzle = gun?.nozzle(nozzleId);
        final (q, dw) = nozzle != null ? gunPerformance(nozzle, pressure) : (flow, diameter);
        final r = analyzeTraveller(
          TravellerSpec(
            gunFlow: q,
            gunPressureM: pressure,
            wettedDiameterM: dw,
            sectorDeg: sector,
            hoseLengthM: hoseLength,
            hoseInnerMm: hoseMm,
            hoseHazenC: hoseC,
            method: params.frictionMethod,
            kinematicViscosity: params.kinematicViscosity,
            driveLossM: driveLoss,
            gunHeightM: gunHeight,
            groundRiseM: rise,
            wind: wind,
            taperedNozzle: tapered,
            laneSpacingM: laneSpacing,
            laneLengthM: laneLength,
            fieldWidthM: fieldWidth,
            targetDepthMm: targetDepth,
            speedMPerMin: speed,
            setupHours: setup,
            hoursPerDay: hoursPerDay,
            pumpEfficiency: efficiency / 100,
            soilIntakeMmH: intake,
            minSpeedMPerMin: minSpeed,
            maxSpeedMPerMin: maxSpeed,
          ),
        );
        final pd = u.pressure == PressureUnit.bar ? 2 : 1;
        String len(double m, [int d = 1]) => '${fmtUi(u.lengthFromSi(m), d)} ${u.lengthLabel}';
        String pr(double h) => '${fmtUi(u.pressureFromHead(h), pd)} ${u.pressureLabel}';
        final dd = u.depthLabel == 'in' ? 2 : 1;
        final speedUnit = '${u.lengthLabel}/min';
        return _frame(ctx, c, t('trav.title'), 760, [
          _hintText(t('trav.hint')),
          SectionTitle(t('trav.gun')),
          if (guns.isNotEmpty)
            fieldGrid([
              SpecDropdown<OutletSpec>(
                key: const Key('trav_gun'),
                label: t('mech.gunSpec'),
                value: gunId,
                items: guns,
                labelOf: (o) => o.name,
                idOf: (o) => o.id,
                allowNull: true,
                nullLabel: t('trav.typed'),
                onChanged: (v) => setState(() {
                  gunId = v;
                  nozzleId = guns.where((g) => g.id == v).firstOrNull?.nozzles.first.id;
                }),
              ),
              if (gun != null)
                SpecDropdown<NozzleSpec>(
                  key: ValueKey('trav_nozzle_$gunId'),
                  label: t('mech.gunNozzle'),
                  value: nozzleId,
                  items: gun.nozzles,
                  labelOf: (n) => n.name,
                  idOf: (n) => n.id,
                  onChanged: (v) => setState(() => nozzleId = v),
                ),
            ], minWidth: 280),
          fieldGrid([
            NumField(
              key: const Key('trav_flow'),
              label: '${t('mech.gunFlow')} (${u.flowLabel})',
              value: u.flowFromSi(q),
              decimals: flowDecimals(u),
              enabled: nozzle == null,
              onChanged: (v) => setState(() => flow = v > 0 ? u.flowToSi(v) : flow),
            ),
            NumField(
              key: const Key('trav_pressure'),
              label: '${t('trav.gunPressure')} (${u.pressureLabel})',
              value: u.pressureFromHead(pressure),
              onChanged: (v) => setState(() => pressure = v > 0 ? u.pressureToHead(v) : pressure),
            ),
            NumField(
              key: const Key('trav_diameter'),
              label: '${t('trav.wettedDiameter')} (${u.lengthLabel})',
              value: u.lengthFromSi(dw),
              decimals: 1,
              enabled: nozzle == null,
              onChanged: (v) => setState(() => diameter = v > 0 ? u.lengthToSi(v) : diameter),
            ),
            NumField(key: const Key('trav_sector'), label: t('trav.sector'), value: sector, decimals: 0, onChanged: (v) => setState(() => sector = v.clamp(1.0, 360.0).toDouble())),
          ]),
          SectionTitle(t('trav.hose')),
          fieldGrid([
            NumField(
              key: const Key('trav_hose_length'),
              label: '${t('trav.hoseLength')} (${u.lengthLabel})',
              value: u.lengthFromSi(hoseLength),
              decimals: 0,
              onChanged: (v) => setState(() => hoseLength = v > 0 ? u.lengthToSi(v) : hoseLength),
            ),
            NumField(
              key: const Key('trav_hose_bore'),
              label: '${t('trav.hoseBore')} (${u.diameterLabel})',
              value: u.diameterFromSi(hoseMm / 1000),
              decimals: u.diameter == DiameterUnit.inch ? 2 : 0,
              onChanged: (v) => setState(() => hoseMm = v > 0 ? u.diameterToSi(v) * 1000 : hoseMm),
            ),
            if (params.frictionMethod == FrictionMethod.hazenWilliams) NumField(label: t('trav.hoseC'), value: hoseC, decimals: 0, onChanged: (v) => setState(() => hoseC = v > 0 ? v : hoseC)),
            NumField(
              key: const Key('trav_drive_loss'),
              label: '${t('trav.driveLoss')} (${u.pressureLabel})',
              value: u.pressureFromHead(driveLoss),
              onChanged: (v) => setState(() => driveLoss = math.max(0.0, u.pressureToHead(v))),
            ),
            NumField(label: '${t('trav.gunHeight')} (${u.lengthLabel})', value: u.lengthFromSi(gunHeight), onChanged: (v) => setState(() => gunHeight = u.lengthToSi(v))),
            NumField(label: '${t('trav.groundRise')} (${u.lengthLabel})', value: u.lengthFromSi(rise), onChanged: (v) => setState(() => rise = u.lengthToSi(v))),
          ]),
          SectionTitle(t('trav.lanes')),
          fieldGrid([
            SpecDropdown<WindClass>(
              key: const Key('trav_wind'),
              label: t('trav.wind'),
              value: wind.name,
              items: WindClass.values,
              labelOf: (w) => t('trav.wind.${w.name}'),
              idOf: (w) => w.name,
              onChanged: (v) => setState(() => wind = WindClass.values.byName(v!)),
            ),
            SpecDropdown<bool>(
              label: t('trav.nozzleType'),
              value: '$tapered',
              items: const [true, false],
              labelOf: (v) => t(v ? 'trav.tapered' : 'trav.ring'),
              idOf: (v) => '$v',
              onChanged: (v) => setState(() => tapered = v == 'true'),
            ),
            NumField(
              key: const Key('trav_lane_spacing'),
              label: '${t('trav.laneSpacingIn')} (${u.lengthLabel})',
              value: u.lengthFromSi(laneSpacing),
              onChanged: (v) => setState(() => laneSpacing = math.max(0.0, u.lengthToSi(v))),
            ),
            NumField(
              label: '${t('trav.laneLengthIn')} (${u.lengthLabel})',
              value: u.lengthFromSi(laneLength),
              decimals: 0,
              onChanged: (v) => setState(() => laneLength = math.max(0.0, u.lengthToSi(v))),
            ),
            NumField(
              key: const Key('trav_field_width'),
              label: '${t('trav.fieldWidth')} (${u.lengthLabel})',
              value: u.lengthFromSi(fieldWidth),
              decimals: 0,
              onChanged: (v) => setState(() => fieldWidth = math.max(0.0, u.lengthToSi(v))),
            ),
          ]),
          SectionTitle(t('trav.operation')),
          fieldGrid([
            NumField(
              key: const Key('trav_depth'),
              label: '${t('trav.targetDepth')} (${u.depthLabel})',
              value: u.depthFromMm(targetDepth),
              onChanged: (v) => setState(() => targetDepth = math.max(0.0, u.depthToMm(v))),
            ),
            NumField(key: const Key('trav_speed'), label: '${t('trav.speedIn')} ($speedUnit)', value: u.lengthFromSi(speed), onChanged: (v) => setState(() => speed = math.max(0.0, u.lengthToSi(v)))),
            NumField(label: t('trav.setup'), value: setup, onChanged: (v) => setState(() => setup = math.max(0.0, v))),
            NumField(label: t('trav.hoursDay'), value: hoursPerDay, decimals: 1, onChanged: (v) => setState(() => hoursPerDay = v.clamp(0.5, 24.0).toDouble())),
            NumField(label: t('trav.pumpEff'), value: efficiency, decimals: 0, onChanged: (v) => setState(() => efficiency = v.clamp(5.0, 95.0).toDouble())),
            NumField(label: '${t('trav.intake')} (${u.depthRateLabel})', value: u.depthFromMm(intake), onChanged: (v) => setState(() => intake = math.max(0.0, u.depthToMm(v)))),
            NumField(label: '${t('trav.minSpeed')} ($speedUnit)', value: u.lengthFromSi(minSpeed), onChanged: (v) => setState(() => minSpeed = math.max(0.0, u.lengthToSi(v)))),
            NumField(label: '${t('trav.maxSpeed')} ($speedUnit)', value: u.lengthFromSi(maxSpeed), onChanged: (v) => setState(() => maxSpeed = math.max(0.0, u.lengthToSi(v)))),
          ]),
          SectionTitle(t('dens.results')),
          KV(
            t('trav.laneSpacing'),
            t('trav.spacingValue', {'s': len(r.laneSpacingM), 'p': fmtUi(r.laneSpacingPct, 0), 'r': fmtUi(r.recommendedPct, 0)}),
            color: r.warnings.contains('traveller_lane_wide') ? Cad.warning : null,
          ),
          KV(t('trav.lanesCount'), '${r.lanes}'),
          KV(t('trav.runLength'), len(r.laneLengthM, 0)),
          KV(
            t('trav.speed'),
            r.speedMPerMin > 0 ? '${fmtUi(u.lengthFromSi(r.speedMPerMin), 2)} $speedUnit (${fmtUi(u.lengthFromSi(r.speedMPerMin * 60), 0)} ${u.lengthLabel}/h)' : '-',
            color: r.warnings.contains('traveller_speed_range') ? Cad.warning : null,
          ),
          KV(t('mech.depth'), '${fmtUi(u.depthFromMm(r.grossDepthMm), dd)} ${u.depthLabel}'),
          KV(t('trav.travelHours'), '${fmtUi(r.travelHours, 1)} h'),
          KV(t('trav.laneHours'), '${fmtUi(r.laneHours, 1)} h'),
          KV(t('trav.cycle'), t('trav.cycleValue', {'h': fmtUi(r.cycleHours, 1), 'd': fmtUi(r.cycleDays, 1)})),
          KV(t('trav.areaLane'), '${fmtUi(u.areaFromSi(r.areaPerLaneM2), 2)} ${u.areaLabel}'),
          KV(t('trav.volumeLane'), '${fmtUi(u.volumeFromM3(r.volumePerLaneM3), 0)} ${u.volumeLabel}'),
          KV(t('trav.appRate'), '${fmtUi(u.depthFromMm(r.applicationRateMmH), dd)} ${u.depthRateLabel}', color: r.warnings.contains('traveller_app_rate') ? Cad.warning : null),
          KV(t('trav.hoseFriction'), pr(r.hoseFrictionM)),
          KV(t('trav.hoseVelocity'), '${fmtUi(u.velocityFromSi(r.hoseVelocity), 2)} ${u.velocityLabel}'),
          KV(t('trav.inlet'), pr(r.inletHeadM)),
          KV(t('trav.power'), '${fmtUi(r.hydraulicPowerKw, 2)} / ${fmtUi(r.shaftPowerKw, 2)} kW'),
          SectionTitle(t('rep.warnings')),
          ...messageLines(c, r.warnings),
        ]);
      },
    ),
  );
}

// ---------------------------------------------------------------- surface irrigation

/// Typical Manning n of a system: furrows (FAO 45 §4.3) and borders or
/// basins with a close-growing crop.
double _manningOf(SurfaceSystem s) => s == SurfaceSystem.furrow ? 0.04 : 0.15;

/// Surface irrigation by the volume balance of FAO Irrigation and Drainage
/// Paper 45 (`core/design/surface_irrigation.dart`): design (the inflow of
/// best application efficiency and its cutoff for the required depth) or the
/// evaluation of a given inflow and cutoff, for furrows, open-end borders
/// and level basins with an NRCS intake family or typed Kostiakov-Lewis
/// parameters.
Future<void> showSurfaceIrrigationCalculator(BuildContext context, ProjectController c) {
  final t = c.t;
  final u = c.units;
  var system = SurfaceSystem.furrow;
  var length = 200.0, slopePct = 0.1, manningN = 0.04, spacing = 0.75, family = 0.5;
  var later = false, typedIntake = false;
  // the first-irrigation furrow of the FAO 45 design example (§5.4.4), per minute
  var k = 0.00346, a = 0.388, f0 = 0.000057;
  var requiredMm = 80.0, cutoffMin = 450.0, maxVelocity = 13 / 60, fieldWidth = 0.0;
  var design = true;
  var furrowInflow = 0.6e-3, widthInflow = 5e-3;
  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final furrow = system == SurfaceSystem.furrow;
        final intake = typedIntake ? KostiakovLewis.perMinute(k: k, a: a, f0: f0) : (furrow ? nrcsFurrowIntake(family, later: later) : nrcsBorderIntake(family, later: later));
        final spec = SurfaceSpec(system: system, lengthM: length, intake: intake, slope: slopePct / 100, manningN: manningN, furrowSpacingM: spacing);
        final inflow = furrow ? furrowInflow : widthInflow;
        final SurfaceDesign? d = design ? designSurface(spec, requiredDepthM: requiredMm / 1000, maxVelocity: maxVelocity) : null;
        final e = design ? d!.best : evaluateSurface(spec, inflow: inflow, cutoffS: cutoffMin * 60, requiredDepthM: requiredMm / 1000);
        final warnings = design ? d!.warnings : e!.warnings;
        // a flow per furrow, or per unit of width in the display units
        final perWidth = u.lengthToSi(1);
        String qLabel() => furrow ? u.flowLabel : '${u.flowLabel}/${u.lengthLabel}';
        double qShown(double q) => furrow ? u.flowFromSi(q) : u.flowFromSi(q) * perWidth;
        double qSi(double v) => furrow ? u.flowToSi(v) : u.flowToSi(v) / perWidth;
        String q(double v) => '${fmtUi(qShown(v), flowDecimals(u, small: true))} ${qLabel()}';
        final dd = u.depthLabel == 'in' ? 2 : 1;
        String depth(double m) => '${fmtUi(u.depthFromMm(m * 1000), dd)} ${u.depthLabel}';
        String minutes(double s) => s.isFinite ? '${fmtUi(s / 60, 0)} min' : t('surf.incomplete');
        final families = [for (final f in nrcsIntakeFamiliesInitial) f.family];
        // whole furrows across the field, or the field width of borders
        final count = fieldWidth > 0 && spacing > 0 ? math.max(1, (fieldWidth / spacing).round()) : 0;
        return _frame(ctx, c, t('surf.title'), 760, [
          _hintText(t('surf.hint')),
          fieldGrid([
            SpecDropdown<SurfaceSystem>(
              key: const Key('surf_system'),
              label: t('surf.system'),
              value: system.name,
              items: SurfaceSystem.values,
              labelOf: (s) => t('surf.sys.${s.name}'),
              idOf: (s) => s.name,
              onChanged: (v) => setState(() {
                system = SurfaceSystem.values.byName(v!);
                manningN = _manningOf(system);
              }),
            ),
            SpecDropdown<bool>(
              key: const Key('surf_mode'),
              label: t('surf.mode'),
              value: '$design',
              items: const [true, false],
              labelOf: (v) => t(v ? 'surf.mode.design' : 'surf.mode.evaluate'),
              idOf: (v) => '$v',
              onChanged: (v) => setState(() => design = v == 'true'),
            ),
          ], minWidth: 260),
          fieldGrid([
            NumField(
              key: const Key('surf_length'),
              label: '${t('surf.length')} (${u.lengthLabel})',
              value: u.lengthFromSi(length),
              decimals: 0,
              onChanged: (v) => setState(() => length = v > 0 ? u.lengthToSi(v) : length),
            ),
            if (system != SurfaceSystem.basin)
              NumField(key: const Key('surf_slope'), label: t('surf.slope'), value: slopePct, decimals: 3, onChanged: (v) => setState(() => slopePct = math.max(0.0, v))),
            NumField(key: ValueKey('surf_n_${system.name}'), label: t('surf.manning'), value: manningN, decimals: 3, onChanged: (v) => setState(() => manningN = v > 0 ? v : manningN)),
            if (furrow)
              NumField(
                key: const Key('surf_spacing'),
                label: '${t('surf.spacing')} (${u.lengthLabel})',
                value: u.lengthFromSi(spacing),
                onChanged: (v) => setState(() => spacing = v > 0 ? u.lengthToSi(v) : spacing),
              ),
            NumField(
              key: const Key('surf_required'),
              label: '${t('surf.required')} (${u.depthLabel})',
              value: u.depthFromMm(requiredMm),
              onChanged: (v) => setState(() => requiredMm = math.max(0.0, u.depthToMm(v))),
            ),
            NumField(
              label: '${t('surf.fieldWidth')} (${u.lengthLabel})',
              value: u.lengthFromSi(fieldWidth),
              decimals: 0,
              onChanged: (v) => setState(() => fieldWidth = math.max(0.0, u.lengthToSi(v))),
            ),
          ]),
          SectionTitle(t('surf.infiltration')),
          SwitchListTile(
            key: const Key('surf_typed'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(t('surf.typedIntake'), style: const TextStyle(fontSize: 12)),
            value: typedIntake,
            onChanged: (v) => setState(() => typedIntake = v),
          ),
          if (typedIntake)
            fieldGrid([
              NumField(label: furrow ? 'k (m³/m/min^a)' : 'k (m/min^a)', value: k, decimals: 6, onChanged: (v) => setState(() => k = v > 0 ? v : k)),
              NumField(label: 'a', value: a, decimals: 3, onChanged: (v) => setState(() => a = v.clamp(0.01, 1.0).toDouble())),
              NumField(label: furrow ? 'f0 (m³/m/min)' : 'f0 (m/min)', value: f0, decimals: 7, onChanged: (v) => setState(() => f0 = math.max(0.0, v))),
            ])
          else
            fieldGrid([
              SpecDropdown<double>(
                key: const Key('surf_family'),
                label: t('surf.family'),
                value: '$family',
                items: families,
                labelOf: (f) => '${fmtUi(f, 2)} in/h (${fmtUi(f * 25.4, 1)} mm/h)',
                idOf: (f) => '$f',
                onChanged: (v) => setState(() => family = double.parse(v!)),
              ),
              SpecDropdown<bool>(
                label: t('surf.irrigation'),
                value: '$later',
                items: const [false, true],
                labelOf: (v) => t(v ? 'surf.later' : 'surf.first'),
                idOf: (v) => '$v',
                onChanged: (v) => setState(() => later = v == 'true'),
              ),
            ], minWidth: 260),
          SectionTitle(t(design ? 'surf.mode.design' : 'surf.mode.evaluate')),
          fieldGrid([
            if (design)
              NumField(
                key: const Key('surf_max_velocity'),
                label: '${t('surf.maxVelocity')} (${u.lengthLabel}/min)',
                value: u.lengthFromSi(maxVelocity * 60),
                decimals: 1,
                onChanged: (v) => setState(() => maxVelocity = v > 0 ? u.lengthToSi(v) / 60 : maxVelocity),
              )
            else ...[
              NumField(
                key: const Key('surf_inflow'),
                label: '${t(furrow ? 'surf.inflow' : 'surf.inflowWidth')} (${qLabel()})',
                value: qShown(inflow),
                decimals: flowDecimals(u, small: true),
                onChanged: (v) => setState(() {
                  if (v <= 0) return;
                  if (furrow) {
                    furrowInflow = qSi(v);
                  } else {
                    widthInflow = qSi(v);
                  }
                }),
              ),
              NumField(key: const Key('surf_cutoff'), label: t('surf.cutoff'), value: cutoffMin, decimals: 0, onChanged: (v) => setState(() => cutoffMin = v > 0 ? v : cutoffMin)),
            ],
          ]),
          SectionTitle(t('dens.results')),
          if (e == null)
            Text(t('warn.surface_no_advance'), style: TextStyle(fontSize: 12, color: Cad.warning))
          else ...[
            KV(t(design ? 'surf.best' : (furrow ? 'surf.inflow' : 'surf.inflowWidth')), q(e.inflow)),
            if (design) KV(t('surf.inflowRange'), '${fmtUi(qShown(d!.minInflow), flowDecimals(u, small: true))} – ${q(d.maxInflow)}'),
            KV(t('surf.advance'), minutes(e.advanceS), color: e.complete ? null : Cad.warning),
            KV(t('surf.cutoffResult'), minutes(e.cutoffS)),
            if (system == SurfaceSystem.border) KV(t('surf.recession'), minutes(e.recessionS)),
            KV(t('surf.inletDepth'), depth(e.inletDepthM)),
            KV(t('surf.efficiency'), _pct(e.efficiency), color: e.efficiency >= 0.6 ? Cad.ok : Cad.warning),
            KV(t('surf.requirementEff'), _pct(e.requirementEfficiency), color: e.requirementEfficiency >= 0.95 ? Cad.ok : Cad.warning),
            KV(t('surf.du'), _pct(e.lowQuarterDu)),
            KV(t('surf.deepPerc'), _pct(e.deepPercolationRatio)),
            KV(t('surf.tailwater'), _pct(e.tailwaterRatio)),
            KV(
              t('surf.depths'),
              '${fmtUi(u.depthFromMm(e.meanDepthM * 1000), dd)} / ${fmtUi(u.depthFromMm(e.minDepthM * 1000), dd)} / ${fmtUi(u.depthFromMm(e.maxDepthM * 1000), dd)} ${u.depthLabel}',
            ),
            KV(
              t(furrow ? 'surf.appliedFurrow' : 'surf.appliedWidth'),
              furrow ? '${fmtUi(u.volumeFromM3(e.appliedM3), 2)} ${u.volumeLabel}' : '${fmtUi(u.volumeFromM3(e.appliedM3) * perWidth, 2)} ${u.volumeLabel}/${u.lengthLabel}',
            ),
            if (fieldWidth > 0)
              KV(
                t('surf.totalFlow'),
                furrow
                    ? '${fmtUi(u.flowFromSi(e.inflow * count), flowDecimals(u))} ${u.flowLabel} ($count ${t('surf.furrows')})'
                    : '${fmtUi(u.flowFromSi(e.inflow * fieldWidth), flowDecimals(u))} ${u.flowLabel}',
              ),
          ],
          if (design && d!.rows.isNotEmpty) ...[
            SectionTitle(t('surf.rows')),
            resultTable(
              [
                '${t(furrow ? 'surf.inflow' : 'surf.inflowWidth')} (${qLabel()})',
                '${t('surf.advance')} (min)',
                '${t('surf.cutoffResult')} (min)',
                'Ea (%)',
                'DU (%)',
                '${t('surf.tailwater')} (%)',
                '${t('surf.deepPerc')} (%)',
              ],
              [
                for (final row in d.rows)
                  [
                    fmtUi(qShown(row.inflow), flowDecimals(u, small: true)),
                    row.advanceS.isFinite ? fmtUi(row.advanceS / 60, 0) : '-',
                    row.cutoffS.isFinite ? fmtUi(row.cutoffS / 60, 0) : '-',
                    fmtUi(row.efficiency * 100, 1),
                    fmtUi(row.lowQuarterDu * 100, 1),
                    fmtUi(row.tailwaterRatio * 100, 1),
                    fmtUi(row.deepPercolationRatio * 100, 1),
                  ],
              ],
              warn: [for (final row in d.rows) !row.cutoffS.isFinite],
              bold: [for (final row in d.rows) e != null && (row.inflow - e.inflow).abs() < 1e-12],
              key: const Key('surf_rows'),
            ),
          ],
          SectionTitle(t('rep.warnings')),
          ...messageLines(c, warnings),
        ]);
      },
    ),
  );
}

// ---------------------------------------------------------------- gated pipe

/// Gated pipe feeding furrows (`core/design/gated_pipe.dart`): the opening
/// of every gate, or the standard hole, so each furrow receives its flow
/// with the friction and the slope gate by gate, and the least inlet head
/// that serves them all.
Future<void> showGatedPipeCalculator(BuildContext context, ProjectController c) {
  final t = c.t;
  final u = c.units;
  final params = c.project.params;
  var outlets = 40, spacing = 0.76, flow = 1e-3, first = -1.0, pipeMm = 250.0, hazenC = 150.0, slopePct = 0.0, inletHead = 0.0, cd = 0.61;
  var fixedHoles = false;
  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final r = designGatedPipe(
          GatedPipeSpec(
            outlets: outlets,
            outletSpacingM: spacing,
            targetFlow: flow,
            firstOutletM: first,
            pipeInnerMm: pipeMm,
            hazenC: hazenC,
            method: params.frictionMethod,
            kinematicViscosity: params.kinematicViscosity,
            slope: slopePct / 100,
            inletHeadM: inletHead,
            dischargeCoefficient: cd,
            fixedHoles: fixedHoles,
          ),
        );
        // the heads of a gated pipe are a few decimetres
        final pd = switch (u.pressure) {
          PressureUnit.mH2O => 3,
          PressureUnit.kPa => 2,
          PressureUnit.bar => 4,
          PressureUnit.psi => 3,
          PressureUnit.ftH2O => 2,
        };
        String pr(double h) => '${fmtUi(u.pressureFromHead(h), pd)} ${u.pressureLabel}';
        final inch = u.diameter == DiameterUnit.inch;
        String dia(double mm) => fmtUi(u.diameterFromSi(mm / 1000), inch ? 3 : 1);
        final areaUnit = inch ? 'in²' : 'mm²';
        String q(double v) => fmtUi(u.flowFromSi(v), flowDecimals(u, small: true));
        return _frame(ctx, c, t('gate.title'), 760, [
          _hintText(t('gate.hint')),
          fieldGrid([
            NumField(key: const Key('gate_outlets'), label: t('gate.outlets'), value: outlets.toDouble(), decimals: 0, onChanged: (v) => setState(() => outlets = v.round().clamp(1, 2000))),
            NumField(
              key: const Key('gate_spacing'),
              label: '${t('gate.spacing')} (${u.lengthLabel})',
              value: u.lengthFromSi(spacing),
              onChanged: (v) => setState(() => spacing = v > 0 ? u.lengthToSi(v) : spacing),
            ),
            NumField(
              key: const Key('gate_flow'),
              label: '${t('gate.flow')} (${u.flowLabel})',
              value: u.flowFromSi(flow),
              decimals: flowDecimals(u, small: true),
              onChanged: (v) => setState(() => flow = v > 0 ? u.flowToSi(v) : flow),
            ),
            NumField(label: '${t('gate.first')} (${u.lengthLabel})', value: first < 0 ? -1 : u.lengthFromSi(first), onChanged: (v) => setState(() => first = v < 0 ? -1 : u.lengthToSi(v))),
            NumField(
              key: const Key('gate_bore'),
              label: '${t('gate.pipeBore')} (${u.diameterLabel})',
              value: u.diameterFromSi(pipeMm / 1000),
              decimals: inch ? 2 : 0,
              onChanged: (v) => setState(() => pipeMm = v > 0 ? u.diameterToSi(v) * 1000 : pipeMm),
            ),
            if (params.frictionMethod == FrictionMethod.hazenWilliams) NumField(label: t('gate.hazenC'), value: hazenC, decimals: 0, onChanged: (v) => setState(() => hazenC = v > 0 ? v : hazenC)),
            NumField(key: const Key('gate_slope'), label: t('gate.slope'), value: slopePct, decimals: 3, onChanged: (v) => setState(() => slopePct = v)),
            NumField(
              key: const Key('gate_inlet'),
              label: '${t('gate.inletHead')} (${u.pressureLabel})',
              value: u.pressureFromHead(inletHead),
              decimals: pd,
              onChanged: (v) => setState(() => inletHead = math.max(0.0, u.pressureToHead(v))),
            ),
            NumField(label: t('gate.cd'), value: cd, decimals: 2, onChanged: (v) => setState(() => cd = v.clamp(0.1, 1.0).toDouble())),
          ]),
          // punched holes that stay open: the flows of the holes, not the targets (AGR-23)
          SwitchListTile(
            key: const Key('gate_fixed'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(t('gate.fixedHoles'), style: const TextStyle(fontSize: 12)),
            subtitle: Text(t('gate.fixedHolesHint'), style: TextStyle(fontSize: 10.5, color: Cad.fg54)),
            value: fixedHoles,
            onChanged: (v) => setState(() => fixedHoles = v),
          ),
          SectionTitle(t('dens.results')),
          KV(t('gate.inletUsed'), pr(r.inletHeadM), color: r.inletHeadOk ? Cad.ok : Cad.warning),
          KV(t('gate.inletMin'), pr(r.minInletHeadM)),
          KV(t('gate.total'), '${fmtUi(u.flowFromSi(r.totalFlow), flowDecimals(u))} ${u.flowLabel}'),
          if (r.fixedHoles) ...[
            KV(t('gate.deliveredTotal'), '${fmtUi(u.flowFromSi(r.deliveredTotalFlow), flowDecimals(u))} ${u.flowLabel}', color: r.deliveredTotalFlow > r.totalFlow * 1.05 ? Cad.warning : null),
            KV(t('gate.uniformity'), 'CU ${fmtUi(r.flowCu, 1)} % · ${t('gate.minOverMean')} ${fmtUi(r.minOverMeanFlow, 2)}', color: r.flowCu < 90 ? Cad.warning : null),
          ],
          KV(t('gate.friction'), pr(r.frictionLossM)),
          KV(t('gate.elevation'), pr(r.elevationGainM)),
          KV(t('gate.velocity'), '${fmtUi(u.velocityFromSi(r.inletVelocity), 2)} ${u.velocityLabel}'),
          if (r.gates.isNotEmpty) ...[
            SectionTitle(t('gate.gates')),
            resultTable(
              [
                t('gate.gate'),
                '${t('mech.distance')} (${u.lengthLabel})',
                '${t('gate.pipeFlow')} (${u.flowLabel})',
                '${t('gate.head')} (${u.pressureLabel})',
                '${t('gate.target')} (${u.flowLabel})',
                '${t('gate.area')} ($areaUnit)',
                '${t('gate.diameter')} (${u.diameterLabel})',
                '${t('gate.hole')} (${u.diameterLabel})',
                '${t('gate.opening')} (%)',
                '${t('gate.fullFlow')} (${u.flowLabel})',
                if (r.fixedHoles) '${t('gate.delivered')} (${u.flowLabel})',
              ],
              [
                for (final g in r.gates)
                  [
                    '${g.index}',
                    fmtUi(u.lengthFromSi(g.distanceM), 2),
                    q(g.pipeFlow),
                    fmtUi(u.pressureFromHead(g.headM), pd),
                    q(g.targetFlow),
                    fmtUi(inch ? g.areaMm2 / 645.16 : g.areaMm2, inch ? 3 : 0),
                    dia(g.diameterMm),
                    g.holeMm > 0 ? dia(g.holeMm) : '-',
                    g.holeMm > 0 ? fmtUi(g.openingPct, 0) : '-',
                    g.holeMm > 0 ? q(g.fullFlow) : '-',
                    if (r.fixedHoles) q(g.deliveredFlow),
                  ],
              ],
              warn: [for (final g in r.gates) g.holeMm <= 0 || g.headM <= 0],
              key: const Key('gate_table'),
            ),
          ],
          SectionTitle(t('rep.warnings')),
          ...messageLines(c, r.warnings),
        ]);
      },
    ),
  );
}
