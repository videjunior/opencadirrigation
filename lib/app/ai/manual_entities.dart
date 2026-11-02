/// The "entities" topic of the AI assistant's manual: every item type with
/// every key of the project file, its unit, default, valid values and the
/// label the properties panel gives it.
///
/// What a key means is written here; everything else is read from the
/// program when the topic is asked for: the keys a type takes and must have
/// ([entityKeys], [entityRequired]), the defaults (an item built by
/// `Entity.fromJson` from [entitySamples] and written back with `toJson`),
/// the default layer ([defaultLayerOf]), the valid values (the enums and
/// tables of the engine) and the panel labels (the English strings). A test
/// fails when a type or a key has no meaning here, or a default written
/// here is not the one `Entity.fromJson` assumes.
library;

import 'dart:convert';

import '../../core/ai/agent_loop.dart';
import '../../core/design/crops.dart' show fao56Crops;
import '../../core/design/effective_rain.dart' show EffectiveRainMethod;
import '../../core/design/pivot.dart' show PivotKind;
import '../../core/design/soils.dart' show soilTable;
import '../../core/design/water_budget.dart' show PlantWaterUse;
import '../../core/model/entities.dart';
import '../i18n.dart';
import 'agent_tools.dart';
import 'agent_tools_edit.dart';

/// What one key of an item means.
class FieldDoc {
  const FieldDoc(this.text, {this.unit = '', this.values, this.panel, this.def, this.defText});

  /// Meaning and effect.
  final String text;
  final String unit;

  /// The values it takes, when they are a closed list.
  final List<String>? values;

  /// i18n key of its label in the properties panel.
  final String? panel;

  /// Default when the project file leaves the key out (a test checks that
  /// writing it changes nothing).
  final Object? def;

  /// The default in words, where a value would mislead.
  final String? defText;
}

/// What an item type is and how it joins the network.
class TypeDoc {
  const TypeDoc(this.title, this.summary, this.fields, {this.connects = 'Never part of the hydraulic network.'});
  final String title;
  final String summary;
  final String connects;
  final Map<String, FieldDoc> fields;
}

/// The least a project-file item of each type holds: the defaults of the
/// manual are what `Entity.fromJson` fills in around it.
const entitySamples = <String, Map<String, Object>>{
  'line': {
    'a': [0, 0],
    'b': [10, 0],
  },
  'polyline': {
    'pts': [
      [0, 0],
      [10, 0],
    ],
  },
  'circle': {
    'p': [0, 0],
    'r': 5,
  },
  'arc': {
    'p': [0, 0],
    'r': 5,
    's': 0,
    'w': 1.5,
  },
  'spline': {
    'pts': [
      [0, 0],
      [5, 3],
      [10, 0],
    ],
  },
  'hatch': {
    'pts': [
      [0, 0],
      [10, 0],
      [10, 10],
    ],
  },
  'symbol': {
    'p': [0, 0],
  },
  'text': {
    'p': [0, 0],
    'text': 'Note',
  },
  'dimension': {
    'a': [0, 0],
    'b': [10, 0],
  },
  'angularDimension': {
    'v': [0, 0],
    'a': [10, 0],
    'b': [0, 10],
  },
  'radialDimension': {
    'c': [0, 0],
    'p': [5, 0],
  },
  'leader': {
    'pts': [
      [0, 0],
      [5, 5],
    ],
    'text': 'Note',
  },
  'image': {
    'p': [0, 0],
  },
  'contour': {
    'pts': [
      [0, 0],
      [10, 0],
    ],
    'z': 100,
  },
  'spotHeight': {
    'p': [0, 0],
    'z': 100,
  },
  'pipe': {
    'pts': [
      [0, 0],
      [10, 0],
    ],
    'scope': 'zone',
  },
  'sprayline': {
    'pts': [
      [0, 0],
      [10, 0],
    ],
    'outlet': 'micro',
  },
  'tape': {
    'pts': [
      [0, 0],
      [10, 0],
    ],
    'spec': 'drip16_16_50',
  },
  'outlet': {
    'p': [0, 0],
    'outlet': 'rotor',
  },
  'controlValve': {
    'p': [0, 0],
  },
  'waterSupply': {
    'p': [0, 0],
  },
  'pump': {
    'p': [0, 0],
  },
  'misc': {
    'p': [0, 0],
    'spec': 'filter_disc50',
  },
  'junction': {
    'p': [0, 0],
  },
  'area': {
    'pts': [
      [0, 0],
      [10, 0],
      [10, 10],
    ],
  },
  'pivot': {
    'p': [0, 0],
    'r': 400,
  },
  'controller': {
    'p': [0, 0],
  },
  'wire': {
    'pts': [
      [0, 0],
      [10, 0],
    ],
  },
  'ordinateDimension': {
    'p': [0, 0],
    'e': [0, 5],
  },
  'comment': {
    'p': [0, 0],
    'text': 'Note',
  },
  'revisionCloud': {
    'pts': [
      [0, 0],
      [10, 0],
      [10, 10],
    ],
  },
  'breakline': {
    'pts': [
      [0, 0],
      [10, 0],
    ],
  },
};

