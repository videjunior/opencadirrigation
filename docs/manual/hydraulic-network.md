# Hydraulic network

## Hydraulic entities

| Entity | Alias | Layer | Role in the calculation |
|---|---|---|---|
| Water supply | `WS` | WATER_SUPPLY | Origin of the mainline. Calculated pressure (well with a negative water level, reservoir with a positive height) or fixed (mains with design and maximum pressure and flow). *Reservoir or dam…* in its Properties ties it to a reservoir: the closed outline of the water at the full level, a dam or pond (the ground inside the outline) or an excavated reservoir (flat bottom and side slopes), the full, lowest and starting levels and the inflow; it gives the stage–area–volume curve from the terrain, the usable volume, the cut of an excavation, the days of demand and the time to fill, the design pumps from the lowest level and the 24-hour simulation lets the level fall and rise. |
| Pump | `PU` | PUMPS | Catalogue H(Q) curve, with speed ratio, or a variable-speed drive that holds a target outlet pressure between a minimum and the full speed; efficiency and NPSH required curves when the catalogue has them; motor and drive efficiency; operating point in the system-flow analysis; optional hour meter; a flywheel (kg·m²) that slows the pump trip of the transients. *Pump station…* makes the item a station: its own pump and the ones after it, joined in parallel (their flows add) or in series (their heads add), on duty or on standby, with a staged start by the flow of each system flow; the design solves the curve of the pumps that run together and gives the duty of each, and standby pumps go to the bill of materials. |
| Mainline pipe | `MP` | MAINLINE_PIPES | From the supply to the valves; fixed diameter or sized (`computerSized`). |
| Zone valve | `V` | CONTROL_VALVES | Separates mainline and zone; names the zone; may have a fixed downstream pressure for a detailed analysis, and a pilot: pressure reducing (the pressure held after it), pressure sustaining (the pressure kept before it) or both. |
| Zone pipe | `ZP` | ZONE_PIPES | Submains and distributors downstream of the valve. |
| Lateral (sprayline) | `SL` | SPRAYLINES | Pipe with equally spaced emitters: emitter and nozzle from the catalogue, spacing, first-outlet offset, arc, riser height, depth. |
| Tape / dripline | `DT` | TAPES | Integral emitters defined by the catalogue item; inlet pressure, regulated or not, flushing flow. |
| Single emitter | `OUT` | OUTLETS | Sprinkler, micro-sprinkler, dripper, bubbler, gun or demand point on a zone pipe. Drawn on the mainline it is a valve-in-head sprinkler: a station of its own, or one station with the heads that share its station name. |
| Device | `F` | MISC_HYDRAULIC | Gate valve, filter, pressure regulator (with setting), pressure-sustaining valve (upstream setting), hydrant with flow limiter (flow setting), master valve, meter, backflow preventer, air valve, check valve; in a zone or on the mainline. Master, isolation and other valves may carry a reducing or sustaining pilot too. |
| Junction | `J` | JUNCTIONS | Explicit node, with optional fixed elevation. On the mainline, an air vessel (hydropneumatic tank: volume, gas in the steady state, connection bore, price) that the transients and the bill of materials take. |
| Irrigated area | `AR` | AREAS | Polygon with crop (FAO-56 table or free text) and planting date, soil texture and slope, irrigation method, ground cover, water salinity, effective rain method, net depth or water balance (ETo, Kc, available water, root depth, allowable depletion), efficiency, wetted fraction, emitters per plant and, for landscapes, the plant water use of its hydrozone. It may have islands that are not irrigated (Edit → Geometry → Subtract from area): its area and water are net, the automatic tools keep out of them and the exports carry them. An outline drawn or edited across itself is warned about at once. |
| Centre pivot / linear move | `PV` | PIVOTS | Machine with radius, spans, applied depth, cycle, end pressure, end gun, cost. A demand on the mainline; its machine data (sprinkler package, drive train and timer, corner arm, variable-rate prescription, electrical supply) open from Properties. |
| Controller | `CTRL` | CONTROLLERS | Irrigation controller: stations, output voltage (24 V AC), most stations at once, cost, sensors and accessories (rain, soil moisture, flow, freeze and wind sensors, pump start relay, surge protection). Powers the valve solenoids through the wire routes. |
| Wire route | `WR` | WIRES | Path of the wires from a controller through the valves (a trench or conduit), drawn by hand or by Automatic wire routes. Routes sharing a vertex connect; a controller or valve on a vertex or on the route joins it. |
| Traveller lane | | TRAVELLERS | A lane of a travelling gun from the hydrant on the mainline (Mainline → Traveller lanes…): a demand point of the mainline at the flow and pressure the gun needs ([Power, water and machines](power-water-machines.md#traveller-lanes-and-furrows)). |
| Furrow set | | SURFACE_IRRIGATION | Furrows fed by a gated pipe from an inlet on the mainline (Mainline → Furrows with gated pipe…): a demand point at the flow of the furrows irrigated together and the pressure of the gated pipe. |

## Connection rules

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

## Generators

- **Lateral block** (B): polygon, direction, lateral spacing, offset of the first one, lateral with
  emitters or tape, submain position (start, centre, end), valve (position and model), valve stub
  length, names. If a line, polyline, contour line or spline is selected when the dialog opens it
  can act as a guide: the laterals follow the curve (parallel to a contour line or a curved
  boundary) and are clipped by the polygon. The submain runs through the feed point of every row
  on the chosen side, stepping inside the field where a row does not reach that line (an L-shaped
  field); rows the polygon cuts in several pieces (a U-shaped field, a curved row clipped in two)
  are fed by branches joined to it, so every lateral is connected. Rows farther from the guide than
  the radius of its bends, or round a sharp corner of it, are rounded or cut and the block says so.
  Its **Longest lateral** section works out how long a lateral can run from its inlet before the flow
  of its emitters varies more than allowed (10 % by default, the usual rule; about 20 % of pressure
  for sprinklers), uphill and downhill, on the slope of the ground fitted over the block (level
  without terrain), inside the pressure window of the emitter and the velocity limit, for the tape
  or the emitter and lateral pipe chosen; it says what limits it and warns when the longest lateral of
  the drawing exceeds it.
- **Sprinkler grid** (AH): polygon, sprinkler and nozzle, spacings, square or triangular pattern,
  direction and design pressure.
- **Densogram** (Zone → Densogram, `DENS`): map of the water applied by the sprinklers and
  micro-sprinklers as they are drawn (position, arc, orientation and, after a design, the
  pressure of each one), with Christiansen CU, low-quarter DU, scheduling coefficient (mean over
  the driest 5 %) and dry spots, measured inside every irrigated area against its own mean (a
  lawn of sprays next to one of rotors is judged separately); the measured radial profile of a
  nozzle when the catalogue has one, else a triangular, elliptical or uniform profile; an optional
  wind (speed and direction) that drifts the water downwind; cell size, zones; the map is drawn
  on the canvas and the grid exports to CSV. The scheduling coefficient takes the driest contiguous
  window of 5 % of the area, and Design → Agronomy → Uniformity in the field shows the depth of one
  event of the programme instead of the rate ([Agronomy and irrigation scheduling](agronomy.md#uniformity-in-the-field)).
- **Submain position envelope** (FE): for every selected lateral, paints in green the stretch where
  the submain can feed it while keeping the pressure window, taking the terrain into account.

## Automatic design (Design → Automatic design)

Each tool shows its result after a pause, in steps with their progress and Cancel, and generates it
as one undo step. The islands of an irrigated area and the closed shapes selected inside its outline
(a pond, a shed, a well) are exclusions: laterals, rings and heads go round them, and the blocks have
net areas. SUBDIV and LAYOUT have the same longest lateral as the block generator (SUBDIV fills its
length with *Use the computed limit*; LAYOUT sets it against the longest path of the routed zones);
the routed zones never share a valve between areas of different water use (hydrozones), and their
pipes stay inside the outline of the lot.

| Tool | Alias | What it makes |
|---|---|---|
| Automatic sprinkler layout | `LAYOUT` | Heads for a lawn or bed (corners, then edges, then the interior, head to head, buildings and beds left out) with matched-precipitation nozzles and the CU/DU/SC preview; optionally zoned by flow (never mixing precipitation classes) and routed: valves on the mainline, by their zones or in a manifold, zone pipes as trees through the heads, a mainline tree from the supply. |
| Sports turf and golf templates | `TPL` | Football pitch with 3, 4 or 5 rows of rotors, running-track infield, golf green ringed by part circles, tee and fairway on a triangular grid. |
| Subdivide a field into blocks | `SUBDIV` | Blocks of equal net area no larger than an area or a flow, as strips or a grid, with service roads, each with its submain side and valve, filled by the block generator and fed by a mainline. |
| Orchard drip rings | `RINGS` | A ring of dripline or drippers round every tree of a planting grid or of surveyed trees, joined to laterals along the rows, a submain and the valve. |
| Fit a pivot to the field | `PFIT` | The largest full circle clear of the obstacles, or the part-circle pivot that waters the most of the field, with the machine length in standard spans. |
| Several pivots in the property | | The arrangement of centre pivots of standard spans that irrigates the most of the selected outline, within the flow allowed, with the common mainline ([Power, water and machines](power-water-machines.md#several-pivots-in-the-property)). |
| Detect vegetation in the image | `VEG` | Lawns, trees and shrubs found by image processing on this device (no service) in the base map on screen or a selected aerial photo, created as irrigated areas (with presets per class) and exclusions. Check that the imagery's terms of use allow tracing it. |
| Trace on the image (Draw menu) | `WAND` | Click inside a field, lawn or pond on the map: the outline grows over the pixels of similar colour of the satellite tiles, with a preview of its area and edge; colour tolerance (0 = automatic), colour smoothing (3–6 m in orchards) and the simplification of the outline change it without downloading again; Enter makes an irrigated area or a closed polyline (one undo step), Esc drops it and `V` outlines every field of the view. It needs a georeference and the internet. |
