# The OpenCADIrrigation MCP server

*Português: [MCP.pt-BR.md](MCP.pt-BR.md)*

`dart run bin/oci.dart mcp --root <folder>` starts a [Model Context Protocol](https://modelcontextprotocol.io) server:
any AI application that speaks MCP (an "MCP client") can then design pressurised irrigation systems with the
OpenCADIrrigation engine, on your own computer. The model reads and writes projects in one folder of your choice, makes
a project of a drawing or a survey, draws and changes its items, sizes the pipes, analyses the zones, the mainline and
the pivots, reads the messages of the design assistant with their explanations, the bill of materials and every report
table, and exports drawings (DXF, DWG, PDF, SVG, KML, GeoJSON, shapefiles, LandXML, IFC, EPANET) and reports (CSV, TXT,
XLSX, PDF). Nothing goes to the internet, nothing runs outside that folder, and no account is needed.

The server is the command line's own engine (`bin/oci.dart`, the same functions as `design`, `check`, `export`, `bom`,
`new`, `import`, `set` and `pack add`), so a result through MCP is the result of the app and of the command line.

## Contents

1. [Starting the server](#1-starting-the-server)
2. [Configuring an MCP client](#2-configuring-an-mcp-client)
3. [The protocol](#3-the-protocol)
4. [The tools](#4-the-tools)
5. [Resources and prompts](#5-resources-and-prompts)
6. [Safety](#6-safety)
7. [Limits](#7-limits)
8. [For developers](#8-for-developers)

## 1. Starting the server

You need a copy of this repository with its packages (`flutter pub get`, see [CONTRIBUTING.md](../CONTRIBUTING.md)), or
the engine package without Flutter (`dart tool/engine_package.dart build/engine`, then `dart pub get` inside it; that
package has no example projects). Then:

```sh
dart run bin/oci.dart mcp --root ~/irrigation-projects
dart run bin/oci.dart mcp --root ~/irrigation-projects --read-only --lang pt
```

| Option | What it does |
|---|---|
| `--root <folder>` | The folder the AI application may read and write (required). Every path of every tool is inside it. |
| `--read-only` | Only the tools that read, analyse, check and report: none of them writes a file. |
| `--lang <code>` | Language of the names, reports and messages (default `en`; any of the 20 languages of the app). |

The server reads JSON-RPC messages on its standard input and writes its answers on its standard output, one message per
line; what it has to say for people (the start line, a request cancelled, an error) goes to the standard error. It stops
when its input closes: calls still running get ten seconds to answer, the rest are stopped. `dart run bin/oci.dart --help`
lists the options too.

## 2. Configuring an MCP client

An MCP client starts the server as a program of its own and talks to it over its standard input and output. Most
clients take the command, its arguments and, optionally, environment variables, in a JSON file of their settings; the
name of the file and of its keys depends on the client (see its documentation). A typical entry:

```json
{
  "mcpServers": {
    "opencadirrigation": {
      "command": "/path/to/flutter/bin/dart",
      "args": ["run", "/path/to/opencadirrigation/bin/oci.dart", "mcp", "--root", "/path/to/irrigation-projects", "--lang", "en"]
    }
  }
}
```

Give absolute paths: the client may start the server from any folder. Add `"--read-only"` to the arguments for a server
that can only look. The first start compiles the program (some seconds); later starts are quick.

## 3. The protocol

The server implements the current revision of the specification, **2026-07-28**, and the handshake revisions
**2025-11-25** and **2025-06-18**, in the same process:

- **2026-07-28 (stateless).** Every request carries `_meta["io.modelcontextprotocol/protocolVersion"]` and
  `_meta["io.modelcontextprotocol/clientCapabilities"]`; every result carries `resultType: "complete"` and
  `_meta["io.modelcontextprotocol/serverInfo"]`; lists and reads carry `ttlMs` and `cacheScope`. `server/discover` names
  the revisions, the capabilities (tools, resources, prompts) and the instructions for the model. A request for a
  revision the server does not speak gets error `-32022` with the supported ones; one without the required `_meta`
  fields gets `-32602`.
- **2025-11-25 and 2025-06-18 (handshake).** `initialize` agrees on the revision (the one asked for, or 2025-11-25 for any
  other), then `notifications/initialized`, `ping` and the requests below work without `_meta`, with the result shapes of
  that revision.

Methods: `server/discover`, `initialize`, `ping`, `tools/list`, `tools/call`, `resources/list`, `resources/read`,
`resources/templates/list` (empty), `prompts/list`, `prompts/get` and `subscriptions/listen` (acknowledged with no
notification type: the tools, resources and prompts never change while the server runs). Notifications:
`notifications/initialized` and `notifications/cancelled`.

- **Errors.** Not JSON: `-32700`; a batch, a request without `jsonrpc: "2.0"`, without a method or with a null id:
  `-32600`; an unknown method: `-32601`; bad parameters, an unknown tool, an unknown cursor: `-32602`. Arguments that do
  not match a tool's input schema are a *tool* error (`isError: true`) whose text lists every problem, so that the model
  can correct them; so is a tool that fails (a file that is not there, a project with nothing to design).
- **Cancellation.** `notifications/cancelled` with the request id stops the call: every tool call runs in an isolate of
  its own, which is killed, and no response is sent.
- **Progress.** A call with `_meta.progressToken` gets `notifications/progress` every five seconds while it runs (the
  count of beats and the seconds elapsed), so that a client can keep a long design alive.
- **Time limit.** A call that runs for more than 15 minutes is stopped with a tool error.
- **Concurrency.** Reading tools run side by side; a tool that writes runs alone, in the order the calls came.
- **Schemas.** Input and output schemas are JSON Schema 2020-12, without `$ref`; the arguments are validated before the
  tool runs.

## 4. The tools

Every path is relative to the root (`"field.oci.json"`, `"plans/site.dxf"`); an absolute path is accepted when it lies
inside the root. Inside a project file everything is SI (coordinates and lengths in metres, flows in m³/s, pressures as
heads in metres of water); the result tables use the project's display units, which their headers state. Every result
is a JSON object (`structuredContent`, also serialised in the text block), described by the tool's output schema.

| Tool | Writes | What it does |
|---|---|---|
| [`list_files`](#list_files) | | Files under the root, by kind |
| [`read_project`](#read_project) | | A project's details, units, georeference, items, zones, catalogue |
| [`list_entities`](#list_entities) | | The items of a project, filtered, a page at a time |
| [`list_catalog`](#list_catalog) | | Pipes, emitters, tapes, valves, pumps, fittings, wires of a project |
| [`analyze_project`](#analyze_project) | | Hydraulic analysis without saving |
| [`check_project`](#check_project) | | Every message of the design check and the assistant |
| [`validate_project`](#validate_project) | | What reading the file had to repair |
| [`bill_of_materials`](#bill_of_materials) | | The bill of materials and the capital cost |
| [`report_table`](#report_table) | | Any report table as rows |
| [`project_schema`](#project_schema) | | The JSON Schema of the project file, by part |
| [`list_examples`](#list_examples) | | The example projects that ship with the program |
| [`list_catalog_packs`](#list_catalog_packs) | | The catalogue packs that ship with the program |
| [`create_project`](#create_project) | yes | A new project, with a georeference, an area and a sprinkler layout |
| [`copy_example`](#copy_example) | yes | An example copied into the root |
| [`import_files`](#import_files) | yes | A project made of drawings, maps and surveys |
| [`set_project`](#set_project) | yes | Settings, details and design parameters |
| [`edit_entities`](#edit_entities) | yes | Items added, changed and deleted |
| [`add_catalog_pack`](#add_catalog_pack) | yes | Catalogue packs added to a project |
| [`design_project`](#design_project) | yes | The design (F5), saved with its results |
| [`export_drawing`](#export_drawing) | yes | The drawing in another format |
| [`export_report`](#export_report) | yes | The report tables as CSV, TXT, XLSX or PDF |

Every tool states its hints: the reading ones `readOnlyHint: true`; the writing ones `destructiveHint` (true when they may
change or replace a file: all but `create_project` and `copy_example`, which never replace one) and `idempotentHint`;
none reaches the internet (`openWorldHint: false`). The examples below are real answers for the garden example
(shortened where `…` stands).

### list_files

Files under the root or one of its folders (`folder`), `recursive` (default true), of one `kind` (`all`, `projects`,
`importable`, `catalogue_packs`, `other`). Hidden files are left out.

```json
{"name": "list_files", "arguments": {}}
```
```json
{"folder": ".", "files": [{"path": "garden.oci.json", "kind": "project", "bytes": 146908}], "truncated": false}
```

### read_project

The details, display units, currency, mains frequency, georeference, extent of the drawing (m), items by type, zones
(control valves), supplies, pivots, system flows, layers with items, catalogue sizes and repairs; `parameters: true` adds
the design parameters as the file stores them.

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

Items filtered by `types`, `layer` or `ids`, a page at a time (`offset`, `limit`), as a table; `full: true` gives each item
as the project file stores it, ready for `edit_entities`.

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

The catalogue of a project, one `kind` at a time (`pipes`, `outlets`, `tapes`, `valves`, `pumps`, `fittings`, `wires`),
with `search` and `enabled_only`; the ids are what the items of the drawing refer to.

```json
{"name": "list_catalog", "arguments": {"project": "garden.oci.json", "kind": "pipes", "search": "PE", "limit": 1}}
```
```json
{"kind": "pipes", "currency": "USD", "total": 8, "items": [{"id": "pe16", "name": "PE 16 mm (PN 4)", "nominalMm": 16.0,
 "idMm": 13.6, "material": "peld", "c": 140.0, "ratingM": 40.0, "cost": 0.175, "usage": ["lateral"], "enabled": true}]}
```

### analyze_project

The hydraulic analysis without changing the file (`size_pipes: true` sizes the pipes first, still without saving): zones,
system flows, pivots, capital cost and the assistant's messages.

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

Every message, as `oci check --json` gives it: level, code, text, the items, and with `explain` (default true) why it
matters, how to fix it and the automatic corrections that apply. `run`: `design` (default), `analyze` or `none`.

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

What reading the file had to repair (items set aside, renumbered ids, dropped vertices, values not understood, a newer
format) and the errors of the design check, as `oci validate --json`.

```json
{"name": "validate_project", "arguments": {"project": "garden.oci.json"}}
```
```json
{"project": "garden.oci.json", "name": "Residential garden", "version": 2, "readsVersion": 2, "newerVersion": false,
 "skipped": {}, "renumbered": 0, "droppedVertices": 0, "unknownValues": [], "repairs": [], "errors": [], "clean": true}
```

### bill_of_materials

The bill of materials after the design (`size_pipes: false` keeps the sizes drawn), a page at a time, and the capital cost.

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

Without `table`, the list of the report tables of the design (key, title, columns, rows); with `table`, its rows a page at
a time. A key that repeats is addressed as `key#2`, `key#3`…

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

The JSON Schema (2020-12) of the project file, built from the model: `overview` (default), `full`, `meta`, `params`,
`layers`, `systemFlows`, `catalog`, `catalog.<kind>` or `entity.<type>`.

```json
{"name": "project_schema", "arguments": {"part": "entity.controlValve"}}
```
```json
{"part": "entity.controlValve", "schema": {"title": "controlValve", "type": "object", "required": ["type", "id"],
 "properties": {"type": {"const": "controlValve"}, "p": {"type": "array", "items": {"type": "number"}, "description": "position [x, y] (m)"},
   "zone": {"type": "string", "description": "zone name of a valve; …", "default": ""}, "…": {}}}}
```

### list_examples

The 15 example projects (garden, sports field, orchard, drip row crop, greenhouse, nursery, coffee on contours, bananas,
subsurface drip sugarcane, gravity-fed drip, pasture, golf hole, centre and sector pivots, linear move) in a `language`.

```json
{"name": "list_examples", "arguments": {}}
```
```json
{"language": "en", "examples": [{"id": "orchard", "name": "Orchard example", "client": "Example Farm", "site": "Blocks A and B",
 "entities": {"sprayline": 11, "tape": 16, "pipe": 7, "controlValve": 2, "…": 0}}, "…"]}
```

### list_catalog_packs

The catalogue packs that ship with the program (manufacturers and pipe standards), with `search`.

```json
{"name": "list_catalog_packs", "arguments": {"search": "netafim"}}
```
```json
{"packs": [{"id": "netafim", "brand": "Netafim", "name": "Netafim", "description": "UniRam AS / DripNet PC / Streamline X driplines …",
 "items": 21, "source": "https://www.netafim.com/…", "license": "CC0-1.0", "updated": "2026-09-21"}]}
```

### create_project

A new project as `oci new` makes it: `out` (a new `.oci.json`), `name`, `units` (`metric` or `us`), `currency` (ISO 4217),
`mains_hz` (50 or 60), `georef` (`{"lat", "lon"}` of the drawing origin), and with `boundary` (a drawing or map) the
irrigated area of its largest closed outline; `layout: true` lays sprinklers over it (`outlet`: an emitter id). It
never replaces a file. The result is that of `read_project`, with a `log`.

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

One of the examples copied into the root as a project of its own (a new identifier), its texts in `language`.

```json
{"name": "copy_example", "arguments": {"example": "garden", "out": "garden.oci.json"}}
```
```json
{"project": "garden.oci.json", "name": "Residential garden", "…": "…", "log": ["copied the example garden (en)"]}
```

### import_files

A project made of drawings, maps and surveys (`files`: DXF, DWG, DGN, KML/KMZ, shapefiles, GeoJSON, GPX, LandXML, EPANET
`.inp`, LAS, GeoTIFF elevations, CSV points), written to `out` (default: the first file with `.oci.json`) with the
settings of `create_project`; or added to an existing project (`into`).

```json
{"name": "import_files", "arguments": {"files": ["garden.dxf"], "out": "survey.oci.json"}}
```
```json
{"project": "survey.oci.json", "name": "garden", "entities": {"total": 111, "byType": {"outlet": 24, "pipe": 15, "…": 0}},
 "zones": [{"id": "e16", "zone": "Zone 1 — sprays"}, "…"], "…": "…", "log": ["garden.dxf: dxf, 111 items"]}
```

### set_project

The settings of `oci set` (`name`, `units`, `currency` with the prices converted at reference rates, `mains_hz`, `georef`),
the details (`client`, `site`, `designer`, `notes`) and design `parameters` by their key in the file
(`project_schema` part `params`; invalid keys and values are refused all together). Saved to `out` or over the project.

```json
{"name": "set_project", "arguments": {"project": "lawn.oci.json", "client": "Ana", "parameters": {"vZone": 1.2, "sizing": "lp"}}}
```
```json
{"project": "lawn.oci.json", "name": "Lawn", "client": "Ana", "…": "…", "log": ["changed: client, parameters"]}
```

### edit_entities

Items added (`add`: objects of the project file with their `type`; `id` and `layer` optional), changed (`update`:
`{"id", "set": {key: value}}`) and deleted (`delete`: ids). Everything is checked first; when anything is refused, the
file is not touched. The result lists the ids and the problems the design check finds in the items changed.

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

Catalogue packs added as `oci pack add` adds them: bundled ids (`list_catalog_packs`) or `.oci.cat` files under the root.

```json
{"name": "add_catalog_pack", "arguments": {"project": "lawn.oci.json", "packs": ["netafim"]}}
```
```json
{"project": "lawn.oci.json", "catalog": {"pipes": 17, "outlets": 14, "tapes": 23, "…": 0}, "…": "…", "log": ["netafim: 21 items added"]}
```

### design_project

The design of the app (F5): pipes sized, every zone, flow and pivot analysed, priced, then saved with its results (to
`out` or over the project). The result is that of `analyze_project`, with `saved`.

```json
{"name": "design_project", "arguments": {"project": "garden.oci.json"}}
```
```json
{"project": "garden.oci.json", "name": "Residential garden", "sized": true, "saved": "garden.oci.json",
 "tables": {"zones": {"…": "…", "rows": [["Zone 1 — sprays", 4803.5, 22.8, 19.7, 20.4, 94.2, 0], "…"]}, "flows": {"…": "…"}},
 "totals": {"capitalCost": 881.34, "currency": "USD", "bomLines": 37}, "messages": {"errors": 0, "warnings": 0, "notes": 3, "…": "…"}}
```

### export_drawing

The drawing in `format` (`dxf`, `dxfR12`, `dwg`, `pdf`, `svg`, `kml`, `kmz`, `geojson`, `gpx`, `shp`, `landxml`, `ifc`,
`inp`), to `out` (default: next to the project); `calculate` (`design` by default, `analyze`, `none`), `paper` and
`portrait` for PDF and SVG, `georef` for the map formats when the project has none, `overwrite` to replace a file.

```json
{"name": "export_drawing", "arguments": {"project": "garden.oci.json", "format": "pdf", "paper": "a3"}}
```
```json
{"written": "garden.pdf", "bytes": 8933, "format": "pdf"}
```

### export_report

The report tables (`tables`: `all` or `bom`) in `format` (`csv`, `txt`, `xlsx`, `pdf`), after the design.

```json
{"name": "export_report", "arguments": {"project": "garden.oci.json", "format": "xlsx"}}
```
```json
{"written": "garden.report.xlsx", "bytes": 42294, "format": "xlsx"}
```

A refused call is a tool error the model can act on:

```json
{"name": "read_project", "arguments": {"project": "../elsewhere.oci.json"}}
```
```json
{"content": [{"type": "text", "text": "../elsewhere.oci.json: \"..\" is not allowed in a path (every path stays under the root folder)"}], "isError": true}
```

## 5. Resources and prompts

Resources (`resources/list`, `resources/read`): `oci://schema/project.json` (the JSON Schema of the project file),
`oci://catalogs/index.json` (the catalogue packs) and `oci://examples/<language>/<id>.oci.json` (the 15 examples in the
server's language).

Prompts (`prompts/list`, `prompts/get`), for clients that offer them as commands:

- `design_irrigation` (`drawing`, required; `what`): design a system for the area of a drawing, step by step, with the
  assumptions stated.
- `review_project` (`project`, required): check a project, explain its problems and how to correct them, without changing it.

## 6. Safety

- **One folder.** Every path is resolved inside `--root`: `..` is refused outright, `~` is not expanded, an absolute path
  must lie inside the root, and every symbolic link on the way is resolved before the check, so a link that leads out is
  refused. Only regular files are read (no devices or pipes); listings leave out hidden files and links that lead out.
- **Files of their own kind.** A tool writes only its own kind of file: projects as `.oci.json`, drawings with the
  extension of their format, reports as `.csv`, `.txt`, `.xlsx` or `.pdf`. New projects and copies never replace a file;
  exports replace one only with `overwrite: true`; the tools that change a project (`set_project`, `edit_entities`,
  `add_catalog_pack`, `design_project`, `import_files` with `into`) write over it unless `out` is given. A project the
  server saves is written whole (into a hidden temporary file renamed over it); exports, reports and the projects of
  `create_project`, `import_files` and `add_catalog_pack` are written by the command line's own code.
- **Read-only.** With `--read-only`, the tools that write are not listed and cannot be called.
- **No network, no shell.** No tool reaches the internet (the hints say `openWorldHint: false`), and the server runs no
  other program.
- **Validated inputs.** Arguments are checked against the tool's schema (types, ranges, patterns, sizes, no unknown
  argument) before anything runs; edits are checked whole before the file changes.
- **Bounded work.** Files, messages, pages and the time of a call have limits (below); a call can be cancelled.
- **What it is not.** The server is a program of the user: it runs with the user's rights. A hard link inside the root to
  a file elsewhere is that file, and a link changed between the check and the use is not seen. Give it a folder of
  projects, not your home folder.

## 7. Limits

| What | Limit |
|---|---|
| A file a tool reads (project, drawing, survey, pack) | 256 MB |
| A message (one line) | 16 MB |
| Rows or items in one answer | 100 by default, 1000 at most (`offset`, `limit`) |
| Items in full (`list_entities` with `full`) | 200 a page |
| Files listed | 2000 |
| Changes in one `edit_entities` call | 5000 of each kind |
| Files or packs in one call | 50 |
| A tool call | 15 minutes |

The design runs on what the project holds: what the app cannot design, the server cannot either (the limits of the
manual's limitations chapter apply). The automatic corrections of the design assistant, scenarios, the technical
documents and the online data (elevations, base maps, climate) are not tools yet: the app has them.

## 8. For developers

- `lib/core/mcp/mcp_server.dart`: the protocol (pure Dart, no transport): JSON-RPC, both kinds of revision, tools,
  resources, prompts, validation, cancellation, progress and the time limit through an executor.
- `lib/core/mcp/json_schema.dart`: the validator of the JSON Schema keywords the tools use.
- `lib/core/mcp/oci_mcp_tools.dart`: the tools, on an `OciMcpHost` that provides the files and the command line's functions.
- `bin/src/oci_mcp_io.dart`: the root folder, the isolate of each call and the stdio transport (dart:io, dart:isolate).
- `bin/oci.dart`: the `mcp` command, the host on the command line's session, `ociMcpServer()`.
- Tests: `test/core/mcp_protocol_test.dart` (protocol), `test/core/mcp_session_test.dart` (the tools in a whole session),
  `test/core/mcp_paths_test.dart` (the root folder), `test/core/mcp_process_test.dart` (the real process).
