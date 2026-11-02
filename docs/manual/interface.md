# Interface

## Layout (wide screen)

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
- **AI assistant panel** (optional, [AI assistant](ai-assistant.md)) docked beside the canvas,
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

## Compact layout (phone and tablet)

Below 700 px of width the screen changes: ☰ menu at the top, tool bar by group at the bottom,
Done/Cancel buttons instead of Enter/Esc, properties, reports and the AI assistant in sliding
panels. Pinch to zoom, two fingers to pan, one finger draws.

## Menus

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

## Keyboard shortcuts

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
