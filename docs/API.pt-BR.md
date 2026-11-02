# API do motor do OpenCADIrrigation

*English: [API.md](API.md)*

Tudo o que o OpenCADIrrigation calcula está em `lib/core`: Dart puro, sem Flutter. O motor é o mesmo em toda parte: o
aplicativo o executa num Web Worker (navegador) ou num isolate (desktop), a linha de comando (`bin/oci.dart`) o executa na
VM do Dart, e seus próprios scripts podem chamá-lo. Esta página percorre essa biblioteca: abrir um projeto, rodar o
dimensionamento, ler os resultados, os relatórios e as exportações, o solver hidráulico sozinho e os módulos mais novos
(transientes, simulação de período estendido, ventosas, automação do traçado, estações valve-in-head, bombas e a frequência
da rede elétrica, detecção de vegetação, agronomia, máquinas mecanizadas, formatos de arquivo, plantas em PDF, o desenho
CAD nativo e o cliente do assistente de IA).

Cada trecho abaixo é executado, exatamente como aparece, por `test/core/api_examples_test.dart`, que também falha quando
esta página mostra uma linha de código que os testes não executam. Os caminhos são relativos à raiz do repositório. O
código é o mesmo da versão em inglês (os textos impressos ficam em inglês).

## Conteúdo