const _pts = FieldDoc('vertices [[x, y], …] in drawing order', unit: 'm');
const _pt = FieldDoc('position [x, y]', unit: 'm');
const _depth = FieldDoc('burial depth: the nodes sit this far below the ground, so their pressure rises by it', unit: 'm', panel: 'props.depth');
const _rot = FieldDoc('rotation of the symbol on the drawing, counter-clockwise from east (no hydraulic effect)', unit: '°');

List<String> get _scopes => [for (final s in HydraulicScope.values) s.name];

/// Every item type (by [EntityType] name) with the meaning of its keys.
final Map<String, TypeDoc> entityDocs = {
  'pipe': TypeDoc(
    'Zone or mainline pipe',
    'A pipe of the zone network (submain, manifold, stub) or of the mainline.',
    {
      'pts': const FieldDoc('vertices [[x, y], …]; at least 2', unit: 'm'),
      'scope': FieldDoc('network it belongs to', values: _scopes, panel: 'props.scope'),
      'spec': const FieldDoc('catalogue pipe id (search_catalog kind "pipe" with usage zone or mainline); without one the design sizes it', panel: 'props.pipe', defText: 'none (sized by the design)'),
      'auto': const FieldDoc('true: the design may resize it even with a spec; false with a spec: analysed as given', panel: 'props.auto'),
      'depth': _depth,
    },
    connects: 'Its nodes are its vertices and the points where it is split: where a point item of its scope, or an end of another pipe or lateral of its scope, lies on its interior (within connectTolerance). Its own ends join other items of its scope the same way (a tee on their interior). Pipes that only cross do not join (pipes_cross). A zone pipe and a mainline pipe join only through a control valve.',
  ),
  'sprayline': TypeDoc(
    'Lateral with emitters',
    'A lateral pipe with equally spaced emitters (sprinklers, micro-sprinklers, drippers) along it, analysed with each emitter at its own pressure.',
    {
      'pts': const FieldDoc('vertices [[x, y], …]; the emitters are measured from the first point', unit: 'm'),
      'outlet': const FieldDoc('emitter family id (search_catalog kind "emitter")', panel: 'props.outlet'),
      'nozzle': const FieldDoc('nozzle id of that family', panel: 'props.nozzle', defText: 'the family\'s first nozzle'),
      'head': const FieldDoc('nominal pressure at the emitters: the zone is designed so their mean pressure equals it; keep it inside the nozzle\'s pressure range', unit: 'm', panel: 'props.head'),
      'sp': const FieldDoc('emitter spacing along the line; above 0', unit: 'm', panel: 'props.spacing'),
      'off': const FieldDoc('distance from the first point to the first emitter; 0 = one spacing. Emitters follow every sp up to the end', unit: 'm', panel: 'props.offset'),
      'arc': const FieldDoc('wetted arc of each emitter (uniformity and precipitation)', unit: '°', panel: 'props.arc'),
      'riser': const FieldDoc('riser height above the lateral, added to the catalogue riser', unit: 'm', panel: 'props.riser'),
      'spec': const FieldDoc('lateral pipe id (usage lateral); without one the design sizes it', panel: 'props.pipe', defText: 'none (sized by the design)'),
      'auto': const FieldDoc('as for pipes: true lets the design resize it', panel: 'props.auto'),
      'depth': _depth,
    },
    connects: 'Zone scope. Joins where one of its ends lies on a zone pipe (the submain) or lateral, at a vertex or on the interior (which is split there), or where a vertex coincides with another item\'s vertex; a point item on its interior splits it. Emitter count = floor((length − first) / sp) + 1, with first = off, or sp when off is 0.',
  ),
  'tape': TypeDoc('Drip tape or dripline', 'A drip lateral whose emitters and pipe come from one catalogue tape model.', {
    'pts': const FieldDoc('vertices [[x, y], …]; emitters every tape spacing from the first point', unit: 'm'),
    'spec': const FieldDoc('tape id (search_catalog kind "tape")', panel: 'props.tape'),
    'inlet': const FieldDoc(
      'nominal pressure at the inlet: the zone is designed so its emitters\' mean pressure equals it; keep it inside the tape\'s pressure range',
      unit: 'm',
      panel: 'props.inlet',
    ),
    'reg': const FieldDoc(
      'pressure regulator at the inlet: it holds the tape inlet at "inlet" whatever the submain gives (the tape no longer follows the zone valve); the zone valve is raised until every regulated tape has submin at its submain connection',
      panel: 'props.regulated',
    ),
    'submin': const FieldDoc('least submain pressure a regulated inlet needs to regulate (at least "inlet"; 0 = "inlet")', unit: 'm', panel: 'props.submainMin'),
    'depth': const FieldDoc('burial depth (subsurface drip): the emitters sit this far below the ground', unit: 'm', panel: 'props.depth'),
    'flush': const FieldDoc('extra flow out of the open end for the flushing analysis; 0 = from flushingVelocity', unit: 'm³/s', panel: 'props.flushingFlow'),
  }, connects: 'Zone scope, joins like a sprayline. Emitter count = floor(length / tape emitter spacing). Never sized: its tape model is its pipe.'),
  'outlet': TypeDoc(
    'Single sprinkler or emitter',
    'One head: a sprinkler, rotor, spray, gun or emitter at a point. Zone scope for heads fed by a zone valve; mainline scope for valve-in-head heads, which open by stations.',
    {
      'p': _pt,
      'outlet': const FieldDoc('emitter family id (search_catalog kind "emitter")', panel: 'props.outlet'),
      'nozzle': const FieldDoc('nozzle id of that family', panel: 'props.nozzle', defText: 'the family\'s first nozzle'),
      'head': const FieldDoc('nominal pressure at the nozzle; keep it inside the nozzle\'s range', unit: 'm', panel: 'props.head'),
      'arc': const FieldDoc('wetted arc; a part-circle nozzle waters only its own arc', unit: '°', panel: 'props.arc'),
      'rot': const FieldDoc('where the wetted arc starts; it runs counter-clockwise from there over "arc"', unit: '° from east', panel: 'props.orientation'),
      'riser': const FieldDoc('riser height, added to the catalogue riser', unit: 'm', panel: 'props.riser'),
      'scope': FieldDoc('"zone" or "mainline" (a valve-in-head head on the mainline)', values: _scopes, panel: 'props.scope'),
      'zone': const FieldDoc('mainline heads only: the valve-in-head station; heads sharing a name open together, an empty one is a station of its own', panel: 'props.vihStation', def: ''),
    },
    connects: 'Joins a node of its scope at its position: it must lie on a pipe or lateral of that scope (a vertex, or the interior, which it splits). Elsewhere it is unconnected.',
  ),
  'controlValve': TypeDoc(
    'Zone control valve',
    'The valve that opens one zone: it joins the mainline to the zone pipes; the zone takes its name.',
    {
      'p': _pt,
      'spec': const FieldDoc(
        'control valve id (search_catalog kind "valve", kind control). Without one the zone has no valve loss and no flow check; optimize_design picks the smallest that fits',
        panel: 'props.valve',
        defText: 'none',
      ),
      'zone': const FieldDoc('zone name, unique among the valves (duplicate_zone_name otherwise); system flows and reports use it', panel: 'props.zone', defText: 'its name, else a new "Zone n"'),
      'fixed': const FieldDoc(
        'downstream pressure the zone is analysed at, instead of the one that gives the emitters their mean nominal pressure',
        unit: 'm',
        panel: 'props.fixedHead',
        defText: 'none (calculated)',
      ),
      'rot': _rot,
      'depth': _depth,
    },
    connects: 'Makes a mainline node and a zone node at its position: the mainline must reach the position (a pipe vertex or interior point there, reached from a supply) and the zone pipes start there. The zone is everything reached from the zone node through zone items.',
  ),
  'waterSupply': TypeDoc('Water supply', 'Where the water enters: a well, reservoir, tank, canal or a pressurised connection.', {
    'p': _pt,
    'calc': const FieldDoc('true: the design finds the pressure the system needs here (the "needs" figure); false: it gives dh', panel: 'props.calc'),
    'dh': const FieldDoc('pressure the supply gives when calc is false; valves short of pressure are reported', unit: 'm', panel: 'props.designHead'),
    'mh': const FieldDoc('largest pressure it can give; a need above it is reported (supply_head_exceeded); 0 = no limit', unit: 'm', panel: 'props.maxHead'),
    'dq': const FieldDoc(
      'design flow, the source\'s capacity: a system flow drawing more is reported (supply_flow_exceeded) and set_system_flows "auto" packs the zones under it; 0 = unknown',
      unit: 'm³/s',
      panel: 'props.designFlow',
    ),
    'mq': const FieldDoc('largest flow it can give; 0 = no limit', unit: 'm³/s', panel: 'props.maxFlow'),
    'wl': const FieldDoc(
      'water level relative to the ground: negative in a well (−8 = 8 m down), positive for a raised tank; the supply node stands at ground + wl',
      unit: 'm',
      panel: 'props.waterLevel',
    ),
  }, connects: 'A mainline node at its position, standing at the water level: the mainline must start there (or pass through it). A supply without a pipe is unconnected.'),
  'pump': TypeDoc(
    'Pump',
    'A pump in line on a pipe: it adds the head of its catalogue curve at the flow.',
    {
      'p': _pt,
      'spec': const FieldDoc('pump id (search_catalog kind "pump"); without one the pump is reported (spec_missing)', panel: 'props.pump', defText: 'none'),
      'scope': FieldDoc('network it sits in', values: _scopes, panel: 'props.scope'),
      'speed': const FieldDoc('speed ratio to the rated speed (affinity laws); outside 0.4–1.3 it is reported. With vfd it is the top speed', panel: 'props.speed'),
      'vfd': const FieldDoc('variable-speed drive: the outlet pressure it keeps in every system flow; 0 = fixed speed', unit: 'm', panel: 'props.vfdTarget', def: 0),
      'vmin': const FieldDoc('least speed ratio of the drive', panel: 'props.vfdMin', def: 0.5),
      'meff': const FieldDoc(
        'efficiency of the motor and its drive (0.05–1), wire to shaft: the energy of the design, the 24-hour simulation and the tariff schedule divide by it as well as by the pump curve\'s efficiency; 1 = the pump efficiency stands for the whole set',
        panel: 'props.motorEfficiency',
        def: 1,
      ),
      'hm': const FieldDoc('hour meter fitted: its price for the bill of materials (the key present = fitted)', panel: 'acc.hourMeter', defText: 'none (no hour meter)'),
      'rot': _rot,
    },
    connects: 'In line: it must lie on a pipe of its scope (vertex or interior, which it splits); the side nearer the supply (mainline) or the zone valve (zone) is the suction side. A submersible model sits at the water level of its supply.',
  ),
  'misc': TypeDoc(
    'In-line device',
    'A filter, meter, pressure reducing (PRV) or sustaining (PSV) valve, flow limiter (FCV), check valve, backflow preventer, gate valve, air valve or master valve on a pipe.',
    {
      'p': _pt,
      'spec': const FieldDoc('device id (search_catalog kind "valve": every kind but control); its kind decides what it does: a loss curve, or a PRV/PSV/FCV setting', panel: 'props.misc'),
      'scope': FieldDoc('network it sits in', values: _scopes, panel: 'props.scope'),
      'set': const FieldDoc('PRV: pressure kept downstream; PSV: pressure kept upstream; 0 = the model\'s setting', unit: 'm', panel: 'props.setting'),
      'setq': const FieldDoc('FCV: the flow it lets through; 0 = the model\'s largest flow', unit: 'm³/s', panel: 'props.flowLimit', def: 0),
      'rot': _rot,
    },
    connects: 'In line like a pump: it must lie on a pipe of its scope, which it splits.',
  ),
  'junction': TypeDoc('Junction', 'A node at a point: a place to give a fixed elevation, or to mark where pipes of its scope meet.', {
    'p': _pt,
    'scope': FieldDoc('network it belongs to', values: _scopes, panel: 'props.scope'),
    'z': const FieldDoc('fixed elevation of that node instead of the terrain', unit: 'm', panel: 'props.elevationDem', defText: 'none (from the terrain)'),
  }, connects: 'A node of its scope at its position; it splits a pipe it lies on.'),
  'pivot': TypeDoc(
    'Centre pivot or linear move',
    'A mechanised machine: a demand on the mainline whose flow (irrigated area × gross depth ÷ hours per cycle) and inlet pressure (end pressure + friction + ground rise + pipe height + machine losses) come from the machine hydraulics.',
    {
      'p': const FieldDoc('pivot point (or the inlet of a linear)', unit: 'm'),
      'r': const FieldDoc('span pipe length to the last sprinkler; the irrigated radius adds the throw', unit: 'm', panel: 'props.pivotRadius'),
      'kind': FieldDoc('"pivot" or "linear"', values: [for (final k in PivotKind.values) k.name], panel: 'props.pivotKind'),
      'ang': const FieldDoc('direction the span is drawn (a pivot) or the lateral runs (a linear); for a sector, the middle of the sweep', unit: '° from east', panel: 'props.pivotAngle'),
      'sector': const FieldDoc('irrigated sector of a pivot, 1–360', unit: '°', panel: 'props.pivotSector', def: 360),
      'travel': const FieldDoc('linear: travel length across the field', unit: 'm', panel: 'props.pivotTravel', def: 0),
      'span': const FieldDoc('span length between towers', unit: 'm', panel: 'props.pivotSpan'),
      'depth': const FieldDoc('gross depth applied per cycle (revolution or pass)', unit: 'mm', panel: 'props.pivotDepth'),
      'hours': const FieldDoc('hours per cycle', unit: 'h', panel: 'props.pivotHours'),
      'hend': const FieldDoc('pressure needed at the end sprinkler', unit: 'm', panel: 'props.pivotEndP'),
      'qg': const FieldDoc('end gun flow; 0 = no end gun', unit: 'm³/s', panel: 'props.pivotGunQ', def: 0),
      'hg': const FieldDoc('end gun pressure', unit: 'm', panel: 'props.pivotGunP', def: 0),
      'throw': const FieldDoc('throw beyond the end of the machine', unit: 'm', panel: 'props.pivotThrow'),
      'spec': const FieldDoc('catalogue pipe of the spans (usage mainline); without one idmm and c are used', panel: 'props.pivotPipe', defText: 'none (idmm and c)'),
      'idmm': const FieldDoc('span pipe inner diameter', unit: 'mm', panel: 'props.pivotPipeId'),
      'c': const FieldDoc('Hazen-Williams C of the span pipe', panel: 'props.pivotC'),
      'hp': const FieldDoc('height of the span pipe above the ground', unit: 'm', panel: 'props.pivotHeight'),
      'ww': const FieldDoc('wetted width at the end, for the application rate', unit: 'm', panel: 'props.pivotWidth'),
      'hm': const FieldDoc('losses in the machine (swivel, drops, regulators)', unit: 'm', panel: 'props.pivotLoss'),
      'imax': const FieldDoc('soil intake rate the peak application rate must not exceed (pivot_app_rate); 0 = no check', unit: 'mm/h', panel: 'props.pivotMaxRate', def: 0),
      'zone': const FieldDoc('name used in system flows and reports', panel: 'props.zone', def: ''),
      'ssp': const FieldDoc('sprinkler spacing along the span (sprinkler chart, bill of materials)', unit: 'm', panel: 'props.pivotSprSpacing'),
      'sspec': const FieldDoc('catalogue sprinkler of the package', panel: 'props.pivotSprinkler', defText: 'none'),
      'rspec': const FieldDoc('catalogue pressure regulator (kind prv) of the package', panel: 'props.pivotRegulator', defText: 'none'),
      'cost': const FieldDoc('machine price for the bill of materials; 0 = not costed', panel: 'props.pivotCost', def: 0),
      'tcost': const FieldDoc('price of one tower (span and drive)', panel: 'props.pivotTowerCost', def: 0),
      'mach': const FieldDoc('package, drive, corner arm, variable rate and electrical data (read-only here: the machine dialog of the properties panel or run_operation sets them)'),
    },
    connects: 'Draws its flow at its centre, which must lie on a mainline pipe (vertex or interior) reached from a supply; otherwise unconnected.',
  ),
  'area': TypeDoc(
    'Irrigated area',
    'An irrigated field, lawn, bed or hydrozone (a closed polygon). The layout tools fill areas; the agronomy reports (crop water requirement, schedule, water budget) and the emitters per plant of the EU use the area holding a zone\'s emitters.',
    {
      'pts': const FieldDoc('polygon vertices [[x, y], …], at least 3, enclosing a surface', unit: 'm'),
      // 1.6.0 MOD
      'holes': const FieldDoc(
        'islands inside the outline that are not irrigated (a pond, a building, a bed): closed polygons [[[x, y], …], …]; the area, the water it needs and the layout leave them out. Change them with the operations subtract_from_area and set_area_holes',
        unit: 'm',
        defText: 'none (no islands)',
      ),
      'crop': const FieldDoc('crop name shown in the reports', panel: 'props.crop'),
      'ck': FieldDoc('FAO-56 crop key (read_manual "agronomy" lists each with its Kc); set kc, root and mad with it, as the panel does', values: [...fao56Crops.keys], panel: 'req.crop', def: ''),
      'im': const FieldDoc(
        'irrigation method: the leaching formula and, for localized, the ground-cover reduction of Kc',
        values: ['sprinkler', 'localized', 'surface'],
        panel: 'req.method',
        def: 'sprinkler',
      ),
      'depth': const FieldDoc('net irrigation depth per day used when wb is false', unit: 'mm/day', panel: 'props.netDepth'),
      'eff': const FieldDoc('application efficiency, 0–1: gross = net ÷ eff', panel: 'props.efficiency'),
      'wb': const FieldDoc('true: the requirement comes from eto × kc and the soil water balance (awc, root, mad) instead of depth', panel: 'props.waterBalance', def: false),
      'eto': const FieldDoc('reference evapotranspiration (with wb; the downloaded climate gives it by month)', unit: 'mm/day', panel: 'props.eto'),
      'kc': const FieldDoc('crop coefficient', panel: 'props.kc'),
      'awc': const FieldDoc('available water capacity of the soil', unit: 'mm per m', panel: 'props.awc'),
      'root': const FieldDoc('effective root depth', unit: 'm', panel: 'props.rootDepth'),
      'mad': const FieldDoc('management allowed depletion, 0–1: the share of the available water used before irrigating', panel: 'props.mad'),
      'psp': const FieldDoc('plant spacing along the row; 0 = not set', unit: 'm', def: 0),
      'rsp': const FieldDoc('row spacing; 0 = not set', unit: 'm', def: 0),
      'wf': const FieldDoc('wetted fraction of the area, 0–1 (localized irrigation)', panel: 'props.wettedFraction', def: 1),
      'epp': const FieldDoc('emitters per plant for the EU of zones mostly inside the area; 0 = the project\'s emittersPerPlant', panel: 'props.emittersPerPlant', def: 0),
      'soil': FieldDoc('soil texture key; the panel then sets awc from it', values: [...soilTable.keys], panel: 'req.soil', def: ''),
      'slope': const FieldDoc('ground slope (intake and runoff)', unit: '%', panel: 'req.slope', def: 0),
      'pd': const FieldDoc('planting or green-up date "MM-DD"; "" = the crop table\'s planting month', panel: 'req.planting', def: ''),
      'gc': const FieldDoc('canopy ground cover, 0–1 (localized Kc reduction)', panel: 'req.groundCover', def: 1),
      'kr': const FieldDoc(
        'localized reduction factor Kr typed, 0.05–1; 0 = 0.1·√(ground cover %); ETc,loc = Kr·Kc·ETo sets volumes and run times, wf only the readily available water',
        panel: 'area.kr',
        def: 0,
      ),
      'yp': const FieldDoc('yield potential (%) whose soil salinity sets the leaching requirement, 50–100', unit: '%', panel: 'req.yieldPotential', def: 100),
      'kcc': const FieldDoc('false: no climatic adjustment of Kc mid and Kc end to the RHmin and wind of the site climate (FAO-56 eqs. 62, 65)', panel: 'req.climateKc', def: true),
      'ecw': const FieldDoc('salinity of the irrigation water; 0 = no leaching', unit: 'dS/m', panel: 'req.ecw', def: 0),
      'erm': FieldDoc('effective rain method', values: [for (final m in EffectiveRainMethod.values) m.name], panel: 'req.rainMethod', def: 'usdaScs'),
      'dep': const FieldDoc('true: dependable rain (80 % probability) instead of the mean', panel: 'req.dependable', def: false),
      'pwu': FieldDoc(
        'plant water use of a landscape hydrozone for the water budget; "" = not a hydrozone',
        values: ['', for (final w in PlantWaterUse.values) w.name],
        panel: 'wb.plantWaterUse',
        def: '',
      ),
    },
  ),
  'controller': TypeDoc('Irrigation controller', 'A controller (timer) that powers the valve solenoids through the wire routes from it; every valve reached gets a station.', {
    'p': _pt,
    'st': const FieldDoc('stations (valve outputs); more valves than stations is reported (elec_stations)', panel: 'props.stations'),
    'v': const FieldDoc('output voltage under load (AC)', unit: 'V', panel: 'props.outputVolts'),
    'sim': const FieldDoc('most stations open at once; 0 = as the system flows say', panel: 'props.maxSimultaneous', def: 0),
    'ist': const FieldDoc('largest current one station output delivers; 0 = 0.56 A, typical of 24 V AC controllers (elec_station_current above it)', unit: 'A', panel: 'props.stationMaxA', def: 0),
    'itot': const FieldDoc('largest current the whole controller delivers; 0 = 1.5 A, typical (elec_overcurrent above it)', unit: 'A', panel: 'props.totalMaxA', def: 0),
    'cost': const FieldDoc('price for the bill of materials; 0 = not costed', def: 0),
    'acc': const FieldDoc('sensors and accessories with their prices (read-only here: set them in the properties panel)'),
  }, connects: 'Joins the wire routes at a vertex or on a route; not hydraulic.'),
  'wire': TypeDoc(
    'Wire route',
    'A trench or conduit for the valve wires, from a controller towards the valves; route_wires draws them along the pipes.',
    {'pts': _pts},
    connects:
        'Routes sharing a vertex connect; a controller or valve on a vertex or on the route joins it. Each valve reached has its own station conductor along the route and shares the common one.',
  ),
  'contour': TypeDoc('Contour line', 'A terrain contour: its vertices are terrain data at elevation z.', {
    'pts': _pts,
    'z': const FieldDoc('elevation', unit: 'm', panel: 'props.elevation'),
    'gen': const FieldDoc('read-only: true for contours generated from the terrain model, which are drawn but are not terrain data'),
  }),
  'spotHeight': TypeDoc('Spot height', 'A terrain point at elevation z. Those named "DEM …" are downloaded elevation points (download_terrain replaces them).', {
    'p': _pt,
    'z': const FieldDoc('elevation', unit: 'm', panel: 'props.elevation'),
  }),
  'breakline': TypeDoc('Breakline', 'A terrain line the triangulation does not cross: a ridge, channel bottom, terrace edge, road or embankment.', {
    'pts': _pts,
    'zs': const FieldDoc('elevation of each vertex, null where the other terrain data give it', unit: 'm', panel: 'props.breaklineZs', defText: 'none (all from the terrain)'),
  }),
  'line': TypeDoc('Line', 'A straight line (drawing only).', {'a': const FieldDoc('first point [x, y]', unit: 'm'), 'b': const FieldDoc('second point [x, y]', unit: 'm')}),
  'polyline': TypeDoc('Polyline', 'A polyline (drawing only). A closed one is a closed shape: the layout tools accept it as an area and fit_pivot avoids it.', {
    'pts': _pts,
    'closed': const FieldDoc('closed polygon', panel: 'props.closed'),
  }),
  'spline': TypeDoc('Spline', 'A smooth curve through its points (drawing only); a closed one is a closed shape; generate_block can follow one as a guide.', {
    'pts': _pts,
    'closed': const FieldDoc('closed curve', panel: 'props.closed'),
  }),
  'circle': TypeDoc('Circle', 'A circle (drawing only); a closed shape for the layout tools and the pivot fit.', {
    'p': const FieldDoc('centre [x, y]', unit: 'm'),
    'r': const FieldDoc('radius', unit: 'm', panel: 'props.radius'),
  }),
  'arc': TypeDoc('Arc', 'A circular arc (drawing only).', {
    'p': const FieldDoc('centre [x, y]', unit: 'm'),
    'r': const FieldDoc('radius', unit: 'm', panel: 'props.radius'),
    's': const FieldDoc('start angle, counter-clockwise from east', unit: 'rad'),
    'w': const FieldDoc('sweep; negative runs clockwise', unit: 'rad'),
  }),
  'hatch': TypeDoc('Hatch', 'A hatched or solid filled polygon (drawing only; a closed shape).', {
    'pts': const FieldDoc('polygon vertices, at least 3', unit: 'm'),
    'ang': const FieldDoc('hatch line angle', unit: '°', panel: 'props.hatchAngle'),
    'sp': const FieldDoc('hatch line spacing', unit: 'm', panel: 'props.hatchSpacing'),
    'solid': const FieldDoc('solid fill', panel: 'props.hatchSolid'),
  }),
  'text': TypeDoc('Text', 'A text on the drawing.', {
    'p': const FieldDoc('insertion point (bottom left) [x, y]', unit: 'm'),
    'text': const FieldDoc('the text', panel: 'props.text'),
    'h': const FieldDoc('text height', unit: 'm', panel: 'props.textHeight'),
    'rot': const FieldDoc('rotation, counter-clockwise from east', unit: '°', panel: 'props.rotation'),
  }),
  'leader': TypeDoc('Leader', 'An arrow polyline ending at a note.', {
    'pts': const FieldDoc('arrow vertices from the tip; the text sits at the last one', unit: 'm'),
    'text': const FieldDoc('the note', panel: 'props.text'),
    'h': const FieldDoc('text height', unit: 'm', panel: 'props.textHeight'),
  }),
  'symbol': TypeDoc('Symbol', 'A vector symbol sized in metres. Tree symbols inside an area can be ringed by tree_rings; fit_pivot keeps 10 m from every symbol.', {
    'p': _pt,
    'kind': FieldDoc('symbol', values: [for (final k in SymbolKind.values) k.name], panel: 'props.symbolKind'),
    'size': const FieldDoc('size', unit: 'm', panel: 'props.symbolSize'),
    'rot': const FieldDoc('rotation, counter-clockwise from east', unit: '°', panel: 'props.rotation'),
  }),
  'comment': TypeDoc('Review comment', 'A note pinned to the drawing for the people reviewing it; outside the hydraulics and the bill of materials.', {
    'p': _pt,
    'text': const FieldDoc('the comment', panel: 'props.text'),
    'author': const FieldDoc('who wrote it', panel: 'props.author', def: ''),
    'date': const FieldDoc('when, "YYYY-MM-DD"', panel: 'props.date', def: ''),
    'done': const FieldDoc('resolved', panel: 'props.resolved', def: false),
    'photo': const FieldDoc(
      'a small JPEG of a field photo taken there (add_photo_comment sets it from a photo the user attached); the model reads only its size, and "" removes it',
      panel: 'props.removePhoto',
      def: '',
    ),
  }),
  'dimension': TypeDoc('Linear dimension', 'A dimension between two points (made with the drawing tools; update_entities cannot change it).', {
    'a': const FieldDoc('first point [x, y]', unit: 'm'),
    'b': const FieldDoc('second point [x, y]', unit: 'm'),
    'off': const FieldDoc('offset of the dimension line', unit: 'm', panel: 'props.dimOffset'),
  }),
  'angularDimension': TypeDoc('Angular dimension', 'The angle between the rays vertex → a and vertex → b (made with the drawing tools).', {
    'v': const FieldDoc('vertex [x, y]', unit: 'm'),
    'a': const FieldDoc('point on the first ray', unit: 'm'),
    'b': const FieldDoc('point on the second ray', unit: 'm'),
    'r': const FieldDoc('radius of the dimension arc', unit: 'm', panel: 'props.dimRadius'),
  }),
  'radialDimension': TypeDoc('Radius or diameter dimension', 'A radius (or diameter) dimension of a circle (made with the drawing tools).', {
    'c': const FieldDoc('centre [x, y]', unit: 'm'),
    'p': const FieldDoc('point on the circle', unit: 'm'),
    'dia': const FieldDoc('dimension the diameter', panel: 'props.dimDiameter', def: false),
  }),
  'ordinateDimension': TypeDoc('Ordinate dimension', 'The X or Y coordinate of a point from an origin, at the end of a leader (made with the drawing tools).', {
    'p': const FieldDoc('point measured [x, y]', unit: 'm'),
    'e': const FieldDoc('end of the leader, where the value is written', unit: 'm'),
    'o': const FieldDoc('origin [x, y]', unit: 'm', panel: 'props.ordinateOrigin', defText: '[0, 0]'),
    'x': const FieldDoc('true measures X, false Y', panel: 'props.ordinateX'),
  }),
  'image': TypeDoc('Image', 'A raster image (aerial photo, scanned plan) placed in the drawing (made by File → Import; update_entities cannot change it).', {
    'p': const FieldDoc('bottom-left corner [x, y]', unit: 'm'),
    'w': const FieldDoc('width', unit: 'm', panel: 'props.imageWidth'),
    'h': const FieldDoc('height', unit: 'm', panel: 'props.imageHeight'),
    'rot': const FieldDoc('rotation about the corner, counter-clockwise', unit: '°', panel: 'props.rotation'),
    'op': const FieldDoc('opacity, 0.05–1', panel: 'props.opacity'),
    'mime': const FieldDoc('image type'),
    'src': const FieldDoc('file it came from', panel: 'props.source', def: ''),
    'data': const FieldDoc('the encoded image (left out of get_entity)', defText: 'none'),
  }),
  'revisionCloud': TypeDoc('Revision cloud', 'A cloud round what changed in a revision; the revision table of the sheet lists it (made with the drawing tools).', {
    'pts': const FieldDoc('outline vertices', unit: 'm'),
    'rev': const FieldDoc('revision', panel: 'props.revision', def: ''),
    'date': const FieldDoc('date', panel: 'props.date', def: ''),
    'desc': const FieldDoc('description', panel: 'props.description', def: ''),
    'arc': const FieldDoc('chord of each arc; 0 = from the outline size', unit: 'm', panel: 'props.arcLength', def: 0),
  }),
};

