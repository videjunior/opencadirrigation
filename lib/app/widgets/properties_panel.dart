import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/design/agronomy.dart';
import '../../core/design/pivot.dart' show PivotKind;
import '../../core/model/catalog.dart';
import '../../core/model/entities.dart';
import '../../core/units.dart';
import '../state/controller.dart';
import '../theme.dart';
import '../tools/tools.dart';
import 'fields.dart';

class PropertiesPanel extends StatelessWidget {
  const PropertiesPanel({super.key, required this.c});
  final ProjectController c;

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
      Row(children: [
        Expanded(child: Text(t('tool.${_toolNameOf(e)}'), style: const TextStyle(fontWeight: FontWeight.bold))),
        IconButton(icon: const Icon(Icons.center_focus_strong, size: 16), tooltip: t('props.zoomTo'), onPressed: () => c.zoomToEntity(e.id)),
        IconButton(icon: const Icon(Icons.delete_outline, size: 16), onPressed: c.deleteSelected),
      ]),
      if (locked) Text(t('props.locked'), style: const TextStyle(fontSize: 11, color: Colors.amber)),
      TextFieldRow(label: t('props.name'), value: e.name, onChanged: (v) => c.mutate(() => e.name = v, invalidateResults: false)),
      _layerField(e),
    ];
    void set(void Function() fn, {bool inv = true}) => c.mutate(fn, invalidateResults: inv);
    String pLabel(String k) => '${t(k)} (${u.pressureLabel})';
    String qLabel(String k) => '${t(k)} (${u.flowLabel})';
    String lLabel(String k) => '${t(k)} (${u.lengthLabel})';

    switch (e) {
      case PipeEntity p:
        items.addAll([
          KV(t('props.scope'), t('scope.${p.scope.name}')),
          KV(t('props.length'), '${fmt(u.lengthFromSi(p.length))} ${u.lengthLabel}'),
          SpecDropdown<PipeSpec>(label: t('props.pipe'), value: p.pipeSpecId, items: cat.pipesFor(p.scope == HydraulicScope.zone ? PipeUsage.zone : PipeUsage.mainline), labelOf: (s) => s.name, idOf: (s) => s.id, allowNull: true, nullLabel: t('auto'), onChanged: (v) => set(() {
            p.pipeSpecId = v;
            if (v == null) p.computerSized = true;
          })),
          SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(t('props.auto'), style: const TextStyle(fontSize: 12)), value: p.computerSized, onChanged: (v) => set(() => p.computerSized = v)),
          NumField(label: t('props.depth'), value: p.depth, onChanged: (v) => set(() => p.depth = v)),
        ]);
      case SpraylineEntity s:
        final outlet = cat.outlet(s.outletSpecId);
        items.addAll([
          KV(t('props.length'), '${fmt(u.lengthFromSi(s.length))} ${u.lengthLabel}'),
          KV(t('props.outlets'), '${s.outletCount}'),
          SpecDropdown<PipeSpec>(label: t('props.pipe'), value: s.pipeSpecId, items: cat.pipesFor(PipeUsage.lateral), labelOf: (x) => x.name, idOf: (x) => x.id, allowNull: true, nullLabel: t('auto'), onChanged: (v) => set(() {
            s.pipeSpecId = v;
            if (v == null) s.computerSized = true;
          })),
          SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(t('props.auto'), style: const TextStyle(fontSize: 12)), value: s.computerSized, onChanged: (v) => set(() => s.computerSized = v)),
          SpecDropdown<OutletSpec>(label: t('props.outlet'), value: s.outletSpecId, items: cat.outlets.where((o) => o.enabled).toList(), labelOf: (x) => x.name, idOf: (x) => x.id, onChanged: (v) => set(() {
            s.outletSpecId = v ?? s.outletSpecId;
            s.nozzleId = cat.outlet(v)?.nozzles.first.id;
          })),
          if (outlet != null)
            SpecDropdown<NozzleSpec>(label: t('props.nozzle'), value: s.nozzleId, items: outlet.nozzles, labelOf: (x) => x.name, idOf: (x) => x.id, onChanged: (v) => set(() => s.nozzleId = v)),
          NumField(label: pLabel('props.head'), value: u.pressureFromHead(s.headM), onChanged: (v) => set(() => s.headM = u.pressureToHead(v))),
          NumField(label: lLabel('props.spacing'), value: u.lengthFromSi(s.spacing), onChanged: (v) => set(() => s.spacing = u.lengthToSi(v))),
          NumField(label: lLabel('props.offset'), value: u.lengthFromSi(s.offset), onChanged: (v) => set(() => s.offset = u.lengthToSi(v))),
          NumField(label: t('props.arc'), value: s.arcDeg, onChanged: (v) => set(() => s.arcDeg = v)),
          NumField(label: t('props.riser'), value: s.riserHeight, onChanged: (v) => set(() => s.riserHeight = v)),
          NumField(label: t('props.depth'), value: s.depth, onChanged: (v) => set(() => s.depth = v)),
          ..._envelope(e.id),
        ]);
      case TapeEntity tp:
        items.addAll([
          KV(t('props.length'), '${fmt(u.lengthFromSi(tp.length))} ${u.lengthLabel}'),
          SpecDropdown<TapeSpec>(label: t('props.tape'), value: tp.tapeSpecId, items: cat.tapes.where((x) => x.enabled).toList(), labelOf: (x) => x.name, idOf: (x) => x.id, onChanged: (v) => set(() => tp.tapeSpecId = v ?? tp.tapeSpecId)),
          NumField(label: pLabel('props.inlet'), value: u.pressureFromHead(tp.inletHeadM), onChanged: (v) => set(() => tp.inletHeadM = u.pressureToHead(v))),
          SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(t('props.regulated'), style: const TextStyle(fontSize: 12)), value: tp.regulated, onChanged: (v) => set(() => tp.regulated = v)),
          NumField(label: pLabel('props.submainMin'), value: u.pressureFromHead(tp.submainMinHeadM), onChanged: (v) => set(() => tp.submainMinHeadM = u.pressureToHead(v)), enabled: tp.regulated),
          NumField(label: t('props.depth'), value: tp.depth, onChanged: (v) => set(() => tp.depth = v)),
          NumField(label: qLabel('props.flushingFlow'), value: u.flowFromSi(tp.flushingFlow), onChanged: (v) => set(() => tp.flushingFlow = u.flowToSi(v))),
          ..._envelope(e.id),
        ]);
      case OutletEntity o:
        final outlet = cat.outlet(o.outletSpecId);
        final nozzle = outlet?.nozzle(o.nozzleId);
        items.addAll([
          KV(t('props.scope'), t('scope.${o.scope.name}')),
          SpecDropdown<OutletSpec>(label: t('props.outlet'), value: o.outletSpecId, items: cat.outlets.where((x) => x.enabled).toList(), labelOf: (x) => x.name, idOf: (x) => x.id, onChanged: (v) => set(() {
            o.outletSpecId = v ?? o.outletSpecId;
            o.nozzleId = cat.outlet(v)?.nozzles.first.id;
          })),
          if (outlet != null)
            SpecDropdown<NozzleSpec>(label: t('props.nozzle'), value: o.nozzleId, items: outlet.nozzles, labelOf: (x) => x.name, idOf: (x) => x.id, onChanged: (v) => set(() => o.nozzleId = v)),
          NumField(label: pLabel('props.head'), value: u.pressureFromHead(o.headM), onChanged: (v) => set(() => o.headM = u.pressureToHead(v))),
          if (nozzle != null) KV(t('result.flow'), '${fmt(u.flowFromSi(nozzle.curve.flow(o.headM)))} ${u.flowLabel}'),
          if (nozzle != null && nozzle.curve.radiusA > 0) KV(t('props.radius'), '${fmt(u.lengthFromSi(nozzle.curve.radius(o.headM)))} ${u.lengthLabel}'),
          NumField(label: t('props.arc'), value: o.arcDeg, onChanged: (v) => set(() => o.arcDeg = v)),
          NumField(label: t('props.orientation'), value: o.orientationDeg, onChanged: (v) => set(() => o.orientationDeg = v, inv: false)),
          NumField(label: t('props.riser'), value: o.riserHeight, onChanged: (v) => set(() => o.riserHeight = v)),
        ]);
      case ControlValveEntity v:
        items.addAll([
          TextFieldRow(label: t('props.zone'), value: v.zoneName, onChanged: (x) => set(() => v.zoneName = x, inv: false)),
          SpecDropdown<ValveSpec>(label: t('props.valve'), value: v.valveSpecId, items: cat.valves.where((x) => x.enabled && x.kind == ValveKind.control).toList(), labelOf: (x) => x.name, idOf: (x) => x.id, allowNull: true, onChanged: (x) => set(() => v.valveSpecId = x)),
          NumField(label: pLabel('props.fixedHead'), value: v.fixedDownstreamHeadM == null ? 0 : u.pressureFromHead(v.fixedDownstreamHeadM!), onChanged: (x) => set(() => v.fixedDownstreamHeadM = x <= 0 ? null : u.pressureToHead(x))),
          NumField(label: t('props.depth'), value: v.depth, onChanged: (x) => set(() => v.depth = x)),
        ]);
      case WaterSupplyEntity w:
        items.addAll([
          SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(t('props.calc'), style: const TextStyle(fontSize: 12)), value: w.calculatePressure, onChanged: (x) => set(() => w.calculatePressure = x)),
          NumField(label: pLabel('props.designHead'), value: u.pressureFromHead(w.designHeadM), enabled: !w.calculatePressure, onChanged: (x) => set(() => w.designHeadM = u.pressureToHead(x))),
          NumField(label: pLabel('props.maxHead'), value: u.pressureFromHead(w.maxHeadM), onChanged: (x) => set(() => w.maxHeadM = u.pressureToHead(x))),
          NumField(label: qLabel('props.designFlow'), value: u.flowFromSi(w.designFlow), onChanged: (x) => set(() => w.designFlow = u.flowToSi(x))),
          NumField(label: qLabel('props.maxFlow'), value: u.flowFromSi(w.maxFlow), onChanged: (x) => set(() => w.maxFlow = u.flowToSi(x))),
          NumField(label: t('props.waterLevel'), value: w.waterLevelOffsetM, onChanged: (x) => set(() => w.waterLevelOffsetM = x)),
        ]);
      case PumpEntity p:
        final spec = cat.pump(p.pumpSpecId);
        items.addAll([
          SpecDropdown<PumpSpec>(label: t('props.pump'), value: p.pumpSpecId, items: cat.pumps.where((x) => x.enabled).toList(), labelOf: (x) => x.name, idOf: (x) => x.id, onChanged: (x) => set(() => p.pumpSpecId = x)),
          NumField(label: t('props.speed'), value: p.speedRatio, onChanged: (x) => set(() => p.speedRatio = x)),
          if (spec != null) KV('H0', '${fmt(u.pressureFromHead(spec.curve.withSpeed(p.speedRatio).shutoffHead), 1)} ${u.pressureLabel}'),
        ]);
      case MiscHydraulicEntity m:
        final spec = cat.valve(m.valveSpecId);
        items.addAll([
          KV(t('props.scope'), t('scope.${m.scope.name}')),
          SpecDropdown<ValveSpec>(label: t('props.misc'), value: m.valveSpecId, items: cat.valves.where((x) => x.enabled && x.kind != ValveKind.control).toList(), labelOf: (x) => x.name, idOf: (x) => x.id, onChanged: (x) => set(() => m.valveSpecId = x)),
          if (spec?.kind == ValveKind.prv) NumField(label: pLabel('props.setting'), value: u.pressureFromHead(m.settingM), onChanged: (x) => set(() => m.settingM = u.pressureToHead(x))),
        ]);
      case JunctionEntity j:
        items.addAll([
          KV(t('props.scope'), t('scope.${j.scope.name}')),
          NumField(label: t('props.elevationDem'), value: j.fixedElevation ?? 0, onChanged: (x) => set(() => j.fixedElevation = x == 0 ? null : x)),
        ]);
      case ContourEntity ct:
        items.addAll([
          NumField(label: t('props.elevation'), value: ct.elevation, onChanged: (x) => set(() => ct.elevation = x)),
          KV(t('props.length'), '${fmt(u.lengthFromSi(ct.length))} ${u.lengthLabel}'),
          if (ct.derived) Text(t('props.derived'), style: const TextStyle(fontSize: 11, color: Colors.white54)),
        ]);
      case PivotEntity pv:
        final r = c.results?.pivots[pv.id];
        items.addAll([
          SpecDropdown<PivotKind>(label: t('props.pivotKind'), value: pv.kind.name, items: PivotKind.values, labelOf: (k) => t(k == PivotKind.pivot ? 'pivot.kindPivot' : 'pivot.kindLinear'), idOf: (k) => k.name, onChanged: (x) => set(() {
            pv.kind = PivotKind.values.byName(x!);
            if (pv.kind == PivotKind.linear && pv.travelM <= 0) pv.travelM = c.toolSettings.pivotTravelM;
          })),
          TextFieldRow(label: t('props.zone'), value: pv.zoneName, onChanged: (x) => set(() => pv.zoneName = x, inv: false)),
          NumField(label: t('props.pivotRadius'), value: pv.radiusM, onChanged: (x) => set(() => pv.radiusM = x <= 0 ? pv.radiusM : x)),
          NumField(label: t('props.pivotSpan'), value: pv.spanLengthM, onChanged: (x) => set(() => pv.spanLengthM = x <= 0 ? pv.spanLengthM : x)),
          if (pv.kind == PivotKind.linear) NumField(label: t('props.pivotTravel'), value: pv.travelM, onChanged: (x) => set(() => pv.travelM = x)),
          if (pv.kind == PivotKind.pivot) NumField(label: t('props.pivotSector'), value: pv.sectorDeg, onChanged: (x) => set(() => pv.sectorDeg = x.clamp(1, 360))),
          NumField(label: t('props.pivotAngle'), value: pv.angleDeg, onChanged: (x) => set(() => pv.angleDeg = x, inv: false)),
          SpecDropdown<PipeSpec>(label: t('props.pivotPipe'), value: pv.pipeSpecId, items: cat.pipesFor(PipeUsage.mainline), labelOf: (x) => x.name, idOf: (x) => x.id, allowNull: true, nullLabel: '${fmt(pv.pipeInnerMm, 0)} mm, C ${fmt(pv.hazenC, 0)}', onChanged: (v) => set(() => pv.pipeSpecId = v)),
          if (pv.pipeSpecId == null) NumField(label: t('props.pivotPipeId'), value: pv.pipeInnerMm, onChanged: (x) => set(() => pv.pipeInnerMm = x)),
          if (pv.pipeSpecId == null) NumField(label: t('props.pivotC'), value: pv.hazenC, decimals: 0, onChanged: (x) => set(() => pv.hazenC = x)),
          NumField(label: t('props.pivotHeight'), value: pv.pipeHeightM, onChanged: (x) => set(() => pv.pipeHeightM = x)),
          NumField(label: pLabel('props.pivotEndP'), value: u.pressureFromHead(pv.endPressureM), onChanged: (x) => set(() => pv.endPressureM = u.pressureToHead(x))),
          NumField(label: qLabel('props.pivotGunQ'), value: u.flowFromSi(pv.endGunFlow), onChanged: (x) => set(() => pv.endGunFlow = u.flowToSi(x))),
          if (pv.endGunFlow > 0) NumField(label: pLabel('props.pivotGunP'), value: u.pressureFromHead(pv.endGunPressureM), onChanged: (x) => set(() => pv.endGunPressureM = u.pressureToHead(x))),
          NumField(label: t('props.pivotThrow'), value: pv.endThrowM, onChanged: (x) => set(() => pv.endThrowM = x)),
          NumField(label: t('props.pivotDepth'), value: pv.grossDepthMm, onChanged: (x) => set(() => pv.grossDepthMm = x)),
          NumField(label: t('props.pivotHours'), value: pv.hoursPerCycle, onChanged: (x) => set(() => pv.hoursPerCycle = x)),
          NumField(label: t('props.pivotWidth'), value: pv.wettedWidthM, onChanged: (x) => set(() => pv.wettedWidthM = x)),
          NumField(label: t('props.pivotLoss'), value: pv.machineLossM, onChanged: (x) => set(() => pv.machineLossM = x)),
          NumField(label: t('props.pivotMaxRate'), value: pv.maxAppRateMmH, onChanged: (x) => set(() => pv.maxAppRateMmH = x)),
          NumField(label: '${t('props.pivotCost')} (${c.project.params.currency})', value: pv.machineCost, onChanged: (x) => set(() => pv.machineCost = x)),
          NumField(label: '${t('props.pivotTowerCost')} (${c.project.params.currency})', value: pv.towerCost, onChanged: (x) => set(() => pv.towerCost = x)),
          NumField(label: t('props.pivotSprSpacing'), value: pv.sprinklerSpacingM, onChanged: (x) => set(() => pv.sprinklerSpacingM = x <= 0 ? pv.sprinklerSpacingM : x)),
          SpecDropdown<OutletSpec>(label: t('props.pivotSprinkler'), value: pv.sprinklerSpecId, items: cat.outlets.where((o) => o.enabled && o.kind != OutletKind.demandPoint).toList(), labelOf: (x) => x.name, idOf: (x) => x.id, allowNull: true, onChanged: (v) => set(() => pv.sprinklerSpecId = v)),
          SpecDropdown<ValveSpec>(label: t('props.pivotRegulator'), value: pv.regulatorSpecId, items: cat.valves.where((x) => x.enabled && x.kind == ValveKind.prv).toList(), labelOf: (x) => x.name, idOf: (x) => x.id, allowNull: true, onChanged: (v) => set(() => pv.regulatorSpecId = v)),
          KV(t('props.pivotArea'), '${fmt((pv.kind == PivotKind.pivot ? 3.141592653589793 * pv.irrigatedRadius * pv.irrigatedRadius * pv.sectorDeg / 360 : pv.irrigatedRadius * pv.travelM) / 10000, 2)} ha'),
          if (r != null) ...[
            SectionTitle(t('props.pivotResults')),
            KV(t('rep.flow'), '${fmt(u.flowFromSi(r.flow), 1)} ${u.flowLabel}'),
            KV(t('props.pivotInlet'), '${fmt(u.pressureFromHead(r.inletHead), 1)} ${u.pressureLabel}'),
            if (r.availableHead != null) KV(t('rep.pAvail'), '${fmt(u.pressureFromHead(r.availableHead!), 1)} ${u.pressureLabel}'),
            KV(t('rep.hf'), '${fmt(u.pressureFromHead(r.frictionLoss), 2)} ${u.pressureLabel}'),
            KV(t('rep.rise'), '${fmt(r.elevationRise, 2)} m'),
            KV(t('rep.towers'), '${r.towerCount}'),
            KV(t('rep.sprinklers'), '${r.sprinklerCount}'),
            KV(t('rep.appRatePeak'), '${fmt(r.appRateEndPeak, 1)} mm/h'),
            for (final w in r.warnings) Text(c.t.warning(w), style: const TextStyle(fontSize: 11, color: CadColors.warning)),
          ],
        ]);
      case SpotHeightEntity sp:
        items.add(NumField(label: t('props.elevation'), value: sp.elevation, onChanged: (x) => set(() => sp.elevation = x)));
      case TextEntity tx:
        items.addAll([
          TextFieldRow(label: t('props.text'), value: tx.text, onChanged: (x) => set(() => tx.text = x, inv: false)),
          NumField(label: t('props.textHeight'), value: tx.height, onChanged: (x) => set(() => tx.height = x, inv: false)),
          NumField(label: t('props.rotation'), value: tx.rotationDeg, onChanged: (x) => set(() => tx.rotationDeg = x, inv: false)),
        ]);
      case CircleEntity ci:
        items.add(NumField(label: t('props.radius'), value: ci.radius, onChanged: (x) => set(() => ci.radius = x, inv: false)));
      case ArcEntity a:
        items.addAll([
          NumField(label: t('props.radius'), value: a.radius, onChanged: (x) => set(() => a.radius = x, inv: false)),
          KV(t('props.angle'), '${fmt(a.sweepRad * 180 / 3.141592653589793, 1)}°'),
          KV(t('props.length'), '${fmt(u.lengthFromSi(a.length))} ${u.lengthLabel}'),
        ]);
      case SplineEntity sp:
        items.addAll([
          KV(t('props.length'), '${fmt(u.lengthFromSi(sp.length))} ${u.lengthLabel}'),
          SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(t('props.closed'), style: const TextStyle(fontSize: 12)), value: sp.closed, onChanged: (x) => set(() => sp.closed = x, inv: false)),
        ]);
      case HatchEntity h:
        items.addAll([
          KV(t('props.area'), '${fmt(h.area)} m² (${fmt(h.area / 10000, 3)} ha)'),
          NumField(label: t('props.hatchAngle'), value: h.angleDeg, onChanged: (x) => set(() => h.angleDeg = x, inv: false)),
          NumField(label: t('props.hatchSpacing'), value: h.spacing, onChanged: (x) => set(() => h.spacing = x <= 0 ? 1 : x, inv: false)),
          SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(t('props.hatchSolid'), style: const TextStyle(fontSize: 12)), value: h.solid, onChanged: (x) => set(() => h.solid = x, inv: false)),
        ]);
      case SymbolEntity sy:
        items.addAll([
          SpecDropdown<SymbolKind>(label: t('props.symbolKind'), value: sy.kind.name, items: SymbolKind.values, labelOf: (k) => t('sym.${k.name}'), idOf: (k) => k.name, onChanged: (x) => set(() => sy.kind = SymbolKind.values.byName(x!), inv: false)),
          NumField(label: t('props.symbolSize'), value: sy.size, onChanged: (x) => set(() => sy.size = x <= 0 ? 1 : x, inv: false)),
          NumField(label: t('props.rotation'), value: sy.rotationDeg, onChanged: (x) => set(() => sy.rotationDeg = x, inv: false)),
        ]);
      case PolylineEntity pl:
        items.addAll([
          KV(t('props.length'), '${fmt(u.lengthFromSi(pl.length))} ${u.lengthLabel}'),
          if (pl.closed) KV(t('props.area'), '${fmt(pl.area)} m² (${fmt(pl.area / 10000, 3)} ha)'),
          SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(t('props.closed'), style: const TextStyle(fontSize: 12)), value: pl.closed, onChanged: (x) => set(() => pl.closed = x, inv: false)),
        ]);
      case LineEntity l:
        items.add(KV(t('props.length'), '${fmt(u.lengthFromSi(l.length))} ${u.lengthLabel}'));
      case DimensionEntity d:
        items.add(NumField(label: t('props.dimOffset'), value: d.offset, onChanged: (x) => set(() => d.offset = x, inv: false)));
      case AngularDimensionEntity ad:
        items.addAll([
          KV(t('props.angle'), '${fmt(ad.angleDeg, 2)}°'),
          NumField(label: t('props.dimRadius'), value: ad.radius, onChanged: (x) => set(() => ad.radius = x <= 0 ? 1 : x, inv: false)),
        ]);
      case RadialDimensionEntity rd:
        items.add(KV(t('props.radius'), '${fmt(u.lengthFromSi(rd.radius))} ${u.lengthLabel}'));
      case LeaderEntity le:
        items.addAll([
          TextFieldRow(label: t('props.text'), value: le.text, onChanged: (x) => set(() => le.text = x, inv: false)),
          NumField(label: t('props.textHeight'), value: le.height, onChanged: (x) => set(() => le.height = x, inv: false)),
        ]);
      case ImageEntity im:
        items.addAll([
          KV(t('props.source'), im.source),
          NumField(label: t('props.imageWidth'), value: im.width, onChanged: (x) => set(() => im.width = x <= 0 ? 1 : x, inv: false)),
          NumField(label: t('props.imageHeight'), value: im.height, onChanged: (x) => set(() => im.height = x <= 0 ? 1 : x, inv: false)),
          NumField(label: t('props.rotation'), value: im.rotationDeg, onChanged: (x) => set(() => im.rotationDeg = x, inv: false)),
          NumField(label: t('props.opacity'), value: im.opacity, onChanged: (x) => set(() => im.opacity = x.clamp(0.05, 1.0), inv: false)),
        ]);
      case AreaEntity a:
        items.addAll(_areaFields(a, set));
      default:
        break;
    }
    items.addAll(_results(e));
    return ListView(padding: const EdgeInsets.all(8), children: items);
  }

  List<Widget> _areaFields(AreaEntity a, void Function(void Function() fn, {bool inv}) set) {
    final t = c.t;
    final crop = cropWaterRequirements(c.project, c.results).where((x) => x.areaId == a.id).firstOrNull;
    return [
      KV(t('props.area'), '${fmt(a.area)} m² (${fmt(a.area / 10000, 3)} ha)'),
      TextFieldRow(label: t('props.crop'), value: a.crop, onChanged: (x) => set(() => a.crop = x, inv: false)),
      SpecDropdown<String>(label: t('props.kcPreset'), value: 'crop.custom', items: ['crop.custom', ...cropKcTable.keys], labelOf: (k) => k == 'crop.custom' ? t(k) : '${t(k)} (Kc ${cropKcTable[k]!.$2})', idOf: (k) => k, onChanged: (k) {
        if (k == null || k == 'crop.custom') return;
        set(() {
          a.kc = cropKcTable[k]!.$2;
          a.useWaterBalance = true;
          if (a.crop.isEmpty) a.crop = t(k);
        }, inv: false);
      }),
      NumField(label: t('props.efficiency'), value: a.efficiency, onChanged: (x) => set(() => a.efficiency = x.clamp(0.05, 1.0), inv: false)),
      NumField(label: t('props.emittersPerPlant'), value: a.emittersPerPlant.toDouble(), decimals: 0, onChanged: (x) => set(() => a.emittersPerPlant = x.round().clamp(0, 20))),
      SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(t('props.waterBalance'), style: const TextStyle(fontSize: 12)), value: a.useWaterBalance, onChanged: (x) => set(() => a.useWaterBalance = x, inv: false)),
      if (!a.useWaterBalance) NumField(label: t('props.netDepth'), value: a.netDepthMmPerDay, onChanged: (x) => set(() => a.netDepthMmPerDay = x, inv: false)),
      if (a.useWaterBalance) ...[
        NumField(label: t('props.eto'), value: a.etoMmDay, onChanged: (x) => set(() => a.etoMmDay = x, inv: false)),
        NumField(label: t('props.kc'), value: a.kc, onChanged: (x) => set(() => a.kc = x, inv: false)),
        NumField(label: t('props.awc'), value: a.awcMmPerM, decimals: 0, onChanged: (x) => set(() => a.awcMmPerM = x, inv: false)),
        NumField(label: t('props.rootDepth'), value: a.rootDepthM, onChanged: (x) => set(() => a.rootDepthM = x, inv: false)),
        NumField(label: t('props.mad'), value: a.mad, onChanged: (x) => set(() => a.mad = x.clamp(0.05, 0.95), inv: false)),
        NumField(label: t('props.wettedFraction'), value: a.wettedFraction, onChanged: (x) => set(() => a.wettedFraction = x.clamp(0.05, 1.0), inv: false)),
        KV(t('props.etc'), fmt(a.etcMmDay, 2)),
      ],
      if (crop != null) ...[
        KV(t('props.interval'), fmt(crop.intervalDays, 0)),
        KV(t('rep.grossEvent'), '${fmt(crop.grossDepthMm, 1)} mm'),
        KV(t('rep.hoursEvent'), '${fmt(crop.hoursPerEvent, 2)} h'),
      ],
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
      Text(ok.isEmpty ? t('props.envelopeNone') : t('props.envelopeRange', {'a': (ok.first.fraction * 100).round().toString(), 'b': (ok.last.fraction * 100).round().toString()}), style: TextStyle(fontSize: 11.5, color: ok.isEmpty ? CadColors.warning : CadColors.ok)),
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
      byType[_toolNameOf(e)] = (byType[_toolNameOf(e)] ?? 0) + 1;
    }
    final dominant = byType.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final items = <Widget>[
      Text(t('props.multi', {'n': '${sel.length}'}), style: const TextStyle(fontWeight: FontWeight.bold)),
      Text(byType.entries.map((e) => '${e.value} × ${t('tool.${e.key}')}').join(', '), style: const TextStyle(fontSize: 11, color: Colors.white54)),
      const SizedBox(height: 4),
      _layerField(sel.first),
    ];
    String pLabel(String k) => '${t(k)} (${u.pressureLabel})';
    String lLabel(String k) => '${t(k)} (${u.lengthLabel})';
    T? common<T>(Iterable<T?> values) {
      final list = values.toList();
      if (list.isEmpty) return null;
      final first = list.first;
      return list.every((v) => v == first) ? first : null;
    }

    Widget mixedNote() => Text(t('props.mixed'), style: const TextStyle(fontSize: 10.5, color: Colors.white38));
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
          SpecDropdown<PipeSpec>(label: t('props.pipe'), value: pipe, items: cat.pipesFor(PipeUsage.lateral), labelOf: (x) => x.name, idOf: (x) => x.id, allowNull: true, nullLabel: pipe == null && s.any((e) => e.pipeSpecId != null) ? t('props.mixed') : t('auto'), onChanged: (v) => c.mutateSelected<SpraylineEntity>((e) {
            e.pipeSpecId = v;
            if (v == null) e.computerSized = true;
          })),
          SpecDropdown<OutletSpec>(label: t('props.outlet'), value: outlet, items: cat.outlets.where((o) => o.enabled).toList(), labelOf: (x) => x.name, idOf: (x) => x.id, allowNull: outlet == null, nullLabel: t('props.mixed'), onChanged: (v) {
            if (v == null) return;
            c.mutateSelected<SpraylineEntity>((e) {
              e.outletSpecId = v;
              e.nozzleId = cat.outlet(v)?.nozzles.first.id;
            });
          }),
          if (outletSpec != null) SpecDropdown<NozzleSpec>(label: t('props.nozzle'), value: nozzle, items: outletSpec.nozzles, labelOf: (x) => x.name, idOf: (x) => x.id, allowNull: nozzle == null, nullLabel: t('props.mixed'), onChanged: (v) => c.mutateSelected<SpraylineEntity>((e) => e.nozzleId = v)),
          NumField(label: pLabel('props.head'), value: head == null ? 0 : u.pressureFromHead(head), onChanged: (v) => c.mutateSelected<SpraylineEntity>((e) => e.headM = u.pressureToHead(v))),
          if (head == null) mixedNote(),
          NumField(label: lLabel('props.spacing'), value: spacing == null ? 0 : u.lengthFromSi(spacing), onChanged: (v) => c.mutateSelected<SpraylineEntity>((e) => e.spacing = u.lengthToSi(v))),
          if (spacing == null) mixedNote(),
        ]);
      case 'tape':
        final s = sel.whereType<TapeEntity>().toList();
        final spec = common(s.map((e) => e.tapeSpecId));
        final inlet = common(s.map((e) => e.inletHeadM));
        items.addAll([
          SpecDropdown<TapeSpec>(label: t('props.tape'), value: spec, items: cat.tapes.where((x) => x.enabled).toList(), labelOf: (x) => x.name, idOf: (x) => x.id, allowNull: spec == null, nullLabel: t('props.mixed'), onChanged: (v) {
            if (v != null) c.mutateSelected<TapeEntity>((e) => e.tapeSpecId = v);
          }),
          NumField(label: pLabel('props.inlet'), value: inlet == null ? 0 : u.pressureFromHead(inlet), onChanged: (v) => c.mutateSelected<TapeEntity>((e) => e.inletHeadM = u.pressureToHead(v))),
          if (inlet == null) mixedNote(),
        ]);
      case 'zonePipe':
      case 'mainPipe':
        final s = sel.whereType<PipeEntity>().toList();
        final scope = common(s.map((e) => e.scope)) ?? HydraulicScope.zone;
        final spec = common(s.map((e) => e.pipeSpecId));
        final depth = common(s.map((e) => e.depth));
        items.addAll([
          SpecDropdown<PipeSpec>(label: t('props.pipe'), value: spec, items: cat.pipesFor(scope == HydraulicScope.zone ? PipeUsage.zone : PipeUsage.mainline), labelOf: (x) => x.name, idOf: (x) => x.id, allowNull: true, nullLabel: spec == null && s.any((e) => e.pipeSpecId != null) ? t('props.mixed') : t('auto'), onChanged: (v) => c.mutateSelected<PipeEntity>((e) {
            e.pipeSpecId = v;
            if (v == null) e.computerSized = true;
          })),
          SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(t('props.auto'), style: const TextStyle(fontSize: 12)), value: s.every((e) => e.computerSized), onChanged: (v) => c.mutateSelected<PipeEntity>((e) => e.computerSized = v)),
          NumField(label: t('props.depth'), value: depth ?? 0, onChanged: (v) => c.mutateSelected<PipeEntity>((e) => e.depth = v)),
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
          SpecDropdown<OutletSpec>(label: t('props.outlet'), value: outlet, items: cat.outlets.where((o) => o.enabled).toList(), labelOf: (x) => x.name, idOf: (x) => x.id, allowNull: outlet == null, nullLabel: t('props.mixed'), onChanged: (v) {
            if (v == null) return;
            c.mutateSelected<OutletEntity>((e) {
              e.outletSpecId = v;
              e.nozzleId = cat.outlet(v)?.nozzles.first.id;
            });
          }),
          if (outletSpec != null) SpecDropdown<NozzleSpec>(label: t('props.nozzle'), value: nozzle, items: outletSpec.nozzles, labelOf: (x) => x.name, idOf: (x) => x.id, allowNull: nozzle == null, nullLabel: t('props.mixed'), onChanged: (v) => c.mutateSelected<OutletEntity>((e) => e.nozzleId = v)),
          NumField(label: pLabel('props.head'), value: head == null ? 0 : u.pressureFromHead(head), onChanged: (v) => c.mutateSelected<OutletEntity>((e) => e.headM = u.pressureToHead(v))),
          if (head == null) mixedNote(),
          NumField(label: t('props.arc'), value: arc ?? 0, onChanged: (v) => c.mutateSelected<OutletEntity>((e) => e.arcDeg = v)),
        ]);
      case 'valve':
        final s = sel.whereType<ControlValveEntity>().toList();
        final spec = common(s.map((e) => e.valveSpecId));
        items.add(SpecDropdown<ValveSpec>(label: t('props.valve'), value: spec, items: cat.valves.where((x) => x.enabled && x.kind == ValveKind.control).toList(), labelOf: (x) => x.name, idOf: (x) => x.id, allowNull: true, nullLabel: t('props.mixed'), onChanged: (v) => c.mutateSelected<ControlValveEntity>((e) => e.valveSpecId = v)));
      case 'contour':
        final s = sel.whereType<ContourEntity>().toList();
        final z = common(s.map((e) => e.elevation));
        items.addAll([
          NumField(label: t('props.elevation'), value: z ?? 0, onChanged: (v) => c.mutateSelected<ContourEntity>((e) => e.elevation = v)),
          if (z == null) mixedNote(),
        ]);
      case 'spot':
        final s = sel.whereType<SpotHeightEntity>().toList();
        final z = common(s.map((e) => e.elevation));
        items.addAll([
          NumField(label: t('props.elevation'), value: z ?? 0, onChanged: (v) => c.mutateSelected<SpotHeightEntity>((e) => e.elevation = v)),
          if (z == null) mixedNote(),
        ]);
      case 'text':
        final s = sel.whereType<TextEntity>().toList();
        final h = common(s.map((e) => e.height));
        items.add(NumField(label: t('props.textHeight'), value: h ?? 1, onChanged: (v) => c.mutateSelected<TextEntity>((e) => e.height = v, invalidateResults: false)));
      case 'area':
        final s = sel.whereType<AreaEntity>().toList();
        final eff = common(s.map((e) => e.efficiency));
        items.addAll([
          NumField(label: t('props.efficiency'), value: eff ?? 0.9, onChanged: (v) => c.mutateSelected<AreaEntity>((e) => e.efficiency = v.clamp(0.05, 1.0), invalidateResults: false)),
          NumField(label: t('props.eto'), value: common(s.map((e) => e.etoMmDay)) ?? 5, onChanged: (v) => c.mutateSelected<AreaEntity>((e) => e.etoMmDay = v, invalidateResults: false)),
        ]);
      default:
        break;
    }
    items.addAll([
      const SizedBox(height: 8),
      FilledButton.tonalIcon(onPressed: c.deleteSelected, icon: const Icon(Icons.delete_outline, size: 16), label: Text(t('edit.delete'))),
    ]);
    return ListView(padding: const EdgeInsets.all(8), children: items);
  }

  Widget _layerField(Entity e) => SpecDropdown<String>(label: c.t('props.layer'), value: e.layer, items: c.project.layers.map((l) => l.name).toList(), labelOf: (s) => s, idOf: (s) => s, onChanged: (v) {
    if (v == null) return;
    c.mutate(() {
      for (final x in c.project.entities.where((x) => c.selection.contains(x.id))) {
        x.layer = v;
      }
    }, invalidateResults: false);
  });

  String _toolNameOf(Entity e) => switch (e) {
    LineEntity _ => 'line',
    PolylineEntity _ => 'polyline',
    CircleEntity _ => 'circle',
    ArcEntity _ => 'arc',
    SplineEntity _ => 'spline',
    HatchEntity _ => 'hatch',
    SymbolEntity _ => 'symbol',
    TextEntity _ => 'text',
    DimensionEntity _ => 'dimension',
    AngularDimensionEntity _ => 'dimAngular',
    RadialDimensionEntity _ => 'dimRadial',
    LeaderEntity _ => 'leader',
    ImageEntity _ => 'image',
    ContourEntity _ => 'contour',
    SpotHeightEntity _ => 'spot',
    PipeEntity p => p.scope == HydraulicScope.zone ? 'zonePipe' : 'mainPipe',
    SpraylineEntity _ => 'sprayline',
    TapeEntity _ => 'tape',
    OutletEntity _ => 'outlet',
    ControlValveEntity _ => 'valve',
    WaterSupplyEntity _ => 'supply',
    PumpEntity _ => 'pump',
    MiscHydraulicEntity _ => 'misc',
    JunctionEntity _ => 'junction',
    PivotEntity _ => 'pivot',
    AreaEntity _ => 'area',
    _ => 'select',
  };

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
        KV(t('props.emitterMinMax'), '${fmt(u.pressureFromHead(z.minOutletPressure), 1)} / ${fmt(u.pressureFromHead(z.maxOutletPressure), 1)}', color: z.withinWindow ? CadColors.ok : CadColors.warning),
        KV(t('props.allowed'), '${fmt(u.pressureFromHead(z.allowedMin), 1)} / ${fmt(u.pressureFromHead(z.allowedMax), 1)}'),
        KV(t('props.uniformity'), '${fmt(z.uniformity.cu, 1)} / ${fmt(z.uniformity.du, 1)} / ${fmt(z.uniformity.eu, 1)} %'),
        if (z.overlapCu > 0) KV(t('rep.overlapCu'), fmt(z.overlapCu, 0)),
        for (final w in z.warnings) Text(c.t.warning(w, entityName: (id) => c.project.byId(id)?.name ?? id), style: const TextStyle(fontSize: 11, color: CadColors.warning)),
      ]);
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
        KV(t('result.velocity'), '${fmt(vmax)} m/s', color: pipes.any((p) => p.overVelocity) ? CadColors.warning : null),
        KV(t('result.loss'), '${fmt(u.pressureFromHead(loss), 2)} ${u.pressureLabel}'),
        KV(t('result.pStart'), '${fmt(u.pressureFromHead(pStart), 1)} ${u.pressureLabel}'),
        KV(t('result.pEnd'), '${fmt(u.pressureFromHead(pEnd), 1)} ${u.pressureLabel}'),
      ]);
      final sr = r.surge.where((s) => s.entityId == e.id).firstOrNull;
      if (sr != null) out.add(KV(t('reports.surge'), '+${fmt(u.pressureFromHead(sr.surgeHead), 1)} → ${fmt(u.pressureFromHead(sr.totalHead), 1)} ${u.pressureLabel}', color: sr.exceeds ? CadColors.warning : null));
    }
    final outs = r.outletsByEntity[e.id];
    if (outs != null && outs.isNotEmpty) {
      final pmin = outs.map((o) => o.pressure).reduce((a, b) => a < b ? a : b);
      final pmax = outs.map((o) => o.pressure).reduce((a, b) => a > b ? a : b);
      final q = outs.fold<double>(0, (s, o) => s + o.flow * o.count);
      out.addAll([
        KV('${t('result.pressure')} ${t('result.min')}/${t('result.max')}', '${fmt(u.pressureFromHead(pmin), 1)} / ${fmt(u.pressureFromHead(pmax), 1)} ${u.pressureLabel}', color: outs.every((o) => o.inWindow) ? CadColors.ok : CadColors.warning),
        KV(t('result.flow'), '${fmt(u.flowFromSi(q))} ${u.flowLabel}'),
      ]);
    }
    if (e is WaterSupplyEntity) {
      for (final f in r.systemFlows) {
        for (final d in f.supplies.where((d) => d.supplyId == e.id)) {
          final surplus = d.surplusHead > 0.05 ? ' (${t('rep.surplus')} ${fmt(u.pressureFromHead(d.surplusHead), 1)})' : '';
          out.add(KV(f.name, '${fmt(u.flowFromSi(d.flow))} ${u.flowLabel} @ ${fmt(u.pressureFromHead(math.max(0, d.requiredHead)), 1)} ${u.pressureLabel}$surplus', color: d.headExceedsMax || d.flowExceedsDesign ? CadColors.warning : null));
        }
      }
    }
    if (e is PumpEntity || e is MiscHydraulicEntity) {
      for (final f in r.systemFlows) {
        for (final d in f.devices.where((d) => d.entityId == e.id)) {
          out.add(KV(f.name, e is PumpEntity ? '${fmt(u.flowFromSi(d.flow))} ${u.flowLabel} / H ${fmt(u.pressureFromHead(d.pumpHead), 1)}' : 'Δh ${fmt(u.pressureFromHead(d.headLoss), 2)} ${u.pressureLabel}'));
        }
      }
      for (final z in r.zones.values) {
        for (final d in z.devices.where((d) => d.entityId == e.id)) {
          out.add(KV(z.zoneName, 'Δh ${fmt(u.pressureFromHead(d.headLoss), 2)} ${u.pressureLabel}'));
        }
      }
    }
    if (out.length == 1) out.add(const Text('—', style: TextStyle(color: Colors.white38)));
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
        items.add(SpecDropdown<PipeSpec>(label: t('props.pipe'), value: s.zonePipeSpecId, items: cat.pipesFor(PipeUsage.zone), labelOf: (x) => x.name, idOf: (x) => x.id, allowNull: true, nullLabel: t('auto'), onChanged: (v) => upd(() => s.zonePipeSpecId = v)));
      case ToolId.mainPipe:
        items.add(SpecDropdown<PipeSpec>(label: t('props.pipe'), value: s.mainPipeSpecId, items: cat.pipesFor(PipeUsage.mainline), labelOf: (x) => x.name, idOf: (x) => x.id, allowNull: true, nullLabel: t('auto'), onChanged: (v) => upd(() => s.mainPipeSpecId = v)));
      case ToolId.sprayline:
      case ToolId.outlet:
      case ToolId.autohead:
        final outlet = cat.outlet(s.outletSpecId);
        items.addAll([
          if (tool == ToolId.sprayline) SpecDropdown<PipeSpec>(label: t('props.pipe'), value: s.lateralPipeSpecId, items: cat.pipesFor(PipeUsage.lateral), labelOf: (x) => x.name, idOf: (x) => x.id, allowNull: true, nullLabel: t('auto'), onChanged: (v) => upd(() => s.lateralPipeSpecId = v)),
          SpecDropdown<OutletSpec>(label: t('props.outlet'), value: s.outletSpecId, items: cat.outlets.where((o) => o.enabled).toList(), labelOf: (x) => x.name, idOf: (x) => x.id, onChanged: (v) => upd(() {
            s.outletSpecId = v ?? s.outletSpecId;
            final o = cat.outlet(s.outletSpecId);
            s.nozzleId = o?.nozzles.first.id;
            s.headM = o?.nozzles.first.defaultHeadM ?? s.headM;
          })),
          if (outlet != null) SpecDropdown<NozzleSpec>(label: t('props.nozzle'), value: s.nozzleId, items: outlet.nozzles, labelOf: (x) => x.name, idOf: (x) => x.id, onChanged: (v) => upd(() {
            s.nozzleId = v;
            s.headM = outlet.nozzle(v)?.defaultHeadM ?? s.headM;
          })),
          NumField(label: '${t('props.head')} (${u.pressureLabel})', value: u.pressureFromHead(s.headM), onChanged: (v) => upd(() => s.headM = u.pressureToHead(v))),
          if (tool == ToolId.sprayline) NumField(label: '${t('props.spacing')} (${u.lengthLabel})', value: u.lengthFromSi(s.spacing), onChanged: (v) => upd(() => s.spacing = u.lengthToSi(v))),
          if (tool == ToolId.sprayline) SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(t('props.halfSpacing'), style: const TextStyle(fontSize: 12)), value: s.outletOffsetHalf, onChanged: (v) => upd(() => s.outletOffsetHalf = v)),
          if (tool == ToolId.outlet) NumField(label: t('props.arc'), value: s.arcDeg, onChanged: (v) => upd(() => s.arcDeg = v)),
          if (tool == ToolId.outlet) _scopeSwitch(),
        ]);
      case ToolId.tape:
        items.addAll([
          SpecDropdown<TapeSpec>(label: t('props.tape'), value: s.tapeSpecId, items: cat.tapes.where((x) => x.enabled).toList(), labelOf: (x) => x.name, idOf: (x) => x.id, onChanged: (v) => upd(() {
            s.tapeSpecId = v ?? s.tapeSpecId;
            s.tapeInletHeadM = cat.tape(s.tapeSpecId)?.defaultInletHeadM ?? s.tapeInletHeadM;
          })),
          NumField(label: '${t('props.inlet')} (${u.pressureLabel})', value: u.pressureFromHead(s.tapeInletHeadM), onChanged: (v) => upd(() => s.tapeInletHeadM = u.pressureToHead(v))),
        ]);
      case ToolId.valve:
        items.addAll([
          SpecDropdown<ValveSpec>(label: t('props.valve'), value: s.valveSpecId, items: cat.valves.where((x) => x.enabled && x.kind == ValveKind.control).toList(), labelOf: (x) => x.name, idOf: (x) => x.id, onChanged: (v) => upd(() => s.valveSpecId = v ?? s.valveSpecId)),
          _splitSwitch(),
        ]);
      case ToolId.pump:
        items.addAll([
          SpecDropdown<PumpSpec>(label: t('props.pump'), value: s.pumpSpecId, items: cat.pumps.where((x) => x.enabled).toList(), labelOf: (x) => x.name, idOf: (x) => x.id, onChanged: (v) => upd(() => s.pumpSpecId = v ?? s.pumpSpecId)),
          _scopeSwitch(),
          _splitSwitch(),
        ]);
      case ToolId.misc:
        final spec = cat.valve(s.miscSpecId);
        items.addAll([
          SpecDropdown<ValveSpec>(label: t('props.misc'), value: s.miscSpecId, items: cat.valves.where((x) => x.enabled && x.kind != ValveKind.control).toList(), labelOf: (x) => x.name, idOf: (x) => x.id, onChanged: (v) => upd(() {
            s.miscSpecId = v ?? s.miscSpecId;
            s.miscSettingM = cat.valve(s.miscSpecId)?.defaultSettingM ?? 0;
          })),
          if (spec?.kind == ValveKind.prv) NumField(label: '${t('props.setting')} (${u.pressureLabel})', value: u.pressureFromHead(s.miscSettingM), onChanged: (v) => upd(() => s.miscSettingM = u.pressureToHead(v))),
          _scopeSwitch(),
          _splitSwitch(),
        ]);
      case ToolId.junction:
        items.addAll([_scopeSwitch(), _splitSwitch()]);
      case ToolId.contour:
        items.addAll([
          NumField(label: t('props.elevation'), value: s.contourElevation, onChanged: (v) => upd(() => s.contourElevation = v)),
          NumField(label: t('props.contourInterval'), value: s.contourInterval, onChanged: (v) => upd(() => s.contourInterval = v)),
          SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(t('props.contourSmooth'), style: const TextStyle(fontSize: 12)), value: s.contourSmooth, onChanged: (v) => upd(() => s.contourSmooth = v)),
          SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(t('elev.autoIncrement'), style: const TextStyle(fontSize: 12)), value: s.contourAutoIncrement, onChanged: (v) => upd(() => s.contourAutoIncrement = v)),
          SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(t('elev.ask'), style: const TextStyle(fontSize: 12)), value: s.askElevation, onChanged: (v) => upd(() => s.askElevation = v)),
          Text(t('elev.explainContour'), style: const TextStyle(color: Colors.white54, fontSize: 11.5)),
        ]);
      case ToolId.spot:
        items.addAll([
          NumField(label: t('props.elevation'), value: s.spotElevation, onChanged: (v) => upd(() => s.spotElevation = v)),
          SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(t('elev.ask'), style: const TextStyle(fontSize: 12)), value: s.askElevation, onChanged: (v) => upd(() => s.askElevation = v)),
          Text(t('elev.explainSpot'), style: const TextStyle(color: Colors.white54, fontSize: 11.5)),
        ]);
      case ToolId.pivot:
        items.addAll([
          SpecDropdown<PivotKind>(label: t('props.pivotKind'), value: s.pivotKind.name, items: PivotKind.values, labelOf: (k) => t(k == PivotKind.pivot ? 'pivot.kindPivot' : 'pivot.kindLinear'), idOf: (k) => k.name, onChanged: (v) => upd(() => s.pivotKind = PivotKind.values.byName(v!))),
          NumField(label: t('props.pivotSpan'), value: s.pivotSpan, onChanged: (v) => upd(() => s.pivotSpan = v <= 0 ? 50 : v)),
          if (s.pivotKind == PivotKind.linear) NumField(label: t('props.pivotTravel'), value: s.pivotTravelM, onChanged: (v) => upd(() => s.pivotTravelM = v)),
          NumField(label: t('props.pivotDepth'), value: s.pivotDepthMm, onChanged: (v) => upd(() => s.pivotDepthMm = v)),
          NumField(label: t('props.pivotHours'), value: s.pivotHours, onChanged: (v) => upd(() => s.pivotHours = v)),
          NumField(label: '${t('props.pivotEndP')} (${u.pressureLabel})', value: u.pressureFromHead(s.pivotEndPressureM), onChanged: (v) => upd(() => s.pivotEndPressureM = u.pressureToHead(v))),
          Text(t('hint.pivot'), style: const TextStyle(color: Colors.white54, fontSize: 11.5)),
        ]);
      case ToolId.alignImage:
        items.addAll([
          SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(t('align.keepScale'), style: const TextStyle(fontSize: 12)), value: s.alignKeepScale, onChanged: (v) => upd(() => s.alignKeepScale = v)),
          Text(t('hint.alignImage'), style: const TextStyle(color: Colors.white54, fontSize: 11.5)),
          Text(c.selection.isEmpty ? t('msg.alignSelectFirst') : t('mob.selection', {'n': '${c.selection.length}'}), style: TextStyle(color: c.selection.isEmpty ? CadColors.warning : Colors.white70, fontSize: 11.5)),
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
          SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(t('props.hatchSolid'), style: const TextStyle(fontSize: 12)), value: s.hatchSolid, onChanged: (v) => upd(() => s.hatchSolid = v)),
        ]);
      case ToolId.symbol:
        items.addAll([
          SpecDropdown<SymbolKind>(label: t('props.symbolKind'), value: s.symbolKind.name, items: SymbolKind.values, labelOf: (k) => t('sym.${k.name}'), idOf: (k) => k.name, onChanged: (v) => upd(() => s.symbolKind = SymbolKind.values.byName(v!))),
          NumField(label: t('props.symbolSize'), value: s.symbolSize, onChanged: (v) => upd(() => s.symbolSize = v <= 0 ? 1 : v)),
        ]);
      case ToolId.spline:
        items.add(SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(t('props.splineClosed'), style: const TextStyle(fontSize: 12)), value: s.splineClosed, onChanged: (v) => upd(() => s.splineClosed = v)));
      case ToolId.dimAngular:
        items.add(NumField(label: t('props.dimRadius'), value: s.angularDimRadius, onChanged: (v) => upd(() => s.angularDimRadius = v <= 0 ? 1 : v)));
      case ToolId.offset:
        items.add(NumField(label: '${t('props.offsetDistance')} (${u.lengthLabel})', value: u.lengthFromSi(s.offsetDistance), onChanged: (v) => upd(() => s.offsetDistance = u.lengthToSi(v.abs()))));
      case ToolId.rotate:
      case ToolId.scale:
        items.add(SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(t('props.copyOnTransform'), style: const TextStyle(fontSize: 12)), value: s.copyOnTransform, onChanged: (v) => upd(() => s.copyOnTransform = v)));
        items.add(Text(t('hint.${hintKeyOf(tool)}'), style: const TextStyle(color: Colors.white54, fontSize: 11.5)));
      case ToolId.mirror:
        items.add(SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(t('props.mirrorKeep'), style: const TextStyle(fontSize: 12)), value: s.mirrorKeepSource, onChanged: (v) => upd(() => s.mirrorKeepSource = v)));
      default:
        items.add(Padding(padding: const EdgeInsets.only(top: 8), child: Text(t('hint.${hintKeyOf(tool)}'), style: const TextStyle(color: Colors.white54, fontSize: 11.5))));
    }
    return ListView(padding: const EdgeInsets.all(8), children: items);
  }

  Widget _splitSwitch() => SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(c.t('props.splitOnInsert'), style: const TextStyle(fontSize: 12)), value: c.toolSettings.splitPipesOnInsert, onChanged: (v) {
    c.toolSettings.splitPipesOnInsert = v;
    c.refresh();
  });

  Widget _scopeSwitch() {
    final s = c.toolSettings;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SegmentedButton<HydraulicScope>(
        segments: [for (final sc in HydraulicScope.values) ButtonSegment(value: sc, label: Text(c.t('scope.${sc.name}'), style: const TextStyle(fontSize: 11)))],
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
