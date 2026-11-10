# O servidor MCP do OpenCADIrrigation

*English: [MCP.md](MCP.md)*

`dart run bin/oci.dart mcp --root <pasta>` inicia um servidor do [Model Context Protocol](https://modelcontextprotocol.io):
qualquer aplicativo de IA que fale MCP (um "cliente MCP") passa a projetar sistemas de irrigação pressurizada com o motor
do OpenCADIrrigation, no seu próprio computador. O modelo lê e grava projetos numa pasta escolhida por você, faz um
projeto a partir de um desenho ou de um levantamento, desenha e altera os itens, dimensiona as tubulações, analisa os
setores, a linha principal e os pivôs, lê as mensagens do assistente de projeto com as explicações, a lista de materiais
e qualquer tabela do relatório, e exporta desenhos (DXF, DWG, PDF, SVG, KML, GeoJSON, shapefiles, LandXML, IFC, EPANET) e
relatórios (CSV, TXT, XLSX, PDF). Nada vai para a internet, nada acontece fora daquela pasta e não é preciso conta.

O servidor usa o próprio motor da linha de comando (`bin/oci.dart`, as mesmas funções de `design`, `check`, `export`,
`bom`, `new`, `import`, `set` e `pack add`): um resultado obtido pelo MCP é o resultado do aplicativo e da linha de comando.

## Sumário

1. [Como iniciar o servidor](#1-como-iniciar-o-servidor)
2. [Como configurar um cliente MCP](#2-como-configurar-um-cliente-mcp)
3. [O protocolo](#3-o-protocolo)
4. [As ferramentas](#4-as-ferramentas)
5. [Recursos e prompts](#5-recursos-e-prompts)
6. [Segurança](#6-segurança)
7. [Limites](#7-limites)
8. [Para quem desenvolve](#8-para-quem-desenvolve)

## 1. Como iniciar o servidor

É preciso uma cópia deste repositório com os pacotes instalados (`flutter pub get`, veja o
[CONTRIBUTING.md](../CONTRIBUTING.md)) ou o pacote do motor sem Flutter (`dart tool/engine_package.dart build/engine` e,
dentro dele, `dart pub get`; esse pacote não traz os projetos de exemplo). Depois:

```sh
dart run bin/oci.dart mcp --root ~/projetos-irrigacao
dart run bin/oci.dart mcp --root ~/projetos-irrigacao --read-only --lang pt
```

| Opção | O que faz |
|---|---|
| `--root <pasta>` | A pasta que o aplicativo de IA pode ler e gravar (obrigatória). Todo caminho de toda ferramenta fica dentro dela. |
| `--read-only` | Só as ferramentas que leem, analisam, verificam e relatam: nenhuma grava arquivo. |
| `--lang <código>` | Idioma dos nomes, relatórios e mensagens (padrão `en`; qualquer um dos 20 idiomas do aplicativo). |

O servidor lê mensagens JSON-RPC na entrada padrão e escreve as respostas na saída padrão, uma mensagem por linha; o que
ele tem a dizer para pessoas (a linha de início, um pedido cancelado, um erro) vai para a saída de erro. Ele para quando
a entrada fecha: as chamadas ainda em andamento têm dez segundos para responder e as demais são interrompidas.
`dart run bin/oci.dart --help` também lista as opções.

## 2. Como configurar um cliente MCP

Um cliente MCP inicia o servidor como um programa à parte e conversa com ele pela entrada e pela saída padrão. A maioria
dos clientes recebe o comando, os argumentos e, se quiser, variáveis de ambiente num arquivo JSON das configurações; o
nome do arquivo e das chaves depende do cliente (veja a documentação dele). Uma entrada típica:

```json
{
  "mcpServers": {
    "opencadirrigation": {
      "command": "/caminho/do/flutter/bin/dart",
      "args": ["run", "/caminho/do/opencadirrigation/bin/oci.dart", "mcp", "--root", "/caminho/dos/projetos-irrigacao", "--lang", "pt"]
    }
  }
}
```

Use caminhos absolutos: o cliente pode iniciar o servidor a partir de qualquer pasta. Acrescente `"--read-only"` aos
argumentos para um servidor que só consulta. A primeira execução compila o programa (alguns segundos); as seguintes são
rápidas.

## 3. O protocolo

O servidor implementa a revisão atual da especificação, **2026-07-28**, e as revisões com handshake **2025-11-25** e
**2025-06-18**, no mesmo processo:

- **2026-07-28 (sem estado).** Todo pedido traz `_meta["io.modelcontextprotocol/protocolVersion"]` e
  `_meta["io.modelcontextprotocol/clientCapabilities"]`; todo resultado traz `resultType: "complete"` e
  `_meta["io.modelcontextprotocol/serverInfo"]`; listas e leituras trazem `ttlMs` e `cacheScope`. `server/discover`
  informa as revisões, as capacidades (ferramentas, recursos, prompts) e as instruções para o modelo. Um pedido de uma
  revisão que o servidor não fala recebe o erro `-32022` com as que ele fala; um pedido sem os campos obrigatórios de
  `_meta` recebe `-32602`.
- **2025-11-25 e 2025-06-18 (handshake).** `initialize` combina a revisão (a pedida, ou 2025-11-25 para qualquer outra);
  depois `notifications/initialized`, `ping` e os pedidos abaixo funcionam sem `_meta`, com os formatos de resultado
  daquela revisão.

Métodos: `server/discover`, `initialize`, `ping`, `tools/list`, `tools/call`, `resources/list`, `resources/read`,
`resources/templates/list` (vazio), `prompts/list`, `prompts/get` e `subscriptions/listen` (confirmado sem nenhum tipo de
notificação: as ferramentas, os recursos e os prompts não mudam enquanto o servidor roda). Notificações:
`notifications/initialized` e `notifications/cancelled`.

- **Erros.** Não é JSON: `-32700`; um lote, um pedido sem `jsonrpc: "2.0"`, sem método ou com id nulo: `-32600`; um
  método desconhecido: `-32601`; parâmetros errados, uma ferramenta desconhecida, um cursor desconhecido: `-32602`.
  Argumentos fora do esquema de entrada de uma ferramenta são um erro *da ferramenta* (`isError: true`), cujo texto lista
  todos os problemas para o modelo corrigir; o mesmo vale para uma ferramenta que falha (um arquivo que não existe, um
  projeto sem nada para dimensionar).
- **Cancelamento.** `notifications/cancelled` com o id do pedido interrompe a chamada: cada chamada de ferramenta roda num
  isolate próprio, que é encerrado, e nenhuma resposta é enviada.
- **Progresso.** Uma chamada com `_meta.progressToken` recebe `notifications/progress` a cada cinco segundos enquanto
  roda (a contagem e os segundos decorridos), para que o cliente mantenha vivo um dimensionamento longo.
- **Tempo máximo.** Uma chamada que passa de 15 minutos é interrompida com um erro da ferramenta.
- **Concorrência.** Ferramentas que só leem rodam lado a lado; uma que grava roda sozinha, na ordem em que as chamadas
  chegaram.
- **Esquemas.** Os esquemas de entrada e de saída são JSON Schema 2020-12, sem `$ref`; os argumentos são validados antes de
  a ferramenta rodar.

## 4. As ferramentas

Todo caminho é relativo à pasta raiz (`"campo.oci.json"`, `"plantas/area.dxf"`); um caminho absoluto é aceito quando fica
dentro dela. Dentro de um arquivo de projeto tudo está no SI (coordenadas e comprimentos em metros, vazões em m³/s,
pressões como carga em metros de coluna d'água); as tabelas de resultado usam as unidades de exibição do projeto,
indicadas nos cabeçalhos. Todo resultado é um objeto JSON (`structuredContent`, também serializado no bloco de texto),
descrito pelo esquema de saída da ferramenta.

| Ferramenta | Grava | O que faz |
|---|---|---|
| [`list_files`](#list_files) | | Arquivos sob a raiz, por tipo |
| [`read_project`](#read_project) | | Dados, unidades, georreferência, itens, setores e catálogo de um projeto |
| [`list_entities`](#list_entities) | | Os itens de um projeto, filtrados, uma página por vez |
| [`list_catalog`](#list_catalog) | | Tubos, emissores, fitas, válvulas, bombas, conexões e fios de um projeto |
| [`analyze_project`](#analyze_project) | | Análise hidráulica sem gravar |
| [`check_project`](#check_project) | | Todas as mensagens da verificação e do assistente |
| [`validate_project`](#validate_project) | | O que a leitura do arquivo teve de reparar |
| [`bill_of_materials`](#bill_of_materials) | | A lista de materiais e o custo de implantação |
| [`report_table`](#report_table) | | Qualquer tabela do relatório, em linhas |
| [`project_schema`](#project_schema) | | O JSON Schema do arquivo de projeto, por parte |
| [`list_examples`](#list_examples) | | Os projetos de exemplo que acompanham o programa |
| [`list_catalog_packs`](#list_catalog_packs) | | Os pacotes de catálogo que acompanham o programa |
| [`create_project`](#create_project) | sim | Um projeto novo, com georreferência, área e distribuição de aspersores |
| [`copy_example`](#copy_example) | sim | Um exemplo copiado para a raiz |
| [`import_files`](#import_files) | sim | Um projeto feito de desenhos, mapas e levantamentos |
| [`set_project`](#set_project) | sim | Configurações, dados e parâmetros de projeto |
| [`edit_entities`](#edit_entities) | sim | Itens acrescentados, alterados e apagados |
| [`add_catalog_pack`](#add_catalog_pack) | sim | Pacotes de catálogo acrescentados a um projeto |
| [`design_project`](#design_project) | sim | O dimensionamento (F5), gravado com os resultados |
| [`export_drawing`](#export_drawing) | sim | O desenho em outro formato |
| [`export_report`](#export_report) | sim | As tabelas do relatório em CSV, TXT, XLSX ou PDF |

Toda ferramenta declara suas dicas: as de leitura, `readOnlyHint: true`; as que gravam, `destructiveHint` (verdadeiro quando
podem alterar ou substituir um arquivo: todas menos `create_project` e `copy_example`, que nunca substituem) e
`idempotentHint`; nenhuma acessa a internet (`openWorldHint: false`). Os exemplos abaixo são respostas reais para o exemplo
do jardim, em inglês (abreviadas onde aparece `…`).

### list_files

Arquivos sob a raiz ou uma das pastas dela (`folder`), `recursive` (padrão verdadeiro), de um `kind` (`all`, `projects`,
`importable`, `catalogue_packs`, `other`). Arquivos ocultos ficam de fora.

```json
{"name": "list_files", "arguments": {}}
```
```json
{"folder": ".", "files": [{"path": "garden.oci.json", "kind": "project", "bytes": 146908}], "truncated": false}
```

### read_project

Os dados, as unidades de exibição, a moeda, a frequência da rede, a georreferência, a extensão do desenho (m), os itens
por tipo, os setores (válvulas), as captações, os pivôs, os fluxos do sistema, as camadas com itens, o tamanho do
catálogo e os reparos; `parameters: true` acrescenta os parâmetros de projeto como o arquivo os guarda.

```json
{"name": "read_project", "arguments": {"project": "garden.oci.json"}}
```
```json
{"project": "garden.oci.json", "name": "Residential garden", "client": "Example Residence", "site": "Lot 16 × 40 m",
 "units": {"system": "metric", "length": "m", "flow": "L/h", "pressure": "m.c.a.", "diameter": "mm"},
 "currency": "USD", "mainsHz": 60.0, "georef": null,
 "bounds": {"minX": -6.0, "minY": -8.5, "maxX": 34.64, "maxY": 44.4},
 "entities": {"total": 77, "byType": {"outlet": 24, "pipe": 15, "controlValve": 3, "tape": 6, "…": 0}},
 "zones": [{"id": "e39", "zone": "Zone 1 — sprays"}, {"id": "e55", "zone": "Zone 2 — rotors"}, {"id": "e58", "zone": "Zone 3 — drip"}],
 "supplies": [{"id": "e68", "name": "Mains supply"}], "pivots": [],
 "systemFlows": [{"id": "sf1", "name": "Shift 1 — Zone 1 — sprays", "runs": ["e39"]}, "…"],
 "layers": ["DRAWING", "ZONE_PIPES", "OUTLETS", "…"], "layerCount": 28,
 "catalog": {"pipes": 17, "outlets": 10, "tapes": 6, "valves": 36, "pumps": 18, "fittings": 326, "wires": 12}, "repairs": []}
```

### list_entities

Itens filtrados por `types`, `layer` ou `ids`, uma página por vez (`offset`, `limit`), em tabela; `full: true` dá cada item
como o arquivo de projeto o guarda, pronto para `edit_entities`.

```json
{"name": "list_entities", "arguments": {"project": "garden.oci.json", "types": ["controlValve", "pipe"], "limit": 2}}
```
```json
{"total": 18, "offset": 0, "columns": ["id", "type", "name", "layer", "spec", "x", "y", "length_m", "area_m2", "zone"],
 "rows": [["e35", "pipe", "", "ZONE_PIPES", null, 0.0, 0.0, 16.0, null, null],
          ["e36", "pipe", "", "ZONE_PIPES", null, 0.0, 4.0, 16.0, null, null]]}
```
```json
{"name": "list_entities", "arguments": {"project": "garden.oci.json", "ids": ["e39"], "full": true}}
```
```json
{"total": 1, "offset": 0, "entities": [{"type": "controlValve", "id": "e39", "layer": "CONTROL_VALVES", "name": "Zone 1 — sprays",
 "p": [-1.0, 4.0], "spec": "ev25", "zone": "Zone 1 — sprays", "rot": 0.0, "depth": 0.0}]}
```

### list_catalog

O catálogo de um projeto, um `kind` por vez (`pipes`, `outlets`, `tapes`, `valves`, `pumps`, `fittings`, `wires`), com
`search` e `enabled_only`; os ids são aquilo a que os itens do desenho se referem.

```json
{"name": "list_catalog", "arguments": {"project": "garden.oci.json", "kind": "pipes", "search": "PE", "limit": 1}}
```
```json
{"kind": "pipes", "currency": "USD", "total": 8, "items": [{"id": "pe16", "name": "PE 16 mm (PN 4)", "nominalMm": 16.0,
 "idMm": 13.6, "material": "peld", "c": 140.0, "ratingM": 40.0, "cost": 0.175, "usage": ["lateral"], "enabled": true}]}
```

### analyze_project

A análise hidráulica sem alterar o arquivo (`size_pipes: true` dimensiona as tubulações antes, ainda sem gravar):
setores, fluxos do sistema, pivôs, custo de implantação e as mensagens do assistente.

```json
{"name": "analyze_project", "arguments": {"project": "garden.oci.json"}}
```
```json
{"project": "garden.oci.json", "name": "Residential garden", "sized": false,
 "tables": {"zones": {"title": "Zone summary",
   "headers": ["Zone", "Flow (L/h)", "Required P (m.c.a.)", "Min P (m.c.a.)", "Max P (m.c.a.)", "EU %", "Warnings"],
   "rows": [["Zone 1 — sprays", 4789.6, 23.6, 19.4, 20.6, 93.5, 2], ["Zone 2 — rotors", 2818.8, 26.4, 24.8, 25.3, 95.8, 1], "…"]},
   "flows": {"title": "Mainline / duty", "headers": ["System flow", "Flow (L/h)", "Supply Required P (m.c.a.)", "Warnings"], "rows": ["…"]}},
 "totals": {"capitalCost": 668.42, "currency": "USD", "bomLines": 17},
 "messages": {"errors": 0, "warnings": 3, "notes": 3, "list": [{"level": "warning", "code": "velocity_exceeded",
   "message": "Zone 1 — sprays: Maximum velocity exceeded (pipe e40)", "entities": ["e40"]}, "…"]}}
```

### check_project

Todas as mensagens, como `oci check --json` as dá: nível, código, texto, os itens e, com `explain` (padrão verdadeiro), por
que importa, como corrigir e as correções automáticas que se aplicam. `run`: `design` (padrão), `analyze` ou `none`.

```json
{"name": "check_project", "arguments": {"project": "garden.oci.json"}}
```
```json
{"project": "garden.oci.json", "name": "Residential garden", "designed": true, "errors": 0, "warnings": 0, "notes": 3,
 "messages": [{"level": "info", "code": "valve_pressure_excess", "raw": "valve_pressure_excess",
   "message": "Shift 1 — Zone 1 — sprays: Surplus pressure at a zone valve that does not regulate (Zone 1 — sprays)",
   "context": "Shift 1 — Zone 1 — sprays", "entities": ["e39"],
   "why": "The mainline delivers far more pressure at the valve than the zone needs (more than 5 m and 20 %). …",
   "how": "Use a pressure regulating valve (with a reducing pilot) or set the outlet pressure of the valve, …"}, "…"]}
```

### validate_project

O que a leitura do arquivo teve de reparar (itens deixados de lado, ids renumerados, vértices descartados, valores não
entendidos, um formato mais novo) e os erros da verificação do projeto, como `oci validate --json`.

```json
{"name": "validate_project", "arguments": {"project": "garden.oci.json"}}
```
```json
{"project": "garden.oci.json", "name": "Residential garden", "version": 2, "readsVersion": 2, "newerVersion": false,
 "skipped": {}, "renumbered": 0, "droppedVertices": 0, "unknownValues": [], "repairs": [], "errors": [], "clean": true}
```

### bill_of_materials

A lista de materiais depois do dimensionamento (`size_pipes: false` mantém os diâmetros desenhados), uma página por vez, e
o custo de implantação.

```json
{"name": "bill_of_materials", "arguments": {"project": "garden.oci.json", "limit": 2}}
```
```json
{"project": "garden.oci.json", "currency": "USD", "capitalCost": 881.34, "title": "Bill of materials",
 "headers": ["Category", "Description", "Code", "Unit", "Quantity", "Unit cost (US$)", "Total (US$)"],
 "rows": [["Hydraulic devices", "Backflow preventer 2\"", "", "un", 1.0, 175.05, 175.05],
          ["Hydraulic devices", "Water meter 2\"", "", "un", 1.0, 136.15, 136.15]], "totalRows": 41}
```

### report_table

Sem `table`, a lista das tabelas do relatório do dimensionamento (chave, título, colunas, linhas); com `table`, as linhas
dela, uma página por vez. Uma chave que se repete é pedida como `chave#2`, `chave#3`…

```json
{"name": "report_table", "arguments": {"project": "garden.oci.json"}}
```
```json
{"project": "garden.oci.json", "tables": [{"key": "zones", "title": "Zone summary", "columns": ["Zone", "Valve", "…"], "rows": 3},
 {"key": "pipes", "title": "Pipes", "columns": ["Context", "Entity", "…"], "rows": 217}, {"key": "bom", "…": "…"}, "…"]}
```
```json
{"name": "report_table", "arguments": {"project": "garden.oci.json", "table": "zones"}}
```
```json
{"project": "garden.oci.json", "key": "zones", "title": "Zone summary", "headers": ["Zone", "Valve", "Outlets", "Flow (L/h)", "…", "EU %", "…"],
 "rows": [["Zone 1 — sprays", "Solenoid valve 1\"", 15, 4803.5, "…"], "…"], "totalRows": 3}
```

### project_schema

O JSON Schema (2020-12) do arquivo de projeto, gerado do modelo: `overview` (padrão), `full`, `meta`, `params`, `layers`,
`systemFlows`, `catalog`, `catalog.<tipo>` ou `entity.<tipo>`.

```json
{"name": "project_schema", "arguments": {"part": "entity.controlValve"}}
```
```json
{"part": "entity.controlValve", "schema": {"title": "controlValve", "type": "object", "required": ["type", "id"],
 "properties": {"type": {"const": "controlValve"}, "p": {"type": "array", "items": {"type": "number"}, "description": "position [x, y] (m)"},
   "zone": {"type": "string", "description": "zone name of a valve; …", "default": ""}, "…": {}}}}
```

### list_examples

Os 15 projetos de exemplo (jardim, campo de futebol, pomar, cultura em linhas no gotejamento, estufa, viveiro, café em
nível, banana, cana com gotejamento enterrado, gotejamento por gravidade, pastagem, buraco de golfe, pivô central e pivô
setorial, linear) num `language`.

```json
{"name": "list_examples", "arguments": {}}
```
```json
{"language": "en", "examples": [{"id": "orchard", "name": "Orchard example", "client": "Example Farm", "site": "Blocks A and B",
 "entities": {"sprayline": 11, "tape": 16, "pipe": 7, "controlValve": 2, "…": 0}}, "…"]}
```

### list_catalog_packs

Os pacotes de catálogo que acompanham o programa (fabricantes e normas de tubos), com `search`.

```json
{"name": "list_catalog_packs", "arguments": {"search": "netafim"}}
```
```json
{"packs": [{"id": "netafim", "brand": "Netafim", "name": "Netafim", "description": "UniRam AS / DripNet PC / Streamline X driplines …",
 "items": 21, "source": "https://www.netafim.com/…", "license": "CC0-1.0", "updated": "2026-09-21"}]}
```

### create_project

Um projeto novo como `oci new` o faz: `out` (um `.oci.json` novo), `name`, `units` (`metric` ou `us`), `currency` (ISO
4217), `mains_hz` (50 ou 60), `georef` (`{"lat", "lon"}` da origem do desenho) e, com `boundary` (um desenho ou mapa), a
área irrigada do maior contorno fechado dele; `layout: true` distribui aspersores sobre ela (`outlet`: o id de um
emissor). Nunca substitui um arquivo. O resultado é o de `read_project`, com um `log`.

```json
{"name": "create_project", "arguments": {"out": "lawn.oci.json", "name": "Lawn", "currency": "EUR", "mains_hz": 50,
 "georef": {"lat": 38.72, "lon": -9.14}}}
```
```json
{"project": "lawn.oci.json", "name": "Lawn", "currency": "EUR", "mainsHz": 50.0,
 "georef": {"crs": "ETRS89 / UTM 29N", "epsg": 25829, "origin": {"lat": 38.72, "lon": -9.14}},
 "entities": {"total": 0, "byType": {}}, "…": "…", "log": []}
```

### copy_example

Um dos exemplos copiado para a raiz como um projeto próprio (um identificador novo), com os textos em `language`.

```json
{"name": "copy_example", "arguments": {"example": "garden", "out": "garden.oci.json"}}
```
```json
{"project": "garden.oci.json", "name": "Residential garden", "…": "…", "log": ["copied the example garden (en)"]}
```

### import_files

Um projeto feito de desenhos, mapas e levantamentos (`files`: DXF, DWG, DGN, KML/KMZ, shapefiles, GeoJSON, GPX, LandXML,
`.inp` do EPANET, LAS, cotas em GeoTIFF, pontos em CSV), gravado em `out` (padrão: o primeiro arquivo com `.oci.json`) com
as configurações de `create_project`; ou acrescentado a um projeto existente (`into`).

```json
{"name": "import_files", "arguments": {"files": ["garden.dxf"], "out": "survey.oci.json"}}
```
```json
{"project": "survey.oci.json", "name": "garden", "entities": {"total": 111, "byType": {"outlet": 24, "pipe": 15, "…": 0}},
 "zones": [{"id": "e16", "zone": "Zone 1 — sprays"}, "…"], "…": "…", "log": ["garden.dxf: dxf, 111 items"]}
```

### set_project

As configurações de `oci set` (`name`, `units`, `currency` com os preços convertidos pelas taxas de referência,
`mains_hz`, `georef`), os dados (`client`, `site`, `designer`, `notes`) e os `parameters` de projeto pela chave no arquivo
(`project_schema` parte `params`; chaves e valores inválidos são recusados todos juntos). Gravado em `out` ou sobre o
projeto.

```json
{"name": "set_project", "arguments": {"project": "lawn.oci.json", "client": "Ana", "parameters": {"vZone": 1.2, "sizing": "lp"}}}
```
```json
{"project": "lawn.oci.json", "name": "Lawn", "client": "Ana", "…": "…", "log": ["changed: client, parameters"]}
```

### edit_entities

Itens acrescentados (`add`: objetos do arquivo de projeto com o `type`; `id` e `layer` opcionais), alterados (`update`:
`{"id", "set": {chave: valor}}`) e apagados (`delete`: ids). Tudo é verificado antes; se algo for recusado, o arquivo não
muda. O resultado lista os ids e os problemas que a verificação do projeto encontra nos itens alterados.

```json
{"name": "edit_entities", "arguments": {"project": "lawn.oci.json", "add": [
  {"type": "waterSupply", "p": [0, 0]},
  {"type": "pipe", "scope": "mainline", "auto": true, "pts": [[0, 0], [12, 0]]},
  {"type": "controlValve", "p": [12, 0], "zone": "Front"}]}}
```
```json
{"project": "lawn.oci.json", "added": ["e1", "e2", "e3"], "updated": [], "deleted": [], "entities": 3,
 "problems": [{"level": "info", "code": "supply_no_meter", "message": "Intake without a flow meter or an hour meter", "entities": ["e1"]}, "…"]}
```

### add_catalog_pack

Pacotes de catálogo acrescentados como `oci pack add` faz: ids dos que acompanham o programa (`list_catalog_packs`) ou
arquivos `.oci.cat` sob a raiz.

```json
{"name": "add_catalog_pack", "arguments": {"project": "lawn.oci.json", "packs": ["netafim"]}}
```
```json
{"project": "lawn.oci.json", "catalog": {"pipes": 17, "outlets": 14, "tapes": 23, "…": 0}, "…": "…", "log": ["netafim: 21 items added"]}
```

### design_project

O dimensionamento do aplicativo (F5): tubulações dimensionadas, cada setor, fluxo e pivô analisado, orçado e gravado com
os resultados (em `out` ou sobre o projeto). O resultado é o de `analyze_project`, com `saved`.

```json
{"name": "design_project", "arguments": {"project": "garden.oci.json"}}
```
```json
{"project": "garden.oci.json", "name": "Residential garden", "sized": true, "saved": "garden.oci.json",
 "tables": {"zones": {"…": "…", "rows": [["Zone 1 — sprays", 4803.5, 22.8, 19.7, 20.4, 94.2, 0], "…"]}, "flows": {"…": "…"}},
 "totals": {"capitalCost": 881.34, "currency": "USD", "bomLines": 37}, "messages": {"errors": 0, "warnings": 0, "notes": 3, "…": "…"}}
```

### export_drawing

O desenho em `format` (`dxf`, `dxfR12`, `dwg`, `pdf`, `svg`, `kml`, `kmz`, `geojson`, `gpx`, `shp`, `landxml`, `ifc`,
`inp`), em `out` (padrão: ao lado do projeto); `calculate` (`design` por padrão, `analyze`, `none`), `paper` e `portrait`
para PDF e SVG, `georef` para os formatos de mapa quando o projeto não tem, `overwrite` para substituir um arquivo.

```json
{"name": "export_drawing", "arguments": {"project": "garden.oci.json", "format": "pdf", "paper": "a3"}}
```
```json
{"written": "garden.pdf", "bytes": 8933, "format": "pdf"}
```

### export_report

As tabelas do relatório (`tables`: `all` ou `bom`) em `format` (`csv`, `txt`, `xlsx`, `pdf`), depois do dimensionamento.

```json
{"name": "export_report", "arguments": {"project": "garden.oci.json", "format": "xlsx"}}
```
```json
{"written": "garden.report.xlsx", "bytes": 42294, "format": "xlsx"}
```

Uma chamada recusada é um erro da ferramenta, que o modelo consegue corrigir:

```json
{"name": "read_project", "arguments": {"project": "../elsewhere.oci.json"}}
```
```json
{"content": [{"type": "text", "text": "../elsewhere.oci.json: \"..\" is not allowed in a path (every path stays under the root folder)"}], "isError": true}
```

## 5. Recursos e prompts

Recursos (`resources/list`, `resources/read`): `oci://schema/project.json` (o JSON Schema do arquivo de projeto),
`oci://catalogs/index.json` (os pacotes de catálogo) e `oci://examples/<idioma>/<id>.oci.json` (os 15 exemplos no idioma
do servidor).

Prompts (`prompts/list`, `prompts/get`), para os clientes que os oferecem como comandos:

- `design_irrigation` (`drawing`, obrigatório; `what`): projetar um sistema para a área de um desenho, passo a passo,
  dizendo as hipóteses adotadas.
- `review_project` (`project`, obrigatório): verificar um projeto, explicar os problemas e como corrigi-los, sem alterá-lo.

## 6. Segurança

- **Uma pasta.** Todo caminho é resolvido dentro de `--root`: `..` é recusado de saída, `~` não é expandido, um caminho
  absoluto precisa ficar dentro da raiz e todo link simbólico no caminho é resolvido antes da verificação, de modo que um
  link que leva para fora é recusado. Só arquivos comuns são lidos (nada de dispositivos ou pipes); as listagens deixam
  de fora os arquivos ocultos e os links que levam para fora.
- **Cada arquivo do seu tipo.** Uma ferramenta só grava o seu tipo de arquivo: projetos como `.oci.json`, desenhos com a
  extensão do formato, relatórios como `.csv`, `.txt`, `.xlsx` ou `.pdf`. Projetos novos e cópias nunca substituem um
  arquivo; exportações só substituem com `overwrite: true`; as ferramentas que alteram um projeto (`set_project`,
  `edit_entities`, `add_catalog_pack`, `design_project`, `import_files` com `into`) gravam sobre ele, a não ser que se dê
  `out`. Um projeto que o servidor grava é escrito inteiro (num arquivo temporário oculto renomeado por cima); as
  exportações, os relatórios e os projetos de `create_project`, `import_files` e `add_catalog_pack` são gravados pelo
  próprio código da linha de comando.
- **Somente leitura.** Com `--read-only`, as ferramentas que gravam não aparecem na lista e não podem ser chamadas.
- **Sem rede, sem shell.** Nenhuma ferramenta acessa a internet (as dicas dizem `openWorldHint: false`) e o servidor não
  executa nenhum outro programa.
- **Entradas validadas.** Os argumentos são verificados contra o esquema da ferramenta (tipos, faixas, padrões, tamanhos,
  nenhum argumento desconhecido) antes de qualquer coisa rodar; as edições são verificadas por inteiro antes de o
  arquivo mudar.
- **Trabalho limitado.** Arquivos, mensagens, páginas e o tempo de uma chamada têm limites (abaixo); uma chamada pode ser
  cancelada.
- **O que ele não é.** O servidor é um programa do usuário: roda com as permissões do usuário. Um hard link dentro da raiz
  para um arquivo em outro lugar é aquele arquivo, e um link trocado entre a verificação e o uso não é percebido. Dê a ele
  uma pasta de projetos, não a sua pasta pessoal.

## 7. Limites

| O quê | Limite |
|---|---|
| Um arquivo que uma ferramenta lê (projeto, desenho, levantamento, pacote) | 256 MB |
| Uma mensagem (uma linha) | 16 MB |
| Linhas ou itens numa resposta | 100 por padrão, no máximo 1000 (`offset`, `limit`) |
| Itens completos (`list_entities` com `full`) | 200 por página |
| Arquivos listados | 2000 |
| Alterações numa chamada de `edit_entities` | 5000 de cada tipo |
| Arquivos ou pacotes numa chamada | 50 |
| Uma chamada de ferramenta | 15 minutos |

O dimensionamento trabalha com o que o projeto contém: o que o aplicativo não dimensiona, o servidor também não (valem os
limites do capítulo de limitações do manual). As correções automáticas do assistente de projeto, os cenários, os
documentos técnicos e os dados on-line (cotas, mapas de fundo, clima) ainda não são ferramentas: o aplicativo os tem.

## 8. Para quem desenvolve

- `lib/core/mcp/mcp_server.dart`: o protocolo (Dart puro, sem transporte): JSON-RPC, os dois tipos de revisão,
  ferramentas, recursos, prompts, validação, cancelamento, progresso e o tempo máximo por meio de um executor.
- `lib/core/mcp/json_schema.dart`: o validador das palavras-chave de JSON Schema que as ferramentas usam.
- `lib/core/mcp/oci_mcp_tools.dart`: as ferramentas, sobre um `OciMcpHost` que fornece os arquivos e as funções da linha
  de comando.
- `bin/src/oci_mcp_io.dart`: a pasta raiz, o isolate de cada chamada e o transporte stdio (dart:io, dart:isolate).
- `bin/oci.dart`: o comando `mcp`, o host sobre a sessão da linha de comando, `ociMcpServer()`.
- Testes: `test/core/mcp_protocol_test.dart` (protocolo), `test/core/mcp_session_test.dart` (as ferramentas numa sessão
  inteira), `test/core/mcp_paths_test.dart` (a pasta raiz), `test/core/mcp_process_test.dart` (o processo real).
