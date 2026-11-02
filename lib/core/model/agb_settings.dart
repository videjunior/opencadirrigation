/// Project settings of the machines, electrical and water functions added
/// in 1.6.0, kept in the project file under `agb`: the electrical design of
/// the pump house ([PumpHouseSettings]), solar pumping in the design
/// ([SolarSettings]), the water analysis with its filtration and chemical
/// treatment ([WaterQualitySettings]) and two-wire (decoder) valve wiring
/// ([TwoWireSettings]). Only what differs from the defaults is written, so a
/// project that never used them keeps its file as it was; fields of a newer
/// version are kept as read ([KeyLog]).
library;

import 'read_report.dart';

/// Insulation of a power cable: PVC (70 °C) or EPR/XLPE (90 °C).
enum CableInsulation { pvc, xlpe }

/// Reference installation methods of NBR 5410:2004 Tabela 33 (IEC
/// 60364-5-52 Table B.52.1): conduit on or in a wall (B1), cable fixed on a
/// wall or on an unperforated tray (C), in a duct in the ground (D),
/// multicore cable in free air or on a perforated tray (E).
enum CableMethod { b1, c, d, e }

/// How a motor starts: chosen by the design, direct on line, star-delta,
/// soft-starter or variable-frequency drive.
enum StarterKind { auto, direct, starDelta, softStarter, vfd }

/// Where the pump house is fed from: a transformer of its own (MV/LV), the
/// utility's low-voltage network, or a generator set.
enum PowerSupplyKind { ownTransformer, lowVoltage, generator }

/// Solar pumping in the design: none, an off-grid PV pumping system (the
/// array drives the pump) or a grid-tied array under net metering.
enum SolarMode { off, offGrid, gridTied }

/// Where the irrigation water comes from (surface water carries algae and
/// organic matter: media filters).
enum WaterSource { well, surface, reservoir, municipal }

/// Chlorination: chosen from the analysis, none, continuous (a residual at
/// the end of the laterals) or intermittent (a strong dose now and then).
enum ChlorinationMode { auto, none, continuous, intermittent }

/// Acid used to lower the pH of the water.
enum AcidProduct { sulfuric, hydrochloric, nitric, phosphoric }

double _d(KeyLog j, String k, double def) {
  final v = j[k];
  return v is num && v.isFinite ? v.toDouble() : def;
}

double? _dn(KeyLog j, String k) {
  final v = j[k];
  return v is num && v.isFinite ? v.toDouble() : null;
}

Map<String, dynamic>? _obj(Object? v) => v is Map ? v.cast<String, dynamic>() : null;

/// Electrical data of one pump of the pump house; the defaults let the
/// design choose.
class PumpFeeder {
  PumpFeeder({this.electric = true, this.lengthM, this.starter = StarterKind.auto, this.motorKw = 0, this.efficiency = 0, this.powerFactor = 0});

  /// An electric motor (false: a diesel engine, left out of the electrical design).
  bool electric;

  /// Feeder length from the supply to the motor starter (m); null = the default of the pump house.
  double? lengthM;
  StarterKind starter;

  /// Rated output (kW; 0 = the motor of the pump's data or of its duty),
  /// efficiency and power factor (0 = IE3 and typical values).
  double motorKw;
  double efficiency;
  double powerFactor;

  /// Fields of a newer version, kept as read.
  Map<String, dynamic>? extra;

  bool get isDefault => toJson().isEmpty;

  PumpFeeder clone() => PumpFeeder.fromJson(toJson());

  Map<String, dynamic> toJson() => {
    ...?extra,
    if (!electric) 'elec': false,
    if (lengthM != null) 'len': lengthM,
    if (starter != StarterKind.auto) 'start': starter.name,
    if (motorKw > 0) 'kw': motorKw,
    if (efficiency > 0) 'eff': efficiency,
    if (powerFactor > 0) 'pf': powerFactor,
  };

