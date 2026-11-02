# Interface

## Layout (wide screen)

- **Menu bar** at the top (the menus that do not fit a narrow window go under ⋯); on the right, the
  ▶ Design and Save buttons (amber when there are unsaved changes).
- **Project tabs** just below: several projects open at once (Ctrl+Alt+N new tab, Ctrl+Alt+W
  close, Ctrl+Alt+←/→ switch). Copy and paste (Ctrl+C/X/V) work across tabs and across browser
  windows, carrying layers and catalogue items missing at the destination (an item whose id the
  destination gives to something else is renamed, prices follow the destination's currency, and
  between georeferenced projects the items keep their place on the map).
- **Tool palette** on the left, by group (navigation, drawing, editing, terrain, zone, mainline,
  electrical, review).
- **Canvas** in the centre, with grid, snaps, overlays and the calculation progress card.
- **Side panel** on the right with three tabs: **Properties** of the selected item (with hydraulic
  results after the calculation and the submain position envelope for laterals; a selection of
  several kinds shows one chip per kind, to edit one kind at a time), **Layers** (visibility, lock,
  colour, rename, create, remove, isolate and layer states) and **History** (a timeline of states, as
  in Photoshop: click to go back or forward). Drag its edge to change its width, which is kept; View
  → Interface folds it away.
- **Reports** below the canvas (F2), resizable.
- **AI assistant panel** (optional, [AI assistant](ai-assistant.md)) docked beside the canvas,
  opened and closed from Design → AI assistant… or its status-bar button.
- **Status bar** with cursor coordinates, active snap (and the snap chosen for the next point only),
  typed command or coordinates, tool hint, toggles (snap, ortho, grid, polar tracking, keep
  connections), the real scale of the screen, the GPS accuracy while the device GPS is on, the
  automatic-analysis chip, a warning while the copy in the browser cannot be kept, the AI assistant
  button and the app version.
- **Command palette** (Ctrl+K, Help → Search commands…): every item of the menus, the typed commands
  and the switches of the screen and of the interface, found by their name in the interface language
  or in English, without accents or case; ↑ ↓ choose, Enter runs. On a phone the search is at the top
  of the ☰ menu.
- **Help → Manual (F1)** and the **?** of the main windows and panels: a short explanation of each
  part of the program in the interface language, with its chapter of this manual one click away.
  Help → What's new lists the news of the version (also once after an update), Help → Recent
  messages… keeps the notices shown on screen, and Help → Report a problem or suggest a feature…
  prepares a GitHub issue with a diagnosis free of personal data, or copies the text.

In Arabic and Urdu the whole layout is mirrored (menus, panels and dialogs read right to left);
the drawing keeps its coordinates.

**Interface**: View → Interface sets the size of the whole interface (without the zoom of the
browser), a high contrast (dark and light palettes at 7:1), focus mode (the drawing board alone,
Ctrl+Alt+F) and the side panel folded away.

**Numbers** show in the notation of the interface language: a decimal comma on screen in Portuguese,
Spanish, German, French, Indonesian, Turkish, Russian and Vietnamese, and a number typed as "2.000"
in Portuguese is two thousand; when a typed number could be read both ways, the field offers the
other reading just below it. Files, technical exports and the AI assistant keep the decimal point.

**Theme**: View → Theme → Dark (the default), Light or Follow the system (also in the phone menu).
The choice is saved and switches live, without losing the open projects, the selection or the open
dialogs. On the light canvas (white) the drawing colours follow the usual CAD rule: white and
near-white draw near-black and other light colours are darkened with their hue kept, so nothing
fades into the background; the data keeps its colours, and the selection shows in magenta instead
of yellow. Plots and exports (PDF, SVG, PNG sheets) are paper and do not change with the theme.

## Compact layout (phone and tablet)

