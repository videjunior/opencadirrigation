<p align="center"><img src="web/brand/logo-horizontal.png" width="560" alt="OpenCADIrrigation"></p>

<p align="center"><a href="https://opencadirrigation.com">opencadirrigation.com</a> · <a href="https://opencadirrigation.com/pt/">Português</a> · <a href="https://opencadirrigation.com/es/">Español</a> · <a href="LICENSE.md">MIT licence</a></p>

<p align="center"><strong>English</strong> · <a href="README.pt-BR.md">Português</a></p>

# OpenCADIrrigation

Open-source CAD, written in Flutter/Dart, for the design of pressurised irrigation systems:
drawing, hydraulic network, pipe sizing, reports and plotting, right in the browser, with no
installation, no server and no sign-up, plus an optional AI assistant (Claude or GPT, with your
own key) that draws and designs the project with you. Projects stay on your computer. Released
under the [MIT licence](LICENSE.md).

<p align="center"><img src="web/screenshots/design-1440x900.png" width="900" alt="A designed irrigation project with pipe sizes, pressures and results per zone"></p>

> This README is the canonical documentation, maintained in English; a Portuguese translation is
> in [README.pt-BR.md](README.pt-BR.md). The technical study behind the engine is in
> [docs/TECHNICAL_STUDY.md](docs/TECHNICAL_STUDY.md) (English) and
> [docs/PESQUISA.pt-BR.md](docs/PESQUISA.pt-BR.md) (Portuguese); the engine API is in
> [docs/API.md](docs/API.md) ([docs/API.pt-BR.md](docs/API.pt-BR.md)). The interface is available
> in 20 languages ([section 13](#13-languages-and-site)).

---

## Contents

1. [Overview](#1-overview)
2. [Five-minute start](#2-five-minute-start)
3. [Design workflow](#3-design-workflow)
4. [Interface](#4-interface)
5. [Drawing and editing](#5-drawing-and-editing)
6. [Hydraulic network](#6-hydraulic-network)
7. [Component catalogue](#7-component-catalogue)
8. [Terrain](#8-terrain)
9. [Calculation and sizing](#9-calculation-and-sizing)
10. [Reports, plotting and export](#10-reports-plotting-and-export)
11. [File formats](#11-file-formats)
12. [Storage, privacy and network access](#12-storage-privacy-and-network-access)
13. [Languages and site](#13-languages-and-site)
14. [Code architecture](#14-code-architecture)
15. [Development](#15-development)
16. [Tests](#16-tests)
17. [Known limitations and roadmap](#17-known-limitations-and-roadmap)
18. [Contributing](#18-contributing)
19. [References](#19-references)
20. [Licence, third-party components and data](#20-licence-third-party-components-and-data)

---

## 1. Overview

### What it is

A single application covering the whole cycle of a pressurised irrigation design:

- **Optional AI agent**: Claude (Anthropic) or GPT (OpenAI), with your own API key, works on the
  open project with the program's own tools: it answers questions, asks what is missing, plans,
  draws, designs, checks and reports, with your approval and an undo for every answer
  ([section 9](#ai-assistant-optional)); nothing is sent until you press Send.
- **2D CAD drawing** with layers, snaps, typed coordinates, dimensions, hatches, symbols, user
  blocks, review comments and revision clouds, and typed command aliases (L, PL, C, ZE…) as in desktop
  CAD programs.
- **Hydraulic network** drawn on top of the CAD: water supplies, pumps (fixed or variable speed),
  mainline, zone valves, laterals with emitters, drip tapes and driplines, filters, pressure
  regulators, pressure-sustaining valves, hydrants with flow limiters, meters, junctions,
  valve-in-head sprinklers, centre pivots and linear moves.
- **Hydraulic engine** in pure Dart: Hazen-Williams, Darcy-Weisbach, Scobey or Manning friction,
  minor losses (a share of the length or the bends and tees of the drawing), emitters
  `q = k·H^x`, network solver by the Global Gradient Algorithm (the one used by EPANET), pumps,
  pressure-reducing, pressure-sustaining and flow-control valves, tape flushing, water hammer by
  the method of characteristics and a 24-hour extended-period simulation.
- **Automatic sizing** of laterals, submains and mainline by linear programming (annualised pipe
  cost plus energy, emitter pressure window, pipe pressure class at the water temperature,
  telescoping) or by the classic maximum-velocity method.
- **Automatic design**: landscape head layout with zoning and routing of pipes and valves, field
  subdivision into blocks, orchard drip rings, sports and golf templates, pivot fit, and
  vegetation detected in aerial imagery.
- **Agronomy and operation**: site climate (downloaded or typed), FAO-56 crops with growth stages,
  soils, effective rain and leaching, requirement tables, valve wiring (conventional or two-wire),
  time-of-use tariffs, on-demand networks, fertigation, mechanised machines and surface
  irrigation.
- **Terrain**: contour lines, spot heights, breaklines, digital terrain model by triangulation,
  LAS point clouds and LandXML surfaces, elevation downloaded from the internet for a coordinate,
  slope maps, profiles and hydraulic grade line.
- **Outputs**: reports of zones, pipes, emitters, system flows, bill of materials with fittings,
  water requirements and controller programme; PDF sheets in every interface script (sets per
  zone, construction details, charts); a commercial quote; DXF and DWG (R2000, native
  entities), SVG, PNG, KML, KMZ, GeoJSON, shapefile, GPX, LandXML, IFC 4, EPANET, Excel, CSV.
- **Open manufacturer catalogues** in JSON, loadable by file or URL.
- **Command line and engine API**: `bin/oci.dart` designs, checks and exports projects without a
  browser; `lib/core/api.dart` gives the whole engine in one import ([docs/API.md](docs/API.md)).

### Who it is for

Agricultural and landscape irrigation designers, agronomists, engineers, dealers, teachers and
students. The interactive tutorial and the example gallery let you start without reading a manual.

### Principles

| Principle | What it means in practice |
|---|---|
| Open | Code, project format (`.oci.json`), catalogues (`.oci.cat`) and examples are readable files, documented in this repository. |
| In the browser | Chrome, Edge, Firefox and Safari, on desktop, tablet and phone; installable as a PWA that starts without a network after the first visit. It also builds for desktop (macOS, Windows, Linux). Native Android and iOS builds are not made: on phones and tablets use the web app. |
| No server | There is no server behind the app and no account. Projects live in the browser and in local files. The internet is used for what you ask for (base maps, online elevation and climate, address search, catalogues by URL, and the optional AI assistant, the one feature that sends project data, to the AI provider you choose), for the fonts of the scripts and symbols the app does not bundle (Google Fonts) and, on the site's pages and only if you accept them, for the visit statistics; see [section 12](#12-storage-privacy-and-network-access). |
| Transparent engine | Every formula is documented in the code and in the [technical study](docs/TECHNICAL_STUDY.md), with tests comparing it to reference values. |
| 20 languages | Interface in Portuguese, English, Spanish, Chinese, Hindi, Arabic, French, Bengali, Russian, Urdu, Indonesian, German, Japanese, Marathi, Vietnamese, Telugu, Hausa, Turkish, Punjabi and Swahili; the app opens in the system language, and Arabic and Urdu lay the interface out right to left. |

---

## 2. Five-minute start

1. Open [opencadirrigation.com](https://opencadirrigation.com) and press **Open the app** (or open
   an example or the tutorial straight from the page). The app opens by itself on later visits, on
   an empty project, with a start screen that asks two things: **where the area is** (an address
   found on OpenStreetMap, or coordinates; the project is georeferenced there, on the satellite map)
   and **whether to design with the AI assistant**.
2. Draw the area, let the assistant design it, or open a ready example: Help → Welcome and example
   gallery (with the **interactive tutorial**, 76 steps) or File → Examples.
3. Press **F5** (or the ▶ button at the top right). The calculation runs off the interface thread;
   a progress card shows the current step (zone by zone, mainline, flushing, water hammer,
   materials). The screen stays usable while it runs.
4. Read the results in the **Reports** panel (F2): zone summary, pipes with diameters and
   pressures, emitters, mainline and supply duties, bill of materials, water requirements,
   hydraulic grade line, messages.
5. Hover a pipe to see diameter, flow, velocity and head loss; select a lateral and open the
   **Hydraulic grade line** tab; switch the drawing overlay in View (velocity, pressure, diameters,
   minimum and maximum pressure, densogram, terrain slope and aspect). Every overlay draws the same
   items and changes only their colours: the emitters of drip lines are small dots on the line (one
   in a few when zoomed out), in the colour of the line or, with the pressure overlay, of their own
   pressure.
6. Export: File → Export drawing (PDF sheets, DXF, DWG, PNG…) or Export report (PDF, Excel, CSV,
   TXT). Save the project with **Ctrl+S** (`.oci.json`), or send it as a link (File → Share by
   link…).

### Example gallery

| id | Project | Contents | Zones |
|---|---|---|---|
| `orchard` | Orchard | Micro-sprinklers on citrus and drip on grapes, well, pump and filter, sloping ground | 2 |
| `garden` | Residential garden | Pop-up sprays on the front lawn, rotors at the back, drip in the beds; mains supply with meter and backflow preventer | 3 |
| `sportsField` | Football pitch | 105 × 68 m, impact sprinklers in five rows with matched nozzles on the lines, reservoir, pump, night-time shifts | 5 |
| `rowCrop` | Drip row crop | Four tomato blocks on tape, submains with valves, screen filter, pump, 1 % slope | 4 |
| `pivot` | Centre pivot | 300 m pivot on maize, mainline, well and pump; tower, span and nozzle report | 1 pivot |
| `greenhouse` | Vegetable greenhouse | Four pepper tunnels on pressure-compensating dripline, tank, small pump and disc filter | 4 |
| `nursery` | Plant nursery | Three beds under overhead micro-sprinklers on a 4 × 4 m grid, elevated tank, small pump and disc filter | 3 |
| `coffee` | Coffee on contour lines | Three hillside blocks with curved laterals following the contours (guided block), PC dripline, well and pump | 3 |
| `bananas` | Banana plantation | Two blocks under pressure-compensating micro-sprinklers at 5 × 5 m, well with submersible pump and disc filter | 2 |
| `sugarcane` | Subsurface drip sugarcane | 20 mm PC dripline buried 0.3 m deep, 180 m laterals, buried submains, screen filter and air valve | 2 |
| `gravity` | Gravity-fed drip | Reservoir 40 m above the blocks, no pump: gate valve, pressure-reducing valve and filter on the mainline | 2 |
| `pasture` | Sprinkler-irrigated pasture | Three paddocks with impact-sprinkler lines at 12 × 18 m, reservoir, pump and check valve | 3 |
| `golf` | Golf hole | Tee with sprays, fairway with rotors on a triangular grid and green with rotors around the edge, pond and pump | 4 |
| `sectorPivot` | Sector pivot with end gun | 250 m pivot sweeping 270° with a 12 m³/h end gun, pond, 20 hp pump and gate valve | 1 pivot |
| `linear` | Linear move | 392 m lateral-move machine travelling 800 m along a canal, intake with a 30 hp pump | 1 linear |

Every example with valves also has its electrical part: a controller by the pump (or the control
head) and the wire routes beside the mainline to every valve. The design gives each valve a station
and a wire size, checks the solenoid voltage and adds wires, controller and connectors to the bill
of materials (Electrical tab). The pivot and linear examples have no solenoid valves to wire.

Examples open from the welcome screen (Help → Welcome and example gallery…), from the File →
Examples menu and from the URL. The same projects are in [examples/](examples/) as `.oci.json`
files, one folder per interface language (`examples/de/`, `examples/ja/`, … 20 in all): the same
drawing everywhere, with the names, crops and catalogue items in that language.

### URL parameters

| Parameter | Effect |
|---|---|
| `?example=garden` | Opens the given example (`orchard`, `garden`, `sportsField`, `rowCrop`, `pivot`, `greenhouse`, `nursery`, `coffee`, `bananas`, `sugarcane`, `gravity`, `pasture`, `golf`, `sectorPivot`, `linear`). |
| `?design=1` | Designs on load. |
| `?ai=1` | Opens the AI assistant beside the drawing (the site's "Open the AI assistant" button and the app shortcut). |
| `?tutorial=N` | Opens the interactive tutorial at step N (1 to 76). |
| `?lang=pt` (any code of section 13) | Language for this visit (does not change the saved preference). |
| `/pt/`, `/es/`, `/de/`, … | Entry page of each language under its code (all 20), with the same effect as `?lang` (the root page is the English one). |
| `#p=…` | A project shared by link (File → Share by link…): it opens as a copy in a new tab. The part after `#` is never sent to any server. |

---

## 3. Design workflow

The workflow follows established irrigation design practice (inventory and terrain, layout, zones,
management, mainline, materials and plotting), adapted to a browser app.

1. **Project details** (File → Project details…): name, client, site, designer and notes, which go
   to the sheet title block and the reports. Units (metric or US) in Tools → Units.
2. **Background information**: import the base (DXF, DWG, DGN, a PDF plan, KML/KMZ, SHP, GeoJSON,
   GPX, survey CSV, GeoTIFF, satellite image), draw boundaries, buildings and roads, or walk them
   with the device GPS (Draw → GPS in the field). Images and plans out of scale are fitted with
   Align by 2 points (AL). Georeference the project (File → Georeference…) when you want base maps,
   online elevation and climate or KML/GeoJSON/GPX export. Design → Automatic design → Detect
   vegetation in the image… turns the lawns and tree crowns of an aerial view into irrigated areas.
3. **Terrain**: draw contour lines (CT), breaklines (BRK) and spot heights (SP), import a survey,
   a LAS point cloud, a LandXML surface or an elevation GeoTIFF, or download the elevation from the
   internet for a coordinate. Generate contours from the model and check them in 3D or on the slope
   map.
4. **Hydraulic layout**: water supply (WS), pump (PU), mainline (MP), zone valves (V) and, downstream
   of each valve, zone pipes (ZP), laterals (SL), tapes (DT), emitters (OUT), devices (F). The
   **lateral block** (B) and **sprinkler grid** (AH) generators and the **automatic design** tools
   (Design → Automatic design) do the repetitive work: heads laid out, zoned and piped, fields cut
   into blocks, drip rings, turf templates, pivots fitted to a field. Irrigated areas (AR) carry
   crop, soil, efficiency and water balance; Design → Site climate… gives them the monthly climate.
5. **Management** (Design → System flows): system flows (which valves, pivots and valve-in-head
   stations open together, start time and duration). Without defined flows, all valves are assumed
   to open together (the worst case for the mainline and the supply). *Automatic…* groups the zones
   into the fewest flows that fit the supply flow (or a flow and a number of zones you choose),
   largest demands first; Design → Group zones for energy… groups zones of similar head, and
   Time-of-use tariff and flow schedule… chooses the start hours of least energy cost.
   **Wiring**: a controller (CTRL) and the wire routes (WR) to the valves, drawn by hand or along
   the pipe trenches (Zone → Automatic wire routes…), sized in the design.
6. **Check** (Design → Design check…): unconnected items, pipes crossing without a junction, dead
   ends, zones without emitters or mixing emitter kinds, missing catalogue items, missing terrain.
7. **Design** (F5): zones, mainline, telescoping, flushing, water hammer, mechanised machines and
   materials. You can also design only the zones, only the mainline, or just analyse with the
   current diameters (also automatically after every edit). The Mainline menu then checks the
   mainline further: hydraulic transients, air valves, a 24-hour simulation, on-demand operation,
   pipe criticality, roughness calibration and fertigation.
8. **Reports and plotting**: reports panel, PDF sheets (one sheet, or an overview and a sheet per
   zone or area) with title block, legend, north arrow, scale bar, bill of materials, construction
   details and charts; a commercial quote; exports to other CADs, GIS, BIM, EPANET and spreadsheets.

---

## 4. Interface

### Layout (wide screen)

- **Menu bar** at the top; on the right, the ▶ Design and Save buttons (amber when there are
  unsaved changes).
- **Project tabs** just below: several projects open at once (Ctrl+Alt+N new tab, Ctrl+Alt+W
  close, Ctrl+Alt+←/→ switch). Copy and paste (Ctrl+C/X/V) work across tabs and across browser
  windows, carrying layers and catalogue items missing at the destination.
- **Tool palette** on the left, by group (navigation, drawing, editing, terrain, zone, mainline,
  electrical, review).
- **Canvas** in the centre, with grid, snaps, overlays and the calculation progress card.
- **Side panel** on the right with three tabs: **Properties** of the selected item (with hydraulic
  results after the calculation and the submain position envelope for laterals), **Layers**
  (visibility, lock, colour, rename, create, remove) and **History** (a timeline of states, as in
  Photoshop: click to go back or forward).
- **Reports** below the canvas (F2), resizable.
- **AI assistant panel** (optional, [section 9](#ai-assistant-optional)) docked beside the canvas,
  opened and closed from Design → AI assistant… or its status-bar button.
- **Status bar** with cursor coordinates, active snap, typed command or coordinates, tool hint,
  toggles (snap, ortho, grid, polar tracking, keep connections), the GPS accuracy while the device
  GPS is on, the automatic-analysis chip, the AI assistant button and the app version.

In Arabic and Urdu the whole layout is mirrored (menus, panels and dialogs read right to left);
the drawing keeps its coordinates.

**Theme**: View → Theme → Dark (the default), Light or Follow the system (also in the phone menu).
The choice is saved and switches live, without losing the open projects, the selection or the open
dialogs. On the light canvas (white) the drawing colours follow the usual CAD rule: white and
near-white draw near-black and other light colours are darkened with their hue kept, so nothing
fades into the background; the data keeps its colours, and the selection shows in magenta instead
of yellow. Plots and exports (PDF, SVG, PNG sheets) are paper and do not change with the theme.

### Compact layout (phone and tablet)

Below 700 px of width the screen changes: ☰ menu at the top, tool bar by group at the bottom,
Done/Cancel buttons instead of Enter/Esc, properties, reports and the AI assistant in sliding
panels. Pinch to zoom, two fingers to pan, one finger draws.

### Menus

| Menu | Items |
|---|---|
| File | New project, New project tab, Close tab, Open project, Recent projects ▸, Save project, Version history, Autosave in the browser (on/off), Examples ▸, Import (DXF, DWG, DGN, PDF, KML/KMZ, SHP, GeoJSON, GPX, LandXML, LAS, EPANET, CSV/XYZ, images, GeoTIFF), Georeference selected image, Align by 2 points, Export drawing ▸ (DXF, DXF R12, DWG, PDF, SVG, KML, KMZ, GeoJSON, Shapefile, GPX, LandXML, IFC 4, EPANET, PNG), Export report ▸ (CSV, TXT, XLSX, PDF, controller programme), Share by link, Project details, Georeference |
| Edit | Undo, Redo, Select all, Copy, Cut, Paste, Duplicate selection, Delete selection, Materials of the selection, Save selection as block, Insert block, Modify ▸ (rotate, mirror, scale, offset, trim, extend, cut pipe, align by 2 points, array) |
| View | Zoom all, Zoom in/out, Grid, Labels, Wetted radii, Edit grips, Conditional labels, Device GPS, Overlay (none, velocity, pressure, diameters, min/max pressure per zone, densogram, terrain slope, terrain aspect), Base map ▸ (none, OpenStreetMap, OpenTopoMap, CARTO, Esri imagery/streets/topo, Google Maps roadmap/satellite/hybrid/terrain with your own API key, custom XYZ or WMS URL; needs a georeference), Google Maps API key…, Custom map URL…, Language ▸, Theme ▸ (dark, light, follow the system) |
| Draw | Line, Polyline, Rectangle, Circle, Arc, Spline, Hatch, Symbol, Text, Dimension, Angular dimension, Radial dimension, Ordinate dimension, Leader, Contour, Spot height, Irrigated area, Measure, Elevation profile, Comment, Revision cloud, GPS in the field ▸ (record a walk; finish it as an irrigated area, a closed outline or a line; mark a point at the current position) |
| Zone | Zone pipe, Sprayline (lateral), Drip tape / dripline, Outlet, Control valve, Misc. hydraulic, Junction, Lateral block, Sprinkler grid, Allowable submain position, Densogram, Device on the selected laterals, Turn the selected laterals into blank pipe, Controller, Wire route, Automatic wire routes |
| Mainline | Water supply, Mainline pipe, Pump, Misc. hydraulic, outlet and junction on the mainline, Select pump, Hydraulic transients, Air valves, 24-hour simulation, On-demand operation (Clément), Pipe criticality, Calibrate roughness from readings, Fertigation, Centre pivot / linear move |
| Design | Design parameters, Component catalog, System flows (management), Time-of-use tariff and flow schedule, Group zones for energy, Commercial quote, Design alternatives, Site climate, Terrain ▸ (contour, breakline, spot height, elevation profile, download elevation from the internet, generate contours from the model, 3D terrain view, clear profile, TIN or IDW interpolation), Automatic design ▸ (automatic sprinkler layout, sports turf and golf templates, subdivide a field into blocks, orchard drip rings, fit a pivot to the field, detect vegetation in the image), Design check, Fix automatically, Optimise design, AI assistant, Size zones, Size mainline, Design all, Analyse (existing sizes), Analyse automatically while editing, 3D terrain view, Clear results |
| Reports | The tabs of the panel |
| Tools | Lateral calculator, Pump & system curve, Water hammer, Solar pumping, Wetted bulb, Landscape water budget, Hose-reel traveller, Surface irrigation (furrows, borders, basins), Gated pipe, Units |
| Help | Interactive tutorial, Welcome and example gallery, Keyboard shortcuts, About |

### Keyboard shortcuts

With the drawing focused, type the alias and **Enter** or **Space**; a complete alias also runs by
itself after a pause. Aliases accept Portuguese, English and Spanish names (for example `LINHA`,
`LINE`, `LINEA`). The full list is in Help → Keyboard shortcuts.

| Group | Aliases |
|---|---|
| Navigation | `S` select · `P` pan · `Z` / `ZE` zoom extents · `ZI` / `ZO` zoom |
| Drawing | `L` line · `PL` polyline · `REC` rectangle · `C` circle · `A` arc · `SPL` spline · `H` hatch · `SY` / `I` symbol · `T` / `MT` text · `D` dimension · `DAN` angular dimension · `DRA` radial / diameter dimension · `DOR` ordinate dimension · `LE` leader · `ME` / `DI` measure · `NOTE` comment · `RC` revision cloud |
| Terrain | `CT` contour line · `BRK` breakline · `SP` spot height · `PR` profile · `AR` irrigated area |
| Editing | `RO` rotate · `MI` mirror · `SC` scale · `O` offset · `TR` trim · `EX` extend · `CUT` / `BR` cut pipe · `ARRAY` array · `E` erase · `CO` copy · `PA` paste · `U` undo · `REDO` · `ALL` select all · `DUP` duplicate · `AL` align by 2 points · `WBLOCK` / `SB` save selection as block · `INSERT` / `IB` insert block |
| Zone | `ZP` zone pipe · `SL` lateral · `DT` tape · `OUT` / `EM` emitter · `V` valve · `F` device · `J` junction · `B` block · `AH` sprinkler grid · `FE` submain envelope · `DENS` densogram |
| Electrical | `CTRL` controller · `WR` wire route · `WROUTE` automatic wire routes |
| Mainline | `MP` mainline pipe · `WS` supply · `PU` pump · `PV` pivot |
| Automatic design | `LAYOUT` sprinkler layout · `TPL` turf and golf templates · `SUBDIV` field blocks · `RINGS` drip rings · `PFIT` pivot fit · `VEG` vegetation |
| Analyses | `SURGE` transients · `AV` air valves · `EPS` 24-hour simulation · `DEMAND` on-demand operation · `CRIT` criticality · `CALIB` roughness calibration · `FERT` fertigation · `TARIFF` tariff schedule · `EGROUP` energy grouping |
| Design and files | `RUN` design · `CHK` check · `FIX` fix automatically · `OPT` optimise · `AI` / `IA` / `ASK` AI assistant · `REP` reports · `SAVE` · `OPEN` · `OS` snap · `OR` ortho · `GS` grid snap · `GR` grid |

| Key | Action |
|---|---|
| F2 | Show/hide reports |
| F3 | Toggle object snap |
| F5 | Design all |
| F7 | Grid |
| F8 | Ortho |
| F9 | Grid snap |
| F10 | Polar tracking step: off, 15°, 30°, 45°, 90° |
| Home | Zoom extents |
| Enter | Finishes the polyline/lateral being drawn; when selecting, repeats the last tool |
| Esc | Cancels the tool or clears the selection |
| Del | Deletes the selection |
| Shift (held) | Locks the segment to 0°, 45°, 90° |
| Ctrl+Z / Ctrl+Y | Undo / redo |
| Ctrl+A, Ctrl+D | Select all, duplicate |
| Ctrl+C / X / V | Copy, cut, paste (also across tabs and windows) |
| Ctrl+S, Ctrl+O, Ctrl+I | Save, open, import |
| Ctrl+Alt+N / W / ← / → | New tab, close tab, switch tabs |

While a tool waits for a point, the same command line takes coordinates in the display unit:
`x,y` absolute, `@dx,dy` relative to the previous point, `@d<a` polar (distance and angle in
degrees, counter-clockwise from east) or a bare distance along the direction of the cursor, then
Enter (`;` separates numbers written with a decimal comma).

Shortcuts are captured natively (window keyboard listener in the browser, `HardwareKeyboard` on
desktop) and work whatever widget has the focus, except while a menu or a dialog is open.

---

## 5. Drawing and editing

### Drawing entities

Line, polyline (open or closed), rectangle, circle, arc, spline (smooth curve through the points),
hatch (lines or solid), symbol (north arrow, tree, building, tank, well, valve box, pump house,
gate, filter station), text, linear, angular, radial and diameter (Ø) dimensions, ordinate
dimension (the X or Y of a point from the drawing origin: a vertical leader writes X, a horizontal
one Y), leader, image (georeferenced raster, PDF plan or picture placed by hand), contour line,
breakline, spot height and irrigated area. Review entities: **comments** (a note with its author,
date and a resolved flag) and **revision clouds** (a scalloped outline with the revision tag, date
and description; the sheet's revision table lists them), each with its report tab.

### Snaps

Endpoints, midpoints, centres, quadrants, intersections (lines, arcs and circles), perpendicular and
tangent from the previous point, extension beyond the end of a line, hydraulic nodes, "on" pipes
and laterals (the nearest point of the segment), circle perimeters, grid, ortho, polar tracking
(F10) and 45° lock with Shift. The tolerance is in pixels, so it does not depend on the zoom. The
marker changes shape with the snap type.

### Selection and grips

Click selects; Shift+click toggles; a window dragged left to right selects what lies entirely
inside it and right to left what it crosses (the usual CAD convention). Up to 60 selected entities show
**grips**: drag a vertex to move it, drag the midpoint of a segment to insert a vertex, Ctrl+click a
vertex to remove it. With *keep connections* (on by default) dragging a pipe node takes the
valves, items and wire routes sharing it along; dragging a wire vertex moves only the wires.

### Transformations

Move (drag), rotate, mirror (keeping the original or not), scale, offset, trim and extend against
the selected or visible entities, cut pipes, rectangular or polar array and alignment by two
points (moves, rotates and scales an image or an imported drawing in one go). Inserting a valve,
junction, pump or device on a pipe splits the pipe at that point. Zone → Device on the selected
laterals… puts the same device (regulator, gate valve…) at the inlet of every selected lateral and
tape; Turn the selected laterals into blank pipe keeps their path without emitters.

### User blocks

Edit → Save selection as block (`WBLOCK`) keeps the selection as a named block with a base point
(a valve manifold, a standard head layout, a title); Insert block (`INSERT`) places copies with a
rotation and a scale at a picked or typed point, each insertion one undo step with new ids and the
layers it lacks. The library travels in the project file and exports as DXF/DWG block definitions.

### Layers

Every entity type is born on its default layer (DRAWING, TEXT, DIMENSIONS, CONTOURS, BREAKLINES,
SPOT_HEIGHTS, DEM, ZONE_PIPES, MAINLINE_PIPES, SPRAYLINES, TAPES, OUTLETS, WETTED_RADII,
CONTROL_VALVES, WATER_SUPPLY, PUMPS, MISC_HYDRAULIC, JUNCTIONS, AREAS, LABELS, IMAGES, HATCHES,
SYMBOLS, PIVOTS, WIRES, CONTROLLERS, COMMENTS, REVISIONS). Layers imported from DXF/DWG/KML/PDF are
preserved. A layer can be hidden (leaves the drawing, the snap and the selection) or locked
(visible but not editable).

### Labels

View → Labels shows names and sizes; View → Conditional labels… adds rules that write a result
next to the pipes (velocity, flow, pressure, head loss, diameter), outlets (pressure, flow) or
valves (flow, pressure, downstream pressure) where it is above or below a value, or always, in a
colour of their own (velocity above 1.5 m/s in red, say). The rules travel with the project.

### History

Every action produces a named state (add line, move 3 items, design, import…). Undo and redo walk
up to 150 states (fewer in very large drawings: the copies kept stay below 400 000 entities); the
History panel jumps to any of them. The dialogs that edit the project in place (details,
parameters, units, catalogue, management) also make one undo step each, however they are closed
(OK, Esc or a click outside): the edits are kept, the project is marked as modified and results
computed with the old settings are discarded. A dialog that generates something (a layout, a block
of laterals, the routes of the wires) and every answer of the AI assistant that changed the
project are one step too.

---

## 6. Hydraulic network

### Hydraulic entities

| Entity | Alias | Layer | Role in the calculation |
|---|---|---|---|
| Water supply | `WS` | WATER_SUPPLY | Origin of the mainline. Calculated pressure (well with a negative water level, reservoir with a positive height) or fixed (mains with design and maximum pressure and flow). |
| Pump | `PU` | PUMPS | Catalogue H(Q) curve, with speed ratio, or a variable-speed drive that holds a target outlet pressure between a minimum and the full speed; efficiency and NPSH required curves when the catalogue has them; operating point in the system-flow analysis; optional hour meter. |
| Mainline pipe | `MP` | MAINLINE_PIPES | From the supply to the valves; fixed diameter or sized (`computerSized`). |
| Zone valve | `V` | CONTROL_VALVES | Separates mainline and zone; names the zone; may have a fixed downstream pressure for a detailed analysis. |
| Zone pipe | `ZP` | ZONE_PIPES | Submains and distributors downstream of the valve. |
| Lateral (sprayline) | `SL` | SPRAYLINES | Pipe with equally spaced emitters: emitter and nozzle from the catalogue, spacing, first-outlet offset, arc, riser height, depth. |
| Tape / dripline | `DT` | TAPES | Integral emitters defined by the catalogue item; inlet pressure, regulated or not, flushing flow. |
| Single emitter | `OUT` | OUTLETS | Sprinkler, micro-sprinkler, dripper, bubbler, gun or demand point on a zone pipe. Drawn on the mainline it is a valve-in-head sprinkler: a station of its own, or one station with the heads that share its station name. |
| Device | `F` | MISC_HYDRAULIC | Gate valve, filter, pressure regulator (with setting), pressure-sustaining valve (upstream setting), hydrant with flow limiter (flow setting), master valve, meter, backflow preventer, air valve, check valve; in a zone or on the mainline. |
| Junction | `J` | JUNCTIONS | Explicit node, with optional fixed elevation. |
| Irrigated area | `AR` | AREAS | Polygon with crop (FAO-56 table or free text) and planting date, soil texture and slope, irrigation method, ground cover, water salinity, effective rain method, net depth or water balance (ETo, Kc, available water, root depth, allowable depletion), efficiency, wetted fraction, emitters per plant and, for landscapes, the plant water use of its hydrozone. |
| Centre pivot / linear move | `PV` | PIVOTS | Machine with radius, spans, applied depth, cycle, end pressure, end gun, cost. A demand on the mainline; its machine data (sprinkler package, drive train and timer, corner arm, variable-rate prescription, electrical supply) open from Properties. |
| Controller | `CTRL` | CONTROLLERS | Irrigation controller: stations, output voltage (24 V AC), most stations at once, cost, sensors and accessories (rain, soil moisture, flow, freeze and wind sensors, pump start relay, surge protection). Powers the valve solenoids through the wire routes. |
| Wire route | `WR` | WIRES | Path of the wires from a controller through the valves (a trench or conduit), drawn by hand or by Automatic wire routes. Routes sharing a vertex connect; a controller or valve on a vertex or on the route joins it. |

### Connection rules

- **Coincident vertices connect.** Two pipes sharing a vertex (within the connection tolerance,
  0.05 m by default) form a node. A pipe ending in the middle of another is joined by an automatic
  tee. Emitters, valves, pumps and devices placed on a pipe split it.
- **The valve separates the worlds.** Everything downstream of a zone valve belongs to that zone;
  the mainline runs from the supply to the valves. Zone items do not connect to mainline items
  without a valve between them.
- **Tapes and laterals must not touch across zones.** Since coincident vertices connect, the ends
  of tapes in neighbouring blocks must stay apart (a service strip between blocks), or the two
  zones will be calculated as one. The design check warns about unconnected items, pipes crossing
  without a junction and dead ends.
- **Laterals are lumped.** In the graph each lateral becomes a sequence of nodes with aggregated
  emitters (up to 100 nodes per lateral by default, adjustable), which keeps the calculation fast
  even with hundreds of emitters per line.
- **Valve-in-head stations are scheduled like valves.** A head on the mainline opens when its
  station runs. System flows list the stations next to the zone valves and pivots; a station some
  flow lists runs only in those flows, at its nominal pressure, and one that no flow lists runs in
  every flow (and is reported). The controller wires each station like a valve, the solenoids of
  its heads in parallel.
- **Wires follow their own graph.** Wire routes do not touch the hydraulic network: each valve
  reached from a controller along the routes gets a station (the nearest valve is station 1) and
  a station conductor of its own; all of them share the common conductor along the routes. A
  master valve opens with every zone, on output 0.

### Generators

- **Lateral block** (B): polygon, direction, lateral spacing, offset of the first one, lateral with
  emitters or tape, submain position (start, centre, end), valve (position and model), valve stub
  length, names. If a line, polyline, contour line or spline is selected when the dialog opens it
  can act as a guide: the laterals follow the curve (parallel to a contour line or a curved
  boundary) and are clipped by the polygon. The submain runs through the feed point of every row
  on the chosen side, stepping inside the field where a row does not reach that line (an L-shaped
  field); rows the polygon cuts in several pieces (a U-shaped field, a curved row clipped in two)
  are fed by branches joined to it, so every lateral is connected.
- **Sprinkler grid** (AH): polygon, sprinkler and nozzle, spacings, square or triangular pattern,
  direction and design pressure.
- **Densogram** (Zone → Densogram, `DENS`): map of the water applied by the sprinklers and
  micro-sprinklers as they are drawn (position, arc, orientation and, after a design, the
  pressure of each one), with Christiansen CU, low-quarter DU, scheduling coefficient (mean over
  the driest 5 %) and dry spots, measured inside every irrigated area against its own mean (a
  lawn of sprays next to one of rotors is judged separately); the measured radial profile of a
  nozzle when the catalogue has one, else a triangular, elliptical or uniform profile; an optional
  wind (speed and direction) that drifts the water downwind; cell size, zones; the map is drawn
  on the canvas and the grid exports to CSV.
- **Submain position envelope** (FE): for every selected lateral, paints in green the stretch where
  the submain can feed it while keeping the pressure window, taking the terrain into account.

### Automatic design (Design → Automatic design)

Each tool shows its result live and generates it as one undo step.

| Tool | Alias | What it makes |
|---|---|---|
| Automatic sprinkler layout | `LAYOUT` | Heads for a lawn or bed (corners, then edges, then the interior, head to head, buildings and beds left out) with matched-precipitation nozzles and the CU/DU/SC preview; optionally zoned by flow (never mixing precipitation classes) and routed: valves on the mainline, by their zones or in a manifold, zone pipes as trees through the heads, a mainline tree from the supply. |
| Sports turf and golf templates | `TPL` | Football pitch with 3, 4 or 5 rows of rotors, running-track infield, golf green ringed by part circles, tee and fairway on a triangular grid. |
| Subdivide a field into blocks | `SUBDIV` | Blocks of equal net area no larger than an area or a flow, as strips or a grid, with service roads, each with its submain side and valve, filled by the block generator and fed by a mainline. |
| Orchard drip rings | `RINGS` | A ring of dripline or drippers round every tree of a planting grid or of surveyed trees, joined to laterals along the rows, a submain and the valve. |
| Fit a pivot to the field | `PFIT` | The largest full circle clear of the obstacles, or the part-circle pivot that waters the most of the field, with the machine length in standard spans. |
| Detect vegetation in the image | `VEG` | Lawns, trees and shrubs found by image processing on this device (no service) in the base map on screen or a selected aerial photo, created as irrigated areas (with presets per class) and exclusions. Check that the imagery's terms of use allow tracing it. |

---

## 7. Component catalogue

The project catalogue has seven groups: **pipes**, **emitters** (with nozzles), **tapes**, **valves
and devices**, **pumps**, **fittings** and **wires**. All internal hydraulic values are in SI.

| Group | Main fields |
|---|---|
| Pipes | DN, inner diameter, material (which sets the Scobey and Manning coefficients and the derating of PVC and PE pressure classes with warm water), Hazen-Williams C, roughness, pressure rating, usage (lateral, zone, mainline), cost per metre, supplier, code |
| Emitters and nozzles | Kind (sprinkler, micro-sprinkler, dripper, bubbler, gun, demand point), curve `q = k·H^x`, wetted radius `R = a·H^b`, arc, default, minimum and maximum pressure, manufacturing CV, flow tolerance, inlet diameter, riser height, cost; a nozzle curve can be fitted to the rows of its data sheet (pressure, flow and radius pasted as a table), and a measured radial profile (catch-can test) feeds the densogram |
| Tapes | Inner diameter, emitter spacing and curve, barb coefficient, CV, default, minimum and maximum inlet pressure, tolerances above and below, rating, cost per metre |
| Valves and devices | Kind (zone, master, PRV, pressure-sustaining, flow control, gate, check, backflow, filter, meter, air valve, other), diameter, loss `h = K·Q^n + C`, minimum and maximum flow, default setting, cost |
| Pumps | (Q, H) points fitted to a parabola, efficiency (or an efficiency curve), NPSH required curve, power, maximum flow, submersible or surface, the mains frequency the curve was measured at, cost |
| Fittings | Kind (coupler, 90° and 45° elbow, tee, cross, reducer, end cap, adapter, lateral take-off, tape end, riser), diameters, cost |
| Wires | Conductor section (mm²), resistance (Ω/km), cost per metre, supplier, code; CSV columns `mm2` or `awg`, `ohmKm` (copper is assumed when only the section is given) |

Any item can also carry the FINAME code under which it is credentialed for financing by the
Brazilian development bank BNDES; the bill of materials and the quote show it.

The **default catalogue** ships 17 pipes (PE 16–50 mm, PVC DN 35–250, HDPE 110 and 160, 6" steel),
10 emitter families (PC and turbulent drippers, micro-sprinklers, PC bubbler, impact sprinkler, gun,
garden rotor and spray, demand point), 6 tapes and driplines, 36 valves and devices (1" to 6",
master valves, pressure-sustaining valves and hydrants with flow limiter among them), 18 pumps
(centrifugal 1 to 100 hp, submersible 3 to 30 hp) and about 330 fittings generated for every
nominal diameter (couplers, 90° and 45° elbows, tees, crosses, end caps, adapters and reducers, plus
lateral take-offs, tape ends and risers) and 12 copper wires (1 to 10 mm² enabled, AWG 18 to 8
disabled: enable them where AWG is the norm), with translated names and illustrative prices.

The editor (Design → Component catalog…) edits, duplicates and removes items, imports and exports
JSON, CSV per group and **Excel** (export, fill in prices in the spreadsheet and import it back), sets
the default catalogue for new projects and restores the original.

### Prices and currency

Every price of a project (catalogue, energy tariff, pivot machines) is in one currency, stored as an
ISO 4217 code with the symbol shown in tables and reports (Design → Design parameters → Currency).
A new project takes the currency of the machine's region when the system locale of the interface
language names one (`pt-PT` → EUR, `en-IN` → INR, `de-CH` → CHF), else the currency of the most
populous country of the language (pt BRL, en USD, es MXN, de/fr EUR, ja JPY, zh CNY, hi/mr/te/pa INR,
bn BDT, ur PKR, ar EGP, ru RUB, tr TRY, id IDR, vi VND, ha NGN, sw TZS). The illustrative prices of the
default catalogue and the default energy tariff (0.75 R$/kWh) are written in reais and converted with
reference exchange rates (European Central Bank and exchangerate-api.com, 2026-09-21), so every
language gets the same design; they only order the options for the economic sizing and should be
replaced by a local price list. Choosing another currency asks whether to convert every price, with
the reference rate offered and editable, and becomes the currency of new projects. The saved default
catalogue remembers its currency and is converted for projects in another one. The gallery examples
use the currency of their language (in the app, the user's currency). The list includes the Chilean
UF (`CLF`), the inflation-indexed unit public subsidy contests ask budgets in (taken as CLP 40 000;
type the day's value when converting).

Items without a price (manufacturer packs come without them) are reported by the design assistant
(`bom_unpriced`); the bill of materials leaves them out of the totals and the economic sizing prices a
pipe without cost in proportion to its wall cross-section, calibrated on the priced pipes of the same
material, so the diameters keep their order.

### Manufacturer catalogues (`.oci.cat`)

Fourteen packs ship with the app (259 items): Hunter, Rain Bird, Toro, Netafim, Rivulis,
NaanDanJain, Jain, Nelson and Senninger (sprinklers, micro-sprinklers, drippers, tapes and
driplines, pivot sprinklers, big guns, valves and regulators), Irritec (driplines and drippers),
Bermad (hydraulic valves), Schneider (centrifugal and 4" submersible pumps, with curves measured at
60 Hz), and Amanco Wavin and Multilit (PVC irrigation pipes, NBR 14312). The data come from the
manufacturers' published tables: nozzle curves `q = k·H^x` and radii `R = a·H^b` fitted by least
squares to the pressure, flow and radius rows (the radius anchored at the design pressure), emitter
constants, exponents, inner diameters and barb losses (Kd) as printed, pressure ranges and wall
classes, valve losses fitted to the loss tables (or taken from Kv), and pump curves from the
selection tables (pump efficiency estimated from the rated power, since the tables omit it). Each
pack lists its source documents (`sources`). Prices are left at zero; a pack that carries prices
states their currency (`currency`) and is converted to the project currency when added; a pump
states the frequency its curve was measured at (`hz`), so on other mains (Design parameters) a
fixed-speed pump turns in proportion. They live in [catalogs/](catalogs/) as JSON files, one per
manufacturer, plus an `index.json`. Through the *Manufacturer catalogues…* dialog you add a pack to
the project, import an `.oci.cat` file or load a pack or a whole index by URL, which lets any dealer
or community keep its own repository. The project catalogue is exported in the same format. The
complete format, with the fields of every group and the contribution rules, is in
[catalogs/README.md](catalogs/README.md); `dart run tool/gen_catalogs.dart` validates the packs
(unique ids, plausible curves) and rebuilds the index.

---

## 8. Terrain

- **Elevation sources**: drawn contour lines (with automatic increment and optional smoothing),
  breaklines (`BRK`: ridges, channels and banks the surface must fold along), spot heights (the
  elevation is asked at every click), survey points (CSV, TXT, XYZ, PNEZD), DXF/DWG/DGN with
  elevation (polylines on contour layers or with an elevation), KML with altitude, shapefile with Z
  or an elevation attribute, GPX waypoints, LAS point clouds (the ground class), LandXML surfaces
  and points, elevation GeoTIFF (single-band raster) and **online elevation**.
- **Digital terrain model**: Delaunay triangulation (TIN) constrained by the breaklines, with linear
  interpolation inside the triangles, exact on planar slopes, and inverse-distance interpolation as
  an alternative and as a complement outside the convex hull. Contour lines are sampled every 5 m
  (adjustable). The TIN takes up to 12 000 samples: a larger terrain is triangulated from a uniform
  subset, which the app says once per project (the IDW interpolation uses all of them); point
  clouds and LandXML surfaces are thinned on a grid as they are read.
- **Online elevation** (Design → Terrain → Download elevation from the internet (DEM)…): a grid of
  points over the project or over the visible area is queried from free public services with no
  key: Terrain Tiles on AWS Open Data (SRTM 30 m, GMTED, ETOPO1; the default), Open-Meteo
  (Copernicus GLO-90; 600 coordinates per minute) and, in the desktop builds, OpenTopoData (SRTM
  30 m, ASTER 30 m; its public API sends no CORS header, so browsers cannot use it). The download
  replaces the heights you entered by default, since they are usually on another datum than the
  model. In an empty project you can just paste the coordinate of the site (decimal, Google Maps
  link or degrees/minutes/seconds): the drawing origin moves there and the elevation is downloaded
  in a square around it. When it finishes, contour lines can be generated automatically with an
  interval chosen from the relief.
- **Tools**: generate contour lines from the model (derived curves that do not feed the model back),
  3D view of the terrain with the pipes draped on it, slope and aspect maps (View → overlay, with
  the share of the area in each slope class), profile along a path (with the pipe and the
  hydraulic grade line when there are results); the pressure of every emitter accounts for the
  ground elevation plus the riser height minus the burial depth.

---

## 9. Calculation and sizing

### Design parameters (Design → Design parameters)

| Group | Parameters and defaults |
|---|---|
| Hydraulics | Friction formula: Hazen-Williams (default), Darcy-Weisbach, Scobey or Manning; water temperature 20 °C (viscosity, vapour pressure and the derating of PVC and PE pressure classes); local losses as 5 % of the length (default) or the K of the bends and tees found in the drawing, enabled; C scale and offset (ageing); connection tolerance 0.05 m; at most 100 lumped nodes per lateral |
| Maximum velocities | 2.0 m/s in laterals, 1.5 m/s in zone pipes, 2.0 m/s in the mainline |
| Sizing | LP method (default) or velocity + pressure window (greedy); diameters per lateral (1), per submain (3) and per mainline (3); maximum pressure variation in the zone (0 = derived from the emitter flow tolerance); emitters per plant (1) |
| Economics | Interest 10 %, term 10 years, energy 0.75 per kWh, pump efficiency 65 %, 2000 h/year for the mainline and 500 h/year per zone, capital × energy trade-off enabled, currency of the region or language (see *Prices and currency*); mains frequency 60 Hz (a fixed-speed pump whose curve was measured at another frequency turns in proportion: a 60 Hz curve on 50 Hz mains runs at 5/6 of the speed and 69 % of the head) |
| Flushing and safety | Tape flushing velocity 0.3 m/s with 1 m minimum pressure at the open end; water hammer check enabled with valve closure time (0 = instantaneous) |
| Materials | Automatic fitting selection enabled; 6 m pipe sticks to count couplers |
| Terrain | Triangulation (default) or inverse-distance interpolation; contour densification 5 m |
| Electrical | 24 V AC solenoids: inrush current 0.37 A, holding current 0.22 A, minimum voltage at the solenoid 20 V; wire slack 10 % over the route length |

### Calculation steps

1. **Graph construction**: entities → nodes and links; coincident vertices merged; point items
   inserted into pipes; laterals lumped; terrain elevation at every node; zones identified from
   every valve; fittings (bends and tees) found when the local losses come from them.
2. **Zones**, one by one:
   - initial sizing by maximum velocity, which also provides the nominal flows;
   - **LP**: every sizable unit may be built from fractions of the candidate diameters; the linear
     programme minimises the annualised pipe cost plus the energy cost of the inlet pressure,
     subject to the pressure window of the critical emitters (the end, the highest and the lowest
     point of every lateral, every single emitter). If the analysis does not confirm the window, the
     emitters at minimum and maximum pressure become constraints and the LP runs again (up to four
     rounds);
   - **pressure class**: the LP and the greedy steps offer each unit only the pipes whose class, at
     the water temperature, withstands the pressure the analysis found there (PVC loses part of
     its class above 25 °C and PE above 20 °C); when a pass ends with a pipe below its pressure,
     the unit's requirement rises and the zone is sized again (up to three passes). With nothing
     in the catalogue strong enough the unit is sized as before and the class is reported exceeded;
   - **repair**: greedy diameter increase along the critical path until the window is met;
   - **rationalisation**: non-increasing diameters from upstream to downstream and telescoping
     within the limit of diameters per unit;
   - **detailed analysis**: non-linear network with pressure-dependent emitters; the pressure
     downstream of the valve is chosen by bisection so that the mean emitter pressure equals the
     nominal one (or, for regulated tapes, to guarantee the minimum submain pressure);
   - results: zone flow, minimum and maximum pressures and the allowable ones, allowable and actual
     variation, required valve pressure, valve loss, uniformity (Christiansen CU, low-quarter DU,
     Keller-Karmeli EU with the manufacturer CV and emitters per plant, statistical uniformity, flow
     variation), overlap CU for sprinklers with a wetted radius, pipe table with pressures,
     elevations and velocities, emitter table.
3. **Mainline**, per system flow: demand and required pressure of every valve, pivot (what its
   sprinkler package needs) and scheduled valve-in-head station, LP over all flows with the energy
   cost weighted by the hours of each and the same pressure-class passes; in a looped mainline the
   sizes decide how the flow splits, so the LP is solved again with the flows of the new sizes
   until the choice settles (up to four more times). Then the analysis of every flow with pumps
   (operating point; a variable-speed drive finds the speed that holds its target outlet pressure;
   the NPSH available is compared with the pump's curve), pressure-reducing, pressure-sustaining
   and flow-control valves, check valves and fixed- or calculated-pressure supplies; duty of every
   supply (flow, available pressure, required pressure, deficit) and annual energy.
4. **Telescoping**: pipes with more than one diameter are split into entities, largest diameter
   upstream, and the affected zones are re-analysed.
5. **Flushing**: every zone with tapes is analysed with the ends open at the flushing velocity;
   reports the flushing flow, the required valve and upstream pressure, number of tapes, minimum end
   pressure and maximum velocity.
6. **Water hammer**: for the worst segment of every pipe, wave celerity from material and wall,
   Joukowsky surge for the operating velocity, critical time 2L/a and comparison of the maximum
   static pressure plus surge with the pipe rating, taking the closure time into account (the full
   transient analysis is Mainline → Hydraulic transients…, below).
7. **Mechanised machines**: the sprinkler package and timer chart of every centre pivot and linear
   move and, when their data are given, the corner arm, the variable-rate prescription and the
   electrical design (see *Mechanised machines and field calculators*).
8. **Valve wiring** (when the drawing has a controller or a wire route): shortest route from each
   controller to every valve, stations in order of distance, and, for every controller, the common
   wire and the station wire of every valve with the lowest cost such that each solenoid, while
   opening (inrush current) with the other valves of its system flow already on (holding
   current), gets at least the minimum voltage. The drop is `I·R·L` on the station conductor plus,
   on every stretch of the common, the current of the valves beyond it; lengths include the slack.
   Without system flows every valve is on at once, as in the hydraulic design. A master valve is
   on with every zone (output 0, its own wire, its current on the common), and every valve-in-head
   station takes a station with its heads in parallel. Reports stations, route and wire lengths,
   wire sizes, solenoid voltages and the peak current of every controller; warns about valves
   without wire, routes reaching no controller, controllers with too few stations or opening more
   valves than they drive at once, and voltages below the minimum.
9. **Materials**: pipes by diameter and rating, emitters, tapes, valves, devices, pumps (with
   automatic selection from the catalogue and a standard IEC motor; pump hour meters), pivots with
   towers, sprinklers and regulators, **fittings selected automatically** from the geometry
   (couplers per stick, elbows, tees, crosses, reducers, end caps, lateral take-offs, tape ends,
   risers) and the electrical items (wires by size, controllers and their accessories, two
   waterproof connectors per valve), with costs, FINAME codes where the catalogue has them,
   annualised cost (capital recovery factor) and energy; also split by sector (Materials by sector)
   and for the current selection (Edit → Materials of the selection…).

The calculation runs in a **Web Worker** in the browser (or in an isolate on desktop) and returns
the resized entities and the results to the interface; while it runs, editing is blocked so that
no change is lost, but navigation, reports and other tabs stay free. With Design → Analyse
automatically while editing, a moment after every edit the design is analysed again without
sizing, so pressures, flows and messages follow the drawing (a chip in the status bar shows it).

### Design check

| Code | Severity | Meaning |
|---|---|---|
| `unconnected` | error | Hydraulic item not connected to the network |
| `no_supply` | error | No water supply |
| `no_valves` | error | No zone valve (nor pivot) |
| `zone_no_emitters` | error | Valve without emitters downstream |
| `spec_missing` | error | Item references a component that is not in the catalogue |
| `zero_length` | error | Zero-length pipe |
| `pivot_unconnected` | error | Pivot away from a mainline node |
| `pipes_cross` | warning | Pipes crossing without a junction |
| `mainline_dead_end` | warning | Dead end on the mainline |
| `duplicate_item`, `duplicate_zone_name` | warning | Overlapping items; zones with the same name |
| `tiny_segment` | warning | Segment shorter than the tolerance |
| `supply_no_head` | warning | Fixed-pressure supply without a pressure |
| `zone_mixed_emitters` | warning | Zone mixing drip with overhead emitters, or heads whose application rates differ by more than 1.8 times (sprays with rotors, part circles without matched nozzles) |
| `zone_dead_end`, `area_no_emitters`, `no_terrain`, `looped_mainline`, `no_hydraulics` | information | Situations worth a look that do not prevent the calculation |
| `elec_stations`, `elec_voltage` | error | Controller with fewer stations than valves wired to it; solenoid voltage below the minimum even with the thickest enabled wire |
| `elec_unwired`, `elec_wire_orphan`, `elec_ctrl_unwired`, `elec_no_controller`, `elec_no_wires`, `elec_simultaneous` | warning | Valve without a wire to a controller; route reaching no controller; controller off the routes; routes without a controller; no wire enabled in the catalogue; a system flow opening more valves than the controller drives at once |

### Calculation messages

Every zone, system flow and step may emit warnings, shown in the Messages tab and next to the item:
pressure outside the window, velocity exceeded, pressure rating exceeded (in operation or by water
hammer), valve outside its flow range, pump off its curve, NPSH available below what the pump
requires, a variable-speed drive that cannot reach its target pressure or would need less than its
minimum speed, supply flow or pressure exceeded, pressure deficit at a valve, pivot or valve-in-head
station (or a station above its window, or in no flow), infeasible LP (with the greedy method taking
over), looped mainline (the LP sizes it on tree paths and repeats; the final analysis checks),
missing catalogue components, pivot application rate above the soil limit, among others.

### Design assistant: explanations and one-click corrections

The Messages tab and the design check show every problem as a card: what happened, **why it
matters** and **how to fix it**, a button to show the item on the drawing, **Ask the AI** (which
opens the AI assistant with a question about that message; nothing is sent until you press Send)
and, when there is one, a button that fixes it (each correction is one undo step). Besides the
drawing and the results, the assistant checks **impossible settings**: velocity, hours, economic
parameters, tolerance, zone variation or water temperature out of physical ranges, no enabled
catalogue pipe for a use, supply maxima below the design values, zones in no system flow, empty
flows, emitter pressures outside the nozzle range, pump speeds out of range.

- **Corrections**: join an item dropped next to the pipe, remove zero-length pipes, repeated
  vertices and duplicates, rename repeated zones, choose (or insert) the pump with the lowest
  life-cycle cost, replace a surface pump that cannot lift the water with a submersible one, a pipe
  of a higher pressure class, a valve of the right size, split the zones into more system flows,
  restore default parameters, add the zones left out to a flow, the nominal emitter pressure, a
  controller with enough stations (the next standard size), enable the catalogue wires, and
  more.
- **Fix automatically** (Design menu, `FIX`): safe corrections and designs in rounds until nothing
  more can be fixed, all in one undo step, with a summary of what changed and what needs a decision.
- **Optimise design** (Design menu, `OPT`): lowest annual cost (annualised investment + energy)
  that meets every requirement — LP sizing, the smallest suitable valves and the pump with the
  lowest life-cycle cost; kept only when it improves, with a before / after comparison.
- After a design with errors the Messages tab opens by itself and shows how many problems there are.

### Analyses of the mainline and of the operation

These run on the designed project (each says what is missing when there is no design or no water
supply); what they propose (inserted air valves, start hours, system flows, wire routes, a C
factor) is applied as one undo step.

| Analysis | Menu, alias | What it does |
|---|---|---|
| Hydraulic transients | Mainline, `SURGE` | Method of characteristics on the mainline of every system flow: the zone valves closing in the closure time, a power failure tripping the pumps (inertia estimated from power and speed, check valves closing on reverse flow) and an isolation valve closing; wave celerity from each pipe's wall, vapour cavities (column separation), the air valves drawn acting as combination valves; head and pressure envelopes per pipe against its class and against vacuum, the profile along the critical path, time series at the pump and at the worst point, and findings. |
| Air valves | Mainline, `AV` | Profile of every path from a supply to an end of the mainline and the air valves AWWA M51 practice asks for (high points, slope changes, long runs, pump discharge, check valves, line ends, low grade line, transient vacuum), sized by the orifice air flow, inserted with the catalogue item that fits. |
| 24-hour simulation | Mainline, `EPS` | The system flows over a day at their start hours and durations, every pump on while a flow it serves runs; energy and cost per pump and hour at the tariff of the parameters, with an optional peak band. |
| On-demand operation | Mainline, `DEMAND` | Design flows of a branched network of hydrants by Clément's formula and the check against random configurations of open hydrants (FAO 59): reliability and pressure deficits per hydrant; hydrants may have flow limiters. |
| Pipe criticality | Mainline, `CRIT` | Every pipe closed in turn (N−1): the demand cut off and the demand the remaining pressures cannot deliver, pipes ranked. |
| Roughness calibration | Mainline, `CALIB` | Hazen-Williams C factors (one, or one per material group) fitted to pressures and flows read in the field, by weighted least squares with the network solver in the loop. |
| Fertigation | Mainline, `FERT` | Travel times of a product injected at the supply or the pump to every valve and on to the farthest emitter, the injection plan (pre-wetting, injection, flushing), amounts for a dose per hectare and the check of a venturi injector. |
| Time-of-use tariff and flow schedule | Design, `TARIFF` | Energy price by band of the day, demand charges and seasons, and the Brazilian rural irrigation discount (a window of up to 8 h 30 min a day in up to three blocks, never between 17:00 and 21:30, ANEEL Normative Resolution 1,000/2021, art. 186, and MME Normative Ordinance 137/2026); the start hours of least daily cost. |
| Group zones for energy | Design, `EGROUP` | Zones (and pivots and valve-in-head stations) grouped into system flows of similar required head, so the pump does not give every zone the pressure of the most demanding one; compared with the grouping by flow. |
| Automatic wire routes | Zone, `WROUTE` | Wire routes along the pipe trenches from every controller to its valves, master valves and pump-start relays (shortest paths for conventional wiring, a Steiner-like tree for a two-wire path), and the sizing of a two-wire (decoder) system on them: decoders, cable, voltage at every decoder, grounding points. |

### Agronomy, mechanised machines and field calculators

- **Site climate** (Design → Site climate…): monthly normals of ETo (FAO Penman-Monteith), rain
  (mean and dependable) and solar radiation, downloaded for the site from Open-Meteo (historical
  weather, ERA5) or NASA POWER, or typed in, kept in the project with their source.
- **Crop requirement** (report tab): every irrigated area with a crop of the FAO-56 table gets its
  table by month and growth stage from the site climate, its soil (12 USDA texture classes), the
  effective rain method (USDA-SCS, FAO/AGLW, FAO empirical, a share of the rain), the leaching
  requirement for the water salinity (FAO-29) and, for drip, the ground-cover reduction of Kc;
  totals per area and the CONAMA 284/2001 licensing category by method and area (informative).
- **Mechanised machines**: the Properties of a pivot or linear move open **Package, timer, arm, VRI
  and electrical…**: the sprinkler package (flow per outlet for a uniform depth, regulators, drops,
  numbered nozzles or catalogue nozzles, end gun and booster), the timer chart from the drive train,
  a corner arm following a guide path (with its jump warning), a variable-rate prescription by
  zones or sectors (CSV) and the electrical design (cable drop span by span, motor starting,
  generator size). The Pivot package and Arm, VRI and electrical tabs list them.
- **Calculators** (Tools menu): lateral (maximum length, losses and uniformity of a lateral or tape
  on a slope); pump and system curve (operating point, power and annual energy); water hammer
  (Joukowsky surge against the pipe rating); solar pumping (PV array for the daily volume of every
  month, with the grid comparison); wetted bulb of a drip emitter and the wetted share of the area;
  landscape water budget (MAWA and ETWU, with cycle-and-soak run times); hose-reel traveller (lane
  spacing, speed, depth, hose friction, inlet pressure); surface irrigation (furrows, borders and
  basins by volume balance: advance, cutoff, efficiencies); gated pipe (gate openings or hole sizes
  for a flow per furrow).

### AI assistant (optional)

Design → AI assistant… (`AI`, `IA`, `ASK`), its button in the status bar, or **Ask the AI** on any
message card opens an AI agent that works on the open project in a panel docked beside the drawing
(a bottom sheet on phones), so you watch the drawing change while it works. It runs a model of
Anthropic (Claude, through the Messages API) or of OpenAI (GPT, through the Responses API), with
your own API key for that company: the browser (or the desktop app) calls the company's API
directly, with no server of this project in between, and the company bills the usage to your
account. The panel shows the tokens of every answer and of the conversation with an estimate in
US$ at the list prices below, which may change.

| Company | Tier | Model | Id | US$ per million tokens, input / output |
|---|---|---|---|---|
| Anthropic | top | Claude Fable 5.1 | `claude-fable-5-1` | 10 / 50 |
| Anthropic | top | Claude Opus 5.5 (the default) | `claude-opus-5-5` | 4 / 20 |
| Anthropic | intermediate | Claude Sonnet 5.5 | `claude-sonnet-5-5` | 2 / 10 |
| Anthropic | fast | Claude Haiku 5.5 | `claude-haiku-5-5` | 0.10 / 0.50 (5 × above 100 000 input tokens) |
| OpenAI | top | GPT-6 Astra | `gpt-6-astra` | 10 / 50 |
| OpenAI | intermediate | GPT-6.1 Sol | `gpt-6.1-sol` | 2 / 10 |
| OpenAI | intermediate, earlier releases | GPT-6 Sol, GPT-5.6 Terra | `gpt-6-sol`, `gpt-5.6-terra` | 2 / 10, 2 / 12 |
| OpenAI | fast | GPT-6 Luna | `gpt-6-luna` | 0.10 / 0.50 |

OpenAI prompts above 272 000 input tokens cost 2 × input and 1.5 × output; the settings also show
the cache prices of each model. Every model takes five depths of reasoning, from quick to maximum
(balanced by default). Claude Fable 5.1 and GPT-6 Astra may think for several minutes on one step,
and Claude Fable 5.1 is offered only to organisations with 30-day data retention (otherwise the
app says so and suggests Claude Opus 5.5). On Claude Fable 5.1, Opus 5.5 and Sonnet 5.5 a request a
safety classifier declines is answered by another model on Anthropic's side, priced at the model
that answered. Switching to the other company's model, or between OpenAI models, starts a new
conversation; between Claude models the conversation goes on.

**Starting with the AI.** The app opens on an empty project with a start screen that asks where
the area to irrigate is and whether you want to design with the assistant (not when the address
already says what to open, an example, the tutorial or a shared project, nor after recovered work;
"Don't show this screen at start-up" and a switch in the assistant's settings turn it off). The place
is an address or place name searched on OpenStreetMap (you pick among the matches) or coordinates
in any usual form; the project is georeferenced there and the satellite map shows. **Design with AI**
opens the assistant beside the drawing with the place and your description, or a request to start a
new design, waiting in its box; nothing is sent before you press Send. **Start without AI** leaves you
on the empty, georeferenced project. On phones the assistant has a button in the top bar that spins while it works
and shows a dot when it waits for an approval, an answer or a plan decision (the docked panel's
button does the same).

**How it works.** The agent keeps a to-do list of the task, asks you questions as cards with
options when something is missing (the task waits for the answers), presents its plan, and works
through the program's own tools: 73 tools sent with every request, 102 more operations it finds and
runs (`find_operations`, `run_operation`), any menu command (`run_command`, the dialogs run without
opening) and 134 settings (`get_setting`, `set_setting`). It reads the same numbers as the reports,
changes the project through the same functions as the menus and dialogs (drawing, network,
catalogue, system flows, the design, its corrections, the automatic layouts, the analyses, the
quote, exports), keeps the project's **AI notes** (requirements, your answers and decisions, saved
in the project file and editable in the settings, each update one undo step), reads the design
playbook of the project type (12, written from the gallery examples) and the example projects,
finds the site from an address (OpenStreetMap Nominatim: at most one search a second and 8 per
conversation), sets the georeference and the base map, downloads the terrain and the climate
through the app's own downloads, and imports the drawings and GIS files you attach. It can also
read a data sheet you attach (PDF, image or text, up to 20 MB) and add its items to the catalogue,
checked before they go in, and write the project's technical report, which can be copied or put on
the drawing as text. [docs/AI_TOOLS.md](docs/AI_TOOLS.md), generated from the coverage map, lists
what it reaches: of the 1677 functions a user can reach (command actions, drawing tools, aliases,
menu items, dialogs and their options, panel fields, status bar, view options), 1637 are covered,
40 have no meaning for the AI (each with its reason) and none is missing; a test fails when a new
command, tool, menu item or dialog has no route. The system prompt states the network rules, the
design run and the permissions and indexes a reference manual the model reads when it needs it
(`read_manual`, 20 topics generated from the code: items and their fields, design parameters,
message codes, tools and operations, the engine's values, and a worked example replayed against the
real tools); the prompt and the tool definitions are cached between requests.

**Vision.** `view_snapshot` takes one picture of the drawing over a base map: by default the
satellite image whenever the project is georeferenced (Esri World Imagery, or Google with your
key), so the model draws over what is really on the ground, and otherwise the map on screen; the
model can also ask for the map on screen, a street map or none. The tiles are fetched off screen, so
your view and base map never change. The model also chooses what the drawing is coloured by in its
picture (layer colours, pressures, velocities, pipe sizes, the lowest and highest pressure of each
zone, or every zone in its own colour with its name at its valve) and what is marked on it: the
design messages at their items, numbered as in the Messages list, and its own changes of the task
(added in cyan, changed in amber, removed as a dashed red outline), so it checks its work; your
screen stays as it is. Every picture states its exact pixel-to-world mapping, and `image_to_world`
converts the positions the model reads on it, optionally snapping them onto the ends and lines of
existing items so that new pipes meet the old ones; a picture drawn before the georeference changed
is refused. `trace_region` outlines a field, lawn, pond or roof from one point inside it by image
analysis on the imagery (the region grows over similar colours and texture up to the tolerance at
which its area stops growing, before it leaks into the next field), far more exactly than corners
picked by eye, and `trace_fields` outlines every field of an area at once (roads, hedges, specks and
regions cut by the edge of the area left out). The model can zoom into a part, label the items, draw proposed shapes with
`preview_geometry` before creating anything, and read the ground with `terrain_picture` (hillshade,
colours by elevation, contours, slope, aspect), `terrain_profile` and `terrain_info`. Pictures are as
large as the model reads them pixel for pixel: up to 2000 pixels and about 3.6 megapixels on Claude
Opus 5.5, Sonnet 5.5 and Fable 5.1, otherwise 1568 pixels and about 1.15 megapixels, with the shorter
side at most 768 pixels on OpenAI's models; aerial and relief pictures go as JPEG, which keeps long
conversations within the request size, and attached photos are turned upright and scaled to at most
2000 pixels a side. On Claude Opus 5.5, Sonnet 5.5 and Fable 5.1 the status line shows the model's
short progress notes between steps. The panel has a button that attaches a picture of your view;
pictures and files can also be pasted into the message box (Ctrl+V) or dropped on the panel. A
setting (on by default) sends, after each round of changes, a picture framed on what changed, with
the changes marked. A photo you attach that carries its GPS position (as phones write it) comes with
where it was taken in the project and the nearest item, and the model can pin it to the drawing with
`add_photo_comment`: a review comment at that place keeping a small copy of the photo and what the
model read in it (a pump's nameplate, the state of a valve box), shown in its properties. Before it
exports a drawing sheet, the model looks at it with `preview_sheet`: the sheet as it will print, with
a check of overlapping, tiny or cut texts, a drawing that fills too little of its viewport or runs out
of it, empty title-block fields and the north arrow, scale bar and legend, each finding with where it
is, so it fixes them first.

**Pointing.** "Mark a point" and "Mark a line" above the message box show the assistant where:
every click on the drawing adds an orange mark labelled A, B, C… (a line ends with a double click or
Enter; Esc drops it), each with an optional note ("pump", "mainline up to here"). The marks go with
your next message with their coordinates and show in the assistant's pictures, so "the pump at A, the
mainline along B" is read exactly; the assistant may also ask you to mark a place. They are not part
of the project (no undo step, not saved) and go when you clear them or open another project; on a
phone the assistant's sheet closes while you mark and comes back when you finish. The commands `MK`
and `MKL` start them too.

**Voice.** A microphone button beside the message box dictates the message through the browser's
speech service, in the interface language (Chrome, Edge and Safari; there is none in Firefox nor in
the desktop app): the words being recognised show in a small bubble above the button and each
confirmed phrase goes into the box at the cursor, to be read and sent as if typed. The first use
says where the voice goes.

**Saved conversations.** A reload of the page, or the project opened again later in the same browser,
brings its conversation back as it was, and the model goes on with the exact earlier history; an
answer the closing page cut short shows as stopped, with **Try again**. Rewinding a restored
conversation takes back only the conversation (the project's undo history does not survive a reload).

**Control.** What it may do is set in the settings: **read only**; **plan first** (it explores with
reads only and presents a plan; changes start once you approve it); **ask before each change** (the
default: a card with Apply, Skip and Stop, also for each request to another service); or **apply
changes automatically** (saving a file, setting the georeference and deleting more than 20 items
are still confirmed). You can type while it works (the message reaches it at its next step) and
stop it at any time. Approving a plan with "apply automatically" runs that task without asking; the
mode chosen in the settings stays for the next tasks. After an error or a stop the answer offers
**Try again** (the same message, when nothing of it reached the model) or **Continue**, and the
settings when the fix is there (a key refused, a model the key cannot use). Every answer that changed the project is one history entry with **Undo these
changes**, and every message has **Rewind to here**, which takes the project (through the undo
history) and the conversation back to before it. A task ends at its step limit (50 by default, up
to 200) or at its spending cap (US$ 2 by default at list prices, with a warning at 80 % and a
**Continue** button for another cap). The cap is the app's own: the model is shown no token
countdown (a task budget made it stop early and suggest a new conversation), and its instructions
say there is ample context. Long conversations are summarised on the company's
server (Anthropic from 150 000 input tokens, after clearing old tool results from 80 000 while
keeping the notes, the plan and the to-do list; OpenAI from 200 000, with older pictures dropped
from the request); a setting turns this off. Quick commands: `/new`, `/design`, `/check`,
`/review`, `/report`, `/quote`, `/export`, `/plan`, `/clear` and `/cost`. `/review` runs read-only
whatever the mode: the model looks at the zones, the messages marked at their items and the
pressures and velocities over the drawing, reads the messages and the report tables, and answers with
a checklist (OK, attention or problem, with the figures and where to fix each point), changing nothing. Standing instructions in the
settings apply to every conversation ("always PVC PN 80 on the mainline"), and the conversation
saves as Markdown. Conversations are not saved with the project, so shared files and links never
carry the chat or its pictures. What is sent, when, and how the keys are kept: [section
12](#12-storage-privacy-and-network-access).

---

## 10. Reports, plotting and export

### Reports panel

Tabs: zone summary, pipes, emitters, mainline and duties (with the devices), bill of materials,
water requirements, hydraulic grade line (chart of the selected pipe, lateral or valve, with the
allowable pressure band), messages, profile (terrain along a path, with pipe and grade line),
flushing, water hammer, agronomy (ETc, readily available water, interval, depths, hours per event),
schedule (controller calendar per system flow), pivots and pivot spans, electrical (station, route
and wire length, station and common wire, valves open together and solenoid voltage of every valve;
stations used, common length and peak current of every controller), quote, trenches (volumes and
the construction schedule), materials by sector, comments, revisions, alternatives, crop
requirement (with the licensing category), pivot package (nozzle chart and timer), arm, VRI and
electrical, and valve-in-head stations. Tables are virtualised, with columns measured from their
content, and are the basis of every exporter, so PDF, Excel and CSV show the same numbers.

### PDF sheets

File → Export drawing → PDF opens the plot options: size (A4 to A0, Letter, Tabloid), orientation,
scale (automatic or fixed), margin, wetted radii, labels, layer legend, bill of materials on the
sheet, the base map of the screen under the drawing (with its credit) and attached report pages.
A PDF can hold a **set of sheets**: one sheet, or an overview plus one sheet per zone or per
irrigated area (each fitted to its subject with its own materials, the other zones in grey or
hidden), and the current screen view as an extra sheet at its own scale; then **construction
details** (trench, thrust block, valve box, sprinkler riser and swing joint, drip line connection,
air valve, filter station, pump suction) drawn with the design's own pipes, depths, models and
pressures; and **charts** (the mainline grade line of every system flow, the terrain profile and
the pump curves with their duty points). Revision clouds and open comments print on the sheets, and
the revision table lists them under the legend. The scene is built in "paper space": pens, symbols
and texts in paper millimetres, so that 1:500 and 1:2000 are equally legible. The title block
carries the project details, the north arrow and the scale bar.

The PDF writer is our own (PDF 1.4, Flate compression), with no native dependencies: the text
Helvetica can show stays in Helvetica, and any other script (Cyrillic, Greek, Vietnamese, Arabic,
Urdu, Hindi, Marathi, Bengali, Punjabi, Telugu, Chinese, Japanese) is set with embedded subsets of
the bundled Noto fonts, shaped and ordered (bidirectional text) by the app itself, so copy and
search give the text back. Images are embedded (JPEG passed through, other images with their
transparency) and downsampled for the size they are printed at. The same sheet exports as **PNG**
(File → Export drawing → PNG, 96 to 300 dpi, about 40 megapixels at most).

### Commercial quote and alternatives

Design → Commercial quote… turns the bill of materials into a quote: sale prices with the margin,
labour, trench excavation (volumes from the buried pipes and the trench settings), extra lines,
discount, taxes and freight, validity and terms; payback, net present value and internal rate of
return from a yearly benefit; a construction schedule from the crews and their output per day; the
FINAME codes (financing by the Brazilian development bank BNDES) of the items that have one. Design
→ Design alternatives… keeps named copies of the project with their key figures, compares them side
by side and restores one in one undo step.

### Exports

| Format | Contents | Notes |
|---|---|---|
| DXF | R2000 (AC1015) with native entities: polylines with arcs, splines, hatches, dimensions, leaders, multiline text; symbols and hydraulic items as blocks with attributes (NAME, ITEM, NOZZLE, ZONE, STATIONS); layers with true colours and dashed linetypes; user blocks as block definitions | Validated with ezdxf and LibreDWG and re-read by the app's reader |
| DXF R12 | The plain primitives of the earlier export, one text per line | For older programs |
| DWG | R2000 (AC1015), the same native drawing (colour indices only) | Our own writer, validated with LibreDWG and re-read by the app's reader |
| PDF | Sheet sets with title block, legend, north arrow, scale bar, details, charts and, optionally, reports | Every interface script |
| PNG | The sheet as an image, 96–300 dpi | |
| SVG | Sheet in millimetres, one group per layer, images embedded | Browsers, Inkscape |
| KML / KMZ | Folders per layer, WGS84 coordinates | Google Earth; needs a georeference |
| GeoJSON | FeatureCollection with attributes | QGIS, web GIS; needs a georeference |
| Shapefile (zip) | One shapefile per layer and geometry type (Z where an elevation counts), UTF-8 attributes with diameters, flows, velocities and pressures, a `.prj` | GIS; UTM on SIRGAS 2000 / WGS 84 when georeferenced, local metres otherwise |
| GPX | Every point item as a waypoint (lateral outlets one by one) and the linear items as tracks | Staking out with a GPS; needs a georeference |
| LandXML 1.2 | The terrain TIN and its source data, the point items as CgPoints, one pipe network per zone and for the mainline with inverts, diameters and design flows | Survey and civil software |
| IFC 4 | Site with the terrain, pipes as swept solids at their burial depth, terminals, valves, filters, meters, pumps and tanks with property sets and hydraulic values, one distribution system per zone | BIM; Reference View |
| EPANET (.inp) | The network of a system flow (or of everything open), with pumps, valves, emitters and the valve-in-head heads that flow runs | EPANET 2.2; Hazen-Williams, Darcy-Weisbach or Chezy-Manning |
| CSV, TXT, XLSX, PDF | Reports (all tables) | XLSX with one sheet per table and numbers as numbers |
| Controller CSV | Irrigation programme: events per system flow, days and times | File → Export report, or the System flows dialog |

---

## 11. File formats

### Project (`.oci.json`)

Readable JSON with these top-level keys:

| Key | Contents |
|---|---|
| `format`, `version` | `"opencadirrigation"`, `1` (the old name `irrigationcad` is still accepted) |
| `meta` | Stable uid, creation and modification dates, name, client, site, designer, notes, georeference (UTM zone, hemisphere, E/N origin) |
| `params` | All design parameters and the units |
| `catalog` | The whole project catalogue (the file is self-contained) |
| `layers` | Name, ARGB colour, visible, locked |
| `entities` | One entry per entity, with `type`, `id`, `layer`, `name` and its own fields (points in metres; a pivot keeps its machine data under `mach`) |
| `systemFlows` | System flows: name, valves (and pivots and valve-in-head stations), start time, duration |
| `proposal`, `scenarios`, `climate`, `labelRules`, `blocks`, `aiNotes` | Optional: quote settings, design alternatives, site climate, conditional labels, user blocks, the AI assistant's notes about the project |
| `nextId`, `currentLayer` | Id counter and current layer |
| `results` | Optional: results of the last calculation, to reopen with reports without recalculating |

The same JSON is used by the autosave, the versions, the cross-project clipboard, share links and
the calculation worker.

### Import

| Format | What comes in | Details |
|---|---|---|
| DXF (ASCII) | LINE, LWPOLYLINE and POLYLINE (with bulge arcs), CIRCLE, ARC, ELLIPSE, SPLINE (through its fit points, or the NURBS curve of its control points, knots and weights), HATCH (boundary paths of polylines, lines, arcs, ellipses and splines; pattern angle and spacing; islands as polylines), SOLID, TRACE, TEXT, MTEXT, ATTRIB, LEADER (its line), POINT, layers and blocks (INSERT, MINSERT and the block of every DIMENSION, nested too) | R12 to 2018, Latin-1 or UTF-8; `\U+XXXX` characters, `%%c`/`%%d`/`%%p` symbols and MTEXT codes decoded; polylines with elevation (2D or 3D vertices) become contour lines and breakline layers breaklines; points with Z become spot heights; scale from the file units |
| DWG | Same entities (ELLIPSE, SPLINE, HATCH, SOLID, TRACE and LEADER included; 2D polylines with their arcs), layers, blocks (INSERT, MINSERT) and dimensions; like the DXF, entities mirrored in the CAD program (extrusion 0, 0, −1) land where the CAD shows them | R13/R14 (partial), 2000, 2004, 2007, 2010, 2013 and 2018, in pure Dart; handle maps read whichever way the writer coded them; reports skipped objects |
| DGN V7 | Lines, line strings, shapes, curves, complex chains and shapes, circles, ellipses, arcs, texts, cells; levels as layers (`LEVEL_<n>`); 2D and 3D files (a constant Z becomes the elevation) | Units from the master/sub-unit ratio and the global origin of the file; DGN V8 is refused by name |
| PDF (plan) | A page as an underlay: lines, polylines and outlines, texts with their height and angle, images, PDF layers (layers off by default only on request), one layer per import and optionally per colour | File → Import opens a dialog: page with a preview, scale 1:N (read from the sheet when written there, or chosen, or metres per PDF unit), insertion point, contents; then Align by 2 points. Encrypted files are refused; JPEG 2000 and JBIG2 images are skipped; filled areas come as outlines |
| KML / KMZ | Placemarks, folders as layers, GPS tracks (gx:Track), altitude or ELEV attribute as elevation | WGS84 → UTM (automatic zone) with a local origin; georeferences the project |
| SHP (+ DBF, PRJ, CPG in a zip) | Points, lines, polygons, multipoints, Z variants; a zip with several shapefiles brings each on the layer of its name | Elevation from Z or from an ELEV/Z/COTA attribute; name from NAME/NOME/ID; attributes in UTF-8 or Latin-1 (.cpg); the `.prj` places the data (below); without one, degrees are recognised by range and precision |
| GeoJSON | FeatureCollection, Feature, GeometryCollection or a bare geometry, every geometry type; name, elevation and layer from the properties | RFC 7946 longitude/latitude on WGS 84, or the `crs` member of the 2008 specification (UTM on SIRGAS 2000, SAD 69 or Córrego Alegre lands in place); points without height become markers |
| GPX | Waypoints (with elevation: spot heights), routes and tracks | GPX 1.1 and 1.0 |
| LandXML | CgPoints, surfaces (the TIN, or contours, breaklines, points and boundaries) and pipe networks | Decimated to the terrain limit; CRS from the file; imperial units converted |
| LAS | The ground points (class 2) of a point cloud as terrain, thinned on a grid while reading | LAS 1.0–1.4, point formats 0–10, CRS from the GeoTIFF keys or the WKT; compressed LAZ is refused |
| EPANET (.inp) | The network drawn: pipes, pumps and valves as polylines on `EPANET_*` layers, nodes with their ids | US units converted; placed by the georeference or in local metres; the engine reader also builds the hydraulic network ([docs/API.md](docs/API.md)) |
| CSV, TXT, XYZ, PNEZD | Survey points | Columns detected by header or position; decimal comma accepted (also in columns separated by spaces), thousands separators too; a text column names the points; lat/lon recognised |
| Elevation GeoTIFF | Elevation grid | One band of heights, float or integer, nodata ignored; BigTIFF is refused by name |
| JPG, PNG, GeoTIFF, zip with world file | Background image | Georeferenced (world file, rotated too; GeoTIFF tags) or placed by hand and aligned by 2 points; rasters over 100 million pixels are refused before decoding |

**Coordinate systems.** The readers that carry a CRS (shapefile `.prj`, GeoJSON `crs`, LandXML,
LAS) recognise WKT 1 (ESRI and OGC flavours), WKT 2, EPSG codes and OGC URNs. SAD 69 and Córrego
Alegre data are shifted to SIRGAS 2000 with the IBGE three-parameter translations (accurate to a
few metres); SIRGAS 2000, WGS 84, ETRS89 and NAD83 are treated as identical at the accuracy of a
project map. An unrecognised system is reported, not guessed.

### Catalogues and examples

`.oci.cat` packs in [catalogs/](catalogs/) (format in [catalogs/README.md](catalogs/README.md)) and
example projects in [examples/](examples/), regenerated by tools and guarded by tests.

---

## 12. Storage, privacy and network access

- **Autosave** in the browser storage, at most every 3 seconds of activity and when a tab is
  closed; **recent projects** (the last 8) in File → Recent projects; **versions** (the last 10
  saves of every project) in File → Version history; **recovery** on start-up when there are
  unsaved autosaves. Projects above 256 KB of JSON are stored compressed; the limit per project is
  about 3.5 MB after compression. When even that does not fit, the embedded images are left out of
  the automatic copy, and the app says so once per project (or that the project cannot be kept
  there: save it to a file). The automatic copy is made in the background: the browser compresses
  it beside the app, so a large project does not hold the window after a design or while editing.
  A browser warning appears when closing the tab with unsaved changes.
- **Files**: Save produces an `.oci.json` download; Open reads from disk. Nothing is sent to any
  server.
- **Share by link** (File → Share by link…): the whole project, compressed, travels inside the
  address after the `#`, which browsers send to no server; whoever opens the link gets a copy in a
  new tab. Images, the photos of comments and results are left out (the receiver designs again); a link longer than about
  60 000 characters may be cut by mail and chat apps, and a project too large for a link is sent as
  a file.
- **Offline**: once the app has run in a browser, its service worker keeps a copy of the app (about
  20 MB, once per version, plus the language pack and the PDF fonts a start uses) and the next start,
  of the installed app or of the site, works without a network. Base maps, online elevation and
  climate, catalogues loaded by URL and the AI assistant still need one. A new version downloads in
  the background; the app then offers to reload into it (unsaved work goes to the autosave), or it
  is used from the next start.
- **Internet access**, for what you ask: online elevation (Terrain Tiles on AWS, Open-Meteo,
  OpenTopoData in the desktop builds), site climate (Open-Meteo historical weather, NASA POWER),
  base maps (OpenStreetMap, OpenTopoMap, CARTO, Esri, Google Maps with your own key, or a custom XYZ
  or WMS URL), catalogues loaded by URL and the AI assistant. Elevation and climate requests carry
  the coordinates of the site, nothing of the project. The Google Maps API key is kept in the
  browser's storage, which any script of the site could read, and sent to Google only (restrict it
  to the site in the Google Cloud console); where a tile server has no imagery at the current zoom the
  app scales the nearest coarser tile instead of showing a "no data" placeholder. Interface fonts
  for scripts the app does not bundle are fetched from Google Fonts when first needed.
- **AI assistant** (optional, [section 9](#ai-assistant-optional)): the one feature that sends
  project data to a third party, and only on your action. Nothing goes out until you send a
  message; then the requests go only to the company of the model you chose, Anthropic
  (`api.anthropic.com`) or OpenAI (`api.openai.com`, with `store: false`), with your key for it:
  your message, the files you attached, the project data you ticked (a compact text built from the
  report tables and the design messages, with the site position rounded to about a kilometre; the
  *Data sent* view shows the exact text of the next message), the earlier messages of the
  conversation and, while the model works, the results of the tools it calls: tables, items and
  pictures of the drawing over the base map, satellite imagery included (the terms of the imagery
  provider, Esri or Google, apply to what goes out; the pictures download their tiles as the
  screen does, without asking). A site search by address sends the address to OpenStreetMap's
  Nominatim (`nominatim.openstreetmap.org`), on your approval unless changes apply automatically.
  Each key stays in memory while the page is open; with *Remember the key on this device* it is
  kept in the browser storage, which any script of the site could read (the site's visit statistics
  never run in a page where the app runs). The keys never enter the project file, the autosave, share links or
  exports, and each goes only to its own company. Voice dictation sends the sound of your voice to
  the browser's speech service (Chrome uses Google's servers, Edge Microsoft's and Safari Apple's),
  which returns the text; the app neither records nor keeps the audio, and the text reaches the AI
  only when you send it. A photo pinned with `add_photo_comment` keeps a small copy (about 480
  pixels) in the project file, left out of share links; the model reads only its size. The AI notes are part of the project file, so
  they travel with it and with share links. Conversations are kept in this browser's storage
  (IndexedDB) by project, with their pictures and small attached files but never the keys, so a
  reload or the project opened again brings them back; the 12 most recent are kept, and *Keep
  conversations in this browser* in the assistant's settings turns this off and deletes them. What each company does with the requests is governed by your agreement with it.
- **Visit statistics**: the pages of opencadirrigation.com ask once whether visits may be counted
  and load Google Analytics 4 only after *Accept* (Consent Mode v2: everything denied by default,
  only the statistics granted), never in a page where the app runs, so it cannot reach projects or
  keys; *Decline*, also later with *Cookie settings* at the foot of the pages, deletes its cookies.
  The measurement id is set when the pages are generated (`OCI_ANALYTICS_ID`, empty for none). The
  privacy policy (`/privacy/`) and the terms of use (`/terms/`) are generated with the pages, and
  Help → About links them in the interface language.
- **Language and preferences** (chosen language, theme, default catalogue, tutorial done, the
  assistant's settings) are kept in the browser preferences.

---

## 13. Languages and site

The interface is in **20 languages**, the most spoken in the world. Portuguese, English and Spanish
are compiled into the app; Chinese (`zh`), Hindi (`hi`), Arabic (`ar`), French (`fr`), Bengali (`bn`),
Russian (`ru`), Urdu (`ur`), Indonesian (`id`), German (`de`), Japanese (`ja`), Marathi (`mr`),
Vietnamese (`vi`), Telugu (`te`), Hausa (`ha`), Turkish (`tr`), Punjabi (`pa`, Gurmukhi script) and
Swahili (`sw`) are language packs in `assets/i18n/<code>.json`, fetched only when that language is
chosen (the interface shows English until the pack arrives, a fraction of a second). Each pack
translates the whole string table, the interactive tutorial and the default catalogue names; the
design worker receives the pack with the request, so reports and plots come out in the chosen
language too. The app opens in the first language of the system's preferred-language list (from the
browser or the operating system) that it speaks, and in English when none of them is spoken; the
choice in View → Language (each language under its own name) is saved. The language pages (`/pt/`,
`/de/`, …) and the `?lang=` parameter apply to the visit only. The document `lang` attribute follows the app
language (`pt-BR`, `zh-CN`, otherwise the code). In Arabic and Urdu the interface is laid out right
to left. PDFs print every one of these scripts (section 10): before a PDF is written, the bundled
Noto fonts its texts need are loaded once per session. The shipped example projects exist in all 20
languages (`examples/<code>/`).

A pack is a plain JSON file with three sections: `strings` (key → text), `tutorial` and `catalog`
(English source text → text). Translators can revise it without touching the code;
`test/core/i18n_packs_test.dart` checks that every pack covers every key with the same placeholders.

The site is generated by `dart run tool/gen_site.dart` from `tool/site.dart`: `web/index.html`
(English, the page a visitor gets when nothing chose a language), one `web/<code>/index.html` for
each of the other 19 interface languages (`web/pt/`, `web/es/`, `web/de/`, `web/zh/`, …; the list
follows `supportedLanguages`, so a new app language needs its page), a redirect at
`web/en/index.html` for the address English used to have, `web/sitemap.xml`, `web/404.html` (in
the browser's language when the site speaks it), the privacy policy and the terms of use of every
language (`web/privacy/`, `web/<code>/privacy/`, and `terms/` alike; written in Portuguese, English
and Spanish, in English in the others until they are translated, which are then not indexed), one
manifest per language (`web/manifest.json`, `web/<code>/manifest.json`: the same app identity, a
start address, names and shortcuts in that language, a wide and a narrow screenshot), `web/site.js`
(the only script of the pages: it starts the app when it is wanted and asks the consent of the
statistics) and the hosting configuration `hosting/firebase.json` (see `hosting/README.md`). The page texts live in `tool/site.dart`
(Portuguese, English, Spanish) and `tool/site/<code>.dart` (the others, with the example gallery
taken from the language packs); Arabic and Urdu pages read right to left. Since
Flutter paints on a canvas, every page carries the content as real HTML (heading, features,
examples, FAQ), with its own canonical, `hreflang` between all the versions (also the bare `pt` and
`zh` beside `pt-BR` and `zh-CN`), a Content Security Policy (scripts from the site only, WebAssembly
for CanvasKit, no inline script, no plugin or frame), Open Graph and JSON-LD
(application, FAQ, how it works and the example gallery, in the page's language, with the subject
linked to Wikipedia/Wikidata). The test `test/web_metadata_test.dart` fails when the generated files
drift from the template.

That HTML is all a first visit downloads (and what crawlers and PageSpeed measure): the app, several
megabytes, is fetched only when the visitor opens it (the page's buttons and example links start it
in place), arrives at an app address (`?example=`, `?tutorial=`, `?design=`, `?ai=`, `?lang=`, the installed
app's `?source=pwa`) or has used it in that browser before (any `opencadirrigation.` key in
`localStorage`); the page then stays, hidden, under the app. `web/flutter_bootstrap.js` is Flutter's
loader without Flutter's deprecated service worker, and `tool/build_web.sh` drops the pointer to the
`flutter.js.map` the build does not write and builds with `--no-web-resources-cdn`: CanvasKit and the
Roboto font come from the site itself, not from Google's CDN. The logo at the top is WebP in three
widths (`web/brand/logo-horizontal-{520,780,1040}.webp`, made from `logo-horizontal.png`), its
address versioned by a hash of the file. The site is served by Firebase Hosting from a deploy folder
kept outside this repository (`public/`, a copy of `build/web`, beside `firebase.json`); the
configuration is versioned in `hosting/firebase.json`, generated with the pages (`hosting/README.md`
says how to apply it). It has no catch-all rewrite, so an unknown address gets `404.html` with status
404 instead of the app page (which made `/.well-known/ai-catalog.json` look like a broken AI
catalogue to PageSpeed); every file gets `nosniff`, `SAMEORIGIN`, a `Referrer-Policy` and a
`Permissions-Policy` limited to the device position and the microphone; the pages, the manifests
and every app file whose name stays the same from build to build (`main.dart.js`, the worker,
`flutter_bootstrap.js`, `sw.js`, `offline.js`, `site.js`, `assets/**`, `canvaskit/**`) are
`no-cache`, the images under `brand/`, `icons/`, `screenshots/` and at the root keep for 30 days,
and `/en/` answers with a 301 to `/`.

**Offline start.** Once the first frame is on screen and the browser is idle, `flutter_bootstrap.js`
loads `web/offline.js`, which registers the app's own service worker, `web/sw.js`, so a first visit
is never slowed by it. `tool/build_web.sh` ends with `dart run tool/gen_sw.dart`, which writes into
the build's `sw.js` the build name (version, git commit, date and a hash of the files) and the files
a start may need with their SHA-256: the root page, the bootstrap, `main.dart.js`, the design worker,
`site.js`, the manifest and icons, the Flutter assets, the logo and CanvasKit (the browser's variant
only), about 17 MB uncompressed. The language packs, the PDF fonts and the licence list are listed
with their hash too but kept only once a start uses them, and a new build carries forward those the
browser kept, fetching their new version when they changed. At install the
worker fills one cache per build (`oci-shell-<build>`): files unchanged since the previous build are
copied from its cache, the others fetched past the HTTP cache and checked against their hash. It
answers from the cache first and revalidates the start page after the first frame; it keeps the
fallback fonts the engine fetches from fonts.gstatic.com; map tiles, elevation, climate and
analytics go to the network untouched. A new build is installed in the background; `offline.js` tells
the app, which offers to reload into it (*A new version of OpenCADIrrigation is ready*, after a word
about unsaved work, which goes to the autosave), and otherwise it is taken at the next start. A
page already open keeps the build it started with (the other open pages keep theirs when one
reloads), a page left open for days looks for a new build every hour and when it comes back on
screen, and a build's cache is deleted once no page uses it. A `sw.js` that was not filled in (`flutter run`, a
plain `flutter build web`) only removes itself and its caches.

The generator also writes what search engines and AI assistants read besides the pages:
`web/robots.txt` (everything allowed, with the search and AI crawlers named: GPTBot, OAI-SearchBot,
ClaudeBot, PerplexityBot, Google-Extended, Applebot-Extended, CCBot, bingbot and others),
`web/llms.txt` (the [llmstxt.org](https://llmstxt.org) summary: what the app is, key facts and links
to every language page and example) and `web/llms-full.txt` (the whole reference in Markdown:
features, workflow, hydraulic methods, sizing, catalogues, formats, deep links, limitations, FAQ;
its technical sections live in `tool/site/llms.dart` and follow this README), `web/humans.txt` and
the IndexNow key `web/<key>.txt`. After a deploy, `dart run tool/indexnow.dart` asks Bing, Yandex and
the other IndexNow engines to crawl the pages again (Bing's index also answers Copilot and ChatGPT
search); `--dry-run` prints the request without sending it.

---

## 14. Code architecture

```
bin/oci.dart                command line: design, analyze, check, export and bom for .oci.json projects
lib/
  core/                     pure Dart, no Flutter (runs in the worker, in the isolate, the tools and the CLI)
    api.dart                the whole engine in one import (docs/API.md)
    hydraulics/             formulas and solvers
      friction.dart           Hazen-Williams, Darcy-Weisbach (Swamee-Jain, Colebrook, Blasius, laminar,
                              transition), Scobey, Manning
      minor_losses.dart       fitting K, equivalent length, curve h = K·Q^n + C
      emitter.dart            q = k·H^x, wetted radius, fit to a data-sheet table, pressure window, overlap CU
      lateral.dart            step-by-step lateral analysis, maximum length, feed positions
      network.dart            network solver (Global Gradient Algorithm) with emitters, pumps, PRV, PSV,
                              FCV, check valves
      sparse_solver.dart      sparse LDLᵀ with minimum-degree ordering
      pump.dart               pump and system curves, operating point, power, NPSH, CRF, energy
      uniformity.dart         CU, DU, EU, Us, flow variation
      water_hammer.dart       celerity, Joukowsky, critical time
      transient.dart          transients by the method of characteristics (pump trip, air valves,
                              vessels, vapour cavities)
      eps.dart                extended-period simulation: tanks, schedules, patterns, controls, energy
    model/                  data
      geometry.dart           Pt, Bounds, segments, polygons, offsets, convex hull, affine transformations
      entities.dart           drawing and hydraulic entities (JSON, clone, transform, grips, distance)
      catalog.dart            component catalogue and default database, pipe class derating
      catalog_packs.dart      manufacturer packs (in memory) and merging
      currency.dart           currencies, default by language/region, reference exchange rates, price conversion
      project.dart            project: meta, parameters, catalogue, layers, entities, system flows
      terrain.dart, tin.dart  terrain model: Delaunay TIN constrained by breaklines, IDW, contour lines
      slope_map.dart          slope and aspect on a grid
      spatial_index.dart      STR R-tree for culling, selection and snap
      split.dart              splitting of linear entities
      blocks.dart, label_rules.dart, scenario.dart, proposal_settings.dart, site_climate.dart,
      pivot_machine.dart      user blocks, conditional labels, alternatives, quote settings, site climate,
                              pivot machine data
    design/                 designer
      network_builder.dart    entities → hydraulic graph (nodes, links, zones, emitter lumping, fittings)
      designer.dart           orchestration: zones, mainline, pressure classes, telescoping, flushing,
                              water hammer, machines, wiring, BOM
      lp.dart, lp_sizing.dart dense two-phase simplex and the sizing formulation
      block_generator.dart    lateral blocks (straight and guided) and sprinkler grids
      auto_layout.dart, zoning.dart, routing.dart, templates.dart, field_subdivision.dart,
      tree_rings.dart, pivot_fit.dart, vegetation.dart
                              automatic design: heads, zones, pipe and mainline trees, turf templates,
                              blocks, drip rings, pivot fit, vegetation from aerial imagery
      pivot.dart              centre pivot and linear move hydraulics
      mechanised.dart, pivot_package.dart, corner_arm.dart, vri.dart, pivot_electrical.dart
                              sprinkler package and timer, corner arm, variable rate, pivot electrical
      traveller.dart, surface_irrigation.dart, gated_pipe.dart
                              hose-reel travellers, furrows, borders and basins, gated pipe
      fittings.dart           automatic fitting selection
      pump_selection.dart     pump and motor choice
      agronomy.dart           ETc, water balance, controller programme
      climate.dart, crops.dart, soils.dart, effective_rain.dart, irrigation_requirement.dart,
      area_requirement.dart   FAO-56 ETo and crops, USDA soils, effective rain, requirement tables
      solar_pumping.dart, wetted_bulb.dart, water_budget.dart
                              PV pumping, drip wetted bulb, landscape water budget
      management.dart         demands of zones, pivots and stations, automatic system flows
      valve_in_head.dart      valve-in-head stations
      densogram.dart          water applied by the sprinklers as drawn, uniformity per area, wind
      electrical.dart         valve wiring: routes, stations, wire sizes for the solenoid voltage
      two_wire.dart, wire_routing.dart
                              two-wire (decoder) sizing, wire routes along the trenches
      transient_analysis.dart, air_valves.dart
                              transients of the mainline, air valves (AWWA M51), 24-hour simulation
      network_ops.dart, on_demand.dart, tariff.dart, energy_grouping.dart, criticality.dart,
      calibration.dart, fertigation.dart
                              operation: Clément flows, tariff schedule, energy grouping, N−1,
                              calibration, fertigation
      proposal.dart           commercial quote, trenches, payback, construction schedule
      design_check.dart       design check
      advisor.dart            problems explained, impossible settings, corrections that apply
      auto_fix.dart           corrections, fix automatically, optimisation
      results.dart, report_tables.dart  serialisable results and report tables
    io/                     format readers and writers
      dxf.dart, dwg.dart, dgn.dart, kml.dart, shp.dart, geojson_reader.dart, gpx.dart, landxml.dart,
      las.dart, epanet_inp.dart, points_csv.dart, point_grid.dart, geoimage.dart, dem_tiff.dart
                              readers (the EPANET, GPX and LandXML files also write)
      cad_drawing.dart, cad_export.dart, dxf_r2000.dart, dwg_writer.dart
                              R2000 DXF and DWG with native entities
      pdf_reader.dart, pdf_reader_fonts.dart, pdf_reader_images.dart, pdf_import.dart
                              PDF plans as an underlay
      plot.dart, pdf.dart, pdf_sheet.dart, sheet_set.dart, sheet_canvas.dart, details.dart,
      plot_charts.dart, svg.dart
                              plot scene, PDF writer, sheet sets, construction details, charts, SVG
      fonts/                  TrueType reader and subsetter, OpenType shaper (Arabic, Indic), bidi,
                              Unicode data, the PDF font registry
      shp_writer.dart, geo_export.dart, ifc.dart, xlsx.dart, catalog_io.dart, project_export.dart
                              shapefile, KML/GeoJSON, IFC 4, Excel, catalogues, export dispatch
      geo.dart, datum.dart    UTM, datums (SIRGAS 2000, SAD 69, Córrego Alegre), CRS recognition
      dem_online.dart, climate_online.dart, share_link.dart
                              online elevation and climate, projects in a link
    ai/                     optional AI assistant, two companies behind one interface
      llm.dart                models with their tiers and list prices, tokens and cost, errors, the
                              client every company implements
      llm_formats.dart        conversion of messages, tools and results to each company's format
      claude_api.dart         Anthropic Messages API: streaming, adaptive thinking, effort, caching,
                              refusal fallback, task budgets, compaction, clearing of old tool results
      openai_api.dart         OpenAI Responses API: streaming, function tools, reasoning effort,
                              store: false, compaction
      agent_loop.dart         the agent loop: tools, approvals by mode, step limit, spending cap
      project_context.dart    the project data sent with a message
    units.dart              units (metric/US), water viscosity, typed tables
    translate.dart          translation hook so reports and plots label their output without Flutter
    i18n/language_packs.dart registry of the language packs (strings, tutorial, catalogue names)
  app/                      Flutter
    state/                  ProjectController (project, selection, camera, undo, spatial index, calculation),
                            Workspace (tabs and clipboard), DesignRunner (worker/isolate/thread)
    canvas/                 CadCanvas, CadPainter, Camera, Snapper, base map
    tools/                  drawing, editing and hydraulic tools, typed points, block insertion
    keys/                   shortcut dispatcher and native listener
    widgets/                menus, palette, panels, reports, charts, dialogs, compact layout, and
                            ai/: the docked AI panel and its views (conversation, data sent, settings)
    ai/                     the agent of a tab: 73 tools and 102 operations over the controller and
                            the engine (agent_tools*, agent_ops*, ops_*), the coverage map
                            (ai_coverage.dart), the system prompt, the manual and the playbooks,
                            vision (pictures, tiles, terrain), transports (fetch, HttpClient),
                            approvals, rewind and undo
    tutorial/               interactive tutorial
    io/                     files, preferences, HTTP, local storage, HTML document, external links,
                            GPS, PDF fonts, PNG export of a sheet
    actions.dart            file, clipboard and export actions shared by menus, palette and aliases
    examples.dart           example gallery
    i18n.dart               pt/en/es text table, language list and on-demand loading of the packs
    i18n_assets.dart        reads assets/i18n/<code>.json for the chosen language
    shortcuts.dart          command aliases (pt/en/es) and the shortcut table
    theme.dart              dark and light palettes (CadPalette, 76 colour tokens read through Cad.*),
                            the CAD colour rule of the light canvas, theme switching (CadThemeHost)
    version.dart            generated app version (tool/gen_version.dart)
  worker/design_worker.dart Web Worker entry point
assets/                     language packs (i18n/) and the Noto font subsets of the PDFs (fonts/)
catalogs/                   manufacturer packs (JSON) and index
docs/                       technical study, the engine API (API.md, API.pt-BR.md) and what the AI
                            reaches (AI_TOOLS.md, generated)
examples/                   example projects, one folder per interface language (20)
tool/                       generators: site, catalogues, examples, brand, version, service worker; worker
                            and web builds; fonts and shaping fixtures (tool/fonts)
test/                       engine, model, format and interface tests
web/                        pages, manifest, icons, robots, sitemap, compiled worker, offline start
                            (sw.js, offline.js)
```

### Design decisions

- **Pure Dart engine.** `lib/core` does not import Flutter, so it runs in the Web Worker, in the
  isolate, in `dart run` (tools and the command line) and in fast tests. The interface only builds
  requests and shows results.
- **One controller per project.** `ProjectController` holds the project, the selection, the
  camera, the undo stack (entity snapshots), the spatial index and the calculation state. Every edit
  goes through `mutate`, which takes the snapshot, marks the project dirty, invalidates results and
  the index, notifies the interface and schedules the autosave.
- **Calculation off the thread.** The project is serialised to the worker; the worker returns the
  results and the resized entities; an edit counter discards results of a project that changed
  while it was being calculated.
- **Spatial index.** STR-packed R-tree rebuilt on every edit; painting queries only the visible
  window, and selection, snap and window selection query the index (microsecond queries with tens
  of thousands of entities).
- **Drawing on screen.** The canvas keeps its drawing between frames (`SceneCache`): it is recorded
  again only when something it shows changes (an edit, the selection, the view, the base map, the
  results), so moving the cursor repaints only the snap marker, the tool preview and the item under
  the cursor over a picture of the scene. A scene that takes long to draw follows a pan or a zoom as
  a moved picture and is drawn sharp once the view rests. The painter gathers its drawing calls by
  paint (a few hundred calls for tens of thousands of items) and leaves out vertices closer than a
  pixel; lines no wider than a device pixel are drawn as hairlines and wider ones segment by segment
  (in the browser a wide stroked path is rasterised on the CPU), and a view packed with linework on
  a high-density screen draws its 1 px lines one device pixel wide. The status bar alone listens to
  the cursor coordinates, so the window is not rebuilt on every move.
- **Own formats in pure Dart.** Readers and writers of DWG, PDF (with its fonts and text shaping),
  XLSX, SHP, GeoTIFF, LAS, IFC etc. do not depend on native libraries, which keeps the app 100 %
  web.
- **Centralised texts.** All interface strings are keys of `i18n.dart`, with the Portuguese, English
  and Spanish texts compiled in and the other 17 languages in the packs of `assets/i18n`; the engine
  returns codes (`velocity_exceeded:e12`) that the interface translates. Every test file fails when
  the interface asks for a key the table does not have (`test/flutter_test_config.dart`), which
  would otherwise show the key itself on screen.
- **The AI uses the program, not a copy of it.** The assistant's tools are thin wrappers over the
  controller and the engine, every change goes through `mutate` (one undo group per answer), and
  a coverage map routes every user-reachable function to a tool, an operation, a command or a
  setting. The two companies sit behind one interface (`llm.dart`), with the format conversion in
  one place (`llm_formats.dart`) and one agent loop; the request code takes the HTTP exchange as a
  parameter, so the tests run it against scripted fakes.

---

## 15. Development

Requirements: a recent stable Flutter (developed with 3.47, Dart 3.13). No native dependencies.

```bash
git clone https://github.com/videjunior/opencadirrigation.git
cd opencadirrigation
flutter pub get
flutter run -d chrome              # development in the browser
flutter test                       # about 1,900 tests: engine, model, formats, interface
flutter analyze                    # lints
tool/build_worker.sh               # recompiles web/design_worker.js after changing lib/core (the app falls
                                   # back to the interface thread when the file is missing)
tool/build_web.sh                  # release build: worker + flutter build web with the git commit and date
                                   # baked into the version (welcome, status bar, Help → About, console),
                                   # CanvasKit served by the site and the offline service worker filled in
                                   # (tool/gen_sw.dart); OCI_WEB_OUT=<folder> writes the build elsewhere
flutter build web --release        # a plain build (no commit/date, CanvasKit from Google's CDN, no offline
                                   # start: its sw.js removes itself; build/web, web/CNAME holds the domain)
dart run bin/oci.dart --help       # command line: design, analyze, check, export, bom of .oci.json projects (docs/API.md)
dart run tool/gen_version.dart     # regenerates lib/app/version.dart after changing `version:` in pubspec.yaml
dart run tool/gen_site.dart        # site pages (English index, /pt/, /es/, /de/, … sitemap, 404, robots, llms.txt)
dart run tool/indexnow.dart        # after a deploy: ask IndexNow engines (Bing…) to crawl the pages again
dart run tool/gen_catalogs.dart    # validates and normalises catalogs/*.oci.cat and rebuilds index.json
dart run tool/gen_examples.dart    # regenerates examples/<lang>/*.oci.json from lib/app/examples.dart
dart run tool/gen_brand.dart       # icons and brand assets from web/brand
python3 tool/formats/make_fixtures.py   # rewrites test/fixtures/formats with ezdxf, pyshp, tifffile, Pillow, openpyxl and LibreDWG
python3 tool/formats/check_exports.py   # validates build/formats (written by flutter test) with independent readers
python3 tool/fonts/build_fonts.py       # rebuilds the Noto subsets of assets/fonts from the interface strings
python3 tool/fonts/gen_unicode_data.py  # regenerates lib/core/io/fonts/unicode_data.dart from the Unicode Character Database
python3 tool/fonts/make_shaping_fixtures.py  # rewrites test/fixtures/shaping with HarfBuzz (uharfbuzz)
UPDATE_AI_TOOLS_DOC=1 flutter test test/widget_ai_coverage_test.dart  # regenerates docs/AI_TOOLS.md from the coverage map
```

The command line runs the engine of the app in the Dart VM, without Flutter or a browser:
`design` sizes and analyses a project (and writes the designed project, the results and every
report table), `analyze` keeps the sizes as drawn, `check` lists the problems and exits with 1 on an
error, `export` writes any drawing format and `bom` prints the bill of materials, in any of the 20
languages (`--lang`).

The committed outputs of most generators have guard tests (the site pages, the service worker
template, the examples, the catalogues, the version and the AI tools table): when one drifts from its
source, the matching test fails and says which command to run. Rebuild the design worker
(`tool/build_worker.sh`) after changing `lib/core` or the string table, and the PDF font subsets
(`tool/fonts/build_fonts.py`) after adding characters, where no guard reminds you. Desktop builds (`flutter run -d macos|windows|linux`) use the
isolate for the calculation. The `android/` and `ios/` folders are the project templates Flutter
generated; native mobile builds have not been built or tested, and phones and tablets use the web
app (installable as a PWA).

### How to extend

- **New entity**: class in `entities.dart` (JSON, clone, transform, grips, distance, bounds),
  `EntityType`, default layer, painting in `painter.dart`, properties in `properties_panel.dart`,
  tool in `tools.dart` and alias in `shortcuts.dart`, export in `plot.dart`/`cad_export.dart`.
- **New report**: table in `report_tables.dart` (the CSV/TXT/XLSX/PDF exporters and the panel pick
  it up automatically) and texts in `i18n.dart`.
- **New format**: reader or writer in `lib/core/io`, entry in the controller's `importFile` or in
  `DrawingFormat`/`ReportFormat`, and a round-trip test.
- **New formula**: in `lib/core/hydraulics`, with a test against a reference value.
- **New AI tool**: a tool in `lib/app/ai/agent_tools*.dart` (sent with every request) or an
  operation in `lib/app/ai/ops_*.dart` (found with `find_operations`), over the controller, with
  its input schema and its effect (read, change, export or a request to another service), and its
  route in `lib/app/ai/ai_coverage.dart`. `test/widget_ai_tools_test.dart` checks names and
  schemas, `test/widget_ai_coverage_test.dart` fails when a command, tool, menu item or dialog has
  no route, and `test/widget_ai_manual_test.dart` when the manual misses an item key, a design
  parameter or a message code.
- **Interface colours**: take them from `Cad.*` (`lib/app/theme.dart`), adding a token to both
  palettes when none fits; `test/widget_theme_test.dart` checks the contrast of the light text
  tokens (4.5:1 on every light surface).

---

## 16. Tests

`flutter test` runs about 1,900 tests in a few minutes (the number grows with every version). What each
group guarantees:

| File | Coverage |
|---|---|
| `core/hydraulics_test.dart` | Hazen-Williams against a textbook value; Darcy-Weisbach ≈ Hazen-Williams on smooth PVC; laminar factor; Swamee-Jain ≈ Colebrook; continuity and slope match at the transition; Christiansen F table and Scaloppi adjustment; equivalent diameter; emitter law and fit; application rate; overlap CU; CU/DU and the Keller-Karmeli EU (the worked example of the technical study); pump curve fit, operating point, CRF; K → flow form; PVC celerity; number formatting without scientific notation |
| `core/network_test.dart` | Sparse solver; single pipe; loops; mass conservation; pressure-dependent emitters; pump; PRV; device curve; Darcy-Weisbach convergence; large branched network is fast; comparison with Christiansen; laterals on slopes; maximum length; feed positions; emitters above the available head stay closed (no backflow) |
| `core/network_robustness_test.dart` | A pump near its shutoff head feeding a hundred emitters near zero pressure (against an independent bisection); a pump that one bad step used to lock closed; pressure-compensating emitters on a hill, dry above the grade line and starved below it; a pressure-reducing valve just above its setting stays open; a check valve fitted as a device stops reverse flow; 300 random tree networks (pumps, check valves, demands, every emitter exponent) converge to solutions that satisfy continuity and the head-loss laws; a line at rest behind an idle pump |
| `core/valves_formulas_test.dart`, `core/pressure_class_test.dart`, `core/minor_fittings_test.dart`, `core/mains_frequency_test.dart` | Scobey and Manning laws in the solver; a pressure-sustaining valve holds its upstream setting and a flow-control valve its flow, hydrant flow limiters in a project; a variable-speed pump holds its outlet pressure flow after flow, with NPSH and efficiency curves; PVC and PE derating with temperature and the class as a sizing constraint (a 95 m supply never gets PN 80 PVC, warm water fails a pipe that passes at 20 °C); the losses of the drawn fittings; a 60 Hz pump on 50 Hz mains and the pump selection at the mains speed |
| `core/invariance_test.dart` | Moving a project (also to UTM coordinates), drawing its pipes the other way round, saving and reopening it or changing the language leave the design as it was; inverse-distance terrain counts every spot height once |
| `core/regressions_1017_test.dart` | Defects fixed in the 2026-10-17 sweep: pump and device curves typed with repeated flows, a pump with a shutoff head only, feed positions of laterals that need more than three times the nominal pressure |
| `core/lp_test.dart` | Simplex: ≤/≥, equalities, infeasible, unbounded, a problem shaped like the sizing one |
| `core/design_test.dart`, `core/sizing_features_test.dart`, `core/gaps_test.dart` | Block generator; connected graph; full analysis and sizing; LP no worse than greedy; telescoping; fittings; flushing; water hammer; overlap CU and emitters per plant; agronomy and controller programme; pump and motor selection; GeoTIFF DEM; pivot (spans, costs); looped mainline |
| `core/transient_test.dart`, `core/transient_analysis_test.dart`, `core/air_valves_test.dart`, `core/eps_test.dart` | Method of characteristics: the steady state does not move without an event, Joukowsky surge and the 4L/a period, Michaud's surge for a slow stop, friction damping, column separation, a combination air valve, a pump trip with its check valve, inertia and an air vessel, merged and lumped pipes; every example's mainline runs every scenario with the steady state inside the envelopes; air valve placement by AWWA M51 practice and orifice sizing; extended period with tanks, schedules, patterns and controls, and the energy, against analytic curves and hand calculations |
| `core/terrain_pivot_test.dart`, `core/breakline_test.dart`, `core/slope_map_test.dart` | Delaunay TIN exact on planes; TIN vs IDW; contour generation; segment chaining; alignment and clipping geometry; guided blocks; pivot hydraulics (including sector pivots); design check; Excel catalogue and packs; breaklines forced into the triangulation; slope and aspect maps |
| `core/advisor_test.dart` | Unconnected items joined (valve back at its zone), impossible settings restored, emitter pressure outside the nozzle range, zones left out of the flows, surface pump in a deep well → submersible, booster for a short public supply, flows split to the supply flow, fix automatically on a project with several mistakes, optimisation never raising the annual cost |
| `widget_advice_test.dart` | Messages tab explains and fixes in one click (one undo step), design with errors opens Messages, fix automatically in one history step, optimisation and menu entries, missing supply with its one-click fix |
| `core/auto_layout_test.dart`, `core/zoning_test.dart`, `core/routing_test.dart`, `core/templates_test.dart`, `core/field_subdivision_test.dart`, `core/tree_rings_test.dart`, `core/pivot_fit_test.dart`, `core/auto_design_test.dart`, `core/vegetation_test.dart` | Head layouts of rectangles, L-shapes, curved beds and lawns round a house with their CU, matched part circles; zones within the flow that never mix precipitation classes; zone and mainline trees round buildings; pitch, track, green, tee and fairway templates; blocks of equal area with roads; rings joined to their laterals; the largest circle and the best sector of a field; laid-out, zoned and routed lawns, fields and orchards that design without errors; vegetation of a synthetic aerial scene (lawns, crowns, shade, pool, paving) within a few per cent; each in well under a second for thousands of heads |
| `core/climate_test.dart`, `core/climate_online_test.dart`, `core/crops_test.dart`, `core/soils_test.dart`, `core/effective_rain_test.dart`, `core/irrigation_requirement_test.dart`, `core/solar_pumping_test.dart`, `core/wetted_bulb_test.dart`, `core/water_budget_test.dart` | FAO-56 worked examples (pressure, vapour pressure, radiation, ETo in Bangkok, Uccle and Lyon), Kc curves, Annex 7 and sparse cover; FAO-29 leaching and the drip-irrigated citrus of FAO Module 9; NEH 623 effective rain and the FAO formulas; the soil table against NEH 652, Rawls et al., FAO-56 Table 19 and the SWAT/EPA table; solar geometry against Duffie & Beckman and FAO-56 Example 8; Schwartzman & Zur; MWELO budgets and cycle and soak; Open-Meteo and NASA POWER requests, parsing, pacing, retries and normals |
| `core/mechanised_test.dart`, `core/pivot_package_test.dart`, `core/corner_arm_test.dart`, `core/vri_test.dart`, `core/pivot_electrical_test.dart`, `core/traveller_test.dart`, `core/surface_irrigation_test.dart`, `core/gated_pipe_test.dart` | NEH 623 sample calculation 11-18 (system capacity, outlet flow, end gun, friction, revolution and booster), regulated packages with numbered or catalogue nozzles, timer chart from the drive train; corner arm against analytic cases; variable rate from sectors and zones; tower motors and cable drop by IEC 60364-5-52, generator size; traveller sample calculation 11-17; the furrow, border and basin examples of FAO 45; gated pipe outlets |
| `core/network_ops_test.dart`, `core/on_demand_test.dart`, `core/tariff_test.dart`, `core/energy_grouping_test.dart`, `core/criticality_test.dart`, `core/calibration_test.dart`, `core/fertigation_test.dart` | Clément flows against FAO 59 Box 1 and the random-configuration check (AS 241 quantiles, MRG32k3a reference sequence); the Brazilian discount rule and the scheduler exact against brute force; energy grouping 30 % below first fit by flow; N−1 on trees and loops; golden section and Levenberg–Marquardt recovering C; fertigation travel times, plan and venturi; all of them on a designed project |
| `core/valve_in_head_test.dart`, `core/two_wire_test.dart`, `core/wire_routing_test.dart`, `core/round_1025_test.dart`, `widget_valve_in_head_test.dart` | Valve-in-head stations scheduled by the flows (pressures, 24 hours, wiring, two-wire, EPANET, pump static lift, controller programme, transients, fertigation) and the results of projects that never scheduled them; two-wire voltage by hand, decoders and grounding; routes along the trenches (shortest paths, Steiner-like tree), master valves and pump relays; master valve and accessories in the BOM, compressed browser storage, a device on every selected lateral, share links, comments and revision clouds, nozzle curves fitted to pasted tables |
| `core/dwg_test.dart`, `core/dwg_writer_test.dart`, `core/cad_export_test.dart` | Reading R2000–R2018 and R2007 samples, with blocks and dimensions expanded; rejection of unknown versions; CRC; writer round trip; LibreDWG validation when installed; R2000 DXF and DWG with native entities, dimension blocks, layers with true colours and linetypes, attribute definitions and user blocks, for every gallery example, read back alike |
| `core/formats_test.dart`, `core/formats_app_test.dart` | Every import format against files written by other programs (ezdxf, LibreDWG, pyshp, tifffile, Pillow, openpyxl and Google Earth style KML; fixtures in `test/fixtures/formats`, generated by `tool/formats/make_fixtures.py`) with positions, elevations, names and layers checked; every export re-read by our own readers and written to `build/formats` for `tool/formats/check_exports.py`, which validates them with ezdxf, LibreDWG, lxml, openpyxl and pypdf; the new formats through the app (GeoJSON, GPX, LAS, DGN, EPANET, zips of shapefiles) |
| `core/epanet_inp_test.dart`, `core/shp_writer_test.dart`, `core/gpx_test.dart`, `core/landxml_test.dart`, `core/ifc_test.dart`, `core/geojson_reader_test.dart`, `core/las_test.dart`, `core/dgn_test.dart`, `core/datum_test.dart` | EPANET files of designed projects matching our analysis zone by zone and flow by flow, and the reader; shapefiles, GPX, LandXML and IFC by their specifications and read back; GeoJSON with every geometry and `crs`; LAS formats 0–10, decimation and refusals; DGN V7 2D and 3D; transverse Mercator, the IBGE datum shifts and CRS recognition |
| `core/pdf_reader_test.dart`, `core/pdf_import_test.dart`, `core/pdf_fonts_test.dart`, `core/pdf_images_test.dart`, `core/text_shaping_test.dart`, `core/sheets_test.dart`, `widget_sheets_test.dart` | The PDF reader on our own files and on file structures, filters, colours, texts, images and layers of other writers, plans imported to scale; TrueType reading and subsetting, bidirectional order, embedded fonts in every interface script; shaping identical to HarfBuzz on the interface strings (fixtures by `tool/fonts/make_shaping_fixtures.py`); images in PDF and SVG; sheet sets, details, charts and the revision table; PNG of a sheet |
| `core/export_test.dart`, `core/kml_test.dart` | UTM round trip; georeference; KML round trip; GeoJSON; plot scene; SVG; valid compressed PDF; sheet and report pages; same tables in CSV/TXT/XLSX |
| `core/catalog_packs_test.dart` | Every pack in `catalogs/` loads, unique ids not colliding with the default catalogue, normalised files and consistent index; pack format; loaders (assets and URL) |
| `core/examples_test.dart` | Every example, in the 20 languages, builds, is connected, passes the check, designs with zones inside the window and no deficit, prints every report cell as a plain number, and matches the files in `examples/` |
| `core/spatial_index_test.dart` | Index against brute force, drawing order, degenerate cases, invalidation in the controller, selection and snap, entities by id and counts per layer |
| `core/painter_test.dart`, `core/scene_cache_test.dart` | Result overlays (the same emitter dots in every overlay, recoloured by pressure), drawing entities, texts over the linework, the hover colour, hairlines in a view packed with linework on a 2× screen; one recording per scene, a heavy scene moved with the view and drawn sharp once it rests |
| `core/geo_parse_test.dart`, `core/i18n_lang_test.dart` | Pasted coordinates (decimals, comma, hemispheres, DMS, links); contour interval; language choice from the system and the URL |
| `core/i18n_packs_test.dart` | Every language pack covers every key of the table, the tutorial and the catalogue names with the same placeholders and is mostly not English; installed packs reach the strings, the tutorial and the catalogue; `setLanguage` loads a pack on demand with English meanwhile and retries a failed load |
| `core/editing_test.dart`, `core/model_test.dart`, `core/workspace_test.dart`, `core/design_job_test.dart`, `core/app_io_test.dart`, `core/entities_roundtrip_test.dart` | Editing (grips, transformations, trim, extend, cut), entity JSON, tabs and clipboard (pivot catalogue items and wiring included), worker protocol, local HTTP, project storage, camera and snap |
| `core/blocks_test.dart`, `core/label_rules_test.dart`, `core/snapping_extra_test.dart`, `core/gps_test.dart`, `core/auto_analysis_test.dart`, `core/selection_bom_test.dart`, `core/proposal_test.dart`, `core/finame_test.dart`, `core/licensing_test.dart`, `core/works_schedule_test.dart`, `core/limits_test.dart` | User blocks in the file and the history; conditional labels; intersection, perpendicular, tangent, quadrant, extension snaps and polar tracking, also on long contours crossing by the cursor; GPS walks, marks and stake-out; automatic analysis after edits; materials of the selection; the quote (margin to freight, trenches, payback, NPV and IRR, sectors, alternatives); FINAME codes; CONAMA categories; construction schedule; the limits the app tells the user (BigTIFF, the raster cap, TIN thinning, a PDF dropped without the dialog) |
| `core/cli_test.dart`, `core/api_examples_test.dart` | `test/core/cli_test.dart` runs the command line on a shipped example; `test/core/api_examples_test.dart` runs every snippet of docs/API.md and fails when the documents show code it does not run |
| `core/ai_agent_test.dart`, `core/ai_openai_test.dart`, `core/ai_formats_test.dart`, `core/ai_context_test.dart` | Requests follow each API: Anthropic (endpoint, headers, streaming, adaptive thinking, always on for Fable 5.1, effort, caching, refusal fallback, task budgets, compaction, clearing of old tool results; no browser header on desktop) and OpenAI (Responses API, bearer key, instructions, function tools, reasoning effort, no storage, compaction, older pictures dropped); tool turns, invalid inputs as error results, the four modes and plan approval, confirmed exports, the step limit and the spending cap, messages written while it works, Stop, retries and errors that never show a key, the data-retention refusal of Fable 5.1, refusals and fallbacks priced at the model that answered, list prices with the long-prompt rules; both formats convert to each other without loss; the project context is deterministic, bounded and never holds a key |
| `widget_ai_agent_test.dart`, `widget_ai_assistant_test.dart`, `widget_ai_tools_test.dart`, `widget_ai_vision_test.dart` | GPT with the OpenAI key, a new conversation when the company changes and neither key reaching the other company, one Claude model taking over another's conversation; a whole small project done by the agent (questions, plan, drawing, design, check, fixes, report, to-do list); messages typed while it works, rewind, the spending cap and Continue, quick commands, compaction notices, pictures, the Markdown transcript, the docked panel, its button and the phone sheet; keys in memory unless remembered, nothing sent before Send, data sheets checked before they enter the catalogue; the pixel-to-world mapping, the satellite picture taken off screen with the user's view and map unchanged, Google imagery with a key, proposed geometry, terrain pictures and profiles against exact values |
| `widget_ai_coverage_test.dart`, `widget_ai_manual_test.dart`, `widget_ai_ops_cad_test.dart`, `widget_ai_ops_eng_test.dart` | Every action, tool, alias, menu item and dialog has a route for the AI and every route exists, and `docs/AI_TOOLS.md` is the table of the map; every manual topic reads on an empty and on a designed project, every item key, design parameter and message code has its explanation, and the worked example replays; the drawing-side and engineering operations (editing, annotation, blocks, view and history, files, terrain and site, imports; calculators, network analyses, catalogue and packs, exports, automatic design), each with its approvals and undo steps. Scripted fakes of both APIs (`test/support/fake_claude.dart`, `test/support/fake_openai.dart`) stand in for the companies: no test reaches the network |
| `densogram_test.dart`, `electrical_test.dart`, `electrical_io_test.dart`, `management_test.dart` (in `core/`) | Every spray profile returns the whole flow, part circles, areas against their own mean, measured profiles and wind; routes, stations, solenoid voltage by hand, cheapest wires against brute force, wire catalogue, BOM and Electrical report, design check codes, DXF/DWG/GeoJSON/plot output; demands and automatic system flows with pivots and stations |
| `core/import_curves_test.dart` | Rational and clamped NURBS; DXF SPLINE by control points or fit points, HATCH with polyline, line, arc (both senses), ellipse and spline edges and islands, SOLID/TRACE, hatches inside blocks; DWG R2000–R2018 splines, hatches, solids and the ellipse matching LibreDWG |
| `core/controller_extra_test.dart` | Opening a file or an example drops the old marks, profile, check and history; dialog edits as one undo step (mutations folded in, units keep the results); undo with nothing to undo; grips drag wires with pipe nodes; painter for the new entities and the densogram |
| `core/regressions_test.dart` | Every defect fixed in the 2026-09-22 sweep, each failing without its fix: a lateral cut on an outlet keeps it once; generated contours stay generated; files without the id counter; mirrored part-circle sprinklers and full-circle heads with a part-circle nozzle (plot and canvas too); survey files with spaces and decimal commas; rasters too large to decode; damaged files reported as such; psi, kPa and bar; grid CU with close heads; blocks on L and U fields and guided rows clipped in two; telescoping drawn either way; numbers with thousands separators, prices and pump curves; spacings of 0 and NaN values that used to hang or break the saving; GPS tracks in KML |
| `core/hotkeys_dispatch_test.dart` | The keyboard dispatcher on its own: application, editing and canvas keys, typed coordinates, what dialogs and menus block, every typed command alias |
| `core/engine_speed_test.dart` | The faster engine gives the very same results: the elimination plan of the network solver bit for bit against the map-based solver, and the indexed lookups of links and catalogue items following every edit of their lists |
| `core/hydraulics_extra_test.dart`, `core/pump_devices_test.dart` | Friction helpers (gradients, Reynolds number, Blasius against Colebrook, Hazen C as a roughness), minor losses, devices and emitter flags; every mainline device of the catalogue in series between a tank and a zone: each splits the pipe and reports its own loss, a PRV regulates only above its setting, the pump follows its curve and the affinity laws, a calculated supply never runs below zero, suction lift |
| `core/design_extra_test.dart`, `core/area_water_test.dart`, `core/auto_fix_test.dart` | Design paths the other tests do not reach (empty and missing zones, the zone variation limit, devices inside a zone, unreachable valves, missing fittings, fixed-hour schedules, Darcy-Weisbach pivots); the defects found by checking the example gallery (heads on an area's outline, matched-precipitation uniformity, flushing convergence, staggered programme days, pivots in the water table); every correction of the design assistant on its case and on a case where it has nothing to do |
| `core/model_extra_test.dart`, `core/io_extra_test.dart`, `core/currency_test.dart` | Geometry, units, terrain and TIN edge cases, split, extend and offset on every entity type; importers and exporters on the inputs the format tests do not reach (catalogue lists, UTM zone exceptions, GeoTIFF transforms, KMZ variants, DBF encodings, DXF blocks and curves, PDF report pages); currencies by language and region, reference rates and the conversion of every price |
| `core/basemap_layer_test.dart`, `core/dem_online_test.dart` | Map tiles against a fake server: cache and eviction, a coarser zoom instead of a blank map, the nearest ancestor of a missing tile, the ArcGIS tilemap and the Google Map Tiles session; the online elevation grid, batches, concurrent downloads with retries and pacing, and the datum check of the user's own data |
| `core/region_trace_test.dart` | Field outlines on synthetic aerial pictures: crop rows traced to the field edges, trees inside filled and reported, fields cut by the picture edge flagged, every field of a picture found |
| `core/ai_api_fixes_test.dart`, `core/ai_transport_io_test.dart`, `core/ai_image_prep_test.dart` | The assistant against scripted failures of the APIs (refused and oversized requests, service errors, timeouts and dropped streams, each with what is kept and sent again); the desktop transport against a server on the machine (upload, streaming, a cancel closes the connection); attached pictures typed by their bytes, turned upright, scaled into the model limits and re-encoded within the size |
| `core/app_logic_test.dart` | App logic without widgets: command aliases, translated action labels, tutorial navigation, the route observer, the design runner without workers, desktop files and language assets |
| `widget_ai_*.dart` (the files not named above) | The assistant's start screen, beginner help, chat behaviour and Markdown, error messages, marks on the map, voice, field photos, paste and drop, saved conversations, `/review`, the sheet preview and the pictures it sends |
| `editorial_names_test.dart` | The editorial rule: no competing product anywhere in the repository and no CAD product in the interface, the site and the documentation, checked by SHA-256 so that the test names none of them |
| `widget_*.dart` | Real interface: welcome screen and tutorial, gallery, menus and dialogs, panels, canvas editing, shortcuts, history, terrain and compact layout; management with pivots and automatic flows, dialogs closed outside, densogram, controller and wire tools with the Electrical tab, ordinate and diameter dimensions, the Wires tab of the catalogue, numeric fields that reject a value; the properties of every entity type, batch editing and the results of the selection; the profile chart readout; wheel, trackpad, middle-button and two-finger navigation; georeference and plot dialogs; mainline and phone menus; the system flows dialog; the dialogs of automatic design, agronomy, mechanised machines, network operation, transients, PDF import, sheets and blocks and vegetation, each applying as one undo step and laying out on a 390 × 844 phone; the right-to-left layout of Arabic and Urdu, conditional labels, the GPS chip, the breakline tool and the materials of the selection |
| `widget_theme_test.dart` | The dark palette is the original look, colour for colour; the light palette keeps WCAG AA contrast for the text on its surfaces; View → Theme switches in place (same shell, project and selection), also from the phone menu, and the sheets build in light; a white layer draws near-black on the light canvas while plots stay unchanged; the choice is saved and applied at start-up; Follow the system tracks the platform brightness live; the pictures for the AI assistant keep the dark canvas |
| `web_metadata_test.dart`, `version_test.dart`, `web_offline_test.dart` | Generated site pages, SEO, JSON-LD, manifest, icons, robots, sitemap, 404, llms.txt; the entry pages load the app on demand; app version consistent with pubspec.yaml, the generator and the site; `test/web_offline_test.dart` covers the service worker generator, the templates and the build script |
| `flutter_test_config.dart` | Runs around every test file: the file fails when the interface asked for a string key the table does not have |

Known pitfalls when writing widget tests: the calculation is truly asynchronous and must run inside
`tester.runAsync`; dialog titles may be upper-case; the canvas needs a defined window size; asset
loading (catalogues) uses `rootBundle` and works in `flutter test`.

---

## 17. Known limitations and roadmap

- **Looped networks**: the LP sizes loops on tree paths (an approximation) and is solved again with
  the flows of the new sizes until they settle; the final analysis checks, and the greedy method is
  the safe alternative.
- **Network solver**: pressure-compensating emitters in grossly undersized networks (flows many
  times what the pipes can carry) may still fail to converge; the design then reports
  `not_converged` instead of figures.
- **Transients**: the analysis covers the mainline of each system flow, with the zones seen from it
  as orifices at their valves; friction is quasi-steady (a constant factor per pipe); air vessels
  (hydropneumatic tanks) are modelled by the engine but cannot be placed in a project yet.
- **24-hour simulation**: a project has no storage tank whose level changes over the day (the
  supplies keep their level); tanks, patterns and level controls exist in the engine's
  extended-period simulation ([docs/API.md](docs/API.md)).
- **Electrical**: the design wires the valves conventionally (a station conductor per valve and a
  shared common) with 24 V AC solenoids; the two-wire (decoder) sizing of Automatic wire routes is a
  separate analysis whose decoders and cable do not enter the bill of materials.
- **DWG and DXF**: the reader covers the typical entities of a plan (lines, polylines, circles,
  arcs, ellipses, splines, hatches, solids, leaders, points, texts, blocks and dimensions), with
  R13/R14 read in part; the writers produce R2000 only (DWG with colour indices; true
  colours in the DXF), and pictures go out as their frame, without the raster.
- **PDF plans**: shadings, pattern fills (drawn grey), transparency groups, annotations and Type 3
  glyph drawings are not interpreted; clipping is approximated by rectangles; filled areas come in
  as outlines; encrypted files and JPEG 2000 or JBIG2 images are left out; the work of a page is
  capped, and a truncated page says so.
- **Other files**: compressed LAZ clouds, DGN V8 and BigTIFF are refused by name; rasters above 100
  million pixels are refused; a terrain above 12 000 samples is triangulated from a uniform subset.
- **Datums**: SAD 69 and Córrego Alegre are shifted with three-parameter translations (a few metres
  of accuracy); a grid-based transformation is not applied.
- **Densogram**: one spray profile for every head without a measured profile (chosen in the
  dialog: sprays are closer to uniform, single-nozzle impact sprinklers to triangular); wind is a
  first-order drift of the calm-air pattern, not a substitute for windy-day measurements.
- **Agronomy and field models**: soil values are typical ones for the texture class; the wetted
  bulb formula comes from two soils and two emitters and extrapolates outside them; the corner arm
  assumes level ground, a rigid arm and a convex guide path; surface irrigation uses the volume
  balance, not a hydrodynamic model.
- **Vegetation detection**: plain image processing of the colours and texture of one image: dry
  lawns, deep shade or green roofs can be misread, so the outlines need a check; the imagery's terms
  of use apply.
- **Automatic copy in the browser**: about 3.5 MB per project after compression; larger projects
  keep only their file (the app says so once).
- **Collaboration**: no simultaneous editing; projects are shared by the `.oci.json` file or by a
  link, which leaves the images and results out and is refused when the project is too large.
- **Performance**: projects with hundreds of tapes per zone take a few seconds per zone; the
  flushing step is the heaviest.
- **Offline start**: tested in Chromium-based browsers; base maps, online elevation and climate,
  catalogues by URL and the AI assistant need the network.
- **Native mobile**: the `android/` and `ios/` folders are Flutter's templates and are neither
  built nor tested; phones and tablets use the web app.
- **AI assistant**: needs the network and an account with API credit at Anthropic or OpenAI
  (Claude Fable 5.1 also 30-day data retention); in the browser a rejected OpenAI key shows as a
  network failure, since OpenAI's error answers carry no CORS header; pictures do not ask for
  approval although they download base-map tiles; positions read off pictures are approximate; the
  analyses it runs (transients, 24-hour simulation and the like) run on the interface thread;
  conversations never go into the project file nor into share links, but they stay in this
  browser (the 12 most recent of each project, with their pictures and small attachments) until
  *Keep conversations in this browser* is turned off, which also deletes them: on a shared computer,
  turn it off or clear the site data. It was tested against scripted fakes of both APIs, not
  against the live services. Its answers can be wrong like any model's: changes go through the
  approval, undo and rewind of section 9, and the design should be checked.

Suggested roadmap: two-wire systems in the design's bill of materials; air vessels and storage
tanks placed in a project; additional community catalogues; browser tests of the offline start in
Firefox and Safari; automated browser tests for runtime language switching.

---

## 18. Contributing

- **Issues and pull requests** are welcome on
  [GitHub](https://github.com/videjunior/opencadirrigation). Before a pull request run
  `flutter analyze` and `flutter test`; rebuild `web/design_worker.js` with `tool/build_worker.sh`
  after changing `lib/core` or `i18n.dart`, and run the generator a failing guard test names.
  Contributions are accepted under the MIT licence of the project.
- **Catalogues**: follow [catalogs/README.md](catalogs/README.md), run
  `dart run tool/gen_catalogs.dart` and open a pull request; the tests guarantee unique ids and
  plausible curves.
- **Examples**: add a builder in `lib/app/examples.dart`, texts in `i18n.dart` and run
  `dart run tool/gen_examples.dart`; the test designs the example and requires zones inside the window.
- **Translations**: every key of `i18n.dart` is a (pt, en, es) tuple and every other language is a
  pack in `assets/i18n/<code>.json` (strings, tutorial and catalogue names; the tests fail on a
  missing key or placeholder); the site pages are in `tool/site.dart` and `tool/site/<code>.dart`.
  A string with characters the PDF fonts do not cover yet needs `tool/fonts/build_fonts.py`.
  Documentation is maintained in English (`README.md`, `docs/TECHNICAL_STUDY.md`, `docs/API.md`)
  and translated to Portuguese (`README.pt-BR.md`, `docs/PESQUISA.pt-BR.md`, `docs/API.pt-BR.md`):
  change the English version first. The snippets of the API documents are run by
  `test/core/api_examples_test.dart`.
- **Engine**: every new formula comes with a test against a published reference value.
- **Interface**: colours come from `Cad.*` (`lib/app/theme.dart`), which change with the theme:
  read them in `build` and `paint`, never in `const` expressions or in fields that outlive a
  rebuild. A new command, tool, menu item or dialog needs its route for the AI assistant in
  `lib/app/ai/ai_coverage.dart` (the coverage test says which is missing).
- **Editorial rule**: competing irrigation-design products and their makers are never named, anywhere
  in the repository (code, comments, texts, tests, documentation and commit messages), and neither
  are CAD products: a file format goes by the name of the format (DXF, DWG R2000). Component
  manufacturers appear only as the origin of catalogue data; EPANET may be cited as the reference of
  an algorithm; data and map providers (OpenStreetMap, Esri, Open-Meteo…) and the AI providers
  (Anthropic, OpenAI) appear as sources and credits; other programs (spreadsheets, GIS, virtual
  globes, browsers) only as the target of a file format. `test/editorial_names_test.dart` checks the
  forbidden names by their SHA-256, so it names none of them.

---

## 19. References

The study that guided the project, with what a designer expects from an irrigation CAD, the engine
formulas, the sizing formulations, agronomy, pivots, terrain, the file formats and the bibliography,
is in [docs/TECHNICAL_STUDY.md](docs/TECHNICAL_STUDY.md) (Portuguese translation in
[docs/PESQUISA.pt-BR.md](docs/PESQUISA.pt-BR.md)). The modules added since then cite their sources
in their doc comments, with the equation and table numbers they use:

| Topic | Sources |
|---|---|
| Transients | Wylie, E. B.; Streeter, V. L. (1993), *Fluid Transients in Systems*; Chaudhry, M. H. (2014), *Applied Hydraulic Transients*; Thorley, A. R. D.; Faithfull, E. M. (1992), *Inertias of pumps and their driving motors* (also Thorley 2004, *Fluid Transients in Pipeline Systems*); Bergant, A.; Simpson, A. R.; Tijsseling, A. S. (2006), "Water hammer with column separation: a historical review", *Journal of Fluids and Structures* 22(2) (vapour cavity model) |
| Air valves | AWWA Manual M51, *Air-Release, Air/Vacuum, and Combination Air Valves* |
| Extended period, EPANET files | Rossman, L. A. (2000), *EPANET 2 Users Manual*, and the analysis algorithms of EPANET 2.2; EPANET 2.2 Users Manual, EPA/600/R-20/133 (input file format) |
| Sizing and pipes | Alperovits, E.; Shamir, U. (1977), *Water Resources Research* 13(6) (looped networks); Scobey (1930), after Keller & Bliesner (1990); Chow (1959) (Manning n); ISO 1452-2 and ISO 4427-1 annex A, NBR 14312 (pressure class derating with temperature); ANSI/HI 9.6.1 (NPSH margin) |
| On-demand networks | Clément, R. (1966), "Calcul des débits dans les réseaux d'irrigation fonctionnant à la demande", *La Houille Blanche* 5; Lamaddalena, N.; Sagardoy, J. A. (2000), *Performance analysis of on-demand pressurized irrigation systems*, FAO Irrigation and Drainage Paper 59; Wichura (1988), AS 241; L'Ecuyer (1999), MRG32k3a |
| Criticality, calibration | Wagner, J. M.; Shamir, U.; Marks, D. H. (1988), *J. Water Resources Planning and Management* 114(3); Kiefer (1953); Levenberg (1944); Marquardt (1963) |
| Energy and tariffs | Jiménez-Bello, M. A. et al. (2010), *Biosystems Engineering* 105(4); Carrillo Cobo, M. T. et al. (2011), *Irrigation Science* 29; ANEEL Normative Resolution 1,000/2021, art. 186; MME Normative Ordinance 137 of 8 June 2026 |
| Routing and wiring | Alpert, C. J. et al. (1995), *IEEE Trans. Computer-Aided Design* 14(7); Takahashi, H.; Matsuyama, A. (1980), *Math. Japonica* 24; Dijkstra (1959) |
| Agronomy | Allen, R. G.; Pereira, L. S.; Raes, D.; Smith, M. (1998), FAO Irrigation and Drainage Paper 56; Ayers, R. S.; Westcot, D. W. (1985), FAO-29 Rev. 1; Smith (1992), FAO-46; Brouwer & Heibloem (1986), FAO Training Manual 3; Savva & Frenken (2002), FAO Irrigation Manual Module 9; USDA-SCS (1970) TR-21 and NRCS NEH Part 623 ch. 2; Keller & Bliesner (1990); Keller, J.; Karmeli, D. (1974); Rawls, Brakensiek & Saxton (1982), *Trans. ASAE* 25(5); NRCS NEH Part 652 (1997); USDA-SCS NEH Section 15 ch. 11 (1983); Irrigation Association SWAT protocol (2008) and US EPA WaterSense (2011); Schwartzman & Zur (1986), *J. Irrig. Drain. Eng.* 112(3); California MWELO (CCR Title 23, §§ 490–495, 2015); Burt, O'Connor & Ruehr (1995), *Fertigation* |
| Solar pumping | IEC 62253:2011; IEC 61724-1; Duffie & Beckman, *Solar Engineering of Thermal Processes* (Liu & Jordan; Erbs, Klein & Duffie 1982) |
| Mechanised and surface irrigation | Heermann & Hein (1968); NRCS NEH Part 623 ch. 4 and 11; Kansas State University MF3608 (2022); Evans, R. G. et al. (2013), *Irrigation Science* 31; IEC 60364-5-52 annex G, IEC 60228, IEEE Std 399 and 446; Walker & Skogerboe (1987) and Walker (1989), FAO-45; Elliott & Walker (1982); Strelkoff (1977); U.S. Bureau of Reclamation, *Water Measurement Manual* |
| Layout and turf | Irrigation Association (2014), *Landscape Irrigation Best Management Practices*; Keller & Bliesner (1990); IFAB Law 1, World Athletics and USGA recommendations for pitches, tracks and greens; Garcia-Castellanos & Lombardo (2007), *Scottish Geographical Journal* 123; Seginer, Kantz & Nir (1991) (sprinklers in wind) |
| Vegetation detection | Woebbecke et al. (1995) (excess green); Otsu (1979); Meyer & Neto (2008); Gitelson et al. (2002); Taubin (1995); Douglas & Peucker (1973) |
| Terrain and coordinates | Sloan (1993), *Computers & Structures* 47(3) (constrained Delaunay); ASPRS LAS 1.4 R15 (2019); LandXML 1.2 (2008); IBGE R.PR 1/2005 and R.PR 23/1989 (SIRGAS 2000, SAD 69, Córrego Alegre); OGC 01-009 (WKT 1), ISO 19162:2019 (WKT 2), EPSG; Karney (2011) |
| Formats and details | ISO 32000-1 (PDF); OpenType and Unicode (UAX #9, Character Database); RFC 7946 and the 2008 GeoJSON specification; GPX 1.1; ISO 16739-1:2018 (IFC4) and ISO 10303-21; ESRI Shapefile Technical Description (1998); ISFF (DGN V7); ASAE S376.2 (covers of buried thermoplastic irrigation pipelines); Azevedo Netto, *Manual de Hidráulica* (suction submergence); CONAMA Resolution 284/2001 (licensing categories) |

---

## 20. Licence, third-party components and data

OpenCADIrrigation is released under the [MIT licence](LICENSE.md). It is an engineering aid: its
results depend on the data entered and on the catalogue values, and a qualified designer should
check a design before it is built (the licence carries no warranty).

| Component | Used for | Licence |
|---|---|---|
| Flutter and the Dart SDK | framework and language | BSD-3-Clause |
| [`web`](https://pub.dev/packages/web) | browser APIs (files, storage, workers, geolocation, streamed requests) | BSD-3-Clause |
| [`xml`](https://pub.dev/packages/xml) | KML, GPX, LandXML and XLSX | MIT |
| [`archive`](https://pub.dev/packages/archive) | KMZ, XLSX, zipped shapefiles, PDF streams, compressed share links and stored projects | MIT |
| [`image`](https://pub.dev/packages/image) | raster images, images in PDFs, vegetation detection and the brand assets | MIT |
| [`cupertino_icons`](https://pub.dev/packages/cupertino_icons) | icon font | MIT |
| CanvasKit (Skia) | rendering, served by the site with the app | BSD-3-Clause |
| Material Icons, Roboto, Noto | interface fonts (Roboto served with the app; Noto fetched on demand for other scripts and kept for offline use) | Apache-2.0, SIL OFL 1.1 |
| Noto Sans subsets in `assets/fonts` (Latin, Math, Arabic, Devanagari, Bengali, Gurmukhi, Telugu, SC, JP) | text of the PDFs in every interface script | SIL OFL 1.1 ([assets/fonts/OFL.txt](assets/fonts/OFL.txt)) |

Online services, reached when you use them, have their own terms; the app shows their
credits: base maps (© OpenStreetMap contributors under the ODbL, OpenTopoMap under CC-BY-SA, CARTO,
Esri, Google Maps with your own key, or the XYZ or WMS server you configure), elevation (Terrain
Tiles on AWS Open Data: SRTM/NASA, GMTED, ETOPO1; Open-Meteo under CC BY 4.0 with the Copernicus DEM
GLO-90; OpenTopoData: NASA SRTM, ASTER GDEM), climate (Open-Meteo historical weather API under CC BY
4.0, ERA5 reanalysis of the Copernicus Climate Change Service, free for non-commercial use; NASA
POWER, with the acknowledgement NASA asks for) and the AI assistant (the APIs of Anthropic and
OpenAI, used with your own key and account under that company's terms, which bill the usage to
that account; site searches by address use OpenStreetMap's Nominatim, © OpenStreetMap contributors
under the ODbL, within its usage policy; the satellite pictures come from Esri World Imagery or,
with your key, Google).

The manufacturer catalogues in [catalogs/](catalogs/) were compiled from the manufacturers' public
data sheets, and every pack names its source. Product names and trademarks belong to their owners;
the project is not affiliated with any of them, and prices are reference values to confirm with a
dealer.
