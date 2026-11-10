<p align="center"><img src="web/brand/logo-horizontal.png" width="560" alt="OpenCADIrrigation"></p>

<p align="center"><a href="https://opencadirrigation.com">opencadirrigation.com</a> · <a href="https://opencadirrigation.com/pt/">Português</a> · <a href="https://opencadirrigation.com/es/">Español</a> · <a href="LICENSE.md">MIT licence</a></p>

<p align="center"><strong>English</strong> · <a href="README.pt-BR.md">Português</a></p>

# OpenCADIrrigation

Open-source CAD, written in Flutter/Dart, for the design of pressurised irrigation systems: drawing, hydraulic network,
pipe sizing, reports and plotting, right in the browser, with no installation, no server and no sign-up, plus an
optional AI assistant (Claude, GPT, Gemini, Grok, Muse or the models of OpenRouter, with your own key) that draws and
designs the project with you. Projects stay on your computer. Released under the [MIT licence](LICENSE.md).

<p align="center"><img src="web/screenshots/design-1440x900.png" width="900" alt="A designed irrigation project with pipe sizes, pressures and results per zone"></p>

## Start in five minutes

1. Open [opencadirrigation.com](https://opencadirrigation.com) and press **Open the app** (or open an example or the
   tutorial straight from the page). It runs in Chrome, Edge, Firefox and Safari, on desktop, tablet and phone, and
   installs as an app that starts without a network after the first visit.
2. Say where the area is (an address or coordinates) and whether to design with the AI assistant, or open a ready
   example: Help → Welcome and example gallery, with the **interactive tutorial** (90 steps in chapters). Ctrl+K finds
   any menu, command or setting, and F1 opens the manual.
3. Draw the area and the network, or let the generators or the assistant do it; press **F5** to design.
4. Read the results in the **Reports** panel (F2) and export PDF sheets, DXF, DWG, Excel and more; save the project
   with **Ctrl+S** (`.oci.json`).

More in [the five-minute start](docs/manual/getting-started.md).

## What it is

A single application covering the whole cycle of a pressurised irrigation design:

- **Optional AI agent**: a model of Anthropic (Claude), OpenAI (GPT), Google (Gemini), xAI (Grok),
  Meta (Muse) or OpenRouter (hundreds of models through one key, some free), with your own API key,
  works on the open project with the program's own tools: it answers questions, asks what is
  missing, plans, draws, designs, checks and reports, with your approval and an undo for every
  answer, and another company's model can give a second opinion on an answer
  ([AI assistant](docs/manual/ai-assistant.md)); nothing is sent until you press Send.
- **2D CAD drawing** with layers and layer states, snaps one by one, typed and field coordinates (UTM,
  latitude and longitude, azimuths and bearings), dimensions with a project style, hatches, symbols, user
  blocks and block references with attributes, review comments, revision clouds and field photos, comparison
  of two copies, and typed command aliases (L, PL, C, ZE…) as in desktop CAD programs.
- **Hydraulic network** drawn on top of the CAD: water supplies (also from a reservoir or dam), pumps
  (fixed or variable speed, or a pump station in parallel or in series with standby units), mainline,
  zone valves with reducing or sustaining pilots, laterals with emitters, drip tapes and driplines,
  filters, pressure regulators, pressure-sustaining valves, hydrants with flow limiters, meters, junctions
  and air vessels, valve-in-head sprinklers, centre pivots and linear moves, traveller lanes and furrows;
  irrigated areas with islands.
- **Hydraulic engine** in pure Dart: Hazen-Williams, Darcy-Weisbach, Scobey or Manning friction,
  minor losses (a share of the length or the bends and tees of the drawing), emitters
  `q = k·H^x`, network solver by the Global Gradient Algorithm (the one used by EPANET), pumps,
  pressure-reducing, pressure-sustaining and flow-control valves, tape flushing, water hammer by
  the method of characteristics, a 24-hour extended-period simulation with the level of reservoirs,
  the real operation of the zones at the pressure the mainline gives them, and the design aged and
  clogged.
- **Automatic sizing** of laterals, submains and mainline by linear programming (annualised pipe
  cost plus energy, emitter pressure window, pipe pressure class at the water temperature and with
  the water hammer, the energy balance of every loop, telescoping) or by the classic maximum-velocity
  method.
