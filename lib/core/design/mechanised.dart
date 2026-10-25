/// Mechanised machines of a design: the sprinkler package (nozzle chart)
/// and timer chart of every centre pivot and linear move and, when their
/// data are given, the corner arm, the variable-rate prescription and the
/// electrical design (see `pivot_package.dart`, `corner_arm.dart`,
/// `vri.dart` and `pivot_electrical.dart`).
library;

import 'dart:math' as math;

import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import '../model/terrain.dart';
import 'corner_arm.dart';
import 'pivot.dart';
import 'pivot_electrical.dart';
import 'pivot_package.dart';
import 'vri.dart';

/// Hydraulic data of pivot entity [p] for the machine analyses: the span
/// pipe of the catalogue (or the typed bore and C), the design friction
/// method and the machine data.
PivotSpec pivotSpecOf(Project project, PivotEntity p) {
  final params = project.params;
  final pipe = project.catalog.pipe(p.pipeSpecId);
  return PivotSpec(
    kind: p.kind,
    lengthM: p.radiusM,
    travelM: p.travelM,
    spanLengthM: p.spanLengthM,
    pipeInnerMm: pipe?.innerDiameterMm ?? p.pipeInnerMm,
    hazenC: params.adjustedC(pipe?.hazenC ?? p.hazenC),
    roughnessMm: pipe?.roughnessMm ?? 0.15,
    method: params.frictionMethod,
    kinematicViscosity: params.kinematicViscosity,
    pipeHeightM: p.pipeHeightM,
    endPressureM: p.endPressureM,
    endGunFlow: p.endGunFlow,
    endGunPressureM: p.endGunPressureM,
    endThrowM: p.endThrowM,
    grossDepthMm: p.grossDepthMm,
    hoursPerCycle: p.hoursPerCycle,
    wettedWidthM: p.wettedWidthM,
    machineLossM: p.machineLossM,
    maxAppRateMmH: p.maxAppRateMmH,
    sectorDeg: p.sectorDeg,
    maxVelocity: math.max(params.maxMainlineVelocity, 3.0),
    sprinklerSpacingM: p.sprinklerSpacingM,
  );
}

/// The package data of [p] with its machine data, the inlet at
/// [availableInletHeadM] (0 = the head the package needs).
PivotPackageSpec pivotPackageSpecOf(PivotSpec spec, PivotEntity p, {double availableInletHeadM = 0}) {
  final m = p.machine;
  final n = spec.towerCount;
  PivotSpanDef span(double len, {bool overhang = false}) => PivotSpanDef(
    lengthM: len, pipeInnerMm: spec.pipeInnerMm, hazenC: spec.hazenC, roughnessMm: spec.roughnessMm, outletSpacingM: spec.sprinklerSpacingM, overhang: overhang, archM: overhang ? 0 : m.spanArchM,
  );
  final spans = n == 0 ? [span(spec.lengthM)] : [for (var i = 0; i < n; i++) span(spec.spanLengthM), if (spec.overhangM > 1e-6) span(spec.overhangM, overhang: true)];
  final gun = switch (m.endGun) {
    'none' => EndGunUse.none,
    'fullCircle' => EndGunUse.fullCircle,
    'corners' => EndGunUse.corners,
    _ => spec.endGunFlow > 0 ? EndGunUse.corners : EndGunUse.none,
  };
  return PivotPackageSpec(
    spans: spans, kind: spec.kind, endThrowM: spec.endThrowM, endGun: gun, endGunFlow: spec.endGunFlow, endGunPressureM: spec.endGunPressureM, endGunRadiusM: m.endGunRadiusM,
    endGunBooster: m.endGunBooster, grossDepthMm: spec.grossDepthMm, hoursPerCycle: spec.hoursPerCycle, sectorDeg: spec.sectorDeg, travelM: spec.travelM, method: spec.method,
    kinematicViscosity: spec.kinematicViscosity, pipeHeightM: spec.pipeHeightM, machineLossM: spec.machineLossM, nozzlePressureM: spec.endPressureM, regulated: m.regulated,
    nozzleHeightM: m.nozzleHeightM, dropInnerMm: m.dropInnerMm, minNozzleNumber: m.minNozzleNumber, maxNozzleNumber: math.max(m.minNozzleNumber, m.maxNozzleNumber),
    availableInletHeadM: availableInletHeadM,
    drive: TowerDrive(motorRpm: m.motorRpm, centerGearRatio: m.centerGearRatio, wheelGearRatio: m.wheelGearRatio, tyreRollingDiameterM: m.tyreRollingDiameterM, speedMPerMin: m.towerSpeedMPerMin),
    timerSettings: {...defaultTimerSettings, if (m.timerPct > 0 && m.timerPct <= 100) m.timerPct}.toList()..sort((a, b) => b.compareTo(a)),
  );
}

/// Closed outline of entity [id] of [project] (an area, closed polyline,
/// hatch or cloud), or null.
List<Pt>? closedOutlineOf(Project project, String? id) {
  final e = id == null ? null : project.byId(id);
  if (e == null) return null;
  if (e is CircleEntity) return [for (var i = 0; i < 72; i++) e.center + Pt.polar(e.radius, 2 * math.pi * i / 72)];
  if (!e.isClosedShape) return null;
  final pts = e.linearPoints;
  return pts == null || pts.length < 3 ? null : pts;
}

/// Package, corner arm, prescription and electrical design of one machine.
class MechanisedResult {
  MechanisedResult({required this.pivotId, required this.package, this.cornerArm, this.vri, this.electrical});
  final String pivotId;
  final PivotPackageResult package;
  final CornerArmResult? cornerArm;
  final VriResult? vri;
  final PivotElectricalResult? electrical;

