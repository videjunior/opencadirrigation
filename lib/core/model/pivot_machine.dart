/// Mechanised-irrigation data a centre pivot or linear move keeps beside
/// its hydraulics: the sprinkler package (regulators, drops, numbered
/// nozzles, end gun), the drive train and the timer, a corner arm, the
/// variable-rate prescription and the electrical supply. The defaults leave
/// everything but the package off.
library;

/// One sector of a variable-rate prescription: from [startDeg]
/// counter-clockwise to [endDeg], target gross depth (mm).
class VriSectorDepth {
  const VriSectorDepth(this.startDeg, this.endDeg, this.depthMm);
  final double startDeg, endDeg, depthMm;

  List<double> toJson() => [startDeg, endDeg, depthMm];
  static VriSectorDepth? fromJson(Object? j) {
    if (j is! List || j.length < 3 || j.any((v) => v is! num)) return null;
    return VriSectorDepth((j[0] as num).toDouble(), (j[1] as num).toDouble(), (j[2] as num).toDouble());
  }
}

class PivotMachine {
  PivotMachine({
    this.regulated = true,
    this.nozzleHeightM = 0,
    this.spanArchM = 0,
    this.dropInnerMm = 19,
    this.minNozzleNumber = 2,
    this.maxNozzleNumber = 64,
    this.endGun = 'auto',
    this.endGunRadiusM = 0,
    this.endGunSpecId,
    this.endGunBooster = false,
    this.motorRpm = 0,
    this.centerGearRatio = 0,
    this.wheelGearRatio = 0,
    this.tyreRollingDiameterM = 0,
    this.towerSpeedMPerMin = 0,
    this.timerPct = 100,
    this.minTimerPct = 5,
    this.cornerArmLengthM = 0,
    this.cornerArmOverhangM = 0,
    this.cornerArmMaxDeg = 120,
    this.cornerArmBanks = 4,
    this.cornerArmThrowM,
    this.guidePathId,
    this.guideOffsetM = 0,
    this.clockwise = false,
    this.vriStepDeg = 2,
    List<double>? vriBankEdgesM,
    Map<String, double>? vriZones,
    List<VriSectorDepth>? vriSectors,
    this.voltage = 0,
    this.towerMotorKw = 0.55,
    this.supplyCableM = 0,
    this.supplyCableMm2 = 0,
  }) : vriBankEdgesM = vriBankEdgesM ?? [],
       vriZones = vriZones ?? {},
       vriSectors = vriSectors ?? [];

  /// Regulated package (the target nozzle pressure picks the regulator
  /// rating), or unregulated (the end pressure is the least at every nozzle).
  bool regulated;

  /// Height of the nozzles above the ground (m; 0 = on top of the pipe, no
  /// drops) and rise of the span pipe at mid-span (m).
  double nozzleHeightM;
  double spanArchM;

  /// Drop hose bore (mm) and the numbered nozzle series used without
  /// catalogue nozzles (1/128-inch steps).
  double dropInnerMm;
  int minNozzleNumber, maxNozzleNumber;

  /// End gun: `auto` (corners when the machine has an end-gun flow),
  /// `none`, `fullCircle` or `corners`; its wetted radius (m; 0 = from the
  /// catalogue gun), the catalogue gun whose nozzles are offered and a
  /// booster pump at the end.
  String endGun;
  double endGunRadiusM;
  String? endGunSpecId;
  bool endGunBooster;

  /// Drive train of the last regular tower (motor rpm, centre and wheel
  /// gearbox ratios, tyre rolling diameter in m) or its speed at 100 %
  /// (m/min, wins when positive); timer setting and the slowest one (%).
  double motorRpm, centerGearRatio, wheelGearRatio, tyreRollingDiameterM, towerSpeedMPerMin;
  double timerPct, minTimerPct;

  /// Corner arm (0 = none): length from the hinge at the last tower, pipe
  /// beyond its tip, largest folding angle, sprinkler banks, and the guide:
  /// a closed polyline or area of the drawing ([guidePathId]) offset
  /// inwards by [guideOffsetM]; [clockwise] is the direction of travel.
  double cornerArmLengthM, cornerArmOverhangM, cornerArmMaxDeg;
  int cornerArmBanks;

  /// Throw of the last sprinkler of the corner arm beyond its tip (m; null =
  /// the end throw of the machine). With an arm the main machine waters only
  /// to the hinge at its last tower: its own throw and overhang do not count.
  double? cornerArmThrowM;
  String? guidePathId;
  double guideOffsetM;
  bool clockwise;

  /// Variable rate: sector width (degrees), boundaries of the radial banks
  /// for zone control (m from the pivot point; empty = speed control), the
  /// target depth (mm) of the areas of the drawing used as zones (area id →
  /// depth) and the sectors typed in.
  double vriStepDeg;
  List<double> vriBankEdgesM;
  Map<String, double> vriZones;
  List<VriSectorDepth> vriSectors;

  /// Electrical design (on when [voltage] > 0): three-phase supply voltage
  /// (V), tower motor rating (kW), supply cable to the pivot point (m) and
  /// its section (mm²; 0 = sized).
  double voltage, towerMotorKw, supplyCableM, supplyCableMm2;