Below 700 px of width, and on a phone held sideways, the screen changes: ☰ menu at the top (with a
search, the tabs and the recent projects), tool bar by group at the bottom, Done/Cancel buttons
instead of Enter/Esc, properties, reports and the AI assistant in sliding panels. Pinch to zoom, two
fingers to pan, one finger draws; the ⌨ button types commands, coordinates and lengths (with the
keys @ < , ; - . and ABC/123). A finger held still opens the context menu of the drawing board, and
held then dragged opens a selection window; *Add to selection* makes every tap count as Shift+click;
a magnifier over the finger shows where the point goes, placed where the finger lifts. Between 700 and
1100 px (a tablet in portrait, a narrow window) the side panel goes into a drawer and the AI assistant
into a sheet. Buttons are at least 48 px for the finger.

## Menus

| Menu | Items |
|---|---|
| File | New project, New project tab, Close tab, Open project, Recent projects ▸ (and Browser storage), Save project, Version history, Autosave in the browser (on/off), Examples ▸, Import (DXF, DWG, DGN, PDF, KML/KMZ, SHP, GeoJSON, GPX, LandXML, LAS, EPANET, CSV/TXT/XYZ/PTS/PNEZD points, images, GeoTIFF), Insert project, Georeference selected image, Align by 2 points, Export drawing ▸ (DXF, DXF R12, DWG, PDF, SVG, KML, KMZ, GeoJSON, Shapefile, GPX, LandXML, IFC 4, EPANET, PNG, stake-out points), Export report ▸ (CSV, TXT, XLSX, PDF, controller programme), Export document package (PDF), Share by link, Project details, Title block and technical lead, Georeference, Save as, Save as copy, Browser storage, Compare with, Bring back the comments of a copy, Saved downloaded data |
| Edit | Undo, Redo, Select all, Copy, Cut, Paste, Duplicate selection, Delete selection, Materials of the selection, Save selection as block, Insert block, Modify ▸ (rotate, mirror, scale, offset, trim, extend, cut pipe, align by 2 points, array), Move, Copy with base point, Select ▸ (similar, quick select, all on the current layer, lasso, fence), Geometry ▸ (stretch, fillet, chamfer, break at two points, join, explode, convert to area, subtract from area, remove the islands of the area), Lengthen, Outline by a click inside, Drawing order ▸ (bring to front, send to back), Move to the current layer, Blocks ▸ (edit a block in place, explode references, export and import the block library) |
| View | Zoom all, Zoom in/out, Grid, Labels, Wetted radii, Edit grips, Conditional labels, Device GPS, Overlay (none, velocity, pressure, diameters, min/max pressure per zone, densogram, terrain slope, terrain aspect), Base map ▸ (none, OpenStreetMap, OpenTopoMap, CARTO, Esri imagery/streets/topo, Google Maps roadmap/satellite/hybrid/terrain with your own API key, custom XYZ or WMS URL, the street map server, the terms of the maps, keep the map of the area for the field; needs a georeference), Google Maps API key…, Custom map URL…, Language ▸, Theme ▸ (dark, light, follow the system), Interface ▸ (size, high contrast, focus mode, side panel folded), Snaps and drawing, Layers ▸ (isolate the layer, show every layer, layer states) |
| Draw | Line, Polyline, Rectangle, Circle, Arc, Spline, Hatch, Symbol, Text, Dimension, Angular dimension, Radial dimension, Ordinate dimension, Leader, Contour, Spot height, Irrigated area, Trace on the image, Measure, Elevation profile, Comment, Revision cloud, GPS in the field ▸ (record a walk; finish it as an irrigated area, a closed outline or a line; mark a point at the current position; discard the walk), Dimension style, Field photo |
| Zone | Zone pipe, Sprayline (lateral), Drip tape / dripline, Outlet, Control valve, Misc. hydraulic, Junction, Lateral block, Sprinkler grid, Allowable submain position, Densogram, Device on the selected laterals, Turn the selected laterals into blank pipe, Controller, Wire route, Automatic wire routes, Two-wire system (decoders) |
| Mainline | Water supply, Mainline pipe, Pump, Misc. hydraulic, outlet and junction on the mainline, Select pump, Hydraulic transients, Air valves, 24-hour simulation, On-demand operation (Clément), Pipe criticality, Calibrate roughness from readings, The design over its life (ageing and clogging), Fertigation, Centre pivot / linear move, Traveller lanes, Furrows with gated pipe |
| Design | Design parameters, Component catalog, System flows (management), Time-of-use tariff and flow schedule, Group zones for energy, Commercial quote, Design alternatives, Site climate, Pump house electrics, Solar pumping of the design, Water quality and filtration, Agronomy ▸ (daily water balance, irrigation programme, runoff potential, fertigation by stage, uniformity in the field, user crops), Terrain ▸ (contour, breakline, spot height, elevation profile, download elevation from the internet, generate contours from the model, 3D terrain view, clear profile, TIN or IDW interpolation), Automatic design ▸ (automatic sprinkler layout, sports turf and golf templates, subdivide a field into blocks, orchard drip rings, fit a pivot to the field, several pivots in the property, detect vegetation in the image), Design check, Fix automatically, Optimise design, AI assistant, Size zones, Size mainline, Design all, Analyse (existing sizes), Analyse automatically while editing, 3D terrain view, Clear results |
| Reports | The tabs of the panel, Technical documents ▸ (water permit table and self-monitoring, descriptive and calculation memorial, operation and maintenance plan, budget by unit-cost compositions, life-cycle cost) |
| Tools | Lateral calculator, Pump & system curve, Water hammer, Solar pumping, Wetted bulb, Landscape water budget, Hose-reel traveller, Surface irrigation (furrows, borders, basins), Gated pipe, Units |
| Help | Interactive tutorial, Welcome and example gallery, Keyboard shortcuts, Recent messages, Search commands (Ctrl+K), Manual (F1), What's new, Report a problem or suggest a feature, Terms of the data, About |

