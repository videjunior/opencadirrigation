import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/design/agronomy.dart';
import '../../core/design/area_water.dart';
import '../../core/design/crops.dart';
import '../../core/design/effective_rain.dart';
import '../../core/design/pivot.dart' show PivotKind;
import '../../core/design/soils.dart';
import '../../core/design/valve_in_head.dart';
import '../../core/model/catalog.dart';
import '../../core/model/entities.dart';
import '../../core/model/geometry.dart';
import '../../core/units.dart';
import '../state/controller.dart';
import '../theme.dart';
import '../tools/tools.dart';
import 'dialogs/mechanised_dialogs.dart';
import 'edit_fields.dart';
import 'fields.dart';

class PropertiesPanel extends StatelessWidget {
  const PropertiesPanel({super.key, required this.c});
  final ProjectController c;

  /// The label of a catalogue item the list does not offer (UI-10): its name
  /// marked "(switched off)" while it is in the catalogue, else its id
  /// marked "(not in the catalogue)" — never another item in its place.
  String Function(String) _missing(String? Function(String id) nameOf) => (id) {
    final n = nameOf(id);
    return n == null ? '$id ${c.t('props.notInCatalog')}' : '$n ${c.t('props.disabled')}';
  };

  /// A fraction (0–1) as a field (UI-12): 85 typed is read as 85 % (0.85),
  /// and a value out of [min]..[max] is cut to the range with a message, not
  /// in silence.
  Widget _fraction(String label, double value, double min, double max, void Function(double v) apply, {Key? key}) => NumField(
    key: key,
    label: label.contains('0–1') ? label : '$label (0–1)',
    value: value,
    onChanged: (x) {
      final f = x > 1 && x <= 100 ? x / 100 : x;
      final cut = f.clamp(min, max).toDouble();
      if (cut != f) c.notify(c.t('ui.fractionCut', {'v': fmtUi(f, 2), 'r': '${fmtUi(min, 2)}–${fmtUi(max, 2)}', 'n': fmtUi(cut, 2)}));
      apply(cut);
    },
  );