  bool get hasCornerArm => cornerArmLengthM > 0 && guidePathId != null;
  bool get hasVri => vriZones.isNotEmpty || vriSectors.isNotEmpty;
  bool get hasElectrical => voltage > 0;

  bool get isDefault => _json().isEmpty;

  PivotMachine clone() => PivotMachine.fromJson(toJson());

  Map<String, dynamic> _json() => {
    if (!regulated) 'reg': false,
    if (nozzleHeightM > 0) 'hnoz': nozzleHeightM,
    if (spanArchM > 0) 'arch': spanArchM,
    if (dropInnerMm != 19) 'drop': dropInnerMm,
    if (minNozzleNumber != 2) 'nmin': minNozzleNumber,
    if (maxNozzleNumber != 64) 'nmax': maxNozzleNumber,
    if (endGun != 'auto') 'gun': endGun,
    if (endGunRadiusM > 0) 'rg': endGunRadiusM,
    if (endGunSpecId != null) 'gspec': endGunSpecId,
    if (endGunBooster) 'boost': true,
    if (motorRpm > 0) 'rpm': motorRpm,
    if (centerGearRatio > 0) 'g1': centerGearRatio,
    if (wheelGearRatio > 0) 'g2': wheelGearRatio,
    if (tyreRollingDiameterM > 0) 'tyre': tyreRollingDiameterM,
    if (towerSpeedMPerMin > 0) 'v100': towerSpeedMPerMin,
    if (timerPct != 100) 'timer': timerPct,
    if (minTimerPct != 5) 'tmin': minTimerPct,
    if (cornerArmLengthM > 0) 'cal': cornerArmLengthM,
    if (cornerArmOverhangM > 0) 'cao': cornerArmOverhangM,
    if (cornerArmMaxDeg != 120) 'camax': cornerArmMaxDeg,
    if (cornerArmBanks != 4) 'cab': cornerArmBanks,
    if (cornerArmThrowM != null) 'cat': cornerArmThrowM,
    if (guidePathId != null) 'gpath': guidePathId,
    if (guideOffsetM != 0) 'goff': guideOffsetM,
    if (clockwise) 'cw': true,
    if (vriStepDeg != 2) 'vris': vriStepDeg,
    if (vriBankEdgesM.isNotEmpty) 'vrib': vriBankEdgesM,
    if (vriZones.isNotEmpty) 'vriz': vriZones,
    if (vriSectors.isNotEmpty) 'vri': [for (final s in vriSectors) s.toJson()],
    if (voltage > 0) 'volt': voltage,
    if (towerMotorKw != 0.55) 'mkw': towerMotorKw,
    if (supplyCableM > 0) 'scl': supplyCableM,
    if (supplyCableMm2 > 0) 'smm2': supplyCableMm2,
  };

  Map<String, dynamic> toJson() => _json();

  static PivotMachine fromJson(Map<String, dynamic>? j) {
    if (j == null) return PivotMachine();
    double d(String k, double def) => (j[k] as num?)?.toDouble() ?? def;
    return PivotMachine(
      regulated: j['reg'] as bool? ?? true,
      nozzleHeightM: d('hnoz', 0),
      spanArchM: d('arch', 0),
      dropInnerMm: d('drop', 19),
      minNozzleNumber: (j['nmin'] as num?)?.toInt() ?? 2,
      maxNozzleNumber: (j['nmax'] as num?)?.toInt() ?? 64,
      endGun: switch (j['gun']) {
        'none' || 'fullCircle' || 'corners' => j['gun'] as String,
        _ => 'auto',
      },
      endGunRadiusM: d('rg', 0),
      endGunSpecId: j['gspec'] as String?,
      endGunBooster: j['boost'] as bool? ?? false,
      motorRpm: d('rpm', 0),
      centerGearRatio: d('g1', 0),
      wheelGearRatio: d('g2', 0),
      tyreRollingDiameterM: d('tyre', 0),
      towerSpeedMPerMin: d('v100', 0),
      timerPct: d('timer', 100),
      minTimerPct: d('tmin', 5),
      cornerArmLengthM: d('cal', 0),
      cornerArmOverhangM: d('cao', 0),
      cornerArmMaxDeg: d('camax', 120),
      cornerArmBanks: (j['cab'] as num?)?.toInt() ?? 4,
      cornerArmThrowM: (j['cat'] as num?)?.toDouble(),
      guidePathId: j['gpath'] as String?,
      guideOffsetM: d('goff', 0),
      clockwise: j['cw'] as bool? ?? false,
      vriStepDeg: d('vris', 2),
      vriBankEdgesM: [
        for (final v in (j['vrib'] as List?) ?? const [])
          if (v is num) v.toDouble(),
      ],
      vriZones: {
        for (final e in ((j['vriz'] as Map?) ?? const {}).entries)
          if (e.key is String && e.value is num) e.key as String: (e.value as num).toDouble(),
      },
      vriSectors: [for (final s in (j['vri'] as List?) ?? const []) ?VriSectorDepth.fromJson(s)],
      voltage: d('volt', 0),
      towerMotorKw: d('mkw', 0.55),
      supplyCableM: d('scl', 0),
      supplyCableMm2: d('smm2', 0),
    );
  }
}