## Keyboard shortcuts

With the drawing focused, type the alias and **Enter** or **Space**; a complete alias also runs by
itself after a pause. Aliases accept Portuguese, English and Spanish names (for example `LINHA`,
`LINE`, `LINEA`). The full list is in Help → Keyboard shortcuts.

| Group | Aliases |
|---|---|
| Navigation | `S` select · `P` pan · `Z` / `ZE` zoom extents · `ZI` / `ZO` zoom |
| Drawing | `L` line · `PL` polyline · `REC` rectangle · `C` circle · `A` arc · `SPL` spline · `H` hatch · `SY` / `I` symbol · `T` / `MT` text · `D` dimension · `DAN` angular dimension · `DRA` radial / diameter dimension · `DOR` ordinate dimension · `LE` leader · `ME` / `DI` measure · `NOTE` comment · `RC` revision cloud |
| Terrain | `CT` contour line · `BRK` breakline · `SP` spot height · `PR` profile · `AR` irrigated area |
| Editing | `M` move · `CO` / `CP` copy with a base point · `COPYCLIP` copy to the clipboard · `RO` rotate · `MI` mirror · `SC` scale · `O` offset · `TR` trim · `EX` extend · `CUT` / `BR` cut pipe · `ARRAY` array · `STRETCH` / `STR` stretch · `FILLET` / `FIL` fillet · `CHA` chamfer · `BREAK` / `BK` break at two points · `JOIN` / `JO` join · `X` explode · `TOAREA` convert to area · `LEN` lengthen · `BO` outline by a click inside · `TOFRONT` / `TOBACK` drawing order · `E` erase · `PA` paste · `U` undo · `REDO` · `ALL` select all · `DUP` duplicate · `AL` align by 2 points · `WBLOCK` / `SB` save selection as block · `INSERT` / `IB` insert block · `BEDIT` edit a block in place |
| Selection and layers | `SIMILAR` select similar · `QSELECT` / `QS` quick select · `SELLAYER` all on the current layer · `LASSO` / `WP` lasso · `FENCE` / `FEN` fence · `LAYISO` / `LAYUNISO` isolate the layer, show every layer · `LAYCUR` move to the current layer |
| Snap of the next point | `END` · `MID` · `INT` · `PER` · `TAN` · `NEA` · `CEN` · `QUA` · `NOD` · `EXT`, typed while drawing (`NON` clears it) |
| Zone | `ZP` zone pipe · `SL` lateral · `DT` tape · `OUT` / `EM` emitter · `V` valve · `F` device · `J` junction · `B` block · `AH` sprinkler grid · `FE` submain envelope · `DENS` densogram |
| Electrical | `CTRL` controller · `WR` wire route · `WROUTE` automatic wire routes |
| Mainline | `MP` mainline pipe · `WS` supply · `PU` pump · `PV` pivot |
| Automatic design | `LAYOUT` sprinkler layout · `TPL` turf and golf templates · `SUBDIV` field blocks · `RINGS` drip rings · `PFIT` pivot fit · `VEG` vegetation · `WAND` trace on the image |
| Analyses | `SURGE` transients · `AV` air valves · `EPS` 24-hour simulation · `DEMAND` on-demand operation · `CRIT` criticality · `CALIB` roughness calibration · `FERT` fertigation · `TARIFF` tariff schedule · `EGROUP` energy grouping |
| Design and files | `RUN` design · `CHK` check · `FIX` fix automatically · `OPT` optimise · `AI` / `IA` / `ASK` AI assistant · `REP` reports · `SAVE` · `OPEN` · `OS` snap · `OR` ortho · `GS` grid snap · `GR` grid |