  static PumpFeeder fromJson(Map<String, dynamic>? json) {
    final j = KeyLog(json ?? const {});
    return PumpFeeder(
      electric: j['elec'] as bool? ?? true,
      lengthM: _dn(j, 'len'),
      starter: enumByName(StarterKind.values, j['start'], StarterKind.auto),
      motorKw: _d(j, 'kw', 0),
      efficiency: _d(j, 'eff', 0),
      powerFactor: _d(j, 'pf', 0),
    )..extra = j.unread;
  }
}

/// Electrical design of the pump house (Design → Pump house electrics):
/// on when [enabled].
class PumpHouseSettings {
  PumpHouseSettings({
    this.enabled = false,
    this.voltage = 380,
    this.supply = PowerSupplyKind.ownTransformer,
    this.insulation = CableInsulation.pvc,
    this.method = CableMethod.d,
    this.ambientC,
    this.groupingFactor = 1,
    this.serviceFactor = 1.15,
    this.directMaxKw = 5.5,
    this.softStartMultiple = 3,
    this.lockedRotorMultiple = 7,
    this.defaultFeederM = 50,
    this.maxRunningDropPct = 0,
    this.maxStartingDropPct = 10,
    this.transformerUkPct = 0,
    this.transformerLoadingPct = 100,
    this.otherLoadsKva = 0,
    this.includePivots = true,
    this.clearingTimeS = 0.1,
    this.upstreamMva = 0,
    this.generatorReactance = 0.2,
    this.allowedDipPct = 20,
    this.panelCost = 0,
    this.transformerCost = 0,
    Map<String, PumpFeeder>? pumps,
  }) : pumps = pumps ?? {};

  bool enabled;

  /// Line-to-line voltage of the three-phase supply (V).
  double voltage;
  PowerSupplyKind supply;

  /// Feeder cables: insulation, installation method, temperature of the air
  /// (or of the soil for method D; null = the reference of the tables, 30 °C
  /// air, 20 °C soil) and the grouping factor (NBR 5410 Tabela 42; 1 = alone).
  CableInsulation insulation;
  CableMethod method;
  double? ambientC;
  double groupingFactor;

  /// Motor service factor (the feeder carries the rated current times it,
  /// NBR 5410 6.5.1.3.1).
  double serviceFactor;

  /// Largest motor the utility lets start direct on line (kW), the current a
  /// soft-starter is set to (× rated) and the locked-rotor current of a
  /// direct start (× rated).
  double directMaxKw;
  double softStartMultiple;
  double lockedRotorMultiple;

  /// Feeder length of a pump without its own (m).
  double defaultFeederM;

  /// Voltage drop limits: running (%; 0 = NBR 5410 6.2.7.1 by the supply:
  /// 7 % from a transformer or generator of its own, 5 % from the
  /// low-voltage network) and at the starter while the motor starts (%,
  /// NBR 5410 6.5.1.3.3).
  double maxRunningDropPct;
  double maxStartingDropPct;

  /// Transformer short-circuit voltage (%; 0 = typical for its size) and
  /// the largest loading of its rating (%).
  double transformerUkPct;
  double transformerLoadingPct;

  /// Other loads on the same supply (kVA) and whether the pivots with an
  /// electrical design are fed from it.
  double otherLoadsKva;
  bool includePivots;

  /// Time the protection takes to clear a short circuit (s), for the
  /// thermal check of the cables, and the short-circuit power of the
  /// network upstream of the transformer (MVA; 0 = infinite).
  double clearingTimeS;
  double upstreamMva;

  /// Generator set: subtransient reactance (per unit) and the voltage dip
  /// allowed while the largest motor starts (%).
  double generatorReactance;
  double allowedDipPct;

  /// Prices for the bill of materials (0 = not costed): a starter panel and
  /// the transformer or generator.
  double panelCost;
  double transformerCost;

  /// Data of the pumps by entity id.
  final Map<String, PumpFeeder> pumps;

  /// Fields of a newer version, kept as read.
  Map<String, dynamic>? extra;

  PumpFeeder feederOf(String pumpId) => pumps[pumpId] ?? PumpFeeder();

  bool get isDefault => toJson().isEmpty;

  PumpHouseSettings clone() => PumpHouseSettings.fromJson(toJson());