  /// The length of a line, an open polyline or a pipe as a field: the last
  /// vertex moves along the last segment (what is joined to it goes along
  /// when "Keep connections" is on), so an exact length can be typed and
  /// corrected later, also without a keyboard command.
  Widget _lengthField(Entity e, List<Pt> pts) {
    final t = c.t, u = c.units;
    return NumField(
      key: const Key('props_length'),
      label: '${t('props.length')} (${u.lengthLabel})',
      value: u.lengthFromSi(polylineLength(pts)),
      onChanged: (v) {
        final end = endForLength(pts, u.lengthToSi(v));
        if (end == null) {
          c.notify(t('props.lengthNo'));
          return;
        }
        c.setGrip(e.id, pts.length - 1, end, keepConnections: c.toolSettings.keepConnections);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = c.t;
    final u = c.units;
    if (c.selection.isEmpty) return _toolDefaults(context);
    if (c.selection.length > 1) return _batch(context);
    final e = c.selectedEntity;
    if (e == null) return Center(child: Text(t('props.none')));
    final cat = c.project.catalog;
    final locked = c.project.isLocked(e.layer);
    final items = <Widget>[
      Row(
        children: [
          Expanded(
            child: Text(t('tool.${ProjectController.toolKeyOf(e)}'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          IconButton(icon: const Icon(Icons.center_focus_strong, size: 16), tooltip: t('props.zoomTo'), onPressed: () => c.zoomToEntity(e.id)),
          IconButton(icon: const Icon(Icons.delete_outline, size: 16), tooltip: t('edit.delete'), onPressed: c.deleteSelected),
        ],
      ),
      if (locked) Text(t('props.locked'), style: TextStyle(fontSize: 11, color: Cad.amber)),
      TextFieldRow(label: t('props.name'), value: e.name, onChanged: (v) => c.mutate(() => e.name = v, invalidateResults: false)),
      _layerField(e),
    ];
    void set(void Function() fn, {bool inv = true}) => c.mutate(fn, invalidateResults: inv);
    String pLabel(String k) => '${t(k)} (${u.pressureLabel})';
    String qLabel(String k) => '${t(k)} (${u.flowLabel})';
    String lLabel(String k) => '${t(k)} (${u.lengthLabel})';
    // a length in metres in the display unit (ft with US units); [nonPositive]
    // gives what a value <= 0 becomes (null: the value is kept as it is)
    Widget len(String key, double m, void Function(double m) apply, {bool inv = true, double? Function()? nonPositive}) => NumField(
      label: lLabel(key),
      value: u.lengthFromSi(m),
      onChanged: (x) {
        final v = x <= 0 && nonPositive != null ? nonPositive() : u.lengthToSi(x);
        if (v != null) set(() => apply(v), inv: inv);
      },
    );

    switch (e) {
      case PipeEntity p:
        items.addAll([
          KV(t('props.scope'), t('scope.${p.scope.name}')),
          _lengthField(p, p.points),
          SpecDropdown<PipeSpec>(
            missingLabel: _missing((id) => cat.pipe(id)?.name),
            label: t('props.pipe'),
            value: p.pipeSpecId,
            items: cat.pipesFor(p.scope == HydraulicScope.zone ? PipeUsage.zone : PipeUsage.mainline),
            labelOf: (s) => s.name,
            idOf: (s) => s.id,
            allowNull: true,
            nullLabel: t('auto'),
            onChanged: (v) => set(() {
              p.pipeSpecId = v;
              // a pipe chosen is a pipe kept: "Automatic" sizes it again
              p.computerSized = v == null;
            }),
          ),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(t('props.auto'), style: const TextStyle(fontSize: 12)),
            value: p.computerSized,
            onChanged: (v) => set(() => p.computerSized = v),
          ),
          len('ui.depth', p.depth, (v) => p.depth = v),
        ]);
      case SpraylineEntity s:
        final outlet = cat.outlet(s.outletSpecId);
        items.addAll([
          KV(t('props.length'), '${fmt(u.lengthFromSi(s.length))} ${u.lengthLabel}'),
          KV(t('props.outlets'), '${s.outletCount}'),
          SpecDropdown<PipeSpec>(
            missingLabel: _missing((id) => cat.pipe(id)?.name),
            label: t('props.pipe'),
            value: s.pipeSpecId,
            items: cat.pipesFor(PipeUsage.lateral),
            labelOf: (x) => x.name,
            idOf: (x) => x.id,
            allowNull: true,
            nullLabel: t('auto'),
            onChanged: (v) => set(() {
              s.pipeSpecId = v;
              s.computerSized = v == null;
            }),
          ),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(t('props.auto'), style: const TextStyle(fontSize: 12)),
            value: s.computerSized,
            onChanged: (v) => set(() => s.computerSized = v),
          ),
          SpecDropdown<OutletSpec>(
            missingLabel: _missing((id) => cat.outlet(id)?.name),
            label: t('props.outlet'),
            value: s.outletSpecId,
            items: cat.outlets.where((o) => o.enabled).toList(),
            labelOf: (x) => x.name,
            idOf: (x) => x.id,
            onChanged: (v) => set(() {
              s.outletSpecId = v ?? s.outletSpecId;
              s.nozzleId = cat.outlet(v)?.nozzles.firstOrNull?.id;
            }),
          ),
          if (outlet != null)
            SpecDropdown<NozzleSpec>(
              missingLabel: _missing((id) => null),
              label: t('props.nozzle'),
              value: s.nozzleId,
              items: outlet.nozzles,
              labelOf: (x) => x.name,
              idOf: (x) => x.id,
              onChanged: (v) => set(() => s.nozzleId = v),
            ),
          NumField(label: pLabel('props.head'), value: u.pressureFromHead(s.headM), onChanged: (v) => set(() => s.headM = u.pressureToHead(v))),
          NumField(label: lLabel('props.spacing'), value: u.lengthFromSi(s.spacing), onChanged: (v) => set(() => s.spacing = v > 0 ? u.lengthToSi(v) : s.spacing)),
          NumField(label: lLabel('props.offset'), value: u.lengthFromSi(s.offset), onChanged: (v) => set(() => s.offset = u.lengthToSi(v))),
          NumField(label: t('props.arc'), value: s.arcDeg, onChanged: (v) => set(() => s.arcDeg = v)),
          len('ui.riser', s.riserHeight, (v) => s.riserHeight = v),
          len('ui.depth', s.depth, (v) => s.depth = v),
          ..._envelope(e.id),
        ]);
      case TapeEntity tp:
        items.addAll([
          KV(t('props.length'), '${fmt(u.lengthFromSi(tp.length))} ${u.lengthLabel}'),
          SpecDropdown<TapeSpec>(
            missingLabel: _missing((id) => cat.tape(id)?.name),
            label: t('props.tape'),
            value: tp.tapeSpecId,
            items: cat.tapes.where((x) => x.enabled).toList(),
            labelOf: (x) => x.name,
            idOf: (x) => x.id,
            onChanged: (v) => set(() => tp.tapeSpecId = v ?? tp.tapeSpecId),
          ),
          NumField(label: pLabel('props.inlet'), value: u.pressureFromHead(tp.inletHeadM), onChanged: (v) => set(() => tp.inletHeadM = u.pressureToHead(v))),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(t('props.regulated'), style: const TextStyle(fontSize: 12)),
            value: tp.regulated,
            onChanged: (v) => set(() => tp.regulated = v),
          ),
          NumField(label: pLabel('props.submainMin'), value: u.pressureFromHead(tp.submainMinHeadM), onChanged: (v) => set(() => tp.submainMinHeadM = u.pressureToHead(v)), enabled: tp.regulated),
          len('ui.depth', tp.depth, (v) => tp.depth = v),
          NumField(label: qLabel('props.flushingFlow'), value: u.flowFromSi(tp.flushingFlow), onChanged: (v) => set(() => tp.flushingFlow = u.flowToSi(v))),
          ..._envelope(e.id),
        ]);
      case OutletEntity o:
        final outlet = cat.outlet(o.outletSpecId);
        final nozzle = outlet?.nozzle(o.nozzleId);
        items.addAll([
          KV(t('props.scope'), t('scope.${o.scope.name}')),
          SpecDropdown<OutletSpec>(
            missingLabel: _missing((id) => cat.outlet(id)?.name),
            label: t('props.outlet'),
            value: o.outletSpecId,
            items: cat.outlets.where((x) => x.enabled).toList(),
            labelOf: (x) => x.name,
            idOf: (x) => x.id,
            onChanged: (v) => set(() {
              o.outletSpecId = v ?? o.outletSpecId;
              o.nozzleId = cat.outlet(v)?.nozzles.firstOrNull?.id;
            }),
          ),
          if (outlet != null)
            SpecDropdown<NozzleSpec>(
              missingLabel: _missing((id) => null),
              label: t('props.nozzle'),
              value: o.nozzleId,
              items: outlet.nozzles,
              labelOf: (x) => x.name,
              idOf: (x) => x.id,
              onChanged: (v) => set(() => o.nozzleId = v),
            ),
          NumField(label: pLabel('props.head'), value: u.pressureFromHead(o.headM), onChanged: (v) => set(() => o.headM = u.pressureToHead(v))),
          if (nozzle != null) KV(t('result.flow'), '${fmt(u.flowFromSi(nozzle.curve.flow(o.headM)))} ${u.flowLabel}'),
          if (nozzle != null && nozzle.curve.radiusA > 0) KV(t('props.radius'), '${fmt(u.lengthFromSi(nozzle.curve.radius(o.headM)))} ${u.lengthLabel}'),
          NumField(label: t('props.arc'), value: o.arcDeg, onChanged: (v) => set(() => o.arcDeg = v)),
          NumField(label: t('props.orientation'), value: o.orientationDeg, onChanged: (v) => set(() => o.orientationDeg = v, inv: false)),
          len('ui.riser', o.riserHeight, (v) => o.riserHeight = v),
          // valve-in-head: its station and the system flows that run it
          if (o.scope == HydraulicScope.mainline) ...[
            TextFieldRow(key: const Key('vih_station'), label: t('props.vihStation'), value: o.zoneName, onChanged: (x) => set(() => o.zoneName = x)),
            KV(t('props.vihFlows'), _vihFlows(o)),
            Text(t('props.vihHint'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
          ],
        ]);
      case ControlValveEntity v:
        items.addAll([
          TextFieldRow(label: t('props.zone'), value: v.zoneName, onChanged: (x) => set(() => v.zoneName = x, inv: false)),
          SpecDropdown<ValveSpec>(
            missingLabel: _missing((id) => cat.valve(id)?.name),
            label: t('props.valve'),
            value: v.valveSpecId,
            items: cat.valves.where((x) => x.enabled && x.kind == ValveKind.control).toList(),
            labelOf: (x) => x.name,
            idOf: (x) => x.id,
            allowNull: true,
            onChanged: (x) => set(() => v.valveSpecId = x),
          ),
          NumField(
            label: pLabel('props.fixedHead'),
            value: v.fixedDownstreamHeadM == null ? 0 : u.pressureFromHead(v.fixedDownstreamHeadM!),
            onChanged: (x) => set(() => v.fixedDownstreamHeadM = x <= 0 ? null : u.pressureToHead(x)),
          ),
          len('ui.depth', v.depth, (x) => v.depth = x),
        ]);
      case WaterSupplyEntity w:
        items.addAll([
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(t('props.calc'), style: const TextStyle(fontSize: 12)),
            value: w.calculatePressure,
            onChanged: (x) => set(() => w.calculatePressure = x),
          ),
          NumField(label: pLabel('props.designHead'), value: u.pressureFromHead(w.designHeadM), enabled: !w.calculatePressure, onChanged: (x) => set(() => w.designHeadM = u.pressureToHead(x))),
          NumField(label: pLabel('props.maxHead'), value: u.pressureFromHead(w.maxHeadM), onChanged: (x) => set(() => w.maxHeadM = u.pressureToHead(x))),
          NumField(label: qLabel('props.designFlow'), value: u.flowFromSi(w.designFlow), onChanged: (x) => set(() => w.designFlow = u.flowToSi(x))),
          NumField(label: qLabel('props.maxFlow'), value: u.flowFromSi(w.maxFlow), onChanged: (x) => set(() => w.maxFlow = u.flowToSi(x))),
          NumField(label: lLabel('ui.waterLevel'), value: u.lengthFromSi(w.waterLevelOffsetM), signed: true, onChanged: (x) => set(() => w.waterLevelOffsetM = u.lengthToSi(x))),
        ]);
      case PumpEntity p:
        final spec = cat.pump(p.pumpSpecId);
        items.addAll([
          SpecDropdown<PumpSpec>(
            missingLabel: _missing((id) => cat.pump(id)?.name),
            label: t('props.pump'),
            value: p.pumpSpecId,
            items: cat.pumps.where((x) => x.enabled).toList(),
            labelOf: (x) => x.name,
            idOf: (x) => x.id,
            onChanged: (x) => set(() => p.pumpSpecId = x),
          ),
          NumField(label: t('props.speed'), value: p.speedRatio, onChanged: (x) => set(() => p.speedRatio = x)),
          if (spec != null) KV('H0', '${fmt(u.pressureFromHead(spec.curve.withSpeed(p.speedRatio).shutoffHead), 1)} ${u.pressureLabel}'),
          NumField(label: pLabel('props.vfdTarget'), value: u.pressureFromHead(p.targetPressureM), onChanged: (x) => set(() => p.targetPressureM = x <= 0 ? 0 : u.pressureToHead(x))),
          if (p.targetPressureM > 0) NumField(label: t('props.vfdMin'), value: p.minSpeedRatio, onChanged: (x) => set(() => p.minSpeedRatio = x.clamp(0.1, 1.0).toDouble())),
          // 1.6.0 MOT: the motor and its drive in the energy
          NumField(label: t('props.motorEfficiency'), value: p.motorEfficiency, onChanged: (x) => set(() => p.motorEfficiency = x.clamp(0.05, 1.0).toDouble())),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(t('acc.hourMeter'), style: const TextStyle(fontSize: 12)),
            value: p.hourMeter,
            onChanged: (x) => set(() => p.hourMeter = x),
          ),
          if (p.hourMeter) NumField(label: '${t('props.pivotCost')} (${c.project.params.currency})', value: p.hourMeterCost, onChanged: (x) => set(() => p.hourMeterCost = x < 0 ? 0 : x)),
        ]);
      case MiscHydraulicEntity m:
        final spec = cat.valve(m.valveSpecId);
        items.addAll([
          KV(t('props.scope'), t('scope.${m.scope.name}')),
          SpecDropdown<ValveSpec>(
            missingLabel: _missing((id) => cat.valve(id)?.name),
            label: t('props.misc'),
            value: m.valveSpecId,
            items: cat.valves.where((x) => x.enabled && x.kind != ValveKind.control).toList(),
            labelOf: (x) => x.name,
            idOf: (x) => x.id,
            onChanged: (x) => set(() => m.valveSpecId = x),
          ),
          if (spec?.kind == ValveKind.prv) NumField(label: pLabel('props.setting'), value: u.pressureFromHead(m.settingM), onChanged: (x) => set(() => m.settingM = u.pressureToHead(x))),
          if (spec?.kind == ValveKind.psv)
            NumField(label: pLabel('props.sustain'), value: u.pressureFromHead(m.settingM > 0 ? m.settingM : spec!.defaultSettingM), onChanged: (x) => set(() => m.settingM = u.pressureToHead(x))),
          if (spec?.kind == ValveKind.fcv)
            NumField(label: qLabel('props.flowLimit'), value: u.flowFromSi(m.settingFlow > 0 ? m.settingFlow : spec!.maxFlow), onChanged: (x) => set(() => m.settingFlow = x <= 0 ? 0 : u.flowToSi(x))),
        ]);
      case JunctionEntity j:
        items.addAll([
          KV(t('props.scope'), t('scope.${j.scope.name}')),
          NumField(label: t('props.elevationDem'), value: j.fixedElevation ?? 0, onChanged: (x) => set(() => j.fixedElevation = x == 0 ? null : x)),
        ]);
      case BreaklineEntity bl:
        String zText() => [for (var i = 0; i < bl.points.length; i++) bl.elevationOf(i).isFinite ? fmtUi(bl.elevationOf(i), 2) : '-'].join('; ');
        items.addAll([
          KV(t('props.vertices'), '${bl.points.length}'),
          KV(t('props.length'), '${fmt(u.lengthFromSi(bl.length))} ${u.lengthLabel}'),
          TextFieldRow(
            key: const Key('breakline_zs'),
            label: t('props.breaklineZs'),
            value: zText(),
            onChanged: (x) => set(() {
              final parts = x.split(';');
              bl.elevations = [for (var i = 0; i < bl.points.length; i++) i < parts.length ? (parseUiNumber(parts[i].trim()) ?? double.nan) : double.nan];
            }),
          ),
          Text(t('props.breaklineHint'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
        ]);
      case ContourEntity ct:
        items.addAll([
          NumField(label: t('props.elevation'), value: ct.elevation, onChanged: (x) => set(() => ct.elevation = x)),
          KV(t('props.length'), '${fmt(u.lengthFromSi(ct.length))} ${u.lengthLabel}'),
          if (ct.derived) ...[
            Text(t('props.derived'), style: TextStyle(fontSize: 11, color: Cad.attention)),
            TextButton.icon(
              key: const Key('contour_make_source'),
              onPressed: () => set(() => ct.derived = false),
              icon: const Icon(Icons.terrain, size: 16),
              label: Text(t('props.derivedToSource'), style: const TextStyle(fontSize: 12)),
            ),
          ],
        ]);
      case PivotEntity pv:
        final r = c.results?.pivots[pv.id];
        items.addAll([
          SpecDropdown<PivotKind>(
            label: t('props.pivotKind'),
            value: pv.kind.name,
            items: PivotKind.values,
            labelOf: (k) => t(k == PivotKind.pivot ? 'pivot.kindPivot' : 'pivot.kindLinear'),
            idOf: (k) => k.name,
            onChanged: (x) => set(() {
              pv.kind = PivotKind.values.byName(x!);
              if (pv.kind == PivotKind.linear && pv.travelM <= 0) pv.travelM = c.toolSettings.pivotTravelM;
            }),
          ),
          TextFieldRow(label: t('props.zone'), value: pv.zoneName, onChanged: (x) => set(() => pv.zoneName = x, inv: false)),
          len('ui.pivotRadius', pv.radiusM, (x) => pv.radiusM = x, nonPositive: () => null),
          len('ui.pivotSpan', pv.spanLengthM, (x) => pv.spanLengthM = x, nonPositive: () => null),
          if (pv.kind == PivotKind.linear) len('ui.pivotTravel', pv.travelM, (x) => pv.travelM = x),
          if (pv.kind == PivotKind.pivot) NumField(label: t('props.pivotSector'), value: pv.sectorDeg, onChanged: (x) => set(() => pv.sectorDeg = x.clamp(1, 360))),
          NumField(label: t('props.pivotAngle'), value: pv.angleDeg, onChanged: (x) => set(() => pv.angleDeg = x, inv: false)),
          SpecDropdown<PipeSpec>(
            missingLabel: _missing((id) => cat.pipe(id)?.name),
            label: t('props.pivotPipe'),
            value: pv.pipeSpecId,
            items: cat.pipesFor(PipeUsage.mainline),
            labelOf: (x) => x.name,
            idOf: (x) => x.id,
            allowNull: true,
            nullLabel: '${fmt(pv.pipeInnerMm, 0)} mm, C ${fmt(pv.hazenC, 0)}',
            onChanged: (v) => set(() => pv.pipeSpecId = v),
          ),
          if (pv.pipeSpecId == null)
            NumField(label: '${t('ui.pivotPipeId')} (${u.diameterLabel})', value: u.diameterFromSi(pv.pipeInnerMm / 1000), onChanged: (x) => set(() => pv.pipeInnerMm = u.diameterToSi(x) * 1000)),
          if (pv.pipeSpecId == null) NumField(label: t('props.pivotC'), value: pv.hazenC, decimals: 0, onChanged: (x) => set(() => pv.hazenC = x)),
          len('ui.pivotHeight', pv.pipeHeightM, (x) => pv.pipeHeightM = x),
          NumField(label: pLabel('props.pivotEndP'), value: u.pressureFromHead(pv.endPressureM), onChanged: (x) => set(() => pv.endPressureM = u.pressureToHead(x))),
          NumField(label: qLabel('props.pivotGunQ'), value: u.flowFromSi(pv.endGunFlow), onChanged: (x) => set(() => pv.endGunFlow = u.flowToSi(x))),
          if (pv.endGunFlow > 0) NumField(label: pLabel('props.pivotGunP'), value: u.pressureFromHead(pv.endGunPressureM), onChanged: (x) => set(() => pv.endGunPressureM = u.pressureToHead(x))),
          len('ui.pivotThrow', pv.endThrowM, (x) => pv.endThrowM = x),
          NumField(label: '${t('ui.pivotDepth')} (${u.depthLabel})', value: u.depthFromMm(pv.grossDepthMm), onChanged: (x) => set(() => pv.grossDepthMm = u.depthToMm(x))),
          NumField(label: t('props.pivotHours'), value: pv.hoursPerCycle, onChanged: (x) => set(() => pv.hoursPerCycle = x)),
          len('ui.pivotWidth', pv.wettedWidthM, (x) => pv.wettedWidthM = x),
          NumField(label: pLabel('ui.pivotLoss'), value: u.pressureFromHead(pv.machineLossM), onChanged: (x) => set(() => pv.machineLossM = u.pressureToHead(x))),
          NumField(label: '${t('ui.pivotMaxRate')} (${u.depthRateLabel})', value: u.depthFromMm(pv.maxAppRateMmH), onChanged: (x) => set(() => pv.maxAppRateMmH = u.depthToMm(x))),
          NumField(label: '${t('props.pivotCost')} (${c.project.params.currency})', value: pv.machineCost, onChanged: (x) => set(() => pv.machineCost = x)),
          NumField(label: '${t('props.pivotTowerCost')} (${c.project.params.currency})', value: pv.towerCost, onChanged: (x) => set(() => pv.towerCost = x)),
          len('ui.pivotSprSpacing', pv.sprinklerSpacingM, (x) => pv.sprinklerSpacingM = x, nonPositive: () => null),
          SpecDropdown<OutletSpec>(
            missingLabel: _missing((id) => cat.outlet(id)?.name),
            label: t('props.pivotSprinkler'),
            value: pv.sprinklerSpecId,
            items: cat.outlets.where((o) => o.enabled && o.kind != OutletKind.demandPoint).toList(),
            labelOf: (x) => x.name,
            idOf: (x) => x.id,
            allowNull: true,
            onChanged: (v) => set(() => pv.sprinklerSpecId = v),
          ),
          SpecDropdown<ValveSpec>(
            missingLabel: _missing((id) => cat.valve(id)?.name),
            label: t('props.pivotRegulator'),
            value: pv.regulatorSpecId,
            items: cat.valves.where((x) => x.enabled && x.kind == ValveKind.prv).toList(),
            labelOf: (x) => x.name,
            idOf: (x) => x.id,
            allowNull: true,
            onChanged: (v) => set(() => pv.regulatorSpecId = v),
          ),
          OutlinedButton.icon(
            key: const Key('pivot_machine'),
            onPressed: locked ? null : () => showPivotMachineDialog(context, c, pv),
            icon: const Icon(Icons.tune, size: 16),
            label: Text(t('mech.open'), style: const TextStyle(fontSize: 12)),
          ),
          KV(
            t('props.pivotArea'),
            '${fmt(u.areaFromSi(pv.kind == PivotKind.pivot ? 3.141592653589793 * pv.irrigatedRadius * pv.irrigatedRadius * pv.sectorDeg / 360 : pv.irrigatedRadius * pv.travelM), 2)} ${u.areaLabel}',
          ),
          if (r != null) ...[
            SectionTitle(t('props.pivotResults')),
            KV(t('rep.flow'), '${fmt(u.flowFromSi(r.flow), 1)} ${u.flowLabel}'),
            KV(t('props.pivotInlet'), '${fmt(u.pressureFromHead(r.inletHead), 1)} ${u.pressureLabel}'),
            if (r.availableHead != null) KV(t('rep.pAvail'), '${fmt(u.pressureFromHead(r.availableHead!), 1)} ${u.pressureLabel}'),
            KV(t('rep.hf'), '${fmt(u.pressureFromHead(r.frictionLoss), 2)} ${u.pressureLabel}'),
            KV(t('rep.rise'), '${fmt(u.lengthFromSi(r.elevationRise), 2)} ${u.lengthLabel}'),
            KV(t('rep.towers'), '${r.towerCount}'),
            KV(t('rep.sprinklers'), '${r.sprinklerCount}'),
            KV(t('rep.appRatePeak'), '${fmt(u.depthFromMm(r.appRateEndPeak), 2)} ${u.depthRateLabel}'),
            for (final w in r.warnings) Text(c.t.warning(w), style: TextStyle(fontSize: 11, color: Cad.warning)),
          ],
        ]);
      case SpotHeightEntity sp:
        items.add(NumField(label: t('props.elevation'), value: sp.elevation, onChanged: (x) => set(() => sp.elevation = x)));
      case TextEntity tx:
        items.addAll([
          TextFieldRow(label: t('props.text'), value: tx.text, onChanged: (x) => set(() => tx.text = x, inv: false)),
          len('ui.textHeight', tx.height, (x) => tx.height = x, inv: false),
          NumField(label: t('props.rotation'), value: tx.rotationDeg, onChanged: (x) => set(() => tx.rotationDeg = x, inv: false)),
        ]);
      case CircleEntity ci:
        items.add(len('ui.radius', ci.radius, (x) => ci.radius = x, inv: false));
      case ArcEntity a:
        items.addAll([
          len('ui.radius', a.radius, (x) => a.radius = x, inv: false),
          KV(t('props.angle'), '${fmt(a.sweepRad * 180 / 3.141592653589793, 1)}°'),
          KV(t('props.length'), '${fmt(u.lengthFromSi(a.length))} ${u.lengthLabel}'),
        ]);
      case SplineEntity sp:
        items.addAll([
          KV(t('props.length'), '${fmt(u.lengthFromSi(sp.length))} ${u.lengthLabel}'),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(t('props.closed'), style: const TextStyle(fontSize: 12)),
            value: sp.closed,
            onChanged: (x) => set(() => sp.closed = x, inv: false),
          ),
        ]);
      case HatchEntity h:
        items.addAll([
          KV(t('props.area'), '${fmt(u.areaFromSi(h.area), 3)} ${u.areaLabel}'),
          NumField(label: t('props.hatchAngle'), value: h.angleDeg, onChanged: (x) => set(() => h.angleDeg = x, inv: false)),
          len('ui.hatchSpacing', h.spacing, (x) => h.spacing = x, inv: false, nonPositive: () => 1),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(t('props.hatchSolid'), style: const TextStyle(fontSize: 12)),
            value: h.solid,
            onChanged: (x) => set(() => h.solid = x, inv: false),
          ),
        ]);
      case SymbolEntity sy:
        items.addAll([
          SpecDropdown<SymbolKind>(
            label: t('props.symbolKind'),
            value: sy.kind.name,
            items: SymbolKind.values,
            labelOf: (k) => t('sym.${k.name}'),
            idOf: (k) => k.name,
            onChanged: (x) => set(() => sy.kind = SymbolKind.values.byName(x!), inv: false),
          ),
          len('ui.symbolSize', sy.size, (x) => sy.size = x, inv: false, nonPositive: () => 1),
          NumField(label: t('props.rotation'), value: sy.rotationDeg, onChanged: (x) => set(() => sy.rotationDeg = x, inv: false)),
        ]);
      case PolylineEntity pl:
        items.addAll([
          if (pl.closed) KV(t('props.length'), '${fmt(u.lengthFromSi(pl.length))} ${u.lengthLabel}') else _lengthField(pl, pl.points),
          if (pl.closed) KV(t('props.area'), '${fmt(u.areaFromSi(pl.area), 3)} ${u.areaLabel}'),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(t('props.closed'), style: const TextStyle(fontSize: 12)),
            value: pl.closed,
            onChanged: (x) => set(() => pl.closed = x, inv: false),
          ),
        ]);
      case LineEntity l:
        items.add(_lengthField(l, [l.a, l.b]));
      case DimensionEntity d:
        items.add(NumField(label: t('props.dimOffset'), value: d.offset, onChanged: (x) => set(() => d.offset = x, inv: false)));
      case AngularDimensionEntity ad:
        items.addAll([KV(t('props.angle'), '${fmt(ad.angleDeg, 2)}°'), len('ui.dimRadius', ad.radius, (x) => ad.radius = x, inv: false, nonPositive: () => 1)]);
      case RadialDimensionEntity rd:
        items.addAll([
          KV(rd.diameter ? t('props.diameter') : t('props.radius'), '${fmt(u.lengthFromSi(rd.value))} ${u.lengthLabel}'),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(t('props.dimDiameter'), style: const TextStyle(fontSize: 12)),
            value: rd.diameter,
            onChanged: (x) => set(() => rd.diameter = x, inv: false),
          ),
        ]);
      case OrdinateDimensionEntity od:
        items.addAll([
          KV(od.xAxis ? 'X' : 'Y', '${fmt(u.lengthFromSi(od.value))} ${u.lengthLabel}'),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(t('props.ordinateX'), style: const TextStyle(fontSize: 12)),
            value: od.xAxis,
            onChanged: (x) => set(() => od.xAxis = x, inv: false),
          ),
          NumField(label: '${t('props.ordinateOrigin')} X', value: od.origin.x, onChanged: (x) => set(() => od.origin = Pt(x, od.origin.y), inv: false)),
          NumField(label: '${t('props.ordinateOrigin')} Y', value: od.origin.y, onChanged: (x) => set(() => od.origin = Pt(od.origin.x, x), inv: false)),
        ]);
      case ControllerEntity k:
        final duty = c.results?.electrical?.controllers.where((d) => d.controllerId == k.id).firstOrNull;
        items.addAll([
          NumField(label: t('props.stations'), value: k.stations.toDouble(), decimals: 0, onChanged: (x) => set(() => k.stations = x.round().clamp(1, 999))),
          NumField(label: t('props.outputVolts'), value: k.outputVolts, onChanged: (x) => set(() => k.outputVolts = x <= 0 ? k.outputVolts : x)),
          NumField(label: t('props.maxSimultaneous'), value: k.maxSimultaneous.toDouble(), decimals: 0, onChanged: (x) => set(() => k.maxSimultaneous = x.round().clamp(0, 99))),
          // 1.6.0 AGR: what one output and the controller deliver
          NumField(key: const Key('ctrl_station_amps'), label: t('props.stationMaxA'), value: k.stationMaxA, onChanged: (x) => set(() => k.stationMaxA = x < 0 ? 0 : x)),
          NumField(key: const Key('ctrl_total_amps'), label: t('props.totalMaxA'), value: k.totalMaxA, onChanged: (x) => set(() => k.totalMaxA = x < 0 ? 0 : x)),
          NumField(label: '${t('props.pivotCost')} (${c.project.params.currency})', value: k.cost, onChanged: (x) => set(() => k.cost = x < 0 ? 0 : x)),
          SectionTitle(t('acc.title')),
          for (final kind in controllerAccessoryKinds) ...[
            SwitchListTile(
              key: Key('acc_$kind'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(t('acc.$kind'), style: const TextStyle(fontSize: 12)),
              value: k.accessories.containsKey(kind),
              onChanged: (x) => set(() => x ? k.accessories[kind] = 0 : k.accessories.remove(kind)),
            ),
            if (k.accessories.containsKey(kind))
              NumField(label: '${t('props.pivotCost')} (${c.project.params.currency})', value: k.accessories[kind]!, onChanged: (x) => set(() => k.accessories[kind] = x < 0 ? 0 : x)),
          ],
          if (duty != null) ...[
            SectionTitle(t('props.results')),
            KV(t('elec.used'), '${duty.used} / ${duty.stations}', color: duty.overloaded ? Cad.warning : null),
            KV(t('elec.common'), '${cat.wire(duty.commonWireId)?.name ?? '—'}  ${fmt(u.lengthFromSi(duty.commonWireM), 0)} ${u.lengthLabel}'),
            KV(t('elec.maxOpen'), '${duty.maxOpen}'),
            KV(t('elec.stationPeak'), '${fmt(duty.largestStationA, 2)} / ${fmt(duty.stationLimitA, 2)} A', color: duty.largestStationA > duty.stationLimitA + 1e-9 ? Cad.warning : null),
            KV(t('elec.peak'), '${fmt(duty.peakCurrentA, 2)} / ${fmt(duty.totalLimitA, 2)} A', color: duty.peakCurrentA > duty.totalLimitA + 1e-9 ? Cad.warning : null),
          ],
        ]);
      case WireEntity w:
        items.addAll([KV(t('props.length'), '${fmt(u.lengthFromSi(w.length))} ${u.lengthLabel}'), Text(t('hint.wire'), style: TextStyle(color: Cad.fg54, fontSize: 11))]);
      case LeaderEntity le:
        items.addAll([TextFieldRow(label: t('props.text'), value: le.text, onChanged: (x) => set(() => le.text = x, inv: false)), len('ui.textHeight', le.height, (x) => le.height = x, inv: false)]);
      case ImageEntity im:
        items.addAll([
          KV(t('props.source'), im.source),
          len('ui.imageWidth', im.width, (x) => im.width = x, inv: false, nonPositive: () => 1),
          len('ui.imageHeight', im.height, (x) => im.height = x, inv: false, nonPositive: () => 1),
          NumField(label: t('props.rotation'), value: im.rotationDeg, onChanged: (x) => set(() => im.rotationDeg = x, inv: false)),
          NumField(label: t('props.opacity'), value: im.opacity, onChanged: (x) => set(() => im.opacity = x.clamp(0.05, 1.0), inv: false)),
        ]);
      case CommentEntity cm:
        items.addAll([
          if (cm.photo.isNotEmpty) _photo(cm),
          TextFieldRow(label: t('props.text'), value: cm.text, maxLines: 4, onChanged: (x) => set(() => cm.text = x, inv: false)),
          TextFieldRow(label: t('props.author'), value: cm.author, onChanged: (x) => set(() => cm.author = x, inv: false)),
          TextFieldRow(label: t('props.date'), value: cm.date, onChanged: (x) => set(() => cm.date = x, inv: false)),
          SwitchListTile(
            key: const Key('comment_resolved'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(t('props.resolved'), style: const TextStyle(fontSize: 12)),
            value: cm.resolved,
            onChanged: (x) => set(() => cm.resolved = x, inv: false),
          ),
        ]);
      case RevisionCloudEntity rc:
        items.addAll([
          TextFieldRow(label: t('props.revision'), value: rc.revision, onChanged: (x) => set(() => rc.revision = x, inv: false)),
          TextFieldRow(label: t('props.date'), value: rc.date, onChanged: (x) => set(() => rc.date = x, inv: false)),
          TextFieldRow(label: t('props.description'), value: rc.description, maxLines: 3, onChanged: (x) => set(() => rc.description = x, inv: false)),
          NumField(label: '${t('props.arcLength')} (${u.lengthLabel})', value: u.lengthFromSi(rc.arcLength), onChanged: (x) => set(() => rc.arcLength = x <= 0 ? 0 : u.lengthToSi(x), inv: false)),
        ]);
      case AreaEntity a:
        items.addAll(_areaFields(a, set));
      default:
        break;
    }
    // 1.6.0 EDT: coordinates of the item (X/Y of its position or vertices)
    items.addAll(coordinateFields(c, e));
    items.addAll(_results(e));
    return ListView(padding: const EdgeInsets.all(8), children: items);
  }

  /// The photo kept with a comment, and a button to remove it.
  Widget _photo(CommentEntity cm) {
    Uint8List? bytes;
    try {
      bytes = base64Decode(cm.photo);
    } catch (_) {
      bytes = null;
    }
    return Padding(
      key: const Key('comment_photo'),
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.memory(bytes, fit: BoxFit.contain, height: 180, gaplessPlayback: true, errorBuilder: (_, _, _) => const SizedBox.shrink()),
            ),
          TextButton.icon(
            key: const Key('comment_photo_remove'),
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
            icon: const Icon(Icons.hide_image_outlined, size: 16),
            label: Text(c.t('props.removePhoto'), style: const TextStyle(fontSize: 12)),
            onPressed: () => c.mutate(() => cm.photo = '', invalidateResults: false, label: 'hist.edit'),
          ),
        ],
      ),
    );
  }

  List<Widget> _areaFields(AreaEntity a, void Function(void Function() fn, {bool inv}) set) {
    final t = c.t;
    final u = c.units;
    final crop = cropWaterRequirements(c.project, c.results).where((x) => x.areaId == a.id).firstOrNull;
    final localized = isLocalizedArea(a);
    return [
      KV(t('props.area'), '${fmt(u.areaFromSi(a.area), 3)} ${u.areaLabel}'),
      TextFieldRow(label: t('props.crop'), value: a.crop, onChanged: (x) => set(() => a.crop = x, inv: false)),
      SpecDropdown<String>(
        label: t('props.kcPreset'),
        value: 'crop.custom',
        items: ['crop.custom', ...cropKcTable.keys],
        labelOf: (k) => k == 'crop.custom' ? t(k) : '${t(k)} (Kc ${cropKcTable[k]!.$2})',
        idOf: (k) => k,
        onChanged: (k) {
          if (k == null || k == 'crop.custom') return;
          set(() {
            a.kc = cropKcTable[k]!.$2;
            a.useWaterBalance = true;
            if (a.crop.isEmpty) a.crop = t(k);
          }, inv: false);
        },
      ),
      _fraction(t('props.efficiency'), a.efficiency, 0.05, 1.0, (x) => set(() => a.efficiency = x, inv: false), key: const Key('area_efficiency')),
      NumField(label: t('props.emittersPerPlant'), value: a.emittersPerPlant.toDouble(), decimals: 0, onChanged: (x) => set(() => a.emittersPerPlant = x.round().clamp(0, 20))),
      // the method sets Kr and Pw of localized irrigation (one rule for every
      // report: ETc,loc = Kr·Kc·ETo, Pw only in the readily available water)
      SpecDropdown<String>(
        key: const Key('area_method'),
        label: t('req.method'),
        value: areaIrrigationMethod(a),
        items: const ['sprinkler', 'localized', 'surface'],
        labelOf: (k) => t('req.method.$k'),
        idOf: (k) => k,
        onChanged: (k) => set(() {
          a.irrigationMethod = k ?? 'sprinkler';
          // a wetted fraction belongs to localized irrigation only
          if (a.irrigationMethod != 'localized') a.wettedFraction = 1;
        }, inv: false),
      ),
      if (localized) ...[
        _fraction(t('props.wettedFraction'), a.wettedFraction, 0.05, 1.0, (x) => set(() => a.wettedFraction = x, inv: false)),
        _fraction(t('req.groundCover'), a.groundCover, 0, 1, (x) => set(() => a.groundCover = x, inv: false)),
        // 0: from the ground cover
        _fraction(t('area.kr'), a.localizedKr, 0, 1, (x) => set(() => a.localizedKr = x <= 0 ? 0 : math.max(0.05, x), inv: false), key: const Key('area_kr')),
        KV(t('area.krUsed'), fmt(areaKr(a), 2)),
      ],
      SwitchListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(t('props.waterBalance'), style: const TextStyle(fontSize: 12)),
        value: a.useWaterBalance,
        onChanged: (x) => set(() => a.useWaterBalance = x, inv: false),
      ),
      if (!a.useWaterBalance) NumField(label: t('props.netDepth'), value: a.netDepthMmPerDay, onChanged: (x) => set(() => a.netDepthMmPerDay = x, inv: false)),
      if (a.useWaterBalance) ...[
        NumField(label: t('props.eto'), value: a.etoMmDay, onChanged: (x) => set(() => a.etoMmDay = x, inv: false)),
        NumField(label: t('props.kc'), value: a.kc, onChanged: (x) => set(() => a.kc = x, inv: false)),
        NumField(label: t('props.awc'), value: a.awcMmPerM, decimals: 0, onChanged: (x) => set(() => a.awcMmPerM = x, inv: false)),
        NumField(label: t('props.rootDepth'), value: a.rootDepthM, onChanged: (x) => set(() => a.rootDepthM = x, inv: false)),
        _fraction(t('props.mad'), a.mad, 0.05, 0.95, (x) => set(() => a.mad = x, inv: false), key: const Key('area_mad')),
        // ETc,loc of the design period (the crop table's month with a crop of the table)
        KV(t('props.etc'), fmt(crop?.etcMmDay ?? a.etcMmDay * areaKr(a), 2)),
      ],
      if (crop != null) ...[
        if (crop.month != null) KV(t('area.designMonth'), t('mon.${crop.month}')),
        KV(t('props.interval'), fmt(crop.intervalDays, 0)),
        KV(t('rep.grossEvent'), '${fmt(u.depthFromMm(crop.grossDepthMm), 2)} ${u.depthLabel}'),
        KV(t('rep.hoursEvent'), '${fmt(crop.hoursPerEvent, 2)} h'),
      ],
      // requirement by month and growth stage (FAO-56 crop table)
      SectionTitle(t('req.title')),
      SpecDropdown<String>(
        key: const Key('area_crop_key'),
        label: t('req.crop'),
        value: a.cropKey.isEmpty ? '' : a.cropKey,
        // 1.6.0 AGR: the user's crops after the FAO-56 table (PRD-15)
        items: ['', ...fao56Crops.keys, for (final x in c.project.agronomy.userCrops) x.key],
        labelOf: (k) => k.isEmpty ? t('req.noCrop') : cropNameOf(c.project, k, t.call),
        idOf: (k) => k,
        onChanged: (k) => set(() {
          a.cropKey = k ?? '';
          final data = cropDataOf(c.project, a.cropKey);
          if (data != null) {
            if (a.crop.isEmpty) a.crop = cropNameOf(c.project, a.cropKey, t.call);
            a.kc = data.kcMid;
            if (data.schedulingRootDepthM != null) a.rootDepthM = data.schedulingRootDepthM!;
            if (data.depletionFraction != null) a.mad = data.depletionFraction!;
          }
        }, inv: false),
      ),
      if (a.cropKey.isNotEmpty) ...[
        TextFieldRow(label: t('req.planting'), value: a.plantingMonthDay, onChanged: (x) => set(() => a.plantingMonthDay = x.trim(), inv: false)),
        // how the date was read (DD/MM, MM-DD, month names; the FAO-56 month without one)
        () {
          final (date, how) = readPlantingDate(a, southern: siteIsSouthern(c.project), crop: cropDataOf(c.project, a.cropKey));
          final day = '${date.day} ${t('mon.${date.month}')}';
          final (text, warn) = switch (how) {
            PlantingRead.given => (t('req.plantingRead', {'d': day}), false),
            PlantingRead.ambiguous => (t('req.plantingAmbiguous', {'d': day}), true),
            PlantingRead.invalid => (t('req.plantingInvalid', {'d': day}), true),
            PlantingRead.missing => (t('req.plantingDefault', {'d': day}), false),
          };
          return Text(
            text,
            key: const Key('area_planting_read'),
            style: TextStyle(fontSize: 11, color: warn ? Cad.warning : Cad.fg54),
          );
        }(),
        SpecDropdown<String>(
          label: t('req.rainMethod'),
          value: a.rainMethod,
          items: [for (final m in EffectiveRainMethod.values) m.name],
          labelOf: (k) => t('req.rain.$k'),
          idOf: (k) => k,
          onChanged: (k) => set(() => a.rainMethod = k ?? 'usdaScs', inv: false),
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(t('req.dependable'), style: const TextStyle(fontSize: 12)),
          value: a.useDependableRain,
          onChanged: (x) => set(() => a.useDependableRain = x, inv: false),
        ),
        NumField(label: t('req.ecw'), value: a.ecwDsM, onChanged: (x) => set(() => a.ecwDsM = x < 0 ? 0 : x, inv: false)),
        if (a.ecwDsM > 0)
          NumField(
            key: const Key('area_yield_potential'),
            label: t('req.yieldPotential'),
            value: a.yieldPotentialPct,
            decimals: 0,
            onChanged: (x) => set(() => a.yieldPotentialPct = x.clamp(50, 100).toDouble(), inv: false),
          ),
        SwitchListTile(
          key: const Key('area_climate_kc'),
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(t('req.climateKc'), style: const TextStyle(fontSize: 12)),
          value: a.climateKc,
          onChanged: (x) => set(() => a.climateKc = x, inv: false),
        ),
        if (c.project.climate == null) Text(t('req.noClimate'), style: TextStyle(fontSize: 11, color: Cad.fg54)),
      ],
      SpecDropdown<String>(
        key: const Key('area_soil'),
        label: t('req.soil'),
        value: a.soilKey,
        items: ['', ...soilTable.keys],
        labelOf: (k) => k.isEmpty ? t('req.soilTyped') : t(k),
        idOf: (k) => k,
        onChanged: (k) => set(() {
          a.soilKey = k ?? '';
          final soil = soilTable[a.soilKey];
          if (soil != null) a.awcMmPerM = soil.awcMmPerM;
        }, inv: false),
      ),
      NumField(label: t('req.slope'), value: a.slopePct, onChanged: (x) => set(() => a.slopePct = x < 0 ? 0 : x, inv: false)),
      SpecDropdown<String>(
        label: t('wb.plantWaterUse'),
        value: a.plantWaterUse,
        items: const ['', 'veryLow', 'low', 'moderate', 'high'],
        labelOf: (k) => t(k.isEmpty ? 'wb.notHydrozone' : 'wb.use.$k'),
        idOf: (k) => k,
        onChanged: (k) => set(() => a.plantWaterUse = k ?? '', inv: false),
      ),
    ];
  }

  /// Allowable submain position of a lateral (from Zone → Envelope).
  List<Widget> _envelope(String id) {
    final res = c.feedEnvelope[id];
    if (res == null || res.isEmpty) return const [];
    final t = c.t;
    final u = c.units;
    var best = res.first;
    for (final r in res) {
      if (r.variation < best.variation) best = r;
    }
    final ok = res.where((r) => r.ok).toList();
    return [
      SectionTitle(t('props.envelope')),
      Text(t('props.envelopeBest', {'f': (best.fraction * 100).round().toString(), 'v': '${fmt(u.pressureFromHead(best.variation), 1)} ${u.pressureLabel}'}), style: const TextStyle(fontSize: 11.5)),
      Text(
        ok.isEmpty ? t('props.envelopeNone') : t('props.envelopeRange', {'a': (ok.first.fraction * 100).round().toString(), 'b': (ok.last.fraction * 100).round().toString()}),
        style: TextStyle(fontSize: 11.5, color: ok.isEmpty ? Cad.warning : Cad.ok),
      ),
    ];
  }

  /// Batch properties: common fields of the dominant entity type.
  Widget _batch(BuildContext context) {
    final t = c.t;
    final u = c.units;
    final cat = c.project.catalog;
    final sel = c.project.entities.where((e) => c.selection.contains(e.id)).toList();
    final byType = <String, int>{};
    for (final e in sel) {
      byType[ProjectController.toolKeyOf(e)] = (byType[ProjectController.toolKeyOf(e)] ?? 0) + 1;
    }
    final dominant = byType.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final items = <Widget>[
      Text(t('props.multi', {'n': '${sel.length}'}), style: const TextStyle(fontWeight: FontWeight.bold)),
      Text(byType.entries.map((e) => '${e.value} × ${t('tool.${e.key}')}').join(', '), style: TextStyle(fontSize: 11, color: Cad.fg54)),
      const SizedBox(height: 4),
      _layerField(sel.first, mixed: sel.any((e) => e.layer != sel.first.layer)),
    ];
    String pLabel(String k) => '${t(k)} (${u.pressureLabel})';
    String lLabel(String k) => '${t(k)} (${u.lengthLabel})';
    T? common<T>(Iterable<T?> values) {
      final list = values.toList();
      if (list.isEmpty) return null;
      final first = list.first;
      return list.every((v) => v == first) ? first : null;
    }

    Widget mixedNote() => const SizedBox.shrink();
    items.add(SectionTitle(t('props.batch', {'n': '${byType[dominant]}', 'type': t('tool.$dominant')})));
    switch (dominant) {
      case 'sprayline':
        final s = sel.whereType<SpraylineEntity>().toList();
        final pipe = common(s.map((e) => e.pipeSpecId));
        final outlet = common(s.map((e) => e.outletSpecId));
        final nozzle = common(s.map((e) => e.nozzleId));
        final head = common(s.map((e) => e.headM));
        final spacing = common(s.map((e) => e.spacing));
        final outletSpec = outlet != null ? cat.outlet(outlet) : null;
        items.addAll([
          SpecDropdown<PipeSpec>(
            missingLabel: _missing((id) => cat.pipe(id)?.name),
            label: t('props.pipe'),
            value: pipe,
            items: cat.pipesFor(PipeUsage.lateral),
            labelOf: (x) => x.name,
            idOf: (x) => x.id,
            allowNull: true,
            nullLabel: pipe == null && s.any((e) => e.pipeSpecId != null) ? t('props.mixed') : t('auto'),
            onChanged: (v) => c.mutateSelected<SpraylineEntity>((e) {
              e.pipeSpecId = v;
              e.computerSized = v == null;
            }),
          ),
          SpecDropdown<OutletSpec>(
            missingLabel: _missing((id) => cat.outlet(id)?.name),
            label: t('props.outlet'),
            value: outlet,
            items: cat.outlets.where((o) => o.enabled).toList(),
            labelOf: (x) => x.name,
            idOf: (x) => x.id,
            allowNull: outlet == null,
            nullLabel: t('props.mixed'),
            onChanged: (v) {
              if (v == null) return;
              c.mutateSelected<SpraylineEntity>((e) {
                e.outletSpecId = v;
                e.nozzleId = cat.outlet(v)?.nozzles.firstOrNull?.id;
              });
            },
          ),
          if (outletSpec != null)
            SpecDropdown<NozzleSpec>(
              missingLabel: _missing((id) => null),
              label: t('props.nozzle'),
              value: nozzle,
              items: outletSpec.nozzles,
              labelOf: (x) => x.name,
              idOf: (x) => x.id,
              allowNull: nozzle == null,
              nullLabel: t('props.mixed'),
              onChanged: (v) => c.mutateSelected<SpraylineEntity>((e) => e.nozzleId = v),
            ),
          NumField(
            label: pLabel('props.head'),
            value: head == null ? 0 : u.pressureFromHead(head),
            mixed: head == null,
            onChanged: (v) => c.mutateSelected<SpraylineEntity>((e) => e.headM = u.pressureToHead(v)),
          ),
          if (head == null) mixedNote(),
          NumField(
            label: lLabel('props.spacing'),
            value: spacing == null ? 0 : u.lengthFromSi(spacing),
            mixed: spacing == null,
            onChanged: (v) {
              if (v > 0) c.mutateSelected<SpraylineEntity>((e) => e.spacing = u.lengthToSi(v));
            },
          ),
          if (spacing == null) mixedNote(),
        ]);
      case 'tape':
        final s = sel.whereType<TapeEntity>().toList();
        final spec = common(s.map((e) => e.tapeSpecId));
        final inlet = common(s.map((e) => e.inletHeadM));
        items.addAll([
          SpecDropdown<TapeSpec>(
            missingLabel: _missing((id) => cat.tape(id)?.name),
            label: t('props.tape'),
            value: spec,
            items: cat.tapes.where((x) => x.enabled).toList(),
            labelOf: (x) => x.name,
            idOf: (x) => x.id,
            allowNull: spec == null,
            nullLabel: t('props.mixed'),
            onChanged: (v) {
              if (v != null) c.mutateSelected<TapeEntity>((e) => e.tapeSpecId = v);
            },
          ),
          NumField(
            label: pLabel('props.inlet'),
            value: inlet == null ? 0 : u.pressureFromHead(inlet),
            mixed: inlet == null,
            onChanged: (v) => c.mutateSelected<TapeEntity>((e) => e.inletHeadM = u.pressureToHead(v)),
          ),
          if (inlet == null) mixedNote(),
        ]);
      case 'zonePipe':
      case 'mainPipe':
        final s = sel.whereType<PipeEntity>().toList();
        final scope = common(s.map((e) => e.scope)) ?? HydraulicScope.zone;
        final spec = common(s.map((e) => e.pipeSpecId));
        final depth = common(s.map((e) => e.depth));
        items.addAll([
          SpecDropdown<PipeSpec>(
            missingLabel: _missing((id) => cat.pipe(id)?.name),
            label: t('props.pipe'),
            value: spec,
            items: cat.pipesFor(scope == HydraulicScope.zone ? PipeUsage.zone : PipeUsage.mainline),
            labelOf: (x) => x.name,
            idOf: (x) => x.id,
            allowNull: true,
            nullLabel: spec == null && s.any((e) => e.pipeSpecId != null) ? t('props.mixed') : t('auto'),
            onChanged: (v) => c.mutateSelected<PipeEntity>((e) {
              e.pipeSpecId = v;
              e.computerSized = v == null;
            }),
          ),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(t('props.auto'), style: const TextStyle(fontSize: 12)),
            value: s.every((e) => e.computerSized),
            onChanged: (v) => c.mutateSelected<PipeEntity>((e) => e.computerSized = v),
          ),
          NumField(label: lLabel('ui.depth'), value: u.lengthFromSi(depth ?? 0), mixed: depth == null, onChanged: (v) => c.mutateSelected<PipeEntity>((e) => e.depth = u.lengthToSi(v))),
          if (depth == null) mixedNote(),
        ]);
      case 'outlet':
        final s = sel.whereType<OutletEntity>().toList();
        final outlet = common(s.map((e) => e.outletSpecId));
        final nozzle = common(s.map((e) => e.nozzleId));
        final head = common(s.map((e) => e.headM));
        final arc = common(s.map((e) => e.arcDeg));
        final outletSpec = outlet != null ? cat.outlet(outlet) : null;
        items.addAll([
          SpecDropdown<OutletSpec>(
            missingLabel: _missing((id) => cat.outlet(id)?.name),
            label: t('props.outlet'),
            value: outlet,
            items: cat.outlets.where((o) => o.enabled).toList(),
            labelOf: (x) => x.name,
            idOf: (x) => x.id,
            allowNull: outlet == null,
            nullLabel: t('props.mixed'),
            onChanged: (v) {
              if (v == null) return;
              c.mutateSelected<OutletEntity>((e) {
                e.outletSpecId = v;
                e.nozzleId = cat.outlet(v)?.nozzles.firstOrNull?.id;
              });
            },
          ),
          if (outletSpec != null)
            SpecDropdown<NozzleSpec>(
              missingLabel: _missing((id) => null),
              label: t('props.nozzle'),
              value: nozzle,
              items: outletSpec.nozzles,
              labelOf: (x) => x.name,
              idOf: (x) => x.id,
              allowNull: nozzle == null,
              nullLabel: t('props.mixed'),
              onChanged: (v) => c.mutateSelected<OutletEntity>((e) => e.nozzleId = v),
            ),
          NumField(
            label: pLabel('props.head'),
            value: head == null ? 0 : u.pressureFromHead(head),
            mixed: head == null,
            onChanged: (v) => c.mutateSelected<OutletEntity>((e) => e.headM = u.pressureToHead(v)),
          ),
          if (head == null) mixedNote(),
          NumField(label: t('props.arc'), value: arc ?? 0, mixed: arc == null, onChanged: (v) => c.mutateSelected<OutletEntity>((e) => e.arcDeg = v)),
          // valve-in-head heads: one station for all of them
          if (s.every((e) => e.scope == HydraulicScope.mainline))
            TextFieldRow(
              key: const Key('vih_station_batch'),
              label: t('props.vihStation'),
              value: common(s.map((e) => e.zoneName)) ?? '',
              onChanged: (v) => c.mutateSelected<OutletEntity>((e) => e.zoneName = v),
            ),
        ]);
      case 'valve':
        final s = sel.whereType<ControlValveEntity>().toList();
        final spec = common(s.map((e) => e.valveSpecId));
        items.add(
          SpecDropdown<ValveSpec>(
            missingLabel: _missing((id) => cat.valve(id)?.name),
            label: t('props.valve'),
            value: spec,
            items: cat.valves.where((x) => x.enabled && x.kind == ValveKind.control).toList(),
            labelOf: (x) => x.name,
            idOf: (x) => x.id,
            allowNull: true,
            nullLabel: t('props.mixed'),
            onChanged: (v) => c.mutateSelected<ControlValveEntity>((e) => e.valveSpecId = v),
          ),
        );
      case 'contour':
        final s = sel.whereType<ContourEntity>().toList();
        final z = common(s.map((e) => e.elevation));
        items.add(NumField(label: t('props.elevation'), value: z ?? 0, mixed: z == null, onChanged: (v) => c.mutateSelected<ContourEntity>((e) => e.elevation = v)));
      case 'spot':
        final s = sel.whereType<SpotHeightEntity>().toList();
        final z = common(s.map((e) => e.elevation));
        items.add(NumField(label: t('props.elevation'), value: z ?? 0, mixed: z == null, onChanged: (v) => c.mutateSelected<SpotHeightEntity>((e) => e.elevation = v)));
      case 'text':
        final s = sel.whereType<TextEntity>().toList();
        final h = common(s.map((e) => e.height));
        items.add(
          NumField(
            label: lLabel('ui.textHeight'),
            value: u.lengthFromSi(h ?? 1),
            mixed: h == null,
            onChanged: (v) {
              if (v > 0) c.mutateSelected<TextEntity>((e) => e.height = u.lengthToSi(v), invalidateResults: false);
            },
          ),
        );
      case 'area':
        final s = sel.whereType<AreaEntity>().toList();
        final eff = common(s.map((e) => e.efficiency));
        items.addAll([
          _fraction(t('props.efficiency'), eff ?? 0.9, 0.05, 1.0, (v) => c.mutateSelected<AreaEntity>((e) => e.efficiency = v, invalidateResults: false)),
          NumField(
            label: t('props.eto'),
            value: common(s.map((e) => e.etoMmDay)) ?? 5,
            mixed: common(s.map((e) => e.etoMmDay)) == null,
            onChanged: (v) => c.mutateSelected<AreaEntity>((e) => e.etoMmDay = v, invalidateResults: false),
          ),
        ]);
      default:
        break;
    }
    items.addAll([const SizedBox(height: 8), FilledButton.tonalIcon(onPressed: c.deleteSelected, icon: const Icon(Icons.delete_outline, size: 16), label: Text(t('edit.delete')))]);
    return ListView(padding: const EdgeInsets.all(8), children: items);
  }

  /// The system flows the station of the valve-in-head head [o] runs in.
  String _vihFlows(OutletEntity o) {
    final p = c.project;
    final vih = VihStations.of(p);
    final s = vihStationId(o);
    if (!vih.scheduled.contains(s)) return c.t('props.vihEveryFlow');
    return vih.flowsOf(s, p.systemFlows).map((f) => f.name).join(', ');
  }

  Widget _layerField(Entity e, {bool mixed = false}) => SpecDropdown<String>(
    label: c.t('props.layer'),
    value: mixed ? null : e.layer,
    items: c.project.layers.map((l) => l.name).toList(),
    labelOf: (s) => s,
    idOf: (s) => s,
    allowNull: mixed,
    nullLabel: c.t('props.mixed'),
    missingLabel: (id) => '$id ${c.t('props.noLayer')}',
    onChanged: (v) {
      if (v == null) return;
      c.mutate(() {
        for (final x in c.project.entities.where((x) => c.selection.contains(x.id))) {
          x.layer = v;
        }
      }, invalidateResults: false);
    },
  );

  List<Widget> _results(Entity e) {
    final r = c.results;
    if (r == null) return const [];
    final t = c.t;
    final u = c.units;
    final out = <Widget>[SectionTitle(t('props.results'))];
    if (e is ControlValveEntity) {
      final z = r.zones[e.id];
      if (z == null) return out..add(const Text('—'));
      out.addAll([
        KV(t('result.flow'), '${fmt(u.flowFromSi(z.totalFlow))} ${u.flowLabel}'),
        KV(t('props.downstream'), '${fmt(u.pressureFromHead(z.downstreamHead), 1)} ${u.pressureLabel}'),
        KV(t('props.valveLoss'), '${fmt(u.pressureFromHead(z.valveLoss), 2)} ${u.pressureLabel}'),
        KV(t('props.required'), '${fmt(u.pressureFromHead(z.requiredUpstreamHead), 1)} ${u.pressureLabel}'),
        KV(t('props.emitterMinMax'), '${fmt(u.pressureFromHead(z.minOutletPressure), 1)} / ${fmt(u.pressureFromHead(z.maxOutletPressure), 1)}', color: z.withinWindow ? Cad.ok : Cad.warning),
        KV(t('props.allowed'), '${fmt(u.pressureFromHead(z.allowedMin), 1)} / ${fmt(u.pressureFromHead(z.allowedMax), 1)}'),
        KV(t('props.uniformity'), '${fmt(z.uniformity.cu, 1)} / ${fmt(z.uniformity.du, 1)} / ${fmt(z.uniformity.eu, 1)} %'),
        if (z.overlapCu > 0) KV(t('rep.overlapCu'), fmt(z.overlapCu, 0)),
        for (final w in z.warnings)
          Text(
            c.t.warning(w, entityName: (id) => c.project.byId(id)?.name ?? id),
            style: TextStyle(fontSize: 11, color: Cad.warning),
          ),
      ]);
      final run = r.electrical?.runOf(e.id);
      if (run != null) {
        out.add(KV(t('elec.station'), '${c.project.byId(run.controllerId)?.name ?? run.controllerId} · ${run.station}'));
        out.add(KV(t('elec.stationWire'), '${c.project.catalog.wire(run.stationWireId)?.name ?? '—'}  ${fmt(u.lengthFromSi(run.wireM), 0)} ${u.lengthLabel}'));
        out.add(KV(t('elec.volts'), '${fmt(run.volts, 1)} V', color: run.ok ? Cad.ok : Cad.warning));
      }
      final fl = r.flushing.where((f) => f.valveId == e.id).firstOrNull;
      if (fl != null) out.add(KV(t('reports.flushing'), '${fmt(u.flowFromSi(fl.flow), 1)} ${u.flowLabel} @ ${fmt(u.pressureFromHead(fl.requiredUpstreamHead), 1)} ${u.pressureLabel}'));
      return out;
    }
    final pipes = r.pipesByEntity[e.id];
    if (pipes != null && pipes.isNotEmpty) {
      final qmax = pipes.map((p) => p.flow.abs()).reduce((a, b) => a > b ? a : b);
      final vmax = pipes.map((p) => p.velocity).reduce((a, b) => a > b ? a : b);
      final loss = pipes.fold<double>(0, (s, p) => s + p.headLoss.abs());
      final pStart = pipes.first.pressureStart, pEnd = pipes.last.pressureEnd;
      out.addAll([
        KV(t('props.pipe'), pipes.first.pipeName),
        KV(t('result.flow'), '${fmt(u.flowFromSi(qmax))} ${u.flowLabel}'),
        KV(t('result.velocity'), '${fmt(u.velocityFromSi(vmax))} ${u.velocityLabel}', color: pipes.any((p) => p.overVelocity) ? Cad.warning : null),
        KV(t('result.loss'), '${fmt(u.pressureFromHead(loss), 2)} ${u.pressureLabel}'),
        KV(t('result.pStart'), '${fmt(u.pressureFromHead(pStart), 1)} ${u.pressureLabel}'),
        KV(t('result.pEnd'), '${fmt(u.pressureFromHead(pEnd), 1)} ${u.pressureLabel}'),
      ]);
      final sr = r.surge.where((s) => s.entityId == e.id).firstOrNull;
      if (sr != null) {
        out.add(KV(t('reports.surge'), '+${fmt(u.pressureFromHead(sr.surgeHead), 1)} → ${fmt(u.pressureFromHead(sr.totalHead), 1)} ${u.pressureLabel}', color: sr.exceeds ? Cad.warning : null));
      }
    }
    final outs = r.outletsByEntity[e.id];
    if (outs != null && outs.isNotEmpty) {
      final pmin = outs.map((o) => o.pressure).reduce((a, b) => a < b ? a : b);
      final pmax = outs.map((o) => o.pressure).reduce((a, b) => a > b ? a : b);
      final q = outs.fold<double>(0, (s, o) => s + o.flow * o.count);
      out.addAll([
        KV(
          '${t('result.pressure')} ${t('result.min')}/${t('result.max')}',
          '${fmt(u.pressureFromHead(pmin), 1)} / ${fmt(u.pressureFromHead(pmax), 1)} ${u.pressureLabel}',
          color: outs.every((o) => o.inWindow) ? Cad.ok : Cad.warning,
        ),
        KV(t('result.flow'), '${fmt(u.flowFromSi(q))} ${u.flowLabel}'),
      ]);
    }
    if (e is WaterSupplyEntity) {
      for (final f in r.systemFlows) {
        for (final d in f.supplies.where((d) => d.supplyId == e.id)) {
          final surplus = d.surplusHead > 0.05 ? ' (${t('rep.surplus')} ${fmt(u.pressureFromHead(d.surplusHead), 1)})' : '';
          out.add(
            KV(
              f.name,
              '${fmt(u.flowFromSi(d.flow))} ${u.flowLabel} @ ${fmt(u.pressureFromHead(math.max(0, d.requiredHead)), 1)} ${u.pressureLabel}$surplus',
              color: d.headExceedsMax || d.flowExceedsDesign ? Cad.warning : null,
            ),
          );
        }
      }
    }
    if (e is PumpEntity || e is MiscHydraulicEntity) {
      for (final f in r.systemFlows) {
        for (final d in f.devices.where((d) => d.entityId == e.id)) {
          final suction = f.warnings.contains('pump_suction_lift:${e.id}');
          out.add(
            KV(
              f.name,
              e is PumpEntity ? '${fmt(u.flowFromSi(d.flow))} ${u.flowLabel} / H ${fmt(u.pressureFromHead(d.pumpHead), 1)}' : 'Δh ${fmt(u.pressureFromHead(d.headLoss), 2)} ${u.pressureLabel}',
            ),
          );
          out.add(
            KV(
              '  ${t('rep.pIn')} → ${t('rep.pOut')}',
              '${fmt(u.pressureFromHead(d.upstreamPressure), 1)} → ${fmt(u.pressureFromHead(d.downstreamPressure), 1)} ${u.pressureLabel}',
              color: suction ? Cad.warning : null,
            ),
          );
          if (suction) out.add(Text(c.t.warning('pump_suction_lift'), style: TextStyle(fontSize: 11, color: Cad.warning)));
        }
      }
      for (final z in r.zones.values) {
        for (final d in z.devices.where((d) => d.entityId == e.id)) {
          out.add(KV(z.zoneName, 'Δh ${fmt(u.pressureFromHead(d.headLoss), 2)} ${u.pressureLabel}'));
        }
      }
    }
    if (out.length == 1) out.add(Text('—', style: TextStyle(color: Cad.fg38)));
    return out;
  }

  /// Defaults used by the active creation / editing tool.
  Widget _toolDefaults(BuildContext context) {
    final t = c.t;
    final u = c.units;
    final s = c.toolSettings;
    final cat = c.project.catalog;
    final tool = c.activeTool;
    final items = <Widget>[Text('${t('tool.${tool.name}')} — ${t('props.defaults')}', style: const TextStyle(fontWeight: FontWeight.bold))];
    void upd(void Function() fn) {
      fn();
      c.refresh();
    }

    switch (tool) {
      case ToolId.zonePipe:
        items.add(
          SpecDropdown<PipeSpec>(
            missingLabel: _missing((id) => cat.pipe(id)?.name),
            label: t('props.pipe'),
            value: s.zonePipeSpecId,
            items: cat.pipesFor(PipeUsage.zone),
            labelOf: (x) => x.name,
            idOf: (x) => x.id,
            allowNull: true,
            nullLabel: t('auto'),
            onChanged: (v) => upd(() => s.zonePipeSpecId = v),
          ),
        );
      case ToolId.mainPipe:
        items.add(
          SpecDropdown<PipeSpec>(
            missingLabel: _missing((id) => cat.pipe(id)?.name),
            label: t('props.pipe'),
            value: s.mainPipeSpecId,
            items: cat.pipesFor(PipeUsage.mainline),
            labelOf: (x) => x.name,
            idOf: (x) => x.id,
            allowNull: true,
            nullLabel: t('auto'),
            onChanged: (v) => upd(() => s.mainPipeSpecId = v),
          ),
        );
      case ToolId.sprayline:
      case ToolId.outlet:
      case ToolId.autohead:
        final outlet = cat.outlet(s.outletSpecId);
        items.addAll([
          if (tool == ToolId.sprayline)
            SpecDropdown<PipeSpec>(
              missingLabel: _missing((id) => cat.pipe(id)?.name),
              label: t('props.pipe'),
              value: s.lateralPipeSpecId,
              items: cat.pipesFor(PipeUsage.lateral),
              labelOf: (x) => x.name,
              idOf: (x) => x.id,
              allowNull: true,
              nullLabel: t('auto'),
              onChanged: (v) => upd(() => s.lateralPipeSpecId = v),
            ),
          SpecDropdown<OutletSpec>(
            missingLabel: _missing((id) => cat.outlet(id)?.name),
            label: t('props.outlet'),
            value: s.outletSpecId,
            items: cat.outlets.where((o) => o.enabled).toList(),
            labelOf: (x) => x.name,
            idOf: (x) => x.id,
            onChanged: (v) => upd(() {
              s.outletSpecId = v ?? s.outletSpecId;
              final o = cat.outlet(s.outletSpecId);
              s.nozzleId = o?.nozzles.firstOrNull?.id;
              s.headM = o?.nozzles.firstOrNull?.defaultHeadM ?? s.headM;
            }),
          ),
          if (outlet != null)
            SpecDropdown<NozzleSpec>(
              missingLabel: _missing((id) => null),
              label: t('props.nozzle'),
              value: s.nozzleId,
              items: outlet.nozzles,
              labelOf: (x) => x.name,
              idOf: (x) => x.id,
              onChanged: (v) => upd(() {
                s.nozzleId = v;
                s.headM = outlet.nozzle(v)?.defaultHeadM ?? s.headM;
              }),
            ),
          NumField(label: '${t('props.head')} (${u.pressureLabel})', value: u.pressureFromHead(s.headM), onChanged: (v) => upd(() => s.headM = u.pressureToHead(v))),
          if (tool == ToolId.sprayline)
            NumField(label: '${t('props.spacing')} (${u.lengthLabel})', value: u.lengthFromSi(s.spacing), onChanged: (v) => upd(() => s.spacing = v > 0 ? u.lengthToSi(v) : s.spacing)),
          if (tool == ToolId.sprayline)
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(t('props.halfSpacing'), style: const TextStyle(fontSize: 12)),
              value: s.outletOffsetHalf,
              onChanged: (v) => upd(() => s.outletOffsetHalf = v),
            ),
          if (tool == ToolId.outlet) NumField(label: t('props.arc'), value: s.arcDeg, onChanged: (v) => upd(() => s.arcDeg = v)),
          if (tool == ToolId.outlet) _scopeSwitch(),
        ]);
      case ToolId.tape:
        items.addAll([
          SpecDropdown<TapeSpec>(
            missingLabel: _missing((id) => cat.tape(id)?.name),
            label: t('props.tape'),
            value: s.tapeSpecId,
            items: cat.tapes.where((x) => x.enabled).toList(),
            labelOf: (x) => x.name,
            idOf: (x) => x.id,
            onChanged: (v) => upd(() {
              s.tapeSpecId = v ?? s.tapeSpecId;
              s.tapeInletHeadM = cat.tape(s.tapeSpecId)?.defaultInletHeadM ?? s.tapeInletHeadM;
            }),
          ),
          NumField(label: '${t('props.inlet')} (${u.pressureLabel})', value: u.pressureFromHead(s.tapeInletHeadM), onChanged: (v) => upd(() => s.tapeInletHeadM = u.pressureToHead(v))),
        ]);
      case ToolId.valve:
        items.addAll([
          SpecDropdown<ValveSpec>(
            missingLabel: _missing((id) => cat.valve(id)?.name),
            label: t('props.valve'),
            value: s.valveSpecId,
            items: cat.valves.where((x) => x.enabled && x.kind == ValveKind.control).toList(),
            labelOf: (x) => x.name,
            idOf: (x) => x.id,
            onChanged: (v) => upd(() => s.valveSpecId = v ?? s.valveSpecId),
          ),
          _splitSwitch(),
        ]);
      case ToolId.pump:
        items.addAll([
          SpecDropdown<PumpSpec>(
            missingLabel: _missing((id) => cat.pump(id)?.name),
            label: t('props.pump'),
            value: s.pumpSpecId,
            items: cat.pumps.where((x) => x.enabled).toList(),
            labelOf: (x) => x.name,
            idOf: (x) => x.id,
            onChanged: (v) => upd(() => s.pumpSpecId = v ?? s.pumpSpecId),
          ),
          _scopeSwitch(),
          _splitSwitch(),
        ]);
      case ToolId.misc:
        final spec = cat.valve(s.miscSpecId);
        items.addAll([
          SpecDropdown<ValveSpec>(
            missingLabel: _missing((id) => cat.valve(id)?.name),
            label: t('props.misc'),
            value: s.miscSpecId,
            items: cat.valves.where((x) => x.enabled && x.kind != ValveKind.control).toList(),
            labelOf: (x) => x.name,
            idOf: (x) => x.id,
            onChanged: (v) => upd(() {
              s.miscSpecId = v ?? s.miscSpecId;
              s.miscSettingM = cat.valve(s.miscSpecId)?.defaultSettingM ?? 0;
            }),
          ),
          if (spec?.kind == ValveKind.prv)
            NumField(label: '${t('props.setting')} (${u.pressureLabel})', value: u.pressureFromHead(s.miscSettingM), onChanged: (v) => upd(() => s.miscSettingM = u.pressureToHead(v))),
          _scopeSwitch(),
          _splitSwitch(),
        ]);
      case ToolId.junction:
        items.addAll([_scopeSwitch(), _splitSwitch()]);
      case ToolId.contour:
        items.addAll([
          NumField(label: t('props.elevation'), value: s.contourElevation, onChanged: (v) => upd(() => s.contourElevation = v)),
          NumField(label: t('props.contourInterval'), value: s.contourInterval, onChanged: (v) => upd(() => s.contourInterval = v)),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(t('props.contourSmooth'), style: const TextStyle(fontSize: 12)),
            value: s.contourSmooth,
            onChanged: (v) => upd(() => s.contourSmooth = v),
          ),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(t('elev.autoIncrement'), style: const TextStyle(fontSize: 12)),
            value: s.contourAutoIncrement,
            onChanged: (v) => upd(() => s.contourAutoIncrement = v),
          ),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(t('elev.ask'), style: const TextStyle(fontSize: 12)),
            value: s.askElevation,
            onChanged: (v) => upd(() => s.askElevation = v),
          ),
          Text(t('elev.explainContour'), style: TextStyle(color: Cad.fg54, fontSize: 11.5)),
        ]);
      case ToolId.spot:
        items.addAll([
          NumField(label: t('props.elevation'), value: s.spotElevation, onChanged: (v) => upd(() => s.spotElevation = v)),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(t('elev.ask'), style: const TextStyle(fontSize: 12)),
            value: s.askElevation,
            onChanged: (v) => upd(() => s.askElevation = v),
          ),
          Text(t('elev.explainSpot'), style: TextStyle(color: Cad.fg54, fontSize: 11.5)),
        ]);
      case ToolId.pivot:
        items.addAll([
          SpecDropdown<PivotKind>(
            label: t('props.pivotKind'),
            value: s.pivotKind.name,
            items: PivotKind.values,
            labelOf: (k) => t(k == PivotKind.pivot ? 'pivot.kindPivot' : 'pivot.kindLinear'),
            idOf: (k) => k.name,
            onChanged: (v) => upd(() => s.pivotKind = PivotKind.values.byName(v!)),
          ),
          NumField(label: t('props.pivotSpan'), value: s.pivotSpan, onChanged: (v) => upd(() => s.pivotSpan = v <= 0 ? 50 : v)),
          if (s.pivotKind == PivotKind.linear) NumField(label: t('props.pivotTravel'), value: s.pivotTravelM, onChanged: (v) => upd(() => s.pivotTravelM = v)),
          NumField(label: t('props.pivotDepth'), value: s.pivotDepthMm, onChanged: (v) => upd(() => s.pivotDepthMm = v)),
          NumField(label: t('props.pivotHours'), value: s.pivotHours, onChanged: (v) => upd(() => s.pivotHours = v)),
          NumField(label: '${t('props.pivotEndP')} (${u.pressureLabel})', value: u.pressureFromHead(s.pivotEndPressureM), onChanged: (v) => upd(() => s.pivotEndPressureM = u.pressureToHead(v))),
          Text(t('hint.pivot'), style: TextStyle(color: Cad.fg54, fontSize: 11.5)),
        ]);
      case ToolId.alignImage:
        items.addAll([
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(t('align.keepScale'), style: const TextStyle(fontSize: 12)),
            value: s.alignKeepScale,
            onChanged: (v) => upd(() => s.alignKeepScale = v),
          ),
          Text(t('hint.alignImage'), style: TextStyle(color: Cad.fg54, fontSize: 11.5)),
          Text(
            c.selection.isEmpty ? t('msg.alignSelectFirst') : t('mob.selection', {'n': '${c.selection.length}'}),
            style: TextStyle(color: c.selection.isEmpty ? Cad.warning : Cad.fg70, fontSize: 11.5),
          ),
        ]);
      case ToolId.text:
        items.addAll([
          TextFieldRow(label: t('props.text'), value: s.text, onChanged: (v) => upd(() => s.text = v)),
          NumField(label: t('props.textHeight'), value: s.textHeight, onChanged: (v) => upd(() => s.textHeight = v)),
        ]);
      case ToolId.leader:
        items.addAll([
          TextFieldRow(label: t('props.leaderText'), value: s.leaderText, onChanged: (v) => upd(() => s.leaderText = v)),
          NumField(label: t('props.textHeight'), value: s.textHeight, onChanged: (v) => upd(() => s.textHeight = v)),
        ]);
      case ToolId.hatch:
        items.addAll([
          NumField(label: t('props.hatchAngle'), value: s.hatchAngle, onChanged: (v) => upd(() => s.hatchAngle = v)),
          NumField(label: t('props.hatchSpacing'), value: s.hatchSpacing, onChanged: (v) => upd(() => s.hatchSpacing = v <= 0 ? 1 : v)),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(t('props.hatchSolid'), style: const TextStyle(fontSize: 12)),
            value: s.hatchSolid,
            onChanged: (v) => upd(() => s.hatchSolid = v),
          ),
        ]);
      case ToolId.symbol:
        items.addAll([
          SpecDropdown<SymbolKind>(
            label: t('props.symbolKind'),
            value: s.symbolKind.name,
            items: SymbolKind.values,
            labelOf: (k) => t('sym.${k.name}'),
            idOf: (k) => k.name,
            onChanged: (v) => upd(() => s.symbolKind = SymbolKind.values.byName(v!)),
          ),
          NumField(label: t('props.symbolSize'), value: s.symbolSize, onChanged: (v) => upd(() => s.symbolSize = v <= 0 ? 1 : v)),
        ]);
      case ToolId.spline:
        items.add(
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(t('props.splineClosed'), style: const TextStyle(fontSize: 12)),
            value: s.splineClosed,
            onChanged: (v) => upd(() => s.splineClosed = v),
          ),
        );
      case ToolId.dimAngular:
        items.add(NumField(label: t('props.dimRadius'), value: s.angularDimRadius, onChanged: (v) => upd(() => s.angularDimRadius = v <= 0 ? 1 : v)));
      case ToolId.dimRadial:
        items.addAll([
          SwitchListTile(
            key: const Key('tool_radial_diameter'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(t('props.dimDiameter'), style: const TextStyle(fontSize: 12)),
            value: s.radialDiameter,
            onChanged: (v) => upd(() => s.radialDiameter = v),
          ),
          Text(t('hint.dimRadial'), style: TextStyle(color: Cad.fg54, fontSize: 11.5)),
        ]);
      case ToolId.controller:
        items.addAll([
          NumField(label: t('props.stations'), value: s.controllerStations.toDouble(), decimals: 0, onChanged: (v) => upd(() => s.controllerStations = v.round().clamp(1, 999))),
          NumField(label: t('props.outputVolts'), value: s.controllerVolts, onChanged: (v) => upd(() => s.controllerVolts = v <= 0 ? 24 : v)),
          Text(t('hint.controller'), style: TextStyle(color: Cad.fg54, fontSize: 11.5)),
        ]);
      case ToolId.offset:
        items.add(NumField(label: '${t('props.offsetDistance')} (${u.lengthLabel})', value: u.lengthFromSi(s.offsetDistance), onChanged: (v) => upd(() => s.offsetDistance = u.lengthToSi(v.abs()))));
      case ToolId.rotate:
      case ToolId.scale:
        items.add(
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(t('props.copyOnTransform'), style: const TextStyle(fontSize: 12)),
            value: s.copyOnTransform,
            onChanged: (v) => upd(() => s.copyOnTransform = v),
          ),
        );
        items.add(Text(t('hint.${hintKeyOf(tool)}'), style: TextStyle(color: Cad.fg54, fontSize: 11.5)));
      case ToolId.mirror:
        items.add(
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(t('props.mirrorKeep'), style: const TextStyle(fontSize: 12)),
            value: s.mirrorKeepSource,
            onChanged: (v) => upd(() => s.mirrorKeepSource = v),
          ),
        );
      // 1.6.0 EDT: the settings of the new editing and selection tools
      case ToolId.lasso || ToolId.fence || ToolId.fillet || ToolId.chamfer || ToolId.measure:
        items.addAll(editToolFields(c, tool));
      default:
        items.add(
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(t('hint.${hintKeyOf(tool)}'), style: TextStyle(color: Cad.fg54, fontSize: 11.5)),
          ),
        );
    }
    return ListView(padding: const EdgeInsets.all(8), children: items);
  }

  Widget _splitSwitch() => SwitchListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    title: Text(c.t('props.splitOnInsert'), style: const TextStyle(fontSize: 12)),
    value: c.toolSettings.splitPipesOnInsert,
    onChanged: (v) {
      c.toolSettings.splitPipesOnInsert = v;
      c.refresh();
    },
  );

  Widget _scopeSwitch() {
    final s = c.toolSettings;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SegmentedButton<HydraulicScope>(
        segments: [
          for (final sc in HydraulicScope.values)
            ButtonSegment(
              value: sc,
              label: Text(c.t('scope.${sc.name}'), style: const TextStyle(fontSize: 11)),
            ),
        ],
        selected: {s.pointScope},
        onSelectionChanged: (v) {
          s.pointScope = v.first;
          c.refresh();
        },
        style: const ButtonStyle(visualDensity: VisualDensity.compact),
      ),
    );
  }
}

/// Where the last vertex of [pts] goes for the path to measure [length]
/// (along the last segment); null when the last segment would vanish or
/// turn back, or has no direction.
Pt? endForLength(List<Pt> pts, double length) {
  if (pts.length < 2 || !length.isFinite) return null;
  final a = pts[pts.length - 2], seg = pts.last - a;
  if (seg.length < 1e-9) return null;
  final last = length - (polylineLength(pts) - seg.length);
  if (last <= 1e-6) return null;
  return a + seg.normalized * last;
}
