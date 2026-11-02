# Calculation and sizing

## Design parameters (Design → Design parameters)

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

## Calculation steps

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

## Design check

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

## Calculation messages

Every zone, system flow and step may emit warnings, shown in the Messages tab and next to the item:
pressure outside the window, velocity exceeded, pressure rating exceeded (in operation or by water
hammer), valve outside its flow range, pump off its curve, NPSH available below what the pump
requires, a variable-speed drive that cannot reach its target pressure or would need less than its
minimum speed, supply flow or pressure exceeded, pressure deficit at a valve, pivot or valve-in-head
station (or a station above its window, or in no flow), infeasible LP (with the greedy method taking
over), looped mainline (the LP sizes it on tree paths and repeats; the final analysis checks),
missing catalogue components, pivot application rate above the soil limit, among others.

## Design assistant: explanations and one-click corrections

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

## Analyses of the mainline and of the operation

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

## Agronomy, mechanised machines and field calculators

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