  Map<String, dynamic> toJson() {
    final p = {
      for (final e in pumps.entries)
        if (!e.value.isDefault) e.key: e.value.toJson(),
    };
    return {
      ...?extra,
      if (enabled) 'on': true,
      if (voltage != 380) 'v': voltage,
      if (supply != PowerSupplyKind.ownTransformer) 'supply': supply.name,
      if (insulation != CableInsulation.pvc) 'ins': insulation.name,
      if (method != CableMethod.d) 'method': method.name,
      if (ambientC != null) 'temp': ambientC,
      if (groupingFactor != 1) 'group': groupingFactor,
      if (serviceFactor != 1.15) 'sf': serviceFactor,
      if (directMaxKw != 5.5) 'dol': directMaxKw,
      if (softStartMultiple != 3) 'soft': softStartMultiple,
      if (lockedRotorMultiple != 7) 'lr': lockedRotorMultiple,
      if (defaultFeederM != 50) 'len': defaultFeederM,
      if (maxRunningDropPct != 0) 'du': maxRunningDropPct,
      if (maxStartingDropPct != 10) 'dus': maxStartingDropPct,
      if (transformerUkPct != 0) 'uk': transformerUkPct,
      if (transformerLoadingPct != 100) 'load': transformerLoadingPct,
      if (otherLoadsKva != 0) 'other': otherLoadsKva,
      if (!includePivots) 'pivots': false,
      if (clearingTimeS != 0.1) 'tk': clearingTimeS,
      if (upstreamMva != 0) 'mva': upstreamMva,
      if (generatorReactance != 0.2) 'xd': generatorReactance,
      if (allowedDipPct != 20) 'dip': allowedDipPct,
      if (panelCost != 0) 'cpanel': panelCost,
      if (transformerCost != 0) 'ctr': transformerCost,
      if (p.isNotEmpty) 'pumps': p,
    };
  }

  static PumpHouseSettings fromJson(Map<String, dynamic>? json) {
    final j = KeyLog(json ?? const {});
    return PumpHouseSettings(
      enabled: j['on'] as bool? ?? false,
      voltage: _d(j, 'v', 380),
      supply: enumByName(PowerSupplyKind.values, j['supply'], PowerSupplyKind.ownTransformer),
      insulation: enumByName(CableInsulation.values, j['ins'], CableInsulation.pvc),
      method: enumByName(CableMethod.values, j['method'], CableMethod.d),
      ambientC: _dn(j, 'temp'),
      groupingFactor: _d(j, 'group', 1),
      serviceFactor: _d(j, 'sf', 1.15),
      directMaxKw: _d(j, 'dol', 5.5),
      softStartMultiple: _d(j, 'soft', 3),
      lockedRotorMultiple: _d(j, 'lr', 7),
      defaultFeederM: _d(j, 'len', 50),
      maxRunningDropPct: _d(j, 'du', 0),
      maxStartingDropPct: _d(j, 'dus', 10),
      transformerUkPct: _d(j, 'uk', 0),
      transformerLoadingPct: _d(j, 'load', 100),
      otherLoadsKva: _d(j, 'other', 0),
      includePivots: j['pivots'] as bool? ?? true,
      clearingTimeS: _d(j, 'tk', 0.1),
      upstreamMva: _d(j, 'mva', 0),
      generatorReactance: _d(j, 'xd', 0.2),
      allowedDipPct: _d(j, 'dip', 20),
      panelCost: _d(j, 'cpanel', 0),
      transformerCost: _d(j, 'ctr', 0),
      pumps: {
        for (final e in (_obj(j['pumps']) ?? const <String, dynamic>{}).entries)
          if (_obj(e.value) case final m?) e.key: PumpFeeder.fromJson(m),
      },
    )..extra = j.unread;
  }
}