/// Order of the index: the hydraulic network first.
const _groups = <String, List<String>>{
  'Hydraulic network': ['waterSupply', 'pump', 'misc', 'pipe', 'controlValve', 'sprayline', 'tape', 'outlet', 'junction', 'pivot'],
  'Fields and wiring': ['area', 'controller', 'wire'],
  'Terrain': ['contour', 'spotHeight', 'breakline'],
  'Drawing and notes': ['line', 'polyline', 'spline', 'circle', 'arc', 'hatch', 'text', 'leader', 'symbol', 'comment'],
  'Made by the drawing tools (read with get_entity)': ['dimension', 'angularDimension', 'radialDimension', 'ordinateDimension', 'image', 'revisionCloud'],
};

final _en = I18n('en');

/// A sample item of [type] as `Entity.fromJson` builds it.
Entity sampleEntity(String type, [Map<String, Object?> extra = const {}]) => Entity.fromJson({...entitySamples[type]!, ...extra, 'type': type, 'id': 'manual', 'layer': 'MANUAL'});

/// A value as the manual writes it.
String manualValue(Object? v) => switch (v) {
  null => 'none',
  String s => '"$s"',
  double d => numText(d),
  List<Object?> l => jsonEncode(l),
  Map<Object?, Object?> m => jsonEncode(m),
  _ => '$v',
};

