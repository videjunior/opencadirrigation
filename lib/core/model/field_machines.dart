part of 'entities.dart';

/// One lane of a travelling gun (hose reel): the reel stands at the hydrant
/// at [start] and winds the gun cart in from [end]. The hydrant is a node of
/// the mainline, where the lane takes the gun flow at the pressure the
/// traveller needs (`design/field_machines.dart`); lanes sharing a
/// [machine] are served one after the other by the same reel.
class TravellerEntity extends Entity {
  TravellerEntity({
    required super.id,
    super.layer = Layers.travellers,
    super.name,
    required this.start,
    required this.end,
    this.laneWidthM = 0,
    this.gunSpecId,
    this.gunNozzleId,
    this.gunFlow = 0.0125,
    this.gunPressureM = 50,
    this.wettedDiameterM = 80,
    this.sectorDeg = 300,
    this.hoseLengthM = 0,
    this.hoseInnerMm = 100,
    this.driveLossM = 7,
    this.gunHeightM = 2.5,
    this.targetDepthMm = 25,
    this.speedMPerMin = 0,
    this.setupHours = 0.5,
    this.hoursPerDay = 22,
    this.wind = WindClass.light,
    this.taperedNozzle = true,
    this.machine = 'A',
    this.machineCost = 0,
    this.hydrantCost = 0,
  });

  /// Hydrant and reel (inlet) and the far end of the run.
  Pt start;
  Pt end;

  /// Lane spacing (m; 0 = from the wind table and the wetted diameter).
  double laneWidthM;

  /// Gun of the catalogue and its nozzle (flow and wetted diameter at
  /// [gunPressureM]); without it [gunFlow] (m³/s) and [wettedDiameterM] (m).
  String? gunSpecId;
  String? gunNozzleId;
  double gunFlow;
  double gunPressureM;
  double wettedDiameterM;

  /// Part of the circle the gun waters (degrees).
  double sectorDeg;

  /// Hose length (m; 0 = the run length) and bore (mm), turbine and drum
  /// loss (m), height of the gun above the hydrant (m).
  double hoseLengthM;
  double hoseInnerMm;
  double driveLossM;
  double gunHeightM;

  /// Gross depth wanted (mm), which sets the speed, or the speed (m/min);
  /// set-up time between lanes (h) and working hours per day.
  double targetDepthMm;
  double speedMPerMin;
  double setupHours;
  double hoursPerDay;

  /// Wind class of the lane spacing table and the nozzle type.
  WindClass wind;
  bool taperedNozzle;

  /// Reel serving the lane (lanes with the same label share one machine)
  /// and the prices of the machine and of the hydrant.
  String machine;
  double machineCost;
  double hydrantCost;

  /// Run length (m).
  double get runLengthM => start.distanceTo(end);

  /// Direction of the run, from the hydrant out.
  Pt get direction {
    final d = end - start;
    return d.length > 1e-9 ? d * (1 / d.length) : const Pt(1, 0);
  }

  /// Lane width drawn: the typed spacing, else 75 % of the wetted diameter.
  double get drawnWidthM => laneWidthM > 0 ? laneWidthM : 0.75 * wettedDiameterM;

  /// The strip the lane waters.
  List<Pt> outline() {
    final n = direction.perpendicular * (drawnWidthM / 2);
    return [start + n, end + n, end - n, start - n];
  }

  @override
  EntityType get type => EntityType.traveller;
  @override
  Bounds get bounds => Bounds.ofPoints(outline());
  @override
  double distanceTo(Pt p) {
    final o = outline();
    var best = distanceToSegment(p, start, end);
    for (var i = 0; i < o.length; i++) {
      best = math.min(best, distanceToSegment(p, o[i], o[(i + 1) % o.length]));
    }
    return best;
  }

  @override
  List<Pt> get grips => [start, end];
  @override
  void setGrip(int index, Pt p) => index == 0 ? start = p : end = p;