/// Solar pumping of the design (Design → Solar pumping): an off-grid PV
/// pumping system sized for the month of largest need (IEC 62253), or a
/// grid-tied array whose energy is compensated on the bill (net metering,
/// Lei 14.300/2022 in Brazil).
class SolarSettings {
  SolarSettings({
    this.mode = SolarMode.off,
    this.moduleWp = 550,
    this.moduleAreaM2 = 2.6,
    this.tiltDeg,
    this.azimuthFromEquatorDeg = 0,
    this.oversize = 1,
    this.soiling = 0.03,
    this.wiring = 0.02,
    this.mismatch = 0.02,
    this.converterEfficiency = 0.95,
    this.motorPumpEfficiency = 0,
    this.headM = 0,
    this.dcAcRatio = 1.2,
    this.simultaneity = 0,
    this.fioBSharePct = 28,
    this.billingYear = 2026,
    this.grandfathered = false,
    this.modulePrice = 0,
    this.inverterPricePerKw = 0,
    this.structurePricePerModule = 0,
  });

  SolarMode mode;

  /// Module rating (Wp at STC) and area (m²).
  double moduleWp;
  double moduleAreaM2;

  /// Array slope (degrees; null = |latitude|) and azimuth from the equator
  /// (degrees, west positive).
  double? tiltDeg;
  double azimuthFromEquatorDeg;

  /// Margin on the required power (1 = none) and the losses of the
  /// performance ratio (IEC 61724-1): soiling, DC wiring, mismatch.
  double oversize;
  double soiling;
  double wiring;
  double mismatch;

  /// Power conditioner (pump drive or inverter) efficiency and the
  /// wire-to-water efficiency of the motor-pump set (0 = from the design).
  double converterEfficiency;
  double motorPumpEfficiency;

  /// Total dynamic head (m; 0 = from the design).
  double headM;

  /// Grid-tied: array power over inverter power, the share of the
  /// generation used while it is produced (0–1), the share of the
  /// distribution wires (Fio B) in the energy tariff (%), the year billed
  /// and whether access was asked before 7 January 2023 (no Fio B until
  /// 2045, Lei 14.300/2022 art. 26).
  double dcAcRatio;
  double simultaneity;
  double fioBSharePct;
  int billingYear;
  bool grandfathered;

  /// Prices for the bill of materials (0 = not costed).
  double modulePrice;
  double inverterPricePerKw;
  double structurePricePerModule;

  /// Fields of a newer version, kept as read.
  Map<String, dynamic>? extra;

  bool get isDefault => toJson().isEmpty;
  bool get enabled => mode != SolarMode.off;

  SolarSettings clone() => SolarSettings.fromJson(toJson());

  Map<String, dynamic> toJson() => {
    ...?extra,
    if (mode != SolarMode.off) 'mode': mode.name,
    if (moduleWp != 550) 'wp': moduleWp,
    if (moduleAreaM2 != 2.6) 'area': moduleAreaM2,
    if (tiltDeg != null) 'tilt': tiltDeg,
    if (azimuthFromEquatorDeg != 0) 'az': azimuthFromEquatorDeg,
    if (oversize != 1) 'over': oversize,
    if (soiling != 0.03) 'soil': soiling,
    if (wiring != 0.02) 'wire': wiring,
    if (mismatch != 0.02) 'mis': mismatch,
    if (converterEfficiency != 0.95) 'conv': converterEfficiency,
    if (motorPumpEfficiency != 0) 'eta': motorPumpEfficiency,
    if (headM != 0) 'head': headM,
    if (dcAcRatio != 1.2) 'dcac': dcAcRatio,
    if (simultaneity != 0) 'simul': simultaneity,
    if (fioBSharePct != 28) 'fiob': fioBSharePct,
    if (billingYear != 2026) 'year': billingYear,
    if (grandfathered) 'gf': true,
    if (modulePrice != 0) 'cmod': modulePrice,
    if (inverterPricePerKw != 0) 'cinv': inverterPricePerKw,
    if (structurePricePerModule != 0) 'cstr': structurePricePerModule,
  };

