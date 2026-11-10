# Calculation and sizing

## Design parameters (Design → Design parameters)

| Group | Parameters and defaults |
|---|---|
| Hydraulics | Friction formula: Hazen-Williams (default), Darcy-Weisbach, Scobey or Manning; water temperature 20 °C (viscosity, vapour pressure and the derating of PVC and PE pressure classes); local losses as 5 % of the length (default) or the K of the bends and tees found in the drawing, enabled; C scale and offset (ageing); connection tolerance 0.05 m; at most 100 lumped nodes per lateral |
| Maximum velocities | 2.0 m/s in laterals, 1.5 m/s in zone pipes, 2.0 m/s in the mainline |
| Sizing | LP method (default) or velocity + pressure window (greedy); diameters per lateral (1), per submain (3) and per mainline (3); maximum pressure variation in the zone (0 = derived from the emitter flow tolerance); emitters per plant (1) |
| Economics | Interest 10 %, term 10 years, energy 0.75 per kWh, pump efficiency 65 %, 2000 h/year for the mainline and 500 h/year per zone, capital × energy trade-off enabled, currency of the region or language (see *Prices and currency*); mains frequency of the region, 50 or 60 Hz (a fixed-speed pump whose curve was measured at another frequency turns in proportion: a 60 Hz curve on 50 Hz mains runs at 5/6 of the speed and 69 % of the head) |
| Flushing and safety | Tape flushing velocity 0.3 m/s with 1 m minimum pressure at the open end; water hammer check enabled with valve closure time (0 = instantaneous); real operation of the zones, off (when on, after the design every zone and pivot of each system flow also runs at the pressure that really reaches its valve, and the Mainline tab shows the table) |
| Materials | Automatic fitting selection enabled; 6 m pipe sticks to count couplers |
| Terrain | Triangulation (default) or inverse-distance interpolation; contour densification 5 m |
| Electrical | 24 V AC solenoids: inrush current 0.37 A, holding current 0.22 A, minimum voltage at the solenoid 20 V; wire slack 10 % over the route length |

