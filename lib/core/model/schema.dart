/// JSON Schema of the `.oci.json` project file, built from the model itself
/// (the keys each object writes, their JSON type and the default value of a
/// new project), with the units of the keys documented in [fieldNotes].
/// `dart run bin/oci.dart schema` prints it; being built at run time, it
/// cannot fall behind the model.
library;

import 'dart:math' as math;

import 'catalog.dart';
import 'entities.dart';
import 'geometry.dart';
import 'project.dart';

/// What a key means and its unit (SI inside the file: lengths and
/// elevations in m, flows in m³/s, heads in metres of water, diameters in
/// mm where the key says so, prices in the project currency).
const fieldNotes = <String, String>{
  // entities
  'type': 'kind of entity',
  'id': 'unique identifier (e<number> when made by the app)',
  'layer': 'layer name',
  'name': 'name shown in the drawing and the reports',
  'p': 'position [x, y] (m)',
  'pts': 'vertices [[x, y], …] (m)',
  'a': 'first point [x, y] (m)',
  'b': 'second point [x, y] (m)',
  'c': 'centre [x, y] (m); in a pipe item, the Hazen-Williams C',
  'v': 'vertex [x, y] (m); in a controller, the output voltage (V)',
  'e': 'end of the leader [x, y] (m)',
  'o': 'origin of the ordinates [x, y] (m)',
  'r': 'radius (m)',
  's': 'start angle (rad, counter-clockwise from +x)',
  'w': 'sweep (rad); in an image, its width (m)',
  'h': 'text height or image height (m)',
  'rot': 'rotation (degrees, counter-clockwise)',
  'z': 'elevation (m); in a junction, the fixed elevation of its node',
  'zs': 'elevation of every vertex (m; null = taken from the terrain)',
  'gen': 'generated from the terrain model (not a survey input)',
  'scope': 'zone (downstream of a valve) or mainline',
  'spec': 'catalogue item id',
  'outlet': 'catalogue emitter id',
  'nozzle': 'nozzle id of the catalogue emitter',
  'head': 'pressure head at the emitter (m)',
  'inlet': 'pressure head at the inlet of the tape (m)',
  'arc': 'arc watered (degrees, 360 = full circle)',
  'sp': 'spacing of the emitters along the line (m); in a hatch, of its lines (m)',
  'off': 'distance of the first emitter from the start (m); in a dimension, its offset (m)',
  'riser': 'riser height (m)',
  'depth': 'burial depth (m); in an area, the net daily depth (mm/day); in a pivot, the gross depth (mm)',
  'auto': 'the design chooses the size',
  'zone': 'zone name of a valve; station name of a valve-in-head sprinkler',
  'fixed': 'fixed downstream head of a valve (m)',
  'calc': 'the design computes the supply pressure',
  'dh': 'design head of the supply (m)',
  'mh': 'maximum head of the supply (m)',
  'dq': 'design flow of the supply (m³/s)',
  'mq': 'maximum flow of the supply (m³/s)',
  'wl': 'water level below the supply point (m)',
  'speed': 'speed ratio of the pump (1 = rated)',
  'hm': 'price of the hour meter of the pump (project currency); in a pivot, the machine loss (m)',
  'vfd': 'pressure kept by the variable-speed drive (m; 0 = fixed speed)',
  'vmin': 'lowest speed ratio of the drive',
  'set': 'setting of the device (m of head)',
  'setq': 'flow setting of the device (m³/s)',
  'cost': 'price (project currency)',
  'tcost': 'price per tower (project currency)',
  'acc': 'prices of the controller accessories (project currency)',
  'st': 'stations of the controller',
  'sim': 'most stations open at once (0 = as the system flows say)',
  'mir': 'symbol reflected across its vertical axis',
  'data': 'image bytes (base64)',
  'mime': 'image type',
  'src': 'file the image came from',
  'op': 'opacity (0–1)',
  'photo': 'photo of the comment (base64 JPEG)',
  // 1.6.0 CAD
  'block': 'name of the block of the project a block reference draws',
  // parameters
  'units': 'display units (length, flow, pressure, diameter)',
  'method': 'friction formula',
  'temp': 'water temperature (°C)',
  'vZone': 'largest velocity in zone pipes (m/s)',
  'vMain': 'largest velocity in mainline pipes (m/s)',
  'vLat': 'largest velocity in laterals (m/s)',
  'minorPct': 'local losses as a share of the pipe length (%)',
  'tol': 'connection tolerance (m)',
  'interest': 'interest rate (fraction a year)',
  'term': 'economic life (years)',
  'kwh': 'price of energy (project currency per kWh)',
  'eff': 'pump efficiency (0–1)',
  'hours': 'yearly operating hours of the mainline (h)',
  'zoneHours': 'yearly operating hours of a zone (h)',
  'densify': 'sampling of contour lines for the terrain (m)',
  'currency': 'symbol of the prices',
  'currencyCode': 'ISO 4217 code of every price',
  'terrain': 'terrain interpolation: tin or idw',
  'hz': 'mains frequency (Hz)',
  // catalogue
  'nominalMm': 'nominal diameter (mm)',
  'idMm': 'inner diameter (mm)',
  'wallMm': 'wall thickness (mm)',
  'ratingM': 'pressure rating (m of head)',
  'roughMm': 'absolute roughness (mm)',
  'sizeMm': 'size (mm)',
  'loss': 'head loss law h = k·Q^n + c (Q in m³/s, h in m)',
  'minQ': 'least flow (m³/s)',
  'maxQ': 'largest flow (m³/s)',
  'points': 'pump curve [[Q (m³/s), H (m)], …]',
  'kw': 'motor power (kW)',
  'curve': 'emitter law q = k·H^x (q in m³/s, H in m), radius r = ra·H^rb (m)',
  // top level
  'format': 'always "opencadirrigation"',
  'version': 'version of the file layout',
  'nextId': 'next number the app gives to a new entity id',
  'unreadable': 'items a version of the app could not read, kept as they were (by section)',
};