  static SolarSettings fromJson(Map<String, dynamic>? json) {
    final j = KeyLog(json ?? const {});
    return SolarSettings(
      mode: enumByName(SolarMode.values, j['mode'], SolarMode.off),
      moduleWp: _d(j, 'wp', 550),
      moduleAreaM2: _d(j, 'area', 2.6),
      tiltDeg: _dn(j, 'tilt'),
      azimuthFromEquatorDeg: _d(j, 'az', 0),
      oversize: _d(j, 'over', 1),
      soiling: _d(j, 'soil', 0.03),
      wiring: _d(j, 'wire', 0.02),
      mismatch: _d(j, 'mis', 0.02),
      converterEfficiency: _d(j, 'conv', 0.95),
      motorPumpEfficiency: _d(j, 'eta', 0),
      headM: _d(j, 'head', 0),
      dcAcRatio: _d(j, 'dcac', 1.2),
      simultaneity: _d(j, 'simul', 0),
      fioBSharePct: _d(j, 'fiob', 28),
      billingYear: (j['year'] as num?)?.toInt() ?? 2026,
      grandfathered: j['gf'] as bool? ?? false,
      modulePrice: _d(j, 'cmod', 0),
      inverterPricePerKw: _d(j, 'cinv', 0),
      structurePricePerModule: _d(j, 'cstr', 0),
    )..extra = j.unread;
  }
}

/// The water analysis (null = not analysed) and the treatment asked for
/// (Design → Water quality and filtration).
class WaterQualitySettings {
  WaterQualitySettings({
    this.source = WaterSource.well,
    this.ph,
    this.ecDsM,
    this.tdsMgL,
    this.tssMgL,
    this.ironMgL,
    this.manganeseMgL,
    this.sulfideMgL,
    this.calciumMgL,
    this.bicarbonateMgL,
    this.bacteriaPerMl,
    this.temperatureC = 25,
    this.emitterPassageMm = 0,
    this.meshRatio = 7,
    this.chlorination = ChlorinationMode.auto,
    this.chlorineResidualMgL = 1,
    this.shockMgL = 10,
    this.shockMinutes = 45,
    this.shocksPerMonth = 4,
    this.hypochloritePct = 10,
    this.acidTargetPh,
    this.acid = AcidProduct.sulfuric,
    this.filterCost = 0,
    this.injectorCost = 0,
  });

  WaterSource source;

  /// pH, electrical conductivity (dS/m), dissolved solids (mg/L; null =
  /// from the conductivity), suspended solids, iron, manganese, hydrogen
  /// sulfide, calcium and bicarbonate (mg/L), bacteria (per mL) and the
  /// water temperature (°C).
  double? ph;
  double? ecDsM;
  double? tdsMgL;
  double? tssMgL;
  double? ironMgL;
  double? manganeseMgL;
  double? sulfideMgL;
  double? calciumMgL;
  double? bicarbonateMgL;
  double? bacteriaPerMl;
  double temperatureC;

  /// Smallest water passage of the emitters (mm; 0 = by the emitters of the
  /// project) and how many times smaller the filter opening is.
  double emitterPassageMm;
  double meshRatio;

  /// Chlorination: the mode, the free residual kept at the end of the
  /// laterals (mg/L), the intermittent dose (mg/L), its duration (min) and
  /// how many per month, and the strength of the sodium hypochlorite (%
  /// available chlorine).
  ChlorinationMode chlorination;
  double chlorineResidualMgL;
  double shockMgL;
  double shockMinutes;
  double shocksPerMonth;
  double hypochloritePct;

  /// pH the acid brings the water to (null = no acid unless carbonates
  /// precipitate) and the acid product.
  double? acidTargetPh;
  AcidProduct acid;

  /// Prices for the bill of materials (0 = not costed): one filter of the
  /// station and one injector.
  double filterCost;
  double injectorCost;

  /// Fields of a newer version, kept as read.
  Map<String, dynamic>? extra;

  bool get isDefault => toJson().isEmpty;

  /// Whether any value of the analysis was given.
  bool get analysed => [ph, ecDsM, tdsMgL, tssMgL, ironMgL, manganeseMgL, sulfideMgL, calciumMgL, bicarbonateMgL, bacteriaPerMl].any((v) => v != null);

  WaterQualitySettings clone() => WaterQualitySettings.fromJson(toJson());