**New projects**, the last section of the dialog, says what the next new projects start with and
where each value comes from (the region of the machine, your choice or the program's default): the
mains frequency (60 Hz in North and Central America, the Caribbean, Brazil, Colombia, Venezuela,
Ecuador, Peru, Guyana, Suriname, Saudi Arabia, Korea, Taiwan, the Philippines, Japan, several
Pacific islands and Liberia, 50 Hz elsewhere) and the currency of the region unless you chose them,
and the units you chose (US units never come from the region alone). *Use these parameters for new
projects* keeps every parameter of the open project (velocities, losses, economics…) as the template
of the next ones, which keep the currency of their catalogue (an energy price kept in another
currency is converted); *Back to the region's defaults* forgets the choices.

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
     the water temperature, withstands the pressure the analysis found there plus the water hammer
     of the screening of step 6 (PVC loses part of its class above 25 °C and PE above 20 °C); when a
     pass ends with a pipe below its pressure,
     the unit's requirement rises and the zone is sized again (up to three passes). With nothing
     in the catalogue strong enough the unit is sized as before and the class is reported exceeded;
   - **repair**: greedy diameter increase along the critical path until the window is met (when the
     elevation range of the emitters alone exceeds the window, no pipe is bought for it and the
     zone says so: `zone_slope_exceeds_window`);
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
   LP holds the energy balance of every loop for the flows it sizes for, and since the sizes decide
   how the flow splits it is solved again with the flows of the new sizes until the choice settles
   (up to four more times; a note of approximation is left only when the flows do not settle). With
   a calculated supply, the grade line is kept above the pipe at the high points of the profile (in
   the LP and in the analysis), and a high point without an air valve is pointed out
   (`air_valve_missing`, information). Then the analysis of every flow with pumps
   (operating point; a variable-speed drive finds the speed that holds its target outlet pressure;
   the NPSH available is compared with the pump's curve; a pump station runs the duty pumps the flow
   needs, staged by flow, on the joint curve of those running, with the duty of each), valves with
   reducing or sustaining pilots, pressure-reducing, pressure-sustaining
   and flow-control valves, check valves and fixed- or calculated-pressure supplies; duty of every
   supply (flow, available pressure, required pressure, deficit) and annual energy. With the real
   operation of the zones on, every zone and pivot then runs at the pressure the mainline delivers
   to it, as an equivalent emitter behind its valve (a regulating valve holds its setting, a
   sustaining pilot its upstream pressure), adjusted until the zone and the line agree.
4. **Telescoping**: pipes with more than one diameter are split into entities, largest diameter
   upstream, and the affected zones are re-analysed.
5. **Flushing**: every zone with tapes is analysed with the ends open at the flushing velocity;
   reports the flushing flow, the required valve and upstream pressure, number of tapes, minimum end
   pressure and maximum velocity.
6. **Water hammer**: along the path of the water from the supply (from the valve, in a zone), every
   point of a pipe gets Michaud's envelope at its distance x, min(a·ΔV/g, 2·x·ΔV/(g·T)), with the
   wave celerity a from the material and wall and the closure time T, over the static pressure
   there; the worst point of each entity is compared with the pipe rating and the report shows the
   path used (the full transient analysis is Mainline → Hydraulic transients…, below).
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
   and for the current selection (Edit → Materials of the selection…). The standby pumps of pump
   stations, the air vessels, the block references marked to count, the traveller lanes and furrows
   and, when they are switched on, the parts of the pump house electrics, the solar array and the
   two-wire system ([Power, water and machines](power-water-machines.md)) are listed too. Pipe
   lengths run along the ground (√(L² + Δz²) with the terrain at both ends), in the losses as in the
   bill of materials.

The calculation runs in a **Web Worker** in the browser (or in an isolate on desktop) and returns
the resized entities and the results to the interface; while it runs, editing is blocked so that
no change is lost (unless *Edit while the design runs* is on in View → Snaps and drawing…: the
design then works on a copy and its results, out of date, are discarded), but navigation, reports
and other tabs stay free; the progress card has a Cancel. With Design → Analyse
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
| `area_self_intersect` | error | An irrigated area whose outline crosses itself (its area, and its water, come out wrong); the correction splits it into simple areas |
| `pipes_overlap`, `outside_terrain`, `zone_spacing_wide`, `area_uniformity_low` | warning | Pipes or laterals on top of each other; items more than 10 m outside the terrain data (extrapolated elevation); full-circle sprinklers farther apart than their throw allows; an area watered unevenly by its sprinklers (densogram: CU below 75 %, DU below 60 % or more than 5 % of the area getting less than half the mean) |
| `area_rate_exceeds_soil`, `area_eto_climate`, `area_planting_date`, `area_leaching_infeasible` | warning | Sprinklers applying more than the soil and its slope take in; an ETo typed on an area that differs from the site climate; a planting date ambiguous or not a date; water too saline for the crop |
| `capacity_below_peak`, `pivot_capacity_below_peak`, `pivot_runoff` | warning | The system, or a machine, short of the peak demand in the irrigation window; runoff under a machine ([Agronomy and irrigation scheduling](agronomy.md#checks)) |
| `supply_no_meter` | information | A water source with no flow meter nor hour meter, which the self-monitoring of a water permit asks for |

## Calculation messages

Every zone, system flow and step may emit warnings, shown in the Messages tab and next to the item:
pressure outside the window, velocity exceeded, pressure rating exceeded (in operation or by water
hammer), valve outside its flow range, pump off its curve, NPSH available below what the pump
requires, a variable-speed drive that cannot reach its target pressure or would need less than its
minimum speed, supply flow or pressure exceeded, pressure deficit at a valve, pivot or valve-in-head
station (or a station above its window, or in no flow), infeasible LP (with the greedy method taking
over), looped mainline (the LP holds the energy balance of every loop and repeats with the new flows;
the final analysis checks),
missing catalogue components, pivot application rate above the soil limit, a pump below the
minimum flow of its curve or above its motor power, the LP stopped at its iteration limit (the greedy
method then sizes), the elevation range of a zone beyond the emitter window, a zone that a regulating
device keeps below its nominal pressure, pressure below the atmosphere in a pipe (the grade line under
it), surplus pressure at a zone valve that does not regulate, a station or a system flow drawing more
current than the controller gives, the flows of a day that do
not fit the irrigation window, among others.

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
  controller with enough stations (the next standard size), enable the catalogue wires, split an
  area that crosses itself into simple areas, keep one of two pipes drawn over each other, join a
  loose sprinkler to the nearest pipe by a short pipe, design with the supply maximums, and more.
- **Fix automatically** (Design menu, `FIX`): safe corrections and designs in rounds until nothing
  more can be fixed, all in one undo step, with a summary of what changed and what needs a decision
  (a pump on public mains, new system flows: never applied on their own).
- **Optimise design** (Design menu, `OPT`): lowest annual cost (annualised investment + energy)
  that meets every requirement — LP sizing, the smallest suitable valves and the pump with the
  lowest life-cycle cost — in steps, each kept only when it improves and brings no new warning, with
  a before / after comparison.
- Both list every correction or change with a tick box and a button that shows it on the drawing:
  *Keep only the ticked ones* takes the project back and makes only those again, in one undo step.
- After a design with errors the Messages tab opens by itself and shows how many problems there are.

## Design scorecard

**Design → Design scorecard…** (under *Design check…*; on a phone ☰ → Design) grades a designed project on one page.
It reads only what the program already computes (the design results, the design check, the Messages list and the
analyses) and turns it into a transparent index: an overall score from 0 to 100 with a grade from A to E, a score and
a grade for each of seven categories, a radar of the categories, and every indicator with its value, its target, the
standard or design parameter the target comes from, its score, its weight, the points it would add and its weakest
item (a row of the table selects and frames it). Without a design, the dialog offers to design first.

| Category | Indicators scored | Reported only |
|---|---|---|
| Uniformity | Emission uniformity EU of the drip and micro zones; overlap CU of the sprinkler zones; emitter flow variation q_var (each the flow-weighted mean of the zones) | |
| Hydraulics | Pipe length within the velocity limit of its use (design parameters); pipe length within its pressure class at the water temperature; water the emitters deliver within their pressure window; zones and pivots given the pressure they need | |
| Energy | Pump duties within the catalogue range; pumps within 70–120 % of their best-efficiency flow (pumps with an efficiency curve); share of the pump head the critical zone uses (the rest is burnt in the valves) | kWh per m³ pumped and per ha·mm |
| Water and soil | Sprinkler rate within the soil intake (NRCS NEH 15-11); water infiltrated without runoff (sprinkler zones and machines over a soil); peak FAO-56 demand met in the irrigation window | |
| Economy | Life-cycle cost against the cheapest saved alternative | Investment and equivalent annual cost per area; energy share of the life-cycle cost |
| Robustness | Pipes within their class with the water hammer (Joukowsky check); pumps with their NPSH margin and suction lift; after the ageing test, the water within the pressure window and the EU of the design aged and clogged | |
| Completeness | Errors of the check and of the design; items without warnings; mainline high points without an air valve (AWWA M51); bill of materials priced | |

**How to use it.** **What to improve first** lists the indicators below 100, the most points first, each with how to
improve it and an **Open** button to the tool that does it (design parameters, Fix automatically, pump selection, the
densogram, the irrigation programme, system flows, life-cycle cost, air valves, the catalogue, the Messages tab). **Run
the ageing test** analyses the design aged and clogged (the defaults of *The design over its life*: 15 years, the
Hazen-Williams C falling 0.5 a year, 10 % of the emitter flow lost to clogging) and scores its robustness over its
life. **Remember this score**, change the design and design again, then **Compare with** the remembered score (or with
an alternative saved in Design → Design alternatives…) to see what the change did, category by category; the
remembered score lives in memory, not in the file. The scorecard exports as CSV, XLSX or PDF (the PDF with the table
and the radar); the same table is in File → Export report (`scorecard`) and the radar in the chart pages of the sheets
and of the document packages. The assistant reads it with `design_scorecard`, which also says what changed since its
previous call or against an alternative or the remembered score.

**Method.** Each indicator is scored by a piecewise-linear function between stated anchors (value → score), held at
the end scores beyond the first and the last anchor:

- **EU**: 0 → 0, 70 → 60, 80 → 70, 90 → 80, 94 → 90, 100 → 100. The classes are those of ASABE EP405.1 as the
  technical study (§9) gives them: above 94 % excellent, 90–94 % good, 80–90 % fair, below 80 % poor; the anchor at 70 %
  (the limit of grade D) is the program's own step inside the poor class.
- **Overlap CU**: 0 → 0, 75 → 60, 85 → 80, 100 → 100 (85 % satisfactory by Keller & Bliesner 1990 and ISO 15886-3; 75 %
  is the limit below which the program's own design check warns, `area_uniformity_low`).
- **q_var**: 0 → 100, 10 → 90, 20 → 70, 100 → 0. The classes are 10 % desirable and 20 % acceptable, as the technical
  study (§9) states them; the scorecard prints Keller & Bliesner (1990) and that section beside them, but the study
  gives no reference of its own for the two limits, so take them as the program's working bands.
- A criterion that must hold everywhere scores the share that meets it (0 % → 0, 100 % → 100), weighted by pipe
  length, by the water the emitters deliver, by flow (times the hours of the system flow for the pumps), by area or by
  count.
- A count that must be zero (errors, high points without an air valve) scores 100 at zero and 0 from one.

The anchor scores follow the grade bands (A ≥ 90, B ≥ 80, C ≥ 70, D ≥ 60, E below): the top class of a standard ends at
the A limit, the next at B, and so on. A category is the weighted mean of its assessed indicators and the overall score
the weighted mean of the assessed categories; every weight is 1. The points to gain of an indicator are (100 − score)
× its share of the overall score, so raising it to 100 adds exactly them. An indicator without data (no zone of that
kind, no soil on the areas, no prices, no saved alternative, a pump without an efficiency curve, the ageing test not
run) is *not assessed* and left out of the averages, never guessed; indicators without any reference value (energy per
m³ and per ha·mm, cost per area, the energy share of the life-cycle cost) are only reported.

**Not scored, and why.** Pivot and linear-move uniformity (the pivot results keep no CU), the full transient analysis
and the 24-hour simulation (their results are not kept with the design) and the densogram DU of the areas (too slow
for a table rebuilt after every edit). Application efficiency is a typed input of the areas, not a design result.

**Limits.** The scorecard is as good as the data: the soils, the prices, the efficiency curves of the pumps and the
saved alternatives make more indicators assessed. Compliance shares are linear (90 % of the pipe length within the
velocity limit scores 90), and a count is all or nothing, since the results do not keep the number of high points.
Every warning of the Messages list weighs on completeness, design warnings included. Equal weights are a neutral
choice, not a ranking of importance, and the ageing test uses its defaults, not the options typed in *The design over
its life*. The score compares designs; it is not a certification.

## Analyses of the mainline and of the operation

These run on the designed project (each says what is missing when there is no design or no water
supply); what they propose (inserted air valves, start hours, system flows, wire routes, a C
factor) is applied as one undo step. The long ones (on-demand operation, criticality, calibration,
the tariff schedule, the energy grouping, the design over its life) show their progress and stop
with Cancel.

| Analysis | Menu, alias | What it does |
|---|---|---|
| Hydraulic transients | Mainline, `SURGE` | Method of characteristics on the mainline of every system flow: the zone valves closing in the closure time, a power failure tripping the pumps (inertia estimated from power and speed, plus the flywheel of the pump; check valves closing on reverse flow) and an isolation valve closing; wave celerity from each pipe's wall, vapour cavities (column separation), the air valves drawn acting as combination valves and the air vessels of the mainline junctions; head and pressure envelopes per pipe against its class and against vacuum, the profile along the critical path, time series at the pump and at the worst point, and findings. It stops with Cancel between runs. |
| Air valves | Mainline, `AV` | Profile of every path from a supply to an end of the mainline and the air valves AWWA M51 practice asks for (high points, slope changes, long runs, pump discharge, check valves, line ends, low grade line, transient vacuum), sized by the orifice air flow, inserted with the catalogue item that fits. |
| 24-hour simulation | Mainline, `EPS` | The system flows over a day at their start hours and durations, every pump on while a flow it serves runs; energy and cost per pump and hour at the tariff of the parameters, with an optional peak band; the level of every reservoir or dam of a supply falls and rises with its inflow. |
| On-demand operation | Mainline, `DEMAND` | Design flows of a branched network of hydrants by Clément's formula and the check against random configurations of open hydrants (FAO 59): reliability and pressure deficits per hydrant; hydrants may have flow limiters. |
| Pipe criticality | Mainline, `CRIT` | Every pipe closed in turn (N−1): the demand cut off and the demand the remaining pressures cannot deliver, pipes ranked. |
| Roughness calibration | Mainline, `CALIB` | Hazen-Williams C factors (one, or one per material group) fitted to pressures and flows read in the field, by weighted least squares with the network solver in the loop. |
| The design over its life | Mainline | The designed project analysed again with its pipes after years of use: the pipes rougher (the Hazen-Williams C falling by so many points a year, the Darcy-Weisbach roughness growing by so many millimetres a year), the emitters partly clogged (less flow, more manufacturing variation) and both, beside the new design: flows, emitter pressures, EU and CU, zones out of their window, the pressure the valves lack, what the supplies and pumps must give and the energy, to show the margin of the design. |
| Fertigation | Mainline, `FERT` | Travel times of a product injected at the supply or the pump to every valve and on to the farthest emitter, the injection plan (pre-wetting, injection, flushing), amounts for a dose per hectare and the check of a venturi injector. |
| Time-of-use tariff and flow schedule | Design, `TARIFF` | Energy price by band of the day, demand charges and seasons, and the Brazilian rural irrigation discount (a window of up to 8 h 30 min a day in up to three blocks, never between 17:00 and 21:30, ANEEL Normative Resolution 1,000/2021, art. 186, and MME Normative Ordinance 137/2026); the start hours of least daily cost. |
| Group zones for energy | Design, `EGROUP` | Zones (and pivots and valve-in-head stations) grouped into system flows of similar required head, so the pump does not give every zone the pressure of the most demanding one; compared with the grouping by flow. |
| Automatic wire routes | Zone, `WROUTE` | Wire routes along the pipe trenches from every controller to its valves, master valves and pump-start relays (shortest paths for conventional wiring, a Steiner-like tree for a two-wire path), and the sizing of a two-wire (decoder) system on them: decoders, cable, voltage at every decoder, grounding points. |

## Agronomy, mechanised machines and field calculators

- **Site climate** (Design → Site climate…): monthly normals of ETo (FAO Penman-Monteith), rain
  (mean and dependable), solar radiation, minimum humidity and wind at 2 m, downloaded for the site
  from NASA POWER (the default, free for any use) or Open-Meteo (historical weather, ERA5; for
  non-commercial use), read from an INMET station file, worked out from the normals of a station, or
  typed in, kept in the project with their source. The daily soil water balance, the irrigation
  programme, fertigation by stage, field uniformity and user crops are in
  [Agronomy and irrigation scheduling](agronomy.md); the pump house electrics, solar pumping in the
  design, water quality, two-wire wiring, several pivots, traveller lanes and furrows in
  [Power, water and machines](power-water-machines.md).
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