1. [Usando o motor](#1-usando-o-motor)
2. [Projetos e o dimensionamento](#2-projetos-e-o-dimensionamento)
3. [Mensagens, relatórios e exportações](#3-mensagens-relatórios-e-exportações)
4. [O solver hidráulico](#4-o-solver-hidráulico)
5. [Módulos mais novos](#5-módulos-mais-novos)
6. [Convenções](#6-convenções)

## 1. Usando o motor

Uma importação traz toda a superfície pública:

```dart
import 'package:opencadirrigation/core/api.dart';
```

`lib/core/api.dart` exporta todas as bibliotecas de `lib/core`, exceto os detalhes internos da composição de texto do PDF
(`io/fonts/*`, menos `pdf_fonts.dart`) e o solver de matrizes esparsas (`hydraulics/sparse_solver.dart`);
`test/core/api_exports_test.dart` falha quando falta alguma. Importar as bibliotecas individuais
(`core/model/project.dart`, `core/design/designer.dart`, …) também funciona e é o que o aplicativo faz. O motor não faz entrada nem saída por conta
própria: os leitores recebem textos ou bytes, os gravadores os devolvem, e quem chama decide de onde vêm e para onde vão.

**Onde executar.** O pacote depende do SDK do Flutter (por causa do aplicativo), então `dart run` funciona dentro deste
repositório (`dart run bin/oci.dart`, ou um script seu em `tool/` ou `bin/`), e um projeto Flutter pode depender dele por
caminho ou git. Um pacote só de Dart não pode depender dele diretamente, por causa dessa dependência do SDK.

**Traduções.** O motor rotula o que produz com uma função que você passa (`Translate`, `String Function(String key)`): o
dimensionador a usa para os nomes que dá (fontes de água, pivôs, a vazão de sistema automática, algumas linhas da lista
de materiais), e as tabelas de relatório e os exportadores rotulam suas colunas com ela. A tabela de textos do aplicativo,
`lib/app/i18n.dart` (`I18n('pt')`, `I18n('en')`, …), também é Dart puro, sem Flutter, e o worker de cálculo e a linha de
comando a usam; os 17 idiomas além de português, inglês e espanhol vêm dos pacotes `assets/i18n/<código>.json`
(`installLanguagePack`). Sem função de rótulo, as próprias chaves aparecem.

**A linha de comando.** `dart run bin/oci.dart --help` lista os comandos: `design`, `analyze`, `check` (código de saída 1
quando há erros), `validate` (o que a leitura do arquivo teve de reparar; código de saída 1 quando houve algo), `export`
(DXF, DWG, PDF, SVG, KML/KMZ, GeoJSON, shapefile, GPX, LandXML, IFC, INP do EPANET), `bom` e `schema` (o JSON Schema
do arquivo de projeto, gerado do modelo: cada chave, seu tipo, sua unidade e o padrão de um projeto novo), com as opções
`--lang`, `--report`, `--results` e `--out`. `design --out` grava o projeto dimensionado com os resultados, como o aplicativo salva
(`--no-results` os deixa de fora).

## 2. Projetos e o dimensionamento

### Abrir, dimensionar, ler os resultados, salvar

Um projeto é o arquivo `.oci.json` que o aplicativo salva: `Project.fromJsonString` o lê, `toJsonString` o grava.
`Designer` monta o modelo hidráulico a partir do desenho; `designAll()` dimensiona os tubos dimensionados pelo computador
(zonas, depois a linha principal, telescopando onde compensa) e analisa tudo, exatamente como o F5 no aplicativo. Ele
altera o projeto (diâmetros dos tubos, tubos divididos pelo telescopamento) e devolve os `DesignResults`.

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

O motor trabalha em unidades SI (vazão em m³/s, carga em metros de coluna d'água); `project.params.units` converte para as
unidades que o usuário escolheu (`Units.metric` mostra L/h e m.c.a., `Units.us` gpm e psi) e `fmt` formata um número para
exibição.

O que `DesignResults` contém:

| Campo | O quê |
|---|---|
| `zones` | `ZoneResult` por id de válvula: vazão, pressões (`requiredUpstreamHead`, `minOutletPressure`, `maxOutletPressure`, a faixa admissível), `uniformity` (CU, DU, EU), cada trecho de tubo (`pipes`), emissor (`outlets`) e dispositivo, `warnings` |
| `systemFlows` | `SystemFlowResult` por turno de operação: exigências das fontes (`supplies`), pressões nas válvulas (`valves`, `maxDeficit`), tubos e dispositivos da linha principal, custo de energia |
| `pivots`, `mechanised` | pivôs centrais e lineares: hidráulica, pacote de emissores, percentímetro, braço de canto, taxa variável, parte elétrica |
| `bom`, `bomByZone` | lista de materiais (`BomLine`: categoria, descrição, quantidade, custo unitário, código, fornecedor), também separada por zona |
| `flushing`, `surge`, `electrical` | lavagem das fitas, verificação de golpe de aríete de cada tubo, fiação das válvulas |
| `messages`, `unconnected` | códigos das mensagens gerais do projeto e os itens não ligados à rede |
| `capitalCost`, `annualCapitalCost`, `annualEnergyCost` | custos na moeda do projeto |

`results.pipesByEntity` e `results.outletsByEntity` indexam os resultados dos tubos e dos emissores pelo id da entidade.

### Arquivos danificados e de outras versões

O leitor abre o arquivo item a item. Um item que ele não consegue ler (danificado, ou de uma versão mais nova do aplicativo)
fica de lado em `project.unreadable` e é gravado de novo ao salvar, em `unreadable`, para que uma versão posterior o
recupere; vértices sem coordenadas são descartados, uma cota desconhecida nunca vira 0 m, ids de entidade repetidos ou
ausentes recebem novos, opções desconhecidas ficam no padrão e campos desconhecidos são preservados. `readProjectFile`
devolve o projeto, os resultados que o arquivo guarda ao lado dele e um `ProjectReadReport` dos reparos (`notes`: códigos
que o aplicativo traduz como `read.<código>`). O formato tem uma `version` (`Project.formatVersion`, 2); arquivos mais
antigos passam pelas `Project.migrations`, e uma chave ausente recebe o valor de um projeto novo.

```dart
final file = readProjectFile(File('examples/en/garden.oci.json').readAsStringSync());
final report = file.report;
for (final note in report.notes) {
  print('${note.code} ${note.args}');
}
print('${file.project.entities.length} entities, ${report.skippedCount} set aside, clean: ${report.clean}');
```

### Só a análise, o progresso, os resultados em JSON

`analyzeAll()` analisa o desenho como está, sem dimensionar nada. `designAllAsync` executa os mesmos passos de
`designAll` e cede a vez entre eles, informando a etapa (zonas, linha principal, divisões, lavagem, golpe de aríete, lista
de materiais): é assim que o aplicativo mostra o cartão de progresso. Os resultados viajam como JSON (`toJson` /
`fromJson`), que é como o worker de cálculo os entrega à interface.

```dart
final analysis = Designer(project).analyzeAll();
final designer = Designer(project);
final results = await designer.designAllAsync(onProgress: (p) => print('${p.stage.name} ${p.done}/${p.total}'));
final json = jsonEncode(results.toJson());
final again = DesignResults.fromJson(jsonDecode(json) as Map<String, dynamic>);
```

### Um projeto montado em código

As entidades são objetos simples acrescentados a `project.entities`; `project.newId()` fornece os ids. O gerador de blocos
traça laterais, linha de derivação e válvula da zona sobre um polígono; um tubo da linha principal e uma fonte de água
completam a rede. Tubos sem diâmetro (`pipeSpecId` nulo) são dimensionados pelo dimensionador.

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

Os principais tipos de entidade: desenho (`LineEntity`, `PolylineEntity`, `CircleEntity`, `ArcEntity`, `SplineEntity`,
`TextEntity`, cotas, `HatchEntity`), terreno (`ContourEntity`, `SpotHeightEntity`, `BreaklineEntity`), hidráulica
(`WaterSupplyEntity`, `PumpEntity`, `PipeEntity` com `scope` de zona ou de linha principal, `ControlValveEntity`,
`SpraylineEntity` e `TapeEntity` para as laterais, `OutletEntity`, `MiscHydraulicEntity` para filtros, hidrômetros e
outros dispositivos, `JunctionEntity`), áreas (`AreaEntity`, com os dados da cultura), máquinas (`PivotEntity`) e
fiação (`ControllerEntity`, `WireEntity`).

### O catálogo

`Catalog.defaultCatalog()` é o catálogo embutido (tubos, emissores com seus bocais, fitas gotejadoras, válvulas, bombas,
conexões, fios); cada projeto leva sua própria cópia em `project.catalog`, e as entidades se referem a ela pelo id. Os
pacotes de fabricantes (`catalogs/*.oci.cat`) são lidos com `CatalogIo.parsePack` (`lib/core/io/catalog_io.dart`).

```dart
final catalog = Catalog.defaultCatalog();
final pipe = catalog.pipe('pvc50')!;
print('${pipe.name}: inner ${pipe.innerDiameterMm} mm, rated ${pipe.pressureRatingM} m, ${pipe.costPerM}/m');
final rotor = catalog.outlet('rotor')!;
for (final nozzle in rotor.nozzles.take(3)) {
  print('${nozzle.id}: ${fmt(nozzle.curve.flow(30) * 3600, 2)} m³/h at 30 m');
}
```

`catalogPlausibility` (`lib/core/model/catalog_check.dart`) acusa valores lidos errado de uma ficha técnica: parede de tubo
termoplástico fina demais para a classe de pressão (a tensão na parede contra a tensão de projeto do material), bocal que
passa mais do que um orifício ideal do seu diâmetro, curva de bomba que pede mais do que o motor dá com o fator de serviço.
O catálogo padrão e todos os pacotes passam nela.

```dart
final problems = catalogPlausibility(Catalog.defaultCatalog());
print(problems.isEmpty ? 'plausible' : problems.join('\n'));
```

## 3. Mensagens, relatórios e exportações

### Verificação do projeto e o assistente de projeto

`runDesignCheck` varre o desenho atrás do que faz um dimensionamento falhar antes de rodar (itens desconectados, pontas
soltas, tubos que se cruzam sem junção, zonas sem emissores, dados de catálogo faltando…). `buildAdvice` junta isso à
verificação dos parâmetros e, quando recebe, às mensagens dos resultados, e dá a cada problema seu código de explicação
(`adv.<código>.why`, `adv.<código>.how` na tabela de textos) e as correções que se aplicam (`fixes`, aplicadas por
`applyFix` em `design/auto_fix.dart`).

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

Os avisos nos resultados são códigos como `velocity_exceeded:e12` (chave da mensagem `warn.velocity_exceeded`, depois os
ids dos itens); `I18n.warning` transforma um deles em texto.

### Tabelas de relatório e exportações

`ProjectExporter` é o código de exportação do aplicativo: tabelas de relatório (`reportTables()`, as mesmas do painel de
Relatórios) e todos os formatos de desenho e de relatório. Os formatos de texto voltam como `String`, os binários como
`Uint8List`.

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

- `DrawingFormat`: `dxf`, `dwg` (AutoCAD 2000), `pdf` (prancha plotada), `svg`, `kml`, `kmz`, `geojson`, `shp`
  (shapefiles num zip), `gpx`, `landxml`, `ifc` (IFC4) e `inp` (EPANET). KML, KMZ, GeoJSON e GPX precisam de
  georreferência (`project.meta.georef`; `GeoReference.fromLatLonOrigin` põe a origem do desenho numa posição WGS84) e
  lançam `GeoReferenceMissing` sem ela.
- `ReportFormat`: `csv` (separado por ponto e vírgula), `txt`, `xlsx` e `pdf`. `reportTablesToCsv` e `reportTablesToText`
  formatam qualquer lista de tabelas; cada tabela tem uma `key` estável (`zones`, `pipes`, `outlets`, `mainline`, `bom`,
  `messages`…).
- Texto de PDF além do Latin-1 (árabe, escritas indianas, chinês, japonês) precisa das fontes Noto incluídas registradas
  em `PdfFonts.shared` (`BundledFonts.all` dá os nomes dos arquivos de `assets/fonts`); `bin/oci.dart` mostra como.

## 4. O solver hidráulico

`HydraulicNetwork` é o solver de regime permanente por trás de toda análise: o Algoritmo do Gradiente Global (Todini e
Pilati, 1988, o método do EPANET) com emissores dependentes da pressão, bombas, válvulas redutoras e sustentadoras de
pressão, válvulas controladoras de vazão e válvulas de retenção. Os nós (`HNode`) são junções ou reservatórios de carga
fixa; os trechos (`HLink`) são tubos, bombas, válvulas ou dispositivos com curva de perda. As unidades são SI: vazão m³/s,
carga e cota m, diâmetro m.

### Uma rede de tubos com emissores

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

`solve()` devolve um `NetworkResult`: `nodes` (`NodeResult`: `head`, `pressure`, `demand`, `emitterFlow`), `links`
(`LinkResult`: `flow`, `velocity`, `headLoss`, `status`, `pumpHead`), `converged`, `iterations` e `warnings`. Um nó com
emissor descarrega `emitterCount` vezes q = k·Hˣ na sua pressão (mais `emitterOffset`, a haste); `demand` é uma vazão de
saída fixa (negativa para uma entrada).

### Bombas, válvulas redutoras de pressão e válvulas de retenção

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

`NetworkOptions` escolhe a lei de perda de carga (`FrictionMethod.hazenWilliams`, `darcyWeisbach`, `scobey`, `manning`), a
viscosidade da água e as tolerâncias de convergência; cada trecho leva seu próprio coeficiente (`hazenC`, `roughness` em m,
`scobeyKs`, `manningN`) e perda localizada (`minorK`). Tipos de trecho: `pipe`, `pump` (`PumpCurve`, H = a·Q² + b·Q + c,
com razão de rotação), `prv` e `psv` (`prvSetting`, m), `fcv` (`fcvFlow`, m³/s), `device` (`DeviceLossCurve`,
h = K·Qⁿ + C) e `closed`.

### Perda de carga, emissores e curvas de bomba

As fórmulas também estão disponíveis sozinhas:

```dart
final hf = hazenWilliamsLoss(flow: 0.003, diameter: 0.06, length: 80, c: 140);
final dw = darcyWeisbachLoss(flow: 0.003, diameter: 0.06, length: 80, roughness: 1.5e-6);
final dripper = EmitterCurve.fromNominal(flow: 2 / 3.6e6, head: 10, x: 0.5);
final pump = PumpCurve.fit([(0, 50), (0.01, 45), (0.02, 30)]);
final duty = operatingPoint(pump, const SystemCurve(staticHead: 20, k: 30000));
```

Também em `lib/core/hydraulics`: `lateral.dart` (análise da lateral passo a passo), `minor_losses.dart`, `uniformity.dart`
(CU, DU, EU) e `water_hammer.dart` (celeridade, sobrepressão de Joukowsky, tempo crítico de fechamento).

## 5. Módulos mais novos

### Golpe de aríete (método das características)

`TransientModel` recebe uma rede resolvida e simula eventos sobre ela (fechamentos e aberturas de válvulas, desligamento
de bombas, interrupção de demandas) pelo método das características, com separação de coluna, ventosas e reservatórios
hidropneumáticos. O resultado dá as envoltórias de carga de cada nó e tubo e as séries no tempo dos pontos pedidos.

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

As pressões nos resultados são cargas manométricas (m); `TransientOptions.vapourHead` e `barometricHead` são absolutas. As
celeridades dos tubos vêm de `TransientLinkData.fromPipe` (diâmetro, espessura da parede, material) ou são dadas
diretamente.

### Transientes, simulação de 24 horas e ventosas num projeto

`design/transient_analysis.dart` monta essas simulações a partir de um projeto: `TransientStudy` (fechamento de válvula,
desligamento de bomba, fechamento de um registro, por vazão de sistema), `simulateDay` (o dia de operação das vazões de
sistema como simulação de período estendido, com energia e custo) e `suggestMainlineAirValves` (ventosas ao longo da linha
principal, conforme a prática do AWWA M51, opcionalmente usando as pressões mínimas dos transientes).

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

### Simulação de período estendido

`simulateEps` avança uma rede no tempo (o esquema do EPANET): reservatórios de nível variável, horários dos trechos,
controles pelo nível ou pelo relógio, padrões de demanda, energia das bombas e tarifas. Trabalha sobre uma cópia da rede.

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

### Ventosas ao longo de um perfil

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

### Automação do traçado

Aspersores sobre um gramado (`layoutLandscape`, com aspersores de canto, de borda e setoriais e a uniformidade
resultante), zonas por vazão (`zoneByFlow`), válvulas e rotas dos tubos (`routeZones`), e depois as entidades de um
projeto, prontas para dimensionar:

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

Para campos esportivos e golfe, `templates.dart` tem `sportsPitchLayout`, `golfGreenLayout`, `fairwayLayout`,
`teeLayout` e `runningTrackInfieldLayout`. Para fazendas, `subdivideField` divide um talhão em blocos que `blockOptionsFor`
transforma em opções do gerador de blocos, e `fitFullCirclePivot` / `fitSectorPivot` posicionam o maior pivô que cabe na
área:

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

### Estações valve-in-head

Um aspersor desenhado na linha principal (um `OutletEntity` com `scope: HydraulicScope.mainline`) tem a válvula no
próprio corpo. `VihStations.of(project)` agrupa esses aspersores em estações (`design/valve_in_head.dart`): um aspersor sem
nome de zona é uma estação sozinho, com o id dele, e os que têm o mesmo nome de zona formam a estação `vih:<nome>`, com os
solenoides em paralelo numa só estação do controlador. Uma vazão de sistema programa uma estação listando o id dela em
`valveIds`, ao lado das válvulas de zona e dos pivôs: a estação programada só funciona nas vazões que a listam, e o
dimensionamento dá aos seus aspersores a pressão nominal ali, como dá a uma válvula de zona a pressão de que a zona
precisa. Uma estação que nenhuma vazão lista funciona em todas e não influi na pressão da fonte, como as saídas da linha
principal se comportavam antes de poderem ser programadas.

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

`SystemFlowResult.heads` traz um `VihDuty` para cada estação que funciona na vazão: aspersores, vazão, a menor e a maior
pressão nos bocais, o aspersor crítico e o que ele precisa no seu nó da linha principal (pressão nominal mais a haste,
31 m aqui) contra o que recebe (`deficit`). As estações também passam pela fiação das válvulas e pelo projeto de dois fios
(uma estação cada, os solenoides dos aspersores em paralelo), pela simulação de 24 horas, pelos transientes (os aspersores
fecham com as válvulas de zona da vazão), pelo agrupamento por energia, pelo programa do controlador, pela fertirrigação e
pela exportação para o EPANET de cada vazão.

### Frequência da rede elétrica e bombas de rotação variável

Uma bomba do catálogo pode dizer em que frequência a sua curva foi levantada (`PumpSpec.ratedHz`, `hz` nos pacotes), e
`DesignParameters.mainsHz` (50 ou 60) é a frequência do local. Um motor de rotação fixa gira então a `mainsHz / ratedHz`
da rotação da curva, que as leis de afinidade escalam (H(Q) = ω²·H₀(Q/ω)): uma curva de 60 Hz numa rede de 50 Hz roda a
5/6 da rotação e dá 69 % da altura. Uma bomba com pressão de saída alvo (`PumpEntity.targetPressureM`, entre
`minSpeedRatio` e o seu `speedRatio`) tem inversor de frequência: o dimensionador ajusta a rotação em cada vazão de
sistema, e a frequência da rede não a reduz. `rankPumps` lê todas as curvas na rotação da rede, e
`TransientStudyOptions.speedForPoles` dá a rotação de trabalho do motor para o desligamento da bomba (a rotação síncrona
menos cerca de 3 % de escorregamento).

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

Uma bomba também pode trazer uma curva de rendimento (`efficiencyPoints`) e uma de NPSH requerido (`npshPoints`):
`efficiencyAt(q, speed:)` lê o rendimento na vazão homóloga q/ω, `npshrAt(q, speed:)` escala o NPSH requerido por ω², e o
dimensionamento o compara com `npshAvailable` (`pump_npsh` quando falta a margem de 0,6 m).

### Vegetação em imagens aéreas

`design/vegetation.dart` encontra gramados, árvores e arbustos numa imagem aérea no próprio dispositivo, sem serviço
externo: um `VegetationImage` guarda a grade de trabalho de uma imagem posicionada pelos seus quatro cantos no mundo
(inferior esquerdo, inferior direito, superior direito, superior esquerdo) com o índice de excesso de verde de cada pixel e
o limiar de Otsu, `detectVegetation` devolve as manchas com os seus buracos e `vegetationEntities` as transforma em áreas
irrigadas (com valores agronômicos iniciais por classe) e contornos de exclusão. `VegetationImage.fromEncoded` decodifica
um PNG ou JPEG em vez de pixels brutos. Aqui, uma vista sintética de 40 × 30 m com 10 cm por pixel: um gramado sobre
pavimento com um pátio redondo no meio.

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

`VegetationOptions` guarda os ajustes do usuário (deslocamento do limiar, a separação entre gramado e árvores e o seu viés,
áreas mínimas das manchas e dos buracos, tolerância da simplificação, raios da limpeza); um mesmo `VegetationImage` serve
a quantas execuções forem precisas. O resultado também traz avisos (`messages`: poucos pixels de vegetação, pouco
contraste, manchas cortadas pela borda da vista) e a classe de cada pixel da grade para uma prévia (`vegetationPreview`).

### Agronomia

Evapotranspiração de referência por Penman-Monteith FAO-56 (`fao56Eto`, com as estimativas da FAO-56 para dados
faltantes, e `fao56MonthlySeries`) ou Hargreaves, coeficientes de cultura (`KcCurve`, a tabela de culturas da FAO-56
`fao56Crops`), solos (`soilOf`, texturas USDA), a necessidade de irrigação mês a mês (`irrigationRequirement`: chuva
efetiva, irrigação localizada, lixiviação, turnos de rega, volumes e a vazão de pico), orçamentos de água de paisagismo
(`mweloWaterBudget`), ciclo e infiltração, o bulbo molhado dos gotejadores, bombeamento solar (`sizeSolarPumping`) e
fertirrigação (`fertigationTravel`, `planFertigation`).

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

### Máquinas mecanizadas

`analyzeMechanised` dimensiona o pacote de emissores de um pivô central ou linear (bocal por bocal, com reguladores,
pendurais, canhão final e bomba auxiliar), o seu percentímetro e, quando a máquina está configurada para isso
(`PivotMachine`), o braço de canto, a prescrição de taxa variável e a alimentação elétrica; o dimensionador o executa para
cada pivô do projeto. As partes também estão disponíveis sozinhas (`designPivotPackage`, `analyzeCornerArm`,
`vriFromZones`, `vriFromSectors`, `designPivotElectrical`), assim como os carretéis com canhão (`analyzeTraveller`).

```dart
final project = Project();
final pivot = PivotEntity(id: project.newId(), center: const Pt(0, 0), radiusM: 400, name: 'Pivot 1', machine: PivotMachine(towerSpeedMPerMin: 3));
project.entities.add(pivot);
final machine = analyzeMechanised(project, pivot);
final package = machine.package;
final gun = analyzeTraveller(const TravellerSpec(gunFlow: 30 / 3600, gunPressureM: 45, wettedDiameterM: 90, hoseLengthM: 350, hoseInnerMm: 90, speedMPerMin: 0.5));
```

### Formatos de arquivo

Os leitores transformam arquivos num `DxfDocument` (camadas e entidades simples, em metros locais) ou num objeto de
resultado em volta de um, muitas vezes com georreferência; os gravadores transformam um projeto (ou um `DxfDocument`) em
texto ou bytes.

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

| Formato | Leitura | Gravação |
|---|---|---|
| DXF | `DxfReader.parse(String)` | `DxfR2000Writer.write(CadDrawing)` (AutoCAD 2000), `DxfWriter.write(DxfDocument)` (R12) |
| DWG (R13 a 2018 / 2000) | `DwgReader.parse(Uint8List)` | `DwgWriter.writeDrawing(CadDrawing)`, `DwgWriter.write(DxfDocument)` |
| PDF | `PdfReader.open(Uint8List)` → `readPage`, `pdfPageEntities` / `addPdfPage` | pranchas pelo `ProjectExporter` |
| DGN V7 | `DgnReader.parse(Uint8List)` | |
| KML / KMZ | `KmlReader.parse`, `KmlReader.parseKmz` | pelo `ProjectExporter` |
| GeoJSON | `GeoJsonReader.parse(String)` | pelo `ProjectExporter` |
| Shapefile | `ShpReader.parse` (.shp + .dbf + .prj), `ShpReader.parseAny` (zip) | `ShapefileWriter(project: …).zip()` |
| GPX | `GpxReader.parse(String)` | `GpxWriter.write(project)` |
| LandXML | `LandXmlReader.parse(String)` | `LandXmlWriter.write(project)` |
| IFC4 | | `IfcWriter.write(project)` |
| INP do EPANET | `EpanetInpReader.parse(String)` → `toNetwork()`, `toDocument()` | `EpanetWriter.write(project)` |
| Nuvens de pontos LAS | `LasReader.read(Uint8List)` | |
| Elevação em GeoTIFF | `GeoTiffDemReader.read(Uint8List)` | |
| Pontos de levantamento CSV / XYZ | `PointsCsvReader.parse(String)` | |
| Sistemas de coordenadas | `parseCrs` (WKT, `EPSG:n`), `crsFromEpsg`, `GeoPlacement.plan`, conversão de datum (`datumToWgs84`) | |

### Plantas em PDF como fundo

`PdfReader.open` lê um PDF (tabelas de referência cruzada clássicas e em fluxo, fluxos de objetos, atualizações
incrementais; uma tabela danificada é reconstruída, um arquivo criptografado é recusado com `pdf_encrypted`) e `readPage`
interpreta uma página em caminhos, textos e imagens em pontos da página (1/72 de polegada, origem no canto inferior
esquerdo da área de corte, com a rotação da página aplicada), com as camadas do PDF a que pertencem. `pdfScaleOnSheet`
procura uma escala escrita na prancha (`Scale 1:500`, `ESCALA 1:200`, um `1:250` sozinho); `pdfPageEntities` e
`addPdfPage` colocam a página no desenho numa escala de papel (`PdfImportOptions.atScale`), ou num fator para uma planta
cujas unidades são metros (`metresPerUnit`), em camadas próprias. As ferramentas de alinhamento por dois pontos e de
georreferência ajustam depois a planta a pontos conhecidos. Aqui o PDF é uma prancha gravada pelo exportador; o carimbo
dela traz a escala separada do rótulo, por isso a escala é informada.

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

`readPage` aceita `vectors`, `texts` e `images` para ler só parte de uma página (decodificar as imagens de uma digitalização
é o que mais demora) e para em `pdfMaxSegments` segmentos de caminho (`pdf_truncated`). `PdfImportOptions` também escolhe
as camadas (uma por camada do PDF e, opcionalmente, uma por cor) e se entram as camadas do PDF que estão desligadas.

### Desenho CAD nativo (DXF 2000 e DWG)

As exportações DXF e DWG partilham um único desenho nativo, `CadDrawing` (`io/cad_drawing.dart`): camadas com índice de
cor, cor verdadeira e tipo de linha, estilos de cota, definições de bloco com definições de atributo, e as entidades que
os programas de CAD editam como tais (polilinhas leves com arcos, splines, hachuras, texto multilinha, cotas com os seus
blocos anônimos, chamadas, referências de bloco com atributos). `CadExport(project).build()` o monta a partir de um projeto
(é o `cadDrawing()` do exportador), `DxfR2000Writer.write` o grava como DXF do AutoCAD 2000 (AC1015) e
`DwgWriter.writeDrawing` como DWG do AutoCAD 2000. Símbolos e itens hidráulicos são referências a pequenos blocos cujos
atributos levam o nome, o item do catálogo, o bocal, a zona e as estações. `DrawingFormat.dxfR12` mantém as primitivas do
R12 para programas mais antigos.

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

### Os clientes e o laço de agente do assistente de IA

`ai/llm.dart` reúne o que o assistente precisa de qualquer provedor de modelos: os modelos oferecidos (`AiModel`, com
provedor, nível e preços de lista), os tokens e o seu custo estimado (`AiUsage`), os erros (`AiError`), o cancelamento
(`AiCancel`) e a troca HTTP como uma função (`AiTransport`: o aplicativo usa fetch no navegador e `HttpClient` no desktop,
`lib/app/ai/ai_transport_*.dart`). Dois clientes implementam `AiClient`: `AnthropicClient` (`ai/claude_api.dart`, a API
Messages da Anthropic) e `OpenAiClient` (`ai/openai_api.dart`, a API Responses da OpenAI); `ai/llm_formats.dart` reúne os
dois formatos num só lugar. `apiKey` é a chave do próprio usuário para aquele provedor, que vai no seu cabeçalho para a API
dele (`api.anthropic.com` ou `api.openai.com`) e para nenhum outro lugar. `ai/agent_loop.dart` é o laço em que o modelo
chama ferramentas até encerrar a sua vez, o mesmo para os dois provedores. Uma ferramenta (`AgentTool`, ou `FnTool` feita
de funções) tem nome, descrição, um esquema JSON contra o qual a entrada é conferida antes de rodar, e um efeito (leitura,
alteração, exportação ou rede) que o modo de permissão governa (`AgentPermission.readOnly`, `plan`, `ask` com o callback
`approve` de `AgentEvents`, `auto`). `buildProjectContext` escreve os dados compactos do projeto que o aplicativo anexa a
uma pergunta, a partir das tabelas de relatório e das mensagens do dimensionamento, limitados a cerca de 18 000
caracteres. Uma conversa de verdade consome tokens cobrados da conta da chave; o teste roda este trecho para cada provedor
contra um transporte roteirizado.

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

`turn.messages` é o que entra no histórico da conversa para a próxima pergunta, no formato do próprio provedor (a
pergunta, as respostas do modelo exatamente como vieram — blocos de raciocínio da Anthropic, itens de raciocínio
cifrados da OpenAI — e um resultado para cada chamada de ferramenta); `turn.stop` diz por que a vez terminou (`done`,
`maxTokens`, `stepLimit` depois de `maxSteps` requisições, `budget` passado o `costCap`, `cancelled` por um `AiCancel`,
`error` com um `AiError`). `AiClient.send` sozinho faz uma requisição em fluxo, com novas tentativas em sobrecarga, limite
de taxa, erro de servidor, erro de rede, tempo esgotado e fluxo interrompido (enquanto nada da resposta foi mostrado). Os nomes da primeira versão, só da Anthropic (`ClaudeApi`, `ClaudeModel`, `ClaudeCancel`…),
continuam como apelidos.

## 6. Convenções

- **Unidades**: SI dentro do motor: comprimentos e cotas em m, vazão em m³/s, carga e pressão em metros de coluna d'água
  (manométrica), diâmetros em m (os campos do catálogo terminados em `Mm` estão em milímetros), tempo em s ou h conforme o
  nome. `lib/core/units.dart` tem as conversões (`m3sPerLph`, `m3sPerM3h`, `m3sPerGpm`, `psiPerMeterHead`…) e `Units` as
  unidades de exibição de um projeto.
- **Mensagens são códigos**: `código` ou `código:argumento` (geralmente o id de uma entidade). O aplicativo as traduz com a
  tabela de textos: `check.<código>`, `warn.<código>`, `adv.<código>.why` e `adv.<código>.how`.
- **Determinismo**: o mesmo projeto dá os mesmos resultados; além dos pacotes de idioma instalados e das fontes de PDF
  registradas, o motor não guarda estado global que os altere (o maior terreno que o TIN aceita inteiro, por exemplo, é o
  `tinLimit` de cada `Terrain`, por padrão `Terrain.maxTinPoints`).
- **Alterações**: `Designer.designAll` altera o projeto que dimensiona (diâmetros, tubos telescopados divididos); trabalhe
  sobre `project.copy()` para manter o original. Os leitores nunca alteram o que recebem.
- **Estabilidade**: esta API é o motor do aplicativo, não uma interface congelada. Ela acompanha as necessidades do
  aplicativo; os testes em `test/core` são a referência de cada módulo.