| Key | Action |
|---|---|
| F1 | Manual (the subject last read) |
| F2 | Show/hide reports |
| F3 | Toggle object snap |
| F5 | Design all |
| F7 | Grid |
| F8 | Ortho |
| F9 | Grid snap |
| F10 | Polar tracking step: off, 15°, 30°, 45°, 90° |
| Home | Zoom extents |
| Enter | Finishes the polyline/lateral being drawn; when selecting, repeats the last tool |
| Esc | Cancels the tool or clears the selection; a line being drawn ends keeping what was drawn |
| Del | Deletes the selection |
| Backspace | With the select tool, deletes the selection; while drawing, undoes the last point |
| Tab | In the dynamic input beside the cursor, keeps the typed length and goes to the angle |
| Shift (held) | Locks the segment to 0°, 45°, 90° |
| Ctrl+Z / Ctrl+Y | Undo / redo |
| Ctrl+A, Ctrl+D | Select all, duplicate |
| Ctrl+C / X / V | Copy, cut, paste (also across tabs and windows) |
| Ctrl+S, Ctrl+O, Ctrl+I | Save, open, import |
| Ctrl+Alt+N / W / ← / → | New tab, close tab, switch tabs |
| Ctrl+K | Command palette |
| Ctrl+Alt+F | Focus mode (the drawing board alone) |

While a tool waits for a point, the same command line takes coordinates in the display unit:
`x,y` absolute, `@dx,dy` relative to the previous point, `@d<a` polar (distance and angle in
degrees, counter-clockwise from east) or a bare distance along the direction of the cursor, then
Enter (`;` separates numbers written with a decimal comma). In a georeferenced project it also takes
coordinates of the field: UTM with its zone (`23S 456789 7654321`, or `UTM 23K 456789 7654321` with
the latitude band), UTM in the project's zone (`UTM 456789,7654321`) and latitude and longitude
(`LL -22.5,-47.1`, degree marks or hemisphere letters, degrees, minutes and seconds). An angle can be
an azimuth (`A45`) or a bearing (`N45E`). While a line is being drawn, `C` closes it and `U` takes
back the last point; Rotate takes a typed angle, Scale a factor and Offset a distance. Tools →
Units also offers ft H₂O and kgf/cm² for pressures.

Shortcuts are captured natively (window keyboard listener in the browser, `HardwareKeyboard` on
desktop) and work whatever widget has the focus, except while a menu or a dialog is open.