- **Automatic design**: landscape head layout with zoning and routing of pipes and valves, field
  subdivision into blocks with the longest lateral computed, orchard drip rings, sports and golf
  templates, pivot fit and several pivots in a property, fields traced on the satellite image,
  vegetation detected in aerial imagery, the direction, spacing and number of the planting rows of
  orchards, coffee, vineyards and citrus read on the satellite image so that the laterals follow
  them, and corrections and optimisation reviewed item by item.
- **Agronomy and operation**: site climate (downloaded, typed or from INMET station files), FAO-56
  crops with growth stages and your own crops, soils, effective rain and leaching, requirement
  tables, a daily soil water balance with regulated deficit, the controller programme with an
  irrigation window and cycle and soak, runoff potential, fertigation by stage, uniformity tests in
  the field, valve wiring (conventional or two-wire), time-of-use tariffs, on-demand networks,
  mechanised machines and surface irrigation. The programme plays on the plan (zones watering,
  pipes by flow and velocity, pumps, reservoir level) and exports as an animated GIF and a phone
  calendar (.ics); the irrigation forecast turns the weather forecast of the site (MET Norway open
  data) into the run time of each zone in the next days; the climate risk checks the design against
  forty real years of NASA POWER daily weather (requirement and peak demand by probability,
  reliability, dry spells, trend).
- **Power and water**: pump house electrics (motors, starters, feeders, short circuit, transformer),
  solar pumping in the design, water quality with its filters, chlorination and acid.
- **Terrain**: contour lines, spot heights, breaklines, digital terrain model by triangulation,
  LAS point clouds and LandXML surfaces, elevation downloaded from the internet for a coordinate,
  slope maps, profiles and hydraulic grade line.
- **Outputs**: reports of zones, pipes, emitters, system flows, bill of materials with fittings,
  water requirements and controller programme, each table with the standards of its criteria; PDF
  sheets in every interface script (sets per zone, construction details, charts, coordinate grid,
  slope and aspect sheets, a professional title block with the technical lead, any paper size,
  PDF/A-2b); document packages by reader and technical documents (water permit table, memorial,
  operation and maintenance plan, budget by unit-cost compositions, life-cycle cost); a commercial
  quote; DXF and DWG (R2000, native entities, hydraulic data), SVG, PNG, KML, KMZ, GeoJSON,
  shapefile, GPX, LandXML, IFC 4, EPANET, stake-out points, Excel, CSV; and a **design scorecard**
  that grades the designed project A–E in seven categories, every indicator with its target and the
  standard it comes from, and says what to improve first.
- **Open catalogues** in JSON, loadable by file or URL: manufacturer packs and generic pipes by
  standard (ISO 1452, EN 12201, IS 4985, IS 4984, ASTM); pump, emitter and sprinkler-profile curves
  digitised from a picture of a catalogue chart.
- **Command line and engine API**: `bin/oci.dart` imports drawings, starts, changes, designs, checks
  and exports projects without a browser, one or many at a time; `lib/core/api.dart` gives the whole
  engine in one import, also as a Dart package without Flutter ([docs/API.md](docs/API.md)).
- **MCP server**: `bin/oci.dart mcp --root <folder>` lets any AI application that speaks the Model
  Context Protocol design, check and export projects with the engine on your computer, confined to
  one folder ([docs/MCP.md](docs/MCP.md)).

## Who it is for

Agricultural and landscape irrigation designers, agronomists, engineers, dealers, teachers and
students. The interactive tutorial (with quick tracks for drip, landscape and pivots) and the example
gallery let you start without reading a manual.

## Principles

| Principle | What it means in practice |
|---|---|
| Open | Code, project format (`.oci.json`), catalogues (`.oci.cat`) and examples are readable files, documented in this repository. |
| In the browser | Chrome, Edge, Firefox and Safari, on desktop, tablet and phone; installable as a PWA that starts without a network after the first visit. It also builds for desktop (macOS, Windows, Linux). Native Android and iOS builds are not made: on phones and tablets use the web app. |
| No server | There is no server behind the app and no account. Projects live in the browser and in local files. The internet is used for what you ask for (base maps, online elevation and climate, the weather forecast, address search, catalogues by URL, and the optional AI assistant, the one feature that sends project data, to the AI provider you choose) and, on the site's pages and in the app, for the visit statistics (Google Analytics, with its cookies; Cookie settings at the foot of the pages turns it off); see [Storage, privacy and network access](docs/manual/privacy-and-network.md). |
| Transparent engine | Every formula is documented in the code and in the [technical study](docs/TECHNICAL_STUDY.md), with tests comparing it to reference values. |
| 20 languages | Interface in Portuguese, English, Spanish, Chinese, Hindi, Arabic, French, Bengali, Russian, Urdu, Indonesian, German, Japanese, Marathi, Vietnamese, Telugu, Hausa, Turkish, Punjabi and Swahili; the app opens in the system language, and Arabic and Urdu lay the interface out right to left. |

