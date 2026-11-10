# OpenCADIrrigation engine API

*Português: [API.pt-BR.md](API.pt-BR.md)*

Everything OpenCADIrrigation calculates lives in `lib/core`: plain Dart, with no Flutter. The engine is the same everywhere: the
app runs it in a Web Worker (browser) or an isolate (desktop), the command line (`bin/oci.dart`) runs it in the Dart VM,
and you can call it from your own scripts. This page is a tour of that library: loading a project, running the design,
reading the results, the reports and exports, the hydraulic solver on its own and the newer modules (transients,
extended period simulation, air valves, layout automation, valve-in-head stations, pumps on the mains frequency,
vegetation detection, agronomy, mechanised machines, file formats, PDF plans, the native CAD drawing and the AI
assistant's clients) and the libraries 1.6.0 added (pump stations, reservoirs, the daily water balance, power and
water, technical documents, editing and files) and 1.7.0 added (the AI clients of four more companies, crop rows from
imagery, the climate risk, the irrigation forecast, the programme played on the plan, the design scorecard, curves read
off a picture and the MCP server).

Every snippet below is run, exactly as shown, by `test/core/api_examples_test.dart`, which also fails when this page shows
a line of code the tests do not run. Paths are relative to the repository root.

## Contents

1. [Using the engine](#1-using-the-engine)
2. [Projects and the design](#2-projects-and-the-design)
3. [Messages, reports and exports](#3-messages-reports-and-exports)
4. [The hydraulic solver](#4-the-hydraulic-solver)
5. [Newer modules](#5-newer-modules)
6. [Conventions](#6-conventions)

## 1. Using the engine

One import brings the whole public surface:

```dart
import 'package:opencadirrigation/core/api.dart';
```

`lib/core/api.dart` exports every library of `lib/core` except the internals of the PDF text shaping (`io/fonts/*` but
`pdf_fonts.dart`), the sparse matrix solver (`hydraulics/sparse_solver.dart`) and the tables of the East Asian code
pages (`io/codepages_cjk_data.dart`, loaded on demand by `codepages.dart`); `test/core/api_exports_test.dart` fails
when a library is missing from it. Importing the individual libraries (`core/model/project.dart`,
`core/design/designer.dart`, …) works as well and is what the app does. The engine does no input or output of its own:
readers take strings or bytes, writers return them, and the caller decides where they come from and go.

**Where to run it.** The package depends on the Flutter SDK (for the app), so `dart run` works inside this repository
(`dart run bin/oci.dart`, or a script of your own under `tool/` or `bin/`), and a Flutter project can depend on it by path
or git. For a server, a CI job or a Dart-only program, `tool/engine_package.dart` writes the engine as a package of its
own, without Flutter: `lib/core`, the command line, the two plain-Dart files of `lib/app` it reads (the string table and
the version), the language packs, the PDF fonts and the catalogue packs, under a pubspec with the engine's packages only
(archive, image, xml). It keeps the name `opencadirrigation`, so the imports stay the same, and the generator itself needs
only the Dart SDK (`test/guards/engine_package_test.dart` checks that every library the package reaches is in it):

```sh
dart tool/engine_package.dart build/engine
cd build/engine && dart pub get && dart run bin/oci.dart --help
dart compile exe bin/oci.dart -o oci   # one executable, no SDK needed to run it
```

Another Dart package then depends on it by path (`opencadirrigation: {path: ../build/engine}`).

**Translations.** The engine labels its output through a function you pass (`Translate`, `String Function(String key)`):
the designer uses it for the names it gives (supplies, pivots, the automatic system flow, some lines of the bill of
materials), and the report tables and exporters label their columns with it.
The app's string table, `lib/app/i18n.dart` (`I18n('pt')`, `I18n('en')`, …), is plain Dart too, with no Flutter, and the
design worker and the command line use it; the 17 languages beyond Portuguese, English and Spanish come from the packs in
`assets/i18n/<code>.json` (`installLanguagePack`). Without a label function the keys themselves are used.

**The command line.** `dart run bin/oci.dart --help` lists the commands: `design`, `analyze`, `check` (exit code 1 on
errors), `validate` (what reading the file had to repair, exit code 1 when anything), `export` (DXF, DWG, PDF, SVG,
KML/KMZ, GeoJSON, shapefile, GPX, LandXML, IFC, EPANET INP), `bom` and `schema` (the JSON Schema of the project file,
built from the model: every key, its type, its unit and the default of a new project), with `--lang`, `--report`,
`--results` and `--out` options. `design --out` writes the designed project with its results, as the app saves it (`--no-results` leaves them
out).

Projects are also made and changed there, without the interface: `import` makes a project of drawings, maps and surveys
(DXF, DWG, DGN, KML/KMZ, shapefiles, GeoJSON, GPX, LandXML, EPANET .inp, LAS, GeoTIFF elevations, CSV points; `--into`
adds them to a project), as File → Import does (`importFileInto` and `importDrawingInto` in `core/io/drawing_import.dart`);
`new` starts a project with `--units`, `--currency`, `--hz`, `--name` and `--georef`, makes the largest closed outline of
`--boundary` its irrigated area (the rings inside it its islands) and with `--layout` lays the sprinkler heads over it;
`set` changes the units, the currency (the prices follow at the reference rates), the mains frequency, the name or the
georeference; `pack add` adds catalogue packs (a `.oci.cat` file or the id of a bundled one, prices converted). `design`,
`analyze`, `check`, `validate`, `export` and `bom` take several projects or folders of them in one run, with `--out-dir`
for the files of each; the exit code is the worst of the run:

```sh
dart run bin/oci.dart import survey.dxf boundary.kml --out farm.oci.json
dart run bin/oci.dart new --out lawn.oci.json --boundary lawn.geojson --layout --currency USD --hz 60
dart run bin/oci.dart set farm.oci.json --units us --currency USD
dart run bin/oci.dart pack add farm.oci.json iso1452 en12201
dart run bin/oci.dart design projects/ --out-dir designed/ --report xlsx
```

## 2. Projects and the design

### Load, design, read the results, save

A project is the `.oci.json` file the app saves: `Project.fromJsonString` reads it, `toJsonString` writes it. `Designer`
builds the hydraulic model from the drawing; `designAll()` sizes the computer-sized pipes (zones, then the mainline,
telescoping where it pays) and analyses everything, exactly as F5 in the app. It changes the project in place (pipe sizes,
pipes split by telescoping) and returns the `DesignResults`.

```dart
final project = Project.fromJsonString(File('examples/en/garden.oci.json').readAsStringSync());
final results = Designer(project).designAll();
final units = project.params.units;
for (final zone in results.zones.values) {
  print('${zone.zoneName}: ${fmt(units.flowFromSi(zone.totalFlow), 0)} ${units.flowLabel}, '
      '${fmt(units.pressureFromHead(zone.requiredUpstreamHead), 1)} ${units.pressureLabel} at the valve, '
      'EU ${fmt(zone.uniformity.eu, 1)} %');
}
print('${results.bom.length} materials, ${fmt(results.capitalCost, 2)} ${project.params.currency}');
final saved = project.toJsonString(pretty: true);
```

The engine works in SI units (flow in m³/s, head in metres of water); `project.params.units` converts to the units the
user chose (`Units.metric` shows L/h and m.c.a., `Units.us` gpm and psi) and `fmt` formats a number for display.

What `DesignResults` holds:

| Field | What |
|---|---|
| `zones` | `ZoneResult` by valve id: flow, pressures (`requiredUpstreamHead`, `minOutletPressure`, `maxOutletPressure`, the allowed window), `uniformity` (CU, DU, EU), every pipe segment (`pipes`), outlet (`outlets`) and device, `warnings` |
| `systemFlows` | `SystemFlowResult` per operating shift: supply duties (`supplies`), valve pressures (`valves`, `maxDeficit`), mainline pipes and devices, energy cost |
| `pivots`, `mechanised` | centre pivots and linear moves: hydraulics, sprinkler package, timer, corner arm, variable rate, electrical |
| `bom`, `bomByZone` | bill of materials (`BomLine`: category, description, quantity, unit cost, code, supplier), also split by zone |
| `flushing`, `surge`, `electrical` | flushing of drip tapes, water hammer check of every pipe, valve wiring |
| `messages`, `unconnected` | codes of the project-wide messages and the items not connected to the network |
| `capitalCost`, `annualCapitalCost`, `annualEnergyCost` | costs in the project currency |

`results.pipesByEntity` and `results.outletsByEntity` index the pipe and outlet results by entity id.

### Damaged files and files of other versions

The reader opens a file item by item. An item it cannot read (damaged, or of a newer version of the app) is set aside in
`project.unreadable` and written back on save, under `unreadable`, so a later version gets it back; vertices without
coordinates are dropped, an elevation that is not known is never taken as 0 m, repeated or missing entity ids get new ones,
options it does not know take their default and fields it does not know are kept. `readProjectFile` returns the project,
the results the file keeps beside it and a `ProjectReadReport` of the repairs (`notes`: codes translated by the app as
`read.<code>`). The format carries a `version` (`Project.formatVersion`, 2); older files are upgraded by
`Project.migrations`, and a key missing from a file takes the value of a new project.

```dart
final file = readProjectFile(File('examples/en/garden.oci.json').readAsStringSync());
final report = file.report;
for (final note in report.notes) {
  print('${note.code} ${note.args}');
}
print('${file.project.entities.length} entities, ${report.skippedCount} set aside, clean: ${report.clean}');
```

### Analysis only, progress, results as JSON

`analyzeAll()` analyses the drawing as it is, without sizing anything. `designAllAsync` runs the same steps as
`designAll` and yields between them, reporting the stage (zones, mainline, splits, flushing, surge, bill of materials):
this is how the app shows its progress card. Results travel as JSON (`toJson` / `fromJson`), which is how the design
worker hands them to the interface.

```dart
final analysis = Designer(project).analyzeAll();
final designer = Designer(project);
final results = await designer.designAllAsync(onProgress: (p) => print('${p.stage.name} ${p.done}/${p.total}'));
final json = jsonEncode(results.toJson());
final again = DesignResults.fromJson(jsonDecode(json) as Map<String, dynamic>);
```

### A project built in code

Entities are plain objects added to `project.entities`; `project.newId()` hands out ids. The block generator lays out
laterals, submain and zone valve over a polygon; a mainline pipe and a water supply complete the network. Pipes without a
size (`pipeSpecId` null) are sized by the designer.

```dart
final project = Project();
final block = generateBlock(project, BlockOptions(
  polygon: const [Pt(0, 0), Pt(120, 0), Pt(120, 45), Pt(0, 45)],
  direction: const Pt(1, 0),
  lateralSpacing: 4,
  outletSpecId: 'micro',
  nozzleId: 'm50',
  outletSpacing: 3.5,
  headM: 15,
  valveSpecId: 'ev80',
  zoneName: 'Block 1',
));
project.entities.addAll(block.all);
final valve = block.valve!;
final well = valve.position + const Pt(-40, 0);
project.entities.add(PipeEntity(id: project.newId(), points: [well, valve.position], scope: HydraulicScope.mainline));
project.entities.add(WaterSupplyEntity(id: project.newId(), position: well, name: 'Well', calculatePressure: true));
final results = Designer(project).designAll();
final zone = results.zones[valve.id]!;
```

The main entity types: drawing (`LineEntity`, `PolylineEntity`, `CircleEntity`, `ArcEntity`, `SplineEntity`,
`TextEntity`, dimensions, `HatchEntity`), terrain (`ContourEntity`, `SpotHeightEntity`, `BreaklineEntity`), hydraulics
(`WaterSupplyEntity`, `PumpEntity`, `PipeEntity` with a `scope` of zone or mainline, `ControlValveEntity`,
`SpraylineEntity` and `TapeEntity` for laterals, `OutletEntity`, `MiscHydraulicEntity` for filters, meters and other
devices, `JunctionEntity`), areas (`AreaEntity`, with crop data), machines (`PivotEntity`) and wiring (`ControllerEntity`,
`WireEntity`).

### The catalogue

`Catalog.defaultCatalog()` is the built-in catalogue (pipes, outlets with their nozzles, drip tapes, valves, pumps,
fittings, wires); every project carries its own copy in `project.catalog`, and entities refer to it by id. Manufacturer
packs (`catalogs/*.oci.cat`) are read with `CatalogIo.parsePack` (`lib/core/io/catalog_io.dart`).

```dart
final catalog = Catalog.defaultCatalog();
final pipe = catalog.pipe('pvc50')!;
print('${pipe.name}: inner ${pipe.innerDiameterMm} mm, rated ${pipe.pressureRatingM} m, ${pipe.costPerM}/m');
final rotor = catalog.outlet('rotor')!;
for (final nozzle in rotor.nozzles.take(3)) {
  print('${nozzle.id}: ${fmt(nozzle.curve.flow(30) * 3600, 2)} m³/h at 30 m');
}
```

`catalogPlausibility` (`lib/core/model/catalog_check.dart`) catches values misread from a data sheet: a thermoplastic pipe
wall too thin for its pressure class (the hoop stress against the material's design stress), a nozzle passing more than an
ideal orifice of its bore, a pump curve asking more than its motor gives at its service factor. The default catalogue and
every pack pass it.

```dart
final problems = catalogPlausibility(Catalog.defaultCatalog());
print(problems.isEmpty ? 'plausible' : problems.join('\n'));
```

## 3. Messages, reports and exports

### Design check and the design assistant

`runDesignCheck` sweeps the drawing for what makes a design fail before it runs (disconnected items, dead ends, pipes
crossing without a junction, zones without emitters, missing catalogue data…). `buildAdvice` merges it with the settings
check and, when given, the messages of the results, and gives each problem its explanation code (`adv.<code>.why`,
`adv.<code>.how` in the string table) and the corrections that apply (`fixes`, applied by `applyFix` in
`design/auto_fix.dart`).

```dart
final check = runDesignCheck(project);
for (final issue in check.issues) {
  print('${issue.severity.name} ${issue.code} ${issue.entityIds.join(',')}');
}
final advice = buildAdvice(project);
final t = I18n('pt');
for (final a in advice.where((a) => a.level == AdviceLevel.error)) {
  print('${t('check.${a.raw}')} → ${t('adv.${a.code}.how')}');
}
```

The warnings in the results are codes such as `velocity_exceeded:e12` (message key `warn.velocity_exceeded`, then the ids
of the items); `I18n.warning` turns one into text.

### Report tables and exports

`ProjectExporter` is the app's export code: report tables (`reportTables()`, the same tables as the Reports panel) and
every drawing and report format. Text formats come back as `String`, binary ones as `Uint8List`.

```dart
final t = I18n('en');
final exporter = ProjectExporter(
  project: project,
  results: results,
  labels: ReportLabels(t: t.call, has: t.has, warning: t.warning),
);
final tables = exporter.reportTables();
final csv = reportTablesToCsv(tables);
final dxf = exporter.exportDrawing(DrawingFormat.dxf) as String;
final dwg = exporter.exportDrawing(DrawingFormat.dwg) as Uint8List;
final inp = exporter.exportDrawing(DrawingFormat.inp) as String;
final xlsx = exporter.exportReport(ReportFormat.xlsx) as Uint8List;
final pdf = exporter.exportDrawing(DrawingFormat.pdf, sheet: const SheetOptions(page: PageSize.a1)) as Uint8List;
project.meta.georef = GeoReference.fromLatLonOrigin(-22.9068, -43.1729);
final kml = exporter.exportDrawing(DrawingFormat.kml) as String;
```

- `DrawingFormat`: `dxf`, `dwg` (DWG R2000), `pdf` (plotted sheet), `svg`, `kml`, `kmz`, `geojson`, `shp` (zipped
  shapefiles), `gpx`, `landxml`, `ifc` (IFC4) and `inp` (EPANET). KML, KMZ, GeoJSON and GPX need a georeference
  (`project.meta.georef`; `GeoReference.fromLatLonOrigin` places the drawing origin at a WGS84 position) and throw
  `GeoReferenceMissing` without one.
- `ReportFormat`: `csv` (semicolon separated), `txt`, `xlsx` and `pdf`. `reportTablesToCsv` and `reportTablesToText`
  format any list of tables; a table has a stable `key` (`zones`, `pipes`, `outlets`, `mainline`, `bom`, `messages`…).
- PDF text beyond Latin-1 (Arabic, Indic scripts, Chinese, Japanese) needs the bundled Noto fonts registered in
  `PdfFonts.shared` (`BundledFonts.all` names the files of `assets/fonts`); `bin/oci.dart` shows how.

## 4. The hydraulic solver

`HydraulicNetwork` is the steady-state solver behind every analysis: the Global Gradient Algorithm (Todini and Pilati,
1988, the method of EPANET) with pressure-dependent emitters, pumps, pressure reducing and sustaining valves, flow control
valves and check valves. Nodes (`HNode`) are junctions or fixed-head reservoirs; links (`HLink`) are pipes, pumps, valves
or devices with a loss curve. Units are SI: flow m³/s, head and elevation m, diameter m.

### A pipe network with emitters

```dart
final net = HydraulicNetwork();
net.addNode(HNode(id: 'tank', kind: HNodeKind.reservoir, fixedHead: 30));
net.addNode(HNode(id: 'J1', elevation: 2));
net.addNode(HNode(id: 'J2', elevation: 3, emitter: EmitterCurve.fromNominal(flow: 1.0 / 3600, head: 15), emitterCount: 10));
net.addLink(HLink(id: 'P1', from: 'tank', to: 'J1', diameter: 0.05, length: 120, hazenC: 150));
net.addLink(HLink(id: 'P2', from: 'J1', to: 'J2', diameter: 0.032, length: 40, hazenC: 150));
final result = net.solve();
final j2 = result.nodes['J2']!;
print('converged ${result.converged} in ${result.iterations} iterations');
print('J2: ${fmt(j2.pressure, 2)} m, ten sprinklers give ${fmt(j2.emitterFlow * 3600, 2)} m³/h');
```

`solve()` returns a `NetworkResult`: `nodes` (`NodeResult`: `head`, `pressure`, `demand`, `emitterFlow`), `links`
(`LinkResult`: `flow`, `velocity`, `headLoss`, `status`, `pumpHead`), `converged`, `iterations` and `warnings`. An emitter
node discharges `emitterCount` times q = k·Hˣ at its pressure (plus `emitterOffset`, the riser); `demand` is a fixed
outflow (negative for an inflow).

### Pumps, pressure reducing valves and check valves

```dart
final net = HydraulicNetwork(options: const NetworkOptions(method: FrictionMethod.darcyWeisbach));
net.addNode(HNode(id: 'well', kind: HNodeKind.reservoir, fixedHead: -20));
net.addNode(HNode(id: 'out'));
net.addNode(HNode(id: 'reg'));
net.addNode(HNode(id: 'field', elevation: 5, demand: 0.008));
net.addLink(HLink(id: 'pump', from: 'well', to: 'out', kind: HLinkKind.pump, pump: PumpCurve.fit([(0, 70), (0.01, 62), (0.02, 40)])));
net.addLink(HLink(id: 'main', from: 'out', to: 'reg', diameter: 0.1, length: 300, roughness: 1.5e-6, checkValve: true));
net.addLink(HLink(id: 'prv', from: 'reg', to: 'field', kind: HLinkKind.prv, prvSetting: 25, diameter: 0.1));
final result = net.solve();
final pump = result.links['pump']!;
```

`NetworkOptions` chooses the friction law (`FrictionMethod.hazenWilliams`, `darcyWeisbach`, `scobey`, `manning`), the
water viscosity and the convergence tolerances; each link carries its own coefficient (`hazenC`, `roughness` in m,
`scobeyKs`, `manningN`) and minor loss (`minorK`). Link kinds: `pipe`, `pump` (`PumpCurve`, H = a·Q² + b·Q + c, with a
speed ratio), `prv` and `psv` (`prvSetting`, m), `fcv` (`fcvFlow`, m³/s), `device` (`DeviceLossCurve`, h = K·Qⁿ + C) and
`closed`.

### Friction, emitters and pump curves

The formulas are available on their own:

```dart
final hf = hazenWilliamsLoss(flow: 0.003, diameter: 0.06, length: 80, c: 140);
final dw = darcyWeisbachLoss(flow: 0.003, diameter: 0.06, length: 80, roughness: 1.5e-6);
final dripper = EmitterCurve.fromNominal(flow: 2 / 3.6e6, head: 10, x: 0.5);
final pump = PumpCurve.fit([(0, 50), (0.01, 45), (0.02, 30)]);
final duty = operatingPoint(pump, const SystemCurve(staticHead: 20, k: 30000));
```

Also in `lib/core/hydraulics`: `lateral.dart` (step-by-step lateral analysis), `minor_losses.dart`, `uniformity.dart`
(CU, DU, EU) and `water_hammer.dart` (wave celerity, Joukowsky surge, critical closure time).

## 5. Newer modules

### Water hammer (method of characteristics)

`TransientModel` takes a solved network and simulates events on it (valve closures and openings, pump trips, demand
stops) by the method of characteristics, with column separation, air valves and surge vessels. The result gives head
envelopes for every node and pipe and time series for the probes asked for.

```dart
final net = HydraulicNetwork();
net.addNode(HNode(id: 'R', kind: HNodeKind.reservoir, fixedHead: 100));
net.addNode(HNode(id: 'N'));
net.addNode(HNode(id: 'O', kind: HNodeKind.reservoir, fixedHead: 0));
net.addLink(HLink(id: 'P', from: 'R', to: 'N', diameter: 0.5, length: 1000, hazenC: 1e7));
net.addLink(HLink(id: 'V', from: 'N', to: 'O', kind: HLinkKind.device, device: const DeviceLossCurve(k: 100 / (0.196 * 0.196))));
final steady = net.solve();
final model = TransientModel.fromNetwork(net, steady, linkData: const {'P': TransientLinkData(celerity: 1000)});
final run = model.simulate(events: [TransientEvent.valveClosure('V', closureTime: 0)], options: const TransientOptions(duration: 12, probes: [TransientProbe.node('N')]));
final n = run.nodes['N']!;
```

Pressures in the results are gauge heads (m); `TransientOptions.vapourHead` and `barometricHead` are absolute. Pipe
celerities come from `TransientLinkData.fromPipe` (diameter, wall thickness, material) or are given directly.

### Transients, a 24-hour simulation and air valves on a project

`design/transient_analysis.dart` builds those runs from a project: `TransientStudy` (valve closure, pump trip, closure of
an isolation valve, per system flow), `simulateDay` (the operating day of the system flows as an extended period
simulation, with energy and cost) and `suggestMainlineAirValves` (air valves along the mainline, AWWA M51 practice,
optionally using the transient minimum pressures).

```dart
final project = Project.fromJsonString(File('examples/en/orchard.oci.json').readAsStringSync());
final results = Designer(project).designAll();
final transient = TransientStudy(project, results: results, options: const TransientStudyOptions(scenarios: {TransientScenario.valveClosure, TransientScenario.pumpTrip})).analyze();
for (final run in transient.runs.where((r) => r.ran)) {
  print('${run.flowName} ${run.scenario.name}: surge ${fmt(run.maxSurge, 1)} m, '
      '${fmt(run.minPressure, 1)}…${fmt(run.maxPressure, 1)} m');
}
final day = simulateDay(project, results: results);
print('a day: ${fmt(day.energyKwh, 1)} kWh, ${fmt(day.volume, 1)} m³');
final air = suggestMainlineAirValves(project, results: results, transient: transient);
```

### Extended period simulation

`simulateEps` steps a network through time (EPANET's scheme): tanks, link schedules, controls on tank levels or the clock,
demand patterns, pump energy and tariffs. It works on a copy of the network.

```dart
final net = HydraulicNetwork();
net.addNode(HNode(id: 'J', demand: -0.01));
net.addNode(HNode(id: 'T', elevation: 5));
net.addLink(HLink(id: 'P', from: 'J', to: 'T', diameter: 0.15, length: 50, hazenC: 130));
final eps = simulateEps(net, tanks: const [EpsTank(nodeId: 'T', initialLevel: 1, maxLevel: 6, area: 50)], options: const EpsOptions(duration: 5 * 3600));
for (var i = 0; i < eps.times.length; i++) {
  print('${eps.times[i] ~/ 3600} h: ${fmt(eps.tankLevels['T']![i], 2)} m');
}
```

### Air valves along a profile

```dart
final plan = suggestAirValves(PipelineProfile(points: const [
  ProfilePoint(chainage: 0, pipe: 0),
  ProfilePoint(chainage: 1000, pipe: 20),
  ProfilePoint(chainage: 2000, pipe: 0),
], diameter: 0.3, designFlow: 0.05));
for (final s in plan.suggestions) {
  print('${fmt(s.chainage, 0)} m: ${s.type.name} (${s.reason.name}), ${fmt(s.sizing.nominalSize * 1000, 0)} mm');
}
```

### Layout automation

Heads over a lawn (`layoutLandscape`, with corner, edge and part-circle heads and the resulting uniformity), zones by
flow (`zoneByFlow`), valves and pipe routes (`routeZones`), then entities of a project, ready to design:

```dart
final project = Project(catalog: Catalog.defaultCatalog());
final rotor = project.catalog.outlet('rotor')!;
const lawn = [Pt(0, 0), Pt(40, 0), Pt(40, 30), Pt(0, 30)];
const house = [Pt(12, 10), Pt(26, 10), Pt(26, 20), Pt(12, 20)];
final layout = layoutLandscape(outline: lawn, exclusions: [house], family: rotor);
final zoning = zoneByFlow(zoneItemsOf(layout, rotor), ZoningOptions(maxZoneFlow: 3 / 3600));
const tap = Pt(-8, -6);
final routing = routeZones([for (final z in zoning.zones) [for (final i in z.items) layout.heads[i].position]], RouteOptions(pointOfConnection: tap, exclusions: [house], direction: layout.direction));
final names = [for (var z = 0; z < zoning.zones.length; z++) 'Zone ${z + 1}'];
project.entities.addAll(layout.toOutlets(project, zoneName: (i) => names[zoning.zoneOf[i]]));
project.entities.addAll(routing.toEntities(project, zoneNames: names, valveSpecIds: [for (final z in zoning.zones) pickZoneValve(project.catalog, z.flow)?.id]));
project.entities.addAll([for (final m in routing.mainline) PipeEntity(id: project.newId(), points: m.points, scope: HydraulicScope.mainline)]);
project.entities.add(WaterSupplyEntity(id: project.newId(), position: tap, calculatePressure: false, designHeadM: 45, maxHeadM: 50));
final results = Designer(project).designAll();
```

For sports fields and golf, `templates.dart` has `sportsPitchLayout`, `golfGreenLayout`, `fairwayLayout`, `teeLayout` and
`runningTrackInfieldLayout`. For farms, `subdivideField` cuts a field into blocks that `blockOptionsFor` turns into block
generator options, and `fitFullCirclePivot` / `fitSectorPivot` place the largest pivot a field holds:

```dart
const field = [Pt(0, 0), Pt(420, 0), Pt(420, 180), Pt(250, 260), Pt(0, 260)];
final blocks = subdivideField(field, FieldSubdivisionOptions(direction: const Pt(1, 0), maxBlockArea: 2e4, roadWidth: 4));
final project = Project();
for (final b in blocks.blocks) {
  project.entities.addAll(generateBlock(project, blockOptionsFor(b, blocks.direction, lateralSpacing: 1.8, isTape: true, tapeSpecId: 'tape16_10_30', valveSpecId: 'ev80')).all);
}
final pivot = fitFullCirclePivot(const [Pt(0, 0), Pt(900, 0), Pt(900, 650), Pt(0, 650)], PivotFitOptions(endThrowM: 15));
project.entities.add(pivot.toPivotEntity(project, name: 'Pivot 1'));
```

### Valve-in-head stations

A sprinkler drawn on the mainline (an `OutletEntity` with `scope: HydraulicScope.mainline`) has its valve in the head.
`VihStations.of(project)` groups the heads into stations (`design/valve_in_head.dart`): a head without a zone name is a
station of its own, whose id is the head's, and heads sharing a zone name are the station `vih:<name>`, their solenoids in
parallel on one controller station. A system flow schedules a station by listing its id in `valveIds`, beside the zone
valves and pivots: a scheduled station runs only in the flows that list it, and the design gives its heads their nominal
pressure there, as it gives a zone valve the pressure its zone needs. A station no flow lists runs in every flow and has
no say on the supply pressure, which is how mainline outlets behaved before they could be scheduled.

```dart
final project = Project();
project.entities.add(WaterSupplyEntity(id: 'well', position: Pt.zero, calculatePressure: true));
project.entities.add(PipeEntity(id: 'main', points: const [Pt.zero, Pt(100, 0)], scope: HydraulicScope.mainline));
for (var i = 0; i < 6; i++) {
  project.entities.add(OutletEntity(id: 'h${i + 1}', position: Pt(15.0 * (i + 1), 0), scope: HydraulicScope.mainline, outletSpecId: 'impact34', nozzleId: 'i4.0', headM: 30, zoneName: i < 3 ? 'Green' : 'Tee'));
}
project.systemFlows.add(SystemFlow(id: 'f1', name: 'Morning', valveIds: {'vih:Green'}, startHour: 6, durationHours: 1));
project.systemFlows.add(SystemFlow(id: 'f2', name: 'Evening', valveIds: {'vih:Tee'}, startHour: 19, durationHours: 1));
final stations = VihStations.of(project);
print(stations.heads.map((id, heads) => MapEntry(id, heads.join(' '))));
final results = Designer(project).designAll();
for (final flow in results.systemFlows) {
  for (final s in flow.heads) {
    print('${flow.name}: ${s.name}, ${s.heads} heads, ${fmt(s.flow * 3600, 2)} m³/h, '
        '${fmt(s.minPressure, 1)}–${fmt(s.maxPressure, 1)} m at the nozzles (needs ${fmt(s.requiredHead, 1)} m)');
  }
}
```

`SystemFlowResult.heads` holds a `VihDuty` for every station running in the flow: heads, flow, the lowest and highest
nozzle pressure, the critical head and what it needs at its mainline node (nominal pressure plus riser, 31 m here) against
what it gets (`deficit`). The stations also go through the valve wiring and the two-wire design (one station each, the
heads' solenoids in parallel), the 24-hour simulation, the transients (their heads close with the zone valves of the
flow), the energy grouping, the controller programme, fertigation and the EPANET export of each flow.

### Mains frequency and variable-speed pumps

A catalogue pump may state the mains frequency its curve was measured at (`PumpSpec.ratedHz`, `hz` in the packs), and
`DesignParameters.mainsHz` (50 or 60) is the frequency of the site. A fixed-speed motor then turns at `mainsHz / ratedHz`
of the speed of the curve, which the affinity laws scale (H(Q) = ω²·H₀(Q/ω)): a 60 Hz curve on 50 Hz mains runs at 5/6 of
the speed and gives 69 % of the head. A pump with a target outlet pressure (`PumpEntity.targetPressureM`, between
`minSpeedRatio` and its `speedRatio`) has a variable-speed drive: the designer sets its speed in every system flow, and
the mains frequency does not slow it. `rankPumps` reads every curve at the speed of the mains, and
`TransientStudyOptions.speedForPoles` gives the running speed of the motor for the pump trip (synchronous speed less
about 3 % slip).

```dart
final project = Project.fromJsonString(File('examples/en/orchard.oci.json').readAsStringSync());
final pump = project.entities.whereType<PumpEntity>().first;
project.catalog.pump(pump.pumpSpecId)!.ratedHz = 60;
project.params.mainsHz = 50;
final fixed = Designer(project).designAll();
double speedOf(DesignResults r) => r.systemFlows.first.devices.firstWhere((d) => d.entityId == pump.id).speedRatio;
print('a 60 Hz curve on 50 Hz mains: ${fmt(speedOf(fixed), 3)} of the speed, ${fmt(speedOf(fixed) * speedOf(fixed), 3)} of the head');
pump.targetPressureM = 30;
final drive = Designer(project).designAll();
print('with a drive holding 30 m at the outlet: ${fmt(speedOf(drive), 3)} of the speed');
final duties = rankPumps(project.catalog, flow: 18 * m3sPerM3h, head: 32, staticHead: 20, hoursPerYear: 2000, costPerKwh: 0.75, mainsHz: 50);
print('${duties.length} pump choices; a 2-pole motor turns at ${fmt(TransientStudyOptions.speedForPoles(2, 50), 0)} rpm on 50 Hz');
```

A pump may also carry an efficiency curve (`efficiencyPoints`) and an NPSH required curve (`npshPoints`):
`efficiencyAt(q, speed:)` reads the efficiency at the homologous flow q/ω, `npshrAt(q, speed:)` scales the NPSH required
by ω², and the design compares it with `npshAvailable` (`pump_npsh` when the margin of 0.6 m is not there).

### Vegetation from aerial imagery

`design/vegetation.dart` finds lawns, trees and shrubs in an aerial picture on the device, with no service: a
`VegetationImage` holds the working raster of an image placed by its four world corners (bottom-left, bottom-right,
top-right, top-left) with the excess-green index of every pixel and Otsu's threshold, `detectVegetation` returns the
patches with their holes and `vegetationEntities` turns them into irrigated areas (with agronomic starting values per
class) and exclusion outlines. `VegetationImage.fromEncoded` decodes a PNG or JPEG instead of raw pixels. Here a synthetic
40 × 30 m view at 10 cm per pixel: a lawn on paving with a round patio in it.

```dart
const w = 400, h = 300;
final rgba = Uint8List(4 * w * h);
for (var y = 0; y < h; y++) {
  for (var x = 0; x < w; x++) {
    final lawn = x >= 60 && x < 340 && y >= 50 && y < 250 && (x - 200) * (x - 200) + (y - 150) * (y - 150) > 30 * 30;
    rgba.setAll(4 * (y * w + x), lawn ? const [72, 128, 46, 255] : const [148, 142, 136, 255]);
  }
}
final image = VegetationImage.fromPixels(rgba, w, h, const [Pt(0, 0), Pt(40, 0), Pt(40, 30), Pt(0, 30)]);
final found = detectVegetation(image, VegetationOptions());
for (final patch in found.patches) {
  print('${patch.cls.name}: ${fmt(patch.grossArea, 1)} m² inside, ${fmt(patch.area, 1)} m² net, ${patch.holes.length} hole');
}
final project = Project();
project.entities.addAll(vegetationEntities(project, found.patches, name: (c) => c == VegetationClass.turf ? 'Lawn' : 'Planting', exclusionName: (area, n) => '$area, exclusion $n'));
```

`VegetationOptions` holds the user's settings (threshold offset, the turf/trees split and its bias, minimum areas of
patches and holes, simplification tolerance, clean-up radii); one `VegetationImage` serves any number of runs. The
result also carries notes (`messages`: few vegetated pixels, low contrast, patches cut by the edge of the view) and the
class of every working pixel for a preview (`vegetationPreview`).

### Agronomy

Reference evapotranspiration by FAO-56 Penman-Monteith (`fao56Eto`, with the FAO-56 estimates for missing data, and
`fao56MonthlySeries`) or Hargreaves, crop coefficients (`KcCurve`, the FAO-56 crop table `fao56Crops`), soils (`soilOf`,
USDA textures), the irrigation requirement month by month (`irrigationRequirement`: effective rain, localised irrigation,
leaching, intervals, volumes and the peak flow), landscape water budgets (`mweloWaterBudget`), cycle and soak, the wetted
bulb of drippers, solar pumping (`sizeSolarPumping`) and fertigation (`fertigationTravel`, `planFertigation`).

```dart
final eto = fao56Eto(const Fao56Input(latitudeDeg: 45.72, elevationM: 200, dayOfYear: 196, tMaxC: 26.6, tMinC: 14.8));
const bean = KcCurve(kcIni: 0.15, kcMid: 1.19, kcEnd: 0.35, stages: CropStages(25, 25, 30, 20));
final loam = soilOf(SoilTexture.loam);
final table = irrigationRequirement(RequirementInput(
  areaId: 'field',
  areaM2: 10000,
  cycles: [CropCycle.fromTable('crop.citrus', planting: DateTime.utc(2001))],
  climate: ClimateNormals(etoMmDay: List.filled(12, 5.0), rainMm: List.filled(12, 30.0)),
  awcMmPerM: loam.awcMmPerM,
));
final soak = cycleAndSoakForSoil(precipitationRateMmH: 38, depthMm: 12.7, texture: SoilTexture.clayLoam, slopePct: 5);
final bulb = schwartzmanZurBulb(flowLph: 4, volumeL: 8, ksatMmH: 13.2);
```

### Mechanised machines

`analyzeMechanised` designs the sprinkler package of a centre pivot or linear move (nozzle by nozzle, with regulators,
drops, end gun and booster), its timer chart and, when the machine is set up for them (`PivotMachine`), the corner arm, the
variable-rate prescription and the electrical supply; the designer runs it for every pivot of a project. The parts are
also available alone (`designPivotPackage`, `analyzeCornerArm`, `vriFromZones`, `vriFromSectors`,
`designPivotElectrical`), and so are travelling guns (`analyzeTraveller`).

```dart
final project = Project();
final pivot = PivotEntity(id: project.newId(), center: const Pt(0, 0), radiusM: 400, name: 'Pivot 1', machine: PivotMachine(towerSpeedMPerMin: 3));
project.entities.add(pivot);
final machine = analyzeMechanised(project, pivot);
final package = machine.package;
final gun = analyzeTraveller(const TravellerSpec(gunFlow: 30 / 3600, gunPressureM: 45, wettedDiameterM: 90, hoseLengthM: 350, hoseInnerMm: 90, speedMPerMin: 0.5));
```

### File formats

Readers turn files into a `DxfDocument` (layers and plain entities, in local metres) or a result object around one, often
with a georeference; writers turn a project (or a `DxfDocument`) into text or bytes.

```dart
final doc = DxfDocument(layers: [DxfLayer('PIPES', color: 5)], entities: [
  DxfEntity(type: 'LINE', layer: 'PIPES', points: [const Pt(0, 0), const Pt(10, 5)]),
  DxfEntity(type: 'CIRCLE', layer: 'PIPES', center: const Pt(3, 3), radius: 2),
]);
final dxf = DxfWriter.write(doc);
final dwg = DwgWriter.write(doc);
final points = PointsCsvReader.parse('lat,lon,alt\n-22.9,-47.06,600\n-22.9001,-47.0601,601\n');
final geojson = GeoJsonReader.parse(jsonEncode({'type': 'Point', 'coordinates': [-47.93, -15.78, 1000.5]}));
final crs = parseCrs('EPSG:31983');
```

| Format | Read | Write |
|---|---|---|
| DXF | `DxfReader.parse(String)` | `DxfR2000Writer.write(CadDrawing)` (DXF R2000), `DxfWriter.write(DxfDocument)` (R12) |
| DWG (R13 to 2018 / 2000) | `DwgReader.parse(Uint8List)` | `DwgWriter.writeDrawing(CadDrawing)`, `DwgWriter.write(DxfDocument)` |
| PDF | `PdfReader.open(Uint8List)` → `readPage`, `pdfPageEntities` / `addPdfPage` | sheets through `ProjectExporter` |
| DGN V7 | `DgnReader.parse(Uint8List)` | |
| KML / KMZ | `KmlReader.parse`, `KmlReader.parseKmz` | through `ProjectExporter` |
| GeoJSON | `GeoJsonReader.parse(String)` | through `ProjectExporter` |
| Shapefile | `ShpReader.parse` (.shp + .dbf + .prj), `ShpReader.parseAny` (zip) | `ShapefileWriter(project: …).zip()` |
| GPX | `GpxReader.parse(String)` | `GpxWriter.write(project)` |
| LandXML | `LandXmlReader.parse(String)` | `LandXmlWriter.write(project)` |
| IFC4 | | `IfcWriter.write(project)` |
| EPANET INP | `EpanetInpReader.parse(String)` → `toNetwork()`, `toDocument()` | `EpanetWriter.write(project)` |
| LAS point clouds | `LasReader.read(Uint8List)` | |
| GeoTIFF elevation | `GeoTiffDemReader.read(Uint8List)` | |
| Survey points CSV / XYZ | `PointsCsvReader.parse(String)` | |
| Coordinate systems | `parseCrs` (WKT, `EPSG:n`), `crsFromEpsg`, `GeoPlacement.plan`, datum shifts (`datumToWgs84`) | |

### PDF plans as an underlay

`PdfReader.open` reads a PDF (classic and stream cross-references, object streams, incremental updates; a damaged table
is rebuilt, an encrypted file refused with `pdf_encrypted`) and `readPage` interprets one page into paths, texts and
images in page points (1/72 inch, origin at the bottom-left of the crop box, the page rotation applied), with the PDF
layers they belong to. `pdfScaleOnSheet` looks for a scale written on the sheet (`Scale 1:500`, `ESCALA 1:200`, a lone
`1:250`); `pdfPageEntities` and `addPdfPage` place the page in the drawing at a paper scale
(`PdfImportOptions.atScale`), or at a factor for a plan whose units are metres (`metresPerUnit`), on layers of their own.
The two-point align and the georeference tools then fit the plan to known points. Here the PDF is a sheet the exporter
wrote; its title block keeps the scale apart from its label, so the scale is given.

```dart
final source = Project.fromJsonString(File('examples/en/garden.oci.json').readAsStringSync());
final t = I18n('en');
final sheet = ProjectExporter(project: source, results: Designer(source).designAll(), labels: ReportLabels(t: t.call, has: t.has, warning: t.warning)).exportDrawing(DrawingFormat.pdf) as Uint8List;
final pdf = PdfReader.open(sheet);
final page = pdf.readPage(0);
final scale = pdfScaleOnSheet(page) ?? 250;
print('page 1 of ${pdf.pageCount}: ${fmt(page.page.widthMm, 0)} × ${fmt(page.page.heightMm, 0)} mm, '
    '${page.paths.length} paths, ${page.texts.length} texts, ${page.images.length} images');
final project = Project();
final plan = addPdfPage(project, page, PdfImportOptions(metresPerUnit: PdfImportOptions.atScale(scale.toDouble()), layer: pdfLayerName('garden.pdf')));
print('imported: ${plan.lines + plan.polylines} lines and polylines, ${plan.texts} texts, layers ${plan.layers.map((l) => l.name).join(', ')}');
```

`readPage` takes `vectors`, `texts` and `images` to read only part of a page (decoding the images of a scan takes the
longest) and stops at `pdfMaxSegments` path segments (`pdf_truncated`). `PdfImportOptions` also chooses the layers (one per
PDF layer, optionally one per colour) and whether the PDF layers that are off come in.

### Native CAD drawing (DXF 2000 and DWG)

The DXF and DWG exports share one native drawing, `CadDrawing` (`io/cad_drawing.dart`): layers with colour index, true
colour and linetype, dimension styles, block definitions with attribute definitions, and the entities CAD programs edit as
such (lightweight polylines with arcs, splines, hatches, multiline text, dimensions with their anonymous blocks, leaders,
block references with attributes). `CadExport(project).build()` makes it from a project (it is the exporter's
`cadDrawing()`), `DxfR2000Writer.write` writes it as a DXF R2000 (AC1015) and `DwgWriter.writeDrawing` as a DWG
R2000, which the CAD programs that read DXF/DWG R2000 open. Symbols and hydraulic items are references to small blocks
whose attributes carry the name, the catalogue item, the nozzle, the zone and the stations, and every pipe, lateral,
tape and hydraulic item carries its hydraulic data as extended data (`io/cad_xdata.dart`), which the app's import reads
back into a network. `DrawingFormat.dxfR12` keeps the R12 primitives for older programs.

```dart
final project = Project.fromJsonString(File('examples/en/garden.oci.json').readAsStringSync());
final results = Designer(project).designAll();
final drawing = CadExport(project, units: project.params.units).build();
print('${drawing.layers.length} layers, ${drawing.blocks.length} blocks, ${drawing.entities.length} entities');
for (final insert in drawing.entities.whereType<CadInsert>().where((i) => i.attribs.isNotEmpty).take(2)) {
  print('${insert.block}: ${[for (final a in insert.attribs) '${a.tag}=${a.value}'].join(', ')}');
}
final dxf = DxfR2000Writer.write(drawing);
final dwg = DwgWriter.writeDrawing(drawing);
final t = I18n('en');
final r12 = ProjectExporter(project: project, results: results, labels: ReportLabels(t: t.call, has: t.has, warning: t.warning)).exportDrawing(DrawingFormat.dxfR12) as Uint8List;
```

### The AI assistant's clients and agent loop

`ai/llm.dart` holds what the assistant needs from any model provider: the models offered (`AiModel`, with their provider,
tier and list prices), tokens and their estimated cost (`AiUsage`), errors (`AiError`), cancellation (`AiCancel`) and the
HTTP exchange as a function (`AiTransport`: the app plugs in fetch in the browser and `HttpClient` on the desktop,
`lib/app/ai/ai_transport_*.dart`). Six clients implement `AiClient`: `AnthropicClient` (`ai/claude_api.dart`, the
Anthropic Messages API), `OpenAiClient` (`ai/openai_api.dart`, the OpenAI Responses API), `XaiClient`, `MetaClient` and
`OpenRouterClient` (`ai/xai_api.dart`, `ai/meta_api.dart`, `ai/openrouter_api.dart`: the Responses APIs of xAI, Meta and
OpenRouter, built on `OpenAiClient` through its hooks) and `GeminiClient` (`ai/gemini_api.dart`, Google's Interactions
API, with its own translation `GeminiFormat`); `ai/llm_formats.dart` holds the Messages and Responses wire formats in one
place, and `ai/openrouter_catalog.dart` reads OpenRouter's public list of models into `AiModel`s. `apiKey` is the user's
own key for that provider, which goes in its header to that provider's API (`AiProvider.host`: `api.anthropic.com`,
`api.openai.com`, `generativelanguage.googleapis.com`, `api.x.ai`, `api.meta.ai` or `openrouter.ai`) and nowhere else.
`ai/agent_loop.dart` is the loop in which the model calls tools until it ends its turn, the same for every provider. A tool (`AgentTool`, or `FnTool` made of closures)
has a name, a description, a JSON schema its input is checked against before it runs, and an effect (read, write, export
or network) that the permission mode governs (`AgentPermission.readOnly`, `plan`, `ask` with the `approve` callback of
`AgentEvents`, `auto`). `buildProjectContext` writes the compact project data the app attaches to a question, from the
report tables and the design messages, bounded to about 18 000 characters. A real conversation costs tokens billed to
the key's account; the test runs this snippet for each provider against a scripted transport.

```dart
final project = Project.fromJsonString(File('examples/en/garden.oci.json').readAsStringSync());
final results = Designer(project).designAll();
final t = I18n('en');
final labels = ReportLabels(t: t.call, has: t.has, warning: t.warning);
final context = buildProjectContext(ContextSource(project: project, labels: labels, results: results, tables: ProjectExporter(project: project, results: results, labels: labels).reportTables()));
print('project data: ${context.text.length} characters, about ${context.approxTokens} tokens');
final AiClient api = provider == AiProvider.anthropic ? AnthropicClient(apiKey: apiKey, transport: transport) : OpenAiClient(apiKey: apiKey, transport: transport);
final countItems = FnTool(
  name: 'count_items',
  description: 'Counts the items of the open project.',
  inputSchema: const {'type': 'object', 'properties': {}, 'additionalProperties': false},
  handler: (input) async => ToolOutput('${project.entities.length} items'),
);
final turn = await AgentLoop(api: api, tools: [countItems]).run(
  model: provider == AiProvider.anthropic ? AiModel.opus55 : AiModel.gpt6Astra,
  system: 'You help an irrigation designer with the open project.',
  history: const [],
  user: api.userMessage([AiTextPart('<project_data>\n${context.text}\n</project_data>\n\nHow many items does the drawing have?')]),
  permission: AgentPermission.readOnly,
  cancel: AiCancel(),
);
print('${turn.text} (${turn.steps} requests, ${turn.calls.length} tool call, US\$ ${fmt(turn.cost, 4)} at list prices)');
```

`turn.messages` is what goes on the conversation's history for the next question, in the provider's own format (the
question, the model's answers exactly as they came — Anthropic thinking blocks, OpenAI encrypted reasoning items — and a
result for every tool call); `turn.stop` says why the turn ended (`done`, `maxTokens`, `stepLimit` after `maxSteps`
requests, `budget` past `costCap`, `cancelled` through `AiCancel`, `error` with an `AiError`). `AiClient.send` alone runs
one streamed request with retries on overloads, rate limits, server and network errors, timeouts and dropped streams (while nothing of the answer was shown). The names of the first, Anthropic-only
version (`ClaudeApi`, `ClaudeModel`, `ClaudeCancel`…) remain as aliases.

### Added in 1.6.0

The libraries 1.6.0 added to `lib/core/api.dart` (the blocks marked `// 1.6.0` in it and the libraries of the engine,
formats and model areas), by subject. They follow the conventions of the rest of the engine: functions over a `Project`
and its `DesignResults`, settings kept in the project file only when they differ from those of a new project (fields of
a newer version kept as read), report tables built like the others (the reports panel and every exporter show the same
numbers) and the long analyses written as steps. The command line that makes and changes projects and the engine as a
package without Flutter are in [Using the engine](#1-using-the-engine).

| Subject | Libraries | Entry points |
|---|---|---|
| Pump stations, valve pilots, real operation of the zones | `model/pump_station.dart`, `model/valve_pilot.dart`, `design/results_mot.dart`, `design/report_tables_mot.dart` | `PumpEntity.station` (`PumpStation`, `PumpUnit`, `PumpArrangement`), solved on `PumpCurve.parallel` and `PumpCurve.series`; `PumpEntity.flywheelKgm2`; `ControlValveEntity.pilot` and `MiscHydraulicEntity.pilot` (`ValvePilot`); `DesignParameters.realZoneOperation`; `StationDuty`, `StationUnitDuty` and `ZoneOperation` in the results; `motReportTables` |
| Reservoirs, air vessels, ageing and clogging, progress and cancel | `model/reservoir.dart`, `design/reservoir.dart`, `design/life_scenarios.dart`, `design/analysis_control.dart` | `WaterSupplyEntity.reservoir` (`ReservoirSpec`) and `reservoirStudy` (the stage–area–volume curve, `ReservoirStudy.tankAt` for the extended period); `JunctionEntity.vesselLiters` for the transients; `lifeScenarios` and `lifeScenariosAsync` (`LifeOptions`, `LifeFigures`); `runSteps` and `runStepsAsync` with an `AnalysisControl` that cancels (`AnalysisCancelled`) |
| Longest lateral | `design/lateral_limit.dart` | `maxLateralRun`, `maxLateralRunsBothWays`, `tapeLateralSpec`, `emitterLateralSpec`, `terrainSlopeAlong` |
| Agronomy | `design/soil_water_balance.dart`, `design/irrigation_programme.dart`, `design/runoff_potential.dart`, `design/system_capacity.dart`, `design/catch_cans.dart`, `design/fertigation_stages.dart`, `design/agr_tables.dart`, `io/inmet_csv.dart`, `model/agronomy_plan.dart` | `soilWaterBalance`, `areaWaterBalance`; `buildIrrigationProgramme`, `programmeRunsCsv`, `programmeStationsCsv`; `machineRunoff`, `zoneRunoff`; `systemCapacity`; `depthDensogram`, `canGridOver`, `evaluateFieldTest`; `fertigationSchedule`; `parseInmetCsv`, `readStationFiles`, `stationClimate`; `Project.agronomy` (`AgronomyPlan`, `UserCrop`); `agronomyPlusTables` |
| Power, water and machines | `design/agb_design.dart`, `design/pump_house.dart`, `design/solar_design.dart`, `design/water_quality.dart`, `design/multi_pivot.dart`, `design/field_machines.dart`, `design/agb_reports.dart`, `model/agb_settings.dart` | `designAgb` (the step of the design, its results in `DesignResults.agb`, its bill lines by `agbBomLines`), `designPumpHouse`, `designSolar`, `designWaterQuality`, `layoutPivots`, `layoutTravellerLanes`, `analyzeTravellerLane`, `analyzeFurrowSet`; `Project.agb` (`AgbSettings`); `agbReportTables` |
| Title block, sheets, standards, document packages | `model/title_block.dart`, `io/title_block_sheet.dart`, `io/sheet_grid.dart`, `io/sheet_theme.dart`, `io/doc_package.dart`, `io/doc_pdf.dart`, `io/doc_sections.dart`, `design/report_standards.dart`, `design/slope_report.dart` | `ProjectMeta.titleBlock` (`TitleBlock`), `drawProTitleBlock`; `utmGridLines`, `graticuleLines`, `drawSheetGrid`; `ThemeMap`; `buildDocumentPackage` (`DocPackageOptions`, `DocProfile`), `registerDocumentSection`; `reportCriteria`, `attachStandards`; `slopeClassAreas`, `slopeClassesTable` |
| Technical documents | `design/permit.dart`, `design/memorial.dart`, `design/om_plan.dart`, `design/budget.dart`, `design/life_cycle.dart`, `io/tech_doc.dart`, `io/tech_doc_sections.dart`, `model/deliverables.dart` | `buildPermitStudy`, `permitDocument`; `buildMemorial`; `buildOmPlan`; `buildBudget`, `budgetDocument`; `buildLifeCycleStudy`, `lifeCycleDocument`; `TechDocument` and its writers (`techDocumentPdf`, Markdown, CSV and XLSX); `prbDocumentSections` for the packages; `Project.deliverables` (`DeliverableSettings`) |
| Drawing edits | `model/edit_ops.dart`, `model/lengthen.dart`, `model/boundary.dart`, `model/dim_style.dart`, `model/layer_states.dart`, `model/project_compare.dart`, `io/typed_geo.dart` | `joinChains`, `explodeEntity`, `filletBetween`, `chamferVertex`, `stretchEntity`, `breakEntity`; `lengthenEntity`; `boundaryAround`; `DimStyle`; `LayerState`; `compareProjects`, `mergeReview`; `parseTypedGeoPoint` |
| Model and catalogues | `model/area_holes.dart`, `model/project_merge.dart`, `model/paste.dart`, `model/pipe_standards.dart`, `model/regional.dart`, `model/schema.dart`, `model/read_report.dart`, `design/area_water.dart`, `design/model_checks.dart` | `AreaEntity.holes`, `subtractFromArea`, `subtractFromAreas`; `insertProject`; `pasteEntities`; `pipeStandards`, `standardPack`, `standardCatalogPacks`; `mainsHzForLocale`, `unitsForLocale`; `projectJsonSchema`; `ProjectReadReport`; `areaWaterBasis`; `modelChecks` |
| Files | `io/drawing_import.dart`, `io/import_async.dart`, `io/work_slicer.dart`, `io/safe_archive.dart`, `io/tiff_raster.dart`, `io/cad_xdata.dart`, `io/codepages.dart`, `io/stakeout.dart`, `io/data_cache.dart`, `io/data_credits.dart`, `io/icc_srgb.dart`, `io/image_decode.dart`, `io/xml_text.dart`, `io/sheet_check.dart` | `importFileInto`, `importDrawingInto`; `readImportAsync`; `WorkSlicer`; `openZip`, `gunzipCapped`; `TiffFile`, `TiffRaster`, `TiffReducer`, `TiffGridSampler`; `hydraulicXdata`, `readHydraulicXdata`, `restoreHydraulic`; `decodeCodepage`, `loadCjkCodepages`; `stakeoutPoints`, `stakeoutCsv`; `DataCache` (over a `DataCacheStore`); `projectDataCredits`, `sheetCredits`; `srgbIccProfile`; `SheetReview` |
| Also exported now | `design/region_trace.dart`, `ai/image_prep.dart` | `traceRegion`, `traceRegions` (outlines grown from a point on an aerial picture); `prepareModelImage` (pictures fitted to what the models take) |

The projections beyond the transverse Mercator (Albers equal-area, Lambert conformal conic, polyconic) are in
`io/datum.dart` with the rest of the coordinate systems (`parseCrs` reads them), and the datum of a project's
georeference is `GeoReference.datum`, or the site's (`GeoReference.effectiveDatum`, `defaultProjectDatum`).

### Added in 1.7.0

The libraries 1.7.0 added to `lib/core/api.dart` (the blocks marked `// 1.7.0` in it, and the AI clients next to the
earlier ones), by subject. The reports they add are tables like the others; the forecast is not project data, so its
tables are built from a plan and not by `buildReportTables`.

| Subject | Libraries | Entry points |
|---|---|---|
| AI clients of Google, xAI, Meta and OpenRouter | `ai/gemini_api.dart`, `ai/xai_api.dart`, `ai/meta_api.dart`, `ai/openrouter_api.dart`, `ai/openrouter_catalog.dart` | `GeminiClient` (with `GeminiFormat`), `XaiClient`, `MetaClient`, `OpenRouterClient`; `OpenRouterCatalog.parse` and `entryOf` (rows of `GET https://openrouter.ai/api/v1/models` as `OpenRouterEntry`, each with its `AiModel`); `AiModel.register`, `AiModel.offered` and `AiModel.find` for the models added; `AiUsage.charged` (what OpenRouter says it charged, used for a router's pick the table does not price) |
| Crop rows from the image | `design/crop_rows.dart` | `detectCropRows` on a `CropRowRaster` (straight RGBA, north up, square pixels over a world rectangle) with `CropRowOptions` (closest and widest spacing, the other band) gives a `CropRowResult` (verdict, `directionDeg` counter-clockwise from the x axis in [0, 180), `spacingM`, `rows`, `confidence`, `plantSpacingM`, `groundCover`, `rowLines`, messages); `cropRowFrame` chooses the frame and pixel size to render; `cropRowLines` and `rowSegments` give the rows of a field; `applyCropRows` writes them into the project; `storedRowDirection`, `storedRowSpacing` and `storedPlantSpacing` read them back from an `AreaEntity` (`rowDirectionDeg`, `rowSpacingM`, `plantSpacingM`) |
| Climate risk over the years | `design/climate_risk.dart`, `design/climate_risk_stats.dart`, `model/climate_risk_summary.dart` | `climateRiskAnalysis` over a `RiskSeries` (`RiskSeries.ofClimateSeries` from a NASA POWER download, `RiskSeries.ofDaily` from `SiteClimate.daily`), `areaDailyCapacity`, `climateRiskTables`; `quantileAt`, `exceedanceCurve`, `senMannKendall`; `Project.climateRisk` (`ClimateRiskSummary`); `BalanceInput.maxGrossMmDay` and `BalanceInput.yearStart` of the daily balance |
| Irrigation forecast | `design/irrigation_forecast.dart`, `io/forecast_online.dart` | `fetchForecast` (a `ForecastSource`, an injected GET and a `ForecastKeeper` such as `DataCacheForecastKeeper` that keeps the answer while it is valid), `forecastParse`, `forecastDayEto`; `irrigationForecast` over a `ForecastSeries` with a `ForecastStart` gives a `ForecastPlan`; `forecastTables` |
| Programme played on the plan, its calendar | `design/programme_playback.dart`, `design/programme_calendar.dart`, `io/ics.dart`, `io/gif_animation.dart` | `buildProgrammeTimeline` and `programmeTimeline` (`ProgrammeTimeline`: the runs of the cycle, what runs at an hour, the next start, the clock), `programmePeriodDays`, `ProgrammePlayback` and its `PlaybackFrame`s with the `FlowView` of each group, `reservoirTrace`, `playbackFrameTimes`; `programmeCalendar` and `programmeEvents`; `writeIcs`, `icsFold`, `icsText`, `icsUnfold`; `GifAnimation` |
| Design scorecard | `design/scorecard.dart`, `io/scorecard_chart.dart` | `designScorecard` gives a `DesignScorecard` (categories, indicators with their `ScoreCurve`, value, target, sources and score, `gainOf`), `scoreGrade`, `scorecardTable`; `scorecardChart` (the radar as a `PlotChart` for the sheets and the document packages) |
| Curves from a picture | `design/curve_digitiser.dart`, `design/curve_trace.dart`, `design/curve_fits.dart` | `AxisUnit`, `AxisCalibration` (two points per axis, linear or logarithmic) and `ChartMapping` (the affine mapping, its inverse and `CalibrationError`), `CurveKind`, `CurveRole`, `DigitiserSession`; `ChartRaster`, `traceCurve`, `sampleTrack`; `fitPumpChart`, `fitEmitterChart`, `fitProfileChart`, `cleanChartPoints`; `putPumpChart`, `putNewOutlet`, `putNozzleCurve`, `putTapeEmitter`, `putNozzleProfile` (`ChartApplyError`) |
| MCP server | `mcp/mcp_server.dart`, `mcp/json_schema.dart`, `mcp/oci_mcp_tools.dart`, `model/default_layers.dart` | `McpServer` (the protocol without a transport), `schemaProblems` and `schemaErrors`, `OciMcpTools` over an `OciMcpHost`, `defaultLayerFor`; the command `dart run bin/oci.dart mcp --root <folder>` and its transport are in `bin/` ([docs/MCP.md](MCP.md)) |

## 6. Conventions

- **Units**: SI inside the engine: lengths and elevations in m, flow in m³/s, head and pressure in metres of water
  (gauge), diameters in m (catalogue fields ending in `Mm` are millimetres), time in s or h as named. `lib/core/units.dart`
  has the conversions (`m3sPerLph`, `m3sPerM3h`, `m3sPerGpm`, `psiPerMeterHead`…) and `Units` the display units of a
  project.
- **Messages are codes**: `code` or `code:argument` (usually an entity id). The app translates them with the string table:
  `check.<code>`, `warn.<code>`, `adv.<code>.why` and `adv.<code>.how`.
- **Determinism**: the same project gives the same results; besides the installed language packs and the registered PDF
  fonts, the engine keeps no global state that changes them (the largest terrain the TIN takes as is, for one, is the
  `tinLimit` of each `Terrain`, `Terrain.maxTinPoints` by default).
- **Mutation**: `Designer.designAll` changes the project it designs (pipe sizes, telescoped pipes split); work on
  `project.copy()` to keep the original. Readers never change their input.
- **Stability**: this API is the engine of the app, not a frozen interface. It follows the app's needs; the tests in
  `test/core` are the reference for every module.