  Map<String, dynamic> toJson() => {
    ...?extra,
    if (source != WaterSource.well) 'src': source.name,
    if (ph != null) 'ph': ph,
    if (ecDsM != null) 'ec': ecDsM,
    if (tdsMgL != null) 'tds': tdsMgL,
    if (tssMgL != null) 'tss': tssMgL,
    if (ironMgL != null) 'fe': ironMgL,
    if (manganeseMgL != null) 'mn': manganeseMgL,
    if (sulfideMgL != null) 'h2s': sulfideMgL,
    if (calciumMgL != null) 'ca': calciumMgL,
    if (bicarbonateMgL != null) 'hco3': bicarbonateMgL,
    if (bacteriaPerMl != null) 'bact': bacteriaPerMl,
    if (temperatureC != 25) 'temp': temperatureC,
    if (emitterPassageMm != 0) 'pass': emitterPassageMm,
    if (meshRatio != 7) 'ratio': meshRatio,
    if (chlorination != ChlorinationMode.auto) 'cl': chlorination.name,
    if (chlorineResidualMgL != 1) 'clres': chlorineResidualMgL,
    if (shockMgL != 10) 'shock': shockMgL,
    if (shockMinutes != 45) 'shockmin': shockMinutes,
    if (shocksPerMonth != 4) 'shockn': shocksPerMonth,
    if (hypochloritePct != 10) 'naocl': hypochloritePct,
    if (acidTargetPh != null) 'acidph': acidTargetPh,
    if (acid != AcidProduct.sulfuric) 'acid': acid.name,
    if (filterCost != 0) 'cfilter': filterCost,
    if (injectorCost != 0) 'cinj': injectorCost,
  };

  static WaterQualitySettings fromJson(Map<String, dynamic>? json) {
    final j = KeyLog(json ?? const {});
    return WaterQualitySettings(
      source: enumByName(WaterSource.values, j['src'], WaterSource.well),
      ph: _dn(j, 'ph'),
      ecDsM: _dn(j, 'ec'),
      tdsMgL: _dn(j, 'tds'),
      tssMgL: _dn(j, 'tss'),
      ironMgL: _dn(j, 'fe'),
      manganeseMgL: _dn(j, 'mn'),
      sulfideMgL: _dn(j, 'h2s'),
      calciumMgL: _dn(j, 'ca'),
      bicarbonateMgL: _dn(j, 'hco3'),
      bacteriaPerMl: _dn(j, 'bact'),
      temperatureC: _d(j, 'temp', 25),
      emitterPassageMm: _d(j, 'pass', 0),
      meshRatio: _d(j, 'ratio', 7),
      chlorination: enumByName(ChlorinationMode.values, j['cl'], ChlorinationMode.auto),
      chlorineResidualMgL: _d(j, 'clres', 1),
      shockMgL: _d(j, 'shock', 10),
      shockMinutes: _d(j, 'shockmin', 45),
      shocksPerMonth: _d(j, 'shockn', 4),
      hypochloritePct: _d(j, 'naocl', 10),
      acidTargetPh: _dn(j, 'acidph'),
      acid: enumByName(AcidProduct.values, j['acid'], AcidProduct.sulfuric),
      filterCost: _d(j, 'cfilter', 0),
      injectorCost: _d(j, 'cinj', 0),
    )..extra = j.unread;
  }
}

/// Two-wire (decoder) valve wiring in the design (Zone → Two-wire system):
/// when [enabled], the design sizes the decoder path of every controller
/// (`two_wire.dart`) and the bill of materials lists decoders, the
/// two-wire cable and the surge protection instead of the station wires.
class TwoWireSettings {
  TwoWireSettings({
    this.enabled = false,
    this.outputVolts = 34,
    this.minVolts = 24,
    this.decoderIdleMa = 1,
    this.solenoidReachM = 30,
    this.groundEveryDecoders = 12,
    this.groundEveryM = 150,
    Map<int, double>? decoderPrices,
    this.arresterPrice = 0,
  }) : decoderPrices = decoderPrices ?? {};

  bool enabled;