/// One entity of [type] with the values of a new one (for the schema).
Entity sampleEntity(EntityType type) => switch (type) {
  EntityType.line => LineEntity(id: 'e1', a: Pt.zero, b: const Pt(1, 0)),
  EntityType.polyline => PolylineEntity(id: 'e1', points: const [Pt.zero, Pt(1, 0)]),
  EntityType.circle => CircleEntity(id: 'e1', center: Pt.zero, radius: 1),
  EntityType.arc => ArcEntity(id: 'e1', center: Pt.zero, radius: 1, startRad: 0, sweepRad: math.pi),
  EntityType.spline => SplineEntity(id: 'e1', points: const [Pt.zero, Pt(1, 0)]),
  EntityType.hatch => HatchEntity(id: 'e1', points: const [Pt.zero, Pt(1, 0), Pt(1, 1)]),
  EntityType.symbol => SymbolEntity(id: 'e1', position: Pt.zero),
  EntityType.text => TextEntity(id: 'e1', position: Pt.zero, text: ''),
  EntityType.dimension => DimensionEntity(id: 'e1', a: Pt.zero, b: const Pt(1, 0)),
  EntityType.angularDimension => AngularDimensionEntity(id: 'e1', vertex: Pt.zero, a: const Pt(1, 0), b: const Pt(0, 1)),
  EntityType.radialDimension => RadialDimensionEntity(id: 'e1', center: Pt.zero, point: const Pt(1, 0)),
  EntityType.leader => LeaderEntity(id: 'e1', points: const [Pt.zero, Pt(1, 1)]),
  EntityType.image => ImageEntity(id: 'e1', origin: Pt.zero, width: 1, height: 1),
  EntityType.contour => ContourEntity(id: 'e1', points: const [Pt.zero, Pt(1, 0)], elevation: 0),
  EntityType.spotHeight => SpotHeightEntity(id: 'e1', position: Pt.zero, elevation: 0),
  EntityType.pipe => PipeEntity(id: 'e1', points: const [Pt.zero, Pt(1, 0)], scope: HydraulicScope.zone, pipeSpecId: 'pvc50'),
  EntityType.sprayline => SpraylineEntity(id: 'e1', points: const [Pt.zero, Pt(1, 0)], outletSpecId: 'micro'),
  EntityType.tape => TapeEntity(id: 'e1', points: const [Pt.zero, Pt(1, 0)], tapeSpecId: ''),
  EntityType.outlet => OutletEntity(id: 'e1', position: Pt.zero, outletSpecId: ''),
  EntityType.controlValve => ControlValveEntity(id: 'e1', position: Pt.zero),
  EntityType.waterSupply => WaterSupplyEntity(id: 'e1', position: Pt.zero),
  EntityType.pump => PumpEntity(id: 'e1', position: Pt.zero),
  EntityType.misc => MiscHydraulicEntity(id: 'e1', position: Pt.zero),
  EntityType.junction => JunctionEntity(id: 'e1', position: Pt.zero),
  EntityType.area => AreaEntity(id: 'e1', points: const [Pt.zero, Pt(1, 0), Pt(1, 1)]),
  EntityType.pivot => PivotEntity(id: 'e1', center: Pt.zero),
  EntityType.controller => ControllerEntity(id: 'e1', position: Pt.zero),
  EntityType.wire => WireEntity(id: 'e1', points: const [Pt.zero, Pt(1, 0)]),
  EntityType.ordinateDimension => OrdinateDimensionEntity(id: 'e1', point: Pt.zero, leaderEnd: const Pt(1, 1)),
  EntityType.comment => CommentEntity(id: 'e1', position: Pt.zero),
  EntityType.revisionCloud => RevisionCloudEntity(id: 'e1', points: const [Pt.zero, Pt(1, 0), Pt(1, 1)]),
  EntityType.breakline => BreaklineEntity(id: 'e1', points: const [Pt.zero, Pt(1, 0)]),
  // 1.6.0 CAD
  // the keys written only when set (rot, sc, mir, attrs) stay out, as for the other kinds
  EntityType.blockRef => BlockRefEntity(id: 'e1', position: Pt.zero, blockName: ''),
};