/// [v] without trailing zeros (up to six significant digits).
String numText(double v) {
  if (v == v.roundToDouble() && v.abs() < 1e15) return '${v.toInt()}';
  var s = v.toStringAsPrecision(6);
  if (!s.contains('e') && s.contains('.')) s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  return s;
}

/// The default of [key] of [type], as the manual states it.
String fieldDefault(String type, String key) {
  final doc = entityDocs[type]!.fields[key];
  final sample = entitySamples[type]!;
  if (sample.containsKey(key) && (entityRequired[type] ?? const []).contains(key)) return 'required';
  if (sample.containsKey(key) && !entityKeys.containsKey(type)) return 'always set';
  if (doc?.defText != null) return doc!.defText!;
  final json = sampleEntity(type).toJson();
  if (!sample.containsKey(key) && json.containsKey(key)) return manualValue(json[key]);
  if (doc?.def != null) return manualValue(doc!.def);
  return 'none';
}

/// The keys of [type] the project file holds, in the order the manual
/// lists them: those create_entities takes, then the read-only ones.
List<String> typeKeys(String type) {
  final doc = entityDocs[type];
  final take = entityKeys[type];
  return [...?take, ...?doc?.fields.keys.where((k) => take == null || !take.contains(k))];
}

String _layerOf(String type) {
  if (!entityKeys.containsKey(type)) return 'the one the drawing tool that made it uses';
  if (type == 'pipe') return '${defaultLayerOf(sampleEntity(type, {'scope': 'zone'}))} or ${defaultLayerOf(sampleEntity(type, {'scope': 'mainline'}))}';
  return defaultLayerOf(sampleEntity(type));
}

