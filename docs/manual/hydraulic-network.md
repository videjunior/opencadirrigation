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
| Crop rows from the image | | The direction, spacing and number of the planting rows of an orchard, coffee, vineyard, citrus or olive field read on the satellite image or a placed aerial photo, with the plant spacing and the canopy ground cover where the image shows them; they become the defaults of Subdivide a field into blocks, Orchard drip rings and Lateral block over the area ([below](#crop-rows-from-the-image)). |
| Detect vegetation in the image | `VEG` | Lawns, trees and shrubs found by image processing on this device (no service) in the base map on screen or a selected aerial photo, created as irrigated areas (with presets per class) and exclusions. Check that the imagery's terms of use allow tracing it. |
| Trace on the image (Draw menu) | `WAND` | Click inside a field, lawn or pond on the map: the outline grows over the pixels of similar colour of the satellite tiles, with a preview of its area and edge; colour tolerance (0 = automatic), colour smoothing (3–6 m in orchards) and the simplification of the outline change it without downloading again; Enter makes an irrigated area or a closed polyline (one undo step), Esc drops it and `V` outlines every field of the view. It needs a georeference and the internet. |

### Crop rows from the image

Drip laterals in an orchard, a coffee field, a vineyard or a citrus or olive grove follow the planting rows already
in the field. **Design → Automatic design → Crop rows from the image…** (on a phone, ☰ → Design, the same label)
reads those rows on the aerial image instead of measuring them by hand. Select the irrigated area of the planted
field (or a closed outline; with a single area in the project nothing needs to be selected) and open the tool. The
satellite image needs a georeferenced project (File → Georeference); a placed aerial photo over the field can be
chosen instead under *Image*. The tool downloads the imagery of the field and reads it on this device, with no AI key
and no other service:

- **Row direction**, in degrees counter-clockwise from east, 0 to 180 (the same *Row direction (°)* as Subdivide a
  field into blocks and Orchard drip rings);
- **Row spacing**, **Rows across the field** and the **Confidence** (clear rows from 35 %, uncertain from 15 %, no rows
  below);
- the **Plant spacing in the row** (when separate crowns show) and the **Canopy ground cover** (when canopy and ground
  show apart), else "not visible in the image".

The picture shows the field (cyan) and the rows found (amber), with a detail of its middle at actual pixels, and the
rows are drawn over the drawing while the dialog is open; **Stop** ends a long reading. If the lines fell on the
alleys rather than on the plants (a closed canopy with shaded alleys, a cover crop as green as the crop), turn on
**Rows on the other band**, which moves them half a spacing. *Closest spacing* and *Widest spacing* bound the search
(1.5 to 12 m by default); the closest also sets the pixel size asked of the imagery. **Apply** writes, in one undo step,
the row direction (the area's `rdir`) and spacing, and the plant spacing, on the area, which Subdivide a field into
blocks, Orchard drip rings and Lateral block (and the assistant's layouts) then start from over that area; the
area's ground cover (used by the Kr of localised irrigation); and, if ticked, the rows as guide lines on the
`CROP_ROWS` layer. The assistant does the same with `detect_crop_rows` (a reading that changes nothing) and
`apply_crop_rows`.

**Method.** The colour of the field is high-passed (the mean over a box 1.25 × the widest spacing is subtracted, so
shading and patches go and the stripes stay), divided by its local RMS so that dark and bright parts weigh alike, and
projected on its first principal component, signed so that the greener and darker band is positive. For every
direction (steps of at most 1°) the pixels of square blocks of the field are binned by their distance across that
direction (a discrete Radon projection), and the share of the variance the bins explain (R²) is averaged over the
blocks: rows give a sharp maximum at their direction. The spacing is the first peak of the autocorrelation of the
block profiles; the direction is then refined on the whole field (to about 0.1° over a field a hundred spacings long)
and the spacing on the Fourier power of the whole-field profile (within ±6 %, by a parabola through the logarithm of
the power), whose phase places the rows. Confidence = angular prominence (1 − median R² ÷ largest R²) × periodicity
(the autocorrelation at the spacing). The plant spacing is the first peak of the autocorrelation along the centre of
the rows; the ground cover is the share of the field above the Otsu threshold of the smoothed signal, given only when
its histogram has two populations (bimodality coefficient above 5/9). The method and its references are in the
[technical study](../TECHNICAL_STUDY.md#201-crop-rows).

**Limits.** The rows must be straight over the area (rows that bend along the contours give an average direction and a
note: draw smaller areas), evenly spaced and visible, about three pixels of the imagery per spacing at least: Esri
imagery is about 0.3–0.6 m a pixel over most farmland, so rows closer than about 1–2 m are not seen, and the tool
says so. Which band is the crop is decided by colour (the greener and darker band, or the wider one when both are
green and the other is clearly wider): check the detail and use *Rows on the other band* when needed. Shadows count
as canopy in the ground cover. A field larger than the pixel budget (2.5 million pixels) is read on a window in its
middle and the rows are extended over the whole field. The imagery may be years old: check that it shows the planting
of today, and that its terms of use allow deriving data from it.