/// The JSON Schema (draft 2020-12) of a project file.
Map<String, dynamic> projectJsonSchema() {
  final project = Project();
  final cat = Catalog.defaultCatalog();
  return {
    r'$schema': 'https://json-schema.org/draft/2020-12/schema',
    r'$id': 'https://opencadirrigation.com/schema/oci-project.schema.json',
    'title': 'OpenCADIrrigation project (.oci.json), format version ${Project.formatVersion}',
    'description': 'Generated from the model of the app. SI units inside: lengths and elevations in m, flows in m³/s, heads in metres of water, diameters in mm where the key says so, prices in the project currency. A key left out takes the value of a new project (the defaults given); keys this version does not know are kept and written back.',
    'type': 'object',
    'required': ['format'],
    'properties': {
      ..._properties(project.toJson()..remove('entities'), skip: {'params', 'meta', 'catalog', 'layers', 'systemFlows'}),
      'format': {
        'enum': [Project.formatName, Project.legacyFormatName],
        'description': fieldNotes['format'],
      },
      'version': {'type': 'integer', 'description': fieldNotes['version'], 'default': Project.formatVersion},
      'meta': _object(project.meta.toJson()..remove('georef'), 'name, client, site and designer of the project and its identifier'),
      'params': _object(project.params.toJson(), 'design parameters', withDefaults: true),
      'layers': {'type': 'array', 'items': _object(project.layers.first.toJson(), 'a layer')},
      'systemFlows': {'type': 'array', 'items': _object(SystemFlow(id: 'f1', name: '').toJson(), 'zones that run together (valve, pivot and station ids)')},
      'catalog': {
        'type': 'object',
        'description': 'the components the entities refer to by id',
        'properties': {
          'pipes': {'type': 'array', 'items': _object(cat.pipes.first.toJson(), 'a pipe')},
          'outlets': {'type': 'array', 'items': _object(cat.outlets.first.toJson(), 'an emitter and its nozzles')},
          'tapes': {'type': 'array', 'items': _object(cat.tapes.first.toJson(), 'a drip tape or dripline')},
          'valves': {'type': 'array', 'items': _object(cat.valves.first.toJson(), 'a valve or device')},
          'pumps': {'type': 'array', 'items': _object(cat.pumps.first.toJson(), 'a pump')},
          'fittings': {'type': 'array', 'items': _object(cat.fittings.first.toJson(), 'a fitting of the bill of materials')},
          'wires': {'type': 'array', 'items': _object(cat.wires.first.toJson(), 'a conductor to the solenoids')},
          'finame': {
            'type': 'object',
            'additionalProperties': {'type': 'string'},
            'description': 'financing code by item id',
          },
        },
      },
      'entities': {
        'type': 'array',
        'items': {
          'oneOf': [for (final t in EntityType.values) _entitySchema(t)],
        },
      },
    },
  };
}

Map<String, dynamic> _entitySchema(EntityType t) {
  final o = _object(sampleEntity(t).toJson(), 'a ${t.name} entity', required: const ['type', 'id'], withDefaults: true);
  (o['properties'] as Map<String, dynamic>)['type'] = {'const': t.name, 'description': fieldNotes['type']};
  return {'title': t.name, ...o};
}

/// Keys whose value in a sample is no default (an id, a reference).
const _noDefault = {'id', 'name', 'spec', 'outlet', 'nozzle', 'text', 'uid', 'created'};

Map<String, dynamic> _object(Map<String, dynamic> sample, String description, {List<String> required = const [], bool withDefaults = false}) => {
  'type': 'object',
  if (description.isNotEmpty) 'description': description,
  if (required.isNotEmpty) 'required': required,
  'properties': _properties(sample, withDefaults: withDefaults),
};

Map<String, dynamic> _properties(Map<String, dynamic> sample, {Set<String> skip = const {}, bool withDefaults = false}) => {
  for (final e in sample.entries)
    if (!skip.contains(e.key))
      e.key: {
        ..._typeOf(e.value),
        if (fieldNotes[e.key] != null) 'description': fieldNotes[e.key],
        if (withDefaults && !_noDefault.contains(e.key) && (e.value is num || e.value is bool || e.value is String)) 'default': e.value,
      },
};

Map<String, dynamic> _typeOf(Object? v) => switch (v) {
  int _ => {'type': 'integer'},
  num _ => {'type': 'number'},
  bool _ => {'type': 'boolean'},
  String _ => {'type': 'string'},
  List l when l.isNotEmpty => {'type': 'array', 'items': _typeOf(l.first)},
  List _ => {'type': 'array'},
  Map m => {'type': 'object', 'properties': _properties(m.cast<String, dynamic>())},
  _ => const <String, dynamic>{},
};
