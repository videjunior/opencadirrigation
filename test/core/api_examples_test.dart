// dart format off
// (the snippets of docs/API.md are matched line by line against this file)
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/core/api.dart';

import '../support/fake_claude.dart';
import '../support/fake_openai.dart';

/// Every snippet of docs/API.md and docs/API.pt-BR.md, run as written (the
/// last test checks that the documents show no code these tests do not
/// run). What a snippet prints is collected here instead of the console.
final printed = <String>[];
void print(Object? object) => printed.add('$object');

Project example(String name) => Project.fromJsonString(File('examples/en/$name.oci.json').readAsStringSync());

void main() {
  setUp(printed.clear);

  group('projects and design', () {
    test('load, design, read the results, save', () {
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

      expect(results.zones, hasLength(3));
      expect(printed.first, startsWith('Zone 1'));
      expect(printed.last, contains(project.params.currency));
      expect(Project.fromJsonString(saved).entities.length, project.entities.length);
      expect(results.zones.values.every((z) => z.converged && z.withinWindow), isTrue);
    });

    test('analysis only, progress and results as JSON', () async {
      final project = example('orchard');
      final analysis = Designer(project).analyzeAll();
      final designer = Designer(project);
      final results = await designer.designAllAsync(onProgress: (p) => print('${p.stage.name} ${p.done}/${p.total}'));
      final json = jsonEncode(results.toJson());
      final again = DesignResults.fromJson(jsonDecode(json) as Map<String, dynamic>);

      expect(analysis.method, isNot(results.method));
      expect(printed, contains(startsWith('zones ')));
      expect(again.zones.keys, results.zones.keys);
      expect(again.capitalCost, closeTo(results.capitalCost, 1e-9));
    });

    test('a project built in code', () {
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
      print('${zone.emitterCount} micro-sprinklers, ${fmt(zone.totalFlow * 3600, 1)} m³/h, '
          'the supply must give ${fmt(results.systemFlows.first.supplies.first.requiredHead, 1)} m');

      expect(zone.emitterCount, 11 * 34);
      expect(zone.withinWindow, isTrue);
      expect(project.entities.whereType<PipeEntity>().every((p) => project.catalog.pipe(p.pipeSpecId) != null), isTrue);
    });

    test('the catalogue', () {
      final catalog = Catalog.defaultCatalog();
      final pipe = catalog.pipe('pvc50')!;
      print('${pipe.name}: inner ${pipe.innerDiameterMm} mm, rated ${pipe.pressureRatingM} m, ${pipe.costPerM}/m');
      final rotor = catalog.outlet('rotor')!;
      for (final nozzle in rotor.nozzles.take(3)) {
        print('${nozzle.id}: ${fmt(nozzle.curve.flow(30) * 3600, 2)} m³/h at 30 m');
      }
      final lightest = catalog.pipes.where((p) => p.enabled && p.usage.contains(PipeUsage.mainline)).reduce((a, b) => a.costPerM <= b.costPerM ? a : b);

      expect(pipe.innerDiameter, closeTo(pipe.innerDiameterMm / 1000, 1e-12));
      expect(printed.length, 4);
      expect(lightest.costPerM, greaterThan(0));
    });

    test('catalogue plausibility', () {
      final problems = catalogPlausibility(Catalog.defaultCatalog());
      print(problems.isEmpty ? 'plausible' : problems.join('\n'));

      expect(printed.single, 'plausible');
    });

    test('damaged files and files of other versions', () {
      final file = readProjectFile(File('examples/en/garden.oci.json').readAsStringSync());
      final report = file.report;
      for (final note in report.notes) {
        print('${note.code} ${note.args}');
      }
      print('${file.project.entities.length} entities, ${report.skippedCount} set aside, clean: ${report.clean}');

      expect(printed.last, endsWith('0 set aside, clean: true'));
      expect(file.results, isNull, reason: 'the examples are saved without results');
    });
  });

  group('messages, reports and exports', () {
    test('design check and the design assistant', () {
      final project = example('garden');
      project.entities.removeWhere((e) => e is WaterSupplyEntity);
      final check = runDesignCheck(project);
      for (final issue in check.issues) {
        print('${issue.severity.name} ${issue.code} ${issue.entityIds.join(',')}');
      }
      final advice = buildAdvice(project);
      final t = I18n('pt');
      for (final a in advice.where((a) => a.level == AdviceLevel.error)) {
        print('${t('check.${a.raw}')} → ${t('adv.${a.code}.how')}');
      }

      expect(check.ok, isFalse);
      expect(advice.first.code, 'no_supply');
      expect(advice.first.fixes, isNotEmpty);
      expect(printed.last, contains('→'));
    });

    test('report tables and exports', () {
      final project = example('garden');
      final results = Designer(project).designAll();
      final t = I18n('en');
      final exporter = ProjectExporter(
        project: project,
        results: results,
        labels: ReportLabels(t: t.call, has: t.has, warning: t.warning),
      );
      final tables = exporter.reportTables();
      print(tables.map((tb) => tb.key).join(', '));
      final csv = reportTablesToCsv(tables);
      final dxf = exporter.exportDrawing(DrawingFormat.dxf) as String;
      final dwg = exporter.exportDrawing(DrawingFormat.dwg) as Uint8List;
      final inp = exporter.exportDrawing(DrawingFormat.inp) as String;
      final xlsx = exporter.exportReport(ReportFormat.xlsx) as Uint8List;
      final pdf = exporter.exportDrawing(DrawingFormat.pdf, sheet: const SheetOptions(page: PageSize.a1)) as Uint8List;
      project.meta.georef = GeoReference.fromLatLonOrigin(-22.9068, -43.1729);
      final kml = exporter.exportDrawing(DrawingFormat.kml) as String;

      expect(printed.single, startsWith('zones, pipes'));
      expect(csv, contains('ZONE SUMMARY'));
      expect(DxfReader.parse(dxf).entities, isNotEmpty);
      expect(String.fromCharCodes(dwg.sublist(0, 6)), 'AC1015');
      expect(EpanetInpReader.parse(inp).toNetwork().solve().converged, isTrue);
      expect(xlsx.sublist(0, 2), 'PK'.codeUnits);
      expect(String.fromCharCodes(pdf.sublist(0, 5)), '%PDF-');
      expect(KmlReader.parse(kml).placemarkCount, greaterThan(0));
    });
  });

  group('the hydraulic solver', () {
    test('a pipe network with emitters', () {
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

      expect(result.converged, isTrue);
      expect(j2.emitterFlow, closeTo(10 * EmitterCurve.fromNominal(flow: 1.0 / 3600, head: 15).flow(j2.pressure), 1e-9));
      expect(result.links['P1']!.flow, closeTo(j2.emitterFlow, 1e-9));
    });

    test('pumps, pressure reducing valves and check valves', () {
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
      print('pump: ${fmt(pump.flow * 3600, 1)} m³/h at ${fmt(pump.pumpHead, 1)} m; '
          'after the PRV: ${fmt(result.nodes['field']!.pressure, 1)} m (${result.links['prv']!.status.name})');

      expect(result.converged, isTrue);
      expect(pump.flow, closeTo(0.008, 1e-6));
      expect(result.nodes['field']!.pressure, closeTo(25, 1e-3));
      expect(result.links['prv']!.status, LinkStatus.active);
    });

    test('friction, emitters and pump curves', () {
      final hf = hazenWilliamsLoss(flow: 0.003, diameter: 0.06, length: 80, c: 140);
      final dw = darcyWeisbachLoss(flow: 0.003, diameter: 0.06, length: 80, roughness: 1.5e-6);
      final dripper = EmitterCurve.fromNominal(flow: 2 / 3.6e6, head: 10, x: 0.5);
      final pump = PumpCurve.fit([(0, 50), (0.01, 45), (0.02, 30)]);
      final duty = operatingPoint(pump, const SystemCurve(staticHead: 20, k: 30000));
      print('hf ${fmt(hf, 3)} m (Hazen-Williams), ${fmt(dw, 3)} m (Darcy-Weisbach); '
          'dripper at 15 m: ${fmt(dripper.flow(15) * 3.6e6, 2)} L/h; duty ${fmt(duty!.$1 * 3600, 1)} m³/h at ${fmt(duty.$2, 1)} m');

      expect(hf, greaterThan(0));
      expect(dripper.flow(10) * 3.6e6, closeTo(2, 1e-9));
      expect(pump.head(duty.$1), closeTo(duty.$2, 1e-3));
    });
  });

  group('newer modules', () {
    test('water hammer: valve closure on a pipe', () {
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
      print('surge ${fmt(n.maxHead - n.steadyHead, 1)} m (Joukowsky a·V/g), lowest ${fmt(n.minPressure, 1)} m');

      final v = steady.links['P']!.flow / (math.pi * 0.25 * 0.25);
      expect(n.maxHead - n.steadyHead, closeTo(1000 * v / gravity, 1e-3 * 1000 * v / gravity));
      expect(run.seriesOf('N')!.heads, isNotEmpty);
    });

    test('transients, 24 hours and air valves on a project', () {
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
      for (final s in air.suggestions) {
        print('air valve ${s.type.name} at ${fmt(s.chainage, 0)} m (${s.reasons.first.name})');
      }

      expect(transient.runs.where((r) => r.ran), isNotEmpty);
      expect(day.energyKwh, greaterThan(0));
      expect(day.times, isNotEmpty);
      expect(air.messages, isA<List<String>>());
    });

    test('extended period simulation: a tank filling', () {
      final net = HydraulicNetwork();
      net.addNode(HNode(id: 'J', demand: -0.01));
      net.addNode(HNode(id: 'T', elevation: 5));
      net.addLink(HLink(id: 'P', from: 'J', to: 'T', diameter: 0.15, length: 50, hazenC: 130));
      final eps = simulateEps(net, tanks: const [EpsTank(nodeId: 'T', initialLevel: 1, maxLevel: 6, area: 50)], options: const EpsOptions(duration: 5 * 3600));
      for (var i = 0; i < eps.times.length; i++) {
        print('${eps.times[i] ~/ 3600} h: ${fmt(eps.tankLevels['T']![i], 2)} m');
      }

      expect(eps.tankLevels['T']!.last, closeTo(1 + 0.01 * 5 * 3600 / 50, 1e-9));
      expect(eps.messages, isEmpty);
    });

    test('air valves along a profile', () {
      final plan = suggestAirValves(PipelineProfile(points: const [
        ProfilePoint(chainage: 0, pipe: 0),
        ProfilePoint(chainage: 1000, pipe: 20),
        ProfilePoint(chainage: 2000, pipe: 0),
      ], diameter: 0.3, designFlow: 0.05));
      for (final s in plan.suggestions) {
        print('${fmt(s.chainage, 0)} m: ${s.type.name} (${s.reason.name}), ${fmt(s.sizing.nominalSize * 1000, 0)} mm');
      }

      expect([for (final s in plan.suggestions) s.chainage], [500, 1000, 1500, 2000]);
      expect(plan.suggestions[1].reason, AirValveReason.highPoint);
    });

    test('layout automation: heads, zones, valves and pipes for a lawn', () {
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
      print('${layout.heads.length} rotors, CU ${fmt(layout.metrics!.cu, 1)} %, ${zoning.zones.length} zones, '
          '${fmt(routing.mainlineLength, 0)} m of mainline, ${results.zones.values.where((z) => z.withinWindow).length} zones in their pressure window');

      expect(results.zones.length, zoning.zones.length);
      expect(results.zones.values.every((z) => z.withinWindow), isTrue);
    });

    test('fields, blocks and pivots', () {
      const field = [Pt(0, 0), Pt(420, 0), Pt(420, 180), Pt(250, 260), Pt(0, 260)];
      final blocks = subdivideField(field, FieldSubdivisionOptions(direction: const Pt(1, 0), maxBlockArea: 2e4, roadWidth: 4));
      final project = Project();
      for (final b in blocks.blocks) {
        project.entities.addAll(generateBlock(project, blockOptionsFor(b, blocks.direction, lateralSpacing: 1.8, isTape: true, tapeSpecId: 'tape16_10_30', valveSpecId: 'ev80')).all);
      }
      final pivot = fitFullCirclePivot(const [Pt(0, 0), Pt(900, 0), Pt(900, 650), Pt(0, 650)], PivotFitOptions(endThrowM: 15));
      project.entities.add(pivot.toPivotEntity(project, name: 'Pivot 1'));
      print('${blocks.blocks.length} blocks of ${fmt(blocks.blocks.first.area / 1e4, 2)} ha; '
          'pivot of ${pivot.spans!.count} spans, ${fmt(pivot.machineLength, 1)} m, ${fmt(pivot.area / 1e4, 1)} ha');

      expect(blocks.blocks.length, (blocks.fieldArea / 2e4).ceil());
      expect(pivot.fullCircle, isTrue);
      expect(project.entities.whereType<ControlValveEntity>().length, blocks.blocks.length);
    });

    test('agronomy', () {
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
      print('ETo ${fmt(eto.etoMmDay, 2)} mm/day; bean Kc at day 40: ${fmt(bean.at(40), 2)}; '
          'loam holds ${fmt(loam.awcMmPerM, 0)} mm/m; peak gross ${fmt(table.areaTotals.peakGrossMmDay, 2)} mm/day; '
          '${soak.cycles} cycles of ${fmt(soak.runMinutesPerCycle, 0)} min; wetted bulb ${fmt(bulb.widthM, 2)} × ${fmt(bulb.depthM, 2)} m');

      expect(eto.etoMmDay, closeTo(4.56, 0.01));
      expect(table.monthly, hasLength(12));
      expect(soak.cycles, 2);
    });

    test('mechanised machines', () {
      final project = Project();
      final pivot = PivotEntity(id: project.newId(), center: const Pt(0, 0), radiusM: 400, name: 'Pivot 1', machine: PivotMachine(towerSpeedMPerMin: 3));
      project.entities.add(pivot);
      final machine = analyzeMechanised(project, pivot);
      final package = machine.package;
      print('${package.sprinklerCount} sprinklers, ${fmt(package.systemFlow * 3600, 1)} m³/h, '
          '${fmt(package.hoursAt100, 1)} h a turn at 100 %, ${fmt(package.depthAt100Mm, 1)} mm');
      final gun = analyzeTraveller(const TravellerSpec(gunFlow: 30 / 3600, gunPressureM: 45, wettedDiameterM: 90, hoseLengthM: 350, hoseInnerMm: 90, speedMPerMin: 0.5));
      print('traveller: ${fmt(gun.grossDepthMm, 1)} mm, inlet ${fmt(gun.inletHeadM, 1)} m');

      expect(package.outlets, isNotEmpty);
      expect(package.hoursAt100, closeTo(2 * math.pi * 400 / 3 / 60, 1e-9));
      expect(gun.inletHeadM, greaterThan(45));
    });

    test('file formats', () {
      final doc = DxfDocument(layers: [DxfLayer('PIPES', color: 5)], entities: [
        DxfEntity(type: 'LINE', layer: 'PIPES', points: [const Pt(0, 0), const Pt(10, 5)]),
        DxfEntity(type: 'CIRCLE', layer: 'PIPES', center: const Pt(3, 3), radius: 2),
      ]);
      final dxf = DxfWriter.write(doc);
      final dwg = DwgWriter.write(doc);
      print('${DxfReader.parse(dxf).entities.length} entities from the DXF, ${DwgReader.parse(dwg).document.entities.length} from the DWG');
      final points = PointsCsvReader.parse('lat,lon,alt\n-22.9,-47.06,600\n-22.9001,-47.0601,601\n');
      print('${points.count} spot heights, UTM zone ${points.georef!.zone}');
      final geojson = GeoJsonReader.parse(jsonEncode({'type': 'Point', 'coordinates': [-47.93, -15.78, 1000.5]}));
      print('GeoJSON point at ${geojson.document.entities.single.elevation} m');
      final crs = parseCrs('EPSG:31983');
      print('${crs.name}: UTM ${crs.utmZone}');

      expect(DxfReader.parse(dxf).entities, hasLength(2));
      expect(points.count, 2);
      expect(crs.utmZone, 23);
    });

    test('valve-in-head stations', () {
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

      expect(stations.heads, {
        'vih:Green': ['h1', 'h2', 'h3'],
        'vih:Tee': ['h4', 'h5', 'h6'],
      });
      expect(stations.scheduled, {'vih:Green', 'vih:Tee'});
      expect([for (final f in results.systemFlows) f.heads.single.stationId], ['vih:Green', 'vih:Tee']);
      expect(results.systemFlows.every((f) => f.heads.single.deficit <= 0.011), isTrue);
      expect(printed.length, 3);
    });

    test('mains frequency and variable-speed pumps', () {
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

      expect(speedOf(fixed), closeTo(5 / 6, 1e-9));
      expect(speedOf(drive), isNot(closeTo(5 / 6, 1e-6)));
      expect(TransientStudyOptions.speedForPoles(2, 50), 2900);
      expect(TransientStudyOptions.speedForPoles(4, 60), 1750);
    });

    test('vegetation from aerial imagery', () {
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

      expect(image.pixelSizeM, closeTo(0.1, 1e-12));
      expect(found.patches.single.cls, VegetationClass.turf);
      expect(found.patches.single.grossArea, closeTo(28 * 20, 28 * 20 * 0.02));
      expect(found.patches.single.area, closeTo(28 * 20 - math.pi * 9, 28 * 20 * 0.02));
      expect(project.entities.whereType<AreaEntity>().single.name, 'Lawn 1');
      expect(project.entities.whereType<PolylineEntity>().single.name, 'Lawn 1, exclusion 1');
    });

    test('PDF plans as an underlay', () {
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

      expect(pdf.pageCount, greaterThan(0));
      expect(plan.entities, isNotEmpty);
      expect(project.entities.length, plan.entities.length);
      expect(project.findLayer('PDF-garden'), isNotNull);
    });

    test('native CAD drawing (DXF 2000 and DWG)', () {
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

      expect(dxf, contains('AC1015'));
      expect(String.fromCharCodes(dwg.sublist(0, 6)), 'AC1015');
      expect(latin1.decode(r12), contains('AC1009'));
      expect(DxfReader.parse(dxf).entities, isNotEmpty);
      expect(DwgReader.parse(dwg).document.entities, isNotEmpty);
      expect(drawing.entities.whereType<CadInsert>(), isNotEmpty);
    });

    test('the AI assistant: a client per provider and the agent loop', () async {
      for (final provider in AiProvider.values) {
        final apiKey = provider == AiProvider.anthropic ? 'sk-ant-test-0000' : 'sk-proj-test-0000';
        final claude = FakeClaude([
          (_) => FakeReply.tools([('count_items', <String, dynamic>{})], text: 'Let me count.'),
          // the scripted model reads the tool result of the request it answers
          (body) => FakeReply.text('The drawing has ${(((body['messages'] as List).last as Map)['content'] as List).first['content']}.'),
        ]);
        final openai = FakeOpenAi([
          (_) => OpenAiReply.tools([('count_items', <String, dynamic>{})], text: 'Let me count.'),
          (body) => OpenAiReply.text('The drawing has ${((body['input'] as List).last as Map)['output']}.'),
        ]);
        final AiTransport transport = provider == AiProvider.anthropic ? claude.call : openai.call;
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

        expect(turn.stop, AgentStop.done);
        expect(turn.calls.single.name, 'count_items');
        expect(turn.text, contains('${project.entities.length} items'));
        expect(context.approxTokens, greaterThan(100));
        if (provider == AiProvider.anthropic) {
          expect(claude.calls, 2);
          expect(claude.requests.first.headers['x-api-key'], apiKey);
          expect(claude.requests.first.body.contains(apiKey), isFalse);
          expect(claude.lastUserText(1), '${project.entities.length} items');
          expect(turn.messages.map((m) => m['role']), ['user', 'assistant', 'user', 'assistant']);
        } else {
          expect(openai.calls, 2);
          expect(openai.requests.first.headers['authorization'], 'Bearer $apiKey');
          expect(openai.requests.first.body.contains(apiKey), isFalse);
          expect(turn.messages.map((m) => m['type']), ['message', 'reasoning', 'message', 'function_call', 'function_call_output', 'reasoning', 'message']);
        }
      }
    });
  });

  test('the documents show only code these tests run', () {
    final source = File('test/core/api_examples_test.dart').readAsLinesSync().map((l) => l.trim()).toSet();
    for (final doc in ['docs/API.md', 'docs/API.pt-BR.md']) {
      final text = File(doc).readAsStringSync();
      final blocks = RegExp(r'```dart\n([\s\S]*?)```').allMatches(text).map((m) => m.group(1)!).toList();
      expect(blocks.length, greaterThan(10), reason: doc);
      for (final block in blocks) {
        for (final line in block.split('\n').map((l) => l.trim())) {
          if (line.isEmpty || line.startsWith('//') || line.startsWith('import ')) continue;
          expect(source, contains(line), reason: '$doc shows a line no test runs: $line');
        }
      }
    }
  });
}