  /// Message codes of every part (`pivot_pkg_*`, `corner_arm_*`, `vri_*`,
  /// `pivot_elec_*`, with `:<pivot id>`).
  List<String> get warnings => [...package.warnings, ...?cornerArm?.warnings, ...?vri?.warnings, ...?electrical?.warnings];

  Map<String, dynamic> toJson() => {
    'id': pivotId, 'pkg': package.toJson(), if (cornerArm != null) 'arm': cornerArm!.toJson(), if (vri != null) 'vri': vri!.toJson(), if (electrical != null) 'elec': electrical!.toJson(),
  };

  static MechanisedResult fromJson(Map<String, dynamic> j) => MechanisedResult(
    pivotId: j['id'] as String? ?? '', package: PivotPackageResult.fromJson(j['pkg'] as Map<String, dynamic>),
    cornerArm: j['arm'] == null ? null : CornerArmResult.fromJson(j['arm'] as Map<String, dynamic>),
    vri: j['vri'] == null ? null : VriResult.fromJson(j['vri'] as Map<String, dynamic>),
    electrical: j['elec'] == null ? null : PivotElectricalResult.fromJson(j['elec'] as Map<String, dynamic>),
  );
}

/// Machine analyses of pivot [p]: its package with the pressure
/// [availableInletHeadM] at the pivot point (0 = the required one), the
/// highest ground of [terrain] along the circle setting the inlet head, and
/// its corner arm, prescription and electrical design when configured.
MechanisedResult analyzeMechanised(Project project, PivotEntity p, {Terrain? terrain, double availableInletHeadM = 0}) {
  final spec = pivotSpecOf(project, p);
  final m = p.machine;
  final catalog = project.catalog;
  final rise = terrain == null || terrain.isEmpty ? null : groundRiseFunction(spec, p.center, p.angleRad, terrain.elevationAt);
  final regulator = catalog.valve(p.regulatorSpecId);
  final pkg = designPivotPackage(
    pivotPackageSpecOf(spec, p, availableInletHeadM: availableInletHeadM), id: p.id,
    nozzles: catalog.outlet(p.sprinklerSpecId)?.nozzles ?? const [], regulators: [?regulator], gunNozzles: catalog.outlet(m.endGunSpecId)?.nozzles ?? const [], worstRiseAt: rise,
  );
  final sector = p.kind == PivotKind.pivot && p.sectorDeg < 360 - 1e-6;
  final startDeg = sector ? p.angleDeg - p.sectorDeg / 2 : 0.0, sweepDeg = sector ? p.sectorDeg : 360.0;
  CornerArmResult? arm;
  if (m.hasCornerArm && p.kind == PivotKind.pivot) {
    final boundary = closedOutlineOf(project, m.guidePathId);
    final path = boundary == null ? const <Pt>[] : (m.guideOffsetM.abs() > 1e-9 ? guidancePathFromBoundary(boundary, m.guideOffsetM) : boundary);
    arm = analyzeCornerArm(
      CornerArmSpec(
        center: p.center, hingeRadiusM: pkg.lastTowerRadiusM, armLengthM: m.cornerArmLengthM, guidePath: path, armOverhangM: m.cornerArmOverhangM, tipThrowM: p.endThrowM,
        maxArmAngleDeg: m.cornerArmMaxDeg, clockwise: m.clockwise, startDeg: startDeg, sweepDeg: sweepDeg, bankCount: math.max(1, m.cornerArmBanks), grossDepthMm: p.grossDepthMm,
        hoursPerRev: p.hoursPerCycle, mainFlow: pkg.systemFlow, mainRadiusM: pkg.effectiveRadiusM, referenceRadiusM: p.irrigatedRadius,
      ),
      id: p.id,
    );
  }
  VriResult? vri;
  if (m.hasVri && p.kind == PivotKind.pivot && pkg.depthAt100Mm > 0) {
    final vs = VriSpec(
      center: p.center, radiusM: pkg.effectiveRadiusM, depthAt100Mm: pkg.depthAt100Mm, startDeg: startDeg, sweepDeg: sweepDeg, sectorStepDeg: m.vriStepDeg.clamp(0.5, 90.0).toDouble(),
      minTimerPct: m.minTimerPct.clamp(1.0, 100.0).toDouble(), bankEdgesM: m.vriBankEdgesM,
    );
    final zones = [
      for (final e in m.vriZones.entries)
        if (closedOutlineOf(project, e.key) case final poly?) VriZone(polygon: poly, depthMm: e.value),
    ];
    vri = zones.isNotEmpty
        ? vriFromZones(vs, zones, id: p.id)
        : vriFromSectors(vs, [for (final s in m.vriSectors) VriSectorTarget(startDeg: s.startDeg, endDeg: s.endDeg, depthMm: s.depthMm)], id: p.id);
  }
  PivotElectricalResult? elec;
  if (m.hasElectrical) {
    final towers = [for (var i = 1; i <= spec.towerCount; i++) i * spec.spanLengthM];
    elec = designPivotElectrical(
      PivotElectricalSpec(
        towerRadiiM: towers.isEmpty ? [spec.lengthM] : towers, motorKw: m.towerMotorKw, voltage: m.voltage, supplyCableM: m.supplyCableM, supplyCableMm2: m.supplyCableMm2,
        boosterFlow: m.endGunBooster ? pkg.endGunFlow : 0, boosterHeadM: m.endGunBooster ? pkg.boosterHeadM : 0, timerPct: m.timerPct.clamp(1.0, 100.0).toDouble(),
      ),
      id: p.id,
    );
  }
  return MechanisedResult(pivotId: p.id, package: pkg, cornerArm: arm, vri: vri, electrical: elec);
}