  /// Voltage on the path and the least a decoder needs (V), the idle
  /// current of a decoder (mA) and the reach of a solenoid cable (m).
  double outputVolts;
  double minVolts;
  double decoderIdleMa;
  double solenoidReachM;

  /// Grounding (surge arrester and rod): every this many decoders or metres
  /// of path (0 = not used), besides the controller and the path ends.
  int groundEveryDecoders;
  double groundEveryM;

  /// Prices for the bill of materials (0 = not costed): decoders by their
  /// outputs (1, 2, 4, 6) and one surge arrester with its ground rod.
  final Map<int, double> decoderPrices;
  double arresterPrice;

  /// Fields of a newer version, kept as read.
  Map<String, dynamic>? extra;

  bool get isDefault => toJson().isEmpty;

  TwoWireSettings clone() => TwoWireSettings.fromJson(toJson());

  Map<String, dynamic> toJson() => {
    ...?extra,
    if (enabled) 'on': true,
    if (outputVolts != 34) 'v': outputVolts,
    if (minVolts != 24) 'vmin': minVolts,
    if (decoderIdleMa != 1) 'idle': decoderIdleMa,
    if (solenoidReachM != 30) 'reach': solenoidReachM,
    if (groundEveryDecoders != 12) 'gdec': groundEveryDecoders,
    if (groundEveryM != 150) 'gm': groundEveryM,
    if (decoderPrices.values.any((v) => v != 0)) 'cdec': {for (final e in decoderPrices.entries) '${e.key}': e.value},
    if (arresterPrice != 0) 'cgnd': arresterPrice,
  };

  static TwoWireSettings fromJson(Map<String, dynamic>? json) {
    final j = KeyLog(json ?? const {});
    return TwoWireSettings(
      enabled: j['on'] as bool? ?? false,
      outputVolts: _d(j, 'v', 34),
      minVolts: _d(j, 'vmin', 24),
      decoderIdleMa: _d(j, 'idle', 1),
      solenoidReachM: _d(j, 'reach', 30),
      groundEveryDecoders: (j['gdec'] as num?)?.toInt() ?? 12,
      groundEveryM: _d(j, 'gm', 150),
      decoderPrices: {
        for (final e in (_obj(j['cdec']) ?? const <String, dynamic>{}).entries)
          if (int.tryParse(e.key) case final k? when e.value is num) k: (e.value as num).toDouble(),
      },
      arresterPrice: _d(j, 'cgnd', 0),
    )..extra = j.unread;
  }
}

/// Everything of the project under `agb`.
class AgbSettings {
  AgbSettings({PumpHouseSettings? pumpHouse, SolarSettings? solar, WaterQualitySettings? water, TwoWireSettings? twoWire})
    : pumpHouse = pumpHouse ?? PumpHouseSettings(),
      solar = solar ?? SolarSettings(),
      water = water ?? WaterQualitySettings(),
      twoWire = twoWire ?? TwoWireSettings();

  PumpHouseSettings pumpHouse;
  SolarSettings solar;
  WaterQualitySettings water;
  TwoWireSettings twoWire;

  /// Fields of a newer version, kept as read.
  Map<String, dynamic>? extra;

  bool get isDefault => toJson().isEmpty;

  AgbSettings clone() => AgbSettings.fromJson(toJson());

  Map<String, dynamic> toJson() => {
    ...?extra,
    if (!pumpHouse.isDefault) 'pumpHouse': pumpHouse.toJson(),
    if (!solar.isDefault) 'solar': solar.toJson(),
    if (!water.isDefault) 'water': water.toJson(),
    if (!twoWire.isDefault) 'twoWire': twoWire.toJson(),
  };

  static AgbSettings fromJson(Map<String, dynamic>? json) {
    final j = KeyLog(json ?? const {});
    return AgbSettings(
      pumpHouse: PumpHouseSettings.fromJson(_obj(j['pumpHouse'])),
      solar: SolarSettings.fromJson(_obj(j['solar'])),
      water: WaterQualitySettings.fromJson(_obj(j['water'])),
      twoWire: TwoWireSettings.fromJson(_obj(j['twoWire'])),
    )..extra = j.unread;
  }
}
