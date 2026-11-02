# Five-minute start

1. Open [opencadirrigation.com](https://opencadirrigation.com) and press **Open the app** (or open
   an example or the tutorial straight from the page). The app opens by itself on later visits, on
   an empty project, with a start screen that asks two things: **where the area is** (an address
   found on OpenStreetMap, or coordinates; the project is georeferenced there, on the satellite map)
   and **whether to design with the AI assistant**.
2. Draw the area, let the assistant design it, or open a ready example: Help → Welcome and example
   gallery (with the **interactive tutorial**, 80 steps) or File → Examples.
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

## Example gallery

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
Examples menu and from the URL. The same projects are in [examples/](../../examples/) as `.oci.json`
files, one folder per interface language (`examples/de/`, `examples/ja/`, … 20 in all): the same
drawing everywhere, with the names, crops and catalogue items in that language.

## URL parameters

| Parameter | Effect |
|---|---|
| `?example=garden` | Opens the given example (`orchard`, `garden`, `sportsField`, `rowCrop`, `pivot`, `greenhouse`, `nursery`, `coffee`, `bananas`, `sugarcane`, `gravity`, `pasture`, `golf`, `sectorPivot`, `linear`). |
| `?design=1` | Designs on load. |
| `?ai=1` | Opens the AI assistant beside the drawing (the site's "Open the AI assistant" button and the app shortcut). |
| `?tutorial=N` | Opens the interactive tutorial at step N (1 to 76). |
| `?lang=pt` (any code of [Languages and site](languages-and-site.md)) | Language for this visit (does not change the saved preference). |
| `/pt/`, `/es/`, `/de/`, … | Entry page of each language under its code (all 20), with the same effect as `?lang` (the root page is the English one). |
| `#p=…` | A project shared by link (File → Share by link…): it opens as a copy in a new tab. The part after `#` is never sent to any server. |