  @override
  TravellerEntity clone({String? newId}) => TravellerEntity(
    id: newId ?? id,
    layer: layer,
    name: name,
    start: start,
    end: end,
    laneWidthM: laneWidthM,
    gunSpecId: gunSpecId,
    gunNozzleId: gunNozzleId,
    gunFlow: gunFlow,
    gunPressureM: gunPressureM,
    wettedDiameterM: wettedDiameterM,
    sectorDeg: sectorDeg,
    hoseLengthM: hoseLengthM,
    hoseInnerMm: hoseInnerMm,
    driveLossM: driveLossM,
    gunHeightM: gunHeightM,
    targetDepthMm: targetDepthMm,
    speedMPerMin: speedMPerMin,
    setupHours: setupHours,
    hoursPerDay: hoursPerDay,
    wind: wind,
    taperedNozzle: taperedNozzle,
    machine: machine,
    machineCost: machineCost,
    hydrantCost: hydrantCost,
  )..extra = extra;
  @override
  TravellerEntity translated(Pt d) => clone()
    ..start = start + d
    ..end = end + d
    ..extra = extra;
  @override
  TravellerEntity transformed(Affine t) => clone()
    ..start = t.apply(start)
    ..end = t.apply(end)
    ..laneWidthM = laneWidthM * t.scale
    ..extra = extra;
  @override
  Map<String, dynamic> toJson() => {
    ..._base(),
    'a': start.toList(),
    'b': end.toList(),
    if (laneWidthM > 0) 'w': laneWidthM,
    if (gunSpecId != null) 'gun': gunSpecId,
    if (gunNozzleId != null) 'noz': gunNozzleId,
    'q': gunFlow,
    'hg': gunPressureM,
    'dw': wettedDiameterM,
    if (sectorDeg != 300) 'sector': sectorDeg,
    if (hoseLengthM > 0) 'hose': hoseLengthM,
    if (hoseInnerMm != 100) 'hosemm': hoseInnerMm,
    if (driveLossM != 7) 'hd': driveLossM,
    if (gunHeightM != 2.5) 'zg': gunHeightM,
    if (targetDepthMm != 25) 'depth': targetDepthMm,
    if (speedMPerMin > 0) 'v': speedMPerMin,
    if (setupHours != 0.5) 'setup': setupHours,
    if (hoursPerDay != 22) 'hday': hoursPerDay,
    if (wind != WindClass.light) 'wind': wind.name,
    if (!taperedNozzle) 'ring': true,
    if (machine != 'A') 'mach': machine,
    if (machineCost > 0) 'cost': machineCost,
    if (hydrantCost > 0) 'hcost': hydrantCost,
  };

  static TravellerEntity _read(KeyLog j, String id, String layer, String name, Pt Function(String) pt, double Function(String, [double]) d, ProjectReadReport? report) => TravellerEntity(
    id: id,
    layer: layer,
    name: name,
    start: pt('a'),
    end: pt('b'),
    laneWidthM: d('w'),
    gunSpecId: j['gun'] as String?,
    gunNozzleId: j['noz'] as String?,
    gunFlow: d('q', 0.0125),
    gunPressureM: d('hg', 50),
    wettedDiameterM: d('dw', 80),
    sectorDeg: d('sector', 300),
    hoseLengthM: d('hose'),
    hoseInnerMm: d('hosemm', 100),
    driveLossM: d('hd', 7),
    gunHeightM: d('zg', 2.5),
    targetDepthMm: d('depth', 25),
    speedMPerMin: d('v'),
    setupHours: d('setup', 0.5),
    hoursPerDay: d('hday', 22),
    wind: enumByName(WindClass.values, j['wind'], WindClass.light, report: report, key: 'wind'),
    taperedNozzle: !(j['ring'] as bool? ?? false),
    machine: j['mach'] as String? ?? 'A',
    machineCost: d('cost'),
    hydrantCost: d('hcost'),
  );
}

/// A set of furrows fed from a head line: a gated pipe (or a head ditch
/// with siphons) drawn from its inlet ([points] first), the furrows running
/// [furrowLengthM] from it to one side. The inlet is a node of the mainline
/// that takes the flow of the furrows irrigated together at the pressure
/// the gated pipe needs (`design/field_machines.dart`).
class FurrowEntity extends Entity with PolyEntity {
  FurrowEntity({
    required super.id,
    super.layer = Layers.surface,
    super.name,
    required this.points,
    this.leftSide = true,
    this.furrowLengthM = 200,
    this.furrowSpacingM = 0.9,
    this.slope = 0.002,
    this.manningN = 0.04,
    this.intakeFamily = 0.5,
    this.requiredDepthMm = 60,
    this.inflowLps = 0,
    this.furrowsPerSet = 0,
    this.gatedPipe = true,
    this.pipeInnerMm = 150,
    this.hazenC = 150,
    this.pipeCostPerM = 0,
    this.gateCost = 0,
  });

  /// Head line from its inlet.
  @override
  final List<Pt> points;

  /// The furrows run to the left of the head line (looking along it from
  /// the inlet), else to the right.
  bool leftSide;

  /// Furrow length and spacing (m), slope along the furrows (m/m), Manning
  /// n and the NRCS intake family of the soil (in/h).
  double furrowLengthM;
  double furrowSpacingM;
  double slope;
  double manningN;
  double intakeFamily;