## Manual

The manual is in [docs/manual/](docs/manual/README.md) (Portuguese: [docs/manual/pt-BR/](docs/manual/pt-BR/README.md)), and on the
site as the [user guide](https://opencadirrigation.com/manual/) ([in Portuguese](https://opencadirrigation.com/pt/manual/)):

- [Five-minute start](docs/manual/getting-started.md): open the app, the example gallery, the URL parameters
- [Design workflow](docs/manual/workflow.md): from the area to the reports, step by step
- [Interface](docs/manual/interface.md): layout, menus, compact layout and keyboard shortcuts
- [Drawing and editing](docs/manual/drawing.md): entities, snaps, selection, transformations, blocks, layers
- [Hydraulic network](docs/manual/hydraulic-network.md): hydraulic items, connection rules, generators, automatic design
- [Component catalogue](docs/manual/catalogue.md): pipes, emitters, valves, pumps, prices and manufacturer packs
- [Terrain](docs/manual/terrain.md): contours, spot heights, the terrain model, online elevation
- [Calculation and sizing](docs/manual/calculation.md): parameters, calculation steps, design check and assistant, design scorecard, analyses
- [Agronomy and irrigation scheduling](docs/manual/agronomy.md): daily water balance, irrigation programme and its player, irrigation forecast, climate risk, runoff, fertigation, field uniformity
- [Power, water and machines](docs/manual/power-water-machines.md): pump house electrics, solar pumping, water quality, two-wire, several pivots
- [AI assistant](docs/manual/ai-assistant.md): what the optional assistant does, what it sends and how it is controlled
- [Reports, plotting and export](docs/manual/reports-and-export.md): reports panel, PDF sheets, quote, exports
- [Title block and technical documents](docs/manual/technical-documents.md): professional title block, document packages, permit table, memorial, budget
- [File formats](docs/manual/file-formats.md): the project file and every import and export format
- [Storage, privacy and network access](docs/manual/privacy-and-network.md): what stays in the browser, what goes out and to whom
- [Languages and site](docs/manual/languages-and-site.md): the 20 languages, the site, the offline start and the hosting
- [Code architecture](docs/manual/architecture.md): the source tree and the design decisions
- [Development and tests](docs/manual/development.md): commands, how to extend, what every test guarantees
- [Known limitations and roadmap](docs/manual/limitations.md): what the app does not do yet
- [References](docs/manual/references.md): standards, books and papers behind the engine
- [Licence, third-party components and data](docs/manual/licence.md): MIT licence, the components and the data sources

The technical study behind the engine is [docs/TECHNICAL_STUDY.md](docs/TECHNICAL_STUDY.md) (Portuguese:
[docs/PESQUISA.pt-BR.md](docs/PESQUISA.pt-BR.md)); the engine API is [docs/API.md](docs/API.md)
([docs/API.pt-BR.md](docs/API.pt-BR.md)); the MCP server is [docs/MCP.md](docs/MCP.md); what the AI assistant reaches is
[docs/AI_TOOLS.md](docs/AI_TOOLS.md).

## Contributing, security and licence

- [CONTRIBUTING.md](CONTRIBUTING.md): how to propose changes, catalogues, examples and translations, the editorial
  rule and the release checklist; [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
- [SECURITY.md](SECURITY.md): how to report a vulnerability privately.
- [CHANGELOG.md](CHANGELOG.md): what changed in each version; [CITATION.cff](CITATION.cff) to cite it.
- The app is a design aid: a qualified professional checks and signs a design made with it (terms of use at
  <https://opencadirrigation.com/terms/>, privacy policy at <https://opencadirrigation.com/privacy/>).
- [MIT licence](LICENSE.md); third-party components and data in [the licence chapter](docs/manual/licence.md).