String _typeLine(String type) {
  final doc = entityDocs[type]!;
  final req = entityRequired[type] ?? const <String>[];
  final keys = [for (final k in typeKeys(type)) req.contains(k) ? '$k*' : k];
  return '- $type (${doc.title}) {${keys.join(', ')}}: ${doc.summary}';
}

String _entityIndex() {
  final out = StringBuffer(
    '# Item types\n'
    'Keys are those of the project file; create_entities takes them for the types it can create, update_entities changes them, get_entity shows them. * = required to create. SI units, points [x, y] in metres. read_manual {"topic": "entities", "item": "<type>"} gives every key with its unit, default and values (several types: "pipe, sprayline").\n',
  );
  for (final g in _groups.entries) {
    out.writeln('\n## ${g.key}');
    for (final type in g.value) {
      out.writeln(_typeLine(type));
    }
  }
  out.writeln('\nEvery item also has "name" (free text; tools find items by name too) and "layer" (default: its type\'s layer).');
  return out.toString();
}

String _entityDetail(String type) {
  final doc = entityDocs[type]!;
  final creatable = entityKeys.containsKey(type);
  final req = entityRequired[type] ?? const <String>[];
  final out = StringBuffer(
    '## $type: ${doc.title}\n${doc.summary}\nNetwork: ${doc.connects}\nDefault layer: ${_layerOf(type)}.${creatable ? '' : ' Not created or changed by create_entities / update_entities.'}\nKeys:\n',
  );
  for (final k in typeKeys(type)) {
    final f = doc.fields[k];
    final writable = entityKeys[type]?.contains(k) ?? false;
    final parts = <String>[
      if (f != null) f.text,
      if (f?.unit.isNotEmpty ?? false) 'unit ${f!.unit}',
      if (f?.values != null && f!.values!.length <= 40) 'values ${f.values!.map((v) => v.isEmpty ? '""' : v).join(' | ')}',
      if (f?.values != null && f!.values!.length > 40) '${f.values!.length} values, e.g. ${f.values!.take(6).join(', ')}',
      req.contains(k) ? 'required' : 'default ${fieldDefault(type, k)}',
      if (f?.panel != null) 'panel: "${_en(f!.panel!)}"',
      if (creatable && !writable) 'read-only',
    ];
    out.writeln('- $k: ${parts.join('; ')}');
  }
  out.writeln('- name, layer: as for every item.');
  return out.toString();
}

/// The "entities" topic: the index, or the types named in [item].
String entitiesTopic(AgentToolbox b, String? item) {
  if (item == null || item.trim().isEmpty) return _entityIndex();
  final byLower = {for (final t in EntityType.values) t.name.toLowerCase(): t.name};
  final names = [
    for (final s in item.split(RegExp(r'[,;\s]+')))
      if (s.trim().isNotEmpty) s.trim(),
  ];
  final out = <String>[];
  for (final n in names.take(4)) {
    final type = byLower[n.toLowerCase()];
    if (type == null) throw ToolInputError('No item type "$n". Types: ${EntityType.values.map((t) => t.name).join(', ')}.');
    out.add(_entityDetail(type));
  }
  if (names.length > 4) out.add('(at most 4 types per call)');
  return out.join('\n');
}