  /// Depth to infiltrate (mm), the inflow of a furrow (L/s; 0 = the one
  /// of the highest efficiency) and the furrows irrigated together (0 =
  /// all of them).
  double requiredDepthMm;
  double inflowLps;
  int furrowsPerSet;

  /// A gated pipe along the head line (else a ditch with siphons, no
  /// pressure), its bore (mm) and Hazen-Williams C; prices of the pipe (per
  /// m) and of a gate.
  bool gatedPipe;
  double pipeInnerMm;
  double hazenC;
  double pipeCostPerM;
  double gateCost;

  /// Number of furrows along the head line.
  int get furrowCount => furrowSpacingM > 0 ? math.max(1, (length / furrowSpacingM).floor()) : 0;

  /// The side the furrows run to (a unit vector).
  Pt get furrowDirection {
    if (points.length < 2) return const Pt(0, 1);
    final d = points.last - points.first;
    if (d.length < 1e-9) return const Pt(0, 1);
    final n = d.perpendicular * (1 / d.length);
    return leftSide ? n : n * -1;
  }

  /// The field the furrows water.
  List<Pt> outline() {
    final off = furrowDirection * furrowLengthM;
    return [...points, for (final p in points.reversed) p + off];
  }

  @override
  EntityType get type => EntityType.furrows;
  @override
  Bounds get bounds => Bounds.ofPoints(points.length < 2 ? points : outline());

  @override
  FurrowEntity clone({String? newId}) => FurrowEntity(
    id: newId ?? id,
    layer: layer,
    name: name,
    points: List.of(points),
    leftSide: leftSide,
    furrowLengthM: furrowLengthM,
    furrowSpacingM: furrowSpacingM,
    slope: slope,
    manningN: manningN,
    intakeFamily: intakeFamily,
    requiredDepthMm: requiredDepthMm,
    inflowLps: inflowLps,
    furrowsPerSet: furrowsPerSet,
    gatedPipe: gatedPipe,
    pipeInnerMm: pipeInnerMm,
    hazenC: hazenC,
    pipeCostPerM: pipeCostPerM,
    gateCost: gateCost,
  )..extra = extra;
  @override
  FurrowEntity translated(Pt d) {
    final c = clone();
    for (var i = 0; i < c.points.length; i++) {
      c.points[i] = c.points[i] + d;
    }
    return c;
  }

  @override
  FurrowEntity transformed(Affine t) {
    final c = clone();
    for (var i = 0; i < c.points.length; i++) {
      c.points[i] = t.apply(c.points[i]);
    }
    // a mirror turns the side over
    if (t.determinant < 0) c.leftSide = !leftSide;
    c
      ..furrowLengthM = furrowLengthM * t.scale
      ..furrowSpacingM = furrowSpacingM * t.scale;
    return c;
  }

  @override
  Map<String, dynamic> toJson() => {
    ..._base(),
    'pts': _ptsJson(points),
    if (!leftSide) 'right': true,
    'len': furrowLengthM,
    'sp': furrowSpacingM,
    'slope': slope,
    if (manningN != 0.04) 'n': manningN,
    'fam': intakeFamily,
    'depth': requiredDepthMm,
    if (inflowLps > 0) 'q': inflowLps,
    if (furrowsPerSet > 0) 'set': furrowsPerSet,
    if (!gatedPipe) 'ditch': true,
    if (pipeInnerMm != 150) 'mm': pipeInnerMm,
    if (hazenC != 150) 'c': hazenC,
    if (pipeCostPerM > 0) 'cost': pipeCostPerM,
    if (gateCost > 0) 'gcost': gateCost,
  };

  static FurrowEntity _read(KeyLog j, String id, String layer, String name, List<Pt> pts, double Function(String, [double]) d) => FurrowEntity(
    id: id,
    layer: layer,
    name: name,
    points: pts,
    leftSide: !(j['right'] as bool? ?? false),
    furrowLengthM: d('len', 200),
    furrowSpacingM: d('sp', 0.9),
    slope: d('slope', 0.002),
    manningN: d('n', 0.04),
    intakeFamily: d('fam', 0.5),
    requiredDepthMm: d('depth', 60),
    inflowLps: d('q'),
    furrowsPerSet: (j['set'] as num?)?.toInt() ?? 0,
    gatedPipe: !(j['ditch'] as bool? ?? false),
    pipeInnerMm: d('mm', 150),
    hazenC: d('c', 150),
    pipeCostPerM: d('cost'),
    gateCost: d('gcost'),
  );
}
